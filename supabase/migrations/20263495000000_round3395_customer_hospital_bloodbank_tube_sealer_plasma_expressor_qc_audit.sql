-- Round 3395: Customer Hospital Blood-Bank Tube-Sealer, Plasma-Expressor & Component Processing QC Audit
-- Blood-bank processing QA — device type × department × seal integrity × weight accuracy × mixing × temperature × rpm × sterile weld × CAPA

-- =============================================================================
-- TABLE 1: bloodbag_processing_qc_r3395 — per-device QC checks
-- =============================================================================
create table if not exists public.bloodbag_processing_qc_r3395 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'tube_sealer','plasma_expressor','component_weigh_mixer','sterile_connection_device',
    'blood_bag_centrifuge','cryoprecipitate_bath'
  )),
  department text not null,
  check_date date not null,
  seal_integrity_ok boolean not null,
  seal_test_result text not null check (seal_test_result in (
    'pass','weak_seal','fail','not_applicable'
  )),
  weight_accuracy_error_pct numeric(5,2),
  mixing_uniformity_ok boolean not null,
  temperature_control_ok text not null check (temperature_control_ok in (
    'ok','drift','fail','not_applicable'
  )),
  rpm_accuracy_ok text not null check (rpm_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  sterile_weld_integrity_ok boolean not null,
  hygiene_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bloodbag_processing_qc_r3395 enable row level security;

create index if not exists idx_bloodbag_processing_qc_r3395_org on public.bloodbag_processing_qc_r3395(organization_id);
create index if not exists idx_bloodbag_processing_qc_r3395_date on public.bloodbag_processing_qc_r3395(check_date);
create index if not exists idx_bloodbag_processing_qc_r3395_verdict on public.bloodbag_processing_qc_r3395(qc_verdict);

-- =============================================================================
-- TABLE 2: bloodbag_processing_qc_capa_actions_r3395 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.bloodbag_processing_qc_capa_actions_r3395 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.bloodbag_processing_qc_r3395(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'seal_integrity_failure','weak_seal','weight_accuracy_out_of_tolerance','mixing_non_uniform',
    'temperature_control_failure','rpm_accuracy_failure','alarm_test_failure',
    'sterile_weld_failure','hygiene_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'heating_element_wear','load_cell_drift','motor_fault','sensor_misalignment',
    'consumable_quality_issue','seal_die_worn','operator_setup_error',
    'pending_investigation','preventive_service_backlog','wafer_electrode_worn'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_heating_element','recalibrate_load_cell','repair_motor','realign_sensor',
    'replace_seal_die','replace_wafer_electrode','recalibrate','retrain_bloodbank_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','nbtc_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bloodbag_processing_qc_capa_actions_r3395 enable row level security;

create index if not exists idx_bloodbag_processing_capa_r3395_log on public.bloodbag_processing_qc_capa_actions_r3395(qc_log_id);
create index if not exists idx_bloodbag_processing_capa_r3395_status on public.bloodbag_processing_qc_capa_actions_r3395(capa_status);

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

  insert into public.bloodbag_processing_qc_r3395 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    seal_integrity_ok, seal_test_result, weight_accuracy_error_pct, mixing_uniformity_ok,
    temperature_control_ok, rpm_accuracy_ok, alarm_test, sterile_weld_integrity_ok,
    hygiene_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.seal, q.sealtest, q.werr, q.mix,
    q.temp, q.rpm, q.alarm, q.weld,
    q.hyg, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','BB-APL-01','tube_sealer','blood_bank','2026-07-03',
     true,'pass',null,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Quarterly QC — RF tube sealer seals within spec'),
    ('Apollo Chennai','BB-APL-02','component_weigh_mixer','blood_bank','2026-07-03',
     true,'not_applicable',0.6,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Weigh-mixer accuracy and mixing uniform'),
    ('Fortis Gurgaon','BB-FRT-11','plasma_expressor','blood_bank','2026-07-02',
     true,'not_applicable',null,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Plasma expressor QC nominal'),
    ('Fortis Gurgaon','BB-FRT-12','tube_sealer','blood_bank','2026-07-02',
     false,'fail',null,true,'not_applicable','not_applicable','fail',true,true,true,'fail','Tube sealer weak/failed seals and alarm fail — seal die worn, pulled'),
    ('Manipal Bengaluru','BB-MNP-21','blood_bag_centrifuge','blood_bank','2026-07-01',
     true,'not_applicable',null,true,'drift','drift','pass',true,true,false,'conditional_pass','Bag centrifuge temp and rpm drift, calibration overdue — recheck'),
    ('Manipal Bengaluru','BB-MNP-22','sterile_connection_device','blood_bank','2026-07-01',
     true,'not_applicable',null,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Sterile connection device weld QC pass'),
    ('AIIMS Delhi','BB-AIM-31','component_weigh_mixer','blood_bank','2026-06-30',
     true,'not_applicable',2.4,false,'not_applicable','not_applicable','pass',true,true,true,'conditional_pass','Weigh-mixer accuracy 2.4% and mixing non-uniform — load cell drift'),
    ('AIIMS Delhi','BB-AIM-32','cryoprecipitate_bath','blood_bank','2026-06-30',
     true,'not_applicable',null,true,'fail','not_applicable','fail',true,false,true,'fail','Cryo bath temperature control and alarm failed, hygiene lapse — pulled'),
    ('CMC Vellore','BB-CMC-41','tube_sealer','blood_bank','2026-06-29',
     true,'pass',null,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Tube sealer QC pass'),
    ('CMC Vellore','BB-CMC-42','sterile_connection_device','blood_bank','2026-06-29',
     false,'not_applicable',null,true,'not_applicable','not_applicable','pass',false,true,true,'conditional_pass','Sterile weld integrity marginal — wafer electrode replace due'),
    ('KIMS Hyderabad','BB-KIM-51','plasma_expressor','blood_bank','2026-06-28',
     true,'not_applicable',null,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Plasma expressor QC pass post-AMC'),
    ('KIMS Hyderabad','BB-KIM-52','blood_bag_centrifuge','blood_bank','2026-06-28',
     true,'not_applicable',null,true,'ok','ok','not_tested',true,true,true,'conditional_pass','Bag centrifuge balance ok but alarm not tested — recheck due'),
    ('Yashoda Hyderabad','BB-YSH-61','component_weigh_mixer','blood_bank','2026-06-27',
     true,'not_applicable',0.7,true,'not_applicable','not_applicable','pass',true,true,true,'pass','Weigh-mixer QC nominal'),
    ('Kokilaben Mumbai','BB-KKB-71','tube_sealer','blood_bank','2026-06-27',
     false,'fail',null,true,'not_applicable','not_applicable','fail',false,false,false,'removed_from_service','Tube sealer multiple failures across seal, alarm, weld, hygiene — removed')
  ) as q(hosp, dcode, dtype, dept, cdate, seal, sealtest, werr, mix, temp, rpm, alarm, weld, hyg, calcur, qv, nt);

  insert into public.bloodbag_processing_qc_capa_actions_r3395 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BB-FRT-12','seal_integrity_failure','seal_die_worn','replace_seal_die','in_progress','nbtc_deviation','2026-07-06',null,14000.00,'Tube sealer seal die replacement; seal validation after'),
    ('BB-AIM-31','weight_accuracy_out_of_tolerance','load_cell_drift','recalibrate_load_cell','open','internal_only','2026-07-05',null,6000.00,'Weigh-mixer load cell recalibration and mixing check'),
    ('BB-AIM-32','temperature_control_failure','heating_element_wear','replace_heating_element','escalated','patient_safety_alert','2026-07-04',null,19000.00,'Cryo bath temp control and alarm failure escalated'),
    ('BB-KKB-71','seal_integrity_failure','seal_die_worn','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',22000.00,'Sealer removed; replacement installed and seal-validated'),
    ('BB-CMC-42','sterile_weld_failure','wafer_electrode_worn','replace_wafer_electrode','verification_pending','nabh_finding','2026-07-05',null,8500.00,'SCD wafer electrode replaced — verify weld integrity'),
    ('BB-MNP-21','rpm_accuracy_failure','motor_fault','schedule_oem_service','overdue','internal_only','2026-06-30',null,17000.00,'Bag centrifuge motor service past target — vendor delay'),
    ('BB-KIM-52','alarm_test_failure','operator_setup_error','retrain_bloodbank_staff','open','none','2026-07-07',null,0.00,'Alarm test procedure retraining scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.bloodbag_processing_qc_r3395 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3395_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bloodbag_processing_qc_r3395)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bloodbag_processing_qc_r3395 l group by l.qc_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3395_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3395_qc_verdict_rollup() to authenticated;

create or replace function public.founder_r3395_hospital_scorecard()
returns table(
  hospital_name text, total_checks bigint, passed bigint, conditional bigint, failed bigint,
  seal_issue bigint, temp_issue bigint, calibration_overdue bigint, pass_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.seal_test_result in ('weak_seal','fail'))::bigint,
    count(*) filter (where l.temperature_control_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.bloodbag_processing_qc_r3395 l group by l.hospital_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3395_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3395_hospital_scorecard() to authenticated;

create or replace function public.founder_r3395_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_weight_error_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.weight_accuracy_error_pct), 2)
  from public.bloodbag_processing_qc_r3395 l group by l.device_type, l.department order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3395_device_department_matrix() from public, anon;
grant execute on function public.founder_r3395_device_department_matrix() to authenticated;

create or replace function public.founder_r3395_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, seal_issue bigint, temp_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.seal_test_result in ('weak_seal','fail'))::bigint,
    count(*) filter (where l.temperature_control_ok in ('drift','fail'))::bigint
  from public.bloodbag_processing_qc_r3395 l group by l.check_date order by l.check_date desc;
end;
$$;
revoke execute on function public.founder_r3395_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3395_daily_qc_trend() to authenticated;

create or replace function public.founder_r3395_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.bloodbag_processing_qc_capa_actions_r3395 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3395_capa_status_board() from public, anon;
grant execute on function public.founder_r3395_capa_status_board() to authenticated;

create or replace function public.founder_r3395_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bloodbag_processing_qc_capa_actions_r3395)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bloodbag_processing_qc_capa_actions_r3395 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3395_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3395_root_cause_pareto() to authenticated;

create or replace function public.founder_r3395_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.bloodbag_processing_qc_capa_actions_r3395 c group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3395_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3395_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3395_high_risk_queue()
returns table(
  hospital_name text, device_code text, device_type text, department text, check_date date,
  qc_verdict text, seal_test_result text, temperature_control_ok text, alarm_test text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.seal_test_result, l.temperature_control_ok, l.alarm_test, l.notes
  from public.bloodbag_processing_qc_r3395 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.seal_integrity_ok = false
     or l.seal_test_result in ('weak_seal','fail')
     or l.mixing_uniformity_ok = false
     or l.temperature_control_ok in ('drift','fail')
     or l.rpm_accuracy_ok in ('drift','fail')
     or l.alarm_test in ('fail','not_tested')
     or l.sterile_weld_integrity_ok = false
     or l.hygiene_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;
revoke execute on function public.founder_r3395_high_risk_queue() from public, anon;
grant execute on function public.founder_r3395_high_risk_queue() to authenticated;
