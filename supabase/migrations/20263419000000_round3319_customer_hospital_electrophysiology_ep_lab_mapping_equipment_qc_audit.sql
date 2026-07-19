-- Round 3319: Customer Hospital Electrophysiology (EP) Lab Mapping-Equipment QC Audit
-- EP-lab QA — device type × signal acquisition × mapping accuracy × ablation power × impedance monitoring × irrigation pump × catheter integrity × defib sync × patient leakage × calibration × CAPA

-- =============================================================================
-- TABLE 1: ep_lab_qc_r3319 — per-device EP-lab equipment QC checks
-- =============================================================================
create table if not exists public.ep_lab_qc_r3319 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    '3d_mapping_system','ep_recording_system','rf_ablation_generator',
    'cryoablation_console','stimulator','intracardiac_echo'
  )),
  ep_lab text not null,
  check_date date not null,
  signal_acquisition_ok boolean not null,
  mapping_accuracy_ok text not null check (mapping_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  ablation_power_output_error_pct numeric(5,2),
  impedance_monitoring_ok boolean not null,
  irrigation_pump_ok text not null check (irrigation_pump_ok in (
    'ok','fault','not_applicable'
  )),
  catheter_connection_integrity_ok boolean not null,
  emergency_defib_sync_ok boolean not null,
  patient_isolation_leakage_ua numeric(6,2),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ep_lab_qc_r3319 enable row level security;

create index if not exists idx_ep_lab_qc_r3319_org on public.ep_lab_qc_r3319(organization_id);
create index if not exists idx_ep_lab_qc_r3319_date on public.ep_lab_qc_r3319(check_date);
create index if not exists idx_ep_lab_qc_r3319_verdict on public.ep_lab_qc_r3319(qc_verdict);

-- =============================================================================
-- TABLE 2: ep_lab_qc_capa_actions_r3319 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ep_lab_qc_capa_actions_r3319 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ep_lab_qc_r3319(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'signal_acquisition_failure','mapping_accuracy_drift','ablation_power_deviation',
    'impedance_monitoring_failure','irrigation_pump_fault','catheter_connection_fault',
    'defib_sync_failure','patient_leakage_exceedance','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'mapping_sensor_drift','rf_generator_calibration_drift','irrigation_pump_wear',
    'catheter_connector_wear','defib_sync_cable_fault','isolation_transformer_leak',
    'software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_mapping_system','recalibrate_rf_generator','replace_irrigation_pump',
    'replace_catheter_connector','replace_defib_sync_cable','repair_isolation_transformer',
    'update_software_config','retrain_ep_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.ep_lab_qc_capa_actions_r3319 enable row level security;

create index if not exists idx_ep_lab_capa_r3319_log on public.ep_lab_qc_capa_actions_r3319(qc_log_id);
create index if not exists idx_ep_lab_capa_r3319_status on public.ep_lab_qc_capa_actions_r3319(capa_status);

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

  -- 14 EP-lab QC rows
  insert into public.ep_lab_qc_r3319 (
    organization_id, hospital_name, device_code, device_type, ep_lab, check_date,
    signal_acquisition_ok, mapping_accuracy_ok, ablation_power_output_error_pct,
    impedance_monitoring_ok, irrigation_pump_ok, catheter_connection_integrity_ok,
    emergency_defib_sync_ok, patient_isolation_leakage_ua, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.lab, q.cd::date,
    q.sao, q.maok, q.aperr,
    q.imon, q.irr, q.cci,
    q.eds, q.leak, q.calcur,
    q.qv, q.nt
  from (values
    ('Apollo Chennai','EP-APL-3DM-01','3d_mapping_system','EP-1','2026-07-03',
     true,'ok',null,true,'not_applicable',true,true,4.2,true,'pass','Quarterly QC — CARTO map accuracy within tolerance'),
    ('Apollo Chennai','EP-APL-REC-02','ep_recording_system','EP-1','2026-07-03',
     true,'not_applicable',null,true,'not_applicable',true,true,3.8,true,'pass','EP recording amplifier noise floor nominal'),
    ('Fortis Gurgaon','EP-FRT-RFA-01','rf_ablation_generator','EP-2','2026-07-02',
     true,'not_applicable',7.50,true,'ok',true,true,6.1,true,'conditional_pass','RF power output 7.5% high — recheck after generator service'),
    ('Fortis Gurgaon','EP-FRT-CRY-02','cryoablation_console','EP-2','2026-07-02',
     true,'not_applicable',null,false,'not_applicable',true,true,5.4,true,'fail','Impedance monitoring dropped during freeze cycle — held'),
    ('Manipal Bengaluru','EP-MNP-3DM-01','3d_mapping_system','EP-1','2026-07-01',
     true,'drift',null,true,'not_applicable',true,true,4.6,true,'conditional_pass','Mapping accuracy drift 3mm at far-field — recalibration booked'),
    ('Manipal Bengaluru','EP-MNP-STM-02','stimulator','EP-1','2026-07-01',
     true,'not_applicable',null,true,'not_applicable',true,true,3.2,true,'pass','Programmed stimulator output and timing verified'),
    ('AIIMS Delhi','EP-AIM-RFA-01','rf_ablation_generator','EP-3','2026-06-30',
     true,'not_applicable',3.10,true,'fault',true,true,58.0,true,'fail','Irrigation pump flow fault and leakage 58uA above 50uA limit'),
    ('AIIMS Delhi','EP-AIM-ICE-02','intracardiac_echo','EP-3','2026-06-30',
     true,'not_applicable',null,true,'not_applicable',true,true,4.0,true,'pass','ICE image quality and connector integrity verified'),
    ('CMC Vellore','EP-CMC-REC-01','ep_recording_system','EP-1','2026-06-29',
     false,'not_applicable',null,true,'not_applicable',true,true,4.4,true,'conditional_pass','Signal acquisition intermittent on 2 channels — cable swap pending'),
    ('CMC Vellore','EP-CMC-RFA-02','rf_ablation_generator','EP-2','2026-06-29',
     true,'not_applicable',2.20,true,'ok',true,false,6.8,true,'removed_from_service','Emergency defib sync failed to trigger — unit pulled from service'),
    ('KIMS Hyderabad','EP-KIM-3DM-01','3d_mapping_system','EP-1','2026-06-28',
     true,'fail',null,true,'not_applicable',false,true,5.1,false,'fail','Mapping accuracy fail 6mm and catheter connection intermittent; calibration lapsed'),
    ('Narayana Health Bengaluru','EP-NAR-CRY-01','cryoablation_console','EP-2','2026-06-27',
     true,'not_applicable',null,true,'not_applicable',true,true,4.3,true,'pass','Cryo console pressure and sensing verified nominal'),
    ('Medanta Gurgaon','EP-MED-RFA-01','rf_ablation_generator','EP-3','2026-06-26',
     true,'not_applicable',4.80,true,'ok',true,true,47.5,true,'conditional_pass','Leakage 47.5uA near 50uA limit — enhanced monitoring'),
    ('SGPGI Lucknow','EP-SGP-ICE-01','intracardiac_echo','EP-1','2026-06-25',
     true,'not_applicable',null,true,'not_applicable',true,true,3.9,true,'pass','Annual QC clean pass')
  ) as q(hosp, dcode, dtype, lab, cd, sao, maok, aperr, imon, irr, cci, eds, leak, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ep_lab_qc_capa_actions_r3319 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EP-FRT-RFA-01','ablation_power_deviation','rf_generator_calibration_drift','recalibrate_rf_generator','in_progress','iso_13485_deviation','2026-07-08',null,35000.00,'RF generator scheduled for OEM calibration'),
    ('EP-FRT-CRY-02','impedance_monitoring_failure','software_config_error','update_software_config','escalated','cdsco_notifiable','2026-07-07',null,28000.00,'Impedance dropout during freeze cycle — escalated to OEM'),
    ('EP-AIM-RFA-01','irrigation_pump_fault','irrigation_pump_wear','replace_irrigation_pump','open','patient_safety_alert','2026-07-10',null,62000.00,'Irrigation pump kit on order; leakage under review'),
    ('EP-CMC-REC-01','signal_acquisition_failure','catheter_connector_wear','replace_catheter_connector','verification_pending','internal_only','2026-07-05',null,9000.00,'Channel cable replaced — verify on next case'),
    ('EP-CMC-RFA-02','defib_sync_failure','defib_sync_cable_fault','replace_defib_sync_cable','closed','patient_safety_alert','2026-07-02','2026-06-30',15500.00,'Sync cable replaced and retested OK'),
    ('EP-KIM-3DM-01','mapping_accuracy_drift','mapping_sensor_drift','recalibrate_mapping_system','overdue','nabh_finding','2026-06-26',null,40000.00,'Recalibration overdue — NABH finding raised'),
    ('EP-MED-RFA-01','patient_leakage_exceedance','isolation_transformer_leak','repair_isolation_transformer','in_progress','iso_13485_deviation','2026-07-06',null,22000.00,'Isolation transformer leakage monitored; repair scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ep_lab_qc_r3319 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3319_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ep_lab_qc_r3319)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ep_lab_qc_r3319 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3319_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3319_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3319_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  signal_fail bigint,
  mapping_fail bigint,
  defib_sync_fail bigint,
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
    count(*) filter (where l.signal_acquisition_ok = false)::bigint,
    count(*) filter (where l.mapping_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.emergency_defib_sync_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ep_lab_qc_r3319 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3319_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3319_hospital_scorecard() to authenticated;

-- 3) Device-type × EP-lab matrix
create or replace function public.founder_r3319_device_type_lab_matrix()
returns table(device_type text, ep_lab text, checks bigint, passed bigint, avg_power_error_pct numeric, avg_leakage_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.ep_lab, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.ablation_power_output_error_pct), 2),
    round(avg(l.patient_isolation_leakage_ua), 1)
  from public.ep_lab_qc_r3319 l
  group by l.device_type, l.ep_lab
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3319_device_type_lab_matrix() from public, anon;
grant execute on function public.founder_r3319_device_type_lab_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3319_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, signal_fail bigint, mapping_fail bigint)
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
    count(*) filter (where l.signal_acquisition_ok = false)::bigint,
    count(*) filter (where l.mapping_accuracy_ok in ('drift','fail'))::bigint
  from public.ep_lab_qc_r3319 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3319_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3319_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3319_capa_status_board()
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
  from public.ep_lab_qc_capa_actions_r3319 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3319_capa_status_board() from public, anon;
grant execute on function public.founder_r3319_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3319_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ep_lab_qc_capa_actions_r3319)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ep_lab_qc_capa_actions_r3319 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3319_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3319_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3319_regulatory_impact_digest()
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
  from public.ep_lab_qc_capa_actions_r3319 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3319_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3319_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3319_high_risk_queue()
returns table(
  hospital_name text,
  ep_lab text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  mapping_accuracy_ok text,
  irrigation_pump_ok text,
  patient_isolation_leakage_ua numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ep_lab, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.mapping_accuracy_ok, l.irrigation_pump_ok,
    l.patient_isolation_leakage_ua, l.notes
  from public.ep_lab_qc_r3319 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.signal_acquisition_ok = false
     or l.mapping_accuracy_ok in ('drift','fail')
     or l.irrigation_pump_ok = 'fault'
     or l.impedance_monitoring_ok = false
     or l.catheter_connection_integrity_ok = false
     or l.emergency_defib_sync_ok = false
     or l.calibration_current = false
     or l.patient_isolation_leakage_ua >= 47.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3319_high_risk_queue() from public, anon;
grant execute on function public.founder_r3319_high_risk_queue() to authenticated;
