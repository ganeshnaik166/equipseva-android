-- Round 3479: Customer Hospital Hot-Air-Oven / Dry-Heat Sterilizer QC Audit
-- Dry-heat sterilizer QA — parameter (setpoint temp, uniformity delta, hold time, recovery time, door-seal temp, probe accuracy) × device model × department × load type × reference vs measured × deviation % × tolerance × BI test × calibration currency × QC verdict × CAPA

-- =============================================================================
-- TABLE 1: hot_air_oven_qc_r3479 — per-parameter dry-heat sterilizer QC checks
-- =============================================================================
create table if not exists public.hot_air_oven_qc_r3479 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  department text not null check (department in (
    'cssd','laboratory','pharmacy','ot_sterile_store','microbiology'
  )),
  parameter text not null check (parameter in (
    'setpoint_temp_c','uniformity_delta_c','hold_time_min','recovery_time_min','door_seal_temp_c','probe_accuracy_c'
  )),
  reference_value numeric(8,2) not null,
  measured_value numeric(8,2) not null,
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  within_tolerance boolean not null,
  bi_test_ok boolean not null,
  load_type text not null check (load_type in (
    'glassware','metal_instruments','powders','oils_ointments','empty_chamber'
  )),
  check_date date not null,
  calibration_date date,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hot_air_oven_qc_r3479 enable row level security;

create index if not exists idx_hot_air_oven_qc_r3479_org on public.hot_air_oven_qc_r3479(organization_id);
create index if not exists idx_hot_air_oven_qc_r3479_date on public.hot_air_oven_qc_r3479(check_date);
create index if not exists idx_hot_air_oven_qc_r3479_verdict on public.hot_air_oven_qc_r3479(qc_verdict);

