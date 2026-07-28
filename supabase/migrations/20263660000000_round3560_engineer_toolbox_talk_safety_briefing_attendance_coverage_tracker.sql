-- Round 3560: Engineer Toolbox-Talk / Safety-Briefing Attendance & Coverage Tracker
-- Daily pre-work toolbox-talk / safety-briefing attendance + topic-coverage tracker —
-- engineer × region × topic × attendance × coverage_status × acknowledgment × CAPA closure

-- =============================================================================
-- TABLE 1: toolbox_talk_r3560 — per-briefing attendance & coverage log
-- =============================================================================
create table if not exists public.toolbox_talk_r3560 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  briefing_code text not null,
  engineer_name text not null,
  region text not null,
  briefing_date date not null,
  conducted_by text not null,
  topic text not null check (topic in (
    'electrical_safety','lifting_handling','ppe','biohazard',
    'working_at_height','tool_safety','emergency_response'
  )),
  attendees int not null,
  team_size int not null,
  attendance_pct numeric(5,2),
  duration_min int,
  coverage_status text not null check (coverage_status in (
    'full','partial','skipped','makeup_pending'
  )),
  acknowledgment_captured boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.toolbox_talk_r3560 enable row level security;

create index if not exists idx_toolbox_talk_r3560_org on public.toolbox_talk_r3560(organization_id);
create index if not exists idx_toolbox_talk_r3560_date on public.toolbox_talk_r3560(briefing_date);
create index if not exists idx_toolbox_talk_r3560_status on public.toolbox_talk_r3560(coverage_status);

