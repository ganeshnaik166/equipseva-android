-- Round 3455: Customer Hospital Argon Plasma Coagulation (APC) Electrosurgery QC Audit
-- Hospital APC electrosurgery unit QC — argon flow, set/delivered power, ignition voltage, gas purity, leakage current
-- per parameter x device model x unit x tolerance x accuracy deviation x calibration currency x qc verdict x CAPA

-- =============================================================================
-- TABLE 1: argon_plasma_apc_qc_r3455 — per-parameter APC electrosurgery QC measurements
-- =============================================================================
create table if not exists public.argon_plasma_apc_qc_r3455 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  qc_ref text not null,
  device_code text not null,
  device_model text not null,
  unit text not null check (unit in (
    'endoscopy_suite','general_ot','gi_endoscopy','bronchoscopy','urology_ot'
  )),
  parameter text not null check (parameter in (
    'argon_flow_lpm','set_power_w','delivered_power_w','ignition_voltage_kv','gas_purity_pct','leakage_current_ua'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  tolerance_band_pct numeric(5,2),
  apc_mode text not null check (apc_mode in (
    'forced_apc','pulsed_apc','precise_apc'
  )),
  calibration_date date not null,
  next_calibration_due date,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.argon_plasma_apc_qc_r3455 enable row level security;

create index if not exists idx_argon_plasma_apc_qc_r3455_org on public.argon_plasma_apc_qc_r3455(organization_id);
create index if not exists idx_argon_plasma_apc_qc_r3455_caldate on public.argon_plasma_apc_qc_r3455(calibration_date);
create index if not exists idx_argon_plasma_apc_qc_r3455_verdict on public.argon_plasma_apc_qc_r3455(qc_verdict);

-- =============================================================================
-- TABLE 2: argon_plasma_apc_qc_capa_actions_r3455 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.argon_plasma_apc_qc_capa_actions_r3455 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.argon_plasma_apc_qc_r3455(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'argon_flow_out_of_tolerance','power_delivery_out_of_tolerance','ignition_failure',
    'gas_purity_low','excessive_leakage_current','calibration_overdue',
    'preventive_maintenance_due','electrode_probe_damaged'
  )),
  root_cause text not null check (root_cause in (
    'flow_sensor_drift','generator_output_drift','gas_regulator_fault','contaminated_argon_supply',
    'insulation_degradation','ignition_electrode_wear','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_flow_sensor','recalibrate_generator','replace_gas_regulator','replace_argon_cylinder',
    'repair_insulation','replace_ignition_electrode','update_software_config','retrain_ot_staff',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.argon_plasma_apc_qc_capa_actions_r3455 enable row level security;

create index if not exists idx_argon_plasma_apc_capa_r3455_log on public.argon_plasma_apc_qc_capa_actions_r3455(qc_log_id);
create index if not exists idx_argon_plasma_apc_capa_r3455_status on public.argon_plasma_apc_qc_capa_actions_r3455(capa_status);

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
  insert into public.argon_plasma_apc_qc_r3455 (
    organization_id, hospital_name, qc_ref, device_code, device_model, unit, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, tolerance_band_pct,
    apc_mode, calibration_date, next_calibration_due, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.qcref, q.dcode, q.dmodel, q.unit, q.param,
    q.refv, q.measv, q.devpct, q.wtol, q.tolband,
    q.amode, q.caldate::date, q.nextcal::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','APC-QC-01','APC-APL-01','ERBE VIO 300D','general_ot','set_power_w',
     40,39.4,1.5,true,5.0,'forced_apc','2026-07-03','2027-01-03',true,'pass','Set power within 1.5% deviation — QC pass'),
    ('Apollo Chennai','APC-QC-02','APC-APL-01','ERBE VIO 300D','general_ot','delivered_power_w',
     40,38.6,3.5,true,5.0,'forced_apc','2026-07-03','2027-01-03',true,'pass','Delivered power within tolerance band'),
    ('Apollo Chennai','APC-QC-03','APC-APL-02','ERBE APC 2','gi_endoscopy','argon_flow_lpm',
     2.0,1.94,3.0,true,5.0,'pulsed_apc','2026-07-03','2027-01-03',true,'pass','Argon flow nominal for GI endoscopy'),
    ('Fortis Gurgaon','APC-QC-04','APC-FRT-11','Olympus ESG-400','gi_endoscopy','argon_flow_lpm',
     2.0,1.78,11.0,false,5.0,'pulsed_apc','2026-07-02','2026-08-02',true,'fail','Argon flow 11% low — gas regulator suspected'),
    ('Fortis Gurgaon','APC-QC-05','APC-FRT-11','Olympus ESG-400','gi_endoscopy','gas_purity_pct',
     99.99,99.40,0.59,true,1.0,'pulsed_apc','2026-07-02','2026-08-02',true,'conditional_pass','Gas purity slightly low — monitor cylinder batch'),
    ('Fortis Gurgaon','APC-QC-06','APC-FRT-12','Covidien ForceTriad','general_ot','leakage_current_ua',
     10,14.5,45.0,false,10.0,'forced_apc','2026-07-02','2026-08-02',false,'fail','Leakage 14.5 uA exceeds 10 uA limit — insulation fault'),
    ('Manipal Bengaluru','APC-QC-07','APC-MNP-21','Bowa ARC 400','urology_ot','set_power_w',
     30,29.7,1.0,true,5.0,'precise_apc','2026-07-01','2027-01-01',true,'pass','Precise APC power for urology within tolerance'),
    ('Manipal Bengaluru','APC-QC-08','APC-MNP-22','ERBE VIO 300D','general_ot','ignition_voltage_kv',
     5.0,5.1,2.0,true,5.0,'forced_apc','2026-07-01','2027-01-01',true,'pass','Ignition voltage nominal'),
    ('AIIMS Delhi','APC-QC-09','APC-AIM-31','ERBE APC 2','bronchoscopy','delivered_power_w',
     25,23.2,7.2,false,5.0,'pulsed_apc','2026-06-30','2026-12-30',true,'fail','Delivered power 7.2% low in bronchoscopy mode'),
    ('AIIMS Delhi','APC-QC-10','APC-AIM-31','ERBE APC 2','bronchoscopy','ignition_voltage_kv',
     5.0,4.6,8.0,false,5.0,'pulsed_apc','2026-06-30','2026-12-30',true,'conditional_pass','Ignition voltage low — intermittent ignition delay'),
    ('CMC Vellore','APC-QC-11','APC-CMC-41','KLS Martin ME MB2','general_ot','set_power_w',
     45,44.6,0.9,true,5.0,'forced_apc','2026-06-29','2026-12-29',true,'pass','Set power QC pass'),
    ('CMC Vellore','APC-QC-12','APC-CMC-42','Olympus ESG-400','gi_endoscopy','gas_purity_pct',
     99.99,99.98,0.01,true,1.0,'pulsed_apc','2026-06-29','2026-12-29',true,'pass','Argon purity nominal'),
    ('KIMS Hyderabad','APC-QC-13','APC-KIM-51','Covidien ForceTriad','general_ot','leakage_current_ua',
     10,6.2,38.0,true,10.0,'forced_apc','2026-06-28','2026-12-28',true,'pass','Leakage current well below limit'),
    ('KIMS Hyderabad','APC-QC-14','APC-KIM-52','Bowa ARC 400','urology_ot','argon_flow_lpm',
     1.5,1.42,5.3,false,5.0,'precise_apc','2026-06-28','2026-07-28',false,'conditional_pass','Flow marginally over tolerance and calibration overdue'),
    ('Yashoda Hyderabad','APC-QC-15','APC-YSH-61','ERBE VIO 300D','endoscopy_suite','delivered_power_w',
     40,40.4,1.0,true,5.0,'forced_apc','2026-06-27','2026-12-27',true,'pass','Delivered power QC pass'),
    ('Kokilaben Mumbai','APC-QC-16','APC-KKB-71','ERBE APC 2','gi_endoscopy','leakage_current_ua',
     10,16.8,68.0,false,10.0,'pulsed_apc','2026-06-27','2026-07-27',false,'fail','Leakage 16.8 uA — unit removed pending insulation repair')
  ) as q(hosp, qcref, dcode, dmodel, unit, param, refv, measv, devpct, wtol, tolband, amode, caldate, nextcal, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via qc_ref
  insert into public.argon_plasma_apc_qc_capa_actions_r3455 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('APC-QC-04','argon_flow_out_of_tolerance','gas_regulator_fault','replace_gas_regulator','in_progress','iso_13485_deviation','2026-07-06',null,18000.00,'Flow 11% low — gas regulator replacement in progress'),
    ('APC-QC-05','gas_purity_low','contaminated_argon_supply','replace_argon_cylinder','verification_pending','internal_only','2026-07-05',null,9500.00,'Argon cylinder batch swapped — verify purity next QC'),
    ('APC-QC-06','excessive_leakage_current','insulation_degradation','repair_insulation','escalated','patient_safety_alert','2026-07-05',null,26000.00,'Leakage above limit — escalated, handpiece insulation repair'),
    ('APC-QC-09','power_delivery_out_of_tolerance','generator_output_drift','recalibrate_generator','open','nabh_finding','2026-07-04',null,15000.00,'Delivered power low in bronchoscopy — generator recalibration scheduled'),
    ('APC-QC-10','ignition_failure','ignition_electrode_wear','replace_ignition_electrode','open','internal_only','2026-07-04',null,7200.00,'Ignition voltage low — electrode wear, replacement ordered'),
    ('APC-QC-14','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','nabh_finding','2026-06-30',null,12000.00,'Flow marginal and calibration overdue — OEM service past due'),
    ('APC-QC-16','excessive_leakage_current','insulation_degradation','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-29',48000.00,'Unit removed; insulation repaired and revalidated'),
    ('APC-QC-02','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-10',null,0.00,'Routine PM due on ERBE VIO 300D — scheduling OEM visit')
  ) as q(qcref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.argon_plasma_apc_qc_r3455 e
    on e.organization_id = v_org_id and e.qc_ref = q.qcref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3455_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.argon_plasma_apc_qc_r3455)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.argon_plasma_apc_qc_r3455 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3455_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3455_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3455_device_model_scorecard()
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
  from public.argon_plasma_apc_qc_r3455 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3455_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3455_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3455_parameter_verdict_matrix()
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
  from public.argon_plasma_apc_qc_r3455 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3455_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3455_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3455_monthly_accuracy_trend()
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
  from public.argon_plasma_apc_qc_r3455 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3455_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3455_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3455_capa_status_board()
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
  from public.argon_plasma_apc_qc_capa_actions_r3455 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3455_capa_status_board() from public, anon;
grant execute on function public.founder_r3455_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3455_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.argon_plasma_apc_qc_capa_actions_r3455)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.argon_plasma_apc_qc_capa_actions_r3455 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3455_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3455_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3455_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  failed bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.argon_plasma_apc_qc_r3455 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3455_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3455_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / overdue)
create or replace function public.founder_r3455_high_risk_queue()
returns table(
  hospital_name text,
  qc_ref text,
  device_code text,
  device_model text,
  parameter text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
  calibration_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.qc_ref, l.device_code, l.device_model, l.parameter,
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.calibration_date, l.notes
  from public.argon_plasma_apc_qc_r3455 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3455_high_risk_queue() from public, anon;
grant execute on function public.founder_r3455_high_risk_queue() to authenticated;
