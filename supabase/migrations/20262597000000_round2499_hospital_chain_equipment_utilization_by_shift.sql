-- Round 2499: hospital-chain-equipment-utilization-by-shift
-- Chain × equipment × shift slot × hours used × revenue × idle hours × upsell

create extension if not exists pgcrypto;

------------------------------------------------------------
-- Table 1: chain_equipment_shift_utilization_r2499
------------------------------------------------------------
create table if not exists public.chain_equipment_shift_utilization_r2499 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_user_id uuid references public.profiles(id) on delete set null,
  equipment_label text not null,
  shift_slot text not null check (shift_slot in ('morning','afternoon','night','weekend')),
  hours_used numeric not null default 0,
  hours_idle numeric not null default 0,
  revenue_rupees bigint not null default 0,
  idle_revenue_loss_rupees bigint not null default 0,
  utilization_pct numeric not null default 0,
  upsell_opportunity_rupees bigint not null default 0,
  observed_period_start date not null,
  observed_period_end date not null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_ceshu_r2499_chain on public.chain_equipment_shift_utilization_r2499(chain_name);
create index if not exists idx_ceshu_r2499_shift on public.chain_equipment_shift_utilization_r2499(shift_slot);
create index if not exists idx_ceshu_r2499_period on public.chain_equipment_shift_utilization_r2499(observed_period_start);

alter table public.chain_equipment_shift_utilization_r2499 enable row level security;
drop policy if exists founder_all on public.chain_equipment_shift_utilization_r2499;
create policy founder_all on public.chain_equipment_shift_utilization_r2499
  for all to authenticated
  using (public.is_founder()) with check (public.is_founder());

