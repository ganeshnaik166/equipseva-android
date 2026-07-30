-- Round 3621: Founder Other-Income / Non-Operating-Income Analysis Board
-- Founder finance — other-income / non-operating-income analysis (interest, scrap, forex, rental, misc,
-- provision writeback) per source × business unit × income category × income status × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: other_income_r3621 — per-source non-operating income lines
-- =============================================================================
create table if not exists public.other_income_r3621 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  income_ref text not null,
  income_source text not null,
  business_unit text not null,
  period_month date not null,
  income_amount_rupees numeric(14,2),
  budget_amount_rupees numeric(14,2),
  variance_pct numeric(7,2),
  recurring_pct numeric(6,2),
  ytd_amount_rupees numeric(14,2),
  contribution_to_pbt_pct numeric(6,2),
  income_category text not null check (income_category in (
    'interest','scrap_sale','forex_gain','rental','misc','provision_writeback'
  )),
  income_status text not null check (income_status in (
    'strong','on_budget','below_budget','one_time','volatile'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.other_income_r3621 enable row level security;

create index if not exists idx_other_income_r3621_org on public.other_income_r3621(organization_id);
create index if not exists idx_other_income_r3621_month on public.other_income_r3621(period_month);
create index if not exists idx_other_income_r3621_status on public.other_income_r3621(income_status);

-- =============================================================================
-- TABLE 2: other_income_capa_actions_r3621 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.other_income_capa_actions_r3621 (
  id uuid primary key default gen_random_uuid(),
  income_log_id uuid not null references public.other_income_r3621(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'budget_shortfall','forex_volatility','one_time_dependency','recurring_decline',
    'collection_delay','rate_reduction','scrap_price_drop','provision_reversal_risk'
  )),
  root_cause text not null check (root_cause in (
    'interest_rate_cut','fx_rate_swing','scrap_market_softening','tenant_vacancy',
    'delayed_fd_renewal','one_time_gain_lapsed','accounting_reclass','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_fd_ladder','hedge_forex_exposure','renegotiate_rental_contract',
    'diversify_scrap_vendors','accelerate_collections','reclassify_income',
    'build_recurring_stream','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  income_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.other_income_capa_actions_r3621 enable row level security;

create index if not exists idx_other_income_capa_r3621_log on public.other_income_capa_actions_r3621(income_log_id);
create index if not exists idx_other_income_capa_r3621_status on public.other_income_capa_actions_r3621(capa_status);

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

  -- 16 other-income lines
  insert into public.other_income_r3621 (
    organization_id, income_ref, income_source, business_unit, period_month,
    income_amount_rupees, budget_amount_rupees, variance_pct, recurring_pct,
    ytd_amount_rupees, contribution_to_pbt_pct, income_category, income_status, trend_dir, notes
  )
  select v_org_id, q.iref, q.isrc, q.bu, q.pm::date,
    q.iamt::numeric, q.bamt::numeric, q.vpct::numeric, q.rpct::numeric,
    q.ytd::numeric, q.pbt::numeric, q.icat, q.ist, q.trnd, q.nt
  from (values
    ('OI-FD-2607-01','Fixed deposit interest — SBI','corporate_treasury','2026-07-01',
     '1850000','1800000','2.8','95','12600000','4.2','interest','strong','improving','FD ladder yield up post rate revision'),
    ('OI-FD-2607-02','Fixed deposit interest — HDFC','corporate_treasury','2026-07-01',
     '1420000','1500000','-5.3','92','9800000','3.1','interest','below_budget','worsening','FD renewal at lower rate dragged interest income'),
    ('OI-SCRAP-2607-01','Scrap sale — decommissioned CT tubes','spare_parts','2026-07-01',
     '680000','500000','36.0','20','3200000','1.5','scrap_sale','strong','improving','Higher scrap metal prices boosted realisation'),
    ('OI-SCRAP-2607-02','Scrap sale — old modular OT panels','projects','2026-07-01',
     '240000','350000','-31.4','10','1400000','0.6','scrap_sale','below_budget','worsening','Scrap market softening reduced realisation'),
    ('OI-FX-2607-01','Forex gain — Euro import payables','projects','2026-07-01',
     '920000','400000','130.0','5','2100000','2.0','forex_gain','volatile','worsening','Sharp INR-EUR swing, non-recurring fx gain'),
    ('OI-FX-2607-02','Forex gain — USD spare imports','spare_parts','2026-07-01',
     '-150000','200000','-175.0','5','300000','-0.4','forex_gain','volatile','worsening','Adverse USD movement turned into fx loss this month'),
    ('OI-RENT-2607-01','Equipment rental — dialysis machines','rentals','2026-07-01',
     '1100000','1050000','4.8','88','7400000','2.6','rental','strong','improving','Rental fleet utilisation strong across NABH hospitals'),
    ('OI-RENT-2607-02','Equipment rental — ventilators','rentals','2026-07-01',
     '780000','900000','-13.3','80','5200000','1.8','rental','below_budget','worsening','Ventilator rental demand cooled, partial tenant vacancy'),
    ('OI-MISC-2607-01','Misc — training fees and consumable margin','diagnostics','2026-07-01',
     '320000','300000','6.7','60','2000000','0.7','misc','on_budget','stable','Misc income tracking to plan'),
    ('OI-PWB-2607-01','Provision writeback — old warranty reserve','amc_services','2026-07-01',
     '540000','0','100.0','0','540000','1.2','provision_writeback','one_time','stable','One-time writeback of excess warranty provision'),
    ('OI-FD-2606-01','Fixed deposit interest — SBI','corporate_treasury','2026-06-01',
     '1790000','1800000','-0.6','95','10750000','4.0','interest','on_budget','stable','June FD interest broadly on budget'),
    ('OI-SCRAP-2606-01','Scrap sale — battery and UPS banks','spare_parts','2026-06-01',
     '410000','400000','2.5','15','2520000','0.9','scrap_sale','on_budget','stable','Battery scrap realisation on plan'),
    ('OI-RENT-2606-01','Equipment rental — dialysis machines','rentals','2026-06-01',
     '1050000','1050000','0.0','88','6300000','2.5','rental','on_budget','stable','Rental income flat vs budget'),
    ('OI-FX-2606-01','Forex gain — Euro import payables','projects','2026-06-01',
     '260000','300000','-13.3','5','1180000','0.5','forex_gain','volatile','stable','Modest fx gain, inherently volatile'),
    ('OI-AMC-2607-01','Late-payment interest — AMC debtors','amc_services','2026-07-01',
     '210000','250000','-16.0','70','1350000','0.5','interest','below_budget','worsening','Collection delays reduced late-payment interest'),
    ('OI-MISC-2607-02','Misc — cafeteria and parking recoveries','diagnostics','2026-07-01',
     '180000','200000','-10.0','85','1120000','0.4','misc','below_budget','stable','Recoveries slightly below plan')
  ) as q(iref, isrc, bu, pm, iamt, bamt, vpct, rpct, ytd, pbt, icat, ist, trnd, nt);

  -- CAPA seed — attach to specific income lines via income_ref
  insert into public.other_income_capa_actions_r3621 (
    income_log_id, finding_category, root_cause, corrective_action,
    capa_status, income_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp::numeric, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('OI-FD-2607-02','rate_reduction','delayed_fd_renewal','reprice_fd_ladder','in_progress','80000','Treasury — R. Nair','2026-08-15',null,'Re-laddering FDs to lock higher-yield tenors'),
    ('OI-SCRAP-2607-02','scrap_price_drop','scrap_market_softening','diversify_scrap_vendors','open','110000','Spares — A. Kulkarni','2026-08-20',null,'Onboarding additional scrap buyers to improve realisation'),
    ('OI-FX-2607-01','forex_volatility','fx_rate_swing','hedge_forex_exposure','escalated','520000','Finance — S. Menon','2026-08-10',null,'Forward cover on EUR payables to reduce fx volatility'),
    ('OI-FX-2607-02','forex_volatility','fx_rate_swing','hedge_forex_exposure','overdue','350000','Finance — S. Menon','2026-07-25',null,'USD hedge past target date — vendor confirmation pending'),
    ('OI-RENT-2607-02','recurring_decline','tenant_vacancy','renegotiate_rental_contract','in_progress','120000','Rentals — P. Desai','2026-08-30',null,'Renegotiating ventilator rental terms with hospitals'),
    ('OI-AMC-2607-01','collection_delay','pending_investigation','accelerate_collections','open','40000','AMC — V. Rao','2026-08-18',null,'Chasing overdue AMC debtors to recover late-payment interest'),
    ('OI-PWB-2607-01','one_time_dependency','one_time_gain_lapsed','build_recurring_stream','verification_pending','540000','FP&A — D. Iyer','2026-08-05',null,'One-time writeback flagged — building recurring income to offset'),
    ('OI-MISC-2607-02','budget_shortfall','accounting_reclass','reclassify_income','closed','20000','Accounts — M. Shah','2026-07-20','2026-07-19','Recoveries reclassified correctly — variance resolved')
  ) as q(iref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.other_income_r3621 e
    on e.organization_id = v_org_id and e.income_ref = q.iref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Income status distribution
create or replace function public.founder_r3621_income_status_rollup()
returns table(income_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.other_income_r3621)
  select l.income_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.other_income_r3621 l
  group by l.income_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3621_income_status_rollup() from public, anon;
grant execute on function public.founder_r3621_income_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3621_business_unit_scorecard()
returns table(
  business_unit text,
  entries bigint,
  strong bigint,
  below_budget bigint,
  volatile bigint,
  total_income_rupees numeric,
  total_budget_rupees numeric,
  avg_variance_pct numeric
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
    count(*) filter (where l.income_status = 'strong')::bigint,
    count(*) filter (where l.income_status = 'below_budget')::bigint,
    count(*) filter (where l.income_status = 'volatile')::bigint,
    coalesce(sum(l.income_amount_rupees),0)::numeric,
    coalesce(sum(l.budget_amount_rupees),0)::numeric,
    round(avg(l.variance_pct), 2)
  from public.other_income_r3621 l
  group by l.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3621_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3621_business_unit_scorecard() to authenticated;

-- 3) Income-category × income-status matrix
create or replace function public.founder_r3621_category_status_matrix()
returns table(income_category text, income_status text, entries bigint, total_income_rupees numeric, avg_contribution_to_pbt_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.income_category, l.income_status, count(*)::bigint,
    coalesce(sum(l.income_amount_rupees),0)::numeric,
    round(avg(l.contribution_to_pbt_pct), 2)
  from public.other_income_r3621 l
  group by l.income_category, l.income_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3621_category_status_matrix() from public, anon;
grant execute on function public.founder_r3621_category_status_matrix() to authenticated;

-- 4) Monthly other-income trend
create or replace function public.founder_r3621_monthly_income_trend()
returns table(period_month date, entries bigint, total_income_rupees numeric, total_budget_rupees numeric, avg_variance_pct numeric, below_budget bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.income_amount_rupees),0)::numeric,
    coalesce(sum(l.budget_amount_rupees),0)::numeric,
    round(avg(l.variance_pct), 2),
    count(*) filter (where l.income_status = 'below_budget')::bigint
  from public.other_income_r3621 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3621_monthly_income_trend() from public, anon;
grant execute on function public.founder_r3621_monthly_income_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3621_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.income_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.other_income_capa_actions_r3621 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3621_capa_status_board() from public, anon;
grant execute on function public.founder_r3621_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3621_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.other_income_capa_actions_r3621)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.income_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.other_income_capa_actions_r3621 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3621_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3621_root_cause_pareto() to authenticated;

-- 7) Income-impact digest by finding category
create or replace function public.founder_r3621_income_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.income_impact_rupees),0)::numeric
  from public.other_income_capa_actions_r3621 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3621_income_impact_digest() from public, anon;
grant execute on function public.founder_r3621_income_impact_digest() to authenticated;

-- 8) High-risk income queue (below_budget / volatile / worsening)
create or replace function public.founder_r3621_high_risk_queue()
returns table(
  income_source text,
  income_ref text,
  business_unit text,
  income_category text,
  period_month date,
  income_status text,
  variance_pct numeric,
  recurring_pct numeric,
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
  select l.income_source, l.income_ref, l.business_unit, l.income_category, l.period_month,
    l.income_status, l.variance_pct, l.recurring_pct, l.trend_dir, l.notes
  from public.other_income_r3621 l
  where l.income_status in ('below_budget','volatile','one_time')
     or l.trend_dir = 'worsening'
     or l.variance_pct < 0
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3621_high_risk_queue() from public, anon;
grant execute on function public.founder_r3621_high_risk_queue() to authenticated;
