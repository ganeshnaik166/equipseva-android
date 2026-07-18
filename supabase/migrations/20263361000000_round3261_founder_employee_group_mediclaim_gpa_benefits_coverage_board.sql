-- Round 3261: Founder Employee Group-Mediclaim / GPA / GTL Benefits Coverage Board
-- HR-benefits governance — policy type × employee cohort × insurer × lives covered × claim ratio × CD balance × endorsement backlog × CAPA

-- =============================================================================
-- TABLE 1: employee_benefits_coverage_r3261 — per policy/cohort coverage rows
-- =============================================================================
create table if not exists public.employee_benefits_coverage_r3261 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  policy_name text not null,
  policy_type text not null check (policy_type in (
    'group_mediclaim','group_personal_accident','group_term_life','workmen_compensation'
  )),
  insurer text not null,
  employee_cohort text not null check (employee_cohort in (
    'field_engineers','office_staff','leadership','contract_workers','all_employees'
  )),
  lives_covered int not null,
  sum_insured_per_life_rupees numeric(14,2) not null,
  annual_premium_rupees numeric(14,2) not null,
  policy_start date not null,
  policy_end date not null,
  cd_balance_rupees numeric(12,2),
  claims_filed_ytd int not null,
  claims_settled_ytd int not null,
  claim_ratio_pct numeric(6,2),
  endorsement_backlog int not null,
  coverage_verdict text not null check (coverage_verdict in (
    'healthy','renewal_due','claims_ratio_high','cd_balance_low','coverage_gap','critical'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.employee_benefits_coverage_r3261 enable row level security;

create index if not exists idx_emp_benefits_r3261_org on public.employee_benefits_coverage_r3261(organization_id);
create index if not exists idx_emp_benefits_r3261_end on public.employee_benefits_coverage_r3261(policy_end);
create index if not exists idx_emp_benefits_r3261_verdict on public.employee_benefits_coverage_r3261(coverage_verdict);

-- =============================================================================
-- TABLE 2: employee_benefits_coverage_capa_actions_r3261 — renewal/endorsement/coverage-gap actions
-- =============================================================================
create table if not exists public.employee_benefits_coverage_capa_actions_r3261 (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.employee_benefits_coverage_r3261(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'renewal_lapse_risk','claims_ratio_breach','cd_balance_depletion','endorsement_backlog',
    'statutory_coverage_gap','premium_cost_spike','insurer_service_delay'
  )),
  root_cause text not null check (root_cause in (
    'high_claims_utilisation','hr_endorsement_process_lag','contractor_onboarding_missed',
    'cd_top_up_not_budgeted','broker_follow_up_lapse','policy_terms_mismatch',
    'headcount_growth_unplanned','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'invite_renewal_quotes','negotiate_copay_redesign','top_up_cd_balance','bulk_endorsement_submission',
    'onboard_contractor_lives','switch_insurer','automate_hr_endorsement_feed','escalate_to_broker','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  compliance_impact text not null check (compliance_impact in (
    'wc_act_statutory_breach','irdai_grievance_risk','employee_grievance_risk',
    'contractual_breach','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.employee_benefits_coverage_capa_actions_r3261 enable row level security;

create index if not exists idx_emp_benefits_capa_r3261_policy on public.employee_benefits_coverage_capa_actions_r3261(policy_id);
create index if not exists idx_emp_benefits_capa_r3261_status on public.employee_benefits_coverage_capa_actions_r3261(capa_status);

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

  -- 14 policy/cohort coverage rows
  insert into public.employee_benefits_coverage_r3261 (
    organization_id, policy_name, policy_type, insurer, employee_cohort,
    lives_covered, sum_insured_per_life_rupees, annual_premium_rupees,
    policy_start, policy_end, cd_balance_rupees,
    claims_filed_ytd, claims_settled_ytd, claim_ratio_pct,
    endorsement_backlog, coverage_verdict, notes
  )
  select v_org_id, q.pname, q.ptype, q.ins, q.cohort,
    q.lives, q.sipl, q.prem,
    q.pstart::date, q.pend::date, q.cdb,
    q.cfy, q.csy, q.cratio,
    q.ebk, q.cv, q.nt
  from (values
    ('GMC-FY26 All-Staff Base','group_mediclaim','ICICI Lombard General Insurance','all_employees',
     412,500000.00,2870000.00,'2026-04-01','2027-03-31',640000.00,38,31,61.40,6,'healthy',
     'Base GMC floater 5L per family — utilisation tracking to plan'),
    ('GMC-FY26 Field Engineer Top-Up','group_mediclaim','Star Health & Allied Insurance','field_engineers',
     168,300000.00,940000.00,'2026-04-01','2027-03-31',82000.00,22,14,88.60,14,'claims_ratio_high',
     'Claims ratio 88.6% — insurer flagged loading of 25% at renewal'),
    ('GPA-FY26 Field Engineers','group_personal_accident','Tata AIG General Insurance','field_engineers',
     168,2500000.00,385000.00,'2026-04-01','2027-03-31',55000.00,3,2,41.20,2,'healthy',
     '24x7 accident cover incl. two-wheeler commute rider for field team'),
    ('GTL-FY26 All-Staff','group_term_life','LIC of India','all_employees',
     412,2000000.00,1180000.00,'2026-04-01','2027-03-31',null,1,1,34.00,0,'healthy',
     'Flat 20L GTL — one claim settled in 11 days, nominee paid'),
    ('GMC-FY26 Leadership Super Top-Up','group_mediclaim','HDFC ERGO General Insurance','leadership',
     18,2000000.00,460000.00,'2026-04-01','2027-03-31',120000.00,2,2,28.50,0,'healthy',
     'Super top-up above 5L base for CXO band — clean run'),
    ('WC-FY26 Contract Workers','workmen_compensation','New India Assurance','contract_workers',
     96,1500000.00,210000.00,'2026-04-01','2027-03-31',null,4,2,52.00,9,'coverage_gap',
     'New Kochi contractor batch of 22 loaders not yet endorsed — statutory gap live'),
    ('GMC-FY25 Office Staff Legacy','group_mediclaim','Oriental Insurance','office_staff',
     74,400000.00,512000.00,'2025-08-16','2026-08-15',34000.00,11,9,74.80,3,'renewal_due',
     'Renewal in 28 days — quotes invited from 3 insurers via broker'),
    ('GPA-FY26 Office & Warehouse','group_personal_accident','Bajaj Allianz General Insurance','office_staff',
     118,1500000.00,168000.00,'2026-04-01','2027-03-31',21000.00,1,0,12.40,1,'healthy',
     'Single fracture claim in survey — documents pending from employee'),
    ('GMC-FY26 Contract Workers Base','group_mediclaim','Niva Bupa Health Insurance','contract_workers',
     96,200000.00,388000.00,'2026-04-01','2027-03-31',18500.00,9,5,71.30,11,'cd_balance_low',
     'CD float below one month of claims outgo — top-up invoice raised'),
    ('GTL-FY26 Leadership Keyman','group_term_life','Kotak Mahindra Life Insurance','leadership',
     6,10000000.00,340000.00,'2026-04-01','2027-03-31',null,0,0,0.00,0,'healthy',
     'Keyman 1Cr GTL on founders and CTO — assignment clauses verified'),
    ('GPA-FY26 Leadership Travel-Heavy','group_personal_accident','ICICI Lombard General Insurance','leadership',
     18,5000000.00,96000.00,'2026-04-01','2027-03-31',null,0,0,0.00,0,'healthy',
     'Air-travel multiplier rider for leadership hospital-visit circuit'),
    ('GMC-FY26 Parental Add-On','group_mediclaim','Care Health Insurance','all_employees',
     143,300000.00,1620000.00,'2026-04-01','2027-03-31',47000.00,26,17,96.20,8,'claims_ratio_high',
     'Parental block ratio 96.2% — 10% co-pay redesign under study'),
    ('WC-FY26 Warehouse Loaders','workmen_compensation','National Insurance Company','contract_workers',
     34,1000000.00,88000.00,'2026-04-01','2027-03-31',null,1,1,45.00,0,'healthy',
     'Hyderabad spares-warehouse crew — one crush-injury claim settled'),
    ('GTL-FY26 New-Joiner Cohort','group_term_life','HDFC Life Insurance','all_employees',
     57,1500000.00,152000.00,'2026-04-01','2027-03-31',null,0,0,0.00,16,'critical',
     'Q1 joiners not yet added to GTL — 57 lives unendorsed, cover gap live')
  ) as q(pname, ptype, ins, cohort, lives, sipl, prem, pstart, pend, cdb, cfy, csy, cratio, ebk, cv, nt);

  -- CAPA seed — attach to specific policies via policy name
  insert into public.employee_benefits_coverage_capa_actions_r3261 (
    policy_id, finding_category, root_cause, corrective_action,
    capa_status, compliance_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('GMC-FY26 Field Engineer Top-Up','claims_ratio_breach','high_claims_utilisation','negotiate_copay_redesign',
     'in_progress','employee_grievance_risk','2026-08-10',null,0.00,
     'Co-pay 10% on non-network hospitalisation modelled — CHRO review 25-Jul'),
    ('GMC-FY25 Office Staff Legacy','renewal_lapse_risk','broker_follow_up_lapse','invite_renewal_quotes',
     'open','internal_only','2026-07-30',null,512000.00,
     'Renewal RFQ to ICICI Lombard, HDFC ERGO and Niva Bupa — quotes due 24-Jul'),
    ('GMC-FY26 Contract Workers Base','cd_balance_depletion','cd_top_up_not_budgeted','top_up_cd_balance',
     'escalated','contractual_breach','2026-07-22',null,150000.00,
     'CD top-up of 1.5L pending finance approval — cashless claims may bounce'),
    ('WC-FY26 Contract Workers','statutory_coverage_gap','contractor_onboarding_missed','onboard_contractor_lives',
     'in_progress','wc_act_statutory_breach','2026-07-20',null,46000.00,
     'Kochi batch of 22 loaders — endorsement filed 16-Jul, awaiting insurer confirmation'),
    ('GTL-FY26 New-Joiner Cohort','endorsement_backlog','hr_endorsement_process_lag','automate_hr_endorsement_feed',
     'overdue','employee_grievance_risk','2026-07-05',null,152000.00,
     'HRMS-to-insurer feed build slipped — 57 Q1 joiners still uncovered'),
    ('GMC-FY26 Parental Add-On','claims_ratio_breach','high_claims_utilisation','negotiate_copay_redesign',
     'verification_pending','internal_only','2026-07-15',null,0.00,
     'Parental co-pay grid signed with insurer — verify on next endorsement cycle'),
    ('GMC-FY26 All-Staff Base','endorsement_backlog','hr_endorsement_process_lag','bulk_endorsement_submission',
     'closed','none','2026-07-08','2026-07-06',0.00,
     '6 pending add/deletes submitted in bulk — insurer confirmation received')
  ) as q(pname, fc, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.employee_benefits_coverage_r3261 e
    on e.organization_id = v_org_id and e.policy_name = q.pname;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage verdict distribution
create or replace function public.founder_r3261_coverage_verdict_rollup()
returns table(coverage_verdict text, policies bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.employee_benefits_coverage_r3261)
  select l.coverage_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.employee_benefits_coverage_r3261 l
  group by l.coverage_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3261_coverage_verdict_rollup() from public, anon;
grant execute on function public.founder_r3261_coverage_verdict_rollup() to authenticated;

-- 2) Insurer-level coverage scorecard
create or replace function public.founder_r3261_insurer_scorecard()
returns table(
  insurer text,
  policies bigint,
  lives_covered bigint,
  total_premium_rupees numeric,
  healthy bigint,
  at_risk bigint,
  avg_claim_ratio_pct numeric,
  endorsement_backlog bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.insurer,
    count(*)::bigint,
    coalesce(sum(l.lives_covered),0)::bigint,
    coalesce(sum(l.annual_premium_rupees),0)::numeric,
    count(*) filter (where l.coverage_verdict = 'healthy')::bigint,
    count(*) filter (where l.coverage_verdict in ('renewal_due','claims_ratio_high','cd_balance_low','coverage_gap','critical'))::bigint,
    round(avg(l.claim_ratio_pct), 1),
    coalesce(sum(l.endorsement_backlog),0)::bigint
  from public.employee_benefits_coverage_r3261 l
  group by l.insurer
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3261_insurer_scorecard() from public, anon;
grant execute on function public.founder_r3261_insurer_scorecard() to authenticated;

-- 3) Policy type × employee cohort matrix
create or replace function public.founder_r3261_policy_cohort_matrix()
returns table(policy_type text, employee_cohort text, policies bigint, lives bigint, avg_sum_insured_rupees numeric, total_premium_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_type, l.employee_cohort, count(*)::bigint,
    coalesce(sum(l.lives_covered),0)::bigint,
    round(avg(l.sum_insured_per_life_rupees), 0),
    coalesce(sum(l.annual_premium_rupees),0)::numeric
  from public.employee_benefits_coverage_r3261 l
  group by l.policy_type, l.employee_cohort
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3261_policy_cohort_matrix() from public, anon;
grant execute on function public.founder_r3261_policy_cohort_matrix() to authenticated;

-- 4) Renewal runway trend by policy-end date
create or replace function public.founder_r3261_renewal_runway_trend()
returns table(policy_end date, policies_expiring bigint, lives bigint, annual_premium_rupees numeric, at_risk bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_end,
    count(*)::bigint,
    coalesce(sum(l.lives_covered),0)::bigint,
    coalesce(sum(l.annual_premium_rupees),0)::numeric,
    count(*) filter (where l.coverage_verdict in ('renewal_due','claims_ratio_high','cd_balance_low','coverage_gap','critical'))::bigint
  from public.employee_benefits_coverage_r3261 l
  group by l.policy_end
  order by l.policy_end asc;
end;
$$;

revoke execute on function public.founder_r3261_renewal_runway_trend() from public, anon;
grant execute on function public.founder_r3261_renewal_runway_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3261_capa_status_board()
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
  from public.employee_benefits_coverage_capa_actions_r3261 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3261_capa_status_board() from public, anon;
grant execute on function public.founder_r3261_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3261_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.employee_benefits_coverage_capa_actions_r3261)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.employee_benefits_coverage_capa_actions_r3261 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3261_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3261_root_cause_pareto() to authenticated;

-- 7) Compliance impact digest
create or replace function public.founder_r3261_compliance_impact_digest()
returns table(compliance_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.compliance_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.employee_benefits_coverage_capa_actions_r3261 c
  group by c.compliance_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3261_compliance_impact_digest() from public, anon;
grant execute on function public.founder_r3261_compliance_impact_digest() to authenticated;

-- 8) High-risk coverage queue (top individual concerns)
create or replace function public.founder_r3261_high_risk_queue()
returns table(
  policy_name text,
  policy_type text,
  insurer text,
  employee_cohort text,
  policy_end date,
  coverage_verdict text,
  claim_ratio_pct numeric,
  cd_balance_rupees numeric,
  endorsement_backlog int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_name, l.policy_type, l.insurer, l.employee_cohort, l.policy_end,
    l.coverage_verdict, l.claim_ratio_pct, l.cd_balance_rupees, l.endorsement_backlog,
    l.notes
  from public.employee_benefits_coverage_r3261 l
  where l.coverage_verdict in ('renewal_due','claims_ratio_high','cd_balance_low','coverage_gap','critical')
     or l.endorsement_backlog >= 5
  order by l.policy_end asc, l.policy_name;
end;
$$;

revoke execute on function public.founder_r3261_high_risk_queue() from public, anon;
grant execute on function public.founder_r3261_high_risk_queue() to authenticated;
