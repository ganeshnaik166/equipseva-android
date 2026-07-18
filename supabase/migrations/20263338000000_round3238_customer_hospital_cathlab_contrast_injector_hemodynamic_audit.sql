-- Round 3238: Customer Hospital Cath-Lab Contrast-Injector & Hemodynamic-Recorder QC Audit
-- Cath-lab QA — injector model × flow-rate accuracy × pressure-limit test × air-detect × syringe heater × zero-cal × transducer accuracy × ECG-sync × CAPA

-- =============================================================================
-- TABLE 1: cathlab_injector_r3238 — individual injector + recorder QC audits
-- =============================================================================
create table if not exists public.cathlab_injector_r3238 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  cathlab_room_code text not null,
  injector_asset_tag text not null,
  injector_model text not null check (injector_model in (
    'medrad_mark_7_arterion','medrad_stellant','acist_cvi','guerbet_optivantage',
    'bracco_empower_cta','nemoto_press_duo','medtron_accutron_hp_d','ulrich_ct_motion'
  )),
  hemodynamic_recorder_model text not null check (hemodynamic_recorder_model in (
    'ge_mac_lab_im','philips_xper_flex_cardio','siemens_sensis_vibe','mennen_horizon_xvu'
  )),
  qc_date date not null,
  qc_started_at timestamptz not null,
  flow_rate_setpoint_ml_s numeric(5,2) not null,
  flow_rate_measured_ml_s numeric(5,2),
  flow_rate_error_pct numeric(5,2),
  pressure_limit_setpoint_psi int not null,
  pressure_limit_test text not null check (pressure_limit_test in (
    'pass','fail','over_pressure_no_cutoff','early_cutoff','not_run'
  )),
  air_detect_sensor_result text not null check (air_detect_sensor_result in (
    'pass','fail','intermittent','alarm_muted_found','not_run'
  )),
  syringe_heater_temp_c numeric(4,1),
  syringe_heater_status text not null check (syringe_heater_status in (
    'within_range','under_temp','over_temp','heater_fault','not_fitted'
  )),
  zero_cal_result text not null check (zero_cal_result in (
    'pass','fail','drift_recalibrated','not_run'
  )),
  transducer_error_mmhg numeric(4,1),
  transducer_accuracy_verdict text not null check (transducer_accuracy_verdict in (
    'within_1mmhg','within_2mmhg','out_of_tolerance','not_tested'
  )),
  ecg_sync_trigger_result text not null check (ecg_sync_trigger_result in (
    'pass','fail','intermittent_trigger','not_applicable'
  )),
  qc_verdict text not null check (qc_verdict in (
    'passed','conditional_pass','failed','removed_from_service','pending_review','recheck_scheduled'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cathlab_injector_r3238 enable row level security;

create index if not exists idx_cathlab_injector_r3238_org on public.cathlab_injector_r3238(organization_id);
create index if not exists idx_cathlab_injector_r3238_date on public.cathlab_injector_r3238(qc_date);
create index if not exists idx_cathlab_injector_r3238_verdict on public.cathlab_injector_r3238(qc_verdict);

-- =============================================================================
-- TABLE 2: cathlab_injector_capa_actions_r3238 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cathlab_injector_capa_actions_r3238 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cathlab_injector_r3238(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'flow_rate_deviation','pressure_cutoff_failure','air_detect_failure','syringe_heater_fault',
    'zero_cal_drift','transducer_out_of_tolerance','ecg_sync_failure','alarm_configuration','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'injector_piston_wear','pressure_sensor_drift','air_detect_optics_dirty','heater_element_failing',
    'transducer_cable_damaged','stopcock_leak','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_piston_assembly','recalibrate_pressure_sensor','clean_air_detect_optics','replace_heater_module',
    'replace_transducer_cable','rezero_and_recalibrate','update_software_config','retrain_cathlab_staff',
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

alter table public.cathlab_injector_capa_actions_r3238 enable row level security;

create index if not exists idx_cathlab_capa_r3238_log on public.cathlab_injector_capa_actions_r3238(qc_log_id);
create index if not exists idx_cathlab_capa_r3238_status on public.cathlab_injector_capa_actions_r3238(capa_status);

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

  -- 14 QC audit rows
  insert into public.cathlab_injector_r3238 (
    organization_id, hospital_name, cathlab_room_code, injector_asset_tag, injector_model,
    hemodynamic_recorder_model, qc_date, qc_started_at,
    flow_rate_setpoint_ml_s, flow_rate_measured_ml_s, flow_rate_error_pct,
    pressure_limit_setpoint_psi, pressure_limit_test, air_detect_sensor_result,
    syringe_heater_temp_c, syringe_heater_status, zero_cal_result,
    transducer_error_mmhg, transducer_accuracy_verdict, ecg_sync_trigger_result,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.room, q.tag, q.model,
    q.rec, q.qcd::date, q.qcs::timestamptz,
    q.fset, q.fmeas, q.ferr,
    q.plim, q.plt, q.ads,
    q.sht, q.shs, q.zc,
    q.terr, q.tav, q.ecg,
    q.qv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CL-1','INJ-APL-101','medrad_stellant','ge_mac_lab_im','2026-07-02','2026-07-02 07:15:00+05:30',
     5.00,5.08,1.60,325,'pass','pass',37.2,'within_range','pass',0.8,'within_1mmhg','pass','passed','Quarterly QC — all parameters nominal'),
    ('Apollo Hyderabad Jubilee Hills','CL-2','INJ-APL-102','medrad_mark_7_arterion','ge_mac_lab_im','2026-07-02','2026-07-02 08:05:00+05:30',
     6.00,6.55,9.20,300,'pass','pass',36.8,'within_range','pass',1.2,'within_2mmhg','pass','conditional_pass','Flow error 9.2% above 5% tolerance — recheck booked'),
    ('Fortis Bannerghatta Bengaluru','CL-1','INJ-FRT-201','acist_cvi','philips_xper_flex_cardio','2026-07-01','2026-07-01 06:40:00+05:30',
     4.00,3.98,-0.50,300,'pass','fail',37.0,'within_range','pass',0.6,'within_1mmhg','pass','removed_from_service','Air-detect missed 0.5 mL bolus challenge — unit pulled'),
    ('Fortis Bannerghatta Bengaluru','CL-2','INJ-FRT-202','guerbet_optivantage','philips_xper_flex_cardio','2026-07-01','2026-07-01 07:30:00+05:30',
     5.00,5.03,0.60,325,'over_pressure_no_cutoff','pass',36.5,'within_range','drift_recalibrated',2.6,'out_of_tolerance','pass','failed','No cutoff at 325 psi and transducer 2.6 mmHg off'),
    ('Manipal Whitefield Bengaluru','CL-1','INJ-MNP-301','medrad_stellant','siemens_sensis_vibe','2026-06-30','2026-06-30 08:10:00+05:30',
     5.00,5.02,0.40,300,'pass','pass',34.1,'under_temp','pass',0.9,'within_1mmhg','pass','conditional_pass','Syringe heater 34.1C below 35C floor — heater watch'),
    ('Manipal Whitefield Bengaluru','CL-2','INJ-MNP-302','nemoto_press_duo','siemens_sensis_vibe','2026-06-30','2026-06-30 09:00:00+05:30',
     3.50,3.49,-0.30,250,'pass','pass',37.4,'within_range','pass',0.5,'within_1mmhg','intermittent_trigger','conditional_pass','ECG-sync dropped 2 of 20 test beats'),
    ('AIIMS New Delhi Ansari Nagar','CL-3','INJ-AIM-401','medrad_mark_7_arterion','mennen_horizon_xvu','2026-06-29','2026-06-29 06:20:00+05:30',
     6.00,6.04,0.70,325,'pass','pass',37.1,'within_range','fail',3.4,'out_of_tolerance','pass','failed','Zero-cal failed twice — transducer replaced same day'),
    ('AIIMS New Delhi Ansari Nagar','CL-4','INJ-AIM-402','medtron_accutron_hp_d','mennen_horizon_xvu','2026-06-29','2026-06-29 07:10:00+05:30',
     5.00,4.99,-0.20,300,'pass','pass',37.0,'within_range','pass',0.4,'within_1mmhg','pass','passed','Annual QC clean pass'),
    ('KIMS Secunderabad','CL-1','INJ-KIM-501','acist_cvi','ge_mac_lab_im','2026-06-28','2026-06-28 06:50:00+05:30',
     4.50,4.12,-8.40,300,'early_cutoff','pass',37.3,'within_range','pass',1.0,'within_1mmhg','pass','failed','Early cutoff at 210 psi and flow low — piston wear suspected'),
    ('KIMS Secunderabad','CL-2','INJ-KIM-502','bracco_empower_cta','ge_mac_lab_im','2026-06-28','2026-06-28 07:45:00+05:30',
     5.00,5.01,0.20,300,'pass','intermittent',37.0,'within_range','pass',0.7,'within_1mmhg','not_applicable','pending_review','Air-detect intermittent on retest — held for OEM check'),
    ('Care Hospitals Banjara Hills','CL-1','INJ-CAR-601','guerbet_optivantage','philips_xper_flex_cardio','2026-06-27','2026-06-27 08:30:00+05:30',
     5.00,5.06,1.20,325,'pass','pass',39.6,'over_temp','pass',0.8,'within_1mmhg','pass','conditional_pass','Heater 39.6C above 38C ceiling — thermostat check due'),
    ('Yashoda Somajiguda Hyderabad','CL-2','INJ-YSH-701','medrad_stellant','siemens_sensis_vibe','2026-06-27','2026-06-27 09:20:00+05:30',
     6.00,6.02,0.30,325,'pass','pass',37.2,'within_range','pass',0.6,'within_1mmhg','pass','passed','Post-AMC verification pass'),
    ('St John''s Bengaluru','CL-1','INJ-STJ-801','nemoto_press_duo','mennen_horizon_xvu','2026-06-26','2026-06-26 06:15:00+05:30',
     4.00,null,null,300,'not_run','not_run',null,'not_fitted','fail',null,'not_tested','fail','recheck_scheduled','Recorder zero-cal and ECG-sync failed — QC aborted, revisit booked'),
    ('Rainbow Children''s Hyderabad','CL-1','INJ-RBW-901','medtron_accutron_hp_d','ge_mac_lab_im','2026-06-26','2026-06-26 07:40:00+05:30',
     2.50,2.51,0.40,200,'pass','pass',36.9,'within_range','pass',0.9,'within_1mmhg','pass','passed','Paediatric low-flow protocol verified')
  ) as q(hosp, room, tag, model, rec, qcd, qcs, fset, fmeas, ferr, plim, plt, ads, sht, shs, zc, terr, tav, ecg, qv, nt);

  -- CAPA seed — attach to specific audits via asset tag
  insert into public.cathlab_injector_capa_actions_r3238 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('INJ-FRT-201','air_detect_failure','air_detect_optics_dirty','clean_air_detect_optics','in_progress','patient_safety_alert','2026-07-06',null,18000.00,'Optics cleaned — awaiting bolus re-challenge test'),
    ('INJ-FRT-202','pressure_cutoff_failure','pressure_sensor_drift','recalibrate_pressure_sensor','escalated','cdsco_notifiable','2026-07-05',null,42000.00,'No cutoff at 325 psi — escalated to OEM engineer'),
    ('INJ-AIM-401','zero_cal_drift','transducer_cable_damaged','replace_transducer_cable','closed','iso_13485_deviation','2026-07-01','2026-06-29',9500.00,'Cable replaced, re-zero within 0.4 mmHg'),
    ('INJ-KIM-501','flow_rate_deviation','injector_piston_wear','replace_piston_assembly','open','nabh_finding','2026-07-08',null,68000.00,'Piston kit on order from ACIST'),
    ('INJ-STJ-801','ecg_sync_failure','software_config_error','update_software_config','verification_pending','internal_only','2026-07-04',null,0.00,'Sync source remapped to lead II — verify on next case day'),
    ('INJ-CAR-601','syringe_heater_fault','heater_element_failing','replace_heater_module','overdue','internal_only','2026-06-24',null,12500.00,'Heater module past target date — AMC vendor delayed')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cathlab_injector_r3238 e
    on e.organization_id = v_org_id and e.injector_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3238_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cathlab_injector_r3238)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cathlab_injector_r3238 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3238_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3238_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3238_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  air_detect_fail bigint,
  pressure_test_fail bigint,
  zero_cal_fail bigint,
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
    count(*) filter (where l.qc_verdict = 'passed')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('failed','removed_from_service'))::bigint,
    count(*) filter (where l.air_detect_sensor_result in ('fail','intermittent','alarm_muted_found'))::bigint,
    count(*) filter (where l.pressure_limit_test in ('fail','over_pressure_no_cutoff','early_cutoff'))::bigint,
    count(*) filter (where l.zero_cal_result = 'fail')::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'passed')::numeric / nullif(count(*),0), 1)
  from public.cathlab_injector_r3238 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3238_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3238_hospital_scorecard() to authenticated;

