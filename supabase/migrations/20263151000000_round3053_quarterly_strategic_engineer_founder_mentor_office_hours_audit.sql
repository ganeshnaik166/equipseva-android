-- Round 3053: Founder Quarterly Strategic Engineer-Founder Mentor Office-Hours Audit
-- Two tables (_r3053) + 7 SECURITY DEFINER RPCs gated by is_founder()

create table if not exists quarterly_mentor_office_hours_sessions_r3053 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  fiscal_quarter text not null check (fiscal_quarter in ('FY26_Q1','FY26_Q2','FY26_Q3','FY26_Q4','FY27_Q1','FY27_Q2')),
  engineer_code text not null,
  engineer_tier text not null check (engineer_tier in ('bronze','silver','gold','platinum','diamond')),
  scheduled_at timestamptz not null,
  duration_minutes int not null check (duration_minutes between 15 and 120),
  session_format text not null check (session_format in ('1on1_video','1on1_in_person','group_video','workshop','async_loom')),
  topic_category text not null check (topic_category in ('career_path','technical_mastery','field_safety','customer_handling','tier_progression','founder_vision','escalation_playbook')),
  founder_present boolean not null default true,
  attendance_status text not null check (attendance_status in ('attended','no_show','rescheduled','cancelled_by_engineer','cancelled_by_founder')),
  satisfaction_score int check (satisfaction_score between 1 and 10),
  action_items_count int not null default 0 check (action_items_count between 0 and 20),
  followup_required boolean not null default false,
  region text not null check (region in ('south','north','east','west','central')),
  city text not null
);

create table if not exists quarterly_mentor_audit_findings_r3053 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  fiscal_quarter text not null check (fiscal_quarter in ('FY26_Q1','FY26_Q2','FY26_Q3','FY26_Q4','FY27_Q1','FY27_Q2')),
  finding_code text not null,
  severity text not null check (severity in ('p0','p1','p2','p3','observation')),
  finding_area text not null check (finding_area in ('coverage_gap','session_quality','followup_lapse','tier_mismatch','founder_overload','documentation','engineer_disengagement','metric_drift','founder_owned')),
  affected_engineers_count int not null check (affected_engineers_count between 0 and 500),
  founder_owned boolean not null default true,
  status text not null check (status in ('open','in_remediation','resolved','accepted_risk','deferred')),
  remediation_due_date date,
  closed_at timestamptz,
  notes text
);

alter table quarterly_mentor_office_hours_sessions_r3053 enable row level security;
alter table quarterly_mentor_audit_findings_r3053 enable row level security;

drop policy if exists sessions_founder_select on quarterly_mentor_office_hours_sessions_r3053;
create policy sessions_founder_select on quarterly_mentor_office_hours_sessions_r3053
  for select to authenticated using (is_founder());

drop policy if exists findings_founder_select on quarterly_mentor_audit_findings_r3053;
create policy findings_founder_select on quarterly_mentor_audit_findings_r3053
  for select to authenticated using (is_founder());

-- Seed: 20 session rows
insert into quarterly_mentor_office_hours_sessions_r3053
  (fiscal_quarter, engineer_code, engineer_tier, scheduled_at, duration_minutes, session_format, topic_category, founder_present, attendance_status, satisfaction_score, action_items_count, followup_required, region, city)
