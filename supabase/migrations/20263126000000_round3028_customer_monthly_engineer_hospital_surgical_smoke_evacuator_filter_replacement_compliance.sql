-- Round 3028 — Surgical Smoke-Evacuator Filter Replacement Compliance
-- Two tables (_r3028) + 7 RPCs (is_founder gated)

-- ============================================================
-- TABLE 1: filter replacement events
-- ============================================================
create table if not exists public.smoke_evac_filter_replacements_r3028 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_name text not null,
  hospital_city text not null,
  evacuator_unit_serial text not null,
  ot_room_label text not null,
  filter_type text not null check (filter_type in ('ulpa','hepa','charcoal','combo_ulpa_charcoal')),
  scheduled_for date not null,
  replaced_at timestamptz,
  replaced_by_engineer text,
  engineer_signature_ref text,
  saturation_pct numeric(5,2) check (saturation_pct is null or (saturation_pct >= 0 and saturation_pct <= 100)),
  hours_used numeric(7,2) check (hours_used is null or hours_used >= 0),
  compliance_status text not null check (compliance_status in ('on_time','late','missed','upcoming','in_progress')),
  delay_days int not null default 0 check (delay_days >= 0),
  cost_rupees int not null check (cost_rupees >= 0),
  notes text
);

alter table public.smoke_evac_filter_replacements_r3028 enable row level security;

drop policy if exists r3028_filters_founder_select on public.smoke_evac_filter_replacements_r3028;
create policy r3028_filters_founder_select on public.smoke_evac_filter_replacements_r3028
  for select using (public.is_founder());

revoke all on public.smoke_evac_filter_replacements_r3028 from public, anon;
grant select on public.smoke_evac_filter_replacements_r3028 to authenticated;

insert into public.smoke_evac_filter_replacements_r3028
  (hospital_name, hospital_city, evacuator_unit_serial, ot_room_label, filter_type, scheduled_for, replaced_at, replaced_by_engineer, engineer_signature_ref, saturation_pct, hours_used, compliance_status, delay_days, cost_rupees, notes)
values
  ('Apollo Jubilee Hills','Hyderabad','SE-AP-J-001','OT-1','ulpa','2026-06-01'::date,'2026-06-01 09:12:00+05:30'::timestamptz,'Ramesh K','sig_8821',74.5,142.0,'on_time',0,4200,'routine swap'),
  ('Apollo Jubilee Hills','Hyderabad','SE-AP-J-002','OT-2','hepa','2026-06-03'::date,'2026-06-05 11:00:00+05:30'::timestamptz,'Ramesh K','sig_8824',91.2,168.5,'late',2,3800,'engineer rerouted'),
  ('KIMS Secunderabad','Hyderabad','SE-KIMS-04','OT-3','combo_ulpa_charcoal','2026-06-04'::date,'2026-06-04 08:30:00+05:30'::timestamptz,'Sunita R','sig_8830',68.0,131.4,'on_time',0,6200,null),
  ('Manipal Whitefield','Bangalore','SE-MAN-W-11','OT-1','ulpa','2026-06-05'::date,null,null,null,null,null,'missed',7,4400,'hospital escalated to founder'),
  ('Manipal Whitefield','Bangalore','SE-MAN-W-12','OT-5','hepa','2026-06-06'::date,'2026-06-06 14:20:00+05:30'::timestamptz,'Akhil P','sig_8841',82.4,159.1,'on_time',0,3700,null),
  ('Fortis BG Road','Bangalore','SE-FOR-BG-08','OT-2','charcoal','2026-06-07'::date,'2026-06-08 10:00:00+05:30'::timestamptz,'Vikram S','sig_8855',77.0,148.0,'late',1,2900,null),
  ('Fortis BG Road','Bangalore','SE-FOR-BG-09','OT-4','ulpa','2026-06-08'::date,'2026-06-08 12:45:00+05:30'::timestamptz,'Vikram S','sig_8857',71.5,138.2,'on_time',0,4150,null),
  ('Yashoda Somajiguda','Hyderabad','SE-YAS-S-21','OT-3','combo_ulpa_charcoal','2026-06-09'::date,'2026-06-12 10:15:00+05:30'::timestamptz,'Sunita R','sig_8861',95.0,172.4,'late',3,6300,'shortage on combo SKU'),
  ('Yashoda Somajiguda','Hyderabad','SE-YAS-S-22','OT-1','hepa','2026-06-10'::date,'2026-06-10 09:00:00+05:30'::timestamptz,'Sunita R','sig_8863',69.0,141.0,'on_time',0,3850,null),
  ('Continental Gachibowli','Hyderabad','SE-CON-G-15','OT-6','ulpa','2026-06-11'::date,null,null,null,null,null,'upcoming',0,4200,null),
  ('Continental Gachibowli','Hyderabad','SE-CON-G-16','OT-2','charcoal','2026-06-12'::date,null,null,null,null,null,'upcoming',0,2950,null),
  ('Rainbow Vikrampuri','Hyderabad','SE-RB-V-03','OT-1','hepa','2026-06-12'::date,'2026-06-12 11:00:00+05:30'::timestamptz,'Ramesh K','sig_8870',73.0,144.5,'on_time',0,3700,null),
  ('AIG Gachibowli','Hyderabad','SE-AIG-G-31','OT-7','ulpa','2026-06-13'::date,'2026-06-15 08:30:00+05:30'::timestamptz,'Akhil P','sig_8875',88.6,164.0,'late',2,4400,null),
  ('AIG Gachibowli','Hyderabad','SE-AIG-G-32','OT-3','combo_ulpa_charcoal','2026-06-14'::date,null,null,null,null,null,'in_progress',1,6250,'engineer on site'),
  ('Care Banjara','Hyderabad','SE-CARE-B-07','OT-2','hepa','2026-06-15'::date,null,null,null,null,null,'upcoming',0,3800,null),
  ('Care Banjara','Hyderabad','SE-CARE-B-08','OT-4','ulpa','2026-06-16'::date,null,null,null,null,null,'upcoming',0,4200,null),
  ('Sakra World','Bangalore','SE-SAK-W-12','OT-1','charcoal','2026-06-17'::date,null,null,null,null,null,'upcoming',0,2900,null),
  ('Sakra World','Bangalore','SE-SAK-W-13','OT-3','combo_ulpa_charcoal','2026-06-18'::date,null,null,null,null,null,'upcoming',0,6300,null);

