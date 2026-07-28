-- Round 3550: Customer Hospital Surgical Irrigation / Fluid-Management Pump QC Audit
-- Arthroscopy/laparoscopy irrigation & fluid-management pump QA — set/measured flow × set/measured pressure × occlusion auto-shutoff response × fluid-deficit accuracy × reference-vs-measured deviation × within-tolerance × CAPA

-- =============================================================================
-- TABLE 1: irrigation_pump_qc_r3550 — per-device irrigation/fluid-pump QC parameter checks
-- =============================================================================
create table if not exists public.irrigation_pump_qc_r3550 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'set_flow_mlmin','measured_flow_mlmin','set_pressure_mmhg','measured_pressure_mmhg','occlusion_response_sec','deficit_accuracy_ml'
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

alter table public.irrigation_pump_qc_r3550 enable row level security;

create index if not exists idx_irrigation_pump_qc_r3550_org on public.irrigation_pump_qc_r3550(organization_id);
create index if not exists idx_irrigation_pump_qc_r3550_date on public.irrigation_pump_qc_r3550(calibration_date);
create index if not exists idx_irrigation_pump_qc_r3550_verdict on public.irrigation_pump_qc_r3550(qc_verdict);

-- =============================================================================
-- TABLE 2: irrigation_pump_qc_capa_actions_r3550 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.irrigation_pump_qc_capa_actions_r3550 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.irrigation_pump_qc_r3550(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'flow_rate_out_of_tolerance','pressure_out_of_tolerance','occlusion_response_slow',
    'deficit_measurement_inaccurate','calibration_overdue','pump_mechanical_wear',
    'tubing_set_fault','sensor_drift','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'peristaltic_roller_wear','pressure_sensor_drift','flow_sensor_calibration_error','tubing_compliance_variation',
    'occlusion_valve_sticking','load_cell_drift','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_flow_sensor','recalibrate_pressure_sensor','replace_pump_head','replace_tubing_set',
    'replace_occlusion_valve','recalibrate_load_cell','update_software_config','retrain_ot_staff',
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

alter table public.irrigation_pump_qc_capa_actions_r3550 enable row level security;

create index if not exists idx_irrigation_pump_capa_r3550_log on public.irrigation_pump_qc_capa_actions_r3550(qc_log_id);
create index if not exists idx_irrigation_pump_capa_r3550_status on public.irrigation_pump_qc_capa_actions_r3550(capa_status);

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

  -- 16 QC parameter-check rows
  insert into public.irrigation_pump_qc_r3550 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','IRR-APL-01','Stryker FloSteady','set_flow_mlmin',
     300,299,0.33,true,'2026-07-05','pass','Arthroscopy pump set-flow accuracy within tolerance'),
    ('Apollo Chennai','IRR-APL-02','Stryker FloSteady','set_pressure_mmhg',
     60,60,0,true,'2026-07-05','pass','Chamber set-pressure calibration nominal'),
    ('Fortis Gurgaon','IRR-FRT-11','Arthrex DualWave','measured_flow_mlmin',
     250,268,7.2,false,'2026-07-04','conditional_pass','Measured flow 7.2% high — peristaltic roller wear suspected'),
    ('Fortis Gurgaon','IRR-FRT-12','Arthrex DualWave','measured_pressure_mmhg',
     80,92,15.0,false,'2026-07-04','fail','Chamber pressure 15% over target — pressure sensor drift'),
    ('Manipal Bengaluru','IRR-MNP-21','Karl Storz Endomat Select','occlusion_response_sec',
     2.0,4.8,140.0,false,'2026-07-03','fail','Occlusion auto-shutoff slow (4.8s vs 2.0s) — over-pressure risk'),
    ('Manipal Bengaluru','IRR-MNP-22','Karl Storz Endomat Select','set_flow_mlmin',
     200,201,0.5,true,'2026-07-03','pass','Laparoscopy irrigation set-flow nominal'),
    ('AIIMS Delhi','IRR-AIM-31','Smith Nephew DYONICS 25','deficit_accuracy_ml',
     500,540,8.0,false,'2026-07-02','conditional_pass','Fluid deficit reading 8% high — load cell recalibration advised'),
    ('AIIMS Delhi','IRR-AIM-32','Smith Nephew DYONICS 25','set_pressure_mmhg',
     70,70,0,true,'2026-07-02','pass','Pressure setpoint accurate'),
    ('CMC Vellore','IRR-CMC-41','Stryker FloSteady','measured_flow_mlmin',
     350,351,0.29,true,'2026-07-01','pass','Measured flow within tolerance'),
    ('CMC Vellore','IRR-CMC-42','Karl Storz Endomat Select','occlusion_response_sec',
     2.0,2.1,5.0,true,'2026-07-01','pass','Occlusion auto-shutoff response acceptable'),
    ('KIMS Hyderabad','IRR-KIM-51','ConMed 24K','measured_pressure_mmhg',
     90,104,15.56,false,'2026-06-30','fail','Pressure overshoot — occlusion valve sticking, removed pending service'),
    ('KIMS Hyderabad','IRR-KIM-52','ConMed 24K','deficit_accuracy_ml',
     1000,1018,1.8,true,'2026-06-30','pass','Fluid deficit accuracy within 2%'),
    ('Yashoda Hyderabad','IRR-YSH-61','Stryker FloSteady','set_flow_mlmin',
     300,315,5.0,false,'2026-06-29','conditional_pass','Set flow 5% high, calibration overdue — schedule recal'),
    ('Kokilaben Mumbai','IRR-KKB-71','Arthrex DualWave','measured_pressure_mmhg',
     75,76,1.33,true,'2026-06-29','pass','Chamber pressure accuracy nominal post-AMC'),
    ('Kokilaben Mumbai','IRR-KKB-72','Karl Storz Endomat Select','occlusion_response_sec',
     2.0,6.5,225.0,false,'2026-06-28','fail','Occlusion response critically slow — removed from service'),
    ('Medanta Gurgaon','IRR-MDT-81','Smith Nephew DYONICS 25','deficit_accuracy_ml',
     800,870,8.75,false,'2026-06-28','conditional_pass','Fluid deficit reading 8.75% high — recalibration scheduled')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — 8 rows attached to specific checks via device_code
  insert into public.irrigation_pump_qc_capa_actions_r3550 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IRR-FRT-12','pressure_out_of_tolerance','pressure_sensor_drift','recalibrate_pressure_sensor','in_progress','iso_13485_deviation','2026-07-08',null,14000.00,'Pressure sensor re-zeroed and recalibrated — verification pending'),
    ('IRR-MNP-21','occlusion_response_slow','occlusion_valve_sticking','replace_occlusion_valve','escalated','patient_safety_alert','2026-07-07',null,28000.00,'Occlusion valve sticking with over-pressure risk — escalated to OEM'),
    ('IRR-KIM-51','pressure_out_of_tolerance','occlusion_valve_sticking','remove_from_service','in_progress','cdsco_notifiable','2026-07-06',null,33000.00,'Pressure overshoot with valve fault — removed pending valve replacement'),
    ('IRR-KKB-72','occlusion_response_slow','occlusion_valve_sticking','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-30',42000.00,'Critically slow occlusion — removed, valve assembly replaced and validated'),
    ('IRR-FRT-11','flow_rate_out_of_tolerance','peristaltic_roller_wear','replace_pump_head','verification_pending','internal_only','2026-07-06',null,22000.00,'Pump head roller worn — replaced, flow re-check pending'),
    ('IRR-AIM-31','deficit_measurement_inaccurate','load_cell_drift','recalibrate_load_cell','open','nabh_finding','2026-07-05',null,6000.00,'Fluid-deficit load cell drift — recalibration in progress'),
    ('IRR-YSH-61','calibration_overdue','preventive_service_backlog','recalibrate_flow_sensor','overdue','internal_only','2026-07-02',null,4500.00,'Flow calibration past due — recal past target date, vendor delay'),
    ('IRR-MDT-81','deficit_measurement_inaccurate','load_cell_drift','recalibrate_load_cell','open','internal_only','2026-07-04',null,6500.00,'Deficit reading high — load cell recalibration scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.irrigation_pump_qc_r3550 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3550_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.irrigation_pump_qc_r3550)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.irrigation_pump_qc_r3550 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3550_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3550_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3550_device_model_scorecard()
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
  from public.irrigation_pump_qc_r3550 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3550_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3550_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3550_parameter_verdict_matrix()
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
  from public.irrigation_pump_qc_r3550 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3550_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3550_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3550_monthly_calibration_trend()
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
  from public.irrigation_pump_qc_r3550 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3550_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3550_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3550_capa_status_board()
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
  from public.irrigation_pump_qc_capa_actions_r3550 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3550_capa_status_board() from public, anon;
grant execute on function public.founder_r3550_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3550_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.irrigation_pump_qc_capa_actions_r3550)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.irrigation_pump_qc_capa_actions_r3550 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3550_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3550_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3550_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric,
  within_tolerance_pct numeric
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
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1)
  from public.irrigation_pump_qc_r3550 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc;
end;
$$;

revoke execute on function public.founder_r3550_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3550_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed concerns)
create or replace function public.founder_r3550_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
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
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.notes
  from public.irrigation_pump_qc_r3550 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or (l.parameter = 'occlusion_response_sec' and l.qc_verdict <> 'pass')
  order by l.deviation_pct desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3550_high_risk_queue() from public, anon;
grant execute on function public.founder_r3550_high_risk_queue() to authenticated;
