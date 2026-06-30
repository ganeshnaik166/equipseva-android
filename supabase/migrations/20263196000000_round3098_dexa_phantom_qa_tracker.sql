-- Round 3098: Customer Hospital Bone-Density DEXA Scanner Daily QA Phantom Tracker
-- HEAVY ★★★★ — daily phantom BMD QA tracking, drift trend, CAPA when out-of-spec

set search_path = public, pg_temp;

-- ============================================================
-- TABLE 1: daily phantom QA scan readings
-- ============================================================
create table if not exists dexa_phantom_qa_readings_r3098 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references organizations(id) on delete cascade,
  scanner_asset_tag text not null,
  scanner_model text not null check (scanner_model in (
    'Hologic Horizon W','Hologic Horizon A','Hologic Discovery Wi','Hologic Discovery Ci',
    'GE Lunar Prodigy','GE Lunar iDXA','GE Lunar DPX-NT','Norland Elite','Norland XR-800','Osteosys Primus'
  )),
  phantom_type text not null check (phantom_type in (
    'hologic_spine_phantom','hologic_block_phantom','ge_lunar_aluminum_spine','ge_lunar_calibration_block',
    'norland_77_step_phantom','european_spine_phantom'
  )),
  phantom_serial_no text not null,
  expected_bmd_g_cm2 numeric(6,4) not null check (expected_bmd_g_cm2 between 0.5 and 1.5),
  measured_bmd_g_cm2 numeric(6,4) not null check (measured_bmd_g_cm2 between 0.4 and 1.6),
  percent_deviation numeric(6,3) generated always as (
    ((measured_bmd_g_cm2 - expected_bmd_g_cm2) / expected_bmd_g_cm2) * 100
  ) stored,
  tolerance_band_pct numeric(4,2) not null default 1.5 check (tolerance_band_pct between 0.5 and 5.0),
  qa_status text not null check (qa_status in (
    'within_tolerance','warning_drift','out_of_spec','phantom_error','technologist_repeat_needed'
  )),
  drift_direction text not null check (drift_direction in ('stable','upward_drift','downward_drift','oscillating','first_baseline')),
  technologist_profile_id uuid references profiles(id) on delete set null,
  technologist_name text not null,
  technologist_dmlt_no text,
  ambient_temp_celsius numeric(4,1) check (ambient_temp_celsius between 15.0 and 35.0),
  humidity_pct numeric(4,1) check (humidity_pct between 20.0 and 80.0),
  scan_mode text not null check (scan_mode in ('fast_array','array','high_definition','express','thick_patient')),
  scan_duration_seconds integer not null check (scan_duration_seconds between 10 and 300),
  shift text not null check (shift in ('morning','afternoon','evening','night')),
  scan_date date not null,
  scanned_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dexa_qa_r3098_hospital on dexa_phantom_qa_readings_r3098(hospital_org_id, scan_date desc);
create index if not exists idx_dexa_qa_r3098_status on dexa_phantom_qa_readings_r3098(qa_status);
create index if not exists idx_dexa_qa_r3098_scanner on dexa_phantom_qa_readings_r3098(scanner_asset_tag, scan_date desc);

