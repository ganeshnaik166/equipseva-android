-- Round 3386: Customer Hospital Neuro-ICU Multimodal Monitoring QC Audit
-- Neuro-ICU QA — device type × unit × transducer zero-cal × pressure accuracy × signal quality × probe condition × electrode impedance × alarm test × reference-cal × cable integrity × CAPA

-- =============================================================================
-- TABLE 1: neuro_multimodal_qc_r3386 — per-device multimodal monitoring QC checks
-- =============================================================================
create table if not exists public.neuro_multimodal_qc_r3386 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'icp_monitor','cerebral_oximeter_nirs','bis_depth_monitor','entropy_monitor',
    'cerebral_microdialysis','jugular_oximetry'
  )),
  unit text not null check (unit in (
    'neuro_icu','neuro_ot','trauma_icu','general_icu'
  )),
  check_date date not null,
  transducer_zero_calibration_ok boolean not null,
  pressure_accuracy_error_mmhg numeric(5,2),
  signal_quality_ok boolean not null,
  sensor_probe_condition text not null check (sensor_probe_condition in (
    'good','worn','cracked','replace_due'
  )),
  electrode_impedance_ok text not null check (electrode_impedance_ok in (
    'ok','high','fail','not_applicable'
  )),
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  reference_calibration_ok boolean not null,
  cable_integrity_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.neuro_multimodal_qc_r3386 enable row level security;

create index if not exists idx_neuro_multimodal_qc_r3386_org on public.neuro_multimodal_qc_r3386(organization_id);
create index if not exists idx_neuro_multimodal_qc_r3386_date on public.neuro_multimodal_qc_r3386(check_date);
create index if not exists idx_neuro_multimodal_qc_r3386_verdict on public.neuro_multimodal_qc_r3386(qc_verdict);

