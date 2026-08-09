-- Round 3688: Founder Genset / DG-Set AMC, Fuel & Runtime Board
-- Own-premises DG-set fleet — genset class × site × runtime hours × fuel consumption × fuel/hr ×
-- AMC validity × load test × battery health × start failures × readiness status × CAPA

-- =============================================================================
-- TABLE 1: genset_r3688 — per-genset per-month AMC / fuel / runtime log
-- =============================================================================
create table if not exists public.genset_r3688 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  genset_code text not null,
  site_name text not null,
  period_month date not null,
  capacity_kva numeric(8,1),
  runtime_hours numeric(8,1),
  fuel_consumed_litres numeric(10,1),
  fuel_per_hour numeric(6,2),
  amc_valid_till date,
  days_to_amc_expiry int,
  load_test_done boolean not null,
  battery_health_pct numeric(5,1),
  starts_failed int not null default 0,
  service_visits int not null default 0,
  genset_class text not null check (genset_class in (
    'below_62kva','62_125kva','125_320kva','above_320kva','portable'
  )),
  readiness_status text not null check (readiness_status in (
    'ready','service_due','amc_expiring','start_failures','not_operational'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.genset_r3688 enable row level security;

create index if not exists idx_genset_r3688_org on public.genset_r3688(organization_id);
create index if not exists idx_genset_r3688_month on public.genset_r3688(period_month);
create index if not exists idx_genset_r3688_status on public.genset_r3688(readiness_status);

-- =============================================================================
-- TABLE 2: genset_capa_actions_r3688 — CAPA actions on genset findings
-- =============================================================================
create table if not exists public.genset_capa_actions_r3688 (
  id uuid primary key default gen_random_uuid(),
  genset_log_id uuid not null references public.genset_r3688(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'battery_end_of_life','fuel_injector_clogged','amc_vendor_delay','coolant_leak',
    'starter_motor_worn','fuel_pilferage_suspected','load_test_skipped',
    'control_panel_fault','pending_investigation','diesel_quality_poor'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_battery','service_fuel_system','renew_amc_contract','repair_coolant_system',
    'replace_starter_motor','install_fuel_sensor','conduct_load_test',
    'repair_control_panel','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.genset_capa_actions_r3688 enable row level security;

create index if not exists idx_genset_capa_r3688_log on public.genset_capa_actions_r3688(genset_log_id);
create index if not exists idx_genset_capa_r3688_status on public.genset_capa_actions_r3688(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness status distribution
create or replace function public.founder_r3688_readiness_status_rollup()
returns table(readiness_status text, gensets bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.genset_r3688)
  select l.readiness_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.genset_r3688 l
  group by l.readiness_status
  order by count(*) desc;
end;
$$;

-- 2) Site-level genset scorecard
create or replace function public.founder_r3688_site_scorecard()
returns table(
  site_name text,
  gensets bigint,
  ready bigint,
  service_due bigint,
  amc_expiring bigint,
  start_failures bigint,
  not_operational bigint,
  total_runtime_hours numeric,
  avg_fuel_per_hour numeric,
  ready_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.readiness_status = 'ready')::bigint,
    count(*) filter (where l.readiness_status = 'service_due')::bigint,
    count(*) filter (where l.readiness_status = 'amc_expiring')::bigint,
    count(*) filter (where l.readiness_status = 'start_failures')::bigint,
    count(*) filter (where l.readiness_status = 'not_operational')::bigint,
    round(coalesce(sum(l.runtime_hours),0)::numeric, 1),
    round(avg(l.fuel_per_hour)::numeric, 2),
    round(100.0 * count(*) filter (where l.readiness_status = 'ready')::numeric / nullif(count(*),0), 1)
  from public.genset_r3688 l
  group by l.site_name
  order by count(*) desc;
end;
$$;

-- 3) Genset class × readiness status matrix
create or replace function public.founder_r3688_class_status_matrix()
returns table(genset_class text, readiness_status text, gensets bigint, total_runtime_hours numeric, avg_fuel_per_hour numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.genset_class, l.readiness_status, count(*)::bigint,
    round(coalesce(sum(l.runtime_hours),0)::numeric, 1),
    round(avg(l.fuel_per_hour)::numeric, 2)
  from public.genset_r3688 l
  group by l.genset_class, l.readiness_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly runtime / fuel trend
create or replace function public.founder_r3688_monthly_runtime_fuel_trend()
returns table(
  period_month date,
  gensets bigint,
  total_runtime_hours numeric,
  total_fuel_litres numeric,
  avg_fuel_per_hour numeric,
  load_tests_done bigint,
  start_failures bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(coalesce(sum(l.runtime_hours),0)::numeric, 1),
    round(coalesce(sum(l.fuel_consumed_litres),0)::numeric, 1),
    round(avg(l.fuel_per_hour)::numeric, 2),
    count(*) filter (where l.load_test_done = true)::bigint,
    coalesce(sum(l.starts_failed),0)::bigint
  from public.genset_r3688 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3688_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.genset_capa_actions_r3688 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3688_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.genset_capa_actions_r3688)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.genset_capa_actions_r3688 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Fuel efficiency digest by genset class
create or replace function public.founder_r3688_fuel_efficiency_digest()
returns table(
  genset_class text,
  gensets bigint,
  avg_capacity_kva numeric,
  total_runtime_hours numeric,
  total_fuel_litres numeric,
  avg_fuel_per_hour numeric,
  worsening bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.genset_class,
    count(*)::bigint,
    round(avg(l.capacity_kva)::numeric, 1),
    round(coalesce(sum(l.runtime_hours),0)::numeric, 1),
    round(coalesce(sum(l.fuel_consumed_litres),0)::numeric, 1),
    round(avg(l.fuel_per_hour)::numeric, 2),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.genset_r3688 l
  group by l.genset_class
  order by count(*) desc;
end;
$$;

-- 8) High-risk genset queue
create or replace function public.founder_r3688_high_risk_queue()
returns table(
  site_name text,
  genset_code text,
  genset_class text,
  period_month date,
  readiness_status text,
  starts_failed int,
  battery_health_pct numeric,
  days_to_amc_expiry int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name, l.genset_code, l.genset_class, l.period_month,
    l.readiness_status, l.starts_failed, l.battery_health_pct,
    l.days_to_amc_expiry, l.trend_dir, l.notes
  from public.genset_r3688 l
  where l.readiness_status in ('not_operational','start_failures','amc_expiring','service_due')
     or l.starts_failed > 0
     or l.battery_health_pct < 70
     or l.days_to_amc_expiry < 30
     or l.load_test_done = false
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.site_name;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3688_readiness_status_rollup() from public, anon;
revoke all on function public.founder_r3688_site_scorecard() from public, anon;
revoke all on function public.founder_r3688_class_status_matrix() from public, anon;
revoke all on function public.founder_r3688_monthly_runtime_fuel_trend() from public, anon;
revoke all on function public.founder_r3688_capa_status_board() from public, anon;
revoke all on function public.founder_r3688_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3688_fuel_efficiency_digest() from public, anon;
revoke all on function public.founder_r3688_high_risk_queue() from public, anon;

grant execute on function public.founder_r3688_readiness_status_rollup() to authenticated;
grant execute on function public.founder_r3688_site_scorecard() to authenticated;
grant execute on function public.founder_r3688_class_status_matrix() to authenticated;
grant execute on function public.founder_r3688_monthly_runtime_fuel_trend() to authenticated;
grant execute on function public.founder_r3688_capa_status_board() to authenticated;
grant execute on function public.founder_r3688_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3688_fuel_efficiency_digest() to authenticated;
grant execute on function public.founder_r3688_high_risk_queue() to authenticated;

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

  -- 16 genset month-log rows
  insert into public.genset_r3688 (
    organization_id, genset_code, site_name, period_month, capacity_kva,
    runtime_hours, fuel_consumed_litres, fuel_per_hour, amc_valid_till,
    days_to_amc_expiry, load_test_done, battery_health_pct, starts_failed,
    service_visits, genset_class, readiness_status, trend_dir, notes
  )
  select v_org_id, q.gcode, q.site, q.pmon::date, q.kva,
    q.rhrs, q.fuel, q.fph, q.amct::date,
    q.dexp, q.ltd, q.batt, q.sfail,
    q.svis, q.gcls, q.rst, q.tdir, q.nt
  from (values
    ('DG-DEL-01','Delhi HQ Warehouse','2026-07-01',125,182.5,3193.8,17.50,'2026-12-15',
     159,true,92.0,0,1,'62_125kva','ready','stable','Prime cold-room backup — Sudhir Power AMC current'),
    ('DG-DEL-02','Delhi HQ Warehouse','2026-07-01',320,96.0,4224.0,44.00,'2026-08-20',
     42,true,88.5,0,1,'125_320kva','ready','improving','Cummins 320 kVA — fuel per hour improved after injector service'),
    ('DG-DEL-03','Delhi HQ Warehouse','2026-07-01',40,12.5,87.5,7.00,'2026-08-05',
     27,false,71.0,1,0,'below_62kva','amc_expiring','worsening','Jakson AMC expiring in 4 weeks — renewal quote awaited'),
    ('DG-BHW-01','Mumbai Bhiwandi Warehouse','2026-07-01',500,210.0,9450.0,45.00,'2027-01-31',
     206,true,95.0,0,1,'above_320kva','ready','stable','Monsoon grid outages — high runtime, efficiency on target'),
    ('DG-BHW-02','Mumbai Bhiwandi Warehouse','2026-07-01',125,165.0,3135.0,19.00,'2026-09-10',
     63,false,64.0,3,2,'62_125kva','start_failures','worsening','3 failed cold starts — battery bank weak, Powerica visit logged'),
    ('DG-BHW-03','Mumbai Bhiwandi Warehouse','2026-07-01',15,8.0,28.0,3.50,'2026-11-30',
     144,true,90.0,0,0,'portable','ready','stable','Portable set for yard lighting — nominal'),
    ('DG-CHN-01','Chennai Warehouse','2026-07-01',250,142.0,5680.0,40.00,'2026-07-25',
     16,true,85.0,0,1,'125_320kva','amc_expiring','stable','Sterling and Wilson AMC expiring this month — PO under approval'),
    ('DG-CHN-02','Chennai Warehouse','2026-07-01',62.5,55.0,660.0,12.00,'2026-10-18',
     101,false,58.0,2,2,'62_125kva','service_due','worsening','Coolant top-ups repeating; 250-hr service overdue'),
    ('DG-CHN-03','Chennai Warehouse','2026-07-01',125,0.0,0.0,0.00,'2026-09-30',
     83,false,34.0,5,3,'62_125kva','not_operational','worsening','Starter motor seized — set down since 08-Jul, hire DG on standby'),
    ('DG-DEL-01','Delhi HQ Warehouse','2026-06-01',125,158.0,2844.0,18.00,'2026-12-15',
     189,true,93.0,0,1,'62_125kva','ready','stable','June — normal grid support duty'),
    ('DG-BHW-01','Mumbai Bhiwandi Warehouse','2026-06-01',500,175.0,8050.0,46.00,'2027-01-31',
     236,true,95.5,0,0,'above_320kva','ready','stable','Pre-monsoon load trial completed'),
    ('DG-BHW-02','Mumbai Bhiwandi Warehouse','2026-06-01',125,149.0,2831.0,19.00,'2026-09-10',
     93,true,72.0,1,1,'62_125kva','service_due','worsening','First start failure noted; battery voltage sagging'),
    ('DG-CHN-01','Chennai Warehouse','2026-06-01',250,128.0,4992.0,39.00,'2026-07-25',
     46,true,86.0,0,1,'125_320kva','ready','stable','June QC — AMC renewal reminder raised to procurement'),
    ('DG-CHN-02','Chennai Warehouse','2026-06-01',62.5,48.0,552.0,11.50,'2026-10-18',
     131,true,66.0,1,1,'62_125kva','service_due','worsening','Radiator fan belt noise — service ticket open'),
    ('DG-DEL-02','Delhi HQ Warehouse','2026-05-01',320,88.0,4048.0,46.00,'2026-08-20',
     111,true,89.0,0,1,'125_320kva','ready','stable','May — fuel per hour baseline before injector service'),
    ('DG-BHW-03','Mumbai Bhiwandi Warehouse','2026-05-01',15,6.0,21.0,3.50,'2026-11-30',
     214,false,91.0,0,0,'portable','ready','stable','Load test deferred to June — low usage set')
  ) as q(gcode, site, pmon, kva, rhrs, fuel, fph, amct, dexp, ltd, batt, sfail, svis, gcls, rst, tdir, nt);

  -- 8 CAPA rows — attach via genset_code + period_month
  insert into public.genset_capa_actions_r3688 (
    genset_log_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DG-BHW-02','2026-07-01','battery_end_of_life','replace_battery','in_progress',
     38000.00,'Ravi Deshmukh','2026-07-20',null,'Two 180Ah batteries ordered from Exide dealer'),
    ('DG-CHN-03','2026-07-01','starter_motor_worn','replace_starter_motor','escalated',
     52000.00,'S. Muthukumar','2026-07-15',null,'Starter seized — Sterling and Wilson escalation, hire DG billed daily'),
    ('DG-DEL-03','2026-07-01','amc_vendor_delay','renew_amc_contract','open',
     85000.00,'Neha Kapoor','2026-07-30',null,'Jakson renewal quote pending commercial approval'),
    ('DG-CHN-01','2026-07-01','amc_vendor_delay','renew_amc_contract','verification_pending',
     140000.00,'S. Muthukumar','2026-07-22',null,'PO released — awaiting signed AMC schedule from vendor'),
    ('DG-CHN-02','2026-07-01','coolant_leak','repair_coolant_system','overdue',
     18500.00,'Arun Prasad','2026-07-10',null,'Radiator hose replacement slipped past target — parts delay'),
    ('DG-BHW-02','2026-06-01','pending_investigation','conduct_load_test','closed',
     6000.00,'Ravi Deshmukh','2026-06-25','2026-06-24','Load bank test done — confirmed battery sag under crank'),
    ('DG-DEL-02','2026-05-01','fuel_injector_clogged','service_fuel_system','closed',
     24000.00,'Neha Kapoor','2026-06-05','2026-06-02','Injector overhaul cut fuel per hour from 46 to 44 litres'),
    ('DG-BHW-03','2026-05-01','load_test_skipped','conduct_load_test','closed',
     4500.00,'Ravi Deshmukh','2026-06-15','2026-06-10','Portable set load-tested in June — passed')
  ) as q(gcode, pmon, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.genset_r3688 e
    on e.organization_id = v_org_id and e.genset_code = q.gcode and e.period_month = q.pmon::date;
end;
$seed$;
