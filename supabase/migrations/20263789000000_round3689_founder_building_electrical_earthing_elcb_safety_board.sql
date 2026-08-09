-- Round 3689: Founder Building Electrical / Earthing / ELCB Safety Board
-- Own-building electrical installation safety — earthing-pit resistance × ELCB/RCCB trip tests × LT-panel thermography × load imbalance × install zone × status × trend × CAPA

-- =============================================================================
-- TABLE 1: building_electrical_r3689 — per-panel-zone building electrical safety checks
-- =============================================================================
create table if not exists public.building_electrical_r3689 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  site_name text not null,
  panel_zone text not null,
  period_month date not null,
  earthing_pits int not null,
  pits_tested int not null,
  max_earth_resistance_ohm numeric(6,2),
  resistance_limit_ohm numeric(6,2),
  elcb_count int not null,
  elcb_tested int not null,
  elcb_trip_pass_pct numeric(5,1),
  thermography_hotspots int not null,
  load_imbalance_pct numeric(5,1),
  last_audit_date date,
  install_zone text not null check (install_zone in (
    'lt_panel','ups_circuit','warehouse_lighting','office_floor','external_perimeter'
  )),
  electrical_status text not null check (electrical_status in (
    'safe','test_due','resistance_high','trip_failures','hazardous'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.building_electrical_r3689 enable row level security;

create index if not exists idx_building_electrical_r3689_org on public.building_electrical_r3689(organization_id);
create index if not exists idx_building_electrical_r3689_month on public.building_electrical_r3689(period_month);
create index if not exists idx_building_electrical_r3689_status on public.building_electrical_r3689(electrical_status);

-- =============================================================================
-- TABLE 2: building_electrical_capa_actions_r3689 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.building_electrical_capa_actions_r3689 (
  id uuid primary key default gen_random_uuid(),
  electrical_id uuid not null references public.building_electrical_r3689(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'earth_pit_dried_out','corroded_earth_strip','elcb_mechanism_worn','loose_termination',
    'overloaded_phase','aging_wiring','moisture_ingress','vendor_test_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recharge_earth_pit','replace_earth_strip','replace_elcb','retorque_terminations',
    'rebalance_phase_loads','rewire_circuit','seal_moisture_entry','expedite_vendor_test','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.building_electrical_capa_actions_r3689 enable row level security;

create index if not exists idx_building_electrical_capa_r3689_log on public.building_electrical_capa_actions_r3689(electrical_id);
create index if not exists idx_building_electrical_capa_r3689_status on public.building_electrical_capa_actions_r3689(capa_status);

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

  -- 15 panel-zone electrical safety rows
  insert into public.building_electrical_r3689 (
    organization_id, site_name, panel_zone, period_month,
    earthing_pits, pits_tested, max_earth_resistance_ohm, resistance_limit_ohm,
    elcb_count, elcb_tested, elcb_trip_pass_pct, thermography_hotspots,
    load_imbalance_pct, last_audit_date, install_zone, electrical_status, trend_dir, notes
  )
  select v_org_id, q.site, q.pz, q.pm::date,
    q.pits, q.ptest, q.maxr, q.rlim,
    q.elcb, q.etest, q.tpass, q.hot,
    q.imb, q.lad::date, q.iz, q.st, q.trd, q.nt
  from (values
    ('Delhi HQ Warehouse','DEL-LT-01','2026-07-01',
     6,6,1.4,2.0,12,12,100.0,0,4.2,'2026-07-04','lt_panel','safe','stable',
     'All six earth pits under 2 ohm; every ELCB tripped within 30 ms at 30 mA'),
    ('Delhi HQ Warehouse','DEL-UPS-02','2026-07-01',
     2,2,1.1,1.0,8,8,100.0,0,3.5,'2026-07-04','ups_circuit','resistance_high','worsening',
     'UPS clean-earth pit reads 1.1 ohm against 1.0 ohm limit — salt-charcoal recharge raised'),
    ('Delhi HQ Warehouse','DEL-OFF-03','2026-07-01',
     2,2,0.9,2.0,10,9,88.9,1,6.8,'2026-07-05','office_floor','trip_failures','worsening',
     'One office-floor RCCB failed to trip at 30 mA push-button test — replacement ordered'),
    ('Delhi HQ Warehouse','DEL-EXT-04','2026-07-01',
     3,3,3.8,2.0,4,4,75.0,2,11.5,'2026-07-05','external_perimeter','hazardous','worsening',
     'Feeder pillar moisture ingress plus 3.8 ohm earth — circuit isolated pending rework'),
    ('Mumbai Bhiwandi Warehouse','BHW-LT-01','2026-07-01',
     8,8,1.8,2.0,14,14,100.0,2,9.4,'2026-07-06','lt_panel','safe','improving',
     'Two bus-bar joint hotspots retorqued during audit; repeat thermography clean'),
    ('Mumbai Bhiwandi Warehouse','BHW-WHL-02','2026-07-01',
     4,2,1.6,2.0,16,10,100.0,0,7.1,'2026-05-22','warehouse_lighting','test_due','stable',
     'Six lighting-circuit ELCBs untested past quarterly window — AMC vendor slot awaited'),
    ('Chennai Ambattur Warehouse','CHN-LT-01','2026-06-01',
     6,6,1.2,2.0,12,12,100.0,0,5.0,'2026-06-18','lt_panel','safe','stable',
     'LT panel thermography clean; all earthing pits within limit'),
    ('Chennai Ambattur Warehouse','CHN-UPS-02','2026-06-01',
     2,2,0.7,1.0,6,6,100.0,0,2.8,'2026-06-18','ups_circuit','safe','improving',
     'UPS clean earth improved to 0.7 ohm after pit recharge last quarter'),
    ('Chennai Ambattur Warehouse','CHN-WHL-03','2026-06-01',
     4,4,2.6,2.0,14,14,92.9,1,8.3,'2026-06-19','warehouse_lighting','resistance_high','stable',
     'High-bay lighting earth grid at 2.6 ohm — pit dried out in summer, recharge planned'),
    ('Pune Service Center','PUN-LT-01','2026-06-01',
     4,3,1.5,2.0,8,6,100.0,0,5.6,'2026-04-25','lt_panel','test_due','stable',
     'One pit and two ELCBs pending test — audit slipped past 60-day window'),
    ('Pune Service Center','PUN-OFF-02','2026-06-01',
     2,2,1.0,2.0,9,9,100.0,0,4.9,'2026-06-20','office_floor','safe','stable',
     'Office floor RCCBs all tripping within spec; loads balanced across phases'),
    ('Hyderabad Service Hub','HYD-LT-01','2026-05-01',
     4,4,1.7,2.0,10,10,80.0,3,13.2,'2026-05-15','lt_panel','trip_failures','worsening',
     'Two ELCBs stuck on trip test plus three thermography hotspots on outgoing feeders'),
    ('Hyderabad Service Hub','HYD-EXT-02','2026-05-01',
     2,1,1.9,2.0,3,2,100.0,0,6.4,'2026-05-15','external_perimeter','test_due','stable',
     'One perimeter pit inaccessible during audit — retest scheduled with excavation'),
    ('Mumbai Bhiwandi Warehouse','BHW-EXT-03','2026-05-01',
     3,3,4.6,2.0,4,4,100.0,1,10.8,'2026-05-20','external_perimeter','hazardous','worsening',
     'Perimeter earth strip corroded through; 4.6 ohm reading — strip replacement escalated'),
    ('Mumbai Bhiwandi Warehouse','BHW-UPS-04','2026-05-01',
     2,2,0.8,1.0,6,6,100.0,0,3.1,'2026-05-21','ups_circuit','safe','improving',
     'UPS circuit earth at 0.8 ohm and all ELCBs passing after last-quarter CAPA')
  ) as q(site, pz, pm, pits, ptest, maxr, rlim, elcb, etest, tpass, hot, imb, lad, iz, st, trd, nt);

  -- 8 CAPA rows — attach via panel_zone business key
  insert into public.building_electrical_capa_actions_r3689 (
    electrical_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DEL-UPS-02','earth_pit_dried_out','recharge_earth_pit','in_progress',
     18000.00,'Facilities — R. Sharma','2026-07-15',null,
     'Salt-charcoal recharge of UPS clean-earth pit under way; retest after 48 h soak'),
    ('DEL-OFF-03','elcb_mechanism_worn','replace_elcb','open',
     6500.00,'Electrical AMC — Sterling & Wilson','2026-07-12',null,
     '40 A 30 mA RCCB replacement indented for office floor DB'),
    ('DEL-EXT-04','moisture_ingress','seal_moisture_entry','escalated',
     27500.00,'Facilities — R. Sharma','2026-07-09',null,
     'Feeder pillar gasket and gland sealing — circuit stays isolated until IR test passes'),
    ('BHW-LT-01','loose_termination','retorque_terminations','closed',
     4800.00,'Electrical AMC — Suvidha Engineers','2026-07-08','2026-07-06',
     'Bus-bar joints retorqued to spec; repeat thermography shows no hotspot'),
    ('BHW-EXT-03','corroded_earth_strip','replace_earth_strip','escalated',
     42000.00,'Facilities — Bhiwandi site lead','2026-07-10',null,
     'GI earth strip run of 40 m to be replaced with copper-bonded strip'),
    ('BHW-WHL-02','vendor_test_backlog','expedite_vendor_test','open',
     0.00,'Electrical AMC — Suvidha Engineers','2026-07-20',null,
     'AMC vendor slot pulled forward to clear six untested lighting ELCBs'),
    ('CHN-WHL-03','earth_pit_dried_out','recharge_earth_pit','verification_pending',
     15000.00,'Facilities — Chennai','2026-07-18',null,
     'Pit recharged; awaiting post-monsoon-onset resistance verification reading'),
    ('HYD-LT-01','elcb_mechanism_worn','replace_elcb','overdue',
     13000.00,'Electrical AMC — Medha Electricals','2026-06-28',null,
     'Two stuck ELCBs on LT panel past target date — vendor spares delay')
  ) as q(pz, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.building_electrical_r3689 e
    on e.organization_id = v_org_id and e.panel_zone = q.pz;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Electrical status distribution
create or replace function public.founder_r3689_electrical_status_rollup()
returns table(electrical_status text, panels bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.building_electrical_r3689)
  select l.electrical_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.building_electrical_r3689 l
  group by l.electrical_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3689_electrical_status_rollup() from public, anon;
grant execute on function public.founder_r3689_electrical_status_rollup() to authenticated;

-- 2) Site-level electrical safety scorecard
create or replace function public.founder_r3689_site_scorecard()
returns table(
  site_name text,
  panels bigint,
  safe_panels bigint,
  test_due_panels bigint,
  resistance_issues bigint,
  trip_failure_panels bigint,
  hazardous_panels bigint,
  total_hotspots bigint,
  avg_trip_pass_pct numeric,
  safe_pct numeric
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
    count(*) filter (where l.electrical_status = 'safe')::bigint,
    count(*) filter (where l.electrical_status = 'test_due')::bigint,
    count(*) filter (where l.electrical_status = 'resistance_high')::bigint,
    count(*) filter (where l.electrical_status = 'trip_failures')::bigint,
    count(*) filter (where l.electrical_status = 'hazardous')::bigint,
    coalesce(sum(l.thermography_hotspots),0)::bigint,
    round(avg(l.elcb_trip_pass_pct), 1),
    round(100.0 * count(*) filter (where l.electrical_status = 'safe')::numeric / nullif(count(*),0), 1)
  from public.building_electrical_r3689 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3689_site_scorecard() from public, anon;
grant execute on function public.founder_r3689_site_scorecard() to authenticated;

-- 3) Install zone × electrical status matrix
create or replace function public.founder_r3689_zone_status_matrix()
returns table(install_zone text, electrical_status text, panels bigint, avg_max_resistance_ohm numeric, hotspots bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.install_zone, l.electrical_status, count(*)::bigint,
    round(avg(l.max_earth_resistance_ohm), 2),
    coalesce(sum(l.thermography_hotspots),0)::bigint
  from public.building_electrical_r3689 l
  group by l.install_zone, l.electrical_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3689_zone_status_matrix() from public, anon;
grant execute on function public.founder_r3689_zone_status_matrix() to authenticated;

-- 4) Monthly test trend
create or replace function public.founder_r3689_monthly_test_trend()
returns table(period_month date, panels bigint, pits_tested bigint, elcb_tested bigint, avg_trip_pass_pct numeric, hotspots bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.pits_tested),0)::bigint,
    coalesce(sum(l.elcb_tested),0)::bigint,
    round(avg(l.elcb_trip_pass_pct), 1),
    coalesce(sum(l.thermography_hotspots),0)::bigint
  from public.building_electrical_r3689 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3689_monthly_test_trend() from public, anon;
grant execute on function public.founder_r3689_monthly_test_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3689_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.building_electrical_capa_actions_r3689 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3689_capa_status_board() from public, anon;
grant execute on function public.founder_r3689_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3689_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.building_electrical_capa_actions_r3689)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.building_electrical_capa_actions_r3689 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3689_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3689_root_cause_pareto() to authenticated;

-- 7) Hotspot & earth-resistance digest by install zone
create or replace function public.founder_r3689_hotspot_resistance_digest()
returns table(
  install_zone text,
  panels bigint,
  total_hotspots bigint,
  over_resistance_limit bigint,
  avg_max_resistance_ohm numeric,
  avg_load_imbalance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.install_zone,
    count(*)::bigint,
    coalesce(sum(l.thermography_hotspots),0)::bigint,
    count(*) filter (where l.max_earth_resistance_ohm > l.resistance_limit_ohm)::bigint,
    round(avg(l.max_earth_resistance_ohm), 2),
    round(avg(l.load_imbalance_pct), 1)
  from public.building_electrical_r3689 l
  group by l.install_zone
  order by coalesce(sum(l.thermography_hotspots),0) desc;
end;
$$;

revoke all on function public.founder_r3689_hotspot_resistance_digest() from public, anon;
grant execute on function public.founder_r3689_hotspot_resistance_digest() to authenticated;

-- 8) High-risk panel queue (hazardous / trip failures / over-limit earth)
create or replace function public.founder_r3689_high_risk_queue()
returns table(
  site_name text,
  panel_zone text,
  install_zone text,
  period_month date,
  electrical_status text,
  max_earth_resistance_ohm numeric,
  resistance_limit_ohm numeric,
  elcb_trip_pass_pct numeric,
  thermography_hotspots int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.panel_zone, l.install_zone, l.period_month,
    l.electrical_status, l.max_earth_resistance_ohm, l.resistance_limit_ohm,
    l.elcb_trip_pass_pct, l.thermography_hotspots, l.trend_dir, l.notes
  from public.building_electrical_r3689 l
  where l.electrical_status in ('hazardous','trip_failures','resistance_high')
     or l.max_earth_resistance_ohm > l.resistance_limit_ohm
     or l.elcb_trip_pass_pct < 100.0
     or l.trend_dir = 'worsening'
  order by
    case l.electrical_status
      when 'hazardous' then 0
      when 'trip_failures' then 1
      when 'resistance_high' then 2
      else 3
    end,
    l.period_month desc, l.site_name;
end;
$$;

revoke all on function public.founder_r3689_high_risk_queue() from public, anon;
grant execute on function public.founder_r3689_high_risk_queue() to authenticated;
