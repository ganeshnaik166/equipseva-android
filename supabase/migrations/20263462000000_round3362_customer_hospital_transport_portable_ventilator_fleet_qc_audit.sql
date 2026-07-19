-- Round 3362: Customer Hospital Transport & Portable Ventilator Fleet QC Audit
-- Transport/portable ventilator QA — device type × unit × tidal-volume accuracy × PEEP/FiO2 × battery runtime
--   × O2 cylinder pressure × alarm test × circuit leak × self-test × dispatch readiness × CAPA

-- =============================================================================
-- TABLE 1: transport_vent_qc_r3362 — individual device QC checks
-- =============================================================================
create table if not exists public.transport_vent_qc_r3362 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'transport_ventilator','portable_icu_ventilator','ambulance_ventilator','bvm_resuscitator','cpap_transport'
  )),
  unit text not null check (unit in (
    'emergency','ambulance','icu_transport','ward'
  )),
  check_date date not null,
  tidal_volume_accuracy_error_pct numeric(5,2),
  peep_accuracy_ok boolean,
  fio2_delivery_accuracy_ok boolean,
  battery_runtime_hours numeric(5,2),
  oxygen_cylinder_pressure_ok boolean,
  alarm_function_test text not null check (alarm_function_test in (
    'pass','fail','not_tested'
  )),
  circuit_leak_test text not null check (circuit_leak_test in (
    'pass','minor_leak','fail'
  )),
  self_test_pass boolean,
  ready_for_dispatch boolean not null,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.transport_vent_qc_r3362 enable row level security;

create index if not exists idx_transport_vent_qc_r3362_org on public.transport_vent_qc_r3362(organization_id);
create index if not exists idx_transport_vent_qc_r3362_date on public.transport_vent_qc_r3362(check_date);
create index if not exists idx_transport_vent_qc_r3362_verdict on public.transport_vent_qc_r3362(qc_verdict);

-- =============================================================================
-- TABLE 2: transport_vent_qc_capa_actions_r3362 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.transport_vent_qc_capa_actions_r3362 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.transport_vent_qc_r3362(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'tidal_volume_deviation','peep_inaccuracy','fio2_delivery_error','battery_runtime_low',
    'oxygen_supply_fault','alarm_function_failure','circuit_leak','self_test_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'flow_sensor_drift','oxygen_blender_fault','battery_degradation','cylinder_regulator_leak',
    'expiratory_valve_worn','alarm_module_fault','circuit_connector_damaged','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_flow_sensor','recalibrate_oxygen_blender','replace_battery_pack','replace_regulator',
    'replace_expiratory_valve','replace_alarm_module','replace_breathing_circuit','update_software_config',
    'retrain_transport_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.transport_vent_qc_capa_actions_r3362 enable row level security;

create index if not exists idx_transport_vent_qc_capa_r3362_log on public.transport_vent_qc_capa_actions_r3362(qc_log_id);
create index if not exists idx_transport_vent_qc_capa_r3362_status on public.transport_vent_qc_capa_actions_r3362(capa_status);

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

  -- 14 device QC rows
  insert into public.transport_vent_qc_r3362 (
    organization_id, hospital_name, device_code, device_type, unit, check_date,
    tidal_volume_accuracy_error_pct, peep_accuracy_ok, fio2_delivery_accuracy_ok,
    battery_runtime_hours, oxygen_cylinder_pressure_ok, alarm_function_test,
    circuit_leak_test, self_test_pass, ready_for_dispatch, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.unit, q.cdt::date,
    q.tve, q.peep, q.fio2,
    q.brh, q.ocp, q.aft,
    q.clt, q.stp, q.rfd, q.calc,
    q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','TV-APL-101','transport_ventilator','icu_transport','2026-07-03',
     2.10,true,true,6.50,true,'pass','pass',true,true,true,'pass','Quarterly QC — all parameters nominal'),
    ('Apollo Chennai Greams Road','AV-APL-102','ambulance_ventilator','ambulance','2026-07-03',
     8.40,true,false,4.20,true,'pass','minor_leak',true,false,true,'conditional_pass','Tidal-volume error 8.4% over 5% limit and FiO2 off — held for recheck'),
    ('Fortis Gurgaon','PV-FRT-201','portable_icu_ventilator','icu_transport','2026-07-02',
     1.20,true,true,7.80,true,'pass','pass',true,true,true,'pass','Inter-facility transport ventilator verified'),
    ('Fortis Gurgaon','AV-FRT-202','ambulance_ventilator','ambulance','2026-07-02',
     3.50,false,true,2.10,false,'fail','fail',false,false,false,'removed_from_service','Alarm and circuit-leak failed, battery 2.1h, cylinder low — pulled from ambulance'),
    ('Manipal Bengaluru Old Airport Road','PV-MNP-301','portable_icu_ventilator','icu_transport','2026-07-01',
     0.90,true,true,8.00,true,'pass','pass',true,true,true,'pass','Annual QC clean pass'),
    ('Manipal Bengaluru Old Airport Road','BVM-MNP-302','bvm_resuscitator','emergency','2026-07-01',
     null,null,null,null,null,'not_tested','minor_leak',null,true,null,'conditional_pass','Manual BVM — patient-valve minor leak found and reseated'),
    ('AIIMS New Delhi Ansari Nagar','TV-AIM-401','transport_ventilator','emergency','2026-06-30',
     1.60,true,true,6.90,true,'pass','pass',true,true,true,'pass','Emergency-bay transport ventilator verified'),
    ('AIIMS New Delhi Ansari Nagar','CV-AIM-402','cpap_transport','icu_transport','2026-06-30',
     null,true,true,5.50,true,'pass','pass',true,true,true,'pass','Transport CPAP pressure delivery verified'),
    ('CMC Vellore','PV-CMC-501','portable_icu_ventilator','ward','2026-06-29',
     6.20,true,false,3.40,true,'pass','pass',true,false,true,'conditional_pass','FiO2 delivery off spec and battery 3.4h below 4h floor'),
    ('CMC Vellore','AV-CMC-502','ambulance_ventilator','ambulance','2026-06-29',
     12.50,false,true,4.80,true,'pass','pass',false,false,false,'fail','Tidal volume 12.5% out and self-test failed — calibration overdue'),
    ('KIMS Hyderabad Secunderabad','TV-KIM-601','transport_ventilator','icu_transport','2026-06-28',
     2.00,true,true,7.10,true,'pass','pass',true,true,true,'pass','Post-AMC verification pass'),
    ('KIMS Hyderabad Secunderabad','BVM-KIM-602','bvm_resuscitator','ambulance','2026-06-28',
     null,null,null,null,null,'not_tested','fail',null,false,null,'fail','BVM duckbill valve failed leak test — replaced'),
    ('Yashoda Hyderabad Somajiguda','PV-YSH-701','portable_icu_ventilator','ward','2026-06-27',
     1.10,true,true,8.30,true,'pass','pass',true,true,true,'pass','Step-down transport ventilator verified'),
    ('Medanta Gurgaon','AV-MED-801','ambulance_ventilator','ambulance','2026-06-27',
     4.90,true,true,5.00,false,'pass','minor_leak',true,false,true,'conditional_pass','O2 cylinder pressure low and minor circuit leak — cylinder swapped')
  ) as q(hosp, dcode, dtype, unit, cdt, tve, peep, fio2, brh, ocp, aft, clt, stp, rfd, calc, qv, nt);

  -- CAPA seed — attach to specific device checks via device_code
  insert into public.transport_vent_qc_capa_actions_r3362 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('AV-FRT-202','alarm_function_failure','alarm_module_fault','replace_alarm_module','escalated','patient_safety_alert','2026-07-07',null,35000.00,'Alarm silent on disconnect — escalated to OEM engineer'),
    ('AV-APL-102','tidal_volume_deviation','flow_sensor_drift','replace_flow_sensor','in_progress','nabh_finding','2026-07-08',null,22000.00,'Flow sensor drift — replacement sensor on order'),
    ('PV-CMC-501','fio2_delivery_error','oxygen_blender_fault','recalibrate_oxygen_blender','open','internal_only','2026-07-05',null,15000.00,'Blender recalibration scheduled with biomed'),
    ('AV-CMC-502','self_test_failure','software_config_error','update_software_config','verification_pending','iso_13485_deviation','2026-07-04',null,0.00,'Firmware reflashed — verify on next dispatch check'),
    ('BVM-KIM-602','circuit_leak','expiratory_valve_worn','replace_expiratory_valve','closed','internal_only','2026-07-01','2026-06-29',3500.00,'Duckbill and patient valve replaced, retested pass'),
    ('AV-MED-801','oxygen_supply_fault','cylinder_regulator_leak','replace_regulator','overdue','nabh_finding','2026-06-26',null,18000.00,'Regulator leak past target date — AMC vendor delayed'),
    ('BVM-MNP-302','circuit_leak','expiratory_valve_worn','replace_breathing_circuit','closed','internal_only','2026-07-03','2026-07-01',2500.00,'Patient-valve leak resolved after circuit swap')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.transport_vent_qc_r3362 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3362_qc_verdict_rollup()
