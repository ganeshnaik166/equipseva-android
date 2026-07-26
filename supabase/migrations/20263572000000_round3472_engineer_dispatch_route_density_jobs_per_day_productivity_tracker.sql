-- Round 3472: Engineer Dispatch Route-Density / Jobs-Per-Day Productivity Tracker
-- Field dispatch productivity — engineer × region × route date × jobs planned/completed × travel km/hours
-- × on-site hours × jobs-per-day × first-visit-success × route efficiency × productivity status × overtime × CAPA

-- =============================================================================
-- TABLE 1: dispatch_route_density_r3472 — per-route field dispatch productivity log
-- =============================================================================
create table if not exists public.dispatch_route_density_r3472 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  route_code text not null,
  region text not null,
  route_date date not null,
  jobs_planned int not null,
  jobs_completed int not null,
  travel_km numeric(7,2),
  travel_hours numeric(5,2),
  onsite_hours numeric(5,2),
  jobs_per_day numeric(5,2),
  first_visit_success_pct numeric(5,2),
  route_efficiency text not null check (route_efficiency in (
    'optimal','acceptable','suboptimal','poor'
  )),
  productivity_status text not null check (productivity_status in (
    'above_target','on_target','below_target','critical_low'
  )),
  overtime_flag boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dispatch_route_density_r3472 enable row level security;

create index if not exists idx_dispatch_route_density_r3472_org on public.dispatch_route_density_r3472(organization_id);
create index if not exists idx_dispatch_route_density_r3472_date on public.dispatch_route_density_r3472(route_date);
create index if not exists idx_dispatch_route_density_r3472_status on public.dispatch_route_density_r3472(productivity_status);

