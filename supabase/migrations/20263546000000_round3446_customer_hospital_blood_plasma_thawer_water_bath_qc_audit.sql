-- Round 3446: Customer Hospital Blood / Plasma Thawer (Water-Bath) QC Audit
-- Blood/plasma thawer QA — parameter (bath temp, uniformity delta, thaw cycle, high-temp alarm, agitation rpm, probe accuracy)
-- x reference vs measured x deviation x alarm test x calibration x verdict x CAPA closure

-- =============================================================================
-- TABLE 1: blood_plasma_thawer_qc_r3446 — per-parameter thawer QC measurements
-- =============================================================================
create table if not exists public.blood_plasma_thawer_qc_r3446 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'bath_temp_c','uniformity_delta_c','thaw_cycle_min','high_temp_alarm','agitation_rpm','probe_accuracy'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  alarm_ok boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_plasma_thawer_qc_r3446 enable row level security;

create index if not exists idx_blood_plasma_thawer_qc_r3446_org on public.blood_plasma_thawer_qc_r3446(organization_id);
create index if not exists idx_blood_plasma_thawer_qc_r3446_caldate on public.blood_plasma_thawer_qc_r3446(calibration_date);
create index if not exists idx_blood_plasma_thawer_qc_r3446_verdict on public.blood_plasma_thawer_qc_r3446(qc_verdict);

