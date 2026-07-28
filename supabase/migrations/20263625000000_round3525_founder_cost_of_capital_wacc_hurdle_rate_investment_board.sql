-- Round 3525: Founder Cost-of-Capital / WACC Hurdle-Rate Investment Board
-- Capital allocation gating — project × business unit × cost of debt/equity × WACC × hurdle rate × project IRR × spread × investment × gate decision × risk premium × CAPA

-- =============================================================================
-- TABLE 1: wacc_hurdle_rate_r3525 — per-project WACC vs hurdle-rate gating log
-- =============================================================================
create table if not exists public.wacc_hurdle_rate_r3525 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_code text not null,
  project_name text not null,
  business_unit text not null,
  cost_of_debt_pct numeric(6,2),
  cost_of_equity_pct numeric(6,2),
  wacc_pct numeric(6,2),
  hurdle_rate_pct numeric(6,2),
  project_irr_pct numeric(6,2),
  spread_over_hurdle_pct numeric(6,2),
  investment_rupees numeric(16,2),
  risk_premium_pct numeric(6,2),
  gate_decision text not null check (gate_decision in (
    'accept','accept_conditional','revise','reject','defer'
  )),
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wacc_hurdle_rate_r3525 enable row level security;

create index if not exists idx_wacc_hurdle_rate_r3525_org on public.wacc_hurdle_rate_r3525(organization_id);
create index if not exists idx_wacc_hurdle_rate_r3525_month on public.wacc_hurdle_rate_r3525(period_month);
create index if not exists idx_wacc_hurdle_rate_r3525_gate on public.wacc_hurdle_rate_r3525(gate_decision);

