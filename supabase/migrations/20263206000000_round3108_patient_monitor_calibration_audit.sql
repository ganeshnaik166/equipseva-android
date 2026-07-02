-- Round 3108 — Customer Hospital Patient-Monitor SpO2 NIBP Calibration Compliance Audit
-- Quarterly patient-monitor calibration tracking across SpO2 simulator deviation,
-- NIBP cuff pressure accuracy, ECG calibration, probe/cable health, and CAPA.

set search_path = public, pg_temp;

-- =====================================================================
-- TABLE 1 — patient monitor calibration sessions
-- =====================================================================
create table if not exists patient_monitor_calibration_sessions_r3108 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references organizations(id) on delete cascade,
  monitor_asset_tag text not null,
  monitor_make text not null,
  monitor_model text not null,
  bed_location text not null,
  ward_name text not null,
  calibration_quarter text not null check (calibration_quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  calibrated_at timestamptz not null default now(),
  engineer_id uuid references engineers(id) on delete set null,
  spo2_simulator_serial text not null,
  spo2_target_pct numeric(5,2) not null check (spo2_target_pct between 70 and 100),
  spo2_measured_pct numeric(5,2) not null check (spo2_measured_pct between 50 and 100),
  spo2_deviation_pct numeric(5,2) not null,
  nibp_cuff_target_mmhg integer not null check (nibp_cuff_target_mmhg between 60 and 280),
  nibp_cuff_measured_mmhg integer not null,
  nibp_deviation_mmhg integer not null,
  ecg_calibration_mv numeric(4,2) not null check (ecg_calibration_mv between 0.5 and 2.0),
  ecg_pass boolean not null default true,
  probe_cable_health text not null check (probe_cable_health in ('excellent','good','fair','degraded','replace_now')),
  overall_verdict text not null check (overall_verdict in ('pass','conditional_pass','fail','withdrawn_from_service')),
  nabh_clause_ref text not null check (nabh_clause_ref in ('FMS.7','FMS.7a','FMS.7b','FMS.8','COP.18','COP.18a')),
  certificate_pdf_url text,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_pmcs_r3108_hospital on patient_monitor_calibration_sessions_r3108(hospital_org_id);
create index if not exists idx_pmcs_r3108_quarter on patient_monitor_calibration_sessions_r3108(calibration_quarter);
create index if not exists idx_pmcs_r3108_verdict on patient_monitor_calibration_sessions_r3108(overall_verdict);

-- =====================================================================
-- TABLE 2 — CAPA (corrective and preventive actions) for failed calibrations
-- =====================================================================
create table if not exists patient_monitor_calibration_capa_r3108 (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references patient_monitor_calibration_sessions_r3108(id) on delete cascade,
  hospital_org_id uuid not null references organizations(id) on delete cascade,
  capa_kind text not null check (capa_kind in ('spo2_recalibrate','nibp_cuff_replace','ecg_lead_replace','probe_replace','cable_replace','firmware_update','full_service','retire_asset')),
  root_cause text not null check (root_cause in ('sensor_drift','cuff_leak','cable_break','firmware_bug','operator_error','transducer_aging','battery_aging','unknown')),
  severity text not null check (severity in ('low','medium','high','critical')),
  capa_status text not null check (capa_status in ('open','in_progress','awaiting_parts','blocked','closed','verified','cancelled')),
  opened_at timestamptz not null default now(),
  target_close_at timestamptz not null,
  closed_at timestamptz,
  assigned_engineer_id uuid references engineers(id) on delete set null,
  estimated_cost_rupees integer not null check (estimated_cost_rupees >= 0),
  actual_cost_rupees integer,
  patient_safety_impact text not null check (patient_safety_impact in ('none','minor','moderate','major','sentinel_event')),
  follow_up_required boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_pmcc_r3108_session on patient_monitor_calibration_capa_r3108(session_id);
create index if not exists idx_pmcc_r3108_status on patient_monitor_calibration_capa_r3108(capa_status);
create index if not exists idx_pmcc_r3108_severity on patient_monitor_calibration_capa_r3108(severity);

-- =====================================================================
-- SEED DATA
-- =====================================================================
do $seed$
declare
  v_org uuid;
  v_eng uuid;
  v_session_ids uuid[];
begin
  select id into v_org from organizations order by created_at asc limit 1;
  if v_org is null then
    raise notice 'no organizations row — skipping r3108 seed';
    return;
  end if;

  select id into v_eng from engineers order by created_at asc limit 1;

  insert into patient_monitor_calibration_sessions_r3108
    (hospital_org_id, monitor_asset_tag, monitor_make, monitor_model, bed_location, ward_name,
     calibration_quarter, engineer_id, spo2_simulator_serial, spo2_target_pct, spo2_measured_pct, spo2_deviation_pct,
     nibp_cuff_target_mmhg, nibp_cuff_measured_mmhg, nibp_deviation_mmhg,
     ecg_calibration_mv, ecg_pass, probe_cable_health, overall_verdict, nabh_clause_ref, notes)
  values
    (v_org, 'PM-ICU-001', 'Philips', 'IntelliVue MX450', 'Bed-1', 'ICU-A', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 95.00, 95.20, 0.20, 120, 121, 1, 1.00, true, 'excellent', 'pass', 'FMS.7', 'clean pass'),
    (v_org, 'PM-ICU-002', 'GE', 'B450', 'Bed-2', 'ICU-A', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 90.00, 91.50, 1.50, 140, 143, 3, 1.00, true, 'good', 'pass', 'FMS.7', 'within tolerance'),
    (v_org, 'PM-ICU-003', 'Mindray', 'BeneView T5', 'Bed-3', 'ICU-A', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 88.00, 92.50, 4.50, 120, 128, 8, 1.00, true, 'fair', 'conditional_pass', 'FMS.7a', 'spo2 drift flagged'),
    (v_org, 'PM-OT-001', 'Nihon Kohden', 'BSM-6301', 'OT-1', 'OT', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-002', 96.00, 96.10, 0.10, 100, 100, 0, 1.00, true, 'excellent', 'pass', 'FMS.7', 'OT certified'),
    (v_org, 'PM-OT-002', 'Drager', 'Infinity Delta', 'OT-2', 'OT', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-002', 92.00, 86.00, -6.00, 110, 95, -15, 1.00, false, 'degraded', 'fail', 'FMS.8', 'spo2 + nibp + ecg fail'),
    (v_org, 'PM-PED-001', 'Philips', 'IntelliVue MX400', 'Bed-1', 'Paediatric', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 97.00, 97.20, 0.20, 80, 81, 1, 1.00, true, 'good', 'pass', 'FMS.7', 'paeds OK'),
    (v_org, 'PM-PED-002', 'GE', 'B125', 'Bed-2', 'Paediatric', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 95.00, 90.00, -5.00, 90, 102, 12, 1.20, true, 'fair', 'fail', 'FMS.8', 'cuff size mismatch'),
    (v_org, 'PM-ER-001', 'Mindray', 'iPM-12', 'Trauma-1', 'ER', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-002', 88.00, 88.30, 0.30, 130, 132, 2, 1.00, true, 'good', 'pass', 'FMS.7', 'ER ready'),
    (v_org, 'PM-ER-002', 'Philips', 'SureSigns VS4', 'Trauma-2', 'ER', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-002', 94.00, 78.00, -16.00, 120, 145, 25, 1.50, false, 'replace_now', 'withdrawn_from_service', 'COP.18', 'sensor failure — pulled from service'),
    (v_org, 'PM-NICU-001', 'Drager', 'Babylog VN500 monitor', 'Iso-1', 'NICU', 'Q1-2026', v_eng, 'FLUKE-INDEX-2SE', 98.00, 98.10, 0.10, 60, 60, 0, 0.50, true, 'excellent', 'pass', 'FMS.7', 'NICU strict pass'),
    (v_org, 'PM-NICU-002', 'GE', 'CARESCAPE B650', 'Iso-2', 'NICU', 'Q1-2026', v_eng, 'FLUKE-INDEX-2SE', 96.00, 94.00, -2.00, 65, 68, 3, 0.50, true, 'fair', 'conditional_pass', 'COP.18a', 'NICU follow-up Q2'),
    (v_org, 'PM-WARD-101', 'Mindray', 'VS-900', 'Bed-101', 'General-A', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 94.00, 94.20, 0.20, 130, 131, 1, 1.00, true, 'good', 'pass', 'FMS.7', 'routine pass'),
    (v_org, 'PM-WARD-102', 'Nihon Kohden', 'BSM-3500', 'Bed-102', 'General-A', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-001', 92.00, 86.50, -5.50, 140, 152, 12, 1.30, true, 'degraded', 'fail', 'FMS.7b', 'probe + cuff replace'),
    (v_org, 'PM-DIAL-001', 'Philips', 'IntelliVue MX500', 'Chair-1', 'Dialysis', 'Q1-2026', v_eng, 'FLUKE-PROSIM-8-002', 96.00, 96.30, 0.30, 150, 151, 1, 1.00, true, 'excellent', 'pass', 'FMS.7', 'dialysis OK');

  -- gather session ids deterministically by tag for FK CAPA seed
  select array_agg(id order by monitor_asset_tag)
    into v_session_ids
    from patient_monitor_calibration_sessions_r3108
    where hospital_org_id = v_org;

  insert into patient_monitor_calibration_capa_r3108
    (session_id, hospital_org_id, capa_kind, root_cause, severity, capa_status,
     target_close_at, closed_at, assigned_engineer_id, estimated_cost_rupees, actual_cost_rupees,
     patient_safety_impact, follow_up_required, notes)
  values
    -- map by index into session-id array; tags sorted alphabetically:
    -- 1 PM-DIAL-001  2 PM-ER-001  3 PM-ER-002  4 PM-ICU-001  5 PM-ICU-002  6 PM-ICU-003
    -- 7 PM-NICU-001  8 PM-NICU-002  9 PM-OT-001  10 PM-OT-002  11 PM-PED-001  12 PM-PED-002
    -- 13 PM-WARD-101  14 PM-WARD-102
    (v_session_ids[6],  v_org, 'spo2_recalibrate', 'sensor_drift', 'medium', 'closed',     now() + interval '14 days', now() - interval '2 days', v_eng, 3500,  3200,  'minor',    false, 'recalibrated, drift back to 1.2'),
    (v_session_ids[10], v_org, 'firmware_update', 'firmware_bug', 'high',   'verified',   now() + interval '7 days',  now() - interval '5 days', v_eng, 8000,  8000,  'moderate', true,  'Drager firmware push 3.4.1'),
    (v_session_ids[10], v_org, 'cable_replace', 'cable_break', 'high', 'in_progress',     now() + interval '5 days',  null,                      v_eng, 4500,  null,  'moderate', true,  'ECG lead set ordered'),
    (v_session_ids[3],  v_org, 'probe_replace', 'transducer_aging', 'critical', 'awaiting_parts', now() + interval '3 days', null,               v_eng, 12000, null,  'major',    true,  'pulse-ox sensor on order'),
    (v_session_ids[3],  v_org, 'nibp_cuff_replace', 'cuff_leak', 'critical', 'open',       now() + interval '1 days',  null,                      v_eng, 2200,  null,  'major',    true,  'cuff leak isolated'),
    (v_session_ids[12], v_org, 'nibp_cuff_replace', 'cuff_leak', 'high', 'closed',         now() + interval '7 days',  now() - interval '1 days', v_eng, 2200,  2200,  'minor',    false, 'paed cuff size corrected'),
    (v_session_ids[14], v_org, 'full_service', 'sensor_drift', 'medium', 'blocked',       now() + interval '21 days', null,                      v_eng, 15000, null,  'minor',    true,  'awaiting biomed slot'),
    (v_session_ids[8],  v_org, 'spo2_recalibrate', 'sensor_drift', 'low', 'verified',     now() + interval '30 days', now() - interval '10 days',v_eng, 3500,  3500,  'none',     false, 'NICU follow-up satisfied'),
    (v_session_ids[6],  v_org, 'ecg_lead_replace', 'cable_break', 'medium', 'closed',     now() + interval '14 days', now() - interval '8 days', v_eng, 4500,  4200,  'minor',    false, 'lead set swapped'),
    (v_session_ids[10], v_org, 'retire_asset', 'transducer_aging', 'critical', 'cancelled', now() + interval '60 days', null,                    v_eng, 0,     null,  'sentinel_event', false, 'capex deferred'),
    (v_session_ids[14], v_org, 'cable_replace', 'cable_break', 'high', 'in_progress',     now() + interval '5 days',  null,                      v_eng, 4500,  null,  'moderate', true,  'cable on order'),
    (v_session_ids[6],  v_org, 'firmware_update', 'firmware_bug', 'low', 'open',          now() + interval '30 days', null,                      v_eng, 5000,  null,  'none',     false, 'Q2 batch update'),
    (v_session_ids[3],  v_org, 'full_service', 'unknown', 'critical', 'open',             now() + interval '2 days',  null,                      v_eng, 20000, null,  'major',    true,  'unit withdrawn');
end
$seed$;

-- =====================================================================
-- RPC 1 — quarterly summary
-- =====================================================================
create or replace function r3108_quarterly_summary()
returns table (
  calibration_quarter text,
  total_sessions integer,
  pass_count integer,
  conditional_pass_count integer,
  fail_count integer,
  withdrawn_count integer,
  pass_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.calibration_quarter::text,
           count(*)::integer,
           count(*) filter (where s.overall_verdict='pass')::integer,
           count(*) filter (where s.overall_verdict='conditional_pass')::integer,
           count(*) filter (where s.overall_verdict='fail')::integer,
           count(*) filter (where s.overall_verdict='withdrawn_from_service')::integer,
           round(100.0 * count(*) filter (where s.overall_verdict='pass') / nullif(count(*),0), 1)
      from patient_monitor_calibration_sessions_r3108 s
     group by s.calibration_quarter
     order by s.calibration_quarter;
end
$fn$;

revoke execute on function r3108_quarterly_summary() from public, anon;
grant execute on function r3108_quarterly_summary() to authenticated;

-- =====================================================================
-- RPC 2 — ward heatmap
-- =====================================================================
create or replace function r3108_ward_heatmap()
returns table (
  ward_name text,
  sessions integer,
  fails integer,
  withdrawn integer,
  avg_spo2_dev numeric,
  avg_nibp_dev numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.ward_name::text,
           count(*)::integer,
           count(*) filter (where s.overall_verdict='fail')::integer,
           count(*) filter (where s.overall_verdict='withdrawn_from_service')::integer,
           round(avg(abs(s.spo2_deviation_pct))::numeric, 2),
           round(avg(abs(s.nibp_deviation_mmhg))::numeric, 2)
      from patient_monitor_calibration_sessions_r3108 s
     group by s.ward_name
     order by fails desc, withdrawn desc, s.ward_name;
end
$fn$;

revoke execute on function r3108_ward_heatmap() from public, anon;
grant execute on function r3108_ward_heatmap() to authenticated;

-- =====================================================================
-- RPC 3 — vendor (make) deviation rollup
-- =====================================================================
create or replace function r3108_vendor_deviation()
returns table (
  monitor_make text,
  monitors_tested integer,
  fail_rate_pct numeric,
  avg_spo2_dev numeric,
  worst_spo2_dev numeric,
  avg_nibp_dev numeric,
  worst_nibp_dev integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.monitor_make::text,
           count(*)::integer,
           round(100.0 * count(*) filter (where s.overall_verdict in ('fail','withdrawn_from_service')) / nullif(count(*),0), 1),
           round(avg(abs(s.spo2_deviation_pct))::numeric, 2),
           round(max(abs(s.spo2_deviation_pct))::numeric, 2),
           round(avg(abs(s.nibp_deviation_mmhg))::numeric, 2),
           max(abs(s.nibp_deviation_mmhg))::integer
      from patient_monitor_calibration_sessions_r3108 s
     group by s.monitor_make
     order by fail_rate_pct desc nulls last;
end
$fn$;

revoke execute on function r3108_vendor_deviation() from public, anon;
grant execute on function r3108_vendor_deviation() to authenticated;

-- =====================================================================
-- RPC 4 — probe/cable health distribution
-- =====================================================================
create or replace function r3108_probe_cable_health()
returns table (
  probe_cable_health text,
  count integer,
  share_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_total integer;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into v_total from patient_monitor_calibration_sessions_r3108;
  return query
    select s.probe_cable_health::text,
           count(*)::integer,
           round(100.0 * count(*) / nullif(v_total,0), 1)
      from patient_monitor_calibration_sessions_r3108 s
     group by s.probe_cable_health
     order by count desc;
end
$fn$;

revoke execute on function r3108_probe_cable_health() from public, anon;
grant execute on function r3108_probe_cable_health() to authenticated;

-- =====================================================================
-- RPC 5 — NABH clause rollup
-- =====================================================================
create or replace function r3108_nabh_clause_rollup()
returns table (
  nabh_clause_ref text,
  sessions integer,
  non_pass integer,
  open_capa integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.nabh_clause_ref::text,
           count(*)::integer,
           count(*) filter (where s.overall_verdict in ('conditional_pass','fail','withdrawn_from_service'))::integer,
           (select count(*)::integer
              from patient_monitor_calibration_capa_r3108 c
             where c.session_id in (select id from patient_monitor_calibration_sessions_r3108 s2 where s2.nabh_clause_ref = s.nabh_clause_ref)
               and c.capa_status in ('open','in_progress','awaiting_parts','blocked'))
      from patient_monitor_calibration_sessions_r3108 s
     group by s.nabh_clause_ref
     order by s.nabh_clause_ref;
end
$fn$;

revoke execute on function r3108_nabh_clause_rollup() from public, anon;
grant execute on function r3108_nabh_clause_rollup() to authenticated;

-- =====================================================================
-- RPC 6 — CAPA pipeline
-- =====================================================================
create or replace function r3108_capa_pipeline()
returns table (
  capa_status text,
  count integer,
  est_cost_rupees bigint,
  actual_cost_rupees bigint,
  avg_days_open numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.capa_status::text,
           count(*)::integer,
           coalesce(sum(c.estimated_cost_rupees),0)::bigint,
           coalesce(sum(c.actual_cost_rupees),0)::bigint,
           round(avg(extract(epoch from (coalesce(c.closed_at, now()) - c.opened_at)) / 86400.0)::numeric, 1)
      from patient_monitor_calibration_capa_r3108 c
     group by c.capa_status
     order by count desc;
end
$fn$;

revoke execute on function r3108_capa_pipeline() from public, anon;
grant execute on function r3108_capa_pipeline() to authenticated;

-- =====================================================================
-- RPC 7 — root-cause × severity matrix
-- =====================================================================
create or replace function r3108_root_cause_matrix()
returns table (
  root_cause text,
  severity text,
  count integer,
  total_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.root_cause::text,
           c.severity::text,
           count(*)::integer,
           coalesce(sum(c.estimated_cost_rupees),0)::bigint
      from patient_monitor_calibration_capa_r3108 c
     group by c.root_cause, c.severity
     order by c.root_cause, c.severity;
end
$fn$;

revoke execute on function r3108_root_cause_matrix() from public, anon;
grant execute on function r3108_root_cause_matrix() to authenticated;

-- =====================================================================
-- RPC 8 — overdue CAPA watchlist
-- =====================================================================
create or replace function r3108_overdue_capa_watch()
returns table (
  capa_id uuid,
  monitor_asset_tag text,
  ward_name text,
  capa_kind text,
  severity text,
  capa_status text,
  days_overdue integer,
  patient_safety_impact text,
  estimated_cost_rupees integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.id,
           s.monitor_asset_tag::text,
           s.ward_name::text,
           c.capa_kind::text,
           c.severity::text,
           c.capa_status::text,
           greatest(0, extract(day from (now() - c.target_close_at)))::integer,
           c.patient_safety_impact::text,
           c.estimated_cost_rupees
      from patient_monitor_calibration_capa_r3108 c
      join patient_monitor_calibration_sessions_r3108 s on s.id = c.session_id
     where c.capa_status in ('open','in_progress','awaiting_parts','blocked')
     order by c.severity desc, c.target_close_at asc;
end
$fn$;

revoke execute on function r3108_overdue_capa_watch() from public, anon;
grant execute on function r3108_overdue_capa_watch() to authenticated;

-- =====================================================================
-- RPC 9 — patient safety impact distribution
-- =====================================================================
create or replace function r3108_patient_safety_impact()
returns table (
  patient_safety_impact text,
  count integer,
  open_count integer,
  closed_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.patient_safety_impact::text,
           count(*)::integer,
           count(*) filter (where c.capa_status in ('open','in_progress','awaiting_parts','blocked'))::integer,
           count(*) filter (where c.capa_status in ('closed','verified'))::integer
      from patient_monitor_calibration_capa_r3108 c
     group by c.patient_safety_impact
     order by case c.patient_safety_impact
        when 'sentinel_event' then 1
        when 'major' then 2
        when 'moderate' then 3
        when 'minor' then 4
        when 'none' then 5
        else 6 end;
end
$fn$;

revoke execute on function r3108_patient_safety_impact() from public, anon;
grant execute on function r3108_patient_safety_impact() to authenticated;
