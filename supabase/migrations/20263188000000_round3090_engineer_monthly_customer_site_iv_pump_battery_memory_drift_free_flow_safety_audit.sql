-- Round 3090: Engineer Monthly Customer Site IV-Pump Battery-Memory Drift & Free-Flow Safety Audit
-- HEAVY star x4

create table if not exists iv_pump_battery_memory_drift_r3090 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  engineer_id uuid references engineers(id) on delete set null,
  hospital_org_id uuid,
  pump_asset_tag text not null,
  pump_manufacturer text not null,
  pump_model text not null,
  battery_serial text not null,
  battery_install_date date,
  battery_cycle_count int not null,
  rated_runtime_minutes int not null,
  measured_runtime_minutes int not null,
  drift_percent numeric(6,2) not null,
  memory_retention_pass boolean not null,
  memory_drift_seconds int not null,
  occlusion_alarm_pass boolean not null,
  drift_severity text not null check (drift_severity in ('within_spec','minor','major','critical')),
  action_taken text not null check (action_taken in ('none','recalibrate','battery_swap','escalate','quarantine')),
  remediation_notes text,
  next_due_on date,
  ward_location text,
  audited_at timestamptz
);

alter table iv_pump_battery_memory_drift_r3090 enable row level security;
drop policy if exists ivpbmd_r3090_founder_all on iv_pump_battery_memory_drift_r3090;
create policy ivpbmd_r3090_founder_all on iv_pump_battery_memory_drift_r3090 for all to authenticated using (is_founder()) with check (is_founder());

create table if not exists iv_pump_free_flow_safety_audit_r3090 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_month date not null,
  engineer_id uuid references engineers(id) on delete set null,
  hospital_org_id uuid,
  pump_asset_tag text not null,
  set_brand text not null,
  anti_free_flow_clamp_present boolean not null,
  clamp_engagement_force_n numeric(6,2),
  free_flow_ml_per_min numeric(6,2) not null,
  door_interlock_pass boolean not null,
  alarm_db_level numeric(5,2),
  bolus_accuracy_percent numeric(6,2),
  occlusion_pressure_psi numeric(6,2),
  safety_grade text not null check (safety_grade in ('A','B','C','D','F')),
  failure_mode text check (failure_mode in ('none','clamp_worn','door_sensor','set_misload','tubing_creep','controller_bug')),
  corrective_action text not null check (corrective_action in ('pass','adjust','replace_set','replace_clamp','remove_from_service')),
  patient_risk_flag boolean not null,
  audited_at timestamptz,
  signed_off_by uuid references profiles(id) on delete set null
);

alter table iv_pump_free_flow_safety_audit_r3090 enable row level security;
drop policy if exists ivpffsa_r3090_founder_all on iv_pump_free_flow_safety_audit_r3090;
create policy ivpffsa_r3090_founder_all on iv_pump_free_flow_safety_audit_r3090 for all to authenticated using (is_founder()) with check (is_founder());

