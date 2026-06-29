-- Round 3020: Customer Monthly Engineer Hospital MRI-Suite Helium Boil-Off Rate & Refill Tracker
-- HEAVY ★★★★

create extension if not exists pgcrypto;

-- =========================================================================
-- TABLE 1: monthly helium boil-off readings per MRI suite
-- =========================================================================
create table if not exists mri_helium_boiloff_readings_r3020 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid,
  suite_code text not null,
  scanner_model text not null,
  field_strength_tesla numeric(3,1) not null check (field_strength_tesla in (1.5, 3.0, 7.0)),
  reading_month date not null,
  helium_level_pct numeric(5,2) not null check (helium_level_pct between 0 and 100),
  boiloff_rate_pct_per_month numeric(5,3) not null check (boiloff_rate_pct_per_month between 0 and 10),
  ambient_temp_c numeric(4,1) not null check (ambient_temp_c between -10 and 60),
  cold_head_runtime_hours int not null check (cold_head_runtime_hours between 0 and 1000),
  quench_risk_band text not null check (quench_risk_band in ('green','amber','red','critical')),
  reading_status text not null check (reading_status in ('normal','elevated','urgent','vendor_review')),
  engineer_user_id uuid,
  notes text,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table mri_helium_boiloff_readings_r3020 enable row level security;

drop policy if exists founder_read_r3020_readings on mri_helium_boiloff_readings_r3020;
create policy founder_read_r3020_readings on mri_helium_boiloff_readings_r3020
  for select using (is_founder());

-- Seed 18 readings (varied months/hospitals/risk bands)
insert into mri_helium_boiloff_readings_r3020
  (suite_code, scanner_model, field_strength_tesla, reading_month, helium_level_pct, boiloff_rate_pct_per_month, ambient_temp_c, cold_head_runtime_hours, quench_risk_band, reading_status, notes)
values
  ('AIIMS-MRI-01','Siemens Magnetom Vida',3.0,'2026-01-01'::date,87.50,0.420,22.0,720,'green','normal','baseline ok'),
  ('AIIMS-MRI-01','Siemens Magnetom Vida',3.0,'2026-02-01'::date,86.90,0.610,23.5,712,'green','normal','steady'),
  ('AIIMS-MRI-01','Siemens Magnetom Vida',3.0,'2026-03-01'::date,85.40,1.510,24.8,705,'amber','elevated','rate climbing'),
  ('AIIMS-MRI-02','GE Signa Premier',3.0,'2026-01-01'::date,72.10,0.380,21.5,718,'green','normal',null),
  ('AIIMS-MRI-02','GE Signa Premier',3.0,'2026-02-01'::date,71.40,0.700,22.0,720,'green','normal','within spec'),
  ('AIIMS-MRI-02','GE Signa Premier',3.0,'2026-03-01'::date,69.80,1.610,22.8,716,'amber','elevated','watch'),
  ('AIIMS-MRI-02','GE Signa Premier',3.0,'2026-04-01'::date,64.20,5.600,23.5,690,'red','urgent','cold head suspect'),
  ('APOLLO-DLF-MRI-A','Philips Ingenia Elition',3.0,'2026-02-01'::date,91.20,0.290,21.0,724,'green','normal','best in fleet'),
  ('APOLLO-DLF-MRI-A','Philips Ingenia Elition',3.0,'2026-03-01'::date,90.80,0.410,21.2,720,'green','normal',null),
  ('APOLLO-DLF-MRI-A','Philips Ingenia Elition',3.0,'2026-04-01'::date,90.30,0.520,21.5,722,'green','normal','stable'),
  ('FORTIS-BLR-MRI-1','Siemens Magnetom Sola',1.5,'2026-03-01'::date,55.40,2.100,25.0,700,'amber','elevated','older system'),
  ('FORTIS-BLR-MRI-1','Siemens Magnetom Sola',1.5,'2026-04-01'::date,49.80,5.610,26.8,680,'red','urgent','schedule refill'),
  ('MAX-SAKET-MRI-2','Canon Vantage Galan',1.5,'2026-04-01'::date,38.20,3.800,27.5,665,'red','urgent','critical low'),
  ('MAX-SAKET-MRI-2','Canon Vantage Galan',1.5,'2026-05-01'::date,15.40,9.200,29.0,620,'critical','vendor_review','quench imminent'),
  ('MEDANTA-MRI-7T','Siemens Magnetom Terra',7.0,'2026-03-01'::date,94.10,0.180,20.0,732,'green','normal','7T pristine'),
  ('MEDANTA-MRI-7T','Siemens Magnetom Terra',7.0,'2026-04-01'::date,93.80,0.310,20.2,728,'green','normal',null),
  ('NARAYANA-MRI-3','GE Architect',3.0,'2026-04-01'::date,68.50,1.420,23.0,710,'amber','elevated','monitor'),
  ('NARAYANA-MRI-3','GE Architect',3.0,'2026-05-01'::date,62.10,6.350,24.5,695,'red','vendor_review','OEM ticket open');