-- =============================================================================
-- TABLE 2: dispatch_route_density_capa_actions_r3472 — CAPA & productivity actions
-- =============================================================================
create table if not exists public.dispatch_route_density_capa_actions_r3472 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_id uuid references public.dispatch_route_density_r3472(id) on delete cascade,
  route_code text not null,
  finding_category text not null check (finding_category in (
    'low_jobs_per_day','high_travel_ratio','low_first_visit_success','excessive_overtime',
    'poor_route_efficiency','below_target_productivity','route_planning_gap','skill_gap'
  )),
  root_cause text not null check (root_cause in (
    'poor_route_sequencing','high_traffic_density','wide_territory_spread','parts_unavailability',
    'incomplete_job_prep','skill_mismatch','understaffed_region','scheduling_conflict',
    'pending_investigation','customer_site_delays'
  )),
  corrective_action text not null check (corrective_action in (
    'reoptimize_route_clustering','rebalance_territory','add_field_engineer','preload_common_spares',
    'improve_job_prep_checklist','cross_train_engineer','adjust_scheduling_window',
    'coordinate_customer_access','escalate_to_ops_lead','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  productivity_impact_pct numeric(6,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dispatch_route_density_capa_actions_r3472 enable row level security;

create index if not exists idx_dispatch_route_density_capa_r3472_route on public.dispatch_route_density_capa_actions_r3472(route_id);
create index if not exists idx_dispatch_route_density_capa_r3472_status on public.dispatch_route_density_capa_actions_r3472(capa_status);

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

  -- 16 route productivity rows
  insert into public.dispatch_route_density_r3472 (
    organization_id, engineer_name, route_code, region, route_date,
    jobs_planned, jobs_completed, travel_km, travel_hours, onsite_hours,
    jobs_per_day, first_visit_success_pct, route_efficiency, productivity_status,
    overtime_flag, notes
  )
  select v_org_id, q.eng, q.rcode, q.reg, q.rdate::date,
    q.jp::int, q.jc::int, q.tkm::numeric, q.thrs::numeric, q.ohrs::numeric,
    q.jpd::numeric, q.fvs::numeric, q.reff, q.pstat,
    q.ot, q.nt
  from (values
    ('Ravi Kumar','RTE-CHN-01','Chennai','2026-07-06',
     8,8,42.5,2.5,5.5,8.0,95.0,'optimal','above_target',false,'Dense CBD cluster, all jobs closed same-day'),
    ('Ravi Kumar','RTE-CHN-02','Chennai','2026-07-07',
     7,6,58.0,3.2,4.8,6.0,88.0,'acceptable','on_target',false,'One callback needed for spare part'),
    ('Priya Nair','RTE-BLR-11','Bengaluru','2026-07-06',
     9,9,55.0,3.5,5.0,9.0,92.0,'optimal','above_target',false,'Whitefield corridor tight clustering'),
    ('Priya Nair','RTE-BLR-12','Bengaluru','2026-07-08',
     8,5,72.0,4.5,4.0,5.0,70.0,'suboptimal','below_target',true,'Heavy traffic and two failed first visits'),
    ('Arjun Menon','RTE-DEL-21','Delhi NCR','2026-07-06',
     7,7,48.0,2.8,5.2,7.0,90.0,'optimal','on_target',false,'Gurgaon sector cluster efficient'),
    ('Arjun Menon','RTE-DEL-22','Delhi NCR','2026-07-09',
     8,4,95.0,5.5,3.5,4.0,55.0,'poor','critical_low',true,'Wide NCR spread, most of day lost to travel'),
    ('Sneha Reddy','RTE-HYD-31','Hyderabad','2026-07-07',
     6,6,40.0,2.2,5.5,6.0,93.0,'optimal','on_target',false,'Hitec City compact route'),
    ('Sneha Reddy','RTE-HYD-32','Hyderabad','2026-07-10',
     7,5,66.0,3.8,4.5,5.0,72.0,'suboptimal','below_target',false,'Spare stockout caused one reschedule'),
    ('Vikram Shah','RTE-MUM-41','Mumbai','2026-07-07',
     8,8,35.0,3.0,5.5,8.0,96.0,'optimal','above_target',false,'South Mumbai dense hospital belt'),
    ('Vikram Shah','RTE-MUM-42','Mumbai','2026-07-11',
     7,3,88.0,5.0,3.0,3.0,50.0,'poor','critical_low',true,'Suburban spread, access delays at sites'),
    ('Deepa Iyer','RTE-PUN-51','Pune','2026-07-08',
     6,6,50.0,2.6,5.0,6.0,89.0,'acceptable','on_target',false,'Hinjewadi IT park cluster'),
    ('Deepa Iyer','RTE-PUN-52','Pune','2026-07-12',
     7,6,62.0,3.5,4.6,6.0,85.0,'acceptable','on_target',true,'Slight overtime to finish last job'),
    ('Rahul Verma','RTE-DEL-23','Delhi NCR','2026-07-13',
     9,9,52.0,3.2,5.4,9.0,94.0,'optimal','above_target',false,'Noida cluster well sequenced'),
    ('Rahul Verma','RTE-DEL-24','Delhi NCR','2026-07-14',
     8,4,80.0,4.8,3.8,4.0,60.0,'suboptimal','below_target',true,'Poor sequencing, backtracking across zones'),
    ('Anita Das','RTE-BLR-13','Bengaluru','2026-07-15',
     7,7,45.0,2.9,5.3,7.0,91.0,'optimal','on_target',false,'Electronic City compact loop'),
    ('Anita Das','RTE-BLR-14','Bengaluru','2026-07-16',
     8,3,98.0,5.8,2.8,3.0,45.0,'poor','critical_low',true,'Territory too wide, understaffed region')
  ) as q(eng, rcode, reg, rdate, jp, jc, tkm, thrs, ohrs, jpd, fvs, reff, pstat, ot, nt);

  -- CAPA seed — attach to specific routes via route_code
  insert into public.dispatch_route_density_capa_actions_r3472 (
    organization_id, route_id, route_code, finding_category, root_cause, corrective_action,
    capa_status, productivity_impact_pct, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.rcode, q.fc, q.rc, q.ca,
    q.cst, q.imp::numeric, q.own, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('RTE-DEL-22','poor_route_efficiency','wide_territory_spread','rebalance_territory','in_progress',35.0,'Ops Lead - Delhi','2026-07-15',null,0.00,'NCR territory too wide — rebalancing zones between two engineers'),
    ('RTE-MUM-42','below_target_productivity','customer_site_delays','coordinate_customer_access','open',40.0,'Ops Lead - Mumbai','2026-07-16',null,0.00,'Site access delays — coordinating fixed access windows'),
    ('RTE-BLR-12','low_first_visit_success','parts_unavailability','preload_common_spares','verification_pending',22.0,'Regional Supervisor - BLR','2026-07-14',null,5000.00,'Van spares kit expanded — verify FVS next cycle'),
    ('RTE-DEL-24','poor_route_efficiency','poor_route_sequencing','reoptimize_route_clustering','closed',18.0,'Ops Lead - Delhi','2026-07-18','2026-07-17',0.00,'Route re-clustered via dispatch tool — backtracking removed'),
    ('RTE-HYD-32','low_jobs_per_day','parts_unavailability','preload_common_spares','open',15.0,'Regional Supervisor - HYD','2026-07-15',null,4500.00,'Stockout of common sensor board — replenishment ordered'),
    ('RTE-BLR-14','poor_route_efficiency','understaffed_region','add_field_engineer','escalated',45.0,'Ops Head - South','2026-07-20',null,60000.00,'Bengaluru south understaffed — hiring one more engineer'),
    ('RTE-DEL-22','excessive_overtime','high_traffic_density','adjust_scheduling_window','open',30.0,'Ops Lead - Delhi','2026-07-16',null,0.00,'Shift start moved earlier to avoid peak traffic'),
    ('RTE-DEL-24','skill_gap','skill_mismatch','cross_train_engineer','in_progress',12.0,'L&D Coordinator','2026-07-19',null,8000.00,'Cross-training on new infusion pump line')
  ) as q(rcode, fc, rc, ca, cst, imp, own, tcd, acd, cost, nt)
  join public.dispatch_route_density_r3472 e
    on e.organization_id = v_org_id and e.route_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Productivity status distribution
create or replace function public.founder_r3472_productivity_status_rollup()
returns table(productivity_status text, routes bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dispatch_route_density_r3472)
  select l.productivity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dispatch_route_density_r3472 l
  group by l.productivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3472_productivity_status_rollup() from public, anon;
grant execute on function public.founder_r3472_productivity_status_rollup() to authenticated;

-- 2) Region-level productivity scorecard
create or replace function public.founder_r3472_region_scorecard()
returns table(
  region text,
  total_routes bigint,
  jobs_planned bigint,
  jobs_completed bigint,
  avg_jobs_per_day numeric,
  avg_first_visit_success_pct numeric,
  overtime_routes bigint,
  below_target bigint,
  on_or_above_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    coalesce(sum(l.jobs_planned),0)::bigint,
    coalesce(sum(l.jobs_completed),0)::bigint,
    round(avg(l.jobs_per_day), 2),
    round(avg(l.first_visit_success_pct), 1),
    count(*) filter (where l.overtime_flag = true)::bigint,
    count(*) filter (where l.productivity_status in ('below_target','critical_low'))::bigint,
    round(100.0 * count(*) filter (where l.productivity_status in ('above_target','on_target'))::numeric / nullif(count(*),0), 1)
  from public.dispatch_route_density_r3472 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3472_region_scorecard() from public, anon;
grant execute on function public.founder_r3472_region_scorecard() to authenticated;

-- 3) Region × route-efficiency matrix
create or replace function public.founder_r3472_region_efficiency_matrix()
returns table(region text, route_efficiency text, routes bigint, avg_jobs_per_day numeric, avg_travel_km numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, l.route_efficiency, count(*)::bigint,
    round(avg(l.jobs_per_day), 2),
    round(avg(l.travel_km), 1)
  from public.dispatch_route_density_r3472 l
  group by l.region, l.route_efficiency
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3472_region_efficiency_matrix() from public, anon;
grant execute on function public.founder_r3472_region_efficiency_matrix() to authenticated;

-- 4) Monthly jobs-per-day trend
create or replace function public.founder_r3472_monthly_productivity_trend()
returns table(
  month text,
  routes bigint,
  jobs_completed bigint,
  avg_jobs_per_day numeric,
  avg_first_visit_success_pct numeric,
  overtime_routes bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.route_date, 'YYYY-MM'),
    count(*)::bigint,
    coalesce(sum(l.jobs_completed),0)::bigint,
    round(avg(l.jobs_per_day), 2),
    round(avg(l.first_visit_success_pct), 1),
    count(*) filter (where l.overtime_flag = true)::bigint
  from public.dispatch_route_density_r3472 l
  group by to_char(l.route_date, 'YYYY-MM')
  order by to_char(l.route_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3472_monthly_productivity_trend() from public, anon;
grant execute on function public.founder_r3472_monthly_productivity_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3472_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_pct numeric, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.productivity_impact_pct), 1),
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.dispatch_route_density_capa_actions_r3472 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3472_capa_status_board() from public, anon;
grant execute on function public.founder_r3472_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3472_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dispatch_route_density_capa_actions_r3472)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dispatch_route_density_capa_actions_r3472 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3472_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3472_root_cause_pareto() to authenticated;

