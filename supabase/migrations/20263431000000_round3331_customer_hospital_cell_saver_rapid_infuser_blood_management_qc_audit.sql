-- Round 3331: Customer Hospital Cell-Saver / Rapid-Infuser Intraoperative Blood-Management QC Audit
-- Blood-mgmt QA — device type × centrifuge bowl × wash quality × anticoag pump × flow accuracy × air-detect × warming temp × pressure alarm × disposable stock × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: cell_saver_qc_r3331 — per-device intraoperative blood-management QC checks
-- =============================================================================
create table if not exists public.cell_saver_qc_r3331 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'cell_saver_autotransfusion','rapid_infuser','fluid_warmer_high_flow','blood_warmer_inline'
  )),
  department text not null,
  check_date date not null,
  centrifuge_bowl_ok boolean not null,
  wash_quality_ok text not null check (wash_quality_ok in (
    'ok','suboptimal','fail','not_applicable'
  )),
  anticoagulant_pump_accuracy_ok boolean not null,
  flow_rate_accuracy_error_pct numeric(5,2),
  air_detector_test text not null check (air_detector_test in (
    'pass','fail','not_tested'
  )),
  warming_temp_accuracy_error_c numeric(4,1),
  pressure_alarm_ok boolean not null,
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

alter table public.cell_saver_qc_r3331 enable row level security;

create index if not exists idx_cell_saver_qc_r3331_org on public.cell_saver_qc_r3331(organization_id);
create index if not exists idx_cell_saver_qc_r3331_date on public.cell_saver_qc_r3331(check_date);
create index if not exists idx_cell_saver_qc_r3331_verdict on public.cell_saver_qc_r3331(qc_verdict);

