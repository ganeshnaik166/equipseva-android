-- Round 3297: Founder Annual Appraisal, Merit-Increment & Compensation-Review Board
-- HR governance — verdict × department × band/rating × increment × market-benchmark × flight-risk × variable-payout × CAPA

-- =============================================================================
-- TABLE 1: appraisal_review_r3297 — per-employee annual appraisal & comp review
-- =============================================================================
create table if not exists public.appraisal_review_r3297 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  employee_name text not null,
  employee_code text not null,
  base_location text not null,
  department text not null check (department in (
    'field_engineering','office_ops','sales','finance','leadership','support'
  )),
  band text not null check (band in (
    'l1_junior','l2_mid','l3_senior','l4_lead','l5_leadership'
  )),
  review_cycle text not null,
  review_date date not null,
  performance_rating text not null check (performance_rating in (
    'outstanding','exceeds','meets','partially_meets','below'
  )),
  current_ctc_rupees numeric(12,2) not null,
  proposed_increment_pct numeric(5,2) not null,
  revised_ctc_rupees numeric(12,2) not null,
  promotion_recommended boolean not null default false,
  market_benchmark_position text not null check (market_benchmark_position in (
    'above','at_par','below'
  )),
  flight_risk text not null check (flight_risk in (
    'low','medium','high'
  )),
  variable_payout_pct numeric(5,2) not null,
  budget_within_guardrail boolean not null default true,
  review_verdict text not null check (review_verdict in (
    'approved','approved_with_adjustment','hold_for_calibration','promotion_track','retention_action'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.appraisal_review_r3297 enable row level security;

create index if not exists idx_appraisal_review_r3297_org on public.appraisal_review_r3297(org_id);
create index if not exists idx_appraisal_review_r3297_date on public.appraisal_review_r3297(review_date);
create index if not exists idx_appraisal_review_r3297_verdict on public.appraisal_review_r3297(review_verdict);

-- =============================================================================
-- TABLE 2: appraisal_review_capa_actions_r3297 — retention/calibration/promotion actions
-- =============================================================================
create table if not exists public.appraisal_review_capa_actions_r3297 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  review_id uuid not null references public.appraisal_review_r3297(id) on delete cascade,
  raised_at timestamptz not null default now(),
  action_category text not null check (action_category in (
    'retention_bonus','role_change_promotion','calibration_review','compensation_correction',
    'performance_improvement_plan','market_adjustment','equity_grant','manager_coaching'
  )),
  root_cause text not null check (root_cause in (
    'below_market_pay','high_flight_risk','rating_calibration_gap','budget_guardrail_breach',
    'promotion_readiness','underperformance','pay_compression','pending_review'
  )),
  action_owner text not null check (action_owner in (
    'hr_business_partner','department_head','founder','finance_controller','reporting_manager'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  compensation_impact text not null check (compensation_impact in (
    'ctc_revision','one_time_bonus','equity_only','no_cost','deferred','off_cycle_correction'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.appraisal_review_capa_actions_r3297 enable row level security;

create index if not exists idx_appraisal_capa_r3297_org on public.appraisal_review_capa_actions_r3297(org_id);
create index if not exists idx_appraisal_capa_r3297_review on public.appraisal_review_capa_actions_r3297(review_id);
create index if not exists idx_appraisal_capa_r3297_status on public.appraisal_review_capa_actions_r3297(capa_status);

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

  -- 14 appraisal review rows
  insert into public.appraisal_review_r3297 (
    org_id, employee_name, employee_code, base_location, department, band,
    review_cycle, review_date, performance_rating,
    current_ctc_rupees, proposed_increment_pct, revised_ctc_rupees,
    promotion_recommended, market_benchmark_position, flight_risk,
    variable_payout_pct, budget_within_guardrail, review_verdict, notes
  )
  select v_org_id, q.name, q.code, q.loc, q.dept, q.band,
    q.cycle, q.rdate::date, q.rating,
    q.cctc, q.incr, q.rctc,
    q.promo, q.mbp, q.frisk,
    q.vpay, q.guard, q.verdict, q.nt
  from (values
    ('Rajesh Kumar','EQS-FE-001','Apollo Chennai','field_engineering','l3_senior',
     'fy2026_annual','2026-06-10','exceeds',
     950000.00,12.00,1064000.00,
     false,'at_par','low',
     8.00,true,'approved','Strong biomed uptime metrics — standard merit increment'),
    ('Priya Sharma','EQS-SAL-002','Fortis Gurgaon','sales','l3_senior',
     'fy2026_annual','2026-06-10','outstanding',
     1100000.00,18.00,1298000.00,
     true,'at_par','medium',
     15.00,true,'promotion_track','Exceeded AMC renewal quota — recommended for L4'),
    ('Arjun Nair','EQS-FE-003','Manipal Bengaluru','field_engineering','l2_mid',
     'fy2026_annual','2026-06-11','meets',
     720000.00,9.00,784800.00,
     false,'below','high',
     6.00,true,'retention_action','Below-market pay + competing offer — retention bonus proposed'),
    ('Sneha Reddy','EQS-OPS-004','KIMS Hyderabad','office_ops','l2_mid',
     'fy2026_annual','2026-06-11','exceeds',
     640000.00,11.00,710400.00,
     false,'at_par','low',
     7.00,true,'approved','Dispatch SLA consistently green'),
    ('Vikram Singh','EQS-FE-005','AIIMS Delhi','field_engineering','l4_lead',
     'fy2026_annual','2026-06-12','outstanding',
     1550000.00,16.00,1798000.00,
     true,'above','medium',
     18.00,false,'approved_with_adjustment','Increment trimmed to stay within band guardrail'),
    ('Ananya Iyer','EQS-FIN-006','Chennai HO','finance','l3_senior',
     'fy2026_annual','2026-06-12','meets',
     980000.00,8.00,1058400.00,
     false,'at_par','low',
     9.00,true,'approved','Clean audit close — standard increment'),
    ('Karthik Menon','EQS-FE-007','CMC Vellore','field_engineering','l2_mid',
     'fy2026_annual','2026-06-13','partially_meets',
     680000.00,4.00,707200.00,
     false,'at_par','medium',
     4.00,true,'hold_for_calibration','Rating disputed by dept head — calibration pending'),
    ('Meera Joshi','EQS-SUP-008','Bengaluru HO','support','l1_junior',
     'fy2026_annual','2026-06-13','meets',
     420000.00,10.00,462000.00,
     false,'below','medium',
     5.00,true,'approved','Junior support — market-correction increment'),
    ('Sanjay Gupta','EQS-SAL-009','Fortis Mulund Mumbai','sales','l4_lead',
     'fy2026_annual','2026-06-14','exceeds',
     1650000.00,14.00,1881000.00,
     false,'above','low',
     20.00,true,'approved','Top region revenue — variable-heavy package'),
    ('Divya Pillai','EQS-OPS-010','Apollo Chennai','office_ops','l3_senior',
     'fy2026_annual','2026-06-15','below',
     890000.00,0.00,890000.00,
     false,'at_par','low',
     0.00,true,'hold_for_calibration','Below expectations — PIP recommended, no increment this cycle'),
    ('Rohan Desai','EQS-FE-011','Manipal Bengaluru','field_engineering','l3_senior',
     'fy2026_annual','2026-06-15','exceeds',
     940000.00,13.00,1062200.00,
     true,'below','high',
     9.00,true,'promotion_track','High performer, below market, retention risk — promote to L4'),
    ('Neha Verma','EQS-FIN-012','Gurgaon HO','finance','l2_mid',
     'fy2026_annual','2026-06-16','meets',
     620000.00,9.00,675800.00,
     false,'at_par','low',
     6.00,true,'approved','Standard cycle — no flags'),
    ('Aditya Rao','EQS-LEAD-013','Chennai HO','leadership','l5_leadership',
     'fy2026_annual','2026-06-16','outstanding',
     3200000.00,15.00,3680000.00,
     false,'above','low',
     30.00,false,'approved_with_adjustment','Leadership comp reviewed by board — variable rebalanced, guardrail breach noted'),
    ('Pooja Bhat','EQS-SUP-014','KIMS Hyderabad','support','l2_mid',
     'fy2026_annual','2026-06-17','exceeds',
     560000.00,12.00,627200.00,
     false,'below','medium',
     6.00,true,'approved','Support lead — market correction applied')
  ) as q(name, code, loc, dept, band, cycle, rdate, rating, cctc, incr, rctc, promo, mbp, frisk, vpay, guard, verdict, nt);

  -- CAPA seed — attach to specific reviews via employee_code
  insert into public.appraisal_review_capa_actions_r3297 (
    org_id, review_id, action_category, root_cause, action_owner,
    capa_status, compensation_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.acat, q.rc, q.owner,
    q.cst, q.cimp, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EQS-FE-003','retention_bonus','below_market_pay','hr_business_partner','in_progress','one_time_bonus','2026-06-30',null,150000.00,'Retention bonus to counter competing offer'),
    ('EQS-FE-011','role_change_promotion','promotion_readiness','department_head','open','ctc_revision','2026-07-05',null,122000.00,'Promotion to L4 lead — off-cycle correction pending approval'),
    ('EQS-FE-007','calibration_review','rating_calibration_gap','department_head','verification_pending','no_cost','2026-06-28',null,0.00,'Second-round calibration with dept head'),
    ('EQS-OPS-010','performance_improvement_plan','underperformance','reporting_manager','open','no_cost','2026-07-15',null,0.00,'90-day PIP with monthly checkpoints'),
    ('EQS-SAL-002','role_change_promotion','promotion_readiness','founder','closed','ctc_revision','2026-06-20','2026-06-19',198000.00,'Promoted to L4 — approved and effective'),
    ('EQS-LEAD-013','compensation_correction','budget_guardrail_breach','finance_controller','escalated','deferred','2026-06-25',null,480000.00,'Leadership comp exceeds guardrail — board sign-off required'),
    ('EQS-FE-005','market_adjustment','budget_guardrail_breach','finance_controller','overdue','off_cycle_correction','2026-06-18',null,60000.00,'Band-cap correction past target closure date')
  ) as q(code, acat, rc, owner, cst, cimp, tcd, acd, cost, nt)
  join public.appraisal_review_r3297 e
    on e.org_id = v_org_id and e.employee_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Review verdict distribution
create or replace function public.founder_r3297_verdict_rollup()
returns table(review_verdict text, employees bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.appraisal_review_r3297)
  select l.review_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.appraisal_review_r3297 l
  group by l.review_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3297_verdict_rollup() from public, anon;
grant execute on function public.founder_r3297_verdict_rollup() to authenticated;

-- 2) Department-level appraisal scorecard
create or replace function public.founder_r3297_department_scorecard()
returns table(
  department text,
  total_reviews bigint,
  promotions bigint,
  retention_actions bigint,
  high_flight_risk bigint,
  below_market bigint,
  guardrail_breaches bigint,
  avg_increment_pct numeric
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
    count(*) filter (where l.promotion_recommended)::bigint,
    count(*) filter (where l.review_verdict = 'retention_action')::bigint,
    count(*) filter (where l.flight_risk = 'high')::bigint,
    count(*) filter (where l.market_benchmark_position = 'below')::bigint,
    count(*) filter (where l.budget_within_guardrail = false)::bigint,
    round(avg(l.proposed_increment_pct), 2)
  from public.appraisal_review_r3297 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3297_department_scorecard() from public, anon;
grant execute on function public.founder_r3297_department_scorecard() to authenticated;

-- 3) Band × performance-rating matrix
create or replace function public.founder_r3297_band_rating_matrix()
returns table(band text, performance_rating text, employees bigint, promotions bigint, avg_increment_pct numeric, avg_variable_payout_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.band, l.performance_rating, count(*)::bigint,
    count(*) filter (where l.promotion_recommended)::bigint,
    round(avg(l.proposed_increment_pct), 2),
    round(avg(l.variable_payout_pct), 2)
  from public.appraisal_review_r3297 l
  group by l.band, l.performance_rating
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3297_band_rating_matrix() from public, anon;
grant execute on function public.founder_r3297_band_rating_matrix() to authenticated;

-- 4) Daily review-date trend
create or replace function public.founder_r3297_review_date_trend()
returns table(review_date date, reviews bigint, promotions bigint, retention_actions bigint, high_flight_risk bigint, guardrail_breaches bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_date,
    count(*)::bigint,
    count(*) filter (where l.promotion_recommended)::bigint,
    count(*) filter (where l.review_verdict = 'retention_action')::bigint,
    count(*) filter (where l.flight_risk = 'high')::bigint,
    count(*) filter (where l.budget_within_guardrail = false)::bigint
  from public.appraisal_review_r3297 l
  group by l.review_date
  order by l.review_date desc;
end;
$$;

revoke execute on function public.founder_r3297_review_date_trend() from public, anon;
grant execute on function public.founder_r3297_review_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3297_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, escalated_flag bigint)
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
  from public.appraisal_review_capa_actions_r3297 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3297_capa_status_board() from public, anon;
grant execute on function public.founder_r3297_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3297_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.appraisal_review_capa_actions_r3297)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.appraisal_review_capa_actions_r3297 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3297_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3297_root_cause_pareto() to authenticated;

-- 7) Compensation-impact cost digest
create or replace function public.founder_r3297_compensation_cost_digest()
returns table(compensation_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.compensation_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.appraisal_review_capa_actions_r3297 c
  group by c.compensation_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3297_compensation_cost_digest() from public, anon;
grant execute on function public.founder_r3297_compensation_cost_digest() to authenticated;

-- 8) High-risk appraisal queue (top individual concerns)
create or replace function public.founder_r3297_high_risk_queue()
returns table(
  employee_name text,
  department text,
  band text,
  review_date date,
  performance_rating text,
  review_verdict text,
  flight_risk text,
  market_benchmark_position text,
  proposed_increment_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_name, l.department, l.band, l.review_date,
    l.performance_rating, l.review_verdict, l.flight_risk,
    l.market_benchmark_position, l.proposed_increment_pct, l.notes
  from public.appraisal_review_r3297 l
  where l.flight_risk = 'high'
     or l.review_verdict in ('retention_action','hold_for_calibration')
     or l.market_benchmark_position = 'below'
     or l.budget_within_guardrail = false
     or l.performance_rating in ('partially_meets','below')
  order by l.review_date desc, l.employee_name;
end;
$$;

revoke execute on function public.founder_r3297_high_risk_queue() from public, anon;
grant execute on function public.founder_r3297_high_risk_queue() to authenticated;
