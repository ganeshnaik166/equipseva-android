-- Round 3388: Engineer Equipment-History-File (EHF) / Service-Log Completeness & Audit-Trail Integrity Tracker
-- Per-device EHF audit — equipment type × engineer × install/service/parts/calibration/incident records × tamper-evident audit trail × accreditation readiness × completeness % × CAPA reconstruction

-- =============================================================================
-- TABLE 1: engineer_ehf_audit_r3388 — per-device equipment-history-file audits
-- =============================================================================
create table if not exists public.engineer_ehf_audit_r3388 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  device_code text not null,
  equipment_type text not null check (equipment_type in (
    'imaging','patient_monitoring','dialysis','ventilator','lab_analyzer','infusion_pump','ot_equipment'
  )),
  ehf_exists boolean not null,
  install_record_present boolean not null,
  service_records_count int not null,
  expected_service_records int not null,
  missing_records int not null,
  parts_replaced_logged boolean not null,
  calibration_records_current boolean not null,
  incident_records_linked boolean not null,
  last_updated_date date,
  audit_trail_tamper_evident boolean not null,
  accreditation_ready boolean not null,
  completeness_pct numeric(5,2) not null,
  ehf_verdict text not null check (ehf_verdict in (
    'complete_audit_ready','minor_gaps','records_missing','not_maintained','reconstruct_needed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_ehf_audit_r3388 enable row level security;

create index if not exists idx_engineer_ehf_audit_r3388_org on public.engineer_ehf_audit_r3388(organization_id);
create index if not exists idx_engineer_ehf_audit_r3388_updated on public.engineer_ehf_audit_r3388(last_updated_date);
create index if not exists idx_engineer_ehf_audit_r3388_verdict on public.engineer_ehf_audit_r3388(ehf_verdict);

-- =============================================================================
-- TABLE 2: engineer_ehf_audit_capa_actions_r3388 — record reconstruction & completion actions
-- =============================================================================
create table if not exists public.engineer_ehf_audit_capa_actions_r3388 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.engineer_ehf_audit_r3388(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_install_record','missing_service_records','parts_log_gap','calibration_records_absent',
    'incident_not_linked','audit_trail_not_tamper_evident','ehf_not_maintained','accreditation_gap'
  )),
  root_cause text not null check (root_cause in (
    'paper_records_not_digitized','engineer_documentation_lapse','handover_gap_prior_vendor',
    'lost_records','no_ehf_created','system_migration_data_loss','pending_investigation','process_not_defined'
  )),
  corrective_action text not null check (corrective_action in (
    'reconstruct_from_backups','digitize_paper_records','request_records_from_oem','create_new_ehf',
    'backfill_service_entries','link_incident_reports','enable_tamper_evident_log','retrain_engineer',
    'schedule_full_audit','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','jci_accreditation_gap'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_ehf_audit_capa_actions_r3388 enable row level security;

create index if not exists idx_engineer_ehf_capa_r3388_audit on public.engineer_ehf_audit_capa_actions_r3388(audit_id);
create index if not exists idx_engineer_ehf_capa_r3388_status on public.engineer_ehf_audit_capa_actions_r3388(capa_status);

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

  -- 14 per-device EHF audit rows
  insert into public.engineer_ehf_audit_r3388 (
    organization_id, hospital_name, engineer_name, device_code, equipment_type,
    ehf_exists, install_record_present, service_records_count, expected_service_records, missing_records,
    parts_replaced_logged, calibration_records_current, incident_records_linked, last_updated_date, audit_trail_tamper_evident,
    accreditation_ready, completeness_pct, ehf_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.dev, q.etype,
    q.ehf, q.inst, q.srec::int, q.exps::int, q.miss::int,
    q.parts, q.calib, q.inc, q.lud::date, q.tamper,
    q.accr, q.comp::numeric, q.verdict, q.nt
  from (values
    ('Apollo Chennai','Karthik Raman','IMG-APL-CHN-01','imaging',
     true,true,12,12,0,true,true,true,'2026-07-12',true,
     true,100.00,'complete_audit_ready','CT scanner history file complete — installation, all PMs, parts and calibration traceable; NABH ready'),
    ('Apollo Chennai','Karthik Raman','MON-APL-CHN-07','patient_monitoring',
     true,true,7,8,1,true,true,true,'2026-07-11',true,
     true,92.50,'minor_gaps','One quarterly service entry pending backfill on bedside monitor'),
    ('Fortis Gurgaon','Neha Sharma','DIA-FRT-GGN-03','dialysis',
     true,true,9,12,3,false,true,true,'2026-07-09',true,
     false,74.00,'records_missing','Three service records and parts-replacement log missing — water-treatment logs incomplete'),
    ('Fortis Gurgaon','Neha Sharma','VEN-FRT-GGN-05','ventilator',
     true,false,6,8,2,true,false,false,'2026-07-08',true,
     false,62.50,'records_missing','ICU ventilator install record and calibration certificates absent from EHF'),
    ('Manipal Bengaluru','Arjun Nair','LAB-MNP-BLR-02','lab_analyzer',
     true,true,10,10,0,true,true,true,'2026-07-10',true,
     true,98.00,'complete_audit_ready','Biochemistry analyzer EHF audit-ready — full traceable service and calibration history'),
    ('Manipal Bengaluru','Arjun Nair','INF-MNP-BLR-11','infusion_pump',
     true,true,4,6,2,true,true,false,'2026-07-07',false,
     false,70.00,'minor_gaps','Audit trail not tamper-evident — paper log only; incidents not yet linked'),
    ('AIIMS Delhi','Vikram Singh','OT-AIIMS-DEL-04','ot_equipment',
     true,true,11,12,1,true,true,true,'2026-07-11',true,
     true,95.00,'minor_gaps','OT electrosurgical unit — one preventive-maintenance entry pending in history file'),
    ('AIIMS Delhi','Vikram Singh','IMG-AIIMS-DEL-09','imaging',
     false,false,0,12,12,false,false,false,null,false,
     false,0.00,'not_maintained','No EHF created since installation — full history-file reconstruction required'),
    ('CMC Vellore','Priya Menon','DIA-CMC-VEL-06','dialysis',
     true,true,8,8,0,true,true,true,'2026-07-09',true,
     true,100.00,'complete_audit_ready','Dialysis machine history file complete and tamper-evident'),
    ('CMC Vellore','Priya Menon','MON-CMC-VEL-14','patient_monitoring',
     true,true,5,8,3,false,false,true,'2026-07-05',true,
     false,60.00,'records_missing','Central monitor — calibration and parts-replacement logs missing'),
    ('KIMS Hyderabad','Rahul Reddy','VEN-KIM-HYD-08','ventilator',
     true,true,3,8,5,false,false,false,'2026-06-30',false,
     false,40.00,'reconstruct_needed','Prior-vendor handover gap — most records lost; reconstruct from OEM and backups'),
    ('KIMS Hyderabad','Rahul Reddy','LAB-KIM-HYD-12','lab_analyzer',
     true,true,9,10,1,true,true,true,'2026-07-10',true,
     true,93.00,'minor_gaps','Hematology analyzer — one service note pending attachment to EHF'),
    ('Narayana Health Bengaluru','Sunita Iyer','INF-NAR-BLR-15','infusion_pump',
     false,false,0,6,6,false,false,false,null,false,
     false,0.00,'not_maintained','Rental infusion-pump fleet — no equipment history file maintained per device'),
    ('Medanta Gurgaon','Amitabh Bose','OT-MED-GGN-10','ot_equipment',
     true,true,7,10,3,true,false,true,'2026-07-06',true,
     false,68.00,'records_missing','OT anaesthesia workstation — calibration records absent, three PM entries missing')
  ) as q(hosp, eng, dev, etype, ehf, inst, srec, exps, miss, parts, calib, inc, lud, tamper, accr, comp, verdict, nt);

  -- CAPA seed — attach to specific at-risk audits via device_code
  insert into public.engineer_ehf_audit_capa_actions_r3388 (
    audit_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DIA-FRT-GGN-03','missing_service_records','engineer_documentation_lapse','backfill_service_entries','in_progress','nabh_finding','2026-07-20',null,15000.00,'Backfilling three dialysis service entries from paper job cards'),
    ('VEN-FRT-GGN-05','missing_install_record','handover_gap_prior_vendor','request_records_from_oem','open','iso_13485_deviation','2026-07-25',null,22000.00,'Install certificate and calibration records requested from OEM'),
    ('IMG-AIIMS-DEL-09','ehf_not_maintained','no_ehf_created','create_new_ehf','escalated','jci_accreditation_gap','2026-07-30',null,55000.00,'No EHF since install — reconstructing full history file for accreditation'),
    ('MON-CMC-VEL-14','calibration_records_absent','lost_records','reconstruct_from_backups','in_progress','nabh_finding','2026-07-22',null,18000.00,'Calibration records being reconstructed from backup CMMS server'),
    ('VEN-KIM-HYD-08','missing_service_records','handover_gap_prior_vendor','request_records_from_oem','escalated','cdsco_notifiable','2026-07-28',null,48000.00,'Vendor handover gap — OEM records requested, reconstruction in progress'),
    ('INF-MNP-BLR-11','audit_trail_not_tamper_evident','paper_records_not_digitized','enable_tamper_evident_log','verification_pending','internal_only','2026-07-18',null,9000.00,'Digitized paper log to tamper-evident CMMS — verifying audit trail'),
    ('INF-NAR-BLR-15','ehf_not_maintained','no_ehf_created','create_new_ehf','open','jci_accreditation_gap','2026-08-02',null,30000.00,'Rental fleet — creating per-device history files for accreditation')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.engineer_ehf_audit_r3388 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) EHF verdict distribution
create or replace function public.founder_r3388_ehf_verdict_rollup()
returns table(ehf_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_ehf_audit_r3388)
  select l.ehf_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_ehf_audit_r3388 l
  group by l.ehf_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3388_ehf_verdict_rollup() from public, anon;
grant execute on function public.founder_r3388_ehf_verdict_rollup() to authenticated;

-- 2) Hospital-level EHF completeness scorecard
create or replace function public.founder_r3388_hospital_scorecard()
returns table(
  hospital_name text,
  total_devices bigint,
  complete_ready bigint,
  minor_gaps bigint,
  records_missing bigint,
  not_maintained bigint,
  missing_install bigint,
  calibration_gaps bigint,
  avg_completeness_pct numeric,
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
    count(*) filter (where l.ehf_verdict = 'complete_audit_ready')::bigint,
    count(*) filter (where l.ehf_verdict = 'minor_gaps')::bigint,
    count(*) filter (where l.ehf_verdict = 'records_missing')::bigint,
    count(*) filter (where l.ehf_verdict in ('not_maintained','reconstruct_needed'))::bigint,
    count(*) filter (where l.install_record_present = false)::bigint,
    count(*) filter (where l.calibration_records_current = false)::bigint,
    round(avg(l.completeness_pct), 1),
    round(100.0 * count(*) filter (where l.accreditation_ready = true)::numeric / nullif(count(*),0), 1)
  from public.engineer_ehf_audit_r3388 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3388_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3388_hospital_scorecard() to authenticated;

-- 3) Equipment-type × engineer completeness matrix
create or replace function public.founder_r3388_equipment_engineer_matrix()
returns table(equipment_type text, engineer_name text, devices bigint, accreditation_ready_count bigint, avg_completeness_pct numeric, total_missing_records bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.engineer_name, count(*)::bigint,
    count(*) filter (where l.accreditation_ready = true)::bigint,
    round(avg(l.completeness_pct), 1),
    coalesce(sum(l.missing_records),0)::bigint
  from public.engineer_ehf_audit_r3388 l
  group by l.equipment_type, l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3388_equipment_engineer_matrix() from public, anon;
grant execute on function public.founder_r3388_equipment_engineer_matrix() to authenticated;

-- 4) Daily EHF-update trend
create or replace function public.founder_r3388_daily_update_trend()
returns table(last_updated_date date, devices bigint, complete_ready bigint, records_missing bigint, avg_completeness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.last_updated_date,
    count(*)::bigint,
    count(*) filter (where l.ehf_verdict = 'complete_audit_ready')::bigint,
    count(*) filter (where l.ehf_verdict in ('records_missing','not_maintained','reconstruct_needed'))::bigint,
    round(avg(l.completeness_pct), 1)
  from public.engineer_ehf_audit_r3388 l
  group by l.last_updated_date
  order by l.last_updated_date desc nulls last;
end;
$$;

revoke execute on function public.founder_r3388_daily_update_trend() from public, anon;
grant execute on function public.founder_r3388_daily_update_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3388_capa_status_board()
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
  from public.engineer_ehf_audit_capa_actions_r3388 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3388_capa_status_board() from public, anon;
grant execute on function public.founder_r3388_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3388_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_ehf_audit_capa_actions_r3388)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_ehf_audit_capa_actions_r3388 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3388_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3388_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3388_regulatory_impact_digest()
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
  from public.engineer_ehf_audit_capa_actions_r3388 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3388_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3388_regulatory_impact_digest() to authenticated;

-- 8) High-risk EHF queue (top individual concerns)
create or replace function public.founder_r3388_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  device_code text,
  equipment_type text,
  ehf_verdict text,
  missing_records int,
  completeness_pct numeric,
  accreditation_ready boolean,
  last_updated_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.device_code, l.equipment_type,
    l.ehf_verdict, l.missing_records, l.completeness_pct, l.accreditation_ready,
    l.last_updated_date, l.notes
  from public.engineer_ehf_audit_r3388 l
  where l.ehf_verdict in ('records_missing','not_maintained','reconstruct_needed','minor_gaps')
     or l.accreditation_ready = false
     or l.audit_trail_tamper_evident = false
     or l.install_record_present = false
     or l.calibration_records_current = false
     or l.missing_records > 0
  order by l.completeness_pct asc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3388_high_risk_queue() from public, anon;
grant execute on function public.founder_r3388_high_risk_queue() to authenticated;
