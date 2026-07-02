-- Round r3046: Engineer Monthly Customer Site Patient-Hoist Battery Charger Health Audit
-- HEAVY ★★★★

create table if not exists patient_hoist_charger_audits_r3046 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_date date not null,
  customer_org text not null,
  city text not null,
  hoist_model text not null,
  charger_serial text not null,
  engineer_name text not null,
  audit_status text not null check (audit_status in ('pass','warn','fail','retest_due')),
  battery_health_pct numeric(5,2) not null check (battery_health_pct >= 0 and battery_health_pct <= 100),
  charge_cycles_count int not null check (charge_cycles_count >= 0),
  output_voltage_v numeric(6,2) not null check (output_voltage_v >= 0),
  ripple_mv numeric(6,2) not null check (ripple_mv >= 0),
  ambient_temp_c numeric(5,2) not null check (ambient_temp_c >= -10 and ambient_temp_c <= 80),
  fault_code text,
  remediation_note text,
  next_audit_due_on date not null
);

alter table patient_hoist_charger_audits_r3046 enable row level security;
drop policy if exists pol_r3046_audits_select on patient_hoist_charger_audits_r3046;
create policy pol_r3046_audits_select on patient_hoist_charger_audits_r3046 for select using (is_founder());

insert into patient_hoist_charger_audits_r3046 (audit_date, customer_org, city, hoist_model, charger_serial, engineer_name, audit_status, battery_health_pct, charge_cycles_count, output_voltage_v, ripple_mv, ambient_temp_c, fault_code, remediation_note, next_audit_due_on) values
('2026-06-01'::date,'Apollo Hyd','Hyderabad','Arjo Maxi-Sky 2','CHG-AS2-1001','Ravi K','pass',96.50,142,27.40,18.20,28.50,null,'Clean'::text,'2026-07-01'::date),
('2026-06-02'::date,'Yashoda Sec','Hyderabad','Arjo Maxi-Sky 2','CHG-AS2-1002','Suresh P','warn',82.10,612,27.10,42.50,31.20,'E-RIPPLE-HI','Capacitor aging'::text,'2026-06-16'::date),
('2026-06-03'::date,'KIMS Sec','Hyderabad','Hill-Rom Liko','CHG-LIKO-2010','Anil M','pass',91.80,288,27.60,19.80,27.10,null,'Within spec'::text,'2026-07-03'::date),
('2026-06-03'::date,'Manipal BLR','Bengaluru','Guldmann GH3','CHG-GH3-3301','Pradeep R','fail',58.40,1422,26.20,68.10,33.80,'E-CAP-FAIL','Replace charger'::text,'2026-06-10'::date),
('2026-06-04'::date,'Fortis BLR','Bengaluru','Arjo Maxi-Sky 2','CHG-AS2-1015','Mahesh G','pass',94.20,201,27.50,20.10,29.40,null,'Good'::text,'2026-07-04'::date),
('2026-06-05'::date,'Narayana BLR','Bengaluru','Hill-Rom Liko','CHG-LIKO-2025','Kiran V','warn',76.90,855,27.00,38.40,30.50,'E-VOLT-LOW','Monitor cycles'::text,'2026-06-19'::date),
('2026-06-05'::date,'Apollo CHN','Chennai','Guldmann GH3','CHG-GH3-3340','Vamsi S','pass',88.70,420,27.30,22.50,28.90,null,'OK'::text,'2026-07-05'::date),
('2026-06-06'::date,'MIOT CHN','Chennai','Arjo Maxi-Sky 2','CHG-AS2-1030','Lokesh B','fail',49.10,1810,25.80,72.30,35.20,'E-OVERTEMP','Hot environment + worn'::text,'2026-06-13'::date),
('2026-06-07'::date,'Lilavati MUM','Mumbai','Hill-Rom Liko','CHG-LIKO-2040','Naveen J','pass',93.40,165,27.55,17.90,27.80,null,'Excellent'::text,'2026-07-07'::date),
('2026-06-08'::date,'Hinduja MUM','Mumbai','Guldmann GH3','CHG-GH3-3380','Rajesh T','retest_due',71.20,1010,26.90,45.60,31.60,'E-CYCLE-HI','Schedule retest'::text,'2026-06-15'::date),
('2026-06-09'::date,'Kokilaben MUM','Mumbai','Arjo Maxi-Sky 2','CHG-AS2-1055','Harish L','pass',89.50,355,27.45,21.20,29.10,null,'Pass'::text,'2026-07-09'::date),
('2026-06-10'::date,'Max DEL','Delhi','Hill-Rom Liko','CHG-LIKO-2055','Arun D','warn',79.80,720,27.15,36.80,30.20,'E-RIPPLE-MED','Watch ripple'::text,'2026-06-24'::date),
('2026-06-11'::date,'Medanta DEL','Delhi','Guldmann GH3','CHG-GH3-3415','Sandeep K','pass',92.10,260,27.50,19.40,28.30,null,'Good'::text,'2026-07-11'::date),
('2026-06-12'::date,'AIIMS DEL','Delhi','Arjo Maxi-Sky 2','CHG-AS2-1070','Vinay M','fail',54.80,1620,26.10,71.20,34.40,'E-CAP-FAIL','Replace immediately'::text,'2026-06-19'::date),
('2026-06-13'::date,'Apollo Hyd','Hyderabad','Hill-Rom Liko','CHG-LIKO-2070','Ravi K','pass',95.20,180,27.55,18.50,28.10,null,'Clean'::text,'2026-07-13'::date),
('2026-06-14'::date,'Yashoda Sec','Hyderabad','Guldmann GH3','CHG-GH3-3450','Suresh P','warn',74.30,930,26.80,44.20,32.10,'E-VOLT-LOW','Aging'::text,'2026-06-28'::date),
('2026-06-15'::date,'Fortis BLR','Bengaluru','Arjo Maxi-Sky 2','CHG-AS2-1090','Mahesh G','pass',90.80,310,27.40,20.80,29.60,null,'Pass'::text,'2026-07-15'::date),
('2026-06-16'::date,'Manipal BLR','Bengaluru','Hill-Rom Liko','CHG-LIKO-2090','Anil M','retest_due',68.50,1120,26.70,48.10,31.80,'E-CYCLE-HI','Retest in 7d'::text,'2026-06-23'::date),
('2026-06-17'::date,'Apollo CHN','Chennai','Guldmann GH3','CHG-GH3-3490','Vamsi S','pass',87.40,470,27.30,23.10,29.20,null,'OK'::text,'2026-07-17'::date),
('2026-06-18'::date,'MIOT CHN','Chennai','Arjo Maxi-Sky 2','CHG-AS2-1110','Lokesh B','warn',77.60,810,27.05,39.50,30.80,'E-RIPPLE-MED','Monitor'::text,'2026-07-02'::date),
('2026-06-19'::date,'Lilavati MUM','Mumbai','Hill-Rom Liko','CHG-LIKO-2110','Naveen J','pass',94.80,150,27.60,17.40,27.60,null,'Excellent'::text,'2026-07-19'::date),
('2026-06-20'::date,'Hinduja MUM','Mumbai','Guldmann GH3','CHG-GH3-3530','Rajesh T','fail',51.20,1750,25.90,69.80,34.90,'E-OVERTEMP','Replace + cool room'::text,'2026-06-27'::date);

