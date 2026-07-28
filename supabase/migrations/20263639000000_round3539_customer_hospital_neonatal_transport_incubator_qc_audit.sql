-- Round 3539: Customer Hospital Neonatal Transport Incubator QC Audit
-- Neonatal transport incubator QA — device model × transport context × parameter (air/skin temp, battery
-- runtime, O2 concentration, alarm response, vibration damping) × reference vs measured × deviation ×
-- alarm test × calibration currency × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: transport_incubator_qc_r3539 — per-parameter transport incubator QC checks
-- =============================================================================
create table if not exists public.transport_incubator_qc_r3539 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  transport_context text not null check (transport_context in (
    'inter_hospital','intra_hospital','ambulance','air_transport'
  )),
  parameter text not null check (parameter in (
    'air_temp_c','skin_temp_c','battery_runtime_min','o2_concentration_pct','alarm_response_sec','vibration_damping'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  alarm_ok boolean not null,
  battery_health_pct numeric(5,2),
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.transport_incubator_qc_r3539 enable row level security;

create index if not exists idx_transport_incubator_qc_r3539_org on public.transport_incubator_qc_r3539(organization_id);
create index if not exists idx_transport_incubator_qc_r3539_date on public.transport_incubator_qc_r3539(calibration_date);
create index if not exists idx_transport_incubator_qc_r3539_verdict on public.transport_incubator_qc_r3539(qc_verdict);

-- =============================================================================
-- TABLE 2: transport_incubator_qc_capa_actions_r3539 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.transport_incubator_qc_capa_actions_r3539 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.transport_incubator_qc_r3539(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'air_temp_out_of_tolerance','skin_temp_out_of_tolerance','battery_runtime_short',
    'o2_concentration_out_of_tolerance','alarm_response_slow','vibration_damping_degraded',
    'calibration_overdue','alarm_failure','sensor_drift','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'temperature_sensor_drift','heater_element_fault','battery_end_of_life','o2_sensor_degraded',
    'alarm_module_fault','suspension_mount_worn','calibration_lapsed','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_sensor','replace_temperature_sensor','replace_battery_pack','replace_o2_sensor',
    'repair_alarm_module','replace_suspension_mounts','schedule_calibration','retrain_transport_team',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.transport_incubator_qc_capa_actions_r3539 enable row level security;

create index if not exists idx_transport_incubator_capa_r3539_log on public.transport_incubator_qc_capa_actions_r3539(qc_log_id);
create index if not exists idx_transport_incubator_capa_r3539_status on public.transport_incubator_qc_capa_actions_r3539(capa_status);

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
  insert into public.transport_incubator_qc_r3539 (
    organization_id, hospital_name, device_code, device_model, transport_context, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, alarm_ok, battery_health_pct,
    calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.tctx, q.param,
    q.refv, q.measv, q.devp, q.wtol, q.alarm, q.bhp,
    q.cdate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','TI-APL-01','Draeger TI500','inter_hospital','air_temp_c',
     36.0,36.2,0.6,true,true,96.0,'2026-07-05',true,'pass','Air temp within +/-0.5C — transport incubator QC pass'),
    ('Apollo Chennai','TI-APL-02','GE Giraffe Shuttle','ambulance','battery_runtime_min',
     120,118,-1.7,true,true,94.0,'2026-07-05',true,'pass','Battery runtime 118 min meets 120 min target'),
    ('Fortis Gurgaon','TI-FRT-11','Atom V-808','intra_hospital','skin_temp_c',
     36.5,37.1,1.6,true,true,88.0,'2026-07-04',true,'conditional_pass','Skin temp reads 0.6C high — servo probe recheck advised'),
    ('Fortis Gurgaon','TI-FRT-12','Draeger TI500','inter_hospital','o2_concentration_pct',
     40.0,34.0,-15.0,false,true,90.0,'2026-07-04',true,'fail','O2 blender delivering 34% vs 40% set — out of tolerance'),
    ('Manipal Bengaluru','TI-MNP-21','Fanem IT-158','ambulance','alarm_response_sec',
     10.0,22.0,120.0,false,false,72.0,'2026-07-03',true,'fail','High-temp alarm delayed to 22s and audible alarm weak'),
    ('Manipal Bengaluru','TI-MNP-22','GE Giraffe Shuttle','air_transport','vibration_damping',
     0.30,0.31,3.3,true,true,91.0,'2026-07-03',true,'pass','Vibration damping ratio nominal for air ambulance use'),
    ('AIIMS Delhi','TI-AIM-31','Phoenix Trans-Warm','inter_hospital','air_temp_c',
     36.0,35.4,-1.7,true,true,89.0,'2026-06-30',true,'conditional_pass','Air temp 0.6C low with slow warm-up — heater watch'),
    ('AIIMS Delhi','TI-AIM-32','Draeger TI500','ambulance','battery_runtime_min',
     120,74,-38.3,false,true,55.0,'2026-06-30',true,'fail','Battery runtime only 74 min — pack degraded, below target'),
    ('CMC Vellore','TI-CMC-41','Atom V-808','intra_hospital','skin_temp_c',
     36.5,36.6,0.3,true,true,93.0,'2026-06-29',true,'pass','Skin servo temp accurate — QC pass'),
    ('CMC Vellore','TI-CMC-42','Fanem IT-158','inter_hospital','o2_concentration_pct',
     40.0,41.5,3.8,true,true,87.0,'2026-06-29',false,'conditional_pass','O2 slightly high and calibration overdue — schedule cal'),
    ('KIMS Hyderabad','TI-KIM-51','GE Giraffe Shuttle','ambulance','air_temp_c',
     36.0,36.1,0.3,true,true,95.0,'2026-06-28',true,'pass','Post-AMC transport incubator QC pass'),
    ('KIMS Hyderabad','TI-KIM-52','Phoenix Trans-Warm','intra_hospital','alarm_response_sec',
     10.0,9.0,-10.0,true,true,90.0,'2026-06-28',true,'pass','Alarm response 9s within limit'),
    ('Yashoda Hyderabad','TI-YSH-61','Fanem IT-158','air_transport','vibration_damping',
     0.30,0.42,40.0,false,true,84.0,'2026-06-27',false,'fail','Suspension mounts worn — damping degraded, cal overdue'),
    ('Kokilaben Mumbai','TI-KKB-71','Draeger TI500','inter_hospital','o2_concentration_pct',
     40.0,40.2,0.5,true,true,92.0,'2026-06-27',true,'pass','O2 concentration accurate — QC pass'),
    ('Kokilaben Mumbai','TI-KKB-72','Atom V-808','ambulance','battery_runtime_min',
     120,60,-50.0,false,false,40.0,'2026-06-26',false,'fail','Battery under 60 min, alarm mute fault and cal overdue — removed'),
    ('Rainbow Hyderabad','TI-RBW-81','Weyer Globe-Trotter','intra_hospital','skin_temp_c',
     36.5,38.2,4.7,false,true,86.0,'2026-06-26',true,'fail','Skin temp 1.7C high — sensor drift, out of tolerance')
  ) as q(hosp, dcode, dmodel, tctx, param, refv, measv, devp, wtol, alarm, bhp, cdate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.transport_incubator_qc_capa_actions_r3539 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TI-FRT-12','o2_concentration_out_of_tolerance','o2_sensor_degraded','replace_o2_sensor','in_progress','iso_13485_deviation','2026-07-08',null,21000.00,'O2 sensor replaced; verify blender output next transport'),
    ('TI-MNP-21','alarm_response_slow','alarm_module_fault','repair_alarm_module','escalated','patient_safety_alert','2026-07-06',null,15500.00,'Delayed alarm — escalated to OEM for module repair'),
    ('TI-AIM-32','battery_runtime_short','battery_end_of_life','replace_battery_pack','open','nabh_finding','2026-07-07',null,34000.00,'Battery pack past life — replacement ordered'),
    ('TI-KKB-72','battery_runtime_short','battery_end_of_life','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-29',41000.00,'Removed from service; replacement unit validated'),
    ('TI-FRT-11','skin_temp_out_of_tolerance','temperature_sensor_drift','recalibrate_sensor','verification_pending','internal_only','2026-07-08',null,3800.00,'Servo skin probe recalibrated — verify next case'),
    ('TI-YSH-61','vibration_damping_degraded','suspension_mount_worn','replace_suspension_mounts','overdue','internal_only','2026-07-01',null,12500.00,'Suspension mounts replacement past target — vendor delay'),
    ('TI-CMC-42','calibration_overdue','calibration_lapsed','schedule_calibration','open','none','2026-07-09',null,2500.00,'Calibration scheduled with biomed'),
    ('TI-RBW-81','sensor_drift','temperature_sensor_drift','replace_temperature_sensor','in_progress','iso_13485_deviation','2026-07-05',null,9800.00,'Skin temp sensor replaced due to drift — verifying accuracy')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.transport_incubator_qc_r3539 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3539_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transport_incubator_qc_r3539)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.transport_incubator_qc_r3539 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3539_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3539_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3539_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  alarm_fail bigint,
  out_of_tolerance bigint,
  calibration_expired bigint,
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
    count(*) filter (where l.alarm_ok = false)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.transport_incubator_qc_r3539 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3539_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3539_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3539_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, avg_measured numeric)
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
  from public.transport_incubator_qc_r3539 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3539_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3539_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3539_monthly_accuracy_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, alarm_fail bigint, avg_abs_deviation_pct numeric)
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
    count(*) filter (where l.alarm_ok = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.transport_incubator_qc_r3539 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3539_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3539_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3539_capa_status_board()
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
  from public.transport_incubator_qc_capa_actions_r3539 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3539_capa_status_board() from public, anon;
grant execute on function public.founder_r3539_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3539_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transport_incubator_qc_capa_actions_r3539)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.transport_incubator_qc_capa_actions_r3539 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3539_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3539_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (deviation-band rollup)
create or replace function public.founder_r3539_accuracy_impact_digest()
returns table(deviation_band text, checks bigint, out_of_tolerance bigint, alarm_fail bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with banded as (
    select case
             when abs(coalesce(l.deviation_pct,0)) <= 2 then 'within_2pct'
             when abs(coalesce(l.deviation_pct,0)) <= 5 then '2_to_5pct'
             when abs(coalesce(l.deviation_pct,0)) <= 15 then '5_to_15pct'
             else 'over_15pct'
           end as deviation_band,
           l.within_tolerance, l.alarm_ok, l.deviation_pct
    from public.transport_incubator_qc_r3539 l
  )
  select b.deviation_band, count(*)::bigint,
    count(*) filter (where b.within_tolerance = false)::bigint,
    count(*) filter (where b.alarm_ok = false)::bigint,
    round(avg(abs(b.deviation_pct)), 2)
  from banded b
  group by b.deviation_band
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3539_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3539_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / alarm-fail / overdue)
create or replace function public.founder_r3539_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  transport_context text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  alarm_status text,
  tolerance_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.transport_context,
    l.calibration_date, l.qc_verdict, l.deviation_pct,
    case when l.alarm_ok then 'ok' else 'alarm_fail' end,
    case when l.within_tolerance then 'within_tolerance' else 'out_of_tolerance' end,
    l.notes
  from public.transport_incubator_qc_r3539 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.alarm_ok = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3539_high_risk_queue() from public, anon;
grant execute on function public.founder_r3539_high_risk_queue() to authenticated;
