-- Round 3527: Customer Hospital Cerebral Oximeter (NIRS / rSO2) Monitor QC Audit
-- Cerebral oximeter QA — device model × unit × QC parameter × reference vs measured × deviation × tolerance × probe condition × ambient light × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: cerebral_oximeter_qc_r3527 — per-parameter cerebral oximeter QC checks
-- =============================================================================
create table if not exists public.cerebral_oximeter_qc_r3527 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  unit text not null check (unit in (
    'cardiac_ot','neuro_icu','cardiac_icu','pediatric_icu','general_ot'
  )),
  parameter text not null check (parameter in (
    'rso2_pct_accuracy','led_intensity','signal_quality_index','baseline_drift','response_time_sec','sensor_impedance'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  probe_condition text not null check (probe_condition in (
    'good','worn','cracked','replace_due'
  )),
  ambient_light_ok boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cerebral_oximeter_qc_r3527 enable row level security;

create index if not exists idx_cerebral_oximeter_qc_r3527_org on public.cerebral_oximeter_qc_r3527(organization_id);
create index if not exists idx_cerebral_oximeter_qc_r3527_date on public.cerebral_oximeter_qc_r3527(calibration_date);
create index if not exists idx_cerebral_oximeter_qc_r3527_verdict on public.cerebral_oximeter_qc_r3527(qc_verdict);

-- =============================================================================
-- TABLE 2: cerebral_oximeter_qc_capa_actions_r3527 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cerebral_oximeter_qc_capa_actions_r3527 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cerebral_oximeter_qc_r3527(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'rso2_accuracy_out_of_tolerance','led_intensity_low','signal_quality_degraded',
    'baseline_drift_excessive','response_time_slow','sensor_impedance_high',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'led_degradation','photodetector_drift','sensor_adhesive_worn','optical_coupling_poor',
    'cable_connector_damaged','firmware_config_error','operator_placement_error',
    'pending_investigation','preventive_service_backlog','ambient_light_interference'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_reference_block','replace_optical_sensor','replace_led_module','replace_sensor_cable',
    'reseat_sensor_placement','update_firmware_config','retrain_clinical_staff',
    'remove_from_service','schedule_oem_service','shield_ambient_light','none_required'
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
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cerebral_oximeter_qc_capa_actions_r3527 enable row level security;

create index if not exists idx_cerebral_oximeter_capa_r3527_log on public.cerebral_oximeter_qc_capa_actions_r3527(qc_log_id);
create index if not exists idx_cerebral_oximeter_capa_r3527_status on public.cerebral_oximeter_qc_capa_actions_r3527(capa_status);

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
  insert into public.cerebral_oximeter_qc_r3527 (
    organization_id, hospital_name, device_code, device_model, unit, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    probe_condition, ambient_light_ok, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.unit, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.probe, q.amb, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','COX-APL-01','Medtronic INVOS 7100','cardiac_ot','rso2_pct_accuracy',
     70,69.2,-1.1,true,'good',true,'2026-07-05',true,'pass','rSO2 accuracy within +/-3% on reference block QC'),
    ('Apollo Chennai','COX-APL-02','Masimo O3 Regional','neuro_icu','signal_quality_index',
     90,88.0,-2.2,true,'good',true,'2026-07-05',true,'pass','Signal quality index nominal'),
    ('Fortis Gurgaon','COX-FRT-11','Nonin SenSmart X-100','pediatric_icu','led_intensity',
     100,92.0,-8.0,false,'worn',true,'2026-07-04',true,'conditional_pass','LED intensity 8% low — sensor worn, monitor recommended'),
    ('Fortis Gurgaon','COX-FRT-12','Medtronic INVOS 7100','cardiac_icu','rso2_pct_accuracy',
     70,63.5,-9.3,false,'good',true,'2026-07-04',true,'fail','rSO2 reads 6.5% low vs reference — accuracy out of tolerance'),
    ('Manipal Bengaluru','COX-MNP-21','Edwards ForeSight Elite','pediatric_icu','sensor_impedance',
     5.0,9.4,88.0,false,'replace_due',true,'2026-07-03',false,'fail','Sensor impedance high and calibration overdue — replace due'),
    ('Manipal Bengaluru','COX-MNP-22','Masimo O3 Regional','cardiac_ot','baseline_drift',
     0,0.4,4.0,true,'good',true,'2026-07-03',true,'pass','Baseline drift minimal, within tolerance'),
    ('AIIMS Delhi','COX-AIM-31','Medtronic INVOS 5100C','neuro_icu','response_time_sec',
     4.0,5.6,40.0,false,'good',true,'2026-07-02',true,'conditional_pass','Response time slower than 4s spec — flagged for trend'),
    ('AIIMS Delhi','COX-AIM-32','Nonin SenSmart X-100','general_ot','rso2_pct_accuracy',
     70,71.5,2.1,true,'good',false,'2026-07-02',true,'conditional_pass','Ambient OT light interference suspected — accuracy borderline'),
    ('CMC Vellore','COX-CMC-41','Masimo O3 Regional','cardiac_icu','signal_quality_index',
     90,60.0,-33.3,false,'cracked',true,'2026-07-01',false,'fail','Signal quality very low, sensor cracked, calibration overdue'),
    ('CMC Vellore','COX-CMC-42','Edwards ForeSight Elite','cardiac_ot','led_intensity',
     100,98.0,-2.0,true,'good',true,'2026-07-01',true,'pass','LED intensity nominal'),
    ('KIMS Hyderabad','COX-KIM-51','Medtronic INVOS 7100','cardiac_ot','rso2_pct_accuracy',
     70,69.8,-0.3,true,'good',true,'2026-06-30',true,'pass','rSO2 accuracy excellent post-AMC'),
    ('KIMS Hyderabad','COX-KIM-52','Nonin SenSmart X-100','pediatric_icu','baseline_drift',
     0,2.1,21.0,false,'worn',true,'2026-06-30',true,'conditional_pass','Baseline drift elevated — sensor worn, recheck due'),
    ('Yashoda Hyderabad','COX-YSH-61','Edwards ForeSight Elite','cardiac_icu','sensor_impedance',
     5.0,5.6,12.0,true,'good',true,'2026-06-29',true,'pass','Sensor impedance within limit'),
    ('Kokilaben Mumbai','COX-KKB-71','Medtronic INVOS 5100C','neuro_icu','rso2_pct_accuracy',
     70,58.0,-17.1,false,'cracked',false,'2026-06-28',false,'fail','Cracked sensor, ambient interference, accuracy grossly out — removed pending repair'),
    ('Narayana Bengaluru','COX-NAR-81','Masimo O3 Regional','cardiac_ot','response_time_sec',
     4.0,4.2,5.0,true,'good',true,'2026-06-28',true,'pass','Response time within spec'),
    ('Medanta Gurugram','COX-MED-91','Edwards ForeSight Elite','pediatric_icu','led_intensity',
     100,84.0,-16.0,false,'worn',true,'2026-06-27',false,'fail','LED intensity 16% low and calibration overdue — module failing')
  ) as q(hosp, dcode, dmodel, unit, param, refv, measv, devp, wtol, probe, amb, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cerebral_oximeter_qc_capa_actions_r3527 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.own, q.nt
  from (values
    ('COX-FRT-12','rso2_accuracy_out_of_tolerance','photodetector_drift','recalibrate_reference_block','in_progress','iso_13485_deviation','2026-07-08',null,14000.00,'Biomed - R. Nair','rSO2 recalibrated on reference block; verification pending'),
    ('COX-FRT-11','led_intensity_low','led_degradation','replace_led_module','open','internal_only','2026-07-09',null,26000.00,'Biomed - R. Nair','LED module degradation — replacement scheduled'),
    ('COX-MNP-21','sensor_impedance_high','sensor_adhesive_worn','replace_optical_sensor','verification_pending','nabh_finding','2026-07-07',null,21000.00,'Clinical Eng - S. Rao','Impedance high, calibration overdue — sensor replaced, verify next case'),
    ('COX-AIM-31','response_time_slow','firmware_config_error','update_firmware_config','open','internal_only','2026-07-06',null,0.00,'Biomed - A. Kumar','Response-time slow — firmware config review scheduled'),
    ('COX-CMC-41','signal_quality_degraded','optical_coupling_poor','replace_optical_sensor','escalated','patient_safety_alert','2026-07-05',null,23000.00,'Clinical Eng - J. Thomas','Cracked sensor with poor coupling — escalated, unit down'),
    ('COX-KKB-71','rso2_accuracy_out_of_tolerance','ambient_light_interference','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-30',48000.00,'Biomed - P. Shah','Cracked sensor removed, replaced and validated; ambient shielding added'),
    ('COX-MED-91','led_intensity_low','led_degradation','replace_led_module','overdue','iso_13485_deviation','2026-06-30',null,27000.00,'Biomed - V. Menon','LED module past target replacement date — vendor delay'),
    ('COX-KIM-52','baseline_drift_excessive','sensor_adhesive_worn','replace_optical_sensor','closed','internal_only','2026-07-02','2026-06-30',18500.00,'Clinical Eng - S. Rao','Worn sensor replaced, baseline drift resolved')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, own, nt)
  join public.cerebral_oximeter_qc_r3527 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3527_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cerebral_oximeter_qc_r3527)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cerebral_oximeter_qc_r3527 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3527_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3527_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3527_device_model_scorecard()
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
  from public.cerebral_oximeter_qc_r3527 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3527_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3527_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3527_parameter_verdict_matrix()
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
  from public.cerebral_oximeter_qc_r3527 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3527_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3527_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3527_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cerebral_oximeter_qc_r3527 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3527_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3527_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3527_capa_status_board()
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
  from public.cerebral_oximeter_qc_capa_actions_r3527 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3527_capa_status_board() from public, anon;
grant execute on function public.founder_r3527_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3527_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cerebral_oximeter_qc_capa_actions_r3527)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cerebral_oximeter_qc_capa_actions_r3527 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3527_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3527_root_cause_pareto() to authenticated;

-- 7) Accuracy impact digest (per parameter)
create or replace function public.founder_r3527_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  avg_reference_value numeric,
  avg_measured_value numeric,
  avg_deviation_pct numeric,
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
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.cerebral_oximeter_qc_r3527 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3527_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3527_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3527_high_risk_queue()
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
  probe_condition text,
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
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.probe_condition, l.notes
  from public.cerebral_oximeter_qc_r3527 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.ambient_light_ok = false
     or l.calibration_current = false
     or l.probe_condition in ('cracked','replace_due')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3527_high_risk_queue() from public, anon;
grant execute on function public.founder_r3527_high_risk_queue() to authenticated;
