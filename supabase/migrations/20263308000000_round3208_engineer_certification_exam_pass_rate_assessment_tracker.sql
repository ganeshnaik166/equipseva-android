-- Round 3208: Engineer Certification-Exam Pass-Rate & Skill-Assessment Outcome Tracker
-- Cert exam log — exam type × skill domain × attempt × score × proctor verdict × retake pipeline × CAPA

-- =============================================================================
-- TABLE 1: cert_exam_r3208 — individual certification-exam attempts
-- =============================================================================
create table if not exists public.cert_exam_r3208 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  exam_ref text not null,
  exam_type text not null check (exam_type in (
    'tier_upgrade','oem_cert','safety','refresher','specialty_modality','onboarding_baseline'
  )),
  skill_domain text not null check (skill_domain in (
    'imaging_ct_mri','ventilators_icu','dialysis_ro_plant','ot_equipment_sterilizers',
    'lab_analyzers','patient_monitoring','endoscopy','infusion_pumps'
  )),
  attempt_number int not null,
  exam_date date not null,
  score_pct numeric(5,2) not null,
  pass_mark_pct numeric(5,2) not null default 70.00,
  passed boolean not null,
  weak_areas text,
  delivery_mode text not null check (delivery_mode in (
    'online_proctored','onsite_practical','oem_center','simulation_lab'
  )),
  retake_due_date date,
  proctor_verdict text not null check (proctor_verdict in (
    'clean_pass','pass_with_observations','fail_knowledge_gap',
    'fail_practical_gap','malpractice_flagged','absent_no_show'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cert_exam_r3208 enable row level security;

create index if not exists idx_cert_exam_r3208_org on public.cert_exam_r3208(organization_id);
create index if not exists idx_cert_exam_r3208_date on public.cert_exam_r3208(exam_date);
create index if not exists idx_cert_exam_r3208_verdict on public.cert_exam_r3208(proctor_verdict);

-- =============================================================================
-- TABLE 2: cert_exam_capa_actions_r3208 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.cert_exam_capa_actions_r3208 (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.cert_exam_r3208(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'knowledge_gap','practical_skill_gap','safety_protocol_breach','documentation_error',
    'malpractice_suspected','repeat_failure','proctoring_irregularity','expired_certification'
  )),
  root_cause text not null check (root_cause in (
    'insufficient_training_hours','outdated_study_material','no_hands_on_exposure',
    'language_barrier','exam_anxiety','mentor_unavailable','scheduling_conflict',
    'pending_investigation','oem_curriculum_change'
  )),
  corrective_action text not null check (corrective_action in (
    'assign_mentor_shadowing','enroll_refresher_course','schedule_oem_bootcamp',
    'provide_regional_language_material','extend_practice_lab_hours',
    'mandate_retake_within_30_days','suspend_field_assignments','escalate_to_hr','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_license_risk','oem_authorization_risk','nabh_finding','customer_sla_risk','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cert_exam_capa_actions_r3208 enable row level security;

create index if not exists idx_cert_exam_capa_r3208_exam on public.cert_exam_capa_actions_r3208(exam_id);
create index if not exists idx_cert_exam_capa_r3208_status on public.cert_exam_capa_actions_r3208(capa_status);

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

  -- 14 exam-attempt rows
  insert into public.cert_exam_r3208 (
    organization_id, hospital_name, engineer_name, exam_ref,
    exam_type, skill_domain, attempt_number, exam_date,
    score_pct, pass_mark_pct, passed, weak_areas,
    delivery_mode, retake_due_date, proctor_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.ref,
    q.et, q.sd, q.att, q.ed::date,
    q.score, q.passmark, q.passed, q.weak,
    q.dm, q.rd::date, q.pv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','EX-3208-001','tier_upgrade','imaging_ct_mri',1,'2026-07-10',
     84.50,70.00,true,'CT tube arc troubleshooting','online_proctored',null,'clean_pass','Tier-2 to Tier-3 upgrade cleared first attempt'),
    ('Apollo Hyderabad Jubilee Hills','Ravi Kumar','EX-3208-002','oem_cert','imaging_ct_mri',1,'2026-07-12',
     91.00,75.00,true,'None noted','oem_center',null,'clean_pass','GE Healthcare CT service certification — badge issued'),
    ('Fortis Bannerghatta Bengaluru','Sneha Patil','EX-3208-003','safety','patient_monitoring',1,'2026-07-11',
     58.00,70.00,false,'Loose ECG lead fault isolation; IEC 60601 leakage limits','online_proctored','2026-08-10','fail_knowledge_gap','Electrical safety theory below cutoff'),
    ('Fortis Bannerghatta Bengaluru','Sneha Patil','EX-3208-004','safety','patient_monitoring',2,'2026-07-15',
     73.50,70.00,true,'Slow on leakage current calculations','online_proctored',null,'pass_with_observations','Retake cleared after refresher module'),
    ('Manipal Whitefield Bengaluru','Arjun Nair','EX-3208-005','tier_upgrade','ventilators_icu',1,'2026-07-09',
     66.00,70.00,false,'PEEP valve calibration; O2 sensor drift compensation','onsite_practical','2026-08-08','fail_practical_gap','Practical station timed out on vent calibration'),
    ('Manipal Whitefield Bengaluru','Arjun Nair','EX-3208-006','refresher','infusion_pumps',1,'2026-07-14',
     88.00,60.00,true,'None','simulation_lab',null,'clean_pass','Annual refresher — syringe pump occlusion drills'),
    ('AIIMS New Delhi Ansari Nagar','Meena Joshi','EX-3208-007','oem_cert','dialysis_ro_plant',2,'2026-07-08',
     79.25,75.00,true,'RO membrane replacement sequence','oem_center',null,'pass_with_observations','Fresenius dialysis cert cleared on second attempt'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','EX-3208-008','tier_upgrade','endoscopy',3,'2026-07-13',
     62.50,70.00,false,'Scope leak testing; light-guide alignment','onsite_practical','2026-08-12','fail_practical_gap','Third attempt failed — mentor escalation raised'),
    ('KIMS Secunderabad','Farhan Ali','EX-3208-009','safety','lab_analyzers',1,'2026-07-07',
     0.00,70.00,false,'Did not appear','online_proctored','2026-07-28','absent_no_show','No-show; slot lapsed without cancellation'),
    ('KIMS Secunderabad','Farhan Ali','EX-3208-010','refresher','lab_analyzers',1,'2026-07-16',
     71.00,60.00,true,'Reagent probe alignment','simulation_lab',null,'pass_with_observations','Refresher cleared after rescheduling'),
    ('Care Hospitals Banjara Hills','Divya Reddy','EX-3208-011','oem_cert','patient_monitoring',1,'2026-07-12',
     45.00,75.00,false,'Telemetry pairing; alarm limit configuration','oem_center','2026-08-11','malpractice_flagged','Second device seen on proctor camera — under inquiry'),
    ('Yashoda Somajiguda Hyderabad','Kiran Rao','EX-3208-012','tier_upgrade','ot_equipment_sterilizers',1,'2026-07-10',
     82.00,70.00,true,'Bowie-Dick interpretation edge cases','onsite_practical',null,'clean_pass','Sterilizer tier upgrade cleared'),
    ('St John''s Bengaluru','Anita George','EX-3208-013','refresher','imaging_ct_mri',2,'2026-07-11',
     69.00,70.00,false,'MRI quench procedure; cryogen safety','online_proctored','2026-08-09','fail_knowledge_gap','One mark below cutoff — bootcamp scheduled'),
    ('Rainbow Children''s Hyderabad','Suresh Babu','EX-3208-014','onboarding_baseline','infusion_pumps',1,'2026-07-15',
     76.50,65.00,true,'Pediatric dosing profiles need review','simulation_lab',null,'pass_with_observations','New-joiner baseline assessment')
  ) as q(hosp, eng, ref, et, sd, att, ed, score, passmark, passed, weak, dm, rd, pv, nt);

  -- CAPA seed — attach to specific exams via exam_ref
  insert into public.cert_exam_capa_actions_r3208 (
    exam_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('EX-3208-003','knowledge_gap','outdated_study_material','enroll_refresher_course','2026-08-05',null,'in_progress','customer_sla_risk',8500.00,'IEC 60601 study pack refreshed; retake booked'),
    ('EX-3208-005','practical_skill_gap','no_hands_on_exposure','extend_practice_lab_hours','2026-08-06',null,'open','oem_authorization_risk',12000.00,'Ventilator bench slots reserved three evenings a week'),
    ('EX-3208-008','repeat_failure','mentor_unavailable','assign_mentor_shadowing','2026-08-10',null,'escalated','customer_sla_risk',18000.00,'Third attempt failed — senior endoscopy mentor assigned'),
    ('EX-3208-009','documentation_error','scheduling_conflict','mandate_retake_within_30_days','2026-07-25',null,'overdue','internal_only',0.00,'No-show unreported for five days — attendance process fixed'),
    ('EX-3208-011','malpractice_suspected','pending_investigation','suspend_field_assignments','2026-08-01',null,'verification_pending','oem_authorization_risk',0.00,'Field assignments frozen pending malpractice inquiry'),
    ('EX-3208-013','knowledge_gap','insufficient_training_hours','schedule_oem_bootcamp','2026-07-30','2026-07-16','closed','aerb_license_risk',22000.00,'MRI cryogen-safety bootcamp completed; retake scheduled')
  ) as q(ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.cert_exam_r3208 e
    on e.organization_id = v_org_id and e.exam_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Proctor verdict distribution
create or replace function public.founder_r3208_verdict_rollup()
returns table(proctor_verdict text, exams bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cert_exam_r3208)
  select l.proctor_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cert_exam_r3208 l
  group by l.proctor_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3208_verdict_rollup() from public, anon;
grant execute on function public.founder_r3208_verdict_rollup() to authenticated;

-- 2) Hospital-level pass-rate scorecard
create or replace function public.founder_r3208_hospital_scorecard()
returns table(
  hospital_name text,
  total_exams bigint,
  passed_exams bigint,
  failed_exams bigint,
  malpractice_flags bigint,
  no_shows bigint,
  avg_score_pct numeric,
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
    count(*) filter (where l.passed)::bigint,
    count(*) filter (where not l.passed)::bigint,
    count(*) filter (where l.proctor_verdict = 'malpractice_flagged')::bigint,
    count(*) filter (where l.proctor_verdict = 'absent_no_show')::bigint,
    round(avg(l.score_pct), 1),
    round(100.0 * count(*) filter (where l.passed)::numeric / nullif(count(*),0), 1)
  from public.cert_exam_r3208 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3208_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3208_hospital_scorecard() to authenticated;

-- 3) Exam type × skill domain matrix
create or replace function public.founder_r3208_exam_type_matrix()
returns table(exam_type text, skill_domain text, exams bigint, passed_exams bigint, avg_score_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.exam_type, l.skill_domain, count(*)::bigint,
    count(*) filter (where l.passed)::bigint,
    round(avg(l.score_pct), 1)
  from public.cert_exam_r3208 l
  group by l.exam_type, l.skill_domain
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3208_exam_type_matrix() from public, anon;
grant execute on function public.founder_r3208_exam_type_matrix() to authenticated;

-- 4) Daily exam-outcome trend
create or replace function public.founder_r3208_daily_trend()
returns table(exam_date date, exams bigint, passed_exams bigint, failed_exams bigint, avg_score_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.exam_date,
    count(*)::bigint,
    count(*) filter (where l.passed)::bigint,
    count(*) filter (where not l.passed)::bigint,
    round(avg(l.score_pct), 1)
  from public.cert_exam_r3208 l
  group by l.exam_date
  order by l.exam_date desc;
end;
$$;

revoke execute on function public.founder_r3208_daily_trend() from public, anon;
grant execute on function public.founder_r3208_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3208_capa_status_board()
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
  from public.cert_exam_capa_actions_r3208 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3208_capa_status_board() from public, anon;
grant execute on function public.founder_r3208_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3208_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cert_exam_capa_actions_r3208)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cert_exam_capa_actions_r3208 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3208_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3208_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3208_regulatory_impact_digest()
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
  from public.cert_exam_capa_actions_r3208 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3208_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3208_regulatory_impact_digest() to authenticated;

-- 8) High-risk engineers queue (fails, malpractice, no-shows, 3rd attempts)
create or replace function public.founder_r3208_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  exam_ref text,
  exam_date date,
  exam_type text,
  attempt_number int,
  score_pct numeric,
  proctor_verdict text,
  retake_due_date date,
  weak_areas text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.exam_ref, l.exam_date,
    l.exam_type, l.attempt_number, l.score_pct::numeric, l.proctor_verdict, l.retake_due_date, l.weak_areas
  from public.cert_exam_r3208 l
  where not l.passed
     or l.proctor_verdict in ('malpractice_flagged','absent_no_show')
     or l.attempt_number >= 3
  order by l.exam_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3208_high_risk_queue() from public, anon;
grant execute on function public.founder_r3208_high_risk_queue() to authenticated;
