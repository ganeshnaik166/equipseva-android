-- Round 3323: Customer Hospital Rehabilitation Mechanical-Equipment Safety Audit
-- Rehab safety QA — device type × load-limit label × brake lock × strap/harness × emergency-stop × motor/actuator × angle accuracy × pinch guard × tip stability × PM × CAPA

-- =============================================================================
-- TABLE 1: rehab_equipment_r3323 — per-device mechanical-safety check log
-- =============================================================================
create table if not exists public.rehab_equipment_r3323 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'traction_unit','cpm_machine','tilt_table','gait_trainer','standing_frame','parallel_bars'
  )),
  department text not null,
  check_date date not null,
  load_limit_labeled boolean not null,
  brake_lock_function_ok boolean not null,
  strap_harness_condition text not null check (strap_harness_condition in (
    'good','frayed','worn','replace_due'
  )),
  emergency_stop_ok boolean not null,
  motor_actuator_ok text not null check (motor_actuator_ok in (
    'ok','noisy','fault','not_applicable'
  )),
  angle_position_accuracy_ok boolean not null,
  patient_pinch_guard_ok boolean not null,
  stability_tip_test_ok boolean not null,
  preventive_maint_current boolean not null,
  safety_verdict text not null check (safety_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rehab_equipment_r3323 enable row level security;

create index if not exists idx_rehab_equipment_r3323_org on public.rehab_equipment_r3323(organization_id);
create index if not exists idx_rehab_equipment_r3323_date on public.rehab_equipment_r3323(check_date);
create index if not exists idx_rehab_equipment_r3323_verdict on public.rehab_equipment_r3323(safety_verdict);

-- =============================================================================
-- TABLE 2: rehab_equipment_capa_actions_r3323 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.rehab_equipment_capa_actions_r3323 (
  id uuid primary key default gen_random_uuid(),
  safety_check_id uuid not null references public.rehab_equipment_r3323(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'brake_lock_failure','strap_harness_wear','emergency_stop_failure','motor_actuator_fault',
    'load_limit_unlabeled','angle_accuracy_deviation','pinch_guard_missing','tip_stability_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'brake_mechanism_worn','strap_material_fatigue','estop_switch_faulty','actuator_motor_failing',
    'label_missing_or_illegible','position_sensor_drift','guard_cover_broken','frame_base_unstable',
    'service_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_brake_assembly','replace_straps_harness','replace_estop_switch','replace_actuator_motor',
    'reapply_load_limit_label','recalibrate_angle_sensor','refit_pinch_guard','stabilize_widen_base',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','patient_safety_alert','internal_only','none','iso_13485_deviation','cdsco_notifiable'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rehab_equipment_capa_actions_r3323 enable row level security;

create index if not exists idx_rehab_capa_r3323_check on public.rehab_equipment_capa_actions_r3323(safety_check_id);
create index if not exists idx_rehab_capa_r3323_status on public.rehab_equipment_capa_actions_r3323(capa_status);

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

  -- 14 device safety-check rows
  insert into public.rehab_equipment_r3323 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    load_limit_labeled, brake_lock_function_ok, strap_harness_condition, emergency_stop_ok,
    motor_actuator_ok, angle_position_accuracy_ok, patient_pinch_guard_ok, stability_tip_test_ok,
    preventive_maint_current, safety_verdict, notes
  )
  select v_org_id, q.hosp, q.dc, q.dt, q.dept, q.cd::date,
    q.lll, q.blf, q.shc, q.est,
    q.maok, q.apa, q.ppg, q.stt,
    q.pmc, q.sv, q.nt
  from (values
    ('Apollo Chennai Greams Road','RH-APL-101','traction_unit','Physiotherapy','2026-07-03',
     true,true,'good',true,'ok',true,true,true,true,'pass','Cervical traction unit — annual mechanical-safety check clean'),
    ('Apollo Chennai Greams Road','RH-APL-102','cpm_machine','Ortho Rehab','2026-07-03',
     true,true,'good',true,'noisy',true,true,true,true,'conditional_pass','Knee CPM actuator noisy under load — service booked, safe to use'),
    ('Fortis Gurgaon','RH-FRT-201','tilt_table','Neuro Rehab','2026-07-02',
     true,false,'worn',true,'ok',false,true,true,false,'fail','Tilt table brake lock slips at 60deg and angle readout 8deg off'),
    ('Fortis Gurgaon','RH-FRT-202','gait_trainer','Neuro Rehab','2026-07-02',
     true,true,'frayed',true,'ok',true,true,true,true,'conditional_pass','Body-weight-support harness webbing frayed — replacement due'),
    ('Manipal Bengaluru Old Airport Road','RH-MNP-301','standing_frame','Paediatric Rehab','2026-07-01',
     true,true,'good',true,'not_applicable',true,true,true,true,'pass','Manual paediatric standing frame — casters lock, no powered drive'),
    ('Manipal Bengaluru Old Airport Road','RH-MNP-302','parallel_bars','Physiotherapy','2026-07-01',
     true,true,'good',true,'not_applicable',true,true,false,true,'conditional_pass','Parallel bars base slightly unstable on tip test — shims added, recheck'),
    ('AIIMS New Delhi Ansari Nagar','RH-AIM-401','traction_unit','Spinal Injury Unit','2026-06-30',
     false,true,'worn',true,'ok',true,true,true,false,'fail','Lumbar traction load-limit label missing and PM overdue 3 months'),
    ('AIIMS New Delhi Ansari Nagar','RH-AIM-402','cpm_machine','Ortho Rehab','2026-06-30',
     true,true,'good',true,'ok',true,true,true,true,'pass','Shoulder CPM — full range and safety function verified'),
    ('CMC Vellore','RH-CMC-501','tilt_table','Neuro Rehab','2026-06-29',
     true,false,'good',false,'fault',false,true,false,false,'removed_from_service','Tilt table e-stop dead and actuator fault — pulled from service'),
    ('CMC Vellore','RH-CMC-502','gait_trainer','Paediatric Rehab','2026-06-29',
     true,true,'good',true,'ok',true,false,true,true,'conditional_pass','Pinch-guard cover cracked near hip pivot — guard on order'),
    ('KIMS Hyderabad','RH-KIM-601','standing_frame','Ortho Rehab','2026-06-28',
     true,true,'replace_due',true,'not_applicable',true,true,true,true,'conditional_pass','Chest strap past replace-by date — swap scheduled this week'),
    ('KIMS Hyderabad','RH-KIM-602','traction_unit','Physiotherapy','2026-06-28',
     true,true,'good',true,'ok',true,true,true,true,'pass','Cervical traction — quarterly mechanical check nominal'),
    ('Yashoda Somajiguda Hyderabad','RH-YSH-701','cpm_machine','Neuro Rehab','2026-06-27',
     true,true,'good',true,'noisy',true,true,true,false,'conditional_pass','Elbow CPM gearbox noisy and PM lapsed — service visit booked'),
    ('Rainbow Children''s Bengaluru','RH-RBW-801','parallel_bars','Paediatric Rehab','2026-06-26',
     true,true,'good',true,'not_applicable',true,true,true,true,'pass','Paediatric parallel bars — stable, height lock secure')
  ) as q(hosp, dc, dt, dept, cd, lll, blf, shc, est, maok, apa, ppg, stt, pmc, sv, nt);

  -- CAPA seed — attach to specific device checks via device_code
  insert into public.rehab_equipment_capa_actions_r3323 (
    safety_check_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('RH-FRT-201','brake_lock_failure','brake_mechanism_worn','replace_brake_assembly','2026-07-08',null,'in_progress','patient_safety_alert',32000.00,'Tilt table brake lock slips — brake kit ordered from OEM'),
    ('RH-FRT-202','strap_harness_wear','strap_material_fatigue','replace_straps_harness','2026-07-06',null,'open','nabh_finding',14000.00,'BWS harness webbing frayed — replacement harness sourced'),
    ('RH-AIM-401','load_limit_unlabeled','label_missing_or_illegible','reapply_load_limit_label','2026-07-04','2026-07-01','closed','iso_13485_deviation',1500.00,'Load-limit label reprinted and PM completed same day'),
    ('RH-CMC-501','emergency_stop_failure','estop_switch_faulty','replace_estop_switch','2026-07-05',null,'escalated','patient_safety_alert',26000.00,'E-stop dead — unit isolated, escalated to biomedical vendor'),
    ('RH-CMC-502','pinch_guard_missing','guard_cover_broken','refit_pinch_guard','2026-07-07',null,'verification_pending','internal_only',8000.00,'New hip-pivot guard fitted — awaiting safety sign-off'),
    ('RH-KIM-601','strap_harness_wear','strap_material_fatigue','replace_straps_harness','2026-06-26',null,'overdue','internal_only',9000.00,'Chest strap replacement overdue — vendor delay'),
    ('RH-YSH-701','motor_actuator_fault','actuator_motor_failing','schedule_oem_service','2026-07-10',null,'open','none',22000.00,'Elbow CPM gearbox noise — OEM service scheduled')
  ) as q(dc_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.rehab_equipment_r3323 e
    on e.organization_id = v_org_id and e.device_code = q.dc_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Safety verdict distribution
create or replace function public.founder_r3323_safety_verdict_rollup()
returns table(safety_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rehab_equipment_r3323)
  select l.safety_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.rehab_equipment_r3323 l
  group by l.safety_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3323_safety_verdict_rollup() from public, anon;
grant execute on function public.founder_r3323_safety_verdict_rollup() to authenticated;

-- 2) Hospital-level safety scorecard
create or replace function public.founder_r3323_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  brake_fail bigint,
  estop_fail bigint,
  pinch_guard_fail bigint,
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
    count(*) filter (where l.safety_verdict = 'pass')::bigint,
    count(*) filter (where l.safety_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.safety_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.brake_lock_function_ok = false)::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    count(*) filter (where l.patient_pinch_guard_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.safety_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.rehab_equipment_r3323 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3323_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3323_hospital_scorecard() to authenticated;

-- 3) Device type × safety verdict matrix
create or replace function public.founder_r3323_device_type_verdict_matrix()
returns table(device_type text, safety_verdict text, checks bigint, estop_fail bigint, brake_fail bigint, maint_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.safety_verdict, count(*)::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    count(*) filter (where l.brake_lock_function_ok = false)::bigint,
    count(*) filter (where l.preventive_maint_current = false)::bigint
  from public.rehab_equipment_r3323 l
  group by l.device_type, l.safety_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3323_device_type_verdict_matrix() from public, anon;
grant execute on function public.founder_r3323_device_type_verdict_matrix() to authenticated;

-- 4) Daily safety-check trend
create or replace function public.founder_r3323_daily_safety_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, estop_fail bigint, brake_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.safety_verdict = 'pass')::bigint,
    count(*) filter (where l.safety_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    count(*) filter (where l.brake_lock_function_ok = false)::bigint
  from public.rehab_equipment_r3323 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3323_daily_safety_trend() from public, anon;
grant execute on function public.founder_r3323_daily_safety_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3323_capa_status_board()
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
  from public.rehab_equipment_capa_actions_r3323 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3323_capa_status_board() from public, anon;
grant execute on function public.founder_r3323_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3323_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rehab_equipment_capa_actions_r3323)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.rehab_equipment_capa_actions_r3323 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3323_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3323_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3323_regulatory_impact_digest()
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
  from public.rehab_equipment_capa_actions_r3323 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3323_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3323_regulatory_impact_digest() to authenticated;

-- 8) High-risk device queue (top individual concerns)
create or replace function public.founder_r3323_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  safety_verdict text,
  brake_lock_status text,
  emergency_stop_status text,
  strap_harness_condition text,
  motor_actuator_ok text,
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
    l.safety_verdict,
    (case when l.brake_lock_function_ok then 'ok' else 'fail' end)::text,
    (case when l.emergency_stop_ok then 'ok' else 'fail' end)::text,
    l.strap_harness_condition, l.motor_actuator_ok, l.notes
  from public.rehab_equipment_r3323 l
  where l.safety_verdict in ('conditional_pass','fail','removed_from_service')
     or l.brake_lock_function_ok = false
     or l.emergency_stop_ok = false
     or l.patient_pinch_guard_ok = false
     or l.stability_tip_test_ok = false
     or l.angle_position_accuracy_ok = false
     or l.load_limit_labeled = false
     or l.preventive_maint_current = false
     or l.motor_actuator_ok in ('noisy','fault')
     or l.strap_harness_condition in ('frayed','worn','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3323_high_risk_queue() from public, anon;
grant execute on function public.founder_r3323_high_risk_queue() to authenticated;
