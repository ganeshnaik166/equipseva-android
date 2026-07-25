-- Round 3413: Founder Zero-Based-Budgeting Cost-Line Challenge Board
-- ZBB governance — cost line × owner department × period quarter × prior-year vs justified vs proposed spend × challenge reduction × spend classification × justification strength × owner signoff × savings locked × verdict × CAPA

-- =============================================================================
-- TABLE 1: zbb_cost_line_challenge_r3413 — per cost-line/owner ZBB challenge
-- =============================================================================
create table if not exists public.zbb_cost_line_challenge_r3413 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cost_line text not null check (cost_line in (
    'field_travel','logistics_freight','it_saas_subscriptions','marketing_spend',
    'office_admin','professional_fees','training','consumables','vehicle_running'
  )),
  owner_department text not null check (owner_department in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  period_quarter text not null,
  prior_year_spend_rupees numeric(14,2) not null,
  zbb_justified_spend_rupees numeric(14,2) not null,
  proposed_budget_rupees numeric(14,2) not null,
  challenge_reduction_rupees numeric(14,2) not null,
  reduction_pct numeric(5,2) not null,
  spend_classification text not null check (spend_classification in (
    'essential','important','discretionary','eliminate'
  )),
  business_justification_strength text not null check (business_justification_strength in (
    'strong','moderate','weak','none'
  )),
  owner_signoff boolean not null,
  savings_locked boolean not null,
  zbb_verdict text not null check (zbb_verdict in (
    'approved_lean','approved_with_challenge','rechallenge','cut_discretionary','eliminate_line'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.zbb_cost_line_challenge_r3413 enable row level security;

create index if not exists idx_zbb_cost_line_challenge_r3413_org on public.zbb_cost_line_challenge_r3413(organization_id);
create index if not exists idx_zbb_cost_line_challenge_r3413_line on public.zbb_cost_line_challenge_r3413(cost_line);
create index if not exists idx_zbb_cost_line_challenge_r3413_verdict on public.zbb_cost_line_challenge_r3413(zbb_verdict);

-- =============================================================================
-- TABLE 2: zbb_cost_line_challenge_capa_actions_r3413 — challenge/reduction/elimination actions
-- =============================================================================
create table if not exists public.zbb_cost_line_challenge_capa_actions_r3413 (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.zbb_cost_line_challenge_r3413(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'over_baseline_no_justification','discretionary_spend_flagged','duplicate_saas_subscription',
    'vendor_rate_above_market','low_utilization_asset','unapproved_recurring_spend',
    'travel_policy_breach','headcount_driven_overrun','one_time_cost_recurring','savings_target_missed'
  )),
  root_cause text not null check (root_cause in (
    'baseline_budgeting_habit','unchallenged_renewal','scope_creep','lack_of_owner_accountability',
    'vendor_lock_in','demand_overforecast','process_inefficiency','pending_investigation',
    'policy_gap','seasonal_spike'
  )),
  corrective_action text not null check (corrective_action in (
    'cut_discretionary_line','renegotiate_vendor_rate','consolidate_subscriptions','eliminate_line',
    'set_spend_cap','require_preapproval','shift_to_variable_cost','defer_to_next_quarter',
    'reallocate_budget','enforce_travel_policy','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  governance_impact text not null check (governance_impact in (
    'board_review','cfo_review','none','internal_only','policy_change','spend_freeze'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_savings_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.zbb_cost_line_challenge_capa_actions_r3413 enable row level security;

create index if not exists idx_zbb_cost_line_capa_r3413_challenge on public.zbb_cost_line_challenge_capa_actions_r3413(challenge_id);
create index if not exists idx_zbb_cost_line_capa_r3413_status on public.zbb_cost_line_challenge_capa_actions_r3413(capa_status);

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

  -- 14 ZBB cost-line challenge rows
  insert into public.zbb_cost_line_challenge_r3413 (
    organization_id, cost_line, owner_department, period_quarter,
    prior_year_spend_rupees, zbb_justified_spend_rupees, proposed_budget_rupees,
    challenge_reduction_rupees, reduction_pct, spend_classification,
    business_justification_strength, owner_signoff, savings_locked, zbb_verdict, notes
  )
  select v_org_id, q.cl, q.dept, q.pq,
    q.pys, q.zjs, q.pb,
    q.crr, q.rpct, q.sc,
    q.bjs, q.sign, q.lock, q.verdict, q.nt
  from (values
    ('field_travel','field_engineering','FY27-Q1',
     480000,360000,360000,120000,25.0,'important','strong',true,true,'approved_with_challenge','Field-visit travel re-based on route optimization; 25% cut locked'),
    ('logistics_freight','field_engineering','FY27-Q1',
     620000,520000,540000,80000,12.9,'essential','strong',true,true,'approved_lean','Spare-part freight essential to SLA; renegotiated courier slabs'),
    ('it_saas_subscriptions','office_ops','FY27-Q1',
     340000,190000,210000,130000,38.2,'important','moderate',true,false,'approved_with_challenge','Consolidated overlapping SaaS seats; 3 tools dropped, savings not yet locked'),
    ('marketing_spend','sales','FY27-Q1',
     750000,400000,450000,300000,40.0,'discretionary','weak',false,false,'rechallenge','Brand spend not justified vs pipeline; owner to re-defend from zero'),
    ('office_admin','office_ops','FY27-Q1',
     210000,150000,160000,50000,23.8,'important','moderate',true,true,'approved_with_challenge','Pantry, printing and courier rationalized'),
    ('professional_fees','finance','FY27-Q1',
     280000,240000,250000,30000,10.7,'essential','strong',true,true,'approved_lean','Statutory audit and ROC filings essential; retainer trimmed'),
    ('training','support','FY27-Q1',
     160000,120000,130000,30000,18.8,'important','moderate',true,true,'approved_with_challenge','OEM certification training kept; external workshops trimmed'),
    ('consumables','field_engineering','FY27-Q1',
     190000,170000,175000,15000,7.9,'essential','strong',true,true,'approved_lean','Calibration and PM consumables essential to service SLA'),
    ('vehicle_running','field_engineering','FY27-Q1',
     520000,380000,400000,120000,23.1,'important','moderate',true,false,'approved_with_challenge','Fuel and maintenance re-based on GPS mileage; savings pending lock'),
    ('marketing_spend','leadership','FY27-Q2',
     300000,60000,90000,210000,70.0,'discretionary','none',false,false,'cut_discretionary','Event sponsorship discretionary with no ROI evidence — cut'),
    ('it_saas_subscriptions','finance','FY27-Q2',
     120000,0,0,120000,100.0,'eliminate','none',true,true,'eliminate_line','Duplicate BI tool eliminated; migrated to existing analytics stack'),
    ('office_admin','leadership','FY27-Q2',
     95000,55000,60000,35000,36.8,'discretionary','weak',false,false,'rechallenge','Memberships and subscriptions flagged discretionary — re-challenge'),
    ('professional_fees','leadership','FY27-Q2',
     400000,250000,300000,100000,25.0,'important','moderate',true,false,'approved_with_challenge','Legal retainer re-scoped to as-needed engagement'),
    ('training','sales','FY27-Q2',
     140000,40000,50000,90000,64.3,'discretionary','weak',false,false,'cut_discretionary','Sales offsite training cut; move to in-house enablement')
  ) as q(cl, dept, pq, pys, zjs, pb, crr, rpct, sc, bjs, sign, lock, verdict, nt);

  -- CAPA seed — attach to specific challenge rows via (cost_line, owner_department, period_quarter)
  insert into public.zbb_cost_line_challenge_capa_actions_r3413 (
    challenge_id, finding_category, root_cause, corrective_action,
    capa_status, governance_impact, target_closure_date, actual_closure_date,
    estimated_savings_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.gi, q.tcd::date, q.acd::date,
    q.sav, q.nt
  from (values
    ('marketing_spend','sales','FY27-Q1','discretionary_spend_flagged','baseline_budgeting_habit','cut_discretionary_line','in_progress','cfo_review','2026-08-10',null,300000.00,'Brand spend re-challenged from zero; owner defending pipeline linkage'),
    ('marketing_spend','leadership','FY27-Q2','discretionary_spend_flagged','lack_of_owner_accountability','eliminate_line','verification_pending','board_review','2026-08-05',null,210000.00,'Event sponsorship cut pending board sign-off'),
    ('it_saas_subscriptions','finance','FY27-Q2','duplicate_saas_subscription','vendor_lock_in','consolidate_subscriptions','closed','policy_change','2026-07-20','2026-07-18',120000.00,'Duplicate BI tool decommissioned; migrated to existing stack'),
    ('office_admin','leadership','FY27-Q2','unapproved_recurring_spend','policy_gap','require_preapproval','open','cfo_review','2026-08-15',null,35000.00,'Memberships flagged; pre-approval workflow to be enforced'),
    ('training','sales','FY27-Q2','discretionary_spend_flagged','scope_creep','shift_to_variable_cost','in_progress','internal_only','2026-08-12',null,90000.00,'Sales offsite training moved in-house to enablement team'),
    ('it_saas_subscriptions','office_ops','FY27-Q1','duplicate_saas_subscription','unchallenged_renewal','consolidate_subscriptions','overdue','policy_change','2026-07-15',null,130000.00,'SaaS consolidation past target — 3 seats still active'),
    ('vehicle_running','field_engineering','FY27-Q1','vendor_rate_above_market','vendor_lock_in','renegotiate_vendor_rate','escalated','cfo_review','2026-07-25',null,120000.00,'Fleet fuel-card rates above market — escalated to renegotiate')
  ) as q(cl, dept, pq, fc, rc, ca, cst, gi, tcd, acd, sav, nt)
  join public.zbb_cost_line_challenge_r3413 e
    on e.organization_id = v_org_id and e.cost_line = q.cl and e.owner_department = q.dept and e.period_quarter = q.pq;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) ZBB verdict distribution
create or replace function public.founder_r3413_zbb_verdict_rollup()
returns table(zbb_verdict text, cost_lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.zbb_cost_line_challenge_r3413)
  select l.zbb_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.zbb_cost_line_challenge_r3413 l
  group by l.zbb_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3413_zbb_verdict_rollup() from public, anon;
grant execute on function public.founder_r3413_zbb_verdict_rollup() to authenticated;

-- 2) Department-level ZBB scorecard
create or replace function public.founder_r3413_department_scorecard()
returns table(
  owner_department text,
  total_lines bigint,
  approved_lean bigint,
  challenged bigint,
  cut_eliminated bigint,
  discretionary_lines bigint,
  weak_justification bigint,
  prior_year_total_rupees numeric,
  proposed_total_rupees numeric,
  reduction_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owner_department,
    count(*)::bigint,
    count(*) filter (where l.zbb_verdict = 'approved_lean')::bigint,
    count(*) filter (where l.zbb_verdict in ('approved_with_challenge','rechallenge'))::bigint,
    count(*) filter (where l.zbb_verdict in ('cut_discretionary','eliminate_line'))::bigint,
    count(*) filter (where l.spend_classification in ('discretionary','eliminate'))::bigint,
    count(*) filter (where l.business_justification_strength in ('weak','none'))::bigint,
    coalesce(sum(l.prior_year_spend_rupees),0)::numeric,
    coalesce(sum(l.proposed_budget_rupees),0)::numeric,
    round(100.0 * (coalesce(sum(l.prior_year_spend_rupees),0) - coalesce(sum(l.proposed_budget_rupees),0))
      / nullif(sum(l.prior_year_spend_rupees),0), 1)
  from public.zbb_cost_line_challenge_r3413 l
  group by l.owner_department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3413_department_scorecard() from public, anon;
grant execute on function public.founder_r3413_department_scorecard() to authenticated;

-- 3) Cost-line × department matrix
create or replace function public.founder_r3413_cost_line_department_matrix()
returns table(
  cost_line text,
  owner_department text,
  lines bigint,
  prior_year_total_rupees numeric,
  proposed_total_rupees numeric,
  avg_reduction_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_line, l.owner_department, count(*)::bigint,
    coalesce(sum(l.prior_year_spend_rupees),0)::numeric,
    coalesce(sum(l.proposed_budget_rupees),0)::numeric,
    round(avg(l.reduction_pct), 1)
  from public.zbb_cost_line_challenge_r3413 l
  group by l.cost_line, l.owner_department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3413_cost_line_department_matrix() from public, anon;
grant execute on function public.founder_r3413_cost_line_department_matrix() to authenticated;

-- 4) Period-quarter trend
create or replace function public.founder_r3413_period_trend()
returns table(
  period_quarter text,
  cost_lines bigint,
  prior_year_total_rupees numeric,
  proposed_total_rupees numeric,
  reduction_total_rupees numeric,
  avg_reduction_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_quarter,
    count(*)::bigint,
    coalesce(sum(l.prior_year_spend_rupees),0)::numeric,
    coalesce(sum(l.proposed_budget_rupees),0)::numeric,
    coalesce(sum(l.challenge_reduction_rupees),0)::numeric,
    round(avg(l.reduction_pct), 1)
  from public.zbb_cost_line_challenge_r3413 l
  group by l.period_quarter
  order by l.period_quarter desc;
end;
$$;

revoke execute on function public.founder_r3413_period_trend() from public, anon;
grant execute on function public.founder_r3413_period_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3413_capa_status_board()
returns table(capa_status text, findings bigint, avg_savings_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_savings_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.zbb_cost_line_challenge_capa_actions_r3413 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3413_capa_status_board() from public, anon;
grant execute on function public.founder_r3413_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3413_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.zbb_cost_line_challenge_capa_actions_r3413)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.zbb_cost_line_challenge_capa_actions_r3413 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3413_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3413_root_cause_pareto() to authenticated;

-- 7) Governance impact digest
create or replace function public.founder_r3413_governance_impact_digest()
returns table(governance_impact text, findings bigint, open_findings bigint, total_savings_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.governance_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric
  from public.zbb_cost_line_challenge_capa_actions_r3413 c
  group by c.governance_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3413_governance_impact_digest() from public, anon;
grant execute on function public.founder_r3413_governance_impact_digest() to authenticated;

-- 8) High-risk challenge queue (top individual concerns)
create or replace function public.founder_r3413_high_risk_queue()
returns table(
  owner_department text,
  cost_line text,
  period_quarter text,
  prior_year_spend_rupees numeric,
  proposed_budget_rupees numeric,
  reduction_pct numeric,
  spend_classification text,
  business_justification_strength text,
  zbb_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.owner_department, l.cost_line, l.period_quarter,
    l.prior_year_spend_rupees, l.proposed_budget_rupees, l.reduction_pct,
    l.spend_classification, l.business_justification_strength, l.zbb_verdict, l.notes
  from public.zbb_cost_line_challenge_r3413 l
  where l.zbb_verdict in ('rechallenge','cut_discretionary','eliminate_line')
     or l.spend_classification in ('discretionary','eliminate')
     or l.business_justification_strength in ('weak','none')
     or l.owner_signoff = false
     or l.savings_locked = false
  order by l.reduction_pct desc, l.owner_department;
end;
$$;

revoke execute on function public.founder_r3413_high_risk_queue() from public, anon;
grant execute on function public.founder_r3413_high_risk_queue() to authenticated;
