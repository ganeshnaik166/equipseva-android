-- Round 3721: Founder Warehouse Pick-Pack Accuracy & Dispatch Slotting Board
-- Warehouse pick-pack accuracy, bin-slotting efficiency & dispatch error rate per warehouse/zone
-- (in-warehouse picking/slotting/dispatch operational accuracy — NOT container/truck load-utilization,
-- NOT packaging spend) — warehouse × zone × zone class × orders picked × pick errors × mis-slotted
-- bins × dispatch errors × returns from pick error × relabeling × CAPA

-- =============================================================================
-- TABLE 1: pickpack_r3721 — per-warehouse per-zone per-month pick-pack accuracy facts
-- =============================================================================
create table if not exists public.pickpack_r3721 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  warehouse_name text not null,
  zone text not null,
  period_month date not null,
  orders_picked int not null,
  pick_errors int not null,
  pick_accuracy_pct numeric(5,2),
  avg_pick_time_minutes numeric(6,2),
  mis_slotted_bins int,
  dispatch_errors int,
  returns_due_to_pick_error int,
  relabeling_required int,
  zone_class text not null check (zone_class in (
    'fast_moving','slow_moving','bulky_oversized','high_value_secure','returns_staging'
  )),
  pickpack_status text not null check (pickpack_status in (
    'excellent','on_target','slipping','high_error','critical_error'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pickpack_r3721 enable row level security;

create index if not exists idx_pickpack_r3721_org on public.pickpack_r3721(organization_id);
create index if not exists idx_pickpack_r3721_month on public.pickpack_r3721(period_month);
create index if not exists idx_pickpack_r3721_status on public.pickpack_r3721(pickpack_status);

-- =============================================================================
-- TABLE 2: pickpack_capa_actions_r3721 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.pickpack_capa_actions_r3721 (
  id uuid primary key default gen_random_uuid(),
  pickpack_entry_id uuid references public.pickpack_r3721(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in (
    'open','in_progress','closed','overdue'
  )),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pickpack_capa_actions_r3721 enable row level security;

create index if not exists idx_pickpack_capa_r3721_entry on public.pickpack_capa_actions_r3721(pickpack_entry_id);
create index if not exists idx_pickpack_capa_r3721_status on public.pickpack_capa_actions_r3721(capa_status);

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

  -- 16 pick-pack accuracy rows
  insert into public.pickpack_r3721 (
    organization_id, warehouse_name, zone, period_month, orders_picked, pick_errors,
    pick_accuracy_pct, avg_pick_time_minutes, mis_slotted_bins, dispatch_errors,
    returns_due_to_pick_error, relabeling_required, zone_class, pickpack_status, trend_dir,
    notes, created_at
  )
  select v_org_id, q.wh, q.zn, q.pmon::date, q.op, q.pe,
    q.pap, q.apt, q.msb, q.de,
    q.rdpe, q.rlr, q.zc, q.pps, q.td,
    q.nt, now()
  from (values
    ('Bhiwandi Fulfilment Center','A1','2026-07-01',8200,41,99.50,1.8,3,5,6,2,
     'fast_moving','excellent','improving',
     'Fast-moving spares zone holding above 99.5% pick accuracy after voice-pick rollout.'),
    ('Bhiwandi Fulfilment Center','D1','2026-07-01',1450,22,98.48,3.2,1,2,3,1,
     'high_value_secure','on_target','stable',
     'Cage-secured high-value imaging spares zone steady at target accuracy with dual sign-off.'),
    ('Bhiwandi Fulfilment Center','B1','2026-07-01',2100,95,95.48,4.1,12,9,14,6,
     'slow_moving','slipping','worsening',
     'Slow-moving ventilator accessory zone slipping — mis-slotted bins climbing after last cycle count.'),
    ('Bhiwandi Fulfilment Center','C1','2026-07-01',980,88,91.02,6.5,18,21,25,11,
     'bulky_oversized','high_error','worsening',
     'Bulky dialysis-machine crate zone running a high pick-error rate — aisle congestion flagged.'),
    ('Bhiwandi Fulfilment Center','E1','2026-07-01',640,140,78.13,8.2,31,38,52,29,
     'returns_staging','critical_error','worsening',
     'Returns-staging zone in a critical state — inbound RMA backlog causing widespread mis-picks.'),
    ('Nagpur Regional DC','A2','2026-07-01',6100,28,99.54,1.9,2,3,4,1,
     'fast_moving','excellent','stable',
     'Nagpur fast-pick zone for compressor spares holding steady above 99.5% accuracy.'),
    ('Nagpur Regional DC','D2','2026-07-01',1100,30,97.27,3.6,4,5,6,3,
     'high_value_secure','on_target','improving',
     'High-value cath-lab spares cage on target after a tightened dual-verification SOP.'),
    ('Nagpur Regional DC','C2','2026-07-01',730,52,92.88,5.9,9,11,13,7,
     'bulky_oversized','slipping','stable',
     'Oversized X-ray gantry parts zone slipping on accuracy amid narrow-aisle rework.'),
    ('Pune Cross-Dock Hub','B2','2026-07-01',1800,64,96.44,3.8,7,6,9,4,
     'slow_moving','on_target','improving',
     'Slow-moving anaesthesia-accessory zone recovering after re-slotting by pick frequency.'),
    ('Pune Cross-Dock Hub','E2','2026-07-01',520,112,78.46,7.9,27,33,45,24,
     'returns_staging','critical_error','worsening',
     'Returns-staging zone critical — mismatched SKU labels driving repeat mis-picks on RMA units.'),
    ('Chennai Spare Parts Hub','A3','2026-06-01',7600,52,99.32,2.0,4,6,7,3,
     'fast_moving','excellent','stable',
     'Chennai fast-pick consumables zone consistently above 99% accuracy through June.'),
    ('Chennai Spare Parts Hub','C3','2026-06-01',860,95,88.95,6.9,21,24,28,15,
     'bulky_oversized','high_error','worsening',
     'Bulky ultrasound-cart parts zone high-error in June — putaway confirmation gaps identified.'),
    ('Bhiwandi Fulfilment Center','A1','2026-06-01',7900,55,99.30,1.9,4,6,7,3,
     'fast_moving','excellent','stable',
     'June baseline for the fast-pick zone before voice-pick rollout — accuracy already strong.'),
    ('Nagpur Regional DC','B2','2026-06-01',1750,80,95.43,4.3,10,8,12,5,
     'slow_moving','slipping','worsening',
     'Slow-moving zone slipping in June — cycle-count variance traced to shared bin locations.'),
    ('Pune Cross-Dock Hub','D2','2026-08-01',1200,18,98.50,3.1,1,2,2,1,
     'high_value_secure','excellent','improving',
     'High-value infusion-pump spares cage improved to excellent after a camera-audit pilot.'),
    ('Chennai Spare Parts Hub','E3','2026-08-01',590,98,83.39,7.2,19,22,30,16,
     'returns_staging','slipping','improving',
     'Returns-staging zone improving off a critical base — new triage desk cutting mis-picks.')
  ) as q(wh, zn, pmon, op, pe, pap, apt, msb, de, rdpe, rlr, zc, pps, td, nt);

  -- CAPA seed — attach to specific pick-pack entries via warehouse + zone + month
  insert into public.pickpack_capa_actions_r3721 (
    pickpack_entry_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes, created_at
  )
  select e.id, q.rc, q.ca, q.cst, q.own,
    q.tcd::date, q.acd::date, q.nt, now()
  from (values
    ('Bhiwandi Fulfilment Center','B1','2026-07-01','inadequate_bin_slotting','reslot_bins_by_velocity',
     'in_progress','Priya Nair','2026-08-20',null,
     'Re-slotting ventilator-accessory bins by pick frequency; cycle-count variance under active review.'),
    ('Bhiwandi Fulfilment Center','C1','2026-07-01','aisle_congestion','redesign_aisle_layout',
     'open','Ravi Deshmukh','2026-08-28',null,
     'Dialysis-crate aisle widened in a pilot bay; full rollout pending facilities sign-off.'),
    ('Bhiwandi Fulfilment Center','E1','2026-07-01','returns_backlog_volume','clear_returns_backlog',
     'overdue','Sunita Rao','2026-08-05',null,
     'RMA backlog clearance missed its target date — additional temp staff requested for the returns desk.'),
    ('Nagpur Regional DC','C2','2026-07-01','cycle_count_variance','increase_cycle_count_frequency',
     'in_progress','Suresh Rao','2026-08-22',null,
     'Weekly cycle counts introduced for the oversized gantry-parts zone to catch slotting drift early.'),
    ('Pune Cross-Dock Hub','E2','2026-07-01','sku_mislabeling','implement_barcode_scan_verification',
     'overdue','Anita Sharma','2026-08-10',null,
     'Barcode scan-verify at returns intake delayed by hardware procurement — mis-picks continuing.'),
    ('Chennai Spare Parts Hub','C3','2026-06-01','putaway_error','automate_putaway_confirmation',
     'open','Meena Iyer','2026-08-30',null,
     'Ultrasound-cart parts putaway to move to scan-confirm; vendor quote for scanners under review.'),
    ('Nagpur Regional DC','B2','2026-06-01','inadequate_bin_slotting','reslot_bins_by_velocity',
     'closed','Vikram Joshi','2026-07-10','2026-07-08',
     'Shared bin locations split by SKU velocity; July accuracy already recovering.'),
    ('Chennai Spare Parts Hub','E3','2026-08-01','triage_desk_gap','add_returns_triage_desk',
     'closed','Lakshmi Menon','2026-08-12','2026-08-11',
     'New returns triage desk live — mis-pick rate on RMA units already trending down.')
  ) as q(wh, zn, pmon, rc, ca, cst, own, tcd, acd, nt)
  join public.pickpack_r3721 e
    on e.organization_id = v_org_id
   and e.warehouse_name = q.wh
   and e.zone = q.zn
   and e.period_month = q.pmon::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Pick-pack status distribution
create or replace function public.founder_r3721_pickpack_status_rollup()
returns table(pickpack_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pickpack_r3721)
  select l.pickpack_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pickpack_r3721 l
  group by l.pickpack_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3721_pickpack_status_rollup() from public, anon;
grant execute on function public.founder_r3721_pickpack_status_rollup() to authenticated;

-- 2) Warehouse-level pick-pack scorecard
create or replace function public.founder_r3721_warehouse_scorecard()
returns table(
  warehouse_name text,
  entries bigint,
  total_orders_picked bigint,
  total_pick_errors bigint,
  avg_pick_accuracy_pct numeric,
  avg_pick_time_minutes numeric,
  total_mis_slotted_bins bigint,
  total_dispatch_errors bigint,
  total_returns_due_to_pick_error bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warehouse_name,
    count(*)::bigint,
    coalesce(sum(l.orders_picked),0)::bigint,
    coalesce(sum(l.pick_errors),0)::bigint,
    round(avg(l.pick_accuracy_pct), 1),
    round(avg(l.avg_pick_time_minutes), 1),
    coalesce(sum(l.mis_slotted_bins),0)::bigint,
    coalesce(sum(l.dispatch_errors),0)::bigint,
    coalesce(sum(l.returns_due_to_pick_error),0)::bigint
  from public.pickpack_r3721 l
  group by l.warehouse_name
  order by round(avg(l.pick_accuracy_pct), 1) asc;
end;
$$;

revoke all on function public.founder_r3721_warehouse_scorecard() from public, anon;
grant execute on function public.founder_r3721_warehouse_scorecard() to authenticated;

-- 3) Zone class × pick-pack status matrix
create or replace function public.founder_r3721_zone_class_status_matrix()
returns table(zone_class text, pickpack_status text, entries bigint, avg_pick_accuracy_pct numeric, avg_dispatch_errors numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.zone_class, l.pickpack_status, count(*)::bigint,
    round(avg(l.pick_accuracy_pct), 1),
    round(avg(l.dispatch_errors), 1)
  from public.pickpack_r3721 l
  group by l.zone_class, l.pickpack_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3721_zone_class_status_matrix() from public, anon;
grant execute on function public.founder_r3721_zone_class_status_matrix() to authenticated;

-- 4) Monthly accuracy trend
create or replace function public.founder_r3721_monthly_accuracy_trend()
returns table(period_month date, entries bigint, total_orders_picked bigint, avg_pick_accuracy_pct numeric, avg_pick_time_minutes numeric, high_error_entries bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.orders_picked),0)::bigint,
    round(avg(l.pick_accuracy_pct), 1),
    round(avg(l.avg_pick_time_minutes), 1),
    count(*) filter (where l.pickpack_status in ('high_error','critical_error'))::bigint
  from public.pickpack_r3721 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3721_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3721_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3721_capa_status_board()
returns table(capa_status text, findings bigint, avg_days_to_target numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.target_close_date - c.created_at::date), 1),
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.pickpack_capa_actions_r3721 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3721_capa_status_board() from public, anon;
grant execute on function public.founder_r3721_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3721_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pickpack_capa_actions_r3721)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pickpack_capa_actions_r3721 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3721_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3721_root_cause_pareto() to authenticated;

