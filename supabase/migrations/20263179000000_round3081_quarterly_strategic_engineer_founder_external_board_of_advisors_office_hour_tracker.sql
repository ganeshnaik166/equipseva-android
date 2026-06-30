-- Round r3081 — Founder Quarterly Strategic Engineer-Founder External Board-of-Advisors Office-Hour Tracker
-- Two tables (_r3081 suffix) + 7 RPCs + seed data.

create table if not exists board_advisor_office_hours_r3081 (
  id uuid primary key default gen_random_uuid(),
  quarter_label text not null check (quarter_label in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  advisor_name text not null,
  advisor_firm text not null,
  advisor_expertise text not null check (advisor_expertise in ('clinical_ops','medtech_regulation','hospital_finance','engineer_ops','go_to_market','fundraising','supply_chain','ai_triage')),
  scheduled_at timestamptz not null,
  duration_minutes int not null check (duration_minutes between 15 and 240),
  attended boolean not null default false,
  founder_rating int check (founder_rating between 1 and 5),
  topics_covered text not null,
  follow_up_required boolean not null default false,
  meeting_format text not null check (meeting_format in ('in_person','video','phone','hybrid')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists board_advisor_action_items_r3081 (
  id uuid primary key default gen_random_uuid(),
  office_hour_id uuid not null references board_advisor_office_hours_r3081(id) on delete cascade,
  action_title text not null,
  action_owner text not null check (action_owner in ('founder','engineering_lead','ops_lead','finance_lead','advisor')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  status text not null check (status in ('open','in_progress','blocked','done','dropped')),
  due_date date,
  completed_at timestamptz,
  impact_estimate_rupees bigint,
  created_at timestamptz not null default now()
);

alter table board_advisor_office_hours_r3081 enable row level security;
alter table board_advisor_action_items_r3081 enable row level security;

drop policy if exists boh_r3081_founder_select on board_advisor_office_hours_r3081;
create policy boh_r3081_founder_select on board_advisor_office_hours_r3081 for select using (is_founder());
drop policy if exists boh_r3081_founder_all on board_advisor_office_hours_r3081;
create policy boh_r3081_founder_all on board_advisor_office_hours_r3081 for all using (is_founder()) with check (is_founder());

drop policy if exists bai_r3081_founder_select on board_advisor_action_items_r3081;
create policy bai_r3081_founder_select on board_advisor_action_items_r3081 for select using (is_founder());
drop policy if exists bai_r3081_founder_all on board_advisor_action_items_r3081;
create policy bai_r3081_founder_all on board_advisor_action_items_r3081 for all using (is_founder()) with check (is_founder());

-- Seed advisors (16 rows)
insert into board_advisor_office_hours_r3081 (quarter_label, advisor_name, advisor_firm, advisor_expertise, scheduled_at, duration_minutes, attended, founder_rating, topics_covered, follow_up_required, meeting_format, notes) values
  ('Q1-2026','Dr Anitha Rao','Apollo Hospitals','clinical_ops','2026-01-12 10:00:00+05:30'::timestamptz,60,true,5,'Class A device repair SLAs; NABH audit prep',true,'in_person','Excellent strategic depth'),
  ('Q1-2026','Vikram Mehta','SeedToScale Capital','fundraising','2026-01-19 15:30:00+05:30'::timestamptz,45,true,4,'Series A narrative; ARR vs GMV framing',true,'video','Push for ARR clarity'),
  ('Q1-2026','Priya Subramanian','CDSCO ex-Director','medtech_regulation','2026-01-26 11:00:00+05:30'::timestamptz,90,true,5,'Class B/C licensing pathway; MDR 2017 compliance',true,'in_person','Critical for super-specialty'),
  ('Q1-2026','Rakesh Iyer','Manipal Hospitals','hospital_finance','2026-02-02 14:00:00+05:30'::timestamptz,60,true,4,'AMC contract pricing; chain procurement',true,'video','Push 3-tier model'),
  ('Q2-2026','Suresh Kumar','HDFC Securities','fundraising','2026-04-08 16:00:00+05:30'::timestamptz,30,true,3,'Pre-Series A bridge structuring',false,'phone',null),
  ('Q2-2026','Dr Meenakshi Sharma','AIIMS Delhi','clinical_ops','2026-04-15 09:30:00+05:30'::timestamptz,75,true,5,'Tertiary care equipment uptime; counterfeit parts',true,'in_person','Sharp on counterfeit parts'),
  ('Q2-2026','Amit Bansal','Flipkart ex-VP','go_to_market','2026-04-22 17:00:00+05:30'::timestamptz,60,false,null,'Tier-2 city expansion playbook',true,'video','Rescheduled to Q3'),
  ('Q2-2026','Lakshmi Narayanan','BharatPe ex-CTO','engineer_ops','2026-05-06 11:00:00+05:30'::timestamptz,90,true,4,'Engineer rotation; supervised training scale',true,'hybrid','Loved certification ladder'),
  ('Q2-2026','Karthik Reddy','Bessemer Venture','fundraising','2026-05-13 14:30:00+05:30'::timestamptz,45,true,4,'Series A pitch dry-run',true,'video','Iterate metric slide'),
  ('Q3-2026','Dr Sanjay Gupta','Fortis Healthcare','clinical_ops','2026-07-10 10:00:00+05:30'::timestamptz,60,true,5,'Code Red protocol; multi-city chain rollout',true,'in_person','Greenlit Fortis pilot'),
  ('Q3-2026','Neha Agarwal','Razorpay','hospital_finance','2026-07-17 15:00:00+05:30'::timestamptz,30,true,3,'Payment reconciliation at scale',false,'phone',null),
  ('Q3-2026','Ramesh Krishnan','Siemens Healthineers ex-MD','supply_chain','2026-07-24 13:00:00+05:30'::timestamptz,120,true,5,'OEM parts authentication; provenance ledger',true,'in_person','Game-changer insights'),
  ('Q3-2026','Dr Tara Bhatt','MD-AI Research','ai_triage','2026-08-07 16:30:00+05:30'::timestamptz,60,true,4,'AI triage model for repair classification',true,'video','Worth a pilot'),
  ('Q4-2026','Arjun Pillai','Sequoia India','fundraising','2026-10-14 11:00:00+05:30'::timestamptz,45,true,5,'Series A term-sheet expectations',true,'in_person','Strong intent'),
  ('Q4-2026','Sneha Joshi','Practo ex-COO','engineer_ops','2026-10-21 14:00:00+05:30'::timestamptz,60,true,4,'Engineer NPS; retention levers',true,'video','Tie certification to NPS'),
  ('Q4-2026','Dr Venkat Iyengar','Narayana Health','clinical_ops','2026-11-04 10:30:00+05:30'::timestamptz,75,false,null,'Cardiac equipment uptime — pending',false,'in_person','Awaiting reschedule');

-- Seed action items (22 rows)
insert into board_advisor_action_items_r3081 (office_hour_id, action_title, action_owner, priority, status, due_date, completed_at, impact_estimate_rupees) values
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Anitha Rao'),'Draft Class A repair SLA matrix','ops_lead','p0','done','2026-02-15'::date,'2026-02-12 18:00:00+05:30'::timestamptz,4500000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Anitha Rao'),'NABH audit dry-run script','founder','p1','in_progress','2026-03-30'::date,null,1800000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Vikram Mehta'),'Rewrite Series A deck — ARR slide','founder','p0','done','2026-02-05'::date,'2026-02-03 22:30:00+05:30'::timestamptz,null),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Vikram Mehta'),'Build investor data-room v2','finance_lead','p1','done','2026-02-20'::date,'2026-02-19 16:00:00+05:30'::timestamptz,null),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Priya Subramanian'),'File Class B device registration','founder','p0','in_progress','2026-04-30'::date,null,12000000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Priya Subramanian'),'CDSCO compliance audit memo','ops_lead','p1','open','2026-05-15'::date,null,3500000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Rakesh Iyer'),'3-tier AMC pricing model','finance_lead','p0','done','2026-02-28'::date,'2026-02-26 11:00:00+05:30'::timestamptz,8500000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Meenakshi Sharma'),'Counterfeit parts blocklist','ops_lead','p0','done','2026-05-10'::date,'2026-05-08 14:00:00+05:30'::timestamptz,6700000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Meenakshi Sharma'),'OEM partner authentication API','engineering_lead','p1','in_progress','2026-06-20'::date,null,9200000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Lakshmi Narayanan'),'Engineer rotation v2 algorithm','engineering_lead','p1','done','2026-06-05'::date,'2026-06-02 19:00:00+05:30'::timestamptz,2300000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Lakshmi Narayanan'),'Certification ladder gamification','engineering_lead','p2','blocked','2026-07-15'::date,null,1500000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Karthik Reddy'),'Pitch deck v4 iteration','founder','p1','done','2026-06-01'::date,'2026-05-30 23:00:00+05:30'::timestamptz,null),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Sanjay Gupta'),'Fortis chain pilot kickoff','founder','p0','in_progress','2026-08-30'::date,null,15000000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Sanjay Gupta'),'Code Red multi-city playbook','ops_lead','p1','open','2026-09-15'::date,null,4800000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Ramesh Krishnan'),'Parts provenance ledger v2','engineering_lead','p0','in_progress','2026-09-20'::date,null,11000000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Ramesh Krishnan'),'Siemens OEM MoU draft','founder','p0','open','2026-09-30'::date,null,25000000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Ramesh Krishnan'),'Supply-chain audit framework','ops_lead','p2','open','2026-10-30'::date,null,3200000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Dr Tara Bhatt'),'AI triage pilot — 50 jobs','engineering_lead','p1','open','2026-10-15'::date,null,2700000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Arjun Pillai'),'Series A term-sheet response','founder','p0','open','2026-11-15'::date,null,250000000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Arjun Pillai'),'Diligence pack — financials','finance_lead','p0','open','2026-11-30'::date,null,null),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Sneha Joshi'),'Engineer NPS quarterly survey','ops_lead','p1','open','2026-12-10'::date,null,1900000),
  ((select id from board_advisor_office_hours_r3081 where advisor_name='Sneha Joshi'),'Retention bonus tied to NPS','finance_lead','p2','open','2026-12-31'::date,null,3800000);

