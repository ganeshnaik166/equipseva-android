-- Round 3299: Customer Hospital TMS / ECT Neuromodulation Device QC Audit
-- Neuromodulation QA — device type × output-intensity error × coil-temp monitor × pulse waveform × impedance/EEG (ECT) × motor-threshold cal (TMS) × e-stop × leakage current × treatment-log × calibration × CAPA

-- =============================================================================
-- TABLE 1: neuromod_device_r3299 — per-device TMS/ECT QC checks
-- =============================================================================
create table if not exists public.neuromod_device_r3299 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'rtms_figure8','deep_tms','ect_brief_pulse','ect_ultrabrief','theta_burst_tms'
  )),
  department text not null check (department in (
    'psychiatry','neurology','neuromodulation_suite','ect_suite','deaddiction_psychiatry'
  )),
  check_date date not null,
  checked_at timestamptz not null,
  output_intensity_error_pct numeric(5,2),
  coil_temperature_monitor_ok text not null check (coil_temperature_monitor_ok in (
    'ok','fault','not_applicable'
  )),
  pulse_waveform_ok boolean not null,
  impedance_monitor_ok boolean,
  eeg_seizure_monitor_ok boolean,
  motor_threshold_calibration_ok boolean,
  emergency_stop_ok boolean not null,
  patient_isolation_leakage_ua numeric(6,2),
  treatment_log_download_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neuromod_device_r3299 enable row level security;

create index if not exists idx_neuromod_device_r3299_org on public.neuromod_device_r3299(organization_id);
create index if not exists idx_neuromod_device_r3299_date on public.neuromod_device_r3299(check_date);
create index if not exists idx_neuromod_device_r3299_verdict on public.neuromod_device_r3299(qc_verdict);