-- =============================================================================
-- TABLE 2: cell_saver_qc_capa_actions_r3331 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cell_saver_qc_capa_actions_r3331 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cell_saver_qc_r3331(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'centrifuge_bowl_fault','wash_quality_deficiency','anticoagulant_pump_inaccuracy','flow_rate_deviation',
    'air_detector_failure','warming_temp_deviation','pressure_alarm_failure','disposable_stockout',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'centrifuge_bearing_wear','wash_valve_clog','pump_occlusion_sensor_drift','flow_sensor_drift',
    'air_detector_optics_dirty','heater_element_failing','pressure_transducer_fault','consumable_supply_delay',
    'calibration_lapsed','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_centrifuge_assembly','service_wash_valve','recalibrate_anticoagulant_pump','recalibrate_flow_sensor',
    'clean_air_detector_optics','replace_heater_module','replace_pressure_transducer','expedite_consumable_supply',
    'recalibrate_and_certify','retrain_perfusion_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.cell_saver_qc_capa_actions_r3331 enable row level security;

create index if not exists idx_cell_saver_capa_r3331_log on public.cell_saver_qc_capa_actions_r3331(qc_log_id);
create index if not exists idx_cell_saver_capa_r3331_status on public.cell_saver_qc_capa_actions_r3331(capa_status);

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
  insert into public.cell_saver_qc_r3331 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    centrifuge_bowl_ok, wash_quality_ok, anticoagulant_pump_accuracy_ok, flow_rate_accuracy_error_pct,
    air_detector_test, warming_temp_accuracy_error_c, pressure_alarm_ok, disposable_set_stock,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.cbowl, q.wash, q.acpump, q.ferr,
    q.airtest, q.wtemp, q.palarm, q.dstock,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','CS-APL-01','cell_saver_autotransfusion','Cardiac OT','2026-07-03',
     true,'ok',true,1.80,'pass',null,true,'adequate',true,'pass','Haemonetics Cell Saver Elite — quarterly QC, all nominal'),
    ('Apollo Chennai','RI-APL-02','rapid_infuser','Trauma OT','2026-07-03',
     true,'not_applicable',true,7.40,'pass',0.8,true,'adequate',true,'conditional_pass','Flow-rate error 7.4% above 5% tolerance — recheck booked'),
    ('Fortis Gurgaon','CS-FRT-01','cell_saver_autotransfusion','Cardiac OT','2026-07-02',
     true,'suboptimal',true,2.10,'pass',null,true,'low',true,'conditional_pass','Washed-RBC haematocrit low — wash quality suboptimal'),
    ('Fortis Gurgaon','RI-FRT-02','rapid_infuser','Trauma OT','2026-07-02',
     true,'not_applicable',true,3.20,'fail',2.6,true,'adequate',true,'removed_from_service','Air detector missed injected air bolus — unit pulled'),
    ('Manipal Bengaluru','FW-MNP-01','fluid_warmer_high_flow','General OT','2026-07-01',
     true,'not_applicable',true,null,'pass',3.4,false,'adequate',true,'fail','Warming temp 3.4C off and pressure alarm silent on test'),
    ('Manipal Bengaluru','BW-MNP-02','blood_warmer_inline','Blood Bank OT','2026-07-01',
     true,'not_applicable',true,null,'pass',0.6,true,'adequate',true,'pass','Inline blood warmer within spec'),
    ('AIIMS Delhi','CS-AIM-01','cell_saver_autotransfusion','Cardiac OT','2026-06-30',
     false,'fail',true,2.50,'pass',null,true,'adequate',true,'fail','Centrifuge bowl imbalance and wash fail — bowl replaced'),
    ('AIIMS Delhi','CS-AIM-02','cell_saver_autotransfusion','CTVS OT','2026-06-30',
     true,'ok',false,5.80,'pass',null,true,'adequate',true,'conditional_pass','Heparin anticoagulant pump accuracy off — recalibration booked'),
    ('CMC Vellore','RI-CMC-01','rapid_infuser','Trauma OT','2026-06-29',
     true,'not_applicable',true,1.40,'pass',0.9,true,'adequate',true,'pass','Belmont rapid infuser routine QC pass'),
    ('CMC Vellore','FW-CMC-02','fluid_warmer_high_flow','General OT','2026-06-29',
     true,'not_applicable',true,null,'not_tested',4.2,true,'low',false,'fail','Warming temp 4.2C high, calibration lapsed, air-detect not tested'),
    ('KIMS Hyderabad','CS-KIM-01','cell_saver_autotransfusion','Cardiac OT','2026-06-28',
     true,'ok',true,1.10,'pass',null,true,'adequate',true,'pass','Haemonetics Cell Saver Elite QC pass'),
    ('KIMS Hyderabad','BW-KIM-02','blood_warmer_inline','Blood Bank OT','2026-06-28',
     true,'not_applicable',true,null,'pass',2.1,false,'adequate',true,'conditional_pass','Inline warmer temp 2.1C off and pressure alarm test slow'),
    ('Medanta Gurugram','RI-MDT-01','rapid_infuser','Trauma OT','2026-06-27',
     true,'not_applicable',true,null,'not_tested',null,true,'out_of_stock',true,'conditional_pass','Disposable warming set out of stock — QC deferred on consumables'),
    ('Narayana Health Bengaluru','CS-NAR-01','cell_saver_autotransfusion','CTVS OT','2026-06-27',
     true,'ok',true,0.90,'pass',null,true,'adequate',true,'pass','Post-AMC verification pass')
  ) as q(hosp, dcode, dtype, dept, cdate, cbowl, wash, acpump, ferr, airtest, wtemp, palarm, dstock, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cell_saver_qc_capa_actions_r3331 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RI-FRT-02','air_detector_failure','air_detector_optics_dirty','clean_air_detector_optics','in_progress','patient_safety_alert','2026-07-06',null,16000.00,'Air-detect optics cleaned — awaiting air-bolus re-challenge test'),
    ('FW-MNP-01','pressure_alarm_failure','pressure_transducer_fault','replace_pressure_transducer','escalated','cdsco_notifiable','2026-07-05',null,38000.00,'Pressure alarm silent at 300 mmHg — escalated to OEM engineer'),
    ('CS-AIM-01','centrifuge_bowl_fault','centrifuge_bearing_wear','replace_centrifuge_assembly','closed','iso_13485_deviation','2026-07-01','2026-06-30',72000.00,'Bowl and centrifuge assembly replaced, re-run within spec'),
    ('CS-AIM-02','anticoagulant_pump_inaccuracy','pump_occlusion_sensor_drift','recalibrate_anticoagulant_pump','open','nabh_finding','2026-07-08',null,9000.00,'Heparin pump recalibration kit on order'),
    ('FW-CMC-02','calibration_overdue','calibration_lapsed','recalibrate_and_certify','open','nabh_finding','2026-07-07',null,15000.00,'Calibration lapsed — full recalibration and certificate due'),
    ('RI-MDT-01','disposable_stockout','consumable_supply_delay','expedite_consumable_supply','verification_pending','internal_only','2026-07-04',null,0.00,'Warming set PO expedited — verify QC on receipt'),
    ('CS-FRT-01','wash_quality_deficiency','wash_valve_clog','service_wash_valve','overdue','internal_only','2026-06-26',null,11000.00,'Wash valve service past target date — AMC vendor delayed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cell_saver_qc_r3331 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3331_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cell_saver_qc_r3331)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cell_saver_qc_r3331 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3331_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3331_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3331_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  wash_fail bigint,
  air_detect_fail bigint,
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
    count(*) filter (where l.wash_quality_ok in ('suboptimal','fail'))::bigint,
    count(*) filter (where l.air_detector_test = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cell_saver_qc_r3331 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3331_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3331_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3331_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_flow_error_pct numeric, avg_warming_temp_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.flow_rate_accuracy_error_pct), 2),
    round(avg(l.warming_temp_accuracy_error_c), 1)
  from public.cell_saver_qc_r3331 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3331_device_department_matrix() from public, anon;
grant execute on function public.founder_r3331_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3331_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, wash_fail bigint, air_detect_fail bigint)
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
    count(*) filter (where l.wash_quality_ok in ('suboptimal','fail'))::bigint,
    count(*) filter (where l.air_detector_test = 'fail')::bigint
  from public.cell_saver_qc_r3331 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3331_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3331_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3331_capa_status_board()
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
  from public.cell_saver_qc_capa_actions_r3331 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3331_capa_status_board() from public, anon;
grant execute on function public.founder_r3331_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3331_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cell_saver_qc_capa_actions_r3331)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cell_saver_qc_capa_actions_r3331 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3331_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3331_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3331_regulatory_impact_digest()
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
  from public.cell_saver_qc_capa_actions_r3331 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3331_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3331_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3331_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  wash_quality_ok text,
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
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.wash_quality_ok, l.air_detector_test, l.disposable_set_stock, l.notes
  from public.cell_saver_qc_r3331 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.wash_quality_ok in ('suboptimal','fail')
     or l.air_detector_test = 'fail'
     or l.centrifuge_bowl_ok = false
     or l.anticoagulant_pump_accuracy_ok = false
     or l.pressure_alarm_ok = false
     or l.calibration_current = false
     or l.disposable_set_stock = 'out_of_stock'
     or l.flow_rate_accuracy_error_pct > 5
     or l.warming_temp_accuracy_error_c > 2
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3331_high_risk_queue() from public, anon;
grant execute on function public.founder_r3331_high_risk_queue() to authenticated;
