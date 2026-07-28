-- Round 3574: Customer Hospital Metabolic Cart (Indirect Calorimetry) QC Audit
-- Metabolic cart / indirect calorimetry QA — device model × department × gas-analyzer type × parameter
-- (VO2/VCO2/flow/O2-drift/CO2-drift/RQ) × reference vs measured × deviation × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: metabolic_cart_qc_r3574 — per-parameter indirect-calorimetry QC checks
-- =============================================================================
create table if not exists public.metabolic_cart_qc_r3574 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  department text not null check (department in (
    'metabolic_unit','medical_icu','surgical_icu','pulmonary_lab','nutrition_support'
  )),
  device_code text not null,
  device_model text not null,
  gas_analyzer_type text not null check (gas_analyzer_type in (
    'fuel_cell','paramagnetic','zirconia','infrared_co2'
  )),
  parameter text not null check (parameter in (
    'vo2_accuracy','vco2_accuracy','flow_accuracy_lmin','o2_sensor_drift','co2_sensor_drift','rq_accuracy'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  tolerance_limit_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  calibration_due_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.metabolic_cart_qc_r3574 enable row level security;

create index if not exists idx_metabolic_cart_qc_r3574_org on public.metabolic_cart_qc_r3574(organization_id);
create index if not exists idx_metabolic_cart_qc_r3574_date on public.metabolic_cart_qc_r3574(calibration_date);
create index if not exists idx_metabolic_cart_qc_r3574_verdict on public.metabolic_cart_qc_r3574(qc_verdict);

-- =============================================================================
-- TABLE 2: metabolic_cart_qc_capa_actions_r3574 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.metabolic_cart_qc_capa_actions_r3574 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.metabolic_cart_qc_r3574(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'vo2_accuracy_out_of_tolerance','vco2_accuracy_out_of_tolerance','flow_accuracy_out_of_tolerance',
    'o2_sensor_drift','co2_sensor_drift','rq_accuracy_out_of_tolerance',
    'calibration_overdue','gas_analyzer_degraded','flow_sensor_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'o2_fuel_cell_end_of_life','co2_sensor_degraded','flow_sensor_contamination','calibration_gas_expired',
    'sample_line_leak','water_trap_saturated','operator_setup_error','software_config_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_o2_fuel_cell','replace_co2_sensor','clean_replace_flow_sensor','replace_calibration_gas',
    'repair_sample_line_leak','replace_water_trap','recalibrate_analyzer','retrain_operator',
    'update_software_config','schedule_oem_service','none_required'
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

alter table public.metabolic_cart_qc_capa_actions_r3574 enable row level security;

create index if not exists idx_metabolic_cart_capa_r3574_log on public.metabolic_cart_qc_capa_actions_r3574(qc_log_id);
create index if not exists idx_metabolic_cart_capa_r3574_status on public.metabolic_cart_qc_capa_actions_r3574(capa_status);

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
  insert into public.metabolic_cart_qc_r3574 (
    organization_id, hospital_name, department, device_code, device_model, gas_analyzer_type,
    parameter, reference_value, measured_value, deviation_pct, tolerance_limit_pct,
    within_tolerance, calibration_date, calibration_due_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dept, q.dcode, q.dmodel, q.gat,
    q.param, q.refv, q.measv, q.dev, q.tol,
    q.wt, q.cdate::date, q.cdue::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','metabolic_unit','MC-APL-01','COSMED Quark RMR','fuel_cell',
     'vo2_accuracy',250.0,252.0,0.80,3.00,true,'2026-07-05','2026-10-05','pass','VO2 accuracy within 3% tolerance post-calibration'),
    ('Apollo Chennai','medical_icu','MC-APL-02','COSMED Quark RMR','infrared_co2',
     'vco2_accuracy',200.0,203.0,1.50,3.00,true,'2026-07-05','2026-10-05','pass','VCO2 accuracy within tolerance'),
    ('Fortis Gurgaon','metabolic_unit','MC-FRT-11','Vyaire Vyntus CPX','paramagnetic',
     'o2_sensor_drift',20.9,20.6,1.44,2.00,true,'2026-07-02','2026-10-02','conditional_pass','Paramagnetic O2 sensor slight drift, upward trend flagged'),
    ('Fortis Gurgaon','surgical_icu','MC-FRT-12','Vyaire Vyntus CPX','fuel_cell',
     'flow_accuracy_lmin',3.0,3.4,13.33,3.00,false,'2026-06-28','2026-09-28','fail','Flow accuracy out of tolerance, pneumotach fouled'),
    ('Manipal Bengaluru','pulmonary_lab','MC-MNP-21','MGC Ultima CardiO2','zirconia',
     'rq_accuracy',0.85,0.86,1.18,3.00,true,'2026-06-30','2026-09-30','pass','RQ accuracy within tolerance'),
    ('Manipal Bengaluru','nutrition_support','MC-MNP-22','MGC Ultima CardiO2','infrared_co2',
     'co2_sensor_drift',5.0,5.4,8.00,3.00,false,'2026-06-15','2026-09-15','fail','CO2 infrared sensor drift beyond tolerance'),
    ('AIIMS Delhi','medical_icu','MC-AIM-31','GE Carescape','fuel_cell',
     'o2_sensor_drift',20.9,20.4,2.39,2.00,false,'2026-06-20','2026-09-20','fail','O2 fuel cell near end of life, drift out of tolerance'),
    ('AIIMS Delhi','metabolic_unit','MC-AIM-32','GE Carescape','infrared_co2',
     'vco2_accuracy',200.0,205.0,2.50,3.00,true,'2026-07-01','2026-10-01','conditional_pass','VCO2 within tolerance but water trap saturating'),
    ('CMC Vellore','pulmonary_lab','MC-CMC-41','Cortex Metalyzer 3B','paramagnetic',
     'vo2_accuracy',300.0,303.0,1.00,3.00,true,'2026-05-28','2026-08-28','pass','VO2 accuracy pass at high workload'),
    ('CMC Vellore','metabolic_unit','MC-CMC-42','Cortex Metalyzer 3B','zirconia',
     'flow_accuracy_lmin',3.0,3.05,1.67,3.00,true,'2026-05-30','2026-08-30','pass','Flow accuracy within tolerance'),
    ('KIMS Hyderabad','medical_icu','MC-KIM-51','COSMED Quark RMR','fuel_cell',
     'rq_accuracy',0.85,0.90,5.88,3.00,false,'2026-06-10','2026-09-10','fail','RQ out of tolerance, calibration gas suspect'),
    ('KIMS Hyderabad','nutrition_support','MC-KIM-52','Vyaire Vyntus CPX','paramagnetic',
     'vco2_accuracy',200.0,201.0,0.50,3.00,true,'2026-07-03','2026-10-03','pass','VCO2 accuracy pass'),
    ('Yashoda Hyderabad','surgical_icu','MC-YSH-61','MGC Ultima CardiO2','infrared_co2',
     'co2_sensor_drift',5.0,5.1,2.00,3.00,true,'2026-07-04','2026-10-04','pass','CO2 sensor drift within tolerance'),
    ('Kokilaben Mumbai','metabolic_unit','MC-KKB-71','GE Carescape','fuel_cell',
     'vo2_accuracy',250.0,240.0,4.00,3.00,false,'2026-05-20','2026-08-20','fail','VO2 out of tolerance, analyzer calibration overdue'),
    ('Kokilaben Mumbai','pulmonary_lab','MC-KKB-72','Cortex Metalyzer 3B','paramagnetic',
     'o2_sensor_drift',20.9,20.8,0.48,2.00,true,'2026-07-06','2026-10-06','pass','O2 sensor drift minimal'),
    ('Medanta Gurgaon','medical_icu','MC-MDT-81','Vyaire Vyntus CPX','zirconia',
     'flow_accuracy_lmin',3.0,3.2,6.67,3.00,false,'2026-06-05','2026-09-05','conditional_pass','Flow accuracy borderline, turbine flow sensor recheck due')
  ) as q(hosp, dept, dcode, dmodel, gat, param, refv, measv, dev, tol, wt, cdate, cdue, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.metabolic_cart_qc_capa_actions_r3574 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MC-FRT-12','flow_accuracy_out_of_tolerance','flow_sensor_contamination','clean_replace_flow_sensor','in_progress','iso_13485_deviation','2026-07-10',null,12000.00,'Pneumotach cleaned and replaced, verify flow linearity'),
    ('MC-MNP-22','co2_sensor_drift','co2_sensor_degraded','replace_co2_sensor','open','nabh_finding','2026-07-12',null,38000.00,'CO2 infrared sensor drift beyond tolerance, replacement ordered'),
    ('MC-AIM-31','o2_sensor_drift','o2_fuel_cell_end_of_life','replace_o2_fuel_cell','escalated','patient_safety_alert','2026-07-08',null,9500.00,'O2 fuel cell end of life, escalated to OEM'),
    ('MC-KIM-51','rq_accuracy_out_of_tolerance','calibration_gas_expired','replace_calibration_gas','closed','internal_only','2026-07-02','2026-06-30',6500.00,'Calibration gas cylinder expired, replaced and recalibrated'),
    ('MC-KKB-71','calibration_overdue','calibration_gas_expired','recalibrate_analyzer','closed','cdsco_notifiable','2026-07-01','2026-06-27',15000.00,'Analyzer recalibrated with fresh gas, VO2 back in tolerance'),
    ('MC-MDT-81','flow_accuracy_out_of_tolerance','flow_sensor_contamination','clean_replace_flow_sensor','verification_pending','internal_only','2026-07-11',null,11000.00,'Turbine flow sensor cleaned, verify next QC cycle'),
    ('MC-AIM-32','gas_analyzer_degraded','water_trap_saturated','replace_water_trap','overdue','internal_only','2026-06-28',null,3200.00,'Water trap saturated, replacement past target date'),
    ('MC-FRT-11','o2_sensor_drift','sample_line_leak','repair_sample_line_leak','open','none','2026-07-14',null,4800.00,'Sample line leak suspected, O2 drift under investigation')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.metabolic_cart_qc_r3574 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3574_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.metabolic_cart_qc_r3574)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.metabolic_cart_qc_r3574 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3574_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3574_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3574_device_model_scorecard()
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
  from public.metabolic_cart_qc_r3574 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3574_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3574_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3574_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, out_of_tolerance bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.within_tolerance = false)::bigint
  from public.metabolic_cart_qc_r3574 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3574_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3574_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3574_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
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
    round(avg(l.deviation_pct), 2)
  from public.metabolic_cart_qc_r3574 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3574_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3574_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3574_capa_status_board()
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
  from public.metabolic_cart_qc_capa_actions_r3574 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3574_capa_status_board() from public, anon;
grant execute on function public.founder_r3574_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3574_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.metabolic_cart_qc_capa_actions_r3574)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.metabolic_cart_qc_capa_actions_r3574 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3574_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3574_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by regulatory impact)
create or replace function public.founder_r3574_accuracy_impact_digest()
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
  from public.metabolic_cart_qc_capa_actions_r3574 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3574_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3574_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3574_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  within_tolerance boolean,
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
    l.qc_verdict, l.deviation_pct, l.within_tolerance, l.notes
  from public.metabolic_cart_qc_r3574 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3574_high_risk_queue() from public, anon;
grant execute on function public.founder_r3574_high_risk_queue() to authenticated;
