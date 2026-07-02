-- Round r2952: Customer Monthly Engineer Female-Engineer Site Comfort & Safety Index
-- HEAVY ★★★★

create table if not exists female_engineer_site_comfort_r2952 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  month_start date not null,
  hospital_code text not null,
  hospital_name text not null,
  city text not null,
  engineer_code text not null,
  engineer_name text not null,
  visits_count int not null default 0,
  comfort_score numeric(4,2) not null,
  safety_score numeric(4,2) not null,
  lighting_score numeric(4,2) not null,
  restroom_access text not null check (restroom_access in ('available','limited','unavailable','dedicated')),
  escort_provided boolean not null default false,
  cab_pickup_on_time_pct numeric(5,2) not null default 0,
  incidents_reported int not null default 0,
  red_flag boolean not null default false,
  composite_index numeric(5,2) not null,
  notes text
);

create table if not exists female_engineer_site_incidents_r2952 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  reported_at timestamptz not null default now(),
  month_start date not null,
  hospital_code text not null,
  engineer_code text not null,
  incident_type text not null check (incident_type in ('harassment','unsafe_access','lighting','restroom','transport','escort_missing','other')),
  severity text not null check (severity in ('p1','p2','p3','p4')),
  description text not null,
  resolved boolean not null default false,
  resolution_notes text,
  action_taken text
);

alter table female_engineer_site_comfort_r2952 enable row level security;
alter table female_engineer_site_incidents_r2952 enable row level security;

drop policy if exists fesc_r2952_select on female_engineer_site_comfort_r2952;
create policy fesc_r2952_select on female_engineer_site_comfort_r2952 for select to authenticated using (is_founder());

drop policy if exists fesi_r2952_select on female_engineer_site_incidents_r2952;
create policy fesi_r2952_select on female_engineer_site_incidents_r2952 for select to authenticated using (is_founder());

-- Seed comfort rows
insert into female_engineer_site_comfort_r2952 (month_start, hospital_code, hospital_name, city, engineer_code, engineer_name, visits_count, comfort_score, safety_score, lighting_score, restroom_access, escort_provided, cab_pickup_on_time_pct, incidents_reported, red_flag, composite_index, notes) values
('2026-06-01'::date, 'HOS-APL-001', 'Apollo Jubilee', 'Hyderabad', 'ENG-F-101', 'Priya R', 14, 8.40, 8.90, 8.10, 'dedicated', true, 96.5, 0, false, 86.8, 'good site'),
('2026-06-01'::date, 'HOS-KIM-002', 'KIMS Secunderabad', 'Hyderabad', 'ENG-F-102', 'Anitha S', 11, 7.50, 7.80, 7.20, 'available', true, 92.0, 0, false, 76.3, null),
('2026-06-01'::date, 'HOS-YAS-003', 'Yashoda Somajiguda', 'Hyderabad', 'ENG-F-103', 'Lakshmi V', 9, 6.20, 5.40, 5.80, 'limited', false, 71.0, 1, true, 58.9, 'restroom issue'),
('2026-06-01'::date, 'HOS-MAN-004', 'Manipal Vijayawada', 'Vijayawada', 'ENG-F-104', 'Sneha K', 8, 7.10, 7.40, 6.90, 'available', false, 82.5, 0, false, 70.5, null),
('2026-06-01'::date, 'HOS-FOR-005', 'Fortis Bengaluru', 'Bengaluru', 'ENG-F-105', 'Divya M', 13, 9.10, 9.20, 8.80, 'dedicated', true, 98.2, 0, false, 91.2, 'gold'),
('2026-06-01'::date, 'HOS-NAR-006', 'Narayana Health BLR', 'Bengaluru', 'ENG-F-106', 'Reshma P', 10, 6.80, 6.50, 6.10, 'limited', true, 79.0, 1, false, 64.7, 'late cab'),
('2026-06-01'::date, 'HOS-TAT-007', 'Tata Memorial', 'Mumbai', 'ENG-F-107', 'Kavya N', 7, 8.20, 8.50, 8.30, 'dedicated', true, 94.0, 0, false, 84.2, null),
('2026-06-01'::date, 'HOS-KOK-008', 'Kokilaben DAH', 'Mumbai', 'ENG-F-108', 'Ishita J', 12, 5.40, 4.90, 5.20, 'unavailable', false, 62.0, 2, true, 49.7, 'severe lighting concern'),
('2026-06-01'::date, 'HOS-AII-009', 'AIIMS Delhi', 'Delhi', 'ENG-F-109', 'Pooja G', 15, 7.90, 8.30, 7.60, 'available', true, 91.5, 0, false, 79.6, null),
('2026-06-01'::date, 'HOS-MAX-010', 'Max Saket', 'Delhi', 'ENG-F-110', 'Neha B', 11, 8.60, 8.80, 8.20, 'dedicated', true, 95.4, 0, false, 86.1, null),
('2026-06-01'::date, 'HOS-CMC-011', 'CMC Vellore', 'Vellore', 'ENG-F-111', 'Saritha L', 9, 7.30, 7.10, 6.90, 'available', false, 84.0, 0, false, 71.2, 'no escort'),
('2026-06-01'::date, 'HOS-AMR-012', 'Amrita Kochi', 'Kochi', 'ENG-F-112', 'Meera D', 8, 8.00, 7.90, 7.50, 'dedicated', true, 93.0, 0, false, 80.4, null),
('2026-06-01'::date, 'HOS-RUB-013', 'Ruby Hall Pune', 'Pune', 'ENG-F-113', 'Aishwarya T', 10, 6.10, 5.80, 5.60, 'limited', false, 68.0, 1, true, 56.9, 'red'),
('2026-06-01'::date, 'HOS-AST-014', 'Aster Whitefield', 'Bengaluru', 'ENG-F-114', 'Bhavana C', 6, 8.80, 8.70, 8.50, 'dedicated', true, 97.0, 0, false, 88.4, null),
('2026-06-01'::date, 'HOS-MED-015', 'Medanta Gurgaon', 'Gurgaon', 'ENG-F-115', 'Tanvi H', 12, 7.70, 8.10, 7.40, 'available', true, 90.0, 0, false, 77.9, null);

