-- Round 3449: Founder Inventory Days-Inventory-Outstanding (DIO) / Stock-Turns Board
-- Spare-parts DIO + stock-turns vs target per category × warehouse × avg inventory value × annual COGS
-- × DIO days × turns/year × dio_status × excess capital × monthly trend × CAPA closure

-- =============================================================================
-- TABLE 1: dio_stock_turns_r3449 — per category/warehouse DIO & stock-turns board
-- =============================================================================
create table if not exists public.dio_stock_turns_r3449 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  line_code text not null,
  category text not null,
  warehouse text not null,
  avg_inventory_value_rupees numeric(14,2),
  annual_cogs_rupees numeric(14,2),
  dio_days numeric(7,2),
  target_dio_days numeric(7,2),
  turns_per_year numeric(6,2),
  target_turns numeric(6,2),
  dio_status text not null check (dio_status in (
    'on_target','above_target','below_target','critical_excess'
  )),
  excess_capital_rupees numeric(14,2),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dio_stock_turns_r3449 enable row level security;

create index if not exists idx_dio_stock_turns_r3449_org on public.dio_stock_turns_r3449(organization_id);
create index if not exists idx_dio_stock_turns_r3449_status on public.dio_stock_turns_r3449(dio_status);
create index if not exists idx_dio_stock_turns_r3449_month on public.dio_stock_turns_r3449(period_month);

