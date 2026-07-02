-- Round r2992 — Wayfinding & Signage Damage Spotting
-- HEAVY ★★★★ — 2 tables + 7 RPCs + seeds

begin;

-- ============================================================
-- Table 1: signage_damage_reports_r2992
-- ============================================================
create table if not exists public.signage_damage_reports_r2992 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  hospital_city text not null,
  reception_zone text not null check (reception_zone in ('main_entrance','opd_lobby','ipd_lobby','emergency_bay','pharmacy_counter','radiology_wing','pediatrics_wing','cafeteria','exit_marker')),
  signage_type text not null check (signage_type in ('directional_arrow','room_label','floor_map','digital_kiosk','illuminated_box','wall_decal','overhead_panel','exit_marker')),
  damage_severity text not null check (damage_severity in ('cosmetic','minor','moderate','severe','critical')),
  damage_kind text not null check (damage_kind in ('scratched','faded','cracked','peeling','unlit','missing_letters','vandalized','water_damaged')),
  spotted_by_engineer_name text not null,
  spotted_on_visit_date date not null,
  patron_complaints_30d int not null check (patron_complaints_30d between 0 and 500),
  wayfinding_confusion_score int not null check (wayfinding_confusion_score between 0 and 100),
  replacement_cost_rupees int not null check (replacement_cost_rupees between 500 and 250000),
  repair_priority int not null check (repair_priority between 1 and 5),
  status text not null default 'spotted' check (status in ('spotted','quoted','approved','in_repair','resolved','deferred'))
);

alter table public.signage_damage_reports_r2992 enable row level security;

drop policy if exists founder_all_signage_damage_reports_r2992 on public.signage_damage_reports_r2992;
create policy founder_all_signage_damage_reports_r2992 on public.signage_damage_reports_r2992
  for all to authenticated using (is_founder()) with check (is_founder());

revoke all on public.signage_damage_reports_r2992 from public, anon;
grant select on public.signage_damage_reports_r2992 to authenticated;

-- ============================================================
-- Table 2: monthly_engineer_walkthrough_audits_r2992
-- ============================================================
create table if not exists public.monthly_engineer_walkthrough_audits_r2992 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  engineer_name text not null,
  engineer_region text not null check (engineer_region in ('hyderabad_central','hyderabad_west','secunderabad','bangalore_north','bangalore_south','chennai_north','chennai_south','mumbai_west')),
  audit_month date not null,
  hospitals_walked int not null check (hospitals_walked between 1 and 60),
  signage_items_inspected int not null check (signage_items_inspected between 5 and 800),
  damage_items_logged int not null check (damage_items_logged between 0 and 200),
  photos_attached int not null check (photos_attached between 0 and 600),
  wayfinding_score_avg int not null check (wayfinding_score_avg between 0 and 100),
  reception_wayfinding_rating int not null check (reception_wayfinding_rating between 1 and 10),
  customer_signoff_obtained boolean not null default false,
  total_replacement_estimate_rupees int not null check (total_replacement_estimate_rupees between 0 and 5000000),
  audit_status text not null check (audit_status in ('scheduled','in_progress','submitted','founder_review','approved','customer_shared'))
);

alter table public.monthly_engineer_walkthrough_audits_r2992 enable row level security;

drop policy if exists founder_all_monthly_engineer_walkthrough_audits_r2992 on public.monthly_engineer_walkthrough_audits_r2992;
create policy founder_all_monthly_engineer_walkthrough_audits_r2992 on public.monthly_engineer_walkthrough_audits_r2992
  for all to authenticated using (is_founder()) with check (is_founder());

revoke all on public.monthly_engineer_walkthrough_audits_r2992 from public, anon;
grant select on public.monthly_engineer_walkthrough_audits_r2992 to authenticated;

-- ============================================================
-- Seeds: signage_damage_reports_r2992 (20 rows)
-- ============================================================
insert into public.signage_damage_reports_r2992
  (hospital_name, hospital_city, reception_zone, signage_type, damage_severity, damage_kind, spotted_by_engineer_name, spotted_on_visit_date, patron_complaints_30d, wayfinding_confusion_score, replacement_cost_rupees, repair_priority, status)
