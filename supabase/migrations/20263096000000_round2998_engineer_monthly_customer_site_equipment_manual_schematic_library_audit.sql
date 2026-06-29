-- Round 2998: Engineer Monthly Customer Site Equipment Manual & Schematic Library Audit

create table if not exists engineer_manual_library_audits_r2998 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  engineer_name text not null,
  customer_site text not null,
  city text not null,
  equipment_category text not null check (equipment_category in ('imaging','life_support','diagnostic','surgical','lab','sterilization','dental','ophthalmic')),
  equipment_count int not null check (equipment_count >= 0),
  manuals_present int not null check (manuals_present >= 0),
  schematics_present int not null check (schematics_present >= 0),
  manuals_missing int not null check (manuals_missing >= 0),
  schematics_missing int not null check (schematics_missing >= 0),
  coverage_pct numeric(5,2) not null,
  audit_status text not null check (audit_status in ('clean','minor_gap','major_gap','critical_gap')),
  remediation_owner text not null,
  audit_minutes int not null check (audit_minutes > 0),
  created_at timestamptz not null default now()
);

create table if not exists engineer_manual_library_gaps_r2998 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references engineer_manual_library_audits_r2998(id) on delete cascade,
  equipment_model text not null,
  serial_no text not null,
  gap_type text not null check (gap_type in ('manual_missing','schematic_missing','outdated_revision','language_mismatch','damaged_copy','vendor_unreachable')),
  severity text not null check (severity in ('low','medium','high','critical')),
  oem_name text not null,
  request_status text not null check (request_status in ('pending','requested','received','escalated','closed')),
  age_days int not null check (age_days >= 0),
  resolution_eta date,
  created_at timestamptz not null default now()
);

alter table engineer_manual_library_audits_r2998 enable row level security;
alter table engineer_manual_library_gaps_r2998 enable row level security;

drop policy if exists r2998_audits_founder_all on engineer_manual_library_audits_r2998;
create policy r2998_audits_founder_all on engineer_manual_library_audits_r2998 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists r2998_gaps_founder_all on engineer_manual_library_gaps_r2998;
create policy r2998_gaps_founder_all on engineer_manual_library_gaps_r2998 for all to authenticated using (is_founder()) with check (is_founder());