-- =============================================================================
-- TABLE 2: blood_plasma_thawer_qc_capa_actions_r3446 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.blood_plasma_thawer_qc_capa_actions_r3446 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.blood_plasma_thawer_qc_r3446(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'bath_temp_out_of_tolerance','uniformity_delta_high','thaw_cycle_time_excess',
    'high_temp_alarm_failure','agitation_rpm_deviation','probe_accuracy_drift',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'heater_element_degraded','thermostat_drift','pump_impeller_worn','temperature_probe_drift',
    'water_bath_fouling','alarm_module_fault','operator_setup_error',
    'pending_investigation','preventive_service_backlog','control_board_fault'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_temperature','replace_heater_element','replace_temperature_probe','service_agitation_pump',
    'descale_water_bath','repair_alarm_module','update_control_firmware','retrain_bank_staff',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.blood_plasma_thawer_qc_capa_actions_r3446 enable row level security;

create index if not exists idx_blood_plasma_thawer_capa_r3446_log on public.blood_plasma_thawer_qc_capa_actions_r3446(qc_log_id);
create index if not exists idx_blood_plasma_thawer_capa_r3446_status on public.blood_plasma_thawer_qc_capa_actions_r3446(capa_status);

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

  -- 16 QC measurement rows
  insert into public.blood_plasma_thawer_qc_r3446 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, alarm_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.alarm, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','THW-APL-01','Barkey Plasmatherm II','bath_temp_c',
     37.0,37.2,0.54,true,'2026-07-05','pass','Water-bath temperature within +/-1C at 37C setpoint'),
    ('Apollo Chennai','THW-APL-01','Barkey Plasmatherm II','uniformity_delta_c',
     0.50,0.30,-40.0,true,'2026-07-05','pass','Chamber uniformity 0.3C, within 0.5C spec'),
    ('Fortis Mohali','THW-FRT-11','Helmer DH8','thaw_cycle_min',
     15.0,16.5,10.0,true,'2026-07-04','conditional_pass','FFP thaw cycle 16.5 min vs 15 min target - slight overrun'),
    ('Fortis Mohali','THW-FRT-11','Helmer DH8','high_temp_alarm',
     41.0,41.0,null,true,'2026-07-04','pass','High-temp alarm tripped at 41C setpoint on test'),
    ('Manipal Bengaluru','THW-MNP-21','Sarstedt Sahara-III','agitation_rpm',
     60.0,54.0,-10.0,true,'2026-07-03','conditional_pass','Agitation 54 rpm vs 60 rpm nominal - pump service due'),
    ('Manipal Bengaluru','THW-MNP-22','Sarstedt Sahara-III','bath_temp_c',
     37.0,38.6,4.32,false,'2026-07-03','fail','Bath ran hot at 38.6C and high-temp alarm did not trip'),
    ('AIIMS Delhi','THW-AIM-31','Boekel PlasmaThaw','probe_accuracy',
     0.0,0.8,null,true,'2026-07-02','conditional_pass','Probe reads 0.8C high vs NABL reference - recalibrate'),
    ('AIIMS Delhi','THW-AIM-31','Boekel PlasmaThaw','bath_temp_c',
     37.0,37.4,1.08,true,'2026-07-02','pass','Bath temperature 37.4C acceptable within tolerance'),
    ('CMC Vellore','THW-CMC-41','CytoTherm DF-4','uniformity_delta_c',
     0.50,0.90,80.0,true,'2026-07-01','fail','Chamber uniformity 0.9C exceeds 0.5C - hot spots near heater'),
    ('CMC Vellore','THW-CMC-42','CytoTherm DF-4','thaw_cycle_min',
     15.0,14.5,-3.33,true,'2026-07-01','pass','Thaw cycle 14.5 min within target'),
    ('KIMS Hyderabad','THW-KIM-51','Helmer DH8','high_temp_alarm',
     41.0,43.5,null,false,'2026-06-30','fail','High-temp alarm failed to trip until 43.5C - patient safety risk'),
    ('KIMS Hyderabad','THW-KIM-52','Barkey Plasmatherm II','agitation_rpm',
     60.0,60.0,0.0,true,'2026-06-30','pass','Agitation rpm nominal at 60 rpm'),
    ('Yashoda Hyderabad','THW-YSH-61','Sarstedt Sahara-III','bath_temp_c',
     37.0,36.5,-1.35,true,'2026-06-29','conditional_pass','Bath slightly low at 36.5C - thermostat drift'),
    ('Kokilaben Mumbai','THW-KKB-71','Boekel PlasmaThaw','probe_accuracy',
     0.0,1.5,null,true,'2026-06-28','fail','Probe error 1.5C exceeds 1C limit - calibration overdue'),
    ('Kokilaben Mumbai','THW-KKB-72','CytoTherm DF-4','uniformity_delta_c',
     0.50,0.35,-30.0,true,'2026-06-28','pass','Chamber uniformity 0.35C within spec'),
    ('Narayana Bengaluru','THW-NAR-81','Helmer DH8','thaw_cycle_min',
     15.0,18.0,20.0,false,'2026-06-27','fail','Thaw cycle 18 min overrun and low-flow alarm inactive')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, alarm, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.blood_plasma_thawer_qc_capa_actions_r3446 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('THW-MNP-22','bath_temp_out_of_tolerance','thermostat_drift','recalibrate_temperature','in_progress','iso_15189_deviation','2026-07-08',null,18000.00,'Thermostat recalibrated; alarm trip point under re-verification'),
    ('THW-CMC-41','uniformity_delta_high','water_bath_fouling','descale_water_bath','open','nabh_finding','2026-07-07',null,9500.00,'Heater hot spots - descale water bath and re-map chamber uniformity'),
    ('THW-KIM-51','high_temp_alarm_failure','alarm_module_fault','repair_alarm_module','escalated','patient_safety_alert','2026-07-06',null,22000.00,'Alarm failed to trip until 43.5C - unit quarantined, OEM engaged'),
    ('THW-KKB-71','probe_accuracy_drift','temperature_probe_drift','replace_temperature_probe','closed','cdsco_notifiable','2026-07-05','2026-07-02',14000.00,'Probe replaced and validated against NABL reference'),
    ('THW-NAR-81','thaw_cycle_time_excess','pump_impeller_worn','service_agitation_pump','open','nabh_finding','2026-07-09',null,26000.00,'Cycle overrun with inactive low-flow alarm - pump service and alarm test'),
    ('THW-MNP-21','agitation_rpm_deviation','pump_impeller_worn','service_agitation_pump','verification_pending','internal_only','2026-07-08',null,7200.00,'Agitation pump serviced - verify rpm at next QC cycle'),
    ('THW-YSH-61','calibration_overdue','thermostat_drift','recalibrate_temperature','overdue','internal_only','2026-07-04',null,6000.00,'Bath low at 36.5C - recalibration past target date'),
    ('THW-CMC-42','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-10',null,0.00,'Annual preventive maintenance due - schedule OEM service')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.blood_plasma_thawer_qc_r3446 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3446_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_plasma_thawer_qc_r3446)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.blood_plasma_thawer_qc_r3446 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3446_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3446_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3446_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  alarm_fail bigint,
  out_of_tolerance bigint,
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
    count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 5)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.blood_plasma_thawer_qc_r3446 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3446_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3446_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3446_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, alarm_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.alarm_ok = false)::bigint
  from public.blood_plasma_thawer_qc_r3446 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3446_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3446_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3446_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, alarm_fail bigint, avg_deviation_pct numeric)
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
    round(avg(l.deviation_pct), 2)
  from public.blood_plasma_thawer_qc_r3446 l
  where l.calibration_date is not null
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3446_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3446_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3446_capa_status_board()
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
  from public.blood_plasma_thawer_qc_capa_actions_r3446 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3446_capa_status_board() from public, anon;
grant execute on function public.founder_r3446_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3446_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_plasma_thawer_qc_capa_actions_r3446)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.blood_plasma_thawer_qc_capa_actions_r3446 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3446_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3446_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter accuracy rollup)
create or replace function public.founder_r3446_accuracy_impact_digest()
returns table(parameter text, checks bigint, alarm_fail bigint, out_of_tolerance bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.alarm_ok = false)::bigint,
    count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 5)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.blood_plasma_thawer_qc_r3446 l
  group by l.parameter
  order by count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 5) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3446_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3446_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / alarm-fail concerns)
create or replace function public.founder_r3446_high_risk_queue()
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
  alarm_result text,
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct,
    case when l.alarm_ok then 'ok' else 'fail' end,
    l.notes
  from public.blood_plasma_thawer_qc_r3446 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.alarm_ok = false
     or (l.deviation_pct is not null and abs(l.deviation_pct) > 5)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3446_high_risk_queue() from public, anon;
grant execute on function public.founder_r3446_high_risk_queue() to authenticated;
