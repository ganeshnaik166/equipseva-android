-- Round 3166: Customer Hospital NICU Incubator & Radiant-Warmer Thermal-Safety Audit
-- NICU thermal QA log — device × set/measured temp × temp error × skin-probe accuracy × over-temp cutout × humidity × alarm × verdict + CAPA

-- =============================================================================
-- TABLE 1: nicu_incubator_r3166 — individual NICU thermal-safety audit records
-- =============================================================================
create table if not exists public.nicu_incubator_r3166 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  nicu_unit_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'incubator','radiant_warmer','phototherapy_unit',
    'transport_incubator','hybrid_warmer','open_care_system'
  )),
  test_date date not null,
  tested_at timestamptz not null,
  set_temperature_c numeric(5,2) not null,
  measured_temperature_c numeric(5,2) not null,
  temperature_error_c numeric(5,2) not null,
  control_mode text not null check (control_mode in (
    'air_mode','skin_servo_mode','manual_mode','preheat_mode'
  )),
  skin_probe_accuracy text not null check (skin_probe_accuracy in (
    'within_spec','minor_deviation','out_of_spec','probe_faulty','not_tested'
  )),
  skin_probe_error_c numeric(5,2),
  over_temp_cutout_test text not null check (over_temp_cutout_test in (
    'pass','fail','not_triggered','not_tested'
  )),
  over_temp_cutout_c numeric(5,2),
  humidity_pct numeric(5,2),
  humidity_verdict text not null check (humidity_verdict in (
    'within_spec','low','high','not_applicable','not_tested'
  )),
  alarm_test text not null check (alarm_test in (
    'pass','fail','delayed','silent','not_tested'
  )),
  audible_alarm_db numeric(5,2),
  safety_verdict text not null check (safety_verdict in (
    'passed','conditional_pass','failed','quarantined','recalibrate_needed','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nicu_incubator_r3166 enable row level security;

create index if not exists idx_nicu_incubator_r3166_org on public.nicu_incubator_r3166(organization_id);
create index if not exists idx_nicu_incubator_r3166_date on public.nicu_incubator_r3166(test_date);
create index if not exists idx_nicu_incubator_r3166_verdict on public.nicu_incubator_r3166(safety_verdict);

-- =============================================================================
-- TABLE 2: nicu_incubator_capa_actions_r3166 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.nicu_incubator_capa_actions_r3166 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.nicu_incubator_r3166(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_overshoot','temperature_undershoot','skin_probe_inaccuracy',
    'over_temp_cutout_fail','humidity_deviation','alarm_failure',
    'sensor_drift','calibration_overdue','preventive_maintenance_due','probe_damage'
  )),
  root_cause text not null check (root_cause in (
    'temperature_sensor_drift','skin_probe_worn','heater_element_degraded',
    'humidity_reservoir_fault','fan_airflow_blocked','control_board_fault',
    'calibration_overdue','operator_setup_error','power_fluctuation','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_temperature_sensor','replace_skin_probe','replace_heater_element',
    'service_humidity_system','clean_airflow_path','replace_control_board',
    'schedule_amc_visit','retrain_operator','quarantine_device','none_required'
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

alter table public.nicu_incubator_capa_actions_r3166 enable row level security;

create index if not exists idx_nicu_incubator_capa_r3166_audit on public.nicu_incubator_capa_actions_r3166(audit_log_id);
create index if not exists idx_nicu_incubator_capa_r3166_status on public.nicu_incubator_capa_actions_r3166(capa_status);

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

  -- 14 NICU thermal-safety audit rows
  insert into public.nicu_incubator_r3166 (
    organization_id, hospital_name, nicu_unit_code, device_asset_tag, device_model, device_type,
    test_date, tested_at, set_temperature_c, measured_temperature_c, temperature_error_c,
    control_mode, skin_probe_accuracy, skin_probe_error_c, over_temp_cutout_test, over_temp_cutout_c,
    humidity_pct, humidity_verdict, alarm_test, audible_alarm_db, safety_verdict, notes
  )
  select v_org_id, q.hosp, q.unit, q.tag, q.model, q.dtype,
    q.td::date, q.ta::timestamptz, q.setc, q.meas, q.err,
    q.cmode, q.spa, q.spe, q.oct, q.octc,
    q.hum, q.humv, q.alm, q.almdb, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','NICU-A','INC-APL-101','Draeger Isolette 8000','incubator',
     '2026-07-15','2026-07-15 08:30:00+05:30',36.50,36.60,0.10,
     'skin_servo_mode','within_spec',0.10,'pass',38.20,
     60.00,'within_spec','pass',68.00,'passed','Routine QA all within spec'),
    ('Apollo Hyderabad Jubilee Hills','NICU-A','RWM-APL-102','GE Lullaby Warmer','radiant_warmer',
     '2026-07-15','2026-07-15 09:15:00+05:30',36.80,37.10,0.30,
     'skin_servo_mode','minor_deviation',0.30,'pass',39.00,
     null,'not_applicable','pass',70.00,'conditional_pass','Skin probe reads 0.3C high — monitor'),
    ('Fortis Bannerghatta Bengaluru','NICU-1','INC-FRT-201','Draeger Caleo','incubator',
     '2026-07-14','2026-07-14 07:45:00+05:30',36.50,37.40,0.90,
     'air_mode','out_of_spec',0.80,'pass',38.50,
     55.00,'low','pass',66.00,'failed','Air temp 0.9C over — sensor drift, quarantined'),
    ('Fortis Bannerghatta Bengaluru','NICU-1','PHT-FRT-202','Phoenix Bili Phototherapy','phototherapy_unit',
     '2026-07-14','2026-07-14 08:30:00+05:30',0.00,0.00,0.00,
     'manual_mode','not_tested',null,'not_tested',null,
     null,'not_applicable','pass',65.00,'passed','Phototherapy irradiance OK, no thermal control'),
    ('Manipal Whitefield Bengaluru','NICU-2','INC-MNP-301','Fanem 1186','incubator',
     '2026-07-14','2026-07-14 06:50:00+05:30',36.50,36.55,0.05,
     'skin_servo_mode','within_spec',0.10,'pass',38.30,
     62.00,'within_spec','pass',69.00,'passed','Post-calibration verification passed'),
    ('Manipal Whitefield Bengaluru','NICU-2','RWM-MNP-302','GE Panda iRes','radiant_warmer',
     '2026-07-13','2026-07-13 10:20:00+05:30',36.80,36.90,0.10,
     'skin_servo_mode','within_spec',0.10,'fail',40.50,
     null,'not_applicable','delayed',62.00,'conditional_pass','Over-temp cutout triggered late at 40.5C — flagged'),
    ('AIIMS New Delhi Ansari Nagar','NICU-5','INC-AIM-401','Draeger TI500 Transport','transport_incubator',
     '2026-07-13','2026-07-13 05:40:00+05:30',36.50,36.70,0.20,
     'air_mode','minor_deviation',0.20,'pass',38.60,
     58.00,'within_spec','pass',67.00,'passed','Transport unit pre-dispatch check'),
    ('AIIMS New Delhi Ansari Nagar','NICU-5','RWM-AIM-402','Phoenix Radiant Warmer','radiant_warmer',
     '2026-07-12','2026-07-12 07:15:00+05:30',36.80,38.20,1.40,
     'skin_servo_mode','out_of_spec',1.30,'fail',41.20,
     null,'not_applicable','silent',0.00,'quarantined','Runaway heating 1.4C over, alarm silent — device pulled'),
    ('KIMS Secunderabad','NICU-4','INC-KIM-501','Atom Incu i','incubator',
     '2026-07-12','2026-07-12 08:00:00+05:30',36.50,36.20,0.30,
     'air_mode','minor_deviation',0.20,'pass',38.40,
     48.00,'low','pass',66.00,'conditional_pass','Humidity low at 48% — reservoir refilled'),
    ('KIMS Secunderabad','NICU-4','INC-KIM-502','Atom Incu ii','incubator',
     '2026-07-11','2026-07-11 09:30:00+05:30',36.50,37.30,0.80,
     'skin_servo_mode','probe_faulty',1.10,'pass',38.70,
     61.00,'within_spec','pass',68.00,'recalibrate_needed','Skin probe faulty reading — replace and recalibrate'),
    ('Care Hospitals Banjara Hills','NICU-2','PHT-CAR-601','Natus neoBLUE','phototherapy_unit',
     '2026-07-11','2026-07-11 11:00:00+05:30',0.00,0.00,0.00,
     'manual_mode','not_tested',null,'not_tested',null,
     null,'not_applicable','pass',64.00,'passed','LED phototherapy alarm test passed'),
    ('Yashoda Somajiguda Hyderabad','NICU-6','INC-YSH-701','Draeger Isolette C2000','incubator',
     '2026-07-10','2026-07-10 06:20:00+05:30',36.50,36.60,0.10,
     'skin_servo_mode','within_spec',0.10,'pass',38.20,
     63.00,'within_spec','pass',69.00,'passed','Daily thermal QA nominal'),
    ('St John''s Bengaluru','NICU-1','RWM-STJ-801','GE Lullaby XP','radiant_warmer',
     '2026-07-10','2026-07-10 07:50:00+05:30',36.80,37.00,0.20,
     'skin_servo_mode','within_spec',0.10,'pass',39.10,
     null,'not_applicable','pass',70.00,'passed','Weekly warmer safety check passed'),
    ('Rainbow Children''s Hyderabad','NICU-3','INC-RBW-901','GE Giraffe OmniBed','hybrid_warmer',
     '2026-07-09','2026-07-09 08:40:00+05:30',36.50,36.90,0.40,
     'skin_servo_mode','minor_deviation',0.30,'not_tested',null,
     59.00,'within_spec','delayed',64.00,'pending_review','Cutout test skipped — alarm delayed, review pending')
  ) as q(hosp, unit, tag, model, dtype, td, ta, setc, meas, err, cmode, spa, spe, oct, octc, hum, humv, alm, almdb, verdict, nt);

  -- CAPA seed — attach to specific audit records by unique asset tag
  insert into public.nicu_incubator_capa_actions_r3166 (
    audit_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('INC-FRT-201','temperature_overshoot','temperature_sensor_drift','recalibrate_temperature_sensor',
     '2026-07-20',null,'in_progress','nabh_finding',8500.00,'Air-mode sensor drift 0.9C — recalibration booked'),
    ('RWM-MNP-302','over_temp_cutout_fail','control_board_fault','replace_control_board',
     '2026-07-18',null,'escalated','patient_safety_alert',32000.00,'Cutout triggered late — control board replacement escalated'),
    ('RWM-AIM-402','temperature_overshoot','heater_element_degraded','replace_heater_element',
     '2026-07-16','2026-07-14','closed','cdsco_notifiable',45000.00,'Runaway heating — heater + alarm module replaced, retested pass'),
    ('INC-KIM-502','skin_probe_inaccuracy','skin_probe_worn','replace_skin_probe',
     '2026-07-15','2026-07-13','closed','iso_13485_deviation',3500.00,'Skin probe replaced, servo accuracy verified'),
    ('INC-KIM-501','humidity_deviation','humidity_reservoir_fault','service_humidity_system',
     '2026-07-19',null,'open','internal_only',2200.00,'Humidity reservoir seal service scheduled'),
    ('INC-RBW-901','alarm_failure','calibration_overdue','schedule_amc_visit',
     '2026-07-08',null,'overdue','nabh_finding',15000.00,'Cutout test + alarm calibration overdue by 10 days')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.nicu_incubator_r3166 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Safety verdict distribution
create or replace function public.founder_r3166_safety_verdict_rollup()
returns table(safety_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nicu_incubator_r3166)
  select l.safety_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nicu_incubator_r3166 l
  group by l.safety_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3166_safety_verdict_rollup() from public, anon;
grant execute on function public.founder_r3166_safety_verdict_rollup() to authenticated;

-- 2) Hospital-level thermal-safety scorecard
create or replace function public.founder_r3166_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  failed bigint,
  quarantined bigint,
  cutout_fail bigint,
  probe_issues bigint,
  alarm_issues bigint,
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
    count(*) filter (where l.safety_verdict = 'passed')::bigint,
    count(*) filter (where l.safety_verdict = 'failed')::bigint,
    count(*) filter (where l.safety_verdict = 'quarantined')::bigint,
    count(*) filter (where l.over_temp_cutout_test = 'fail')::bigint,
    count(*) filter (where l.skin_probe_accuracy in ('out_of_spec','probe_faulty'))::bigint,
    count(*) filter (where l.alarm_test in ('fail','delayed','silent'))::bigint,
    round(100.0 * count(*) filter (where l.safety_verdict = 'passed')::numeric / nullif(count(*),0), 1)
  from public.nicu_incubator_r3166 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3166_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3166_hospital_scorecard() to authenticated;

-- 3) Device-type × control-mode matrix
create or replace function public.founder_r3166_device_control_matrix()
returns table(device_type text, control_mode text, audits bigint, passed bigint, avg_temp_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.control_mode, count(*)::bigint,
    count(*) filter (where l.safety_verdict = 'passed')::bigint,
    round(avg(abs(l.temperature_error_c)), 2)
  from public.nicu_incubator_r3166 l
  group by l.device_type, l.control_mode
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3166_device_control_matrix() from public, anon;
grant execute on function public.founder_r3166_device_control_matrix() to authenticated;

-- 4) Daily thermal-safety trend
create or replace function public.founder_r3166_thermal_daily_trend()
returns table(test_date date, audits bigint, passed bigint, failed bigint, cutout_fail bigint, alarm_issues bigint, avg_temp_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.safety_verdict = 'passed')::bigint,
    count(*) filter (where l.safety_verdict in ('failed','quarantined'))::bigint,
    count(*) filter (where l.over_temp_cutout_test = 'fail')::bigint,
    count(*) filter (where l.alarm_test in ('fail','delayed','silent'))::bigint,
    round(avg(abs(l.temperature_error_c)), 2)
  from public.nicu_incubator_r3166 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3166_thermal_daily_trend() from public, anon;
