-- Round 3343: Customer Hospital Ophthalmic Biometry / Perimetry Diagnostic-Imaging QC Audit
-- Ophthalmic diagnostic QA — device type × model-eye calibration × axial-length accuracy × keratometry × perimeter luminance × fixation monitor × probe/transducer × IOL-constants × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_diagnostic_qc_r3343 — per-device diagnostic-imaging QC checks
-- =============================================================================
create table if not exists public.ophthalmic_diagnostic_qc_r3343 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'optical_biometer','ultrasound_biometer_ascan','corneal_topographer',
    'specular_microscope','automated_perimeter','bscan_ultrasound'
  )),
  department text not null,
  check_date date not null,
  model_eye_calibration_ok boolean not null,
  axial_length_accuracy_error_pct numeric(5,2),
  keratometry_accuracy_ok boolean not null,
  perimeter_stimulus_luminance_ok text not null check (perimeter_stimulus_luminance_ok in (
    'ok','drift','fail','not_applicable'
  )),
  fixation_monitor_ok boolean not null,
  probe_transducer_condition text not null check (probe_transducer_condition in (
    'good','worn','replace_due','not_applicable'
  )),
  software_iol_constants_current boolean not null,
  printer_output_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_diagnostic_qc_r3343 enable row level security;

create index if not exists idx_ophthalmic_qc_r3343_org on public.ophthalmic_diagnostic_qc_r3343(organization_id);
create index if not exists idx_ophthalmic_qc_r3343_date on public.ophthalmic_diagnostic_qc_r3343(check_date);
create index if not exists idx_ophthalmic_qc_r3343_verdict on public.ophthalmic_diagnostic_qc_r3343(qc_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_diagnostic_qc_capa_actions_r3343 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ophthalmic_diagnostic_qc_capa_actions_r3343 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ophthalmic_diagnostic_qc_r3343(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'axial_length_error','keratometry_error','model_eye_calibration_failure','perimeter_luminance_drift',
    'fixation_monitor_fault','probe_transducer_wear','iol_constants_outdated','printer_output_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'probe_transducer_wear','optics_misalignment','luminance_lamp_aging','fixation_camera_fault',
    'software_not_updated','reference_eye_damaged','environmental_drift','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_probe_transducer','realign_optics','replace_luminance_lamp','repair_fixation_camera',
    'update_iol_constants_software','replace_model_eye','recalibrate_device','retrain_ophthalmic_technician',
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

alter table public.ophthalmic_diagnostic_qc_capa_actions_r3343 enable row level security;

create index if not exists idx_ophthalmic_capa_r3343_log on public.ophthalmic_diagnostic_qc_capa_actions_r3343(qc_log_id);
create index if not exists idx_ophthalmic_capa_r3343_status on public.ophthalmic_diagnostic_qc_capa_actions_r3343(capa_status);

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
  insert into public.ophthalmic_diagnostic_qc_r3343 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    model_eye_calibration_ok, axial_length_accuracy_error_pct, keratometry_accuracy_ok,
    perimeter_stimulus_luminance_ok, fixation_monitor_ok, probe_transducer_condition,
    software_iol_constants_current, printer_output_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.mecal, q.alerr, q.kerok,
    q.lum, q.fixok, q.probe,
    q.iolcur, q.prnok, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','OPH-APL-B01','optical_biometer','Ophthalmology','2026-07-05',
     true,0.15,true,'not_applicable',true,'not_applicable',true,true,true,'pass','IOLMaster QC clean, IOL constants current'),
    ('Apollo Chennai Greams Road','OPH-APL-P01','automated_perimeter','Glaucoma Clinic','2026-07-05',
     true,null,true,'ok',true,'not_applicable',true,true,true,'pass','Humphrey field analyzer luminance within spec'),
    ('Fortis Gurgaon','OPH-FRT-A01','ultrasound_biometer_ascan','Ophthalmology','2026-07-04',
     true,0.42,true,'not_applicable',true,'good',true,true,true,'pass','A-scan probe within tolerance, immersion technique verified'),
    ('Fortis Gurgaon','OPH-FRT-T01','corneal_topographer','Cornea Clinic','2026-07-04',
     true,null,false,'not_applicable',true,'not_applicable',true,true,true,'conditional_pass','Keratometry off reference sphere by 0.6D — recalibration booked'),
    ('Manipal Bengaluru Old Airport Road','OPH-MNP-B01','optical_biometer','Ophthalmology','2026-07-03',
     true,1.85,true,'not_applicable',true,'not_applicable',false,true,true,'conditional_pass','Axial length error 1.85% above 1% tolerance; IOL constants outdated'),
    ('Manipal Bengaluru Old Airport Road','OPH-MNP-S01','specular_microscope','Cornea Clinic','2026-07-03',
     true,null,true,'not_applicable',false,'not_applicable',true,true,true,'conditional_pass','Fixation monitor intermittent — endothelial count reproducibility watch'),
    ('AIIMS Delhi Ansari Nagar','OPH-AIM-P01','automated_perimeter','Glaucoma Clinic','2026-07-02',
     true,null,true,'drift',true,'not_applicable',true,true,true,'conditional_pass','Stimulus luminance drift 0.6 dB — lamp aging, service scheduled'),
    ('AIIMS Delhi Ansari Nagar','OPH-AIM-U01','bscan_ultrasound','Retina Clinic','2026-07-02',
     true,null,true,'not_applicable',true,'worn',true,true,true,'conditional_pass','B-scan transducer face worn — image quality acceptable, replace next cycle'),
    ('CMC Vellore','OPH-CMC-A01','ultrasound_biometer_ascan','Ophthalmology','2026-07-01',
     false,3.20,true,'not_applicable',true,'replace_due',true,true,false,'fail','Model-eye calibration failed; axial length 3.2% off; probe replace-due; calibration expired'),
    ('CMC Vellore','OPH-CMC-P01','automated_perimeter','Glaucoma Clinic','2026-07-01',
     true,null,true,'fail',false,'not_applicable',true,false,true,'fail','Luminance failed calibration and fixation-loss monitor faulty — unit flagged'),
    ('KIMS Hyderabad','OPH-KIM-T01','corneal_topographer','Cornea Clinic','2026-06-30',
     true,null,true,'not_applicable',true,'not_applicable',true,true,true,'pass','Placido-disc topographer QC nominal'),
    ('KIMS Hyderabad','OPH-KIM-B01','optical_biometer','Ophthalmology','2026-06-30',
     true,0.08,true,'not_applicable',true,'not_applicable',true,true,true,'pass','Optical biometry excellent repeatability'),
    ('Aravind Eye Hospital Madurai','OPH-ARV-U01','bscan_ultrasound','Retina Clinic','2026-06-29',
     true,null,true,'not_applicable',true,'replace_due',true,false,false,'removed_from_service','Transducer delamination + printer dead + calibration lapsed — pulled from service'),
    ('Sankara Nethralaya Chennai','OPH-SNC-S01','specular_microscope','Cornea Clinic','2026-06-29',
     true,null,true,'not_applicable',true,'not_applicable',true,true,true,'pass','Specular microscope endothelial QC pass')
  ) as q(hosp, dcode, dtype, dept, cdate, mecal, alerr, kerok, lum, fixok, probe, iolcur, prnok, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ophthalmic_diagnostic_qc_capa_actions_r3343 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('OPH-FRT-T01','keratometry_error','optics_misalignment','realign_optics','in_progress','nabh_finding','2026-07-10',null,15000.00,'Topographer optics realignment scheduled with OEM'),
    ('OPH-MNP-B01','iol_constants_outdated','software_not_updated','update_iol_constants_software','closed','iso_13485_deviation','2026-07-06','2026-07-04',0.00,'IOL constants table updated to current A-constant set'),
    ('OPH-MNP-S01','fixation_monitor_fault','fixation_camera_fault','repair_fixation_camera','open','internal_only','2026-07-12',null,28000.00,'Fixation camera module on order'),
    ('OPH-AIM-P01','perimeter_luminance_drift','luminance_lamp_aging','replace_luminance_lamp','verification_pending','internal_only','2026-07-09',null,34000.00,'Stimulus lamp replaced; awaiting luminance re-verification'),
    ('OPH-CMC-A01','model_eye_calibration_failure','reference_eye_damaged','replace_model_eye','escalated','cdsco_notifiable','2026-07-07',null,52000.00,'Reference model eye cracked; A-scan out of service pending replacement'),
    ('OPH-CMC-P01','perimeter_luminance_drift','luminance_lamp_aging','schedule_oem_service','overdue','patient_safety_alert','2026-06-28',null,41000.00,'Perimeter luminance + fixation failure past target date — OEM visit delayed'),
    ('OPH-ARV-U01','probe_transducer_wear','probe_transducer_wear','replace_probe_transducer','open','nabh_finding','2026-07-08',null,60000.00,'B-scan transducer delaminated; replacement ordered, unit removed from service')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ophthalmic_diagnostic_qc_r3343 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3343_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_diagnostic_qc_r3343)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_diagnostic_qc_r3343 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3343_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3343_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3343_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  keratometry_fail bigint,
  model_eye_fail bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.keratometry_accuracy_ok = false)::bigint,
    count(*) filter (where l.model_eye_calibration_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_diagnostic_qc_r3343 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3343_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3343_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3343_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_axial_length_error_pct numeric, luminance_issues bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.axial_length_accuracy_error_pct), 2),
    count(*) filter (where l.perimeter_stimulus_luminance_ok in ('drift','fail'))::bigint
  from public.ophthalmic_diagnostic_qc_r3343 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3343_device_department_matrix() from public, anon;
