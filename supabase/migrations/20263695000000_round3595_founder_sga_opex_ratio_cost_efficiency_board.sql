-- Round 3595: Founder SG&A / Opex-Ratio Cost-Efficiency Board
-- SG&A + operating-expense ratio and cost efficiency per business unit × month ×
-- revenue × SG&A ratio vs target × selling/admin split × opex ratio × efficiency status × trend × CAPA

-- =============================================================================
-- TABLE 1: sga_opex_ratio_r3595 — per business-unit monthly SG&A / opex ratio
-- =============================================================================
create table if not exists public.sga_opex_ratio_r3595 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_code text not null,
  business_unit text not null,
  period_month date not null,
  revenue_rupees numeric(14,2) not null,
  sga_expense_rupees numeric(14,2) not null,
  sga_ratio_pct numeric(6,2) not null,
  target_sga_ratio_pct numeric(6,2) not null,
  selling_expense_rupees numeric(14,2) not null,
  admin_expense_rupees numeric(14,2) not null,
  opex_total_rupees numeric(14,2) not null,
  opex_ratio_pct numeric(6,2) not null,
  efficiency_status text not null check (efficiency_status in (
    'lean','on_target','elevated','bloated'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sga_opex_ratio_r3595 enable row level security;

create index if not exists idx_sga_opex_ratio_r3595_org on public.sga_opex_ratio_r3595(organization_id);
create index if not exists idx_sga_opex_ratio_r3595_month on public.sga_opex_ratio_r3595(period_month);
create index if not exists idx_sga_opex_ratio_r3595_status on public.sga_opex_ratio_r3595(efficiency_status);

-- =============================================================================
-- TABLE 2: sga_opex_ratio_capa_actions_r3595 — cost-efficiency CAPA actions
-- =============================================================================
create table if not exists public.sga_opex_ratio_capa_actions_r3595 (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.sga_opex_ratio_r3595(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sga_over_budget','high_opex_ratio','admin_overhead_high','selling_cost_spike',
    'margin_erosion','productivity_shortfall'
  )),
  root_cause text not null check (root_cause in (
    'excess_gtm_spend','headcount_overrun','low_asset_utilization','warehouse_cost_creep',
    'vendor_price_increase','process_inefficiency','revenue_shortfall','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rightsize_fleet','rebalance_marketing_spend','freeze_discretionary_hiring',
    'renegotiate_vendor_contracts','improve_fleet_scheduling','automate_admin_process','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact_rupees numeric(14,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sga_opex_ratio_capa_actions_r3595 enable row level security;

create index if not exists idx_sga_opex_capa_r3595_entry on public.sga_opex_ratio_capa_actions_r3595(entry_id);
create index if not exists idx_sga_opex_capa_r3595_status on public.sga_opex_ratio_capa_actions_r3595(capa_status);

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

  -- 16 business-unit monthly SG&A / opex rows
  insert into public.sga_opex_ratio_r3595 (
    organization_id, entry_code, business_unit, period_month,
    revenue_rupees, sga_expense_rupees, sga_ratio_pct, target_sga_ratio_pct,
    selling_expense_rupees, admin_expense_rupees, opex_total_rupees, opex_ratio_pct,
    efficiency_status, trend_dir, notes
  )
  select v_org_id, q.ecode, q.bu, q.pm::date,
    q.rev, q.sga, q.sgapct, q.tgt,
    q.sell, q.adm, q.opex, q.opexpct,
    q.eff, q.trend, q.nt
  from (values
    ('DGX-2601','Diagnostics Sales','2026-01-01',
     24000000,3120000,13.0,14.0,1440000,1680000,4560000,19.0,'lean','improving','Diagnostics SG&A below target on strong order book'),
    ('DGX-2604','Diagnostics Sales','2026-04-01',
     26500000,3445000,13.0,14.0,1590000,1855000,4770000,18.0,'lean','improving','Sustained lean SG&A ratio through Q2'),
    ('AMC-2601','AMC Services','2026-01-01',
     18000000,2700000,15.0,15.0,900000,1800000,3600000,20.0,'on_target','stable','AMC SG&A holding at target band'),
    ('AMC-2604','AMC Services','2026-04-01',
     19500000,3120000,16.0,15.0,975000,2145000,4095000,21.0,'elevated','worsening','Admin overhead crept up on new field hires'),
    ('SPR-2602','Spare Parts','2026-02-01',
     9500000,1425000,15.0,16.0,665000,760000,1900000,20.0,'on_target','improving','Spare parts SG&A within target band'),
    ('SPR-2605','Spare Parts','2026-05-01',
     8800000,1584000,18.0,16.0,704000,880000,2112000,24.0,'elevated','worsening','Warehouse admin cost creep pushed ratio up'),
    ('RNT-2603','Rental Fleet','2026-03-01',
     6200000,1240000,20.0,17.0,496000,744000,1798000,29.0,'bloated','worsening','Rental fleet SG&A bloated on low utilization'),
    ('RNT-2606','Rental Fleet','2026-06-01',
     6800000,1224000,18.0,17.0,544000,680000,1768000,26.0,'elevated','improving','Utilization recovering but ratio still above target'),
    ('FLD-2602','Field Service','2026-02-01',
     14200000,1988000,14.0,15.0,710000,1278000,3053000,21.5,'lean','stable','Field service SG&A efficient vs target'),
    ('FLD-2605','Field Service','2026-05-01',
     15100000,2265000,15.0,15.0,755000,1510000,3322000,22.0,'on_target','stable','Field service holding target ratio'),
    ('MKT-2601','Marketplace','2026-01-01',
     4200000,1050000,25.0,18.0,630000,420000,1470000,35.0,'bloated','worsening','Marketplace early-stage SG&A heavy on GTM spend'),
    ('MKT-2604','Marketplace','2026-04-01',
     5600000,1176000,21.0,18.0,728000,448000,1624000,29.0,'elevated','improving','GTM leverage improving as GMV scales'),
    ('CNS-2603','Consumables','2026-03-01',
     11200000,1568000,14.0,15.0,784000,784000,2464000,22.0,'lean','improving','Recurring consumables revenue keeps SG&A lean'),
    ('CNS-2606','Consumables','2026-06-01',
     12000000,1800000,15.0,15.0,840000,960000,2640000,22.0,'on_target','stable','Consumables at target ratio'),
    ('AMC-2606','AMC Services','2026-06-01',
     20500000,3690000,18.0,15.0,1025000,2665000,4715000,23.0,'bloated','worsening','AMC admin overrun — cost action required'),
    ('RNT-2602','Rental Fleet','2026-02-01',
     5900000,1298000,22.0,17.0,472000,826000,1770000,30.0,'bloated','stable','Rental fleet persistently bloated SG&A ratio')
  ) as q(ecode, bu, pm, rev, sga, sgapct, tgt, sell, adm, opex, opexpct, eff, trend, nt);

  -- CAPA seed — attach to specific entries via entry_code
  insert into public.sga_opex_ratio_capa_actions_r3595 (
    entry_id, finding_category, root_cause, corrective_action,
    capa_status, cost_impact_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RNT-2603','high_opex_ratio','low_asset_utilization','rightsize_fleet','in_progress',350000,'COO Office','2026-05-15',null,'Idle rental units flagged for redeployment or disposal'),
    ('MKT-2601','sga_over_budget','excess_gtm_spend','rebalance_marketing_spend','in_progress',500000,'Growth Lead','2026-04-30',null,'Shift spend from paid acquisition to referral loops'),
    ('AMC-2606','admin_overhead_high','headcount_overrun','freeze_discretionary_hiring','open',800000,'AMC Head','2026-08-15',null,'Admin headcount review; freeze non-critical backfills'),
    ('RNT-2602','high_opex_ratio','low_asset_utilization','rightsize_fleet','escalated',300000,'COO Office','2026-04-15',null,'Persistent bloat escalated to board finance committee'),
    ('SPR-2605','admin_overhead_high','warehouse_cost_creep','renegotiate_vendor_contracts','closed',120000,'Ops Manager','2026-06-10','2026-06-08','Renegotiated 3PL storage rates; ratio normalising'),
    ('AMC-2604','sga_over_budget','headcount_overrun','freeze_discretionary_hiring','verification_pending',220000,'AMC Head','2026-06-30',null,'Hiring paused; awaiting next-month ratio confirmation'),
    ('RNT-2606','high_opex_ratio','low_asset_utilization','improve_fleet_scheduling','closed',90000,'Fleet Manager','2026-07-05','2026-07-02','Scheduling optimiser lifted utilization above threshold'),
    ('MKT-2604','sga_over_budget','excess_gtm_spend','rebalance_marketing_spend','overdue',260000,'Growth Lead','2026-06-15',null,'Rebalance action past due — CAC still above plan')
  ) as q(ecode, fc, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.sga_opex_ratio_r3595 e
    on e.organization_id = v_org_id and e.entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Efficiency-status distribution
create or replace function public.founder_r3595_efficiency_status_rollup()
returns table(efficiency_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sga_opex_ratio_r3595)
  select l.efficiency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.sga_opex_ratio_r3595 l
  group by l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3595_efficiency_status_rollup() from public, anon;
grant execute on function public.founder_r3595_efficiency_status_rollup() to authenticated;

-- 2) Business-unit cost-efficiency scorecard
create or replace function public.founder_r3595_business_unit_scorecard()
returns table(
  business_unit text,
  entries bigint,
  avg_sga_ratio_pct numeric,
  avg_target_sga_ratio_pct numeric,
  avg_opex_ratio_pct numeric,
  total_revenue_rupees numeric,
  total_sga_rupees numeric,
  bloated_or_elevated bigint
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
    round(avg(l.sga_ratio_pct), 1),
    round(avg(l.target_sga_ratio_pct), 1),
    round(avg(l.opex_ratio_pct), 1),
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.sga_expense_rupees),0)::numeric,
    count(*) filter (where l.efficiency_status in ('elevated','bloated'))::bigint
  from public.sga_opex_ratio_r3595 l
  group by l.business_unit
  order by round(avg(l.sga_ratio_pct), 1) desc;
end;
$$;

revoke execute on function public.founder_r3595_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3595_business_unit_scorecard() to authenticated;

-- 3) Business-unit × efficiency-status matrix
create or replace function public.founder_r3595_unit_efficiency_matrix()
returns table(business_unit text, efficiency_status text, entries bigint, avg_sga_ratio_pct numeric, avg_opex_ratio_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.efficiency_status, count(*)::bigint,
    round(avg(l.sga_ratio_pct), 1),
    round(avg(l.opex_ratio_pct), 1)
  from public.sga_opex_ratio_r3595 l
  group by l.business_unit, l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3595_unit_efficiency_matrix() from public, anon;
grant execute on function public.founder_r3595_unit_efficiency_matrix() to authenticated;

-- 4) Monthly SG&A / opex ratio trend
create or replace function public.founder_r3595_monthly_sga_ratio_trend()
returns table(period_month date, entries bigint, avg_sga_ratio_pct numeric, avg_opex_ratio_pct numeric, elevated_or_bloated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.sga_ratio_pct), 1),
    round(avg(l.opex_ratio_pct), 1),
    count(*) filter (where l.efficiency_status in ('elevated','bloated'))::bigint
  from public.sga_opex_ratio_r3595 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3595_monthly_sga_ratio_trend() from public, anon;
grant execute on function public.founder_r3595_monthly_sga_ratio_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3595_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, escalated_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cost_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.sga_opex_ratio_capa_actions_r3595 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3595_capa_status_board() from public, anon;
grant execute on function public.founder_r3595_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3595_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sga_opex_ratio_capa_actions_r3595)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.sga_opex_ratio_capa_actions_r3595 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3595_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3595_root_cause_pareto() to authenticated;

-- 7) Cost-impact digest by finding category
create or replace function public.founder_r3595_cost_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric
  from public.sga_opex_ratio_capa_actions_r3595 c
  group by c.finding_category
  order by coalesce(sum(c.cost_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3595_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3595_cost_impact_digest() to authenticated;

-- 8) High-risk (bloated / elevated) cost-efficiency queue
create or replace function public.founder_r3595_high_risk_queue()
returns table(
  business_unit text,
  entry_code text,
  period_month date,
  revenue_rupees numeric,
  sga_ratio_pct numeric,
  target_sga_ratio_pct numeric,
  opex_ratio_pct numeric,
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
  select l.business_unit, l.entry_code, l.period_month, l.revenue_rupees,
    l.sga_ratio_pct, l.target_sga_ratio_pct, l.opex_ratio_pct,
    l.efficiency_status, l.trend_dir, l.notes
  from public.sga_opex_ratio_r3595 l
  where l.efficiency_status in ('elevated','bloated')
     or l.sga_ratio_pct > l.target_sga_ratio_pct
     or l.trend_dir = 'worsening'
  order by l.sga_ratio_pct desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3595_high_risk_queue() from public, anon;
grant execute on function public.founder_r3595_high_risk_queue() to authenticated;