-- =============================================================================
-- TABLE 2: wacc_hurdle_rate_capa_actions_r3525 — CAPA & governance actions
-- =============================================================================
create table if not exists public.wacc_hurdle_rate_capa_actions_r3525 (
  id uuid primary key default gen_random_uuid(),
  gate_log_id uuid not null references public.wacc_hurdle_rate_r3525(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'irr_below_hurdle','negative_spread_over_hurdle','wacc_understated','risk_premium_insufficient',
    'cost_of_debt_stale','cost_of_equity_stale','capital_rationing_conflict','strategic_override_unjustified',
    'model_assumption_error','sensitivity_not_run'
  )),
  root_cause text not null check (root_cause in (
    'optimistic_revenue_assumptions','underestimated_capex','stale_market_data','beta_misestimated',
    'debt_mix_changed','tax_shield_miscalc','terminal_value_overstated','discount_rate_error',
    'pending_investigation','scope_creep'
  )),
  corrective_action text not null check (corrective_action in (
    'rebuild_dcf_model','revise_hurdle_rate','update_capital_structure','rerun_sensitivity_analysis',
    'defer_to_next_cycle','reject_and_reallocate','escalate_to_board','renegotiate_vendor_terms',
    'refresh_market_data','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  portfolio_impact text not null check (portfolio_impact in (
    'board_approval_required','reallocate_capital','none','watchlist','write_down_risk','strategic_priority'
  )),
  owner text not null,
  capital_at_risk_rupees numeric(16,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wacc_hurdle_rate_capa_actions_r3525 enable row level security;

create index if not exists idx_wacc_hurdle_capa_r3525_log on public.wacc_hurdle_rate_capa_actions_r3525(gate_log_id);
create index if not exists idx_wacc_hurdle_capa_r3525_status on public.wacc_hurdle_rate_capa_actions_r3525(capa_status);

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

  -- 16 project gating rows
  insert into public.wacc_hurdle_rate_r3525 (
    organization_id, project_code, project_name, business_unit,
    cost_of_debt_pct, cost_of_equity_pct, wacc_pct, hurdle_rate_pct,
    project_irr_pct, spread_over_hurdle_pct, investment_rupees, risk_premium_pct,
    gate_decision, period_month, notes
  )
  select v_org_id, q.pcode, q.pname, q.bu,
    q.cod, q.coe, q.wacc, q.hurdle,
    q.irr, q.spread, q.invest, q.rprem,
    q.gate, q.pmonth::date, q.nt
  from (values
    ('INV-2601','CT Scanner Fleet Expansion','imaging_capex',
     8.50,15.00,12.20,14.00,18.50,4.50,45000000,3.00,'accept','2026-07-01','IRR comfortably above hurdle — approved for FY capex'),
    ('INV-2602','MRI Refurb Program','refurb_program',
     8.20,14.50,11.80,13.50,12.00,-1.50,18000000,2.50,'reject','2026-07-01','IRR below hurdle — refurb economics weak vs new'),
    ('INV-2603','Biomedical AMC Platform','biomedical_amc',
     8.80,15.50,12.60,14.00,15.20,1.20,9000000,3.20,'accept_conditional','2026-07-01','Thin positive spread — approve pending sensitivity run'),
    ('INV-2604','Field Service Van Fleet','logistics_fleet',
     9.20,14.00,12.10,13.00,13.40,0.40,6500000,2.80,'accept_conditional','2026-06-01','Marginal spread — WACC recheck on debt mix required'),
    ('INV-2605','Digital Health App Suite','digital_health',
     8.00,18.00,14.50,16.00,22.00,6.00,12000000,5.00,'accept','2026-06-01','High-growth digital IRR well above risk-adjusted hurdle'),
    ('INV-2606','Spares Inventory Automation','spares_inventory',
     8.50,14.80,12.30,13.50,11.50,-2.00,4200000,2.60,'revise','2026-06-01','Below hurdle — capex assumptions to be revised'),
    ('INV-2607','Tier-2 Market Entry','new_market_expansion',
     9.50,19.00,15.20,17.00,16.50,-0.50,30000000,5.50,'defer','2026-06-01','Just under hurdle — defer pending fresh market data'),
    ('INV-2608','Service Network Hub North','service_network',
     8.70,15.20,12.40,14.00,19.00,5.00,22000000,3.10,'accept','2026-05-01','Strong spread — accretive network build approved'),
    ('INV-2609','Ventilator Rental Pool','biomedical_amc',
     8.90,15.80,12.90,14.50,14.20,-0.30,15000000,3.40,'revise','2026-05-01','Marginally below hurdle — terminal value overstated'),
    ('INV-2610','Cath Lab Capex','imaging_capex',
     8.40,15.10,12.20,14.00,20.50,6.50,55000000,3.00,'accept','2026-05-01','Flagship capex — highest spread in portfolio'),
    ('INV-2611','Refurb Ultrasound Line','refurb_program',
     8.30,14.60,11.90,13.50,17.80,4.30,8000000,2.70,'accept','2026-05-01','Refurb ultrasound economics strong vs hurdle'),
    ('INV-2612','Logistics Cold-Chain','logistics_fleet',
     9.00,14.20,12.00,13.00,9.50,-3.50,11000000,2.90,'reject','2026-04-01','IRR far below hurdle — reallocate capital'),
    ('INV-2613','AI Diagnostics Pilot','digital_health',
     8.10,20.00,15.50,18.00,17.00,-1.00,7500000,6.00,'defer','2026-04-01','Below high-risk hurdle — beta re-estimation needed'),
    ('INV-2614','South Region Service Hub','service_network',
     8.60,15.00,12.30,14.00,16.80,2.80,19000000,3.10,'accept_conditional','2026-04-01','Positive spread — approve with staged drawdown'),
    ('INV-2615','East Market Expansion','new_market_expansion',
     9.40,18.50,14.90,17.00,12.50,-4.50,26000000,5.40,'reject','2026-04-01','Deep negative spread — expansion rejected this cycle'),
    ('INV-2616','Spare Parts Depot Capex','spares_inventory',
     8.50,14.90,12.30,13.50,14.60,1.10,5000000,2.60,'accept','2026-07-01','Modest positive spread — depot capex approved')
  ) as q(pcode, pname, bu, cod, coe, wacc, hurdle, irr, spread, invest, rprem, gate, pmonth, nt);

  -- CAPA seed — attach to specific gates via project_code
  insert into public.wacc_hurdle_rate_capa_actions_r3525 (
    gate_log_id, finding_category, root_cause, corrective_action,
    capa_status, portfolio_impact, owner, capital_at_risk_rupees,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.pi, q.own, q.car,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('INV-2602','irr_below_hurdle','optimistic_revenue_assumptions','rebuild_dcf_model','in_progress','reallocate_capital','Priya Nair',18000000,'2026-08-05',null,'Refurb revenue case rebuilt with conservative utilisation'),
    ('INV-2606','negative_spread_over_hurdle','underestimated_capex','rerun_sensitivity_analysis','open','watchlist','Arjun Rao',4200000,'2026-08-10',null,'Automation capex under-scoped — rerun with vendor quotes'),
    ('INV-2607','irr_below_hurdle','stale_market_data','refresh_market_data','open','board_approval_required','Meera Krishnan',30000000,'2026-08-15',null,'Tier-2 TAM estimates stale — refresh before board cycle'),
    ('INV-2609','negative_spread_over_hurdle','terminal_value_overstated','rebuild_dcf_model','verification_pending','watchlist','Sanjay Gupta',15000000,'2026-08-01',null,'Rental pool terminal value corrected — verify revised IRR'),
    ('INV-2612','irr_below_hurdle','underestimated_capex','reject_and_reallocate','closed','reallocate_capital','Priya Nair',11000000,'2026-07-20','2026-07-18','Cold-chain rejected — budget reallocated to Cath Lab'),
    ('INV-2613','risk_premium_insufficient','beta_misestimated','revise_hurdle_rate','escalated','strategic_priority','Rahul Desai',7500000,'2026-08-12',null,'AI pilot beta re-estimated — hurdle rate under board review'),
    ('INV-2615','negative_spread_over_hurdle','optimistic_revenue_assumptions','reject_and_reallocate','overdue','write_down_risk','Meera Krishnan',26000000,'2026-07-15',null,'East expansion rejected — closure of sunk spend overdue'),
    ('INV-2603','sensitivity_not_run','discount_rate_error','rerun_sensitivity_analysis','open','none','Arjun Rao',9000000,'2026-08-08',null,'AMC platform sensitivity table not run at gate'),
    ('INV-2604','wacc_understated','debt_mix_changed','update_capital_structure','in_progress','watchlist','Sanjay Gupta',6500000,'2026-08-03',null,'Van fleet WACC understated — refresh with new debt mix')
  ) as q(pcode, fc, rc, ca, cst, pi, own, car, tcd, acd, nt)
  join public.wacc_hurdle_rate_r3525 e
    on e.organization_id = v_org_id and e.project_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Gate decision distribution
create or replace function public.founder_r3525_gate_decision_rollup()
returns table(gate_decision text, projects bigint, total_investment_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.wacc_hurdle_rate_r3525)
  select l.gate_decision, count(*)::bigint,
         coalesce(sum(l.investment_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.wacc_hurdle_rate_r3525 l
  group by l.gate_decision
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3525_gate_decision_rollup() from public, anon;
grant execute on function public.founder_r3525_gate_decision_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3525_business_unit_scorecard()
returns table(
  business_unit text,
  total_projects bigint,
  accepted bigint,
  conditional bigint,
  rejected bigint,
  below_hurdle bigint,
  avg_spread_pct numeric,
  total_investment_rupees numeric,
  accept_pct numeric
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
    count(*) filter (where l.gate_decision = 'accept')::bigint,
    count(*) filter (where l.gate_decision = 'accept_conditional')::bigint,
    count(*) filter (where l.gate_decision in ('reject','defer','revise'))::bigint,
    count(*) filter (where l.spread_over_hurdle_pct < 0)::bigint,
    round(avg(l.spread_over_hurdle_pct), 2),
    coalesce(sum(l.investment_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.gate_decision = 'accept')::numeric / nullif(count(*),0), 1)
  from public.wacc_hurdle_rate_r3525 l
  group by l.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3525_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3525_business_unit_scorecard() to authenticated;

-- 3) Business-unit × gate-decision matrix
create or replace function public.founder_r3525_bu_gate_matrix()
returns table(business_unit text, gate_decision text, projects bigint, total_investment_rupees numeric, avg_irr_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.gate_decision, count(*)::bigint,
    coalesce(sum(l.investment_rupees),0)::numeric,
    round(avg(l.project_irr_pct), 2)
  from public.wacc_hurdle_rate_r3525 l
  group by l.business_unit, l.gate_decision
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3525_bu_gate_matrix() from public, anon;
grant execute on function public.founder_r3525_bu_gate_matrix() to authenticated;

-- 4) Monthly IRR-vs-hurdle trend
create or replace function public.founder_r3525_monthly_irr_hurdle_trend()
returns table(
  period_month date,
  projects bigint,
  avg_wacc_pct numeric,
  avg_hurdle_rate_pct numeric,
  avg_project_irr_pct numeric,
  avg_spread_pct numeric,
  below_hurdle bigint
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
    round(avg(l.wacc_pct), 2),
    round(avg(l.hurdle_rate_pct), 2),
    round(avg(l.project_irr_pct), 2),
    round(avg(l.spread_over_hurdle_pct), 2),
    count(*) filter (where l.spread_over_hurdle_pct < 0)::bigint
  from public.wacc_hurdle_rate_r3525 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3525_monthly_irr_hurdle_trend() from public, anon;
grant execute on function public.founder_r3525_monthly_irr_hurdle_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3525_capa_status_board()
returns table(capa_status text, findings bigint, avg_capital_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.capital_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.wacc_hurdle_rate_capa_actions_r3525 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3525_capa_status_board() from public, anon;
grant execute on function public.founder_r3525_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3525_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_capital_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.wacc_hurdle_rate_capa_actions_r3525)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.capital_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.wacc_hurdle_rate_capa_actions_r3525 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3525_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3525_root_cause_pareto() to authenticated;

-- 7) Investment-impact digest (by portfolio impact)
create or replace function public.founder_r3525_investment_impact_digest()
returns table(portfolio_impact text, findings bigint, open_findings bigint, total_capital_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.portfolio_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.capital_at_risk_rupees),0)::numeric
  from public.wacc_hurdle_rate_capa_actions_r3525 c
  group by c.portfolio_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3525_investment_impact_digest() from public, anon;
grant execute on function public.founder_r3525_investment_impact_digest() to authenticated;

-- 8) High-risk queue (reject / below-hurdle / high-risk projects)
create or replace function public.founder_r3525_high_risk_queue()
returns table(
  project_name text,
  project_code text,
  business_unit text,
  period_month date,
  gate_decision text,
  wacc_pct numeric,
  hurdle_rate_pct numeric,
  project_irr_pct numeric,
  spread_over_hurdle_pct numeric,
  investment_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.project_name, l.project_code, l.business_unit, l.period_month,
    l.gate_decision, l.wacc_pct, l.hurdle_rate_pct, l.project_irr_pct,
    l.spread_over_hurdle_pct, l.investment_rupees, l.notes
  from public.wacc_hurdle_rate_r3525 l
  where l.gate_decision in ('reject','defer','revise')
     or l.spread_over_hurdle_pct < 0
     or l.project_irr_pct < l.hurdle_rate_pct
     or l.risk_premium_pct >= 5.00
  order by l.spread_over_hurdle_pct asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3525_high_risk_queue() from public, anon;
grant execute on function public.founder_r3525_high_risk_queue() to authenticated;
