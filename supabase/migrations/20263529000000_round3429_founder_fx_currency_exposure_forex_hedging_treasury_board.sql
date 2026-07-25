-- Round 3429: Founder FX Currency-Exposure / Forex-Hedging Treasury Board
-- Treasury FX-exposure & hedging board — currency pair × exposure type × hedge instrument ×
-- hedge ratio × spot vs booked rate × MTM gain/loss × value date × counterparty bank × verdict × CAPA

-- =============================================================================
-- TABLE 1: founder_fx_currency_exposure_forex_hedging_r3429 — per-exposure hedging positions
-- =============================================================================
create table if not exists public.founder_fx_currency_exposure_forex_hedging_r3429 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  exposure_code text not null,
  exposure_name text not null,
  currency_pair text not null check (currency_pair in (
    'USD_INR','EUR_INR','GBP_INR','JPY_INR','SGD_INR','CHF_INR'
  )),
  exposure_type text not null check (exposure_type in (
    'import_payable','export_receivable','foreign_loan','capex_commitment','royalty'
  )),
  exposure_amount_fcy numeric(18,2),
  exposure_amount_rupees numeric(18,2),
  hedge_instrument text not null check (hedge_instrument in (
    'forward','option','swap','natural_hedge','unhedged'
  )),
  hedge_ratio_pct numeric(6,2),
  spot_rate numeric(12,4),
  booked_rate numeric(12,4),
  mtm_gain_loss_rupees numeric(18,2),
  value_date date,
  counterparty_bank text,
  hedge_verdict text not null check (hedge_verdict in (
    'adequately_hedged','under_hedged','over_hedged','unhedged_exposed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_fx_currency_exposure_forex_hedging_r3429 enable row level security;

create index if not exists idx_fx_hedging_r3429_org on public.founder_fx_currency_exposure_forex_hedging_r3429(organization_id);
create index if not exists idx_fx_hedging_r3429_pair on public.founder_fx_currency_exposure_forex_hedging_r3429(currency_pair);
create index if not exists idx_fx_hedging_r3429_verdict on public.founder_fx_currency_exposure_forex_hedging_r3429(hedge_verdict);

-- =============================================================================
-- TABLE 2: founder_fx_currency_exposure_forex_hedging_capa_actions_r3429 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  finding_key text not null,
  exposure_name text not null,
  root_cause text not null check (root_cause in (
    'hedge_policy_gap','delayed_forward_booking','rate_view_speculation','unhedged_open_position',
    'over_hedged_forecast_error','counterparty_limit_breach','documentation_delay',
    'natural_hedge_assumption_failed','pending_investigation','market_volatility_spike'
  )),
  corrective_action text not null check (corrective_action in (
    'book_forward_cover','buy_option_hedge','enter_currency_swap','unwind_over_hedge',
    'increase_hedge_ratio','tighten_hedge_policy','escalate_to_treasury_committee',
    'rebalance_natural_hedge','no_action_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact_rupees numeric(18,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429 enable row level security;

create index if not exists idx_fx_hedging_capa_r3429_org on public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429(organization_id);
create index if not exists idx_fx_hedging_capa_r3429_status on public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429(capa_status);

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

  -- 16 exposure rows
  insert into public.founder_fx_currency_exposure_forex_hedging_r3429 (
    organization_id, exposure_code, exposure_name, currency_pair, exposure_type,
    exposure_amount_fcy, exposure_amount_rupees, hedge_instrument, hedge_ratio_pct,
    spot_rate, booked_rate, mtm_gain_loss_rupees, value_date, counterparty_bank, hedge_verdict, notes
  )
  select v_org_id, q.ecode, q.ename, q.cpair, q.etype,
    q.fcy, q.inr, q.hinst, q.hratio,
    q.spot, q.booked, q.mtm, q.vdate::date, q.bank, q.hv, q.nt
  from (values
    ('FX-IMP-USD-01','US MRI console import payable','USD_INR','import_payable',
     2500000,208750000,'forward',90,83.5000,82.4000,2750000,'2026-08-15','HDFC Bank','adequately_hedged','90% forward cover booked with HDFC, favourable MTM'),
    ('FX-EXP-EUR-02','EU diagnostics export receivable','EUR_INR','export_receivable',
     1800000,165600000,'forward',120,92.0000,91.2000,-1440000,'2026-08-05','ICICI Bank','over_hedged','Hedged 120% then forecast revised down — over-hedged position'),
    ('FX-LOAN-USD-03','ECB foreign-currency term loan','USD_INR','foreign_loan',
     5000000,417500000,'swap',100,83.5000,80.1000,-17000000,'2026-09-30','State Bank of India','adequately_hedged','Principal+interest swapped at 80.10, rupee depreciation MTM loss on swap'),
    ('FX-CAP-EUR-04','MRI suite capex commitment','EUR_INR','capex_commitment',
     900000,82800000,'option',60,92.0000,90.5000,620000,'2026-10-20','Axis Bank','under_hedged','Only 60% covered via call option — under-hedged on capex'),
    ('FX-ROY-USD-05','Software royalty remittance','USD_INR','royalty',
     350000,29225000,'unhedged',0,83.5000,null,-420000,'2026-08-25','HDFC Bank','unhedged_exposed','Quarterly royalty left unhedged — exposed to USD strength'),
    ('FX-IMP-JPY-06','Japanese endoscope import payable','JPY_INR','import_payable',
     60000000,33600000,'forward',85,0.5600,0.5520,480000,'2026-09-10','Kotak Mahindra Bank','adequately_hedged','85% forward on JPY payable, small favourable MTM'),
    ('FX-EXP-GBP-07','UK teleradiology export receivable','GBP_INR','export_receivable',
     700000,74200000,'forward',70,106.0000,107.1000,-770000,'2026-08-18','Standard Chartered','under_hedged','70% cover on GBP receivable — residual open, adverse MTM'),
    ('FX-CAP-USD-08','Cath-lab capex import commitment','USD_INR','capex_commitment',
     1200000,100200000,'forward',95,83.5000,82.8000,840000,'2026-11-05','ICICI Bank','adequately_hedged','95% forward cover on capex, favourable MTM'),
    ('FX-LOAN-EUR-09','EUR working-capital loan','EUR_INR','foreign_loan',
     2000000,184000000,'natural_hedge',40,92.0000,null,-2600000,'2026-09-22','HSBC India','under_hedged','Relying on EUR receivables as natural hedge — only 40% matched'),
    ('FX-ROY-EUR-10','Imaging license royalty','EUR_INR','royalty',
     250000,23000000,'unhedged',0,92.0000,null,-310000,'2026-08-28','Yes Bank','unhedged_exposed','Small royalty unhedged, EUR appreciation MTM loss'),
    ('FX-IMP-SGD-11','Singapore lab reagent payable','SGD_INR','import_payable',
     800000,51600000,'forward',100,64.5000,63.9000,480000,'2026-09-15','DBS Bank India','adequately_hedged','Full forward cover on SGD payable'),
    ('FX-CAP-CHF-12','Swiss surgical robot capex','CHF_INR','capex_commitment',
     600000,56400000,'option',55,94.0000,92.2000,1350000,'2026-12-01','Standard Chartered','under_hedged','55% option cover on CHF capex — under-hedged, favourable MTM so far'),
    ('FX-EXP-USD-13','US PACS SaaS export receivable','USD_INR','export_receivable',
     1500000,125250000,'forward',130,83.5000,84.2000,1050000,'2026-08-12','Axis Bank','over_hedged','Hedged 130% against a receivable that shrank — over-hedged'),
    ('FX-LOAN-JPY-14','JPY buyer-credit facility','JPY_INR','foreign_loan',
     120000000,67200000,'swap',100,0.5600,0.5480,-1440000,'2026-10-10','IndusInd Bank','adequately_hedged','Buyer credit swapped to fixed INR, minor MTM loss'),
    ('FX-IMP-USD-15','Ventilator spares import payable','USD_INR','import_payable',
     420000,35070000,'unhedged',0,83.5000,null,-560000,'2026-08-08','HDFC Bank','unhedged_exposed','Spot-settled spares payable left unhedged — exposed'),
    ('FX-CAP-GBP-16','UK linac capex commitment','GBP_INR','capex_commitment',
     950000,100700000,'forward',80,106.0000,105.3000,665000,'2026-11-18','Kotak Mahindra Bank','adequately_hedged','80% forward on GBP capex, favourable MTM')
  ) as q(ecode, ename, cpair, etype, fcy, inr, hinst, hratio, spot, booked, mtm, vdate, bank, hv, nt);

  -- CAPA seed — org-scoped remediation actions on flagged exposures
  insert into public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429 (
    organization_id, finding_key, exposure_name, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, q.fk, q.en, q.rc, q.ca,
    q.cst, q.fin, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('FX-ROY-USD-05','Software royalty remittance','unhedged_open_position','book_forward_cover','in_progress',420000,'Treasury - R. Nair','2026-08-10',null,'Book forward to cover quarterly royalty outflow'),
    ('FX-EXP-GBP-07','UK teleradiology export receivable','delayed_forward_booking','increase_hedge_ratio','open',770000,'Treasury - S. Iyer','2026-08-08',null,'Raise GBP receivable cover from 70% to policy 90%'),
    ('FX-LOAN-EUR-09','EUR working-capital loan','natural_hedge_assumption_failed','enter_currency_swap','escalated',2600000,'CFO Office','2026-08-30',null,'Natural hedge mismatch — escalate to swap the EUR loan'),
    ('FX-ROY-EUR-10','Imaging license royalty','unhedged_open_position','book_forward_cover','open',310000,'Treasury - R. Nair','2026-08-20',null,'Small EUR royalty exposure to be forward-covered'),
    ('FX-IMP-USD-15','Ventilator spares import payable','hedge_policy_gap','tighten_hedge_policy','verification_pending',560000,'Treasury - A. Desai','2026-08-05','2026-08-04','Policy updated to auto-hedge sub-500k payables'),
    ('FX-EXP-EUR-02','EU diagnostics export receivable','over_hedged_forecast_error','unwind_over_hedge','closed',1440000,'Treasury - S. Iyer','2026-07-28','2026-07-25','Unwound excess EUR forward after forecast revision'),
    ('FX-EXP-USD-13','US PACS SaaS export receivable','over_hedged_forecast_error','unwind_over_hedge','overdue',1050000,'Treasury - S. Iyer','2026-07-20',null,'Over-hedge on shrunk receivable — unwind past due'),
    ('FX-CAP-CHF-12','Swiss surgical robot capex','delayed_forward_booking','increase_hedge_ratio','in_progress',900000,'CFO Office','2026-08-25',null,'Raise CHF capex cover from 55% toward 85% policy')
  ) as q(fk, en, rc, ca, cst, fin, own, tcd, acd, nt);
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Hedge-verdict distribution
create or replace function public.founder_r3429_hedge_verdict_rollup()
returns table(hedge_verdict text, exposures bigint, total_exposure_rupees numeric, net_mtm_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_fx_currency_exposure_forex_hedging_r3429)
  select l.hedge_verdict, count(*)::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    coalesce(sum(l.mtm_gain_loss_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.founder_fx_currency_exposure_forex_hedging_r3429 l
  group by l.hedge_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3429_hedge_verdict_rollup() from public, anon;
grant execute on function public.founder_r3429_hedge_verdict_rollup() to authenticated;

-- 2) Currency-pair scorecard
create or replace function public.founder_r3429_currency_pair_scorecard()
returns table(
  currency_pair text,
  exposures bigint,
  total_exposure_rupees numeric,
  adequately_hedged bigint,
  under_hedged bigint,
  unhedged_exposed bigint,
  avg_hedge_ratio_pct numeric,
  net_mtm_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.currency_pair,
    count(*)::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    count(*) filter (where l.hedge_verdict = 'adequately_hedged')::bigint,
    count(*) filter (where l.hedge_verdict = 'under_hedged')::bigint,
    count(*) filter (where l.hedge_verdict = 'unhedged_exposed')::bigint,
    round(avg(l.hedge_ratio_pct), 1),
    coalesce(sum(l.mtm_gain_loss_rupees),0)::numeric
  from public.founder_fx_currency_exposure_forex_hedging_r3429 l
  group by l.currency_pair
  order by sum(l.exposure_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3429_currency_pair_scorecard() from public, anon;
grant execute on function public.founder_r3429_currency_pair_scorecard() to authenticated;

-- 3) Exposure-type × hedge-instrument matrix
create or replace function public.founder_r3429_exposure_hedge_matrix()
returns table(
  exposure_type text,
  hedge_instrument text,
  exposures bigint,
  total_exposure_rupees numeric,
  avg_hedge_ratio_pct numeric,
  net_mtm_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.exposure_type, l.hedge_instrument, count(*)::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    round(avg(l.hedge_ratio_pct), 1),
    coalesce(sum(l.mtm_gain_loss_rupees),0)::numeric
  from public.founder_fx_currency_exposure_forex_hedging_r3429 l
  group by l.exposure_type, l.hedge_instrument
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3429_exposure_hedge_matrix() from public, anon;
grant execute on function public.founder_r3429_exposure_hedge_matrix() to authenticated;

-- 4) Monthly value-date / MTM trend
create or replace function public.founder_r3429_monthly_mtm_trend()
returns table(
  value_month date,
  exposures bigint,
  total_exposure_rupees numeric,
  net_mtm_rupees numeric,
  mtm_loss_rupees numeric,
  unhedged_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.value_date)::date,
    count(*)::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    coalesce(sum(l.mtm_gain_loss_rupees),0)::numeric,
    coalesce(sum(l.mtm_gain_loss_rupees) filter (where l.mtm_gain_loss_rupees < 0),0)::numeric,
    count(*) filter (where l.hedge_instrument = 'unhedged' or l.hedge_verdict = 'unhedged_exposed')::bigint
  from public.founder_fx_currency_exposure_forex_hedging_r3429 l
  where l.value_date is not null
  group by date_trunc('month', l.value_date)
  order by date_trunc('month', l.value_date);
end;
$$;

revoke execute on function public.founder_r3429_monthly_mtm_trend() from public, anon;
grant execute on function public.founder_r3429_monthly_mtm_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3429_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(avg(c.financial_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3429_capa_status_board() from public, anon;
grant execute on function public.founder_r3429_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3429_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.founder_fx_currency_exposure_forex_hedging_capa_actions_r3429 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3429_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3429_root_cause_pareto() to authenticated;

-- 7) Financial-impact (MTM) digest by exposure type
create or replace function public.founder_r3429_mtm_impact_digest()
returns table(
  exposure_type text,
  exposures bigint,
  total_exposure_rupees numeric,
  mtm_gain_rupees numeric,
  mtm_loss_rupees numeric,
  net_mtm_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.exposure_type, count(*)::bigint,
    coalesce(sum(l.exposure_amount_rupees),0)::numeric,
    coalesce(sum(l.mtm_gain_loss_rupees) filter (where l.mtm_gain_loss_rupees > 0),0)::numeric,
    coalesce(sum(l.mtm_gain_loss_rupees) filter (where l.mtm_gain_loss_rupees < 0),0)::numeric,
    coalesce(sum(l.mtm_gain_loss_rupees),0)::numeric
  from public.founder_fx_currency_exposure_forex_hedging_r3429 l
  group by l.exposure_type
  order by sum(l.exposure_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3429_mtm_impact_digest() from public, anon;
grant execute on function public.founder_r3429_mtm_impact_digest() to authenticated;

-- 8) High-risk exposure queue (unhedged / under-hedged / over-hedged / large MTM loss)
create or replace function public.founder_r3429_high_risk_queue()
returns table(
  exposure_name text,
  exposure_code text,
  currency_pair text,
  exposure_type text,
  exposure_amount_rupees numeric,
  hedge_instrument text,
  hedge_ratio_pct numeric,
  mtm_gain_loss_rupees numeric,
  value_date date,
  counterparty_bank text,
  hedge_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.exposure_name, l.exposure_code, l.currency_pair, l.exposure_type,
    l.exposure_amount_rupees, l.hedge_instrument, l.hedge_ratio_pct,
    l.mtm_gain_loss_rupees, l.value_date, l.counterparty_bank, l.hedge_verdict, l.notes
  from public.founder_fx_currency_exposure_forex_hedging_r3429 l
  where l.hedge_verdict in ('under_hedged','over_hedged','unhedged_exposed')
     or l.hedge_instrument = 'unhedged'
     or l.mtm_gain_loss_rupees <= -1000000
  order by l.mtm_gain_loss_rupees asc, l.exposure_amount_rupees desc;
end;
$$;

revoke execute on function public.founder_r3429_high_risk_queue() from public, anon;
grant execute on function public.founder_r3429_high_risk_queue() to authenticated;
