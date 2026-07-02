-- Round r2976 — Customer Monthly Engineer Hospital Foot-Traffic Density Visit-Schedule Optimization
-- HEAVY ★★★★

create table if not exists hospital_foot_traffic_density_r2976 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_code text not null,
  hospital_name text not null,
  city text not null,
  month_label text not null,
  visit_count int not null check (visit_count >= 0),
  unique_engineers int not null check (unique_engineers >= 0),
  avg_dwell_minutes numeric(6,2) not null check (avg_dwell_minutes >= 0),
  density_score numeric(5,2) not null check (density_score between 0 and 100),
  density_band text not null check (density_band in ('sparse','moderate','dense','saturated')),
  peak_weekday text not null check (peak_weekday in ('mon','tue','wed','thu','fri','sat','sun')),
  congestion_flag boolean not null default false
);

create table if not exists engineer_visit_schedule_optimization_r2976 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  engineer_code text not null,
  engineer_name text not null,
  hospital_code text not null,
  proposed_slot timestamptz not null,
  current_slot timestamptz,
  slot_status text not null check (slot_status in ('proposed','approved','rejected','rescheduled','locked')),
  optimization_gain_minutes int not null check (optimization_gain_minutes >= 0),
  travel_km numeric(6,2) not null check (travel_km >= 0),
  priority text not null check (priority in ('low','medium','high','critical')),
  conflict_count int not null default 0 check (conflict_count >= 0)
);

alter table hospital_foot_traffic_density_r2976 enable row level security;
alter table engineer_visit_schedule_optimization_r2976 enable row level security;

drop policy if exists hftd_r2976_founder on hospital_foot_traffic_density_r2976;
create policy hftd_r2976_founder on hospital_foot_traffic_density_r2976
  for select using (is_founder());

drop policy if exists evso_r2976_founder on engineer_visit_schedule_optimization_r2976;
create policy evso_r2976_founder on engineer_visit_schedule_optimization_r2976
  for select using (is_founder());

revoke all on hospital_foot_traffic_density_r2976 from public, anon;
revoke all on engineer_visit_schedule_optimization_r2976 from public, anon;
grant select on hospital_foot_traffic_density_r2976 to authenticated;
grant select on engineer_visit_schedule_optimization_r2976 to authenticated;

-- Seed: hospital_foot_traffic_density_r2976 (18 rows)
insert into hospital_foot_traffic_density_r2976
(hospital_code, hospital_name, city, month_label, visit_count, unique_engineers, avg_dwell_minutes, density_score, density_band, peak_weekday, congestion_flag) values
('H001','Apollo Jubilee','Hyderabad','2026-06',124,9,52.30,82.50,'saturated','wed',true),
('H002','KIMS Secunderabad','Hyderabad','2026-06',88,7,48.10,68.20,'dense','tue',true),
('H003','Yashoda Somajiguda','Hyderabad','2026-06',61,6,44.50,54.10,'dense','thu',false),
('H004','Fortis Banjara','Hyderabad','2026-06',42,5,39.80,41.20,'moderate','mon',false),
('H005','Care Banjara','Hyderabad','2026-06',31,4,36.10,33.40,'moderate','fri',false),
('H006','AIG Gachibowli','Hyderabad','2026-06',27,4,42.20,29.80,'moderate','wed',false),
('H007','Sunshine Paradise','Hyderabad','2026-06',18,3,33.40,21.10,'sparse','sat',false),
('H008','Continental Nanakramguda','Hyderabad','2026-06',15,3,31.20,18.40,'sparse','tue',false),
('H009','Manipal Bangalore','Bangalore','2026-06',97,8,50.10,71.30,'dense','thu',true),
('H010','Narayana HSR','Bangalore','2026-06',73,6,46.40,62.80,'dense','wed',false),
('H011','Fortis Bannerghatta','Bangalore','2026-06',54,5,43.20,49.10,'moderate','fri',false),
('H012','Cloudnine Jayanagar','Bangalore','2026-06',38,4,38.70,36.20,'moderate','tue',false),
('H013','Apollo Greams Road','Chennai','2026-06',102,8,51.80,76.40,'dense','wed',true),
('H014','MIOT International','Chennai','2026-06',64,6,45.20,57.30,'dense','mon',false),
('H015','Kauvery Alwarpet','Chennai','2026-06',45,5,41.10,43.80,'moderate','thu',false),
('H016','Lilavati Bandra','Mumbai','2026-06',81,7,47.60,66.40,'dense','wed',true),
('H017','Hinduja Mahim','Mumbai','2026-06',58,5,42.90,52.20,'dense','fri',false),
('H018','Nanavati Vile Parle','Mumbai','2026-06',22,4,34.50,24.60,'sparse','sat',false);

