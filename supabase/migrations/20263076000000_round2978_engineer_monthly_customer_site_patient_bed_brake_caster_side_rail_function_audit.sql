-- Round r2978 — Engineer Monthly Customer Site Patient-Bed Brake-Caster & Side-Rail Function Audit
-- HEAVY ★★★★

create table if not exists patient_bed_brake_caster_audit_r2978 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_code text not null,
  hospital_name text not null,
  ward_name text not null,
  bed_asset_tag text not null,
  bed_model text not null,
  audit_month text not null,
  engineer_code text not null,
  engineer_name text not null,
  caster_count int not null check (caster_count between 2 and 8),
  brakes_functional int not null check (brakes_functional >= 0),
  brakes_failed int not null check (brakes_failed >= 0),
  caster_swivel_score numeric(5,2) not null check (caster_swivel_score between 0 and 100),
  caster_wear_mm numeric(5,2) not null check (caster_wear_mm >= 0),
  brake_pedal_force_n numeric(6,2) not null check (brake_pedal_force_n >= 0),
  audit_result text not null check (audit_result in ('pass','minor_defect','major_defect','fail')),
  severity text not null check (severity in ('low','medium','high','critical')),
  patient_safety_flag boolean not null default false
);

create table if not exists patient_bed_side_rail_function_r2978 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_code text not null,
  bed_asset_tag text not null,
  audit_month text not null,
  rail_position text not null check (rail_position in ('left_head','right_head','left_foot','right_foot')),
  latch_status text not null check (latch_status in ('locks','slips','seized','broken')),
  travel_range_cm numeric(5,2) not null check (travel_range_cm >= 0),
  drop_test_seconds numeric(5,2) not null check (drop_test_seconds >= 0),
  noise_db numeric(5,2) not null check (noise_db >= 0),
  finding text not null check (finding in ('ok','adjust','replace_part','replace_unit','urgent')),
  action_eta_days int not null check (action_eta_days >= 0),
  parts_cost_rupees int not null check (parts_cost_rupees >= 0),
  fall_risk_flag boolean not null default false
);

alter table patient_bed_brake_caster_audit_r2978 enable row level security;
alter table patient_bed_side_rail_function_r2978 enable row level security;

drop policy if exists pbbca_r2978_founder on patient_bed_brake_caster_audit_r2978;
create policy pbbca_r2978_founder on patient_bed_brake_caster_audit_r2978
  for select using (is_founder());

drop policy if exists pbsrf_r2978_founder on patient_bed_side_rail_function_r2978;
create policy pbsrf_r2978_founder on patient_bed_side_rail_function_r2978
  for select using (is_founder());

revoke all on patient_bed_brake_caster_audit_r2978 from public, anon;
revoke all on patient_bed_side_rail_function_r2978 from public, anon;
grant select on patient_bed_brake_caster_audit_r2978 to authenticated;
grant select on patient_bed_side_rail_function_r2978 to authenticated;

