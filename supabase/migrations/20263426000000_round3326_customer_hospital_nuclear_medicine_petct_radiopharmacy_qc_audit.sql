-- Round 3326: Customer Hospital Nuclear-Medicine PET-CT & Radiopharmacy Hot-Lab QC Audit
-- Nuc-med QA — device type × dose-calibrator accuracy × uniformity × shielding survey × contamination wipe × signage × waste decay-storage × ALARA × calibration × CAPA

-- =============================================================================
-- TABLE 1: nucmed_petct_qc_r3326 — per-device / per-area QC audit log
-- =============================================================================
create table if not exists public.nucmed_petct_qc_r3326 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'pet_ct_scanner','dose_calibrator','hot_lab_dispensing','survey_meter','well_counter','spect_ct_hybrid'
  )),
  device_vendor text not null,
  department text not null,
  check_date date not null,
  checked_at timestamptz not null,
  daily_qc_pass boolean not null,
  dose_calibrator_accuracy_error_pct numeric(5,2),
  uniformity_ok text not null check (uniformity_ok in (
    'pass','non_uniform','fail','not_applicable'
  )),
  shielding_survey_ok boolean not null,
  contamination_wipe_result text not null check (contamination_wipe_result in (
    'clean','low','fail'
  )),
  radiation_area_signage_ok boolean not null,
  waste_decay_storage_ok boolean not null,
  alara_compliance_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nucmed_petct_qc_r3326 enable row level security;

create index if not exists idx_nucmed_petct_qc_r3326_org on public.nucmed_petct_qc_r3326(organization_id);
create index if not exists idx_nucmed_petct_qc_r3326_date on public.nucmed_petct_qc_r3326(check_date);
create index if not exists idx_nucmed_petct_qc_r3326_verdict on public.nucmed_petct_qc_r3326(qc_verdict);

