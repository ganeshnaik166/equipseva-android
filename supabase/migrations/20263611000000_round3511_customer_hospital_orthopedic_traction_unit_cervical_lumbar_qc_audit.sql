-- Round 3511: Customer Hospital Orthopedic Traction Unit (Cervical/Lumbar) QC Audit
-- Ortho traction QA — device model x parameter (set/measured force, hold time, ramp rate, timer accuracy, e-stop response)
-- x reference vs measured vs deviation x within-tolerance x calibration currency x QC verdict x CAPA closure.

-- =============================================================================
-- TABLE 1: traction_unit_qc_r3511 — per-parameter traction unit QC measurements
-- =============================================================================
create table if not exists public.traction_unit_qc_r3511 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  qc_ref text not null,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'set_force_kg','measured_force_kg','hold_time_sec','ramp_rate','timer_accuracy_pct','estop_response_sec'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.traction_unit_qc_r3511 enable row level security;

create index if not exists idx_traction_unit_qc_r3511_org on public.traction_unit_qc_r3511(organization_id);
create index if not exists idx_traction_unit_qc_r3511_date on public.traction_unit_qc_r3511(calibration_date);
create index if not exists idx_traction_unit_qc_r3511_verdict on public.traction_unit_qc_r3511(qc_verdict);

