-- Round 3552: Engineer Field-Connectivity / Remote-Access (VPN) Uptime Tracker
-- Field device connectivity / remote-access (VPN / teleservice link) uptime + session tracker —
-- engineer × hospital × device × link type × uptime % × sessions × latency × dropouts × connectivity status × remote-fix × CAPA

-- =============================================================================
-- TABLE 1: remote_access_vpn_r3552 — per-connection uptime & session log
-- =============================================================================
create table if not exists public.remote_access_vpn_r3552 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  connection_id text not null,
  link_type text not null check (link_type in (
    'vpn','cellular_gateway','wifi','ethernet','service_modem','cloud_agent'
  )),
  uptime_pct numeric(5,2) not null,
  sessions_count int not null,
  avg_latency_ms numeric(7,2) not null,
  dropouts int not null,
  last_seen date not null,
  connectivity_status text not null check (connectivity_status in (
    'online','intermittent','degraded','offline','blocked'
  )),
  remote_fix_enabled boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_access_vpn_r3552 enable row level security;

create index if not exists idx_remote_access_vpn_r3552_org on public.remote_access_vpn_r3552(organization_id);
create index if not exists idx_remote_access_vpn_r3552_seen on public.remote_access_vpn_r3552(last_seen);
create index if not exists idx_remote_access_vpn_r3552_status on public.remote_access_vpn_r3552(connectivity_status);

