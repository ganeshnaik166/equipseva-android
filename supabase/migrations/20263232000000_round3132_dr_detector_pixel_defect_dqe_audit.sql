-- Round 3132: Customer Hospital Radiology DR Detector Panel Pixel Defect & DQE Performance Audit
-- Scope: pixel defect map, DQE, MTF, line-pair resolution, ghost image, replacement cost, CAPA

set check_function_bodies = off;

create table if not exists dr_detector_panel_audits_r3132 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_id uuid not null references organizations(id) on delete cascade,
  panel_serial text not null,
  panel_make text not null,
  panel_model text not null,
  panel_type text not null check (panel_type in ('a_si_csi','a_si_gos','igzo_csi','cmos_csi','wireless_csi','tethered_gos')),
  installed_on date not null,
  audit_date date not null,
  modality text not null check (modality in ('general_xr','chest_xr','ortho_xr','fluoro','mammography_dr','dental_pano','cath_lab','portable_xr')),
  use_intensity text not null check (use_intensity in ('low','medium','high','very_high','24x7_trauma')),
  pixel_pitch_um numeric(6,2) not null check (pixel_pitch_um between 50 and 200),
  active_area_cm text not null,
  total_dead_pixels integer not null check (total_dead_pixels >= 0),
  cluster_defects integer not null check (cluster_defects >= 0),
  line_defects integer not null check (line_defects >= 0),
  dqe_at_1lp_mm numeric(4,3) not null check (dqe_at_1lp_mm between 0 and 1),
  dqe_at_2lp_mm numeric(4,3) not null check (dqe_at_2lp_mm between 0 and 1),
  mtf_at_2lp_mm numeric(4,3) not null check (mtf_at_2lp_mm between 0 and 1),
  limiting_resolution_lp_mm numeric(4,2) not null check (limiting_resolution_lp_mm > 0),
  ghost_image_severity text not null check (ghost_image_severity in ('none','trace','mild','moderate','severe','image_unusable')),
  uniformity_pct numeric(5,2) not null check (uniformity_pct between 0 and 100),
  noise_floor_grade text not null check (noise_floor_grade in ('excellent','good','acceptable','marginal','fail')),
  calibration_status text not null check (calibration_status in ('current','due_30d','overdue','offset_only','full_recal_needed')),
  audit_verdict text not null check (audit_verdict in ('pass','watch','conditional','fail','replace_now','warranty_claim')),
  replacement_cost_lakhs numeric(8,2) check (replacement_cost_lakhs is null or replacement_cost_lakhs >= 0),
  amc_covered boolean not null default false,
  engineer_id uuid references engineers(id) on delete set null,
  remediation_window_days integer not null check (remediation_window_days >= 0),
  capa_status text not null check (capa_status in ('not_started','in_progress','vendor_engaged','parts_ordered','remediated','escalated','closed_replaced')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists dr_detector_pixel_capa_events_r3132 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references dr_detector_panel_audits_r3132(id) on delete cascade,
  hospital_org_id uuid not null references organizations(id) on delete cascade,
  event_date date not null,
  event_type text not null check (event_type in ('initial_finding','vendor_dispatch','offset_calibration','gain_calibration','full_recal','firmware_update','part_swap','panel_replacement','warranty_filed','warranty_approved','warranty_denied','closure_signoff')),
  event_outcome text not null check (event_outcome in ('successful','partial','failed','pending','escalated','rejected')),
  defect_class text not null check (defect_class in ('isolated_pixel','dead_cluster','line_artifact','ghost_persistence','dqe_drift','uniformity_drift','flicker','no_signal','image_lag','tile_seam')),
  severity text not null check (severity in ('minor','moderate','major','critical','clinical_impact')),
  spend_rupees numeric(10,2) not null check (spend_rupees >= 0),
  downtime_hours numeric(6,2) not null check (downtime_hours >= 0),
  studies_lost integer not null check (studies_lost >= 0),
  revenue_loss_rupees numeric(10,2) not null check (revenue_loss_rupees >= 0),
  vendor_response_hours numeric(6,2),
  engineer_id uuid references engineers(id) on delete set null,
  resolved_by_user_id uuid references profiles(id) on delete set null,
  follow_up_required boolean not null default false,
  follow_up_due date,
  remarks text,
  created_at timestamptz not null default now()
);

