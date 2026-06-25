-- r2664 customer-monthly-equipment-utilization-grade
-- Tables track monthly utilization grade per equipment per hospital plus improvement actions.

create table if not exists public.customer_utilization_grade_r2664 (
  id uuid primary key default gen_random_uuid(),
  hospital_user_id uuid not null references public.profiles(id) on delete cascade,
  month_label text not null,
  equipment_label text not null,
  equipment_kind text not null,
  utilization_pct numeric(6,2) not null default 0,
  target_pct numeric(6,2) not null default 70,
  utilization_grade text not null default 'C' check (utilization_grade in ('A','B','C','D','F')),
  owner_email text not null default '',
  status text not null default 'strong' check (status in ('strong','improving','declining','under_utilized')),
  notes text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists customer_utilization_grade_r2664_hospital_idx
  on public.customer_utilization_grade_r2664(hospital_user_id);
create index if not exists customer_utilization_grade_r2664_status_idx
  on public.customer_utilization_grade_r2664(status);
create index if not exists customer_utilization_grade_r2664_grade_idx
  on public.customer_utilization_grade_r2664(utilization_grade);
create index if not exists customer_utilization_grade_r2664_month_idx
  on public.customer_utilization_grade_r2664(month_label);

alter table public.customer_utilization_grade_r2664 enable row level security;
drop policy if exists founder_all on public.customer_utilization_grade_r2664;
create policy founder_all on public.customer_utilization_grade_r2664
  for all to authenticated using (public.is_founder()) with check (public.is_founder());

create table if not exists public.utilization_improvement_actions_r2664 (
  id uuid primary key default gen_random_uuid(),
  grade_id uuid not null references public.customer_utilization_grade_r2664(id) on delete cascade,
  action_at timestamptz not null default now(),
  action_kind text not null default 'training' check (action_kind in ('training','cross_dept','marketing','extended_hours','replacement_quote')),
  outcome text not null default 'pending' check (outcome in ('positive','neutral','negative','pending')),
  owner_email text not null default '',
  status text not null default 'open' check (status in ('open','done','dropped')),
  notes text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists utilization_improvement_actions_r2664_grade_idx
  on public.utilization_improvement_actions_r2664(grade_id);
create index if not exists utilization_improvement_actions_r2664_status_idx
  on public.utilization_improvement_actions_r2664(status);
create index if not exists utilization_improvement_actions_r2664_outcome_idx
  on public.utilization_improvement_actions_r2664(outcome);

alter table public.utilization_improvement_actions_r2664 enable row level security;
drop policy if exists founder_all on public.utilization_improvement_actions_r2664;
create policy founder_all on public.utilization_improvement_actions_r2664
  for all to authenticated using (public.is_founder()) with check (public.is_founder());

-- Seed: 4 grade rows + 4 actions. Pick first hospital_admin profile if present.
do $seed$
declare
  v_hospital uuid;
  v_g1 uuid;
  v_g2 uuid;
  v_g3 uuid;
  v_g4 uuid;
begin
  select id into v_hospital from public.profiles where role = 'hospital_admin' order by created_at asc limit 1;
  if v_hospital is null then
    return;
  end if;

  insert into public.customer_utilization_grade_r2664
    (hospital_user_id, month_label, equipment_label, equipment_kind, utilization_pct, target_pct, utilization_grade, owner_email, status, notes)
  values
    (v_hospital, '2026-05', 'GE Vivid E95 Ultrasound', 'ultrasound', 88.50, 70.00, 'A', 'cs1@equipseva.in', 'strong', 'Cardiology peak hours running at capacity')
  returning id into v_g1;

  insert into public.customer_utilization_grade_r2664
    (hospital_user_id, month_label, equipment_label, equipment_kind, utilization_pct, target_pct, utilization_grade, owner_email, status, notes)
  values
    (v_hospital, '2026-05', 'Philips Ingenuity CT 128', 'ct_scanner', 64.00, 70.00, 'B', 'cs1@equipseva.in', 'improving', 'Added evening shift slots this month')
  returning id into v_g2;

  insert into public.customer_utilization_grade_r2664
    (hospital_user_id, month_label, equipment_label, equipment_kind, utilization_pct, target_pct, utilization_grade, owner_email, status, notes)
  values
    (v_hospital, '2026-05', 'Siemens Magnetom Aera MRI', 'mri', 41.20, 70.00, 'D', 'cs2@equipseva.in', 'under_utilized', 'Radiologist headcount gap; weekend slots empty')
  returning id into v_g3;

  insert into public.customer_utilization_grade_r2664
    (hospital_user_id, month_label, equipment_label, equipment_kind, utilization_pct, target_pct, utilization_grade, owner_email, status, notes)
  values
    (v_hospital, '2026-04', 'Mindray BeneVision N17 Monitor', 'patient_monitor', 72.00, 70.00, 'B', 'cs2@equipseva.in', 'declining', 'ICU census down month over month')
  returning id into v_g4;

  insert into public.utilization_improvement_actions_r2664
    (grade_id, action_at, action_kind, outcome, owner_email, status, notes)
  values
    (v_g2, (now() - interval '12 days')::timestamptz, 'extended_hours', 'positive', 'cs1@equipseva.in', 'done', 'Evening shift pilot lifted utilization 9 points'),
    (v_g3, (now() - interval '8 days')::timestamptz, 'cross_dept', 'pending', 'cs2@equipseva.in', 'open', 'Route ortho referrals to MRI suite Saturdays'),
    (v_g3, (now() - interval '4 days')::timestamptz, 'marketing', 'neutral', 'cs2@equipseva.in', 'open', 'Outbound referral campaign to 3 nearby polyclinics'),
    (v_g4, (now() - interval '20 days')::timestamptz, 'training', 'positive', 'cs2@equipseva.in', 'done', 'Refresher session for nursing staff on monitor features');
end;
$seed$;

-- RPC 1: list_grades_r2664
create or replace function public.list_grades_r2664()
returns table (
  id uuid,
  hospital_user_id uuid,
  month_label text,
  equipment_label text,
  equipment_kind text,
  utilization_pct numeric,
  target_pct numeric,
  utilization_grade text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select g.id, g.hospital_user_id, g.month_label, g.equipment_label, g.equipment_kind,
           g.utilization_pct, g.target_pct, g.utilization_grade, g.owner_email, g.status, g.notes, g.created_at
    from public.customer_utilization_grade_r2664 g
    order by g.month_label desc, g.utilization_pct asc;
end;
$$;
revoke execute on function public.list_grades_r2664() from public, anon;
grant execute on function public.list_grades_r2664() to authenticated;

-- RPC 2: list_actions_r2664
create or replace function public.list_actions_r2664()
returns table (
  id uuid,
  grade_id uuid,
  equipment_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.id, a.grade_id, g.equipment_label, a.action_at, a.action_kind, a.outcome,
           a.owner_email, a.status, a.notes
    from public.utilization_improvement_actions_r2664 a
    join public.customer_utilization_grade_r2664 g on g.id = a.grade_id
    order by a.action_at desc;
end;
$$;
revoke execute on function public.list_actions_r2664() from public, anon;
grant execute on function public.list_actions_r2664() to authenticated;

-- RPC 3: top_under_utilized_focus_r2664
create or replace function public.top_under_utilized_focus_r2664()
returns table (
  id uuid,
  equipment_label text,
  equipment_kind text,
  month_label text,
  utilization_pct numeric,
  target_pct numeric,
  gap_pct numeric,
  utilization_grade text,
  status text,
  owner_email text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select g.id, g.equipment_label, g.equipment_kind, g.month_label,
           g.utilization_pct, g.target_pct,
           (g.target_pct - g.utilization_pct) as gap_pct,
           g.utilization_grade, g.status, g.owner_email
    from public.customer_utilization_grade_r2664 g
    where g.utilization_pct < g.target_pct
    order by (g.target_pct - g.utilization_pct) desc
    limit 10;
end;
$$;
revoke execute on function public.top_under_utilized_focus_r2664() from public, anon;
grant execute on function public.top_under_utilized_focus_r2664() to authenticated;

-- RPC 4: grade_distribution_r2664
create or replace function public.grade_distribution_r2664()
returns table (
  utilization_grade text,
  total bigint,
  avg_utilization numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select g.utilization_grade,
           count(*)::bigint as total,
           round(avg(g.utilization_pct)::numeric, 2) as avg_utilization
    from public.customer_utilization_grade_r2664 g
    group by g.utilization_grade
    order by g.utilization_grade asc;
end;
$$;
revoke execute on function public.grade_distribution_r2664() from public, anon;
grant execute on function public.grade_distribution_r2664() to authenticated;

-- RPC 5: status_funnel_r2664
create or replace function public.status_funnel_r2664()
returns table (
  status text,
  total bigint,
  avg_utilization numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select g.status,
           count(*)::bigint as total,
           round(avg(g.utilization_pct)::numeric, 2) as avg_utilization
    from public.customer_utilization_grade_r2664 g
    group by g.status
    order by total desc;
end;
$$;
revoke execute on function public.status_funnel_r2664() from public, anon;
grant execute on function public.status_funnel_r2664() to authenticated;

-- RPC 6: monthly_grade_trend_r2664
create or replace function public.monthly_grade_trend_r2664()
returns table (
  month_label text,
  total bigint,
  avg_utilization numeric,
  under_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select g.month_label,
           count(*)::bigint as total,
           round(avg(g.utilization_pct)::numeric, 2) as avg_utilization,
           sum(case when g.status = 'under_utilized' then 1 else 0 end)::bigint as under_count
    from public.customer_utilization_grade_r2664 g
    group by g.month_label
    order by g.month_label desc;
end;
$$;
revoke execute on function public.monthly_grade_trend_r2664() from public, anon;
grant execute on function public.monthly_grade_trend_r2664() to authenticated;

-- RPC 7: owner_load_r2664
create or replace function public.owner_load_r2664()
returns table (
  owner_email text,
  grade_count bigint,
  open_actions bigint,
  under_utilized bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
    select g.owner_email,
           count(distinct g.id)::bigint as grade_count,
           coalesce(sum(case when a.status = 'open' then 1 else 0 end), 0)::bigint as open_actions,
           sum(case when g.status = 'under_utilized' then 1 else 0 end)::bigint as under_utilized
    from public.customer_utilization_grade_r2664 g
    left join public.utilization_improvement_actions_r2664 a on a.grade_id = g.id
    group by g.owner_email
    order by grade_count desc;
end;
$$;
revoke execute on function public.owner_load_r2664() from public, anon;
grant execute on function public.owner_load_r2664() to authenticated;