-- =============================================================================
-- TABLE 2: toolbox_talk_capa_actions_r3560 — CAPA & coverage-gap actions
-- =============================================================================
create table if not exists public.toolbox_talk_capa_actions_r3560 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  briefing_log_id uuid not null references public.toolbox_talk_r3560(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'low_attendance','no_acknowledgment','topic_skipped','makeup_overdue',
    'short_duration','ppe_gap','high_risk_topic_uncovered','repeat_absentee'
  )),
  root_cause text not null check (root_cause in (
    'scheduling_conflict','engineer_on_leave','emergency_callout','trainer_unavailable',
    'poor_planning','language_barrier','tool_shortage','awareness_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reschedule_makeup_session','capture_digital_acknowledgment','assign_backup_trainer',
    'enforce_daily_briefing','translate_material','provide_ppe','one_on_one_coaching',
    'escalate_to_supervisor','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  coverage_impact text not null check (coverage_impact in (
    'safety_critical','compliance_finding','audit_observation','none','internal_only','repeat_gap'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.toolbox_talk_capa_actions_r3560 enable row level security;

create index if not exists idx_toolbox_talk_capa_r3560_log on public.toolbox_talk_capa_actions_r3560(briefing_log_id);
create index if not exists idx_toolbox_talk_capa_r3560_status on public.toolbox_talk_capa_actions_r3560(capa_status);

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

  -- 16 briefing rows
  insert into public.toolbox_talk_r3560 (
    organization_id, briefing_code, engineer_name, region, briefing_date, conducted_by,
    topic, attendees, team_size, attendance_pct, duration_min, coverage_status,
    acknowledgment_captured, notes
  )
  select v_org_id, q.bcode, q.engr, q.rgn, q.bdate::date, q.cby,
    q.tpc, q.att, q.tsz, q.apct, q.dmin, q.cvs,
    q.ack, q.nt
  from (values
    ('TBT-BLR-01','Ramesh Kumar','Bengaluru','2026-07-27','Suresh Nair',
     'electrical_safety',8,8,100.0,15,'full',true,'Full turnout, LOTO refresher covered'),
    ('TBT-BLR-02','Ramesh Kumar','Bengaluru','2026-07-26','Suresh Nair',
     'ppe',7,8,87.5,12,'full',true,'One engineer on service call, briefed on return'),
    ('TBT-CHN-01','Anand Raj','Chennai','2026-07-27','Priya Menon',
     'lifting_handling',6,9,66.7,10,'partial',true,'Partial coverage — 3 engineers at customer site'),
    ('TBT-CHN-02','Anand Raj','Chennai','2026-07-25','Priya Menon',
     'working_at_height',0,9,0.0,0,'skipped',false,'Briefing skipped — emergency callout across team'),
    ('TBT-HYD-01','Vijay Reddy','Hyderabad','2026-07-27','Kiran Rao',
     'tool_safety',10,10,100.0,18,'full',true,'Power-tool inspection walk-through, all acknowledged'),
    ('TBT-HYD-02','Vijay Reddy','Hyderabad','2026-07-24','Kiran Rao',
     'biohazard',8,10,80.0,14,'partial',true,'Biomedical waste handling, 2 absentees flagged for makeup'),
    ('TBT-MUM-01','Farhan Shaikh','Mumbai','2026-07-27','Deepa Iyer',
     'emergency_response',11,12,91.7,20,'full',true,'Fire and evacuation drill briefing'),
    ('TBT-MUM-02','Farhan Shaikh','Mumbai','2026-07-23','Deepa Iyer',
     'electrical_safety',5,12,41.7,8,'makeup_pending',false,'Low attendance, no digital ack — makeup scheduled'),
    ('TBT-DEL-01','Amit Sharma','Delhi NCR','2026-07-27','Neha Gupta',
     'ppe',9,9,100.0,12,'full',true,'PPE compliance briefing, all signed'),
    ('TBT-DEL-02','Amit Sharma','Delhi NCR','2026-07-22','Neha Gupta',
     'working_at_height',4,9,44.4,9,'partial',false,'Height-work permit briefing, weak turnout, ack pending'),
    ('TBT-PUN-01','Sachin Patil','Pune','2026-07-26','Rohit Deshmukh',
     'lifting_handling',7,7,100.0,13,'full',true,'Manual handling and trolley safety, full team'),
    ('TBT-PUN-02','Sachin Patil','Pune','2026-07-20','Rohit Deshmukh',
     'tool_safety',6,7,85.7,11,'full',true,'Torque-tool safety, one engineer on leave'),
    ('TBT-KOL-01','Sourav Das','Kolkata','2026-07-27','Ananya Bose',
     'biohazard',0,8,0.0,0,'skipped',false,'Briefing skipped — trainer unavailable, no backup'),
    ('TBT-KOL-02','Sourav Das','Kolkata','2026-07-19','Ananya Bose',
     'emergency_response',6,8,75.0,16,'makeup_pending',true,'Spill-response briefing, 2 absentees, makeup due'),
    ('TBT-AMD-01','Bhavin Shah','Ahmedabad','2026-06-30','Manish Trivedi',
     'electrical_safety',8,8,100.0,15,'full',true,'Monthly electrical safety refresher'),
    ('TBT-AMD-02','Bhavin Shah','Ahmedabad','2026-06-15','Manish Trivedi',
     'ppe',3,8,37.5,7,'makeup_pending',false,'Very low turnout, repeat gap, ack not captured')
  ) as q(bcode, engr, rgn, bdate, cby, tpc, att, tsz, apct, dmin, cvs, ack, nt);

  -- CAPA seed — attach to specific briefings via briefing_code
  insert into public.toolbox_talk_capa_actions_r3560 (
    organization_id, briefing_log_id, finding_category, root_cause, corrective_action,
    capa_status, coverage_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TBT-CHN-02','topic_skipped','emergency_callout','reschedule_makeup_session','open','safety_critical','Priya Menon','2026-07-30',null,0.00,'Working-at-height briefing skipped during callout — makeup mandatory'),
    ('TBT-MUM-02','low_attendance','scheduling_conflict','enforce_daily_briefing','in_progress','compliance_finding','Deepa Iyer','2026-07-31',null,1500.00,'Electrical safety briefing under-attended — reslotting to shift start'),
    ('TBT-MUM-02','no_acknowledgment','awareness_gap','capture_digital_acknowledgment','verification_pending','audit_observation','Farhan Shaikh','2026-07-29',null,0.00,'Digital ack app rollout to Mumbai team'),
    ('TBT-KOL-01','topic_skipped','trainer_unavailable','assign_backup_trainer','escalated','safety_critical','Ananya Bose','2026-07-30',null,5000.00,'No backup trainer in Kolkata — assign and cross-train'),
    ('TBT-DEL-02','makeup_overdue','poor_planning','reschedule_makeup_session','overdue','compliance_finding','Neha Gupta','2026-07-25',null,2000.00,'Height-work makeup session overdue — schedule this week'),
    ('TBT-AMD-02','repeat_absentee','awareness_gap','one_on_one_coaching','in_progress','repeat_gap','Manish Trivedi','2026-08-05',null,3000.00,'Repeat absentee pattern — one-on-one coaching started'),
    ('TBT-HYD-02','low_attendance','engineer_on_leave','reschedule_makeup_session','closed','internal_only','Kiran Rao','2026-07-27','2026-07-26',1000.00,'Biohazard makeup completed for 2 absentees'),
    ('TBT-KOL-02','makeup_overdue','scheduling_conflict','enforce_daily_briefing','closed','internal_only','Ananya Bose','2026-07-22','2026-07-21',500.00,'Emergency-response makeup delivered and acknowledged')
  ) as q(bcode, fc, rc, ca, cst, ci, own, tcd, acd, cost, nt)
  join public.toolbox_talk_r3560 e
    on e.organization_id = v_org_id and e.briefing_code = q.bcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage-status distribution
create or replace function public.founder_r3560_coverage_status_rollup()
returns table(coverage_status text, briefings bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.toolbox_talk_r3560)
  select l.coverage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.toolbox_talk_r3560 l
  group by l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3560_coverage_status_rollup() from public, anon;
grant execute on function public.founder_r3560_coverage_status_rollup() to authenticated;

-- 2) Topic scorecard
create or replace function public.founder_r3560_topic_scorecard()
returns table(
  topic text,
  briefings bigint,
  full_coverage bigint,
  partial_coverage bigint,
  skipped bigint,
  makeup_pending bigint,
  avg_attendance_pct numeric,
  ack_captured bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.topic,
    count(*)::bigint,
    count(*) filter (where l.coverage_status = 'full')::bigint,
    count(*) filter (where l.coverage_status = 'partial')::bigint,
    count(*) filter (where l.coverage_status = 'skipped')::bigint,
    count(*) filter (where l.coverage_status = 'makeup_pending')::bigint,
    round(avg(l.attendance_pct), 1),
    count(*) filter (where l.acknowledgment_captured = true)::bigint
  from public.toolbox_talk_r3560 l
  group by l.topic
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3560_topic_scorecard() from public, anon;
grant execute on function public.founder_r3560_topic_scorecard() to authenticated;

-- 3) Topic × coverage-status matrix
create or replace function public.founder_r3560_topic_coverage_matrix()
returns table(topic text, coverage_status text, briefings bigint, avg_attendance_pct numeric, ack_captured bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.topic, l.coverage_status, count(*)::bigint,
    round(avg(l.attendance_pct), 1),
    count(*) filter (where l.acknowledgment_captured = true)::bigint
  from public.toolbox_talk_r3560 l
  group by l.topic, l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3560_topic_coverage_matrix() from public, anon;
grant execute on function public.founder_r3560_topic_coverage_matrix() to authenticated;

-- 4) Monthly attendance trend
create or replace function public.founder_r3560_monthly_attendance_trend()
returns table(
  month text,
  briefings bigint,
  total_attendees bigint,
  total_team_size bigint,
  avg_attendance_pct numeric,
  skipped bigint,
  makeup_pending bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.briefing_date, 'YYYY-MM'),
    count(*)::bigint,
    sum(l.attendees)::bigint,
    sum(l.team_size)::bigint,
    round(avg(l.attendance_pct), 1),
    count(*) filter (where l.coverage_status = 'skipped')::bigint,
    count(*) filter (where l.coverage_status = 'makeup_pending')::bigint
  from public.toolbox_talk_r3560 l
  group by to_char(l.briefing_date, 'YYYY-MM')
  order by to_char(l.briefing_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3560_monthly_attendance_trend() from public, anon;
grant execute on function public.founder_r3560_monthly_attendance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3560_capa_status_board()
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
  from public.toolbox_talk_capa_actions_r3560 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3560_capa_status_board() from public, anon;
grant execute on function public.founder_r3560_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3560_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.toolbox_talk_capa_actions_r3560)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.toolbox_talk_capa_actions_r3560 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3560_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3560_root_cause_pareto() to authenticated;

-- 7) Coverage-gap impact digest
create or replace function public.founder_r3560_coverage_gap_impact_digest()
returns table(coverage_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.coverage_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.toolbox_talk_capa_actions_r3560 c
  group by c.coverage_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3560_coverage_gap_impact_digest() from public, anon;
grant execute on function public.founder_r3560_coverage_gap_impact_digest() to authenticated;

-- 8) High-risk queue (skipped / low-attendance / no-ack)
create or replace function public.founder_r3560_high_risk_queue()
returns table(
  engineer_name text,
  briefing_code text,
  region text,
  briefing_date date,
  topic text,
  coverage_status text,
  attendees int,
  team_size int,
  attendance_pct numeric,
  acknowledgment_captured boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.briefing_code, l.region, l.briefing_date, l.topic,
    l.coverage_status, l.attendees, l.team_size, l.attendance_pct,
    l.acknowledgment_captured, l.notes
  from public.toolbox_talk_r3560 l
  where l.coverage_status in ('skipped','makeup_pending')
     or l.attendance_pct < 70
     or l.acknowledgment_captured = false
  order by l.briefing_date desc, l.region;
end;
$$;

revoke execute on function public.founder_r3560_high_risk_queue() from public, anon;
grant execute on function public.founder_r3560_high_risk_queue() to authenticated;
