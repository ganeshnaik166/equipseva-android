-- Round 3461: Founder Price-Volume-Mix Margin-Waterfall Variance Board
-- Gross-margin variance decomposed into price / volume / mix / cost effects per product line —
-- base vs actual margin, total variance, driver classification, verdict, trend direction & CAPA closure.

-- =============================================================================
-- TABLE 1: price_volume_mix_margin_r3461 — per product-line monthly margin-waterfall decomposition
-- =============================================================================
create table if not exists public.price_volume_mix_margin_r3461 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  variance_ref text not null,
  product_line text not null,
  period_month date not null,
  base_margin_rupees numeric(14,2),
  price_effect_rupees numeric(14,2),
  volume_effect_rupees numeric(14,2),
  mix_effect_rupees numeric(14,2),
  cost_effect_rupees numeric(14,2),
  actual_margin_rupees numeric(14,2),
  total_variance_rupees numeric(14,2),
  variance_driver text not null check (variance_driver in (
    'price_led','volume_led','mix_led','cost_led','balanced'
  )),
  variance_verdict text not null check (variance_verdict in (
    'favorable','neutral','unfavorable'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_volume_mix_margin_r3461 enable row level security;

create index if not exists idx_pvm_margin_r3461_org on public.price_volume_mix_margin_r3461(organization_id);
create index if not exists idx_pvm_margin_r3461_month on public.price_volume_mix_margin_r3461(period_month);
create index if not exists idx_pvm_margin_r3461_verdict on public.price_volume_mix_margin_r3461(variance_verdict);

-- =============================================================================
-- TABLE 2: price_volume_mix_margin_capa_actions_r3461 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.price_volume_mix_margin_capa_actions_r3461 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  variance_log_id uuid not null references public.price_volume_mix_margin_r3461(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'price_erosion','volume_shortfall','adverse_mix_shift','cost_overrun',
    'discount_leakage','fx_input_cost','freight_cost_spike','margin_dilution'
  )),
  root_cause text not null check (root_cause in (
    'competitive_pricing_pressure','tender_discount','demand_slowdown','channel_mix_shift',
    'raw_material_inflation','vendor_price_increase','logistics_cost_rise','forex_depreciation',
    'product_mix_downtrade','under_recovery_of_amc','pending_analysis'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_list','tighten_discount_policy','renegotiate_vendor_contract','shift_sales_mix',
    'hedge_forex','optimize_freight','volume_recovery_plan','value_engineering',
    'escalate_to_pricing_committee','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_volume_mix_margin_capa_actions_r3461 enable row level security;

create index if not exists idx_pvm_margin_capa_r3461_log on public.price_volume_mix_margin_capa_actions_r3461(variance_log_id);
create index if not exists idx_pvm_margin_capa_r3461_status on public.price_volume_mix_margin_capa_actions_r3461(capa_status);

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

  -- 16 margin-waterfall rows
  insert into public.price_volume_mix_margin_r3461 (
    organization_id, variance_ref, product_line, period_month,
    base_margin_rupees, price_effect_rupees, volume_effect_rupees, mix_effect_rupees, cost_effect_rupees,
    actual_margin_rupees, total_variance_rupees, variance_driver, variance_verdict, trend_dir, notes
  )
  select v_org_id, q.vref, q.pline, q.pmon::date,
    q.bmar, q.prc, q.vol, q.mix, q.cst,
    q.amar, q.tvar, q.vdrv, q.vvrd, q.tdir, q.nt
  from (values
    ('PVM-PMON-2606','Patient Monitors','2026-06-01',
     1200000,45000,80000,15000,-30000,1310000,110000,'volume_led','favorable','improving','Monitor unit volumes up on new ICU orders; input cost mild drag'),
    ('PVM-PMON-2607','Patient Monitors','2026-07-01',
     1310000,20000,-35000,10000,-25000,1280000,-30000,'volume_led','unfavorable','worsening','Order pull-in reversed in July; freight on spares eroded margin'),
    ('PVM-VENT-2606','Ventilators','2026-06-01',
     2100000,120000,60000,40000,-50000,2270000,170000,'price_led','favorable','improving','List price hike held; premium mix and volume both additive'),
    ('PVM-VENT-2607','Ventilators','2026-07-01',
     2270000,-80000,-40000,-20000,-60000,2070000,-200000,'price_led','unfavorable','worsening','Import competition forced discounting; cost inflation compounded'),
    ('PVM-DIAL-2606','Dialysis Machines','2026-06-01',
     1750000,30000,25000,-60000,-20000,1725000,-25000,'mix_led','unfavorable','stable','Downtrade to entry dialysis SKUs dented mix despite volume gain'),
    ('PVM-DIAL-2607','Dialysis Machines','2026-07-01',
     1725000,15000,40000,20000,10000,1810000,85000,'volume_led','favorable','improving','Volume recovery plan worked; consumable attach improved cost line'),
    ('PVM-CT-2606','Imaging CT','2026-06-01',
     3400000,200000,-120000,50000,-90000,3440000,40000,'price_led','neutral','stable','Price realization offset soft CT volumes and tube cost inflation'),
    ('PVM-CT-2607','Imaging CT','2026-07-01',
     3440000,-150000,-200000,-30000,-110000,2950000,-490000,'volume_led','unfavorable','worsening','Two hospital tenders lost; sharp volume and price fall in CT line'),
    ('PVM-USG-2606','Imaging Ultrasound','2026-06-01',
     980000,25000,35000,12000,-8000,1044000,64000,'volume_led','favorable','improving','Portable USG demand strong across secondary-care accounts'),
    ('PVM-INFP-2606','Infusion Pumps','2026-06-01',
     620000,-12000,18000,5000,-30000,601000,-19000,'cost_led','unfavorable','stable','Polymer raw-material inflation dominated the pump margin bridge'),
    ('PVM-INFP-2607','Infusion Pumps','2026-07-01',
     601000,8000,22000,4000,-15000,620000,19000,'volume_led','neutral','improving','Volume-led recovery; cost drag easing after VE actions'),
    ('PVM-STER-2606','Sterilizers','2026-06-01',
     540000,10000,-25000,-8000,-18000,499000,-41000,'volume_led','unfavorable','worsening','Sterilizer volumes declining third month; utility cost adverse'),
    ('PVM-DEFI-2606','Defibrillators','2026-06-01',
     760000,30000,20000,10000,-12000,808000,48000,'price_led','favorable','improving','AED refresh cycle lifted price and volume in defib line'),
    ('PVM-LAB-2606','Lab Analyzers','2026-06-01',
     2600000,90000,70000,-140000,-60000,2560000,-40000,'mix_led','unfavorable','worsening','Downtrade to entry analyzers hurt mix; reagent cost up'),
    ('PVM-AMC-2606','AMC Services','2026-06-01',
     1450000,60000,45000,20000,15000,1590000,140000,'price_led','favorable','improving','AMC renewal repricing and higher coverage lifted all effects'),
    ('PVM-SPAR-2606','Spares & Consumables','2026-06-01',
     880000,12000,8000,3000,-5000,898000,18000,'balanced','neutral','stable','Balanced small effects across spares; no single dominant driver')
  ) as q(vref, pline, pmon, bmar, prc, vol, mix, cst, amar, tvar, vdrv, vvrd, tdir, nt);

  -- CAPA seed — attach to specific variance rows via variance_ref
  insert into public.price_volume_mix_margin_capa_actions_r3461 (
    organization_id, variance_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PVM-CT-2607','volume_shortfall','demand_slowdown','volume_recovery_plan','in_progress',490000,'Rajesh Menon (VP Sales)','2026-08-15',null,'CT volume collapsed after two lost tenders; win-back plan under execution'),
    ('PVM-VENT-2607','price_erosion','competitive_pricing_pressure','reprice_list','open',200000,'Anita Rao (Product Mgr)','2026-08-20',null,'Ventilator ASP eroded by imports; list reprice and bundle under review'),
    ('PVM-LAB-2606','adverse_mix_shift','product_mix_downtrade','shift_sales_mix','open',140000,'Suresh Iyer (Sales Head)','2026-08-10',null,'Push premium analyzers and reagent contracts to reverse mix downtrade'),
    ('PVM-STER-2606','volume_shortfall','demand_slowdown','volume_recovery_plan','escalated',41000,'Priya Nair (Region Mgr)','2026-07-31',null,'Sterilizer volumes down three months; escalated to regional leadership'),
    ('PVM-PMON-2607','freight_cost_spike','logistics_cost_rise','optimize_freight','verification_pending',30000,'Karthik Reddy (Ops)','2026-08-05',null,'Freight spike on monitor spares; new courier rates in verification'),
    ('PVM-DIAL-2606','margin_dilution','channel_mix_shift','tighten_discount_policy','closed',25000,'Deepa Shah (Commercial)','2026-07-15','2026-07-12','Distributor channel discounts tightened; dialysis mix normalized'),
    ('PVM-INFP-2606','cost_overrun','raw_material_inflation','value_engineering','in_progress',30000,'Vikram Joshi (R&D)','2026-08-25',null,'Pump BOM cost up on polymer inflation; value-engineering in progress'),
    ('PVM-CT-2606','fx_input_cost','forex_depreciation','hedge_forex','overdue',90000,'Meera Krishnan (Finance)','2026-07-10',null,'Imported CT tube cost up on INR depreciation; forex hedge overdue')
  ) as q(vref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.price_volume_mix_margin_r3461 e
    on e.organization_id = v_org_id and e.variance_ref = q.vref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Variance verdict distribution
create or replace function public.founder_r3461_variance_verdict_rollup()
returns table(variance_verdict text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_volume_mix_margin_r3461)
  select l.variance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.price_volume_mix_margin_r3461 l
  group by l.variance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3461_variance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3461_variance_verdict_rollup() to authenticated;

-- 2) Product-line scorecard
create or replace function public.founder_r3461_product_line_scorecard()
returns table(
  product_line text,
  entries bigint,
  favorable bigint,
  neutral bigint,
  unfavorable bigint,
  total_variance_rupees numeric,
  avg_variance_rupees numeric,
  worsening bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line,
    count(*)::bigint,
    count(*) filter (where l.variance_verdict = 'favorable')::bigint,
    count(*) filter (where l.variance_verdict = 'neutral')::bigint,
    count(*) filter (where l.variance_verdict = 'unfavorable')::bigint,
    coalesce(sum(l.total_variance_rupees),0)::numeric,
    round(avg(l.total_variance_rupees), 0),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.price_volume_mix_margin_r3461 l
  group by l.product_line
  order by coalesce(sum(l.total_variance_rupees),0) asc;
end;
$$;

revoke execute on function public.founder_r3461_product_line_scorecard() from public, anon;
grant execute on function public.founder_r3461_product_line_scorecard() to authenticated;

-- 3) Driver × verdict matrix
create or replace function public.founder_r3461_driver_verdict_matrix()
returns table(
  variance_driver text,
  variance_verdict text,
  entries bigint,
  total_variance_rupees numeric,
  avg_variance_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.variance_driver, l.variance_verdict, count(*)::bigint,
    coalesce(sum(l.total_variance_rupees),0)::numeric,
    round(avg(l.total_variance_rupees), 0)
  from public.price_volume_mix_margin_r3461 l
  group by l.variance_driver, l.variance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3461_driver_verdict_matrix() from public, anon;
grant execute on function public.founder_r3461_driver_verdict_matrix() to authenticated;

-- 4) Monthly variance trend
create or replace function public.founder_r3461_monthly_variance_trend()
returns table(
  period_month date,
  entries bigint,
  favorable bigint,
  unfavorable bigint,
  total_variance_rupees numeric,
  price_effect_rupees numeric,
  cost_effect_rupees numeric
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
    count(*) filter (where l.variance_verdict = 'favorable')::bigint,
    count(*) filter (where l.variance_verdict = 'unfavorable')::bigint,
    coalesce(sum(l.total_variance_rupees),0)::numeric,
    coalesce(sum(l.price_effect_rupees),0)::numeric,
    coalesce(sum(l.cost_effect_rupees),0)::numeric
  from public.price_volume_mix_margin_r3461 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3461_monthly_variance_trend() from public, anon;
grant execute on function public.founder_r3461_monthly_variance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3461_capa_status_board()
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
  from public.price_volume_mix_margin_capa_actions_r3461 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3461_capa_status_board() from public, anon;
grant execute on function public.founder_r3461_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3461_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_volume_mix_margin_capa_actions_r3461)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.price_volume_mix_margin_capa_actions_r3461 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3461_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3461_root_cause_pareto() to authenticated;

-- 7) Margin-impact digest (waterfall components)
create or replace function public.founder_r3461_margin_impact_digest()
returns table(effect_component text, total_rupees numeric, favorable_rows bigint, adverse_rows bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select 'price'::text, coalesce(sum(l.price_effect_rupees),0)::numeric,
    count(*) filter (where l.price_effect_rupees > 0)::bigint,
    count(*) filter (where l.price_effect_rupees < 0)::bigint
  from public.price_volume_mix_margin_r3461 l
  union all
  select 'volume'::text, coalesce(sum(l.volume_effect_rupees),0)::numeric,
    count(*) filter (where l.volume_effect_rupees > 0)::bigint,
    count(*) filter (where l.volume_effect_rupees < 0)::bigint
  from public.price_volume_mix_margin_r3461 l
  union all
  select 'mix'::text, coalesce(sum(l.mix_effect_rupees),0)::numeric,
    count(*) filter (where l.mix_effect_rupees > 0)::bigint,
    count(*) filter (where l.mix_effect_rupees < 0)::bigint
  from public.price_volume_mix_margin_r3461 l
  union all
  select 'cost'::text, coalesce(sum(l.cost_effect_rupees),0)::numeric,
    count(*) filter (where l.cost_effect_rupees > 0)::bigint,
    count(*) filter (where l.cost_effect_rupees < 0)::bigint
  from public.price_volume_mix_margin_r3461 l;
end;
$$;

revoke execute on function public.founder_r3461_margin_impact_digest() from public, anon;
grant execute on function public.founder_r3461_margin_impact_digest() to authenticated;

-- 8) High-risk variance queue (unfavorable / worsening / large-variance)
create or replace function public.founder_r3461_high_risk_queue()
returns table(
  product_line text,
  variance_ref text,
  period_month date,
  variance_driver text,
  variance_verdict text,
  trend_dir text,
  total_variance_rupees numeric,
  actual_margin_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line, l.variance_ref, l.period_month, l.variance_driver,
    l.variance_verdict, l.trend_dir, l.total_variance_rupees, l.actual_margin_rupees, l.notes
  from public.price_volume_mix_margin_r3461 l
  where l.variance_verdict = 'unfavorable'
     or l.trend_dir = 'worsening'
     or abs(l.total_variance_rupees) >= 100000
  order by l.total_variance_rupees asc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3461_high_risk_queue() from public, anon;
grant execute on function public.founder_r3461_high_risk_queue() to authenticated;
