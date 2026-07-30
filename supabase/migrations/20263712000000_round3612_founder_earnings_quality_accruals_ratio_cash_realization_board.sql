-- Round 3612: Founder Earnings-Quality, Accruals-Ratio & Cash-Realization Board
-- Earnings-quality log — business unit × period × net profit × operating cash flow × accruals × accruals-ratio × cash-realization × non-recurring items × provisions × one-time gains × quality verdict × CAPA

-- =============================================================================
-- TABLE 1: earnings_quality_r3612 — per-business-unit monthly earnings-quality facts
-- =============================================================================
create table if not exists public.earnings_quality_r3612 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_code text not null,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals',
    'consumables','turnkey_installations','refurbished_equipment'
  )),
  period_month date not null,
  net_profit_rupees numeric(14,2) not null,
  operating_cash_flow_rupees numeric(14,2) not null,
  accruals_rupees numeric(14,2),
  accruals_ratio_pct numeric(6,2),
  cash_realization_pct numeric(6,2),
  non_recurring_items_rupees numeric(14,2),
  provision_charge_rupees numeric(14,2),
  one_time_gains_rupees numeric(14,2),
  quality_status text not null check (quality_status in (
    'high_quality','sound','watch','aggressive','red_flag'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.earnings_quality_r3612 enable row level security;

create index if not exists idx_earnings_quality_r3612_org on public.earnings_quality_r3612(organization_id);
create index if not exists idx_earnings_quality_r3612_period on public.earnings_quality_r3612(period_month);
create index if not exists idx_earnings_quality_r3612_status on public.earnings_quality_r3612(quality_status);

-- =============================================================================
-- TABLE 2: earnings_quality_capa_actions_r3612 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.earnings_quality_capa_actions_r3612 (
  id uuid primary key default gen_random_uuid(),
  eq_id uuid not null references public.earnings_quality_r3612(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'high_accruals_ratio','low_cash_realization','one_time_gain_reliance','under_provisioning',
    'revenue_recognition_aggressive','receivables_buildup','inventory_overstatement',
    'deferred_cost_capitalization','channel_stuffing','provision_reversal_spike'
  )),
  root_cause text not null check (root_cause in (
    'aggressive_revenue_recognition','delayed_collections','inventory_overvaluation',
    'under_provisioned_receivables','capitalized_operating_costs','one_time_asset_sale_booked_operating',
    'channel_stuffing_quarter_end','deferred_expense_recognition','manual_accrual_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'tighten_revenue_recognition_policy','accelerate_collections','revalue_inventory',
    'increase_provision_coverage','expense_capitalized_costs','reclassify_one_time_items',
    'restate_prior_period','strengthen_accrual_review','implement_cutoff_controls','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.earnings_quality_capa_actions_r3612 enable row level security;

create index if not exists idx_eq_capa_r3612_eq on public.earnings_quality_capa_actions_r3612(eq_id);
create index if not exists idx_eq_capa_r3612_status on public.earnings_quality_capa_actions_r3612(capa_status);

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

  -- 16 earnings-quality rows
  insert into public.earnings_quality_r3612 (
    organization_id, entry_code, business_unit, period_month,
    net_profit_rupees, operating_cash_flow_rupees, accruals_rupees, accruals_ratio_pct,
    cash_realization_pct, non_recurring_items_rupees, provision_charge_rupees, one_time_gains_rupees,
    quality_status, trend_dir, notes
  )
  select v_org_id, q.ecode, q.bu, q.pm::date,
    q.np, q.ocf, q.acc, q.arp,
    q.crp, q.nri, q.prov, q.otg,
    q.qs, q.td, q.nt
  from (values
    ('EQ-AMC-2026-06','amc_services','2026-06-01',
     4200000,3990000,210000,5.00,95.00,0,120000,0,'high_quality','improving','AMC annuity book — strong cash conversion, minimal accruals'),
    ('EQ-SP-2026-06','spare_parts','2026-06-01',
     2800000,2380000,420000,15.00,85.00,50000,180000,0,'sound','stable','Spare parts margin healthy; minor receivables lag'),
    ('EQ-PRJ-2026-06','projects','2026-06-01',
     6500000,3250000,3250000,50.00,50.00,800000,250000,1200000,'aggressive','worsening','Turnkey project revenue booked ahead of milestone billing'),
    ('EQ-DIAG-2026-06','diagnostics','2026-06-01',
     1900000,1729000,171000,9.00,91.00,0,90000,0,'high_quality','stable','Diagnostics reagents subscription — clean accruals'),
    ('EQ-RENT-2026-06','rentals','2026-06-01',
     1500000,1275000,225000,15.00,85.00,0,60000,0,'sound','improving','Equipment rental fleet utilization up, deposits timely'),
    ('EQ-TKI-2026-06','turnkey_installations','2026-06-01',
     3800000,1140000,2660000,70.00,30.00,1500000,200000,900000,'red_flag','worsening','Modular OT install — heavy unbilled revenue and one-time gains'),
    ('EQ-CONS-2026-06','consumables','2026-06-01',
     2200000,1980000,220000,10.00,90.00,0,110000,0,'high_quality','stable','Consumables reorder cycle steady, clean conversion'),
    ('EQ-REF-2026-06','refurbished_equipment','2026-06-01',
     1200000,720000,480000,40.00,60.00,300000,150000,350000,'watch','worsening','Refurb resale margins propped by one-time asset sale'),
    ('EQ-AMC-2026-05','amc_services','2026-05-01',
     4000000,3720000,280000,7.00,93.00,0,110000,0,'high_quality','stable','May AMC book steady, high cash realization'),
    ('EQ-SP-2026-05','spare_parts','2026-05-01',
     2600000,2054000,546000,21.00,79.00,40000,160000,0,'watch','worsening','Spares receivables stretched at quarter-end'),
    ('EQ-PRJ-2026-05','projects','2026-05-01',
     5800000,3480000,2320000,40.00,60.00,600000,220000,700000,'aggressive','worsening','Project percentage-completion running ahead of collections'),
    ('EQ-DIAG-2026-05','diagnostics','2026-05-01',
     1800000,1656000,144000,8.00,92.00,0,85000,0,'high_quality','improving','Diagnostics cash conversion improving month-on-month'),
    ('EQ-RENT-2026-05','rentals','2026-05-01',
     1400000,1148000,252000,18.00,82.00,0,55000,0,'sound','stable','Rental deposits timing normal, fleet steady'),
    ('EQ-TKI-2026-05','turnkey_installations','2026-05-01',
     3500000,1400000,2100000,60.00,40.00,1000000,180000,600000,'red_flag','worsening','Install milestones slipping; revenue front-loaded'),
    ('EQ-CONS-2026-05','consumables','2026-05-01',
     2100000,1848000,252000,12.00,88.00,0,100000,0,'sound','stable','Consumables stable, mild accrual buildup'),
    ('EQ-REF-2026-05','refurbished_equipment','2026-05-01',
     1000000,450000,550000,55.00,45.00,250000,140000,400000,'red_flag','worsening','Refurb book heavily reliant on one-time gains; under-provisioned')
  ) as q(ecode, bu, pm, np, ocf, acc, arp, crp, nri, prov, otg, qs, td, nt);

  -- CAPA seed — attach to specific entries by entry_code
  insert into public.earnings_quality_capa_actions_r3612 (
    eq_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EQ-PRJ-2026-06','revenue_recognition_aggressive','aggressive_revenue_recognition','tighten_revenue_recognition_policy',
     'in_progress',3250000.00,'CFO Office','2026-08-15',null,'Milestone billing to be re-cut to match percentage-of-completion'),
    ('EQ-TKI-2026-06','low_cash_realization','delayed_collections','accelerate_collections',
     'escalated',2660000.00,'Projects Controller','2026-08-10',null,'Unbilled revenue on OT install; collection plan escalated to board'),
    ('EQ-REF-2026-06','one_time_gain_reliance','one_time_asset_sale_booked_operating','reclassify_one_time_items',
     'open',350000.00,'Financial Reporting','2026-08-20',null,'One-time asset sale to be reclassified below the operating line'),
    ('EQ-SP-2026-05','receivables_buildup','delayed_collections','accelerate_collections',
     'verification_pending',546000.00,'Regional Finance','2026-07-31',null,'Spares AR aging beyond 90 days; collection drive underway'),
    ('EQ-PRJ-2026-05','revenue_recognition_aggressive','channel_stuffing_quarter_end','implement_cutoff_controls',
     'closed',2320000.00,'Internal Audit','2026-07-10','2026-07-08','Quarter-end cutoff controls implemented and verified'),
    ('EQ-TKI-2026-05','under_provisioning','under_provisioned_receivables','increase_provision_coverage',
     'overdue',2100000.00,'CFO Office','2026-06-30',null,'ECL provision top-up on install receivables past due'),
    ('EQ-REF-2026-05','under_provisioning','inventory_overvaluation','revalue_inventory',
     'escalated',550000.00,'Inventory Controller','2026-07-25',null,'Refurb inventory NRV review; write-down likely'),
    ('EQ-SP-2026-06','high_accruals_ratio','manual_accrual_error','strengthen_accrual_review',
     'open',180000.00,'Finance Ops','2026-08-05',null,'Manual accrual entries to be reviewed on a monthly cadence')
  ) as q(ecode, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.earnings_quality_r3612 e
    on e.organization_id = v_org_id and e.entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Earnings-quality status distribution
create or replace function public.founder_r3612_quality_status_rollup()
returns table(quality_status text, entries bigint, total_net_profit_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.earnings_quality_r3612)
  select e.quality_status, count(*)::bigint,
         coalesce(sum(e.net_profit_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.earnings_quality_r3612 e
  group by e.quality_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3612_quality_status_rollup() from public, anon;
grant execute on function public.founder_r3612_quality_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3612_business_unit_scorecard()
returns table(
  business_unit text,
  months bigint,
  total_net_profit_rupees numeric,
  total_ocf_rupees numeric,
  avg_accruals_ratio_pct numeric,
  avg_cash_realization_pct numeric,
  red_flag_months bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.business_unit,
    count(*)::bigint,
    coalesce(sum(e.net_profit_rupees),0)::numeric,
    coalesce(sum(e.operating_cash_flow_rupees),0)::numeric,
    round(avg(e.accruals_ratio_pct), 2),
    round(avg(e.cash_realization_pct), 2),
    count(*) filter (where e.quality_status in ('aggressive','red_flag'))::bigint
  from public.earnings_quality_r3612 e
  group by e.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3612_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3612_business_unit_scorecard() to authenticated;

-- 3) Business-unit × quality-status matrix
create or replace function public.founder_r3612_unit_quality_matrix()
returns table(business_unit text, quality_status text, entries bigint, avg_accruals_ratio_pct numeric, avg_cash_realization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.business_unit, e.quality_status, count(*)::bigint,
    round(avg(e.accruals_ratio_pct), 2),
    round(avg(e.cash_realization_pct), 2)
  from public.earnings_quality_r3612 e
  group by e.business_unit, e.quality_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3612_unit_quality_matrix() from public, anon;
grant execute on function public.founder_r3612_unit_quality_matrix() to authenticated;

-- 4) Monthly earnings-quality trend
create or replace function public.founder_r3612_monthly_quality_trend()
returns table(
  period_month date,
  entries bigint,
  total_net_profit_rupees numeric,
  total_ocf_rupees numeric,
  avg_accruals_ratio_pct numeric,
  avg_cash_realization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.period_month,
    count(*)::bigint,
    coalesce(sum(e.net_profit_rupees),0)::numeric,
    coalesce(sum(e.operating_cash_flow_rupees),0)::numeric,
    round(avg(e.accruals_ratio_pct), 2),
    round(avg(e.cash_realization_pct), 2)
  from public.earnings_quality_r3612 e
  group by e.period_month
  order by e.period_month desc;
end;
$$;

revoke execute on function public.founder_r3612_monthly_quality_trend() from public, anon;
grant execute on function public.founder_r3612_monthly_quality_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3612_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.financial_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.earnings_quality_capa_actions_r3612 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3612_capa_status_board() from public, anon;
grant execute on function public.founder_r3612_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3612_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.earnings_quality_capa_actions_r3612)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.earnings_quality_capa_actions_r3612 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3612_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3612_root_cause_pareto() to authenticated;

-- 7) Accruals digest by business unit
create or replace function public.founder_r3612_accruals_digest()
returns table(
  business_unit text,
  entries bigint,
  total_accruals_rupees numeric,
  avg_accruals_ratio_pct numeric,
  total_non_recurring_rupees numeric,
  total_provision_rupees numeric,
  total_one_time_gains_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.business_unit,
    count(*)::bigint,
    coalesce(sum(e.accruals_rupees),0)::numeric,
    round(avg(e.accruals_ratio_pct), 2),
    coalesce(sum(e.non_recurring_items_rupees),0)::numeric,
    coalesce(sum(e.provision_charge_rupees),0)::numeric,
    coalesce(sum(e.one_time_gains_rupees),0)::numeric
  from public.earnings_quality_r3612 e
  group by e.business_unit
  order by coalesce(sum(e.accruals_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3612_accruals_digest() from public, anon;
grant execute on function public.founder_r3612_accruals_digest() to authenticated;

-- 8) High-risk queue (aggressive / red_flag earnings quality)
create or replace function public.founder_r3612_high_risk_queue()
returns table(
  business_unit text,
  entry_code text,
  period_month date,
  quality_status text,
  accruals_ratio_pct numeric,
  cash_realization_pct numeric,
  net_profit_rupees numeric,
  operating_cash_flow_rupees numeric,
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
  select e.business_unit, e.entry_code, e.period_month, e.quality_status,
    e.accruals_ratio_pct, e.cash_realization_pct, e.net_profit_rupees,
    e.operating_cash_flow_rupees, e.trend_dir, e.notes
  from public.earnings_quality_r3612 e
  where e.quality_status in ('aggressive','red_flag')
     or e.trend_dir = 'worsening'
  order by case e.quality_status
             when 'red_flag' then 0
             when 'aggressive' then 1
             when 'watch' then 2
             else 3
           end,
           e.period_month desc;
end;
$$;

revoke execute on function public.founder_r3612_high_risk_queue() from public, anon;
grant execute on function public.founder_r3612_high_risk_queue() to authenticated;
