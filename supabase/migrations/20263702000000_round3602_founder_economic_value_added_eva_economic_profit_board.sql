-- Round 3602: Founder Economic Value Added (EVA) / Economic-Profit Board
-- EVA = NOPAT - (capital employed x WACC); per-business-unit economic profit — business unit x period x
-- NOPAT x capital employed x WACC x capital charge x EVA x EVA margin x target EVA x ROIC x value spread x
-- eva_status x trend x CAPA closure

-- =============================================================================
-- TABLE 1: eva_board_r3602 — per-business-unit monthly economic-profit fact rows
-- =============================================================================
create table if not exists public.eva_board_r3602 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals',
    'turnkey_solutions','consumables','refurb_equipment'
  )),
  eva_record_code text not null,
  period_month date not null,
  nopat_rupees numeric(14,2) not null,
  capital_employed_rupees numeric(14,2) not null,
  wacc_pct numeric(5,2) not null,
  capital_charge_rupees numeric(14,2) not null,
  eva_rupees numeric(14,2) not null,
  eva_margin_pct numeric(6,2) not null,
  target_eva_rupees numeric(14,2) not null,
  roic_pct numeric(6,2) not null,
  value_spread_pct numeric(6,2) not null,
  eva_status text not null check (eva_status in (
    'value_creating','neutral','value_eroding','value_destroying'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eva_board_r3602 enable row level security;

create index if not exists idx_eva_board_r3602_org on public.eva_board_r3602(organization_id);
create index if not exists idx_eva_board_r3602_period on public.eva_board_r3602(period_month);
create index if not exists idx_eva_board_r3602_status on public.eva_board_r3602(eva_status);

-- =============================================================================
-- TABLE 2: eva_board_capa_actions_r3602 — value-improvement CAPA actions
-- =============================================================================
create table if not exists public.eva_board_capa_actions_r3602 (
  id uuid primary key default gen_random_uuid(),
  eva_id uuid not null references public.eva_board_r3602(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'negative_economic_profit','eva_below_target','capital_charge_exceeds_return','roic_below_wacc',
    'value_spread_negative','capital_misallocation','margin_erosion','deteriorating_eva_trend'
  )),
  root_cause text not null check (root_cause in (
    'high_working_capital_lockup','underpriced_amc_contracts','idle_rental_fleet','project_cost_overrun',
    'excess_inventory_holding','low_asset_utilization','elevated_cost_of_capital','pricing_discount_leakage',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_amc_pricing','reduce_working_capital','divest_idle_assets','tighten_project_governance',
    'liquidate_excess_inventory','reallocate_capital','optimize_debt_mix','enforce_discount_controls',
    'exit_business_line','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eva_board_capa_actions_r3602 enable row level security;

create index if not exists idx_eva_board_capa_r3602_eva on public.eva_board_capa_actions_r3602(eva_id);
create index if not exists idx_eva_board_capa_r3602_status on public.eva_board_capa_actions_r3602(capa_status);

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

  -- 16 EVA fact rows
  insert into public.eva_board_r3602 (
    organization_id, business_unit, eva_record_code, period_month,
    nopat_rupees, capital_employed_rupees, wacc_pct, capital_charge_rupees,
    eva_rupees, eva_margin_pct, target_eva_rupees, roic_pct, value_spread_pct,
    eva_status, trend_dir, notes
  )
  select v_org_id, q.bu, q.rcode, q.pmonth::date,
    q.nopat, q.capemp, q.wacc, q.capchg,
    q.eva, q.evamgn, q.tgteva, q.roic, q.vspread,
    q.evst, q.trend, q.nt
  from (values
    ('amc_services','EVA-AMC-2606','2026-06-01',
     12000000,50000000,14.00,7000000,5000000,10.00,4500000,24.00,10.00,
     'value_creating','improving','AMC services generating strong economic profit; ROIC 24 pct well above WACC'),
    ('spare_parts','EVA-SPR-2606','2026-06-01',
     9000000,30000000,13.50,4050000,4950000,16.50,4000000,30.00,16.50,
     'value_creating','improving','Spare parts high-margin BU; best value spread in portfolio'),
    ('diagnostics','EVA-DGN-2606','2026-06-01',
     6200000,40000000,14.50,5800000,400000,1.00,1500000,15.50,1.00,
     'neutral','stable','Diagnostics barely above capital charge; EVA well short of target'),
    ('rentals','EVA-RNT-2606','2026-06-01',
     3600000,25000000,15.00,3750000,-150000,-0.60,500000,14.40,-0.60,
     'value_eroding','worsening','Rental fleet returns dipped below cost of capital this month'),
    ('projects','EVA-PRJ-2606','2026-06-01',
     8000000,80000000,15.50,12400000,-4400000,-5.50,2000000,10.00,-5.50,
     'value_destroying','worsening','Turnkey projects consuming most capital yet destroying value; cost overruns'),
    ('turnkey_solutions','EVA-TKY-2606','2026-06-01',
     6000000,60000000,15.00,9000000,-3000000,-5.00,1000000,10.00,-5.00,
     'value_destroying','stable','Turnkey solutions ROIC stuck at 10 pct against 15 pct WACC'),
    ('consumables','EVA-CNS-2606','2026-06-01',
     4500000,15000000,13.00,1950000,2550000,17.00,2000000,30.00,17.00,
     'value_creating','improving','Consumables capital-light and highly value-accretive'),
    ('refurb_equipment','EVA-RFB-2606','2026-06-01',
     3000000,20000000,16.00,3200000,-200000,-1.00,300000,15.00,-1.00,
     'value_eroding','stable','Refurb line marginally eroding value; inventory holding cost high'),
    ('amc_services','EVA-AMC-2605','2026-05-01',
     11000000,48000000,14.00,6720000,4280000,8.92,4200000,22.92,8.92,
     'value_creating','improving','AMC services steadily improving economic profit month over month'),
    ('spare_parts','EVA-SPR-2605','2026-05-01',
     8000000,28000000,13.50,3780000,4220000,15.07,3800000,28.57,15.07,
     'value_creating','stable','Spare parts consistent value creator'),
    ('projects','EVA-PRJ-2605','2026-05-01',
     7500000,75000000,15.50,11625000,-4125000,-5.50,1800000,10.00,-5.50,
     'value_destroying','worsening','Projects BU negative EVA second month running'),
    ('diagnostics','EVA-DGN-2605','2026-05-01',
     6000000,38000000,14.50,5510000,490000,1.29,1400000,15.79,1.29,
     'neutral','improving','Diagnostics inching toward value creation as utilization rises'),
    ('rentals','EVA-RNT-2605','2026-05-01',
     3400000,24000000,15.00,3600000,-200000,-0.83,400000,14.17,-0.83,
     'value_eroding','worsening','Rentals value spread negative; idle units dragging returns'),
    ('amc_services','EVA-AMC-2604','2026-04-01',
     10000000,46000000,14.00,6440000,3560000,7.74,4000000,21.74,7.74,
     'value_creating','stable','AMC services solid economic profit base'),
    ('turnkey_solutions','EVA-TKY-2604','2026-04-01',
     5500000,55000000,15.00,8250000,-2750000,-5.00,800000,10.00,-5.00,
     'value_destroying','worsening','Turnkey solutions destroying value since project ramp'),
    ('consumables','EVA-CNS-2604','2026-04-01',
     4000000,14000000,13.00,1820000,2180000,15.57,1800000,28.57,15.57,
     'value_creating','improving','Consumables strong ROIC and improving EVA')
  ) as q(bu, rcode, pmonth, nopat, capemp, wacc, capchg, eva, evamgn, tgteva, roic, vspread, evst, trend, nt);

  -- CAPA seed — attach to specific line items via eva_record_code
  insert into public.eva_board_capa_actions_r3602 (
    eva_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EVA-PRJ-2606','negative_economic_profit','project_cost_overrun','tighten_project_governance',
     'escalated',4400000,'Ramesh Iyer (COO)','2026-08-15',null,'Projects BU eroding value; turnkey cost overruns — governance review escalated to board'),
    ('EVA-TKY-2606','roic_below_wacc','high_working_capital_lockup','reduce_working_capital',
     'in_progress',3000000,'Anjali Mehta (CFO)','2026-08-10',null,'Turnkey ROIC 10 pct vs 15 pct WACC; milestone billing being accelerated'),
    ('EVA-RNT-2606','value_spread_negative','idle_rental_fleet','divest_idle_assets',
     'open',150000,'Suresh Nair (Ops Head)','2026-08-20',null,'Rental fleet utilization below breakeven; identify idle units for divestment'),
    ('EVA-PRJ-2605','deteriorating_eva_trend','project_cost_overrun','tighten_project_governance',
     'in_progress',4125000,'Ramesh Iyer (COO)','2026-08-05',null,'Second consecutive month of negative EVA in projects; stage-gate controls tightened'),
    ('EVA-RFB-2606','eva_below_target','excess_inventory_holding','liquidate_excess_inventory',
     'verification_pending',200000,'Kavya Reddy (SCM Lead)','2026-07-25',null,'Refurb inventory ageing; clearance sale underway, verifying capital release'),
    ('EVA-TKY-2604','capital_charge_exceeds_return','elevated_cost_of_capital','optimize_debt_mix',
     'closed',2750000,'Anjali Mehta (CFO)','2026-06-30','2026-06-28','Refinanced project debt at lower rate; WACC lowered, EVA gap closed'),
    ('EVA-DGN-2606','eva_below_target','underpriced_amc_contracts','renegotiate_amc_pricing',
     'open',1100000,'Priya Deshpande (Sales Head)','2026-09-01',null,'Diagnostics EVA below target; bundled AMC pricing being revised at renewals'),
    ('EVA-RNT-2605','value_spread_negative','low_asset_utilization','reallocate_capital',
     'overdue',200000,'Suresh Nair (Ops Head)','2026-07-10',null,'Rental value spread negative two months; capital reallocation plan overdue')
  ) as q(rcode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.eva_board_r3602 e
    on e.organization_id = v_org_id and e.eva_record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) EVA status distribution
create or replace function public.founder_r3602_eva_status_rollup()
returns table(eva_status text, line_items bigint, total_eva_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eva_board_r3602)
  select l.eva_status, count(*)::bigint,
         coalesce(sum(l.eva_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.eva_board_r3602 l
  group by l.eva_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3602_eva_status_rollup() from public, anon;
grant execute on function public.founder_r3602_eva_status_rollup() to authenticated;

-- 2) Business-unit economic-profit scorecard
create or replace function public.founder_r3602_business_unit_scorecard()
returns table(
  business_unit text,
  line_items bigint,
  total_nopat_rupees numeric,
  total_capital_employed_rupees numeric,
  total_capital_charge_rupees numeric,
  total_eva_rupees numeric,
  avg_roic_pct numeric,
  avg_wacc_pct numeric
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
    coalesce(sum(l.nopat_rupees),0)::numeric,
    coalesce(sum(l.capital_employed_rupees),0)::numeric,
    coalesce(sum(l.capital_charge_rupees),0)::numeric,
    coalesce(sum(l.eva_rupees),0)::numeric,
    round(avg(l.roic_pct), 2),
    round(avg(l.wacc_pct), 2)
  from public.eva_board_r3602 l
  group by l.business_unit
  order by coalesce(sum(l.eva_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3602_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3602_business_unit_scorecard() to authenticated;

-- 3) Business-unit × EVA-status matrix
create or replace function public.founder_r3602_business_unit_status_matrix()
returns table(business_unit text, eva_status text, line_items bigint, total_eva_rupees numeric, avg_value_spread_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.eva_status, count(*)::bigint,
    coalesce(sum(l.eva_rupees),0)::numeric,
    round(avg(l.value_spread_pct), 2)
  from public.eva_board_r3602 l
  group by l.business_unit, l.eva_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3602_business_unit_status_matrix() from public, anon;
grant execute on function public.founder_r3602_business_unit_status_matrix() to authenticated;

-- 4) Monthly EVA trend
create or replace function public.founder_r3602_monthly_eva_trend()
returns table(
  period_month date,
  line_items bigint,
  total_nopat_rupees numeric,
  total_capital_charge_rupees numeric,
  total_eva_rupees numeric,
  avg_eva_margin_pct numeric
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
    coalesce(sum(l.nopat_rupees),0)::numeric,
    coalesce(sum(l.capital_charge_rupees),0)::numeric,
    coalesce(sum(l.eva_rupees),0)::numeric,
    round(avg(l.eva_margin_pct), 2)
  from public.eva_board_r3602 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3602_monthly_eva_trend() from public, anon;
grant execute on function public.founder_r3602_monthly_eva_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3602_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.financial_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.eva_board_capa_actions_r3602 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3602_capa_status_board() from public, anon;
grant execute on function public.founder_r3602_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3602_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eva_board_capa_actions_r3602)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.eva_board_capa_actions_r3602 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3602_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3602_root_cause_pareto() to authenticated;

-- 7) Value-creation digest (by momentum / trend direction)
create or replace function public.founder_r3602_value_creation_digest()
returns table(
  trend_dir text,
  line_items bigint,
  total_eva_rupees numeric,
  avg_eva_margin_pct numeric,
  value_creating bigint,
  value_destroying bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir,
    count(*)::bigint,
    coalesce(sum(l.eva_rupees),0)::numeric,
    round(avg(l.eva_margin_pct), 2),
    count(*) filter (where l.eva_status = 'value_creating')::bigint,
    count(*) filter (where l.eva_status in ('value_eroding','value_destroying'))::bigint
  from public.eva_board_r3602 l
  group by l.trend_dir
  order by coalesce(sum(l.eva_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3602_value_creation_digest() from public, anon;
grant execute on function public.founder_r3602_value_creation_digest() to authenticated;

-- 8) High-risk queue (value_destroying / value_eroding line items)
create or replace function public.founder_r3602_high_risk_queue()
returns table(
  business_unit text,
  eva_record_code text,
  period_month date,
  eva_rupees numeric,
  eva_margin_pct numeric,
  roic_pct numeric,
  wacc_pct numeric,
  value_spread_pct numeric,
  eva_status text,
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
  select l.business_unit, l.eva_record_code, l.period_month,
    l.eva_rupees, l.eva_margin_pct, l.roic_pct, l.wacc_pct, l.value_spread_pct,
    l.eva_status, l.trend_dir, l.notes
  from public.eva_board_r3602 l
  where l.eva_status in ('value_destroying','value_eroding')
     or l.value_spread_pct < 0
     or l.eva_rupees < l.target_eva_rupees
     or l.trend_dir = 'worsening'
  order by case l.eva_status
             when 'value_destroying' then 0
             when 'value_eroding' then 1
             when 'neutral' then 2
             else 3
           end,
           l.eva_rupees asc;
end;
$$;

revoke execute on function public.founder_r3602_high_risk_queue() from public, anon;
grant execute on function public.founder_r3602_high_risk_queue() to authenticated;
