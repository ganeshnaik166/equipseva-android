-- Round 3040: Customer Monthly Engineer Hospital Smart IV Stand Battery & Brake Lock Audit
-- HEAVY ★★★★ — 2 tables, 7 RPCs

create table if not exists smart_iv_stand_battery_audits_r3040 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_org_id uuid,
  ward_code text not null,
  stand_serial text not null,
  audit_month date not null,
  engineer_name text not null,
  battery_health_pct numeric(5,2) not null check (battery_health_pct between 0 and 100),
  battery_cycle_count int not null check (battery_cycle_count >= 0),
  charge_hold_minutes int not null check (charge_hold_minutes >= 0),
  brake_lock_status text not null check (brake_lock_status in ('pass','degraded','fail','missing')),
  brake_torque_nm numeric(6,2) not null check (brake_torque_nm >= 0),
  wheel_swivel_status text not null check (wheel_swivel_status in ('smooth','sticky','seized')),
  pole_height_cm int not null check (pole_height_cm between 100 and 250),
  load_test_kg numeric(5,2) not null check (load_test_kg >= 0),
  iv_hook_count int not null check (iv_hook_count between 0 and 8),
  hook_corrosion text not null check (hook_corrosion in ('none','light','moderate','severe')),
  alarm_audible_db int not null check (alarm_audible_db between 0 and 120),
  alarm_function text not null check (alarm_function in ('pass','intermittent','fail')),
  overall_grade text not null check (overall_grade in ('A','B','C','D','F')),
  action_required text not null check (action_required in ('none','clean','recalibrate','replace_battery','replace_brake','retire_unit')),
  next_audit_due date not null,
  notes text
);

create table if not exists iv_stand_remediation_tickets_r3040 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid references smart_iv_stand_battery_audits_r3040(id) on delete cascade,
  ticket_status text not null check (ticket_status in ('open','assigned','in_progress','resolved','escalated','cancelled')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  defect_class text not null check (defect_class in ('battery','brake','wheel','hook','alarm','frame','electrical')),
  assigned_engineer text,
  eta_days int not null check (eta_days between 0 and 90),
  cost_estimate_rupees numeric(10,2) not null check (cost_estimate_rupees >= 0),
  parts_required text,
  resolution_summary text,
  customer_signoff text not null check (customer_signoff in ('pending','approved','rejected','na'))
);

alter table smart_iv_stand_battery_audits_r3040 enable row level security;
alter table iv_stand_remediation_tickets_r3040 enable row level security;

drop policy if exists founder_read_audits_r3040 on smart_iv_stand_battery_audits_r3040;
create policy founder_read_audits_r3040 on smart_iv_stand_battery_audits_r3040 for select to authenticated using (is_founder());

drop policy if exists founder_read_tickets_r3040 on iv_stand_remediation_tickets_r3040;
create policy founder_read_tickets_r3040 on iv_stand_remediation_tickets_r3040 for select to authenticated using (is_founder());

