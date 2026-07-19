-- Round 3338: Customer Hospital Surgical-Navigation & Intraoperative-Imaging QC Audit
-- Surgical-nav QA — device type × registration accuracy (TRE) × tracker camera × reference array × image-to-patient sync × radiation output × calibration phantom × instrument cal × foot-pedal interlock × software/cal currency × CAPA

-- =============================================================================
-- TABLE 1: surgnav_imaging_r3338 — per-device surgical-navigation / intraop-imaging QC checks
-- =============================================================================
create table if not exists public.surgnav_imaging_r3338 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'neuronavigation','spine_navigation','o_arm_3d','intraop_cbct','optical_tracker','em_tracker'
  )),
  department text not null,
  check_date date not null,
  check_started_at timestamptz not null,
  registration_accuracy_mm numeric(5,2),
  tracker_camera_ok boolean not null,
  reference_array_condition text not null check (reference_array_condition in (
    'good','worn','damaged','replace_due'
  )),
  image_to_patient_sync_ok boolean not null,
  radiation_output_ok text not null check (radiation_output_ok in (
    'ok','high','not_applicable'
  )),
  calibration_phantom_pass boolean not null,
  instrument_calibration_ok boolean not null,
  foot_pedal_interlock_ok boolean not null,
  software_version_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.surgnav_imaging_r3338 enable row level security;

create index if not exists idx_surgnav_imaging_r3338_org on public.surgnav_imaging_r3338(organization_id);
create index if not exists idx_surgnav_imaging_r3338_date on public.surgnav_imaging_r3338(check_date);
create index if not exists idx_surgnav_imaging_r3338_verdict on public.surgnav_imaging_r3338(qc_verdict);