-- 7) Mis-slot digest
create or replace function public.founder_r3721_mis_slot_digest()
returns table(warehouse_name text, zone text, entries bigint, total_mis_slotted_bins bigint, avg_mis_slotted_bins numeric, high_mis_slot_entries bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warehouse_name, l.zone,
    count(*)::bigint,
    coalesce(sum(l.mis_slotted_bins),0)::bigint,
    round(avg(l.mis_slotted_bins), 1),
    count(*) filter (where l.mis_slotted_bins >= 10)::bigint
  from public.pickpack_r3721 l
  group by l.warehouse_name, l.zone
  order by coalesce(sum(l.mis_slotted_bins),0) desc;
end;
$$;

revoke all on function public.founder_r3721_mis_slot_digest() from public, anon;
grant execute on function public.founder_r3721_mis_slot_digest() to authenticated;

-- 8) High-risk queue (high_error / critical_error)
create or replace function public.founder_r3721_high_risk_queue()
returns table(
  warehouse_name text,
  zone text,
  zone_class text,
  period_month date,
  pick_accuracy_pct numeric,
  dispatch_errors int,
  mis_slotted_bins int,
  pickpack_status text,
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
  select l.warehouse_name, l.zone, l.zone_class, l.period_month,
    l.pick_accuracy_pct, l.dispatch_errors, l.mis_slotted_bins,
    l.pickpack_status, l.trend_dir, l.notes
  from public.pickpack_r3721 l
  where l.pickpack_status in ('high_error','critical_error')
  order by l.pick_accuracy_pct asc, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3721_high_risk_queue() from public, anon;
grant execute on function public.founder_r3721_high_risk_queue() to authenticated;