grant execute on function public.founder_r3166_thermal_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3166_capa_status_board()
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
  from public.nicu_incubator_capa_actions_r3166 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3166_capa_status_board() from public, anon;
grant execute on function public.founder_r3166_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3166_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nicu_incubator_capa_actions_r3166)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nicu_incubator_capa_actions_r3166 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3166_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3166_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3166_regulatory_impact_digest()
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
  from public.nicu_incubator_capa_actions_r3166 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3166_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3166_regulatory_impact_digest() to authenticated;

-- 8) High-risk devices priority queue
create or replace function public.founder_r3166_high_risk_devices()
returns table(
  hospital_name text,
  nicu_unit_code text,
  device_asset_tag text,
  device_type text,
  test_date date,
  safety_verdict text,
  temperature_error_c numeric,
  over_temp_cutout_test text,
  skin_probe_accuracy text,
  alarm_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.nicu_unit_code, l.device_asset_tag, l.device_type, l.test_date,
    l.safety_verdict, l.temperature_error_c, l.over_temp_cutout_test, l.skin_probe_accuracy, l.alarm_test, l.notes
  from public.nicu_incubator_r3166 l
  where l.safety_verdict in ('failed','quarantined','recalibrate_needed','pending_review','conditional_pass')
     or l.over_temp_cutout_test = 'fail'
     or l.skin_probe_accuracy in ('out_of_spec','probe_faulty')
     or l.alarm_test in ('fail','delayed','silent')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3166_high_risk_devices() from public, anon;
grant execute on function public.founder_r3166_high_risk_devices() to authenticated;