-- =============================================================================
-- TABLE 2: traction_unit_qc_capa_actions_r3511 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.traction_unit_qc_capa_actions_r3511 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.traction_unit_qc_r3511(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'force_accuracy_out_of_tolerance','hold_time_drift','ramp_rate_deviation',
    'timer_accuracy_failure','estop_response_slow','calibration_overdue',
    'load_cell_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'load_cell_drift','worn_cable_pulley','control_board_fault','timer_circuit_fault',
    'estop_switch_degraded','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','actuator_wear'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_load_cell','replace_load_cell','replace_cable_pulley','replace_control_board',
    'adjust_timer_circuit','replace_estop_switch','update_software_config','retrain_ortho_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.traction_unit_qc_capa_actions_r3511 enable row level security;

create index if not exists idx_traction_unit_capa_r3511_log on public.traction_unit_qc_capa_actions_r3511(qc_log_id);
create index if not exists idx_traction_unit_capa_r3511_status on public.traction_unit_qc_capa_actions_r3511(capa_status);

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

  -- 16 QC measurement rows
  insert into public.traction_unit_qc_r3511 (
    organization_id, qc_ref, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.qcref, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('QC-APL-01','Apollo Chennai','TRC-APL-01','Chattanooga Triton DTS','set_force_kg',
     30.0,29.7,-1.0,true,'2026-07-05','pass','Cervical set-force within +/-3% tolerance'),
    ('QC-APL-02','Apollo Chennai','TRC-APL-01','Chattanooga Triton DTS','hold_time_sec',
     60.0,59.0,-1.7,true,'2026-07-05','pass','Hold timer accurate on 60s cervical program'),
    ('QC-APL-03','Apollo Chennai','TRC-APL-02','Enraf-Nonius Endomed 482','estop_response_sec',
     0.5,0.48,-4.0,true,'2026-07-05','pass','E-stop cut traction force within 0.5s limit'),
    ('QC-FRT-01','Fortis Gurgaon','TRC-FRT-11','BTL-16 Combi','measured_force_kg',
     25.0,26.8,7.2,false,'2026-07-04','fail','Lumbar measured force 7.2% high — load cell drift suspected'),
    ('QC-FRT-02','Fortis Gurgaon','TRC-FRT-11','BTL-16 Combi','ramp_rate',
     5.0,5.4,8.0,false,'2026-07-04','conditional_pass','Ramp rate 8% fast — flagged for control-board recheck'),
    ('QC-FRT-03','Fortis Gurgaon','TRC-FRT-12','Saunders Cervical HomeTrac','timer_accuracy_pct',
     100.0,96.0,-4.0,false,'2026-07-04','conditional_pass','Timer 4% slow at 15-min cervical setpoint'),
    ('QC-MNP-01','Manipal Bengaluru','TRC-MNP-21','Technomed TracForce X','set_force_kg',
     35.0,33.2,-5.1,false,'2026-07-03','fail','Cervical set-force 5.1% low — actuator wear'),
    ('QC-MNP-02','Manipal Bengaluru','TRC-MNP-21','Technomed TracForce X','hold_time_sec',
     45.0,44.5,-1.1,true,'2026-07-03','pass','Hold time nominal on 45s program'),
    ('QC-AIM-01','AIIMS Delhi','TRC-AIM-31','Chattanooga Triton DTS','estop_response_sec',
     0.5,0.72,44.0,false,'2026-07-02','fail','E-stop response 0.72s exceeds 0.5s safety limit'),
    ('QC-AIM-02','AIIMS Delhi','TRC-AIM-31','Chattanooga Triton DTS','measured_force_kg',
     20.0,20.3,1.5,true,'2026-07-02','pass','Lumbar measured force within tolerance'),
    ('QC-CMC-01','CMC Vellore','TRC-CMC-41','Enraf-Nonius Endomed 482','ramp_rate',
     4.0,4.1,2.5,true,'2026-07-01','pass','Ramp rate within +/-3% band'),
    ('QC-CMC-02','CMC Vellore','TRC-CMC-42','ITL Traction Pro','timer_accuracy_pct',
     100.0,99.2,-0.8,true,'2026-07-01','pass','Timer accuracy pass'),
    ('QC-KIM-01','KIMS Hyderabad','TRC-KIM-51','BTL-16 Combi','set_force_kg',
     28.0,27.6,-1.4,true,'2026-06-30','pass','Cervical set-force pass post-AMC'),
    ('QC-KIM-02','KIMS Hyderabad','TRC-KIM-51','BTL-16 Combi','hold_time_sec',
     90.0,85.0,-5.6,false,'2026-06-30','conditional_pass','Hold time 5.6% short — calibration overdue'),
    ('QC-YSH-01','Yashoda Hyderabad','TRC-YSH-61','Technomed TracForce X','timer_accuracy_pct',
     100.0,92.5,-7.5,false,'2026-06-29','fail','Timer 7.5% slow — timer circuit fault'),
    ('QC-KKB-01','Kokilaben Mumbai','TRC-KKB-71','Saunders Cervical HomeTrac','estop_response_sec',
     0.5,0.55,10.0,false,'2026-06-29','conditional_pass','E-stop 0.55s slightly over limit — monitor')
  ) as q(qcref, hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via qc_ref business key
  insert into public.traction_unit_qc_capa_actions_r3511 (
    organization_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('QC-FRT-01','force_accuracy_out_of_tolerance','load_cell_drift','recalibrate_load_cell','in_progress','iso_13485_deviation','Biomed Team Fortis','2026-07-08',null,12000.00,'Load cell re-cal in progress; verify next cycle'),
    ('QC-MNP-01','force_accuracy_out_of_tolerance','actuator_wear','replace_cable_pulley','open','nabh_finding','Manipal Biomed','2026-07-07',null,28000.00,'Actuator and cable-pulley wear — replacement kit ordered'),
    ('QC-AIM-01','estop_response_slow','estop_switch_degraded','replace_estop_switch','escalated','patient_safety_alert','AIIMS Clinical Eng','2026-07-05',null,9500.00,'E-stop exceeds safety limit — escalated, unit tagged out of service'),
    ('QC-YSH-01','timer_accuracy_failure','timer_circuit_fault','adjust_timer_circuit','verification_pending','internal_only','Yashoda Biomed','2026-07-04',null,6500.00,'Timer board adjusted — awaiting verification run'),
    ('QC-FRT-02','ramp_rate_deviation','control_board_fault','replace_control_board','open','internal_only','Fortis Biomed','2026-07-09',null,18000.00,'Ramp control board flagged — schedule replacement'),
    ('QC-KIM-02','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','nabh_finding','KIMS Biomed','2026-07-01',null,15000.00,'Calibration past due — OEM service visit delayed'),
    ('QC-KKB-01','estop_response_slow','estop_switch_degraded','replace_estop_switch','closed','cdsco_notifiable','Kokilaben Clinical Eng','2026-07-02','2026-06-30',9500.00,'E-stop switch replaced and response validated at 0.42s'),
    ('QC-FRT-03','timer_accuracy_failure','timer_circuit_fault','adjust_timer_circuit','in_progress','internal_only','Fortis Biomed','2026-07-08',null,6500.00,'Timer accuracy correction underway')
  ) as q(qcref, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.traction_unit_qc_r3511 e
    on e.organization_id = v_org_id and e.qc_ref = q.qcref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3511_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.traction_unit_qc_r3511)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.traction_unit_qc_r3511 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3511_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3511_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3511_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.traction_unit_qc_r3511 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3511_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3511_device_model_scorecard() to authenticated;

-- 3) Parameter x verdict matrix
create or replace function public.founder_r3511_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.traction_unit_qc_r3511 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3511_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3511_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3511_monthly_accuracy_trend()
returns table(
  cal_month text,
  checks bigint,
  passed bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.calibration_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.traction_unit_qc_r3511 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3511_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3511_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3511_capa_status_board()
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
  from public.traction_unit_qc_capa_actions_r3511 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3511_capa_status_board() from public, anon;
grant execute on function public.founder_r3511_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3511_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.traction_unit_qc_capa_actions_r3511)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.traction_unit_qc_capa_actions_r3511 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3511_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3511_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory impact digest
create or replace function public.founder_r3511_accuracy_impact_digest()
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
  from public.traction_unit_qc_capa_actions_r3511 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3511_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3511_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed concerns)
create or replace function public.founder_r3511_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.calibration_date,
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.notes
  from public.traction_unit_qc_r3511 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3511_high_risk_queue() from public, anon;
grant execute on function public.founder_r3511_high_risk_queue() to authenticated;
