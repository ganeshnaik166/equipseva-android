-- Round r3042: Engineer Monthly Customer Site Bone-Saw Blade Wear & Sterilization Cycle Audit
-- 2 tables + 7 RPCs, all founder-gated

create table if not exists engineer_bonesaw_blade_wear_r3042 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  engineer_user_id uuid,
  engineer_name text not null,
  customer_site_name text not null,
  city text not null,
  hospital_tier text not null check (hospital_tier in ('tier_a','tier_b','tier_c','super_specialty')),
  blade_serial text not null,
  blade_model text not null check (blade_model in ('stryker_system7','dejuke_oscillating','medtronic_midas','aesculap_acculan','linvatec_hall')),
  cycles_used int not null check (cycles_used between 0 and 5000),
  rated_cycles int not null check (rated_cycles between 500 and 5000),
  wear_pct numeric(5,2) not null check (wear_pct between 0 and 100),
  teeth_chip_count int not null check (teeth_chip_count between 0 and 60),
  rpm_drift_pct numeric(5,2) not null check (rpm_drift_pct between -20 and 20),
  heat_signature_c numeric(5,2) not null check (heat_signature_c between 20 and 200),
  cut_quality_score int not null check (cut_quality_score between 1 and 10),
  blade_status text not null check (blade_status in ('green','yellow','amber','red','retired')),
  replacement_due boolean not null default false,
  audited_at timestamptz,
  notes text
);

create table if not exists engineer_sterilization_cycle_r3042 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  engineer_user_id uuid,
  engineer_name text not null,
  customer_site_name text not null,
  autoclave_serial text not null,
  cycle_method text not null check (cycle_method in ('steam_134c','steam_121c','ethylene_oxide','plasma_h2o2','flash_cycle')),
  cycles_run int not null check (cycles_run between 0 and 2000),
  failed_cycles int not null check (failed_cycles between 0 and 200),
  biological_indicator_pass boolean not null,
  chemical_indicator_pass boolean not null,
  bowie_dick_pass boolean not null,
  load_temp_c numeric(5,2) not null check (load_temp_c between 30 and 200),
  exposure_minutes numeric(5,2) not null check (exposure_minutes between 1 and 240),
  drying_minutes numeric(5,2) not null check (drying_minutes between 0 and 120),
  sterility_compliance_pct numeric(5,2) not null check (sterility_compliance_pct between 0 and 100),
  audit_outcome text not null check (audit_outcome in ('pass','minor_finding','major_finding','critical_fail','closed_loop')),
  nabh_aligned boolean not null default true,
  audited_at timestamptz,
  remediation text
);

alter table engineer_bonesaw_blade_wear_r3042 enable row level security;
alter table engineer_sterilization_cycle_r3042 enable row level security;

drop policy if exists bw_founder_r3042 on engineer_bonesaw_blade_wear_r3042;
create policy bw_founder_r3042 on engineer_bonesaw_blade_wear_r3042 for select to authenticated using (is_founder());

drop policy if exists st_founder_r3042 on engineer_sterilization_cycle_r3042;
create policy st_founder_r3042 on engineer_sterilization_cycle_r3042 for select to authenticated using (is_founder());

