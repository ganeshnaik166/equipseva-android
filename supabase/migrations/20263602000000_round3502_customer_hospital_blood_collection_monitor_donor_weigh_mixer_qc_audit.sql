-- Round 3502: Customer Hospital Blood Collection Monitor / Donor Weigh-Mixer QC Audit
-- Blood collection monitor / mixer (donor bag) QA — parameter × device model × verdict × tolerance
-- × weight/volume/mix/flow/clamp accuracy × calibration currency × alarm × CAPA closure

-- =============================================================================
-- TABLE 1: blood_collection_monitor_qc_r3502 — per-parameter donor weigh-mixer QC checks
-- =============================================================================
create table if not exists public.blood_collection_monitor_qc_r3502 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  department text not null check (department in (
    'blood_bank','donor_collection','apheresis_unit','mobile_blood_camp'
  )),
  check_date date not null,
  parameter text not null check (parameter in (
    'target_volume_ml','measured_volume_ml','weight_accuracy_g','mix_cycles_per_min','flow_rate_mlmin','clamp_response_sec'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  tolerance_band_pct numeric(5,2),
  within_tolerance boolean not null,
  alarm_functional boolean not null,
  calibration_date date,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_collection_monitor_qc_r3502 enable row level security;

create index if not exists idx_blood_collection_qc_r3502_org on public.blood_collection_monitor_qc_r3502(organization_id);
create index if not exists idx_blood_collection_qc_r3502_date on public.blood_collection_monitor_qc_r3502(check_date);
create index if not exists idx_blood_collection_qc_r3502_verdict on public.blood_collection_monitor_qc_r3502(qc_verdict);

-- =============================================================================
-- TABLE 2: blood_collection_monitor_qc_capa_actions_r3502 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.blood_collection_monitor_qc_capa_actions_r3502 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.blood_collection_monitor_qc_r3502(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'volume_accuracy_out_of_tolerance','weight_accuracy_out_of_tolerance','mix_speed_out_of_tolerance',
    'flow_rate_out_of_tolerance','clamp_response_slow','alarm_test_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'load_cell_drift','mixer_motor_wear','flow_sensor_fouled','clamp_actuator_worn',
    'firmware_config_error','operator_setup_error','pending_investigation',
    'preventive_service_backlog','calibration_weight_uncertified'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_load_cell','replace_load_cell','service_mixer_motor','clean_flow_sensor',
    'replace_clamp_actuator','update_firmware_config','retrain_blood_bank_staff',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.blood_collection_monitor_qc_capa_actions_r3502 enable row level security;

create index if not exists idx_blood_collection_capa_r3502_log on public.blood_collection_monitor_qc_capa_actions_r3502(qc_log_id);
create index if not exists idx_blood_collection_capa_r3502_status on public.blood_collection_monitor_qc_capa_actions_r3502(capa_status);

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
  insert into public.blood_collection_monitor_qc_r3502 (
    organization_id, hospital_name, device_code, device_model, department, check_date,
    parameter, reference_value, measured_value, deviation_pct, tolerance_band_pct,
    within_tolerance, alarm_functional, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.dept, q.cdate::date,
    q.param, q.refv::numeric, q.measv::numeric, q.devpct::numeric, q.tolband::numeric,
    q.wtol, q.alarm, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','BCM-APL-01','Terumo T-RAC II','blood_bank','2026-07-05',
     'target_volume_ml',450,450,0.0,2.0,true,true,'2026-06-15',true,'pass','Target volume set-point verified at 450 mL'),
    ('Apollo Chennai','BCM-APL-02','Terumo T-RAC II','donor_collection','2026-07-05',
     'measured_volume_ml',450,447,0.67,2.0,true,true,'2026-06-15',true,'pass','Collected whole-blood volume within +/-2% tolerance'),
    ('Fortis Gurgaon','BCM-FRT-11','Delcon Kool','blood_bank','2026-07-04',
     'weight_accuracy_g',477,470,1.47,1.5,true,true,'2026-06-10',true,'conditional_pass','Weight accuracy near tolerance edge — recheck advised'),
    ('Fortis Gurgaon','BCM-FRT-12','Delcon Kool','donor_collection','2026-07-04',
     'weight_accuracy_g',477,488,2.31,1.5,false,true,'2026-06-10',true,'fail','Load cell over-reading 2.31% — out of tolerance'),
    ('Manipal Bengaluru','BCM-MNP-21','Fresenius CompoMat','apheresis_unit','2026-07-03',
     'mix_cycles_per_min',60,52,13.33,8.0,false,true,'2026-05-28',false,'fail','Rocker mix speed low at 52 rpm and calibration overdue'),
    ('Manipal Bengaluru','BCM-MNP-22','Fresenius CompoMat','blood_bank','2026-07-03',
     'mix_cycles_per_min',60,61,1.67,8.0,true,true,'2026-06-20',true,'pass','Rocker mix cycles within tolerance'),
    ('AIIMS Delhi','BCM-AIM-31','LMB Donomix','donor_collection','2026-07-02',
     'flow_rate_mlmin',80,78,2.5,10.0,true,true,'2026-06-18',true,'pass','Flow rate nominal at 78 mL/min'),
    ('AIIMS Delhi','BCM-AIM-32','LMB Donomix','donor_collection','2026-07-02',
     'flow_rate_mlmin',80,95,18.75,10.0,false,false,'2026-06-18',true,'fail','Flow sensor over-reading and collection alarm failed'),
    ('CMC Vellore','BCM-CMC-41','Terumo T-RAC II','blood_bank','2026-07-01',
     'clamp_response_sec',2.0,2.1,5.0,15.0,true,true,'2026-06-12',true,'pass','Auto-clamp response within limit'),
    ('CMC Vellore','BCM-CMC-42','Delcon Travel','mobile_blood_camp','2026-07-01',
     'clamp_response_sec',2.0,3.6,80.0,15.0,false,false,'2026-05-20',false,'fail','Clamp response slow at 3.6s, alarm silent, calibration overdue'),
    ('KIMS Hyderabad','BCM-KIM-51','Fresenius CompoMat','blood_bank','2026-06-30',
     'target_volume_ml',350,350,0.0,2.0,true,true,'2026-06-08',true,'pass','Paediatric 350 mL target verified'),
    ('KIMS Hyderabad','BCM-KIM-52','LMB Donomix','donor_collection','2026-06-30',
     'weight_accuracy_g',371,366,1.35,1.5,true,true,'2026-06-08',true,'conditional_pass','Weight accuracy within tolerance but downward drift trend flagged'),
    ('Yashoda Hyderabad','BCM-YSH-61','Terumo T-RAC II','apheresis_unit','2026-06-29',
     'measured_volume_ml',500,494,1.2,2.0,true,true,'2026-06-05',true,'pass','Apheresis collection volume verified'),
    ('Yashoda Hyderabad','BCM-YSH-62','Delcon Kool','mobile_blood_camp','2026-06-29',
     'flow_rate_mlmin',80,72,10.0,10.0,true,true,'2026-05-30',true,'conditional_pass','Flow rate at tolerance edge during outdoor camp'),
    ('Kokilaben Mumbai','BCM-KKB-71','Fresenius CompoMat','blood_bank','2026-06-28',
     'mix_cycles_per_min',60,44,26.67,8.0,false,false,'2026-05-15',false,'fail','Mixer motor failing, alarm dead, calibration overdue — removed from service'),
    ('Kokilaben Mumbai','BCM-KKB-72','LMB Donomix','donor_collection','2026-06-28',
     'clamp_response_sec',2.0,2.2,10.0,15.0,true,true,'2026-06-22',true,'pass','Clamp response within tolerance post-service')
  ) as q(hosp, dcode, dmodel, dept, cdate, param, refv, measv, devpct, tolband, wtol, alarm, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.blood_collection_monitor_qc_capa_actions_r3502 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('BCM-FRT-12','weight_accuracy_out_of_tolerance','load_cell_drift','recalibrate_load_cell','in_progress','iso_15189_deviation','2026-07-08',null,12000.00,'Load cell re-spanned with certified weights — verification pending'),
    ('BCM-MNP-21','mix_speed_out_of_tolerance','mixer_motor_wear','service_mixer_motor','open','nabh_finding','2026-07-07',null,28000.00,'Rocker motor RPM low — OEM service scheduled'),
    ('BCM-AIM-32','flow_rate_out_of_tolerance','flow_sensor_fouled','clean_flow_sensor','escalated','patient_safety_alert','2026-07-06',null,6500.00,'Flow over-read with alarm miss — escalated to OEM'),
    ('BCM-CMC-42','clamp_response_slow','clamp_actuator_worn','replace_clamp_actuator','open','cdsco_notifiable','2026-07-05',null,18500.00,'Slow clamp actuator on mobile unit — replacement ordered'),
    ('BCM-KKB-71','mix_speed_out_of_tolerance','mixer_motor_wear','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-30',42000.00,'Mixer motor replaced and unit revalidated'),
    ('BCM-FRT-11','weight_accuracy_out_of_tolerance','load_cell_drift','recalibrate_load_cell','verification_pending','internal_only','2026-07-08',null,3800.00,'Recalibrated near-edge load cell — verify next collection batch'),
    ('BCM-YSH-62','flow_rate_out_of_tolerance','calibration_weight_uncertified','recalibrate_load_cell','overdue','internal_only','2026-07-01',null,5200.00,'Camp unit recheck past target date — field logistics delay'),
    ('BCM-KIM-52','calibration_overdue','load_cell_drift','recalibrate_load_cell','open','none','2026-07-09',null,3000.00,'Weight drift trend — preventive recalibration planned')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.blood_collection_monitor_qc_r3502 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3502_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_collection_monitor_qc_r3502)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.blood_collection_monitor_qc_r3502 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3502_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3502_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3502_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
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
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.alarm_functional = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.blood_collection_monitor_qc_r3502 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3502_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3502_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3502_parameter_verdict_matrix()
returns table(
  parameter text,
  checks bigint,
  passed bigint,
  conditional bigint,
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
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.blood_collection_monitor_qc_r3502 l
  group by l.parameter
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3502_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3502_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3502_monthly_accuracy_trend()
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
  select to_char(date_trunc('month', l.check_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.blood_collection_monitor_qc_r3502 l
  group by to_char(date_trunc('month', l.check_date), 'YYYY-MM')
  order by to_char(date_trunc('month', l.check_date), 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3502_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3502_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3502_capa_status_board()
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
  from public.blood_collection_monitor_qc_capa_actions_r3502 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3502_capa_status_board() from public, anon;
grant execute on function public.founder_r3502_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3502_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_collection_monitor_qc_capa_actions_r3502)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.blood_collection_monitor_qc_capa_actions_r3502 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3502_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3502_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3502_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
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
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.blood_collection_monitor_qc_r3502 l
  group by l.parameter
  order by round(avg(l.deviation_pct), 2) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3502_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3502_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3502_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  department text,
  parameter text,
  check_date date,
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
  select l.hospital_name, l.device_code, l.device_model, l.department, l.parameter, l.check_date,
    l.measured_value, l.deviation_pct, l.qc_verdict, l.notes
  from public.blood_collection_monitor_qc_r3502 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.alarm_functional = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3502_high_risk_queue() from public, anon;
grant execute on function public.founder_r3502_high_risk_queue() to authenticated;
