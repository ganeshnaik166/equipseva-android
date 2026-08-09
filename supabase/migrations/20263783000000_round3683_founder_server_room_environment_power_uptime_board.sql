-- Round 3683: Founder Server-Room Environment / Power / Uptime Board
-- Own server/network-room environment — temp × humidity × UPS runtime × power events × generator takeovers × cooling redundancy × thermal audit × CAPA

-- =============================================================================
-- TABLE 1: server_room_r3683 — per-room per-month environment / power log
-- =============================================================================
create table if not exists public.server_room_r3683 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  room_code text not null,
  room_name text not null,
  site_name text not null,
  period_month date not null,
  avg_temp_c numeric(5,2),
  max_temp_c numeric(5,2),
  avg_humidity_pct numeric(5,2),
  temp_excursions int not null default 0,
  ups_capacity_kva numeric(6,2),
  ups_runtime_min numeric(6,1),
  power_events int not null default 0,
  generator_takeovers int not null default 0,
  cooling_redundancy boolean not null,
  last_thermal_audit date,
  room_class text not null check (room_class in (
    'server_room','network_closet','ups_room','telecom_rack','edge_cabinet'
  )),
  environment_status text not null check (environment_status in (
    'healthy','watch','excursion_prone','power_risk','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.server_room_r3683 enable row level security;

create index if not exists idx_server_room_r3683_org on public.server_room_r3683(organization_id);
create index if not exists idx_server_room_r3683_month on public.server_room_r3683(period_month);
create index if not exists idx_server_room_r3683_status on public.server_room_r3683(environment_status);

-- =============================================================================
-- TABLE 2: server_room_capa_actions_r3683 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.server_room_capa_actions_r3683 (
  id uuid primary key default gen_random_uuid(),
  room_log_id uuid not null references public.server_room_r3683(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'hvac_unit_failure','ups_battery_aging','power_grid_instability',
    'cable_congestion_airflow','sensor_calibration_drift','generator_ats_fault',
    'door_seal_leak','overloaded_pdu','condensate_drain_blockage','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_hvac_unit','service_hvac_unit','replace_ups_batteries','add_redundant_cooling',
    'recable_and_clear_airflow','recalibrate_sensors','repair_generator_ats','install_door_seals',
    'rebalance_pdu_load','schedule_vendor_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.server_room_capa_actions_r3683 enable row level security;

create index if not exists idx_server_room_capa_r3683_log on public.server_room_capa_actions_r3683(room_log_id);
create index if not exists idx_server_room_capa_r3683_status on public.server_room_capa_actions_r3683(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Environment status distribution
create or replace function public.founder_r3683_environment_status_rollup()
returns table(environment_status text, rooms bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.server_room_r3683)
  select l.environment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.server_room_r3683 l
  group by l.environment_status
  order by count(*) desc;
end;
$$;

-- 2) Site-level environment scorecard
create or replace function public.founder_r3683_site_scorecard()
returns table(
  site_name text,
  rooms bigint,
  healthy bigint,
  watch bigint,
  excursion_prone bigint,
  power_risk bigint,
  critical bigint,
  total_excursions bigint,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.environment_status = 'healthy')::bigint,
    count(*) filter (where l.environment_status = 'watch')::bigint,
    count(*) filter (where l.environment_status = 'excursion_prone')::bigint,
    count(*) filter (where l.environment_status = 'power_risk')::bigint,
    count(*) filter (where l.environment_status = 'critical')::bigint,
    coalesce(sum(l.temp_excursions),0)::bigint,
    round(100.0 * count(*) filter (where l.environment_status = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.server_room_r3683 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 3) Room class × environment status matrix
create or replace function public.founder_r3683_room_class_status_matrix()
returns table(room_class text, environment_status text, rooms bigint, avg_temp_c numeric, total_excursions bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.room_class, l.environment_status, count(*)::bigint,
    round(avg(l.avg_temp_c), 2),
    coalesce(sum(l.temp_excursions),0)::bigint
  from public.server_room_r3683 l
  group by l.room_class, l.environment_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly excursion trend
create or replace function public.founder_r3683_monthly_excursion_trend()
returns table(
  period_month date,
  rooms bigint,
  total_excursions bigint,
  total_power_events bigint,
  total_generator_takeovers bigint,
  avg_max_temp_c numeric
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
    coalesce(sum(l.temp_excursions),0)::bigint,
    coalesce(sum(l.power_events),0)::bigint,
    coalesce(sum(l.generator_takeovers),0)::bigint,
    round(avg(l.max_temp_c), 2)
  from public.server_room_r3683 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3683_capa_status_board()
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
  from public.server_room_capa_actions_r3683 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3683_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.server_room_capa_actions_r3683)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.server_room_capa_actions_r3683 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Power-event digest by site
create or replace function public.founder_r3683_power_event_digest()
returns table(
  site_name text,
  rooms bigint,
  total_power_events bigint,
  total_generator_takeovers bigint,
  avg_ups_runtime_min numeric,
  total_ups_capacity_kva numeric,
  no_redundancy_rooms bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    coalesce(sum(l.power_events),0)::bigint,
    coalesce(sum(l.generator_takeovers),0)::bigint,
    round(avg(l.ups_runtime_min), 1),
    coalesce(sum(l.ups_capacity_kva),0)::numeric,
    count(*) filter (where l.cooling_redundancy = false)::bigint
  from public.server_room_r3683 l
  group by l.site_name
  order by coalesce(sum(l.power_events),0) desc;
end;
$$;

-- 8) High-risk room queue (critical / power_risk / weak runtime / no redundancy)
create or replace function public.founder_r3683_high_risk_queue()
returns table(
  room_code text,
  room_name text,
  site_name text,
  period_month date,
  room_class text,
  environment_status text,
  temp_excursions int,
  power_events int,
  ups_runtime_min numeric,
  cooling_redundancy boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.room_code, l.room_name, l.site_name, l.period_month, l.room_class,
    l.environment_status, l.temp_excursions, l.power_events, l.ups_runtime_min,
    l.cooling_redundancy, l.notes
  from public.server_room_r3683 l
  where l.environment_status in ('critical','power_risk')
     or l.temp_excursions >= 3
     or l.ups_runtime_min < 20
     or l.cooling_redundancy = false
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.site_name;
end;
$$;

-- =============================================================================
-- GRANTS — founder RPCs locked to authenticated
-- =============================================================================
revoke all on function public.founder_r3683_environment_status_rollup() from public, anon;
revoke all on function public.founder_r3683_site_scorecard() from public, anon;
revoke all on function public.founder_r3683_room_class_status_matrix() from public, anon;
revoke all on function public.founder_r3683_monthly_excursion_trend() from public, anon;
revoke all on function public.founder_r3683_capa_status_board() from public, anon;
revoke all on function public.founder_r3683_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3683_power_event_digest() from public, anon;
revoke all on function public.founder_r3683_high_risk_queue() from public, anon;

grant execute on function public.founder_r3683_environment_status_rollup() to authenticated;
grant execute on function public.founder_r3683_site_scorecard() to authenticated;
grant execute on function public.founder_r3683_room_class_status_matrix() to authenticated;
grant execute on function public.founder_r3683_monthly_excursion_trend() to authenticated;
grant execute on function public.founder_r3683_capa_status_board() to authenticated;
grant execute on function public.founder_r3683_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3683_power_event_digest() to authenticated;
grant execute on function public.founder_r3683_high_risk_queue() to authenticated;

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

  -- 16 room-month environment rows
  insert into public.server_room_r3683 (
    organization_id, room_code, room_name, site_name, period_month,
    avg_temp_c, max_temp_c, avg_humidity_pct, temp_excursions,
    ups_capacity_kva, ups_runtime_min, power_events, generator_takeovers,
    cooling_redundancy, last_thermal_audit, room_class, environment_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.rname, q.site, q.pmon::date,
    q.avgt, q.maxt, q.avgh, q.texc,
    q.upsk, q.upsr, q.pevt, q.gtk,
    q.coolr, q.lta::date, q.rclass, q.estat, q.tdir, q.nt
  from (values
    ('SR-MUM-01','Primary Server Room','Mumbai HQ','2026-07-01',
     22.4,24.1,48.5,0,40,45.0,1,0,true,'2026-06-20','server_room','healthy','stable','Primary DC room nominal; UPS load at 55 percent'),
    ('NC-MUM-02','Floor 3 Network Closet','Mumbai HQ','2026-07-01',
     26.8,31.5,58.2,4,3,22.0,2,0,false,'2026-05-11','network_closet','excursion_prone','worsening','Closet AC undersized; four excursions above 30C this month'),
    ('UPS-MUM-03','UPS & Battery Room','Mumbai HQ','2026-07-01',
     24.9,27.2,51.0,1,60,38.5,3,1,true,'2026-06-20','ups_room','watch','stable','Battery string 2 nearing end of life; runtime still adequate'),
    ('TR-MUM-04','Telecom Rack Mezzanine','Mumbai HQ','2026-06-01',
     25.2,28.0,55.4,2,2,18.0,1,0,false,null,'telecom_rack','watch','improving','Rack fan tray replaced mid-month; never thermally audited'),
    ('SR-MUM-05','DR Server Room Basement','Mumbai HQ','2026-05-01',
     24.1,29.8,60.3,3,40,30.0,4,2,true,'2026-02-14','server_room','excursion_prone','worsening','Basement condensate backup raised humidity; thermal audit overdue'),
    ('SR-CHN-01','Branch Server Room','Chennai Branch','2026-07-01',
     27.6,33.4,66.8,6,20,26.0,5,2,false,'2026-04-18','server_room','critical','worsening','Coastal humidity plus grid sags; six excursions and two genset takeovers'),
    ('NC-CHN-02','Ground Floor Network Closet','Chennai Branch','2026-07-01',
     26.1,29.3,61.5,2,3,20.5,3,1,false,'2026-05-30','network_closet','power_risk','stable','Raw-power feed on shared circuit; UPS runtime trending down'),
    ('EC-CHN-03','Service Bay Edge Cabinet','Chennai Branch','2026-06-01',
     28.9,34.2,63.0,5,1.5,12.0,4,1,false,null,'edge_cabinet','critical','worsening','Sealed cabinet cooling fan failed; thermal audit never done'),
    ('UPS-CHN-04','Branch UPS Room','Chennai Branch','2026-05-01',
     26.3,30.1,64.2,2,30,18.0,5,2,false,'2026-03-08','ups_room','power_risk','worsening','Runtime fell to 18 min under full load; battery bank aging'),
    ('SR-DEL-01','Warehouse Server Room','Delhi Warehouse','2026-07-01',
     23.8,26.5,42.1,1,30,41.0,2,1,true,'2026-06-05','server_room','watch','stable','Peak-summer loading; one excursion during afternoon grid outage'),
    ('NC-DEL-02','Dock Office Network Closet','Delhi Warehouse','2026-06-01',
     27.4,32.8,39.5,3,3,24.0,6,3,false,'2026-03-22','network_closet','power_risk','worsening','Six power events; DG set took over three times in June'),
    ('UPS-DEL-03','Warehouse UPS Room','Delhi Warehouse','2026-07-01',
     25.5,27.9,44.0,0,45,35.0,2,1,true,'2026-06-05','ups_room','watch','improving','New battery bank commissioned; runtime recovering month on month'),
    ('SR-BLR-01','Refurb Center Server Room','Bengaluru Refurb Center','2026-07-01',
     21.9,23.6,50.2,0,25,52.0,0,0,true,'2026-07-02','server_room','healthy','improving','Best-run room; redundant split units rotated weekly'),
    ('EC-BLR-02','Test Lab Edge Cabinet','Bengaluru Refurb Center','2026-06-01',
     24.6,27.8,53.7,1,1.5,15.5,1,0,false,'2026-06-10','edge_cabinet','watch','stable','Single excursion during refurb lab load test; low UPS runtime'),
    ('TR-BLR-03','Telecom Rack Annex','Bengaluru Refurb Center','2026-07-01',
     23.2,25.1,49.8,0,2,20.0,1,0,false,'2026-06-10','telecom_rack','healthy','stable','Rack ambient steady; PDU load balanced across phases'),
    ('NC-BLR-04','Refurb Floor Network Closet','Bengaluru Refurb Center','2026-05-01',
     25.7,28.4,52.0,1,3,28.0,2,0,false,'2026-04-25','network_closet','watch','stable','Minor excursion during HVAC filter change window')
  ) as q(rcode, rname, site, pmon, avgt, maxt, avgh, texc, upsk, upsr, pevt, gtk, coolr, lta, rclass, estat, tdir, nt);

  -- CAPA seed — attach to specific room logs via room_code
  insert into public.server_room_capa_actions_r3683 (
    room_log_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SR-CHN-01','hvac_unit_failure','add_redundant_cooling','escalated',185000.00,'Ravi Kulkarni','2026-08-20',null,'Second precision AC unit ordered; grid stabilizer scoped with vendor Bluestar'),
    ('EC-CHN-03','hvac_unit_failure','replace_hvac_unit','open',42000.00,'Ravi Kulkarni','2026-08-25',null,'Edge cabinet cooling fan module replacement awaiting parts from OEM'),
    ('NC-CHN-02','ups_battery_aging','replace_ups_batteries','in_progress',96000.00,'Meena Iyer','2026-08-18',null,'Battery bank swap 60 percent done; runtime retest pending'),
    ('NC-DEL-02','power_grid_instability','repair_generator_ats','verification_pending',54000.00,'Amit Sharma','2026-08-12',null,'ATS relay replaced by vendor Jakson; monitoring next three grid events'),
    ('SR-MUM-05','condensate_drain_blockage','service_hvac_unit','closed',18500.00,'Priya Nair','2026-07-30','2026-07-26','Drain line flushed and trap re-sloped; humidity back under 55 percent'),
    ('NC-MUM-02','cable_congestion_airflow','recable_and_clear_airflow','in_progress',22000.00,'Priya Nair','2026-08-15',null,'Patch-panel recabling half complete; blanking panels installed'),
    ('UPS-CHN-04','ups_battery_aging','replace_ups_batteries','overdue',110000.00,'Meena Iyer','2026-07-31',null,'Procurement delayed; revised quote from Exide vendor awaited'),
    ('SR-MUM-01','sensor_calibration_drift','recalibrate_sensors','closed',6500.00,'Amit Sharma','2026-07-20','2026-07-15','Temp and RH sensors recalibrated during quarterly PM visit')
  ) as q(rcode, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.server_room_r3683 e
    on e.organization_id = v_org_id and e.room_code = q.rcode;
end;
$seed$;
