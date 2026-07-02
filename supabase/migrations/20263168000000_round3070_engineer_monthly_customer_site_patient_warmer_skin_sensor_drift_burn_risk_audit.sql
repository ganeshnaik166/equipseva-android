-- Round 3070 — Engineer Monthly Customer Site Patient Warmer Skin-Sensor Drift & Burn-Risk Audit
-- Two tables suffixed _r3070, RLS enabled, 7 founder-gated RPCs, seeds.

create table if not exists patient_warmer_skin_sensor_audits_r3070 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  hospital_org_id uuid,
  hospital_name text not null,
  warmer_asset_tag text not null,
  warmer_model text not null,
  ward text not null check (ward in ('nicu','picu','ot','er','labor_delivery','recovery')),
  engineer_user_id uuid,
  engineer_name text not null,
  sensor_serial text not null,
  setpoint_celsius numeric(5,2) not null check (setpoint_celsius between 30 and 40),
  measured_skin_celsius numeric(5,2) not null check (measured_skin_celsius between 25 and 45),
  reference_probe_celsius numeric(5,2) not null check (reference_probe_celsius between 25 and 45),
  drift_celsius numeric(5,2) not null,
  drift_band text not null check (drift_band in ('within_spec','minor','moderate','severe','critical')),
  burn_risk_score int not null check (burn_risk_score between 0 and 100),
  burn_risk_band text not null check (burn_risk_band in ('green','yellow','orange','red')),
  patients_exposed int not null check (patients_exposed >= 0),
  burn_incidents_reported int not null check (burn_incidents_reported >= 0),
  calibration_due boolean not null default false,
  calibrated_at timestamptz,
  status text not null check (status in ('open','calibrated','sensor_replaced','escalated','closed')),
  founder_reviewed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists patient_warmer_remediation_actions_r3070 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references patient_warmer_skin_sensor_audits_r3070(id) on delete cascade,
  action_month date not null,
  hospital_name text not null,
  warmer_asset_tag text not null,
  action_type text not null check (action_type in ('recalibrate','replace_sensor','replace_warmer','quarantine','firmware_update','training','escalate_oem')),
  action_priority text not null check (action_priority in ('p0','p1','p2','p3')),
  engineer_name text not null,
  scheduled_at timestamptz,
  completed_at timestamptz,
  parts_cost_rupees int not null default 0 check (parts_cost_rupees >= 0),
  labor_minutes int not null default 0 check (labor_minutes >= 0),
  post_action_drift_celsius numeric(5,2),
  post_action_burn_risk_score int check (post_action_burn_risk_score between 0 and 100),
  outcome text not null check (outcome in ('pending','in_progress','resolved','partial','failed','deferred')),
  notes text,
  created_at timestamptz not null default now()
);

alter table patient_warmer_skin_sensor_audits_r3070 enable row level security;
alter table patient_warmer_remediation_actions_r3070 enable row level security;

drop policy if exists pwssa_r3070_founder_all on patient_warmer_skin_sensor_audits_r3070;
create policy pwssa_r3070_founder_all on patient_warmer_skin_sensor_audits_r3070
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists pwra_r3070_founder_all on patient_warmer_remediation_actions_r3070;
create policy pwra_r3070_founder_all on patient_warmer_remediation_actions_r3070
  for all to authenticated using (is_founder()) with check (is_founder());

