-- Round 3374: Customer Hospital Specialty-Bed & Pressure-Injury Support-Surface QC Audit
-- Specialty-bed QA — device type × bed-function × brake/rail safety × pump-pressure accuracy × low-pressure alarm × surface integrity × CPR-deflate × calibration × CAPA

-- =============================================================================
-- TABLE 1: specialty_bed_qc_r3374 — per-device specialty-bed / support-surface QC checks
-- =============================================================================
create table if not exists public.specialty_bed_qc_r3374 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'icu_electric_bed','bariatric_bed','low_air_loss_mattress','air_fluidized_therapy',
    'alternating_pressure_mattress','lateral_rotation_surface'
  )),
  ward text not null,
  check_date date not null,
  bed_function_ok boolean not null,
  brake_lock_ok boolean not null,
  side_rail_latch_ok boolean not null,
  pump_pressure_accuracy_ok text not null check (pump_pressure_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  low_pressure_alarm_test text not null check (low_pressure_alarm_test in (
    'pass','fail','not_tested'
  )),
  surface_integrity_ok text not null check (surface_integrity_ok in (
    'good','worn','puncture','replace_due'
  )),
  cpr_deflate_function_ok boolean not null,
  load_capacity_labeled boolean not null,
  cleaning_hygiene_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.specialty_bed_qc_r3374 enable row level security;

create index if not exists idx_specialty_bed_qc_r3374_org on public.specialty_bed_qc_r3374(organization_id);
create index if not exists idx_specialty_bed_qc_r3374_date on public.specialty_bed_qc_r3374(check_date);
create index if not exists idx_specialty_bed_qc_r3374_verdict on public.specialty_bed_qc_r3374(qc_verdict);

-- =============================================================================
-- TABLE 2: specialty_bed_qc_capa_actions_r3374 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.specialty_bed_qc_capa_actions_r3374 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.specialty_bed_qc_r3374(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'bed_function_failure','brake_lock_failure','side_rail_latch_failure','pump_pressure_failure',
    'low_pressure_alarm_failure','surface_integrity_defect','cpr_deflate_failure',
    'load_capacity_unlabeled','hygiene_deficiency','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_motor_wear','pressure_sensor_drift','mattress_cell_puncture','foam_surface_worn',
    'brake_mechanism_worn','rail_latch_broken','cpr_valve_stuck','label_missing_illegible',
    'cleaning_protocol_gap','control_board_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_pump_unit','recalibrate_pressure_sensor','replace_mattress_cells','replace_foam_surface',
    'repair_brake_mechanism','replace_rail_latch','replace_cpr_valve','reapply_load_label',
    'reinforce_cleaning_protocol','replace_control_board','remove_from_service','schedule_oem_service','none_required'
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

alter table public.specialty_bed_qc_capa_actions_r3374 enable row level security;

create index if not exists idx_specialty_bed_capa_r3374_log on public.specialty_bed_qc_capa_actions_r3374(qc_log_id);
create index if not exists idx_specialty_bed_capa_r3374_status on public.specialty_bed_qc_capa_actions_r3374(capa_status);

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

  -- 14 specialty-bed QC rows
  insert into public.specialty_bed_qc_r3374 (
    organization_id, hospital_name, device_code, device_type, ward, check_date,
    bed_function_ok, brake_lock_ok, side_rail_latch_ok, pump_pressure_accuracy_ok,
    low_pressure_alarm_test, surface_integrity_ok, cpr_deflate_function_ok,
    load_capacity_labeled, cleaning_hygiene_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.ward, q.cd::date,
    q.bfn, q.brk, q.rail, q.pump,
    q.alarm, q.surf, q.cpr,
    q.load, q.hyg, q.cal, q.qv, q.nt
  from (values
    ('Apollo Chennai','SB-APL-101','icu_electric_bed','ICU-1','2026-07-10',
     true,true,true,'not_applicable','not_tested','good',true,true,true,true,'pass','Quarterly QC — ICU electric bed height/tilt/trendelenburg nominal'),
    ('Apollo Chennai','SB-APL-102','alternating_pressure_mattress','ICU-1','2026-07-10',
     true,true,true,'ok','pass','good',true,true,true,true,'pass','Alternating-pressure cycle and alarm within spec'),
    ('Fortis Gurgaon','SB-FRT-201','low_air_loss_mattress','Wound-Care','2026-07-09',
     true,true,true,'drift','pass','worn',true,true,true,true,'conditional_pass','Pump pressure drift +12% and surface worn — recalibration booked'),
    ('Fortis Gurgaon','SB-FRT-202','bariatric_bed','Bariatric-1','2026-07-09',
     false,true,true,'not_applicable','not_tested','good',true,false,true,true,'conditional_pass','Trendelenburg tilt motor sluggish and load-capacity label missing'),
    ('Manipal Bengaluru','SB-MNP-301','air_fluidized_therapy','Burns-ICU','2026-07-08',
     true,true,true,'fail','fail','replace_due',true,true,false,false,'fail','Bead-temperature pump failed and low-pressure alarm silent — hygiene gap'),
    ('Manipal Bengaluru','SB-MNP-302','icu_electric_bed','ICU-2','2026-07-08',
     true,false,true,'not_applicable','not_tested','good',true,true,true,true,'conditional_pass','Foot-end brake lock intermittent — brake service due'),
    ('AIIMS Delhi','SB-AIM-401','alternating_pressure_mattress','Neuro-ICU','2026-07-07',
     true,true,false,'ok','pass','puncture',false,true,true,true,'removed_from_service','Cell puncture with air loss and CPR-deflate valve stuck — unit withdrawn'),
    ('AIIMS Delhi','SB-AIM-402','low_air_loss_mattress','Neuro-ICU','2026-07-07',
     true,true,true,'ok','pass','good',true,true,true,true,'pass','Annual QC clean pass'),
    ('CMC Vellore','SB-CMC-501','bariatric_bed','Bariatric-2','2026-07-06',
     true,true,true,'not_applicable','not_tested','good',true,true,true,false,'conditional_pass','Calibration certificate expired — recertification scheduled'),
    ('CMC Vellore','SB-CMC-502','lateral_rotation_surface','Pulmo-ICU','2026-07-06',
     true,true,true,'ok','pass','good',true,true,true,true,'pass','Lateral-rotation cycle verified — pass'),
    ('KIMS Hyderabad','SB-KIM-601','low_air_loss_mattress','Wound-Care','2026-07-05',
     true,true,true,'fail','not_tested','replace_due',true,true,false,true,'fail','Pump not holding pressure and surface degraded — replace surface'),
    ('KIMS Hyderabad','SB-KIM-602','icu_electric_bed','ICU-3','2026-07-05',
     true,true,true,'not_applicable','not_tested','good',true,true,true,true,'pass','Post-AMC verification pass'),
    ('Yashoda Hyderabad','SB-YSH-701','air_fluidized_therapy','Burns-ICU','2026-07-04',
     true,true,true,'drift','pass','worn',true,true,true,true,'conditional_pass','Fluidization pressure drift within recoverable range — monitor'),
    ('Rainbow Hyderabad','SB-RBW-801','alternating_pressure_mattress','PICU','2026-07-04',
     true,true,true,'ok','pass','good',true,true,true,true,'pass','Paediatric alternating-pressure surface QC pass')
  ) as q(hosp, code, dtype, ward, cd, bfn, brk, rail, pump, alarm, surf, cpr, load, hyg, cal, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.specialty_bed_qc_capa_actions_r3374 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SB-FRT-201','pump_pressure_failure','pressure_sensor_drift','recalibrate_pressure_sensor','in_progress','internal_only','2026-07-14',null,8500.00,'Pump drift +12% — pressure-sensor recalibration in progress'),
    ('SB-FRT-202','bed_function_failure','control_board_fault','replace_control_board','open','nabh_finding','2026-07-16',null,32000.00,'Trendelenburg tilt motor sluggish — control board replacement quoted'),
    ('SB-MNP-301','low_pressure_alarm_failure','control_board_fault','replace_control_board','escalated','patient_safety_alert','2026-07-12',null,145000.00,'Air-fluidized pump dead and silent low-pressure alarm — escalated to OEM'),
    ('SB-AIM-401','surface_integrity_defect','mattress_cell_puncture','replace_mattress_cells','closed','iso_13485_deviation','2026-07-11','2026-07-09',26000.00,'Punctured cells and stuck CPR valve — cells replaced, surface returned to service'),
    ('SB-KIM-601','pump_pressure_failure','pump_motor_wear','replace_pump_unit','open','nabh_finding','2026-07-15',null,22000.00,'Pump not holding pressure and surface degraded — replace pump unit'),
    ('SB-MNP-302','brake_lock_failure','brake_mechanism_worn','repair_brake_mechanism','in_progress','internal_only','2026-07-13',null,4500.00,'Foot-end brake intermittent — brake mechanism service in progress'),
    ('SB-CMC-501','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-02',null,6000.00,'Calibration certificate expired — OEM recertification past target date')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.specialty_bed_qc_r3374 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3374_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.specialty_bed_qc_r3374)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.specialty_bed_qc_r3374 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3374_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3374_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3374_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  pump_fail bigint,
  alarm_fail bigint,
  surface_defect bigint,
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
    count(*) filter (where l.pump_pressure_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.low_pressure_alarm_test = 'fail')::bigint,
    count(*) filter (where l.surface_integrity_ok in ('worn','puncture','replace_due'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.specialty_bed_qc_r3374 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3374_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3374_hospital_scorecard() to authenticated;

-- 3) Device-type × ward matrix
create or replace function public.founder_r3374_device_ward_matrix()
returns table(device_type text, ward text, checks bigint, passed bigint, failed bigint, defect_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.ward, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict in ('conditional_pass','fail','removed_from_service'))::numeric / nullif(count(*),0), 1)
  from public.specialty_bed_qc_r3374 l
  group by l.device_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3374_device_ward_matrix() from public, anon;
grant execute on function public.founder_r3374_device_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3374_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, pump_fail bigint, surface_defect bigint)
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
    count(*) filter (where l.pump_pressure_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.surface_integrity_ok in ('worn','puncture','replace_due'))::bigint
  from public.specialty_bed_qc_r3374 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3374_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3374_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3374_capa_status_board()
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
  from public.specialty_bed_qc_capa_actions_r3374 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3374_capa_status_board() from public, anon;
grant execute on function public.founder_r3374_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3374_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.specialty_bed_qc_capa_actions_r3374)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.specialty_bed_qc_capa_actions_r3374 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3374_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3374_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3374_regulatory_impact_digest()
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
  from public.specialty_bed_qc_capa_actions_r3374 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3374_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3374_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3374_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  ward text,
  check_date date,
  qc_verdict text,
  pump_pressure_accuracy_ok text,
  low_pressure_alarm_test text,
  surface_integrity_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.ward, l.check_date,
    l.qc_verdict, l.pump_pressure_accuracy_ok, l.low_pressure_alarm_test,
    l.surface_integrity_ok, l.notes
  from public.specialty_bed_qc_r3374 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.pump_pressure_accuracy_ok in ('drift','fail')
     or l.low_pressure_alarm_test = 'fail'
     or l.surface_integrity_ok in ('worn','puncture','replace_due')
     or l.bed_function_ok = false
     or l.brake_lock_ok = false
     or l.side_rail_latch_ok = false
     or l.cpr_deflate_function_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3374_high_risk_queue() from public, anon;
grant execute on function public.founder_r3374_high_risk_queue() to authenticated;
