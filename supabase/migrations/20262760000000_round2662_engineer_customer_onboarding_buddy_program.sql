-- r2662 engineer customer onboarding buddy program
-- Pairs new engineers with veteran buddies and tracks ramp outcomes

create table if not exists public.engineer_onboarding_buddies_r2662 (
  id uuid primary key default gen_random_uuid(),
  new_engineer_user_id uuid references public.engineers(id) on delete set null,
  buddy_engineer_user_id uuid references public.engineers(id) on delete set null,
  hospital_user_id uuid references public.profiles(id) on delete set null,
  paired_at timestamptz not null default now(),
  days_paired int not null default 0,
  knowledge_transfer_kind text not null check (knowledge_transfer_kind in ('equipment_specific','customer_skills','escalation_process','all')),
  retention_signal text not null default 'neutral' check (retention_signal in ('positive','neutral','negative')),
  owner_email text,
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.buddy_program_outcomes_r2662 (
  id uuid primary key default gen_random_uuid(),
  pairing_id uuid not null references public.engineer_onboarding_buddies_r2662(id) on delete cascade,
  observed_at timestamptz not null default now(),
  outcome_kind text not null check (outcome_kind in ('faster_ramp','strong_relationship','buddy_friction','no_change')),
  revenue_impact_rupees bigint not null default 0,
  owner_email text,
  status text not null default 'open' check (status in ('open','done','dropped')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_onboarding_buddies_r2662 enable row level security;
alter table public.buddy_program_outcomes_r2662 enable row level security;

drop policy if exists founder_all on public.engineer_onboarding_buddies_r2662;
create policy founder_all on public.engineer_onboarding_buddies_r2662
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

drop policy if exists founder_all on public.buddy_program_outcomes_r2662;
create policy founder_all on public.buddy_program_outcomes_r2662
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- RPCs

create or replace function public.list_buddies_r2662()
returns table (
  id uuid,
  new_engineer_user_id uuid,
  buddy_engineer_user_id uuid,
  hospital_user_id uuid,
  paired_at timestamptz,
  days_paired int,
  knowledge_transfer_kind text,
  retention_signal text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.id, b.new_engineer_user_id, b.buddy_engineer_user_id, b.hospital_user_id,
           b.paired_at, b.days_paired, b.knowledge_transfer_kind, b.retention_signal,
           b.owner_email, b.status, b.notes, b.created_at
    from public.engineer_onboarding_buddies_r2662 b
    order by b.paired_at desc;
end;
$$;
revoke execute on function public.list_buddies_r2662() from public, anon;
grant execute on function public.list_buddies_r2662() to authenticated;

create or replace function public.list_outcomes_r2662()
returns table (
  id uuid,
  pairing_id uuid,
  observed_at timestamptz,
  outcome_kind text,
  revenue_impact_rupees bigint,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.id, o.pairing_id, o.observed_at, o.outcome_kind, o.revenue_impact_rupees,
           o.owner_email, o.status, o.notes, o.created_at
    from public.buddy_program_outcomes_r2662 o
    order by o.observed_at desc;
end;
$$;
revoke execute on function public.list_outcomes_r2662() from public, anon;
grant execute on function public.list_outcomes_r2662() to authenticated;

create or replace function public.top_pairing_focus_r2662()
returns table (
  pairing_id uuid,
  knowledge_transfer_kind text,
  retention_signal text,
  status text,
  days_paired int,
  outcome_count bigint,
  total_revenue_impact bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.id as pairing_id,
           b.knowledge_transfer_kind,
           b.retention_signal,
           b.status,
           b.days_paired,
           count(o.id) as outcome_count,
           coalesce(sum(o.revenue_impact_rupees), 0) as total_revenue_impact
    from public.engineer_onboarding_buddies_r2662 b
    left join public.buddy_program_outcomes_r2662 o on o.pairing_id = b.id
    group by b.id, b.knowledge_transfer_kind, b.retention_signal, b.status, b.days_paired
    order by total_revenue_impact desc, outcome_count desc
    limit 25;
end;
$$;
revoke execute on function public.top_pairing_focus_r2662() from public, anon;
grant execute on function public.top_pairing_focus_r2662() to authenticated;

create or replace function public.knowledge_kind_distribution_r2662()
returns table (
  knowledge_transfer_kind text,
  pairing_count bigint,
  positive_signal_count bigint,
  negative_signal_count bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.knowledge_transfer_kind,
           count(*) as pairing_count,
           sum(case when b.retention_signal = 'positive' then 1 else 0 end) as positive_signal_count,
           sum(case when b.retention_signal = 'negative' then 1 else 0 end) as negative_signal_count
    from public.engineer_onboarding_buddies_r2662 b
    group by b.knowledge_transfer_kind
    order by pairing_count desc;
end;
$$;
revoke execute on function public.knowledge_kind_distribution_r2662() from public, anon;
grant execute on function public.knowledge_kind_distribution_r2662() to authenticated;

create or replace function public.status_funnel_r2662()
returns table (
  status text,
  pairing_count bigint,
  avg_days_paired numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.status,
           count(*) as pairing_count,
           round(avg(b.days_paired)::numeric, 1) as avg_days_paired
    from public.engineer_onboarding_buddies_r2662 b
    group by b.status
    order by pairing_count desc;
end;
$$;
revoke execute on function public.status_funnel_r2662() from public, anon;
grant execute on function public.status_funnel_r2662() to authenticated;

create or replace function public.monthly_buddy_trend_r2662()
returns table (
  month_start date,
  pairing_count bigint,
  completed_count bigint,
  cancelled_count bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select date_trunc('month', b.paired_at)::date as month_start,
           count(*) as pairing_count,
           sum(case when b.status = 'completed' then 1 else 0 end) as completed_count,
           sum(case when b.status = 'cancelled' then 1 else 0 end) as cancelled_count
    from public.engineer_onboarding_buddies_r2662 b
    group by date_trunc('month', b.paired_at)
    order by month_start desc
    limit 12;
end;
$$;
revoke execute on function public.monthly_buddy_trend_r2662() from public, anon;
grant execute on function public.monthly_buddy_trend_r2662() to authenticated;

create or replace function public.owner_load_r2662()
returns table (
  owner_email text,
  open_pairings bigint,
  open_outcomes bigint,
  total_revenue_impact bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    with b_load as (
      select coalesce(b.owner_email, 'unassigned') as owner_email,
             count(*) filter (where b.status = 'active') as open_pairings
      from public.engineer_onboarding_buddies_r2662 b
      group by coalesce(b.owner_email, 'unassigned')
    ),
    o_load as (
      select coalesce(o.owner_email, 'unassigned') as owner_email,
             count(*) filter (where o.status = 'open') as open_outcomes,
             coalesce(sum(o.revenue_impact_rupees), 0) as total_revenue_impact
      from public.buddy_program_outcomes_r2662 o
      group by coalesce(o.owner_email, 'unassigned')
    )
    select coalesce(b_load.owner_email, o_load.owner_email) as owner_email,
           coalesce(b_load.open_pairings, 0) as open_pairings,
           coalesce(o_load.open_outcomes, 0) as open_outcomes,
           coalesce(o_load.total_revenue_impact, 0) as total_revenue_impact
    from b_load
    full outer join o_load on o_load.owner_email = b_load.owner_email
    order by total_revenue_impact desc, open_pairings desc;
end;
$$;
revoke execute on function public.owner_load_r2662() from public, anon;
grant execute on function public.owner_load_r2662() to authenticated;

-- Seed data (no apostrophes in strings)
insert into public.engineer_onboarding_buddies_r2662 (paired_at, days_paired, knowledge_transfer_kind, retention_signal, owner_email, status, notes)
values
  ('2026-05-12 10:00:00+05:30'::timestamptz, 30, 'equipment_specific', 'positive', 'ops@equipseva.in', 'completed', 'New hire ramped on CT scanner faster than baseline'),
  ('2026-05-25 09:00:00+05:30'::timestamptz, 18, 'customer_skills', 'positive', 'people@equipseva.in', 'active', 'Buddy coached on hospital admin etiquette'),
  ('2026-06-02 11:00:00+05:30'::timestamptz, 12, 'escalation_process', 'neutral', 'ops@equipseva.in', 'active', 'Escalation playbook walkthrough'),
  ('2026-06-10 14:00:00+05:30'::timestamptz, 5, 'all', 'negative', 'people@equipseva.in', 'cancelled', 'Personality mismatch — re-pair next round'),
  ('2026-06-18 08:30:00+05:30'::timestamptz, 2, 'all', 'positive', 'ops@equipseva.in', 'active', 'Strong rapport from day one');

insert into public.buddy_program_outcomes_r2662 (pairing_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
select b.id, b.paired_at + interval '14 days', 'faster_ramp', 45000, 'ops@equipseva.in', 'done', 'Closed first solo repair within 2 weeks'
from public.engineer_onboarding_buddies_r2662 b where b.knowledge_transfer_kind = 'equipment_specific' limit 1;

insert into public.buddy_program_outcomes_r2662 (pairing_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
select b.id, b.paired_at + interval '21 days', 'strong_relationship', 75000, 'people@equipseva.in', 'open', 'Hospital flagged new engineer as preferred contact'
from public.engineer_onboarding_buddies_r2662 b where b.knowledge_transfer_kind = 'customer_skills' limit 1;

insert into public.buddy_program_outcomes_r2662 (pairing_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
select b.id, b.paired_at + interval '7 days', 'buddy_friction', 0, 'people@equipseva.in', 'dropped', 'Friction surfaced — moved to different buddy'
from public.engineer_onboarding_buddies_r2662 b where b.status = 'cancelled' limit 1;

insert into public.buddy_program_outcomes_r2662 (pairing_id, observed_at, outcome_kind, revenue_impact_rupees, owner_email, status, notes)
select b.id, b.paired_at + interval '10 days', 'no_change', 5000, 'ops@equipseva.in', 'open', 'Marginal improvement vs baseline'
from public.engineer_onboarding_buddies_r2662 b where b.knowledge_transfer_kind = 'escalation_process' limit 1;
