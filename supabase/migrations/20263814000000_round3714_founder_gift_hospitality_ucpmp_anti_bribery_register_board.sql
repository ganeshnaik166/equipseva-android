-- Round 3714: Gift & Hospitality (UCPMP) Anti-Bribery Register Board
-- Gift/hospitality declarations to/from HCPs & officials — counterparty type × threshold × approval × declaration timeliness × CAPA

-- =============================================================================
-- TABLE 1: gift_register_r3714 — per-declaration gift & hospitality register
-- =============================================================================
create table if not exists public.gift_register_r3714 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  declaration_ref text not null,
  department text not null,
  period_month date not null,
  declared_by text not null,
  counterparty_type text not null check (counterparty_type in (
    'hcp_individual','hospital_institution','government_official',
    'regulatory_official','distributor_partner','media_or_kol'
  )),
  gift_value_rupees numeric(10,2),
  threshold_rupees numeric(10,2),
  above_threshold boolean not null,
  approval_required boolean not null,
  approved boolean not null,
  declared_within_days int,
  hcp_involved boolean not null,
  recurring_counterparty boolean not null,
  direction text not null check (direction in (
    'given','received'
  )),
  compliance_status text not null check (compliance_status in (
    'compliant','approval_pending','late_declaration','threshold_breach','undeclared_found'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gift_register_r3714 enable row level security;

create index if not exists idx_gift_register_r3714_org on public.gift_register_r3714(organization_id);
create index if not exists idx_gift_register_r3714_period on public.gift_register_r3714(period_month);
create index if not exists idx_gift_register_r3714_status on public.gift_register_r3714(compliance_status);

-- =============================================================================
-- TABLE 2: gift_register_capa_actions_r3714 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.gift_register_capa_actions_r3714 (
  id uuid primary key default gen_random_uuid(),
  declaration_id uuid not null references public.gift_register_r3714(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'lack_of_awareness','inadequate_pre_approval_process','delayed_documentation',
    'vendor_relationship_practice','threshold_ambiguity','hcp_solicitation',
    'system_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_employee','tighten_approval_workflow','recover_value_from_employee',
    'issue_written_warning','revise_gift_policy','blacklist_counterparty',
    'escalate_to_compliance_committee','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_exposure_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gift_register_capa_actions_r3714 enable row level security;

create index if not exists idx_gift_register_capa_r3714_decl on public.gift_register_capa_actions_r3714(declaration_id);
create index if not exists idx_gift_register_capa_r3714_status on public.gift_register_capa_actions_r3714(capa_status);

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

  -- 16 declaration rows
  insert into public.gift_register_r3714 (
    organization_id, declaration_ref, department, period_month, declared_by, counterparty_type,
    gift_value_rupees, threshold_rupees, above_threshold, approval_required, approved,
    declared_within_days, hcp_involved, recurring_counterparty, direction, compliance_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.dept, q.pm::date, q.decby, q.ctype,
    q.gval::numeric, q.thresh::numeric, q.abv, q.apprreq, q.appr,
    q.dwd::int, q.hcp, q.recur, q.dir, q.cstat, q.trend, q.nt
  from (values
    ('DECL-0001','Sales - West','2026-07-01','Rohit Sharma','hcp_individual',3500.00,5000.00,false,false,true,4,true,false,'given','compliant','stable','Conference travel kit given to visiting surgeon within threshold, approved as courtesy'),
    ('DECL-0002','Sales - West','2026-07-01','Rohit Sharma','hcp_individual',12000.00,5000.00,true,true,true,6,true,false,'given','compliant','improving','Above-threshold CME sponsorship pre-approved by compliance committee'),
    ('DECL-0003','Marketing','2026-07-02','Priya Nair','hospital_institution',45000.00,5000.00,true,true,false,null,false,true,'given','approval_pending','worsening','Hospital CME grant awaiting compliance sign-off, recurring counterparty flagged'),
    ('DECL-0004','Key Accounts','2026-07-03','Arvind Menon','hcp_individual',8000.00,5000.00,true,true,true,18,true,false,'given','late_declaration','worsening','Diagnostic kit gift declared 18 days after event, beyond 7-day SOP window'),
    ('DECL-0005','Clinical Affairs','2026-06-28','Deepa Iyer','hcp_individual',2000.00,5000.00,false,false,true,2,true,false,'received','compliant','stable','Token conference memento received from KOL, logged same week'),
    ('DECL-0006','Distributor Relations','2026-06-27','Suresh Pillai','distributor_partner',60000.00,5000.00,true,true,false,null,false,true,'received','threshold_breach','worsening','Distributor hospitality package well above threshold, no prior approval sought'),
    ('DECL-0007','Regulatory Affairs','2026-06-25','Kavya Reddy','government_official',15000.00,5000.00,true,true,false,null,false,false,'given','undeclared_found','worsening','Facilitation gift to regulatory official surfaced via audit, not self-declared'),
    ('DECL-0008','Sales - South','2026-06-24','Manoj Kumar','hcp_individual',3000.00,5000.00,false,false,true,3,true,false,'given','compliant','stable','Branded diary and calendar set, within threshold'),
    ('DECL-0009','Medical Affairs','2026-06-22','Anjali Rao','hcp_individual',9500.00,5000.00,true,true,true,9,true,true,'given','late_declaration','worsening','Speaker honorarium declared 9 days late, recurring speaker relationship'),
    ('DECL-0010','Marketing','2026-06-20','Priya Nair','media_or_kol',25000.00,5000.00,true,true,true,5,false,false,'given','compliant','improving','Product launch media hospitality pre-approved by legal'),
    ('DECL-0011','Field Service','2026-06-18','Rajesh Babu','hospital_institution',4000.00,5000.00,false,false,true,1,false,false,'received','compliant','stable','Appreciation token received from hospital biomedical dept, logged next day'),
    ('DECL-0012','Key Accounts','2026-06-15','Arvind Menon','regulatory_official',20000.00,5000.00,true,true,false,null,false,false,'given','undeclared_found','worsening','Gift to regulatory official flagged by internal audit, employee had not declared'),
    ('DECL-0013','Sales - West','2026-06-12','Rohit Sharma','hcp_individual',6000.00,5000.00,true,true,true,10,true,false,'given','late_declaration','stable','Surgical training kit declared 10 days after handover'),
    ('DECL-0014','Distributor Relations','2026-06-10','Suresh Pillai','distributor_partner',4500.00,5000.00,false,false,true,2,false,true,'received','compliant','improving','Festival gift hamper from distributor, within threshold and logged promptly'),
    ('DECL-0015','Clinical Affairs','2026-06-08','Deepa Iyer','hcp_individual',55000.00,5000.00,true,true,false,null,true,false,'given','threshold_breach','worsening','High-value research grant to investigator well above threshold, no compliance sign-off'),
    ('DECL-0016','Marketing','2026-06-05','Priya Nair','hcp_individual',5000.00,5000.00,false,true,true,3,true,false,'given','compliant','stable','Gift at exact threshold, approval sought as precaution and granted')
  ) as q(ref, dept, pm, decby, ctype, gval, thresh, abv, apprreq, appr, dwd, hcp, recur, dir, cstat, trend, nt);

  -- CAPA seed — attach to specific declarations via declaration_ref
  insert into public.gift_register_capa_actions_r3714 (
    declaration_id, root_cause, corrective_action, capa_status,
    financial_exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.fin::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DECL-0003','inadequate_pre_approval_process','tighten_approval_workflow','in_progress',45000.00,'Compliance Officer - Meera Joshi','2026-07-10',null,'Escalated hospital CME grant for compliance committee review; approval workflow being tightened'),
    ('DECL-0004','delayed_documentation','retrain_employee','closed',8000.00,'Regional Compliance Lead - Meera Joshi','2026-07-15','2026-07-12','Employee retrained on 7-day declaration SOP; late filing acknowledged and closed'),
    ('DECL-0006','vendor_relationship_practice','escalate_to_compliance_committee','escalated',60000.00,'Head of Compliance - Nikhil Shah','2026-07-08',null,'Distributor hospitality breach escalated to compliance committee for review and possible blacklist'),
    ('DECL-0007','system_gap','escalate_to_compliance_committee','overdue',15000.00,'Ethics Committee - Nikhil Shah','2026-07-01',null,'Undeclared gift to regulatory official surfaced via internal audit; escalation overdue pending legal review'),
    ('DECL-0009','delayed_documentation','retrain_employee','verification_pending',9500.00,'Medical Affairs Compliance - Ritu Sen','2026-07-05',null,'Speaker honorarium late filing; retraining completed, awaiting verification of next declaration cycle'),
    ('DECL-0012','pending_investigation','escalate_to_compliance_committee','open',20000.00,'Head of Compliance - Nikhil Shah','2026-07-20',null,'Undeclared gift to regulatory official under investigation by ethics committee'),
    ('DECL-0013','threshold_ambiguity','revise_gift_policy','closed',6000.00,'Regional Compliance Lead - Meera Joshi','2026-06-25','2026-06-24','Surgical training kit declaration delay; gift policy threshold guidance clarified and circulated'),
    ('DECL-0015','inadequate_pre_approval_process','tighten_approval_workflow','in_progress',55000.00,'Head of Compliance - Nikhil Shah','2026-07-18',null,'Investigator research grant breach; pre-approval workflow tightened, retroactive compliance review underway')
  ) as q(ref, rc, ca, cst, fin, own, tcd, acd, nt)
  join public.gift_register_r3714 e
    on e.organization_id = v_org_id and e.declaration_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance status distribution
create or replace function public.founder_r3714_compliance_status_rollup()
returns table(compliance_status text, declarations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gift_register_r3714)
  select g.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gift_register_r3714 g
  group by g.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3714_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3714_compliance_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3714_department_scorecard()
returns table(
  department text,
  total_declarations bigint,
  compliant bigint,
  approval_pending bigint,
  late_declaration bigint,
  threshold_breach bigint,
  undeclared_found bigint,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.department,
    count(*)::bigint,
    count(*) filter (where g.compliance_status = 'compliant')::bigint,
    count(*) filter (where g.compliance_status = 'approval_pending')::bigint,
    count(*) filter (where g.compliance_status = 'late_declaration')::bigint,
    count(*) filter (where g.compliance_status = 'threshold_breach')::bigint,
    count(*) filter (where g.compliance_status = 'undeclared_found')::bigint,
    round(100.0 * count(*) filter (where g.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.gift_register_r3714 g
  group by g.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3714_department_scorecard() from public, anon;
grant execute on function public.founder_r3714_department_scorecard() to authenticated;

-- 3) Direction x compliance status matrix
create or replace function public.founder_r3714_direction_status_matrix()
returns table(direction text, compliance_status text, declarations bigint, avg_gift_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.direction, g.compliance_status, count(*)::bigint,
    round(avg(g.gift_value_rupees), 2)
  from public.gift_register_r3714 g
  group by g.direction, g.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3714_direction_status_matrix() from public, anon;
grant execute on function public.founder_r3714_direction_status_matrix() to authenticated;

-- 4) Monthly declaration trend
create or replace function public.founder_r3714_monthly_declaration_trend()
returns table(
  period_month date,
  declarations bigint,
  compliant bigint,
  non_compliant bigint,
  threshold_breaches bigint,
  avg_declared_within_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.period_month,
    count(*)::bigint,
    count(*) filter (where g.compliance_status = 'compliant')::bigint,
    count(*) filter (where g.compliance_status <> 'compliant')::bigint,
    count(*) filter (where g.compliance_status = 'threshold_breach')::bigint,
    round(avg(g.declared_within_days), 1)
  from public.gift_register_r3714 g
  group by g.period_month
  order by g.period_month desc;
end;
$$;

revoke execute on function public.founder_r3714_monthly_declaration_trend() from public, anon;
grant execute on function public.founder_r3714_monthly_declaration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3714_capa_status_board()
returns table(capa_status text, findings bigint, avg_financial_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.financial_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.gift_register_capa_actions_r3714 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3714_capa_status_board() from public, anon;
grant execute on function public.founder_r3714_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3714_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_financial_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gift_register_capa_actions_r3714)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gift_register_capa_actions_r3714 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3714_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3714_root_cause_pareto() to authenticated;

-- 7) Threshold-breach digest
create or replace function public.founder_r3714_threshold_breach_digest()
returns table(
  counterparty_type text,
  breaches bigint,
  avg_gift_value_rupees numeric,
  avg_threshold_rupees numeric,
  hcp_involved_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.counterparty_type, count(*)::bigint,
    round(avg(g.gift_value_rupees), 2),
    round(avg(g.threshold_rupees), 2),
    count(*) filter (where g.hcp_involved = true)::bigint
  from public.gift_register_r3714 g
  where g.above_threshold = true
  group by g.counterparty_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3714_threshold_breach_digest() from public, anon;
grant execute on function public.founder_r3714_threshold_breach_digest() to authenticated;

-- 8) High-risk declaration queue
create or replace function public.founder_r3714_high_risk_queue()
returns table(
  declaration_ref text,
  department text,
  period_month date,
  declared_by text,
  counterparty_type text,
  direction text,
  gift_value_rupees numeric,
  threshold_rupees numeric,
  compliance_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.declaration_ref, g.department, g.period_month, g.declared_by, g.counterparty_type,
    g.direction, g.gift_value_rupees, g.threshold_rupees, g.compliance_status, g.notes
  from public.gift_register_r3714 g
  where g.compliance_status in ('undeclared_found','threshold_breach')
  order by g.period_month desc, g.declaration_ref;
end;
$$;

revoke execute on function public.founder_r3714_high_risk_queue() from public, anon;
grant execute on function public.founder_r3714_high_risk_queue() to authenticated;