-- Seed: 18 audits
insert into smart_iv_stand_battery_audits_r3040 (ward_code, stand_serial, audit_month, engineer_name, battery_health_pct, battery_cycle_count, charge_hold_minutes, brake_lock_status, brake_torque_nm, wheel_swivel_status, pole_height_cm, load_test_kg, iv_hook_count, hook_corrosion, alarm_audible_db, alarm_function, overall_grade, action_required, next_audit_due, notes) values
('ICU-1','IV-A001','2026-06-01'::date,'Ravi K',92.5,148,420,'pass',14.20,'smooth',180,8.0,4,'none',78,'pass','A','none','2026-07-01'::date,'pristine'),
('ICU-1','IV-A002','2026-06-01'::date,'Ravi K',74.8,310,260,'degraded',9.80,'sticky',180,8.0,4,'light',72,'pass','B','clean','2026-07-01'::date,'wheel grease low'),
('ICU-2','IV-A003','2026-06-01'::date,'Sneha P',58.3,520,140,'fail',4.10,'seized',180,8.0,4,'moderate',60,'intermittent','D','replace_brake','2026-06-15'::date,'brake pad worn'),
('NICU','IV-N101','2026-06-02'::date,'Arjun M',88.0,180,380,'pass',13.10,'smooth',160,6.0,3,'none',80,'pass','A','none','2026-07-02'::date,null),
('NICU','IV-N102','2026-06-02'::date,'Arjun M',45.2,640,90,'pass',12.00,'smooth',160,6.0,3,'light',76,'pass','C','replace_battery','2026-06-20'::date,'battery EOL'),
('ER-A','IV-E201','2026-06-03'::date,'Priya S',95.0,90,440,'pass',15.00,'smooth',200,10.0,5,'none',82,'pass','A','none','2026-07-03'::date,'new unit'),
('ER-A','IV-E202','2026-06-03'::date,'Priya S',68.0,380,200,'degraded',8.50,'sticky',200,10.0,5,'light',74,'pass','B','recalibrate','2026-07-03'::date,null),
('Onco','IV-O301','2026-06-04'::date,'Kumar T',82.0,210,360,'pass',13.50,'smooth',190,8.0,4,'none',79,'pass','A','none','2026-07-04'::date,null),
('Onco','IV-O302','2026-06-04'::date,'Kumar T',30.5,820,50,'fail',3.20,'seized',190,8.0,4,'severe',55,'fail','F','retire_unit','2026-06-10'::date,'beyond repair'),
('Cardio','IV-C401','2026-06-05'::date,'Meera R',90.0,160,400,'pass',14.50,'smooth',180,8.0,4,'none',81,'pass','A','none','2026-07-05'::date,null),
('Cardio','IV-C402','2026-06-05'::date,'Meera R',62.0,440,180,'degraded',7.20,'sticky',180,8.0,4,'moderate',70,'intermittent','C','replace_brake','2026-06-25'::date,null),
('Peds','IV-P501','2026-06-06'::date,'Vikram L',86.0,200,370,'pass',13.80,'smooth',150,6.0,3,'none',80,'pass','A','none','2026-07-06'::date,null),
('Peds','IV-P502','2026-06-06'::date,'Vikram L',71.0,330,240,'pass',11.90,'sticky',150,6.0,3,'light',73,'pass','B','clean','2026-07-06'::date,null),
('Gen-W1','IV-G601','2026-06-07'::date,'Anita D',93.5,120,430,'pass',14.80,'smooth',180,8.0,4,'none',82,'pass','A','none','2026-07-07'::date,null),
('Gen-W1','IV-G602','2026-06-07'::date,'Anita D',54.0,560,120,'fail',5.00,'seized',180,8.0,4,'moderate',58,'intermittent','D','replace_brake','2026-06-18'::date,'brake disc cracked'),
('Gen-W2','IV-G701','2026-06-08'::date,'Rohit B',80.0,250,320,'pass',12.80,'smooth',180,8.0,4,'light',77,'pass','B','clean','2026-07-08'::date,null),
('Surg-A','IV-S801','2026-06-09'::date,'Lakshmi N',77.0,290,280,'degraded',9.10,'sticky',200,10.0,5,'light',75,'pass','B','recalibrate','2026-07-09'::date,null),
('Surg-A','IV-S802','2026-06-09'::date,'Lakshmi N',40.0,720,70,'fail',2.50,'seized',200,10.0,5,'severe',50,'fail','F','retire_unit','2026-06-12'::date,'frame bent');

-- Seed: 16 tickets
insert into iv_stand_remediation_tickets_r3040 (audit_id, ticket_status, priority, defect_class, assigned_engineer, eta_days, cost_estimate_rupees, parts_required, resolution_summary, customer_signoff) values
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-A002'),'in_progress','p2','wheel','Ravi K',3,450.00,'wheel grease kit',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-A003'),'assigned','p1','brake','Ravi K',5,2800.00,'brake assembly',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-N102'),'assigned','p1','battery','Arjun M',7,4200.00,'Li-ion battery pack',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-E202'),'open','p3','frame','Priya S',10,180.00,'calibration tool only',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-O302'),'escalated','p0','frame',null,2,15000.00,'full replacement','retire and procure new unit','approved'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-C402'),'in_progress','p2','brake','Meera R',4,2600.00,'brake pad kit',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-P502'),'resolved','p3','wheel','Vikram L',1,300.00,'lubricant','wheel greased and tested','approved'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-G602'),'assigned','p0','brake','Anita D',3,3100.00,'brake disc + pad',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-G701'),'resolved','p3','hook','Rohit B',1,150.00,'rust remover','hooks polished','approved'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-S801'),'in_progress','p2','electrical','Lakshmi N',5,800.00,'sensor module',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-S802'),'escalated','p0','frame',null,1,18000.00,'full replacement','frame bent beyond repair','approved'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-A002'),'resolved','p3','wheel','Ravi K',2,450.00,'wheel grease','greased and tested','approved'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-E202'),'cancelled','p3','alarm','Priya S',0,0.00,null,'false positive on prior audit','na'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-N101'),'resolved','p3','alarm','Arjun M',1,200.00,'speaker test','passed','approved'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-C401'),'open','p3','battery','Meera R',14,4200.00,'preventive replacement',null,'pending'),
((select id from smart_iv_stand_battery_audits_r3040 where stand_serial='IV-P501'),'resolved','p3','wheel','Vikram L',1,250.00,'lubricant','done','approved');

