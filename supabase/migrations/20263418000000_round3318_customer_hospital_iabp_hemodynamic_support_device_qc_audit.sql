-- Round 3318: Customer Hospital IABP & Hemodynamic-Support Device QC Audit
-- Cardiac support-device readiness — device type × unit × helium supply × timing trigger × augmentation × purge cycle × battery backup × alarm test × transducer cal × self-test × readiness verdict × CAPA

-- =============================================================================
-- TABLE 1: hemo_support_device_r3318 — per-device readiness QC checks
-- =============================================================================
create table if not exists public.hemo_support_device_r3318 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'iabp_console','pvad_console','cardiac_output_monitor','picco_system','swan_ganz_monitor'
  )),
  unit text not null check (unit in (
    'cicu','cath_lab','cardiac_ot','cardiac_stepdown'
  )),
  check_date date not null,
  helium_supply_ok boolean,
  timing_trigger_accuracy_ok boolean,
  augmentation_pressure_ok text not null check (augmentation_pressure_ok in (
    'ok','suboptimal','fail','not_applicable'
  )),
  purge_cycle_ok boolean,
  battery_backup_minutes int not null,
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  calibration_transducer_ok boolean not null,
  backup_console_available boolean not null,
  self_test_pass boolean not null,
  readiness_verdict text not null check (readiness_verdict in (
    'mission_ready','conditional','not_ready','out_of_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hemo_support_device_r3318 enable row level security;

create index if not exists idx_hemo_support_device_r3318_org on public.hemo_support_device_r3318(organization_id);
create index if not exists idx_hemo_support_device_r3318_date on public.hemo_support_device_r3318(check_date);
create index if not exists idx_hemo_support_device_r3318_verdict on public.hemo_support_device_r3318(readiness_verdict);

-- =============================================================================
-- TABLE 2: hemo_support_device_capa_actions_r3318 — CAPA findings for not-ready devices
-- =============================================================================
create table if not exists public.hemo_support_device_capa_actions_r3318 (
  id uuid primary key default gen_random_uuid(),
  check_log_id uuid not null references public.hemo_support_device_r3318(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'helium_supply_low','timing_trigger_error','augmentation_pressure_deficit','purge_cycle_failure',
    'battery_backup_deficit','alarm_failure','transducer_calibration_drift','self_test_failure',
    'backup_console_unavailable','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'helium_cylinder_empty','trigger_cable_fault','balloon_membrane_leak','purge_valve_stuck',
    'battery_end_of_life','alarm_module_fault','transducer_drift','console_firmware_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_helium_cylinder','replace_trigger_cable','replace_balloon_catheter','service_purge_system',
    'replace_battery_pack','repair_alarm_module','recalibrate_transducer','update_console_firmware',
    'retrain_cardiac_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.hemo_support_device_capa_actions_r3318 enable row level security;

create index if not exists idx_hemo_support_capa_r3318_log on public.hemo_support_device_capa_actions_r3318(check_log_id);
create index if not exists idx_hemo_support_capa_r3318_status on public.hemo_support_device_capa_actions_r3318(capa_status);

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

  -- 14 device readiness QC rows
  insert into public.hemo_support_device_r3318 (
    organization_id, hospital_name, device_code, device_type, unit, check_date,
    helium_supply_ok, timing_trigger_accuracy_ok, augmentation_pressure_ok, purge_cycle_ok,
    battery_backup_minutes, alarm_test, calibration_transducer_ok, backup_console_available,
    self_test_pass, readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.unit, q.cd::date,
    q.helium, q.timing, q.aug, q.purge,
    q.batt, q.alarm, q.caltr, q.backup,
    q.selftest, q.verdict, q.nt
  from (values
    ('Apollo Hospitals Chennai Greams Road','HSD-APL-IABP-01','iabp_console','cicu','2026-07-05',
     true,true,'ok',true,120,'pass',true,true,true,'mission_ready','Weekly readiness — helium full, 1:1 augmentation nominal'),
    ('Apollo Hospitals Chennai Greams Road','HSD-APL-COM-02','cardiac_output_monitor','cicu','2026-07-05',
     null,null,'not_applicable',null,90,'pass',true,true,true,'mission_ready','Continuous CO monitor — thermodilution cal verified'),
    ('Fortis Memorial Gurgaon','HSD-FRT-IABP-03','iabp_console','cath_lab','2026-07-04',
     false,true,'suboptimal',true,45,'pass',true,false,true,'conditional','Helium cylinder <20% and no backup console in room — flagged'),
    ('Fortis Memorial Gurgaon','HSD-FRT-PVAD-04','pvad_console','cardiac_ot','2026-07-04',
     null,true,'not_applicable',true,150,'pass',true,true,true,'mission_ready','Impella controller — purge cassette fresh, motor current normal'),
    ('Manipal Hospital Old Airport Road Bengaluru','HSD-MNP-IABP-05','iabp_console','cicu','2026-07-03',
     true,false,'fail',true,100,'pass',true,true,false,'not_ready','ECG trigger timing off by 40ms, augmentation fails — self-test failed'),
    ('Manipal Hospital Old Airport Road Bengaluru','HSD-MNP-PIC-06','picco_system','cardiac_stepdown','2026-07-03',
     null,null,'not_applicable',null,80,'pass',true,true,true,'mission_ready','PiCCO transpulmonary cal within spec'),
    ('AIIMS Delhi Ansari Nagar','HSD-AIM-IABP-07','iabp_console','cardiac_ot','2026-07-02',
     true,true,'fail',false,30,'fail',false,true,false,'not_ready','Balloon membrane leak suspected — purge cycle fault, alarm test failed'),
    ('AIIMS Delhi Ansari Nagar','HSD-AIM-SWG-08','swan_ganz_monitor','cicu','2026-07-02',
     null,null,'not_applicable',null,110,'pass',false,true,true,'conditional','Swan-Ganz transducer zero drift 3mmHg — recal scheduled'),
    ('CMC Vellore','HSD-CMC-IABP-09','iabp_console','cicu','2026-07-01',
     true,true,'ok',true,130,'pass',true,true,true,'mission_ready','Full readiness — post-PM verification clean'),
    ('CMC Vellore','HSD-CMC-PVAD-10','pvad_console','cath_lab','2026-07-01',
     null,true,'not_applicable',true,18,'pass',true,false,true,'conditional','Impella console battery holds only 18min — battery pack aging'),
    ('KIMS Hyderabad Kondapur','HSD-KIM-IABP-11','iabp_console','cardiac_stepdown','2026-06-30',
     false,false,'fail',false,0,'fail',false,false,false,'out_of_service','Console powered down — self-test fail, purge failure, pulled from floor'),
    ('KIMS Hyderabad Kondapur','HSD-KIM-COM-12','cardiac_output_monitor','cicu','2026-06-30',
     null,null,'not_applicable',null,95,'pass',true,true,true,'mission_ready','FloTrac CO monitor — sensor within cal window'),
    ('Narayana Health City Bengaluru','HSD-NHC-IABP-13','iabp_console','cath_lab','2026-06-29',
     true,true,'ok',true,105,'fail',true,true,true,'conditional','Augmentation good but audible alarm test failed — speaker service'),
    ('Medanta The Medicity Gurgaon','HSD-MED-PIC-14','picco_system','cardiac_ot','2026-06-29',
     null,null,'not_applicable',null,140,'pass',true,true,true,'mission_ready','PiCCO OT unit — arterial thermistor verified')
  ) as q(hosp, code, dtype, unit, cd, helium, timing, aug, purge, batt, alarm, caltr, backup, selftest, verdict, nt);

  -- CAPA seed — attach to specific not-ready / at-risk devices via device_code
  insert into public.hemo_support_device_capa_actions_r3318 (
    check_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HSD-FRT-IABP-03','helium_supply_low','helium_cylinder_empty','replace_helium_cylinder','in_progress','nabh_finding','2026-07-08',null,8000.00,'Cylinder swap + backup console requested for cath lab'),
    ('HSD-MNP-IABP-05','timing_trigger_error','trigger_cable_fault','replace_trigger_cable','open','patient_safety_alert','2026-07-07',null,15000.00,'Trigger cable replacement — device held from patient use'),
    ('HSD-AIM-IABP-07','augmentation_pressure_deficit','balloon_membrane_leak','replace_balloon_catheter','escalated','cdsco_notifiable','2026-07-06',null,95000.00,'Suspected balloon leak — OEM Maquet escalation, catheter replacement'),
    ('HSD-AIM-SWG-08','transducer_calibration_drift','transducer_drift','recalibrate_transducer','closed','iso_13485_deviation','2026-07-05','2026-07-03',6000.00,'Transducer re-zeroed and verified within 1mmHg'),
    ('HSD-CMC-PVAD-10','battery_backup_deficit','battery_end_of_life','replace_battery_pack','open','internal_only','2026-07-09',null,42000.00,'Impella battery pack aged — replacement on order from Abiomed'),
    ('HSD-KIM-IABP-11','self_test_failure','console_firmware_error','schedule_oem_service','overdue','patient_safety_alert','2026-06-28',null,120000.00,'Console out of service — OEM service past due, loaner requested'),
    ('HSD-NHC-IABP-13','alarm_failure','alarm_module_fault','repair_alarm_module','verification_pending','internal_only','2026-07-02',null,9000.00,'Alarm speaker module repaired — verify on next readiness round')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.hemo_support_device_r3318 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3318_readiness_verdict_rollup()
returns table(readiness_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hemo_support_device_r3318)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hemo_support_device_r3318 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3318_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3318_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3318_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  mission_ready bigint,
  conditional bigint,
  not_ready bigint,
  out_of_service bigint,
  alarm_fail bigint,
  transducer_fail bigint,
  self_test_fail bigint,
  ready_pct numeric
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
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'conditional')::bigint,
    count(*) filter (where l.readiness_verdict = 'not_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint,
    count(*) filter (where l.calibration_transducer_ok = false)::bigint,
    count(*) filter (where l.self_test_pass = false)::bigint,
    round(100.0 * count(*) filter (where l.readiness_verdict = 'mission_ready')::numeric / nullif(count(*),0), 1)
  from public.hemo_support_device_r3318 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3318_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3318_hospital_scorecard() to authenticated;

-- 3) Device type × unit matrix
create or replace function public.founder_r3318_device_unit_matrix()
returns table(device_type text, unit text, checks bigint, mission_ready bigint, not_ready_or_oos bigint, avg_battery_minutes numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.unit, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    count(*) filter (where l.readiness_verdict in ('not_ready','out_of_service'))::bigint,
    round(avg(l.battery_backup_minutes), 0)
  from public.hemo_support_device_r3318 l
  group by l.device_type, l.unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3318_device_unit_matrix() from public, anon;
grant execute on function public.founder_r3318_device_unit_matrix() to authenticated;

-- 4) Daily readiness-check trend
create or replace function public.founder_r3318_daily_check_trend()
returns table(check_date date, checks bigint, mission_ready bigint, not_ready bigint, out_of_service bigint, alarm_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'not_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint
  from public.hemo_support_device_r3318 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3318_daily_check_trend() from public, anon;
grant execute on function public.founder_r3318_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3318_capa_status_board()
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
  from public.hemo_support_device_capa_actions_r3318 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3318_capa_status_board() from public, anon;
grant execute on function public.founder_r3318_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3318_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hemo_support_device_capa_actions_r3318)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hemo_support_device_capa_actions_r3318 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3318_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3318_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3318_regulatory_impact_digest()
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
  from public.hemo_support_device_capa_actions_r3318 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3318_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3318_regulatory_impact_digest() to authenticated;

-- 8) High-risk readiness queue (individual devices needing action)
create or replace function public.founder_r3318_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  unit text,
  check_date date,
  readiness_verdict text,
  augmentation_pressure_ok text,
  alarm_test text,
  battery_backup_minutes int,
  self_test_pass boolean,
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
    l.readiness_verdict, l.augmentation_pressure_ok, l.alarm_test, l.battery_backup_minutes,
    l.self_test_pass, l.notes
  from public.hemo_support_device_r3318 l
  where l.readiness_verdict in ('conditional','not_ready','out_of_service')
     or l.augmentation_pressure_ok in ('suboptimal','fail')
     or l.alarm_test = 'fail'
     or l.self_test_pass = false
     or l.calibration_transducer_ok = false
     or l.timing_trigger_accuracy_ok = false
     or l.purge_cycle_ok = false
     or l.helium_supply_ok = false
     or l.battery_backup_minutes < 30
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3318_high_risk_queue() from public, anon;
grant execute on function public.founder_r3318_high_risk_queue() to authenticated;
