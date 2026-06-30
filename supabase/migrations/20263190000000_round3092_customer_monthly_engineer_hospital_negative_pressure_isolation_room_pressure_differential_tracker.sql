-- Round 3092: Customer Monthly Engineer Hospital Negative-Pressure Isolation Room Pressure-Differential Tracker

create table if not exists isolation_room_pressure_readings_r3092 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid references organizations(id) on delete set null,
  room_code text not null,
  ward_type text not null check (ward_type in ('airborne_isolation','protective_isolation','combination','or_negative','tb_ward')),
  reading_month date not null,
  engineer_id uuid references engineers(id) on delete set null,
  customer_profile_id uuid references profiles(id) on delete set null,
  setpoint_pascals numeric(6,2) not null,
  observed_pascals numeric(6,2) not null,
  ach_observed numeric(5,2),
  filter_dp_pascals numeric(6,2),
  occupancy_pct numeric(5,2),
  door_open_seconds int,
  compliance_status text not null check (compliance_status in ('compliant','watch','breach','critical_breach','offline')),
  nabh_clause_ref text,
  remediation_action text,
  remediation_at timestamptz,
  created_at timestamptz default now()
);

create table if not exists isolation_room_audit_visits_r3092 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid references organizations(id) on delete set null,
  room_code text not null,
  visit_month date not null,
  engineer_id uuid references engineers(id) on delete set null,
  visit_kind text not null check (visit_kind in ('monthly_audit','quarterly_certification','complaint_response','filter_change','calibration')),
  visit_status text not null check (visit_status in ('scheduled','in_progress','completed','missed','rescheduled')),
  duration_minutes int,
  findings_count int not null default 0,
  critical_findings_count int not null default 0,
  manometer_serial text,
  calibration_cert_ref text,
  visit_started_at timestamptz,
  visit_completed_at timestamptz,
  notes text,
  created_at timestamptz default now()
);

alter table isolation_room_pressure_readings_r3092 enable row level security;
alter table isolation_room_audit_visits_r3092 enable row level security;

drop policy if exists isol_read_founder_r3092 on isolation_room_pressure_readings_r3092;
create policy isol_read_founder_r3092 on isolation_room_pressure_readings_r3092 for select using (is_founder());

drop policy if exists isol_audit_founder_r3092 on isolation_room_audit_visits_r3092;
create policy isol_audit_founder_r3092 on isolation_room_audit_visits_r3092 for select using (is_founder());

-- Seed pressure readings (18 rows)
insert into isolation_room_pressure_readings_r3092
  (room_code, ward_type, reading_month, setpoint_pascals, observed_pascals, ach_observed, filter_dp_pascals, occupancy_pct, door_open_seconds, compliance_status, nabh_clause_ref, remediation_action, remediation_at)
