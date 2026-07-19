-- Round 3337: Founder Salary-Advance, Employee-Loan & Advance-Recovery Governance Board
-- HR-finance — advance type × department × recovery status × payroll-deduction health × exit exposure × CAPA recovery/adjustment/write-off

-- =============================================================================
-- TABLE 1: salary_advance_loan_r3337 — per advance / employee-loan ledger
-- =============================================================================
create table if not exists public.salary_advance_loan_r3337 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  department text not null check (department in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  advance_type text not null check (advance_type in (
    'salary_advance','festival_advance','emergency_medical_loan','travel_advance','tool_purchase_loan','relocation_advance'
  )),
  principal_rupees numeric(12,2) not null,
  disbursed_date date not null,
  monthly_deduction_rupees numeric(12,2) not null,
  tenure_months int not null,
  recovered_rupees numeric(12,2) not null,
  outstanding_rupees numeric(12,2) not null,
  installments_remaining int not null,
  deduction_on_track boolean not null,
  employee_status text not null check (employee_status in (
    'active','notice_period','exited','absconding'
  )),
  recovery_risk text not null check (recovery_risk in (
    'low','medium','high','at_exit_risk','write_off_candidate'
  )),
  recovery_verdict text not null check (recovery_verdict in (
    'on_track','ahead','behind_schedule','recover_at_fnf','escalate','write_off_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.salary_advance_loan_r3337 enable row level security;

create index if not exists idx_salary_advance_loan_r3337_org on public.salary_advance_loan_r3337(organization_id);
create index if not exists idx_salary_advance_loan_r3337_date on public.salary_advance_loan_r3337(disbursed_date);
create index if not exists idx_salary_advance_loan_r3337_verdict on public.salary_advance_loan_r3337(recovery_verdict);

-- =============================================================================
-- TABLE 2: salary_advance_loan_capa_actions_r3337 — recovery / adjustment / write-off actions
-- =============================================================================
create table if not exists public.salary_advance_loan_capa_actions_r3337 (
  id uuid primary key default gen_random_uuid(),
  advance_id uuid not null references public.salary_advance_loan_r3337(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'deduction_missed','deduction_shortfall','exit_without_recovery','absconding_balance',
    'tenure_overrun','excess_deduction_refund','documentation_gap','fnf_adjustment_pending'
  )),
  root_cause text not null check (root_cause in (
    'payroll_setup_error','insufficient_salary_balance','employee_resignation','employee_absconding',
    'manual_tracking_lapse','policy_exception_unapproved','system_deduction_bug','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'resume_payroll_deduction','increase_monthly_deduction','recover_from_fnf','issue_demand_notice',
    'restructure_repayment_plan','refund_excess_deduction','legal_recovery_notice','write_off_approved','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_exposure text not null check (financial_exposure in (
    'fully_recoverable','partial_recovery','at_exit_risk','write_off_likely','provisioned','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_amount_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.salary_advance_loan_capa_actions_r3337 enable row level security;

create index if not exists idx_salary_advance_loan_capa_r3337_advance on public.salary_advance_loan_capa_actions_r3337(advance_id);
create index if not exists idx_salary_advance_loan_capa_r3337_status on public.salary_advance_loan_capa_actions_r3337(capa_status);

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

  -- 14 advance / employee-loan rows
  insert into public.salary_advance_loan_r3337 (
    organization_id, employee_name, department, advance_type,
    principal_rupees, disbursed_date, monthly_deduction_rupees, tenure_months,
    recovered_rupees, outstanding_rupees, installments_remaining, deduction_on_track,
    employee_status, recovery_risk, recovery_verdict, notes
  )
  select v_org_id, q.emp, q.dept, q.atype,
    q.prin, q.ddate::date, q.mdd, q.tenure,
    q.recov, q.outst, q.instrem, q.ontrack,
    q.estatus, q.risk, q.verdict, q.nt
  from (values
    ('Ramesh Kumar','field_engineering','tool_purchase_loan',
     45000.00,'2026-01-15',5000.00,9,30000.00,15000.00,3,true,
     'active','low','on_track','Toolkit loan for Chennai field kit — deductions current'),
    ('Priya Nair','office_ops','salary_advance',
     30000.00,'2026-03-01',10000.00,3,20000.00,10000.00,1,true,
     'active','low','on_track','One-month salary advance — final installment next cycle'),
    ('Anil Deshpande','sales','travel_advance',
     25000.00,'2026-04-10',5000.00,5,5000.00,20000.00,4,false,
     'notice_period','at_exit_risk','recover_at_fnf','Serving notice — balance to be recovered at full-and-final'),
    ('Sunil Verma','field_engineering','festival_advance',
     20000.00,'2025-10-20',4000.00,5,8000.00,12000.00,3,false,
     'active','medium','behind_schedule','Two payroll deductions missed — deduction restart pending'),
    ('Kavita Reddy','finance','emergency_medical_loan',
     100000.00,'2025-12-01',8000.00,13,56000.00,44000.00,6,true,
     'active','low','on_track','Medical loan for family surgery — on schedule'),
    ('Manoj Gupta','sales','salary_advance',
     40000.00,'2026-02-15',8000.00,5,40000.00,0.00,0,true,
     'active','low','ahead','Cleared early via voluntary lump-sum — fully recovered'),
    ('Deepak Sharma','field_engineering','relocation_advance',
     60000.00,'2025-09-05',5000.00,12,20000.00,40000.00,8,false,
     'absconding','write_off_candidate','write_off_review','Absconded from Hyderabad posting — no contact, legal review'),
    ('Lakshmi Menon','support','salary_advance',
     15000.00,'2026-05-01',7500.00,2,0.00,15000.00,2,true,
     'active','low','on_track','Fresh advance — first deduction due this cycle'),
    ('Rahul Joshi','leadership','tool_purchase_loan',
     80000.00,'2025-11-10',6000.00,14,48000.00,32000.00,5,true,
     'active','low','on_track','Diagnostic-tool loan for regional lead — deductions current'),
    ('Sneha Iyer','office_ops','emergency_medical_loan',
     50000.00,'2026-01-20',5000.00,10,20000.00,30000.00,6,false,
     'notice_period','at_exit_risk','recover_at_fnf','Resigned mid-tenure — FnF settlement to absorb balance'),
    ('Vikram Singh','sales','travel_advance',
     18000.00,'2026-06-01',9000.00,2,0.00,18000.00,2,true,
     'active','low','on_track','Client-tour travel float — deductions start next payroll'),
    ('Arjun Pillai','field_engineering','festival_advance',
     22000.00,'2025-08-15',4000.00,6,8000.00,14000.00,4,false,
     'exited','high','escalate','Exited with short FnF — residual balance pending demand notice'),
    ('Neha Kulkarni','finance','salary_advance',
     35000.00,'2026-03-20',11667.00,3,23334.00,11666.00,1,true,
     'active','low','on_track','Salary advance — minor excess-deduction refund reconciled'),
    ('Sanjay Rao','support','relocation_advance',
     55000.00,'2025-10-01',5000.00,11,15000.00,40000.00,8,false,
     'absconding','write_off_candidate','write_off_review','Untraceable after relocation payout — write-off provisioned')
  ) as q(emp, dept, atype, prin, ddate, mdd, tenure, recov, outst, instrem, ontrack, estatus, risk, verdict, nt);

  -- CAPA seed — recovery / adjustment / write-off actions on at-risk advances
  insert into public.salary_advance_loan_capa_actions_r3337 (
    advance_id, finding_category, root_cause, corrective_action,
    capa_status, financial_exposure, target_closure_date, actual_closure_date,
    estimated_amount_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fe, q.tcd::date, q.acd::date,
    q.amt, q.nt
  from (values
    ('Anil Deshpande','fnf_adjustment_pending','employee_resignation','recover_from_fnf','in_progress','at_exit_risk','2026-08-15',null,20000.00,'Balance flagged to payroll for FnF recovery'),
    ('Sunil Verma','deduction_missed','payroll_setup_error','resume_payroll_deduction','open','partial_recovery','2026-08-05',null,12000.00,'Deduction mapping was disabled — re-enable and backfill'),
    ('Deepak Sharma','absconding_balance','employee_absconding','legal_recovery_notice','escalated','write_off_likely','2026-07-30',null,40000.00,'Sent to legal for recovery notice — likely write-off'),
    ('Sneha Iyer','fnf_adjustment_pending','employee_resignation','recover_from_fnf','verification_pending','at_exit_risk','2026-08-10',null,30000.00,'FnF held pending confirmation of residual balance'),
    ('Arjun Pillai','exit_without_recovery','insufficient_salary_balance','issue_demand_notice','overdue','partial_recovery','2026-07-10',null,14000.00,'FnF insufficient — demand notice past target date'),
    ('Sanjay Rao','absconding_balance','employee_absconding','write_off_approved','closed','provisioned','2026-07-05','2026-07-12',40000.00,'Write-off approved by finance and board — provisioned'),
    ('Neha Kulkarni','excess_deduction_refund','system_deduction_bug','refund_excess_deduction','closed','none','2026-07-01','2026-07-03',2000.00,'Rounding bug over-deducted one cycle — refunded')
  ) as q(emp, fc, rc, ca, cst, fe, tcd, acd, amt, nt)
  join public.salary_advance_loan_r3337 e
    on e.organization_id = v_org_id and e.employee_name = q.emp;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recovery verdict distribution
create or replace function public.founder_r3337_recovery_verdict_rollup()
returns table(recovery_verdict text, advances bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.salary_advance_loan_r3337)
  select l.recovery_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.salary_advance_loan_r3337 l
  group by l.recovery_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3337_recovery_verdict_rollup() from public, anon;
grant execute on function public.founder_r3337_recovery_verdict_rollup() to authenticated;

-- 2) Department-level recovery scorecard
create or replace function public.founder_r3337_department_scorecard()
returns table(
  department text,
  total_advances bigint,
  on_track bigint,
  behind bigint,
  escalate_writeoff bigint,
  at_risk bigint,
  total_outstanding_rupees numeric,
  recovered_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    count(*) filter (where l.recovery_verdict in ('on_track','ahead'))::bigint,
    count(*) filter (where l.recovery_verdict = 'behind_schedule')::bigint,
    count(*) filter (where l.recovery_verdict in ('escalate','write_off_review'))::bigint,
    count(*) filter (where l.recovery_risk in ('high','at_exit_risk','write_off_candidate'))::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.recovered_rupees),0)::numeric / nullif(sum(l.principal_rupees),0), 1)
  from public.salary_advance_loan_r3337 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3337_department_scorecard() from public, anon;
grant execute on function public.founder_r3337_department_scorecard() to authenticated;

-- 3) Department × advance-type matrix
create or replace function public.founder_r3337_dept_advance_type_matrix()
returns table(department text, advance_type text, advances bigint, total_principal_rupees numeric, total_outstanding_rupees numeric, on_track bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, l.advance_type, count(*)::bigint,
    coalesce(sum(l.principal_rupees),0)::numeric,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    count(*) filter (where l.deduction_on_track)::bigint
  from public.salary_advance_loan_r3337 l
  group by l.department, l.advance_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3337_dept_advance_type_matrix() from public, anon;
grant execute on function public.founder_r3337_dept_advance_type_matrix() to authenticated;

-- 4) Daily disbursal trend
create or replace function public.founder_r3337_disbursal_trend()
returns table(disbursed_date date, advances bigint, principal_disbursed_rupees numeric, outstanding_rupees numeric, off_track bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.disbursed_date,
    count(*)::bigint,
    coalesce(sum(l.principal_rupees),0)::numeric,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    count(*) filter (where l.deduction_on_track = false)::bigint
  from public.salary_advance_loan_r3337 l
  group by l.disbursed_date
  order by l.disbursed_date desc;
end;
$$;

revoke execute on function public.founder_r3337_disbursal_trend() from public, anon;
grant execute on function public.founder_r3337_disbursal_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3337_capa_status_board()
returns table(capa_status text, findings bigint, avg_amount_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.salary_advance_loan_capa_actions_r3337 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3337_capa_status_board() from public, anon;
grant execute on function public.founder_r3337_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3337_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_amount_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.salary_advance_loan_capa_actions_r3337)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.salary_advance_loan_capa_actions_r3337 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3337_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3337_root_cause_pareto() to authenticated;

-- 7) Financial-exposure digest (cost / risk)
create or replace function public.founder_r3337_exposure_digest()
returns table(financial_exposure text, findings bigint, open_findings bigint, total_amount_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_exposure, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_amount_rupees),0)::numeric
  from public.salary_advance_loan_capa_actions_r3337 c
  group by c.financial_exposure
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3337_exposure_digest() from public, anon;
grant execute on function public.founder_r3337_exposure_digest() to authenticated;

-- 8) High-risk recovery queue (individual concerns)
create or replace function public.founder_r3337_high_risk_queue()
returns table(
  employee_name text,
  department text,
  advance_type text,
  disbursed_date date,
  outstanding_rupees numeric,
  installments_remaining int,
  employee_status text,
  recovery_risk text,
  recovery_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l.advance_type, l.disbursed_date,
    l.outstanding_rupees, l.installments_remaining, l.employee_status,
    l.recovery_risk, l.recovery_verdict, l.notes
  from public.salary_advance_loan_r3337 l
  where l.recovery_verdict in ('behind_schedule','recover_at_fnf','escalate','write_off_review')
     or l.recovery_risk in ('medium','high','at_exit_risk','write_off_candidate')
     or l.employee_status in ('notice_period','exited','absconding')
     or l.deduction_on_track = false
  order by l.outstanding_rupees desc, l.disbursed_date desc;
end;
$$;

revoke execute on function public.founder_r3337_high_risk_queue() from public, anon;
grant execute on function public.founder_r3337_high_risk_queue() to authenticated;
