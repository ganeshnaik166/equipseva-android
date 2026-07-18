-- Round 3316: Engineer Field-Service Productivity — Wrench-Time & Utilization Tracker
-- Per engineer-period productivity — region × verdict × wrench-time % × travel % × jobs/day × first-time-fix × capacity utilization × overtime × routing/coaching CAPA

-- =============================================================================
-- TABLE 1: field_service_productivity_r3316 — per engineer-period productivity
-- =============================================================================
create table if not exists public.field_service_productivity_r3316 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null check (region in (
    'north','south','east','west','central'
  )),
  period_week text not null,
  scheduled_shift_hours numeric(6,2) not null,
  wrench_time_hours numeric(6,2) not null,
  travel_hours numeric(6,2) not null,
  admin_idle_hours numeric(6,2) not null,
  jobs_completed int not null,
  jobs_per_day numeric(5,2) not null,
  first_time_fix_pct numeric(5,2) not null,
  wrench_time_pct numeric(5,2) not null,
  travel_pct numeric(5,2) not null,
  avg_job_duration_hours numeric(5,2) not null,
  overtime_hours numeric(5,2) not null,
  capacity_utilization_pct numeric(5,2) not null,
  productivity_verdict text not null check (productivity_verdict in (
    'high_performer','on_target','below_target','travel_heavy','underutilized','overloaded'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.field_service_productivity_r3316 enable row level security;

create index if not exists idx_fsp_r3316_org on public.field_service_productivity_r3316(organization_id);
create index if not exists idx_fsp_r3316_week on public.field_service_productivity_r3316(period_week);
create index if not exists idx_fsp_r3316_verdict on public.field_service_productivity_r3316(productivity_verdict);

-- =============================================================================
-- TABLE 2: field_service_productivity_capa_actions_r3316 — routing / scheduling / coaching CAPA
-- =============================================================================
create table if not exists public.field_service_productivity_capa_actions_r3316 (
  id uuid primary key default gen_random_uuid(),
  productivity_log_id uuid not null references public.field_service_productivity_r3316(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_wrench_time','excess_travel','low_first_time_fix','overload_burnout_risk',
    'underutilization','schedule_gaps','high_admin_time','overtime_excess'
  )),
  root_cause text not null check (root_cause in (
    'poor_route_planning','territory_too_large','parts_availability_delay','skill_gap',
    'scheduling_imbalance','excess_documentation','customer_site_access_delay',
    'understaffed_region','pending_investigation','tooling_shortage'
  )),
  corrective_action text not null check (corrective_action in (
    'optimize_routing','rebalance_territory','improve_parts_kitting','targeted_upskilling',
    'reassign_workload','streamline_paperwork','pre_visit_coordination',
    'hire_additional_engineer','coaching_1on1','schedule_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'sla_risk','cost_overrun','capacity_shortfall','none','retention_risk','customer_satisfaction'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.field_service_productivity_capa_actions_r3316 enable row level security;

create index if not exists idx_fsp_capa_r3316_log on public.field_service_productivity_capa_actions_r3316(productivity_log_id);
create index if not exists idx_fsp_capa_r3316_status on public.field_service_productivity_capa_actions_r3316(capa_status);

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

  -- 14 engineer-period productivity rows
  insert into public.field_service_productivity_r3316 (
    organization_id, engineer_name, region, period_week,
    scheduled_shift_hours, wrench_time_hours, travel_hours, admin_idle_hours,
    jobs_completed, jobs_per_day, first_time_fix_pct, wrench_time_pct, travel_pct,
    avg_job_duration_hours, overtime_hours, capacity_utilization_pct,
    productivity_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.wk,
    q.sched, q.wrench, q.travel, q.admin,
    q.jobs, q.jpd, q.ftf, q.wtp, q.tvp,
    q.ajd, q.ot, q.cap,
    q.verdict, q.nt
  from (values
    ('Ravi Kumar','south','2026-W25',45.0,31.5,8.0,5.5,27,5.4,92.0,70.0,17.8,1.2,2.0,96.0,'high_performer','Top wrench-time in South cluster — Apollo Chennai routes'),
    ('Ravi Kumar','south','2026-W26',45.0,30.0,9.0,6.0,25,5.0,90.0,66.7,20.0,1.2,1.0,93.0,'on_target','Consistent week across CMC Vellore accounts'),
    ('Anitha Rao','south','2026-W26',45.0,22.0,15.0,8.0,18,3.6,78.0,48.9,33.3,1.5,0.0,82.0,'travel_heavy','Wide Manipal Bengaluru territory — 33% travel'),
    ('Suresh Nair','south','2026-W26',45.0,18.0,10.0,12.0,12,2.4,70.0,40.0,22.2,1.8,0.0,71.0,'below_target','Low wrench-time and 12h admin drag'),
    ('Deepak Sharma','north','2026-W25',45.0,33.0,7.0,5.0,30,6.0,94.0,73.3,15.6,1.1,4.0,98.0,'high_performer','Highest jobs/day at AIIMS Delhi — watch overtime'),
    ('Deepak Sharma','north','2026-W26',45.0,38.0,6.0,4.0,34,6.8,93.0,84.4,13.3,1.0,8.0,108.0,'overloaded','108% capacity — burnout risk, needs backfill'),
    ('Priya Menon','north','2026-W26',45.0,28.0,9.5,7.5,22,4.4,88.0,62.2,21.1,1.3,1.5,90.0,'on_target','Solid first-time-fix on Fortis Gurgaon fleet'),
    ('Karthik Reddy','south','2026-W26',45.0,12.0,6.0,9.0,8,1.6,65.0,26.7,13.3,1.5,0.0,55.0,'underutilized','Only 55% capacity — reassign KIMS Hyderabad work'),
    ('Meena Iyer','west','2026-W26',45.0,29.0,8.5,7.5,24,4.8,89.0,64.4,18.9,1.2,2.0,92.0,'on_target','Mumbai metro route stable'),
    ('Arjun Pillai','west','2026-W26',45.0,20.0,17.0,8.0,15,3.0,74.0,44.4,37.8,1.4,0.0,78.0,'travel_heavy','Pune-Nashik corridor travel heavy — 38%'),
    ('Sanjay Gupta','north','2026-W26',45.0,16.0,11.0,14.0,10,2.0,68.0,35.6,24.4,1.7,0.0,64.0,'below_target','High admin and low FTF — coaching needed'),
    ('Vikram Singh','east','2026-W26',45.0,34.0,7.0,4.0,29,5.8,91.0,75.6,15.6,1.2,5.0,100.0,'high_performer','Kolkata cluster lead — clean utilization'),
    ('Rahul Verma','central','2026-W26',45.0,37.0,5.0,3.0,33,6.6,90.0,82.2,11.1,1.1,9.0,110.0,'overloaded','Nagpur single-engineer region — 110% and 9h OT'),
    ('Nisha Joshi','central','2026-W26',45.0,13.0,5.0,10.0,9,1.8,66.0,28.9,11.1,1.6,0.0,58.0,'underutilized','New hire ramping — 58% capacity')
  ) as q(eng, reg, wk, sched, wrench, travel, admin, jobs, jpd, ftf, wtp, tvp, ajd, ot, cap, verdict, nt);

  -- CAPA seed — attach to specific engineer-periods via engineer + week
  insert into public.field_service_productivity_capa_actions_r3316 (
    productivity_log_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Suresh Nair','2026-W26','high_admin_time','excess_documentation','streamline_paperwork','in_progress','cost_overrun','2026-07-20',null,6000.00,'Admin 12h/wk — deploy mobile job-close app'),
    ('Sanjay Gupta','2026-W26','low_first_time_fix','skill_gap','targeted_upskilling','open','customer_satisfaction','2026-07-25',null,22000.00,'FTF 68% — enroll in OEM certification training'),
    ('Deepak Sharma','2026-W26','overload_burnout_risk','understaffed_region','hire_additional_engineer','escalated','retention_risk','2026-08-05',null,480000.00,'108% capacity two weeks — approve North backfill hire'),
    ('Rahul Verma','2026-W26','overtime_excess','understaffed_region','hire_additional_engineer','escalated','sla_risk','2026-08-10',null,480000.00,'Nagpur single-engineer — 9h OT, hire or share load'),
    ('Arjun Pillai','2026-W26','excess_travel','territory_too_large','rebalance_territory','in_progress','capacity_shortfall','2026-07-28',null,15000.00,'38% travel — split Pune-Nashik corridor'),
    ('Karthik Reddy','2026-W26','underutilization','scheduling_imbalance','reassign_workload','closed','capacity_shortfall','2026-07-10','2026-07-12',0.00,'Rebalanced dispatch — now near 80% target'),
    ('Anitha Rao','2026-W26','excess_travel','poor_route_planning','optimize_routing','verification_pending','cost_overrun','2026-07-18',null,9000.00,'Route optimizer piloted — verify next week')
  ) as q(eng, wk, fc, rc, ca, cst, bi, tcd, acd, cost, nt)
  join public.field_service_productivity_r3316 e
    on e.organization_id = v_org_id and e.engineer_name = q.eng and e.period_week = q.wk;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Productivity verdict distribution
create or replace function public.founder_r3316_verdict_rollup()
returns table(productivity_verdict text, engineer_periods bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.field_service_productivity_r3316)
  select l.productivity_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.field_service_productivity_r3316 l
  group by l.productivity_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3316_verdict_rollup() from public, anon;
grant execute on function public.founder_r3316_verdict_rollup() to authenticated;

-- 2) Engineer productivity scorecard
create or replace function public.founder_r3316_engineer_scorecard()
returns table(
  engineer_name text,
  region text,
  periods bigint,
  avg_wrench_time_pct numeric,
  avg_travel_pct numeric,
  avg_jobs_per_day numeric,
  avg_first_time_fix_pct numeric,
  avg_capacity_utilization_pct numeric,
  total_overtime_hours numeric,
  high_performer_periods bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region,
    count(*)::bigint,
    round(avg(l.wrench_time_pct), 1),
    round(avg(l.travel_pct), 1),
    round(avg(l.jobs_per_day), 2),
    round(avg(l.first_time_fix_pct), 1),
    round(avg(l.capacity_utilization_pct), 1),
    round(sum(l.overtime_hours), 1),
    count(*) filter (where l.productivity_verdict = 'high_performer')::bigint
  from public.field_service_productivity_r3316 l
  group by l.engineer_name, l.region
  order by round(avg(l.wrench_time_pct), 1) desc;
end;
$$;

revoke execute on function public.founder_r3316_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3316_engineer_scorecard() to authenticated;

-- 3) Region × verdict matrix
create or replace function public.founder_r3316_region_verdict_matrix()
returns table(region text, productivity_verdict text, engineer_periods bigint, avg_wrench_time_pct numeric, avg_capacity_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, l.productivity_verdict, count(*)::bigint,
    round(avg(l.wrench_time_pct), 1),
    round(avg(l.capacity_utilization_pct), 1)
  from public.field_service_productivity_r3316 l
  group by l.region, l.productivity_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3316_region_verdict_matrix() from public, anon;
grant execute on function public.founder_r3316_region_verdict_matrix() to authenticated;

-- 4) Weekly productivity trend
create or replace function public.founder_r3316_weekly_trend()
returns table(period_week text, engineer_periods bigint, avg_wrench_time_pct numeric, avg_jobs_per_day numeric, overloaded bigint, underutilized bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_week,
    count(*)::bigint,
    round(avg(l.wrench_time_pct), 1),
    round(avg(l.jobs_per_day), 2),
    count(*) filter (where l.productivity_verdict = 'overloaded')::bigint,
    count(*) filter (where l.productivity_verdict = 'underutilized')::bigint
  from public.field_service_productivity_r3316 l
  group by l.period_week
  order by l.period_week desc;
end;
$$;

revoke execute on function public.founder_r3316_weekly_trend() from public, anon;
grant execute on function public.founder_r3316_weekly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3316_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.field_service_productivity_capa_actions_r3316 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3316_capa_status_board() from public, anon;
grant execute on function public.founder_r3316_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3316_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.field_service_productivity_capa_actions_r3316)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.field_service_productivity_capa_actions_r3316 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3316_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3316_root_cause_pareto() to authenticated;

-- 7) Business-impact cost/risk digest
create or replace function public.founder_r3316_business_impact_digest()
returns table(business_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.business_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.field_service_productivity_capa_actions_r3316 c
  group by c.business_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3316_business_impact_digest() from public, anon;
grant execute on function public.founder_r3316_business_impact_digest() to authenticated;

-- 8) High-risk productivity queue (individual concerns)
create or replace function public.founder_r3316_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  period_week text,
  productivity_verdict text,
  wrench_time_pct numeric,
  travel_pct numeric,
  jobs_per_day numeric,
  first_time_fix_pct numeric,
  capacity_utilization_pct numeric,
  overtime_hours numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.period_week, l.productivity_verdict,
    l.wrench_time_pct, l.travel_pct, l.jobs_per_day, l.first_time_fix_pct,
    l.capacity_utilization_pct, l.overtime_hours, l.notes
  from public.field_service_productivity_r3316 l
  where l.productivity_verdict in ('below_target','travel_heavy','underutilized','overloaded')
     or l.first_time_fix_pct < 75
     or l.capacity_utilization_pct > 105
     or l.capacity_utilization_pct < 60
     or l.overtime_hours >= 8
  order by l.capacity_utilization_pct desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3316_high_risk_queue() from public, anon;
grant execute on function public.founder_r3316_high_risk_queue() to authenticated;