-- ============================================================
-- TABLE 2: monthly hospital compliance scorecard
-- ============================================================
create table if not exists public.smoke_evac_hospital_scorecard_r3028 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_name text not null,
  hospital_city text not null,
  scorecard_month date not null,
  ot_count int not null check (ot_count >= 0),
  total_filters_due int not null check (total_filters_due >= 0),
  on_time_count int not null check (on_time_count >= 0),
  late_count int not null check (late_count >= 0),
  missed_count int not null check (missed_count >= 0),
  compliance_pct numeric(5,2) not null check (compliance_pct >= 0 and compliance_pct <= 100),
  avg_delay_days numeric(4,2) not null check (avg_delay_days >= 0),
  tier_label text not null check (tier_label in ('platinum','gold','silver','bronze','watchlist')),
  primary_engineer text,
  amc_status text not null check (amc_status in ('active','renewal_due','expired','grace')),
  monthly_fee_rupees int not null check (monthly_fee_rupees >= 0),
  notes text
);

alter table public.smoke_evac_hospital_scorecard_r3028 enable row level security;

drop policy if exists r3028_score_founder_select on public.smoke_evac_hospital_scorecard_r3028;
create policy r3028_score_founder_select on public.smoke_evac_hospital_scorecard_r3028
  for select using (public.is_founder());

revoke all on public.smoke_evac_hospital_scorecard_r3028 from public, anon;
grant select on public.smoke_evac_hospital_scorecard_r3028 to authenticated;

insert into public.smoke_evac_hospital_scorecard_r3028
  (hospital_name, hospital_city, scorecard_month, ot_count, total_filters_due, on_time_count, late_count, missed_count, compliance_pct, avg_delay_days, tier_label, primary_engineer, amc_status, monthly_fee_rupees, notes)
