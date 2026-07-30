-- Round 3611: Founder Borrowing-Cost / Cost-of-Debt Analysis Board
-- Cost-of-debt analytics — facility × business unit × effective rate vs benchmark × spread × hedged × fixed/floating × cost status × trend × CAPA

-- =============================================================================
-- TABLE 1: borrowing_cost_r3611 — per-facility monthly cost-of-debt fact rows
-- =============================================================================
create table if not exists public.borrowing_cost_r3611 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  facility_name text not null,
  business_unit text not null,
  period_month date not null,
  outstanding_rupees numeric(16,2),
  interest_expense_rupees numeric(16,2),
  effective_rate_pct numeric(6,2),
  benchmark_rate_pct numeric(6,2),
  spread_bps int,
  weighted_avg_cost_pct numeric(6,2),
  hedged_pct numeric(5,2),
  fixed_vs_floating_pct numeric(5,2),
  cost_status text not null check (cost_status in (
    'optimized','on_market','above_market','expensive','distressed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.borrowing_cost_r3611 enable row level security;

create index if not exists idx_borrowing_cost_r3611_org on public.borrowing_cost_r3611(organization_id);
create index if not exists idx_borrowing_cost_r3611_month on public.borrowing_cost_r3611(period_month);
create index if not exists idx_borrowing_cost_r3611_status on public.borrowing_cost_r3611(cost_status);

-- =============================================================================
-- TABLE 2: borrowing_cost_capa_actions_r3611 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.borrowing_cost_capa_actions_r3611 (
  id uuid primary key default gen_random_uuid(),
  cost_log_id uuid not null references public.borrowing_cost_r3611(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'above_market_rate','high_spread','unhedged_exposure','floating_rate_risk',
    'covenant_pressure','refinance_opportunity','rate_reset_due','concentration_risk'
  )),
  root_cause text not null check (root_cause in (
    'benchmark_repricing','poor_credit_rating','lender_margin_high','no_hedge_in_place',
    'excess_floating_mix','delayed_refinance','covenant_breach_risk','market_rate_spike',
    'pending_investigation','collateral_shortfall'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_spread','refinance_facility','add_interest_rate_hedge','convert_to_fixed',
    'prepay_high_cost_debt','improve_credit_metrics','consolidate_facilities','extend_tenor',
    'none_required','escalate_to_board'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  annual_savings_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.borrowing_cost_capa_actions_r3611 enable row level security;

create index if not exists idx_borrowing_cost_capa_r3611_log on public.borrowing_cost_capa_actions_r3611(cost_log_id);
create index if not exists idx_borrowing_cost_capa_r3611_status on public.borrowing_cost_capa_actions_r3611(capa_status);

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

  -- 15 facility cost-of-debt rows across 3 months
  insert into public.borrowing_cost_r3611 (
    organization_id, facility_name, business_unit, period_month,
    outstanding_rupees, interest_expense_rupees, effective_rate_pct, benchmark_rate_pct,
    spread_bps, weighted_avg_cost_pct, hedged_pct, fixed_vs_floating_pct,
    cost_status, trend_dir, notes
  )
  select v_org_id, q.fac, q.bu, q.pm::date,
    q.outr, q.intr, q.eff, q.bench,
    q.spr, q.wac, q.hedg, q.fixp,
    q.cstat, q.trend, q.nt
  from (values
    ('HDFC Term Loan TL-01','amc_services','2026-07-01',
     250000000,1718750,8.25,7.50,75,8.25,60,70,'optimized','improving','AMC term loan spread tightened after rating upgrade'),
    ('SBI Cash Credit CC-11','spare_parts','2026-07-01',
     90000000,712500,9.50,7.50,200,9.50,0,20,'on_market','stable','Spare-parts CC line priced at market, mostly floating'),
    ('ICICI WCDL-21','projects','2026-07-01',
     140000000,1225000,10.50,7.50,300,10.50,25,30,'above_market','worsening','Projects WCDL running 300 bps over benchmark'),
    ('Axis Term Loan TL-31','diagnostics','2026-07-01',
     60000000,625000,12.50,7.50,500,12.50,0,40,'expensive','worsening','Diagnostics expansion loan carries elevated spread'),
    ('Kotak Equipment Finance EF-41','rentals','2026-07-01',
     45000000,618750,16.50,7.50,900,16.50,0,100,'distressed','worsening','Rental fleet finance at distressed pricing, refinance urgent'),
    ('Yes Bank OD-51','working_capital','2026-06-01',
     30000000,275000,11.00,7.50,350,11.00,0,10,'above_market','stable','OD facility floating, above market on weak collateral cover'),
    ('HDFC Working Capital WC-61','amc_services','2026-06-01',
     110000000,802083,8.75,7.50,125,8.75,50,65,'optimized','improving','AMC WC line hedged, cost trending down'),
    ('Bajaj Finserv ECL-71','projects','2026-06-01',
     55000000,641666,14.00,7.50,650,14.00,0,55,'expensive','stable','Project ECL priced high pending milestone completion'),
    ('IDFC First Term Loan TL-81','diagnostics','2026-06-01',
     80000000,700000,10.50,7.50,300,10.50,30,45,'above_market','worsening','Diagnostics loan reset upward at last review'),
    ('SIDBI Machinery Loan ML-91','spare_parts','2026-06-01',
     35000000,262500,9.00,7.50,150,9.00,40,80,'on_market','stable','SIDBI machinery loan concessional, mostly fixed'),
    ('Tata Capital Lease LS-12','rentals','2026-05-01',
     42000000,490000,14.00,7.50,650,14.00,0,100,'expensive','stable','Rental lease fixed but expensive vs current market'),
    ('Federal Bank CC-22','amc_services','2026-05-01',
     70000000,554166,9.50,7.50,200,9.50,20,25,'on_market','improving','AMC CC line renegotiation lowered spread modestly'),
    ('IndusInd WCDL-32','projects','2026-05-01',
     95000000,950000,12.00,7.50,450,12.00,10,35,'expensive','worsening','Projects WCDL unhedged floating exposure rising'),
    ('Canara Term Loan TL-42','diagnostics','2026-05-01',
     65000000,446875,8.25,7.50,75,8.25,55,70,'optimized','improving','Diagnostics term loan well-priced and hedged'),
    ('Union Bank OD-52','working_capital','2026-05-01',
     25000000,291666,14.00,7.50,650,14.00,0,5,'distressed','worsening','Small OD at distressed rate, prepay candidate')
  ) as q(fac, bu, pm, outr, intr, eff, bench, spr, wac, hedg, fixp, cstat, trend, nt);

  -- CAPA seed — attach to specific facilities via facility_name
  insert into public.borrowing_cost_capa_actions_r3611 (
    cost_log_id, finding_category, root_cause, corrective_action,
    capa_status, annual_savings_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.sav, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Axis Term Loan TL-31','above_market_rate','lender_margin_high','renegotiate_spread','in_progress',1200000,'Treasury - R. Menon','2026-08-15',null,'Renegotiating spread with Axis relationship manager'),
    ('Kotak Equipment Finance EF-41','high_spread','poor_credit_rating','refinance_facility','escalated',3500000,'CFO Office','2026-08-30',null,'Distressed rental finance flagged for urgent refinance'),
    ('ICICI WCDL-21','floating_rate_risk','excess_floating_mix','convert_to_fixed','open',800000,'Treasury - S. Iyer','2026-09-10',null,'Convert portion of projects WCDL to fixed rate'),
    ('Bajaj Finserv ECL-71','refinance_opportunity','market_rate_spike','refinance_facility','verification_pending',1500000,'Treasury - R. Menon','2026-08-05',null,'Refinance quote received, awaiting board note verification'),
    ('Union Bank OD-52','above_market_rate','collateral_shortfall','prepay_high_cost_debt','closed',650000,'Finance Controller','2026-07-20','2026-07-18','Distressed OD prepaid from internal accruals'),
    ('IndusInd WCDL-32','unhedged_exposure','no_hedge_in_place','add_interest_rate_hedge','overdue',900000,'Treasury - S. Iyer','2026-07-15',null,'Hedge not placed past target date, rate rising'),
    ('IDFC First Term Loan TL-81','rate_reset_due','benchmark_repricing','renegotiate_spread','open',560000,'Treasury - R. Menon','2026-09-01',null,'Reset review due; seek spread reduction'),
    ('Yes Bank OD-51','high_spread','lender_margin_high','consolidate_facilities','in_progress',420000,'CFO Office','2026-08-20',null,'Consolidate OD into cheaper AMC WC line')
  ) as q(fac, fc, rc, ca, cst, sav, own, tcd, acd, nt)
  join public.borrowing_cost_r3611 e
    on e.organization_id = v_org_id and e.facility_name = q.fac;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Cost-status distribution
create or replace function public.founder_r3611_cost_status_rollup()
returns table(cost_status text, facilities bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.borrowing_cost_r3611)
  select l.cost_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.borrowing_cost_r3611 l
  group by l.cost_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3611_cost_status_rollup() from public, anon;
grant execute on function public.founder_r3611_cost_status_rollup() to authenticated;

-- 2) Business-unit cost-of-debt scorecard
create or replace function public.founder_r3611_business_unit_scorecard()
returns table(
  business_unit text,
  facilities bigint,
  total_outstanding_rupees numeric,
  total_interest_rupees numeric,
  avg_effective_rate_pct numeric,
  avg_spread_bps numeric,
  avg_hedged_pct numeric,
  expensive bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit,
    count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.interest_expense_rupees),0)::numeric,
    round(avg(l.effective_rate_pct), 2),
    round(avg(l.spread_bps), 0),
    round(avg(l.hedged_pct), 1),
    count(*) filter (where l.cost_status in ('expensive','distressed'))::bigint
  from public.borrowing_cost_r3611 l
  group by l.business_unit
  order by coalesce(sum(l.outstanding_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3611_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3611_business_unit_scorecard() to authenticated;

-- 3) Business-unit × cost-status matrix
create or replace function public.founder_r3611_business_unit_status_matrix()
returns table(
  business_unit text,
  cost_status text,
  facilities bigint,
  total_outstanding_rupees numeric,
  avg_effective_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.cost_status, count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    round(avg(l.effective_rate_pct), 2)
  from public.borrowing_cost_r3611 l
  group by l.business_unit, l.cost_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3611_business_unit_status_matrix() from public, anon;
grant execute on function public.founder_r3611_business_unit_status_matrix() to authenticated;

-- 4) Monthly cost-of-debt trend
create or replace function public.founder_r3611_monthly_cost_trend()
returns table(
  period_month date,
  facilities bigint,
  total_outstanding_rupees numeric,
  total_interest_rupees numeric,
  weighted_avg_cost_pct numeric,
  avg_spread_bps numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.interest_expense_rupees),0)::numeric,
    round(sum(l.effective_rate_pct * l.outstanding_rupees) / nullif(sum(l.outstanding_rupees),0), 2),
    round(avg(l.spread_bps), 0)
  from public.borrowing_cost_r3611 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3611_monthly_cost_trend() from public, anon;
grant execute on function public.founder_r3611_monthly_cost_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3611_capa_status_board()
returns table(capa_status text, actions bigint, avg_savings_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.annual_savings_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.borrowing_cost_capa_actions_r3611 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3611_capa_status_board() from public, anon;
grant execute on function public.founder_r3611_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3611_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.borrowing_cost_capa_actions_r3611)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.annual_savings_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.borrowing_cost_capa_actions_r3611 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3611_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3611_root_cause_pareto() to authenticated;

-- 7) Interest-cost digest (by cost-trend direction)
create or replace function public.founder_r3611_interest_cost_digest()
returns table(
  trend_dir text,
  facilities bigint,
  total_outstanding_rupees numeric,
  total_interest_rupees numeric,
  avg_effective_rate_pct numeric,
  avg_spread_bps numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir,
    count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.interest_expense_rupees),0)::numeric,
    round(avg(l.effective_rate_pct), 2),
    round(avg(l.spread_bps), 0)
  from public.borrowing_cost_r3611 l
  group by l.trend_dir
  order by coalesce(sum(l.interest_expense_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3611_interest_cost_digest() from public, anon;
grant execute on function public.founder_r3611_interest_cost_digest() to authenticated;

-- 8) High-risk (expensive/distressed) queue
create or replace function public.founder_r3611_high_risk_queue()
returns table(
  facility_name text,
  business_unit text,
  period_month date,
  outstanding_rupees numeric,
  effective_rate_pct numeric,
  benchmark_rate_pct numeric,
  spread_bps int,
  hedged_pct numeric,
  cost_status text,
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
  select l.facility_name, l.business_unit, l.period_month, l.outstanding_rupees,
    l.effective_rate_pct, l.benchmark_rate_pct, l.spread_bps, l.hedged_pct,
    l.cost_status, l.trend_dir, l.notes
  from public.borrowing_cost_r3611 l
  where l.cost_status in ('above_market','expensive','distressed')
     or l.trend_dir = 'worsening'
     or l.spread_bps >= 300
     or l.hedged_pct = 0
  order by l.spread_bps desc, l.outstanding_rupees desc;
end;
$$;

revoke execute on function public.founder_r3611_high_risk_queue() from public, anon;
grant execute on function public.founder_r3611_high_risk_queue() to authenticated;