-- =============================================================================
-- TABLE 2: neuro_multimodal_qc_capa_actions_r3386 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.neuro_multimodal_qc_capa_actions_r3386 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.neuro_multimodal_qc_r3386(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'zero_calibration_drift','pressure_accuracy_out_of_tolerance','signal_quality_degraded',
    'sensor_probe_damaged','electrode_impedance_high','alarm_test_failure',
    'reference_calibration_failure','cable_integrity_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_drift','probe_end_of_life','cable_connector_damaged','electrode_pad_dried',
    'optical_sensor_degraded','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','microdialysis_catheter_expired'
  )),
  corrective_action text not null check (corrective_action in (
    'rezero_and_recalibrate','replace_sensor_probe','replace_cable','replace_electrode_set',
    'replace_optical_sensor','update_software_config','retrain_neuro_staff',
    'remove_from_service','schedule_oem_service','replace_microdialysis_catheter','none_required'
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

alter table public.neuro_multimodal_qc_capa_actions_r3386 enable row level security;

create index if not exists idx_neuro_multimodal_capa_r3386_log on public.neuro_multimodal_qc_capa_actions_r3386(qc_log_id);
create index if not exists idx_neuro_multimodal_capa_r3386_status on public.neuro_multimodal_qc_capa_actions_r3386(capa_status);

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

  -- 14 QC check rows
  insert into public.neuro_multimodal_qc_r3386 (
    organization_id, hospital_name, device_code, device_type, unit, check_date,
    transducer_zero_calibration_ok, pressure_accuracy_error_mmhg, signal_quality_ok,
    sensor_probe_condition, electrode_impedance_ok, alarm_test,
    reference_calibration_ok, cable_integrity_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.unit, q.cdate::date,
    q.zerocal, q.perr, q.sigq,
    q.probe, q.imp, q.alarm,
    q.refcal, q.cable, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','ICP-APL-01','icp_monitor','neuro_icu','2026-07-03',
     true,0.6,true,'good','not_applicable','pass',true,true,true,'pass','Quarterly QC — ICP transducer within tolerance'),
    ('Apollo Chennai','NIRS-APL-02','cerebral_oximeter_nirs','neuro_ot','2026-07-03',
     true,null,true,'good','not_applicable','pass',true,true,true,'pass','NIRS cerebral oximetry optical sensor QC clean'),
    ('Fortis Gurgaon','BIS-FRT-11','bis_depth_monitor','neuro_ot','2026-07-02',
     true,null,true,'worn','high','pass',true,true,true,'conditional_pass','BIS electrode impedance high on one channel — sensor worn'),
    ('Fortis Gurgaon','ICP-FRT-12','icp_monitor','neuro_icu','2026-07-02',
     false,3.2,true,'good','not_applicable','pass',false,true,true,'fail','Zero-cal failed, 3.2 mmHg accuracy error and reference-cal failed'),
    ('Manipal Bengaluru','MDIA-MNP-21','cerebral_microdialysis','neuro_icu','2026-07-01',
     true,null,false,'replace_due','not_applicable','not_tested',true,true,false,'removed_from_service','Microdialysis catheter past dwell limit, signal poor — removed'),
    ('Manipal Bengaluru','ENT-MNP-22','entropy_monitor','neuro_ot','2026-07-01',
     true,null,true,'good','ok','pass',true,true,true,'pass','Entropy depth-of-anesthesia module QC nominal'),
    ('AIIMS Delhi','ICP-AIM-31','icp_monitor','trauma_icu','2026-06-30',
     true,1.1,true,'good','not_applicable','pass',true,true,true,'conditional_pass','ICP accuracy 1.1 mmHg within limit but upward drift trend flagged'),
    ('AIIMS Delhi','JUG-AIM-32','jugular_oximetry','trauma_icu','2026-06-30',
     true,null,false,'worn','not_applicable','fail',true,false,true,'fail','Jugular oximetry cable integrity and alarm test failed, signal poor'),
    ('CMC Vellore','BIS-CMC-41','bis_depth_monitor','general_icu','2026-06-29',
     true,null,true,'good','ok','pass',true,true,true,'pass','BIS depth-of-anesthesia monitor QC pass'),
    ('CMC Vellore','NIRS-CMC-42','cerebral_oximeter_nirs','neuro_icu','2026-06-29',
     true,null,true,'cracked','not_applicable','pass',true,true,false,'conditional_pass','NIRS sensor housing cracked and calibration overdue — replacement ordered'),
    ('KIMS Hyderabad','ICP-KIM-51','icp_monitor','neuro_icu','2026-06-28',
     true,0.9,true,'good','not_applicable','pass',true,true,true,'pass','ICP monitor QC pass post-AMC'),
    ('KIMS Hyderabad','ENT-KIM-52','entropy_monitor','general_icu','2026-06-28',
     true,null,true,'worn','high','not_tested',true,true,true,'conditional_pass','Entropy electrode impedance high and alarm not tested — recheck due'),
    ('Yashoda Hyderabad','MDIA-YSH-61','cerebral_microdialysis','trauma_icu','2026-06-27',
     true,null,true,'good','not_applicable','pass',true,true,true,'pass','Cerebral microdialysis analyser QC nominal'),
    ('Kokilaben Mumbai','ICP-KKB-71','icp_monitor','neuro_ot','2026-06-27',
     false,4.5,false,'cracked','not_applicable','fail',false,false,false,'removed_from_service','ICP transducer cracked with multiple failures — removed from service')
  ) as q(hosp, dcode, dtype, unit, cdate, zerocal, perr, sigq, probe, imp, alarm, refcal, cable, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.neuro_multimodal_qc_capa_actions_r3386 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ICP-FRT-12','pressure_accuracy_out_of_tolerance','transducer_drift','rezero_and_recalibrate','in_progress','iso_13485_deviation','2026-07-06',null,15000.00,'Transducer re-zeroed; reference-cal pending verification'),
    ('MDIA-MNP-21','preventive_maintenance_due','microdialysis_catheter_expired','replace_microdialysis_catheter','open','nabh_finding','2026-07-05',null,32000.00,'Catheter past dwell limit — replacement kit ordered'),
    ('JUG-AIM-32','cable_integrity_failure','cable_connector_damaged','replace_cable','escalated','patient_safety_alert','2026-07-04',null,8500.00,'Cable fail with alarm miss — escalated to OEM'),
    ('ICP-KKB-71','sensor_probe_damaged','probe_end_of_life','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',46000.00,'Cracked transducer removed; replacement installed and validated'),
    ('BIS-FRT-11','electrode_impedance_high','electrode_pad_dried','replace_electrode_set','verification_pending','internal_only','2026-07-05',null,4200.00,'Electrode set replaced — verify impedance next case'),
    ('NIRS-CMC-42','calibration_overdue','optical_sensor_degraded','replace_optical_sensor','overdue','internal_only','2026-06-30',null,21000.00,'NIRS sensor replacement past target date — vendor delay'),
    ('ENT-KIM-52','alarm_test_failure','software_config_error','update_software_config','open','none','2026-07-07',null,0.00,'Alarm module reconfigured — recheck scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.neuro_multimodal_qc_r3386 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3386_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuro_multimodal_qc_r3386)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.neuro_multimodal_qc_r3386 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3386_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3386_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3386_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  signal_fail bigint,
  impedance_issue bigint,
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
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.signal_quality_ok = false)::bigint,
    count(*) filter (where l.electrode_impedance_ok in ('high','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.neuro_multimodal_qc_r3386 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3386_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3386_hospital_scorecard() to authenticated;

-- 3) Device-type × unit matrix
create or replace function public.founder_r3386_device_type_unit_matrix()
returns table(device_type text, unit text, checks bigint, passed bigint, failed bigint, avg_pressure_error_mmhg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.unit, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.pressure_accuracy_error_mmhg), 2)
  from public.neuro_multimodal_qc_r3386 l
  group by l.device_type, l.unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3386_device_type_unit_matrix() from public, anon;
grant execute on function public.founder_r3386_device_type_unit_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3386_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, signal_fail bigint, impedance_issue bigint)
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
    count(*) filter (where l.signal_quality_ok = false)::bigint,
    count(*) filter (where l.electrode_impedance_ok in ('high','fail'))::bigint
  from public.neuro_multimodal_qc_r3386 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3386_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3386_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3386_capa_status_board()
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
  from public.neuro_multimodal_qc_capa_actions_r3386 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3386_capa_status_board() from public, anon;
grant execute on function public.founder_r3386_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3386_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.neuro_multimodal_qc_capa_actions_r3386)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.neuro_multimodal_qc_capa_actions_r3386 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3386_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3386_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3386_regulatory_impact_digest()
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
  from public.neuro_multimodal_qc_capa_actions_r3386 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3386_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3386_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3386_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  unit text,
  check_date date,
  qc_verdict text,
  sensor_probe_condition text,
  electrode_impedance_ok text,
  alarm_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.unit, l.check_date,
    l.qc_verdict, l.sensor_probe_condition, l.electrode_impedance_ok, l.alarm_test, l.notes
  from public.neuro_multimodal_qc_r3386 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.signal_quality_ok = false
     or l.electrode_impedance_ok in ('high','fail')
     or l.alarm_test = 'fail'
     or l.transducer_zero_calibration_ok = false
     or l.reference_calibration_ok = false
     or l.cable_integrity_ok = false
     or l.calibration_current = false
     or l.sensor_probe_condition in ('cracked','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3386_high_risk_queue() from public, anon;
grant execute on function public.founder_r3386_high_risk_queue() to authenticated;