-- =============================================================================
-- TABLE 2: surgnav_imaging_capa_actions_r3338 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.surgnav_imaging_capa_actions_r3338 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.surgnav_imaging_r3338(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'registration_accuracy_deviation','tracker_camera_fault','reference_array_damage','image_patient_sync_failure',
    'radiation_output_high','calibration_phantom_failure','instrument_calibration_error','foot_pedal_interlock_failure',
    'software_version_outdated','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reference_array_worn','tracker_camera_misaligned','optical_marker_degraded','em_field_interference',
    'phantom_calibration_drift','instrument_bent','foot_pedal_switch_fault','software_not_updated',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_reference_array','realign_tracker_camera','replace_optical_markers','mitigate_em_interference',
    'recalibrate_with_phantom','replace_instrument','replace_foot_pedal','update_software',
    'retrain_or_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','aerb_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.surgnav_imaging_capa_actions_r3338 enable row level security;

create index if not exists idx_surgnav_capa_r3338_log on public.surgnav_imaging_capa_actions_r3338(qc_log_id);
create index if not exists idx_surgnav_capa_r3338_status on public.surgnav_imaging_capa_actions_r3338(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 QC check rows
  insert into public.surgnav_imaging_r3338 (
    organization_id, hospital_name, device_code, device_type, department,
    check_date, check_started_at,
    registration_accuracy_mm, tracker_camera_ok, reference_array_condition,
    image_to_patient_sync_ok, radiation_output_ok, calibration_phantom_pass,
    instrument_calibration_ok, foot_pedal_interlock_ok, software_version_current,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept,
    q.cdate::date, q.cstart::timestamptz,
    q.regmm, q.tcam, q.refc,
    q.sync, q.rad, q.phantom,
    q.instcal, q.pedal, q.swcur,
    q.calcur, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','NAV-APL-N01','neuronavigation','Neurosurgery','2026-07-03','2026-07-03 07:20:00+05:30',
     0.70,true,'good',true,'not_applicable',true,true,true,true,true,'pass','Brainlab Curve navigation — quarterly QC nominal'),
    ('Apollo Chennai Greams Road','NAV-APL-O01','o_arm_3d','Spine OR','2026-07-03','2026-07-03 09:05:00+05:30',
     1.10,true,'good',true,'ok',true,true,true,true,true,'pass','Medtronic O-arm — 3D spin dose within baseline'),
    ('Fortis Gurgaon','NAV-FRT-S01','spine_navigation','Orthopaedics','2026-07-02','2026-07-02 08:10:00+05:30',
     1.90,true,'worn',true,'ok',true,false,true,true,true,'conditional_pass','NuVasive Pulse — TRE 1.9mm near limit, reference array worn, instrument cal off'),
    ('Fortis Gurgaon','NAV-FRT-C01','intraop_cbct','Neuro OR','2026-07-02','2026-07-02 10:30:00+05:30',
     1.20,true,'good',true,'high',true,true,true,false,true,'conditional_pass','Ziehm CBCT — dose above reference, AERB review, software update pending'),
    ('Manipal Bengaluru Old Airport Road','NAV-MNP-N01','neuronavigation','Neurosurgery','2026-07-01','2026-07-01 07:45:00+05:30',
     2.40,true,'damaged',false,'not_applicable',false,true,true,true,false,'fail','Medtronic StealthStation — TRE 2.4mm, damaged array, phantom fail, cal overdue'),
    ('Manipal Bengaluru Old Airport Road','NAV-MNP-E01','em_tracker','ENT','2026-07-01','2026-07-01 09:15:00+05:30',
     1.50,true,'good',true,'not_applicable',true,true,true,true,true,'pass','NDI Aurora EM tracker — ENT fusion nav, field map clean'),
    ('AIIMS Delhi Ansari Nagar','NAV-AIM-O01','o_arm_3d','Spine OR','2026-06-30','2026-06-30 06:50:00+05:30',
     3.10,false,'worn',false,'high',false,false,false,false,false,'removed_from_service','Medtronic O-arm — camera tracking loss, high dose, multiple fails, pulled'),
    ('AIIMS Delhi Ansari Nagar','NAV-AIM-N01','neuronavigation','Neurosurgery','2026-06-30','2026-06-30 08:20:00+05:30',
     0.90,true,'good',true,'not_applicable',true,true,true,true,true,'pass','Brainlab Kick — annual QC clean pass'),
    ('CMC Vellore','NAV-CMC-S01','spine_navigation','Orthopaedics','2026-06-29','2026-06-29 07:35:00+05:30',
     1.30,true,'good',true,'ok',true,true,false,true,true,'conditional_pass','Stryker spine nav — foot-pedal interlock intermittent on retest'),
    ('CMC Vellore','NAV-CMC-C01','intraop_cbct','Hybrid OR','2026-06-29','2026-06-29 09:40:00+05:30',
     1.00,true,'good',true,'ok',true,true,true,true,true,'pass','Siemens Cios Spin — 3D intraop imaging QC pass'),
    ('KIMS Hyderabad','NAV-KIM-P01','optical_tracker','Neurosurgery','2026-06-28','2026-06-28 07:10:00+05:30',
     2.20,false,'replace_due',true,'not_applicable',false,true,true,true,true,'fail','NDI Polaris optical — camera fault, marker array replace-due, phantom fail'),
    ('KIMS Hyderabad','NAV-KIM-N01','neuronavigation','Neurosurgery','2026-06-28','2026-06-28 09:00:00+05:30',
     1.00,true,'good',true,'not_applicable',true,true,true,false,true,'conditional_pass','StealthStation — software one version behind, update scheduled'),
    ('NIMHANS Bengaluru','NAV-NIM-N01','neuronavigation','Neurosurgery','2026-06-27','2026-06-27 06:40:00+05:30',
     null,false,'damaged',false,'not_applicable',false,false,true,true,false,'removed_from_service','QC aborted — tracker camera dead on power-up, unit withdrawn'),
    ('Medanta Gurugram','NAV-MDT-C01','intraop_cbct','Hybrid OR','2026-06-27','2026-06-27 08:55:00+05:30',
     1.20,true,'good',true,'ok',true,true,true,true,true,'pass','Ziehm Vision RFD 3D — post-AMC verification pass')
  ) as q(hosp, dcode, dtype, dept, cdate, cstart, regmm, tcam, refc, sync, rad, phantom, instcal, pedal, swcur, calcur, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.surgnav_imaging_capa_actions_r3338 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NAV-FRT-S01','reference_array_damage','reference_array_worn','replace_reference_array','overdue','nabh_finding','2026-06-30',null,22000.00,'Reference array replacement past target date — NuVasive vendor delay'),
    ('NAV-FRT-C01','radiation_output_high','software_not_updated','update_software','escalated','aerb_notifiable','2026-07-06',null,15000.00,'Dose above reference — AERB review, dose-cal plus software update'),
    ('NAV-MNP-N01','calibration_phantom_failure','phantom_calibration_drift','recalibrate_with_phantom','open','patient_safety_alert','2026-07-10',null,28000.00,'Phantom QC fail plus damaged array — StealthStation cal overdue'),
    ('NAV-AIM-O01','tracker_camera_fault','tracker_camera_misaligned','realign_tracker_camera','escalated','aerb_notifiable','2026-07-05',null,90000.00,'O-arm camera tracking loss plus high dose — OEM service escalated'),
    ('NAV-KIM-P01','reference_array_damage','optical_marker_degraded','replace_optical_markers','open','nabh_finding','2026-07-09',null,40000.00,'Polaris marker array replace-due plus phantom fail — kit on order from NDI'),
    ('NAV-CMC-S01','foot_pedal_interlock_failure','foot_pedal_switch_fault','replace_foot_pedal','verification_pending','internal_only','2026-07-04',null,6000.00,'Foot-pedal interlock switch replaced — verify on next case day'),
    ('NAV-NIM-N01','tracker_camera_fault','tracker_camera_misaligned','remove_from_service','closed','iso_13485_deviation','2026-07-01','2026-06-27',0.00,'Camera dead on power-up — removed from service, OEM RMA raised')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.surgnav_imaging_r3338 e
    on e.organization_id = v_org_id and e.device_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3338_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.surgnav_imaging_r3338)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.surgnav_imaging_r3338 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3338_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3338_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3338_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  camera_fault bigint,
  array_issue bigint,
  phantom_fail bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.tracker_camera_ok = false)::bigint,
    count(*) filter (where l.reference_array_condition in ('worn','damaged','replace_due'))::bigint,
    count(*) filter (where l.calibration_phantom_pass = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.surgnav_imaging_r3338 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3338_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3338_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3338_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_registration_mm numeric, array_issues bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.registration_accuracy_mm), 2),
    count(*) filter (where l.reference_array_condition in ('worn','damaged','replace_due'))::bigint
  from public.surgnav_imaging_r3338 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3338_device_department_matrix() from public, anon;
