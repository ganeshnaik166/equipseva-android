-- Round 3423: Customer Hospital FES / Biofeedback / Robotic-Gait Rehab QC Audit
-- Neuro-rehab QA — device type × department × stimulation accuracy × EMG signal × robotic actuator × harness load × e-stop × force-torque cal × safety interlock × CAPA

-- =============================================================================
-- TABLE 1: neuro_rehab_qc_r3423 — per-device rehab equipment QC checks
-- =============================================================================
create table if not exists public.neuro_rehab_qc_r3423 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'fes_system','emg_biofeedback','robotic_gait_trainer','body_weight_support_treadmill','upper_limb_robot'
  )),
  department text not null check (department in (
    'neuro_rehab','stroke_rehab','spinal_injury_unit','physiotherapy','ortho_rehab'
  )),
  check_date date not null,
  stimulation_output_accuracy_error_pct numeric(5,2),
  electrode_channel_ok boolean not null,
  emg_signal_acquisition_ok boolean not null,
  robotic_actuator_ok text not null check (robotic_actuator_ok in (
    'ok','noisy','fault','not_applicable'
  )),
  harness_suspension_load_ok text not null check (harness_suspension_load_ok in (
    'ok','worn','fail','not_applicable'
  )),
  emergency_stop_ok boolean not null,
  force_torque_calibration_ok boolean not null,
  patient_safety_interlock_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neuro_rehab_qc_r3423 enable row level security;

create index if not exists idx_neuro_rehab_qc_r3423_org on public.neuro_rehab_qc_r3423(organization_id);
create index if not exists idx_neuro_rehab_qc_r3423_date on public.neuro_rehab_qc_r3423(check_date);
create index if not exists idx_neuro_rehab_qc_r3423_verdict on public.neuro_rehab_qc_r3423(qc_verdict);

