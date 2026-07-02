-- Round 3004: Customer Monthly Engineer Hospital Pneumatic-Door Auto-Close & Sensor Calibration Tracker

create table if not exists pneumatic_door_checks_r3004 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_name text not null,
  city text not null,
  door_location text not null,
  door_model text not null,
  check_month date not null,
  engineer_name text not null,
  auto_close_seconds numeric(6,2) not null,
  target_seconds numeric(6,2) not null default 4.0,
  sensor_calibration_status text not null check (sensor_calibration_status in ('calibrated','drift_minor','drift_major','failed','pending')),
  seal_integrity text not null check (seal_integrity in ('intact','minor_wear','major_wear','breached')),
  pressure_psi numeric(6,2) not null,
  follow_up_status text not null check (follow_up_status in ('open','in_progress','resolved','escalated'))
);

create table if not exists pneumatic_door_incidents_r3004 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  check_id uuid references pneumatic_door_checks_r3004(id) on delete cascade,
  hospital_name text not null,
  incident_type text not null check (incident_type in ('slam','fail_to_close','sensor_misfire','seal_leak','manual_override','obstruction')),
  severity text not null check (severity in ('low','medium','high','critical')),
  reported_by text not null,
  resolution_minutes int,
  resolution_status text not null check (resolution_status in ('open','in_progress','resolved','deferred')),
  ot_disruption_minutes int not null default 0
);

alter table pneumatic_door_checks_r3004 enable row level security;
alter table pneumatic_door_incidents_r3004 enable row level security;

drop policy if exists pdc_r3004_founder on pneumatic_door_checks_r3004;
create policy pdc_r3004_founder on pneumatic_door_checks_r3004 for select using (is_founder());

drop policy if exists pdi_r3004_founder on pneumatic_door_incidents_r3004;
create policy pdi_r3004_founder on pneumatic_door_incidents_r3004 for select using (is_founder());

insert into pneumatic_door_checks_r3004 (hospital_name, city, door_location, door_model, check_month, engineer_name, auto_close_seconds, target_seconds, sensor_calibration_status, seal_integrity, pressure_psi, follow_up_status) values
('Apollo Jubilee Hills','Hyderabad','OT-1 Entry','Dorma ED250','2026-06-01'::date,'Ravi Kumar',3.8,4.0,'calibrated','intact',62.5,'resolved'),
('Apollo Jubilee Hills','Hyderabad','OT-2 Entry','Dorma ED250','2026-06-01'::date,'Ravi Kumar',5.2,4.0,'drift_minor','minor_wear',58.1,'in_progress'),
('KIMS Secunderabad','Hyderabad','ICU Entry','Geze Slimdrive','2026-06-02'::date,'Suresh Naidu',4.1,4.0,'calibrated','intact',61.0,'resolved'),
('KIMS Secunderabad','Hyderabad','OT-3 Entry','Geze Slimdrive','2026-06-02'::date,'Suresh Naidu',6.8,4.0,'drift_major','major_wear',54.2,'escalated'),
('Yashoda Somajiguda','Hyderabad','Cath Lab','Dorma ED100','2026-06-03'::date,'Praveen Reddy',3.9,4.0,'calibrated','intact',63.0,'resolved'),
('Yashoda Somajiguda','Hyderabad','OT-1 Entry','Dorma ED100','2026-06-03'::date,'Praveen Reddy',4.5,4.0,'drift_minor','intact',60.5,'open'),
('Continental Gachibowli','Hyderabad','OT-Main','Record STA20','2026-06-04'::date,'Anil Varma',3.7,4.0,'calibrated','intact',64.2,'resolved'),
('Continental Gachibowli','Hyderabad','ICU-2','Record STA20','2026-06-04'::date,'Anil Varma',7.5,4.0,'failed','major_wear',49.8,'escalated'),
('AIG Gachibowli','Hyderabad','OT-Endo','Dorma ED250','2026-06-05'::date,'Mahesh Babu',4.0,4.0,'calibrated','intact',62.1,'resolved'),
('AIG Gachibowli','Hyderabad','OT-Liver','Dorma ED250','2026-06-05'::date,'Mahesh Babu',5.8,4.0,'drift_major','minor_wear',56.4,'in_progress'),
('Care Banjara Hills','Hyderabad','OT-1','Geze ECdrive','2026-06-06'::date,'Vinod Kumar',3.6,4.0,'calibrated','intact',63.8,'resolved'),
('Care Banjara Hills','Hyderabad','OT-2','Geze ECdrive','2026-06-06'::date,'Vinod Kumar',4.2,4.0,'drift_minor','intact',61.3,'open'),
('Rainbow Vikrampuri','Hyderabad','NICU','Dorma ED100','2026-06-07'::date,'Sandeep Rao',3.9,4.0,'calibrated','intact',62.9,'resolved'),
('Rainbow Vikrampuri','Hyderabad','PICU','Dorma ED100','2026-06-07'::date,'Sandeep Rao',6.2,4.0,'drift_major','major_wear',52.1,'escalated'),
('Sunshine Paradise','Hyderabad','OT-Ortho','Record STA20','2026-06-08'::date,'Kiran Goud',4.1,4.0,'calibrated','intact',61.7,'resolved'),
('Sunshine Paradise','Hyderabad','OT-Cardio','Record STA20','2026-06-08'::date,'Kiran Goud',5.0,4.0,'drift_minor','minor_wear',58.9,'in_progress'),
('Medicover Hitec','Hyderabad','OT-Main','Dorma ED250','2026-06-09'::date,'Rajesh Pillai',3.8,4.0,'calibrated','intact',63.2,'resolved'),
('Medicover Hitec','Hyderabad','OT-2','Dorma ED250','2026-06-09'::date,'Rajesh Pillai',8.1,4.0,'failed','breached',45.6,'escalated'),
('Citizens Specialty','Hyderabad','ICU-1','Geze Slimdrive','2026-06-10'::date,'Naveen Teja',3.9,4.0,'calibrated','intact',62.4,'resolved'),
('Citizens Specialty','Hyderabad','ICU-2','Geze Slimdrive','2026-06-10'::date,'Naveen Teja',4.8,4.0,'drift_minor','minor_wear',59.7,'open'),
('Star Hospitals','Hyderabad','OT-1','Dorma ED100','2026-06-11'::date,'Bharat Singh',3.7,4.0,'calibrated','intact',63.5,'resolved'),
('Star Hospitals','Hyderabad','OT-2','Dorma ED100','2026-06-11'::date,'Bharat Singh',5.5,4.0,'drift_major','minor_wear',55.8,'in_progress'),
('Olive Hospital','Hyderabad','OT-Main','Record STA20','2026-06-12'::date,'Karthik M',4.2,4.0,'drift_minor','intact',60.9,'open'),
('Olive Hospital','Hyderabad','ICU','Record STA20','2026-06-12'::date,'Karthik M',3.8,4.0,'calibrated','intact',62.7,'resolved');

