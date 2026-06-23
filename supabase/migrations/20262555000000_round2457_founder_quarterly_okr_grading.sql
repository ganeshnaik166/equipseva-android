-- Round 2457: founder quarterly OKR grading
-- Quarter × OKR × target × actual × grade × lessons × next quarter carryover.

create table if not exists public.founder_quarterly_okrs_r2457 (
  id uuid primary key default gen_random_uuid(),
  quarter_label text not null,
  okr_name text not null,
  kr_text text not null,
  target_value numeric not null,
  target_unit text not null,
  actual_value numeric not null,
  grade text not null check (grade in ('A','B','C','D','F')),
  status text not null check (status in ('on_track','at_risk','missed','exceeded')),
  lessons_md text not null,
  carryover boolean not null default false,
  owner_email text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.okr_grading_session_log_r2457 (
  id uuid primary key default gen_random_uuid(),
  quarter_label text not null,
  graded_at timestamptz not null default now(),
  graded_by_email text not null,
  okr_count int not null,
  avg_grade text not null,
  top_win text not null,
  top_miss text not null,
  carryover_count int not null,
  next_quarter_focus_md text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_quarterly_okrs_r2457 enable row level security;
alter table public.okr_grading_session_log_r2457 enable row level security;

drop policy if exists founder_all on public.founder_quarterly_okrs_r2457;
create policy founder_all on public.founder_quarterly_okrs_r2457
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

drop policy if exists founder_all on public.okr_grading_session_log_r2457;
create policy founder_all on public.okr_grading_session_log_r2457
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- Seed
insert into public.founder_quarterly_okrs_r2457
  (quarter_label, okr_name, kr_text, target_value, target_unit, actual_value, grade, status, lessons_md, carryover, owner_email, notes)
values
  ('Q2-2026','GTM','Active paying hospitals',100,'count',118,'A','exceeded','Chain accounts converted faster than mid-market singles.',false,'gtm@equipseva.in','Top win of quarter.'),
  ('Q2-2026','Reliability','Engineer SLA on-time %',95,'percent',91,'C','at_risk','Monsoon logistics ate margin; need standby engineers.',true,'ops@equipseva.in','Carry into Q3.'),
  ('Q2-2026','Revenue','Monthly recurring revenue lakhs',45,'lakh_inr',38,'D','missed','AMC churn higher than modeled. Pricing test inconclusive.',true,'founder@equipseva.in','Top miss.'),
  ('Q2-2026','Compliance','NABH-ready hospitals onboarded',12,'count',12,'B','on_track','Cleared. Process repeatable.',false,'compliance@equipseva.in',null),
  ('Q2-2026','Engineering','Crash-free sessions %',99.5,'percent',99.7,'A','exceeded','R8 + Sentry integration paying off.',false,'eng@equipseva.in',null);

insert into public.okr_grading_session_log_r2457
  (quarter_label, graded_by_email, okr_count, avg_grade, top_win, top_miss, carryover_count, next_quarter_focus_md, notes)
values
  ('Q2-2026','founder@equipseva.in',5,'B','GTM chain accounts','MRR shortfall',2,'Q3 focus: AMC retention + standby engineer pool.','First formal grading session.'),
  ('Q1-2026','founder@equipseva.in',4,'C','Compliance NABH','Hospital activation',1,'Sharpen onboarding funnel.','Carryover became Q2 GTM OKR.');

-- RPCs
create or replace function public.list_okrs_r2457()
returns table (
  id uuid, quarter_label text, okr_name text, kr_text text,
  target_value numeric, target_unit text, actual_value numeric,
  grade text, status text, carryover boolean, owner_email text, created_at timestamptz
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.id, o.quarter_label, o.okr_name, o.kr_text,
           o.target_value, o.target_unit, o.actual_value,
           o.grade, o.status, o.carryover, o.owner_email, o.created_at
      from public.founder_quarterly_okrs_r2457 o
     order by o.quarter_label desc, o.grade asc, o.created_at desc;
end;
$$;
revoke execute on function public.list_okrs_r2457() from public, anon;
grant execute on function public.list_okrs_r2457() to authenticated;

create or replace function public.list_grading_sessions_r2457()
returns table (
  id uuid, quarter_label text, graded_at timestamptz, graded_by_email text,
  okr_count int, avg_grade text, top_win text, top_miss text,
  carryover_count int, next_quarter_focus_md text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.id, s.quarter_label, s.graded_at, s.graded_by_email,
           s.okr_count, s.avg_grade, s.top_win, s.top_miss,
           s.carryover_count, s.next_quarter_focus_md
      from public.okr_grading_session_log_r2457 s
     order by s.graded_at desc;
end;
$$;
revoke execute on function public.list_grading_sessions_r2457() from public, anon;
grant execute on function public.list_grading_sessions_r2457() to authenticated;

create or replace function public.status_breakdown_r2457()
returns table (status text, okr_count bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.status, count(*)::bigint
      from public.founder_quarterly_okrs_r2457 o
     group by o.status
     order by 2 desc;
end;
$$;
revoke execute on function public.status_breakdown_r2457() from public, anon;
grant execute on function public.status_breakdown_r2457() to authenticated;

create or replace function public.grade_distribution_r2457()
returns table (grade text, okr_count bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.grade, count(*)::bigint
      from public.founder_quarterly_okrs_r2457 o
     group by o.grade
     order by o.grade asc;
end;
$$;
revoke execute on function public.grade_distribution_r2457() from public, anon;
grant execute on function public.grade_distribution_r2457() to authenticated;

create or replace function public.carryover_summary_r2457()
returns table (quarter_label text, carryover_count bigint, total_okrs bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.quarter_label,
           sum(case when o.carryover then 1 else 0 end)::bigint,
           count(*)::bigint
      from public.founder_quarterly_okrs_r2457 o
     group by o.quarter_label
     order by o.quarter_label desc;
end;
$$;
revoke execute on function public.carryover_summary_r2457() from public, anon;
grant execute on function public.carryover_summary_r2457() to authenticated;

create or replace function public.top_misses_r2457()
returns table (quarter_label text, okr_name text, kr_text text, target_value numeric, actual_value numeric, grade text, owner_email text)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.quarter_label, o.okr_name, o.kr_text, o.target_value, o.actual_value, o.grade, o.owner_email
      from public.founder_quarterly_okrs_r2457 o
     where o.status in ('missed','at_risk')
     order by o.grade desc, o.quarter_label desc
     limit 25;
end;
$$;
revoke execute on function public.top_misses_r2457() from public, anon;
grant execute on function public.top_misses_r2457() to authenticated;

create or replace function public.quarterly_trend_r2457()
returns table (quarter_label text, avg_grade text, okr_count bigint, carryover_count bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.quarter_label, s.avg_grade, s.okr_count::bigint, s.carryover_count::bigint
      from public.okr_grading_session_log_r2457 s
     order by s.quarter_label desc;
end;
$$;
revoke execute on function public.quarterly_trend_r2457() from public, anon;
grant execute on function public.quarterly_trend_r2457() to authenticated;
