-- Round 3480: Engineer Condition-Based / Predictive-Maintenance Sensor-Alert Tracker
-- CBM sensor-alerts — sensor type × anomaly severity × reading vs threshold × predicted-failure horizon × action taken × resolution × CAPA intervention closure

-- =============================================================================
-- TABLE 1: cbm_predictive_r3480 — per-alert condition-based monitoring readings
-- =============================================================================
create table if not exists public.cbm_predictive_r3480 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  alert_code text not null,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  asset_tag text not null,
  sensor_type text not null check (sensor_type in (
    'vibration','temperature','current','acoustic','pressure','runtime_hours','error_rate'
  )),
  reading_value numeric(12,2) not null,
  threshold_value numeric(12,2) not null,
  anomaly_severity text not null check (anomaly_severity in (
    'normal','watch','warning','critical'
  )),
  predicted_failure_days int,
  action_taken text not null check (action_taken in (
    'none','monitor','scheduled_pm','part_replaced','shutdown','false_alarm'
  )),
  alert_date date not null,
  resolved boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cbm_predictive_r3480 enable row level security;

create index if not exists idx_cbm_predictive_r3480_org on public.cbm_predictive_r3480(organization_id);
create index if not exists idx_cbm_predictive_r3480_date on public.cbm_predictive_r3480(alert_date);
create index if not exists idx_cbm_predictive_r3480_severity on public.cbm_predictive_r3480(anomaly_severity);

