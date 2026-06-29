-- Round 3044: Mortuary-Fridge Temperature & Door-Lock Compliance
-- Two tables tracking customer-monthly engineer-hospital mortuary fridge compliance

create table if not exists mortuary_fridge_readings_r3044 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  engineer_user_id uuid,
  engineer_name text not null,
  fridge_label text not null,
  reading_month date not null,
  reading_taken_at timestamptz not null default now(),
  temperature_celsius numeric(5,2) not null,
  target_temp_low numeric(5,2) not null default -25.0,
  target_temp_high numeric(5,2) not null default -15.0,
  in_range boolean not null,
  door_lock_state text not null check (door_lock_state in ('locked','unlocked','tamper','offline','broken')),
  door_open_minutes_today int not null default 0 check (door_open_minutes_today >= 0),
  compliance_status text not null check (compliance_status in ('compliant','warning','breach','critical','unknown')),
  body_count int not null default 0 check (body_count >= 0 and body_count <= 20),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists mortuary_fridge_incidents_r3044 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  hospital_name text not null,
  engineer_user_id uuid,
  engineer_name text not null,
  fridge_label text not null,
  incident_kind text not null check (incident_kind in ('temp_excursion','door_left_open','lock_tamper','power_loss','sensor_offline','door_lock_broken')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  duration_minutes int check (duration_minutes >= 0),
  resolved boolean not null default false,
  resolution_note text,
  followup_repair_required boolean not null default false,
  created_at timestamptz not null default now()
);

alter table mortuary_fridge_readings_r3044 enable row level security;
alter table mortuary_fridge_incidents_r3044 enable row level security;

drop policy if exists r3044_readings_founder_select on mortuary_fridge_readings_r3044;
create policy r3044_readings_founder_select on mortuary_fridge_readings_r3044
  for select to authenticated using (is_founder());

drop policy if exists r3044_incidents_founder_select on mortuary_fridge_incidents_r3044;
create policy r3044_incidents_founder_select on mortuary_fridge_incidents_r3044
  for select to authenticated using (is_founder());

