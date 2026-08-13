-- Round 3724: Founder Employee Assistance Program (EAP) Wellness Utilization Board
-- Formal EAP counseling/wellness program's operational utilization & effectiveness per
-- department -- sessions used, case closure, clinical-referral escalation, cost per case.
-- Distinct from any personal mental-health-PULSE-survey or founder-burnout-tracker page --
-- this ship is a formal program's operational utilization, not a personal pulse survey.

-- =============================================================================
-- TABLE 1: eap_wellness_r3724 -- per-department/month EAP utilization log
-- =============================================================================
create table if not exists public.eap_wellness_r3724 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  department text not null,
  period_month date not null,
  eligible_employees int not null,
  employees_enrolled int not null,
  sessions_utilized int not null,
  cases_opened int not null,
  cases_closed int not null,
  avg_sessions_per_case numeric,
  escalated_to_clinical_referral int,
  program_cost_rupees numeric(12,2),
  satisfaction_score numeric,
  utilization_pct numeric,
  case_category text not null check (case_category in (
    'stress_burnout','financial_counseling','family_personal','substance_related','workplace_conflict'
  )),
  program_status text not null check (program_status in (
    'healthy_utilization','underutilized','high_demand','escalation_spike','under_review'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eap_wellness_r3724 enable row level security;

create index if not exists idx_eap_wellness_r3724_org on public.eap_wellness_r3724(organization_id);
create index if not exists idx_eap_wellness_r3724_month on public.eap_wellness_r3724(period_month);
create index if not exists idx_eap_wellness_r3724_status on public.eap_wellness_r3724(program_status);

-- =============================================================================
-- TABLE 2: eap_wellness_capa_actions_r3724 -- CAPA & corrective actions
-- =============================================================================
create table if not exists public.eap_wellness_capa_actions_r3724 (
  id uuid primary key default gen_random_uuid(),
  wellness_entry_id uuid references public.eap_wellness_r3724(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in (
    'open','in_progress','closed','overdue'
  )),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eap_wellness_capa_actions_r3724 enable row level security;

create index if not exists idx_eap_wellness_capa_r3724_entry on public.eap_wellness_capa_actions_r3724(wellness_entry_id);
create index if not exists idx_eap_wellness_capa_r3724_status on public.eap_wellness_capa_actions_r3724(capa_status);

-- =============================================================================
-- SEED DATA -- reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 EAP wellness utilization rows
  insert into public.eap_wellness_r3724 (
    organization_id, department, period_month, eligible_employees, employees_enrolled,
    sessions_utilized, cases_opened, cases_closed, avg_sessions_per_case,
    escalated_to_clinical_referral, program_cost_rupees, satisfaction_score, utilization_pct,
    case_category, program_status, trend_dir, notes, created_at
  )
  select v_org_id, q.dept, q.pm::date, q.elig, q.enr,
    q.sess, q.copen, q.cclose, q.avgspc::numeric,
    q.esc, q.cost::numeric, q.sat::numeric, q.util::numeric,
    q.cat, q.pstat, q.trend, q.nt, now()
  from (values
    ('Engineering','2026-06-01',420,68,145,42,38,3.5,2,245000.00,4.3,16.2,
     'stress_burnout','healthy_utilization','improving',
     'Post-release crunch counseling demand steady; manager referrals up.'),
    ('Engineering','2026-07-01',425,71,138,39,36,3.4,1,238000.00,4.4,16.7,
     'stress_burnout','healthy_utilization','stable',
     'Utilization holding steady after Q2 sprint load eased.'),
    ('Sales','2026-06-01',210,18,32,14,8,2.3,0,58000.00,3.6,8.6,
     'financial_counseling','underutilized','worsening',
     'Awareness of financial-counseling benefit remains low among field sales reps.'),
    ('Sales','2026-07-01',212,41,96,33,19,2.9,4,182000.00,3.2,19.3,
     'workplace_conflict','high_demand','worsening',
     'Territory-realignment disputes driving sharp rise in conflict-counseling cases.'),
    ('Operations','2026-06-01',340,52,101,29,27,3.5,1,176000.00,4.1,15.3,
     'family_personal','healthy_utilization','stable',
     'Family-personal cases resolved within program norms this cycle.'),
    ('Operations','2026-07-01',342,39,88,22,11,4.0,9,214000.00,3.0,11.4,
     'substance_related','escalation_spike','worsening',
     'Sharp rise in substance-related referrals to clinical partner; HRBP alerted.'),
    ('Warehouse','2026-06-01',280,61,140,45,22,3.1,3,196000.00,3.4,21.8,
     'workplace_conflict','high_demand','worsening',
     'Shift-supervisor conflict cases surged after new roster policy rollout.'),
    ('Warehouse','2026-07-01',282,58,133,40,31,3.3,2,188000.00,3.8,20.6,
     'stress_burnout','high_demand','stable',
     'Peak-season workload keeping burnout-counseling demand elevated but managed.'),
    ('Field Service','2026-06-01',305,44,79,21,19,3.8,1,142000.00,4.2,14.4,
     'family_personal','healthy_utilization','improving',
     'Field engineers using tele-counseling slots effectively between site visits.'),
    ('Field Service','2026-07-01',308,36,54,17,9,3.2,1,98000.00,3.7,11.7,
     'financial_counseling','under_review','stable',
     'Case-closure rate lagging enrollment; program lead reviewing case backlog.'),
    ('Finance','2026-06-01',95,22,48,13,12,3.7,0,88000.00,4.5,23.2,
     'financial_counseling','healthy_utilization','improving',
     'Personal-finance counseling well received after year-end tax season stress.'),
    ('HR','2026-07-01',48,14,31,11,5,2.8,2,64000.00,3.1,29.2,
     'workplace_conflict','under_review','worsening',
     'Interpersonal conflict cases within HR team itself under confidential review.'),
    ('Customer Support','2026-06-01',160,19,29,12,6,2.4,0,52000.00,3.3,11.9,
     'stress_burnout','underutilized','stable',
     'Night-shift support staff enrollment remains low despite outreach emails.'),
    ('IT','2026-07-01',110,17,41,9,3,4.6,5,97000.00,2.9,15.5,
     'substance_related','escalation_spike','worsening',
     'Multiple clinical-referral escalations flagged for on-call counselor review.'),
    ('Marketing','2026-06-01',72,9,14,6,4,2.3,0,26000.00,3.9,12.5,
     'family_personal','underutilized','improving',
     'Small team; enrollment ticking up after internal wellness-week campaign.'),
    ('Product','2026-07-01',88,20,47,15,13,3.1,1,79000.00,4.3,22.7,
     'stress_burnout','healthy_utilization','stable',
     'Release-cycle stress counseling well-utilized with strong closure rate.')
  ) as q(dept, pm, elig, enr, sess, copen, cclose, avgspc, esc, cost, sat, util, cat, pstat, trend, nt);

  -- CAPA seed -- attach to specific entries via department + period_month + case_category
  insert into public.eap_wellness_capa_actions_r3724 (
    wellness_entry_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Operations','2026-07-01','substance_related',
     'Untrained frontline supervisors missing early warning signs',
     'Mandatory supervisor training on substance-referral protocol','in_progress',
     'EAP Program Manager','2026-08-25',null,
     'Coordinating with clinical-referral partner to add an on-site counselor slot for ops staff.'),
    ('HR','2026-07-01','workplace_conflict',
     'Unresolved interpersonal friction escalated without early mediation',
     'Independent facilitator engaged to mediate intra-team conflict','open',
     'HR Business Partner','2026-08-30',null,
     'Confidentiality protocol applied; mediation sessions scheduled fortnightly.'),
    ('IT','2026-07-01','substance_related',
     'Clinical-referral follow-up capacity gap at partner network',
     'Add backup clinical partner for follow-up scheduling','overdue',
     'EAP Clinical Liaison','2026-08-05',null,
     'Follow-up overdue for two escalated cases; program manager following up directly.'),
    ('Sales','2026-07-01','workplace_conflict',
     'Territory realignment created role-ownership disputes',
     'Group counseling and manager mediation for affected territory team','in_progress',
     'Regional Sales HRBP','2026-08-20',null,
     'Group session scheduled post realignment; monitoring case volume weekly.'),
    ('Warehouse','2026-06-01','workplace_conflict',
     'New roster policy rolled out without shift-supervisor consultation',
     'Grievance sessions and union rep sign-off on revised roster','closed',
     'Warehouse HR Lead','2026-07-15','2026-07-12',
     'Roster-policy grievance sessions completed; conflict cases closed.'),
    ('Field Service','2026-07-01','financial_counseling',
     'Case backlog from remote-engineer scheduling constraints',
     'Review and prioritize backlog with tele-counseling slots','open',
     'EAP Program Manager','2026-08-28',null,
     'Reviewing case-closure backlog to shorten time-to-close for field engineers.'),
    ('Customer Support','2026-06-01','stress_burnout',
     'Low benefit awareness among night-shift support staff',
     'Peer-champion referral and night-shift outreach campaign','in_progress',
     'Support Ops Lead','2026-08-18',null,
     'Outreach campaign relaunched with peer-champion referrals to lift enrollment.'),
    ('Sales','2026-06-01','financial_counseling',
     'Low awareness of financial-counseling benefit among field reps',
     'Awareness webinar and benefit-guide distribution','closed',
     'Sales HRBP','2026-07-20','2026-07-18',
     'Awareness webinar completed; enrollment among field sales reps improved marginally.')
  ) as q(dept, pm, cat, rc, ca, cst, own, tcd, acd, nt)
  join public.eap_wellness_r3724 e
    on e.organization_id = v_org_id
   and e.department = q.dept
   and e.period_month = q.pm::date
   and e.case_category = q.cat;
end;
$seed$;

-- =============================================================================
-- RPCs -- 8 founder-gated rollups
-- =============================================================================

-- 1) Program status distribution
create or replace function public.founder_r3724_program_status_rollup()
returns table(program_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eap_wellness_r3724)
  select l.program_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.eap_wellness_r3724 l
  group by l.program_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3724_program_status_rollup() from public, anon;
grant execute on function public.founder_r3724_program_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3724_department_scorecard()
returns table(
  department text,
  entries bigint,
  total_eligible bigint,
  total_enrolled bigint,
  total_sessions_utilized bigint,
  total_cases_opened bigint,
  total_cases_closed bigint,
  avg_utilization_pct numeric,
  avg_satisfaction_score numeric,
  total_escalations bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    coalesce(sum(l.eligible_employees),0)::bigint,
    coalesce(sum(l.employees_enrolled),0)::bigint,
    coalesce(sum(l.sessions_utilized),0)::bigint,
    coalesce(sum(l.cases_opened),0)::bigint,
    coalesce(sum(l.cases_closed),0)::bigint,
    round(avg(l.utilization_pct), 1),
    round(avg(l.satisfaction_score), 1),
    coalesce(sum(l.escalated_to_clinical_referral),0)::bigint
  from public.eap_wellness_r3724 l
  group by l.department
  order by coalesce(sum(l.eligible_employees),0) desc;
end;
$$;

revoke execute on function public.founder_r3724_department_scorecard() from public, anon;
grant execute on function public.founder_r3724_department_scorecard() to authenticated;

-- 3) Case category x program status matrix
create or replace function public.founder_r3724_case_category_status_matrix()
returns table(case_category text, program_status text, entries bigint, avg_utilization_pct numeric, total_escalations bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.case_category, l.program_status, count(*)::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.escalated_to_clinical_referral),0)::bigint
  from public.eap_wellness_r3724 l
  group by l.case_category, l.program_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3724_case_category_status_matrix() from public, anon;
