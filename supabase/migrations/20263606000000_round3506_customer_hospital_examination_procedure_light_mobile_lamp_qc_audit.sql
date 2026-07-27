-- Round 3506: Customer Hospital Examination / Procedure Light (Mobile Lamp) QC Audit
-- Mobile exam/procedure lamp QA — device model × department × light source × parameter (illuminance, color temp,
-- CRI, focus diameter, battery runtime, flicker) × reference vs measured × deviation × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: exam_procedure_light_qc_r3506 — per-lamp photometric QC checks
-- =============================================================================
create table if not exists public.exam_procedure_light_qc_r3506 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  department text not null,
  light_source text not null check (light_source in (
    'led','halogen','hybrid','xenon'
  )),
  parameter text not null check (parameter in (
    'illuminance_lux','color_temp_k','cri_index','focus_diameter_cm','battery_runtime_min','flicker_pct'
  )),
  reference_value numeric(10,2) not null,
  measured_value numeric(10,2) not null,
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.exam_procedure_light_qc_r3506 enable row level security;

create index if not exists idx_exam_proc_light_qc_r3506_org on public.exam_procedure_light_qc_r3506(organization_id);
create index if not exists idx_exam_proc_light_qc_r3506_caldate on public.exam_procedure_light_qc_r3506(calibration_date);
create index if not exists idx_exam_proc_light_qc_r3506_verdict on public.exam_procedure_light_qc_r3506(qc_verdict);

