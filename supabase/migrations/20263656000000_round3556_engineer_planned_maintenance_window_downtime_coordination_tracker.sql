-- Round 3556: Engineer Planned-Maintenance-Window / Downtime-Coordination Tracker
-- Planned maintenance-window / downtime coordination with hospital — window type × approval
-- × clinical impact × planned vs actual duration × overrun × downtime agreement × CAPA closure

-- =============================================================================
-- TABLE 1: maintenance_window_r3556 — per-work-order planned maintenance windows
-- =============================================================================
create table if not exists public.maintenance_window_r3556 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  work_order text not null,
  window_type text not null check (window_type in (
    'scheduled_pm','upgrade','repair','calibration','statutory','installation'
  )),
  planned_start date not null,
  planned_duration_hrs numeric(6,2),
  actual_duration_hrs numeric(6,2),
  overrun_hrs numeric(6,2),
  approval_status text not null check (approval_status in (
    'requested','approved','rescheduled','rejected','completed'
  )),
  clinical_impact text not null check (clinical_impact in (
    'none','low','moderate','high','service_suspended'
  )),
  downtime_agreed boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.maintenance_window_r3556 enable row level security;

create index if not exists idx_maintenance_window_r3556_org on public.maintenance_window_r3556(organization_id);
create index if not exists idx_maintenance_window_r3556_start on public.maintenance_window_r3556(planned_start);
create index if not exists idx_maintenance_window_r3556_approval on public.maintenance_window_r3556(approval_status);

