-- Round 3454: Customer Hospital Tympanometer / Middle-Ear Impedance Audiometry QC Audit
-- Tympanometry / middle-ear impedance analyzer QC — pressure, static compliance, ear-canal volume, probe tone,
-- reflex threshold, gradient × reference vs measured × deviation × tolerance × calibration currency × verdict × CAPA

-- =============================================================================
-- TABLE 1: tympanometer_qc_r3454 — per-parameter middle-ear impedance QC checks
-- =============================================================================
create table if not exists public.tympanometer_qc_r3454 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  department text not null check (department in (
    'audiology','ent_opd','pediatric_audiology','neonatal_screening'
  )),
  test_ear text not null check (test_ear in (
    'left','right','both'
  )),
  parameter text not null check (parameter in (
    'ear_canal_pressure_dapa','static_compliance_ml','ear_canal_volume_ml',
    'probe_tone_db','reflex_threshold_db','gradient_dapa'
  )),
  probe_tone_hz numeric(6,1),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tympanometer_qc_r3454 enable row level security;

create index if not exists idx_tympanometer_qc_r3454_org on public.tympanometer_qc_r3454(organization_id);
create index if not exists idx_tympanometer_qc_r3454_date on public.tympanometer_qc_r3454(calibration_date);
create index if not exists idx_tympanometer_qc_r3454_verdict on public.tympanometer_qc_r3454(qc_verdict);

