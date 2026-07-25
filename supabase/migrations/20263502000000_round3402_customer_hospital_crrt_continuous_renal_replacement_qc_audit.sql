-- Round 3402: Customer Hospital CRRT (Continuous Renal Replacement Therapy) Machine QC Audit
-- ICU acute dialysis QA — machine type × ICU unit × blood-pump flow accuracy × fluid-balance accuracy × scale cal × pressure sensor × air detector × blood-leak detector × warmer temp × anticoagulation pump × alarm/battery × disposable stock × calibration × CAPA

-- =============================================================================
-- TABLE 1: crrt_qc_r3402 — per-machine CRRT QC checks
-- =============================================================================
create table if not exists public.crrt_qc_r3402 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  machine_code text not null,
  machine_type text not null check (machine_type in (
    'crrt_cvvh','crrt_cvvhd','crrt_cvvhdf','sled_machine','hybrid_crrt'
  )),
  icu_unit text not null check (icu_unit in (
    'medical_icu','surgical_icu','nephrology_hdu','cardiac_icu','pediatric_icu'
  )),
  check_date date not null,
  blood_pump_flow_accuracy_error_pct numeric(5,2),
  fluid_balance_accuracy_error_ml numeric(7,2),
  scale_calibration_ok boolean not null,
  pressure_sensor_ok text not null check (pressure_sensor_ok in (
    'ok','drift','fail'
  )),
  air_detector_test text not null check (air_detector_test in (
    'pass','fail','not_tested'
  )),
  blood_leak_detector_ok boolean not null,
  warmer_temp_accuracy_ok boolean not null,
  anticoagulation_pump_ok boolean not null,
  alarm_battery_test text not null check (alarm_battery_test in (
    'pass','fail','not_tested'
  )),
  disposable_set_stock text not null check (disposable_set_stock in (
    'adequate','low','out_of_stock'
  )),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crrt_qc_r3402 enable row level security;

create index if not exists idx_crrt_qc_r3402_org on public.crrt_qc_r3402(organization_id);
create index if not exists idx_crrt_qc_r3402_date on public.crrt_qc_r3402(check_date);
create index if not exists idx_crrt_qc_r3402_verdict on public.crrt_qc_r3402(qc_verdict);

