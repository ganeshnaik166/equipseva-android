-- Round 3340: Engineer Installation-Commissioning FAT/SAT Acceptance-Test Tracker
-- Per commissioning job — equipment type × commissioning stage (FAT/SAT/IQ-OQ-PQ) × checklist pass × deviations × utilities/calibration/training/signoff × verdict + CAPA closure

-- =============================================================================
-- TABLE 1: commissioning_acceptance_r3340 — per-job commissioning / acceptance test
-- =============================================================================
create table if not exists public.commissioning_acceptance_r3340 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  job_code text not null,
  equipment_type text not null check (equipment_type in (
    'ct_scanner','mri','cath_lab','linac','lab_analyzer','dialysis_fleet','patient_monitoring'
  )),
  commissioning_stage text not null check (commissioning_stage in (
    'fat','site_readiness','installation','sat','iq_oq_pq','handover'
  )),
  scheduled_date date not null,
  completed_date date,
  checklist_items_total int not null,
  checklist_items_passed int not null,
  deviations_found int not null,
  critical_deviation_open boolean not null,
  utilities_ready boolean not null,
  calibration_done boolean not null,
  training_delivered boolean not null,
  customer_signoff boolean not null,
  commissioning_verdict text not null check (commissioning_verdict in (
    'accepted_go_live','conditional_go_live','deviations_open','delayed','rejected'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.commissioning_acceptance_r3340 enable row level security;

create index if not exists idx_commissioning_acceptance_r3340_org on public.commissioning_acceptance_r3340(organization_id);
create index if not exists idx_commissioning_acceptance_r3340_date on public.commissioning_acceptance_r3340(scheduled_date);
create index if not exists idx_commissioning_acceptance_r3340_verdict on public.commissioning_acceptance_r3340(commissioning_verdict);

-- =============================================================================
-- TABLE 2: commissioning_acceptance_capa_actions_r3340 — deviation-closure / CAPA actions
-- =============================================================================
create table if not exists public.commissioning_acceptance_capa_actions_r3340 (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.commissioning_acceptance_r3340(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'checklist_item_failure','critical_deviation','utilities_not_ready','calibration_incomplete',
    'training_pending','signoff_pending','fat_shortfall','sat_shortfall','iq_oq_pq_deviation','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'oem_delay','site_civil_incomplete','hvac_shielding_gap','equipment_defect',
    'calibration_backlog','staff_unavailable','spare_part_shortage','software_validation_pending',
    'pending_investigation','vendor_documentation_missing'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_oem_support','complete_site_readiness','fix_utilities','recalibrate_and_verify',
    'schedule_staff_training','obtain_customer_signoff','replace_defective_unit','rerun_acceptance_test',
    'escalate_to_project_lead','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_notifiable','iso_13485_deviation',
    'internal_only','patient_safety_alert','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.commissioning_acceptance_capa_actions_r3340 enable row level security;

create index if not exists idx_commissioning_capa_r3340_job on public.commissioning_acceptance_capa_actions_r3340(job_id);
create index if not exists idx_commissioning_capa_r3340_status on public.commissioning_acceptance_capa_actions_r3340(capa_status);

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

  -- 14 commissioning-job rows
  insert into public.commissioning_acceptance_r3340 (
    organization_id, engineer_name, hospital_name, job_code, equipment_type,
    commissioning_stage, scheduled_date, completed_date,
    checklist_items_total, checklist_items_passed, deviations_found,
    critical_deviation_open, utilities_ready, calibration_done,
    training_delivered, customer_signoff, commissioning_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.jc, q.etype,
    q.stage, q.sd::date, q.cd::date,
    q.cit::int, q.cip::int, q.dev::int,
    q.crit, q.util, q.cal,
    q.train, q.sign, q.verdict, q.nt
  from (values
    ('Arun Prakash','Apollo Chennai Greams Road','COM-APL-2401','ct_scanner',
     'sat','2026-07-02','2026-07-03',64,64,0,
     false,true,true,true,true,'accepted_go_live','128-slice CT SAT clean — signed off for go-live'),
    ('Vivek Menon','Fortis Gurgaon','COM-FRT-2402','cath_lab',
     'iq_oq_pq','2026-07-01','2026-07-02',88,84,4,
     false,true,true,true,true,'conditional_go_live','IQ/OQ/PQ passed with 4 minor deviations — conditional go-live'),
    ('Suresh Nair','Manipal Bengaluru Old Airport Road','COM-MNP-2403','mri',
     'installation','2026-06-30',null,52,40,8,
     true,true,false,false,false,'deviations_open','3T MRI chiller interlock deviation open — install paused'),
    ('Rajesh Iyer','AIIMS Delhi Ansari Nagar','COM-AIM-2404','linac',
     'fat','2026-06-29',null,40,30,10,
     true,false,false,false,false,'delayed','Linac FAT at OEM slipped — beam data package incomplete'),
    ('Deepa Reddy','CMC Vellore','COM-CMC-2405','lab_analyzer',
     'sat','2026-06-28','2026-06-28',48,48,0,
     false,true,true,true,true,'accepted_go_live','Biochemistry analyzer SAT passed — QC within limits'),
    ('Anil Kumar','KIMS Hyderabad Secunderabad','COM-KIM-2406','dialysis_fleet',
     'iq_oq_pq','2026-06-27','2026-06-28',72,69,3,
     false,true,true,true,false,'conditional_go_live','12-station dialysis fleet — water AAMI pass, biomed-head signoff pending'),
    ('Arun Prakash','Apollo Chennai Greams Road','COM-APL-2407','patient_monitoring',
     'handover','2026-06-26','2026-06-26',36,36,0,
     false,true,true,true,true,'accepted_go_live','ICU central station handover complete — staff trained'),
    ('Farhan Qureshi','Fortis Mulund Mumbai','COM-FMU-2408','mri',
     'sat','2026-06-25',null,52,33,14,
     true,true,false,false,false,'rejected','1.5T MRI SAT failed — SNR below spec, unit rejected pending OEM rework'),
    ('Nikhil Joshi','Narayana Health Bengaluru','COM-NAR-2409','ct_scanner',
     'site_readiness','2026-06-24',null,30,18,6,
     false,false,false,false,false,'delayed','Site-readiness fail — HVAC and lead shielding pending civil works'),
    ('Rajesh Iyer','Medanta Gurgaon','COM-MED-2410','linac',
     'iq_oq_pq','2026-06-23',null,96,88,8,
     true,true,true,false,false,'deviations_open','Linac OQ MLC positioning deviation open — TG-142 recheck scheduled'),
    ('Vivek Menon','Max Saket Delhi','COM-MAX-2411','cath_lab',
     'sat','2026-06-22','2026-06-23',80,77,3,
     false,true,true,true,true,'conditional_go_live','Cath-lab SAT — DAP meter cal deviation, conditional go-live with recheck'),
    ('Lakshmi Iyer','Yashoda Hyderabad Somajiguda','COM-YSH-2412','lab_analyzer',
     'installation','2026-06-21','2026-06-22',44,44,0,
     false,true,true,true,true,'accepted_go_live','Hematology analyzer install + IQ complete — accepted'),
    ('Joseph Thomas','Aster Medcity Kochi','COM-AST-2413','dialysis_fleet',
     'handover','2026-06-20','2026-06-20',60,60,0,
     false,true,true,true,true,'accepted_go_live','Dialysis fleet handover — endotoxin and training closed out'),
    ('Priya Menon','Ruby Hall Clinic Pune','COM-RUB-2414','patient_monitoring',
     'fat','2026-06-19',null,28,22,6,
     false,true,false,false,false,'delayed','Monitoring FAT slipped — vendor firmware validation pending'),
    ('Anil Kumar','KIMS Hyderabad Secunderabad','COM-KIM-2415','ct_scanner',
     'installation','2026-06-18','2026-06-19',56,54,2,
     false,true,true,true,true,'conditional_go_live','CT install complete — 2 cosmetic deviations, conditional acceptance')
  ) as q(eng, hosp, jc, etype, stage, sd, cd, cit, cip, dev, crit, util, cal, train, sign, verdict, nt);

  -- 7 CAPA / deviation-closure action rows — attach to specific jobs by job_code
  insert into public.commissioning_acceptance_capa_actions_r3340 (
    job_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('COM-MNP-2403','critical_deviation','equipment_defect','expedite_oem_support',
     'in_progress','patient_safety_alert','2026-07-08',null,85000.00,'MRI chiller interlock — OEM field engineer dispatched'),
    ('COM-AIM-2404','fat_shortfall','oem_delay','expedite_oem_support',
     'escalated','aerb_notifiable','2026-07-10',null,120000.00,'Linac FAT beam data incomplete — escalated to OEM and AERB liaison'),
    ('COM-FMU-2408','sat_shortfall','equipment_defect','replace_defective_unit',
     'open','cdsco_notifiable','2026-07-12',null,250000.00,'1.5T MRI SNR below spec — OEM rework/replacement under warranty'),
    ('COM-NAR-2409','utilities_not_ready','site_civil_incomplete','complete_site_readiness',
     'in_progress','internal_only','2026-07-09',null,40000.00,'HVAC and lead shielding pending — civil contractor mobilized'),
    ('COM-MED-2410','iq_oq_pq_deviation','software_validation_pending','rerun_acceptance_test',
     'verification_pending','aerb_notifiable','2026-07-07',null,60000.00,'MLC positioning TG-142 recheck — rerun OQ after software patch'),
    ('COM-MAX-2411','calibration_incomplete','calibration_backlog','recalibrate_and_verify',
     'closed','nabh_finding','2026-06-28','2026-06-27',15000.00,'DAP meter recalibrated and verified — closed'),
    ('COM-RUB-2414','fat_shortfall','software_validation_pending','rerun_acceptance_test',
     'overdue','internal_only','2026-06-30',null,8000.00,'Vendor firmware validation overdue — chased with OEM')
  ) as q(jc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.commissioning_acceptance_r3340 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Commissioning verdict distribution
create or replace function public.founder_r3340_verdict_rollup()
returns table(commissioning_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.commissioning_acceptance_r3340)
  select l.commissioning_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.commissioning_acceptance_r3340 l
  group by l.commissioning_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3340_verdict_rollup() from public, anon;
grant execute on function public.founder_r3340_verdict_rollup() to authenticated;

-- 2) Hospital-level commissioning scorecard
create or replace function public.founder_r3340_hospital_scorecard()
returns table(
  hospital_name text,
  total_jobs bigint,
  accepted bigint,
  conditional bigint,
  not_accepted bigint,
  critical_open bigint,
  total_deviations bigint,
  avg_checklist_pass_pct numeric,
  accepted_pct numeric
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
    count(*) filter (where l.commissioning_verdict = 'accepted_go_live')::bigint,
    count(*) filter (where l.commissioning_verdict = 'conditional_go_live')::bigint,
    count(*) filter (where l.commissioning_verdict in ('deviations_open','delayed','rejected'))::bigint,
    count(*) filter (where l.critical_deviation_open)::bigint,
    coalesce(sum(l.deviations_found),0)::bigint,
    round(avg(100.0 * l.checklist_items_passed::numeric / nullif(l.checklist_items_total,0)), 1),
    round(100.0 * count(*) filter (where l.commissioning_verdict = 'accepted_go_live')::numeric / nullif(count(*),0), 1)
  from public.commissioning_acceptance_r3340 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3340_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3340_hospital_scorecard() to authenticated;

-- 3) Equipment type × commissioning stage matrix
create or replace function public.founder_r3340_equipment_stage_matrix()
returns table(equipment_type text, commissioning_stage text, jobs bigint, accepted bigint, avg_checklist_pass_pct numeric, total_deviations bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.commissioning_stage, count(*)::bigint,
    count(*) filter (where l.commissioning_verdict = 'accepted_go_live')::bigint,
    round(avg(100.0 * l.checklist_items_passed::numeric / nullif(l.checklist_items_total,0)), 1),
    coalesce(sum(l.deviations_found),0)::bigint
  from public.commissioning_acceptance_r3340 l
  group by l.equipment_type, l.commissioning_stage
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3340_equipment_stage_matrix() from public, anon;
grant execute on function public.founder_r3340_equipment_stage_matrix() to authenticated;

-- 4) Daily commissioning trend
create or replace function public.founder_r3340_daily_commissioning_trend()
returns table(scheduled_date date, jobs bigint, accepted bigint, not_accepted bigint, critical_open bigint, total_deviations bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scheduled_date,
    count(*)::bigint,
    count(*) filter (where l.commissioning_verdict = 'accepted_go_live')::bigint,
    count(*) filter (where l.commissioning_verdict in ('deviations_open','delayed','rejected'))::bigint,
    count(*) filter (where l.critical_deviation_open)::bigint,
    coalesce(sum(l.deviations_found),0)::bigint
  from public.commissioning_acceptance_r3340 l
  group by l.scheduled_date
  order by l.scheduled_date desc;
end;
$$;

revoke execute on function public.founder_r3340_daily_commissioning_trend() from public, anon;
grant execute on function public.founder_r3340_daily_commissioning_trend() to authenticated;

-- 5) CAPA / deviation-closure status board
create or replace function public.founder_r3340_capa_status_board()
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
  from public.commissioning_acceptance_capa_actions_r3340 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3340_capa_status_board() from public, anon;
grant execute on function public.founder_r3340_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3340_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.commissioning_acceptance_capa_actions_r3340)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.commissioning_acceptance_capa_actions_r3340 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3340_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3340_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3340_regulatory_impact_digest()
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
  from public.commissioning_acceptance_capa_actions_r3340 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3340_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3340_regulatory_impact_digest() to authenticated;

-- 8) High-risk commissioning queue
create or replace function public.founder_r3340_high_risk_queue()
returns table(
  hospital_name text,
  job_code text,
  engineer_name text,
  equipment_type text,
  commissioning_stage text,
  scheduled_date date,
  commissioning_verdict text,
  deviations_found integer,
  critical_open text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.job_code, l.engineer_name, l.equipment_type,
    l.commissioning_stage, l.scheduled_date, l.commissioning_verdict,
    l.deviations_found,
    case when l.critical_deviation_open then 'yes' else 'no' end,
    l.notes
  from public.commissioning_acceptance_r3340 l
  where l.commissioning_verdict in ('conditional_go_live','deviations_open','delayed','rejected')
     or l.critical_deviation_open
     or not l.utilities_ready
     or l.deviations_found > 0
  order by l.scheduled_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3340_high_risk_queue() from public, anon;
grant execute on function public.founder_r3340_high_risk_queue() to authenticated;
