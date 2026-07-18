-- Round 3251: Customer Hospital Fundus-Camera & OCT Imaging-Quality QC Audit
-- Ophthalmic imaging QA — device type × model-eye image grade × illumination uniformity × OCT signal strength × artifacts × focus cal × fixation target × DICOM export × patient backlog × CAPA

-- =============================================================================
-- TABLE 1: fundus_oct_imaging_r3251 — individual fundus/OCT image-quality checks
-- =============================================================================
create table if not exists public.fundus_oct_imaging_r3251 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'fundus_camera','oct_spectral_domain','oct_swept_source','fundus_fluorescein_angio','retinal_camera_portable'
  )),
  check_date date not null,
  test_eye_image_grade text not null check (test_eye_image_grade in (
    'excellent','acceptable','degraded','unusable'
  )),
  illumination_uniformity_ok boolean not null,
  oct_signal_strength int check (oct_signal_strength between 1 and 10),
  artifact_present text not null check (artifact_present in (
    'none','dust_spots','streaks','vignetting'
  )),
  focus_calibration_ok boolean not null,
  fixation_target_ok boolean not null,
  image_export_dicom_ok text not null check (image_export_dicom_ok in (
    'ok','failing','not_configured'
  )),
  patient_backlog_affected int not null default 0,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fundus_oct_imaging_r3251 enable row level security;

create index if not exists idx_fundus_oct_r3251_org on public.fundus_oct_imaging_r3251(organization_id);
create index if not exists idx_fundus_oct_r3251_date on public.fundus_oct_imaging_r3251(check_date);
create index if not exists idx_fundus_oct_r3251_verdict on public.fundus_oct_imaging_r3251(qc_verdict);

