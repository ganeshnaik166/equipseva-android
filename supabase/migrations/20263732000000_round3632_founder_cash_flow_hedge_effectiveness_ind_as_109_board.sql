-- Round 3632: Founder Cash-Flow Hedge Effectiveness (Ind-AS 109) Board
-- Cash-flow hedge effectiveness under Ind-AS 109 — hedge ratio, effective/ineffective portion,
-- OCI reserve, effectiveness %, per hedge relationship × hedged item × hedge type × CAPA remediation.

-- =============================================================================
-- TABLE 1: hedge_eff_r3632 — per-relationship cash-flow hedge effectiveness ledger
-- =============================================================================
create table if not exists public.hedge_eff_r3632 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hedge_relationship text not null,
  hedged_item text not null,
  period_month date not null,
  notional_rupees numeric(16,2) not null,
  hedge_ratio_pct numeric(6,2) not null,
  mtm_gain_loss_rupees numeric(16,2) not null,
  effective_portion_rupees numeric(16,2) not null,
  ineffective_portion_rupees numeric(16,2) not null,
  oci_reserve_rupees numeric(16,2) not null,
  effectiveness_pct numeric(6,2) not null,
  days_to_settlement int not null,
  hedge_type text not null check (hedge_type in (
    'forward','option','swap','forward_cover','natural_hedge'
  )),
  effectiveness_status text not null check (effectiveness_status in (
    'highly_effective','effective','partially_effective','ineffective','de_designated'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hedge_eff_r3632 enable row level security;

create index if not exists idx_hedge_eff_r3632_org on public.hedge_eff_r3632(organization_id);
create index if not exists idx_hedge_eff_r3632_month on public.hedge_eff_r3632(period_month);
create index if not exists idx_hedge_eff_r3632_status on public.hedge_eff_r3632(effectiveness_status);

-- =============================================================================
-- TABLE 2: hedge_eff_capa_actions_r3632 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.hedge_eff_capa_actions_r3632 (
  id uuid primary key default gen_random_uuid(),
  hedge_log_id uuid not null references public.hedge_eff_r3632(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'effectiveness_below_band','ineffectiveness_spike','hedge_ratio_imbalance',
    'de_designation_required','oci_reserve_recycling_delay','documentation_gap',
    'settlement_date_mismatch','forecast_transaction_shortfall'
  )),
  root_cause text not null check (root_cause in (
    'hedge_ratio_mismatch','timing_mismatch','basis_risk','credit_valuation_adjustment',
    'counterparty_downgrade','forecast_transaction_change','volatility_spike',
    'documentation_deficiency','interest_rate_reset_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rebalance_hedge_ratio','de_designate_relationship','roll_forward_contract',
    'add_hedge_layer','reclassify_oci_to_pl','update_hedge_documentation',
    'switch_counterparty','reduce_notional','escalate_to_treasury_committee','no_action_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  ineffectiveness_impact_rupees numeric(16,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hedge_eff_capa_actions_r3632 enable row level security;

create index if not exists idx_hedge_eff_capa_r3632_log on public.hedge_eff_capa_actions_r3632(hedge_log_id);
create index if not exists idx_hedge_eff_capa_r3632_status on public.hedge_eff_capa_actions_r3632(capa_status);

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

  -- 16 hedge-effectiveness rows
  insert into public.hedge_eff_r3632 (
    organization_id, hedge_relationship, hedged_item, period_month,
    notional_rupees, hedge_ratio_pct, mtm_gain_loss_rupees, effective_portion_rupees,
    ineffective_portion_rupees, oci_reserve_rupees, effectiveness_pct, days_to_settlement,
    hedge_type, effectiveness_status, trend_dir, notes
  )
  select v_org_id, q.hr, q.hi, q.pm::date,
    q.notl, q.hrp, q.mtm, q.eff,
    q.ineff, q.oci, q.effp, q.dts::int,
    q.ht, q.es, q.td, q.nt
  from (values
    ('HR-USD-FWD-2601','USD CT-scanner import payable — projects','2026-04-01',
     25000000,100.0,1250000,1230000,20000,1230000,98.4,45,'forward','highly_effective','stable','USD forward cover on CT-scanner import payable — within 80-125% band'),
    ('HR-EUR-FWD-2602','EUR MRI coil import payable — projects','2026-04-01',
     18000000,100.0,720000,690000,30000,690000,95.8,60,'forward','highly_effective','improving','EUR forward on MRI coil import — effectiveness improving'),
    ('HR-USD-OPT-2603','USD spare-parts import payable — spare_parts','2026-05-01',
     9000000,90.0,-180000,-150000,-30000,-150000,83.3,30,'option','effective','stable','USD call option hedge on spares — 90% designated cover'),
    ('HR-USD-SWP-2604','USD project term-loan interest — projects','2026-05-01',
     60000000,100.0,2400000,2200000,200000,2200000,91.7,180,'swap','effective','worsening','Interest-rate swap on project loan — ineffectiveness rising on reset gap'),
    ('HR-EUR-FWDC-2605','EUR diagnostics reagent import — diagnostics','2026-05-01',
     12000000,100.0,480000,470000,10000,470000,97.9,40,'forward_cover','highly_effective','stable','EUR forward cover on reagent import payable'),
    ('HR-USD-FWD-2606','USD ventilator import payable — projects','2026-06-01',
     15000000,75.0,900000,640000,260000,640000,71.1,25,'forward','partially_effective','worsening','Under-hedged at 75% — effectiveness below band, rebalance needed'),
    ('HR-USD-FWD-2607','USD cath-lab import payable — projects','2026-06-01',
     40000000,100.0,-3200000,-1400000,-1800000,-1400000,43.8,90,'forward','ineffective','worsening','Forecast transaction downsized — hedge now ineffective, de-designation review'),
    ('HR-EUR-OPT-2608','EUR ultrasound probe import — spare_parts','2026-06-01',
     6000000,80.0,150000,145000,5000,145000,96.7,20,'option','highly_effective','stable','EUR put option on probe import — effective'),
    ('HR-USD-NAT-2609','USD service-export receivable natural hedge — amc_services','2026-06-01',
     8000000,60.0,200000,120000,80000,120000,60.0,120,'natural_hedge','partially_effective','stable','Natural hedge USD export vs import — 60% offset only'),
    ('HR-USD-SWP-2610','USD legacy term-loan swap — projects','2026-04-01',
     30000000,100.0,-1500000,-300000,-1200000,0,20.0,15,'swap','de_designated','worsening','Swap de-designated on counterparty downgrade — recycle OCI to P&L'),
    ('HR-EUR-FWD-2611','EUR PACS software import payable — diagnostics','2026-07-01',
     5000000,100.0,100000,98000,2000,98000,98.0,55,'forward','highly_effective','improving','EUR forward on PACS software import — clean'),
    ('HR-USD-FWDC-2612','USD consumables rolling forward cover — spare_parts','2026-07-01',
     22000000,95.0,660000,610000,50000,610000,92.4,35,'forward_cover','effective','stable','USD rolling forward cover — 95% hedge ratio'),
    ('HR-USD-OPT-2613','USD dialysis machine import — projects','2026-07-01',
     14000000,85.0,-420000,-300000,-120000,-300000,71.4,28,'option','partially_effective','worsening','Option hedge effectiveness slipped below band on volatility spike'),
    ('HR-EUR-SWP-2614','EUR capex facility interest swap — projects','2026-07-01',
     45000000,100.0,1800000,1750000,50000,1750000,97.2,200,'swap','highly_effective','improving','EUR interest swap on capex facility — highly effective'),
    ('HR-USD-FWD-2615','USD endoscopy tower import — projects','2026-07-01',
     11000000,100.0,330000,325000,5000,325000,98.5,48,'forward','highly_effective','stable','USD forward on endoscopy tower import — within band'),
    ('HR-USD-NAT-2616','USD AMC-services receivable natural hedge — amc_services','2026-07-01',
     7000000,50.0,-150000,-60000,-90000,0,40.0,130,'natural_hedge','ineffective','worsening','Natural hedge offset dropped to 40% — reclassify, ineffective')
  ) as q(hr, hi, pm, notl, hrp, mtm, eff, ineff, oci, effp, dts, ht, es, td, nt);

  -- CAPA seed — attach to specific relationships via hedge_relationship
  insert into public.hedge_eff_capa_actions_r3632 (
    hedge_log_id, finding_category, root_cause, corrective_action,
    capa_status, ineffectiveness_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('HR-USD-FWD-2606','effectiveness_below_band','hedge_ratio_mismatch','rebalance_hedge_ratio','in_progress',260000.00,'Treasury — R. Menon','2026-06-20',null,'Add hedge layer to restore 100% ratio; effectiveness re-test pending'),
    ('HR-USD-FWD-2607','de_designation_required','forecast_transaction_change','de_designate_relationship','escalated',1800000.00,'CFO Office','2026-06-25',null,'Cath-lab order downsized — de-designation and OCI recycle under review'),
    ('HR-USD-SWP-2610','oci_reserve_recycling_delay','counterparty_downgrade','reclassify_oci_to_pl','open',1200000.00,'Treasury — R. Menon','2026-06-18',null,'Swap de-designated; recycle OCI 12L to P&L, awaiting audit sign-off'),
    ('HR-USD-SWP-2604','ineffectiveness_spike','interest_rate_reset_gap','roll_forward_contract','verification_pending',200000.00,'Treasury — A. Iyer','2026-06-30',null,'Reset-date gap on project-loan swap — roll to align reset dates'),
    ('HR-USD-OPT-2613','effectiveness_below_band','volatility_spike','add_hedge_layer','open',120000.00,'Treasury — A. Iyer','2026-07-15',null,'Volatility spike on dialysis import option — top up hedge layer'),
    ('HR-USD-NAT-2616','ineffectiveness_spike','basis_risk','reduce_notional','open',90000.00,'FP&A — S. Rao','2026-07-20',null,'AMC receivable natural-hedge offset dropped — reduce designated notional'),
    ('HR-USD-NAT-2609','hedge_ratio_imbalance','hedge_ratio_mismatch','rebalance_hedge_ratio','closed',80000.00,'FP&A — S. Rao','2026-06-10','2026-06-28','Service-export natural hedge rebalanced to 80% designation'),
    ('HR-USD-OPT-2603','documentation_gap','documentation_deficiency','update_hedge_documentation','closed',30000.00,'Treasury — R. Menon','2026-05-20','2026-05-30','Hedge documentation updated for spares option — closed')
  ) as q(hr, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.hedge_eff_r3632 e
    on e.organization_id = v_org_id and e.hedge_relationship = q.hr;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Effectiveness-status distribution
create or replace function public.founder_r3632_effectiveness_status_rollup()
returns table(effectiveness_status text, relationships bigint, total_notional_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hedge_eff_r3632)
  select l.effectiveness_status, count(*)::bigint,
         coalesce(sum(l.notional_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hedge_eff_r3632 l
  group by l.effectiveness_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3632_effectiveness_status_rollup() from public, anon;
grant execute on function public.founder_r3632_effectiveness_status_rollup() to authenticated;

-- 2) Hedge-type scorecard
create or replace function public.founder_r3632_hedge_type_scorecard()
returns table(
  hedge_type text,
  relationships bigint,
  highly_effective bigint,
  effective bigint,
  ineffective bigint,
  total_notional_rupees numeric,
  avg_effectiveness_pct numeric,
  total_oci_reserve_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hedge_type,
    count(*)::bigint,
    count(*) filter (where l.effectiveness_status = 'highly_effective')::bigint,
    count(*) filter (where l.effectiveness_status = 'effective')::bigint,
    count(*) filter (where l.effectiveness_status in ('ineffective','de_designated'))::bigint,
    coalesce(sum(l.notional_rupees),0)::numeric,
    round(avg(l.effectiveness_pct), 1),
    coalesce(sum(l.oci_reserve_rupees),0)::numeric
  from public.hedge_eff_r3632 l
  group by l.hedge_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3632_hedge_type_scorecard() from public, anon;
grant execute on function public.founder_r3632_hedge_type_scorecard() to authenticated;

-- 3) Hedge-type × effectiveness-status matrix
create or replace function public.founder_r3632_hedge_type_status_matrix()
returns table(hedge_type text, effectiveness_status text, relationships bigint, total_notional_rupees numeric, total_ineffective_rupees numeric, avg_effectiveness_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hedge_type, l.effectiveness_status, count(*)::bigint,
    coalesce(sum(l.notional_rupees),0)::numeric,
    coalesce(sum(l.ineffective_portion_rupees),0)::numeric,
    round(avg(l.effectiveness_pct), 1)
  from public.hedge_eff_r3632 l
  group by l.hedge_type, l.effectiveness_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3632_hedge_type_status_matrix() from public, anon;
grant execute on function public.founder_r3632_hedge_type_status_matrix() to authenticated;

-- 4) Monthly effectiveness trend
create or replace function public.founder_r3632_monthly_effectiveness_trend()
returns table(period_month date, relationships bigint, avg_effectiveness_pct numeric, total_effective_rupees numeric, total_ineffective_rupees numeric, total_oci_reserve_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.effectiveness_pct), 1),
    coalesce(sum(l.effective_portion_rupees),0)::numeric,
    coalesce(sum(l.ineffective_portion_rupees),0)::numeric,
    coalesce(sum(l.oci_reserve_rupees),0)::numeric
  from public.hedge_eff_r3632 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3632_monthly_effectiveness_trend() from public, anon;
grant execute on function public.founder_r3632_monthly_effectiveness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3632_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.ineffectiveness_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.hedge_eff_capa_actions_r3632 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3632_capa_status_board() from public, anon;
grant execute on function public.founder_r3632_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3632_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hedge_eff_capa_actions_r3632)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.ineffectiveness_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hedge_eff_capa_actions_r3632 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3632_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3632_root_cause_pareto() to authenticated;

-- 7) Ineffectiveness digest by effectiveness status
create or replace function public.founder_r3632_ineffectiveness_digest()
returns table(
  effectiveness_status text,
  relationships bigint,
  total_notional_rupees numeric,
  total_effective_rupees numeric,
  total_ineffective_rupees numeric,
  total_oci_reserve_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.effectiveness_status, count(*)::bigint,
    coalesce(sum(l.notional_rupees),0)::numeric,
    coalesce(sum(l.effective_portion_rupees),0)::numeric,
    coalesce(sum(l.ineffective_portion_rupees),0)::numeric,
    coalesce(sum(l.oci_reserve_rupees),0)::numeric
  from public.hedge_eff_r3632 l
  group by l.effectiveness_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3632_ineffectiveness_digest() from public, anon;
grant execute on function public.founder_r3632_ineffectiveness_digest() to authenticated;

-- 8) High-risk hedge queue (ineffective / de-designated / below-band / worsening)
create or replace function public.founder_r3632_high_risk_queue()
returns table(
  hedge_relationship text,
  hedged_item text,
  hedge_type text,
  period_month date,
  notional_rupees numeric,
  effectiveness_pct numeric,
  ineffective_portion_rupees numeric,
  effectiveness_status text,
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
  select l.hedge_relationship, l.hedged_item, l.hedge_type, l.period_month,
    l.notional_rupees, l.effectiveness_pct, l.ineffective_portion_rupees,
    l.effectiveness_status, l.trend_dir, l.notes
  from public.hedge_eff_r3632 l
  where l.effectiveness_status in ('ineffective','de_designated','partially_effective')
     or l.effectiveness_pct < 80
     or l.trend_dir = 'worsening'
  order by l.effectiveness_pct asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3632_high_risk_queue() from public, anon;
grant execute on function public.founder_r3632_high_risk_queue() to authenticated;
