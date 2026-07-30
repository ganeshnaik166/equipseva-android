-- Round 3617: Founder Employee Advance / Imprest Settlement Aging Board
-- Employee advance / imprest finance — advance type × department × period month × issued/settled/outstanding/overdue rupees × days outstanding × aging bucket × settlement status × trend × CAPA recovery actions

-- =============================================================================
-- TABLE 1: emp_advance_r3617 — per-advance imprest settlement + aging fact table
-- =============================================================================
create table if not exists public.emp_advance_r3617 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  advance_ref text not null,
  employee_name text not null,
  department text not null,
  period_month date not null,
  advance_issued_rupees numeric(14,2) not null,
  advance_settled_rupees numeric(14,2) not null,
  advance_outstanding_rupees numeric(14,2) not null,
  overdue_rupees numeric(14,2) not null,
  days_outstanding int not null,
  advance_type text not null check (advance_type in (
    'travel','imprest','project','medical','salary_advance'
  )),
  aging_bucket text not null check (aging_bucket in (
    '0_15_days','16_45_days','46_90_days','over_90_days'
  )),
  settlement_status text not null check (settlement_status in (
    'settled','on_track','overdue','escalated','recovery_from_salary'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.emp_advance_r3617 enable row level security;

create index if not exists idx_emp_advance_r3617_org on public.emp_advance_r3617(organization_id);
create index if not exists idx_emp_advance_r3617_month on public.emp_advance_r3617(period_month);
create index if not exists idx_emp_advance_r3617_status on public.emp_advance_r3617(settlement_status);

-- =============================================================================
-- TABLE 2: emp_advance_capa_actions_r3617 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.emp_advance_capa_actions_r3617 (
  id uuid primary key default gen_random_uuid(),
  advance_id uuid not null references public.emp_advance_r3617(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'advance_overdue','settlement_delay','documentation_missing','excess_advance',
    'recovery_pending','policy_breach','duplicate_advance','ageing_beyond_policy'
  )),
  root_cause text not null check (root_cause in (
    'employee_separation_pending','missing_bills','travel_extended','project_delay',
    'manual_tracking_gap','policy_non_compliance','vendor_payment_pending',
    'approval_bottleneck','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recover_from_salary','collect_supporting_bills','issue_reminder_notice','escalate_to_hr',
    'write_off_with_approval','adjust_against_reimbursement','tighten_advance_policy',
    'automate_aging_alerts','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.emp_advance_capa_actions_r3617 enable row level security;

create index if not exists idx_emp_advance_capa_r3617_advance on public.emp_advance_capa_actions_r3617(advance_id);
create index if not exists idx_emp_advance_capa_r3617_status on public.emp_advance_capa_actions_r3617(capa_status);

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

  -- 16 advance rows
  insert into public.emp_advance_r3617 (
    organization_id, advance_ref, employee_name, department, period_month,
    advance_issued_rupees, advance_settled_rupees, advance_outstanding_rupees, overdue_rupees,
    days_outstanding, advance_type, aging_bucket, settlement_status, trend_dir, notes
  )
  select v_org_id, q.aref, q.emp, q.dept, q.pm::date,
    q.iss, q.setl, q.outs, q.ovd,
    q.dio, q.atype, q.abkt, q.sstat, q.trend, q.nt
  from (values
    ('ADV-2607-01','Ramesh Kumar','field_service','2026-07-01',
     45000,45000,0,0,8,'travel','0_15_days','settled','improving','Field-service travel advance fully settled with bills'),
    ('ADV-2607-02','Priya Nair','sales','2026-07-01',
     60000,40000,20000,0,12,'travel','0_15_days','on_track','stable','Sales tour advance partly settled, within window'),
    ('ADV-2606-03','Anil Deshmukh','projects','2026-06-01',
     250000,120000,130000,130000,62,'project','46_90_days','overdue','worsening','Project site imprest overdue beyond 45 days'),
    ('ADV-2606-04','Sunita Rao','procurement','2026-06-01',
     80000,80000,0,0,5,'imprest','0_15_days','settled','stable','Procurement petty-cash imprest settled'),
    ('ADV-2605-05','Vikram Singh','field_service','2026-05-01',
     35000,10000,25000,25000,95,'medical','over_90_days','escalated','worsening','Medical advance unrecovered, employee on long leave — escalated'),
    ('ADV-2607-06','Meena Iyer','admin','2026-07-01',
     20000,15000,5000,0,10,'imprest','0_15_days','on_track','stable','Office admin imprest, minor balance pending bills'),
    ('ADV-2606-07','Karthik Menon','projects','2026-06-01',
     150000,60000,90000,90000,55,'project','46_90_days','overdue','worsening','Project advance aging, contractor bills awaited'),
    ('ADV-2606-08','Deepa Shetty','sales','2026-06-01',
     55000,30000,25000,25000,40,'travel','16_45_days','overdue','stable','Sales advance overdue, reminder issued'),
    ('ADV-2605-09','Rahul Verma','logistics','2026-05-01',
     40000,0,40000,40000,110,'salary_advance','over_90_days','recovery_from_salary','worsening','Salary advance being recovered in installments'),
    ('ADV-2607-10','Sneha Joshi','finance','2026-07-01',
     30000,30000,0,0,6,'imprest','0_15_days','settled','improving','Finance dept imprest settled promptly'),
    ('ADV-2606-11','Arjun Pillai','field_service','2026-06-01',
     48000,20000,28000,28000,38,'travel','16_45_days','overdue','worsening','AMC service tour advance overdue, bills pending'),
    ('ADV-2606-12','Lakshmi Menon','projects','2026-06-01',
     200000,200000,0,0,20,'project','16_45_days','settled','improving','Large project imprest fully settled after milestone'),
    ('ADV-2605-13','Suresh Babu','procurement','2026-05-01',
     70000,25000,45000,45000,88,'imprest','46_90_days','escalated','worsening','Procurement imprest aging, vendor dispute — escalated'),
    ('ADV-2607-14','Nisha Agarwal','sales','2026-07-01',
     25000,18000,7000,0,9,'travel','0_15_days','on_track','stable','Sales advance on track within policy window'),
    ('ADV-2606-15','Ganesh Iyer','admin','2026-06-01',
     15000,5000,10000,10000,50,'medical','46_90_days','overdue','stable','Medical advance overdue, documentation missing'),
    ('ADV-2605-16','Pooja Reddy','logistics','2026-05-01',
     90000,30000,60000,60000,120,'project','over_90_days','escalated','worsening','Logistics project advance severely aged — escalated to HR')
  ) as q(aref, emp, dept, pm, iss, setl, outs, ovd, dio, atype, abkt, sstat, trend, nt);

  -- CAPA seed — attach to specific advances via advance_ref
  insert into public.emp_advance_capa_actions_r3617 (
    advance_id, finding_category, root_cause, corrective_action,
    capa_status, recovery_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('ADV-2606-03','advance_overdue','project_delay','issue_reminder_notice','in_progress',130000,'Anita Verma','2026-07-20',null,'Project imprest reminder issued, awaiting contractor bills'),
    ('ADV-2605-05','recovery_pending','employee_separation_pending','recover_from_salary','escalated',25000,'HR Team','2026-07-15',null,'Medical advance recovery from final settlement'),
    ('ADV-2606-07','settlement_delay','vendor_payment_pending','collect_supporting_bills','open',90000,'Karthik Menon','2026-07-25',null,'Awaiting contractor invoices for project advance'),
    ('ADV-2606-08','advance_overdue','missing_bills','issue_reminder_notice','verification_pending',25000,'Sales Admin','2026-07-18',null,'Reminder sent, bills submission pending verification'),
    ('ADV-2605-09','recovery_pending','employee_separation_pending','recover_from_salary','in_progress',40000,'Payroll','2026-08-01',null,'Salary recovery in 3 installments underway'),
    ('ADV-2605-13','ageing_beyond_policy','approval_bottleneck','escalate_to_hr','escalated',45000,'Finance Head','2026-07-12',null,'Procurement dispute escalated for write-off decision'),
    ('ADV-2606-15','documentation_missing','missing_bills','collect_supporting_bills','overdue',10000,'Admin Lead','2026-07-10',null,'Medical bills not submitted past target date'),
    ('ADV-2605-16','ageing_beyond_policy','manual_tracking_gap','automate_aging_alerts','closed',60000,'Ops Team','2026-07-05','2026-07-08','Aged advance recovered and aging alerts automated')
  ) as q(aref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.emp_advance_r3617 e
    on e.organization_id = v_org_id and e.advance_ref = q.aref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Settlement status distribution
create or replace function public.founder_r3617_settlement_status_rollup()
returns table(settlement_status text, advances bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.emp_advance_r3617)
  select l.settlement_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.emp_advance_r3617 l
  group by l.settlement_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3617_settlement_status_rollup() from public, anon;
grant execute on function public.founder_r3617_settlement_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3617_department_scorecard()
returns table(
  department text,
  total_advances bigint,
  settled bigint,
  on_track bigint,
  overdue bigint,
  escalated bigint,
  recovery_from_salary bigint,
  total_issued_rupees numeric,
  total_outstanding_rupees numeric,
  total_overdue_rupees numeric,
  settled_pct numeric
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
    count(*) filter (where l.settlement_status = 'settled')::bigint,
    count(*) filter (where l.settlement_status = 'on_track')::bigint,
    count(*) filter (where l.settlement_status = 'overdue')::bigint,
    count(*) filter (where l.settlement_status = 'escalated')::bigint,
    count(*) filter (where l.settlement_status = 'recovery_from_salary')::bigint,
    coalesce(sum(l.advance_issued_rupees),0)::numeric,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.settlement_status = 'settled')::numeric / nullif(count(*),0), 1)
  from public.emp_advance_r3617 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3617_department_scorecard() from public, anon;
grant execute on function public.founder_r3617_department_scorecard() to authenticated;

-- 3) Aging bucket × settlement status matrix
create or replace function public.founder_r3617_aging_settlement_matrix()
returns table(aging_bucket text, settlement_status text, advances bigint, total_outstanding_rupees numeric, total_overdue_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.aging_bucket, l.settlement_status, count(*)::bigint,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric
  from public.emp_advance_r3617 l
  group by l.aging_bucket, l.settlement_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3617_aging_settlement_matrix() from public, anon;
grant execute on function public.founder_r3617_aging_settlement_matrix() to authenticated;

-- 4) Monthly settlement trend
create or replace function public.founder_r3617_monthly_settlement_trend()
returns table(period_month date, advances bigint, total_issued_rupees numeric, total_settled_rupees numeric, total_outstanding_rupees numeric, total_overdue_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.advance_issued_rupees),0)::numeric,
    coalesce(sum(l.advance_settled_rupees),0)::numeric,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric
  from public.emp_advance_r3617 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3617_monthly_settlement_trend() from public, anon;
grant execute on function public.founder_r3617_monthly_settlement_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3617_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.emp_advance_capa_actions_r3617 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3617_capa_status_board() from public, anon;
grant execute on function public.founder_r3617_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3617_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.emp_advance_capa_actions_r3617)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.emp_advance_capa_actions_r3617 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3617_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3617_root_cause_pareto() to authenticated;

-- 7) Overdue-impact digest (by aging bucket)
create or replace function public.founder_r3617_overdue_impact_digest()
returns table(aging_bucket text, advances bigint, total_overdue_rupees numeric, total_outstanding_rupees numeric, avg_days_outstanding numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.aging_bucket, count(*)::bigint,
    coalesce(sum(l.overdue_rupees),0)::numeric,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    round(avg(l.days_outstanding)::numeric, 1)
  from public.emp_advance_r3617 l
  group by l.aging_bucket
  order by coalesce(sum(l.overdue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3617_overdue_impact_digest() from public, anon;
grant execute on function public.founder_r3617_overdue_impact_digest() to authenticated;

-- 8) High-risk queue (overdue / escalated advances)
create or replace function public.founder_r3617_high_risk_queue()
returns table(
  employee_name text,
  advance_ref text,
  department text,
  advance_type text,
  period_month date,
  settlement_status text,
  aging_bucket text,
  days_outstanding int,
  overdue_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.advance_ref, l.department, l.advance_type, l.period_month,
    l.settlement_status, l.aging_bucket, l.days_outstanding, l.overdue_rupees, l.notes
  from public.emp_advance_r3617 l
  where l.settlement_status in ('overdue','escalated','recovery_from_salary')
     or l.aging_bucket in ('46_90_days','over_90_days')
     or l.overdue_rupees > 0
  order by l.overdue_rupees desc, l.days_outstanding desc;
end;
$$;

revoke execute on function public.founder_r3617_high_risk_queue() from public, anon;
grant execute on function public.founder_r3617_high_risk_queue() to authenticated;
