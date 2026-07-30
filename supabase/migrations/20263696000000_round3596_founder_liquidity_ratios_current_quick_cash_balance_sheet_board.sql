-- Round 3596: Founder Liquidity Ratios (Current / Quick / Cash) Balance-Sheet Board
-- Founder finance — per business-unit balance-sheet liquidity: current/quick/cash ratios × targets ×
-- liquidity status × trend × root-cause pareto × liquidity-impact digest × high-risk queue × CAPA

-- =============================================================================
-- TABLE 1: liquidity_ratios_r3596 — per business-unit monthly liquidity snapshot
-- =============================================================================
create table if not exists public.liquidity_ratios_r3596 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  snapshot_ref text not null,
  business_unit text not null,
  period_month date not null,
  current_assets_rupees numeric(16,2) not null,
  current_liabilities_rupees numeric(16,2) not null,
  inventory_rupees numeric(16,2) not null,
  cash_and_equivalents_rupees numeric(16,2) not null,
  current_ratio numeric(8,2) not null,
  quick_ratio numeric(8,2) not null,
  cash_ratio numeric(8,2) not null,
  target_current_ratio numeric(8,2) not null,
  liquidity_status text not null check (liquidity_status in (
    'strong','adequate','tight','stressed','distressed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.liquidity_ratios_r3596 enable row level security;

create index if not exists idx_liquidity_ratios_r3596_org on public.liquidity_ratios_r3596(organization_id);
create index if not exists idx_liquidity_ratios_r3596_month on public.liquidity_ratios_r3596(period_month);
create index if not exists idx_liquidity_ratios_r3596_status on public.liquidity_ratios_r3596(liquidity_status);

-- =============================================================================
-- TABLE 2: liquidity_ratios_capa_actions_r3596 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.liquidity_ratios_capa_actions_r3596 (
  id uuid primary key default gen_random_uuid(),
  ratio_id uuid not null references public.liquidity_ratios_r3596(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'current_ratio_below_target','quick_ratio_weak','cash_ratio_low','inventory_overhang',
    'receivables_buildup','payables_spike','working_capital_negative','covenant_breach_risk'
  )),
  root_cause text not null check (root_cause in (
    'slow_receivables_collection','excess_inventory','short_term_debt_spike','delayed_customer_payments',
    'capex_overrun','seasonal_demand_dip','vendor_terms_tightened','revenue_shortfall','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'accelerate_collections','liquidate_excess_inventory','refinance_short_term_debt','negotiate_vendor_terms',
    'draw_working_capital_line','defer_capex','equity_infusion','none_required'
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

alter table public.liquidity_ratios_capa_actions_r3596 enable row level security;

create index if not exists idx_liquidity_ratios_capa_r3596_ratio on public.liquidity_ratios_capa_actions_r3596(ratio_id);
create index if not exists idx_liquidity_ratios_capa_r3596_status on public.liquidity_ratios_capa_actions_r3596(capa_status);

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

  -- 16 monthly liquidity snapshots across 6 business units
  insert into public.liquidity_ratios_r3596 (
    organization_id, snapshot_ref, business_unit, period_month,
    current_assets_rupees, current_liabilities_rupees, inventory_rupees, cash_and_equivalents_rupees,
    current_ratio, quick_ratio, cash_ratio, target_current_ratio,
    liquidity_status, trend_dir, notes
  )
  select v_org_id, q.sref, q.bu, q.pm::date,
    q.ca, q.cl, q.inv, q.cash,
    q.cr, q.qr, q.cshr, q.tcr,
    q.ls, q.td, q.nt
  from (values
    ('LQ-DIAG-202605','Diagnostics Imaging','2026-05-01',
     48000000,20000000,9000000,12000000, 2.40,1.95,0.60,2.00,'strong','stable','CR 2.40 comfortably above 2.0 target'),
    ('LQ-DIAG-202606','Diagnostics Imaging','2026-06-01',
     46000000,21000000,9500000,11000000, 2.19,1.74,0.52,2.00,'strong','worsening','Liabilities creeping up; still strong'),
    ('LQ-DIAG-202607','Diagnostics Imaging','2026-07-01',
     44000000,22000000,10000000,9000000, 2.00,1.55,0.41,2.00,'strong','worsening','CR exactly at 2.0 target; cash ratio softening'),
    ('LQ-BIOM-202605','Biomedical Services','2026-05-01',
     32000000,18000000,6000000,8000000, 1.78,1.44,0.44,1.60,'adequate','improving','AMC receivables collection improving'),
    ('LQ-BIOM-202606','Biomedical Services','2026-06-01',
     30000000,18500000,6500000,7000000, 1.62,1.27,0.38,1.60,'adequate','stable','Holding just above 1.6 target'),
    ('LQ-BIOM-202607','Biomedical Services','2026-07-01',
     28000000,19000000,7000000,6000000, 1.47,1.11,0.32,1.60,'tight','worsening','CR fell below 1.6 target — collections lag'),
    ('LQ-SPRT-202606','Spare Parts Trading','2026-06-01',
     24000000,17000000,11000000,3000000, 1.41,0.76,0.18,1.50,'tight','stable','Heavy inventory drags quick ratio to 0.76'),
    ('LQ-SPRT-202607','Spare Parts Trading','2026-07-01',
     22000000,18000000,12000000,2500000, 1.22,0.56,0.14,1.50,'tight','worsening','Inventory overhang; quick ratio 0.56'),
    ('LQ-RENT-202606','Equipment Rental Fleet','2026-06-01',
     18000000,16000000,2000000,4000000, 1.13,1.00,0.25,1.30,'stressed','worsening','CR 1.13 below 1.3 target; lease receivables slow'),
    ('LQ-RENT-202607','Equipment Rental Fleet','2026-07-01',
     17000000,16500000,2200000,3500000, 1.03,0.90,0.21,1.30,'stressed','worsening','CR 1.03 — near covenant floor'),
    ('LQ-CONS-202605','Consumables Distribution','2026-05-01',
     24000000,15500000,8500000,5000000, 1.55,1.00,0.32,1.50,'adequate','stable','Above 1.5 target'),
    ('LQ-CONS-202606','Consumables Distribution','2026-06-01',
     26000000,15000000,8000000,6000000, 1.73,1.20,0.40,1.50,'adequate','improving','Working capital improving on faster turns'),
    ('LQ-CONS-202607','Consumables Distribution','2026-07-01',
     27000000,14500000,7800000,6500000, 1.86,1.32,0.45,1.50,'adequate','improving','Best liquidity in the unit this quarter'),
    ('LQ-TRNK-202605','Turnkey Projects','2026-05-01',
     40000000,38000000,5000000,6000000, 1.05,0.92,0.16,1.40,'stressed','stable','Project milestone billing lumpy; CR 1.05'),
    ('LQ-TRNK-202606','Turnkey Projects','2026-06-01',
     42000000,44000000,6000000,5000000, 0.95,0.82,0.11,1.40,'distressed','worsening','Negative working capital; CR below 1.0'),
    ('LQ-TRNK-202607','Turnkey Projects','2026-07-01',
     45000000,50000000,7000000,4000000, 0.90,0.76,0.08,1.40,'distressed','worsening','CR 0.90 — equity infusion approved by board')
  ) as q(sref, bu, pm, ca, cl, inv, cash, cr, qr, cshr, tcr, ls, td, nt);

  -- CAPA seed — attach to specific snapshots via snapshot_ref
  insert into public.liquidity_ratios_capa_actions_r3596 (
    ratio_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca_act,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('LQ-TRNK-202607','current_ratio_below_target','revenue_shortfall','equity_infusion','escalated',
     8000000,'CFO','2026-08-31',null,'Turnkey CR 0.90 vs 1.40 target — board approved equity infusion'),
    ('LQ-TRNK-202606','working_capital_negative','capex_overrun','refinance_short_term_debt','in_progress',
     5000000,'Treasury Lead','2026-08-15',null,'Negative working capital — refinancing project loans to term'),
    ('LQ-RENT-202607','cash_ratio_low','delayed_customer_payments','accelerate_collections','open',
     2500000,'Collections Manager','2026-08-20',null,'Rental cash ratio 0.21 — chasing overdue lease invoices'),
    ('LQ-SPRT-202607','inventory_overhang','excess_inventory','liquidate_excess_inventory','in_progress',
     3500000,'Inventory Head','2026-08-10',null,'Spare-parts quick ratio 0.56 — liquidating slow-moving stock'),
    ('LQ-BIOM-202607','current_ratio_below_target','slow_receivables_collection','accelerate_collections','verification_pending',
     1800000,'AMC Ops Lead','2026-07-31',null,'Biomedical CR 1.47 — collections drive underway, verifying impact'),
    ('LQ-RENT-202606','covenant_breach_risk','short_term_debt_spike','draw_working_capital_line','closed',
     1200000,'Treasury Lead','2026-07-15','2026-07-12','Drew WC line to cover short-term debt — covenant maintained'),
    ('LQ-SPRT-202606','receivables_buildup','delayed_customer_payments','negotiate_vendor_terms','overdue',
     900000,'Credit Controller','2026-07-20',null,'Receivables build-up — vendor term renegotiation past due'),
    ('LQ-TRNK-202605','payables_spike','vendor_terms_tightened','negotiate_vendor_terms','closed',
     700000,'Procurement Lead','2026-06-30','2026-06-25','Vendor terms tightened — renegotiated 60-day terms restored')
  ) as q(sref, fc, rc, ca_act, cst, imp, ownr, tcd, acd, nt)
  join public.liquidity_ratios_r3596 e
    on e.organization_id = v_org_id and e.snapshot_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Liquidity status distribution
create or replace function public.founder_r3596_liquidity_status_rollup()
returns table(liquidity_status text, snapshots bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.liquidity_ratios_r3596)
  select l.liquidity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.liquidity_ratios_r3596 l
  group by l.liquidity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3596_liquidity_status_rollup() from public, anon;
grant execute on function public.founder_r3596_liquidity_status_rollup() to authenticated;

-- 2) Business-unit liquidity scorecard
create or replace function public.founder_r3596_business_unit_scorecard()
returns table(
  business_unit text,
  snapshots bigint,
  avg_current_ratio numeric,
  avg_quick_ratio numeric,
  avg_cash_ratio numeric,
  worst_current_ratio numeric,
  below_target bigint,
  stressed_count bigint
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
    round(avg(l.current_ratio), 2),
    round(avg(l.quick_ratio), 2),
    round(avg(l.cash_ratio), 2),
    round(min(l.current_ratio), 2),
    count(*) filter (where l.current_ratio < l.target_current_ratio)::bigint,
    count(*) filter (where l.liquidity_status in ('stressed','distressed'))::bigint
  from public.liquidity_ratios_r3596 l
  group by l.business_unit
  order by avg(l.current_ratio) asc;
end;
$$;

revoke execute on function public.founder_r3596_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3596_business_unit_scorecard() to authenticated;

-- 3) Business-unit × liquidity-status matrix
create or replace function public.founder_r3596_business_unit_status_matrix()
returns table(business_unit text, liquidity_status text, snapshots bigint, avg_current_ratio numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.liquidity_status, count(*)::bigint,
    round(avg(l.current_ratio), 2)
  from public.liquidity_ratios_r3596 l
  group by l.business_unit, l.liquidity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3596_business_unit_status_matrix() from public, anon;
grant execute on function public.founder_r3596_business_unit_status_matrix() to authenticated;

-- 4) Monthly current-ratio trend
create or replace function public.founder_r3596_monthly_current_ratio_trend()
returns table(
  period_month date,
  snapshots bigint,
  avg_current_ratio numeric,
  avg_quick_ratio numeric,
  avg_cash_ratio numeric,
  stressed_count bigint
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
    round(avg(l.current_ratio), 2),
    round(avg(l.quick_ratio), 2),
    round(avg(l.cash_ratio), 2),
    count(*) filter (where l.liquidity_status in ('stressed','distressed'))::bigint
  from public.liquidity_ratios_r3596 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3596_monthly_current_ratio_trend() from public, anon;
grant execute on function public.founder_r3596_monthly_current_ratio_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3596_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.liquidity_ratios_capa_actions_r3596 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3596_capa_status_board() from public, anon;
grant execute on function public.founder_r3596_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3596_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.liquidity_ratios_capa_actions_r3596)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.liquidity_ratios_capa_actions_r3596 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3596_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3596_root_cause_pareto() to authenticated;

-- 7) Liquidity-impact digest (by liquidity status)
create or replace function public.founder_r3596_liquidity_impact_digest()
returns table(
  liquidity_status text,
  snapshots bigint,
  total_current_assets_rupees numeric,
  total_current_liabilities_rupees numeric,
  net_working_capital_rupees numeric,
  total_cash_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.liquidity_status,
    count(*)::bigint,
    coalesce(sum(l.current_assets_rupees),0)::numeric,
    coalesce(sum(l.current_liabilities_rupees),0)::numeric,
    coalesce(sum(l.current_assets_rupees) - sum(l.current_liabilities_rupees),0)::numeric,
    coalesce(sum(l.cash_and_equivalents_rupees),0)::numeric
  from public.liquidity_ratios_r3596 l
  group by l.liquidity_status
  order by coalesce(sum(l.current_assets_rupees) - sum(l.current_liabilities_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3596_liquidity_impact_digest() from public, anon;
grant execute on function public.founder_r3596_liquidity_impact_digest() to authenticated;

-- 8) High-risk (stressed / distressed) queue
create or replace function public.founder_r3596_high_risk_queue()
returns table(
  business_unit text,
  period_month date,
  current_ratio numeric,
  quick_ratio numeric,
  cash_ratio numeric,
  target_current_ratio numeric,
  liquidity_status text,
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
  select l.business_unit, l.period_month, l.current_ratio, l.quick_ratio, l.cash_ratio,
    l.target_current_ratio, l.liquidity_status, l.trend_dir, l.notes
  from public.liquidity_ratios_r3596 l
  where l.liquidity_status in ('tight','stressed','distressed')
     or l.current_ratio < l.target_current_ratio
     or l.trend_dir = 'worsening'
  order by l.current_ratio asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3596_high_risk_queue() from public, anon;
grant execute on function public.founder_r3596_high_risk_queue() to authenticated;