values
  ('AIIR-3A','airborne_isolation','2026-06-01'::date,-2.50,-2.80,12.40,180.00,72.00,42,'compliant','HIC-7.2',null,null),
  ('AIIR-3B','airborne_isolation','2026-06-01'::date,-2.50,-1.10,9.10,240.00,80.00,95,'breach','HIC-7.2','Replace HEPA prefilter','2026-06-08T10:30:00+05:30'::timestamptz),
  ('PIE-5C','protective_isolation','2026-06-01'::date,2.50,2.70,14.20,165.00,55.00,30,'compliant','HIC-7.3',null,null),
  ('OR-NEG-1','or_negative','2026-06-01'::date,-5.00,-5.20,20.00,210.00,45.00,18,'compliant','OT-4.1',null,null),
  ('TB-W2','tb_ward','2026-06-01'::date,-2.50,-0.40,7.80,290.00,90.00,210,'critical_breach','HIC-7.4','Damper actuator replacement','2026-06-03T16:45:00+05:30'::timestamptz),
  ('AIIR-4A','airborne_isolation','2026-06-01'::date,-2.50,-2.60,11.90,175.00,68.00,55,'compliant','HIC-7.2',null,null),
  ('COMBO-2','combination','2026-06-01'::date,-2.50,-1.80,10.50,200.00,75.00,80,'watch','HIC-7.2','Recalibrate manometer','2026-06-10T11:00:00+05:30'::timestamptz),
  ('AIIR-3A','airborne_isolation','2026-05-01'::date,-2.50,-2.75,12.20,170.00,70.00,48,'compliant','HIC-7.2',null,null),
  ('AIIR-3B','airborne_isolation','2026-05-01'::date,-2.50,-2.40,11.40,205.00,78.00,60,'compliant','HIC-7.2',null,null),
  ('PIE-5C','protective_isolation','2026-05-01'::date,2.50,2.65,13.90,160.00,52.00,28,'compliant','HIC-7.3',null,null),
  ('OR-NEG-1','or_negative','2026-05-01'::date,-5.00,0.20,2.10,320.00,40.00,15,'offline','OT-4.1','Fan VFD failure - replaced','2026-05-12T09:15:00+05:30'::timestamptz),
  ('TB-W2','tb_ward','2026-05-01'::date,-2.50,-2.30,11.10,220.00,85.00,150,'compliant','HIC-7.4',null,null),
  ('AIIR-4A','airborne_isolation','2026-05-01'::date,-2.50,-2.55,11.80,180.00,65.00,52,'compliant','HIC-7.2',null,null),
  ('AIIR-7B','airborne_isolation','2026-06-01'::date,-2.50,-2.90,12.80,155.00,60.00,38,'compliant','HIC-7.2',null,null),
  ('PIE-5D','protective_isolation','2026-06-01'::date,2.50,1.40,8.20,250.00,58.00,45,'watch','HIC-7.3','Door sweep replacement','2026-06-14T14:20:00+05:30'::timestamptz),
  ('COMBO-2','combination','2026-05-01'::date,-2.50,-2.45,11.60,195.00,72.00,75,'compliant','HIC-7.2',null,null),
  ('OR-NEG-3','or_negative','2026-06-01'::date,-5.00,-4.80,19.40,215.00,42.00,20,'compliant','OT-4.1',null,null),
  ('TB-W5','tb_ward','2026-06-01'::date,-2.50,-2.20,10.90,235.00,82.00,165,'compliant','HIC-7.4',null,null);

-- Seed audit visits (16 rows)
insert into isolation_room_audit_visits_r3092
  (room_code, visit_month, visit_kind, visit_status, duration_minutes, findings_count, critical_findings_count, manometer_serial, calibration_cert_ref, visit_started_at, visit_completed_at, notes)
