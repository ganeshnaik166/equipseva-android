-- Round r3010: Engineer Monthly Customer Site OR Temperature & Humidity Logger Audit
-- Founder console for tracking monthly OR environmental compliance audits at hospital customer sites

create table if not exists or_temp_humidity_logger_audits_r3010 (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null unique,
  customer_site text not null,
  hospital_city text not null,
  operating_room_label text not null,
  engineer_name text not null,
  audit_month date not null,
  audit_status text not null check (audit_status in ('scheduled','in_progress','completed','overdue','cancelled')),
  logger_make text not null check (logger_make in ('testo','rotronic','vaisala','onset','tsi','elitech')),
  logger_serial text not null,
  calibration_due_date date,
  last_calibration_date date,
  visit_outcome text not null check (visit_outcome in ('pass','conditional_pass','fail','reaudit_required')),
  compliance_score_pct numeric(5,2) not null check (compliance_score_pct >= 0 and compliance_score_pct <= 100),
  temp_range_compliant boolean not null,
  humidity_range_compliant boolean not null,
  nabh_clause_ref text not null,
  followup_required boolean not null,
  followup_due_date date,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists or_temp_humidity_logger_readings_r3010 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references or_temp_humidity_logger_audits_r3010(id) on delete cascade,
  reading_timestamp timestamptz not null,
  temperature_celsius numeric(5,2) not null,
  humidity_percent numeric(5,2) not null,
  temp_within_limits boolean not null,
  humidity_within_limits boolean not null,
  reading_severity text not null check (reading_severity in ('normal','warning','critical','sensor_error')),
  excursion_minutes int not null default 0,
  corrective_action text not null check (corrective_action in ('none','adjusted_hvac','replaced_sensor','escalated','flagged_for_review')),
  flagged_for_review boolean not null,
  created_at timestamptz not null default now()
);

alter table or_temp_humidity_logger_audits_r3010 enable row level security;
alter table or_temp_humidity_logger_readings_r3010 enable row level security;

drop policy if exists founder_read_audits_r3010 on or_temp_humidity_logger_audits_r3010;
create policy founder_read_audits_r3010 on or_temp_humidity_logger_audits_r3010 for select to authenticated using (is_founder());

drop policy if exists founder_read_readings_r3010 on or_temp_humidity_logger_readings_r3010;
create policy founder_read_readings_r3010 on or_temp_humidity_logger_readings_r3010 for select to authenticated using (is_founder());