values
  ('Apollo Jubilee Hills','Hyderabad','main_entrance','illuminated_box','severe','unlit','Ravi Kumar','2026-06-01'::date,42,78,68000,1,'approved'),
  ('Yashoda Secunderabad','Hyderabad','opd_lobby','directional_arrow','moderate','faded','Priya Sharma','2026-06-02'::date,18,55,12500,3,'quoted'),
  ('KIMS Kondapur','Hyderabad','ipd_lobby','floor_map','minor','scratched','Arun Reddy','2026-06-03'::date,7,32,8000,4,'spotted'),
  ('Continental Gachibowli','Hyderabad','emergency_bay','overhead_panel','critical','cracked','Suresh Naidu','2026-06-04'::date,89,95,145000,1,'in_repair'),
  ('Care Banjara Hills','Hyderabad','pharmacy_counter','room_label','cosmetic','peeling','Lakshmi Devi','2026-06-05'::date,3,15,2500,5,'deferred'),
  ('Manipal Whitefield','Bangalore','radiology_wing','digital_kiosk','severe','unlit','Karthik Iyer','2026-06-06'::date,56,82,185000,1,'approved'),
  ('Fortis Cunningham','Bangalore','main_entrance','wall_decal','moderate','vandalized','Deepa Menon','2026-06-07'::date,22,48,15000,3,'quoted'),
  ('Sakra World HSR','Bangalore','pediatrics_wing','illuminated_box','minor','water_damaged','Vivek Hegde','2026-06-08'::date,11,38,22000,4,'spotted'),
  ('Narayana Bommasandra','Bangalore','exit_marker'::text,'exit_marker','critical','missing_letters','Anjali Pillai','2026-06-09'::date,67,88,9500,1,'in_repair'),
  ('Aster CMI Hebbal','Bangalore','cafeteria','room_label','cosmetic','faded','Rohit Bhat','2026-06-10'::date,2,12,3200,5,'resolved'),
  ('Apollo Greams Road','Chennai','main_entrance','directional_arrow','severe','cracked','Mohan Subramanian','2026-06-11'::date,48,75,28000,2,'approved'),
  ('MIOT Manapakkam','Chennai','opd_lobby','overhead_panel','moderate','unlit','Geetha Krishnan','2026-06-12'::date,19,52,72000,3,'quoted'),
  ('Kauvery Alwarpet','Chennai','ipd_lobby','floor_map','minor','peeling','Bala Murugan','2026-06-13'::date,9,28,6800,4,'spotted'),
  ('Gleneagles Perumbakkam','Chennai','radiology_wing','digital_kiosk','critical','vandalized','Saranya Devi','2026-06-14'::date,71,91,210000,1,'in_repair'),
  ('Lilavati Bandra','Mumbai','emergency_bay','illuminated_box','severe','water_damaged','Nikhil Patel','2026-06-15'::date,53,80,98000,1,'approved'),
  ('Hinduja Mahim','Mumbai','pharmacy_counter','wall_decal','moderate','scratched','Anita Joshi','2026-06-16'::date,16,44,8500,3,'quoted'),
  ('Kokilaben Andheri','Mumbai','pediatrics_wing','room_label','minor','faded','Sanjay Kulkarni','2026-06-17'::date,6,22,4200,4,'spotted'),
  ('Nanavati Vile Parle','Mumbai','cafeteria','overhead_panel','cosmetic','peeling','Meera Rao','2026-06-18'::date,1,8,1800,5,'resolved'),
  ('Apollo Health City','Hyderabad','main_entrance','digital_kiosk','critical','unlit','Ravi Kumar','2026-06-19'::date,82,93,225000,1,'in_repair'),
  ('Yashoda Malakpet','Hyderabad','opd_lobby','floor_map','moderate','cracked','Priya Sharma','2026-06-20'::date,24,58,18000,2,'quoted');

-- ============================================================
-- Seeds: monthly_engineer_walkthrough_audits_r2992 (16 rows)
-- ============================================================
insert into public.monthly_engineer_walkthrough_audits_r2992
  (engineer_name, engineer_region, audit_month, hospitals_walked, signage_items_inspected, damage_items_logged, photos_attached, wayfinding_score_avg, reception_wayfinding_rating, customer_signoff_obtained, total_replacement_estimate_rupees, audit_status)
