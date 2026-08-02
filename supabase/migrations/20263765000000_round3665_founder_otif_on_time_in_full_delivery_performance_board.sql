-- Round 3665: OTIF (On-Time-In-Full) Delivery Performance Board
-- Outbound OTIF — region × customer segment × period × on-time × in-full × OTIF % vs target × delay days × short-ship × expedite cost × failure driver × CAPA

-- =============================================================================
-- TABLE 1: otif_r3665 — per-region / per-segment monthly OTIF delivery records
-- =============================================================================
create table if not exists public.otif_r3665 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  otif_ref text not null,
  region text not null,
  customer_segment text not null,
  period_month date not null,
  orders_shipped int not null,
  on_time int not null,
  in_full int not null,
  otif_orders int not null,
  otif_pct numeric(5,2),
  target_otif_pct numeric(5,2),
  avg_delay_days numeric(5,2),
  short_ship_incidents int,
  expedite_cost_rupees numeric(12,2),
  failure_driver text not null check (failure_driver in (
    'stock_out','carrier_delay','order_processing','documentation','customer_hold'
  )),
  otif_status text not null check (otif_status in (
    'excellent','on_target','slipping','poor','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.otif_r3665 enable row level security;

create index if not exists idx_otif_r3665_org on public.otif_r3665(organization_id);
create index if not exists idx_otif_r3665_month on public.otif_r3665(period_month);
create index if not exists idx_otif_r3665_status on public.otif_r3665(otif_status);

-- =============================================================================
-- TABLE 2: otif_capa_actions_r3665 — CAPA actions on OTIF misses
-- =============================================================================
create table if not exists public.otif_capa_actions_r3665 (
  id uuid primary key default gen_random_uuid(),
  otif_id uuid not null references public.otif_r3665(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'safety_stock_misconfigured','carrier_capacity_shortfall','warehouse_pick_backlog',
    'documentation_process_gap','demand_forecast_miss','customer_credit_hold',
    'port_congestion','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rebalance_safety_stock','contract_secondary_carrier','add_pick_shift',
    'automate_document_checks','tune_forecast_model','review_credit_release_process',
    'expedite_air_shipment','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  revenue_at_risk_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.otif_capa_actions_r3665 enable row level security;

create index if not exists idx_otif_capa_r3665_otif on public.otif_capa_actions_r3665(otif_id);
create index if not exists idx_otif_capa_r3665_status on public.otif_capa_actions_r3665(capa_status);

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

  -- 16 OTIF records
  insert into public.otif_r3665 (
    organization_id, otif_ref, region, customer_segment, period_month,
    orders_shipped, on_time, in_full, otif_orders, otif_pct, target_otif_pct,
    avg_delay_days, short_ship_incidents, expedite_cost_rupees,
    failure_driver, otif_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.reg, q.seg, q.pm::date,
    q.shp, q.ontm, q.infl, q.otifo, q.opct, q.tpct,
    q.dly, q.ssi, q.exc,
    q.fd, q.st, q.td, q.nt
  from (values
    ('OTIF-N-HOSP-2604','north','private_hospital','2026-04-01',
     120,112,110,106,88.3,92.0,1.8,4,185000,'carrier_delay','slipping','stable','Delhi hub — Delhi-Chandigarh lane congested at Gurgaon cross-dock'),
    ('OTIF-N-HOSP-2605','north','private_hospital','2026-05-01',
     132,124,126,119,90.2,92.0,1.4,3,142000,'carrier_delay','slipping','improving','Delhi Air Cargo uplift added for Lucknow hospital deliveries'),
    ('OTIF-N-HOSP-2606','north','private_hospital','2026-06-01',
     128,122,124,118,92.2,92.0,1.1,2,98000,'order_processing','on_target','improving','OTIF recovered above target after secondary carrier on trunk lane'),
    ('OTIF-N-GOVT-2606','north','govt_tender','2026-06-01',
     64,52,55,48,75.0,90.0,3.6,6,240000,'documentation','critical','worsening','GeM tender consignments held for e-way bill and inspection docs'),
    ('OTIF-S-HOSP-2605','south','private_hospital','2026-05-01',
     140,133,135,129,92.1,92.0,0.9,2,76000,'order_processing','on_target','stable','Chennai-Bengaluru lane steady; same-day POD capture live'),
    ('OTIF-S-HOSP-2606','south','private_hospital','2026-06-01',
     146,141,142,138,94.5,92.0,0.7,1,54000,'customer_hold','excellent','improving','Best region — Chennai port CFS bypass for domestic stock'),
    ('OTIF-S-DIAG-2606','south','diagnostic_chain','2026-06-01',
     88,79,76,72,81.8,90.0,2.2,5,165000,'stock_out','poor','worsening','Reagent stock-outs at Bengaluru DC hit diagnostic chain replenishment'),
    ('OTIF-S-DIST-2607','south','distributor','2026-07-01',
     92,87,88,84,91.3,90.0,1.0,2,61000,'carrier_delay','on_target','stable','Hyderabad distributor drops consolidated to twice-weekly milk run'),
    ('OTIF-W-HOSP-2605','west','private_hospital','2026-05-01',
     150,138,140,132,88.0,92.0,1.9,4,210000,'carrier_delay','slipping','stable','Mumbai-Pune lane detours due to monsoon waterlogging at Lonavala'),
    ('OTIF-W-HOSP-2606','west','private_hospital','2026-06-01',
     154,139,141,131,85.1,92.0,2.4,5,265000,'carrier_delay','poor','worsening','Nhava Sheva import delays cascaded into Mumbai hospital deliveries'),
    ('OTIF-W-DIST-2606','west','distributor','2026-06-01',
     96,90,88,85,88.5,90.0,1.5,3,118000,'stock_out','slipping','stable','Ahmedabad distributor short-shipped on consumables — safety stock low'),
    ('OTIF-W-DIAL-2607','west','dialysis_center','2026-07-01',
     72,69,70,67,93.1,92.0,0.8,1,32000,'order_processing','on_target','improving','Dialysis consumable standing orders auto-released from Bhiwandi DC'),
    ('OTIF-E-HOSP-2606','east','private_hospital','2026-06-01',
     58,49,50,45,77.6,90.0,3.1,4,152000,'carrier_delay','poor','stable','Kolkata-Guwahati lane transit variance high — single carrier dependency'),
    ('OTIF-E-GOVT-2607','east','govt_tender','2026-07-01',
     40,30,32,27,67.5,90.0,4.8,5,198000,'documentation','critical','worsening','State tender consignments stuck at Patna check-post for permit docs'),
    ('OTIF-N-DIAG-2607','north','diagnostic_chain','2026-07-01',
     84,80,81,78,92.9,90.0,0.9,1,45000,'customer_hold','on_target','improving','NCR diagnostic chain slots confirmed via delivery appointment portal'),
    ('OTIF-W-HOSP-2607','west','private_hospital','2026-07-01',
     148,142,143,138,93.2,92.0,0.9,2,88000,'order_processing','excellent','improving','Mumbai OTIF rebounded after dedicated FTL on Mumbai-Delhi trunk lane')
  ) as q(ref, reg, seg, pm, shp, ontm, infl, otifo, opct, tpct, dly, ssi, exc, fd, st, td, nt);

  -- CAPA seed — attach to specific OTIF records via otif_ref
  insert into public.otif_capa_actions_r3665 (
    otif_id, root_cause, corrective_action, capa_status,
    revenue_at_risk_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.rar, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('OTIF-N-GOVT-2606','documentation_process_gap','automate_document_checks','in_progress',3200000,'Ravi Iyer','2026-07-20',null,'E-way bill and tender doc checklist being automated in OMS'),
    ('OTIF-S-DIAG-2606','safety_stock_misconfigured','rebalance_safety_stock','open',2100000,'Meera Nair','2026-07-25',null,'Reagent safety stock at Bengaluru DC being reset to 3 weeks cover'),
    ('OTIF-W-HOSP-2606','port_congestion','expedite_air_shipment','escalated',4500000,'Arjun Shetty','2026-07-15',null,'Nhava Sheva backlog — critical SKUs moved via Delhi Air Cargo'),
    ('OTIF-E-HOSP-2606','carrier_capacity_shortfall','contract_secondary_carrier','verification_pending',1600000,'Sunil Das','2026-07-18',null,'Second carrier onboarded on Kolkata-Guwahati lane — verify transit'),
    ('OTIF-E-GOVT-2607','documentation_process_gap','automate_document_checks','overdue',1900000,'Ravi Iyer','2026-07-22',null,'Patna check-post permit pack overdue — state liaison engaged'),
    ('OTIF-W-DIST-2606','demand_forecast_miss','tune_forecast_model','closed',900000,'Kavya Rao','2026-07-10','2026-07-08','Consumables forecast retuned with distributor sell-out data'),
    ('OTIF-N-HOSP-2604','carrier_capacity_shortfall','contract_secondary_carrier','closed',1250000,'Arjun Shetty','2026-05-30','2026-05-26','Secondary carrier contracted on Delhi-Chandigarh lane — OTIF recovered'),
    ('OTIF-S-HOSP-2605','customer_credit_hold','review_credit_release_process','closed',400000,'Meera Nair','2026-06-15','2026-06-12','Auto credit-release for repeat hospital accounts below threshold')
  ) as q(ref, rc, ca, cst, rar, own, tcd, acd, nt)
  join public.otif_r3665 e
    on e.organization_id = v_org_id and e.otif_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) OTIF status distribution
create or replace function public.founder_r3665_otif_status_rollup()
returns table(otif_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.otif_r3665)
  select l.otif_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.otif_r3665 l
  group by l.otif_status
  order by count(*) desc;
end;
$$;

-- 2) Region OTIF scorecard
create or replace function public.founder_r3665_region_scorecard()
returns table(
  region text,
  records bigint,
  total_orders bigint,
  total_otif_orders bigint,
  avg_otif_pct numeric,
  avg_target_pct numeric,
  avg_delay_days numeric,
  short_ship_incidents bigint,
  expedite_cost_rupees numeric,
  below_target bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    coalesce(sum(l.orders_shipped),0)::bigint,
    coalesce(sum(l.otif_orders),0)::bigint,
    round(avg(l.otif_pct), 1),
    round(avg(l.target_otif_pct), 1),
    round(avg(l.avg_delay_days), 2),
    coalesce(sum(l.short_ship_incidents),0)::bigint,
    coalesce(sum(l.expedite_cost_rupees),0)::numeric,
    count(*) filter (where l.otif_pct < l.target_otif_pct)::bigint
  from public.otif_r3665 l
  group by l.region
  order by count(*) desc;
end;
$$;

-- 3) Failure driver × OTIF status matrix
create or replace function public.founder_r3665_failure_driver_status_matrix()
returns table(failure_driver text, otif_status text, records bigint, avg_otif_pct numeric, expedite_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.failure_driver, l.otif_status, count(*)::bigint,
    round(avg(l.otif_pct), 1),
    coalesce(sum(l.expedite_cost_rupees),0)::numeric
  from public.otif_r3665 l
  group by l.failure_driver, l.otif_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly OTIF trend
create or replace function public.founder_r3665_monthly_otif_trend()
returns table(period_month date, records bigint, orders_shipped bigint, otif_orders bigint, otif_rate_pct numeric, avg_delay_days numeric, short_ship_incidents bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.orders_shipped),0)::bigint,
    coalesce(sum(l.otif_orders),0)::bigint,
    round(100.0 * coalesce(sum(l.otif_orders),0)::numeric / nullif(sum(l.orders_shipped),0), 1),
    round(avg(l.avg_delay_days), 2),
    coalesce(sum(l.short_ship_incidents),0)::bigint
  from public.otif_r3665 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3665_capa_status_board()
returns table(capa_status text, actions bigint, avg_revenue_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.revenue_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.otif_capa_actions_r3665 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3665_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_revenue_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.otif_capa_actions_r3665)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.revenue_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.otif_capa_actions_r3665 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Delay-impact digest by failure driver
create or replace function public.founder_r3665_delay_impact_digest()
returns table(failure_driver text, records bigint, avg_delay_days numeric, total_short_ship bigint, total_expedite_cost_rupees numeric, worst_otif_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.failure_driver, count(*)::bigint,
    round(avg(l.avg_delay_days), 2),
    coalesce(sum(l.short_ship_incidents),0)::bigint,
    coalesce(sum(l.expedite_cost_rupees),0)::numeric,
    min(l.otif_pct)
  from public.otif_r3665 l
  group by l.failure_driver
  order by count(*) desc;
end;
$$;

-- 8) High-risk OTIF queue (poor/critical, below target, or worsening)
create or replace function public.founder_r3665_high_risk_queue()
returns table(
  otif_ref text,
  region text,
  customer_segment text,
  period_month date,
  orders_shipped int,
  otif_pct numeric,
  target_otif_pct numeric,
  avg_delay_days numeric,
  failure_driver text,
  otif_status text,
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
  select l.otif_ref, l.region, l.customer_segment, l.period_month,
    l.orders_shipped, l.otif_pct, l.target_otif_pct, l.avg_delay_days,
    l.failure_driver, l.otif_status, l.trend_dir, l.notes
  from public.otif_r3665 l
  where l.otif_status in ('poor','critical')
     or l.otif_pct < l.target_otif_pct
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.otif_pct asc;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3665_otif_status_rollup() from public, anon;
revoke all on function public.founder_r3665_region_scorecard() from public, anon;
revoke all on function public.founder_r3665_failure_driver_status_matrix() from public, anon;
revoke all on function public.founder_r3665_monthly_otif_trend() from public, anon;
revoke all on function public.founder_r3665_capa_status_board() from public, anon;
revoke all on function public.founder_r3665_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3665_delay_impact_digest() from public, anon;
revoke all on function public.founder_r3665_high_risk_queue() from public, anon;

grant execute on function public.founder_r3665_otif_status_rollup() to authenticated;
grant execute on function public.founder_r3665_region_scorecard() to authenticated;
grant execute on function public.founder_r3665_failure_driver_status_matrix() to authenticated;
grant execute on function public.founder_r3665_monthly_otif_trend() to authenticated;
grant execute on function public.founder_r3665_capa_status_board() to authenticated;
grant execute on function public.founder_r3665_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3665_delay_impact_digest() to authenticated;
grant execute on function public.founder_r3665_high_risk_queue() to authenticated;
