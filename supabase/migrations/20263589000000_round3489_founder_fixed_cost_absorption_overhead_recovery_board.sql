-- Round 3489: Founder Fixed-Cost Absorption / Overhead Recovery Board
-- Overhead recovery vs applied per cost-center × period × fixed-cost pool × allocation base × applied/absorbed overhead × over/under absorption × absorption rate × capacity utilization × trend × CAPA

-- =============================================================================
-- TABLE 1: cost_absorption_overhead_r3489 — per cost-center / month overhead absorption fact
-- =============================================================================
create table if not exists public.cost_absorption_overhead_r3489 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cost_center text not null,
  line_ref text not null,
  period_month date not null,
  fixed_cost_pool_rupees numeric(14,2),
  allocation_base_units numeric(12,2),
  applied_overhead_rupees numeric(14,2),
  absorbed_rupees numeric(14,2),
  over_under_absorbed_rupees numeric(14,2),
  absorption_rate_pct numeric(6,2),
  capacity_utilization_pct numeric(6,2),
  absorption_status text not null check (absorption_status in (
    'over_absorbed','fully_absorbed','under_absorbed','severely_under'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cost_absorption_overhead_r3489 enable row level security;

create index if not exists idx_cost_absorption_overhead_r3489_org on public.cost_absorption_overhead_r3489(organization_id);
create index if not exists idx_cost_absorption_overhead_r3489_month on public.cost_absorption_overhead_r3489(period_month);
create index if not exists idx_cost_absorption_overhead_r3489_status on public.cost_absorption_overhead_r3489(absorption_status);

-- =============================================================================
-- TABLE 2: cost_absorption_overhead_capa_actions_r3489 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.cost_absorption_overhead_capa_actions_r3489 (
  id uuid primary key default gen_random_uuid(),
  absorption_line_id uuid not null references public.cost_absorption_overhead_r3489(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'under_absorption','over_absorption','low_capacity_utilization','allocation_base_error',
    'fixed_cost_overrun','rate_variance','idle_capacity','spending_variance'
  )),
  root_cause text not null check (root_cause in (
    'volume_shortfall','fixed_cost_inflation','allocation_base_misestimate','rate_setting_error',
    'idle_capacity','demand_drop','budgeting_error','pending_investigation','one_time_charge','capacity_expansion_lag'
  )),
  corrective_action text not null check (corrective_action in (
    'revise_overhead_rate','reforecast_volume','reallocate_fixed_costs','trim_fixed_cost_pool',
    'improve_capacity_utilization','update_allocation_base','absorb_to_cogs','escalate_to_cfo','reprice_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_class text not null check (impact_class in (
    'material_variance','budget_breach','margin_risk','minor_variance','immaterial'
  )),
  target_closure_date date,
  actual_closure_date date,
  impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cost_absorption_overhead_capa_actions_r3489 enable row level security;

create index if not exists idx_cost_absorption_capa_r3489_line on public.cost_absorption_overhead_capa_actions_r3489(absorption_line_id);
create index if not exists idx_cost_absorption_capa_r3489_status on public.cost_absorption_overhead_capa_actions_r3489(capa_status);

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

  -- 16 cost-center / month absorption rows
  insert into public.cost_absorption_overhead_r3489 (
    organization_id, cost_center, line_ref, period_month,
    fixed_cost_pool_rupees, allocation_base_units, applied_overhead_rupees, absorbed_rupees,
    over_under_absorbed_rupees, absorption_rate_pct, capacity_utilization_pct,
    absorption_status, trend_dir, notes
  )
  select v_org_id, q.cc, q.lref, q.pm::date,
    q.pool, q.base, q.applied, q.absorbed,
    q.ou, q.rate, q.cap,
    q.status, q.trend, q.nt
  from (values
    ('biomed_service_south','CC-BSS-2604','2026-04-01',
     1850000,2400,1790000,1790000,-60000,96.8,91.0,'under_absorbed','improving','Q1 under-absorption narrowing as job volume recovers'),
    ('biomed_service_south','CC-BSS-2605','2026-05-01',
     1850000,2600,1880000,1880000,30000,101.6,96.0,'over_absorbed','improving','May volume above plan — slight over-absorption'),
    ('biomed_service_south','CC-BSS-2606','2026-06-01',
     1900000,2550,1900000,1900000,0,100.0,95.0,'fully_absorbed','stable','June fully absorbed at planned overhead rate'),
    ('biomed_service_north','CC-BSN-2604','2026-04-01',
     1620000,1900,1360000,1360000,-260000,84.0,74.0,'severely_under','worsening','North region demand slump — severe under-absorption'),
    ('biomed_service_north','CC-BSN-2605','2026-05-01',
     1620000,1850,1330000,1330000,-290000,82.1,71.0,'severely_under','worsening','Continued shortfall; two large AMC contracts lost'),
    ('biomed_service_north','CC-BSN-2606','2026-06-01',
     1650000,2050,1520000,1520000,-130000,92.1,82.0,'under_absorbed','improving','Recovery underway after re-tender wins'),
    ('calibration_lab','CC-CAL-2604','2026-04-01',
     720000,1400,745000,745000,25000,103.5,98.0,'over_absorbed','stable','Cal lab near full capacity, mild over-absorption'),
    ('calibration_lab','CC-CAL-2605','2026-05-01',
     720000,1380,720000,720000,0,100.0,96.0,'fully_absorbed','stable','Balanced month for calibration lab'),
    ('calibration_lab','CC-CAL-2606','2026-06-01',
     740000,1300,700000,700000,-40000,94.6,90.0,'under_absorbed','worsening','Slight dip as one OEM calibration contract paused'),
    ('refurb_workshop','CC-RFW-2604','2026-04-01',
     1120000,900,980000,980000,-140000,87.5,78.0,'under_absorbed','stable','Refurb throughput below plan; spare-part delays'),
    ('refurb_workshop','CC-RFW-2605','2026-05-01',
     1120000,820,890000,890000,-230000,79.5,70.0,'severely_under','worsening','Import spares held at customs — output collapsed'),
    ('refurb_workshop','CC-RFW-2606','2026-06-01',
     1150000,1050,1160000,1160000,10000,100.9,97.0,'over_absorbed','improving','Backlog cleared — over-absorbed as volume surged'),
    ('field_logistics','CC-FLG-2605','2026-05-01',
     640000,3200,640000,640000,0,100.0,93.0,'fully_absorbed','stable','Fleet overhead fully recovered on service calls'),
    ('field_logistics','CC-FLG-2606','2026-06-01',
     660000,3050,705000,705000,45000,106.8,99.0,'over_absorbed','improving','High call density — fleet over-absorbed'),
    ('spares_warehouse','CC-SPW-2605','2026-05-01',
     540000,5200,430000,430000,-110000,79.6,68.0,'severely_under','worsening','Warehouse fixed cost high vs low pick volume'),
    ('spares_warehouse','CC-SPW-2606','2026-06-01',
     560000,5600,505000,505000,-55000,90.2,83.0,'under_absorbed','improving','Pick volume recovering; under-absorption easing')
  ) as q(cc, lref, pm, pool, base, applied, absorbed, ou, rate, cap, status, trend, nt);

  -- CAPA seed — attach to specific absorption lines via line_ref
  insert into public.cost_absorption_overhead_capa_actions_r3489 (
    absorption_line_id, finding_category, root_cause, corrective_action,
    capa_status, impact_class, target_closure_date, actual_closure_date,
    impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ic, q.tcd::date, q.acd::date,
    q.imp, q.nt
  from (values
    ('CC-BSN-2604','under_absorption','demand_drop','reforecast_volume','in_progress','budget_breach','2026-05-15',null,260000,'North region volume reforecast; sales push initiated'),
    ('CC-BSN-2605','low_capacity_utilization','volume_shortfall','improve_capacity_utilization','escalated','margin_risk','2026-06-10',null,290000,'Escalated to CFO — capacity redeployment plan'),
    ('CC-RFW-2605','idle_capacity','allocation_base_misestimate','update_allocation_base','open','material_variance','2026-06-20',null,230000,'Spares customs delay caused idle capacity; base revised'),
    ('CC-SPW-2605','fixed_cost_overrun','fixed_cost_inflation','trim_fixed_cost_pool','overdue','budget_breach','2026-06-15',null,110000,'Warehouse lease renegotiation overdue'),
    ('CC-RFW-2604','under_absorption','capacity_expansion_lag','reforecast_volume','closed','minor_variance','2026-05-10','2026-05-08',140000,'Throughput restored after spare-part backlog cleared'),
    ('CC-CAL-2606','rate_variance','rate_setting_error','revise_overhead_rate','verification_pending','minor_variance','2026-07-05',null,40000,'Overhead rate revised for paused OEM contract'),
    ('CC-BSN-2606','low_capacity_utilization','demand_drop','reprice_service','in_progress','margin_risk','2026-07-10',null,130000,'Repricing AMC renewals to recover fixed cost'),
    ('CC-SPW-2606','spending_variance','fixed_cost_inflation','reallocate_fixed_costs','open','minor_variance','2026-07-12',null,55000,'Reallocating warehouse overhead to fast-moving SKUs')
  ) as q(lref, fc, rc, ca, cst, ic, tcd, acd, imp, nt)
  join public.cost_absorption_overhead_r3489 e
    on e.organization_id = v_org_id and e.line_ref = q.lref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Absorption status distribution
create or replace function public.founder_r3489_absorption_status_rollup()
returns table(absorption_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cost_absorption_overhead_r3489)
  select l.absorption_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cost_absorption_overhead_r3489 l
  group by l.absorption_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3489_absorption_status_rollup() from public, anon;
grant execute on function public.founder_r3489_absorption_status_rollup() to authenticated;

-- 2) Cost-center scorecard
create or replace function public.founder_r3489_cost_center_scorecard()
returns table(
  cost_center text,
  total_lines bigint,
  over_absorbed bigint,
  fully_absorbed bigint,
  under_absorbed bigint,
  severely_under bigint,
  avg_absorption_rate_pct numeric,
  avg_capacity_utilization_pct numeric,
  net_over_under_rupees numeric
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
    count(*) filter (where l.absorption_status = 'over_absorbed')::bigint,
    count(*) filter (where l.absorption_status = 'fully_absorbed')::bigint,
    count(*) filter (where l.absorption_status = 'under_absorbed')::bigint,
    count(*) filter (where l.absorption_status = 'severely_under')::bigint,
    round(avg(l.absorption_rate_pct), 1),
    round(avg(l.capacity_utilization_pct), 1),
    coalesce(sum(l.over_under_absorbed_rupees),0)::numeric
  from public.cost_absorption_overhead_r3489 l
  group by l.cost_center
  order by coalesce(sum(l.over_under_absorbed_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3489_cost_center_scorecard() from public, anon;
grant execute on function public.founder_r3489_cost_center_scorecard() to authenticated;

-- 3) Cost-center × absorption-status matrix
create or replace function public.founder_r3489_cost_center_status_matrix()
returns table(cost_center text, absorption_status text, lines bigint, avg_absorption_rate_pct numeric, net_over_under_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_center, l.absorption_status, count(*)::bigint,
    round(avg(l.absorption_rate_pct), 1),
    coalesce(sum(l.over_under_absorbed_rupees),0)::numeric
  from public.cost_absorption_overhead_r3489 l
  group by l.cost_center, l.absorption_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3489_cost_center_status_matrix() from public, anon;
grant execute on function public.founder_r3489_cost_center_status_matrix() to authenticated;

-- 4) Monthly absorption trend
create or replace function public.founder_r3489_monthly_absorption_trend()
returns table(period_month date, lines bigint, applied_overhead_rupees numeric, absorbed_rupees numeric, net_over_under_rupees numeric, avg_capacity_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.applied_overhead_rupees),0)::numeric,
    coalesce(sum(l.absorbed_rupees),0)::numeric,
    coalesce(sum(l.over_under_absorbed_rupees),0)::numeric,
    round(avg(l.capacity_utilization_pct), 1)
  from public.cost_absorption_overhead_r3489 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3489_monthly_absorption_trend() from public, anon;
grant execute on function public.founder_r3489_monthly_absorption_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3489_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cost_absorption_overhead_capa_actions_r3489 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3489_capa_status_board() from public, anon;
grant execute on function public.founder_r3489_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3489_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cost_absorption_overhead_capa_actions_r3489)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cost_absorption_overhead_capa_actions_r3489 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3489_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3489_root_cause_pareto() to authenticated;

-- 7) Over/under absorbed impact digest
create or replace function public.founder_r3489_over_under_impact_digest()
returns table(absorption_status text, lines bigint, applied_overhead_rupees numeric, absorbed_rupees numeric, net_over_under_rupees numeric, avg_absorption_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.absorption_status,
    count(*)::bigint,
    coalesce(sum(l.applied_overhead_rupees),0)::numeric,
    coalesce(sum(l.absorbed_rupees),0)::numeric,
    coalesce(sum(l.over_under_absorbed_rupees),0)::numeric,
    round(avg(l.absorption_rate_pct), 1)
  from public.cost_absorption_overhead_r3489 l
  group by l.absorption_status
  order by coalesce(sum(l.over_under_absorbed_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3489_over_under_impact_digest() from public, anon;
grant execute on function public.founder_r3489_over_under_impact_digest() to authenticated;

-- 8) High-risk absorption queue (severely-under / worsening)
create or replace function public.founder_r3489_high_risk_queue()
returns table(
  cost_center text,
  line_ref text,
  period_month date,
  absorption_status text,
  absorption_rate_pct numeric,
  capacity_utilization_pct numeric,
  over_under_absorbed_rupees numeric,
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
  select l.cost_center, l.line_ref, l.period_month, l.absorption_status,
    l.absorption_rate_pct, l.capacity_utilization_pct, l.over_under_absorbed_rupees,
    l.trend_dir, l.notes
  from public.cost_absorption_overhead_r3489 l
  where l.absorption_status in ('under_absorbed','severely_under')
     or l.trend_dir = 'worsening'
  order by l.over_under_absorbed_rupees asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3489_high_risk_queue() from public, anon;
grant execute on function public.founder_r3489_high_risk_queue() to authenticated;
