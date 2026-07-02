-- Round 3034: Engineer Monthly Customer Site Centrifuge Imbalance & Drift Bearing Health Audit

create table if not exists centrifuge_imbalance_audits_r3034 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_name text,
  centrifuge_model text,
  centrifuge_serial text,
  engineer_name text,
  audit_date date,
  rotor_type text,
  rotor_balance_grade text check (rotor_balance_grade in ('g1','g2.5','g6.3','out_of_spec')),
  vibration_rms_mm_s numeric,
  vibration_peak_mm_s numeric,
  rpm_setpoint int,
  rpm_actual int,
  rpm_drift_pct numeric,
  bearing_temp_celsius numeric,
  bearing_noise_db numeric,
  bearing_status text check (bearing_status in ('healthy','watch','degrading','replace_now')),
  imbalance_severity text check (imbalance_severity in ('none','mild','moderate','severe','critical')),
  follow_up_required boolean default false,
  notes text
);

create table if not exists centrifuge_bearing_replacement_log_r3034 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_id uuid references centrifuge_imbalance_audits_r3034(id) on delete set null,
  hospital_name text,
  centrifuge_serial text,
  bearing_part_no text,
  replacement_date date,
  engineer_name text,
  cost_rupees numeric,
  downtime_hours numeric,
  root_cause text check (root_cause in ('age','contamination','overload','misalignment','manufacturing_defect','unknown')),
  warranty_claim boolean default false,
  resolution_status text check (resolution_status in ('open','parts_ordered','in_progress','resolved','escalated'))
);

alter table centrifuge_imbalance_audits_r3034 enable row level security;
alter table centrifuge_bearing_replacement_log_r3034 enable row level security;

drop policy if exists r3034_audits_founder_read on centrifuge_imbalance_audits_r3034;
create policy r3034_audits_founder_read on centrifuge_imbalance_audits_r3034 for select to authenticated using (is_founder());

drop policy if exists r3034_log_founder_read on centrifuge_bearing_replacement_log_r3034;
create policy r3034_log_founder_read on centrifuge_bearing_replacement_log_r3034 for select to authenticated using (is_founder());

-- Seeds: centrifuge_imbalance_audits_r3034 (18 rows)
insert into centrifuge_imbalance_audits_r3034 (hospital_name, centrifuge_model, centrifuge_serial, engineer_name, audit_date, rotor_type, rotor_balance_grade, vibration_rms_mm_s, vibration_peak_mm_s, rpm_setpoint, rpm_actual, rpm_drift_pct, bearing_temp_celsius, bearing_noise_db, bearing_status, imbalance_severity, follow_up_required, notes) values
('Apollo Hyderabad','Eppendorf 5810R','EP5810-2201','Ravi Kumar','2026-06-01'::date,'swing_bucket','g2.5',1.2,2.1,4000,3998,0.05,38.5,52.0,'healthy','none',false,'clean run'),
('Yashoda Secunderabad','Hettich Rotina 380','HR380-1145','Sneha Reddy','2026-06-02'::date,'fixed_angle','g2.5',2.8,4.5,5000,4985,0.30,42.1,58.5,'watch','mild',false,'slight wobble'),
('KIMS Kondapur','Thermo Sorvall ST8','TS8-3320','Arjun Patel','2026-06-03'::date,'swing_bucket','g6.3',5.4,8.9,4500,4420,1.78,55.2,68.0,'degrading','moderate',true,'rotor seat wear'),
('Continental Gachibowli','Eppendorf 5430R','EP5430-7711','Priya Iyer','2026-06-04'::date,'fixed_angle','g2.5',1.5,2.4,6000,5995,0.08,39.0,53.5,'healthy','none',false,null),
('Care Banjara','Hettich Universal 320','HU320-2210','Karthik N','2026-06-05'::date,'swing_bucket','g6.3',6.8,11.2,3500,3380,3.43,62.4,72.1,'replace_now','severe',true,'bearing whine audible'),
('Maxcure Madhapur','Thermo Megafuge 8','TM8-4455','Anita Rao','2026-06-06'::date,'fixed_angle','g2.5',1.9,3.0,5500,5490,0.18,40.2,54.0,'healthy','none',false,null),
('Citizens Nallagandla','Eppendorf 5910R','EP5910-9988','Rohan Das','2026-06-07'::date,'swing_bucket','g2.5',2.2,3.6,4000,3992,0.20,41.5,55.8,'watch','mild',false,'monitor next month'),
('AIG Gachibowli','Hettich Mikro 220R','HM220-5566','Deepa Joshi','2026-06-08'::date,'fixed_angle','g2.5',3.5,5.8,14000,13905,0.68,48.9,62.5,'watch','moderate',true,'high speed wobble'),
('Sunshine Paradise','Thermo Sorvall LYNX','SL-7780','Vikram Singh','2026-06-09'::date,'fixed_angle','g6.3',7.2,12.5,12000,11760,2.00,65.0,74.3,'replace_now','severe',true,'urgent replace'),
('Olive Hospital','Eppendorf 5424R','EP5424-3344','Manoj T','2026-06-10'::date,'fixed_angle','g2.5',1.1,1.9,15000,14990,0.07,37.5,51.2,'healthy','none',false,null),
('Star Banjara','Hettich Rotina 420R','HR420-8899','Sanjay Mehta','2026-06-11'::date,'swing_bucket','g6.3',8.5,14.2,4500,4280,4.89,68.5,76.0,'replace_now','critical',true,'unsafe — locked out'),
('Rainbow Banjara','Thermo Heraeus Pico 17','TP17-1122','Lakshmi V','2026-06-12'::date,'fixed_angle','g2.5',1.8,2.9,13300,13280,0.15,39.8,53.2,'healthy','none',false,null),
('Global Lakdikapul','Eppendorf 5418R','EP5418-6677','Ramesh K','2026-06-13'::date,'fixed_angle','g6.3',4.9,7.8,14000,13860,1.00,52.0,65.5,'degrading','moderate',true,null),
('Care Outpatient','Hettich EBA 280','HE280-4400','Anjali B','2026-06-14'::date,'fixed_angle','g2.5',2.0,3.2,6000,5988,0.20,40.5,54.8,'healthy','mild',false,null),
('Apollo DRDO','Thermo Multifuge X3R','TX3-2244','Suresh M','2026-06-15'::date,'swing_bucket','g2.5',2.6,4.1,4200,4180,0.48,42.8,57.0,'watch','mild',false,null),
('KIMS Begumpet','Eppendorf 5702R','EP5702-9911','Naveen P','2026-06-16'::date,'swing_bucket','g6.3',6.1,10.0,4400,4310,2.05,58.6,69.5,'degrading','severe',true,'imbalance on tube load'),
('Yashoda Malakpet','Hettich Rotofix 32A','HR32-3355','Kavya S','2026-06-17'::date,'fixed_angle','out_of_spec',9.2,15.5,6000,5710,4.83,71.2,78.5,'replace_now','critical',true,'CRITICAL — out of service'),
('Continental Madhapur','Thermo Sorvall ST1','TS1-8866','Akhil R','2026-06-18'::date,'fixed_angle','g2.5',1.4,2.2,5000,4992,0.16,38.2,52.5,'healthy','none',false,'baseline clean');

