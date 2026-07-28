-- Round 3569: Founder Operating-Leverage / Fixed-Variable Cost-Structure Board
-- Per business-line fixed vs variable cost structure, contribution margin, operating income,
-- degree of operating leverage (DOL), breakeven revenue, leverage status & trend + CAPA remediation.

-- =============================================================================
-- TABLE 1: operating_leverage_r3569 — per business-line monthly cost-structure snapshot
-- =============================================================================
create table if not exists public.operating_leverage_r3569 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  snapshot_code text not null,
  business_line text not null,
  period_month date not null,
  revenue_rupees numeric(14,2),
  variable_cost_rupees numeric(14,2),
  fixed_cost_rupees numeric(14,2),
  contribution_rupees numeric(14,2),
  contribution_margin_pct numeric(6,2),
  operating_income_rupees numeric(14,2),
  degree_operating_leverage numeric(8,2),
  breakeven_revenue_rupees numeric(14,2),
  leverage_status text not null check (leverage_status in (
    'high_leverage','balanced','low_leverage','below_breakeven'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.operating_leverage_r3569 enable row level security;

create index if not exists idx_operating_leverage_r3569_org on public.operating_leverage_r3569(organization_id);
create index if not exists idx_operating_leverage_r3569_month on public.operating_leverage_r3569(period_month);
create index if not exists idx_operating_leverage_r3569_status on public.operating_leverage_r3569(leverage_status);

-- =============================================================================
-- TABLE 2: operating_leverage_capa_actions_r3569 — cost-structure CAPA & remediation
-- =============================================================================
create table if not exists public.operating_leverage_capa_actions_r3569 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  leverage_snapshot_id uuid not null references public.operating_leverage_r3569(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'fixed_cost_too_high','variable_cost_creep','contribution_margin_erosion',
    'below_breakeven_volume','high_dol_volatility_risk','pricing_below_target',
    'utilization_shortfall','overhead_allocation_issue'
  )),
  root_cause text not null check (root_cause in (
    'excess_fixed_headcount','vendor_price_increase','discounting_pressure','low_volume_demand',
    'inefficient_process','underpriced_contracts','idle_capacity','fx_input_cost',
    'logistics_cost_spike','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_vendor_pricing','convert_fixed_to_variable','raise_prices','consolidate_headcount',
    'improve_utilization','exit_unprofitable_line','process_automation','renegotiate_contracts',
    'monitor_next_quarter','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  annual_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.operating_leverage_capa_actions_r3569 enable row level security;

create index if not exists idx_operating_leverage_capa_r3569_snap on public.operating_leverage_capa_actions_r3569(leverage_snapshot_id);
create index if not exists idx_operating_leverage_capa_r3569_status on public.operating_leverage_capa_actions_r3569(capa_status);

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

  -- 16 cost-structure snapshot rows
  insert into public.operating_leverage_r3569 (
    organization_id, snapshot_code, business_line, period_month,
    revenue_rupees, variable_cost_rupees, fixed_cost_rupees, contribution_rupees,
    contribution_margin_pct, operating_income_rupees, degree_operating_leverage,
    breakeven_revenue_rupees, leverage_status, trend_dir, notes
  )
  select v_org_id, q.sc, q.bl, q.pm::date,
    q.rev, q.vc, q.fc, q.contr,
    q.cmp, q.oi, q.dol,
    q.bev, q.ls, q.td, q.nt
  from (values
    ('OL-AMC-2026-05','amc_service_contracts','2026-05-01',
     8000000,2400000,2000000,5600000,70.0,3600000,1.56,2857143,'balanced','improving','AMC contracts high-margin annuity — strong contribution cushion'),
    ('OL-SPR-2026-05','spare_parts_sales','2026-05-01',
     5000000,3500000,600000,1500000,30.0,900000,1.67,2000000,'low_leverage','stable','Spare-parts trading margin thin, mostly variable pass-through'),
    ('OL-RES-2026-05','equipment_resale','2026-05-01',
     12000000,9600000,800000,2400000,20.0,1600000,1.50,4000000,'low_leverage','stable','Refurbished equipment resale — commodity-like 20% margin'),
    ('OL-INST-2026-05','installation_projects','2026-05-01',
     6000000,2100000,3200000,3900000,65.0,700000,5.57,4923077,'high_leverage','worsening','Project crews carried as fixed cost — DOL 5.6x, margin squeeze'),
    ('OL-CAL-2026-05','calibration_services','2026-05-01',
     2200000,550000,1000000,1650000,75.0,650000,2.54,1333333,'balanced','improving','Calibration lab high margin, moderate fixed lab overhead'),
    ('OL-RENT-2026-05','rental_fleet','2026-05-01',
     3500000,700000,3400000,2800000,80.0,-600000,null,4250000,'below_breakeven','worsening','Rental fleet depreciation fixed cost exceeds contribution — loss'),
    ('OL-TRN-2026-05','training_academy','2026-05-01',
     900000,180000,1200000,720000,80.0,-480000,null,1500000,'below_breakeven','stable','Training academy sub-scale, fixed faculty cost not covered'),
    ('OL-MKT-2026-05','marketplace_commission','2026-05-01',
     4000000,400000,1500000,3600000,90.0,2100000,1.71,1666667,'balanced','improving','Marketplace take-rate near-pure margin, platform fixed cost light'),
    ('OL-AMC-2026-06','amc_service_contracts','2026-06-01',
     8600000,2500000,2050000,6100000,70.9,4050000,1.51,2890492,'balanced','improving','AMC book grew with renewals, contribution scaling well'),
    ('OL-INST-2026-06','installation_projects','2026-06-01',
     5200000,1900000,3400000,3300000,63.5,-100000,null,5357576,'below_breakeven','worsening','Installation slipped below breakeven — fixed crew idle between projects'),
    ('OL-SPR-2026-06','spare_parts_sales','2026-06-01',
     5400000,3700000,620000,1700000,31.5,1080000,1.57,1969412,'low_leverage','improving','Spare-parts mix improved slightly, still variable-heavy'),
    ('OL-RENT-2026-06','rental_fleet','2026-06-01',
     4400000,800000,3400000,3600000,81.8,200000,18.00,4155556,'high_leverage','improving','Rental utilization recovered above breakeven — DOL 18x, fragile'),
    ('OL-CAL-2026-06','calibration_services','2026-06-01',
     2400000,580000,1020000,1820000,75.8,800000,2.28,1345055,'balanced','improving','Calibration volume up, contribution comfortably above fixed'),
    ('OL-MKT-2026-06','marketplace_commission','2026-06-01',
     4300000,420000,1550000,3880000,90.2,2330000,1.67,1717783,'balanced','improving','Marketplace commission scaling with GMV, low incremental cost'),
    ('OL-RES-2026-06','equipment_resale','2026-06-01',
     11000000,9000000,850000,2000000,18.2,1150000,1.74,4675000,'low_leverage','worsening','Resale margin eroded on FX-inflated import COGS'),
    ('OL-TRN-2026-06','training_academy','2026-06-01',
     1100000,200000,1150000,900000,81.8,-250000,null,1405556,'below_breakeven','improving','Academy enrolment rising but still short of fixed-cost breakeven')
  ) as q(sc, bl, pm, rev, vc, fc, contr, cmp, oi, dol, bev, ls, td, nt);

  -- CAPA seed — attach to specific snapshots via snapshot_code
  insert into public.operating_leverage_capa_actions_r3569 (
    organization_id, leverage_snapshot_id, finding_category, root_cause, corrective_action,
    capa_status, annual_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('OL-RENT-2026-05','below_breakeven_volume','idle_capacity','improve_utilization','in_progress',7200000,'Rahul Nair (Rentals Head)','2026-08-15',null,'Rental fleet below breakeven — utilization drive and fleet rightsizing underway'),
    ('OL-TRN-2026-05','below_breakeven_volume','low_volume_demand','exit_unprofitable_line','escalated',5760000,'Priya Menon (Academy Lead)','2026-08-01',null,'Training academy sub-scale — board reviewing shutdown vs digital pivot'),
    ('OL-INST-2026-05','high_dol_volatility_risk','excess_fixed_headcount','convert_fixed_to_variable','open',3840000,'Arun Kumar (Projects Head)','2026-09-10',null,'Installation DOL 5.6x — shift site crews to variable subcontract model'),
    ('OL-RES-2026-05','contribution_margin_erosion','discounting_pressure','raise_prices','in_progress',2880000,'Sneha Rao (Resale Lead)','2026-08-20',null,'Resale margin at 20% — enforce floor pricing on refurbished units'),
    ('OL-SPR-2026-05','variable_cost_creep','vendor_price_increase','renegotiate_vendor_pricing','verification_pending',1800000,'Vikram Shetty (Procurement)','2026-07-25',null,'Spare-parts COGS creeping — renegotiated top-5 vendors, verifying realized rates'),
    ('OL-RENT-2026-06','high_dol_volatility_risk','idle_capacity','monitor_next_quarter','open',0,'Rahul Nair (Rentals Head)','2026-09-30',null,'Rental back above breakeven but DOL 18x — monitor demand volatility'),
    ('OL-INST-2026-06','below_breakeven_volume','underpriced_contracts','renegotiate_contracts','escalated',4200000,'Arun Kumar (Projects Head)','2026-08-05',null,'Installation slipped below breakeven — reprice fixed-bid backlog'),
    ('OL-RES-2026-06','contribution_margin_erosion','fx_input_cost','renegotiate_vendor_pricing','closed',1600000,'Sneha Rao (Resale Lead)','2026-07-10','2026-07-08','Import FX pass-through negotiated with OEM — resale margin stabilized')
  ) as q(sc, fc, rc, ca, cst, impact, own, tcd, acd, nt)
  join public.operating_leverage_r3569 e
    on e.organization_id = v_org_id and e.snapshot_code = q.sc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Leverage-status distribution
create or replace function public.founder_r3569_leverage_status_rollup()
returns table(leverage_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.operating_leverage_r3569)
  select l.leverage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.operating_leverage_r3569 l
  group by l.leverage_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3569_leverage_status_rollup() from public, anon;
grant execute on function public.founder_r3569_leverage_status_rollup() to authenticated;

-- 2) Business-line scorecard
create or replace function public.founder_r3569_business_line_scorecard()
returns table(
  business_line text,
  snapshots bigint,
  total_revenue_rupees numeric,
  total_contribution_rupees numeric,
  avg_contribution_margin_pct numeric,
  total_operating_income_rupees numeric,
  avg_dol numeric,
  below_breakeven_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_line,
    count(*)::bigint,
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.contribution_rupees),0)::numeric,
    round(avg(l.contribution_margin_pct), 1),
    coalesce(sum(l.operating_income_rupees),0)::numeric,
    round(avg(l.degree_operating_leverage), 2),
    count(*) filter (where l.leverage_status = 'below_breakeven')::bigint
  from public.operating_leverage_r3569 l
  group by l.business_line
  order by coalesce(sum(l.contribution_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3569_business_line_scorecard() from public, anon;
grant execute on function public.founder_r3569_business_line_scorecard() to authenticated;

-- 3) Business-line x leverage-status matrix
create or replace function public.founder_r3569_line_status_matrix()
returns table(
  business_line text,
  leverage_status text,
  snapshots bigint,
  avg_contribution_margin_pct numeric,
  total_operating_income_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_line, l.leverage_status, count(*)::bigint,
    round(avg(l.contribution_margin_pct), 1),
    coalesce(sum(l.operating_income_rupees),0)::numeric
  from public.operating_leverage_r3569 l
  group by l.business_line, l.leverage_status
  order by l.business_line, count(*) desc;
end;
$$;

revoke all on function public.founder_r3569_line_status_matrix() from public, anon;
grant execute on function public.founder_r3569_line_status_matrix() to authenticated;

-- 4) Monthly DOL / contribution trend
create or replace function public.founder_r3569_monthly_dol_trend()
returns table(
  period_month date,
  snapshots bigint,
  total_revenue_rupees numeric,
  total_contribution_rupees numeric,
  total_operating_income_rupees numeric,
  avg_dol numeric,
  below_breakeven_lines bigint
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
    coalesce(sum(l.revenue_rupees),0)::numeric,
    coalesce(sum(l.contribution_rupees),0)::numeric,
    coalesce(sum(l.operating_income_rupees),0)::numeric,
    round(avg(l.degree_operating_leverage), 2),
    count(*) filter (where l.leverage_status = 'below_breakeven')::bigint
  from public.operating_leverage_r3569 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3569_monthly_dol_trend() from public, anon;
grant execute on function public.founder_r3569_monthly_dol_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3569_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.annual_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.operating_leverage_capa_actions_r3569 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3569_capa_status_board() from public, anon;
grant execute on function public.founder_r3569_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3569_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.operating_leverage_capa_actions_r3569)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.annual_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.operating_leverage_capa_actions_r3569 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3569_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3569_root_cause_pareto() to authenticated;

-- 7) Contribution-impact digest (per business line)
create or replace function public.founder_r3569_contribution_impact_digest()
returns table(
  business_line text,
  total_contribution_rupees numeric,
  total_fixed_cost_rupees numeric,
  total_operating_income_rupees numeric,
  avg_contribution_margin_pct numeric,
  capa_impact_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_line,
    coalesce(sum(l.contribution_rupees),0)::numeric,
    coalesce(sum(l.fixed_cost_rupees),0)::numeric,
    coalesce(sum(l.operating_income_rupees),0)::numeric,
    round(avg(l.contribution_margin_pct), 1),
    coalesce((
      select sum(c.annual_impact_rupees)
      from public.operating_leverage_capa_actions_r3569 c
      join public.operating_leverage_r3569 e on c.leverage_snapshot_id = e.id
      where e.business_line = l.business_line
    ),0)::numeric
  from public.operating_leverage_r3569 l
  group by l.business_line
  order by coalesce(sum(l.contribution_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3569_contribution_impact_digest() from public, anon;
grant execute on function public.founder_r3569_contribution_impact_digest() to authenticated;

-- 8) High-risk queue (below-breakeven / high-leverage / thin-margin / worsening)
create or replace function public.founder_r3569_high_risk_queue()
returns table(
  business_line text,
  snapshot_code text,
  period_month date,
  revenue_rupees numeric,
  contribution_margin_pct numeric,
  operating_income_rupees numeric,
  degree_operating_leverage numeric,
  breakeven_revenue_rupees numeric,
  leverage_status text,
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
  select l.business_line, l.snapshot_code, l.period_month, l.revenue_rupees,
    l.contribution_margin_pct, l.operating_income_rupees, l.degree_operating_leverage,
    l.breakeven_revenue_rupees, l.leverage_status, l.trend_dir, l.notes
  from public.operating_leverage_r3569 l
  where l.leverage_status in ('below_breakeven','high_leverage')
     or (l.leverage_status = 'low_leverage' and l.contribution_margin_pct < 25)
     or l.operating_income_rupees < 0
     or l.trend_dir = 'worsening'
  order by l.operating_income_rupees asc, l.period_month desc;
end;
$$;

revoke all on function public.founder_r3569_high_risk_queue() from public, anon;
grant execute on function public.founder_r3569_high_risk_queue() to authenticated;
