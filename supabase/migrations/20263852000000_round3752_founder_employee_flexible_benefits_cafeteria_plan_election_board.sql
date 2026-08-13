-- Round 3752: Founder Employee Flexible-Benefits / Cafeteria-Plan Election Board
-- Flexible-benefits/cafeteria-plan (LTA, meal vouchers, fuel allowance, medical
-- reimbursement, books & periodicals) election and utilization — completion rate,
-- tax-optimal use, unused-component forfeiture risk, per employee/department/month.

-- =============================================================================
-- TABLE 1: flexi_benefits_r3752 — per-employee FBP election/utilization facts
-- =============================================================================
create table if not exists public.flexi_benefits_r3752 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  department text not null,
  period_month date not null,
  plan_year text,
  components_offered int,
  components_elected int,
  election_completion_pct numeric,
  total_allocated_rupees numeric(12,2),
  total_utilized_rupees numeric(12,2),
  utilization_pct numeric,
  forfeiture_risk_rupees numeric(12,2),
  declaration_class text not null check (declaration_class in (
    'lta','meal_vouchers','fuel_allowance','medical_reimbursement','books_periodicals'
  )),
  election_status text not null check (election_status in (
    'fully_elected_optimal','partially_elected','not_elected','over_allocated','forfeiture_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.flexi_benefits_r3752 enable row level security;

create index if not exists idx_flexi_benefits_r3752_org on public.flexi_benefits_r3752(organization_id);
create index if not exists idx_flexi_benefits_r3752_month on public.flexi_benefits_r3752(period_month);
create index if not exists idx_flexi_benefits_r3752_status on public.flexi_benefits_r3752(election_status);

-- =============================================================================
-- TABLE 2: flexi_benefits_capa_actions_r3752 — CAPA for election/utilization gaps
-- =============================================================================
create table if not exists public.flexi_benefits_capa_actions_r3752 (
  id uuid primary key default gen_random_uuid(),
  election_id uuid references public.flexi_benefits_r3752(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.flexi_benefits_capa_actions_r3752 enable row level security;

create index if not exists idx_flexi_benefits_capa_r3752_election on public.flexi_benefits_capa_actions_r3752(election_id);
create index if not exists idx_flexi_benefits_capa_r3752_status on public.flexi_benefits_capa_actions_r3752(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Election-status distribution
create or replace function public.founder_r3752_election_status_rollup()
returns table(election_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.flexi_benefits_r3752)
  select f.election_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.flexi_benefits_r3752 f
  group by f.election_status
  order by count(*) desc;
end;
$$;

-- 2) Department scorecard
create or replace function public.founder_r3752_department_scorecard()
returns table(
  department text,
  records bigint,
  fully_elected_optimal bigint,
  partially_elected bigint,
  not_elected bigint,
  over_allocated bigint,
  forfeiture_risk bigint,
  avg_election_completion_pct numeric,
  avg_utilization_pct numeric,
  forfeiture_risk_total_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.department,
    count(*)::bigint,
    count(*) filter (where f.election_status = 'fully_elected_optimal')::bigint,
    count(*) filter (where f.election_status = 'partially_elected')::bigint,
    count(*) filter (where f.election_status = 'not_elected')::bigint,
    count(*) filter (where f.election_status = 'over_allocated')::bigint,
    count(*) filter (where f.election_status = 'forfeiture_risk')::bigint,
    round(avg(f.election_completion_pct), 1),
    round(avg(f.utilization_pct), 1),
    coalesce(sum(f.forfeiture_risk_rupees), 0)::numeric
  from public.flexi_benefits_r3752 f
  group by f.department
  order by count(*) desc;
end;
$$;

-- 3) Declaration-class x election-status matrix
create or replace function public.founder_r3752_declaration_class_status_matrix()
returns table(declaration_class text, election_status text, records bigint, avg_utilization_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.declaration_class, f.election_status, count(*)::bigint,
    round(avg(f.utilization_pct), 1)
  from public.flexi_benefits_r3752 f
  group by f.declaration_class, f.election_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly utilization trend
create or replace function public.founder_r3752_monthly_utilization_trend()
returns table(
  period_month date,
  records bigint,
  total_allocated_rupees_total numeric,
  total_utilized_rupees_total numeric,
  forfeiture_risk_rupees_total numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.period_month,
    count(*)::bigint,
    coalesce(sum(f.total_allocated_rupees), 0)::numeric,
    coalesce(sum(f.total_utilized_rupees), 0)::numeric,
    coalesce(sum(f.forfeiture_risk_rupees), 0)::numeric,
    round(avg(f.utilization_pct), 1)
  from public.flexi_benefits_r3752 f
  group by f.period_month
  order by f.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3752_capa_status_board()
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
  from public.flexi_benefits_capa_actions_r3752 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3752_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.flexi_benefits_capa_actions_r3752)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.flexi_benefits_capa_actions_r3752 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Forfeiture-risk digest by department
create or replace function public.founder_r3752_forfeiture_risk_digest()
returns table(
  department text,
  records bigint,
  forfeiture_risk_records bigint,
  forfeiture_risk_total_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.department,
    count(*)::bigint,
    count(*) filter (where f.election_status = 'forfeiture_risk')::bigint,
    coalesce(sum(f.forfeiture_risk_rupees) filter (where f.election_status = 'forfeiture_risk'), 0)::numeric,
    round(avg(f.utilization_pct) filter (where f.election_status = 'forfeiture_risk'), 1)
  from public.flexi_benefits_r3752 f
  where f.election_status = 'forfeiture_risk'
  group by f.department
  order by coalesce(sum(f.forfeiture_risk_rupees) filter (where f.election_status = 'forfeiture_risk'), 0) desc;
end;
$$;

-- 8) High-risk queue (forfeiture-risk / over-allocated, worst first)
create or replace function public.founder_r3752_high_risk_queue()
returns table(
  employee_name text,
  department text,
  period_month date,
  declaration_class text,
  election_status text,
  utilization_pct numeric,
  forfeiture_risk_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.employee_name, f.department, f.period_month, f.declaration_class,
    f.election_status, f.utilization_pct, f.forfeiture_risk_rupees, f.notes
  from public.flexi_benefits_r3752 f
  where f.election_status in ('forfeiture_risk','over_allocated')
  order by f.forfeiture_risk_rupees desc nulls last, f.period_month desc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3752_election_status_rollup() from public, anon;
revoke all on function public.founder_r3752_department_scorecard() from public, anon;
revoke all on function public.founder_r3752_declaration_class_status_matrix() from public, anon;
revoke all on function public.founder_r3752_monthly_utilization_trend() from public, anon;
revoke all on function public.founder_r3752_capa_status_board() from public, anon;
revoke all on function public.founder_r3752_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3752_forfeiture_risk_digest() from public, anon;
revoke all on function public.founder_r3752_high_risk_queue() from public, anon;

grant execute on function public.founder_r3752_election_status_rollup() to authenticated;
grant execute on function public.founder_r3752_department_scorecard() to authenticated;
grant execute on function public.founder_r3752_declaration_class_status_matrix() to authenticated;
grant execute on function public.founder_r3752_monthly_utilization_trend() to authenticated;
grant execute on function public.founder_r3752_capa_status_board() to authenticated;
grant execute on function public.founder_r3752_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3752_forfeiture_risk_digest() to authenticated;
grant execute on function public.founder_r3752_high_risk_queue() to authenticated;

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

  -- 16 flexible-benefits election/utilization rows across employees, departments & months
  insert into public.flexi_benefits_r3752 (
    organization_id, employee_name, department, period_month, plan_year,
    components_offered, components_elected, election_completion_pct,
    total_allocated_rupees, total_utilized_rupees, utilization_pct, forfeiture_risk_rupees,
    declaration_class, election_status, trend_dir, notes
  )
  select v_org_id, q.en, q.dept, q.pm::date, q.py,
    q.co, q.ce, q.ecp,
    q.tar, q.tur, q.up, q.frr,
    q.dc, q.es, q.td, q.nt
  from (values
    ('Priya Sharma','Engineering','2026-07-01','2025-26',5,5,100.0,84000.00,82500.00,98.2,0.00,'lta','fully_elected_optimal','stable','All five FBP components fully elected and tax-optimally utilized for the year'),
    ('Anjali Verma','Operations','2026-07-01','2025-26',5,3,60.0,60000.00,28000.00,46.7,12000.00,'meal_vouchers','partially_elected','worsening','Meal voucher component under-utilized; risk of forfeiture rising as year-end nears'),
    ('Kavita Rao','Finance','2026-06-01','2025-26',5,0,0.0,0.00,0.00,0.0,0.00,'fuel_allowance','not_elected','stable','Declined fuel allowance component this cycle; opted for higher take-home instead'),
    ('Sunita Iyer','Sales','2026-07-01','2025-26',5,5,100.0,96000.00,40000.00,41.7,56000.00,'medical_reimbursement','forfeiture_risk','worsening','Medical reimbursement bills not submitted yet; large unused balance at risk of forfeiture'),
    ('Meera Nair','Human Resources','2026-07-01','2025-26',5,6,120.0,72000.00,74500.00,103.5,0.00,'books_periodicals','over_allocated','worsening','Elected amount exceeds the permissible cap for books & periodicals; correction needed'),
    ('Deepika Menon','Customer Support','2026-06-01','2025-26',5,5,100.0,88000.00,86000.00,97.7,0.00,'lta','fully_elected_optimal','improving','LTA claim submitted with valid travel bills; fully reimbursed within the block year'),
    ('Radhika Pillai','Product','2026-05-01','2025-26',5,4,80.0,54000.00,32000.00,59.3,8000.00,'meal_vouchers','partially_elected','stable','Meal voucher usage trailing target; reminders sent for card top-up utilization'),
    ('Shalini Gupta','Quality Assurance','2026-06-01','2025-26',5,0,0.0,0.00,0.00,0.0,0.00,'fuel_allowance','not_elected','stable','No vehicle registered under employee name; fuel allowance component skipped'),
    ('Neha Kulkarni','Engineering','2026-05-01','2025-26',5,5,100.0,60000.00,22000.00,36.7,38000.00,'medical_reimbursement','forfeiture_risk','worsening','Medical bills pending submission past two reminder cycles; forfeiture risk high'),
    ('Ritu Chawla','Marketing','2026-07-01','2025-26',5,5,100.0,45000.00,47200.00,104.9,0.00,'books_periodicals','over_allocated','worsening','Book purchase claims exceeded declared amount; excess to be recovered from payroll'),
    ('Farah Sheikh','Finance','2026-07-01','2025-26',5,5,100.0,90000.00,88500.00,98.3,0.00,'lta','fully_elected_optimal','improving','Second LTA block claim in the current cycle fully utilized and tax-exempt'),
    ('Pooja Bhatt','Operations','2026-06-01','2025-26',5,3,60.0,54000.00,24000.00,44.4,10000.00,'meal_vouchers','partially_elected','worsening','Card top-up frequency dropped after the vendor switch; balance building up unused'),
    ('Aditi Joshi','Sales','2026-07-01','2025-26',5,0,0.0,0.00,0.00,0.0,0.00,'fuel_allowance','not_elected','stable','Employee opted out of fuel allowance in favour of the public-transport reimbursement plan'),
    ('Tanvi Deshmukh','Human Resources','2026-05-01','2025-26',5,5,100.0,72000.00,30000.00,41.7,42000.00,'medical_reimbursement','forfeiture_risk','worsening','Family floater medical bills not yet filed; balance likely to lapse at plan-year close'),
    ('Sneha Reddy','Customer Support','2026-06-01','2025-26',5,6,120.0,60000.00,61500.00,102.5,0.00,'books_periodicals','over_allocated','stable','Periodicals subscription auto-renewed above the declared cap; adjustment pending'),
    ('Vidya Krishnan','Product','2026-07-01','2025-26',5,5,100.0,84000.00,83200.00,99.0,0.00,'lta','fully_elected_optimal','improving','LTA fully utilized with block-year travel completed well within deadline')
  ) as q(en, dept, pm, py, co, ce, ecp, tar, tur, up, frr, dc, es, td, nt);

  -- 8 CAPA rows — attach to election rows via employee_name + period_month
  insert into public.flexi_benefits_capa_actions_r3752 (
    election_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Anjali Verma','2026-07-01','Meal voucher card top-ups not being triggered automatically each payroll cycle','Enable auto top-up for the meal voucher card and notify employee to resume monthly spends','in_progress','HR Business Partner','2026-08-25',null,'Auto top-up request raised with the card vendor; employee notified to resume usage'),
    ('Sunita Iyer','2026-07-01','Medical reimbursement bills not submitted despite two reminder cycles','Follow up directly with employee and extend the bill-submission window by two weeks','open','Payroll Manager','2026-08-30',null,'Employee informed of the extended window; bills expected before month-end'),
    ('Meera Nair','2026-07-01','Declared amount for books & periodicals exceeded the permissible annual cap','Recover the excess amount through payroll deduction and correct the declared cap in the system','closed','Payroll Manager','2026-07-20','2026-07-18','Excess recovered in the July payroll run; declaration cap corrected'),
    ('Radhika Pillai','2026-05-01','Meal voucher usage trailing target due to low awareness of the card top-up process','Send a usage reminder and a step-by-step top-up guide to the employee','in_progress','HR Business Partner','2026-08-15',null,'Guide shared; usage expected to pick up in the next cycle'),
    ('Neha Kulkarni','2026-05-01','Medical bills pending submission past two reminder cycles','Escalate to the employee''s manager and set a hard deadline for bill submission','overdue','HR Business Partner','2026-07-31',null,'SLA breached by two weeks; manager escalation sent this week'),
    ('Ritu Chawla','2026-07-01','Book purchase claims exceeded the declared amount for the periodicals component','Recover the excess via payroll and cap future claims at the declared limit','in_progress','Payroll Manager','2026-08-20',null,'Recovery scheduled for the August payroll run'),
    ('Pooja Bhatt','2026-06-01','Meal voucher card top-up frequency dropped sharply after the vendor switch','Reconcile the new vendor''s top-up schedule and notify affected employees','open','Admin & Facilities Head','2026-08-28',null,'Vendor reconciliation in progress; notification pending'),
    ('Tanvi Deshmukh','2026-05-01','Family floater medical bills not yet filed ahead of the plan-year close','Remind employee of the plan-year deadline and offer assistance filing the claim','in_progress','HR Business Partner','2026-08-31',null,'Employee assisted with claim documentation; submission expected shortly')
  ) as q(en, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.flexi_benefits_r3752 e
    on e.organization_id = v_org_id and e.employee_name = q.en and e.period_month = q.pm::date;
end;
$seed$;
