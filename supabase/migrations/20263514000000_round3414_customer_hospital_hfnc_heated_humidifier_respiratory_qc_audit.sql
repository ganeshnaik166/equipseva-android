-- Round 3414: Customer Hospital HFNC & Heated-Humidifier Respiratory QC Audit
-- Respiratory-therapy QA — device type × ward × flow-rate accuracy × FiO2 delivery × temperature accuracy × humidity output × water-chamber seal × heater-wire circuit × alarm test × oxygen blender × infection control × calibration × CAPA

-- =============================================================================
-- TABLE 1: hfnc_humidifier_qc_r3414 — per-device HFNC / heated-humidifier QC checks
-- =============================================================================
create table if not exists public.hfnc_humidifier_qc_r3414 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'hfnc_standalone','hfnc_integrated','heated_humidifier','bubble_cpap_humidifier','neonatal_hfnc'
  )),
  ward text not null check (ward in (
    'respiratory_icu','nicu','picu','general_ward','emergency'
  )),
  check_date date not null,
  flow_rate_accuracy_error_pct numeric(5,2),
  fio2_delivery_accuracy_ok boolean not null,
  temperature_accuracy_error_c numeric(5,2),
  humidity_output_ok boolean not null,
  water_chamber_seal_ok boolean not null,
  heater_wire_circuit_ok text not null check (heater_wire_circuit_ok in (
    'ok','fault','replace_due','not_applicable'
  )),
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  oxygen_blender_ok boolean not null,
  infection_control_clean_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hfnc_humidifier_qc_r3414 enable row level security;

create index if not exists idx_hfnc_humidifier_qc_r3414_org on public.hfnc_humidifier_qc_r3414(organization_id);
create index if not exists idx_hfnc_humidifier_qc_r3414_date on public.hfnc_humidifier_qc_r3414(check_date);
create index if not exists idx_hfnc_humidifier_qc_r3414_verdict on public.hfnc_humidifier_qc_r3414(qc_verdict);

