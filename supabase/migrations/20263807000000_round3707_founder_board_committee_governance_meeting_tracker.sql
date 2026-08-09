-- Round 3707: Board-Committee Governance / Meeting Tracker
-- Board committees (audit/NRC/CSR/risk/IT steering) — meetings held vs required × quorum × attendance × action closure × minutes filing × CAPA

-- =============================================================================
-- TABLE 1: board_committee_r3707 — per-committee per-month governance tracker
-- =============================================================================
create table if not exists public.board_committee_r3707 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  committee_ref text not null,
  committee_name text not null,
  chair_name text not null,
  committee_class text not null check (committee_class in (
    'audit_committee','nomination_remuneration','csr_committee','risk_committee','it_steering'
  )),
  period_month date not null,
  meetings_required int not null,
  meetings_held int not null,
  quorum_met_pct numeric(5,2),
  avg_attendance_pct numeric(5,2),
  agenda_items int,
  actions_assigned int,
  actions_closed int,
  action_closure_pct numeric(5,2),
  overdue_actions int,
  minutes_filed_on_time boolean not null,
  governance_status text not null check (governance_status in (
    'compliant','on_track','meeting_gap','quorum_risk','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.board_committee_r3707 enable row level security;

create index if not exists idx_board_committee_r3707_org on public.board_committee_r3707(organization_id);
create index if not exists idx_board_committee_r3707_month on public.board_committee_r3707(period_month);
create index if not exists idx_board_committee_r3707_status on public.board_committee_r3707(governance_status);

-- =============================================================================
-- TABLE 2: board_committee_capa_actions_r3707 — governance CAPA actions
-- =============================================================================
create table if not exists public.board_committee_capa_actions_r3707 (
  id uuid primary key default gen_random_uuid(),
  committee_row_id uuid not null references public.board_committee_r3707(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'meeting_not_held','quorum_shortfall','action_closure_lag','minutes_filing_delay',
    'attendance_shortfall','overdue_action_backlog','agenda_deferral','composition_gap'
  )),
  root_cause text not null check (root_cause in (
    'chair_unavailability','quorum_shortfall_members','agenda_overload','secretarial_bandwidth',
    'member_resignation','calendar_conflict','action_owner_turnover','pending_investigation',
    'minutes_drafting_delay','tracking_tool_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'reschedule_meeting','appoint_alternate_chair','co_opt_independent_director','automate_action_tracker',
    'strengthen_secretarial_team','recirculate_calendar_invites','escalate_to_board_chair',
    'conduct_special_session','retrain_committee_secretariat','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  governance_risk_score numeric(5,2),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.board_committee_capa_actions_r3707 enable row level security;

create index if not exists idx_board_committee_capa_r3707_row on public.board_committee_capa_actions_r3707(committee_row_id);
create index if not exists idx_board_committee_capa_r3707_status on public.board_committee_capa_actions_r3707(capa_status);

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

  -- 15 committee-month tracker rows
  insert into public.board_committee_r3707 (
    organization_id, committee_ref, committee_name, chair_name, committee_class, period_month,
    meetings_required, meetings_held, quorum_met_pct, avg_attendance_pct,
    agenda_items, actions_assigned, actions_closed, action_closure_pct, overdue_actions,
    minutes_filed_on_time, governance_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.cname, q.chair, q.cclass, q.pmon::date,
    q.mreq, q.mheld, q.qpct, q.apct,
    q.aitems, q.aassn, q.aclosed, q.clpct, q.ovd,
    q.mfot, q.gstat, q.tdir, q.nt
  from (values
    ('AC-2026-05','Audit Committee','R. Chandrasekaran','audit_committee','2026-05-01',
     2,2,100.0,92.5,9,12,11,91.7,1,true,'compliant','stable','Both quarterly-close meetings held; one legacy internal-audit action pending'),
    ('AC-2026-06','Audit Committee','R. Chandrasekaran','audit_committee','2026-06-01',
     1,1,100.0,88.0,7,8,6,75.0,2,true,'on_track','stable','Statutory auditor interaction completed; two IFC actions carried forward'),
    ('AC-2026-07','Audit Committee','R. Chandrasekaran','audit_committee','2026-07-01',
     1,1,100.0,95.0,8,10,9,90.0,1,true,'compliant','improving','Related-party transactions register reviewed and approved on time'),
    ('NRC-2026-05','Nomination & Remuneration Committee','Meera Krishnan','nomination_remuneration','2026-05-01',
     1,1,100.0,80.0,5,6,4,66.7,2,true,'on_track','stable','KMP appraisal cycle kicked off; two policy actions in flight'),
    ('NRC-2026-06','Nomination & Remuneration Committee','Meera Krishnan','nomination_remuneration','2026-06-01',
     1,0,0.0,0.0,0,4,1,25.0,3,false,'meeting_gap','worsening','ESOP grant review meeting deferred — chair overseas travel'),
    ('NRC-2026-07','Nomination & Remuneration Committee','Meera Krishnan','nomination_remuneration','2026-07-01',
     1,1,100.0,62.5,6,5,3,60.0,2,true,'quorum_risk','improving','Quorum met narrowly with two independent directors joining on video'),
    ('CSR-2026-05','CSR Committee','Anjali Deshpande','csr_committee','2026-05-01',
     1,1,100.0,90.0,4,5,5,100.0,0,true,'compliant','stable','Rural diagnostics camp programme approved; all actions closed'),
    ('CSR-2026-06','CSR Committee','Anjali Deshpande','csr_committee','2026-06-01',
     1,1,100.0,85.0,5,6,4,66.7,1,false,'on_track','stable','Meeting held on time but minutes filed three days late'),
    ('CSR-2026-07','CSR Committee','Anjali Deshpande','csr_committee','2026-07-01',
     1,0,0.0,0.0,0,3,0,0.0,3,false,'non_compliant','worsening','CSR spend approval meeting missed — Schedule VII utilisation deadline at risk'),
    ('RMC-2026-05','Risk Management Committee','Vikram Bhatt','risk_committee','2026-05-01',
     1,1,100.0,87.5,6,9,7,77.8,2,true,'on_track','improving','Enterprise risk register refreshed; supplier concentration flagged'),
    ('RMC-2026-06','Risk Management Committee','Vikram Bhatt','risk_committee','2026-06-01',
     2,1,100.0,70.0,8,10,5,50.0,4,true,'meeting_gap','worsening','Special cyber-risk session deferred; action backlog building'),
    ('RMC-2026-07','Risk Management Committee','Vikram Bhatt','risk_committee','2026-07-01',
     2,2,50.0,68.0,10,12,8,66.7,3,true,'quorum_risk','stable','One of two meetings inquorate — reconvened with shortened agenda'),
    ('ITSC-2026-05','IT Steering Committee','Farhan Sheikh','it_steering','2026-05-01',
     1,1,100.0,95.0,7,8,8,100.0,0,true,'compliant','stable','ERP cutover readiness reviewed; all actions closed in-month'),
    ('ITSC-2026-06','IT Steering Committee','Farhan Sheikh','it_steering','2026-06-01',
     1,1,100.0,90.0,6,7,5,71.4,1,true,'on_track','stable','Cybersecurity posture review done; MDM rollout action open'),
    ('ITSC-2026-07','IT Steering Committee','Farhan Sheikh','it_steering','2026-07-01',
     1,0,0.0,0.0,0,5,2,40.0,3,false,'meeting_gap','worsening','ERP go-live review pushed out — three integration actions now overdue')
  ) as q(cref, cname, chair, cclass, pmon, mreq, mheld, qpct, apct, aitems, aassn, aclosed, clpct, ovd, mfot, gstat, tdir, nt);

  -- CAPA seed — attach to specific committee-months via committee_ref
  insert into public.board_committee_capa_actions_r3707 (
    committee_row_id, finding_category, root_cause, corrective_action,
    capa_status, governance_risk_score, action_owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.score, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('NRC-2026-06','meeting_not_held','chair_unavailability','reschedule_meeting','closed',6.5,'Company Secretary','2026-07-10','2026-07-08','Deferred NRC meeting reconvened in July with full quorum'),
    ('CSR-2026-07','meeting_not_held','calendar_conflict','conduct_special_session','escalated',8.8,'CS & Compliance Head','2026-08-05',null,'CSR spend approval pending — special session sought before Schedule VII cutoff'),
    ('RMC-2026-06','agenda_deferral','agenda_overload','conduct_special_session','in_progress',7.2,'Chief Risk Officer','2026-08-12',null,'Cyber-risk deep-dive split into a dedicated special session'),
    ('RMC-2026-07','quorum_shortfall','member_resignation','co_opt_independent_director','open',8.0,'Board Chair Office','2026-08-20',null,'Independent director vacancy driving inquorate meetings — co-option underway'),
    ('ITSC-2026-07','meeting_not_held','calendar_conflict','recirculate_calendar_invites','in_progress',5.5,'CIO Office','2026-08-10',null,'ERP go-live review rescheduled; annual meeting calendar re-blocked'),
    ('AC-2026-06','action_closure_lag','action_owner_turnover','automate_action_tracker','verification_pending',6.0,'Internal Audit Head','2026-08-08',null,'Action tracker moved to board-portal tool — closure evidence under verification'),
    ('CSR-2026-06','minutes_filing_delay','secretarial_bandwidth','strengthen_secretarial_team','closed',3.5,'Company Secretary','2026-07-15','2026-07-12','Additional CS executive onboarded; minutes now filed within 48 hours'),
    ('NRC-2026-07','attendance_shortfall','calendar_conflict','recirculate_calendar_invites','open',5.0,'Company Secretary','2026-08-18',null,'Two members attended on video only — physical attendance push for next meeting')
  ) as q(cref, fc, rc, ca, cst, score, ownr, tcd, acd, nt)
  join public.board_committee_r3707 e
    on e.organization_id = v_org_id and e.committee_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Governance status distribution
create or replace function public.founder_r3707_governance_status_rollup()
returns table(governance_status text, committee_months bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.board_committee_r3707)
  select l.governance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.board_committee_r3707 l
  group by l.governance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3707_governance_status_rollup() from public, anon;
grant execute on function public.founder_r3707_governance_status_rollup() to authenticated;

-- 2) Committee scorecard
create or replace function public.founder_r3707_committee_scorecard()
returns table(
  committee_name text,
  committee_class text,
  periods bigint,
  meetings_required_total bigint,
  meetings_held_total bigint,
  avg_quorum_pct numeric,
  avg_attendance numeric,
  avg_closure_pct numeric,
  overdue_actions_total bigint,
  minutes_on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committee_name,
    l.committee_class,
    count(*)::bigint,
    coalesce(sum(l.meetings_required),0)::bigint,
    coalesce(sum(l.meetings_held),0)::bigint,
    round(avg(l.quorum_met_pct), 1),
    round(avg(l.avg_attendance_pct), 1),
    round(avg(l.action_closure_pct), 1),
    coalesce(sum(l.overdue_actions),0)::bigint,
    round(100.0 * count(*) filter (where l.minutes_filed_on_time)::numeric / nullif(count(*),0), 1)
  from public.board_committee_r3707 l
  group by l.committee_name, l.committee_class
  order by coalesce(sum(l.overdue_actions),0) desc;
end;
$$;

revoke all on function public.founder_r3707_committee_scorecard() from public, anon;
grant execute on function public.founder_r3707_committee_scorecard() to authenticated;

-- 3) Committee class × governance status matrix
create or replace function public.founder_r3707_class_status_matrix()
returns table(committee_class text, governance_status text, committee_months bigint, avg_closure_pct numeric, overdue_actions_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committee_class, l.governance_status, count(*)::bigint,
    round(avg(l.action_closure_pct), 1),
    coalesce(sum(l.overdue_actions),0)::bigint
  from public.board_committee_r3707 l
  group by l.committee_class, l.governance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3707_class_status_matrix() from public, anon;
grant execute on function public.founder_r3707_class_status_matrix() to authenticated;

-- 4) Monthly closure trend
create or replace function public.founder_r3707_monthly_closure_trend()
returns table(period_month date, committee_months bigint, meetings_required_total bigint, meetings_held_total bigint, avg_closure_pct numeric, overdue_actions_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.meetings_required),0)::bigint,
    coalesce(sum(l.meetings_held),0)::bigint,
    round(avg(l.action_closure_pct), 1),
    coalesce(sum(l.overdue_actions),0)::bigint
  from public.board_committee_r3707 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3707_monthly_closure_trend() from public, anon;
grant execute on function public.founder_r3707_monthly_closure_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3707_capa_status_board()
returns table(capa_status text, findings bigint, avg_risk_score numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.governance_risk_score)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.board_committee_capa_actions_r3707 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3707_capa_status_board() from public, anon;
grant execute on function public.founder_r3707_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3707_root_cause_pareto()
returns table(root_cause text, occurrences bigint, avg_risk_score numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.board_committee_capa_actions_r3707)
  select c.root_cause, count(*)::bigint,
    round(avg(c.governance_risk_score)::numeric, 1),
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.board_committee_capa_actions_r3707 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3707_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3707_root_cause_pareto() to authenticated;

-- 7) Overdue-action digest
create or replace function public.founder_r3707_overdue_action_digest()
returns table(
  committee_name text,
  committee_class text,
  actions_assigned_total bigint,
  actions_closed_total bigint,
  overdue_actions_total bigint,
  avg_closure_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committee_name, l.committee_class,
    coalesce(sum(l.actions_assigned),0)::bigint,
    coalesce(sum(l.actions_closed),0)::bigint,
    coalesce(sum(l.overdue_actions),0)::bigint,
    round(avg(l.action_closure_pct), 1)
  from public.board_committee_r3707 l
  where l.overdue_actions > 0
  group by l.committee_name, l.committee_class
  order by coalesce(sum(l.overdue_actions),0) desc;
end;
$$;

revoke all on function public.founder_r3707_overdue_action_digest() from public, anon;
grant execute on function public.founder_r3707_overdue_action_digest() to authenticated;

-- 8) High-risk committee queue
create or replace function public.founder_r3707_high_risk_queue()
returns table(
  committee_ref text,
  committee_name text,
  chair_name text,
  committee_class text,
  period_month date,
  governance_status text,
  trend_dir text,
  quorum_met_pct numeric,
  overdue_actions int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committee_ref, l.committee_name, l.chair_name, l.committee_class, l.period_month,
    l.governance_status, l.trend_dir, l.quorum_met_pct, l.overdue_actions, l.notes
  from public.board_committee_r3707 l
  where l.governance_status in ('non_compliant','quorum_risk','meeting_gap')
     or l.trend_dir = 'worsening'
     or l.minutes_filed_on_time = false
     or l.meetings_held < l.meetings_required
  order by l.period_month desc, l.committee_name;
end;
$$;

revoke all on function public.founder_r3707_high_risk_queue() from public, anon;
grant execute on function public.founder_r3707_high_risk_queue() to authenticated;
