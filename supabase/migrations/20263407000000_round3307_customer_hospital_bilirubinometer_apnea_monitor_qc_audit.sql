-- Round 3307: Customer Hospital Bilirubinometer & Apnea-Monitor Neonatal QC Audit
-- Neonatal screening/monitoring QA — device type × ward × calibration × bilirubin reading accuracy
-- × apnea alarm delay × alarm sensitivity × sensor/probe condition × lamp/optics × battery/false-alarm/hygiene × CAPA

-- =============================================================================
-- TABLE 1: neonatal_qc_r3307 — individual neonatal device QC checks
-- =============================================================================
create table if not exists public.neonatal_qc_r3307 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'transcutaneous_bilirubinometer','apnea_monitor_mattress','apnea_monitor_impedance',
    'neonatal_spo2_monitor','home_apnea_monitor'
  )),
  ward text not null,
  check_date date not null,
  calibration_check_ok boolean not null,
  bilirubin_reading_error_mgdl numeric(5,2),
  apnea_alarm_delay_seconds int,
  alarm_sensitivity_ok boolean not null,
  sensor_probe_condition text not null check (sensor_probe_condition in (
    'good','worn','cracked','replace_due'
  )),
  lamp_or_optics_ok text not null check (lamp_or_optics_ok in (
    'ok','degraded','not_applicable'
  )),
  battery_backup_ok boolean not null,
  false_alarm_rate_ok boolean not null,
  cleaning_hygiene_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neonatal_qc_r3307 enable row level security;

create index if not exists idx_neonatal_qc_r3307_org on public.neonatal_qc_r3307(organization_id);
create index if not exists idx_neonatal_qc_r3307_date on public.neonatal_qc_r3307(check_date);
create index if not exists idx_neonatal_qc_r3307_verdict on public.neonatal_qc_r3307(qc_verdict);

