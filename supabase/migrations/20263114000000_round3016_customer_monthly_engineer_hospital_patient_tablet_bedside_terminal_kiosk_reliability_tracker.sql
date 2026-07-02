-- Round r3016 — Customer Monthly Engineer Hospital Patient-Tablet & Bedside-Terminal Kiosk Reliability Tracker

create table if not exists public.kiosk_devices_r3016 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_name text not null,
  city text not null,
  device_serial text not null unique,
  device_type text not null check (device_type in ('patient_tablet','bedside_terminal')),
  ward text not null,
  bed_count int not null check (bed_count between 1 and 200),
  install_month text not null,
  assigned_engineer text not null,
  uptime_pct numeric(5,2) not null check (uptime_pct between 0 and 100),
  incidents_30d int not null check (incidents_30d between 0 and 100),
  mttr_minutes int not null check (mttr_minutes between 0 and 2000),
  patient_sessions_30d int not null check (patient_sessions_30d between 0 and 100000),
  battery_health_pct int not null check (battery_health_pct between 0 and 100),
  os_version text not null,
  last_heartbeat_at timestamptz not null,
  status text not null check (status in ('healthy','degraded','offline','retired'))
);

create table if not exists public.kiosk_incidents_r3016 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  device_serial text not null,
  hospital_name text not null,
  opened_at timestamptz not null,
  resolved_at timestamptz,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  category text not null check (category in ('crash','battery','touchscreen','network','firmware','peripheral','os_lockup')),
  engineer text not null,
  resolution_minutes int check (resolution_minutes between 0 and 5000),
  patient_impact int not null check (patient_impact between 0 and 500),
  resolved boolean not null default false,
  root_cause text
);

alter table public.kiosk_devices_r3016 enable row level security;
alter table public.kiosk_incidents_r3016 enable row level security;

drop policy if exists kiosk_devices_r3016_founder on public.kiosk_devices_r3016;
create policy kiosk_devices_r3016_founder on public.kiosk_devices_r3016 for select to authenticated using (public.is_founder());

drop policy if exists kiosk_incidents_r3016_founder on public.kiosk_incidents_r3016;
create policy kiosk_incidents_r3016_founder on public.kiosk_incidents_r3016 for select to authenticated using (public.is_founder());