-- =============================================================================
-- TABLE 2: neuromod_device_capa_actions_r3299 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neuromod_device_capa_actions_r3299 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.neuromod_device_r3299(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'output_intensity_deviation','coil_overheating','pulse_waveform_distortion','impedance_monitor_fault',
    'eeg_monitor_fault','motor_threshold_drift','emergency_stop_failure','excess_leakage_current',
    'treatment_log_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'capacitor_degradation','coil_insulation_wear','waveform_generator_fault','electrode_connector_fault',
    'eeg_amplifier_fault','sensor_drift','estop_switch_fault','ground_fault',
    'firmware_bug','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_capacitor_bank','replace_coil','repair_waveform_generator','replace_electrode_harness',
    'replace_eeg_module','recalibrate_output','replace_estop_switch','repair_isolation_ground',
    'update_firmware','retrain_clinical_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.neuromod_device_capa_actions_r3299 enable row level security;

create index if not exists idx_neuromod_capa_r3299_log on public.neuromod_device_capa_actions_r3299(qc_log_id);
create index if not exists idx_neuromod_capa_r3299_status on public.neuromod_device_capa_actions_r3299(capa_status);

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
  insert into public.neuromod_device_r3299 (
    organization_id, hospital_name, device_code, device_type, department,
    check_date, checked_at, output_intensity_error_pct,
    coil_temperature_monitor_ok, pulse_waveform_ok, impedance_monitor_ok,
    eeg_seizure_monitor_ok, motor_threshold_calibration_ok, emergency_stop_ok,
    patient_isolation_leakage_ua, treatment_log_download_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept,
    q.cdate::date, q.cat::timestamptz, q.oierr,
    q.coil, q.pwave, q.imp,
    q.eeg, q.mtc, q.estop,
    q.leak, q.tlog, q.calib,
    q.qv, q.nt
  from (values
    ('NIMHANS Bengaluru','TMS-NIM-01','deep_tms','psychiatry','2026-07-05','2026-07-05 07:20:00+05:30',1.80,
     'ok',true,null,null,true,true,22.0,true,true,'pass','Quarterly QC — deep TMS all parameters nominal'),
    ('NIMHANS Bengaluru','TMS-NIM-02','rtms_figure8','psychiatry','2026-07-05','2026-07-05 08:10:00+05:30',7.40,
     'ok',true,null,null,true,true,30.0,true,true,'conditional_pass','Output intensity 7.4% over 5% tolerance — recheck booked'),
    ('Apollo Chennai','ECT-APL-01','ect_brief_pulse','psychiatry','2026-07-04','2026-07-04 06:45:00+05:30',2.10,
     'not_applicable',true,true,true,null,true,45.0,true,true,'pass','ECT brief-pulse QC clean — impedance and EEG trace verified'),
    ('Apollo Chennai','ECT-APL-02','ect_ultrabrief','psychiatry','2026-07-04','2026-07-04 07:40:00+05:30',3.00,
     'not_applicable',false,true,false,null,true,60.0,true,true,'fail','EEG seizure monitor no trace and pulse waveform distorted'),
    ('Fortis Gurgaon','TMS-FRT-01','theta_burst_tms','neurology','2026-07-03','2026-07-03 07:05:00+05:30',0.90,
     'fault',true,null,null,true,true,25.0,true,true,'conditional_pass','Coil temperature monitor fault — cooling loop watch'),
    ('Fortis Gurgaon','TMS-FRT-02','deep_tms','psychiatry','2026-07-03','2026-07-03 08:00:00+05:30',6.20,
     'ok',true,null,null,false,true,28.0,true,false,'fail','Motor-threshold calibration drift and calibration overdue'),
    ('Manipal Bengaluru','ECT-MNP-01','ect_brief_pulse','psychiatry','2026-07-02','2026-07-02 06:50:00+05:30',1.20,
     'not_applicable',true,false,true,null,true,90.0,true,true,'conditional_pass','Impedance monitor intermittent and leakage 90uA near 100uA limit'),
    ('Manipal Bengaluru','TMS-MNP-02','rtms_figure8','deaddiction_psychiatry','2026-07-02','2026-07-02 07:45:00+05:30',0.50,
     'ok',true,null,null,true,true,18.0,true,true,'pass','rTMS figure-8 QC clean pass'),
    ('AIIMS Delhi','ECT-AIM-01','ect_brief_pulse','psychiatry','2026-07-01','2026-07-01 06:30:00+05:30',4.50,
     'not_applicable',true,true,true,null,false,120.0,true,true,'removed_from_service','Emergency stop failed and leakage 120uA over limit — unit pulled'),
    ('AIIMS Delhi','TMS-AIM-02','deep_tms','neurology','2026-07-01','2026-07-01 07:25:00+05:30',2.00,
     'ok',true,null,null,true,true,20.0,true,true,'pass','Deep TMS neurology suite clean pass'),
    ('CMC Vellore','ECT-CMC-01','ect_ultrabrief','psychiatry','2026-06-30','2026-06-30 06:35:00+05:30',1.00,
     'not_applicable',true,true,true,null,true,40.0,false,true,'conditional_pass','Treatment-log download failed — USB port fault flagged'),
    ('KIMS Hyderabad','TMS-KIM-01','theta_burst_tms','psychiatry','2026-06-30','2026-06-30 07:30:00+05:30',8.90,
     'fault',false,null,null,false,true,33.0,true,false,'fail','Intensity 8.9% off, coil fault and waveform distortion — capacitor suspected'),
    ('Amrita Kochi','TMS-AMR-01','deep_tms','psychiatry','2026-06-29','2026-06-29 06:20:00+05:30',null,
     'not_applicable',false,null,null,false,true,null,false,false,'removed_from_service','QC aborted — device powered down mid-test, multiple faults'),
    ('Yashoda Hyderabad','ECT-YSH-01','ect_brief_pulse','psychiatry','2026-06-29','2026-06-29 07:15:00+05:30',1.50,
     'not_applicable',true,true,true,null,true,38.0,true,true,'pass','Annual ECT QC clean pass')
  ) as q(hosp, dcode, dtype, dept, cdate, cat, oierr, coil, pwave, imp, eeg, mtc, estop, leak, tlog, calib, qv, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.neuromod_device_capa_actions_r3299 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TMS-FRT-01','coil_overheating','coil_insulation_wear','replace_coil','in_progress','patient_safety_alert','2026-07-09',null,145000.00,'Coil showing insulation wear — replacement coil on order'),
    ('TMS-FRT-02','motor_threshold_drift','sensor_drift','recalibrate_output','open','nabh_finding','2026-07-10',null,26000.00,'Motor-threshold drift plus calibration overdue — recal booked'),
    ('ECT-APL-02','eeg_monitor_fault','eeg_amplifier_fault','replace_eeg_module','escalated','cdsco_notifiable','2026-07-08',null,88000.00,'EEG seizure trace absent — escalated to OEM engineer'),
    ('ECT-AIM-01','emergency_stop_failure','estop_switch_fault','replace_estop_switch','closed','patient_safety_alert','2026-07-03','2026-07-01',15500.00,'E-stop switch replaced and leakage re-verified within limit'),
    ('TMS-KIM-01','output_intensity_deviation','capacitor_degradation','replace_capacitor_bank','open','nabh_finding','2026-07-12',null,210000.00,'Output 8.9% off and coil fault — capacitor bank replacement quoted'),
    ('ECT-CMC-01','treatment_log_failure','firmware_bug','update_firmware','verification_pending','internal_only','2026-07-06',null,0.00,'Log export patched in firmware — verify on next session day'),
    ('TMS-AMR-01','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-28',null,52000.00,'OEM preventive-maintenance visit past due — AMC vendor delay escalated')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neuromod_device_r3299 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3299_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuromod_device_r3299)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neuromod_device_r3299 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3299_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3299_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3299_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  coil_temp_fault bigint,
  estop_fail bigint,
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
    count(*) filter (where l.coil_temperature_monitor_ok = 'fault')::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neuromod_device_r3299 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3299_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3299_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3299_device_type_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_intensity_error_pct numeric, avg_leakage_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.output_intensity_error_pct), 2),
    round(avg(l.patient_isolation_leakage_ua), 1)
  from public.neuromod_device_r3299 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3299_device_type_matrix() from public, anon;
