-- Round 3058 — Engineer Monthly Customer Site Surgical Suction Canister Float-Sensor & Pump Audit

create table if not exists suction_canister_units_r3058 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_name text not null,
  city text not null,
  ward_or_or text not null,
  unit_serial text not null,
  canister_model text not null,
  pump_model text not null,
  install_date date not null,
  last_audit_date date not null,
  next_audit_due_date date not null,
  float_sensor_status text not null check (float_sensor_status in ('healthy','sticky','intermittent','failed')),
  pump_vacuum_status text not null check (pump_vacuum_status in ('green','yellow','red')),
  overflow_protection_status text not null check (overflow_protection_status in ('passed','marginal','failed')),
  risk_band text not null check (risk_band in ('low','medium','high','critical')),
  assigned_engineer text not null,
  measured_vacuum_kpa int not null check (measured_vacuum_kpa between 0 and 120),
  float_response_ms int not null check (float_response_ms between 50 and 5000),
  amc_active boolean not null default true
);

create table if not exists suction_audit_findings_r3058 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  unit_id uuid not null references suction_canister_units_r3058(id) on delete cascade,
  audit_date date not null,
  engineer_name text not null,
  finding_type text not null check (finding_type in ('float_stuck','seal_leak','vacuum_low','overflow_breach','tubing_kink','filter_blocked','calibration_drift','none')),
  severity text not null check (severity in ('info','minor','major','critical')),
  resolution text not null check (resolution in ('cleaned','part_replaced','recalibrated','escalated','pending')),
  parts_cost_rupees int not null check (parts_cost_rupees >= 0),
  labor_minutes int not null check (labor_minutes between 0 and 480),
  patient_safety_flag boolean not null default false,
  customer_rating int check (customer_rating between 1 and 5),
  notes text
);

alter table suction_canister_units_r3058 enable row level security;
alter table suction_audit_findings_r3058 enable row level security;

drop policy if exists scu_r3058_founder_all on suction_canister_units_r3058;
create policy scu_r3058_founder_all on suction_canister_units_r3058 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists saf_r3058_founder_all on suction_audit_findings_r3058;
create policy saf_r3058_founder_all on suction_audit_findings_r3058 for all to authenticated using (is_founder()) with check (is_founder());

