-- Round 3257: Founder Internal-Audit Finding & Control-Remediation Register
-- Governance board — audit cycle × control area × severity × likelihood × retest result × repeat flag × exposure ₹ × management response × verdict × CAPA

-- =============================================================================
-- TABLE 1: internal_audit_finding_r3257 — individual internal-audit findings
-- =============================================================================
create table if not exists public.internal_audit_finding_r3257 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  finding_code text not null,
  audit_cycle text not null check (audit_cycle in (
    'q1_fy27','q2_fy27','q3_fy27','q4_fy27','special_review'
  )),
  control_area text not null check (control_area in (
    'revenue_billing','payroll','procurement','inventory_spares',
    'fixed_assets','it_access','statutory_compliance','cash_treasury'
  )),
  finding_title text not null,
  severity text not null check (severity in (
    'critical','high','medium','low'
  )),
  likelihood text not null check (likelihood in (
    'probable','possible','rare'
  )),
  finding_date date not null,
  remediation_owner text not null,
  target_close_date date not null,
  actual_close_date date,
  retest_result text not null check (retest_result in (
    'effective','partially_effective','ineffective','not_retested'
  )),
  repeat_finding boolean not null default false,
  estimated_exposure_rupees numeric(14,2),
  management_response text not null check (management_response in (
    'accepted','accepted_with_plan','disputed','risk_accepted'
  )),
  finding_verdict text not null check (finding_verdict in (
    'closed_verified','closed_unverified','open_on_track','open_overdue','escalated_to_board'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.internal_audit_finding_r3257 enable row level security;

create index if not exists idx_audit_finding_r3257_org on public.internal_audit_finding_r3257(organization_id);
create index if not exists idx_audit_finding_r3257_date on public.internal_audit_finding_r3257(finding_date);
create index if not exists idx_audit_finding_r3257_verdict on public.internal_audit_finding_r3257(finding_verdict);

-- =============================================================================
-- TABLE 2: internal_audit_finding_capa_actions_r3257 — remediation CAPA actions
-- =============================================================================
create table if not exists public.internal_audit_finding_capa_actions_r3257 (
  id uuid primary key default gen_random_uuid(),
  finding_id uuid not null references public.internal_audit_finding_r3257(id) on delete cascade,
  raised_at timestamptz not null default now(),
  action_category text not null check (action_category in (
    'process_redesign','policy_update','system_control','segregation_of_duties',
    'vendor_management','training_awareness','reconciliation_control','access_revocation'
  )),
  root_cause text not null check (root_cause in (
    'missing_sop','manual_process_error','system_access_gap','vendor_oversight_lapse',
    'headcount_gap','legacy_system_limitation','policy_not_updated','management_override',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'implement_maker_checker','automate_reconciliation','revoke_excess_access','update_sop_and_train',
    'onboard_second_vendor','deploy_asset_tagging','escalate_to_audit_committee','hire_compliance_analyst',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  compliance_impact text not null check (compliance_impact in (
    'companies_act_filing','gst_exposure','tds_exposure','pf_esi_exposure',
    'iso_27001_deviation','internal_only','board_reportable'
  )),
  target_completion_date date,
  actual_completion_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.internal_audit_finding_capa_actions_r3257 enable row level security;

create index if not exists idx_audit_capa_r3257_finding on public.internal_audit_finding_capa_actions_r3257(finding_id);
create index if not exists idx_audit_capa_r3257_status on public.internal_audit_finding_capa_actions_r3257(capa_status);

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

  -- 14 internal-audit finding rows
  insert into public.internal_audit_finding_r3257 (
    organization_id, finding_code, audit_cycle, control_area, finding_title,
    severity, likelihood, finding_date, remediation_owner,
    target_close_date, actual_close_date, retest_result, repeat_finding,
    estimated_exposure_rupees, management_response, finding_verdict, notes
  )
  select v_org_id, q.code, q.cyc, q.area, q.title,
    q.sev, q.lik, q.fdate::date, q.owner,
    q.tcd::date, q.acd::date, q.retest, q.rep,
    q.exposure, q.resp, q.verdict, q.nt
  from (values
    ('IAF-2701','q1_fy27','revenue_billing','AMC invoices raised without PO reference for 3 hospital accounts','high','probable','2026-04-14','Meera Krishnan',
     '2026-06-15','2026-06-10','effective',false,480000.00,'accepted','closed_verified','Maker-checker added in billing workflow; Apollo Chennai and Fortis Gurgaon accounts re-verified'),
    ('IAF-2702','q1_fy27','revenue_billing','Credit notes above Rs 50k approved without CFO sign-off','critical','possible','2026-04-16','Meera Krishnan',
     '2026-05-31',null,'partially_effective',true,1250000.00,'accepted_with_plan','escalated_to_board','Repeat of FY26 finding; interim CFO approval matrix live, ERP hard-block pending'),
    ('IAF-2703','q1_fy27','payroll','Full-and-final settlements delayed beyond 45 days for 6 exits','medium','probable','2026-04-22','Sunita Reddy',
     '2026-06-30','2026-06-25','effective',false,210000.00,'accepted','closed_verified','HRMS exit checklist automated with finance sign-off gate'),
    ('IAF-2704','q1_fy27','payroll','PF ECR filed late twice in Q1 attracting damages','high','possible','2026-04-25','Sunita Reddy',
     '2026-07-10',null,'not_retested',false,165000.00,'accepted_with_plan','open_on_track','Compliance calendar with dual reminders deployed; July filing on time'),
    ('IAF-2705','q1_fy27','procurement','Single-vendor dependency for infusion-pump spares without rate contract','high','probable','2026-05-05','Arvind Sharma',
     '2026-07-31',null,'not_retested',false,890000.00,'accepted_with_plan','open_on_track','Second vendor onboarding for Manipal Bengaluru spare lines in progress'),
    ('IAF-2706','q1_fy27','procurement','Emergency purchases bypassing three-quote rule in 11 cases','medium','probable','2026-05-08','Arvind Sharma',
     '2026-06-20',null,'ineffective',true,340000.00,'disputed','open_overdue','Ops argues clinical urgency at AIIMS Delhi jobs; audit committee review set'),
    ('IAF-2707','q2_fy27','inventory_spares','Physical count variance 4.2% at Hyderabad spares depot','high','possible','2026-07-03','Rakesh Nair',
     '2026-08-15',null,'not_retested',false,560000.00,'accepted','open_on_track','Cycle-count program with barcode scanning piloting at KIMS Hyderabad hub'),
    ('IAF-2708','q2_fy27','inventory_spares','Expired calibration kits issued to field engineers on CMC Vellore job','critical','possible','2026-07-07','Rakesh Nair',
     '2026-07-25',null,'not_retested',false,720000.00,'accepted_with_plan','escalated_to_board','Batch-expiry gating added to issue screen; board notified same week'),
    ('IAF-2709','q1_fy27','fixed_assets','Test equipment worth Rs 18 lakh untagged and untraceable','high','probable','2026-05-12','Vikram Joshi',
     '2026-06-30',null,'partially_effective',false,1800000.00,'accepted_with_plan','open_overdue','61 of 74 assets tagged; balance with field teams in AIIMS Delhi region'),
    ('IAF-2710','q1_fy27','fixed_assets','Depreciation policy not updated for refurbished ventilator fleet','low','rare','2026-05-15','Vikram Joshi',
     '2026-06-10','2026-06-05','effective',false,95000.00,'accepted','closed_verified','Policy note approved by audit committee'),
    ('IAF-2711','q1_fy27','it_access','9 ex-employees retained active ERP and database access post-exit','critical','probable','2026-05-20','Priya Menon',
     '2026-06-05','2026-06-02','partially_effective',true,0.00,'accepted','closed_unverified','Access revoked; automated deprovisioning retest pending on next exit'),
    ('IAF-2712','q2_fy27','it_access','Production database changes made without change-approval tickets','high','possible','2026-07-10','Priya Menon',
     '2026-08-10',null,'not_retested',false,0.00,'accepted_with_plan','open_on_track','Change-management SOP drafted; workflow tooling evaluation underway'),
    ('IAF-2713','q1_fy27','statutory_compliance','GST input credit claimed on blocked services Rs 2.1 lakh','medium','possible','2026-06-02','Deepak Kulkarni',
     '2026-07-15',null,'not_retested',false,210000.00,'risk_accepted','open_on_track','Reversal planned in July GSTR-3B with interest'),
    ('IAF-2714','special_review','cash_treasury','Petty-cash floats at 4 service hubs unreconciled for 60+ days','high','probable','2026-06-18','Kavita Iyer',
     '2026-07-05',null,'ineffective',true,130000.00,'accepted_with_plan','open_overdue','KIMS Hyderabad hub float suspended; recon SOP retraining scheduled')
  ) as q(code, cyc, area, title, sev, lik, fdate, owner, tcd, acd, retest, rep, exposure, resp, verdict, nt);

  -- CAPA seed — attach to specific findings via finding code
  insert into public.internal_audit_finding_capa_actions_r3257 (
    finding_id, action_category, root_cause, corrective_action,
    capa_status, compliance_impact, target_completion_date, actual_completion_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.ac, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('IAF-2702','system_control','management_override','escalate_to_audit_committee','escalated','board_reportable','2026-07-20',null,150000.00,'ERP credit-note approval hard-block scoped with vendor'),
    ('IAF-2706','policy_update','missing_sop','update_sop_and_train','in_progress','internal_only','2026-07-30',null,45000.00,'Emergency-purchase SOP v2 in draft with three-quote waiver matrix'),
    ('IAF-2708','process_redesign','manual_process_error','deploy_asset_tagging','in_progress','board_reportable','2026-07-25',null,220000.00,'Batch-expiry barcode gating live at Hyderabad depot; Vellore rollout next'),
    ('IAF-2709','system_control','headcount_gap','deploy_asset_tagging','overdue','companies_act_filing','2026-06-30',null,180000.00,'RFID tagging vendor PO released; field-team scanning pending'),
    ('IAF-2711','access_revocation','system_access_gap','revoke_excess_access','verification_pending','iso_27001_deviation','2026-07-15',null,0.00,'Automated deprovisioning hook live; retest on next employee exit'),
    ('IAF-2712','segregation_of_duties','missing_sop','implement_maker_checker','open','iso_27001_deviation','2026-08-10',null,90000.00,'Change-approval workflow tool shortlist in review'),
    ('IAF-2714','reconciliation_control','manual_process_error','automate_reconciliation','in_progress','internal_only','2026-07-22',null,60000.00,'Daily float recon dashboard piloted at two hubs')
  ) as q(code, ac, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.internal_audit_finding_r3257 e
    on e.organization_id = v_org_id and e.finding_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Finding verdict distribution
create or replace function public.founder_r3257_finding_verdict_rollup()
returns table(finding_verdict text, findings bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.internal_audit_finding_r3257)
  select l.finding_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.internal_audit_finding_r3257 l
  group by l.finding_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3257_finding_verdict_rollup() from public, anon;
grant execute on function public.founder_r3257_finding_verdict_rollup() to authenticated;

-- 2) Control-area scorecard
create or replace function public.founder_r3257_control_area_scorecard()
returns table(
  control_area text,
  total_findings bigint,
  critical_high bigint,
  open_findings bigint,
  repeat_findings bigint,
  closed_verified bigint,
  total_exposure_rupees numeric,
  closed_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.control_area,
    count(*)::bigint,
    count(*) filter (where l.severity in ('critical','high'))::bigint,
    count(*) filter (where l.finding_verdict in ('open_on_track','open_overdue','escalated_to_board'))::bigint,
    count(*) filter (where l.repeat_finding)::bigint,
    count(*) filter (where l.finding_verdict = 'closed_verified')::bigint,
    coalesce(sum(l.estimated_exposure_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.finding_verdict in ('closed_verified','closed_unverified'))::numeric / nullif(count(*),0), 1)
  from public.internal_audit_finding_r3257 l
  group by l.control_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3257_control_area_scorecard() from public, anon;
grant execute on function public.founder_r3257_control_area_scorecard() to authenticated;

-- 3) Audit cycle × severity matrix
create or replace function public.founder_r3257_cycle_severity_matrix()
returns table(audit_cycle text, severity text, findings bigint, open_findings bigint, avg_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_cycle, l.severity, count(*)::bigint,
    count(*) filter (where l.finding_verdict in ('open_on_track','open_overdue','escalated_to_board'))::bigint,
    round(avg(l.estimated_exposure_rupees), 0)
  from public.internal_audit_finding_r3257 l
  group by l.audit_cycle, l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3257_cycle_severity_matrix() from public, anon;
grant execute on function public.founder_r3257_cycle_severity_matrix() to authenticated;

-- 4) Finding-date trend
create or replace function public.founder_r3257_finding_date_trend()
returns table(finding_date date, findings bigint, critical_high bigint, closed bigint, repeat_findings bigint, exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.finding_date,
    count(*)::bigint,
    count(*) filter (where l.severity in ('critical','high'))::bigint,
    count(*) filter (where l.finding_verdict in ('closed_verified','closed_unverified'))::bigint,
    count(*) filter (where l.repeat_finding)::bigint,
    coalesce(sum(l.estimated_exposure_rupees),0)::numeric
  from public.internal_audit_finding_r3257 l
  group by l.finding_date
  order by l.finding_date desc;
end;
$$;

revoke execute on function public.founder_r3257_finding_date_trend() from public, anon;
grant execute on function public.founder_r3257_finding_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3257_capa_status_board()
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
  from public.internal_audit_finding_capa_actions_r3257 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3257_capa_status_board() from public, anon;
grant execute on function public.founder_r3257_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3257_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.internal_audit_finding_capa_actions_r3257)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.internal_audit_finding_capa_actions_r3257 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3257_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3257_root_cause_pareto() to authenticated;

-- 7) Exposure & management-response digest
create or replace function public.founder_r3257_exposure_response_digest()
returns table(management_response text, findings bigint, open_findings bigint, total_exposure_rupees numeric, max_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.management_response, count(*)::bigint,
    count(*) filter (where l.finding_verdict in ('open_on_track','open_overdue','escalated_to_board'))::bigint,
    coalesce(sum(l.estimated_exposure_rupees),0)::numeric,
    coalesce(max(l.estimated_exposure_rupees),0)::numeric
  from public.internal_audit_finding_r3257 l
  group by l.management_response
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3257_exposure_response_digest() from public, anon;
grant execute on function public.founder_r3257_exposure_response_digest() to authenticated;

-- 8) High-risk finding queue (top individual concerns)
create or replace function public.founder_r3257_high_risk_queue()
returns table(
  finding_code text,
  control_area text,
  finding_title text,
  severity text,
  finding_date date,
  target_close_date date,
  finding_verdict text,
  retest_result text,
  estimated_exposure_rupees numeric,
  remediation_owner text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.finding_code, l.control_area, l.finding_title, l.severity,
    l.finding_date, l.target_close_date, l.finding_verdict, l.retest_result,
    l.estimated_exposure_rupees, l.remediation_owner, l.notes
  from public.internal_audit_finding_r3257 l
  where l.finding_verdict in ('open_overdue','escalated_to_board')
     or l.severity = 'critical'
     or l.retest_result = 'ineffective'
     or l.repeat_finding
  order by l.finding_date desc, l.finding_code;
end;
$$;

revoke execute on function public.founder_r3257_high_risk_queue() from public, anon;
grant execute on function public.founder_r3257_high_risk_queue() to authenticated;