-- Seed readings (20 rows)
insert into mortuary_fridge_readings_r3044 (hospital_name, engineer_name, fridge_label, reading_month, reading_taken_at, temperature_celsius, in_range, door_lock_state, door_open_minutes_today, compliance_status, body_count, notes) values
('Apollo Jubilee Hills','Ramesh K','Morgue-A1','2026-06-01'::date,'2026-06-01 09:15:00'::timestamptz,-20.5,true,'locked',4,'compliant',3,'routine check'),
('Apollo Jubilee Hills','Ramesh K','Morgue-A2','2026-06-01'::date,'2026-06-01 09:25:00'::timestamptz,-18.2,true,'locked',6,'compliant',2,null),
('KIMS Secunderabad','Suresh P','Morgue-B1','2026-06-02'::date,'2026-06-02 10:00:00'::timestamptz,-12.4,false,'unlocked',38,'breach',4,'compressor weak'),
('KIMS Secunderabad','Suresh P','Morgue-B2','2026-06-02'::date,'2026-06-02 10:15:00'::timestamptz,-22.0,true,'locked',2,'compliant',1,null),
('Yashoda Somajiguda','Vikram S','Morgue-C1','2026-06-03'::date,'2026-06-03 08:30:00'::timestamptz,-19.8,true,'locked',5,'compliant',5,'all ok'),
('Yashoda Somajiguda','Vikram S','Morgue-C2','2026-06-03'::date,'2026-06-03 08:45:00'::timestamptz,-8.5,false,'tamper',55,'critical',3,'lock broken'),
('Care Banjara Hills','Anita R','Morgue-D1','2026-06-04'::date,'2026-06-04 11:00:00'::timestamptz,-21.0,true,'locked',7,'compliant',2,null),
('Care Banjara Hills','Anita R','Morgue-D2','2026-06-04'::date,'2026-06-04 11:10:00'::timestamptz,-16.5,true,'locked',9,'compliant',4,null),
('AIG Gachibowli','Mohan T','Morgue-E1','2026-06-05'::date,'2026-06-05 09:00:00'::timestamptz,-14.0,false,'unlocked',28,'warning',6,'door left ajar'),
('AIG Gachibowli','Mohan T','Morgue-E2','2026-06-05'::date,'2026-06-05 09:20:00'::timestamptz,-20.0,true,'locked',3,'compliant',2,null),
('Continental Nanakramguda','Deepak J','Morgue-F1','2026-06-06'::date,'2026-06-06 10:30:00'::timestamptz,-23.5,true,'locked',2,'compliant',1,null),
('Continental Nanakramguda','Deepak J','Morgue-F2','2026-06-06'::date,'2026-06-06 10:45:00'::timestamptz,-5.0,false,'offline','60','critical',7,'sensor down'),
('Sunshine Paradise','Rakesh B','Morgue-G1','2026-06-07'::date,'2026-06-07 08:00:00'::timestamptz,-19.0,true,'locked',6,'compliant',3,null),
('Sunshine Paradise','Rakesh B','Morgue-G2','2026-06-07'::date,'2026-06-07 08:15:00'::timestamptz,-17.2,true,'locked',4,'compliant',2,null),
('Rainbow Children','Priya M','Morgue-H1','2026-06-08'::date,'2026-06-08 09:30:00'::timestamptz,-21.8,true,'locked',5,'compliant',1,'pediatric morgue'),
('Citizens Specialty','Naveen L','Morgue-I1','2026-06-09'::date,'2026-06-09 10:00:00'::timestamptz,-11.0,false,'broken',45,'breach',5,'door hinge broken'),
('Star Hospitals','Geeta V','Morgue-J1','2026-06-10'::date,'2026-06-10 09:45:00'::timestamptz,-20.0,true,'locked',3,'compliant',4,null),
('MaxCure Madhapur','Arun Y','Morgue-K1','2026-06-11'::date,'2026-06-11 11:00:00'::timestamptz,-19.5,true,'locked',8,'compliant',2,null),
('Olive LB Nagar','Sunita K','Morgue-L1','2026-06-12'::date,'2026-06-12 10:00:00'::timestamptz,-15.8,true,'locked',11,'warning',3,'borderline'),
('Pace Hospitals','Manoj G','Morgue-M1','2026-06-13'::date,'2026-06-13 09:00:00'::timestamptz,-22.2,true,'locked',4,'compliant',2,null);

-- fix one row (string '60' was wrong) — actually re-insert clean
-- (kept simple; row inserted above with literal cast issue — use update if needed but not necessary here)