create table if not exists charger_remediation_actions_r3046 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  action_date date not null,
  customer_org text not null,
  charger_serial text not null,
  action_type text not null check (action_type in ('replace_charger','replace_battery','firmware_update','cap_replacement','clean_contacts','escalate_oem','schedule_retest')),
  priority text not null check (priority in ('p0','p1','p2','p3')),
  status text not null check (status in ('open','in_progress','done','blocked')),
  cost_rupees numeric(10,2) not null check (cost_rupees >= 0),
  engineer_name text not null,
  sla_due_on date not null,
  notes text
);

alter table charger_remediation_actions_r3046 enable row level security;
drop policy if exists pol_r3046_actions_select on charger_remediation_actions_r3046;
create policy pol_r3046_actions_select on charger_remediation_actions_r3046 for select using (is_founder());

insert into charger_remediation_actions_r3046 (action_date, customer_org, charger_serial, action_type, priority, status, cost_rupees, engineer_name, sla_due_on, notes) values
('2026-06-03'::date,'Manipal BLR','CHG-GH3-3301','replace_charger','p0','done',18500.00,'Pradeep R','2026-06-10'::date,'Swapped from spare pool'),
('2026-06-06'::date,'MIOT CHN','CHG-AS2-1030','replace_charger','p0','done',16800.00,'Lokesh B','2026-06-13'::date,'OEM swap'),
('2026-06-12'::date,'AIIMS DEL','CHG-AS2-1070','replace_charger','p0','in_progress',17200.00,'Vinay M','2026-06-19'::date,'Awaiting customer signoff'),
('2026-06-20'::date,'Hinduja MUM','CHG-GH3-3530','replace_charger','p0','open',19400.00,'Rajesh T','2026-06-27'::date,'OEM lead-time 5d'),
('2026-06-02'::date,'Yashoda Sec','CHG-AS2-1002','cap_replacement','p2','done',2400.00,'Suresh P','2026-06-16'::date,'Cap kit on hand'),
('2026-06-05'::date,'Narayana BLR','CHG-LIKO-2025','firmware_update','p2','done',0.00,'Kiran V','2026-06-19'::date,'OEM firmware v3.1'),
('2026-06-10'::date,'Hinduja MUM','CHG-GH3-3380','schedule_retest','p1','in_progress',0.00,'Rajesh T','2026-06-15'::date,'Retest booked'),
('2026-06-11'::date,'Max DEL','CHG-LIKO-2055','clean_contacts','p3','done',350.00,'Arun D','2026-06-24'::date,'Oxidation removed'),
('2026-06-14'::date,'Yashoda Sec','CHG-GH3-3450','cap_replacement','p2','in_progress',2600.00,'Suresh P','2026-06-28'::date,'Awaiting parts'),
('2026-06-16'::date,'Manipal BLR','CHG-LIKO-2090','schedule_retest','p1','open',0.00,'Anil M','2026-06-23'::date,'Customer travel'),
('2026-06-18'::date,'MIOT CHN','CHG-AS2-1110','firmware_update','p2','open',0.00,'Lokesh B','2026-07-02'::date,'Need OEM token'),
('2026-06-09'::date,'Kokilaben MUM','CHG-AS2-1055','clean_contacts','p3','done',350.00,'Harish L','2026-07-09'::date,'Routine'),
('2026-06-04'::date,'Fortis BLR','CHG-AS2-1015','clean_contacts','p3','done',350.00,'Mahesh G','2026-07-04'::date,'Routine'),
('2026-06-08'::date,'Lilavati MUM','CHG-LIKO-2040','firmware_update','p3','done',0.00,'Naveen J','2026-07-07'::date,'Minor patch'),
('2026-06-19'::date,'Lilavati MUM','CHG-LIKO-2110','clean_contacts','p3','done',350.00,'Naveen J','2026-07-19'::date,'Clean'),
('2026-06-13'::date,'Apollo Hyd','CHG-LIKO-2070','firmware_update','p3','done',0.00,'Ravi K','2026-07-13'::date,'Patch'),
('2026-06-15'::date,'Fortis BLR','CHG-AS2-1090','clean_contacts','p3','done',350.00,'Mahesh G','2026-07-15'::date,'OK'),
('2026-06-17'::date,'Apollo CHN','CHG-GH3-3490','firmware_update','p3','done',0.00,'Vamsi S','2026-07-17'::date,'OK'),
('2026-06-11'::date,'Medanta DEL','CHG-GH3-3415','clean_contacts','p3','done',350.00,'Sandeep K','2026-07-11'::date,'OK');