-- =============================================================================
-- TABLE 2: cbm_predictive_capa_actions_r3480 — CAPA & intervention actions
-- =============================================================================
create table if not exists public.cbm_predictive_capa_actions_r3480 (
  id uuid primary key default gen_random_uuid(),
  alert_log_id uuid not null references public.cbm_predictive_r3480(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'vibration_exceedance','thermal_rise','current_draw_anomaly','acoustic_signature_change',
    'pressure_deviation','runtime_threshold_reached','error_rate_spike','imminent_failure_predicted',
    'preventive_maintenance_due','sensor_calibration_drift'
  )),
  root_cause text not null check (root_cause in (
    'bearing_wear','motor_degradation','filter_clogging','lubrication_deficiency',
    'electrical_connection_loose','component_end_of_life','cooling_fan_failure',
    'firmware_fault','sensor_fault_false_alarm','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_bearing','replace_motor','replace_filter','lubricate_and_service',
    'tighten_connections','replace_component','replace_cooling_fan','firmware_update',
    'schedule_preventive_pm','recalibrate_sensor','monitor_only','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  downtime_avoided_hours numeric(8,2),
  estimated_savings_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cbm_predictive_capa_actions_r3480 enable row level security;

create index if not exists idx_cbm_predictive_capa_r3480_log on public.cbm_predictive_capa_actions_r3480(alert_log_id);
create index if not exists idx_cbm_predictive_capa_r3480_status on public.cbm_predictive_capa_actions_r3480(capa_status);

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

  -- 16 sensor-alert rows
  insert into public.cbm_predictive_r3480 (
    organization_id, alert_code, engineer_name, hospital_name, device_model, asset_tag,
    sensor_type, reading_value, threshold_value, anomaly_severity, predicted_failure_days,
    action_taken, alert_date, resolved, notes
  )
  select v_org_id, q.acode, q.eng, q.hosp, q.model, q.tag,
    q.stype, q.rv, q.tv, q.sev, q.pfd,
    q.act, q.adate::date, q.rez, q.nt
  from (values
    ('CBM-APL-0001','Ravi Kumar','Apollo Chennai','Drager Savina 300','VENT-APL-14','vibration',3.2,5.0,'normal',180,'none','2026-07-20',true,'Blower vibration baseline healthy'),
    ('CBM-APL-0002','Ravi Kumar','Apollo Chennai','GE Datex-Ohmeda S5','MON-APL-22','temperature',58.0,65.0,'watch',120,'monitor','2026-07-19',true,'PSU temperature trending up — under watch'),
    ('CBM-FRT-0003','Anita Sharma','Fortis Gurgaon','Philips IntelliVue MX550','MON-FRT-31','current',4.8,4.0,'warning',45,'scheduled_pm','2026-07-18',false,'Current draw above limit — PM scheduled'),
    ('CBM-FRT-0004','Anita Sharma','Fortis Gurgaon','Mindray SV800','VENT-FRT-33','vibration',7.9,5.0,'critical',12,'part_replaced','2026-07-17',false,'Blower bearing vibration critical — near failure'),
    ('CBM-MNP-0005','Suresh Nair','Manipal Bengaluru','Siemens Somatom','CT-MNP-05','temperature',72.0,70.0,'warning',30,'scheduled_pm','2026-07-16',false,'Gantry drive thermal rise above threshold'),
    ('CBM-MNP-0006','Suresh Nair','Manipal Bengaluru','Maquet Servo-i','VENT-MNP-08','acoustic',68.0,60.0,'warning',40,'monitor','2026-07-16',true,'Compressor acoustic signature shift — monitoring'),
    ('CBM-AIM-0007','Deepa Menon','AIIMS Delhi','GE Voluson E10','USG-AIM-17','runtime_hours',9800.0,10000.0,'watch',60,'scheduled_pm','2026-07-15',false,'Probe runtime approaching PM interval'),
    ('CBM-AIM-0008','Deepa Menon','AIIMS Delhi','Trumpf TruLight','OT-AIM-19','error_rate',6.5,3.0,'critical',8,'shutdown','2026-07-15',false,'LED driver error-rate spike — unit shut down'),
    ('CBM-CMC-0009','Rajesh Iyer','CMC Vellore','Hamilton C6','VENT-CMC-24','pressure',2.1,2.0,'watch',90,'monitor','2026-07-14',true,'Inspiratory pressure deviation minor — watch'),
    ('CBM-CMC-0010','Rajesh Iyer','CMC Vellore','Philips Azurion','CATH-CMC-26','current',5.6,4.0,'critical',15,'part_replaced','2026-07-13',false,'C-arm motor current critical — motor replaced'),
    ('CBM-KIM-0011','Priya Reddy','KIMS Hyderabad','Fresenius 4008S','DIAL-KIM-12','temperature',44.0,42.0,'warning',35,'scheduled_pm','2026-07-12',false,'Dialysate heater thermal drift — PM due'),
    ('CBM-KIM-0012','Priya Reddy','KIMS Hyderabad','Mindray BeneVision','MON-KIM-15','vibration',2.4,5.0,'normal',200,'none','2026-07-12',true,'Fan vibration nominal — healthy'),
    ('CBM-YSH-0013','Karthik Rao','Yashoda Hyderabad','Getinge Flow-C','VENT-YSH-21','error_rate',1.2,3.0,'normal',150,'false_alarm','2026-07-11',true,'Transient error flag — false alarm confirmed'),
    ('CBM-YSH-0014','Karthik Rao','Yashoda Hyderabad','Siemens Artis','CATH-YSH-23','acoustic',74.0,60.0,'critical',10,'part_replaced','2026-07-10',false,'Cooling fan acoustic critical — fan replaced'),
    ('CBM-KKB-0015','Meena Joshi','Kokilaben Mumbai','Roche Cobas 6000','LAB-KKB-30','runtime_hours',11200.0,10000.0,'warning',20,'scheduled_pm','2026-07-09',false,'Pump runtime past interval — PM overdue'),
    ('CBM-KKB-0016','Meena Joshi','Kokilaben Mumbai','Stryker System 8','OT-KKB-34','current',3.1,4.0,'normal',170,'monitor','2026-07-08',true,'Handpiece current normal — routine watch')
  ) as q(acode, eng, hosp, model, tag, stype, rv, tv, sev, pfd, act, adate, rez, nt);

  -- CAPA seed — attach to specific alerts via alert_code
  insert into public.cbm_predictive_capa_actions_r3480 (
    alert_log_id, finding_category, root_cause, corrective_action,
    capa_status, downtime_avoided_hours, estimated_savings_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.dah, q.sav, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('CBM-FRT-0003','current_draw_anomaly','electrical_connection_loose','tighten_connections','in_progress',24.0,45000.00,'Anita Sharma','2026-07-24',null,'Loose terminal suspected — retorque and recheck current'),
    ('CBM-FRT-0004','vibration_exceedance','bearing_wear','replace_bearing','closed',72.0,180000.00,'Anita Sharma','2026-07-20','2026-07-18','Blower bearing replaced — vibration back to baseline'),
    ('CBM-MNP-0005','thermal_rise','cooling_fan_failure','replace_cooling_fan','open',48.0,90000.00,'Suresh Nair','2026-07-22',null,'Gantry cooling fan degraded — replacement ordered'),
    ('CBM-AIM-0008','error_rate_spike','component_end_of_life','replace_component','escalated',36.0,120000.00,'Deepa Menon','2026-07-19',null,'LED driver end of life — escalated to OEM'),
    ('CBM-CMC-0010','current_draw_anomaly','motor_degradation','replace_motor','closed',60.0,150000.00,'Rajesh Iyer','2026-07-16','2026-07-14','C-arm motor replaced — current normalized'),
    ('CBM-KIM-0011','thermal_rise','component_end_of_life','schedule_preventive_pm','verification_pending',30.0,60000.00,'Priya Reddy','2026-07-18',null,'Heater element PM done — verify next dialysis run'),
    ('CBM-YSH-0014','acoustic_signature_change','cooling_fan_failure','replace_cooling_fan','closed',40.0,75000.00,'Karthik Rao','2026-07-13','2026-07-11','Cooling fan replaced — acoustic signature normal'),
    ('CBM-KKB-0015','runtime_threshold_reached','component_end_of_life','schedule_preventive_pm','overdue',18.0,50000.00,'Meena Joshi','2026-07-13',null,'Pump PM past target date — vendor scheduling delay')
  ) as q(acode, fc, rc, ca, cst, dah, sav, own, tcd, acd, nt)
  join public.cbm_predictive_r3480 e
    on e.organization_id = v_org_id and e.alert_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Anomaly severity distribution
create or replace function public.founder_r3480_anomaly_severity_rollup()
returns table(anomaly_severity text, alerts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cbm_predictive_r3480)
  select l.anomaly_severity, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cbm_predictive_r3480 l
  group by l.anomaly_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3480_anomaly_severity_rollup() from public, anon;
grant execute on function public.founder_r3480_anomaly_severity_rollup() to authenticated;

-- 2) Sensor-type scorecard
create or replace function public.founder_r3480_sensor_type_scorecard()
returns table(
  sensor_type text,
  total_alerts bigint,
  critical bigint,
  warning bigint,
  watch bigint,
  unresolved bigint,
  false_alarms bigint,
  avg_predicted_failure_days numeric,
  critical_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.sensor_type,
    count(*)::bigint,
    count(*) filter (where l.anomaly_severity = 'critical')::bigint,
    count(*) filter (where l.anomaly_severity = 'warning')::bigint,
    count(*) filter (where l.anomaly_severity = 'watch')::bigint,
    count(*) filter (where l.resolved = false)::bigint,
    count(*) filter (where l.action_taken = 'false_alarm')::bigint,
    round(avg(l.predicted_failure_days), 1),
    round(100.0 * count(*) filter (where l.anomaly_severity = 'critical')::numeric / nullif(count(*),0), 1)
  from public.cbm_predictive_r3480 l
  group by l.sensor_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3480_sensor_type_scorecard() from public, anon;
grant execute on function public.founder_r3480_sensor_type_scorecard() to authenticated;

-- 3) Sensor-type × severity matrix
create or replace function public.founder_r3480_sensor_severity_matrix()
returns table(
  sensor_type text,
  anomaly_severity text,
  alerts bigint,
  resolved_count bigint,
  unresolved bigint,
  avg_predicted_failure_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.sensor_type, l.anomaly_severity, count(*)::bigint,
    count(*) filter (where l.resolved = true)::bigint,
    count(*) filter (where l.resolved = false)::bigint,
    round(avg(l.predicted_failure_days), 1)
  from public.cbm_predictive_r3480 l
  group by l.sensor_type, l.anomaly_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3480_sensor_severity_matrix() from public, anon;
grant execute on function public.founder_r3480_sensor_severity_matrix() to authenticated;

-- 4) Monthly alert trend
create or replace function public.founder_r3480_monthly_alert_trend()
returns table(
  alert_month text,
  alerts bigint,
  critical bigint,
  warning bigint,
  unresolved bigint,
  parts_replaced bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.alert_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.anomaly_severity = 'critical')::bigint,
    count(*) filter (where l.anomaly_severity = 'warning')::bigint,
    count(*) filter (where l.resolved = false)::bigint,
    count(*) filter (where l.action_taken = 'part_replaced')::bigint
  from public.cbm_predictive_r3480 l
  group by to_char(l.alert_date, 'YYYY-MM')
  order by to_char(l.alert_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3480_monthly_alert_trend() from public, anon;
grant execute on function public.founder_r3480_monthly_alert_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3480_capa_status_board()
returns table(capa_status text, findings bigint, avg_downtime_avoided_hours numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.downtime_avoided_hours)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cbm_predictive_capa_actions_r3480 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3480_capa_status_board() from public, anon;
grant execute on function public.founder_r3480_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3480_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_downtime_avoided_hours numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cbm_predictive_capa_actions_r3480)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.downtime_avoided_hours),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cbm_predictive_capa_actions_r3480 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3480_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3480_root_cause_pareto() to authenticated;

