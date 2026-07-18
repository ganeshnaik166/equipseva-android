-- Round 3302: Customer Hospital Point-of-Care Testing (POCT) Device Fleet QC Audit
-- POCT fleet QA — device type × internal QC × EQAS × strip-lot × operator competency × LIS connectivity × calibration × cleaning × lab correlation × downtime × CAPA

-- =============================================================================
-- TABLE 1: poct_fleet_qc_r3302 — per-device POCT QC checks
-- =============================================================================
create table if not exists public.poct_fleet_qc_r3302 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'glucometer','abg_poct','coagulation_poct','cardiac_marker_poct','hba1c_poct','urine_strip_reader'
  )),
  ward text not null,
  check_date date not null,
  internal_qc_pass boolean not null,
  eqas_last_result text not null check (eqas_last_result in (
    'pass','warn','fail','not_enrolled'
  )),
  strip_lot_expiry_ok boolean not null,
  operator_competency_current boolean not null,
  connectivity_lis_sync_ok boolean not null,
  calibration_current boolean not null,
  cleaning_disinfection_ok boolean not null,
  result_correlation_lab_ok boolean not null,
  downtime_events int not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.poct_fleet_qc_r3302 enable row level security;

create index if not exists idx_poct_fleet_qc_r3302_org on public.poct_fleet_qc_r3302(organization_id);
create index if not exists idx_poct_fleet_qc_r3302_date on public.poct_fleet_qc_r3302(check_date);
create index if not exists idx_poct_fleet_qc_r3302_verdict on public.poct_fleet_qc_r3302(qc_verdict);

