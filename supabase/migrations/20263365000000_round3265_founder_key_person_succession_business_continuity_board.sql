-- Round 3265: Founder Key-Person Succession & Business-Continuity Board
-- Key-person risk log — critical role × incumbent × function × criticality × bus-factor × successor readiness × knowledge documentation × single-point-of-failure × retention risk × cross-training × continuity verdict × CAPA

-- =============================================================================
-- TABLE 1: key_person_succession_r3265 — one row per critical role / incumbent
-- =============================================================================
create table if not exists public.key_person_succession_r3265 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  role_title text not null,
  incumbent_name text not null,
  function_area text not null check (function_area in (
    'engineering_leadership','finance','sales_leadership','operations',
    'founder_office','key_technical_specialist','customer_relationship'
  )),
  criticality text not null check (criticality in (
    'mission_critical','high','medium'
  )),
  bus_factor int not null,
  successor_identified boolean not null,
  successor_readiness text not null check (successor_readiness in (
    'ready_now','ready_1yr','ready_2yr','none'
  )),
  knowledge_documented_pct numeric(5,2) not null,
  single_point_of_failure boolean not null,
  retention_risk text not null check (retention_risk in (
    'low','medium','high','flight_risk'
  )),
  notice_period_days int not null,
  cross_training_status text not null check (cross_training_status in (
    'complete','in_progress','not_started'
  )),
  continuity_verdict text not null check (continuity_verdict in (
    'resilient','adequate','vulnerable','critical_gap'
  )),
  last_review_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.key_person_succession_r3265 enable row level security;

create index if not exists idx_key_person_succession_r3265_org on public.key_person_succession_r3265(organization_id);
create index if not exists idx_key_person_succession_r3265_review on public.key_person_succession_r3265(last_review_date);
create index if not exists idx_key_person_succession_r3265_verdict on public.key_person_succession_r3265(continuity_verdict);

