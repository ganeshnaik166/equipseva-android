-- Round 3150: Customer Hospital Multiparameter Patient-Monitor Accuracy & Alarm Audit
-- Bedside monitor QA log — parameter × reference/measured value × error % × alarm-limit set × alarm-audible test × waveform quality × verdict + CAPA

-- =============================================================================
-- TABLE 1: patient_monitor_r3150 — individual parameter accuracy/alarm checks
-- =============================================================================
create table if not exists public.patient_monitor_r3150 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_or_unit text not null,
  monitor_asset_tag text not null,
  monitor_model text not null,
  parameter text not null check (parameter in (
    'ecg','spo2','nibp','etco2','temperature',
    'respiration_rate','heart_rate','invasive_bp'
  )),
  test_date date not null,
  tested_at timestamptz not null,
  reference_source text not null check (reference_source in (
    'multiparameter_simulator','spo2_simulator','ecg_simulator',
    'nibp_pump_manometer','etco2_gas_cylinder','certified_thermometer','reference_traceable_standard'
  )),
  reference_value numeric(8,2) not null,
  measured_value numeric(8,2) not null,
  error_pct numeric(6,2) not null,
  allowable_error_pct numeric(6,2) not null,
  alarm_limit_set text not null check (alarm_limit_set in (
    'within_spec','mislabeled','disabled','default_restored','custom_set','not_configured'
  )),
  alarm_audible_test text not null check (alarm_audible_test in (
    'pass','fail','inaudible','delayed','not_tested'
  )),
  alarm_response_seconds numeric(6,2),
  waveform_quality text not null check (waveform_quality in (
    'clean','noisy','artifact_present','flat_trace','baseline_drift','not_applicable'
  )),
  verdict text not null check (verdict in (
    'pass','conditional_pass','fail_accuracy','fail_alarm','fail_waveform','quarantined','pending_review'
  )),
  calibrated_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.patient_monitor_r3150 enable row level security;

create index if not exists idx_patient_monitor_r3150_org on public.patient_monitor_r3150(organization_id);
create index if not exists idx_patient_monitor_r3150_date on public.patient_monitor_r3150(test_date);
create index if not exists idx_patient_monitor_r3150_verdict on public.patient_monitor_r3150(verdict);

