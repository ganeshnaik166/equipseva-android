-- Round 3496: Engineer First-Line-Maintenance / Operator Daily-Care Checklist Tracker
-- Autonomous-maintenance (first-line care) QA — care task × frequency × compliance status × adherence % × issues × escalation × CAPA

-- =============================================================================
-- TABLE 1: first_line_operator_care_r3496 — per-check operator daily-care records
-- =============================================================================
create table if not exists public.first_line_operator_care_r3496 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  device_model text not null,
  operator_name text not null,
  checklist_code text not null,
  care_task text not null check (care_task in (
    'cleaning','lubrication','visual_inspection','consumable_check',
    'calibration_verify','leak_check','filter_check'
  )),
  frequency text not null check (frequency in (
    'daily','weekly','per_shift','monthly'
  )),
  compliance_status text not null check (compliance_status in (
    'completed','partial','missed','not_applicable'
  )),
  adherence_pct numeric(5,2),
  issues_found int not null default 0,
  escalated boolean not null default false,
  check_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.first_line_operator_care_r3496 enable row level security;

create index if not exists idx_first_line_operator_care_r3496_org on public.first_line_operator_care_r3496(organization_id);
create index if not exists idx_first_line_operator_care_r3496_date on public.first_line_operator_care_r3496(check_date);
create index if not exists idx_first_line_operator_care_r3496_status on public.first_line_operator_care_r3496(compliance_status);

