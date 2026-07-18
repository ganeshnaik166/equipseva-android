-- Round 3278: Customer Hospital Advanced Surgical-Energy Generator QC Audit
-- Advanced energy QA — device type (vessel-sealing / ultrasonic / RF-ablation / microwave-ablation / argon-beam)
--   × power-output error × seal burst × handpiece transducer × impedance feedback × ablation temp accuracy
--   × footswitch × smoke-evac integration × electrical-safety leakage × verdict × CAPA
-- NOTE: distinct from basic electrosurgery — these are advanced energy platforms.

-- =============================================================================
-- TABLE 1: advanced_energy_qc_r3278 — per-generator advanced-energy QC checks
-- =============================================================================
create table if not exists public.advanced_energy_qc_r3278 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  generator_code text not null,
  device_type text not null check (device_type in (
    'vessel_sealing_generator','ultrasonic_scalpel','rf_ablation','microwave_ablation','argon_beam_coagulator'
  )),
  department text not null,
  check_date date not null,
  power_output_error_pct numeric(6,2) not null,
  seal_burst_pressure_ok boolean,
  handpiece_transducer_ok text not null check (handpiece_transducer_ok in (
    'ok','degraded','fail','not_applicable'
  )),
  impedance_feedback_ok boolean,
  ablation_temp_accuracy_error_c numeric(5,2),
  footswitch_function_ok boolean not null,
  smoke_evac_integration_ok text not null check (smoke_evac_integration_ok in (
    'ok','weak','not_applicable'
  )),
  electrical_safety_leakage_ua numeric(7,2) not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.advanced_energy_qc_r3278 enable row level security;

create index if not exists idx_advanced_energy_qc_r3278_org on public.advanced_energy_qc_r3278(organization_id);
create index if not exists idx_advanced_energy_qc_r3278_date on public.advanced_energy_qc_r3278(check_date);
create index if not exists idx_advanced_energy_qc_r3278_verdict on public.advanced_energy_qc_r3278(qc_verdict);