-- seed devices
insert into public.kiosk_devices_r3016 (hospital_name,city,device_serial,device_type,ward,bed_count,install_month,assigned_engineer,uptime_pct,incidents_30d,mttr_minutes,patient_sessions_30d,battery_health_pct,os_version,last_heartbeat_at,status) values
('Apollo Jubilee','Hyderabad','KT-APO-001','patient_tablet','ICU',24,'2026-01','Ravi K',99.40,1,18,2840,92,'Android 14','2026-06-21 09:10'::timestamptz,'healthy'),
('Apollo Jubilee','Hyderabad','KT-APO-002','bedside_terminal','Cardiology',30,'2026-01','Ravi K',98.10,3,42,1920,88,'Android 14','2026-06-21 09:12'::timestamptz,'healthy'),
('KIMS Secunderabad','Hyderabad','KT-KIM-001','patient_tablet','Oncology',18,'2026-02','Suresh M',97.20,5,68,2104,76,'Android 13','2026-06-21 09:05'::timestamptz,'degraded'),
('KIMS Secunderabad','Hyderabad','KT-KIM-002','bedside_terminal','ICU',28,'2026-02','Suresh M',99.80,0,12,1740,94,'Android 14','2026-06-21 09:08'::timestamptz,'healthy'),
('Fortis Bannerghatta','Bengaluru','KT-FOR-001','patient_tablet','Pediatrics',22,'2026-01','Priya N',96.40,7,94,3210,71,'Android 13','2026-06-21 08:50'::timestamptz,'degraded'),
('Fortis Bannerghatta','Bengaluru','KT-FOR-002','bedside_terminal','Neuro',20,'2026-03','Priya N',99.10,2,28,1480,90,'Android 14','2026-06-21 09:14'::timestamptz,'healthy'),
('Manipal Old Airport','Bengaluru','KT-MAN-001','patient_tablet','General',40,'2026-02','Karthik R',94.80,9,118,4120,68,'Android 13','2026-06-21 08:42'::timestamptz,'degraded'),
('Manipal Old Airport','Bengaluru','KT-MAN-002','bedside_terminal','ICU',26,'2026-02','Karthik R',99.60,1,16,1620,93,'Android 14','2026-06-21 09:11'::timestamptz,'healthy'),
('Max Saket','Delhi','KT-MAX-001','patient_tablet','Cardiology',32,'2026-01','Neeraj T',98.50,2,34,2540,85,'Android 14','2026-06-21 09:03'::timestamptz,'healthy'),
('Max Saket','Delhi','KT-MAX-002','bedside_terminal','Oncology',24,'2026-03','Neeraj T',97.90,4,52,1830,81,'Android 14','2026-06-21 09:00'::timestamptz,'healthy'),
('Lilavati Bandra','Mumbai','KT-LIL-001','patient_tablet','ICU',20,'2026-02','Anita P',99.20,1,22,2160,89,'Android 14','2026-06-21 09:09'::timestamptz,'healthy'),
('Lilavati Bandra','Mumbai','KT-LIL-002','bedside_terminal','General',36,'2026-02','Anita P',92.10,12,180,3840,62,'Android 12','2026-06-21 07:30'::timestamptz,'offline'),
('Hinduja Mahim','Mumbai','KT-HIN-001','patient_tablet','Neuro',16,'2026-03','Rohit S',98.70,2,30,1420,86,'Android 14','2026-06-21 09:06'::timestamptz,'healthy'),
('Narayana Health','Bengaluru','KT-NAR-001','bedside_terminal','Cardiology',44,'2026-01','Karthik R',95.50,6,86,2980,73,'Android 13','2026-06-21 08:55'::timestamptz,'degraded'),
('AIIMS Delhi','Delhi','KT-AII-001','patient_tablet','Oncology',28,'2026-02','Neeraj T',99.00,2,24,2340,91,'Android 14','2026-06-21 09:13'::timestamptz,'healthy'),
('Medanta Gurgaon','Gurgaon','KT-MED-001','bedside_terminal','ICU',32,'2026-01','Vikram J',98.40,3,38,2080,87,'Android 14','2026-06-21 09:07'::timestamptz,'healthy'),
('CMC Vellore','Vellore','KT-CMC-001','patient_tablet','General',50,'2026-03','Deepa R',93.20,11,154,4520,64,'Android 13','2026-06-21 08:20'::timestamptz,'degraded'),
('Tata Memorial','Mumbai','KT-TAT-001','bedside_terminal','Oncology',38,'2026-02','Anita P',99.50,1,14,2680,92,'Android 14','2026-06-21 09:10'::timestamptz,'healthy'),
('Sankara Nethralaya','Chennai','KT-SAN-001','patient_tablet','Ophthalmology',12,'2026-03','Mahesh L',88.40,15,240,2840,54,'Android 12','2026-06-20 22:10'::timestamptz,'retired'),
('Christian Med College','Vellore','KT-CMC-002','bedside_terminal','Cardiology',26,'2026-02','Deepa R',97.60,4,56,1940,82,'Android 14','2026-06-21 09:02'::timestamptz,'healthy');

