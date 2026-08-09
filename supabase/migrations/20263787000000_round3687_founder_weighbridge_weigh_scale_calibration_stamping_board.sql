-- Round 3687: Founder Weighbridge / Weigh-Scale Calibration & Stamping Board
-- Own-warehouse weigh-scale QA — scale class × warehouse × calibration validity × legal stamping × accuracy vs tolerance × usage load × CAPA

-- =============================================================================
-- TABLE 1: weighscale_r3687 — per-scale calibration & stamping compliance rows
-- =============================================================================
create table if not exists public.weighscale_r3687 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  scale_code text not null,
  warehouse_name text not null,
  period_month date not null,
  scale_class text not null check (scale_class in (
    'platform_scale','bench_scale','crane_scale','pallet_beam','counting_scale'
  )),
  capacity_kg numeric(10,2),
  last_calibration date,
  calibration_due date,
  days_to_due int,
  stamping_valid boolean not null,
  accuracy_error_pct numeric(6,3),
  tolerance_pct numeric(6,3),
  within_tolerance boolean not null,
  usage_transactions int,
  repairs int,
  calibration_status text not null check (calibration_status in (
    'current','due_soon','overdue','out_of_tolerance','decommission_due'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.weighscale_r3687 enable row level security;

create index if not exists idx_weighscale_r3687_org on public.weighscale_r3687(organization_id);
create index if not exists idx_weighscale_r3687_month on public.weighscale_r3687(period_month);
create index if not exists idx_weighscale_r3687_status on public.weighscale_r3687(calibration_status);

-- =============================================================================
-- TABLE 2: weighscale_capa_actions_r3687 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.weighscale_capa_actions_r3687 (
  id uuid primary key default gen_random_uuid(),
  scale_log_id uuid not null references public.weighscale_r3687(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'load_cell_drift','junction_box_moisture','foundation_settlement','indicator_fault',
    'overloading_abuse','stamping_lapse_admin','vendor_service_backlog',
    'corner_load_imbalance','cable_rodent_damage','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_and_stamp','replace_load_cell','seal_junction_box','repair_foundation',
    'replace_indicator','operator_retraining','schedule_legal_stamping',
    'decommission_scale','vendor_amc_escalation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.weighscale_capa_actions_r3687 enable row level security;

create index if not exists idx_weighscale_capa_r3687_log on public.weighscale_capa_actions_r3687(scale_log_id);
create index if not exists idx_weighscale_capa_r3687_status on public.weighscale_capa_actions_r3687(capa_status);

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

  -- 16 weigh-scale compliance rows
  insert into public.weighscale_r3687 (
    organization_id, scale_code, warehouse_name, period_month, scale_class,
    capacity_kg, last_calibration, calibration_due, days_to_due, stamping_valid,
    accuracy_error_pct, tolerance_pct, within_tolerance, usage_transactions, repairs,
    calibration_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.wh, q.pm::date, q.cls,
    q.cap, q.lastcal::date, q.caldue::date, q.dtd, q.stamp,
    q.aerr, q.tol, q.wtol, q.txns, q.reps,
    q.cstat, q.trend, q.nt
  from (values
    ('WB-DEL-01','Delhi NCR Warehouse','2026-07-01','platform_scale',
     5000.00,'2026-06-20','2026-12-20',165,true,0.05,0.10,true,1240,0,
     'current','stable','Half-yearly calibration by Essae-Teraoka AMC — stamping valid till Dec'),
    ('WB-DEL-02','Delhi NCR Warehouse','2026-07-01','pallet_beam',
     3000.00,'2026-02-10','2026-08-10',2,true,0.09,0.10,true,860,1,
     'due_soon','worsening','Calibration due within days — Avery India AMC visit booked'),
    ('WB-DEL-03','Delhi NCR Warehouse','2026-07-01','bench_scale',
     300.00,'2025-12-05','2026-06-05',-64,false,0.22,0.15,false,410,2,
     'out_of_tolerance','worsening','Legal metrology stamping lapsed; error 0.22% beyond 0.15% tolerance'),
    ('WB-DEL-04','Delhi NCR Warehouse','2026-07-01','counting_scale',
     60.00,'2026-05-15','2026-11-15',130,true,0.07,0.10,true,980,0,
     'current','improving','Counting scale for spare-part kitting — within tolerance'),
    ('WB-DEL-05','Delhi NCR Warehouse','2026-07-01','crane_scale',
     10000.00,'2026-01-18','2026-07-18',-21,false,0.12,0.10,false,150,1,
     'overdue','worsening','Crane scale overdue and stamping lapsed — flagged to warehouse admin'),
    ('WB-BHW-01','Mumbai Bhiwandi Warehouse','2026-07-01','platform_scale',
     10000.00,'2026-07-02','2027-01-02',178,true,0.04,0.10,true,2100,0,
     'current','stable','Primary inbound platform scale — Sartorius AMC calibration clean'),
    ('WB-BHW-02','Mumbai Bhiwandi Warehouse','2026-06-01','pallet_beam',
     2000.00,'2026-06-25','2026-12-25',170,true,0.06,0.10,true,1340,0,
     'current','stable','Pallet beam scale for outbound dispatch — nominal'),
    ('WB-BHW-03','Mumbai Bhiwandi Warehouse','2026-06-01','bench_scale',
     150.00,'2026-03-01','2026-09-01',24,true,0.09,0.15,true,720,1,
     'due_soon','stable','Bench scale nearing due date — recalibration slot requested'),
    ('WB-BHW-04','Mumbai Bhiwandi Warehouse','2026-06-01','crane_scale',
     5000.00,'2025-11-20','2026-05-20',-80,false,0.31,0.10,false,90,3,
     'decommission_due','worsening','Repeated load-cell failures after overloads — decommission recommended'),
    ('WB-BHW-05','Mumbai Bhiwandi Warehouse','2026-06-01','counting_scale',
     30.00,'2026-06-10','2026-12-10',155,true,0.05,0.10,true,1150,0,
     'current','improving','Counting scale post-service accuracy improved to 0.05%'),
    ('WB-CHE-01','Chennai Warehouse','2026-06-01','platform_scale',
     5000.00,'2026-04-12','2026-10-12',120,true,0.06,0.10,true,1650,0,
     'current','stable','Platform scale QC clean under Avery India AMC'),
    ('WB-CHE-02','Chennai Warehouse','2026-05-01','bench_scale',
     300.00,'2026-01-08','2026-07-08',-30,false,0.18,0.15,false,540,2,
     'overdue','worsening','Overdue and drifting — junction box moisture suspected post-monsoon'),
    ('WB-CHE-03','Chennai Warehouse','2026-05-01','pallet_beam',
     3000.00,'2026-05-30','2026-11-30',148,true,0.08,0.10,true,880,0,
     'current','stable','Pallet beam scale within tolerance — no repairs this quarter'),
    ('WB-CHE-04','Chennai Warehouse','2026-05-01','counting_scale',
     60.00,'2026-03-22','2026-09-22',45,true,0.11,0.15,true,690,1,
     'due_soon','stable','Indicator flicker under load noted — replacement quoted'),
    ('WB-CHE-05','Chennai Warehouse','2026-05-01','crane_scale',
     10000.00,'2026-04-05','2026-10-05',110,true,0.09,0.10,true,210,0,
     'current','improving','Crane scale accuracy improved after shackle replacement'),
    ('WB-BHW-06','Mumbai Bhiwandi Warehouse','2026-05-01','platform_scale',
     20000.00,'2025-10-15','2026-04-15',-110,false,0.14,0.10,false,1980,2,
     'out_of_tolerance','worsening','20T inbound weighbridge out of tolerance — corner load imbalance found')
  ) as q(scode, wh, pm, cls, cap, lastcal, caldue, dtd, stamp, aerr, tol, wtol, txns, reps, cstat, trend, nt);

  -- CAPA seed — attach to specific scales via scale_code
  insert into public.weighscale_capa_actions_r3687 (
    scale_log_id, root_cause, corrective_action, capa_status,
    cost_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('WB-DEL-03','load_cell_drift','replace_load_cell','in_progress',28000.00,'Ravi Menon','2026-08-20',null,'Load cell ordered from Essae — recalibration after fitment'),
    ('WB-DEL-05','stamping_lapse_admin','schedule_legal_stamping','open',6500.00,'Priya Nair','2026-08-25',null,'Legal metrology stamping appointment requested for crane scale'),
    ('WB-BHW-04','overloading_abuse','decommission_scale','escalated',145000.00,'Amit Shah','2026-08-15',null,'Repeated overloads cracked load cells — replacement crane scale in PO'),
    ('WB-CHE-02','junction_box_moisture','seal_junction_box','verification_pending',4200.00,'S Karthik','2026-08-10',null,'Junction box resealed post-monsoon — verification weigh test pending'),
    ('WB-BHW-06','corner_load_imbalance','repair_foundation','in_progress',88000.00,'Amit Shah','2026-09-05',null,'Foundation grouting for 20T weighbridge under AMC vendor supervision'),
    ('WB-DEL-02','vendor_service_backlog','vendor_amc_escalation','closed',0.00,'Priya Nair','2026-08-05','2026-08-04','Avery India visit rescheduled and completed — calibration booked'),
    ('WB-CHE-04','indicator_fault','replace_indicator','open',12500.00,'S Karthik','2026-08-30',null,'Counting scale indicator flickers under load — replacement quoted'),
    ('WB-BHW-03','pending_investigation','recalibrate_and_stamp','overdue',3800.00,'Amit Shah','2026-08-01',null,'Bench scale recalibration slipped past target — vendor slot awaited')
  ) as q(scode, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.weighscale_r3687 e
    on e.organization_id = v_org_id and e.scale_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Calibration status distribution
create or replace function public.founder_r3687_calibration_status_rollup()
returns table(calibration_status text, scales bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.weighscale_r3687)
  select l.calibration_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.weighscale_r3687 l
  group by l.calibration_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3687_calibration_status_rollup() from public, anon;
grant execute on function public.founder_r3687_calibration_status_rollup() to authenticated;

-- 2) Warehouse compliance scorecard
create or replace function public.founder_r3687_warehouse_scorecard()
returns table(
  warehouse_name text,
  total_scales bigint,
  current_ok bigint,
  due_soon bigint,
  overdue bigint,
  out_of_tolerance bigint,
  stamping_lapsed bigint,
  avg_accuracy_error_pct numeric,
  current_pct numeric
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
    count(*) filter (where l.calibration_status = 'current')::bigint,
    count(*) filter (where l.calibration_status = 'due_soon')::bigint,
    count(*) filter (where l.calibration_status = 'overdue')::bigint,
    count(*) filter (where l.calibration_status in ('out_of_tolerance','decommission_due'))::bigint,
    count(*) filter (where l.stamping_valid = false)::bigint,
    round(avg(l.accuracy_error_pct), 3),
    round(100.0 * count(*) filter (where l.calibration_status = 'current')::numeric / nullif(count(*),0), 1)
  from public.weighscale_r3687 l
  group by l.warehouse_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3687_warehouse_scorecard() from public, anon;
grant execute on function public.founder_r3687_warehouse_scorecard() to authenticated;

-- 3) Scale class × calibration status matrix
create or replace function public.founder_r3687_class_status_matrix()
returns table(scale_class text, calibration_status text, scales bigint, stamping_lapsed bigint, avg_accuracy_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scale_class, l.calibration_status, count(*)::bigint,
    count(*) filter (where l.stamping_valid = false)::bigint,
    round(avg(l.accuracy_error_pct), 3)
  from public.weighscale_r3687 l
  group by l.scale_class, l.calibration_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3687_class_status_matrix() from public, anon;
grant execute on function public.founder_r3687_class_status_matrix() to authenticated;

-- 4) Monthly calibration trend
create or replace function public.founder_r3687_monthly_calibration_trend()
returns table(period_month date, scales bigint, current_ok bigint, overdue bigint, out_of_tolerance bigint, stamping_lapsed bigint, avg_accuracy_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.calibration_status = 'current')::bigint,
    count(*) filter (where l.calibration_status = 'overdue')::bigint,
    count(*) filter (where l.calibration_status in ('out_of_tolerance','decommission_due'))::bigint,
    count(*) filter (where l.stamping_valid = false)::bigint,
    round(avg(l.accuracy_error_pct), 3)
  from public.weighscale_r3687 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3687_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3687_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3687_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cost_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.weighscale_capa_actions_r3687 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3687_capa_status_board() from public, anon;
grant execute on function public.founder_r3687_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3687_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.weighscale_capa_actions_r3687)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.weighscale_capa_actions_r3687 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3687_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3687_root_cause_pareto() to authenticated;

-- 7) Accuracy digest by scale class
create or replace function public.founder_r3687_accuracy_digest()
returns table(
  scale_class text,
  scales bigint,
  avg_accuracy_error_pct numeric,
  max_accuracy_error_pct numeric,
  avg_tolerance_pct numeric,
  out_of_tolerance bigint,
  stamping_lapsed bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scale_class,
    count(*)::bigint,
    round(avg(l.accuracy_error_pct), 3),
    max(l.accuracy_error_pct)::numeric,
    round(avg(l.tolerance_pct), 3),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.stamping_valid = false)::bigint
  from public.weighscale_r3687 l
  group by l.scale_class
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3687_accuracy_digest() from public, anon;
grant execute on function public.founder_r3687_accuracy_digest() to authenticated;

-- 8) High-risk scale queue
create or replace function public.founder_r3687_high_risk_queue()
returns table(
  warehouse_name text,
  scale_code text,
  scale_class text,
  period_month date,
  calibration_status text,
  days_to_due int,
  stamping_valid boolean,
  accuracy_error_pct numeric,
  tolerance_pct numeric,
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
  select l.warehouse_name, l.scale_code, l.scale_class, l.period_month,
    l.calibration_status, l.days_to_due, l.stamping_valid,
    l.accuracy_error_pct, l.tolerance_pct, l.trend_dir, l.notes
  from public.weighscale_r3687 l
  where l.calibration_status in ('overdue','out_of_tolerance','decommission_due')
     or l.stamping_valid = false
     or l.within_tolerance = false
     or l.days_to_due < 15
     or l.trend_dir = 'worsening'
  order by l.days_to_due asc, l.warehouse_name;
end;
$$;

revoke all on function public.founder_r3687_high_risk_queue() from public, anon;
grant execute on function public.founder_r3687_high_risk_queue() to authenticated;
