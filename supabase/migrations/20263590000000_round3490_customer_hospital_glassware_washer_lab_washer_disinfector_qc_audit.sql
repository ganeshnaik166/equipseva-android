-- Round 3490: Customer Hospital Laboratory Glassware Washer-Disinfector QC Audit
-- Lab washer-disinfector QA — wash temp × rinse conductivity × A0 disinfection value × drying temp ×
-- cycle time × detergent dose × reference vs measured × deviation × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: glassware_washer_qc_r3490 — per-parameter washer-disinfector QC checks
-- =============================================================================
create table if not exists public.glassware_washer_qc_r3490 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'wash_temp_c','rinse_conductivity_us','a0_value','drying_temp_c','cycle_time_min','detergent_dose_ml'
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

alter table public.glassware_washer_qc_r3490 enable row level security;

create index if not exists idx_glassware_washer_qc_r3490_org on public.glassware_washer_qc_r3490(organization_id);
create index if not exists idx_glassware_washer_qc_r3490_cal on public.glassware_washer_qc_r3490(calibration_date);
create index if not exists idx_glassware_washer_qc_r3490_verdict on public.glassware_washer_qc_r3490(qc_verdict);

-- =============================================================================
-- TABLE 2: glassware_washer_qc_capa_actions_r3490 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.glassware_washer_qc_capa_actions_r3490 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.glassware_washer_qc_r3490(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'wash_temp_out_of_tolerance','rinse_conductivity_high','a0_value_below_target',
    'drying_temp_out_of_tolerance','cycle_time_deviation','detergent_dose_deviation',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'heater_element_degraded','temperature_sensor_drift','conductivity_sensor_fouled',
    'water_softener_exhausted','detergent_dosing_pump_fault','spray_arm_blocked',
    'door_seal_leak','software_config_error','operator_loading_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_heater_element','recalibrate_temperature_sensor','clean_conductivity_sensor',
    'regenerate_water_softener','replace_dosing_pump','clean_spray_arm','replace_door_seal',
    'update_cycle_program','retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','iso_15189_deviation','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.glassware_washer_qc_capa_actions_r3490 enable row level security;

create index if not exists idx_glassware_washer_capa_r3490_log on public.glassware_washer_qc_capa_actions_r3490(qc_log_id);
create index if not exists idx_glassware_washer_capa_r3490_status on public.glassware_washer_qc_capa_actions_r3490(capa_status);

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
  insert into public.glassware_washer_qc_r3490 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldt::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','GW-APL-01','Getinge 46-4','wash_temp_c',
     90,89.6,-0.4,true,'2026-07-05','pass','Thermal wash temperature within tolerance at 90C'),
    ('Apollo Chennai','GW-APL-01','Getinge 46-4','a0_value',
     3000,3180,6.0,true,'2026-07-05','pass','A0 disinfection value exceeds 3000 target'),
    ('Apollo Chennai','GW-APL-02','Miele PG8583','rinse_conductivity_us',
     15,11.2,-25.3,true,'2026-07-04','pass','Final rinse conductivity well below 15 uS/cm limit'),
    ('Fortis Gurgaon','GW-FRT-11','Steelco DS600','wash_temp_c',
     90,86.4,-4.0,false,'2026-07-03','conditional_pass','Wash temp 3.6C low — heater ramp slow, monitor next cycle'),
    ('Fortis Gurgaon','GW-FRT-11','Steelco DS600','rinse_conductivity_us',
     15,19.8,32.0,false,'2026-07-03','fail','Rinse conductivity 19.8 uS/cm above limit — softener exhausted'),
    ('Fortis Gurgaon','GW-FRT-12','Belimed WD290','drying_temp_c',
     110,108.5,-1.4,true,'2026-07-02','pass','Drying temperature nominal'),
    ('Manipal Bengaluru','GW-MNP-21','Getinge 46-4','a0_value',
     3000,2450,-18.3,false,'2026-07-01','fail','A0 value 2450 below 3000 target — disinfection insufficient'),
    ('Manipal Bengaluru','GW-MNP-21','Getinge 46-4','cycle_time_min',
     45,44.5,-1.1,true,'2026-07-01','pass','Cycle time within tolerance'),
    ('AIIMS Delhi','GW-AIM-31','Lancer 910LX','detergent_dose_ml',
     50,42.0,-16.0,false,'2026-06-30','conditional_pass','Detergent dose 16% low — dosing pump under-delivering'),
    ('AIIMS Delhi','GW-AIM-31','Lancer 910LX','wash_temp_c',
     90,90.3,0.3,true,'2026-06-30','pass','Wash temperature on target'),
    ('CMC Vellore','GW-CMC-41','Miele PG8583','rinse_conductivity_us',
     15,13.8,-8.0,true,'2026-06-29','pass','Rinse conductivity within limit'),
    ('CMC Vellore','GW-CMC-42','Steelco DS600','drying_temp_c',
     110,101.0,-8.2,false,'2026-06-29','conditional_pass','Drying temp 9C low — glassware residual moisture, recheck heater'),
    ('KIMS Hyderabad','GW-KIM-51','Belimed WD290','a0_value',
     3000,3050,1.7,true,'2026-06-28','pass','A0 disinfection value on target'),
    ('KIMS Hyderabad','GW-KIM-52','Getinge 46-4','cycle_time_min',
     45,52.0,15.6,false,'2026-06-28','fail','Cycle time overrun 15.6% — spray arm blockage suspected'),
    ('Yashoda Hyderabad','GW-YSH-61','Lancer 910LX','detergent_dose_ml',
     50,49.5,-1.0,true,'2026-06-27','pass','Detergent dose within tolerance'),
    ('Kokilaben Mumbai','GW-KKB-71','Steelco DS600','wash_temp_c',
     90,82.0,-8.9,false,'2026-06-27','fail','Wash temp 8C low — heater element degraded, unit tagged out')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldt, qv, nt);

  -- CAPA seed — attach to specific checks via device_code + parameter
  insert into public.glassware_washer_qc_capa_actions_r3490 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('GW-FRT-11','rinse_conductivity_us','rinse_conductivity_high','water_softener_exhausted','regenerate_water_softener','in_progress','nabl_finding','2026-07-06',null,8000.00,'Softener regenerated; verify final-rinse conductivity next cycle'),
    ('GW-MNP-21','a0_value','a0_value_below_target','heater_element_degraded','replace_heater_element','escalated','patient_safety_alert','2026-07-05',null,55000.00,'A0 shortfall — heater element flagged, escalated to OEM'),
    ('GW-KIM-52','cycle_time_min','cycle_time_deviation','spray_arm_blocked','clean_spray_arm','closed','internal_only','2026-07-01','2026-06-29',3500.00,'Spray arm cleared and cycle time re-verified within limit'),
    ('GW-KKB-71','wash_temp_c','wash_temp_out_of_tolerance','heater_element_degraded','replace_heater_element','open','nabh_finding','2026-07-02',null,42000.00,'Unit tagged out — heater element replacement ordered'),
    ('GW-AIM-31','detergent_dose_ml','detergent_dose_deviation','detergent_dosing_pump_fault','replace_dosing_pump','verification_pending','iso_15189_deviation','2026-07-03',null,12000.00,'Dosing pump replaced — verify dose delivery over 3 cycles'),
    ('GW-CMC-42','drying_temp_c','drying_temp_out_of_tolerance','temperature_sensor_drift','recalibrate_temperature_sensor','overdue','internal_only','2026-06-30',null,6000.00,'Drying temp sensor recal past target date — vendor delay'),
    ('GW-FRT-11','wash_temp_c','wash_temp_out_of_tolerance','temperature_sensor_drift','recalibrate_temperature_sensor','open','internal_only','2026-07-04',null,5000.00,'Wash temp sensor drift — recalibration scheduled'),
    ('GW-MNP-21','cycle_time_min','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-10',null,0.00,'Preventive maintenance visit due — OEM slot requested')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.glassware_washer_qc_r3490 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3490_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.glassware_washer_qc_r3490)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.glassware_washer_qc_r3490 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3490_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3490_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3490_device_model_scorecard()
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
  from public.glassware_washer_qc_r3490 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3490_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3490_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3490_parameter_verdict_matrix()
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
  from public.glassware_washer_qc_r3490 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3490_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3490_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3490_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.glassware_washer_qc_r3490 l
  group by to_char(l.calibration_date, 'YYYY-MM')
  order by to_char(l.calibration_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3490_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3490_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3490_capa_status_board()
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
  from public.glassware_washer_qc_capa_actions_r3490 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3490_capa_status_board() from public, anon;
grant execute on function public.founder_r3490_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3490_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.glassware_washer_qc_capa_actions_r3490)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.glassware_washer_qc_capa_actions_r3490 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3490_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3490_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by finding category)
create or replace function public.founder_r3490_accuracy_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.glassware_washer_qc_capa_actions_r3490 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3490_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3490_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3490_high_risk_queue()
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
  from public.glassware_washer_qc_r3490 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3490_high_risk_queue() from public, anon;
grant execute on function public.founder_r3490_high_risk_queue() to authenticated;
