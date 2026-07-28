-- Round 3581: Founder Return-on-Capital-Employed (ROCE) / Capital-Efficiency Board
-- Per-business-unit ROCE — EBIT × capital employed × ROCE% vs target × WACC spread × asset base × working capital × efficiency status × trend × CAPA

-- =============================================================================
-- TABLE 1: roce_board_r3581 — per-business-unit monthly ROCE / capital-efficiency fact
-- =============================================================================
create table if not exists public.roce_board_r3581 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  record_code text not null,
  business_unit text not null,
  period_month date not null,
  ebit_rupees numeric(14,2),
  capital_employed_rupees numeric(14,2),
  roce_pct numeric(6,2),
  target_roce_pct numeric(6,2),
  wacc_pct numeric(6,2),
  spread_over_wacc_pct numeric(6,2),
  asset_base_rupees numeric(14,2),
  working_capital_rupees numeric(14,2),
  efficiency_status text not null check (efficiency_status in (
    'value_creating','on_target','below_target','value_destroying'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roce_board_r3581 enable row level security;

create index if not exists idx_roce_board_r3581_org on public.roce_board_r3581(organization_id);
create index if not exists idx_roce_board_r3581_period on public.roce_board_r3581(period_month);
create index if not exists idx_roce_board_r3581_status on public.roce_board_r3581(efficiency_status);

-- =============================================================================
-- TABLE 2: roce_board_capa_actions_r3581 — capital-efficiency CAPA & remediation
-- =============================================================================
create table if not exists public.roce_board_capa_actions_r3581 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  board_id uuid not null references public.roce_board_r3581(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'roce_below_target','negative_wacc_spread','excess_working_capital','idle_asset_base',
    'ebit_margin_decline','capital_misallocation','inventory_overstock','receivables_overdue',
    'underutilized_capacity','value_destruction'
  )),
  root_cause text not null check (root_cause in (
    'demand_shortfall','pricing_pressure','cost_overrun','overinvestment_in_assets',
    'slow_receivables_collection','excess_inventory_buildup','idle_capacity','high_financing_cost',
    'pending_investigation','one_time_writeoff'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_service_contracts','reduce_working_capital','divest_idle_assets','accelerate_receivables',
    'optimize_inventory','reallocate_capital','cost_reduction_program','refinance_debt',
    'improve_asset_utilization','exit_business_unit','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  capital_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roce_board_capa_actions_r3581 enable row level security;

create index if not exists idx_roce_board_capa_r3581_board on public.roce_board_capa_actions_r3581(board_id);
create index if not exists idx_roce_board_capa_r3581_status on public.roce_board_capa_actions_r3581(capa_status);

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

  -- 16 business-unit ROCE rows
  insert into public.roce_board_r3581 (
    organization_id, record_code, business_unit, period_month,
    ebit_rupees, capital_employed_rupees, roce_pct, target_roce_pct, wacc_pct,
    spread_over_wacc_pct, asset_base_rupees, working_capital_rupees,
    efficiency_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.bu, q.pmon::date,
    q.ebit, q.capemp, q.roce, q.troce, q.wacc,
    q.spread, q.asset, q.wc,
    q.effstat, q.trend, q.nt
  from (values
    ('AMC-202604','AMC Services','2026-04-01',
     4200000,18000000,23.3,20.0,13.5,9.8,12000000,6000000,'value_creating','improving','AMC book scaling with strong contract renewals'),
    ('AMC-202605','AMC Services','2026-05-01',
     4500000,18500000,24.3,20.0,13.5,10.8,12200000,6300000,'value_creating','improving','Renewal rate up, margin expansion continues'),
    ('SPARE-202604','Spare Parts','2026-04-01',
     2100000,15000000,14.0,18.0,13.5,0.5,5000000,10000000,'below_target','stable','High inventory holding drags capital efficiency'),
    ('SPARE-202605','Spare Parts','2026-05-01',
     2000000,15600000,12.8,18.0,13.5,-0.7,5100000,10500000,'below_target','worsening','Working capital creep from slow-moving SKUs'),
    ('RENT-202604','Rental Fleet','2026-04-01',
     3800000,22000000,17.3,16.0,13.5,3.8,19000000,3000000,'on_target','stable','Fleet utilization steady at 72 percent'),
    ('RENT-202605','Rental Fleet','2026-05-01',
     3600000,22500000,16.0,16.0,13.5,2.5,19500000,3000000,'on_target','stable','Utilization flat; a few idle units flagged'),
    ('INSTALL-202604','Installation Projects','2026-04-01',
     900000,14000000,6.4,15.0,13.5,-7.1,3000000,11000000,'value_destroying','worsening','Project WIP and retention money locking capital'),
    ('INSTALL-202605','Installation Projects','2026-05-01',
     1100000,13500000,8.1,15.0,13.5,-5.4,3000000,10500000,'value_destroying','improving','Milestone billing improving but still below WACC'),
    ('CALIB-202604','Calibration Lab','2026-04-01',
     1600000,6000000,26.7,22.0,13.5,13.2,4500000,1500000,'value_creating','improving','NABL lab high asset turns, premium pricing'),
    ('CALIB-202605','Calibration Lab','2026-05-01',
     1650000,6100000,27.0,22.0,13.5,13.5,4600000,1500000,'value_creating','stable','Calibration demand robust across South region'),
    ('MKT-202604','Marketplace','2026-04-01',
     -400000,9000000,-4.4,12.0,13.5,-17.9,2000000,7000000,'value_destroying','worsening','Marketplace still sub-scale, cash burn on incentives'),
    ('MKT-202605','Marketplace','2026-05-01',
     -250000,9200000,-2.7,12.0,13.5,-16.2,2100000,7100000,'value_destroying','improving','Take-rate up; losses narrowing but capital destructive'),
    ('CONS-202604','Consumables','2026-04-01',
     2400000,11000000,21.8,18.0,13.5,8.3,3000000,8000000,'value_creating','stable','Consumables annuity revenue with healthy turns'),
    ('CONS-202605','Consumables','2026-05-01',
     2350000,11200000,21.0,18.0,13.5,7.5,3050000,8150000,'value_creating','stable','Steady reorder volumes; receivables in control'),
    ('REFURB-202604','Refurbishment','2026-04-01',
     1300000,9500000,13.7,16.0,13.5,0.2,6000000,3500000,'below_target','improving','Refurb yield improving but capital tied in cores'),
    ('REFURB-202605','Refurbishment','2026-05-01',
     1450000,9600000,15.1,16.0,13.5,1.6,6100000,3500000,'below_target','improving','Core sourcing better; nearing target ROCE')
  ) as q(rcode, bu, pmon, ebit, capemp, roce, troce, wacc, spread, asset, wc, effstat, trend, nt);

  -- CAPA seed — attach to specific board rows via record_code
  insert into public.roce_board_capa_actions_r3581 (
    organization_id, board_id, finding_category, root_cause, corrective_action,
    capa_status, capital_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.owner, q.tcd::date, q.acd::date, q.nt
  from (values
    ('INSTALL-202604','negative_wacc_spread','overinvestment_in_assets','reduce_working_capital','in_progress',7100000,'CFO Office','2026-06-30',null,'Retention money and WIP locking capital below WACC'),
    ('INSTALL-202605','excess_working_capital','slow_receivables_collection','accelerate_receivables','verification_pending',5400000,'Projects Head','2026-06-25',null,'Milestone billing cadence being tightened'),
    ('MKT-202604','value_destruction','demand_shortfall','reallocate_capital','escalated',1620000,'Founder Office','2026-06-20',null,'Marketplace burn escalated to board for capital review'),
    ('MKT-202605','ebit_margin_decline','pricing_pressure','reprice_service_contracts','open',1490000,'Marketplace Lead','2026-07-10',null,'Take-rate revision under evaluation'),
    ('SPARE-202605','inventory_overstock','excess_inventory_buildup','optimize_inventory','in_progress',900000,'Supply Chain','2026-06-28',null,'Slow-moving SKU liquidation plan in motion'),
    ('SPARE-202604','excess_working_capital','excess_inventory_buildup','reduce_working_capital','closed',650000,'Supply Chain','2026-05-31','2026-05-28','Reorder points recalibrated; working capital reduced'),
    ('REFURB-202604','roce_below_target','idle_capacity','improve_asset_utilization','in_progress',300000,'Ops Head','2026-06-15',null,'Core sourcing ramp to lift refurb throughput'),
    ('RENT-202605','underutilized_capacity','idle_capacity','improve_asset_utilization','open',450000,'Rental Ops','2026-07-05',null,'Idle fleet units to be redeployed or divested')
  ) as q(rcode, fc, rc, ca, cst, impact, owner, tcd, acd, nt)
  join public.roce_board_r3581 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Efficiency-status distribution
create or replace function public.founder_r3581_efficiency_status_rollup()
returns table(efficiency_status text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roce_board_r3581)
  select l.efficiency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.roce_board_r3581 l
  group by l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3581_efficiency_status_rollup() from public, anon;
grant execute on function public.founder_r3581_efficiency_status_rollup() to authenticated;

-- 2) Business-unit ROCE scorecard
create or replace function public.founder_r3581_business_unit_scorecard()
returns table(
  business_unit text,
  periods bigint,
  avg_roce_pct numeric,
  avg_target_roce_pct numeric,
  avg_spread_over_wacc_pct numeric,
  total_ebit_rupees numeric,
  value_creating bigint,
  below_or_destroying bigint,
  on_target_or_better_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit,
    count(*)::bigint,
    round(avg(l.roce_pct), 2),
    round(avg(l.target_roce_pct), 2),
    round(avg(l.spread_over_wacc_pct), 2),
    coalesce(sum(l.ebit_rupees),0)::numeric,
    count(*) filter (where l.efficiency_status = 'value_creating')::bigint,
    count(*) filter (where l.efficiency_status in ('below_target','value_destroying'))::bigint,
    round(100.0 * count(*) filter (where l.efficiency_status in ('value_creating','on_target'))::numeric / nullif(count(*),0), 1)
  from public.roce_board_r3581 l
  group by l.business_unit
  order by avg(l.roce_pct) desc;
end;
$$;

revoke execute on function public.founder_r3581_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3581_business_unit_scorecard() to authenticated;

-- 3) Business-unit × efficiency-status matrix
create or replace function public.founder_r3581_unit_efficiency_matrix()
returns table(business_unit text, efficiency_status text, periods bigint, avg_roce_pct numeric, avg_spread_over_wacc_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.efficiency_status, count(*)::bigint,
    round(avg(l.roce_pct), 2),
    round(avg(l.spread_over_wacc_pct), 2)
  from public.roce_board_r3581 l
  group by l.business_unit, l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3581_unit_efficiency_matrix() from public, anon;
grant execute on function public.founder_r3581_unit_efficiency_matrix() to authenticated;

-- 4) Monthly ROCE trend
create or replace function public.founder_r3581_monthly_roce_trend()
returns table(period_month date, units bigint, avg_roce_pct numeric, avg_target_roce_pct numeric, avg_spread_over_wacc_pct numeric, value_destroying bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.roce_pct), 2),
    round(avg(l.target_roce_pct), 2),
    round(avg(l.spread_over_wacc_pct), 2),
    count(*) filter (where l.efficiency_status = 'value_destroying')::bigint
  from public.roce_board_r3581 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3581_monthly_roce_trend() from public, anon;
grant execute on function public.founder_r3581_monthly_roce_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3581_capa_status_board()
returns table(capa_status text, findings bigint, avg_capital_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.capital_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.roce_board_capa_actions_r3581 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3581_capa_status_board() from public, anon;
grant execute on function public.founder_r3581_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3581_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_capital_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roce_board_capa_actions_r3581)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.capital_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.roce_board_capa_actions_r3581 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3581_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3581_root_cause_pareto() to authenticated;

-- 7) Capital-efficiency impact digest (by finding category)
create or replace function public.founder_r3581_capital_efficiency_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_capital_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.capital_impact_rupees),0)::numeric
  from public.roce_board_capa_actions_r3581 c
  group by c.finding_category
  order by coalesce(sum(c.capital_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3581_capital_efficiency_impact_digest() from public, anon;
grant execute on function public.founder_r3581_capital_efficiency_impact_digest() to authenticated;

-- 8) High-risk (value-destroying / below-target) queue
create or replace function public.founder_r3581_high_risk_queue()
returns table(
  business_unit text,
  record_code text,
  period_month date,
  roce_pct numeric,
  target_roce_pct numeric,
  spread_over_wacc_pct numeric,
  efficiency_status text,
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
  select l.business_unit, l.record_code, l.period_month,
    l.roce_pct, l.target_roce_pct, l.spread_over_wacc_pct,
    l.efficiency_status, l.trend_dir, l.notes
  from public.roce_board_r3581 l
  where l.efficiency_status in ('below_target','value_destroying')
     or l.spread_over_wacc_pct < 0
     or l.roce_pct < l.target_roce_pct
     or l.trend_dir = 'worsening'
  order by l.spread_over_wacc_pct asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3581_high_risk_queue() from public, anon;
grant execute on function public.founder_r3581_high_risk_queue() to authenticated;
