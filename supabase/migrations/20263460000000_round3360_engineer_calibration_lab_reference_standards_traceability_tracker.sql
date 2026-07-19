-- Round 3360: Engineer Calibration-Lab Reference-Standards & Measurement-Traceability Tracker (ISO 17025 / NABL)
-- Cal-lab QA — lab location × standard type × traceability chain × cal validity × uncertainty budget × certificate × environmental log × usage × CAPA

-- =============================================================================
-- TABLE 1: cal_ref_standards_r3360 — per reference standard / master instrument
-- =============================================================================
create table if not exists public.cal_ref_standards_r3360 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  lab_location text not null check (lab_location in (
    'chennai_cal_lab','gurgaon_cal_lab','bengaluru_cal_lab','field_kit'
  )),
  standard_code text not null,
  standard_make_model text not null,
  standard_type text not null check (standard_type in (
    'electrical_multifunction','pressure_calibrator','temperature_dry_block','flow_analyzer',
    'defibrillator_analyzer','gas_flow_analyzer','spo2_simulator','esu_analyzer'
  )),
  traceable_to text not null check (traceable_to in (
    'nabl_lab','national_std_npl','oem_factory','international'
  )),
  custodian_engineer text not null,
  last_calibrated date not null,
  cal_due_date date not null,
  days_to_due int not null,
  uncertainty_budget_ok boolean not null,
  cal_certificate_valid boolean not null,
  environmental_conditions_logged boolean not null,
  usage_count_since_cal int not null,
  standard_verdict text not null check (standard_verdict in (
    'in_cal_valid','cal_due_soon','overdue_quarantine','uncertainty_review','retired'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cal_ref_standards_r3360 enable row level security;

create index if not exists idx_cal_ref_standards_r3360_org on public.cal_ref_standards_r3360(organization_id);
create index if not exists idx_cal_ref_standards_r3360_due on public.cal_ref_standards_r3360(cal_due_date);
create index if not exists idx_cal_ref_standards_r3360_verdict on public.cal_ref_standards_r3360(standard_verdict);

-- =============================================================================
-- TABLE 2: cal_ref_standards_capa_actions_r3360 — recal / quarantine / replacement CAPA
-- =============================================================================
create table if not exists public.cal_ref_standards_capa_actions_r3360 (
  id uuid primary key default gen_random_uuid(),
  standard_log_id uuid not null references public.cal_ref_standards_r3360(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'recalibration_overdue','uncertainty_out_of_budget','certificate_expired','environmental_out_of_spec',
    'traceability_gap','usage_limit_exceeded','standard_damaged','preventive_recal_due'
  )),
  root_cause text not null check (root_cause in (
    'recal_backlog','reference_drift','cert_lapsed_vendor_delay','environmental_control_failure',
    'traceability_chain_broken','overuse_between_cal','physical_damage_handling','pending_investigation','vendor_scheduling_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_recalibration','quarantine_standard','replace_reference_standard','renew_cal_certificate',
    'repair_environmental_controls','restore_traceability_chain','retrain_calibration_staff','retire_standard',
    'send_to_nabl_lab','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_nonconformity','iso_17025_deviation','customer_recall_risk','none','internal_only','measurement_invalidated'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cal_ref_standards_capa_actions_r3360 enable row level security;

create index if not exists idx_cal_ref_capa_r3360_log on public.cal_ref_standards_capa_actions_r3360(standard_log_id);
create index if not exists idx_cal_ref_capa_r3360_status on public.cal_ref_standards_capa_actions_r3360(capa_status);

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

  -- 14 reference-standard rows
  insert into public.cal_ref_standards_r3360 (
    organization_id, lab_location, standard_code, standard_make_model, standard_type,
    traceable_to, custodian_engineer, last_calibrated, cal_due_date, days_to_due,
    uncertainty_budget_ok, cal_certificate_valid, environmental_conditions_logged,
    usage_count_since_cal, standard_verdict, notes
  )
  select v_org_id, q.loc, q.code, q.model, q.stype,
    q.trace, q.eng, q.lastcal::date, q.due::date, q.dtd::int,
    q.ubo, q.ccv, q.ecl,
    q.usage::int, q.verdict, q.nt
  from (values
    ('chennai_cal_lab','RS-CHN-EMF-01','Fluke 5522A Multifunction Calibrator','electrical_multifunction',
     'nabl_lab','Arun Prakash','2026-02-10','2027-02-10',206,
     true,true,true,58,'in_cal_valid','Master for Apollo Chennai monitor cal — uncertainty within budget'),
    ('chennai_cal_lab','RS-CHN-PRS-02','Druck DPI 620 Pressure Calibrator','pressure_calibrator',
     'national_std_npl','Meena Sundaram','2025-09-05','2026-09-05',48,
     true,true,true,71,'cal_due_soon','NIBP pressure master due in ~7 weeks — recal PO raised'),
    ('chennai_cal_lab','RS-CHN-DEF-03','Fluke Impulse 7000DP Defib Analyzer','defibrillator_analyzer',
     'oem_factory','Karthik Raman','2025-06-20','2026-06-20',-29,
     true,false,true,96,'overdue_quarantine','Cal cert expired 2026-06-20 — quarantined, CMC Vellore defib cal on hold'),
    ('gurgaon_cal_lab','RS-GGN-EMF-01','Fluke 5502A Multifunction Calibrator','electrical_multifunction',
     'nabl_lab','Rohit Malhotra','2026-03-12','2027-03-12',236,
     true,true,true,33,'in_cal_valid','Fortis Gurgaon coverage master — nominal'),
    ('gurgaon_cal_lab','RS-GGN-TMP-02','Ametek RTC-159 Temperature Dry Block','temperature_dry_block',
     'national_std_npl','Sunita Yadav','2025-08-18','2026-08-18',30,
     true,true,false,64,'cal_due_soon','Environmental log gap during May heatwave — due in ~4 weeks'),
    ('gurgaon_cal_lab','RS-GGN-ESU-03','Fluke QA-ES III ESU Analyzer','esu_analyzer',
     'oem_factory','Vikram Chauhan','2025-05-30','2026-05-30',-50,
     false,true,true,118,'uncertainty_review','RF power uncertainty exceeds budget — AIIMS Delhi ESU cal held pending review'),
    ('bengaluru_cal_lab','RS-BLR-FLW-01','IMT FlowAnalyser PF-300','flow_analyzer',
     'international','Priya Nair','2026-04-02','2027-04-02',257,
     true,true,true,27,'in_cal_valid','Ventilator flow master for Manipal Bengaluru — traceable to PTB'),
    ('bengaluru_cal_lab','RS-BLR-SPO-02','Fluke Index 2 SpO2 Simulator','spo2_simulator',
     'oem_factory','Deepak Shetty','2025-10-11','2026-10-11',84,
     true,true,true,52,'in_cal_valid','SpO2 sim quarterly verification passed'),
    ('bengaluru_cal_lab','RS-BLR-GAS-03','Fluke VT650 Gas Flow Analyzer','gas_flow_analyzer',
     'nabl_lab','Anitha Rao','2025-07-01','2026-07-01',-18,
     true,false,true,103,'overdue_quarantine','Cert lapsed 2026-07-01 — NABL recal slot delayed, quarantined'),
    ('chennai_cal_lab','RS-CHN-PRS-04','Additel 681 Pressure Calibrator','pressure_calibrator',
     'nabl_lab','Ramesh Iyer','2026-01-20','2027-01-20',185,
     true,true,true,40,'in_cal_valid','NIBP cal master for KIMS Hyderabad support — good'),
    ('gurgaon_cal_lab','RS-GGN-DEF-04','Datrend Phase 3 Defib Analyzer','defibrillator_analyzer',
     'oem_factory','Neha Sharma','2024-12-15','2025-12-15',-216,
     false,false,false,210,'retired','End-of-life — superseded by RS-GGN-DEF-05, retired from service'),
    ('field_kit','RS-FLD-EMF-01','Fluke ESA612 Electrical Safety Analyzer','electrical_multifunction',
     'oem_factory','Suresh Kumar','2026-05-05','2027-05-05',290,
     true,true,false,88,'uncertainty_review','Field kit — on-site environmental conditions not logged, uncertainty review pending'),
    ('field_kit','RS-FLD-TMP-02','Fluke 1524 Reference Thermometer','temperature_dry_block',
     'national_std_npl','Lakshmi Menon','2025-11-22','2026-11-22',126,
     true,true,true,61,'in_cal_valid','Portable temp reference for CMC Vellore site cal — good'),
    ('bengaluru_cal_lab','RS-BLR-FLW-04','TSI 4080 Flow Analyzer','flow_analyzer',
     'nabl_lab','Girish Hegde','2025-09-28','2026-09-28',71,
     true,true,true,47,'cal_due_soon','Anaesthesia flow master due Q3 — recal PO raised')
  ) as q(loc, code, model, stype, trace, eng, lastcal, due, dtd, ubo, ccv, ecl, usage, verdict, nt);

  -- CAPA seed — attach to specific standards via standard_code
  insert into public.cal_ref_standards_capa_actions_r3360 (
    standard_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('RS-CHN-DEF-03','certificate_expired','cert_lapsed_vendor_delay','renew_cal_certificate','in_progress','measurement_invalidated','2026-07-25',null,22000.00,'Defib analyzer cert renewal booked at NABL lab — interim quarantine, CMC Vellore cal on hold'),
    ('RS-GGN-ESU-03','uncertainty_out_of_budget','reference_drift','send_to_nabl_lab','escalated','iso_17025_deviation','2026-07-22',null,35000.00,'RF power uncertainty exceeds budget — escalated, AIIMS Delhi ESU cal blocked'),
    ('RS-BLR-GAS-03','recalibration_overdue','vendor_scheduling_delay','schedule_recalibration','open','nabl_nonconformity','2026-07-30',null,28000.00,'Gas flow analyzer overdue — NABL recal slot pending vendor confirmation'),
    ('RS-GGN-DEF-04','standard_damaged','physical_damage_handling','retire_standard','closed','customer_recall_risk','2026-01-10','2025-12-20',0.00,'Retired end-of-life unit — replaced; back-check of affected cal history complete'),
    ('RS-FLD-EMF-01','environmental_out_of_spec','environmental_control_failure','repair_environmental_controls','verification_pending','internal_only','2026-07-28',null,6000.00,'Field-kit environmental logging procedure fixed — verify on next site visit'),
    ('RS-GGN-TMP-02','traceability_gap','environmental_control_failure','restore_traceability_chain','overdue','iso_17025_deviation','2026-06-15',null,9000.00,'Env log gap during May — traceability documentation overdue'),
    ('RS-CHN-PRS-02','preventive_recal_due','recal_backlog','schedule_recalibration','open','none','2026-08-25',null,15000.00,'Preventive recal booked ahead of September due date')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cal_ref_standards_r3360 e
    on e.organization_id = v_org_id and e.standard_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Standard verdict distribution
create or replace function public.founder_r3360_verdict_rollup()
returns table(standard_verdict text, standards bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cal_ref_standards_r3360)
  select l.standard_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cal_ref_standards_r3360 l
  group by l.standard_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3360_verdict_rollup() from public, anon;
grant execute on function public.founder_r3360_verdict_rollup() to authenticated;

-- 2) Lab-location scorecard
create or replace function public.founder_r3360_lab_location_scorecard()
returns table(
  lab_location text,
  total_standards bigint,
  in_cal_valid bigint,
  due_soon bigint,
  overdue bigint,
  uncertainty_fail bigint,
  cert_invalid bigint,
  valid_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lab_location,
    count(*)::bigint,
    count(*) filter (where l.standard_verdict = 'in_cal_valid')::bigint,
    count(*) filter (where l.standard_verdict = 'cal_due_soon')::bigint,
    count(*) filter (where l.standard_verdict in ('overdue_quarantine','retired'))::bigint,
    count(*) filter (where l.uncertainty_budget_ok = false)::bigint,
    count(*) filter (where l.cal_certificate_valid = false)::bigint,
    round(100.0 * count(*) filter (where l.standard_verdict = 'in_cal_valid')::numeric / nullif(count(*),0), 1)
  from public.cal_ref_standards_r3360 l
  group by l.lab_location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3360_lab_location_scorecard() from public, anon;
grant execute on function public.founder_r3360_lab_location_scorecard() to authenticated;

-- 3) Standard type × traceability matrix
create or replace function public.founder_r3360_type_traceability_matrix()
returns table(standard_type text, traceable_to text, standards bigint, in_cal_valid bigint, avg_days_to_due numeric, overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.standard_type, l.traceable_to, count(*)::bigint,
    count(*) filter (where l.standard_verdict = 'in_cal_valid')::bigint,
    round(avg(l.days_to_due), 1),
    count(*) filter (where l.standard_verdict in ('overdue_quarantine','retired'))::bigint
  from public.cal_ref_standards_r3360 l
  group by l.standard_type, l.traceable_to
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3360_type_traceability_matrix() from public, anon;
grant execute on function public.founder_r3360_type_traceability_matrix() to authenticated;

-- 4) Calibration-due date trend
create or replace function public.founder_r3360_cal_due_trend()
returns table(cal_due_date date, standards bigint, in_cal_valid bigint, overdue bigint, due_soon bigint, cert_invalid bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cal_due_date,
    count(*)::bigint,
    count(*) filter (where l.standard_verdict = 'in_cal_valid')::bigint,
    count(*) filter (where l.standard_verdict in ('overdue_quarantine','retired'))::bigint,
    count(*) filter (where l.standard_verdict = 'cal_due_soon')::bigint,
    count(*) filter (where l.cal_certificate_valid = false)::bigint
  from public.cal_ref_standards_r3360 l
  group by l.cal_due_date
  order by l.cal_due_date desc;
end;
$$;

revoke execute on function public.founder_r3360_cal_due_trend() from public, anon;
grant execute on function public.founder_r3360_cal_due_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3360_capa_status_board()
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
  from public.cal_ref_standards_capa_actions_r3360 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3360_capa_status_board() from public, anon;
grant execute on function public.founder_r3360_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3360_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cal_ref_standards_capa_actions_r3360)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cal_ref_standards_capa_actions_r3360 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3360_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3360_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3360_regulatory_impact_digest()
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
  from public.cal_ref_standards_capa_actions_r3360 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3360_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3360_regulatory_impact_digest() to authenticated;

-- 8) High-risk standards queue (top individual concerns)
create or replace function public.founder_r3360_high_risk_queue()
returns table(
  lab_location text,
  standard_code text,
  standard_type text,
  cal_due_date date,
  days_to_due int,
  standard_verdict text,
  uncertainty_budget_ok boolean,
  cal_certificate_valid boolean,
  environmental_conditions_logged boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lab_location, l.standard_code, l.standard_type, l.cal_due_date,
    l.days_to_due, l.standard_verdict, l.uncertainty_budget_ok, l.cal_certificate_valid,
    l.environmental_conditions_logged, l.notes
  from public.cal_ref_standards_r3360 l
  where l.standard_verdict in ('cal_due_soon','overdue_quarantine','uncertainty_review','retired')
     or l.uncertainty_budget_ok = false
     or l.cal_certificate_valid = false
     or l.environmental_conditions_logged = false
     or l.days_to_due <= 60
  order by l.days_to_due asc, l.lab_location;
end;
$$;

revoke execute on function public.founder_r3360_high_risk_queue() from public, anon;
grant execute on function public.founder_r3360_high_risk_queue() to authenticated;
