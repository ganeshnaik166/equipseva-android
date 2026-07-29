-- Round 3592: Founder Revenue-per-Employee / Productivity & Efficiency Board
-- Per-business-unit revenue-per-employee, EBITDA/cost per employee, utilization, productivity index,
-- efficiency status, monthly trend, and CAPA closure across EquipSeva business units.

-- =============================================================================
-- TABLE 1: rev_per_employee_r3592 — per-BU / per-month productivity & efficiency facts
-- =============================================================================
create table if not exists public.rev_per_employee_r3592 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  unit_code text not null,
  business_unit text not null,
  period_month date not null,
  headcount int not null,
  revenue_rupees numeric(16,2),
  revenue_per_employee_rupees numeric(16,2),
  ebitda_per_employee_rupees numeric(16,2),
  cost_per_employee_rupees numeric(16,2),
  target_rev_per_employee_rupees numeric(16,2),
  utilization_pct numeric(5,2),
  productivity_index numeric(6,2),
  efficiency_status text not null check (efficiency_status in (
    'high_performing','on_target','below_target','underproductive'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rev_per_employee_r3592 enable row level security;

create index if not exists idx_rev_per_employee_r3592_org on public.rev_per_employee_r3592(organization_id);
create index if not exists idx_rev_per_employee_r3592_month on public.rev_per_employee_r3592(period_month);
create index if not exists idx_rev_per_employee_r3592_status on public.rev_per_employee_r3592(efficiency_status);

-- =============================================================================
-- TABLE 2: rev_per_employee_capa_actions_r3592 — CAPA & productivity-recovery actions
-- =============================================================================
create table if not exists public.rev_per_employee_capa_actions_r3592 (
  id uuid primary key default gen_random_uuid(),
  rec_id uuid not null references public.rev_per_employee_r3592(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'below_target_revenue_per_employee','low_utilization','high_cost_per_employee',
    'negative_ebitda_per_employee','productivity_decline','headcount_overstaffing',
    'revenue_concentration_risk','skill_gap'
  )),
  root_cause text not null check (root_cause in (
    'overstaffing','low_billable_utilization','pricing_pressure','high_bench_time',
    'process_inefficiency','attrition_backfill_lag','tooling_gaps','demand_shortfall',
    'pending_investigation','training_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'rebalance_headcount','improve_utilization_scheduling','reprice_contracts','upskill_team',
    'automate_workflow','consolidate_roles','redeploy_to_high_demand','hiring_freeze',
    'launch_productivity_program','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  productivity_impact_rupees numeric(16,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rev_per_employee_capa_actions_r3592 enable row level security;

create index if not exists idx_rev_per_employee_capa_r3592_rec on public.rev_per_employee_capa_actions_r3592(rec_id);
create index if not exists idx_rev_per_employee_capa_r3592_status on public.rev_per_employee_capa_actions_r3592(capa_status);

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

  -- 16 productivity fact rows
  insert into public.rev_per_employee_r3592 (
    organization_id, unit_code, business_unit, period_month, headcount, revenue_rupees,
    revenue_per_employee_rupees, ebitda_per_employee_rupees, cost_per_employee_rupees,
    target_rev_per_employee_rupees, utilization_pct, productivity_index,
    efficiency_status, trend_dir, notes
  )
  select v_org_id, q.uc, q.bu, q.pm::date, q.hc, q.rev,
    q.rpe, q.epe, q.cpe,
    q.trpe, q.util, q.pidx,
    q.es, q.td, q.nt
  from (values
    ('RPE-FS-2605','Field Service','2026-05-01',42,63000000,
     1500000,260000,1120000,1450000,84.5,1.06,'on_target','stable','Field service revenue-per-engineer at plan; overtime normalising'),
    ('RPE-FS-2606','Field Service','2026-06-01',44,70400000,
     1600000,300000,1130000,1450000,86.0,1.10,'high_performing','improving','Higher first-visit-fix rate lifting billable hours per engineer'),
    ('RPE-FS-2607','Field Service','2026-07-01',45,74250000,
     1650000,320000,1140000,1500000,87.2,1.12,'high_performing','improving','Best-in-class RPE; dispatch optimisation sustaining gains'),
    ('RPE-SP-2606','Spare Parts & Consumables','2026-06-01',28,47600000,
     1700000,420000,980000,1500000,80.0,1.14,'high_performing','stable','Parts margin steady; SKU rationalisation holding cost/head down'),
    ('RPE-SP-2607','Spare Parts & Consumables','2026-07-01',29,50750000,
     1750000,430000,990000,1550000,81.5,1.15,'high_performing','improving','E-commerce spares channel driving revenue-per-head up'),
    ('RPE-AMC-2606','AMC Contracts','2026-06-01',36,39600000,
     1100000,180000,900000,1300000,72.0,0.88,'below_target','worsening','AMC RPE below plan; contract pricing lagging cost inflation'),
    ('RPE-AMC-2607','AMC Contracts','2026-07-01',37,40700000,
     1100000,170000,910000,1300000,71.0,0.86,'below_target','worsening','Renewal repricing not yet landed; utilization still soft'),
    ('RPE-CAL-2606','Calibration Lab','2026-06-01',14,15400000,
     1100000,240000,820000,1200000,78.0,0.95,'below_target','stable','Cal-lab RPE just under target pending accreditation-scope expansion'),
    ('RPE-CAL-2607','Calibration Lab','2026-07-01',15,18000000,
     1200000,280000,830000,1200000,82.0,1.02,'on_target','improving','NABL scope widened; RPE recovered to target in July'),
    ('RPE-RNT-2606','Equipment Rentals','2026-06-01',12,9600000,
     800000,90000,760000,1200000,64.0,0.68,'underproductive','worsening','Rental fleet idle; low utilization dragging RPE well below target'),
    ('RPE-RNT-2607','Equipment Rentals','2026-07-01',12,10800000,
     900000,110000,770000,1200000,67.0,0.74,'underproductive','improving','Redeployment to metro demand lifting utilization off the floor'),
    ('RPE-RFB-2606','Refurbishment','2026-06-01',20,24000000,
     1200000,210000,950000,1250000,76.5,0.98,'on_target','stable','Refurb throughput steady; RPE near target with healthy margin'),
    ('RPE-RFB-2607','Refurbishment','2026-07-01',21,23100000,
     1100000,150000,960000,1250000,73.0,0.90,'below_target','worsening','Bench time rising as intake dipped; RPE slipped below target'),
    ('RPE-DIG-2606','Digital / SaaS','2026-06-01',18,36000000,
     2000000,700000,1050000,1600000,88.0,1.28,'high_performing','improving','SaaS ARR per head highest in portfolio; strong gross margin'),
    ('RPE-DIG-2607','Digital / SaaS','2026-07-01',19,39900000,
     2100000,740000,1060000,1600000,89.0,1.30,'high_performing','improving','Platform seat expansion driving record revenue-per-employee'),
    ('RPE-TKP-2607','Turnkey Projects','2026-07-01',16,12800000,
     800000,40000,900000,1400000,58.0,0.60,'underproductive','worsening','Turnkey team overstaffed vs thin pipeline; negative EBITDA/head')
  ) as q(uc, bu, pm, hc, rev, rpe, epe, cpe, trpe, util, pidx, es, td, nt);

  -- CAPA seed — attach to specific fact rows via unit_code business key
  insert into public.rev_per_employee_capa_actions_r3592 (
    rec_id, finding_category, root_cause, corrective_action,
    capa_status, productivity_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('RPE-AMC-2607','below_target_revenue_per_employee','pricing_pressure','reprice_contracts','in_progress',7400000,'BU Head - AMC','2026-08-15',null,'AMC renewal repricing underway across ~40 contracts to close RPE gap'),
    ('RPE-AMC-2606','productivity_decline','process_inefficiency','automate_workflow','open',3200000,'Service Ops','2026-08-31',null,'PM scheduling automation to raise technician billable utilization'),
    ('RPE-RNT-2606','low_utilization','demand_shortfall','redeploy_to_high_demand','in_progress',5100000,'Rentals Lead','2026-08-20',null,'Idle rental fleet redeployed to high-demand metro accounts'),
    ('RPE-TKP-2607','negative_ebitda_per_employee','overstaffing','rebalance_headcount','escalated',9600000,'COO Office','2026-08-10',null,'Turnkey team overstaffed vs pipeline — escalated to board for rebalance'),
    ('RPE-RFB-2607','productivity_decline','high_bench_time','improve_utilization_scheduling','open',2800000,'Refurb Lead','2026-09-05',null,'Refurb bench time rising — tighten intake-to-job scheduling'),
    ('RPE-RNT-2607','high_cost_per_employee','low_billable_utilization','launch_productivity_program','verification_pending',1900000,'Rentals Lead','2026-07-31',null,'Utilization recovery program showing early gains — verifying sustained lift'),
    ('RPE-CAL-2606','below_target_revenue_per_employee','tooling_gaps','upskill_team','closed',1200000,'Cal Lab Head','2026-07-10','2026-07-08','Calibration team upskilled on new scope; July RPE recovered to target'),
    ('RPE-AMC-2606','headcount_overstaffing','overstaffing','consolidate_roles','overdue',4500000,'HRBP','2026-07-05',null,'Role consolidation past due date — needs escalation to COO')
  ) as q(uc, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.rev_per_employee_r3592 e
    on e.organization_id = v_org_id and e.unit_code = q.uc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Efficiency-status distribution
create or replace function public.founder_r3592_efficiency_status_rollup()
returns table(efficiency_status text, units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rev_per_employee_r3592)
  select l.efficiency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.rev_per_employee_r3592 l
  group by l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3592_efficiency_status_rollup() from public, anon;
grant execute on function public.founder_r3592_efficiency_status_rollup() to authenticated;

-- 2) Business-unit productivity scorecard
create or replace function public.founder_r3592_business_unit_scorecard()
returns table(
  business_unit text,
  records bigint,
  avg_rev_per_employee_rupees numeric,
  avg_ebitda_per_employee_rupees numeric,
  avg_cost_per_employee_rupees numeric,
  avg_utilization_pct numeric,
  avg_productivity_index numeric,
  below_or_under bigint
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
    round(avg(l.revenue_per_employee_rupees), 0),
    round(avg(l.ebitda_per_employee_rupees), 0),
    round(avg(l.cost_per_employee_rupees), 0),
    round(avg(l.utilization_pct), 1),
    round(avg(l.productivity_index), 2),
    count(*) filter (where l.efficiency_status in ('below_target','underproductive'))::bigint
  from public.rev_per_employee_r3592 l
  group by l.business_unit
  order by round(avg(l.revenue_per_employee_rupees), 0) desc;
end;
$$;

revoke execute on function public.founder_r3592_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3592_business_unit_scorecard() to authenticated;

-- 3) Business-unit × efficiency-status matrix
create or replace function public.founder_r3592_bu_efficiency_matrix()
returns table(business_unit text, efficiency_status text, records bigint, avg_rev_per_employee_rupees numeric, avg_productivity_index numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.efficiency_status, count(*)::bigint,
    round(avg(l.revenue_per_employee_rupees), 0),
    round(avg(l.productivity_index), 2)
  from public.rev_per_employee_r3592 l
  group by l.business_unit, l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3592_bu_efficiency_matrix() from public, anon;
grant execute on function public.founder_r3592_bu_efficiency_matrix() to authenticated;

-- 4) Monthly revenue-per-employee trend
create or replace function public.founder_r3592_monthly_rpe_trend()
returns table(period_month date, records bigint, total_headcount bigint, total_revenue_rupees numeric, avg_rev_per_employee_rupees numeric, avg_productivity_index numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.headcount),0)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    round(avg(l.revenue_per_employee_rupees), 0),
    round(avg(l.productivity_index), 2)
  from public.rev_per_employee_r3592 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3592_monthly_rpe_trend() from public, anon;
grant execute on function public.founder_r3592_monthly_rpe_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3592_capa_status_board()
returns table(capa_status text, actions bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.productivity_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.rev_per_employee_capa_actions_r3592 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3592_capa_status_board() from public, anon;
grant execute on function public.founder_r3592_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3592_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rev_per_employee_capa_actions_r3592)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.productivity_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.rev_per_employee_capa_actions_r3592 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3592_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3592_root_cause_pareto() to authenticated;

-- 7) Productivity-impact digest (by finding category)
create or replace function public.founder_r3592_productivity_impact_digest()
returns table(finding_category text, actions bigint, open_actions bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.productivity_impact_rupees),0)::numeric
  from public.rev_per_employee_capa_actions_r3592 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3592_productivity_impact_digest() from public, anon;
grant execute on function public.founder_r3592_productivity_impact_digest() to authenticated;

-- 8) High-risk (underproductive / below-target) queue
create or replace function public.founder_r3592_high_risk_queue()
returns table(
  business_unit text,
  unit_code text,
  period_month date,
  efficiency_status text,
  trend_dir text,
  revenue_per_employee_rupees numeric,
  target_rev_per_employee_rupees numeric,
  utilization_pct numeric,
  productivity_index numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.unit_code, l.period_month, l.efficiency_status, l.trend_dir,
    l.revenue_per_employee_rupees, l.target_rev_per_employee_rupees, l.utilization_pct,
    l.productivity_index, l.notes
  from public.rev_per_employee_r3592 l
  where l.efficiency_status in ('below_target','underproductive')
     or l.trend_dir = 'worsening'
     or l.revenue_per_employee_rupees < l.target_rev_per_employee_rupees
     or l.utilization_pct < 70
     or l.productivity_index < 0.90
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3592_high_risk_queue() from public, anon;
grant execute on function public.founder_r3592_high_risk_queue() to authenticated;
