-- Round 3526: Customer Hospital Transcutaneous PO2 / PCO2 Monitor QC Audit
-- tcpO2/tcpCO2 monitor QA — device model x parameter x reference vs measured x deviation x tolerance x calibration date x verdict x CAPA

-- =============================================================================
-- TABLE 1: transcutaneous_po2_qc_r3526 — per-device tcpO2/tcpCO2 QC checks
-- =============================================================================
create table if not exists public.transcutaneous_po2_qc_r3526 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'tcpo2_mmhg','tcpco2_mmhg','sensor_temp_c','drift_per_hour','membrane_response_sec','calibration_gas_accuracy'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(7,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.transcutaneous_po2_qc_r3526 enable row level security;

create index if not exists idx_transcutaneous_po2_qc_r3526_org on public.transcutaneous_po2_qc_r3526(organization_id);
create index if not exists idx_transcutaneous_po2_qc_r3526_cal on public.transcutaneous_po2_qc_r3526(calibration_date);
create index if not exists idx_transcutaneous_po2_qc_r3526_verdict on public.transcutaneous_po2_qc_r3526(qc_verdict);

-- =============================================================================
-- TABLE 2: transcutaneous_po2_qc_capa_actions_r3526 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.transcutaneous_po2_qc_capa_actions_r3526 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.transcutaneous_po2_qc_r3526(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'measurement_out_of_tolerance','sensor_temperature_drift','excessive_drift_per_hour',
    'slow_membrane_response','calibration_gas_accuracy_fail','calibration_overdue',
    'membrane_degraded','sensor_failure','reference_gas_expired','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'membrane_worn','electrolyte_depleted','sensor_temp_regulation_fault','calibration_gas_expired',
    'sensor_end_of_life','operator_calibration_error','software_config_error',
    'pending_investigation','preventive_service_backlog','contamination_on_membrane'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_membrane_electrolyte','recalibrate_with_fresh_gas','replace_sensor','adjust_sensor_temperature',
    'replace_calibration_gas','update_software_config','retrain_operator',
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

alter table public.transcutaneous_po2_qc_capa_actions_r3526 enable row level security;

create index if not exists idx_transcutaneous_po2_capa_r3526_log on public.transcutaneous_po2_qc_capa_actions_r3526(qc_log_id);
create index if not exists idx_transcutaneous_po2_capa_r3526_status on public.transcutaneous_po2_qc_capa_actions_r3526(capa_status);

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

  -- 18 QC check rows
  insert into public.transcutaneous_po2_qc_r3526 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldt::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','TCM-APL-01','Radiometer TCM5 FLEX','tcpo2_mmhg',
     80.0,78.6,1.75,true,'2026-07-03','pass','tcpO2 calibration within 5 percent tolerance'),
    ('Apollo Chennai','TCM-APL-02','Radiometer TCM5 FLEX','tcpco2_mmhg',
     40.0,40.7,1.75,true,'2026-07-03','pass','tcpCO2 within tolerance post-calibration'),
    ('Fortis Gurgaon','TCM-FRT-11','Radiometer TCM4','sensor_temp_c',
     44.0,44.6,1.36,true,'2026-07-02','conditional_pass','Sensor electrode temperature slightly high — monitor site rotation'),
    ('Fortis Gurgaon','TCM-FRT-12','Radiometer TCM4','drift_per_hour',
     1.0,1.8,80.0,false,'2026-07-02','fail','Drift 1.8 mmHg/hr exceeds 1.0 limit — membrane replacement due'),
    ('Manipal Bengaluru','SDM-MNP-21','Sentec SDM','membrane_response_sec',
     60.0,92.0,53.33,false,'2026-07-01','fail','Membrane response 92s far exceeds 60s spec — degraded membrane'),
    ('Manipal Bengaluru','SDM-MNP-22','Sentec SDM','calibration_gas_accuracy',
     100.0,99.4,0.60,true,'2026-07-01','pass','Calibration gas accuracy nominal'),
    ('AIIMS Delhi','TCM-AIM-31','Radiometer TCM5 FLEX','tcpco2_mmhg',
     40.0,43.2,8.0,false,'2026-06-30','fail','tcpCO2 8 percent high — recalibration and gas check required'),
    ('AIIMS Delhi','TCM-AIM-32','Radiometer TCM5 FLEX','tcpo2_mmhg',
     80.0,82.0,2.50,true,'2026-06-30','conditional_pass','tcpO2 within tolerance but upward drift trend flagged'),
    ('CMC Vellore','SDM-CMC-41','Sentec V-Sign','sensor_temp_c',
     43.5,43.6,0.23,true,'2026-06-29','pass','Sensor electrode temperature stable'),
    ('CMC Vellore','SDM-CMC-42','Sentec V-Sign','drift_per_hour',
     1.0,0.6,-40.0,true,'2026-06-29','pass','Drift well within limits'),
    ('KIMS Hyderabad','TCM-KIM-51','Radiometer TCM4','membrane_response_sec',
     60.0,68.0,13.33,true,'2026-06-28','conditional_pass','Membrane response marginally slow — schedule replacement'),
    ('KIMS Hyderabad','TCM-KIM-52','Radiometer TCM4','calibration_gas_accuracy',
     100.0,96.5,3.50,false,'2026-06-28','fail','Calibration gas accuracy 96.5 percent — cylinder expired'),
    ('Yashoda Hyderabad','SDM-YSH-61','Sentec SDM','tcpo2_mmhg',
     80.0,79.1,1.13,true,'2026-06-27','pass','tcpO2 calibration nominal post-AMC'),
    ('Kokilaben Mumbai','TCM-KKB-71','Radiometer TCM5 FLEX','drift_per_hour',
     1.0,2.4,140.0,false,'2026-06-27','fail','Excessive drift 2.4 mmHg/hr — sensor end of life, removed'),
    ('Kokilaben Mumbai','TCM-KKB-72','Radiometer TCM5 FLEX','sensor_temp_c',
     44.0,45.2,2.73,false,'2026-06-26','fail','Sensor temp 45.2C exceeds safe limit — temperature regulation fault'),
    ('Narayana Bengaluru','SDM-NAR-81','Sentec SDM','tcpco2_mmhg',
     40.0,40.3,0.75,true,'2026-05-30','pass','tcpCO2 monthly QC pass'),
    ('Narayana Bengaluru','SDM-NAR-82','Sentec V-Sign','calibration_gas_accuracy',
     100.0,99.8,0.20,true,'2026-05-30','pass','Calibration gas accuracy nominal'),
    ('Medanta Gurgaon','TCM-MED-91','Radiometer TCM4','membrane_response_sec',
     60.0,110.0,83.33,false,'2026-06-15','fail','Membrane response 110s — contamination on membrane, removed from service')
  ) as q(hosp, dcode, model, param, refv, measv, devp, wtol, caldt, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.transcutaneous_po2_qc_capa_actions_r3526 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TCM-FRT-12','excessive_drift_per_hour','membrane_worn','replace_membrane_electrolyte','in_progress','iso_13485_deviation','2026-07-06',null,3500.00,'Membrane and electrolyte replaced — verifying drift'),
    ('SDM-MNP-21','slow_membrane_response','membrane_worn','replace_membrane_electrolyte','open','nabh_finding','2026-07-05',null,4200.00,'Sentec membrane past service life — kit ordered'),
    ('TCM-AIM-31','calibration_gas_accuracy_fail','calibration_gas_expired','recalibrate_with_fresh_gas','verification_pending','internal_only','2026-07-04',null,2800.00,'Recalibrated with fresh cal gas — verify tcpCO2 next case'),
    ('TCM-KIM-52','calibration_overdue','calibration_gas_expired','replace_calibration_gas','closed','none','2026-07-02','2026-06-30',6500.00,'Expired cylinder replaced and unit recalibrated'),
    ('TCM-KKB-71','sensor_failure','sensor_end_of_life','replace_sensor','escalated','cdsco_notifiable','2026-07-03',null,48000.00,'Sensor at end of life — OEM replacement escalated'),
    ('TCM-KKB-72','sensor_temperature_drift','sensor_temp_regulation_fault','adjust_sensor_temperature','overdue','patient_safety_alert','2026-06-30',null,12000.00,'Temperature regulation fault — burn risk, past target date'),
    ('TCM-MED-91','membrane_degraded','contamination_on_membrane','remove_from_service','closed','iso_13485_deviation','2026-06-18','2026-06-16',5200.00,'Contaminated membrane cleaned and replaced; validated'),
    ('TCM-AIM-32','sensor_temperature_drift','operator_calibration_error','retrain_operator','open','internal_only','2026-07-05',null,0.00,'Operator retraining on tcpO2 site preparation scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.transcutaneous_po2_qc_r3526 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3526_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transcutaneous_po2_qc_r3526)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.transcutaneous_po2_qc_r3526 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3526_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3526_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3526_device_model_scorecard()
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
  from public.transcutaneous_po2_qc_r3526 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3526_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3526_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3526_parameter_verdict_matrix()
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
  from public.transcutaneous_po2_qc_r3526 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3526_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3526_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3526_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date as cal_month,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.transcutaneous_po2_qc_r3526 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3526_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3526_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3526_capa_status_board()
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
  from public.transcutaneous_po2_qc_capa_actions_r3526 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3526_capa_status_board() from public, anon;
grant execute on function public.founder_r3526_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3526_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transcutaneous_po2_qc_capa_actions_r3526)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.transcutaneous_po2_qc_capa_actions_r3526 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3526_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3526_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (regulatory impact of accuracy findings)
create or replace function public.founder_r3526_accuracy_impact_digest()
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
  from public.transcutaneous_po2_qc_capa_actions_r3526 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3526_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3526_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3526_high_risk_queue()
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
  from public.transcutaneous_po2_qc_r3526 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3526_high_risk_queue() from public, anon;
grant execute on function public.founder_r3526_high_risk_queue() to authenticated;