-- =============================================================================
-- TABLE 2: neonatal_qc_capa_actions_r3307 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neonatal_qc_capa_actions_r3307 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.neonatal_qc_r3307(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_drift','bilirubin_reading_error','apnea_alarm_delay','alarm_sensitivity_low',
    'sensor_probe_worn','optics_degraded','battery_backup_failure','false_alarm_high',
    'hygiene_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'optics_soiled','probe_aging','calibration_expired','sensor_membrane_wear','battery_end_of_life',
    'firmware_config_error','operator_setup_error','lamp_degradation','pending_investigation',
    'preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_device','replace_sensor_probe','clean_replace_optics','replace_battery',
    'update_alarm_config','replace_lamp_module','retrain_nursing_staff','remove_from_service',
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

alter table public.neonatal_qc_capa_actions_r3307 enable row level security;

create index if not exists idx_neonatal_capa_r3307_log on public.neonatal_qc_capa_actions_r3307(qc_log_id);
create index if not exists idx_neonatal_capa_r3307_status on public.neonatal_qc_capa_actions_r3307(capa_status);

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

  -- 14 neonatal device QC rows
  insert into public.neonatal_qc_r3307 (
    organization_id, hospital_name, device_code, device_type, ward, check_date,
    calibration_check_ok, bilirubin_reading_error_mgdl, apnea_alarm_delay_seconds,
    alarm_sensitivity_ok, sensor_probe_condition, lamp_or_optics_ok,
    battery_backup_ok, false_alarm_rate_ok, cleaning_hygiene_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.ward, q.cdt::date,
    q.calok, q.bilerr, q.apneadelay,
    q.alarmok, q.probe, q.optics,
    q.batt, q.falsealarm, q.hygiene, q.calcur,
    q.qv, q.nt
  from (values
    ('Apollo Chennai','BILI-APL-01','transcutaneous_bilirubinometer','NICU','2026-07-05',
     true,0.40,null,true,'good','ok',true,true,true,true,'pass','Quarterly TcB QC — reading within 0.5 mg/dL of reference'),
    ('Apollo Chennai','APN-APL-02','apnea_monitor_impedance','NICU','2026-07-05',
     true,null,12,true,'good','not_applicable',true,true,true,true,'pass','Impedance apnea monitor — 12s alarm delay within 20s spec'),
    ('Fortis Gurgaon','BILI-FRT-11','transcutaneous_bilirubinometer','SNCU','2026-07-04',
     true,2.60,null,true,'worn','degraded',true,true,true,true,'conditional_pass','Bilirubin reading 2.6 mg/dL vs lab — optics degraded, probe worn'),
    ('Fortis Gurgaon','APN-FRT-12','apnea_monitor_mattress','NICU','2026-07-04',
     true,null,25,false,'good','not_applicable',true,true,true,true,'fail','Apnea alarm delayed 25s beyond 20s limit and sensitivity low'),
    ('Manipal Bengaluru','SPO2-MNP-21','neonatal_spo2_monitor','NICU','2026-07-03',
     true,null,8,true,'replace_due','not_applicable',true,true,true,true,'conditional_pass','Neonatal SpO2 probe replace-due, alarm and cal nominal'),
    ('Manipal Bengaluru','APN-MNP-22','apnea_monitor_impedance','SNCU','2026-07-03',
     false,null,18,true,'good','not_applicable',false,true,true,false,'fail','Calibration expired and battery backup dead — removed for service'),
    ('AIIMS Delhi','BILI-AIM-31','transcutaneous_bilirubinometer','Nursery','2026-07-02',
     true,1.10,null,true,'good','ok',true,true,true,true,'pass','TcB reading within 1.1 mg/dL — routine pass'),
    ('AIIMS Delhi','APN-AIM-32','apnea_monitor_mattress','NICU','2026-07-02',
     true,null,14,true,'good','not_applicable',true,false,true,true,'conditional_pass','False-alarm rate high — 6 nuisance alarms per shift'),
    ('CMC Vellore','BILI-CMC-41','transcutaneous_bilirubinometer','SNCU','2026-07-01',
     true,4.20,null,true,'cracked','degraded',true,true,true,false,'removed_from_service','Reading 4.2 mg/dL error, cracked probe, calibration lapsed — removed'),
    ('CMC Vellore','SPO2-CMC-42','neonatal_spo2_monitor','Paediatric ICU','2026-07-01',
     true,null,10,true,'good','not_applicable',true,true,true,true,'pass','Neonatal SpO2 monitor — all parameters nominal'),
    ('KIMS Hyderabad','HAM-KIM-51','home_apnea_monitor','Postnatal Ward','2026-06-30',
     true,null,16,true,'good','not_applicable',true,true,false,true,'conditional_pass','Discharge home-monitor loaner — hygiene wipe-down overdue'),
    ('KIMS Hyderabad','APN-KIM-52','apnea_monitor_impedance','NICU','2026-06-30',
     true,null,11,true,'good','not_applicable',true,true,true,true,'pass','Impedance monitor 11s alarm delay — routine QC pass'),
    ('Rainbow Children''s Bengaluru','BILI-RBW-61','transcutaneous_bilirubinometer','NICU','2026-06-29',
     false,null,null,true,'good','degraded',true,true,true,false,'fail','Lamp degraded and self-test failed — reading not captured, service booked'),
    ('Cloudnine Bengaluru','APN-CLN-71','apnea_monitor_mattress','Nursery','2026-06-29',
     true,null,13,true,'worn','not_applicable',true,true,true,true,'pass','Mattress sensor worn but within spec — monitor next cycle')
  ) as q(hosp, dcode, dtype, ward, cdt, calok, bilerr, apneadelay, alarmok, probe, optics, batt, falsealarm, hygiene, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.neonatal_qc_capa_actions_r3307 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('APN-FRT-12','apnea_alarm_delay','firmware_config_error','update_alarm_config','in_progress','patient_safety_alert','2026-07-09',null,8000.00,'Alarm delay 25s — firmware alarm profile reflashed, verify on bench'),
    ('APN-MNP-22','calibration_drift','calibration_expired','recalibrate_device','open','nabh_finding','2026-07-10',null,12000.00,'Recalibration and battery replacement scheduled with biomed'),
    ('BILI-CMC-41','bilirubin_reading_error','sensor_membrane_wear','remove_from_service','escalated','cdsco_notifiable','2026-07-06',null,22000.00,'Reading 4.2 mg/dL error, cracked probe — removed, OEM service raised'),
    ('APN-AIM-32','false_alarm_high','firmware_config_error','update_alarm_config','verification_pending','internal_only','2026-07-05',null,3000.00,'Nuisance alarms — sensitivity threshold retuned, monitor next shift'),
    ('BILI-FRT-11','optics_degraded','optics_soiled','clean_replace_optics','closed','iso_13485_deviation','2026-07-07','2026-07-06',5500.00,'Optics cleaned, reference re-check within 1.0 mg/dL'),
    ('BILI-RBW-61','preventive_maintenance_due','lamp_degradation','replace_lamp_module','overdue','internal_only','2026-06-27',null,9000.00,'Lamp module past target date — AMC vendor delayed'),
    ('HAM-KIM-51','hygiene_failure','operator_setup_error','retrain_nursing_staff','closed','none','2026-07-02','2026-07-01',0.00,'Loaner cleaning SOP retrained, wipe-down log restored')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neonatal_qc_r3307 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3307_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neonatal_qc_r3307)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neonatal_qc_r3307 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3307_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3307_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3307_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  alarm_fail bigint,
  calibration_fail bigint,
  sensor_issue bigint,
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
    count(*) filter (where l.alarm_sensitivity_ok = false or l.false_alarm_rate_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false or l.calibration_check_ok = false)::bigint,
    count(*) filter (where l.sensor_probe_condition in ('worn','cracked','replace_due'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neonatal_qc_r3307 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3307_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3307_hospital_scorecard() to authenticated;

-- 3) Device type × ward matrix
create or replace function public.founder_r3307_device_ward_matrix()
returns table(device_type text, ward text, checks bigint, passed bigint, avg_bili_error_mgdl numeric, avg_apnea_delay_seconds numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.ward, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.bilirubin_reading_error_mgdl), 2),
    round(avg(l.apnea_alarm_delay_seconds), 1)
  from public.neonatal_qc_r3307 l
  group by l.device_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3307_device_ward_matrix() from public, anon;
grant execute on function public.founder_r3307_device_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3307_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, alarm_fail bigint, calibration_fail bigint)
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
    count(*) filter (where l.alarm_sensitivity_ok = false or l.false_alarm_rate_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false or l.calibration_check_ok = false)::bigint
  from public.neonatal_qc_r3307 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3307_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3307_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3307_capa_status_board()
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
  from public.neonatal_qc_capa_actions_r3307 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3307_capa_status_board() from public, anon;
grant execute on function public.founder_r3307_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3307_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neonatal_qc_capa_actions_r3307)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neonatal_qc_capa_actions_r3307 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3307_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3307_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3307_regulatory_impact_digest()
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
  from public.neonatal_qc_capa_actions_r3307 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3307_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3307_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (individual concerns)
create or replace function public.founder_r3307_high_risk_queue()
returns table(
  hospital_name text,
  ward text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  sensor_probe_condition text,
  lamp_or_optics_ok text,
  apnea_alarm_delay_seconds int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.sensor_probe_condition, l.lamp_or_optics_ok, l.apnea_alarm_delay_seconds, l.notes
  from public.neonatal_qc_r3307 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.alarm_sensitivity_ok = false
     or l.false_alarm_rate_ok = false
     or l.calibration_current = false
     or l.calibration_check_ok = false
     or l.battery_backup_ok = false
     or l.cleaning_hygiene_ok = false
     or l.sensor_probe_condition in ('cracked','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3307_high_risk_queue() from public, anon;
grant execute on function public.founder_r3307_high_risk_queue() to authenticated;