-- Seed: engineer_visit_schedule_optimization_r2976 (18 rows)
insert into engineer_visit_schedule_optimization_r2976
(engineer_code, engineer_name, hospital_code, proposed_slot, current_slot, slot_status, optimization_gain_minutes, travel_km, priority, conflict_count) values
('E101','Ravi Kumar','H001','2026-07-01 09:30:00+05:30'::timestamptz,'2026-07-01 11:00:00+05:30'::timestamptz,'proposed',42,8.40,'high',1),
('E101','Ravi Kumar','H002','2026-07-01 14:00:00+05:30'::timestamptz,'2026-07-01 15:30:00+05:30'::timestamptz,'approved',28,5.20,'medium',0),
('E102','Suresh M','H003','2026-07-02 10:00:00+05:30'::timestamptz,'2026-07-02 13:00:00+05:30'::timestamptz,'rescheduled',60,12.10,'high',2),
('E102','Suresh M','H004','2026-07-02 15:00:00+05:30'::timestamptz,null,'proposed',18,6.80,'low',0),
('E103','Arjun P','H001','2026-07-03 08:30:00+05:30'::timestamptz,'2026-07-03 10:00:00+05:30'::timestamptz,'locked',35,4.60,'critical',1),
('E103','Arjun P','H005','2026-07-03 13:00:00+05:30'::timestamptz,'2026-07-03 14:30:00+05:30'::timestamptz,'approved',22,7.30,'medium',0),
('E104','Vikram S','H009','2026-07-04 09:00:00+05:30'::timestamptz,'2026-07-04 11:30:00+05:30'::timestamptz,'proposed',48,9.10,'high',1),
('E104','Vikram S','H010','2026-07-04 14:30:00+05:30'::timestamptz,null,'proposed',12,3.40,'low',0),
('E105','Naveen R','H011','2026-07-05 10:30:00+05:30'::timestamptz,'2026-07-05 12:00:00+05:30'::timestamptz,'rejected',0,11.20,'medium',3),
('E105','Naveen R','H012','2026-07-05 15:00:00+05:30'::timestamptz,'2026-07-05 16:30:00+05:30'::timestamptz,'approved',26,5.80,'medium',0),
('E106','Mahesh T','H013','2026-07-06 09:00:00+05:30'::timestamptz,'2026-07-06 11:00:00+05:30'::timestamptz,'locked',40,7.50,'critical',1),
('E106','Mahesh T','H014','2026-07-06 13:30:00+05:30'::timestamptz,null,'proposed',16,4.20,'low',0),
('E107','Karthik V','H015','2026-07-07 10:00:00+05:30'::timestamptz,'2026-07-07 12:00:00+05:30'::timestamptz,'proposed',30,6.10,'high',1),
('E107','Karthik V','H006','2026-07-07 14:00:00+05:30'::timestamptz,'2026-07-07 15:30:00+05:30'::timestamptz,'approved',20,8.90,'medium',0),
('E108','Deepak L','H016','2026-07-08 09:30:00+05:30'::timestamptz,'2026-07-08 11:00:00+05:30'::timestamptz,'rescheduled',38,10.40,'high',2),
('E108','Deepak L','H017','2026-07-08 14:30:00+05:30'::timestamptz,null,'proposed',14,7.20,'low',0),
('E109','Anil B','H018','2026-07-09 10:00:00+05:30'::timestamptz,'2026-07-09 12:30:00+05:30'::timestamptz,'approved',32,5.60,'medium',0),
('E109','Anil B','H007','2026-07-09 15:00:00+05:30'::timestamptz,'2026-07-09 16:30:00+05:30'::timestamptz,'locked',24,6.40,'critical',1);