insert into suction_canister_units_r3058 (hospital_name, city, ward_or_or, unit_serial, canister_model, pump_model, install_date, last_audit_date, next_audit_due_date, float_sensor_status, pump_vacuum_status, overflow_protection_status, risk_band, assigned_engineer, measured_vacuum_kpa, float_response_ms, amc_active) values
('Apollo Jubilee','Hyderabad','OR-1','SCU-3058-001','Medela Vario 18','Medela Vario','2025-02-14'::date,'2026-05-22'::date,'2026-06-22'::date,'healthy','green','passed','low','Ramesh K',85,180,true),
('KIMS Secunderabad','Hyderabad','OR-3','SCU-3058-002','Atmos S 351','Atmos S 351','2025-03-08'::date,'2026-04-18'::date,'2026-05-18'::date,'sticky','yellow','marginal','medium','Suresh M',62,820,true),
('Yashoda Somajiguda','Hyderabad','ICU-2','SCU-3058-003','Drager Aspirator','Drager','2025-04-20'::date,'2026-03-25'::date,'2026-04-25'::date,'intermittent','red','failed','critical','Anil G',38,2400,true),
('Care Banjara','Hyderabad','OR-2','SCU-3058-004','Medela Dominant 50','Medela Dominant','2025-05-11'::date,'2026-06-05'::date,'2026-07-05'::date,'healthy','green','passed','low','Ramesh K',92,160,true),
('Citizens Nallagandla','Hyderabad','Recovery','SCU-3058-005','Atmos C 451','Atmos C 451','2025-06-19'::date,'2026-05-12'::date,'2026-06-12'::date,'sticky','yellow','marginal','medium','Vinod P',58,950,true),
('Continental Gachibowli','Hyderabad','OR-4','SCU-3058-006','Medela Vario 18','Medela Vario','2025-07-25'::date,'2026-02-08'::date,'2026-03-08'::date,'failed','red','failed','critical','Anil G',22,4200,true),
('AIG Gachibowli','Hyderabad','Endo Suite','SCU-3058-007','Medela Dominant 50','Medela Dominant','2025-08-30'::date,'2026-06-14'::date,'2026-07-14'::date,'healthy','green','passed','low','Ramesh K',88,170,true),
('Medicover Hitech','Hyderabad','OR-1','SCU-3058-008','Atmos S 351','Atmos S 351','2025-09-12'::date,'2026-05-20'::date,'2026-06-20'::date,'sticky','yellow','passed','medium','Suresh M',66,720,true),
('Star Banjara','Hyderabad','ICU-1','SCU-3058-009','Drager Aspirator','Drager','2025-10-18'::date,'2026-04-22'::date,'2026-05-22'::date,'intermittent','red','marginal','high','Vinod P',44,1850,false),
('Sunshine Secunderabad','Hyderabad','OR-2','SCU-3058-010','Medela Vario 18','Medela Vario','2025-11-22'::date,'2026-06-09'::date,'2026-07-09'::date,'healthy','green','passed','low','Ramesh K',90,175,true),
('Manipal Tadepalli','Vijayawada','OR-3','SCU-3058-011','Atmos C 451','Atmos C 451','2026-01-04'::date,'2026-05-30'::date,'2026-06-30'::date,'sticky','yellow','marginal','medium','Karthik R',60,890,true),
('NRI Chinakakani','Guntur','ICU-3','SCU-3058-012','Medela Dominant 50','Medela Dominant','2026-01-19'::date,'2026-02-22'::date,'2026-03-22'::date,'failed','red','failed','critical','Karthik R',18,4500,true),
('Apollo Visakhapatnam','Visakhapatnam','OR-1','SCU-3058-013','Medela Vario 18','Medela Vario','2026-02-14'::date,'2026-06-11'::date,'2026-07-11'::date,'healthy','green','passed','low','Praveen D',86,165,true),
('Care Vizag','Visakhapatnam','OR-2','SCU-3058-014','Atmos S 351','Atmos S 351','2026-02-28'::date,'2026-05-26'::date,'2026-06-26'::date,'sticky','yellow','marginal','medium','Praveen D',64,780,true),
('Aster Prime Ameerpet','Hyderabad','Recovery','SCU-3058-015','Drager Aspirator','Drager','2026-03-15'::date,'2026-04-28'::date,'2026-05-28'::date,'intermittent','red','marginal','high','Ramesh K',46,1620,true),
('Olive Tolichowki','Hyderabad','OR-1','SCU-3058-016','Medela Dominant 50','Medela Dominant','2026-03-29'::date,'2026-06-13'::date,'2026-07-13'::date,'healthy','green','passed','low','Suresh M',91,155,true),
('Virinchi Banjara','Hyderabad','ICU-2','SCU-3058-017','Atmos C 451','Atmos C 451','2026-04-10'::date,'2026-05-24'::date,'2026-06-24'::date,'sticky','yellow','passed','medium','Anil G',63,810,true),
('Renova Sarojini','Hyderabad','OR-4','SCU-3058-018','Medela Vario 18','Medela Vario','2026-04-22'::date,'2026-03-15'::date,'2026-04-15'::date,'failed','red','failed','critical','Vinod P',24,4100,true);

