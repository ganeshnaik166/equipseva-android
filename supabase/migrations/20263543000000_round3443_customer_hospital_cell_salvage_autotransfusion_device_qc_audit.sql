-- Round 3443: Customer Hospital Cell-Salvage / Autotransfusion Device QC Audit
-- Intra-op cell-salvage / autotransfusion (Cell Saver) machine QC — parameter × device model × reference vs measured × deviation % × air-detector integrity × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: cell_salvage_qc_r3443 — per-device cell-salvage / autotransfusion QC checks
-- =============================================================================
create table if not exists public.cell_salvage_qc_r3443 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'centrifuge_rpm','wash_volume_ml','hematocrit_pct','pump_flow','air_detector','waste_valve'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  air_detector_ok boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cell_salvage_qc_r3443 enable row level security;

create index if not exists idx_cell_salvage_qc_r3443_org on public.cell_salvage_qc_r3443(organization_id);
create index if not exists idx_cell_salvage_qc_r3443_cal on public.cell_salvage_qc_r3443(calibration_date);
create index if not exists idx_cell_salvage_qc_r3443_verdict on public.cell_salvage_qc_r3443(qc_verdict);

-- =============================================================================
-- TABLE 2: cell_salvage_qc_capa_actions_r3443 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cell_salvage_qc_capa_actions_r3443 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cell_salvage_qc_r3443(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'centrifuge_speed_out_of_tolerance','wash_volume_out_of_tolerance','hematocrit_out_of_tolerance',
    'pump_flow_out_of_tolerance','air_detector_failure','waste_valve_leak',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'centrifuge_bearing_wear','pump_tubing_wear','optical_sensor_fouled','air_detector_fault',
    'valve_seal_degraded','sensor_calibration_drift','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_device','replace_centrifuge_bowl','replace_pump_tubing','clean_optical_sensor',
    'replace_air_detector','replace_waste_valve','update_software_config','retrain_perfusion_staff',
    'schedule_oem_service','remove_from_service','none_required'
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

alter table public.cell_salvage_qc_capa_actions_r3443 enable row level security;

create index if not exists idx_cell_salvage_qc_capa_r3443_log on public.cell_salvage_qc_capa_actions_r3443(qc_log_id);
create index if not exists idx_cell_salvage_qc_capa_r3443_status on public.cell_salvage_qc_capa_actions_r3443(capa_status);

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
  insert into public.cell_salvage_qc_r3443 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct,
    air_detector_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval::numeric, q.measval::numeric, q.devpct::numeric,
    q.air, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CS-APL-01','Cell Saver Elite+','centrifuge_rpm',
     5650,5620,0.5,true,'2026-07-06','pass','Centrifuge RPM within tolerance on quarterly QC'),
    ('Apollo Chennai','CS-APL-02','Cell Saver Elite+','wash_volume_ml',
     1000,995,0.5,true,'2026-07-06','pass','Wash volume accuracy nominal at 1000 ml setpoint'),
    ('Fortis Gurgaon','CS-FRT-11','Cell Saver 5+','hematocrit_pct',
     55,48,12.7,true,'2026-07-05','conditional_pass','Processed HCT 48% vs 55 target — 12.7% low, bowl optical sensor drift'),
    ('Fortis Gurgaon','CS-FRT-12','Cell Saver 5+','pump_flow',
     800,690,13.8,true,'2026-07-05','fail','Pump flow 690 vs 800 ml/min — 13.8% low, tubing occlusion suspected'),
    ('Manipal Bengaluru','CS-MNP-21','XTRA','air_detector',
     null,null,null,false,'2026-07-04','fail','Air-bubble detector failed challenge test — reinfusion line unsafe, removed'),
    ('Manipal Bengaluru','CS-MNP-22','XTRA','centrifuge_rpm',
     5000,5010,0.2,true,'2026-07-04','pass','Centrifuge speed matches setpoint on simulator check'),
    ('AIIMS Delhi','CS-AIM-31','autoLog IQ','hematocrit_pct',
     60,58,3.3,true,'2026-06-30','conditional_pass','Processed HCT 3.3% low — wash-program drift flagged for recheck'),
    ('AIIMS Delhi','CS-AIM-32','autoLog IQ','waste_valve',
     null,null,null,true,'2026-06-30','fail','Waste valve seal leaking — RBC loss to waste bag, seal replacement due'),
    ('CMC Vellore','CS-CMC-41','CATS','wash_volume_ml',
     750,742,1.1,true,'2026-06-29','pass','Wash volume accurate post-AMC service'),
    ('CMC Vellore','CS-CMC-42','CATS','pump_flow',
     600,606,1.0,true,'2026-06-29','pass','Pump flow within tolerance at 600 ml/min'),
    ('KIMS Hyderabad','CS-KIM-51','Cell Saver Elite','centrifuge_rpm',
     5650,5200,8.0,true,'2026-06-28','conditional_pass','Centrifuge 8% low — early bearing wear sign, monitor'),
    ('KIMS Hyderabad','CS-KIM-52','Cell Saver Elite','hematocrit_pct',
     55,54,1.8,true,'2026-06-28','pass','Processed HCT nominal at 54%'),
    ('Yashoda Hyderabad','CS-YSH-61','Cell Saver Elite+','air_detector',
     null,null,null,true,'2026-06-27','pass','Air-detector challenge test pass'),
    ('Kokilaben Mumbai','CS-KKB-71','Cell Saver 5+','pump_flow',
     800,560,30.0,false,'2026-06-27','fail','Pump flow 30% low with air-detector fault — multiple failures, removed from service'),
    ('Medanta Gurgaon','CS-MDT-81','XTRA','wash_volume_ml',
     1000,985,1.5,true,'2026-06-26','pass','Wash volume QC pass at 985 ml'),
    ('Narayana Bengaluru','CS-NRY-91','autoLog IQ','waste_valve',
     null,null,null,false,'2026-06-26','fail','Waste valve stuck open and air detector intermittent — calibration overdue, removed')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, air, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cell_salvage_qc_capa_actions_r3443 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CS-FRT-12','pump_flow_out_of_tolerance','pump_tubing_wear','replace_pump_tubing','in_progress','iso_13485_deviation','2026-07-09',null,9000.00,'Pump tubing set replaced; verify flow accuracy next case'),
    ('CS-MNP-21','air_detector_failure','air_detector_fault','replace_air_detector','escalated','patient_safety_alert','2026-07-07',null,28000.00,'Air-detector module fault — safety critical, escalated to OEM'),
    ('CS-AIM-32','waste_valve_leak','valve_seal_degraded','replace_waste_valve','open','nabh_finding','2026-07-06',null,7500.00,'Waste valve seal leaking — replacement kit ordered'),
    ('CS-KKB-71','pump_flow_out_of_tolerance','pump_tubing_wear','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-29',52000.00,'Device removed; tubing and air detector replaced and validated'),
    ('CS-FRT-11','hematocrit_out_of_tolerance','optical_sensor_fouled','clean_optical_sensor','verification_pending','internal_only','2026-07-08',null,3500.00,'Bowl optical sensor cleaned — verify HCT accuracy next case'),
    ('CS-NRY-91','calibration_overdue','sensor_calibration_drift','recalibrate_device','overdue','nabh_finding','2026-06-30',null,14000.00,'Calibration past due — vendor visit delayed'),
    ('CS-KIM-51','centrifuge_speed_out_of_tolerance','centrifuge_bearing_wear','schedule_oem_service','open','none','2026-07-10',null,0.00,'Centrifuge bearing wear — OEM service scheduled, monitor'),
    ('CS-AIM-31','hematocrit_out_of_tolerance','operator_setup_error','retrain_perfusion_staff','verification_pending','internal_only','2026-07-07',null,2000.00,'Wash program reset by operator — retrain and verify trend')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cell_salvage_qc_r3443 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3443_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cell_salvage_qc_r3443)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cell_salvage_qc_r3443 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3443_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3443_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3443_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  air_detector_fail bigint,
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
    count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 10)::bigint,
    count(*) filter (where l.air_detector_ok = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cell_salvage_qc_r3443 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3443_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3443_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3443_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 10)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cell_salvage_qc_r3443 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3443_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3443_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3443_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, air_detector_fail bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date as cal_month,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 10)::bigint,
    count(*) filter (where l.air_detector_ok = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cell_salvage_qc_r3443 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3443_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3443_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3443_capa_status_board()
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
  from public.cell_salvage_qc_capa_actions_r3443 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3443_capa_status_board() from public, anon;
grant execute on function public.founder_r3443_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3443_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cell_salvage_qc_capa_actions_r3443)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cell_salvage_qc_capa_actions_r3443 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3443_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3443_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3443_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  air_detector_fail bigint,
  avg_deviation_pct numeric,
  worst_deviation_pct numeric,
  failed_checks bigint
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
    count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 10)::bigint,
    count(*) filter (where l.air_detector_ok = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2),
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.cell_salvage_qc_r3443 l
  group by l.parameter
  order by count(*) filter (where l.deviation_pct is not null and abs(l.deviation_pct) > 10) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3443_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3443_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / air-detector fail / failed)
create or replace function public.founder_r3443_high_risk_queue()
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
  from public.cell_salvage_qc_r3443 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.air_detector_ok = false
     or (l.deviation_pct is not null and abs(l.deviation_pct) > 10)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3443_high_risk_queue() from public, anon;
grant execute on function public.founder_r3443_high_risk_queue() to authenticated;
