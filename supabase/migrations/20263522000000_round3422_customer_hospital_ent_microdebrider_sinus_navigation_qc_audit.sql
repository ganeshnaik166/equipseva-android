-- Round 3422: Customer Hospital ENT Microdebrider / Sinus-Navigation QC Audit
-- ENT surgical-system QA — device type × department × rotational-speed accuracy × handpiece torque × suction/irrigation × blade/burr condition × navigation registration mm × reference array × footswitch × sterilization × calibration × CAPA

-- =============================================================================
-- TABLE 1: ent_surgical_qc_r3422 — per-device ENT surgical-system QC checks
-- =============================================================================
create table if not exists public.ent_surgical_qc_r3422 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'microdebrider_shaver','high_speed_ent_drill','sinus_navigation',
    'skull_base_navigation','coblation_unit'
  )),
  department text not null check (department in (
    'ent_ot','endoscopy_suite','day_surgery_ot','skull_base_ot','opd_procedure_room'
  )),
  check_date date not null,
  rotational_speed_accuracy_ok text not null check (rotational_speed_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  handpiece_torque_ok boolean not null,
  suction_irrigation_ok boolean not null,
  blade_burr_condition text not null check (blade_burr_condition in (
    'good','worn','dull','replace_due'
  )),
  navigation_registration_accuracy_mm numeric(5,2),
  reference_array_ok text not null check (reference_array_ok in (
    'ok','worn','damaged','not_applicable'
  )),
  footswitch_ok boolean not null,
  sterilization_cycle_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ent_surgical_qc_r3422 enable row level security;

create index if not exists idx_ent_surgical_qc_r3422_org on public.ent_surgical_qc_r3422(organization_id);
create index if not exists idx_ent_surgical_qc_r3422_date on public.ent_surgical_qc_r3422(check_date);
create index if not exists idx_ent_surgical_qc_r3422_verdict on public.ent_surgical_qc_r3422(qc_verdict);

-- =============================================================================
-- TABLE 2: ent_surgical_qc_capa_actions_r3422 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ent_surgical_qc_capa_actions_r3422 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ent_surgical_qc_r3422(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'rotational_speed_out_of_tolerance','handpiece_torque_failure','suction_irrigation_blockage',
    'blade_burr_worn','navigation_registration_inaccurate','reference_array_damaged',
    'footswitch_failure','sterilization_cycle_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'motor_bearing_wear','handpiece_end_of_life','irrigation_line_clogged','blade_burr_dull',
    'navigation_sensor_drift','reference_array_damaged','footswitch_cable_damaged',
    'autoclave_cycle_fault','operator_setup_error','pending_investigation',
    'preventive_service_backlog','software_calibration_error'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_console','replace_handpiece','clear_irrigation_line','replace_blade_burr',
    'recalibrate_navigation','replace_reference_array','replace_footswitch','requalify_sterilizer',
    'retrain_ent_staff','remove_from_service','schedule_oem_service','update_software_config','none_required'
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

alter table public.ent_surgical_qc_capa_actions_r3422 enable row level security;

create index if not exists idx_ent_surgical_capa_r3422_log on public.ent_surgical_qc_capa_actions_r3422(qc_log_id);
create index if not exists idx_ent_surgical_capa_r3422_org on public.ent_surgical_qc_capa_actions_r3422(organization_id);
create index if not exists idx_ent_surgical_capa_r3422_status on public.ent_surgical_qc_capa_actions_r3422(capa_status);

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
  insert into public.ent_surgical_qc_r3422 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    rotational_speed_accuracy_ok, handpiece_torque_ok, suction_irrigation_ok, blade_burr_condition,
    navigation_registration_accuracy_mm, reference_array_ok, footswitch_ok, sterilization_cycle_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.rsa, q.torque, q.suction, q.blade,
    q.navacc, q.refarr, q.foot, q.steril,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','MDB-APL-01','microdebrider_shaver','ent_ot','2026-07-05',
     'ok',true,true,'good',null,'not_applicable',true,true,true,'pass','Microdebrider shaver QC — speed and torque within spec'),
    ('Apollo Chennai','NAV-APL-02','sinus_navigation','ent_ot','2026-07-05',
     'not_applicable',true,true,'good',0.8,'ok',true,true,true,'pass','Sinus navigation registration 0.8 mm within tolerance'),
    ('Fortis Gurgaon','DRL-FRT-11','high_speed_ent_drill','skull_base_ot','2026-07-04',
     'drift',true,true,'worn',null,'not_applicable',true,true,true,'conditional_pass','High-speed drill slight speed drift and burr worn — recheck'),
    ('Fortis Gurgaon','MDB-FRT-12','microdebrider_shaver','ent_ot','2026-07-04',
     'fail',false,true,'dull',null,'not_applicable',true,true,true,'fail','Speed accuracy fail and handpiece torque low, blade dull'),
    ('Manipal Bengaluru','NAV-MNP-21','skull_base_navigation','skull_base_ot','2026-07-03',
     'not_applicable',true,true,'good',2.4,'damaged',true,true,false,'removed_from_service','Skull-base navigation registration 2.4 mm out of tolerance, reference array damaged — removed'),
    ('Manipal Bengaluru','COB-MNP-22','coblation_unit','ent_ot','2026-07-03',
     'ok',true,true,'good',null,'not_applicable',true,true,true,'pass','Coblation unit QC nominal'),
    ('AIIMS Delhi','DRL-AIM-31','high_speed_ent_drill','skull_base_ot','2026-07-02',
     'ok',true,true,'worn',null,'not_applicable',true,true,true,'conditional_pass','Drill QC pass but burr shows wear — replace at next service'),
    ('AIIMS Delhi','NAV-AIM-32','sinus_navigation','endoscopy_suite','2026-07-02',
     'not_applicable',true,true,'good',1.9,'worn',false,true,true,'fail','Navigation footswitch failed and reference array worn, registration 1.9 mm borderline'),
    ('CMC Vellore','MDB-CMC-41','microdebrider_shaver','day_surgery_ot','2026-07-01',
     'ok',true,true,'good',null,'not_applicable',true,true,true,'pass','Shaver QC pass post-service'),
    ('CMC Vellore','COB-CMC-42','coblation_unit','ent_ot','2026-07-01',
     'ok',true,false,'good',null,'not_applicable',true,true,false,'conditional_pass','Coblation suction/irrigation weak and calibration overdue — service scheduled'),
    ('KIMS Hyderabad','DRL-KIM-51','high_speed_ent_drill','ent_ot','2026-06-30',
     'ok',true,true,'good',null,'not_applicable',true,true,true,'pass','High-speed drill QC pass'),
    ('KIMS Hyderabad','MDB-KIM-52','microdebrider_shaver','day_surgery_ot','2026-06-30',
     'drift',true,true,'replace_due',null,'not_applicable',true,true,true,'conditional_pass','Shaver speed drift and blade replacement due — recheck after blade swap'),
    ('Yashoda Hyderabad','NAV-YSH-61','sinus_navigation','endoscopy_suite','2026-06-29',
     'not_applicable',true,true,'good',0.9,'ok',true,true,true,'pass','Sinus navigation registration 0.9 mm accurate'),
    ('Kokilaben Mumbai','DRL-KKB-71','high_speed_ent_drill','skull_base_ot','2026-06-29',
     'fail',false,false,'replace_due',null,'not_applicable',false,false,false,'removed_from_service','Multiple failures — speed, torque, footswitch, sterilization — removed from service')
  ) as q(hosp, dcode, dtype, dept, cdate, rsa, torque, suction, blade, navacc, refarr, foot, steril, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ent_surgical_qc_capa_actions_r3422 (
    qc_log_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MDB-FRT-12','handpiece_torque_failure','handpiece_end_of_life','replace_handpiece','in_progress','iso_13485_deviation','2026-07-08',null,68000.00,'Handpiece torque low, speed fail — replacement handpiece on order'),
    ('NAV-MNP-21','reference_array_damaged','reference_array_damaged','replace_reference_array','escalated','patient_safety_alert','2026-07-07',null,145000.00,'Skull-base nav reference array damaged, 2.4 mm error — escalated to OEM'),
    ('NAV-AIM-32','footswitch_failure','footswitch_cable_damaged','replace_footswitch','open','nabh_finding','2026-07-06',null,12000.00,'Navigation footswitch failed intra-op, backup used — cable replacement'),
    ('DRL-KKB-71','sterilization_cycle_failure','autoclave_cycle_fault','requalify_sterilizer','closed','cdsco_notifiable','2026-07-04','2026-07-02',90000.00,'Multiple failures, drill removed, sterilizer requalified and validated'),
    ('DRL-FRT-11','blade_burr_worn','blade_burr_dull','replace_blade_burr','verification_pending','internal_only','2026-07-07',null,15000.00,'Burr worn with speed drift — replaced, verify next case'),
    ('COB-CMC-42','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-01',null,28000.00,'Coblation calibration overdue and suction weak — OEM service delayed'),
    ('MDB-KIM-52','blade_burr_worn','blade_burr_dull','replace_blade_burr','open','none','2026-07-05',null,9000.00,'Shaver blade replacement due with speed drift — recheck scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ent_surgical_qc_r3422 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3422_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ent_surgical_qc_r3422)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ent_surgical_qc_r3422 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3422_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3422_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3422_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  speed_issue bigint,
  nav_out_of_tolerance bigint,
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
    count(*) filter (where l.rotational_speed_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.navigation_registration_accuracy_mm >= 2.0)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ent_surgical_qc_r3422 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3422_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3422_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3422_device_type_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_nav_accuracy_mm numeric)
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
    round(avg(l.navigation_registration_accuracy_mm), 2)
  from public.ent_surgical_qc_r3422 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3422_device_type_department_matrix() from public, anon;
grant execute on function public.founder_r3422_device_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3422_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, speed_issue bigint, nav_out_of_tolerance bigint)
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
    count(*) filter (where l.rotational_speed_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.navigation_registration_accuracy_mm >= 2.0)::bigint
  from public.ent_surgical_qc_r3422 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3422_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3422_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3422_capa_status_board()
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
  from public.ent_surgical_qc_capa_actions_r3422 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3422_capa_status_board() from public, anon;
grant execute on function public.founder_r3422_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3422_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ent_surgical_qc_capa_actions_r3422)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ent_surgical_qc_capa_actions_r3422 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3422_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3422_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3422_regulatory_impact_digest()
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
  from public.ent_surgical_qc_capa_actions_r3422 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3422_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3422_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3422_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  blade_burr_condition text,
  reference_array_ok text,
  rotational_speed_accuracy_ok text,
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
    l.qc_verdict, l.blade_burr_condition, l.reference_array_ok, l.rotational_speed_accuracy_ok, l.notes
  from public.ent_surgical_qc_r3422 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.rotational_speed_accuracy_ok in ('drift','fail')
     or l.handpiece_torque_ok = false
     or l.suction_irrigation_ok = false
     or l.footswitch_ok = false
     or l.sterilization_cycle_ok = false
     or l.calibration_current = false
     or l.blade_burr_condition in ('worn','dull','replace_due')
     or l.reference_array_ok in ('worn','damaged')
     or l.navigation_registration_accuracy_mm >= 2.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3422_high_risk_queue() from public, anon;
grant execute on function public.founder_r3422_high_risk_queue() to authenticated;
