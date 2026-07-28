-- Round 3553: Founder Inventory Carrying-Cost / Holding-Cost Optimization Board
-- Inventory carrying / holding cost (capital + storage + obsolescence + insurance) optimization
-- category × warehouse × avg inventory value × cost components × carrying-cost % vs target × trend × CAPA

-- =============================================================================
-- TABLE 1: carrying_cost_r3553 — per category/warehouse carrying-cost lines
-- =============================================================================
create table if not exists public.carrying_cost_r3553 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category text not null,
  warehouse text not null,
  sku_code text not null,
  avg_inventory_value_rupees numeric(14,2) not null,
  capital_cost_rupees numeric(14,2) not null,
  storage_cost_rupees numeric(14,2) not null,
  obsolescence_cost_rupees numeric(14,2) not null,
  insurance_cost_rupees numeric(14,2) not null,
  total_carrying_cost_rupees numeric(14,2) not null,
  carrying_cost_pct numeric(6,2) not null,
  target_pct numeric(6,2) not null,
  cost_status text not null check (cost_status in (
    'optimal','acceptable','elevated','excessive'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.carrying_cost_r3553 enable row level security;

create index if not exists idx_carrying_cost_r3553_org on public.carrying_cost_r3553(organization_id);
create index if not exists idx_carrying_cost_r3553_month on public.carrying_cost_r3553(period_month);
create index if not exists idx_carrying_cost_r3553_status on public.carrying_cost_r3553(cost_status);

-- =============================================================================
-- TABLE 2: carrying_cost_capa_actions_r3553 — CAPA & optimization actions
-- =============================================================================
create table if not exists public.carrying_cost_capa_actions_r3553 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cost_line_id uuid not null references public.carrying_cost_r3553(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excess_stock_holding','slow_moving_obsolescence','overstocked_capital_lockup',
    'high_storage_footprint','insurance_over_coverage','deadstock_writeoff_risk',
    'target_variance_breach','warehouse_space_inefficiency','carrying_cost_ratio_high'
  )),
  root_cause text not null check (root_cause in (
    'over_forecasting','bulk_purchase_discount_trap','demand_drop','supplier_moq_constraint',
    'poor_slotting','expiry_near','no_reorder_discipline','capital_tied_up',
    'pending_investigation','warehouse_lease_overhead'
  )),
  corrective_action text not null check (corrective_action in (
    'liquidate_deadstock','renegotiate_moq','reduce_safety_stock','consolidate_warehouse',
    'right_size_insurance','implement_jit','markdown_clearance','improve_forecast_model',
    'redeploy_to_high_turn_site','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  savings_impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.carrying_cost_capa_actions_r3553 enable row level security;

create index if not exists idx_carrying_cost_capa_r3553_line on public.carrying_cost_capa_actions_r3553(cost_line_id);
create index if not exists idx_carrying_cost_capa_r3553_status on public.carrying_cost_capa_actions_r3553(capa_status);

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

  -- 16 carrying-cost lines
  insert into public.carrying_cost_r3553 (
    organization_id, category, warehouse, sku_code,
    avg_inventory_value_rupees, capital_cost_rupees, storage_cost_rupees,
    obsolescence_cost_rupees, insurance_cost_rupees, total_carrying_cost_rupees,
    carrying_cost_pct, target_pct, cost_status, period_month, trend_dir, notes
  )
  select v_org_id, q.cat, q.wh, q.sku,
    q.aiv::numeric, q.cap::numeric, q.stor::numeric,
    q.obs::numeric, q.ins::numeric, q.tcc::numeric,
    q.ccp::numeric, q.tgt::numeric, q.cs, q.pm::date, q.td, q.nt
  from (values
    ('imaging_spares','Chennai Central','IMG-SPR-CHN',4800000.00,456000.00,96000.00,60000.00,24000.00,636000.00,13.3,15.0,'optimal','2026-07-01','improving','Imaging spares turns healthy post JIT rollout'),
    ('patient_monitoring','Mumbai Hub','MON-PRT-MUM',3200000.00,352000.00,96000.00,128000.00,22400.00,598400.00,18.7,15.0,'elevated','2026-07-01','worsening','Monitoring boards overstocked; obsolescence rising'),
    ('ventilator_parts','Delhi NCR DC','VNT-PRT-DEL',6500000.00,650000.00,130000.00,97500.00,32500.00,910000.00,14.0,16.0,'optimal','2026-07-01','stable','Ventilator spares within target after COVID drawdown'),
    ('dialysis_consumables','Bengaluru DC','DLY-CON-BLR',2800000.00,336000.00,112000.00,168000.00,19600.00,635600.00,22.7,16.0,'excessive','2026-07-01','worsening','Dialysis consumables near expiry; deadstock risk'),
    ('surgical_instruments','Hyderabad DC','SRG-INS-HYD',5400000.00,540000.00,108000.00,81000.00,27000.00,756000.00,14.0,15.0,'optimal','2026-07-01','improving','Surgical instrument stock right-sized'),
    ('oxygen_plant_spares','Kolkata DC','OXY-SPR-KOL',3900000.00,468000.00,117000.00,175500.00,27300.00,787800.00,20.2,16.0,'excessive','2026-07-01','worsening','PSA oxygen plant spares slow-moving since pandemic'),
    ('imaging_spares','Mumbai Hub','IMG-SPR-MUM',7100000.00,710000.00,142000.00,106500.00,35500.00,994000.00,14.0,15.0,'acceptable','2026-06-01','stable','CT and MRI coil spares stable'),
    ('patient_monitoring','Delhi NCR DC','MON-PRT-DEL',2600000.00,286000.00,78000.00,91000.00,18200.00,473200.00,18.2,15.0,'elevated','2026-06-01','worsening','SpO2 module boards accumulating'),
    ('infusion_pumps','Chennai Central','INF-PMP-CHN',3400000.00,340000.00,85000.00,68000.00,20400.00,513400.00,15.1,15.0,'acceptable','2026-06-01','stable','Infusion pump spares marginally over target'),
    ('lab_analyzer_spares','Bengaluru DC','LAB-SPR-BLR',4200000.00,462000.00,105000.00,84000.00,25200.00,676200.00,16.1,15.0,'elevated','2026-06-01','stable','Analyzer reagent probes slightly elevated'),
    ('sterilizer_spares','Hyderabad DC','STR-SPR-HYD',2100000.00,210000.00,63000.00,42000.00,14700.00,329700.00,15.7,16.0,'acceptable','2026-06-01','improving','Autoclave spares improving after redeploy'),
    ('endoscopy_spares','Kolkata DC','END-SPR-KOL',3600000.00,432000.00,108000.00,162000.00,25200.00,727200.00,20.2,16.0,'excessive','2026-06-01','worsening','Endoscope optics obsolete models overstocked'),
    ('imaging_spares','Delhi NCR DC','IMG-SPR-DEL',5900000.00,590000.00,118000.00,88500.00,29500.00,826000.00,14.0,15.0,'optimal','2026-05-01','improving','Detector spares consolidated to one DC'),
    ('dialysis_consumables','Chennai Central','DLY-CON-CHN',2400000.00,288000.00,96000.00,144000.00,16800.00,544800.00,22.7,16.0,'excessive','2026-05-01','worsening','RO membrane consumables aging; markdown needed'),
    ('patient_monitoring','Bengaluru DC','MON-PRT-BLR',3000000.00,300000.00,75000.00,60000.00,18000.00,453000.00,15.1,15.0,'acceptable','2026-05-01','stable','Telemetry spares balanced'),
    ('ventilator_parts','Hyderabad DC','VNT-PRT-HYD',4600000.00,460000.00,92000.00,138000.00,27600.00,717600.00,15.6,15.0,'elevated','2026-05-01','worsening','Ventilator valve kits building up post demand drop')
  ) as q(cat, wh, sku, aiv, cap, stor, obs, ins, tcc, ccp, tgt, cs, pm, td, nt);

  -- CAPA seed — attach to specific lines via sku_code
  insert into public.carrying_cost_capa_actions_r3553 (
    organization_id, cost_line_id, finding_category, root_cause, corrective_action,
    capa_status, savings_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.sav::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DLY-CON-BLR','slow_moving_obsolescence','expiry_near','markdown_clearance','in_progress',180000.00,'Priya Nair','2026-08-15',null,'Dialysis consumables near expiry — clearance markdown launched'),
    ('OXY-SPR-KOL','deadstock_writeoff_risk','demand_drop','liquidate_deadstock','open',240000.00,'Rakesh Menon','2026-08-20',null,'PSA plant spares dead since pandemic — liquidation plan drafted'),
    ('MON-PRT-MUM','excess_stock_holding','over_forecasting','reduce_safety_stock','open',95000.00,'Anita Desai','2026-08-10',null,'Cut safety stock on monitoring boards after forecast reset'),
    ('END-SPR-KOL','slow_moving_obsolescence','expiry_near','markdown_clearance','escalated',210000.00,'Rakesh Menon','2026-08-05',null,'Obsolete endoscope optics — escalated to head of operations'),
    ('DLY-CON-CHN','deadstock_writeoff_risk','expiry_near','markdown_clearance','verification_pending',150000.00,'Priya Nair','2026-08-12',null,'RO membrane markdown done — verify sell-through this cycle'),
    ('VNT-PRT-HYD','excess_stock_holding','demand_drop','redeploy_to_high_turn_site','closed',120000.00,'Suresh Iyer','2026-07-20','2026-07-18','Valve kits redeployed to Delhi DC — closed'),
    ('MON-PRT-DEL','overstocked_capital_lockup','no_reorder_discipline','implement_jit','overdue',88000.00,'Anita Desai','2026-07-15',null,'SpO2 boards JIT rollout overdue — vendor lead time slip'),
    ('LAB-SPR-BLR','carrying_cost_ratio_high','capital_tied_up','renegotiate_moq','open',64000.00,'Divya Rao','2026-08-25',null,'Analyzer probe MOQ too high — renegotiating with OEM')
  ) as q(sku, fc, rc, ca, cst, sav, own, tcd, acd, nt)
  join public.carrying_cost_r3553 e
    on e.organization_id = v_org_id and e.sku_code = q.sku;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Cost-status distribution
create or replace function public.founder_r3553_cost_status_rollup()
returns table(cost_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.carrying_cost_r3553)
  select l.cost_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.carrying_cost_r3553 l
  group by l.cost_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3553_cost_status_rollup() from public, anon;
grant execute on function public.founder_r3553_cost_status_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3553_category_scorecard()
returns table(
  category text,
  total_lines bigint,
  optimal bigint,
  acceptable bigint,
  elevated bigint,
  excessive bigint,
  total_carrying_cost_rupees numeric,
  avg_carrying_cost_pct numeric,
  avg_target_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.cost_status = 'optimal')::bigint,
    count(*) filter (where l.cost_status = 'acceptable')::bigint,
    count(*) filter (where l.cost_status = 'elevated')::bigint,
    count(*) filter (where l.cost_status = 'excessive')::bigint,
    coalesce(sum(l.total_carrying_cost_rupees),0)::numeric,
    round(avg(l.carrying_cost_pct), 1),
    round(avg(l.target_pct), 1)
  from public.carrying_cost_r3553 l
  group by l.category
  order by coalesce(sum(l.total_carrying_cost_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3553_category_scorecard() from public, anon;
grant execute on function public.founder_r3553_category_scorecard() to authenticated;

-- 3) Category × cost-status matrix
create or replace function public.founder_r3553_category_status_matrix()
returns table(category text, cost_status text, lines bigint, total_carrying_cost_rupees numeric, avg_carrying_cost_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.cost_status, count(*)::bigint,
    coalesce(sum(l.total_carrying_cost_rupees),0)::numeric,
    round(avg(l.carrying_cost_pct), 1)
  from public.carrying_cost_r3553 l
  group by l.category, l.cost_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3553_category_status_matrix() from public, anon;
grant execute on function public.founder_r3553_category_status_matrix() to authenticated;

-- 4) Monthly carrying-cost trend
create or replace function public.founder_r3553_monthly_carrying_cost_trend()
returns table(
  period_month date,
  lines bigint,
  total_carrying_cost_rupees numeric,
  total_capital_cost_rupees numeric,
  total_obsolescence_cost_rupees numeric,
  avg_carrying_cost_pct numeric
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
    coalesce(sum(l.total_carrying_cost_rupees),0)::numeric,
    coalesce(sum(l.capital_cost_rupees),0)::numeric,
    coalesce(sum(l.obsolescence_cost_rupees),0)::numeric,
    round(avg(l.carrying_cost_pct), 1)
  from public.carrying_cost_r3553 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3553_monthly_carrying_cost_trend() from public, anon;
grant execute on function public.founder_r3553_monthly_carrying_cost_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3553_capa_status_board()
returns table(capa_status text, findings bigint, avg_savings_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.savings_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.carrying_cost_capa_actions_r3553 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3553_capa_status_board() from public, anon;
grant execute on function public.founder_r3553_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3553_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.carrying_cost_capa_actions_r3553)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.savings_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.carrying_cost_capa_actions_r3553 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3553_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3553_root_cause_pareto() to authenticated;

-- 7) Carrying-cost impact digest (by finding category)
create or replace function public.founder_r3553_carrying_cost_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_savings_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.savings_impact_rupees),0)::numeric
  from public.carrying_cost_capa_actions_r3553 c
  group by c.finding_category
  order by coalesce(sum(c.savings_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3553_carrying_cost_impact_digest() from public, anon;
grant execute on function public.founder_r3553_carrying_cost_impact_digest() to authenticated;

-- 8) High-risk queue (excessive / elevated / worsening lines)
create or replace function public.founder_r3553_high_risk_queue()
returns table(
  category text,
  warehouse text,
  sku_code text,
  period_month date,
  cost_status text,
  carrying_cost_pct numeric,
  target_pct numeric,
  total_carrying_cost_rupees numeric,
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
  select l.category, l.warehouse, l.sku_code, l.period_month,
    l.cost_status, l.carrying_cost_pct, l.target_pct,
    l.total_carrying_cost_rupees, l.trend_dir, l.notes
  from public.carrying_cost_r3553 l
  where l.cost_status in ('elevated','excessive')
     or l.trend_dir = 'worsening'
     or l.carrying_cost_pct > l.target_pct
  order by l.total_carrying_cost_rupees desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3553_high_risk_queue() from public, anon;
grant execute on function public.founder_r3553_high_risk_queue() to authenticated;
