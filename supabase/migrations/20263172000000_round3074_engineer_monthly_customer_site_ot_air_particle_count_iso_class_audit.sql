-- Round r3074 — Engineer Monthly Customer Site OT Air Particle Count & ISO-Class Audit

create table if not exists ot_air_particle_audits_r3074 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  city text not null,
  ot_room_label text not null,
  audit_month date not null,
  engineer_name text not null,
  particles_05um_per_m3 int not null,
  particles_5um_per_m3 int not null,
  measured_iso_class text not null check (measured_iso_class in ('ISO-5','ISO-6','ISO-7','ISO-8','ISO-9')),
  target_iso_class text not null check (target_iso_class in ('ISO-5','ISO-6','ISO-7','ISO-8')),
  result_status text not null check (result_status in ('pass','marginal','fail','retest_required')),
  hepa_filter_age_months int,
  temperature_c numeric(4,1),
  humidity_pct numeric(4,1),
  pressure_pa numeric(5,1),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists ot_air_remediation_actions_r3074 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references ot_air_particle_audits_r3074(id) on delete cascade,
  action_type text not null check (action_type in ('hepa_replace','prefilter_clean','ahu_rebalance','seal_repair','revalidation','training','no_action')),
  severity text not null check (severity in ('low','medium','high','critical')),
  assigned_engineer text not null,
  scheduled_date date,
  completed_date date,
  cost_rupees int,
  status text not null check (status in ('open','scheduled','in_progress','done','cancelled')),
  remarks text,
  created_at timestamptz not null default now()
);

alter table ot_air_particle_audits_r3074 enable row level security;
alter table ot_air_remediation_actions_r3074 enable row level security;

drop policy if exists r3074_audits_founder on ot_air_particle_audits_r3074;
create policy r3074_audits_founder on ot_air_particle_audits_r3074 for select using (is_founder());

drop policy if exists r3074_actions_founder on ot_air_remediation_actions_r3074;
create policy r3074_actions_founder on ot_air_remediation_actions_r3074 for select using (is_founder());