-- Seed iv_pump_battery_memory_drift_r3090 (15 rows)
insert into iv_pump_battery_memory_drift_r3090 (audit_month, pump_asset_tag, pump_manufacturer, pump_model, battery_serial, battery_install_date, battery_cycle_count, rated_runtime_minutes, measured_runtime_minutes, drift_percent, memory_retention_pass, memory_drift_seconds, occlusion_alarm_pass, drift_severity, action_taken, remediation_notes, next_due_on, ward_location, audited_at) values
('2026-06-01'::date, 'IVP-AP-001', 'BBraun', 'Infusomat Space', 'BAT-AP-001', '2024-03-15'::date, 412, 360, 348, 3.33, true, 2, true, 'within_spec', 'none', null, '2026-07-01'::date, 'ICU-1', '2026-06-05'::timestamptz),
('2026-06-01'::date, 'IVP-AP-002', 'Fresenius', 'Agilia VP', 'BAT-AP-002', '2023-11-20'::date, 689, 480, 412, 14.17, true, 5, true, 'minor', 'recalibrate', 'Battery aging, schedule swap Q3', '2026-07-01'::date, 'ICU-2', '2026-06-05'::timestamptz),
('2026-06-01'::date, 'IVP-AP-003', 'BPL', 'Accusure IV', 'BAT-AP-003', '2025-01-10'::date, 178, 360, 358, 0.56, true, 1, true, 'within_spec', 'none', null, '2026-07-01'::date, 'PED-1', '2026-06-06'::timestamptz),
('2026-06-01'::date, 'IVP-AP-004', 'BBraun', 'Perfusor Space', 'BAT-AP-004', '2022-08-05'::date, 1102, 480, 298, 37.92, false, 47, true, 'critical', 'battery_swap', 'Memory loss on power cycle - quarantined', '2026-07-15'::date, 'OT-1', '2026-06-07'::timestamptz),
('2026-06-01'::date, 'IVP-AP-005', 'Fresenius', 'Agilia SP', 'BAT-AP-005', '2024-06-22'::date, 298, 360, 340, 5.56, true, 3, true, 'within_spec', 'none', null, '2026-07-01'::date, 'NICU', '2026-06-07'::timestamptz),
('2026-06-01'::date, 'IVP-AP-006', 'Smiths', 'Medfusion 4000', 'BAT-AP-006', '2023-04-18'::date, 845, 600, 502, 16.33, true, 8, false, 'major', 'escalate', 'Occlusion alarm failed - vendor RMA', '2026-07-08'::date, 'ICU-3', '2026-06-08'::timestamptz),
('2026-06-01'::date, 'IVP-AP-007', 'BBraun', 'Infusomat Space', 'BAT-AP-007', '2025-02-14'::date, 142, 360, 359, 0.28, true, 0, true, 'within_spec', 'none', null, '2026-07-01'::date, 'ICU-1', '2026-06-08'::timestamptz),
('2026-06-01'::date, 'IVP-AP-008', 'BPL', 'Accusure IV', 'BAT-AP-008', '2023-09-30'::date, 612, 360, 312, 13.33, false, 21, true, 'minor', 'recalibrate', 'Memory retention marginal', '2026-07-01'::date, 'PED-2', '2026-06-09'::timestamptz),
('2026-06-01'::date, 'IVP-AP-009', 'Fresenius', 'Agilia VP', 'BAT-AP-009', '2024-11-12'::date, 234, 480, 471, 1.88, true, 1, true, 'within_spec', 'none', null, '2026-07-01'::date, 'ICU-2', '2026-06-09'::timestamptz),
('2026-06-01'::date, 'IVP-AP-010', 'BBraun', 'Perfusor Space', 'BAT-AP-010', '2022-12-01'::date, 956, 480, 358, 25.42, false, 89, true, 'major', 'quarantine', 'Battery + memory both failing', '2026-07-15'::date, 'OT-2', '2026-06-10'::timestamptz),
('2026-06-01'::date, 'IVP-AP-011', 'Smiths', 'Medfusion 4000', 'BAT-AP-011', '2025-03-08'::date, 88, 600, 596, 0.67, true, 0, true, 'within_spec', 'none', null, '2026-07-01'::date, 'ICU-3', '2026-06-10'::timestamptz),
('2026-06-01'::date, 'IVP-AP-012', 'BPL', 'Accusure IV', 'BAT-AP-012', '2024-07-19'::date, 312, 360, 339, 5.83, true, 4, true, 'within_spec', 'none', null, '2026-07-01'::date, 'NICU', '2026-06-11'::timestamptz),
('2026-06-01'::date, 'IVP-AP-013', 'BBraun', 'Infusomat Space', 'BAT-AP-013', '2023-02-25'::date, 1234, 360, 201, 44.17, false, 156, false, 'critical', 'quarantine', 'Total failure - removed from service', '2026-08-01'::date, 'ER', '2026-06-11'::timestamptz),
('2026-06-01'::date, 'IVP-AP-014', 'Fresenius', 'Agilia SP', 'BAT-AP-014', '2024-09-04'::date, 267, 360, 345, 4.17, true, 2, true, 'within_spec', 'none', null, '2026-07-01'::date, 'ICU-1', '2026-06-12'::timestamptz),
('2026-06-01'::date, 'IVP-AP-015', 'BBraun', 'Perfusor Space', 'BAT-AP-015', '2023-06-17'::date, 778, 480, 401, 16.46, true, 6, true, 'major', 'battery_swap', 'Scheduled battery replacement', '2026-07-08'::date, 'OT-1', '2026-06-12'::timestamptz);

