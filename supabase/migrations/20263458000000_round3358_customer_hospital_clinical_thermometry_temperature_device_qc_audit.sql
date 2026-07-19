-- Round 3358: Customer Hospital Clinical Thermometry & Temperature-Device QC Audit
-- Thermometry QA — device type × accuracy error vs reference × within-tolerance × probe-cover stock × sensor condition × calibration reference × drift × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: clinical_thermometry_r3358 — per-device temperature QC checks
-- =============================================================================
create table if not exists public.clinical_thermometry_r3358 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'tympanic_thermometer','temporal_artery_scanner','digital_contact_thermometer',
    'skin_temp_probe','core_temp_probe','infrared_forehead'
  )),
  ward text not null,
  check_date date not null,
  accuracy_error_c numeric(5,2),
  within_tolerance boolean not null,
  probe_cover_stock text not null check (probe_cover_stock in (
    'adequate','low','out_of_stock','not_applicable'
  )),
  sensor_condition text not null check (sensor_condition in (
    'good','worn','cracked','replace_due'
  )),
  battery_ok boolean not null,
  calibration_reference_used text not null check (calibration_reference_used in (
    'blackbody','water_bath','dry_block','traceable_reference'
  )),
  cleaning_disinfection_ok boolean not null,
  drift_since_last_check_c numeric(5,2),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.clinical_thermometry_r3358 enable row level security;

create index if not exists idx_clinical_thermometry_r3358_org on public.clinical_thermometry_r3358(organization_id);
create index if not exists idx_clinical_thermometry_r3358_date on public.clinical_thermometry_r3358(check_date);
create index if not exists idx_clinical_thermometry_r3358_verdict on public.clinical_thermometry_r3358(qc_verdict);

