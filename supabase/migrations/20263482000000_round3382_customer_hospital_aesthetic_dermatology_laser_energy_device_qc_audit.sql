-- Round 3382: Customer Hospital Aesthetic-Dermatology Laser & Energy-Device QC Audit
-- Aesthetic-derma QA — device type × fluence-energy accuracy × pulse/spot-size calibration × cooling system × handpiece condition × contact sensor × safety eyewear × e-stop × treatment counter × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: aesthetic_laser_r3382 — per-device laser/energy-device QC checks
-- =============================================================================
create table if not exists public.aesthetic_laser_r3382 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'ipl_system','q_switched_ndyag','co2_fractional','diode_hair_removal','rf_microneedling','cryosurgery_unit'
  )),
  department text not null,
  check_date date not null,
  check_started_at timestamptz not null,
  fluence_energy_accuracy_error_pct numeric(5,2),
  pulse_duration_ok boolean not null,
  spot_size_calibration_ok boolean not null,
  cooling_system_ok text not null check (cooling_system_ok in (
    'ok','weak','fail','not_applicable'
  )),
  handpiece_condition text not null check (handpiece_condition in (
    'good','worn','cracked','replace_due'
  )),
  skin_contact_sensor_ok boolean not null,
  safety_eyewear_available boolean not null,
  emergency_stop_ok boolean not null,
  treatment_counter_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.aesthetic_laser_r3382 enable row level security;

create index if not exists idx_aesthetic_laser_r3382_org on public.aesthetic_laser_r3382(organization_id);
create index if not exists idx_aesthetic_laser_r3382_date on public.aesthetic_laser_r3382(check_date);
create index if not exists idx_aesthetic_laser_r3382_verdict on public.aesthetic_laser_r3382(qc_verdict);

