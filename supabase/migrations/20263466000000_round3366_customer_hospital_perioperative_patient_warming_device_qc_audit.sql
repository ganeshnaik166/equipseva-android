-- Round 3366: Customer Hospital Perioperative Patient-Warming Device QC Audit
-- Warming-device QA — device type × temperature accuracy × over-temp cutoff × airflow filter × hose/blanket × burn-risk × cabinet setpoint × alarm test × hygiene × calibration × CAPA

-- =============================================================================
-- TABLE 1: warming_device_qc_r3366 — individual warming-device QC checks
-- =============================================================================
create table if not exists public.warming_device_qc_r3366 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'forced_air_warmer','warming_cabinet_blanket','warming_cabinet_fluid',
    'conductive_warming_mattress','underbody_warming'
  )),
  department text not null,
  check_date date not null,
  temperature_accuracy_error_c numeric(4,1),
  over_temp_cutoff_ok boolean not null,
  airflow_filter_condition text not null check (airflow_filter_condition in (
    'clean','due','blocked','not_applicable'
  )),
  hose_blanket_condition text not null check (hose_blanket_condition in (
    'good','worn','torn','replace_due'
  )),
  burn_risk_assessment_ok boolean not null,
  cabinet_setpoint_ok text not null check (cabinet_setpoint_ok in (
    'ok','drift','fail','not_applicable'
  )),
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  cleaning_hygiene_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.warming_device_qc_r3366 enable row level security;

create index if not exists idx_warming_device_qc_r3366_org on public.warming_device_qc_r3366(organization_id);
create index if not exists idx_warming_device_qc_r3366_date on public.warming_device_qc_r3366(check_date);
create index if not exists idx_warming_device_qc_r3366_verdict on public.warming_device_qc_r3366(qc_verdict);