-- 3) Injector model × recorder model matrix
create or replace function public.founder_r3238_injector_recorder_matrix()
returns table(injector_model text, hemodynamic_recorder_model text, audits bigint, passed bigint, avg_flow_error_pct numeric, avg_transducer_error_mmhg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.injector_model, l.hemodynamic_recorder_model, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'passed')::bigint,
    round(avg(l.flow_rate_error_pct), 2),
    round(avg(l.transducer_error_mmhg), 1)
  from public.cathlab_injector_r3238 l
  group by l.injector_model, l.hemodynamic_recorder_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3238_injector_recorder_matrix() from public, anon;
grant execute on function public.founder_r3238_injector_recorder_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3238_daily_qc_trend()
returns table(qc_date date, audits bigint, passed bigint, failed bigint, air_detect_fail bigint, zero_cal_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.qc_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'passed')::bigint,
    count(*) filter (where l.qc_verdict in ('failed','removed_from_service'))::bigint,
    count(*) filter (where l.air_detect_sensor_result in ('fail','intermittent','alarm_muted_found'))::bigint,
    count(*) filter (where l.zero_cal_result = 'fail')::bigint
  from public.cathlab_injector_r3238 l
  group by l.qc_date
  order by l.qc_date desc;
end;
$$;

revoke execute on function public.founder_r3238_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3238_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3238_capa_status_board()
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
  from public.cathlab_injector_capa_actions_r3238 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3238_capa_status_board() from public, anon;