-- =============================================================================
-- TABLE 2: fundus_oct_imaging_capa_actions_r3251 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.fundus_oct_imaging_capa_actions_r3251 (
  id uuid primary key default gen_random_uuid(),
  qc_check_id uuid not null references public.fundus_oct_imaging_r3251(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_quality_degradation','oct_signal_loss','artifact_contamination','focus_calibration_drift',
    'fixation_target_failure','dicom_export_failure','illumination_nonuniformity','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sld_light_source_aging','galvo_scanner_misalignment','sensor_window_dust','illumination_lamp_aging',
    'fixation_led_failure','dicom_node_misconfigured','reference_arm_misalignment','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_sld_source','realign_galvo_scanner','clean_sensor_optics','replace_illumination_lamp',
    'replace_fixation_led','reconfigure_dicom_node','realign_reference_arm','retrain_imaging_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fundus_oct_imaging_capa_actions_r3251 enable row level security;

create index if not exists idx_fundus_oct_capa_r3251_check on public.fundus_oct_imaging_capa_actions_r3251(qc_check_id);
create index if not exists idx_fundus_oct_capa_r3251_status on public.fundus_oct_imaging_capa_actions_r3251(capa_status);

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

  -- 14 image-quality check rows
  insert into public.fundus_oct_imaging_r3251 (
    organization_id, hospital_name, device_code, device_type, check_date,
    test_eye_image_grade, illumination_uniformity_ok, oct_signal_strength,
    artifact_present, focus_calibration_ok, fixation_target_ok,
    image_export_dicom_ok, patient_backlog_affected, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dev, q.dt, q.cd::date,
    q.grade, q.illum, q.sig::int,
    q.art, q.foc, q.fix,
    q.dicom, q.backlog::int, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','FND-APL-101','fundus_camera','2026-07-05',
     'excellent',true,null,'none',true,true,'ok',0,'pass','Quarterly QC — model-eye phantom images crisp, all fields clean'),
    ('Apollo Chennai Greams Road','OCT-APL-102','oct_spectral_domain','2026-07-05',
     'acceptable',true,7,'none',true,true,'ok',0,'pass','Signal 7/10 on phantom — stable vs last quarter'),
    ('Fortis Gurgaon Sector 44','OCT-FRT-201','oct_swept_source','2026-07-04',
     'degraded',true,4,'streaks',true,false,'ok',12,'fail','Signal 4/10 with streak artifacts — galvo scanner misalignment suspected by Er. Ramesh Iyer'),
    ('Fortis Gurgaon Sector 44','FND-FRT-202','fundus_fluorescein_angio','2026-07-04',
     'acceptable',false,null,'vignetting',true,true,'ok',3,'conditional_pass','Corner vignetting on angio frames — illumination lamp aging, replacement quoted'),
    ('Manipal Bengaluru Old Airport Road','FND-MNP-301','fundus_camera','2026-07-03',
     'degraded',true,null,'dust_spots',false,true,'ok',5,'conditional_pass','Dust on sensor window plus focus calibration drift — cleaning kit awaited'),
    ('Manipal Bengaluru Old Airport Road','OCT-MNP-302','oct_spectral_domain','2026-07-03',
     'excellent',true,9,'none',true,true,'ok',0,'pass','Signal 9/10 — post-PM verification by Er. Kavitha Nair'),
    ('AIIMS Delhi RP Centre','OCT-AIM-401','oct_spectral_domain','2026-07-02',
     'unusable',false,2,'streaks',false,false,'failing',28,'removed_from_service','SLD light source failing — 28 OCT studies rebooked to backup scanner'),
    ('AIIMS Delhi RP Centre','FND-AIM-402','retinal_camera_portable','2026-07-02',
     'acceptable',true,null,'none',true,true,'not_configured',6,'conditional_pass','Portable camera exports to USB only — DICOM node never configured'),
    ('CMC Vellore Schell Eye Hospital','OCT-CMC-501','oct_swept_source','2026-07-01',
     'excellent',true,10,'none',true,true,'ok',0,'pass','Signal 10/10 — reference arm freshly aligned'),
    ('CMC Vellore Schell Eye Hospital','FND-CMC-502','fundus_camera','2026-07-01',
     'acceptable',true,null,'dust_spots',true,true,'ok',1,'pass','Single dust spot outside macula field — cleaned on the spot by Er. Suresh Babu'),
    ('KIMS Hyderabad Secunderabad','OCT-KIM-601','oct_spectral_domain','2026-06-30',
     'degraded',true,5,'none',true,true,'failing',15,'fail','DICOM export queue stuck — 15 studies not reaching PACS'),
    ('KIMS Hyderabad Secunderabad','FND-KIM-602','fundus_fluorescein_angio','2026-06-30',
     'acceptable',true,null,'none',true,false,'ok',2,'conditional_pass','Fixation target LED intermittent — patients drifting off-axis'),
    ('Sankara Nethralaya Chennai','FND-SNK-701','fundus_camera','2026-06-29',
     'excellent',true,null,'none',true,true,'ok',0,'pass','Post-AMC verification pass — imaged by Er. Priya Venkatesh'),
    ('LV Prasad Eye Institute Hyderabad','OCT-LVP-801','oct_swept_source','2026-06-29',
     'unusable',true,3,'vignetting',false,true,'ok',19,'removed_from_service','Reference arm misalignment — swept-source pulled, OEM service call raised')
  ) as q(hosp, dev, dt, cd, grade, illum, sig, art, foc, fix, dicom, backlog, qv, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.fundus_oct_imaging_capa_actions_r3251 (
    qc_check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('OCT-FRT-201','oct_signal_loss','galvo_scanner_misalignment','realign_galvo_scanner','in_progress','internal_only','2026-07-10',null,55000.00,'OEM engineer visit booked — galvo realignment plus signal re-verify'),
    ('FND-FRT-202','illumination_nonuniformity','illumination_lamp_aging','replace_illumination_lamp','open','internal_only','2026-07-12',null,18000.00,'Xenon lamp on order — vignetting to re-test after fit'),
    ('OCT-AIM-401','oct_signal_loss','sld_light_source_aging','replace_sld_source','escalated','patient_safety_alert','2026-07-08',null,240000.00,'SLD module quote approved — 28 delayed studies rebooked to backup'),
    ('FND-AIM-402','dicom_export_failure','dicom_node_misconfigured','reconfigure_dicom_node','verification_pending','internal_only','2026-07-06',null,0.00,'PACS AE title added — verify export on next retina clinic day'),
    ('OCT-KIM-601','dicom_export_failure','dicom_node_misconfigured','reconfigure_dicom_node','closed','nabh_finding','2026-07-03','2026-07-02',6500.00,'Export queue flushed and node remapped — all 15 studies pushed to PACS'),
    ('FND-MNP-301','focus_calibration_drift','sensor_window_dust','clean_sensor_optics','overdue','internal_only','2026-06-28',null,4000.00,'Cleaning kit awaited from vendor — past target closure date'),
    ('OCT-LVP-801','image_quality_degradation','reference_arm_misalignment','realign_reference_arm','open','cdsco_notifiable','2026-07-15',null,180000.00,'Swept-source removed from service — OEM reference-arm realignment scheduled')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.fundus_oct_imaging_r3251 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3251_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fundus_oct_imaging_r3251)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fundus_oct_imaging_r3251 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3251_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3251_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level imaging QC scorecard
create or replace function public.founder_r3251_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  artifact_flags bigint,
  dicom_issues bigint,
  backlog_studies bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.artifact_present <> 'none')::bigint,
    count(*) filter (where l.image_export_dicom_ok in ('failing','not_configured'))::bigint,
    coalesce(sum(l.patient_backlog_affected),0)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.fundus_oct_imaging_r3251 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3251_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3251_hospital_scorecard() to authenticated;

-- 3) Device type × image grade matrix
create or replace function public.founder_r3251_device_grade_matrix()
returns table(device_type text, test_eye_image_grade text, checks bigint, passed bigint, avg_oct_signal numeric, backlog_studies bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.test_eye_image_grade, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.oct_signal_strength)::numeric, 1),
    coalesce(sum(l.patient_backlog_affected),0)::bigint
  from public.fundus_oct_imaging_r3251 l
  group by l.device_type, l.test_eye_image_grade
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3251_device_grade_matrix() from public, anon;
grant execute on function public.founder_r3251_device_grade_matrix() to authenticated;