-- =============================================================================
-- TABLE 2: maintenance_window_capa_actions_r3556 — CAPA & coordination actions
-- =============================================================================
create table if not exists public.maintenance_window_capa_actions_r3556 (
  id uuid primary key default gen_random_uuid(),
  window_log_id uuid not null references public.maintenance_window_r3556(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'schedule_overrun','approval_delay','window_rescheduled','window_rejected',
    'downtime_not_agreed','clinical_impact_high','service_suspended',
    'work_order_incomplete','calibration_slip','preventive_maintenance_backlog'
  )),
  root_cause text not null check (root_cause in (
    'parts_unavailable','staff_unavailable','clinical_load_conflict','oem_engineer_delay',
    'infrastructure_not_ready','poor_planning','patient_safety_hold','pending_investigation',
    'software_upgrade_failure','access_permission_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'reschedule_window','add_engineer_resource','expedite_spare_parts','coordinate_clinical_slot',
    'escalate_to_oem','improve_planning_process','split_into_phases','obtain_downtime_signoff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  coordination_impact text not null check (coordination_impact in (
    'none','internal_only','sla_breach','patient_care_disruption','nabh_finding','contract_penalty'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.maintenance_window_capa_actions_r3556 enable row level security;

create index if not exists idx_maintenance_window_capa_r3556_log on public.maintenance_window_capa_actions_r3556(window_log_id);
create index if not exists idx_maintenance_window_capa_r3556_status on public.maintenance_window_capa_actions_r3556(capa_status);

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

  -- 16 planned maintenance-window rows
  insert into public.maintenance_window_r3556 (
    organization_id, engineer_name, hospital_name, device_model, work_order, window_type,
    planned_start, planned_duration_hrs, actual_duration_hrs, overrun_hrs,
    approval_status, clinical_impact, downtime_agreed, notes
  )
  select v_org_id, q.eng, q.hosp, q.dev, q.wo, q.wtype,
    q.pstart::date, q.pdur, q.adur, q.ovr,
    q.appr, q.cimp, q.dta, q.nt
  from (values
    ('Ramesh Iyer','Apollo Chennai','GE Vivid E95 Ultrasound','WO-CHN-3556-01','scheduled_pm',
     '2026-07-05',4,4.5,0.5,'completed','low',true,'Quarterly PM completed with minor overrun'),
    ('Ramesh Iyer','Apollo Chennai','Philips MX550 Monitor','WO-CHN-3556-02','calibration',
     '2026-07-06',2,2,0,'completed','none',true,'NIBP module calibration, no downtime impact'),
    ('Suresh Nair','Fortis Gurgaon','Siemens Somatom CT','WO-GGN-3556-11','upgrade',
     '2026-07-08',6,9.5,3.5,'completed','high',true,'CT software upgrade overran 3.5 hrs, scanner suspended'),
    ('Suresh Nair','Fortis Gurgaon','Drager Fabius GS Anesthesia','WO-GGN-3556-12','repair',
     '2026-07-09',3,null,null,'rescheduled','moderate',false,'OT slot conflict — rescheduled to next week'),
    ('Anita Desai','Manipal Bengaluru','Mindray SV300 Ventilator','WO-BLR-3556-21','statutory',
     '2026-07-10',5,5,0,'approved','moderate',true,'Statutory electrical safety inspection scheduled'),
    ('Anita Desai','Manipal Bengaluru','GE Revolution CT','WO-BLR-3556-22','installation',
     '2026-07-11',8,12,4,'completed','service_suspended',true,'New CT install; suite down full day, large overrun'),
    ('Vikram Rao','AIIMS Delhi','Philips Azurion Cathlab','WO-DEL-3556-31','scheduled_pm',
     '2026-07-12',4,4,0,'requested','high',false,'Cathlab PM requested, downtime signoff pending'),
    ('Vikram Rao','AIIMS Delhi','Nihon Kohden EEG','WO-DEL-3556-32','repair',
     '2026-07-13',2,3,1,'completed','low',true,'EEG amplifier repair, minor overrun'),
    ('Deepa Menon','CMC Vellore','Maquet Servo-i Ventilator','WO-VEL-3556-41','calibration',
     '2026-07-14',2,2,0,'completed','none',true,'Ventilator flow-sensor calibration done'),
    ('Deepa Menon','CMC Vellore','Siemens Artis Zee Cathlab','WO-VEL-3556-42','upgrade',
     '2026-07-15',6,6,0,'rejected','high',false,'Upgrade rejected — clinical load too high this quarter'),
    ('Karthik Reddy','KIMS Hyderabad','GE Carescape B650 Monitor','WO-HYD-3556-51','scheduled_pm',
     '2026-07-16',3,3.5,0.5,'completed','low',true,'Central monitoring PM completed'),
    ('Karthik Reddy','KIMS Hyderabad','Stryker Neptune Suction','WO-HYD-3556-52','repair',
     '2026-07-17',2,null,null,'rescheduled','low',false,'Spare part awaited — rescheduled'),
    ('Meera Joshi','Yashoda Hyderabad','Hologic Selenia Mammography','WO-HYD-3556-61','statutory',
     '2026-07-18',4,7,3,'completed','moderate',true,'AERB radiation survey; overran 3 hrs'),
    ('Meera Joshi','Yashoda Hyderabad','Datex Ohmeda Anesthesia','WO-HYD-3556-62','installation',
     '2026-07-19',6,6.5,0.5,'approved','moderate',true,'New anesthesia workstation install approved'),
    ('Arjun Pillai','Kokilaben Mumbai','Varian TrueBeam Linac','WO-MUM-3556-71','upgrade',
     '2026-07-20',10,16,6,'completed','service_suspended',true,'Linac software upgrade; bunker down 2 days, large overrun'),
    ('Arjun Pillai','Kokilaben Mumbai','Boston Scientific EP System','WO-MUM-3556-72','scheduled_pm',
     '2026-07-21',3,3,0,'requested','high',false,'EP lab PM requested, awaiting downtime agreement')
  ) as q(eng, hosp, dev, wo, wtype, pstart, pdur, adur, ovr, appr, cimp, dta, nt);

  -- CAPA seed — attach to specific windows via work_order
  insert into public.maintenance_window_capa_actions_r3556 (
    window_log_id, finding_category, root_cause, corrective_action,
    capa_status, coordination_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WO-GGN-3556-11','schedule_overrun','software_upgrade_failure','split_into_phases','in_progress','sla_breach','Suresh Nair','2026-07-15',null,45000.00,'CT upgrade to be phased across two windows to cap downtime'),
    ('WO-GGN-3556-12','window_rescheduled','clinical_load_conflict','coordinate_clinical_slot','open','patient_care_disruption','Suresh Nair','2026-07-16',null,12000.00,'Coordinate with OT scheduling for a low-load slot'),
    ('WO-BLR-3556-22','schedule_overrun','poor_planning','improve_planning_process','verification_pending','internal_only','Anita Desai','2026-07-18',null,30000.00,'Install runbook underestimated commissioning time'),
    ('WO-DEL-3556-31','downtime_not_agreed','access_permission_delay','obtain_downtime_signoff','open','patient_care_disruption','Vikram Rao','2026-07-20',null,5000.00,'Cathlab HOD signoff pending before PM can proceed'),
    ('WO-VEL-3556-42','window_rejected','clinical_load_conflict','reschedule_window','escalated','contract_penalty','Deepa Menon','2026-07-22',null,60000.00,'Upgrade rejected; AMC SLA at risk, escalated to management'),
    ('WO-HYD-3556-52','window_rescheduled','parts_unavailable','expedite_spare_parts','in_progress','sla_breach','Karthik Reddy','2026-07-24',null,18000.00,'Suction pump seal on order — expedite from OEM'),
    ('WO-HYD-3556-61','schedule_overrun','staff_unavailable','add_engineer_resource','closed','nabh_finding','Meera Joshi','2026-07-20','2026-07-19',8000.00,'Second engineer added; survey completed and signed off'),
    ('WO-MUM-3556-71','schedule_overrun','software_upgrade_failure','escalate_to_oem','overdue','contract_penalty','Arjun Pillai','2026-07-25',null,120000.00,'Linac upgrade rollback needed; OEM escalation, penalty exposure')
  ) as q(wo, fc, rc, ca, cst, ci, ownr, tcd, acd, cost, nt)
  join public.maintenance_window_r3556 e
    on e.organization_id = v_org_id and e.work_order = q.wo;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Approval-status distribution
create or replace function public.founder_r3556_approval_status_rollup()
returns table(approval_status text, windows bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.maintenance_window_r3556)
  select l.approval_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.maintenance_window_r3556 l
  group by l.approval_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3556_approval_status_rollup() from public, anon;
grant execute on function public.founder_r3556_approval_status_rollup() to authenticated;

-- 2) Window-type scorecard
create or replace function public.founder_r3556_window_type_scorecard()
returns table(
  window_type text,
  total_windows bigint,
  completed bigint,
  rescheduled bigint,
  rejected bigint,
  overrun_windows bigint,
  downtime_not_agreed bigint,
  avg_overrun_hrs numeric,
  completed_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.window_type,
    count(*)::bigint,
    count(*) filter (where l.approval_status = 'completed')::bigint,
    count(*) filter (where l.approval_status = 'rescheduled')::bigint,
    count(*) filter (where l.approval_status = 'rejected')::bigint,
    count(*) filter (where l.overrun_hrs > 0)::bigint,
    count(*) filter (where l.downtime_agreed = false)::bigint,
    round(avg(l.overrun_hrs), 2),
    round(100.0 * count(*) filter (where l.approval_status = 'completed')::numeric / nullif(count(*),0), 1)
  from public.maintenance_window_r3556 l
  group by l.window_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3556_window_type_scorecard() from public, anon;
grant execute on function public.founder_r3556_window_type_scorecard() to authenticated;

-- 3) Window-type × clinical-impact matrix
create or replace function public.founder_r3556_window_type_impact_matrix()
returns table(window_type text, clinical_impact text, windows bigint, completed bigint, rejected bigint, avg_overrun_hrs numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.window_type, l.clinical_impact, count(*)::bigint,
    count(*) filter (where l.approval_status = 'completed')::bigint,
    count(*) filter (where l.approval_status in ('rejected','rescheduled'))::bigint,
    round(avg(l.overrun_hrs), 2)
  from public.maintenance_window_r3556 l
  group by l.window_type, l.clinical_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3556_window_type_impact_matrix() from public, anon;
grant execute on function public.founder_r3556_window_type_impact_matrix() to authenticated;

-- 4) Monthly window trend
create or replace function public.founder_r3556_monthly_window_trend()
returns table(window_month date, windows bigint, completed bigint, rescheduled bigint, rejected bigint, overrun_windows bigint, avg_overrun_hrs numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.planned_start)::date,
    count(*)::bigint,
    count(*) filter (where l.approval_status = 'completed')::bigint,
    count(*) filter (where l.approval_status = 'rescheduled')::bigint,
    count(*) filter (where l.approval_status = 'rejected')::bigint,
    count(*) filter (where l.overrun_hrs > 0)::bigint,
    round(avg(l.overrun_hrs), 2)
  from public.maintenance_window_r3556 l
  group by date_trunc('month', l.planned_start)
  order by date_trunc('month', l.planned_start) desc;
end;
$$;

revoke execute on function public.founder_r3556_monthly_window_trend() from public, anon;
grant execute on function public.founder_r3556_monthly_window_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3556_capa_status_board()
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
  from public.maintenance_window_capa_actions_r3556 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3556_capa_status_board() from public, anon;
grant execute on function public.founder_r3556_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3556_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.maintenance_window_capa_actions_r3556)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.maintenance_window_capa_actions_r3556 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3556_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3556_root_cause_pareto() to authenticated;

