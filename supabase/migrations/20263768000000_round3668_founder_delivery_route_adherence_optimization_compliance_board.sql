-- Round 3668: Delivery Route-Adherence / Optimization Compliance Board
-- Logistics governance — route × region × period × trips on-route × adherence % × planned vs actual km × km variance × fuel cost × unauthorized stops × delay × route type × trend × CAPA

-- =============================================================================
-- TABLE 1: route_adherence_r3668 — per-route monthly adherence & optimization log
-- =============================================================================
create table if not exists public.route_adherence_r3668 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_code text not null,
  route_name text not null,
  region text not null,
  period_month date not null,
  trips_planned int not null,
  trips_on_route int not null,
  adherence_pct numeric(5,1),
  planned_km numeric(8,1),
  actual_km numeric(8,1),
  km_variance_pct numeric(5,1),
  fuel_cost_rupees numeric(12,2),
  unauthorized_stops int not null default 0,
  avg_delay_min numeric(6,1),
  route_type text not null check (route_type in (
    'delivery_van','field_engineer','spare_courier','milk_run','emergency'
  )),
  adherence_status text not null check (adherence_status in (
    'on_route','minor_deviation','frequent_deviation','uncontrolled','unplanned'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.route_adherence_r3668 enable row level security;

create index if not exists idx_route_adherence_r3668_org on public.route_adherence_r3668(organization_id);
create index if not exists idx_route_adherence_r3668_month on public.route_adherence_r3668(period_month);
create index if not exists idx_route_adherence_r3668_status on public.route_adherence_r3668(adherence_status);

-- =============================================================================
-- TABLE 2: route_adherence_capa_actions_r3668 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.route_adherence_capa_actions_r3668 (
  id uuid primary key default gen_random_uuid(),
  route_log_id uuid not null references public.route_adherence_r3668(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'traffic_congestion','driver_unfamiliar_with_route','unauthorized_personal_stops',
    'route_plan_outdated','road_closure_diversion','vehicle_breakdown',
    'emergency_dispatch_no_plan','gps_tracker_offline','courier_vendor_noncompliance',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replan_route_sequence','driver_route_training','enable_geofence_alerts',
    'update_route_master','switch_courier_vendor','install_gps_tracker',
    'add_emergency_route_playbook','disciplinary_counselling','schedule_offpeak_departure',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  excess_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.route_adherence_capa_actions_r3668 enable row level security;

create index if not exists idx_route_adherence_capa_r3668_log on public.route_adherence_capa_actions_r3668(route_log_id);
create index if not exists idx_route_adherence_capa_r3668_status on public.route_adherence_capa_actions_r3668(capa_status);

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

  -- 16 route-adherence rows
  insert into public.route_adherence_r3668 (
    organization_id, route_code, route_name, region, period_month,
    trips_planned, trips_on_route, adherence_pct, planned_km, actual_km,
    km_variance_pct, fuel_cost_rupees, unauthorized_stops, avg_delay_min,
    route_type, adherence_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.rname, q.rgn, q.pmon::date,
    q.tp, q.tor, q.adh, q.pkm, q.akm,
    q.kvar, q.fuel, q.ustops, q.delay,
    q.rtype, q.astat, q.tdir, q.nt
  from (values
    ('RT-MUM-PNQ-01','Mumbai-Pune Expressway Delivery','West','2026-07-01',
     22,21,95.5,3280.0,3355.0,2.3,52400.00,1,12.4,'delivery_van','on_route','stable','Consistent expressway run — minor toll-plaza delays only'),
    ('RT-MUM-NSK-02','Mumbai-Nashik Spare Courier','West','2026-07-01',
     18,15,83.3,2470.0,2720.0,10.1,41800.00,3,28.6,'spare_courier','frequent_deviation','worsening','Courier detouring via Bhiwandi hub without approval'),
    ('RT-DEL-GGN-03','Delhi-Gurgaon Hospital Milk Run','North','2026-07-01',
     26,25,96.2,1140.0,1165.0,2.2,19800.00,0,8.9,'milk_run','on_route','improving','NH-48 milk run covering 6 hospitals — clean month'),
    ('RT-DEL-NOI-04','Delhi-Noida Field Engineer Beat','North','2026-07-01',
     20,17,85.0,860.0,955.0,11.0,16400.00,2,22.1,'field_engineer','minor_deviation','stable','DND flyway closures forcing ad-hoc reroutes'),
    ('RT-CHN-VLR-05','Chennai-Vellore CMC Delivery','South','2026-07-01',
     16,15,93.8,2210.0,2265.0,2.5,36200.00,1,10.2,'delivery_van','on_route','stable','CMC Vellore weekly consumables run on plan'),
    ('RT-BLR-CTY-06','Bengaluru City Field Engineer Beat','South','2026-07-01',
     30,22,73.3,1490.0,1810.0,21.5,31500.00,5,41.7,'field_engineer','uncontrolled','worsening','ORR congestion — engineers skipping planned sequence daily'),
    ('RT-HYD-SEC-07','Hyderabad-Secunderabad Milk Run','South','2026-07-01',
     24,23,95.8,920.0,940.0,2.2,15100.00,0,7.5,'milk_run','on_route','stable','Twin-city hospital loop running to plan'),
    ('RT-KOL-HWH-08','Kolkata-Howrah Delivery Van','East','2026-07-01',
     14,11,78.6,760.0,880.0,15.8,14900.00,4,33.2,'delivery_van','frequent_deviation','stable','Howrah bridge restrictions pushing vans onto longer loops'),
    ('RT-PNQ-AUR-09','Pune-Aurangabad Spare Courier','West','2026-06-01',
     12,10,83.3,2860.0,3090.0,8.0,44700.00,2,19.8,'spare_courier','minor_deviation','improving','New courier vendor settling in — variance narrowing'),
    ('RT-AHM-VAD-10','Ahmedabad-Vadodara Delivery','West','2026-06-01',
     15,14,93.3,1680.0,1715.0,2.1,27300.00,1,9.4,'delivery_van','on_route','stable','Expressway run stable after RFID toll tags issued'),
    ('RT-DEL-JPR-11','Delhi-Jaipur Emergency Dispatch','North','2026-06-01',
     6,4,66.7,1620.0,1930.0,19.1,29800.00,2,55.3,'emergency','unplanned','worsening','Emergency ventilator dispatches run without route plans'),
    ('RT-CHN-MDU-12','Chennai-Madurai Overnight Delivery','South','2026-06-01',
     10,9,90.0,4560.0,4680.0,2.6,71200.00,1,14.6,'delivery_van','minor_deviation','stable','Overnight trunk route — one diversion at Trichy bypass'),
    ('RT-BLR-MYS-13','Bengaluru-Mysuru Field Engineer Beat','South','2026-06-01',
     18,16,88.9,2540.0,2660.0,4.7,39400.00,1,16.3,'field_engineer','minor_deviation','improving','Expressway beat improving after geofence alerts enabled'),
    ('RT-LKO-KNP-14','Lucknow-Kanpur Milk Run','North','2026-05-01',
     20,18,90.0,1580.0,1650.0,4.4,26100.00,1,13.8,'milk_run','minor_deviation','stable','Ganga barrage repairs added detour km mid-month'),
    ('RT-KOC-TVM-15','Kochi-Thiruvananthapuram Delivery','South','2026-05-01',
     12,12,100.0,2620.0,2635.0,0.6,40600.00,0,6.2,'delivery_van','on_route','improving','NH-66 run fully on plan — best route in fleet'),
    ('RT-NGP-RPR-16','Nagpur-Raipur Emergency Dispatch','Central','2026-05-01',
     5,3,60.0,1410.0,1760.0,24.8,27600.00,3,62.4,'emergency','uncontrolled','worsening','Dialysis machine emergencies dispatched off-plan via Bhandara')
  ) as q(rcode, rname, rgn, pmon, tp, tor, adh, pkm, akm, kvar, fuel, ustops, delay, rtype, astat, tdir, nt);

  -- CAPA seed — attach to specific routes via route_code
  insert into public.route_adherence_capa_actions_r3668 (
    route_log_id, root_cause, corrective_action, capa_status,
    excess_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.xcost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RT-BLR-CTY-06','traffic_congestion','replan_route_sequence','in_progress',18600.00,'Ravi Kulkarni','2026-07-25',null,'ORR beat being resequenced to off-peak windows'),
    ('RT-DEL-JPR-11','emergency_dispatch_no_plan','add_emergency_route_playbook','open',9400.00,'Sunita Sharma','2026-07-30',null,'Emergency dispatch playbook with pre-cleared NH-48 route drafted'),
    ('RT-MUM-NSK-02','courier_vendor_noncompliance','switch_courier_vendor','escalated',12700.00,'Amit Deshpande','2026-07-20',null,'Vendor detouring via own hub — contract escalation issued'),
    ('RT-KOL-HWH-08','road_closure_diversion','update_route_master','closed',6800.00,'Priya Banerjee','2026-07-10','2026-07-08','Route master updated with Vidyasagar Setu alternative'),
    ('RT-NGP-RPR-16','emergency_dispatch_no_plan','install_gps_tracker','overdue',15300.00,'Vikram Rao','2026-06-15',null,'GPS trackers for emergency vans past install date — vendor delay'),
    ('RT-DEL-NOI-04','route_plan_outdated','update_route_master','verification_pending',4100.00,'Sunita Sharma','2026-07-18',null,'DND closure detours added — verifying next beat cycle'),
    ('RT-BLR-CTY-06','unauthorized_personal_stops','disciplinary_counselling','in_progress',5200.00,'Ravi Kulkarni','2026-07-22',null,'Two engineers counselled for repeated unauthorized halts'),
    ('RT-PNQ-AUR-09','driver_unfamiliar_with_route','driver_route_training','closed',3600.00,'Amit Deshpande','2026-06-28','2026-06-25','New courier drivers completed route familiarisation')
  ) as q(rcode, rc, ca, cst, xcost, ownr, tcd, acd, nt)
  join public.route_adherence_r3668 e
    on e.organization_id = v_org_id and e.route_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adherence status distribution
create or replace function public.founder_r3668_adherence_status_rollup()
returns table(adherence_status text, routes bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.route_adherence_r3668)
  select l.adherence_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.route_adherence_r3668 l
  group by l.adherence_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3668_adherence_status_rollup() from public, anon;
grant execute on function public.founder_r3668_adherence_status_rollup() to authenticated;

-- 2) Region-level adherence scorecard
create or replace function public.founder_r3668_region_scorecard()
returns table(
  region text,
  routes bigint,
  on_route bigint,
  deviating bigint,
  off_plan bigint,
  avg_adherence_pct numeric,
  avg_km_variance_pct numeric,
  total_fuel_cost_rupees numeric,
  unauthorized_stops bigint
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
    count(*) filter (where l.adherence_status = 'on_route')::bigint,
    count(*) filter (where l.adherence_status in ('minor_deviation','frequent_deviation'))::bigint,
    count(*) filter (where l.adherence_status in ('uncontrolled','unplanned'))::bigint,
    round(avg(l.adherence_pct), 1),
    round(avg(l.km_variance_pct), 1),
    coalesce(sum(l.fuel_cost_rupees),0)::numeric,
    coalesce(sum(l.unauthorized_stops),0)::bigint
  from public.route_adherence_r3668 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3668_region_scorecard() from public, anon;
grant execute on function public.founder_r3668_region_scorecard() to authenticated;

-- 3) Route type × adherence status matrix
create or replace function public.founder_r3668_route_type_status_matrix()
returns table(route_type text, adherence_status text, routes bigint, avg_adherence_pct numeric, avg_km_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.route_type, l.adherence_status, count(*)::bigint,
    round(avg(l.adherence_pct), 1),
    round(avg(l.km_variance_pct), 1)
  from public.route_adherence_r3668 l
  group by l.route_type, l.adherence_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3668_route_type_status_matrix() from public, anon;
grant execute on function public.founder_r3668_route_type_status_matrix() to authenticated;

-- 4) Monthly adherence trend
create or replace function public.founder_r3668_monthly_adherence_trend()
returns table(period_month date, routes bigint, avg_adherence_pct numeric, avg_km_variance_pct numeric, total_fuel_cost_rupees numeric, unauthorized_stops bigint, avg_delay_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.adherence_pct), 1),
    round(avg(l.km_variance_pct), 1),
    coalesce(sum(l.fuel_cost_rupees),0)::numeric,
    coalesce(sum(l.unauthorized_stops),0)::bigint,
    round(avg(l.avg_delay_min), 1)
  from public.route_adherence_r3668 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3668_monthly_adherence_trend() from public, anon;
grant execute on function public.founder_r3668_monthly_adherence_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3668_capa_status_board()
returns table(capa_status text, actions bigint, avg_excess_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.excess_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.route_adherence_capa_actions_r3668 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3668_capa_status_board() from public, anon;
grant execute on function public.founder_r3668_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3668_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_excess_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.route_adherence_capa_actions_r3668)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.excess_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.route_adherence_capa_actions_r3668 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3668_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3668_root_cause_pareto() to authenticated;

-- 7) Km-variance digest by route type
create or replace function public.founder_r3668_km_variance_digest()
returns table(route_type text, routes bigint, total_planned_km numeric, total_actual_km numeric, excess_km numeric, avg_km_variance_pct numeric, total_fuel_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.route_type,
    count(*)::bigint,
    coalesce(sum(l.planned_km),0)::numeric,
    coalesce(sum(l.actual_km),0)::numeric,
    (coalesce(sum(l.actual_km),0) - coalesce(sum(l.planned_km),0))::numeric,
    round(avg(l.km_variance_pct), 1),
    coalesce(sum(l.fuel_cost_rupees),0)::numeric
  from public.route_adherence_r3668 l
  group by l.route_type
  order by (coalesce(sum(l.actual_km),0) - coalesce(sum(l.planned_km),0)) desc;
end;
$$;

revoke execute on function public.founder_r3668_km_variance_digest() from public, anon;
grant execute on function public.founder_r3668_km_variance_digest() to authenticated;

-- 8) High-risk route queue (uncontrolled / unplanned / worsening deviations)
create or replace function public.founder_r3668_high_risk_queue()
returns table(
  route_code text,
  route_name text,
  region text,
  period_month date,
  route_type text,
  adherence_status text,
  trend_dir text,
  adherence_pct numeric,
  km_variance_pct numeric,
  unauthorized_stops int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.route_code, l.route_name, l.region, l.period_month, l.route_type,
    l.adherence_status, l.trend_dir, l.adherence_pct, l.km_variance_pct,
    l.unauthorized_stops, l.notes
  from public.route_adherence_r3668 l
  where l.adherence_status in ('uncontrolled','unplanned')
     or (l.adherence_status = 'frequent_deviation' and l.trend_dir = 'worsening')
     or l.unauthorized_stops >= 3
     or l.km_variance_pct >= 15.0
  order by l.period_month desc, l.km_variance_pct desc;
end;
$$;

revoke execute on function public.founder_r3668_high_risk_queue() from public, anon;
grant execute on function public.founder_r3668_high_risk_queue() to authenticated;
