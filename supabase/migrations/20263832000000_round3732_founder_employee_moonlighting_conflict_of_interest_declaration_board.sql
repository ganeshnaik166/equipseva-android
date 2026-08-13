-- Round 3732: Founder Employee Moonlighting / Conflict-of-Interest Declaration Board
-- Proactive employee self-declaration of outside employment / moonlighting / board
-- directorships / family-business interests / vendor relationships / competitor
-- engagements x approval status x conflict identified x undeclared conflicts found x
-- role risk x CAPA. Distinct from any gift-hospitality anti-bribery register page
-- (external gifts) and from any whistleblower/ethics/POSH grievance board (grievances)
-- — this page covers proactive COI self-declaration, not gifts or grievances.

-- =============================================================================
-- TABLE 1: coi_declare_r3732 — per-employee/period conflict-of-interest declarations
-- =============================================================================
create table if not exists public.coi_declare_r3732 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  department text not null,
  period_month date not null,
  declaration_type text,
  declared_date date,
  outside_engagement_name text,
  hours_per_week numeric,
  approval_required boolean not null,
  approved boolean not null,
  conflict_identified boolean not null,
  undeclared_found boolean not null,
  role_risk_level text,
  coi_class text not null check (coi_class in (
    'outside_employment','board_directorship','family_business_interest','vendor_relationship','competitor_engagement'
  )),
  declaration_status text not null check (declaration_status in (
    'declared_approved','declared_pending','declared_restricted','undeclared_found','declined'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.coi_declare_r3732 enable row level security;

create index if not exists idx_coi_declare_r3732_org on public.coi_declare_r3732(organization_id);
create index if not exists idx_coi_declare_r3732_month on public.coi_declare_r3732(period_month);
create index if not exists idx_coi_declare_r3732_status on public.coi_declare_r3732(declaration_status);

-- =============================================================================
-- TABLE 2: coi_declare_capa_actions_r3732 — CAPA & COI remediation actions
-- =============================================================================
create table if not exists public.coi_declare_capa_actions_r3732 (
  id uuid primary key default gen_random_uuid(),
  coi_declare_id uuid references public.coi_declare_r3732(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.coi_declare_capa_actions_r3732 enable row level security;

create index if not exists idx_coi_declare_capa_r3732_cd on public.coi_declare_capa_actions_r3732(coi_declare_id);
create index if not exists idx_coi_declare_capa_r3732_status on public.coi_declare_capa_actions_r3732(capa_status);

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

  -- 16 COI declaration rows
  insert into public.coi_declare_r3732 (
    organization_id, employee_name, department, period_month,
    declaration_type, declared_date, outside_engagement_name, hours_per_week,
    approval_required, approved, conflict_identified, undeclared_found,
    role_risk_level, coi_class, declaration_status, trend_dir, notes
  )
  select v_org_id, q.emp, q.dept, q.pm::date,
    q.dt, q.dd::date, q.oen, q.hpw::numeric,
    q.ar, q.apr, q.ci, q.uf,
    q.rrl, q.cc, q.ds, q.trd, q.nt
  from (values
    ('Arjun Mehta','Field Service','2026-07-01',
     'annual_self_declaration','2026-07-05','Weekend AC repair side gig',8.0,
     true,true,false,false,'low','outside_employment','declared_approved','stable','Disclosed early, no overlap with core accounts, approved by HR'),
    ('Sunita Rao','Sales','2026-07-01',
     'annual_self_declaration','2026-07-08','Family-owned medical equipment trading firm',0.0,
     true,false,true,false,'high','family_business_interest','declared_pending','worsening','Family firm sells competing spare parts; approval committee reviewing'),
    ('Vikram Singh','Procurement','2026-07-01',
     'annual_self_declaration',null,null,null,
     true,false,true,true,'high','vendor_relationship','undeclared_found','worsening','Undeclared stake in preferred spare-parts vendor found during vendor audit'),
    ('Priya Nair','Engineering','2026-06-01',
     'annual_self_declaration','2026-06-12','Board seat at medtech startup',5.0,
     true,true,false,false,'medium','board_directorship','declared_approved','improving','Non-competing startup, board seat disclosed and approved with conditions'),
    ('Rohan Kapoor','Service','2026-06-01',
     'annual_self_declaration','2026-06-15','Freelance CT scanner calibration work',12.0,
     true,false,true,false,'high','outside_employment','declared_restricted','worsening','Directly competes with employer service line; restricted pending resignation from side gig'),
    ('Meera Iyer','Finance','2026-06-01',
     'annual_self_declaration','2026-06-20',null,0.0,
     false,true,false,false,'low','outside_employment','declared_approved','stable','No outside engagement to disclose this cycle, filed as nil declaration'),
    ('Karan Malhotra','Sales','2026-05-01',
     'annual_self_declaration',null,'Reseller agreement with competitor OEM',15.0,
     true,false,true,true,'high','competitor_engagement','undeclared_found','worsening','Discovered acting as reseller for competing OEM brand, undeclared for over a year'),
    ('Divya Krishnan','HR','2026-05-01',
     'annual_self_declaration','2026-05-10','Part-time HR consulting for a clinic',4.0,
     true,true,false,false,'low','outside_employment','declared_approved','stable','Non-competing clinic, minimal hours, approved without conditions'),
    ('Sameer Joshi','Procurement','2026-05-01',
     'annual_self_declaration','2026-05-18','Spouse runs a logistics vendor used by company',0.0,
     true,false,true,false,'high','family_business_interest','declared_pending','worsening','Spouse-owned logistics vendor currently on approved supplier list; recusal pending'),
    ('Ananya Ghosh','Marketing','2026-05-01',
     'annual_self_declaration','2026-05-22','Freelance content writing for unrelated brands',6.0,
     true,true,false,false,'low','outside_employment','declared_approved','stable','Unrelated industry, no conflict, approved'),
    ('Faisal Ahmed','Field Service','2026-07-01',
     'mid_year_update','2026-07-14','Weekend electronics repair shop, part owner',10.0,
     true,false,true,false,'medium','outside_employment','declared_pending','stable','Shop repairs consumer electronics, low overlap risk, under review'),
    ('Neha Bhatt','Engineering','2026-07-01',
     'annual_self_declaration','2026-07-02','Advisor to a diagnostics equipment startup',3.0,
     true,true,false,false,'medium','board_directorship','declared_approved','improving','Advisory role disclosed with IP-conflict waiver signed'),
    ('Gaurav Desai','Sales','2026-06-01',
     'annual_self_declaration',null,'Undisclosed distributorship for rival brand',20.0,
     true,false,true,true,'high','competitor_engagement','undeclared_found','worsening','Whistle-tip led to discovery of active distributorship for rival brand, escalated to legal'),
    ('Shreya Pillai','HR','2026-06-01',
     'annual_self_declaration','2026-06-09',null,0.0,
     false,true,false,false,'low','outside_employment','declared_approved','stable','Nil declaration filed on time, no outside interests'),
    ('Aditya Verma','Finance','2026-05-01',
     'annual_self_declaration','2026-05-05','Investment stake in a supplier company (public shares)',0.0,
     true,false,true,false,'medium','vendor_relationship','declined','worsening','Stake exceeds materiality threshold; divestment requested, employee has declined so far'),
    ('Ritu Chawla','Marketing','2026-05-01',
     'annual_self_declaration','2026-05-11','Freelance graphic design for a competitor tender',2.0,
     true,false,true,false,'high','competitor_engagement','declared_restricted','worsening','Design work for competitor RFP response flagged as direct conflict, activity restricted')
  ) as q(emp, dept, pm, dt, dd, oen, hpw, ar, apr, ci, uf, rrl, cc, ds, trd, nt);

  -- CAPA seed — attach to specific rows via employee_name + department
  insert into public.coi_declare_capa_actions_r3732 (
    coi_declare_id, root_cause, corrective_action,
    capa_status, owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca,
    q.cst, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Vikram Singh','Procurement','No proactive vendor-ownership disclosure check at onboarding','Add mandatory vendor-interest disclosure to annual COI cycle and cross-check against vendor master','in_progress','Compliance Lead','2026-08-30',null,'Cross-check script built against vendor master; rollout to procurement team pending'),
    ('Karan Malhotra','Sales','No monitoring of reseller/distributor registrations against employee roster','Implement quarterly market-scan for employee names against competitor reseller listings','open','Ethics Officer','2026-09-10',null,'Legal review of reseller agreement in progress ahead of disciplinary decision'),
    ('Gaurav Desai','Sales','Distributorship discovery relied solely on anonymous tip, no systematic scan','Stand up systematic distributor-registry scan tied to annual COI cycle','open','Ethics Officer','2026-09-15',null,'Escalated to legal; systematic scan process being scoped in parallel'),
    ('Rohan Kapoor','Service','Side-gig approval workflow did not check for direct service-line overlap','Add service-line overlap check to COI approval workflow before sign-off','closed','HR Business Partner','2026-07-15','2026-07-12','Workflow updated; restriction communicated and side gig wound down'),
    ('Sunita Rao','Sales','Family-business disclosure lacked automatic escalation to approval committee','Route all family-business-interest declarations to approval committee automatically','in_progress','Compliance Lead','2026-08-22',null,'Committee review scheduled, awaiting additional financial disclosure from employee'),
    ('Sameer Joshi','Procurement','Spouse-owned vendor remained on approved supplier list post-declaration','Recuse employee from vendor selection involving spouse-owned firm and flag in ERP','open','Procurement Head','2026-08-28',null,'Recusal drafted, ERP vendor-flag pending IT ticket completion'),
    ('Aditya Verma','Finance','No materiality threshold enforcement for supplier-company shareholdings','Enforce divestment deadline with escalation to CFO if threshold breach persists','overdue','Compliance Lead','2026-08-01',null,'Deadline missed; escalation memo to CFO being finalized'),
    ('Faisal Ahmed','Field Service','No corrective action required — declaration under normal review','None required, continue standard review cycle','closed','HR Business Partner','2026-07-20','2026-07-19','Included as a baseline low-risk reference case, no issue found')
  ) as q(emp, dept, rc, ca, cst, ownr, tcd, acd, nt)
  join public.coi_declare_r3732 e
    on e.organization_id = v_org_id and e.employee_name = q.emp and e.department = q.dept;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Declaration-status distribution
create or replace function public.founder_r3732_declaration_status_rollup()
returns table(declaration_status text, declarations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coi_declare_r3732)
  select l.declaration_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.coi_declare_r3732 l
  group by l.declaration_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3732_declaration_status_rollup() from public, anon;
grant execute on function public.founder_r3732_declaration_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3732_department_scorecard()
returns table(
  department text,
  declarations bigint,
  declared_approved bigint,
  undeclared_found bigint,
  conflicts_identified bigint,
  approval_required_count bigint,
  approved_count bigint,
  avg_hours_per_week numeric,
  high_risk_count bigint
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
    count(*) filter (where l.declaration_status = 'declared_approved')::bigint,
    count(*) filter (where l.declaration_status = 'undeclared_found')::bigint,
    count(*) filter (where l.conflict_identified = true)::bigint,
    count(*) filter (where l.approval_required = true)::bigint,
    count(*) filter (where l.approved = true)::bigint,
    round(avg(l.hours_per_week), 1),
    count(*) filter (where l.role_risk_level = 'high')::bigint
  from public.coi_declare_r3732 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3732_department_scorecard() from public, anon;
grant execute on function public.founder_r3732_department_scorecard() to authenticated;

-- 3) COI-class x declaration-status matrix
create or replace function public.founder_r3732_coi_class_status_matrix()
returns table(coi_class text, declaration_status text, declarations bigint, avg_hours_per_week numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.coi_class, l.declaration_status, count(*)::bigint,
    round(avg(l.hours_per_week), 1)
  from public.coi_declare_r3732 l
  group by l.coi_class, l.declaration_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3732_coi_class_status_matrix() from public, anon;
grant execute on function public.founder_r3732_coi_class_status_matrix() to authenticated;

-- 4) Monthly declaration trend
create or replace function public.founder_r3732_monthly_declaration_trend()
returns table(period_month date, declarations bigint, undeclared_found bigint, conflicts_identified bigint, approved_count bigint, worsening_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.declaration_status = 'undeclared_found')::bigint,
    count(*) filter (where l.conflict_identified = true)::bigint,
    count(*) filter (where l.approved = true)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.coi_declare_r3732 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3732_monthly_declaration_trend() from public, anon;
grant execute on function public.founder_r3732_monthly_declaration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3732_capa_status_board()
returns table(capa_status text, findings bigint, closed_count bigint, overdue_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'closed')::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.coi_declare_capa_actions_r3732 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3732_capa_status_board() from public, anon;
grant execute on function public.founder_r3732_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3732_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coi_declare_capa_actions_r3732)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.coi_declare_capa_actions_r3732 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3732_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3732_root_cause_pareto() to authenticated;

-- 7) Undeclared-conflict digest
create or replace function public.founder_r3732_undeclared_conflict_digest()
returns table(
  employee_name text,
  department text,
  period_month date,
  coi_class text,
  outside_engagement_name text,
  hours_per_week numeric,
  role_risk_level text,
  declaration_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l.period_month, l.coi_class,
    l.outside_engagement_name, l.hours_per_week, l.role_risk_level,
    l.declaration_status, l.notes
  from public.coi_declare_r3732 l
  where l.undeclared_found = true
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3732_undeclared_conflict_digest() from public, anon;
grant execute on function public.founder_r3732_undeclared_conflict_digest() to authenticated;

-- 8) High-risk COI queue (undeclared / restricted / declined)
create or replace function public.founder_r3732_high_risk_queue()
returns table(
  employee_name text,
  department text,
  period_month date,
  coi_class text,
  declaration_status text,
  role_risk_level text,
  conflict_identified boolean,
  hours_per_week numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l.period_month, l.coi_class,
    l.declaration_status, l.role_risk_level, l.conflict_identified,
    l.hours_per_week, l.notes
  from public.coi_declare_r3732 l
  where l.declaration_status in ('undeclared_found','declared_restricted','declined')
  order by l.period_month desc, l.role_risk_level asc
  limit 20;
end;
$$;

revoke all on function public.founder_r3732_high_risk_queue() from public, anon;
grant execute on function public.founder_r3732_high_risk_queue() to authenticated;
