-- Round 3180: Engineer Training-Hours, Certification-CEU & Skill-Refresh Compliance Tracker
-- Training compliance log — training type × skill area × hours × CEU earned/required × completion/expiry × compliance status × CAPA

-- =============================================================================
-- TABLE 1: engineer_training_r3180 — individual engineer training records
-- =============================================================================
create table if not exists public.engineer_training_r3180 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  training_record_code text not null,
  hospital_name text not null,
  engineer_name text not null,
  engineer_id uuid references public.engineers(id) on delete set null,
  training_type text not null check (training_type in (
    'oem_certification','safety_training','soft_skill','refresher_course',
    'regulatory_compliance','clinical_application','install_base_specialization'
  )),
  skill_area text not null check (skill_area in (
    'imaging_radiology','anesthesia_ventilators','dialysis','sterilization_cssd',
    'patient_monitoring','laboratory_diagnostics','ot_infrastructure','electrical_safety'
  )),
  training_provider text not null,
  delivery_mode text not null check (delivery_mode in (
    'onsite_oem','online_self_paced','classroom','simulation_lab','on_the_job'
  )),
  training_hours numeric(5,1) not null,
  ceu_earned numeric(5,2) not null,
  required_ceu numeric(5,2) not null,
  completion_date date,
  certificate_expiry_date date,
  assessment_score_pct numeric(5,2),
  compliance_status text not null check (compliance_status in (
    'compliant','expiring_soon','expired','ceu_shortfall',
    'training_overdue','waiver_granted','pending_verification'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_training_r3180 enable row level security;

create index if not exists idx_engineer_training_r3180_org on public.engineer_training_r3180(organization_id);
create index if not exists idx_engineer_training_r3180_status on public.engineer_training_r3180(compliance_status);
create index if not exists idx_engineer_training_r3180_expiry on public.engineer_training_r3180(certificate_expiry_date);

-- =============================================================================
-- TABLE 2: engineer_training_capa_actions_r3180 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.engineer_training_capa_actions_r3180 (
  id uuid primary key default gen_random_uuid(),
  training_id uuid not null references public.engineer_training_r3180(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ceu_shortfall','certification_expired','refresher_overdue','failed_assessment',
    'missing_oem_certificate','safety_training_lapsed','skill_gap_identified','audit_documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'training_budget_freeze','oem_slot_unavailable','engineer_on_extended_leave',
    'scheduling_conflict','portal_record_missing','manager_oversight',
    'high_attrition_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'book_oem_training_slot','enroll_online_refresher','schedule_reassessment',
    'upload_missing_certificate','assign_mentor_shadowing','budget_escalation_to_founder',
    'temporary_scope_restriction','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','aerb_notifiable','iso_13485_deviation','oem_warranty_risk','internal_only','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_training_capa_actions_r3180 enable row level security;

create index if not exists idx_engineer_training_capa_r3180_training on public.engineer_training_capa_actions_r3180(training_id);
create index if not exists idx_engineer_training_capa_r3180_status on public.engineer_training_capa_actions_r3180(capa_status);

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

  -- 14 training records
  insert into public.engineer_training_r3180 (
    organization_id, training_record_code, hospital_name, engineer_name,
    training_type, skill_area, training_provider, delivery_mode,
    training_hours, ceu_earned, required_ceu,
    completion_date, certificate_expiry_date, assessment_score_pct,
    compliance_status, notes
  )
  select v_org_id, q.rec, q.hosp, q.eng,
    q.tt, q.sk, q.prov, q.dm,
    q.hrs, q.ceu, q.req,
    q.cd::date, q.exp::date, q.score,
    q.cst, q.nt
  from (values
    ('TRN-3180-01','Apollo Hyderabad Jubilee Hills','Ravi Kumar','oem_certification','imaging_radiology','GE Healthcare Academy','onsite_oem',
     40.0,4.00,4.00,'2026-05-12','2028-05-11',88.50,'compliant','GE CT scanner service certification renewed'),
    ('TRN-3180-02','Apollo Hyderabad Jubilee Hills','Sneha Reddy','safety_training','electrical_safety','TUV SUD India','classroom',
     16.0,1.50,2.00,'2026-04-20','2027-04-19',91.00,'ceu_shortfall','IEC 62353 electrical safety — 0.5 CEU short of annual requirement'),
    ('TRN-3180-03','Fortis Bannerghatta Bengaluru','Arjun Nair','oem_certification','anesthesia_ventilators','Drager Service School','onsite_oem',
     56.0,5.50,5.00,'2026-03-08','2027-03-07',94.25,'compliant','Drager Fabius / Savina factory training completed'),
    ('TRN-3180-04','Fortis Bannerghatta Bengaluru','Meera Iyer','refresher_course','dialysis','Fresenius Medical Care','online_self_paced',
     12.0,1.00,3.00,'2025-06-15','2026-06-14',76.00,'expired','Certification lapsed 30+ days — refresher not rebooked'),
    ('TRN-3180-05','Manipal Whitefield Bengaluru','Vikram Shetty','regulatory_compliance','sterilization_cssd','NABH Academy','classroom',
     24.0,2.50,2.50,'2026-06-02','2028-06-01',85.75,'compliant','CSSD sterilization compliance workshop'),
    ('TRN-3180-06','Manipal Whitefield Bengaluru','Divya Prasad','soft_skill','patient_monitoring','EquipSeva L&D','simulation_lab',
     8.0,0.50,1.00,'2026-06-28',null,68.00,'pending_verification','Customer-communication assessment retake pending'),
    ('TRN-3180-07','AIIMS New Delhi Ansari Nagar','Rahul Verma','oem_certification','imaging_radiology','Siemens Healthineers Academy','onsite_oem',
     64.0,6.00,6.00,'2026-01-18','2027-01-17',89.00,'expiring_soon','MRI service cert expires within 6 months — renewal slot needed'),
    ('TRN-3180-08','AIIMS New Delhi Ansari Nagar','Kavita Joshi','safety_training','ot_infrastructure','AERB Approved Trainer','classroom',
     20.0,2.00,2.00,'2026-05-25','2029-05-24',92.50,'compliant','Radiation safety officer refresher'),
    ('TRN-3180-09','KIMS Secunderabad','Suresh Babu','refresher_course','laboratory_diagnostics','Roche Diagnostics Academy','online_self_paced',
     10.0,0.00,2.00,null,'2026-07-30',null,'training_overdue','Analyzer refresher not started — due window closing'),
    ('TRN-3180-10','KIMS Secunderabad','Anita Rao','clinical_application','dialysis','B Braun Avitum Training','simulation_lab',
     32.0,3.00,3.00,'2026-06-10','2028-06-09',87.25,'compliant','Dialysis machine clinical-application module'),
    ('TRN-3180-11','Care Hospitals Banjara Hills','Farhan Ali','oem_certification','patient_monitoring','Philips Healthcare University','onsite_oem',
     48.0,4.50,4.00,'2026-02-14','2027-02-13',90.00,'expiring_soon','Patient monitor service cert — renewal due in Q3'),
    ('TRN-3180-12','Yashoda Somajiguda Hyderabad','Priya Menon','install_base_specialization','imaging_radiology','Canon Medical Systems','onsite_oem',
     36.0,3.50,3.50,'2026-04-05','2028-04-04',83.50,'compliant','Cath-lab install-base specialization'),
    ('TRN-3180-13','St John''s Bengaluru','Deepak Sharma','safety_training','electrical_safety','TUV SUD India','classroom',
     0.0,0.00,2.00,null,null,null,'training_overdue','No-show for scheduled batch — rebooking required'),
    ('TRN-3180-14','Rainbow Children''s Hyderabad','Lakshmi Narayanan','soft_skill','patient_monitoring','EquipSeva L&D','on_the_job',
     6.0,0.50,1.00,'2026-06-20','2027-06-19',72.00,'waiver_granted','Partial waiver — NICU posting workload')
  ) as q(rec, hosp, eng, tt, sk, prov, dm, hrs, ceu, req, cd, exp, score, cst, nt);

  -- CAPA seed — attach to specific training records
  insert into public.engineer_training_capa_actions_r3180 (
    training_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('TRN-3180-04','certification_expired','oem_slot_unavailable','book_oem_training_slot','2026-07-25',null,'in_progress','oem_warranty_risk',85000.00,'Fresenius slot waitlisted — Mumbai batch in August'),
    ('TRN-3180-02','ceu_shortfall','scheduling_conflict','enroll_online_refresher','2026-08-10',null,'open','nabh_finding',6500.00,'0.5 CEU gap — online module assigned'),
    ('TRN-3180-09','refresher_overdue','manager_oversight','enroll_online_refresher','2026-07-20',null,'overdue','iso_13485_deviation',4200.00,'Reminder escalated to zonal manager'),
    ('TRN-3180-13','safety_training_lapsed','engineer_on_extended_leave','temporary_scope_restriction','2026-08-01',null,'escalated','nabh_finding',0.00,'Engineer barred from solo electrical work until retrained'),
    ('TRN-3180-06','failed_assessment','pending_investigation','schedule_reassessment','2026-07-15','2026-07-14','closed','internal_only',1500.00,'Retake passed at 81 pct'),
    ('TRN-3180-07','missing_oem_certificate','portal_record_missing','upload_missing_certificate','2026-07-22',null,'verification_pending','oem_warranty_risk',0.00,'Siemens cert PDF requested from academy portal')
  ) as q(rec, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.engineer_training_r3180 e
    on e.organization_id = v_org_id and e.training_record_code = q.rec;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3180_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_training_r3180)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_training_r3180 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3180_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3180_compliance_status_rollup() to authenticated;

-- 2) Hospital-level training compliance scorecard
create or replace function public.founder_r3180_hospital_scorecard()
returns table(
  hospital_name text,
  total_records bigint,
  compliant bigint,
  expiring_soon bigint,
  expired bigint,
  ceu_shortfall bigint,
  total_training_hours numeric,
  avg_score_pct numeric,
  compliance_pct numeric
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
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'expiring_soon')::bigint,
    count(*) filter (where l.compliance_status = 'expired')::bigint,
    count(*) filter (where l.compliance_status = 'ceu_shortfall')::bigint,
    coalesce(sum(l.training_hours),0)::numeric,
    round(avg(l.assessment_score_pct)::numeric, 1),
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.engineer_training_r3180 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3180_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3180_hospital_scorecard() to authenticated;

-- 3) Training type × skill area matrix
create or replace function public.founder_r3180_type_skill_matrix()
returns table(training_type text, skill_area text, records bigint, total_hours numeric, total_ceu_earned numeric, ceu_gap numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.training_type, l.skill_area, count(*)::bigint,
    coalesce(sum(l.training_hours),0)::numeric,
    coalesce(sum(l.ceu_earned),0)::numeric,
    coalesce(sum(l.required_ceu - l.ceu_earned),0)::numeric
  from public.engineer_training_r3180 l
  group by l.training_type, l.skill_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3180_type_skill_matrix() from public, anon;
grant execute on function public.founder_r3180_type_skill_matrix() to authenticated;

-- 4) Monthly completion trend
create or replace function public.founder_r3180_monthly_completion_trend()
returns table(completion_month text, records bigint, total_hours numeric, total_ceu numeric, compliant bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.completion_date), 'YYYY-MM'),
    count(*)::bigint,
    coalesce(sum(l.training_hours),0)::numeric,
    coalesce(sum(l.ceu_earned),0)::numeric,
    count(*) filter (where l.compliance_status = 'compliant')::bigint
  from public.engineer_training_r3180 l
  where l.completion_date is not null
  group by date_trunc('month', l.completion_date)
  order by date_trunc('month', l.completion_date) desc;
end;
$$;

revoke execute on function public.founder_r3180_monthly_completion_trend() from public, anon;
grant execute on function public.founder_r3180_monthly_completion_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3180_capa_status_board()
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
  from public.engineer_training_capa_actions_r3180 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3180_capa_status_board() from public, anon;
grant execute on function public.founder_r3180_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3180_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_training_capa_actions_r3180)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_training_capa_actions_r3180 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3180_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3180_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3180_regulatory_impact_digest()
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
  from public.engineer_training_capa_actions_r3180 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3180_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3180_regulatory_impact_digest() to authenticated;

-- 8) High-risk training records queue
create or replace function public.founder_r3180_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  training_type text,
  skill_area text,
  compliance_status text,
  ceu_earned numeric,
  required_ceu numeric,
  certificate_expiry_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.training_type, l.skill_area,
    l.compliance_status, l.ceu_earned, l.required_ceu, l.certificate_expiry_date, l.notes
  from public.engineer_training_r3180 l
  where l.compliance_status in ('expired','ceu_shortfall','training_overdue','expiring_soon','pending_verification')
     or l.ceu_earned < l.required_ceu
  order by l.certificate_expiry_date asc nulls first, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3180_high_risk_queue() from public, anon;
grant execute on function public.founder_r3180_high_risk_queue() to authenticated;
