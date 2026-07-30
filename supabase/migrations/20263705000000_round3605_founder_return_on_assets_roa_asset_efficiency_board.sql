-- Round 3605: Founder Return-on-Assets (ROA) / Asset-Efficiency Board
-- Founder finance QA — business unit × period × net profit × total/avg assets × ROA vs target ×
-- asset turnover × net margin × idle-asset % × revenue-per-asset-rupee × efficiency status × trend × CAPA

-- =============================================================================
-- TABLE 1: roa_board_r3605 — per-BU per-month return-on-assets / asset-efficiency facts
-- =============================================================================
create table if not exists public.roa_board_r3605 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_code text not null,
  business_unit text not null,
  period_month date not null,
  net_profit_rupees numeric(14,2),
  total_assets_rupees numeric(14,2),
  avg_assets_rupees numeric(14,2),
  roa_pct numeric(6,2),
  target_roa_pct numeric(6,2),
  asset_turnover_ratio numeric(6,2),
  net_margin_pct numeric(6,2),
  idle_asset_pct numeric(6,2),
  revenue_per_asset_rupee numeric(8,2),
  efficiency_status text not null check (efficiency_status in (
    'high','on_target','below_target','underutilized'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roa_board_r3605 enable row level security;

create index if not exists idx_roa_board_r3605_org on public.roa_board_r3605(organization_id);
create index if not exists idx_roa_board_r3605_month on public.roa_board_r3605(period_month);
create index if not exists idx_roa_board_r3605_status on public.roa_board_r3605(efficiency_status);

-- =============================================================================
-- TABLE 2: roa_board_capa_actions_r3605 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.roa_board_capa_actions_r3605 (
  id uuid primary key default gen_random_uuid(),
  roa_entry_id uuid not null references public.roa_board_r3605(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'roa_below_target','high_idle_assets','low_asset_turnover','margin_compression',
    'revenue_per_asset_decline','asset_impairment','capex_underutilization','depreciation_overrun'
  )),
  root_cause text not null check (root_cause in (
    'idle_equipment_inventory','overinvested_capex','pricing_pressure','low_utilization_rentals',
    'slow_moving_spares','project_cost_overrun','demand_shortfall','aging_asset_base','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'redeploy_idle_assets','liquidate_surplus_inventory','reprice_service_contracts',
    'increase_rental_utilization','divest_underperforming_assets','optimize_capex_plan',
    'accelerate_spare_turnover','renegotiate_vendor_terms','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  profit_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roa_board_capa_actions_r3605 enable row level security;

create index if not exists idx_roa_board_capa_r3605_entry on public.roa_board_capa_actions_r3605(roa_entry_id);
create index if not exists idx_roa_board_capa_r3605_status on public.roa_board_capa_actions_r3605(capa_status);

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

  -- 16 ROA / asset-efficiency rows
  insert into public.roa_board_r3605 (
    organization_id, entry_code, business_unit, period_month,
    net_profit_rupees, total_assets_rupees, avg_assets_rupees,
    roa_pct, target_roa_pct, asset_turnover_ratio, net_margin_pct,
    idle_asset_pct, revenue_per_asset_rupee, efficiency_status, trend_dir, notes
  )
  select v_org_id, q.ecode, q.bu, q.pmonth::date,
    q.nprofit, q.tassets, q.aassets,
    q.roa, q.troa, q.aturn, q.nmargin,
    q.idle, q.rpa, q.estat, q.tdir, q.nt
  from (values
    ('ROA-AMC-2607','amc_services','2026-07-01',
     1850000,9000000,8800000,21.0,18.0,1.9,11.0,6.0,1.90,'high','improving','AMC services high ROA — asset-light recurring revenue'),
    ('ROA-SPR-2607','spare_parts','2026-07-01',
     920000,7200000,7000000,13.1,14.0,1.2,8.0,18.0,1.20,'below_target','worsening','Spare-parts ROA below target — slow-moving inventory drag'),
    ('ROA-PRJ-2607','projects','2026-07-01',
     1400000,15000000,14500000,9.7,12.0,0.8,6.5,9.0,0.80,'below_target','stable','Turnkey projects capital-heavy — ROA under target'),
    ('ROA-DIA-2607','diagnostics','2026-07-01',
     620000,11000000,10800000,5.7,15.0,0.6,5.0,28.0,0.60,'underutilized','worsening','Diagnostics imaging assets underutilized — high idle capacity'),
    ('ROA-RNT-2607','rentals','2026-07-01',
     480000,8500000,8300000,5.8,16.0,0.5,4.5,34.0,0.50,'underutilized','worsening','Rental fleet idle — utilization far below breakeven'),
    ('ROA-AMC-2606','amc_services','2026-06-01',
     1720000,8800000,8600000,20.0,18.0,1.8,10.5,7.0,1.80,'high','improving','AMC June ROA strong on renewals'),
    ('ROA-SPR-2606','spare_parts','2026-06-01',
     1010000,7000000,6900000,14.6,14.0,1.3,8.5,15.0,1.30,'on_target','stable','Spares June on target'),
    ('ROA-PRJ-2606','projects','2026-06-01',
     1550000,14800000,14300000,10.8,12.0,0.85,7.0,8.0,0.85,'below_target','improving','Projects June improving on cost control'),
    ('ROA-DIA-2606','diagnostics','2026-06-01',
     700000,10800000,10700000,6.5,15.0,0.65,5.5,25.0,0.65,'underutilized','stable','Diagnostics idle capacity remains high'),
    ('ROA-RNT-2606','rentals','2026-06-01',
     560000,8300000,8200000,6.8,16.0,0.55,5.0,30.0,0.55,'underutilized','improving','Rentals recovering slowly on new placements'),
    ('ROA-AMC-2605','amc_services','2026-05-01',
     1600000,8600000,8500000,18.8,18.0,1.75,10.0,8.0,1.75,'on_target','stable','AMC May steady near target'),
    ('ROA-SPR-2605','spare_parts','2026-05-01',
     880000,6900000,6800000,12.9,14.0,1.15,7.5,17.0,1.15,'below_target','worsening','Spares May below target on aging stock'),
    ('ROA-PRJ-2605','projects','2026-05-01',
     1200000,14300000,14000000,8.6,12.0,0.75,6.0,10.0,0.75,'below_target','stable','Projects May under target'),
    ('ROA-DIA-2605','diagnostics','2026-05-01',
     540000,10700000,10600000,5.1,15.0,0.58,4.8,30.0,0.58,'underutilized','worsening','Diagnostics May very idle — demand shortfall'),
    ('ROA-TKI-2607','turnkey_installation','2026-07-01',
     1120000,6400000,6300000,17.8,16.0,1.6,9.5,11.0,1.60,'on_target','improving','Turnkey installation efficient asset use'),
    ('ROA-TKI-2606','turnkey_installation','2026-06-01',
     980000,6300000,6200000,15.8,16.0,1.5,9.0,12.0,1.50,'on_target','stable','Turnkey June near target')
  ) as q(ecode, bu, pmonth, nprofit, tassets, aassets, roa, troa, aturn, nmargin, idle, rpa, estat, tdir, nt);

  -- CAPA seed — attach to specific entries via entry_code
  insert into public.roa_board_capa_actions_r3605 (
    roa_entry_id, finding_category, root_cause, corrective_action,
    capa_status, profit_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('ROA-SPR-2607','high_idle_assets','slow_moving_spares','liquidate_surplus_inventory','in_progress',180000.00,'Rakesh Menon (Spares Head)','2026-08-15',null,'Slow-moving spares identified for liquidation to lift turnover'),
    ('ROA-DIA-2607','capex_underutilization','overinvested_capex','redeploy_idle_assets','open',260000.00,'Dr. Anita Rao (Diagnostics Lead)','2026-08-31',null,'Idle imaging capacity — redeploy scanner to high-demand centre'),
    ('ROA-RNT-2607','low_asset_turnover','low_utilization_rentals','increase_rental_utilization','escalated',210000.00,'Vikram Shah (Rentals Mgr)','2026-08-10',null,'Rental fleet utilization critical — escalated to CFO'),
    ('ROA-PRJ-2607','roa_below_target','project_cost_overrun','optimize_capex_plan','in_progress',320000.00,'Suresh Iyer (Projects Dir)','2026-09-15',null,'Turnkey capex plan under review for staged deployment'),
    ('ROA-DIA-2606','high_idle_assets','demand_shortfall','divest_underperforming_assets','open',150000.00,'Dr. Anita Rao (Diagnostics Lead)','2026-08-20',null,'Evaluate divesting older CT unit at low-volume site'),
    ('ROA-RNT-2606','margin_compression','pricing_pressure','reprice_service_contracts','verification_pending',95000.00,'Vikram Shah (Rentals Mgr)','2026-07-25',null,'Rental repricing rolled out — verify margin recovery'),
    ('ROA-SPR-2605','revenue_per_asset_decline','aging_asset_base','accelerate_spare_turnover','closed',120000.00,'Rakesh Menon (Spares Head)','2026-07-05','2026-06-28','Spare turnover program closed — revenue-per-asset improved'),
    ('ROA-PRJ-2605','roa_below_target','pending_investigation','none_required','overdue',0.00,'Suresh Iyer (Projects Dir)','2026-07-10',null,'Root-cause investigation overdue — awaiting cost audit')
  ) as q(ecode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.roa_board_r3605 e
    on e.organization_id = v_org_id and e.entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Efficiency-status distribution
create or replace function public.founder_r3605_efficiency_status_rollup()
returns table(efficiency_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roa_board_r3605)
  select l.efficiency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.roa_board_r3605 l
  group by l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3605_efficiency_status_rollup() from public, anon;
grant execute on function public.founder_r3605_efficiency_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3605_business_unit_scorecard()
returns table(
  business_unit text,
  entries bigint,
  high bigint,
  on_target bigint,
  below_target bigint,
  underutilized bigint,
  avg_roa_pct numeric,
  avg_target_roa_pct numeric,
  on_target_pct numeric
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
    count(*) filter (where l.efficiency_status = 'high')::bigint,
    count(*) filter (where l.efficiency_status = 'on_target')::bigint,
    count(*) filter (where l.efficiency_status = 'below_target')::bigint,
    count(*) filter (where l.efficiency_status = 'underutilized')::bigint,
    round(avg(l.roa_pct), 2),
    round(avg(l.target_roa_pct), 2),
    round(100.0 * count(*) filter (where l.efficiency_status in ('high','on_target'))::numeric / nullif(count(*),0), 1)
  from public.roa_board_r3605 l
  group by l.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3605_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3605_business_unit_scorecard() to authenticated;

-- 3) Business-unit × efficiency-status matrix
create or replace function public.founder_r3605_bu_efficiency_matrix()
returns table(business_unit text, efficiency_status text, entries bigint, avg_roa_pct numeric, avg_idle_asset_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.efficiency_status, count(*)::bigint,
    round(avg(l.roa_pct), 2),
    round(avg(l.idle_asset_pct), 2)
  from public.roa_board_r3605 l
  group by l.business_unit, l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3605_bu_efficiency_matrix() from public, anon;
grant execute on function public.founder_r3605_bu_efficiency_matrix() to authenticated;

-- 4) Monthly ROA trend
create or replace function public.founder_r3605_monthly_roa_trend()
returns table(
  period_month date,
  entries bigint,
  avg_roa_pct numeric,
  avg_target_roa_pct numeric,
  avg_asset_turnover_ratio numeric,
  avg_idle_asset_pct numeric
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
    round(avg(l.roa_pct), 2),
    round(avg(l.target_roa_pct), 2),
    round(avg(l.asset_turnover_ratio), 2),
    round(avg(l.idle_asset_pct), 2)
  from public.roa_board_r3605 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3605_monthly_roa_trend() from public, anon;
grant execute on function public.founder_r3605_monthly_roa_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3605_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.profit_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.roa_board_capa_actions_r3605 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3605_capa_status_board() from public, anon;
grant execute on function public.founder_r3605_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3605_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roa_board_capa_actions_r3605)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.profit_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.roa_board_capa_actions_r3605 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3605_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3605_root_cause_pareto() to authenticated;

-- 7) Asset-efficiency digest (per business unit)
create or replace function public.founder_r3605_asset_efficiency_digest()
returns table(
  business_unit text,
  entries bigint,
  avg_asset_turnover_ratio numeric,
  avg_net_margin_pct numeric,
  avg_idle_asset_pct numeric,
  avg_revenue_per_asset_rupee numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, count(*)::bigint,
    round(avg(l.asset_turnover_ratio), 2),
    round(avg(l.net_margin_pct), 2),
    round(avg(l.idle_asset_pct), 2),
    round(avg(l.revenue_per_asset_rupee), 2)
  from public.roa_board_r3605 l
  group by l.business_unit
  order by round(avg(l.idle_asset_pct), 2) desc;
end;
$$;

revoke execute on function public.founder_r3605_asset_efficiency_digest() from public, anon;
grant execute on function public.founder_r3605_asset_efficiency_digest() to authenticated;

-- 8) High-risk queue (underutilized / below-target)
create or replace function public.founder_r3605_high_risk_queue()
returns table(
  business_unit text,
  entry_code text,
  period_month date,
  efficiency_status text,
  trend_dir text,
  roa_pct numeric,
  target_roa_pct numeric,
  idle_asset_pct numeric,
  asset_turnover_ratio numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.entry_code, l.period_month, l.efficiency_status, l.trend_dir,
    l.roa_pct, l.target_roa_pct, l.idle_asset_pct, l.asset_turnover_ratio, l.notes
  from public.roa_board_r3605 l
  where l.efficiency_status in ('below_target','underutilized')
     or l.trend_dir = 'worsening'
     or l.roa_pct < l.target_roa_pct
     or l.idle_asset_pct >= 20
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3605_high_risk_queue() from public, anon;
grant execute on function public.founder_r3605_high_risk_queue() to authenticated;