-- =============================================================================
-- TABLE 2: key_person_succession_capa_actions_r3265 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.key_person_succession_capa_actions_r3265 (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references public.key_person_succession_r3265(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'no_successor_identified','single_point_of_failure','low_knowledge_documentation',
    'cross_training_gap','retention_risk_high','notice_period_too_short',
    'succession_plan_missing','bus_factor_one'
  )),
  root_cause text not null check (root_cause in (
    'no_talent_pipeline','undocumented_tribal_knowledge','no_backup_staffing',
    'compensation_below_market','founder_dependency','rapid_growth_understaffing',
    'pending_investigation','training_budget_constraint'
  )),
  corrective_action text not null check (corrective_action in (
    'hire_successor','document_sop_runbooks','initiate_cross_training','retention_bonus',
    'recruit_deputy','knowledge_transfer_sessions','engage_external_advisor',
    'update_succession_plan','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'operations_halt_risk','revenue_at_risk','compliance_gap','none','internal_only','board_escalation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.key_person_succession_capa_actions_r3265 enable row level security;

create index if not exists idx_key_person_capa_r3265_record on public.key_person_succession_capa_actions_r3265(record_id);
create index if not exists idx_key_person_capa_r3265_status on public.key_person_succession_capa_actions_r3265(capa_status);

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

  -- 14 critical-role rows
  insert into public.key_person_succession_r3265 (
    organization_id, entity_name, role_title, incumbent_name, function_area,
    criticality, bus_factor, successor_identified, successor_readiness, knowledge_documented_pct,
    single_point_of_failure, retention_risk, notice_period_days, cross_training_status,
    continuity_verdict, last_review_date, notes
  )
  select v_org_id, q.entity, q.role, q.name, q.fn,
    q.crit, q.bus, q.sid, q.sr, q.kdoc,
    q.spof, q.rr, q.notice, q.cts,
    q.verdict, q.lrd::date, q.nt
  from (values
    ('Apollo Chennai','Head of Field Engineering (South)','Rajesh Menon','engineering_leadership',
     'mission_critical',2,true,'ready_1yr',72.0,false,'medium',90,'in_progress','adequate','2026-07-05','South-zone engineering lead; deputy in training'),
    ('Fortis Gurgaon','Finance Controller','Neha Malhotra','finance',
     'high',1,false,'none',45.0,true,'high',60,'not_started','vulnerable','2026-07-04','Sole owner of statutory filings and audit interface'),
    ('Manipal Bengaluru','VP Sales','Aravind Krishnan','sales_leadership',
     'mission_critical',2,true,'ready_now',68.0,false,'low',90,'complete','resilient','2026-07-06','Strong bench; sales-ops head can step up'),
    ('AIIMS Delhi','Govt Accounts Relationship Lead','Suman Bose','customer_relationship',
     'mission_critical',1,false,'none',38.0,true,'flight_risk',30,'not_started','critical_gap','2026-07-03','Holds all AIIMS tender relationships single-handed'),
    ('CMC Vellore','Biomedical Systems Architect','Thomas Varghese','key_technical_specialist',
     'mission_critical',1,false,'ready_2yr',55.0,true,'medium',60,'in_progress','vulnerable','2026-07-02','Only engineer fluent in legacy calibration firmware'),
    ('KIMS Hyderabad','Regional Operations Manager','Lakshmi Narayanan','operations',
     'high',3,true,'ready_now',78.0,false,'low',60,'complete','resilient','2026-07-06','Well-documented ops playbook; two deputies'),
    ('Nova IVF Mumbai','Customer Success Head','Priya Deshpande','customer_relationship',
     'high',2,true,'ready_1yr',64.0,false,'medium',60,'in_progress','adequate','2026-07-01','Renewal book shared with regional CS leads'),
    ('Cloudnine Bengaluru','Founder / CEO Office','Karthik Subramanian','founder_office',
     'mission_critical',1,false,'none',30.0,true,'low',0,'not_started','critical_gap','2026-06-30','Investor and strategy relationships; no deputy identified'),
    ('Apollo Chennai','Lead Software Engineer (Platform)','Fatima Sheikh','key_technical_specialist',
     'high',2,true,'ready_1yr',70.0,false,'medium',60,'in_progress','adequate','2026-07-05','Platform knowledge shared via runbooks; pair in place'),
    ('Fortis Gurgaon','North Zone Sales Manager','Harpreet Singh','sales_leadership',
     'high',2,true,'ready_now',60.0,false,'medium',60,'complete','resilient','2026-07-04','Deputy manager cross-trained on key accounts'),
    ('Manipal Bengaluru','Head of Engineering (National)','Vivek Reddy','engineering_leadership',
     'mission_critical',1,true,'ready_2yr',52.0,true,'high',90,'in_progress','vulnerable','2026-07-06','Successor named but two years from readiness'),
    ('AIIMS Delhi','Finance & Compliance Lead (Govt)','Anjali Verma','finance',
     'high',2,true,'ready_1yr',66.0,false,'low',60,'in_progress','adequate','2026-07-03','Compliance SOPs documented; backup being trained'),
    ('Cloudnine Bengaluru','Regional Ops Manager (West)','Deepak Joshi','operations',
     'medium',3,true,'ready_now',82.0,false,'low',30,'complete','resilient','2026-06-29','Mature ops team; low key-person dependency'),
    ('Nova IVF Mumbai','Key Account Technical Specialist','Ramesh Iyer','key_technical_specialist',
     'high',1,false,'none',40.0,true,'flight_risk',30,'not_started','critical_gap','2026-07-01','Sole cryo-equipment specialist; actively interviewing')
  ) as q(entity, role, name, fn, crit, bus, sid, sr, kdoc, spof, rr, notice, cts, verdict, lrd, nt);

  -- CAPA seed — attach to specific at-risk roles by incumbent_name
  insert into public.key_person_succession_capa_actions_r3265 (
    record_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Neha Malhotra','no_successor_identified','no_talent_pipeline','hire_successor',
     'in_progress','compliance_gap','2026-08-15',null,900000.00,'Recruiting finance-controller backup; JD posted'),
    ('Suman Bose','single_point_of_failure','undocumented_tribal_knowledge','knowledge_transfer_sessions',
     'escalated','revenue_at_risk','2026-07-30',null,250000.00,'AIIMS tender relationships mapping into shared CRM'),
    ('Thomas Varghese','low_knowledge_documentation','undocumented_tribal_knowledge','document_sop_runbooks',
     'overdue','operations_halt_risk','2026-06-25',null,150000.00,'Firmware calibration runbook past due; vendor engaged'),
    ('Karthik Subramanian','succession_plan_missing','founder_dependency','update_succession_plan',
     'in_progress','board_escalation','2026-08-31',null,500000.00,'Board-level succession charter under drafting'),
    ('Vivek Reddy','cross_training_gap','no_backup_staffing','initiate_cross_training',
     'verification_pending','internal_only','2026-07-25',null,120000.00,'National-eng deputy shadowing on OEM escalations'),
    ('Ramesh Iyer','retention_risk_high','compensation_below_market','retention_bonus',
     'escalated','revenue_at_risk','2026-07-22',null,400000.00,'Counter-offer and cryo-specialist retention grant pending'),
    ('Rajesh Menon','cross_training_gap','rapid_growth_understaffing','recruit_deputy',
     'closed','internal_only','2026-06-30','2026-06-28',80000.00,'Deputy field-engineering lead hired for South zone')
  ) as q(name, fc, rc, ca, cst, bi, tcd, acd, cost, nt)
  join public.key_person_succession_r3265 e
    on e.organization_id = v_org_id and e.incumbent_name = q.name;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Continuity verdict distribution
create or replace function public.founder_r3265_continuity_verdict_rollup()
returns table(continuity_verdict text, roles bigint, spof_roles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.key_person_succession_r3265)
  select k.continuity_verdict, count(*)::bigint,
         count(*) filter (where k.single_point_of_failure)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.key_person_succession_r3265 k
  group by k.continuity_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3265_continuity_verdict_rollup() from public, anon;
grant execute on function public.founder_r3265_continuity_verdict_rollup() to authenticated;

-- 2) Entity / hospital-account scorecard
create or replace function public.founder_r3265_entity_scorecard()
returns table(
  entity_name text,
  total_roles bigint,
  mission_critical bigint,
  vulnerable bigint,
  spof_roles bigint,
  avg_knowledge_documented_pct numeric,
  avg_bus_factor numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select k.entity_name,
    count(*)::bigint,
    count(*) filter (where k.criticality = 'mission_critical')::bigint,
    count(*) filter (where k.continuity_verdict in ('vulnerable','critical_gap'))::bigint,
    count(*) filter (where k.single_point_of_failure)::bigint,
    round(avg(k.knowledge_documented_pct), 1),
    round(avg(k.bus_factor), 2)
  from public.key_person_succession_r3265 k
  group by k.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3265_entity_scorecard() from public, anon;
grant execute on function public.founder_r3265_entity_scorecard() to authenticated;

-- 3) Function × criticality matrix
create or replace function public.founder_r3265_function_criticality_matrix()
returns table(function_area text, criticality text, roles bigint, spof_roles bigint, avg_knowledge_documented_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select k.function_area, k.criticality, count(*)::bigint,
    count(*) filter (where k.single_point_of_failure)::bigint,
    round(avg(k.knowledge_documented_pct), 1)
  from public.key_person_succession_r3265 k
  group by k.function_area, k.criticality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3265_function_criticality_matrix() from public, anon;
grant execute on function public.founder_r3265_function_criticality_matrix() to authenticated;

-- 4) Succession-review trend by review date
create or replace function public.founder_r3265_review_trend()
returns table(last_review_date date, roles bigint, vulnerable bigint, spof_roles bigint, avg_knowledge_documented_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select k.last_review_date,
    count(*)::bigint,
    count(*) filter (where k.continuity_verdict in ('vulnerable','critical_gap'))::bigint,
    count(*) filter (where k.single_point_of_failure)::bigint,
    round(avg(k.knowledge_documented_pct), 1)
  from public.key_person_succession_r3265 k
  group by k.last_review_date
  order by k.last_review_date desc;
end;
$$;

revoke execute on function public.founder_r3265_review_trend() from public, anon;
grant execute on function public.founder_r3265_review_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3265_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.key_person_succession_capa_actions_r3265 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3265_capa_status_board() from public, anon;
grant execute on function public.founder_r3265_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3265_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.key_person_succession_capa_actions_r3265)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.key_person_succession_capa_actions_r3265 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3265_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3265_root_cause_pareto() to authenticated;

