-- Round 3749: Founder Statutory Maternity-Benefit / Creche-Facility Board
-- Maternity Benefit Act & creche-facility compliance — leave entitlement usage, pay
-- continuity through leave, on-site/partner creche availability & utilization, and
-- return-to-work outcomes per employee, department and month.

-- =============================================================================
-- TABLE 1: maternity_bnft_r3749 — per-employee maternity-benefit / creche facts
-- =============================================================================
create table if not exists public.maternity_bnft_r3749 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  department text not null,
  period_month date not null,
  leave_start_date date,
  leave_entitled_days int,
  leave_availed_days int,
  pay_continuity_verified boolean not null,
  creche_facility_used boolean not null,
  creche_utilization_pct numeric,
  return_to_work_date date,
  return_to_work_status text,
  benefit_class text not null check (benefit_class in (
    'maternity_leave','creche_facility','work_from_home_transition','nursing_break','adoption_leave'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','leave_in_progress','pay_discrepancy','creche_unavailable','return_overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.maternity_bnft_r3749 enable row level security;

create index if not exists idx_maternity_bnft_r3749_org on public.maternity_bnft_r3749(organization_id);
create index if not exists idx_maternity_bnft_r3749_month on public.maternity_bnft_r3749(period_month);
create index if not exists idx_maternity_bnft_r3749_status on public.maternity_bnft_r3749(compliance_status);

-- =============================================================================
-- TABLE 2: maternity_bnft_capa_actions_r3749 — CAPA for pay/leave/creche gaps
-- =============================================================================
create table if not exists public.maternity_bnft_capa_actions_r3749 (
  id uuid primary key default gen_random_uuid(),
  benefit_id uuid references public.maternity_bnft_r3749(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.maternity_bnft_capa_actions_r3749 enable row level security;

create index if not exists idx_maternity_bnft_capa_r3749_main on public.maternity_bnft_capa_actions_r3749(benefit_id);
create index if not exists idx_maternity_bnft_capa_r3749_status on public.maternity_bnft_capa_actions_r3749(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3749_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.maternity_bnft_r3749)
  select l.compliance_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.maternity_bnft_r3749 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

-- 2) Department scorecard
create or replace function public.founder_r3749_department_scorecard()
returns table(
  department text,
  records bigint,
  compliant bigint,
  leave_in_progress bigint,
  pay_discrepancy bigint,
  creche_unavailable bigint,
  return_overdue bigint,
  avg_leave_availed_days numeric,
  avg_creche_utilization_pct numeric
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
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'leave_in_progress')::bigint,
    count(*) filter (where l.compliance_status = 'pay_discrepancy')::bigint,
    count(*) filter (where l.compliance_status = 'creche_unavailable')::bigint,
    count(*) filter (where l.compliance_status = 'return_overdue')::bigint,
    round(avg(l.leave_availed_days), 1),
    round(avg(l.creche_utilization_pct), 1)
  from public.maternity_bnft_r3749 l
  group by l.department
  order by count(*) desc;
end;
$$;

-- 3) Benefit-class x compliance-status matrix
create or replace function public.founder_r3749_benefit_class_status_matrix()
returns table(benefit_class text, compliance_status text, records bigint, avg_leave_availed_days numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.benefit_class, l.compliance_status, count(*)::bigint,
    round(avg(l.leave_availed_days), 1)
  from public.maternity_bnft_r3749 l
  group by l.benefit_class, l.compliance_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly leave trend
create or replace function public.founder_r3749_monthly_leave_trend()
returns table(
  period_month date,
  records bigint,
  leave_entitled_days_total bigint,
  leave_availed_days_total bigint,
  pay_discrepancy_records bigint,
  return_overdue_records bigint
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
    coalesce(sum(l.leave_entitled_days), 0)::bigint,
    coalesce(sum(l.leave_availed_days), 0)::bigint,
    count(*) filter (where l.compliance_status = 'pay_discrepancy')::bigint,
    count(*) filter (where l.compliance_status = 'return_overdue')::bigint
  from public.maternity_bnft_r3749 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3749_capa_status_board()
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
  from public.maternity_bnft_capa_actions_r3749 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3749_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.maternity_bnft_capa_actions_r3749)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.maternity_bnft_capa_actions_r3749 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Pay-discrepancy digest by department
create or replace function public.founder_r3749_pay_discrepancy_digest()
returns table(
  department text,
  records bigint,
  pay_discrepancy_records bigint,
  avg_leave_availed_days numeric,
  avg_creche_utilization_pct numeric
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
    count(*) filter (where l.compliance_status = 'pay_discrepancy')::bigint,
    round(avg(l.leave_availed_days), 1),
    round(avg(l.creche_utilization_pct), 1)
  from public.maternity_bnft_r3749 l
  where l.compliance_status = 'pay_discrepancy'
  group by l.department
  order by count(*) desc;
end;
$$;

-- 8) High-risk queue (pay-discrepancy / return-overdue, worst first)
create or replace function public.founder_r3749_high_risk_queue()
returns table(
  employee_name text,
  department text,
  period_month date,
  benefit_class text,
  compliance_status text,
  return_to_work_date date,
  return_to_work_status text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l.period_month, l.benefit_class,
    l.compliance_status, l.return_to_work_date, l.return_to_work_status, l.notes
  from public.maternity_bnft_r3749 l
  where l.compliance_status in ('pay_discrepancy','return_overdue')
  order by l.period_month desc, l.employee_name asc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3749_compliance_status_rollup() from public, anon;
revoke all on function public.founder_r3749_department_scorecard() from public, anon;
revoke all on function public.founder_r3749_benefit_class_status_matrix() from public, anon;
revoke all on function public.founder_r3749_monthly_leave_trend() from public, anon;
revoke all on function public.founder_r3749_capa_status_board() from public, anon;
revoke all on function public.founder_r3749_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3749_pay_discrepancy_digest() from public, anon;
revoke all on function public.founder_r3749_high_risk_queue() from public, anon;

grant execute on function public.founder_r3749_compliance_status_rollup() to authenticated;
grant execute on function public.founder_r3749_department_scorecard() to authenticated;
grant execute on function public.founder_r3749_benefit_class_status_matrix() to authenticated;
grant execute on function public.founder_r3749_monthly_leave_trend() to authenticated;
grant execute on function public.founder_r3749_capa_status_board() to authenticated;
grant execute on function public.founder_r3749_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3749_pay_discrepancy_digest() to authenticated;
grant execute on function public.founder_r3749_high_risk_queue() to authenticated;

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

  -- 16 maternity-benefit / creche rows across employees, departments & months
  insert into public.maternity_bnft_r3749 (
    organization_id, employee_name, department, period_month, leave_start_date,
    leave_entitled_days, leave_availed_days, pay_continuity_verified, creche_facility_used,
    creche_utilization_pct, return_to_work_date, return_to_work_status, benefit_class,
    compliance_status, trend_dir, notes
  )
  select v_org_id, q.en, q.dept, q.pm::date, q.lsd::date,
    q.led, q.lad, q.pcv, q.cfu,
    q.cup, q.rtwd::date, q.rtws, q.bc,
    q.cs, q.td, q.nt
  from (values
    ('Priya Sharma','Engineering','2026-07-01','2026-04-10',182,90,true,false,null,null,'leave_ongoing','maternity_leave','leave_in_progress','stable','On statutory 26-week maternity leave; pay credited on schedule each cycle'),
    ('Anjali Verma','Operations','2026-07-01','2026-01-05',182,182,true,true,78.5,'2026-07-06','resumed_full_time','maternity_leave','compliant','improving','Returned to work on schedule; infant enrolled in on-site creche within a week'),
    ('Kavita Rao','Customer Support','2026-06-01','2025-12-01',182,182,false,false,null,'2026-06-02','resumed_full_time','maternity_leave','pay_discrepancy','worsening','Post-return salary missing statutory bonus component for two consecutive cycles'),
    ('Sunita Iyer','Finance','2026-07-01',null,null,null,true,true,45.0,null,'active_user','creche_facility','creche_unavailable','worsening','On-site creche over capacity — enrolment capped at 45% attendance due to waitlist rationing'),
    ('Meera Nair','Human Resources','2026-06-01','2025-11-15',182,182,true,false,null,'2026-05-20','delayed_return','maternity_leave','return_overdue','worsening','Approved return date passed three weeks ago without a formal extension on file'),
    ('Deepika Menon','Sales','2026-07-01',null,null,null,true,false,null,null,'not_applicable','work_from_home_transition','compliant','stable','Two-month phased WFH transition post-return approved and progressing on schedule'),
    ('Radhika Pillai','Product','2026-07-01',null,null,12,true,false,null,'2026-06-01','resumed_full_time','nursing_break','compliant','improving','Two daily 30-minute nursing breaks logged consistently since return'),
    ('Shalini Gupta','Quality Assurance','2026-06-01','2026-05-01',182,45,true,false,null,null,'leave_ongoing','adoption_leave','leave_in_progress','stable','Adoption leave for infant under one year progressing per policy'),
    ('Neha Kulkarni','Engineering','2026-05-01','2025-10-01',182,182,false,true,62.0,'2026-04-05','resumed_full_time','maternity_leave','pay_discrepancy','worsening','Creche subsidy reimbursement pending since March — flagged to payroll twice'),
    ('Ritu Chawla','Operations','2026-05-01',null,null,null,true,true,88.0,null,'active_user','creche_facility','compliant','improving','High and steady attendance at the partner creche near the Andheri facility'),
    ('Farah Sheikh','Finance','2026-06-01','2026-01-20',182,182,true,false,null,'2026-06-01','resumed_full_time','maternity_leave','compliant','stable','Clean return-to-work with full pay continuity maintained across the leave period'),
    ('Pooja Bhatt','Customer Support','2026-07-01',null,null,null,true,true,30.0,null,'active_user','creche_facility','creche_unavailable','worsening','Vendor-run creche shut two days a week for renovation — attendance dropped sharply'),
    ('Aditi Joshi','Human Resources','2026-07-01',null,null,20,true,false,null,'2026-06-15','resumed_full_time','nursing_break','leave_in_progress','stable','Nursing-break schedule under review to align with the new shift roster'),
    ('Tanvi Deshmukh','Sales','2026-05-01','2025-08-01',182,182,true,false,null,'2026-02-01','delayed_return','maternity_leave','return_overdue','worsening','Return delayed beyond approved extension pending a medical fitness certificate'),
    ('Sneha Reddy','Product','2026-06-01',null,null,null,true,false,null,null,'not_applicable','work_from_home_transition','leave_in_progress','stable','WFH transition plan drafted; awaiting manager sign-off before the start date'),
    ('Vidya Krishnan','Quality Assurance','2026-07-01','2026-02-10',182,182,false,false,null,'2026-07-01','resumed_full_time','adoption_leave','pay_discrepancy','worsening','Adoption-leave pay component missing the statutory allowance since return')
  ) as q(en, dept, pm, lsd, led, lad, pcv, cfu, cup, rtwd, rtws, bc, cs, td, nt);

  -- 8 CAPA rows — attach to benefit rows via employee_name + period_month
  insert into public.maternity_bnft_capa_actions_r3749 (
    benefit_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Kavita Rao','2026-06-01','Payroll system did not apply the statutory maternity bonus component post-return','Reconcile payroll register and issue arrears for the missed bonus cycles','in_progress','Payroll Manager','2026-08-25',null,'Arrears calculation underway for two missed cycles; disbursement pending finance sign-off'),
    ('Neha Kulkarni','2026-05-01','Creche subsidy reimbursement claim stuck in the manual approval queue','Escalate the reimbursement claim to the finance controller and automate future subsidy payouts','open','HR Business Partner','2026-08-20',null,'Claim escalated this week; automation ticket raised with the payroll vendor'),
    ('Vidya Krishnan','2026-07-01','Adoption-leave statutory allowance was not mapped in the payroll template','Update the payroll template to include the adoption-leave allowance and reprocess the pay run','closed','Payroll Manager','2026-07-20','2026-07-18','Template corrected and arrears paid within the same pay cycle'),
    ('Sunita Iyer','2026-07-01','On-site creche enrolment exceeded sanctioned capacity for the floor','Negotiate additional capacity with the facility vendor and introduce a rotating waitlist','in_progress','Admin & Facilities Head','2026-09-10',null,'Vendor in talks to add six seats; interim rotation roster published'),
    ('Pooja Bhatt','2026-07-01','Vendor-run creche closed two days weekly for renovation without prior notice','Arrange a temporary backup creche tie-up for the renovation period and notify affected parents','open','Admin & Facilities Head','2026-08-30',null,'Backup vendor shortlisted; formal tie-up agreement being finalised'),
    ('Meera Nair','2026-06-01','Return-to-work extension request was not formally logged in the HRMS','Regularise the extension in HRMS and set an automated return-date reminder','overdue','HR Business Partner','2026-07-31',null,'SLA breached by two weeks; employee''s manager yet to confirm revised return plan'),
    ('Tanvi Deshmukh','2026-05-01','Medical fitness certificate for the extended return was delayed by the treating physician','Follow up with the employee for the fitness certificate and process the return administratively pending receipt','in_progress','HR Business Partner','2026-08-22',null,'Employee has requested one more week; interim WFH arrangement offered'),
    ('Shalini Gupta','2026-06-01','Adoption-leave pay continuity checks had not yet been scheduled mid-leave','Schedule a mid-leave payroll continuity check and confirm the statutory pay credit','closed','Payroll Manager','2026-07-15','2026-07-12','Continuity check completed; pay credited correctly for the period')
  ) as q(en, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.maternity_bnft_r3749 e
    on e.organization_id = v_org_id and e.employee_name = q.en and e.period_month = q.pm::date;
end;
$seed$;
