-- Round 3523: Customer Hospital ESR Analyzer (Erythrocyte-Sedimentation-Rate) QC Audit
-- Automated ESR analyzer QA — parameter (mm/hr accuracy, temperature, optical alignment, carryover, repeatability CV, sample volume) × device model × reference vs measured × deviation % × within-tolerance × calibration date × verdict × CAPA

-- =============================================================================
-- TABLE 1: esr_analyzer_qc_r3523 — per-parameter ESR analyzer QC checks
-- =============================================================================
create table if not exists public.esr_analyzer_qc_r3523 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'esr_mmhr_accuracy','temperature_c','optical_alignment','carryover_pct','repeatability_cv','sample_volume_ul'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esr_analyzer_qc_r3523 enable row level security;

create index if not exists idx_esr_analyzer_qc_r3523_org on public.esr_analyzer_qc_r3523(organization_id);
create index if not exists idx_esr_analyzer_qc_r3523_caldate on public.esr_analyzer_qc_r3523(calibration_date);
create index if not exists idx_esr_analyzer_qc_r3523_verdict on public.esr_analyzer_qc_r3523(qc_verdict);

-- =============================================================================
-- TABLE 2: esr_analyzer_qc_capa_actions_r3523 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.esr_analyzer_qc_capa_actions_r3523 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.esr_analyzer_qc_r3523(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'esr_accuracy_out_of_tolerance','temperature_deviation','optical_misalignment',
    'carryover_high','repeatability_poor','sample_volume_error','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'light_source_aging','optical_sensor_dirty','temperature_control_drift','pipette_wear',
    'reagent_lot_variation','software_config_error','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_analyzer','clean_optical_path','replace_light_source','service_temperature_control',
    'replace_pipette_module','requalify_reagent_lot','update_software_config','retrain_lab_staff',
    'schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esr_analyzer_qc_capa_actions_r3523 enable row level security;

create index if not exists idx_esr_analyzer_capa_r3523_log on public.esr_analyzer_qc_capa_actions_r3523(qc_log_id);
create index if not exists idx_esr_analyzer_capa_r3523_status on public.esr_analyzer_qc_capa_actions_r3523(capa_status);

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

  -- 15 QC check rows
  insert into public.esr_analyzer_qc_r3523 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','ESR-APL-01','Alifax Roller 20','esr_mmhr_accuracy',
     20, 20.6, 3.0, true,'2026-07-03','pass','Level-1 control 20 mm/hr, within plus-minus 5 pct — pass'),
    ('Apollo Chennai','ESR-APL-02','Ves-Matic Cube 30','temperature_c',
     20.0, 20.3, 1.5, true,'2026-07-03','pass','Incubation temperature within plus-minus 1 C spec'),
    ('Fortis Gurgaon','ESR-FRT-11','Vision C','esr_mmhr_accuracy',
     40, 44.0, 10.0, false,'2026-07-02','fail','High control 40 mm/hr read 44 — over plus-minus 8 pct out of tolerance'),
    ('Fortis Gurgaon','ESR-FRT-12','Alifax Roller 20','carryover_pct',
     0.0, 1.2, null, false,'2026-07-02','fail','Carryover 1.2 pct exceeds under-1-pct limit'),
    ('Manipal Bengaluru','ESR-MNP-21','ESR Star 20','repeatability_cv',
     3.0, 5.2, null, false,'2026-07-01','conditional_pass','Repeatability CV 5.2 pct above 4 pct target — flagged'),
    ('Manipal Bengaluru','ESR-MNP-22','Ves-Matic Cube 30','optical_alignment',
     100, 99.4, 0.6, true,'2026-07-01','pass','Optical channel alignment nominal'),
    ('AIIMS Delhi','ESR-AIM-31','Vision C','esr_mmhr_accuracy',
     15, 15.9, 6.0, true,'2026-06-30','conditional_pass','Low control drift plus 6 pct — recheck next lot'),
    ('AIIMS Delhi','ESR-AIM-32','Mindray ESR-M','sample_volume_ul',
     100, 92.0, 8.0, false,'2026-06-30','fail','Aspirated volume 92 uL — pipette underdraw'),
    ('CMC Vellore','ESR-CMC-41','Alifax Roller 20','esr_mmhr_accuracy',
     30, 30.6, 2.0, true,'2026-06-29','pass','Control 30 mm/hr within plus-minus 5 pct — pass'),
    ('CMC Vellore','ESR-CMC-42','ESR Star 20','temperature_c',
     20.0, 22.4, 12.0, false,'2026-06-29','fail','Incubation temperature 22.4 C — thermal control drift'),
    ('KIMS Hyderabad','ESR-KIM-51','Ves-Matic Cube 30','carryover_pct',
     0.0, 0.5, null, true,'2026-06-28','pass','Carryover 0.5 pct within limit'),
    ('KIMS Hyderabad','ESR-KIM-52','Vision C','repeatability_cv',
     3.0, 3.4, null, true,'2026-06-28','pass','Repeatability CV 3.4 pct within target'),
    ('Yashoda Hyderabad','ESR-YSH-61','Mindray ESR-M','optical_alignment',
     100, 96.5, 3.5, true,'2026-06-27','conditional_pass','Optical alignment drift 3.5 pct — clean and recheck'),
    ('Kokilaben Mumbai','ESR-KKB-71','Alifax Roller 20','esr_mmhr_accuracy',
     60, 68.0, 13.3, false,'2026-06-27','fail','Very-high control 60 mm/hr read 68 — light source aging'),
    ('Kokilaben Mumbai','ESR-KKB-72','ESR Star 20','sample_volume_ul',
     100, 99.0, 1.0, true,'2026-06-26','pass','Sample volume within plus-minus 2 pct — pass')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.esr_analyzer_qc_capa_actions_r3523 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ESR-FRT-11','esr_accuracy_out_of_tolerance','light_source_aging','replace_light_source','in_progress','iso_15189_deviation','2026-07-06',null,28000.00,'High control over plus-minus 8 pct — light source replacement scheduled'),
    ('ESR-FRT-12','carryover_high','optical_sensor_dirty','clean_optical_path','verification_pending','internal_only','2026-07-05',null,3500.00,'Carryover 1.2 pct — optical path cleaned, verify next run'),
    ('ESR-AIM-32','sample_volume_error','pipette_wear','replace_pipette_module','open','nabh_finding','2026-07-04',null,42000.00,'Pipette underdraw 92 uL — module replacement ordered'),
    ('ESR-CMC-42','temperature_deviation','temperature_control_drift','service_temperature_control','escalated','patient_safety_alert','2026-07-03',null,36000.00,'Incubation temperature drift 22.4 C — OEM thermal service escalated'),
    ('ESR-KKB-71','esr_accuracy_out_of_tolerance','light_source_aging','replace_light_source','closed','cdsco_notifiable','2026-07-02','2026-06-29',31000.00,'Very-high control error resolved — light source replaced and validated'),
    ('ESR-MNP-21','repeatability_poor','reagent_lot_variation','requalify_reagent_lot','open','internal_only','2026-07-07',null,6800.00,'CV 5.2 pct — requalify reagent lot'),
    ('ESR-AIM-31','esr_accuracy_out_of_tolerance','operator_technique_error','retrain_lab_staff','overdue','internal_only','2026-07-01',null,0.00,'Low-control drift — staff retrain past due'),
    ('ESR-YSH-61','optical_misalignment','optical_sensor_dirty','clean_optical_path','closed','none','2026-06-30','2026-06-28',2500.00,'Optical alignment drift — cleaned and realigned')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.esr_analyzer_qc_r3523 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3523_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esr_analyzer_qc_r3523)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.esr_analyzer_qc_r3523 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3523_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3523_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3523_device_model_scorecard()
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
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.esr_analyzer_qc_r3523 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3523_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3523_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3523_parameter_verdict_matrix()
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
    round(avg(l.deviation_pct), 2)
  from public.esr_analyzer_qc_r3523 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3523_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3523_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3523_monthly_accuracy_trend()
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
    round(avg(l.deviation_pct), 2)
  from public.esr_analyzer_qc_r3523 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3523_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3523_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3523_capa_status_board()
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
  from public.esr_analyzer_qc_capa_actions_r3523 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3523_capa_status_board() from public, anon;
grant execute on function public.founder_r3523_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3523_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esr_analyzer_qc_capa_actions_r3523)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.esr_analyzer_qc_capa_actions_r3523 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3523_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3523_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3523_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  in_tolerance_pct numeric,
  avg_deviation_pct numeric,
  max_deviation_pct numeric
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1),
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.esr_analyzer_qc_r3523 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3523_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3523_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3523_high_risk_queue()
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
  within_tolerance boolean,
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.within_tolerance, l.notes
  from public.esr_analyzer_qc_r3523 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.deviation_pct desc nulls last, l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3523_high_risk_queue() from public, anon;
grant execute on function public.founder_r3523_high_risk_queue() to authenticated;