insert into pneumatic_door_incidents_r3004 (hospital_name, incident_type, severity, reported_by, resolution_minutes, resolution_status, ot_disruption_minutes) values
('Apollo Jubilee Hills','slam','medium','OT Nurse',45,'resolved',12),
('KIMS Secunderabad','fail_to_close','high','OT Manager',180,'resolved',55),
('KIMS Secunderabad','sensor_misfire','medium','Engineer',90,'resolved',20),
('Yashoda Somajiguda','obstruction','low','Housekeeping',30,'resolved',5),
('Continental Gachibowli','fail_to_close','critical','OT Manager',240,'in_progress',120),
('Continental Gachibowli','seal_leak','high','Engineer',null,'open',0),
('AIG Gachibowli','sensor_misfire','medium','OT Nurse',60,'resolved',15),
('AIG Gachibowli','slam','low','OT Nurse',20,'resolved',3),
('Care Banjara Hills','manual_override','low','Surgeon',15,'resolved',2),
('Rainbow Vikrampuri','fail_to_close','critical','NICU Nurse',300,'resolved',95),
('Sunshine Paradise','slam','medium','OT Nurse',40,'resolved',10),
('Medicover Hitec','seal_leak','critical','Engineer',null,'in_progress',180),
('Medicover Hitec','fail_to_close','high','OT Manager',150,'deferred',60),
('Citizens Specialty','obstruction','low','Housekeeping',25,'resolved',4),
('Star Hospitals','sensor_misfire','medium','Engineer',75,'resolved',18),
('Star Hospitals','slam','low','OT Nurse',30,'resolved',6),
('Olive Hospital','manual_override','medium','Surgeon',50,'resolved',12),
('Olive Hospital','seal_leak','high','Engineer',120,'resolved',35);

