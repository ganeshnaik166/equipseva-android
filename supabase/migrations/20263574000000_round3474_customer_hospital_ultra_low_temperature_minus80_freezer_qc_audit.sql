-- Round 3474: Customer Hospital Ultra-Low-Temperature (-80C) Freezer QC Audit
-- ULT freezer QA — parameter (setpoint temp, uniformity delta, door-open recovery, high-temp alarm, compressor current, battery backup) × device model × location × reference vs measured accuracy × deviation × alarm/seal/battery integrity × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: ult_freezer_qc_r3474 — per-device ultra-low-temperature freezer QC checks
-- =============================================================================
create table if not exists public.ult_freezer_qc_r3474 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  location text not null check (location in (
    'blood_bank','pathology_lab','research_lab','pharmacy','ivf_lab','microbiology_lab'
  )),
  check_date date not null,
  parameter text not null check (parameter in (
    'setpoint_temp_c','uniformity_delta_c','door_open_recovery_min','high_temp_alarm_c','compressor_current_a','battery_backup_hr'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  alarm_ok boolean not null,
  door_seal_ok boolean not null,
  compressor_status text not null check (compressor_status in (
    'normal','degraded','noisy','fault'
  )),
  battery_backup_ok boolean not null,
  calibration_date date,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ult_freezer_qc_r3474 enable row level security;

create index if not exists idx_ult_freezer_qc_r3474_org on public.ult_freezer_qc_r3474(organization_id);
create index if not exists idx_ult_freezer_qc_r3474_date on public.ult_freezer_qc_r3474(check_date);
create index if not exists idx_ult_freezer_qc_r3474_verdict on public.ult_freezer_qc_r3474(qc_verdict);

-- =============================================================================
-- TABLE 2: ult_freezer_qc_capa_actions_r3474 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ult_freezer_qc_capa_actions_r3474 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ult_freezer_qc_r3474(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_out_of_tolerance','uniformity_deviation','door_open_recovery_slow',
    'high_temp_alarm_failure','compressor_overcurrent','battery_backup_insufficient',
    'calibration_overdue','door_seal_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compressor_degradation','door_gasket_worn','refrigerant_low','controller_calibration_drift',
    'alarm_sensor_fault','battery_end_of_life','condenser_fouling','operator_door_discipline',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_controller','replace_door_gasket','recharge_refrigerant','replace_compressor',
    'replace_alarm_sensor','replace_backup_battery','clean_condenser','retrain_lab_staff',
    'schedule_oem_service','relocate_samples','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','nabl_deviation','none','internal_only','iso_15189_deviation','sample_integrity_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ult_freezer_qc_capa_actions_r3474 enable row level security;

create index if not exists idx_ult_freezer_capa_r3474_log on public.ult_freezer_qc_capa_actions_r3474(qc_log_id);
create index if not exists idx_ult_freezer_capa_r3474_status on public.ult_freezer_qc_capa_actions_r3474(capa_status);

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
  insert into public.ult_freezer_qc_r3474 (
    organization_id, hospital_name, device_code, device_model, location, check_date,
    parameter, reference_value, measured_value, deviation_pct, within_tolerance,
    alarm_ok, door_seal_ok, compressor_status, battery_backup_ok, calibration_date,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.loc, q.cdate::date,
    q.param, q.refval, q.measval, q.devpct, q.wtol,
    q.alarm, q.seal, q.comp, q.batt, q.caldate::date,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','ULT-APL-01','Thermo TSX -86','blood_bank','2026-07-05',
     'setpoint_temp_c',-80,-79.6,0.5,true,true,true,'normal',true,'2026-01-10',true,'pass','Quarterly QC — setpoint within tolerance, plasma bank freezer'),
    ('Apollo Chennai','ULT-APL-02','Haier DW-86L','pathology_lab','2026-07-05',
     'uniformity_delta_c',5,3.2,-36.0,true,true,true,'normal',true,'2026-02-15',true,'pass','Chamber uniformity mapping well within 5C envelope'),
    ('Fortis Gurgaon','ULT-FRT-11','Panasonic MDF-DU502VH','research_lab','2026-07-04',
     'door_open_recovery_min',15,22,46.7,false,true,false,'degraded',true,'2026-01-20',true,'conditional_pass','Recovery slow after 30s door-open; gasket worn, seal leak suspected'),
    ('Fortis Gurgaon','ULT-FRT-12','Thermo TSX -86','blood_bank','2026-07-04',
     'setpoint_temp_c',-80,-74.5,6.9,false,false,false,'fault',false,'2025-12-05',false,'fail','Setpoint drift to -74.5C, alarm silent, compressor fault — samples relocated'),
    ('Manipal Bengaluru','ULT-MNP-21','Eppendorf CryoCube F740','ivf_lab','2026-07-03',
     'battery_backup_hr',4,1.5,-62.5,false,true,true,'normal',false,'2026-03-01',true,'fail','Battery backup only 1.5h vs 4h spec — end-of-life, IVF embryo store at risk'),
    ('Manipal Bengaluru','ULT-MNP-22','Blue Star ULT-500','microbiology_lab','2026-07-03',
     'compressor_current_a',8.0,8.4,5.0,true,true,true,'normal',true,'2026-02-20',true,'pass','Compressor draw nominal, strain culture archive freezer'),
    ('AIIMS Delhi','ULT-AIM-31','Thermo TSX -86','research_lab','2026-07-02',
     'high_temp_alarm_c',-70,-70.2,0.3,true,true,true,'normal',true,'2026-01-15',true,'pass','High-temp alarm trip verified at -70C setpoint'),
    ('AIIMS Delhi','ULT-AIM-32','Haier DW-86L','pharmacy','2026-07-02',
     'compressor_current_a',8.0,10.2,27.5,false,true,true,'noisy',true,'2026-02-10',true,'conditional_pass','Compressor overcurrent and audible noise — condenser fouling suspected'),
    ('CMC Vellore','ULT-CMC-41','Panasonic MDF-DU502VH','blood_bank','2026-07-01',
     'setpoint_temp_c',-80,-80.3,0.4,true,true,true,'normal',true,'2026-03-05',true,'pass','Setpoint stable, cryoprecipitate store QC pass'),
    ('CMC Vellore','ULT-CMC-42','Vestfrost VT-78','pathology_lab','2026-07-01',
     'uniformity_delta_c',5,7.8,56.0,false,true,false,'degraded',true,'2025-11-25',false,'conditional_pass','Uniformity delta 7.8C over spec and calibration overdue — remap after service'),
    ('KIMS Hyderabad','ULT-KIM-51','Thermo TSX -86','ivf_lab','2026-06-30',
     'setpoint_temp_c',-80,-79.1,1.1,true,true,true,'normal',true,'2026-03-12',true,'pass','Setpoint within tolerance, gamete cryostore freezer'),
    ('KIMS Hyderabad','ULT-KIM-52','Blue Star ULT-500','microbiology_lab','2026-06-30',
     'door_open_recovery_min',15,18,20.0,true,true,true,'normal',true,'2026-02-28',true,'conditional_pass','Recovery slightly slow but inside limit; reinforce door discipline'),
    ('Yashoda Hyderabad','ULT-YSH-61','Eppendorf CryoCube F740','research_lab','2026-06-29',
     'battery_backup_hr',4,4.2,5.0,true,true,true,'normal',true,'2026-01-30',true,'pass','Battery holdover 4.2h, biobank freezer QC nominal'),
    ('Kokilaben Mumbai','ULT-KKB-71','Panasonic MDF-DU502VH','blood_bank','2026-06-29',
     'high_temp_alarm_c',-70,-62.0,11.4,false,false,false,'fault',false,'2025-10-15',false,'fail','High-temp alarm failed to trigger at -62C, compressor fault — freezer condemned'),
    ('Kokilaben Mumbai','ULT-KKB-72','Haier DW-86L','pharmacy','2026-06-28',
     'uniformity_delta_c',5,4.1,-18.0,true,true,true,'normal',true,'2026-03-08',true,'pass','Uniformity within envelope, biologics store QC pass'),
    ('Medanta Gurgaon','ULT-MED-81','Vestfrost VT-78','ivf_lab','2026-06-28',
     'compressor_current_a',8.0,9.1,13.8,false,true,true,'noisy',true,'2026-02-05',true,'conditional_pass','Compressor current elevated, monitor trend and recharge refrigerant')
  ) as q(hosp, dcode, dmodel, loc, cdate, param, refval, measval, devpct, wtol, alarm, seal, comp, batt, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ult_freezer_qc_capa_actions_r3474 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ULT-FRT-11','door_seal_failure','door_gasket_worn','replace_door_gasket','in_progress','nabh_finding','2026-07-10',null,6500.00,'Door gasket replacement kit fitted — verify recovery time next cycle'),
    ('ULT-FRT-12','temperature_out_of_tolerance','compressor_degradation','replace_compressor','escalated','sample_integrity_alert','2026-07-08',null,145000.00,'Compressor failure with silent alarm — plasma relocated, OEM escalation raised'),
    ('ULT-MNP-21','battery_backup_insufficient','battery_end_of_life','replace_backup_battery','open','iso_15189_deviation','2026-07-09',null,28000.00,'Backup battery bank end-of-life — replacement ordered for IVF store'),
    ('ULT-AIM-32','compressor_overcurrent','condenser_fouling','clean_condenser','verification_pending','internal_only','2026-07-07',null,3500.00,'Condenser coils cleaned — verify current draw and noise on recheck'),
    ('ULT-CMC-42','calibration_overdue','controller_calibration_drift','recalibrate_controller','overdue','nabl_deviation','2026-07-03',null,12000.00,'Controller recalibration past target date — NABL cold-chain deviation logged'),
    ('ULT-KKB-71','high_temp_alarm_failure','alarm_sensor_fault','replace_alarm_sensor','closed','cdsco_notifiable','2026-07-05','2026-07-02',42000.00,'Alarm sensor replaced and freezer condemned; CDSCO notification filed'),
    ('ULT-KIM-52','door_open_recovery_slow','operator_door_discipline','retrain_lab_staff','closed','none','2026-07-04','2026-06-30',0.00,'Lab staff retrained on door-open protocol — recovery back within limit'),
    ('ULT-MED-81','compressor_overcurrent','refrigerant_low','recharge_refrigerant','open','internal_only','2026-07-11',null,9500.00,'Refrigerant top-up scheduled to reduce compressor current draw')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ult_freezer_qc_r3474 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3474_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ult_freezer_qc_r3474)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ult_freezer_qc_r3474 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3474_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3474_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3474_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  alarm_fail bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.alarm_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ult_freezer_qc_r3474 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3474_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3474_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3474_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, avg_measured_value numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    round(avg(l.measured_value), 2)
  from public.ult_freezer_qc_r3474 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3474_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3474_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration/accuracy trend
create or replace function public.founder_r3474_monthly_accuracy_trend()
returns table(month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.check_date)::date as month,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.ult_freezer_qc_r3474 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3474_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3474_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3474_capa_status_board()
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
  from public.ult_freezer_qc_capa_actions_r3474 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3474_capa_status_board() from public, anon;
grant execute on function public.founder_r3474_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3474_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ult_freezer_qc_capa_actions_r3474)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ult_freezer_qc_capa_actions_r3474 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3474_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3474_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter accuracy summary)
create or replace function public.founder_r3474_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric,
  out_of_tolerance bigint,
  failed bigint
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
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.ult_freezer_qc_r3474 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3474_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3474_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / alarm-fail concerns)
create or replace function public.founder_r3474_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  location text,
  parameter text,
  check_date date,
  qc_verdict text,
  deviation_pct numeric,
  compressor_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.location, l.parameter, l.check_date,
    l.qc_verdict, l.deviation_pct, l.compressor_status, l.notes
  from public.ult_freezer_qc_r3474 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.alarm_ok = false
     or l.door_seal_ok = false
     or l.battery_backup_ok = false
     or l.calibration_current = false
     or l.compressor_status in ('degraded','noisy','fault')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3474_high_risk_queue() from public, anon;
grant execute on function public.founder_r3474_high_risk_queue() to authenticated;