create index if not exists idx_dr_audits_r3132_hospital on dr_detector_panel_audits_r3132(hospital_org_id);
create index if not exists idx_dr_audits_r3132_verdict on dr_detector_panel_audits_r3132(audit_verdict);
create index if not exists idx_dr_capa_r3132_audit on dr_detector_pixel_capa_events_r3132(audit_id);
create index if not exists idx_dr_capa_r3132_event_type on dr_detector_pixel_capa_events_r3132(event_type);

alter table dr_detector_panel_audits_r3132 enable row level security;
alter table dr_detector_pixel_capa_events_r3132 enable row level security;

-- Seed: 12 audits + 14 CAPA events
do $seed$
declare
  org_id uuid;
  eng_id uuid;
  prof_id uuid;
begin
  select id into org_id from organizations order by created_at asc limit 1;
  if org_id is null then
    raise notice 'No organizations row found; skipping seed.';
    return;
  end if;
  select id into eng_id from engineers order by created_at asc limit 1;
  select id into prof_id from profiles order by created_at asc limit 1;

  insert into dr_detector_panel_audits_r3132 (
    hospital_org_id, panel_serial, panel_make, panel_model, panel_type,
    installed_on, audit_date, modality, use_intensity, pixel_pitch_um,
    active_area_cm, total_dead_pixels, cluster_defects, line_defects,
    dqe_at_1lp_mm, dqe_at_2lp_mm, mtf_at_2lp_mm, limiting_resolution_lp_mm,
    ghost_image_severity, uniformity_pct, noise_floor_grade, calibration_status,
    audit_verdict, replacement_cost_lakhs, amc_covered, engineer_id,
    remediation_window_days, capa_status, notes
  ) values
    (org_id, 'CXDI-701C-A1881', 'Canon', 'CXDI-701C Wireless', 'wireless_csi',
     '2023-04-12', '2026-06-22', 'general_xr', 'very_high', 125.00,
     '43x43', 18, 2, 0, 0.620, 0.480, 0.560, 3.40,
     'trace', 96.40, 'good', 'current',
     'pass', null, true, eng_id,
     0, 'closed_replaced', 'Apollo Jubilee Hills - Trauma bay panel, healthy.'),
    (org_id, 'PIXIUM-3543EZ-K221', 'Trixell', 'Pixium 3543 EZ', 'a_si_csi',
     '2021-09-03', '2026-06-22', 'chest_xr', 'high', 148.00,
     '35x43', 124, 11, 1, 0.510, 0.380, 0.460, 2.80,
     'mild', 92.10, 'acceptable', 'due_30d',
     'watch', 14.50, true, eng_id,
     30, 'in_progress', 'KIMS Secunderabad - line artifact on row 1842, monitor closely.'),
    (org_id, 'CAREVIEW-FXRD-1417WC', 'Carestream', 'DRX-1 System', 'wireless_csi',
     '2020-11-18', '2026-06-23', 'portable_xr', '24x7_trauma', 139.00,
     '35x43', 412, 38, 4, 0.420, 0.290, 0.370, 2.50,
     'moderate', 88.30, 'marginal', 'overdue',
     'conditional', 18.20, false, eng_id,
     45, 'parts_ordered', 'Yashoda Hyderabad ICU - cluster defects expanding, replacement quoted.'),
    (org_id, 'CXDI-410C-B7702', 'Canon', 'CXDI-410C Compact', 'a_si_gos', 
     '2019-06-22', '2026-06-23', 'ortho_xr', 'medium', 160.00,
     '35x43', 891, 72, 9, 0.310, 0.180, 0.260, 1.90,
     'severe', 79.50, 'fail', 'full_recal_needed',
     'replace_now', 22.80, false, null,
     7, 'escalated', 'Continental Hospitals - severe ghost, DQE drift past spec, urgent replace.'),
    (org_id, 'PERKIN-XRD0822AP3', 'Perkin Elmer', 'XRD 0822 AP3', 'cmos_csi',
     '2024-02-10', '2026-06-24', 'fluoro', 'high', 99.50,
     '20x20', 6, 0, 0, 0.740, 0.610, 0.680, 4.20,
     'none', 98.20, 'excellent', 'current',
     'pass', null, true, eng_id,
     0, 'closed_replaced', 'Care Hospitals Banjara - cath lab fluoro panel, baseline.'),
    (org_id, 'RAYENCE-1717SCC', 'Rayence', '1717SCC', 'a_si_csi',
     '2022-07-30', '2026-06-24', 'general_xr', 'high', 140.00,
     '43x43', 67, 4, 0, 0.560, 0.430, 0.510, 3.10,
     'trace', 94.80, 'good', 'due_30d',
     'watch', 12.90, true, eng_id,
     21, 'vendor_engaged', 'Sunshine Secunderabad - calibration drift, vendor scheduled.'),
    (org_id, 'VARIAN-PAXSCAN-4343CB', 'Varex', 'PaxScan 4343CB', 'a_si_csi',
     '2018-03-15', '2026-06-25', 'chest_xr', 'very_high', 139.00,
     '43x43', 1842, 156, 22, 0.220, 0.090, 0.180, 1.40,
     'image_unusable', 64.20, 'fail', 'full_recal_needed',
     'fail', 28.50, false, null,
     0, 'escalated', 'Star Hospital Banjara - panel end-of-life, image unusable for diagnosis.'),
    (org_id, 'AGFA-DR-100E-9821', 'Agfa', 'DR 100e Mobile', 'wireless_csi',
     '2023-11-08', '2026-06-25', 'portable_xr', 'high', 139.00,
     '35x43', 32, 1, 0, 0.640, 0.495, 0.580, 3.50,
     'none', 96.90, 'good', 'current',
     'pass', null, true, eng_id,
     0, 'closed_replaced', 'St John''s Bangalore - mobile DR, performing per spec.'),
    (org_id, 'FUJI-FDR-D-EVO-III', 'Fujifilm', 'FDR D-EVO III G35i', 'igzo_csi',
     '2024-08-19', '2026-06-26', 'mammography_dr', 'medium', 50.00,
     '24x30', 4, 0, 0, 0.820, 0.690, 0.760, 7.10,
     'none', 99.10, 'excellent', 'current',
     'pass', null, true, eng_id,
     0, 'closed_replaced', 'Rainbow Childrens Hyd - mammo DR, premium IGZO, baseline.'),
    (org_id, 'KONICA-AERO-DR3-1417HD', 'Konica', 'AeroDR 3 1417HD', 'wireless_csi',
     '2022-01-25', '2026-06-26', 'general_xr', 'very_high', 175.00,
     '35x43', 218, 19, 2, 0.470, 0.330, 0.420, 2.60,
     'mild', 90.40, 'acceptable', 'offset_only',
     'conditional', 16.30, true, eng_id,
     30, 'parts_ordered', 'Krishna Institute Andhra - cluster growth at corner, AMC swap planned.'),
    (org_id, 'PIXIUM-FE3543RC-T009', 'Trixell', 'Pixium FE 3543 RC', 'a_si_csi',
     '2021-04-11', '2026-06-27', 'cath_lab', '24x7_trauma', 148.00,
     '35x43', 156, 13, 1, 0.490, 0.360, 0.430, 2.70,
     'moderate', 89.70, 'marginal', 'overdue',
     'warranty_claim', 24.10, true, eng_id,
     30, 'vendor_engaged', 'Asian Heart Visakhapatnam - cath lab panel, warranty claim in progress.'),
    (org_id, 'THALES-3543-EZ-DENTAL', 'Thales', 'Pixium 3543 EZ Dental', 'tethered_gos',
     '2020-09-04', '2026-06-27', 'dental_pano', 'low', 96.00,
     '15x20', 89, 6, 1, 0.530, 0.400, 0.480, 4.80,
     'mild', 91.80, 'acceptable', 'due_30d',
     'watch', 8.40, false, null,
     45, 'not_started', 'Clove Dental Banjara - pano DR, minor degradation, schedule recal.');

  insert into dr_detector_pixel_capa_events_r3132 (
    audit_id, hospital_org_id, event_date, event_type, event_outcome,
    defect_class, severity, spend_rupees, downtime_hours, studies_lost,
    revenue_loss_rupees, vendor_response_hours, engineer_id, resolved_by_user_id,
    follow_up_required, follow_up_due, remarks
  )
  select q.audit_id, org_id, q.event_date::date, q.event_type, q.event_outcome,
         q.defect_class, q.severity, q.spend_rupees, q.downtime_hours, q.studies_lost,
         q.revenue_loss_rupees, q.vendor_response_hours, eng_id, prof_id,
         q.follow_up_required, q.follow_up_due::date, q.remarks
  from (
    select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'PIXIUM-3543EZ-K221' limit 1) as audit_id,
           '2026-06-23' as event_date, 'initial_finding' as event_type, 'successful' as event_outcome,
           'line_artifact' as defect_class, 'moderate' as severity, 0.00::numeric as spend_rupees,
           2.50::numeric as downtime_hours, 8 as studies_lost, 12000.00::numeric as revenue_loss_rupees,
           null::numeric as vendor_response_hours, false as follow_up_required, '2026-07-23' as follow_up_due,
           'Row 1842 line artifact mapped, scheduled gain recal.' as remarks
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'PIXIUM-3543EZ-K221' limit 1),
           '2026-06-25', 'gain_calibration', 'successful', 'line_artifact', 'moderate', 8500.00,
           1.50, 0, 0.00, 14.00, false, '2026-07-25', 'Gain recal cleared the row artifact, monitor 30d.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'CAREVIEW-FXRD-1417WC' limit 1),
           '2026-06-23', 'initial_finding', 'successful', 'dead_cluster', 'major', 0.00,
           4.00, 18, 27000.00, null, true, '2026-07-15', 'Cluster defects at quadrant 3 - 38 clusters mapped.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'CAREVIEW-FXRD-1417WC' limit 1),
           '2026-06-26', 'vendor_dispatch', 'pending', 'dead_cluster', 'major', 0.00,
           0.00, 0, 0.00, 36.00, true, '2026-07-10', 'Carestream Pune dispatch scheduled for swap eval.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'CXDI-410C-B7702' limit 1),
           '2026-06-24', 'initial_finding', 'escalated', 'ghost_persistence', 'critical', 0.00,
           12.00, 42, 63000.00, null, true, '2026-07-01', 'Severe ghost image lag, panel pulled from clinical use.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'CXDI-410C-B7702' limit 1),
           '2026-06-26', 'panel_replacement', 'partial', 'ghost_persistence', 'critical', 1820000.00,
           48.00, 156, 234000.00, 72.00, true, '2026-07-15', 'Replacement panel ordered ex-Canon Singapore - lead time 2 weeks.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'RAYENCE-1717SCC' limit 1),
           '2026-06-24', 'offset_calibration', 'successful', 'uniformity_drift', 'minor', 4200.00,
           0.75, 0, 0.00, null, false, '2026-07-24', 'Offset calibration restored uniformity to 95.2 percent.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'VARIAN-PAXSCAN-4343CB' limit 1),
           '2026-06-25', 'initial_finding', 'failed', 'dqe_drift', 'clinical_impact', 0.00,
           24.00, 96, 144000.00, null, true, '2026-07-05', 'DQE collapse - panel no longer fit for clinical diagnosis.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'VARIAN-PAXSCAN-4343CB' limit 1),
           '2026-06-28', 'warranty_filed', 'rejected', 'dqe_drift', 'clinical_impact', 0.00,
           0.00, 0, 0.00, 96.00, true, '2026-07-20', 'Warranty denied - out of coverage, full replacement ₹28.5L quoted.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'KONICA-AERO-DR3-1417HD' limit 1),
           '2026-06-26', 'initial_finding', 'successful', 'dead_cluster', 'major', 0.00,
           1.50, 4, 6000.00, null, true, '2026-07-26', 'Corner cluster mapped, AMC swap initiated with Konica.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'KONICA-AERO-DR3-1417HD' limit 1),
           '2026-06-28', 'part_swap', 'pending', 'dead_cluster', 'major', 0.00,
           0.00, 0, 0.00, 48.00, true, '2026-07-15', 'AeroDR loaner unit arriving, swap window scheduled.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'PIXIUM-FE3543RC-T009' limit 1),
           '2026-06-27', 'warranty_filed', 'pending', 'image_lag', 'major', 0.00,
           6.00, 22, 33000.00, 24.00, true, '2026-07-12', 'Trixell warranty filed - cath lab panel, 30d response expected.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'THALES-3543-EZ-DENTAL' limit 1),
           '2026-06-27', 'initial_finding', 'successful', 'isolated_pixel', 'minor', 0.00,
           0.50, 2, 1800.00, null, false, '2026-08-27', 'Minor pixel defect growth, schedule offset recal next visit.'
    union all select (select id from dr_detector_panel_audits_r3132 where panel_serial = 'AGFA-DR-100E-9821' limit 1),
           '2026-06-25', 'closure_signoff', 'successful', 'isolated_pixel', 'minor', 2400.00,
           0.25, 0, 0.00, null, false, '2026-09-25', 'Mobile DR panel cleared - baseline DQE in spec.'
  ) q;