-- =============================================================================
-- TABLE 2: aesthetic_laser_capa_actions_r3382 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.aesthetic_laser_capa_actions_r3382 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.aesthetic_laser_r3382(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'fluence_energy_deviation','pulse_duration_fault','spot_size_miscalibration','cooling_system_failure',
    'handpiece_wear','skin_contact_sensor_fault','safety_eyewear_missing','emergency_stop_fault',
    'treatment_counter_fault','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'laser_diode_degradation','flashlamp_end_of_life','optics_contamination','cooling_pump_failure',
    'handpiece_fiber_damage','sensor_wiring_fault','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_laser_diode_module','replace_flashlamp','clean_recoat_optics','replace_cooling_pump',
    'replace_handpiece','replace_contact_sensor','update_software_config','retrain_clinic_staff',
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

alter table public.aesthetic_laser_capa_actions_r3382 enable row level security;

create index if not exists idx_aesthetic_laser_capa_r3382_log on public.aesthetic_laser_capa_actions_r3382(qc_log_id);
create index if not exists idx_aesthetic_laser_capa_r3382_status on public.aesthetic_laser_capa_actions_r3382(capa_status);

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

  -- 14 QC check rows
  insert into public.aesthetic_laser_r3382 (
    organization_id, hospital_name, device_code, device_type, department,
    check_date, check_started_at, fluence_energy_accuracy_error_pct,
    pulse_duration_ok, spot_size_calibration_ok, cooling_system_ok, handpiece_condition,
    skin_contact_sensor_ok, safety_eyewear_available, emergency_stop_ok, treatment_counter_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.dept,
    q.cdate::date, q.cstart::timestamptz, q.ferr,
    q.pdur, q.spot, q.cool, q.hand,
    q.skin, q.eyew, q.estop, q.tcount,
    q.calib, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','LZ-APL-01','ipl_system','Dermatology','2026-07-10','2026-07-10 08:00:00+05:30',
     2.10, true, true, 'ok','good', true, true, true, true, true, 'pass','Quarterly QC — fluence within tolerance, all interlocks OK'),
    ('Apollo Chennai Greams Road','LZ-APL-02','q_switched_ndyag','Cosmetology','2026-07-10','2026-07-10 09:15:00+05:30',
     7.80, true, true, 'ok','good', true, true, true, true, true, 'conditional_pass','Fluence error 7.8% above 5% limit — energy recheck booked'),
    ('Fortis Gurgaon Sector 44','LZ-FRT-11','co2_fractional','Plastic Surgery','2026-07-09','2026-07-09 07:40:00+05:30',
     3.20, true, true, 'fail','worn', true, true, true, true, true, 'fail','Cooling system failed at start — unit down, service raised'),
    ('Fortis Gurgaon Sector 44','LZ-FRT-12','diode_hair_removal','Dermatology','2026-07-09','2026-07-09 08:30:00+05:30',
     1.40, true, true, 'ok','good', true, true, true, true, true, 'pass','Routine QC clean pass'),
    ('Manipal Bengaluru Old Airport Rd','LZ-MNP-21','rf_microneedling','Aesthetics Clinic','2026-07-08','2026-07-08 10:05:00+05:30',
     2.60, true, true, 'ok','worn', true, true, true, true, true, 'conditional_pass','Microneedle handpiece tips worn — replacement scheduled'),
    ('Manipal Bengaluru Old Airport Rd','LZ-MNP-22','cryosurgery_unit','Dermatology OPD','2026-07-08','2026-07-08 11:00:00+05:30',
     0.90, true, true, 'not_applicable','good', true, true, true, true, true, 'pass','Cryo N2O pressure and timer verified'),
    ('AIIMS Delhi Ansari Nagar','LZ-AIM-31','q_switched_ndyag','Dermatology','2026-07-07','2026-07-07 06:50:00+05:30',
     9.40, false, false, 'weak','worn', true, true, true, false, false, 'fail','Spot-size miscalibrated, pulse duration off, calibration lapsed'),
    ('AIIMS Delhi Ansari Nagar','LZ-AIM-32','ipl_system','Cosmetology','2026-07-07','2026-07-07 07:45:00+05:30',
     1.80, true, true, 'ok','good', true, true, true, true, true, 'pass','Annual QC pass — lamp shot count nominal'),
    ('CMC Vellore','LZ-CMC-41','diode_hair_removal','Dermatology','2026-07-06','2026-07-06 08:20:00+05:30',
     2.30, true, true, 'ok','good', true, true, false, true, true, 'fail','Emergency-stop did not cut beam — removed pending repair'),
    ('CMC Vellore','LZ-CMC-42','co2_fractional','Plastic Surgery','2026-07-06','2026-07-06 09:10:00+05:30',
     4.10, true, true, 'ok','good', true, true, true, true, false, 'conditional_pass','Calibration certificate expired — recal booked with OEM'),
    ('KIMS Hyderabad Kondapur','LZ-KIM-51','rf_microneedling','Aesthetics Clinic','2026-07-05','2026-07-05 10:30:00+05:30',
     1.10, true, true, 'ok','good', true, true, true, true, true, 'pass','RF energy and depth control verified'),
    ('KIMS Hyderabad Kondapur','LZ-KIM-52','ipl_system','Dermatology OPD','2026-07-05','2026-07-05 11:15:00+05:30',
     3.50, true, true, 'weak','good', true, false, true, true, true, 'conditional_pass','Safety eyewear stock depleted, cooling weak — flagged'),
    ('Kokilaben Mumbai Andheri','LZ-KOK-61','cryosurgery_unit','Dermatology','2026-07-04','2026-07-04 07:30:00+05:30',
     null, false, true, 'fail','replace_due', false, true, true, false, false, 'removed_from_service','Multiple faults — sensor, counter, calibration; pulled from service'),
    ('Rainbow Childrens Hyderabad','LZ-RBW-71','diode_hair_removal','Dermatology','2026-07-04','2026-07-04 08:40:00+05:30',
     1.00, true, true, 'ok','good', true, true, true, true, true, 'pass','Low-fluence protocol verified for adolescent care')
  ) as q(hosp, code, dtype, dept, cdate, cstart, ferr, pdur, spot, cool, hand, skin, eyew, estop, tcount, calib, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.aesthetic_laser_capa_actions_r3382 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('LZ-FRT-11','cooling_system_failure','cooling_pump_failure','replace_cooling_pump','in_progress','patient_safety_alert','2026-07-14',null,55000.00,'Cooling pump replacement in progress — CO2 laser held'),
    ('LZ-AIM-31','spot_size_miscalibration','optics_contamination','clean_recoat_optics','escalated','cdsco_notifiable','2026-07-12',null,38000.00,'Optics contamination and cal lapse — escalated to OEM'),
    ('LZ-CMC-41','emergency_stop_fault','software_config_error','update_software_config','open','patient_safety_alert','2026-07-11',null,15000.00,'E-stop interlock did not cut beam — safety-critical, unit locked out'),
    ('LZ-CMC-42','calibration_overdue','preventive_service_backlog','schedule_oem_service','verification_pending','nabh_finding','2026-07-13',null,22000.00,'Recal scheduled — verify certificate on completion'),
    ('LZ-KIM-52','safety_eyewear_missing','operator_setup_error','retrain_clinic_staff','closed','internal_only','2026-07-08','2026-07-06',3000.00,'Eyewear restocked, staff briefed on wavelength-rated goggles'),
    ('LZ-KOK-61','handpiece_wear','handpiece_fiber_damage','replace_handpiece','overdue','iso_13485_deviation','2026-07-02',null,47000.00,'Cryo handpiece replacement past target — vendor delay'),
    ('LZ-APL-02','fluence_energy_deviation','laser_diode_degradation','replace_laser_diode_module','open','internal_only','2026-07-16',null,72000.00,'Diode output drifted — module quote awaited')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.aesthetic_laser_r3382 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3382_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.aesthetic_laser_r3382)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.aesthetic_laser_r3382 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3382_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3382_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3382_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  cooling_fail bigint,
  handpiece_replace bigint,
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
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.cooling_system_ok in ('weak','fail'))::bigint,
    count(*) filter (where l.handpiece_condition in ('cracked','replace_due'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.aesthetic_laser_r3382 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3382_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3382_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3382_device_department_matrix()
returns table(device_type text, department text, audits bigint, passed bigint, avg_fluence_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.fluence_energy_accuracy_error_pct), 2)
  from public.aesthetic_laser_r3382 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3382_device_department_matrix() from public, anon;
grant execute on function public.founder_r3382_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3382_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, cooling_fail bigint, calibration_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.cooling_system_ok in ('weak','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.aesthetic_laser_r3382 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3382_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3382_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3382_capa_status_board()
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
  from public.aesthetic_laser_capa_actions_r3382 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3382_capa_status_board() from public, anon;
grant execute on function public.founder_r3382_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3382_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.aesthetic_laser_capa_actions_r3382)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.aesthetic_laser_capa_actions_r3382 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3382_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3382_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3382_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.aesthetic_laser_capa_actions_r3382 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3382_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3382_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3382_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  cooling_system_ok text,
  handpiece_condition text,
  calibration_current boolean,
  fluence_energy_accuracy_error_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.cooling_system_ok, l.handpiece_condition, l.calibration_current,
    l.fluence_energy_accuracy_error_pct, l.notes
  from public.aesthetic_laser_r3382 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.cooling_system_ok in ('weak','fail')
     or l.handpiece_condition in ('cracked','replace_due')
     or l.pulse_duration_ok = false
     or l.spot_size_calibration_ok = false
     or l.skin_contact_sensor_ok = false
     or l.safety_eyewear_available = false
     or l.emergency_stop_ok = false
     or l.treatment_counter_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3382_high_risk_queue() from public, anon;
grant execute on function public.founder_r3382_high_risk_queue() to authenticated;