grant execute on function public.founder_r3724_case_category_status_matrix() to authenticated;

-- 4) Monthly utilization trend
create or replace function public.founder_r3724_monthly_utilization_trend()
returns table(
  period_month date,
  entries bigint,
  total_sessions_utilized bigint,
  avg_utilization_pct numeric,
  total_cases_opened bigint,
  total_cases_closed bigint,
  total_escalations bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.sessions_utilized),0)::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.cases_opened),0)::bigint,
    coalesce(sum(l.cases_closed),0)::bigint,
    coalesce(sum(l.escalated_to_clinical_referral),0)::bigint
  from public.eap_wellness_r3724 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3724_monthly_utilization_trend() from public, anon;
grant execute on function public.founder_r3724_monthly_utilization_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3724_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.eap_wellness_capa_actions_r3724 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3724_capa_status_board() from public, anon;
grant execute on function public.founder_r3724_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3724_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eap_wellness_capa_actions_r3724)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.eap_wellness_capa_actions_r3724 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3724_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3724_root_cause_pareto() to authenticated;

-- 7) Escalation spike digest
create or replace function public.founder_r3724_escalation_spike_digest()
returns table(
  department text,
  entries bigint,
  total_escalated bigint,
  avg_escalation_rate_pct numeric,
  worsening_entries bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    coalesce(sum(l.escalated_to_clinical_referral),0)::bigint,
    round(avg(case when l.cases_opened > 0
      then (l.escalated_to_clinical_referral::numeric / l.cases_opened) * 100.0
      else null end), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.eap_wellness_r3724 l
  where l.program_status in ('escalation_spike','high_demand')
     or l.escalated_to_clinical_referral > 0
  group by l.department
  order by coalesce(sum(l.escalated_to_clinical_referral),0) desc;
end;
$$;

revoke execute on function public.founder_r3724_escalation_spike_digest() from public, anon;
grant execute on function public.founder_r3724_escalation_spike_digest() to authenticated;

-- 8) High-risk queue (escalation spike / under review)
create or replace function public.founder_r3724_high_risk_queue()
returns table(
  department text,
  period_month date,
  case_category text,
  program_status text,
  cases_opened int,
  cases_closed int,
  escalated_to_clinical_referral int,
  utilization_pct numeric,
  satisfaction_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, l.period_month, l.case_category, l.program_status,
    l.cases_opened, l.cases_closed, l.escalated_to_clinical_referral,
    l.utilization_pct, l.satisfaction_score, l.notes
  from public.eap_wellness_r3724 l
  where l.program_status in ('escalation_spike','under_review')
  order by l.period_month desc, l.escalated_to_clinical_referral desc
  limit 20;
end;
$$;

revoke execute on function public.founder_r3724_high_risk_queue() from public, anon;
grant execute on function public.founder_r3724_high_risk_queue() to authenticated;
