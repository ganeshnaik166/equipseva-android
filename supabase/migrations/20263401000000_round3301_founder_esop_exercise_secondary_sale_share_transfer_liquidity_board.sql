-- Round 3301: Founder ESOP Exercise, Secondary-Sale & Share-Transfer Liquidity Governance Board
-- Cap-table liquidity log — holder type × transaction type × options/shares × strike × 409A FMV × exercise cost × notional gain × TDS withholding × vesting × board approval × settlement × transaction verdict × CAPA

-- =============================================================================
-- TABLE 1: esop_liquidity_r3301 — individual exercise / secondary / transfer transactions
-- =============================================================================
create table if not exists public.esop_liquidity_r3301 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  holder_name text not null,
  transaction_ref text not null,
  holder_type text not null check (holder_type in (
    'current_employee','ex_employee','founder','angel','esop_pool','institutional'
  )),
  transaction_type text not null check (transaction_type in (
    'option_exercise','secondary_sale','share_transfer','buyback','cashless_exercise','lapse'
  )),
  transaction_date date not null,
  options_or_shares int not null,
  strike_price_rupees numeric(12,2) not null,
  fmv_409a_rupees numeric(12,2) not null,
  exercise_cost_rupees numeric(14,2),
  notional_gain_rupees numeric(14,2),
  tax_withholding_rupees numeric(14,2),
  vesting_status text not null check (vesting_status in (
    'fully_vested','partially_vested','unvested','accelerated'
  )),
  board_approval_status text not null check (board_approval_status in (
    'approved','pending','rejected','conditional'
  )),
  settlement_status text not null check (settlement_status in (
    'settled','in_progress','pending_funds','lapsed'
  )),
  transaction_verdict text not null check (transaction_verdict in (
    'completed','in_progress','blocked_compliance','expiring_window','lapsed_forfeited'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esop_liquidity_r3301 enable row level security;

create index if not exists idx_esop_liquidity_r3301_org on public.esop_liquidity_r3301(organization_id);
create index if not exists idx_esop_liquidity_r3301_date on public.esop_liquidity_r3301(transaction_date);
create index if not exists idx_esop_liquidity_r3301_verdict on public.esop_liquidity_r3301(transaction_verdict);

-- =============================================================================
-- TABLE 2: esop_liquidity_capa_actions_r3301 — approval / tax / settlement CAPA actions
-- =============================================================================
create table if not exists public.esop_liquidity_capa_actions_r3301 (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.esop_liquidity_r3301(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'board_approval_pending','tax_withholding_shortfall','settlement_funds_delay','exercise_window_expiring',
    '409a_valuation_stale','vesting_acceleration_review','share_transfer_documentation','buyback_compliance','rofr_waiver_pending'
  )),
  root_cause text not null check (root_cause in (
    'board_quorum_unavailable','tax_computation_error','buyer_funds_pending','employee_unresponsive',
    'valuation_report_expired','legal_documentation_gap','cap_table_mismatch','rofr_process_delay',
    'pending_investigation','regulatory_filing_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_board_resolution','recompute_tax_withholding','escrow_funds_confirm','extend_exercise_window',
    'commission_fresh_409a','execute_transfer_deed','file_regulatory_form','update_cap_table',
    'counsel_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'sebi_notifiable','rbi_fema_filing','income_tax_tds','none','internal_only','companies_act_roc'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esop_liquidity_capa_actions_r3301 enable row level security;

create index if not exists idx_esop_liquidity_capa_r3301_txn on public.esop_liquidity_capa_actions_r3301(transaction_id);
create index if not exists idx_esop_liquidity_capa_r3301_status on public.esop_liquidity_capa_actions_r3301(capa_status);

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

  -- 14 liquidity transaction rows
  insert into public.esop_liquidity_r3301 (
    organization_id, holder_name, transaction_ref, holder_type, transaction_type,
    transaction_date, options_or_shares, strike_price_rupees, fmv_409a_rupees,
    exercise_cost_rupees, notional_gain_rupees, tax_withholding_rupees,
    vesting_status, board_approval_status, settlement_status, transaction_verdict, notes
  )
  select v_org_id, q.hn, q.tref, q.ht, q.tt,
    q.td::date, q.oos, q.strike, q.fmv,
    q.exc, q.ngain, q.tax,
    q.vs, q.bas, q.ss, q.tv, q.nt
  from (values
    ('Rohan Mehta','TXN-ESOP-1001','current_employee','option_exercise','2026-07-02',
     4000,10.00,340.00,40000.00,1320000.00,396000.00,
     'fully_vested','approved','settled','completed','FY26 exercise window — perquisite TDS remitted on time'),
    ('Ananya Iyer','TXN-ESOP-1002','current_employee','cashless_exercise','2026-07-01',
     2500,10.00,340.00,25000.00,825000.00,247500.00,
     'fully_vested','approved','settled','completed','Cashless exercise — broker sold to cover strike and TDS'),
    ('Vikram Nair','TXN-ESOP-1003','ex_employee','option_exercise','2026-06-30',
     6000,10.00,340.00,60000.00,1980000.00,594000.00,
     'fully_vested','approved','pending_funds','expiring_window','90-day post-exit window closes 2026-07-15 — exercise funds pending'),
    ('Priya Raghavan','TXN-ESOP-1004','ex_employee','lapse','2026-06-29',
     3000,10.00,340.00,null,null,null,
     'unvested','pending','lapsed','lapsed_forfeited','Unvested options lapsed on resignation — no exercise elected'),
    ('Karthik Subramanian','TXN-ESOP-1005','current_employee','option_exercise','2026-06-28',
     5000,85.00,512.00,425000.00,2135000.00,640500.00,
     'partially_vested','conditional','in_progress','blocked_compliance','Board nod conditional on fresh 409A — TDS on hold pending valuation'),
    ('Deepa Krishnan','TXN-ESOP-1006','current_employee','option_exercise','2026-06-27',
     1500,85.00,512.00,127500.00,640500.00,192150.00,
     'fully_vested','approved','settled','completed','Routine vested exercise settled T+2'),
    ('Sundar Balaji','TXN-ESOP-1007','founder','secondary_sale','2026-06-26',
     20000,0.00,512.00,0.00,10240000.00,1049600.00,
     'fully_vested','approved','settled','completed','Founder secondary to incoming Series-B lead — LTCG treatment'),
    ('Meenakshi Ventures LLP','TXN-ESOP-1008','angel','secondary_sale','2026-06-25',
     15000,0.00,512.00,0.00,7680000.00,786000.00,
     'fully_vested','approved','in_progress','in_progress','Angel partial exit — RoFR waiver circulation in progress'),
    ('Aravind Menon','TXN-ESOP-1009','ex_employee','share_transfer','2026-06-24',
     4000,10.00,340.00,40000.00,1320000.00,0.00,
     'fully_vested','pending','pending_funds','blocked_compliance','Transfer deed and RoFR waiver pending board resolution'),
    ('Nikhil Deshpande','TXN-ESOP-1010','current_employee','option_exercise','2026-06-23',
     3500,85.00,512.00,297500.00,1494500.00,448350.00,
     'accelerated','approved','settled','completed','Accelerated vest on promotion — exercised in full'),
    ('Sequoia Surge Fund II','TXN-ESOP-1011','institutional','secondary_sale','2026-06-22',
     30000,0.00,512.00,0.00,15360000.00,1572000.00,
     'fully_vested','approved','settled','completed','Institutional secondary at 409A — FEMA filing completed'),
    ('Lakshmi Narayan','TXN-ESOP-1012','current_employee','cashless_exercise','2026-06-21',
     2000,85.00,512.00,170000.00,854000.00,256200.00,
     'partially_vested','conditional','in_progress','in_progress','Cashless exercise — awaiting broker settlement confirmation'),
    ('ESOP Pool 2024 Trust','TXN-ESOP-1013','esop_pool','buyback','2026-06-20',
     8000,10.00,340.00,80000.00,2640000.00,264000.00,
     'fully_vested','approved','settled','completed','Company buyback of surrendered vested pool shares at 409A'),
    ('Farhan Qureshi','TXN-ESOP-1014','ex_employee','option_exercise','2026-06-19',
     4500,10.00,340.00,45000.00,1485000.00,445500.00,
     'fully_vested','pending','pending_funds','expiring_window','Exit exercise window closes 2026-07-05 — reminder sent to holder')
  ) as q(hn, tref, ht, tt, td, oos, strike, fmv, exc, ngain, tax, vs, bas, ss, tv, nt);

  -- CAPA seed — attach to specific transactions via transaction_ref
  insert into public.esop_liquidity_capa_actions_r3301 (
    transaction_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TXN-ESOP-1005','board_approval_pending','valuation_report_expired','commission_fresh_409a','in_progress','sebi_notifiable','2026-07-10',null,150000.00,'Fresh 409A commissioned before board can clear the exercise'),
    ('TXN-ESOP-1003','exercise_window_expiring','buyer_funds_pending','extend_exercise_window','escalated','income_tax_tds','2026-07-14',null,0.00,'Ex-employee 90-day window nearly closed — 15-day extension requested'),
    ('TXN-ESOP-1009','share_transfer_documentation','legal_documentation_gap','execute_transfer_deed','open','companies_act_roc','2026-07-12',null,35000.00,'Transfer deed drafting and RoFR waiver pending counsel review'),
    ('TXN-ESOP-1008','rofr_waiver_pending','rofr_process_delay','counsel_review','in_progress','sebi_notifiable','2026-07-09',null,25000.00,'Angel secondary held pending RoFR waiver circulation to board'),
    ('TXN-ESOP-1004','vesting_acceleration_review','employee_unresponsive','none_required','closed','internal_only','2026-06-30','2026-06-30',0.00,'Unvested lapse confirmed — no action, cap table updated'),
    ('TXN-ESOP-1014','tax_withholding_shortfall','tax_computation_error','recompute_tax_withholding','overdue','income_tax_tds','2026-07-01',null,12000.00,'Perquisite TDS recomputed on corrected FMV — closure past due')
  ) as q(tref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.esop_liquidity_r3301 e
    on e.organization_id = v_org_id and e.transaction_ref = q.tref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Transaction verdict distribution
create or replace function public.founder_r3301_transaction_verdict_rollup()
returns table(transaction_verdict text, transactions bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esop_liquidity_r3301)
  select l.transaction_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.esop_liquidity_r3301 l
  group by l.transaction_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3301_transaction_verdict_rollup() from public, anon;
grant execute on function public.founder_r3301_transaction_verdict_rollup() to authenticated;

-- 2) Holder-type liquidity scorecard
create or replace function public.founder_r3301_holder_scorecard()
returns table(
  holder_type text,
  total_transactions bigint,
  completed bigint,
  in_progress bigint,
  blocked bigint,
  expiring bigint,
  lapsed bigint,
  total_notional_gain_rupees numeric,
  completed_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.holder_type,
    count(*)::bigint,
    count(*) filter (where l.transaction_verdict = 'completed')::bigint,
    count(*) filter (where l.transaction_verdict = 'in_progress')::bigint,
    count(*) filter (where l.transaction_verdict = 'blocked_compliance')::bigint,
    count(*) filter (where l.transaction_verdict = 'expiring_window')::bigint,
    count(*) filter (where l.transaction_verdict = 'lapsed_forfeited')::bigint,
    coalesce(sum(l.notional_gain_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.transaction_verdict = 'completed')::numeric / nullif(count(*),0), 1)
  from public.esop_liquidity_r3301 l
  group by l.holder_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3301_holder_scorecard() from public, anon;
grant execute on function public.founder_r3301_holder_scorecard() to authenticated;

-- 3) Holder-type × transaction-type matrix
create or replace function public.founder_r3301_holder_transaction_matrix()
returns table(holder_type text, transaction_type text, transactions bigint, completed bigint, avg_notional_gain_rupees numeric, avg_tax_withholding_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.holder_type, l.transaction_type, count(*)::bigint,
    count(*) filter (where l.transaction_verdict = 'completed')::bigint,
    round(avg(l.notional_gain_rupees), 0),
    round(avg(l.tax_withholding_rupees), 0)
  from public.esop_liquidity_r3301 l
  group by l.holder_type, l.transaction_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3301_holder_transaction_matrix() from public, anon;
grant execute on function public.founder_r3301_holder_transaction_matrix() to authenticated;

-- 4) Daily transaction trend
create or replace function public.founder_r3301_daily_transaction_trend()
returns table(transaction_date date, transactions bigint, completed bigint, blocked bigint, expiring bigint, total_notional_gain_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.transaction_date,
    count(*)::bigint,
    count(*) filter (where l.transaction_verdict = 'completed')::bigint,
    count(*) filter (where l.transaction_verdict = 'blocked_compliance')::bigint,
    count(*) filter (where l.transaction_verdict = 'expiring_window')::bigint,
    coalesce(sum(l.notional_gain_rupees),0)::numeric
  from public.esop_liquidity_r3301 l
  group by l.transaction_date
  order by l.transaction_date desc;
end;
$$;

revoke execute on function public.founder_r3301_daily_transaction_trend() from public, anon;
grant execute on function public.founder_r3301_daily_transaction_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3301_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.esop_liquidity_capa_actions_r3301 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3301_capa_status_board() from public, anon;
grant execute on function public.founder_r3301_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3301_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esop_liquidity_capa_actions_r3301)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.esop_liquidity_capa_actions_r3301 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3301_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3301_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3301_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.esop_liquidity_capa_actions_r3301 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3301_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3301_regulatory_impact_digest() to authenticated;

-- 8) High-risk liquidity queue (top individual concerns)
create or replace function public.founder_r3301_high_risk_queue()
returns table(
  holder_name text,
  holder_type text,
  transaction_type text,
  transaction_date date,
  transaction_verdict text,
  board_approval_status text,
  settlement_status text,
  vesting_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.holder_name, l.holder_type, l.transaction_type, l.transaction_date,
    l.transaction_verdict, l.board_approval_status, l.settlement_status,
    l.vesting_status, l.notes
  from public.esop_liquidity_r3301 l
  where l.transaction_verdict in ('in_progress','blocked_compliance','expiring_window','lapsed_forfeited')
     or l.board_approval_status in ('pending','conditional','rejected')
     or l.settlement_status in ('pending_funds','lapsed')
  order by l.transaction_date desc, l.holder_name;
end;
$$;

revoke execute on function public.founder_r3301_high_risk_queue() from public, anon;
grant execute on function public.founder_r3301_high_risk_queue() to authenticated;
