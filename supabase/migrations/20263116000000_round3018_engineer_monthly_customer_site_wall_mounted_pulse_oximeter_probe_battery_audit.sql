-- r3018 — Engineer Monthly Customer Site Wall-Mounted-Pulse-Oximeter Probe & Battery Audit

create table if not exists pulse_ox_probe_audits_r3018 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_month date not null,
  hospital_name text not null,
  site_location text not null,
  engineer_name text not null,
  device_serial text not null,
  probe_type text not null check (probe_type in ('adult_finger','pediatric_finger','neonatal_wrap','ear_clip','reusable_soft')),
  probe_condition text not null check (probe_condition in ('excellent','good','worn','damaged','replace_now')),
  cable_integrity text not null check (cable_integrity in ('intact','frayed','exposed','broken')),
  spo2_accuracy_pct numeric(5,2) not null check (spo2_accuracy_pct between 70 and 100),
  pulse_rate_accuracy_pct numeric(5,2) not null check (pulse_rate_accuracy_pct between 70 and 100),
  drift_detected boolean not null default false,
  replacement_recommended boolean not null default false,
  audit_status text not null check (audit_status in ('pass','warn','fail','replaced'))
);

create table if not exists pulse_ox_battery_audits_r3018 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  audit_month date not null,
  hospital_name text not null,
  device_serial text not null,
  engineer_name text not null,
  battery_type text not null check (battery_type in ('li_ion','ni_mh','sealed_lead_acid','alkaline_pack')),
  battery_age_months int not null check (battery_age_months between 0 and 120),
  capacity_pct numeric(5,2) not null check (capacity_pct between 0 and 100),
  runtime_hours numeric(6,2) not null check (runtime_hours between 0 and 48),
  charge_cycles int not null check (charge_cycles between 0 and 5000),
  swelling_detected boolean not null default false,
  voltage_ok boolean not null default true,
  replacement_recommended boolean not null default false,
  battery_status text not null check (battery_status in ('healthy','aging','warn','critical','replaced'))
);

alter table pulse_ox_probe_audits_r3018 enable row level security;
alter table pulse_ox_battery_audits_r3018 enable row level security;

drop policy if exists probe_audits_founder_r3018 on pulse_ox_probe_audits_r3018;
create policy probe_audits_founder_r3018 on pulse_ox_probe_audits_r3018 for select to authenticated using (is_founder());

drop policy if exists battery_audits_founder_r3018 on pulse_ox_battery_audits_r3018;
create policy battery_audits_founder_r3018 on pulse_ox_battery_audits_r3018 for select to authenticated using (is_founder());

