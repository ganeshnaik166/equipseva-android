-- Round 3597: Founder Return-on-Equity (ROE) / DuPont Decomposition Board
-- Per-business-unit ROE + DuPont decomposition (net-margin x asset-turnover x equity-multiplier)
-- vs target, with performance status, trend direction, monthly trend & CAPA remediation.

-- =============================================================================
-- TABLE 1: roe_dupont_r3597 — per-business-unit monthly ROE / DuPont snapshot
-- =============================================================================
create table if not exists public.roe_dupont_r3597 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  business_unit text not null,
  period_month date not null,
  net_profit_rupees numeric(16,2),
  revenue_rupees numeric(16,2),
  total_assets_rupees numeric(16,2),
  shareholders_equity_rupees numeric(16,2),
  net_margin_pct numeric(6,2),
  asset_turnover_ratio numeric(6,3),
  equity_multiplier numeric(6,3),
  roe_pct numeric(6,2),
  target_roe_pct numeric(6,2),
  performance_status text not null check (performance_status in (
    'value_accretive','on_target','below_target','value_dilutive'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roe_dupont_r3597 enable row level security;

create index if not exists idx_roe_dupont_r3597_org on public.roe_dupont_r3597(organization_id);
create index if not exists idx_roe_dupont_r3597_month on public.roe_dupont_r3597(period_month);
create index if not exists idx_roe_dupont_r3597_status on public.roe_dupont_r3597(performance_status);

-- =============================================================================
-- TABLE 2: roe_dupont_capa_actions_r3597 — CAPA / value-improvement actions
-- =============================================================================
create table if not exists public.roe_dupont_capa_actions_r3597 (
  id uuid primary key default gen_random_uuid(),
  roe_log_id uuid not null references public.roe_dupont_r3597(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'net_margin_erosion','asset_turnover_low','excess_leverage','idle_asset_base',
    'below_target_roe','value_dilution','working_capital_drag','revenue_shortfall','cost_overrun'
  )),
  root_cause text not null check (root_cause in (
    'pricing_pressure','input_cost_inflation','underutilized_assets','high_receivables',
    'excess_inventory','debt_heavy_capital_structure','low_sales_volume','opex_overrun',
    'pending_investigation','capex_not_yet_productive'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_contracts','renegotiate_supplier_costs','divest_idle_assets','tighten_credit_terms',
    'liquidate_excess_inventory','deleverage_balance_sheet','sales_push_campaign',
    'opex_rationalization','reallocate_capital','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  roe_uplift_bps numeric(8,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roe_dupont_capa_actions_r3597 enable row level security;

create index if not exists idx_roe_dupont_capa_r3597_log on public.roe_dupont_capa_actions_r3597(roe_log_id);
create index if not exists idx_roe_dupont_capa_r3597_status on public.roe_dupont_capa_actions_r3597(capa_status);

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

  -- 18 ROE / DuPont snapshot rows (6 business units x 3 months)
  insert into public.roe_dupont_r3597 (
    organization_id, business_unit, period_month,
    net_profit_rupees, revenue_rupees, total_assets_rupees, shareholders_equity_rupees,
    net_margin_pct, asset_turnover_ratio, equity_multiplier, roe_pct, target_roe_pct,
    performance_status, trend_dir, notes
  )
  select v_org_id, q.bunit, q.pmon::date,
    q.netp, q.rev, q.tassets, q.sheq,
    q.nmarg, q.aturn, q.emult, q.roev, q.troe,
    q.pstat, q.trnd, q.nt
  from (values
    ('Diagnostic Imaging AMC','2026-04-01',4180000,38000000,31666667,20042194,11.00,1.20,1.58,20.86,20.0,'on_target','improving','Imaging AMC base month — contract renewals ramping'),
    ('Diagnostic Imaging AMC','2026-05-01',4720000,40000000,32786885,20620682,11.80,1.22,1.59,22.89,20.0,'value_accretive','improving','Higher-margin CT/MRI AMC mix lifting net margin'),
    ('Diagnostic Imaging AMC','2026-06-01',5208000,42000000,33600000,21000000,12.40,1.25,1.60,24.80,20.0,'value_accretive','improving','ROE well above hurdle — flagship value creator'),
    ('Field Service Contracts','2026-04-01',2392000,26000000,18309859,12371526,9.20,1.42,1.48,19.34,18.0,'on_target','stable','Engineer utilisation steady, turnover strong'),
    ('Field Service Contracts','2026-05-01',2269500,25500000,18214286,12142857,8.90,1.40,1.50,18.69,18.0,'on_target','stable','Marginal margin dip on travel cost, still on target'),
    ('Field Service Contracts','2026-06-01',2411500,26500000,18794326,12613641,9.10,1.41,1.49,19.12,18.0,'on_target','stable','Recurring AMC labour margins holding at hurdle'),
    ('Spare Parts Trading','2026-04-01',3456000,54000000,29189189,20555767,6.40,1.85,1.42,16.81,18.0,'below_target','worsening','Thin trading margin below equity hurdle'),
    ('Spare Parts Trading','2026-05-01',3120000,52000000,28888889,20634921,6.00,1.80,1.40,15.12,18.0,'below_target','worsening','Pricing pressure eroding net margin further'),
    ('Spare Parts Trading','2026-06-01',2800000,50000000,28089888,20354991,5.60,1.78,1.38,13.76,18.0,'below_target','worsening','Inventory buildup dragging turnover and ROE'),
    ('Equipment Rental Fleet','2026-04-01',4200000,30000000,51724138,24057738,14.00,0.58,2.15,17.46,16.0,'on_target','stable','Capital-heavy fleet, leverage-driven ROE at hurdle'),
    ('Equipment Rental Fleet','2026-05-01',4800000,32000000,53333333,24464832,15.00,0.60,2.18,19.62,16.0,'value_accretive','improving','Utilisation up — margin and turnover both improving'),
    ('Equipment Rental Fleet','2026-06-01',5214000,33000000,53225806,24193548,15.80,0.62,2.20,21.55,16.0,'value_accretive','improving','Fleet ROE now clearing hurdle with margin'),
    ('Turnkey Project Delivery','2026-04-01',2100000,60000000,63157895,25263158,3.50,0.95,2.50,8.31,15.0,'value_dilutive','worsening','Low-margin projects on heavy asset base — dilutive'),
    ('Turnkey Project Delivery','2026-05-01',1624000,58000000,64444444,24786325,2.80,0.90,2.60,6.55,15.0,'value_dilutive','worsening','Cost overruns compress margin, leverage rising'),
    ('Turnkey Project Delivery','2026-06-01',1210000,55000000,62500000,23148148,2.20,0.88,2.70,5.23,15.0,'value_dilutive','worsening','ROE far below hurdle — capital reallocation needed'),
    ('Consumables Distribution','2026-04-01',3220000,70000000,34146341,26676829,4.60,2.05,1.28,12.07,14.0,'below_target','stable','High turnover but thin margin keeps ROE under hurdle'),
    ('Consumables Distribution','2026-05-01',3528000,72000000,34285714,26373626,4.90,2.10,1.30,13.38,14.0,'below_target','improving','Credit-terms tightening improving working capital'),
    ('Consumables Distribution','2026-06-01',3848000,74000000,34905660,26645542,5.20,2.12,1.31,14.44,14.0,'on_target','improving','Consumables ROE reaches hurdle on margin recovery')
  ) as q(bunit, pmon, netp, rev, tassets, sheq, nmarg, aturn, emult, roev, troe, pstat, trnd, nt);

  -- CAPA seed — attach to specific snapshots via business_unit + period_month
  insert into public.roe_dupont_capa_actions_r3597 (
    roe_log_id, finding_category, root_cause, corrective_action,
    capa_status, roe_uplift_bps, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.uplift, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Turnkey Project Delivery','2026-06-01','value_dilution','debt_heavy_capital_structure','deleverage_balance_sheet','escalated',320,'CFO','2026-08-31',null,'Balance-sheet deleveraging plan escalated to board'),
    ('Turnkey Project Delivery','2026-05-01','cost_overrun','opex_overrun','opex_rationalization','in_progress',180,'BU Head - Projects','2026-08-15',null,'Site-cost controls and change-order discipline underway'),
    ('Spare Parts Trading','2026-06-01','net_margin_erosion','pricing_pressure','reprice_contracts','open',150,'Head - Spares','2026-08-20',null,'Repricing distributor contracts to defend margin'),
    ('Spare Parts Trading','2026-05-01','working_capital_drag','excess_inventory','liquidate_excess_inventory','verification_pending',90,'Supply Chain Lead','2026-07-31',null,'Slow-moving SKU liquidation — verifying turnover uplift'),
    ('Consumables Distribution','2026-04-01','below_target_roe','high_receivables','tighten_credit_terms','closed',110,'Finance Controller','2026-06-30','2026-06-25','Credit terms tightened to 30 days — receivables down'),
    ('Equipment Rental Fleet','2026-04-01','asset_turnover_low','underutilized_assets','divest_idle_assets','in_progress',130,'Head - Rental','2026-08-10',null,'Divesting idle rental units to lift asset turnover'),
    ('Diagnostic Imaging AMC','2026-04-01','revenue_shortfall','low_sales_volume','sales_push_campaign','closed',70,'Head - Imaging','2026-06-15','2026-06-10','AMC renewal drive closed the volume gap'),
    ('Turnkey Project Delivery','2026-04-01','excess_leverage','capex_not_yet_productive','reallocate_capital','overdue',260,'CFO','2026-07-15',null,'Unproductive project capex — reallocation past due')
  ) as q(bunit, pmon, fc, rc, ca, cst, uplift, ownr, tcd, acd, nt)
  join public.roe_dupont_r3597 e
    on e.organization_id = v_org_id and e.business_unit = q.bunit and e.period_month = q.pmon::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Performance-status distribution
create or replace function public.founder_r3597_performance_status_rollup()
returns table(performance_status text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roe_dupont_r3597)
  select l.performance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.roe_dupont_r3597 l
  group by l.performance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3597_performance_status_rollup() from public, anon;
grant execute on function public.founder_r3597_performance_status_rollup() to authenticated;

-- 2) Business-unit ROE scorecard
create or replace function public.founder_r3597_business_unit_scorecard()
returns table(
  business_unit text,
  periods bigint,
  avg_net_margin_pct numeric,
  avg_asset_turnover_ratio numeric,
  avg_equity_multiplier numeric,
  avg_roe_pct numeric,
  avg_target_roe_pct numeric,
  roe_gap_pct numeric,
  underperform_periods bigint
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
    round(avg(l.net_margin_pct), 2),
    round(avg(l.asset_turnover_ratio), 3),
    round(avg(l.equity_multiplier), 3),
    round(avg(l.roe_pct), 2),
    round(avg(l.target_roe_pct), 2),
    round(avg(l.roe_pct) - avg(l.target_roe_pct), 2),
    count(*) filter (where l.performance_status in ('below_target','value_dilutive'))::bigint
  from public.roe_dupont_r3597 l
  group by l.business_unit
  order by round(avg(l.roe_pct), 2) desc;
end;
$$;

revoke execute on function public.founder_r3597_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3597_business_unit_scorecard() to authenticated;

-- 3) Business-unit x performance-status matrix
create or replace function public.founder_r3597_business_unit_status_matrix()
returns table(business_unit text, performance_status text, periods bigint, avg_roe_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.performance_status, count(*)::bigint,
    round(avg(l.roe_pct), 2)
  from public.roe_dupont_r3597 l
  group by l.business_unit, l.performance_status
  order by l.business_unit, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3597_business_unit_status_matrix() from public, anon;
grant execute on function public.founder_r3597_business_unit_status_matrix() to authenticated;

-- 4) Monthly ROE / DuPont trend
create or replace function public.founder_r3597_monthly_roe_trend()
returns table(
  period_month date,
  units bigint,
  avg_net_margin_pct numeric,
  avg_asset_turnover_ratio numeric,
  avg_equity_multiplier numeric,
  avg_roe_pct numeric,
  underperform_units bigint
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
    round(avg(l.net_margin_pct), 2),
    round(avg(l.asset_turnover_ratio), 3),
    round(avg(l.equity_multiplier), 3),
    round(avg(l.roe_pct), 2),
    count(*) filter (where l.performance_status in ('below_target','value_dilutive'))::bigint
  from public.roe_dupont_r3597 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3597_monthly_roe_trend() from public, anon;
grant execute on function public.founder_r3597_monthly_roe_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3597_capa_status_board()
returns table(capa_status text, findings bigint, avg_roe_uplift_bps numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.roe_uplift_bps)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.roe_dupont_capa_actions_r3597 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3597_capa_status_board() from public, anon;
grant execute on function public.founder_r3597_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3597_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_roe_uplift_bps numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roe_dupont_capa_actions_r3597)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.roe_uplift_bps),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.roe_dupont_capa_actions_r3597 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3597_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3597_root_cause_pareto() to authenticated;

-- 7) ROE-driver digest (DuPont drivers by performance status)
create or replace function public.founder_r3597_roe_driver_digest()
returns table(
  performance_status text,
  units bigint,
  avg_net_margin_pct numeric,
  avg_asset_turnover_ratio numeric,
  avg_equity_multiplier numeric,
  avg_roe_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.performance_status,
    count(*)::bigint,
    round(avg(l.net_margin_pct), 2),
    round(avg(l.asset_turnover_ratio), 3),
    round(avg(l.equity_multiplier), 3),
    round(avg(l.roe_pct), 2)
  from public.roe_dupont_r3597 l
  group by l.performance_status
  order by round(avg(l.roe_pct), 2) desc;
end;
$$;

revoke execute on function public.founder_r3597_roe_driver_digest() from public, anon;
grant execute on function public.founder_r3597_roe_driver_digest() to authenticated;

-- 8) High-risk queue (value_dilutive / below_target)
create or replace function public.founder_r3597_high_risk_queue()
returns table(
  business_unit text,
  period_month date,
  roe_pct numeric,
  target_roe_pct numeric,
  net_margin_pct numeric,
  asset_turnover_ratio numeric,
  equity_multiplier numeric,
  performance_status text,
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
  select l.business_unit, l.period_month, l.roe_pct, l.target_roe_pct,
    l.net_margin_pct, l.asset_turnover_ratio, l.equity_multiplier,
    l.performance_status, l.trend_dir, l.notes
  from public.roe_dupont_r3597 l
  where l.performance_status in ('below_target','value_dilutive')
     or l.trend_dir = 'worsening'
     or l.roe_pct < l.target_roe_pct
  order by l.roe_pct asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3597_high_risk_queue() from public, anon;
grant execute on function public.founder_r3597_high_risk_queue() to authenticated;
