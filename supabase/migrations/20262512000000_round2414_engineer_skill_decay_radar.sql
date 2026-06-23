-- Round 2414: Engineer Skill Decay Radar
-- Tracks engineer skill inventory, last-used dates, decay alerts, certification expiry

create table if not exists public.engineer_skill_inventory_r2414 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  engineer_user_id uuid not null references public.engineers(id) on delete cascade,
  skill_name text not null,
  skill_category text not null check (skill_category in ('electrical','mechanical','software','safety','imaging','process')),
  proficiency_level text not null check (proficiency_level in ('beginner','intermediate','advanced','expert')),
  last_used_at timestamptz,
  last_assessed_at timestamptz,
  last_score_pct numeric(5,2) check (last_score_pct is null or (last_score_pct >= 0 and last_score_pct <= 100)),
  refresher_recommended_at timestamptz,
  certification_expires_at timestamptz,
  certification_authority text,
  notes text
);

create index if not exists idx_skill_inv_r2414_eng on public.engineer_skill_inventory_r2414(engineer_user_id);
create index if not exists idx_skill_inv_r2414_cat on public.engineer_skill_inventory_r2414(skill_category);
create index if not exists idx_skill_inv_r2414_lastused on public.engineer_skill_inventory_r2414(last_used_at);

create table if not exists public.skill_decay_alerts_r2414 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  engineer_user_id uuid not null references public.engineers(id) on delete cascade,
  skill_name text not null,
  alert_kind text not null check (alert_kind in ('decay','expiring_cert','never_assessed')),
  decay_days integer not null default 0,
  severity text not null check (severity in ('low','medium','high','critical')),
  recommended_refresher text,
  refresher_due_at timestamptz,
  status text not null default 'open' check (status in ('open','scheduled','completed','dropped')),
  closed_at timestamptz,
  closed_by_email text
);

create index if not exists idx_skill_alerts_r2414_eng on public.skill_decay_alerts_r2414(engineer_user_id);
create index if not exists idx_skill_alerts_r2414_status on public.skill_decay_alerts_r2414(status);
create index if not exists idx_skill_alerts_r2414_sev on public.skill_decay_alerts_r2414(severity);

alter table public.engineer_skill_inventory_r2414 enable row level security;
alter table public.skill_decay_alerts_r2414 enable row level security;

drop policy if exists founder_all on public.engineer_skill_inventory_r2414;
create policy founder_all on public.engineer_skill_inventory_r2414
  for all to authenticated
  using (public.is_founder()) with check (public.is_founder());

drop policy if exists founder_all on public.skill_decay_alerts_r2414;
create policy founder_all on public.skill_decay_alerts_r2414
  for all to authenticated
  using (public.is_founder()) with check (public.is_founder());

-- Seed data
do $$
declare
  eng_a uuid;
  eng_b uuid;
  eng_c uuid;