insert into suction_audit_findings_r3058 (unit_id, audit_date, engineer_name, finding_type, severity, resolution, parts_cost_rupees, labor_minutes, patient_safety_flag, customer_rating, notes)
select id,'2026-05-22'::date,'Ramesh K','none','info','cleaned',0,30,false,5,'all green' from suction_canister_units_r3058 where unit_serial='SCU-3058-001'
union all select id,'2026-04-18'::date,'Suresh M','float_stuck','minor','cleaned',150,45,false,4,'cleaned residue' from suction_canister_units_r3058 where unit_serial='SCU-3058-002'
union all select id,'2026-03-25'::date,'Anil G','overflow_breach','critical','escalated',3800,180,true,2,'patient safety incident' from suction_canister_units_r3058 where unit_serial='SCU-3058-003'
union all select id,'2026-06-05'::date,'Ramesh K','none','info','cleaned',0,28,false,5,null from suction_canister_units_r3058 where unit_serial='SCU-3058-004'
union all select id,'2026-05-12'::date,'Vinod P','seal_leak','minor','part_replaced',420,55,false,4,'gasket swap' from suction_canister_units_r3058 where unit_serial='SCU-3058-005'
union all select id,'2026-02-08'::date,'Anil G','vacuum_low','critical','escalated',5200,240,true,1,'pump failure full' from suction_canister_units_r3058 where unit_serial='SCU-3058-006'
union all select id,'2026-06-14'::date,'Ramesh K','none','info','cleaned',0,32,false,5,null from suction_canister_units_r3058 where unit_serial='SCU-3058-007'
union all select id,'2026-05-20'::date,'Suresh M','float_stuck','minor','cleaned',180,42,false,4,null from suction_canister_units_r3058 where unit_serial='SCU-3058-008'
union all select id,'2026-04-22'::date,'Vinod P','calibration_drift','major','recalibrated',900,95,false,3,'recalibrated vacuum' from suction_canister_units_r3058 where unit_serial='SCU-3058-009'
union all select id,'2026-06-09'::date,'Ramesh K','none','info','cleaned',0,30,false,5,null from suction_canister_units_r3058 where unit_serial='SCU-3058-010'
union all select id,'2026-05-30'::date,'Karthik R','tubing_kink','minor','part_replaced',280,38,false,4,'tubing replaced' from suction_canister_units_r3058 where unit_serial='SCU-3058-011'
union all select id,'2026-02-22'::date,'Karthik R','overflow_breach','critical','escalated',4600,300,true,1,'full unit replace' from suction_canister_units_r3058 where unit_serial='SCU-3058-012'
union all select id,'2026-06-11'::date,'Praveen D','none','info','cleaned',0,29,false,5,null from suction_canister_units_r3058 where unit_serial='SCU-3058-013'
union all select id,'2026-05-26'::date,'Praveen D','filter_blocked','minor','part_replaced',320,40,false,4,'pre-filter swap' from suction_canister_units_r3058 where unit_serial='SCU-3058-014'
union all select id,'2026-04-28'::date,'Ramesh K','calibration_drift','major','recalibrated',850,85,false,3,'sensor drift' from suction_canister_units_r3058 where unit_serial='SCU-3058-015'
union all select id,'2026-06-13'::date,'Suresh M','none','info','cleaned',0,27,false,5,null from suction_canister_units_r3058 where unit_serial='SCU-3058-016'
union all select id,'2026-05-24'::date,'Anil G','seal_leak','minor','part_replaced',390,48,false,4,null from suction_canister_units_r3058 where unit_serial='SCU-3058-017'
union all select id,'2026-03-15'::date,'Vinod P','vacuum_low','critical','escalated',5400,260,true,1,'pump red zone' from suction_canister_units_r3058 where unit_serial='SCU-3058-018';

