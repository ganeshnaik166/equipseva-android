-- Round 3538: Customer Hospital Fetal-Scalp pH / Lactate Blood-Sampling QC Audit
-- Intrapartum fetal scalp pH / lactate blood-sampling analyzer QC — parameter × reference/measured × deviation × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: fetal_scalp_ph_qc_r3538 — per-device blood-sampling analyzer QC checks
-- =============================================================================
create table if not exists public.fetal_scalp_ph_qc_r3538 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'ph_accuracy','lactate_mmol_accuracy','sample_temp_c','carryover_pct','repeatability_cv','sample_volume_ul'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(8,2),
  within_tolerance boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fetal_scalp_ph_qc_r3538 enable row level security;

create index if not exists idx_fetal_scalp_ph_qc_r3538_org on public.fetal_scalp_ph_qc_r3538(organization_id);
create index if not exists idx_fetal_scalp_ph_qc_r3538_cal on public.fetal_scalp_ph_qc_r3538(calibration_date);
create index if not exists idx_fetal_scalp_ph_qc_r3538_verdict on public.fetal_scalp_ph_qc_r3538(qc_verdict);

-- =============================================================================
-- TABLE 2: fetal_scalp_ph_qc_capa_actions_r3538 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.fetal_scalp_ph_qc_capa_actions_r3538 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.fetal_scalp_ph_qc_r3538(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ph_out_of_tolerance','lactate_out_of_tolerance','sample_temp_deviation','carryover_high',
    'repeatability_poor','sample_volume_error','calibration_overdue','reference_material_expired','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'electrode_drift','reference_electrode_aged','sensor_membrane_fouled','calibrant_expired',
    'temperature_control_fault','insufficient_wash_cycle','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_analyzer','replace_ph_electrode','replace_reference_electrode','replace_sensor_membrane',
    'replace_calibrant_solution','service_temperature_module','increase_wash_cycles',
    'retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fetal_scalp_ph_qc_capa_actions_r3538 enable row level security;

create index if not exists idx_fetal_scalp_ph_capa_r3538_log on public.fetal_scalp_ph_qc_capa_actions_r3538(qc_log_id);
create index if not exists idx_fetal_scalp_ph_capa_r3538_status on public.fetal_scalp_ph_qc_capa_actions_r3538(capa_status);

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
  insert into public.fetal_scalp_ph_qc_r3538 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','ABL90-APL-01','Radiometer ABL90 Flex','ph_accuracy',
     7.40,7.39,0.14,true,'2026-07-05','pass','pH accuracy within +/-0.02 unit tolerance'),
    ('Apollo Chennai','ABL90-APL-01','Radiometer ABL90 Flex','lactate_mmol_accuracy',
     5.00,4.95,1.00,true,'2026-07-05','pass','Lactate QC control within tolerance'),
    ('Fortis Gurgaon','RP500-FRT-11','Siemens RAPIDPoint 500','ph_accuracy',
     7.40,7.36,0.54,false,'2026-07-04','conditional_pass','pH drift 0.04 units near tolerance limit — recheck'),
    ('Fortis Gurgaon','RP500-FRT-11','Siemens RAPIDPoint 500','carryover_pct',
     0.00,1.20,1.20,false,'2026-07-04','fail','Carryover 1.2% exceeds 1% limit — wash cycle deficiency'),
    ('Manipal Bengaluru','COBAS-MNP-21','Roche cobas b 221','lactate_mmol_accuracy',
     5.00,5.60,12.00,false,'2026-07-03','fail','Lactate reads +12% high — electrode drift suspected'),
    ('Manipal Bengaluru','COBAS-MNP-21','Roche cobas b 221','sample_temp_c',
     37.0,37.1,0.27,true,'2026-07-03','pass','Sample temperature within 0.5C spec'),
    ('AIIMS Delhi','NOVA-AIM-31','Nova Biomedical Stat Profile','repeatability_cv',
     2.0,1.6,-20.00,true,'2026-07-02','pass','Repeatability CV 1.6% under 2% maximum'),
    ('AIIMS Delhi','NOVA-AIM-31','Nova Biomedical Stat Profile','ph_accuracy',
     7.40,7.41,0.14,true,'2026-07-02','pass','pH QC nominal post-calibration'),
    ('CMC Vellore','GEM5K-CMC-41','Werfen GEM 5000','sample_volume_ul',
     60.0,66.0,10.00,false,'2026-07-01','conditional_pass','Sample volume high — aspiration check advised'),
    ('CMC Vellore','GEM5K-CMC-41','Werfen GEM 5000','carryover_pct',
     0.00,0.30,0.30,true,'2026-07-01','pass','Carryover 0.3% within 1% limit'),
    ('KIMS Hyderabad','ABL90-KIM-51','Radiometer ABL90 Flex','repeatability_cv',
     2.0,3.4,70.00,false,'2026-06-30','fail','Repeatability CV 3.4% exceeds max — sensor membrane fouled'),
    ('KIMS Hyderabad','ABL90-KIM-51','Radiometer ABL90 Flex','lactate_mmol_accuracy',
     5.00,4.90,2.00,true,'2026-06-30','pass','Lactate control within tolerance'),
    ('Yashoda Hyderabad','RP500-YSH-61','Siemens RAPIDPoint 500','sample_temp_c',
     37.0,38.2,3.24,false,'2026-06-29','fail','Sample temperature 38.2C — thermal control fault'),
    ('Yashoda Hyderabad','RP500-YSH-61','Siemens RAPIDPoint 500','ph_accuracy',
     7.40,7.38,0.27,true,'2026-06-29','pass','pH within tolerance post-service'),
    ('Kokilaben Mumbai','COBAS-KKB-71','Roche cobas b 221','sample_volume_ul',
     60.0,52.0,-13.33,false,'2026-06-28','fail','Sample volume low — short-sample errors, calibration overdue'),
    ('Kokilaben Mumbai','COBAS-KKB-71','Roche cobas b 221','ph_accuracy',
     7.40,7.44,0.54,false,'2026-06-28','conditional_pass','pH +0.04 drift — calibrant expiry flagged')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via (device_code, parameter)
  insert into public.fetal_scalp_ph_qc_capa_actions_r3538 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RP500-FRT-11','ph_accuracy','ph_out_of_tolerance','electrode_drift','recalibrate_analyzer','in_progress','iso_15189_deviation','2026-07-08',null,12000.00,'pH drift near limit — analyzer recalibrated, verify next batch'),
    ('RP500-FRT-11','carryover_pct','carryover_high','insufficient_wash_cycle','increase_wash_cycles','open','nabh_finding','2026-07-07',null,6000.00,'Carryover >1% — wash protocol revised and re-validated'),
    ('COBAS-MNP-21','lactate_mmol_accuracy','lactate_out_of_tolerance','reference_electrode_aged','replace_reference_electrode','escalated','patient_safety_alert','2026-07-06',null,18000.00,'Lactate +12% high — reference electrode replaced, escalated to OEM'),
    ('ABL90-KIM-51','repeatability_cv','repeatability_poor','sensor_membrane_fouled','replace_sensor_membrane','verification_pending','iso_15189_deviation','2026-07-05',null,22000.00,'Sensor membrane replaced — verify CV over 20 replicates'),
    ('RP500-YSH-61','sample_temp_c','sample_temp_deviation','temperature_control_fault','service_temperature_module','closed','cdsco_notifiable','2026-07-02','2026-06-30',34000.00,'Thermal module serviced and temperature validated'),
    ('COBAS-KKB-71','sample_volume_ul','sample_volume_error','calibrant_expired','replace_calibrant_solution','overdue','internal_only','2026-06-30',null,8000.00,'Calibrant expired — replacement past target date, vendor delay'),
    ('GEM5K-CMC-41','sample_volume_ul','sample_volume_error','operator_technique_error','retrain_lab_staff','open','internal_only','2026-07-04',null,0.00,'Aspiration technique retraining scheduled for labour-ward staff'),
    ('COBAS-KKB-71','ph_accuracy','ph_out_of_tolerance','calibrant_expired','replace_calibrant_solution','in_progress','nabh_finding','2026-07-01',null,8000.00,'pH drift traced to expired calibrant — replacing solution lot')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.fetal_scalp_ph_qc_r3538 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3538_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fetal_scalp_ph_qc_r3538)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fetal_scalp_ph_qc_r3538 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3538_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3538_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3538_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
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
  from public.fetal_scalp_ph_qc_r3538 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3538_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3538_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3538_parameter_verdict_matrix()
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
  from public.fetal_scalp_ph_qc_r3538 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3538_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3538_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3538_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.fetal_scalp_ph_qc_r3538 l
  where l.calibration_date is not null
  group by date_trunc('month', l.calibration_date)::date
  order by date_trunc('month', l.calibration_date)::date desc;
end;
$$;

revoke execute on function public.founder_r3538_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3538_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3538_capa_status_board()
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
  from public.fetal_scalp_ph_qc_capa_actions_r3538 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3538_capa_status_board() from public, anon;
grant execute on function public.founder_r3538_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3538_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fetal_scalp_ph_qc_capa_actions_r3538)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fetal_scalp_ph_qc_capa_actions_r3538 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3538_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3538_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3538_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  within_tolerance_pct numeric,
  avg_abs_deviation_pct numeric,
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1),
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.fetal_scalp_ph_qc_r3538 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3538_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3538_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3538_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
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
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.notes
  from public.fetal_scalp_ph_qc_r3538 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3538_high_risk_queue() from public, anon;
grant execute on function public.founder_r3538_high_risk_queue() to authenticated;
