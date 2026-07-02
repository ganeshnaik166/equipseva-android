-- Round 2427: Hospital chain procurement cycle tracker
-- Chain x PO raised -> approved -> delivered cycle x lead days x bottleneck stage

create table if not exists public.chain_procurement_pos_r2427 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_name text not null,
  hospital_user_id uuid references public.profiles(id) on delete set null,
  po_external_ref text not null,
  raised_at timestamptz not null,
  approved_at timestamptz,
  delivered_at timestamptz,
  expected_delivery_at timestamptz,
  lead_days_total int,
  lead_days_to_approval int,
  lead_days_to_delivery int,
  bottleneck_stage text not null check (bottleneck_stage in ('approval','legal','procurement','logistics','delivery','none')),
  value_rupees bigint not null default 0 check (value_rupees >= 0),
  item_count int not null default 0 check (item_count >= 0),
  owner_email text,
  status text not null check (status in ('raised','approved','in_transit','delivered','cancelled')),
  notes text
);

alter table public.chain_procurement_pos_r2427 enable row level security;

drop policy if exists founder_all on public.chain_procurement_pos_r2427;
create policy founder_all on public.chain_procurement_pos_r2427
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

create table if not exists public.chain_procurement_bottlenecks_r2427 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_name text not null,
  week_start date not null,
  bottleneck_stage text not null,
  po_count int not null default 0 check (po_count >= 0),
  total_lead_days int not null default 0,
  avg_lead_days numeric(8,2) not null default 0,
  worst_offender_po text,
  action_plan text,
  owner_email text,
  status text not null check (status in ('open','in_progress','resolved','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  notes text
);

alter table public.chain_procurement_bottlenecks_r2427 enable row level security;

drop policy if exists founder_all on public.chain_procurement_bottlenecks_r2427;
create policy founder_all on public.chain_procurement_bottlenecks_r2427
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- Seed PO rows
insert into public.chain_procurement_pos_r2427
  (chain_name, po_external_ref, raised_at, approved_at, delivered_at, expected_delivery_at,
   lead_days_total, lead_days_to_approval, lead_days_to_delivery, bottleneck_stage,
   value_rupees, item_count, owner_email, status, notes)
values
  ('Apollo Hospitals', 'PO-AP-77821', now() - interval '32 days', now() - interval '28 days', now() - interval '6 days', now() - interval '10 days',
    26, 4, 22, 'logistics', 1840000, 14, 'procure.apollo@apollohospitals.com', 'delivered', 'Logistics ran 12 days past expected'),
  ('Manipal Health', 'PO-MAN-44910', now() - interval '21 days', now() - interval '18 days', null, now() - interval '2 days',
    null, 3, null, 'delivery', 920000, 8, 'central.procure@manipalhospitals.com', 'in_transit', 'Stuck at last-mile delivery 2 days'),
  ('Fortis Healthcare', 'PO-FRT-22119', now() - interval '14 days', null, null, now() + interval '7 days',
    null, null, null, 'approval', 2350000, 19, 'cmo.office@fortishealthcare.com', 'raised', 'CMO sign-off pending 14 days'),
  ('Max Healthcare', 'PO-MAX-90883', now() - interval '11 days', now() - interval '9 days', now() - interval '1 days', now() - interval '3 days',
    10, 2, 8, 'logistics', 540000, 5, 'biomedical@maxhealthcare.com', 'delivered', 'Slipped 2 days vs expected'),
  ('Narayana Health', 'PO-NH-33214', now() - interval '40 days', now() - interval '38 days', null, now() - interval '20 days',
    null, 2, null, 'procurement', 1280000, 11, 'procure@narayanahealth.org', 'cancelled', 'Vendor backed out; rebid');

-- Seed bottleneck rows
insert into public.chain_procurement_bottlenecks_r2427
  (chain_name, week_start, bottleneck_stage, po_count, total_lead_days, avg_lead_days,
   worst_offender_po, action_plan, owner_email, status, notes)
values
  ('Apollo Hospitals', (current_date - 7)::date, 'logistics', 4, 88, 22.0,
    'PO-AP-77821', 'Switch from road-only to road+air-hybrid for sub-2-day commits', 'procure.apollo@apollohospitals.com', 'in_progress', 'Pilot 2 routes Mumbai-BLR'),
  ('Manipal Health', (current_date - 7)::date, 'delivery', 3, 54, 18.0,
    'PO-MAN-44910', 'Onboard local 3PL in Bengaluru for last-mile', 'central.procure@manipalhospitals.com', 'open', null),
  ('Fortis Healthcare', (current_date - 14)::date, 'approval', 5, 72, 14.4,
    'PO-FRT-22119', 'Pre-approval matrix - delegate <25L to GM', 'cmo.office@fortishealthcare.com', 'open', 'Awaiting board nod'),
  ('Narayana Health', (current_date - 14)::date, 'procurement', 2, 78, 39.0,
    'PO-NH-33214', 'Maintain 3-vendor live panel per category', 'procure@narayanahealth.org', 'resolved', 'Panel live since last cycle'),
  ('Max Healthcare', (current_date - 7)::date, 'logistics', 3, 38, 12.6,
    'PO-MAX-90883', 'Tighten dispatch SLA with biomedical vendor', 'biomedical@maxhealthcare.com', 'dropped', 'Low impact - drop');

-- RPCs

create or replace function public.list_pos_r2427()
returns table (
  id uuid,
  chain_name text,
  po_external_ref text,
  raised_at timestamptz,
  approved_at timestamptz,
  delivered_at timestamptz,
  expected_delivery_at timestamptz,
  lead_days_total int,
  lead_days_to_approval int,
  lead_days_to_delivery int,
  bottleneck_stage text,
  value_rupees bigint,
  item_count int,
  owner_email text,
  status text,
  notes text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.id, p.chain_name, p.po_external_ref, p.raised_at, p.approved_at, p.delivered_at, p.expected_delivery_at,
           p.lead_days_total, p.lead_days_to_approval, p.lead_days_to_delivery, p.bottleneck_stage,
           p.value_rupees, p.item_count, p.owner_email, p.status, p.notes
    from public.chain_procurement_pos_r2427 p
    order by p.raised_at desc;
end;
$$;
revoke execute on function public.list_pos_r2427() from public, anon;
grant execute on function public.list_pos_r2427() to authenticated;

create or replace function public.list_bottlenecks_r2427()
returns table (
  id uuid,
  chain_name text,
  week_start date,
  bottleneck_stage text,
  po_count int,
  total_lead_days int,
  avg_lead_days numeric,
  worst_offender_po text,
  action_plan text,
  owner_email text,
  status text,
  closed_at timestamptz,
  closed_by_email text,
  notes text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.id, b.chain_name, b.week_start, b.bottleneck_stage, b.po_count, b.total_lead_days,
           b.avg_lead_days, b.worst_offender_po, b.action_plan, b.owner_email, b.status,
           b.closed_at, b.closed_by_email, b.notes
    from public.chain_procurement_bottlenecks_r2427 b
    order by b.week_start desc, b.avg_lead_days desc;
end;
$$;
revoke execute on function public.list_bottlenecks_r2427() from public, anon;
grant execute on function public.list_bottlenecks_r2427() to authenticated;

create or replace function public.bottleneck_breakdown_r2427()
returns table (
  bottleneck_stage text,
  po_count bigint,
  avg_lead_days numeric,
  total_value_rupees bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.bottleneck_stage,
           count(*)::bigint as po_count,
           coalesce(round(avg(p.lead_days_total)::numeric, 2), 0) as avg_lead_days,
           coalesce(sum(p.value_rupees), 0)::bigint as total_value_rupees
    from public.chain_procurement_pos_r2427 p
    group by p.bottleneck_stage
    order by po_count desc;
end;
$$;
revoke execute on function public.bottleneck_breakdown_r2427() from public, anon;
grant execute on function public.bottleneck_breakdown_r2427() to authenticated;

create or replace function public.top_slow_pos_r2427()
returns table (
  id uuid,
  chain_name text,
  po_external_ref text,
  bottleneck_stage text,
  lead_days_total int,
  value_rupees bigint,
  status text,
  owner_email text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.id, p.chain_name, p.po_external_ref, p.bottleneck_stage,
           p.lead_days_total, p.value_rupees, p.status, p.owner_email
    from public.chain_procurement_pos_r2427 p
    where p.lead_days_total is not null
    order by p.lead_days_total desc nulls last
    limit 10;
end;
$$;
revoke execute on function public.top_slow_pos_r2427() from public, anon;
grant execute on function public.top_slow_pos_r2427() to authenticated;

create or replace function public.weekly_lead_trend_r2427()
returns table (
  week_start date,
  po_count bigint,
  avg_lead_days numeric
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select date_trunc('week', p.raised_at)::date as week_start,
           count(*)::bigint as po_count,
           coalesce(round(avg(p.lead_days_total)::numeric, 2), 0) as avg_lead_days
    from public.chain_procurement_pos_r2427 p
    group by 1
    order by 1 desc
    limit 12;
end;
$$;
revoke execute on function public.weekly_lead_trend_r2427() from public, anon;
grant execute on function public.weekly_lead_trend_r2427() to authenticated;

create or replace function public.chain_lead_summary_r2427()
returns table (
  chain_name text,
  po_count bigint,
  avg_lead_days numeric,
  total_value_rupees bigint,
  open_bottlenecks bigint
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.chain_name,
           count(*)::bigint as po_count,
           coalesce(round(avg(p.lead_days_total)::numeric, 2), 0) as avg_lead_days,
           coalesce(sum(p.value_rupees), 0)::bigint as total_value_rupees,
           coalesce((
             select count(*) from public.chain_procurement_bottlenecks_r2427 b
             where b.chain_name = p.chain_name and b.status in ('open','in_progress')
           ), 0)::bigint as open_bottlenecks
    from public.chain_procurement_pos_r2427 p
    group by p.chain_name
    order by avg_lead_days desc nulls last;
end;
$$;
revoke execute on function public.chain_lead_summary_r2427() from public, anon;
grant execute on function public.chain_lead_summary_r2427() to authenticated;

create or replace function public.upcoming_deliveries_r2427()
returns table (
  id uuid,
  chain_name text,
  po_external_ref text,
  expected_delivery_at timestamptz,
  status text,
  bottleneck_stage text,
  value_rupees bigint,
  owner_email text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.id, p.chain_name, p.po_external_ref, p.expected_delivery_at, p.status,
           p.bottleneck_stage, p.value_rupees, p.owner_email
    from public.chain_procurement_pos_r2427 p
    where p.status in ('raised','approved','in_transit')
    order by p.expected_delivery_at asc nulls last
    limit 20;
end;
$$;
revoke execute on function public.upcoming_deliveries_r2427() from public, anon;
grant execute on function public.upcoming_deliveries_r2427() to authenticated;