values
  ('Ravi Kumar','hyderabad_central','2026-04-01'::date,12,420,38,156,68,7,true,485000,'customer_shared'),
  ('Ravi Kumar','hyderabad_central','2026-05-01'::date,14,478,42,182,72,8,true,520000,'approved'),
  ('Ravi Kumar','hyderabad_central','2026-06-01'::date,15,512,48,210,74,8,false,612000,'founder_review'),
  ('Priya Sharma','hyderabad_west','2026-04-01'::date,9,285,22,98,71,7,true,285000,'customer_shared'),
  ('Priya Sharma','hyderabad_west','2026-05-01'::date,11,342,28,124,73,8,true,348000,'approved'),
  ('Priya Sharma','hyderabad_west','2026-06-01'::date,12,378,32,142,75,8,false,395000,'submitted'),
  ('Arun Reddy','secunderabad','2026-05-01'::date,10,298,24,108,69,7,true,268000,'approved'),
  ('Arun Reddy','secunderabad','2026-06-01'::date,11,328,29,128,71,7,false,312000,'in_progress'),
  ('Karthik Iyer','bangalore_north','2026-05-01'::date,13,445,41,168,70,8,true,492000,'customer_shared'),
  ('Karthik Iyer','bangalore_north','2026-06-01'::date,14,478,45,184,72,8,false,548000,'founder_review'),
  ('Deepa Menon','bangalore_south','2026-05-01'::date,11,358,31,138,73,8,true,378000,'approved'),
  ('Deepa Menon','bangalore_south','2026-06-01'::date,12,388,34,152,74,8,false,418000,'submitted'),
  ('Mohan Subramanian','chennai_north','2026-05-01'::date,12,402,36,148,71,7,true,425000,'customer_shared'),
  ('Mohan Subramanian','chennai_north','2026-06-01'::date,13,438,39,162,73,8,false,468000,'founder_review'),
  ('Nikhil Patel','mumbai_west','2026-05-01'::date,10,312,27,118,72,8,true,328000,'approved'),
  ('Nikhil Patel','mumbai_west','2026-06-01'::date,11,348,30,134,74,8,false,372000,'scheduled');