-- Seeds: centrifuge_bearing_replacement_log_r3034 (16 rows)
insert into centrifuge_bearing_replacement_log_r3034 (hospital_name, centrifuge_serial, bearing_part_no, replacement_date, engineer_name, cost_rupees, downtime_hours, root_cause, warranty_claim, resolution_status) values
('Care Banjara','HU320-2210','SKF-6203-2RS','2026-06-09'::date,'Karthik N',4200,6.5,'age',false,'resolved'),
('Sunshine Paradise','SL-7780','FAG-6206-Z','2026-06-12'::date,'Vikram Singh',8500,12.0,'contamination',false,'resolved'),
('Star Banjara','HR420-8899','NSK-6204-RS','2026-06-13'::date,'Sanjay Mehta',5800,18.5,'overload',true,'in_progress'),
('KIMS Kondapur','TS8-3320','SKF-6205-2RS','2026-06-14'::date,'Arjun Patel',6100,8.0,'misalignment',false,'resolved'),
('Yashoda Malakpet','HR32-3355','FAG-6203-Z','2026-06-19'::date,'Kavya S',4500,24.0,'manufacturing_defect',true,'escalated'),
('AIG Gachibowli','HM220-5566','NSK-625-ZZ','2026-06-15'::date,'Deepa Joshi',3200,4.5,'age',false,'parts_ordered'),
('Global Lakdikapul','EP5418-6677','SKF-624-RS','2026-06-18'::date,'Ramesh K',2900,5.0,'age',false,'resolved'),
('KIMS Begumpet','EP5702-9911','FAG-6204-2RS','2026-06-20'::date,'Naveen P',5400,7.5,'overload',false,'in_progress'),
('Apollo Hyderabad','EP5810-2201','SKF-6203-2RS','2026-05-15'::date,'Ravi Kumar',4200,5.0,'age',false,'resolved'),
('Olive Hospital','EP5424-3344','SKF-6202-Z','2026-05-20'::date,'Manoj T',2400,3.0,'unknown',false,'resolved'),
('Continental Gachibowli','EP5430-7711','FAG-6205-RS','2026-05-22'::date,'Priya Iyer',5100,6.0,'contamination',false,'resolved'),
('Rainbow Banjara','TP17-1122','NSK-625-ZZ','2026-05-25'::date,'Lakshmi V',2800,4.0,'age',false,'resolved'),
('Maxcure Madhapur','TM8-4455','SKF-6204-2RS','2026-05-28'::date,'Anita Rao',4400,5.5,'misalignment',false,'resolved'),
('Citizens Nallagandla','EP5910-9988','FAG-6206-Z','2026-06-01'::date,'Rohan Das',7200,8.5,'overload',true,'open'),
('Apollo DRDO','TX3-2244','NSK-6203-RS','2026-06-05'::date,'Suresh M',4600,6.0,'age',false,'resolved'),
('Continental Madhapur','TS1-8866','SKF-6204-Z','2026-06-08'::date,'Akhil R',4100,4.5,'unknown',false,'resolved');