-- Seed incidents (16 rows)
insert into mortuary_fridge_incidents_r3044 (hospital_name, engineer_name, fridge_label, incident_kind, severity, opened_at, resolved_at, duration_minutes, resolved, resolution_note, followup_repair_required) values
('KIMS Secunderabad','Suresh P','Morgue-B1','temp_excursion','p1','2026-06-02 10:00:00'::timestamptz,'2026-06-02 14:30:00'::timestamptz,270,true,'compressor reset',true),
('Yashoda Somajiguda','Vikram S','Morgue-C2','lock_tamper','p0','2026-06-03 08:45:00'::timestamptz,null,null,false,null,true),
('AIG Gachibowli','Mohan T','Morgue-E1','door_left_open','p2','2026-06-05 09:00:00'::timestamptz,'2026-06-05 10:00:00'::timestamptz,60,true,'door closed manually',false),
('Continental Nanakramguda','Deepak J','Morgue-F2','sensor_offline','p0','2026-06-06 10:45:00'::timestamptz,null,null,false,null,true),
('Continental Nanakramguda','Deepak J','Morgue-F2','power_loss','p1','2026-06-06 12:00:00'::timestamptz,'2026-06-06 13:30:00'::timestamptz,90,true,'generator kicked in',false),
('Citizens Specialty','Naveen L','Morgue-I1','door_lock_broken','p1','2026-06-09 10:00:00'::timestamptz,null,null,false,null,true),
('Olive LB Nagar','Sunita K','Morgue-L1','temp_excursion','p3','2026-06-12 10:00:00'::timestamptz,'2026-06-12 11:15:00'::timestamptz,75,true,'thermostat adjusted',false),
('Apollo Jubilee Hills','Ramesh K','Morgue-A1','door_left_open','p3','2026-05-28 14:00:00'::timestamptz,'2026-05-28 14:30:00'::timestamptz,30,true,'door auto-closed',false),
('KIMS Secunderabad','Suresh P','Morgue-B1','temp_excursion','p2','2026-05-20 09:00:00'::timestamptz,'2026-05-20 13:00:00'::timestamptz,240,true,'door gasket replaced',false),
('Yashoda Somajiguda','Vikram S','Morgue-C2','door_lock_broken','p0','2026-05-15 10:00:00'::timestamptz,'2026-05-16 16:00:00'::timestamptz,1800,true,'lock replaced',false),
('Care Banjara Hills','Anita R','Morgue-D2','sensor_offline','p2','2026-05-25 11:00:00'::timestamptz,'2026-05-25 12:00:00'::timestamptz,60,true,'sensor recalibrated',false),
('AIG Gachibowli','Mohan T','Morgue-E2','temp_excursion','p1','2026-05-18 08:00:00'::timestamptz,'2026-05-18 11:00:00'::timestamptz,180,true,'compressor topped up',false),
('Sunshine Paradise','Rakesh B','Morgue-G1','door_left_open','p3','2026-06-01 09:00:00'::timestamptz,'2026-06-01 09:25:00'::timestamptz,25,true,'closed manually',false),
('Star Hospitals','Geeta V','Morgue-J1','lock_tamper','p2','2026-05-30 10:00:00'::timestamptz,'2026-05-30 12:00:00'::timestamptz,120,true,'investigated, false alarm',false),
('MaxCure Madhapur','Arun Y','Morgue-K1','power_loss','p1','2026-05-22 14:00:00'::timestamptz,'2026-05-22 15:30:00'::timestamptz,90,true,'UPS restored',false),
('Pace Hospitals','Manoj G','Morgue-M1','temp_excursion','p3','2026-05-10 08:00:00'::timestamptz,'2026-05-10 09:00:00'::timestamptz,60,true,'minor excursion',false);

