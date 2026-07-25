-- Round 3411: Customer Hospital Ophthalmic YAG / SLT Glaucoma-Laser QC Audit
-- Ophthalmic laser QA — device type × department × energy output error × aiming beam × focus offset × burst mode × slit-lamp integration × spot targeting × safety filter × footswitch × shot counter × calibration × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_laser_qc_r3411 — per-device ophthalmic laser QC checks
-- =============================================================================
create table if not exists public.ophthalmic_laser_qc_r3411 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'yag_capsulotomy','slt_glaucoma','combined_yag_slt','lpi_iridotomy','diode_cyclophotocoagulation'
  )),
  department text not null check (department in (
    'glaucoma_clinic','cataract_service','retina_service','general_ophthalmology','laser_suite'
  )),
  check_date date not null,
  energy_output_error_pct numeric(5,2),
  aiming_beam_ok boolean not null,
  focus_offset_accuracy_ok boolean not null,
  burst_mode_ok text not null check (burst_mode_ok in (
    'ok','drift','fail','not_applicable'
  )),
  slit_lamp_integration_ok boolean not null,
  spot_targeting_ok boolean not null,
  safety_filter_ok boolean not null,
  footswitch_ok boolean not null,
  shot_counter_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_laser_qc_r3411 enable row level security;

create index if not exists idx_ophthalmic_laser_qc_r3411_org on public.ophthalmic_laser_qc_r3411(organization_id);
create index if not exists idx_ophthalmic_laser_qc_r3411_date on public.ophthalmic_laser_qc_r3411(check_date);
create index if not exists idx_ophthalmic_laser_qc_r3411_verdict on public.ophthalmic_laser_qc_r3411(qc_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_laser_qc_capa_actions_r3411 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ophthalmic_laser_qc_capa_actions_r3411 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ophthalmic_laser_qc_r3411(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'energy_output_out_of_tolerance','aiming_beam_misalignment','focus_offset_drift','burst_mode_fault',
    'slit_lamp_integration_fault','spot_targeting_error','safety_filter_failure','footswitch_fault',
    'shot_counter_fault','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'laser_cavity_aging','beam_delivery_misalignment','focus_optics_contamination','q_switch_fault',
    'optical_filter_degraded','footswitch_wear','counter_sensor_fault','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_energy_output','realign_aiming_beam','clean_focus_optics','replace_q_switch_module',
    'replace_safety_filter','replace_footswitch','repair_shot_counter','update_software_config',
    'retrain_laser_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.ophthalmic_laser_qc_capa_actions_r3411 enable row level security;

create index if not exists idx_ophthalmic_laser_capa_r3411_log on public.ophthalmic_laser_qc_capa_actions_r3411(qc_log_id);
create index if not exists idx_ophthalmic_laser_capa_r3411_status on public.ophthalmic_laser_qc_capa_actions_r3411(capa_status);

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
  insert into public.ophthalmic_laser_qc_r3411 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    energy_output_error_pct, aiming_beam_ok, focus_offset_accuracy_ok, burst_mode_ok,
    slit_lamp_integration_ok, spot_targeting_ok, safety_filter_ok, footswitch_ok,
    shot_counter_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.eerr, q.aim, q.foc, q.burst,
    q.slit, q.spot, q.safe, q.foot,
    q.shot, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','YAG-APL-01','yag_capsulotomy','cataract_service','2026-07-03',
     0.7,true,true,'ok',true,true,true,true,true,true,'pass','YAG capsulotomy energy and burst mode within tolerance'),
    ('Apollo Chennai','SLT-APL-02','slt_glaucoma','glaucoma_clinic','2026-07-03',
     0.9,true,true,'not_applicable',true,true,true,true,true,true,'pass','SLT trabeculoplasty QC clean, aiming beam aligned'),
    ('Fortis Gurgaon','YAG-FRT-11','combined_yag_slt','glaucoma_clinic','2026-07-02',
     1.1,true,true,'drift',true,true,true,true,true,true,'conditional_pass','Combined YAG/SLT burst-mode drift observed — monitor next QC'),
    ('Fortis Gurgaon','YAG-FRT-12','yag_capsulotomy','cataract_service','2026-07-02',
     4.2,false,false,'fail',true,true,true,true,true,true,'fail','Energy output 4.2% error, aiming beam misaligned, burst mode fail'),
    ('Manipal Bengaluru','DCP-MNP-21','diode_cyclophotocoagulation','glaucoma_clinic','2026-07-01',
     5.6,true,false,'not_applicable',false,true,false,true,false,false,'removed_from_service','Diode CPC energy 5.6% high, safety filter fail, calibration overdue — removed'),
    ('Manipal Bengaluru','LPI-MNP-22','lpi_iridotomy','glaucoma_clinic','2026-07-01',
     0.8,true,true,'ok',true,true,true,true,true,true,'pass','LPI iridotomy laser QC nominal'),
    ('AIIMS Delhi','YAG-AIM-31','yag_capsulotomy','general_ophthalmology','2026-06-30',
     1.4,true,true,'ok',true,true,true,true,true,true,'conditional_pass','Energy error 1.4% within limit but upward drift trend flagged'),
    ('AIIMS Delhi','SLT-AIM-32','slt_glaucoma','glaucoma_clinic','2026-06-30',
     3.1,true,false,'not_applicable',false,false,true,false,true,true,'fail','SLT focus offset and slit-lamp integration failed, footswitch intermittent'),
    ('CMC Vellore','YAG-CMC-41','yag_capsulotomy','cataract_service','2026-06-29',
     0.6,true,true,'ok',true,true,true,true,true,true,'pass','YAG capsulotomy QC pass'),
    ('CMC Vellore','SLT-CMC-42','slt_glaucoma','glaucoma_clinic','2026-06-29',
     1.2,true,true,'not_applicable',true,true,true,true,false,false,'conditional_pass','Shot counter fault and calibration overdue — service scheduled'),
    ('KIMS Hyderabad','LPI-KIM-51','lpi_iridotomy','general_ophthalmology','2026-06-28',
     0.9,true,true,'ok',true,true,true,true,true,true,'pass','LPI iridotomy laser QC pass post-AMC'),
    ('KIMS Hyderabad','DCP-KIM-52','diode_cyclophotocoagulation','retina_service','2026-06-28',
     1.6,true,true,'not_applicable',true,true,true,false,true,true,'conditional_pass','Diode CPC footswitch worn — replacement due'),
    ('Yashoda Hyderabad','YAG-YSH-61','combined_yag_slt','laser_suite','2026-06-27',
     0.7,true,true,'ok',true,true,true,true,true,true,'pass','Combined YAG/SLT platform QC nominal'),
    ('Kokilaben Mumbai','YAG-KKB-71','yag_capsulotomy','cataract_service','2026-06-27',
     6.3,false,false,'fail',false,false,false,false,false,false,'removed_from_service','Multiple failures across energy, optics and safety filter — removed from service')
  ) as q(hosp, dcode, dtype, dept, cdate, eerr, aim, foc, burst, slit, spot, safe, foot, shot, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ophthalmic_laser_qc_capa_actions_r3411 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('YAG-FRT-12','energy_output_out_of_tolerance','laser_cavity_aging','recalibrate_energy_output','in_progress','iso_13485_deviation','2026-07-06',null,18000.00,'Energy output recalibrated; aiming-beam realignment pending verification'),
    ('DCP-MNP-21','safety_filter_failure','optical_filter_degraded','replace_safety_filter','open','patient_safety_alert','2026-07-05',null,42000.00,'Diode CPC safety filter and calibration — removed pending replacement parts'),
    ('SLT-AIM-32','slit_lamp_integration_fault','beam_delivery_misalignment','realign_aiming_beam','escalated','nabh_finding','2026-07-04',null,12500.00,'Slit-lamp integration and focus offset — escalated to OEM engineer'),
    ('YAG-KKB-71','energy_output_out_of_tolerance','laser_cavity_aging','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',68000.00,'Multiple failures; unit removed and replaced, validated on install'),
    ('YAG-FRT-11','burst_mode_fault','q_switch_fault','replace_q_switch_module','verification_pending','internal_only','2026-07-05',null,26000.00,'Q-switch module replaced — verify burst stability next case list'),
    ('SLT-CMC-42','shot_counter_fault','counter_sensor_fault','repair_shot_counter','overdue','internal_only','2026-06-30',null,9500.00,'Shot counter repair past target date — vendor spare delay'),
    ('DCP-KIM-52','footswitch_fault','footswitch_wear','replace_footswitch','open','none','2026-07-07',null,3500.00,'Footswitch replacement scheduled at next PM visit')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ophthalmic_laser_qc_r3411 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3411_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_laser_qc_r3411)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_laser_qc_r3411 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3411_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3411_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3411_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  aiming_beam_fail bigint,
  safety_filter_fail bigint,
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
    count(*) filter (where l.aiming_beam_ok = false)::bigint,
    count(*) filter (where l.safety_filter_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_laser_qc_r3411 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3411_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3411_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3411_device_type_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_energy_error_pct numeric)
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
    round(avg(l.energy_output_error_pct), 2)
  from public.ophthalmic_laser_qc_r3411 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3411_device_type_department_matrix() from public, anon;
