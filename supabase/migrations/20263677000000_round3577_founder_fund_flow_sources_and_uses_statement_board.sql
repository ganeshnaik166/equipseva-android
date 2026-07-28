-- Round 3577: Founder Fund-Flow Sources-and-Uses Statement Board
-- Fund-flow statement — sources vs uses of funds + working-capital movement per period.
-- flow item × period × flow category × source/use type × amount × cumulative × net fund position
-- × flow status × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: fund_flow_r3577 — per-line-item sources-and-uses fund-flow entries
-- =============================================================================
create table if not exists public.fund_flow_r3577 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  flow_item text not null,
  period_month date not null,
  flow_category text not null check (flow_category in (
    'source','use'
  )),
  source_type text not null check (source_type in (
    'operations','debt','equity','asset_sale','wc_release','none'
  )),
  use_type text not null check (use_type in (
    'capex','debt_repay','dividend','wc_increase','investment','none'
  )),
  amount_rupees numeric(14,2) not null,
  cumulative_rupees numeric(14,2),
  net_fund_position_rupees numeric(14,2),
  flow_status text not null check (flow_status in (
    'surplus','balanced','deficit','strained'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fund_flow_r3577 enable row level security;

create index if not exists idx_fund_flow_r3577_org on public.fund_flow_r3577(organization_id);
create index if not exists idx_fund_flow_r3577_period on public.fund_flow_r3577(period_month);
create index if not exists idx_fund_flow_r3577_status on public.fund_flow_r3577(flow_status);

-- =============================================================================
-- TABLE 2: fund_flow_capa_actions_r3577 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.fund_flow_capa_actions_r3577 (
  id uuid primary key default gen_random_uuid(),
  flow_item_id uuid not null references public.fund_flow_r3577(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cash_deficit','wc_deterioration','debt_repay_shortfall','capex_overrun','collection_delay',
    'liquidity_gap','covenant_breach_risk','forecast_variance','dividend_strain','none'
  )),
  root_cause text not null check (root_cause in (
    'receivables_delay','inventory_buildup','revenue_shortfall','cost_overrun','delayed_funding',
    'high_capex','debt_servicing_pressure','seasonal_dip','payables_squeeze','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'accelerate_collections','defer_capex','raise_bridge_debt','equity_infusion','renegotiate_terms',
    'reduce_inventory','delay_dividend','draw_wc_line','cost_rationalization','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_area text not null check (impact_area in (
    'liquidity_risk','covenant_risk','none','internal_only','investor_reporting','board_escalation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fund_flow_capa_actions_r3577 enable row level security;

create index if not exists idx_fund_flow_capa_r3577_item on public.fund_flow_capa_actions_r3577(flow_item_id);
create index if not exists idx_fund_flow_capa_r3577_status on public.fund_flow_capa_actions_r3577(capa_status);

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

  -- 16 fund-flow line items across May-Jul 2026
  insert into public.fund_flow_r3577 (
    organization_id, flow_item, period_month, flow_category, source_type, use_type,
    amount_rupees, cumulative_rupees, net_fund_position_rupees, flow_status, trend_dir, notes
  )
  select v_org_id, q.itm, q.pm::date, q.cat, q.src, q.ut,
    q.amt, q.cum, q.netp, q.fst, q.trd, q.nt
  from (values
    ('Operating cash inflow May','2026-05-01','source','operations','none',4200000,4200000,1500000,'surplus','improving','Service AMC and repair collections strong in May'),
    ('Term loan drawdown May','2026-05-01','source','debt','none',2500000,6700000,1800000,'surplus','stable','Working-capital term loan tranche drawn from HDFC'),
    ('Capex spare-parts inventory May','2026-05-01','use','none','capex',1800000,4900000,1200000,'balanced','stable','Diagnostic spares and calibration kit purchase'),
    ('WC increase receivables May','2026-05-01','use','none','wc_increase',1600000,3300000,400000,'deficit','worsening','Receivables ballooned as hospital payments slipped'),
    ('Operating cash inflow Jun','2026-06-01','source','operations','none',3800000,7100000,900000,'balanced','worsening','June collections dipped on delayed government-hospital payments'),
    ('Equity infusion Jun','2026-06-01','source','equity','none',5000000,12100000,4500000,'surplus','improving','Pre-Series-A bridge equity from angel syndicate'),
    ('Debt repayment Jun','2026-06-01','use','none','debt_repay',1200000,10900000,3300000,'surplus','stable','Scheduled term-loan EMI to HDFC'),
    ('Capex service-van fleet Jun','2026-06-01','use','none','capex',2200000,8700000,1100000,'balanced','stable','Two field-service vans for Bengaluru and Hyderabad'),
    ('Investment fixed-deposit Jun','2026-06-01','use','none','investment',3000000,5700000,-200000,'deficit','worsening','Surplus parked in FD reduced liquidity buffer below threshold'),
    ('Operating cash inflow Jul','2026-07-01','source','operations','none',4600000,10300000,700000,'balanced','improving','July AMC renewals and spot-repair revenue recovered'),
    ('Asset sale old equipment Jul','2026-07-01','source','asset_sale','none',800000,11100000,1500000,'surplus','improving','Disposed end-of-life demo units and refurb stock'),
    ('WC release payables Jul','2026-07-01','source','wc_release','none',1400000,12500000,2900000,'surplus','improving','Extended vendor credit terms freed working capital'),
    ('Dividend payout Jul','2026-07-01','use','none','dividend',900000,11600000,2000000,'balanced','stable','Founder dividend against retained earnings'),
    ('WC increase inventory Jul','2026-07-01','use','none','wc_increase',2100000,9500000,-100000,'deficit','worsening','Inventory buildup ahead of monsoon service season strained cash'),
    ('Bridge debt drawdown Jul','2026-07-01','source','debt','none',1500000,11000000,400000,'strained','worsening','Emergency bridge line drawn to cover payroll gap'),
    ('Capex diagnostic-lab setup Jul','2026-07-01','use','none','capex',2600000,8400000,-600000,'strained','worsening','Calibration-lab capex pushed net position negative')
  ) as q(itm, pm, cat, src, ut, amt, cum, netp, fst, trd, nt);

  -- CAPA seed — attach to specific line items via flow_item
  insert into public.fund_flow_capa_actions_r3577 (
    flow_item_id, finding_category, root_cause, corrective_action,
    capa_status, impact_area, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ia, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WC increase receivables May','wc_deterioration','receivables_delay','accelerate_collections','in_progress','liquidity_risk','2026-05-20',null,0.00,'Receivables ageing beyond 90 days; collections drive with hospital accounts'),
    ('Investment fixed-deposit Jun','liquidity_gap','delayed_funding','renegotiate_terms','open','liquidity_risk','2026-06-25',null,50000.00,'FD lock-in cut liquidity buffer; renegotiating premature-withdrawal terms'),
    ('WC increase inventory Jul','wc_deterioration','inventory_buildup','reduce_inventory','in_progress','internal_only','2026-07-20',null,120000.00,'Slow-moving spares inventory; liquidation and JIT reorder plan'),
    ('Bridge debt drawdown Jul','liquidity_gap','revenue_shortfall','raise_bridge_debt','escalated','board_escalation','2026-07-15',null,300000.00,'Payroll gap covered by bridge line; escalated to board for equity top-up'),
    ('Capex diagnostic-lab setup Jul','capex_overrun','high_capex','defer_capex','open','liquidity_risk','2026-07-31',null,180000.00,'Lab capex overran budget; deferring phase-2 fit-out'),
    ('Operating cash inflow Jun','collection_delay','receivables_delay','accelerate_collections','closed','none','2026-06-30','2026-06-28',0.00,'Govt-hospital payment delay resolved after escalation'),
    ('Dividend payout Jul','dividend_strain','debt_servicing_pressure','delay_dividend','verification_pending','investor_reporting','2026-07-25',null,0.00,'Dividend timing reviewed against debt-service cover; deferral verified'),
    ('Capex service-van fleet Jun','capex_overrun','cost_overrun','cost_rationalization','overdue','internal_only','2026-06-20',null,90000.00,'Van fit-out costs overran; rationalization review past due')
  ) as q(itm, fc, rc, ca, cst, ia, tcd, acd, cost, nt)
  join public.fund_flow_r3577 e
    on e.organization_id = v_org_id and e.flow_item = q.itm;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Flow-status distribution
create or replace function public.founder_r3577_flow_status_rollup()
returns table(flow_status text, line_items bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fund_flow_r3577)
  select l.flow_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fund_flow_r3577 l
  group by l.flow_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3577_flow_status_rollup() from public, anon;
grant execute on function public.founder_r3577_flow_status_rollup() to authenticated;

-- 2) Flow-category scorecard
create or replace function public.founder_r3577_flow_category_scorecard()
returns table(
  flow_category text,
  line_items bigint,
  total_amount_rupees numeric,
  surplus_items bigint,
  deficit_items bigint,
  strained_items bigint,
  worsening_items bigint,
  avg_net_position_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.flow_category,
    count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    count(*) filter (where l.flow_status = 'surplus')::bigint,
    count(*) filter (where l.flow_status = 'deficit')::bigint,
    count(*) filter (where l.flow_status = 'strained')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint,
    round(avg(l.net_fund_position_rupees), 0)
  from public.fund_flow_r3577 l
  group by l.flow_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3577_flow_category_scorecard() from public, anon;
grant execute on function public.founder_r3577_flow_category_scorecard() to authenticated;

-- 3) Source/use-type × flow-status matrix
create or replace function public.founder_r3577_source_use_status_matrix()
returns table(
  flow_category text,
  flow_type text,
  flow_status text,
  line_items bigint,
  total_amount_rupees numeric,
  avg_net_position_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.flow_category,
    case when l.flow_category = 'source' then l.source_type else l.use_type end,
    l.flow_status,
    count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(avg(l.net_fund_position_rupees), 0)
  from public.fund_flow_r3577 l
  group by l.flow_category,
    case when l.flow_category = 'source' then l.source_type else l.use_type end,
    l.flow_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3577_source_use_status_matrix() from public, anon;
grant execute on function public.founder_r3577_source_use_status_matrix() to authenticated;

-- 4) Monthly fund-flow trend
create or replace function public.founder_r3577_monthly_fund_flow_trend()
returns table(
  period_month date,
  line_items bigint,
  source_amount_rupees numeric,
  use_amount_rupees numeric,
  net_amount_rupees numeric,
  surplus_items bigint,
  deficit_items bigint
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
    coalesce(sum(l.amount_rupees) filter (where l.flow_category = 'source'),0)::numeric,
    coalesce(sum(l.amount_rupees) filter (where l.flow_category = 'use'),0)::numeric,
    (coalesce(sum(l.amount_rupees) filter (where l.flow_category = 'source'),0)
      - coalesce(sum(l.amount_rupees) filter (where l.flow_category = 'use'),0))::numeric,
    count(*) filter (where l.flow_status = 'surplus')::bigint,
    count(*) filter (where l.flow_status in ('deficit','strained'))::bigint
  from public.fund_flow_r3577 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3577_monthly_fund_flow_trend() from public, anon;
grant execute on function public.founder_r3577_monthly_fund_flow_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3577_capa_status_board()
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
  from public.fund_flow_capa_actions_r3577 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3577_capa_status_board() from public, anon;
grant execute on function public.founder_r3577_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3577_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fund_flow_capa_actions_r3577)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fund_flow_capa_actions_r3577 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3577_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3577_root_cause_pareto() to authenticated;

-- 7) Net-position impact digest (by trend direction)
create or replace function public.founder_r3577_net_position_impact_digest()
returns table(
  trend_dir text,
  line_items bigint,
  total_amount_rupees numeric,
  avg_net_position_rupees numeric,
  min_net_position_rupees numeric,
  deficit_or_strained_items bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir,
    count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(avg(l.net_fund_position_rupees), 0),
    min(l.net_fund_position_rupees)::numeric,
    count(*) filter (where l.flow_status in ('deficit','strained'))::bigint
  from public.fund_flow_r3577 l
  group by l.trend_dir
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3577_net_position_impact_digest() from public, anon;
grant execute on function public.founder_r3577_net_position_impact_digest() to authenticated;

-- 8) High-risk fund-flow queue (deficit / strained / worsening / negative net position)
create or replace function public.founder_r3577_high_risk_queue()
returns table(
  flow_item text,
  period_month date,
  flow_category text,
  source_type text,
  use_type text,
  amount_rupees numeric,
  net_fund_position_rupees numeric,
  flow_status text,
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
  select l.flow_item, l.period_month, l.flow_category, l.source_type, l.use_type,
    l.amount_rupees, l.net_fund_position_rupees, l.flow_status, l.trend_dir, l.notes
  from public.fund_flow_r3577 l
  where l.flow_status in ('deficit','strained')
     or l.trend_dir = 'worsening'
     or l.net_fund_position_rupees < 0
  order by l.period_month desc, l.flow_item;
end;
$$;

revoke execute on function public.founder_r3577_high_risk_queue() from public, anon;
grant execute on function public.founder_r3577_high_risk_queue() to authenticated;
