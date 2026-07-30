-- Round 3600: Founder Net-Working-Capital Movement & Drivers Board
-- NWC movement log — business unit × period × receivables × inventory × payables × net working capital × NWC change × NWC-to-revenue % × target × cash released × DSO/DPO/DIO × status verdict × trend × CAPA

-- =============================================================================
-- TABLE 1: nwc_movement_r3600 — per-business-unit monthly NWC movement facts
-- =============================================================================
create table if not exists public.nwc_movement_r3600 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  movement_code text not null,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals'
  )),
  period_month date not null,
  receivables_rupees numeric(16,2) not null,
  inventory_rupees numeric(16,2) not null,
  payables_rupees numeric(16,2) not null,
  net_working_capital_rupees numeric(16,2) not null,
  nwc_change_rupees numeric(16,2) not null,
  nwc_to_revenue_pct numeric(6,2) not null,
  target_nwc_to_revenue_pct numeric(6,2) not null,
  cash_released_rupees numeric(16,2) not null,
  dso_days int not null,
  dpo_days int not null,
  dio_days int not null,
  nwc_status text not null check (nwc_status in (
    'optimized','healthy','elevated','bloated','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nwc_movement_r3600 enable row level security;

create index if not exists idx_nwc_movement_r3600_org on public.nwc_movement_r3600(organization_id);
create index if not exists idx_nwc_movement_r3600_period on public.nwc_movement_r3600(period_month);
create index if not exists idx_nwc_movement_r3600_status on public.nwc_movement_r3600(nwc_status);

-- =============================================================================
-- TABLE 2: nwc_movement_capa_actions_r3600 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.nwc_movement_capa_actions_r3600 (
  id uuid primary key default gen_random_uuid(),
  movement_id uuid not null references public.nwc_movement_r3600(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'receivables_overdue','inventory_excess','payables_stretched_risk','dso_deterioration',
    'dio_deterioration','dpo_shortfall','nwc_target_breach','cash_conversion_slow',
    'revenue_mix_shift','forecast_variance'
  )),
  root_cause text not null check (root_cause in (
    'slow_collections','customer_payment_delay','excess_stock_buildup','obsolete_inventory',
    'vendor_terms_unfavorable','early_supplier_payment','billing_delay','project_milestone_slippage',
    'demand_forecast_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'tighten_credit_policy','escalate_collections','optimize_reorder_levels','liquidate_slow_stock',
    'renegotiate_vendor_terms','stagger_supplier_payments','accelerate_invoicing',
    'revise_milestone_billing','improve_demand_forecast','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cash_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nwc_movement_capa_actions_r3600 enable row level security;

create index if not exists idx_nwc_movement_capa_r3600_mov on public.nwc_movement_capa_actions_r3600(movement_id);
create index if not exists idx_nwc_movement_capa_r3600_status on public.nwc_movement_capa_actions_r3600(capa_status);

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

  -- 16 NWC movement rows
  insert into public.nwc_movement_r3600 (
    organization_id, movement_code, business_unit, period_month,
    receivables_rupees, inventory_rupees, payables_rupees, net_working_capital_rupees,
    nwc_change_rupees, nwc_to_revenue_pct, target_nwc_to_revenue_pct, cash_released_rupees,
    dso_days, dpo_days, dio_days, nwc_status, trend_dir, notes
  )
  select v_org_id, q.mcode, q.bu, q.pm::date,
    q.rcv, q.inv, q.pay, q.nwc,
    q.chg, q.n2r, q.tgt, q.cash,
    q.dso, q.dpo, q.dio, q.st, q.td, q.nt
  from (values
    ('NWC-AMC-MAY','amc_services','2026-05-01',
     18000000,2500000,9000000,11500000,500000,22.5,20.0,-300000,62,48,15,'elevated','worsening','AMC receivables rising ahead of Q1 collections drive'),
    ('NWC-AMC-JUN','amc_services','2026-06-01',
     16500000,2400000,9500000,9400000,-2100000,19.8,20.0,2100000,55,51,14,'healthy','improving','Collections drive released cash in June'),
    ('NWC-AMC-JUL','amc_services','2026-07-01',
     15000000,2300000,9800000,7500000,-1900000,17.5,20.0,1900000,50,53,13,'optimized','improving','AMC NWC below target on strong DSO'),
    ('NWC-SPR-MAY','spare_parts','2026-05-01',
     12000000,22000000,8000000,26000000,3000000,41.0,30.0,-3000000,48,40,95,'bloated','worsening','Spare-parts inventory buildup ahead of monsoon demand'),
    ('NWC-SPR-JUN','spare_parts','2026-06-01',
     11500000,24000000,8200000,27300000,1300000,42.5,30.0,-1300000,46,41,102,'bloated','worsening','Inventory still climbing with obsolescence risk on legacy SKUs'),
    ('NWC-SPR-JUL','spare_parts','2026-07-01',
     11000000,19000000,8500000,21500000,-5800000,34.0,30.0,5800000,44,43,82,'elevated','improving','Slow-stock liquidation released cash'),
    ('NWC-PRJ-APR','projects','2026-04-01',
     41000000,5500000,18500000,28000000,0,27.0,25.0,0,84,50,21,'elevated','stable','Baseline project NWC for FY start'),
    ('NWC-PRJ-MAY','projects','2026-05-01',
     45000000,6000000,20000000,31000000,3000000,28.0,25.0,-3000000,88,55,20,'elevated','worsening','Turnkey project WIP receivables ballooning on milestone delays'),
    ('NWC-PRJ-JUN','projects','2026-06-01',
     52000000,6500000,19000000,39500000,8500000,33.0,25.0,-8500000,95,52,22,'critical','worsening','Milestone slippage stretched receivables critically'),
    ('NWC-PRJ-JUL','projects','2026-07-01',
     43000000,6200000,21000000,28200000,-11300000,24.0,25.0,11300000,80,58,19,'healthy','improving','Milestone billing corrected with large cash release'),
    ('NWC-DIA-MAY','diagnostics','2026-05-01',
     8000000,3500000,5000000,6500000,200000,18.0,18.0,-200000,40,45,30,'healthy','stable','Diagnostics NWC on target'),
    ('NWC-DIA-JUN','diagnostics','2026-06-01',
     7800000,3400000,5200000,6000000,-500000,16.5,18.0,500000,38,46,29,'optimized','improving','Reagent stock optimized below target'),
    ('NWC-DIA-JUL','diagnostics','2026-07-01',
     8200000,3600000,5100000,6700000,700000,18.5,18.0,-700000,41,44,31,'healthy','stable','Slight uptick with new reagent contracts'),
    ('NWC-RNT-MAY','rentals','2026-05-01',
     6000000,1200000,3000000,4200000,100000,15.0,16.0,-100000,35,38,12,'optimized','stable','Rental fleet NWC lean'),
    ('NWC-RNT-JUN','rentals','2026-06-01',
     6500000,1300000,2800000,5000000,800000,17.5,16.0,-800000,38,36,13,'elevated','worsening','Deposits held up by hospital procurement cycles'),
    ('NWC-RNT-JUL','rentals','2026-07-01',
     9000000,1400000,2600000,7800000,2800000,24.0,16.0,-2800000,52,34,14,'bloated','worsening','Rental receivables spiked on collection lag at new sites')
  ) as q(mcode, bu, pm, rcv, inv, pay, nwc, chg, n2r, tgt, cash, dso, dpo, dio, st, td, nt);

  -- CAPA seed — attach to specific movements via movement_code
  insert into public.nwc_movement_capa_actions_r3600 (
    movement_id, finding_category, root_cause, corrective_action,
    capa_status, cash_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('NWC-PRJ-JUN','receivables_overdue','project_milestone_slippage','revise_milestone_billing','in_progress',8500000,'Head of Projects','2026-07-15',null,'Rework milestone billing schedule with client PMO'),
    ('NWC-SPR-MAY','inventory_excess','excess_stock_buildup','optimize_reorder_levels','in_progress',3000000,'Spares Category Lead','2026-07-20',null,'Reset reorder points on fast and slow movers'),
    ('NWC-SPR-JUN','inventory_excess','obsolete_inventory','liquidate_slow_stock','open',5000000,'Spares Category Lead','2026-08-05',null,'Identify obsolete SKUs for clearance sale'),
    ('NWC-PRJ-MAY','dso_deterioration','slow_collections','escalate_collections','closed',3000000,'Collections Manager','2026-06-30','2026-06-28','Escalation to CFO recovered two large receipts'),
    ('NWC-RNT-JUL','receivables_overdue','customer_payment_delay','tighten_credit_policy','escalated',2800000,'Rentals BU Head','2026-08-10',null,'New-site deposits delayed — escalated to procurement heads'),
    ('NWC-AMC-MAY','nwc_target_breach','billing_delay','accelerate_invoicing','closed',300000,'AMC Ops Lead','2026-06-15','2026-06-10','Automated AMC renewal invoicing cleared backlog'),
    ('NWC-PRJ-JUL','cash_conversion_slow','vendor_terms_unfavorable','renegotiate_vendor_terms','verification_pending',3000000,'Procurement Head','2026-07-25',null,'Renegotiated net-60 terms with two OEMs — verifying uptake'),
    ('NWC-SPR-JUL','forecast_variance','demand_forecast_error','improve_demand_forecast','open',1500000,'S and OP Planner','2026-08-15',null,'Introduce monthly S&OP review to cut forecast error'),
    ('NWC-RNT-JUN','dpo_shortfall','early_supplier_payment','stagger_supplier_payments','overdue',800000,'Finance Controller','2026-07-05',null,'Payment run cadence change past target — pending treasury sign-off')
  ) as q(mcode, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.nwc_movement_r3600 e
    on e.organization_id = v_org_id and e.movement_code = q.mcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) NWC status distribution
create or replace function public.founder_r3600_nwc_status_rollup()
returns table(nwc_status text, entries bigint, total_nwc_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nwc_movement_r3600)
  select l.nwc_status, count(*)::bigint,
         coalesce(sum(l.net_working_capital_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nwc_movement_r3600 l
  group by l.nwc_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3600_nwc_status_rollup() from public, anon;
grant execute on function public.founder_r3600_nwc_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3600_business_unit_scorecard()
returns table(
  business_unit text,
  entries bigint,
  total_nwc_rupees numeric,
  avg_nwc_to_revenue_pct numeric,
  avg_target_pct numeric,
  total_cash_released_rupees numeric,
  at_risk bigint,
  avg_dso_days numeric
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
    coalesce(sum(l.net_working_capital_rupees),0)::numeric,
    round(avg(l.nwc_to_revenue_pct), 1),
    round(avg(l.target_nwc_to_revenue_pct), 1),
    coalesce(sum(l.cash_released_rupees),0)::numeric,
    count(*) filter (where l.nwc_status in ('bloated','critical'))::bigint,
    round(avg(l.dso_days), 1)
  from public.nwc_movement_r3600 l
  group by l.business_unit
  order by coalesce(sum(l.net_working_capital_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3600_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3600_business_unit_scorecard() to authenticated;

-- 3) Business-unit × NWC-status matrix
create or replace function public.founder_r3600_business_unit_status_matrix()
returns table(business_unit text, nwc_status text, entries bigint, total_nwc_rupees numeric, total_cash_released_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.nwc_status, count(*)::bigint,
    coalesce(sum(l.net_working_capital_rupees),0)::numeric,
    coalesce(sum(l.cash_released_rupees),0)::numeric
  from public.nwc_movement_r3600 l
  group by l.business_unit, l.nwc_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3600_business_unit_status_matrix() from public, anon;
grant execute on function public.founder_r3600_business_unit_status_matrix() to authenticated;

-- 4) Monthly NWC trend
create or replace function public.founder_r3600_monthly_nwc_trend()
returns table(
  period_month date,
  entries bigint,
  total_nwc_rupees numeric,
  total_nwc_change_rupees numeric,
  total_cash_released_rupees numeric,
  avg_nwc_to_revenue_pct numeric
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
    coalesce(sum(l.net_working_capital_rupees),0)::numeric,
    coalesce(sum(l.nwc_change_rupees),0)::numeric,
    coalesce(sum(l.cash_released_rupees),0)::numeric,
    round(avg(l.nwc_to_revenue_pct), 1)
  from public.nwc_movement_r3600 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3600_monthly_nwc_trend() from public, anon;
grant execute on function public.founder_r3600_monthly_nwc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3600_capa_status_board()
returns table(capa_status text, findings bigint, avg_cash_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cash_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.nwc_movement_capa_actions_r3600 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3600_capa_status_board() from public, anon;
grant execute on function public.founder_r3600_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3600_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cash_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nwc_movement_capa_actions_r3600)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cash_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nwc_movement_capa_actions_r3600 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3600_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3600_root_cause_pareto() to authenticated;

-- 7) Cash-release digest by business unit
create or replace function public.founder_r3600_cash_release_digest()
returns table(
  business_unit text,
  months bigint,
  total_cash_released_rupees numeric,
  total_nwc_change_rupees numeric,
  avg_nwc_to_revenue_pct numeric
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
    coalesce(sum(l.cash_released_rupees),0)::numeric,
    coalesce(sum(l.nwc_change_rupees),0)::numeric,
    round(avg(l.nwc_to_revenue_pct), 1)
  from public.nwc_movement_r3600 l
  group by l.business_unit
  order by coalesce(sum(l.cash_released_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3600_cash_release_digest() from public, anon;
grant execute on function public.founder_r3600_cash_release_digest() to authenticated;

-- 8) High-risk (bloated/critical) queue
create or replace function public.founder_r3600_high_risk_queue()
returns table(
  business_unit text,
  movement_code text,
  period_month date,
  nwc_status text,
  net_working_capital_rupees numeric,
  nwc_change_rupees numeric,
  nwc_to_revenue_pct numeric,
  target_nwc_to_revenue_pct numeric,
  dso_days int,
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
  select l.business_unit, l.movement_code, l.period_month, l.nwc_status,
    l.net_working_capital_rupees, l.nwc_change_rupees, l.nwc_to_revenue_pct,
    l.target_nwc_to_revenue_pct, l.dso_days, l.trend_dir, l.notes
  from public.nwc_movement_r3600 l
  where l.nwc_status in ('bloated','critical')
     or l.trend_dir = 'worsening'
     or l.nwc_to_revenue_pct > l.target_nwc_to_revenue_pct
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3600_high_risk_queue() from public, anon;
grant execute on function public.founder_r3600_high_risk_queue() to authenticated;
