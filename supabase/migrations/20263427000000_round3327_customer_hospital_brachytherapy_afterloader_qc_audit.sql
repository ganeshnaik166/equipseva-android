-- Round 3327: Customer Hospital Brachytherapy Afterloader QC Audit
-- Brachy QA — device type × source-position accuracy × activity/dwell verification × transfer-tube integrity
--   × applicator condition × treatment-room interlocks × emergency retract × area monitor × survey meter × calibration × CAPA

-- =============================================================================
-- TABLE 1: brachy_afterloader_qc_r3327 — per-device brachytherapy QC checks
-- =============================================================================
create table if not exists public.brachy_afterloader_qc_r3327 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'hdr_afterloader','ldr_afterloader','pdr_afterloader','source_calibrator_well','applicator_set'
  )),
  department text not null,
  check_date date not null,
  source_position_accuracy_mm numeric(5,2),
  source_activity_verified boolean not null,
  dwell_time_accuracy_ok boolean not null,
  transfer_tube_integrity_ok boolean not null,
  applicator_condition text not null check (applicator_condition in (
    'good','worn','damaged','replace_due'
  )),
  door_interlock_ok boolean not null,
  emergency_source_retract_ok boolean not null,
  area_radiation_monitor_ok boolean not null,
  survey_meter_available boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.brachy_afterloader_qc_r3327 enable row level security;

create index if not exists idx_brachy_afterloader_qc_r3327_org on public.brachy_afterloader_qc_r3327(organization_id);
create index if not exists idx_brachy_afterloader_qc_r3327_date on public.brachy_afterloader_qc_r3327(check_date);
create index if not exists idx_brachy_afterloader_qc_r3327_verdict on public.brachy_afterloader_qc_r3327(qc_verdict);