-- Seed iv_pump_free_flow_safety_audit_r3090 (15 rows)
insert into iv_pump_free_flow_safety_audit_r3090 (audit_month, pump_asset_tag, set_brand, anti_free_flow_clamp_present, clamp_engagement_force_n, free_flow_ml_per_min, door_interlock_pass, alarm_db_level, bolus_accuracy_percent, occlusion_pressure_psi, safety_grade, failure_mode, corrective_action, patient_risk_flag, audited_at) values
('2026-06-01'::date, 'IVP-AP-001', 'BBraun OEM', true, 8.40, 0.00, true, 72.50, 98.20, 12.10, 'A', 'none', 'pass', false, '2026-06-05'::timestamptz),
('2026-06-01'::date, 'IVP-AP-002', 'BBraun OEM', true, 7.80, 0.02, true, 71.80, 97.50, 11.90, 'A', 'none', 'pass', false, '2026-06-05'::timestamptz),
('2026-06-01'::date, 'IVP-AP-003', 'BPL OEM', true, 6.20, 0.05, true, 68.40, 96.80, 10.20, 'B', 'none', 'pass', false, '2026-06-06'::timestamptz),
('2026-06-01'::date, 'IVP-AP-004', 'BBraun OEM', false, null, 4.80, false, 65.20, 88.40, 8.10, 'F', 'clamp_worn', 'remove_from_service', true, '2026-06-07'::timestamptz),
('2026-06-01'::date, 'IVP-AP-005', 'Fresenius OEM', true, 8.10, 0.01, true, 73.10, 98.90, 12.40, 'A', 'none', 'pass', false, '2026-06-07'::timestamptz),
('2026-06-01'::date, 'IVP-AP-006', 'Smiths OEM', true, 5.40, 1.20, true, 70.20, 92.30, 9.80, 'C', 'tubing_creep', 'replace_set', false, '2026-06-08'::timestamptz),
('2026-06-01'::date, 'IVP-AP-007', 'BBraun OEM', true, 8.50, 0.00, true, 72.80, 98.50, 12.20, 'A', 'none', 'pass', false, '2026-06-08'::timestamptz),
('2026-06-01'::date, 'IVP-AP-008', 'Generic', true, 4.10, 2.40, false, 64.50, 89.20, 8.40, 'D', 'door_sensor', 'replace_clamp', true, '2026-06-09'::timestamptz),
('2026-06-01'::date, 'IVP-AP-009', 'Fresenius OEM', true, 7.90, 0.03, true, 72.10, 97.80, 11.70, 'A', 'none', 'pass', false, '2026-06-09'::timestamptz),
('2026-06-01'::date, 'IVP-AP-010', 'BBraun OEM', false, null, 6.20, false, 62.10, 84.50, 7.80, 'F', 'controller_bug', 'remove_from_service', true, '2026-06-10'::timestamptz),
('2026-06-01'::date, 'IVP-AP-011', 'Smiths OEM', true, 8.20, 0.01, true, 73.40, 99.10, 12.50, 'A', 'none', 'pass', false, '2026-06-10'::timestamptz),
('2026-06-01'::date, 'IVP-AP-012', 'BPL OEM', true, 6.40, 0.08, true, 68.90, 96.20, 10.40, 'B', 'none', 'pass', false, '2026-06-11'::timestamptz),
('2026-06-01'::date, 'IVP-AP-013', 'Generic', false, null, 8.40, false, 58.20, 78.10, 6.20, 'F', 'set_misload', 'remove_from_service', true, '2026-06-11'::timestamptz),
('2026-06-01'::date, 'IVP-AP-014', 'Fresenius OEM', true, 8.00, 0.02, true, 72.40, 98.10, 12.00, 'A', 'none', 'pass', false, '2026-06-12'::timestamptz),
('2026-06-01'::date, 'IVP-AP-015', 'BBraun OEM', true, 5.80, 0.90, true, 69.80, 93.40, 10.10, 'C', 'tubing_creep', 'adjust', false, '2026-06-12'::timestamptz);