-- =============================================================================
-- TABLE 2: advanced_energy_qc_capa_actions_r3278 — CAPA findings for failures
-- =============================================================================
create table if not exists public.advanced_energy_qc_capa_actions_r3278 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.advanced_energy_qc_r3278(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'power_output_deviation','seal_burst_failure','transducer_degraded','impedance_feedback_fault',
    'ablation_temp_inaccuracy','footswitch_fault','smoke_evac_integration_fail','electrical_safety_leakage',
    'preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_wear','generator_calibration_drift','handpiece_cable_fault','impedance_sensor_fault',
    'temperature_probe_fault','footswitch_contact_worn','smoke_evac_seal_leak','power_board_fault',
    'software_config_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_transducer','recalibrate_generator','replace_handpiece_cable','replace_impedance_sensor',
    'replace_temp_probe','replace_footswitch','reseal_smoke_evac_port','replace_power_board',
    'update_software_config','remove_from_service','schedule_oem_service','none_required'
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

alter table public.advanced_energy_qc_capa_actions_r3278 enable row level security;

create index if not exists idx_advanced_energy_capa_r3278_log on public.advanced_energy_qc_capa_actions_r3278(qc_log_id);
create index if not exists idx_advanced_energy_capa_r3278_status on public.advanced_energy_qc_capa_actions_r3278(capa_status);

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

  -- 14 advanced-energy QC rows
  insert into public.advanced_energy_qc_r3278 (
    organization_id, hospital_name, generator_code, device_type, department, check_date,
    power_output_error_pct, seal_burst_pressure_ok, handpiece_transducer_ok, impedance_feedback_ok,
    ablation_temp_accuracy_error_c, footswitch_function_ok, smoke_evac_integration_ok,
    electrical_safety_leakage_ua, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.gcode, q.dtype, q.dept, q.cdate::date,
    q.perr, q.sbp, q.htx, q.imp,
    q.atemp, q.foot, q.smoke,
    q.leak, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','AEG-APL-VS01','vessel_sealing_generator','general_surgery_ot','2026-07-03',
     2.10,true,'not_applicable',true,null,true,'ok',42.0,'pass','LigaSure generator — seal cycle and impedance feedback within spec'),
    ('Apollo Chennai Greams Road','AEG-APL-US02','ultrasonic_scalpel','general_surgery_ot','2026-07-03',
     1.80,null,'ok',null,null,true,'ok',38.5,'pass','Harmonic scalpel — transducer resonance nominal'),
    ('Fortis Gurgaon','AEG-FRT-VS03','vessel_sealing_generator','gynae_ot','2026-06-30',
     8.40,true,'not_applicable',true,null,true,'weak',61.0,'conditional_pass','Power output 8.4% over set watts — recalibration scheduled, smoke-evac suction weak'),
    ('Fortis Gurgaon','AEG-FRT-US04','ultrasonic_scalpel','laparoscopy_ot','2026-06-30',
     5.60,null,'fail',null,null,true,'ok',88.0,'fail','Harmonic transducer failed resonance test — handpiece removed from tray'),
    ('Manipal Bengaluru Old Airport Road','AEG-MNP-RF05','rf_ablation','interventional_radiology','2026-06-29',
     2.60,null,'not_applicable',true,1.40,true,'not_applicable',55.0,'pass','RF ablation generator — impedance feedback and temp within 2C'),
    ('Manipal Bengaluru Old Airport Road','AEG-MNP-MW06','microwave_ablation','interventional_radiology','2026-06-29',
     3.10,null,'not_applicable',null,6.20,true,'not_applicable',63.0,'conditional_pass','Microwave ablation temp accuracy 6.2C off — probe recalibration advised'),
    ('AIIMS New Delhi Ansari Nagar','AEG-AIM-AB07','argon_beam_coagulator','hepatobiliary_ot','2026-06-28',
     2.90,null,'not_applicable',null,null,true,'ok',48.0,'pass','Argon beam coagulator — gas flow and power delivery verified'),
    ('AIIMS New Delhi Ansari Nagar','AEG-AIM-VS08','vessel_sealing_generator','general_surgery_ot','2026-06-28',
     4.20,false,'not_applicable',false,null,true,'ok',138.0,'fail','Seal burst below 3x systolic and impedance feedback erratic; leakage 138uA over limit — unit tagged out'),
    ('CMC Vellore','AEG-CMC-US09','ultrasonic_scalpel','general_surgery_ot','2026-06-27',
     1.50,null,'ok',null,null,true,'ok',40.0,'pass','Harmonic scalpel annual QC — clean pass'),
    ('CMC Vellore','AEG-CMC-RF10','rf_ablation','cardiology_ep_lab','2026-06-27',
     6.80,null,'not_applicable',false,9.40,false,'not_applicable',210.0,'removed_from_service','Footswitch intermittent, impedance feedback fault and temp 9.4C off; leakage 210uA — generator withdrawn'),
    ('KIMS Hyderabad Secunderabad','AEG-KIM-VS11','vessel_sealing_generator','urology_ot','2026-06-26',
     2.40,true,'not_applicable',true,null,true,'ok',51.0,'pass','Enseal generator — seal integrity verified'),
    ('KIMS Hyderabad Secunderabad','AEG-KIM-MW12','microwave_ablation','interventional_radiology','2026-06-26',
     7.60,null,'not_applicable',null,3.80,true,'not_applicable',67.0,'conditional_pass','Microwave power output 7.6% high — antenna cable check pending'),
    ('Yashoda Hyderabad Somajiguda','AEG-YSH-AB13','argon_beam_coagulator','thoracic_ot','2026-06-25',
     3.30,null,'not_applicable',null,null,true,'weak',92.0,'conditional_pass','Argon coagulator smoke-evac integration weak — filter service due'),
    ('Medanta Gurgaon','AEG-MDT-US14','ultrasonic_scalpel','bariatric_ot','2026-06-25',
     4.90,null,'degraded',null,null,true,'ok',79.0,'conditional_pass','Harmonic transducer 8% low output — flagged for watch, recheck in 30 days')
  ) as q(hosp, gcode, dtype, dept, cdate, perr, sbp, htx, imp, atemp, foot, smoke, leak, qv, nt);

  -- CAPA seed — attach to specific checks via generator_code
  insert into public.advanced_energy_qc_capa_actions_r3278 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('AEG-FRT-US04','transducer_degraded','transducer_wear','replace_transducer','in_progress','patient_safety_alert','2026-07-05',null,155000.00,'Harmonic handpiece transducer failed — replacement on order from Ethicon'),
    ('AEG-AIM-VS08','seal_burst_failure','generator_calibration_drift','recalibrate_generator','escalated','cdsco_notifiable','2026-07-04',null,88000.00,'Seal burst below spec and enclosure leakage 138uA — escalated to Medtronic biomed'),
    ('AEG-CMC-RF10','impedance_feedback_fault','impedance_sensor_fault','replace_impedance_sensor','open','nabh_finding','2026-07-08',null,240000.00,'RF generator withdrawn — impedance board, temp probe and footswitch all implicated'),
    ('AEG-FRT-VS03','power_output_deviation','generator_calibration_drift','recalibrate_generator','closed','iso_13485_deviation','2026-07-02','2026-07-01',12000.00,'Generator recalibrated — power output back within 3% of setpoint'),
    ('AEG-MNP-MW06','ablation_temp_inaccuracy','temperature_probe_fault','replace_temp_probe','verification_pending','internal_only','2026-07-06',null,34000.00,'Microwave temp probe replaced — awaiting verification burn on phantom'),
    ('AEG-YSH-AB13','smoke_evac_integration_fail','smoke_evac_seal_leak','reseal_smoke_evac_port','overdue','internal_only','2026-06-23',null,8500.00,'Smoke-evac port seal leak past target date — vendor filter kit delayed'),
    ('AEG-KIM-MW12','power_output_deviation','software_config_error','update_software_config','open','internal_only','2026-07-07',null,0.00,'Microwave antenna power profile mismatch in software preset — reconfig planned')
  ) as q(gcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.advanced_energy_qc_r3278 e
    on e.organization_id = v_org_id and e.generator_code = q.gcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3278_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.advanced_energy_qc_r3278)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.advanced_energy_qc_r3278 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3278_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3278_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3278_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  seal_burst_fail bigint,
  transducer_fail bigint,
  leakage_high bigint,
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
    count(*) filter (where l.seal_burst_pressure_ok = false)::bigint,
    count(*) filter (where l.handpiece_transducer_ok in ('degraded','fail'))::bigint,
    count(*) filter (where l.electrical_safety_leakage_ua > 100)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.advanced_energy_qc_r3278 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3278_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3278_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3278_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_power_error_pct numeric, avg_leakage_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.power_output_error_pct), 2),
    round(avg(l.electrical_safety_leakage_ua), 1)
  from public.advanced_energy_qc_r3278 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3278_device_department_matrix() from public, anon;