-- =============================================================================
-- TABLE 2: nucmed_petct_qc_capa_actions_r3326 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.nucmed_petct_qc_capa_actions_r3326 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.nucmed_petct_qc_r3326(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dose_calibrator_accuracy','uniformity_failure','shielding_breach','contamination_event',
    'signage_missing','waste_storage_deviation','alara_deviation','calibration_overdue','daily_qc_failure'
  )),
  root_cause text not null check (root_cause in (
    'detector_drift','source_geometry_error','shielding_damage','spill_containment_failure',
    'procedure_not_followed','staffing_gap','equipment_ageing','software_config_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_dose_calibrator','normalize_detector','repair_shielding','decontaminate_and_wipe_retest',
    'replace_signage','correct_waste_storage','retrain_staff','update_software_config',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nucmed_petct_qc_capa_actions_r3326 enable row level security;

create index if not exists idx_nucmed_petct_capa_r3326_log on public.nucmed_petct_qc_capa_actions_r3326(qc_log_id);
create index if not exists idx_nucmed_petct_capa_r3326_status on public.nucmed_petct_qc_capa_actions_r3326(capa_status);

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

  -- 14 QC audit rows
  insert into public.nucmed_petct_qc_r3326 (
    organization_id, hospital_name, device_code, device_type, device_vendor, department,
    check_date, checked_at, daily_qc_pass, dose_calibrator_accuracy_error_pct, uniformity_ok,
    shielding_survey_ok, contamination_wipe_result, radiation_area_signage_ok,
    waste_decay_storage_ok, alara_compliance_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.vendor, q.dept,
    q.cd::date, q.cat::timestamptz, q.dqp, q.dcerr, q.uni,
    q.ssok, q.cwr, q.sign,
    q.waste, q.alara, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','NM-APL-PET1','pet_ct_scanner','GE Healthcare','Nuclear Medicine','2026-07-05','2026-07-05 07:20:00+05:30',
     true,null,'pass',true,'clean',true,true,true,true,'pass','Discovery MI daily QC and uniformity nominal'),
    ('Apollo Chennai Greams Road','NM-APL-DC1','dose_calibrator','Capintec','Radiopharmacy Hot Lab','2026-07-05','2026-07-05 07:45:00+05:30',
     true,4.80,'not_applicable',true,'clean',true,true,true,true,'conditional_pass','Dose-calibrator accuracy 4.8% near 5% limit — constancy trend watch'),
    ('Fortis Gurgaon','NM-FRT-HL1','hot_lab_dispensing','Comecer','Radiopharmacy Hot Lab','2026-07-04','2026-07-04 06:50:00+05:30',
     true,null,'not_applicable',true,'low',true,true,true,true,'conditional_pass','Bench wipe low-level activity — recleaned, reswab booked'),
    ('Fortis Gurgaon','NM-FRT-SM1','survey_meter','Mirion','Radiopharmacy Hot Lab','2026-07-04','2026-07-04 07:10:00+05:30',
     false,null,'not_applicable',true,'fail',true,true,false,true,'fail','Wipe test above limit near draw-up station — ALARA deviation logged'),
    ('Manipal Bengaluru Old Airport Rd','NM-MNP-SP1','spect_ct_hybrid','Siemens Healthineers','Nuclear Medicine','2026-07-03','2026-07-03 08:05:00+05:30',
     false,null,'fail',true,'clean',true,true,true,false,'removed_from_service','Flood uniformity failed — camera head pulled for PMT tuning; calibration lapsed'),
    ('Manipal Bengaluru Old Airport Rd','NM-MNP-PET1','pet_ct_scanner','United Imaging','Nuclear Medicine','2026-07-03','2026-07-03 08:40:00+05:30',
     true,null,'non_uniform',true,'clean',true,true,true,true,'conditional_pass','Normalization slightly non-uniform — recon corrected, reverify next day'),
    ('AIIMS Delhi Ansari Nagar','NM-AIM-DC1','dose_calibrator','Capintec','Radiopharmacy Hot Lab','2026-07-02','2026-07-02 06:30:00+05:30',
     false,7.90,'not_applicable',true,'clean',true,true,true,false,'fail','Cs-137 constancy 7.9% over 5% — recalibration overdue'),
    ('AIIMS Delhi Ansari Nagar','NM-AIM-WC1','well_counter','Mediso','Nuclear Medicine','2026-07-02','2026-07-02 07:00:00+05:30',
     true,null,'not_applicable',true,'clean',true,true,true,true,'pass','Well-counter energy peak and efficiency within spec'),
    ('CMC Vellore','NM-CMC-SM1','survey_meter','Fluke','Radiopharmacy Hot Lab','2026-07-01','2026-07-01 06:45:00+05:30',
     true,null,'not_applicable',false,'clean',true,true,true,true,'conditional_pass','Shielding survey elevated dose at hot-lab door edge — lead flashing check'),
    ('CMC Vellore','NM-CMC-HL1','hot_lab_dispensing','Tema Sinergie','Radiopharmacy Hot Lab','2026-07-01','2026-07-01 07:15:00+05:30',
     true,null,'not_applicable',true,'clean',false,true,true,true,'conditional_pass','Radiation-area signage on dispensing bay missing — replacement ordered'),
    ('KIMS Hyderabad','NM-KIM-PET1','pet_ct_scanner','Philips','Nuclear Medicine','2026-06-30','2026-06-30 08:20:00+05:30',
     true,null,'pass',true,'clean',true,true,true,true,'pass','Vereos daily QC — sinogram and uniformity pass'),
    ('KIMS Hyderabad','NM-KIM-DC1','dose_calibrator','Capintec','Radiopharmacy Hot Lab','2026-06-30','2026-06-30 08:55:00+05:30',
     true,2.10,'not_applicable',true,'clean',true,false,true,true,'conditional_pass','Decay-storage log gap for F-18 waste drums — waste_decay_storage flagged'),
    ('Tata Memorial Mumbai','NM-TMH-SP1','spect_ct_hybrid','Siemens Healthineers','Nuclear Medicine','2026-06-29','2026-06-29 07:35:00+05:30',
     false,null,'non_uniform',true,'fail',true,false,false,true,'fail','Bench wipe failed and decay-storage overfilled — ALARA breach, area quarantined'),
    ('Amrita Kochi','NM-AMR-SM1','survey_meter','Mirion','Radiopharmacy Hot Lab','2026-06-29','2026-06-29 08:10:00+05:30',
     true,null,'not_applicable',true,'clean',true,true,true,true,'pass','Survey meter calibration current, background readings normal')
  ) as q(hosp, code, dtype, vendor, dept, cd, cat, dqp, dcerr, uni, ssok, cwr, sign, waste, alara, calcur, qv, nt);

  -- CAPA seed — attach to specific audits via device code
  insert into public.nucmed_petct_qc_capa_actions_r3326 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NM-FRT-SM1','contamination_event','spill_containment_failure','decontaminate_and_wipe_retest','in_progress','patient_safety_alert','2026-07-09',null,25000.00,'Hot-lab draw-up station decontaminated — awaiting clearance wipe below limit'),
    ('NM-MNP-SP1','uniformity_failure','detector_drift','normalize_detector','escalated','aerb_notifiable','2026-07-08',null,140000.00,'Camera head removed — PMT tuning and flood normalization by OEM'),
    ('NM-AIM-DC1','dose_calibrator_accuracy','source_geometry_error','recalibrate_dose_calibrator','open','aerb_notifiable','2026-07-07',null,35000.00,'Constancy 7.9% off — Cs-137 recalibration and linearity scheduled'),
    ('NM-CMC-SM1','shielding_breach','shielding_damage','repair_shielding','open','nabh_finding','2026-07-10',null,60000.00,'Lead flashing at hot-lab door edge to be re-leaded'),
    ('NM-CMC-HL1','signage_missing','procedure_not_followed','replace_signage','closed','internal_only','2026-07-03','2026-07-02',3000.00,'Radiation-area signage reinstalled on dispensing bay'),
    ('NM-KIM-DC1','waste_storage_deviation','staffing_gap','correct_waste_storage','verification_pending','iso_13485_deviation','2026-07-05',null,8000.00,'Decay-storage log resumed — verify F-18 drum decay before disposal'),
    ('NM-TMH-SP1','contamination_event','spill_containment_failure','decontaminate_and_wipe_retest','overdue','patient_safety_alert','2026-07-01',null,90000.00,'Quarantined area — decontamination past target date, AERB report pending')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.nucmed_petct_qc_r3326 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3326_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nucmed_petct_qc_r3326)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nucmed_petct_qc_r3326 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3326_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3326_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3326_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  contamination_fail bigint,
  shielding_fail bigint,
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
    count(*) filter (where l.contamination_wipe_result in ('low','fail'))::bigint,
    count(*) filter (where l.shielding_survey_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.nucmed_petct_qc_r3326 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3326_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3326_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3326_device_department_matrix()
returns table(device_type text, department text, audits bigint, passed bigint, daily_qc_fail bigint, avg_accuracy_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.daily_qc_pass = false)::bigint,
    round(avg(l.dose_calibrator_accuracy_error_pct), 2)
  from public.nucmed_petct_qc_r3326 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3326_device_department_matrix() from public, anon;
grant execute on function public.founder_r3326_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3326_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, contamination_fail bigint, daily_qc_fail bigint)
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
    count(*) filter (where l.contamination_wipe_result in ('low','fail'))::bigint,
    count(*) filter (where l.daily_qc_pass = false)::bigint
  from public.nucmed_petct_qc_r3326 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3326_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3326_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3326_capa_status_board()
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
  from public.nucmed_petct_qc_capa_actions_r3326 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3326_capa_status_board() from public, anon;
grant execute on function public.founder_r3326_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3326_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nucmed_petct_qc_capa_actions_r3326)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nucmed_petct_qc_capa_actions_r3326 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3326_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3326_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3326_regulatory_impact_digest()
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
  from public.nucmed_petct_qc_capa_actions_r3326 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3326_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3326_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3326_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  uniformity_ok text,
  contamination_wipe_result text,
  shielding_survey_ok boolean,
  calibration_current boolean,
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
    l.qc_verdict, l.uniformity_ok, l.contamination_wipe_result, l.shielding_survey_ok,
    l.calibration_current, l.notes
  from public.nucmed_petct_qc_r3326 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.uniformity_ok in ('non_uniform','fail')
     or l.contamination_wipe_result in ('low','fail')
     or l.shielding_survey_ok = false
     or l.waste_decay_storage_ok = false
     or l.alara_compliance_ok = false
     or l.calibration_current = false
     or l.daily_qc_pass = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3326_high_risk_queue() from public, anon;
grant execute on function public.founder_r3326_high_risk_queue() to authenticated;