grant execute on function public.founder_r3238_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3238_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cathlab_injector_capa_actions_r3238)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cathlab_injector_capa_actions_r3238 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3238_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3238_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3238_regulatory_impact_digest()
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
  from public.cathlab_injector_capa_actions_r3238 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3238_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3238_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3238_high_risk_queue()
returns table(
  hospital_name text,
  cathlab_room_code text,
  injector_asset_tag text,
  qc_date date,
  qc_verdict text,
  pressure_limit_test text,
  air_detect_sensor_result text,
  zero_cal_result text,
  transducer_accuracy_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.cathlab_room_code, l.injector_asset_tag, l.qc_date,
    l.qc_verdict, l.pressure_limit_test, l.air_detect_sensor_result, l.zero_cal_result,
    l.transducer_accuracy_verdict, l.notes
  from public.cathlab_injector_r3238 l
  where l.qc_verdict in ('conditional_pass','failed','removed_from_service','pending_review','recheck_scheduled')
     or l.pressure_limit_test in ('fail','over_pressure_no_cutoff','early_cutoff')
     or l.air_detect_sensor_result in ('fail','intermittent','alarm_muted_found')
     or l.zero_cal_result = 'fail'
     or l.transducer_accuracy_verdict = 'out_of_tolerance'
     or l.ecg_sync_trigger_result in ('fail','intermittent_trigger')
  order by l.qc_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3238_high_risk_queue() from public, anon;
grant execute on function public.founder_r3238_high_risk_queue() to authenticated;
