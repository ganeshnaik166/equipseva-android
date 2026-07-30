-- Round 3598: Founder Customer-Account Profitability P&L / Margin Board
-- Founder per-customer/account profitability P&L — segment × period × revenue × COGS × gross margin × cost-to-serve × allocated overhead × net contribution × contribution margin × profitability status × trend × CAPA

-- =============================================================================
-- TABLE 1: cust_profit_r3598 — per-account monthly profitability P&L fact table
-- =============================================================================
create table if not exists public.cust_profit_r3598 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  account_code text not null,
  customer_name text not null,
  segment text not null check (segment in (
    'amc_services','spare_parts','projects','diagnostics','rentals'
  )),
  period_month date not null,
  revenue_rupees numeric(14,2) not null,
  cogs_rupees numeric(14,2) not null,
  gross_margin_rupees numeric(14,2) not null,
  gross_margin_pct numeric(6,2) not null,
  service_cost_rupees numeric(14,2) not null,
  allocated_overhead_rupees numeric(14,2) not null,
  net_contribution_rupees numeric(14,2) not null,
  contribution_margin_pct numeric(6,2) not null,
  cost_to_serve_rupees numeric(14,2) not null,
  profitability_status text not null check (profitability_status in (
    'star','core','marginal','loss_making'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cust_profit_r3598 enable row level security;

create index if not exists idx_cust_profit_r3598_org on public.cust_profit_r3598(organization_id);
create index if not exists idx_cust_profit_r3598_period on public.cust_profit_r3598(period_month);
create index if not exists idx_cust_profit_r3598_status on public.cust_profit_r3598(profitability_status);

-- =============================================================================
-- TABLE 2: cust_profit_capa_actions_r3598 — margin-recovery CAPA & actions
-- =============================================================================
create table if not exists public.cust_profit_capa_actions_r3598 (
  id uuid primary key default gen_random_uuid(),
  profit_log_id uuid not null references public.cust_profit_r3598(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'high_service_cost','deep_discounting','sla_penalties','low_amc_renewal',
    'freight_logistics_cost','excess_spare_consumption','overhead_allocation',
    'payment_delay_finance_cost','scope_creep','low_asset_utilization'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_contract','renegotiate_amc','reduce_visit_frequency','optimize_spare_usage',
    'consolidate_logistics','enforce_sla_credits','shift_to_remote_support',
    'exit_unprofitable_account','upsell_higher_tier','tighten_payment_terms',
    'redeploy_idle_assets','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_category text not null check (impact_category in (
    'revenue_uplift','cost_reduction','overhead_reallocation','contract_exit','risk_mitigation'
  )),
  margin_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cust_profit_capa_actions_r3598 enable row level security;

create index if not exists idx_cust_profit_capa_r3598_log on public.cust_profit_capa_actions_r3598(profit_log_id);
create index if not exists idx_cust_profit_capa_r3598_status on public.cust_profit_capa_actions_r3598(capa_status);

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

  -- 16 account-month P&L rows
  insert into public.cust_profit_r3598 (
    organization_id, account_code, customer_name, segment, period_month,
    revenue_rupees, cogs_rupees, gross_margin_rupees, gross_margin_pct,
    service_cost_rupees, allocated_overhead_rupees, net_contribution_rupees,
    contribution_margin_pct, cost_to_serve_rupees, profitability_status, trend_dir, notes
  )
  select v_org_id, q.acode, q.cust, q.seg, q.pmon::date,
    q.rev, q.cogs, q.gm, q.gmpct,
    q.svc, q.ovh, q.netc,
    q.cmpct, q.cts, q.pstat, q.trnd, q.nt
  from (values
    ('ACC-APOLLO-AMC','Apollo Hospitals Chennai','amc_services','2026-07-01',
     1800000,720000,1080000,60.00,240000,180000,660000,36.67,420000,'star','improving','Comprehensive AMC portfolio — high renewal rate, low callout frequency'),
    ('ACC-FORTIS-AMC','Fortis Gurgaon','amc_services','2026-07-01',
     1200000,540000,660000,55.00,300000,150000,210000,17.50,450000,'core','stable','Steady AMC account; service cost elevated by frequent on-site visits'),
    ('ACC-MANIPAL-SPR','Manipal Bengaluru','spare_parts','2026-07-01',
     950000,665000,285000,30.00,90000,95000,100000,10.53,185000,'core','improving','Spare-parts pull-through improving as install base grows'),
    ('ACC-AIIMS-PRJ','AIIMS Delhi','projects','2026-06-01',
     5400000,4320000,1080000,20.00,300000,540000,240000,4.44,840000,'marginal','worsening','Turnkey project margin compressed by scope creep and overhead load'),
    ('ACC-CMC-DIAG','CMC Vellore','diagnostics','2026-06-01',
     2200000,1320000,880000,40.00,260000,220000,400000,18.18,480000,'core','stable','Diagnostics reagent + service bundle performing to plan'),
    ('ACC-KIMS-RENT','KIMS Hyderabad','rentals','2026-07-01',
     780000,546000,234000,30.00,180000,78000,-24000,-3.08,258000,'loss_making','worsening','Rental fleet under-utilised; idle asset carrying cost erodes contribution'),
    ('ACC-YASHODA-AMC','Yashoda Hyderabad','amc_services','2026-06-01',
     1050000,472500,577500,55.00,210000,131250,236250,22.50,341250,'core','improving','AMC uplift after preventive-maintenance discipline tightened'),
    ('ACC-KOKILABEN-PRJ','Kokilaben Mumbai','projects','2026-05-01',
     6800000,5780000,1020000,15.00,340000,680000,0,0.00,1020000,'marginal','worsening','Large project at breakeven contribution — overhead allocation heavy'),
    ('ACC-NARAYANA-DIAG','Narayana Bengaluru','diagnostics','2026-05-01',
     1900000,1140000,760000,40.00,220000,190000,350000,18.42,410000,'core','stable','Diagnostics account stable; reagent mix healthy'),
    ('ACC-MEDANTA-AMC','Medanta Gurgaon','amc_services','2026-07-01',
     2400000,840000,1560000,65.00,300000,240000,1020000,42.50,540000,'star','improving','Premium comprehensive AMC — best-in-class contribution margin'),
    ('ACC-MAX-SPR','Max Delhi','spare_parts','2026-06-01',
     620000,496000,124000,20.00,80000,62000,-18000,-2.90,142000,'loss_making','worsening','Deep discounting on spares eroded gross margin below cost-to-serve'),
    ('ACC-ASTER-RENT','Aster Kochi','rentals','2026-06-01',
     900000,585000,315000,35.00,150000,90000,75000,8.33,240000,'marginal','stable','Rental account thin contribution; freight and repositioning cost high'),
    ('ACC-RAINBOW-DIAG','Rainbow Hyderabad','diagnostics','2026-07-01',
     1350000,810000,540000,40.00,200000,135000,205000,15.19,335000,'core','improving','Paediatric diagnostics bundle ramping; contribution improving'),
    ('ACC-SHANKARA-PRJ','Shankara Nethralaya Chennai','projects','2026-04-01',
     4200000,3150000,1050000,25.00,250000,420000,380000,9.05,670000,'marginal','stable','Ophthalmology project; service cost recoverable via AMC attach'),
    ('ACC-LILAVATI-AMC','Lilavati Mumbai','amc_services','2026-05-01',
     1600000,640000,960000,60.00,320000,160000,480000,30.00,480000,'star','stable','High-margin AMC with strong renewal and low escalation rate'),
    ('ACC-COLUMBIA-RENT','Columbia Asia Bengaluru','rentals','2026-04-01',
     700000,490000,210000,30.00,170000,70000,-30000,-4.29,240000,'loss_making','worsening','Rental contract loss-making; recommend exit or reprice at renewal')
  ) as q(acode, cust, seg, pmon, rev, cogs, gm, gmpct, svc, ovh, netc, cmpct, cts, pstat, trnd, nt);

  -- CAPA seed — attach to specific accounts via account_code
  insert into public.cust_profit_capa_actions_r3598 (
    profit_log_id, root_cause, corrective_action, capa_status, impact_category,
    margin_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ic,
    q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('ACC-AIIMS-PRJ','scope_creep','reprice_contract','in_progress','revenue_uplift',260000,'Key Accounts - Delhi','2026-08-15',null,'Change orders formalised; reprice to recover scope-creep effort'),
    ('ACC-KIMS-RENT','low_asset_utilization','redeploy_idle_assets','open','cost_reduction',180000,'Rentals Ops - South','2026-08-10',null,'Redeploy idle units to higher-demand sites to lift utilisation'),
    ('ACC-MAX-SPR','deep_discounting','reprice_contract','escalated','revenue_uplift',140000,'Sales - North','2026-08-05',null,'Discount slab breached floor margin — escalate for price correction'),
    ('ACC-KOKILABEN-PRJ','overhead_allocation','renegotiate_amc','verification_pending','overhead_reallocation',320000,'Projects - West','2026-08-20',null,'Attach post-project AMC to absorb allocated overhead going forward'),
    ('ACC-COLUMBIA-RENT','low_asset_utilization','exit_unprofitable_account','closed','contract_exit',30000,'Rentals Ops - South','2026-06-30','2026-06-25','Loss-making rental exited at renewal; assets recovered'),
    ('ACC-ASTER-RENT','freight_logistics_cost','consolidate_logistics','open','cost_reduction',90000,'Logistics - South','2026-08-12',null,'Consolidate reposition trips with regional milk-run to cut freight'),
    ('ACC-SHANKARA-PRJ','high_service_cost','shift_to_remote_support','overdue','cost_reduction',210000,'Service - South','2026-07-15',null,'Shift L1 triage to remote support; target date missed, expedite'),
    ('ACC-FORTIS-AMC','high_service_cost','reduce_visit_frequency','in_progress','cost_reduction',120000,'Service - North','2026-08-18',null,'Right-size PM visit cadence to contract SLA, not over-service')
  ) as q(acode, rc, ca, cst, ic, imp, ownr, tcd, acd, nt)
  join public.cust_profit_r3598 e
    on e.organization_id = v_org_id and e.account_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Profitability status distribution
create or replace function public.founder_r3598_profitability_status_rollup()
returns table(profitability_status text, accounts bigint, total_revenue_rupees numeric, total_net_contribution_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cust_profit_r3598)
  select l.profitability_status,
         count(*)::bigint,
         coalesce(sum(l.revenue_rupees),0)::numeric,
         coalesce(sum(l.net_contribution_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cust_profit_r3598 l
  group by l.profitability_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3598_profitability_status_rollup() from public, anon;
grant execute on function public.founder_r3598_profitability_status_rollup() to authenticated;

-- 2) Segment scorecard
create or replace function public.founder_r3598_segment_scorecard()
returns table(
  segment text,
  accounts bigint,
  total_revenue_rupees numeric,
  total_cogs_rupees numeric,
  total_net_contribution_rupees numeric,
  avg_gross_margin_pct numeric,
  avg_contribution_margin_pct numeric,
  loss_making bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.segment,
    count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.cogs_rupees),0)::numeric,
    coalesce(sum(l.net_contribution_rupees),0)::numeric,
    round(avg(l.gross_margin_pct), 2),
    round(avg(l.contribution_margin_pct), 2),
    count(*) filter (where l.profitability_status = 'loss_making')::bigint
  from public.cust_profit_r3598 l
  group by l.segment
  order by coalesce(sum(l.net_contribution_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3598_segment_scorecard() from public, anon;
grant execute on function public.founder_r3598_segment_scorecard() to authenticated;

-- 3) Segment × profitability-status matrix
create or replace function public.founder_r3598_segment_status_matrix()
returns table(segment text, profitability_status text, accounts bigint, total_net_contribution_rupees numeric, avg_contribution_margin_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.segment, l.profitability_status,
    count(*)::bigint,
    coalesce(sum(l.net_contribution_rupees),0)::numeric,
    round(avg(l.contribution_margin_pct), 2)
  from public.cust_profit_r3598 l
  group by l.segment, l.profitability_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3598_segment_status_matrix() from public, anon;
grant execute on function public.founder_r3598_segment_status_matrix() to authenticated;

-- 4) Monthly contribution trend
create or replace function public.founder_r3598_monthly_contribution_trend()
returns table(period_month date, accounts bigint, total_revenue_rupees numeric, total_net_contribution_rupees numeric, avg_contribution_margin_pct numeric, loss_making bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.net_contribution_rupees),0)::numeric,
    round(avg(l.contribution_margin_pct), 2),
    count(*) filter (where l.profitability_status = 'loss_making')::bigint
  from public.cust_profit_r3598 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3598_monthly_contribution_trend() from public, anon;
grant execute on function public.founder_r3598_monthly_contribution_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3598_capa_status_board()
returns table(capa_status text, findings bigint, total_margin_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cust_profit_capa_actions_r3598 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3598_capa_status_board() from public, anon;
grant execute on function public.founder_r3598_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3598_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_margin_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cust_profit_capa_actions_r3598)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cust_profit_capa_actions_r3598 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3598_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3598_root_cause_pareto() to authenticated;

-- 7) Margin-impact digest
create or replace function public.founder_r3598_margin_impact_digest()
returns table(impact_category text, findings bigint, open_findings bigint, total_margin_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric
  from public.cust_profit_capa_actions_r3598 c
  group by c.impact_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3598_margin_impact_digest() from public, anon;
grant execute on function public.founder_r3598_margin_impact_digest() to authenticated;

-- 8) High-risk (loss_making / marginal) account queue
create or replace function public.founder_r3598_high_risk_queue()
returns table(
  customer_name text,
  account_code text,
  segment text,
  period_month date,
  profitability_status text,
  gross_margin_pct numeric,
  contribution_margin_pct numeric,
  net_contribution_rupees numeric,
  cost_to_serve_rupees numeric,
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
  select l.customer_name, l.account_code, l.segment, l.period_month,
    l.profitability_status, l.gross_margin_pct, l.contribution_margin_pct,
    l.net_contribution_rupees, l.cost_to_serve_rupees, l.trend_dir, l.notes
  from public.cust_profit_r3598 l
  where l.profitability_status in ('loss_making','marginal')
     or l.net_contribution_rupees < 0
     or l.contribution_margin_pct < 5
     or l.trend_dir = 'worsening'
  order by l.net_contribution_rupees asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3598_high_risk_queue() from public, anon;
grant execute on function public.founder_r3598_high_risk_queue() to authenticated;
