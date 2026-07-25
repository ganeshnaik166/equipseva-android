-- Round 3425: Founder Capex-Approval Pipeline & Capital-Request Prioritization Board
-- Pre-approval funding-gate governance — request verdict × department × asset-category alignment × payback × priority score × budget gate × board gate × CAPA (review/rework/funding actions)

-- =============================================================================
-- TABLE 1: capex_approval_pipeline_r3425 — per capital-request in the funding pipeline
-- =============================================================================
create table if not exists public.capex_approval_pipeline_r3425 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_ref text not null,
  requesting_department text not null check (requesting_department in (
    'field_engineering','calibration_lab','it_infra','sales_ops','logistics','workshop','founder_office'
  )),
  asset_category text not null check (asset_category in (
    'test_equipment','it_hardware','vehicles','workshop_tools','demo_medical_equipment','facilities'
  )),
  request_title text not null,
  request_date date not null,
  capex_amount_rupees numeric(14,2) not null,
  expected_annual_return_rupees numeric(14,2),
  projected_payback_months int,
  strategic_alignment text not null check (strategic_alignment in (
    'core_strategic','efficiency','compliance_mandatory','growth_bet','nice_to_have'
  )),
  risk_level text not null check (risk_level in (
    'low','medium','high'
  )),
  approval_stage text not null check (approval_stage in (
    'submitted','under_review','committee','approved','on_hold','rejected'
  )),
  priority_score numeric(5,2),
  budget_available boolean not null,
  board_approval_needed boolean not null,
  request_verdict text not null check (request_verdict in (
    'fast_track_approve','approve','defer_next_quarter','rework_business_case','reject'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capex_approval_pipeline_r3425 enable row level security;

create index if not exists idx_capex_approval_pipeline_r3425_org on public.capex_approval_pipeline_r3425(organization_id);
create index if not exists idx_capex_approval_pipeline_r3425_date on public.capex_approval_pipeline_r3425(request_date);
create index if not exists idx_capex_approval_pipeline_r3425_verdict on public.capex_approval_pipeline_r3425(request_verdict);

-- =============================================================================
-- TABLE 2: capex_approval_pipeline_capa_actions_r3425 — review / rework / funding actions
-- =============================================================================
create table if not exists public.capex_approval_pipeline_capa_actions_r3425 (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.capex_approval_pipeline_r3425(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'weak_business_case','payback_too_long','budget_unavailable','duplicate_request','over_scope',
    'missing_vendor_quotes','strategic_misalignment','risk_too_high','compliance_gap','scope_creep'
  )),
  root_cause text not null check (root_cause in (
    'inflated_return_estimate','no_vendor_quotes','scope_creep','misaligned_with_roadmap',
    'insufficient_budget_cycle','pending_business_case','competing_priority','optimistic_payback',
    'unclear_ownership','vendor_lock_in'
  )),
  corrective_action text not null check (corrective_action in (
    'rework_business_case','request_vendor_quotes','reduce_scope','defer_next_quarter','split_into_phases',
    'escalate_to_board','reallocate_budget','approve_as_is','reject_request','request_pilot','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  funding_impact text not null check (funding_impact in (
    'board_gate','budget_reallocation','none','internal_only','quarter_deferral','strategic_priority'
  )),
  target_closure_date date,
  actual_closure_date date,
  capex_at_stake_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capex_approval_pipeline_capa_actions_r3425 enable row level security;

create index if not exists idx_capex_approval_pipeline_capa_r3425_req on public.capex_approval_pipeline_capa_actions_r3425(request_id);
create index if not exists idx_capex_approval_pipeline_capa_r3425_status on public.capex_approval_pipeline_capa_actions_r3425(capa_status);

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

  -- 14 capital-request rows
  insert into public.capex_approval_pipeline_r3425 (
    organization_id, request_ref, requesting_department, asset_category, request_title, request_date,
    capex_amount_rupees, expected_annual_return_rupees, projected_payback_months, strategic_alignment,
    risk_level, approval_stage, priority_score, budget_available, board_approval_needed, request_verdict, notes
  )
  select v_org_id, q.rref, q.dept, q.acat, q.title, q.rdate::date,
    q.amt, q.ret, q.payback::int, q.align,
    q.risk, q.stage, q.score, q.budget, q.boardneed, q.verdict, q.nt
  from (values
    ('CPX-2601','field_engineering','test_equipment','Fluke biomedical analyzer fleet refresh','2026-06-20',
     850000, 620000, 16, 'core_strategic','low','approved', 88.5, true, false, 'approve','Replaces aging analyzers, strong utilization across South zone'),
    ('CPX-2602','calibration_lab','test_equipment','NABL pressure calibration bench upgrade','2026-06-19',
     1250000, 900000, 18, 'compliance_mandatory','low','committee', 82.0, true, true, 'approve','Needed for NABL scope extension — board sign-off pending'),
    ('CPX-2603','it_infra','it_hardware','Field-engineer rugged tablet rollout (120 units)','2026-06-18',
     1800000, 1400000, 15, 'efficiency','medium','under_review', 74.0, true, true, 'rework_business_case','Return estimate optimistic — need adoption data before board'),
    ('CPX-2604','logistics','vehicles','Spare-parts delivery van (Tamil Nadu hub)','2026-06-17',
     1100000, 480000, 28, 'growth_bet','medium','on_hold', 55.5, false, false, 'defer_next_quarter','Payback long, budget cycle constrained — revisit Q3'),
    ('CPX-2605','workshop','workshop_tools','Ultrasonic cleaning + soldering rework station','2026-06-16',
     320000, 260000, 15, 'efficiency','low','approved', 79.0, true, false, 'approve','Improves refurb turnaround at Chennai workshop'),
    ('CPX-2606','sales_ops','demo_medical_equipment','Demo patient-monitor pool for hospital pitches','2026-06-15',
     950000, 1600000, 8, 'growth_bet','medium','committee', 84.5, true, true, 'fast_track_approve','High conversion lift on Apollo & Fortis demos — fast track'),
    ('CPX-2607','founder_office','facilities','Bengaluru service-center expansion fit-out','2026-06-14',
     2600000, 1200000, 30, 'growth_bet','high','submitted', 48.0, false, true, 'defer_next_quarter','Large spend, high risk — needs phased plan and board gate'),
    ('CPX-2608','field_engineering','test_equipment','Electrical safety analyzer (IEC 62353) batch','2026-06-13',
     540000, 500000, 13, 'compliance_mandatory','low','approved', 86.0, true, false, 'approve','Mandatory for electrical-safety AMC contracts'),
    ('CPX-2609','it_infra','it_hardware','Cloud FinOps + BI dashboard licensing (annual)','2026-06-12',
     420000, 300000, 20, 'nice_to_have','low','under_review', 44.0, true, false, 'rework_business_case','Value unclear vs existing tooling — tighten scope'),
    ('CPX-2610','calibration_lab','test_equipment','Temperature/humidity chamber for sensor cal','2026-06-11',
     1450000, 780000, 24, 'core_strategic','medium','committee', 71.0, true, true, 'approve','Unlocks new cal categories — board approval needed'),
    ('CPX-2611','logistics','vehicles','Two-wheeler fleet for metro field engineers','2026-06-10',
     680000, 900000, 10, 'efficiency','low','approved', 80.5, true, false, 'approve','Cuts inter-site travel time in Hyderabad & Chennai'),
    ('CPX-2612','sales_ops','it_hardware','CRM + field-service mobile add-on seats','2026-06-09',
     300000, 250000, 18, 'nice_to_have','medium','on_hold', 41.0, false, false, 'reject','Overlaps existing CRM — no incremental return justified'),
    ('CPX-2613','workshop','workshop_tools','Infusion-pump test rig & flow analyzer','2026-06-08',
     760000, 640000, 16, 'compliance_mandatory','low','committee', 77.5, true, true, 'approve','Required for infusion-device AMC quality gate'),
    ('CPX-2614','founder_office','demo_medical_equipment','Flagship demo dialysis machine for tender bids','2026-06-07',
     2100000, 1900000, 14, 'growth_bet','high','submitted', 62.0, false, true, 'rework_business_case','Big tender upside but high risk — strengthen ROI case')
  ) as q(rref, dept, acat, title, rdate, amt, ret, payback, align, risk, stage, score, budget, boardneed, verdict, nt);

  -- CAPA seed — attach to specific requests via request_ref
  insert into public.capex_approval_pipeline_capa_actions_r3425 (
    request_id, finding_category, root_cause, corrective_action,
    capa_status, funding_impact, target_closure_date, actual_closure_date,
    capex_at_stake_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CPX-2603','weak_business_case','inflated_return_estimate','rework_business_case','in_progress','board_gate','2026-07-05',null,1800000.00,'Adoption data requested before board review'),
    ('CPX-2604','payback_too_long','optimistic_payback','defer_next_quarter','open','quarter_deferral','2026-07-10',null,1100000.00,'Deferred to Q3 — reassess with route utilization'),
    ('CPX-2607','risk_too_high','competing_priority','split_into_phases','escalated','board_gate','2026-07-08',null,2600000.00,'Facilities expansion escalated to board — phase plan required'),
    ('CPX-2609','over_scope','scope_creep','reduce_scope','open','internal_only','2026-07-12',null,420000.00,'Trim licensing scope; overlaps current BI tooling'),
    ('CPX-2612','duplicate_request','misaligned_with_roadmap','reject_request','closed','none','2026-07-02','2026-06-28',300000.00,'Rejected — CRM add-on duplicates existing seats'),
    ('CPX-2614','risk_too_high','optimistic_payback','request_pilot','verification_pending','strategic_priority','2026-07-09',null,2100000.00,'Pilot demo unit at one tender before full spend'),
    ('CPX-2602','missing_vendor_quotes','no_vendor_quotes','request_vendor_quotes','overdue','budget_reallocation','2026-06-30',null,1250000.00,'NABL bench quotes overdue from vendor — reallocating budget')
  ) as q(rref, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.capex_approval_pipeline_r3425 e
    on e.organization_id = v_org_id and e.request_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Request verdict distribution
create or replace function public.founder_r3425_verdict_rollup()
returns table(request_verdict text, requests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capex_approval_pipeline_r3425)
  select l.request_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.capex_approval_pipeline_r3425 l
  group by l.request_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3425_verdict_rollup() from public, anon;
grant execute on function public.founder_r3425_verdict_rollup() to authenticated;

-- 2) Department-level pipeline scorecard
create or replace function public.founder_r3425_department_scorecard()
returns table(
  requesting_department text,
  total_requests bigint,
  approved bigint,
  deferred bigint,
  rejected bigint,
  total_capex_rupees numeric,
  board_needed bigint,
  avg_priority_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.requesting_department,
    count(*)::bigint,
    count(*) filter (where l.request_verdict in ('fast_track_approve','approve'))::bigint,
    count(*) filter (where l.request_verdict = 'defer_next_quarter')::bigint,
    count(*) filter (where l.request_verdict = 'reject')::bigint,
    coalesce(sum(l.capex_amount_rupees),0)::numeric,
    count(*) filter (where l.board_approval_needed = true)::bigint,
    round(avg(l.priority_score), 1)
  from public.capex_approval_pipeline_r3425 l
  group by l.requesting_department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3425_department_scorecard() from public, anon;
grant execute on function public.founder_r3425_department_scorecard() to authenticated;

-- 3) Asset-category × strategic-alignment matrix
create or replace function public.founder_r3425_category_alignment_matrix()
returns table(asset_category text, strategic_alignment text, requests bigint, approved bigint, total_capex_rupees numeric, avg_payback_months numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_category, l.strategic_alignment, count(*)::bigint,
    count(*) filter (where l.request_verdict in ('fast_track_approve','approve'))::bigint,
    coalesce(sum(l.capex_amount_rupees),0)::numeric,
    round(avg(l.projected_payback_months), 1)
  from public.capex_approval_pipeline_r3425 l
  group by l.asset_category, l.strategic_alignment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3425_category_alignment_matrix() from public, anon;
grant execute on function public.founder_r3425_category_alignment_matrix() to authenticated;

-- 4) Daily request-submission trend
create or replace function public.founder_r3425_daily_request_trend()
returns table(request_date date, requests bigint, approved bigint, deferred bigint, rejected bigint, total_capex_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.request_date,
    count(*)::bigint,
    count(*) filter (where l.request_verdict in ('fast_track_approve','approve'))::bigint,
    count(*) filter (where l.request_verdict = 'defer_next_quarter')::bigint,
    count(*) filter (where l.request_verdict = 'reject')::bigint,
    coalesce(sum(l.capex_amount_rupees),0)::numeric
  from public.capex_approval_pipeline_r3425 l
  group by l.request_date
  order by l.request_date desc;
end;
$$;

revoke execute on function public.founder_r3425_daily_request_trend() from public, anon;
grant execute on function public.founder_r3425_daily_request_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3425_capa_status_board()
returns table(capa_status text, actions bigint, avg_capex_at_stake_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.capex_at_stake_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.capex_approval_pipeline_capa_actions_r3425 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3425_capa_status_board() from public, anon;
grant execute on function public.founder_r3425_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3425_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_capex_at_stake_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capex_approval_pipeline_capa_actions_r3425)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.capex_at_stake_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.capex_approval_pipeline_capa_actions_r3425 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3425_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3425_root_cause_pareto() to authenticated;

-- 7) Funding impact digest
create or replace function public.founder_r3425_funding_impact_digest()
returns table(funding_impact text, actions bigint, open_actions bigint, total_capex_at_stake_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.funding_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.capex_at_stake_rupees),0)::numeric
  from public.capex_approval_pipeline_capa_actions_r3425 c
  group by c.funding_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3425_funding_impact_digest() from public, anon;
grant execute on function public.founder_r3425_funding_impact_digest() to authenticated;

-- 8) High-risk / high-scrutiny request queue
create or replace function public.founder_r3425_high_risk_queue()
returns table(
  request_ref text,
  requesting_department text,
  asset_category text,
  request_title text,
  request_date date,
  capex_amount_rupees numeric,
  strategic_alignment text,
  risk_level text,
  approval_stage text,
  request_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.request_ref, l.requesting_department, l.asset_category, l.request_title, l.request_date,
    l.capex_amount_rupees, l.strategic_alignment, l.risk_level, l.approval_stage, l.request_verdict, l.notes
  from public.capex_approval_pipeline_r3425 l
  where l.request_verdict in ('defer_next_quarter','rework_business_case','reject')
     or l.risk_level = 'high'
     or l.budget_available = false
     or l.projected_payback_months > 24
     or l.approval_stage in ('on_hold','submitted')
  order by l.priority_score asc, l.capex_amount_rupees desc;
end;
$$;

revoke execute on function public.founder_r3425_high_risk_queue() from public, anon;
grant execute on function public.founder_r3425_high_risk_queue() to authenticated;