-- 7) Downtime-avoidance impact digest (by corrective action)
create or replace function public.founder_r3480_downtime_avoidance_digest()
returns table(
  corrective_action text,
  findings bigint,
  total_downtime_avoided_hours numeric,
  total_savings_rupees numeric,
  closed_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.corrective_action, count(*)::bigint,
    coalesce(sum(c.downtime_avoided_hours),0)::numeric,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric,
    count(*) filter (where c.capa_status = 'closed')::bigint
  from public.cbm_predictive_capa_actions_r3480 c
  group by c.corrective_action
  order by coalesce(sum(c.downtime_avoided_hours),0) desc;
end;
$$;

revoke execute on function public.founder_r3480_downtime_avoidance_digest() from public, anon;
grant execute on function public.founder_r3480_downtime_avoidance_digest() to authenticated;

-- 8) High-risk queue (critical / near-failure / unresolved)
create or replace function public.founder_r3480_high_risk_queue()
returns table(
  hospital_name text,
  asset_tag text,
  device_model text,
  sensor_type text,
  alert_date date,
  anomaly_severity text,
  reading_value numeric,
  threshold_value numeric,
  predicted_failure_days int,
  action_taken text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.asset_tag, l.device_model, l.sensor_type, l.alert_date,
    l.anomaly_severity, l.reading_value, l.threshold_value, l.predicted_failure_days,
    l.action_taken, l.notes
  from public.cbm_predictive_r3480 l
  where l.anomaly_severity in ('warning','critical')
     or l.resolved = false
     or l.predicted_failure_days <= 30
     or l.action_taken = 'shutdown'
  order by l.predicted_failure_days asc nulls last, l.alert_date desc;
end;
$$;

revoke execute on function public.founder_r3480_high_risk_queue() from public, anon;
grant execute on function public.founder_r3480_high_risk_queue() to authenticated;
