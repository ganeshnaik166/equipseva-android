-- Round 3312: Engineer Scheduled-Service Appointment Adherence & Missed-Visit Recovery Tracker
-- Field-engineer appointment adherence — visit type × window × actual status × delay × reschedule × advance notice × SLA impact × adherence verdict × recovery/coaching CAPA

-- =============================================================================
-- TABLE 1: svc_appointment_adherence_r3312 — per scheduled service visit
-- =============================================================================
create table if not exists public.svc_appointment_adherence_r3312 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  hospital_name text not null,
  job_code text not null,
  visit_type text not null check (visit_type in (
    'preventive_maintenance','amc_scheduled','repair_followup','installation','calibration'
  )),
  scheduled_date date not null,
  scheduled_window text not null check (scheduled_window in (
    'morning','afternoon','full_day','specific_slot'
  )),
  actual_status text not null check (actual_status in (
    'completed_on_time','completed_late','rescheduled','missed_no_show','cancelled_customer','cancelled_engineer'
  )),
  delay_minutes int,
  reschedule_count int not null default 0,
  advance_notice_given boolean not null default false,
  customer_informed boolean not null default false,
  recovery_visit_date date,
  sla_impact text not null check (sla_impact in (
    'none','minor','breach','repeat_breach'
  )),
  adherence_verdict text not null check (adherence_verdict in (
    'reliable','minor_slip','chronic_slippage','no_show_escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.svc_appointment_adherence_r3312 enable row level security;

create index if not exists idx_svc_appt_adherence_r3312_org on public.svc_appointment_adherence_r3312(organization_id);
create index if not exists idx_svc_appt_adherence_r3312_date on public.svc_appointment_adherence_r3312(scheduled_date);
create index if not exists idx_svc_appt_adherence_r3312_verdict on public.svc_appointment_adherence_r3312(adherence_verdict);

-- =============================================================================
-- TABLE 2: svc_appointment_adherence_capa_actions_r3312 — recovery & coaching CAPA
-- =============================================================================
create table if not exists public.svc_appointment_adherence_capa_actions_r3312 (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.svc_appointment_adherence_r3312(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missed_no_show','chronic_slippage','repeat_breach','advance_notice_gap',
    'customer_comm_gap','recovery_delay','route_overload'
  )),
  root_cause text not null check (root_cause in (
    'route_overload','parts_delay','traffic_transport','double_booking',
    'customer_unavailable','engineer_absence','poor_scheduling','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rebalance_route','add_engineer_capacity','coaching_session','auto_reminder_setup',
    'buffer_slot_policy','escalate_to_lead','priority_reschedule','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_severity text not null check (risk_severity in (
    'none','low','medium','high','critical'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.svc_appointment_adherence_capa_actions_r3312 enable row level security;

create index if not exists idx_svc_appt_capa_r3312_visit on public.svc_appointment_adherence_capa_actions_r3312(visit_id);
create index if not exists idx_svc_appt_capa_r3312_status on public.svc_appointment_adherence_capa_actions_r3312(capa_status);

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

  -- 14 scheduled-visit rows
  insert into public.svc_appointment_adherence_r3312 (
    organization_id, engineer_name, region, hospital_name, job_code, visit_type,
    scheduled_date, scheduled_window, actual_status, delay_minutes, reschedule_count,
    advance_notice_given, customer_informed, recovery_visit_date, sla_impact, adherence_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.hosp, q.job, q.vt,
    q.sd::date, q.sw, q.ast, q.dly, q.rsc,
    q.ang, q.ci, q.rvd::date, q.sla, q.av, q.nt
  from (values
    ('Ramesh Kumar','Chennai','Apollo Chennai','JOB-AMC-4101','amc_scheduled',
     '2026-07-02','morning','completed_on_time',0,0,true,true,null,'none','reliable','Quarterly AMC visit completed within morning slot'),
    ('Ramesh Kumar','Chennai','CMC Vellore','JOB-PM-4102','preventive_maintenance',
     '2026-07-03','afternoon','completed_late',75,0,true,true,null,'minor','minor_slip','Arrived 75 min late due to highway traffic — customer informed ahead'),
    ('Anil Sharma','Delhi NCR','AIIMS Delhi','JOB-RPR-4103','repair_followup',
     '2026-07-01','full_day','missed_no_show',null,1,false,false,'2026-07-05','breach','no_show_escalated','No-show without notice — recovery visit booked 05 Jul, escalated to lead'),
    ('Anil Sharma','Delhi NCR','Fortis Gurgaon','JOB-INST-4104','installation',
     '2026-07-04','specific_slot','completed_on_time',0,0,true,true,null,'none','reliable','New ventilator install completed in booked slot'),
    ('Suresh Reddy','Hyderabad','KIMS Hyderabad','JOB-CAL-4105','calibration',
     '2026-06-30','morning','rescheduled',null,2,true,true,'2026-07-07','minor','minor_slip','Rescheduled twice at customer request — calibration moved to 07 Jul'),
    ('Suresh Reddy','Hyderabad','Yashoda Hyderabad','JOB-AMC-4106','amc_scheduled',
     '2026-06-29','afternoon','completed_late',130,1,false,true,null,'breach','chronic_slippage','Late 130 min with no advance notice — third late visit this quarter'),
    ('Vijay Nair','Bengaluru','Manipal Bengaluru','JOB-PM-4107','preventive_maintenance',
     '2026-07-02','morning','completed_on_time',0,0,true,true,null,'none','reliable','PM completed within morning window'),
    ('Vijay Nair','Bengaluru','Narayana Health Bengaluru','JOB-RPR-4108','repair_followup',
     '2026-07-03','full_day','cancelled_customer',null,0,true,false,'2026-07-09','minor','minor_slip','Customer cancelled day-of — biomed unavailable, revisit 09 Jul'),
    ('Prakash Iyer','Mumbai','Kokilaben Mumbai','JOB-CAL-4109','calibration',
     '2026-07-01','specific_slot','completed_on_time',15,0,true,true,null,'none','reliable','Minor 15 min delay within slot tolerance'),
    ('Prakash Iyer','Mumbai','Ruby Hall Pune','JOB-AMC-4110','amc_scheduled',
     '2026-06-28','morning','missed_no_show',null,2,false,false,'2026-07-06','repeat_breach','no_show_escalated','Second no-show for this site — repeat SLA breach, escalated to lead'),
    ('Deepak Verma','Delhi NCR','AIIMS Delhi','JOB-PM-4111','preventive_maintenance',
     '2026-06-27','afternoon','cancelled_engineer',null,1,true,true,'2026-07-04','minor','minor_slip','Engineer pulled to emergency — PM rebooked 04 Jul, customer informed'),
    ('Karthik Rao','Chennai','Apollo Chennai','JOB-RPR-4112','repair_followup',
     '2026-07-04','full_day','completed_on_time',0,0,true,true,null,'none','reliable','Follow-up repair closed on time'),
    ('Suresh Reddy','Hyderabad','KIMS Hyderabad','JOB-PM-4113','preventive_maintenance',
     '2026-06-26','morning','completed_late',200,1,false,true,null,'repeat_breach','chronic_slippage','Late 200 min — chronic slippage, route overload flagged for Hyderabad zone'),
    ('Manoj Gupta','Bengaluru','Manipal Bengaluru','JOB-INST-4114','installation',
     '2026-06-29','specific_slot','rescheduled',null,1,true,false,'2026-07-08','minor','minor_slip','Parts delay forced reschedule to 08 Jul — customer notified late')
  ) as q(eng, reg, hosp, job, vt, sd, sw, ast, dly, rsc, ang, ci, rvd, sla, av, nt);

  -- CAPA seed — recovery/coaching actions attached via job_code
  insert into public.svc_appointment_adherence_capa_actions_r3312 (
    visit_id, finding_category, root_cause, corrective_action,
    capa_status, risk_severity, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.rs, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('JOB-RPR-4103','missed_no_show','poor_scheduling','priority_reschedule','in_progress','high','2026-07-05',null,3500.00,'No-show recovery visit scheduled — coaching session flagged'),
    ('JOB-AMC-4106','chronic_slippage','route_overload','rebalance_route','open','medium','2026-07-10',null,6000.00,'Third late visit — route rebalancing under review for Hyderabad'),
    ('JOB-AMC-4110','repeat_breach','engineer_absence','escalate_to_lead','escalated','critical','2026-07-06',null,12000.00,'Repeat SLA breach — escalated to regional lead for account save'),
    ('JOB-PM-4113','route_overload','route_overload','add_engineer_capacity','open','high','2026-07-12',null,15000.00,'Route overload — adding second engineer to Hyderabad zone'),
    ('JOB-CAL-4105','recovery_delay','customer_unavailable','buffer_slot_policy','verification_pending','low','2026-07-08','2026-07-07',2000.00,'Buffer-slot policy applied — calibration completed 07 Jul'),
    ('JOB-INST-4114','advance_notice_gap','parts_delay','auto_reminder_setup','closed','low','2026-07-05','2026-07-03',1500.00,'Auto-reminder configured — customer notified earlier next cycle'),
    ('JOB-RPR-4108','customer_comm_gap','customer_unavailable','coaching_session','overdue','medium','2026-06-30',null,4000.00,'Coaching on pre-visit confirmation — past target closure date')
  ) as q(job, fc, rc, ca, cst, rs, tcd, acd, cost, nt)
  join public.svc_appointment_adherence_r3312 e
    on e.organization_id = v_org_id and e.job_code = q.job;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adherence verdict distribution
create or replace function public.founder_r3312_adherence_verdict_rollup()
returns table(adherence_verdict text, visits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.svc_appointment_adherence_r3312)
  select l.adherence_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.svc_appointment_adherence_r3312 l
  group by l.adherence_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3312_adherence_verdict_rollup() from public, anon;
grant execute on function public.founder_r3312_adherence_verdict_rollup() to authenticated;

-- 2) Engineer adherence scorecard
create or replace function public.founder_r3312_engineer_scorecard()
returns table(
  engineer_name text,
  region text,
  total_visits bigint,
  on_time bigint,
  completed_late bigint,
  rescheduled bigint,
  missed bigint,
  cancelled bigint,
  breaches bigint,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region,
    count(*)::bigint,
    count(*) filter (where l.actual_status = 'completed_on_time')::bigint,
    count(*) filter (where l.actual_status = 'completed_late')::bigint,
    count(*) filter (where l.actual_status = 'rescheduled')::bigint,
    count(*) filter (where l.actual_status = 'missed_no_show')::bigint,
    count(*) filter (where l.actual_status in ('cancelled_customer','cancelled_engineer'))::bigint,
    count(*) filter (where l.sla_impact in ('breach','repeat_breach'))::bigint,
    round(100.0 * count(*) filter (where l.actual_status = 'completed_on_time')::numeric / nullif(count(*),0), 1)
  from public.svc_appointment_adherence_r3312 l
  group by l.engineer_name, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3312_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3312_engineer_scorecard() to authenticated;

-- 3) Visit type × actual status matrix
create or replace function public.founder_r3312_visit_type_status_matrix()
returns table(visit_type text, actual_status text, visits bigint, avg_delay_minutes numeric, breaches bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.visit_type, l.actual_status, count(*)::bigint,
    round(avg(l.delay_minutes), 1),
    count(*) filter (where l.sla_impact in ('breach','repeat_breach'))::bigint
  from public.svc_appointment_adherence_r3312 l
  group by l.visit_type, l.actual_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3312_visit_type_status_matrix() from public, anon;
grant execute on function public.founder_r3312_visit_type_status_matrix() to authenticated;

-- 4) Daily adherence trend
create or replace function public.founder_r3312_daily_adherence_trend()
returns table(scheduled_date date, visits bigint, on_time bigint, missed bigint, rescheduled bigint, breaches bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scheduled_date,
    count(*)::bigint,
    count(*) filter (where l.actual_status = 'completed_on_time')::bigint,
    count(*) filter (where l.actual_status = 'missed_no_show')::bigint,
    count(*) filter (where l.actual_status = 'rescheduled')::bigint,
    count(*) filter (where l.sla_impact in ('breach','repeat_breach'))::bigint
  from public.svc_appointment_adherence_r3312 l
  group by l.scheduled_date
  order by l.scheduled_date desc;
end;
$$;

revoke execute on function public.founder_r3312_daily_adherence_trend() from public, anon;
grant execute on function public.founder_r3312_daily_adherence_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3312_capa_status_board()
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
  from public.svc_appointment_adherence_capa_actions_r3312 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3312_capa_status_board() from public, anon;
grant execute on function public.founder_r3312_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3312_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.svc_appointment_adherence_capa_actions_r3312)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.svc_appointment_adherence_capa_actions_r3312 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3312_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3312_root_cause_pareto() to authenticated;

-- 7) Risk-severity cost digest
create or replace function public.founder_r3312_risk_severity_digest()
returns table(risk_severity text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_severity, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.svc_appointment_adherence_capa_actions_r3312 c
  group by c.risk_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3312_risk_severity_digest() from public, anon;
grant execute on function public.founder_r3312_risk_severity_digest() to authenticated;

-- 8) High-risk visit queue (top individual concerns)
create or replace function public.founder_r3312_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  hospital_name text,
  job_code text,
  scheduled_date date,
  visit_type text,
  actual_status text,
  sla_impact text,
  adherence_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.hospital_name, l.job_code, l.scheduled_date,
    l.visit_type, l.actual_status, l.sla_impact, l.adherence_verdict, l.notes
  from public.svc_appointment_adherence_r3312 l
  where l.actual_status in ('missed_no_show','cancelled_customer','cancelled_engineer','completed_late','rescheduled')
     or l.sla_impact in ('breach','repeat_breach')
     or l.adherence_verdict in ('chronic_slippage','no_show_escalated')
  order by l.scheduled_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3312_high_risk_queue() from public, anon;
grant execute on function public.founder_r3312_high_risk_queue() to authenticated;