grant execute on function public.founder_r3343_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3343_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, keratometry_fail bigint, calibration_overdue bigint)
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
    count(*) filter (where l.keratometry_accuracy_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.ophthalmic_diagnostic_qc_r3343 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3343_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3343_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3343_capa_status_board()
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
  from public.ophthalmic_diagnostic_qc_capa_actions_r3343 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3343_capa_status_board() from public, anon;
grant execute on function public.founder_r3343_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3343_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_diagnostic_qc_capa_actions_r3343)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_diagnostic_qc_capa_actions_r3343 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3343_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3343_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3343_regulatory_impact_digest()
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
  from public.ophthalmic_diagnostic_qc_capa_actions_r3343 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3343_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3343_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3343_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  axial_length_accuracy_error_pct numeric,
  perimeter_stimulus_luminance_ok text,
  probe_transducer_condition text,
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
    l.qc_verdict, l.axial_length_accuracy_error_pct, l.perimeter_stimulus_luminance_ok,
    l.probe_transducer_condition, l.notes
  from public.ophthalmic_diagnostic_qc_r3343 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.keratometry_accuracy_ok = false
     or l.model_eye_calibration_ok = false
     or l.fixation_monitor_ok = false
     or l.perimeter_stimulus_luminance_ok in ('drift','fail')
     or l.probe_transducer_condition in ('worn','replace_due')
     or l.software_iol_constants_current = false
     or l.printer_output_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3343_high_risk_queue() from public, anon;
grant execute on function public.founder_r3343_high_risk_queue() to authenticated;
