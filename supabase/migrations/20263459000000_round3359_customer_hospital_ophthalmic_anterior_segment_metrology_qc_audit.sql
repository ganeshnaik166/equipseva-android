-- Round 3359: Customer Hospital Ophthalmic Anterior-Segment Metrology QC Audit
-- Ophthalmic metrology QA — device type × model-eye cal × cell-count accuracy × pachymetry error × probe-tip × illumination × repeatability × software norms × calibration × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_metrology_r3359 — per-device anterior-segment metrology QC checks
-- =============================================================================
create table if not exists public.ophthalmic_metrology_r3359 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'specular_microscope','ultrasound_pachymeter','optical_pachymeter',
    'gonioscopy_imaging','anterior_segment_oct','tonopachy_combo'
  )),
  department text not null,
  check_date date not null,
  model_eye_calibration_ok boolean not null,
  cell_count_accuracy_ok text not null check (cell_count_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  pachymetry_accuracy_error_um numeric(5,1),
  image_focus_ok boolean not null,
  probe_tip_condition text not null check (probe_tip_condition in (
    'good','worn','replace_due','not_applicable'
  )),
  illumination_ok boolean not null,
  measurement_repeatability_ok boolean not null,
  software_norms_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_metrology_r3359 enable row level security;

create index if not exists idx_ophthalmic_metrology_r3359_org on public.ophthalmic_metrology_r3359(organization_id);
create index if not exists idx_ophthalmic_metrology_r3359_date on public.ophthalmic_metrology_r3359(check_date);
create index if not exists idx_ophthalmic_metrology_r3359_verdict on public.ophthalmic_metrology_r3359(qc_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_metrology_capa_actions_r3359 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ophthalmic_metrology_capa_actions_r3359 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ophthalmic_metrology_r3359(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cell_count_drift','pachymetry_out_of_tolerance','probe_tip_wear','image_focus_failure',
    'illumination_failure','repeatability_failure','software_norms_outdated','calibration_expired',
    'model_eye_calibration_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'probe_tip_worn','optics_contamination','light_source_degraded','transducer_drift',
    'software_norms_version_old','calibration_expired','environmental_vibration',
    'operator_technique_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_probe_tip','clean_optics','replace_light_source','recalibrate_device',
    'update_software_norms','schedule_oem_calibration','retrain_ophthalmic_staff',
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

alter table public.ophthalmic_metrology_capa_actions_r3359 enable row level security;

create index if not exists idx_ophthalmic_capa_r3359_log on public.ophthalmic_metrology_capa_actions_r3359(qc_log_id);
create index if not exists idx_ophthalmic_capa_r3359_status on public.ophthalmic_metrology_capa_actions_r3359(capa_status);

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

  -- 14 metrology QC rows
  insert into public.ophthalmic_metrology_r3359 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    model_eye_calibration_ok, cell_count_accuracy_ok, pachymetry_accuracy_error_um,
    image_focus_ok, probe_tip_condition, illumination_ok, measurement_repeatability_ok,
    software_norms_current, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.dept, q.cdate::date,
    q.meco, q.ccao, q.pach,
    q.focus, q.probe, q.illum, q.repeatab,
    q.sw, q.cal, q.verdict, q.nt
  from (values
    ('Apollo Chennai','OPH-APL-SM01','specular_microscope','Cornea Clinic','2026-07-05',
     true,'ok',null,true,'not_applicable',true,true,true,true,'pass','Quarterly QC — endothelial cell count within model-eye reference'),
    ('Apollo Chennai','OPH-APL-OCT1','anterior_segment_oct','Glaucoma Clinic','2026-07-05',
     true,'not_applicable',4.2,true,'not_applicable',true,true,true,true,'pass','AS-OCT pachymetry map within 5um tolerance'),
    ('Fortis Gurgaon','OPH-FRT-USP1','ultrasound_pachymeter','Cornea Clinic','2026-07-03',
     true,'not_applicable',6.5,true,'worn',true,true,true,true,'conditional_pass','Probe tip worn — pachymetry 6.5um above 5um tolerance, replacement scheduled'),
    ('Fortis Gurgaon','OPH-FRT-OPP1','optical_pachymeter','Refractive Clinic','2026-07-03',
     true,'not_applicable',2.1,true,'not_applicable',true,true,true,true,'pass','Non-contact pachymetry within tolerance'),
    ('Manipal Bengaluru','OPH-MNP-SM01','specular_microscope','Cornea Clinic','2026-07-02',
     true,'drift',null,true,'not_applicable',true,true,true,true,'conditional_pass','Cell-count drift vs model-eye reference — recount and recalibration due'),
    ('Manipal Bengaluru','OPH-MNP-GON1','gonioscopy_imaging','Glaucoma Clinic','2026-07-02',
     true,'not_applicable',null,false,'not_applicable',true,true,true,true,'fail','Anterior-chamber angle images out of focus — objective lens fault'),
    ('AIIMS Delhi','OPH-AIM-TPC1','tonopachy_combo','Glaucoma Clinic','2026-07-01',
     false,'not_applicable',11.0,true,'replace_due',true,false,true,false,'fail','Model-eye cal failed, pachymetry 11um off, calibration lapsed — pending service'),
    ('AIIMS Delhi','OPH-AIM-OCT1','anterior_segment_oct','Cornea Clinic','2026-07-01',
     true,'not_applicable',3.0,true,'not_applicable',true,true,true,true,'pass','Annual QC clean pass'),
    ('CMC Vellore','OPH-CMC-USP1','ultrasound_pachymeter','Cornea Clinic','2026-06-30',
     true,'not_applicable',9.4,true,'replace_due',true,false,true,true,'fail','Probe tip cracked — repeatability and accuracy out of tolerance'),
    ('CMC Vellore','OPH-CMC-SM01','specular_microscope','Cornea Clinic','2026-06-30',
     false,'fail',null,false,'not_applicable',false,false,true,false,'removed_from_service','Cell-count fails model-eye, illumination weak — unit withdrawn'),
    ('KIMS Hyderabad','OPH-KIM-OPP1','optical_pachymeter','Refractive Clinic','2026-06-29',
     true,'not_applicable',3.8,true,'not_applicable',false,true,true,true,'conditional_pass','Illumination LED dimming — light-source service scheduled'),
    ('KIMS Hyderabad','OPH-KIM-OCT1','anterior_segment_oct','Glaucoma Clinic','2026-06-29',
     true,'not_applicable',4.5,true,'not_applicable',true,true,false,true,'conditional_pass','Normative database version outdated — software norms update pending'),
    ('Sankara Nethralaya Chennai','OPH-SNT-GON1','gonioscopy_imaging','Glaucoma Clinic','2026-06-28',
     true,'not_applicable',null,true,'not_applicable',true,true,true,true,'pass','Angle imaging QC pass — all quadrants sharp'),
    ('LV Prasad Hyderabad','OPH-LVP-TPC1','tonopachy_combo','Cornea Clinic','2026-06-28',
     true,'not_applicable',5.6,true,'worn',true,false,true,true,'conditional_pass','Repeatability marginal, probe tip wear — recheck after tip swap')
  ) as q(hosp, code, dtype, dept, cdate, meco, ccao, pach, focus, probe, illum, repeatab, sw, cal, verdict, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.ophthalmic_metrology_capa_actions_r3359 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('OPH-FRT-USP1','probe_tip_wear','probe_tip_worn','replace_probe_tip','overdue','internal_only','2026-07-10',null,8500.00,'Probe tip replacement past target date — AMC vendor delayed'),
    ('OPH-MNP-SM01','cell_count_drift','optics_contamination','clean_optics','open','nabh_finding','2026-07-12',null,6000.00,'Optics cleaning booked — recount after service'),
    ('OPH-MNP-GON1','image_focus_failure','pending_investigation','schedule_oem_service','escalated','iso_13485_deviation','2026-07-09',null,22000.00,'Objective lens fault — escalated to OEM engineer'),
    ('OPH-AIM-TPC1','calibration_expired','calibration_expired','schedule_oem_calibration','escalated','cdsco_notifiable','2026-07-08',null,35000.00,'Calibration lapsed and model-eye fail — CDSCO-notifiable, OEM cal booked'),
    ('OPH-CMC-USP1','pachymetry_out_of_tolerance','probe_tip_worn','replace_probe_tip','open','patient_safety_alert','2026-07-11',null,9500.00,'Cracked probe tip — new tip on order'),
    ('OPH-CMC-SM01','illumination_failure','light_source_degraded','replace_light_source','closed','iso_13485_deviation','2026-07-02','2026-07-04',28000.00,'Light source replaced and cell-count re-verified'),
    ('OPH-KIM-OCT1','software_norms_outdated','software_norms_version_old','update_software_norms','verification_pending','internal_only','2026-07-06',null,0.00,'Normative DB updated to v4.2 — verify on next QC')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ophthalmic_metrology_r3359 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3359_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_metrology_r3359)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_metrology_r3359 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3359_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3359_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3359_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  cell_count_issues bigint,
  pachymetry_issues bigint,
  calibration_lapsed bigint,
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
    count(*) filter (where l.cell_count_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where abs(l.pachymetry_accuracy_error_um) > 5.0)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_metrology_r3359 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3359_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3359_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3359_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_pachymetry_error_um numeric, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.pachymetry_accuracy_error_um), 1),
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint
  from public.ophthalmic_metrology_r3359 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3359_device_department_matrix() from public, anon;
grant execute on function public.founder_r3359_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3359_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, cell_count_issues bigint, calibration_lapsed bigint)
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
    count(*) filter (where l.cell_count_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.ophthalmic_metrology_r3359 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3359_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3359_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3359_capa_status_board()
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
  from public.ophthalmic_metrology_capa_actions_r3359 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3359_capa_status_board() from public, anon;
grant execute on function public.founder_r3359_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3359_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_metrology_capa_actions_r3359)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_metrology_capa_actions_r3359 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3359_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3359_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3359_regulatory_impact_digest()
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
  from public.ophthalmic_metrology_capa_actions_r3359 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3359_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3359_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3359_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  cell_count_accuracy_ok text,
  probe_tip_condition text,
  pachymetry_accuracy_error_um numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.cell_count_accuracy_ok, l.probe_tip_condition,
    l.pachymetry_accuracy_error_um, l.notes
  from public.ophthalmic_metrology_r3359 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.cell_count_accuracy_ok in ('drift','fail')
     or l.probe_tip_condition in ('worn','replace_due')
     or l.calibration_current = false
     or l.model_eye_calibration_ok = false
     or l.image_focus_ok = false
     or l.illumination_ok = false
     or l.measurement_repeatability_ok = false
     or l.software_norms_current = false
     or abs(l.pachymetry_accuracy_error_um) > 5.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3359_high_risk_queue() from public, anon;
grant execute on function public.founder_r3359_high_risk_queue() to authenticated;
