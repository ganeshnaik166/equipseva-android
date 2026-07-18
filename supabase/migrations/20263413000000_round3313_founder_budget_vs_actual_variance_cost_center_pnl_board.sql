-- Round 3313: Founder Budget-vs-Actual Variance & Cost-Center P&L Governance Board
-- Finance board — cost-center × line-item × budget vs actual × variance rupees/pct × direction × YTD × full-year forecast × variance verdict × CAPA reforecast actions

-- =============================================================================
-- TABLE 1: budget_variance_r3313 — per cost-center/period/line-item budget-vs-actual rows
-- =============================================================================
create table if not exists public.budget_variance_r3313 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cost_center text not null check (cost_center in (
    'field_service_ops','spares_inventory','sales_marketing','rnd_engineering',
    'g_and_a','logistics','customer_support'
  )),
  period_month text not null,
  line_item text not null check (line_item in (
    'revenue','parts_cost','labour_cost','travel','marketing_spend',
    'rent_utilities','software_tools','other_opex'
  )),
  owner text not null,
  budget_rupees numeric(14,2) not null,
  actual_rupees numeric(14,2) not null,
  variance_rupees numeric(14,2) not null,
  variance_pct numeric(6,2) not null,
  variance_direction text not null check (variance_direction in (
    'favorable','unfavorable','on_budget'
  )),
  ytd_budget_rupees numeric(14,2) not null,
  ytd_actual_rupees numeric(14,2) not null,
  forecast_full_year_rupees numeric(14,2) not null,
  variance_verdict text not null check (variance_verdict in (
    'within_tolerance','watch','overrun_action_needed','underspend_review','reforecast_required'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.budget_variance_r3313 enable row level security;

create index if not exists idx_budget_variance_r3313_org on public.budget_variance_r3313(organization_id);
create index if not exists idx_budget_variance_r3313_period on public.budget_variance_r3313(period_month);
create index if not exists idx_budget_variance_r3313_verdict on public.budget_variance_r3313(variance_verdict);

-- =============================================================================
-- TABLE 2: budget_variance_capa_actions_r3313 — corrective / reforecast actions
-- =============================================================================
create table if not exists public.budget_variance_capa_actions_r3313 (
  id uuid primary key default gen_random_uuid(),
  variance_id uuid not null references public.budget_variance_r3313(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'revenue_shortfall','cost_overrun','marketing_overspend','travel_overspend',
    'parts_cost_spike','labour_cost_overrun','software_cost_creep','underspend_risk','forecast_gap'
  )),
  root_cause text not null check (root_cause in (
    'demand_slowdown','vendor_price_increase','fx_impact','headcount_ramp','scope_creep',
    'one_time_event','budgeting_error','process_inefficiency','pending_investigation','seasonal_variation'
  )),
  corrective_action text not null check (corrective_action in (
    'reforecast_quarter','renegotiate_vendor_contract','freeze_discretionary_spend','reallocate_budget',
    'hiring_freeze','price_increase_customers','process_automation','escalate_to_board',
    'accept_variance','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  materiality text not null check (materiality in (
    'immaterial','monitor','material','board_escalation','runway_risk','covenant_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.budget_variance_capa_actions_r3313 enable row level security;

create index if not exists idx_budget_variance_capa_r3313_var on public.budget_variance_capa_actions_r3313(variance_id);
create index if not exists idx_budget_variance_capa_r3313_status on public.budget_variance_capa_actions_r3313(capa_status);

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

  -- 14 budget-vs-actual rows
  insert into public.budget_variance_r3313 (
    organization_id, cost_center, period_month, line_item, owner,
    budget_rupees, actual_rupees, variance_rupees, variance_pct, variance_direction,
    ytd_budget_rupees, ytd_actual_rupees, forecast_full_year_rupees, variance_verdict, notes
  )
  select v_org_id, q.cc, q.pm, q.li, q.owner,
    q.budget, q.actual, q.var, q.vpct, q.dir,
    q.ytdb, q.ytda, q.fcy, q.verdict, q.nt
  from (values
    ('field_service_ops','2026-06','labour_cost','Rajesh Menon',
     1800000,1935000,135000,7.50,'unfavorable',10200000,10850000,21800000,'watch','Overtime for AIIMS Delhi cath-lab installs pushed labour 7.5% over'),
    ('field_service_ops','2026-06','travel','Rajesh Menon',
     420000,512000,92000,21.90,'unfavorable',2350000,2780000,5400000,'overrun_action_needed','Multi-city Apollo Chennai to Manipal Bengaluru travel spike'),
    ('spares_inventory','2026-06','parts_cost','Anita Deshpande',
     3200000,3680000,480000,15.00,'unfavorable',18500000,20100000,39800000,'overrun_action_needed','Contrast injector piston kits and transducer cables — vendor price up'),
    ('spares_inventory','2026-06','other_opex','Anita Deshpande',
     260000,240000,-20000,-7.69,'favorable',1500000,1420000,2900000,'within_tolerance','Warehouse consumables under plan'),
    ('sales_marketing','2026-06','marketing_spend','Priya Krishnan',
     900000,1180000,280000,31.11,'unfavorable',5100000,6050000,11800000,'reforecast_required','Digital campaign for Fortis Gurgaon AMC renewals over-indexed'),
    ('sales_marketing','2026-06','revenue','Priya Krishnan',
     12500000,11200000,-1300000,-10.40,'unfavorable',71000000,66500000,138000000,'overrun_action_needed','AMC renewal revenue short — CMC Vellore deal slipped to Q3'),
    ('rnd_engineering','2026-06','labour_cost','Suresh Iyer',
     2100000,2050000,-50000,-2.38,'favorable',12300000,12100000,24600000,'within_tolerance','Firmware team on plan'),
    ('rnd_engineering','2026-06','software_tools','Suresh Iyer',
     380000,465000,85000,22.37,'unfavorable',2200000,2560000,5000000,'watch','Added CAD and PLM seats mid-quarter'),
    ('g_and_a','2026-06','rent_utilities','Meera Nair',
     650000,662000,12000,1.85,'on_budget',3850000,3880000,7800000,'within_tolerance','Bengaluru HQ within tolerance'),
    ('g_and_a','2026-06','other_opex','Meera Nair',
     540000,430000,-110000,-20.37,'favorable',3100000,2680000,6200000,'underspend_review','Legal and audit fees deferred to H2 — confirm timing'),
    ('logistics','2026-06','travel','Vikram Rao',
     780000,905000,125000,16.03,'unfavorable',4400000,5010000,9700000,'overrun_action_needed','Fuel and last-mile to KIMS Hyderabad and Fortis Gurgaon up'),
    ('customer_support','2026-06','labour_cost','Deepa Balan',
     1100000,1145000,45000,4.09,'unfavorable',6400000,6520000,13000000,'watch','Extra L2 engineer for Manipal Bengaluru escalations'),
    ('customer_support','2026-06','software_tools','Deepa Balan',
     210000,208000,-2000,-0.95,'on_budget',1250000,1240000,2500000,'within_tolerance','Ticketing tool renewal on plan'),
    ('field_service_ops','2026-05','parts_cost','Rajesh Menon',
     2900000,3520000,620000,21.38,'unfavorable',15600000,16580000,38000000,'reforecast_required','May parts burn from Apollo Chennai emergency swaps — reforecast FY')
  ) as q(cc, pm, li, owner, budget, actual, var, vpct, dir, ytdb, ytda, fcy, verdict, nt);

  -- CAPA seed — attach to at-risk rows via cost_center + period_month + line_item
  insert into public.budget_variance_capa_actions_r3313 (
    variance_id, finding_category, root_cause, corrective_action,
    capa_status, materiality, target_closure_date, actual_closure_date,
    estimated_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.mat, q.tcd::date, q.acd::date,
    q.impact, q.nt
  from (values
    ('field_service_ops','2026-06','travel','travel_overspend','process_inefficiency','reallocate_budget','in_progress','monitor','2026-07-31',null,92000,'Consolidate site visits — route-planning tool rollout for South zone'),
    ('spares_inventory','2026-06','parts_cost','parts_cost_spike','vendor_price_increase','renegotiate_vendor_contract','open','material','2026-08-15',null,480000,'Renegotiate ACIST and Medrad annual rate card before Q3 buys'),
    ('sales_marketing','2026-06','marketing_spend','marketing_overspend','scope_creep','freeze_discretionary_spend','escalated','board_escalation','2026-07-20',null,280000,'Freeze paid campaigns pending ROI review with board'),
    ('sales_marketing','2026-06','revenue','revenue_shortfall','demand_slowdown','reforecast_quarter','escalated','runway_risk','2026-07-25',null,1300000,'CMC Vellore slip — reforecast Q3 pipeline and cash runway'),
    ('logistics','2026-06','travel','travel_overspend','seasonal_variation','process_automation','in_progress','monitor','2026-08-05',null,125000,'Fuel surcharge — pilot 3PL last-mile for South zone'),
    ('field_service_ops','2026-05','parts_cost','forecast_gap','one_time_event','reforecast_quarter','closed','material','2026-06-30','2026-06-28',620000,'Emergency swaps reforecast into FY parts budget — closed'),
    ('rnd_engineering','2026-06','software_tools','software_cost_creep','budgeting_error','accept_variance','verification_pending','immaterial','2026-07-15',null,85000,'Seat additions justified — fold into next-quarter software budget')
  ) as q(cc, pm, li, fc, rc, ca, cst, mat, tcd, acd, impact, nt)
  join public.budget_variance_r3313 e
    on e.organization_id = v_org_id and e.cost_center = q.cc and e.period_month = q.pm and e.line_item = q.li;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Variance verdict distribution
create or replace function public.founder_r3313_variance_verdict_rollup()
returns table(variance_verdict text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.budget_variance_r3313)
  select l.variance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.budget_variance_r3313 l
  group by l.variance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3313_variance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3313_variance_verdict_rollup() to authenticated;

-- 2) Cost-center P&L scorecard
create or replace function public.founder_r3313_cost_center_scorecard()
returns table(
  cost_center text,
  total_lines bigint,
  favorable bigint,
  unfavorable bigint,
  overrun_action bigint,
  total_budget_rupees numeric,
  total_actual_rupees numeric,
  total_variance_rupees numeric,
  avg_variance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_center,
    count(*)::bigint,
    count(*) filter (where l.variance_direction = 'favorable')::bigint,
    count(*) filter (where l.variance_direction = 'unfavorable')::bigint,
    count(*) filter (where l.variance_verdict in ('overrun_action_needed','reforecast_required'))::bigint,
    coalesce(sum(l.budget_rupees),0)::numeric,
    coalesce(sum(l.actual_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric,
    round(avg(l.variance_pct), 2)
  from public.budget_variance_r3313 l
  group by l.cost_center
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3313_cost_center_scorecard() from public, anon;
grant execute on function public.founder_r3313_cost_center_scorecard() to authenticated;

-- 3) Cost-center × line-item matrix
create or replace function public.founder_r3313_center_lineitem_matrix()
returns table(
  cost_center text,
  line_item text,
  entries bigint,
  total_budget_rupees numeric,
  total_actual_rupees numeric,
  total_variance_rupees numeric,
  avg_variance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_center, l.line_item, count(*)::bigint,
    coalesce(sum(l.budget_rupees),0)::numeric,
    coalesce(sum(l.actual_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric,
    round(avg(l.variance_pct), 2)
  from public.budget_variance_r3313 l
  group by l.cost_center, l.line_item
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3313_center_lineitem_matrix() from public, anon;
grant execute on function public.founder_r3313_center_lineitem_matrix() to authenticated;

-- 4) Monthly variance trend
create or replace function public.founder_r3313_monthly_variance_trend()
returns table(
  period_month text,
  entries bigint,
  total_budget_rupees numeric,
  total_actual_rupees numeric,
  total_variance_rupees numeric,
  unfavorable bigint
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
    coalesce(sum(l.budget_rupees),0)::numeric,
    coalesce(sum(l.actual_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric,
    count(*) filter (where l.variance_direction = 'unfavorable')::bigint
  from public.budget_variance_r3313 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3313_monthly_variance_trend() from public, anon;
grant execute on function public.founder_r3313_monthly_variance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3313_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.budget_variance_capa_actions_r3313 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3313_capa_status_board() from public, anon;
grant execute on function public.founder_r3313_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3313_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.budget_variance_capa_actions_r3313)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.budget_variance_capa_actions_r3313 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3313_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3313_root_cause_pareto() to authenticated;

-- 7) Materiality / cost-risk digest
create or replace function public.founder_r3313_materiality_digest()
returns table(materiality text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.materiality, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric
  from public.budget_variance_capa_actions_r3313 c
  group by c.materiality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3313_materiality_digest() from public, anon;
grant execute on function public.founder_r3313_materiality_digest() to authenticated;

-- 8) High-risk variance queue (top individual concerns)
create or replace function public.founder_r3313_high_risk_queue()
returns table(
  cost_center text,
  period_month text,
  line_item text,
  owner text,
  budget_rupees numeric,
  actual_rupees numeric,
  variance_rupees numeric,
  variance_pct numeric,
  variance_direction text,
  variance_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_center, l.period_month, l.line_item, l.owner,
    l.budget_rupees, l.actual_rupees, l.variance_rupees, l.variance_pct,
    l.variance_direction, l.variance_verdict, l.notes
  from public.budget_variance_r3313 l
  where l.variance_verdict in ('watch','overrun_action_needed','underspend_review','reforecast_required')
     or l.variance_direction = 'unfavorable'
     or abs(l.variance_pct) >= 10.0
  order by l.variance_rupees desc, l.cost_center;
end;
$$;

revoke execute on function public.founder_r3313_high_risk_queue() from public, anon;
grant execute on function public.founder_r3313_high_risk_queue() to authenticated;
