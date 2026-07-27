-- Round 3499: Customer Hospital Vortex Mixer / Orbital Shaker (Lab) QC Audit
-- Lab equipment QA — vortex mixer / orbital shaker QC: parameter (set/measured RPM, orbit mm,
-- timer accuracy, platform temp, speed stability) × reference vs measured × deviation × tolerance
-- × calibration × verdict × lab section × device model × CAPA closure.

-- =============================================================================
-- TABLE 1: vortex_shaker_qc_r3499 — per-parameter vortex/shaker QC measurements
-- =============================================================================
create table if not exists public.vortex_shaker_qc_r3499 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  lab_section text not null check (lab_section in (
    'microbiology','biochemistry','hematology','molecular_biology','serology','blood_bank'
  )),
  parameter text not null check (parameter in (
    'set_rpm','measured_rpm','orbit_mm','timer_accuracy_pct','platform_temp_c','speed_stability_pct'
  )),
  reference_value numeric(10,3) not null,
  measured_value numeric(10,3) not null,
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  next_due_date date,
  technician text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vortex_shaker_qc_r3499 enable row level security;

create index if not exists idx_vortex_shaker_qc_r3499_org on public.vortex_shaker_qc_r3499(organization_id);
create index if not exists idx_vortex_shaker_qc_r3499_cal on public.vortex_shaker_qc_r3499(calibration_date);
create index if not exists idx_vortex_shaker_qc_r3499_verdict on public.vortex_shaker_qc_r3499(qc_verdict);