-- RPC 1: fleet summary
create or replace function rpc_r3040_fleet_summary()
returns table(total_audits int, total_stands int, grade_a int, grade_b int, grade_c int, grade_d int, grade_f int, avg_battery_pct numeric, retire_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    count(distinct stand_serial)::int,
    (count(*) filter (where overall_grade='A'))::int,
    (count(*) filter (where overall_grade='B'))::int,
    (count(*) filter (where overall_grade='C'))::int,
    (count(*) filter (where overall_grade='D'))::int,
    (count(*) filter (where overall_grade='F'))::int,
    round(avg(battery_health_pct),2),
    (count(*) filter (where action_required='retire_unit'))::int
  from smart_iv_stand_battery_audits_r3040;
end; $$;

-- RPC 2: ward breakdown
create or replace function rpc_r3040_ward_breakdown()
returns table(ward_code text, stand_count int, avg_battery numeric, fail_brakes int, retires int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.ward_code, count(*)::int, round(avg(a.battery_health_pct),2),
    (count(*) filter (where a.brake_lock_status='fail'))::int,
    (count(*) filter (where a.action_required='retire_unit'))::int
  from smart_iv_stand_battery_audits_r3040 a
  group by a.ward_code order by a.ward_code;
end; $$;

-- RPC 3: engineer scorecard
create or replace function rpc_r3040_engineer_scorecard()
returns table(engineer_name text, audits_done int, avg_grade_score numeric, retires_flagged int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name, count(*)::int,
    round(avg(case a.overall_grade when 'A' then 5 when 'B' then 4 when 'C' then 3 when 'D' then 2 else 1 end),2),
    (count(*) filter (where a.action_required='retire_unit'))::int
  from smart_iv_stand_battery_audits_r3040 a
  group by a.engineer_name order by a.engineer_name;
end; $$;

-- RPC 4: critical units (D/F grade)
create or replace function rpc_r3040_critical_units()
returns table(stand_serial text, ward_code text, overall_grade text, battery_health_pct numeric, brake_lock_status text, action_required text, next_audit_due date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.stand_serial, a.ward_code, a.overall_grade, a.battery_health_pct, a.brake_lock_status, a.action_required, a.next_audit_due
  from smart_iv_stand_battery_audits_r3040 a
  where a.overall_grade in ('D','F') order by a.overall_grade desc, a.battery_health_pct asc;
end; $$;

-- RPC 5: ticket status pipeline
create or replace function rpc_r3040_ticket_pipeline()
returns table(ticket_status text, count_total int, p0_count int, total_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.ticket_status, count(*)::int,
    (count(*) filter (where t.priority='p0'))::int,
    coalesce(sum(t.cost_estimate_rupees),0)
  from iv_stand_remediation_tickets_r3040 t
  group by t.ticket_status order by t.ticket_status;
end; $$;

-- RPC 6: defect class spend
create or replace function rpc_r3040_defect_class_spend()
returns table(defect_class text, ticket_count int, open_count int, total_cost numeric, avg_eta_days numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.defect_class, count(*)::int,
    (count(*) filter (where t.ticket_status in ('open','assigned','in_progress')))::int,
    coalesce(sum(t.cost_estimate_rupees),0),
    round(avg(t.eta_days),2)
  from iv_stand_remediation_tickets_r3040 t
  group by t.defect_class order by total_cost desc;
end; $$;

-- RPC 7: battery health distribution buckets
create or replace function rpc_r3040_battery_buckets()
returns table(bucket text, stand_count int, action_replace int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.bucket, count(*)::int,
    (count(*) filter (where a.action_required='replace_battery'))::int
  from smart_iv_stand_battery_audits_r3040 a
  join lateral (select case
    when a.battery_health_pct >= 85 then 'A_85_100'
    when a.battery_health_pct >= 70 then 'B_70_84'
    when a.battery_health_pct >= 50 then 'C_50_69'
    else 'D_below_50' end as bucket) b on true
  group by b.bucket order by b.bucket;
end; $$;

revoke all on function rpc_r3040_fleet_summary() from public, anon;
revoke all on function rpc_r3040_ward_breakdown() from public, anon;
revoke all on function rpc_r3040_engineer_scorecard() from public, anon;
revoke all on function rpc_r3040_critical_units() from public, anon;
revoke all on function rpc_r3040_ticket_pipeline() from public, anon;
revoke all on function rpc_r3040_defect_class_spend() from public, anon;
revoke all on function rpc_r3040_battery_buckets() from public, anon;

grant execute on function rpc_r3040_fleet_summary() to authenticated;
grant execute on function rpc_r3040_ward_breakdown() to authenticated;
grant execute on function rpc_r3040_engineer_scorecard() to authenticated;
grant execute on function rpc_r3040_critical_units() to authenticated;
grant execute on function rpc_r3040_ticket_pipeline() to authenticated;
grant execute on function rpc_r3040_defect_class_spend() to authenticated;
grant execute on function rpc_r3040_battery_buckets() to authenticated;