revoke all on board_advisor_office_hours_r3081 from public, anon;
revoke all on board_advisor_action_items_r3081 from public, anon;
grant select on board_advisor_office_hours_r3081 to authenticated;
grant select on board_advisor_action_items_r3081 to authenticated;

-- RPC 1: quarterly attendance summary
create or replace function r3081_quarterly_attendance_summary()
returns table(quarter_label text, scheduled_count int, attended_count int, no_show_count int, attendance_pct numeric, avg_rating numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.quarter_label,
    count(*)::int as scheduled_count,
    (count(*) filter (where h.attended))::int as attended_count,
    (count(*) filter (where not h.attended))::int as no_show_count,
    round(100.0 * (count(*) filter (where h.attended))::numeric / nullif(count(*),0), 1) as attendance_pct,
    round(avg(h.founder_rating) filter (where h.founder_rating is not null), 2) as avg_rating
  from board_advisor_office_hours_r3081 h
  group by h.quarter_label
  order by h.quarter_label;
end; $$;

-- RPC 2: top-rated advisors
create or replace function r3081_top_rated_advisors()
returns table(advisor_name text, advisor_firm text, sessions_attended int, avg_rating numeric, total_duration_minutes int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.advisor_name,
    h.advisor_firm,
    (count(*) filter (where h.attended))::int as sessions_attended,
    round(avg(h.founder_rating) filter (where h.founder_rating is not null), 2) as avg_rating,
    coalesce(sum(h.duration_minutes) filter (where h.attended), 0)::int as total_duration_minutes
  from board_advisor_office_hours_r3081 h
  where h.attended
  group by h.advisor_name, h.advisor_firm
  having avg(h.founder_rating) is not null
  order by avg(h.founder_rating) desc nulls last, sessions_attended desc
  limit 10;
end; $$;

-- RPC 3: action item pipeline by status
create or replace function r3081_action_pipeline_by_status()
returns table(status text, item_count int, total_impact_rupees bigint, p0_count int, p1_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.status,
    count(*)::int as item_count,
    coalesce(sum(a.impact_estimate_rupees), 0)::bigint as total_impact_rupees,
    (count(*) filter (where a.priority='p0'))::int as p0_count,
    (count(*) filter (where a.priority='p1'))::int as p1_count
  from board_advisor_action_items_r3081 a
  group by a.status
  order by case a.status when 'open' then 1 when 'in_progress' then 2 when 'blocked' then 3 when 'done' then 4 when 'dropped' then 5 end;
end; $$;

-- RPC 4: overdue action items
create or replace function r3081_overdue_action_items()
returns table(action_title text, action_owner text, priority text, status text, due_date date, days_overdue int, impact_estimate_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.action_title,
    a.action_owner,
    a.priority,
    a.status,
    a.due_date,
    (current_date - a.due_date)::int as days_overdue,
    a.impact_estimate_rupees
  from board_advisor_action_items_r3081 a
  where a.status not in ('done','dropped')
    and a.due_date is not null
    and a.due_date < current_date
  order by a.due_date asc, a.priority asc;
end; $$;

-- RPC 5: expertise coverage
create or replace function r3081_expertise_coverage()
returns table(advisor_expertise text, advisor_count int, sessions_attended int, avg_rating numeric, follow_ups_open int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.advisor_expertise,
    count(distinct h.advisor_name)::int as advisor_count,
    (count(*) filter (where h.attended))::int as sessions_attended,
    round(avg(h.founder_rating) filter (where h.founder_rating is not null), 2) as avg_rating,
    (count(*) filter (where h.follow_up_required))::int as follow_ups_open
  from board_advisor_office_hours_r3081 h
  group by h.advisor_expertise
  order by sessions_attended desc;
end; $$;

-- RPC 6: upcoming sessions next 90 days
create or replace function r3081_upcoming_sessions()
returns table(advisor_name text, advisor_firm text, advisor_expertise text, scheduled_at timestamptz, days_until int, meeting_format text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.advisor_name,
    h.advisor_firm,
    h.advisor_expertise,
    h.scheduled_at,
    (h.scheduled_at::date - current_date)::int as days_until,
    h.meeting_format
  from board_advisor_office_hours_r3081 h
  where h.scheduled_at >= now()
    and h.scheduled_at < now() + interval '90 days'
  order by h.scheduled_at asc;
end; $$;

-- RPC 7: founder impact by owner
create or replace function r3081_impact_by_owner()
returns table(action_owner text, total_items int, done_items int, open_items int, total_impact_rupees bigint, realized_impact_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.action_owner,
    count(*)::int as total_items,
    (count(*) filter (where a.status='done'))::int as done_items,
    (count(*) filter (where a.status in ('open','in_progress','blocked')))::int as open_items,
    coalesce(sum(a.impact_estimate_rupees), 0)::bigint as total_impact_rupees,
    coalesce(sum(a.impact_estimate_rupees) filter (where a.status='done'), 0)::bigint as realized_impact_rupees
  from board_advisor_action_items_r3081 a
  group by a.action_owner
  order by total_impact_rupees desc;
end; $$;

revoke all on function r3081_quarterly_attendance_summary() from public, anon;
revoke all on function r3081_top_rated_advisors() from public, anon;
revoke all on function r3081_action_pipeline_by_status() from public, anon;
revoke all on function r3081_overdue_action_items() from public, anon;
revoke all on function r3081_expertise_coverage() from public, anon;
revoke all on function r3081_upcoming_sessions() from public, anon;
revoke all on function r3081_impact_by_owner() from public, anon;

grant execute on function r3081_quarterly_attendance_summary() to authenticated;
grant execute on function r3081_top_rated_advisors() to authenticated;
grant execute on function r3081_action_pipeline_by_status() to authenticated;
grant execute on function r3081_overdue_action_items() to authenticated;
grant execute on function r3081_expertise_coverage() to authenticated;
grant execute on function r3081_upcoming_sessions() to authenticated;
grant execute on function r3081_impact_by_owner() to authenticated;
