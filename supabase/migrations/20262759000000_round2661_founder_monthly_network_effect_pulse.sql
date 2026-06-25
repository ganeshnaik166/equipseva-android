-- r2661 founder monthly network effect pulse
-- Tracks founder network effect month over month with recovery actions

create table if not exists public.founder_network_effect_r2661 (
  id uuid primary key default gen_random_uuid(),
  month_label text not null,
  intros_made_count int not null default 0,
  intros_received_count int not null default 0,
  peer_advice_sessions int not null default 0,
  network_score int not null default 0 check (network_score between 0 and 100),
  top_strength_md text,
  top_weakness_md text,
  owner_email text,
  status text not null default 'monitoring' check (status in ('monitoring','growing','stagnant','declining')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.network_recovery_actions_r2661 (
  id uuid primary key default gen_random_uuid(),
  pulse_id uuid not null references public.founder_network_effect_r2661(id) on delete cascade,
  action_at timestamptz not null default now(),
  action_kind text not null check (action_kind in ('reach_out','event_attend','give_first','peer_mentor','cofounder_intro')),
  outcome text not null default 'pending' check (outcome in ('positive','neutral','negative','pending')),
  owner_email text,
  status text not null default 'open' check (status in ('open','done','dropped')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_network_effect_r2661 enable row level security;
alter table public.network_recovery_actions_r2661 enable row level security;

drop policy if exists founder_all on public.founder_network_effect_r2661;
create policy founder_all on public.founder_network_effect_r2661
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

drop policy if exists founder_all on public.network_recovery_actions_r2661;
create policy founder_all on public.network_recovery_actions_r2661
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- RPCs

create or replace function public.list_network_r2661()
returns table (
  id uuid,
  month_label text,
  intros_made_count int,
  intros_received_count int,
  peer_advice_sessions int,
  network_score int,
  top_strength_md text,
  top_weakness_md text,
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
    select n.id, n.month_label, n.intros_made_count, n.intros_received_count,
           n.peer_advice_sessions, n.network_score, n.top_strength_md, n.top_weakness_md,
           n.owner_email, n.status, n.notes, n.created_at
    from public.founder_network_effect_r2661 n
    order by n.created_at desc;
end;
$$;
revoke execute on function public.list_network_r2661() from public, anon;
grant execute on function public.list_network_r2661() to authenticated;

create or replace function public.list_recovery_actions_r2661()
returns table (
  id uuid,
  pulse_id uuid,
  month_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
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
    select a.id, a.pulse_id, n.month_label, a.action_at, a.action_kind, a.outcome,
           a.owner_email, a.status, a.notes, a.created_at
    from public.network_recovery_actions_r2661 a
    join public.founder_network_effect_r2661 n on n.id = a.pulse_id
    order by a.action_at desc;
end;
$$;
revoke execute on function public.list_recovery_actions_r2661() from public, anon;
grant execute on function public.list_recovery_actions_r2661() to authenticated;

create or replace function public.top_weakness_focus_r2661()
returns table (
  weakness text,
  pulse_count bigint,
  avg_score numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(n.top_weakness_md, 'unspecified') as weakness,
           count(*)::bigint as pulse_count,
           round(avg(n.network_score)::numeric, 1) as avg_score
    from public.founder_network_effect_r2661 n
    group by coalesce(n.top_weakness_md, 'unspecified')
    order by pulse_count desc;
end;
$$;
revoke execute on function public.top_weakness_focus_r2661() from public, anon;
grant execute on function public.top_weakness_focus_r2661() to authenticated;

create or replace function public.monthly_network_trend_r2661()
returns table (
  month_label text,
  network_score int,
  intros_made_count int,
  intros_received_count int,
  peer_advice_sessions int
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select n.month_label, n.network_score, n.intros_made_count,
           n.intros_received_count, n.peer_advice_sessions
    from public.founder_network_effect_r2661 n
    order by n.created_at asc;
end;
$$;
revoke execute on function public.monthly_network_trend_r2661() from public, anon;
grant execute on function public.monthly_network_trend_r2661() to authenticated;

create or replace function public.status_funnel_r2661()
returns table (
  status text,
  pulse_count bigint,
  avg_score numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select n.status, count(*)::bigint as pulse_count,
           round(avg(n.network_score)::numeric, 1) as avg_score
    from public.founder_network_effect_r2661 n
    group by n.status
    order by pulse_count desc;
end;
$$;
revoke execute on function public.status_funnel_r2661() from public, anon;
grant execute on function public.status_funnel_r2661() to authenticated;

create or replace function public.action_kind_distribution_r2661()
returns table (
  action_kind text,
  action_count bigint,
  positive_count bigint,
  pending_count bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.action_kind,
           count(*)::bigint as action_count,
           count(*) filter (where a.outcome = 'positive')::bigint as positive_count,
           count(*) filter (where a.outcome = 'pending')::bigint as pending_count
    from public.network_recovery_actions_r2661 a
    group by a.action_kind
    order by action_count desc;
end;
$$;
revoke execute on function public.action_kind_distribution_r2661() from public, anon;
grant execute on function public.action_kind_distribution_r2661() to authenticated;

create or replace function public.founder_pulse_summary_r2661()
returns table (
  total_pulses bigint,
  avg_network_score numeric,
  total_intros_made bigint,
  total_intros_received bigint,
  total_peer_sessions bigint,
  growing_count bigint,
  declining_count bigint,
  open_actions bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      (select count(*)::bigint from public.founder_network_effect_r2661),
      (select round(avg(network_score)::numeric, 1) from public.founder_network_effect_r2661),
      (select coalesce(sum(intros_made_count),0)::bigint from public.founder_network_effect_r2661),
      (select coalesce(sum(intros_received_count),0)::bigint from public.founder_network_effect_r2661),
      (select coalesce(sum(peer_advice_sessions),0)::bigint from public.founder_network_effect_r2661),
      (select count(*)::bigint from public.founder_network_effect_r2661 where status = 'growing'),
      (select count(*)::bigint from public.founder_network_effect_r2661 where status = 'declining'),
      (select count(*)::bigint from public.network_recovery_actions_r2661 where status = 'open');
end;
$$;
revoke execute on function public.founder_pulse_summary_r2661() from public, anon;
grant execute on function public.founder_pulse_summary_r2661() to authenticated;

-- Seeds
insert into public.founder_network_effect_r2661 (month_label, intros_made_count, intros_received_count, peer_advice_sessions, network_score, top_strength_md, top_weakness_md, owner_email, status, notes) values
  ('2026-02', 4, 2, 1, 38, 'Active in hospital admin circles', 'Weak ties with investors', 'founder@equipseva.in', 'monitoring', 'baseline month'),
  ('2026-03', 7, 5, 3, 52, 'Strong peer engineer network', 'Limited supplier introductions', 'founder@equipseva.in', 'growing', 'first growth month'),
  ('2026-04', 6, 4, 2, 49, 'Hospital chain warm intros', 'Investor outreach stagnant', 'founder@equipseva.in', 'stagnant', 'plateau detected'),
  ('2026-05', 9, 8, 4, 64, 'Cross-vertical referrals', 'Manufacturer relationships thin', 'founder@equipseva.in', 'growing', 'compound month'),
  ('2026-06', 5, 3, 1, 41, 'Engineer trust deep', 'Drop in proactive outreach', 'founder@equipseva.in', 'declining', 'attention needed');

with months as (
  select id, month_label from public.founder_network_effect_r2661
)
insert into public.network_recovery_actions_r2661 (pulse_id, action_at, action_kind, outcome, owner_email, status, notes)
select id, '2026-03-10 10:00:00'::timestamptz, 'reach_out', 'positive', 'founder@equipseva.in', 'done', 'pinged 12 hospital admins' from months where month_label = '2026-03'
union all
select id, '2026-04-15 14:00:00'::timestamptz, 'event_attend', 'neutral', 'founder@equipseva.in', 'done', 'attended Bangalore healthtech meetup' from months where month_label = '2026-04'
union all
select id, '2026-05-08 09:00:00'::timestamptz, 'give_first', 'positive', 'founder@equipseva.in', 'done', 'shared CDSCO template with two founders' from months where month_label = '2026-05'
union all
select id, '2026-06-12 16:00:00'::timestamptz, 'peer_mentor', 'pending', 'founder@equipseva.in', 'open', 'scheduled mentor call with biomed engineer' from months where month_label = '2026-06'
union all
select id, '2026-06-18 11:00:00'::timestamptz, 'cofounder_intro', 'pending', 'founder@equipseva.in', 'open', 'warm intro to potential CTO via mutual' from months where month_label = '2026-06';
