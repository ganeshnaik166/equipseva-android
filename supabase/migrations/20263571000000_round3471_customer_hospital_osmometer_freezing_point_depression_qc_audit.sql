-- Round 3471: Customer Hospital Osmometer (Freezing-Point Depression) QC Audit
-- Hospital osmometer QC — serum/urine osmolality via freezing-point depression:
-- parameter × sample type × reference vs measured × deviation % × tolerance × repeatability CV
-- × calibration currency × QC verdict × CAPA closure

-- =============================================================================
-- TABLE 1: osmometer_qc_r3471 — per-check osmometer QC records
-- =============================================================================
create table if not exists public.osmometer_qc_r3471 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'osmolality_mosm','freezing_point_mc','cooling_rate','probe_calibration',
    'repeatability_cv','sample_volume_ul'
  )),
  sample_type text not null check (sample_type in (
    'serum','urine','qc_control_low','qc_control_high','reference_standard'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  within_tolerance boolean not null,
  repeatability_cv_pct numeric(6,2),
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.osmometer_qc_r3471 enable row level security;

create index if not exists idx_osmometer_qc_r3471_org on public.osmometer_qc_r3471(organization_id);
create index if not exists idx_osmometer_qc_r3471_caldate on public.osmometer_qc_r3471(calibration_date);
create index if not exists idx_osmometer_qc_r3471_verdict on public.osmometer_qc_r3471(qc_verdict);

-- =============================================================================
-- TABLE 2: osmometer_qc_capa_actions_r3471 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.osmometer_qc_capa_actions_r3471 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.osmometer_qc_r3471(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'osmolality_bias_out_of_tolerance','freezing_point_drift','cooling_rate_out_of_spec',
    'probe_calibration_failure','poor_repeatability_cv','sample_volume_error',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'thermistor_probe_drift','calibrator_expired','cooling_module_degraded',
    'sample_pipette_miscalibrated','operator_technique_error','reference_standard_contaminated',
    'firmware_config_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_with_standards','replace_thermistor_probe','replace_calibrator_lot',
    'service_cooling_module','recalibrate_sample_pipette','retrain_lab_staff',
    'update_firmware_config','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only',
    'iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.osmometer_qc_capa_actions_r3471 enable row level security;

create index if not exists idx_osmometer_qc_capa_r3471_log on public.osmometer_qc_capa_actions_r3471(qc_log_id);
create index if not exists idx_osmometer_qc_capa_r3471_status on public.osmometer_qc_capa_actions_r3471(capa_status);

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
  insert into public.osmometer_qc_r3471 (
    organization_id, hospital_name, device_code, device_model, parameter, sample_type,
    reference_value, measured_value, deviation_pct, tolerance_pct, within_tolerance,
    repeatability_cv_pct, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.param, q.stype,
    q.refval, q.measval, q.devpct, q.tolpct, q.wtol,
    q.cv, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','OSM-APL-01','Advanced 3320','osmolality_mosm','serum',
     290.0,291.0,0.34,2.0,true,0.8,'2026-07-05',true,'pass','Serum osmolality within tolerance vs 290 mOsm/kg standard'),
    ('Apollo Chennai','OSM-APL-02','Advanced 3320','freezing_point_mc','reference_standard',
     -540.0,-538.0,0.37,2.0,true,0.9,'2026-07-05',true,'pass','Freezing-point depression check nominal against reference'),
    ('Fortis Gurgaon','OSM-FRT-11','OsmoTECH XT','osmolality_mosm','urine',
     850.0,872.0,2.59,2.0,false,1.4,'2026-07-04',true,'conditional_pass','Urine osmolality bias 2.6% exceeds 2% tolerance — recheck scheduled'),
    ('Fortis Gurgaon','OSM-FRT-12','OsmoTECH XT','probe_calibration','qc_control_high',
     1000.0,1043.0,4.30,2.0,false,2.6,'2026-07-04',false,'fail','Probe calibration off 4.3% and calibration overdue — expired calibrator'),
    ('Manipal Bengaluru','OSM-MNP-21','Gonotec Osmomat 3000','cooling_rate','reference_standard',
     100.0,96.0,-4.00,3.0,false,1.1,'2026-07-03',true,'fail','Cooling rate 4% low — cooling module degradation suspected'),
    ('Manipal Bengaluru','OSM-MNP-22','Gonotec Osmomat 3000','repeatability_cv','qc_control_low',
     1.0,1.05,5.00,3.0,false,3.1,'2026-07-03',true,'conditional_pass','Repeatability CV 3.1% above 3% target — operator technique review'),
    ('AIIMS Delhi','OSM-AIM-31','Advanced 3250','osmolality_mosm','serum',
     290.0,289.0,-0.34,2.0,true,0.7,'2026-06-30',true,'pass','Serum osmolality QC pass post-AMC calibration'),
    ('AIIMS Delhi','OSM-AIM-32','Advanced 3250','sample_volume_ul','qc_control_high',
     250.0,246.0,-1.60,2.0,true,1.0,'2026-06-30',true,'conditional_pass','Sample volume 1.6% low but within tolerance — pipette watch flagged'),
    ('CMC Vellore','OSM-CMC-41','Fiske 210','osmolality_mosm','urine',
     500.0,503.0,0.60,2.0,true,0.9,'2026-06-29',true,'pass','Urine osmolality within tolerance vs 500 mOsm/kg control'),
    ('CMC Vellore','OSM-CMC-42','Fiske 210','freezing_point_mc','reference_standard',
     -1000.0,-1058.0,5.80,2.0,false,1.8,'2026-06-29',false,'fail','Freezing-point drift 5.8% and calibration overdue — thermistor drift'),
    ('KIMS Hyderabad','OSM-KIM-51','Advanced 3320','probe_calibration','qc_control_low',
     100.0,101.0,1.00,2.0,true,0.6,'2026-06-28',true,'pass','Probe calibration verified against 100 mOsm/kg standard'),
    ('KIMS Hyderabad','OSM-KIM-52','Advanced 3320','repeatability_cv','serum',
     1.0,0.9,-10.00,3.0,true,0.9,'2026-06-28',true,'pass','Repeatability CV 0.9% — excellent precision'),
    ('Yashoda Hyderabad','OSM-YSH-61','Loser OM-815','cooling_rate','reference_standard',
     100.0,99.0,-1.00,3.0,true,1.2,'2026-06-27',true,'pass','Cooling rate nominal within 3% tolerance'),
    ('Yashoda Hyderabad','OSM-YSH-62','Loser OM-815','osmolality_mosm','qc_control_high',
     900.0,927.0,3.00,2.0,false,2.2,'2026-06-27',true,'conditional_pass','High QC control osmolality bias 3% — recalibration due'),
    ('Kokilaben Mumbai','OSM-KKB-71','OsmoTECH XT','sample_volume_ul','qc_control_low',
     250.0,262.0,4.80,2.0,false,3.4,'2026-06-26',false,'fail','Sample volume 4.8% high, poor repeatability, calibration overdue — pipette and service'),
    ('Kokilaben Mumbai','OSM-KKB-72','OsmoTECH XT','freezing_point_mc','serum',
     -540.0,-541.0,0.19,2.0,true,0.7,'2026-06-26',true,'pass','Serum freezing-point depression check pass')
  ) as q(hosp, dcode, model, param, stype, refval, measval, devpct, tolpct, wtol, cv, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.osmometer_qc_capa_actions_r3471 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('OSM-FRT-12','probe_calibration_failure','calibrator_expired','replace_calibrator_lot','in_progress','iso_15189_deviation','2026-07-08',null,12000.00,'Calibrator lot expired — fresh lot ordered, recheck pending'),
    ('OSM-MNP-21','cooling_rate_out_of_spec','cooling_module_degraded','service_cooling_module','escalated','nabl_finding','2026-07-07',null,38000.00,'Cooling module underperforming — OEM service escalated'),
    ('OSM-CMC-42','freezing_point_drift','thermistor_probe_drift','replace_thermistor_probe','open','nabl_finding','2026-07-06',null,26000.00,'Thermistor drift on freezing-point channel — probe replacement scheduled'),
    ('OSM-KKB-71','sample_volume_error','sample_pipette_miscalibrated','recalibrate_sample_pipette','verification_pending','internal_only','2026-07-05',null,4500.00,'Sample pipette recalibrated — verify volume accuracy next run'),
    ('OSM-FRT-11','osmolality_bias_out_of_tolerance','calibrator_expired','recalibrate_with_standards','closed','internal_only','2026-07-02','2026-06-30',3000.00,'Recalibrated with fresh standards — urine osmolality bias resolved'),
    ('OSM-MNP-22','poor_repeatability_cv','operator_technique_error','retrain_lab_staff','open','none','2026-07-09',null,0.00,'Repeatability CV above target — staff retraining on sampling technique'),
    ('OSM-YSH-62','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','nabh_finding','2026-06-30',null,15000.00,'Recalibration past target date — vendor service slot delayed'),
    ('OSM-AIM-32','sample_volume_error','sample_pipette_miscalibrated','recalibrate_sample_pipette','closed','iso_15189_deviation','2026-07-03','2026-07-01',4200.00,'Sample volume low flag — pipette recalibrated and verified')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.osmometer_qc_r3471 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3471_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.osmometer_qc_r3471)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.osmometer_qc_r3471 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3471_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3471_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3471_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.calibration_current = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.osmometer_qc_r3471 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3471_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3471_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3471_parameter_verdict_matrix()
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
  from public.osmometer_qc_r3471 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3471_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3471_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3471_monthly_calibration_trend()
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
  from public.osmometer_qc_r3471 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3471_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3471_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3471_capa_status_board()
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
  from public.osmometer_qc_capa_actions_r3471 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3471_capa_status_board() from public, anon;
grant execute on function public.founder_r3471_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3471_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.osmometer_qc_capa_actions_r3471)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.osmometer_qc_capa_actions_r3471 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3471_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3471_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3471_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric,
  avg_repeatability_cv_pct numeric
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
    round(max(abs(l.deviation_pct)), 2),
    round(avg(l.repeatability_cv_pct), 2)
  from public.osmometer_qc_r3471 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3471_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3471_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3471_high_risk_queue()
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
  from public.osmometer_qc_r3471 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3471_high_risk_queue() from public, anon;
grant execute on function public.founder_r3471_high_risk_queue() to authenticated;
