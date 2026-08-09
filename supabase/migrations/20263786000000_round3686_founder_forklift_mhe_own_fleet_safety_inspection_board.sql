-- Round 3686: Founder Forklift / MHE Own-Fleet Safety-Inspection Board
-- Own-warehouse material-handling-equipment safety — mhe_class × warehouse × inspection completion × defects × hydraulic leaks × load test × operator authorization × downtime × CAPA

-- =============================================================================
-- TABLE 1: forklift_mhe_r3686 — per-equipment monthly safety-inspection entries
-- =============================================================================
create table if not exists public.forklift_mhe_r3686 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  warehouse_name text not null,
  equipment_code text not null,
  mhe_class text not null check (mhe_class in (
    'counterbalance_forklift','reach_truck','pallet_jack','stacker','hand_trolley_powered'
  )),
  period_month date not null,
  equipment_age_years numeric(4,1),
  inspections_due int not null,
  inspections_done int not null,
  inspection_pct numeric(5,1),
  defects_found int not null,
  hydraulic_leaks int not null,
  load_test_current boolean not null,
  operators_authorized int not null,
  operators_unauthorized_use int not null,
  downtime_hours numeric(6,1),
  safety_status text not null check (safety_status in (
    'safe','minor_defects','repair_due','load_test_overdue','unsafe'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.forklift_mhe_r3686 enable row level security;

create index if not exists idx_forklift_mhe_r3686_org on public.forklift_mhe_r3686(organization_id);
create index if not exists idx_forklift_mhe_r3686_month on public.forklift_mhe_r3686(period_month);
create index if not exists idx_forklift_mhe_r3686_status on public.forklift_mhe_r3686(safety_status);

-- =============================================================================
-- TABLE 2: forklift_mhe_capa_actions_r3686 — CAPA & safety actions
-- =============================================================================
create table if not exists public.forklift_mhe_capa_actions_r3686 (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.forklift_mhe_r3686(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'hydraulic_seal_wear','worn_fork_heels','battery_maintenance_lapse','operator_misuse',
    'overdue_load_test','tyre_wear','mast_chain_stretch','pending_investigation','amc_vendor_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_hydraulic_seals','replace_forks','battery_service','retrain_operators',
    'schedule_load_test','replace_tyres','adjust_mast_chain','remove_from_service',
    'escalate_amc_vendor','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  downtime_impact_hours numeric(6,1),
  owner_name text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.forklift_mhe_capa_actions_r3686 enable row level security;

create index if not exists idx_forklift_mhe_capa_r3686_insp on public.forklift_mhe_capa_actions_r3686(inspection_id);
create index if not exists idx_forklift_mhe_capa_r3686_status on public.forklift_mhe_capa_actions_r3686(capa_status);

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

  -- 16 equipment-month inspection rows
  insert into public.forklift_mhe_r3686 (
    organization_id, warehouse_name, equipment_code, mhe_class, period_month,
    equipment_age_years, inspections_due, inspections_done, inspection_pct,
    defects_found, hydraulic_leaks, load_test_current, operators_authorized,
    operators_unauthorized_use, downtime_hours, safety_status, trend_dir, notes
  )
  select v_org_id, q.wh, q.ecode, q.cls, q.pmon::date,
    q.age, q.insdue, q.insdone, q.inspct,
    q.defs, q.leaks, q.ldtest, q.opsauth,
    q.opsunauth, q.dth, q.sst, q.trd, q.nt
  from (values
    ('Delhi Okhla WH','FLT-DEL-01','counterbalance_forklift','2026-07-01',
     6.5,4,4,100.0,0,0,true,5,0,0.0,'safe','stable','Godrej MH quarterly AMC service done — brakes, mast and hydraulics clean'),
    ('Delhi Okhla WH','RT-DEL-02','reach_truck','2026-07-01',
     3.2,4,4,100.0,2,0,true,3,0,4.5,'minor_defects','improving','Mast chain lubrication and horn defect fixed under Toyota MH AMC'),
    ('Delhi Okhla WH','PJ-DEL-03','pallet_jack','2026-07-01',
     8.0,2,1,50.0,3,1,false,6,2,12.0,'load_test_overdue','worsening','Annual load test lapsed in June; hydraulic seep at lift cylinder'),
    ('Mumbai Bhiwandi WH','FLT-BHW-11','counterbalance_forklift','2026-07-01',
     9.4,4,4,100.0,5,2,true,5,1,26.0,'repair_due','worsening','Tilt cylinder leaks; Jungheinrich AMC repair slot booked for 12 Jul'),
    ('Mumbai Bhiwandi WH','RT-BHW-12','reach_truck','2026-07-01',
     2.1,4,4,100.0,0,0,true,4,0,0.0,'safe','improving','New reach truck — pre-shift checklist adherence at 100 percent'),
    ('Chennai Ambattur WH','FLT-CHN-21','counterbalance_forklift','2026-07-01',
     7.3,4,4,100.0,1,0,true,6,0,1.5,'safe','stable','Minor seat-belt latch defect fixed same day; Godrej MH AMC current'),
    ('Delhi Okhla WH','STK-DEL-04','stacker','2026-06-01',
     4.8,4,3,75.0,1,0,true,4,0,2.0,'minor_defects','stable','Worn fork heel pads noted — replacement parts ordered from Maini'),
    ('Mumbai Bhiwandi WH','HT-BHW-13','hand_trolley_powered','2026-06-01',
     5.6,2,2,100.0,1,0,true,8,3,3.5,'minor_defects','stable','Unauthorized use by contract loaders — badge interlock retrofit planned'),
    ('Mumbai Bhiwandi WH','FLT-BHW-14','counterbalance_forklift','2026-06-01',
     11.2,4,2,50.0,7,3,false,5,2,48.0,'unsafe','worsening','Parked out of service — brake fade plus three hydraulic leaks; load test overdue'),
    ('Chennai Ambattur WH','STK-CHN-22','stacker','2026-06-01',
     1.4,4,4,100.0,0,0,true,3,0,0.0,'safe','improving','New Jungheinrich stacker — zero defects since commissioning'),
    ('Chennai Ambattur WH','PJ-CHN-23','pallet_jack','2026-06-01',
     6.9,2,2,100.0,2,1,true,7,1,6.0,'repair_due','stable','Load-wheel tyre flat spots and slow lift; repair due this month'),
    ('Delhi Okhla WH','FLT-DEL-05','counterbalance_forklift','2026-05-01',
     10.1,4,3,75.0,3,0,true,5,1,8.0,'repair_due','improving','Battery watering lapsed — Exide service visit and charger audit done'),
    ('Mumbai Bhiwandi WH','PJ-BHW-15','pallet_jack','2026-05-01',
     7.7,2,2,100.0,1,0,true,6,0,1.0,'minor_defects','stable','Handle return spring weak — replaced during monthly inspection'),
    ('Mumbai Bhiwandi WH','STK-BHW-16','stacker','2026-05-01',
     3.9,4,4,100.0,0,0,true,4,0,0.0,'safe','stable','All checks clean; operator refresher completed for evening shift'),
    ('Chennai Ambattur WH','HT-CHN-24','hand_trolley_powered','2026-05-01',
     2.8,2,2,100.0,0,0,true,9,0,0.0,'safe','stable','Powered trolley fleet clean; charging bay ventilation verified'),
    ('Chennai Ambattur WH','RT-CHN-25','reach_truck','2026-05-01',
     5.5,4,4,100.0,2,0,true,3,0,5.0,'minor_defects','improving','Mast chain stretch at limit — adjusted under Toyota MH AMC')
  ) as q(wh, ecode, cls, pmon, age, insdue, insdone, inspct, defs, leaks, ldtest, opsauth, opsunauth, dth, sst, trd, nt);

  -- CAPA seed — attach to specific inspections via equipment_code
  insert into public.forklift_mhe_capa_actions_r3686 (
    inspection_id, root_cause, corrective_action, capa_status,
    downtime_impact_hours, owner_name, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.dih, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PJ-DEL-03','overdue_load_test','schedule_load_test','in_progress',12.0,'Rakesh Sharma — WH Manager Delhi','2026-07-15',null,'Load test slot booked with Godrej MH service for 11 Jul'),
    ('FLT-BHW-11','hydraulic_seal_wear','replace_hydraulic_seals','open',26.0,'Imran Shaikh — Maintenance Lead Bhiwandi','2026-07-20',null,'Seal kit ordered from Jungheinrich; truck restricted to light duty'),
    ('FLT-BHW-14','hydraulic_seal_wear','remove_from_service','escalated',48.0,'Imran Shaikh — Maintenance Lead Bhiwandi','2026-07-10',null,'Escalated to AMC vendor — quote awaited for full hydraulic overhaul'),
    ('STK-DEL-04','worn_fork_heels','replace_forks','verification_pending',2.0,'Rakesh Sharma — WH Manager Delhi','2026-07-08',null,'New forks fitted; load-test verification pending'),
    ('HT-BHW-13','operator_misuse','retrain_operators','closed',3.5,'Priya Nair — EHS Officer','2026-06-25','2026-06-20','Toolbox talk done; three loaders retrained and badge list updated'),
    ('PJ-CHN-23','tyre_wear','replace_tyres','overdue',6.0,'S Murugan — Stores Supervisor Chennai','2026-06-30',null,'Load-wheel tyres past target replacement date — vendor delay'),
    ('RT-CHN-25','mast_chain_stretch','adjust_mast_chain','closed',5.0,'S Murugan — Stores Supervisor Chennai','2026-05-28','2026-05-26','Chain tension adjusted and re-measured within tolerance'),
    ('FLT-DEL-05','battery_maintenance_lapse','battery_service','in_progress',8.0,'Rakesh Sharma — WH Manager Delhi','2026-07-18',null,'Exide AMC battery service scheduled; watering log made daily')
  ) as q(ecode, rc, ca, cst, dih, own, tcd, acd, nt)
  join public.forklift_mhe_r3686 e
    on e.organization_id = v_org_id and e.equipment_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Safety status distribution
create or replace function public.founder_r3686_safety_status_rollup()
returns table(safety_status text, mhe_units bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.forklift_mhe_r3686)
  select l.safety_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.forklift_mhe_r3686 l
  group by l.safety_status
  order by count(*) desc;
end;
$$;

-- 2) Warehouse safety scorecard
create or replace function public.founder_r3686_warehouse_scorecard()
returns table(
  warehouse_name text,
  mhe_units bigint,
  safe_units bigint,
  minor_defect_units bigint,
  repair_due_units bigint,
  load_test_overdue_units bigint,
  unsafe_units bigint,
  total_defects bigint,
  unauthorized_use_events bigint,
  avg_inspection_pct numeric,
  safe_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warehouse_name,
    count(*)::bigint,
    count(*) filter (where l.safety_status = 'safe')::bigint,
    count(*) filter (where l.safety_status = 'minor_defects')::bigint,
    count(*) filter (where l.safety_status = 'repair_due')::bigint,
    count(*) filter (where l.safety_status = 'load_test_overdue')::bigint,
    count(*) filter (where l.safety_status = 'unsafe')::bigint,
    coalesce(sum(l.defects_found),0)::bigint,
    coalesce(sum(l.operators_unauthorized_use),0)::bigint,
    round(avg(l.inspection_pct), 1),
    round(100.0 * count(*) filter (where l.safety_status = 'safe')::numeric / nullif(count(*),0), 1)
  from public.forklift_mhe_r3686 l
  group by l.warehouse_name
  order by count(*) desc;
end;
$$;

-- 3) MHE class × safety status matrix
create or replace function public.founder_r3686_class_status_matrix()
returns table(mhe_class text, safety_status text, mhe_units bigint, avg_age_years numeric, defects bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.mhe_class, l.safety_status, count(*)::bigint,
    round(avg(l.equipment_age_years), 1),
    coalesce(sum(l.defects_found),0)::bigint
  from public.forklift_mhe_r3686 l
  group by l.mhe_class, l.safety_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly inspection trend
create or replace function public.founder_r3686_monthly_inspection_trend()
returns table(
  period_month date,
  mhe_units bigint,
  inspections_due bigint,
  inspections_done bigint,
  avg_inspection_pct numeric,
  defects_found bigint,
  downtime_hours numeric
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
    coalesce(sum(l.inspections_due),0)::bigint,
    coalesce(sum(l.inspections_done),0)::bigint,
    round(avg(l.inspection_pct), 1),
    coalesce(sum(l.defects_found),0)::bigint,
    coalesce(sum(l.downtime_hours),0)::numeric
  from public.forklift_mhe_r3686 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3686_capa_status_board()
returns table(capa_status text, findings bigint, avg_downtime_impact_hours numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.downtime_impact_hours)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.forklift_mhe_capa_actions_r3686 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3686_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_downtime_impact_hours numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.forklift_mhe_capa_actions_r3686)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.downtime_impact_hours),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.forklift_mhe_capa_actions_r3686 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Defect & downtime digest by MHE class
create or replace function public.founder_r3686_defect_digest()
returns table(
  mhe_class text,
  mhe_units bigint,
  total_defects bigint,
  hydraulic_leaks bigint,
  downtime_hours numeric,
  unauthorized_use_events bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.mhe_class,
    count(*)::bigint,
    coalesce(sum(l.defects_found),0)::bigint,
    coalesce(sum(l.hydraulic_leaks),0)::bigint,
    coalesce(sum(l.downtime_hours),0)::numeric,
    coalesce(sum(l.operators_unauthorized_use),0)::bigint
  from public.forklift_mhe_r3686 l
  group by l.mhe_class
  order by coalesce(sum(l.defects_found),0) desc;
end;
$$;

-- 8) High-risk equipment queue
create or replace function public.founder_r3686_high_risk_queue()
returns table(
  warehouse_name text,
  equipment_code text,
  mhe_class text,
  period_month date,
  safety_status text,
  defects_found int,
  hydraulic_leaks int,
  load_test_current boolean,
  downtime_hours numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warehouse_name, l.equipment_code, l.mhe_class, l.period_month,
    l.safety_status, l.defects_found, l.hydraulic_leaks, l.load_test_current,
    l.downtime_hours, l.notes
  from public.forklift_mhe_r3686 l
  where l.safety_status in ('unsafe','load_test_overdue','repair_due')
     or l.load_test_current = false
     or l.hydraulic_leaks > 0
     or l.operators_unauthorized_use > 0
  order by l.period_month desc, l.warehouse_name;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3686_safety_status_rollup() from public, anon;
revoke all on function public.founder_r3686_warehouse_scorecard() from public, anon;
revoke all on function public.founder_r3686_class_status_matrix() from public, anon;
revoke all on function public.founder_r3686_monthly_inspection_trend() from public, anon;
revoke all on function public.founder_r3686_capa_status_board() from public, anon;
revoke all on function public.founder_r3686_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3686_defect_digest() from public, anon;
revoke all on function public.founder_r3686_high_risk_queue() from public, anon;

grant execute on function public.founder_r3686_safety_status_rollup() to authenticated;
grant execute on function public.founder_r3686_warehouse_scorecard() to authenticated;
grant execute on function public.founder_r3686_class_status_matrix() to authenticated;
grant execute on function public.founder_r3686_monthly_inspection_trend() to authenticated;
grant execute on function public.founder_r3686_capa_status_board() to authenticated;
grant execute on function public.founder_r3686_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3686_defect_digest() to authenticated;
grant execute on function public.founder_r3686_high_risk_queue() to authenticated;