values
  ('FY26_Q3','ENG-2201','platinum','2026-04-02 10:00:00+05:30'::timestamptz, 60, '1on1_video','career_path', true, 'attended', 9, 4, true, 'south','Hyderabad'),
  ('FY26_Q3','ENG-2202','gold','2026-04-03 11:30:00+05:30'::timestamptz, 45, '1on1_video','tier_progression', true, 'attended', 8, 3, true, 'south','Bengaluru'),
  ('FY26_Q3','ENG-2203','silver','2026-04-05 14:00:00+05:30'::timestamptz, 30, 'group_video','field_safety', true, 'attended', 7, 2, false, 'west','Mumbai'),
  ('FY26_Q3','ENG-2204','bronze','2026-04-07 09:00:00+05:30'::timestamptz, 30, 'group_video','founder_vision', true, 'attended', 8, 1, false, 'north','Delhi'),
  ('FY26_Q3','ENG-2205','diamond','2026-04-09 16:00:00+05:30'::timestamptz, 90, '1on1_in_person','escalation_playbook', true, 'attended', 10, 6, true, 'south','Chennai'),
  ('FY26_Q3','ENG-2206','gold','2026-04-11 10:30:00+05:30'::timestamptz, 45, '1on1_video','customer_handling', true, 'no_show', null, 0, true, 'east','Kolkata'),
  ('FY26_Q3','ENG-2207','silver','2026-04-12 13:00:00+05:30'::timestamptz, 30, 'async_loom','technical_mastery', false, 'attended', 6, 2, false, 'central','Nagpur'),
  ('FY26_Q3','ENG-2208','platinum','2026-04-14 15:00:00+05:30'::timestamptz, 60, '1on1_video','career_path', true, 'attended', 9, 3, true, 'south','Hyderabad'),
  ('FY26_Q3','ENG-2209','gold','2026-04-16 11:00:00+05:30'::timestamptz, 45, '1on1_in_person','tier_progression', true, 'rescheduled', null, 0, true, 'west','Pune'),
  ('FY26_Q3','ENG-2210','bronze','2026-04-18 10:00:00+05:30'::timestamptz, 30, 'workshop','field_safety', true, 'attended', 7, 2, false, 'north','Jaipur'),
  ('FY26_Q3','ENG-2211','silver','2026-04-20 14:30:00+05:30'::timestamptz, 30, '1on1_video','customer_handling', true, 'attended', 8, 3, true, 'south','Vijayawada'),
  ('FY26_Q3','ENG-2212','diamond','2026-04-22 16:00:00+05:30'::timestamptz,120, '1on1_in_person','founder_vision', true, 'attended', 10, 5, true, 'south','Hyderabad'),
  ('FY26_Q3','ENG-2213','gold','2026-04-24 09:30:00+05:30'::timestamptz, 45, '1on1_video','technical_mastery', true, 'cancelled_by_engineer', null, 0, true, 'east','Bhubaneswar'),
  ('FY26_Q3','ENG-2214','platinum','2026-04-26 11:00:00+05:30'::timestamptz, 60, '1on1_video','escalation_playbook', true, 'attended', 9, 4, true, 'west','Ahmedabad'),
  ('FY26_Q3','ENG-2215','silver','2026-04-28 13:30:00+05:30'::timestamptz, 30, 'group_video','field_safety', true, 'attended', 7, 1, false, 'central','Indore'),
  ('FY26_Q3','ENG-2216','bronze','2026-04-30 10:00:00+05:30'::timestamptz, 30, 'workshop','founder_vision', true, 'attended', 8, 2, false, 'north','Lucknow'),
  ('FY26_Q3','ENG-2217','gold','2026-05-02 15:00:00+05:30'::timestamptz, 45, '1on1_video','tier_progression', true, 'attended', 9, 3, true, 'south','Bengaluru'),
  ('FY26_Q3','ENG-2218','platinum','2026-05-04 10:30:00+05:30'::timestamptz, 60, '1on1_in_person','career_path', true, 'attended', 10, 5, true, 'south','Chennai'),
  ('FY26_Q3','ENG-2219','silver','2026-05-06 14:00:00+05:30'::timestamptz, 30, 'async_loom','technical_mastery', false, 'attended', 6, 1, false, 'west','Surat'),
  ('FY26_Q3','ENG-2220','diamond','2026-05-08 16:30:00+05:30'::timestamptz, 90, '1on1_in_person','escalation_playbook', true, 'attended', 10, 6, true, 'south','Hyderabad');

-- Seed: 16 finding rows
insert into quarterly_mentor_audit_findings_r3053
  (fiscal_quarter, finding_code, severity, finding_area, affected_engineers_count, founder_owned, status, remediation_due_date, closed_at, notes)
