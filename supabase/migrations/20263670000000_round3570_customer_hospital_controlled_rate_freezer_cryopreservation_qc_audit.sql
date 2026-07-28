-- Round 3570: Customer Hospital Controlled-Rate Freezer (Cryopreservation) QC Audit
-- Cryopreservation controlled-rate freezer QA — device model × parameter × reference vs measured × deviation × within-tolerance × calibration date × verdict × CAPA

-- =============================================================================
-- TABLE 1: crf_cryo_qc_r3570 — per-parameter controlled-rate freezer QC checks
-- =============================================================================
create table if not exists public.crf_cryo_qc_r3570 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'cooling_rate_c_min','chamber_temp_c','ln2_consumption','uniformity_delta_c','seeding_temp_c','probe_accuracy_c'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(8,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crf_cryo_qc_r3570 enable row level security;

create index if not exists idx_crf_cryo_qc_r3570_org on public.crf_cryo_qc_r3570(organization_id);
create index if not exists idx_crf_cryo_qc_r3570_date on public.crf_cryo_qc_r3570(calibration_date);
create index if not exists idx_crf_cryo_qc_r3570_verdict on public.crf_cryo_qc_r3570(qc_verdict);

-- =============================================================================
-- TABLE 2: crf_cryo_qc_capa_actions_r3570 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.crf_cryo_qc_capa_actions_r3570 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.crf_cryo_qc_r3570(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cooling_rate_out_of_tolerance','chamber_temp_out_of_tolerance','ln2_consumption_high',
    'uniformity_out_of_tolerance','seeding_temp_out_of_tolerance','probe_accuracy_out_of_tolerance',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'probe_drift','ln2_supply_low','ln2_valve_fault','chamber_seal_degraded',
    'controller_pid_miscalibrated','fan_circulation_fault','sensor_end_of_life',
    'operator_setup_error','software_config_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_probe','replace_probe','refill_ln2_and_check_supply','repair_ln2_valve',
    'replace_chamber_seal','retune_pid_controller','repair_circulation_fan','update_software_config',
    'retrain_lab_staff','schedule_oem_service','remove_from_service','none_required'
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

alter table public.crf_cryo_qc_capa_actions_r3570 enable row level security;

create index if not exists idx_crf_cryo_capa_r3570_log on public.crf_cryo_qc_capa_actions_r3570(qc_log_id);
create index if not exists idx_crf_cryo_capa_r3570_status on public.crf_cryo_qc_capa_actions_r3570(capa_status);

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
  insert into public.crf_cryo_qc_r3570 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CRF-APL-01','Planer Kryo 560-16','cooling_rate_c_min',
     1.000,1.020,2.0,true,'2026-07-05','pass','Embryo cryo cooling ramp within plus/minus 5% tolerance'),
    ('Apollo Chennai','CRF-APL-01','Planer Kryo 560-16','uniformity_delta_c',
     0.500,0.600,20.0,true,'2026-07-05','pass','Chamber uniformity delta acceptable across map points'),
    ('Fortis Gurgaon','CRF-FRT-11','Thermo CryoMed TSCM34','chamber_temp_c',
     -80.000,-76.500,4.38,false,'2026-07-04','conditional_pass','Chamber temp 3.5C warm — recheck after PID tune'),
    ('Fortis Gurgaon','CRF-FRT-11','Thermo CryoMed TSCM34','ln2_consumption',
     12.000,18.500,54.17,false,'2026-07-04','fail','LN2 consumption high — suspect chamber seal leak'),
    ('Manipal Bengaluru','CRF-MNP-21','Grant Asymptote EF600','cooling_rate_c_min',
     1.000,0.620,-38.0,false,'2026-07-03','fail','Cooling ramp shallow — stem-cell run aborted, controller fault'),
    ('Manipal Bengaluru','CRF-MNP-22','Grant Asymptote EF600','seeding_temp_c',
     -8.000,-7.800,2.5,true,'2026-07-03','pass','Ice-seeding temp nominal for cord-blood unit'),
    ('AIIMS Delhi','CRF-AIM-31','Planer Kryo 360','probe_accuracy_c',
     0.100,0.450,350.0,false,'2026-07-02','fail','Probe accuracy drift beyond plus/minus 0.2C — recalibration required'),
    ('AIIMS Delhi','CRF-AIM-31','Planer Kryo 360','chamber_temp_c',
     -80.000,-79.200,1.0,true,'2026-07-02','conditional_pass','Chamber temp within limit but probe drift flagged'),
    ('CMC Vellore','CRF-CMC-41','Cryologic CL-8800','uniformity_delta_c',
     0.500,1.300,160.0,false,'2026-07-01','fail','Uniformity poor across map — circulation fan suspect'),
    ('CMC Vellore','CRF-CMC-42','Cryologic CL-8800','cooling_rate_c_min',
     1.000,1.040,4.0,true,'2026-07-01','pass','Cooling ramp within tolerance for BMT cryo'),
    ('KIMS Hyderabad','CRF-KIM-51','Thermo CryoMed TSCM34','ln2_consumption',
     12.000,12.800,6.67,true,'2026-06-30','pass','LN2 usage nominal post-AMC service'),
    ('KIMS Hyderabad','CRF-KIM-51','Thermo CryoMed TSCM34','seeding_temp_c',
     -8.000,-6.500,18.75,false,'2026-06-30','conditional_pass','Seeding temp warm — monitor next run'),
    ('Tata Memorial Mumbai','CRF-TMH-61','Planer Kryo 560-16','probe_accuracy_c',
     0.100,0.120,20.0,true,'2026-06-29','pass','Probe accuracy within spec for BMT cryo runs'),
    ('Tata Memorial Mumbai','CRF-TMH-61','Planer Kryo 560-16','chamber_temp_c',
     -80.000,-80.300,0.38,true,'2026-06-29','pass','Chamber temp nominal at soak setpoint'),
    ('Rajiv Gandhi Bengaluru','CRF-RGB-71','Grant Asymptote EF600','cooling_rate_c_min',
     1.000,1.900,90.0,false,'2026-06-28','fail','Cooling ramp runaway — freezer removed from service pending OEM'),
    ('Rajiv Gandhi Bengaluru','CRF-RGB-72','Cryologic CL-8800','ln2_consumption',
     12.000,13.500,12.5,true,'2026-06-28','conditional_pass','LN2 slightly high but within action limit')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via (device_code, parameter)
  insert into public.crf_cryo_qc_capa_actions_r3570 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CRF-FRT-11','ln2_consumption','ln2_consumption_high','chamber_seal_degraded','replace_chamber_seal','in_progress','iso_13485_deviation','2026-07-08',null,28000.00,'LN2 leak suspected — chamber seal replacement scheduled'),
    ('CRF-MNP-21','cooling_rate_c_min','cooling_rate_out_of_tolerance','controller_pid_miscalibrated','retune_pid_controller','open','patient_safety_alert','2026-07-07',null,15000.00,'Cooling ramp shallow — stem-cell run aborted, PID retune'),
    ('CRF-AIM-31','probe_accuracy_c','probe_accuracy_out_of_tolerance','probe_drift','recalibrate_probe','verification_pending','internal_only','2026-07-06',null,6500.00,'Probe drift beyond spec — recalibrated, verify next run'),
    ('CRF-CMC-41','uniformity_delta_c','uniformity_out_of_tolerance','fan_circulation_fault','repair_circulation_fan','escalated','nabh_finding','2026-07-05',null,34000.00,'Chamber uniformity poor — circulation fan repair escalated to OEM'),
    ('CRF-RGB-71','cooling_rate_c_min','cooling_rate_out_of_tolerance','controller_pid_miscalibrated','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-30',52000.00,'Cooling runaway — freezer removed, controller board replaced and validated'),
    ('CRF-KIM-51','seeding_temp_c','seeding_temp_out_of_tolerance','sensor_end_of_life','replace_probe','open','internal_only','2026-07-09',null,7200.00,'Seeding temp warm — seeding probe end of life, replacement ordered'),
    ('CRF-FRT-11','chamber_temp_c','chamber_temp_out_of_tolerance','controller_pid_miscalibrated','retune_pid_controller','overdue','iso_13485_deviation','2026-07-04',null,15000.00,'Chamber temp warm — PID tune past target date, vendor delay'),
    ('CRF-RGB-72','ln2_consumption','ln2_consumption_high','ln2_supply_low','refill_ln2_and_check_supply','open','none','2026-07-10',null,3000.00,'LN2 slightly high — supply topped up, monitor consumption')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.crf_cryo_qc_r3570 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3570_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crf_cryo_qc_r3570)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.crf_cryo_qc_r3570 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3570_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3570_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3570_device_model_scorecard()
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
  from public.crf_cryo_qc_r3570 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3570_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3570_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3570_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.crf_cryo_qc_r3570 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3570_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3570_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3570_monthly_calibration_trend()
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
  from public.crf_cryo_qc_r3570 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3570_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3570_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3570_capa_status_board()
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
  from public.crf_cryo_qc_capa_actions_r3570 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3570_capa_status_board() from public, anon;
grant execute on function public.founder_r3570_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3570_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crf_cryo_qc_capa_actions_r3570)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.crf_cryo_qc_capa_actions_r3570 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3570_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3570_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3570_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric, max_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.crf_cryo_qc_r3570 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3570_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3570_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3570_high_risk_queue()
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
  from public.crf_cryo_qc_r3570 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3570_high_risk_queue() from public, anon;
grant execute on function public.founder_r3570_high_risk_queue() to authenticated;