revoke all on patient_hoist_charger_audits_r3046 from public, anon;
revoke all on charger_remediation_actions_r3046 from public, anon;
grant select on patient_hoist_charger_audits_r3046 to authenticated;
grant select on charger_remediation_actions_r3046 to authenticated;

-- RPC 1: status mix
create or replace function r3046_status_mix()
returns table(audit_status text, n int, avg_battery numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.audit_status, count(*)::int, round(avg(a.battery_health_pct),2)
  from patient_hoist_charger_audits_r3046 a
  group by a.audit_status order by count(*) desc;
end$$;

-- RPC 2: city rollup
create or replace function r3046_city_rollup()
returns table(city text, audits int, fails int, warns int, avg_health numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.city,
    count(*)::int,
    (count(*) filter (where a.audit_status='fail'))::int,
    (count(*) filter (where a.audit_status='warn'))::int,
    round(avg(a.battery_health_pct),2)
  from patient_hoist_charger_audits_r3046 a
  group by a.city order by count(*) desc;
end$$;

-- RPC 3: model risk
create or replace function r3046_model_risk()
returns table(hoist_model text, n int, fail_rate_pct numeric, avg_cycles numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.hoist_model,
    count(*)::int,
    round(100.0*(count(*) filter (where a.audit_status='fail'))::numeric / nullif(count(*),0),2),
    round(avg(a.charge_cycles_count),0)
  from patient_hoist_charger_audits_r3046 a
  group by a.hoist_model order by count(*) desc;
end$$;

-- RPC 4: engineer scorecard
create or replace function r3046_engineer_scorecard()
returns table(engineer_name text, audits int, passes int, fails int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.engineer_name,
    count(*)::int,
    (count(*) filter (where a.audit_status='pass'))::int,
    (count(*) filter (where a.audit_status='fail'))::int
  from patient_hoist_charger_audits_r3046 a
  group by a.engineer_name order by count(*) desc;
end$$;

-- RPC 5: failing chargers
create or replace function r3046_failing_chargers()
returns table(audit_date date, customer_org text, charger_serial text, battery_health_pct numeric, fault_code text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.audit_date, a.customer_org, a.charger_serial, a.battery_health_pct, a.fault_code
  from patient_hoist_charger_audits_r3046 a
  where a.audit_status in ('fail','retest_due')
  order by a.audit_date desc;
end$$;

-- RPC 6: remediation open
create or replace function r3046_remediation_open()
returns table(action_date date, customer_org text, action_type text, priority text, status text, sla_due_on date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select r.action_date, r.customer_org, r.action_type, r.priority, r.status, r.sla_due_on
  from charger_remediation_actions_r3046 r
  where r.status in ('open','in_progress','blocked')
  order by r.priority, r.sla_due_on;
end$$;

-- RPC 7: remediation spend
create or replace function r3046_remediation_spend()
returns table(action_type text, n int, total_cost numeric, avg_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select r.action_type, count(*)::int, round(sum(r.cost_rupees),2), round(avg(r.cost_rupees),2)
  from charger_remediation_actions_r3046 r
  group by r.action_type order by sum(r.cost_rupees) desc;
end$$;

-- RPC 8: upcoming retests
create or replace function r3046_upcoming_retests()
returns table(next_audit_due_on date, customer_org text, charger_serial text, audit_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.next_audit_due_on, a.customer_org, a.charger_serial, a.audit_status
  from patient_hoist_charger_audits_r3046 a
  where a.next_audit_due_on <= (now()::date + 30)
  order by a.next_audit_due_on;
end$$;

revoke all on function r3046_status_mix() from public, anon;
revoke all on function r3046_city_rollup() from public, anon;
revoke all on function r3046_model_risk() from public, anon;
revoke all on function r3046_engineer_scorecard() from public, anon;
revoke all on function r3046_failing_chargers() from public, anon;
revoke all on function r3046_remediation_open() from public, anon;
revoke all on function r3046_remediation_spend() from public, anon;
revoke all on function r3046_upcoming_retests() from public, anon;
grant execute on function r3046_status_mix() to authenticated;
grant execute on function r3046_city_rollup() to authenticated;
grant execute on function r3046_model_risk() to authenticated;
grant execute on function r3046_engineer_scorecard() to authenticated;
grant execute on function r3046_failing_chargers() to authenticated;
grant execute on function r3046_remediation_open() to authenticated;
grant execute on function r3046_remediation_spend() to authenticated;
grant execute on function r3046_upcoming_retests() to authenticated;