end;
$seed$;

-- =================================================================
-- RPCs (founder-gated, plpgsql, SECURITY DEFINER)
-- =================================================================

create or replace function dr_detector_audit_fleet_summary_r3132()
returns table (
  modality text,
  panel_count bigint,
  pass_count bigint,
  watch_count bigint,
  fail_or_replace bigint,
  avg_dead_pixels numeric,
  avg_dqe_2lp numeric,
  avg_mtf_2lp numeric,
  total_replacement_lakhs numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.modality::text,
           count(*)::bigint,
           count(*) filter (where a.audit_verdict = 'pass')::bigint,
           count(*) filter (where a.audit_verdict = 'watch')::bigint,
           count(*) filter (where a.audit_verdict in ('fail','replace_now','warranty_claim'))::bigint,
           round(avg(a.total_dead_pixels)::numeric, 1),
           round(avg(a.dqe_at_2lp_mm)::numeric, 3),
           round(avg(a.mtf_at_2lp_mm)::numeric, 3),
           coalesce(sum(a.replacement_cost_lakhs) filter (where a.audit_verdict in ('fail','replace_now','warranty_claim')), 0)::numeric
    from dr_detector_panel_audits_r3132 a
    group by a.modality
    order by panel_count desc, a.modality asc;
end;
$$;
revoke execute on function dr_detector_audit_fleet_summary_r3132() from public, anon;
grant execute on function dr_detector_audit_fleet_summary_r3132() to authenticated;

create or replace function dr_detector_pixel_defect_severity_map_r3132()
returns table (
  panel_serial text,
  panel_make text,
  modality text,
  total_dead_pixels integer,
  cluster_defects integer,
  line_defects integer,
  ghost_image_severity text,
  defect_score numeric,
  risk_band text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.panel_serial::text,
           a.panel_make::text,
           a.modality::text,
           a.total_dead_pixels,
           a.cluster_defects,
           a.line_defects,
           (a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50)::numeric as defect_score,
           case
             when a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50 >= 2000 then 'red'
             when a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50 >= 500 then 'amber'
             when a.total_dead_pixels + a.cluster_defects * 10 + a.line_defects * 50 >= 100 then 'yellow'
             else 'green'
           end::text as risk_band,
           a.ghost_image_severity::text
    from dr_detector_panel_audits_r3132 a
    order by defect_score desc;
end;
$$;
revoke execute on function dr_detector_pixel_defect_severity_map_r3132() from public, anon;
grant execute on function dr_detector_pixel_defect_severity_map_r3132() to authenticated;

create or replace function dr_detector_dqe_mtf_resolution_r3132()
returns table (
  panel_serial text,
  panel_model text,
  pixel_pitch_um numeric,
  dqe_at_1lp_mm numeric,
  dqe_at_2lp_mm numeric,
  mtf_at_2lp_mm numeric,
  limiting_resolution_lp_mm numeric,
  spec_compliance text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.panel_serial::text,
           a.panel_model::text,
           a.pixel_pitch_um,
           a.dqe_at_1lp_mm,
           a.dqe_at_2lp_mm,
           a.mtf_at_2lp_mm,
           a.limiting_resolution_lp_mm,
           case
             when a.dqe_at_2lp_mm >= 0.55 and a.mtf_at_2lp_mm >= 0.50 then 'within_spec'
             when a.dqe_at_2lp_mm >= 0.35 and a.mtf_at_2lp_mm >= 0.35 then 'borderline'
             when a.dqe_at_2lp_mm >= 0.20 then 'below_spec'
             else 'unfit_for_clinical'
           end::text as spec_compliance
    from dr_detector_panel_audits_r3132 a
    order by a.dqe_at_2lp_mm asc;
end;
$$;
revoke execute on function dr_detector_dqe_mtf_resolution_r3132() from public, anon;
grant execute on function dr_detector_dqe_mtf_resolution_r3132() to authenticated;

create or replace function dr_detector_ghost_image_audit_r3132()
returns table (
  ghost_image_severity text,
  panel_count bigint,
  modalities_affected bigint,
  avg_uniformity numeric,
  avg_age_years numeric,
  ghost_share_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  total_panels integer;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total_panels from dr_detector_panel_audits_r3132;
  return query
    select a.ghost_image_severity::text,
           count(*)::bigint,
           count(distinct a.modality)::bigint,
           round(avg(a.uniformity_pct)::numeric, 2),
           round(avg(extract(epoch from (a.audit_date - a.installed_on)) / (365.25 * 86400))::numeric, 2),
           round((count(*)::numeric * 100.0 / nullif(total_panels, 0))::numeric, 1)
    from dr_detector_panel_audits_r3132 a
    group by a.ghost_image_severity
    order by panel_count desc;
end;
$$;
revoke execute on function dr_detector_ghost_image_audit_r3132() from public, anon;
grant execute on function dr_detector_ghost_image_audit_r3132() to authenticated;

create or replace function dr_detector_replacement_cost_funnel_r3132()
returns table (
  audit_verdict text,
  panel_count bigint,
  amc_covered_count bigint,
  out_of_pocket_count bigint,
  total_replacement_lakhs numeric,
  avg_replacement_lakhs numeric,
  exposure_lakhs numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.audit_verdict::text,
           count(*)::bigint,
           count(*) filter (where a.amc_covered)::bigint,
           count(*) filter (where not a.amc_covered)::bigint,
           coalesce(sum(a.replacement_cost_lakhs), 0)::numeric,
           round(coalesce(avg(a.replacement_cost_lakhs), 0)::numeric, 2),
           coalesce(sum(a.replacement_cost_lakhs) filter (where not a.amc_covered), 0)::numeric
    from dr_detector_panel_audits_r3132 a
    group by a.audit_verdict
    order by total_replacement_lakhs desc;
end;
$$;
revoke execute on function dr_detector_replacement_cost_funnel_r3132() from public, anon;
grant execute on function dr_detector_replacement_cost_funnel_r3132() to authenticated;

create or replace function dr_detector_capa_event_rollup_r3132()
returns table (
  event_type text,
  event_count bigint,
  successful_count bigint,
  failed_or_rejected bigint,
  total_spend_rupees numeric,
  total_downtime_hours numeric,
  total_revenue_loss numeric,
  avg_vendor_response_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.event_type::text,
           count(*)::bigint,
           count(*) filter (where e.event_outcome = 'successful')::bigint,
           count(*) filter (where e.event_outcome in ('failed','rejected'))::bigint,
           coalesce(sum(e.spend_rupees), 0)::numeric,
           coalesce(sum(e.downtime_hours), 0)::numeric,
           coalesce(sum(e.revenue_loss_rupees), 0)::numeric,
           round(coalesce(avg(e.vendor_response_hours), 0)::numeric, 1)
    from dr_detector_pixel_capa_events_r3132 e
    group by e.event_type
    order by event_count desc;
end;
$$;
revoke execute on function dr_detector_capa_event_rollup_r3132() from public, anon;
grant execute on function dr_detector_capa_event_rollup_r3132() to authenticated;

create or replace function dr_detector_defect_class_severity_r3132()
returns table (
  defect_class text,
  severity text,
  event_count bigint,
  total_studies_lost bigint,
  total_revenue_loss numeric,
  avg_downtime_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.defect_class::text,
           e.severity::text,
           count(*)::bigint,
           coalesce(sum(e.studies_lost), 0)::bigint,
           coalesce(sum(e.revenue_loss_rupees), 0)::numeric,
           round(coalesce(avg(e.downtime_hours), 0)::numeric, 2)
    from dr_detector_pixel_capa_events_r3132 e
    group by e.defect_class, e.severity
    order by total_revenue_loss desc, event_count desc;
end;
$$;
revoke execute on function dr_detector_defect_class_severity_r3132() from public, anon;
grant execute on function dr_detector_defect_class_severity_r3132() to authenticated;

create or replace function dr_detector_calibration_capa_status_r3132()
returns table (
  calibration_status text,
  capa_status text,
  panel_count bigint,
  total_dead_pixels_sum bigint,
  total_remediation_window_days bigint,
  exposure_lakhs numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select a.calibration_status::text,
           a.capa_status::text,
           count(*)::bigint,
           coalesce(sum(a.total_dead_pixels), 0)::bigint,
           coalesce(sum(a.remediation_window_days), 0)::bigint,
           coalesce(sum(a.replacement_cost_lakhs), 0)::numeric
    from dr_detector_panel_audits_r3132 a
    group by a.calibration_status, a.capa_status
    order by panel_count desc, a.calibration_status asc;
end;
$$;
revoke execute on function dr_detector_calibration_capa_status_r3132() from public, anon;
grant execute on function dr_detector_calibration_capa_status_r3132() to authenticated;