insert into ot_air_particle_audits_r3074 (hospital_name, city, ot_room_label, audit_month, engineer_name, particles_05um_per_m3, particles_5um_per_m3, measured_iso_class, target_iso_class, result_status, hepa_filter_age_months, temperature_c, humidity_pct, pressure_pa, notes) values
('Apollo Jubilee','Hyderabad','OT-1 Cardiac','2026-06-01'::date,'Rajesh Kumar',2840,18,'ISO-7','ISO-7','pass',9,21.5,52.0,12.5,'Stable'),
('Apollo Jubilee','Hyderabad','OT-2 Ortho','2026-06-01'::date,'Rajesh Kumar',9120,68,'ISO-8','ISO-7','fail',14,22.8,58.2,8.1,'HEPA loaded'),
('KIMS Secunderabad','Hyderabad','OT-3 Neuro','2026-06-01'::date,'Anitha Reddy',1820,9,'ISO-6','ISO-6','pass',4,20.5,48.5,15.2,'Excellent'),
('Yashoda Somajiguda','Hyderabad','OT-A General','2026-06-01'::date,'Vikram Singh',38400,210,'ISO-9','ISO-8','fail',22,24.1,64.0,4.2,'Seal breach'),
('Continental Gachibowli','Hyderabad','OT-7 Robotic','2026-06-01'::date,'Anitha Reddy',520,2,'ISO-5','ISO-5','pass',2,20.0,45.0,18.5,'Brand-new HEPA'),
('Care Banjara','Hyderabad','OT-4 Vascular','2026-06-01'::date,'Suresh Mehta',3200,22,'ISO-7','ISO-7','marginal',11,21.8,55.0,11.0,'Near upper limit'),
('Manipal Vijayanagar','Bangalore','OT-1 Cardiac','2026-06-01'::date,'Deepika Rao',2950,19,'ISO-7','ISO-7','pass',8,21.0,51.5,12.8,null),
('Fortis Bannerghatta','Bangalore','OT-2 Onco','2026-06-01'::date,'Deepika Rao',7800,55,'ISO-8','ISO-7','fail',16,23.5,60.0,7.5,'AHU imbalance'),
('Narayana Hrudayalaya','Bangalore','OT-Cath-1','2026-06-01'::date,'Mahesh Iyer',1680,8,'ISO-6','ISO-6','pass',5,20.8,49.0,14.5,'Good'),
('Sakra World','Bangalore','OT-5 Transplant','2026-06-01'::date,'Mahesh Iyer',780,3,'ISO-5','ISO-5','pass',3,20.2,46.5,17.0,'Class A'),
('Aster CMI','Bangalore','OT-3 General','2026-06-01'::date,'Priya Nair',12400,85,'ISO-8','ISO-7','retest_required',18,23.0,61.5,6.2,'Pending retest'),
('Lilavati Bandra','Mumbai','OT-1 Cardiac','2026-06-01'::date,'Arjun Patel',3050,21,'ISO-7','ISO-7','pass',7,21.2,52.8,13.0,'Stable'),
('Kokilaben Andheri','Mumbai','OT-4 Neuro','2026-06-01'::date,'Arjun Patel',1940,10,'ISO-6','ISO-6','pass',6,20.9,50.0,15.8,null),
('Hinduja Mahim','Mumbai','OT-2 General','2026-06-01'::date,'Sneha Joshi',8950,62,'ISO-8','ISO-7','fail',15,23.8,62.5,5.8,'Filter spent'),
('Fortis Mulund','Mumbai','OT-6 Ortho','2026-06-01'::date,'Sneha Joshi',4100,28,'ISO-7','ISO-7','marginal',12,22.0,56.0,10.2,'Watch'),
('Wockhardt Mira Road','Mumbai','OT-A Cardiac','2026-06-01'::date,'Rohan Desai',2780,17,'ISO-7','ISO-7','pass',8,21.5,53.0,12.0,null),
('Max Saket','Delhi','OT-1 Robotic','2026-06-01'::date,'Karan Malhotra',610,2,'ISO-5','ISO-5','pass',2,20.1,45.5,18.0,'Excellent'),
('AIIMS Delhi','Delhi','OT-12 Trauma','2026-06-01'::date,'Karan Malhotra',6200,45,'ISO-8','ISO-7','fail',17,24.0,63.0,4.8,'Public load'),
('Medanta Gurgaon','Delhi','OT-3 Neuro','2026-06-01'::date,'Neha Kapoor',1740,9,'ISO-6','ISO-6','pass',5,20.6,48.0,15.5,null),
('BLK Pusa','Delhi','OT-5 General','2026-06-01'::date,'Neha Kapoor',9800,72,'ISO-8','ISO-7','fail',19,23.5,61.0,5.2,'Schedule HEPA'),
('Apollo Greams','Chennai','OT-1 Cardiac','2026-06-01'::date,'Lakshmi Iyer',2920,20,'ISO-7','ISO-7','pass',8,21.4,52.2,12.6,null),
('MIOT Manapakkam','Chennai','OT-2 Ortho','2026-06-01'::date,'Lakshmi Iyer',5400,38,'ISO-7','ISO-7','marginal',13,22.2,57.0,9.8,'Borderline'),
('SIMS Vadapalani','Chennai','OT-3 Onco','2026-06-01'::date,'Praveen Reddy',1620,8,'ISO-6','ISO-6','pass',4,20.7,49.5,15.0,null),
('Fortis Malar','Chennai','OT-4 General','2026-06-01'::date,'Praveen Reddy',11200,82,'ISO-8','ISO-7','fail',20,23.7,62.0,5.5,'Replace HEPA');

insert into ot_air_remediation_actions_r3074 (action_type, severity, assigned_engineer, scheduled_date, completed_date, cost_rupees, status, remarks) values
('hepa_replace','high','Rajesh Kumar','2026-06-15'::date,'2026-06-18'::date,42000,'done','OT-2 Apollo Jubilee'),
('seal_repair','critical','Vikram Singh','2026-06-10'::date,'2026-06-12'::date,8500,'done','Yashoda OT-A gasket'),
('hepa_replace','high','Deepika Rao','2026-06-20'::date,null,38000,'scheduled','Fortis Bannerghatta OT-2'),
('ahu_rebalance','medium','Suresh Mehta','2026-06-25'::date,null,12000,'in_progress','Care Banjara OT-4'),
('prefilter_clean','low','Anitha Reddy','2026-06-08'::date,'2026-06-09'::date,1500,'done','Routine pre-filter'),
('revalidation','high','Priya Nair',null,null,null,'open','Aster CMI retest pending'),
('hepa_replace','critical','Sneha Joshi','2026-06-22'::date,null,45000,'scheduled','Hinduja Mahim OT-2'),
('training','low','Mahesh Iyer',null,null,null,'open','Gowning refresher Sakra'),
('hepa_replace','high','Karan Malhotra','2026-06-28'::date,null,40000,'scheduled','AIIMS OT-12 Trauma'),
('seal_repair','medium','Neha Kapoor','2026-06-26'::date,null,7200,'scheduled','BLK Pusa OT-5'),
('ahu_rebalance','medium','Lakshmi Iyer','2026-06-30'::date,null,11500,'open','MIOT OT-2 borderline'),
('hepa_replace','high','Praveen Reddy','2026-07-02'::date,null,39500,'open','Fortis Malar OT-4'),
('no_action','low','Arjun Patel',null,'2026-06-05'::date,0,'done','Lilavati OT-1 within spec'),
('prefilter_clean','low','Rohan Desai','2026-06-12'::date,'2026-06-13'::date,1400,'done','Wockhardt routine'),
('revalidation','medium','Anitha Reddy','2026-07-05'::date,null,9000,'scheduled','Continental annual revalidation');