-- Seed audits (18 rows)
insert into or_temp_humidity_logger_audits_r3010 (audit_code, customer_site, hospital_city, operating_room_label, engineer_name, audit_month, audit_status, logger_make, logger_serial, calibration_due_date, last_calibration_date, visit_outcome, compliance_score_pct, temp_range_compliant, humidity_range_compliant, nabh_clause_ref, followup_required, followup_due_date, notes)
select 'OR-AUD-3010-001','Apollo Jubilee Hills','Hyderabad','OR-1 Cardiac','Ravi Kumar','2026-06-01'::date,'completed','testo','TST-1001','2026-12-15'::date,'2026-06-15'::date,'pass',98.50,true,true,'NABH-FMS-3.2',false,null::date,'All zones in spec'
union all select 'OR-AUD-3010-002','Yashoda Somajiguda','Hyderabad','OR-2 Ortho','Priya Sharma','2026-06-01'::date,'completed','rotronic','RTR-2202','2027-01-10'::date,'2026-01-10'::date,'conditional_pass',87.20,true,false,'NABH-FMS-3.2',true,'2026-07-15'::date,'RH spiked 3x'
union all select 'OR-AUD-3010-003','KIMS Secunderabad','Hyderabad','OR-3 Neuro','Arjun Reddy','2026-06-01'::date,'completed','vaisala','VSL-3003','2026-11-20'::date,'2026-05-20'::date,'pass',96.80,true,true,'NABH-FMS-3.4',false,null,'Clean run'
union all select 'OR-AUD-3010-004','Fortis Banjara','Hyderabad','OR-1 General','Sneha Iyer','2026-06-01'::date,'completed','onset','ONS-4404','2026-10-01'::date,'2026-04-01'::date,'fail',62.40,false,false,'NABH-FMS-3.2',true,'2026-07-05'::date,'Compressor failure'
union all select 'OR-AUD-3010-005','Continental Gachibowli','Hyderabad','OR-2 Trauma','Vikram Singh','2026-06-01'::date,'completed','testo','TST-1005','2026-09-30'::date,'2026-03-30'::date,'pass',94.10,true,true,'NABH-FMS-3.2',false,null,'Routine pass'
union all select 'OR-AUD-3010-006','Care Banjara','Hyderabad','OR-1 ENT','Meera Joshi','2026-06-01'::date,'completed','tsi','TSI-5505','2027-02-14'::date,'2026-02-14'::date,'conditional_pass',82.50,false,true,'NABH-FMS-3.2',true,'2026-07-20'::date,'Temp peak at 23.5C'
union all select 'OR-AUD-3010-007','AIG Hospitals Gachibowli','Hyderabad','OR-4 GI','Karthik Rao','2026-06-01'::date,'completed','elitech','ELT-6606','2026-12-01'::date,'2026-06-01'::date,'pass',99.00,true,true,'NABH-FMS-3.4',false,null,'Best in batch'
union all select 'OR-AUD-3010-008','Sunshine Paradise','Hyderabad','OR-1 Cardiac','Anil Patil','2026-06-01'::date,'in_progress','testo','TST-1008','2026-11-05'::date,'2026-05-05'::date,'reaudit_required',71.30,false,false,'NABH-FMS-3.2',true,'2026-07-10'::date,'HVAC retune scheduled'
union all select 'OR-AUD-3010-009','Star Banjara','Hyderabad','OR-2 Plastic','Divya Menon','2026-06-01'::date,'completed','rotronic','RTR-2209','2027-03-22'::date,'2026-03-22'::date,'pass',95.40,true,true,'NABH-FMS-3.2',false,null,'No issues'
union all select 'OR-AUD-3010-010','Olive Sherlingampally','Hyderabad','OR-1 Gen','Ramesh Naidu','2026-06-01'::date,'overdue','vaisala','VSL-3010','2026-08-18'::date,'2026-02-18'::date,'fail',55.80,false,false,'NABH-FMS-3.2',true,'2026-07-02'::date,'No engineer dispatch'
union all select 'OR-AUD-3010-011','Renova Soujanya','Hyderabad','OR-3 Uro','Suresh Babu','2026-06-01'::date,'completed','onset','ONS-4411','2026-10-25'::date,'2026-04-25'::date,'conditional_pass',85.60,true,false,'NABH-FMS-3.2',true,'2026-07-25'::date,'Humidifier drift'
union all select 'OR-AUD-3010-012','Image Hospitals','Hyderabad','OR-1 Mixed','Lakshmi Devi','2026-06-01'::date,'completed','testo','TST-1012','2026-12-30'::date,'2026-06-30'::date,'pass',97.20,true,true,'NABH-FMS-3.4',false,null,'Clean baseline'
union all select 'OR-AUD-3010-013','Aware Gachibowli','Hyderabad','OR-2 Day','Naveen Kumar','2026-06-01'::date,'cancelled','tsi','TSI-5513','2026-11-15'::date,'2026-05-15'::date,'reaudit_required',0.00,false,false,'NABH-FMS-3.2',true,'2026-07-12'::date,'Site refused entry'
union all select 'OR-AUD-3010-014','Krishna Institute Kondapur','Hyderabad','OR-5 Cardiac','Pooja Agarwal','2026-06-01'::date,'completed','elitech','ELT-6614','2026-09-08'::date,'2026-03-08'::date,'pass',93.70,true,true,'NABH-FMS-3.2',false,null,'Cardiac OR healthy'
union all select 'OR-AUD-3010-015','Medicover Hitec City','Hyderabad','OR-1 Robotic','Harish Kumar','2026-06-01'::date,'completed','vaisala','VSL-3015','2027-01-19'::date,'2026-01-19'::date,'conditional_pass',88.90,false,true,'NABH-FMS-3.2',true,'2026-07-18'::date,'Robotic suite temp creep'
union all select 'OR-AUD-3010-016','Maxcure Madhapur','Hyderabad','OR-2 Bariatric','Anjali Verma','2026-06-01'::date,'completed','rotronic','RTR-2216','2026-12-22'::date,'2026-06-22'::date,'pass',96.10,true,true,'NABH-FMS-3.2',false,null,'Stable'
union all select 'OR-AUD-3010-017','Citizens Specialty','Hyderabad','OR-1 Gen','Manoj Pillai','2026-06-01'::date,'overdue','onset','ONS-4417','2026-08-30'::date,'2026-02-28'::date,'fail',48.50,false,false,'NABH-FMS-3.2',true,'2026-07-08'::date,'AC outage 4h'
union all select 'OR-AUD-3010-018','Virinchi Banjara','Hyderabad','OR-3 Spine','Geetha Krishnan','2026-06-01'::date,'completed','testo','TST-1018','2026-11-28'::date,'2026-05-28'::date,'pass',94.80,true,true,'NABH-FMS-3.4',false,null,'Routine clear';