insert into pulse_ox_probe_audits_r3018 (audit_month, hospital_name, site_location, engineer_name, device_serial, probe_type, probe_condition, cable_integrity, spo2_accuracy_pct, pulse_rate_accuracy_pct, drift_detected, replacement_recommended, audit_status) values
('2026-06-01'::date, 'Apollo Hyderabad', 'ICU Bay 3', 'Ravi Kumar', 'POX-A1001', 'adult_finger', 'good', 'intact', 98.5, 99.2, false, false, 'pass'),
('2026-06-01'::date, 'Yashoda Secunderabad', 'Ward 7B', 'Suresh Naik', 'POX-A1002', 'adult_finger', 'worn', 'frayed', 95.1, 97.8, true, true, 'warn'),
('2026-06-01'::date, 'KIMS Kondapur', 'OT 2', 'Anjali Rao', 'POX-A1003', 'pediatric_finger', 'excellent', 'intact', 99.1, 99.5, false, false, 'pass'),
('2026-06-01'::date, 'Care Banjara', 'NICU', 'Pavan Reddy', 'POX-A1004', 'neonatal_wrap', 'damaged', 'exposed', 88.4, 92.1, true, true, 'fail'),
('2026-06-01'::date, 'Continental Gachibowli', 'ICU 1', 'Lakshmi N', 'POX-A1005', 'adult_finger', 'good', 'intact', 97.8, 98.4, false, false, 'pass'),
('2026-06-01'::date, 'AIG Gachibowli', 'Ward 4', 'Ramesh Babu', 'POX-A1006', 'ear_clip', 'worn', 'intact', 94.2, 96.7, true, false, 'warn'),
('2026-06-01'::date, 'Sunshine Paradise', 'ICU 2', 'Deepa K', 'POX-A1007', 'adult_finger', 'replace_now', 'broken', 79.3, 84.5, true, true, 'fail'),
('2026-06-01'::date, 'Rainbow Banjara', 'PICU', 'Vikram S', 'POX-A1008', 'pediatric_finger', 'good', 'intact', 98.1, 99.0, false, false, 'pass'),
('2026-06-01'::date, 'Star Begumpet', 'ER', 'Naveen Chand', 'POX-A1009', 'reusable_soft', 'excellent', 'intact', 99.4, 99.7, false, false, 'pass'),
('2026-06-01'::date, 'MaxCure Madhapur', 'Ward 9', 'Pooja Sharma', 'POX-A1010', 'adult_finger', 'worn', 'frayed', 93.8, 95.6, true, true, 'replaced'),
('2026-06-01'::date, 'Citizens Nallagandla', 'ICU', 'Karthik V', 'POX-A1011', 'adult_finger', 'good', 'intact', 97.1, 98.2, false, false, 'pass'),
('2026-06-01'::date, 'Olive Hitech', 'Day Care', 'Sandeep R', 'POX-A1012', 'ear_clip', 'damaged', 'frayed', 89.5, 91.4, true, true, 'fail'),
('2026-05-01'::date, 'Apollo Hyderabad', 'ICU Bay 3', 'Ravi Kumar', 'POX-A1001', 'adult_finger', 'good', 'intact', 98.9, 99.4, false, false, 'pass'),
('2026-05-01'::date, 'Yashoda Secunderabad', 'Ward 7B', 'Suresh Naik', 'POX-A1002', 'adult_finger', 'good', 'intact', 96.8, 98.1, false, false, 'pass'),
('2026-05-01'::date, 'KIMS Kondapur', 'OT 2', 'Anjali Rao', 'POX-A1003', 'pediatric_finger', 'excellent', 'intact', 99.3, 99.6, false, false, 'pass'),
('2026-05-01'::date, 'Care Banjara', 'NICU', 'Pavan Reddy', 'POX-A1004', 'neonatal_wrap', 'worn', 'intact', 94.5, 96.2, true, false, 'warn'),
('2026-05-01'::date, 'AIG Gachibowli', 'Ward 4', 'Ramesh Babu', 'POX-A1006', 'ear_clip', 'good', 'intact', 97.4, 98.5, false, false, 'pass'),
('2026-05-01'::date, 'Sunshine Paradise', 'ICU 2', 'Deepa K', 'POX-A1007', 'adult_finger', 'worn', 'frayed', 92.1, 94.8, true, true, 'warn');

