-- Round 2636 — Customer quarterly revenue quality grade tracker
-- Tables: customer_revenue_quality_r2636 + revenue_quality_improvement_actions_r2636
-- 7 RPCs gated by public.is_founder()

create table if not exists public.customer_revenue_quality_r2636 (
  id uuid primary key default gen_random_uuid(),
  hospital_user_id uuid not null references public.profiles(id) on delete cascade,
  quarter_label text not null,
  revenue_rupees bigint not null default 0,
  recurring_pct numeric(5,2) not null default 0,
  paid_on_time_pct numeric(5,2) not null default 0,
  churn_risk_pct numeric(5,2) not null default 0,
  quality_grade text not null check (quality_grade in ('A','B','C','D','F')),
  owner_email text,
  status text not null default 'monitoring' check (status in ('monitoring','improving','declining','stable')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_revenue_quality_r2636_hospital on public.customer_revenue_quality_r2636(hospital_user_id);
create index if not exists idx_revenue_quality_r2636_grade on public.customer_revenue_quality_r2636(quality_grade);
create index if not exists idx_revenue_quality_r2636_status on public.customer_revenue_quality_r2636(status);

alter table public.customer_revenue_quality_r2636 enable row level security;
drop policy if exists founder_all on public.customer_revenue_quality_r2636;
create policy founder_all on public.customer_revenue_quality_r2636
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

create table if not exists public.revenue_quality_improvement_actions_r2636 (
  id uuid primary key default gen_random_uuid(),
  quality_id uuid not null references public.customer_revenue_quality_r2636(id) on delete cascade,
  action_at timestamptz not null default now(),
  action_kind text not null check (action_kind in ('billing_terms','contract_lock','early_pay_discount','penalty_clause','exit_clause')),
  outcome text not null default 'pending' check (outcome in ('positive','neutral','negative','pending')),
  owner_email text,
  status text not null default 'open' check (status in ('open','done','dropped')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_quality_actions_r2636_quality on public.revenue_quality_improvement_actions_r2636(quality_id);
create index if not exists idx_quality_actions_r2636_status on public.revenue_quality_improvement_actions_r2636(status);

alter table public.revenue_quality_improvement_actions_r2636 enable row level security;
drop policy if exists founder_all on public.revenue_quality_improvement_actions_r2636;
create policy founder_all on public.revenue_quality_improvement_actions_r2636
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- Seeds
insert into public.customer_revenue_quality_r2636
  (hospital_user_id, quarter_label, revenue_rupees, recurring_pct, paid_on_time_pct, churn_risk_pct, quality_grade, owner_email, status, notes)
select id, 'Q1-2026', 1850000, 92.50, 96.00, 8.00, 'A', 'cfo@equipseva.in', 'stable', 'Top-tier multi-year AMC anchor'
  from public.profiles where role = 'hospital_admin' limit 1
on conflict do nothing;

insert into public.customer_revenue_quality_r2636
  (hospital_user_id, quarter_label, revenue_rupees, recurring_pct, paid_on_time_pct, churn_risk_pct, quality_grade, owner_email, status, notes)
select id, 'Q1-2026', 920000, 65.00, 78.00, 28.00, 'C', 'ops@equipseva.in', 'declining', 'Late on 2 invoices; renegotiate terms'
  from public.profiles where role = 'hospital_admin' offset 1 limit 1
on conflict do nothing;

insert into public.customer_revenue_quality_r2636
  (hospital_user_id, quarter_label, revenue_rupees, recurring_pct, paid_on_time_pct, churn_risk_pct, quality_grade, owner_email, status, notes)
select id, 'Q1-2026', 540000, 40.00, 60.00, 55.00, 'D', 'ops@equipseva.in', 'declining', 'High churn risk; needs contract lock'
  from public.profiles where role = 'hospital_admin' offset 2 limit 1
on conflict do nothing;

insert into public.customer_revenue_quality_r2636
  (hospital_user_id, quarter_label, revenue_rupees, recurring_pct, paid_on_time_pct, churn_risk_pct, quality_grade, owner_email, status, notes)
select id, 'Q4-2025', 1450000, 85.00, 90.00, 12.00, 'B', 'cfo@equipseva.in', 'improving', 'Recurring trending up'
  from public.profiles where role = 'hospital_admin' limit 1
on conflict do nothing;

insert into public.revenue_quality_improvement_actions_r2636
  (quality_id, action_kind, outcome, owner_email, status, notes)
select id, 'contract_lock', 'positive', 'cfo@equipseva.in', 'done', 'Locked 24-month renewal'
  from public.customer_revenue_quality_r2636 where quality_grade = 'A' limit 1
on conflict do nothing;

insert into public.revenue_quality_improvement_actions_r2636
  (quality_id, action_kind, outcome, owner_email, status, notes)
select id, 'early_pay_discount', 'pending', 'ops@equipseva.in', 'open', 'Offered 2 pct discount for NET-15'
  from public.customer_revenue_quality_r2636 where quality_grade = 'C' limit 1
on conflict do nothing;

insert into public.revenue_quality_improvement_actions_r2636
  (quality_id, action_kind, outcome, owner_email, status, notes)
select id, 'penalty_clause', 'neutral', 'ops@equipseva.in', 'open', 'Added late-pay penalty to next renewal'
  from public.customer_revenue_quality_r2636 where quality_grade = 'D' limit 1
on conflict do nothing;

-- RPCs

drop function if exists public.list_quality_r2636();
create or replace function public.list_quality_r2636()
returns setof public.customer_revenue_quality_r2636
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select * from public.customer_revenue_quality_r2636
    order by created_at desc;
end;
$$;
revoke execute on function public.list_quality_r2636() from public, anon;
grant execute on function public.list_quality_r2636() to authenticated;

drop function if exists public.list_improvement_actions_r2636();
create or replace function public.list_improvement_actions_r2636()
returns setof public.revenue_quality_improvement_actions_r2636
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select * from public.revenue_quality_improvement_actions_r2636
    order by action_at desc;
end;
$$;
revoke execute on function public.list_improvement_actions_r2636() from public, anon;
grant execute on function public.list_improvement_actions_r2636() to authenticated;

drop function if exists public.top_at_risk_focus_r2636();
create or replace function public.top_at_risk_focus_r2636()
returns table(
  id uuid,
  hospital_user_id uuid,
  quarter_label text,
  revenue_rupees bigint,
  churn_risk_pct numeric,
  quality_grade text,
  status text,
  owner_email text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.id, q.hospital_user_id, q.quarter_label, q.revenue_rupees,
           q.churn_risk_pct, q.quality_grade, q.status, q.owner_email
    from public.customer_revenue_quality_r2636 q
    where q.quality_grade in ('C','D','F')
    order by q.churn_risk_pct desc, q.revenue_rupees desc
    limit 25;
end;
$$;
revoke execute on function public.top_at_risk_focus_r2636() from public, anon;
grant execute on function public.top_at_risk_focus_r2636() to authenticated;

drop function if exists public.grade_distribution_r2636();
create or replace function public.grade_distribution_r2636()
returns table(quality_grade text, cohort_count bigint, total_revenue_rupees bigint, avg_churn_risk_pct numeric)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.quality_grade,
           count(*)::bigint as cohort_count,
           coalesce(sum(q.revenue_rupees),0)::bigint as total_revenue_rupees,
           coalesce(avg(q.churn_risk_pct),0)::numeric(5,2) as avg_churn_risk_pct
    from public.customer_revenue_quality_r2636 q
    group by q.quality_grade
    order by q.quality_grade asc;
end;
$$;
revoke execute on function public.grade_distribution_r2636() from public, anon;
grant execute on function public.grade_distribution_r2636() to authenticated;

drop function if exists public.status_funnel_r2636();
create or replace function public.status_funnel_r2636()
returns table(status text, cohort_count bigint, total_revenue_rupees bigint)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.status,
           count(*)::bigint as cohort_count,
           coalesce(sum(q.revenue_rupees),0)::bigint as total_revenue_rupees
    from public.customer_revenue_quality_r2636 q
    group by q.status
    order by q.status asc;
end;
$$;
revoke execute on function public.status_funnel_r2636() from public, anon;
grant execute on function public.status_funnel_r2636() to authenticated;

drop function if exists public.quarterly_quality_trend_r2636();
create or replace function public.quarterly_quality_trend_r2636()
returns table(
  quarter_label text,
  cohort_count bigint,
  total_revenue_rupees bigint,
  avg_recurring_pct numeric,
  avg_paid_on_time_pct numeric,
  avg_churn_risk_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select q.quarter_label,
           count(*)::bigint as cohort_count,
           coalesce(sum(q.revenue_rupees),0)::bigint as total_revenue_rupees,
           coalesce(avg(q.recurring_pct),0)::numeric(5,2) as avg_recurring_pct,
           coalesce(avg(q.paid_on_time_pct),0)::numeric(5,2) as avg_paid_on_time_pct,
           coalesce(avg(q.churn_risk_pct),0)::numeric(5,2) as avg_churn_risk_pct
    from public.customer_revenue_quality_r2636 q
    group by q.quarter_label
    order by q.quarter_label desc;
end;
$$;
revoke execute on function public.quarterly_quality_trend_r2636() from public, anon;
grant execute on function public.quarterly_quality_trend_r2636() to authenticated;

drop function if exists public.total_revenue_summary_r2636();
create or replace function public.total_revenue_summary_r2636()
returns table(
  total_cohorts bigint,
  total_revenue_rupees bigint,
  high_grade_revenue_rupees bigint,
  at_risk_revenue_rupees bigint,
  avg_churn_risk_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select count(*)::bigint as total_cohorts,
           coalesce(sum(q.revenue_rupees),0)::bigint as total_revenue_rupees,
           coalesce(sum(q.revenue_rupees) filter (where q.quality_grade in ('A','B')),0)::bigint as high_grade_revenue_rupees,
           coalesce(sum(q.revenue_rupees) filter (where q.quality_grade in ('C','D','F')),0)::bigint as at_risk_revenue_rupees,
           coalesce(avg(q.churn_risk_pct),0)::numeric(5,2) as avg_churn_risk_pct
    from public.customer_revenue_quality_r2636 q;
end;
$$;
revoke execute on function public.total_revenue_summary_r2636() from public, anon;
grant execute on function public.total_revenue_summary_r2636() to authenticated;
