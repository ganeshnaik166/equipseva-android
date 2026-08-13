-- Round 3718: Founder Returnable Packaging / Crate-Pool Circulation Board
-- Returnable packaging (crates/pallets/IBC totes/cylinders) circulating between depots and customers —
-- units issued vs returned, deposit reconciliation, loss/damage rate, pool utilization.
-- Distinct from any packaging-SPEND/dunnage-cost page and from any transit-DAMAGE-CLAIMS page — this
-- ship is about the circulating asset POOL itself.

-- =============================================================================
-- TABLE 1: crate_pool_r3718 — per-asset-type / depot-region / month crate-pool circulation log
-- =============================================================================
create table if not exists public.crate_pool_r3718 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_type text not null,
  depot_region text not null,
  period_month date not null,
  units_issued int not null,
  units_returned int not null,
  units_outstanding int not null,
  avg_return_cycle_days numeric,
  deposit_collected_rupees numeric(12,2),
  deposit_refunded_rupees numeric(12,2),
  units_damaged int,
  units_lost int,
  replacement_cost_rupees numeric(12,2),
  pool_utilization_pct numeric,
  container_class text not null check (container_class in (
    'crate','pallet','ipc_tote','cylinder','other_returnable'
  )),
  pool_status text not null check (pool_status in (
    'healthy','tight_supply','overdue_returns','high_loss','write_off_review'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crate_pool_r3718 enable row level security;

create index if not exists idx_crate_pool_r3718_org on public.crate_pool_r3718(organization_id);
create index if not exists idx_crate_pool_r3718_month on public.crate_pool_r3718(period_month);
create index if not exists idx_crate_pool_r3718_status on public.crate_pool_r3718(pool_status);

-- =============================================================================
-- TABLE 2: crate_pool_capa_actions_r3718 — CAPA actions on the crate-pool circulation log
-- =============================================================================
create table if not exists public.crate_pool_capa_actions_r3718 (
  id uuid primary key default gen_random_uuid(),
  pool_log_id uuid references public.crate_pool_r3718(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in (
    'open','in_progress','closed','overdue'
  )),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crate_pool_capa_actions_r3718 enable row level security;

create index if not exists idx_crate_pool_capa_r3718_log on public.crate_pool_capa_actions_r3718(pool_log_id);
create index if not exists idx_crate_pool_capa_r3718_status on public.crate_pool_capa_actions_r3718(capa_status);

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

  -- 16 crate-pool circulation rows
  insert into public.crate_pool_r3718 (
    organization_id, asset_type, depot_region, period_month, units_issued, units_returned,
    units_outstanding, avg_return_cycle_days, deposit_collected_rupees, deposit_refunded_rupees,
    units_damaged, units_lost, replacement_cost_rupees, pool_utilization_pct, container_class,
    pool_status, trend_dir, notes, created_at
  )
  select v_org_id, q.atype, q.dreg, q.pmon::date, q.uiss, q.uret, q.uout,
    q.cyc, q.depc, q.depr, q.udam, q.ulost, q.rcost, q.util, q.cclass, q.pstat, q.trd, q.nt, now()
  from (values
    ('HDPE Crate 50L','Mumbai-Bhiwandi','2026-07-01',4200,3950,250,9.2,1260000.00,1185000.00,18,6,42000.00,91.5,'crate','healthy','stable','Return cycle steady well within depot SLA'),
    ('Wooden Pallet CP1','Delhi-NCR','2026-07-01',3600,3080,520,14.5,1800000.00,1540000.00,45,22,198000.00,78.2,'pallet','tight_supply','worsening','Peak-season dispatch outpacing pallet returns from distributors'),
    ('IBC Tote 1000L','Chennai','2026-06-01',850,610,240,38.0,2550000.00,1830000.00,12,9,270000.00,58.6,'ipc_tote','overdue_returns','worsening','Chemical customer holding totes beyond 30-day contract cycle'),
    ('LPG Cylinder 19kg','Bengaluru','2026-07-01',2100,1450,650,22.0,3150000.00,2175000.00,38,61,610000.00,64.1,'cylinder','high_loss','worsening','Field mechanics diverting cylinders to informal refill network'),
    ('Corrugated RPC Large','Pune','2026-06-01',980,520,460,45.0,294000.00,156000.00,210,95,915000.00,39.4,'other_returnable','write_off_review','worsening','RPC fleet degraded beyond repair threshold — bulk write-off proposed'),
    ('HDPE Crate 50L','Kolkata','2026-07-01',3100,2960,140,8.0,930000.00,888000.00,9,4,21000.00,95.0,'crate','healthy','improving','New QR tracking cut cycle time by 2 days this month'),
    ('Wooden Pallet CP2','Hyderabad','2026-06-01',2800,2350,450,17.5,1400000.00,1175000.00,52,18,189000.00,71.0,'pallet','tight_supply','stable','Retail chain returns lagging festival dispatch volumes'),
    ('IBC Tote 1000L','Ahmedabad','2026-05-01',620,560,60,19.0,1860000.00,1680000.00,5,2,54000.00,88.7,'ipc_tote','healthy','improving','Speciality-chemicals lane running clean return cycles'),
    ('LPG Cylinder 19kg','Mumbai-Bhiwandi','2026-06-01',1800,1650,150,15.0,2700000.00,2475000.00,14,11,110000.00,90.2,'cylinder','healthy','stable','Depot-level tracking app adoption stable across routes'),
    ('Corrugated RPC Large','Delhi-NCR','2026-07-01',1450,1180,270,21.0,435000.00,354000.00,88,34,372000.00,68.5,'other_returnable','tight_supply','worsening','E-commerce reverse-logistics partner delaying RPC pickups'),
    ('HDPE Crate 25L','Chennai','2026-05-01',2650,1980,670,29.0,795000.00,594000.00,64,41,252000.00,61.3,'crate','overdue_returns','worsening','Quick-commerce dark-store network holding crates past turnaround window'),
    ('Wooden Pallet CP1','Bengaluru','2026-07-01',3300,3190,110,10.5,1650000.00,1595000.00,21,7,87000.00,94.8,'pallet','healthy','improving','Pooling agreement with 3PL partner improved dock turnaround'),
    ('IBC Tote 650L','Pune','2026-06-01',410,245,165,52.0,1230000.00,735000.00,28,19,310000.00,44.6,'ipc_tote','high_loss','worsening','Lubricant-oil customer tote loss rate exceeding acceptable threshold'),
    ('LPG Cylinder 14kg','Kolkata','2026-05-01',1550,980,570,34.0,1550000.00,980000.00,42,88,640000.00,52.9,'cylinder','write_off_review','worsening','Cylinder shrinkage flagged for board-level write-off decision'),
    ('Wooden Pallet CP2','Ahmedabad','2026-07-01',1900,1805,95,11.0,950000.00,902500.00,16,5,63000.00,92.1,'pallet','healthy','stable','Stable dock turnaround at new Ahmedabad hub'),
    ('Corrugated RPC Medium','Hyderabad','2026-06-01',730,410,320,41.0,219000.00,123000.00,95,58,414000.00,45.8,'other_returnable','overdue_returns','worsening','Fresh-produce vendor retaining RPCs past agreed 15-day cycle')
  ) as q(atype, dreg, pmon, uiss, uret, uout, cyc, depc, depr, udam, ulost, rcost, util, cclass, pstat, trd, nt);

  -- CAPA seed — attach to specific pool rows via asset_type + depot_region
  insert into public.crate_pool_capa_actions_r3718 (
    pool_log_id, root_cause, corrective_action, capa_status, owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('HDPE Crate 25L','Chennai','Quick-commerce dark stores exceeding contracted turnaround window','Renegotiate SLA with dark-store network and add penalty clause for late returns','in_progress','Regional Logistics Manager','2026-08-20',null,'Weekly reconciliation calls started with top 5 dark-store accounts'),
    ('Wooden Pallet CP1','Delhi-NCR','Festival dispatch volume outpaced pallet return velocity from retail distributors','Deploy additional buffer pallet stock and tighten distributor return cycle','open','Depot Supply Planner','2026-08-25',null,'Buffer stock request raised with central pallet pool'),
    ('IBC Tote 1000L','Chennai','Chemical customer retaining totes beyond the 30-day contractual cycle','Issue formal overdue notice and apply deposit forfeiture clause','overdue','Key Accounts Manager','2026-07-30',null,'Legal notice drafted — customer yet to confirm return schedule'),
    ('LPG Cylinder 19kg','Bengaluru','Field mechanics diverting cylinders into informal refill network','Introduce cylinder-level RFID tracking and mechanic accountability audit','in_progress','Fleet Compliance Lead','2026-08-31',null,'RFID pilot running across two routes ahead of full rollout'),
    ('Corrugated RPC Large','Pune','RPC fleet degraded beyond economical repair threshold','Complete condition audit and process bulk write-off with replacement order','closed','Asset Manager','2026-07-15','2026-07-12','412 units written off and replacement order placed with vendor'),
    ('Corrugated RPC Large','Delhi-NCR','E-commerce reverse-logistics partner delaying scheduled RPC pickups','Escalate to partner ops head and add pickup SLA to contract renewal','open','Reverse Logistics Coordinator','2026-09-05',null,'Escalation email sent — awaiting partner response on pickup slots'),
    ('IBC Tote 650L','Pune','Lubricant-oil customer tote loss rate exceeding acceptable threshold','Increase deposit value and mandate tote-return proof before next dispatch','in_progress','Depot Manager - Pune','2026-08-28',null,'Revised deposit terms communicated to customer procurement team'),
    ('LPG Cylinder 14kg','Kolkata','Cylinder shrinkage rate flagged for board-level write-off review','Present shrinkage analysis to board and process approved write-off batch','overdue','Regional Finance Controller','2026-07-31',null,'Board review rescheduled — write-off pending sign-off')
  ) as q(atyp, dreg, rc, ca, cst, ownr, tcd, acd, nt)
  join public.crate_pool_r3718 e
    on e.organization_id = v_org_id and e.asset_type = q.atyp and e.depot_region = q.dreg;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Pool-status distribution
create or replace function public.founder_r3718_pool_status_rollup()
returns table(pool_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crate_pool_r3718)
  select l.pool_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.crate_pool_r3718 l
  group by l.pool_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3718_pool_status_rollup() from public, anon;
grant execute on function public.founder_r3718_pool_status_rollup() to authenticated;

-- 2) Depot-region scorecard
create or replace function public.founder_r3718_depot_region_scorecard()
returns table(
  depot_region text,
  total_entries bigint,
  healthy bigint,
  tight_supply bigint,
  overdue_returns bigint,
  high_loss bigint,
  write_off_review bigint,
  total_units_issued bigint,
  total_units_outstanding bigint,
  avg_pool_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.depot_region,
    count(*)::bigint,
    count(*) filter (where l.pool_status = 'healthy')::bigint,
    count(*) filter (where l.pool_status = 'tight_supply')::bigint,
    count(*) filter (where l.pool_status = 'overdue_returns')::bigint,
    count(*) filter (where l.pool_status = 'high_loss')::bigint,
    count(*) filter (where l.pool_status = 'write_off_review')::bigint,
    coalesce(sum(l.units_issued),0)::bigint,
    coalesce(sum(l.units_outstanding),0)::bigint,
    round(avg(l.pool_utilization_pct), 1)
  from public.crate_pool_r3718 l
  group by l.depot_region
  order by coalesce(sum(l.units_outstanding),0) desc;
end;
$$;

revoke all on function public.founder_r3718_depot_region_scorecard() from public, anon;
grant execute on function public.founder_r3718_depot_region_scorecard() to authenticated;

-- 3) Container-class × pool-status matrix
create or replace function public.founder_r3718_container_class_status_matrix()
returns table(container_class text, pool_status text, entries bigint, avg_units_outstanding numeric, avg_pool_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.container_class, l.pool_status, count(*)::bigint,
    round(avg(l.units_outstanding), 1),
    round(avg(l.pool_utilization_pct), 1)
  from public.crate_pool_r3718 l
  group by l.container_class, l.pool_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3718_container_class_status_matrix() from public, anon;
grant execute on function public.founder_r3718_container_class_status_matrix() to authenticated;

-- 4) Monthly return-cycle trend
create or replace function public.founder_r3718_monthly_cycle_trend()
returns table(
  period_month date,
  entries bigint,
  total_units_issued bigint,
  total_units_returned bigint,
  avg_return_cycle_days numeric,
  units_damaged_total bigint,
  units_lost_total bigint
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
    coalesce(sum(l.units_issued),0)::bigint,
    coalesce(sum(l.units_returned),0)::bigint,
    round(avg(l.avg_return_cycle_days), 1),
    coalesce(sum(l.units_damaged),0)::bigint,
    coalesce(sum(l.units_lost),0)::bigint
  from public.crate_pool_r3718 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3718_monthly_cycle_trend() from public, anon;
grant execute on function public.founder_r3718_monthly_cycle_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3718_capa_status_board()
returns table(capa_status text, actions bigint, past_due bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.target_close_date < current_date and c.actual_close_date is null)::bigint
  from public.crate_pool_capa_actions_r3718 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3718_capa_status_board() from public, anon;
grant execute on function public.founder_r3718_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3718_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crate_pool_capa_actions_r3718)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.crate_pool_capa_actions_r3718 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3718_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3718_root_cause_pareto() to authenticated;

-- 7) Overdue-returns digest by depot region
create or replace function public.founder_r3718_overdue_returns_digest()
returns table(
  depot_region text,
  overdue_entries bigint,
  units_outstanding_total bigint,
  avg_return_cycle_days numeric,
  deposit_at_risk_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.depot_region,
    count(*)::bigint,
    coalesce(sum(l.units_outstanding),0)::bigint,
    round(avg(l.avg_return_cycle_days), 1),
    coalesce(sum(l.deposit_collected_rupees - coalesce(l.deposit_refunded_rupees,0)),0)::numeric
  from public.crate_pool_r3718 l
  where l.pool_status = 'overdue_returns'
  group by l.depot_region
  order by coalesce(sum(l.units_outstanding),0) desc;
end;
$$;

revoke all on function public.founder_r3718_overdue_returns_digest() from public, anon;
grant execute on function public.founder_r3718_overdue_returns_digest() to authenticated;

-- 8) High-risk pool queue (overdue returns / high loss / write-off review)
create or replace function public.founder_r3718_high_risk_queue()
returns table(
  asset_type text,
  depot_region text,
  period_month date,
  container_class text,
  pool_status text,
  units_issued int,
  units_returned int,
  units_outstanding int,
  units_damaged int,
  units_lost int,
  avg_return_cycle_days numeric,
  pool_utilization_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, l.depot_region, l.period_month, l.container_class, l.pool_status,
    l.units_issued, l.units_returned, l.units_outstanding, l.units_damaged, l.units_lost,
    l.avg_return_cycle_days, l.pool_utilization_pct, l.notes
  from public.crate_pool_r3718 l
  where l.pool_status in ('overdue_returns','high_loss','write_off_review')
  order by l.units_outstanding desc, l.avg_return_cycle_days desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3718_high_risk_queue() from public, anon;
grant execute on function public.founder_r3718_high_risk_queue() to authenticated;
