-- Round r2974 — Engineer Monthly Customer Site Emergency-Lighting Battery Drain & UPS Bypass Audit

create table if not exists emergency_lighting_battery_audits_r2974 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  hospital_name text not null,
  city text not null,
  engineer_name text not null,
  fixtures_total int not null check (fixtures_total > 0),
  fixtures_failed int not null check (fixtures_failed >= 0),
  battery_health_pct numeric(5,2) not null check (battery_health_pct >= 0 and battery_health_pct <= 100),
  drain_rate_pct_per_hr numeric(5,2) not null check (drain_rate_pct_per_hr >= 0),
  expected_runtime_min int not null check (expected_runtime_min > 0),
  measured_runtime_min int not null check (measured_runtime_min >= 0),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  status text not null check (status in ('open','remediation','closed','escalated'))
);

create table if not exists ups_bypass_events_r2974 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  event_month date not null,
  hospital_name text not null,
  ups_model text not null,
  bypass_reason text not null check (bypass_reason in ('overload','battery_fault','maintenance','manual_override','grid_surge','unknown')),
  duration_minutes int not null check (duration_minutes > 0),
  load_kva numeric(6,2) not null check (load_kva >= 0),
  affected_critical_loads int not null check (affected_critical_loads >= 0),
  resolved_by text not null,
  resolution_status text not null check (resolution_status in ('resolved','pending','escalated','recurring')),
  audit_link_id uuid references emergency_lighting_battery_audits_r2974(id) on delete set null
);

alter table emergency_lighting_battery_audits_r2974 enable row level security;
alter table ups_bypass_events_r2974 enable row level security;

drop policy if exists eba_founder_r2974 on emergency_lighting_battery_audits_r2974;
create policy eba_founder_r2974 on emergency_lighting_battery_audits_r2974 for select to authenticated using (is_founder());

drop policy if exists ubp_founder_r2974 on ups_bypass_events_r2974;
create policy ubp_founder_r2974 on ups_bypass_events_r2974 for select to authenticated using (is_founder());

insert into emergency_lighting_battery_audits_r2974 (audit_month, hospital_name, city, engineer_name, fixtures_total, fixtures_failed, battery_health_pct, drain_rate_pct_per_hr, expected_runtime_min, measured_runtime_min, severity, status) values
('2026-06-01'::date,'Apollo Jubilee','Hyderabad','Ramesh K',120,4,92.5,3.2,180,168,'p3','closed'),
('2026-06-01'::date,'Yashoda Secunderabad','Hyderabad','Suresh P',180,18,71.0,8.5,180,92,'p1','remediation'),
('2026-06-01'::date,'KIMS Kondapur','Hyderabad','Anitha R',95,2,94.0,2.8,180,172,'p3','closed'),
('2026-06-01'::date,'Care Banjara','Hyderabad','Vivek S',140,22,65.5,11.2,180,68,'p1','escalated'),
('2026-06-01'::date,'Continental Gachibowli','Hyderabad','Lakshmi M',210,8,88.0,4.1,180,154,'p2','remediation'),
('2026-06-01'::date,'AIG Hospitals','Hyderabad','Rajesh T',260,35,58.0,14.0,180,52,'p0','escalated'),
('2026-06-01'::date,'Sunshine Paradise','Hyderabad','Kavitha B',88,1,96.0,2.4,180,176,'p3','closed'),
('2026-06-01'::date,'Star Hospitals','Hyderabad','Mohan G',155,14,76.5,7.8,180,108,'p2','remediation'),
('2026-06-01'::date,'Citizens Specialty','Hyderabad','Priya N',102,6,84.0,5.5,180,138,'p2','open'),
('2026-06-01'::date,'Rainbow Vikrampuri','Hyderabad','Arjun D',76,3,91.0,3.5,180,162,'p3','closed'),
('2026-06-01'::date,'Asian Institute','Hyderabad','Deepika V',195,28,62.0,13.5,180,58,'p0','escalated'),
('2026-06-01'::date,'Olive Hospital','Hyderabad','Naveen J',64,2,93.5,2.9,180,170,'p3','closed'),
('2026-06-01'::date,'Medicover','Hyderabad','Sandhya L',172,16,73.0,8.2,180,96,'p1','remediation'),
('2026-06-01'::date,'Pace Hospitals','Hyderabad','Harish W',98,5,86.5,5.0,180,144,'p2','open'),
('2026-06-01'::date,'Renova Soujanya','Hyderabad','Bharath E',82,9,68.0,10.5,180,76,'p1','remediation'),
('2026-06-01'::date,'Krishna Institute','Hyderabad','Geeta U',114,3,90.5,3.6,180,158,'p3','closed'),
('2026-06-01'::date,'Virinchi Hospitals','Hyderabad','Kiran F',128,11,79.0,7.2,180,116,'p2','remediation'),
('2026-06-01'::date,'Aware Gachibowli','Hyderabad','Manoj H',104,7,82.5,6.0,180,128,'p2','open');