insert into patient_warmer_skin_sensor_audits_r3070
(audit_month, hospital_name, warmer_asset_tag, warmer_model, ward, engineer_name, sensor_serial, setpoint_celsius, measured_skin_celsius, reference_probe_celsius, drift_celsius, drift_band, burn_risk_score, burn_risk_band, patients_exposed, burn_incidents_reported, calibration_due, calibrated_at, status, founder_reviewed)
values
('2026-06-01'::date,'Apollo Jubilee Hills','PW-AJH-0001','Fanem 1186','nicu','Ravi Kumar','SN-AA0001',36.5,36.7,36.6,0.10,'within_spec',8,'green',24,0,false,'2026-06-03 10:00+05:30'::timestamptz,'closed',true),
('2026-06-01'::date,'Apollo Jubilee Hills','PW-AJH-0002','Fanem 1186','nicu','Ravi Kumar','SN-AA0002',36.5,37.2,36.6,0.60,'minor',22,'yellow',18,0,false,'2026-06-04 11:00+05:30'::timestamptz,'calibrated',true),
('2026-06-01'::date,'KIMS Secunderabad','PW-KIM-0007','GE Lullaby','picu','Suresh M',  'SN-BB0007',36.0,37.8,36.1,1.70,'moderate',54,'orange',12,1,true, null,'open',false),
('2026-06-01'::date,'KIMS Secunderabad','PW-KIM-0009','GE Lullaby','nicu','Suresh M',  'SN-BB0009',36.5,39.1,36.4,2.70,'severe',81,'red',9,2,true,null,'escalated',true),
('2026-06-01'::date,'Yashoda Somajiguda','PW-YS-0014','Drager Babytherm','ot','Priya N','SN-CC0014',36.5,36.4,36.5,-0.10,'within_spec',6,'green',8,0,false,'2026-06-05 09:30+05:30'::timestamptz,'closed',true),
('2026-06-01'::date,'Yashoda Somajiguda','PW-YS-0015','Drager Babytherm','recovery','Priya N','SN-CC0015',36.0,36.9,36.0,0.90,'minor',28,'yellow',15,0,false,'2026-06-06 14:00+05:30'::timestamptz,'calibrated',false),
('2026-06-01'::date,'Rainbow Banjara','PW-RB-0021','Atom Phoenix','nicu','Anil V','SN-DD0021',36.5,38.4,36.4,2.00,'moderate',62,'orange',20,1,true,null,'open',false),
('2026-06-01'::date,'Rainbow Banjara','PW-RB-0022','Atom Phoenix','nicu','Anil V','SN-DD0022',36.5,40.2,36.5,3.70,'critical',94,'red',6,3,true,null,'escalated',true),
('2026-06-01'::date,'Continental Gachibowli','PW-CG-0030','Phoenix Advanced','er','Meera S','SN-EE0030',36.0,36.2,36.1,0.10,'within_spec',7,'green',11,0,false,'2026-06-07 12:00+05:30'::timestamptz,'closed',true),
('2026-06-01'::date,'Continental Gachibowli','PW-CG-0031','Phoenix Advanced','labor_delivery','Meera S','SN-EE0031',36.0,37.4,36.0,1.40,'moderate',48,'orange',17,0,true,null,'sensor_replaced',true),
('2026-05-01'::date,'Apollo Jubilee Hills','PW-AJH-0001','Fanem 1186','nicu','Ravi Kumar','SN-AA0001',36.5,36.8,36.6,0.20,'within_spec',10,'green',22,0,false,'2026-05-04 10:00+05:30'::timestamptz,'closed',true),
('2026-05-01'::date,'KIMS Secunderabad','PW-KIM-0007','GE Lullaby','picu','Suresh M','SN-BB0007',36.0,37.0,36.1,0.90,'minor',26,'yellow',11,0,false,'2026-05-06 11:00+05:30'::timestamptz,'calibrated',true),
('2026-05-01'::date,'Yashoda Somajiguda','PW-YS-0014','Drager Babytherm','ot','Priya N','SN-CC0014',36.5,36.5,36.5,0.00,'within_spec',5,'green',9,0,false,'2026-05-05 09:30+05:30'::timestamptz,'closed',true),
('2026-05-01'::date,'Rainbow Banjara','PW-RB-0022','Atom Phoenix','nicu','Anil V','SN-DD0022',36.5,38.2,36.4,1.80,'moderate',58,'orange',14,1,true,'2026-05-08 16:00+05:30'::timestamptz,'sensor_replaced',true),
('2026-04-01'::date,'KIMS Secunderabad','PW-KIM-0009','GE Lullaby','nicu','Suresh M','SN-BB0009',36.5,38.7,36.4,2.30,'severe',74,'red',8,1,true,'2026-04-09 10:00+05:30'::timestamptz,'sensor_replaced',true),
('2026-04-01'::date,'Continental Gachibowli','PW-CG-0031','Phoenix Advanced','labor_delivery','Meera S','SN-EE0031',36.0,37.0,36.0,1.00,'moderate',44,'orange',13,0,true,'2026-04-10 12:00+05:30'::timestamptz,'calibrated',true);