insert into pulse_ox_battery_audits_r3018 (audit_month, hospital_name, device_serial, engineer_name, battery_type, battery_age_months, capacity_pct, runtime_hours, charge_cycles, swelling_detected, voltage_ok, replacement_recommended, battery_status) values
('2026-06-01'::date, 'Apollo Hyderabad', 'POX-A1001', 'Ravi Kumar', 'li_ion', 8, 94.5, 11.2, 142, false, true, false, 'healthy'),
('2026-06-01'::date, 'Yashoda Secunderabad', 'POX-A1002', 'Suresh Naik', 'li_ion', 22, 72.1, 7.4, 410, false, true, false, 'aging'),
('2026-06-01'::date, 'KIMS Kondapur', 'POX-A1003', 'Anjali Rao', 'ni_mh', 14, 81.3, 8.9, 285, false, true, false, 'healthy'),
('2026-06-01'::date, 'Care Banjara', 'POX-A1004', 'Pavan Reddy', 'li_ion', 36, 48.2, 3.8, 720, true, false, true, 'critical'),
('2026-06-01'::date, 'Continental Gachibowli', 'POX-A1005', 'Lakshmi N', 'li_ion', 6, 96.8, 12.0, 95, false, true, false, 'healthy'),
('2026-06-01'::date, 'AIG Gachibowli', 'POX-A1006', 'Ramesh Babu', 'sealed_lead_acid', 30, 65.4, 5.2, 380, false, true, true, 'warn'),
('2026-06-01'::date, 'Sunshine Paradise', 'POX-A1007', 'Deepa K', 'li_ion', 42, 38.5, 2.4, 890, true, false, true, 'critical'),
('2026-06-01'::date, 'Rainbow Banjara', 'POX-A1008', 'Vikram S', 'li_ion', 10, 92.1, 10.8, 175, false, true, false, 'healthy'),
('2026-06-01'::date, 'Star Begumpet', 'POX-A1009', 'Naveen Chand', 'alkaline_pack', 4, 88.6, 6.5, 0, false, true, false, 'healthy'),
('2026-06-01'::date, 'MaxCure Madhapur', 'POX-A1010', 'Pooja Sharma', 'li_ion', 26, 68.9, 6.1, 480, false, true, true, 'aging'),
('2026-06-01'::date, 'Citizens Nallagandla', 'POX-A1011', 'Karthik V', 'ni_mh', 18, 76.4, 7.8, 320, false, true, false, 'healthy'),
('2026-06-01'::date, 'Olive Hitech', 'POX-A1012', 'Sandeep R', 'li_ion', 40, 42.3, 3.1, 815, true, false, true, 'critical'),
('2026-05-01'::date, 'Apollo Hyderabad', 'POX-A1001', 'Ravi Kumar', 'li_ion', 7, 95.8, 11.5, 128, false, true, false, 'healthy'),
('2026-05-01'::date, 'Yashoda Secunderabad', 'POX-A1002', 'Suresh Naik', 'li_ion', 21, 74.6, 7.7, 392, false, true, false, 'aging'),
('2026-05-01'::date, 'Care Banjara', 'POX-A1004', 'Pavan Reddy', 'li_ion', 35, 51.4, 4.2, 695, true, true, true, 'critical'),
('2026-05-01'::date, 'Sunshine Paradise', 'POX-A1007', 'Deepa K', 'li_ion', 41, 41.2, 2.8, 865, true, false, true, 'critical');