-- 7) Productivity-impact digest (by finding category)
create or replace function public.founder_r3472_productivity_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, avg_impact_pct numeric, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    round(avg(c.productivity_impact_pct), 1),
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.dispatch_route_density_capa_actions_r3472 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3472_productivity_impact_digest() from public, anon;
grant execute on function public.founder_r3472_productivity_impact_digest() to authenticated;

-- 8) High-risk route queue (critical-low / poor-route / overtime)
create or replace function public.founder_r3472_high_risk_queue()
returns table(
  engineer_name text,
  route_code text,
  region text,
  route_date date,
  productivity_status text,
  route_efficiency text,
  jobs_planned int,
  jobs_completed int,
  jobs_per_day numeric,
  first_visit_success_pct numeric,
  overtime_flag boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.route_code, l.region, l.route_date,
    l.productivity_status, l.route_efficiency, l.jobs_planned, l.jobs_completed,
    l.jobs_per_day, l.first_visit_success_pct, l.overtime_flag, l.notes
  from public.dispatch_route_density_r3472 l
  where l.productivity_status in ('below_target','critical_low')
     or l.route_efficiency in ('suboptimal','poor')
     or l.overtime_flag = true
  order by l.route_date desc, l.region;
end;
$$;

revoke execute on function public.founder_r3472_high_risk_queue() from public, anon;
grant execute on function public.founder_r3472_high_risk_queue() to authenticated;