-- =============================================================================
-- TABLE 2: crrt_qc_capa_actions_r3402 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.crrt_qc_capa_actions_r3402 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.crrt_qc_r3402(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'blood_pump_flow_out_of_tolerance','fluid_balance_accuracy_error','scale_calibration_drift',
    'pressure_sensor_fault','air_detector_failure','blood_leak_detector_failure',
    'warmer_temp_inaccuracy','anticoagulation_pump_fault','alarm_battery_failure',
    'disposable_set_stockout','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_tubing_wear','load_cell_drift','pressure_transducer_fault','air_sensor_degraded',
    'blood_leak_optical_fouled','heater_element_fault','syringe_pump_mechanism_fault',
    'battery_end_of_life','supply_chain_delay','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_pump_segment','recalibrate_scale','replace_pressure_sensor','replace_air_detector',
    'replace_blood_leak_detector','replace_warmer_element','service_anticoagulation_pump',
    'replace_battery','expedite_disposable_restock','update_software_config','retrain_dialysis_staff',
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

alter table public.crrt_qc_capa_actions_r3402 enable row level security;

create index if not exists idx_crrt_qc_capa_r3402_log on public.crrt_qc_capa_actions_r3402(qc_log_id);
create index if not exists idx_crrt_qc_capa_r3402_status on public.crrt_qc_capa_actions_r3402(capa_status);

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

  -- 14 CRRT QC check rows
  insert into public.crrt_qc_r3402 (
    org_id, organization_id, hospital_name, machine_code, machine_type, icu_unit, check_date,
    blood_pump_flow_accuracy_error_pct, fluid_balance_accuracy_error_ml, scale_calibration_ok,
    pressure_sensor_ok, air_detector_test, blood_leak_detector_ok,
    warmer_temp_accuracy_ok, anticoagulation_pump_ok, alarm_battery_test,
    disposable_set_stock, calibration_current, qc_verdict, notes
  )
  select v_org_id, v_org_id, q.hosp, q.mcode, q.mtype, q.unit, q.cdate::date,
    q.bpflow, q.fbal, q.scalecal,
    q.psensor, q.airdet, q.leakdet,
    q.warmer, q.anticoag, q.alarmbat,
    q.stock, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','CRRT-APL-01','crrt_cvvhdf','medical_icu','2026-07-10',
     1.2,15.0,true,'ok','pass',true,true,true,'pass','adequate',true,'pass','Quarterly QC — CVVHDF machine within all tolerances'),
    ('Apollo Chennai','CRRT-APL-02','crrt_cvvh','nephrology_hdu','2026-07-10',
     0.8,20.0,true,'ok','pass',true,true,true,'pass','adequate',true,'pass','CVVH blood-pump and fluid balance nominal'),
    ('Fortis Gurgaon','CRRT-FRT-11','crrt_cvvhd','surgical_icu','2026-07-09',
     3.5,45.0,true,'drift','pass',true,true,true,'pass','low',true,'conditional_pass','Pressure sensor drift + fluid balance 45 ml error, disposable stock low'),
    ('Fortis Gurgaon','CRRT-FRT-12','crrt_cvvhdf','medical_icu','2026-07-09',
     6.2,120.0,false,'fail','pass',true,true,true,'pass','adequate',true,'fail','Blood-pump flow 6.2% error, scale cal failed and pressure sensor fail'),
    ('Manipal Bengaluru','CRRT-MNP-21','sled_machine','nephrology_hdu','2026-07-08',
     null,30.0,true,'ok','not_tested',false,true,true,'not_tested','low',false,'removed_from_service','Blood-leak detector failed and calibration overdue — removed from service'),
    ('Manipal Bengaluru','CRRT-MNP-22','hybrid_crrt','cardiac_icu','2026-07-08',
     1.0,18.0,true,'ok','pass',true,true,true,'pass','adequate',true,'pass','Hybrid CRRT QC nominal post-AMC'),
    ('AIIMS Delhi','CRRT-AIM-31','crrt_cvvh','pediatric_icu','2026-07-07',
     2.1,25.0,true,'ok','pass',true,false,true,'pass','adequate',true,'conditional_pass','Warmer temp accuracy out of band — flagged, pediatric CRRT'),
    ('AIIMS Delhi','CRRT-AIM-32','crrt_cvvhdf','medical_icu','2026-07-07',
     4.8,90.0,true,'drift','fail',true,true,false,'pass','adequate',true,'fail','Air-detector test failed and anticoagulation pump fault'),
    ('CMC Vellore','CRRT-CMC-41','crrt_cvvhd','surgical_icu','2026-07-06',
     0.9,12.0,true,'ok','pass',true,true,true,'pass','adequate',true,'pass','CVVHD machine QC pass'),
    ('CMC Vellore','CRRT-CMC-42','sled_machine','nephrology_hdu','2026-07-06',
     1.5,22.0,true,'ok','pass',true,true,true,'pass','out_of_stock',false,'conditional_pass','Disposable set out of stock and calibration overdue — recheck due'),
    ('KIMS Hyderabad','CRRT-KIM-51','crrt_cvvhdf','cardiac_icu','2026-07-05',
     1.1,16.0,true,'ok','pass',true,true,true,'pass','adequate',true,'pass','CVVHDF QC pass'),
    ('KIMS Hyderabad','CRRT-KIM-52','crrt_cvvh','medical_icu','2026-07-05',
     2.8,40.0,true,'drift','not_tested',true,true,true,'not_tested','low',true,'conditional_pass','Pressure sensor drift and alarm/battery not tested — recheck due'),
    ('Yashoda Hyderabad','CRRT-YSH-61','hybrid_crrt','surgical_icu','2026-07-04',
     0.7,14.0,true,'ok','pass',true,true,true,'pass','adequate',true,'pass','Hybrid CRRT analyser QC nominal'),
    ('Kokilaben Mumbai','CRRT-KKB-71','crrt_cvvhdf','medical_icu','2026-07-04',
     7.5,150.0,false,'fail','fail',false,false,false,'fail','out_of_stock',false,'removed_from_service','Multiple failures across pump/scale/sensors — removed from service')
  ) as q(hosp, mcode, mtype, unit, cdate, bpflow, fbal, scalecal, psensor, airdet, leakdet, warmer, anticoag, alarmbat, stock, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via machine_code
  insert into public.crrt_qc_capa_actions_r3402 (
    org_id, organization_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CRRT-FRT-12','blood_pump_flow_out_of_tolerance','pump_tubing_wear','replace_pump_segment','in_progress','iso_13485_deviation','2026-07-13',null,12000.00,'Pump segment replaced; scale recal and reference check pending'),
    ('CRRT-MNP-21','blood_leak_detector_failure','blood_leak_optical_fouled','replace_blood_leak_detector','open','patient_safety_alert','2026-07-12',null,28000.00,'Optical blood-leak detector fouled — replacement kit ordered'),
    ('CRRT-AIM-32','air_detector_failure','air_sensor_degraded','replace_air_detector','escalated','patient_safety_alert','2026-07-11',null,18500.00,'Air detector fail with anticoag fault — escalated to OEM'),
    ('CRRT-KKB-71','preventive_maintenance_due','preventive_service_backlog','remove_from_service','closed','cdsco_notifiable','2026-07-08','2026-07-05',65000.00,'Multi-fault machine removed; replacement validated and returned'),
    ('CRRT-FRT-11','pressure_sensor_fault','pressure_transducer_fault','replace_pressure_sensor','verification_pending','internal_only','2026-07-12',null,9500.00,'Pressure transducer replaced — verify at next treatment'),
    ('CRRT-CMC-42','disposable_set_stockout','supply_chain_delay','expedite_disposable_restock','overdue','nabh_finding','2026-07-09',null,22000.00,'Disposable restock past target date — vendor expedite pending'),
    ('CRRT-KIM-52','calibration_overdue','software_config_error','update_software_config','open','none','2026-07-14',null,0.00,'Alarm/battery module reconfigured — recheck scheduled')
  ) as q(mcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.crrt_qc_r3402 e
    on e.organization_id = v_org_id and e.machine_code = q.mcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3402_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crrt_qc_r3402)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.crrt_qc_r3402 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3402_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3402_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3402_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  sensor_fail bigint,
  stock_issue bigint,
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
    count(*) filter (where l.pressure_sensor_ok = 'fail')::bigint,
    count(*) filter (where l.disposable_set_stock in ('low','out_of_stock'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.crrt_qc_r3402 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3402_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3402_hospital_scorecard() to authenticated;

-- 3) Machine-type × ICU-unit matrix
create or replace function public.founder_r3402_machine_type_unit_matrix()
returns table(machine_type text, icu_unit text, checks bigint, passed bigint, failed bigint, avg_flow_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.machine_type, l.icu_unit, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.blood_pump_flow_accuracy_error_pct), 2)
  from public.crrt_qc_r3402 l
  group by l.machine_type, l.icu_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3402_machine_type_unit_matrix() from public, anon;
grant execute on function public.founder_r3402_machine_type_unit_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3402_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, sensor_fail bigint, stock_issue bigint)
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
    count(*) filter (where l.pressure_sensor_ok = 'fail')::bigint,
    count(*) filter (where l.disposable_set_stock in ('low','out_of_stock'))::bigint
  from public.crrt_qc_r3402 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3402_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3402_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3402_capa_status_board()
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
  from public.crrt_qc_capa_actions_r3402 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3402_capa_status_board() from public, anon;