-- =========================================================================
-- TABLE 2: refill events and engineer assignments
-- =========================================================================
create table if not exists mri_helium_refill_events_r3020 (
  id uuid primary key default gen_random_uuid(),
  reading_id uuid,
  hospital_org_id uuid,
  suite_code text not null,
  engineer_user_id uuid,
  engineer_display_name text not null,
  refill_status text not null check (refill_status in ('scheduled','in_progress','completed','cancelled','failed')),
  litres_delivered numeric(6,2) not null check (litres_delivered between 0 and 5000),
  helium_price_inr_per_litre numeric(7,2) not null check (helium_price_inr_per_litre between 0 and 10000),
  total_cost_inr numeric(12,2) not null check (total_cost_inr between 0 and 50000000),
  downtime_hours numeric(5,2) not null check (downtime_hours between 0 and 168),
  customer_sat_rating int check (customer_sat_rating between 1 and 5),
  scheduled_at timestamptz not null,
  completed_at timestamptz,
  vendor_name text not null,
  created_at timestamptz not null default now()
);

alter table mri_helium_refill_events_r3020 enable row level security;

drop policy if exists founder_read_r3020_refills on mri_helium_refill_events_r3020;
create policy founder_read_r3020_refills on mri_helium_refill_events_r3020
  for select using (is_founder());

-- Seed 16 refill events
insert into mri_helium_refill_events_r3020
  (suite_code, engineer_display_name, refill_status, litres_delivered, helium_price_inr_per_litre, total_cost_inr, downtime_hours, customer_sat_rating, scheduled_at, completed_at, vendor_name)
values
  ('AIIMS-MRI-01','Ravi Kumar','completed',1200.00,2850.00,3420000.00,18.5,5,'2026-01-10 09:00'::timestamptz,'2026-01-11 03:30'::timestamptz,'Linde India'),
  ('AIIMS-MRI-02','Priya Sharma','completed',1500.00,2900.00,4350000.00,22.0,4,'2026-02-05 08:00'::timestamptz,'2026-02-06 06:00'::timestamptz,'Air Liquide'),
  ('AIIMS-MRI-02','Priya Sharma','in_progress',1600.00,3050.00,4880000.00,24.0,null,'2026-04-15 07:00'::timestamptz,null::timestamptz,'Linde India'),
  ('APOLLO-DLF-MRI-A','Suresh Naidu','completed',900.00,2820.00,2538000.00,14.0,5,'2026-02-12 10:00'::timestamptz,'2026-02-13 00:00'::timestamptz,'Inox Air Products'),
  ('APOLLO-DLF-MRI-A','Suresh Naidu','scheduled',950.00,2900.00,2755000.00,15.0,null,'2026-05-20 10:00'::timestamptz,null::timestamptz,'Linde India'),
  ('FORTIS-BLR-MRI-1','Anita Rao','completed',1100.00,3100.00,3410000.00,28.0,3,'2026-03-08 09:00'::timestamptz,'2026-03-09 13:00'::timestamptz,'Air Liquide'),
  ('FORTIS-BLR-MRI-1','Anita Rao','failed',0.00,3100.00,0.00,4.5,2,'2026-04-10 09:00'::timestamptz,'2026-04-10 13:30'::timestamptz,'Air Liquide'),
  ('FORTIS-BLR-MRI-1','Vikram Joshi','completed',1250.00,3150.00,3937500.00,30.0,4,'2026-04-18 08:00'::timestamptz,'2026-04-19 14:00'::timestamptz,'Linde India'),
  ('MAX-SAKET-MRI-2','Mohan Das','completed',1400.00,3200.00,4480000.00,36.0,3,'2026-04-22 06:00'::timestamptz,'2026-04-23 18:00'::timestamptz,'Inox Air Products'),
  ('MAX-SAKET-MRI-2','Mohan Das','scheduled',1500.00,3250.00,4875000.00,40.0,null,'2026-05-25 06:00'::timestamptz,null::timestamptz,'Linde India'),
  ('MEDANTA-MRI-7T','Lakshmi Iyer','completed',2400.00,3400.00,8160000.00,48.0,5,'2026-03-15 05:00'::timestamptz,'2026-03-17 05:00'::timestamptz,'Linde India'),
  ('MEDANTA-MRI-7T','Lakshmi Iyer','scheduled',2500.00,3450.00,8625000.00,50.0,null,'2026-06-15 05:00'::timestamptz,null::timestamptz,'Linde India'),
  ('NARAYANA-MRI-3','Raghav Mehta','completed',1050.00,2950.00,3097500.00,20.0,4,'2026-04-25 07:00'::timestamptz,'2026-04-26 03:00'::timestamptz,'Air Liquide'),
  ('NARAYANA-MRI-3','Raghav Mehta','in_progress',1150.00,3000.00,3450000.00,22.0,null,'2026-05-28 07:00'::timestamptz,null::timestamptz,'Linde India'),
  ('AIIMS-MRI-01','Ravi Kumar','cancelled',0.00,2900.00,0.00,0.00,null,'2026-03-20 09:00'::timestamptz,null::timestamptz,'Linde India'),
  ('APOLLO-DLF-MRI-A','Suresh Naidu','completed',850.00,2800.00,2380000.00,12.5,5,'2026-04-08 10:00'::timestamptz,'2026-04-08 22:30'::timestamptz,'Linde India');

