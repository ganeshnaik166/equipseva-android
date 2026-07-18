-- Round 3184: Engineer Route-Efficiency, Travel-Time & Job-Density Optimisation Tracker
-- Field-service route log — engineer day × km travelled × travel/wrench minutes × ratio × job density × zone coverage × fuel cost × CAPA

-- =============================================================================
-- TABLE 1: route_efficiency_r3184 — per-engineer per-day route efficiency log
-- =============================================================================
create table if not exists public.route_efficiency_r3184 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_tag text not null,
  engineer_name text not null,
  engineer_code text not null,
  hospital_name text not null,
  zone_name text not null,
  day_date date not null,
  shift_type text not null check (shift_type in (
    'regular_day','extended_day','night_emergency','weekend_oncall','split_shift'
  )),
  zone_coverage text not null check (zone_coverage in (
    'single_zone','dual_zone','multi_zone_sprawl','out_of_zone_dispatch','intra_campus'
  )),
  jobs_assigned int not null,
  jobs_completed int not null,
  jobs_carried_over int,
  km_travelled numeric(6,1) not null,
  travel_minutes int not null,
  wrench_minutes int not null,
  idle_minutes int,
  travel_to_wrench_ratio numeric(5,2) not null,
  first_job_start timestamptz,
  last_job_end timestamptz,
  route_plan_source text not null check (route_plan_source in (
    'auto_optimizer','dispatcher_manual','engineer_self_routed','emergency_override','customer_priority_lock'
  )),
  vehicle_type text not null check (vehicle_type in (
    'two_wheeler','four_wheeler_van','public_transport','company_ev_scooter','walking_campus'
  )),
  traffic_severity text check (traffic_severity in (
    'light','moderate','heavy','gridlock','not_recorded'
  )),
  fuel_cost_rupees numeric(8,2),
  route_verdict text not null check (route_verdict in (
    'optimal','acceptable','inefficient','severely_inefficient','data_incomplete','under_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.route_efficiency_r3184 enable row level security;

create index if not exists idx_route_eff_r3184_org on public.route_efficiency_r3184(organization_id);
create index if not exists idx_route_eff_r3184_date on public.route_efficiency_r3184(day_date);
create index if not exists idx_route_eff_r3184_verdict on public.route_efficiency_r3184(route_verdict);

-- =============================================================================
-- TABLE 2: route_efficiency_capa_actions_r3184 — optimisation & CAPA actions
-- =============================================================================
create table if not exists public.route_efficiency_capa_actions_r3184 (
  id uuid primary key default gen_random_uuid(),
  route_log_id uuid not null references public.route_efficiency_r3184(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excessive_backtracking','zone_hopping','high_idle_time','low_job_density',
    'traffic_misplanning','fuel_overspend','missed_sla_window','overloaded_route',
    'underutilized_engineer','data_gap_gps'
  )),
  root_cause text not null check (root_cause in (
    'dispatcher_manual_override','optimizer_stale_traffic_data','customer_reschedule_cascade',
    'spare_part_pickup_detour','engineer_skill_mismatch','emergency_insertion',
    'gps_tracking_dropout','zone_boundary_misdrawn','vehicle_breakdown','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retrain_dispatcher','refresh_optimizer_traffic_feed','rebalance_zone_boundaries',
    'stage_spares_at_hub','swap_engineer_skill_map','add_buffer_slots',
    'fix_gps_device','enforce_route_adherence','provision_ev_scooter','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'sla_breach_risk','customer_credit_due','none','internal_only','contract_penalty_exposure','safety_concern'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.route_efficiency_capa_actions_r3184 enable row level security;

create index if not exists idx_route_eff_capa_r3184_log on public.route_efficiency_capa_actions_r3184(route_log_id);
create index if not exists idx_route_eff_capa_r3184_status on public.route_efficiency_capa_actions_r3184(capa_status);

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

  -- 14 route-day rows
  insert into public.route_efficiency_r3184 (
    organization_id, route_tag, engineer_name, engineer_code, hospital_name, zone_name,
    day_date, shift_type, zone_coverage,
    jobs_assigned, jobs_completed, jobs_carried_over,
    km_travelled, travel_minutes, wrench_minutes, idle_minutes, travel_to_wrench_ratio,
    first_job_start, last_job_end,
    route_plan_source, vehicle_type, traffic_severity, fuel_cost_rupees,
    route_verdict, notes
  )
  select v_org_id, q.tag, q.en, q.ec, q.hosp, q.zn,
    q.dd::date, q.st, q.zc,
    q.ja, q.jc, q.jco,
    q.km, q.tm, q.wm, q.im, q.ratio,
    q.fs::timestamptz, q.le::timestamptz,
    q.rps, q.vt, q.ts, q.fc,
    q.rv, q.nt
  from (values
    ('RT-APL-0701-VK','Vikram Rao','ENG-HYD-01','Apollo Hyderabad Jubilee Hills','Hyderabad West','2026-07-01','regular_day','single_zone',
     6,6,0,38.4,95,310,25,0.31,'2026-07-01 09:05:00+05:30','2026-07-01 17:40:00+05:30','auto_optimizer','two_wheeler','moderate',210.00,'optimal','Tight Jubilee Hills cluster — best ratio this week'),
    ('RT-APL-0702-VK','Vikram Rao','ENG-HYD-01','Apollo Hyderabad Jubilee Hills','Hyderabad West','2026-07-02','regular_day','dual_zone',
     5,4,1,61.2,175,240,40,0.73,'2026-07-02 09:20:00+05:30','2026-07-02 18:30:00+05:30','dispatcher_manual','two_wheeler','heavy',335.00,'inefficient','Manual reroute to Gachibowli mid-day — optimizer plan discarded'),
    ('RT-FRT-0701-SK','Suresh Kumar','ENG-BLR-04','Fortis Bannerghatta Bengaluru','Bengaluru South','2026-07-01','regular_day','single_zone',
     7,7,0,42.0,110,335,15,0.33,'2026-07-01 08:50:00+05:30','2026-07-01 17:55:00+05:30','auto_optimizer','company_ev_scooter','moderate',95.00,'optimal','Bannerghatta corridor loop — EV scooter kept fuel cost low'),
    ('RT-FRT-0702-SK','Suresh Kumar','ENG-BLR-04','Fortis Bannerghatta Bengaluru','Bengaluru South','2026-07-02','extended_day','multi_zone_sprawl',
     6,4,2,88.7,260,190,55,1.37,'2026-07-02 08:40:00+05:30','2026-07-02 20:10:00+05:30','emergency_override','four_wheeler_van','gridlock',640.00,'severely_inefficient','Code-red insertion at Whitefield dragged route across three zones'),
    ('RT-MNP-0701-AN','Anita Nair','ENG-BLR-09','Manipal Whitefield Bengaluru','Bengaluru East','2026-07-01','extended_day','dual_zone',
     8,7,1,57.3,150,365,20,0.41,'2026-07-01 08:30:00+05:30','2026-07-01 19:15:00+05:30','auto_optimizer','four_wheeler_van','heavy',410.00,'acceptable','ORR jam added 35 min but job density held'),
    ('RT-MNP-0629-AN','Anita Nair','ENG-BLR-09','Manipal Whitefield Bengaluru','Bengaluru East','2026-06-29','weekend_oncall','out_of_zone_dispatch',
     3,3,0,74.5,220,150,10,1.47,'2026-06-29 10:00:00+05:30','2026-06-29 16:40:00+05:30','customer_priority_lock','four_wheeler_van','light',520.00,'inefficient','Weekend VIP contract pulled her out to Electronic City'),
    ('RT-AIM-0701-RJ','Rajesh Meena','ENG-DEL-02','AIIMS New Delhi Ansari Nagar','Delhi Central','2026-07-01','regular_day','single_zone',
     9,9,0,29.8,80,400,10,0.20,'2026-07-01 08:15:00+05:30','2026-07-01 17:30:00+05:30','auto_optimizer','two_wheeler','moderate',165.00,'optimal','Campus-dense route — best jobs-per-day in fleet'),
    ('RT-AIM-0702-RJ','Rajesh Meena','ENG-DEL-02','AIIMS New Delhi Ansari Nagar','Delhi Central','2026-07-02','regular_day','intra_campus',
     10,8,2,8.5,45,380,65,0.12,'2026-07-02 08:20:00+05:30','2026-07-02 17:50:00+05:30','engineer_self_routed','walking_campus','not_recorded',0.00,'acceptable','Two ventilator jobs overran — carryover to Friday'),
    ('RT-KIM-0701-PT','Praveen Thota','ENG-HYD-07','KIMS Secunderabad','Hyderabad North','2026-07-01','regular_day','dual_zone',
     5,5,0,52.6,165,230,35,0.72,'2026-07-01 09:10:00+05:30','2026-07-01 18:05:00+05:30','dispatcher_manual','two_wheeler','heavy',290.00,'inefficient','Backtracked twice for spare pickup at Paradise hub'),
    ('RT-CAR-0630-LD','Lakshmi Devi','ENG-HYD-12','Care Hospitals Banjara Hills','Hyderabad West','2026-06-30','regular_day','single_zone',
     6,5,1,33.9,90,295,30,0.31,'2026-06-30 09:00:00+05:30','2026-06-30 17:25:00+05:30','auto_optimizer','company_ev_scooter','moderate',75.00,'acceptable','One infusion-pump job rescheduled by ward'),
    ('RT-YSH-0630-MI','Mohammed Irfan','ENG-HYD-05','Yashoda Somajiguda Hyderabad','Hyderabad Central','2026-06-30','night_emergency','single_zone',
     2,2,0,18.2,40,170,5,0.24,'2026-06-30 22:10:00+05:30','2026-07-01 01:35:00+05:30','emergency_override','two_wheeler','light',100.00,'optimal','Night dialysis-machine call pair — clean run'),
    ('RT-STJ-0630-JG','John George','ENG-BLR-11','St John''s Bengaluru','Bengaluru Central','2026-06-30','regular_day','multi_zone_sprawl',
     4,3,1,96.4,290,145,50,2.00,'2026-06-30 08:45:00+05:30','2026-06-30 19:40:00+05:30','dispatcher_manual','four_wheeler_van','gridlock',710.00,'severely_inefficient','Crossed Silk Board twice — worst ratio this month'),
    ('RT-RBW-0628-SP','Sandhya Pillai','ENG-HYD-09','Rainbow Children''s Hyderabad','Hyderabad West','2026-06-28','split_shift','single_zone',
     5,4,1,36.7,105,255,45,0.41,'2026-06-28 08:55:00+05:30','2026-06-28 18:20:00+05:30','auto_optimizer','two_wheeler','moderate',200.00,'under_review','GPS dropout 11:20 to 12:05 — km figure interpolated'),
    ('RT-KIM-0628-PT','Praveen Thota','ENG-HYD-07','KIMS Secunderabad','Hyderabad North','2026-06-28','regular_day','single_zone',
     6,6,0,41.0,120,300,20,0.40,'2026-06-28 09:05:00+05:30','2026-06-28 17:45:00+05:30','auto_optimizer','two_wheeler','moderate',225.00,'acceptable','Clean single-zone loop')
  ) as q(tag, en, ec, hosp, zn, dd, st, zc, ja, jc, jco, km, tm, wm, im, ratio, fs, le, rps, vt, ts, fc, rv, nt);

  -- CAPA seed — attach to specific route days
  insert into public.route_efficiency_capa_actions_r3184 (
    route_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('RT-FRT-0702-SK','zone_hopping','emergency_insertion','add_buffer_slots','2026-07-08',null,'in_progress','sla_breach_risk',12000.00,'Reserve one emergency slot per zone per shift'),
    ('RT-STJ-0630-JG','excessive_backtracking','dispatcher_manual_override','retrain_dispatcher','2026-07-06','2026-07-04','closed','contract_penalty_exposure',8000.00,'Dispatcher coached on optimizer-first policy'),
    ('RT-KIM-0701-PT','fuel_overspend','spare_part_pickup_detour','stage_spares_at_hub','2026-07-10',null,'open','internal_only',35000.00,'Stock fast-moving spares at Secunderabad hub'),
    ('RT-RBW-0628-SP','data_gap_gps','gps_tracking_dropout','fix_gps_device','2026-07-03',null,'overdue','none',4500.00,'Tracker battery swap pending two weeks'),
    ('RT-APL-0702-VK','traffic_misplanning','optimizer_stale_traffic_data','refresh_optimizer_traffic_feed','2026-07-09',null,'verification_pending','sla_breach_risk',22000.00,'Traffic feed upgraded to 5-min refresh — verifying'),
    ('RT-MNP-0629-AN','missed_sla_window','customer_reschedule_cascade','rebalance_zone_boundaries','2026-07-12',null,'escalated','customer_credit_due',18000.00,'VIP contract pulled zone coverage — redraw proposal with ops head')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.route_efficiency_r3184 e
    on e.organization_id = v_org_id and e.route_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Route verdict distribution
create or replace function public.founder_r3184_route_verdict_rollup()
returns table(route_verdict text, route_days bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.route_efficiency_r3184)
  select l.route_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.route_efficiency_r3184 l
  group by l.route_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3184_route_verdict_rollup() from public, anon;
grant execute on function public.founder_r3184_route_verdict_rollup() to authenticated;

-- 2) Engineer efficiency scorecard
create or replace function public.founder_r3184_engineer_scorecard()
returns table(
  engineer_name text,
  engineer_code text,
  route_days bigint,
  jobs_done bigint,
  total_km numeric,
  avg_travel_to_wrench numeric,
  avg_jobs_per_day numeric,
  total_fuel_rupees numeric,
  optimal_days bigint,
  efficiency_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.engineer_code,
    count(*)::bigint,
    coalesce(sum(l.jobs_completed),0)::bigint,
    round(coalesce(sum(l.km_travelled),0)::numeric, 1),
    round(avg(l.travel_to_wrench_ratio)::numeric, 2),
    round(avg(l.jobs_completed)::numeric, 1),
    round(coalesce(sum(l.fuel_cost_rupees),0)::numeric, 0),
    count(*) filter (where l.route_verdict = 'optimal')::bigint,
    round(100.0 * count(*) filter (where l.route_verdict in ('optimal','acceptable'))::numeric / nullif(count(*),0), 1)
  from public.route_efficiency_r3184 l
  group by l.engineer_name, l.engineer_code
  order by count(*) desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3184_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3184_engineer_scorecard() to authenticated;

-- 3) Zone coverage × route plan source matrix
create or replace function public.founder_r3184_zone_coverage_matrix()
returns table(zone_coverage text, route_plan_source text, route_days bigint, avg_km numeric, avg_travel_to_wrench numeric, jobs_done bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.zone_coverage, l.route_plan_source, count(*)::bigint,
    round(avg(l.km_travelled)::numeric, 1),
    round(avg(l.travel_to_wrench_ratio)::numeric, 2),
    coalesce(sum(l.jobs_completed),0)::bigint
  from public.route_efficiency_r3184 l
  group by l.zone_coverage, l.route_plan_source
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3184_zone_coverage_matrix() from public, anon;
grant execute on function public.founder_r3184_zone_coverage_matrix() to authenticated;

-- 4) Daily fleet trend
create or replace function public.founder_r3184_daily_trend()
returns table(day_date date, routes bigint, jobs_done bigint, total_km numeric, avg_travel_min numeric, avg_wrench_min numeric, avg_travel_to_wrench numeric, fuel_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.day_date, count(*)::bigint,
    coalesce(sum(l.jobs_completed),0)::bigint,
    round(coalesce(sum(l.km_travelled),0)::numeric, 1),
    round(avg(l.travel_minutes)::numeric, 0),
    round(avg(l.wrench_minutes)::numeric, 0),
    round(avg(l.travel_to_wrench_ratio)::numeric, 2),
    round(coalesce(sum(l.fuel_cost_rupees),0)::numeric, 0)
  from public.route_efficiency_r3184 l
  group by l.day_date
  order by l.day_date desc;
end;
$$;

revoke execute on function public.founder_r3184_daily_trend() from public, anon;
grant execute on function public.founder_r3184_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3184_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.route_efficiency_capa_actions_r3184 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3184_capa_status_board() from public, anon;
grant execute on function public.founder_r3184_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3184_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.route_efficiency_capa_actions_r3184)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.route_efficiency_capa_actions_r3184 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3184_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3184_root_cause_pareto() to authenticated;

-- 7) Regulatory / contract impact digest
create or replace function public.founder_r3184_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.route_efficiency_capa_actions_r3184 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3184_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3184_regulatory_impact_digest() to authenticated;

-- 8) High-risk / inefficient routes queue
create or replace function public.founder_r3184_high_risk_routes()
returns table(
  engineer_name text,
  hospital_name text,
  zone_name text,
  day_date date,
  route_verdict text,
  travel_to_wrench numeric,
  km_travelled numeric,
  jobs_done int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.zone_name, l.day_date,
    l.route_verdict, l.travel_to_wrench_ratio, l.km_travelled, l.jobs_completed, l.notes
  from public.route_efficiency_r3184 l
  where l.route_verdict in ('inefficient','severely_inefficient','data_incomplete','under_review')
     or l.travel_to_wrench_ratio >= 1.00
  order by l.travel_to_wrench_ratio desc, l.day_date desc;
end;
$$;

revoke execute on function public.founder_r3184_high_risk_routes() from public, anon;
grant execute on function public.founder_r3184_high_risk_routes() to authenticated;