-- =============================================================================
-- TABLE 2: neuro_rehab_qc_capa_actions_r3423 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neuro_rehab_qc_capa_actions_r3423 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.neuro_rehab_qc_r3423(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stimulation_output_out_of_tolerance','electrode_channel_failure','emg_signal_acquisition_degraded',
    'robotic_actuator_fault','harness_suspension_wear','emergency_stop_failure',
    'force_torque_calibration_failure','patient_safety_interlock_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'stimulator_output_drift','electrode_cable_damaged','emg_sensor_degraded','actuator_motor_wear',
    'harness_strap_worn','estop_switch_fault','load_cell_drift','interlock_sensor_fault',
    'software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_stimulator','replace_electrode_cable','replace_emg_sensor','replace_actuator_module',
    'replace_harness_strap','replace_estop_switch','recalibrate_load_cell','replace_interlock_sensor',
    'update_software_config','retrain_rehab_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.neuro_rehab_qc_capa_actions_r3423 enable row level security;

create index if not exists idx_neuro_rehab_capa_r3423_log on public.neuro_rehab_qc_capa_actions_r3423(qc_log_id);
create index if not exists idx_neuro_rehab_capa_r3423_status on public.neuro_rehab_qc_capa_actions_r3423(capa_status);

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
  insert into public.neuro_rehab_qc_r3423 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    stimulation_output_accuracy_error_pct, electrode_channel_ok, emg_signal_acquisition_ok,
    robotic_actuator_ok, harness_suspension_load_ok, emergency_stop_ok,
    force_torque_calibration_ok, patient_safety_interlock_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.stimerr, q.echan, q.emgsig,
    q.ract, q.harness, q.estop,
    q.ftcal, q.interlock, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','FES-APL-01','fes_system','neuro_rehab','2026-07-03',
     0.8,true,true,'not_applicable','not_applicable',true,true,true,true,'pass','FES stimulation output within tolerance — quarterly QC'),
    ('Apollo Chennai','EMG-APL-02','emg_biofeedback','physiotherapy','2026-07-03',
     null,true,true,'not_applicable','not_applicable',true,true,true,true,'pass','EMG biofeedback signal acquisition clean across all channels'),
    ('Fortis Gurgaon','RGT-FRT-11','robotic_gait_trainer','stroke_rehab','2026-07-02',
     null,true,true,'noisy','worn',true,true,true,true,'conditional_pass','Gait trainer actuator noisy and harness strap worn — monitor'),
    ('Fortis Gurgaon','FES-FRT-12','fes_system','neuro_rehab','2026-07-02',
     6.4,false,true,'not_applicable','not_applicable',true,false,true,true,'fail','Stimulation output 6.4% error, electrode channel and force-torque cal failed'),
    ('Manipal Bengaluru','RGT-MNP-21','robotic_gait_trainer','spinal_injury_unit','2026-07-01',
     null,true,false,'fault','fail',false,false,false,false,'removed_from_service','Actuator fault, harness load fail, e-stop and interlock failed — removed'),
    ('Manipal Bengaluru','ULR-MNP-22','upper_limb_robot','neuro_rehab','2026-07-01',
     null,true,true,'ok','not_applicable',true,true,true,true,'pass','Upper-limb robot QC nominal — force-torque within limits'),
    ('AIIMS Delhi','FES-AIM-31','fes_system','spinal_injury_unit','2026-06-30',
     2.1,true,true,'not_applicable','not_applicable',true,true,true,true,'conditional_pass','FES output 2.1% within limit but upward drift trend flagged'),
    ('AIIMS Delhi','BWS-AIM-32','body_weight_support_treadmill','stroke_rehab','2026-06-30',
     null,true,true,'not_applicable','fail',true,false,true,true,'fail','BWS harness suspension load fail and force-torque cal failed'),
    ('CMC Vellore','EMG-CMC-41','emg_biofeedback','physiotherapy','2026-06-29',
     null,true,true,'not_applicable','not_applicable',true,true,true,true,'pass','EMG biofeedback unit QC pass'),
    ('CMC Vellore','ULR-CMC-42','upper_limb_robot','neuro_rehab','2026-06-29',
     null,true,true,'noisy','not_applicable',true,true,true,false,'conditional_pass','Upper-limb robot actuator noisy and calibration overdue — service due'),
    ('KIMS Hyderabad','FES-KIM-51','fes_system','neuro_rehab','2026-06-28',
     0.9,true,true,'not_applicable','not_applicable',true,true,true,true,'pass','FES system QC pass post-AMC'),
    ('KIMS Hyderabad','RGT-KIM-52','robotic_gait_trainer','ortho_rehab','2026-06-28',
     null,true,true,'ok','worn',true,true,true,true,'conditional_pass','Gait trainer harness strap worn — replacement due at next PM'),
    ('Yashoda Hyderabad','BWS-YSH-61','body_weight_support_treadmill','stroke_rehab','2026-06-27',
     null,true,true,'not_applicable','ok',true,true,true,true,'pass','BWS treadmill harness and interlock QC nominal'),
    ('Kokilaben Mumbai','RGT-KKB-71','robotic_gait_trainer','spinal_injury_unit','2026-06-27',
     null,false,false,'fault','fail',false,false,false,false,'removed_from_service','Multiple actuator, harness and safety failures — removed from service')
  ) as q(hosp, dcode, dtype, dept, cdate, stimerr, echan, emgsig, ract, harness, estop, ftcal, interlock, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.neuro_rehab_qc_capa_actions_r3423 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FES-FRT-12','stimulation_output_out_of_tolerance','stimulator_output_drift','recalibrate_stimulator','in_progress','iso_13485_deviation','2026-07-06',null,12000.00,'Stimulator recalibrated; force-torque cal pending verification'),
    ('RGT-MNP-21','robotic_actuator_fault','actuator_motor_wear','replace_actuator_module','escalated','patient_safety_alert','2026-07-05',null,34000.00,'Actuator fault with interlock miss — escalated to OEM'),
    ('BWS-AIM-32','harness_suspension_wear','harness_strap_worn','replace_harness_strap','escalated','patient_safety_alert','2026-07-04',null,9500.00,'Harness suspension load fail — escalated to OEM'),
    ('RGT-KKB-71','robotic_actuator_fault','actuator_motor_wear','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',52000.00,'Multiple actuator faults — unit removed, replacement validated'),
    ('RGT-FRT-11','harness_suspension_wear','harness_strap_worn','replace_harness_strap','verification_pending','internal_only','2026-07-05',null,6800.00,'Harness strap replaced — verify load next session'),
    ('ULR-CMC-42','calibration_overdue','actuator_motor_wear','schedule_oem_service','overdue','internal_only','2026-06-30',null,18000.00,'OEM calibration past target date — vendor delay'),
    ('RGT-KIM-52','preventive_maintenance_due','harness_strap_worn','replace_harness_strap','open','none','2026-07-07',null,5200.00,'Harness worn — replacement scheduled at next PM')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neuro_rehab_qc_r3423 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3423_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuro_rehab_qc_r3423)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neuro_rehab_qc_r3423 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3423_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3423_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3423_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  emg_signal_fail bigint,
  interlock_issue bigint,
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
    count(*) filter (where l.emg_signal_acquisition_ok = false)::bigint,
    count(*) filter (where l.patient_safety_interlock_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neuro_rehab_qc_r3423 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3423_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3423_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3423_device_type_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_stim_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.stimulation_output_accuracy_error_pct), 2)
  from public.neuro_rehab_qc_r3423 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3423_device_type_department_matrix() from public, anon;
grant execute on function public.founder_r3423_device_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3423_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, emg_signal_fail bigint, interlock_issue bigint)
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
    count(*) filter (where l.emg_signal_acquisition_ok = false)::bigint,
    count(*) filter (where l.patient_safety_interlock_ok = false)::bigint
  from public.neuro_rehab_qc_r3423 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3423_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3423_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3423_capa_status_board()
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
  from public.neuro_rehab_qc_capa_actions_r3423 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3423_capa_status_board() from public, anon;
grant execute on function public.founder_r3423_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3423_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuro_rehab_qc_capa_actions_r3423)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neuro_rehab_qc_capa_actions_r3423 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3423_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3423_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3423_regulatory_impact_digest()
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
  from public.neuro_rehab_qc_capa_actions_r3423 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3423_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3423_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3423_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  robotic_actuator_ok text,
  harness_suspension_load_ok text,
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
    l.qc_verdict, l.robotic_actuator_ok, l.harness_suspension_load_ok, l.notes
  from public.neuro_rehab_qc_r3423 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.emg_signal_acquisition_ok = false
     or l.electrode_channel_ok = false
     or l.emergency_stop_ok = false
     or l.force_torque_calibration_ok = false
     or l.patient_safety_interlock_ok = false
     or l.calibration_current = false
     or l.robotic_actuator_ok in ('noisy','fault')
     or l.harness_suspension_load_ok in ('worn','fail')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3423_high_risk_queue() from public, anon;
grant execute on function public.founder_r3423_high_risk_queue() to authenticated;