-- =============================================================================
-- TABLE 2: exam_procedure_light_qc_capa_actions_r3506 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.exam_procedure_light_qc_capa_actions_r3506 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.exam_procedure_light_qc_r3506(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'illuminance_below_spec','color_temp_out_of_range','cri_below_spec','focus_diameter_out_of_spec',
    'battery_runtime_short','flicker_excessive','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'led_module_degraded','lamp_bulb_end_of_life','driver_board_fault','battery_end_of_life',
    'optics_lens_soiled','color_filter_aged','reflector_misaligned','power_supply_ripple',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_led_module','replace_lamp_bulb','replace_driver_board','replace_battery_pack',
    'clean_optics_lens','replace_color_filter','realign_reflector','recalibrate_photometer',
    'retrain_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.exam_procedure_light_qc_capa_actions_r3506 enable row level security;

create index if not exists idx_exam_proc_light_capa_r3506_log on public.exam_procedure_light_qc_capa_actions_r3506(qc_log_id);
create index if not exists idx_exam_proc_light_capa_r3506_status on public.exam_procedure_light_qc_capa_actions_r3506(capa_status);

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

  -- 16 QC check rows
  insert into public.exam_procedure_light_qc_r3506 (
    organization_id, hospital_name, device_code, device_model, department, light_source,
    parameter, reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.dept, q.src,
    q.param, q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','EXL-APL-01','Hanaulux Blue 130','ot','led',
     'illuminance_lux',130000,128500,-1.15,true,'2026-07-05','pass','OT exam lamp illuminance within spec'),
    ('Apollo Chennai','EXL-APL-02','Dr Mach LED 150','emergency','led',
     'color_temp_k',4500,4520,0.44,true,'2026-07-05','pass','Colour temperature nominal at 4500K target'),
    ('Fortis Gurgaon','EXL-FRT-11','Waldmann D-View','opd','led',
     'cri_index',96,91,-5.21,false,'2026-07-04','conditional_pass','CRI dropped below 95 target — LED module ageing'),
    ('Fortis Gurgaon','EXL-FRT-12','Hanaulux Aura','minor_ot','halogen',
     'illuminance_lux',100000,74000,-26.00,false,'2026-07-04','fail','Illuminance far below spec — halogen bulb degraded'),
    ('Manipal Bengaluru','EXL-MNP-21','Dr Mach M2','labour_room','led',
     'battery_runtime_min',120,58,-51.67,false,'2026-07-03','fail','Battery runtime collapsed to under one hour'),
    ('Manipal Bengaluru','EXL-MNP-22','Skytron Stellar','icu','led',
     'flicker_pct',3.0,2.4,-20.00,true,'2026-07-03','pass','Flicker well within safe range'),
    ('AIIMS Delhi','EXL-AIM-31','Hanaulux Blue 90','minor_ot','halogen',
     'focus_diameter_cm',20,26,30.00,false,'2026-07-02','conditional_pass','Focus field wider than spec — reflector misaligned'),
    ('AIIMS Delhi','EXL-AIM-32','Dr Mach LED 130','emergency','led',
     'illuminance_lux',120000,118000,-1.67,true,'2026-07-02','pass','Emergency exam lamp illuminance within tolerance'),
    ('CMC Vellore','EXL-CMC-41','Waldmann Halux','opd','halogen',
     'color_temp_k',4300,3850,-10.47,false,'2026-07-01','conditional_pass','Warm colour shift — halogen bulb ageing'),
    ('CMC Vellore','EXL-CMC-42','Skytron Stellar','ot','led',
     'cri_index',97,96,-1.03,true,'2026-07-01','pass','CRI within tolerance for surgical field'),
    ('KIMS Hyderabad','EXL-KIM-51','Dr Mach M2','labour_room','led',
     'battery_runtime_min',120,112,-6.67,true,'2026-06-30','pass','Battery runtime acceptable after service'),
    ('KIMS Hyderabad','EXL-KIM-52','Hanaulux Aura','minor_ot','hybrid',
     'flicker_pct',3.0,7.8,160.00,false,'2026-06-30','fail','Excessive flicker measured — driver board fault suspected'),
    ('Yashoda Hyderabad','EXL-YSH-61','Waldmann D-View','opd','led',
     'illuminance_lux',90000,88500,-1.67,true,'2026-06-29','pass','OPD procedure lamp illuminance nominal'),
    ('Yashoda Hyderabad','EXL-YSH-62','Dr Mach LED 150','emergency','led',
     'cri_index',96,88,-8.33,false,'2026-06-29','conditional_pass','CRI below spec — LED module replacement to be scheduled'),
    ('Kokilaben Mumbai','EXL-KKB-71','Skytron Stellar','ot','led',
     'focus_diameter_cm',18,18.5,2.78,true,'2026-06-28','pass','Focus field diameter within spec'),
    ('Kokilaben Mumbai','EXL-KKB-72','Hanaulux Blue 130','icu','xenon',
     'illuminance_lux',110000,62000,-43.64,false,'2026-06-28','fail','Severe illuminance loss — xenon module failing, removed pending repair')
  ) as q(hosp, dcode, model, dept, src, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.exam_procedure_light_qc_capa_actions_r3506 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EXL-FRT-11','cri_below_spec','led_module_degraded','replace_led_module','in_progress','iso_13485_deviation','2026-07-08',null,28000.00,'CRI below 95 target — LED module replacement scheduled'),
    ('EXL-FRT-12','illuminance_below_spec','lamp_bulb_end_of_life','replace_lamp_bulb','verification_pending','nabh_finding','2026-07-07',null,6500.00,'Halogen bulb at end of life — replaced, verify illuminance next round'),
    ('EXL-MNP-21','battery_runtime_short','battery_end_of_life','replace_battery_pack','open','patient_safety_alert','2026-07-06',null,18000.00,'Battery runtime under one hour — replacement pack ordered'),
    ('EXL-AIM-31','focus_diameter_out_of_spec','reflector_misaligned','realign_reflector','closed','internal_only','2026-07-05','2026-07-03',2500.00,'Reflector realigned — focus field back within spec'),
    ('EXL-CMC-41','color_temp_out_of_range','lamp_bulb_end_of_life','replace_lamp_bulb','in_progress','internal_only','2026-07-06',null,6500.00,'Warm colour shift — halogen bulb replacement in progress'),
    ('EXL-KIM-52','flicker_excessive','driver_board_fault','replace_driver_board','escalated','cdsco_notifiable','2026-07-05',null,34000.00,'Excessive flicker from driver fault — escalated to OEM'),
    ('EXL-YSH-62','cri_below_spec','led_module_degraded','replace_led_module','open','iso_13485_deviation','2026-07-09',null,28000.00,'CRI below spec — LED module replacement pending'),
    ('EXL-KKB-72','illuminance_below_spec','lamp_bulb_end_of_life','remove_from_service','escalated','patient_safety_alert','2026-07-04',null,52000.00,'Severe illuminance loss — lamp removed from service pending major repair')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.exam_procedure_light_qc_r3506 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3506_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.exam_procedure_light_qc_r3506)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.exam_procedure_light_qc_r3506 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3506_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3506_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3506_device_model_scorecard()
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
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.exam_procedure_light_qc_r3506 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3506_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3506_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3506_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.exam_procedure_light_qc_r3506 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3506_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3506_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3506_monthly_accuracy_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.exam_procedure_light_qc_r3506 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3506_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3506_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3506_capa_status_board()
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
  from public.exam_procedure_light_qc_capa_actions_r3506 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3506_capa_status_board() from public, anon;
grant execute on function public.founder_r3506_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3506_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.exam_procedure_light_qc_capa_actions_r3506)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.exam_procedure_light_qc_capa_actions_r3506 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3506_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3506_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3506_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.exam_procedure_light_qc_r3506 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3506_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3506_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3506_high_risk_queue()
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
  from public.exam_procedure_light_qc_r3506 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3506_high_risk_queue() from public, anon;
grant execute on function public.founder_r3506_high_risk_queue() to authenticated;