-- Seed: patient_bed_brake_caster_audit_r2978 (20 rows)
insert into patient_bed_brake_caster_audit_r2978
(hospital_code, hospital_name, ward_name, bed_asset_tag, bed_model, audit_month, engineer_code, engineer_name, caster_count, brakes_functional, brakes_failed, caster_swivel_score, caster_wear_mm, brake_pedal_force_n, audit_result, severity, patient_safety_flag) values
('H001','Apollo Jubilee','ICU-1','BED-A001','Stryker S3','2026-06','E101','Ravi Kumar',4,4,0,92.50,1.20,38.40,'pass','low',false),
('H001','Apollo Jubilee','ICU-1','BED-A002','Stryker S3','2026-06','E101','Ravi Kumar',4,3,1,78.30,2.80,42.10,'minor_defect','medium',false),
('H001','Apollo Jubilee','Ward-3B','BED-A003','Hill-Rom 900','2026-06','E101','Ravi Kumar',4,2,2,65.40,4.10,51.20,'major_defect','high',true),
('H002','KIMS Secunderabad','ICU-2','BED-B001','Stryker S3','2026-06','E102','Suresh M',4,4,0,88.10,1.50,39.80,'pass','low',false),
('H002','KIMS Secunderabad','Maternity','BED-B002','Hill-Rom 900','2026-06','E102','Suresh M',4,3,1,74.20,3.20,44.50,'minor_defect','medium',false),
('H002','KIMS Secunderabad','Emergency','BED-B003','Drager TC30','2026-06','E102','Suresh M',4,1,3,42.10,5.80,62.40,'fail','critical',true),
('H003','Yashoda Somajiguda','ICU-1','BED-C001','Stryker S3','2026-06','E103','Arjun P',4,4,0,90.80,1.10,37.20,'pass','low',false),
('H003','Yashoda Somajiguda','Ward-2A','BED-C002','Hill-Rom 900','2026-06','E103','Arjun P',4,2,2,58.30,4.60,55.80,'major_defect','high',true),
('H004','Fortis Banjara','ICU-3','BED-D001','Drager TC30','2026-06','E104','Vikram S',4,3,1,72.40,2.90,41.30,'minor_defect','medium',false),
('H004','Fortis Banjara','Ward-1B','BED-D002','Stryker S3','2026-06','E104','Vikram S',4,4,0,86.20,1.80,40.10,'pass','low',false),
('H005','Care Banjara','Pediatric','BED-E001','Hill-Rom 900','2026-06','E105','Naveen R',4,3,1,68.90,3.40,46.70,'minor_defect','medium',false),
('H005','Care Banjara','ICU-1','BED-E002','Drager TC30','2026-06','E105','Naveen R',4,0,4,32.10,6.20,71.40,'fail','critical',true),
('H006','AIG Gachibowli','ICU-2','BED-F001','Stryker S3','2026-06','E106','Mahesh T',4,4,0,89.40,1.30,38.90,'pass','low',false),
('H006','AIG Gachibowli','Ward-3A','BED-F002','Hill-Rom 900','2026-06','E106','Mahesh T',4,2,2,61.20,4.80,57.30,'major_defect','high',true),
('H007','Sunshine Paradise','Ward-1A','BED-G001','Stryker S3','2026-06','E107','Karthik V',4,3,1,76.50,2.60,43.20,'minor_defect','medium',false),
('H008','Continental Nanakramguda','ICU-1','BED-H001','Drager TC30','2026-06','E108','Deepak L',4,4,0,91.20,1.40,38.60,'pass','low',false),
('H008','Continental Nanakramguda','Emergency','BED-H002','Hill-Rom 900','2026-06','E108','Deepak L',4,1,3,38.40,5.40,65.80,'fail','critical',true),
('H009','Manipal Bangalore','ICU-2','BED-I001','Stryker S3','2026-06','E109','Anil B',4,4,0,87.30,1.70,39.40,'pass','low',false),
('H009','Manipal Bangalore','Ward-2B','BED-I002','Hill-Rom 900','2026-06','E109','Anil B',4,3,1,73.10,3.10,45.20,'minor_defect','medium',false),
('H010','Narayana HSR','ICU-1','BED-J001','Drager TC30','2026-06','E110','Rajesh K',4,2,2,55.60,4.90,58.40,'major_defect','high',true);

-- Seed: patient_bed_side_rail_function_r2978 (20 rows)
insert into patient_bed_side_rail_function_r2978
(hospital_code, bed_asset_tag, audit_month, rail_position, latch_status, travel_range_cm, drop_test_seconds, noise_db, finding, action_eta_days, parts_cost_rupees, fall_risk_flag) values
('H001','BED-A001','2026-06','left_head','locks',42.50,2.80,38.20,'ok',0,0,false),
('H001','BED-A001','2026-06','right_head','locks',42.30,2.90,38.80,'ok',0,0,false),
('H001','BED-A002','2026-06','left_foot','slips',38.10,1.40,52.40,'adjust',3,450,true),
('H001','BED-A003','2026-06','right_foot','seized',18.20,0.80,61.20,'replace_part',5,2400,true),
('H002','BED-B001','2026-06','left_head','locks',41.80,2.60,39.10,'ok',0,0,false),
('H002','BED-B002','2026-06','right_head','slips',36.40,1.60,54.20,'adjust',2,380,true),
('H002','BED-B003','2026-06','left_foot','broken',8.40,0.40,72.30,'replace_unit',7,18500,true),
('H003','BED-C001','2026-06','right_foot','locks',43.10,2.70,37.80,'ok',0,0,false),
('H003','BED-C002','2026-06','left_head','seized',22.30,0.90,58.40,'replace_part',5,2200,true),
('H004','BED-D001','2026-06','right_head','slips',37.80,1.50,53.10,'adjust',3,420,true),
('H004','BED-D002','2026-06','left_foot','locks',42.20,2.80,38.40,'ok',0,0,false),
('H005','BED-E001','2026-06','right_foot','slips',35.60,1.30,55.40,'adjust',4,510,true),
('H005','BED-E002','2026-06','left_head','broken',4.20,0.30,74.10,'urgent',1,21800,true),
('H006','BED-F001','2026-06','right_head','locks',42.80,2.70,38.60,'ok',0,0,false),
('H006','BED-F002','2026-06','left_foot','seized',16.40,0.70,62.80,'replace_part',6,2600,true),
('H007','BED-G001','2026-06','right_foot','slips',38.20,1.70,51.80,'adjust',3,460,true),
('H008','BED-H001','2026-06','left_head','locks',43.40,2.80,37.90,'ok',0,0,false),
('H008','BED-H002','2026-06','right_head','broken',6.80,0.40,73.40,'urgent',1,19600,true),
('H009','BED-I002','2026-06','left_foot','slips',37.10,1.50,53.80,'adjust',3,440,true),
('H010','BED-J001','2026-06','right_foot','seized',19.40,0.80,60.10,'replace_part',5,2350,true);

-- RPCs