-- 4) Daily check trend
create or replace function public.founder_r3251_daily_check_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, artifact_flags bigint, dicom_issues bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.artifact_present <> 'none')::bigint,
    count(*) filter (where l.image_export_dicom_ok in ('failing','not_configured'))::bigint
  from public.fundus_oct_imaging_r3251 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3251_daily_check_trend() from public, anon;
grant execute on function public.founder_r3251_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3251_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.fundus_oct_imaging_capa_actions_r3251 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3251_capa_status_board() from public, anon;
grant execute on function public.founder_r3251_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3251_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fundus_oct_imaging_capa_actions_r3251)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fundus_oct_imaging_capa_actions_r3251 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3251_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3251_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3251_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.fundus_oct_imaging_capa_actions_r3251 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3251_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3251_regulatory_impact_digest() to authenticated;

-- 8) High-risk imaging queue (top individual concerns)
create or replace function public.founder_r3251_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  test_eye_image_grade text,
  artifact_present text,
  image_export_dicom_ok text,
  qc_verdict text,
  patient_backlog_affected int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.test_eye_image_grade, l.artifact_present, l.image_export_dicom_ok,
    l.qc_verdict, l.patient_backlog_affected, l.notes
  from public.fundus_oct_imaging_r3251 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.test_eye_image_grade in ('degraded','unusable')
     or l.artifact_present <> 'none'
     or l.image_export_dicom_ok in ('failing','not_configured')
     or l.oct_signal_strength <= 5
     or not l.illumination_uniformity_ok
     or not l.focus_calibration_ok
     or not l.fixation_target_ok
  order by l.patient_backlog_affected desc, l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3251_high_risk_queue() from public, anon;
grant execute on function public.founder_r3251_high_risk_queue() to authenticated;
