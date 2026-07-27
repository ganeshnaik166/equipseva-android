-- Round 3486: Customer Hospital UV-Vis Spectrophotometer (Lab) QC Audit
-- Lab UV-Vis spectrophotometer QA — device model × parameter (wavelength accuracy, absorbance, stray light, baseline flatness, photometric noise, resolution) × reference vs measured × deviation × tolerance × calibration date × verdict × CAPA

-- =============================================================================
-- TABLE 1: spectrophotometer_qc_r3486 — per-device UV-Vis spectrophotometer QC checks
-- =============================================================================
create table if not exists public.spectrophotometer_qc_r3486 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'wavelength_accuracy_nm','absorbance_accuracy','stray_light_pct',
    'baseline_flatness','photometric_noise','resolution_nm'
  )),
  reference_value numeric(12,4),
  measured_value numeric(12,4),
  deviation_pct numeric(8,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spectrophotometer_qc_r3486 enable row level security;

create index if not exists idx_spectrophotometer_qc_r3486_org on public.spectrophotometer_qc_r3486(organization_id);
create index if not exists idx_spectrophotometer_qc_r3486_date on public.spectrophotometer_qc_r3486(calibration_date);
create index if not exists idx_spectrophotometer_qc_r3486_verdict on public.spectrophotometer_qc_r3486(qc_verdict);

-- =============================================================================
-- TABLE 2: spectrophotometer_qc_capa_actions_r3486 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.spectrophotometer_qc_capa_actions_r3486 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.spectrophotometer_qc_r3486(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'wavelength_accuracy_out_of_tolerance','absorbance_accuracy_out_of_tolerance','stray_light_excessive',
    'baseline_flatness_drift','photometric_noise_high','resolution_degraded',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lamp_aged','monochromator_misalignment','detector_degraded','optical_contamination',
    'reference_standard_drift','sample_compartment_stray_light','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_deuterium_lamp','replace_tungsten_lamp','realign_monochromator','replace_detector',
    'clean_optics','recalibrate_wavelength','replace_reference_standard','update_software_config',
    'retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','iso_15189_deviation',
    'internal_only','none','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spectrophotometer_qc_capa_actions_r3486 enable row level security;

create index if not exists idx_spectrophotometer_capa_r3486_log on public.spectrophotometer_qc_capa_actions_r3486(qc_log_id);
create index if not exists idx_spectrophotometer_capa_r3486_status on public.spectrophotometer_qc_capa_actions_r3486(capa_status);

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

  -- 16 QC check rows
  insert into public.spectrophotometer_qc_r3486 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.param,
    q.refv, q.measv, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','SPEC-APL-01','Shimadzu UV-1900i','wavelength_accuracy_nm',
     361.0000,361.1000,0.03,true,'2026-07-05','pass','Holmium oxide wavelength check within +/-0.3 nm'),
    ('Apollo Chennai','SPEC-APL-02','Shimadzu UV-1900i','absorbance_accuracy',
     1.0000,1.0040,0.40,true,'2026-07-05','pass','Absorbance linearity NIST 930e filter within tolerance'),
    ('Fortis Gurgaon','SPEC-FRT-11','Thermo Evolution 201','stray_light_pct',
     0.0500,0.1200,140.00,false,'2026-07-02','fail','Stray light at 220 nm exceeds 0.05 pct limit - cell compartment contamination'),
    ('Fortis Gurgaon','SPEC-FRT-12','Thermo Evolution 201','wavelength_accuracy_nm',
     486.0000,486.7000,0.14,false,'2026-07-02','conditional_pass','Wavelength drift 0.7 nm at hydrogen line - monochromator realignment advised'),
    ('Manipal Bengaluru','SPEC-MNP-21','PerkinElmer Lambda 365','baseline_flatness',
     0.0010,0.0035,250.00,false,'2026-06-28','fail','Baseline flatness out of spec across 200-800 nm - lamp aged'),
    ('Manipal Bengaluru','SPEC-MNP-22','PerkinElmer Lambda 365','photometric_noise',
     0.0005,0.0006,20.00,true,'2026-06-28','pass','Photometric noise RMS within limit'),
    ('AIIMS Delhi','SPEC-AIM-31','Agilent Cary 60','resolution_nm',
     1.0000,1.0500,5.00,true,'2026-06-25','conditional_pass','Spectral bandwidth marginally wide - monitor at next QC'),
    ('AIIMS Delhi','SPEC-AIM-32','Agilent Cary 60','absorbance_accuracy',
     0.5000,0.5180,3.60,false,'2026-06-25','fail','Absorbance accuracy error 3.6 pct - detector response degraded'),
    ('CMC Vellore','SPEC-CMC-41','Systronics 2202','wavelength_accuracy_nm',
     656.0000,656.1000,0.02,true,'2026-06-20','pass','Wavelength calibration at deuterium line pass'),
    ('CMC Vellore','SPEC-CMC-42','Systronics 2202','stray_light_pct',
     0.0500,0.0400,-20.00,true,'2026-06-20','pass','Stray light below limit - good'),
    ('KIMS Hyderabad','SPEC-KIM-51','Analytik Jena Specord 210','baseline_flatness',
     0.0010,0.0012,20.00,true,'2026-05-30','pass','Baseline flatness within tolerance post PM'),
    ('KIMS Hyderabad','SPEC-KIM-52','Analytik Jena Specord 210','photometric_noise',
     0.0005,0.0011,120.00,false,'2026-05-30','fail','Photometric noise doubled - deuterium lamp end of life'),
    ('Yashoda Hyderabad','SPEC-YSH-61','Shimadzu UV-1900i','resolution_nm',
     1.0000,1.0200,2.00,true,'2026-05-22','pass','Resolution within spec'),
    ('Yashoda Hyderabad','SPEC-YSH-62','Shimadzu UV-1900i','wavelength_accuracy_nm',
     361.0000,361.6000,0.17,false,'2026-05-22','conditional_pass','Wavelength 0.6 nm drift - recalibration scheduled'),
    ('Kokilaben Mumbai','SPEC-KKB-71','Thermo Evolution 201','absorbance_accuracy',
     1.0000,1.0900,9.00,false,'2026-05-15','fail','Absorbance error 9 pct - instrument removed pending service'),
    ('Narayana Bengaluru','SPEC-NRY-81','PerkinElmer Lambda 365','stray_light_pct',
     0.0500,0.0600,20.00,false,'2026-07-01','conditional_pass','Stray light slightly above limit - clean sample compartment')
  ) as q(hosp, dcode, model, param, refv, measv, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.spectrophotometer_qc_capa_actions_r3486 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SPEC-FRT-11','stray_light_excessive','sample_compartment_stray_light','clean_optics','in_progress','nabl_finding','2026-07-08',null,6500.00,'Cell compartment cleaned - reverify stray light at 220 nm'),
    ('SPEC-FRT-12','wavelength_accuracy_out_of_tolerance','monochromator_misalignment','realign_monochromator','open','internal_only','2026-07-10',null,12000.00,'Monochromator realignment scheduled with OEM'),
    ('SPEC-MNP-21','baseline_flatness_drift','lamp_aged','replace_deuterium_lamp','verification_pending','iso_15189_deviation','2026-07-03',null,28000.00,'Deuterium lamp replaced - verify baseline flatness'),
    ('SPEC-AIM-32','absorbance_accuracy_out_of_tolerance','detector_degraded','replace_detector','escalated','nabh_finding','2026-06-30',null,55000.00,'Detector response degraded - escalated to OEM service'),
    ('SPEC-KIM-52','photometric_noise_high','lamp_aged','replace_deuterium_lamp','closed','internal_only','2026-06-05','2026-06-02',26000.00,'Lamp replaced and noise back within spec - closed'),
    ('SPEC-KKB-71','absorbance_accuracy_out_of_tolerance','detector_degraded','schedule_oem_service','overdue','cdsco_notifiable','2026-05-25',null,60000.00,'Instrument removed from service - OEM service overdue'),
    ('SPEC-YSH-62','wavelength_accuracy_out_of_tolerance','operator_setup_error','recalibrate_wavelength','closed','internal_only','2026-05-28','2026-05-24',0.00,'Wavelength recalibrated by lab staff - closed'),
    ('SPEC-NRY-81','stray_light_excessive','optical_contamination','clean_optics','open','nabl_finding','2026-07-06',null,4000.00,'Clean sample compartment and reverify')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.spectrophotometer_qc_r3486 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3486_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spectrophotometer_qc_r3486)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.spectrophotometer_qc_r3486 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3486_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3486_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3486_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.spectrophotometer_qc_r3486 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3486_model_scorecard() from public, anon;
grant execute on function public.founder_r3486_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3486_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.spectrophotometer_qc_r3486 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3486_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3486_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3486_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.spectrophotometer_qc_r3486 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3486_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3486_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3486_capa_status_board()
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
  from public.spectrophotometer_qc_capa_actions_r3486 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3486_capa_status_board() from public, anon;
grant execute on function public.founder_r3486_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3486_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spectrophotometer_qc_capa_actions_r3486)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.spectrophotometer_qc_capa_actions_r3486 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3486_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3486_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3486_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  in_tolerance bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
  worst_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.spectrophotometer_qc_r3486 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3486_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3486_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3486_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.calibration_date,
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.notes
  from public.spectrophotometer_qc_r3486 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3486_high_risk_queue() from public, anon;
grant execute on function public.founder_r3486_high_risk_queue() to authenticated;
