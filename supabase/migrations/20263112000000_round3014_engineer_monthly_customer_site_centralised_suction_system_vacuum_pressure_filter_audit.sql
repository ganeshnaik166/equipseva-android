-- Round r3014 — Engineer Monthly Customer Site Centralised Suction System Vacuum Pressure & Filter Audit

create table if not exists suction_system_audits_r3014 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  site_code text not null,
  hospital_name text not null,
  city text not null,
  engineer_name text not null,
  audit_date date not null,
  pump_count int not null check (pump_count between 1 and 8),
  vacuum_pressure_kpa numeric(6,2) not null check (vacuum_pressure_kpa between 0 and 100),
  target_pressure_kpa numeric(6,2) not null check (target_pressure_kpa between 40 and 80),
  filter_status text not null check (filter_status in ('clean','dirty','replaced','overdue')),
  leak_test_pass boolean not null,
  noise_db numeric(5,2) not null check (noise_db between 30 and 90),
  next_audit_due date,
  status text not null check (status in ('scheduled','completed','failed','remediation'))
);

create table if not exists suction_filter_replacements_r3014 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  site_code text not null,
  filter_type text not null check (filter_type in ('hepa','coalescing','bacterial','prefilter')),
  replaced_on date,
  hours_used int not null check (hours_used between 0 and 5000),
  cost_rupees int not null check (cost_rupees between 0 and 50000),
  engineer_name text not null,
  notes text
);

alter table suction_system_audits_r3014 enable row level security;
alter table suction_filter_replacements_r3014 enable row level security;

drop policy if exists ssa_r3014_founder on suction_system_audits_r3014;
create policy ssa_r3014_founder on suction_system_audits_r3014 for select using (is_founder());

drop policy if exists sfr_r3014_founder on suction_filter_replacements_r3014;
create policy sfr_r3014_founder on suction_filter_replacements_r3014 for select using (is_founder());

insert into suction_system_audits_r3014 (site_code, hospital_name, city, engineer_name, audit_date, pump_count, vacuum_pressure_kpa, target_pressure_kpa, filter_status, leak_test_pass, noise_db, next_audit_due, status) values
('STE-01','Apollo Jubilee','Hyderabad','Ravi Kumar','2026-06-01'::date,4,62.50,60.00,'clean',true,68.20,'2026-07-01'::date,'completed'),
('STE-02','Yashoda Somajiguda','Hyderabad','Suresh M','2026-06-02'::date,3,55.20,60.00,'dirty',true,72.40,'2026-07-02'::date,'remediation'),
('STE-03','KIMS Secunderabad','Hyderabad','Anita R','2026-06-03'::date,4,48.30,60.00,'overdue',false,78.10,'2026-06-15'::date,'failed'),
('STE-04','Care Banjara','Hyderabad','Vikram S','2026-06-04'::date,2,65.40,60.00,'replaced',true,64.30,'2026-07-04'::date,'completed'),
('STE-05','Continental Gachibowli','Hyderabad','Ramesh K','2026-06-05'::date,5,58.20,60.00,'clean',true,70.50,'2026-07-05'::date,'completed'),
('STE-06','AIG Hospital','Hyderabad','Priya T','2026-06-06'::date,4,42.10,60.00,'dirty',false,82.30,'2026-06-20'::date,'failed'),
('STE-07','Sunshine Paradise','Hyderabad','Naveen B','2026-06-07'::date,3,61.20,60.00,'clean',true,66.80,'2026-07-07'::date,'completed'),
('STE-08','Star Banjara','Hyderabad','Deepa K','2026-06-08'::date,2,59.40,60.00,'clean',true,68.40,'2026-07-08'::date,'completed'),
('STE-09','Olive Hospital','Hyderabad','Manoj L','2026-06-09'::date,3,52.30,60.00,'dirty',true,74.20,'2026-07-09'::date,'remediation'),
('STE-10','Citizens Specialty','Hyderabad','Lakshmi P','2026-06-10'::date,4,63.80,60.00,'replaced',true,67.10,'2026-07-10'::date,'completed'),
('STE-11','Virinchi Hospital','Hyderabad','Arjun M','2026-06-11'::date,5,57.20,60.00,'clean',true,71.30,'2026-07-11'::date,'completed'),
('STE-12','Medicover','Hyderabad','Sneha R','2026-06-12'::date,4,49.20,60.00,'overdue',false,80.40,'2026-06-25'::date,'failed'),
('STE-13','Asian Institute','Hyderabad','Kiran D','2026-06-13'::date,3,60.50,60.00,'clean',true,69.20,'2026-07-13'::date,'completed'),
('STE-14','Maxcure Madhapur','Hyderabad','Pooja S','2026-06-14'::date,4,54.30,60.00,'dirty',true,73.50,'2026-07-14'::date,'remediation'),
('STE-15','Renova Hospital','Hyderabad','Rohit T','2026-06-15'::date,2,62.40,60.00,'clean',true,65.40,'2026-07-15'::date,'completed'),
('STE-16','Image Hospital','Hyderabad','Anjali V','2026-06-16'::date,3,58.70,60.00,'replaced',true,68.90,'2026-07-16'::date,'completed'),
('STE-17','Citicare','Hyderabad','Sanjay G','2026-06-17'::date,4,45.30,60.00,'overdue',false,84.20,'2026-06-30'::date,'failed'),
('STE-18','Vasavi Hospital','Hyderabad','Meena J','2026-06-18'::date,3,61.80,60.00,'clean',true,66.50,'2026-07-18'::date,'completed'),
('STE-19','Global Hospital','Hyderabad','Karthik P','2026-06-19'::date,5,56.20,60.00,'dirty',true,72.80,'2026-07-19'::date,'remediation'),
('STE-20','Care Outpatient','Hyderabad','Divya N','2026-06-20'::date,2,0.00,60.00,'clean',true,40.00,'2026-07-20'::date,'scheduled');