insert into engineer_manual_library_audits_r2998 (audit_month, engineer_name, customer_site, city, equipment_category, equipment_count, manuals_present, schematics_present, manuals_missing, schematics_missing, coverage_pct, audit_status, remediation_owner, audit_minutes) values
('2026-06-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'Hyderabad', 'imaging', 24, 22, 20, 2, 4, 87.50, 'minor_gap', 'oem_liaison', 95),
('2026-06-01'::date, 'Priya Sharma', 'Fortis Bannerghatta', 'Bangalore', 'life_support', 18, 14, 11, 4, 7, 69.44, 'major_gap', 'engineer_self', 110),
('2026-06-01'::date, 'Arjun Mehta', 'Manipal Whitefield', 'Bangalore', 'diagnostic', 32, 30, 28, 2, 4, 90.62, 'minor_gap', 'oem_liaison', 130),
('2026-06-01'::date, 'Sneha Iyer', 'KIMS Secunderabad', 'Hyderabad', 'surgical', 15, 9, 7, 6, 8, 53.33, 'critical_gap', 'founder_escalation', 75),
('2026-06-01'::date, 'Vikram Reddy', 'Yashoda Somajiguda', 'Hyderabad', 'lab', 28, 26, 24, 2, 4, 89.29, 'minor_gap', 'oem_liaison', 105),
('2026-06-01'::date, 'Anjali Patel', 'Care Banjara', 'Hyderabad', 'sterilization', 12, 12, 11, 0, 1, 95.83, 'clean', 'engineer_self', 55),
('2026-06-01'::date, 'Rohan Singh', 'Continental Gachibowli', 'Hyderabad', 'imaging', 20, 16, 14, 4, 6, 75.00, 'major_gap', 'oem_liaison', 90),
('2026-06-01'::date, 'Meera Joshi', 'AIG Gachibowli', 'Hyderabad', 'diagnostic', 26, 25, 23, 1, 3, 92.31, 'clean', 'engineer_self', 100),
('2026-06-01'::date, 'Karthik Nair', 'Rainbow Hospital', 'Hyderabad', 'life_support', 14, 13, 12, 1, 2, 89.29, 'minor_gap', 'oem_liaison', 70),
('2026-06-01'::date, 'Divya Rao', 'Sunshine Hospital', 'Hyderabad', 'dental', 8, 8, 7, 0, 1, 93.75, 'clean', 'engineer_self', 40),
('2026-06-01'::date, 'Aditya Verma', 'Asian Institute', 'Hyderabad', 'ophthalmic', 10, 6, 4, 4, 6, 50.00, 'critical_gap', 'founder_escalation', 60),
('2026-06-01'::date, 'Lakshmi Pillai', 'Maxcure Madhapur', 'Hyderabad', 'lab', 22, 21, 19, 1, 3, 90.91, 'clean', 'engineer_self', 85),
('2026-06-01'::date, 'Suresh Babu', 'Star Hospital', 'Hyderabad', 'surgical', 16, 12, 10, 4, 6, 68.75, 'major_gap', 'oem_liaison', 80),
('2026-06-01'::date, 'Nisha Agarwal', 'Olive Hospital', 'Hyderabad', 'sterilization', 6, 6, 6, 0, 0, 100.00, 'clean', 'engineer_self', 30),
('2026-06-01'::date, 'Manoj Tiwari', 'Virinchi Hospital', 'Hyderabad', 'imaging', 18, 15, 12, 3, 6, 75.00, 'major_gap', 'oem_liaison', 88),
('2026-06-01'::date, 'Pooja Bhatt', 'Renova Soujanya', 'Hyderabad', 'diagnostic', 14, 14, 13, 0, 1, 96.43, 'clean', 'engineer_self', 65),
('2026-06-01'::date, 'Rahul Desai', 'Care Outpatient', 'Hyderabad', 'dental', 7, 5, 4, 2, 3, 64.29, 'major_gap', 'engineer_self', 35),
('2026-06-01'::date, 'Kavya Menon', 'Citizens Hospital', 'Hyderabad', 'life_support', 20, 18, 17, 2, 3, 87.50, 'minor_gap', 'oem_liaison', 92);

insert into engineer_manual_library_gaps_r2998 (audit_id, equipment_model, serial_no, gap_type, severity, oem_name, request_status, age_days, resolution_eta) values
((select id from engineer_manual_library_audits_r2998 where engineer_name='Sneha Iyer'), 'Datex Aestiva 5', 'DX-A5-22118', 'schematic_missing', 'critical', 'GE Healthcare', 'escalated', 42, '2026-07-15'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Sneha Iyer'), 'Maquet Servo-i', 'MQ-SI-30811', 'manual_missing', 'critical', 'Getinge', 'requested', 28, '2026-07-10'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Priya Sharma'), 'Drager Evita V500', 'DR-EV-44521', 'schematic_missing', 'high', 'Drager', 'requested', 18, '2026-06-30'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Priya Sharma'), 'Philips IntelliVue MX800', 'PH-MX-7812', 'outdated_revision', 'medium', 'Philips', 'received', 5, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Aditya Verma'), 'Zeiss Visucam 524', 'ZS-VC-11203', 'manual_missing', 'high', 'Zeiss', 'escalated', 51, '2026-07-20'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Aditya Verma'), 'Topcon TRC-50DX', 'TC-50-9087', 'schematic_missing', 'critical', 'Topcon', 'pending', 67, '2026-07-25'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Suresh Babu'), 'Stryker SDC Ultra', 'SK-SDC-3322', 'language_mismatch', 'medium', 'Stryker', 'requested', 12, '2026-06-28'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Manoj Tiwari'), 'Siemens Mobilett Mira', 'SM-MM-66401', 'damaged_copy', 'medium', 'Siemens', 'received', 8, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Rohan Singh'), 'GE Optima CT660', 'GE-OC-88912', 'schematic_missing', 'high', 'GE Healthcare', 'requested', 22, '2026-07-05'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Rahul Desai'), 'KaVo Estetica E70', 'KV-E70-2201', 'manual_missing', 'medium', 'KaVo', 'pending', 33, '2026-07-12'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Ravi Kumar'), 'Siemens Mammomat', 'SM-MMG-7711', 'outdated_revision', 'low', 'Siemens', 'closed', 3, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Karthik Nair'), 'Fisher Paykel MR850', 'FP-MR-55234', 'manual_missing', 'low', 'Fisher Paykel', 'received', 6, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Arjun Mehta'), 'Roche Cobas 6000', 'RC-C6-99812', 'schematic_missing', 'medium', 'Roche', 'requested', 14, '2026-07-02'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Vikram Reddy'), 'Sysmex XN-1000', 'SX-XN-44102', 'language_mismatch', 'low', 'Sysmex', 'closed', 4, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Kavya Menon'), 'Hamilton C6', 'HM-C6-23311', 'vendor_unreachable', 'high', 'Hamilton Medical', 'escalated', 38, '2026-07-18'::date),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Lakshmi Pillai'), 'Beckman DXH 800', 'BK-DX-77821', 'outdated_revision', 'low', 'Beckman Coulter', 'received', 7, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Meera Joshi'), 'Siemens Atellica', 'SM-AT-12378', 'manual_missing', 'low', 'Siemens Healthineers', 'closed', 2, null),
((select id from engineer_manual_library_audits_r2998 where engineer_name='Anjali Patel'), 'Steris Amsco V-PRO', 'ST-VP-88012', 'schematic_missing', 'low', 'Steris', 'closed', 5, null);

