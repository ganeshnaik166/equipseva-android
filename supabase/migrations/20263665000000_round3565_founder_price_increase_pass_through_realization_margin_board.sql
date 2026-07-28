-- Round 3565: Founder Price-Increase Pass-Through / Realization Margin Board
-- Cost-inflation price-increase pass-through realization + margin protection per product line —
-- product line × segment × region × cost/list/realized increase × pass-through ratio × margin
-- before/after × revenue impact × realization status × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: price_increase_passthru_r3565 — per-line pass-through realization facts
-- =============================================================================
create table if not exists public.price_increase_passthru_r3565 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  pricing_ref text not null,
  product_line text not null,
  customer_segment text not null check (customer_segment in (
    'private_hospital','government_hospital','diagnostic_chain','nursing_home','medical_college'
  )),
  region text not null check (region in (
    'north','south','east','west'
  )),
  period_month date not null,
  cost_increase_pct numeric(6,2),
  list_increase_pct numeric(6,2),
  realized_increase_pct numeric(6,2),
  pass_through_ratio_pct numeric(6,2),
  margin_before_pct numeric(6,2),
  margin_after_pct numeric(6,2),
  revenue_impact_rupees numeric(14,2),
  realization_status text not null check (realization_status in (
    'fully_passed','partially_passed','absorbed','margin_eroded','pending'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_increase_passthru_r3565 enable row level security;

create index if not exists idx_price_increase_passthru_r3565_org on public.price_increase_passthru_r3565(organization_id);
create index if not exists idx_price_increase_passthru_r3565_month on public.price_increase_passthru_r3565(period_month);
create index if not exists idx_price_increase_passthru_r3565_status on public.price_increase_passthru_r3565(realization_status);

-- =============================================================================
-- TABLE 2: price_increase_passthru_capa_actions_r3565 — CAPA & margin-recovery actions
-- =============================================================================
create table if not exists public.price_increase_passthru_capa_actions_r3565 (
  id uuid primary key default gen_random_uuid(),
  passthru_id uuid not null references public.price_increase_passthru_r3565(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cost_inflation_unrecovered','list_price_lag','discount_leakage','competitive_pressure_absorption',
    'contract_price_lock','margin_erosion','fx_input_cost_spike','freight_surcharge_unpassed'
  )),
  root_cause text not null check (root_cause in (
    'raw_material_price_spike','fx_depreciation','supplier_surcharge','sales_discount_override',
    'long_term_contract_lock','competitive_undercut','delayed_list_revision',
    'freight_logistics_inflation','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'issue_list_price_revision','renegotiate_contract','tighten_discount_policy','add_price_escalation_clause',
    'pass_freight_surcharge','value_engineer_bom','hedge_fx_exposure','escalate_to_pricing_committee','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  margin_impact_pct numeric(6,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_recovery_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_increase_passthru_capa_actions_r3565 enable row level security;

create index if not exists idx_price_increase_passthru_capa_r3565_link on public.price_increase_passthru_capa_actions_r3565(passthru_id);
create index if not exists idx_price_increase_passthru_capa_r3565_status on public.price_increase_passthru_capa_actions_r3565(capa_status);

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

  -- 16 pass-through realization rows
  insert into public.price_increase_passthru_r3565 (
    organization_id, pricing_ref, product_line, customer_segment, region, period_month,
    cost_increase_pct, list_increase_pct, realized_increase_pct, pass_through_ratio_pct,
    margin_before_pct, margin_after_pct, revenue_impact_rupees, realization_status, trend_dir, notes
  )
  select v_org_id, q.pref, q.pline, q.seg, q.rgn, q.pmonth::date,
    q.costinc, q.listinc, q.realinc, q.ptr,
    q.mbefore, q.mafter, q.revimp, q.rstat, q.trend, q.nt
  from (values
    ('PIP-PM-2601','patient_monitors','private_hospital','south','2026-06-01',
     8.0,9.0,8.2,102.5,34.0,34.5,1250000.00,'fully_passed','improving','List revision absorbed by market; monitor margin protected'),
    ('PIP-IP-2602','infusion_pumps','government_hospital','north','2026-06-01',
     7.5,6.0,4.0,53.3,30.0,27.5,-420000.00,'partially_passed','stable','Govt tender price cap limited realization; partial pass-through'),
    ('PIP-VN-2603','ventilators','private_hospital','west','2026-06-01',
     12.0,10.0,3.0,25.0,28.0,20.5,-1800000.00,'margin_eroded','worsening','Post-glut ventilator pricing forced absorption; margin eroded'),
    ('PIP-DM-2604','dialysis_machines','diagnostic_chain','south','2026-06-01',
     9.0,9.5,0.0,0.0,26.0,18.0,-2100000.00,'absorbed','worsening','Multi-year AMC contract locked price; full cost absorbed'),
    ('PIP-US-2605','ultrasound','private_hospital','east','2026-06-01',
     6.0,7.0,6.5,108.3,38.0,38.8,980000.00,'fully_passed','improving','Premium ultrasound demand allowed full pass-through'),
    ('PIP-CT-2606','ct_scanner_service','medical_college','north','2026-06-01',
     10.0,8.0,5.0,50.0,32.0,28.5,-650000.00,'partially_passed','stable','CT service AMC renewal only partially repriced'),
    ('PIP-DF-2607','defibrillators','nursing_home','west','2026-06-01',
     5.5,6.0,5.8,105.5,36.0,36.4,340000.00,'fully_passed','stable','Defibrillator list uptick accepted by accounts'),
    ('PIP-EC-2608','ecg_machines','diagnostic_chain','south','2026-06-01',
     4.0,3.0,1.5,37.5,29.0,26.8,-180000.00,'partially_passed','worsening','ECG price war capped realization'),
    ('PIP-OC-2609','oxygen_concentrators','government_hospital','east','2026-06-01',
     14.0,5.0,2.0,14.3,24.0,14.0,-2400000.00,'margin_eroded','worsening','Import duty spike; tender list price frozen'),
    ('PIP-SL-2610','surgical_lights','private_hospital','north','2026-06-01',
     6.5,7.0,7.0,107.7,40.0,40.5,560000.00,'fully_passed','improving','Surgical lights repriced cleanly'),
    ('PIP-PM-2611','patient_monitors','government_hospital','west','2026-07-01',
     8.5,6.0,3.5,41.2,33.0,29.0,-720000.00,'partially_passed','worsening','Govt monitor tender delayed list revision'),
    ('PIP-IP-2612','infusion_pumps','private_hospital','south','2026-07-01',
     7.0,8.0,7.5,107.1,31.0,31.4,610000.00,'fully_passed','improving','Infusion pump list revision landed with realization'),
    ('PIP-VN-2613','ventilators','medical_college','east','2026-07-01',
     11.0,9.0,0.0,0.0,27.0,18.5,-1950000.00,'absorbed','worsening','Ventilator college contract price lock; no escalation clause'),
    ('PIP-DM-2614','dialysis_machines','private_hospital','north','2026-07-01',
     9.5,10.0,9.8,103.2,27.0,27.6,1420000.00,'fully_passed','improving','Dialysis consumable escalation clause triggered'),
    ('PIP-US-2615','ultrasound','nursing_home','west','2026-07-01',
     6.0,5.0,4.0,66.7,37.0,35.5,-240000.00,'partially_passed','stable','Ultrasound partial pass in price-sensitive segment'),
    ('PIP-CT-2616','ct_scanner_service','private_hospital','south','2026-07-01',
     10.5,8.0,8.0,76.2,33.0,31.5,210000.00,'pending','stable','CT service reprice under negotiation; realization pending')
  ) as q(pref, pline, seg, rgn, pmonth, costinc, listinc, realinc, ptr, mbefore, mafter, revimp, rstat, trend, nt);

  -- CAPA seed — attach to specific lines via pricing_ref
  insert into public.price_increase_passthru_capa_actions_r3565 (
    passthru_id, finding_category, root_cause, corrective_action,
    capa_status, margin_impact_pct, owner, target_closure_date, actual_closure_date,
    estimated_recovery_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.mimp, q.own, q.tcd::date, q.acd::date,
    q.rec, q.nt
  from (values
    ('PIP-VN-2603','margin_erosion','competitive_undercut','renegotiate_contract','in_progress',-7.5,'Pricing Lead - Rao','2026-08-15',null,900000.00,'Renegotiating ventilator floor price with three large accounts'),
    ('PIP-DM-2604','contract_price_lock','long_term_contract_lock','add_price_escalation_clause','open',-8.0,'Contracts - Nair','2026-09-01',null,1500000.00,'Adding CPI-linked escalation clause at AMC renewal'),
    ('PIP-OC-2609','fx_input_cost_spike','fx_depreciation','hedge_fx_exposure','escalated',-10.0,'CFO Office - Mehta','2026-08-10',null,1800000.00,'Import duty and FX hit; escalated to pricing committee for tender rebid'),
    ('PIP-VN-2613','contract_price_lock','long_term_contract_lock','add_price_escalation_clause','open',-8.5,'Contracts - Nair','2026-09-05',null,1200000.00,'Ventilator college contract lacks escalation clause'),
    ('PIP-IP-2602','list_price_lag','delayed_list_revision','issue_list_price_revision','verification_pending',-2.5,'Product Mktg - Iyer','2026-08-20',null,380000.00,'Govt list revision filed; awaiting realization confirmation'),
    ('PIP-CT-2606','discount_leakage','sales_discount_override','tighten_discount_policy','in_progress',-3.5,'Sales Ops - Khan','2026-08-25',null,450000.00,'Field discount overrides exceeding matrix; tightening approvals'),
    ('PIP-EC-2608','competitive_pressure_absorption','competitive_undercut','value_engineer_bom','open',-2.2,'R&D - Bose','2026-09-15',null,260000.00,'Value-engineering ECG BOM to protect margin under price war'),
    ('PIP-PM-2611','list_price_lag','delayed_list_revision','issue_list_price_revision','closed',-4.0,'Product Mktg - Iyer','2026-07-20','2026-07-18',700000.00,'Govt monitor list revision issued and realized next cycle')
  ) as q(pref, fc, rc, ca, cst, mimp, own, tcd, acd, rec, nt)
  join public.price_increase_passthru_r3565 e
    on e.organization_id = v_org_id and e.pricing_ref = q.pref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Realization status distribution
create or replace function public.founder_r3565_realization_status_rollup()
returns table(realization_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_increase_passthru_r3565)
  select l.realization_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.price_increase_passthru_r3565 l
  group by l.realization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3565_realization_status_rollup() from public, anon;
grant execute on function public.founder_r3565_realization_status_rollup() to authenticated;

-- 2) Product-line scorecard
create or replace function public.founder_r3565_product_line_scorecard()
returns table(
  product_line text,
  lines bigint,
  fully_passed bigint,
  partially_passed bigint,
  absorbed_eroded bigint,
  avg_cost_increase_pct numeric,
  avg_realized_increase_pct numeric,
  avg_pass_through_ratio_pct numeric,
  total_revenue_impact_rupees numeric
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
    count(*) filter (where l.realization_status = 'fully_passed')::bigint,
    count(*) filter (where l.realization_status = 'partially_passed')::bigint,
    count(*) filter (where l.realization_status in ('absorbed','margin_eroded'))::bigint,
    round(avg(l.cost_increase_pct), 2),
    round(avg(l.realized_increase_pct), 2),
    round(avg(l.pass_through_ratio_pct), 2),
    coalesce(sum(l.revenue_impact_rupees), 0)::numeric
  from public.price_increase_passthru_r3565 l
  group by l.product_line
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3565_product_line_scorecard() from public, anon;
grant execute on function public.founder_r3565_product_line_scorecard() to authenticated;

-- 3) Product-line x realization-status matrix
create or replace function public.founder_r3565_line_status_matrix()
returns table(
  product_line text,
  realization_status text,
  lines bigint,
  avg_pass_through_ratio_pct numeric,
  total_revenue_impact_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line, l.realization_status, count(*)::bigint,
    round(avg(l.pass_through_ratio_pct), 2),
    coalesce(sum(l.revenue_impact_rupees), 0)::numeric
  from public.price_increase_passthru_r3565 l
  group by l.product_line, l.realization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3565_line_status_matrix() from public, anon;
grant execute on function public.founder_r3565_line_status_matrix() to authenticated;

-- 4) Monthly pass-through trend
create or replace function public.founder_r3565_monthly_passthru_trend()
returns table(
  period_month date,
  lines bigint,
  avg_cost_increase_pct numeric,
  avg_realized_increase_pct numeric,
  avg_pass_through_ratio_pct numeric,
  total_revenue_impact_rupees numeric,
  eroded_or_absorbed bigint
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
    round(avg(l.cost_increase_pct), 2),
    round(avg(l.realized_increase_pct), 2),
    round(avg(l.pass_through_ratio_pct), 2),
    coalesce(sum(l.revenue_impact_rupees), 0)::numeric,
    count(*) filter (where l.realization_status in ('absorbed','margin_eroded'))::bigint
  from public.price_increase_passthru_r3565 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3565_monthly_passthru_trend() from public, anon;
grant execute on function public.founder_r3565_monthly_passthru_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3565_capa_status_board()
returns table(capa_status text, findings bigint, avg_margin_impact_pct numeric, total_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.margin_impact_pct), 2),
    coalesce(sum(c.estimated_recovery_rupees), 0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.price_increase_passthru_capa_actions_r3565 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3565_capa_status_board() from public, anon;
grant execute on function public.founder_r3565_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3565_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_increase_passthru_capa_actions_r3565)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_recovery_rupees), 0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.price_increase_passthru_capa_actions_r3565 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3565_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3565_root_cause_pareto() to authenticated;

-- 7) Margin-impact digest
create or replace function public.founder_r3565_margin_impact_digest()
returns table(
  realization_status text,
  lines bigint,
  avg_margin_before_pct numeric,
  avg_margin_after_pct numeric,
  avg_margin_delta_pct numeric,
  total_revenue_impact_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.realization_status,
    count(*)::bigint,
    round(avg(l.margin_before_pct), 2),
    round(avg(l.margin_after_pct), 2),
    round(avg(l.margin_after_pct - l.margin_before_pct), 2),
    coalesce(sum(l.revenue_impact_rupees), 0)::numeric
  from public.price_increase_passthru_r3565 l
  group by l.realization_status
  order by round(avg(l.margin_after_pct - l.margin_before_pct), 2) asc;
end;
$$;

revoke execute on function public.founder_r3565_margin_impact_digest() from public, anon;
grant execute on function public.founder_r3565_margin_impact_digest() to authenticated;

-- 8) High-risk queue (margin-eroded / absorbed / worsening)
create or replace function public.founder_r3565_high_risk_queue()
returns table(
  product_line text,
  pricing_ref text,
  customer_segment text,
  region text,
  period_month date,
  cost_increase_pct numeric,
  realized_increase_pct numeric,
  pass_through_ratio_pct numeric,
  margin_before_pct numeric,
  margin_after_pct numeric,
  revenue_impact_rupees numeric,
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
  select l.product_line, l.pricing_ref, l.customer_segment, l.region, l.period_month,
    l.cost_increase_pct, l.realized_increase_pct, l.pass_through_ratio_pct,
    l.margin_before_pct, l.margin_after_pct, l.revenue_impact_rupees,
    l.realization_status, l.trend_dir, l.notes
  from public.price_increase_passthru_r3565 l
  where l.realization_status in ('margin_eroded','absorbed','partially_passed')
     or l.trend_dir = 'worsening'
     or l.pass_through_ratio_pct < 60
  order by l.pass_through_ratio_pct asc nulls first, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3565_high_risk_queue() from public, anon;
grant execute on function public.founder_r3565_high_risk_queue() to authenticated;
