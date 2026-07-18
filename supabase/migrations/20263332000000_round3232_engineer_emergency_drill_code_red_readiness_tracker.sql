-- Round 3232: Engineer Emergency-Response Drill Participation & Code-Red Readiness Tracker
-- Drill log — drill type × participation × response-time × checklist score × weak step × retrain due × readiness verdict × CAPA

-- =============================================================================
-- TABLE 1: emergency_drill_r3232 — individual engineer drill participation records
-- =============================================================================
create table if not exists public.emergency_drill_r3232 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  drill_ref text not null,
  drill_date date not null,
  drill_type text not null check (drill_type in (
    'code_red_simulation','fire_response','electrical_shutdown',
    'evacuation_drill','oxygen_line_failure','generator_switchover'
  )),
  participated boolean not null default true,
  response_time_minutes numeric(5,2),
  checklist_score_pct numeric(5,2),
  weak_step_identified text not null check (weak_step_identified in (
    'none','alarm_escalation','equipment_isolation','fire_extinguisher_use',
    'patient_evacuation_route','communication_protocol','ppe_donning',
    'power_restoration_sequence','assembly_point_headcount'
  )),
  retrain_due boolean not null default false,
  retrain_due_date date,
  readiness_verdict text not null check (readiness_verdict in (
    'fully_ready','ready_with_gaps','retraining_required','not_ready','absent_unassessed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.emergency_drill_r3232 enable row level security;

create index if not exists idx_emergency_drill_r3232_org on public.emergency_drill_r3232(organization_id);
create index if not exists idx_emergency_drill_r3232_date on public.emergency_drill_r3232(drill_date);
create index if not exists idx_emergency_drill_r3232_verdict on public.emergency_drill_r3232(readiness_verdict);

-- =============================================================================
-- TABLE 2: emergency_drill_capa_actions_r3232 — CAPA & readiness actions
-- =============================================================================
create table if not exists public.emergency_drill_capa_actions_r3232 (
  id uuid primary key default gen_random_uuid(),
  drill_id uuid not null references public.emergency_drill_r3232(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'slow_response_time','checklist_step_missed','non_participation','ppe_gap',
    'communication_breakdown','equipment_access_blocked','route_obstruction','headcount_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'training_lapsed','staffing_shortage','signage_missing','equipment_mislocated',
    'protocol_outdated','new_joiner_unbriefed','alarm_system_fault','complacency','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_retraining','update_protocol_document','relocate_emergency_equipment',
    'install_signage','repeat_drill','issue_ppe_kit','fix_alarm_system','counsel_engineer','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','fire_noc_risk','none','internal_only','aerb_notifiable','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.emergency_drill_capa_actions_r3232 enable row level security;

create index if not exists idx_emergency_capa_r3232_drill on public.emergency_drill_capa_actions_r3232(drill_id);
create index if not exists idx_emergency_capa_r3232_status on public.emergency_drill_capa_actions_r3232(capa_status);

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

  -- 14 drill participation rows
  insert into public.emergency_drill_r3232 (
    organization_id, hospital_name, engineer_name, drill_ref, drill_date,
    drill_type, participated, response_time_minutes, checklist_score_pct,
    weak_step_identified, retrain_due, retrain_due_date, readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.eng, q.ref, q.dd::date,
    q.dt, q.part, q.rt, q.cs,
    q.ws, q.rtd, q.rdd::date, q.rv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ramesh Kumar','DRL-001','2026-07-02',
     'code_red_simulation',true,3.50,92.00,'none',false,null,'fully_ready','Led equipment isolation during code-red sim'),
    ('Apollo Hyderabad Jubilee Hills','Suresh Babu','DRL-002','2026-07-02',
     'code_red_simulation',true,6.20,74.00,'communication_protocol',true,'2026-07-20','ready_with_gaps','Missed handoff call to central control room'),
    ('Fortis Bannerghatta Bengaluru','Arjun Nair','DRL-003','2026-07-01',
     'fire_response',true,4.10,88.00,'fire_extinguisher_use',false,null,'fully_ready','Minor fumbling with CO2 extinguisher pin'),
    ('Fortis Bannerghatta Bengaluru','Kiran Reddy','DRL-004','2026-07-01',
     'fire_response',false,null,null,'none',true,'2026-07-15','absent_unassessed','On leave — must attend repeat drill'),
    ('Manipal Whitefield Bengaluru','Deepak Sharma','DRL-005','2026-06-30',
     'electrical_shutdown',true,8.40,61.00,'power_restoration_sequence',true,'2026-07-18','retraining_required','Restored non-critical panel before ICU feeder'),
    ('Manipal Whitefield Bengaluru','Vivek Rao','DRL-006','2026-06-30',
     'electrical_shutdown',true,5.00,83.00,'equipment_isolation',false,null,'ready_with_gaps','Ventilator changeover to UPS done correctly'),
    ('AIIMS New Delhi Ansari Nagar','Pooja Verma','DRL-007','2026-06-29',
     'evacuation_drill',true,4.80,90.00,'none',false,null,'fully_ready','Cleared ward 5 within target window'),
    ('AIIMS New Delhi Ansari Nagar','Rahul Mehta','DRL-008','2026-06-29',
     'evacuation_drill',true,9.60,55.00,'patient_evacuation_route',true,'2026-07-16','retraining_required','Took blocked corridor — route map outdated'),
    ('KIMS Secunderabad','Naveen Kumar','DRL-009','2026-06-28',
     'code_red_simulation',true,5.50,79.00,'alarm_escalation',true,'2026-07-22','ready_with_gaps','Delay raising alarm to biomedical control desk'),
    ('Care Hospitals Banjara Hills','Sandeep Joshi','DRL-010','2026-06-28',
     'oxygen_line_failure',true,7.10,68.00,'equipment_isolation',true,'2026-07-19','retraining_required','Manifold isolation valve location not known'),
    ('Yashoda Somajiguda Hyderabad','Anil Gupta','DRL-011','2026-06-27',
     'generator_switchover',true,2.90,95.00,'none',false,null,'fully_ready','DG set on load in under 3 minutes'),
    ('St John''s Bengaluru','Mohan Das','DRL-012','2026-06-27',
     'fire_response',true,12.30,42.00,'ppe_donning',true,'2026-07-14','not_ready','New joiner — no PPE kit issued, failed checklist'),
    ('Rainbow Children''s Hyderabad','Srinivas Rao','DRL-013','2026-06-26',
     'evacuation_drill',true,6.80,71.00,'assembly_point_headcount',true,'2026-07-21','ready_with_gaps','Headcount at assembly point mismatched by 2'),
    ('KIMS Secunderabad','Lakshmi Priya','DRL-014','2026-06-26',
     'generator_switchover',true,3.20,87.00,'none',false,null,'fully_ready','Clean ATS changeover, log book updated')
  ) as q(hosp, eng, ref, dd, dt, part, rt, cs, ws, rtd, rdd, rv, nt);

  -- CAPA seed — attach to specific drills
  insert into public.emergency_drill_capa_actions_r3232 (
    drill_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('DRL-004','non_participation','staffing_shortage','repeat_drill','2026-07-15',null,'open','nabh_finding',5000.00,'Repeat drill scheduled for absentees'),
    ('DRL-005','slow_response_time','training_lapsed','schedule_retraining','2026-07-18',null,'in_progress','internal_only',8000.00,'Refresher on critical-feeder restoration order booked'),
    ('DRL-008','route_obstruction','signage_missing','install_signage','2026-07-16',null,'escalated','fire_noc_risk',15000.00,'Corridor signage missing — flagged in fire NOC pre-audit'),
    ('DRL-010','equipment_access_blocked','equipment_mislocated','relocate_emergency_equipment','2026-07-19','2026-07-01','closed','patient_safety_alert',12000.00,'Manifold isolation valve relabelled and access cleared'),
    ('DRL-012','ppe_gap','new_joiner_unbriefed','issue_ppe_kit','2026-07-14',null,'overdue','nabh_finding',6500.00,'PPE kit issue pending from stores — 4 days overdue'),
    ('DRL-009','communication_breakdown','alarm_system_fault','fix_alarm_system','2026-07-22',null,'verification_pending','internal_only',22000.00,'Control-desk paging repeater replaced, retest pending')
  ) as q(ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.emergency_drill_r3232 e
    on e.organization_id = v_org_id and e.drill_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3232_readiness_verdict_rollup()
returns table(readiness_verdict text, drills bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.emergency_drill_r3232)
  select d.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.emergency_drill_r3232 d
  group by d.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3232_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3232_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3232_hospital_scorecard()
returns table(
  hospital_name text,
  total_drills bigint,
  participated bigint,
  fully_ready bigint,
  retraining_required bigint,
  not_ready bigint,
  avg_response_min numeric,
  avg_checklist_pct numeric,
  readiness_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.hospital_name,
    count(*)::bigint,
    count(*) filter (where d.participated)::bigint,
    count(*) filter (where d.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where d.readiness_verdict = 'retraining_required')::bigint,
    count(*) filter (where d.readiness_verdict = 'not_ready')::bigint,
    round(avg(d.response_time_minutes), 2),
    round(avg(d.checklist_score_pct), 1),
    round(100.0 * count(*) filter (where d.readiness_verdict = 'fully_ready')::numeric / nullif(count(*),0), 1)
  from public.emergency_drill_r3232 d
  group by d.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3232_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3232_hospital_scorecard() to authenticated;

-- 3) Drill type × weak step matrix
create or replace function public.founder_r3232_drill_weak_step_matrix()
returns table(drill_type text, weak_step_identified text, drills bigint, avg_checklist_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.drill_type, d.weak_step_identified, count(*)::bigint,
    round(avg(d.checklist_score_pct), 1)
  from public.emergency_drill_r3232 d
  group by d.drill_type, d.weak_step_identified
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3232_drill_weak_step_matrix() from public, anon;
grant execute on function public.founder_r3232_drill_weak_step_matrix() to authenticated;

-- 4) Daily drill trend
create or replace function public.founder_r3232_daily_drill_trend()
returns table(drill_date date, drills bigint, participated bigint, fully_ready bigint, retrain_flagged bigint, avg_response_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.drill_date, count(*)::bigint,
    count(*) filter (where d.participated)::bigint,
    count(*) filter (where d.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where d.retrain_due)::bigint,
    round(avg(d.response_time_minutes), 2)
  from public.emergency_drill_r3232 d
  group by d.drill_date
  order by d.drill_date desc;
end;
$$;

revoke execute on function public.founder_r3232_daily_drill_trend() from public, anon;
grant execute on function public.founder_r3232_daily_drill_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3232_capa_status_board()
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
  from public.emergency_drill_capa_actions_r3232 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3232_capa_status_board() from public, anon;
grant execute on function public.founder_r3232_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3232_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.emergency_drill_capa_actions_r3232)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.emergency_drill_capa_actions_r3232 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3232_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3232_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3232_regulatory_impact_digest()
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
  from public.emergency_drill_capa_actions_r3232 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3232_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3232_regulatory_impact_digest() to authenticated;

-- 8) Retrain priority queue (engineers needing intervention)
create or replace function public.founder_r3232_retrain_priority_queue()
returns table(
  hospital_name text,
  engineer_name text,
  drill_ref text,
  drill_date date,
  drill_type text,
  response_time_minutes numeric,
  checklist_score_pct numeric,
  weak_step_identified text,
  retrain_due_date date,
  readiness_verdict text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.hospital_name, d.engineer_name, d.drill_ref, d.drill_date,
    d.drill_type, d.response_time_minutes, d.checklist_score_pct,
    d.weak_step_identified, d.retrain_due_date, d.readiness_verdict
  from public.emergency_drill_r3232 d
  where d.retrain_due
     or d.readiness_verdict in ('retraining_required','not_ready','absent_unassessed')
  order by d.retrain_due_date asc nulls last, d.checklist_score_pct asc nulls last;
end;
$$;

revoke execute on function public.founder_r3232_retrain_priority_queue() from public, anon;
grant execute on function public.founder_r3232_retrain_priority_queue() to authenticated;