grant execute on function public.founder_r3278_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3278_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, seal_burst_fail bigint, transducer_fail bigint)
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
    count(*) filter (where l.seal_burst_pressure_ok = false)::bigint,
    count(*) filter (where l.handpiece_transducer_ok in ('degraded','fail'))::bigint
  from public.advanced_energy_qc_r3278 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3278_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3278_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3278_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.advanced_energy_qc_capa_actions_r3278 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3278_capa_status_board() from public, anon;
grant execute on function public.founder_r3278_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3278_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.advanced_energy_qc_capa_actions_r3278)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.advanced_energy_qc_capa_actions_r3278 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3278_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3278_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3278_regulatory_impact_digest()
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
  from public.advanced_energy_qc_capa_actions_r3278 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3278_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3278_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3278_high_risk_queue()
returns table(
  hospital_name text,
  generator_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  power_output_error_pct numeric,
  handpiece_transducer_ok text,
  smoke_evac_integration_ok text,
  electrical_safety_leakage_ua numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.generator_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.power_output_error_pct, l.handpiece_transducer_ok, l.smoke_evac_integration_ok,
    l.electrical_safety_leakage_ua, l.notes
  from public.advanced_energy_qc_r3278 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.seal_burst_pressure_ok = false
     or l.handpiece_transducer_ok in ('degraded','fail')
     or l.impedance_feedback_ok = false
     or l.footswitch_function_ok = false
     or l.smoke_evac_integration_ok = 'weak'
     or l.electrical_safety_leakage_ua > 100
     or (l.ablation_temp_accuracy_error_c is not null and abs(l.ablation_temp_accuracy_error_c) > 5)
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3278_high_risk_queue() from public, anon;
grant execute on function public.founder_r3278_high_risk_queue() to authenticated;