values
  ('Apollo Jubilee Hills','Hyderabad','2026-05-01'::date,8,16,15,1,0,93.75,0.13,'platinum','Ramesh K','active',48000,null),
  ('Apollo Jubilee Hills','Hyderabad','2026-06-01'::date,8,16,14,2,0,87.50,0.25,'gold','Ramesh K','active',48000,null),
  ('KIMS Secunderabad','Hyderabad','2026-05-01'::date,12,24,22,2,0,91.66,0.17,'platinum','Sunita R','active',62000,null),
  ('KIMS Secunderabad','Hyderabad','2026-06-01'::date,12,24,20,4,0,83.33,0.42,'gold','Sunita R','active',62000,null),
  ('Manipal Whitefield','Bangalore','2026-05-01'::date,6,12,9,2,1,75.00,0.83,'silver','Akhil P','active',38000,null),
  ('Manipal Whitefield','Bangalore','2026-06-01'::date,6,12,8,2,2,66.66,1.42,'watchlist','Akhil P','renewal_due',38000,'2 missed jun5+jun18'),
  ('Fortis BG Road','Bangalore','2026-05-01'::date,7,14,13,1,0,92.85,0.07,'platinum','Vikram S','active',44000,null),
  ('Fortis BG Road','Bangalore','2026-06-01'::date,7,14,12,2,0,85.71,0.21,'gold','Vikram S','active',44000,null),
  ('Yashoda Somajiguda','Hyderabad','2026-05-01'::date,10,20,16,3,1,80.00,0.65,'silver','Sunita R','active',55000,null),
  ('Yashoda Somajiguda','Hyderabad','2026-06-01'::date,10,20,15,4,1,75.00,0.95,'silver','Sunita R','active',55000,'combo SKU shortage'),
  ('Continental Gachibowli','Hyderabad','2026-05-01'::date,9,18,18,0,0,100.00,0.00,'platinum','Ramesh K','active',52000,null),
  ('Continental Gachibowli','Hyderabad','2026-06-01'::date,9,18,17,1,0,94.44,0.11,'platinum','Ramesh K','active',52000,null),
  ('Rainbow Vikrampuri','Hyderabad','2026-05-01'::date,5,10,10,0,0,100.00,0.00,'platinum','Ramesh K','active',32000,null),
  ('Rainbow Vikrampuri','Hyderabad','2026-06-01'::date,5,10,9,1,0,90.00,0.10,'gold','Ramesh K','active',32000,null),
  ('AIG Gachibowli','Hyderabad','2026-05-01'::date,11,22,20,2,0,90.90,0.18,'platinum','Akhil P','active',58000,null),
  ('AIG Gachibowli','Hyderabad','2026-06-01'::date,11,22,17,4,1,77.27,0.86,'silver','Akhil P','active',58000,'engineer reassigned'),
  ('Care Banjara','Hyderabad','2026-05-01'::date,6,12,11,1,0,91.66,0.17,'platinum','Vikram S','active',36000,null),
  ('Care Banjara','Hyderabad','2026-06-01'::date,6,12,10,2,0,83.33,0.33,'gold','Vikram S','grace',36000,'amc grace 14d'),
  ('Sakra World','Bangalore','2026-05-01'::date,7,14,12,2,0,85.71,0.28,'gold','Akhil P','active',42000,null),
  ('Sakra World','Bangalore','2026-06-01'::date,7,14,11,3,0,78.57,0.57,'silver','Akhil P','active',42000,null);

-- ============================================================
-- RPC 1: portfolio summary
-- ============================================================
create or replace function public.r3028_portfolio_summary()
returns table (
  total_replacements int,
  on_time_count int,
  late_count int,
  missed_count int,
  upcoming_count int,
  compliance_pct numeric,
  total_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where compliance_status = 'on_time'))::int,
    (count(*) filter (where compliance_status = 'late'))::int,
    (count(*) filter (where compliance_status = 'missed'))::int,
    (count(*) filter (where compliance_status = 'upcoming'))::int,
    round(
      100.0 * (count(*) filter (where compliance_status = 'on_time'))::numeric
      / nullif((count(*) filter (where compliance_status in ('on_time','late','missed')))::numeric, 0),
      2
    ),
    coalesce(sum(cost_rupees),0)::bigint
  from public.smoke_evac_filter_replacements_r3028;
end;
$$;
revoke all on function public.r3028_portfolio_summary() from public, anon;
grant execute on function public.r3028_portfolio_summary() to authenticated;

