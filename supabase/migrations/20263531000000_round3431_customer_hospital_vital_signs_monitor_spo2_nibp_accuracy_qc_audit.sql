-- Round 3431: Customer Hospital Vital-Signs Monitor SpO2 / NIBP Accuracy QC Audit
-- Multipara vital-signs monitor QA — parameter (SpO2, NIBP systolic/diastolic, pulse, resp, temp) x
-- reference vs measured value x deviation % x simulator x within-tolerance x alarm test x calibration x CAPA

-- =============================================================================
-- TABLE 1: vital_signs_spo2_nibp_qc_r3431
-- =============================================================================
create table if not exists public.vital_signs_spo2_nibp_qc_r3431 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  check_code text not null,
  device_model text not null,
  ward_or_dept text not null,
  parameter text not null check (parameter in (
    'spo2','nibp_systolic','nibp_diastolic','pulse_rate','resp_rate','temperature'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  simulator_model text,
  within_tolerance boolean not null,
  alarm_test_ok boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vital_signs_spo2_nibp_qc_r3431 enable row level security;

create index if not exists idx_vsm_spo2_nibp_qc_r3431_org on public.vital_signs_spo2_nibp_qc_r3431(organization_id);
create index if not exists idx_vsm_spo2_nibp_qc_r3431_cal on public.vital_signs_spo2_nibp_qc_r3431(calibration_date);
create index if not exists idx_vsm_spo2_nibp_qc_r3431_verdict on public.vital_signs_spo2_nibp_qc_r3431(qc_verdict);

-- =============================================================================
-- TABLE 2: vital_signs_spo2_nibp_qc_capa_actions_r3431
-- =============================================================================
create table if not exists public.vital_signs_spo2_nibp_qc_capa_actions_r3431 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.vital_signs_spo2_nibp_qc_r3431(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'spo2_accuracy_out_of_tolerance','nibp_accuracy_out_of_tolerance','pulse_rate_deviation',
    'resp_rate_deviation','temperature_deviation','alarm_test_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_probe_degraded','cuff_leak_or_wear','transducer_drift','simulator_mismatch',
    'firmware_config_error','operator_technique_error','pending_investigation',
    'calibration_drift','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_spo2_probe','replace_nibp_cuff','recalibrate_module','update_firmware',
    'retrain_clinical_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.vital_signs_spo2_nibp_qc_capa_actions_r3431 enable row level security;

create index if not exists idx_vsm_spo2_nibp_capa_r3431_log on public.vital_signs_spo2_nibp_qc_capa_actions_r3431(qc_log_id);
create index if not exists idx_vsm_spo2_nibp_capa_r3431_status on public.vital_signs_spo2_nibp_qc_capa_actions_r3431(capa_status);

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

  -- 16 accuracy-QC check rows
  insert into public.vital_signs_spo2_nibp_qc_r3431 (
    organization_id, hospital_name, check_code, device_model, ward_or_dept, parameter,
    reference_value, measured_value, deviation_pct, simulator_model,
    within_tolerance, alarm_test_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.cc, q.dmodel, q.ward, q.param,
    q.refv, q.measv, q.devpct, q.sim,
    q.wtol, q.alarmok, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','VSM-APL-01-SPO2','Philips IntelliVue MX450','icu','spo2',
     98,98,0.00,'Fluke ProSim 8',true,true,'2026-07-05','pass','SpO2 within +/-2% at 98% reference'),
    ('Apollo Chennai','VSM-APL-01-NBPS','Philips IntelliVue MX450','icu','nibp_systolic',
     120,122,1.67,'Fluke ProSim 8',true,true,'2026-07-05','pass','NIBP systolic within +/-3 mmHg'),
    ('Apollo Chennai','VSM-APL-01-NBPD','Philips IntelliVue MX450','icu','nibp_diastolic',
     80,78,-2.50,'Fluke ProSim 8',true,true,'2026-07-05','pass','NIBP diastolic within tolerance'),
    ('Fortis Gurgaon','VSM-FRT-11-SPO2','GE CARESCAPE B650','ot','spo2',
     95,91,-4.21,'Fluke ProSim 4',false,true,'2026-07-04','conditional_pass','SpO2 reads 4% low at 95% ref — probe recheck'),
    ('Fortis Gurgaon','VSM-FRT-12-NBPS','GE CARESCAPE B650','er','nibp_systolic',
     160,149,-6.88,'Fluke ProSim 4',false,false,'2026-07-04','fail','NIBP systolic 11 mmHg low and alarm failed to annunciate'),
    ('Manipal Bengaluru','VSM-MNP-21-PR','Mindray BeneVision N17','icu','pulse_rate',
     80,81,1.25,'Fluke ProSim 8',true,true,'2026-07-02','pass','Pulse rate accurate within +/-2 bpm'),
    ('Manipal Bengaluru','VSM-MNP-21-TEMP','Mindray BeneVision N17','icu','temperature',
     37.0,37.2,0.54,'Fluke ProSim 8',true,true,'2026-07-02','pass','Temperature within +/-0.2 C'),
    ('AIIMS Delhi','VSM-AIM-31-RR','Nihon Kohden BSM-6000','ward','resp_rate',
     20,22,10.00,'Fluke ProSim 8',false,true,'2026-06-28','conditional_pass','Resp rate 2 bpm high via impedance — monitor'),
    ('AIIMS Delhi','VSM-AIM-32-SPO2','Nihon Kohden BSM-6000','icu','spo2',
     90,84,-6.67,'Fluke ProSim 4',false,false,'2026-06-28','fail','SpO2 6% low in hypoxic range and desat alarm missed'),
    ('CMC Vellore','VSM-CMC-41-NBPD','Philips IntelliVue MX550','ot','nibp_diastolic',
     90,92,2.22,'Fluke ProSim 8',true,true,'2026-06-25','pass','NIBP diastolic pass'),
    ('CMC Vellore','VSM-CMC-42-NBPS','Philips IntelliVue MX550','icu','nibp_systolic',
     100,98,-2.00,'Fluke ProSim 8',true,true,'2026-06-25','pass','NIBP systolic within +/-3 mmHg'),
    ('KIMS Hyderabad','VSM-KIM-51-SPO2','Mindray BeneVision N15','er','spo2',
     97,95,-2.06,'Fluke ProSim 8',true,true,'2026-06-20','conditional_pass','SpO2 borderline 2% — upward drift trend'),
    ('KIMS Hyderabad','VSM-KIM-52-TEMP','Mindray BeneVision N15','icu','temperature',
     38.5,38.9,1.04,'Fluke ProSim 8',false,true,'2026-06-20','conditional_pass','Temperature 0.4 C high in febrile range'),
    ('Yashoda Hyderabad','VSM-YSH-61-PR','GE B450','ward','pulse_rate',
     120,108,-10.00,'Fluke ProSim 4',false,false,'2026-06-18','fail','Pulse rate 12 bpm low and tachy alarm failed'),
    ('Kokilaben Mumbai','VSM-KKB-71-NBPS','Philips IntelliVue MX750','icu','nibp_systolic',
     140,141,0.71,'Fluke ProSim 8',true,true,'2026-06-15','pass','NIBP systolic pass'),
    ('Kokilaben Mumbai','VSM-KKB-72-RR','Philips IntelliVue MX750','ot','resp_rate',
     15,15,0.00,'Fluke ProSim 8',true,true,'2026-06-15','pass','Resp rate accurate')
  ) as q(hosp, cc, dmodel, ward, param, refv, measv, devpct, sim, wtol, alarmok, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via check_code
  insert into public.vital_signs_spo2_nibp_qc_capa_actions_r3431 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('VSM-FRT-11-SPO2','spo2_accuracy_out_of_tolerance','sensor_probe_degraded','replace_spo2_probe','in_progress','iso_13485_deviation','2026-07-08',null,6500.00,'SpO2 probe replaced — verify at next QC'),
    ('VSM-FRT-12-NBPS','nibp_accuracy_out_of_tolerance','cuff_leak_or_wear','replace_nibp_cuff','escalated','patient_safety_alert','2026-07-07',null,3200.00,'NIBP cuff leak plus alarm miss — escalated to OEM'),
    ('VSM-AIM-31-RR','resp_rate_deviation','operator_technique_error','retrain_clinical_staff','open','internal_only','2026-07-10',null,0.00,'Impedance resp lead placement retraining scheduled'),
    ('VSM-AIM-32-SPO2','alarm_test_failure','firmware_config_error','update_firmware','verification_pending','cdsco_notifiable','2026-07-06',null,0.00,'Desat alarm firmware patched — verification pending'),
    ('VSM-KIM-51-SPO2','spo2_accuracy_out_of_tolerance','calibration_drift','recalibrate_module','closed','internal_only','2026-06-24','2026-06-23',4800.00,'SpO2 module recalibrated and validated'),
    ('VSM-KIM-52-TEMP','temperature_deviation','transducer_drift','recalibrate_module','open','nabh_finding','2026-07-05',null,5200.00,'Temperature channel drift — recalibration due'),
    ('VSM-YSH-61-PR','alarm_test_failure','cuff_leak_or_wear','remove_from_service','overdue','patient_safety_alert','2026-06-22',null,9500.00,'Pulse-rate low plus tachy alarm fail — unit pulled, past target'),
    ('VSM-CMC-42-NBPS','calibration_overdue','preventive_service_backlog','schedule_oem_service','closed','internal_only','2026-06-27','2026-06-26',2500.00,'Preventive AMC visit completed on schedule')
  ) as q(cc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.vital_signs_spo2_nibp_qc_r3431 e
    on e.organization_id = v_org_id and e.check_code = q.cc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3431_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vital_signs_spo2_nibp_qc_r3431)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vital_signs_spo2_nibp_qc_r3431 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3431_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3431_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3431_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  alarm_failures bigint,
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
    count(*) filter (where l.alarm_test_ok = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.vital_signs_spo2_nibp_qc_r3431 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3431_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3431_device_model_scorecard() to authenticated;

-- 3) Ward x verdict matrix
create or replace function public.founder_r3431_ward_verdict_matrix()
returns table(ward_or_dept text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ward_or_dept, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.vital_signs_spo2_nibp_qc_r3431 l
  group by l.ward_or_dept, l.qc_verdict
  order by l.ward_or_dept, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3431_ward_verdict_matrix() from public, anon;
grant execute on function public.founder_r3431_ward_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3431_monthly_accuracy_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select (date_trunc('month', l.calibration_date))::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.vital_signs_spo2_nibp_qc_r3431 l
  where l.calibration_date is not null
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3431_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3431_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3431_capa_status_board()
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
  from public.vital_signs_spo2_nibp_qc_capa_actions_r3431 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3431_capa_status_board() from public, anon;
grant execute on function public.founder_r3431_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3431_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vital_signs_spo2_nibp_qc_capa_actions_r3431)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vital_signs_spo2_nibp_qc_capa_actions_r3431 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3431_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3431_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3431_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  avg_reference numeric,
  avg_measured numeric,
  avg_abs_deviation_pct numeric,
  out_of_tolerance bigint,
  failed bigint
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
    round(avg(l.reference_value), 2),
    round(avg(l.measured_value), 2),
    round(avg(abs(l.deviation_pct)), 2),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.vital_signs_spo2_nibp_qc_r3431 l
  group by l.parameter
  order by round(avg(abs(l.deviation_pct)), 2) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3431_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3431_accuracy_impact_digest() to authenticated;

-- 8) High-risk queue (out-of-tolerance / failed / alarm-failed)
create or replace function public.founder_r3431_high_risk_queue()
returns table(
  hospital_name text,
  check_code text,
  device_model text,
  ward_or_dept text,
  parameter text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
  alarm_test_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.check_code, l.device_model, l.ward_or_dept, l.parameter,
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.alarm_test_ok, l.notes
  from public.vital_signs_spo2_nibp_qc_r3431 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.alarm_test_ok = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3431_high_risk_queue() from public, anon;
grant execute on function public.founder_r3431_high_risk_queue() to authenticated;
