-- Round 3050: Engineer Monthly Customer Site Critical-Care Bed Mattress Pressure-Sensor Audit
-- HEAVY ★★★★

create table if not exists engineer_bed_mattress_audits_r3050 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  customer_org_id uuid not null,
  engineer_user_id uuid not null,
  bed_asset_tag text not null,
  ward_name text not null,
  bed_model text not null,
  mattress_type text not null check (mattress_type in ('alternating_pressure','low_air_loss','foam_static','gel_overlay','hybrid')),
  sensor_count int not null check (sensor_count between 1 and 16),
  audit_status text not null check (audit_status in ('passed','failed','partial','pending','rescheduled')),
  overall_pressure_kpa numeric(6,2) not null check (overall_pressure_kpa between 0 and 99.99),
  patient_present boolean not null,
  notes text
);

create table if not exists engineer_bed_mattress_sensor_readings_r3050 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references engineer_bed_mattress_audits_r3050(id) on delete cascade,
  sensor_index int not null check (sensor_index between 1 and 16),
  zone text not null check (zone in ('head','shoulders','sacrum','heels','left_hip','right_hip','calves')),
  measured_kpa numeric(6,2) not null check (measured_kpa between 0 and 99.99),
  expected_min_kpa numeric(6,2) not null check (expected_min_kpa between 0 and 99.99),
  expected_max_kpa numeric(6,2) not null check (expected_max_kpa between 0 and 99.99),
  result text not null check (result in ('in_range','under','over','dead_sensor','noisy')),
  remediation text
);

alter table engineer_bed_mattress_audits_r3050 enable row level security;
alter table engineer_bed_mattress_sensor_readings_r3050 enable row level security;

drop policy if exists founder_all_audits_r3050 on engineer_bed_mattress_audits_r3050;
create policy founder_all_audits_r3050 on engineer_bed_mattress_audits_r3050 for select using (is_founder());

drop policy if exists founder_all_readings_r3050 on engineer_bed_mattress_sensor_readings_r3050;
create policy founder_all_readings_r3050 on engineer_bed_mattress_sensor_readings_r3050 for select using (is_founder());

-- Seed audits (15 rows)
insert into engineer_bed_mattress_audits_r3050
  (audit_month, customer_org_id, engineer_user_id, bed_asset_tag, ward_name, bed_model, mattress_type, sensor_count, audit_status, overall_pressure_kpa, patient_present, notes)
values
  ('2026-06-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-001', 'ICU-A', 'Hillrom-900', 'alternating_pressure', 8, 'passed', 4.20, true, 'all zones nominal'),
  ('2026-06-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-002', 'ICU-A', 'Hillrom-900', 'low_air_loss', 8, 'failed', 6.80, true, 'sacrum over-pressure'),
  ('2026-06-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-003', 'ICU-B', 'Stryker-MX', 'hybrid', 10, 'partial', 3.90, false, '1 dead sensor'),
  ('2026-06-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-CCU-101', 'CCU', 'Hillrom-900', 'alternating_pressure', 8, 'passed', 4.10, true, null),
  ('2026-06-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-CCU-102', 'CCU', 'Stryker-MX', 'gel_overlay', 6, 'pending', 0.00, false, 'patient transfer delayed'),
  ('2026-05-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-001', 'ICU-A', 'Hillrom-900', 'alternating_pressure', 8, 'passed', 4.30, true, null),
  ('2026-05-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-004', 'ICU-A', 'Hillrom-900', 'foam_static', 4, 'failed', 7.20, true, 'heels region overloaded'),
  ('2026-05-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-NICU-01', 'NICU', 'Stryker-MX', 'low_air_loss', 6, 'passed', 2.80, true, 'neonatal calibration ok'),
  ('2026-05-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-005', 'ICU-B', 'Hillrom-900', 'alternating_pressure', 8, 'rescheduled', 0.00, false, 'ward closed for cleaning'),
  ('2026-04-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-001', 'ICU-A', 'Hillrom-900', 'alternating_pressure', 8, 'passed', 4.15, true, null),
  ('2026-04-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-002', 'ICU-A', 'Hillrom-900', 'low_air_loss', 8, 'partial', 5.40, true, '2 noisy sensors'),
  ('2026-04-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-CCU-101', 'CCU', 'Hillrom-900', 'alternating_pressure', 8, 'failed', 6.95, true, 'pump weak'),
  ('2026-04-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-HDU-201', 'HDU', 'Stryker-MX', 'hybrid', 10, 'passed', 3.85, false, null),
  ('2026-03-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-ICU-003', 'ICU-B', 'Stryker-MX', 'hybrid', 10, 'passed', 3.95, true, null),
  ('2026-03-01'::date, gen_random_uuid(), gen_random_uuid(), 'BED-NICU-01', 'NICU', 'Stryker-MX', 'low_air_loss', 6, 'failed', 8.10, true, 'heel sensor failure');