-- Seed blade wear (18 rows)
insert into engineer_bonesaw_blade_wear_r3042 (audit_month, engineer_name, customer_site_name, city, hospital_tier, blade_serial, blade_model, cycles_used, rated_cycles, wear_pct, teeth_chip_count, rpm_drift_pct, heat_signature_c, cut_quality_score, blade_status, replacement_due, audited_at, notes) values
('2026-06-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'Hyderabad', 'super_specialty', 'BS-A0001', 'stryker_system7', 412, 1500, 27.46, 2, 1.20, 48.50, 9, 'green', false, '2026-06-03'::timestamptz, 'clean'),
('2026-06-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'Hyderabad', 'super_specialty', 'BS-A0002', 'medtronic_midas', 1190, 1500, 79.33, 8, 4.10, 72.40, 6, 'amber', true, '2026-06-03'::timestamptz, 'replace before 2 weeks'),
('2026-06-01'::date, 'Suresh Patel', 'KIMS Secunderabad', 'Hyderabad', 'tier_a', 'BS-B0010', 'aesculap_acculan', 880, 1200, 73.33, 5, 2.80, 65.20, 7, 'yellow', false, null::timestamptz, null),
('2026-06-01'::date, 'Suresh Patel', 'KIMS Secunderabad', 'Hyderabad', 'tier_a', 'BS-B0011', 'dejuke_oscillating', 1450, 1500, 96.66, 18, 8.40, 110.50, 3, 'red', true, null::timestamptz, 'mandatory swap'),
('2026-06-01'::date, 'Anita Sharma', 'Manipal Whitefield', 'Bengaluru', 'super_specialty', 'BS-C0020', 'stryker_system7', 320, 1500, 21.33, 1, 0.80, 42.10, 10, 'green', false, null::timestamptz, 'pristine'),
('2026-06-01'::date, 'Anita Sharma', 'Manipal Whitefield', 'Bengaluru', 'super_specialty', 'BS-C0021', 'linvatec_hall', 990, 1200, 82.50, 11, 6.10, 88.30, 5, 'amber', true, null::timestamptz, null),
('2026-06-01'::date, 'Manoj Reddy', 'Fortis Mulund', 'Mumbai', 'tier_a', 'BS-D0030', 'medtronic_midas', 1500, 1500, 100.00, 24, 12.30, 145.60, 1, 'retired', true, null::timestamptz, 'pulled from circulation'),
('2026-06-01'::date, 'Manoj Reddy', 'Fortis Mulund', 'Mumbai', 'tier_a', 'BS-D0031', 'aesculap_acculan', 540, 1200, 45.00, 3, 1.90, 55.40, 8, 'green', false, null::timestamptz, null),
('2026-06-01'::date, 'Deepa Nair', 'AIIMS Delhi', 'Delhi', 'super_specialty', 'BS-E0040', 'stryker_system7', 760, 1500, 50.66, 4, 2.20, 58.80, 8, 'yellow', false, null::timestamptz, 'monitor'),
('2026-06-01'::date, 'Deepa Nair', 'AIIMS Delhi', 'Delhi', 'super_specialty', 'BS-E0041', 'dejuke_oscillating', 1100, 1500, 73.33, 9, 5.50, 78.90, 6, 'amber', false, null::timestamptz, null),
('2026-05-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'Hyderabad', 'super_specialty', 'BS-A0003', 'medtronic_midas', 650, 1500, 43.33, 3, 2.00, 52.30, 9, 'green', false, null::timestamptz, 'last month baseline'),
('2026-05-01'::date, 'Suresh Patel', 'KIMS Secunderabad', 'Hyderabad', 'tier_a', 'BS-B0012', 'linvatec_hall', 1180, 1200, 98.33, 15, 9.10, 120.40, 2, 'red', true, null::timestamptz, 'replaced 06-02'),
('2026-06-01'::date, 'Kavya Iyer', 'Yashoda Somajiguda', 'Hyderabad', 'tier_b', 'BS-F0050', 'stryker_system7', 230, 1500, 15.33, 0, 0.40, 38.20, 10, 'green', false, null::timestamptz, 'new blade'),
('2026-06-01'::date, 'Kavya Iyer', 'Yashoda Somajiguda', 'Hyderabad', 'tier_b', 'BS-F0051', 'aesculap_acculan', 870, 1200, 72.50, 6, 3.10, 68.50, 7, 'yellow', false, null::timestamptz, null),
('2026-06-01'::date, 'Pradeep Joshi', 'Narayana Bommasandra', 'Bengaluru', 'tier_a', 'BS-G0060', 'dejuke_oscillating', 1320, 1500, 88.00, 13, 7.20, 95.40, 4, 'amber', true, null::timestamptz, 'schedule swap'),
('2026-06-01'::date, 'Pradeep Joshi', 'Narayana Bommasandra', 'Bengaluru', 'tier_a', 'BS-G0061', 'medtronic_midas', 480, 1500, 32.00, 2, 1.50, 47.80, 9, 'green', false, null::timestamptz, null),
('2026-06-01'::date, 'Sneha Bose', 'Medanta Gurugram', 'Gurugram', 'super_specialty', 'BS-H0070', 'linvatec_hall', 1050, 1200, 87.50, 10, 5.80, 84.20, 5, 'amber', true, null::timestamptz, null),
('2026-06-01'::date, 'Sneha Bose', 'Medanta Gurugram', 'Gurugram', 'super_specialty', 'BS-H0071', 'stryker_system7', 600, 1500, 40.00, 2, 1.70, 50.10, 9, 'green', false, null::timestamptz, 'OK');

-- Seed sterilization (16 rows)
insert into engineer_sterilization_cycle_r3042 (audit_month, engineer_name, customer_site_name, autoclave_serial, cycle_method, cycles_run, failed_cycles, biological_indicator_pass, chemical_indicator_pass, bowie_dick_pass, load_temp_c, exposure_minutes, drying_minutes, sterility_compliance_pct, audit_outcome, nabh_aligned, audited_at, remediation) values
('2026-06-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'AC-A001', 'steam_134c', 480, 2, true, true, true, 134.00, 4.00, 25.00, 99.58, 'pass', true, '2026-06-04'::timestamptz, null),
('2026-06-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'AC-A002', 'steam_121c', 320, 5, true, true, true, 121.00, 15.00, 30.00, 98.43, 'minor_finding', true, '2026-06-04'::timestamptz, 'tighten gasket'),
('2026-06-01'::date, 'Suresh Patel', 'KIMS Secunderabad', 'AC-B010', 'plasma_h2o2', 210, 8, false, true, true, 55.00, 28.00, 0.00, 96.19, 'major_finding', false, '2026-06-05'::timestamptz, 'BI failed — repeat batch'),
('2026-06-01'::date, 'Suresh Patel', 'KIMS Secunderabad', 'AC-B011', 'steam_134c', 410, 1, true, true, true, 134.00, 4.00, 22.00, 99.75, 'pass', true, '2026-06-05'::timestamptz, null),
('2026-06-01'::date, 'Anita Sharma', 'Manipal Whitefield', 'AC-C020', 'ethylene_oxide', 95, 0, true, true, true, 60.00, 180.00, 60.00, 100.00, 'pass', true, '2026-06-06'::timestamptz, null),
('2026-06-01'::date, 'Anita Sharma', 'Manipal Whitefield', 'AC-C021', 'flash_cycle', 540, 18, true, false, true, 132.00, 3.00, 5.00, 96.66, 'major_finding', true, '2026-06-06'::timestamptz, 'CI fail — reseal'),
('2026-06-01'::date, 'Manoj Reddy', 'Fortis Mulund', 'AC-D030', 'steam_134c', 510, 14, false, false, false, 128.00, 4.00, 18.00, 97.25, 'critical_fail', false, '2026-06-07'::timestamptz, 'autoclave taken offline'),
('2026-06-01'::date, 'Manoj Reddy', 'Fortis Mulund', 'AC-D031', 'steam_121c', 280, 0, true, true, true, 121.00, 15.00, 30.00, 100.00, 'pass', true, '2026-06-07'::timestamptz, null),
('2026-06-01'::date, 'Deepa Nair', 'AIIMS Delhi', 'AC-E040', 'plasma_h2o2', 340, 3, true, true, true, 56.00, 28.00, 0.00, 99.11, 'pass', true, '2026-06-08'::timestamptz, null),
('2026-06-01'::date, 'Deepa Nair', 'AIIMS Delhi', 'AC-E041', 'ethylene_oxide', 80, 6, false, true, true, 60.00, 180.00, 55.00, 92.50, 'major_finding', false, '2026-06-08'::timestamptz, 'aeration time low'),
('2026-05-01'::date, 'Ravi Kumar', 'Apollo Jubilee Hills', 'AC-A001', 'steam_134c', 460, 1, true, true, true, 134.00, 4.00, 25.00, 99.78, 'pass', true, '2026-05-04'::timestamptz, null),
('2026-06-01'::date, 'Kavya Iyer', 'Yashoda Somajiguda', 'AC-F050', 'steam_134c', 290, 7, true, true, false, 133.00, 4.00, 20.00, 97.58, 'minor_finding', true, '2026-06-09'::timestamptz, 'BD test fail — vacuum service'),
('2026-06-01'::date, 'Kavya Iyer', 'Yashoda Somajiguda', 'AC-F051', 'flash_cycle', 610, 22, true, false, true, 132.00, 3.00, 4.00, 96.39, 'major_finding', true, '2026-06-09'::timestamptz, 'reduce flash usage'),
('2026-06-01'::date, 'Pradeep Joshi', 'Narayana Bommasandra', 'AC-G060', 'steam_121c', 240, 0, true, true, true, 121.00, 15.00, 30.00, 100.00, 'closed_loop', true, '2026-06-10'::timestamptz, null),
('2026-06-01'::date, 'Pradeep Joshi', 'Narayana Bommasandra', 'AC-G061', 'plasma_h2o2', 180, 2, true, true, true, 55.00, 28.00, 0.00, 98.88, 'pass', true, '2026-06-10'::timestamptz, null),
('2026-06-01'::date, 'Sneha Bose', 'Medanta Gurugram', 'AC-H070', 'steam_134c', 470, 4, true, true, true, 134.00, 4.00, 22.00, 99.14, 'pass', true, '2026-06-11'::timestamptz, null);

-- RPCs
create or replace function r3042_blade_status_distribution()
returns table(blade_status text, blade_count int, retired_count int, avg_wear numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.blade_status,
           count(*)::int as blade_count,
           (count(*) filter (where b.blade_status = 'retired'))::int as retired_count,
           round(avg(b.wear_pct), 2) as avg_wear
    from engineer_bonesaw_blade_wear_r3042 b
    group by b.blade_status
    order by blade_count desc;
end; $$;

create or replace function r3042_engineer_blade_scorecard()
returns table(engineer_name text, blades_audited int, red_blades int, amber_blades int, avg_quality numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.engineer_name,
           count(*)::int as blades_audited,
           (count(*) filter (where b.blade_status = 'red'))::int as red_blades,
           (count(*) filter (where b.blade_status = 'amber'))::int as amber_blades,
           round(avg(b.cut_quality_score), 2) as avg_quality
    from engineer_bonesaw_blade_wear_r3042 b
    group by b.engineer_name
    order by red_blades desc, amber_blades desc;
end; $$;

create or replace function r3042_blade_model_wear_summary()
returns table(blade_model text, units int, avg_wear numeric, avg_chips numeric, replacements_due int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.blade_model,
           count(*)::int as units,
           round(avg(b.wear_pct), 2) as avg_wear,
           round(avg(b.teeth_chip_count), 2) as avg_chips,
           (count(*) filter (where b.replacement_due))::int as replacements_due
    from engineer_bonesaw_blade_wear_r3042 b
    group by b.blade_model
    order by avg_wear desc;
end; $$;

create or replace function r3042_site_replacement_queue()
returns table(customer_site_name text, city text, blades_due int, avg_wear numeric, worst_quality int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select b.customer_site_name, b.city,
           (count(*) filter (where b.replacement_due))::int as blades_due,
           round(avg(b.wear_pct), 2) as avg_wear,
           min(b.cut_quality_score)::int as worst_quality
    from engineer_bonesaw_blade_wear_r3042 b
    group by b.customer_site_name, b.city
    order by blades_due desc, avg_wear desc;
end; $$;

create or replace function r3042_sterilization_outcome_distribution()
returns table(audit_outcome text, audits int, total_failed_cycles int, avg_compliance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.audit_outcome,
           count(*)::int as audits,
           sum(s.failed_cycles)::int as total_failed_cycles,
           round(avg(s.sterility_compliance_pct), 2) as avg_compliance
    from engineer_sterilization_cycle_r3042 s
    group by s.audit_outcome
    order by audits desc;
end; $$;

create or replace function r3042_cycle_method_health()
returns table(cycle_method text, runs int, failures int, bi_pass_rate numeric, avg_compliance numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.cycle_method,
           sum(s.cycles_run)::int as runs,
           sum(s.failed_cycles)::int as failures,
           round((count(*) filter (where s.biological_indicator_pass))::numeric * 100.0 / nullif(count(*),0), 2) as bi_pass_rate,
           round(avg(s.sterility_compliance_pct), 2) as avg_compliance
    from engineer_sterilization_cycle_r3042 s
    group by s.cycle_method
    order by failures desc;
end; $$;

create or replace function r3042_critical_findings_feed()
returns table(audited_at timestamptz, engineer_name text, customer_site_name text, autoclave_serial text, audit_outcome text, sterility_compliance_pct numeric, remediation text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.audited_at, s.engineer_name, s.customer_site_name, s.autoclave_serial, s.audit_outcome, s.sterility_compliance_pct, s.remediation
    from engineer_sterilization_cycle_r3042 s
    where s.audit_outcome in ('major_finding','critical_fail')
    order by s.audited_at desc;
end; $$;

revoke all on function r3042_blade_status_distribution() from public, anon;
revoke all on function r3042_engineer_blade_scorecard() from public, anon;
revoke all on function r3042_blade_model_wear_summary() from public, anon;
revoke all on function r3042_site_replacement_queue() from public, anon;
revoke all on function r3042_sterilization_outcome_distribution() from public, anon;
revoke all on function r3042_cycle_method_health() from public, anon;
revoke all on function r3042_critical_findings_feed() from public, anon;

grant execute on function r3042_blade_status_distribution() to authenticated;
grant execute on function r3042_engineer_blade_scorecard() to authenticated;
grant execute on function r3042_blade_model_wear_summary() to authenticated;
grant execute on function r3042_site_replacement_queue() to authenticated;
grant execute on function r3042_sterilization_outcome_distribution() to authenticated;
grant execute on function r3042_cycle_method_health() to authenticated;
grant execute on function r3042_critical_findings_feed() to authenticated;