begin
  select id into eng_a from public.engineers order by created_at asc limit 1;
  select id into eng_b from public.engineers order by created_at asc offset 1 limit 1;
  select id into eng_c from public.engineers order by created_at asc offset 2 limit 1;

  if eng_a is not null then
    insert into public.engineer_skill_inventory_r2414
      (engineer_user_id, skill_name, skill_category, proficiency_level, last_used_at, last_assessed_at, last_score_pct, refresher_recommended_at, certification_expires_at, certification_authority, notes)
    values
      (eng_a, 'GE Logiq P9 Ultrasound Calibration', 'imaging', 'expert', now() - interval '210 days', now() - interval '400 days', 88.5, now() - interval '15 days', now() + interval '60 days', 'GE Healthcare', 'Long gap since last hands-on; schedule refresher.'),
      (eng_a, 'Defibrillator Discharge Safety', 'safety', 'advanced', now() - interval '30 days', now() - interval '90 days', 92.0, null, now() + interval '14 days', 'AHA India', 'Cert expiring in 2 weeks.');
  end if;

  if eng_b is not null then
    insert into public.engineer_skill_inventory_r2414
      (engineer_user_id, skill_name, skill_category, proficiency_level, last_used_at, last_assessed_at, last_score_pct, refresher_recommended_at, certification_expires_at, certification_authority, notes)
    values
      (eng_b, 'Mindray Anesthesia Workstation PM', 'mechanical', 'intermediate', now() - interval '420 days', null, null, now() - interval '60 days', null, null, 'Never formally assessed.'),
      (eng_b, 'DICOM Network Troubleshooting', 'software', 'advanced', now() - interval '120 days', now() - interval '180 days', 76.0, null, null, null, 'Mid-tier proficiency.');
  end if;

  if eng_c is not null then
    insert into public.engineer_skill_inventory_r2414
      (engineer_user_id, skill_name, skill_category, proficiency_level, last_used_at, last_assessed_at, last_score_pct, refresher_recommended_at, certification_expires_at, certification_authority, notes)
    values
      (eng_c, 'HV X-ray Tube Replacement', 'electrical', 'expert', now() - interval '15 days', now() - interval '45 days', 95.0, null, now() + interval '180 days', 'AERB', 'Recent and current.');
  end if;

  if eng_a is not null then
    insert into public.skill_decay_alerts_r2414
      (engineer_user_id, skill_name, alert_kind, decay_days, severity, recommended_refresher, refresher_due_at, status)
    values
      (eng_a, 'GE Logiq P9 Ultrasound Calibration', 'decay', 210, 'high', 'Shadow senior on 2 ultrasound jobs', now() + interval '21 days', 'open'),
      (eng_a, 'Defibrillator Discharge Safety', 'expiring_cert', 14, 'critical', 'Renew AHA cert before expiry', now() + interval '10 days', 'scheduled');
  end if;

  if eng_b is not null then
    insert into public.skill_decay_alerts_r2414
      (engineer_user_id, skill_name, alert_kind, decay_days, severity, recommended_refresher, refresher_due_at, status)
    values
      (eng_b, 'Mindray Anesthesia Workstation PM', 'never_assessed', 420, 'high', 'Formal proficiency test + supervised job', now() + interval '30 days', 'open');
  end if;
end $$;

-- RPCs

