-- Round 3172: Engineer First-Time-Fix-Rate & Repeat-Visit Root-Cause Tracker
-- Field service job log — engineer × equipment category × job outcome (fixed-first/repeat/escalated)
--   × repeat reason × visits × resolution days × verdict + CAPA corrective actions

-- =============================================================================
-- TABLE 1: first_time_fix_r3172 — individual field-service repair jobs
-- =============================================================================
create table if not exists public.first_time_fix_r3172 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  city text not null,
  engineer_name text not null,
  engineer_grade text not null check (engineer_grade in (
    'junior_technician','senior_technician','lead_engineer','oem_specialist'
  )),
  equipment_category text not null check (equipment_category in (
    'ventilator','patient_monitor','infusion_pump','dialysis_machine',
    'ct_scanner','mri_scanner','ultrasound','xray_system',
    'anesthesia_workstation','defibrillator','autoclave_sterilizer','ecg_machine'
  )),
  equipment_model text not null,
  job_code text not null,
  complaint_type text not null check (complaint_type in (
    'no_power','calibration_drift','sensor_failure','software_fault',
    'mechanical_wear','fluid_leak','alarm_malfunction','battery_fault',
    'connectivity_loss','preventive_service'
  )),
  first_visit_date date not null,
  closed_date date,
  job_outcome text not null check (job_outcome in (
    'fixed_first_visit','repeat_visit','escalated','pending'
  )),
  repeat_reason text not null check (repeat_reason in (
    'part_unavailable','misdiagnosis','intermittent_fault','no_fault_found',
    'incomplete_repair','wrong_part_fitted','not_applicable'
  )),
  visits_count int not null,
  resolution_days int,
  labor_hours numeric(6,2),
  job_verdict text not null check (job_verdict in (
    'resolved_confirmed','repeat_open','escalated_oem','awaiting_parts',
    'under_observation','closed_unresolved'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.first_time_fix_r3172 enable row level security;

create index if not exists idx_first_time_fix_r3172_org on public.first_time_fix_r3172(organization_id);
create index if not exists idx_first_time_fix_r3172_date on public.first_time_fix_r3172(first_visit_date);
create index if not exists idx_first_time_fix_r3172_outcome on public.first_time_fix_r3172(job_outcome);

-- =============================================================================
-- TABLE 2: first_time_fix_capa_actions_r3172 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.first_time_fix_capa_actions_r3172 (
  id uuid primary key default gen_random_uuid(),
  fix_log_id uuid not null references public.first_time_fix_r3172(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'repeat_failure','first_visit_miss','parts_supply_gap','diagnostic_skill_gap',
    'documentation_gap','oem_dependency','tooling_shortfall','sla_breach'
  )),
  root_cause text not null check (root_cause in (
    'spares_stockout','inadequate_training','missing_service_manual',
    'faulty_test_equipment','oem_delay','environmental_factor',
    'intermittent_fault_undetected','process_noncompliance','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'stock_critical_spares','retrain_engineer','procure_service_manual',
    'calibrate_test_equipment','escalate_oem_contract','revise_diagnostic_sop',
    'add_remote_monitoring','none_required','second_engineer_shadow'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','sla_penalty','none','internal_only','patient_safety_alert','warranty_claim'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.first_time_fix_capa_actions_r3172 enable row level security;

create index if not exists idx_first_time_fix_capa_r3172_log on public.first_time_fix_capa_actions_r3172(fix_log_id);
create index if not exists idx_first_time_fix_capa_r3172_status on public.first_time_fix_capa_actions_r3172(capa_status);

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

  -- 14 repair-job rows
  insert into public.first_time_fix_r3172 (
    organization_id, hospital_name, city, engineer_name, engineer_grade,
    equipment_category, equipment_model, job_code, complaint_type,
    first_visit_date, closed_date, job_outcome, repeat_reason,
    visits_count, resolution_days, labor_hours, job_verdict, notes
  )
  select v_org_id, q.hosp, q.city, q.eng, q.grade,
    q.cat, q.model, q.jc, q.ct,
    q.fvd::date, q.cd::date, q.jo, q.rr,
    q.vc, q.rd, q.lh, q.jv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Hyderabad','Ravi Kumar','senior_technician',
     'ventilator','Draeger Evita V500','FTF-APL-3001','sensor_failure',
     '2026-07-01','2026-07-01','fixed_first_visit','not_applicable',1,0,3.50,'resolved_confirmed','Flow sensor swapped on first visit'),
    ('Apollo Hyderabad Jubilee Hills','Hyderabad','Ravi Kumar','senior_technician',
     'patient_monitor','Philips IntelliVue MX750','FTF-APL-3002','calibration_drift',
     '2026-07-02','2026-07-02','fixed_first_visit','not_applicable',1,0,1.75,'resolved_confirmed','SpO2 module recalibrated in ward'),
    ('Fortis Bannerghatta Bengaluru','Bengaluru','Anil Menon','junior_technician',
     'infusion_pump','BBraun Infusomat Space','FTF-FRT-3003','mechanical_wear',
     '2026-07-01','2026-07-04','repeat_visit','part_unavailable',3,3,6.00,'repeat_open','Peristaltic mechanism worn — spare delayed'),
    ('Fortis Bannerghatta Bengaluru','Bengaluru','Anil Menon','junior_technician',
     'dialysis_machine','Fresenius 4008S','FTF-FRT-3004','fluid_leak',
     '2026-06-29',null,'repeat_visit','misdiagnosis',2,null,4.25,'under_observation','Leak reappeared — first diagnosis wrong'),
    ('Manipal Whitefield Bengaluru','Bengaluru','Suresh Rao','lead_engineer',
     'ct_scanner','GE Revolution CT','FTF-MNP-3005','software_fault',
     '2026-06-30',null,'escalated','not_applicable',1,null,2.00,'escalated_oem','Recon software crash — escalated to GE OEM'),
    ('Manipal Whitefield Bengaluru','Bengaluru','Suresh Rao','lead_engineer',
     'ultrasound','Philips EPIQ 7','FTF-MNP-3006','connectivity_loss',
     '2026-06-30','2026-06-30','fixed_first_visit','not_applicable',1,0,1.25,'resolved_confirmed','DICOM cable reseated on first visit'),
    ('AIIMS New Delhi Ansari Nagar','New Delhi','Pooja Sharma','senior_technician',
     'mri_scanner','Siemens Magnetom Vida','FTF-AIM-3007','alarm_malfunction',
     '2026-06-28',null,'escalated','not_applicable',2,null,5.50,'awaiting_parts','Helium compressor alarm — OEM part awaited'),
    ('AIIMS New Delhi Ansari Nagar','New Delhi','Pooja Sharma','senior_technician',
     'anesthesia_workstation','Draeger Perseus A500','FTF-AIM-3008','no_power',
     '2026-06-27','2026-06-27','fixed_first_visit','not_applicable',1,0,2.75,'resolved_confirmed','PSU fuse replaced on first visit'),
    ('KIMS Secunderabad','Secunderabad','Manish Gupta','junior_technician',
     'defibrillator','Zoll R Series','FTF-KIM-3009','battery_fault',
     '2026-06-29','2026-07-02','repeat_visit','intermittent_fault',2,3,3.00,'repeat_open','Battery pack intermittently drops charge'),
    ('KIMS Secunderabad','Secunderabad','Manish Gupta','junior_technician',
     'ecg_machine','GE MAC 2000','FTF-KIM-3010','sensor_failure',
     '2026-06-29',null,'repeat_visit','no_fault_found',3,null,4.00,'under_observation','No-fault-found twice — lead artefact suspected'),
    ('Care Hospitals Banjara Hills','Hyderabad','Kavita Reddy','senior_technician',
     'autoclave_sterilizer','Getinge HS6606','FTF-CAR-3011','preventive_service',
     '2026-06-29','2026-06-29','fixed_first_visit','not_applicable',1,0,2.50,'resolved_confirmed','Quarterly PM completed same day'),
    ('Yashoda Somajiguda Hyderabad','Hyderabad','Ravi Kumar','senior_technician',
     'xray_system','Siemens Multix Impact','FTF-YSH-3012','calibration_drift',
     '2026-06-28','2026-07-01','repeat_visit','wrong_part_fitted',2,3,3.75,'repeat_open','Wrong collimator module fitted first time'),
    ('St John''s Bengaluru','Bengaluru','Suresh Rao','lead_engineer',
     'patient_monitor','Mindray BeneVision N22','FTF-STJ-3013','software_fault',
     '2026-06-27','2026-06-27','fixed_first_visit','not_applicable',1,0,1.50,'resolved_confirmed','Firmware reflash on first visit'),
    ('Rainbow Children''s Hyderabad','Hyderabad','Kavita Reddy','senior_technician',
     'infusion_pump','BBraun Perfusor Space','FTF-RBW-3014','alarm_malfunction',
     '2026-06-26',null,'escalated','incomplete_repair',2,null,4.50,'closed_unresolved','Occlusion alarm persists — unit retired')
  ) as q(hosp, city, eng, grade, cat, model, jc, ct, fvd, cd, jo, rr, vc, rd, lh, jv, nt);

  -- CAPA seed — attach to specific jobs by job_code
  insert into public.first_time_fix_capa_actions_r3172 (
    fix_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cs, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('FTF-FRT-3003','parts_supply_gap','spares_stockout','stock_critical_spares',
     'in_progress','sla_penalty','2026-07-08',null,18000.00,'Peristaltic spare stockout — add to critical list'),
    ('FTF-FRT-3004','diagnostic_skill_gap','inadequate_training','retrain_engineer',
     'open','sla_penalty','2026-07-10',null,8000.00,'Misdiagnosis — retrain on leak isolation'),
    ('FTF-KIM-3009','repeat_failure','intermittent_fault_undetected','add_remote_monitoring',
     'verification_pending','patient_safety_alert','2026-07-09',null,22000.00,'Add battery telemetry to catch intermittent drop'),
    ('FTF-KIM-3010','first_visit_miss','faulty_test_equipment','calibrate_test_equipment',
     'escalated','internal_only','2026-07-05',null,6500.00,'NFF caused by drifting ECG simulator'),
    ('FTF-YSH-3012','documentation_gap','missing_service_manual','procure_service_manual',
     'closed','none','2026-07-04','2026-07-03',12000.00,'Wrong part — service manual procured, closed'),
    ('FTF-RBW-3014','oem_dependency','oem_delay','escalate_oem_contract',
     'overdue','warranty_claim','2026-06-30',null,30000.00,'Occlusion alarm — OEM warranty claim overdue')
  ) as q(jc_key, fc, rc, ca, cs, ri, tcd, acd, cost, nt)
  join public.first_time_fix_r3172 e
    on e.organization_id = v_org_id and e.job_code = q.jc_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Job verdict / status distribution
create or replace function public.founder_r3172_verdict_rollup()
returns table(job_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.first_time_fix_r3172)
  select l.job_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.first_time_fix_r3172 l
  group by l.job_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3172_verdict_rollup() from public, anon;
grant execute on function public.founder_r3172_verdict_rollup() to authenticated;

-- 2) Hospital first-time-fix scorecard
create or replace function public.founder_r3172_hospital_scorecard()
returns table(
  hospital_name text,
  total_jobs bigint,
  fixed_first bigint,
  repeat_jobs bigint,
  escalated bigint,
  ftf_pct numeric,
  avg_resolution_days numeric
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
    count(*) filter (where l.job_outcome = 'fixed_first_visit')::bigint,
    count(*) filter (where l.job_outcome = 'repeat_visit')::bigint,
    count(*) filter (where l.job_outcome = 'escalated')::bigint,
    round(100.0 * count(*) filter (where l.job_outcome = 'fixed_first_visit')::numeric / nullif(count(*),0), 1),
    round(avg(l.resolution_days), 1)
  from public.first_time_fix_r3172 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3172_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3172_hospital_scorecard() to authenticated;

-- 3) Equipment category × complaint-type matrix
create or replace function public.founder_r3172_category_matrix()
returns table(
  equipment_category text,
  complaint_type text,
  jobs bigint,
  fixed_first bigint,
  ftf_pct numeric,
  avg_labor_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_category, l.complaint_type, count(*)::bigint,
    count(*) filter (where l.job_outcome = 'fixed_first_visit')::bigint,
    round(100.0 * count(*) filter (where l.job_outcome = 'fixed_first_visit')::numeric / nullif(count(*),0), 1),
    round(avg(l.labor_hours), 2)
  from public.first_time_fix_r3172 l
  group by l.equipment_category, l.complaint_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3172_category_matrix() from public, anon;
grant execute on function public.founder_r3172_category_matrix() to authenticated;

-- 4) Daily first-visit trend
create or replace function public.founder_r3172_daily_trend()
returns table(
  first_visit_date date,
  jobs bigint,
  fixed_first bigint,
  repeat_jobs bigint,
  escalated bigint,
  avg_visits numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.first_visit_date,
    count(*)::bigint,
    count(*) filter (where l.job_outcome = 'fixed_first_visit')::bigint,
    count(*) filter (where l.job_outcome = 'repeat_visit')::bigint,
    count(*) filter (where l.job_outcome = 'escalated')::bigint,
    round(avg(l.visits_count), 2)
  from public.first_time_fix_r3172 l
  group by l.first_visit_date
  order by l.first_visit_date desc;
end;
$$;

revoke execute on function public.founder_r3172_daily_trend() from public, anon;
grant execute on function public.founder_r3172_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3172_capa_status_board()
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
  from public.first_time_fix_capa_actions_r3172 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3172_capa_status_board() from public, anon;
grant execute on function public.founder_r3172_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3172_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.first_time_fix_capa_actions_r3172)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.first_time_fix_capa_actions_r3172 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3172_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3172_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3172_regulatory_impact_digest()
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
  from public.first_time_fix_capa_actions_r3172 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3172_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3172_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority repair queue
create or replace function public.founder_r3172_priority_queue()
returns table(
  hospital_name text,
  engineer_name text,
  equipment_category text,
  job_code text,
  first_visit_date date,
  job_outcome text,
  repeat_reason text,
  visits_count int,
  job_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.equipment_category, l.job_code,
    l.first_visit_date, l.job_outcome, l.repeat_reason, l.visits_count, l.job_verdict, l.notes
  from public.first_time_fix_r3172 l
  where l.job_outcome in ('repeat_visit','escalated')
     or l.job_verdict in ('repeat_open','escalated_oem','awaiting_parts','under_observation','closed_unresolved')
     or l.visits_count >= 2
  order by l.visits_count desc, l.first_visit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3172_priority_queue() from public, anon;
grant execute on function public.founder_r3172_priority_queue() to authenticated;