insert into ups_bypass_events_r2974 (event_month, hospital_name, ups_model, bypass_reason, duration_minutes, load_kva, affected_critical_loads, resolved_by, resolution_status) values
('2026-06-01'::date,'Apollo Jubilee','APC Symmetra 80kVA','maintenance',45,52.5,0,'Ramesh K','resolved'),
('2026-06-01'::date,'Yashoda Secunderabad','Emerson Liebert 120kVA','overload',128,118.0,4,'Suresh P','recurring'),
('2026-06-01'::date,'KIMS Kondapur','Eaton 9395 100kVA','maintenance',32,68.0,0,'Anitha R','resolved'),
('2026-06-01'::date,'Care Banjara','Schneider Galaxy 60kVA','battery_fault',215,55.5,7,'Vivek S','escalated'),
('2026-06-01'::date,'Continental Gachibowli','APC Symmetra 100kVA','grid_surge',18,72.0,2,'Lakshmi M','resolved'),
('2026-06-01'::date,'AIG Hospitals','Emerson Liebert 200kVA','battery_fault',342,185.0,12,'Rajesh T','escalated'),
('2026-06-01'::date,'Sunshine Paradise','Eaton 9355 40kVA','maintenance',28,28.5,0,'Kavitha B','resolved'),
('2026-06-01'::date,'Star Hospitals','APC Symmetra 80kVA','manual_override',96,62.0,3,'Mohan G','pending'),
('2026-06-01'::date,'Citizens Specialty','Schneider Galaxy 50kVA','overload',74,48.5,2,'Priya N','recurring'),
('2026-06-01'::date,'Rainbow Vikrampuri','Eaton 9130 30kVA','maintenance',22,18.5,0,'Arjun D','resolved'),
('2026-06-01'::date,'Asian Institute','Emerson Liebert 150kVA','unknown',268,142.0,9,'Deepika V','escalated'),
('2026-06-01'::date,'Olive Hospital','APC Smart-UPS 20kVA','maintenance',15,14.0,0,'Naveen J','resolved'),
('2026-06-01'::date,'Medicover','Schneider Galaxy 100kVA','battery_fault',156,88.5,5,'Sandhya L','recurring'),
('2026-06-01'::date,'Pace Hospitals','Eaton 9395 60kVA','grid_surge',24,45.0,1,'Harish W','resolved'),
('2026-06-01'::date,'Renova Soujanya','APC Symmetra 40kVA','overload',88,38.5,3,'Bharath E','pending'),
('2026-06-01'::date,'Krishna Institute','Eaton 9130 40kVA','maintenance',30,28.0,0,'Geeta U','resolved'),
('2026-06-01'::date,'Virinchi Hospitals','Schneider Galaxy 80kVA','manual_override',62,58.0,2,'Kiran F','pending'),
('2026-06-01'::date,'Aware Gachibowli','Emerson Liebert 60kVA','battery_fault',112,48.5,4,'Manoj H','recurring');

