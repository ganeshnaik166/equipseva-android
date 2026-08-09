-- Round 3705: Founder Crisis-Communication / Incident-Comms Readiness Board
-- Crisis-comms readiness — scenario playbooks × owning function × spokesperson × contact-tree verification × drills × holding statements × readiness status × CAPA

-- =============================================================================
-- TABLE 1: crisis_comms_r3705 — per-scenario crisis-communication readiness log
-- =============================================================================
create table if not exists public.crisis_comms_r3705 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  scenario_name text not null,
  owning_function text not null,
  period_month date not null,
  playbook_current boolean not null,
  last_reviewed date,
  review_due date,
  spokesperson_assigned boolean not null,
  contact_tree_verified_pct numeric(5,1),
  drill_last_run date,
  drill_response_minutes numeric(6,1),
  stakeholder_groups_covered int,
  media_holding_statement_ready boolean not null,
  scenario_class text not null check (scenario_class in (
    'patient_safety_event','data_breach','regulatory_action','key_person_loss','service_outage','pr_social'
  )),
  readiness_status text not null check (readiness_status in (
    'ready','review_due','drill_overdue','gaps_found','unprepared'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crisis_comms_r3705 enable row level security;

create index if not exists idx_crisis_comms_r3705_org on public.crisis_comms_r3705(organization_id);
create index if not exists idx_crisis_comms_r3705_month on public.crisis_comms_r3705(period_month);
create index if not exists idx_crisis_comms_r3705_status on public.crisis_comms_r3705(readiness_status);

-- =============================================================================
-- TABLE 2: crisis_comms_capa_actions_r3705 — CAPA & readiness-gap actions
-- =============================================================================
create table if not exists public.crisis_comms_capa_actions_r3705 (
  id uuid primary key default gen_random_uuid(),
  readiness_id uuid not null references public.crisis_comms_r3705(id) on delete cascade,
  raised_at timestamptz not null default now(),
  gap_category text not null check (gap_category in (
    'playbook_outdated','spokesperson_unassigned','contact_tree_stale','drill_not_run',
    'holding_statement_missing','stakeholder_coverage_gap','escalation_path_unclear','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'owner_attrition','policy_change_unabsorbed','budget_deferred','competing_priorities',
    'vendor_dependency','no_drill_calendar','legal_review_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rewrite_playbook','assign_spokesperson','media_train_spokesperson','rebuild_contact_tree',
    'schedule_drill','draft_holding_statement','update_escalation_matrix','run_tabletop_exercise','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crisis_comms_capa_actions_r3705 enable row level security;

create index if not exists idx_crisis_comms_capa_r3705_log on public.crisis_comms_capa_actions_r3705(readiness_id);
create index if not exists idx_crisis_comms_capa_r3705_status on public.crisis_comms_capa_actions_r3705(capa_status);

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

  -- 16 readiness rows
  insert into public.crisis_comms_r3705 (
    organization_id, scenario_name, owning_function, period_month,
    playbook_current, last_reviewed, review_due, spokesperson_assigned,
    contact_tree_verified_pct, drill_last_run, drill_response_minutes,
    stakeholder_groups_covered, media_holding_statement_ready,
    scenario_class, readiness_status, trend_dir, notes
  )
  select v_org_id, q.sname, q.ofunc, q.pmon::date,
    q.pbcur, q.lrev::date, q.rdue::date, q.spox,
    q.ctpct, q.dlast::date, q.dresp,
    q.sgrp, q.mhold,
    q.sclass, q.rstat, q.tdir, q.nt
  from (values
    ('Ventilator adverse-event field response','Quality Assurance','2026-07-01',
     true,'2026-06-20','2026-09-20',true,94.0,'2026-06-18',42.0,6,true,
     'patient_safety_event','ready','improving','Playbook refreshed after mock drill; MDR notification chain tested end to end'),
    ('Defibrillator recall communication','Regulatory Affairs','2026-07-01',
     true,'2026-06-05','2026-09-05',true,88.5,'2026-05-28',55.0,5,true,
     'regulatory_action','ready','stable','CDSCO recall template pre-approved by legal counsel'),
    ('Customer PHI data-breach disclosure','IT Security','2026-07-01',
     false,'2026-02-10','2026-05-10',true,71.0,'2026-03-15',95.0,4,false,
     'data_breach','review_due','worsening','Playbook predates DPDP rules update — rewrite in progress'),
    ('Ransomware service-platform outage','IT Security','2026-07-01',
     true,'2026-06-12','2026-09-12',false,66.5,null,null,3,false,
     'service_outage','gaps_found','stable','No spokesperson named and drill never run for ransomware path'),
    ('CEO sudden unavailability succession comms','HR','2026-06-01',
     true,'2026-05-22','2026-08-22',true,90.0,'2026-05-20',38.0,4,true,
     'key_person_loss','ready','stable','Board-approved holding statement on file in crisis vault'),
    ('Viral social-media complaint on billing','Corporate Comms','2026-06-01',
     true,'2026-06-01','2026-09-01',true,82.0,'2026-06-02',30.0,5,true,
     'pr_social','ready','improving','Social-listening escalation tree verified in June drill'),
    ('CDSCO show-cause notice response','Regulatory Affairs','2026-06-01',
     false,'2026-01-18','2026-04-18',true,58.0,'2025-12-10',120.0,4,false,
     'regulatory_action','drill_overdue','worsening','Drill seven months old and quarterly review lapsed'),
    ('Hospital network outage during AMC peak','Service Operations','2026-06-01',
     true,'2026-05-30','2026-08-30',true,76.5,'2026-04-25',64.0,5,false,
     'service_outage','review_due','stable','Holding statement draft awaiting legal sign-off'),
    ('Implant batch patient-safety alert','Quality Assurance','2026-05-01',
     true,'2026-04-28','2026-07-28',true,91.5,'2026-04-22',47.0,6,true,
     'patient_safety_event','ready','stable','Field-safety notice pack validated against distributor list'),
    ('Payroll-vendor data leak employee comms','HR','2026-05-01',
     false,'2026-03-02','2026-06-02',false,40.0,null,null,2,false,
     'data_breach','unprepared','worsening','No drill ever run; contact tree stale after attrition'),
    ('Key OEM partner contract termination story','Corporate Comms','2026-05-01',
     true,'2026-04-15','2026-07-15',true,85.0,'2026-03-30',52.0,4,true,
     'pr_social','review_due','stable','Review due mid-July; media Q and A bank needs refresh'),
    ('Founder exit rumor market response','Corporate Comms','2026-05-01',
     true,'2026-04-20','2026-07-20',true,87.0,'2026-04-18',35.0,3,true,
     'key_person_loss','ready','improving','Investor and employee scripts rehearsed in April drill'),
    ('Oxygen concentrator failure cluster','Quality Assurance','2026-04-01',
     false,'2025-11-05','2026-02-05',false,52.5,'2025-10-20',140.0,3,false,
     'patient_safety_event','unprepared','worsening','Legacy playbook unowned after QA comms lead exit — rebuild assigned'),
    ('State drug-inspector surprise audit comms','Regulatory Affairs','2026-04-01',
     true,'2026-03-25','2026-06-25',true,79.0,'2026-03-12',58.0,4,true,
     'regulatory_action','review_due','stable','June review slipped two weeks; reschedule confirmed'),
    ('Marketplace payment-gateway outage','Service Operations','2026-04-01',
     true,'2026-04-02','2026-07-02',true,73.0,'2026-02-14',88.0,4,false,
     'service_outage','drill_overdue','stable','Drill older than 90-day SLA; holding statement missing UPI-failure variant'),
    ('Whistleblower allegation social amplification','Corporate Comms','2026-04-01',
     false,'2026-02-26','2026-05-26',false,61.0,null,null,5,false,
     'pr_social','gaps_found','worsening','No spokesperson for legal-sensitive topics; counsel review pending')
  ) as q(sname, ofunc, pmon, pbcur, lrev, rdue, spox, ctpct, dlast, dresp, sgrp, mhold, sclass, rstat, tdir, nt);

  -- CAPA seed — attach to specific scenarios via scenario_name
  insert into public.crisis_comms_capa_actions_r3705 (
    readiness_id, gap_category, root_cause, corrective_action,
    capa_status, action_owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.gcat, q.rc, q.ca,
    q.cst, q.aowner, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Customer PHI data-breach disclosure','playbook_outdated','policy_change_unabsorbed','rewrite_playbook','in_progress','Priya Nair','2026-08-25',null,120000.00,'DPDP-aligned rewrite at draft two; legal review booked'),
    ('Ransomware service-platform outage','spokesperson_unassigned','competing_priorities','assign_spokesperson','open','Arjun Mehta','2026-08-30',null,85000.00,'CTO proposed as spokesperson; media-training quote received'),
    ('Payroll-vendor data leak employee comms','contact_tree_stale','owner_attrition','rebuild_contact_tree','escalated','Kavita Rao','2026-08-15',null,45000.00,'HRIS export automation needed; escalated to CHRO'),
    ('CDSCO show-cause notice response','drill_not_run','no_drill_calendar','schedule_drill','overdue','Suresh Iyer','2026-07-31',null,60000.00,'Tabletop slipped twice against inspection season'),
    ('Oxygen concentrator failure cluster','playbook_outdated','owner_attrition','run_tabletop_exercise','open','Meena Pillai','2026-09-10',null,150000.00,'New QA comms lead onboarding; full rebuild plus exercise planned'),
    ('Marketplace payment-gateway outage','holding_statement_missing','legal_review_backlog','draft_holding_statement','verification_pending','Rohit Shetty','2026-08-12',null,25000.00,'UPI-failure variant drafted; awaiting counsel sign-off'),
    ('Whistleblower allegation social amplification','escalation_path_unclear','legal_review_backlog','update_escalation_matrix','in_progress','Ananya Ghosh','2026-08-20',null,55000.00,'Counsel defining privilege-safe approval chain'),
    ('Hospital network outage during AMC peak','holding_statement_missing','competing_priorities','draft_holding_statement','closed','Rohit Shetty','2026-07-05','2026-07-03',18000.00,'Statement approved and stored in crisis vault')
  ) as q(sname, gcat, rc, ca, cst, aowner, tcd, acd, cost, nt)
  join public.crisis_comms_r3705 e
    on e.organization_id = v_org_id and e.scenario_name = q.sname;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness status distribution
create or replace function public.founder_r3705_readiness_status_rollup()
returns table(readiness_status text, scenarios bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crisis_comms_r3705)
  select l.readiness_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.crisis_comms_r3705 l
  group by l.readiness_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3705_readiness_status_rollup() from public, anon;
grant execute on function public.founder_r3705_readiness_status_rollup() to authenticated;

-- 2) Owning-function readiness scorecard
create or replace function public.founder_r3705_owning_function_scorecard()
returns table(
  owning_function text,
  total_scenarios bigint,
  ready bigint,
  review_due bigint,
  drill_overdue bigint,
  gaps_or_unprepared bigint,
  avg_contact_tree_pct numeric,
  avg_drill_response_minutes numeric,
  ready_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owning_function,
    count(*)::bigint,
    count(*) filter (where l.readiness_status = 'ready')::bigint,
    count(*) filter (where l.readiness_status = 'review_due')::bigint,
    count(*) filter (where l.readiness_status = 'drill_overdue')::bigint,
    count(*) filter (where l.readiness_status in ('gaps_found','unprepared'))::bigint,
    round(avg(l.contact_tree_verified_pct), 1),
    round(avg(l.drill_response_minutes), 1),
    round(100.0 * count(*) filter (where l.readiness_status = 'ready')::numeric / nullif(count(*),0), 1)
  from public.crisis_comms_r3705 l
  group by l.owning_function
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3705_owning_function_scorecard() from public, anon;
grant execute on function public.founder_r3705_owning_function_scorecard() to authenticated;

-- 3) Scenario-class × readiness-status matrix
create or replace function public.founder_r3705_class_status_matrix()
returns table(scenario_class text, readiness_status text, scenarios bigint, avg_contact_tree_pct numeric, avg_drill_response_minutes numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scenario_class, l.readiness_status, count(*)::bigint,
    round(avg(l.contact_tree_verified_pct), 1),
    round(avg(l.drill_response_minutes), 1)
  from public.crisis_comms_r3705 l
  group by l.scenario_class, l.readiness_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3705_class_status_matrix() from public, anon;
grant execute on function public.founder_r3705_class_status_matrix() to authenticated;

-- 4) Monthly drill trend
create or replace function public.founder_r3705_monthly_drill_trend()
returns table(period_month date, scenarios bigint, drills_run bigint, avg_drill_response_minutes numeric, spokesperson_gaps bigint, playbook_stale bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.drill_last_run is not null)::bigint,
    round(avg(l.drill_response_minutes), 1),
    count(*) filter (where l.spokesperson_assigned = false)::bigint,
    count(*) filter (where l.playbook_current = false)::bigint
  from public.crisis_comms_r3705 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3705_monthly_drill_trend() from public, anon;
grant execute on function public.founder_r3705_monthly_drill_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3705_capa_status_board()
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
  from public.crisis_comms_capa_actions_r3705 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3705_capa_status_board() from public, anon;
grant execute on function public.founder_r3705_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3705_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crisis_comms_capa_actions_r3705)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.crisis_comms_capa_actions_r3705 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3705_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3705_root_cause_pareto() to authenticated;

-- 7) Readiness-gap digest
create or replace function public.founder_r3705_gap_digest()
returns table(gap_category text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.gap_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.crisis_comms_capa_actions_r3705 c
  group by c.gap_category
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3705_gap_digest() from public, anon;
grant execute on function public.founder_r3705_gap_digest() to authenticated;

-- 8) High-risk scenario queue (unprepared / gaps found / drill overdue)
create or replace function public.founder_r3705_high_risk_queue()
returns table(
  scenario_name text,
  owning_function text,
  scenario_class text,
  period_month date,
  readiness_status text,
  trend_dir text,
  spokesperson_assigned boolean,
  contact_tree_verified_pct numeric,
  media_holding_statement_ready boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scenario_name, l.owning_function, l.scenario_class, l.period_month,
    l.readiness_status, l.trend_dir, l.spokesperson_assigned,
    l.contact_tree_verified_pct, l.media_holding_statement_ready, l.notes
  from public.crisis_comms_r3705 l
  where l.readiness_status in ('unprepared','gaps_found','drill_overdue')
     or l.spokesperson_assigned = false
     or l.playbook_current = false
     or l.media_holding_statement_ready = false
  order by l.period_month desc, l.scenario_name;
end;
$$;

revoke all on function public.founder_r3705_high_risk_queue() from public, anon;
grant execute on function public.founder_r3705_high_risk_queue() to authenticated;
