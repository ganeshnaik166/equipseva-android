-- Round 3300: Engineer Customer-Site HSE Induction & Permit-to-Work (PTW) Compliance Tracker
-- Field-service safety — work category × site induction × PTW obtained × PPE × method statement × safety-officer signoff × area isolation × near-miss × CAPA

-- =============================================================================
-- TABLE 1: site_hse_ptw_r3300 — per site-visit HSE induction + PTW compliance record
-- =============================================================================
create table if not exists public.site_hse_ptw_r3300 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  job_code text not null,
  visit_date date not null,
  work_category text not null check (work_category in (
    'electrical_work','hot_work','work_at_height','confined_space','general_service','radiation_area'
  )),
  site_induction_valid boolean not null,
  ptw_required boolean not null,
  ptw_obtained boolean not null,
  ppe_compliant boolean not null,
  method_statement_available boolean not null,
  hospital_safety_officer_signoff boolean not null,
  area_isolation_confirmed boolean not null,
  incident_free boolean not null,
  near_miss_reported int not null default 0,
  compliance_verdict text not null check (compliance_verdict in (
    'fully_compliant','minor_gap','permit_missing','stop_work','incident_occurred'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.site_hse_ptw_r3300 enable row level security;

create index if not exists idx_site_hse_ptw_r3300_org on public.site_hse_ptw_r3300(organization_id);
create index if not exists idx_site_hse_ptw_r3300_date on public.site_hse_ptw_r3300(visit_date);
create index if not exists idx_site_hse_ptw_r3300_verdict on public.site_hse_ptw_r3300(compliance_verdict);

-- =============================================================================
-- TABLE 2: site_hse_ptw_capa_actions_r3300 — corrective/training CAPA actions
-- =============================================================================
create table if not exists public.site_hse_ptw_capa_actions_r3300 (
  id uuid primary key default gen_random_uuid(),
  visit_log_id uuid not null references public.site_hse_ptw_r3300(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'induction_expired','permit_not_obtained','ppe_noncompliance','method_statement_missing',
    'safety_officer_signoff_missing','isolation_not_confirmed','near_miss_event','incident_event','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'induction_not_scheduled','permit_process_delay','ppe_stock_shortage','documentation_gap',
    'communication_breakdown','engineer_training_gap','hospital_process_gap','time_pressure',
    'pending_investigation','supervisor_oversight_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'reschedule_site_induction','enforce_permit_signoff','issue_ppe_kit','complete_method_statement',
    'obtain_safety_officer_signoff','verify_isolation_lockout','retrain_engineer','revise_sop',
    'stop_work_until_compliant','escalate_to_hospital_ehs','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','factories_act_notifiable','none','internal_only','iso_45001_deviation','worker_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.site_hse_ptw_capa_actions_r3300 enable row level security;

create index if not exists idx_site_hse_ptw_capa_r3300_log on public.site_hse_ptw_capa_actions_r3300(visit_log_id);
create index if not exists idx_site_hse_ptw_capa_r3300_org on public.site_hse_ptw_capa_actions_r3300(organization_id);
create index if not exists idx_site_hse_ptw_capa_r3300_status on public.site_hse_ptw_capa_actions_r3300(capa_status);

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

  -- 14 site-visit HSE/PTW compliance rows
  insert into public.site_hse_ptw_r3300 (
    organization_id, engineer_name, hospital_name, job_code, visit_date, work_category,
    site_induction_valid, ptw_required, ptw_obtained, ppe_compliant, method_statement_available,
    hospital_safety_officer_signoff, area_isolation_confirmed, incident_free, near_miss_reported,
    compliance_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.job, q.vdate::date, q.cat,
    q.induct, q.ptwreq, q.ptwobt, q.ppe, q.method,
    q.signoff, q.isolation, q.incfree, q.nearmiss,
    q.verdict, q.nt
  from (values
    ('Rajesh Kumar','Apollo Chennai Greams Road','JOB-APL-3301','2026-07-02','general_service',
     true, false, false, true, true, true, true, true, 0,
     'fully_compliant','Routine PM — induction current, no PTW needed, all PPE worn'),
    ('Suresh Nair','Apollo Chennai Greams Road','JOB-APL-3302','2026-07-02','electrical_work',
     true, true, true, true, true, true, true, true, 0,
     'fully_compliant','HT panel PM — electrical PTW obtained, LOTO isolation confirmed'),
    ('Amit Patel','Fortis Gurgaon','JOB-FRT-3303','2026-07-01','hot_work',
     true, true, true, true, false, true, true, true, 1,
     'minor_gap','Hot-work permit obtained but method statement not on file — 1 near-miss (spark near O2 line)'),
    ('Priya Sharma','Fortis Gurgaon','JOB-FRT-3304','2026-07-01','work_at_height',
     true, true, false, true, true, false, true, true, 0,
     'permit_missing','Height work started without signed PTW and safety-officer signoff — work paused'),
    ('Vikram Reddy','Manipal Bengaluru Old Airport Road','JOB-MNP-3305','2026-06-30','confined_space',
     false, true, false, false, false, false, false, true, 0,
     'stop_work','Confined-space entry attempted with expired induction, no permit, no gas test — STOP WORK issued'),
    ('Karthik Iyer','Manipal Bengaluru Old Airport Road','JOB-MNP-3306','2026-06-30','electrical_work',
     true, true, true, false, true, true, true, false, 2,
     'incident_occurred','Minor arc-flash — engineer gloves not arc-rated; first-aid given, 2 near-misses logged prior'),
    ('Manoj Gupta','AIIMS Delhi Ansari Nagar','JOB-AIM-3307','2026-06-29','radiation_area',
     true, true, true, true, true, true, true, true, 0,
     'fully_compliant','CT gantry service in radiation area — RSO clearance and dosimeter check complete'),
    ('Deepak Verma','AIIMS Delhi Ansari Nagar','JOB-AIM-3308','2026-06-29','general_service',
     true, false, false, true, true, true, true, true, 0,
     'fully_compliant','Biomed PM in ward — standard induction valid, no permit required'),
    ('Anil Menon','CMC Vellore','JOB-CMC-3309','2026-06-28','hot_work',
     true, true, true, false, true, true, true, true, 1,
     'minor_gap','Welding on chiller line — fire watch present but engineer face-shield missing; 1 near-miss'),
    ('Sanjay Rao','CMC Vellore','JOB-CMC-3310','2026-06-28','work_at_height',
     true, true, false, true, true, true, false, true, 0,
     'permit_missing','Rooftop AHU work — PTW lapsed mid-shift, isolation not re-confirmed; rescheduled'),
    ('Ravi Krishnan','KIMS Hyderabad','JOB-KIM-3311','2026-06-27','confined_space',
     true, true, true, true, true, true, true, true, 0,
     'fully_compliant','UST tank inspection — gas test, standby man, and rescue plan verified'),
    ('Farhan Sheikh','KIMS Hyderabad','JOB-KIM-3312','2026-06-27','electrical_work',
     true, true, true, true, false, true, true, true, 1,
     'minor_gap','HT room service — method statement verbal only, not documented; near-miss on adjacent live bus'),
    ('Naveen Joshi','Narayana Health Bengaluru','JOB-NAR-3313','2026-06-26','radiation_area',
     false, true, false, true, true, false, true, true, 0,
     'stop_work','Cath-lab tube swap — site induction expired and no RSO permit; work halted pending induction'),
    ('Prakash Desai','Medanta Gurgaon','JOB-MDT-3314','2026-06-26','general_service',
     true, false, false, true, true, true, true, false, 3,
     'incident_occurred','Trip-and-fall in plant room — wet floor not barricaded; minor injury, 3 near-misses this month')
  ) as q(eng, hosp, job, vdate, cat, induct, ptwreq, ptwobt, ppe, method, signoff, isolation, incfree, nearmiss, verdict, nt);

  -- CAPA seed — attach to specific visits via job_code
  insert into public.site_hse_ptw_capa_actions_r3300 (
    visit_log_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('JOB-FRT-3304','permit_not_obtained','permit_process_delay','enforce_permit_signoff','open','nabh_finding','2026-07-08',null,8000.00,'Height-work PTW workflow retrained; awaiting re-audit signoff'),
    ('JOB-MNP-3305','induction_expired','induction_not_scheduled','reschedule_site_induction','escalated','factories_act_notifiable','2026-07-05',null,15000.00,'Confined-space stop-work escalated to hospital EHS; induction rebooked'),
    ('JOB-MNP-3306','incident_event','ppe_stock_shortage','issue_ppe_kit','in_progress','worker_safety_alert','2026-07-04',null,22000.00,'Arc-rated glove kits issued to field team; incident report filed'),
    ('JOB-CMC-3310','permit_not_obtained','permit_process_delay','verify_isolation_lockout','closed','internal_only','2026-07-01','2026-06-30',5000.00,'Isolation re-confirmed and PTW renewed; rooftop work completed'),
    ('JOB-NAR-3313','induction_expired','induction_not_scheduled','reschedule_site_induction','verification_pending','nabh_finding','2026-07-03',null,6000.00,'RSO permit process documented; induction completed, verifying closure'),
    ('JOB-MDT-3314','incident_event','hospital_process_gap','escalate_to_hospital_ehs','overdue','factories_act_notifiable','2026-06-30',null,18000.00,'Wet-floor barricade SOP overdue at hospital; escalation letter sent'),
    ('JOB-CMC-3309','ppe_noncompliance','documentation_gap','complete_method_statement','open','iso_45001_deviation','2026-07-07',null,3500.00,'Hot-work method statement to be documented; face-shield PPE re-briefed')
  ) as q(job, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.site_hse_ptw_r3300 e
    on e.organization_id = v_org_id and e.job_code = q.job;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3300_compliance_verdict_rollup()
returns table(compliance_verdict text, visits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.site_hse_ptw_r3300)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.site_hse_ptw_r3300 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3300_compliance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3300_compliance_verdict_rollup() to authenticated;

-- 2) Hospital-level HSE scorecard
create or replace function public.founder_r3300_hospital_scorecard()
returns table(
  hospital_name text,
  total_visits bigint,
  fully_compliant bigint,
  minor_gap bigint,
  permit_missing bigint,
  stop_work bigint,
  ppe_fail bigint,
  induction_invalid bigint,
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
    count(*) filter (where l.compliance_verdict = 'fully_compliant')::bigint,
    count(*) filter (where l.compliance_verdict = 'minor_gap')::bigint,
    count(*) filter (where l.compliance_verdict = 'permit_missing')::bigint,
    count(*) filter (where l.compliance_verdict in ('stop_work','incident_occurred'))::bigint,
    count(*) filter (where l.ppe_compliant = false)::bigint,
    count(*) filter (where l.site_induction_valid = false)::bigint,
    round(100.0 * count(*) filter (where l.compliance_verdict = 'fully_compliant')::numeric / nullif(count(*),0), 1)
  from public.site_hse_ptw_r3300 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3300_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3300_hospital_scorecard() to authenticated;

-- 3) Work-category × engineer matrix
create or replace function public.founder_r3300_category_engineer_matrix()
returns table(
  work_category text,
  engineer_name text,
  visits bigint,
  fully_compliant bigint,
  near_miss_total bigint,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.work_category, l.engineer_name, count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'fully_compliant')::bigint,
    coalesce(sum(l.near_miss_reported),0)::bigint,
    round(100.0 * count(*) filter (where l.compliance_verdict = 'fully_compliant')::numeric / nullif(count(*),0), 1)
  from public.site_hse_ptw_r3300 l
  group by l.work_category, l.engineer_name
  order by count(*) desc, l.work_category;
end;
$$;

revoke execute on function public.founder_r3300_category_engineer_matrix() from public, anon;
grant execute on function public.founder_r3300_category_engineer_matrix() to authenticated;

-- 4) Daily HSE compliance trend
create or replace function public.founder_r3300_daily_compliance_trend()
returns table(
  visit_date date,
  visits bigint,
  fully_compliant bigint,
  permit_missing bigint,
  stop_work bigint,
  near_miss_total bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.visit_date,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'fully_compliant')::bigint,
    count(*) filter (where l.compliance_verdict = 'permit_missing')::bigint,
    count(*) filter (where l.compliance_verdict in ('stop_work','incident_occurred'))::bigint,
    coalesce(sum(l.near_miss_reported),0)::bigint
  from public.site_hse_ptw_r3300 l
  group by l.visit_date
  order by l.visit_date desc;
end;
$$;

revoke execute on function public.founder_r3300_daily_compliance_trend() from public, anon;
grant execute on function public.founder_r3300_daily_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3300_capa_status_board()
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
  from public.site_hse_ptw_capa_actions_r3300 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3300_capa_status_board() from public, anon;
grant execute on function public.founder_r3300_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3300_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.site_hse_ptw_capa_actions_r3300)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.site_hse_ptw_capa_actions_r3300 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3300_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3300_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3300_regulatory_impact_digest()
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
  from public.site_hse_ptw_capa_actions_r3300 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3300_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3300_regulatory_impact_digest() to authenticated;

-- 8) High-risk HSE queue (individual visits needing action)
create or replace function public.founder_r3300_high_risk_queue()
returns table(
  hospital_name text,
  engineer_name text,
  job_code text,
  visit_date date,
  work_category text,
  compliance_verdict text,
  ptw_obtained boolean,
  ppe_compliant boolean,
  site_induction_valid boolean,
  near_miss_reported int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.job_code, l.visit_date,
    l.work_category, l.compliance_verdict, l.ptw_obtained, l.ppe_compliant,
    l.site_induction_valid, l.near_miss_reported, l.notes
  from public.site_hse_ptw_r3300 l
  where l.compliance_verdict in ('minor_gap','permit_missing','stop_work','incident_occurred')
     or (l.ptw_required = true and l.ptw_obtained = false)
     or l.ppe_compliant = false
     or l.site_induction_valid = false
     or l.hospital_safety_officer_signoff = false
     or l.area_isolation_confirmed = false
     or l.incident_free = false
     or l.near_miss_reported > 0
  order by l.visit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3300_high_risk_queue() from public, anon;
grant execute on function public.founder_r3300_high_risk_queue() to authenticated;
