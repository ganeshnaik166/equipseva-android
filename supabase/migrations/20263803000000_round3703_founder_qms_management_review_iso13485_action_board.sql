-- Round 3703: QMS Management-Review (ISO-13485) Action Board
-- ISO-13485 clause-5.6 management-review meetings — inputs covered × decisions × action closure × overdue actions × input area × review status × trend × CAPA

-- =============================================================================
-- TABLE 1: mgmt_review_r3703 — per-review ISO-13485 clause-5.6 management-review log
-- =============================================================================
create table if not exists public.mgmt_review_r3703 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  review_ref text not null,
  site_scope text not null,
  period_month date not null,
  review_date date not null,
  next_review_due date,
  inputs_required int not null,
  inputs_covered int not null,
  input_coverage_pct numeric(5,1),
  decisions_made int not null,
  actions_assigned int not null,
  actions_closed int not null,
  action_closure_pct numeric(5,1),
  overdue_actions int not null,
  input_area text not null check (input_area in (
    'audit_results','customer_feedback','process_performance',
    'capa_status','regulatory_changes','resource_needs'
  )),
  review_status text not null check (review_status in (
    'completed_on_time','completed_late','scheduled','overdue','actions_pending'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mgmt_review_r3703 enable row level security;

create index if not exists idx_mgmt_review_r3703_org on public.mgmt_review_r3703(organization_id);
create index if not exists idx_mgmt_review_r3703_month on public.mgmt_review_r3703(period_month);
create index if not exists idx_mgmt_review_r3703_status on public.mgmt_review_r3703(review_status);

-- =============================================================================
-- TABLE 2: mgmt_review_capa_actions_r3703 — CAPA & follow-up actions per review
-- =============================================================================
create table if not exists public.mgmt_review_capa_actions_r3703 (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.mgmt_review_r3703(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'action_closure_slippage','input_not_covered','review_delayed',
    'decision_not_implemented','resource_gap_unaddressed','regulatory_change_missed',
    'effectiveness_check_missing','minutes_not_circulated'
  )),
  root_cause text not null check (root_cause in (
    'owner_bandwidth_shortage','cross_functional_dependency','budget_approval_delay',
    'tracking_sheet_not_updated','agenda_template_outdated','data_not_available_on_time',
    'ownership_ambiguity','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reassign_action_owner','escalate_to_leadership','automate_action_tracker',
    'update_review_agenda_template','pre_review_data_pack_sla','split_action_into_milestones',
    'add_interim_review_checkpoint','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mgmt_review_capa_actions_r3703 enable row level security;

create index if not exists idx_mgmt_review_capa_r3703_review on public.mgmt_review_capa_actions_r3703(review_id);
create index if not exists idx_mgmt_review_capa_r3703_status on public.mgmt_review_capa_actions_r3703(capa_status);

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

  -- 16 management-review rows
  insert into public.mgmt_review_r3703 (
    organization_id, review_ref, site_scope, period_month, review_date, next_review_due,
    inputs_required, inputs_covered, input_coverage_pct, decisions_made,
    actions_assigned, actions_closed, action_closure_pct, overdue_actions,
    input_area, review_status, trend_dir, notes
  )
  select v_org_id, q.rref, q.site, q.pmon::date, q.rdate::date, q.ndue::date,
    q.ireq, q.icov, q.icovp, q.dmade,
    q.aassn, q.aclsd, q.aclsp, q.aover,
    q.iarea, q.rstat, q.tdir, q.nt
  from (values
    ('MRM-2026-04-HO','Mumbai HO','2026-04-01','2026-04-10','2026-07-10',
     6,6,100.0,8,12,12,100.0,0,'audit_results','completed_on_time','improving','Q1 review closed all 12 actions — internal-audit findings fully addressed'),
    ('MRM-2026-04-PUN','Pune Plant','2026-04-01','2026-04-15','2026-07-15',
     6,5,83.3,5,9,7,77.8,1,'process_performance','completed_on_time','stable','Process yield input covered; one line-rework action carried over'),
    ('MRM-2026-04-KOC','Kochi Service Hub','2026-04-01','2026-04-22','2026-07-22',
     6,4,66.7,4,8,4,50.0,3,'capa_status','completed_late','worsening','Review held 7 days late; CAPA-status input thin and 3 actions overdue'),
    ('MRM-2026-05-JAI','Jaipur Warehouse','2026-05-01','2026-05-08','2026-08-08',
     6,6,100.0,6,10,9,90.0,0,'customer_feedback','completed_on_time','improving','Customer-feedback input strong — dispatch-damage complaints down'),
    ('MRM-2026-05-LKO','Lucknow Service Hub','2026-05-01','2026-05-12','2026-08-12',
     6,5,83.3,5,7,3,42.9,2,'resource_needs','actions_pending','worsening','Test-bench technician hiring action stuck pending budget'),
    ('MRM-2026-05-CHE','Chennai Plant','2026-05-01','2026-05-18','2026-08-18',
     6,6,100.0,7,11,10,90.9,0,'regulatory_changes','completed_on_time','stable','CDSCO MD-14 amendment reviewed; labelling actions on track'),
    ('MRM-2026-05-HO','Mumbai HO','2026-05-01','2026-05-25','2026-08-25',
     6,5,83.3,6,9,6,66.7,1,'capa_status','completed_late','stable','Held late due to leadership travel; CAPA backlog reviewed'),
    ('MRM-2026-06-PUN','Pune Plant','2026-06-01','2026-06-05','2026-09-05',
     6,6,100.0,9,14,11,78.6,1,'audit_results','completed_on_time','improving','Notified-body audit prep decisions logged; 3 actions in flight'),
    ('MRM-2026-06-KOC','Kochi Service Hub','2026-06-01','2026-06-12','2026-09-12',
     6,4,66.7,4,9,3,33.3,4,'process_performance','actions_pending','worsening','Service TAT input missing again; 4 actions overdue at close'),
    ('MRM-2026-06-JAI','Jaipur Warehouse','2026-06-01','2026-06-16','2026-09-16',
     6,6,100.0,5,8,8,100.0,0,'customer_feedback','completed_on_time','improving','All warehouse actions closed within cycle'),
    ('MRM-2026-06-LKO','Lucknow Service Hub','2026-06-01','2026-06-20','2026-09-20',
     6,3,50.0,3,6,2,33.3,3,'resource_needs','completed_late','worsening','Only half the required inputs presented — data pack arrived late'),
    ('MRM-2026-07-CHE','Chennai Plant','2026-07-01','2026-07-07','2026-10-07',
     6,6,100.0,6,10,8,80.0,1,'regulatory_changes','completed_on_time','stable','EU-MDR distributor-obligation change tracked; one action open'),
    ('MRM-2026-07-HO','Mumbai HO','2026-07-01','2026-07-14','2026-10-14',
     6,6,100.0,8,13,9,69.2,2,'audit_results','actions_pending','stable','Supplier-audit escalations assigned; two actions past due date'),
    ('MRM-2026-07-PUN','Pune Plant','2026-07-01','2026-07-21','2026-10-21',
     6,5,83.3,5,9,5,55.6,2,'capa_status','completed_late','stable','CAPA effectiveness checks pending on two closed items'),
    ('MRM-2026-08-KOC','Kochi Service Hub','2026-08-01','2026-08-04','2026-11-04',
     6,0,0.0,0,0,0,0.0,5,'process_performance','overdue','worsening','August review not convened — 5 prior-cycle actions still overdue'),
    ('MRM-2026-08-JAI','Jaipur Warehouse','2026-08-01','2026-08-20','2026-11-20',
     6,0,0.0,0,0,0,0.0,0,'audit_results','scheduled','stable','Scheduled — agenda and clause-5.6.2 input pack circulated')
  ) as q(rref, site, pmon, rdate, ndue, ireq, icov, icovp, dmade, aassn, aclsd, aclsp, aover, iarea, rstat, tdir, nt);

  -- CAPA seed — attach to specific reviews via review_ref
  insert into public.mgmt_review_capa_actions_r3703 (
    review_id, finding_category, root_cause, corrective_action,
    capa_status, estimated_cost_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.cost, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('MRM-2026-04-KOC','action_closure_slippage','owner_bandwidth_shortage','reassign_action_owner','in_progress',18000.00,'Rakesh Nair','2026-08-20',null,'Three service-audit actions reassigned to hub QA lead'),
    ('MRM-2026-05-LKO','resource_gap_unaddressed','budget_approval_delay','escalate_to_leadership','escalated',250000.00,'Priya Sharma','2026-08-15',null,'Test-bench technician hiring budget escalated to CFO'),
    ('MRM-2026-06-KOC','action_closure_slippage','cross_functional_dependency','split_action_into_milestones','open',40000.00,'Rakesh Nair','2026-08-30',null,'Service-TAT action split into spares, staffing and tooling milestones'),
    ('MRM-2026-06-LKO','input_not_covered','data_not_available_on_time','pre_review_data_pack_sla','verification_pending',0.00,'Anil Gupta','2026-08-10',null,'T-minus-5-day data-pack SLA introduced — verify at next review'),
    ('MRM-2026-05-HO','review_delayed','agenda_template_outdated','update_review_agenda_template','closed',5000.00,'Meera Iyer','2026-06-30','2026-06-24','Agenda template rebuilt against clause-5.6.2 input checklist'),
    ('MRM-2026-07-HO','decision_not_implemented','ownership_ambiguity','reassign_action_owner','in_progress',12000.00,'Meera Iyer','2026-08-25',null,'Supplier-audit escalation had two owners — single owner named'),
    ('MRM-2026-08-KOC','review_delayed','owner_bandwidth_shortage','add_interim_review_checkpoint','overdue',8000.00,'Rakesh Nair','2026-08-07',null,'August review missed — interim checkpoint now past due'),
    ('MRM-2026-07-PUN','effectiveness_check_missing','tracking_sheet_not_updated','automate_action_tracker','open',60000.00,'Sandeep Kulkarni','2026-09-05',null,'Action tracker moving from spreadsheet to QMS software module')
  ) as q(rref, fc, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.mgmt_review_r3703 e
    on e.organization_id = v_org_id and e.review_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Review status distribution
create or replace function public.founder_r3703_review_status_rollup()
returns table(review_status text, reviews bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mgmt_review_r3703)
  select l.review_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mgmt_review_r3703 l
  group by l.review_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3703_review_status_rollup() from public, anon;
grant execute on function public.founder_r3703_review_status_rollup() to authenticated;

-- 2) Site-scope scorecard
create or replace function public.founder_r3703_site_scope_scorecard()
returns table(
  site_scope text,
  reviews bigint,
  on_time bigint,
  late bigint,
  pending_or_overdue bigint,
  avg_input_coverage_pct numeric,
  avg_closure_pct numeric,
  total_overdue_actions bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_scope,
    count(*)::bigint,
    count(*) filter (where l.review_status = 'completed_on_time')::bigint,
    count(*) filter (where l.review_status = 'completed_late')::bigint,
    count(*) filter (where l.review_status in ('actions_pending','overdue'))::bigint,
    round(avg(l.input_coverage_pct), 1),
    round(avg(l.action_closure_pct), 1),
    coalesce(sum(l.overdue_actions),0)::bigint
  from public.mgmt_review_r3703 l
  group by l.site_scope
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3703_site_scope_scorecard() from public, anon;
grant execute on function public.founder_r3703_site_scope_scorecard() to authenticated;

-- 3) Input-area × review-status matrix
create or replace function public.founder_r3703_input_area_status_matrix()
returns table(input_area text, review_status text, reviews bigint, avg_closure_pct numeric, overdue_actions bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.input_area, l.review_status, count(*)::bigint,
    round(avg(l.action_closure_pct), 1),
    coalesce(sum(l.overdue_actions),0)::bigint
  from public.mgmt_review_r3703 l
  group by l.input_area, l.review_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3703_input_area_status_matrix() from public, anon;
grant execute on function public.founder_r3703_input_area_status_matrix() to authenticated;

-- 4) Monthly action-closure trend
create or replace function public.founder_r3703_monthly_closure_trend()
returns table(period_month date, reviews bigint, decisions bigint, actions_assigned bigint, actions_closed bigint, avg_closure_pct numeric, overdue_actions bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.decisions_made),0)::bigint,
    coalesce(sum(l.actions_assigned),0)::bigint,
    coalesce(sum(l.actions_closed),0)::bigint,
    round(avg(l.action_closure_pct), 1),
    coalesce(sum(l.overdue_actions),0)::bigint
  from public.mgmt_review_r3703 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3703_monthly_closure_trend() from public, anon;
grant execute on function public.founder_r3703_monthly_closure_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3703_capa_status_board()
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
  from public.mgmt_review_capa_actions_r3703 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3703_capa_status_board() from public, anon;
grant execute on function public.founder_r3703_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3703_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mgmt_review_capa_actions_r3703)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mgmt_review_capa_actions_r3703 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3703_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3703_root_cause_pareto() to authenticated;

-- 7) Overdue-action digest
create or replace function public.founder_r3703_overdue_action_digest()
returns table(
  review_ref text,
  site_scope text,
  review_date date,
  review_status text,
  actions_assigned int,
  actions_closed int,
  overdue_actions int,
  action_closure_pct numeric,
  trend_dir text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_ref, l.site_scope, l.review_date, l.review_status,
    l.actions_assigned, l.actions_closed, l.overdue_actions,
    l.action_closure_pct, l.trend_dir
  from public.mgmt_review_r3703 l
  where l.overdue_actions > 0
  order by l.overdue_actions desc, l.review_date desc;
end;
$$;

revoke all on function public.founder_r3703_overdue_action_digest() from public, anon;
grant execute on function public.founder_r3703_overdue_action_digest() to authenticated;

-- 8) High-risk review queue (overdue / actions-pending / worsening)
create or replace function public.founder_r3703_high_risk_queue()
returns table(
  review_ref text,
  site_scope text,
  period_month date,
  review_date date,
  review_status text,
  input_area text,
  overdue_actions int,
  action_closure_pct numeric,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_ref, l.site_scope, l.period_month, l.review_date,
    l.review_status, l.input_area, l.overdue_actions,
    l.action_closure_pct, l.trend_dir, l.notes
  from public.mgmt_review_r3703 l
  where l.review_status in ('overdue','actions_pending')
     or l.overdue_actions > 0
     or l.trend_dir = 'worsening'
  order by l.overdue_actions desc, l.review_date desc;
end;
$$;

revoke all on function public.founder_r3703_high_risk_queue() from public, anon;
grant execute on function public.founder_r3703_high_risk_queue() to authenticated;
