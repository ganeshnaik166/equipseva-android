-- Round 3293: Founder Whistleblower, Ethics-Hotline, POSH & Employee-Grievance Case Governance Board
-- Governance case log — case category × reporting channel × severity × department × committee × investigation status × outcome × confidentiality × board verdict × CAPA

-- =============================================================================
-- TABLE 1: governance_case_r3293 — individual whistleblower / ethics / POSH / grievance cases
-- =============================================================================
create table if not exists public.governance_case_r3293 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  case_ref text not null,
  case_category text not null check (case_category in (
    'posh_harassment','financial_fraud','ethics_coc_violation','workplace_grievance',
    'safety_concern','discrimination','retaliation'
  )),
  reporting_channel text not null check (reporting_channel in (
    'ethics_hotline','email','posh_committee','direct_to_hr','anonymous_box'
  )),
  severity text not null check (severity in (
    'critical','high','medium','low'
  )),
  reported_date date not null,
  anonymous boolean not null default false,
  department_involved text not null check (department_involved in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  committee_assigned text not null check (committee_assigned in (
    'posh_ic','ethics_committee','hr_panel','external_investigator'
  )),
  investigation_status text not null check (investigation_status in (
    'intake','under_investigation','hearing','concluded','appeal'
  )),
  target_closure_date date not null,
  actual_closure_date date,
  outcome text not null check (outcome in (
    'substantiated','partially_substantiated','unsubstantiated','withdrawn','pending'
  )),
  confidentiality_maintained boolean not null default true,
  case_verdict text not null check (case_verdict in (
    'closed_actioned','closed_no_action','open_on_track','open_overdue','escalated_to_board'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.governance_case_r3293 enable row level security;

create index if not exists idx_governance_case_r3293_org on public.governance_case_r3293(organization_id);
create index if not exists idx_governance_case_r3293_date on public.governance_case_r3293(reported_date);
create index if not exists idx_governance_case_r3293_verdict on public.governance_case_r3293(case_verdict);

-- =============================================================================
-- TABLE 2: governance_case_capa_actions_r3293 — corrective / disciplinary / policy actions
-- =============================================================================
create table if not exists public.governance_case_capa_actions_r3293 (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.governance_case_r3293(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'disciplinary_action','policy_gap','training_deficiency','process_control_gap',
    'confidentiality_breach','retaliation_prevention','whistleblower_protection','records_management'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_policy','lack_of_awareness','supervisory_failure','weak_internal_controls',
    'cultural_issue','process_not_followed','pending_investigation','systemic_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'issue_disciplinary_action','update_policy','mandatory_training','strengthen_controls',
    'terminate_employment','counsel_and_warn','enhance_whistleblower_safeguards','no_action_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'posh_act_2013','companies_act_2013','labour_law','none','internal_policy_only','board_reportable'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.governance_case_capa_actions_r3293 enable row level security;

create index if not exists idx_governance_capa_r3293_case on public.governance_case_capa_actions_r3293(case_id);
create index if not exists idx_governance_capa_r3293_status on public.governance_case_capa_actions_r3293(capa_status);

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

  -- 14 governance case rows
  insert into public.governance_case_r3293 (
    organization_id, case_ref, case_category, reporting_channel, severity,
    reported_date, anonymous, department_involved, committee_assigned, investigation_status,
    target_closure_date, actual_closure_date, outcome, confidentiality_maintained, case_verdict, notes
  )
  select v_org_id, q.cref, q.cat, q.chan, q.sev,
    q.rdate::date, q.anon, q.dept, q.comm, q.invst,
    q.tcd::date, q.acd::date, q.outc, q.conf, q.verdict, q.nt
  from (values
    ('GRV-2026-001','posh_harassment','posh_committee','high','2026-06-10',false,'sales','posh_ic','concluded',
     '2026-07-05','2026-06-30','substantiated',true,'closed_actioned','IC inquiry upheld complaint; respondent issued written warning and inter-branch transfer'),
    ('GRV-2026-002','financial_fraud','ethics_hotline','critical','2026-06-12',true,'finance','ethics_committee','under_investigation',
     '2026-07-20',null,'pending',true,'open_on_track','Anonymous tip on vendor kickback in procurement; forensic audit underway'),
    ('GRV-2026-003','ethics_coc_violation','email','medium','2026-06-15',false,'office_ops','ethics_committee','hearing',
     '2026-07-10',null,'partially_substantiated',true,'open_on_track','Undisclosed conflict-of-interest with supplier; hearing scheduled'),
    ('GRV-2026-004','workplace_grievance','direct_to_hr','low','2026-06-18',false,'field_engineering','hr_panel','concluded',
     '2026-06-28','2026-06-26','unsubstantiated',true,'closed_no_action','Shift-roster fairness grievance; no policy breach found on review'),
    ('GRV-2026-005','safety_concern','ethics_hotline','high','2026-06-05',false,'field_engineering','hr_panel','concluded',
     '2026-06-25','2026-06-24','substantiated',true,'closed_actioned','PPE non-issuance at Chennai install site; corrective PPE rollout ordered'),
    ('GRV-2026-006','discrimination','posh_committee','high','2026-05-28',false,'support','ethics_committee','concluded',
     '2026-06-20','2026-07-02','substantiated',true,'closed_actioned','Discriminatory rostering substantiated; manager counselled, closed past target'),
    ('GRV-2026-007','retaliation','ethics_hotline','critical','2026-06-20',true,'leadership','external_investigator','under_investigation',
     '2026-07-15',null,'pending',true,'escalated_to_board','Alleged retaliation against a whistleblower; external investigator engaged, board notified'),
    ('GRV-2026-008','posh_harassment','anonymous_box','critical','2026-05-15',true,'office_ops','posh_ic','appeal',
     '2026-06-15',null,'substantiated',false,'open_overdue','IC upheld complaint; respondent filed appeal; confidentiality lapse noted, past target'),
    ('GRV-2026-009','workplace_grievance','direct_to_hr','medium','2026-06-22',false,'sales','hr_panel','intake',
     '2026-07-25',null,'pending',true,'open_on_track','Incentive-payout dispute logged by Bengaluru sales rep; intake review pending'),
    ('GRV-2026-010','financial_fraud','ethics_hotline','high','2026-05-20',true,'finance','ethics_committee','hearing',
     '2026-06-18',null,'partially_substantiated',true,'open_overdue','Expense-claim inflation flagged; partial evidence, investigation past target date'),
    ('GRV-2026-011','ethics_coc_violation','email','low','2026-06-25',false,'sales','ethics_committee','concluded',
     '2026-07-08','2026-07-06','withdrawn',true,'closed_no_action','Gift-policy query on customer diwali hamper; complainant withdrew after clarification'),
    ('GRV-2026-012','safety_concern','direct_to_hr','medium','2026-06-08',false,'field_engineering','hr_panel','concluded',
     '2026-06-28','2026-06-27','substantiated',true,'closed_actioned','Unsafe ladder practice at Hyderabad site; toolbox-talk and equipment fix completed'),
    ('GRV-2026-013','discrimination','ethics_hotline','high','2026-06-14',true,'support','ethics_committee','under_investigation',
     '2026-07-12',null,'pending',true,'open_on_track','Anonymous bias complaint against a hiring panel; investigation active'),
    ('GRV-2026-014','posh_harassment','posh_committee','critical','2026-05-10',false,'leadership','external_investigator','concluded',
     '2026-06-10','2026-06-30','substantiated',true,'escalated_to_board','Senior-leader POSH case substantiated; board-level action, closed after appeal window')
  ) as q(cref, cat, chan, sev, rdate, anon, dept, comm, invst, tcd, acd, outc, conf, verdict, nt);

  -- CAPA seed — attach to specific cases via case_ref
  insert into public.governance_case_capa_actions_r3293 (
    case_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('GRV-2026-001','disciplinary_action','supervisory_failure','issue_disciplinary_action','closed','posh_act_2013','2026-07-05','2026-06-30',0.00,'Written warning and transfer executed per IC recommendation'),
    ('GRV-2026-002','process_control_gap','weak_internal_controls','strengthen_controls','in_progress','companies_act_2013','2026-07-20',null,150000.00,'Vendor-onboarding controls being tightened; forensic audit ongoing'),
    ('GRV-2026-007','whistleblower_protection','cultural_issue','enhance_whistleblower_safeguards','escalated','board_reportable','2026-07-15',null,80000.00,'External investigator plus board oversight; anti-retaliation policy refresh'),
    ('GRV-2026-008','confidentiality_breach','process_not_followed','mandatory_training','overdue','posh_act_2013','2026-06-15',null,25000.00,'Case-handling confidentiality breach; IC re-training overdue'),
    ('GRV-2026-005','policy_gap','inadequate_policy','update_policy','closed','labour_law','2026-06-25','2026-06-24',60000.00,'Site PPE SOP updated and PPE re-issued to field crew'),
    ('GRV-2026-010','disciplinary_action','process_not_followed','counsel_and_warn','verification_pending','internal_policy_only','2026-06-18',null,15000.00,'Expense-claim clawback plus written caution; verifying reimbursement recovery'),
    ('GRV-2026-014','disciplinary_action','supervisory_failure','terminate_employment','closed','board_reportable','2026-06-10','2026-06-30',0.00,'Leadership respondent separated post-inquiry; board informed')
  ) as q(cref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.governance_case_r3293 e
    on e.organization_id = v_org_id and e.case_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Case verdict distribution
create or replace function public.founder_r3293_case_verdict_rollup()
returns table(case_verdict text, cases bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.governance_case_r3293)
  select l.case_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.governance_case_r3293 l
  group by l.case_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3293_case_verdict_rollup() from public, anon;
grant execute on function public.founder_r3293_case_verdict_rollup() to authenticated;

-- 2) Department-level governance scorecard
create or replace function public.founder_r3293_department_scorecard()
returns table(
  department_involved text,
  total_cases bigint,
  substantiated bigint,
  open_overdue bigint,
  escalated bigint,
  posh_cases bigint,
  anonymous_cases bigint,
  closure_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department_involved,
    count(*)::bigint,
    count(*) filter (where l.outcome in ('substantiated','partially_substantiated'))::bigint,
    count(*) filter (where l.case_verdict = 'open_overdue')::bigint,
    count(*) filter (where l.case_verdict = 'escalated_to_board')::bigint,
    count(*) filter (where l.case_category = 'posh_harassment')::bigint,
    count(*) filter (where l.anonymous)::bigint,
    round(100.0 * count(*) filter (where l.case_verdict in ('closed_actioned','closed_no_action'))::numeric / nullif(count(*),0), 1)
  from public.governance_case_r3293 l
  group by l.department_involved
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3293_department_scorecard() from public, anon;
grant execute on function public.founder_r3293_department_scorecard() to authenticated;

-- 3) Case category × reporting channel matrix
create or replace function public.founder_r3293_category_channel_matrix()
returns table(case_category text, reporting_channel text, cases bigint, substantiated bigint, avg_days_to_close numeric, anonymous_cases bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.case_category, l.reporting_channel, count(*)::bigint,
    count(*) filter (where l.outcome in ('substantiated','partially_substantiated'))::bigint,
    round(avg(l.actual_closure_date - l.reported_date) filter (where l.actual_closure_date is not null), 1),
    count(*) filter (where l.anonymous)::bigint
  from public.governance_case_r3293 l
  group by l.case_category, l.reporting_channel
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3293_category_channel_matrix() from public, anon;
grant execute on function public.founder_r3293_category_channel_matrix() to authenticated;

-- 4) Daily case-intake trend
create or replace function public.founder_r3293_daily_case_trend()
returns table(reported_date date, cases bigint, substantiated bigint, open_overdue bigint, posh_cases bigint, anonymous_cases bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.reported_date,
    count(*)::bigint,
    count(*) filter (where l.outcome in ('substantiated','partially_substantiated'))::bigint,
    count(*) filter (where l.case_verdict = 'open_overdue')::bigint,
    count(*) filter (where l.case_category = 'posh_harassment')::bigint,
    count(*) filter (where l.anonymous)::bigint
  from public.governance_case_r3293 l
  group by l.reported_date
  order by l.reported_date desc;
end;
$$;

revoke execute on function public.founder_r3293_daily_case_trend() from public, anon;
grant execute on function public.founder_r3293_daily_case_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3293_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.governance_case_capa_actions_r3293 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3293_capa_status_board() from public, anon;
grant execute on function public.founder_r3293_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3293_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.governance_case_capa_actions_r3293)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.governance_case_capa_actions_r3293 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3293_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3293_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3293_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
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
  from public.governance_case_capa_actions_r3293 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3293_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3293_regulatory_impact_digest() to authenticated;

-- 8) High-risk case queue (top individual concerns)
create or replace function public.founder_r3293_high_risk_queue()
returns table(
  case_ref text,
  case_category text,
  department_involved text,
  severity text,
  reported_date date,
  investigation_status text,
  outcome text,
  case_verdict text,
  confidentiality_maintained boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.case_ref, l.case_category, l.department_involved, l.severity, l.reported_date,
    l.investigation_status, l.outcome, l.case_verdict, l.confidentiality_maintained, l.notes
  from public.governance_case_r3293 l
  where l.case_verdict in ('open_overdue','escalated_to_board')
     or l.severity = 'critical'
     or l.outcome in ('substantiated','partially_substantiated')
     or l.confidentiality_maintained = false
  order by l.reported_date desc, l.case_ref;
end;
$$;

revoke execute on function public.founder_r3293_high_risk_queue() from public, anon;
grant execute on function public.founder_r3293_high_risk_queue() to authenticated;