-- Seed readings (24 rows)
insert into or_temp_humidity_logger_readings_r3010 (audit_id, reading_timestamp, temperature_celsius, humidity_percent, temp_within_limits, humidity_within_limits, reading_severity, excursion_minutes, corrective_action, flagged_for_review)
select a.id, '2026-06-15 08:00:00+05:30'::timestamptz, 21.50, 55.00, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-001'
union all select a.id, '2026-06-15 14:00:00+05:30'::timestamptz, 22.10, 56.50, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-001'
union all select a.id, '2026-06-16 09:30:00+05:30'::timestamptz, 23.80, 68.00, true, false, 'warning', 45, 'adjusted_hvac', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-002'
union all select a.id, '2026-06-16 11:00:00+05:30'::timestamptz, 22.50, 65.50, true, false, 'warning', 30, 'adjusted_hvac', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-002'
union all select a.id, '2026-06-17 08:15:00+05:30'::timestamptz, 20.80, 52.00, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-003'
union all select a.id, '2026-06-18 10:00:00+05:30'::timestamptz, 26.50, 72.00, false, false, 'critical', 240, 'escalated', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-004'
union all select a.id, '2026-06-18 12:00:00+05:30'::timestamptz, 27.20, 74.50, false, false, 'critical', 180, 'escalated', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-004'
union all select a.id, '2026-06-19 09:00:00+05:30'::timestamptz, 21.80, 54.50, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-005'
union all select a.id, '2026-06-20 14:30:00+05:30'::timestamptz, 23.50, 58.00, false, true, 'warning', 60, 'flagged_for_review', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-006'
union all select a.id, '2026-06-21 08:45:00+05:30'::timestamptz, 21.20, 53.50, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-007'
union all select a.id, '2026-06-21 10:30:00+05:30'::timestamptz, 21.40, 54.00, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-007'
union all select a.id, '2026-06-22 11:00:00+05:30'::timestamptz, 25.80, 71.00, false, false, 'critical', 120, 'escalated', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-008'
union all select a.id, '2026-06-23 09:00:00+05:30'::timestamptz, 22.00, 56.00, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-009'
union all select a.id, '2026-06-24 08:30:00+05:30'::timestamptz, 28.50, 78.00, false, false, 'critical', 360, 'escalated', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-010'
union all select a.id, '2026-06-25 10:00:00+05:30'::timestamptz, 22.80, 63.50, true, false, 'warning', 25, 'adjusted_hvac', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-011'
union all select a.id, '2026-06-26 09:15:00+05:30'::timestamptz, 21.60, 55.50, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-012'
union all select a.id, '2026-06-27 11:30:00+05:30'::timestamptz, 0.00, 0.00, false, false, 'sensor_error', 0, 'replaced_sensor', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-013'
union all select a.id, '2026-06-28 08:00:00+05:30'::timestamptz, 21.90, 56.80, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-014'
union all select a.id, '2026-06-29 10:45:00+05:30'::timestamptz, 23.80, 57.00, false, true, 'warning', 35, 'flagged_for_review', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-015'
union all select a.id, '2026-06-30 09:00:00+05:30'::timestamptz, 22.20, 56.50, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-016'
union all select a.id, '2026-07-01 11:00:00+05:30'::timestamptz, 29.80, 80.50, false, false, 'critical', 240, 'escalated', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-017'
union all select a.id, '2026-07-02 08:30:00+05:30'::timestamptz, 21.70, 55.20, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-018'
union all select a.id, '2026-06-15 16:00:00+05:30'::timestamptz, 21.80, 55.40, true, true, 'normal', 0, 'none', false from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-001'
union all select a.id, '2026-06-22 13:30:00+05:30'::timestamptz, 26.10, 72.50, false, false, 'critical', 150, 'escalated', true from or_temp_humidity_logger_audits_r3010 a where a.audit_code='OR-AUD-3010-008';