-- =============================================================================
-- TABLE 2: hfnc_humidifier_qc_capa_actions_r3414 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hfnc_humidifier_qc_capa_actions_r3414 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.hfnc_humidifier_qc_r3414(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'flow_rate_out_of_tolerance','fio2_delivery_inaccurate','temperature_out_of_tolerance',
    'humidity_output_low','water_chamber_seal_leak','heater_wire_circuit_fault',
    'alarm_test_failure','oxygen_blender_fault','infection_control_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'flow_sensor_drift','oxygen_sensor_degraded','heater_plate_fault','heater_wire_broken',
    'chamber_seal_worn','blender_valve_fault','biofilm_contamination','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_flow_sensor','replace_oxygen_sensor','replace_heater_plate','replace_heater_wire_circuit',
    'replace_water_chamber','replace_blender','deep_clean_disinfect','update_software_config',
    'retrain_respiratory_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.hfnc_humidifier_qc_capa_actions_r3414 enable row level security;

create index if not exists idx_hfnc_humidifier_capa_r3414_log on public.hfnc_humidifier_qc_capa_actions_r3414(qc_log_id);
create index if not exists idx_hfnc_humidifier_capa_r3414_status on public.hfnc_humidifier_qc_capa_actions_r3414(capa_status);

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
  insert into public.hfnc_humidifier_qc_r3414 (
    organization_id, hospital_name, device_code, device_type, ward, check_date,
    flow_rate_accuracy_error_pct, fio2_delivery_accuracy_ok, temperature_accuracy_error_c,
    humidity_output_ok, water_chamber_seal_ok, heater_wire_circuit_ok, alarm_test,
    oxygen_blender_ok, infection_control_clean_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.ward, q.cdate::date,
    q.flowerr, q.fio2ok, q.temperr,
    q.humok, q.sealok, q.heater, q.alarm,
    q.blenderok, q.infclean, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','HFNC-APL-01','hfnc_standalone','respiratory_icu','2026-07-10',
     1.2,true,0.3,true,true,'ok','pass',true,true,true,'pass','Quarterly QC — AIRVO flow and FiO2 within tolerance'),
    ('Apollo Chennai','HUM-APL-02','heated_humidifier','respiratory_icu','2026-07-10',
     null,true,0.5,true,true,'ok','pass',true,true,true,'pass','MR850 heated humidifier temperature probe QC clean'),
    ('Fortis Gurgaon','HFNC-FRT-11','hfnc_integrated','respiratory_icu','2026-07-09',
     2.1,true,0.9,true,true,'ok','pass',true,false,true,'conditional_pass','Integrated HFNC — infection-control clean overdue, circuit change due'),
    ('Fortis Gurgaon','HUM-FRT-12','heated_humidifier','general_ward','2026-07-09',
     null,false,3.4,false,true,'fault','pass',true,true,true,'fail','Heater wire circuit fault, temp error 3.4C and humidity output low'),
    ('Manipal Bengaluru','NHFNC-MNP-21','neonatal_hfnc','nicu','2026-07-08',
     0.8,true,0.4,true,true,'ok','pass',true,true,true,'pass','Neonatal HFNC Optiflow Junior QC pass in NICU'),
    ('Manipal Bengaluru','BCPAP-MNP-22','bubble_cpap_humidifier','nicu','2026-07-08',
     null,true,null,false,false,'not_applicable','not_tested',true,true,false,'removed_from_service','Bubble CPAP humidifier chamber seal leak and calibration overdue — removed'),
    ('AIIMS Delhi','HFNC-AIM-31','hfnc_standalone','picu','2026-07-07',
     1.9,true,1.1,true,true,'ok','pass',true,true,true,'conditional_pass','Flow error 1.9% within limit but upward drift flagged for recheck'),
    ('AIIMS Delhi','HFNC-AIM-32','hfnc_integrated','emergency','2026-07-07',
     3.6,false,0.8,true,true,'ok','fail',false,true,true,'fail','FiO2 delivery inaccurate, oxygen blender fault and alarm test failed'),
    ('CMC Vellore','HUM-CMC-41','heated_humidifier','respiratory_icu','2026-07-06',
     null,true,0.6,true,true,'ok','pass',true,true,true,'pass','Heated humidifier QC pass post-PM'),
    ('CMC Vellore','NHFNC-CMC-42','neonatal_hfnc','nicu','2026-07-06',
     1.4,true,0.7,true,false,'ok','pass',true,true,false,'conditional_pass','Water chamber seal worn and calibration overdue — replacement ordered'),
    ('KIMS Hyderabad','HFNC-KIM-51','hfnc_standalone','respiratory_icu','2026-07-05',
     0.9,true,0.4,true,true,'ok','pass',true,true,true,'pass','Standalone HFNC QC pass post-AMC'),
    ('KIMS Hyderabad','HUM-KIM-52','heated_humidifier','general_ward','2026-07-05',
     null,true,1.2,true,true,'replace_due','not_tested',true,true,true,'conditional_pass','Heater wire circuit replacement due and alarm not tested — recheck due'),
    ('Yashoda Hyderabad','HFNC-YSH-61','hfnc_integrated','picu','2026-07-04',
     1.0,true,0.5,true,true,'ok','pass',true,true,true,'pass','Integrated HFNC humidification QC nominal'),
    ('Kokilaben Mumbai','BCPAP-KKB-71','bubble_cpap_humidifier','nicu','2026-07-04',
     null,false,4.2,false,false,'fault','fail',false,false,false,'removed_from_service','Multiple failures — heater fault, seal leak, blender fault — removed from service')
  ) as q(hosp, dcode, dtype, ward, cdate, flowerr, fio2ok, temperr, humok, sealok, heater, alarm, blenderok, infclean, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.hfnc_humidifier_qc_capa_actions_r3414 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HUM-FRT-12','heater_wire_circuit_fault','heater_wire_broken','replace_heater_wire_circuit','in_progress','iso_13485_deviation','2026-07-13',null,18000.00,'Heater wire circuit replacement in progress — verify temp output'),
    ('BCPAP-MNP-22','water_chamber_seal_leak','chamber_seal_worn','replace_water_chamber','open','nabh_finding','2026-07-12',null,9500.00,'Chamber seal leak — replacement chamber kit ordered'),
    ('HFNC-AIM-32','oxygen_blender_fault','blender_valve_fault','replace_blender','escalated','patient_safety_alert','2026-07-11',null,26000.00,'FiO2 delivery fault with alarm miss — escalated to OEM'),
    ('BCPAP-KKB-71','heater_wire_circuit_fault','heater_plate_fault','remove_from_service','closed','cdsco_notifiable','2026-07-09','2026-07-05',54000.00,'Multiple failures — device removed; replacement installed and validated'),
    ('NHFNC-CMC-42','water_chamber_seal_leak','chamber_seal_worn','replace_water_chamber','verification_pending','internal_only','2026-07-12',null,7200.00,'Neonatal HFNC chamber replaced — verify seal next case'),
    ('HUM-KIM-52','heater_wire_circuit_fault','heater_wire_broken','replace_heater_wire_circuit','overdue','internal_only','2026-07-08',null,16000.00,'Heater wire circuit replacement past target date — vendor delay'),
    ('HFNC-FRT-11','infection_control_failure','biofilm_contamination','deep_clean_disinfect','open','none','2026-07-14',null,3500.00,'Deep clean and disinfection scheduled — recheck culture')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.hfnc_humidifier_qc_r3414 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3414_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hfnc_humidifier_qc_r3414)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hfnc_humidifier_qc_r3414 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3414_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3414_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3414_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  humidity_fail bigint,
  seal_fail bigint,
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
    count(*) filter (where l.humidity_output_ok = false)::bigint,
    count(*) filter (where l.water_chamber_seal_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.hfnc_humidifier_qc_r3414 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3414_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3414_hospital_scorecard() to authenticated;

-- 3) Device-type × ward matrix
create or replace function public.founder_r3414_device_type_ward_matrix()
returns table(device_type text, ward text, checks bigint, passed bigint, failed bigint, avg_flow_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.ward, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.flow_rate_accuracy_error_pct), 2)
  from public.hfnc_humidifier_qc_r3414 l
  group by l.device_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3414_device_type_ward_matrix() from public, anon;
