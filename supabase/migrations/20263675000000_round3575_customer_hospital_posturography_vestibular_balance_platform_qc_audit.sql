-- Round 3575: Customer Hospital Posturography / Vestibular Balance-Platform QC Audit
-- Computerized dynamic posturography / vestibular balance-platform QA — force plate, sway, platform tilt,
-- visual-surround sync, load linearity, motor response × reference/measured × deviation × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: posturography_qc_r3575 — per-parameter balance-platform QC checks
-- =============================================================================
create table if not exists public.posturography_qc_r3575 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'force_plate_accuracy','sway_measurement','platform_tilt_deg',
    'visual_surround_sync','load_linearity','motor_response_ms'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.posturography_qc_r3575 enable row level security;

create index if not exists idx_posturography_qc_r3575_org on public.posturography_qc_r3575(organization_id);
create index if not exists idx_posturography_qc_r3575_caldate on public.posturography_qc_r3575(calibration_date);
create index if not exists idx_posturography_qc_r3575_verdict on public.posturography_qc_r3575(qc_verdict);

-- =============================================================================
-- TABLE 2: posturography_qc_capa_actions_r3575 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.posturography_qc_capa_actions_r3575 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.posturography_qc_r3575(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'force_plate_accuracy_out_of_tolerance','sway_measurement_drift','platform_tilt_out_of_spec',
    'visual_surround_sync_failure','load_linearity_nonlinear','motor_response_slow',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'load_cell_drift','strain_gauge_degraded','servo_motor_wear','visual_surround_actuator_fault',
    'software_calibration_error','operator_setup_error','mechanical_wear','cabling_connector_fault',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_force_plate','replace_load_cell','replace_strain_gauge','service_servo_motor',
    'repair_visual_surround','update_calibration_software','retrain_operator','replace_cabling',
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

alter table public.posturography_qc_capa_actions_r3575 enable row level security;

create index if not exists idx_posturography_capa_r3575_log on public.posturography_qc_capa_actions_r3575(qc_log_id);
create index if not exists idx_posturography_capa_r3575_status on public.posturography_qc_capa_actions_r3575(capa_status);

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
  insert into public.posturography_qc_r3575 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','PST-APL-01','NeuroCom SMART EquiTest','force_plate_accuracy',
     100.000,100.400,0.40,true,'2026-07-05','pass','Force-plate load accuracy within +/-1% spec'),
    ('Apollo Chennai','PST-APL-02','Bertec CDP','sway_measurement',
     5.000,5.100,2.00,true,'2026-07-05','pass','Center-of-pressure sway repeatability nominal'),
    ('Fortis Gurgaon','PST-FRT-11','Biodex Balance SD','platform_tilt_deg',
     10.000,10.350,3.50,true,'2026-07-04','conditional_pass','Platform tilt angle slightly high — monitor drift'),
    ('Fortis Gurgaon','PST-FRT-12','NeuroCom Balance Master','force_plate_accuracy',
     100.000,96.200,3.80,false,'2026-07-04','fail','Force-plate reads 3.8% low — load cell drift suspected'),
    ('Manipal Bengaluru','PST-MNP-21','Tetrax TPS','visual_surround_sync',
     20.000,20.500,2.50,true,'2026-07-03','pass','Visual-surround sync latency within tolerance'),
    ('Manipal Bengaluru','PST-MNP-22','AMTI AccuSway','load_linearity',
     100.000,99.100,0.90,true,'2026-07-03','pass','Load linearity across range within spec'),
    ('AIIMS Delhi','PST-AIM-31','NeuroCom SMART EquiTest','motor_response_ms',
     150.000,168.000,12.00,false,'2026-07-02','fail','Servo motor response 168 ms vs 150 ms spec'),
    ('AIIMS Delhi','PST-AIM-32','Bertec CDP','force_plate_accuracy',
     100.000,100.900,0.90,true,'2026-07-02','pass','Force-plate accuracy within tolerance post-service'),
    ('CMC Vellore','PST-CMC-41','Biodex Balance SD','sway_measurement',
     5.000,5.450,9.00,false,'2026-07-01','fail','Sway measurement drift 9% out of tolerance'),
    ('CMC Vellore','PST-CMC-42','NeuroCom Balance Master','platform_tilt_deg',
     10.000,10.150,1.50,true,'2026-07-01','pass','Platform tilt within +/-2% tolerance'),
    ('KIMS Hyderabad','PST-KIM-51','Tetrax TPS','visual_surround_sync',
     20.000,22.800,14.00,false,'2026-06-30','conditional_pass','Visual-surround sync latency high — actuator flagged'),
    ('KIMS Hyderabad','PST-KIM-52','AMTI AccuSway','force_plate_accuracy',
     100.000,100.200,0.20,true,'2026-06-30','pass','Force-plate accuracy excellent'),
    ('Yashoda Hyderabad','PST-YSH-61','NeuroCom SMART EquiTest','load_linearity',
     100.000,97.500,2.50,true,'2026-06-29','conditional_pass','Load linearity marginal at upper range — strain gauge watch'),
    ('Kokilaben Mumbai','PST-KKB-71','Bertec CDP','motor_response_ms',
     150.000,152.000,1.33,true,'2026-06-29','pass','Motor response within spec — annual PM approaching'),
    ('Kokilaben Mumbai','PST-KKB-72','Biodex Balance SD','platform_tilt_deg',
     10.000,11.200,12.00,false,'2026-06-28','fail','Platform tilt 12% out of spec — actuator cabling fault'),
    ('Medanta Gurgaon','PST-MDT-81','NeuroCom Balance Master','sway_measurement',
     5.000,5.050,1.00,true,'2026-06-28','pass','Sway measurement repeatability within tolerance')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.posturography_qc_capa_actions_r3575 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PST-FRT-12','force_plate_accuracy_out_of_tolerance','load_cell_drift','recalibrate_force_plate','in_progress','iso_13485_deviation','2026-07-10',null,18000.00,'Force plate recalibrated; verification measurement pending'),
    ('PST-FRT-11','platform_tilt_out_of_spec','mechanical_wear','service_servo_motor','open','internal_only','2026-07-12',null,9500.00,'Platform tilt marginally high — servo service scheduled'),
    ('PST-AIM-31','motor_response_slow','servo_motor_wear','service_servo_motor','escalated','patient_safety_alert','2026-07-08',null,26000.00,'Motor response 168 ms vs 150 ms — escalated to OEM'),
    ('PST-CMC-41','sway_measurement_drift','load_cell_drift','recalibrate_force_plate','closed','nabh_finding','2026-07-06','2026-07-04',12000.00,'Sway drift corrected via recalibration and revalidated'),
    ('PST-KIM-51','visual_surround_sync_failure','visual_surround_actuator_fault','repair_visual_surround','verification_pending','internal_only','2026-07-09',null,21000.00,'Visual-surround actuator repaired — verify sync latency'),
    ('PST-KKB-72','platform_tilt_out_of_spec','cabling_connector_fault','replace_cabling','overdue','cdsco_notifiable','2026-07-03',null,15000.00,'Tilt actuator cabling fault — replacement past due, vendor delay'),
    ('PST-YSH-61','load_linearity_nonlinear','strain_gauge_degraded','replace_strain_gauge','open','iso_13485_deviation','2026-07-14',null,32000.00,'Load linearity marginal — strain gauge replacement ordered'),
    ('PST-KKB-71','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-15',null,0.00,'Annual preventive maintenance due — OEM service to schedule')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.posturography_qc_r3575 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3575_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.posturography_qc_r3575)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.posturography_qc_r3575 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3575_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3575_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3575_device_model_scorecard()
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
  from public.posturography_qc_r3575 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3575_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3575_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3575_parameter_verdict_matrix()
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
  from public.posturography_qc_r3575 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3575_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3575_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3575_monthly_calibration_trend()
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
  from public.posturography_qc_r3575 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3575_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3575_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3575_capa_status_board()
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
  from public.posturography_qc_capa_actions_r3575 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3575_capa_status_board() from public, anon;
grant execute on function public.founder_r3575_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3575_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.posturography_qc_capa_actions_r3575)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.posturography_qc_capa_actions_r3575 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3575_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3575_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter deviation profile)
create or replace function public.founder_r3575_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, failed bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.posturography_qc_r3575 l
  group by l.parameter
  order by round(avg(l.deviation_pct), 2) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3575_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3575_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3575_high_risk_queue()
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
  within_tolerance boolean,
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.within_tolerance, l.notes
  from public.posturography_qc_r3575 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3575_high_risk_queue() from public, anon;
grant execute on function public.founder_r3575_high_risk_queue() to authenticated;
