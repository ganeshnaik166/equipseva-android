-- Round 3670: Container / Truck Load-Utilization & Fill-Rate Board
-- Logistics load QA — lane × vehicle type × load mode × trips × fill rate vs target × cube utilization × part-load share × consolidation misses × cost per trip × CAPA

-- =============================================================================
-- TABLE 1: load_util_r3670 — per-lane per-month load-utilization entries
-- =============================================================================
create table if not exists public.load_util_r3670 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  lane_code text not null,
  lane_name text not null,
  vehicle_type text not null,
  period_month date not null,
  trips int not null,
  capacity_kg numeric(10,2),
  avg_load_kg numeric(10,2),
  fill_rate_pct numeric(5,2),
  target_fill_pct numeric(5,2),
  cube_utilization_pct numeric(5,2),
  part_load_trips int,
  consolidation_missed int,
  cost_per_trip_rupees numeric(12,2),
  load_mode text not null check (load_mode in (
    'full_truck','part_truck','container_20ft','container_40ft','tempo_small'
  )),
  utilization_status text not null check (utilization_status in (
    'optimized','on_target','underfilled','fragmented','wasteful'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.load_util_r3670 enable row level security;

create index if not exists idx_load_util_r3670_org on public.load_util_r3670(organization_id);
create index if not exists idx_load_util_r3670_month on public.load_util_r3670(period_month);
create index if not exists idx_load_util_r3670_status on public.load_util_r3670(utilization_status);

-- =============================================================================
-- TABLE 2: load_util_capa_actions_r3670 — CAPA & consolidation actions
-- =============================================================================
create table if not exists public.load_util_capa_actions_r3670 (
  id uuid primary key default gen_random_uuid(),
  load_entry_id uuid not null references public.load_util_r3670(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'chronic_underfill','fragmented_dispatch','missed_consolidation','wrong_vehicle_size',
    'cube_out_before_weight','high_part_load_share','cost_per_kg_spike','route_imbalance'
  )),
  root_cause text not null check (root_cause in (
    'poor_load_planning','order_batching_gap','vehicle_mix_mismatch','packaging_inefficiency',
    'demand_fragmentation','carrier_capacity_shortfall','manual_dispatch_decisions','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'implement_load_planning_tool','consolidate_dispatch_days','right_size_vehicle','redesign_packaging',
    'milk_run_routing','renegotiate_carrier_contract','train_dispatch_team','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  action_owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_savings_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.load_util_capa_actions_r3670 enable row level security;

create index if not exists idx_load_util_capa_r3670_entry on public.load_util_capa_actions_r3670(load_entry_id);
create index if not exists idx_load_util_capa_r3670_status on public.load_util_capa_actions_r3670(capa_status);

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

  -- 16 load-utilization rows
  insert into public.load_util_r3670 (
    organization_id, lane_code, lane_name, vehicle_type, period_month,
    trips, capacity_kg, avg_load_kg, fill_rate_pct, target_fill_pct,
    cube_utilization_pct, part_load_trips, consolidation_missed,
    cost_per_trip_rupees, load_mode, utilization_status, trend_dir, notes
  )
  select v_org_id, q.lcode, q.lname, q.vtype, q.pmon::date,
    q.trp, q.capkg, q.loadkg, q.fillp, q.targp,
    q.cubep, q.plt, q.cmiss,
    q.cpt, q.lmode, q.ustat, q.tdir, q.nt
  from (values
    ('LN-BHWDEL-07','Bhiwandi -> Delhi NCR','32ft MXL Truck','2026-07-01',
     42,18000,16400,91.1,90.0,88.5,3,1,52000,'full_truck','optimized','improving','Spare-parts trunk lane running above target fill after pooling SOP'),
    ('LN-BHWDEL-OF-07','Bhiwandi -> Delhi NCR overflow','19ft SXL Truck','2026-07-01',
     11,9000,5200,57.8,85.0,61.0,7,4,31000,'part_truck','fragmented','worsening','Overflow dispatches leaving part-loaded — consolidation window missed four times'),
    ('LN-CHNBLR-07','Chennai -> Bengaluru','24ft Container Truck','2026-07-01',
     28,12000,10700,89.2,88.0,84.0,2,0,34500,'full_truck','on_target','stable','Consumables lane steady at target fill'),
    ('LN-NSAEU-07','Nhava Sheva Export EU','40ft HC Container','2026-07-01',
     9,26000,23900,91.9,92.0,86.7,0,0,118000,'container_40ft','on_target','stable','Export FCL stuffing near weight limit — cube constrained by wooden crates'),
    ('LN-NSAGCC-07','Nhava Sheva Export GCC','20ft Container','2026-07-01',
     6,21000,12300,58.6,85.0,55.2,0,2,84000,'container_20ft','underfilled','worsening','GCC FCL sailings part-filled — LCL option not evaluated'),
    ('LN-DELAIR-07','Delhi Air Cargo implants','Reefer Tempo','2026-07-01',
     18,1500,910,60.7,70.0,52.4,9,3,9800,'tempo_small','underfilled','stable','Implant urgent shipments in small tempos — pooling window too tight'),
    ('LN-HYDVJA-07','Hyderabad -> Vijayawada','Tata 407','2026-07-01',
     15,2500,1300,52.0,80.0,48.9,11,6,12500,'tempo_small','wasteful','worsening','Service-van spares moving ad hoc, six missed consolidation slots'),
    ('LN-PUNAHM-07','Pune -> Ahmedabad','32ft SXL Truck','2026-07-01',
     12,16000,14100,88.1,88.0,90.2,1,0,41000,'full_truck','on_target','improving','Dialysis machines lane cubes out before weight — fill healthy'),
    ('LN-BHWDEL-06','Bhiwandi -> Delhi NCR','32ft MXL Truck','2026-06-01',
     38,18000,15600,86.7,90.0,84.1,4,2,51000,'full_truck','underfilled','improving','June fill below target — two missed pooling windows'),
    ('LN-CHNBLR-06','Chennai -> Bengaluru','24ft Container Truck','2026-06-01',
     26,12000,10250,85.4,88.0,80.3,3,1,34000,'full_truck','underfilled','improving','Fill recovering after carrier swap mid-June'),
    ('LN-NSAGCC-06','Nhava Sheva Export GCC','20ft Container','2026-06-01',
     7,21000,13900,66.2,85.0,60.1,0,1,82500,'container_20ft','underfilled','worsening','Return-leg imbalance leaving boxes light on outbound'),
    ('LN-HYDVJA-06','Hyderabad -> Vijayawada','Tata 407','2026-06-01',
     14,2500,1450,58.0,80.0,54.6,9,4,12200,'tempo_small','fragmented','worsening','Engineers booking ad-hoc tempos outside dispatch desk'),
    ('LN-DELAIR-06','Delhi Air Cargo implants','Reefer Tempo','2026-06-01',
     16,1500,980,65.3,70.0,58.8,7,2,9600,'tempo_small','on_target','stable','Implant runs holding near target with two-slot pooling'),
    ('LN-BHWDEL-05','Bhiwandi -> Delhi NCR','32ft MXL Truck','2026-05-01',
     35,18000,14900,82.8,90.0,80.7,6,3,50500,'full_truck','underfilled','stable','Pre-SOP baseline month — foam crates wasting cube'),
    ('LN-CHNMAA-05','Chennai Port ICD shuttle','20ft Container','2026-05-01',
     10,21000,18700,89.0,88.0,83.4,0,0,28000,'container_20ft','optimized','stable','ICD shuttle running dense with stacked pallets'),
    ('LN-MUMNAG-05','Mumbai -> Nagpur','17ft LCV','2026-05-01',
     13,3500,1750,50.0,78.0,47.2,10,5,16800,'part_truck','wasteful','stable','Half-empty LCVs on low-density lane — later retired to 3PL')
  ) as q(lcode, lname, vtype, pmon, trp, capkg, loadkg, fillp, targp, cubep, plt, cmiss, cpt, lmode, ustat, tdir, nt);

  -- CAPA seed — attach to specific lane entries via lane_code
  insert into public.load_util_capa_actions_r3670 (
    load_entry_id, finding_category, root_cause, corrective_action,
    capa_status, action_owner, target_closure_date, actual_closure_date,
    estimated_savings_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.own, q.tcd::date, q.acd::date,
    q.sav, q.nt
  from (values
    ('LN-BHWDEL-OF-07','fragmented_dispatch','order_batching_gap','consolidate_dispatch_days','in_progress','Ravi Deshmukh','2026-08-10',null,180000.00,'Overflow dispatches moved to Tue/Fri pooling windows'),
    ('LN-NSAGCC-07','chronic_underfill','demand_fragmentation','milk_run_routing','open','Meena Iyer','2026-08-20',null,240000.00,'Evaluate LCL vs FCL for GCC sailings below 70% fill'),
    ('LN-HYDVJA-07','missed_consolidation','manual_dispatch_decisions','implement_load_planning_tool','escalated','Suresh Rao','2026-08-05',null,150000.00,'Six missed slots in July — dispatch still on WhatsApp approvals'),
    ('LN-DELAIR-07','wrong_vehicle_size','vehicle_mix_mismatch','right_size_vehicle','verification_pending','Anita Sharma','2026-08-08',null,96000.00,'Shifted implant runs to shared reefer LCV — verifying August fill'),
    ('LN-MUMNAG-05','high_part_load_share','poor_load_planning','train_dispatch_team','closed','Vikram Joshi','2026-06-15','2026-06-12',72000.00,'Dispatch team trained on load-builder SOP; lane retired to 3PL'),
    ('LN-BHWDEL-05','cube_out_before_weight','packaging_inefficiency','redesign_packaging','closed','Ravi Deshmukh','2026-06-30','2026-06-25',125000.00,'Foam crate redesign lifted cube utilization six points'),
    ('LN-CHNBLR-06','cost_per_kg_spike','carrier_capacity_shortfall','renegotiate_carrier_contract','overdue','Meena Iyer','2026-07-15',null,88000.00,'Peak-season surcharge dispute pending with carrier'),
    ('LN-NSAGCC-06','route_imbalance','pending_investigation','none_required','open','Suresh Rao','2026-08-25',null,0.00,'Return-leg empty containers under study with freight forwarder')
  ) as q(lcode, fc, rc, ca, cst, own, tcd, acd, sav, nt)
  join public.load_util_r3670 e
    on e.organization_id = v_org_id and e.lane_code = q.lcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Utilization status distribution
create or replace function public.founder_r3670_utilization_status_rollup()
returns table(utilization_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.load_util_r3670)
  select l.utilization_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.load_util_r3670 l
  group by l.utilization_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3670_utilization_status_rollup() from public, anon;
grant execute on function public.founder_r3670_utilization_status_rollup() to authenticated;

-- 2) Lane-level utilization scorecard
create or replace function public.founder_r3670_lane_scorecard()
returns table(
  lane_name text,
  entries bigint,
  total_trips bigint,
  avg_fill_rate_pct numeric,
  avg_target_fill_pct numeric,
  avg_cube_utilization_pct numeric,
  part_load_trips bigint,
  consolidation_missed bigint,
  avg_cost_per_trip_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lane_name,
    count(*)::bigint,
    coalesce(sum(l.trips),0)::bigint,
    round(avg(l.fill_rate_pct), 1),
    round(avg(l.target_fill_pct), 1),
    round(avg(l.cube_utilization_pct), 1),
    coalesce(sum(l.part_load_trips),0)::bigint,
    coalesce(sum(l.consolidation_missed),0)::bigint,
    round(avg(l.cost_per_trip_rupees), 0)
  from public.load_util_r3670 l
  group by l.lane_name
  order by round(avg(l.fill_rate_pct), 1) asc;
end;
$$;

revoke all on function public.founder_r3670_lane_scorecard() from public, anon;
grant execute on function public.founder_r3670_lane_scorecard() to authenticated;

-- 3) Load mode × utilization status matrix
create or replace function public.founder_r3670_load_mode_status_matrix()
returns table(load_mode text, utilization_status text, entries bigint, avg_fill_rate_pct numeric, avg_cost_per_trip_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.load_mode, l.utilization_status, count(*)::bigint,
    round(avg(l.fill_rate_pct), 1),
    round(avg(l.cost_per_trip_rupees), 0)
  from public.load_util_r3670 l
  group by l.load_mode, l.utilization_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3670_load_mode_status_matrix() from public, anon;
grant execute on function public.founder_r3670_load_mode_status_matrix() to authenticated;

-- 4) Monthly fill-rate trend
create or replace function public.founder_r3670_monthly_fill_rate_trend()
returns table(period_month date, entries bigint, total_trips bigint, avg_fill_rate_pct numeric, avg_target_fill_pct numeric, avg_cube_utilization_pct numeric, underfilled_entries bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.trips),0)::bigint,
    round(avg(l.fill_rate_pct), 1),
    round(avg(l.target_fill_pct), 1),
    round(avg(l.cube_utilization_pct), 1),
    count(*) filter (where l.utilization_status in ('underfilled','fragmented','wasteful'))::bigint
  from public.load_util_r3670 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3670_monthly_fill_rate_trend() from public, anon;
grant execute on function public.founder_r3670_monthly_fill_rate_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3670_capa_status_board()
returns table(capa_status text, findings bigint, avg_savings_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_savings_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.load_util_capa_actions_r3670 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3670_capa_status_board() from public, anon;
grant execute on function public.founder_r3670_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3670_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.load_util_capa_actions_r3670)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_savings_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.load_util_capa_actions_r3670 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3670_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3670_root_cause_pareto() to authenticated;

-- 7) Consolidation-miss digest
create or replace function public.founder_r3670_consolidation_miss_digest()
returns table(lane_name text, entries bigint, total_trips bigint, part_load_trips bigint, consolidation_missed bigint, miss_rate_pct numeric, est_leakage_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lane_name,
    count(*)::bigint,
    coalesce(sum(l.trips),0)::bigint,
    coalesce(sum(l.part_load_trips),0)::bigint,
    coalesce(sum(l.consolidation_missed),0)::bigint,
    round(100.0 * coalesce(sum(l.consolidation_missed),0)::numeric / nullif(sum(l.trips),0), 1),
    coalesce(sum(l.consolidation_missed * l.cost_per_trip_rupees),0)::numeric
  from public.load_util_r3670 l
  group by l.lane_name
  order by coalesce(sum(l.consolidation_missed),0) desc;
end;
$$;

revoke all on function public.founder_r3670_consolidation_miss_digest() from public, anon;
grant execute on function public.founder_r3670_consolidation_miss_digest() to authenticated;

-- 8) High-risk lane queue (wasteful / fragmented / worsening)
create or replace function public.founder_r3670_high_risk_queue()
returns table(
  lane_code text,
  lane_name text,
  vehicle_type text,
  load_mode text,
  period_month date,
  fill_rate_pct numeric,
  target_fill_pct numeric,
  cube_utilization_pct numeric,
  utilization_status text,
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
  select l.lane_code, l.lane_name, l.vehicle_type, l.load_mode, l.period_month,
    l.fill_rate_pct, l.target_fill_pct, l.cube_utilization_pct,
    l.utilization_status, l.trend_dir, l.notes
  from public.load_util_r3670 l
  where l.utilization_status in ('wasteful','fragmented')
     or l.trend_dir = 'worsening'
     or l.fill_rate_pct < l.target_fill_pct - 15
  order by l.period_month desc, l.fill_rate_pct asc;
end;
$$;

revoke all on function public.founder_r3670_high_risk_queue() from public, anon;
grant execute on function public.founder_r3670_high_risk_queue() to authenticated;