create or replace function r2998_audit_overview()
returns table(total_audits int, clean_audits int, minor_gap int, major_gap int, critical_gap int, avg_coverage numeric, total_equipment int, total_manuals_missing int, total_schematics_missing int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where audit_status='clean'))::int,
    (count(*) filter (where audit_status='minor_gap'))::int,
    (count(*) filter (where audit_status='major_gap'))::int,
    (count(*) filter (where audit_status='critical_gap'))::int,
    round(avg(coverage_pct),2),
    sum(equipment_count)::int,
    sum(manuals_missing)::int,
    sum(schematics_missing)::int
  from engineer_manual_library_audits_r2998;
end; $$;

create or replace function r2998_audits_by_category()
returns table(equipment_category text, audit_count int, avg_coverage numeric, total_missing int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.equipment_category, count(*)::int, round(avg(a.coverage_pct),2), sum(a.manuals_missing + a.schematics_missing)::int
  from engineer_manual_library_audits_r2998 a
  group by a.equipment_category
  order by avg(a.coverage_pct) asc;
end; $$;

create or replace function r2998_engineer_leaderboard()
returns table(engineer_name text, sites_audited int, avg_coverage numeric, total_minutes int, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.engineer_name, count(*)::int, round(avg(a.coverage_pct),2), sum(a.audit_minutes)::int,
    (count(*) filter (where a.audit_status='critical_gap'))::int
  from engineer_manual_library_audits_r2998 a
  group by a.engineer_name
  order by avg(a.coverage_pct) desc;
end; $$;

create or replace function r2998_critical_sites()
returns table(customer_site text, city text, engineer_name text, equipment_category text, coverage_pct numeric, manuals_missing int, schematics_missing int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.customer_site, a.city, a.engineer_name, a.equipment_category, a.coverage_pct, a.manuals_missing, a.schematics_missing
  from engineer_manual_library_audits_r2998 a
  where a.audit_status in ('major_gap','critical_gap')
  order by a.coverage_pct asc;
end; $$;

create or replace function r2998_gaps_by_type()
returns table(gap_type text, severity text, gap_count int, avg_age numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select g.gap_type, g.severity, count(*)::int, round(avg(g.age_days),1)
  from engineer_manual_library_gaps_r2998 g
  group by g.gap_type, g.severity
  order by count(*) desc;
end; $$;

create or replace function r2998_oem_response()
returns table(oem_name text, total_gaps int, received_count int, escalated_count int, pending_count int, response_rate numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select g.oem_name,
    count(*)::int,
    (count(*) filter (where g.request_status in ('received','closed')))::int,
    (count(*) filter (where g.request_status='escalated'))::int,
    (count(*) filter (where g.request_status='pending'))::int,
    round((count(*) filter (where g.request_status in ('received','closed'))) * 100.0 / nullif(count(*),0), 2)
  from engineer_manual_library_gaps_r2998 g
  group by g.oem_name
  order by count(*) desc;
end; $$;

create or replace function r2998_city_summary()
returns table(city text, sites int, avg_coverage numeric, total_equipment int, critical_gaps int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.city, count(*)::int, round(avg(a.coverage_pct),2), sum(a.equipment_count)::int,
    (count(*) filter (where a.audit_status='critical_gap'))::int
  from engineer_manual_library_audits_r2998 a
  group by a.city
  order by count(*) desc;
end; $$;

create or replace function r2998_stale_gaps()
returns table(equipment_model text, oem_name text, gap_type text, severity text, age_days int, request_status text, resolution_eta date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select g.equipment_model, g.oem_name, g.gap_type, g.severity, g.age_days, g.request_status, g.resolution_eta
  from engineer_manual_library_gaps_r2998 g
  where g.age_days > 14 and g.request_status not in ('received','closed')
  order by g.age_days desc;
end; $$;

revoke all on function r2998_audit_overview() from public, anon;
revoke all on function r2998_audits_by_category() from public, anon;
revoke all on function r2998_engineer_leaderboard() from public, anon;
revoke all on function r2998_critical_sites() from public, anon;
revoke all on function r2998_gaps_by_type() from public, anon;
revoke all on function r2998_oem_response() from public, anon;
revoke all on function r2998_city_summary() from public, anon;
revoke all on function r2998_stale_gaps() from public, anon;

grant execute on function r2998_audit_overview() to authenticated;
grant execute on function r2998_audits_by_category() to authenticated;
grant execute on function r2998_engineer_leaderboard() to authenticated;
grant execute on function r2998_critical_sites() to authenticated;
grant execute on function r2998_gaps_by_type() to authenticated;
grant execute on function r2998_oem_response() to authenticated;
grant execute on function r2998_city_summary() to authenticated;
grant execute on function r2998_stale_gaps() to authenticated;