create or replace function rpc_r3004_summary_by_hospital()
returns table (hospital_name text, checks_total int, calibrated_count int, drift_count int, failed_count int, avg_close_seconds numeric, open_followups int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.hospital_name,
         count(*)::int as checks_total,
         (count(*) filter (where c.sensor_calibration_status = 'calibrated'))::int,
         (count(*) filter (where c.sensor_calibration_status in ('drift_minor','drift_major')))::int,
         (count(*) filter (where c.sensor_calibration_status = 'failed'))::int,
         round(avg(c.auto_close_seconds)::numeric, 2),
         (count(*) filter (where c.follow_up_status in ('open','in_progress','escalated')))::int
  from pneumatic_door_checks_r3004 c
  group by c.hospital_name
  order by c.hospital_name;
end; $$;

create or replace function rpc_r3004_calibration_breakdown()
returns table (sensor_calibration_status text, doors int, share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.sensor_calibration_status,
         count(*)::int,
         round(100.0 * count(*) / nullif((select count(*) from pneumatic_door_checks_r3004), 0), 1)
  from pneumatic_door_checks_r3004 c
  group by c.sensor_calibration_status
  order by count(*) desc;
end; $$;

create or replace function rpc_r3004_slow_close_doors()
returns table (hospital_name text, door_location text, door_model text, auto_close_seconds numeric, target_seconds numeric, gap_seconds numeric, follow_up_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.hospital_name, c.door_location, c.door_model, c.auto_close_seconds, c.target_seconds,
         round((c.auto_close_seconds - c.target_seconds)::numeric, 2) as gap_seconds,
         c.follow_up_status
  from pneumatic_door_checks_r3004 c
  where c.auto_close_seconds > c.target_seconds
  order by gap_seconds desc;
end; $$;

create or replace function rpc_r3004_engineer_coverage()
returns table (engineer_name text, doors_checked int, calibrated_pct numeric, avg_close_seconds numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.engineer_name,
         count(*)::int,
         round(100.0 * (count(*) filter (where c.sensor_calibration_status = 'calibrated')) / nullif(count(*),0)::numeric, 1),
         round(avg(c.auto_close_seconds)::numeric, 2)
  from pneumatic_door_checks_r3004 c
  group by c.engineer_name
  order by count(*) desc;
end; $$;

create or replace function rpc_r3004_incident_summary()
returns table (incident_type text, total int, critical_count int, avg_resolution_min numeric, total_ot_disruption int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select i.incident_type,
         count(*)::int,
         (count(*) filter (where i.severity = 'critical'))::int,
         round(avg(i.resolution_minutes)::numeric, 1),
         sum(i.ot_disruption_minutes)::int
  from pneumatic_door_incidents_r3004 i
  group by i.incident_type
  order by count(*) desc;
end; $$;

create or replace function rpc_r3004_open_escalations()
returns table (hospital_name text, incident_type text, severity text, reported_by text, ot_disruption_minutes int, resolution_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select i.hospital_name, i.incident_type, i.severity, i.reported_by, i.ot_disruption_minutes, i.resolution_status
  from pneumatic_door_incidents_r3004 i
  where i.resolution_status in ('open','in_progress','deferred')
  order by case i.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end; $$;

create or replace function rpc_r3004_seal_pressure_health()
returns table (seal_integrity text, doors int, avg_pressure_psi numeric, low_pressure_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_founder'; end if;
  return query
  select c.seal_integrity,
         count(*)::int,
         round(avg(c.pressure_psi)::numeric, 1),
         (count(*) filter (where c.pressure_psi < 55))::int
  from pneumatic_door_checks_r3004 c
  group by c.seal_integrity
  order by count(*) desc;
end; $$;

revoke all on function rpc_r3004_summary_by_hospital() from public, anon;
revoke all on function rpc_r3004_calibration_breakdown() from public, anon;
revoke all on function rpc_r3004_slow_close_doors() from public, anon;
revoke all on function rpc_r3004_engineer_coverage() from public, anon;
revoke all on function rpc_r3004_incident_summary() from public, anon;
revoke all on function rpc_r3004_open_escalations() from public, anon;
revoke all on function rpc_r3004_seal_pressure_health() from public, anon;

grant execute on function rpc_r3004_summary_by_hospital() to authenticated;
grant execute on function rpc_r3004_calibration_breakdown() to authenticated;
grant execute on function rpc_r3004_slow_close_doors() to authenticated;
grant execute on function rpc_r3004_engineer_coverage() to authenticated;
grant execute on function rpc_r3004_incident_summary() to authenticated;
grant execute on function rpc_r3004_open_escalations() to authenticated;
grant execute on function rpc_r3004_seal_pressure_health() to authenticated;
