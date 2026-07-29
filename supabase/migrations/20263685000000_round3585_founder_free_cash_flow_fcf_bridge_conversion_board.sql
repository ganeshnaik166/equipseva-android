-- Round 3585: Founder Free-Cash-Flow (FCF) Bridge / Conversion Board
-- Founder FCF bridge — EBITDA -> operating cash -> FCF, cash-conversion % per period/business unit + CAPA

-- =============================================================================
-- TABLE 1: fcf_bridge_r3585 — per business-unit / month FCF bridge & conversion
-- =============================================================================
create table if not exists public.fcf_bridge_r3585 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bridge_code text not null,
  business_unit text not null,
  period_month date not null,
  ebitda_rupees numeric(14,2),
  working_capital_change_rupees numeric(14,2),
  tax_paid_rupees numeric(14,2),
  capex_rupees numeric(14,2),
  operating_cash_flow_rupees numeric(14,2),
  free_cash_flow_rupees numeric(14,2),
  fcf_conversion_pct numeric(6,2),
  target_conversion_pct numeric(6,2),
  conversion_status text not null check (conversion_status in (
    'strong','on_target','weak','cash_burn'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fcf_bridge_r3585 enable row level security;

create index if not exists idx_fcf_bridge_r3585_org on public.fcf_bridge_r3585(organization_id);
create index if not exists idx_fcf_bridge_r3585_month on public.fcf_bridge_r3585(period_month);
create index if not exists idx_fcf_bridge_r3585_status on public.fcf_bridge_r3585(conversion_status);

-- =============================================================================
-- TABLE 2: fcf_bridge_capa_actions_r3585 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.fcf_bridge_capa_actions_r3585 (
  id uuid primary key default gen_random_uuid(),
  bridge_id uuid not null references public.fcf_bridge_r3585(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'working_capital_bloat','capex_overrun','ebitda_shortfall','tax_outflow_spike',
    'receivables_aging','inventory_buildup','payables_stretch_reversal',
    'fcf_conversion_miss','cash_burn','one_time_outflow'
  )),
  root_cause text not null check (root_cause in (
    'collections_delay','inventory_overstock','vendor_prepayment','capex_front_loading',
    'demand_shortfall','pricing_pressure','advance_tax_timing','project_cost_overrun',
    'pending_investigation','seasonal_wc_swing'
  )),
  corrective_action text not null check (corrective_action in (
    'tighten_collections','reduce_inventory_dio','renegotiate_vendor_terms','defer_noncritical_capex',
    'pricing_review','cost_rationalization','stagger_tax_payments','capex_phasing_plan',
    'escalate_to_board','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cash_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fcf_bridge_capa_actions_r3585 enable row level security;

create index if not exists idx_fcf_bridge_capa_r3585_bridge on public.fcf_bridge_capa_actions_r3585(bridge_id);
create index if not exists idx_fcf_bridge_capa_r3585_status on public.fcf_bridge_capa_actions_r3585(capa_status);

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

  -- 16 FCF bridge rows
  insert into public.fcf_bridge_r3585 (
    organization_id, bridge_code, business_unit, period_month,
    ebitda_rupees, working_capital_change_rupees, tax_paid_rupees, capex_rupees,
    operating_cash_flow_rupees, free_cash_flow_rupees, fcf_conversion_pct, target_conversion_pct,
    conversion_status, trend_dir, notes
  )
  select v_org_id, q.bcode, q.bu, q.pmonth::date,
    q.ebitda, q.wcchg, q.tax, q.capex,
    q.ocf, q.fcf, q.convpct, q.tgtpct,
    q.cstatus, q.tdir, q.nt
  from (values
    ('FCF-AMC-2604','amc_services','2026-04-01',
     5200000,400000,1100000,300000,4500000,4200000,80.8,75.0,'strong','improving','AMC recurring cash strong; collections ahead of plan'),
    ('FCF-AMC-2605','amc_services','2026-05-01',
     5400000,300000,1150000,350000,4550000,4200000,77.8,75.0,'strong','stable','AMC steady; renewals invoiced and collected on time'),
    ('FCF-AMC-2606','amc_services','2026-06-01',
     5600000,200000,1200000,400000,4600000,4200000,75.0,75.0,'on_target','stable','AMC at target; slight working-capital drag from spares float'),
    ('FCF-SPR-2604','spare_parts','2026-04-01',
     3800000,-1500000,800000,250000,1500000,1250000,32.9,60.0,'weak','worsening','Spare-parts inventory build-up choking cash conversion'),
    ('FCF-SPR-2605','spare_parts','2026-05-01',
     3900000,-1200000,820000,200000,1880000,1680000,43.1,60.0,'weak','improving','Inventory drawdown started; still below conversion target'),
    ('FCF-SPR-2606','spare_parts','2026-06-01',
     4000000,-600000,850000,200000,2550000,2350000,58.8,60.0,'on_target','improving','DIO reduction lifting conversion near target'),
    ('FCF-RNT-2604','equipment_rental','2026-04-01',
     4600000,100000,950000,3200000,3750000,550000,12.0,40.0,'weak','worsening','Rental fleet capex front-loaded; FCF thin this month'),
    ('FCF-RNT-2605','equipment_rental','2026-05-01',
     4700000,150000,980000,2800000,3870000,1070000,22.8,40.0,'weak','improving','Capex tapering; conversion recovering off a low base'),
    ('FCF-RNT-2606','equipment_rental','2026-06-01',
     4800000,200000,1000000,1500000,4000000,2500000,52.1,40.0,'strong','improving','Fleet capex normalized; strong conversion above target'),
    ('FCF-PRJ-2604','turnkey_projects','2026-04-01',
     6200000,-6000000,1300000,900000,-1100000,-2000000,-32.3,50.0,'cash_burn','worsening','Milestone billing delayed; heavy WC drag turned FCF negative'),
    ('FCF-PRJ-2605','turnkey_projects','2026-05-01',
     6400000,-3000000,1350000,800000,2050000,1250000,19.5,50.0,'weak','improving','Partial milestone collection; conversion still weak'),
    ('FCF-PRJ-2606','turnkey_projects','2026-06-01',
     6600000,-800000,1400000,700000,4400000,3700000,56.1,50.0,'strong','improving','Collections caught up; project cash strong and above target'),
    ('FCF-CNS-2604','consumables','2026-04-01',
     2900000,250000,600000,150000,2550000,2400000,82.8,70.0,'strong','stable','Consumables high-velocity cash conversion'),
    ('FCF-CNS-2605','consumables','2026-05-01',
     3000000,100000,620000,150000,2480000,2330000,77.7,70.0,'strong','stable','Consumables steady conversion above target'),
    ('FCF-DGN-2604','diagnostics','2026-04-01',
     4100000,-900000,850000,2500000,2350000,-150000,-3.7,45.0,'cash_burn','worsening','Diagnostics lab expansion capex drove FCF negative'),
    ('FCF-DGN-2606','diagnostics','2026-06-01',
     4300000,-400000,900000,1200000,3000000,1800000,41.9,45.0,'weak','improving','Capex easing post-expansion; conversion recovering to near target')
  ) as q(bcode, bu, pmonth, ebitda, wcchg, tax, capex, ocf, fcf, convpct, tgtpct, cstatus, tdir, nt);

  -- CAPA seed — attach to specific bridges via bridge_code
  insert into public.fcf_bridge_capa_actions_r3585 (
    bridge_id, finding_category, root_cause, corrective_action,
    capa_status, cash_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('FCF-SPR-2604','inventory_buildup','inventory_overstock','reduce_inventory_dio','in_progress',1500000,'Ravi Kumar (Ops Finance)','2026-06-30',null,'DIO reduction plan; target 45 days for fast-moving spares'),
    ('FCF-RNT-2604','capex_overrun','capex_front_loading','defer_noncritical_capex','verification_pending',3200000,'Anita Desai (CFO Office)','2026-06-15',null,'Deferred Q1 fleet additions to H2; awaiting utilization uplift'),
    ('FCF-PRJ-2604','working_capital_bloat','collections_delay','tighten_collections','escalated',6000000,'Suresh Nair (Projects)','2026-05-31',null,'Milestone billing dispute escalated to board for resolution'),
    ('FCF-DGN-2604','capex_overrun','capex_front_loading','capex_phasing_plan','in_progress',2500000,'Priya Menon (Diagnostics)','2026-07-15',null,'Lab expansion capex phased over three quarters'),
    ('FCF-SPR-2605','receivables_aging','collections_delay','tighten_collections','closed',1200000,'Ravi Kumar (Ops Finance)','2026-05-25','2026-05-20','Overdue distributor receivables cleared and reconciled'),
    ('FCF-RNT-2605','fcf_conversion_miss','demand_shortfall','pricing_review','open',1070000,'Anita Desai (CFO Office)','2026-07-10',null,'Rental utilization below plan; pricing review underway'),
    ('FCF-PRJ-2605','working_capital_bloat','project_cost_overrun','cost_rationalization','in_progress',3000000,'Suresh Nair (Projects)','2026-06-30',null,'Cost overrun on turnkey install; rationalization ongoing'),
    ('FCF-DGN-2606','fcf_conversion_miss','pricing_pressure','pricing_review','verification_pending',800000,'Priya Menon (Diagnostics)','2026-07-20',null,'Diagnostics pricing pressure; margin review with sales'),
    ('FCF-PRJ-2604','tax_outflow_spike','advance_tax_timing','stagger_tax_payments','closed',1300000,'Anita Desai (CFO Office)','2026-05-15','2026-05-10','Advance-tax timing smoothed across the quarter')
  ) as q(bcode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.fcf_bridge_r3585 e
    on e.organization_id = v_org_id and e.bridge_code = q.bcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Conversion-status distribution
create or replace function public.founder_r3585_conversion_status_rollup()
returns table(conversion_status text, periods bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fcf_bridge_r3585)
  select l.conversion_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fcf_bridge_r3585 l
  group by l.conversion_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3585_conversion_status_rollup() from public, anon;
grant execute on function public.founder_r3585_conversion_status_rollup() to authenticated;

-- 2) Business-unit FCF scorecard
create or replace function public.founder_r3585_business_unit_scorecard()
returns table(
  business_unit text,
  periods bigint,
  strong bigint,
  on_target bigint,
  weak bigint,
  cash_burn bigint,
  avg_conversion_pct numeric,
  total_free_cash_flow_rupees numeric
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
    count(*) filter (where l.conversion_status = 'strong')::bigint,
    count(*) filter (where l.conversion_status = 'on_target')::bigint,
    count(*) filter (where l.conversion_status = 'weak')::bigint,
    count(*) filter (where l.conversion_status = 'cash_burn')::bigint,
    round(avg(l.fcf_conversion_pct), 1),
    coalesce(sum(l.free_cash_flow_rupees),0)::numeric
  from public.fcf_bridge_r3585 l
  group by l.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3585_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3585_business_unit_scorecard() to authenticated;

-- 3) Business-unit × conversion-status matrix
create or replace function public.founder_r3585_bu_conversion_matrix()
returns table(business_unit text, conversion_status text, periods bigint, avg_conversion_pct numeric, total_free_cash_flow_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.conversion_status, count(*)::bigint,
    round(avg(l.fcf_conversion_pct), 1),
    coalesce(sum(l.free_cash_flow_rupees),0)::numeric
  from public.fcf_bridge_r3585 l
  group by l.business_unit, l.conversion_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3585_bu_conversion_matrix() from public, anon;
grant execute on function public.founder_r3585_bu_conversion_matrix() to authenticated;

-- 4) Monthly FCF trend
create or replace function public.founder_r3585_monthly_fcf_trend()
returns table(period_month date, periods bigint, total_ebitda_rupees numeric, total_operating_cash_flow_rupees numeric, total_free_cash_flow_rupees numeric, avg_conversion_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.ebitda_rupees),0)::numeric,
    coalesce(sum(l.operating_cash_flow_rupees),0)::numeric,
    coalesce(sum(l.free_cash_flow_rupees),0)::numeric,
    round(avg(l.fcf_conversion_pct), 1)
  from public.fcf_bridge_r3585 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3585_monthly_fcf_trend() from public, anon;
grant execute on function public.founder_r3585_monthly_fcf_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3585_capa_status_board()
returns table(capa_status text, findings bigint, avg_cash_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cash_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.fcf_bridge_capa_actions_r3585 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3585_capa_status_board() from public, anon;
grant execute on function public.founder_r3585_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3585_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cash_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fcf_bridge_capa_actions_r3585)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cash_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fcf_bridge_capa_actions_r3585 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3585_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3585_root_cause_pareto() to authenticated;

-- 7) Cash-conversion impact digest
create or replace function public.founder_r3585_cash_conversion_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_cash_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.cash_impact_rupees),0)::numeric
  from public.fcf_bridge_capa_actions_r3585 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3585_cash_conversion_impact_digest() from public, anon;
grant execute on function public.founder_r3585_cash_conversion_impact_digest() to authenticated;

-- 8) High-risk (cash-burn / weak) conversion queue
create or replace function public.founder_r3585_high_risk_queue()
returns table(
  business_unit text,
  bridge_code text,
  period_month date,
  ebitda_rupees numeric,
  free_cash_flow_rupees numeric,
  fcf_conversion_pct numeric,
  target_conversion_pct numeric,
  conversion_status text,
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
  select l.business_unit, l.bridge_code, l.period_month, l.ebitda_rupees, l.free_cash_flow_rupees,
    l.fcf_conversion_pct, l.target_conversion_pct, l.conversion_status, l.trend_dir, l.notes
  from public.fcf_bridge_r3585 l
  where l.conversion_status in ('weak','cash_burn')
     or l.fcf_conversion_pct < l.target_conversion_pct
     or l.free_cash_flow_rupees < 0
     or l.trend_dir = 'worsening'
  order by l.free_cash_flow_rupees asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3585_high_risk_queue() from public, anon;
grant execute on function public.founder_r3585_high_risk_queue() to authenticated;
