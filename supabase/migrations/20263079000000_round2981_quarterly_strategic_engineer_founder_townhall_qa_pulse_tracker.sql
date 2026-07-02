-- Round r2981 — Founder Quarterly Strategic Engineer-Founder Townhall Q&A Pulse Tracker

create table if not exists townhall_sessions_r2981 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quarter text not null check (quarter in ('q1','q2','q3','q4')),
  fiscal_year int not null check (fiscal_year between 2024 and 2030),
  held_on timestamptz not null,
  attendee_count int not null check (attendee_count > 0),
  questions_submitted int not null check (questions_submitted >= 0),
  questions_answered int not null check (questions_answered >= 0),
  avg_satisfaction numeric(3,2) not null check (avg_satisfaction between 0 and 5),
  nps_score int not null check (nps_score between -100 and 100),
  status text not null check (status in ('scheduled','live','closed','archived'))
);

create table if not exists townhall_questions_r2981 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  session_id uuid not null references townhall_sessions_r2981(id) on delete cascade,
  engineer_name text not null,
  category text not null check (category in ('strategy','product','pay','tools','culture','growth','ops')),
  question text not null,
  upvotes int not null check (upvotes >= 0),
  answered boolean not null default false,
  founder_response text,
  follow_up_required boolean not null default false,
  priority text not null check (priority in ('p0','p1','p2','p3'))
);

alter table townhall_sessions_r2981 enable row level security;
alter table townhall_questions_r2981 enable row level security;

drop policy if exists townhall_sessions_r2981_founder_select on townhall_sessions_r2981;
create policy townhall_sessions_r2981_founder_select on townhall_sessions_r2981
  for select using (is_founder());

drop policy if exists townhall_questions_r2981_founder_select on townhall_questions_r2981;
create policy townhall_questions_r2981_founder_select on townhall_questions_r2981
  for select using (is_founder());

-- Seed sessions (14)
insert into townhall_sessions_r2981 (quarter, fiscal_year, held_on, attendee_count, questions_submitted, questions_answered, avg_satisfaction, nps_score, status) values
('q1', 2025, '2025-03-15'::timestamptz, 42, 38, 28, 4.20, 45, 'archived'),
('q2', 2025, '2025-06-14'::timestamptz, 48, 52, 41, 4.35, 52, 'archived'),
('q3', 2025, '2025-09-13'::timestamptz, 55, 61, 48, 4.10, 38, 'archived'),
('q4', 2025, '2025-12-12'::timestamptz, 61, 72, 58, 4.45, 58, 'archived'),
('q1', 2026, '2026-03-14'::timestamptz, 68, 84, 65, 4.50, 62, 'closed'),
('q2', 2026, '2026-06-13'::timestamptz, 74, 91, 71, 4.55, 65, 'closed'),
('q3', 2026, '2026-09-12'::timestamptz, 80, 98, 0, 0.00, 0, 'scheduled'),
('q4', 2026, '2026-12-11'::timestamptz, 85, 0, 0, 0.00, 0, 'scheduled'),
('q1', 2027, '2027-03-13'::timestamptz, 90, 0, 0, 0.00, 0, 'scheduled'),
('q2', 2024, '2024-06-15'::timestamptz, 22, 18, 16, 3.80, 22, 'archived'),
('q3', 2024, '2024-09-14'::timestamptz, 28, 24, 20, 3.95, 28, 'archived'),
('q4', 2024, '2024-12-13'::timestamptz, 35, 30, 25, 4.05, 35, 'archived'),
('q1', 2024, '2024-03-16'::timestamptz, 18, 14, 12, 3.70, 18, 'archived'),
('q2', 2027, '2027-06-12'::timestamptz, 95, 0, 0, 0.00, 0, 'scheduled');