-- Seed readings (20 rows)
with a as (
  select id from engineer_bed_mattress_audits_r3050 order by created_at limit 1
)
insert into engineer_bed_mattress_sensor_readings_r3050
  (audit_id, sensor_index, zone, measured_kpa, expected_min_kpa, expected_max_kpa, result, remediation)
select id, 1, 'head', 3.80, 3.50, 4.50, 'in_range', null from a union all
select id, 2, 'shoulders', 4.10, 3.50, 4.50, 'in_range', null from a union all
select id, 3, 'sacrum', 6.90, 3.50, 4.50, 'over', 'rebalance pump output' from a union all
select id, 4, 'heels', 3.20, 3.50, 4.50, 'under', 'inspect cell leak' from a union all
select id, 5, 'left_hip', 4.20, 3.50, 4.50, 'in_range', null from a union all
select id, 6, 'right_hip', 4.20, 3.50, 4.50, 'in_range', null from a union all
select id, 7, 'calves', 0.00, 3.50, 4.50, 'dead_sensor', 'replace sensor' from a union all
select id, 8, 'sacrum', 5.50, 3.50, 4.50, 'noisy', 'recalibrate' from a union all
select id, 1, 'head', 3.90, 3.50, 4.50, 'in_range', null from a union all
select id, 2, 'shoulders', 4.05, 3.50, 4.50, 'in_range', null from a union all
select id, 3, 'sacrum', 4.30, 3.50, 4.50, 'in_range', null from a union all
select id, 4, 'heels', 4.00, 3.50, 4.50, 'in_range', null from a union all
select id, 5, 'left_hip', 4.10, 3.50, 4.50, 'in_range', null from a union all
select id, 6, 'right_hip', 4.15, 3.50, 4.50, 'in_range', null from a union all
select id, 7, 'calves', 4.00, 3.50, 4.50, 'in_range', null from a union all
select id, 8, 'sacrum', 4.20, 3.50, 4.50, 'in_range', null from a union all
select id, 1, 'head', 7.20, 3.50, 4.50, 'over', 'lower pressure setpoint' from a union all
select id, 2, 'shoulders', 3.10, 3.50, 4.50, 'under', 'check leak' from a union all
select id, 3, 'sacrum', 0.00, 3.50, 4.50, 'dead_sensor', 'replace sensor head' from a union all
select id, 4, 'heels', 5.80, 3.50, 4.50, 'noisy', 'recalibrate baseline' from a;

revoke all on engineer_bed_mattress_audits_r3050 from public, anon;
revoke all on engineer_bed_mattress_sensor_readings_r3050 from public, anon;

