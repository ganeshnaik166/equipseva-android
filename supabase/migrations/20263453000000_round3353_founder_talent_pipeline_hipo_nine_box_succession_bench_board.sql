-- Round 3353: Founder Talent Pipeline, HiPo Nine-Box & Succession-Bench Board
-- Talent review — employee × department × band × performance-axis × potential-axis × nine-box cell × retention priority × succession readiness × development action × flight-risk × talent verdict × CAPA

-- =============================================================================
-- TABLE 1: talent_pipeline_hipo_r3353 — per-employee talent-review records
-- =============================================================================
create table if not exists public.talent_pipeline_hipo_r3353 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  department text not null check (department in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  "current_role" text not null,
  current_band text not null check (current_band in (
    'l1','l2','l3','l4','l5'
  )),
  review_date date not null,
  performance_axis text not null check (performance_axis in (
    'low','medium','high'
  )),
  potential_axis text not null check (potential_axis in (
    'low','medium','high'
  )),
  nine_box_cell text not null check (nine_box_cell in (
    'star','high_performer','high_potential','core_player','solid',
    'inconsistent','risk','dilemma','underperformer'
  )),
  retention_priority text not null check (retention_priority in (
    'critical','high','standard'
  )),
  successor_for_role text,
  readiness text not null check (readiness in (
    'ready_now','ready_1yr','ready_2yr','not_ready'
  )),
  development_action text not null check (development_action in (
    'stretch_assignment','mentoring','training','job_rotation','none'
  )),
  flight_risk text not null check (flight_risk in (
    'low','medium','high'
  )),
  talent_verdict text not null check (talent_verdict in (
    'accelerate','retain_develop','monitor','performance_plan','exit_managed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.talent_pipeline_hipo_r3353 enable row level security;

create index if not exists idx_talent_pipeline_hipo_r3353_org on public.talent_pipeline_hipo_r3353(organization_id);
create index if not exists idx_talent_pipeline_hipo_r3353_date on public.talent_pipeline_hipo_r3353(review_date);
create index if not exists idx_talent_pipeline_hipo_r3353_verdict on public.talent_pipeline_hipo_r3353(talent_verdict);

-- =============================================================================
-- TABLE 2: talent_pipeline_hipo_capa_actions_r3353 — development / retention / succession actions
-- =============================================================================
create table if not exists public.talent_pipeline_hipo_capa_actions_r3353 (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.talent_pipeline_hipo_r3353(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'succession_gap','flight_risk_high','development_stalled','bench_strength_low',
    'retention_at_risk','readiness_gap','performance_concern','key_person_dependency'
  )),
  root_cause text not null check (root_cause in (
    'limited_growth_path','compensation_below_market','manager_relationship','no_successor_identified',
    'skill_gap','engagement_decline','role_mismatch','pending_investigation','workload_burnout'
  )),
  corrective_action text not null check (corrective_action in (
    'stretch_assignment','mentoring_program','training_enrollment','job_rotation','compensation_review',
    'succession_plan_build','retention_bonus','career_path_defined','none_required','performance_plan_start'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_impact text not null check (risk_impact in (
    'leadership_gap','key_person_dependency','attrition_risk','bench_strength_low','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.talent_pipeline_hipo_capa_actions_r3353 enable row level security;

create index if not exists idx_talent_capa_r3353_review on public.talent_pipeline_hipo_capa_actions_r3353(review_id);
create index if not exists idx_talent_capa_r3353_status on public.talent_pipeline_hipo_capa_actions_r3353(capa_status);

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

  -- 14 talent-review rows
  insert into public.talent_pipeline_hipo_r3353 (
    organization_id, employee_name, department, "current_role", current_band,
    review_date, performance_axis, potential_axis, nine_box_cell, retention_priority,
    successor_for_role, readiness, development_action, flight_risk, talent_verdict, notes
  )
  select v_org_id, q.name, q.dept, q.role, q.band,
    q.rdate::date, q.perf, q.pot, q.cell, q.retn,
    q.succ, q.rdy, q.dev, q.frisk, q.verdict, q.nt
  from (values
    ('Rajesh Kumar','field_engineering','Senior Field Engineer','l3',
     '2026-07-15','high','high','star','critical',
     'Regional Service Lead','ready_now','stretch_assignment','low','accelerate','Top field performer at Apollo Chennai zone, ready for regional lead role'),
    ('Priya Sharma','sales','Enterprise Sales Manager','l4',
     '2026-07-15','high','high','star','critical',
     'VP Sales','ready_1yr','mentoring','medium','accelerate','Consistent 130 pct quota across Fortis Gurgaon accounts, grooming for VP'),
    ('Anil Reddy','leadership','Head of Operations','l5',
     '2026-07-15','high','medium','high_performer','critical',
     'COO','ready_1yr','mentoring','low','retain_develop','Strong ops leader on COO succession track'),
    ('Sneha Nair','finance','Finance Controller','l4',
     '2026-07-14','high','high','star','critical',
     'CFO','ready_2yr','training','medium','accelerate','High-potential controller in CFO successor pipeline'),
    ('Vikram Singh','field_engineering','Field Engineer','l2',
     '2026-07-14','medium','high','high_potential','high',
     'Senior Field Engineer','ready_1yr','job_rotation','medium','retain_develop','Fast learner at Manipal Bengaluru site, rotate across regions'),
    ('Meera Iyer','support','Support Team Lead','l3',
     '2026-07-14','high','medium','high_performer','high',
     'Support Manager','ready_now','stretch_assignment','low','retain_develop','Reliable lead, ready for support manager role'),
    ('Arjun Menon','office_ops','Operations Analyst','l2',
     '2026-07-13','medium','medium','core_player','standard',
     null,'ready_2yr','training','low','monitor','Steady contributor, develop analytics and process skills'),
    ('Kavya Rao','sales','Sales Executive','l1',
     '2026-07-13','medium','high','high_potential','high',
     'Sales Manager','ready_2yr','mentoring','medium','retain_develop','Promising junior at KIMS Hyderabad territory, high ceiling'),
    ('Suresh Patel','field_engineering','Senior Field Engineer','l3',
     '2026-07-13','low','medium','risk','high',
     null,'not_ready','training','high','performance_plan','Recent CSAT dip post-reorg, elevated flight-risk'),
    ('Deepa Krishnan','finance','Accounts Manager','l3',
     '2026-07-12','high','low','solid','standard',
     null,'not_ready','none','low','retain_develop','Trusted professional at AIIMS Delhi account, limited upward interest'),
    ('Rohan Gupta','sales','Regional Sales Head','l4',
     '2026-07-12','low','high','dilemma','high',
     null,'not_ready','mentoring','high','performance_plan','High potential but underdelivering, structured coaching plan'),
    ('Ananya Desai','office_ops','Office Manager','l2',
     '2026-07-12','medium','low','inconsistent','standard',
     null,'not_ready','training','medium','monitor','Inconsistent quarters, needs process discipline training'),
    ('Karthik Subramanian','support','Support Engineer','l1',
     '2026-07-11','low','low','underperformer','standard',
     null,'not_ready','training','high','exit_managed','Sustained underperformance at CMC Vellore desk, managed exit in progress'),
    ('Nisha Verma','leadership','Product Lead','l4',
     '2026-07-11','high','high','star','critical',
     'VP Product','ready_1yr','stretch_assignment','high','accelerate','Star performer but high flight-risk, retention critical')
  ) as q(name, dept, role, band, rdate, perf, pot, cell, retn, succ, rdy, dev, frisk, verdict, nt);

  -- CAPA seed — development / retention / succession actions attached via employee_name
  insert into public.talent_pipeline_hipo_capa_actions_r3353 (
    review_id, finding_category, root_cause, corrective_action,
    capa_status, risk_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Suresh Patel','flight_risk_high','compensation_below_market','retention_bonus','in_progress','attrition_risk','2026-07-25',null,150000.00,'Retention bonus proposed after reorg to stabilise senior field cover'),
    ('Rohan Gupta','performance_concern','role_mismatch','performance_plan_start','open','key_person_dependency','2026-07-30',null,0.00,'30-60-90 performance plan initiated with weekly check-ins'),
    ('Karthik Subramanian','performance_concern','skill_gap','succession_plan_build','escalated','bench_strength_low','2026-07-22',null,0.00,'Managed exit underway, backfill requisition raised for support desk'),
    ('Nisha Verma','retention_at_risk','compensation_below_market','retention_bonus','open','leadership_gap','2026-07-28',null,250000.00,'Star at high flight-risk, comp review plus equity refresh proposed'),
    ('Vikram Singh','development_stalled','limited_growth_path','job_rotation','in_progress','none','2026-08-05',null,20000.00,'Cross-region rotation to build breadth toward senior engineer'),
    ('Kavya Rao','readiness_gap','skill_gap','mentoring_program','verification_pending','bench_strength_low','2026-07-20','2026-07-18',15000.00,'Enrolled in leadership mentoring cohort, verifying progress'),
    ('Anil Reddy','succession_gap','no_successor_identified','succession_plan_build','closed','leadership_gap','2026-07-10','2026-07-09',0.00,'COO succession chart finalised with two-deep bench')
  ) as q(name, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.talent_pipeline_hipo_r3353 e
    on e.organization_id = v_org_id and e.employee_name = q.name;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Talent verdict distribution
create or replace function public.founder_r3353_verdict_rollup()
returns table(talent_verdict text, employees bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.talent_pipeline_hipo_r3353)
  select l.talent_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.talent_pipeline_hipo_r3353 l
  group by l.talent_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3353_verdict_rollup() from public, anon;
grant execute on function public.founder_r3353_verdict_rollup() to authenticated;

-- 2) Department-level talent scorecard
create or replace function public.founder_r3353_department_scorecard()
returns table(
  department text,
  total_employees bigint,
  accelerate bigint,
  retain_develop bigint,
  monitor_or_plan bigint,
  high_flight_risk bigint,
  critical_retention bigint,
  ready_now bigint,
  hipo_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    count(*) filter (where l.talent_verdict = 'accelerate')::bigint,
    count(*) filter (where l.talent_verdict = 'retain_develop')::bigint,
    count(*) filter (where l.talent_verdict in ('monitor','performance_plan','exit_managed'))::bigint,
    count(*) filter (where l.flight_risk = 'high')::bigint,
    count(*) filter (where l.retention_priority = 'critical')::bigint,
    count(*) filter (where l.readiness = 'ready_now')::bigint,
    round(100.0 * count(*) filter (where l.nine_box_cell in ('star','high_potential','high_performer'))::numeric / nullif(count(*),0), 1)
  from public.talent_pipeline_hipo_r3353 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3353_department_scorecard() from public, anon;
grant execute on function public.founder_r3353_department_scorecard() to authenticated;

-- 3) Nine-box matrix: performance axis × potential axis
create or replace function public.founder_r3353_nine_box_matrix()
returns table(performance_axis text, potential_axis text, employees bigint, critical_retention bigint, high_flight_risk bigint, ready_now bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.performance_axis, l.potential_axis, count(*)::bigint,
    count(*) filter (where l.retention_priority = 'critical')::bigint,
    count(*) filter (where l.flight_risk = 'high')::bigint,
    count(*) filter (where l.readiness = 'ready_now')::bigint
  from public.talent_pipeline_hipo_r3353 l
  group by l.performance_axis, l.potential_axis
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3353_nine_box_matrix() from public, anon;
grant execute on function public.founder_r3353_nine_box_matrix() to authenticated;

-- 4) Review-date trend
create or replace function public.founder_r3353_review_trend()
returns table(review_date date, reviews bigint, accelerate bigint, exit_managed bigint, high_flight_risk bigint, critical_retention bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_date,
    count(*)::bigint,
    count(*) filter (where l.talent_verdict = 'accelerate')::bigint,
    count(*) filter (where l.talent_verdict = 'exit_managed')::bigint,
    count(*) filter (where l.flight_risk = 'high')::bigint,
    count(*) filter (where l.retention_priority = 'critical')::bigint
  from public.talent_pipeline_hipo_r3353 l
  group by l.review_date
  order by l.review_date desc;
end;
$$;

revoke execute on function public.founder_r3353_review_trend() from public, anon;
grant execute on function public.founder_r3353_review_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3353_capa_status_board()
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
  from public.talent_pipeline_hipo_capa_actions_r3353 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3353_capa_status_board() from public, anon;
grant execute on function public.founder_r3353_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3353_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.talent_pipeline_hipo_capa_actions_r3353)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.talent_pipeline_hipo_capa_actions_r3353 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3353_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3353_root_cause_pareto() to authenticated;

-- 7) Risk-impact digest
create or replace function public.founder_r3353_risk_impact_digest()
returns table(risk_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.talent_pipeline_hipo_capa_actions_r3353 c
  group by c.risk_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3353_risk_impact_digest() from public, anon;
grant execute on function public.founder_r3353_risk_impact_digest() to authenticated;

-- 8) High-risk talent queue (individual concerns)
create or replace function public.founder_r3353_high_risk_queue()
returns table(
  employee_name text,
  department text,
  "current_role" text,
  current_band text,
  nine_box_cell text,
  talent_verdict text,
  retention_priority text,
  flight_risk text,
  readiness text,
  successor_for_role text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l."current_role", l.current_band,
    l.nine_box_cell, l.talent_verdict, l.retention_priority, l.flight_risk,
    l.readiness, l.successor_for_role, l.notes
  from public.talent_pipeline_hipo_r3353 l
  where l.talent_verdict in ('performance_plan','exit_managed','monitor')
     or l.flight_risk = 'high'
     or l.retention_priority = 'critical'
     or l.nine_box_cell in ('risk','dilemma','underperformer','inconsistent')
  order by
    case l.flight_risk when 'high' then 0 when 'medium' then 1 else 2 end,
    l.retention_priority,
    l.employee_name;
end;
$$;

revoke execute on function public.founder_r3353_high_risk_queue() from public, anon;
grant execute on function public.founder_r3353_high_risk_queue() to authenticated;
