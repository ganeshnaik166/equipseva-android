-- Round 2988 — Customer Monthly Engineer Hospital Lift-Elevator Annual-Maintenance Sync Tracker
-- HEAVY ★★★★

create table if not exists lift_elevator_amc_sync_contracts_r2988 (
  id uuid primary key default gen_random_uuid(),
  hospital_name text not null,
  hospital_city text not null,
  elevator_count int not null check (elevator_count between 1 and 40),
  amc_tier text not null check (amc_tier in ('bronze','silver','gold','platinum')),
  monthly_visit_quota int not null check (monthly_visit_quota between 1 and 12),
  monthly_visits_completed int not null default 0 check (monthly_visits_completed between 0 and 12),
  contract_start_date date not null,
  contract_end_date date not null,
  monthly_fee_rupees int not null check (monthly_fee_rupees between 5000 and 999999),
  assigned_engineer_name text not null,
  sync_status text not null check (sync_status in ('on_track','behind','ahead','at_risk','breached')),
  last_visit_at timestamptz,
  next_visit_due_at timestamptz,
  uptime_percent numeric(5,2) check (uptime_percent between 0 and 100),
  created_at timestamptz not null default now()
);

create table if not exists lift_elevator_amc_sync_visits_r2988 (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references lift_elevator_amc_sync_contracts_r2988(id) on delete cascade,
  visit_month date not null,
  scheduled_at timestamptz not null,
  completed_at timestamptz,
  engineer_name text not null,
  visit_outcome text not null check (visit_outcome in ('completed','partial','rescheduled','missed','customer_cancelled')),
  parts_replaced_count int not null default 0 check (parts_replaced_count between 0 and 25),
  duration_minutes int check (duration_minutes between 15 and 480),
  customer_signoff_received boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

alter table lift_elevator_amc_sync_contracts_r2988 enable row level security;
alter table lift_elevator_amc_sync_visits_r2988 enable row level security;

drop policy if exists lec_r2988_founder_read on lift_elevator_amc_sync_contracts_r2988;
create policy lec_r2988_founder_read on lift_elevator_amc_sync_contracts_r2988 for select to authenticated using (is_founder());

drop policy if exists lev_r2988_founder_read on lift_elevator_amc_sync_visits_r2988;
create policy lev_r2988_founder_read on lift_elevator_amc_sync_visits_r2988 for select to authenticated using (is_founder());

-- Seed contracts (18)
insert into lift_elevator_amc_sync_contracts_r2988
  (hospital_name, hospital_city, elevator_count, amc_tier, monthly_visit_quota, monthly_visits_completed, contract_start_date, contract_end_date, monthly_fee_rupees, assigned_engineer_name, sync_status, last_visit_at, next_visit_due_at, uptime_percent)
values
  ('Apollo Hospitals Jubilee','Hyderabad',8,'platinum',4,4,'2026-01-01'::date,'2026-12-31'::date,180000,'Ramesh Kumar','on_track',now() - interval '4 days', now() + interval '3 days', 99.20),
  ('KIMS Secunderabad','Hyderabad',6,'gold',3,2,'2026-02-15'::date,'2027-02-14'::date,120000,'Suresh Reddy','behind',now() - interval '12 days', now() - interval '1 day', 97.40),
  ('Care Banjara','Hyderabad',4,'silver',2,2,'2026-03-01'::date,'2027-02-28'::date,70000,'Pavan Gupta','on_track',now() - interval '6 days', now() + interval '8 days', 98.10),
  ('Yashoda Somajiguda','Hyderabad',10,'platinum',4,3,'2026-01-10'::date,'2026-12-31'::date,225000,'Anil Sharma','behind',now() - interval '9 days', now() - interval '2 days', 96.50),
  ('Continental Gachibowli','Hyderabad',7,'gold',3,3,'2026-02-01'::date,'2027-01-31'::date,135000,'Vikram Singh','ahead',now() - interval '2 days', now() + interval '12 days', 99.50),
  ('Rainbow Childrens Banjara','Hyderabad',3,'silver',2,1,'2026-04-01'::date,'2027-03-31'::date,55000,'Rajesh Yadav','at_risk',now() - interval '20 days', now() - interval '5 days', 94.10),
  ('Manipal Whitefield','Bengaluru',9,'platinum',4,4,'2026-01-01'::date,'2026-12-31'::date,195000,'Karthik Nair','on_track',now() - interval '3 days', now() + interval '5 days', 99.10),
  ('Fortis Bannerghatta','Bengaluru',6,'gold',3,3,'2026-02-10'::date,'2027-02-09'::date,125000,'Deepak Rao','on_track',now() - interval '5 days', now() + interval '7 days', 98.70),
  ('Narayana Bommasandra','Bengaluru',12,'platinum',4,2,'2026-01-20'::date,'2026-12-31'::date,240000,'Ganesh Iyer','breached',now() - interval '35 days', now() - interval '15 days', 91.20),
  ('Lilavati Bandra','Mumbai',5,'gold',3,3,'2026-03-15'::date,'2027-03-14'::date,115000,'Mahesh Patil','on_track',now() - interval '4 days', now() + interval '6 days', 98.90),
  ('Kokilaben Andheri','Mumbai',11,'platinum',4,3,'2026-01-05'::date,'2026-12-31'::date,230000,'Sanjay Joshi','behind',now() - interval '11 days', now() - interval '3 days', 96.80),
  ('Hinduja Mahim','Mumbai',7,'gold',3,2,'2026-02-20'::date,'2027-02-19'::date,140000,'Nitin Shah','at_risk',now() - interval '18 days', now() - interval '4 days', 95.30),
  ('Max Saket','Delhi',8,'platinum',4,4,'2026-01-15'::date,'2026-12-31'::date,185000,'Amit Verma','ahead',now() - interval '1 day', now() + interval '14 days', 99.40),
  ('Medanta Gurgaon','Gurgaon',14,'platinum',4,3,'2026-01-01'::date,'2026-12-31'::date,265000,'Rohit Malhotra','on_track',now() - interval '6 days', now() + interval '4 days', 98.60),
  ('Fortis Vasant Kunj','Delhi',6,'gold',3,1,'2026-02-25'::date,'2027-02-24'::date,130000,'Pankaj Tiwari','breached',now() - interval '40 days', now() - interval '18 days', 89.70),
  ('Apollo Chennai Greams','Chennai',9,'platinum',4,4,'2026-01-12'::date,'2026-12-31'::date,205000,'Senthil Murugan','on_track',now() - interval '2 days', now() + interval '10 days', 99.30),
  ('MIOT Manapakkam','Chennai',5,'silver',2,2,'2026-03-10'::date,'2027-03-09'::date,75000,'Karthikeyan R','on_track',now() - interval '7 days', now() + interval '9 days', 98.40),
  ('AMRI Kolkata','Kolkata',6,'bronze',2,1,'2026-04-05'::date,'2027-04-04'::date,45000,'Subhash Banerjee','at_risk',now() - interval '22 days', now() - interval '8 days', 93.80);

-- Seed visits (24)
insert into lift_elevator_amc_sync_visits_r2988
  (contract_id, visit_month, scheduled_at, completed_at, engineer_name, visit_outcome, parts_replaced_count, duration_minutes, customer_signoff_received, notes)
select c.id, date_trunc('month', now())::date, now() - interval '4 days', now() - interval '4 days', c.assigned_engineer_name, 'completed', 2, 120, true, 'Routine quarterly'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Apollo Hospitals Jubilee'
union all select c.id, date_trunc('month', now())::date, now() - interval '12 days', now() - interval '12 days', c.assigned_engineer_name, 'partial', 1, 90, false, 'Customer time crunch'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='KIMS Secunderabad'
union all select c.id, date_trunc('month', now())::date, now() - interval '6 days', now() - interval '6 days', c.assigned_engineer_name, 'completed', 3, 180, true, 'Cable swap'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Care Banjara'
union all select c.id, date_trunc('month', now())::date, now() - interval '9 days', now() - interval '9 days', c.assigned_engineer_name, 'completed', 0, 60, true, 'Inspection only'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Yashoda Somajiguda'
union all select c.id, date_trunc('month', now())::date, now() - interval '2 days', now() - interval '2 days', c.assigned_engineer_name, 'completed', 4, 240, true, 'Brake pad service'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Continental Gachibowli'
union all select c.id, date_trunc('month', now())::date, now() - interval '20 days', null, c.assigned_engineer_name, 'rescheduled', 0, null, false, 'Engineer reassigned'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Rainbow Childrens Banjara'
union all select c.id, date_trunc('month', now())::date, now() - interval '3 days', now() - interval '3 days', c.assigned_engineer_name, 'completed', 1, 150, true, 'Door sensor calibration'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Manipal Whitefield'
union all select c.id, date_trunc('month', now())::date, now() - interval '5 days', now() - interval '5 days', c.assigned_engineer_name, 'completed', 2, 135, true, 'Hoist motor lube'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Fortis Bannerghatta'
union all select c.id, date_trunc('month', now())::date, now() - interval '35 days', null, c.assigned_engineer_name, 'missed', 0, null, false, 'Critical SLA breach'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Narayana Bommasandra'
union all select c.id, date_trunc('month', now())::date, now() - interval '4 days', now() - interval '4 days', c.assigned_engineer_name, 'completed', 1, 110, true, 'Bearing replacement'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Lilavati Bandra'
union all select c.id, date_trunc('month', now())::date, now() - interval '11 days', now() - interval '11 days', c.assigned_engineer_name, 'partial', 2, 95, false, 'Patient evacuation drill'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Kokilaben Andheri'
union all select c.id, date_trunc('month', now())::date, now() - interval '18 days', null, c.assigned_engineer_name, 'customer_cancelled', 0, null, false, 'Hospital ICU surge'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Hinduja Mahim'
union all select c.id, date_trunc('month', now())::date, now() - interval '1 day', now() - interval '1 day', c.assigned_engineer_name, 'completed', 3, 200, true, 'Full inspection'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Max Saket'
union all select c.id, date_trunc('month', now())::date, now() - interval '6 days', now() - interval '6 days', c.assigned_engineer_name, 'completed', 2, 165, true, 'Floor leveler tune'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Medanta Gurgaon'
union all select c.id, date_trunc('month', now())::date, now() - interval '40 days', null, c.assigned_engineer_name, 'missed', 0, null, false, 'No engineer assigned'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Fortis Vasant Kunj'
union all select c.id, date_trunc('month', now())::date, now() - interval '2 days', now() - interval '2 days', c.assigned_engineer_name, 'completed', 1, 130, true, 'Standard sync'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Apollo Chennai Greams'
union all select c.id, date_trunc('month', now())::date, now() - interval '7 days', now() - interval '7 days', c.assigned_engineer_name, 'completed', 0, 75, true, 'Quick check'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='MIOT Manapakkam'
union all select c.id, date_trunc('month', now())::date, now() - interval '22 days', null, c.assigned_engineer_name, 'rescheduled', 0, null, false, 'Engineer on leave'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='AMRI Kolkata'
union all select c.id, (date_trunc('month', now()) - interval '1 month')::date, now() - interval '35 days', now() - interval '35 days', c.assigned_engineer_name, 'completed', 2, 145, true, 'Prev month'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Apollo Hospitals Jubilee'
union all select c.id, (date_trunc('month', now()) - interval '1 month')::date, now() - interval '40 days', now() - interval '40 days', c.assigned_engineer_name, 'completed', 1, 105, true, 'Prev month'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Manipal Whitefield'
union all select c.id, (date_trunc('month', now()) - interval '1 month')::date, now() - interval '38 days', now() - interval '38 days', c.assigned_engineer_name, 'partial', 0, 70, false, 'Prev month'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Narayana Bommasandra'
union all select c.id, (date_trunc('month', now()) - interval '1 month')::date, now() - interval '42 days', now() - interval '42 days', c.assigned_engineer_name, 'completed', 3, 190, true, 'Prev month'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Medanta Gurgaon'
union all select c.id, (date_trunc('month', now()) - interval '1 month')::date, now() - interval '45 days', now() - interval '45 days', c.assigned_engineer_name, 'completed', 2, 155, true, 'Prev month'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Kokilaben Andheri'
union all select c.id, (date_trunc('month', now()) - interval '1 month')::date, now() - interval '50 days', null, c.assigned_engineer_name, 'missed', 0, null, false, 'Prev month miss'
  from lift_elevator_amc_sync_contracts_r2988 c where c.hospital_name='Fortis Vasant Kunj';

-- RPCs

create or replace function r2988_sync_overview()
returns table(total_contracts int, on_track int, behind int, at_risk int, breached int, avg_uptime numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select count(*)::int,
           (count(*) filter (where sync_status='on_track'))::int,
           (count(*) filter (where sync_status='behind'))::int,
           (count(*) filter (where sync_status='at_risk'))::int,
           (count(*) filter (where sync_status='breached'))::int,
           round(avg(uptime_percent),2)
      from lift_elevator_amc_sync_contracts_r2988;
end$$;

create or replace function r2988_contracts_by_tier()
returns table(amc_tier text, contracts int, total_elevators int, monthly_revenue_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.amc_tier, count(*)::int, sum(c.elevator_count)::int, sum(c.monthly_fee_rupees)::bigint
      from lift_elevator_amc_sync_contracts_r2988 c
     group by c.amc_tier
     order by sum(c.monthly_fee_rupees) desc;
end$$;

create or replace function r2988_behind_schedule()
returns table(hospital_name text, hospital_city text, sync_status text, monthly_visit_quota int, monthly_visits_completed int, next_visit_due_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.hospital_name, c.hospital_city, c.sync_status, c.monthly_visit_quota, c.monthly_visits_completed, c.next_visit_due_at
      from lift_elevator_amc_sync_contracts_r2988 c
     where c.sync_status in ('behind','at_risk','breached')
     order by c.monthly_visits_completed::numeric / nullif(c.monthly_visit_quota,0) asc nulls first;
end$$;

create or replace function r2988_engineer_load()
returns table(assigned_engineer_name text, contracts int, total_elevators int, avg_uptime numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.assigned_engineer_name, count(*)::int, sum(c.elevator_count)::int, round(avg(c.uptime_percent),2)
      from lift_elevator_amc_sync_contracts_r2988 c
     group by c.assigned_engineer_name
     order by sum(c.elevator_count) desc;
end$$;

create or replace function r2988_visit_outcomes()
returns table(visit_outcome text, visits int, signoff_count int, total_parts int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select v.visit_outcome, count(*)::int,
           (count(*) filter (where v.customer_signoff_received))::int,
           sum(v.parts_replaced_count)::int
      from lift_elevator_amc_sync_visits_r2988 v
     group by v.visit_outcome
     order by count(*) desc;
end$$;

create or replace function r2988_city_breakdown()
returns table(hospital_city text, contracts int, elevators int, breached_count int, avg_uptime numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.hospital_city, count(*)::int, sum(c.elevator_count)::int,
           (count(*) filter (where c.sync_status='breached'))::int,
           round(avg(c.uptime_percent),2)
      from lift_elevator_amc_sync_contracts_r2988 c
     group by c.hospital_city
     order by count(*) desc;
end$$;

create or replace function r2988_recent_visits()
returns table(hospital_name text, engineer_name text, scheduled_at timestamptz, visit_outcome text, parts_replaced_count int, signoff boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.hospital_name, v.engineer_name, v.scheduled_at, v.visit_outcome, v.parts_replaced_count, v.customer_signoff_received
      from lift_elevator_amc_sync_visits_r2988 v
      join lift_elevator_amc_sync_contracts_r2988 c on c.id = v.contract_id
     order by v.scheduled_at desc
     limit 20;
end$$;

revoke all on function r2988_sync_overview() from public, anon;
revoke all on function r2988_contracts_by_tier() from public, anon;
revoke all on function r2988_behind_schedule() from public, anon;
revoke all on function r2988_engineer_load() from public, anon;
revoke all on function r2988_visit_outcomes() from public, anon;
revoke all on function r2988_city_breakdown() from public, anon;
revoke all on function r2988_recent_visits() from public, anon;

grant execute on function r2988_sync_overview() to authenticated;
grant execute on function r2988_contracts_by_tier() to authenticated;
grant execute on function r2988_behind_schedule() to authenticated;
grant execute on function r2988_engineer_load() to authenticated;
grant execute on function r2988_visit_outcomes() to authenticated;
grant execute on function r2988_city_breakdown() to authenticated;
grant execute on function r2988_recent_visits() to authenticated;
