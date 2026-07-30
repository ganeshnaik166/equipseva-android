-- Round 3601: Founder Gross-to-Net Revenue Bridge / Discount-Leakage Board
-- Gross-to-net finance bridge — business unit × period × gross revenue → volume/promo discounts →
-- returns/rebates/price adjustments → net revenue → gross-to-net leakage % vs target × realization
-- status × trend × CAPA on discount-leakage drivers.

-- =============================================================================
-- TABLE 1: gross_to_net_r3601 — per-business-unit gross-to-net revenue bridge
-- =============================================================================
create table if not exists public.gross_to_net_r3601 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bridge_code text not null,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals',
    'consumables','refurbished_equipment','training'
  )),
  period_month date not null,
  gross_revenue_rupees numeric(14,2) not null,
  volume_discount_rupees numeric(14,2) not null,
  promotional_discount_rupees numeric(14,2) not null,
  returns_credits_rupees numeric(14,2) not null,
  rebates_rupees numeric(14,2) not null,
  price_adjustments_rupees numeric(14,2) not null,
  net_revenue_rupees numeric(14,2) not null,
  gross_to_net_leakage_pct numeric(6,2) not null,
  target_leakage_pct numeric(6,2) not null,
  realization_status text not null check (realization_status in (
    'strong','on_target','leaky','eroded'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gross_to_net_r3601 enable row level security;

create index if not exists idx_gross_to_net_r3601_org on public.gross_to_net_r3601(organization_id);
create index if not exists idx_gross_to_net_r3601_month on public.gross_to_net_r3601(period_month);
create index if not exists idx_gross_to_net_r3601_status on public.gross_to_net_r3601(realization_status);

-- =============================================================================
-- TABLE 2: gross_to_net_capa_actions_r3601 — discount-leakage CAPA actions
-- =============================================================================
create table if not exists public.gross_to_net_capa_actions_r3601 (
  id uuid primary key default gen_random_uuid(),
  bridge_log_id uuid not null references public.gross_to_net_r3601(id) on delete cascade,
  raised_at timestamptz not null default now(),
  leakage_driver text not null check (leakage_driver in (
    'excess_volume_discount','unauthorized_promo','high_return_rate','rebate_overaccrual',
    'price_override','margin_erosion','contract_noncompliance','billing_error'
  )),
  root_cause text not null check (root_cause in (
    'sales_discretion_abuse','promo_not_approved','quality_returns','contract_terms_misconfigured',
    'pricing_master_stale','competitive_pressure','manual_billing_error','rebate_accrual_error',
    'pending_investigation','fx_or_freight_passthrough'
  )),
  corrective_action text not null check (corrective_action in (
    'tighten_discount_approval','enforce_promo_policy','root_cause_returns','recalibrate_rebate_accrual',
    'update_pricing_master','renegotiate_contract','fix_billing_process','escalate_to_finance_committee',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_band text not null check (impact_band in (
    'critical','high','moderate','low','negligible'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  leakage_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gross_to_net_capa_actions_r3601 enable row level security;

create index if not exists idx_gross_to_net_capa_r3601_log on public.gross_to_net_capa_actions_r3601(bridge_log_id);
create index if not exists idx_gross_to_net_capa_r3601_status on public.gross_to_net_capa_actions_r3601(capa_status);

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

  -- 16 gross-to-net bridge rows
  insert into public.gross_to_net_r3601 (
    organization_id, bridge_code, business_unit, period_month,
    gross_revenue_rupees, volume_discount_rupees, promotional_discount_rupees,
    returns_credits_rupees, rebates_rupees, price_adjustments_rupees,
    net_revenue_rupees, gross_to_net_leakage_pct, target_leakage_pct,
    realization_status, trend_dir, notes
  )
  select v_org_id, q.bcode, q.bu, q.pm::date,
    q.gross, q.voldisc, q.promo,
    q.rets, q.rebate, q.priceadj,
    q.net, q.leak, q.tgt,
    q.rstat, q.trend, q.nt
  from (values
    ('GTN-AMC-2604','amc_services','2026-04-01',
     4850000,145000,60000,25000,40000,30000,4550000,6.19,6.00,'on_target','stable','AMC renewals — discount within band, slightly over target'),
    ('GTN-AMC-2605','amc_services','2026-05-01',
     5120000,128000,45000,18000,38000,22000,4869000,4.90,6.00,'strong','improving','AMC leakage improving after discount-approval tightening'),
    ('GTN-SPR-2604','spare_parts','2026-04-01',
     3260000,210000,130000,95000,55000,48000,2722000,16.50,9.00,'eroded','worsening','Spare-parts channel discount leakage far above target'),
    ('GTN-SPR-2605','spare_parts','2026-05-01',
     3410000,185000,90000,78000,52000,40000,2965000,13.05,9.00,'leaky','improving','Spare-parts leakage down but still above target'),
    ('GTN-PRJ-2604','projects','2026-04-01',
     12500000,620000,150000,40000,180000,210000,11300000,9.60,8.00,'leaky','stable','Turnkey project price adjustments eroding realization'),
    ('GTN-PRJ-2606','projects','2026-06-01',
     9800000,340000,90000,25000,120000,95000,9130000,6.84,8.00,'strong','improving','Project discount governance improving quarter on quarter'),
    ('GTN-DIA-2604','diagnostics','2026-04-01',
     2740000,96000,140000,62000,30000,25000,2387000,12.88,7.50,'eroded','worsening','Diagnostics promo overspend and returns spike'),
    ('GTN-DIA-2605','diagnostics','2026-05-01',
     2910000,88000,72000,45000,28000,20000,2657000,8.69,7.50,'leaky','improving','Diagnostics returns reduced after QC fix'),
    ('GTN-RNT-2604','rentals','2026-04-01',
     1680000,42000,18000,9000,15000,12000,1584000,5.71,6.50,'strong','stable','Rental fleet realization strong and stable'),
    ('GTN-RNT-2606','rentals','2026-06-01',
     1750000,55000,30000,14000,16000,18000,1617000,7.60,6.50,'leaky','worsening','Rental discounts creeping above target'),
    ('GTN-CNS-2604','consumables','2026-04-01',
     2200000,132000,88000,70000,44000,30000,1836000,16.55,10.00,'eroded','worsening','Consumables high return and rebate leakage'),
    ('GTN-CNS-2605','consumables','2026-05-01',
     2350000,118000,70000,52000,40000,26000,2044000,13.02,10.00,'leaky','improving','Consumables leakage improving after rebate recalibration'),
    ('GTN-RFB-2604','refurbished_equipment','2026-04-01',
     3900000,175000,60000,120000,65000,90000,3390000,13.08,9.50,'eroded','stable','Refurb returns and price adjustments elevated'),
    ('GTN-TRN-2605','training','2026-05-01',
     620000,12000,8000,3000,4000,2000,591000,4.68,6.00,'strong','stable','Training services minimal leakage'),
    ('GTN-AMC-2606','amc_services','2026-06-01',
     5340000,160000,95000,40000,55000,48000,4942000,7.45,6.00,'leaky','worsening','AMC leakage up on renewal-season discounting'),
    ('GTN-PRJ-2605','projects','2026-05-01',
     11200000,780000,220000,60000,260000,340000,9540000,14.82,8.00,'eroded','worsening','Large project heavy price concessions — realization eroded')
  ) as q(bcode, bu, pm, gross, voldisc, promo, rets, rebate, priceadj, net, leak, tgt, rstat, trend, nt);

  -- CAPA seed — attach to specific bridge rows via bridge_code
  insert into public.gross_to_net_capa_actions_r3601 (
    bridge_log_id, leakage_driver, root_cause, corrective_action,
    capa_status, impact_band, owner, target_closure_date, actual_closure_date,
    leakage_impact_rupees, notes
  )
  select e.id, q.driver, q.rc, q.ca,
    q.cst, q.band, q.ownr, q.tcd::date, q.acd::date,
    q.impact, q.nt
  from (values
    ('GTN-SPR-2604','excess_volume_discount','sales_discretion_abuse','tighten_discount_approval','in_progress','high','Rohan Mehta','2026-06-15',null,538000,'Spare-parts discount abuse — approval matrix being enforced'),
    ('GTN-DIA-2604','unauthorized_promo','promo_not_approved','enforce_promo_policy','open','high','Priya Nair','2026-06-20',null,353000,'Diagnostics promo run without finance sign-off'),
    ('GTN-CNS-2604','high_return_rate','quality_returns','root_cause_returns','escalated','critical','Anil Kumar','2026-06-10',null,364000,'Consumables returns leakage escalated to ops-quality'),
    ('GTN-PRJ-2605','price_override','competitive_pressure','renegotiate_contract','in_progress','critical','Sunita Rao','2026-06-30',null,1660000,'Large project heavy concessions — margin recovery plan'),
    ('GTN-RFB-2604','margin_erosion','pricing_master_stale','update_pricing_master','verification_pending','high','Vikram Shah','2026-06-12',null,510000,'Refurb pricing master refreshed — verifying realization'),
    ('GTN-PRJ-2604','price_override','contract_terms_misconfigured','renegotiate_contract','closed','moderate','Sunita Rao','2026-05-28','2026-05-25',1200000,'Project contract terms corrected and closed'),
    ('GTN-CNS-2605','rebate_overaccrual','rebate_accrual_error','recalibrate_rebate_accrual','overdue','moderate','Deepa Iyer','2026-06-05',null,306000,'Consumables rebate over-accrual correction past due'),
    ('GTN-RNT-2606','contract_noncompliance','competitive_pressure','escalate_to_finance_committee','open','moderate','Rohan Mehta','2026-07-01',null,133000,'Rental discount creep flagged to finance committee')
  ) as q(bcode, driver, rc, ca, cst, band, ownr, tcd, acd, impact, nt)
  join public.gross_to_net_r3601 e
    on e.organization_id = v_org_id and e.bridge_code = q.bcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Realization status distribution
create or replace function public.founder_r3601_realization_status_rollup()
returns table(realization_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gross_to_net_r3601)
  select l.realization_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gross_to_net_r3601 l
  group by l.realization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3601_realization_status_rollup() from public, anon;
grant execute on function public.founder_r3601_realization_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3601_business_unit_scorecard()
returns table(
  business_unit text,
  total_lines bigint,
  strong bigint,
  on_target bigint,
  leaky bigint,
  eroded bigint,
  gross_revenue_rupees numeric,
  net_revenue_rupees numeric,
  avg_leakage_pct numeric
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
    count(*) filter (where l.realization_status = 'strong')::bigint,
    count(*) filter (where l.realization_status = 'on_target')::bigint,
    count(*) filter (where l.realization_status = 'leaky')::bigint,
    count(*) filter (where l.realization_status = 'eroded')::bigint,
    coalesce(sum(l.gross_revenue_rupees),0)::numeric,
    coalesce(sum(l.net_revenue_rupees),0)::numeric,
    round(avg(l.gross_to_net_leakage_pct), 2)
  from public.gross_to_net_r3601 l
  group by l.business_unit
  order by coalesce(sum(l.gross_revenue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3601_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3601_business_unit_scorecard() to authenticated;

-- 3) Business-unit × realization-status matrix
create or replace function public.founder_r3601_bu_realization_matrix()
returns table(
  business_unit text,
  realization_status text,
  lines bigint,
  gross_revenue_rupees numeric,
  net_revenue_rupees numeric,
  avg_leakage_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.realization_status, count(*)::bigint,
    coalesce(sum(l.gross_revenue_rupees),0)::numeric,
    coalesce(sum(l.net_revenue_rupees),0)::numeric,
    round(avg(l.gross_to_net_leakage_pct), 2)
  from public.gross_to_net_r3601 l
  group by l.business_unit, l.realization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3601_bu_realization_matrix() from public, anon;
grant execute on function public.founder_r3601_bu_realization_matrix() to authenticated;

-- 4) Monthly leakage trend
create or replace function public.founder_r3601_monthly_leakage_trend()
returns table(
  period_month date,
  lines bigint,
  gross_revenue_rupees numeric,
  total_discounts_rupees numeric,
  net_revenue_rupees numeric,
  avg_leakage_pct numeric
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
    coalesce(sum(l.gross_revenue_rupees),0)::numeric,
    coalesce(sum(l.volume_discount_rupees + l.promotional_discount_rupees + l.returns_credits_rupees
      + l.rebates_rupees + l.price_adjustments_rupees),0)::numeric,
    coalesce(sum(l.net_revenue_rupees),0)::numeric,
    round(avg(l.gross_to_net_leakage_pct), 2)
  from public.gross_to_net_r3601 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3601_monthly_leakage_trend() from public, anon;
grant execute on function public.founder_r3601_monthly_leakage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3601_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.leakage_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.gross_to_net_capa_actions_r3601 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3601_capa_status_board() from public, anon;
grant execute on function public.founder_r3601_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3601_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gross_to_net_capa_actions_r3601)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.leakage_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gross_to_net_capa_actions_r3601 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3601_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3601_root_cause_pareto() to authenticated;

-- 7) Leakage-impact digest
create or replace function public.founder_r3601_leakage_impact_digest()
returns table(impact_band text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_band, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.leakage_impact_rupees),0)::numeric
  from public.gross_to_net_capa_actions_r3601 c
  group by c.impact_band
  order by coalesce(sum(c.leakage_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3601_leakage_impact_digest() from public, anon;
grant execute on function public.founder_r3601_leakage_impact_digest() to authenticated;

-- 8) High-risk (eroded/leaky) queue
create or replace function public.founder_r3601_high_risk_queue()
returns table(
  business_unit text,
  bridge_code text,
  period_month date,
  gross_revenue_rupees numeric,
  net_revenue_rupees numeric,
  gross_to_net_leakage_pct numeric,
  target_leakage_pct numeric,
  realization_status text,
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
  select l.business_unit, l.bridge_code, l.period_month,
    l.gross_revenue_rupees, l.net_revenue_rupees,
    l.gross_to_net_leakage_pct, l.target_leakage_pct,
    l.realization_status, l.trend_dir, l.notes
  from public.gross_to_net_r3601 l
  where l.realization_status in ('eroded','leaky')
     or l.gross_to_net_leakage_pct > l.target_leakage_pct
     or l.trend_dir = 'worsening'
  order by l.gross_to_net_leakage_pct desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3601_high_risk_queue() from public, anon;
grant execute on function public.founder_r3601_high_risk_queue() to authenticated;