-- 7) Business-impact digest
create or replace function public.founder_r3265_business_impact_digest()
returns table(business_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.business_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.key_person_succession_capa_actions_r3265 c
  group by c.business_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3265_business_impact_digest() from public, anon;
grant execute on function public.founder_r3265_business_impact_digest() to authenticated;

-- 8) High-risk key-person queue (top continuity concerns)
create or replace function public.founder_r3265_high_risk_queue()
returns table(
  entity_name text,
  role_title text,
  incumbent_name text,
  function_area text,
  criticality text,
  bus_factor int,
  successor_readiness text,
  retention_risk text,
  continuity_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select k.entity_name, k.role_title, k.incumbent_name, k.function_area,
    k.criticality, k.bus_factor, k.successor_readiness, k.retention_risk,
    k.continuity_verdict, k.notes
  from public.key_person_succession_r3265 k
  where k.continuity_verdict in ('vulnerable','critical_gap')
     or k.single_point_of_failure
     or k.retention_risk in ('high','flight_risk')
     or k.successor_readiness = 'none'
  order by case k.continuity_verdict
             when 'critical_gap' then 0
             when 'vulnerable' then 1
             when 'adequate' then 2
             else 3
           end,
           k.entity_name;
end;
$$;

revoke execute on function public.founder_r3265_high_risk_queue() from public, anon;
grant execute on function public.founder_r3265_high_risk_queue() to authenticated;
