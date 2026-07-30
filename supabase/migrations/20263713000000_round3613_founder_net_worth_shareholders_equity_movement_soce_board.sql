-- Round 3613: Founder Net-Worth / Shareholders-Equity Movement (SOCE) Board
-- Statement-of-changes-in-equity log — entity × period × opening equity × net profit × dividends × capital raised × OCI × other adjustments × closing equity × net-worth growth % × book value/share × equity status × trend × CAPA

-- =============================================================================
-- TABLE 1: networth_movement_r3613 — per-entity SOCE (statement of changes in equity)
-- =============================================================================
create table if not exists public.networth_movement_r3613 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  entry_code text not null,
  period_month date not null,
  opening_equity_rupees numeric(16,2),
  net_profit_rupees numeric(16,2),
  dividends_paid_rupees numeric(16,2),
  capital_raised_rupees numeric(16,2),
  oci_movement_rupees numeric(16,2),
  other_adjustments_rupees numeric(16,2),
  closing_equity_rupees numeric(16,2),
  net_worth_growth_pct numeric(8,2),
  book_value_per_share_rupees numeric(12,2),
  equity_status text not null check (equity_status in (
    'strengthening','stable','eroding','depleted','negative_networth'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.networth_movement_r3613 enable row level security;

create index if not exists idx_networth_movement_r3613_org on public.networth_movement_r3613(organization_id);
create index if not exists idx_networth_movement_r3613_period on public.networth_movement_r3613(period_month);
create index if not exists idx_networth_movement_r3613_status on public.networth_movement_r3613(equity_status);

-- =============================================================================
-- TABLE 2: networth_movement_capa_actions_r3613 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.networth_movement_capa_actions_r3613 (
  id uuid primary key default gen_random_uuid(),
  movement_id uuid not null references public.networth_movement_r3613(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dividend_over_distribution','capital_erosion','oci_volatility','accumulated_losses',
    'negative_net_worth','book_value_decline','equity_dilution','reserve_shortfall',
    'audit_adjustment','covenant_breach'
  )),
  root_cause text not null check (root_cause in (
    'operating_losses','excess_dividend_payout','fair_value_writedown','forex_translation_loss',
    'impairment_charge','buyback_capital_reduction','deferred_tax_adjustment','pending_investigation',
    'prior_period_error','goodwill_writeoff'
  )),
  corrective_action text not null check (corrective_action in (
    'suspend_dividends','raise_fresh_capital','cost_restructuring','asset_revaluation',
    'debt_to_equity_conversion','retain_earnings','hedge_forex_exposure','impairment_review',
    'restate_financials','board_capital_plan','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  equity_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.networth_movement_capa_actions_r3613 enable row level security;

create index if not exists idx_networth_movement_capa_r3613_move on public.networth_movement_capa_actions_r3613(movement_id);
create index if not exists idx_networth_movement_capa_r3613_status on public.networth_movement_capa_actions_r3613(capa_status);

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

  -- 16 SOCE movement rows
  insert into public.networth_movement_r3613 (
    organization_id, entity_name, entry_code, period_month,
    opening_equity_rupees, net_profit_rupees, dividends_paid_rupees, capital_raised_rupees,
    oci_movement_rupees, other_adjustments_rupees, closing_equity_rupees,
    net_worth_growth_pct, book_value_per_share_rupees, equity_status, trend_dir, notes
  )
  select v_org_id, q.ename, q.ecode, q.pmon::date,
    q.opeq::numeric, q.npft::numeric, q.divp::numeric, q.craise::numeric,
    q.ocim::numeric, q.othadj::numeric, q.cleq::numeric,
    q.gpct::numeric, q.bvps::numeric, q.estat, q.tdir, q.nt
  from (values
    ('EquipSeva Medical Devices Pvt Ltd','SOCE-EMD-2604','2026-04-01',
     120000000,18000000,6000000,0,500000,-200000,132300000,10.25,264.60,'strengthening','improving','FY-close carry-in; strong AMC + device sales, healthy retained earnings'),
    ('EquipSeva AMC Services','SOCE-AMC-2604','2026-04-01',
     45000000,7200000,2000000,0,100000,-50000,50250000,11.67,167.50,'strengthening','improving','AMC contracts business unit compounding on recurring revenue'),
    ('EquipSeva Spare Parts','SOCE-SPR-2604','2026-04-01',
     28000000,2100000,800000,0,0,0,29300000,4.64,146.50,'stable','stable','Spare-parts unit steady margins, modest reserve build'),
    ('EquipSeva Projects','SOCE-PRJ-2604','2026-04-01',
     60000000,-4500000,0,5000000,-300000,-200000,60000000,0.00,150.00,'stable','worsening','Turnkey projects unit operating loss offset by fresh capital'),
    ('EquipSeva Diagnostics','SOCE-DGN-2604','2026-04-01',
     35000000,-8200000,0,0,-400000,0,26400000,-24.57,105.60,'eroding','worsening','Diagnostics lab unit bleeding on underutilised imaging assets'),
    ('EquipSeva Rentals','SOCE-RNT-2604','2026-04-01',
     18000000,1200000,300000,0,0,0,18900000,5.00,126.00,'stable','stable','Equipment rentals unit thin but positive net worth accretion'),
    ('EquipSeva Medical Devices Pvt Ltd','SOCE-EMD-2605','2026-05-01',
     132300000,19500000,6000000,10000000,300000,0,156100000,17.99,283.82,'strengthening','improving','Rights issue capital of Rs 1 cr + strong quarter lift book value'),
    ('EquipSeva AMC Services','SOCE-AMC-2605','2026-05-01',
     50250000,6800000,2000000,0,-100000,0,54950000,9.35,183.17,'strengthening','improving','AMC unit continued equity build, minor OCI hedge drag'),
    ('EquipSeva Projects','SOCE-PRJ-2605','2026-05-01',
     60000000,-6800000,0,0,-500000,-300000,52400000,-12.67,131.00,'eroding','worsening','Projects unit WIP impairment; net worth eroding, no capital top-up'),
    ('EquipSeva Diagnostics','SOCE-DGN-2605','2026-05-01',
     26400000,-9500000,0,0,-600000,-400000,15900000,-39.77,63.60,'eroding','worsening','Diagnostics equity halved over quarter, capital plan required'),
    ('EquipSeva Rentals','SOCE-RNT-2605','2026-05-01',
     18900000,1400000,300000,0,0,0,20000000,5.82,133.33,'stable','improving','Rentals unit crosses Rs 2 cr equity, utilisation improving'),
    ('EquipSeva Medical Devices Pvt Ltd','SOCE-EMD-2606','2026-06-01',
     156100000,21000000,8000000,0,400000,-100000,169400000,8.52,308.00,'strengthening','stable','Flagship entity steady; higher dividend distribution moderated growth'),
    ('EquipSeva Projects','SOCE-PRJ-2606','2026-06-01',
     52400000,-12800000,0,0,-700000,-900000,38000000,-27.48,95.00,'eroding','worsening','Projects unit deepening losses on cost overruns, book value sub-100'),
    ('EquipSeva Diagnostics','SOCE-DGN-2606','2026-06-01',
     15900000,-11200000,0,0,-500000,-600000,3600000,-77.36,14.40,'depleted','worsening','Diagnostics equity near-depleted; urgent recapitalisation escalated'),
    ('EquipSeva Imaging Solutions','SOCE-IMG-2606','2026-06-01',
     8000000,-9500000,0,0,-300000,-400000,-2200000,-127.50,-22.00,'negative_networth','worsening','Imaging entity in negative net worth; board recap or wind-down decision'),
    ('EquipSeva Rentals','SOCE-RNT-2606','2026-06-01',
     20000000,-2200000,0,0,-200000,0,17600000,-12.00,117.33,'eroding','worsening','Rentals unit hit by fleet fair-value writedown this month')
  ) as q(ename, ecode, pmon, opeq, npft, divp, craise, ocim, othadj, cleq, gpct, bvps, estat, tdir, nt);

  -- CAPA seed — attach to specific movements via entry_code
  insert into public.networth_movement_capa_actions_r3613 (
    movement_id, finding_category, root_cause, corrective_action,
    capa_status, equity_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fcat, q.rcause, q.caction,
    q.cstat, q.eimp::numeric, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SOCE-DGN-2605','accumulated_losses','operating_losses','cost_restructuring','in_progress',9500000,'CFO - Ramesh Iyer','2026-06-15',null,'Diagnostics division cost restructuring underway to stem operating losses'),
    ('SOCE-DGN-2606','capital_erosion','operating_losses','raise_fresh_capital','open',12300000,'CFO - Ramesh Iyer','2026-07-10',null,'Diagnostics equity depleted — Rs 1.5 cr capital infusion plan before board'),
    ('SOCE-IMG-2606','negative_net_worth','operating_losses','board_capital_plan','escalated',10200000,'Founder - Anil Kapoor','2026-07-05',null,'Imaging entity negative net worth — escalated to board for recap or wind-down'),
    ('SOCE-PRJ-2606','accumulated_losses','impairment_charge','impairment_review','verification_pending',14400000,'Controller - Priya Nair','2026-06-30',null,'Projects WIP impairment review pending audit verification'),
    ('SOCE-EMD-2606','dividend_over_distribution','excess_dividend_payout','suspend_dividends','closed',8000000,'CFO - Ramesh Iyer','2026-06-20','2026-06-18','Dividend policy revised to retain earnings for growth capex'),
    ('SOCE-PRJ-2605','book_value_decline','operating_losses','cost_restructuring','overdue',7600000,'Controller - Priya Nair','2026-06-10',null,'Projects book value declining — restructuring past due date, escalate'),
    ('SOCE-RNT-2606','book_value_decline','fair_value_writedown','asset_revaluation','open',2400000,'Finance Mgr - Sunil Rao','2026-07-15',null,'Rental fleet fair-value writedown — independent revaluation scheduled'),
    ('SOCE-DGN-2604','oci_volatility','forex_translation_loss','hedge_forex_exposure','closed',400000,'Treasury - Meera Shah','2026-05-10','2026-05-08','Forex translation loss on imported analysers hedged going forward')
  ) as q(ecode, fcat, rcause, caction, cstat, eimp, ownr, tcd, acd, nt)
  join public.networth_movement_r3613 e
    on e.organization_id = v_org_id and e.entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Equity-status distribution
create or replace function public.founder_r3613_equity_status_rollup()
returns table(equity_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.networth_movement_r3613)
  select l.equity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.networth_movement_r3613 l
  group by l.equity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3613_equity_status_rollup() from public, anon;
grant execute on function public.founder_r3613_equity_status_rollup() to authenticated;

-- 2) Entity scorecard
create or replace function public.founder_r3613_entity_scorecard()
returns table(
  entity_name text,
  movements bigint,
  total_net_profit_rupees numeric,
  total_dividends_rupees numeric,
  total_capital_raised_rupees numeric,
  total_oci_rupees numeric,
  avg_growth_pct numeric,
  strengthening bigint,
  eroding_or_worse bigint
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
    coalesce(sum(l.net_profit_rupees),0)::numeric,
    coalesce(sum(l.dividends_paid_rupees),0)::numeric,
    coalesce(sum(l.capital_raised_rupees),0)::numeric,
    coalesce(sum(l.oci_movement_rupees),0)::numeric,
    round(avg(l.net_worth_growth_pct), 2),
    count(*) filter (where l.equity_status = 'strengthening')::bigint,
    count(*) filter (where l.equity_status in ('eroding','depleted','negative_networth'))::bigint
  from public.networth_movement_r3613 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3613_entity_scorecard() from public, anon;
grant execute on function public.founder_r3613_entity_scorecard() to authenticated;

-- 3) Entity × equity-status matrix
create or replace function public.founder_r3613_entity_status_matrix()
returns table(entity_name text, equity_status text, movements bigint, avg_growth_pct numeric, total_net_movement_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.equity_status, count(*)::bigint,
    round(avg(l.net_worth_growth_pct), 2),
    coalesce(sum(l.closing_equity_rupees - l.opening_equity_rupees),0)::numeric
  from public.networth_movement_r3613 l
  group by l.entity_name, l.equity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3613_entity_status_matrix() from public, anon;
grant execute on function public.founder_r3613_entity_status_matrix() to authenticated;

-- 4) Monthly net-worth trend
create or replace function public.founder_r3613_monthly_networth_trend()
returns table(
  period_month date,
  movements bigint,
  total_opening_equity_rupees numeric,
  total_closing_equity_rupees numeric,
  total_net_profit_rupees numeric,
  total_capital_raised_rupees numeric,
  avg_growth_pct numeric
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
    coalesce(sum(l.opening_equity_rupees),0)::numeric,
    coalesce(sum(l.closing_equity_rupees),0)::numeric,
    coalesce(sum(l.net_profit_rupees),0)::numeric,
    coalesce(sum(l.capital_raised_rupees),0)::numeric,
    round(avg(l.net_worth_growth_pct), 2)
  from public.networth_movement_r3613 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3613_monthly_networth_trend() from public, anon;
grant execute on function public.founder_r3613_monthly_networth_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3613_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.equity_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.networth_movement_capa_actions_r3613 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3613_capa_status_board() from public, anon;
grant execute on function public.founder_r3613_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3613_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.networth_movement_capa_actions_r3613)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.equity_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.networth_movement_capa_actions_r3613 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3613_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3613_root_cause_pareto() to authenticated;

-- 7) Equity-movement digest (by equity status)
create or replace function public.founder_r3613_equity_movement_digest()
returns table(
  equity_status text,
  entities bigint,
  total_opening_equity_rupees numeric,
  total_net_profit_rupees numeric,
  total_dividends_rupees numeric,
  total_capital_raised_rupees numeric,
  total_closing_equity_rupees numeric,
  total_net_movement_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equity_status,
    count(distinct l.entity_name)::bigint,
    coalesce(sum(l.opening_equity_rupees),0)::numeric,
    coalesce(sum(l.net_profit_rupees),0)::numeric,
    coalesce(sum(l.dividends_paid_rupees),0)::numeric,
    coalesce(sum(l.capital_raised_rupees),0)::numeric,
    coalesce(sum(l.closing_equity_rupees),0)::numeric,
    coalesce(sum(l.closing_equity_rupees - l.opening_equity_rupees),0)::numeric
  from public.networth_movement_r3613 l
  group by l.equity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3613_equity_movement_digest() from public, anon;
grant execute on function public.founder_r3613_equity_movement_digest() to authenticated;

-- 8) High-risk queue (depleted / negative net worth / worsening)
create or replace function public.founder_r3613_high_risk_queue()
returns table(
  entity_name text,
  entry_code text,
  period_month date,
  equity_status text,
  trend_dir text,
  closing_equity_rupees numeric,
  net_worth_growth_pct numeric,
  book_value_per_share_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.entry_code, l.period_month, l.equity_status, l.trend_dir,
    l.closing_equity_rupees, l.net_worth_growth_pct, l.book_value_per_share_rupees, l.notes
  from public.networth_movement_r3613 l
  where l.equity_status in ('depleted','negative_networth')
     or l.trend_dir = 'worsening'
     or l.net_worth_growth_pct < 0
     or l.closing_equity_rupees < 0
  order by l.period_month desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3613_high_risk_queue() from public, anon;
grant execute on function public.founder_r3613_high_risk_queue() to authenticated;
