-- Round 3531: Customer Hospital Cardiac-Output Monitor (PiCCO / FloTrac) Hemodynamic QC Audit
-- Cardiac-output monitor hemodynamic QC — parameter (CO/CI, SVV, pressure accuracy, thermistor temp, signal stability, zero drift) × device model × reference vs measured × deviation × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: cardiac_output_qc_r3531 — per-parameter cardiac-output monitor QC checks
-- =============================================================================
create table if not exists public.cardiac_output_qc_r3531 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'cardiac_output_lpm','svv_pct','pressure_accuracy_mmhg','thermistor_temp_c','signal_stability','zero_drift'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cardiac_output_qc_r3531 enable row level security;

create index if not exists idx_cardiac_output_qc_r3531_org on public.cardiac_output_qc_r3531(organization_id);
create index if not exists idx_cardiac_output_qc_r3531_caldate on public.cardiac_output_qc_r3531(calibration_date);
create index if not exists idx_cardiac_output_qc_r3531_verdict on public.cardiac_output_qc_r3531(qc_verdict);

-- =============================================================================
-- TABLE 2: cardiac_output_qc_capa_actions_r3531 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cardiac_output_qc_capa_actions_r3531 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cardiac_output_qc_r3531(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cardiac_output_out_of_tolerance','svv_reading_drift','pressure_accuracy_out_of_tolerance',
    'thermistor_temp_error','signal_instability','zero_drift_excess',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'thermistor_sensor_degraded','pressure_transducer_drift','flotrac_sensor_expired',
    'picco_catheter_fault','cable_connector_damaged','software_config_error',
    'operator_setup_error','zeroing_reference_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'rezero_and_recalibrate','replace_thermistor_sensor','replace_pressure_transducer',
    'replace_flotrac_sensor','replace_picco_catheter','replace_cable',
    'update_software_config','retrain_icu_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.cardiac_output_qc_capa_actions_r3531 enable row level security;

create index if not exists idx_cardiac_output_capa_r3531_log on public.cardiac_output_qc_capa_actions_r3531(qc_log_id);
create index if not exists idx_cardiac_output_capa_r3531_status on public.cardiac_output_qc_capa_actions_r3531(capa_status);

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
  insert into public.cardiac_output_qc_r3531 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','PICCO-APL-01','Getinge PiCCO2','cardiac_output_lpm',
     5.0,5.1,2.0,true,'2026-07-05','pass','CO calibration within plus/minus 10% tolerance'),
    ('Apollo Chennai','PICCO-APL-02','Getinge PiCCO2','pressure_accuracy_mmhg',
     100.0,98.5,1.5,true,'2026-07-05','pass','Arterial pressure accuracy nominal'),
    ('Fortis Gurgaon','FLOT-FRT-11','Edwards HemoSphere','svv_pct',
     12.0,13.1,9.2,true,'2026-07-04','conditional_pass','SVV reading drift 9.2% near tolerance — monitor next cycle'),
    ('Fortis Gurgaon','FLOT-FRT-12','Edwards EV1000 FloTrac','cardiac_output_lpm',
     4.8,5.6,16.7,false,'2026-07-04','fail','CO deviation 16.7% out of plus/minus 10% — sensor suspect'),
    ('Manipal Bengaluru','PICCO-MNP-21','Pulsion PiCCO Plus','thermistor_temp_c',
     37.0,37.2,0.5,true,'2026-07-03','pass','Thermistor temperature accuracy good'),
    ('Manipal Bengaluru','PICCO-MNP-22','Pulsion PiCCO Plus','zero_drift',
     0.0,2.5,12.0,false,'2026-07-03','fail','Zero drift 2.5 mmHg exceeds limit — re-zero required'),
    ('AIIMS Delhi','FLOT-AIM-31','Edwards HemoSphere','cardiac_output_lpm',
     5.2,5.3,1.9,true,'2026-07-02','pass','HemoSphere CO within tolerance post-AMC'),
    ('AIIMS Delhi','FLOT-AIM-32','Edwards Vigileo','signal_stability',
     100.0,91.0,9.0,true,'2026-07-02','conditional_pass','Signal stability 91% — intermittent noise flagged'),
    ('CMC Vellore','PICCO-CMC-41','Getinge PiCCO2','pressure_accuracy_mmhg',
     120.0,112.0,6.7,true,'2026-07-01','conditional_pass','Pressure accuracy 6.7% drift — recheck next cycle'),
    ('CMC Vellore','FLOT-CMC-42','Edwards EV1000 FloTrac','svv_pct',
     10.0,10.3,3.0,true,'2026-07-01','pass','SVV within tolerance'),
    ('KIMS Hyderabad','PICCO-KIM-51','Pulsion PiCCO Plus','thermistor_temp_c',
     37.0,37.8,2.2,false,'2026-06-30','fail','Thermistor temp error 0.8C — bath verification failed'),
    ('KIMS Hyderabad','FLOT-KIM-52','Edwards HemoSphere','cardiac_output_lpm',
     4.5,4.6,2.2,true,'2026-06-30','pass','CO calibration pass'),
    ('Yashoda Hyderabad','PICCO-YSH-61','Getinge PiCCO2','zero_drift',
     0.0,0.4,2.0,true,'2026-06-29','pass','Zero drift within plus/minus 1 mmHg'),
    ('Yashoda Hyderabad','FLOT-YSH-62','Edwards Vigileo','signal_stability',
     100.0,82.0,18.0,false,'2026-06-29','fail','Signal stability 82% — cable noise, unstable trace'),
    ('Kokilaben Mumbai','PICCO-KKB-71','Pulsion PiCCO Plus','pressure_accuracy_mmhg',
     100.0,88.0,12.0,false,'2026-06-28','fail','Pressure transducer 12% error — out of tolerance'),
    ('Kokilaben Mumbai','FLOT-KKB-72','Edwards EV1000 FloTrac','svv_pct',
     14.0,14.4,2.9,true,'2026-06-28','pass','SVV accuracy nominal')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cardiac_output_qc_capa_actions_r3531 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FLOT-FRT-12','cardiac_output_out_of_tolerance','flotrac_sensor_expired','replace_flotrac_sensor','in_progress','iso_13485_deviation','2026-07-08',null,18000.00,'FloTrac sensor past 24h dwell — replacement in progress'),
    ('PICCO-MNP-22','zero_drift_excess','pressure_transducer_drift','rezero_and_recalibrate','open','nabh_finding','2026-07-07',null,6000.00,'Transducer re-zero scheduled — verify drift on recheck'),
    ('PICCO-KIM-51','thermistor_temp_error','thermistor_sensor_degraded','replace_thermistor_sensor','escalated','patient_safety_alert','2026-07-06',null,22000.00,'Thermistor bath verification failed — escalated to OEM'),
    ('FLOT-YSH-62','signal_instability','cable_connector_damaged','replace_cable','closed','internal_only','2026-07-05','2026-07-02',4800.00,'Cable replaced, signal restored and validated'),
    ('PICCO-KKB-71','pressure_accuracy_out_of_tolerance','pressure_transducer_drift','replace_pressure_transducer','verification_pending','cdsco_notifiable','2026-07-06',null,26000.00,'Transducer replaced — verify accuracy next case'),
    ('FLOT-FRT-11','svv_reading_drift','software_config_error','update_software_config','open','none','2026-07-09',null,0.00,'HemoSphere SVV filter reconfigured — recheck due'),
    ('FLOT-AIM-32','signal_instability','operator_setup_error','retrain_icu_staff','overdue','internal_only','2026-06-30',null,1500.00,'Vigileo setup retraining past target date'),
    ('PICCO-CMC-41','calibration_overdue','preventive_service_backlog','schedule_oem_service','in_progress','iso_13485_deviation','2026-07-10',null,9000.00,'Preventive maintenance overdue — OEM service scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cardiac_output_qc_r3531 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3531_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cardiac_output_qc_r3531)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cardiac_output_qc_r3531 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3531_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3531_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3531_device_model_scorecard()
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
  from public.cardiac_output_qc_r3531 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3531_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3531_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3531_parameter_verdict_matrix()
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
  from public.cardiac_output_qc_r3531 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3531_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3531_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3531_monthly_calibration_trend()
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
  from public.cardiac_output_qc_r3531 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3531_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3531_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3531_capa_status_board()
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
  from public.cardiac_output_qc_capa_actions_r3531 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3531_capa_status_board() from public, anon;
grant execute on function public.founder_r3531_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3531_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cardiac_output_qc_capa_actions_r3531)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cardiac_output_qc_capa_actions_r3531 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3531_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3531_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3531_accuracy_impact_digest()
returns table(parameter text, checks bigint, within_tol bigint, out_of_tol bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.cardiac_output_qc_r3531 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3531_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3531_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3531_high_risk_queue()
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
  from public.cardiac_output_qc_r3531 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3531_high_risk_queue() from public, anon;
grant execute on function public.founder_r3531_high_risk_queue() to authenticated;