insert into patient_warmer_remediation_actions_r3070
(action_month, hospital_name, warmer_asset_tag, action_type, action_priority, engineer_name, scheduled_at, completed_at, parts_cost_rupees, labor_minutes, post_action_drift_celsius, post_action_burn_risk_score, outcome, notes)
values
('2026-06-01'::date,'Apollo Jubilee Hills','PW-AJH-0002','recalibrate','p2','Ravi Kumar','2026-06-04 10:00+05:30'::timestamptz,'2026-06-04 11:00+05:30'::timestamptz,0,45,0.10,8,'resolved','Routine recalibration restored drift to within spec'),
('2026-06-01'::date,'KIMS Secunderabad','PW-KIM-0007','replace_sensor','p1','Suresh M','2026-06-12 09:00+05:30'::timestamptz,null,2400,60,null,null,'in_progress','Sensor ordered from OEM'),
('2026-06-01'::date,'KIMS Secunderabad','PW-KIM-0009','escalate_oem','p0','Suresh M','2026-06-10 10:00+05:30'::timestamptz,null,0,30,null,null,'pending','Severe drift; OEM RMA initiated'),
('2026-06-01'::date,'Yashoda Somajiguda','PW-YS-0015','recalibrate','p3','Priya N','2026-06-06 13:30+05:30'::timestamptz,'2026-06-06 14:00+05:30'::timestamptz,0,30,0.10,7,'resolved','Calibration within tolerance'),
('2026-06-01'::date,'Rainbow Banjara','PW-RB-0021','replace_sensor','p1','Anil V','2026-06-14 09:00+05:30'::timestamptz,null,2200,60,null,null,'in_progress','Spare sensor in transit'),
('2026-06-01'::date,'Rainbow Banjara','PW-RB-0022','quarantine','p0','Anil V','2026-06-08 08:00+05:30'::timestamptz,'2026-06-08 09:00+05:30'::timestamptz,0,60,null,null,'partial','Warmer quarantined; replacement unit allocated'),
('2026-06-01'::date,'Continental Gachibowli','PW-CG-0031','replace_sensor','p1','Meera S','2026-06-09 11:00+05:30'::timestamptz,'2026-06-09 12:30+05:30'::timestamptz,2100,90,0.20,12,'resolved','Replacement sensor calibrated successfully'),
('2026-05-01'::date,'KIMS Secunderabad','PW-KIM-0007','recalibrate','p2','Suresh M','2026-05-06 10:00+05:30'::timestamptz,'2026-05-06 11:00+05:30'::timestamptz,0,45,0.20,12,'resolved','Calibration restored'),
('2026-05-01'::date,'Rainbow Banjara','PW-RB-0022','replace_sensor','p1','Anil V','2026-05-08 15:00+05:30'::timestamptz,'2026-05-08 16:00+05:30'::timestamptz,2200,60,0.30,18,'partial','Drift improved but still trending'),
('2026-04-01'::date,'KIMS Secunderabad','PW-KIM-0009','replace_sensor','p0','Suresh M','2026-04-09 09:00+05:30'::timestamptz,'2026-04-09 10:00+05:30'::timestamptz,2400,60,0.50,22,'resolved','Severe drift sensor replaced'),
('2026-04-01'::date,'Continental Gachibowli','PW-CG-0031','recalibrate','p2','Meera S','2026-04-10 11:30+05:30'::timestamptz,'2026-04-10 12:00+05:30'::timestamptz,0,30,0.30,14,'resolved','Calibration drift moderate; monitored'),
('2026-06-01'::date,'Apollo Jubilee Hills','PW-AJH-0001','firmware_update','p3','Ravi Kumar','2026-06-15 10:00+05:30'::timestamptz,null,0,30,null,null,'deferred','Firmware update scheduled next maintenance window'),
('2026-06-01'::date,'Yashoda Somajiguda','PW-YS-0014','training','p3','Priya N','2026-06-18 14:00+05:30'::timestamptz,null,0,90,null,null,'pending','Ward staff retraining on probe placement');

-- RPCs