-- RPCs

create or replace function r3034_summary()
returns table(total_audits int, follow_ups int, critical_units int, replace_now_units int, avg_vibration numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where follow_up_required))::int,
    (count(*) filter (where imbalance_severity = 'critical'))::int,
    (count(*) filter (where bearing_status = 'replace_now'))::int,
    round(avg(vibration_rms_mm_s)::numeric, 2)
  from centrifuge_imbalance_audits_r3034;
end $$;

create or replace function r3034_by_severity()
returns table(imbalance_severity text, units int, avg_vibration numeric, avg_drift numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.imbalance_severity, count(*)::int, round(avg(a.vibration_rms_mm_s)::numeric, 2), round(avg(a.rpm_drift_pct)::numeric, 2)
  from centrifuge_imbalance_audits_r3034 a
  group by a.imbalance_severity
  order by units desc;
end $$;

create or replace function r3034_bearing_health_dist()
returns table(bearing_status text, units int, avg_temp numeric, avg_noise numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.bearing_status, count(*)::int, round(avg(a.bearing_temp_celsius)::numeric, 1), round(avg(a.bearing_noise_db)::numeric, 1)
  from centrifuge_imbalance_audits_r3034 a
  group by a.bearing_status
  order by units desc;
end $$;

create or replace function r3034_top_problem_sites()
returns table(hospital_name text, audits int, critical_count int, max_vibration numeric, max_drift_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, count(*)::int,
    (count(*) filter (where a.imbalance_severity in ('severe','critical')))::int,
    max(a.vibration_rms_mm_s), max(a.rpm_drift_pct)
  from centrifuge_imbalance_audits_r3034 a
  group by a.hospital_name
  order by critical_count desc, max_vibration desc
  limit 12;
end $$;

create or replace function r3034_engineer_load()
returns table(engineer_name text, audits int, follow_ups int, replace_now_calls int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name, count(*)::int,
    (count(*) filter (where a.follow_up_required))::int,
    (count(*) filter (where a.bearing_status = 'replace_now'))::int
  from centrifuge_imbalance_audits_r3034 a
  group by a.engineer_name
  order by audits desc;
end $$;

create or replace function r3034_root_cause_breakdown()
returns table(root_cause text, replacements int, total_cost numeric, avg_downtime numeric, warranty_claims int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.root_cause, count(*)::int, sum(l.cost_rupees)::numeric, round(avg(l.downtime_hours)::numeric, 1),
    (count(*) filter (where l.warranty_claim))::int
  from centrifuge_bearing_replacement_log_r3034 l
  group by l.root_cause
  order by replacements desc;
end $$;

create or replace function r3034_open_replacement_actions()
returns table(hospital_name text, centrifuge_serial text, bearing_part_no text, resolution_status text, cost_rupees numeric, downtime_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.centrifuge_serial, l.bearing_part_no, l.resolution_status, l.cost_rupees, l.downtime_hours
  from centrifuge_bearing_replacement_log_r3034 l
  where l.resolution_status in ('open','parts_ordered','in_progress','escalated')
  order by l.created_at desc;
end $$;

revoke all on function r3034_summary() from public, anon;
revoke all on function r3034_by_severity() from public, anon;
revoke all on function r3034_bearing_health_dist() from public, anon;
revoke all on function r3034_top_problem_sites() from public, anon;
revoke all on function r3034_engineer_load() from public, anon;
revoke all on function r3034_root_cause_breakdown() from public, anon;
revoke all on function r3034_open_replacement_actions() from public, anon;

grant execute on function r3034_summary() to authenticated;
grant execute on function r3034_by_severity() to authenticated;
grant execute on function r3034_bearing_health_dist() to authenticated;
grant execute on function r3034_top_problem_sites() to authenticated;
grant execute on function r3034_engineer_load() to authenticated;
grant execute on function r3034_root_cause_breakdown() to authenticated;
grant execute on function r3034_open_replacement_actions() to authenticated;