-- =============================================================================
-- TABLE 2: warming_device_qc_capa_actions_r3366 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.warming_device_qc_capa_actions_r3366 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.warming_device_qc_r3366(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_accuracy_deviation','over_temp_cutoff_failure','airflow_filter_blocked',
    'hose_blanket_damage','burn_risk','cabinet_setpoint_drift','alarm_failure',
    'hygiene_contamination','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_drift','heater_element_fault','filter_clogged','hose_wear','blanket_perforation',
    'thermostat_fault','alarm_board_fault','cleaning_protocol_lapse','calibration_backlog',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_temperature_sensor','replace_heater_element','replace_air_filter',
    'replace_hose_blanket','adjust_thermostat','repair_alarm_circuit','deep_clean_and_disinfect',
    'schedule_calibration','remove_from_service','schedule_oem_service','none_required'
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

alter table public.warming_device_qc_capa_actions_r3366 enable row level security;

create index if not exists idx_warming_device_capa_r3366_log on public.warming_device_qc_capa_actions_r3366(qc_log_id);
create index if not exists idx_warming_device_capa_r3366_status on public.warming_device_qc_capa_actions_r3366(capa_status);

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

  -- 14 warming-device QC rows
  insert into public.warming_device_qc_r3366 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    temperature_accuracy_error_c, over_temp_cutoff_ok, airflow_filter_condition,
    hose_blanket_condition, burn_risk_assessment_ok, cabinet_setpoint_ok, alarm_test,
    cleaning_hygiene_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.taerr, q.otc, q.aff,
    q.hbc, q.bra, q.csp, q.alm,
    q.chy, q.calc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','WD-APL-101','forced_air_warmer','Operating Theatre 1','2026-07-03',
     0.3,true,'clean','good',true,'not_applicable','pass',true,true,'pass','Routine QC — forced-air warmer within 2C spec'),
    ('Apollo Chennai Greams Road','WD-APL-102','warming_cabinet_fluid','Operating Theatre 2','2026-07-03',
     0.6,true,'not_applicable','good',true,'ok','pass',true,true,'pass','Fluid warming cabinet setpoint verified at 40C'),
    ('Fortis Gurgaon','WD-FRT-201','forced_air_warmer','OT Complex A','2026-07-02',
     2.4,true,'due','worn',true,'not_applicable','pass',true,false,'conditional_pass','Temp error 2.4C over 2C tolerance, filter due, calibration lapsed'),
    ('Fortis Gurgaon','WD-FRT-202','warming_cabinet_blanket','PACU','2026-07-02',
     0.4,false,'not_applicable','good',false,'fail','fail',true,true,'fail','Cabinet ran high to 48C with no over-temp cutoff — burn risk flagged'),
    ('Manipal Bengaluru Old Airport Road','WD-MNP-301','forced_air_warmer','Operating Theatre 3','2026-07-01',
     0.5,true,'blocked','good',true,'not_applicable','pass',true,true,'conditional_pass','Airflow filter blocked — warm-up slow, HEPA change due'),
    ('Manipal Bengaluru Old Airport Road','WD-MNP-302','conductive_warming_mattress','Paediatric OT','2026-07-01',
     0.2,true,'not_applicable','good',true,'ok','pass',true,true,'pass','Conductive mattress within 0.2C — paediatric protocol verified'),
    ('AIIMS Delhi Ansari Nagar','WD-AIM-401','forced_air_warmer','Cardiac OT','2026-06-30',
     3.1,false,'due','torn',false,'not_applicable','not_tested',true,false,'removed_from_service','Torn hose, 3.1C error, no cutoff — unit pulled from service'),
    ('AIIMS Delhi Ansari Nagar','WD-AIM-402','warming_cabinet_fluid','Emergency OT','2026-06-30',
     0.7,true,'not_applicable','good',true,'drift','pass',true,true,'conditional_pass','Fluid cabinet setpoint drifting ~2C — thermostat watch'),
    ('CMC Vellore','WD-CMC-501','underbody_warming','Operating Theatre 5','2026-06-29',
     0.4,true,'not_applicable','good',true,'not_applicable','pass',true,true,'pass','Underbody warming pad QC clean'),
    ('CMC Vellore','WD-CMC-502','forced_air_warmer','Neuro OT','2026-06-29',
     1.1,true,'clean','replace_due',true,'not_applicable','pass',false,true,'conditional_pass','Blanket hose replace-due, hygiene wipe-down missed on log'),
    ('KIMS Hyderabad','WD-KIM-601','warming_cabinet_blanket','OT Complex B','2026-06-28',
     0.5,true,'not_applicable','good',true,'ok','pass',true,true,'pass','Blanket warming cabinet nominal at 43C'),
    ('KIMS Hyderabad','WD-KIM-602','forced_air_warmer','Obstetric OT','2026-06-28',
     0.8,true,'blocked','worn',true,'not_applicable','fail',true,true,'conditional_pass','Filter blocked and alarm test failed — audible alarm silent'),
    ('Medanta Gurugram','WD-MDT-701','warming_cabinet_fluid','Hybrid OT','2026-06-27',
     null,true,'not_applicable','good',true,'not_applicable','not_tested',false,false,'removed_from_service','QC aborted on power fault, hygiene and calibration overdue, revisit booked'),
    ('Rainbow Hyderabad Banjara Hills','WD-RBW-801','conductive_warming_mattress','Paediatric ICU OT','2026-06-27',
     0.3,true,'not_applicable','good',true,'ok','pass',true,true,'pass','Paediatric conductive mattress verified within spec')
  ) as q(hosp, dcode, dtype, dept, cdate, taerr, otc, aff, hbc, bra, csp, alm, chy, calc, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.warming_device_qc_capa_actions_r3366 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WD-FRT-202','over_temp_cutoff_failure','thermostat_fault','adjust_thermostat','escalated','patient_safety_alert','2026-07-06',null,35000.00,'Cabinet overheated to 48C with no cutoff — escalated to biomed'),
    ('WD-AIM-401','hose_blanket_damage','hose_wear','replace_hose_blanket','open','nabh_finding','2026-07-05',null,14000.00,'Torn hose and blanket — replacement kit on order from OEM'),
    ('WD-FRT-201','calibration_overdue','calibration_backlog','schedule_calibration','in_progress','iso_13485_deviation','2026-07-07',null,8000.00,'Temp sensor calibration lapsed — booked with OEM engineer'),
    ('WD-MNP-301','airflow_filter_blocked','filter_clogged','replace_air_filter','closed','internal_only','2026-07-03','2026-07-02',3500.00,'HEPA filter replaced, airflow restored and re-tested'),
    ('WD-KIM-602','alarm_failure','alarm_board_fault','repair_alarm_circuit','verification_pending','internal_only','2026-07-04',null,11000.00,'Alarm board reseated — verify audible alarm on next check'),
    ('WD-MDT-701','hygiene_contamination','cleaning_protocol_lapse','deep_clean_and_disinfect','overdue','nabh_finding','2026-06-30',null,5000.00,'Hygiene deep-clean past target — OT turnaround delayed'),
    ('WD-AIM-402','cabinet_setpoint_drift','thermostat_fault','adjust_thermostat','open','internal_only','2026-07-08',null,9000.00,'Fluid cabinet setpoint drift ~2C — thermostat adjustment scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.warming_device_qc_r3366 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3366_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warming_device_qc_r3366)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.warming_device_qc_r3366 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3366_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3366_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3366_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  cutoff_fail bigint,
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
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.over_temp_cutoff_ok = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.warming_device_qc_r3366 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3366_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3366_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3366_device_type_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_temp_error_c numeric, cutoff_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.temperature_accuracy_error_c), 2),
    count(*) filter (where l.over_temp_cutoff_ok = false)::bigint
  from public.warming_device_qc_r3366 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3366_device_type_department_matrix() from public, anon;
grant execute on function public.founder_r3366_device_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3366_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, cutoff_fail bigint, alarm_fail bigint)
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
    count(*) filter (where l.over_temp_cutoff_ok = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint
  from public.warming_device_qc_r3366 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3366_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3366_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3366_capa_status_board()
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
  from public.warming_device_qc_capa_actions_r3366 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3366_capa_status_board() from public, anon;
grant execute on function public.founder_r3366_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3366_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.warming_device_qc_capa_actions_r3366)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.warming_device_qc_capa_actions_r3366 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3366_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3366_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3366_regulatory_impact_digest()
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
  from public.warming_device_qc_capa_actions_r3366 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3366_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3366_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3366_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  over_temp_cutoff_ok boolean,
  airflow_filter_condition text,
  hose_blanket_condition text,
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
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.over_temp_cutoff_ok, l.airflow_filter_condition, l.hose_blanket_condition,
    l.alarm_test, l.notes
  from public.warming_device_qc_r3366 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.over_temp_cutoff_ok = false
     or l.burn_risk_assessment_ok = false
     or l.airflow_filter_condition = 'blocked'
     or l.hose_blanket_condition in ('torn','replace_due')
     or l.cabinet_setpoint_ok in ('drift','fail')
     or l.alarm_test = 'fail'
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3366_high_risk_queue() from public, anon;
grant execute on function public.founder_r3366_high_risk_queue() to authenticated;