insert into suction_filter_replacements_r3014 (site_code, filter_type, replaced_on, hours_used, cost_rupees, engineer_name, notes) values
('STE-01','hepa','2026-06-01'::date,2400,8500,'Ravi Kumar','Routine replacement'),
('STE-02','coalescing',null,3200,4200,'Suresh M','Overdue - schedule next week'),
('STE-03','prefilter','2026-06-03'::date,1800,1200,'Anita R','Heavy dust load'),
('STE-04','hepa','2026-06-04'::date,2100,8500,'Vikram S','Preventive'),
('STE-05','bacterial','2026-06-05'::date,2800,3600,'Ramesh K','Annual'),
('STE-06','coalescing','2026-06-06'::date,4100,4200,'Priya T','Failed leak test'),
('STE-07','prefilter','2026-06-07'::date,1500,1200,'Naveen B','Quarterly'),
('STE-08','hepa','2026-06-08'::date,2200,8500,'Deepa K','Routine'),
('STE-09','bacterial','2026-06-09'::date,2600,3600,'Manoj L','Bacterial culture clean'),
('STE-10','coalescing','2026-06-10'::date,3000,4200,'Lakshmi P','Replaced ahead'),
('STE-11','hepa','2026-06-11'::date,2350,8500,'Arjun M','Routine'),
('STE-12','prefilter',null,2400,1200,'Sneha R','Pending dispatch'),
('STE-13','bacterial','2026-06-13'::date,2700,3600,'Kiran D','Annual'),
('STE-14','coalescing','2026-06-14'::date,3100,4200,'Pooja S','Slight oil residue'),
('STE-15','hepa','2026-06-15'::date,2050,8500,'Rohit T','Routine');