-- =========================================================================
-- RPC 1: fleet summary by hospital suite (latest reading)
-- =========================================================================
create or replace function fn_r3020_fleet_summary()
returns table (
  suite_code text,
  scanner_model text,
  field_strength_tesla numeric,
  latest_helium_pct numeric,
  latest_boiloff_pct numeric,
  latest_risk_band text,
  latest_reading_month date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select distinct on (r.suite_code)
      r.suite_code,
      r.scanner_model,
      r.field_strength_tesla,
      r.helium_level_pct,
      r.boiloff_rate_pct_per_month,
      r.quench_risk_band,
      r.reading_month
    from mri_helium_boiloff_readings_r3020 r
    order by r.suite_code, r.reading_month desc;
end;
$$;

revoke all on function fn_r3020_fleet_summary() from public, anon;
grant execute on function fn_r3020_fleet_summary() to authenticated;

-- =========================================================================
-- RPC 2: risk band distribution
-- =========================================================================
create or replace function fn_r3020_risk_distribution()
returns table (
  quench_risk_band text,
  reading_count int,
  avg_helium_pct numeric,
  avg_boiloff_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.quench_risk_band,
      count(*)::int,
      round(avg(r.helium_level_pct), 2),
      round(avg(r.boiloff_rate_pct_per_month), 3)
    from mri_helium_boiloff_readings_r3020 r
    group by r.quench_risk_band
    order by r.quench_risk_band;
end;
$$;

revoke all on function fn_r3020_risk_distribution() from public, anon;
grant execute on function fn_r3020_risk_distribution() to authenticated;

-- =========================================================================
-- RPC 3: monthly boil-off trend
-- =========================================================================
create or replace function fn_r3020_monthly_trend()
returns table (
  reading_month date,
  total_readings int,
  red_count int,
  critical_count int,
  avg_boiloff_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.reading_month,
      count(*)::int,
      (count(*) filter (where r.quench_risk_band = 'red'))::int,
      (count(*) filter (where r.quench_risk_band = 'critical'))::int,
      round(avg(r.boiloff_rate_pct_per_month), 3)
    from mri_helium_boiloff_readings_r3020 r
    group by r.reading_month
    order by r.reading_month;
end;
$$;

revoke all on function fn_r3020_monthly_trend() from public, anon;
grant execute on function fn_r3020_monthly_trend() to authenticated;

-- =========================================================================
-- RPC 4: refill spend by vendor
-- =========================================================================
create or replace function fn_r3020_vendor_spend()
returns table (
  vendor_name text,
  refill_count int,
  total_litres numeric,
  total_spend_inr numeric,
  avg_price_per_litre numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      e.vendor_name,
      count(*)::int,
      round(sum(e.litres_delivered), 2),
      round(sum(e.total_cost_inr), 2),
      round(avg(e.helium_price_inr_per_litre), 2)
    from mri_helium_refill_events_r3020 e
    where e.refill_status = 'completed'
    group by e.vendor_name
    order by sum(e.total_cost_inr) desc;
end;
$$;

revoke all on function fn_r3020_vendor_spend() from public, anon;
grant execute on function fn_r3020_vendor_spend() to authenticated;

-- =========================================================================
-- RPC 5: engineer performance leaderboard
-- =========================================================================
create or replace function fn_r3020_engineer_leaderboard()
returns table (
  engineer_display_name text,
  completed_refills int,
  failed_refills int,
  avg_sat_rating numeric,
  avg_downtime_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      e.engineer_display_name,
      (count(*) filter (where e.refill_status = 'completed'))::int,
      (count(*) filter (where e.refill_status = 'failed'))::int,
      round(avg(e.customer_sat_rating) filter (where e.customer_sat_rating is not null), 2),
      round(avg(e.downtime_hours) filter (where e.refill_status = 'completed'), 2)
    from mri_helium_refill_events_r3020 e
    group by e.engineer_display_name
    order by (count(*) filter (where e.refill_status = 'completed')) desc;
end;
$$;

revoke all on function fn_r3020_engineer_leaderboard() from public, anon;
grant execute on function fn_r3020_engineer_leaderboard() to authenticated;

-- =========================================================================
-- RPC 6: critical suites needing intervention
-- =========================================================================
create or replace function fn_r3020_critical_suites()
returns table (
  suite_code text,
  scanner_model text,
  helium_level_pct numeric,
  boiloff_rate_pct_per_month numeric,
  reading_status text,
  reading_month date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      r.suite_code,
      r.scanner_model,
      r.helium_level_pct,
      r.boiloff_rate_pct_per_month,
      r.reading_status,
      r.reading_month,
      r.notes
    from mri_helium_boiloff_readings_r3020 r
    where r.quench_risk_band in ('red','critical')
       or r.reading_status in ('urgent','vendor_review')
    order by r.helium_level_pct asc;
end;
$$;

revoke all on function fn_r3020_critical_suites() from public, anon;
grant execute on function fn_r3020_critical_suites() to authenticated;

-- =========================================================================
-- RPC 7: upcoming refills (scheduled + in_progress)
-- =========================================================================
create or replace function fn_r3020_upcoming_refills()
returns table (
  suite_code text,
  engineer_display_name text,
  refill_status text,
  litres_delivered numeric,
  total_cost_inr numeric,
  scheduled_at timestamptz,
  vendor_name text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      e.suite_code,
      e.engineer_display_name,
      e.refill_status,
      e.litres_delivered,
      e.total_cost_inr,
      e.scheduled_at,
      e.vendor_name
    from mri_helium_refill_events_r3020 e
    where e.refill_status in ('scheduled','in_progress')
    order by e.scheduled_at asc;
end;
$$;

revoke all on function fn_r3020_upcoming_refills() from public, anon;
grant execute on function fn_r3020_upcoming_refills() to authenticated;

-- =========================================================================
-- RPC 8: kpi headline
-- =========================================================================
create or replace function fn_r3020_kpi_headline()
returns table (
  total_suites int,
  red_or_critical_suites int,
  ytd_refill_spend_inr numeric,
  total_litres_delivered numeric,
  avg_boiloff_pct numeric,
  scheduled_refills int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      (select count(distinct suite_code) from mri_helium_boiloff_readings_r3020)::int,
      (select count(distinct suite_code) from mri_helium_boiloff_readings_r3020 where quench_risk_band in ('red','critical'))::int,
      coalesce((select sum(total_cost_inr) from mri_helium_refill_events_r3020 where refill_status = 'completed'), 0)::numeric,
      coalesce((select sum(litres_delivered) from mri_helium_refill_events_r3020 where refill_status = 'completed'), 0)::numeric,
      coalesce((select round(avg(boiloff_rate_pct_per_month), 3) from mri_helium_boiloff_readings_r3020), 0)::numeric,
      (select count(*) from mri_helium_refill_events_r3020 where refill_status = 'scheduled')::int;
end;
$$;

revoke all on function fn_r3020_kpi_headline() from public, anon;
grant execute on function fn_r3020_kpi_headline() to authenticated;
