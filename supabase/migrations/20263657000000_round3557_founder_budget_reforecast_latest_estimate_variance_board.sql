-- Round 3557: Founder Budget-Reforecast / Latest-Estimate Variance Board
-- Founder budget vs latest-estimate (reforecast) variance + full-year outlook per cost/rev line —
-- line item × category × original budget × latest estimate × actuals YTD × variance rupees/pct ×
-- full-year outlook × forecast status × month × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: budget_reforecast_r3557 — per-line reforecast / latest-estimate variance
-- =============================================================================
create table if not exists public.budget_reforecast_r3557 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  line_code text not null,
  line_item text not null,
  category text not null check (category in (
    'revenue','cogs','opex','capex','headcount'
  )),
  cost_center text not null,
  original_budget_rupees numeric(16,2) not null,
  latest_estimate_rupees numeric(16,2) not null,
  actuals_ytd_rupees numeric(16,2),
  variance_rupees numeric(16,2),
  variance_pct numeric(7,2),
  full_year_outlook_rupees numeric(16,2),
  forecast_status text not null check (forecast_status in (
    'on_budget','favorable','unfavorable','at_risk','revised'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.budget_reforecast_r3557 enable row level security;

create index if not exists idx_budget_reforecast_r3557_org on public.budget_reforecast_r3557(organization_id);
create index if not exists idx_budget_reforecast_r3557_month on public.budget_reforecast_r3557(period_month);
create index if not exists idx_budget_reforecast_r3557_status on public.budget_reforecast_r3557(forecast_status);

-- =============================================================================
-- TABLE 2: budget_reforecast_capa_actions_r3557 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.budget_reforecast_capa_actions_r3557 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  budget_line_id uuid not null references public.budget_reforecast_r3557(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'budget_overrun','revenue_shortfall','cost_inflation','scope_creep','headcount_overrun',
    'capex_overrun','fx_impact','demand_miss','vendor_price_increase','forecast_model_error'
  )),
  root_cause text not null check (root_cause in (
    'demand_lower_than_planned','input_cost_inflation','hiring_ahead_of_plan','vendor_price_hike',
    'scope_expansion','fx_depreciation','delayed_project','pricing_pressure',
    'forecast_assumption_error','one_time_expense'
  )),
  corrective_action text not null check (corrective_action in (
    'reforecast_line','freeze_discretionary_spend','renegotiate_vendor_contract','defer_capex',
    'hiring_freeze','price_increase','cost_reduction_program','reallocate_budget',
    'escalate_to_board','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.budget_reforecast_capa_actions_r3557 enable row level security;

create index if not exists idx_budget_reforecast_capa_r3557_org on public.budget_reforecast_capa_actions_r3557(organization_id);
create index if not exists idx_budget_reforecast_capa_r3557_line on public.budget_reforecast_capa_actions_r3557(budget_line_id);
create index if not exists idx_budget_reforecast_capa_r3557_status on public.budget_reforecast_capa_actions_r3557(capa_status);

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

  -- 16 reforecast line rows
  insert into public.budget_reforecast_r3557 (
    organization_id, line_code, line_item, category, cost_center,
    original_budget_rupees, latest_estimate_rupees, actuals_ytd_rupees,
    variance_rupees, variance_pct, full_year_outlook_rupees,
    forecast_status, period_month, trend_dir, owner, notes
  )
  select v_org_id, q.lcode, q.litem, q.cat, q.cc,
    q.obud, q.lest, q.ayt,
    q.varr, q.varp, q.fyo,
    q.fst, q.pmon::date, q.tdir, q.own, q.nt
  from (values
    ('REV-AMC-01','AMC & service contract revenue','revenue','Service Revenue',
     42000000,45500000,26000000,3500000,8.3,45500000,'favorable','2026-07-01','improving','Priya Nair','AMC renewals ahead of plan across metro accounts'),
    ('REV-MKT-02','Marketplace commission revenue','revenue','Marketplace',
     18000000,15200000,8400000,-2800000,-15.6,15200000,'unfavorable','2026-07-01','worsening','Rahul Menon','Transaction volume below plan, fewer active sellers'),
    ('REV-SPR-03','Spare-parts resale revenue','revenue','Parts',
     9500000,9600000,5300000,100000,1.1,9600000,'on_budget','2026-06-01','stable','Anita Rao','Tracking to plan'),
    ('REV-INS-04','Installation & commissioning revenue','revenue','Projects',
     6000000,5100000,2600000,-900000,-15.0,5100000,'at_risk','2026-07-01','worsening','Vikram Shah','Two hospital deployments slipped to next quarter'),
    ('COGS-PRT-05','Spare parts & consumables COGS','cogs','Parts',
     5200000,5900000,3400000,700000,13.5,5900000,'unfavorable','2026-06-01','worsening','Anita Rao','Vendor price hikes on imported spares'),
    ('COGS-LAB-06','Field service labour COGS','cogs','Field Service',
     8800000,8600000,5000000,-200000,-2.3,8600000,'favorable','2026-06-01','improving','Suresh Kumar','Route optimisation lowering travel cost'),
    ('COGS-LOG-07','Logistics & freight COGS','cogs','Supply Chain',
     3100000,3450000,2000000,350000,11.3,3450000,'unfavorable','2026-07-01','worsening','Deepa Iyer','Fuel surcharge and courier rate increase'),
    ('OPEX-SAL-08','Employee salaries & benefits','opex','People',
     24000000,25800000,14800000,1800000,7.5,25800000,'unfavorable','2026-06-01','stable','Meera Joshi','Mid-year increments above budgeted band'),
    ('OPEX-CLD-09','Cloud & SaaS subscriptions','opex','Technology',
     3600000,3300000,1900000,-300000,-8.3,3300000,'favorable','2026-05-01','improving','Karthik Reddy','Committed-use discounts renegotiated'),
    ('OPEX-MKT-10','Marketing & demand-gen spend','opex','Marketing',
     5000000,4600000,2500000,-400000,-8.0,4600000,'favorable','2026-05-01','stable','Rahul Menon','Reallocated to performance channels'),
    ('OPEX-ADM-11','Office rent & admin overhead','opex','Admin',
     4200000,4250000,2450000,50000,1.2,4250000,'on_budget','2026-05-01','stable','Meera Joshi','Tracking to plan'),
    ('CAPX-TLS-12','Field diagnostic tools & instruments','capex','Field Service',
     7500000,8900000,4100000,1400000,18.7,8900000,'at_risk','2026-07-01','worsening','Suresh Kumar','Expanded calibration-lab scope drove capex up'),
    ('CAPX-ITI-13','IT infrastructure & devices','capex','Technology',
     3000000,2700000,1600000,-300000,-10.0,2700000,'favorable','2026-06-01','improving','Karthik Reddy','Lease-vs-buy shift reduced outlay'),
    ('HC-FSE-14','Field service engineer headcount','headcount','Field Service',
     12000000,13500000,7800000,1500000,12.5,13500000,'unfavorable','2026-07-01','worsening','Suresh Kumar','Hiring ahead of plan for new regions'),
    ('HC-SUP-15','Customer support headcount','headcount','Support',
     4800000,4800000,2750000,0,0.0,4800000,'on_budget','2026-05-01','stable','Anita Rao','On plan'),
    ('REV-TRN-16','Biomed training services revenue','revenue','Training',
     3500000,4200000,2300000,700000,20.0,4200000,'revised','2026-06-01','improving','Priya Nair','New certification programme reforecast upward')
  ) as q(lcode, litem, cat, cc, obud, lest, ayt, varr, varp, fyo, fst, pmon, tdir, own, nt);

  -- 8 CAPA rows — attach to specific lines via line_code
  insert into public.budget_reforecast_capa_actions_r3557 (
    organization_id, budget_line_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('REV-MKT-02','revenue_shortfall','demand_lower_than_planned','reforecast_line','in_progress',2800000,'Rahul Menon','2026-08-15',null,'Rebuild marketplace demand plan; onboard two enterprise accounts'),
    ('REV-INS-04','demand_miss','delayed_project','escalate_to_board','escalated',900000,'Vikram Shah','2026-08-10',null,'Installs slipped to Q3 — board review of pipeline'),
    ('COGS-PRT-05','cost_inflation','input_cost_inflation','renegotiate_vendor_contract','open',700000,'Anita Rao','2026-08-20',null,'Renegotiate imported-spares contract; qualify local vendor'),
    ('COGS-LOG-07','cost_inflation','vendor_price_hike','renegotiate_vendor_contract','in_progress',350000,'Deepa Iyer','2026-08-05',null,'Consolidate courier partners; lock freight rate card'),
    ('OPEX-SAL-08','headcount_overrun','hiring_ahead_of_plan','hiring_freeze','verification_pending',1800000,'Meera Joshi','2026-07-31',null,'Selective freeze on non-critical roles; verify run-rate'),
    ('CAPX-TLS-12','capex_overrun','scope_expansion','defer_capex','open',1400000,'Suresh Kumar','2026-08-25',null,'Phase calibration-lab tooling over two quarters'),
    ('HC-FSE-14','headcount_overrun','hiring_ahead_of_plan','reallocate_budget','escalated',1500000,'Suresh Kumar','2026-08-12',null,'Fund from deferred capex; align to region ramp plan'),
    ('REV-TRN-16','forecast_model_error','forecast_assumption_error','reforecast_line','closed',700000,'Priya Nair','2026-06-30','2026-06-28','Training revenue model corrected and reforecast upward')
  ) as q(lcode, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.budget_reforecast_r3557 e
    on e.organization_id = v_org_id and e.line_code = q.lcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Forecast-status distribution
create or replace function public.founder_r3557_forecast_status_rollup()
returns table(forecast_status text, lines bigint, total_variance_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.budget_reforecast_r3557)
  select l.forecast_status, count(*)::bigint,
         coalesce(sum(l.variance_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.budget_reforecast_r3557 l
  group by l.forecast_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3557_forecast_status_rollup() from public, anon;
grant execute on function public.founder_r3557_forecast_status_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3557_category_scorecard()
returns table(
  category text,
  lines bigint,
  on_budget bigint,
  favorable bigint,
  unfavorable bigint,
  at_risk bigint,
  revised bigint,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.forecast_status = 'on_budget')::bigint,
    count(*) filter (where l.forecast_status = 'favorable')::bigint,
    count(*) filter (where l.forecast_status = 'unfavorable')::bigint,
    count(*) filter (where l.forecast_status = 'at_risk')::bigint,
    count(*) filter (where l.forecast_status = 'revised')::bigint,
    round(100.0 * count(*) filter (where l.forecast_status in ('on_budget','favorable'))::numeric / nullif(count(*),0), 1)
  from public.budget_reforecast_r3557 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3557_category_scorecard() from public, anon;
grant execute on function public.founder_r3557_category_scorecard() to authenticated;

-- 3) Category × forecast-status matrix
create or replace function public.founder_r3557_category_status_matrix()
returns table(category text, forecast_status text, lines bigint, total_variance_rupees numeric, total_latest_estimate_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.forecast_status, count(*)::bigint,
    coalesce(sum(l.variance_rupees),0)::numeric,
    coalesce(sum(l.latest_estimate_rupees),0)::numeric
  from public.budget_reforecast_r3557 l
  group by l.category, l.forecast_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3557_category_status_matrix() from public, anon;
grant execute on function public.founder_r3557_category_status_matrix() to authenticated;

-- 4) Monthly reforecast trend
create or replace function public.founder_r3557_monthly_reforecast_trend()
returns table(
  period_month date,
  lines bigint,
  total_original_budget_rupees numeric,
  total_latest_estimate_rupees numeric,
  total_variance_rupees numeric,
  unfavorable bigint,
  at_risk bigint
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
    coalesce(sum(l.original_budget_rupees),0)::numeric,
    coalesce(sum(l.latest_estimate_rupees),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric,
    count(*) filter (where l.forecast_status = 'unfavorable')::bigint,
    count(*) filter (where l.forecast_status = 'at_risk')::bigint
  from public.budget_reforecast_r3557 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3557_monthly_reforecast_trend() from public, anon;
grant execute on function public.founder_r3557_monthly_reforecast_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3557_capa_status_board()
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
  from public.budget_reforecast_capa_actions_r3557 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3557_capa_status_board() from public, anon;
grant execute on function public.founder_r3557_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3557_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.budget_reforecast_capa_actions_r3557)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.budget_reforecast_capa_actions_r3557 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3557_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3557_root_cause_pareto() to authenticated;

-- 7) Variance-impact digest (by category)
create or replace function public.founder_r3557_variance_impact_digest()
returns table(
  category text,
  lines bigint,
  favorable_variance_rupees numeric,
  unfavorable_variance_rupees numeric,
  at_risk_variance_rupees numeric,
  net_variance_rupees numeric,
  total_full_year_outlook_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    coalesce(sum(l.variance_rupees) filter (where l.forecast_status = 'favorable'),0)::numeric,
    coalesce(sum(l.variance_rupees) filter (where l.forecast_status = 'unfavorable'),0)::numeric,
    coalesce(sum(l.variance_rupees) filter (where l.forecast_status = 'at_risk'),0)::numeric,
    coalesce(sum(l.variance_rupees),0)::numeric,
    coalesce(sum(l.full_year_outlook_rupees),0)::numeric
  from public.budget_reforecast_r3557 l
  group by l.category
  order by sum(abs(coalesce(l.variance_rupees,0))) desc;
end;
$$;

revoke execute on function public.founder_r3557_variance_impact_digest() from public, anon;
grant execute on function public.founder_r3557_variance_impact_digest() to authenticated;

-- 8) High-risk queue (at-risk / unfavorable / large-variance / worsening lines)
create or replace function public.founder_r3557_high_risk_queue()
returns table(
  line_code text,
  line_item text,
  category text,
  cost_center text,
  period_month date,
  latest_estimate_rupees numeric,
  variance_rupees numeric,
  variance_pct numeric,
  forecast_status text,
  trend_dir text,
  owner text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.line_code, l.line_item, l.category, l.cost_center, l.period_month,
    l.latest_estimate_rupees, l.variance_rupees, l.variance_pct,
    l.forecast_status, l.trend_dir, l.owner, l.notes
  from public.budget_reforecast_r3557 l
  where l.forecast_status in ('at_risk','unfavorable','revised')
     or abs(coalesce(l.variance_pct,0)) >= 10
     or l.trend_dir = 'worsening'
  order by abs(coalesce(l.variance_pct,0)) desc, l.variance_rupees desc;
end;
$$;

revoke execute on function public.founder_r3557_high_risk_queue() from public, anon;
grant execute on function public.founder_r3557_high_risk_queue() to authenticated;