-- =============================================================================
-- TABLE 2: brachy_afterloader_qc_capa_actions_r3327 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.brachy_afterloader_qc_capa_actions_r3327 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.brachy_afterloader_qc_r3327(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'source_position_deviation','source_activity_discrepancy','dwell_time_error','transfer_tube_defect',
    'applicator_wear','interlock_failure','emergency_retract_failure','area_monitor_fault',
    'survey_meter_unavailable','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'drive_cable_wear','source_decay_uncorrected','timer_drift','transfer_tube_kinked',
    'applicator_corrosion','interlock_switch_faulty','retract_motor_fault','monitor_detector_drift',
    'calibration_backlog','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_drive_cable','recalculate_source_decay','recalibrate_timer','replace_transfer_tube',
    'replace_applicator','replace_interlock_switch','service_retract_mechanism','recalibrate_area_monitor',
    'schedule_source_recalibration','retrain_brachy_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.brachy_afterloader_qc_capa_actions_r3327 enable row level security;

create index if not exists idx_brachy_capa_r3327_log on public.brachy_afterloader_qc_capa_actions_r3327(qc_log_id);
create index if not exists idx_brachy_capa_r3327_status on public.brachy_afterloader_qc_capa_actions_r3327(capa_status);

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

  -- 14 brachytherapy QC rows
  insert into public.brachy_afterloader_qc_r3327 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    source_position_accuracy_mm, source_activity_verified, dwell_time_accuracy_ok, transfer_tube_integrity_ok,
    applicator_condition, door_interlock_ok, emergency_source_retract_ok, area_radiation_monitor_ok,
    survey_meter_available, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cd::date,
    q.spa, q.sav, q.dta, q.tti,
    q.ac, q.dio, q.esr, q.arm,
    q.sma, q.cc, q.qv, q.nt
  from (values
    ('Tata Memorial Mumbai','BT-TMH-01','hdr_afterloader','Radiation Oncology','2026-07-10',
     0.80,true,true,true,'good',true,true,true,true,true,'pass','Quarterly HDR QC — Ir-192 source, all interlocks verified'),
    ('Tata Memorial Mumbai','BT-TMH-02','source_calibrator_well','Medical Physics','2026-07-10',
     null,true,true,true,'good',true,true,true,true,true,'pass','Well chamber constancy within 0.5% — source-position test not applicable'),
    ('Apollo Chennai','BT-APL-01','hdr_afterloader','Brachytherapy Suite','2026-07-09',
     1.20,true,true,true,'worn',true,true,true,true,true,'conditional_pass','Source position 1.2mm near tolerance; applicator worn — monitor'),
    ('Apollo Chennai','BT-APL-02','pdr_afterloader','Radiation Oncology','2026-07-09',
     0.60,true,true,true,'good',true,true,true,false,true,'conditional_pass','Survey meter out for calibration — backup used, follow-up booked'),
    ('Fortis Gurgaon','BT-FRT-01','hdr_afterloader','Radiation Oncology','2026-07-08',
     2.40,true,false,true,'worn',true,true,true,true,true,'fail','Dwell-time error 3.1% and 2.4mm position deviation — recalibration required'),
    ('Fortis Gurgaon','BT-FRT-02','applicator_set','Gynae-Onc Brachytherapy','2026-07-08',
     null,true,true,false,'damaged',true,true,true,true,true,'removed_from_service','Fletcher applicator transfer tube cracked — set quarantined'),
    ('Manipal Bengaluru','BT-MNP-01','ldr_afterloader','Radiation Oncology','2026-07-07',
     0.90,true,true,true,'good',true,true,true,true,true,'pass','LDR Cs-137 QC clean pass'),
    ('Manipal Bengaluru','BT-MNP-02','hdr_afterloader','Brachytherapy Suite','2026-07-07',
     1.00,false,true,true,'good',true,true,true,true,false,'fail','Source activity 6% below decay-corrected expected and calibration overdue'),
    ('AIIMS Delhi','BT-AIM-01','hdr_afterloader','Radiation Oncology','2026-07-06',
     0.70,true,true,true,'good',false,true,true,true,true,'fail','Treatment-room door interlock did not halt source drive — unit locked out'),
    ('AIIMS Delhi','BT-AIM-02','pdr_afterloader','Radiation Oncology','2026-07-06',
     0.50,true,true,true,'good',true,true,true,true,true,'pass','Annual PDR QC — all parameters nominal'),
    ('CMC Vellore','BT-CMC-01','hdr_afterloader','Radiation Oncology','2026-07-05',
     1.10,true,true,true,'replace_due',true,false,true,true,true,'fail','Emergency source-retract took 9s (>5s limit); applicator past replacement interval'),
    ('KIMS Hyderabad','BT-KIM-01','ldr_afterloader','Brachytherapy Suite','2026-07-05',
     0.95,true,true,true,'worn',true,true,false,true,true,'conditional_pass','Area radiation monitor reading erratic — service call raised'),
    ('HCG Bengaluru','BT-HCG-01','hdr_afterloader','Radiation Oncology','2026-07-04',
     0.85,true,true,true,'good',true,true,true,true,true,'pass','Post-AMC verification — Ir-192 source exchange QC pass'),
    ('Rajiv Gandhi Cancer Delhi','BT-RGC-01','applicator_set','Gynae-Onc Brachytherapy','2026-07-04',
     null,true,true,true,'replace_due',true,true,true,true,true,'conditional_pass','Ring applicator nearing end of life — replacement scheduled')
  ) as q(hosp, dcode, dtype, dept, cd, spa, sav, dta, tti, ac, dio, esr, arm, sma, cc, qv, nt);

  -- CAPA seed — attach to specific QC checks via device code
  insert into public.brachy_afterloader_qc_capa_actions_r3327 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BT-FRT-01','dwell_time_error','timer_drift','recalibrate_timer','in_progress','aerb_notifiable','2026-07-14',null,55000.00,'Timer recalibration by OEM medical physicist — dwell accuracy re-test pending'),
    ('BT-FRT-02','transfer_tube_defect','transfer_tube_kinked','replace_transfer_tube','escalated','patient_safety_alert','2026-07-12',null,130000.00,'Cracked Fletcher applicator tube — AERB incident report filed, set quarantined'),
    ('BT-AIM-01','interlock_failure','interlock_switch_faulty','replace_interlock_switch','closed','aerb_notifiable','2026-07-09','2026-07-08',38000.00,'Door interlock microswitch replaced and re-verified — source drive halts correctly'),
    ('BT-MNP-02','source_activity_discrepancy','source_decay_uncorrected','recalculate_source_decay','closed','iso_13485_deviation','2026-07-09','2026-07-07',0.00,'Decay table corrected in TPS; activity re-verified within 1%'),
    ('BT-CMC-01','emergency_retract_failure','retract_motor_fault','service_retract_mechanism','open','patient_safety_alert','2026-07-11',null,92000.00,'Retract-motor gearbox service scheduled with OEM — unit locked out until fixed'),
    ('BT-KIM-01','area_monitor_fault','monitor_detector_drift','recalibrate_area_monitor','verification_pending','nabh_finding','2026-07-10',null,21000.00,'Area monitor recalibrated — awaiting 48h stability re-check'),
    ('BT-APL-01','applicator_wear','applicator_corrosion','replace_applicator','overdue','internal_only','2026-07-06',null,47000.00,'Applicator replacement past target date — procurement delay')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.brachy_afterloader_qc_r3327 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3327_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.brachy_afterloader_qc_r3327)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.brachy_afterloader_qc_r3327 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3327_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3327_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3327_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  interlock_fail bigint,
  retract_fail bigint,
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
    count(*) filter (where l.door_interlock_ok = false)::bigint,
    count(*) filter (where l.emergency_source_retract_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.brachy_afterloader_qc_r3327 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3327_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3327_hospital_scorecard() to authenticated;

-- 3) Device type × applicator condition matrix
create or replace function public.founder_r3327_device_applicator_matrix()
returns table(device_type text, applicator_condition text, audits bigint, passed bigint, avg_source_position_accuracy_mm numeric, activity_verified bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.applicator_condition, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.source_position_accuracy_mm), 2),
    count(*) filter (where l.source_activity_verified = true)::bigint
  from public.brachy_afterloader_qc_r3327 l
  group by l.device_type, l.applicator_condition
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3327_device_applicator_matrix() from public, anon;
grant execute on function public.founder_r3327_device_applicator_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3327_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, interlock_fail bigint, calibration_overdue bigint)
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
    count(*) filter (where l.door_interlock_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.brachy_afterloader_qc_r3327 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3327_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3327_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3327_capa_status_board()
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
  from public.brachy_afterloader_qc_capa_actions_r3327 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3327_capa_status_board() from public, anon;
grant execute on function public.founder_r3327_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3327_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.brachy_afterloader_qc_capa_actions_r3327)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.brachy_afterloader_qc_capa_actions_r3327 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3327_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3327_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3327_regulatory_impact_digest()
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
  from public.brachy_afterloader_qc_capa_actions_r3327 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3327_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3327_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3327_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  applicator_condition text,
  door_interlock_ok boolean,
  emergency_source_retract_ok boolean,
  calibration_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.applicator_condition, l.door_interlock_ok, l.emergency_source_retract_ok,
    l.calibration_current, l.notes
  from public.brachy_afterloader_qc_r3327 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.door_interlock_ok = false
     or l.emergency_source_retract_ok = false
     or l.area_radiation_monitor_ok = false
     or l.calibration_current = false
     or l.source_activity_verified = false
     or l.dwell_time_accuracy_ok = false
     or l.transfer_tube_integrity_ok = false
     or l.applicator_condition in ('damaged','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3327_high_risk_queue() from public, anon;
grant execute on function public.founder_r3327_high_risk_queue() to authenticated;
