-- Round 3494: Customer Hospital Laboratory Magnetic Stirrer / Hotplate QC Audit
-- Lab magnetic stirrer / hotplate QA — device model × lab section × parameter (speed, temp, uniformity, timer)
-- × reference/measured value × deviation × tolerance × calibration currency × qc verdict × CAPA closure

-- =============================================================================
-- TABLE 1: magnetic_stirrer_qc_r3494 — per-device parameter QC checks
-- =============================================================================
create table if not exists public.magnetic_stirrer_qc_r3494 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  lab_section text not null check (lab_section in (
    'biochemistry','microbiology','histopathology','molecular_lab','general_lab'
  )),
  parameter text not null check (parameter in (
    'set_rpm','measured_rpm','set_temp_c','measured_temp_c','temp_uniformity_c','timer_accuracy_pct'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  tolerance_limit_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.magnetic_stirrer_qc_r3494 enable row level security;

create index if not exists idx_magnetic_stirrer_qc_r3494_org on public.magnetic_stirrer_qc_r3494(organization_id);
create index if not exists idx_magnetic_stirrer_qc_r3494_caldate on public.magnetic_stirrer_qc_r3494(calibration_date);
create index if not exists idx_magnetic_stirrer_qc_r3494_verdict on public.magnetic_stirrer_qc_r3494(qc_verdict);

-- =============================================================================
-- TABLE 2: magnetic_stirrer_qc_capa_actions_r3494 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.magnetic_stirrer_qc_capa_actions_r3494 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.magnetic_stirrer_qc_r3494(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'speed_accuracy_out_of_tolerance','temperature_accuracy_out_of_tolerance',
    'temperature_uniformity_out_of_tolerance','timer_accuracy_out_of_tolerance',
    'calibration_overdue','hotplate_surface_damage','stir_bar_coupling_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'tachometer_drift','heater_element_degraded','temperature_sensor_drift','controller_pid_miscalibration',
    'worn_drive_magnet','timer_circuit_fault','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_speed','recalibrate_temperature','replace_temperature_sensor','replace_heater_element',
    'retune_pid_controller','replace_drive_magnet','repair_timer_circuit','retrain_lab_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','none','internal_only','iso_15189_deviation','iso_17025_deviation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.magnetic_stirrer_qc_capa_actions_r3494 enable row level security;

create index if not exists idx_magnetic_stirrer_capa_r3494_log on public.magnetic_stirrer_qc_capa_actions_r3494(qc_log_id);
create index if not exists idx_magnetic_stirrer_capa_r3494_status on public.magnetic_stirrer_qc_capa_actions_r3494(capa_status);

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

  -- 16 QC parameter check rows
  insert into public.magnetic_stirrer_qc_r3494 (
    organization_id, hospital_name, device_code, device_model, lab_section, parameter,
    reference_value, measured_value, deviation_pct, tolerance_limit_pct,
    within_tolerance, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.lsec, q.param,
    q.refv, q.measv, q.devp, q.tolp,
    q.wtol, q.caldt::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','STIR-APL-01','Remi 5MLH','biochemistry','measured_rpm',
     500,496,-0.8,3.0,true,'2026-07-05',true,'pass','Speed check within tolerance at 500 rpm setpoint'),
    ('Apollo Chennai','HOTP-APL-02','IKA C-MAG HS7','biochemistry','measured_temp_c',
     100,99.1,-0.9,2.0,true,'2026-07-05',true,'pass','Hotplate temperature accuracy within 2% at 100C'),
    ('Fortis Gurgaon','STIR-FRT-11','Tarsons Spinot','microbiology','measured_rpm',
     800,760,-5.0,3.0,false,'2026-07-04',true,'fail','Speed 40 rpm low at 800 setpoint, drive magnet suspected'),
    ('Fortis Gurgaon','HOTP-FRT-12','Thermo Cimarec','microbiology','temp_uniformity_c',
     0,2.6,2.6,1.5,false,'2026-07-04',true,'fail','Surface temperature uniformity 2.6C exceeds 1.5C limit'),
    ('Manipal Bengaluru','HOTP-MNP-21','IKA RCT Basic','histopathology','measured_temp_c',
     150,147.5,-1.7,2.0,true,'2026-07-03',true,'conditional_pass','Temp 1.7% low and trending down, monitor next cycle'),
    ('Manipal Bengaluru','STIR-MNP-22','Remi 5MLH','histopathology','timer_accuracy_pct',
     100,99.4,-0.6,1.0,true,'2026-07-03',true,'pass','Timer accuracy within 1% over 30 min run'),
    ('AIIMS Delhi','STIR-AIM-31','IKA C-MAG HS7','molecular_lab','measured_rpm',
     1200,1176,-2.0,3.0,true,'2026-07-02',true,'pass','High-speed stir check within tolerance'),
    ('AIIMS Delhi','HOTP-AIM-32','Borosil LMS','molecular_lab','measured_temp_c',
     200,208,4.0,2.0,false,'2026-07-02',false,'fail','Temp 4% high and calibration overdue, heater element degraded'),
    ('CMC Vellore','HOTP-CMC-41','Thermo Cimarec','general_lab','temp_uniformity_c',
     0,1.1,1.1,1.5,true,'2026-07-01',true,'pass','Uniformity 1.1C within 1.5C limit'),
    ('CMC Vellore','STIR-CMC-42','Tarsons Spinot','general_lab','measured_rpm',
     300,297,-1.0,3.0,true,'2026-07-01',true,'pass','Low-speed stir check nominal'),
    ('KIMS Hyderabad','STIR-KIM-51','Remi 5MLH','biochemistry','timer_accuracy_pct',
     100,97.8,-2.2,1.0,false,'2026-06-30',true,'fail','Timer 2.2% slow, timer circuit fault'),
    ('KIMS Hyderabad','HOTP-KIM-52','IKA RCT Basic','biochemistry','measured_temp_c',
     120,121.2,1.0,2.0,true,'2026-06-30',true,'pass','Temp accuracy within tolerance at 120C'),
    ('Apollo Chennai','STIR-APL-03','IKA C-MAG HS7','microbiology','set_rpm',
     600,600,0.0,3.0,true,'2026-06-29',true,'pass','Setpoint verification at 600 rpm, display matches tachometer'),
    ('Fortis Gurgaon','HOTP-FRT-13','Borosil LMS','histopathology','set_temp_c',
     180,180,0.0,2.0,true,'2026-06-29',false,'conditional_pass','Setpoint verified but calibration due next month'),
    ('Manipal Bengaluru','HOTP-MNP-23','Thermo Cimarec','molecular_lab','temp_uniformity_c',
     0,3.4,3.4,1.5,false,'2026-06-28',false,'fail','Severe hotspot 3.4C and overdue, surface damage, removed'),
    ('AIIMS Delhi','STIR-AIM-33','Tarsons Spinot','general_lab','measured_rpm',
     1000,912,-8.8,3.0,false,'2026-06-28',true,'fail','Speed 8.8% low, worn drive magnet and stir bar coupling loss')
  ) as q(hosp, dcode, dmodel, lsec, param, refv, measv, devp, tolp, wtol, caldt, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.magnetic_stirrer_qc_capa_actions_r3494 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('STIR-FRT-11','speed_accuracy_out_of_tolerance','worn_drive_magnet','replace_drive_magnet','in_progress','iso_15189_deviation','2026-07-08',null,6500.00,'Drive magnet replacement ordered, re-verify speed after fit'),
    ('HOTP-FRT-12','temperature_uniformity_out_of_tolerance','heater_element_degraded','replace_heater_element','open','nabl_finding','2026-07-09',null,18000.00,'Hotplate uniformity out of spec, heater element service scheduled'),
    ('HOTP-AIM-32','temperature_accuracy_out_of_tolerance','temperature_sensor_drift','replace_temperature_sensor','escalated','iso_15189_deviation','2026-07-06',null,12000.00,'Temp 4% high with overdue cal, escalated to biomedical'),
    ('STIR-KIM-51','timer_accuracy_out_of_tolerance','timer_circuit_fault','repair_timer_circuit','verification_pending','internal_only','2026-07-05',null,3200.00,'Timer board repaired, verify over 60 min run'),
    ('HOTP-MNP-23','hotplate_surface_damage','heater_element_degraded','remove_from_service','closed','nabh_finding','2026-07-03','2026-06-30',24000.00,'Surface hotspot and damage, unit removed and replacement installed'),
    ('STIR-AIM-33','stir_bar_coupling_failure','worn_drive_magnet','replace_drive_magnet','open','iso_17025_deviation','2026-07-07',null,6500.00,'Coupling loss at high rpm, magnet assembly replacement pending'),
    ('HOTP-FRT-13','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,4500.00,'Calibration due date passed, OEM visit delayed'),
    ('STIR-MNP-22','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-10',null,3000.00,'Preventive maintenance window due, routine service scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.magnetic_stirrer_qc_r3494 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3494_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.magnetic_stirrer_qc_r3494)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.magnetic_stirrer_qc_r3494 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3494_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3494_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3494_device_model_scorecard()
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
  from public.magnetic_stirrer_qc_r3494 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3494_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3494_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3494_parameter_verdict_matrix()
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
  from public.magnetic_stirrer_qc_r3494 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3494_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3494_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3494_monthly_calibration_trend()
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
  from public.magnetic_stirrer_qc_r3494 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3494_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3494_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3494_capa_status_board()
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
  from public.magnetic_stirrer_qc_capa_actions_r3494 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3494_capa_status_board() from public, anon;
grant execute on function public.founder_r3494_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3494_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.magnetic_stirrer_qc_capa_actions_r3494)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.magnetic_stirrer_qc_capa_actions_r3494 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3494_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3494_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3494_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric,
  out_of_tol_pct numeric
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
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.within_tolerance = false)::numeric / nullif(count(*),0), 1)
  from public.magnetic_stirrer_qc_r3494 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3494_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3494_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3494_high_risk_queue()
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
  from public.magnetic_stirrer_qc_r3494 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3494_high_risk_queue() from public, anon;
grant execute on function public.founder_r3494_high_risk_queue() to authenticated;
