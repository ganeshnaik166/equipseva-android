-- Round 3442: Customer Hospital Heart-Lung Machine / Cardiopulmonary-Bypass (CPB) Perfusion QC Audit
-- CPB perfusion QA — device model × parameter × reference vs measured × deviation × safety interlock × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: heart_lung_cpb_qc_r3442 — per-parameter CPB perfusion QC checks
-- =============================================================================
create table if not exists public.heart_lung_cpb_qc_r3442 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  unit text not null check (unit in (
    'cardiac_ot','cardiac_icu','cath_lab','pediatric_cardiac_ot'
  )),
  parameter text not null check (parameter in (
    'pump_flow_lpm','gas_blender_fio2','heater_cooler_temp','pressure_alarm','level_bubble_sensor','act_timer'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  safety_interlock_ok boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  check_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.heart_lung_cpb_qc_r3442 enable row level security;

create index if not exists idx_heart_lung_cpb_qc_r3442_org on public.heart_lung_cpb_qc_r3442(organization_id);
create index if not exists idx_heart_lung_cpb_qc_r3442_date on public.heart_lung_cpb_qc_r3442(check_date);
create index if not exists idx_heart_lung_cpb_qc_r3442_verdict on public.heart_lung_cpb_qc_r3442(qc_verdict);

-- =============================================================================
-- TABLE 2: heart_lung_cpb_qc_capa_actions_r3442 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.heart_lung_cpb_qc_capa_actions_r3442 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.heart_lung_cpb_qc_r3442(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'flow_calibration_drift','fio2_blender_out_of_tolerance','heater_cooler_temp_deviation',
    'pressure_alarm_failure','level_bubble_sensor_fault','act_timer_inaccuracy',
    'safety_interlock_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'flow_sensor_drift','blender_calibration_error','heater_cooler_fault','pressure_transducer_drift',
    'ultrasonic_sensor_fault','timer_module_fault','interlock_switch_fault','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_flow_sensor','recalibrate_gas_blender','service_heater_cooler','replace_pressure_transducer',
    'replace_bubble_sensor','replace_timer_module','repair_safety_interlock','retrain_perfusion_staff',
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

alter table public.heart_lung_cpb_qc_capa_actions_r3442 enable row level security;

create index if not exists idx_heart_lung_cpb_capa_r3442_log on public.heart_lung_cpb_qc_capa_actions_r3442(qc_log_id);
create index if not exists idx_heart_lung_cpb_capa_r3442_status on public.heart_lung_cpb_qc_capa_actions_r3442(capa_status);

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

  -- 16 CPB perfusion QC rows
  insert into public.heart_lung_cpb_qc_r3442 (
    organization_id, hospital_name, device_code, device_model, unit, parameter,
    reference_value, measured_value, deviation_pct, tolerance_pct,
    safety_interlock_ok, calibration_date, calibration_current, check_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.unit, q.param,
    q.refv, q.measv, q.devp, q.tolp,
    q.interlock, q.caldate::date, q.calcur, q.chkdate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','HLM-APL-01','LivaNova S5','cardiac_ot','pump_flow_lpm',
     5.00,5.05,1.00,5.00,true,'2026-06-15',true,'2026-07-05','pass','Roller pump flow within 1% of reference flowmeter'),
    ('Apollo Chennai','HLM-APL-01','LivaNova S5','cardiac_ot','gas_blender_fio2',
     60.00,61.20,2.00,5.00,true,'2026-06-15',true,'2026-07-05','pass','Oxygen blender FiO2 within tolerance'),
    ('Fortis Gurgaon','HLM-FRT-11','Terumo System 1','cardiac_ot','heater_cooler_temp',
     37.00,37.80,2.16,3.00,true,'2026-06-10',true,'2026-07-04','conditional_pass','Heater-cooler runs slightly warm — recheck trend'),
    ('Fortis Gurgaon','HLM-FRT-12','Maquet HL30','cardiac_icu','pressure_alarm',
     300.00,340.00,13.33,5.00,false,'2026-05-20',false,'2026-07-04','fail','Arterial line pressure alarm late and safety interlock failed'),
    ('Manipal Bengaluru','HLM-MNP-21','Medtronic Bio-Console 560','cardiac_ot','level_bubble_sensor',
     0.50,0.52,4.00,10.00,true,'2026-06-20',true,'2026-07-03','pass','Bubble/level sensor trigger volume nominal'),
    ('Manipal Bengaluru','HLM-MNP-22','LivaNova C5','pediatric_cardiac_ot','act_timer',
     480.00,505.00,5.21,3.00,true,'2026-06-01',true,'2026-07-03','conditional_pass','ACT timer drift beyond 3% — service scheduled'),
    ('AIIMS Delhi','HLM-AIM-31','Terumo System 1','cardiac_ot','pump_flow_lpm',
     5.00,4.60,-8.00,5.00,true,'2026-05-15',false,'2026-07-02','fail','Roller pump flow reads 8% low and calibration overdue'),
    ('AIIMS Delhi','HLM-AIM-32','LivaNova S5','cath_lab','gas_blender_fio2',
     40.00,40.40,1.00,5.00,true,'2026-06-25',true,'2026-07-02','pass','Blender FiO2 QC pass'),
    ('CMC Vellore','HLM-CMC-41','Maquet HL30','cardiac_icu','heater_cooler_temp',
     37.00,37.10,0.27,3.00,true,'2026-06-18',true,'2026-07-01','pass','Heater-cooler within tolerance'),
    ('CMC Vellore','HLM-CMC-42','LivaNova C5','cardiac_ot','pressure_alarm',
     300.00,315.00,5.00,5.00,true,'2026-06-05',true,'2026-07-01','conditional_pass','Pressure alarm at edge of tolerance — monitor'),
    ('KIMS Hyderabad','HLM-KIM-51','Medtronic Bio-Console 560','cardiac_ot','level_bubble_sensor',
     0.50,0.75,50.00,10.00,false,'2026-05-10',false,'2026-06-30','fail','Bubble sensor slow to trigger and interlock inoperative — removed'),
    ('KIMS Hyderabad','HLM-KIM-52','LivaNova S5','cardiac_icu','act_timer',
     480.00,483.00,0.63,3.00,true,'2026-06-22',true,'2026-06-30','pass','ACT timer accurate within tolerance'),
    ('Yashoda Hyderabad','HLM-YSH-61','Terumo System 1','pediatric_cardiac_ot','pump_flow_lpm',
     2.50,2.55,2.00,5.00,true,'2026-06-12',true,'2026-06-29','pass','Pediatric roller pump flow QC pass'),
    ('Kokilaben Mumbai','HLM-KKB-71','Maquet HL30','cardiac_ot','gas_blender_fio2',
     100.00,92.00,-8.00,5.00,false,'2026-05-08',false,'2026-06-28','fail','Blender fails to reach 100% FiO2 and interlock fault — removed from service'),
    ('Kokilaben Mumbai','HLM-KKB-72','LivaNova C5','cardiac_icu','heater_cooler_temp',
     37.00,38.50,4.05,3.00,true,'2026-06-02',true,'2026-06-28','conditional_pass','Heater-cooler runs warm — cooling service due'),
    ('Narayana Bengaluru','HLM-NRY-81','LivaNova S5','cath_lab','pressure_alarm',
     300.00,300.00,0.00,5.00,true,'2026-06-24',true,'2026-06-27','pass','Arterial pressure alarm QC pass')
  ) as q(hosp, dcode, dmodel, unit, param, refv, measv, devp, tolp, interlock, caldate, calcur, chkdate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.heart_lung_cpb_qc_capa_actions_r3442 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HLM-FRT-11','heater_cooler_temp_deviation','heater_cooler_fault','service_heater_cooler','in_progress','iso_13485_deviation','2026-07-10',null,18000.00,'Heater-cooler serviced — verify temperature stability next case'),
    ('HLM-FRT-12','pressure_alarm_failure','pressure_transducer_drift','replace_pressure_transducer','escalated','patient_safety_alert','2026-07-08',null,26000.00,'Late arterial pressure alarm with interlock fail — escalated to OEM'),
    ('HLM-MNP-22','act_timer_inaccuracy','timer_module_fault','replace_timer_module','open','internal_only','2026-07-09',null,12000.00,'ACT timer drift — timer module replacement ordered'),
    ('HLM-AIM-31','flow_calibration_drift','flow_sensor_drift','recalibrate_flow_sensor','verification_pending','nabh_finding','2026-07-07',null,15000.00,'Flow sensor recalibrated — verify against reference flowmeter'),
    ('HLM-CMC-42','pressure_alarm_failure','pressure_transducer_drift','replace_pressure_transducer','open','internal_only','2026-07-11',null,9000.00,'Pressure alarm at tolerance edge — transducer check scheduled'),
    ('HLM-KIM-51','safety_interlock_failure','interlock_switch_fault','repair_safety_interlock','escalated','cdsco_notifiable','2026-07-05',null,34000.00,'Bubble sensor and interlock fault — device removed, OEM engaged'),
    ('HLM-KKB-71','fio2_blender_out_of_tolerance','blender_calibration_error','recalibrate_gas_blender','closed','cdsco_notifiable','2026-07-02','2026-06-30',22000.00,'Blender recalibrated and interlock repaired — device revalidated'),
    ('HLM-KKB-72','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','none','2026-06-30',null,0.00,'Cooling service past target closure — vendor delay')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.heart_lung_cpb_qc_r3442 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3442_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.heart_lung_cpb_qc_r3442)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.heart_lung_cpb_qc_r3442 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3442_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3442_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3442_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  interlock_fail bigint,
  out_of_tolerance bigint,
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
    count(*) filter (where l.safety_interlock_ok = false)::bigint,
    count(*) filter (where abs(l.deviation_pct) > l.tolerance_pct)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.heart_lung_cpb_qc_r3442 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3442_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3442_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3442_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, out_of_tolerance bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where abs(l.deviation_pct) > l.tolerance_pct)::bigint
  from public.heart_lung_cpb_qc_r3442 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3442_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3442_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3442_monthly_accuracy_trend()
returns table(month date, checks bigint, passed bigint, failed bigint, avg_deviation_pct numeric, out_of_tolerance bigint, calibration_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.check_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where abs(l.deviation_pct) > l.tolerance_pct)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.heart_lung_cpb_qc_r3442 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3442_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3442_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3442_capa_status_board()
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
  from public.heart_lung_cpb_qc_capa_actions_r3442 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3442_capa_status_board() from public, anon;
grant execute on function public.founder_r3442_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3442_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.heart_lung_cpb_qc_capa_actions_r3442)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.heart_lung_cpb_qc_capa_actions_r3442 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3442_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3442_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3442_accuracy_impact_digest()
returns table(parameter text, checks bigint, avg_deviation_pct numeric, worst_deviation_pct numeric, out_of_tolerance bigint, interlock_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2),
    count(*) filter (where abs(l.deviation_pct) > l.tolerance_pct)::bigint,
    count(*) filter (where l.safety_interlock_ok = false)::bigint
  from public.heart_lung_cpb_qc_r3442 l
  group by l.parameter
  order by count(*) filter (where abs(l.deviation_pct) > l.tolerance_pct) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3442_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3442_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / interlock-fail)
create or replace function public.founder_r3442_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  check_date date,
  qc_verdict text,
  deviation_pct numeric,
  tolerance_pct numeric,
  safety_interlock_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.check_date,
    l.qc_verdict, l.deviation_pct, l.tolerance_pct, l.safety_interlock_ok, l.notes
  from public.heart_lung_cpb_qc_r3442 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.safety_interlock_ok = false
     or abs(l.deviation_pct) > l.tolerance_pct
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3442_high_risk_queue() from public, anon;
grant execute on function public.founder_r3442_high_risk_queue() to authenticated;