-- =============================================================================
-- TABLE 2: dio_stock_turns_capa_actions_r3449 — CAPA & inventory-reduction actions
-- =============================================================================
create table if not exists public.dio_stock_turns_capa_actions_r3449 (
  id uuid primary key default gen_random_uuid(),
  board_line_id uuid not null references public.dio_stock_turns_r3449(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excess_stock','slow_moving_stock','dead_stock','dio_above_target',
    'turns_below_target','obsolescence_risk','overstock_purchasing','forecast_bias'
  )),
  root_cause text not null check (root_cause in (
    'over_forecasting','bulk_purchase_discount_overbuy','demand_drop','supplier_moq_too_high',
    'discontinued_model','long_lead_time_buffer','duplicate_stocking','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reduce_reorder_point','liquidate_excess_stock','return_to_vendor','redistribute_across_warehouses',
    'write_off_dead_stock','renegotiate_moq','tighten_forecast','consolidate_skus','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  capital_at_risk_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dio_stock_turns_capa_actions_r3449 enable row level security;

create index if not exists idx_dio_stock_turns_capa_r3449_line on public.dio_stock_turns_capa_actions_r3449(board_line_id);
create index if not exists idx_dio_stock_turns_capa_r3449_status on public.dio_stock_turns_capa_actions_r3449(capa_status);

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

  -- 16 DIO / stock-turns board lines
  insert into public.dio_stock_turns_r3449 (
    organization_id, line_code, category, warehouse,
    avg_inventory_value_rupees, annual_cogs_rupees, dio_days, target_dio_days,
    turns_per_year, target_turns, dio_status, excess_capital_rupees,
    period_month, trend_dir, notes
  )
  select v_org_id, q.lcode, q.cat, q.wh,
    q.aiv, q.cogs, q.dio, q.tdio,
    q.tpy, q.ttgt, q.dstat, q.exc,
    q.pm::date, q.tdir, q.nt
  from (values
    ('IMG-MUM-01','Imaging Spares','Mumbai Central WH',
     4200000,15300000,100.2,90,3.65,4.0,'above_target',350000,'2026-07-01','worsening','CT/MRI coil & tube spares holding above target — slow demand quarter'),
    ('MON-MUM-02','Patient Monitoring Spares','Mumbai Central WH',
     1850000,9800000,68.9,75,5.30,4.9,'below_target',0,'2026-07-01','improving','SpO2/ECG monitoring spares turning fast, healthy'),
    ('VNT-DEL-03','Ventilator Spares','Delhi NCR WH',
     2600000,7100000,133.7,95,2.73,3.8,'above_target',740000,'2026-07-01','worsening','Ventilator flow-sensor & valve spares overstocked post-COVID taper'),
    ('DIA-DEL-04','Dialysis Spares','Delhi NCR WH',
     980000,6400000,55.9,60,6.53,6.0,'on_target',0,'2026-07-01','stable','Dialyzer & tubing spares on target'),
    ('LAB-BLR-05','Lab Analyzer Spares','Bengaluru WH',
     3100000,4200000,269.5,110,1.35,3.3,'critical_excess',2050000,'2026-07-01','worsening','Discontinued analyzer reagent-probe spares — dead stock building'),
    ('SRG-BLR-06','Surgical Instrument Spares','Bengaluru WH',
     1450000,8900000,59.5,65,6.14,5.6,'on_target',0,'2026-07-01','stable','Laparoscopy & drill handpiece spares healthy turns'),
    ('STE-CHN-07','Sterilization Spares','Chennai WH',
     760000,3900000,71.1,80,5.13,4.6,'below_target',0,'2026-07-01','improving','Autoclave gasket & valve spares moving well'),
    ('IMG-CHN-08','Imaging Spares','Chennai WH',
     5400000,12100000,162.9,90,2.24,4.0,'critical_excess',3100000,'2026-07-01','worsening','X-ray tube & detector spares severely overstocked — capital locked'),
    ('MON-HYD-09','Patient Monitoring Spares','Hyderabad WH',
     1250000,7600000,60.0,75,6.08,4.9,'below_target',0,'2026-07-01','improving','Monitoring modules turning above target'),
    ('VNT-HYD-10','Ventilator Spares','Hyderabad WH',
     1980000,5200000,139.0,95,2.63,3.8,'above_target',560000,'2026-07-01','stable','Ventilator turbine spares above target, monitoring'),
    ('DIA-KOL-11','Dialysis Spares','Kolkata WH',
     1120000,3100000,131.9,60,2.77,6.0,'critical_excess',890000,'2026-06-01','worsening','RO membrane & concentrate spares overstocked in low-demand region'),
    ('LAB-KOL-12','Lab Analyzer Spares','Kolkata WH',
     680000,4900000,50.6,70,7.21,5.2,'below_target',0,'2026-06-01','improving','Hematology analyzer spares turning fast'),
    ('SRG-MUM-13','Surgical Instrument Spares','Mumbai Central WH',
     2200000,9600000,83.6,70,4.36,5.2,'above_target',430000,'2026-06-01','worsening','Electrosurgery pencil & cable spares creeping above target'),
    ('STE-DEL-14','Sterilization Spares','Delhi NCR WH',
     540000,2800000,70.4,80,5.19,4.6,'on_target',0,'2026-06-01','stable','ETO & plasma sterilizer spares on target'),
    ('GEN-BLR-15','General Biomedical Consumables','Bengaluru WH',
     890000,11200000,29.0,45,12.58,8.1,'below_target',0,'2026-06-01','improving','Fast-moving consumables well below DIO target'),
    ('GEN-CHN-16','General Biomedical Consumables','Chennai WH',
     1650000,3400000,177.2,45,2.06,8.1,'critical_excess',1180000,'2026-06-01','worsening','Obsolete consumable batches nearing expiry — write-off risk')
  ) as q(lcode, cat, wh, aiv, cogs, dio, tdio, tpy, ttgt, dstat, exc, pm, tdir, nt);

  -- CAPA seed — attach to specific board lines via line_code
  insert into public.dio_stock_turns_capa_actions_r3449 (
    board_line_id, finding_category, root_cause, corrective_action,
    capa_status, capital_at_risk_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.risk, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('LAB-BLR-05','dead_stock','discontinued_model','write_off_dead_stock','in_progress',2050000,'Ravi Menon','2026-08-15',null,'Discontinued analyzer reagent probes — write-off approval in progress'),
    ('IMG-CHN-08','excess_stock','over_forecasting','liquidate_excess_stock','open',3100000,'Priya Nair','2026-08-30',null,'X-ray tube overstock — liquidation to partner hospitals planned'),
    ('DIA-KOL-11','slow_moving_stock','demand_drop','redistribute_across_warehouses','in_progress',890000,'Anil Kumar','2026-08-10',null,'RO membranes to be shifted to high-demand Chennai WH'),
    ('GEN-CHN-16','obsolescence_risk','over_forecasting','write_off_dead_stock','escalated',1180000,'Priya Nair','2026-08-05',null,'Consumable batches near expiry — escalated for urgent write-off'),
    ('VNT-DEL-03','dio_above_target','demand_drop','reduce_reorder_point','open',740000,'Suresh Rao','2026-08-20',null,'Ventilator spares reorder point lowered post COVID taper'),
    ('IMG-MUM-01','overstock_purchasing','bulk_purchase_discount_overbuy','renegotiate_moq','verification_pending',350000,'Ravi Menon','2026-07-31',null,'CT coil spares MOQ renegotiation with OEM under review'),
    ('SRG-MUM-13','turns_below_target','duplicate_stocking','consolidate_skus','closed',0,'Anil Kumar','2026-07-15','2026-07-12','Electrosurgery SKUs consolidated across Mumbai WH — closed'),
    ('VNT-HYD-10','dio_above_target','long_lead_time_buffer','tighten_forecast','overdue',560000,'Suresh Rao','2026-07-10',null,'Ventilator turbine buffer stock forecast tightening overdue')
  ) as q(lcode, fc, rc, ca, cst, risk, own, tcd, acd, nt)
  join public.dio_stock_turns_r3449 e
    on e.organization_id = v_org_id and e.line_code = q.lcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) DIO status distribution
create or replace function public.founder_r3449_dio_status_rollup()
returns table(dio_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dio_stock_turns_r3449)
  select l.dio_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dio_stock_turns_r3449 l
  group by l.dio_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3449_dio_status_rollup() from public, anon;
grant execute on function public.founder_r3449_dio_status_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3449_category_scorecard()
returns table(
  category text,
  lines bigint,
  on_target bigint,
  above_target bigint,
  below_target bigint,
  critical_excess bigint,
  total_inventory_value_rupees numeric,
  total_excess_capital_rupees numeric,
  avg_dio_days numeric,
  avg_turns numeric
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
    count(*) filter (where l.dio_status = 'on_target')::bigint,
    count(*) filter (where l.dio_status = 'above_target')::bigint,
    count(*) filter (where l.dio_status = 'below_target')::bigint,
    count(*) filter (where l.dio_status = 'critical_excess')::bigint,
    coalesce(sum(l.avg_inventory_value_rupees),0)::numeric,
    coalesce(sum(l.excess_capital_rupees),0)::numeric,
    round(avg(l.dio_days), 1),
    round(avg(l.turns_per_year), 2)
  from public.dio_stock_turns_r3449 l
  group by l.category
  order by coalesce(sum(l.excess_capital_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3449_category_scorecard() from public, anon;
grant execute on function public.founder_r3449_category_scorecard() to authenticated;

-- 3) Category × DIO-status matrix
create or replace function public.founder_r3449_category_status_matrix()
returns table(category text, dio_status text, lines bigint, total_inventory_value_rupees numeric, excess_capital_rupees numeric, avg_dio_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.dio_status, count(*)::bigint,
    coalesce(sum(l.avg_inventory_value_rupees),0)::numeric,
    coalesce(sum(l.excess_capital_rupees),0)::numeric,
    round(avg(l.dio_days), 1)
  from public.dio_stock_turns_r3449 l
  group by l.category, l.dio_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3449_category_status_matrix() from public, anon;
grant execute on function public.founder_r3449_category_status_matrix() to authenticated;

-- 4) Monthly DIO / turns trend
create or replace function public.founder_r3449_monthly_dio_trend()
returns table(period_month date, lines bigint, avg_dio_days numeric, avg_target_dio_days numeric, avg_turns numeric, avg_target_turns numeric, total_excess_capital_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.dio_days), 1),
    round(avg(l.target_dio_days), 1),
    round(avg(l.turns_per_year), 2),
    round(avg(l.target_turns), 2),
    coalesce(sum(l.excess_capital_rupees),0)::numeric
  from public.dio_stock_turns_r3449 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3449_monthly_dio_trend() from public, anon;
grant execute on function public.founder_r3449_monthly_dio_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3449_capa_status_board()
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
  from public.dio_stock_turns_capa_actions_r3449 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3449_capa_status_board() from public, anon;
grant execute on function public.founder_r3449_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3449_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_capital_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dio_stock_turns_capa_actions_r3449)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.capital_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dio_stock_turns_capa_actions_r3449 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3449_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3449_root_cause_pareto() to authenticated;

-- 7) Excess-capital impact digest
create or replace function public.founder_r3449_excess_capital_digest()
returns table(category text, lines bigint, lines_with_excess bigint, total_excess_capital_rupees numeric, avg_excess_per_line_rupees numeric, worst_dio_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.excess_capital_rupees > 0)::bigint,
    coalesce(sum(l.excess_capital_rupees),0)::numeric,
    round(avg(l.excess_capital_rupees), 0),
    max(l.dio_days)
  from public.dio_stock_turns_r3449 l
  group by l.category
  order by coalesce(sum(l.excess_capital_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3449_excess_capital_digest() from public, anon;
grant execute on function public.founder_r3449_excess_capital_digest() to authenticated;

-- 8) High-risk DIO queue (critical-excess / above-target / worsening)
create or replace function public.founder_r3449_high_risk_queue()
returns table(
  line_code text,
  category text,
  warehouse text,
  period_month date,
  dio_status text,
  dio_days numeric,
  target_dio_days numeric,
  turns_per_year numeric,
  excess_capital_rupees numeric,
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
  select l.line_code, l.category, l.warehouse, l.period_month, l.dio_status,
    l.dio_days, l.target_dio_days, l.turns_per_year, l.excess_capital_rupees, l.trend_dir, l.notes
  from public.dio_stock_turns_r3449 l
  where l.dio_status in ('critical_excess','above_target')
     or l.trend_dir = 'worsening'
  order by l.excess_capital_rupees desc, l.dio_days desc;
end;
$$;

revoke execute on function public.founder_r3449_high_risk_queue() from public, anon;
grant execute on function public.founder_r3449_high_risk_queue() to authenticated;