-- Seed incidents
insert into female_engineer_site_incidents_r2952 (reported_at, month_start, hospital_code, engineer_code, incident_type, severity, description, resolved, resolution_notes, action_taken) values
(now() - interval '5 days', '2026-06-01'::date, 'HOS-YAS-003', 'ENG-F-103', 'restroom', 'p2', 'No female restroom on biomed floor', false, null, 'escalated'),
(now() - interval '10 days', '2026-06-01'::date, 'HOS-NAR-006', 'ENG-F-106', 'transport', 'p3', 'Cab 45 min late at 8pm', true, 'switched vendor', 'vendor change'),
(now() - interval '2 days', '2026-06-01'::date, 'HOS-KOK-008', 'ENG-F-108', 'lighting', 'p1', 'Basement corridor unlit', false, null, 'red alert'),
(now() - interval '3 days', '2026-06-01'::date, 'HOS-KOK-008', 'ENG-F-108', 'escort_missing', 'p2', 'No escort 9pm visit', false, null, 'follow-up'),
(now() - interval '8 days', '2026-06-01'::date, 'HOS-RUB-013', 'ENG-F-113', 'unsafe_access', 'p2', 'Side gate route unsafe', false, null, 'route change'),
(now() - interval '15 days', '2026-06-01'::date, 'HOS-CMC-011', 'ENG-F-111', 'escort_missing', 'p3', 'Escort not on time', true, 'fixed', 'training'),
(now() - interval '1 day', '2026-06-01'::date, 'HOS-YAS-003', 'ENG-F-103', 'lighting', 'p3', 'Corridor bulb out', true, 'replaced', 'maint'),
(now() - interval '12 days', '2026-06-01'::date, 'HOS-RUB-013', 'ENG-F-113', 'transport', 'p3', 'Pickup point unclear', true, 'mapped', 'op update'),
(now() - interval '6 days', '2026-06-01'::date, 'HOS-KOK-008', 'ENG-F-108', 'harassment', 'p1', 'Inappropriate comment by vendor', false, null, 'HR escalated'),
(now() - interval '20 days', '2026-06-01'::date, 'HOS-NAR-006', 'ENG-F-106', 'other', 'p4', 'AC broken in waiting area', true, 'fixed', 'comfort'),
(now() - interval '4 days', '2026-06-01'::date, 'HOS-KIM-002', 'ENG-F-102', 'restroom', 'p3', 'Far restroom location', true, 'temp arrangement', 'site map'),
(now() - interval '7 days', '2026-06-01'::date, 'HOS-AII-009', 'ENG-F-109', 'transport', 'p3', 'Cab no-show once', true, 'replacement', 'vendor warning');

revoke all on female_engineer_site_comfort_r2952 from public, anon;
revoke all on female_engineer_site_incidents_r2952 from public, anon;
grant select on female_engineer_site_comfort_r2952 to authenticated;
grant select on female_engineer_site_incidents_r2952 to authenticated;

