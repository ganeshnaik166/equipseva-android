-- Round 3381: Founder Gross-Margin Bridge & Cost-of-Service Decomposition Board
-- Finance board — service line × period × revenue → gross margin, cost-driver decomposition
-- (parts / labour / travel / rework), biggest-cost-driver, improvement-lever, potential uplift × CAPA

-- =============================================================================
-- TABLE 1: gross_margin_bridge_r3381 — per service-line/period margin decomposition
-- =============================================================================
create table if not exists public.gross_margin_bridge_r3381 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  service_line text not null check (service_line in (
    'amc_contracts','breakdown_repair','spare_parts_sales','installation','calibration_services','consumables'
  )),
  period_month text not null,
  revenue_rupees numeric(14,2) not null,
  parts_cost_rupees numeric(14,2) not null,
  field_labour_cost_rupees numeric(14,2) not null,
  travel_logistics_cost_rupees numeric(14,2) not null,
  warranty_rework_cost_rupees numeric(14,2) not null,
  gross_margin_rupees numeric(14,2) not null,
  gross_margin_pct numeric(6,2) not null,
  margin_vs_target_pct numeric(6,2) not null,
  biggest_cost_driver text not null check (biggest_cost_driver in (
    'parts','labour','travel','rework','underpricing','low_utilization'
  )),
  improvement_lever text not null check (improvement_lever in (
    'reprice','parts_sourcing','route_optimization','first_time_fix','utilization','mix_shift'
  )),
  potential_uplift_rupees numeric(14,2) not null,
  margin_verdict text not null check (margin_verdict in (
    'above_target','on_target','below_target_action','margin_leak','lever_priority'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gross_margin_bridge_r3381 enable row level security;

create index if not exists idx_gross_margin_bridge_r3381_org on public.gross_margin_bridge_r3381(organization_id);
create index if not exists idx_gross_margin_bridge_r3381_period on public.gross_margin_bridge_r3381(period_month);
create index if not exists idx_gross_margin_bridge_r3381_verdict on public.gross_margin_bridge_r3381(margin_verdict);

-- =============================================================================
-- TABLE 2: gross_margin_bridge_capa_actions_r3381 — margin-improvement CAPA actions
-- =============================================================================
create table if not exists public.gross_margin_bridge_capa_actions_r3381 (
  id uuid primary key default gen_random_uuid(),
  margin_row_id uuid not null references public.gross_margin_bridge_r3381(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'travel_cost_overrun','parts_margin_thin','rework_cost_spike','labour_underutilization',
    'consumables_underpricing','amc_renewal_pricing','installation_commissioning_defect'
  )),
  root_cause text not null check (root_cause in (
    'outstation_route_inefficiency','oem_parts_markup','first_time_fix_failure','engineer_idle_capacity',
    'below_floor_pricing','scope_creep_uncosted','commissioning_quality_gap','pending_analysis'
  )),
  corrective_action text not null check (corrective_action in (
    'optimize_service_routes','negotiate_alternate_parts_vendor','improve_first_time_fix','rebalance_engineer_load',
    'reprice_to_cost_plus','renegotiate_amc_rate','tighten_commissioning_qa','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'margin_leak','cash_drag','pricing_risk','retention_risk','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  expected_uplift_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gross_margin_bridge_capa_actions_r3381 enable row level security;

create index if not exists idx_gross_margin_capa_r3381_row on public.gross_margin_bridge_capa_actions_r3381(margin_row_id);
create index if not exists idx_gross_margin_capa_r3381_status on public.gross_margin_bridge_capa_actions_r3381(capa_status);

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

  -- 14 gross-margin bridge rows (per service-line / period)
  insert into public.gross_margin_bridge_r3381 (
    organization_id, service_line, period_month, revenue_rupees,
    parts_cost_rupees, field_labour_cost_rupees, travel_logistics_cost_rupees, warranty_rework_cost_rupees,
    gross_margin_rupees, gross_margin_pct, margin_vs_target_pct,
    biggest_cost_driver, improvement_lever, potential_uplift_rupees, margin_verdict, notes
  )
  select v_org_id, q.sl, q.pm, q.rev,
    q.parts, q.labour, q.travel, q.rework,
    q.gm, q.gmpct, q.mvt,
    q.driver, q.lever, q.uplift, q.verdict, q.nt
  from (values
    ('amc_contracts','2026-06',4200000,520000,980000,310000,140000,2250000,53.6,3.6,'labour','utilization',180000,'above_target','Apollo Chennai and Fortis Gurgaon AMC book — high renewal margin'),
    ('amc_contracts','2026-05',3980000,505000,1010000,330000,210000,1925000,48.4,-1.6,'rework','first_time_fix',220000,'on_target','Rework creeping on legacy ventilator AMCs'),
    ('breakdown_repair','2026-06',2650000,880000,760000,520000,180000,310000,11.7,-13.3,'travel','route_optimization',340000,'margin_leak','Manipal Bengaluru cluster — travel logistics eating margin'),
    ('breakdown_repair','2026-05',2510000,910000,740000,560000,240000,60000,2.4,-22.6,'travel','route_optimization',380000,'margin_leak','AIIMS Delhi outstation breakdown visits — near-zero margin'),
    ('spare_parts_sales','2026-06',1850000,1280000,90000,60000,30000,390000,21.1,-3.9,'parts','parts_sourcing',210000,'below_target_action','OEM parts markup thin — CMC Vellore consumable spares'),
    ('spare_parts_sales','2026-05',1720000,1150000,85000,55000,25000,405000,23.5,-1.5,'parts','parts_sourcing',160000,'on_target','Alternate-vendor sourcing pilot improving parts margin'),
    ('installation','2026-06',3100000,210000,640000,280000,90000,1880000,60.6,10.6,'labour','first_time_fix',120000,'above_target','KIMS Hyderabad cath-lab install — strong project margin'),
    ('installation','2026-05',2400000,180000,690000,410000,260000,860000,35.8,-14.2,'rework','first_time_fix',300000,'below_target_action','Reinstall rework at Fortis Gurgaon — commissioning defects'),
    ('calibration_services','2026-06',980000,40000,520000,240000,20000,160000,16.3,-18.7,'low_utilization','utilization',190000,'margin_leak','Calibration engineers under-utilized — idle days between sites'),
    ('calibration_services','2026-05',1050000,45000,500000,210000,15000,280000,26.7,-8.3,'low_utilization','utilization',150000,'below_target_action','Route batching improving calibration utilization'),
    ('consumables','2026-06',1420000,1080000,70000,110000,40000,120000,8.5,-11.5,'underpricing','reprice',260000,'margin_leak','Consumables priced below cost-plus floor — reprice needed'),
    ('consumables','2026-05',1360000,990000,65000,100000,35000,170000,12.5,-7.5,'underpricing','reprice',210000,'below_target_action','Partial reprice applied on dialysis consumables'),
    ('amc_contracts','2026-04',3850000,490000,990000,320000,175000,1875000,48.7,-1.3,'labour','mix_shift',140000,'on_target','Baseline April AMC margin before renewals'),
    ('breakdown_repair','2026-04',2380000,850000,720000,540000,300000,-30000,-1.3,-26.3,'rework','first_time_fix',420000,'lever_priority','Negative-margin outstation breakdowns — top lever priority')
  ) as q(sl, pm, rev, parts, labour, travel, rework, gm, gmpct, mvt, driver, lever, uplift, verdict, nt);

  -- CAPA seed — attach to at-risk margin rows via service_line + period_month
  insert into public.gross_margin_bridge_capa_actions_r3381 (
    margin_row_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    expected_uplift_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.uplift, q.nt
  from (values
    ('breakdown_repair','2026-06','travel_cost_overrun','outstation_route_inefficiency','optimize_service_routes','in_progress','margin_leak','2026-08-15',null,340000,'Cluster Manipal Bengaluru breakdown routes — batch visits into single trips'),
    ('breakdown_repair','2026-05','travel_cost_overrun','outstation_route_inefficiency','optimize_service_routes','open','margin_leak','2026-08-20',null,380000,'AIIMS Delhi outstation visits — evaluate regional engineer stationing'),
    ('spare_parts_sales','2026-06','parts_margin_thin','oem_parts_markup','negotiate_alternate_parts_vendor','in_progress','pricing_risk','2026-08-10',null,210000,'CMC Vellore spares — qualify alternate vendor to widen markup'),
    ('installation','2026-05','installation_commissioning_defect','commissioning_quality_gap','tighten_commissioning_qa','verification_pending','margin_leak','2026-07-30',null,300000,'Fortis Gurgaon reinstall rework — commissioning checklist rollout'),
    ('calibration_services','2026-06','labour_underutilization','engineer_idle_capacity','rebalance_engineer_load','open','cash_drag','2026-08-25',null,190000,'Calibration engineers idle between sites — batch routes to lift utilization'),
    ('consumables','2026-06','consumables_underpricing','below_floor_pricing','reprice_to_cost_plus','escalated','pricing_risk','2026-07-25',null,260000,'Dialysis consumables below cost-plus floor — reprice escalated to founder'),
    ('breakdown_repair','2026-04','rework_cost_spike','first_time_fix_failure','improve_first_time_fix','closed','margin_leak','2026-06-30','2026-06-28',420000,'Negative-margin April breakdowns — first-time-fix program closed the loop')
  ) as q(sl, pm, fc, rc, ca, cst, fi, tcd, acd, uplift, nt)
  join public.gross_margin_bridge_r3381 e
    on e.organization_id = v_org_id and e.service_line = q.sl and e.period_month = q.pm;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Margin verdict distribution
create or replace function public.founder_r3381_margin_verdict_rollup()
returns table(margin_verdict text, entries bigint, total_revenue_rupees numeric, total_gross_margin_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gross_margin_bridge_r3381)
  select l.margin_verdict, count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.gross_margin_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gross_margin_bridge_r3381 l
  group by l.margin_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3381_margin_verdict_rollup() from public, anon;
grant execute on function public.founder_r3381_margin_verdict_rollup() to authenticated;

-- 2) Service-line margin scorecard
create or replace function public.founder_r3381_service_line_scorecard()
returns table(
  service_line text,
  entries bigint,
  total_revenue_rupees numeric,
  total_gross_margin_rupees numeric,
  avg_gross_margin_pct numeric,
  parts_cost_rupees numeric,
  field_labour_cost_rupees numeric,
  travel_logistics_cost_rupees numeric,
  warranty_rework_cost_rupees numeric,
  potential_uplift_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_line,
    count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.gross_margin_rupees),0)::numeric,
    round(avg(l.gross_margin_pct), 1),
    coalesce(sum(l.parts_cost_rupees),0)::numeric,
    coalesce(sum(l.field_labour_cost_rupees),0)::numeric,
    coalesce(sum(l.travel_logistics_cost_rupees),0)::numeric,
    coalesce(sum(l.warranty_rework_cost_rupees),0)::numeric,
    coalesce(sum(l.potential_uplift_rupees),0)::numeric
  from public.gross_margin_bridge_r3381 l
  group by l.service_line
  order by coalesce(sum(l.gross_margin_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3381_service_line_scorecard() from public, anon;
grant execute on function public.founder_r3381_service_line_scorecard() to authenticated;

-- 3) Service-line × biggest-cost-driver matrix
create or replace function public.founder_r3381_service_line_driver_matrix()
returns table(service_line text, biggest_cost_driver text, entries bigint, total_revenue_rupees numeric, avg_gross_margin_pct numeric, potential_uplift_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_line, l.biggest_cost_driver, count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    round(avg(l.gross_margin_pct), 1),
    coalesce(sum(l.potential_uplift_rupees),0)::numeric
  from public.gross_margin_bridge_r3381 l
  group by l.service_line, l.biggest_cost_driver
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3381_service_line_driver_matrix() from public, anon;
grant execute on function public.founder_r3381_service_line_driver_matrix() to authenticated;

-- 4) Period margin trend
create or replace function public.founder_r3381_period_margin_trend()
returns table(period_month text, entries bigint, total_revenue_rupees numeric, total_gross_margin_rupees numeric, avg_gross_margin_pct numeric, potential_uplift_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.gross_margin_rupees),0)::numeric,
    round(avg(l.gross_margin_pct), 1),
    coalesce(sum(l.potential_uplift_rupees),0)::numeric
  from public.gross_margin_bridge_r3381 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3381_period_margin_trend() from public, anon;
grant execute on function public.founder_r3381_period_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3381_capa_status_board()
returns table(capa_status text, findings bigint, avg_uplift_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.expected_uplift_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.gross_margin_bridge_capa_actions_r3381 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3381_capa_status_board() from public, anon;
grant execute on function public.founder_r3381_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3381_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_uplift_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gross_margin_bridge_capa_actions_r3381)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.expected_uplift_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gross_margin_bridge_capa_actions_r3381 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3381_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3381_root_cause_pareto() to authenticated;

-- 7) Financial-impact (cost/risk) digest
create or replace function public.founder_r3381_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_uplift_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.expected_uplift_rupees),0)::numeric
  from public.gross_margin_bridge_capa_actions_r3381 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3381_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3381_financial_impact_digest() to authenticated;

-- 8) Margin-leak queue (top uplift priorities)
create or replace function public.founder_r3381_margin_leak_queue()
returns table(
  service_line text,
  period_month text,
  revenue_rupees numeric,
  gross_margin_pct numeric,
  margin_vs_target_pct numeric,
  biggest_cost_driver text,
  improvement_lever text,
  potential_uplift_rupees numeric,
  margin_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_line, l.period_month, l.revenue_rupees, l.gross_margin_pct,
    l.margin_vs_target_pct, l.biggest_cost_driver, l.improvement_lever,
    l.potential_uplift_rupees, l.margin_verdict, l.notes
  from public.gross_margin_bridge_r3381 l
  where l.margin_verdict in ('below_target_action','margin_leak','lever_priority')
     or l.margin_vs_target_pct < 0
  order by l.potential_uplift_rupees desc, l.margin_vs_target_pct asc;
end;
$$;

revoke execute on function public.founder_r3381_margin_leak_queue() from public, anon;
grant execute on function public.founder_r3381_margin_leak_queue() to authenticated;
