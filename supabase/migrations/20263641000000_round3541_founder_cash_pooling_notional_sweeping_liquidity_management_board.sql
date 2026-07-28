-- Round 3541: Founder Cash-Pooling / Notional-Sweeping Liquidity-Management Board
-- Treasury cash pooling — entity-account × bank × pool type × balances × sweeps × pool contribution × interest benefit × idle cash × liquidity status × CAPA

-- =============================================================================
-- TABLE 1: cash_pooling_r3541 — per entity-account liquidity / sweep position
-- =============================================================================
create table if not exists public.cash_pooling_r3541 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_account text not null,
  bank_name text not null,
  pool_type text not null check (pool_type in (
    'physical_sweep','notional_pool','zba','target_balance','manual'
  )),
  account_balance_rupees numeric(16,2) not null,
  target_balance_rupees numeric(16,2) not null,
  swept_rupees numeric(16,2) not null,
  pool_contribution_rupees numeric(16,2) not null,
  interest_benefit_rupees numeric(16,2) not null,
  idle_cash_rupees numeric(16,2) not null,
  liquidity_status text not null check (liquidity_status in (
    'optimal','surplus','deficit','trapped','breach'
  )),
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cash_pooling_r3541 enable row level security;

create index if not exists idx_cash_pooling_r3541_org on public.cash_pooling_r3541(organization_id);
create index if not exists idx_cash_pooling_r3541_month on public.cash_pooling_r3541(period_month);
create index if not exists idx_cash_pooling_r3541_status on public.cash_pooling_r3541(liquidity_status);