-- RPCs

create or replace function r2976_density_summary()
returns table(density_band text, hospital_count int, total_visits int, avg_density numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.density_band,
         (count(*))::int,
         (sum(h.visit_count))::int,
         round(avg(h.density_score),2)
  from hospital_foot_traffic_density_r2976 h
  group by h.density_band
  order by avg(h.density_score) desc;
end$$;

create or replace function r2976_top_dense_hospitals()
returns table(hospital_code text, hospital_name text, city text, visit_count int, density_score numeric, peak_weekday text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.hospital_code, h.hospital_name, h.city, h.visit_count, h.density_score, h.peak_weekday
  from hospital_foot_traffic_density_r2976 h
  order by h.density_score desc
  limit 10;
end$$;

create or replace function r2976_city_rollup()
returns table(city text, hospitals int, total_visits int, congested int, avg_dwell numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.city,
         (count(*))::int,
         (sum(h.visit_count))::int,
         (count(*) filter (where h.congestion_flag))::int,
         round(avg(h.avg_dwell_minutes),2)
  from hospital_foot_traffic_density_r2976 h
  group by h.city
  order by sum(h.visit_count) desc;
end$$;

create or replace function r2976_schedule_status_breakdown()
returns table(slot_status text, slot_count int, total_gain int, avg_travel numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.slot_status,
         (count(*))::int,
         (sum(e.optimization_gain_minutes))::int,
         round(avg(e.travel_km),2)
  from engineer_visit_schedule_optimization_r2976 e
  group by e.slot_status
  order by count(*) desc;
end$$;

create or replace function r2976_engineer_optimization_board()
returns table(engineer_code text, engineer_name text, total_slots int, approved_slots int, total_gain int, total_travel numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.engineer_code, e.engineer_name,
         (count(*))::int,
         (count(*) filter (where e.slot_status in ('approved','locked')))::int,
         (sum(e.optimization_gain_minutes))::int,
         round(sum(e.travel_km),2)
  from engineer_visit_schedule_optimization_r2976 e
  group by e.engineer_code, e.engineer_name
  order by sum(e.optimization_gain_minutes) desc;
end$$;

create or replace function r2976_priority_conflicts()
returns table(priority text, slot_count int, conflicts int, avg_gain numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select e.priority,
         (count(*))::int,
         (sum(e.conflict_count))::int,
         round(avg(e.optimization_gain_minutes),2)
  from engineer_visit_schedule_optimization_r2976 e
  group by e.priority
  order by case e.priority when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;
end$$;

create or replace function r2976_dense_hospital_schedule_match()
returns table(hospital_code text, hospital_name text, density_score numeric, scheduled_slots int, total_gain int, congestion_flag boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select h.hospital_code, h.hospital_name, h.density_score,
         (count(e.id))::int,
         (coalesce(sum(e.optimization_gain_minutes),0))::int,
         h.congestion_flag
  from hospital_foot_traffic_density_r2976 h
  left join engineer_visit_schedule_optimization_r2976 e on e.hospital_code = h.hospital_code
  group by h.hospital_code, h.hospital_name, h.density_score, h.congestion_flag
  order by h.density_score desc;
end$$;

revoke all on function r2976_density_summary() from public, anon;
revoke all on function r2976_top_dense_hospitals() from public, anon;
revoke all on function r2976_city_rollup() from public, anon;
revoke all on function r2976_schedule_status_breakdown() from public, anon;
revoke all on function r2976_engineer_optimization_board() from public, anon;
revoke all on function r2976_priority_conflicts() from public, anon;
revoke all on function r2976_dense_hospital_schedule_match() from public, anon;

grant execute on function r2976_density_summary() to authenticated;
grant execute on function r2976_top_dense_hospitals() to authenticated;
grant execute on function r2976_city_rollup() to authenticated;
grant execute on function r2976_schedule_status_breakdown() to authenticated;
grant execute on function r2976_engineer_optimization_board() to authenticated;
grant execute on function r2976_priority_conflicts() to authenticated;
grant execute on function r2976_dense_hospital_schedule_match() to authenticated;