-- RPC 1: index overview by hospital
create or replace function founder_r2952_hospital_index()
returns table(hospital_code text, hospital_name text, city text, avg_comfort numeric, avg_safety numeric, avg_composite numeric, total_visits int, red_flag_engineers int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.hospital_code, c.hospital_name, c.city,
    round(avg(c.comfort_score)::numeric,2),
    round(avg(c.safety_score)::numeric,2),
    round(avg(c.composite_index)::numeric,2),
    sum(c.visits_count)::int,
    (count(*) filter (where c.red_flag))::int
  from female_engineer_site_comfort_r2952 c
  group by c.hospital_code, c.hospital_name, c.city
  order by avg(c.composite_index) asc;
end; $$;

-- RPC 2: engineer-level summary
create or replace function founder_r2952_engineer_summary()
returns table(engineer_code text, engineer_name text, visits_total int, avg_comfort numeric, avg_safety numeric, avg_composite numeric, sites_red int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.engineer_code, c.engineer_name,
    sum(c.visits_count)::int,
    round(avg(c.comfort_score)::numeric,2),
    round(avg(c.safety_score)::numeric,2),
    round(avg(c.composite_index)::numeric,2),
    (count(*) filter (where c.red_flag))::int
  from female_engineer_site_comfort_r2952 c
  group by c.engineer_code, c.engineer_name
  order by avg(c.composite_index) desc;
end; $$;

-- RPC 3: red flag sites
create or replace function founder_r2952_red_flag_sites()
returns table(hospital_code text, hospital_name text, city text, engineer_name text, composite_index numeric, restroom_access text, escort_provided boolean, incidents_reported int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.hospital_code, c.hospital_name, c.city, c.engineer_name, c.composite_index, c.restroom_access, c.escort_provided, c.incidents_reported
  from female_engineer_site_comfort_r2952 c
  where c.red_flag = true
  order by c.composite_index asc;
end; $$;

-- RPC 4: incident breakdown by type
create or replace function founder_r2952_incident_breakdown()
returns table(incident_type text, total_count int, p1_count int, p2_count int, p3_count int, p4_count int, unresolved int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.incident_type,
    count(*)::int,
    (count(*) filter (where i.severity='p1'))::int,
    (count(*) filter (where i.severity='p2'))::int,
    (count(*) filter (where i.severity='p3'))::int,
    (count(*) filter (where i.severity='p4'))::int,
    (count(*) filter (where i.resolved=false))::int
  from female_engineer_site_incidents_r2952 i
  group by i.incident_type
  order by count(*) desc;
end; $$;

-- RPC 5: restroom access distribution
create or replace function founder_r2952_restroom_access_mix()
returns table(restroom_access text, site_count int, avg_comfort numeric, share_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare tot int;
begin
  if not is_founder() then raise exception 'not founder'; end if;
  select count(*) into tot from female_engineer_site_comfort_r2952;
  return query
  select c.restroom_access,
    count(*)::int,
    round(avg(c.comfort_score)::numeric,2),
    round((count(*)*100.0/nullif(tot,0))::numeric,2)
  from female_engineer_site_comfort_r2952 c
  group by c.restroom_access
  order by count(*) desc;
end; $$;

-- RPC 6: open incidents detail
create or replace function founder_r2952_open_incidents()
returns table(hospital_code text, engineer_code text, incident_type text, severity text, description text, reported_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.hospital_code, i.engineer_code, i.incident_type, i.severity, i.description, i.reported_at
  from female_engineer_site_incidents_r2952 i
  where i.resolved = false
  order by case i.severity when 'p1' then 1 when 'p2' then 2 when 'p3' then 3 else 4 end, i.reported_at desc;
end; $$;

-- RPC 7: kpis
create or replace function founder_r2952_kpis()
returns table(total_sites int, total_visits int, avg_composite numeric, red_sites int, dedicated_restroom_pct numeric, escort_provided_pct numeric, open_p1_p2 int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select count(*)::int,
    coalesce(sum(c.visits_count),0)::int,
    round(coalesce(avg(c.composite_index),0)::numeric,2),
    (count(*) filter (where c.red_flag))::int,
    round((count(*) filter (where c.restroom_access='dedicated')*100.0/nullif(count(*),0))::numeric,2),
    round((count(*) filter (where c.escort_provided)*100.0/nullif(count(*),0))::numeric,2),
    (select count(*) from female_engineer_site_incidents_r2952 i where i.resolved=false and i.severity in ('p1','p2'))::int
  from female_engineer_site_comfort_r2952 c;
end; $$;

revoke all on function founder_r2952_hospital_index() from public, anon;
revoke all on function founder_r2952_engineer_summary() from public, anon;
revoke all on function founder_r2952_red_flag_sites() from public, anon;
revoke all on function founder_r2952_incident_breakdown() from public, anon;
revoke all on function founder_r2952_restroom_access_mix() from public, anon;
revoke all on function founder_r2952_open_incidents() from public, anon;
revoke all on function founder_r2952_kpis() from public, anon;

grant execute on function founder_r2952_hospital_index() to authenticated;
grant execute on function founder_r2952_engineer_summary() to authenticated;
grant execute on function founder_r2952_red_flag_sites() to authenticated;
grant execute on function founder_r2952_incident_breakdown() to authenticated;
grant execute on function founder_r2952_restroom_access_mix() to authenticated;
grant execute on function founder_r2952_open_incidents() to authenticated;
grant execute on function founder_r2952_kpis() to authenticated;