grant execute on function public.founder_r3299_device_type_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3299_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, coil_temp_fault bigint, estop_fail bigint)
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
    count(*) filter (where l.coil_temperature_monitor_ok = 'fault')::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint
  from public.neuromod_device_r3299 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3299_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3299_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3299_capa_status_board()
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
  from public.neuromod_device_capa_actions_r3299 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3299_capa_status_board() from public, anon;
grant execute on function public.founder_r3299_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3299_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuromod_device_capa_actions_r3299)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neuromod_device_capa_actions_r3299 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3299_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3299_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3299_regulatory_impact_digest()
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
  from public.neuromod_device_capa_actions_r3299 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3299_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3299_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3299_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  coil_temperature_monitor_ok text,
  emergency_stop_ok boolean,
  calibration_current boolean,
  output_intensity_error_pct numeric,
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
    l.qc_verdict, l.coil_temperature_monitor_ok, l.emergency_stop_ok, l.calibration_current,
    l.output_intensity_error_pct, l.notes
  from public.neuromod_device_r3299 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.coil_temperature_monitor_ok = 'fault'
     or l.emergency_stop_ok = false
     or l.calibration_current = false
     or l.pulse_waveform_ok = false
     or l.impedance_monitor_ok = false
     or l.eeg_seizure_monitor_ok = false
     or l.motor_threshold_calibration_ok = false
     or l.patient_isolation_leakage_ua >= 100
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3299_high_risk_queue() from public, anon;
grant execute on function public.founder_r3299_high_risk_queue() to authenticated;