grant execute on function public.founder_r3414_device_type_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3414_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, humidity_fail bigint, fio2_fail bigint)
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
    count(*) filter (where l.humidity_output_ok = false)::bigint,
    count(*) filter (where l.fio2_delivery_accuracy_ok = false)::bigint
  from public.hfnc_humidifier_qc_r3414 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3414_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3414_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3414_capa_status_board()
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
  from public.hfnc_humidifier_qc_capa_actions_r3414 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3414_capa_status_board() from public, anon;
grant execute on function public.founder_r3414_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3414_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hfnc_humidifier_qc_capa_actions_r3414)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hfnc_humidifier_qc_capa_actions_r3414 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3414_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3414_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3414_regulatory_impact_digest()
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
  from public.hfnc_humidifier_qc_capa_actions_r3414 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3414_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3414_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3414_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  ward text,
  check_date date,
  qc_verdict text,
  heater_wire_circuit_ok text,
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
  select l.hospital_name, l.device_code, l.device_type, l.ward, l.check_date,
    l.qc_verdict, l.heater_wire_circuit_ok, l.alarm_test, l.notes
  from public.hfnc_humidifier_qc_r3414 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.fio2_delivery_accuracy_ok = false
     or l.humidity_output_ok = false
     or l.water_chamber_seal_ok = false
     or l.oxygen_blender_ok = false
     or l.infection_control_clean_ok = false
     or l.calibration_current = false
     or l.heater_wire_circuit_ok in ('fault','replace_due')
     or l.alarm_test = 'fail'
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3414_high_risk_queue() from public, anon;
grant execute on function public.founder_r3414_high_risk_queue() to authenticated;