create or replace function rpc_r3014_audit_overview()
returns table(total_audits int, completed_audits int, failed_audits int, remediation_audits int, scheduled_audits int, avg_pressure numeric, avg_noise numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select
    count(*)::int,
    (count(*) filter (where status = 'completed'))::int,
    (count(*) filter (where status = 'failed'))::int,
    (count(*) filter (where status = 'remediation'))::int,
    (count(*) filter (where status = 'scheduled'))::int,
    round(avg(vacuum_pressure_kpa),2),
    round(avg(noise_db),2)
  from suction_system_audits_r3014;
end; $$;

create or replace function rpc_r3014_failed_sites()
returns table(site_code text, hospital_name text, city text, vacuum_pressure_kpa numeric, target_pressure_kpa numeric, noise_db numeric, filter_status text, next_audit_due date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select s.site_code, s.hospital_name, s.city, s.vacuum_pressure_kpa, s.target_pressure_kpa, s.noise_db, s.filter_status, s.next_audit_due
    from suction_system_audits_r3014 s
    where s.status in ('failed','remediation')
    order by s.vacuum_pressure_kpa asc;
end; $$;

create or replace function rpc_r3014_filter_status_breakdown()
returns table(filter_status text, site_count int, avg_pressure numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select s.filter_status, count(*)::int, round(avg(s.vacuum_pressure_kpa),2)
    from suction_system_audits_r3014 s
    group by s.filter_status
    order by count(*) desc;
end; $$;

create or replace function rpc_r3014_engineer_workload()
returns table(engineer_name text, audit_count int, fail_count int, avg_pressure numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select s.engineer_name, count(*)::int, (count(*) filter (where s.status = 'failed'))::int, round(avg(s.vacuum_pressure_kpa),2)
    from suction_system_audits_r3014 s
    group by s.engineer_name
    order by count(*) desc;
end; $$;

create or replace function rpc_r3014_filter_replacement_cost()
returns table(filter_type text, replacement_count int, total_cost_rupees int, avg_hours_used numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select f.filter_type, count(*)::int, sum(f.cost_rupees)::int, round(avg(f.hours_used),0)
    from suction_filter_replacements_r3014 f
    group by f.filter_type
    order by sum(f.cost_rupees) desc;
end; $$;

create or replace function rpc_r3014_pressure_below_target()
returns table(site_code text, hospital_name text, vacuum_pressure_kpa numeric, target_pressure_kpa numeric, deficit numeric, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select s.site_code, s.hospital_name, s.vacuum_pressure_kpa, s.target_pressure_kpa, round(s.target_pressure_kpa - s.vacuum_pressure_kpa, 2), s.status
    from suction_system_audits_r3014 s
    where s.vacuum_pressure_kpa < s.target_pressure_kpa
    order by (s.target_pressure_kpa - s.vacuum_pressure_kpa) desc;
end; $$;

create or replace function rpc_r3014_upcoming_audits()
returns table(site_code text, hospital_name text, next_audit_due date, status text, filter_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query select s.site_code, s.hospital_name, s.next_audit_due, s.status, s.filter_status
    from suction_system_audits_r3014 s
    where s.next_audit_due is not null
    order by s.next_audit_due asc
    limit 15;
end; $$;

revoke all on function rpc_r3014_audit_overview() from public, anon;
revoke all on function rpc_r3014_failed_sites() from public, anon;
revoke all on function rpc_r3014_filter_status_breakdown() from public, anon;
revoke all on function rpc_r3014_engineer_workload() from public, anon;
revoke all on function rpc_r3014_filter_replacement_cost() from public, anon;
revoke all on function rpc_r3014_pressure_below_target() from public, anon;
revoke all on function rpc_r3014_upcoming_audits() from public, anon;

grant execute on function rpc_r3014_audit_overview() to authenticated;
grant execute on function rpc_r3014_failed_sites() to authenticated;
grant execute on function rpc_r3014_filter_status_breakdown() to authenticated;
grant execute on function rpc_r3014_engineer_workload() to authenticated;
grant execute on function rpc_r3014_filter_replacement_cost() to authenticated;
grant execute on function rpc_r3014_pressure_below_target() to authenticated;
grant execute on function rpc_r3014_upcoming_audits() to authenticated;