-- =============================================================================
-- TABLE 2: clinical_thermometry_capa_actions_r3358 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.clinical_thermometry_capa_actions_r3358 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.clinical_thermometry_r3358(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','excessive_drift','sensor_damage','calibration_overdue',
    'probe_cover_shortage','battery_failure','disinfection_lapse','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_aging','physical_damage','calibration_expired','reference_standard_drift',
    'supply_chain_shortage','battery_depleted','cleaning_protocol_gap','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_sensor','recalibrate_device','replace_probe_covers','replace_battery',
    'reinforce_cleaning_protocol','retrain_ward_staff','remove_from_service','schedule_oem_service',
    'update_calibration_schedule','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.clinical_thermometry_capa_actions_r3358 enable row level security;

create index if not exists idx_clinical_thermometry_capa_r3358_log on public.clinical_thermometry_capa_actions_r3358(qc_log_id);
create index if not exists idx_clinical_thermometry_capa_r3358_status on public.clinical_thermometry_capa_actions_r3358(capa_status);

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

  -- 14 thermometry QC check rows
  insert into public.clinical_thermometry_r3358 (
    organization_id, hospital_name, device_code, device_type, ward, check_date,
    accuracy_error_c, within_tolerance, probe_cover_stock, sensor_condition, battery_ok,
    calibration_reference_used, cleaning_disinfection_ok, drift_since_last_check_c,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.ward, q.cdate::date,
    q.aerr, q.wtol, q.pcov, q.scond, q.batt,
    q.cref, q.clean, q.drift,
    q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','THERM-APL-001','tympanic_thermometer','Emergency','2026-07-05',
     0.08,true,'adequate','good',true,'blackbody',true,0.02,true,'pass','Quarterly QC nominal — reads within 0.1C of blackbody'),
    ('Apollo Chennai','THERM-APL-002','temporal_artery_scanner','ICU','2026-07-05',
     0.22,true,'not_applicable','good',true,'water_bath',true,0.05,true,'pass','Temporal scanner within 0.3C tolerance'),
    ('Fortis Gurugram','THERM-FRT-101','infrared_forehead','OPD','2026-07-04',
     0.45,false,'not_applicable','good',true,'blackbody',true,0.18,true,'conditional_pass','IR forehead 0.45C high vs blackbody — recheck booked'),
    ('Fortis Gurugram','THERM-FRT-102','digital_contact_thermometer','Paediatrics','2026-07-04',
     0.12,true,'low','good',true,'dry_block',true,0.03,true,'pass','Probe cover stock low — reorder raised'),
    ('Manipal Bengaluru','THERM-MNP-201','core_temp_probe','OT','2026-07-03',
     0.30,false,'not_applicable','worn',true,'water_bath',true,0.22,false,'fail','Core probe out of tolerance and calibration lapsed'),
    ('Manipal Bengaluru','THERM-MNP-202','skin_temp_probe','NICU','2026-07-03',
     0.10,true,'not_applicable','good',true,'traceable_reference',true,0.04,true,'pass','NICU skin probe nominal'),
    ('AIIMS Delhi','THERM-AIM-301','tympanic_thermometer','Emergency','2026-07-02',
     0.55,false,'out_of_stock','replace_due',true,'blackbody',true,0.30,true,'fail','Ear probe reads high, sensor replace-due, covers out of stock'),
    ('AIIMS Delhi','THERM-AIM-302','temporal_artery_scanner','ICU','2026-07-02',
     0.15,true,'not_applicable','good',false,'water_bath',true,0.06,true,'conditional_pass','Battery low — flagged for replacement'),
    ('CMC Vellore','THERM-CMC-401','digital_contact_thermometer','General Ward','2026-07-01',
     0.09,true,'adequate','good',true,'dry_block',true,0.02,true,'pass','Ward QC clean pass'),
    ('CMC Vellore','THERM-CMC-402','core_temp_probe','OT','2026-07-01',
     null,false,'not_applicable','cracked',true,'water_bath',false,null,false,'removed_from_service','Cracked core probe removed; disinfection incomplete'),
    ('KIMS Hyderabad','THERM-KIM-501','infrared_forehead','Screening','2026-06-30',
     0.20,true,'not_applicable','good',true,'blackbody',true,0.08,true,'pass','Entrance screening IR nominal'),
    ('KIMS Hyderabad','THERM-KIM-502','skin_temp_probe','NICU','2026-06-30',
     0.28,false,'not_applicable','worn',true,'traceable_reference',true,0.19,true,'conditional_pass','Skin probe drifting, sensor worn — watch'),
    ('Fortis Gurugram','THERM-FRT-103','tympanic_thermometer','OPD','2026-06-29',
     0.14,true,'adequate','good',true,'blackbody',true,0.05,true,'pass','Routine QC pass'),
    ('Apollo Chennai','THERM-APL-003','digital_contact_thermometer','ICU','2026-06-29',
     0.60,false,'low','replace_due',false,'dry_block',true,0.35,false,'fail','Multiple failures — device pulled for service')
  ) as q(hosp, dcode, dtype, ward, cdate, aerr, wtol, pcov, scond, batt, cref, clean, drift, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.clinical_thermometry_capa_actions_r3358 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('THERM-FRT-101','accuracy_out_of_tolerance','reference_standard_drift','recalibrate_device','in_progress','nabh_finding','2026-07-09',null,8000.00,'IR scanner recalibrated to blackbody — re-verify pending'),
    ('THERM-MNP-201','calibration_overdue','calibration_expired','update_calibration_schedule','open','iso_15189_deviation','2026-07-10',null,15000.00,'Core probe calibration lapsed — external cal booked'),
    ('THERM-AIM-301','sensor_damage','sensor_aging','replace_sensor','escalated','patient_safety_alert','2026-07-08',null,22000.00,'Tympanic sensor replace-due and reads high — escalated'),
    ('THERM-CMC-402','sensor_damage','physical_damage','remove_from_service','closed','iso_15189_deviation','2026-07-03','2026-07-01',18000.00,'Cracked core probe removed from service — replacement ordered'),
    ('THERM-KIM-502','excessive_drift','sensor_aging','replace_sensor','verification_pending','internal_only','2026-07-06',null,9000.00,'Skin probe drift beyond limit — sensor replaced, verifying'),
    ('THERM-APL-003','accuracy_out_of_tolerance','pending_investigation','schedule_oem_service','overdue','cdsco_notifiable','2026-06-30',null,25000.00,'Multiple QC failures — OEM service overdue'),
    ('THERM-AIM-302','battery_failure','battery_depleted','replace_battery','closed','internal_only','2026-07-05','2026-07-03',1500.00,'Scanner battery replaced — back in service')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.clinical_thermometry_r3358 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3358_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.clinical_thermometry_r3358)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.clinical_thermometry_r3358 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3358_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3358_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3358_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  sensor_issue bigint,
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.sensor_condition in ('worn','cracked','replace_due'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.clinical_thermometry_r3358 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3358_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3358_hospital_scorecard() to authenticated;

-- 3) Device type × calibration reference matrix
create or replace function public.founder_r3358_device_type_reference_matrix()
returns table(device_type text, calibration_reference_used text, checks bigint, passed bigint, avg_accuracy_error_c numeric, avg_drift_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.calibration_reference_used, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.accuracy_error_c), 2),
    round(avg(l.drift_since_last_check_c), 2)
  from public.clinical_thermometry_r3358 l
  group by l.device_type, l.calibration_reference_used
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3358_device_type_reference_matrix() from public, anon;
grant execute on function public.founder_r3358_device_type_reference_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3358_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, calibration_overdue bigint)
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.clinical_thermometry_r3358 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3358_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3358_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3358_capa_status_board()
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
  from public.clinical_thermometry_capa_actions_r3358 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3358_capa_status_board() from public, anon;
grant execute on function public.founder_r3358_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3358_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.clinical_thermometry_capa_actions_r3358)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.clinical_thermometry_capa_actions_r3358 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3358_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3358_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3358_regulatory_impact_digest()
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
  from public.clinical_thermometry_capa_actions_r3358 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3358_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3358_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3358_high_risk_queue()
returns table(
  hospital_name text,
  ward text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  tolerance_status text,
  sensor_condition text,
  calibration_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward, l.device_code, l.device_type, l.check_date,
    l.qc_verdict,
    case when l.within_tolerance then 'within_tolerance' else 'out_of_tolerance' end,
    l.sensor_condition,
    case when l.calibration_current then 'current' else 'overdue' end,
    l.notes
  from public.clinical_thermometry_r3358 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.within_tolerance = false
     or l.sensor_condition in ('worn','cracked','replace_due')
     or l.calibration_current = false
     or l.battery_ok = false
     or l.cleaning_disinfection_ok = false
     or l.probe_cover_stock = 'out_of_stock'
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3358_high_risk_queue() from public, anon;
grant execute on function public.founder_r3358_high_risk_queue() to authenticated;
