-- Round 3415: Customer Hospital Capnography (EtCO2) & Multi-Gas Analyzer Module QC Audit
-- Anesthesia/ICU monitoring QA — module type × location × zero-cal × CO2 accuracy mmHg × agent-ID × sampling-line patency × water trap × response time × gas-cal × alarm limits × calibration × CAPA

-- =============================================================================
-- TABLE 1: capno_multigas_qc_r3415 — per-module capnography/multigas QC checks
-- =============================================================================
create table if not exists public.capno_multigas_qc_r3415 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  module_type text not null check (module_type in (
    'mainstream_capnography','sidestream_capnography','multigas_analyzer',
    'standalone_etco2','transcutaneous_co2'
  )),
  location text not null check (location in (
    'ot','icu','emergency','recovery','procedural_sedation'
  )),
  check_date date not null,
  co2_accuracy_error_mmhg numeric(5,2),
  agent_id_accuracy_ok text not null check (agent_id_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  sampling_line_patency_ok boolean not null,
  water_trap_ok boolean not null,
  zero_calibration_ok boolean not null,
  response_time_ok boolean not null,
  gas_calibration_current boolean not null,
  alarm_limits_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capno_multigas_qc_r3415 enable row level security;

create index if not exists idx_capno_multigas_qc_r3415_org on public.capno_multigas_qc_r3415(organization_id);
create index if not exists idx_capno_multigas_qc_r3415_date on public.capno_multigas_qc_r3415(check_date);
create index if not exists idx_capno_multigas_qc_r3415_verdict on public.capno_multigas_qc_r3415(qc_verdict);

-- =============================================================================
-- TABLE 2: capno_multigas_qc_capa_actions_r3415 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.capno_multigas_qc_capa_actions_r3415 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.capno_multigas_qc_r3415(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'zero_calibration_drift','co2_accuracy_out_of_tolerance','agent_id_accuracy_fail',
    'sampling_line_blocked','water_trap_fault','response_time_slow',
    'gas_calibration_overdue','alarm_limits_incorrect','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_drift','sampling_line_occlusion','water_trap_saturated','pump_degraded',
    'gas_cell_contamination','operator_setup_error','software_config_error',
    'pending_investigation','preventive_service_backlog','gas_cylinder_expired'
  )),
  corrective_action text not null check (corrective_action in (
    'rezero_and_recalibrate','replace_sampling_line','replace_water_trap','clean_or_replace_gas_cell',
    'replace_sampling_pump','recalibrate_with_span_gas','update_software_config',
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

alter table public.capno_multigas_qc_capa_actions_r3415 enable row level security;

create index if not exists idx_capno_multigas_capa_r3415_log on public.capno_multigas_qc_capa_actions_r3415(qc_log_id);
create index if not exists idx_capno_multigas_capa_r3415_status on public.capno_multigas_qc_capa_actions_r3415(capa_status);

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
  insert into public.capno_multigas_qc_r3415 (
    organization_id, hospital_name, device_code, module_type, location, check_date,
    co2_accuracy_error_mmhg, agent_id_accuracy_ok, sampling_line_patency_ok, water_trap_ok,
    zero_calibration_ok, response_time_ok, gas_calibration_current, alarm_limits_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.mtype, q.loc, q.cdate::date,
    q.co2err, q.agentid, q.samp, q.water,
    q.zerocal, q.resp, q.gascal, q.alarm,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','CAP-APL-01','mainstream_capnography','ot','2026-07-03',
     0.8,'not_applicable',true,true,true,true,true,true,true,'pass','Mainstream EtCO2 module QC within tolerance'),
    ('Apollo Chennai','MGA-APL-02','multigas_analyzer','ot','2026-07-03',
     0.5,'ok',true,true,true,true,true,true,true,'pass','Multigas analyzer agent ID accurate, span-gas cal current'),
    ('Fortis Gurgaon','SCP-FRT-11','sidestream_capnography','icu','2026-07-02',
     1.4,'not_applicable',true,false,true,true,true,true,true,'conditional_pass','Water trap saturated — CO2 within tolerance, trap replacement due'),
    ('Fortis Gurgaon','MGA-FRT-12','multigas_analyzer','ot','2026-07-02',
     3.6,'fail',true,true,false,true,false,true,true,'fail','Agent ID fail, zero-cal failed and span-gas cal overdue'),
    ('Manipal Bengaluru','SCP-MNP-21','sidestream_capnography','procedural_sedation','2026-07-01',
     5.2,'not_applicable',false,false,true,false,true,true,false,'removed_from_service','Sampling line blocked, slow response, calibration overdue — removed'),
    ('Manipal Bengaluru','ETC-MNP-22','standalone_etco2','recovery','2026-07-01',
     0.9,'not_applicable',true,true,true,true,true,true,true,'pass','Standalone EtCO2 recovery-bay module QC nominal'),
    ('AIIMS Delhi','CAP-AIM-31','mainstream_capnography','icu','2026-06-30',
     1.1,'not_applicable',true,true,true,true,true,true,true,'conditional_pass','CO2 accuracy 1.1 mmHg within limit but upward drift trend flagged'),
    ('AIIMS Delhi','MGA-AIM-32','multigas_analyzer','ot','2026-06-30',
     4.1,'drift',true,true,true,false,false,true,true,'fail','Multigas response time slow and span-gas cal overdue, agent ID drifting'),
    ('CMC Vellore','SCP-CMC-41','sidestream_capnography','emergency','2026-06-29',
     0.7,'not_applicable',true,true,true,true,true,true,true,'pass','Sidestream capnography ED module QC pass'),
    ('CMC Vellore','TCP-CMC-42','transcutaneous_co2','icu','2026-06-29',
     2.3,'not_applicable',true,true,false,true,true,true,false,'conditional_pass','Transcutaneous CO2 zero-cal drift and calibration overdue — membrane change ordered'),
    ('KIMS Hyderabad','CAP-KIM-51','mainstream_capnography','ot','2026-06-28',
     0.6,'not_applicable',true,true,true,true,true,true,true,'pass','Mainstream capnography QC pass post-AMC'),
    ('KIMS Hyderabad','ETC-KIM-52','standalone_etco2','procedural_sedation','2026-06-28',
     1.9,'not_applicable',true,true,true,false,true,false,true,'conditional_pass','EtCO2 response time slow and alarm limits misconfigured — recheck due'),
    ('Yashoda Hyderabad','MGA-YSH-61','multigas_analyzer','icu','2026-06-27',
     0.4,'ok',true,true,true,true,true,true,true,'pass','Multigas analyzer ICU QC nominal'),
    ('Kokilaben Mumbai','SCP-KKB-71','sidestream_capnography','ot','2026-06-27',
     6.1,'not_applicable',false,false,false,false,false,false,false,'removed_from_service','Sampling line occluded with multiple QC failures — removed from service')
  ) as q(hosp, dcode, mtype, loc, cdate, co2err, agentid, samp, water, zerocal, resp, gascal, alarm, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.capno_multigas_qc_capa_actions_r3415 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MGA-FRT-12','zero_calibration_drift','sensor_drift','rezero_and_recalibrate','in_progress','iso_13485_deviation','2026-07-06',null,12000.00,'Zero-cal reset; span-gas recalibration pending verification'),
    ('SCP-MNP-21','sampling_line_blocked','sampling_line_occlusion','replace_sampling_line','open','nabh_finding','2026-07-05',null,6500.00,'Sampling line occluded — replacement kit ordered'),
    ('MGA-AIM-32','response_time_slow','pump_degraded','replace_sampling_pump','escalated','patient_safety_alert','2026-07-04',null,28000.00,'Slow response with agent ID drift — escalated to OEM'),
    ('SCP-KKB-71','sampling_line_blocked','sampling_line_occlusion','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',38000.00,'Occluded line, multiple failures — module removed and replaced, validated'),
    ('SCP-FRT-11','water_trap_fault','water_trap_saturated','replace_water_trap','verification_pending','internal_only','2026-07-05',null,3200.00,'Water trap replaced — verify on next case'),
    ('TCP-CMC-42','calibration_overdue','gas_cell_contamination','clean_or_replace_gas_cell','overdue','internal_only','2026-06-30',null,15000.00,'Transcutaneous membrane/cell change past target — vendor delay'),
    ('ETC-KIM-52','alarm_limits_incorrect','software_config_error','update_software_config','open','none','2026-07-07',null,0.00,'Alarm limits reconfigured — recheck scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.capno_multigas_qc_r3415 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3415_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capno_multigas_qc_r3415)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.capno_multigas_qc_r3415 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3415_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3415_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3415_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  sampling_line_fail bigint,
  gas_cal_overdue bigint,
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
    count(*) filter (where l.sampling_line_patency_ok = false)::bigint,
    count(*) filter (where l.gas_calibration_current = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.capno_multigas_qc_r3415 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3415_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3415_hospital_scorecard() to authenticated;

-- 3) Module-type × location matrix
create or replace function public.founder_r3415_module_type_location_matrix()
returns table(module_type text, location text, checks bigint, passed bigint, failed bigint, avg_co2_error_mmhg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.module_type, l.location, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.co2_accuracy_error_mmhg), 2)
  from public.capno_multigas_qc_r3415 l
  group by l.module_type, l.location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3415_module_type_location_matrix() from public, anon;
grant execute on function public.founder_r3415_module_type_location_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3415_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, sampling_line_fail bigint, zero_cal_fail bigint)
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
    count(*) filter (where l.sampling_line_patency_ok = false)::bigint,
    count(*) filter (where l.zero_calibration_ok = false)::bigint
  from public.capno_multigas_qc_r3415 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3415_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3415_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3415_capa_status_board()
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
  from public.capno_multigas_qc_capa_actions_r3415 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3415_capa_status_board() from public, anon;
grant execute on function public.founder_r3415_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3415_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capno_multigas_qc_capa_actions_r3415)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.capno_multigas_qc_capa_actions_r3415 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3415_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3415_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3415_regulatory_impact_digest()
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
  from public.capno_multigas_qc_capa_actions_r3415 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3415_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3415_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3415_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  module_type text,
  location text,
  check_date date,
  qc_verdict text,
  agent_id_accuracy_ok text,
  co2_accuracy_error_mmhg numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.module_type, l.location, l.check_date,
    l.qc_verdict, l.agent_id_accuracy_ok, l.co2_accuracy_error_mmhg, l.notes
  from public.capno_multigas_qc_r3415 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.sampling_line_patency_ok = false
     or l.water_trap_ok = false
     or l.zero_calibration_ok = false
     or l.response_time_ok = false
     or l.gas_calibration_current = false
     or l.alarm_limits_ok = false
     or l.calibration_current = false
     or l.agent_id_accuracy_ok in ('drift','fail')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3415_high_risk_queue() from public, anon;
grant execute on function public.founder_r3415_high_risk_queue() to authenticated;