-- =============================================================================
-- TABLE 2: cash_pooling_capa_actions_r3541 — CAPA & liquidity remediation
-- =============================================================================
create table if not exists public.cash_pooling_capa_actions_r3541 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  pool_ref_id uuid not null references public.cash_pooling_r3541(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'idle_cash_excess','trapped_liquidity','deficit_funding_gap','sweep_execution_failure',
    'target_balance_breach','fx_repatriation_block','notional_offset_shortfall','interest_leakage',
    'zba_config_error','manual_process_delay'
  )),
  root_cause text not null check (root_cause in (
    'bank_cutoff_missed','regulatory_repatriation_limit','fx_control_restriction','sweep_mandate_lapsed',
    'erp_bank_mapping_error','forecast_inaccuracy','manual_intervention_required','counterparty_limit_reached',
    'pending_investigation','holiday_calendar_mismatch'
  )),
  corrective_action text not null check (corrective_action in (
    'reconfigure_sweep_rule','renegotiate_bank_mandate','escalate_to_treasury','adjust_target_balance',
    'fix_erp_mapping','automate_zba_sweep','file_repatriation_request','rebalance_pool',
    'improve_forecast_model','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(16,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cash_pooling_capa_actions_r3541 enable row level security;

create index if not exists idx_cash_pooling_capa_r3541_ref on public.cash_pooling_capa_actions_r3541(pool_ref_id);
create index if not exists idx_cash_pooling_capa_r3541_status on public.cash_pooling_capa_actions_r3541(capa_status);

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

  -- 16 entity-account liquidity rows
  insert into public.cash_pooling_r3541 (
    organization_id, entity_account, bank_name, pool_type,
    account_balance_rupees, target_balance_rupees, swept_rupees, pool_contribution_rupees,
    interest_benefit_rupees, idle_cash_rupees, liquidity_status, period_month, notes
  )
  select v_org_id, q.ent, q.bnk, q.pt,
    q.abal, q.tbal, q.swp, q.pcon,
    q.ibn, q.idl, q.lst, q.pm::date, q.nt
  from (values
    ('EQS-MASTER-HDFC','HDFC Bank','physical_sweep',
     8500000,2000000,6500000,6500000,42000,0,'optimal','2026-07-01',
     'Group master concentration account — daily physical sweep to target'),
    ('EQS-CHENNAI-ICICI','ICICI Bank','zba',
     0,0,3200000,3200000,18000,0,'optimal','2026-07-01',
     'Chennai ops ZBA — fully swept to master nightly'),
    ('EQS-MUMBAI-AXIS','Axis Bank','physical_sweep',
     1500000,1000000,900000,900000,9500,500000,'surplus','2026-07-01',
     'Mumbai surplus above target — partial sweep executed'),
    ('EQS-DELHI-SBI','State Bank of India','target_balance',
     750000,1500000,0,0,0,0,'deficit','2026-07-01',
     'Delhi below target balance — funding required from pool'),
    ('EQS-BENGALURU-KOTAK','Kotak Mahindra Bank','notional_pool',
     4200000,0,0,4200000,31000,0,'optimal','2026-07-01',
     'Bengaluru notional pool leg — interest offset applied'),
    ('EQS-HYDERABAD-YES','Yes Bank','manual',
     2200000,500000,0,0,0,1700000,'trapped','2026-07-01',
     'Hyderabad idle balance trapped — manual sweep not run this cycle'),
    ('EQS-KOLKATA-INDUS','IndusInd Bank','zba',
     320000,0,280000,280000,3100,40000,'surplus','2026-07-01',
     'Kolkata ZBA residual balance above zero — bank cutoff missed'),
    ('EQS-PUNE-IDFC','IDFC First Bank','target_balance',
     1800000,1200000,600000,600000,7200,0,'optimal','2026-07-01',
     'Pune target-balance sweep on target'),
    ('EQS-EXPORT-HDFC','HDFC Bank','manual',
     5600000,0,0,0,0,5600000,'trapped','2026-07-01',
     'Export EEFC balance — FX repatriation pending, cash trapped'),
    ('EQS-MASTER-HDFC-JUN','HDFC Bank','physical_sweep',
     7800000,2000000,5800000,5800000,39000,0,'optimal','2026-06-01',
     'June master concentration — sweep nominal'),
    ('EQS-CHENNAI-ICICI-JUN','ICICI Bank','zba',
     0,0,2950000,2950000,16500,0,'optimal','2026-06-01',
     'June Chennai ZBA clean'),
    ('EQS-DELHI-SBI-JUN','State Bank of India','target_balance',
     400000,1500000,0,0,0,0,'breach','2026-06-01',
     'June Delhi overdraft breach — target-balance funding failed'),
    ('EQS-AHMEDABAD-AXIS','Axis Bank','notional_pool',
     2600000,0,0,2600000,19500,0,'surplus','2026-07-01',
     'Ahmedabad notional leg — surplus contribution to pool'),
    ('EQS-COIMBATORE-ICICI','ICICI Bank','manual',
     900000,700000,0,0,0,200000,'deficit','2026-07-01',
     'Coimbatore below working target after manual delay'),
    ('EQS-NAGPUR-KOTAK','Kotak Mahindra Bank','zba',
     150000,0,120000,120000,1400,30000,'surplus','2026-06-01',
     'Nagpur ZBA residual — small idle balance'),
    ('EQS-VENDOR-YES','Yes Bank','manual',
     3400000,0,0,0,0,3400000,'breach','2026-07-01',
     'Vendor escrow account — sweep mandate lapsed, full idle breach')
  ) as q(ent, bnk, pt, abal, tbal, swp, pcon, ibn, idl, lst, pm, nt);

  -- 8 CAPA rows — attach to specific accounts via entity_account
  insert into public.cash_pooling_capa_actions_r3541 (
    organization_id, pool_ref_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EQS-DELHI-SBI','deficit_funding_gap','forecast_inaccuracy','adjust_target_balance',
     'in_progress',750000,'Ramesh Iyer (Treasury)','2026-07-10',null,
     'Delhi funding gap — target rebalanced, awaiting pool transfer'),
    ('EQS-HYDERABAD-YES','trapped_liquidity','manual_intervention_required','automate_zba_sweep',
     'open',1700000,'Priya Nair (Cash Mgmt)','2026-07-12',null,
     'Automate Hyderabad sweep to eliminate manual miss'),
    ('EQS-EXPORT-HDFC','fx_repatriation_block','regulatory_repatriation_limit','file_repatriation_request',
     'escalated',5600000,'Anil Kumar (FX Desk)','2026-07-08',null,
     'EEFC repatriation filing with AD bank — RBI limit review'),
    ('EQS-DELHI-SBI-JUN','target_balance_breach','sweep_mandate_lapsed','renegotiate_bank_mandate',
     'closed',1100000,'Ramesh Iyer (Treasury)','2026-06-20','2026-06-18',
     'SBI intraday OD limit restored — mandate re-signed'),
    ('EQS-KOLKATA-INDUS','sweep_execution_failure','bank_cutoff_missed','reconfigure_sweep_rule',
     'verification_pending',40000,'Sunita Rao (Ops)','2026-07-09',null,
     'Kolkata ZBA cutoff advanced to 17:30 — verify next cycle'),
    ('EQS-VENDOR-YES','trapped_liquidity','sweep_mandate_lapsed','renegotiate_bank_mandate',
     'overdue',3400000,'Priya Nair (Cash Mgmt)','2026-07-05',null,
     'Vendor escrow sweep mandate lapsed — renewal overdue'),
    ('EQS-COIMBATORE-ICICI','deficit_funding_gap','manual_intervention_required','escalate_to_treasury',
     'open',200000,'Sunita Rao (Ops)','2026-07-11',null,
     'Coimbatore manual delay — escalate for standing instruction'),
    ('EQS-NAGPUR-KOTAK','interest_leakage','forecast_inaccuracy','improve_forecast_model',
     'in_progress',30000,'Anil Kumar (FX Desk)','2026-07-13',null,
     'Nagpur residual idle — improve short-term forecast')
  ) as q(ent, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.cash_pooling_r3541 e
    on e.organization_id = v_org_id and e.entity_account = q.ent;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Liquidity-status distribution
create or replace function public.founder_r3541_liquidity_status_rollup()
returns table(liquidity_status text, accounts bigint, total_balance_rupees numeric, total_idle_cash_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cash_pooling_r3541)
  select l.liquidity_status, count(*)::bigint,
    coalesce(sum(l.account_balance_rupees),0)::numeric,
    coalesce(sum(l.idle_cash_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cash_pooling_r3541 l
  group by l.liquidity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3541_liquidity_status_rollup() from public, anon;
grant execute on function public.founder_r3541_liquidity_status_rollup() to authenticated;

-- 2) Pool-type scorecard
create or replace function public.founder_r3541_pool_type_scorecard()
returns table(
  pool_type text,
  accounts bigint,
  optimal bigint,
  surplus bigint,
  at_risk bigint,
  total_swept_rupees numeric,
  total_interest_benefit_rupees numeric,
  total_idle_cash_rupees numeric,
  optimal_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pool_type,
    count(*)::bigint,
    count(*) filter (where l.liquidity_status = 'optimal')::bigint,
    count(*) filter (where l.liquidity_status = 'surplus')::bigint,
    count(*) filter (where l.liquidity_status in ('deficit','trapped','breach'))::bigint,
    coalesce(sum(l.swept_rupees),0)::numeric,
    coalesce(sum(l.interest_benefit_rupees),0)::numeric,
    coalesce(sum(l.idle_cash_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.liquidity_status = 'optimal')::numeric / nullif(count(*),0), 1)
  from public.cash_pooling_r3541 l
  group by l.pool_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3541_pool_type_scorecard() from public, anon;
grant execute on function public.founder_r3541_pool_type_scorecard() to authenticated;

-- 3) Pool-type × liquidity-status matrix
create or replace function public.founder_r3541_pool_type_status_matrix()
returns table(pool_type text, liquidity_status text, accounts bigint, total_balance_rupees numeric, total_idle_cash_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pool_type, l.liquidity_status, count(*)::bigint,
    coalesce(sum(l.account_balance_rupees),0)::numeric,
    coalesce(sum(l.idle_cash_rupees),0)::numeric
  from public.cash_pooling_r3541 l
  group by l.pool_type, l.liquidity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3541_pool_type_status_matrix() from public, anon;
grant execute on function public.founder_r3541_pool_type_status_matrix() to authenticated;

-- 4) Monthly sweep trend
create or replace function public.founder_r3541_monthly_sweep_trend()
returns table(
  period_month date,
  accounts bigint,
  total_swept_rupees numeric,
  total_pool_contribution_rupees numeric,
  total_interest_benefit_rupees numeric,
  total_idle_cash_rupees numeric
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
    coalesce(sum(l.swept_rupees),0)::numeric,
    coalesce(sum(l.pool_contribution_rupees),0)::numeric,
    coalesce(sum(l.interest_benefit_rupees),0)::numeric,
    coalesce(sum(l.idle_cash_rupees),0)::numeric
  from public.cash_pooling_r3541 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3541_monthly_sweep_trend() from public, anon;
grant execute on function public.founder_r3541_monthly_sweep_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3541_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.cash_pooling_capa_actions_r3541 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3541_capa_status_board() from public, anon;
grant execute on function public.founder_r3541_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3541_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cash_pooling_capa_actions_r3541)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cash_pooling_capa_actions_r3541 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3541_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3541_root_cause_pareto() to authenticated;

-- 7) Idle-cash impact digest (by bank)
create or replace function public.founder_r3541_idle_cash_impact_digest()
returns table(
  bank_name text,
  accounts bigint,
  total_idle_cash_rupees numeric,
  total_balance_rupees numeric,
  total_interest_benefit_rupees numeric,
  idle_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bank_name,
    count(*)::bigint,
    coalesce(sum(l.idle_cash_rupees),0)::numeric,
    coalesce(sum(l.account_balance_rupees),0)::numeric,
    coalesce(sum(l.interest_benefit_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.idle_cash_rupees),0)::numeric / nullif(sum(l.account_balance_rupees),0), 1)
  from public.cash_pooling_r3541 l
  group by l.bank_name
  order by coalesce(sum(l.idle_cash_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3541_idle_cash_impact_digest() from public, anon;
grant execute on function public.founder_r3541_idle_cash_impact_digest() to authenticated;

-- 8) High-risk liquidity queue (trapped / deficit / breach)
create or replace function public.founder_r3541_high_risk_queue()
returns table(
  entity_account text,
  bank_name text,
  pool_type text,
  liquidity_status text,
  account_balance_rupees numeric,
  target_balance_rupees numeric,
  idle_cash_rupees numeric,
  swept_rupees numeric,
  period_month date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_account, l.bank_name, l.pool_type, l.liquidity_status,
    l.account_balance_rupees, l.target_balance_rupees, l.idle_cash_rupees, l.swept_rupees,
    l.period_month, l.notes
  from public.cash_pooling_r3541 l
  where l.liquidity_status in ('deficit','trapped','breach')
     or l.idle_cash_rupees > 0
  order by l.idle_cash_rupees desc, l.period_month desc, l.entity_account;
end;
$$;

revoke execute on function public.founder_r3541_high_risk_queue() from public, anon;
grant execute on function public.founder_r3541_high_risk_queue() to authenticated;