-- ============================================================
-- RPC 1: damage reports by severity
-- ============================================================
create or replace function public.r2992_damage_by_severity()
returns table (
  damage_severity text,
  report_count int,
  total_replacement_rupees bigint,
  avg_confusion_score numeric,
  total_complaints int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    s.damage_severity,
    count(*)::int as report_count,
    sum(s.replacement_cost_rupees)::bigint as total_replacement_rupees,
    round(avg(s.wayfinding_confusion_score)::numeric, 1) as avg_confusion_score,
    sum(s.patron_complaints_30d)::int as total_complaints
  from public.signage_damage_reports_r2992 s
  group by s.damage_severity
  order by total_replacement_rupees desc;
end;
$$;

revoke all on function public.r2992_damage_by_severity() from public, anon;
grant execute on function public.r2992_damage_by_severity() to authenticated;

-- ============================================================
-- RPC 2: reception zone hotspots
-- ============================================================
create or replace function public.r2992_zone_hotspots()
returns table (
  reception_zone text,
  damage_count int,
  critical_count int,
  total_estimate_rupees bigint,
  avg_priority numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    s.reception_zone,
    count(*)::int as damage_count,
    (count(*) filter (where s.damage_severity = 'critical'))::int as critical_count,
    sum(s.replacement_cost_rupees)::bigint as total_estimate_rupees,
    round(avg(s.repair_priority)::numeric, 2) as avg_priority
  from public.signage_damage_reports_r2992 s
  group by s.reception_zone
  order by critical_count desc, total_estimate_rupees desc;
end;
$$;

revoke all on function public.r2992_zone_hotspots() from public, anon;
grant execute on function public.r2992_zone_hotspots() to authenticated;

-- ============================================================
-- RPC 3: open repair pipeline
-- ============================================================
create or replace function public.r2992_open_repair_pipeline()
returns table (
  hospital_name text,
  hospital_city text,
  reception_zone text,
  signage_type text,
  damage_severity text,
  replacement_cost_rupees int,
  repair_priority int,
  status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    s.hospital_name,
    s.hospital_city,
    s.reception_zone,
    s.signage_type,
    s.damage_severity,
    s.replacement_cost_rupees,
    s.repair_priority,
    s.status
  from public.signage_damage_reports_r2992 s
  where s.status in ('spotted','quoted','approved','in_repair')
  order by s.repair_priority asc, s.replacement_cost_rupees desc;
end;
$$;

revoke all on function public.r2992_open_repair_pipeline() from public, anon;
grant execute on function public.r2992_open_repair_pipeline() to authenticated;

-- ============================================================
-- RPC 4: engineer monthly leaderboard
-- ============================================================
create or replace function public.r2992_engineer_leaderboard()
returns table (
  engineer_name text,
  engineer_region text,
  audits_count int,
  total_hospitals_walked int,
  total_items_inspected int,
  total_damage_logged int,
  avg_wayfinding_score numeric,
  signoffs_obtained int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    m.engineer_name,
    m.engineer_region,
    count(*)::int as audits_count,
    sum(m.hospitals_walked)::int as total_hospitals_walked,
    sum(m.signage_items_inspected)::int as total_items_inspected,
    sum(m.damage_items_logged)::int as total_damage_logged,
    round(avg(m.wayfinding_score_avg)::numeric, 1) as avg_wayfinding_score,
    (count(*) filter (where m.customer_signoff_obtained))::int as signoffs_obtained
  from public.monthly_engineer_walkthrough_audits_r2992 m
  group by m.engineer_name, m.engineer_region
  order by total_damage_logged desc;
end;
$$;

revoke all on function public.r2992_engineer_leaderboard() from public, anon;
grant execute on function public.r2992_engineer_leaderboard() to authenticated;

-- ============================================================
-- RPC 5: month-over-month walkthrough trend
-- ============================================================
create or replace function public.r2992_walkthrough_monthly_trend()
returns table (
  audit_month date,
  audit_count int,
  hospitals_total int,
  items_inspected int,
  damage_logged int,
  total_estimate_rupees bigint,
  customer_shared_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    m.audit_month,
    count(*)::int as audit_count,
    sum(m.hospitals_walked)::int as hospitals_total,
    sum(m.signage_items_inspected)::int as items_inspected,
    sum(m.damage_items_logged)::int as damage_logged,
    sum(m.total_replacement_estimate_rupees)::bigint as total_estimate_rupees,
    (count(*) filter (where m.audit_status = 'customer_shared'))::int as customer_shared_count
  from public.monthly_engineer_walkthrough_audits_r2992 m
  group by m.audit_month
  order by m.audit_month asc;
end;
$$;

revoke all on function public.r2992_walkthrough_monthly_trend() from public, anon;
grant execute on function public.r2992_walkthrough_monthly_trend() to authenticated;

-- ============================================================
-- RPC 6: damage kind breakdown
-- ============================================================
create or replace function public.r2992_damage_kind_breakdown()
returns table (
  damage_kind text,
  signage_type text,
  occurrences int,
  avg_cost_rupees numeric,
  worst_confusion_score int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    s.damage_kind,
    s.signage_type,
    count(*)::int as occurrences,
    round(avg(s.replacement_cost_rupees)::numeric, 0) as avg_cost_rupees,
    max(s.wayfinding_confusion_score)::int as worst_confusion_score
  from public.signage_damage_reports_r2992 s
  group by s.damage_kind, s.signage_type
  order by occurrences desc, avg_cost_rupees desc;
end;
$$;

revoke all on function public.r2992_damage_kind_breakdown() from public, anon;
grant execute on function public.r2992_damage_kind_breakdown() to authenticated;

-- ============================================================
-- RPC 7: founder summary KPIs
-- ============================================================
create or replace function public.r2992_founder_summary()
returns table (
  total_damage_reports int,
  critical_open_count int,
  pipeline_estimate_rupees bigint,
  unique_hospitals int,
  active_engineers int,
  audits_in_review int,
  avg_reception_rating numeric,
  total_patron_complaints int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'founder only';
  end if;
  return query
  select
    (select count(*)::int from public.signage_damage_reports_r2992) as total_damage_reports,
    (select count(*)::int from public.signage_damage_reports_r2992 where damage_severity = 'critical' and status in ('spotted','quoted','approved','in_repair')) as critical_open_count,
    (select coalesce(sum(replacement_cost_rupees),0)::bigint from public.signage_damage_reports_r2992 where status in ('spotted','quoted','approved','in_repair')) as pipeline_estimate_rupees,
    (select count(distinct hospital_name)::int from public.signage_damage_reports_r2992) as unique_hospitals,
    (select count(distinct engineer_name)::int from public.monthly_engineer_walkthrough_audits_r2992) as active_engineers,
    (select count(*)::int from public.monthly_engineer_walkthrough_audits_r2992 where audit_status = 'founder_review') as audits_in_review,
    (select round(avg(reception_wayfinding_rating)::numeric, 2) from public.monthly_engineer_walkthrough_audits_r2992) as avg_reception_rating,
    (select coalesce(sum(patron_complaints_30d),0)::int from public.signage_damage_reports_r2992) as total_patron_complaints;
end;
$$;

revoke all on function public.r2992_founder_summary() from public, anon;
grant execute on function public.r2992_founder_summary() to authenticated;

commit;
