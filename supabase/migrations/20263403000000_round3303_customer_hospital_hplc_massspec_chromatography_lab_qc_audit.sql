-- Round 3303: Customer Hospital HPLC / Mass-Spec Chromatography Reference-Lab QC Audit
-- Reference-lab QA — instrument type × lab section × system suitability × RT drift × mass accuracy ppm × peak resolution × column pressure × calibration r2 × carryover × detector response × PM × CAPA

-- =============================================================================
-- TABLE 1: chromatography_qc_r3303 — per-instrument chromatography/MS QC checks
-- =============================================================================
create table if not exists public.chromatography_qc_r3303 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  instrument_code text not null,
  instrument_type text not null check (instrument_type in (
    'hplc_uv','uplc','lc_msms','gc_ms','maldi_tof','ion_chromatography'
  )),
  lab_section text not null check (lab_section in (
    'therapeutic_drug_monitoring','toxicology','newborn_screening',
    'vitamin_assays','hormone_assays','biochemistry_specialised'
  )),
  check_date date not null,
  system_suitability_pass boolean not null,
  retention_time_drift_ok boolean not null,
  mass_accuracy_error_ppm numeric(5,2),
  peak_resolution_ok boolean not null,
  column_pressure_ok boolean not null,
  calibration_curve_r2 numeric(6,4),
  carryover_within_limit boolean not null,
  detector_response_ok boolean not null,
  preventive_maint_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','instrument_grounded'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.chromatography_qc_r3303 enable row level security;

create index if not exists idx_chromatography_qc_r3303_org on public.chromatography_qc_r3303(organization_id);
create index if not exists idx_chromatography_qc_r3303_date on public.chromatography_qc_r3303(check_date);
create index if not exists idx_chromatography_qc_r3303_verdict on public.chromatography_qc_r3303(qc_verdict);

