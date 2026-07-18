-- Round 3260: Engineer Workshop Bench-Repair Turnaround (TAT) & Backlog Tracker
-- Workshop ops — workshop city × bench engineer × equipment type × intake/diagnosis/parts/complete dates × promised vs actual TAT × delay reason × bench test × rework × backlog verdict × CAPA expedite

-- =============================================================================
-- TABLE 1: workshop_bench_repair_r3260 — individual bench-repair jobs
-- =============================================================================
create table if not exists public.workshop_bench_repair_r3260 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  workshop_city text not null,
  bench_engineer_name text not null,
  job_code text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','infusion_pump','ventilator_module','defibrillator',
    'ecg_machine','spo2_module','suction_unit'
  )),
  intake_date date not null,
  diagnosis_date date,
  parts_ordered_date date,
  repair_complete_date date,
  promised_tat_days int not null,
  actual_tat_days int,
  delay_reason text not null check (delay_reason in (
    'no_delay','parts_wait','diagnosis_complex','engineer_bandwidth',
    'customer_approval_wait','oem_support_wait'
  )),
  bench_test_result text not null check (bench_test_result in (
    'full_pass','partial_pass','failed_again','pending'
  )),
  rework_count int not null default 0,
  job_verdict text not null check (job_verdict in (
    'closed_on_time','closed_late','in_progress_on_track','in_progress_at_risk','stalled'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.workshop_bench_repair_r3260 enable row level security;

create index if not exists idx_workshop_bench_r3260_org on public.workshop_bench_repair_r3260(organization_id);
create index if not exists idx_workshop_bench_r3260_intake on public.workshop_bench_repair_r3260(intake_date);
create index if not exists idx_workshop_bench_r3260_verdict on public.workshop_bench_repair_r3260(job_verdict);

-- =============================================================================
-- TABLE 2: workshop_bench_repair_capa_actions_r3260 — expedite / escalation CAPA
-- =============================================================================
create table if not exists public.workshop_bench_repair_capa_actions_r3260 (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.workshop_bench_repair_r3260(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'tat_breach','parts_procurement_delay','diagnosis_backlog','repeat_rework',
    'customer_approval_stuck','oem_dependency','bench_capacity_overload'
  )),
  root_cause text not null check (root_cause in (
    'no_local_parts_stock','vendor_lead_time_long','single_engineer_dependency',
    'incomplete_fault_history','customer_po_pending','oem_ticket_unanswered',
    'spares_budget_hold','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'air_freight_parts','borrow_parts_from_scrap_unit','reassign_to_senior_engineer',
    'add_weekend_bench_shift','escalate_to_customer_admin','escalate_oem_regional_manager',
    'issue_standby_unit','approve_emergency_spares_budget','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  customer_impact text not null check (customer_impact in (
    'sla_credit_due','customer_escalation_logged','standby_unit_issued',
    'none','internal_only','contract_renewal_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.workshop_bench_repair_capa_actions_r3260 enable row level security;

create index if not exists idx_workshop_bench_capa_r3260_job on public.workshop_bench_repair_capa_actions_r3260(job_id);
create index if not exists idx_workshop_bench_capa_r3260_status on public.workshop_bench_repair_capa_actions_r3260(capa_status);

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

  -- 14 bench-repair job rows
  insert into public.workshop_bench_repair_r3260 (
    organization_id, workshop_city, bench_engineer_name, job_code, equipment_type,
    intake_date, diagnosis_date, parts_ordered_date, repair_complete_date,
    promised_tat_days, actual_tat_days, delay_reason, bench_test_result,
    rework_count, job_verdict, notes
  )
  select v_org_id, q.city, q.eng, q.code, q.etype,
    q.intake::date, q.diag::date, q.parts::date, q.comp::date,
    q.ptat, q.atat, q.dreason, q.btr,
    q.rwk, q.jv, q.nt
  from (values
    ('Hyderabad','Ravi Teja Kumar','WB-HYD-1001','patient_monitor','2026-06-22','2026-06-23','2026-06-24','2026-06-28',
     7,6,'no_delay','full_pass',0,'closed_on_time','KIMS Hyderabad monitor — SpO2 board reflow, 24h soak test clean'),
    ('Hyderabad','Ravi Teja Kumar','WB-HYD-1002','infusion_pump','2026-06-25','2026-06-26','2026-06-27','2026-07-08',
     7,13,'parts_wait','full_pass',1,'closed_late','Yashoda Hyderabad pump — occlusion sensor from Mumbai depot took 8 days'),
    ('Bengaluru','Kavitha Srinivasan','WB-BLR-2001','ventilator_module','2026-06-20','2026-06-24','2026-06-26',null,
     10,null,'oem_support_wait','pending',0,'stalled','Manipal Bengaluru vent flow-sensor module — OEM ticket unanswered 12 days'),
    ('Bengaluru','Kavitha Srinivasan','WB-BLR-2002','defibrillator','2026-07-01','2026-07-02',null,'2026-07-06',
     7,5,'no_delay','full_pass',0,'closed_on_time','Fortis Bengaluru defib — paddle connector renewed, 200J energy check OK'),
    ('Bengaluru','Arjun Reddy','WB-BLR-2003','ecg_machine','2026-07-05','2026-07-06','2026-07-07',null,
     8,null,'parts_wait','pending',0,'in_progress_at_risk','St John''s Bengaluru ECG — lead-set PCB awaited, 13 Jul promise at risk'),
    ('Chennai','S. Muthukumar','WB-CHN-3001','patient_monitor','2026-07-08','2026-07-09',null,null,
     7,null,'no_delay','pending',0,'in_progress_on_track','Apollo Chennai monitor — NIBP pump rebuild in progress, day 3 of 7'),
    ('Chennai','S. Muthukumar','WB-CHN-3002','suction_unit','2026-06-18','2026-06-19','2026-06-20','2026-06-24',
     5,6,'engineer_bandwidth','full_pass',0,'closed_late','CMC Vellore suction unit — one day late, bench queue overloaded that week'),
    ('Chennai','Divya Lakshmi','WB-CHN-3003','spo2_module','2026-06-28','2026-06-29',null,'2026-07-01',
     5,3,'no_delay','full_pass',0,'closed_on_time','MIOT Chennai SpO2 module — connector reseat and recalibration, quick close'),
    ('Delhi','Vikram Malhotra','WB-DEL-4001','infusion_pump','2026-06-15','2026-06-17','2026-06-18','2026-06-30',
     8,15,'customer_approval_wait','partial_pass',2,'closed_late','AIIMS Delhi pump — PO approval sat 6 days; keypad still sticky after two reworks'),
    ('Delhi','Vikram Malhotra','WB-DEL-4002','ventilator_module','2026-06-26','2026-07-01',null,null,
     10,null,'diagnosis_complex','failed_again',1,'stalled','Fortis Gurgaon O2-blender module failed bench retest — senior review needed'),
    ('Delhi','Neha Chauhan','WB-DEL-4003','defibrillator','2026-07-10','2026-07-11',null,null,
     7,null,'no_delay','pending',0,'in_progress_on_track','Max Saket defib — capacitor bank replacement underway, on schedule'),
    ('Pune','Sagar Kulkarni','WB-PUN-5001','ecg_machine','2026-06-24','2026-06-25','2026-06-26','2026-07-02',
     7,8,'parts_wait','full_pass',0,'closed_late','Ruby Hall Pune ECG — thermal print head from Delhi depot one day late'),
    ('Pune','Sagar Kulkarni','WB-PUN-5002','patient_monitor','2026-07-06','2026-07-08','2026-07-09',null,
     7,null,'parts_wait','pending',0,'in_progress_at_risk','Sahyadri Pune monitor — mainboard on air-freight, 13 Jul promise slipping'),
    ('Kochi','Anish Menon','WB-KOC-6001','suction_unit','2026-07-03','2026-07-04',null,'2026-07-07',
     5,4,'no_delay','full_pass',0,'closed_on_time','Aster Medcity Kochi suction unit — motor brush replaced, vacuum verified')
  ) as q(city, eng, code, etype, intake, diag, parts, comp, ptat, atat, dreason, btr, rwk, jv, nt);

  -- CAPA seed — attach to specific jobs via job code
  insert into public.workshop_bench_repair_capa_actions_r3260 (
    job_id, finding_category, root_cause, corrective_action,
    capa_status, customer_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WB-BLR-2001','oem_dependency','oem_ticket_unanswered','escalate_oem_regional_manager','escalated','standby_unit_issued','2026-07-22',null,15000.00,'Standby ventilator module issued to Manipal; OEM regional manager looped in'),
    ('WB-DEL-4002','repeat_rework','incomplete_fault_history','reassign_to_senior_engineer','in_progress','customer_escalation_logged','2026-07-20',null,8000.00,'Senior engineer to re-diagnose blender; Fortis biomedical head informed'),
    ('WB-HYD-1002','parts_procurement_delay','vendor_lead_time_long','approve_emergency_spares_budget','closed','sla_credit_due','2026-07-10','2026-07-09',22000.00,'Occlusion sensors added to Hyderabad min-stock; SLA credit issued to Yashoda'),
    ('WB-DEL-4001','customer_approval_stuck','customer_po_pending','escalate_to_customer_admin','verification_pending','sla_credit_due','2026-07-15',null,5000.00,'Pre-approved repair cap agreed with AIIMS stores — verify on next job'),
    ('WB-BLR-2003','parts_procurement_delay','no_local_parts_stock','air_freight_parts','in_progress','none','2026-07-14',null,6500.00,'Lead-set PCB air-freighted from Delhi depot — ETA 12 Jul'),
    ('WB-PUN-5002','bench_capacity_overload','single_engineer_dependency','add_weekend_bench_shift','open','internal_only','2026-07-19',null,4000.00,'Weekend shift added at Pune bench; second engineer being cross-trained'),
    ('WB-CHN-3002','tat_breach','single_engineer_dependency','add_weekend_bench_shift','overdue','contract_renewal_risk','2026-07-05',null,3000.00,'Chennai bench load-balancing plan past target date — ops review pending')
  ) as q(code, fc, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.workshop_bench_repair_r3260 e
    on e.organization_id = v_org_id and e.job_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Job verdict distribution
create or replace function public.founder_r3260_job_verdict_rollup()
returns table(job_verdict text, jobs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.workshop_bench_repair_r3260)
  select l.job_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.workshop_bench_repair_r3260 l
  group by l.job_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3260_job_verdict_rollup() from public, anon;
grant execute on function public.founder_r3260_job_verdict_rollup() to authenticated;

-- 2) Workshop-level TAT scorecard
create or replace function public.founder_r3260_workshop_scorecard()
returns table(
  workshop_city text,
  total_jobs bigint,
  closed_on_time bigint,
  closed_late bigint,
  in_progress bigint,
  stalled bigint,
  avg_promised_tat_days numeric,
  avg_actual_tat_days numeric,
  on_time_close_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.workshop_city,
    count(*)::bigint,
    count(*) filter (where l.job_verdict = 'closed_on_time')::bigint,
    count(*) filter (where l.job_verdict = 'closed_late')::bigint,
    count(*) filter (where l.job_verdict in ('in_progress_on_track','in_progress_at_risk'))::bigint,
    count(*) filter (where l.job_verdict = 'stalled')::bigint,
    round(avg(l.promised_tat_days)::numeric, 1),
    round(avg(l.actual_tat_days)::numeric, 1),
    round(100.0 * count(*) filter (where l.job_verdict = 'closed_on_time')::numeric
      / nullif(count(*) filter (where l.job_verdict in ('closed_on_time','closed_late')),0), 1)
  from public.workshop_bench_repair_r3260 l
  group by l.workshop_city
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3260_workshop_scorecard() from public, anon;
grant execute on function public.founder_r3260_workshop_scorecard() to authenticated;

-- 3) Equipment type × delay reason matrix
create or replace function public.founder_r3260_equipment_delay_matrix()
returns table(equipment_type text, delay_reason text, jobs bigint, avg_actual_tat_days numeric, total_rework bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.delay_reason, count(*)::bigint,
    round(avg(l.actual_tat_days)::numeric, 1),
    coalesce(sum(l.rework_count),0)::bigint
  from public.workshop_bench_repair_r3260 l
  group by l.equipment_type, l.delay_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3260_equipment_delay_matrix() from public, anon;
grant execute on function public.founder_r3260_equipment_delay_matrix() to authenticated;

-- 4) Daily intake trend
create or replace function public.founder_r3260_daily_intake_trend()
returns table(intake_date date, jobs bigint, closed bigint, stalled_jobs bigint, avg_promised_tat_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.intake_date,
    count(*)::bigint,
    count(*) filter (where l.job_verdict in ('closed_on_time','closed_late'))::bigint,
    count(*) filter (where l.job_verdict = 'stalled')::bigint,
    round(avg(l.promised_tat_days)::numeric, 1)
  from public.workshop_bench_repair_r3260 l
  group by l.intake_date
  order by l.intake_date desc;
end;
$$;

revoke execute on function public.founder_r3260_daily_intake_trend() from public, anon;
grant execute on function public.founder_r3260_daily_intake_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3260_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.workshop_bench_repair_capa_actions_r3260 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3260_capa_status_board() from public, anon;
grant execute on function public.founder_r3260_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3260_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.workshop_bench_repair_capa_actions_r3260)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.workshop_bench_repair_capa_actions_r3260 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3260_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3260_root_cause_pareto() to authenticated;

-- 7) Customer impact digest
create or replace function public.founder_r3260_customer_impact_digest()
returns table(customer_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.customer_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.workshop_bench_repair_capa_actions_r3260 c
  group by c.customer_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3260_customer_impact_digest() from public, anon;
grant execute on function public.founder_r3260_customer_impact_digest() to authenticated;

-- 8) High-risk backlog queue (aged / late / rework jobs)
create or replace function public.founder_r3260_high_risk_queue()
returns table(
  workshop_city text,
  bench_engineer_name text,
  job_code text,
  equipment_type text,
  intake_date date,
  promised_tat_days int,
  actual_tat_days int,
  delay_reason text,
  bench_test_result text,
  job_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.workshop_city, l.bench_engineer_name, l.job_code, l.equipment_type,
    l.intake_date, l.promised_tat_days, l.actual_tat_days, l.delay_reason,
    l.bench_test_result, l.job_verdict, l.notes
  from public.workshop_bench_repair_r3260 l
  where l.job_verdict in ('closed_late','in_progress_at_risk','stalled')
     or l.bench_test_result in ('failed_again','partial_pass')
     or l.rework_count >= 1
  order by l.intake_date asc, l.workshop_city;
end;
$$;

revoke execute on function public.founder_r3260_high_risk_queue() from public, anon;
grant execute on function public.founder_r3260_high_risk_queue() to authenticated;