-- ============================================================
-- TABLE 2: CAPA (Corrective and Preventive Action) when out-of-spec
-- ============================================================
create table if not exists dexa_phantom_capa_events_r3098 (
  id uuid primary key default gen_random_uuid(),
  reading_id uuid not null references dexa_phantom_qa_readings_r3098(id) on delete cascade,
  hospital_org_id uuid not null references organizations(id) on delete cascade,
  capa_type text not null check (capa_type in (
    'recalibration_scheduled','engineer_dispatch','phantom_replaced','xray_tube_check',
    'detector_cleaning','full_preventive_maintenance','vendor_escalation','quarantine_scanner','retraining_technologist'
  )),
  severity text not null check (severity in ('p0_quarantine','p1_urgent','p2_routine','p3_advisory')),
  capa_status text not null check (capa_status in ('open','in_progress','engineer_assigned','resolved','verified_closed','cancelled')),
  engineer_id uuid references engineers(id) on delete set null,
  engineer_name text,
  repair_job_id uuid references repair_jobs(id) on delete set null,
  spare_part_order_id uuid references spare_part_orders(id) on delete set null,
  root_cause_category text not null check (root_cause_category in (
    'detector_drift','xray_tube_aging','phantom_degradation','operator_error','environmental','software_glitch','unknown_pending_investigation'
  )),
  corrective_action_summary text not null,
  preventive_action_summary text,
  downtime_hours numeric(6,2) check (downtime_hours between 0 and 720),
  cost_incurred_rupees integer check (cost_incurred_rupees between 0 and 5000000),
  opened_at timestamptz not null default now(),
  target_close_at timestamptz,
  closed_at timestamptz,
  verified_by_profile_id uuid references profiles(id) on delete set null,
  abn_jcia_reportable boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_dexa_capa_r3098_hospital on dexa_phantom_capa_events_r3098(hospital_org_id, opened_at desc);
create index if not exists idx_dexa_capa_r3098_status on dexa_phantom_capa_events_r3098(capa_status);
create index if not exists idx_dexa_capa_r3098_severity on dexa_phantom_capa_events_r3098(severity);

-- ============================================================
-- SEED DATA — 8 readings + 6 CAPA events = 14 rows
-- ============================================================
do $$
declare
  v_org_a uuid;
  v_org_b uuid;
  v_org_c uuid;
  v_reading1 uuid := gen_random_uuid();
  v_reading2 uuid := gen_random_uuid();
  v_reading3 uuid := gen_random_uuid();
  v_reading4 uuid := gen_random_uuid();
  v_reading5 uuid := gen_random_uuid();
  v_reading6 uuid := gen_random_uuid();
  v_reading7 uuid := gen_random_uuid();
  v_reading8 uuid := gen_random_uuid();
begin
  select id into v_org_a from organizations where type = 'hospital' order by created_at limit 1;
  select id into v_org_b from organizations where type = 'hospital' order by created_at offset 1 limit 1;
  select id into v_org_c from organizations where type = 'hospital' order by created_at offset 2 limit 1;
  if v_org_a is null then return; end if;
  if v_org_b is null then v_org_b := v_org_a; end if;
  if v_org_c is null then v_org_c := v_org_a; end if;

  insert into dexa_phantom_qa_readings_r3098 (
    id, hospital_org_id, scanner_asset_tag, scanner_model, phantom_type, phantom_serial_no,
    expected_bmd_g_cm2, measured_bmd_g_cm2, tolerance_band_pct, qa_status, drift_direction,
    technologist_name, technologist_dmlt_no, ambient_temp_celsius, humidity_pct,
    scan_mode, scan_duration_seconds, shift, scan_date, notes
  ) values
    (v_reading1, v_org_a, 'DEXA-APOLLO-HYD-01', 'Hologic Horizon W', 'hologic_spine_phantom', 'HSP-2024-8821',
     1.0250, 1.0265, 1.5, 'within_tolerance', 'stable',
     'Priya Reddy', 'DMLT-TS-22481', 23.5, 45.0, 'fast_array', 90, 'morning', current_date - 1, 'Routine morning QA'),
    (v_reading2, v_org_a, 'DEXA-APOLLO-HYD-01', 'Hologic Horizon W', 'hologic_spine_phantom', 'HSP-2024-8821',
     1.0250, 1.0410, 1.5, 'warning_drift', 'upward_drift',
     'Priya Reddy', 'DMLT-TS-22481', 24.2, 48.0, 'fast_array', 90, 'morning', current_date, 'Slight upward drift - monitor'),
    (v_reading3, v_org_b, 'DEXA-FORTIS-BLR-02', 'GE Lunar iDXA', 'ge_lunar_aluminum_spine', 'GLAS-2023-5512',
     1.1200, 1.1750, 1.5, 'out_of_spec', 'upward_drift',
     'Karthik Iyer', 'DMLT-KA-19887', 22.8, 52.0, 'array', 120, 'morning', current_date - 2, '+4.9% deviation - CAPA opened'),
    (v_reading4, v_org_b, 'DEXA-FORTIS-BLR-02', 'GE Lunar iDXA', 'ge_lunar_aluminum_spine', 'GLAS-2023-5512',
     1.1200, 1.1215, 1.5, 'within_tolerance', 'stable',
     'Karthik Iyer', 'DMLT-KA-19887', 23.0, 50.5, 'array', 120, 'morning', current_date, 'Post-recalibration baseline'),
    (v_reading5, v_org_c, 'DEXA-MAX-DEL-03', 'Hologic Discovery Wi', 'hologic_block_phantom', 'HBP-2024-1199',
     0.9850, 0.9620, 1.5, 'out_of_spec', 'downward_drift',
     'Anjali Sharma', 'DMLT-DL-30122', 25.1, 55.0, 'high_definition', 180, 'afternoon', current_date - 3, '-2.3% deviation - tube concern'),
    (v_reading6, v_org_c, 'DEXA-MAX-DEL-03', 'Hologic Discovery Wi', 'hologic_block_phantom', 'HBP-2024-1199',
     0.9850, 0.9525, 1.5, 'out_of_spec', 'downward_drift',
     'Anjali Sharma', 'DMLT-DL-30122', 24.8, 54.5, 'high_definition', 180, 'afternoon', current_date - 2, 'Worsening - quarantine considered'),
    (v_reading7, v_org_a, 'DEXA-APOLLO-HYD-02', 'GE Lunar Prodigy', 'ge_lunar_calibration_block', 'GLCB-2022-7741',
     1.0500, 1.0512, 1.5, 'within_tolerance', 'stable',
     'Ravi Kumar', 'DMLT-TS-18995', 23.0, 46.0, 'express', 60, 'morning', current_date, 'Stable post-PM'),
    (v_reading8, v_org_b, 'DEXA-FORTIS-BLR-03', 'Norland Elite', 'norland_77_step_phantom', 'N77-2025-0034',
     0.9700, 0.9710, 2.0, 'within_tolerance', 'first_baseline',
     'Sneha Pillai', 'DMLT-KA-25001', 22.5, 49.0, 'fast_array', 75, 'evening', current_date - 1, 'New scanner first baseline');

  insert into dexa_phantom_capa_events_r3098 (
    reading_id, hospital_org_id, capa_type, severity, capa_status, engineer_name,
    root_cause_category, corrective_action_summary, preventive_action_summary,
    downtime_hours, cost_incurred_rupees, target_close_at, abn_jcia_reportable
  ) values
    (v_reading3, v_org_b, 'recalibration_scheduled', 'p1_urgent', 'verified_closed', 'Vikram Singh',
     'detector_drift', 'Detector recalibration performed using factory phantom; baseline re-established',
     'Increase QA frequency to twice-daily for 14 days', 4.5, 12500, now() + interval '1 day', false),
    (v_reading5, v_org_c, 'xray_tube_check', 'p1_urgent', 'in_progress', 'Suresh Menon',
     'xray_tube_aging', 'X-ray tube output measurement; mA stability check in progress',
     'Schedule tube replacement assessment if drift persists', 8.0, 35000, now() + interval '2 days', false),
    (v_reading6, v_org_c, 'quarantine_scanner', 'p0_quarantine', 'open', 'Suresh Menon',
     'detector_drift', 'Scanner quarantined from patient use pending full diagnostic',
     'Vendor escalation to Hologic India; patient scans rerouted to backup unit', 24.0, 0, now() + interval '3 days', true),
    (v_reading6, v_org_c, 'vendor_escalation', 'p0_quarantine', 'engineer_assigned', 'Hologic Field Engineer',
     'unknown_pending_investigation', 'Hologic India dispatched FSE; remote diagnostic initiated',
     'Document RCA in NABH equipment QA log', null, 0, now() + interval '5 days', true),
    (v_reading2, v_org_a, 'retraining_technologist', 'p3_advisory', 'resolved', null,
     'operator_error', 'Technologist re-trained on phantom positioning SOP',
     'Add positioning checklist to daily QA form', 1.0, 0, now() + interval '7 days', false),
    (v_reading5, v_org_c, 'detector_cleaning', 'p2_routine', 'resolved', 'Suresh Menon',
     'environmental', 'Detector window cleaned; dust contamination removed',
     'Add weekly detector cleaning to PM checklist', 1.5, 1500, now() + interval '1 day', false);
end$$;

-- ============================================================
-- RPCs (8 founder-gated)
-- ============================================================

-- 1. Out-of-spec readings (last 30 days)
create or replace function founder_dexa_qa_out_of_spec_r3098()
returns table (
  reading_id uuid,
  scan_date date,
  scanner_asset_tag text,
  scanner_model text,
  hospital_org text,
  measured_bmd numeric,
  expected_bmd numeric,
  percent_deviation numeric,
  drift_direction text,
  technologist_name text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.id, r.scan_date, r.scanner_asset_tag, r.scanner_model,
         o.name, r.measured_bmd_g_cm2, r.expected_bmd_g_cm2, r.percent_deviation,
         r.drift_direction, r.technologist_name
  from dexa_phantom_qa_readings_r3098 r
  join organizations o on o.id = r.hospital_org_id
  where r.qa_status = 'out_of_spec'
    and r.scan_date >= current_date - 30
  order by r.scan_date desc, abs(r.percent_deviation) desc;
end$$;

revoke execute on function founder_dexa_qa_out_of_spec_r3098() from public, anon;
grant execute on function founder_dexa_qa_out_of_spec_r3098() to authenticated;

-- 2. Drift trend per scanner
create or replace function founder_dexa_qa_drift_trend_r3098()
returns table (
  scanner_asset_tag text,
  scanner_model text,
  hospital_org text,
  readings_30d bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric,
  out_of_spec_count bigint,
  dominant_drift text
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.scanner_asset_tag, r.scanner_model, o.name,
         count(*)::bigint,
         round(avg(r.percent_deviation)::numeric, 3),
         round(max(abs(r.percent_deviation))::numeric, 3),
         count(*) filter (where r.qa_status = 'out_of_spec')::bigint,
         mode() within group (order by r.drift_direction)
  from dexa_phantom_qa_readings_r3098 r
  join organizations o on o.id = r.hospital_org_id
  where r.scan_date >= current_date - 30
  group by r.scanner_asset_tag, r.scanner_model, o.name
  order by max(abs(r.percent_deviation)) desc;
end$$;

revoke execute on function founder_dexa_qa_drift_trend_r3098() from public, anon;
grant execute on function founder_dexa_qa_drift_trend_r3098() to authenticated;

-- 3. CAPA pipeline by status
create or replace function founder_dexa_capa_pipeline_r3098()
returns table (
  capa_status text,
  severity text,
  open_count bigint,
  avg_downtime_hours numeric,
  total_cost_rupees bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, c.severity, count(*)::bigint,
         round(avg(c.downtime_hours)::numeric, 2),
         coalesce(sum(c.cost_incurred_rupees), 0)::bigint
  from dexa_phantom_capa_events_r3098 c
  group by c.capa_status, c.severity
  order by case c.severity
    when 'p0_quarantine' then 0
    when 'p1_urgent' then 1
    when 'p2_routine' then 2
    else 3 end, c.capa_status;
end$$;

revoke execute on function founder_dexa_capa_pipeline_r3098() from public, anon;
grant execute on function founder_dexa_capa_pipeline_r3098() to authenticated;

-- 4. Technologist scorecard
create or replace function founder_dexa_qa_technologist_scorecard_r3098()
returns table (
  technologist_name text,
  dmlt_no text,
  total_scans bigint,
  within_tolerance bigint,
  out_of_spec bigint,
  warning_drift bigint,
  pass_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.technologist_name, r.technologist_dmlt_no,
         count(*)::bigint,
         count(*) filter (where r.qa_status = 'within_tolerance')::bigint,
         count(*) filter (where r.qa_status = 'out_of_spec')::bigint,
         count(*) filter (where r.qa_status = 'warning_drift')::bigint,
         round(100.0 * count(*) filter (where r.qa_status = 'within_tolerance') / nullif(count(*), 0), 2)
  from dexa_phantom_qa_readings_r3098 r
  group by r.technologist_name, r.technologist_dmlt_no
  order by count(*) filter (where r.qa_status = 'within_tolerance') desc;
end$$;

revoke execute on function founder_dexa_qa_technologist_scorecard_r3098() from public, anon;
grant execute on function founder_dexa_qa_technologist_scorecard_r3098() to authenticated;

-- 5. Phantom-type performance
create or replace function founder_dexa_qa_phantom_breakdown_r3098()
returns table (
  phantom_type text,
  scans bigint,
  avg_deviation_pct numeric,
  out_of_spec bigint,
  unique_serials bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.phantom_type, count(*)::bigint,
         round(avg(r.percent_deviation)::numeric, 3),
         count(*) filter (where r.qa_status = 'out_of_spec')::bigint,
         count(distinct r.phantom_serial_no)::bigint
  from dexa_phantom_qa_readings_r3098 r
  group by r.phantom_type
  order by count(*) desc;
end$$;

revoke execute on function founder_dexa_qa_phantom_breakdown_r3098() from public, anon;
grant execute on function founder_dexa_qa_phantom_breakdown_r3098() to authenticated;

-- 6. Root-cause distribution from CAPA
create or replace function founder_dexa_capa_root_cause_r3098()
returns table (
  root_cause_category text,
  capa_count bigint,
  avg_downtime_hours numeric,
  total_cost_rupees bigint,
  reportable_count bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.root_cause_category, count(*)::bigint,
         round(avg(c.downtime_hours)::numeric, 2),
         coalesce(sum(c.cost_incurred_rupees), 0)::bigint,
         count(*) filter (where c.abn_jcia_reportable = true)::bigint
  from dexa_phantom_capa_events_r3098 c
  group by c.root_cause_category
  order by count(*) desc;
end$$;

revoke execute on function founder_dexa_capa_root_cause_r3098() from public, anon;
grant execute on function founder_dexa_capa_root_cause_r3098() to authenticated;

-- 7. Hospital QA compliance summary
create or replace function founder_dexa_qa_hospital_compliance_r3098()
returns table (
  hospital_org text,
  scanners_tracked bigint,
  scans_30d bigint,
  pass_rate_pct numeric,
  open_capas bigint,
  jcia_reportable bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select o.name,
         count(distinct r.scanner_asset_tag)::bigint,
         count(r.id)::bigint,
         round(100.0 * count(r.id) filter (where r.qa_status = 'within_tolerance') / nullif(count(r.id), 0), 2),
         (select count(*) from dexa_phantom_capa_events_r3098 c
          where c.hospital_org_id = o.id and c.capa_status in ('open','in_progress','engineer_assigned'))::bigint,
         (select count(*) from dexa_phantom_capa_events_r3098 c
          where c.hospital_org_id = o.id and c.abn_jcia_reportable = true)::bigint
  from organizations o
  left join dexa_phantom_qa_readings_r3098 r on r.hospital_org_id = o.id and r.scan_date >= current_date - 30
  where o.type = 'hospital'
  group by o.id, o.name
  having count(r.id) > 0
  order by count(r.id) desc;
end$$;

revoke execute on function founder_dexa_qa_hospital_compliance_r3098() from public, anon;
grant execute on function founder_dexa_qa_hospital_compliance_r3098() to authenticated;

-- 8. Recent CAPA events with full context
create or replace function founder_dexa_capa_recent_events_r3098()
returns table (
  capa_id uuid,
  opened_at timestamptz,
  hospital_org text,
  capa_type text,
  severity text,
  capa_status text,
  engineer_name text,
  root_cause text,
  downtime_hours numeric,
  cost_rupees integer
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.id, c.opened_at, o.name, c.capa_type, c.severity, c.capa_status,
         c.engineer_name, c.root_cause_category, c.downtime_hours, c.cost_incurred_rupees
  from dexa_phantom_capa_events_r3098 c
  join organizations o on o.id = c.hospital_org_id
  order by c.opened_at desc
  limit 50;
end$$;

revoke execute on function founder_dexa_capa_recent_events_r3098() from public, anon;
grant execute on function founder_dexa_capa_recent_events_r3098() to authenticated;
