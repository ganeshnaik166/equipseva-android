-- Round 3584: Engineer Remote-Diagnostic / IoT-Connected Device Uptime Tracker
-- Remote-diagnostic / IoT-connected medical-device uptime & telemetry-resolution tracker —
-- engineer × region × device model × month × devices-connected × uptime% × telemetry alerts ×
-- remote-resolution% × mean-resolution-hrs × truck-rolls-avoided × connectivity status × alert severity × CAPA

-- =============================================================================
-- TABLE 1: remote_diag_uptime_r3584 — per-engineer/device-model monthly telemetry & uptime rollup
-- =============================================================================
create table if not exists public.remote_diag_uptime_r3584 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  device_model text not null,
  device_serial text not null,
  period_month date not null,
  devices_connected int not null,
  uptime_pct numeric(5,2) not null,
  telemetry_alerts int not null,
  alerts_resolved_remote int not null,
  remote_resolution_pct numeric(5,2) not null,
  mean_resolution_hrs numeric(6,2) not null,
  truck_rolls_avoided int not null,
  connectivity_status text not null check (connectivity_status in (
    'healthy','degraded','intermittent','offline','not_connected'
  )),
  alert_severity text not null check (alert_severity in (
    'critical','major','minor','warning','info'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_diag_uptime_r3584 enable row level security;

create index if not exists idx_remote_diag_uptime_r3584_org on public.remote_diag_uptime_r3584(organization_id);
create index if not exists idx_remote_diag_uptime_r3584_month on public.remote_diag_uptime_r3584(period_month);
create index if not exists idx_remote_diag_uptime_r3584_conn on public.remote_diag_uptime_r3584(connectivity_status);

-- =============================================================================
-- TABLE 2: remote_diag_uptime_capa_actions_r3584 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.remote_diag_uptime_capa_actions_r3584 (
  id uuid primary key default gen_random_uuid(),
  uptime_log_id uuid not null references public.remote_diag_uptime_r3584(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'connectivity_loss','uptime_below_sla','telemetry_alert_storm','remote_resolution_failed',
    'sensor_offline','gateway_failure','firmware_out_of_date','data_gap',
    'high_mean_resolution_time','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'network_outage','sim_data_exhausted','gateway_hardware_fault','firmware_bug',
    'sensor_hardware_fault','power_interruption','cloud_platform_outage','configuration_error',
    'antenna_signal_weak','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'restart_gateway','replace_sim','replace_gateway','update_firmware','replace_sensor',
    'install_ups','reconfigure_device','improve_antenna_signal','dispatch_field_engineer',
    'escalate_to_oem','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  sla_impact text not null check (sla_impact in (
    'sla_breach','at_risk','none','internal_only','contractual_penalty','patient_safety_risk'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_diag_uptime_capa_actions_r3584 enable row level security;

create index if not exists idx_remote_diag_uptime_capa_r3584_log on public.remote_diag_uptime_capa_actions_r3584(uptime_log_id);
create index if not exists idx_remote_diag_uptime_capa_r3584_status on public.remote_diag_uptime_capa_actions_r3584(capa_status);

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

  -- 16 monthly uptime rows
  insert into public.remote_diag_uptime_r3584 (
    organization_id, engineer_name, region, device_model, device_serial, period_month,
    devices_connected, uptime_pct, telemetry_alerts, alerts_resolved_remote,
    remote_resolution_pct, mean_resolution_hrs, truck_rolls_avoided,
    connectivity_status, alert_severity, notes
  )
  select v_org_id, q.eng, q.rgn, q.model, q.serial, q.pmonth::date,
    q.dconn::int, q.upct::numeric, q.talerts::int, q.arem::int,
    q.rrpct::numeric, q.mrh::numeric, q.tra::int,
    q.cstat, q.sev, q.nt
  from (values
    ('Rajesh Kumar','South','Fresenius 4008S Dialysis','FRS-DLY-2201','2026-07-01',
     42,99.6,18,16,88.9,2.4,12,'healthy','info','Dialysis fleet telemetry stable, most alerts auto-resolved remotely'),
    ('Priya Nair','South','GE B650 Patient Monitor','GE-MON-3310','2026-07-01',
     65,99.2,30,27,90.0,1.8,20,'healthy','minor','Monitor bank healthy, high remote resolution rate'),
    ('Amit Sharma','West','Drager V500 Ventilator','DRG-VEN-1102','2026-07-01',
     28,97.4,22,14,63.6,4.1,6,'degraded','major','Ventilator gateway intermittent packet loss, several onsite visits'),
    ('Sunil Reddy','West','Philips MX550 Monitor','PHM-MON-4405','2026-07-01',
     51,98.8,25,21,84.0,2.9,14,'healthy','minor','Steady telemetry, firmware current'),
    ('Deepak Patel','North','BPL Infusion Pump','BPL-INF-5501','2026-07-01',
     80,95.1,40,22,55.0,5.2,8,'degraded','major','Infusion pump SIM data throttling causing telemetry gaps'),
    ('Kavya Iyer','North','Nihon Kohden BSM Monitor','NKD-MON-6602','2026-07-01',
     33,92.0,35,12,34.3,7.6,3,'intermittent','critical','Repeated dropouts, low remote resolution, dispatch backlog'),
    ('Vikram Singh','East','Mindray SV300 Ventilator','MDR-VEN-7703','2026-07-01',
     19,88.5,28,8,28.6,9.3,1,'offline','critical','Ventilators offline after gateway hardware fault, no telemetry'),
    ('Ananya Das','East','Siemens Somatom CT','SMN-CT-8801','2026-07-01',
     6,99.9,9,8,88.9,1.2,5,'healthy','info','CT remote monitoring stable, low alert volume'),
    ('Rajesh Kumar','South','Fresenius 4008S Dialysis','FRS-DLY-2202','2026-06-01',
     40,98.9,20,17,85.0,2.7,11,'healthy','minor','Prior-month baseline, healthy'),
    ('Amit Sharma','West','Drager V500 Ventilator','DRG-VEN-1103','2026-06-01',
     27,96.2,24,13,54.2,4.8,5,'degraded','major','Ongoing gateway instability trend on ventilator fleet'),
    ('Kavya Iyer','North','Nihon Kohden BSM Monitor','NKD-MON-6603','2026-06-01',
     31,90.5,33,10,30.3,8.1,2,'intermittent','critical','Chronic connectivity issues, escalated to network team'),
    ('Sunil Reddy','West','Philips MX550 Monitor','PHM-MON-4406','2026-06-01',
     49,97.9,23,19,82.6,3.1,12,'healthy','warning','Minor firmware warning cleared remotely'),
    ('Deepak Patel','North','BPL Infusion Pump','BPL-INF-5502','2026-06-01',
     78,93.7,44,20,45.5,6.0,6,'degraded','major','Persistent SIM throttling, batch replacement planned'),
    ('Vikram Singh','East','Mindray SV300 Ventilator','MDR-VEN-7704','2026-06-01',
     18,0.0,0,0,0.0,0.0,0,'not_connected','warning','Devices never provisioned to telemetry platform'),
    ('Priya Nair','South','GE B650 Patient Monitor','GE-MON-3311','2026-05-01',
     62,99.0,29,25,86.2,2.0,18,'healthy','info','Baseline healthy month'),
    ('Ananya Das','Central','Siemens Somatom CT','SMN-CT-8802','2026-05-01',
     5,94.0,12,5,41.7,6.5,2,'intermittent','major','CT link intermittent during cloud platform outage window')
  ) as q(eng, rgn, model, serial, pmonth, dconn, upct, talerts, arem, rrpct, mrh, tra, cstat, sev, nt);

  -- CAPA seed — attach to specific rows via device_serial
  insert into public.remote_diag_uptime_capa_actions_r3584 (
    uptime_log_id, finding_category, root_cause, corrective_action,
    capa_status, sla_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.own, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('DRG-VEN-1102','gateway_failure','gateway_hardware_fault','replace_gateway','in_progress','sla_breach','Amit Sharma','2026-07-20',null,18000.00,'Gateway replacement scheduled — intermittent loss on ventilator fleet'),
    ('MDR-VEN-7703','connectivity_loss','gateway_hardware_fault','replace_gateway','escalated','patient_safety_risk','Vikram Singh','2026-07-18',null,42000.00,'Ventilators offline — escalated to OEM, field dispatch en route'),
    ('NKD-MON-6602','remote_resolution_failed','antenna_signal_weak','improve_antenna_signal','open','at_risk','Kavya Iyer','2026-07-22',null,9500.00,'Weak signal driving low remote resolution — antenna relocation planned'),
    ('BPL-INF-5501','data_gap','sim_data_exhausted','replace_sim','verification_pending','contractual_penalty','Deepak Patel','2026-07-15',null,3200.00,'SIM data plan upgraded — verifying telemetry continuity'),
    ('NKD-MON-6603','uptime_below_sla','network_outage','dispatch_field_engineer','overdue','sla_breach','Kavya Iyer','2026-06-28',null,12000.00,'Chronic outages past target date — vendor SLA breach'),
    ('MDR-VEN-7704','sensor_offline','configuration_error','reconfigure_device','closed','internal_only','Vikram Singh','2026-06-20','2026-06-25',0.00,'Devices provisioned to telemetry platform and validated'),
    ('DRG-VEN-1103','high_mean_resolution_time','firmware_bug','update_firmware','closed','none','Amit Sharma','2026-06-22','2026-06-24',5000.00,'Firmware patch reduced mean resolution time — closed'),
    ('BPL-INF-5502','telemetry_alert_storm','sim_data_exhausted','replace_sim','in_progress','at_risk','Deepak Patel','2026-07-25',null,3500.00,'Alert storm from throttled SIMs — batch SIM replacement underway')
  ) as q(serial, fc, rc, ca, cst, si, own, tcd, acd, cost, nt)
  join public.remote_diag_uptime_r3584 e
    on e.organization_id = v_org_id and e.device_serial = q.serial;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Connectivity-status distribution
create or replace function public.founder_r3584_connectivity_status_rollup()
returns table(connectivity_status text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_diag_uptime_r3584)
  select l.connectivity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.remote_diag_uptime_r3584 l
  group by l.connectivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3584_connectivity_status_rollup() from public, anon;
grant execute on function public.founder_r3584_connectivity_status_rollup() to authenticated;

-- 2) Region scorecard
create or replace function public.founder_r3584_region_scorecard()
returns table(
  region text,
  records bigint,
  avg_uptime_pct numeric,
  avg_remote_resolution_pct numeric,
  total_devices_connected bigint,
  total_telemetry_alerts bigint,
  total_truck_rolls_avoided bigint,
  degraded_or_worse bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    round(avg(l.uptime_pct), 2),
    round(avg(l.remote_resolution_pct), 2),
    coalesce(sum(l.devices_connected),0)::bigint,
    coalesce(sum(l.telemetry_alerts),0)::bigint,
    coalesce(sum(l.truck_rolls_avoided),0)::bigint,
    count(*) filter (where l.connectivity_status in ('degraded','intermittent','offline','not_connected'))::bigint
  from public.remote_diag_uptime_r3584 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3584_region_scorecard() from public, anon;
grant execute on function public.founder_r3584_region_scorecard() to authenticated;

-- 3) Alert-severity × connectivity-status matrix
create or replace function public.founder_r3584_severity_connectivity_matrix()
returns table(alert_severity text, connectivity_status text, records bigint, avg_uptime_pct numeric, total_alerts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.alert_severity, l.connectivity_status, count(*)::bigint,
    round(avg(l.uptime_pct), 2),
    coalesce(sum(l.telemetry_alerts),0)::bigint
  from public.remote_diag_uptime_r3584 l
  group by l.alert_severity, l.connectivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3584_severity_connectivity_matrix() from public, anon;
grant execute on function public.founder_r3584_severity_connectivity_matrix() to authenticated;

-- 4) Monthly uptime trend
create or replace function public.founder_r3584_monthly_uptime_trend()
returns table(
  period_month date,
  records bigint,
  avg_uptime_pct numeric,
  avg_remote_resolution_pct numeric,
  total_alerts bigint,
  total_resolved_remote bigint,
  total_truck_rolls_avoided bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.uptime_pct), 2),
    round(avg(l.remote_resolution_pct), 2),
    coalesce(sum(l.telemetry_alerts),0)::bigint,
    coalesce(sum(l.alerts_resolved_remote),0)::bigint,
    coalesce(sum(l.truck_rolls_avoided),0)::bigint
  from public.remote_diag_uptime_r3584 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3584_monthly_uptime_trend() from public, anon;
grant execute on function public.founder_r3584_monthly_uptime_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3584_capa_status_board()
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
  from public.remote_diag_uptime_capa_actions_r3584 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3584_capa_status_board() from public, anon;
grant execute on function public.founder_r3584_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3584_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_diag_uptime_capa_actions_r3584)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.remote_diag_uptime_capa_actions_r3584 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3584_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3584_root_cause_pareto() to authenticated;

-- 7) Uptime-impact digest (by SLA impact)
create or replace function public.founder_r3584_uptime_impact_digest()
returns table(sla_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.sla_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.remote_diag_uptime_capa_actions_r3584 c
  group by c.sla_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3584_uptime_impact_digest() from public, anon;
grant execute on function public.founder_r3584_uptime_impact_digest() to authenticated;

-- 8) High-risk queue (offline / degraded / low-uptime)
create or replace function public.founder_r3584_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  device_model text,
  device_serial text,
  period_month date,
  connectivity_status text,
  alert_severity text,
  uptime_pct numeric,
  remote_resolution_pct numeric,
  mean_resolution_hrs numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.device_model, l.device_serial, l.period_month,
    l.connectivity_status, l.alert_severity, l.uptime_pct, l.remote_resolution_pct,
    l.mean_resolution_hrs, l.notes
  from public.remote_diag_uptime_r3584 l
  where l.connectivity_status in ('degraded','intermittent','offline','not_connected')
     or l.uptime_pct < 95.0
     or l.remote_resolution_pct < 60.0
     or l.alert_severity in ('critical','major')
  order by l.uptime_pct asc, l.mean_resolution_hrs desc;
end;
$$;

revoke execute on function public.founder_r3584_high_risk_queue() from public, anon;
grant execute on function public.founder_r3584_high_risk_queue() to authenticated;