-- =============================================================================
-- TABLE 2: hot_air_oven_qc_capa_actions_r3479 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hot_air_oven_qc_capa_actions_r3479 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.hot_air_oven_qc_r3479(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'setpoint_deviation','uniformity_out_of_tolerance','hold_time_short','recovery_time_excessive',
    'door_seal_leak','probe_accuracy_drift','bi_test_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'heater_element_degraded','fan_circulation_fault','door_gasket_worn','temperature_probe_drift',
    'controller_pid_miscalibration','door_seal_misaligned','timer_malfunction','operator_loading_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_heater_element','repair_circulation_fan','replace_door_gasket','recalibrate_temperature_probe',
    'retune_pid_controller','realign_door_seal','replace_timer_module','retrain_cssd_staff',
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

alter table public.hot_air_oven_qc_capa_actions_r3479 enable row level security;

create index if not exists idx_hot_air_oven_capa_r3479_log on public.hot_air_oven_qc_capa_actions_r3479(qc_log_id);
create index if not exists idx_hot_air_oven_capa_r3479_status on public.hot_air_oven_qc_capa_actions_r3479(capa_status);

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
  insert into public.hot_air_oven_qc_r3479 (
    organization_id, hospital_name, device_code, device_model, department, parameter,
    reference_value, measured_value, deviation_pct, tolerance_pct, within_tolerance,
    bi_test_ok, load_type, check_date, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.dept, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.tolp::numeric, q.wtol,
    q.bi, q.ldt, q.cdate::date, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','HAO-APL-01','Memmert UF160','cssd','setpoint_temp_c',
     160.00,160.80,0.50,2.00,true,true,'glassware','2026-07-05','2026-01-10',true,'pass','160C setpoint within +/-2%; BI spore strip negative'),
    ('Apollo Chennai','HAO-APL-02','Bionics DHS-200','laboratory','uniformity_delta_c',
     5.00,3.20,null,5.00,true,true,'glassware','2026-07-05','2026-01-10',true,'pass','Chamber uniformity 3.2C under 5C spec across 9 probes'),
    ('Fortis Gurgaon','HAO-FRT-11','Yamato DKN612','cssd','hold_time_min',
     120.00,118.00,-1.67,5.00,true,true,'metal_instruments','2026-07-04','2026-02-14',true,'conditional_pass','Hold time 118 vs 120 min at 160C — minor short, revalidate'),
    ('Fortis Gurgaon','HAO-FRT-12','Memmert UF260','pharmacy','probe_accuracy_c',
     0.00,2.40,null,1.00,false,true,'powders','2026-07-04','2025-08-20',false,'fail','Reference probe reads 2.4C high; calibration overdue since Feb'),
    ('Manipal Bengaluru','HAO-MNP-21','Bionics DHS-160','microbiology','setpoint_temp_c',
     170.00,168.50,-0.88,2.00,true,true,'glassware','2026-07-03','2026-03-01',true,'pass','170C setpoint within +/-2% for glassware cycle'),
    ('Manipal Bengaluru','HAO-MNP-22','Yamato DKN812','cssd','recovery_time_min',
     15.00,26.00,73.33,20.00,false,true,'metal_instruments','2026-07-03','2026-03-01',true,'fail','Door-open recovery 26 min vs 15 target — heater bank weak'),
    ('AIIMS Delhi','HAO-AIM-31','Memmert UF160','ot_sterile_store','door_seal_temp_c',
     50.00,58.00,16.00,10.00,false,true,'glassware','2026-07-02','2026-01-25',true,'fail','Door seal surface 58C vs 50C limit — gasket leak suspected'),
    ('AIIMS Delhi','HAO-AIM-32','Bionics DHS-200','laboratory','uniformity_delta_c',
     5.00,6.80,null,5.00,false,false,'glassware','2026-07-02','2025-11-05',false,'fail','Uniformity 6.8C over spec and BI growth positive — quarantined'),
    ('CMC Vellore','HAO-CMC-41','Yamato DKN612','cssd','hold_time_min',
     60.00,61.00,1.67,5.00,true,true,'metal_instruments','2026-07-01','2026-04-10',true,'pass','170C x 60 min hold verified; BI negative'),
    ('CMC Vellore','HAO-CMC-42','Memmert UF260','pharmacy','setpoint_temp_c',
     180.00,181.20,0.67,2.00,true,true,'oils_ointments','2026-07-01','2026-04-10',true,'pass','180C setpoint for oils/ointments within tolerance'),
    ('KIMS Hyderabad','HAO-KIM-51','Bionics DHS-160','microbiology','probe_accuracy_c',
     0.00,0.60,null,1.00,true,true,'glassware','2026-06-30','2026-02-18',true,'pass','Probe error 0.6C within 1C acceptance limit'),
    ('KIMS Hyderabad','HAO-KIM-52','Yamato DKN812','cssd','uniformity_delta_c',
     5.00,5.60,null,5.00,true,true,'metal_instruments','2026-06-30','2026-02-18',true,'conditional_pass','Uniformity 5.6C marginally over — fan circulation check due'),
    ('Yashoda Hyderabad','HAO-YSH-61','Memmert UF160','laboratory','hold_time_min',
     120.00,120.00,0.00,5.00,true,true,'glassware','2026-06-29','2026-05-02',true,'pass','160C x 120 min cycle validated end-to-end'),
    ('Yashoda Hyderabad','HAO-YSH-62','Bionics DHS-200','cssd','recovery_time_min',
     15.00,17.00,13.33,20.00,true,true,'metal_instruments','2026-06-29','2026-05-02',true,'conditional_pass','Recovery 17 min within 20% limit but trending upward'),
    ('Kokilaben Mumbai','HAO-KKB-71','Yamato DKN612','ot_sterile_store','door_seal_temp_c',
     50.00,47.00,-6.00,10.00,true,true,'glassware','2026-06-28','2026-03-15',true,'pass','Door seal temp 47C within limit; gasket intact'),
    ('Kokilaben Mumbai','HAO-KKB-72','Memmert UF260','pharmacy','setpoint_temp_c',
     160.00,155.00,-3.13,2.00,false,false,'powders','2026-06-28','2025-09-12',false,'fail','Setpoint 5C low, BI positive, calibration expired — removed from service')
  ) as q(hosp, dcode, dmodel, dept, param, refv, measv, devp, tolp, wtol, bi, ldt, cdate, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.hot_air_oven_qc_capa_actions_r3479 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HAO-FRT-12','probe_accuracy_drift','temperature_probe_drift','recalibrate_temperature_probe','in_progress','iso_13485_deviation','2026-07-09',null,9000.00,'Reference RTD probe recalibrated; verification cycle pending'),
    ('HAO-MNP-22','recovery_time_excessive','heater_element_degraded','replace_heater_element','open','nabh_finding','2026-07-10',null,42000.00,'Heater bank degraded — replacement element ordered from OEM'),
    ('HAO-AIM-31','door_seal_leak','door_gasket_worn','replace_door_gasket','escalated','patient_safety_alert','2026-07-08',null,6500.00,'Door gasket leak raising seal temp — escalated to biomedical'),
    ('HAO-AIM-32','bi_test_failure','fan_circulation_fault','repair_circulation_fan','open','cdsco_notifiable','2026-07-08',null,28000.00,'BI growth positive with poor uniformity — circulation fan under repair'),
    ('HAO-KKB-72','setpoint_deviation','controller_pid_miscalibration','retune_pid_controller','verification_pending','iso_13485_deviation','2026-07-06',null,12000.00,'PID retuned after 5C low setpoint; revalidation cycle scheduled'),
    ('HAO-FRT-11','hold_time_short','timer_malfunction','replace_timer_module','closed','internal_only','2026-07-07','2026-07-05',7500.00,'Timer module replaced; 120 min hold reverified and closed'),
    ('HAO-KIM-52','uniformity_out_of_tolerance','fan_circulation_fault','repair_circulation_fan','overdue','internal_only','2026-06-30',null,18000.00,'Uniformity marginally over spec — fan service past target date'),
    ('HAO-YSH-62','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-12',null,0.00,'Recovery time trending — preventive OEM service scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.hot_air_oven_qc_r3479 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3479_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hot_air_oven_qc_r3479)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hot_air_oven_qc_r3479 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3479_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3479_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3479_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  bi_fail bigint,
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
    count(*) filter (where l.bi_test_ok = false)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.hot_air_oven_qc_r3479 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3479_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3479_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3479_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, avg_measured numeric, bi_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    round(avg(l.measured_value), 2),
    count(*) filter (where l.bi_test_ok = false)::bigint
  from public.hot_air_oven_qc_r3479 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3479_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3479_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3479_monthly_accuracy_trend()
returns table(month date, checks bigint, passed bigint, failed bigint, avg_deviation_pct numeric, bi_fail bigint, calibration_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.check_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.bi_test_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.hot_air_oven_qc_r3479 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3479_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3479_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3479_capa_status_board()
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
  from public.hot_air_oven_qc_capa_actions_r3479 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3479_capa_status_board() from public, anon;
grant execute on function public.founder_r3479_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3479_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hot_air_oven_qc_capa_actions_r3479)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hot_air_oven_qc_capa_actions_r3479 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3479_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3479_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory-impact digest
create or replace function public.founder_r3479_accuracy_impact_digest()
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
  from public.hot_air_oven_qc_capa_actions_r3479 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3479_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3479_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / BI-fail checks)
create or replace function public.founder_r3479_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  check_date date,
  qc_verdict text,
  measured_value numeric,
  deviation_pct numeric,
  bi_test_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.check_date,
    l.qc_verdict, l.measured_value, l.deviation_pct, l.bi_test_ok, l.notes
  from public.hot_air_oven_qc_r3479 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.bi_test_ok = false
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3479_high_risk_queue() from public, anon;
grant execute on function public.founder_r3479_high_risk_queue() to authenticated;