-- =============================================================================
-- TABLE 2: poct_fleet_qc_capa_actions_r3302 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.poct_fleet_qc_capa_actions_r3302 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.poct_fleet_qc_r3302(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'internal_qc_failure','eqas_failure','strip_lot_expired','operator_competency_lapsed',
    'lis_connectivity_failure','calibration_overdue','cleaning_disinfection_lapse',
    'lab_correlation_deviation','excessive_downtime','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reagent_strip_degraded','control_material_expired','meter_electronics_fault','operator_training_gap',
    'lis_interface_config_error','calibration_drift','cleaning_protocol_not_followed','sample_handling_error',
    'pending_investigation','device_end_of_life'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_reagent_strip_lot','replace_qc_control_material','replace_meter_unit','retrain_operator_competency',
    'reconfigure_lis_interface','recalibrate_device','reinforce_cleaning_protocol','correlate_with_central_lab',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.poct_fleet_qc_capa_actions_r3302 enable row level security;

create index if not exists idx_poct_capa_r3302_log on public.poct_fleet_qc_capa_actions_r3302(qc_log_id);
create index if not exists idx_poct_capa_r3302_status on public.poct_fleet_qc_capa_actions_r3302(capa_status);

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

  -- 14 POCT QC check rows
  insert into public.poct_fleet_qc_r3302 (
    organization_id, hospital_name, device_code, device_type, ward, check_date,
    internal_qc_pass, eqas_last_result, strip_lot_expiry_ok, operator_competency_current,
    connectivity_lis_sync_ok, calibration_current, cleaning_disinfection_ok,
    result_correlation_lab_ok, downtime_events, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.ward, q.cdate::date,
    q.iqc, q.eqas, q.slot, q.opc,
    q.lis, q.cal, q.clean,
    q.corr, q.dte::int, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','POCT-APL-GLU-01','glucometer','ICU','2026-07-02',
     true,'pass',true,true,true,true,true,true,0,'pass','Bedside glucometer — L1/L2 controls in range, LIS synced'),
    ('Apollo Chennai Greams Road','POCT-APL-ABG-01','abg_poct','Emergency','2026-07-02',
     true,'pass',true,true,false,true,true,true,2,'conditional_pass','ABG analyzer LIS sync dropped twice — connectivity watch'),
    ('Fortis Gurgaon','POCT-FRT-COAG-01','coagulation_poct','Cardiac ICU','2026-07-01',
     false,'warn',true,true,true,true,true,false,1,'fail','PT/INR L2 control out and lab correlation off — investigate'),
    ('Fortis Gurgaon','POCT-FRT-GLU-02','glucometer','General Ward','2026-07-01',
     true,'pass',false,true,true,true,true,true,0,'conditional_pass','Strip lot expiring in 5 days — reorder raised'),
    ('Manipal Bengaluru Old Airport Road','POCT-MNP-CARD-01','cardiac_marker_poct','Emergency','2026-06-30',
     true,'pass',true,false,true,true,true,true,0,'conditional_pass','Operator competency lapsed for 2 nurses — retraining booked'),
    ('Manipal Bengaluru Old Airport Road','POCT-MNP-HBA1C-01','hba1c_poct','Diabetology OPD','2026-06-30',
     true,'pass',true,true,true,false,true,true,1,'conditional_pass','Calibration overdue by 6 days — recal scheduled'),
    ('AIIMS Delhi Ansari Nagar','POCT-AIM-ABG-02','abg_poct','Neuro ICU','2026-06-29',
     false,'fail',true,true,true,true,false,false,3,'removed_from_service','ABG QC fail + EQAS fail + lab correlation off — unit pulled'),
    ('AIIMS Delhi Ansari Nagar','POCT-AIM-GLU-03','glucometer','Paediatric ICU','2026-06-29',
     true,'pass',true,true,true,true,true,true,0,'pass','Paediatric glucometer clean pass'),
    ('CMC Vellore','POCT-CMC-URINE-01','urine_strip_reader','Nephrology Ward','2026-06-28',
     true,'warn',true,true,true,true,true,true,0,'conditional_pass','EQAS warn on last cycle — monitor next return'),
    ('CMC Vellore','POCT-CMC-COAG-02','coagulation_poct','OT Complex','2026-06-28',
     true,'pass',true,true,true,true,false,true,0,'conditional_pass','Cleaning/disinfection log incomplete — reinforce protocol'),
    ('KIMS Hyderabad','POCT-KIM-CARD-02','cardiac_marker_poct','Cardiac ICU','2026-06-27',
     false,'fail',true,true,false,true,true,false,4,'fail','Troponin POCT QC + EQAS fail, LIS down, correlation off'),
    ('KIMS Hyderabad','POCT-KIM-GLU-04','glucometer','Emergency','2026-06-27',
     true,'pass',true,true,true,true,true,true,0,'pass','Routine QC pass'),
    ('SGPGI Lucknow','POCT-SGP-HBA1C-02','hba1c_poct','Endocrinology OPD','2026-06-26',
     true,'not_enrolled',true,true,true,true,true,true,0,'conditional_pass','HbA1c POCT not enrolled in EQAS — enrollment pending'),
    ('Narayana Health Bengaluru','POCT-NAR-ABG-03','abg_poct','CTVS ICU','2026-06-26',
     true,'pass',true,true,true,true,true,true,1,'pass','ABG analyzer post-service verification pass')
  ) as q(hosp, dcode, dtype, ward, cdate, iqc, eqas, slot, opc, lis, cal, clean, corr, dte, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.poct_fleet_qc_capa_actions_r3302 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('POCT-FRT-COAG-01','lab_correlation_deviation','control_material_expired','replace_qc_control_material','in_progress','patient_safety_alert','2026-07-06',null,15000.00,'PT/INR control expired — new lot loaded, awaiting lab correlation re-run'),
    ('POCT-AIM-ABG-02','eqas_failure','meter_electronics_fault','replace_meter_unit','escalated','cdsco_notifiable','2026-07-05',null,220000.00,'ABG analyzer electronics fault — escalated to OEM, loaner requested'),
    ('POCT-FRT-GLU-02','strip_lot_expired','reagent_strip_degraded','replace_reagent_strip_lot','closed','internal_only','2026-07-03','2026-07-02',8000.00,'New strip lot received and verified'),
    ('POCT-MNP-CARD-01','operator_competency_lapsed','operator_training_gap','retrain_operator_competency','open','nabh_finding','2026-07-08',null,5000.00,'Competency reassessment for 2 nurses scheduled'),
    ('POCT-MNP-HBA1C-01','calibration_overdue','calibration_drift','recalibrate_device','verification_pending','iso_15189_deviation','2026-07-04',null,12000.00,'Recalibrated — verify against reference next cycle'),
    ('POCT-KIM-CARD-02','lis_connectivity_failure','lis_interface_config_error','reconfigure_lis_interface','overdue','patient_safety_alert','2026-06-30',null,30000.00,'Troponin POCT LIS interface past target — vendor delayed'),
    ('POCT-CMC-COAG-02','cleaning_disinfection_lapse','cleaning_protocol_not_followed','reinforce_cleaning_protocol','closed','internal_only','2026-06-30','2026-06-29',0.00,'Cleaning log corrected, staff re-briefed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.poct_fleet_qc_r3302 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3302_qc_verdict_rollup()
returns table(qc_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.poct_fleet_qc_r3302)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.poct_fleet_qc_r3302 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3302_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3302_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3302_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  internal_qc_fail bigint,
  eqas_fail bigint,
  lab_correlation_fail bigint,
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
    count(*) filter (where l.internal_qc_pass = false)::bigint,
    count(*) filter (where l.eqas_last_result = 'fail')::bigint,
    count(*) filter (where l.result_correlation_lab_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.poct_fleet_qc_r3302 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3302_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3302_hospital_scorecard() to authenticated;

-- 3) Device type × ward matrix
create or replace function public.founder_r3302_device_ward_matrix()
returns table(device_type text, ward text, checks bigint, passed bigint, qc_fail bigint, avg_downtime_events numeric)
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
    round(avg(l.downtime_events), 2)
  from public.poct_fleet_qc_r3302 l
  group by l.device_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3302_device_ward_matrix() from public, anon;
grant execute on function public.founder_r3302_device_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3302_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, internal_qc_fail bigint, eqas_fail bigint)
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
    count(*) filter (where l.internal_qc_pass = false)::bigint,
    count(*) filter (where l.eqas_last_result = 'fail')::bigint
  from public.poct_fleet_qc_r3302 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3302_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3302_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3302_capa_status_board()
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
  from public.poct_fleet_qc_capa_actions_r3302 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3302_capa_status_board() from public, anon;
grant execute on function public.founder_r3302_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3302_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.poct_fleet_qc_capa_actions_r3302)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.poct_fleet_qc_capa_actions_r3302 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3302_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3302_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3302_regulatory_impact_digest()
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
  from public.poct_fleet_qc_capa_actions_r3302 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3302_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3302_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3302_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  ward text,
  check_date date,
  qc_verdict text,
  eqas_last_result text,
  internal_qc text,
  lab_correlation text,
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
    l.qc_verdict, l.eqas_last_result,
    case when l.internal_qc_pass then 'pass' else 'fail' end,
    case when l.result_correlation_lab_ok then 'ok' else 'off' end,
    l.notes
  from public.poct_fleet_qc_r3302 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.internal_qc_pass = false
     or l.eqas_last_result in ('warn','fail')
     or l.result_correlation_lab_ok = false
     or l.calibration_current = false
     or l.connectivity_lis_sync_ok = false
     or l.strip_lot_expiry_ok = false
     or l.operator_competency_current = false
     or l.cleaning_disinfection_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3302_high_risk_queue() from public, anon;
grant execute on function public.founder_r3302_high_risk_queue() to authenticated;