values
  ('FY26_Q3','QMA-001','p1','coverage_gap', 47, true, 'in_remediation','2026-06-30'::date, null, 'East region engineers underserved — only 1 session per quarter'),
  ('FY26_Q3','QMA-002','p2','session_quality', 12, true, 'open','2026-07-15'::date, null, 'Group video format scores 1.8 pts below 1-on-1'),
  ('FY26_Q3','QMA-003','p0','founder_overload', 220, true, 'in_remediation','2026-06-15'::date, null, 'Founder calendar at 142% of sustainable load'),
  ('FY26_Q3','QMA-004','p3','documentation', 8, true, 'resolved',null, '2026-05-12 10:00:00+05:30'::timestamptz, 'Action items not logged for 8 sessions in Apr — template deployed'),
  ('FY26_Q3','QMA-005','p2','followup_lapse', 31, true, 'open','2026-07-30'::date, null, '31 followup_required sessions had no 14-day check-in'),
  ('FY26_Q3','QMA-006','p1','tier_mismatch', 19, true, 'in_remediation','2026-07-01'::date, null, 'Bronze engineers given platinum-level topics — comprehension gap'),
  ('FY26_Q3','QMA-007','p2','engineer_disengagement', 14, true, 'open','2026-08-01'::date, null, '14 engineers skipped 2+ consecutive sessions'),
  ('FY26_Q3','QMA-008','observation','metric_drift', 0, true, 'accepted_risk',null, null, 'Satisfaction trending -0.3 QoQ — within tolerance band'),
  ('FY26_Q3','QMA-009','p3','documentation', 5, true, 'resolved',null, '2026-05-20 14:00:00+05:30'::timestamptz, 'Loom recordings unindexed — search added'),
  ('FY26_Q3','QMA-010','p1','coverage_gap', 28, true, 'open','2026-07-10'::date, null, 'Central region 0 platinum sessions in Q3'),
  ('FY26_Q3','QMA-011','p2','session_quality', 22, true, 'in_remediation','2026-07-20'::date, null, 'Async loom format below 7.0 satisfaction floor'),
  ('FY26_Q3','QMA-012','p0','founder_owned', 1, true, 'in_remediation','2026-06-20'::date, null, 'Founder is single point of failure — no delegate'),
  ('FY26_Q3','QMA-013','p3','documentation',13, false,'deferred','2026-09-30'::date, null, 'Engineer self-reflections not uploaded'),
  ('FY26_Q3','QMA-014','p2','followup_lapse', 18, true, 'open','2026-08-10'::date, null, '18 platinum sessions need quarterly career-path review'),
  ('FY26_Q3','QMA-015','observation','metric_drift', 0, true, 'accepted_risk',null, null, 'Group sessions cost-effective but lower NPS — acceptable trade-off'),
  ('FY26_Q3','QMA-016','p1','tier_mismatch', 9, true, 'resolved',null, '2026-05-28 11:00:00+05:30'::timestamptz, '9 mistier engineers rebooked to correct topic stream');