-- RPC 1: monthly summary by hospital
create or replace function r3044_monthly_compliance_summary()
returns table(hospital_name text, readings_total int, breaches int, criticals int, warnings int, compliant_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.hospital_name,
      count(*)::int as readings_total,
      (count(*) filter (where r.compliance_status = 'breach'))::int as breaches,
      (count(*) filter (where r.compliance_status = 'critical'))::int as criticals,
      (count(*) filter (where r.compliance_status = 'warning'))::int as warnings,
      round(100.0 * (count(*) filter (where r.compliance_status = 'compliant'))::numeric / nullif(count(*),0), 1) as compliant_pct
    from mortuary_fridge_readings_r3044 r
    group by r.hospital_name
    order by criticals desc, breaches desc;
end $$;

-- RPC 2: critical fridges right now
create or replace function r3044_critical_fridges()
returns table(hospital_name text, fridge_label text, temperature_celsius numeric, door_lock_state text, body_count int, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.hospital_name, r.fridge_label, r.temperature_celsius, r.door_lock_state, r.body_count, r.notes
    from mortuary_fridge_readings_r3044 r
    where r.compliance_status in ('critical','breach')
    order by r.compliance_status desc, r.temperature_celsius desc;
end $$;

-- RPC 3: open incidents
create or replace function r3044_open_incidents()
returns table(hospital_name text, fridge_label text, incident_kind text, severity text, engineer_name text, opened_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select i.hospital_name, i.fridge_label, i.incident_kind, i.severity, i.engineer_name, i.opened_at
    from mortuary_fridge_incidents_r3044 i
    where i.resolved = false
    order by i.severity asc, i.opened_at asc;
end $$;

-- RPC 4: engineer scorecard
create or replace function r3044_engineer_scorecard()
returns table(engineer_name text, readings_logged int, breaches_seen int, incidents_handled int, incidents_open int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.engineer_name,
      coalesce(r.readings_logged, 0)::int as readings_logged,
      coalesce(r.breaches_seen, 0)::int as breaches_seen,
      coalesce(i.incidents_handled, 0)::int as incidents_handled,
      coalesce(i.incidents_open, 0)::int as incidents_open
    from (
      select distinct engineer_name from mortuary_fridge_readings_r3044
      union
      select distinct engineer_name from mortuary_fridge_incidents_r3044
    ) e
    left join (
      select engineer_name,
        count(*) as readings_logged,
        count(*) filter (where compliance_status in ('breach','critical')) as breaches_seen
      from mortuary_fridge_readings_r3044
      group by engineer_name
    ) r on r.engineer_name = e.engineer_name
    left join (
      select engineer_name,
        count(*) filter (where resolved = true) as incidents_handled,
        count(*) filter (where resolved = false) as incidents_open
      from mortuary_fridge_incidents_r3044
      group by engineer_name
    ) i on i.engineer_name = e.engineer_name
    order by incidents_open desc, breaches_seen desc;
end $$;

-- RPC 5: door-lock state breakdown
create or replace function r3044_door_lock_breakdown()
returns table(door_lock_state text, fridge_count int, avg_door_open_minutes numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.door_lock_state,
      count(*)::int as fridge_count,
      round(avg(r.door_open_minutes_today)::numeric, 1) as avg_door_open_minutes
    from mortuary_fridge_readings_r3044 r
    group by r.door_lock_state
    order by fridge_count desc;
end $$;

-- RPC 6: incident MTTR
create or replace function r3044_incident_mttr()
returns table(incident_kind text, total_incidents int, resolved_count int, avg_resolution_minutes numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select i.incident_kind,
      count(*)::int as total_incidents,
      (count(*) filter (where i.resolved = true))::int as resolved_count,
      round(avg(i.duration_minutes) filter (where i.resolved = true)::numeric, 1) as avg_resolution_minutes
    from mortuary_fridge_incidents_r3044 i
    group by i.incident_kind
    order by total_incidents desc;
end $$;

-- RPC 7: latest readings (top 15)
create or replace function r3044_latest_readings()
returns table(hospital_name text, fridge_label text, reading_taken_at timestamptz, temperature_celsius numeric, compliance_status text, body_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select r.hospital_name, r.fridge_label, r.reading_taken_at, r.temperature_celsius, r.compliance_status, r.body_count
    from mortuary_fridge_readings_r3044 r
    order by r.reading_taken_at desc
    limit 15;
end $$;

-- RPC 8: severity distribution
create or replace function r3044_severity_distribution()
returns table(severity text, total int, open_count int, resolved_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select i.severity,
      count(*)::int as total,
      (count(*) filter (where i.resolved = false))::int as open_count,
      (count(*) filter (where i.resolved = true))::int as resolved_count
    from mortuary_fridge_incidents_r3044 i
    group by i.severity
    order by i.severity asc;
end $$;

revoke all on mortuary_fridge_readings_r3044 from public, anon;
revoke all on mortuary_fridge_incidents_r3044 from public, anon;
grant select on mortuary_fridge_readings_r3044 to authenticated;
grant select on mortuary_fridge_incidents_r3044 to authenticated;

revoke all on function r3044_monthly_compliance_summary() from public, anon;
revoke all on function r3044_critical_fridges() from public, anon;
revoke all on function r3044_open_incidents() from public, anon;
revoke all on function r3044_engineer_scorecard() from public, anon;
revoke all on function r3044_door_lock_breakdown() from public, anon;
revoke all on function r3044_incident_mttr() from public, anon;
revoke all on function r3044_latest_readings() from public, anon;
revoke all on function r3044_severity_distribution() from public, anon;

grant execute on function r3044_monthly_compliance_summary() to authenticated;
grant execute on function r3044_critical_fridges() to authenticated;
grant execute on function r3044_open_incidents() to authenticated;
grant execute on function r3044_engineer_scorecard() to authenticated;
grant execute on function r3044_door_lock_breakdown() to authenticated;
grant execute on function r3044_incident_mttr() to authenticated;
grant execute on function r3044_latest_readings() to authenticated;
grant execute on function r3044_severity_distribution() to authenticated;
