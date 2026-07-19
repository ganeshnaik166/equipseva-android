-- Round 3346: Customer Hospital Dental Imaging & CAD-CAM Equipment QC Audit
-- Dental QA — device type × image resolution × radiation output × sensor/scanner/milling/implant-motor accuracy × lead-apron × infection-control × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: dental_imaging_qc_r3346 — per-device dental imaging & CAD-CAM QC checks
-- =============================================================================
create table if not exists public.dental_imaging_qc_r3346 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'opg_panoramic','dental_cbct','rvg_intraoral_sensor','intraoral_scanner',
    'cadcam_milling','implant_motor','dental_xray_wall'
  )),
  clinic text not null,
  check_date date not null,
  check_started_at timestamptz not null,
  image_resolution_ok boolean not null,
  radiation_output_error_pct numeric(5,2),
  sensor_calibration_ok boolean not null,
  scanner_accuracy_ok text not null check (scanner_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  milling_precision_ok text not null check (milling_precision_ok in (
    'ok','worn_tool','fail','not_applicable'
  )),
  implant_motor_torque_accuracy_ok text not null check (implant_motor_torque_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  lead_apron_available boolean not null,
  infection_control_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_imaging_qc_r3346 enable row level security;

create index if not exists idx_dental_imaging_qc_r3346_org on public.dental_imaging_qc_r3346(organization_id);
create index if not exists idx_dental_imaging_qc_r3346_date on public.dental_imaging_qc_r3346(check_date);
create index if not exists idx_dental_imaging_qc_r3346_verdict on public.dental_imaging_qc_r3346(qc_verdict);

-- =============================================================================
-- TABLE 2: dental_imaging_qc_capa_actions_r3346 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dental_imaging_qc_capa_actions_r3346 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.dental_imaging_qc_r3346(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'radiation_output_deviation','image_resolution_fail','sensor_calibration_fail',
    'scanner_accuracy_drift','milling_precision_fail','implant_motor_torque_fail',
    'lead_apron_missing','infection_control_lapse','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'xray_tube_aging','detector_degradation','sensor_calibration_drift','scanner_optics_dirty',
    'milling_tool_worn','motor_gearbox_wear','missing_ppe_stock','cleaning_protocol_gap',
    'software_config_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_xray_output','replace_detector','recalibrate_sensor','clean_scanner_optics',
    'replace_milling_tool','service_implant_motor','procure_lead_aprons','retrain_infection_control',
    'update_software_config','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_finding','nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_imaging_qc_capa_actions_r3346 enable row level security;

create index if not exists idx_dental_capa_r3346_log on public.dental_imaging_qc_capa_actions_r3346(qc_log_id);
create index if not exists idx_dental_capa_r3346_status on public.dental_imaging_qc_capa_actions_r3346(capa_status);

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

  -- 14 dental imaging / CAD-CAM QC rows
  insert into public.dental_imaging_qc_r3346 (
    organization_id, hospital_name, device_code, device_type, clinic,
    check_date, check_started_at, image_resolution_ok, radiation_output_error_pct,
    sensor_calibration_ok, scanner_accuracy_ok, milling_precision_ok,
    implant_motor_torque_accuracy_ok, lead_apron_available, infection_control_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.clinic,
    q.cd::date, q.cs::timestamptz, q.ires, q.rerr,
    q.scal, q.sacc, q.mprec,
    q.itor, q.apron, q.infc,
    q.calc, q.qv, q.nt
  from (values
    ('Apollo Hospitals Greams Road Chennai','DNT-APL-OPG-01','opg_panoramic','Dental Radiology',
     '2026-07-03','2026-07-03 08:10:00+05:30',true,2.10,
     true,'not_applicable','not_applicable',
     'not_applicable',true,true,
     true,'pass','Quarterly OPG QC — radiation output within 5%, resolution nominal'),
    ('Apollo Hospitals Greams Road Chennai','DNT-APL-CBCT-02','dental_cbct','Maxillofacial Imaging',
     '2026-07-03','2026-07-03 09:05:00+05:30',true,8.40,
     true,'not_applicable','not_applicable',
     'not_applicable',true,true,
     true,'conditional_pass','CBCT dose output error 8.4% over 5% tolerance — recheck booked'),
    ('Fortis Memorial Gurgaon','DNT-FRT-RVG-03','rvg_intraoral_sensor','Conservative Dentistry',
     '2026-07-02','2026-07-02 07:40:00+05:30',false,4.20,
     false,'not_applicable','not_applicable',
     'not_applicable',true,true,
     false,'fail','RVG sensor calibration failed and images noisy — sensor pulled from service'),
    ('Fortis Memorial Gurgaon','DNT-FRT-IOS-04','intraoral_scanner','Prosthodontics',
     '2026-07-02','2026-07-02 08:30:00+05:30',true,null,
     true,'drift','not_applicable',
     'not_applicable',true,true,
     true,'conditional_pass','Scanner accuracy drift on 20um ball-bar test — recalibration due'),
    ('Manipal Hospital Old Airport Road Bengaluru','DNT-MNP-MILL-05','cadcam_milling','Dental CAD-CAM Lab',
     '2026-07-01','2026-07-01 10:15:00+05:30',true,null,
     true,'not_applicable','worn_tool',
     'not_applicable',true,true,
     true,'conditional_pass','Milling burr worn — crown margins within tol but tool change due'),
    ('Manipal Hospital Old Airport Road Bengaluru','DNT-MNP-IMP-06','implant_motor','Oral Implantology',
     '2026-07-01','2026-07-01 11:00:00+05:30',true,null,
     true,'not_applicable','not_applicable',
     'drift',true,true,
     true,'conditional_pass','Implant motor torque 8% low at 35 Ncm setting — calibration due'),
    ('AIIMS New Delhi Ansari Nagar','DNT-AIM-XRW-07','dental_xray_wall','OPD Dental Radiology',
     '2026-06-30','2026-06-30 09:20:00+05:30',true,11.60,
     true,'not_applicable','not_applicable',
     'not_applicable',false,true,
     false,'removed_from_service','Wall X-ray output 11.6% high and no lead apron at bay — unit locked out'),
    ('AIIMS New Delhi Ansari Nagar','DNT-AIM-OPG-08','opg_panoramic','OPD Dental Radiology',
     '2026-06-30','2026-06-30 10:05:00+05:30',true,1.80,
     true,'not_applicable','not_applicable',
     'not_applicable',true,true,
     true,'pass','Annual OPG QC clean pass'),
    ('CMC Vellore','DNT-CMC-CBCT-09','dental_cbct','Oral Medicine and Radiology',
     '2026-06-29','2026-06-29 08:15:00+05:30',false,3.10,
     true,'not_applicable','not_applicable',
     'not_applicable',true,false,
     true,'fail','CBCT bite-block reprocessing lapse and resolution below spec'),
    ('CMC Vellore','DNT-CMC-IOS-10','intraoral_scanner','Prosthodontics',
     '2026-06-29','2026-06-29 09:10:00+05:30',true,null,
     true,'ok','not_applicable',
     'not_applicable',true,true,
     true,'pass','Scanner accuracy within 15um — clean pass'),
    ('KIMS Hyderabad Secunderabad','DNT-KIM-RVG-11','rvg_intraoral_sensor','Endodontics',
     '2026-06-28','2026-06-28 07:55:00+05:30',true,2.60,
     true,'not_applicable','not_applicable',
     'not_applicable',true,true,
     true,'pass','RVG QC pass — sensor calibration verified'),
    ('KIMS Hyderabad Secunderabad','DNT-KIM-MILL-12','cadcam_milling','Dental CAD-CAM Lab',
     '2026-06-28','2026-06-28 08:45:00+05:30',true,null,
     true,'not_applicable','fail',
     'not_applicable',true,true,
     false,'fail','Milling precision fail — crown margins out of tolerance, service booked'),
    ('Ruby Hall Clinic Pune','DNT-RBY-IMP-13','implant_motor','Oral and Maxillofacial Surgery',
     '2026-06-27','2026-06-27 10:30:00+05:30',true,null,
     true,'not_applicable','not_applicable',
     'ok',true,true,
     true,'pass','Implant motor torque within 3% across range — pass'),
    ('Ruby Hall Clinic Pune','DNT-RBY-IOS-14','intraoral_scanner','Prosthodontics',
     '2026-06-27','2026-06-27 11:20:00+05:30',false,null,
     false,'fail','not_applicable',
     'not_applicable',true,false,
     false,'removed_from_service','Scanner accuracy fail and calibration expired — removed pending OEM service')
  ) as q(hosp, dcode, dtype, clinic, cd, cs, ires, rerr, scal, sacc, mprec, itor, apron, infc, calc, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.dental_imaging_qc_capa_actions_r3346 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DNT-FRT-RVG-03','sensor_calibration_fail','sensor_calibration_drift','recalibrate_sensor','in_progress','aerb_finding','2026-07-07',null,16000.00,'Sensor sent for OEM recalibration — awaiting return and re-test'),
    ('DNT-AIM-XRW-07','radiation_output_deviation','xray_tube_aging','recalibrate_xray_output','escalated','aerb_finding','2026-07-05',null,54000.00,'Output 11.6% high — AERB QA physicist recall, tube output review escalated'),
    ('DNT-CMC-CBCT-09','infection_control_lapse','cleaning_protocol_gap','retrain_infection_control','open','nabh_finding','2026-07-08',null,4000.00,'Bite-block reprocessing SOP retraining scheduled for radiology staff'),
    ('DNT-KIM-MILL-12','milling_precision_fail','milling_tool_worn','replace_milling_tool','open','internal_only','2026-07-09',null,22000.00,'Milling spindle and burr set on order — precision coupon retest pending'),
    ('DNT-RBY-IOS-14','scanner_accuracy_drift','scanner_optics_dirty','clean_scanner_optics','verification_pending','iso_13485_deviation','2026-07-04',null,3500.00,'Optics cleaned and firmware reset — awaiting accuracy re-verification'),
    ('DNT-MNP-IMP-06','implant_motor_torque_fail','motor_gearbox_wear','service_implant_motor','overdue','internal_only','2026-06-25',null,18500.00,'Torque calibration past target date — AMC vendor visit delayed'),
    ('DNT-APL-CBCT-02','radiation_output_deviation','detector_degradation','recalibrate_xray_output','closed','iso_13485_deviation','2026-07-06','2026-07-04',12000.00,'Dose recalibrated to within 2.1% — CBCT returned to clinical use')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.dental_imaging_qc_r3346 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3346_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_imaging_qc_r3346)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dental_imaging_qc_r3346 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3346_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3346_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3346_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  radiation_out_of_tol bigint,
  calibration_lapsed bigint,
  infection_control_fail bigint,
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
    count(*) filter (where l.radiation_output_error_pct is not null and abs(l.radiation_output_error_pct) > 5)::bigint,
    count(*) filter (where l.calibration_current = false or l.sensor_calibration_ok = false)::bigint,
    count(*) filter (where l.infection_control_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.dental_imaging_qc_r3346 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3346_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3346_hospital_scorecard() to authenticated;

-- 3) Device-type × clinic matrix
create or replace function public.founder_r3346_device_clinic_matrix()
returns table(device_type text, clinic text, checks bigint, passed bigint, avg_radiation_error_pct numeric, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.clinic, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.radiation_output_error_pct), 2),
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint
  from public.dental_imaging_qc_r3346 l
  group by l.device_type, l.clinic
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3346_device_clinic_matrix() from public, anon;
grant execute on function public.founder_r3346_device_clinic_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3346_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, radiation_out_of_tol bigint, calibration_lapsed bigint)
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
    count(*) filter (where l.radiation_output_error_pct is not null and abs(l.radiation_output_error_pct) > 5)::bigint,
    count(*) filter (where l.calibration_current = false or l.sensor_calibration_ok = false)::bigint
  from public.dental_imaging_qc_r3346 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3346_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3346_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3346_capa_status_board()
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
  from public.dental_imaging_qc_capa_actions_r3346 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3346_capa_status_board() from public, anon;
grant execute on function public.founder_r3346_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3346_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_imaging_qc_capa_actions_r3346)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dental_imaging_qc_capa_actions_r3346 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3346_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3346_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3346_regulatory_impact_digest()
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
  from public.dental_imaging_qc_capa_actions_r3346 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3346_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3346_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3346_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  clinic text,
  check_date date,
  qc_verdict text,
  radiation_output_error_pct numeric,
  scanner_accuracy_ok text,
  milling_precision_ok text,
  implant_motor_torque_accuracy_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.clinic, l.check_date,
    l.qc_verdict, l.radiation_output_error_pct, l.scanner_accuracy_ok,
    l.milling_precision_ok, l.implant_motor_torque_accuracy_ok, l.notes
  from public.dental_imaging_qc_r3346 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or (l.radiation_output_error_pct is not null and abs(l.radiation_output_error_pct) > 5)
     or l.scanner_accuracy_ok in ('drift','fail')
     or l.milling_precision_ok in ('worn_tool','fail')
     or l.implant_motor_torque_accuracy_ok in ('drift','fail')
     or l.image_resolution_ok = false
     or l.sensor_calibration_ok = false
     or l.lead_apron_available = false
     or l.infection_control_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3346_high_risk_queue() from public, anon;
grant execute on function public.founder_r3346_high_risk_queue() to authenticated;
