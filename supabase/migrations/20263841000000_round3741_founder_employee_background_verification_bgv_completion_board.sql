-- Round 3741: Founder Employee Background-Verification (BGV) Completion Board
-- Employee pre/post-joining background-verification completion — checks completed
-- (criminal/education/employment/address/reference), red-flags found, turnaround time,
-- vendor performance. Distinct from any investor-reference-checks page, which covers
-- investor due-diligence, not employee BGV.

-- =============================================================================
-- TABLE 1: emp_bgv_r3741 — per-employee BGV check facts
-- =============================================================================
create table if not exists public.emp_bgv_r3741 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  department text not null,
  period_month date not null,
  joining_date date,
  bgv_initiated_date date,
  bgv_completed_date date,
  days_to_complete int,
  checks_required int,
  checks_completed int,
  red_flags_found int,
  red_flag_severity text,
  vendor_name text,
  bgv_class text not null check (bgv_class in (
    'criminal_record','education_verification','employment_history','address_verification','reference_check'
  )),
  bgv_status text not null check (bgv_status in (
    'completed_clean','completed_red_flag','in_progress','overdue','vendor_delay'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.emp_bgv_r3741 enable row level security;

create index if not exists idx_emp_bgv_r3741_org on public.emp_bgv_r3741(organization_id);
create index if not exists idx_emp_bgv_r3741_month on public.emp_bgv_r3741(period_month);
create index if not exists idx_emp_bgv_r3741_status on public.emp_bgv_r3741(bgv_status);

-- =============================================================================
-- TABLE 2: emp_bgv_capa_actions_r3741 — CAPA for BGV completion gaps
-- =============================================================================
create table if not exists public.emp_bgv_capa_actions_r3741 (
  id uuid primary key default gen_random_uuid(),
  bgv_id uuid references public.emp_bgv_r3741(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.emp_bgv_capa_actions_r3741 enable row level security;

create index if not exists idx_emp_bgv_capa_r3741_bgv on public.emp_bgv_capa_actions_r3741(bgv_id);
create index if not exists idx_emp_bgv_capa_r3741_status on public.emp_bgv_capa_actions_r3741(capa_status);

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

  -- 16 employee BGV rows
  insert into public.emp_bgv_r3741 (
    organization_id, employee_name, department, period_month, joining_date,
    bgv_initiated_date, bgv_completed_date, days_to_complete, checks_required,
    checks_completed, red_flags_found, red_flag_severity, vendor_name,
    bgv_class, bgv_status, trend_dir, notes
  )
  select v_org_id, q.en, q.dept, q.pm::date, q.jd::date,
    q.bid::date, q.bcd::date, q.dtc::int, q.cr::int,
    q.cc::int, q.rff::int, q.rfs, q.vn,
    q.bc, q.bs, q.td, q.nt
  from (values
    ('Rohit Sharma','Engineering','2026-07-01','2026-06-15','2026-06-16','2026-06-28',12,5,5,0,null,'AuthBridge','criminal_record','completed_clean','stable','Clean police verification report received within SLA'),
    ('Priya Nair','Finance','2026-07-01','2026-06-20','2026-06-21','2026-07-05',14,5,5,1,'medium','SpringVerify','education_verification','completed_red_flag','worsening','Degree certificate from claimed university could not be verified — escalated to HR'),
    ('Arjun Mehta','Sales','2026-07-01','2026-07-01','2026-07-02',null,null,5,2,0,null,'AuthBridge','employment_history','in_progress','stable','Previous employer HR yet to confirm relieving date'),
    ('Sunita Reddy','Operations','2026-06-01','2026-05-10','2026-05-12',null,null,5,1,0,null,'IDfy','address_verification','overdue','worsening','Field verifier could not locate permanent address — 45 days pending'),
    ('Karan Malhotra','Field Service','2026-06-01','2026-05-20','2026-05-22',null,null,5,3,0,null,'SpringVerify','reference_check','vendor_delay','worsening','Vendor SLA breach — reference calls not attempted for 20 days'),
    ('Deepak Kulkarni','Warehouse','2026-07-01','2026-06-25','2026-06-26','2026-07-08',12,4,4,0,null,'AuthBridge','criminal_record','completed_clean','stable','Standard verification completed on schedule'),
    ('Neha Joshi','Human Resources','2026-07-01','2026-07-05','2026-07-06','2026-07-20',14,5,5,1,'high','IDfy','criminal_record','completed_red_flag','worsening','Pending criminal case disclosed post-verification — under legal review'),
    ('Vikram Singh','IT','2026-06-01','2026-06-01','2026-06-02',null,null,5,4,0,null,'SpringVerify','education_verification','in_progress','stable','Final degree-attestation pending from university registrar'),
    ('Anjali Desai','Customer Support','2026-05-01','2026-04-15','2026-04-16',null,null,5,2,0,null,'IDfy','employment_history','overdue','worsening','Two former employers non-responsive to verification requests for 60+ days'),
    ('Manoj Pillai','Marketing','2026-05-01','2026-05-01','2026-05-03',null,null,5,1,0,null,'AuthBridge','address_verification','vendor_delay','worsening','Vendor field-agent visit rescheduled thrice — no report submitted'),
    ('Ritu Chawla','Sales','2026-06-01','2026-05-25','2026-05-27','2026-06-10',14,5,5,0,null,'SpringVerify','reference_check','completed_clean','improving','Both professional references confirmed positively within SLA'),
    ('Suresh Yadav','Operations','2026-07-01','2026-07-01','2026-07-02','2026-07-22',20,5,5,1,'medium','IDfy','address_verification','completed_red_flag','worsening','Address mismatch with Aadhaar found post-relocation — flagged for HR review'),
    ('Kavita Rao','Engineering','2026-06-01','2026-06-05','2026-06-06',null,null,5,3,0,null,'AuthBridge','employment_history','in_progress','stable','Awaiting confirmation letter from second-last employer'),
    ('Rahul Bansal','Finance','2026-05-01','2026-04-20','2026-04-22',null,null,5,2,0,null,'SpringVerify','education_verification','overdue','worsening','University verification portal down for over a month — vendor escalation raised'),
    ('Pooja Iyer','Field Service','2026-07-01','2026-06-18','2026-06-19','2026-07-01',12,4,4,0,null,'IDfy','criminal_record','completed_clean','stable','Clean report — field technician cleared for deployment'),
    ('Amit Trivedi','Warehouse','2026-06-01','2026-05-15','2026-05-17',null,null,4,1,0,null,'AuthBridge','reference_check','vendor_delay','worsening','Vendor unable to reach both listed references after 15 days')
  ) as q(en, dept, pm, jd, bid, bcd, dtc, cr, cc, rff, rfs, vn, bc, bs, td, nt);

  -- 8 CAPA rows — attach to BGV rows via employee_name + department
  insert into public.emp_bgv_capa_actions_r3741 (
    bgv_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Priya Nair','Finance','Degree verification returned unable-to-verify from issuing university','Escalate to alumni-verification cell and request manual degree confirmation','in_progress','HR Compliance Lead','2026-08-20',null,'Awaiting written confirmation from university registrar before final HR sign-off'),
    ('Sunita Reddy','Operations','Field verifier unable to locate permanent address after relocation','Re-assign to local field agent and request updated address proof from employee','open','HR Ops Manager','2026-08-25',null,'Employee submitted new rental agreement — re-verification scheduled this week'),
    ('Karan Malhotra','Field Service','Vendor SLA breach — reference calls not attempted within contracted turnaround','Escalate to vendor account manager and apply SLA penalty clause','in_progress','Vendor Management Lead','2026-08-18',null,'Vendor has committed to same-week completion after escalation call'),
    ('Neha Joshi','Human Resources','Pending criminal case disclosed after verification report issued','Refer case to legal counsel for risk assessment before confirming role placement','open','Legal & Compliance Head','2026-08-22',null,'Nature of pending case under review — placement on hold pending legal opinion'),
    ('Anjali Desai','Customer Support','Former employers non-responsive to employment-verification requests','Switch to alternate verification channel using UAN-based employment history','overdue','HR Compliance Lead','2026-07-30',null,'SLA breached by 30 days — vendor escalation raised, UAN check initiated as fallback'),
    ('Manoj Pillai','Marketing','Vendor field-agent visit rescheduled three times without report submission','Switch address-verification vendor for this case and flag vendor performance','open','Vendor Management Lead','2026-08-15',null,'Alternate vendor onboarded for repeat cases in this vendor''s low-performing zone'),
    ('Suresh Yadav','Operations','Address on file did not match Aadhaar after employee relocation mid-verification','Update HR records with verified new address and note discrepancy resolution','closed','HR Ops Manager','2026-07-28','2026-07-26','Discrepancy traced to unreported relocation — records updated, no fraud indicator found'),
    ('Rahul Bansal','Finance','University verification portal outage lasting over a month','Request manual verification letter via registered post while portal remains down','in_progress','HR Compliance Lead','2026-08-30',null,'Manual letter requested — vendor also escalating portal outage with university')
  ) as q(en, dept, rc, ca, cst, ownr, tcd, acd, nt)
  join public.emp_bgv_r3741 e
    on e.organization_id = v_org_id and e.employee_name = q.en and e.department = q.dept;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) BGV-status distribution
create or replace function public.founder_r3741_bgv_status_rollup()
returns table(bgv_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.emp_bgv_r3741)
  select l.bgv_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.emp_bgv_r3741 l
  group by l.bgv_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3741_bgv_status_rollup() from public, anon;
grant execute on function public.founder_r3741_bgv_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3741_department_scorecard()
returns table(
  department text,
  records bigint,
  completed_clean bigint,
  completed_red_flag bigint,
  overdue bigint,
  vendor_delay bigint,
  avg_days_to_complete numeric,
  red_flags_total bigint
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
    count(*) filter (where l.bgv_status = 'completed_clean')::bigint,
    count(*) filter (where l.bgv_status = 'completed_red_flag')::bigint,
    count(*) filter (where l.bgv_status = 'overdue')::bigint,
    count(*) filter (where l.bgv_status = 'vendor_delay')::bigint,
    round(avg(l.days_to_complete), 1),
    coalesce(sum(l.red_flags_found),0)::bigint
  from public.emp_bgv_r3741 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3741_department_scorecard() from public, anon;
grant execute on function public.founder_r3741_department_scorecard() to authenticated;

-- 3) BGV-class × BGV-status matrix
create or replace function public.founder_r3741_bgv_class_status_matrix()
returns table(bgv_class text, bgv_status text, records bigint, avg_days_to_complete numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bgv_class, l.bgv_status, count(*)::bigint,
    round(avg(l.days_to_complete), 1)
  from public.emp_bgv_r3741 l
  group by l.bgv_class, l.bgv_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3741_bgv_class_status_matrix() from public, anon;
grant execute on function public.founder_r3741_bgv_class_status_matrix() to authenticated;

-- 4) Monthly completion trend
create or replace function public.founder_r3741_monthly_completion_trend()
returns table(
  period_month date,
  records bigint,
  completed bigint,
  avg_days_to_complete numeric,
  red_flags_total bigint,
  worsening_records bigint
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
    count(*) filter (where l.bgv_status in ('completed_clean','completed_red_flag'))::bigint,
    round(avg(l.days_to_complete), 1),
    coalesce(sum(l.red_flags_found),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.emp_bgv_r3741 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3741_monthly_completion_trend() from public, anon;
grant execute on function public.founder_r3741_monthly_completion_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3741_capa_status_board()
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
  from public.emp_bgv_capa_actions_r3741 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3741_capa_status_board() from public, anon;
grant execute on function public.founder_r3741_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3741_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.emp_bgv_capa_actions_r3741)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.emp_bgv_capa_actions_r3741 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3741_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3741_root_cause_pareto() to authenticated;

-- 7) Red-flag digest (departments with red-flag findings)
create or replace function public.founder_r3741_red_flag_digest()
returns table(
  department text,
  records bigint,
  red_flags_total bigint,
  high_severity_flags bigint,
  avg_days_to_complete numeric,
  vendor_delay_records bigint
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
    coalesce(sum(l.red_flags_found),0)::bigint,
    count(*) filter (where l.red_flag_severity = 'high')::bigint,
    round(avg(l.days_to_complete), 1),
    count(*) filter (where l.bgv_status = 'vendor_delay')::bigint
  from public.emp_bgv_r3741 l
  where l.red_flags_found > 0 or l.bgv_status = 'completed_red_flag'
  group by l.department
  order by coalesce(sum(l.red_flags_found),0) desc;
end;
$$;

revoke all on function public.founder_r3741_red_flag_digest() from public, anon;
grant execute on function public.founder_r3741_red_flag_digest() to authenticated;

-- 8) High-risk BGV queue (overdue / vendor-delay / red-flag, worst first)
create or replace function public.founder_r3741_high_risk_queue()
returns table(
  employee_name text,
  department text,
  bgv_class text,
  period_month date,
  bgv_status text,
  days_to_complete int,
  red_flags_found int,
  red_flag_severity text,
  vendor_name text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l.bgv_class, l.period_month,
    l.bgv_status, l.days_to_complete, l.red_flags_found, l.red_flag_severity,
    l.vendor_name, l.notes
  from public.emp_bgv_r3741 l
  where l.bgv_status in ('overdue','vendor_delay','completed_red_flag')
  order by l.days_to_complete desc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3741_high_risk_queue() from public, anon;
grant execute on function public.founder_r3741_high_risk_queue() to authenticated;