-- Seed questions (20)
insert into townhall_questions_r2981 (session_id, engineer_name, category, question, upvotes, answered, founder_response, follow_up_required, priority)
select s.id, vals.engineer_name, vals.category, vals.question, vals.upvotes, vals.answered, vals.founder_response, vals.follow_up_required, vals.priority
from (values
  ('q2', 2026, 'Ravi Kumar', 'strategy', 'When do we expand to Sri Lanka?', 45, true, 'Q4 2026 pilot planned', false, 'p1'),
  ('q2', 2026, 'Sneha Patil', 'pay', 'Will payouts shift to weekly?', 38, true, 'Yes from Q3 2026', false, 'p0'),
  ('q2', 2026, 'Arjun Reddy', 'tools', 'Native iOS app timeline?', 32, true, 'H1 2027', true, 'p1'),
  ('q2', 2026, 'Priya Sharma', 'culture', 'Engineer-of-quarter program?', 28, true, 'Launching Q3', false, 'p2'),
  ('q2', 2026, 'Vikram Singh', 'growth', 'Hospital chain rollout pace?', 41, true, '5 new chains per quarter', false, 'p1'),
  ('q1', 2026, 'Anita Joshi', 'product', 'AMC bulk renewal flow?', 35, true, 'Shipped r1450', false, 'p1'),
  ('q1', 2026, 'Mohan Rao', 'ops', 'Spare part SLA target?', 29, true, '48h aggressive target', true, 'p0'),
  ('q1', 2026, 'Deepa Iyer', 'strategy', 'Series A timeline?', 52, true, 'Q1 2027 close target', false, 'p0'),
  ('q1', 2026, 'Karthik Nair', 'pay', 'TDS clarification', 21, true, '10% standard rate', false, 'p2'),
  ('q4', 2025, 'Sunita Desai', 'culture', 'Annual offsite plans?', 18, true, 'Goa Feb 2026', false, 'p3'),
  ('q4', 2025, 'Rajesh Verma', 'product', 'Triage AI accuracy?', 33, true, '87% and climbing', true, 'p1'),
  ('q4', 2025, 'Lakshmi Pillai', 'tools', 'Better diagnostic SDK?', 26, false, null, true, 'p2'),
  ('q3', 2025, 'Suresh Gupta', 'growth', 'Tier-2 city expansion?', 24, true, 'Pune Q1 2026', false, 'p1'),
  ('q3', 2025, 'Meera Krishnan', 'ops', 'Code-Red protocol?', 31, true, 'Rolled out r600', false, 'p0'),
  ('q2', 2025, 'Hari Prasad', 'strategy', 'Competition response?', 19, true, 'Owning AMC depth', false, 'p1'),
  ('q2', 2026, 'Geeta Menon', 'pay', 'Bonus structure?', 22, true, 'Quarterly perf bonus', false, 'p2'),
  ('q1', 2026, 'Naveen Kumar', 'culture', 'Remote work policy?', 15, true, 'Field + WFH hybrid', false, 'p3'),
  ('q4', 2025, 'Pooja Agarwal', 'ops', 'Parts return process?', 27, true, 'Streamlined via app', true, 'p1'),
  ('q2', 2026, 'Rohit Bansal', 'growth', 'Referral bounty raise?', 36, false, null, true, 'p1'),
  ('q1', 2026, 'Asha Kapoor', 'product', 'Hindi UI completion?', 30, true, 'Shipped r510', false, 'p2')
) as vals(quarter, fiscal_year, engineer_name, category, question, upvotes, answered, founder_response, follow_up_required, priority)
join townhall_sessions_r2981 s on s.quarter = vals.quarter and s.fiscal_year = vals.fiscal_year;

