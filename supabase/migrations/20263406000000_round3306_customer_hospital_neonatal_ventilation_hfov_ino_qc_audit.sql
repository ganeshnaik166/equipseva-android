-- Round 3306: Customer Hospital Neonatal Advanced-Ventilation (HFOV / iNO) QC Audit
-- NICU QA — device type × tidal/pressure accuracy × oscillation amplitude × iNO dose × NO2 scavenging × blender × alarm-battery × circuit-leak × calibration × CAPA

-- =============================================================================
-- TABLE 1: neonatal_vent_r3306 — per-device neonatal ventilation QC checks
-- =============================================================================
create table if not exists public.neonatal_vent_r3306 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'neonatal_servo_ventilator','hfov_oscillator','ino_delivery_system','cpap_bubble_neonatal','nasal_hfnc'
  )),
  nicu_unit text not null,
  check_date date not null,
  tidal_volume_accuracy_error_pct numeric(5,2),
  pressure_delivery_error_cmh2o numeric(5,2),
  oscillation_amplitude_ok text not null check (oscillation_amplitude_ok in (
    'ok','drift','fail','not_applicable'
  )),
  ino_dose_accuracy_error_ppm numeric(6,2),
  no2_scavenging_ok boolean,
  oxygen_blender_accuracy_ok boolean,
  alarm_battery_test text not null check (alarm_battery_test in (
    'pass','fail','not_tested'
  )),
  circuit_leak_test text not null check (circuit_leak_test in (
    'pass','minor_leak','fail'
  )),
  humidifier_function_ok boolean,
  calibration_current boolean not null default true,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neonatal_vent_r3306 enable row level security;

create index if not exists idx_neonatal_vent_r3306_org on public.neonatal_vent_r3306(organization_id);
create index if not exists idx_neonatal_vent_r3306_date on public.neonatal_vent_r3306(check_date);
create index if not exists idx_neonatal_vent_r3306_verdict on public.neonatal_vent_r3306(qc_verdict);

