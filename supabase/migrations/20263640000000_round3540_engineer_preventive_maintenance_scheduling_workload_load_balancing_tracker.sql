-- Round 3540: Engineer PM-Scheduling / Workload Load-Balancing Tracker
-- Per-engineer per-week PM scheduling & workload balancing across regions — PM due/scheduled/completed × capacity/scheduled hours × utilization × load status × carryover × reschedule × balancing action × CAPA

-- =============================================================================
-- TABLE 1: pm_scheduling_load_r3540 — per-engineer per-week PM workload load-balancing
-- =============================================================================
create table if not exists public.pm_scheduling_load_r3540 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  schedule_ref text not null,
  schedule_week date not null,
  pm_due int not null,
  pm_scheduled int not null,
  pm_completed int not null,
  capacity_hours numeric(6,2) not null,
  scheduled_hours numeric(6,2) not null,
  utilization_pct numeric(5,2) not null,
  load_status text not null check (load_status in (
    'under_loaded','balanced','over_loaded','critical_overload'
  )),
  carryover int not null,
  reschedule_count int not null,
  balancing_action text not null check (balancing_action in (
    'none','reassign','defer','overtime','contractor','escalate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_scheduling_load_r3540 enable row level security;

create index if not exists idx_pm_scheduling_load_r3540_org on public.pm_scheduling_load_r3540(organization_id);
create index if not exists idx_pm_scheduling_load_r3540_week on public.pm_scheduling_load_r3540(schedule_week);
create index if not exists idx_pm_scheduling_load_r3540_status on public.pm_scheduling_load_r3540(load_status);

-- =============================================================================
-- TABLE 2: pm_scheduling_load_capa_actions_r3540 — load-balancing CAPA & compliance actions
-- =============================================================================
create table if not exists public.pm_scheduling_load_capa_actions_r3540 (
  id uuid primary key default gen_random_uuid(),
  load_log_id uuid not null references public.pm_scheduling_load_r3540(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'chronic_overload','pm_backlog_growing','low_completion_rate','high_carryover',
    'capacity_shortfall','frequent_reschedule','region_understaffed','skill_gap','none_flagged'
  )),
  root_cause text not null check (root_cause in (
    'technician_shortage','high_travel_time','unplanned_breakdowns','poor_route_planning',
    'spare_parts_delay','absenteeism','seasonal_demand_spike','scheduling_tool_error',
    'skill_mismatch','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reassign_workload','hire_contractor','authorize_overtime','defer_low_priority_pm',
    'rebalance_regions','cross_train_technician','optimize_routes','escalate_to_ops_head',
    'add_headcount','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  sla_impact text not null check (sla_impact in (
    'sla_breach','sla_at_risk','none','internal_only','contract_penalty','customer_escalation'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pm_scheduling_load_capa_actions_r3540 enable row level security;

create index if not exists idx_pm_scheduling_load_capa_r3540_log on public.pm_scheduling_load_capa_actions_r3540(load_log_id);
create index if not exists idx_pm_scheduling_load_capa_r3540_status on public.pm_scheduling_load_capa_actions_r3540(capa_status);

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

  -- 16 weekly workload rows
  insert into public.pm_scheduling_load_r3540 (
    organization_id, engineer_name, region, schedule_ref, schedule_week,
    pm_due, pm_scheduled, pm_completed, capacity_hours, scheduled_hours, utilization_pct,
    load_status, carryover, reschedule_count, balancing_action, notes
  )
  select v_org_id, q.eng, q.reg, q.sref, q.swk::date,
    q.pdue, q.psch, q.pcmp, q.caph, q.schh, q.util,
    q.lstat, q.cry, q.rsc, q.bact, q.nt
  from (values
    ('Rajesh Kumar','Delhi-NCR','PMW-DEL-2205','2026-05-04',
     18,18,17,40,34,85.0,'balanced',1,0,'none','Steady week, one PM carried to next week'),
    ('Anil Sharma','Delhi-NCR','PMW-DEL-2218','2026-05-18',
     26,22,18,40,46,115.0,'over_loaded',6,2,'overtime','Overloaded — authorized overtime, 6 PMs carried over'),
    ('Priya Nair','Bengaluru','PMW-BLR-2211','2026-05-11',
     14,14,14,40,30,75.0,'under_loaded',0,0,'none','Light week, capacity available for reassignment'),
    ('Suresh Reddy','Hyderabad','PMW-HYD-2225','2026-05-25',
     30,24,15,40,52,130.0,'critical_overload',12,3,'escalate','Critical overload — 12 PMs backlog, escalated to ops head'),
    ('Vikram Singh','Mumbai','PMW-MUM-2201','2026-06-01',
     20,20,19,40,38,95.0,'balanced',1,1,'none','Balanced load, minor reschedule due to site access'),
    ('Deepak Joshi','Pune','PMW-PUN-2208','2026-06-08',
     24,20,14,40,44,110.0,'over_loaded',8,2,'reassign','Reassigned 4 PMs to Mumbai team, 8 carryover'),
    ('Kavita Menon','Chennai','PMW-CHN-2215','2026-06-15',
     16,16,16,40,33,82.5,'balanced',0,0,'none','On-target completion, no carryover'),
    ('Arjun Das','Kolkata','PMW-KOL-2222','2026-06-22',
     28,22,13,40,50,125.0,'critical_overload',13,4,'contractor','Understaffed region — contractor engaged, 13 backlog PMs'),
    ('Rahul Verma','Delhi-NCR','PMW-DEL-2229','2026-06-29',
     22,20,18,40,41,102.5,'over_loaded',4,1,'overtime','Slight overload, overtime cleared most PMs'),
    ('Meera Iyer','Bengaluru','PMW-BLR-2206','2026-06-01',
     12,12,12,40,26,65.0,'under_loaded',0,0,'none','Under-utilized — candidate for load rebalancing'),
    ('Sanjay Gupta','Hyderabad','PMW-HYD-2213','2026-07-06',
     25,21,16,40,47,117.5,'over_loaded',9,2,'defer','Deferred 4 low-priority PMs, 9 carryover'),
    ('Neha Kulkarni','Mumbai','PMW-MUM-2220','2026-07-13',
     19,19,18,40,36,90.0,'balanced',1,0,'none','Balanced, one PM slipped to next cycle'),
    ('Amit Patel','Pune','PMW-PUN-2227','2026-07-20',
     31,24,14,40,54,135.0,'critical_overload',14,5,'escalate','Severe overload — 14 PM backlog, escalated for headcount'),
    ('Sunita Rao','Chennai','PMW-CHN-2203','2026-07-06',
     15,15,15,40,31,77.5,'under_loaded',0,0,'none','Light schedule, offered to cover Kolkata overflow'),
    ('Manoj Tiwari','Kolkata','PMW-KOL-2210','2026-07-13',
     27,22,15,40,49,122.5,'critical_overload',12,3,'contractor','Chronic overload — contractor support extended'),
    ('Pooja Bhat','Bengaluru','PMW-BLR-2217','2026-07-20',
     21,20,19,40,40,100.0,'balanced',1,1,'none','At capacity, on-target completion')
  ) as q(eng, reg, sref, swk, pdue, psch, pcmp, caph, schh, util, lstat, cry, rsc, bact, nt);

  -- CAPA seed — attach to specific weekly rows via schedule_ref
  insert into public.pm_scheduling_load_capa_actions_r3540 (
    load_log_id, finding_category, root_cause, corrective_action,
    capa_status, sla_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.sla, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PMW-HYD-2225','capacity_shortfall','technician_shortage','hire_contractor','in_progress','sla_at_risk','Ops Head - South','2026-06-05',null,85000.00,'Critical overload in Hyderabad — contractor onboarding in progress'),
    ('PMW-KOL-2222','region_understaffed','technician_shortage','add_headcount','open','contract_penalty','Regional Manager - East','2026-07-10',null,120000.00,'Kolkata chronically understaffed — headcount requisition raised'),
    ('PMW-PUN-2227','chronic_overload','seasonal_demand_spike','rebalance_regions','escalated','customer_escalation','Ops Head - West','2026-07-25',null,60000.00,'Pune 14-PM backlog escalated — rebalancing to Mumbai team'),
    ('PMW-PUN-2208','high_carryover','poor_route_planning','optimize_routes','verification_pending','sla_at_risk','Field Lead - Pune','2026-06-20',null,15000.00,'Route optimization deployed — verifying carryover reduction'),
    ('PMW-HYD-2213','pm_backlog_growing','spare_parts_delay','defer_low_priority_pm','closed','none','Field Lead - Hyderabad','2026-07-12','2026-07-18',8000.00,'Low-priority PMs deferred pending spares — backlog stabilized'),
    ('PMW-DEL-2218','frequent_reschedule','unplanned_breakdowns','authorize_overtime','closed','internal_only','Field Lead - Delhi','2026-05-25','2026-05-28',22000.00,'Overtime authorized to absorb breakdown-driven reschedules'),
    ('PMW-KOL-2210','low_completion_rate','absenteeism','cross_train_technician','overdue','sla_breach','Regional Manager - East','2026-07-20',null,18000.00,'Completion rate low from absenteeism — cross-training past due'),
    ('PMW-BLR-2206','none_flagged','pending_investigation','none_required','open','internal_only','Field Lead - Bengaluru','2026-07-01',null,0.00,'Under-utilized engineer flagged for rebalancing review')
  ) as q(sref, fc, rc, ca, cst, sla, own, tcd, acd, cost, nt)
  join public.pm_scheduling_load_r3540 e
    on e.organization_id = v_org_id and e.schedule_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Load-status distribution
create or replace function public.founder_r3540_load_status_rollup()
returns table(load_status text, weeks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_scheduling_load_r3540)
  select l.load_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pm_scheduling_load_r3540 l
  group by l.load_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3540_load_status_rollup() from public, anon;
grant execute on function public.founder_r3540_load_status_rollup() to authenticated;

-- 2) Region-level workload scorecard
create or replace function public.founder_r3540_region_scorecard()
returns table(
  region text,
  total_weeks bigint,
  total_pm_due bigint,
  total_pm_completed bigint,
  total_carryover bigint,
  over_loaded_weeks bigint,
  critical_weeks bigint,
  avg_utilization_pct numeric,
  completion_pct numeric
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
    coalesce(sum(l.pm_due),0)::bigint,
    coalesce(sum(l.pm_completed),0)::bigint,
    coalesce(sum(l.carryover),0)::bigint,
    count(*) filter (where l.load_status = 'over_loaded')::bigint,
    count(*) filter (where l.load_status = 'critical_overload')::bigint,
    round(avg(l.utilization_pct), 1),
    round(100.0 * coalesce(sum(l.pm_completed),0)::numeric / nullif(sum(l.pm_due),0), 1)
  from public.pm_scheduling_load_r3540 l
  group by l.region
  order by count(*) filter (where l.load_status = 'critical_overload') desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3540_region_scorecard() from public, anon;
grant execute on function public.founder_r3540_region_scorecard() to authenticated;

-- 3) Region × load-status matrix
create or replace function public.founder_r3540_region_load_status_matrix()
returns table(region text, load_status text, weeks bigint, total_carryover bigint, avg_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, l.load_status, count(*)::bigint,
    coalesce(sum(l.carryover),0)::bigint,
    round(avg(l.utilization_pct), 1)
  from public.pm_scheduling_load_r3540 l
  group by l.region, l.load_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3540_region_load_status_matrix() from public, anon;
grant execute on function public.founder_r3540_region_load_status_matrix() to authenticated;

-- 4) Monthly workload trend
create or replace function public.founder_r3540_monthly_workload_trend()
returns table(
  month date,
  weeks bigint,
  total_pm_due bigint,
  total_pm_completed bigint,
  total_carryover bigint,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.schedule_week)::date,
    count(*)::bigint,
    coalesce(sum(l.pm_due),0)::bigint,
    coalesce(sum(l.pm_completed),0)::bigint,
    coalesce(sum(l.carryover),0)::bigint,
    round(avg(l.utilization_pct), 1)
  from public.pm_scheduling_load_r3540 l
  group by date_trunc('month', l.schedule_week)
  order by date_trunc('month', l.schedule_week) desc;
end;
$$;

revoke execute on function public.founder_r3540_monthly_workload_trend() from public, anon;
grant execute on function public.founder_r3540_monthly_workload_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3540_capa_status_board()
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
  from public.pm_scheduling_load_capa_actions_r3540 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3540_capa_status_board() from public, anon;
grant execute on function public.founder_r3540_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3540_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pm_scheduling_load_capa_actions_r3540)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pm_scheduling_load_capa_actions_r3540 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3540_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3540_root_cause_pareto() to authenticated;

-- 7) Backlog / SLA-impact digest
create or replace function public.founder_r3540_backlog_impact_digest()
returns table(sla_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.sla_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.pm_scheduling_load_capa_actions_r3540 c
  group by c.sla_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3540_backlog_impact_digest() from public, anon;
grant execute on function public.founder_r3540_backlog_impact_digest() to authenticated;

-- 8) High-risk workload queue (critical-overload / high-carryover / low-completion)
create or replace function public.founder_r3540_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  schedule_ref text,
  schedule_week date,
  load_status text,
  pm_due int,
  pm_completed int,
  carryover int,
  utilization_pct numeric,
  balancing_action text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.schedule_ref, l.schedule_week,
    l.load_status, l.pm_due, l.pm_completed, l.carryover, l.utilization_pct,
    l.balancing_action, l.notes
  from public.pm_scheduling_load_r3540 l
  where l.load_status in ('over_loaded','critical_overload')
     or l.carryover >= 6
     or l.utilization_pct >= 110
     or l.pm_completed < (l.pm_due * 0.7)
     or l.reschedule_count >= 3
     or l.balancing_action in ('contractor','escalate')
  order by l.utilization_pct desc, l.carryover desc;
end;
$$;

revoke execute on function public.founder_r3540_high_risk_queue() from public, anon;
grant execute on function public.founder_r3540_high_risk_queue() to authenticated;