create or replace function r3070_summary()
returns table(total_audits int, critical_drift int, red_burn_risk int, calibration_due int, total_burn_incidents int, exposed_patients int, founder_reviewed_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select count(*)::int,
         (count(*) filter (where drift_band in ('severe','critical')))::int,
         (count(*) filter (where burn_risk_band='red'))::int,
         (count(*) filter (where calibration_due))::int,
         coalesce(sum(burn_incidents_reported),0)::int,
         coalesce(sum(patients_exposed),0)::int,
         round(100.0 * (count(*) filter (where founder_reviewed))::numeric / nullif(count(*),0), 1)
  from patient_warmer_skin_sensor_audits_r3070;
end $$;

create or replace function r3070_hospital_risk()
returns table(hospital_name text, audits int, avg_drift numeric, max_burn_score int, red_count int, incidents int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name,
         count(*)::int,
         round(avg(a.drift_celsius)::numeric, 2),
         max(a.burn_risk_score)::int,
         (count(*) filter (where a.burn_risk_band='red'))::int,
         coalesce(sum(a.burn_incidents_reported),0)::int
  from patient_warmer_skin_sensor_audits_r3070 a
  group by a.hospital_name
  order by max(a.burn_risk_score) desc;
end $$;

create or replace function r3070_ward_breakdown()
returns table(ward text, audits int, avg_drift numeric, avg_burn_score numeric, exposed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.ward,
         count(*)::int,
         round(avg(a.drift_celsius)::numeric, 2),
         round(avg(a.burn_risk_score)::numeric, 1),
         coalesce(sum(a.patients_exposed),0)::int
  from patient_warmer_skin_sensor_audits_r3070 a
  group by a.ward
  order by avg(a.burn_risk_score) desc;
end $$;

create or replace function r3070_engineer_performance()
returns table(engineer_name text, audits int, severe_critical int, calibrations_closed int, founder_reviewed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
         count(*)::int,
         (count(*) filter (where a.drift_band in ('severe','critical')))::int,
         (count(*) filter (where a.status in ('calibrated','sensor_replaced','closed')))::int,
         (count(*) filter (where a.founder_reviewed))::int
  from patient_warmer_skin_sensor_audits_r3070 a
  group by a.engineer_name
  order by count(*) desc;
end $$;

create or replace function r3070_monthly_trend()
returns table(audit_month date, audits int, avg_drift numeric, red_count int, incidents int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_month,
         count(*)::int,
         round(avg(a.drift_celsius)::numeric, 2),
         (count(*) filter (where a.burn_risk_band='red'))::int,
         coalesce(sum(a.burn_incidents_reported),0)::int
  from patient_warmer_skin_sensor_audits_r3070 a
  group by a.audit_month
  order by a.audit_month desc;
end $$;

create or replace function r3070_remediation_summary()
returns table(action_type text, actions int, resolved int, in_progress int, pending int, total_parts_cost int, total_labor_minutes int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.action_type,
         count(*)::int,
         (count(*) filter (where r.outcome='resolved'))::int,
         (count(*) filter (where r.outcome='in_progress'))::int,
         (count(*) filter (where r.outcome='pending'))::int,
         coalesce(sum(r.parts_cost_rupees),0)::int,
         coalesce(sum(r.labor_minutes),0)::int
  from patient_warmer_remediation_actions_r3070 r
  group by r.action_type
  order by count(*) desc;
end $$;

create or replace function r3070_open_critical_queue()
returns table(hospital_name text, warmer_asset_tag text, ward text, drift_celsius numeric, burn_risk_score int, burn_risk_band text, status text, engineer_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.warmer_asset_tag, a.ward, a.drift_celsius, a.burn_risk_score, a.burn_risk_band, a.status, a.engineer_name
  from patient_warmer_skin_sensor_audits_r3070 a
  where a.status in ('open','escalated')
     or a.burn_risk_band in ('orange','red')
  order by a.burn_risk_score desc, a.drift_celsius desc;
end $$;

revoke all on function r3070_summary() from public, anon;
revoke all on function r3070_hospital_risk() from public, anon;
revoke all on function r3070_ward_breakdown() from public, anon;
revoke all on function r3070_engineer_performance() from public, anon;
revoke all on function r3070_monthly_trend() from public, anon;
revoke all on function r3070_remediation_summary() from public, anon;
revoke all on function r3070_open_critical_queue() from public, anon;

grant execute on function r3070_summary() to authenticated;
grant execute on function r3070_hospital_risk() to authenticated;
grant execute on function r3070_ward_breakdown() to authenticated;
grant execute on function r3070_engineer_performance() to authenticated;
grant execute on function r3070_monthly_trend() to authenticated;
grant execute on function r3070_remediation_summary() to authenticated;
grant execute on function r3070_open_critical_queue() to authenticated;
