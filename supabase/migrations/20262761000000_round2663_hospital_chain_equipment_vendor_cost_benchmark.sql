-- r2663 hospital chain equipment vendor cost benchmark
-- Tracks chain equipment vendor costs vs market median with action plans

create table if not exists public.chain_vendor_cost_benchmark_r2663 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_user_id uuid references public.profiles(id) on delete set null,
  equipment_kind text not null,
  our_cost_rupees bigint not null default 0,
  market_median_rupees bigint not null default 0,
  top_quartile_rupees bigint not null default 0,
  position_kind text not null default 'at_market' check (position_kind in ('below_market','at_market','above_market','premium')),
  owner_email text,
  status text not null default 'monitoring' check (status in ('monitoring','repricing','aligned','dropped')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.cost_benchmark_actions_r2663 (
  id uuid primary key default gen_random_uuid(),
  benchmark_id uuid not null references public.chain_vendor_cost_benchmark_r2663(id) on delete cascade,
  action_at timestamptz not null default now(),
  action_kind text not null check (action_kind in ('reprice','bundle','escalate','walkaway','justify_value')),
  outcome text not null default 'pending' check (outcome in ('positive','neutral','negative','pending')),
  owner_email text,
  status text not null default 'open' check (status in ('open','done','dropped')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.chain_vendor_cost_benchmark_r2663 enable row level security;
alter table public.cost_benchmark_actions_r2663 enable row level security;

drop policy if exists founder_all on public.chain_vendor_cost_benchmark_r2663;
create policy founder_all on public.chain_vendor_cost_benchmark_r2663
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

drop policy if exists founder_all on public.cost_benchmark_actions_r2663;
create policy founder_all on public.cost_benchmark_actions_r2663
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- RPCs

create or replace function public.list_benchmark_r2663()
returns table (
  id uuid,
  chain_name text,
  hospital_user_id uuid,
  equipment_kind text,
  our_cost_rupees bigint,
  market_median_rupees bigint,
  top_quartile_rupees bigint,
  position_kind text,
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
    select b.id, b.chain_name, b.hospital_user_id, b.equipment_kind,
           b.our_cost_rupees, b.market_median_rupees, b.top_quartile_rupees,
           b.position_kind, b.owner_email, b.status, b.notes, b.created_at
    from public.chain_vendor_cost_benchmark_r2663 b
    order by b.created_at desc;
end;
$$;
revoke execute on function public.list_benchmark_r2663() from public, anon;
grant execute on function public.list_benchmark_r2663() to authenticated;

create or replace function public.list_actions_r2663()
returns table (
  id uuid,
  benchmark_id uuid,
  chain_name text,
  equipment_kind text,
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
    select a.id, a.benchmark_id, b.chain_name, b.equipment_kind,
           a.action_at, a.action_kind, a.outcome, a.owner_email, a.status,
           a.notes, a.created_at
    from public.cost_benchmark_actions_r2663 a
    join public.chain_vendor_cost_benchmark_r2663 b on b.id = a.benchmark_id
    order by a.action_at desc;
end;
$$;
revoke execute on function public.list_actions_r2663() from public, anon;
grant execute on function public.list_actions_r2663() to authenticated;

create or replace function public.top_above_market_focus_r2663()
returns table (
  id uuid,
  chain_name text,
  equipment_kind text,
  our_cost_rupees bigint,
  market_median_rupees bigint,
  gap_rupees bigint,
  position_kind text,
  status text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.id, b.chain_name, b.equipment_kind, b.our_cost_rupees,
           b.market_median_rupees,
           (b.our_cost_rupees - b.market_median_rupees) as gap_rupees,
           b.position_kind, b.status
    from public.chain_vendor_cost_benchmark_r2663 b
    where b.position_kind in ('above_market','premium')
      and b.status <> 'dropped'
    order by (b.our_cost_rupees - b.market_median_rupees) desc
    limit 25;
end;
$$;
revoke execute on function public.top_above_market_focus_r2663() from public, anon;
grant execute on function public.top_above_market_focus_r2663() to authenticated;

create or replace function public.position_distribution_r2663()
returns table (
  position_kind text,
  benchmark_count bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.position_kind, count(*)::bigint
    from public.chain_vendor_cost_benchmark_r2663 b
    group by b.position_kind
    order by b.position_kind;
end;
$$;
revoke execute on function public.position_distribution_r2663() from public, anon;
grant execute on function public.position_distribution_r2663() to authenticated;

create or replace function public.status_funnel_r2663()
returns table (
  status text,
  benchmark_count bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.status, count(*)::bigint
    from public.chain_vendor_cost_benchmark_r2663 b
    group by b.status
    order by b.status;
end;
$$;
revoke execute on function public.status_funnel_r2663() from public, anon;
grant execute on function public.status_funnel_r2663() to authenticated;

create or replace function public.monthly_benchmark_trend_r2663()
returns table (
  month_label text,
  benchmark_count bigint,
  avg_gap_rupees bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select to_char(date_trunc('month', b.created_at), 'YYYY-MM') as month_label,
           count(*)::bigint as benchmark_count,
           coalesce(avg(b.our_cost_rupees - b.market_median_rupees), 0)::bigint as avg_gap_rupees
    from public.chain_vendor_cost_benchmark_r2663 b
    group by date_trunc('month', b.created_at)
    order by date_trunc('month', b.created_at) desc;
end;
$$;
revoke execute on function public.monthly_benchmark_trend_r2663() from public, anon;
grant execute on function public.monthly_benchmark_trend_r2663() to authenticated;

create or replace function public.owner_load_r2663()
returns table (
  owner_email text,
  benchmark_count bigint,
  open_action_count bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(b.owner_email, 'unassigned') as owner_email,
           count(distinct b.id)::bigint as benchmark_count,
           count(a.id) filter (where a.status = 'open')::bigint as open_action_count
    from public.chain_vendor_cost_benchmark_r2663 b
    left join public.cost_benchmark_actions_r2663 a on a.benchmark_id = b.id
    group by coalesce(b.owner_email, 'unassigned')
    order by count(distinct b.id) desc;
end;
$$;
revoke execute on function public.owner_load_r2663() from public, anon;
grant execute on function public.owner_load_r2663() to authenticated;

-- Seed data
insert into public.chain_vendor_cost_benchmark_r2663
  (chain_name, equipment_kind, our_cost_rupees, market_median_rupees, top_quartile_rupees, position_kind, owner_email, status, notes)
values
  ('Apollo Group', 'ventilator', 285000, 250000, 230000, 'above_market', 'ops@equipseva.in', 'repricing', 'Above median by 14 percent; renegotiation underway'),
  ('Yashoda Group', 'ultrasound', 145000, 180000, 170000, 'below_market', 'sales@equipseva.in', 'aligned', 'Strong margin pocket; protect via bundle'),
  ('Care Hospitals', 'patient_monitor', 65000, 65000, 60000, 'at_market', 'ops@equipseva.in', 'monitoring', 'Median pricing holds'),
  ('Manipal Group', 'defibrillator', 195000, 160000, 150000, 'premium', 'cs@equipseva.in', 'repricing', 'Premium tier; justify warranty value'),
  ('KIMS Group', 'autoclave', 88000, 95000, 88000, 'below_market', 'ops@equipseva.in', 'aligned', 'Top quartile pricing achieved');

insert into public.cost_benchmark_actions_r2663
  (benchmark_id, action_kind, outcome, owner_email, status, notes)
select b.id, 'reprice', 'pending', 'ops@equipseva.in', 'open', 'Submit revised quote next week'
from public.chain_vendor_cost_benchmark_r2663 b
where b.chain_name = 'Apollo Group' and b.equipment_kind = 'ventilator'
limit 1;

insert into public.cost_benchmark_actions_r2663
  (benchmark_id, action_kind, outcome, owner_email, status, notes)
select b.id, 'justify_value', 'positive', 'cs@equipseva.in', 'done', 'Warranty SLA presentation accepted'
from public.chain_vendor_cost_benchmark_r2663 b
where b.chain_name = 'Manipal Group' and b.equipment_kind = 'defibrillator'
limit 1;

insert into public.cost_benchmark_actions_r2663
  (benchmark_id, action_kind, outcome, owner_email, status, notes)
select b.id, 'bundle', 'pending', 'sales@equipseva.in', 'open', 'Pair ultrasound with AMC tier 2'
from public.chain_vendor_cost_benchmark_r2663 b
where b.chain_name = 'Yashoda Group' and b.equipment_kind = 'ultrasound'
limit 1;
