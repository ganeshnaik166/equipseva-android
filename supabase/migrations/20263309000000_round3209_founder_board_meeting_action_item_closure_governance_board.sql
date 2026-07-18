-- Round 3209: Founder Board-Meeting Action-Item Closure & Governance Cadence Board
-- Board governance log — meeting date × action item × owner × due/closed × days-to-close × overdue × category × carry-over × verdict; + governance CAPA actions

-- =============================================================================
-- TABLE 1: board_actions_r3209 — board-meeting action items
-- =============================================================================
create table if not exists public.board_actions_r3209 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  board_meeting_date date not null,
  meeting_type text not null check (meeting_type in (
    'quarterly_board','monthly_review','annual_general','special_session',
    'audit_committee','compensation_committee','strategy_offsite','investor_update'
  )),
  action_item text not null,
  action_code text not null,
  owner_name text not null,
  owner_role text not null check (owner_role in (
    'ceo','cfo','coo','cto','vp_sales','vp_engineering',
    'general_counsel','head_hr','board_chair','independent_director'
  )),
  category text not null check (category in (
    'finance','product','hiring','legal','compliance','fundraising','operations','partnerships'
  )),
  priority text not null check (priority in ('critical','high','medium','low')),
  due_date date not null,
  closed_date date,
  days_to_close int,
  overdue_flag boolean not null default false,
  carry_over_count int not null default 0,
  verdict text not null check (verdict in (
    'closed_on_time','closed_late','open_on_track','open_overdue',
    'carried_over','blocked','dropped','pending_verification'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.board_actions_r3209 enable row level security;

create index if not exists idx_board_actions_r3209_org on public.board_actions_r3209(organization_id);
create index if not exists idx_board_actions_r3209_meeting on public.board_actions_r3209(board_meeting_date);
create index if not exists idx_board_actions_r3209_verdict on public.board_actions_r3209(verdict);

-- =============================================================================
-- TABLE 2: board_actions_capa_actions_r3209 — governance CAPA & follow-up actions
-- =============================================================================
create table if not exists public.board_actions_capa_actions_r3209 (
  id uuid primary key default gen_random_uuid(),
  board_action_id uuid not null references public.board_actions_r3209(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missed_deadline','no_owner_assigned','chronic_carry_over','incomplete_minutes',
    'quorum_gap','conflict_of_interest_undeclared','budget_overrun','compliance_lapse',
    'reporting_delay','follow_up_not_scheduled'
  )),
  root_cause text not null check (root_cause in (
    'unclear_ownership','competing_priorities','resource_shortage',
    'dependency_on_external_party','poor_meeting_hygiene','scope_creep',
    'budget_not_sanctioned','legal_review_backlog','data_unavailable','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reassign_owner','split_into_subtasks','escalate_to_chair','add_standing_agenda_item',
    'hire_external_counsel','automate_reporting','block_calendar_review',
    'sanction_budget','set_weekly_checkin','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'companies_act_filing','sebi_disclosure','shareholder_agreement_breach',
    'statutory_audit_flag','internal_only','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.board_actions_capa_actions_r3209 enable row level security;

create index if not exists idx_board_capa_r3209_action on public.board_actions_capa_actions_r3209(board_action_id);
create index if not exists idx_board_capa_r3209_status on public.board_actions_capa_actions_r3209(capa_status);

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

  -- 14 board action-item rows
  insert into public.board_actions_r3209 (
    organization_id, hospital_name, board_meeting_date, meeting_type,
    action_item, action_code, owner_name, owner_role, category, priority,
    due_date, closed_date, days_to_close, overdue_flag, carry_over_count, verdict, notes
  )
  select v_org_id, q.hosp, q.bmd::date, q.mt,
    q.ai, q.ac, q.own, q.orole, q.cat, q.pri,
    q.dd::date, q.cd::date, q.dtc, q.ovf, q.cc, q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','2026-04-10','quarterly_board',
     'Renew Apollo enterprise AMC master agreement','BA-001','Ganesh Rao','ceo','partnerships','critical',
     '2026-05-10','2026-05-05',25,false,0,'closed_on_time','Signed 3-year AMC master agreement'),
    ('Fortis Bannerghatta Bengaluru','2026-04-10','quarterly_board',
     'Resolve Fortis escrow dispute and release pending payouts','BA-002','Meera Iyer','cfo','finance','critical',
     '2026-05-01','2026-05-20',40,true,1,'closed_late','Escrow released after arbitration clause invoked'),
    ('Manipal Whitefield Bengaluru','2026-04-10','quarterly_board',
     'Ship Manipal multi-site asset dashboard pilot','BA-003','Arjun Nair','cto','product','high',
     '2026-06-15','2026-06-10',61,false,0,'closed_on_time','Pilot live across 3 Manipal sites'),
    ('AIIMS New Delhi Ansari Nagar','2026-04-10','audit_committee',
     'Complete AIIMS public-procurement compliance review','BA-004','Kavitha Menon','general_counsel','legal','critical',
     '2026-05-30',null,null,true,2,'open_overdue','GeM tender documentation still with external counsel'),
    ('KIMS Secunderabad','2026-05-08','monthly_review',
     'Hire regional service head for Telangana KIMS cluster','BA-005','Rohit Shetty','head_hr','hiring','high',
     '2026-06-30',null,null,false,1,'carried_over','Two finalists in offer stage'),
    ('Care Hospitals Banjara Hills','2026-05-08','monthly_review',
     'Standardize Care Banjara Hills spare-parts pricing annexure','BA-006','Meera Iyer','cfo','finance','medium',
     '2026-06-05','2026-06-05',28,false,0,'closed_on_time','Annexure v2 adopted by both parties'),
    ('Yashoda Somajiguda Hyderabad','2026-05-08','monthly_review',
     'Launch Yashoda ventilator uptime SLA addendum','BA-007','Arjun Nair','cto','product','high',
     '2026-06-20','2026-07-02',55,true,0,'closed_late','SLA addendum delayed by legal redlines'),
    ('St John''s Bengaluru','2026-05-08','special_session',
     'Close St John''s clinical engineering training MoU','BA-008','Ganesh Rao','ceo','partnerships','medium',
     '2026-07-15',null,null,false,0,'open_on_track','MoU draft in second review round'),
    ('Rainbow Children''s Hyderabad','2026-06-12','quarterly_board',
     'Fix Rainbow pediatric equipment recall escalation workflow','BA-009','Arjun Nair','cto','operations','critical',
     '2026-07-01',null,null,true,1,'blocked','Blocked on CDSCO recall-notice API access'),
    ('Apollo Hyderabad Jubilee Hills','2026-06-12','quarterly_board',
     'Prepare Series B data room with Apollo revenue cohort','BA-010','Meera Iyer','cfo','fundraising','critical',
     '2026-07-20',null,null,false,0,'open_on_track','Cohort tables 80 percent complete'),
    ('AIIMS New Delhi Ansari Nagar','2026-06-12','compensation_committee',
     'Approve ESOP refresh for AIIMS account engineering pod','BA-011','Rohit Shetty','head_hr','hiring','medium',
     '2026-07-10','2026-07-08',26,false,0,'closed_on_time','Board approved 1.2 percent pool refresh'),
    ('Fortis Bannerghatta Bengaluru','2026-06-12','audit_committee',
     'Remediate Fortis GST e-invoice mismatch findings','BA-012','Meera Iyer','cfo','compliance','high',
     '2026-07-05',null,null,true,2,'open_overdue','Awaiting GSTN portal correction window'),
    ('KIMS Secunderabad','2026-06-12','strategy_offsite',
     'Decide KIMS refurbished-equipment marketplace entry','BA-013','Ganesh Rao','ceo','product','low',
     '2026-08-01',null,null,false,3,'carried_over','Deferred third consecutive quarter — needs decision memo'),
    ('Manipal Whitefield Bengaluru','2026-06-12','investor_update',
     'Retire Manipal legacy paper AMC contracts digitization plan','BA-014','Kavitha Menon','general_counsel','legal','low',
     '2026-06-25',null,null,false,1,'dropped','Superseded by e-sign rollout')
  ) as q(hosp, bmd, mt, ai, ac, own, orole, cat, pri, dd, cd, dtc, ovf, cc, vd, nt);

  -- CAPA seed — attach to specific action items by action_code
  insert into public.board_actions_capa_actions_r3209 (
    board_action_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('BA-004','missed_deadline','legal_review_backlog','hire_external_counsel',
     '2026-07-25',null,'in_progress','statutory_audit_flag',350000.00,'Retained procurement counsel for GeM documentation'),
    ('BA-012','compliance_lapse','data_unavailable','automate_reporting',
     '2026-07-20',null,'escalated','statutory_audit_flag',120000.00,'E-invoice reconciliation escalated to audit committee'),
    ('BA-009','follow_up_not_scheduled','dependency_on_external_party','escalate_to_chair',
     '2026-07-15',null,'open','internal_only',0.00,'Chair to write to CDSCO liaison for recall API access'),
    ('BA-013','chronic_carry_over','unclear_ownership','reassign_owner',
     '2026-07-30',null,'in_progress','internal_only',50000.00,'Marketplace decision memo reassigned to CEO office'),
    ('BA-002','budget_overrun','scope_creep','sanction_budget',
     '2026-06-15','2026-06-12','closed','shareholder_agreement_breach',480000.00,'Arbitration fees sanctioned retrospectively by board'),
    ('BA-005','no_owner_assigned','competing_priorities','set_weekly_checkin',
     '2026-07-08','2026-07-06','closed','none',25000.00,'Weekly hiring stand-up with CEO instituted')
  ) as q(ac_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.board_actions_r3209 e
    on e.organization_id = v_org_id and e.action_code = q.ac_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Action-item verdict distribution
create or replace function public.founder_r3209_verdict_rollup()
returns table(verdict text, actions bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.board_actions_r3209)
  select b.verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.board_actions_r3209 b
  group by b.verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3209_verdict_rollup() from public, anon;
grant execute on function public.founder_r3209_verdict_rollup() to authenticated;

-- 2) Hospital / entity governance scorecard
create or replace function public.founder_r3209_hospital_scorecard()
returns table(
  hospital_name text,
  total_actions bigint,
  closed_on_time bigint,
  closed_late bigint,
  open_overdue bigint,
  carried_over bigint,
  avg_days_to_close numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_name,
    count(*)::bigint,
    count(*) filter (where b.verdict = 'closed_on_time')::bigint,
    count(*) filter (where b.verdict = 'closed_late')::bigint,
    count(*) filter (where b.verdict = 'open_overdue')::bigint,
    count(*) filter (where b.verdict = 'carried_over')::bigint,
    round(avg(b.days_to_close)::numeric, 1),
    round(100.0 * count(*) filter (where b.verdict = 'closed_on_time')::numeric / nullif(count(*),0), 1)
  from public.board_actions_r3209 b
  group by b.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3209_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3209_hospital_scorecard() to authenticated;

-- 3) Category × priority matrix
create or replace function public.founder_r3209_category_matrix()
returns table(category text, priority text, actions bigint, closed bigint, avg_days_to_close numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.category, b.priority, count(*)::bigint,
    count(*) filter (where b.verdict in ('closed_on_time','closed_late'))::bigint,
    round(avg(b.days_to_close)::numeric, 1)
  from public.board_actions_r3209 b
  group by b.category, b.priority
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3209_category_matrix() from public, anon;
grant execute on function public.founder_r3209_category_matrix() to authenticated;

-- 4) Meeting-date cadence trend
create or replace function public.founder_r3209_meeting_trend()
returns table(board_meeting_date date, actions bigint, closed bigint, overdue bigint, avg_carry_over numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.board_meeting_date,
    count(*)::bigint,
    count(*) filter (where b.verdict in ('closed_on_time','closed_late'))::bigint,
    count(*) filter (where b.overdue_flag)::bigint,
    round(avg(b.carry_over_count)::numeric, 2)
  from public.board_actions_r3209 b
  group by b.board_meeting_date
  order by b.board_meeting_date desc;
end;
$$;

revoke execute on function public.founder_r3209_meeting_trend() from public, anon;
grant execute on function public.founder_r3209_meeting_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3209_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, escalated_or_overdue bigint)
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
  from public.board_actions_capa_actions_r3209 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3209_capa_status_board() from public, anon;
grant execute on function public.founder_r3209_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3209_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.board_actions_capa_actions_r3209)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.board_actions_capa_actions_r3209 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3209_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3209_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3209_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','overdue','escalated'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.board_actions_capa_actions_r3209 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3209_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3209_regulatory_impact_digest() to authenticated;

-- 8) High-risk action-item queue
create or replace function public.founder_r3209_high_risk_actions()
returns table(
  hospital_name text,
  action_code text,
  action_item text,
  owner_name text,
  category text,
  priority text,
  due_date date,
  verdict text,
  carry_over_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.hospital_name, b.action_code, b.action_item, b.owner_name,
    b.category, b.priority, b.due_date, b.verdict, b.carry_over_count, b.notes
  from public.board_actions_r3209 b
  where b.verdict in ('open_overdue','blocked','carried_over','pending_verification')
     or b.overdue_flag
     or b.carry_over_count >= 2
     or (b.priority = 'critical' and b.verdict in ('open_on_track','open_overdue','blocked'))
  order by b.due_date asc, b.hospital_name;
end;
$$;

revoke execute on function public.founder_r3209_high_risk_actions() from public, anon;
grant execute on function public.founder_r3209_high_risk_actions() to authenticated;