-- =============================================================================
-- TABLE 2: remote_access_vpn_capa_actions_r3552 — CAPA & service actions
-- =============================================================================
create table if not exists public.remote_access_vpn_capa_actions_r3552 (
  id uuid primary key default gen_random_uuid(),
  link_log_id uuid not null references public.remote_access_vpn_r3552(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'vpn_tunnel_down','high_latency','frequent_dropouts','link_offline','cellular_signal_weak',
    'firewall_block','certificate_expired','bandwidth_saturation','device_unreachable','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'isp_outage','router_firmware_bug','expired_vpn_certificate','firewall_policy_change','sim_data_exhausted',
    'weak_wifi_signal','cable_fault','power_outage_at_site','misconfigured_gateway','pending_investigation','oem_agent_crash'
  )),
  corrective_action text not null check (corrective_action in (
    'restart_gateway','renew_vpn_certificate','update_firewall_rules','replace_sim_plan','relocate_access_point',
    'replace_cable','failover_to_cellular','update_router_firmware','dispatch_field_engineer','escalate_to_isp','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  service_impact text not null check (service_impact in (
    'critical_downtime','patient_care_impact','none','internal_only','sla_breach','remote_support_blocked'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_access_vpn_capa_actions_r3552 enable row level security;

create index if not exists idx_remote_access_vpn_capa_r3552_log on public.remote_access_vpn_capa_actions_r3552(link_log_id);
create index if not exists idx_remote_access_vpn_capa_r3552_status on public.remote_access_vpn_capa_actions_r3552(capa_status);

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

  -- 16 connection uptime rows
  insert into public.remote_access_vpn_r3552 (
    organization_id, engineer_name, hospital_name, device_model, connection_id, link_type,
    uptime_pct, sessions_count, avg_latency_ms, dropouts, last_seen, connectivity_status,
    remote_fix_enabled, notes
  )
  select v_org_id, q.eng, q.hosp, q.dmodel, q.conn, q.ltype,
    q.uptime, q.sess, q.lat, q.drops, q.seen::date, q.cstat,
    q.rfix, q.nt
  from (values
    ('Ramesh Iyer','Apollo Chennai','GE CARESCAPE B650','VPN-APL-01','vpn',
     99.8,42,38.5,0,'2026-07-27','online',true,'Site-to-site VPN stable; teleservice sessions nominal'),
    ('Ramesh Iyer','Apollo Chennai','Philips IntelliVue MX800','CGW-APL-02','cellular_gateway',
     97.2,31,120.4,3,'2026-07-27','online',true,'4G cellular gateway backup link healthy'),
    ('Suresh Kumar','Fortis Gurgaon','Siemens MAGNETOM Aera','VPN-FRT-11','vpn',
     91.5,18,180.7,9,'2026-07-26','intermittent',true,'VPN tunnel flapping during peak load — latency high'),
    ('Suresh Kumar','Fortis Gurgaon','Drager Evita V500','SVC-FRT-12','service_modem',
     88.0,12,240.2,14,'2026-07-25','degraded',false,'Service modem dropping calls; remote fix not enabled'),
    ('Anita Desai','Manipal Bengaluru','Mindray BeneVision N22','CLD-MNP-21','cloud_agent',
     99.4,55,45.0,1,'2026-07-27','online',true,'Cloud agent connected; firmware auto-updates on'),
    ('Anita Desai','Manipal Bengaluru','GE Vivid E95','WIFI-MNP-22','wifi',
     94.6,27,95.3,6,'2026-07-26','intermittent',true,'Wi-Fi RSSI weak in cath lab — occasional drops'),
    ('Vijay Menon','AIIMS Delhi','Philips Azurion 7','ETH-AIM-31','ethernet',
     99.9,63,22.1,0,'2026-07-27','online',true,'Wired link rock solid; no dropouts this cycle'),
    ('Vijay Menon','AIIMS Delhi','Siemens Artis Zee','VPN-AIM-32','vpn',
     0.0,0,0.0,28,'2026-07-24','offline',false,'VPN certificate expired — link down four days'),
    ('Priya Nair','CMC Vellore','Nihon Kohden BSM-6000','CGW-CMC-41','cellular_gateway',
     96.1,22,138.9,5,'2026-07-26','online',true,'Cellular gateway steady on new SIM plan'),
    ('Priya Nair','CMC Vellore','Canon Aquilion Prime CT','SVC-CMC-42','service_modem',
     72.3,8,310.5,21,'2026-07-23','degraded',false,'Legacy service modem — high latency and drops, upgrade due'),
    ('Karthik Rao','KIMS Hyderabad','Boston Scientific Cath Lab','VPN-KIM-51','vpn',
     98.7,37,52.4,2,'2026-07-27','online',true,'VPN teleservice link healthy post firmware update'),
    ('Karthik Rao','KIMS Hyderabad','Medtronic Puritan Bennett 980','WIFI-KIM-52','wifi',
     0.0,0,0.0,0,'2026-07-22','blocked',false,'Hospital firewall blocking outbound VPN port — escalated to IT'),
    ('Deepa Shah','Yashoda Hyderabad','Fujifilm FDR Smart X','CLD-YSH-61','cloud_agent',
     99.1,48,60.8,1,'2026-07-27','online',true,'Cloud agent nominal; remote diagnostics enabled'),
    ('Deepa Shah','Yashoda Hyderabad','GE Optima CT660','CGW-YSH-62','cellular_gateway',
     85.4,15,205.0,17,'2026-07-25','intermittent',true,'SIM data cap nearly exhausted — throttled speeds'),
    ('Manoj Pillai','Kokilaben Mumbai','Philips EPIQ Elite','ETH-KKB-71','ethernet',
     99.6,58,28.7,0,'2026-07-27','online',true,'Ethernet link stable; scheduled PM only'),
    ('Manoj Pillai','Kokilaben Mumbai','Siemens Cios Alpha','VPN-KKB-72','vpn',
     63.9,6,420.3,33,'2026-07-21','offline',false,'Router firmware bug causing repeated tunnel collapse — offline')
  ) as q(eng, hosp, dmodel, conn, ltype, uptime, sess, lat, drops, seen, cstat, rfix, nt);

  -- CAPA seed — attach to specific connections via connection_id
  insert into public.remote_access_vpn_capa_actions_r3552 (
    link_log_id, finding_category, root_cause, corrective_action,
    capa_status, service_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('VPN-AIM-32','certificate_expired','expired_vpn_certificate','renew_vpn_certificate','in_progress','critical_downtime','2026-07-29',null,6500.00,'VPN cert renewal in progress — link down blocking remote support'),
    ('SVC-FRT-12','frequent_dropouts','misconfigured_gateway','restart_gateway','open','sla_breach','2026-07-30',null,3200.00,'Service modem reconfiguration scheduled; SLA at risk'),
    ('SVC-CMC-42','high_latency','router_firmware_bug','update_router_firmware','escalated','remote_support_blocked','2026-07-28',null,18000.00,'Legacy modem replacement escalated — remote diagnostics blocked'),
    ('WIFI-KIM-52','firewall_block','firewall_policy_change','update_firewall_rules','open','remote_support_blocked','2026-07-31',null,0.00,'Hospital IT to whitelist VPN port; awaiting change window'),
    ('VPN-KKB-72','vpn_tunnel_down','router_firmware_bug','update_router_firmware','escalated','critical_downtime','2026-07-29',null,22000.00,'Router firmware bug — OEM patch requested, field engineer dispatched'),
    ('CGW-YSH-62','cellular_signal_weak','sim_data_exhausted','replace_sim_plan','verification_pending','sla_breach','2026-07-27',null,4800.00,'Upgraded SIM data plan — verifying throughput'),
    ('WIFI-MNP-22','frequent_dropouts','weak_wifi_signal','relocate_access_point','closed','internal_only','2026-07-24','2026-07-22',9500.00,'Additional access point installed in cath lab — drops resolved'),
    ('VPN-FRT-11','high_latency','isp_outage','escalate_to_isp','overdue','sla_breach','2026-07-25',null,0.00,'ISP peering issue — escalation past target date, awaiting ISP')
  ) as q(conn, fc, rc, ca, cst, si, tcd, acd, cost, nt)
  join public.remote_access_vpn_r3552 e
    on e.organization_id = v_org_id and e.connection_id = q.conn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Connectivity status distribution
create or replace function public.founder_r3552_connectivity_status_rollup()
returns table(connectivity_status text, links bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_access_vpn_r3552)
  select l.connectivity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.remote_access_vpn_r3552 l
  group by l.connectivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3552_connectivity_status_rollup() from public, anon;
grant execute on function public.founder_r3552_connectivity_status_rollup() to authenticated;

-- 2) Link-type scorecard
create or replace function public.founder_r3552_link_type_scorecard()
returns table(
  link_type text,
  total_links bigint,
  online bigint,
  degraded bigint,
  offline bigint,
  remote_fix_ready bigint,
  avg_uptime_pct numeric,
  avg_latency_ms numeric,
  total_dropouts bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.link_type,
    count(*)::bigint,
    count(*) filter (where l.connectivity_status = 'online')::bigint,
    count(*) filter (where l.connectivity_status = 'degraded')::bigint,
    count(*) filter (where l.connectivity_status in ('offline','blocked'))::bigint,
    count(*) filter (where l.remote_fix_enabled = true)::bigint,
    round(avg(l.uptime_pct), 1),
    round(avg(l.avg_latency_ms), 1),
    coalesce(sum(l.dropouts), 0)::bigint
  from public.remote_access_vpn_r3552 l
  group by l.link_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3552_link_type_scorecard() from public, anon;
grant execute on function public.founder_r3552_link_type_scorecard() to authenticated;

-- 3) Link-type × connectivity-status matrix
create or replace function public.founder_r3552_link_type_status_matrix()
returns table(link_type text, connectivity_status text, links bigint, avg_uptime_pct numeric, total_dropouts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.link_type, l.connectivity_status, count(*)::bigint,
    round(avg(l.uptime_pct), 1),
    coalesce(sum(l.dropouts), 0)::bigint
  from public.remote_access_vpn_r3552 l
  group by l.link_type, l.connectivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3552_link_type_status_matrix() from public, anon;
grant execute on function public.founder_r3552_link_type_status_matrix() to authenticated;

-- 4) Monthly uptime trend
create or replace function public.founder_r3552_monthly_uptime_trend()
returns table(month_start date, links bigint, avg_uptime_pct numeric, avg_latency_ms numeric, total_dropouts bigint, offline_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.last_seen)::date,
    count(*)::bigint,
    round(avg(l.uptime_pct), 1),
    round(avg(l.avg_latency_ms), 1),
    coalesce(sum(l.dropouts), 0)::bigint,
    count(*) filter (where l.connectivity_status in ('offline','blocked'))::bigint
  from public.remote_access_vpn_r3552 l
  group by date_trunc('month', l.last_seen)
  order by date_trunc('month', l.last_seen) desc;
end;
$$;

revoke execute on function public.founder_r3552_monthly_uptime_trend() from public, anon;
grant execute on function public.founder_r3552_monthly_uptime_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3552_capa_status_board()
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
  from public.remote_access_vpn_capa_actions_r3552 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3552_capa_status_board() from public, anon;
grant execute on function public.founder_r3552_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3552_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_access_vpn_capa_actions_r3552)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.remote_access_vpn_capa_actions_r3552 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3552_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3552_root_cause_pareto() to authenticated;

-- 7) Downtime-impact digest
create or replace function public.founder_r3552_downtime_impact_digest()
returns table(service_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.service_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.remote_access_vpn_capa_actions_r3552 c
  group by c.service_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3552_downtime_impact_digest() from public, anon;
grant execute on function public.founder_r3552_downtime_impact_digest() to authenticated;

-- 8) High-risk connectivity queue
create or replace function public.founder_r3552_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  device_model text,
  connection_id text,
  link_type text,
  last_seen date,
  connectivity_status text,
  uptime_pct numeric,
  avg_latency_ms numeric,
  dropouts int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.device_model, l.connection_id, l.link_type,
    l.last_seen, l.connectivity_status, l.uptime_pct, l.avg_latency_ms, l.dropouts, l.notes
  from public.remote_access_vpn_r3552 l
  where l.connectivity_status in ('degraded','offline','blocked','intermittent')
     or l.uptime_pct < 95
     or l.dropouts > 5
     or l.remote_fix_enabled = false
  order by l.uptime_pct asc, l.dropouts desc, l.last_seen desc;
end;
$$;

revoke execute on function public.founder_r3552_high_risk_queue() from public, anon;
grant execute on function public.founder_r3552_high_risk_queue() to authenticated;
