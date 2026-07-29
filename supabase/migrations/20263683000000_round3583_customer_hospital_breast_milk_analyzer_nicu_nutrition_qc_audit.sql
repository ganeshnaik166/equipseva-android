-- Round 3583: Customer Hospital Human Breast-Milk Analyzer (NICU Nutrition) QC Audit
-- NICU human breast-milk analyzer QA — parameter (fat/protein/lactose/energy/total-solids/homogenizer speed)
-- x device model x reference vs measured x deviation % x within-tolerance x calibration x verdict x CAPA

-- =============================================================================
-- TABLE 1: breast_milk_analyzer_qc_r3583 — per-parameter analyzer accuracy QC checks
-- =============================================================================
create table if not exists public.breast_milk_analyzer_qc_r3583 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'fat_accuracy_gdl','protein_accuracy_gdl','lactose_accuracy_gdl',
    'energy_accuracy_kcal','total_solids_accuracy','homogenizer_speed_rpm'
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

alter table public.breast_milk_analyzer_qc_r3583 enable row level security;

create index if not exists idx_breast_milk_analyzer_qc_r3583_org on public.breast_milk_analyzer_qc_r3583(organization_id);
create index if not exists idx_breast_milk_analyzer_qc_r3583_cal on public.breast_milk_analyzer_qc_r3583(calibration_date);
create index if not exists idx_breast_milk_analyzer_qc_r3583_verdict on public.breast_milk_analyzer_qc_r3583(qc_verdict);