-- RPC 1: overview KPIs
create or replace function founder_or_audit_overview_r3010()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select 'total_audits'::text, count(*)::text from or_temp_humidity_logger_audits_r3010
    union all select 'completed', (count(*) filter (where audit_status='completed'))::text from or_temp_humidity_logger_audits_r3010
    union all select 'overdue', (count(*) filter (where audit_status='overdue'))::text from or_temp_humidity_logger_audits_r3010
    union all select 'failed_visits', (count(*) filter (where visit_outcome='fail'))::text from or_temp_humidity_logger_audits_r3010
    union all select 'avg_compliance_pct', round(avg(compliance_score_pct),2)::text from or_temp_humidity_logger_audits_r3010
    union all select 'followups_open', (count(*) filter (where followup_required=true))::text from or_temp_humidity_logger_audits_r3010;
end; $$;

-- RPC 2: list audits
create or replace function founder_or_audit_list_r3010()
returns setof or_temp_humidity_logger_audits_r3010
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select * from or_temp_humidity_logger_audits_r3010 order by audit_month desc, compliance_score_pct asc;
end; $$;

-- RPC 3: critical excursions
create or replace function founder_or_audit_critical_excursions_r3010()
returns table(audit_code text, customer_site text, reading_timestamp timestamptz, temperature_celsius numeric, humidity_percent numeric, excursion_minutes int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_code, a.customer_site, r.reading_timestamp, r.temperature_celsius, r.humidity_percent, r.excursion_minutes
    from or_temp_humidity_logger_readings_r3010 r
    join or_temp_humidity_logger_audits_r3010 a on a.id = r.audit_id
    where r.reading_severity = 'critical'
    order by r.excursion_minutes desc;
end; $$;

-- RPC 4: by engineer
create or replace function founder_or_audit_by_engineer_r3010()
returns table(engineer_name text, audit_count int, avg_score numeric, fails int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.engineer_name, count(*)::int, round(avg(a.compliance_score_pct),2), (count(*) filter (where a.visit_outcome='fail'))::int
    from or_temp_humidity_logger_audits_r3010 a
    group by a.engineer_name
    order by avg(a.compliance_score_pct) asc;
end; $$;

-- RPC 5: calibration due soon
create or replace function founder_or_audit_calibration_due_r3010()
returns table(audit_code text, customer_site text, logger_make text, logger_serial text, calibration_due_date date, days_until_due int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_code, a.customer_site, a.logger_make, a.logger_serial, a.calibration_due_date,
      (a.calibration_due_date - current_date)::int
    from or_temp_humidity_logger_audits_r3010 a
    where a.calibration_due_date is not null
    order by a.calibration_due_date asc;
end; $$;

-- RPC 6: followups open
create or replace function founder_or_audit_followups_r3010()
returns table(audit_code text, customer_site text, visit_outcome text, followup_due_date date, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_code, a.customer_site, a.visit_outcome, a.followup_due_date, a.notes
    from or_temp_humidity_logger_audits_r3010 a
    where a.followup_required = true
    order by a.followup_due_date asc nulls last;
end; $$;

-- RPC 7: logger make breakdown
create or replace function founder_or_audit_logger_make_breakdown_r3010()
returns table(logger_make text, units int, avg_compliance numeric, sensor_errors int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.logger_make, count(*)::int, round(avg(a.compliance_score_pct),2),
      (select count(*) from or_temp_humidity_logger_readings_r3010 r where r.audit_id = any(array_agg(a.id)) and r.reading_severity='sensor_error')::int
    from or_temp_humidity_logger_audits_r3010 a
    group by a.logger_make
    order by avg(a.compliance_score_pct) desc;
end; $$;

revoke all on function founder_or_audit_overview_r3010() from public, anon;
revoke all on function founder_or_audit_list_r3010() from public, anon;
revoke all on function founder_or_audit_critical_excursions_r3010() from public, anon;
revoke all on function founder_or_audit_by_engineer_r3010() from public, anon;
revoke all on function founder_or_audit_calibration_due_r3010() from public, anon;
revoke all on function founder_or_audit_followups_r3010() from public, anon;
revoke all on function founder_or_audit_logger_make_breakdown_r3010() from public, anon;

grant execute on function founder_or_audit_overview_r3010() to authenticated;
grant execute on function founder_or_audit_list_r3010() to authenticated;
grant execute on function founder_or_audit_critical_excursions_r3010() to authenticated;
grant execute on function founder_or_audit_by_engineer_r3010() to authenticated;
grant execute on function founder_or_audit_calibration_due_r3010() to authenticated;
grant execute on function founder_or_audit_followups_r3010() to authenticated;
grant execute on function founder_or_audit_logger_make_breakdown_r3010() to authenticated;