-- =============================================================================
-- TABLE 2: chromatography_qc_capa_actions_r3303 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.chromatography_qc_capa_actions_r3303 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.chromatography_qc_r3303(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'system_suitability_failure','retention_time_drift','mass_accuracy_out_of_spec','peak_resolution_loss',
    'column_pressure_fault','calibration_curve_poor','carryover_exceeded','detector_response_drop','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'column_degraded','mobile_phase_contamination','ms_source_fouling','detector_lamp_aging',
    'pump_seal_wear','autosampler_carryover','calibrator_lot_issue','operator_method_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_column','prepare_fresh_mobile_phase','clean_ms_source','replace_detector_lamp',
    'replace_pump_seals','clean_autosampler_needle','requalify_calibrators','retrain_lab_analyst',
    'ground_instrument','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cap_deviation','none','internal_only','iso_15189_deviation','patient_result_hold'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.chromatography_qc_capa_actions_r3303 enable row level security;

create index if not exists idx_chromatography_capa_r3303_log on public.chromatography_qc_capa_actions_r3303(qc_log_id);
create index if not exists idx_chromatography_capa_r3303_status on public.chromatography_qc_capa_actions_r3303(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 chromatography/MS QC check rows
  insert into public.chromatography_qc_r3303 (
    organization_id, hospital_name, instrument_code, instrument_type, lab_section, check_date,
    system_suitability_pass, retention_time_drift_ok, mass_accuracy_error_ppm,
    peak_resolution_ok, column_pressure_ok, calibration_curve_r2,
    carryover_within_limit, detector_response_ok, preventive_maint_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.itype, q.sect, q.cdt::date,
    q.ssp, q.rtd, q.mae,
    q.prk, q.cpk, q.r2,
    q.cwl, q.drk, q.pmc,
    q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','HPLC-APL-01','hplc_uv','therapeutic_drug_monitoring','2026-07-02',
     true,true,null,true,true,0.9995,true,true,true,'pass','Vancomycin TDM assay — system suitability and linearity nominal'),
    ('Apollo Chennai Greams Road','LCMS-APL-02','lc_msms','toxicology','2026-07-02',
     true,true,4.20,true,true,0.9982,true,true,true,'conditional_pass','Mass accuracy 4.2 ppm approaching 5 ppm limit — trend watch'),
    ('Fortis Gurgaon','UPLC-FRT-01','uplc','vitamin_assays','2026-07-01',
     true,true,null,true,true,0.9991,true,true,true,'pass','25-OH Vitamin D UPLC — resolution and carryover within limits'),
    ('Fortis Gurgaon','GCMS-FRT-02','gc_ms','newborn_screening','2026-07-01',
     true,false,6.80,false,true,0.9910,true,true,false,'fail','Organic acid panel — peak resolution lost, RT drift, PM overdue'),
    ('Manipal Bengaluru Old Airport Road','LCMS-MNP-01','lc_msms','hormone_assays','2026-06-30',
     false,false,11.40,true,true,0.9720,false,false,false,'instrument_grounded','Steroid panel — suitability plus 11.4 ppm mass accuracy fail, source fouled, grounded'),
    ('Manipal Bengaluru Old Airport Road','MALDI-MNP-02','maldi_tof','biochemistry_specialised','2026-06-30',
     true,true,8.50,true,true,0.9960,true,true,true,'conditional_pass','MALDI mass calibration 8.5 ppm — recalibrated, monitor next run'),
    ('AIIMS Delhi Ansari Nagar','HPLC-AIM-01','hplc_uv','therapeutic_drug_monitoring','2026-06-29',
     true,true,null,true,true,0.9997,true,true,true,'pass','Carbamazepine and phenytoin TDM — annual QC clean pass'),
    ('AIIMS Delhi Ansari Nagar','IC-AIM-02','ion_chromatography','biochemistry_specialised','2026-06-29',
     true,true,null,true,false,0.9975,true,true,true,'conditional_pass','Column back-pressure high on IC — flush scheduled'),
    ('CMC Vellore','LCMS-CMC-01','lc_msms','newborn_screening','2026-06-28',
     true,true,3.10,true,true,0.9988,false,true,true,'fail','Amino acid MS/MS carryover above 0.1 pct limit — needle wash extended'),
    ('CMC Vellore','UPLC-CMC-02','uplc','vitamin_assays','2026-06-28',
     true,true,null,true,true,0.9993,true,true,true,'pass','Fat-soluble vitamins UPLC — all parameters nominal'),
    ('KIMS Hyderabad','GCMS-KIM-01','gc_ms','toxicology','2026-06-27',
     true,true,5.90,true,true,0.9950,true,false,true,'conditional_pass','GC-MS detector response down 15 pct — EM voltage adjusted'),
    ('KIMS Hyderabad','HPLC-KIM-02','hplc_uv','hormone_assays','2026-06-27',
     true,true,null,true,true,0.9989,true,true,true,'pass','Catecholamine HPLC-ECD — post-AMC verification pass'),
    ('Kokilaben Mumbai','LCMS-KKB-01','lc_msms','therapeutic_drug_monitoring','2026-06-26',
     false,true,4.80,true,true,0.9650,true,true,false,'fail','Tacrolimus immunosuppressant curve r2 0.965 below 0.99, PM overdue'),
    ('SGPGI Lucknow','MALDI-SGP-01','maldi_tof','biochemistry_specialised','2026-06-26',
     true,true,2.40,true,true,0.9992,true,true,true,'pass','Microbial ID MALDI — mass calibration 2.4 ppm within spec')
  ) as q(hosp, code, itype, sect, cdt, ssp, rtd, mae, prk, cpk, r2, cwl, drk, pmc, qv, nt);

  -- CAPA seed — attach to specific checks via instrument code
  insert into public.chromatography_qc_capa_actions_r3303 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('GCMS-FRT-02','peak_resolution_loss','column_degraded','replace_column','in_progress','nabl_finding','2026-07-08',null,55000.00,'GC column degraded — replacement installed, requalifying organic acid panel'),
    ('LCMS-MNP-01','mass_accuracy_out_of_spec','ms_source_fouling','clean_ms_source','escalated','patient_result_hold','2026-07-05',null,85000.00,'Source cleaned, mass cal pending — steroid results held, escalated to OEM'),
    ('LCMS-CMC-01','carryover_exceeded','autosampler_carryover','clean_autosampler_needle','open','iso_15189_deviation','2026-07-09',null,15000.00,'Needle wash extended — re-verify carryover on newborn amino acid panel'),
    ('LCMS-KKB-01','calibration_curve_poor','calibrator_lot_issue','requalify_calibrators','verification_pending','nabl_finding','2026-07-06',null,22000.00,'New calibrator lot qualified — awaiting tacrolimus curve re-verification'),
    ('GCMS-KIM-01','detector_response_drop','detector_lamp_aging','replace_detector_lamp','closed','internal_only','2026-07-01','2026-06-30',18000.00,'EM detector replaced — response restored to spec'),
    ('MALDI-MNP-02','mass_accuracy_out_of_spec','operator_method_error','requalify_calibrators','closed','internal_only','2026-06-30','2026-06-29',0.00,'Recalibrated with fresh standard — mass accuracy back within 5 ppm'),
    ('IC-AIM-02','column_pressure_fault','pump_seal_wear','replace_pump_seals','overdue','internal_only','2026-06-28',null,9500.00,'IC pump seals worn — replacement past target date, vendor delayed')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.chromatography_qc_r3303 e
    on e.organization_id = v_org_id and e.instrument_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3303_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.chromatography_qc_r3303)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.chromatography_qc_r3303 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3303_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3303_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3303_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  suitability_fail bigint,
  carryover_fail bigint,
  maint_overdue bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','instrument_grounded'))::bigint,
    count(*) filter (where l.system_suitability_pass = false)::bigint,
    count(*) filter (where l.carryover_within_limit = false)::bigint,
    count(*) filter (where l.preventive_maint_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.chromatography_qc_r3303 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3303_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3303_hospital_scorecard() to authenticated;

-- 3) Instrument type × lab section matrix
create or replace function public.founder_r3303_instrument_section_matrix()
returns table(instrument_type text, lab_section text, checks bigint, passed bigint, avg_mass_accuracy_error_ppm numeric, avg_calibration_r2 numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_type, l.lab_section, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.mass_accuracy_error_ppm), 2),
    round(avg(l.calibration_curve_r2), 4)
  from public.chromatography_qc_r3303 l
  group by l.instrument_type, l.lab_section
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3303_instrument_section_matrix() from public, anon;
grant execute on function public.founder_r3303_instrument_section_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3303_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, suitability_fail bigint, carryover_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','instrument_grounded'))::bigint,
    count(*) filter (where l.system_suitability_pass = false)::bigint,
    count(*) filter (where l.carryover_within_limit = false)::bigint
  from public.chromatography_qc_r3303 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3303_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3303_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3303_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.chromatography_qc_capa_actions_r3303 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3303_capa_status_board() from public, anon;
