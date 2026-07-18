-- Round 3244: Engineer Device Firmware / Software Update Rollout Tracker
-- Field-engineer discipline — device family × advisory ref × version jump × criticality × backup × post-update verification × downtime × rollout verdict × CAPA

-- =============================================================================
-- TABLE 1: firmware_update_rollout_r3244 — individual firmware/software update jobs
-- =============================================================================
create table if not exists public.firmware_update_rollout_r3244 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  device_family text not null check (device_family in (
    'patient_monitor','ventilator','infusion_pump','defibrillator','imaging_workstation','lab_analyzer'
  )),
  device_code text not null,
  advisory_ref text not null,
  from_version text not null,
  to_version text not null,
  criticality text not null check (criticality in (
    'security_critical','safety_mandatory','recommended','optional'
  )),
  scheduled_date date not null,
  applied_date date,
  backup_taken boolean not null,
  post_update_verification text not null check (post_update_verification in (
    'full_test_pass','smoke_test_pass','failed_rolled_back','pending'
  )),
  downtime_minutes int,
  rollout_verdict text not null check (rollout_verdict in (
    'completed_on_time','completed_late','failed','deferred_with_approval','overdue'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.firmware_update_rollout_r3244 enable row level security;

create index if not exists idx_fw_rollout_r3244_org on public.firmware_update_rollout_r3244(organization_id);
create index if not exists idx_fw_rollout_r3244_date on public.firmware_update_rollout_r3244(scheduled_date);
create index if not exists idx_fw_rollout_r3244_verdict on public.firmware_update_rollout_r3244(rollout_verdict);

-- =============================================================================
-- TABLE 2: firmware_update_rollout_capa_actions_r3244 — CAPA for failed/overdue rollouts
-- =============================================================================
create table if not exists public.firmware_update_rollout_capa_actions_r3244 (
  id uuid primary key default gen_random_uuid(),
  rollout_id uuid not null references public.firmware_update_rollout_r3244(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'update_failed_bricked','rollback_performed','backup_not_taken','window_overrun',
    'advisory_deadline_missed','verification_incomplete','vendor_package_defect'
  )),
  root_cause text not null check (root_cause in (
    'vendor_installer_bug','network_interruption','insufficient_downtime_window','device_storage_full',
    'dependency_version_mismatch','engineer_process_lapse','hospital_scheduling_conflict','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'vendor_escalation_patch','reschedule_with_longer_window','restore_from_backup_retry',
    'pre_update_checklist_enforced','staging_bench_test_first','engineer_retraining',
    'defer_with_risk_acceptance','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','cybersecurity_advisory','patient_safety_alert','iso_13485_deviation','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.firmware_update_rollout_capa_actions_r3244 enable row level security;

create index if not exists idx_fw_capa_r3244_rollout on public.firmware_update_rollout_capa_actions_r3244(rollout_id);
create index if not exists idx_fw_capa_r3244_status on public.firmware_update_rollout_capa_actions_r3244(capa_status);

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

  -- 14 firmware/software update rollout rows
  insert into public.firmware_update_rollout_r3244 (
    organization_id, engineer_name, hospital_name, device_family, device_code,
    advisory_ref, from_version, to_version, criticality,
    scheduled_date, applied_date, backup_taken, post_update_verification,
    downtime_minutes, rollout_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.fam, q.dev,
    q.adv, q.fromv, q.tov, q.crit,
    q.sd::date, q.ad::date, q.bk, q.puv,
    q.dtm, q.rv, q.nt
  from (values
    ('Rajesh Kumar','Apollo Chennai Greams Road','patient_monitor','PM-APL-2201','FSN-GE-2026-114','3.1.2','3.2.0','security_critical',
     '2026-07-01','2026-07-01',true,'full_test_pass',45,'completed_on_time','CARESCAPE cybersecurity patch applied within window'),
    ('Rajesh Kumar','Apollo Chennai Greams Road','infusion_pump','IP-APL-2214','ADV-BBRAUN-2026-08','2.4.1','2.5.0','safety_mandatory',
     '2026-07-01','2026-07-03',true,'full_test_pass',30,'completed_late','Ward occupancy pushed slot by two days'),
    ('Priya Sharma','Fortis Gurgaon Sector 44','ventilator','VT-FRT-1102','FSN-DRAEGER-2026-21','5.0.3','5.1.1','safety_mandatory',
     '2026-07-02','2026-07-02',true,'smoke_test_pass',90,'completed_on_time','Full test deferred to biomed bench at next PM visit'),
    ('Priya Sharma','Fortis Gurgaon Sector 44','defibrillator','DF-FRT-1120','ADV-ZOLL-2026-05','11.2','11.3','security_critical',
     '2026-07-03','2026-07-03',false,'full_test_pass',25,'completed_on_time','Backup skipped — config export tool unavailable, flagged'),
    ('Amit Patel','Manipal Whitefield Bengaluru','imaging_workstation','IW-MNP-3308','CSA-PHILIPS-2026-112','4.7.2','4.8.0','security_critical',
     '2026-06-30','2026-06-30',true,'failed_rolled_back',240,'failed','Installer hung at 70% — restored from backup, vendor ticket open'),
    ('Amit Patel','Manipal Whitefield Bengaluru','lab_analyzer','LA-MNP-3312','FSN-ROCHE-2026-33','8.1.0','8.1.4','recommended',
     '2026-07-04','2026-07-04',true,'full_test_pass',60,'completed_on_time','QC controls rerun post-update — all in range'),
    ('Sneha Reddy','AIIMS New Delhi Ansari Nagar','patient_monitor','PM-AIM-4405','FSN-PHILIPS-2026-77','2.8.9','3.0.1','safety_mandatory',
     '2026-06-28',null,true,'pending',null,'overdue','ICU could not release monitor — advisory deadline at risk'),
    ('Sneha Reddy','AIIMS New Delhi Ansari Nagar','ventilator','VT-AIM-4410','FSN-GETINGE-2026-14','6.2.0','6.3.0','recommended',
     '2026-07-10',null,true,'pending',null,'deferred_with_approval','Deferred to August shutdown with biomed HOD sign-off'),
    ('Vikram Singh','CMC Vellore Main Campus','infusion_pump','IP-CMC-5521','ADV-FRESENIUS-2026-19','3.0.2','3.1.0','security_critical',
     '2026-07-05','2026-07-05',true,'full_test_pass',35,'completed_on_time','Fleet batch 1 of 3 — remaining pumps next week'),
    ('Vikram Singh','CMC Vellore Main Campus','defibrillator','DF-CMC-5533','FSN-STRYKER-2026-41','3.2.1','3.3.0','safety_mandatory',
     '2026-07-02','2026-07-06',true,'smoke_test_pass',40,'completed_late','Spare-unit swap delayed slot; full discharge test pending'),
    ('Kavitha Iyer','KIMS Secunderabad','lab_analyzer','LA-KIM-6608','CSA-SIEMENS-2026-58','2.2.0','2.2.5','security_critical',
     '2026-07-01','2026-07-01',true,'failed_rolled_back',180,'failed','Middleware handshake broke post-update — rolled back same shift'),
    ('Kavitha Iyer','KIMS Secunderabad','imaging_workstation','IW-KIM-6615','CSA-GE-2026-90','5.5.1','5.6.0','recommended',
     '2026-07-06','2026-07-06',true,'full_test_pass',55,'completed_on_time','DICOM push verified to PACS after update'),
    ('Arun Nair','Max Saket New Delhi','patient_monitor','PM-MAX-7702','FSN-MINDRAY-2026-26','1.9.4','2.0.0','optional',
     '2026-07-08',null,false,'pending',null,'overdue','Optional UI update but slot missed twice — no backup plan filed'),
    ('Mohammed Faisal','Narayana Health City Bengaluru','ventilator','VT-NAR-8809','FSN-HAMILTON-2026-09','4.4.2','4.5.0','safety_mandatory',
     '2026-07-07','2026-07-07',true,'full_test_pass',75,'completed_on_time','Post-update ventilation test on lung simulator passed')
  ) as q(eng, hosp, fam, dev, adv, fromv, tov, crit, sd, ad, bk, puv, dtm, rv, nt);

  -- CAPA seed — attach to specific rollout jobs via device code
  insert into public.firmware_update_rollout_capa_actions_r3244 (
    rollout_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, e.organization_id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IW-MNP-3308','update_failed_bricked','vendor_installer_bug','vendor_escalation_patch','escalated','cybersecurity_advisory','2026-07-12',null,35000.00,'Philips ticket SR-88214 — hotfix installer promised this week'),
    ('LA-KIM-6608','rollback_performed','dependency_version_mismatch','staging_bench_test_first','in_progress','internal_only','2026-07-15',null,22000.00,'Middleware vendor validating LIS driver against 2.2.5'),
    ('PM-AIM-4405','advisory_deadline_missed','hospital_scheduling_conflict','reschedule_with_longer_window','open','patient_safety_alert','2026-07-20',null,0.00,'Night-shift window requested from ICU in-charge'),
    ('DF-FRT-1120','backup_not_taken','engineer_process_lapse','pre_update_checklist_enforced','closed','iso_13485_deviation','2026-07-08','2026-07-06',0.00,'Checklist gate added to app — backup now a mandatory field'),
    ('PM-MAX-7702','advisory_deadline_missed','insufficient_downtime_window','defer_with_risk_acceptance','verification_pending','none','2026-07-18',null,0.00,'Risk-acceptance memo with biomed head pending signature'),
    ('DF-CMC-5533','verification_incomplete','insufficient_downtime_window','reschedule_with_longer_window','open','internal_only','2026-07-14',null,5000.00,'Full discharge-energy test booked on bench for Saturday'),
    ('IP-APL-2214','window_overrun','hospital_scheduling_conflict','reschedule_with_longer_window','overdue','none','2026-07-04',null,0.00,'Late-completion review not yet filed — chased with engineer')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.firmware_update_rollout_r3244 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Rollout verdict distribution
create or replace function public.founder_r3244_rollout_verdict_rollup()
returns table(rollout_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.firmware_update_rollout_r3244)
  select l.rollout_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.firmware_update_rollout_r3244 l
  group by l.rollout_verdict
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3244_rollout_verdict_rollup() from public, anon;
grant execute on function public.founder_r3244_rollout_verdict_rollup() to authenticated;

-- 2) Engineer rollout scorecard
create or replace function public.founder_r3244_engineer_scorecard()
returns table(
  engineer_name text,
  total_jobs bigint,
  on_time bigint,
  late bigint,
  failed bigint,
  overdue_or_deferred bigint,
  backup_missed bigint,
  avg_downtime_minutes numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.rollout_verdict = 'completed_on_time')::bigint,
    count(*) filter (where l.rollout_verdict = 'completed_late')::bigint,
    count(*) filter (where l.rollout_verdict = 'failed')::bigint,
    count(*) filter (where l.rollout_verdict in ('overdue','deferred_with_approval'))::bigint,
    count(*) filter (where l.backup_taken = false)::bigint,
    round(avg(l.downtime_minutes)::numeric, 0),
    round(100.0 * count(*) filter (where l.rollout_verdict = 'completed_on_time')::numeric / nullif(count(*),0), 1)
  from public.firmware_update_rollout_r3244 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3244_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3244_engineer_scorecard() to authenticated;

-- 3) Device family × criticality matrix
create or replace function public.founder_r3244_family_criticality_matrix()
returns table(device_family text, criticality text, jobs bigint, completed bigint, failed bigint, avg_downtime_minutes numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_family, l.criticality, count(*)::bigint,
    count(*) filter (where l.rollout_verdict in ('completed_on_time','completed_late'))::bigint,
    count(*) filter (where l.rollout_verdict = 'failed')::bigint,
    round(avg(l.downtime_minutes)::numeric, 0)
  from public.firmware_update_rollout_r3244 l
  group by l.device_family, l.criticality
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3244_family_criticality_matrix() from public, anon;
grant execute on function public.founder_r3244_family_criticality_matrix() to authenticated;

-- 4) Daily rollout trend
create or replace function public.founder_r3244_daily_rollout_trend()
returns table(scheduled_date date, jobs bigint, completed bigint, failed bigint, security_critical_jobs bigint, backup_missed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scheduled_date,
    count(*)::bigint,
    count(*) filter (where l.rollout_verdict in ('completed_on_time','completed_late'))::bigint,
    count(*) filter (where l.rollout_verdict = 'failed')::bigint,
    count(*) filter (where l.criticality = 'security_critical')::bigint,
    count(*) filter (where l.backup_taken = false)::bigint
  from public.firmware_update_rollout_r3244 l
  group by l.scheduled_date
  order by l.scheduled_date desc;
end;
$$;

revoke all on function public.founder_r3244_daily_rollout_trend() from public, anon;
grant execute on function public.founder_r3244_daily_rollout_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3244_capa_status_board()
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
  from public.firmware_update_rollout_capa_actions_r3244 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3244_capa_status_board() from public, anon;
grant execute on function public.founder_r3244_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3244_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.firmware_update_rollout_capa_actions_r3244)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.firmware_update_rollout_capa_actions_r3244 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3244_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3244_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3244_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.firmware_update_rollout_capa_actions_r3244 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3244_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3244_regulatory_impact_digest() to authenticated;

-- 8) High-risk rollout queue (failed / overdue / unverified / no-backup jobs)
create or replace function public.founder_r3244_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  device_family text,
  device_code text,
  advisory_ref text,
  criticality text,
  scheduled_date date,
  rollout_verdict text,
  post_update_verification text,
  backup_taken boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.device_family, l.device_code,
    l.advisory_ref, l.criticality, l.scheduled_date, l.rollout_verdict,
    l.post_update_verification, l.backup_taken, l.notes
  from public.firmware_update_rollout_r3244 l
  where l.rollout_verdict in ('failed','overdue','deferred_with_approval','completed_late')
     or l.post_update_verification in ('failed_rolled_back','pending')
     or l.backup_taken = false
  order by l.scheduled_date desc, l.hospital_name;
end;
$$;

revoke all on function public.founder_r3244_high_risk_queue() from public, anon;
grant execute on function public.founder_r3244_high_risk_queue() to authenticated;