-- RPC 1: drift severity rollup
create or replace function r3090_drift_severity_rollup()
returns table(drift_severity text, pumps int, avg_drift_pct numeric, max_drift_pct numeric, critical_or_major int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.drift_severity,
         count(*)::int,
         round(avg(d.drift_percent)::numeric, 2),
         round(max(d.drift_percent)::numeric, 2),
         (count(*) filter (where d.drift_severity in ('major','critical')))::int
  from iv_pump_battery_memory_drift_r3090 d
  group by d.drift_severity
  order by d.drift_severity;
end; $$;
revoke all on function r3090_drift_severity_rollup() from public, anon;
grant execute on function r3090_drift_severity_rollup() to authenticated;

-- RPC 2: battery aging risk
create or replace function r3090_battery_aging_risk()
returns table(pump_asset_tag text, manufacturer text, battery_cycle_count int, drift_percent numeric, action_taken text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.pump_asset_tag, d.pump_manufacturer, d.battery_cycle_count, d.drift_percent, d.action_taken
  from iv_pump_battery_memory_drift_r3090 d
  where d.battery_cycle_count > 500 or d.drift_percent > 10
  order by d.drift_percent desc;
end; $$;
revoke all on function r3090_battery_aging_risk() from public, anon;
grant execute on function r3090_battery_aging_risk() to authenticated;

-- RPC 3: memory retention failures
create or replace function r3090_memory_retention_failures()
returns table(pump_asset_tag text, model text, memory_drift_seconds int, ward_location text, action_taken text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.pump_asset_tag, d.pump_model, d.memory_drift_seconds, d.ward_location, d.action_taken
  from iv_pump_battery_memory_drift_r3090 d
  where d.memory_retention_pass = false
  order by d.memory_drift_seconds desc;
end; $$;
revoke all on function r3090_memory_retention_failures() from public, anon;
grant execute on function r3090_memory_retention_failures() to authenticated;

-- RPC 4: free flow safety grade summary
create or replace function r3090_free_flow_grade_summary()
returns table(safety_grade text, pumps int, patient_risk_flags int, avg_free_flow numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.safety_grade,
         count(*)::int,
         (count(*) filter (where f.patient_risk_flag))::int,
         round(avg(f.free_flow_ml_per_min)::numeric, 2)
  from iv_pump_free_flow_safety_audit_r3090 f
  group by f.safety_grade
  order by f.safety_grade;
end; $$;
revoke all on function r3090_free_flow_grade_summary() from public, anon;
grant execute on function r3090_free_flow_grade_summary() to authenticated;

-- RPC 5: patient risk pumps
create or replace function r3090_patient_risk_pumps()
returns table(pump_asset_tag text, set_brand text, safety_grade text, failure_mode text, corrective_action text, free_flow_ml_per_min numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.pump_asset_tag, f.set_brand, f.safety_grade, f.failure_mode, f.corrective_action, f.free_flow_ml_per_min
  from iv_pump_free_flow_safety_audit_r3090 f
  where f.patient_risk_flag = true
  order by f.free_flow_ml_per_min desc;
end; $$;
revoke all on function r3090_patient_risk_pumps() from public, anon;
grant execute on function r3090_patient_risk_pumps() to authenticated;

-- RPC 6: failure mode breakdown
create or replace function r3090_failure_mode_breakdown()
returns table(failure_mode text, occurrences int, removed_from_service int, replace_set int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select coalesce(f.failure_mode, 'none')::text,
         count(*)::int,
         (count(*) filter (where f.corrective_action = 'remove_from_service'))::int,
         (count(*) filter (where f.corrective_action = 'replace_set'))::int
  from iv_pump_free_flow_safety_audit_r3090 f
  group by coalesce(f.failure_mode, 'none')
  order by count(*) desc;
end; $$;
revoke all on function r3090_failure_mode_breakdown() from public, anon;
grant execute on function r3090_failure_mode_breakdown() to authenticated;

-- RPC 7: combined audit health by pump
create or replace function r3090_combined_audit_health()
returns table(pump_asset_tag text, drift_severity text, drift_action text, safety_grade text, corrective_action text, combined_risk text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.pump_asset_tag,
         d.drift_severity,
         d.action_taken,
         f.safety_grade,
         f.corrective_action,
         case
           when d.drift_severity = 'critical' or f.safety_grade = 'F' then 'HIGH'
           when d.drift_severity = 'major' or f.safety_grade in ('D') then 'ELEVATED'
           when d.drift_severity = 'minor' or f.safety_grade = 'C' then 'MODERATE'
           else 'LOW'
         end::text
  from iv_pump_battery_memory_drift_r3090 d
  left join iv_pump_free_flow_safety_audit_r3090 f on f.pump_asset_tag = d.pump_asset_tag and f.audit_month = d.audit_month
  order by d.pump_asset_tag;
end; $$;
revoke all on function r3090_combined_audit_health() from public, anon;
grant execute on function r3090_combined_audit_health() to authenticated;