-- RPC 1: sessions overview
create or replace function townhall_r2981_sessions_overview()
returns table(id uuid, quarter text, fiscal_year int, held_on timestamptz, attendee_count int, questions_submitted int, questions_answered int, avg_satisfaction numeric, nps_score int, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.id, s.quarter, s.fiscal_year, s.held_on, s.attendee_count, s.questions_submitted, s.questions_answered, s.avg_satisfaction, s.nps_score, s.status
    from townhall_sessions_r2981 s order by s.held_on desc;
end $$;

-- RPC 2: category breakdown
create or replace function townhall_r2981_category_breakdown()
returns table(category text, total_questions int, total_upvotes int, answered_count int, avg_upvotes numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.category, count(*)::int, coalesce(sum(q.upvotes),0)::int,
    (count(*) filter (where q.answered))::int, round(avg(q.upvotes)::numeric,2)
    from townhall_questions_r2981 q group by q.category order by count(*) desc;
end $$;

-- RPC 3: top upvoted questions
create or replace function townhall_r2981_top_upvoted()
returns table(id uuid, engineer_name text, category text, question text, upvotes int, answered boolean, priority text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.id, q.engineer_name, q.category, q.question, q.upvotes, q.answered, q.priority
    from townhall_questions_r2981 q order by q.upvotes desc limit 12;
end $$;

-- RPC 4: unanswered queue
create or replace function townhall_r2981_unanswered_queue()
returns table(id uuid, engineer_name text, category text, question text, upvotes int, priority text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.id, q.engineer_name, q.category, q.question, q.upvotes, q.priority
    from townhall_questions_r2981 q where q.answered = false order by q.upvotes desc;
end $$;

-- RPC 5: follow-up required
create or replace function townhall_r2981_follow_ups()
returns table(id uuid, engineer_name text, category text, question text, founder_response text, priority text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.id, q.engineer_name, q.category, q.question, q.founder_response, q.priority
    from townhall_questions_r2981 q where q.follow_up_required = true order by q.priority;
end $$;

-- RPC 6: nps trend
create or replace function townhall_r2981_nps_trend()
returns table(quarter text, fiscal_year int, attendee_count int, avg_satisfaction numeric, nps_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select s.quarter, s.fiscal_year, s.attendee_count, s.avg_satisfaction, s.nps_score
    from townhall_sessions_r2981 s where s.status in ('closed','archived') order by s.fiscal_year, s.quarter;
end $$;

-- RPC 7: priority distribution
create or replace function townhall_r2981_priority_dist()
returns table(priority text, total int, answered int, pct_answered numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.priority, count(*)::int,
    (count(*) filter (where q.answered))::int,
    round((100.0 * (count(*) filter (where q.answered)) / nullif(count(*),0))::numeric, 1)
    from townhall_questions_r2981 q group by q.priority order by q.priority;
end $$;

-- RPC 8: engineer participation
create or replace function townhall_r2981_engineer_participation()
returns table(engineer_name text, questions_asked int, total_upvotes int, answered_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select q.engineer_name, count(*)::int, sum(q.upvotes)::int,
    (count(*) filter (where q.answered))::int
    from townhall_questions_r2981 q group by q.engineer_name order by count(*) desc, sum(q.upvotes) desc;
end $$;

revoke all on townhall_sessions_r2981 from public, anon;
revoke all on townhall_questions_r2981 from public, anon;
grant select on townhall_sessions_r2981 to authenticated;
grant select on townhall_questions_r2981 to authenticated;

revoke all on function townhall_r2981_sessions_overview() from public, anon;
revoke all on function townhall_r2981_category_breakdown() from public, anon;
revoke all on function townhall_r2981_top_upvoted() from public, anon;
revoke all on function townhall_r2981_unanswered_queue() from public, anon;
revoke all on function townhall_r2981_follow_ups() from public, anon;
revoke all on function townhall_r2981_nps_trend() from public, anon;
revoke all on function townhall_r2981_priority_dist() from public, anon;
revoke all on function townhall_r2981_engineer_participation() from public, anon;

grant execute on function townhall_r2981_sessions_overview() to authenticated;
grant execute on function townhall_r2981_category_breakdown() to authenticated;
grant execute on function townhall_r2981_top_upvoted() to authenticated;
grant execute on function townhall_r2981_unanswered_queue() to authenticated;
grant execute on function townhall_r2981_follow_ups() to authenticated;
grant execute on function townhall_r2981_nps_trend() to authenticated;
grant execute on function townhall_r2981_priority_dist() to authenticated;
grant execute on function townhall_r2981_engineer_participation() to authenticated;
