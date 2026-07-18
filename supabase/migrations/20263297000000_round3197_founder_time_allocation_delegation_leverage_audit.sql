-- Round 3197: Founder Founder-Time Allocation & Delegation-Leverage Audit
-- Founder time audit — week × activity bucket × hours × leverage score × delegable flag × delegated-to × energy rating × ROI verdict × rebalance CAPA

-- =============================================================================
-- TABLE 1: founder_time_r3197 — individual founder time-block entries
-- =============================================================================
create table if not exists public.founder_time_r3197 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  entry_ref text not null,
  week_start date not null,
  work_date date not null,
  activity_bucket text not null check (activity_bucket in (
    'sales','product','ops','hiring','fundraise','firefighting','deep_work'
  )),
  activity_detail text not null,
  hours_spent numeric(5,2) not null,
  leverage_score int not null check (leverage_score between 1 and 10),
  delegable boolean not null default false,
  delegated_to text not null check (delegated_to in (
    'not_delegated','executive_assistant','ops_manager','sales_lead',
    'engineering_lead','service_head','finance_consultant','agency_partner'
  )),
  energy_rating text not null check (energy_rating in (
    'energizing','sustaining','neutral','draining','exhausting'
  )),
  roi_verdict text not null check (roi_verdict in (
    'high_roi_keep','strategic_keep','delegate_now','delegate_next_quarter',
    'automate','eliminate','renegotiate_scope'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_time_r3197 enable row level security;

create index if not exists idx_founder_time_r3197_org on public.founder_time_r3197(organization_id);
create index if not exists idx_founder_time_r3197_week on public.founder_time_r3197(week_start);
create index if not exists idx_founder_time_r3197_verdict on public.founder_time_r3197(roi_verdict);

-- =============================================================================
-- TABLE 2: founder_time_capa_actions_r3197 — rebalance / delegation CAPA actions
-- =============================================================================
create table if not exists public.founder_time_capa_actions_r3197 (
  id uuid primary key default gen_random_uuid(),
  time_entry_id uuid not null references public.founder_time_r3197(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'firefighting_overload','delegation_gap','low_leverage_drift','energy_drain',
    'calendar_fragmentation','deep_work_starvation','meeting_bloat',
    'hiring_bottleneck','context_switching','fundraise_crunch'
  )),
  root_cause text not null check (root_cause in (
    'no_second_in_command','unclear_ownership','founder_bottleneck_approvals',
    'weak_sops','reactive_customer_escalations','no_ea_support',
    'trust_gap_in_team','tooling_gap','overcommitted_calendar','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'hire_executive_assistant','promote_ops_lead','write_sop_and_handoff',
    'install_weekly_delegation_review','block_deep_work_mornings','batch_meetings_two_days',
    'automate_reporting_dashboard','decline_low_roi_meetings','engage_fractional_cfo','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','board_reportable','investor_update_flag',
    'compliance_filing_risk','key_account_risk'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_time_capa_actions_r3197 enable row level security;

create index if not exists idx_founder_time_capa_r3197_entry on public.founder_time_capa_actions_r3197(time_entry_id);
create index if not exists idx_founder_time_capa_r3197_status on public.founder_time_capa_actions_r3197(capa_status);

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

  -- 13 founder time-block rows
  insert into public.founder_time_r3197 (
    organization_id, entity_name, entry_ref, week_start, work_date,
    activity_bucket, activity_detail, hours_spent, leverage_score,
    delegable, delegated_to, energy_rating, roi_verdict, notes
  )
  select v_org_id, q.ent, q.ref, q.ws::date, q.wd::date,
    q.ab, q.det, q.hrs, q.lev,
    q.del, q.dto, q.en, q.roi, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','FT-W27-01','2026-06-29','2026-06-29',
     'sales','Apollo CMD pitch for enterprise AMC rollout',4.50,9,false,'not_delegated','energizing','high_roi_keep','Founder-led enterprise sale — keep in founder calendar'),
    ('Fortis Bannerghatta Bengaluru','FT-W27-02','2026-06-29','2026-06-30',
     'firefighting','Ventilator repair SLA-breach war room escalation',6.00,3,true,'service_head','exhausting','delegate_now','Service head should own war rooms with an SOP'),
    ('Manipal Whitefield Bengaluru','FT-W27-03','2026-06-29','2026-06-30',
     'product','On-site shadowing of biomedical team for PM module specs',5.00,8,false,'not_delegated','energizing','strategic_keep','Founder-led discovery still needed pre-PMF'),
    ('AIIMS New Delhi Ansari Nagar','FT-W27-04','2026-06-29','2026-07-01',
     'ops','Tender paperwork and GeM portal compliance filing',3.50,2,true,'ops_manager','draining','delegate_now','Pure process work — checklist exists'),
    ('KIMS Secunderabad','FT-W27-05','2026-06-29','2026-07-01',
     'firefighting','Billing dispute call — escrow release stuck',2.00,3,true,'finance_consultant','draining','delegate_next_quarter','Needs a fractional CFO to own disputes'),
    ('Care Hospitals Banjara Hills','FT-W27-06','2026-06-29','2026-07-02',
     'sales','Renewal negotiation for 42-asset AMC bundle',3.00,7,false,'not_delegated','sustaining','high_roi_keep',null),
    ('Yashoda Somajiguda Hyderabad','FT-W27-07','2026-06-29','2026-07-02',
     'ops','Manual invoice reconciliation spreadsheet for Yashoda account',4.00,1,true,'executive_assistant','exhausting','automate','Automate via finance dashboard export'),
    ('St John''s Bengaluru','FT-W27-08','2026-06-29','2026-07-03',
     'hiring','Interview loop for Bengaluru service engineer pod',5.50,6,true,'engineering_lead','neutral','delegate_next_quarter','Founder keeps final round only'),
    ('Rainbow Children''s Hyderabad','FT-W27-09','2026-06-29','2026-07-03',
     'product','Pediatric equipment checklist feature review',2.50,5,true,'engineering_lead','sustaining','renegotiate_scope','Attend demo only, stop writing specs'),
    ('Apollo Hyderabad Jubilee Hills','FT-W28-10','2026-07-06','2026-07-06',
     'deep_work','Drafting Apollo group-wide rollout proposal',6.00,10,false,'not_delegated','energizing','high_roi_keep','Highest-leverage block this fortnight'),
    ('Fortis Bannerghatta Bengaluru','FT-W28-11','2026-07-06','2026-07-07',
     'fundraise','Series A data room — Fortis cohort revenue evidence',4.00,9,false,'not_delegated','sustaining','strategic_keep',null),
    ('Manipal Whitefield Bengaluru','FT-W28-12','2026-07-06','2026-07-08',
     'firefighting','WhatsApp escalations on delayed spare parts',3.00,2,true,'ops_manager','exhausting','delegate_now','Third week in a row on founder plate'),
    ('AIIMS New Delhi Ansari Nagar','FT-W28-13','2026-07-06','2026-07-09',
     'ops','Vendor empanelment renewal documentation',2.50,2,true,'agency_partner','draining','eliminate','Agency partner can file this end to end')
  ) as q(ent, ref, ws, wd, ab, det, hrs, lev, del, dto, en, roi, nt);

  -- CAPA seed — attach to specific time entries by entry_ref
  insert into public.founder_time_capa_actions_r3197 (
    time_entry_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('FT-W27-02','firefighting_overload','reactive_customer_escalations','write_sop_and_handoff','2026-07-10',null,'in_progress','key_account_risk',25000.00,'Escalation SOP in draft; service head shadowing war rooms'),
    ('FT-W27-04','delegation_gap','no_ea_support','hire_executive_assistant','2026-07-25',null,'open','compliance_filing_risk',55000.00,'GeM filings must not depend on founder bandwidth'),
    ('FT-W27-07','low_leverage_drift','tooling_gap','automate_reporting_dashboard','2026-07-15','2026-07-12','closed','internal_only',40000.00,'Invoice recon now exported from finance dashboard'),
    ('FT-W27-08','hiring_bottleneck','founder_bottleneck_approvals','install_weekly_delegation_review','2026-07-18',null,'verification_pending','investor_update_flag',0,'Engineering lead owns screens; founder final round only'),
    ('FT-W28-12','firefighting_overload','weak_sops','promote_ops_lead','2026-07-08',null,'overdue','board_reportable',90000.00,'Spare-parts escalation owner still unassigned — overdue'),
    ('FT-W28-10','deep_work_starvation','overcommitted_calendar','block_deep_work_mornings','2026-07-09','2026-07-06','closed','none',0,'Recurring 6-9am deep-work block installed on calendar')
  ) as q(ref, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.founder_time_r3197 e
    on e.organization_id = v_org_id and e.entry_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) ROI verdict distribution
create or replace function public.founder_r3197_roi_verdict_rollup()
returns table(roi_verdict text, entries bigint, total_hours numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_time_r3197)
  select l.roi_verdict, count(*)::bigint,
         round(sum(l.hours_spent), 2),
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.founder_time_r3197 l
  group by l.roi_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3197_roi_verdict_rollup() from public, anon;
grant execute on function public.founder_r3197_roi_verdict_rollup() to authenticated;

-- 2) Entity / hospital account scorecard
create or replace function public.founder_r3197_entity_scorecard()
returns table(
  entity_name text,
  entries bigint,
  total_hours numeric,
  avg_leverage numeric,
  delegable_hours numeric,
  firefighting_hours numeric,
  keep_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    round(sum(l.hours_spent), 2),
    round(avg(l.leverage_score), 1),
    round(coalesce(sum(l.hours_spent) filter (where l.delegable), 0), 2),
    round(coalesce(sum(l.hours_spent) filter (where l.activity_bucket = 'firefighting'), 0), 2),
    round(100.0 * coalesce(sum(l.hours_spent) filter (where l.roi_verdict in ('high_roi_keep','strategic_keep')), 0) / nullif(sum(l.hours_spent), 0), 1)
  from public.founder_time_r3197 l
  group by l.entity_name
  order by sum(l.hours_spent) desc;
end;
$$;

revoke execute on function public.founder_r3197_entity_scorecard() from public, anon;
grant execute on function public.founder_r3197_entity_scorecard() to authenticated;

-- 3) Activity bucket × energy rating matrix
create or replace function public.founder_r3197_bucket_energy_matrix()
returns table(activity_bucket text, energy_rating text, entries bigint, total_hours numeric, avg_leverage numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.activity_bucket, l.energy_rating, count(*)::bigint,
    round(sum(l.hours_spent), 2),
    round(avg(l.leverage_score), 1)
  from public.founder_time_r3197 l
  group by l.activity_bucket, l.energy_rating
  order by sum(l.hours_spent) desc;
end;
$$;

revoke execute on function public.founder_r3197_bucket_energy_matrix() from public, anon;
grant execute on function public.founder_r3197_bucket_energy_matrix() to authenticated;

-- 4) Weekly founder-time trend
create or replace function public.founder_r3197_weekly_time_trend()
returns table(week_start date, total_hours numeric, deep_work_hours numeric, firefighting_hours numeric, delegable_hours numeric, avg_leverage numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.week_start,
    round(sum(l.hours_spent), 2),
    round(coalesce(sum(l.hours_spent) filter (where l.activity_bucket = 'deep_work'), 0), 2),
    round(coalesce(sum(l.hours_spent) filter (where l.activity_bucket = 'firefighting'), 0), 2),
    round(coalesce(sum(l.hours_spent) filter (where l.delegable), 0), 2),
    round(avg(l.leverage_score), 1)
  from public.founder_time_r3197 l
  group by l.week_start
  order by l.week_start desc;
end;
$$;

revoke execute on function public.founder_r3197_weekly_time_trend() from public, anon;
grant execute on function public.founder_r3197_weekly_time_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3197_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.founder_time_capa_actions_r3197 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3197_capa_status_board() from public, anon;
grant execute on function public.founder_r3197_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3197_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_time_capa_actions_r3197)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees), 0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.founder_time_capa_actions_r3197 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3197_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3197_root_cause_pareto() to authenticated;

-- 7) Regulatory / reporting impact digest
create or replace function public.founder_r3197_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees), 0)::numeric
  from public.founder_time_capa_actions_r3197 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3197_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3197_regulatory_impact_digest() to authenticated;

-- 8) Delegation priority queue (top individual rebalance candidates)
create or replace function public.founder_r3197_delegation_priority_queue()
returns table(
  entity_name text,
  entry_ref text,
  work_date date,
  activity_bucket text,
  hours_spent numeric,
  leverage_score int,
  delegated_to text,
  energy_rating text,
  roi_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.entry_ref, l.work_date, l.activity_bucket,
    l.hours_spent, l.leverage_score, l.delegated_to, l.energy_rating, l.roi_verdict, l.notes
  from public.founder_time_r3197 l
  where l.roi_verdict in ('delegate_now','automate','eliminate')
     or (l.delegable and l.leverage_score <= 3)
     or l.energy_rating = 'exhausting'
  order by l.hours_spent desc, l.work_date desc;
end;
$$;

revoke execute on function public.founder_r3197_delegation_priority_queue() from public, anon;
grant execute on function public.founder_r3197_delegation_priority_queue() to authenticated;