-- =============================================================================
-- TABLE 2: first_line_operator_care_capa_actions_r3496 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.first_line_operator_care_capa_actions_r3496 (
  id uuid primary key default gen_random_uuid(),
  care_log_id uuid not null references public.first_line_operator_care_r3496(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cleaning_not_performed','lubrication_overdue','visual_defect_found','consumable_stockout',
    'calibration_verify_failed','leak_detected','filter_clogged','checklist_not_completed','operator_training_gap'
  )),
  root_cause text not null check (root_cause in (
    'operator_skipped_task','no_training','consumable_unavailable','time_pressure','unclear_procedure',
    'equipment_fault','supervisor_oversight_gap','pending_investigation','staffing_shortage'
  )),
  corrective_action text not null check (corrective_action in (
    'operator_retraining','revise_sop','replenish_consumables','reschedule_shift_workload','supervisor_sign_off',
    'escalate_to_biomedical','update_checklist_template','install_visual_aid','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','internal_only','none','iso_13485_deviation','patient_safety_alert','downtime_risk'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.first_line_operator_care_capa_actions_r3496 enable row level security;

create index if not exists idx_first_line_operator_capa_r3496_log on public.first_line_operator_care_capa_actions_r3496(care_log_id);
create index if not exists idx_first_line_operator_capa_r3496_status on public.first_line_operator_care_capa_actions_r3496(capa_status);

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

  -- 16 operator daily-care check rows
  insert into public.first_line_operator_care_r3496 (
    organization_id, engineer_name, hospital_name, device_model, operator_name, checklist_code,
    care_task, frequency, compliance_status, adherence_pct, issues_found, escalated, check_date, notes
  )
  select v_org_id, q.eng, q.hosp, q.dmodel, q.oper, q.ccode,
    q.task, q.freq, q.cst, q.adh, q.iss, q.esc, q.cdate::date, q.nt
  from (values
    ('Ramesh Kumar','Apollo Chennai','Drager Fabius GS','Nurse Anitha','FLM-APL-01',
     'cleaning','daily','completed',100,0,false,'2026-07-05','Anesthesia machine external cleaning done per shift'),
    ('Ramesh Kumar','Apollo Chennai','GE Carescape B650','Nurse Anitha','FLM-APL-02',
     'visual_inspection','per_shift','completed',98,0,false,'2026-07-05','Monitor cables and screen inspected, no defects'),
    ('Suresh Nair','Fortis Gurgaon','Fresenius 4008S','Tech Rakesh','FLM-FRT-11',
     'leak_check','daily','partial',72,1,false,'2026-07-04','Dialysis machine hydraulic leak check partial — one port skipped'),
    ('Suresh Nair','Fortis Gurgaon','Maquet Servo-i','Tech Rakesh','FLM-FRT-12',
     'filter_check','daily','missed',40,2,true,'2026-07-04','Ventilator expiratory filter check missed two shifts — escalated'),
    ('Priya Menon','Manipal Bengaluru','Mindray SV300','Nurse Deepa','FLM-MNP-21',
     'consumable_check','per_shift','completed',96,0,false,'2026-07-03','Ventilator circuit and HME consumables stocked and verified'),
    ('Priya Menon','Manipal Bengaluru','BPL Eleon','Nurse Deepa','FLM-MNP-22',
     'lubrication','weekly','partial',68,1,false,'2026-07-03','OT table lubrication partial — grease stock low'),
    ('Arjun Rao','AIIMS Delhi','Philips MX450','Tech Vijay','FLM-AIM-31',
     'visual_inspection','per_shift','completed',99,0,false,'2026-07-02','Patient monitor visual inspection nominal'),
    ('Arjun Rao','AIIMS Delhi','Getinge Flow-c','Tech Vijay','FLM-AIM-32',
     'leak_check','daily','missed',35,3,true,'2026-07-02','Anesthesia workstation leak test missed — gas smell reported, escalated'),
    ('Kavya Iyer','CMC Vellore','Nihon Kohden BSM','Nurse Latha','FLM-CMC-41',
     'cleaning','daily','completed',100,0,false,'2026-07-01','Bedside monitor surface disinfection complete'),
    ('Kavya Iyer','CMC Vellore','Hamilton C6','Nurse Latha','FLM-CMC-42',
     'calibration_verify','weekly','partial',75,1,false,'2026-07-01','Ventilator flow-sensor calibration verify partial — recheck scheduled'),
    ('Mohan Das','KIMS Hyderabad','Skanray Star50','Tech Sailaja','FLM-KIM-51',
     'filter_check','daily','completed',97,0,false,'2026-06-30','Ventilator inlet filter inspected and clean'),
    ('Mohan Das','KIMS Hyderabad','Trivitron Elisco','Tech Sailaja','FLM-KIM-52',
     'consumable_check','per_shift','missed',45,2,true,'2026-06-30','ICU pump consumable check missed — battery packs not verified, escalated'),
    ('Deepa Pillai','Yashoda Hyderabad','Drager Evita V300','Nurse Ravi','FLM-YSH-61',
     'lubrication','monthly','completed',94,0,false,'2026-06-29','Monthly lubrication of moving parts done per OEM schedule'),
    ('Deepa Pillai','Yashoda Hyderabad','Mindray N19','Nurse Ravi','FLM-YSH-62',
     'visual_inspection','per_shift','not_applicable',null,0,false,'2026-06-29','Device on standby this shift — inspection not applicable'),
    ('Sanjay Verma','Kokilaben Mumbai','GE Aisys CS2','Tech Farah','FLM-KKB-71',
     'calibration_verify','weekly','partial',70,1,false,'2026-06-28','O2 sensor calibration verify partial — sensor drift noted'),
    ('Sanjay Verma','Kokilaben Mumbai','Philips V60','Tech Farah','FLM-KKB-72',
     'cleaning','daily','missed',30,2,true,'2026-06-28','NIV device cleaning missed over weekend — escalated to biomedical')
  ) as q(eng, hosp, dmodel, oper, ccode, task, freq, cst, adh, iss, esc, cdate, nt);

  -- CAPA seed — attach to specific checks via checklist_code
  insert into public.first_line_operator_care_capa_actions_r3496 (
    care_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FLM-FRT-11','leak_detected','unclear_procedure','revise_sop','in_progress','downtime_risk','Suresh Nair','2026-07-08',null,3000.00,'Leak-check SOP revised to cover all dialysis ports'),
    ('FLM-FRT-12','checklist_not_completed','operator_skipped_task','operator_retraining','escalated','patient_safety_alert','Suresh Nair','2026-07-07',null,5000.00,'Filter check missed two shifts — operator retraining, escalated'),
    ('FLM-MNP-22','lubrication_overdue','consumable_unavailable','replenish_consumables','open','downtime_risk','Priya Menon','2026-07-06',null,2500.00,'Grease stock replenished for OT table lubrication'),
    ('FLM-AIM-32','leak_detected','equipment_fault','escalate_to_biomedical','escalated','patient_safety_alert','Arjun Rao','2026-07-05',null,12000.00,'Anesthesia gas leak — escalated to biomedical for valve repair'),
    ('FLM-CMC-42','calibration_verify_failed','no_training','operator_retraining','verification_pending','iso_13485_deviation','Kavya Iyer','2026-07-06',null,4000.00,'Flow-sensor cal verify — operator retrained, verify next week'),
    ('FLM-KIM-52','consumable_stockout','staffing_shortage','replenish_consumables','overdue','nabh_finding','Mohan Das','2026-07-02',null,3500.00,'Battery pack stockout — replenishment past target, staffing gap'),
    ('FLM-KKB-71','calibration_verify_failed','equipment_fault','escalate_to_biomedical','open','iso_13485_deviation','Sanjay Verma','2026-07-04',null,6000.00,'O2 sensor drift — biomedical to replace sensor'),
    ('FLM-KKB-72','cleaning_not_performed','time_pressure','revise_sop','closed','nabh_finding','Sanjay Verma','2026-07-02','2026-06-30',1500.00,'Weekend cleaning gap — SOP revised with weekend coverage; closed')
  ) as q(ccode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.first_line_operator_care_r3496 e
    on e.organization_id = v_org_id and e.checklist_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3496_compliance_status_rollup()
returns table(compliance_status text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.first_line_operator_care_r3496)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.first_line_operator_care_r3496 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3496_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3496_compliance_status_rollup() to authenticated;

-- 2) Care-task scorecard
create or replace function public.founder_r3496_care_task_scorecard()
returns table(
  care_task text,
  total_checks bigint,
  completed bigint,
  partial bigint,
  missed bigint,
  escalated_count bigint,
  issues_total bigint,
  avg_adherence_pct numeric,
  completion_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.care_task,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'completed')::bigint,
    count(*) filter (where l.compliance_status = 'partial')::bigint,
    count(*) filter (where l.compliance_status = 'missed')::bigint,
    count(*) filter (where l.escalated = true)::bigint,
    coalesce(sum(l.issues_found),0)::bigint,
    round(avg(l.adherence_pct), 1),
    round(100.0 * count(*) filter (where l.compliance_status = 'completed')::numeric / nullif(count(*),0), 1)
  from public.first_line_operator_care_r3496 l
  group by l.care_task
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3496_care_task_scorecard() from public, anon;
grant execute on function public.founder_r3496_care_task_scorecard() to authenticated;

-- 3) Care-task × compliance-status matrix
create or replace function public.founder_r3496_care_task_status_matrix()
returns table(care_task text, compliance_status text, checks bigint, avg_adherence_pct numeric, issues_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.care_task, l.compliance_status, count(*)::bigint,
    round(avg(l.adherence_pct), 1),
    coalesce(sum(l.issues_found),0)::bigint
  from public.first_line_operator_care_r3496 l
  group by l.care_task, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3496_care_task_status_matrix() from public, anon;
grant execute on function public.founder_r3496_care_task_status_matrix() to authenticated;

-- 4) Monthly adherence trend
create or replace function public.founder_r3496_monthly_adherence_trend()
returns table(check_month date, checks bigint, completed bigint, missed bigint, escalated_count bigint, avg_adherence_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.check_date)::date as check_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'completed')::bigint,
    count(*) filter (where l.compliance_status = 'missed')::bigint,
    count(*) filter (where l.escalated = true)::bigint,
    round(avg(l.adherence_pct), 1)
  from public.first_line_operator_care_r3496 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3496_monthly_adherence_trend() from public, anon;