-- 7) Overrun / clinical-impact digest
create or replace function public.founder_r3556_overrun_impact_digest()
returns table(
  clinical_impact text,
  windows bigint,
  overrun_windows bigint,
  total_overrun_hrs numeric,
  avg_overrun_hrs numeric,
  service_suspended bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.clinical_impact,
    count(*)::bigint,
    count(*) filter (where l.overrun_hrs > 0)::bigint,
    coalesce(sum(l.overrun_hrs),0)::numeric,
    round(avg(l.overrun_hrs), 2),
    count(*) filter (where l.clinical_impact = 'service_suspended')::bigint
  from public.maintenance_window_r3556 l
  group by l.clinical_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3556_overrun_impact_digest() from public, anon;
grant execute on function public.founder_r3556_overrun_impact_digest() to authenticated;

-- 8) High-risk window queue (service-suspended / rejected / large-overrun / no-downtime-agreement)
create or replace function public.founder_r3556_high_risk_queue()
returns table(
  hospital_name text,
  work_order text,
  device_model text,
  window_type text,
  planned_start date,
  approval_status text,
  clinical_impact text,
  overrun_hrs numeric,
  downtime_agreed boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.work_order, l.device_model, l.window_type, l.planned_start,
    l.approval_status, l.clinical_impact, l.overrun_hrs, l.downtime_agreed, l.notes
  from public.maintenance_window_r3556 l
  where l.clinical_impact in ('high','service_suspended')
     or l.approval_status in ('rejected','rescheduled')
     or coalesce(l.overrun_hrs, 0) >= 3
     or l.downtime_agreed = false
  order by l.planned_start desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3556_high_risk_queue() from public, anon;
grant execute on function public.founder_r3556_high_risk_queue() to authenticated;