-- =============================================================================
-- TABLE 2: tympanometer_qc_capa_actions_r3454 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.tympanometer_qc_capa_actions_r3454 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.tympanometer_qc_r3454(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pressure_accuracy_out_of_tolerance','compliance_calibration_drift','ear_canal_volume_error',
    'probe_tone_level_error','reflex_threshold_deviation','gradient_out_of_spec',
    'probe_leak_blockage','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_seal_leak','pressure_transducer_drift','probe_tip_blocked','probe_cavity_leak',
    'speaker_output_drift','software_calibration_error','operator_technique_error',
    'reference_cavity_worn','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_pressure_pump','replace_probe_tip','clean_probe_assembly','replace_pump_seal',
    'recalibrate_compliance','update_software_calibration','retrain_audiology_staff',
    'remove_from_service','schedule_oem_service','replace_reference_cavity','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tympanometer_qc_capa_actions_r3454 enable row level security;

create index if not exists idx_tympanometer_capa_r3454_log on public.tympanometer_qc_capa_actions_r3454(qc_log_id);
create index if not exists idx_tympanometer_capa_r3454_status on public.tympanometer_qc_capa_actions_r3454(capa_status);

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
  insert into public.tympanometer_qc_r3454 (
    organization_id, hospital_name, device_code, device_model, department, test_ear,
    parameter, probe_tone_hz, reference_value, measured_value, deviation_pct,
    within_tolerance, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.dept, q.ear,
    q.param, q.tone, q.refv, q.meas, q.devp,
    q.wtol, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','TYMP-APL-01','GSI TympStar Pro','audiology','right',
     'ear_canal_pressure_dapa',226,200,198,-1.0,true,'2026-07-05',true,'pass',
     'Pressure accuracy within plus/minus 10 daPa at +200 daPa reference'),
    ('Apollo Chennai','TYMP-APL-02','GSI TympStar Pro','audiology','left',
     'static_compliance_ml',226,0.50,0.49,-2.0,true,'2026-07-05',true,'pass',
     'Static admittance within tolerance vs 0.5 ml reference cavity'),
    ('Fortis Gurgaon','TYMP-FRT-11','Interacoustics Titan','ent_opd','left',
     'ear_canal_volume_ml',226,2.00,2.14,7.0,false,'2026-07-04',true,'conditional_pass',
     'Ear canal volume 7% high on 2.0 ml cavity — recheck probe seal'),
    ('Fortis Gurgaon','TYMP-FRT-12','Interacoustics Titan','ent_opd','right',
     'ear_canal_pressure_dapa',226,200,176,-12.0,false,'2026-07-04',true,'fail',
     'Pressure error -24 daPa exceeds plus/minus 10 daPa spec — pump seal leak suspected'),
    ('Manipal Bengaluru','TYMP-MNP-21','Maico easyTymp','pediatric_audiology','both',
     'reflex_threshold_db',1000,85,90,5.9,false,'2026-07-03',true,'conditional_pass',
     'Acoustic reflex threshold 5 dB high — verify against calibrated source'),
    ('Manipal Bengaluru','TYMP-MNP-22','Otometrics MADSEN Zodiac','audiology','right',
     'gradient_dapa',226,100,104,4.0,true,'2026-07-03',true,'pass',
     'Tympanometric gradient within tolerance'),
    ('AIIMS Delhi','TYMP-AIM-31','GSI TympStar Pro','ent_opd','left',
     'probe_tone_db',226,85,83,-2.4,true,'2026-06-30',true,'pass',
     'Probe tone level within plus/minus 3 dB'),
    ('AIIMS Delhi','TYMP-AIM-32','GSI TympStar Pro','ent_opd','left',
     'static_compliance_ml',226,0.50,0.42,-16.0,false,'2026-06-30',false,'fail',
     'Static compliance 16% low and calibration overdue — recalibrate'),
    ('CMC Vellore','TYMP-CMC-41','Amplivox Otowave 202','neonatal_screening','both',
     'ear_canal_volume_ml',1000,0.50,0.51,2.0,true,'2026-06-29',true,'pass',
     '1000 Hz neonatal probe volume nominal'),
    ('CMC Vellore','TYMP-CMC-42','Interacoustics Titan','pediatric_audiology','right',
     'reflex_threshold_db',1000,85,86,1.2,true,'2026-06-29',true,'pass',
     'Reflex threshold within tolerance'),
    ('KIMS Hyderabad','TYMP-KIM-51','Maico easyTymp','audiology','left',
     'ear_canal_pressure_dapa',226,200,205,2.5,true,'2026-06-28',true,'pass',
     'Pressure accuracy nominal post-AMC'),
    ('KIMS Hyderabad','TYMP-KIM-52','Otometrics MADSEN Zodiac','ent_opd','right',
     'gradient_dapa',226,100,118,18.0,false,'2026-06-28',true,'conditional_pass',
     'Gradient 18% wide — probe tip partially blocked, cleaning scheduled'),
    ('Yashoda Hyderabad','TYMP-YSH-61','GSI TympStar Pro','audiology','both',
     'probe_tone_db',226,85,80,-5.9,false,'2026-06-27',true,'fail',
     'Probe tone level -5 dB out of spec — speaker output drift'),
    ('Yashoda Hyderabad','TYMP-YSH-62','GSI TympStar Pro','audiology','both',
     'static_compliance_ml',226,0.50,0.50,0.0,true,'2026-06-27',true,'pass',
     'Static admittance exact match to reference cavity'),
    ('Kokilaben Mumbai','TYMP-KKB-71','Interacoustics Titan','pediatric_audiology','left',
     'reflex_threshold_db',1000,85,95,11.8,false,'2026-06-26',false,'fail',
     'Reflex threshold 10 dB high and calibration overdue — removed pending service'),
    ('Kokilaben Mumbai','TYMP-KKB-72','Amplivox Otowave 202','neonatal_screening','both',
     'ear_canal_volume_ml',1000,0.50,0.60,20.0,false,'2026-06-26',true,'conditional_pass',
     '1000 Hz probe volume 20% high — probe cavity leak, reseat probe')
  ) as q(hosp, dcode, model, dept, ear, param, tone, refv, meas, devp, wtol, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.tympanometer_qc_capa_actions_r3454 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TYMP-FRT-12','pressure_accuracy_out_of_tolerance','pump_seal_leak','replace_pump_seal','in_progress','iso_13485_deviation','Biomedical Engg','2026-07-08',null,12000.00,'Pump seal replaced — verifying pressure accuracy at +200 daPa'),
    ('TYMP-AIM-32','compliance_calibration_drift','reference_cavity_worn','recalibrate_compliance','open','nabh_finding','Calibration Cell','2026-07-07',null,9000.00,'Static compliance 16% low — full recalibration and cavity check'),
    ('TYMP-KKB-71','reflex_threshold_deviation','speaker_output_drift','schedule_oem_service','escalated','patient_safety_alert','Service Desk','2026-07-06',null,28000.00,'Reflex threshold 10 dB high — removed from service, OEM recalibration'),
    ('TYMP-YSH-61','probe_tone_level_error','speaker_output_drift','update_software_calibration','verification_pending','internal_only','Audiology Lead','2026-07-05',null,3500.00,'Probe tone recalibrated in software — verify SPL output'),
    ('TYMP-KIM-52','probe_leak_blockage','probe_tip_blocked','clean_probe_assembly','closed','internal_only','Biomedical Engg','2026-07-02','2026-06-30',1500.00,'Probe assembly cleaned — gradient back within spec'),
    ('TYMP-FRT-11','ear_canal_volume_error','probe_cavity_leak','replace_probe_tip','open','internal_only','Biomedical Engg','2026-07-09',null,2800.00,'Ear canal volume 7% high — replace probe tip and reseal'),
    ('TYMP-MNP-21','reflex_threshold_deviation','pending_investigation','none_required','open','none','Audiology Lead','2026-07-08',null,0.00,'Reflex threshold 5 dB high — monitoring, retest next QC cycle'),
    ('TYMP-KKB-72','probe_leak_blockage','probe_cavity_leak','clean_probe_assembly','overdue','internal_only','Service Desk','2026-07-01',null,1500.00,'1000 Hz probe volume high — cleaning past target date, vendor delay')
  ) as q(dcode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.tympanometer_qc_r3454 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3454_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tympanometer_qc_r3454)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tympanometer_qc_r3454 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3454_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3454_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3454_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
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
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.tympanometer_qc_r3454 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3454_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3454_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3454_parameter_verdict_matrix()
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
  from public.tympanometer_qc_r3454 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3454_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3454_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3454_monthly_accuracy_trend()
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
  from public.tympanometer_qc_r3454 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3454_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3454_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3454_capa_status_board()
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
  from public.tympanometer_qc_capa_actions_r3454 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3454_capa_status_board() from public, anon;
grant execute on function public.founder_r3454_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3454_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tympanometer_qc_capa_actions_r3454)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tympanometer_qc_capa_actions_r3454 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3454_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3454_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter deviation profile)
create or replace function public.founder_r3454_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
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
  from public.tympanometer_qc_r3454 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3454_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3454_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / overdue checks)
create or replace function public.founder_r3454_high_risk_queue()
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
  from public.tympanometer_qc_r3454 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3454_high_risk_queue() from public, anon;
grant execute on function public.founder_r3454_high_risk_queue() to authenticated;
