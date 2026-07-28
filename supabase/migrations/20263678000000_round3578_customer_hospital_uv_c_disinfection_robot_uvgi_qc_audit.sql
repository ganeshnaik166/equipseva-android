-- Round 3578: Customer Hospital UV-C Disinfection Robot (UVGI) QC Audit
-- Hospital UV-C disinfection robot (UVGI) QC — device model × parameter (UV dose, lamp output,
-- cycle time, coverage, motion sensor, lamp hours) × reference vs measured × deviation × tolerance
-- × calibration × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: uvc_disinfection_qc_r3578 — per-device UV-C / UVGI QC checks
-- =============================================================================
create table if not exists public.uvc_disinfection_qc_r3578 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'uv_dose_mjcm2','lamp_output_uwcm2','cycle_time_min','coverage_pct','motion_sensor_ok','lamp_hours_used'
  )),
  reference_value numeric(12,2),
  measured_value numeric(12,2),
  deviation_pct numeric(7,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.uvc_disinfection_qc_r3578 enable row level security;

create index if not exists idx_uvc_disinfection_qc_r3578_org on public.uvc_disinfection_qc_r3578(organization_id);
create index if not exists idx_uvc_disinfection_qc_r3578_date on public.uvc_disinfection_qc_r3578(calibration_date);
create index if not exists idx_uvc_disinfection_qc_r3578_verdict on public.uvc_disinfection_qc_r3578(qc_verdict);

-- =============================================================================
-- TABLE 2: uvc_disinfection_qc_capa_actions_r3578 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.uvc_disinfection_qc_capa_actions_r3578 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.uvc_disinfection_qc_r3578(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'uv_dose_below_spec','lamp_output_degraded','cycle_time_out_of_spec','coverage_gap',
    'motion_sensor_failure','lamp_hours_exceeded','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lamp_end_of_life','ballast_degraded','sensor_drift','reflector_dust_fouling','positioning_error',
    'software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog','power_supply_fault'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_uv_lamp','replace_ballast','recalibrate_radiometer','clean_reflectors','reposition_robot',
    'update_cycle_config','retrain_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.uvc_disinfection_qc_capa_actions_r3578 enable row level security;

create index if not exists idx_uvc_disinfection_capa_r3578_log on public.uvc_disinfection_qc_capa_actions_r3578(qc_log_id);
create index if not exists idx_uvc_disinfection_capa_r3578_status on public.uvc_disinfection_qc_capa_actions_r3578(capa_status);

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

  -- 16 UV-C QC check rows
  insert into public.uvc_disinfection_qc_r3578 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','UVC-APL-01','Xenex-LightStrike','uv_dose_mjcm2',
     30,31.2,4.0,true,'2026-07-05','pass','Terminal OR clean — pulsed-xenon UV dose within spec'),
    ('Apollo Chennai','UVC-APL-01','Xenex-LightStrike','coverage_pct',
     95,96.5,1.6,true,'2026-07-05','pass','Coverage mapping nominal across OR-3'),
    ('Fortis Gurgaon','UVC-FRT-11','Tru-D-SmartUVC','lamp_output_uwcm2',
     12000,9800,-18.3,false,'2026-07-04','conditional_pass','Lamp irradiance degraded — replacement scheduled'),
    ('Fortis Gurgaon','UVC-FRT-11','Tru-D-SmartUVC','uv_dose_mjcm2',
     36,27,-25.0,false,'2026-07-04','fail','UV dose below spec due to lamp degradation'),
    ('Manipal Bengaluru','UVC-MNP-21','Surfacide-Helios','cycle_time_min',
     15,15.5,3.3,true,'2026-07-03','pass','Three-emitter cycle time nominal in ICU isolation room'),
    ('Manipal Bengaluru','UVC-MNP-21','Surfacide-Helios','motion_sensor_ok',
     1,1,0.0,true,'2026-07-03','pass','PIR motion safety sensor interlock functional'),
    ('AIIMS Delhi','UVC-AIM-31','Xenex-LightStrike','lamp_hours_used',
     9000,9450,5.0,false,'2026-06-30','conditional_pass','Lamp hours exceeded rated life — monitor output'),
    ('AIIMS Delhi','UVC-AIM-31','Xenex-LightStrike','motion_sensor_ok',
     1,0,-100.0,false,'2026-06-30','fail','Motion safety sensor failed — interlock not tripping on entry'),
    ('CMC Vellore','UVC-CMC-41','Tru-D-SmartUVC','uv_dose_mjcm2',
     32,33.1,3.4,true,'2026-06-29','pass','Sensor-driven dosing verified against radiometer'),
    ('CMC Vellore','UVC-CMC-42','UVD-Robots-ModelC','coverage_pct',
     95,82,-13.7,false,'2026-06-29','fail','Coverage gap behind equipment — shadowing in ward bay'),
    ('KIMS Hyderabad','UVC-KIM-51','Surfacide-Helios','lamp_output_uwcm2',
     12000,11800,-1.7,true,'2026-06-28','pass','Emitter output within tolerance post-service'),
    ('KIMS Hyderabad','UVC-KIM-52','UVD-Robots-ModelC','cycle_time_min',
     20,24,20.0,false,'2026-06-28','conditional_pass','Cycle time extended — reflectors dust-fouled'),
    ('Yashoda Hyderabad','UVC-YSH-61','Xenex-LightStrike','uv_dose_mjcm2',
     30,30.5,1.7,true,'2026-06-27','pass','Pulsed-xenon dose nominal in cath lab'),
    ('Kokilaben Mumbai','UVC-KKB-71','Tru-D-SmartUVC','lamp_output_uwcm2',
     12000,6200,-48.3,false,'2026-06-27','fail','Severe irradiance loss — ballast fault, removed from service'),
    ('Kokilaben Mumbai','UVC-KKB-72','UVD-Robots-ModelC','lamp_hours_used',
     9000,8700,-3.3,true,'2026-06-26','pass','Lamp hours within rated life'),
    ('Narayana Bengaluru','UVC-NAR-81','Surfacide-Helios','coverage_pct',
     95,94,-1.1,true,'2026-06-26','conditional_pass','Minor coverage shortfall — reposition emitters')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code + parameter
  insert into public.uvc_disinfection_qc_capa_actions_r3578 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('UVC-FRT-11','lamp_output_uwcm2','lamp_output_degraded','lamp_end_of_life','replace_uv_lamp','in_progress','iso_13485_deviation','Biomed - Rakesh','2026-07-08',null,45000.00,'Lamp irradiance 18% low — replacement lamp on order'),
    ('UVC-FRT-11','uv_dose_mjcm2','uv_dose_below_spec','lamp_end_of_life','replace_uv_lamp','open','nabh_finding','Biomed - Rakesh','2026-07-08',null,45000.00,'Dose below spec pending lamp swap and re-validation'),
    ('UVC-AIM-31','lamp_hours_used','lamp_hours_exceeded','lamp_end_of_life','replace_uv_lamp','verification_pending','internal_only','Infection Control - Meera','2026-07-05',null,42000.00,'Lamp past rated hours — replace and verify output'),
    ('UVC-AIM-31','motion_sensor_ok','motion_sensor_failure','sensor_drift','schedule_oem_service','escalated','patient_safety_alert','Biomed - Suresh','2026-07-02',null,12000.00,'Motion safety interlock failed — escalated to OEM'),
    ('UVC-CMC-42','coverage_pct','coverage_gap','positioning_error','reposition_robot','closed','internal_only','Housekeeping - Latha','2026-07-01','2026-06-30',0.00,'Repositioned emitters; coverage re-verified and closed'),
    ('UVC-KIM-52','cycle_time_min','cycle_time_out_of_spec','reflector_dust_fouling','clean_reflectors','verification_pending','internal_only','Biomed - Anil','2026-07-02',null,3500.00,'Reflectors cleaned — re-measure cycle time next run'),
    ('UVC-KKB-71','lamp_output_uwcm2','lamp_output_degraded','ballast_degraded','replace_ballast','escalated','cdsco_notifiable','Biomed - Vikram','2026-07-01',null,68000.00,'Severe output loss from ballast fault — device removed from service'),
    ('UVC-NAR-81','coverage_pct','coverage_gap','positioning_error','reposition_robot','open','none','Housekeeping - Priya','2026-07-03',null,0.00,'Minor coverage shortfall — reposition planned for next cycle')
  ) as q(dcode, param, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.uvc_disinfection_qc_r3578 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3578_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.uvc_disinfection_qc_r3578)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.uvc_disinfection_qc_r3578 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3578_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3578_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3578_device_model_scorecard()
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
  from public.uvc_disinfection_qc_r3578 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3578_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3578_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3578_parameter_verdict_matrix()
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
  from public.uvc_disinfection_qc_r3578 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3578_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3578_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3578_monthly_calibration_trend()
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
    round(avg(l.deviation_pct), 2)
  from public.uvc_disinfection_qc_r3578 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3578_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3578_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3578_capa_status_board()
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
  from public.uvc_disinfection_qc_capa_actions_r3578 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3578_capa_status_board() from public, anon;
grant execute on function public.founder_r3578_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3578_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.uvc_disinfection_qc_capa_actions_r3578)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.uvc_disinfection_qc_capa_actions_r3578 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3578_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3578_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3578_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, failed bigint, avg_deviation_pct numeric, max_abs_deviation_pct numeric)
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.uvc_disinfection_qc_r3578 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3578_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3578_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / conditional / failed checks)
create or replace function public.founder_r3578_high_risk_queue()
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
  from public.uvc_disinfection_qc_r3578 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3578_high_risk_queue() from public, anon;
grant execute on function public.founder_r3578_high_risk_queue() to authenticated;