create or replace function founder_r3018_probe_overview()
returns table(audit_status text, total int, avg_spo2 numeric, drift_count int, replace_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.audit_status,
    count(*)::int,
    round(avg(p.spo2_accuracy_pct), 2),
    (count(*) filter (where p.drift_detected))::int,
    (count(*) filter (where p.replacement_recommended))::int
  from pulse_ox_probe_audits_r3018 p
  group by p.audit_status
  order by p.audit_status;
end $$;

create or replace function founder_r3018_battery_overview()
returns table(battery_status text, total int, avg_capacity numeric, avg_runtime numeric, replace_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.battery_status,
    count(*)::int,
    round(avg(b.capacity_pct), 2),
    round(avg(b.runtime_hours), 2),
    (count(*) filter (where b.replacement_recommended))::int
  from pulse_ox_battery_audits_r3018 b
  group by b.battery_status
  order by b.battery_status;
end $$;

create or replace function founder_r3018_hospital_probe_risk()
returns table(hospital_name text, probes_audited int, fail_count int, warn_count int, avg_accuracy numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.hospital_name,
    count(*)::int,
    (count(*) filter (where p.audit_status = 'fail'))::int,
    (count(*) filter (where p.audit_status = 'warn'))::int,
    round(avg(p.spo2_accuracy_pct), 2)
  from pulse_ox_probe_audits_r3018 p
  group by p.hospital_name
  order by (count(*) filter (where p.audit_status = 'fail'))::int desc, p.hospital_name;
end $$;

create or replace function founder_r3018_battery_critical_devices()
returns table(hospital_name text, device_serial text, battery_type text, battery_age_months int, capacity_pct numeric, swelling_detected boolean, battery_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_name, b.device_serial, b.battery_type, b.battery_age_months, b.capacity_pct, b.swelling_detected, b.battery_status
  from pulse_ox_battery_audits_r3018 b
  where b.battery_status in ('critical','warn')
  order by b.capacity_pct asc, b.hospital_name;
end $$;

create or replace function founder_r3018_engineer_throughput()
returns table(engineer_name text, probes_audited int, batteries_audited int, replace_recs int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with pr as (
    select p.engineer_name,
      count(*)::int as probes,
      (count(*) filter (where p.replacement_recommended))::int as pr_rep
    from pulse_ox_probe_audits_r3018 p group by p.engineer_name
  ), ba as (
    select b.engineer_name,
      count(*)::int as batts,
      (count(*) filter (where b.replacement_recommended))::int as ba_rep
    from pulse_ox_battery_audits_r3018 b group by b.engineer_name
  )
  select coalesce(pr.engineer_name, ba.engineer_name),
    coalesce(pr.probes, 0),
    coalesce(ba.batts, 0),
    coalesce(pr.pr_rep, 0) + coalesce(ba.ba_rep, 0)
  from pr full outer join ba on pr.engineer_name = ba.engineer_name
  order by 4 desc, 1;
end $$;

create or replace function founder_r3018_monthly_trend()
returns table(audit_month date, probes int, batteries int, probe_fails int, battery_criticals int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with pr as (
    select p.audit_month,
      count(*)::int as probes,
      (count(*) filter (where p.audit_status = 'fail'))::int as fails
    from pulse_ox_probe_audits_r3018 p group by p.audit_month
  ), ba as (
    select b.audit_month,
      count(*)::int as batts,
      (count(*) filter (where b.battery_status = 'critical'))::int as crits
    from pulse_ox_battery_audits_r3018 b group by b.audit_month
  )
  select coalesce(pr.audit_month, ba.audit_month),
    coalesce(pr.probes, 0),
    coalesce(ba.batts, 0),
    coalesce(pr.fails, 0),
    coalesce(ba.crits, 0)
  from pr full outer join ba on pr.audit_month = ba.audit_month
  order by 1 desc;
end $$;

create or replace function founder_r3018_probe_type_distribution()
returns table(probe_type text, total int, worn_or_worse int, avg_pulse_accuracy numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.probe_type,
    count(*)::int,
    (count(*) filter (where p.probe_condition in ('worn','damaged','replace_now')))::int,
    round(avg(p.pulse_rate_accuracy_pct), 2)
  from pulse_ox_probe_audits_r3018 p
  group by p.probe_type
  order by p.probe_type;
end $$;

create or replace function founder_r3018_replacement_priority_list()
returns table(hospital_name text, device_serial text, issue text, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.hospital_name, p.device_serial,
    ('probe ' || p.probe_condition || ' / cable ' || p.cable_integrity)::text,
    case when p.audit_status = 'fail' then 'high' else 'medium' end::text
  from pulse_ox_probe_audits_r3018 p
  where p.replacement_recommended
  union all
  select b.hospital_name, b.device_serial,
    ('battery ' || b.battery_status || ' / capacity ' || b.capacity_pct::text || '%')::text,
    case when b.battery_status = 'critical' then 'high' else 'medium' end::text
  from pulse_ox_battery_audits_r3018 b
  where b.replacement_recommended
  order by 4 desc, 1;
end $$;

revoke all on function founder_r3018_probe_overview() from public, anon;
revoke all on function founder_r3018_battery_overview() from public, anon;
revoke all on function founder_r3018_hospital_probe_risk() from public, anon;
revoke all on function founder_r3018_battery_critical_devices() from public, anon;
revoke all on function founder_r3018_engineer_throughput() from public, anon;
revoke all on function founder_r3018_monthly_trend() from public, anon;
revoke all on function founder_r3018_probe_type_distribution() from public, anon;
revoke all on function founder_r3018_replacement_priority_list() from public, anon;

grant execute on function founder_r3018_probe_overview() to authenticated;
grant execute on function founder_r3018_battery_overview() to authenticated;
grant execute on function founder_r3018_hospital_probe_risk() to authenticated;
grant execute on function founder_r3018_battery_critical_devices() to authenticated;
grant execute on function founder_r3018_engineer_throughput() to authenticated;
grant execute on function founder_r3018_monthly_trend() to authenticated;
grant execute on function founder_r3018_probe_type_distribution() to authenticated;
grant execute on function founder_r3018_replacement_priority_list() to authenticated;
