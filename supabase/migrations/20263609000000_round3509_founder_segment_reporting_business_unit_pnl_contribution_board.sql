-- Round 3509: Founder Segment-Reporting Business-Unit P&L Contribution Board
-- Segment / BU P&L — business unit × period × revenue × direct cost × contribution × allocated cost ×
-- segment profit × contribution margin × segment margin × performance status × trend × CAPA

-- =============================================================================
-- TABLE 1: segment_bu_pnl_r3509 — per business-unit monthly P&L contribution
-- =============================================================================
create table if not exists public.segment_bu_pnl_r3509 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bu_code text not null,
  business_unit text not null,
  period_month date not null,
  revenue_rupees numeric(14,2),
  direct_cost_rupees numeric(14,2),
  contribution_rupees numeric(14,2),
  allocated_cost_rupees numeric(14,2),
  segment_profit_rupees numeric(14,2),
  contribution_margin_pct numeric(6,2),
  segment_margin_pct numeric(6,2),
  performance_status text not null check (performance_status in (
    'outperforming','on_plan','underperforming','loss_making'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.segment_bu_pnl_r3509 enable row level security;

create index if not exists idx_segment_bu_pnl_r3509_org on public.segment_bu_pnl_r3509(organization_id);
create index if not exists idx_segment_bu_pnl_r3509_month on public.segment_bu_pnl_r3509(period_month);
create index if not exists idx_segment_bu_pnl_r3509_status on public.segment_bu_pnl_r3509(performance_status);

-- =============================================================================
-- TABLE 2: segment_bu_pnl_capa_actions_r3509 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.segment_bu_pnl_capa_actions_r3509 (
  id uuid primary key default gen_random_uuid(),
  pnl_log_id uuid not null references public.segment_bu_pnl_r3509(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'contribution_margin_below_plan','revenue_shortfall','direct_cost_overrun','allocated_cost_spike',
    'segment_operating_loss','pricing_leakage','volume_decline','mix_deterioration','forex_impact','one_time_write_off'
  )),
  root_cause text not null check (root_cause in (
    'demand_softness','pricing_pressure','input_cost_inflation','overhead_misallocation',
    'underutilized_capacity','sales_execution_gap','product_mix_shift','fx_volatility',
    'contract_loss','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_contracts','renegotiate_supplier_terms','rationalize_overheads','exit_loss_making_line',
    'shift_product_mix','ramp_utilization','strengthen_sales_pipeline','hedge_fx_exposure',
    'restructure_bu','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  profit_impact_class text not null check (profit_impact_class in (
    'margin_erosion','revenue_miss','cost_overrun','none','one_time_charge','structural_loss'
  )),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  profit_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.segment_bu_pnl_capa_actions_r3509 enable row level security;

create index if not exists idx_segment_bu_pnl_capa_r3509_log on public.segment_bu_pnl_capa_actions_r3509(pnl_log_id);
create index if not exists idx_segment_bu_pnl_capa_r3509_status on public.segment_bu_pnl_capa_actions_r3509(capa_status);

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

  -- 16 BU-period P&L rows
  insert into public.segment_bu_pnl_r3509 (
    organization_id, bu_code, business_unit, period_month,
    revenue_rupees, direct_cost_rupees, contribution_rupees, allocated_cost_rupees, segment_profit_rupees,
    contribution_margin_pct, segment_margin_pct, performance_status, trend_dir, notes
  )
  select v_org_id, q.buc, q.bunit, q.pm::date,
    q.rev, q.dcost, q.contrib, q.alloc, q.sprofit,
    q.cmpct, q.smpct, q.pstat, q.tdir, q.nt
  from (values
    ('DIAG-APR26','Diagnostics','2026-04-01',
     4200000,2100000,2100000,900000,1200000,50.00,28.57,'outperforming','improving','Diagnostics lab volumes ahead of plan on new referral tie-ups'),
    ('DIAG-MAY26','Diagnostics','2026-05-01',
     4500000,2250000,2250000,950000,1300000,50.00,28.89,'outperforming','improving','Sustained contribution as reagent costs held flat'),
    ('DIAG-JUN26','Diagnostics','2026-06-01',
     4650000,2350000,2300000,980000,1320000,49.46,28.39,'outperforming','stable','Marginal CM dip on B2B pricing; still comfortably above plan'),
    ('MES-APR26','Medical Equipment Sales','2026-04-01',
     8200000,6150000,2050000,1200000,850000,25.00,10.37,'on_plan','stable','Equipment sales on plan; capital deal mix normal'),
    ('MES-MAY26','Medical Equipment Sales','2026-05-01',
     7600000,5900000,1700000,1250000,450000,22.37,5.92,'underperforming','worsening','Contribution margin slipping on discounted tenders'),
    ('MES-JUN26','Medical Equipment Sales','2026-06-01',
     7100000,5700000,1400000,1280000,120000,19.72,1.69,'underperforming','worsening','Third month of CM erosion; direct cost creep on imports'),
    ('AMC-APR26','AMC & Service','2026-04-01',
     3100000,1550000,1550000,620000,930000,50.00,30.00,'outperforming','stable','Service contracts renewing at healthy margins'),
    ('AMC-MAY26','AMC & Service','2026-05-01',
     3250000,1600000,1650000,640000,1010000,50.77,31.08,'outperforming','improving','AMC base expanding; spare-parts attach rate up'),
    ('AMC-JUN26','AMC & Service','2026-06-01',
     3400000,1680000,1720000,660000,1060000,50.59,31.18,'outperforming','improving','Highest segment margin BU; utilisation strong'),
    ('CONS-APR26','Consumables','2026-04-01',
     2600000,1950000,650000,480000,170000,25.00,6.54,'on_plan','stable','Consumables steady; thin but positive margin'),
    ('CONS-MAY26','Consumables','2026-05-01',
     2500000,1920000,580000,490000,90000,23.20,3.60,'underperforming','worsening','Volume dip on hospital destocking softens margin'),
    ('RENT-APR26','Rental Fleet','2026-04-01',
     1800000,1100000,700000,900000,-200000,38.89,-11.11,'loss_making','worsening','Fleet under-utilised; allocated depreciation drags to loss'),
    ('RENT-MAY26','Rental Fleet','2026-05-01',
     1750000,1080000,670000,910000,-240000,38.29,-13.71,'loss_making','worsening','Second consecutive rental loss; idle assets rising'),
    ('TKEY-MAY26','Turnkey Projects','2026-05-01',
     12500000,9800000,2700000,1500000,1200000,21.60,9.60,'on_plan','improving','Large turnkey milestone billed; margin within bid range'),
    ('TKEY-JUN26','Turnkey Projects','2026-06-01',
     9800000,8200000,1600000,1550000,50000,16.33,0.51,'underperforming','worsening','Cost overrun plus overhead spike compresses project margin'),
    ('HOME-JUN26','Homecare','2026-06-01',
     1400000,980000,420000,560000,-140000,30.00,-10.00,'loss_making','worsening','Early-stage homecare BU still sub-scale; operating loss')
  ) as q(buc, bunit, pm, rev, dcost, contrib, alloc, sprofit, cmpct, smpct, pstat, tdir, nt);

  -- CAPA seed — attach to specific BU-period rows via bu_code
  insert into public.segment_bu_pnl_capa_actions_r3509 (
    pnl_log_id, finding_category, root_cause, corrective_action,
    capa_status, profit_impact_class, action_owner, target_closure_date, actual_closure_date,
    profit_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.pic, q.own, q.tcd::date, q.acd::date,
    q.impact, q.nt
  from (values
    ('MES-JUN26','direct_cost_overrun','input_cost_inflation','renegotiate_supplier_terms','in_progress','cost_overrun','Rahul Nair (BU Head - Equipment)','2026-07-20',null,1280000.00,'Import direct-cost creep eroding equipment CM; supplier renegotiation underway'),
    ('MES-MAY26','contribution_margin_below_plan','pricing_pressure','reprice_contracts','open','margin_erosion','Rahul Nair (BU Head - Equipment)','2026-07-15',null,350000.00,'Tender discounting pulling CM below plan; repricing framework proposed'),
    ('RENT-APR26','segment_operating_loss','underutilized_capacity','ramp_utilization','escalated','structural_loss','Sneha Rao (BU Head - Rental)','2026-07-10',null,200000.00,'Rental fleet loss-making on low utilisation; escalated to board review'),
    ('RENT-MAY26','segment_operating_loss','underutilized_capacity','exit_loss_making_line','overdue','structural_loss','Sneha Rao (BU Head - Rental)','2026-06-30',null,240000.00,'Second consecutive rental loss; exit / restructure decision overdue'),
    ('CONS-MAY26','volume_decline','demand_softness','strengthen_sales_pipeline','in_progress','revenue_miss','Amit Desai (BU Head - Consumables)','2026-07-18',null,90000.00,'Consumables volume dip on hospital destocking; pipeline rebuild in progress'),
    ('TKEY-JUN26','allocated_cost_spike','overhead_misallocation','rationalize_overheads','verification_pending','margin_erosion','Priya Menon (BU Head - Projects)','2026-07-22',null,150000.00,'Project overhead allocation spiked; reallocation under verification'),
    ('HOME-JUN26','segment_operating_loss','sales_execution_gap','restructure_bu','open','structural_loss','Vikram Iyer (BU Head - Homecare)','2026-08-05',null,140000.00,'Early-stage homecare operating loss; restructure plan being drafted'),
    ('TKEY-MAY26','mix_deterioration','product_mix_shift','shift_product_mix','closed','none','Priya Menon (BU Head - Projects)','2026-06-15','2026-06-12',0.00,'Scope mix corrected toward higher-margin work; closed after verification'),
    ('DIAG-JUN26','contribution_margin_below_plan','pricing_pressure','reprice_contracts','closed','margin_erosion','Kavya Reddy (BU Head - Diagnostics)','2026-06-25','2026-06-20',60000.00,'Minor diagnostics CM dip from B2B pricing; corrected via list revision')
  ) as q(buc, fc, rc, ca, cst, pic, own, tcd, acd, impact, nt)
  join public.segment_bu_pnl_r3509 e
    on e.organization_id = v_org_id and e.bu_code = q.buc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Performance-status distribution
create or replace function public.founder_r3509_performance_status_rollup()
returns table(performance_status text, business_units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.segment_bu_pnl_r3509)
  select l.performance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.segment_bu_pnl_r3509 l
  group by l.performance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3509_performance_status_rollup() from public, anon;
grant execute on function public.founder_r3509_performance_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3509_business_unit_scorecard()
returns table(
  business_unit text,
  periods bigint,
  total_revenue_rupees numeric,
  total_direct_cost_rupees numeric,
  total_contribution_rupees numeric,
  total_allocated_cost_rupees numeric,
  total_segment_profit_rupees numeric,
  avg_contribution_margin_pct numeric,
  avg_segment_margin_pct numeric
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
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.direct_cost_rupees),0)::numeric,
    coalesce(sum(l.contribution_rupees),0)::numeric,
    coalesce(sum(l.allocated_cost_rupees),0)::numeric,
    coalesce(sum(l.segment_profit_rupees),0)::numeric,
    round(avg(l.contribution_margin_pct), 2),
    round(avg(l.segment_margin_pct), 2)
  from public.segment_bu_pnl_r3509 l
  group by l.business_unit
  order by coalesce(sum(l.segment_profit_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3509_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3509_business_unit_scorecard() to authenticated;

-- 3) Business-unit × performance-status matrix
create or replace function public.founder_r3509_bu_performance_matrix()
returns table(business_unit text, performance_status text, entries bigint, total_segment_profit_rupees numeric, avg_segment_margin_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.performance_status, count(*)::bigint,
    coalesce(sum(l.segment_profit_rupees),0)::numeric,
    round(avg(l.segment_margin_pct), 2)
  from public.segment_bu_pnl_r3509 l
  group by l.business_unit, l.performance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3509_bu_performance_matrix() from public, anon;
grant execute on function public.founder_r3509_bu_performance_matrix() to authenticated;

-- 4) Monthly segment-margin trend
create or replace function public.founder_r3509_monthly_margin_trend()
returns table(period_month date, entries bigint, total_revenue_rupees numeric, total_segment_profit_rupees numeric, avg_contribution_margin_pct numeric, avg_segment_margin_pct numeric)
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
    coalesce(sum(l.segment_profit_rupees),0)::numeric,
    round(avg(l.contribution_margin_pct), 2),
    round(avg(l.segment_margin_pct), 2)
  from public.segment_bu_pnl_r3509 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3509_monthly_margin_trend() from public, anon;
grant execute on function public.founder_r3509_monthly_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3509_capa_status_board()
returns table(capa_status text, findings bigint, avg_profit_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.profit_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.segment_bu_pnl_capa_actions_r3509 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3509_capa_status_board() from public, anon;
grant execute on function public.founder_r3509_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3509_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_profit_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.segment_bu_pnl_capa_actions_r3509)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.profit_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.segment_bu_pnl_capa_actions_r3509 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3509_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3509_root_cause_pareto() to authenticated;

-- 7) Profit-impact digest
create or replace function public.founder_r3509_profit_impact_digest()
returns table(profit_impact_class text, findings bigint, open_findings bigint, total_profit_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.profit_impact_class, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.profit_impact_rupees),0)::numeric
  from public.segment_bu_pnl_capa_actions_r3509 c
  group by c.profit_impact_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3509_profit_impact_digest() from public, anon;
grant execute on function public.founder_r3509_profit_impact_digest() to authenticated;

-- 8) High-risk queue (loss-making / underperforming / worsening)
create or replace function public.founder_r3509_high_risk_queue()
returns table(
  business_unit text,
  period_month date,
  performance_status text,
  trend_dir text,
  revenue_rupees numeric,
  contribution_margin_pct numeric,
  segment_margin_pct numeric,
  segment_profit_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.period_month, l.performance_status, l.trend_dir,
    l.revenue_rupees, l.contribution_margin_pct, l.segment_margin_pct, l.segment_profit_rupees, l.notes
  from public.segment_bu_pnl_r3509 l
  where l.performance_status in ('underperforming','loss_making')
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3509_high_risk_queue() from public, anon;
grant execute on function public.founder_r3509_high_risk_queue() to authenticated;
