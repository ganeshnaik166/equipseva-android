-- Round 3330: Customer Hospital Sleep-Lab PSG / CPAP-Titration QC Audit
-- Sleep-lab QA — device type × channel signal quality × airflow/thermistor × SpO2 sensor × pressure delivery × calibration signal × electrode impedance × data export × CAPA

-- =============================================================================
-- TABLE 1: sleep_lab_qc_r3330 — per-device sleep-lab QC checks
-- =============================================================================
create table if not exists public.sleep_lab_qc_r3330 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'psg_system','cpap_titration','bipap_titration','home_sleep_test','actigraphy_unit','oximetry_recorder'
  )),
  sleep_lab text not null,
  check_date date not null,
  channel_signal_quality text not null check (channel_signal_quality in (
    'excellent','acceptable','degraded','fail'
  )),
  eeg_eog_emg_channels_ok boolean not null,
  airflow_thermistor_ok boolean not null,
  spo2_sensor_ok boolean not null,
  pressure_delivery_accuracy_ok text not null check (pressure_delivery_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  calibration_signal_ok boolean not null,
  electrode_impedance_ok boolean not null,
  data_export_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.sleep_lab_qc_r3330 enable row level security;

create index if not exists idx_sleep_lab_qc_r3330_org on public.sleep_lab_qc_r3330(organization_id);
create index if not exists idx_sleep_lab_qc_r3330_date on public.sleep_lab_qc_r3330(check_date);
create index if not exists idx_sleep_lab_qc_r3330_verdict on public.sleep_lab_qc_r3330(qc_verdict);

-- =============================================================================
-- TABLE 2: sleep_lab_qc_capa_actions_r3330 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.sleep_lab_qc_capa_actions_r3330 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.sleep_lab_qc_r3330(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'signal_quality_degraded','eeg_channel_fault','airflow_sensor_fault','spo2_sensor_fault',
    'pressure_delivery_deviation','calibration_failure','electrode_impedance_high','data_export_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'electrode_wear','sensor_cable_damaged','thermistor_degraded','spo2_probe_worn',
    'pressure_transducer_drift','calibration_reference_drift','amplifier_channel_fault',
    'software_export_bug','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_electrode_set','replace_sensor_cable','replace_thermistor','replace_spo2_probe',
    'recalibrate_pressure_module','recalibrate_reference_signal','replace_amplifier_board',
    'patch_export_software','retrain_sleep_tech','remove_from_service','schedule_oem_service','none_required'
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

alter table public.sleep_lab_qc_capa_actions_r3330 enable row level security;

create index if not exists idx_sleep_lab_capa_r3330_log on public.sleep_lab_qc_capa_actions_r3330(qc_log_id);
create index if not exists idx_sleep_lab_capa_r3330_status on public.sleep_lab_qc_capa_actions_r3330(capa_status);

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

  -- 14 sleep-lab QC rows
  insert into public.sleep_lab_qc_r3330 (
    organization_id, hospital_name, device_code, device_type, sleep_lab, check_date,
    channel_signal_quality, eeg_eog_emg_channels_ok, airflow_thermistor_ok, spo2_sensor_ok,
    pressure_delivery_accuracy_ok, calibration_signal_ok, electrode_impedance_ok, data_export_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.slab, q.cd::date,
    q.csq, q.eeg, q.airflow, q.spo2,
    q.pda, q.calsig, q.imp, q.dexp,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','PSG-APL-01','psg_system','Sleep Lab A','2026-07-10',
     'excellent',true,true,true,'ok',true,true,true,true,'pass','Monthly PSG QC — all 32 channels clean'),
    ('Apollo Chennai Greams Road','CPAP-APL-11','cpap_titration','Sleep Lab A','2026-07-10',
     'acceptable',true,true,true,'ok',true,true,true,true,'pass','CPAP titration verified 4-20 cmH2O'),
    ('Fortis Gurgaon','PSG-FRT-01','psg_system','Neuro Sleep Unit','2026-07-09',
     'degraded',true,true,true,'not_applicable',true,false,true,true,'conditional_pass','C3/C4 electrode impedance high — re-prep advised'),
    ('Fortis Gurgaon','BIPAP-FRT-21','bipap_titration','Neuro Sleep Unit','2026-07-09',
     'acceptable',true,true,true,'drift',true,true,true,true,'conditional_pass','BiPAP IPAP delivered 1.8 cmH2O low — transducer drift'),
    ('Manipal Bengaluru Old Airport Road','PSG-MNP-01','psg_system','Sleep Disorders Centre','2026-07-08',
     'fail',false,true,true,'not_applicable',true,true,true,true,'removed_from_service','EEG amplifier channel dead on F3 — unit pulled'),
    ('Manipal Bengaluru Old Airport Road','HST-MNP-31','home_sleep_test','Home Sleep Program','2026-07-08',
     'acceptable',true,true,true,'not_applicable',true,true,true,true,'pass','HST airflow + SpO2 nominal, dispatch cleared'),
    ('AIIMS Delhi Ansari Nagar','PSG-AIM-01','psg_system','Cardio-Resp Sleep Lab','2026-07-07',
     'degraded',true,false,true,'not_applicable',true,true,true,true,'conditional_pass','Airflow thermistor intermittent — replacement scheduled'),
    ('AIIMS Delhi Ansari Nagar','OXI-AIM-41','oximetry_recorder','Cardio-Resp Sleep Lab','2026-07-07',
     'acceptable',true,true,false,'not_applicable',true,true,true,true,'conditional_pass','SpO2 probe reading 3% low vs reference oximeter'),
    ('CMC Vellore','PSG-CMC-01','psg_system','Sleep Medicine Unit','2026-07-06',
     'excellent',true,true,true,'ok',true,true,true,true,'pass','Annual PSG QC clean pass'),
    ('CMC Vellore','CPAP-CMC-11','cpap_titration','Sleep Medicine Unit','2026-07-06',
     'fail',true,true,true,'fail',true,true,false,true,'fail','CPAP pressure delivery fail + data export corrupt'),
    ('KIMS Hyderabad','ACT-KIM-51','actigraphy_unit','Sleep Lab','2026-07-05',
     'acceptable',true,true,true,'not_applicable',true,true,false,false,'conditional_pass','Actigraphy export needs firmware update, calibration overdue'),
    ('KIMS Hyderabad','BIPAP-KIM-21','bipap_titration','Sleep Lab','2026-07-05',
     'excellent',true,true,true,'ok',true,true,true,true,'pass','BiPAP titration pass, all sensors nominal'),
    ('Medanta Gurugram','PSG-MDT-01','psg_system','Institute of Sleep Medicine','2026-07-04',
     'acceptable',true,true,true,'ok',false,true,true,true,'conditional_pass','Calibration square-wave signal distorted — recal booked'),
    ('Kokilaben Mumbai','HST-KOK-31','home_sleep_test','Home Sleep Service','2026-07-04',
     'excellent',true,true,true,'not_applicable',true,true,true,true,'pass','HST QC pass, calibration current')
  ) as q(hosp, dcode, dtype, slab, cd, csq, eeg, airflow, spo2, pda, calsig, imp, dexp, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.sleep_lab_qc_capa_actions_r3330 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PSG-FRT-01','electrode_impedance_high','electrode_wear','replace_electrode_set','in_progress','nabh_finding','2026-07-14',null,14500.00,'Gold-cup electrode set replaced — re-prep impedance re-check pending'),
    ('BIPAP-FRT-21','pressure_delivery_deviation','pressure_transducer_drift','recalibrate_pressure_module','open','iso_13485_deviation','2026-07-13',null,26000.00,'IPAP 1.8 cmH2O low — transducer recalibration scheduled with OEM'),
    ('PSG-MNP-01','eeg_channel_fault','amplifier_channel_fault','replace_amplifier_board','escalated','patient_safety_alert','2026-07-11',null,88000.00,'F3 amplifier channel dead — headbox board on order, unit out of service'),
    ('PSG-AIM-01','airflow_sensor_fault','thermistor_degraded','replace_thermistor','open','internal_only','2026-07-12',null,9500.00,'Airflow thermistor intermittent — spare thermistor requisitioned'),
    ('OXI-AIM-41','spo2_sensor_fault','spo2_probe_worn','replace_spo2_probe','verification_pending','internal_only','2026-07-10','2026-07-09',6800.00,'SpO2 probe swapped, awaiting reference-oximeter cross-check'),
    ('CPAP-CMC-11','pressure_delivery_deviation','pressure_transducer_drift','recalibrate_pressure_module','escalated','cdsco_notifiable','2026-07-09',null,32000.00,'Pressure delivery fail — device removed, CDSCO notifiable review opened'),
    ('ACT-KIM-51','data_export_failure','software_export_bug','patch_export_software','overdue','internal_only','2026-07-02',null,0.00,'Export firmware patch past target date — vendor build delayed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.sleep_lab_qc_r3330 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3330_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sleep_lab_qc_r3330)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.sleep_lab_qc_r3330 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3330_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3330_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3330_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  electrode_impedance_fail bigint,
  airflow_fail bigint,
  spo2_fail bigint,
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
    count(*) filter (where l.electrode_impedance_ok = false)::bigint,
    count(*) filter (where l.airflow_thermistor_ok = false)::bigint,
    count(*) filter (where l.spo2_sensor_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.sleep_lab_qc_r3330 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3330_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3330_hospital_scorecard() to authenticated;

-- 3) Device type × channel signal-quality matrix
create or replace function public.founder_r3330_device_type_signal_matrix()
returns table(device_type text, channel_signal_quality text, checks bigint, passed bigint, failed_removed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.channel_signal_quality, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint
  from public.sleep_lab_qc_r3330 l
  group by l.device_type, l.channel_signal_quality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3330_device_type_signal_matrix() from public, anon;
grant execute on function public.founder_r3330_device_type_signal_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3330_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, signal_degraded bigint, calibration_overdue bigint)
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
    count(*) filter (where l.channel_signal_quality in ('degraded','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.sleep_lab_qc_r3330 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3330_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3330_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3330_capa_status_board()
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
  from public.sleep_lab_qc_capa_actions_r3330 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3330_capa_status_board() from public, anon;
grant execute on function public.founder_r3330_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3330_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.sleep_lab_qc_capa_actions_r3330)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.sleep_lab_qc_capa_actions_r3330 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3330_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3330_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3330_regulatory_impact_digest()
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
  from public.sleep_lab_qc_capa_actions_r3330 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3330_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3330_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3330_high_risk_queue()
returns table(
  hospital_name text,
  sleep_lab text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  channel_signal_quality text,
  pressure_delivery_accuracy_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.sleep_lab, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.channel_signal_quality, l.pressure_delivery_accuracy_ok, l.notes
  from public.sleep_lab_qc_r3330 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.channel_signal_quality in ('degraded','fail')
     or l.eeg_eog_emg_channels_ok = false
     or l.airflow_thermistor_ok = false
     or l.spo2_sensor_ok = false
     or l.pressure_delivery_accuracy_ok in ('drift','fail')
     or l.calibration_signal_ok = false
     or l.electrode_impedance_ok = false
     or l.data_export_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3330_high_risk_queue() from public, anon;
grant execute on function public.founder_r3330_high_risk_queue() to authenticated;
