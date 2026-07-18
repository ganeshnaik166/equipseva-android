-- Round 3283: Customer Hospital Apheresis / Cell-Separator & Blood-Irradiator QC Audit
-- Transfusion-medicine QA — device type × centrifuge balance × flow-rate accuracy × anticoagulant pump × irradiator dose delivery × dose-mapping × Rad-Sure indicator × alarm-safety × disposable stock × calibration × CAPA

-- =============================================================================
-- TABLE 1: apheresis_irradiator_qc_r3283 — per-device transfusion-medicine QC checks
-- =============================================================================
create table if not exists public.apheresis_irradiator_qc_r3283 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'apheresis_plateletpheresis','apheresis_plasmapheresis','stem_cell_collection',
    'xray_blood_irradiator','gamma_blood_irradiator'
  )),
  department text not null,
  check_date date not null,
  centrifuge_balance_ok boolean,
  flow_rate_accuracy_error_pct numeric(5,2),
  anticoagulant_pump_ok boolean,
  dose_delivery_error_pct numeric(5,2),
  dose_mapping_current boolean,
  radiation_indicator_check text not null check (radiation_indicator_check in (
    'pass','fail','not_applicable'
  )),
  alarm_safety_test text not null check (alarm_safety_test in (
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

alter table public.apheresis_irradiator_qc_r3283 enable row level security;

create index if not exists idx_apheresis_irr_r3283_org on public.apheresis_irradiator_qc_r3283(organization_id);
create index if not exists idx_apheresis_irr_r3283_date on public.apheresis_irradiator_qc_r3283(check_date);
create index if not exists idx_apheresis_irr_r3283_verdict on public.apheresis_irradiator_qc_r3283(qc_verdict);

-- =============================================================================
-- TABLE 2: apheresis_irradiator_qc_capa_actions_r3283 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.apheresis_irradiator_qc_capa_actions_r3283 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.apheresis_irradiator_qc_r3283(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'centrifuge_imbalance','flow_rate_deviation','anticoagulant_pump_fault','dose_delivery_deviation',
    'dose_mapping_expired','radiation_indicator_failure','alarm_safety_failure','disposable_stockout',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'centrifuge_bearing_wear','flow_sensor_drift','pump_occlusion_sensor_fault','source_decay_uncompensated',
    'timer_calibration_drift','indicator_lot_defect','alarm_config_error','supply_chain_delay',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_centrifuge_bearing','recalibrate_flow_sensor','replace_pump_module','recompute_dose_timer',
    'revalidate_dose_mapping','replace_indicator_lot','reconfigure_alarm','expedite_disposable_order',
    'retrain_apheresis_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_reportable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.apheresis_irradiator_qc_capa_actions_r3283 enable row level security;

create index if not exists idx_apheresis_irr_capa_r3283_log on public.apheresis_irradiator_qc_capa_actions_r3283(qc_log_id);
create index if not exists idx_apheresis_irr_capa_r3283_status on public.apheresis_irradiator_qc_capa_actions_r3283(capa_status);

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

  -- 14 per-device QC rows
  insert into public.apheresis_irradiator_qc_r3283 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    centrifuge_balance_ok, flow_rate_accuracy_error_pct, anticoagulant_pump_ok,
    dose_delivery_error_pct, dose_mapping_current, radiation_indicator_check,
    alarm_safety_test, disposable_set_stock, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dc, q.dt, q.dept, q.cd::date,
    q.cbo, q.fra, q.app,
    q.dde, q.dmc, q.ric,
    q.ast, q.dss, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','APH-APL-01','apheresis_plateletpheresis','Transfusion Medicine','2026-07-05',
     true,1.80,true,null,null,'not_applicable','pass','adequate',true,'pass','Routine plateletpheresis QC — all parameters within tolerance'),
    ('Apollo Chennai Greams Road','IRR-APL-02','gamma_blood_irradiator','Blood Bank','2026-07-05',
     null,null,null,2.40,true,'pass','pass','adequate',true,'pass','Gamma dose within 3% and Rad-Sure indicator confirmed'),
    ('Fortis Gurgaon','APH-FRT-03','apheresis_plasmapheresis','Transfusion Medicine','2026-07-04',
     true,6.30,true,null,null,'not_applicable','pass','low',true,'conditional_pass','Flow error 6.3% above 5% limit — recheck booked, kit stock low'),
    ('Fortis Gurgaon','IRR-FRT-04','xray_blood_irradiator','Blood Bank','2026-07-04',
     null,null,null,9.10,false,'fail','pass','adequate',false,'fail','Dose 9.1% high, dose-mapping expired, Rad-Sure indicator failed — quarantined'),
    ('Manipal Bengaluru Old Airport Road','APH-MNP-05','stem_cell_collection','Stem Cell Lab','2026-07-03',
     true,2.10,true,null,null,'not_applicable','pass','adequate',true,'pass','CD34 PBSC collection QC nominal'),
    ('Manipal Bengaluru Old Airport Road','APH-MNP-06','apheresis_plateletpheresis','Transfusion Medicine','2026-07-03',
     false,3.40,true,null,null,'not_applicable','not_tested','adequate',true,'conditional_pass','Centrifuge imbalance alarm during spin — bearing check due, alarm test deferred'),
    ('AIIMS Delhi Ansari Nagar','IRR-AIM-07','gamma_blood_irradiator','Blood Bank','2026-07-02',
     null,null,null,1.20,true,'pass','pass','adequate',true,'pass','Cs-137 source-decay compensated, annual dose map current'),
    ('AIIMS Delhi Ansari Nagar','APH-AIM-08','apheresis_plasmapheresis','Transfusion Medicine','2026-07-02',
     true,1.10,false,null,null,'not_applicable','fail','adequate',true,'fail','Anticoagulant pump occlusion sensor and alarm test both failed — unit stopped'),
    ('CMC Vellore','APH-CMC-09','stem_cell_collection','Stem Cell Lab','2026-07-01',
     true,4.80,true,null,null,'not_applicable','pass','low',false,'conditional_pass','Calibration overdue by 2 weeks, disposable set stock low'),
    ('CMC Vellore','IRR-CMC-10','xray_blood_irradiator','Blood Bank','2026-07-01',
     null,null,null,2.90,true,'pass','pass','adequate',true,'pass','X-ray irradiator annual dose validation pass'),
    ('KIMS Hyderabad','APH-KIM-11','apheresis_plateletpheresis','Transfusion Medicine','2026-06-30',
     true,0.90,true,null,null,'not_applicable','pass','out_of_stock',true,'conditional_pass','QC pass but plateletpheresis kits out of stock — collections paused'),
    ('KIMS Hyderabad','IRR-KIM-12','gamma_blood_irradiator','Blood Bank','2026-06-30',
     null,null,null,7.50,false,'fail','not_tested','adequate',false,'removed_from_service','Dose 7.5% high, mapping expired, indicator failed — removed pending AERB review'),
    ('Tata Memorial Mumbai','APH-TMH-13','stem_cell_collection','Stem Cell Lab','2026-06-29',
     true,1.50,true,null,null,'not_applicable','pass','adequate',true,'pass','Autologous PBSC collection QC clean'),
    ('PGIMER Chandigarh','APH-PGI-14','apheresis_plasmapheresis','Transfusion Medicine','2026-06-29',
     true,5.60,true,null,null,'not_applicable','pass','adequate',true,'conditional_pass','Therapeutic plasma exchange flow error 5.6% — flow sensor recal scheduled')
  ) as q(hosp, dc, dt, dept, cd, cbo, fra, app, dde, dmc, ric, ast, dss, cc, qv, nt);

  -- CAPA seed — attach to specific QC rows via device_code
  insert into public.apheresis_irradiator_qc_capa_actions_r3283 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IRR-FRT-04','dose_delivery_deviation','timer_calibration_drift','recompute_dose_timer','escalated','aerb_reportable','2026-07-08',null,55000.00,'X-ray dose 9.1% high and mapping expired — escalated to RSO and AERB liaison'),
    ('APH-AIM-08','anticoagulant_pump_fault','pump_occlusion_sensor_fault','replace_pump_module','open','patient_safety_alert','2026-07-09',null,42000.00,'ACD pump occlusion sensor failed — replacement module on order'),
    ('APH-MNP-06','centrifuge_imbalance','centrifuge_bearing_wear','replace_centrifuge_bearing','in_progress','nabh_finding','2026-07-10',null,36000.00,'Centrifuge imbalance alarm — bearing kit scheduled'),
    ('APH-FRT-03','flow_rate_deviation','flow_sensor_drift','recalibrate_flow_sensor','verification_pending','iso_15189_deviation','2026-07-07',null,9500.00,'Plasmapheresis flow 6.3% off — sensor recalibrated, awaiting re-run'),
    ('IRR-KIM-12','dose_mapping_expired','source_decay_uncompensated','revalidate_dose_mapping','open','cdsco_notifiable','2026-07-12',null,78000.00,'Gamma dose map expired and Cs-137 decay uncompensated — full revalidation booked'),
    ('APH-CMC-09','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-28',null,15000.00,'Cell separator calibration overdue — OEM service past target date'),
    ('APH-KIM-11','disposable_stockout','supply_chain_delay','expedite_disposable_order','closed','internal_only','2026-07-02','2026-07-06',12000.00,'Plateletpheresis kits expedited — stock replenished')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.apheresis_irradiator_qc_r3283 e
    on e.organization_id = v_org_id and e.device_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3283_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.apheresis_irradiator_qc_r3283)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.apheresis_irradiator_qc_r3283 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3283_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3283_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3283_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  indicator_fail bigint,
  alarm_fail bigint,
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
    count(*) filter (where l.radiation_indicator_check = 'fail')::bigint,
    count(*) filter (where l.alarm_safety_test in ('fail','not_tested'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.apheresis_irradiator_qc_r3283 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3283_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3283_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3283_device_department_matrix()
returns table(device_type text, department text, audits bigint, passed bigint, avg_flow_error_pct numeric, avg_dose_error_pct numeric)
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
    round(avg(l.dose_delivery_error_pct), 2)
  from public.apheresis_irradiator_qc_r3283 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3283_device_department_matrix() from public, anon;
grant execute on function public.founder_r3283_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3283_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, indicator_fail bigint, calibration_overdue bigint)
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
    count(*) filter (where l.radiation_indicator_check = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.apheresis_irradiator_qc_r3283 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3283_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3283_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3283_capa_status_board()
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
  from public.apheresis_irradiator_qc_capa_actions_r3283 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3283_capa_status_board() from public, anon;
grant execute on function public.founder_r3283_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3283_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.apheresis_irradiator_qc_capa_actions_r3283)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.apheresis_irradiator_qc_capa_actions_r3283 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3283_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3283_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3283_regulatory_impact_digest()
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
  from public.apheresis_irradiator_qc_capa_actions_r3283 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3283_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3283_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3283_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  radiation_indicator_check text,
  alarm_safety_test text,
  disposable_set_stock text,
  calibration_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.radiation_indicator_check, l.alarm_safety_test, l.disposable_set_stock,
    case when l.calibration_current then 'current' else 'overdue' end,
    l.notes
  from public.apheresis_irradiator_qc_r3283 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.radiation_indicator_check = 'fail'
     or l.alarm_safety_test in ('fail','not_tested')
     or l.disposable_set_stock in ('low','out_of_stock')
     or l.calibration_current = false
     or l.centrifuge_balance_ok = false
     or l.anticoagulant_pump_ok = false
     or l.dose_mapping_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3283_high_risk_queue() from public, anon;
grant execute on function public.founder_r3283_high_risk_queue() to authenticated;