returns table(qc_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transport_vent_qc_r3362)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.transport_vent_qc_r3362 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3362_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3362_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3362_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  alarm_fail bigint,
  circuit_leak_fail bigint,
  not_ready bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.alarm_function_test = 'fail')::bigint,
    count(*) filter (where l.circuit_leak_test in ('minor_leak','fail'))::bigint,
    count(*) filter (where l.ready_for_dispatch = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.transport_vent_qc_r3362 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3362_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3362_hospital_scorecard() to authenticated;

-- 3) Device type × unit matrix
create or replace function public.founder_r3362_device_unit_matrix()
returns table(device_type text, unit text, checks bigint, passed bigint, avg_tidal_error_pct numeric, avg_battery_runtime_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.unit, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.tidal_volume_accuracy_error_pct), 2),
    round(avg(l.battery_runtime_hours), 2)
  from public.transport_vent_qc_r3362 l
  group by l.device_type, l.unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3362_device_unit_matrix() from public, anon;
grant execute on function public.founder_r3362_device_unit_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3362_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, alarm_fail bigint, not_ready bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.alarm_function_test = 'fail')::bigint,
    count(*) filter (where l.ready_for_dispatch = false)::bigint
  from public.transport_vent_qc_r3362 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3362_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3362_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3362_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.transport_vent_qc_capa_actions_r3362 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3362_capa_status_board() from public, anon;
grant execute on function public.founder_r3362_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3362_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transport_vent_qc_capa_actions_r3362)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.transport_vent_qc_capa_actions_r3362 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3362_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3362_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3362_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.transport_vent_qc_capa_actions_r3362 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3362_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3362_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3362_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  unit text,
  check_date date,
  qc_verdict text,
  alarm_function_test text,
  circuit_leak_test text,
  ready_for_dispatch boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.unit, l.check_date,
    l.qc_verdict, l.alarm_function_test, l.circuit_leak_test, l.ready_for_dispatch, l.notes
  from public.transport_vent_qc_r3362 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.alarm_function_test = 'fail'
     or l.circuit_leak_test in ('minor_leak','fail')
     or l.ready_for_dispatch = false
     or l.self_test_pass = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3362_high_risk_queue() from public, anon;
grant execute on function public.founder_r3362_high_risk_queue() to authenticated;