create or replace function public.list_inventory_r2414()
returns table (
  id uuid,
  engineer_user_id uuid,
  skill_name text,
  skill_category text,
  proficiency_level text,
  last_used_at timestamptz,
  last_assessed_at timestamptz,
  last_score_pct numeric,
  decay_days integer,
  certification_expires_at timestamptz,
  certification_authority text,
  notes text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.id, i.engineer_user_id, i.skill_name, i.skill_category, i.proficiency_level,
         i.last_used_at, i.last_assessed_at, i.last_score_pct,
         case when i.last_used_at is null then null else extract(day from (now() - i.last_used_at))::int end,
         i.certification_expires_at, i.certification_authority, i.notes
  from public.engineer_skill_inventory_r2414 i
  order by i.last_used_at asc nulls first;
end $$;
revoke execute on function public.list_inventory_r2414() from public, anon;
grant execute on function public.list_inventory_r2414() to authenticated;

create or replace function public.list_alerts_r2414()
returns table (
  id uuid,
  engineer_user_id uuid,
  skill_name text,
  alert_kind text,
  decay_days integer,
  severity text,
  recommended_refresher text,
  refresher_due_at timestamptz,
  status text,
  closed_at timestamptz,
  closed_by_email text
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.id, a.engineer_user_id, a.skill_name, a.alert_kind, a.decay_days, a.severity,
         a.recommended_refresher, a.refresher_due_at, a.status, a.closed_at, a.closed_by_email
  from public.skill_decay_alerts_r2414 a
  order by case a.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end,
           a.decay_days desc;
end $$;
revoke execute on function public.list_alerts_r2414() from public, anon;
grant execute on function public.list_alerts_r2414() to authenticated;

create or replace function public.decay_distribution_r2414()
returns table (
  bucket text,
  skill_count integer
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.bucket, coalesce(count(i.id), 0)::int
  from (values ('0-30d'), ('31-90d'), ('91-180d'), ('181-365d'), ('365d+'), ('never_used')) as b(bucket)
  left join public.engineer_skill_inventory_r2414 i
    on case
         when i.last_used_at is null then 'never_used'
         when extract(day from (now() - i.last_used_at)) <= 30 then '0-30d'
         when extract(day from (now() - i.last_used_at)) <= 90 then '31-90d'
         when extract(day from (now() - i.last_used_at)) <= 180 then '91-180d'
         when extract(day from (now() - i.last_used_at)) <= 365 then '181-365d'
         else '365d+'
       end = b.bucket
  group by b.bucket
  order by case b.bucket when '0-30d' then 1 when '31-90d' then 2 when '91-180d' then 3 when '181-365d' then 4 when '365d+' then 5 else 6 end;
end $$;
revoke execute on function public.decay_distribution_r2414() from public, anon;
grant execute on function public.decay_distribution_r2414() to authenticated;

create or replace function public.expiring_certs_r2414()
returns table (
  id uuid,
  engineer_user_id uuid,
  skill_name text,
  certification_authority text,
  certification_expires_at timestamptz,
  days_until_expiry integer
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.id, i.engineer_user_id, i.skill_name, i.certification_authority,
         i.certification_expires_at,
         extract(day from (i.certification_expires_at - now()))::int
  from public.engineer_skill_inventory_r2414 i
  where i.certification_expires_at is not null
    and i.certification_expires_at <= now() + interval '180 days'
  order by i.certification_expires_at asc;
end $$;
revoke execute on function public.expiring_certs_r2414() from public, anon;
grant execute on function public.expiring_certs_r2414() to authenticated;

create or replace function public.never_assessed_r2414()
returns table (
  id uuid,
  engineer_user_id uuid,
  skill_name text,
  skill_category text,
  proficiency_level text,
  last_used_at timestamptz
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.id, i.engineer_user_id, i.skill_name, i.skill_category, i.proficiency_level, i.last_used_at
  from public.engineer_skill_inventory_r2414 i
  where i.last_assessed_at is null
  order by i.created_at asc;
end $$;
revoke execute on function public.never_assessed_r2414() from public, anon;
grant execute on function public.never_assessed_r2414() to authenticated;

create or replace function public.top_decayed_engineers_r2414()
returns table (
  engineer_user_id uuid,
  decayed_skill_count integer,
  avg_decay_days numeric,
  max_decay_days integer
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.engineer_user_id,
         count(*)::int,
         round(avg(extract(day from (now() - i.last_used_at)))::numeric, 1),
         max(extract(day from (now() - i.last_used_at)))::int
  from public.engineer_skill_inventory_r2414 i
  where i.last_used_at is not null
    and extract(day from (now() - i.last_used_at)) > 90
  group by i.engineer_user_id
  order by count(*) desc, max(extract(day from (now() - i.last_used_at))) desc;
end $$;
revoke execute on function public.top_decayed_engineers_r2414() from public, anon;
grant execute on function public.top_decayed_engineers_r2414() to authenticated;

create or replace function public.refresher_pipeline_r2414()
returns table (
  status text,
  alert_count integer,
  critical_count integer,
  high_count integer
)
language plpgsql stable security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.status,
         coalesce(count(a.id), 0)::int,
         coalesce(sum(case when a.severity = 'critical' then 1 else 0 end), 0)::int,
         coalesce(sum(case when a.severity = 'high' then 1 else 0 end), 0)::int
  from (values ('open'), ('scheduled'), ('completed'), ('dropped')) as s(status)
  left join public.skill_decay_alerts_r2414 a on a.status = s.status
  group by s.status
  order by case s.status when 'open' then 1 when 'scheduled' then 2 when 'completed' then 3 else 4 end;
end $$;
revoke execute on function public.refresher_pipeline_r2414() from public, anon;
grant execute on function public.refresher_pipeline_r2414() to authenticated;