-- seed incidents
insert into public.kiosk_incidents_r3016 (device_serial,hospital_name,opened_at,resolved_at,severity,category,engineer,resolution_minutes,patient_impact,resolved,root_cause) values
('KT-LIL-002','Lilavati Bandra','2026-06-21 07:10'::timestamptz,null,'p0','os_lockup','Anita P',null,48,false,'Android 12 watchdog hang'),
('KT-MAN-001','Manipal Old Airport','2026-06-20 18:20'::timestamptz,'2026-06-20 20:40'::timestamptz,'p1','battery','Karthik R',140,24,true,'Battery swell — replaced'),
('KT-SAN-001','Sankara Nethralaya','2026-06-20 21:05'::timestamptz,null,'p0','crash','Mahesh L',null,32,false,'Repeat kernel panic — retire'),
('KT-CMC-001','CMC Vellore','2026-06-20 14:30'::timestamptz,'2026-06-20 17:00'::timestamptz,'p1','touchscreen','Deepa R',150,40,true,'Digitizer flex cable reseat'),
('KT-FOR-001','Fortis Bannerghatta','2026-06-19 11:00'::timestamptz,'2026-06-19 12:20'::timestamptz,'p2','network','Priya N',80,18,true,'WiFi cert rotation'),
('KT-KIM-001','KIMS Secunderabad','2026-06-19 09:45'::timestamptz,'2026-06-19 10:50'::timestamptz,'p2','firmware','Suresh M',65,12,true,'OTA rollback'),
('KT-NAR-001','Narayana Health','2026-06-18 16:10'::timestamptz,'2026-06-18 17:30'::timestamptz,'p2','peripheral','Karthik R',80,20,true,'Barcode reader USB'),
('KT-MAX-002','Max Saket','2026-06-18 10:00'::timestamptz,'2026-06-18 10:55'::timestamptz,'p3','crash','Neeraj T',55,8,true,'App memory leak v2.3.1'),
('KT-APO-002','Apollo Jubilee','2026-06-17 13:25'::timestamptz,'2026-06-17 14:10'::timestamptz,'p3','network','Ravi K',45,6,true,'Switch port flap'),
('KT-LIL-002','Lilavati Bandra','2026-06-16 22:00'::timestamptz,'2026-06-17 02:30'::timestamptz,'p0','os_lockup','Anita P',270,72,true,'Android 12 upgrade overdue'),
('KT-FOR-001','Fortis Bannerghatta','2026-06-15 15:20'::timestamptz,'2026-06-15 17:00'::timestamptz,'p2','battery','Priya N',100,16,true,'Battery <70%'),
('KT-MAN-001','Manipal Old Airport','2026-06-14 09:00'::timestamptz,'2026-06-14 11:30'::timestamptz,'p1','touchscreen','Karthik R',150,30,true,'Cracked digitizer'),
('KT-CMC-001','CMC Vellore','2026-06-13 18:00'::timestamptz,'2026-06-13 20:20'::timestamptz,'p1','firmware','Deepa R',140,28,true,'Bricked OTA — recovery'),
('KT-KIM-001','KIMS Secunderabad','2026-06-12 12:00'::timestamptz,'2026-06-12 13:10'::timestamptz,'p2','peripheral','Suresh M',70,14,true,'Charging dock'),
('KT-NAR-001','Narayana Health','2026-06-11 10:30'::timestamptz,'2026-06-11 12:00'::timestamptz,'p2','network','Karthik R',90,22,true,'DHCP exhaustion'),
('KT-MAX-001','Max Saket','2026-06-10 14:00'::timestamptz,'2026-06-10 14:35'::timestamptz,'p3','crash','Neeraj T',35,4,true,'EMR sync race'),
('KT-MED-001','Medanta Gurgaon','2026-06-09 16:00'::timestamptz,'2026-06-09 16:45'::timestamptz,'p3','peripheral','Vikram J',45,10,true,'Barcode firmware'),
('KT-CMC-002','Christian Med College','2026-06-08 11:00'::timestamptz,'2026-06-08 12:15'::timestamptz,'p2','battery','Deepa R',75,16,true,'Battery calibration'),
('KT-HIN-001','Hinduja Mahim','2026-06-07 09:30'::timestamptz,'2026-06-07 10:00'::timestamptz,'p3','network','Rohit S',30,5,true,'WiFi roaming'),
('KT-AII-001','AIIMS Delhi','2026-06-06 13:00'::timestamptz,'2026-06-06 13:25'::timestamptz,'p3','firmware','Neeraj T',25,3,true,'Patch v2.4.0');

-- RPCs