-- =============================================================================
-- TABLE 2: neonatal_vent_capa_actions_r3306 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neonatal_vent_capa_actions_r3306 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.neonatal_vent_r3306(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'tidal_volume_deviation','pressure_delivery_error','oscillation_amplitude_fault','ino_dose_deviation',
    'no2_scavenging_failure','oxygen_blender_error','alarm_battery_failure','circuit_leak',
    'humidifier_fault','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'flow_sensor_drift','pressure_transducer_drift','oscillator_diaphragm_wear','ino_analyzer_miscalibration',
    'scavenging_line_blocked','blender_valve_wear','battery_end_of_life','circuit_connector_leak',
    'humidifier_element_fault','calibration_backlog','operator_setup_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_flow_sensor','recalibrate_pressure_transducer','replace_oscillator_diaphragm','recalibrate_ino_analyzer',
    'clear_scavenging_line','replace_blender_valve','replace_battery','replace_circuit',
    'replace_humidifier_element','complete_calibration','retrain_nicu_staff','remove_from_service',
    'schedule_oem_service','none_required'
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

alter table public.neonatal_vent_capa_actions_r3306 enable row level security;

create index if not exists idx_neonatal_vent_capa_r3306_log on public.neonatal_vent_capa_actions_r3306(qc_log_id);
create index if not exists idx_neonatal_vent_capa_r3306_status on public.neonatal_vent_capa_actions_r3306(capa_status);

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

  -- 14 neonatal ventilation QC check rows
  insert into public.neonatal_vent_r3306 (
    organization_id, hospital_name, device_code, device_type, nicu_unit, check_date,
    tidal_volume_accuracy_error_pct, pressure_delivery_error_cmh2o, oscillation_amplitude_ok,
    ino_dose_accuracy_error_ppm, no2_scavenging_ok, oxygen_blender_accuracy_ok,
    alarm_battery_test, circuit_leak_test, humidifier_function_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.nunit, q.cdate::date,
    q.tv_err, q.pd_err, q.osc,
    q.ino_err, q.no2, q.blender,
    q.alarm, q.leak, q.humid, q.calib,
    q.verdict, q.notes
  from (values
    ('Apollo Chennai Greams Road','NV-APL-101','neonatal_servo_ventilator','NICU-A','2026-07-02',
     2.10,0.80,'not_applicable',null,null,true,'pass','pass',true,true,'pass','Quarterly QC — tidal and pressure within spec'),
    ('Apollo Chennai Greams Road','NV-APL-102','hfov_oscillator','NICU-B','2026-07-02',
     3.40,1.20,'drift',null,null,true,'pass','minor_leak',true,true,'conditional_pass','Oscillation amplitude drift and minor circuit leak — recheck booked'),
    ('Fortis Gurgaon','NV-FRT-201','ino_delivery_system','NICU-1','2026-07-01',
     null,0.90,'not_applicable',4.80,false,true,'pass','pass',true,true,'fail','iNO dose error 4.8 ppm high and NO2 scavenging failed — off patient'),
    ('Fortis Gurgaon','NV-FRT-202','neonatal_servo_ventilator','NICU-2','2026-07-01',
     9.60,5.40,'not_applicable',null,null,false,'fail','fail',true,false,'removed_from_service','Tidal 9.6% off, pressure 5.4 cmH2O error, blender out — unit pulled'),
    ('Manipal Bengaluru Old Airport Road','NV-MNP-301','cpap_bubble_neonatal','NICU-A','2026-06-30',
     null,0.60,'not_applicable',null,null,true,'pass','pass',true,true,'pass','Bubble CPAP pressure and humidifier nominal'),
    ('Manipal Bengaluru Old Airport Road','NV-MNP-302','nasal_hfnc','NICU-B','2026-06-30',
     null,null,'not_applicable',null,null,true,'pass','pass',false,true,'conditional_pass','HFNC humidifier under-heating — thermostat watch'),
    ('AIIMS Delhi Ansari Nagar','NV-AIM-401','hfov_oscillator','NICU-3','2026-06-29',
     4.20,3.80,'fail',null,null,true,'pass','minor_leak',true,false,'fail','HFOV oscillation amplitude fail and calibration expired'),
    ('AIIMS Delhi Ansari Nagar','NV-AIM-402','neonatal_servo_ventilator','NICU-4','2026-06-29',
     1.80,0.50,'not_applicable',null,null,true,'pass','pass',true,true,'pass','Annual QC clean pass'),
    ('CMC Vellore','NV-CMC-501','ino_delivery_system','NICU-1','2026-06-28',
     null,1.10,'not_applicable',1.90,true,true,'pass','minor_leak',true,true,'conditional_pass','iNO within 2 ppm, minor sample-line leak — monitor'),
    ('KIMS Hyderabad','NV-KIM-601','cpap_bubble_neonatal','NICU-A','2026-06-28',
     null,4.90,'not_applicable',null,null,true,'fail','pass',true,true,'fail','Alarm battery failed load test and pressure 4.9 cmH2O off'),
    ('Rainbow Children''s Hyderabad','NV-RBW-701','neonatal_servo_ventilator','NICU-B','2026-06-27',
     3.10,1.40,'not_applicable',null,null,false,'pass','pass',true,true,'conditional_pass','Oxygen blender FiO2 accuracy borderline — service scheduled'),
    ('Cloudnine Bengaluru Jayanagar','NV-CLN-801','nasal_hfnc','NICU-A','2026-06-27',
     null,null,'not_applicable',null,null,true,'pass','pass',true,true,'pass','HFNC flow and humidifier verified'),
    ('Kokilaben Dhirubhai Ambani Mumbai','NV-KOK-901','hfov_oscillator','NICU-2','2026-06-26',
     null,null,'fail',null,null,false,'fail','fail',false,false,'removed_from_service','Multiple failures — oscillator diaphragm suspect, unit withdrawn'),
    ('Cloudnine Bengaluru Jayanagar','NV-CLN-802','ino_delivery_system','NICU-B','2026-06-26',
     null,0.70,'not_applicable',0.60,true,true,'pass','pass',true,true,'pass','iNO delivery and NO2 scavenging within spec')
  ) as q(hosp, dcode, dtype, nunit, cdate, tv_err, pd_err, osc, ino_err, no2, blender, alarm, leak, humid, calib, verdict, notes);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.neonatal_vent_capa_actions_r3306 (
    qc_log_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NV-FRT-201','ino_dose_deviation','ino_analyzer_miscalibration','recalibrate_ino_analyzer','escalated','cdsco_notifiable','2026-07-05',null,55000.00,'iNO analyzer 4.8 ppm high — escalated to OEM, unit off patient'),
    ('NV-FRT-202','pressure_delivery_error','pressure_transducer_drift','recalibrate_pressure_transducer','open','patient_safety_alert','2026-07-08',null,32000.00,'Pressure 5.4 cmH2O error — transducer recal scheduled'),
    ('NV-AIM-401','oscillation_amplitude_fault','oscillator_diaphragm_wear','replace_oscillator_diaphragm','in_progress','nabh_finding','2026-07-04',null,78000.00,'HFOV diaphragm kit on order from Draeger'),
    ('NV-KIM-601','alarm_battery_failure','battery_end_of_life','replace_battery','closed','internal_only','2026-07-02','2026-06-29',6500.00,'Battery replaced and load-tested — passed'),
    ('NV-KOK-901','oscillation_amplitude_fault','oscillator_diaphragm_wear','remove_from_service','escalated','iso_13485_deviation','2026-07-03',null,120000.00,'Unit withdrawn pending full OEM overhaul'),
    ('NV-MNP-302','humidifier_fault','humidifier_element_fault','replace_humidifier_element','verification_pending','internal_only','2026-07-05',null,9000.00,'HFNC humidifier element replaced — verify heat-up on next use'),
    ('NV-RBW-701','oxygen_blender_error','blender_valve_wear','replace_blender_valve','overdue','nabh_finding','2026-06-30',null,15000.00,'Blender FiO2 drift — past target date, AMC vendor delayed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neonatal_vent_r3306 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3306_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neonatal_vent_r3306)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neonatal_vent_r3306 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3306_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3306_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3306_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  leak_issues bigint,
  alarm_fail bigint,
  calibration_expired bigint,
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
    count(*) filter (where l.circuit_leak_test in ('minor_leak','fail'))::bigint,
    count(*) filter (where l.alarm_battery_test = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neonatal_vent_r3306 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3306_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3306_hospital_scorecard() to authenticated;

-- 3) Device-type × oscillation-amplitude matrix
create or replace function public.founder_r3306_device_type_matrix()
returns table(device_type text, oscillation_amplitude_ok text, checks bigint, passed bigint, avg_tidal_error_pct numeric, avg_pressure_error_cmh2o numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.oscillation_amplitude_ok, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.tidal_volume_accuracy_error_pct), 2),
    round(avg(l.pressure_delivery_error_cmh2o), 2)
  from public.neonatal_vent_r3306 l
  group by l.device_type, l.oscillation_amplitude_ok
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3306_device_type_matrix() from public, anon;
grant execute on function public.founder_r3306_device_type_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3306_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, leak_issues bigint, calibration_expired bigint)
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
    count(*) filter (where l.circuit_leak_test in ('minor_leak','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.neonatal_vent_r3306 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3306_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3306_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3306_capa_status_board()
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
  from public.neonatal_vent_capa_actions_r3306 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3306_capa_status_board() from public, anon;
grant execute on function public.founder_r3306_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3306_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neonatal_vent_capa_actions_r3306)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neonatal_vent_capa_actions_r3306 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3306_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3306_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3306_regulatory_impact_digest()
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
  from public.neonatal_vent_capa_actions_r3306 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3306_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3306_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3306_high_risk_queue()
returns table(
  hospital_name text,
  nicu_unit text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  oscillation_amplitude_ok text,
  alarm_battery_test text,
  circuit_leak_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.nicu_unit, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.oscillation_amplitude_ok, l.alarm_battery_test, l.circuit_leak_test,
    l.notes
  from public.neonatal_vent_r3306 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.oscillation_amplitude_ok in ('drift','fail')
     or l.alarm_battery_test = 'fail'
     or l.circuit_leak_test in ('minor_leak','fail')
     or l.calibration_current = false
     or l.no2_scavenging_ok = false
     or l.oxygen_blender_accuracy_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3306_high_risk_queue() from public, anon;
grant execute on function public.founder_r3306_high_risk_queue() to authenticated;