grant execute on function public.founder_r3411_device_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3411_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, aiming_beam_fail bigint, safety_filter_fail bigint)
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
    count(*) filter (where l.aiming_beam_ok = false)::bigint,
    count(*) filter (where l.safety_filter_ok = false)::bigint
  from public.ophthalmic_laser_qc_r3411 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3411_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3411_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3411_capa_status_board()
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
  from public.ophthalmic_laser_qc_capa_actions_r3411 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3411_capa_status_board() from public, anon;
grant execute on function public.founder_r3411_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3411_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_laser_qc_capa_actions_r3411)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_laser_qc_capa_actions_r3411 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3411_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3411_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3411_regulatory_impact_digest()
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
  from public.ophthalmic_laser_qc_capa_actions_r3411 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3411_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3411_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3411_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  burst_mode_ok text,
  safety_filter_ok text,
  aiming_beam_ok text,
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
    l.qc_verdict, l.burst_mode_ok,
    case when l.safety_filter_ok then 'ok' else 'fail' end,
    case when l.aiming_beam_ok then 'ok' else 'fail' end,
    l.notes
  from public.ophthalmic_laser_qc_r3411 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.aiming_beam_ok = false
     or l.focus_offset_accuracy_ok = false
     or l.burst_mode_ok in ('drift','fail')
     or l.slit_lamp_integration_ok = false
     or l.spot_targeting_ok = false
     or l.safety_filter_ok = false
     or l.footswitch_ok = false
     or l.shot_counter_ok = false
     or l.calibration_current = false
     or l.energy_output_error_pct >= 2.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3411_high_risk_queue() from public, anon;
grant execute on function public.founder_r3411_high_risk_queue() to authenticated;
