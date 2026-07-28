-- Round 3522: Customer Hospital Vascular Doppler / Ankle-Brachial-Index (ABI) QC Audit
-- Vascular doppler / ABI unit QC — probe frequency × cuff pressure accuracy × signal sensitivity × ABI ratio accuracy × waveform quality × battery voltage × deviation × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: vascular_doppler_abi_qc_r3522 — per-parameter vascular doppler / ABI QC checks
-- =============================================================================
create table if not exists public.vascular_doppler_abi_qc_r3522 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'probe_frequency_mhz','cuff_pressure_accuracy','signal_sensitivity',
    'abi_ratio_accuracy','waveform_quality','battery_voltage_v'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vascular_doppler_abi_qc_r3522 enable row level security;

create index if not exists idx_vascular_doppler_abi_qc_r3522_org on public.vascular_doppler_abi_qc_r3522(organization_id);
create index if not exists idx_vascular_doppler_abi_qc_r3522_date on public.vascular_doppler_abi_qc_r3522(calibration_date);
create index if not exists idx_vascular_doppler_abi_qc_r3522_verdict on public.vascular_doppler_abi_qc_r3522(qc_verdict);

-- =============================================================================
-- TABLE 2: vascular_doppler_abi_qc_capa_actions_r3522 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.vascular_doppler_abi_qc_capa_actions_r3522 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.vascular_doppler_abi_qc_r3522(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'probe_frequency_drift','cuff_pressure_out_of_tolerance','signal_sensitivity_low',
    'abi_ratio_error','waveform_quality_degraded','battery_voltage_low',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'probe_crystal_aging','cuff_bladder_leak','transducer_degraded','pressure_sensor_drift',
    'cable_connector_damaged','battery_end_of_life','software_config_error',
    'operator_technique_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_probe','replace_cuff','replace_transducer','replace_pressure_sensor',
    'replace_cable','replace_battery','update_software_config','retrain_vascular_tech',
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

alter table public.vascular_doppler_abi_qc_capa_actions_r3522 enable row level security;

create index if not exists idx_vascular_doppler_abi_capa_r3522_log on public.vascular_doppler_abi_qc_capa_actions_r3522(qc_log_id);
create index if not exists idx_vascular_doppler_abi_capa_r3522_status on public.vascular_doppler_abi_qc_capa_actions_r3522(capa_status);

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

  -- 15 QC check rows
  insert into public.vascular_doppler_abi_qc_r3522 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','ABI-APL-01','Huntleigh Dopplex Ability','probe_frequency_mhz',
     8.0,8.02,0.25,true,'2026-07-03','pass','Probe frequency within tolerance on annual QC'),
    ('Apollo Chennai','ABI-APL-02','Huntleigh Dopplex Ability','abi_ratio_accuracy',
     1.00,0.99,1.00,true,'2026-07-03','pass','ABI ratio accuracy nominal against phantom'),
    ('Fortis Gurgaon','ABI-FRT-11','Bidop ES-100V3','cuff_pressure_accuracy',
     200.0,194.0,3.00,false,'2026-07-02','conditional_pass','Cuff pressure reads 6 mmHg low — recheck after service'),
    ('Fortis Gurgaon','ABI-FRT-12','Bidop ES-100V3','signal_sensitivity',
     60.0,52.0,13.33,false,'2026-07-02','fail','Signal sensitivity 8 dB below reference — transducer suspect'),
    ('Manipal Bengaluru','ABI-MNP-21','MESI ABPI MD','abi_ratio_accuracy',
     1.00,0.90,10.00,false,'2026-07-01','fail','ABI ratio error 10% — pressure sensor drift suspected'),
    ('Manipal Bengaluru','ABI-MNP-22','MESI ABPI MD','waveform_quality',
     95.0,92.0,3.16,true,'2026-07-01','pass','Waveform quality score acceptable'),
    ('AIIMS Delhi','ABI-AIM-31','Nicolet Elite 100R','probe_frequency_mhz',
     8.0,7.78,2.75,false,'2026-06-30','conditional_pass','Probe frequency drift 2.75% — crystal aging trend flagged'),
    ('AIIMS Delhi','ABI-AIM-32','Nicolet Elite 100R','battery_voltage_v',
     12.0,10.6,11.67,false,'2026-06-30','fail','Battery voltage low, unit shuts down mid-study'),
    ('CMC Vellore','ABI-CMC-41','Summit Doppler LifeDop','cuff_pressure_accuracy',
     200.0,199.0,0.50,true,'2026-06-29','pass','Cuff pressure accuracy within limit'),
    ('CMC Vellore','ABI-CMC-42','Summit Doppler LifeDop','signal_sensitivity',
     60.0,59.0,1.67,true,'2026-06-29','pass','Signal sensitivity nominal'),
    ('KIMS Hyderabad','ABI-KIM-51','Huntleigh Dopplex Ability','waveform_quality',
     95.0,84.0,11.58,false,'2026-06-28','fail','Waveform quality degraded — probe wear on 8 MHz element'),
    ('KIMS Hyderabad','ABI-KIM-52','Huntleigh Dopplex Ability','abi_ratio_accuracy',
     1.00,0.98,2.00,true,'2026-06-28','conditional_pass','ABI ratio slight deviation, calibration overdue flagged'),
    ('Yashoda Hyderabad','ABI-YSH-61','MESI ABPI MD','battery_voltage_v',
     12.0,11.9,0.83,true,'2026-06-27','pass','Battery voltage nominal post preventive service'),
    ('Kokilaben Mumbai','ABI-KKB-71','Bidop ES-100V3','cuff_pressure_accuracy',
     200.0,188.0,6.00,false,'2026-06-27','fail','Cuff bladder leak — 12 mmHg low, removed for repair'),
    ('Kokilaben Mumbai','ABI-KKB-72','Nicolet Elite 100R','probe_frequency_mhz',
     8.0,8.01,0.13,true,'2026-06-26','pass','Probe frequency within tolerance post PM')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.vascular_doppler_abi_qc_capa_actions_r3522 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ABI-FRT-12','signal_sensitivity_low','transducer_degraded','replace_transducer','in_progress','iso_13485_deviation','2026-07-06',null,18000.00,'Transducer replacement scheduled — verify sensitivity post swap'),
    ('ABI-MNP-21','abi_ratio_error','pressure_sensor_drift','replace_pressure_sensor','open','nabh_finding','2026-07-05',null,26000.00,'ABI ratio 10% error — pressure sensor replacement ordered'),
    ('ABI-AIM-32','battery_voltage_low','battery_end_of_life','replace_battery','closed','internal_only','2026-07-02','2026-06-30',3500.00,'Battery replaced and voltage validated under load'),
    ('ABI-KKB-71','cuff_pressure_out_of_tolerance','cuff_bladder_leak','replace_cuff','escalated','patient_safety_alert','2026-07-04',null,6500.00,'Cuff bladder leak — unit withdrawn, escalated to OEM'),
    ('ABI-KIM-51','waveform_quality_degraded','probe_crystal_aging','recalibrate_probe','verification_pending','internal_only','2026-07-05',null,9000.00,'Probe recalibrated — verify waveform next vascular study'),
    ('ABI-AIM-31','probe_frequency_drift','probe_crystal_aging','schedule_oem_service','open','cdsco_notifiable','2026-07-07',null,15000.00,'Probe crystal aging — OEM frequency service scheduled'),
    ('ABI-KIM-52','calibration_overdue','preventive_service_backlog','recalibrate_probe','overdue','internal_only','2026-06-30',null,4000.00,'Calibration overdue — preventive service backlog'),
    ('ABI-FRT-11','cuff_pressure_out_of_tolerance','pressure_sensor_drift','recalibrate_probe','in_progress','none','2026-07-06',null,5000.00,'Cuff pressure recalibrated — verifying accuracy')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.vascular_doppler_abi_qc_r3522 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3522_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vascular_doppler_abi_qc_r3522)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vascular_doppler_abi_qc_r3522 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3522_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3522_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3522_device_model_scorecard()
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
  from public.vascular_doppler_abi_qc_r3522 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3522_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3522_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3522_parameter_verdict_matrix()
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
  from public.vascular_doppler_abi_qc_r3522 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3522_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3522_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3522_monthly_accuracy_trend()
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
  from public.vascular_doppler_abi_qc_r3522 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3522_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3522_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3522_capa_status_board()
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
  from public.vascular_doppler_abi_qc_capa_actions_r3522 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3522_capa_status_board() from public, anon;
grant execute on function public.founder_r3522_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3522_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vascular_doppler_abi_qc_capa_actions_r3522)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vascular_doppler_abi_qc_capa_actions_r3522 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3522_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3522_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory impact digest
create or replace function public.founder_r3522_accuracy_impact_digest()
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
  from public.vascular_doppler_abi_qc_capa_actions_r3522 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3522_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3522_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3522_high_risk_queue()
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
  from public.vascular_doppler_abi_qc_r3522 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.deviation_pct desc nulls last, l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3522_high_risk_queue() from public, anon;
grant execute on function public.founder_r3522_high_risk_queue() to authenticated;