-- =============================================================================
-- TABLE 2: vortex_shaker_qc_capa_actions_r3499 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.vortex_shaker_qc_capa_actions_r3499 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.vortex_shaker_qc_r3499(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'speed_out_of_tolerance','orbit_diameter_deviation','timer_inaccuracy',
    'platform_temperature_drift','speed_instability','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'motor_belt_wear','speed_sensor_drift','controller_calibration_error','bearing_wear',
    'heater_element_fault','firmware_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_speed_controller','replace_drive_belt','replace_speed_sensor','replace_bearing_assembly',
    'replace_heater_element','update_firmware','retrain_lab_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cap_finding','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vortex_shaker_qc_capa_actions_r3499 enable row level security;

create index if not exists idx_vortex_shaker_capa_r3499_log on public.vortex_shaker_qc_capa_actions_r3499(qc_log_id);
create index if not exists idx_vortex_shaker_capa_r3499_status on public.vortex_shaker_qc_capa_actions_r3499(capa_status);

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
  insert into public.vortex_shaker_qc_r3499 (
    organization_id, hospital_name, device_code, device_model, lab_section, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, calibration_date,
    next_due_date, technician, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.sect, q.param,
    q.refv::numeric, q.measv::numeric, q.dev::numeric, q.wtol, q.caldate::date,
    q.nextdue::date, q.tech, q.qv, q.nt
  from (values
    ('Apollo Chennai','VTX-APL-01','Remi CM-101','microbiology','set_rpm',
     2500,2498,-0.08,true,'2026-07-05','2027-01-05','Ravi Kumar','pass','Vortex mixer set-RPM within tolerance'),
    ('Apollo Chennai','OSH-APL-02','Remi RS-24 Plus','biochemistry','orbit_mm',
     20.0,19.8,-1.00,true,'2026-07-05','2027-01-05','Ravi Kumar','pass','Orbital shaker orbit diameter within 2%'),
    ('Fortis Gurgaon','OSH-FRT-11','Kuhner LT-X','molecular_biology','speed_stability_pct',
     100,96.5,-3.50,false,'2026-06-28','2026-12-28','Anita Sharma','conditional_pass','Speed stability 3.5% out — belt inspection advised'),
    ('Fortis Gurgaon','VTX-FRT-12','IKA Vortex 3','hematology','measured_rpm',
     3000,2740,-8.67,false,'2026-06-28','2026-12-28','Anita Sharma','fail','Measured RPM 8.7% low — suspected motor/belt fault'),
    ('Manipal Bengaluru','OSH-MNP-21','Neuation iSWIX','serology','timer_accuracy_pct',
     100,99.4,-0.60,true,'2026-06-20','2026-12-20','Suresh Rao','pass','Timer accuracy within 1%'),
    ('Manipal Bengaluru','OSH-MNP-22','Remi RS-24 Plus','biochemistry','platform_temp_c',
     37.0,38.6,4.32,false,'2026-06-20','2026-12-20','Suresh Rao','fail','Heated platform 1.6C high — heater element drift'),
    ('AIIMS Delhi','VTX-AIM-31','Tarsons Spinix','microbiology','set_rpm',
     2000,1994,-0.30,true,'2026-05-30','2026-11-30','Meena Gupta','pass','Set RPM nominal'),
    ('AIIMS Delhi','OSH-AIM-32','Eppendorf Innova','molecular_biology','orbit_mm',
     25.0,23.4,-6.40,false,'2026-05-30','2026-11-30','Meena Gupta','fail','Orbit diameter 6.4% low — eccentric bearing wear'),
    ('CMC Vellore','VTX-CMC-41','Genei Vortex','blood_bank','measured_rpm',
     2800,2795,-0.18,true,'2026-07-02','2027-01-02','Thomas John','pass','Blood bank vortex RPM within spec'),
    ('CMC Vellore','OSH-CMC-42','Labnet Orbit P4','hematology','speed_stability_pct',
     100,99.1,-0.90,true,'2026-07-02','2027-01-02','Thomas John','pass','Speed stability nominal'),
    ('KIMS Hyderabad','OSH-KIM-51','Remi RS-24 Plus','biochemistry','timer_accuracy_pct',
     100,97.8,-2.20,false,'2026-06-15','2026-12-15','Priya Reddy','conditional_pass','Timer 2.2% slow — recalibrate controller'),
    ('KIMS Hyderabad','VTX-KIM-52','IKA Vortex 3','microbiology','set_rpm',
     2500,2503,0.12,true,'2026-06-15','2026-12-15','Priya Reddy','pass','Vortex set RPM within tolerance'),
    ('Yashoda Hyderabad','OSH-YSH-61','Neuation iSWIX','molecular_biology','platform_temp_c',
     30.0,30.2,0.67,true,'2026-05-25','2026-11-25','Kiran Das','pass','Cooled platform temp within 1C'),
    ('Yashoda Hyderabad','OSH-YSH-62','Kuhner LT-X','serology','orbit_mm',
     25.0,24.7,-1.20,true,'2026-05-25','2026-11-25','Kiran Das','pass','Orbit within 2%'),
    ('Kokilaben Mumbai','OSH-KKB-71','Eppendorf Innova','molecular_biology','speed_stability_pct',
     100,91.0,-9.00,false,'2026-07-08','2027-01-08','Farah Khan','fail','Speed stability 9% out — removed pending motor service'),
    ('Kokilaben Mumbai','VTX-KKB-72','Tarsons Spinix','hematology','measured_rpm',
     3000,2988,-0.40,true,'2026-07-08','2027-01-08','Farah Khan','pass','Vortex RPM within spec')
  ) as q(hosp, dcode, model, sect, param, refv, measv, dev, wtol, caldate, nextdue, tech, qv, nt);

  -- 8 CAPA rows — attach to specific checks via device_code
  insert into public.vortex_shaker_qc_capa_actions_r3499 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('OSH-FRT-11','speed_instability','motor_belt_wear','replace_drive_belt','in_progress','iso_15189_deviation','Anita Sharma','2026-07-10',null,4500.00,'Drive belt replacement scheduled — verify stability post-fix'),
    ('VTX-FRT-12','speed_out_of_tolerance','motor_belt_wear','replace_drive_belt','escalated','nabl_finding','Anita Sharma','2026-07-08',null,5200.00,'RPM 8.7% low — escalated, belt and tension check'),
    ('OSH-MNP-22','platform_temperature_drift','heater_element_fault','replace_heater_element','open','nabl_finding','Suresh Rao','2026-07-12',null,8800.00,'Heated platform overshoot — heater element order raised'),
    ('OSH-AIM-32','orbit_diameter_deviation','bearing_wear','replace_bearing_assembly','escalated','patient_safety_alert','Meena Gupta','2026-06-15',null,14500.00,'Orbit 6.4% low — eccentric bearing worn, OEM service'),
    ('OSH-KIM-51','timer_inaccuracy','controller_calibration_error','recalibrate_speed_controller','verification_pending','internal_only','Priya Reddy','2026-07-01',null,2000.00,'Controller recalibrated — verify timer next cycle'),
    ('OSH-KKB-71','speed_instability','motor_belt_wear','remove_from_service','open','iso_15189_deviation','Farah Khan','2026-07-15',null,16000.00,'Removed from service — motor service booked'),
    ('OSH-YSH-62','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','Kiran Das','2026-07-20',null,3000.00,'Preventive maintenance due — OEM visit scheduled'),
    ('OSH-CMC-42','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','closed','internal_only','Thomas John','2026-07-18','2026-07-16',3500.00,'Routine PM completed and verified')
  ) as q(dcode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.vortex_shaker_qc_r3499 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3499_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vortex_shaker_qc_r3499)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vortex_shaker_qc_r3499 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3499_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3499_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3499_device_model_scorecard()
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
  from public.vortex_shaker_qc_r3499 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3499_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3499_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3499_parameter_verdict_matrix()
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
  from public.vortex_shaker_qc_r3499 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3499_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3499_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3499_monthly_accuracy_trend()
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.vortex_shaker_qc_r3499 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3499_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3499_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3499_capa_status_board()
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
  from public.vortex_shaker_qc_capa_actions_r3499 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3499_capa_status_board() from public, anon;
grant execute on function public.founder_r3499_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3499_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vortex_shaker_qc_capa_actions_r3499)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vortex_shaker_qc_capa_actions_r3499 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3499_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3499_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3499_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
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
  from public.vortex_shaker_qc_r3499 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3499_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3499_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed measurements)
create or replace function public.founder_r3499_high_risk_queue()
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
  from public.vortex_shaker_qc_r3499 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3499_high_risk_queue() from public, anon;
grant execute on function public.founder_r3499_high_risk_queue() to authenticated;