grant execute on function public.founder_r3496_monthly_adherence_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3496_capa_status_board()
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
  from public.first_line_operator_care_capa_actions_r3496 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3496_capa_status_board() from public, anon;
grant execute on function public.founder_r3496_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3496_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.first_line_operator_care_capa_actions_r3496)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.first_line_operator_care_capa_actions_r3496 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3496_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3496_root_cause_pareto() to authenticated;

-- 7) Adherence-impact digest (banded)
create or replace function public.founder_r3496_adherence_impact_digest()
returns table(adherence_band text, checks bigint, missed bigint, escalated_count bigint, issues_total bigint, avg_adherence_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when l.adherence_pct is null then 'not_applicable'
      when l.adherence_pct >= 95 then 'high_95_plus'
      when l.adherence_pct >= 80 then 'medium_80_94'
      when l.adherence_pct >= 50 then 'low_50_79'
      else 'critical_below_50'
    end as adherence_band,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'missed')::bigint,
    count(*) filter (where l.escalated = true)::bigint,
    coalesce(sum(l.issues_found),0)::bigint,
    round(avg(l.adherence_pct), 1)
  from public.first_line_operator_care_r3496 l
  group by 1
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3496_adherence_impact_digest() from public, anon;
grant execute on function public.founder_r3496_adherence_impact_digest() to authenticated;

-- 8) High-risk care queue (missed / low-adherence / escalated / issues)
create or replace function public.founder_r3496_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  device_model text,
  operator_name text,
  care_task text,
  frequency text,
  check_date date,
  compliance_status text,
  adherence_pct numeric,
  issues_found int,
  escalated boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.device_model, l.operator_name, l.care_task, l.frequency,
    l.check_date, l.compliance_status, l.adherence_pct, l.issues_found, l.escalated, l.notes
  from public.first_line_operator_care_r3496 l
  where l.compliance_status in ('missed','partial')
     or l.adherence_pct < 70
     or l.escalated = true
     or l.issues_found > 0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3496_high_risk_queue() from public, anon;
grant execute on function public.founder_r3496_high_risk_queue() to authenticated;