create or replace function r3074_iso_class_distribution()
returns table(measured_iso_class text, audits int, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.measured_iso_class,
         count(*)::int,
         (count(*) filter (where a.result_status = 'fail'))::int
  from ot_air_particle_audits_r3074 a
  group by a.measured_iso_class
  order by a.measured_iso_class;
end $$;

create or replace function r3074_city_pass_rate()
returns table(city text, audits int, passed int, failed int, pass_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.city,
         count(*)::int,
         (count(*) filter (where a.result_status = 'pass'))::int,
         (count(*) filter (where a.result_status = 'fail'))::int,
         round(100.0 * (count(*) filter (where a.result_status = 'pass')) / nullif(count(*),0), 1)
  from ot_air_particle_audits_r3074 a
  group by a.city
  order by a.city;
end $$;

create or replace function r3074_engineer_scorecard()
returns table(engineer_name text, audits int, pass_count int, fail_count int, marginal_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name,
         count(*)::int,
         (count(*) filter (where a.result_status = 'pass'))::int,
         (count(*) filter (where a.result_status = 'fail'))::int,
         (count(*) filter (where a.result_status = 'marginal'))::int
  from ot_air_particle_audits_r3074 a
  group by a.engineer_name
  order by a.engineer_name;
end $$;

create or replace function r3074_failing_ots()
returns table(hospital_name text, ot_room_label text, measured_iso_class text, target_iso_class text, particles_05um_per_m3 int, hepa_filter_age_months int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.ot_room_label, a.measured_iso_class, a.target_iso_class, a.particles_05um_per_m3, a.hepa_filter_age_months
  from ot_air_particle_audits_r3074 a
  where a.result_status in ('fail','retest_required')
  order by a.particles_05um_per_m3 desc;
end $$;

create or replace function r3074_hepa_age_buckets()
returns table(bucket text, ots int, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select case
           when a.hepa_filter_age_months <= 6 then '0-6 months'
           when a.hepa_filter_age_months <= 12 then '7-12 months'
           when a.hepa_filter_age_months <= 18 then '13-18 months'
           else '19+ months'
         end as bucket,
         count(*)::int,
         (count(*) filter (where a.result_status = 'fail'))::int
  from ot_air_particle_audits_r3074 a
  group by 1
  order by 1;
end $$;

create or replace function r3074_remediation_status_summary()
returns table(status text, actions int, total_cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.status,
         count(*)::int,
         coalesce(sum(r.cost_rupees),0)::bigint
  from ot_air_remediation_actions_r3074 r
  group by r.status
  order by r.status;
end $$;

create or replace function r3074_critical_open_actions()
returns table(action_type text, severity text, assigned_engineer text, scheduled_date date, remarks text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.action_type, r.severity, r.assigned_engineer, r.scheduled_date, r.remarks
  from ot_air_remediation_actions_r3074 r
  where r.severity in ('high','critical') and r.status in ('open','scheduled','in_progress')
  order by r.severity desc, r.scheduled_date nulls last;
end $$;

revoke all on function r3074_iso_class_distribution() from public, anon;
revoke all on function r3074_city_pass_rate() from public, anon;
revoke all on function r3074_engineer_scorecard() from public, anon;
revoke all on function r3074_failing_ots() from public, anon;
revoke all on function r3074_hepa_age_buckets() from public, anon;
revoke all on function r3074_remediation_status_summary() from public, anon;
revoke all on function r3074_critical_open_actions() from public, anon;

grant execute on function r3074_iso_class_distribution() to authenticated;
grant execute on function r3074_city_pass_rate() to authenticated;
grant execute on function r3074_engineer_scorecard() to authenticated;
grant execute on function r3074_failing_ots() to authenticated;
grant execute on function r3074_hepa_age_buckets() to authenticated;
grant execute on function r3074_remediation_status_summary() to authenticated;
grant execute on function r3074_critical_open_actions() to authenticated;