-- =============================================================================
-- TABLE 2: patient_monitor_capa_actions_r3150 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.patient_monitor_capa_actions_r3150 (
  id uuid primary key default gen_random_uuid(),
  monitor_log_id uuid not null references public.patient_monitor_r3150(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','alarm_limit_misconfigured','alarm_inaudible','alarm_delayed',
    'waveform_artifact','spo2_probe_fault','nibp_cuff_leak','etco2_drift',
    'sensor_calibration_due','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_aged','calibration_drift','probe_cable_damaged','nibp_valve_leak',
    'etco2_bench_contaminated','alarm_volume_muted','firmware_bug','operator_config_error',
    'module_hardware_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_module','replace_spo2_probe','replace_nibp_cuff','rebuild_nibp_pump',
    'replace_etco2_bench','restore_alarm_defaults','update_firmware','retrain_operator',
    'quarantine_monitor','schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.patient_monitor_capa_actions_r3150 enable row level security;

create index if not exists idx_patient_monitor_capa_r3150_log on public.patient_monitor_capa_actions_r3150(monitor_log_id);
create index if not exists idx_patient_monitor_capa_r3150_status on public.patient_monitor_capa_actions_r3150(capa_status);

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

  -- 14 monitor parameter checks
  insert into public.patient_monitor_r3150 (
    organization_id, hospital_name, ward_or_unit, monitor_asset_tag, monitor_model,
    parameter, test_date, tested_at, reference_source,
    reference_value, measured_value, error_pct, allowable_error_pct,
    alarm_limit_set, alarm_audible_test, alarm_response_seconds, waveform_quality,
    verdict, calibrated_at, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.model,
    q.param, q.td::date, q.ta::timestamptz, q.rsrc,
    q.refv, q.measv, q.errp, q.allow,
    q.als, q.aat, q.ars, q.wq,
    q.verdict, q.calat::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-1','PM-APL-014','Philips IntelliVue MX550','ecg','2026-07-15','2026-07-15 09:10:00+05:30','ecg_simulator',
     60.00,60.00,0.00,5.00,'within_spec','pass',2.00,'clean','pass','2026-07-15 09:30:00+05:30','ECG HR simulation exact'),
    ('Apollo Hyderabad Jubilee Hills','ICU-1','PM-APL-021','Philips IntelliVue MX550','spo2','2026-07-15','2026-07-15 09:40:00+05:30','spo2_simulator',
     90.00,88.00,2.22,3.00,'within_spec','pass',3.00,'clean','pass','2026-07-15 10:00:00+05:30','SpO2 within 3% at 90 sat'),
    ('Fortis Bannerghatta Bengaluru','CCU-2','PM-FRT-007','GE CARESCAPE B650','nibp','2026-07-15','2026-07-15 08:20:00+05:30','nibp_pump_manometer',
     120.00,132.00,10.00,3.00,'within_spec','pass',2.50,'not_applicable','fail_accuracy',null,'NIBP reads 12 mmHg high — out of tolerance'),
    ('Fortis Bannerghatta Bengaluru','CCU-2','PM-FRT-013','GE CARESCAPE B650','etco2','2026-07-15','2026-07-15 08:50:00+05:30','etco2_gas_cylinder',
     5.00,4.20,16.00,8.00,'disabled','fail',null,'baseline_drift','fail_alarm',null,'EtCO2 low + apnea alarm disabled — patient safety'),
    ('Manipal Whitefield Bengaluru','NICU-1','PM-MNP-021','Mindray BeneVision N22','spo2','2026-07-14','2026-07-14 10:15:00+05:30','spo2_simulator',
     85.00,79.00,7.06,3.00,'within_spec','delayed',15.00,'noisy','fail_accuracy',null,'SpO2 under-reads at low sat — probe suspect'),
    ('Manipal Whitefield Bengaluru','NICU-1','PM-MNP-028','Mindray BeneVision N22','temperature','2026-07-14','2026-07-14 10:45:00+05:30','certified_thermometer',
     37.00,37.10,0.27,1.00,'within_spec','pass',3.00,'not_applicable','pass','2026-07-14 11:00:00+05:30','Skin temp probe within spec'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','PM-AIM-033','Nihon Kohden Life Scope','ecg','2026-07-14','2026-07-14 07:30:00+05:30','ecg_simulator',
     120.00,118.00,1.67,5.00,'within_spec','pass',2.00,'clean','pass','2026-07-14 07:50:00+05:30','Tachy simulation tracked well'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','PM-AIM-040','Nihon Kohden Life Scope','nibp','2026-07-14','2026-07-14 08:00:00+05:30','nibp_pump_manometer',
     80.00,81.00,1.25,3.00,'within_spec','pass',2.50,'not_applicable','pass','2026-07-14 08:20:00+05:30','NIBP diastolic within tolerance'),
    ('KIMS Secunderabad','HDU-4','PM-KIM-011','Skanray Star 90','spo2','2026-07-13','2026-07-13 09:00:00+05:30','spo2_simulator',
     98.00,97.00,1.02,3.00,'mislabeled','pass',4.00,'clean','conditional_pass','2026-07-13 09:20:00+05:30','Accuracy OK but SpO2 low-limit set to 80 not 90'),
    ('KIMS Secunderabad','HDU-4','PM-KIM-018','Skanray Star 90','etco2','2026-07-13','2026-07-13 09:30:00+05:30','etco2_gas_cylinder',
     5.00,5.90,18.00,8.00,'not_configured','not_tested',null,'baseline_drift','quarantined',null,'EtCO2 bench drift + alarms not configured — unit pulled'),
    ('Care Hospitals Banjara Hills','ICU-2','PM-CAR-005','Philips Efficia CM120','respiration_rate','2026-07-13','2026-07-13 11:00:00+05:30','multiparameter_simulator',
     20.00,19.00,5.00,10.00,'within_spec','pass',3.00,'clean','pass','2026-07-13 11:20:00+05:30','RR impedance channel accurate'),
    ('Yashoda Somajiguda Hyderabad','ICU-6','PM-YSH-018','Draeger Infinity Vista','heart_rate','2026-07-12','2026-07-12 06:30:00+05:30','multiparameter_simulator',
     150.00,150.00,0.00,5.00,'within_spec','pass',2.00,'clean','pass','2026-07-12 06:50:00+05:30','Neonatal HR range verified'),
    ('St John''s Bengaluru','CCU-1','PM-STJ-003','Schiller Argus','invasive_bp','2026-07-12','2026-07-12 05:50:00+05:30','reference_traceable_standard',
     100.00,96.00,4.00,4.00,'within_spec','pass',3.50,'clean','conditional_pass','2026-07-12 06:10:00+05:30','IBP at edge of tolerance — recal advised'),
    ('Rainbow Children''s Hyderabad','PICU-3','PM-RBW-009','Mindray uMEC12','spo2','2026-07-11','2026-07-11 07:00:00+05:30','spo2_simulator',
     92.00,84.00,8.70,3.00,'disabled','inaudible',null,'artifact_present','fail_alarm',null,'SpO2 desat alarm inaudible + reads low — critical')
  ) as q(hosp, ward, tag, model, param, td, ta, rsrc, refv, measv, errp, allow, als, aat, ars, wq, verdict, calat, nt);

  -- CAPA seed — attach to specific monitor checks via asset tag
  insert into public.patient_monitor_capa_actions_r3150 (
    monitor_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PM-FRT-007','accuracy_out_of_tolerance','calibration_drift','recalibrate_module','2026-07-22',null,'in_progress','nabh_finding',8500.00,'NIBP module recalibration scheduled'),
    ('PM-FRT-013','alarm_limit_misconfigured','operator_config_error','restore_alarm_defaults','2026-07-19','2026-07-16','closed','patient_safety_alert',0.00,'Apnea alarm re-enabled + config locked'),
    ('PM-MNP-021','spo2_probe_fault','probe_cable_damaged','replace_spo2_probe','2026-07-20',null,'in_progress','iso_13485_deviation',6500.00,'Reusable SpO2 probe replaced, retest pending'),
    ('PM-KIM-018','etco2_drift','etco2_bench_contaminated','replace_etco2_bench','2026-07-24',null,'escalated','cdsco_notifiable',32000.00,'EtCO2 bench module RMA — unit quarantined'),
    ('PM-RBW-009','alarm_inaudible','alarm_volume_muted','restore_alarm_defaults','2026-07-18',null,'overdue','patient_safety_alert',1500.00,'Desat alarm volume was muted at 0 — overdue closure'),
    ('PM-KIM-011','alarm_limit_misconfigured','operator_config_error','retrain_operator','2026-07-21','2026-07-14','closed','internal_only',0.00,'Nurse retrained on SpO2 alarm-limit policy')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.patient_monitor_r3150 e
    on e.organization_id = v_org_id and e.monitor_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Verdict distribution
create or replace function public.founder_r3150_verdict_rollup()
returns table(verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.patient_monitor_r3150)
  select l.verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.patient_monitor_r3150 l
  group by l.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3150_verdict_rollup() from public, anon;
grant execute on function public.founder_r3150_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3150_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  passed bigint,
  conditional bigint,
  accuracy_fails bigint,
  alarm_fails bigint,
  quarantined bigint,
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
    count(*) filter (where l.verdict = 'pass')::bigint,
    count(*) filter (where l.verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.verdict = 'fail_accuracy')::bigint,
    count(*) filter (where l.verdict = 'fail_alarm')::bigint,
    count(*) filter (where l.verdict = 'quarantined')::bigint,
    round(100.0 * count(*) filter (where l.verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.patient_monitor_r3150 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3150_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3150_hospital_scorecard() to authenticated;

-- 3) Parameter × reference-source matrix
create or replace function public.founder_r3150_parameter_matrix()
returns table(parameter text, reference_source text, tests bigint, passed bigint, avg_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.reference_source, count(*)::bigint,
    count(*) filter (where l.verdict = 'pass')::bigint,
    round(avg(l.error_pct), 2)
  from public.patient_monitor_r3150 l
  group by l.parameter, l.reference_source
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3150_parameter_matrix() from public, anon;
grant execute on function public.founder_r3150_parameter_matrix() to authenticated;

-- 4) Daily accuracy/alarm trend
create or replace function public.founder_r3150_daily_trend()
returns table(test_date date, tests bigint, passed bigint, accuracy_fails bigint, alarm_fails bigint, avg_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.verdict = 'pass')::bigint,
    count(*) filter (where l.verdict = 'fail_accuracy')::bigint,
    count(*) filter (where l.verdict in ('fail_alarm','fail_waveform'))::bigint,
    round(avg(l.error_pct), 2)
  from public.patient_monitor_r3150 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3150_daily_trend() from public, anon;
grant execute on function public.founder_r3150_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3150_capa_status_board()
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
  from public.patient_monitor_capa_actions_r3150 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3150_capa_status_board() from public, anon;
grant execute on function public.founder_r3150_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3150_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.patient_monitor_capa_actions_r3150)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.patient_monitor_capa_actions_r3150 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3150_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3150_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3150_regulatory_impact_digest()
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
  from public.patient_monitor_capa_actions_r3150 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3150_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3150_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (individual concerns)
create or replace function public.founder_r3150_high_risk_queue()
returns table(
  hospital_name text,
  ward_or_unit text,
  monitor_asset_tag text,
  parameter text,
  test_date date,
  verdict text,
  error_pct numeric,
  alarm_limit_set text,
  alarm_audible_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_or_unit, l.monitor_asset_tag, l.parameter, l.test_date,
    l.verdict, l.error_pct, l.alarm_limit_set, l.alarm_audible_test, l.notes
  from public.patient_monitor_r3150 l
  where l.verdict in ('fail_accuracy','fail_alarm','fail_waveform','quarantined','conditional_pass','pending_review')
     or l.alarm_audible_test in ('fail','inaudible','delayed')
     or l.alarm_limit_set in ('disabled','not_configured','mislabeled')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3150_high_risk_queue() from public, anon;
grant execute on function public.founder_r3150_high_risk_queue() to authenticated;