-- RPC 1: quarter rollup
create or replace function r3053_quarter_rollup()
returns table(
  fiscal_quarter text,
  sessions_total int,
  sessions_attended int,
  no_show_count int,
  avg_satisfaction numeric,
  founder_minutes int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      s.fiscal_quarter,
      count(*)::int as sessions_total,
      (count(*) filter (where s.attendance_status = 'attended'))::int as sessions_attended,
      (count(*) filter (where s.attendance_status = 'no_show'))::int as no_show_count,
      round(avg(s.satisfaction_score) filter (where s.satisfaction_score is not null), 2) as avg_satisfaction,
      coalesce(sum(s.duration_minutes) filter (where s.founder_present and s.attendance_status='attended'),0)::int as founder_minutes
    from quarterly_mentor_office_hours_sessions_r3053 s
    group by s.fiscal_quarter
    order by s.fiscal_quarter;
end; $$;

-- RPC 2: tier x topic matrix
create or replace function r3053_tier_topic_matrix()
returns table(
  engineer_tier text,
  topic_category text,
  session_count int,
  avg_score numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.engineer_tier, s.topic_category,
      count(*)::int as session_count,
      round(avg(s.satisfaction_score),2) as avg_score
    from quarterly_mentor_office_hours_sessions_r3053 s
    where s.attendance_status='attended'
    group by s.engineer_tier, s.topic_category
    order by s.engineer_tier, s.topic_category;
end; $$;

-- RPC 3: region coverage gap
create or replace function r3053_region_coverage_gap()
returns table(
  region text,
  attended int,
  no_show int,
  rescheduled int,
  cancelled int,
  coverage_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.region,
      (count(*) filter (where s.attendance_status='attended'))::int as attended,
      (count(*) filter (where s.attendance_status='no_show'))::int as no_show,
      (count(*) filter (where s.attendance_status='rescheduled'))::int as rescheduled,
      (count(*) filter (where s.attendance_status in ('cancelled_by_engineer','cancelled_by_founder')))::int as cancelled,
      round(100.0 * (count(*) filter (where s.attendance_status='attended'))::numeric / nullif(count(*),0), 1) as coverage_pct
    from quarterly_mentor_office_hours_sessions_r3053 s
    group by s.region
    order by coverage_pct asc nulls last;
end; $$;

-- RPC 4: format effectiveness
create or replace function r3053_format_effectiveness()
returns table(
  session_format text,
  session_count int,
  avg_satisfaction numeric,
  avg_action_items numeric,
  followup_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.session_format,
      count(*)::int as session_count,
      round(avg(s.satisfaction_score),2) as avg_satisfaction,
      round(avg(s.action_items_count),2) as avg_action_items,
      round(100.0 * (count(*) filter (where s.followup_required))::numeric / nullif(count(*),0), 1) as followup_rate_pct
    from quarterly_mentor_office_hours_sessions_r3053 s
    where s.attendance_status='attended'
    group by s.session_format
    order by avg_satisfaction desc nulls last;
end; $$;

-- RPC 5: open findings by severity
create or replace function r3053_findings_by_severity()
returns table(
  severity text,
  total int,
  open_count int,
  in_remediation int,
  resolved int,
  affected_engineers int
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.severity,
      count(*)::int as total,
      (count(*) filter (where f.status='open'))::int as open_count,
      (count(*) filter (where f.status='in_remediation'))::int as in_remediation,
      (count(*) filter (where f.status='resolved'))::int as resolved,
      coalesce(sum(f.affected_engineers_count),0)::int as affected_engineers
    from quarterly_mentor_audit_findings_r3053 f
    group by f.severity
    order by case f.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 when 'p3' then 3 else 4 end;
end; $$;

-- RPC 6: founder load risk
create or replace function r3053_founder_load_risk()
returns table(
  fiscal_quarter text,
  founder_hours numeric,
  sessions_with_founder int,
  unique_engineers int,
  load_signal text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.fiscal_quarter,
      round(sum(s.duration_minutes) filter (where s.founder_present)::numeric / 60.0, 1) as founder_hours,
      (count(*) filter (where s.founder_present))::int as sessions_with_founder,
      count(distinct s.engineer_code)::int as unique_engineers,
      case
        when sum(s.duration_minutes) filter (where s.founder_present) > 1200 then 'overloaded'
        when sum(s.duration_minutes) filter (where s.founder_present) > 900 then 'stretched'
        else 'sustainable'
      end as load_signal
    from quarterly_mentor_office_hours_sessions_r3053 s
    group by s.fiscal_quarter
    order by s.fiscal_quarter;
end; $$;

-- RPC 7: open findings detail
create or replace function r3053_open_findings_detail()
returns table(
  finding_code text,
  severity text,
  finding_area text,
  affected_engineers_count int,
  status text,
  remediation_due_date date,
  days_to_due int,
  notes text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.finding_code, f.severity, f.finding_area, f.affected_engineers_count, f.status,
      f.remediation_due_date,
      case when f.remediation_due_date is not null
           then (f.remediation_due_date - current_date)::int
           else null end as days_to_due,
      f.notes
    from quarterly_mentor_audit_findings_r3053 f
    where f.status in ('open','in_remediation')
    order by case f.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 when 'p3' then 3 else 4 end,
             f.remediation_due_date nulls last;
end; $$;

revoke all on function r3053_quarter_rollup() from public, anon;
revoke all on function r3053_tier_topic_matrix() from public, anon;
revoke all on function r3053_region_coverage_gap() from public, anon;
revoke all on function r3053_format_effectiveness() from public, anon;
revoke all on function r3053_findings_by_severity() from public, anon;
revoke all on function r3053_founder_load_risk() from public, anon;
revoke all on function r3053_open_findings_detail() from public, anon;

grant execute on function r3053_quarter_rollup() to authenticated;
grant execute on function r3053_tier_topic_matrix() to authenticated;
grant execute on function r3053_region_coverage_gap() to authenticated;
grant execute on function r3053_format_effectiveness() to authenticated;
grant execute on function r3053_findings_by_severity() to authenticated;
grant execute on function r3053_founder_load_risk() to authenticated;
grant execute on function r3053_open_findings_detail() to authenticated;