grant execute on function public.founder_r3303_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3303_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.chromatography_qc_capa_actions_r3303)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.chromatography_qc_capa_actions_r3303 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3303_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3303_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3303_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.chromatography_qc_capa_actions_r3303 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3303_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3303_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3303_high_risk_queue()
returns table(
  hospital_name text,
  instrument_code text,
  instrument_type text,
  check_date date,
  qc_verdict text,
  system_suitability_pass boolean,
  carryover_within_limit boolean,
  calibration_curve_r2 numeric,
  mass_accuracy_error_ppm numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.instrument_code, l.instrument_type, l.check_date,
    l.qc_verdict, l.system_suitability_pass, l.carryover_within_limit,
    l.calibration_curve_r2, l.mass_accuracy_error_ppm, l.notes
  from public.chromatography_qc_r3303 l
  where l.qc_verdict in ('conditional_pass','fail','instrument_grounded')
     or l.system_suitability_pass = false
     or l.retention_time_drift_ok = false
     or l.peak_resolution_ok = false
     or l.column_pressure_ok = false
     or l.carryover_within_limit = false
     or l.detector_response_ok = false
     or l.preventive_maint_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3303_high_risk_queue() from public, anon;
grant execute on function public.founder_r3303_high_risk_queue() to authenticated;