-- ============================================================
-- RPC 2: city breakdown
-- ============================================================
create or replace function public.r3028_city_breakdown()
returns table (
  hospital_city text,
  filters_due int,
  on_time int,
  late int,
  missed int,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    f.hospital_city,
    count(*)::int,
    (count(*) filter (where f.compliance_status = 'on_time'))::int,
    (count(*) filter (where f.compliance_status = 'late'))::int,
    (count(*) filter (where f.compliance_status = 'missed'))::int,
    round(
      100.0 * (count(*) filter (where f.compliance_status = 'on_time'))::numeric
      / nullif((count(*) filter (where f.compliance_status in ('on_time','late','missed')))::numeric, 0),
      2
    )
  from public.smoke_evac_filter_replacements_r3028 f
  group by f.hospital_city
  order by f.hospital_city;
end;
$$;
revoke all on function public.r3028_city_breakdown() from public, anon;
grant execute on function public.r3028_city_breakdown() to authenticated;

-- ============================================================
-- RPC 3: overdue queue
-- ============================================================
create or replace function public.r3028_overdue_queue()
returns table (
  hospital_name text,
  ot_room_label text,
  evacuator_unit_serial text,
  filter_type text,
  scheduled_for date,
  delay_days int,
  compliance_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    f.hospital_name,
    f.ot_room_label,
    f.evacuator_unit_serial,
    f.filter_type,
    f.scheduled_for,
    f.delay_days,
    f.compliance_status
  from public.smoke_evac_filter_replacements_r3028 f
  where f.compliance_status in ('missed','late','in_progress')
  order by f.delay_days desc, f.scheduled_for asc;
end;
$$;
revoke all on function public.r3028_overdue_queue() from public, anon;
grant execute on function public.r3028_overdue_queue() to authenticated;

-- ============================================================
-- RPC 4: engineer leaderboard
-- ============================================================
create or replace function public.r3028_engineer_leaderboard()
returns table (
  engineer_name text,
  completed int,
  on_time int,
  late int,
  on_time_pct numeric,
  avg_saturation numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    coalesce(f.replaced_by_engineer,'(unassigned)')::text,
    count(*)::int,
    (count(*) filter (where f.compliance_status = 'on_time'))::int,
    (count(*) filter (where f.compliance_status = 'late'))::int,
    round(
      100.0 * (count(*) filter (where f.compliance_status = 'on_time'))::numeric
      / nullif(count(*)::numeric, 0),
      2
    ),
    round(avg(f.saturation_pct), 2)
  from public.smoke_evac_filter_replacements_r3028 f
  where f.replaced_at is not null
  group by coalesce(f.replaced_by_engineer,'(unassigned)')
  order by count(*) desc;
end;
$$;
revoke all on function public.r3028_engineer_leaderboard() from public, anon;
grant execute on function public.r3028_engineer_leaderboard() to authenticated;

-- ============================================================
-- RPC 5: filter type mix
-- ============================================================
create or replace function public.r3028_filter_type_mix()
returns table (
  filter_type text,
  swaps int,
  avg_hours_used numeric,
  avg_saturation numeric,
  total_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    f.filter_type,
    count(*)::int,
    round(avg(f.hours_used), 2),
    round(avg(f.saturation_pct), 2),
    coalesce(sum(f.cost_rupees),0)::bigint
  from public.smoke_evac_filter_replacements_r3028 f
  group by f.filter_type
  order by count(*) desc;
end;
$$;
revoke all on function public.r3028_filter_type_mix() from public, anon;
grant execute on function public.r3028_filter_type_mix() to authenticated;

-- ============================================================
-- RPC 6: hospital scorecard latest month
-- ============================================================
create or replace function public.r3028_hospital_scorecard_latest()
returns table (
  hospital_name text,
  hospital_city text,
  scorecard_month date,
  total_filters_due int,
  on_time_count int,
  late_count int,
  missed_count int,
  compliance_pct numeric,
  tier_label text,
  amc_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    s.hospital_name,
    s.hospital_city,
    s.scorecard_month,
    s.total_filters_due,
    s.on_time_count,
    s.late_count,
    s.missed_count,
    s.compliance_pct,
    s.tier_label,
    s.amc_status
  from public.smoke_evac_hospital_scorecard_r3028 s
  where s.scorecard_month = (select max(scorecard_month) from public.smoke_evac_hospital_scorecard_r3028)
  order by s.compliance_pct desc;
end;
$$;
revoke all on function public.r3028_hospital_scorecard_latest() from public, anon;
grant execute on function public.r3028_hospital_scorecard_latest() to authenticated;

-- ============================================================
-- RPC 7: watchlist hospitals (declining compliance or amc risk)
-- ============================================================
create or replace function public.r3028_watchlist_hospitals()
returns table (
  hospital_name text,
  hospital_city text,
  tier_label text,
  amc_status text,
  compliance_pct numeric,
  avg_delay_days numeric,
  missed_count int,
  monthly_fee_rupees int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    s.hospital_name,
    s.hospital_city,
    s.tier_label,
    s.amc_status,
    s.compliance_pct,
    s.avg_delay_days,
    s.missed_count,
    s.monthly_fee_rupees,
    s.notes
  from public.smoke_evac_hospital_scorecard_r3028 s
  where s.scorecard_month = (select max(scorecard_month) from public.smoke_evac_hospital_scorecard_r3028)
    and (s.tier_label in ('silver','bronze','watchlist')
         or s.amc_status in ('renewal_due','expired','grace')
         or s.compliance_pct < 85)
  order by s.compliance_pct asc;
end;
$$;
revoke all on function public.r3028_watchlist_hospitals() from public, anon;
grant execute on function public.r3028_watchlist_hospitals() to authenticated;