create or replace function r2974_severity_breakdown()
returns table(severity text, audits int, avg_battery_health numeric, avg_drain_rate numeric, failed_fixtures int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.severity,
    count(*)::int,
    round(avg(a.battery_health_pct),2),
    round(avg(a.drain_rate_pct_per_hr),2),
    sum(a.fixtures_failed)::int
  from emergency_lighting_battery_audits_r2974 a
  group by a.severity
  order by case a.severity when 'p0' then 1 when 'p1' then 2 when 'p2' then 3 else 4 end;
end$$;

create or replace function r2974_top_drain_sites()
returns table(hospital_name text, engineer_name text, drain_rate numeric, battery_health numeric, severity text, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.engineer_name, a.drain_rate_pct_per_hr, a.battery_health_pct, a.severity, a.status
  from emergency_lighting_battery_audits_r2974 a
  order by a.drain_rate_pct_per_hr desc
  limit 10;
end$$;

create or replace function r2974_runtime_shortfall()
returns table(hospital_name text, expected_min int, measured_min int, shortfall_min int, shortfall_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.expected_runtime_min, a.measured_runtime_min,
    (a.expected_runtime_min - a.measured_runtime_min),
    round(((a.expected_runtime_min - a.measured_runtime_min)::numeric / a.expected_runtime_min) * 100, 1)
  from emergency_lighting_battery_audits_r2974 a
  where a.measured_runtime_min < a.expected_runtime_min
  order by (a.expected_runtime_min - a.measured_runtime_min) desc
  limit 12;
end$$;

create or replace function r2974_bypass_reasons()
returns table(reason text, events int, total_minutes int, avg_load_kva numeric, critical_loads_hit int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.bypass_reason,
    count(*)::int,
    sum(b.duration_minutes)::int,
    round(avg(b.load_kva),2),
    sum(b.affected_critical_loads)::int
  from ups_bypass_events_r2974 b
  group by b.bypass_reason
  order by sum(b.duration_minutes) desc;
end$$;

create or replace function r2974_recurring_bypass_sites()
returns table(hospital_name text, ups_model text, total_events int, total_minutes int, critical_loads int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_name, b.ups_model,
    count(*)::int,
    sum(b.duration_minutes)::int,
    sum(b.affected_critical_loads)::int
  from ups_bypass_events_r2974 b
  where b.resolution_status in ('recurring','escalated','pending')
  group by b.hospital_name, b.ups_model
  order by sum(b.duration_minutes) desc
  limit 12;
end$$;

create or replace function r2974_engineer_scorecard()
returns table(engineer_name text, audits int, p0_p1_count int, avg_battery_health numeric, closed_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
    count(*)::int,
    (count(*) filter (where a.severity in ('p0','p1')))::int,
    round(avg(a.battery_health_pct),2),
    (count(*) filter (where a.status = 'closed'))::int
  from emergency_lighting_battery_audits_r2974 a
  group by a.engineer_name
  order by count(*) filter (where a.severity in ('p0','p1')) desc, a.engineer_name;
end$$;

create or replace function r2974_status_summary()
returns table(status text, audits int, total_failed_fixtures int, avg_drain numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.status,
    count(*)::int,
    sum(a.fixtures_failed)::int,
    round(avg(a.drain_rate_pct_per_hr),2)
  from emergency_lighting_battery_audits_r2974 a
  group by a.status
  order by count(*) desc;
end$$;

create or replace function r2974_overview()
returns table(metric text, value text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select 'total_audits'::text, count(*)::text from emergency_lighting_battery_audits_r2974
  union all
  select 'p0_p1_audits', (count(*) filter (where severity in ('p0','p1')))::text from emergency_lighting_battery_audits_r2974
  union all
  select 'total_fixtures', sum(fixtures_total)::text from emergency_lighting_battery_audits_r2974
  union all
  select 'failed_fixtures', sum(fixtures_failed)::text from emergency_lighting_battery_audits_r2974
  union all
  select 'avg_battery_health_pct', round(avg(battery_health_pct),2)::text from emergency_lighting_battery_audits_r2974
  union all
  select 'bypass_events', count(*)::text from ups_bypass_events_r2974
  union all
  select 'bypass_total_minutes', sum(duration_minutes)::text from ups_bypass_events_r2974
  union all
  select 'critical_loads_affected', sum(affected_critical_loads)::text from ups_bypass_events_r2974
  union all
  select 'recurring_bypass_sites', (count(*) filter (where resolution_status='recurring'))::text from ups_bypass_events_r2974;
end$$;

revoke all on function r2974_severity_breakdown() from public, anon;
revoke all on function r2974_top_drain_sites() from public, anon;
revoke all on function r2974_runtime_shortfall() from public, anon;
revoke all on function r2974_bypass_reasons() from public, anon;
revoke all on function r2974_recurring_bypass_sites() from public, anon;
revoke all on function r2974_engineer_scorecard() from public, anon;
revoke all on function r2974_status_summary() from public, anon;
revoke all on function r2974_overview() from public, anon;

grant execute on function r2974_severity_breakdown() to authenticated;
grant execute on function r2974_top_drain_sites() to authenticated;
grant execute on function r2974_runtime_shortfall() to authenticated;
grant execute on function r2974_bypass_reasons() to authenticated;
grant execute on function r2974_recurring_bypass_sites() to authenticated;
grant execute on function r2974_engineer_scorecard() to authenticated;
grant execute on function r2974_status_summary() to authenticated;
grant execute on function r2974_overview() to authenticated;
