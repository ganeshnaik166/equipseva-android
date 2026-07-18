-- Round 3308: Engineer Equipment Relocation, Re-Install & Re-Commission Tracker
-- Relocation discipline — equipment type × relocation type × downtime × pre-move backup × post-move calibration × electrical-safety test × transport damage × acceptance sign-off × CAPA

-- =============================================================================
-- TABLE 1: engineer_relocation_r3308 — per relocation / recommission job
-- =============================================================================
create table if not exists public.engineer_relocation_r3308 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  job_code text not null,
  equipment_type text not null check (equipment_type in (
    'ct_scanner','mri','patient_monitor_fleet','dialysis','ot_table','lab_analyzer','ventilator'
  )),
  relocation_type text not null check (relocation_type in (
    'intra_ward','inter_department','inter_site','renovation_temp_move','new_site_commissioning'
  )),
  de_install_date date not null,
  recommission_date date,
  downtime_days int not null,
  pre_move_backup_taken boolean not null,
  calibration_post_move_ok boolean not null,
  safety_electrical_test_ok boolean not null,
  damage_during_move text not null check (damage_during_move in (
    'none','minor_cosmetic','functional_damage','lost_accessory'
  )),
  acceptance_signoff boolean not null,
  job_verdict text not null check (job_verdict in (
    'completed_verified','completed_with_issues','in_progress','delayed','damage_escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_relocation_r3308 enable row level security;

create index if not exists idx_engineer_relocation_r3308_org on public.engineer_relocation_r3308(organization_id);
create index if not exists idx_engineer_relocation_r3308_date on public.engineer_relocation_r3308(de_install_date);
create index if not exists idx_engineer_relocation_r3308_verdict on public.engineer_relocation_r3308(job_verdict);

-- =============================================================================
-- TABLE 2: engineer_relocation_capa_actions_r3308 — CAPA & escalation actions
-- =============================================================================
create table if not exists public.engineer_relocation_capa_actions_r3308 (
  id uuid primary key default gen_random_uuid(),
  job_log_id uuid not null references public.engineer_relocation_r3308(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_post_move_failure','electrical_safety_failure','physical_damage','missing_accessory',
    'backup_not_taken','excessive_downtime','acceptance_signoff_pending','documentation_gap','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'improper_packing','transport_shock','reinstall_error','calibration_drift','power_supply_mismatch',
    'accessory_misplaced','vendor_delay','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_equipment','redo_electrical_safety_test','repair_physical_damage','replace_lost_accessory',
    'retake_backup','reinstall_and_retest','reschedule_recommission','retrain_field_engineer',
    'escalate_to_oem','update_documentation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_relocation_capa_actions_r3308 enable row level security;

create index if not exists idx_engineer_relocation_capa_r3308_log on public.engineer_relocation_capa_actions_r3308(job_log_id);
create index if not exists idx_engineer_relocation_capa_r3308_status on public.engineer_relocation_capa_actions_r3308(capa_status);

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

  -- 14 relocation / recommission job rows
  insert into public.engineer_relocation_r3308 (
    organization_id, engineer_name, hospital_name, job_code, equipment_type,
    relocation_type, de_install_date, recommission_date, downtime_days,
    pre_move_backup_taken, calibration_post_move_ok, safety_electrical_test_ok,
    damage_during_move, acceptance_signoff, job_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.jc, q.eqt,
    q.rt, q.did::date, q.rcd::date, q.dtd,
    q.bkp, q.cal, q.est,
    q.dmg, q.sgn, q.jv, q.nt
  from (values
    ('Ramesh Iyer','Apollo Chennai Greams Road','RELOC-APL-3301','ct_scanner',
     'inter_department','2026-07-01','2026-07-03',2,
     true,true,true,'none',true,'completed_verified','128-slice CT moved to new radiology wing — AERB layout cleared, cal passed'),
    ('Suresh Menon','Fortis Gurgaon','RELOC-FRT-3302','patient_monitor_fleet',
     'intra_ward','2026-07-01','2026-07-01',0,
     true,true,true,'none',true,'completed_verified','24-monitor ICU fleet shifted one bay — hot-swap, zero downtime'),
    ('Anil Kumar','Manipal Bengaluru Old Airport Road','RELOC-MNP-3303','mri',
     'inter_site','2026-06-28','2026-07-05',7,
     true,false,true,'minor_cosmetic',false,'completed_with_issues','1.5T MRI trucked to satellite centre — post-move gradient cal off, recheck booked'),
    ('Deepak Sharma','AIIMS Delhi Ansari Nagar','RELOC-AIM-3304','dialysis',
     'renovation_temp_move','2026-06-27','2026-07-02',5,
     true,true,false,'none',false,'completed_with_issues','6 dialysis stations temp-moved for RO room renovation — earth-leakage retest failed on 1 unit'),
    ('Vijay Nair','CMC Vellore','RELOC-CMC-3305','lab_analyzer',
     'inter_department','2026-06-26','2026-06-29',3,
     true,true,true,'none',true,'completed_verified','Biochem analyzer relocated to new central lab — QC passed post-move'),
    ('Karthik Reddy','KIMS Hyderabad','RELOC-KIM-3306','ot_table',
     'intra_ward','2026-06-25','2026-06-25',0,
     false,true,true,'none',true,'completed_with_issues','OT table shifted between theatres — pre-move config backup skipped, flagged'),
    ('Prakash Rao','Yashoda Hyderabad Somajiguda','RELOC-YSH-3307','ventilator',
     'inter_site','2026-06-24','2026-06-27',3,
     true,true,true,'lost_accessory',false,'completed_with_issues','ICU ventilators moved to new tower — one flow-sensor accessory missing on arrival'),
    ('Ramesh Iyer','Apollo Chennai Greams Road','RELOC-APL-3308','ct_scanner',
     'new_site_commissioning','2026-06-20',null,15,
     true,false,false,'functional_damage',false,'damage_escalated','New-site CT install — detector board damaged in transit, OEM engineer escalated'),
    ('Suresh Menon','Fortis Gurgaon','RELOC-FRT-3309','patient_monitor_fleet',
     'inter_department','2026-06-22','2026-06-24',2,
     true,true,true,'none',true,'completed_verified','Telemetry monitors moved to cardiac step-down — coverage verified'),
    ('Anil Kumar','Manipal Bengaluru Old Airport Road','RELOC-MNP-3310','dialysis',
     'inter_site','2026-06-18',null,20,
     true,false,false,'functional_damage',false,'delayed','Dialysis fleet inter-site move delayed — water-treatment tie-in pending, recommission slipped'),
    ('Deepak Sharma','AIIMS Delhi Ansari Nagar','RELOC-AIM-3311','mri',
     'renovation_temp_move','2026-06-15','2026-06-30',15,
     true,true,true,'minor_cosmetic',true,'completed_verified','3T MRI cold-moved and re-ramped after coil-room renovation — helium topped, cal passed'),
    ('Vijay Nair','CMC Vellore','RELOC-CMC-3312','lab_analyzer',
     'intra_ward','2026-06-14','2026-06-15',1,
     true,true,true,'none',true,'completed_verified','Haematology analyzer nudged to adjacent bench — recal quick pass'),
    ('Karthik Reddy','KIMS Hyderabad','RELOC-KIM-3313','ot_table',
     'new_site_commissioning','2026-06-10',null,25,
     false,false,false,'none',false,'in_progress','New OT block commissioning — 4 tables, install ongoing, backups pending'),
    ('Prakash Rao','Yashoda Hyderabad Somajiguda','RELOC-YSH-3314','ventilator',
     'intra_ward','2026-06-12','2026-06-12',0,
     true,true,true,'none',true,'completed_verified','Transport ventilator relocated within ICU — bench test OK')
  ) as q(eng, hosp, jc, eqt, rt, did, rcd, dtd, bkp, cal, est, dmg, sgn, jv, nt);

  -- CAPA seed — attach to specific jobs via job_code
  insert into public.engineer_relocation_capa_actions_r3308 (
    job_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('RELOC-MNP-3303','calibration_post_move_failure','calibration_drift','recalibrate_equipment','in_progress','iso_13485_deviation','2026-07-10',null,22000.00,'MRI gradient cal off after inter-site move — OEM recal scheduled'),
    ('RELOC-AIM-3304','electrical_safety_failure','power_supply_mismatch','redo_electrical_safety_test','closed','nabh_finding','2026-07-04','2026-07-02',8000.00,'Earth-leakage on dialysis unit — retested within limits, closed'),
    ('RELOC-KIM-3306','backup_not_taken','operator_setup_error','retake_backup','verification_pending','internal_only','2026-06-28',null,0.00,'OT table config backup retaken from OEM template — verify next service'),
    ('RELOC-YSH-3307','missing_accessory','accessory_misplaced','replace_lost_accessory','open','internal_only','2026-07-08',null,15000.00,'Ventilator flow-sensor accessory reordered from vendor'),
    ('RELOC-APL-3308','physical_damage','transport_shock','escalate_to_oem','escalated','cdsco_notifiable','2026-07-06',null,480000.00,'CT detector board damaged in transit — OEM RMA and insurance claim raised'),
    ('RELOC-MNP-3310','excessive_downtime','vendor_delay','reschedule_recommission','overdue','patient_safety_alert','2026-06-25',null,55000.00,'Dialysis inter-site recommission overdue — RO tie-in vendor slipped, patients rerouted'),
    ('RELOC-KIM-3313','acceptance_signoff_pending','reinstall_error','reinstall_and_retest','in_progress','nabh_finding','2026-07-12',null,30000.00,'New OT tables install and acceptance in progress')
  ) as q(jc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.engineer_relocation_r3308 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Job verdict distribution
create or replace function public.founder_r3308_job_verdict_rollup()
returns table(job_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_relocation_r3308)
  select l.job_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_relocation_r3308 l
  group by l.job_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3308_job_verdict_rollup() from public, anon;
grant execute on function public.founder_r3308_job_verdict_rollup() to authenticated;

-- 2) Hospital-level relocation scorecard
create or replace function public.founder_r3308_hospital_scorecard()
returns table(
  hospital_name text,
  total_jobs bigint,
  verified bigint,
  with_issues bigint,
  delayed_escalated bigint,
  calibration_fail bigint,
  electrical_fail bigint,
  damage_jobs bigint,
  verified_pct numeric
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
    count(*) filter (where l.job_verdict = 'completed_verified')::bigint,
    count(*) filter (where l.job_verdict = 'completed_with_issues')::bigint,
    count(*) filter (where l.job_verdict in ('delayed','damage_escalated'))::bigint,
    count(*) filter (where l.calibration_post_move_ok = false)::bigint,
    count(*) filter (where l.safety_electrical_test_ok = false)::bigint,
    count(*) filter (where l.damage_during_move in ('minor_cosmetic','functional_damage','lost_accessory'))::bigint,
    round(100.0 * count(*) filter (where l.job_verdict = 'completed_verified')::numeric / nullif(count(*),0), 1)
  from public.engineer_relocation_r3308 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3308_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3308_hospital_scorecard() to authenticated;

-- 3) Equipment type × relocation type matrix
create or replace function public.founder_r3308_equipment_relocation_matrix()
returns table(equipment_type text, relocation_type text, jobs bigint, verified bigint, avg_downtime_days numeric, damage_jobs bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.relocation_type, count(*)::bigint,
    count(*) filter (where l.job_verdict = 'completed_verified')::bigint,
    round(avg(l.downtime_days), 1),
    count(*) filter (where l.damage_during_move in ('minor_cosmetic','functional_damage','lost_accessory'))::bigint
  from public.engineer_relocation_r3308 l
  group by l.equipment_type, l.relocation_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3308_equipment_relocation_matrix() from public, anon;
grant execute on function public.founder_r3308_equipment_relocation_matrix() to authenticated;

-- 4) Daily relocation-job trend (by de-install date)
create or replace function public.founder_r3308_daily_job_trend()
returns table(de_install_date date, jobs bigint, verified bigint, with_issues bigint, delayed_escalated bigint, avg_downtime_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.de_install_date,
    count(*)::bigint,
    count(*) filter (where l.job_verdict = 'completed_verified')::bigint,
    count(*) filter (where l.job_verdict = 'completed_with_issues')::bigint,
    count(*) filter (where l.job_verdict in ('delayed','damage_escalated'))::bigint,
    round(avg(l.downtime_days), 1)
  from public.engineer_relocation_r3308 l
  group by l.de_install_date
  order by l.de_install_date desc;
end;
$$;

revoke execute on function public.founder_r3308_daily_job_trend() from public, anon;
grant execute on function public.founder_r3308_daily_job_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3308_capa_status_board()
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
  from public.engineer_relocation_capa_actions_r3308 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3308_capa_status_board() from public, anon;
grant execute on function public.founder_r3308_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3308_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_relocation_capa_actions_r3308)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_relocation_capa_actions_r3308 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3308_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3308_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3308_regulatory_impact_digest()
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
  from public.engineer_relocation_capa_actions_r3308 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3308_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3308_regulatory_impact_digest() to authenticated;

-- 8) High-risk relocation queue (individual at-risk jobs)
create or replace function public.founder_r3308_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  job_code text,
  equipment_type text,
  de_install_date date,
  job_verdict text,
  damage_during_move text,
  calibration_post_move_ok boolean,
  safety_electrical_test_ok boolean,
  downtime_days int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.job_code, l.equipment_type, l.de_install_date,
    l.job_verdict, l.damage_during_move, l.calibration_post_move_ok, l.safety_electrical_test_ok,
    l.downtime_days, l.notes
  from public.engineer_relocation_r3308 l
  where l.job_verdict in ('completed_with_issues','in_progress','delayed','damage_escalated')
     or l.calibration_post_move_ok = false
     or l.safety_electrical_test_ok = false
     or l.pre_move_backup_taken = false
     or l.acceptance_signoff = false
     or l.damage_during_move in ('functional_damage','lost_accessory')
  order by l.de_install_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3308_high_risk_queue() from public, anon;
grant execute on function public.founder_r3308_high_risk_queue() to authenticated;