grant execute on function public.founder_r3402_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3402_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crrt_qc_capa_actions_r3402)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.crrt_qc_capa_actions_r3402 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3402_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3402_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3402_regulatory_impact_digest()
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
  from public.crrt_qc_capa_actions_r3402 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3402_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3402_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3402_high_risk_queue()
returns table(
  hospital_name text,
  machine_code text,
  machine_type text,
  icu_unit text,
  check_date date,
  qc_verdict text,
  pressure_sensor_ok text,
  air_detector_test text,
  disposable_set_stock text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.machine_code, l.machine_type, l.icu_unit, l.check_date,
    l.qc_verdict, l.pressure_sensor_ok, l.air_detector_test, l.disposable_set_stock, l.notes
  from public.crrt_qc_r3402 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.scale_calibration_ok = false
     or l.pressure_sensor_ok in ('drift','fail')
     or l.air_detector_test = 'fail'
     or l.blood_leak_detector_ok = false
     or l.warmer_temp_accuracy_ok = false
     or l.anticoagulation_pump_ok = false
     or l.alarm_battery_test = 'fail'
     or l.disposable_set_stock in ('low','out_of_stock')
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3402_high_risk_queue() from public, anon;
grant execute on function public.founder_r3402_high_risk_queue() to authenticated;