-- RPC 1: list audits
create or replace function list_bed_audits_r3050()
returns table(
  id uuid,
  audit_month date,
  bed_asset_tag text,
  ward_name text,
  bed_model text,
  mattress_type text,
  sensor_count int,
  audit_status text,
  overall_pressure_kpa numeric,
  patient_present boolean
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.id, a.audit_month, a.bed_asset_tag, a.ward_name, a.bed_model,
           a.mattress_type, a.sensor_count, a.audit_status, a.overall_pressure_kpa, a.patient_present
    from engineer_bed_mattress_audits_r3050 a
    order by a.audit_month desc, a.bed_asset_tag asc;
end $$;
revoke all on function list_bed_audits_r3050() from public, anon;
grant execute on function list_bed_audits_r3050() to authenticated;

-- RPC 2: status breakdown
create or replace function audit_status_breakdown_r3050()
returns table(audit_status text, n int, avg_pressure numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.audit_status, count(*)::int, round(avg(a.overall_pressure_kpa)::numeric, 2)
    from engineer_bed_mattress_audits_r3050 a
    group by a.audit_status
    order by count(*) desc;
end $$;
revoke all on function audit_status_breakdown_r3050() from public, anon;
grant execute on function audit_status_breakdown_r3050() to authenticated;

-- RPC 3: ward summary
create or replace function ward_summary_r3050()
returns table(ward_name text, n_audits int, n_failed int, n_passed int, avg_pressure numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.ward_name,
           count(*)::int,
           (count(*) filter (where a.audit_status = 'failed'))::int,
           (count(*) filter (where a.audit_status = 'passed'))::int,
           round(avg(a.overall_pressure_kpa)::numeric, 2)
    from engineer_bed_mattress_audits_r3050 a
    group by a.ward_name
    order by (count(*) filter (where a.audit_status = 'failed'))::int desc;
end $$;
revoke all on function ward_summary_r3050() from public, anon;
grant execute on function ward_summary_r3050() to authenticated;

-- RPC 4: mattress type rollup
create or replace function mattress_type_rollup_r3050()
returns table(mattress_type text, n int, fail_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.mattress_type,
           count(*)::int,
           round((100.0 * (count(*) filter (where a.audit_status = 'failed')) / nullif(count(*),0))::numeric, 1)
    from engineer_bed_mattress_audits_r3050 a
    group by a.mattress_type
    order by count(*) desc;
end $$;
revoke all on function mattress_type_rollup_r3050() from public, anon;
grant execute on function mattress_type_rollup_r3050() to authenticated;

-- RPC 5: sensor reading issues
create or replace function sensor_reading_issues_r3050()
returns table(
  reading_id uuid,
  bed_asset_tag text,
  ward_name text,
  sensor_index int,
  zone text,
  measured_kpa numeric,
  expected_min_kpa numeric,
  expected_max_kpa numeric,
  result text,
  remediation text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select r.id, a.bed_asset_tag, a.ward_name, r.sensor_index, r.zone,
           r.measured_kpa, r.expected_min_kpa, r.expected_max_kpa, r.result, r.remediation
    from engineer_bed_mattress_sensor_readings_r3050 r
    join engineer_bed_mattress_audits_r3050 a on a.id = r.audit_id
    where r.result <> 'in_range'
    order by a.audit_month desc, a.bed_asset_tag, r.sensor_index;
end $$;
revoke all on function sensor_reading_issues_r3050() from public, anon;
grant execute on function sensor_reading_issues_r3050() to authenticated;

-- RPC 6: zone failure heatmap
create or replace function zone_failure_heatmap_r3050()
returns table(zone text, n_readings int, n_failures int, fail_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select r.zone,
           count(*)::int,
           (count(*) filter (where r.result <> 'in_range'))::int,
           round((100.0 * (count(*) filter (where r.result <> 'in_range')) / nullif(count(*),0))::numeric, 1)
    from engineer_bed_mattress_sensor_readings_r3050 r
    group by r.zone
    order by (count(*) filter (where r.result <> 'in_range'))::int desc;
end $$;
revoke all on function zone_failure_heatmap_r3050() from public, anon;
grant execute on function zone_failure_heatmap_r3050() to authenticated;

-- RPC 7: monthly trend
create or replace function monthly_audit_trend_r3050()
returns table(audit_month date, n int, n_failed int, n_passed int, avg_pressure numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select a.audit_month,
           count(*)::int,
           (count(*) filter (where a.audit_status = 'failed'))::int,
           (count(*) filter (where a.audit_status = 'passed'))::int,
           round(avg(a.overall_pressure_kpa)::numeric, 2)
    from engineer_bed_mattress_audits_r3050 a
    group by a.audit_month
    order by a.audit_month desc;
end $$;
revoke all on function monthly_audit_trend_r3050() from public, anon;
grant execute on function monthly_audit_trend_r3050() to authenticated;