grant execute on function public.founder_r3338_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3338_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, camera_fault bigint, phantom_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.tracker_camera_ok = false)::bigint,
    count(*) filter (where l.calibration_phantom_pass = false)::bigint
  from public.surgnav_imaging_r3338 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3338_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3338_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3338_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.surgnav_imaging_capa_actions_r3338 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3338_capa_status_board() from public, anon;
grant execute on function public.founder_r3338_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3338_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.surgnav_imaging_capa_actions_r3338)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.surgnav_imaging_capa_actions_r3338 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3338_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3338_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3338_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.surgnav_imaging_capa_actions_r3338 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3338_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3338_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3338_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  registration_accuracy_mm numeric,
  reference_array_condition text,
  radiation_output_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.registration_accuracy_mm, l.reference_array_condition,
    l.radiation_output_ok, l.notes
  from public.surgnav_imaging_r3338 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.tracker_camera_ok = false
     or l.image_to_patient_sync_ok = false
     or l.reference_array_condition in ('damaged','replace_due')
     or l.calibration_phantom_pass = false
     or l.radiation_output_ok = 'high'
     or l.instrument_calibration_ok = false
     or l.foot_pedal_interlock_ok = false
     or l.registration_accuracy_mm > 1.80
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3338_high_risk_queue() from public, anon;
grant execute on function public.founder_r3338_high_risk_queue() to authenticated;