-- =============================================================================
-- TABLE 2: breast_milk_analyzer_qc_capa_actions_r3583 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.breast_milk_analyzer_qc_capa_actions_r3583 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.breast_milk_analyzer_qc_r3583(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'fat_accuracy_out_of_tolerance','protein_accuracy_out_of_tolerance','lactose_accuracy_out_of_tolerance',
    'energy_accuracy_out_of_tolerance','total_solids_accuracy_out_of_tolerance','homogenizer_speed_out_of_tolerance',
    'calibration_overdue','reference_standard_expired','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'infrared_source_drift','calibration_standard_expired','homogenizer_wear','optical_path_contamination',
    'sample_temperature_error','firmware_config_error','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_with_reference_standard','replace_reference_standard','service_homogenizer',
    'clean_optical_path','replace_infrared_source','update_firmware_config','retrain_lab_staff',
    'schedule_oem_service','remove_from_service','none_required'
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

alter table public.breast_milk_analyzer_qc_capa_actions_r3583 enable row level security;

create index if not exists idx_breast_milk_analyzer_capa_r3583_log on public.breast_milk_analyzer_qc_capa_actions_r3583(qc_log_id);
create index if not exists idx_breast_milk_analyzer_capa_r3583_status on public.breast_milk_analyzer_qc_capa_actions_r3583(capa_status);

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

  -- 16 analyzer QC check rows
  insert into public.breast_milk_analyzer_qc_r3583 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','BMA-APL-01','Miris HMA','fat_accuracy_gdl',
     3.50,3.52,0.57,true,'2026-07-05','pass','Fat channel within +/-2% tolerance — quarterly QC pass'),
    ('Apollo Chennai','BMA-APL-02','Miris HMA','protein_accuracy_gdl',
     1.20,1.19,-0.83,true,'2026-07-05','pass','Protein accuracy nominal against certified reference milk'),
    ('Fortis Gurgaon','BMA-FRT-11','Miris HMA v3','lactose_accuracy_gdl',
     6.80,6.72,-1.18,true,'2026-07-04','conditional_pass','Lactose bias trending negative near tolerance limit — monitor'),
    ('Fortis Gurgaon','BMA-FRT-12','Miris HMA v3','fat_accuracy_gdl',
     3.80,4.15,9.21,false,'2026-07-04','fail','Fat reading 9.2% high — outside tolerance, reference standard expired'),
    ('Manipal Bengaluru','BMA-MNP-21','Calais BMA','energy_accuracy_kcal',
     68.00,67.40,-0.88,true,'2026-07-02','pass','Energy content calc within tolerance for fortification decision'),
    ('Manipal Bengaluru','BMA-MNP-22','Calais BMA','total_solids_accuracy',
     12.50,12.90,3.20,false,'2026-07-02','conditional_pass','Total-solids 3.2% high — optical path contamination suspected'),
    ('AIIMS Delhi','BMA-AIM-31','MilkoScan Minor','fat_accuracy_gdl',
     3.60,3.61,0.28,true,'2026-06-30','pass','Fat accuracy excellent post preventive maintenance'),
    ('AIIMS Delhi','BMA-AIM-32','MilkoScan Minor','homogenizer_speed_rpm',
     12000.00,10850.00,-9.58,false,'2026-06-30','fail','Homogenizer 9.6% under target rpm — fat/solids readings unreliable'),
    ('CMC Vellore','BMA-CMC-41','Miris HMA','protein_accuracy_gdl',
     1.30,1.28,-1.54,true,'2026-06-29','conditional_pass','Protein within tolerance but annual calibration overdue'),
    ('CMC Vellore','BMA-CMC-42','Miris HMA','lactose_accuracy_gdl',
     7.00,6.98,-0.29,true,'2026-06-29','pass','Lactose accuracy nominal — QC pass'),
    ('KIMS Hyderabad','BMA-KIM-51','Miris HMA v3','energy_accuracy_kcal',
     70.00,66.10,-5.57,false,'2026-06-28','fail','Energy 5.6% low — infrared source drift affecting caloric estimate'),
    ('KIMS Hyderabad','BMA-KIM-52','Miris HMA v3','total_solids_accuracy',
     12.00,12.10,0.83,true,'2026-06-28','pass','Total-solids accuracy within tolerance'),
    ('Yashoda Hyderabad','BMA-YSH-61','Calais BMA','fat_accuracy_gdl',
     3.40,3.55,4.41,false,'2026-06-27','conditional_pass','Fat 4.4% high from inconsistent sample mixing — operator technique'),
    ('Kokilaben Mumbai','BMA-KKB-71','MilkoScan Minor','homogenizer_speed_rpm',
     12000.00,11980.00,-0.17,true,'2026-06-26','pass','Homogenizer speed on target — but reference standard lot near expiry'),
    ('Kokilaben Mumbai','BMA-KKB-72','Miris HMA','protein_accuracy_gdl',
     1.10,0.98,-10.91,false,'2026-06-26','fail','Protein 10.9% low — traced to sample under-temperature at load'),
    ('Rainbow Hyderabad','BMA-RNB-81','Calais BMA','lactose_accuracy_gdl',
     6.90,6.85,-0.72,true,'2026-06-25','pass','Lactose accuracy nominal — NICU nutrition QC pass')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.breast_milk_analyzer_qc_capa_actions_r3583 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BMA-FRT-12','fat_accuracy_out_of_tolerance','calibration_standard_expired','replace_reference_standard','in_progress','iso_15189_deviation','2026-07-08',null,18000.00,'Fat channel 9% high — certified reference milk past expiry, replacement ordered'),
    ('BMA-MNP-22','total_solids_accuracy_out_of_tolerance','optical_path_contamination','clean_optical_path','verification_pending','internal_only','2026-07-06',null,5500.00,'Total-solids drift — optical cuvette cleaned, verify on next batch'),
    ('BMA-AIM-32','homogenizer_speed_out_of_tolerance','homogenizer_wear','service_homogenizer','escalated','patient_safety_alert','2026-07-05',null,42000.00,'Homogenizer 9.6% under speed — fat/solids unreliable, OEM service escalated'),
    ('BMA-KIM-51','energy_accuracy_out_of_tolerance','infrared_source_drift','replace_infrared_source','open','nabh_finding','2026-07-07',null,36000.00,'Energy calc 5.6% low — IR source drift, source module replacement scheduled'),
    ('BMA-KKB-72','protein_accuracy_out_of_tolerance','sample_temperature_error','recalibrate_with_reference_standard','closed','cdsco_notifiable','2026-07-03','2026-06-30',12000.00,'Protein 11% low traced to under-temperature sample; recalibrated and validated'),
    ('BMA-YSH-61','fat_accuracy_out_of_tolerance','operator_technique_error','retrain_lab_staff','open','internal_only','2026-07-09',null,3000.00,'Fat bias from inconsistent mixing — NICU lab staff retraining scheduled'),
    ('BMA-CMC-41','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','none','2026-07-01',null,15000.00,'Annual calibration overdue — OEM visit past target date, vendor delay'),
    ('BMA-KKB-71','reference_standard_expired','calibration_standard_expired','replace_reference_standard','in_progress','iso_15189_deviation','2026-07-10',null,8000.00,'Homogenizer OK but reference standard lot expired — replacement in transit')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.breast_milk_analyzer_qc_r3583 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3583_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.breast_milk_analyzer_qc_r3583)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.breast_milk_analyzer_qc_r3583 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3583_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3583_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3583_device_model_scorecard()
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
  from public.breast_milk_analyzer_qc_r3583 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3583_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3583_device_model_scorecard() to authenticated;

-- 3) Parameter x verdict matrix
create or replace function public.founder_r3583_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.breast_milk_analyzer_qc_r3583 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3583_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3583_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3583_monthly_calibration_trend()
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
  from public.breast_milk_analyzer_qc_r3583 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3583_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3583_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3583_capa_status_board()
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
  from public.breast_milk_analyzer_qc_capa_actions_r3583 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3583_capa_status_board() from public, anon;
grant execute on function public.founder_r3583_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3583_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.breast_milk_analyzer_qc_capa_actions_r3583)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.breast_milk_analyzer_qc_capa_actions_r3583 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3583_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3583_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3583_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tolerance_checks bigint,
  out_of_tolerance bigint,
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
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.breast_milk_analyzer_qc_r3583 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3583_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3583_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3583_high_risk_queue()
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
  from public.breast_milk_analyzer_qc_r3583 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3583_high_risk_queue() from public, anon;
grant execute on function public.founder_r3583_high_risk_queue() to authenticated;