create or replace function public.kiosk_r3016_fleet_overview()
returns table(metric text, value numeric, detail text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select 'Total Devices'::text, count(*)::numeric, 'Across all hospitals'::text from public.kiosk_devices_r3016
  union all select 'Healthy', (count(*) filter (where status='healthy'))::numeric, 'Uptime >= 98%' from public.kiosk_devices_r3016
  union all select 'Degraded', (count(*) filter (where status='degraded'))::numeric, '90-98% uptime' from public.kiosk_devices_r3016
  union all select 'Offline/Retired', (count(*) filter (where status in ('offline','retired')))::numeric, 'Needs intervention' from public.kiosk_devices_r3016
  union all select 'Avg Uptime %', round(avg(uptime_pct)::numeric,2), 'Fleet-wide mean' from public.kiosk_devices_r3016
  union all select 'Avg MTTR (min)', round(avg(mttr_minutes)::numeric,1), 'Mean time to repair' from public.kiosk_devices_r3016;
end; $$;

create or replace function public.kiosk_r3016_by_hospital()
returns table(hospital_name text, devices int, avg_uptime numeric, total_incidents int, total_sessions int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.hospital_name, count(*)::int, round(avg(d.uptime_pct)::numeric,2),
    sum(d.incidents_30d)::int, sum(d.patient_sessions_30d)::int
  from public.kiosk_devices_r3016 d
  group by d.hospital_name
  order by avg(d.uptime_pct) asc;
end; $$;

create or replace function public.kiosk_r3016_by_engineer()
returns table(engineer text, devices int, avg_uptime numeric, incidents_handled int, avg_mttr numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.assigned_engineer, count(*)::int, round(avg(d.uptime_pct)::numeric,2),
    sum(d.incidents_30d)::int, round(avg(d.mttr_minutes)::numeric,1)
  from public.kiosk_devices_r3016 d
  group by d.assigned_engineer
  order by avg(d.uptime_pct) desc;
end; $$;

create or replace function public.kiosk_r3016_open_incidents()
returns table(device_serial text, hospital_name text, severity text, category text, engineer text, opened_at timestamptz, patient_impact int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.device_serial, i.hospital_name, i.severity, i.category, i.engineer, i.opened_at, i.patient_impact
  from public.kiosk_incidents_r3016 i
  where i.resolved = false
  order by case i.severity when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end, i.opened_at;
end; $$;

create or replace function public.kiosk_r3016_incident_categories()
returns table(category text, count_30d int, avg_resolution_min numeric, patient_impact_total int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.category, count(*)::int, round(avg(i.resolution_minutes)::numeric,1), sum(i.patient_impact)::int
  from public.kiosk_incidents_r3016 i
  group by i.category
  order by count(*) desc;
end; $$;

create or replace function public.kiosk_r3016_battery_risk()
returns table(device_serial text, hospital_name text, battery_health_pct int, os_version text, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.device_serial, d.hospital_name, d.battery_health_pct, d.os_version, d.status
  from public.kiosk_devices_r3016 d
  where d.battery_health_pct < 75
  order by d.battery_health_pct asc;
end; $$;

create or replace function public.kiosk_r3016_device_type_breakdown()
returns table(device_type text, devices int, avg_uptime numeric, total_sessions int, avg_battery int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.device_type, count(*)::int, round(avg(d.uptime_pct)::numeric,2),
    sum(d.patient_sessions_30d)::int, round(avg(d.battery_health_pct))::int
  from public.kiosk_devices_r3016 d
  group by d.device_type
  order by d.device_type;
end; $$;

revoke all on public.kiosk_devices_r3016 from public, anon;
revoke all on public.kiosk_incidents_r3016 from public, anon;
grant select on public.kiosk_devices_r3016 to authenticated;
grant select on public.kiosk_incidents_r3016 to authenticated;

revoke all on function public.kiosk_r3016_fleet_overview() from public, anon;
revoke all on function public.kiosk_r3016_by_hospital() from public, anon;
revoke all on function public.kiosk_r3016_by_engineer() from public, anon;
revoke all on function public.kiosk_r3016_open_incidents() from public, anon;
revoke all on function public.kiosk_r3016_incident_categories() from public, anon;
revoke all on function public.kiosk_r3016_battery_risk() from public, anon;
revoke all on function public.kiosk_r3016_device_type_breakdown() from public, anon;

grant execute on function public.kiosk_r3016_fleet_overview() to authenticated;
grant execute on function public.kiosk_r3016_by_hospital() to authenticated;
grant execute on function public.kiosk_r3016_by_engineer() to authenticated;
grant execute on function public.kiosk_r3016_open_incidents() to authenticated;
grant execute on function public.kiosk_r3016_incident_categories() to authenticated;
grant execute on function public.kiosk_r3016_battery_risk() to authenticated;
grant execute on function public.kiosk_r3016_device_type_breakdown() to authenticated;
