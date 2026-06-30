-- Round r3076 — Customer Monthly Engineer Hospital Floor-Cleaning Robot Battery & Path Coverage Audit
-- Two tables (_r3076) + 7 founder-gated RPCs + seed rows.

create extension if not exists pgcrypto;

-- ============================================================================
-- TABLE 1: robot_battery_audits_r3076
-- ============================================================================
create table if not exists public.robot_battery_audits_r3076 (
  id uuid primary key default gen_random_uuid(),
  hospital_code text not null,
  floor_label text not null,
  robot_serial text not null,
  audit_month date not null,
  engineer_name text not null,
  battery_health_pct numeric(5,2) not null,
  cycle_count int not null,
  runtime_minutes int not null,
  charge_time_minutes int not null,
  battery_status text not null check (battery_status in ('healthy','degrading','replace_soon','replace_now','critical')),
  replacement_recommended boolean not null default false,
  next_audit_due date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.robot_battery_audits_r3076 enable row level security;

drop policy if exists r3076_battery_select on public.robot_battery_audits_r3076;
create policy r3076_battery_select on public.robot_battery_audits_r3076
  for select to authenticated using (public.is_founder());

revoke all on public.robot_battery_audits_r3076 from public, anon;
grant select on public.robot_battery_audits_r3076 to authenticated;

insert into public.robot_battery_audits_r3076
  (hospital_code, floor_label, robot_serial, audit_month, engineer_name, battery_health_pct, cycle_count, runtime_minutes, charge_time_minutes, battery_status, replacement_recommended, next_audit_due, notes)
values
  ('APOLLO-HYD','Floor-1-OPD','RBT-A1-001','2026-06-01'::date,'Ravi Kumar',94.50,142,185,92,'healthy',false,'2026-07-01'::date,'Within spec'),
  ('APOLLO-HYD','Floor-2-ICU','RBT-A1-002','2026-06-01'::date,'Ravi Kumar',88.20,287,168,98,'healthy',false,'2026-07-01'::date,'Minor degrade'),
  ('APOLLO-HYD','Floor-3-Ward','RBT-A1-003','2026-06-01'::date,'Suresh Patel',76.40,512,142,115,'degrading',false,'2026-07-01'::date,'Monitor next cycle'),
  ('FORTIS-BLR','Floor-1-ER','RBT-F2-001','2026-06-01'::date,'Anita Sharma',91.80,198,178,94,'healthy',false,'2026-07-01'::date,'Normal operation'),
  ('FORTIS-BLR','Floor-2-OT','RBT-F2-002','2026-06-01'::date,'Anita Sharma',82.10,402,156,108,'degrading',false,'2026-07-01'::date,'Schedule check'),
  ('FORTIS-BLR','Floor-3-Pharmacy','RBT-F2-003','2026-06-01'::date,'Vikram Singh',68.50,687,128,132,'replace_soon',true,'2026-07-01'::date,'Plan Q3 replacement'),
  ('MAX-DEL','Floor-1-Lobby','RBT-M3-001','2026-06-01'::date,'Priya Nair',95.20,108,192,88,'healthy',false,'2026-07-01'::date,'Excellent'),
  ('MAX-DEL','Floor-2-ICU','RBT-M3-002','2026-06-01'::date,'Priya Nair',58.30,812,98,158,'replace_now',true,'2026-06-15'::date,'URGENT replacement'),
  ('MEDANTA-GGN','Floor-1-OPD','RBT-MD-001','2026-06-01'::date,'Arjun Reddy',89.40,243,172,96,'healthy',false,'2026-07-01'::date,'Within tolerance'),
  ('MEDANTA-GGN','Floor-2-Ward','RBT-MD-002','2026-06-01'::date,'Arjun Reddy',45.20,1024,68,182,'critical',true,'2026-06-08'::date,'IMMEDIATE swap required'),
  ('KIMS-HYD','Floor-1-Reception','RBT-K4-001','2026-06-01'::date,'Sneha Iyer',92.80,178,184,90,'healthy',false,'2026-07-01'::date,'OK'),
  ('KIMS-HYD','Floor-2-OT','RBT-K4-002','2026-06-01'::date,'Sneha Iyer',79.60,456,148,112,'degrading',false,'2026-07-01'::date,'Watch closely'),
  ('AIIMS-DEL','Floor-1-Ward-A','RBT-AI-001','2026-06-01'::date,'Manoj Verma',86.70,312,164,102,'healthy',false,'2026-07-01'::date,'Stable'),
  ('AIIMS-DEL','Floor-2-Ward-B','RBT-AI-002','2026-06-01'::date,'Manoj Verma',71.30,598,134,124,'degrading',true,'2026-07-01'::date,'Order replacement'),
  ('CMC-VLR','Floor-1-OPD','RBT-CM-001','2026-06-01'::date,'Latha Krishnan',93.10,165,188,92,'healthy',false,'2026-07-01'::date,'Good'),
  ('CMC-VLR','Floor-2-Lab','RBT-CM-002','2026-06-01'::date,'Latha Krishnan',62.80,742,108,144,'replace_soon',true,'2026-07-01'::date,'Procurement initiated'),
  ('TATA-MUM','Floor-1-Oncology','RBT-T5-001','2026-06-01'::date,'Deepak Joshi',90.50,221,176,95,'healthy',false,'2026-07-01'::date,'Fine'),
  ('TATA-MUM','Floor-2-Chemo','RBT-T5-002','2026-06-01'::date,'Deepak Joshi',54.20,892,82,168,'replace_now',true,'2026-06-10'::date,'Battery swap booked'),
  ('NIMHANS-BLR','Floor-1-OPD','RBT-N6-001','2026-06-01'::date,'Geeta Rao',87.90,265,170,98,'healthy',false,'2026-07-01'::date,'OK'),
  ('NIMHANS-BLR','Floor-2-Ward','RBT-N6-002','2026-06-01'::date,'Geeta Rao',73.40,524,138,118,'degrading',false,'2026-07-01'::date,'Track usage');

-- ============================================================================
-- TABLE 2: robot_path_coverage_r3076
-- ============================================================================
create table if not exists public.robot_path_coverage_r3076 (
  id uuid primary key default gen_random_uuid(),
  hospital_code text not null,
  floor_label text not null,
  robot_serial text not null,
  audit_month date not null,
  zone_name text not null,
  planned_area_sqm numeric(8,2) not null,
  covered_area_sqm numeric(8,2) not null,
  coverage_pct numeric(5,2) not null,
  missed_zones_count int not null default 0,
  obstacle_events int not null default 0,
  path_status text not null check (path_status in ('optimal','acceptable','suboptimal','poor','critical')),
  remap_recommended boolean not null default false,
  audited_by text,
  created_at timestamptz not null default now()
);

alter table public.robot_path_coverage_r3076 enable row level security;

drop policy if exists r3076_path_select on public.robot_path_coverage_r3076;
create policy r3076_path_select on public.robot_path_coverage_r3076
  for select to authenticated using (public.is_founder());

revoke all on public.robot_path_coverage_r3076 from public, anon;
grant select on public.robot_path_coverage_r3076 to authenticated;

insert into public.robot_path_coverage_r3076
  (hospital_code, floor_label, robot_serial, audit_month, zone_name, planned_area_sqm, covered_area_sqm, coverage_pct, missed_zones_count, obstacle_events, path_status, remap_recommended, audited_by)
values
  ('APOLLO-HYD','Floor-1-OPD','RBT-A1-001','2026-06-01'::date,'Reception',420.00,412.50,98.21,0,2,'optimal',false,'Ravi Kumar'),
  ('APOLLO-HYD','Floor-2-ICU','RBT-A1-002','2026-06-01'::date,'ICU-Corridor',310.00,295.80,95.42,1,4,'optimal',false,'Ravi Kumar'),
  ('APOLLO-HYD','Floor-3-Ward','RBT-A1-003','2026-06-01'::date,'Ward-3A',580.00,521.20,89.86,3,8,'acceptable',false,'Suresh Patel'),
  ('FORTIS-BLR','Floor-1-ER','RBT-F2-001','2026-06-01'::date,'ER-Lobby',390.00,378.30,96.99,1,3,'optimal',false,'Anita Sharma'),
  ('FORTIS-BLR','Floor-2-OT','RBT-F2-002','2026-06-01'::date,'OT-Prep',280.00,252.40,90.14,2,5,'acceptable',false,'Anita Sharma'),
  ('FORTIS-BLR','Floor-3-Pharmacy','RBT-F2-003','2026-06-01'::date,'Pharmacy-Aisle',180.00,142.20,79.00,4,12,'suboptimal',true,'Vikram Singh'),
  ('MAX-DEL','Floor-1-Lobby','RBT-M3-001','2026-06-01'::date,'Main-Lobby',640.00,632.20,98.78,0,1,'optimal',false,'Priya Nair'),
  ('MAX-DEL','Floor-2-ICU','RBT-M3-002','2026-06-01'::date,'ICU-North',340.00,232.10,68.26,7,18,'poor',true,'Priya Nair'),
  ('MEDANTA-GGN','Floor-1-OPD','RBT-MD-001','2026-06-01'::date,'OPD-Wing',510.00,489.40,95.96,1,3,'optimal',false,'Arjun Reddy'),
  ('MEDANTA-GGN','Floor-2-Ward','RBT-MD-002','2026-06-01'::date,'Ward-East',450.00,198.50,44.11,12,28,'critical',true,'Arjun Reddy'),
  ('KIMS-HYD','Floor-1-Reception','RBT-K4-001','2026-06-01'::date,'Reception-Hall',380.00,368.20,96.89,0,2,'optimal',false,'Sneha Iyer'),
  ('KIMS-HYD','Floor-2-OT','RBT-K4-002','2026-06-01'::date,'OT-Corridor',290.00,257.90,88.93,2,6,'acceptable',false,'Sneha Iyer'),
  ('AIIMS-DEL','Floor-1-Ward-A','RBT-AI-001','2026-06-01'::date,'Ward-A-Hall',620.00,581.40,93.77,2,5,'acceptable',false,'Manoj Verma'),
  ('AIIMS-DEL','Floor-2-Ward-B','RBT-AI-002','2026-06-01'::date,'Ward-B-Hall',590.00,478.30,81.07,5,11,'suboptimal',true,'Manoj Verma'),
  ('CMC-VLR','Floor-1-OPD','RBT-CM-001','2026-06-01'::date,'OPD-Block',470.00,452.80,96.34,1,3,'optimal',false,'Latha Krishnan'),
  ('CMC-VLR','Floor-2-Lab','RBT-CM-002','2026-06-01'::date,'Lab-Aisle',220.00,168.70,76.68,4,14,'suboptimal',true,'Latha Krishnan'),
  ('TATA-MUM','Floor-1-Oncology','RBT-T5-001','2026-06-01'::date,'Onco-Wing',410.00,394.20,96.15,1,3,'optimal',false,'Deepak Joshi'),
  ('TATA-MUM','Floor-2-Chemo','RBT-T5-002','2026-06-01'::date,'Chemo-Bay',350.00,212.40,60.69,8,22,'poor',true,'Deepak Joshi'),
  ('NIMHANS-BLR','Floor-1-OPD','RBT-N6-001','2026-06-01'::date,'OPD-South',430.00,418.90,97.42,1,2,'optimal',false,'Geeta Rao'),
  ('NIMHANS-BLR','Floor-2-Ward','RBT-N6-002','2026-06-01'::date,'Ward-Central',520.00,463.80,89.19,3,7,'acceptable',false,'Geeta Rao');

-- ============================================================================
-- RPC 1: fleet summary
-- ============================================================================
create or replace function public.r3076_fleet_summary()
returns table (
  total_robots int,
  hospitals_covered int,
  avg_battery_health numeric,
  avg_coverage_pct numeric,
  critical_batteries int,
  critical_paths int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    (select count(distinct robot_serial) from public.robot_battery_audits_r3076)::int,
    (select count(distinct hospital_code) from public.robot_battery_audits_r3076)::int,
    (select round(avg(battery_health_pct),2) from public.robot_battery_audits_r3076),
    (select round(avg(coverage_pct),2) from public.robot_path_coverage_r3076),
    (select (count(*) filter (where battery_status in ('replace_now','critical')))::int from public.robot_battery_audits_r3076),
    (select (count(*) filter (where path_status in ('poor','critical')))::int from public.robot_path_coverage_r3076);
end;
$$;

revoke all on function public.r3076_fleet_summary() from public, anon;
grant execute on function public.r3076_fleet_summary() to authenticated;

-- ============================================================================
-- RPC 2: battery status breakdown
-- ============================================================================
create or replace function public.r3076_battery_status_breakdown()
returns table (
  battery_status text,
  robot_count int,
  avg_health numeric,
  avg_cycles numeric,
  replacement_count int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    b.battery_status,
    count(*)::int,
    round(avg(b.battery_health_pct),2),
    round(avg(b.cycle_count),0),
    (count(*) filter (where b.replacement_recommended))::int
  from public.robot_battery_audits_r3076 b
  group by b.battery_status
  order by count(*) desc;
end;
$$;

revoke all on function public.r3076_battery_status_breakdown() from public, anon;
grant execute on function public.r3076_battery_status_breakdown() to authenticated;

-- ============================================================================
-- RPC 3: hospital scorecard
-- ============================================================================
create or replace function public.r3076_hospital_scorecard()
returns table (
  hospital_code text,
  robot_count int,
  avg_battery numeric,
  avg_coverage numeric,
  urgent_replacements int,
  remap_needed int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    b.hospital_code,
    count(distinct b.robot_serial)::int,
    round(avg(b.battery_health_pct),2),
    (select round(avg(p.coverage_pct),2) from public.robot_path_coverage_r3076 p where p.hospital_code = b.hospital_code),
    (count(*) filter (where b.battery_status in ('replace_now','critical')))::int,
    (select (count(*) filter (where p.remap_recommended))::int from public.robot_path_coverage_r3076 p where p.hospital_code = b.hospital_code)
  from public.robot_battery_audits_r3076 b
  group by b.hospital_code
  order by avg(b.battery_health_pct) asc;
end;
$$;

revoke all on function public.r3076_hospital_scorecard() from public, anon;
grant execute on function public.r3076_hospital_scorecard() to authenticated;

-- ============================================================================
-- RPC 4: engineer audit performance
-- ============================================================================
create or replace function public.r3076_engineer_performance()
returns table (
  engineer_name text,
  audits_completed int,
  avg_battery_audited numeric,
  flagged_robots int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    b.engineer_name,
    count(*)::int,
    round(avg(b.battery_health_pct),2),
    (count(*) filter (where b.replacement_recommended))::int
  from public.robot_battery_audits_r3076 b
  group by b.engineer_name
  order by count(*) desc;
end;
$$;

revoke all on function public.r3076_engineer_performance() from public, anon;
grant execute on function public.r3076_engineer_performance() to authenticated;

-- ============================================================================
-- RPC 5: urgent replacements queue
-- ============================================================================
create or replace function public.r3076_urgent_replacements()
returns table (
  hospital_code text,
  floor_label text,
  robot_serial text,
  battery_health_pct numeric,
  battery_status text,
  next_audit_due date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    b.hospital_code, b.floor_label, b.robot_serial,
    b.battery_health_pct, b.battery_status, b.next_audit_due, b.notes
  from public.robot_battery_audits_r3076 b
  where b.battery_status in ('replace_now','critical')
     or b.replacement_recommended = true
  order by b.battery_health_pct asc;
end;
$$;

revoke all on function public.r3076_urgent_replacements() from public, anon;
grant execute on function public.r3076_urgent_replacements() to authenticated;

-- ============================================================================
-- RPC 6: path coverage by status
-- ============================================================================
create or replace function public.r3076_path_status_breakdown()
returns table (
  path_status text,
  zone_count int,
  avg_coverage numeric,
  total_missed int,
  total_obstacles int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.path_status,
    count(*)::int,
    round(avg(p.coverage_pct),2),
    sum(p.missed_zones_count)::int,
    sum(p.obstacle_events)::int
  from public.robot_path_coverage_r3076 p
  group by p.path_status
  order by count(*) desc;
end;
$$;

revoke all on function public.r3076_path_status_breakdown() from public, anon;
grant execute on function public.r3076_path_status_breakdown() to authenticated;

-- ============================================================================
-- RPC 7: low coverage zones
-- ============================================================================
create or replace function public.r3076_low_coverage_zones()
returns table (
  hospital_code text,
  floor_label text,
  zone_name text,
  coverage_pct numeric,
  missed_zones_count int,
  obstacle_events int,
  path_status text,
  audited_by text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.hospital_code, p.floor_label, p.zone_name,
    p.coverage_pct, p.missed_zones_count, p.obstacle_events,
    p.path_status, p.audited_by
  from public.robot_path_coverage_r3076 p
  where p.coverage_pct < 90.00
  order by p.coverage_pct asc;
end;
$$;

revoke all on function public.r3076_low_coverage_zones() from public, anon;
grant execute on function public.r3076_low_coverage_zones() to authenticated;