create or replace function r2978_audit_result_summary()
returns table(audit_result text, bed_count int, safety_flags int, avg_swivel numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_result,
         (count(*))::int,
         (count(*) filter (where a.patient_safety_flag))::int,
         round(avg(a.caster_swivel_score),2)
  from patient_bed_brake_caster_audit_r2978 a
  group by a.audit_result
  order by case a.audit_result when 'fail' then 1 when 'major_defect' then 2 when 'minor_defect' then 3 else 4 end;
end$$;

create or replace function r2978_hospital_rollup()
returns table(hospital_code text, hospital_name text, beds_audited int, brakes_failed_total int, safety_flagged int, avg_pedal_force numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_code, a.hospital_name,
         (count(*))::int,
         (sum(a.brakes_failed))::int,
         (count(*) filter (where a.patient_safety_flag))::int,
         round(avg(a.brake_pedal_force_n),2)
  from patient_bed_brake_caster_audit_r2978 a
  group by a.hospital_code, a.hospital_name
  order by sum(a.brakes_failed) desc;
end$$;

create or replace function r2978_critical_beds()
returns table(hospital_code text, bed_asset_tag text, ward_name text, bed_model text, brakes_failed int, caster_wear_mm numeric, audit_result text, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_code, a.bed_asset_tag, a.ward_name, a.bed_model, a.brakes_failed, a.caster_wear_mm, a.audit_result, a.severity
  from patient_bed_brake_caster_audit_r2978 a
  where a.severity in ('high','critical')
  order by case a.severity when 'critical' then 1 else 2 end, a.brakes_failed desc;
end$$;

create or replace function r2978_engineer_workload()
returns table(engineer_code text, engineer_name text, beds_audited int, passes int, defects int, avg_swivel numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_code, a.engineer_name,
         (count(*))::int,
         (count(*) filter (where a.audit_result = 'pass'))::int,
         (count(*) filter (where a.audit_result in ('minor_defect','major_defect','fail')))::int,
         round(avg(a.caster_swivel_score),2)
  from patient_bed_brake_caster_audit_r2978 a
  group by a.engineer_code, a.engineer_name
  order by count(*) filter (where a.audit_result in ('minor_defect','major_defect','fail')) desc;
end$$;

create or replace function r2978_side_rail_findings()
returns table(finding text, rail_count int, fall_risks int, avg_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.finding,
         (count(*))::int,
         (count(*) filter (where r.fall_risk_flag))::int,
         round(avg(r.parts_cost_rupees),2)
  from patient_bed_side_rail_function_r2978 r
  group by r.finding
  order by case r.finding when 'urgent' then 1 when 'replace_unit' then 2 when 'replace_part' then 3 when 'adjust' then 4 else 5 end;
end$$;

create or replace function r2978_latch_status_breakdown()
returns table(latch_status text, rail_count int, avg_travel numeric, avg_drop_seconds numeric, total_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.latch_status,
         (count(*))::int,
         round(avg(r.travel_range_cm),2),
         round(avg(r.drop_test_seconds),2),
         (sum(r.parts_cost_rupees))::int
  from patient_bed_side_rail_function_r2978 r
  group by r.latch_status
  order by sum(r.parts_cost_rupees) desc;
end$$;

create or replace function r2978_bed_combined_risk()
returns table(hospital_code text, bed_asset_tag text, audit_result text, brakes_failed int, broken_rails int, fall_risk_rails int, total_parts_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_code, a.bed_asset_tag, a.audit_result, a.brakes_failed,
         (count(r.id) filter (where r.latch_status in ('broken','seized')))::int,
         (count(r.id) filter (where r.fall_risk_flag))::int,
         (coalesce(sum(r.parts_cost_rupees),0))::int
  from patient_bed_brake_caster_audit_r2978 a
  left join patient_bed_side_rail_function_r2978 r on r.bed_asset_tag = a.bed_asset_tag and r.hospital_code = a.hospital_code
  group by a.hospital_code, a.bed_asset_tag, a.audit_result, a.brakes_failed
  order by a.brakes_failed desc, count(r.id) filter (where r.fall_risk_flag) desc;
end$$;

revoke all on function r2978_audit_result_summary() from public, anon;
revoke all on function r2978_hospital_rollup() from public, anon;
revoke all on function r2978_critical_beds() from public, anon;
revoke all on function r2978_engineer_workload() from public, anon;
revoke all on function r2978_side_rail_findings() from public, anon;
revoke all on function r2978_latch_status_breakdown() from public, anon;
revoke all on function r2978_bed_combined_risk() from public, anon;

grant execute on function r2978_audit_result_summary() to authenticated;
grant execute on function r2978_hospital_rollup() to authenticated;
grant execute on function r2978_critical_beds() to authenticated;
grant execute on function r2978_engineer_workload() to authenticated;
grant execute on function r2978_side_rail_findings() to authenticated;
grant execute on function r2978_latch_status_breakdown() to authenticated;
grant execute on function r2978_bed_combined_risk() to authenticated;