values
  ('AIIR-3A','2026-06-01'::date,'monthly_audit','completed',45,1,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-04T09:00:00+05:30'::timestamptz,'2026-06-04T09:45:00+05:30'::timestamptz,'Within spec'),
  ('AIIR-3B','2026-06-01'::date,'complaint_response','completed',95,4,1,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-08T08:30:00+05:30'::timestamptz,'2026-06-08T10:05:00+05:30'::timestamptz,'Prefilter clogged; replaced'),
  ('PIE-5C','2026-06-01'::date,'monthly_audit','completed',38,0,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-05T11:15:00+05:30'::timestamptz,'2026-06-05T11:53:00+05:30'::timestamptz,'All green'),
  ('OR-NEG-1','2026-06-01'::date,'quarterly_certification','completed',180,2,0,'TSI-9565-P','CAL-2026-Q2-091','2026-06-02T07:00:00+05:30'::timestamptz,'2026-06-02T10:00:00+05:30'::timestamptz,'NABH Q2 cert signed'),
  ('TB-W2','2026-06-01'::date,'complaint_response','completed',140,5,2,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-03T13:30:00+05:30'::timestamptz,'2026-06-03T15:50:00+05:30'::timestamptz,'Damper actuator dead - replaced'),
  ('AIIR-4A','2026-06-01'::date,'monthly_audit','completed',42,0,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-07T10:00:00+05:30'::timestamptz,'2026-06-07T10:42:00+05:30'::timestamptz,null),
  ('COMBO-2','2026-06-01'::date,'calibration','completed',60,1,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-10T10:00:00+05:30'::timestamptz,'2026-06-10T11:00:00+05:30'::timestamptz,'Manometer recalibrated'),
  ('AIIR-7B','2026-06-01'::date,'filter_change','completed',75,0,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-11T09:00:00+05:30'::timestamptz,'2026-06-11T10:15:00+05:30'::timestamptz,'HEPA changed'),
  ('PIE-5D','2026-06-01'::date,'complaint_response','completed',85,3,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-14T13:00:00+05:30'::timestamptz,'2026-06-14T14:25:00+05:30'::timestamptz,'Door sweep replaced'),
  ('OR-NEG-3','2026-06-01'::date,'monthly_audit','completed',50,0,0,'TSI-9565-P','CAL-2026-Q2-091','2026-06-12T08:00:00+05:30'::timestamptz,'2026-06-12T08:50:00+05:30'::timestamptz,null),
  ('TB-W5','2026-06-01'::date,'monthly_audit','completed',48,1,0,'MAG-DM-2110-X','CAL-2026-Q2-118','2026-06-13T09:30:00+05:30'::timestamptz,'2026-06-13T10:18:00+05:30'::timestamptz,'Acceptable drift'),
  ('AIIR-3A','2026-05-01'::date,'monthly_audit','completed',44,0,0,'MAG-DM-2110-X','CAL-2026-Q1-094','2026-05-06T09:00:00+05:30'::timestamptz,'2026-05-06T09:44:00+05:30'::timestamptz,null),
  ('OR-NEG-1','2026-05-01'::date,'complaint_response','completed',220,6,2,'TSI-9565-P','CAL-2026-Q1-094','2026-05-12T07:30:00+05:30'::timestamptz,'2026-05-12T11:10:00+05:30'::timestamptz,'VFD failure - swapped'),
  ('AIIR-3B','2026-06-01'::date,'monthly_audit','missed',null,0,0,null,null,null,null,'Engineer rerouted to TB-W2 critical'),
  ('PIE-5D','2026-05-01'::date,'monthly_audit','completed',40,0,0,'MAG-DM-2110-X','CAL-2026-Q1-094','2026-05-15T10:00:00+05:30'::timestamptz,'2026-05-15T10:40:00+05:30'::timestamptz,null),
  ('COMBO-2','2026-06-01'::date,'monthly_audit','rescheduled',null,0,0,null,null,null,null,'Rescheduled to 2026-06-18');

-- RPCs

create or replace function founder_isol_compliance_summary_r3092()
returns table(compliance_status text, rooms int, avg_observed numeric, avg_setpoint numeric, breach_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.compliance_status,
         count(*)::int as rooms,
         round(avg(r.observed_pascals)::numeric, 2) as avg_observed,
         round(avg(r.setpoint_pascals)::numeric, 2) as avg_setpoint,
         round((100.0 * (count(*) filter (where r.compliance_status in ('breach','critical_breach','offline')))::numeric / nullif(count(*),0))::numeric, 2) as breach_rate_pct
  from isolation_room_pressure_readings_r3092 r
  group by r.compliance_status
  order by rooms desc;
end; $$;

create or replace function founder_isol_ward_breakdown_r3092()
returns table(ward_type text, total_readings int, breaches int, critical_breaches int, avg_ach numeric, avg_filter_dp numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.ward_type,
         count(*)::int as total_readings,
         (count(*) filter (where r.compliance_status = 'breach'))::int as breaches,
         (count(*) filter (where r.compliance_status = 'critical_breach'))::int as critical_breaches,
         round(avg(r.ach_observed)::numeric, 2) as avg_ach,
         round(avg(r.filter_dp_pascals)::numeric, 2) as avg_filter_dp
  from isolation_room_pressure_readings_r3092 r
  group by r.ward_type
  order by critical_breaches desc, breaches desc;
end; $$;

create or replace function founder_isol_room_drift_r3092()
returns table(room_code text, reading_month date, setpoint_pascals numeric, observed_pascals numeric, drift_pascals numeric, compliance_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.room_code, r.reading_month, r.setpoint_pascals, r.observed_pascals,
         round((r.observed_pascals - r.setpoint_pascals)::numeric, 2) as drift_pascals,
         r.compliance_status
  from isolation_room_pressure_readings_r3092 r
  order by abs(r.observed_pascals - r.setpoint_pascals) desc
  limit 20;
end; $$;

create or replace function founder_isol_critical_breaches_r3092()
returns table(room_code text, ward_type text, reading_month date, observed_pascals numeric, setpoint_pascals numeric, remediation_action text, remediation_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.room_code, r.ward_type, r.reading_month, r.observed_pascals, r.setpoint_pascals, r.remediation_action, r.remediation_at
  from isolation_room_pressure_readings_r3092 r
  where r.compliance_status in ('critical_breach','offline','breach')
  order by r.reading_month desc, r.room_code;
end; $$;

create or replace function founder_isol_monthly_trend_r3092()
returns table(reading_month date, rooms_audited int, breaches int, avg_observed numeric, avg_ach numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.reading_month,
         count(*)::int as rooms_audited,
         (count(*) filter (where r.compliance_status in ('breach','critical_breach','offline')))::int as breaches,
         round(avg(r.observed_pascals)::numeric, 2) as avg_observed,
         round(avg(r.ach_observed)::numeric, 2) as avg_ach
  from isolation_room_pressure_readings_r3092 r
  group by r.reading_month
  order by r.reading_month desc;
end; $$;

create or replace function founder_isol_visit_funnel_r3092()
returns table(visit_kind text, scheduled_or_done int, completed int, missed int, avg_duration_min numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.visit_kind,
         count(*)::int as scheduled_or_done,
         (count(*) filter (where v.visit_status = 'completed'))::int as completed,
         (count(*) filter (where v.visit_status = 'missed'))::int as missed,
         round(avg(v.duration_minutes)::numeric, 1) as avg_duration_min
  from isolation_room_audit_visits_r3092 v
  group by v.visit_kind
  order by scheduled_or_done desc;
end; $$;

create or replace function founder_isol_findings_hotlist_r3092()
returns table(room_code text, visit_month date, visit_kind text, findings_count int, critical_findings_count int, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.room_code, v.visit_month, v.visit_kind, v.findings_count, v.critical_findings_count, v.notes
  from isolation_room_audit_visits_r3092 v
  where v.findings_count > 0
  order by v.critical_findings_count desc, v.findings_count desc
  limit 25;
end; $$;

create or replace function founder_isol_occupancy_vs_breach_r3092()
returns table(occupancy_bucket text, readings int, breaches int, avg_door_open_seconds numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select case
           when r.occupancy_pct < 50 then 'low_lt_50'
           when r.occupancy_pct < 75 then 'mid_50_75'
           else 'high_gte_75'
         end as occupancy_bucket,
         count(*)::int as readings,
         (count(*) filter (where r.compliance_status in ('breach','critical_breach','offline')))::int as breaches,
         round(avg(r.door_open_seconds)::numeric, 1) as avg_door_open_seconds
  from isolation_room_pressure_readings_r3092 r
  group by 1
  order by breaches desc;
end; $$;

revoke all on function founder_isol_compliance_summary_r3092() from public, anon;
revoke all on function founder_isol_ward_breakdown_r3092() from public, anon;
revoke all on function founder_isol_room_drift_r3092() from public, anon;
revoke all on function founder_isol_critical_breaches_r3092() from public, anon;
revoke all on function founder_isol_monthly_trend_r3092() from public, anon;
revoke all on function founder_isol_visit_funnel_r3092() from public, anon;
revoke all on function founder_isol_findings_hotlist_r3092() from public, anon;
revoke all on function founder_isol_occupancy_vs_breach_r3092() from public, anon;

grant execute on function founder_isol_compliance_summary_r3092() to authenticated;
grant execute on function founder_isol_ward_breakdown_r3092() to authenticated;
grant execute on function founder_isol_room_drift_r3092() to authenticated;
grant execute on function founder_isol_critical_breaches_r3092() to authenticated;
grant execute on function founder_isol_monthly_trend_r3092() to authenticated;
grant execute on function founder_isol_visit_funnel_r3092() to authenticated;
grant execute on function founder_isol_findings_hotlist_r3092() to authenticated;
grant execute on function founder_isol_occupancy_vs_breach_r3092() to authenticated;