------------------------------------------------------------
-- Table 2: equipment_upsell_actions_r2499
------------------------------------------------------------
create table if not exists public.equipment_upsell_actions_r2499 (
  id uuid primary key default gen_random_uuid(),
  utilization_id uuid not null references public.chain_equipment_shift_utilization_r2499(id) on delete cascade,
  action_kind text not null check (action_kind in ('extended_shift','cross_dept','second_shift','maintenance_window','replacement_quote')),
  proposed_at timestamptz not null default now(),
  owner_email text,
  status text not null default 'open' check (status in ('open','in_progress','done','dropped')),
  expected_revenue_rupees bigint not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_eua_r2499_util on public.equipment_upsell_actions_r2499(utilization_id);
create index if not exists idx_eua_r2499_status on public.equipment_upsell_actions_r2499(status);

alter table public.equipment_upsell_actions_r2499 enable row level security;
drop policy if exists founder_all on public.equipment_upsell_actions_r2499;
create policy founder_all on public.equipment_upsell_actions_r2499
  for all to authenticated
  using (public.is_founder()) with check (public.is_founder());

------------------------------------------------------------
-- Seed
------------------------------------------------------------
do $seed$
declare
  v_u1 uuid; v_u2 uuid; v_u3 uuid; v_u4 uuid;
begin
  insert into public.chain_equipment_shift_utilization_r2499
    (chain_name, equipment_label, shift_slot, hours_used, hours_idle, revenue_rupees, idle_revenue_loss_rupees, utilization_pct, upsell_opportunity_rupees, observed_period_start, observed_period_end, notes)
  values ('Apollo Hyderabad','CT Scanner A','morning',180,40,2700000,600000,81.8,500000,'2026-06-01','2026-06-15','Heavy morning OPD load')
  returning id into v_u1;

  insert into public.chain_equipment_shift_utilization_r2499
    (chain_name, equipment_label, shift_slot, hours_used, hours_idle, revenue_rupees, idle_revenue_loss_rupees, utilization_pct, upsell_opportunity_rupees, observed_period_start, observed_period_end, notes)
  values ('Apollo Hyderabad','CT Scanner A','night',45,115,675000,1725000,28.1,1500000,'2026-06-01','2026-06-15','Night shift wide open — second-shift opportunity')
  returning id into v_u2;

  insert into public.chain_equipment_shift_utilization_r2499
    (chain_name, equipment_label, shift_slot, hours_used, hours_idle, revenue_rupees, idle_revenue_loss_rupees, utilization_pct, upsell_opportunity_rupees, observed_period_start, observed_period_end, notes)
  values ('KIMS Secunderabad','MRI 1.5T','afternoon',120,40,3600000,1200000,75.0,800000,'2026-06-01','2026-06-15','Cross-dept booking gap')
  returning id into v_u3;

  insert into public.chain_equipment_shift_utilization_r2499
    (chain_name, equipment_label, shift_slot, hours_used, hours_idle, revenue_rupees, idle_revenue_loss_rupees, utilization_pct, upsell_opportunity_rupees, observed_period_start, observed_period_end, notes)
  values ('Yashoda Malakpet','Ultrasound Cart 2','weekend',32,64,160000,320000,33.3,250000,'2026-06-01','2026-06-15','Weekend slot half-empty')
  returning id into v_u4;

  insert into public.equipment_upsell_actions_r2499
    (utilization_id, action_kind, owner_email, status, expected_revenue_rupees, notes)
  values
    (v_u2,'second_shift','sales@equipseva.in','in_progress',1500000,'Propose night radiology pact'),
    (v_u3,'cross_dept','sales@equipseva.in','open',800000,'Bridge ortho + cardio bookings'),
    (v_u1,'maintenance_window','ops@equipseva.in','done',150000,'Shift PM to off-peak window'),
    (v_u4,'extended_shift','sales@equipseva.in','open',250000,'Open Sunday afternoon slot'),
    (v_u3,'replacement_quote','sales@equipseva.in','dropped',0,'Hospital not ready to upgrade');
end;
$seed$;

------------------------------------------------------------
-- RPCs
------------------------------------------------------------
create or replace function public.list_utilization_r2499()
returns table (
  id uuid, chain_name text, equipment_label text, shift_slot text,
  hours_used numeric, hours_idle numeric, revenue_rupees bigint,
  idle_revenue_loss_rupees bigint, utilization_pct numeric,
  upsell_opportunity_rupees bigint,
  observed_period_start date, observed_period_end date, notes text
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select u.id, u.chain_name, u.equipment_label, u.shift_slot,
           u.hours_used, u.hours_idle, u.revenue_rupees,
           u.idle_revenue_loss_rupees, u.utilization_pct,
           u.upsell_opportunity_rupees,
           u.observed_period_start, u.observed_period_end, u.notes
    from public.chain_equipment_shift_utilization_r2499 u
    order by u.idle_revenue_loss_rupees desc, u.created_at desc;
end;
$$;
revoke execute on function public.list_utilization_r2499() from public, anon;
grant execute on function public.list_utilization_r2499() to authenticated;

create or replace function public.list_upsell_actions_r2499()
returns table (
  id uuid, utilization_id uuid, chain_name text, equipment_label text,
  action_kind text, proposed_at timestamptz, owner_email text, status text,
  expected_revenue_rupees bigint, notes text
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.id, a.utilization_id, u.chain_name, u.equipment_label,
           a.action_kind, a.proposed_at, a.owner_email, a.status,
           a.expected_revenue_rupees, a.notes
    from public.equipment_upsell_actions_r2499 a
    join public.chain_equipment_shift_utilization_r2499 u on u.id = a.utilization_id
    order by a.proposed_at desc;
end;
$$;
revoke execute on function public.list_upsell_actions_r2499() from public, anon;
grant execute on function public.list_upsell_actions_r2499() to authenticated;

create or replace function public.top_idle_focus_r2499()
returns table (
  id uuid, chain_name text, equipment_label text, shift_slot text,
  hours_idle numeric, idle_revenue_loss_rupees bigint, utilization_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select u.id, u.chain_name, u.equipment_label, u.shift_slot,
           u.hours_idle, u.idle_revenue_loss_rupees, u.utilization_pct
    from public.chain_equipment_shift_utilization_r2499 u
    order by u.idle_revenue_loss_rupees desc
    limit 10;
end;
$$;
revoke execute on function public.top_idle_focus_r2499() from public, anon;
grant execute on function public.top_idle_focus_r2499() to authenticated;

create or replace function public.shift_breakdown_r2499()
returns table (
  shift_slot text, rows_count bigint, total_hours_used numeric,
  total_hours_idle numeric, total_revenue_rupees bigint,
  total_idle_loss_rupees bigint, avg_utilization_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select u.shift_slot,
           count(*)::bigint,
           coalesce(sum(u.hours_used),0),
           coalesce(sum(u.hours_idle),0),
           coalesce(sum(u.revenue_rupees),0)::bigint,
           coalesce(sum(u.idle_revenue_loss_rupees),0)::bigint,
           coalesce(avg(u.utilization_pct),0)
    from public.chain_equipment_shift_utilization_r2499 u
    group by u.shift_slot
    order by u.shift_slot;
end;
$$;
revoke execute on function public.shift_breakdown_r2499() from public, anon;
grant execute on function public.shift_breakdown_r2499() to authenticated;

create or replace function public.top_upsell_opportunities_r2499()
returns table (
  id uuid, chain_name text, equipment_label text, shift_slot text,
  upsell_opportunity_rupees bigint, utilization_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select u.id, u.chain_name, u.equipment_label, u.shift_slot,
           u.upsell_opportunity_rupees, u.utilization_pct
    from public.chain_equipment_shift_utilization_r2499 u
    order by u.upsell_opportunity_rupees desc
    limit 10;
end;
$$;
revoke execute on function public.top_upsell_opportunities_r2499() from public, anon;
grant execute on function public.top_upsell_opportunities_r2499() to authenticated;

create or replace function public.weekly_utilization_trend_r2499()
returns table (
  week_start date, rows_count bigint, total_hours_used numeric,
  total_hours_idle numeric, total_revenue_rupees bigint,
  avg_utilization_pct numeric
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select date_trunc('week', u.observed_period_start)::date as wk,
           count(*)::bigint,
           coalesce(sum(u.hours_used),0),
           coalesce(sum(u.hours_idle),0),
           coalesce(sum(u.revenue_rupees),0)::bigint,
           coalesce(avg(u.utilization_pct),0)
    from public.chain_equipment_shift_utilization_r2499 u
    group by 1
    order by 1 desc;
end;
$$;
revoke execute on function public.weekly_utilization_trend_r2499() from public, anon;
grant execute on function public.weekly_utilization_trend_r2499() to authenticated;

create or replace function public.action_status_funnel_r2499()
returns table (
  status text, rows_count bigint, total_expected_revenue_rupees bigint
)
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.status,
           count(*)::bigint,
           coalesce(sum(a.expected_revenue_rupees),0)::bigint
    from public.equipment_upsell_actions_r2499 a
    group by a.status
    order by a.status;
end;
$$;
revoke execute on function public.action_status_funnel_r2499() from public, anon;
grant execute on function public.action_status_funnel_r2499() to authenticated;
