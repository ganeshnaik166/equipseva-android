-- Round 3477: Founder EBITDA Margin-Bridge / Cost-Lever Board
-- Decompose EBITDA change into revenue / cost-lever effects — business unit x cost lever x period x
-- base/lever/actual EBITDA x margin vs target x lever category x impact direction x variance verdict x
-- trend x CAPA closure. Founder-gated rollups.

-- =============================================================================
-- TABLE 1: ebitda_bridge_r3477 — per-lever EBITDA bridge entries
-- =============================================================================
create table if not exists public.ebitda_bridge_r3477 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bridge_ref text not null,
  business_unit text not null,
  cost_lever text not null,
  period_month date not null,
  base_ebitda_rupees numeric(14,2),
  lever_effect_rupees numeric(14,2),
  actual_ebitda_rupees numeric(14,2),
  ebitda_margin_pct numeric(6,2),
  target_margin_pct numeric(6,2),
  revenue_rupees numeric(14,2),
  lever_category text not null check (lever_category in (
    'revenue_growth','price','cogs','opex','headcount','one_time'
  )),
  impact_direction text not null check (impact_direction in (
    'accretive','dilutive','neutral'
  )),
  variance_verdict text not null check (variance_verdict in (
    'favorable','neutral','unfavorable'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ebitda_bridge_r3477 enable row level security;

create index if not exists idx_ebitda_bridge_r3477_org on public.ebitda_bridge_r3477(organization_id);
create index if not exists idx_ebitda_bridge_r3477_month on public.ebitda_bridge_r3477(period_month);
create index if not exists idx_ebitda_bridge_r3477_verdict on public.ebitda_bridge_r3477(variance_verdict);

-- =============================================================================
-- TABLE 2: ebitda_bridge_capa_actions_r3477 — CAPA & cost-lever corrective actions
-- =============================================================================
create table if not exists public.ebitda_bridge_capa_actions_r3477 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bridge_id uuid references public.ebitda_bridge_r3477(id) on delete cascade,
  bridge_ref text not null,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'margin_below_target','cogs_overrun','opex_overrun','price_erosion',
    'headcount_bloat','one_time_charge','revenue_shortfall','forecast_miss'
  )),
  root_cause text not null check (root_cause in (
    'input_cost_inflation','vendor_price_increase','labor_cost_increase','discounting_pressure',
    'volume_shortfall','process_inefficiency','fx_impact','one_time_provision',
    'pending_investigation','forecast_error'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_supplier_contract','revise_pricing','optimize_headcount','automate_process',
    'tighten_discount_policy','cost_control_program','revenue_acceleration','none_required',
    'vendor_consolidation','budget_reforecast'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  ebitda_at_risk_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ebitda_bridge_capa_actions_r3477 enable row level security;

create index if not exists idx_ebitda_bridge_capa_r3477_bridge on public.ebitda_bridge_capa_actions_r3477(bridge_id);
create index if not exists idx_ebitda_bridge_capa_r3477_status on public.ebitda_bridge_capa_actions_r3477(capa_status);

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

  -- 16 EBITDA bridge rows
  insert into public.ebitda_bridge_r3477 (
    organization_id, bridge_ref, business_unit, cost_lever, period_month,
    base_ebitda_rupees, lever_effect_rupees, actual_ebitda_rupees,
    ebitda_margin_pct, target_margin_pct, revenue_rupees,
    lever_category, impact_direction, variance_verdict, trend_dir, owner, notes
  )
  select v_org_id, q.bref, q.bu, q.lever, q.pmonth::date,
    q.base_e, q.lever_e, q.actual_e,
    q.margin, q.tmargin, q.rev,
    q.lcat, q.impdir, q.vverdict, q.tdir, q.own, q.nt
  from (values
    ('EBB-2606-01','Field Service','Spare-parts cost renegotiation','2026-06-01',
     4200000,350000,4550000,18.6,20.0,24500000,'cogs','accretive','favorable','improving','Rahul Menon','Alternate spares vendor cut input cost, margin recovering toward target'),
    ('EBB-2606-02','Field Service','Engineer overtime spend','2026-06-01',
     4200000,-280000,3920000,16.0,20.0,24500000,'opex','dilutive','unfavorable','worsening','Rahul Menon','Field overtime running hot on emergency callouts, dragging EBITDA'),
    ('EBB-2606-03','Spares & Consumables','Vendor price increase pass-through','2026-06-01',
     3100000,190000,3290000,21.4,19.0,15400000,'price','accretive','favorable','improving','Sneha Iyer','List-price uplift on consumables passed through cleanly'),
    ('EBB-2606-04','Spares & Consumables','Import duty COGS inflation','2026-06-01',
     3100000,-420000,2680000,17.4,19.0,15400000,'cogs','dilutive','unfavorable','worsening','Sneha Iyer','Customs duty hike on imported probes raised landed cost'),
    ('EBB-2606-05','AMC Contracts','AMC renewal price uplift','2026-06-01',
     5600000,640000,6240000,28.4,26.0,22000000,'price','accretive','favorable','improving','Vikram Rao','Annual AMC renewals repriced 8 percent, well above target margin'),
    ('EBB-2606-06','AMC Contracts','Field visit fuel & travel','2026-06-01',
     5600000,-150000,5450000,24.8,26.0,22000000,'opex','dilutive','unfavorable','stable','Vikram Rao','Fuel and travel creep on upcountry AMC visits'),
    ('EBB-2606-07','Rentals','Rental fleet utilization gain','2026-06-01',
     2400000,310000,2710000,22.6,21.0,12000000,'revenue_growth','accretive','favorable','improving','Anita Desai','Higher ventilator rental utilization lifted contribution'),
    ('EBB-2606-08','Installation','New-hire ramp headcount','2026-06-01',
     1800000,-520000,1280000,12.8,18.0,10000000,'headcount','dilutive','unfavorable','worsening','Karthik Nair','Installation team over-hired ahead of pipeline, margin well below target'),
    ('EBB-2606-09','Corporate','ERP migration one-time cost','2026-06-01',
     8000000,-900000,7100000,15.0,17.0,47300000,'one_time','dilutive','unfavorable','stable','Meera Kapoor','One-time ERP cutover cost booked in month, non-recurring'),
    ('EBB-2605-01','Field Service','Spare-parts cost renegotiation','2026-05-01',
     4000000,120000,4120000,17.5,20.0,23500000,'cogs','accretive','neutral','improving','Rahul Menon','Early sourcing savings starting to show, still short of target'),
    ('EBB-2605-02','Spares & Consumables','Vendor consolidation savings','2026-05-01',
     3000000,260000,3260000,20.9,19.0,15600000,'cogs','accretive','favorable','improving','Sneha Iyer','Consolidated to two national distributors, volume rebate captured'),
    ('EBB-2605-03','AMC Contracts','Contract churn revenue loss','2026-05-01',
     5400000,-380000,5020000,23.5,26.0,21400000,'revenue_growth','dilutive','unfavorable','worsening','Vikram Rao','Two large AMC accounts churned, recurring revenue base eroded'),
    ('EBB-2605-04','Rentals','Rental discount pressure','2026-05-01',
     2300000,-90000,2210000,19.2,21.0,11500000,'price','dilutive','unfavorable','stable','Anita Desai','Competitive discounting on rental tenders squeezed price realization'),
    ('EBB-2604-01','Corporate','Marketing opex optimization','2026-04-01',
     7600000,230000,7830000,16.8,17.0,46600000,'opex','accretive','neutral','stable','Meera Kapoor','Shifted spend to performance channels, modest opex saving'),
    ('EBB-2604-02','Field Service','Warranty claim provision','2026-04-01',
     3900000,-340000,3560000,15.6,20.0,22800000,'one_time','dilutive','unfavorable','worsening','Rahul Menon','Extra warranty provision on a recalled infusion pump batch'),
    ('EBB-2603-01','Installation','Automation productivity gain','2026-03-01',
     1700000,410000,2110000,19.5,18.0,10800000,'opex','accretive','favorable','improving','Karthik Nair','Install checklist automation cut rework hours, beat target')
  ) as q(bref, bu, lever, pmonth, base_e, lever_e, actual_e, margin, tmargin, rev, lcat, impdir, vverdict, tdir, own, nt);

  -- CAPA seed — attach to specific bridge entries via bridge_ref
  insert into public.ebitda_bridge_capa_actions_r3477 (
    organization_id, bridge_id, bridge_ref, finding_category, root_cause, corrective_action,
    capa_status, ebitda_at_risk_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.bref, q.fc, q.rc, q.ca,
    q.cst, q.risk, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EBB-2606-02','opex_overrun','labor_cost_increase','optimize_headcount','in_progress',280000,'Rahul Menon','2026-08-15',null,'Shift-roster rebalancing underway to cut emergency overtime'),
    ('EBB-2606-04','cogs_overrun','input_cost_inflation','renegotiate_supplier_contract','open',420000,'Sneha Iyer','2026-08-30',null,'Sourcing alternate probe vendors to offset import duty spike'),
    ('EBB-2606-08','headcount_bloat','labor_cost_increase','optimize_headcount','escalated',520000,'Karthik Nair','2026-08-10',null,'Installation utilization plan escalated to COO for hiring freeze'),
    ('EBB-2606-09','one_time_charge','one_time_provision','budget_reforecast','verification_pending',900000,'Meera Kapoor','2026-07-31',null,'ERP one-time cost excluded from run-rate, reforecast pending sign-off'),
    ('EBB-2606-06','opex_overrun','process_inefficiency','cost_control_program','open',150000,'Vikram Rao','2026-09-05',null,'Route optimization program launched for upcountry AMC visits'),
    ('EBB-2605-03','revenue_shortfall','volume_shortfall','revenue_acceleration','in_progress',380000,'Vikram Rao','2026-08-20',null,'Win-back campaign running on churned AMC accounts'),
    ('EBB-2604-02','one_time_charge','one_time_provision','none_required','closed',340000,'Rahul Menon','2026-05-31','2026-05-28','Warranty provision one-off, closed with no recurring impact'),
    ('EBB-2605-04','margin_below_target','discounting_pressure','tighten_discount_policy','overdue',90000,'Anita Desai','2026-06-30',null,'Rental discount policy revision overdue, margin still eroding')
  ) as q(bref, fc, rc, ca, cst, risk, own, tcd, acd, nt)
  join public.ebitda_bridge_r3477 e
    on e.organization_id = v_org_id and e.bridge_ref = q.bref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Variance verdict distribution
create or replace function public.founder_r3477_variance_verdict_rollup()
returns table(variance_verdict text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ebitda_bridge_r3477)
  select l.variance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ebitda_bridge_r3477 l
  group by l.variance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3477_variance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3477_variance_verdict_rollup() to authenticated;

-- 2) Lever category scorecard
create or replace function public.founder_r3477_lever_category_scorecard()
returns table(
  lever_category text,
  entries bigint,
  favorable bigint,
  neutral bigint,
  unfavorable bigint,
  accretive bigint,
  total_lever_effect_rupees numeric,
  avg_margin_pct numeric,
  avg_target_margin_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lever_category,
    count(*)::bigint,
    count(*) filter (where l.variance_verdict = 'favorable')::bigint,
    count(*) filter (where l.variance_verdict = 'neutral')::bigint,
    count(*) filter (where l.variance_verdict = 'unfavorable')::bigint,
    count(*) filter (where l.impact_direction = 'accretive')::bigint,
    coalesce(sum(l.lever_effect_rupees),0)::numeric,
    round(avg(l.ebitda_margin_pct), 2),
    round(avg(l.target_margin_pct), 2)
  from public.ebitda_bridge_r3477 l
  group by l.lever_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3477_lever_category_scorecard() from public, anon;
grant execute on function public.founder_r3477_lever_category_scorecard() to authenticated;

-- 3) Lever category x impact direction matrix
create or replace function public.founder_r3477_lever_impact_matrix()
returns table(
  lever_category text,
  impact_direction text,
  entries bigint,
  total_lever_effect_rupees numeric,
  favorable bigint,
  unfavorable bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lever_category, l.impact_direction, count(*)::bigint,
    coalesce(sum(l.lever_effect_rupees),0)::numeric,
    count(*) filter (where l.variance_verdict = 'favorable')::bigint,
    count(*) filter (where l.variance_verdict = 'unfavorable')::bigint
  from public.ebitda_bridge_r3477 l
  group by l.lever_category, l.impact_direction
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3477_lever_impact_matrix() from public, anon;
grant execute on function public.founder_r3477_lever_impact_matrix() to authenticated;

-- 4) Monthly EBITDA trend
create or replace function public.founder_r3477_monthly_ebitda_trend()
returns table(
  period_month date,
  entries bigint,
  total_base_ebitda_rupees numeric,
  total_lever_effect_rupees numeric,
  total_actual_ebitda_rupees numeric,
  avg_margin_pct numeric,
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
    coalesce(sum(l.base_ebitda_rupees),0)::numeric,
    coalesce(sum(l.lever_effect_rupees),0)::numeric,
    coalesce(sum(l.actual_ebitda_rupees),0)::numeric,
    round(avg(l.ebitda_margin_pct), 2),
    count(*) filter (where l.variance_verdict = 'unfavorable')::bigint
  from public.ebitda_bridge_r3477 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3477_monthly_ebitda_trend() from public, anon;
grant execute on function public.founder_r3477_monthly_ebitda_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3477_capa_status_board()
returns table(capa_status text, findings bigint, total_ebitda_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.ebitda_at_risk_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ebitda_bridge_capa_actions_r3477 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3477_capa_status_board() from public, anon;
grant execute on function public.founder_r3477_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3477_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_ebitda_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ebitda_bridge_capa_actions_r3477)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.ebitda_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ebitda_bridge_capa_actions_r3477 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3477_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3477_root_cause_pareto() to authenticated;

-- 7) EBITDA impact digest
create or replace function public.founder_r3477_ebitda_impact_digest()
returns table(
  impact_direction text,
  entries bigint,
  total_lever_effect_rupees numeric,
  avg_margin_pct numeric,
  unfavorable bigint,
  worsening bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.impact_direction,
    count(*)::bigint,
    coalesce(sum(l.lever_effect_rupees),0)::numeric,
    round(avg(l.ebitda_margin_pct), 2),
    count(*) filter (where l.variance_verdict = 'unfavorable')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.ebitda_bridge_r3477 l
  group by l.impact_direction
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3477_ebitda_impact_digest() from public, anon;
grant execute on function public.founder_r3477_ebitda_impact_digest() to authenticated;

-- 8) High-risk queue (unfavorable / dilutive / worsening)
create or replace function public.founder_r3477_high_risk_queue()
returns table(
  business_unit text,
  bridge_ref text,
  cost_lever text,
  lever_category text,
  period_month date,
  variance_verdict text,
  impact_direction text,
  trend_dir text,
  lever_effect_rupees numeric,
  ebitda_margin_pct numeric,
  target_margin_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.bridge_ref, l.cost_lever, l.lever_category, l.period_month,
    l.variance_verdict, l.impact_direction, l.trend_dir, l.lever_effect_rupees,
    l.ebitda_margin_pct, l.target_margin_pct, l.notes
  from public.ebitda_bridge_r3477 l
  where l.variance_verdict = 'unfavorable'
     or l.impact_direction = 'dilutive'
     or l.trend_dir = 'worsening'
     or l.ebitda_margin_pct < l.target_margin_pct
  order by l.period_month desc, l.lever_effect_rupees asc;
end;
$$;

revoke execute on function public.founder_r3477_high_risk_queue() from public, anon;
grant execute on function public.founder_r3477_high_risk_queue() to authenticated;