-- RPC 1: roster
create or replace function founder_r3058_unit_roster()
returns table(hospital_name text, city text, ward_or_or text, unit_serial text, canister_model text, pump_model text, float_sensor_status text, pump_vacuum_status text, overflow_protection_status text, risk_band text, assigned_engineer text, measured_vacuum_kpa int, float_response_ms int, next_audit_due_date date, amc_active boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select u.hospital_name,u.city,u.ward_or_or,u.unit_serial,u.canister_model,u.pump_model,u.float_sensor_status,u.pump_vacuum_status,u.overflow_protection_status,u.risk_band,u.assigned_engineer,u.measured_vacuum_kpa,u.float_response_ms,u.next_audit_due_date,u.amc_active
    from suction_canister_units_r3058 u order by case u.risk_band when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end, u.next_audit_due_date;
end$$;

-- RPC 2: risk-band rollup
create or replace function founder_r3058_risk_rollup()
returns table(risk_band text, units int, critical_findings int, patient_safety_incidents int, avg_vacuum_kpa numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select u.risk_band,
    count(*)::int as units,
    (count(*) filter (where exists (select 1 from suction_audit_findings_r3058 f where f.unit_id=u.id and f.severity='critical')))::int as critical_findings,
    (count(*) filter (where exists (select 1 from suction_audit_findings_r3058 f where f.unit_id=u.id and f.patient_safety_flag=true)))::int as patient_safety_incidents,
    round(avg(u.measured_vacuum_kpa)::numeric,1) as avg_vacuum_kpa
  from suction_canister_units_r3058 u group by u.risk_band order by case u.risk_band when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end$$;

-- RPC 3: overdue audits
create or replace function founder_r3058_overdue_audits()
returns table(hospital_name text, unit_serial text, ward_or_or text, assigned_engineer text, next_audit_due_date date, days_overdue int, risk_band text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select u.hospital_name,u.unit_serial,u.ward_or_or,u.assigned_engineer,u.next_audit_due_date,
    greatest(0,('2026-06-30'::date - u.next_audit_due_date))::int as days_overdue, u.risk_band
    from suction_canister_units_r3058 u where u.next_audit_due_date < '2026-06-30'::date order by u.next_audit_due_date;
end$$;

-- RPC 4: engineer scorecard
create or replace function founder_r3058_engineer_scorecard()
returns table(engineer_name text, units_assigned int, audits_completed int, critical_findings int, avg_rating numeric, avg_labor_minutes numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select u.assigned_engineer as engineer_name,
    count(distinct u.id)::int as units_assigned,
    count(f.id)::int as audits_completed,
    (count(f.id) filter (where f.severity='critical'))::int as critical_findings,
    round(avg(f.customer_rating)::numeric,2) as avg_rating,
    round(avg(f.labor_minutes)::numeric,1) as avg_labor_minutes
    from suction_canister_units_r3058 u left join suction_audit_findings_r3058 f on f.unit_id=u.id
    group by u.assigned_engineer order by critical_findings desc, engineer_name;
end$$;

-- RPC 5: failure-mode pareto
create or replace function founder_r3058_failure_mode_pareto()
returns table(finding_type text, occurrences int, criticals int, parts_spend_rupees int, labor_minutes_total int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.finding_type,
    count(*)::int as occurrences,
    (count(*) filter (where f.severity='critical'))::int as criticals,
    coalesce(sum(f.parts_cost_rupees),0)::int as parts_spend_rupees,
    coalesce(sum(f.labor_minutes),0)::int as labor_minutes_total
    from suction_audit_findings_r3058 f group by f.finding_type order by occurrences desc;
end$$;

-- RPC 6: patient safety incidents
create or replace function founder_r3058_patient_safety_incidents()
returns table(hospital_name text, unit_serial text, ward_or_or text, audit_date date, engineer_name text, finding_type text, severity text, resolution text, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select u.hospital_name,u.unit_serial,u.ward_or_or,f.audit_date,f.engineer_name,f.finding_type,f.severity,f.resolution,f.notes
    from suction_audit_findings_r3058 f join suction_canister_units_r3058 u on u.id=f.unit_id
    where f.patient_safety_flag=true order by f.audit_date desc;
end$$;

-- RPC 7: city heat
create or replace function founder_r3058_city_heat()
returns table(city text, units int, criticals int, avg_float_response_ms numeric, total_parts_spend int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select u.city,
    count(*)::int as units,
    (count(*) filter (where u.risk_band='critical'))::int as criticals,
    round(avg(u.float_response_ms)::numeric,1) as avg_float_response_ms,
    coalesce((select sum(f.parts_cost_rupees) from suction_audit_findings_r3058 f join suction_canister_units_r3058 u2 on u2.id=f.unit_id where u2.city=u.city),0)::int as total_parts_spend
    from suction_canister_units_r3058 u group by u.city order by criticals desc, units desc;
end$$;

-- RPC 8: monthly trend
create or replace function founder_r3058_monthly_trend()
returns table(month text, findings int, criticals int, patient_safety int, parts_spend int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select to_char(date_trunc('month',f.audit_date),'YYYY-MM') as month,
    count(*)::int as findings,
    (count(*) filter (where f.severity='critical'))::int as criticals,
    (count(*) filter (where f.patient_safety_flag=true))::int as patient_safety,
    coalesce(sum(f.parts_cost_rupees),0)::int as parts_spend
    from suction_audit_findings_r3058 f group by 1 order by 1;
end$$;

revoke all on function founder_r3058_unit_roster() from public, anon;
revoke all on function founder_r3058_risk_rollup() from public, anon;
revoke all on function founder_r3058_overdue_audits() from public, anon;
revoke all on function founder_r3058_engineer_scorecard() from public, anon;
revoke all on function founder_r3058_failure_mode_pareto() from public, anon;
revoke all on function founder_r3058_patient_safety_incidents() from public, anon;
revoke all on function founder_r3058_city_heat() from public, anon;
revoke all on function founder_r3058_monthly_trend() from public, anon;

grant execute on function founder_r3058_unit_roster() to authenticated;
grant execute on function founder_r3058_risk_rollup() to authenticated;
grant execute on function founder_r3058_overdue_audits() to authenticated;
grant execute on function founder_r3058_engineer_scorecard() to authenticated;
grant execute on function founder_r3058_failure_mode_pareto() to authenticated;
grant execute on function founder_r3058_patient_safety_incidents() to authenticated;
grant execute on function founder_r3058_city_heat() to authenticated;
grant execute on function founder_r3058_monthly_trend() to authenticated;
