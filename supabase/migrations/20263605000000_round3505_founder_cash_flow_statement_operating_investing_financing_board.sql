-- Round 3505: Founder Cash-Flow Statement (Operating / Investing / Financing) Board
-- Cash-flow waterfall — line item × period × activity type (operating/investing/financing) × inflow × outflow × net flow × budget × variance × flow status × trend × CAPA

-- =============================================================================
-- TABLE 1: cash_flow_statement_r3505 — per-line-item monthly cash-flow entries
-- =============================================================================
create table if not exists public.cash_flow_statement_r3505 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  line_item text not null,
  period_month date not null,
  activity_type text not null check (activity_type in (
    'operating','investing','financing'
  )),
  inflow_rupees numeric(14,2) not null default 0,
  outflow_rupees numeric(14,2) not null default 0,
  net_flow_rupees numeric(14,2) not null default 0,
  budget_net_rupees numeric(14,2) not null default 0,
  variance_rupees numeric(14,2) not null default 0,
  flow_status text not null check (flow_status in (
    'favorable','on_plan','unfavorable','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cash_flow_statement_r3505 enable row level security;

create index if not exists idx_cash_flow_statement_r3505_org on public.cash_flow_statement_r3505(organization_id);
create index if not exists idx_cash_flow_statement_r3505_period on public.cash_flow_statement_r3505(period_month);
create index if not exists idx_cash_flow_statement_r3505_status on public.cash_flow_statement_r3505(flow_status);

-- =============================================================================
-- TABLE 2: cash_flow_statement_capa_actions_r3505 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.cash_flow_statement_capa_actions_r3505 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  statement_id uuid references public.cash_flow_statement_r3505(id) on delete cascade,
  finding_ref text not null,
  finding_category text not null check (finding_category in (
    'budget_variance_negative','collection_shortfall','vendor_payment_spike','capex_overrun',
    'interest_cost_overrun','liquidity_risk','forecast_miss','one_time_outflow'
  )),
  root_cause text not null check (root_cause in (
    'delayed_amc_collections','spare_price_inflation','unplanned_tool_purchase','emi_schedule_change',
    'od_utilisation_high','revenue_slippage','vendor_terms_tightened','capex_scope_creep',
    'forecast_model_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'tighten_collections_process','renegotiate_vendor_terms','defer_discretionary_capex',
    'refinance_od_facility','revise_cash_forecast','accelerate_invoicing','escalate_to_board',
    'staged_capex_release','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cash_flow_statement_capa_actions_r3505 enable row level security;

create index if not exists idx_cash_flow_capa_r3505_org on public.cash_flow_statement_capa_actions_r3505(organization_id);
create index if not exists idx_cash_flow_capa_r3505_stmt on public.cash_flow_statement_capa_actions_r3505(statement_id);
create index if not exists idx_cash_flow_capa_r3505_status on public.cash_flow_statement_capa_actions_r3505(capa_status);

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

  -- 18 cash-flow line-item rows
  insert into public.cash_flow_statement_r3505 (
    organization_id, line_item, period_month, activity_type,
    inflow_rupees, outflow_rupees, net_flow_rupees, budget_net_rupees, variance_rupees,
    flow_status, trend_dir, notes
  )
  select v_org_id, q.li, q.pm::date, q.act,
    q.inf, q.outf, q.netf, q.bud, q.vr,
    q.fs, q.td, q.nt
  from (values
    ('AMC contract collections','2026-07-01','operating',
     4200000,0,4200000,4000000,200000,'favorable','improving','Q2 AMC renewals collected ahead of plan across hospital accounts'),
    ('Spare-parts sales receipts','2026-07-01','operating',
     1850000,0,1850000,2000000,-150000,'on_plan','stable','Spare receipts marginally below plan, two large invoices slipped'),
    ('Field-service labour receipts','2026-07-01','operating',
     2600000,0,2600000,2500000,100000,'favorable','improving','Breakdown-call labour billing up on higher visit volume'),
    ('Vendor spare-part payments','2026-07-01','operating',
     0,2350000,-2350000,-2000000,-350000,'unfavorable','worsening','Spare-part outflow above budget due to price inflation'),
    ('Field engineer payroll','2026-07-01','operating',
     0,3100000,-3100000,-3000000,-100000,'on_plan','stable','Payroll near plan; two new field hires added mid-month'),
    ('GST and TDS remittance','2026-07-01','operating',
     0,1250000,-1250000,-1200000,-50000,'on_plan','stable','Statutory remittance in line with higher revenue'),
    ('Office rent and utilities','2026-07-01','operating',
     0,680000,-680000,-650000,-30000,'on_plan','stable','Rent and utilities steady across branch offices'),
    ('Diagnostic tool-kit purchase','2026-07-01','investing',
     0,1450000,-1450000,-900000,-550000,'critical','worsening','Unplanned calibration tool-kit purchase blew capex budget'),
    ('Calibration lab equipment capex','2026-07-01','investing',
     0,2200000,-2200000,-2200000,0,'on_plan','stable','Lab equipment capex exactly on approved plan'),
    ('Sale of retired service vans','2026-07-01','investing',
     520000,0,520000,400000,120000,'favorable','improving','Auction of retired vans realised above book estimate'),
    ('Term-loan drawdown','2026-07-01','financing',
     5000000,0,5000000,5000000,0,'on_plan','stable','Scheduled working-capital term-loan tranche drawn'),
    ('Term-loan EMI repayment','2026-07-01','financing',
     0,1180000,-1180000,-1180000,0,'on_plan','stable','EMI repayment as per amortisation schedule'),
    ('Working-capital OD interest','2026-07-01','financing',
     0,340000,-340000,-250000,-90000,'unfavorable','worsening','OD interest above plan on higher facility utilisation'),
    ('AMC contract collections','2026-06-01','operating',
     3900000,0,3900000,4000000,-100000,'on_plan','stable','June AMC collections marginally short on a delayed payer'),
    ('Vendor spare-part payments','2026-06-01','operating',
     0,2050000,-2050000,-2000000,-50000,'on_plan','worsening','Vendor outflow creeping up as supplier terms tighten'),
    ('Software platform capitalisation','2026-06-01','investing',
     0,1650000,-1650000,-1500000,-150000,'unfavorable','worsening','Platform capex over plan due to added scope'),
    ('Founder equity infusion','2026-05-01','financing',
     7500000,0,7500000,7500000,0,'on_plan','improving','Founder equity round closed as planned, strengthening runway'),
    ('AMC contract collections','2026-05-01','operating',
     3600000,0,3600000,3800000,-200000,'unfavorable','stable','May AMC collections below plan on renewal cycle timing')
  ) as q(li, pm, act, inf, outf, netf, bud, vr, fs, td, nt);

  -- CAPA seed — attach to specific line items via (line_item, period_month) business key
  insert into public.cash_flow_statement_capa_actions_r3505 (
    organization_id, statement_id, finding_ref, finding_category, root_cause,
    corrective_action, capa_status, impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, m.id, q.fref, q.fc, q.rc,
    q.ca, q.cst, q.imp, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Vendor spare-part payments','2026-07-01','CF-CAPA-071','vendor_payment_spike','spare_price_inflation','renegotiate_vendor_terms','in_progress',350000.00,'Procurement Lead','2026-07-31',null,'Re-tendering top three spare-part suppliers to cap price inflation'),
    ('Diagnostic tool-kit purchase','2026-07-01','CF-CAPA-072','capex_overrun','unplanned_tool_purchase','defer_discretionary_capex','escalated',550000.00,'Finance Controller','2026-07-25',null,'Unbudgeted tool-kit escalated to board; remaining capex frozen'),
    ('Working-capital OD interest','2026-07-01','CF-CAPA-073','interest_cost_overrun','od_utilisation_high','refinance_od_facility','open',90000.00,'Treasury','2026-08-15',null,'Evaluating cheaper OD facility to reduce interest drag'),
    ('Spare-parts sales receipts','2026-07-01','CF-CAPA-074','collection_shortfall','revenue_slippage','accelerate_invoicing','in_progress',150000.00,'Sales Ops','2026-08-05',null,'Pulling forward two slipped spare invoices into current cycle'),
    ('Software platform capitalisation','2026-06-01','CF-CAPA-061','capex_overrun','capex_scope_creep','staged_capex_release','verification_pending',150000.00,'CTO','2026-07-10',null,'Scope frozen; releasing platform capex in staged milestones'),
    ('AMC contract collections','2026-05-01','CF-CAPA-051','collection_shortfall','delayed_amc_collections','tighten_collections_process','closed',200000.00,'Collections Manager','2026-06-15','2026-06-12','Dunning cadence tightened; May shortfall recovered in June'),
    ('Vendor spare-part payments','2026-06-01','CF-CAPA-062','budget_variance_negative','vendor_terms_tightened','renegotiate_vendor_terms','closed',50000.00,'Procurement Lead','2026-07-01','2026-06-28','Negotiated 30-day terms restored with primary supplier'),
    ('AMC contract collections','2026-06-01','CF-CAPA-063','forecast_miss','forecast_model_error','revise_cash_forecast','overdue',100000.00,'FP&A Analyst','2026-06-30',null,'Forecast model correction pending; variance driver reviewed')
  ) as q(li, pm, fref, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.cash_flow_statement_r3505 m
    on m.organization_id = v_org_id and m.line_item = q.li and m.period_month = q.pm::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Flow-status distribution
create or replace function public.founder_r3505_flow_status_rollup()
returns table(flow_status text, line_items bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cash_flow_statement_r3505)
  select l.flow_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cash_flow_statement_r3505 l
  group by l.flow_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3505_flow_status_rollup() from public, anon;
grant execute on function public.founder_r3505_flow_status_rollup() to authenticated;

-- 2) Activity-type scorecard
create or replace function public.founder_r3505_activity_type_scorecard()
returns table(
  activity_type text,
  line_items bigint,
  total_inflow_rupees numeric,
  total_outflow_rupees numeric,
  total_net_rupees numeric,
  total_budget_net_rupees numeric,
  total_variance_rupees numeric,
  favorable bigint,
  adverse bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.activity_type,
    count(*)::bigint,
    coalesce(sum(l.inflow_rupees),0)::numeric,
    coalesce(sum(l.outflow_rupees),0)::numeric,
    coalesce(sum(l.net_flow_rupees),0)::numeric,
    coalesce(sum(l.budget_net_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric,
    count(*) filter (where l.flow_status = 'favorable')::bigint,
    count(*) filter (where l.flow_status in ('unfavorable','critical'))::bigint
  from public.cash_flow_statement_r3505 l
  group by l.activity_type
  order by coalesce(sum(l.net_flow_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3505_activity_type_scorecard() from public, anon;
grant execute on function public.founder_r3505_activity_type_scorecard() to authenticated;

-- 3) Activity-type × flow-status matrix
create or replace function public.founder_r3505_activity_flow_status_matrix()
returns table(activity_type text, flow_status text, line_items bigint, total_net_rupees numeric, total_variance_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.activity_type, l.flow_status, count(*)::bigint,
    coalesce(sum(l.net_flow_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric
  from public.cash_flow_statement_r3505 l
  group by l.activity_type, l.flow_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3505_activity_flow_status_matrix() from public, anon;
grant execute on function public.founder_r3505_activity_flow_status_matrix() to authenticated;

-- 4) Monthly cash-flow trend
create or replace function public.founder_r3505_monthly_cash_flow_trend()
returns table(
  period_month date,
  line_items bigint,
  total_inflow_rupees numeric,
  total_outflow_rupees numeric,
  net_change_rupees numeric,
  budget_net_rupees numeric,
  variance_rupees numeric
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
    coalesce(sum(l.inflow_rupees),0)::numeric,
    coalesce(sum(l.outflow_rupees),0)::numeric,
    coalesce(sum(l.net_flow_rupees),0)::numeric,
    coalesce(sum(l.budget_net_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric
  from public.cash_flow_statement_r3505 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3505_monthly_cash_flow_trend() from public, anon;
grant execute on function public.founder_r3505_monthly_cash_flow_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3505_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cash_flow_statement_capa_actions_r3505 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3505_capa_status_board() from public, anon;
grant execute on function public.founder_r3505_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3505_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cash_flow_statement_capa_actions_r3505)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cash_flow_statement_capa_actions_r3505 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3505_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3505_root_cause_pareto() to authenticated;

-- 7) Net-flow impact digest (by flow status)
create or replace function public.founder_r3505_net_flow_impact_digest()
returns table(
  flow_status text,
  line_items bigint,
  total_inflow_rupees numeric,
  total_outflow_rupees numeric,
  total_net_rupees numeric,
  total_variance_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.flow_status,
    count(*)::bigint,
    coalesce(sum(l.inflow_rupees),0)::numeric,
    coalesce(sum(l.outflow_rupees),0)::numeric,
    coalesce(sum(l.net_flow_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric
  from public.cash_flow_statement_r3505 l
  group by l.flow_status
  order by coalesce(sum(l.variance_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3505_net_flow_impact_digest() from public, anon;
grant execute on function public.founder_r3505_net_flow_impact_digest() to authenticated;

-- 8) High-risk queue (critical / unfavorable / worsening)
create or replace function public.founder_r3505_high_risk_queue()
returns table(
  line_item text,
  period_month date,
  activity_type text,
  flow_status text,
  trend_dir text,
  inflow_rupees numeric,
  outflow_rupees numeric,
  net_flow_rupees numeric,
  budget_net_rupees numeric,
  variance_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.line_item, l.period_month, l.activity_type, l.flow_status, l.trend_dir,
    l.inflow_rupees, l.outflow_rupees, l.net_flow_rupees, l.budget_net_rupees, l.variance_rupees, l.notes
  from public.cash_flow_statement_r3505 l
  where l.flow_status in ('unfavorable','critical')
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.variance_rupees asc;
end;
$$;

revoke execute on function public.founder_r3505_high_risk_queue() from public, anon;
grant execute on function public.founder_r3505_high_risk_queue() to authenticated;
