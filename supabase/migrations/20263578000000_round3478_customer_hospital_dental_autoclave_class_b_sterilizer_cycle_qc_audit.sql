-- Round 3478: Customer Hospital Dental Class-B Autoclave Sterilizer Cycle QC Audit
-- Dental/hospital Class-B tabletop autoclave QC — cycle sterilize temp/pressure, vacuum test, Bowie-Dick, hold time, drying, BI test, accuracy deviation × verdict × CAPA

-- =============================================================================
-- TABLE 1: dental_autoclave_qc_r3478 — per-cycle Class-B autoclave QC checks
-- =============================================================================
create table if not exists public.dental_autoclave_qc_r3478 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  cycle_type text not null check (cycle_type in (
    'b_hollow_load','b_wrapped_load','b_solid_load','bowie_dick','vacuum_test','helix_test'
  )),
  parameter text not null check (parameter in (
    'sterilize_temp_c','chamber_pressure_bar','vacuum_test_pass','hold_time_min','drying_time_min','bd_test_score'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  bi_test_ok boolean not null,
  vacuum_leak_ok boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_autoclave_qc_r3478 enable row level security;

create index if not exists idx_dental_autoclave_qc_r3478_org on public.dental_autoclave_qc_r3478(organization_id);
create index if not exists idx_dental_autoclave_qc_r3478_date on public.dental_autoclave_qc_r3478(calibration_date);
create index if not exists idx_dental_autoclave_qc_r3478_verdict on public.dental_autoclave_qc_r3478(qc_verdict);

-- =============================================================================
-- TABLE 2: dental_autoclave_qc_capa_actions_r3478 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dental_autoclave_qc_capa_actions_r3478 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.dental_autoclave_qc_r3478(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sterilize_temp_out_of_tolerance','chamber_pressure_out_of_tolerance','vacuum_test_failure',
    'hold_time_short','drying_incomplete','bowie_dick_failure',
    'biological_indicator_failure','calibration_overdue','door_seal_leak','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'chamber_sensor_drift','door_gasket_worn','vacuum_pump_wear','steam_generator_scaling',
    'water_quality_poor','heater_element_degraded','operator_loading_error',
    'pending_investigation','preventive_service_backlog','control_board_fault'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_sensors','replace_door_gasket','service_vacuum_pump','descale_steam_generator',
    'improve_feed_water','replace_heater_element','retrain_cssd_staff',
    'remove_from_service','schedule_oem_service','replace_control_board','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_autoclave_qc_capa_actions_r3478 enable row level security;

create index if not exists idx_dental_autoclave_capa_r3478_log on public.dental_autoclave_qc_capa_actions_r3478(qc_log_id);
create index if not exists idx_dental_autoclave_capa_r3478_status on public.dental_autoclave_qc_capa_actions_r3478(capa_status);

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
  insert into public.dental_autoclave_qc_r3478 (
    organization_id, hospital_name, device_code, device_model, cycle_type, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, bi_test_ok, vacuum_leak_ok,
    calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.cyc, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol, q.bi, q.vac,
    q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','AUT-APL-01','Melag Vacuklav 41B+','b_wrapped_load','sterilize_temp_c',
     134.0,134.3,0.22,true,true,true,'2026-07-05',true,'pass','Wrapped-load sterilize temp within band; BI ok'),
    ('Apollo Chennai','AUT-APL-02','Melag Vacuklav 41B+','b_hollow_load','chamber_pressure_bar',
     2.10,2.12,0.95,true,true,true,'2026-07-05',true,'pass','Chamber pressure nominal at plateau'),
    ('Fortis Mohali','AUT-FRT-11','W&H Lisa 517','b_hollow_load','hold_time_min',
     3.50,3.10,-11.43,false,true,true,'2026-07-04',true,'fail','Hold time short of 3.5 min at 134C — sterility assurance failed'),
    ('Fortis Mohali','AUT-FRT-12','W&H Lisa 517','bowie_dick','bd_test_score',
     5.0,3.0,-40.0,false,true,false,'2026-07-04',true,'fail','Bowie-Dick shows central pale zone — air removal poor'),
    ('Manipal Bengaluru','AUT-MNP-21','SciCan Statim B G4','vacuum_test','vacuum_test_pass',
     null,null,null,false,true,false,'2026-07-03',true,'conditional_pass','Vacuum leak-rate borderline above 1.3 mbar/min — gasket watch'),
    ('Manipal Bengaluru','AUT-MNP-22','SciCan Statim B G4','b_solid_load','sterilize_temp_c',
     134.0,133.6,-0.30,true,true,true,'2026-07-03',true,'pass','Solid-load temp within tolerance'),
    ('AIIMS Delhi','AUT-AIM-31','Tuttnauer Elara 11','b_wrapped_load','drying_time_min',
     4.0,5.6,40.0,false,true,true,'2026-07-02',false,'conditional_pass','Drying extended, wrapped packs damp — calibration overdue'),
    ('AIIMS Delhi','AUT-AIM-32','Tuttnauer Elara 11','b_wrapped_load','chamber_pressure_bar',
     2.10,2.34,11.43,false,false,true,'2026-07-02',false,'fail','Pressure high with BI fail — removed pending service'),
    ('CMC Vellore','AUT-CMC-41','Getinge HS22','b_hollow_load','sterilize_temp_c',
     134.0,134.1,0.07,true,true,true,'2026-07-01',true,'pass','Hollow-load QC pass; all indicators nominal'),
    ('CMC Vellore','AUT-CMC-42','Getinge HS22','bowie_dick','bd_test_score',
     5.0,5.0,0.0,true,true,true,'2026-07-01',true,'pass','Bowie-Dick uniform colour change — pass'),
    ('KIMS Hyderabad','AUT-KIM-51','Euronda E10','b_wrapped_load','hold_time_min',
     3.50,3.55,1.43,true,true,true,'2026-06-30',true,'pass','Hold time meets minimum plateau'),
    ('KIMS Hyderabad','AUT-KIM-52','Euronda E10','vacuum_test','vacuum_test_pass',
     null,null,null,false,true,false,'2026-06-30',true,'fail','Vacuum test failed — leak rate 2.1 mbar/min, door gasket suspect'),
    ('Yashoda Hyderabad','AUT-YSH-61','Melag Vacuklav 41B+','b_solid_load','sterilize_temp_c',
     134.0,135.9,1.42,false,true,true,'2026-06-29',true,'conditional_pass','Temp overshoot — sensor drift flagged, recalibrate'),
    ('Yashoda Hyderabad','AUT-YSH-62','Melag Vacuklav 41B+','b_wrapped_load','hold_time_min',
     3.50,3.60,2.86,true,true,true,'2026-06-29',true,'pass','Hold time acceptable'),
    ('Kokilaben Mumbai','AUT-KKB-71','W&H Lisa 517','b_wrapped_load','bd_test_score',
     5.0,2.0,-60.0,false,false,false,'2026-06-28',false,'fail','Bowie-Dick fail, BI fail, calibration overdue — removed from service'),
    ('Kokilaben Mumbai','AUT-KKB-72','Tuttnauer Elara 11','b_hollow_load','drying_time_min',
     4.0,4.1,2.5,true,true,true,'2026-06-28',true,'pass','Drying nominal for hollow instruments')
  ) as q(hosp, dcode, dmodel, cyc, param, refv, measv, devp, wtol, bi, vac, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.dental_autoclave_qc_capa_actions_r3478 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('AUT-FRT-11','hold_time_short','steam_generator_scaling','descale_steam_generator','in_progress','iso_13485_deviation','2026-07-08',null,12000.00,'Generator descaled; re-run hold-time validation pending'),
    ('AUT-FRT-12','bowie_dick_failure','vacuum_pump_wear','service_vacuum_pump','escalated','patient_safety_alert','2026-07-07',null,18500.00,'Air-removal poor — vacuum pump service escalated to OEM'),
    ('AUT-AIM-31','calibration_overdue','chamber_sensor_drift','recalibrate_sensors','open','nabh_finding','2026-07-06',null,9000.00,'Drying extended and calibration lapsed — recalibration booked'),
    ('AUT-AIM-32','biological_indicator_failure','heater_element_degraded','replace_heater_element','escalated','cdsco_notifiable','2026-07-05',null,26000.00,'BI fail with pressure high — unit removed, heater element on order'),
    ('AUT-MNP-21','door_seal_leak','door_gasket_worn','replace_door_gasket','verification_pending','internal_only','2026-07-06',null,3500.00,'Door gasket replaced — verify leak rate next vacuum test'),
    ('AUT-KIM-52','vacuum_test_failure','door_gasket_worn','replace_door_gasket','open','nabh_finding','2026-07-04',null,3500.00,'Leak rate 2.1 mbar/min — gasket replacement scheduled'),
    ('AUT-YSH-61','sterilize_temp_out_of_tolerance','chamber_sensor_drift','recalibrate_sensors','closed','internal_only','2026-07-02','2026-06-30',9000.00,'Temp sensor recalibrated; overshoot resolved and verified'),
    ('AUT-KKB-71','bowie_dick_failure','pending_investigation','remove_from_service','overdue','patient_safety_alert','2026-06-30',null,40000.00,'Multiple failures — unit out of service, full OEM investigation overdue')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.dental_autoclave_qc_r3478 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3478_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_autoclave_qc_r3478)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dental_autoclave_qc_r3478 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3478_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3478_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3478_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  bi_fail bigint,
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
    count(*) filter (where l.bi_test_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.dental_autoclave_qc_r3478 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3478_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3478_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3478_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.dental_autoclave_qc_r3478 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3478_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3478_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3478_monthly_accuracy_trend()
returns table(month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.calibration_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.dental_autoclave_qc_r3478 l
  group by to_char(l.calibration_date, 'YYYY-MM')
  order by to_char(l.calibration_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3478_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3478_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3478_capa_status_board()
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
  from public.dental_autoclave_qc_capa_actions_r3478 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3478_capa_status_board() from public, anon;
grant execute on function public.founder_r3478_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3478_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_autoclave_qc_capa_actions_r3478)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dental_autoclave_qc_capa_actions_r3478 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3478_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3478_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3478_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  bi_fail bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric
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
    count(*) filter (where l.bi_test_ok = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.dental_autoclave_qc_r3478 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3478_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3478_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / BI-fail concerns)
create or replace function public.founder_r3478_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  bi_test_ok boolean,
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
    l.qc_verdict, l.deviation_pct, l.bi_test_ok, l.notes
  from public.dental_autoclave_qc_r3478 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.bi_test_ok = false
     or l.vacuum_leak_ok = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3478_high_risk_queue() from public, anon;
grant execute on function public.founder_r3478_high_risk_queue() to authenticated;
