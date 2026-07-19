-- Round 3378: Customer Hospital Neuro & Ortho Surgical Power-Tool & Tourniquet QC Audit
-- Surgical power-tool QA — device type × output-power accuracy × handpiece condition × tourniquet pressure accuracy × leak hold × irrigation flow × footswitch × autoclave × calibration × safety cutoff × CAPA

-- =============================================================================
-- TABLE 1: neuro_ortho_power_tool_r3378 — per-device QC checks
-- =============================================================================
create table if not exists public.neuro_ortho_power_tool_r3378 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'cusa_ultrasonic_aspirator','high_speed_drill','craniotome',
    'pneumatic_tourniquet','arthroscopy_irrigation_pump','sagittal_saw'
  )),
  department text not null,
  check_date date not null,
  output_power_accuracy_error_pct numeric(5,2),
  handpiece_condition text check (handpiece_condition in (
    'good','worn','bearing_noise','replace_due'
  )),
  tourniquet_pressure_accuracy_error_mmhg numeric(6,2),
  pressure_hold_leak_ok boolean,
  irrigation_flow_accuracy_ok text not null check (irrigation_flow_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  footswitch_function_ok boolean,
  autoclave_compatibility_ok boolean,
  calibration_test_pass boolean not null,
  safety_cutoff_ok boolean,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neuro_ortho_power_tool_r3378 enable row level security;

create index if not exists idx_neuro_ortho_power_tool_r3378_org on public.neuro_ortho_power_tool_r3378(organization_id);
create index if not exists idx_neuro_ortho_power_tool_r3378_date on public.neuro_ortho_power_tool_r3378(check_date);
create index if not exists idx_neuro_ortho_power_tool_r3378_verdict on public.neuro_ortho_power_tool_r3378(qc_verdict);

-- =============================================================================
-- TABLE 2: neuro_ortho_power_tool_capa_actions_r3378 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neuro_ortho_power_tool_capa_actions_r3378 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.neuro_ortho_power_tool_r3378(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'power_output_deviation','tourniquet_pressure_deviation','pressure_hold_leak','irrigation_flow_deviation',
    'handpiece_wear','footswitch_fault','autoclave_incompatibility','safety_cutoff_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'motor_brush_wear','bearing_degradation','pressure_sensor_drift','cuff_bladder_leak',
    'irrigation_pump_seal_wear','footswitch_contact_fault','seal_gasket_degradation','calibration_drift',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_motor_brushes','replace_bearings','recalibrate_pressure_sensor','replace_tourniquet_cuff',
    'rebuild_irrigation_pump','replace_footswitch','replace_seal_gasket','recalibrate_and_verify',
    'retrain_or_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.neuro_ortho_power_tool_capa_actions_r3378 enable row level security;

create index if not exists idx_neuro_ortho_power_tool_capa_r3378_log on public.neuro_ortho_power_tool_capa_actions_r3378(qc_log_id);
create index if not exists idx_neuro_ortho_power_tool_capa_r3378_status on public.neuro_ortho_power_tool_capa_actions_r3378(capa_status);

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

  -- 14 per-device QC rows
  insert into public.neuro_ortho_power_tool_r3378 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    output_power_accuracy_error_pct, handpiece_condition, tourniquet_pressure_accuracy_error_mmhg,
    pressure_hold_leak_ok, irrigation_flow_accuracy_ok, footswitch_function_ok,
    autoclave_compatibility_ok, calibration_test_pass, safety_cutoff_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.dept, q.cdate::date,
    q.power, q.hcond, q.tpres,
    q.phold, q.irr, q.foot,
    q.auto, q.caltest, q.safety, q.calcur,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','CUSA-APL-01','cusa_ultrasonic_aspirator','Neurosurgery','2026-07-02',
     1.80,'good',null,null,'ok',true,true,true,true,true,'pass','Quarterly QC — aspirator power and irrigation within tolerance'),
    ('Apollo Chennai Greams Road','DRL-APL-02','high_speed_drill','Neurosurgery','2026-07-02',
     7.40,'worn',null,null,'not_applicable',true,true,true,true,true,'conditional_pass','Drill power error 7.4% over 5% limit — handpiece worn, recheck booked'),
    ('Fortis Gurgaon','TQ-FRT-11','pneumatic_tourniquet','Orthopaedics','2026-07-01',
     null,null,4.00,true,'not_applicable',null,null,true,true,true,'pass','Dual-cuff tourniquet pressure within 5 mmHg, no leak on 10-min hold'),
    ('Fortis Gurgaon','TQ-FRT-12','pneumatic_tourniquet','Ortho OT','2026-07-01',
     null,null,18.50,false,'not_applicable',null,null,true,false,true,'fail','Cuff pressure 18.5 mmHg high and failed 10-min hold — bladder leak, safety cutoff did not trip'),
    ('Manipal Bengaluru Old Airport Road','IRR-MNP-21','arthroscopy_irrigation_pump','Orthopaedics','2026-06-30',
     null,null,null,null,'drift',true,null,true,true,true,'conditional_pass','Irrigation flow drift 12% at high-flow setpoint — pump seal watch'),
    ('Manipal Bengaluru Old Airport Road','SAW-MNP-22','sagittal_saw','Ortho OT','2026-06-30',
     2.10,'good',null,null,'not_applicable',true,true,true,true,true,'pass','Sagittal saw oscillation power nominal, autoclave seal intact'),
    ('AIIMS Delhi Ansari Nagar','CRN-AIM-31','craniotome','Neurosurgery','2026-06-29',
     3.60,'bearing_noise',null,null,'not_applicable',true,true,true,true,true,'conditional_pass','Craniotome bearing noise under load — footswitch and power OK, bearing service due'),
    ('AIIMS Delhi Ansari Nagar','CUSA-AIM-32','cusa_ultrasonic_aspirator','Neuro OT','2026-06-29',
     11.20,'replace_due',null,null,'fail',true,true,false,true,false,'fail','Aspirator power 11.2% low, irrigation fail, calibration expired — unit failed QC'),
    ('CMC Vellore','DRL-CMC-41','high_speed_drill','Orthopaedics','2026-06-28',
     1.40,'good',null,null,'not_applicable',true,true,true,true,true,'pass','Ortho drill annual QC clean pass'),
    ('CMC Vellore','TQ-CMC-42','pneumatic_tourniquet','Ortho OT','2026-06-28',
     null,null,9.80,true,'not_applicable',null,null,true,true,true,'conditional_pass','Tourniquet pressure 9.8 mmHg over target but held — recalibrate at next PM'),
    ('KIMS Hyderabad','IRR-KIM-51','arthroscopy_irrigation_pump','Ortho OT','2026-06-27',
     null,null,null,null,'fail',false,null,false,true,false,'removed_from_service','Irrigation flow fail and footswitch intermittent, calibration overdue — removed pending service'),
    ('KIMS Hyderabad','CRN-KIM-52','craniotome','Neurosurgery','2026-06-27',
     2.90,'good',null,null,'not_applicable',true,true,true,true,true,'pass','Craniotome QC pass post-AMC'),
    ('Kokilaben Dhirubhai Ambani Mumbai','SAW-KKB-61','sagittal_saw','Ortho OT','2026-06-26',
     6.80,'worn',null,null,'not_applicable',true,false,false,false,true,'removed_from_service','Saw over-temp, safety cutoff failed, autoclave seal breach — pulled from service'),
    ('Kokilaben Dhirubhai Ambani Mumbai','TQ-KKB-62','pneumatic_tourniquet','Orthopaedics','2026-06-26',
     null,null,3.20,true,'not_applicable',null,null,true,true,true,'pass','Paediatric tourniquet pressure accurate, leak-tight')
  ) as q(hosp, code, dtype, dept, cdate, power, hcond, tpres, phold, irr, foot, auto, caltest, safety, calcur, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.neuro_ortho_power_tool_capa_actions_r3378 (
    organization_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DRL-APL-02','power_output_deviation','motor_brush_wear','replace_motor_brushes','in_progress','internal_only','2026-07-08',null,15000.00,'Brushes on order — recheck power after replacement'),
    ('TQ-FRT-12','pressure_hold_leak','cuff_bladder_leak','replace_tourniquet_cuff','escalated','patient_safety_alert','2026-07-05',null,22000.00,'Bladder leak with no safety cutoff — escalated, cuff replacement expedited'),
    ('CUSA-AIM-32','power_output_deviation','calibration_drift','recalibrate_and_verify','open','nabh_finding','2026-07-06',null,34000.00,'Aspirator 11.2% low with expired cal — OEM calibration scheduled'),
    ('IRR-MNP-21','irrigation_flow_deviation','irrigation_pump_seal_wear','rebuild_irrigation_pump','verification_pending','internal_only','2026-07-04',null,9000.00,'Pump reseal done — verify flow accuracy on next case'),
    ('IRR-KIM-51','footswitch_fault','footswitch_contact_fault','replace_footswitch','open','iso_13485_deviation','2026-07-09',null,12000.00,'Footswitch intermittent and irrigation fail — footswitch and PM ordered'),
    ('SAW-KKB-61','safety_cutoff_failure','seal_gasket_degradation','schedule_oem_service','escalated','cdsco_notifiable','2026-07-03',null,48000.00,'Over-temp with cutoff failure and autoclave breach — CDSCO-notifiable, OEM engaged'),
    ('CRN-AIM-31','handpiece_wear','bearing_degradation','replace_bearings','closed','internal_only','2026-07-01','2026-06-30',18500.00,'Craniotome bearings replaced, noise resolved')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neuro_ortho_power_tool_r3378 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3378_qc_verdict_rollup()
returns table(qc_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuro_ortho_power_tool_r3378)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neuro_ortho_power_tool_r3378 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3378_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3378_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3378_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  calibration_fail bigint,
  safety_cutoff_fail bigint,
  leak_fail bigint,
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
    count(*) filter (where l.calibration_test_pass = false or l.calibration_current = false)::bigint,
    count(*) filter (where l.safety_cutoff_ok = false)::bigint,
    count(*) filter (where l.pressure_hold_leak_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neuro_ortho_power_tool_r3378 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3378_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3378_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3378_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_power_error_pct numeric, avg_tourniquet_error_mmhg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.output_power_accuracy_error_pct), 2),
    round(avg(l.tourniquet_pressure_accuracy_error_mmhg), 2)
  from public.neuro_ortho_power_tool_r3378 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3378_device_department_matrix() from public, anon;
grant execute on function public.founder_r3378_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3378_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, calibration_fail bigint, safety_cutoff_fail bigint)
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
    count(*) filter (where l.calibration_test_pass = false or l.calibration_current = false)::bigint,
    count(*) filter (where l.safety_cutoff_ok = false)::bigint
  from public.neuro_ortho_power_tool_r3378 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3378_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3378_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3378_capa_status_board()
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
  from public.neuro_ortho_power_tool_capa_actions_r3378 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3378_capa_status_board() from public, anon;
grant execute on function public.founder_r3378_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3378_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuro_ortho_power_tool_capa_actions_r3378)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neuro_ortho_power_tool_capa_actions_r3378 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3378_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3378_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3378_regulatory_impact_digest()
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
  from public.neuro_ortho_power_tool_capa_actions_r3378 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3378_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3378_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3378_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  handpiece_condition text,
  irrigation_flow_accuracy_ok text,
  safety_cutoff_ok boolean,
  calibration_test_pass boolean,
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
    l.qc_verdict, l.handpiece_condition, l.irrigation_flow_accuracy_ok,
    l.safety_cutoff_ok, l.calibration_test_pass, l.notes
  from public.neuro_ortho_power_tool_r3378 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.handpiece_condition in ('worn','bearing_noise','replace_due')
     or l.irrigation_flow_accuracy_ok in ('drift','fail')
     or l.safety_cutoff_ok = false
     or l.pressure_hold_leak_ok = false
     or l.calibration_test_pass = false
     or l.calibration_current = false
     or l.output_power_accuracy_error_pct > 5.0
     or l.tourniquet_pressure_accuracy_error_mmhg > 10.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3378_high_risk_queue() from public, anon;
grant execute on function public.founder_r3378_high_risk_queue() to authenticated;
