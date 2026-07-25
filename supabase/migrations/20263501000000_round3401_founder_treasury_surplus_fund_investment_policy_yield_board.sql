-- Round 3401: Founder Treasury Surplus-Fund / Short-Term Investment-Policy & FD-Ladder Yield Board
-- Treasury governance — instrument type × bank/AMC × amount × tenor × yield vs benchmark × liquidity tier × credit rating × policy compliance × concentration × CAPA

-- =============================================================================
-- TABLE 1: treasury_surplus_fund_r3401 — per-instrument records
-- =============================================================================
create table if not exists public.treasury_surplus_fund_r3401 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  instrument_name text not null,
  instrument_type text not null check (instrument_type in (
    'fixed_deposit','liquid_mutual_fund','overnight_fund','ultra_short_debt_fund',
    'treasury_bill','sweep_account','corporate_deposit'
  )),
  bank_or_amc text not null,
  amount_rupees numeric(14,2) not null,
  placement_date date not null,
  maturity_date date not null,
  tenor_days int not null,
  yield_pct numeric(5,2) not null,
  benchmark_yield_pct numeric(5,2) not null,
  liquidity_tier text not null check (liquidity_tier in (
    'instant','t_plus_1','t_plus_30','locked'
  )),
  credit_rating text not null check (credit_rating in (
    'sovereign','aaa','aa','a','unrated'
  )),
  policy_compliant boolean not null,
  days_to_maturity int not null,
  auto_rollover boolean not null,
  concentration_ok boolean not null,
  treasury_verdict text not null check (treasury_verdict in (
    'optimal','acceptable','reinvest','low_yield','concentration_risk','policy_breach'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.treasury_surplus_fund_r3401 enable row level security;

create index if not exists idx_treasury_surplus_fund_r3401_org on public.treasury_surplus_fund_r3401(organization_id);
create index if not exists idx_treasury_surplus_fund_r3401_verdict on public.treasury_surplus_fund_r3401(treasury_verdict);

-- =============================================================================
-- TABLE 2: treasury_surplus_fund_capa_actions_r3401 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.treasury_surplus_fund_capa_actions_r3401 (
  id uuid primary key default gen_random_uuid(),
  fund_log_id uuid not null references public.treasury_surplus_fund_r3401(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'yield_below_benchmark','concentration_breach','policy_breach','liquidity_mismatch',
    'maturity_clustering','credit_downgrade','idle_cash','reinvestment_due'
  )),
  root_cause text not null check (root_cause in (
    'suboptimal_placement','single_counterparty','policy_gap','poor_laddering',
    'rate_environment_shift','delayed_reinvestment','manual_process','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reallocate_funds','diversify_counterparty','update_investment_policy','build_maturity_ladder',
    'reinvest_surplus','sweep_idle_cash','automate_treasury','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'high_yield_leak','moderate','low','none','capital_risk','opportunity_cost'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_uplift_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.treasury_surplus_fund_capa_actions_r3401 enable row level security;

create index if not exists idx_treasury_surplus_capa_r3401_log on public.treasury_surplus_fund_capa_actions_r3401(fund_log_id);
create index if not exists idx_treasury_surplus_capa_r3401_status on public.treasury_surplus_fund_capa_actions_r3401(capa_status);

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

  insert into public.treasury_surplus_fund_r3401 (
    organization_id, instrument_name, instrument_type, bank_or_amc, amount_rupees,
    placement_date, maturity_date, tenor_days, yield_pct, benchmark_yield_pct,
    liquidity_tier, credit_rating, policy_compliant, days_to_maturity, auto_rollover,
    concentration_ok, treasury_verdict, notes
  )
  select v_org_id, q.name, q.itype, q.bank, q.amt::numeric,
    q.pdate::date, q.mdate::date, q.tenor::int, q.yield, q.bench,
    q.liq, q.rating, q.compliant, q.days::int, q.autoroll,
    q.concok, q.verdict, q.nt
  from (values
    ('HDFC 91-day FD','fixed_deposit','HDFC Bank','5000000','2026-05-01','2026-07-31',91,7.10,6.80,'locked','aaa',true,6,true,true,'optimal','FD beating benchmark, matures in ladder'),
    ('ICICI Liquid Fund','liquid_mutual_fund','ICICI Prudential AMC','8000000','2026-06-01','2026-08-31',91,6.95,6.80,'t_plus_1','aaa',true,37,false,true,'acceptable','Liquid fund on benchmark, high liquidity'),
    ('SBI Overnight Fund','overnight_fund','SBI Mutual Fund','3000000','2026-07-01','2026-07-26',25,6.40,6.50,'instant','aaa',true,1,false,true,'low_yield','Overnight fund below benchmark — sweep to liquid'),
    ('Axis Ultra-Short Debt','ultra_short_debt_fund','Axis AMC','6000000','2026-04-15','2026-08-15',122,7.30,6.90,'t_plus_30','aaa',true,21,false,true,'optimal','Ultra-short debt outperforming benchmark'),
    ('91-day T-Bill','treasury_bill','RBI','4000000','2026-05-15','2026-08-14',91,6.85,6.80,'t_plus_1','sovereign',true,20,false,true,'acceptable','T-bill sovereign safety, on benchmark'),
    ('Kotak Sweep Account','sweep_account','Kotak Bank','2000000','2026-07-01','2026-07-31',30,5.50,6.50,'instant','aaa',true,6,true,true,'low_yield','Sweep balance idle at low yield — deploy to liquid fund'),
    ('HDFC 181-day FD','fixed_deposit','HDFC Bank','7000000','2026-03-01','2026-08-29',181,7.25,6.90,'locked','aaa',false,35,true,false,'concentration_risk','HDFC exposure exceeds single-counterparty policy limit'),
    ('Bajaj Finance Corp Deposit','corporate_deposit','Bajaj Finance','3000000','2026-04-01','2026-10-01',183,7.80,6.90,'locked','aa',false,69,false,true,'policy_breach','AA corporate deposit breaches AAA-minimum policy'),
    ('SBI 90-day FD','fixed_deposit','SBI','5000000','2026-06-01','2026-08-30',90,7.05,6.80,'locked','aaa',true,36,true,true,'acceptable','SBI FD diversifies counterparty, on target'),
    ('Nippon Liquid Fund','liquid_mutual_fund','Nippon India AMC','4000000','2026-06-15','2026-09-15',92,6.90,6.80,'t_plus_1','aaa',true,52,false,true,'acceptable','Liquid fund on benchmark'),
    ('182-day T-Bill','treasury_bill','RBI','6000000','2026-05-01','2026-10-30',182,7.00,6.90,'t_plus_1','sovereign',true,98,false,true,'optimal','182-day T-bill sovereign, above benchmark'),
    ('Axis 60-day FD','fixed_deposit','Axis Bank','2500000','2026-06-20','2026-08-19',60,6.60,6.70,'locked','aaa',true,25,false,true,'reinvest','Short FD maturing — reinvest into longer ladder rung'),
    ('ICICI Overnight Fund','overnight_fund','ICICI Prudential AMC','1500000','2026-07-10','2026-07-27',17,6.35,6.50,'instant','aaa',true,2,false,true,'low_yield','Overnight parking below benchmark — sweep up'),
    ('DSP Ultra-Short Debt','ultra_short_debt_fund','DSP AMC','3500000','2026-05-20','2026-09-20',123,7.20,6.90,'t_plus_30','aaa',true,57,false,true,'optimal','Ultra-short debt beating benchmark comfortably')
  ) as q(name, itype, bank, amt, pdate, mdate, tenor, yield, bench, liq, rating, compliant, days, autoroll, concok, verdict, nt);

  insert into public.treasury_surplus_fund_capa_actions_r3401 (
    fund_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_uplift_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.uplift::numeric, q.nt
  from (values
    ('HDFC 181-day FD','concentration_breach','single_counterparty','diversify_counterparty','in_progress','capital_risk','2026-08-10',null,0,'Reduce HDFC exposure below 25% single-counterparty limit'),
    ('Bajaj Finance Corp Deposit','policy_breach','policy_gap','reallocate_funds','escalated','capital_risk','2026-08-01',null,0,'Exit AA corporate deposit; reallocate to AAA per policy'),
    ('Kotak Sweep Account','idle_cash','delayed_reinvestment','sweep_idle_cash','open','opportunity_cost','2026-07-28',null,15000,'Deploy idle sweep balance to liquid fund for ~1% uplift'),
    ('SBI Overnight Fund','yield_below_benchmark','suboptimal_placement','reinvest_surplus','open','opportunity_cost','2026-07-27',null,8000,'Move overnight balance to ultra-short for yield pickup'),
    ('Axis 60-day FD','reinvestment_due','poor_laddering','build_maturity_ladder','verification_pending','moderate','2026-08-19',null,12000,'Reinvest into 182-day rung to smooth ladder'),
    ('ICICI Overnight Fund','yield_below_benchmark','suboptimal_placement','sweep_idle_cash','overdue','opportunity_cost','2026-07-25',null,4000,'Overnight fund sweep-up past target'),
    ('HDFC 91-day FD','maturity_clustering','poor_laddering','build_maturity_ladder','closed','low','2026-07-20','2026-07-15',0,'Ladder rebalanced to avoid Aug maturity clustering')
  ) as q(name, fc, rc, ca, cst, fi, tcd, acd, uplift, nt)
  join public.treasury_surplus_fund_r3401 e
    on e.organization_id = v_org_id and e.instrument_name = q.name;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3401_treasury_verdict_rollup()
returns table(treasury_verdict text, instruments bigint, total_amount_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.treasury_surplus_fund_r3401)
  select l.treasury_verdict, count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.treasury_surplus_fund_r3401 l group by l.treasury_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3401_treasury_verdict_rollup() from public, anon;
grant execute on function public.founder_r3401_treasury_verdict_rollup() to authenticated;

create or replace function public.founder_r3401_type_scorecard()
returns table(
  instrument_type text, instruments bigint, total_amount_rupees numeric, avg_yield_pct numeric,
  avg_benchmark_pct numeric, below_benchmark bigint, policy_breaches bigint, above_benchmark_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_type, count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(avg(l.yield_pct), 2),
    round(avg(l.benchmark_yield_pct), 2),
    count(*) filter (where l.yield_pct < l.benchmark_yield_pct)::bigint,
    count(*) filter (where l.policy_compliant = false)::bigint,
    round(100.0 * count(*) filter (where l.yield_pct >= l.benchmark_yield_pct)::numeric / nullif(count(*),0), 1)
  from public.treasury_surplus_fund_r3401 l group by l.instrument_type order by sum(l.amount_rupees) desc;
end;
$$;
revoke execute on function public.founder_r3401_type_scorecard() from public, anon;
grant execute on function public.founder_r3401_type_scorecard() to authenticated;

create or replace function public.founder_r3401_liquidity_rating_matrix()
returns table(liquidity_tier text, credit_rating text, instruments bigint, total_amount_rupees numeric, avg_yield_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.liquidity_tier, l.credit_rating, count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(avg(l.yield_pct), 2)
  from public.treasury_surplus_fund_r3401 l group by l.liquidity_tier, l.credit_rating order by sum(l.amount_rupees) desc;
end;
$$;
revoke execute on function public.founder_r3401_liquidity_rating_matrix() from public, anon;
grant execute on function public.founder_r3401_liquidity_rating_matrix() to authenticated;

create or replace function public.founder_r3401_maturity_runway_trend()
returns table(maturity_month text, instruments bigint, total_amount_rupees numeric, avg_yield_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.maturity_date, 'YYYY-MM') as maturity_month, count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(avg(l.yield_pct), 2)
  from public.treasury_surplus_fund_r3401 l group by 1 order by 1;
end;
$$;
revoke execute on function public.founder_r3401_maturity_runway_trend() from public, anon;
grant execute on function public.founder_r3401_maturity_runway_trend() to authenticated;

create or replace function public.founder_r3401_capa_status_board()
returns table(capa_status text, findings bigint, avg_uplift_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_uplift_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.treasury_surplus_fund_capa_actions_r3401 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3401_capa_status_board() from public, anon;
grant execute on function public.founder_r3401_capa_status_board() to authenticated;

create or replace function public.founder_r3401_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_uplift_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.treasury_surplus_fund_capa_actions_r3401)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_uplift_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.treasury_surplus_fund_capa_actions_r3401 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3401_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3401_root_cause_pareto() to authenticated;

create or replace function public.founder_r3401_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_uplift_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_uplift_rupees),0)::numeric
  from public.treasury_surplus_fund_capa_actions_r3401 c group by c.financial_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3401_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3401_financial_impact_digest() to authenticated;

create or replace function public.founder_r3401_high_risk_queue()
returns table(
  instrument_name text, instrument_type text, bank_or_amc text, amount_rupees numeric,
  yield_pct numeric, benchmark_yield_pct numeric, credit_rating text, days_to_maturity int,
  treasury_verdict text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_name, l.instrument_type, l.bank_or_amc, l.amount_rupees,
    l.yield_pct, l.benchmark_yield_pct, l.credit_rating, l.days_to_maturity,
    l.treasury_verdict, l.notes
  from public.treasury_surplus_fund_r3401 l
  where l.treasury_verdict in ('reinvest','low_yield','concentration_risk','policy_breach')
     or l.policy_compliant = false
     or l.concentration_ok = false
     or l.yield_pct < l.benchmark_yield_pct
     or l.days_to_maturity <= 7
  order by
    case l.treasury_verdict when 'policy_breach' then 0 when 'concentration_risk' then 1 when 'low_yield' then 2 else 3 end,
    l.amount_rupees desc;
end;
$$;
revoke execute on function public.founder_r3401_high_risk_queue() from public, anon;
grant execute on function public.founder_r3401_high_risk_queue() to authenticated;
