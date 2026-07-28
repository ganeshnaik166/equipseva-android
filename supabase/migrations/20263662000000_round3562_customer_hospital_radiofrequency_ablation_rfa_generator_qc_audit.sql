-- Round 3562: Customer Hospital Radiofrequency-Ablation (RFA) Generator QC Audit
-- RFA generator QA — parameter (set/delivered power, impedance, tip temp, ablation timer, energy deviation)
-- × reference vs measured × deviation % × tolerance band × calibration currency × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: rfa_generator_qc_r3562 — per-parameter RFA generator QC measurements
-- =============================================================================
create table if not exists public.rfa_generator_qc_r3562 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'set_power_w','delivered_power_w','impedance_ohm','tip_temp_c','ablation_time_sec','energy_deviation_pct'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  tolerance_band_pct numeric(5,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  test_equipment text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rfa_generator_qc_r3562 enable row level security;

create index if not exists idx_rfa_generator_qc_r3562_org on public.rfa_generator_qc_r3562(organization_id);
create index if not exists idx_rfa_generator_qc_r3562_date on public.rfa_generator_qc_r3562(calibration_date);
create index if not exists idx_rfa_generator_qc_r3562_verdict on public.rfa_generator_qc_r3562(qc_verdict);

-- =============================================================================
-- TABLE 2: rfa_generator_qc_capa_actions_r3562 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.rfa_generator_qc_capa_actions_r3562 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.rfa_generator_qc_r3562(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'set_power_out_of_tolerance','delivered_power_out_of_tolerance','impedance_out_of_tolerance',
    'tip_temp_out_of_tolerance','ablation_timer_error','energy_deviation_high',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'rf_output_stage_drift','power_sensor_miscalibration','impedance_sensor_drift','thermocouple_fault',
    'timer_clock_drift','firmware_calibration_error','connector_contact_resistance',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_power_output','replace_power_sensor','recalibrate_impedance_sensor','replace_thermocouple',
    'recalibrate_timer','update_firmware','clean_replace_connector',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  owner text,
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

alter table public.rfa_generator_qc_capa_actions_r3562 enable row level security;

create index if not exists idx_rfa_generator_capa_r3562_log on public.rfa_generator_qc_capa_actions_r3562(qc_log_id);
create index if not exists idx_rfa_generator_capa_r3562_status on public.rfa_generator_qc_capa_actions_r3562(capa_status);

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
  insert into public.rfa_generator_qc_r3562 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, tolerance_band_pct,
    within_tolerance, calibration_date, calibration_current, test_equipment, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.tolpct,
    q.wtol, q.caldate::date, q.calcur, q.testeq, q.qv, q.nt
  from (values
    ('Apollo Chennai','RFA-APL-01','Boston Scientific RF3000','set_power_w',
     100,99,1.0,5,true,'2026-07-05',true,'RF Power Analyzer BAPCO','pass','Set power output within 1% of reference'),
    ('Apollo Chennai','RFA-APL-01','Boston Scientific RF3000','delivered_power_w',
     100,96,-4.0,5,true,'2026-07-05',true,'RF Power Analyzer BAPCO','pass','Delivered power within 5% tolerance band'),
    ('Apollo Chennai','RFA-APL-02','Medtronic Cosman G4','impedance_ohm',
     80,84,5.0,8,true,'2026-07-05',true,'Impedance decade box','pass','Impedance reading nominal against reference load'),
    ('Fortis Gurgaon','RFA-FRT-11','AngioDynamics 1500X','tip_temp_c',
     90,86,-4.4,5,true,'2026-07-04',true,'Thermocouple sim Fluke','conditional_pass','Tip temp 4.4% low — recalibrate at next PM'),
    ('Fortis Gurgaon','RFA-FRT-11','AngioDynamics 1500X','delivered_power_w',
     150,138,-8.0,5,false,'2026-07-04',true,'RF Power Analyzer BAPCO','fail','Delivered power 8% low — exceeds 5% band'),
    ('Fortis Gurgaon','RFA-FRT-12','Boston Scientific RF3000','ablation_time_sec',
     720,726,0.8,3,true,'2026-07-04',true,'Digital timer reference','pass','Timer accuracy within 1% of setpoint'),
    ('Manipal Bengaluru','RFA-MNP-21','STARmed VIVA RF','tip_temp_c',
     90,90,0.0,5,true,'2026-07-03',true,'Thermocouple sim Fluke','pass','Tip temperature exact match to reference'),
    ('Manipal Bengaluru','RFA-MNP-21','STARmed VIVA RF','impedance_ohm',
     75,82,9.3,8,false,'2026-07-03',true,'Impedance decade box','fail','Impedance error 9.3% — sensor drift out of band'),
    ('AIIMS Delhi','RFA-AIM-31','Medtronic Cosman G4','set_power_w',
     120,118,-1.7,5,true,'2026-06-30',true,'RF Power Analyzer BAPCO','pass','Set power nominal post-AMC service'),
    ('AIIMS Delhi','RFA-AIM-31','Medtronic Cosman G4','energy_deviation_pct',
     0,3.2,3.2,5,true,'2026-06-30',true,'Calorimetric load','conditional_pass','Energy deviation 3.2% flagged for trend watch'),
    ('CMC Vellore','RFA-CMC-41','Olympus CelonLab Power','delivered_power_w',
     200,190,-5.0,5,true,'2026-06-29',true,'RF Power Analyzer BAPCO','conditional_pass','Delivered power at 5% band edge'),
    ('CMC Vellore','RFA-CMC-42','Boston Scientific RF3000','impedance_ohm',
     80,81,1.3,8,true,'2026-06-29',false,'Impedance decade box','conditional_pass','Impedance fine but calibration overdue'),
    ('KIMS Hyderabad','RFA-KIM-51','AngioDynamics 1500X','tip_temp_c',
     95,92,-3.2,5,true,'2026-06-28',true,'Thermocouple sim Fluke','pass','Tip temp within tolerance band'),
    ('KIMS Hyderabad','RFA-KIM-52','STARmed VIVA RF','ablation_time_sec',
     600,618,3.0,3,false,'2026-06-28',true,'Digital timer reference','fail','Timer 3% over — exceeds 3% band, service required'),
    ('Yashoda Hyderabad','RFA-YSH-61','Medtronic Cosman G4','set_power_w',
     100,97,-3.0,5,true,'2026-06-27',true,'RF Power Analyzer BAPCO','pass','Set power within 5% band'),
    ('Kokilaben Mumbai','RFA-KKB-71','Olympus CelonLab Power','energy_deviation_pct',
     0,7.5,7.5,5,false,'2026-06-27',false,'Calorimetric load','fail','Energy deviation 7.5% and calibration overdue — removed pending service')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, tolpct, wtol, caldate, calcur, testeq, qv, nt);

  -- CAPA seed — attach to specific measurements via device_code + parameter
  insert into public.rfa_generator_qc_capa_actions_r3562 (
    qc_log_id, finding_category, root_cause, corrective_action, owner,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.own,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RFA-FRT-11','tip_temp_c','tip_temp_out_of_tolerance','thermocouple_fault','replace_thermocouple','Biomedical Engg - Fortis','in_progress','iso_13485_deviation','2026-07-10',null,18000.00,'Thermocouple channel drift — replacement scheduled'),
    ('RFA-FRT-11','delivered_power_w','delivered_power_out_of_tolerance','rf_output_stage_drift','recalibrate_power_output','Biomedical Engg - Fortis','open','patient_safety_alert','2026-07-09',null,25000.00,'Delivered power 8% low — RF output stage recalibration'),
    ('RFA-MNP-21','impedance_ohm','impedance_out_of_tolerance','impedance_sensor_drift','recalibrate_impedance_sensor','Clinical Engg - Manipal','escalated','cdsco_notifiable','2026-07-08',null,22000.00,'Impedance error 9.3% — escalated to OEM'),
    ('RFA-AIM-31','energy_deviation_pct','energy_deviation_high','firmware_calibration_error','update_firmware','Biomedical Dept - AIIMS','verification_pending','internal_only','2026-07-07',null,0.00,'Firmware calibration patch applied — verify next QC'),
    ('RFA-CMC-41','delivered_power_w','delivered_power_out_of_tolerance','power_sensor_miscalibration','replace_power_sensor','Biomedical Engg - CMC','open','internal_only','2026-07-06',null,15000.00,'Delivered power at band edge — power sensor replacement'),
    ('RFA-CMC-42','impedance_ohm','calibration_overdue','preventive_service_backlog','schedule_oem_service','Biomedical Engg - CMC','overdue','nabh_finding','2026-06-30',null,12000.00,'Calibration overdue — OEM service past due date'),
    ('RFA-KIM-52','ablation_time_sec','ablation_timer_error','timer_clock_drift','recalibrate_timer','Clinical Engg - KIMS','closed','iso_13485_deviation','2026-07-02','2026-06-30',9000.00,'Timer recalibrated and verified — closed'),
    ('RFA-KKB-71','energy_deviation_pct','energy_deviation_high','rf_output_stage_drift','remove_from_service','Biomedical Dept - Kokilaben','escalated','patient_safety_alert','2026-07-01',null,48000.00,'Energy deviation 7.5% with overdue cal — removed pending OEM repair')
  ) as q(dcode, param, fc, rc, ca, own, cst, ri, tcd, acd, cost, nt)
  join public.rfa_generator_qc_r3562 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3562_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rfa_generator_qc_r3562)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.rfa_generator_qc_r3562 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3562_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3562_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3562_device_model_scorecard()
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
  from public.rfa_generator_qc_r3562 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3562_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3562_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3562_parameter_verdict_matrix()
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
  from public.rfa_generator_qc_r3562 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3562_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3562_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3562_monthly_accuracy_trend()
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
  from public.rfa_generator_qc_r3562 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3562_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3562_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3562_capa_status_board()
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
  from public.rfa_generator_qc_capa_actions_r3562 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3562_capa_status_board() from public, anon;
grant execute on function public.founder_r3562_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3562_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rfa_generator_qc_capa_actions_r3562)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.rfa_generator_qc_capa_actions_r3562 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3562_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3562_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3562_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  failed bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.rfa_generator_qc_r3562 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3562_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3562_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / overdue)
create or replace function public.founder_r3562_high_risk_queue()
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
  from public.rfa_generator_qc_r3562 l
  where l.within_tolerance = false
     or l.qc_verdict in ('conditional_pass','fail')
     or l.calibration_current = false
  order by abs(l.deviation_pct) desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3562_high_risk_queue() from public, anon;
grant execute on function public.founder_r3562_high_risk_queue() to authenticated;
