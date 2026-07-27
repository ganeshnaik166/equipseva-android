-- Round 3512: Engineer Field-Service-Report Turnaround / Submission-Lag Tracker
-- Field service-report turnaround / submission-lag (job-done -> submitted -> approved) —
-- engineer × hospital × service type × submission lag × approval lag × SLA × report status × backlog × CAPA

-- =============================================================================
-- TABLE 1: report_turnaround_r3512 — per-report turnaround / submission-lag log
-- =============================================================================
create table if not exists public.report_turnaround_r3512 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  report_number text not null,
  service_type text not null check (service_type in (
    'breakdown','preventive','installation','calibration','amc_visit'
  )),
  job_completed_date date not null,
  submitted_date date,
  approved_date date,
  submission_lag_hours numeric(8,2),
  approval_lag_hours numeric(8,2),
  sla_hours int not null,
  sla_breached boolean not null,
  report_status text not null check (report_status in (
    'pending_submission','submitted','under_review','approved','returned'
  )),
  backlog_flag boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.report_turnaround_r3512 enable row level security;

create index if not exists idx_report_turnaround_r3512_org on public.report_turnaround_r3512(organization_id);
create index if not exists idx_report_turnaround_r3512_job_date on public.report_turnaround_r3512(job_completed_date);
create index if not exists idx_report_turnaround_r3512_status on public.report_turnaround_r3512(report_status);

-- =============================================================================
-- TABLE 2: report_turnaround_capa_actions_r3512 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.report_turnaround_capa_actions_r3512 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  report_turnaround_id uuid not null references public.report_turnaround_r3512(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'late_submission','report_returned_rework','sla_breach','incomplete_documentation',
    'approval_delay','backlog_accumulation','missing_signature','pending_customer_signoff'
  )),
  root_cause text not null check (root_cause in (
    'engineer_workload_high','field_connectivity_issue','manual_paperwork_delay','incomplete_data_capture',
    'approver_unavailable','process_bottleneck','training_gap','app_sync_failure','pending_customer_signoff'
  )),
  corrective_action text not null check (corrective_action in (
    'engineer_reminder_workflow','mobile_app_offline_capture','escalate_to_supervisor','retrain_engineer',
    'add_approver_backup','template_standardization','auto_sla_alerts','process_reengineering','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  lag_impact_hours numeric(8,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.report_turnaround_capa_actions_r3512 enable row level security;

create index if not exists idx_report_turnaround_capa_r3512_org on public.report_turnaround_capa_actions_r3512(organization_id);
create index if not exists idx_report_turnaround_capa_r3512_link on public.report_turnaround_capa_actions_r3512(report_turnaround_id);
create index if not exists idx_report_turnaround_capa_r3512_status on public.report_turnaround_capa_actions_r3512(capa_status);

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

  -- 16 report turnaround rows
  insert into public.report_turnaround_r3512 (
    organization_id, engineer_name, hospital_name, report_number, service_type,
    job_completed_date, submitted_date, approved_date,
    submission_lag_hours, approval_lag_hours, sla_hours, sla_breached,
    report_status, backlog_flag, notes
  )
  select v_org_id, q.eng, q.hosp, q.rn, q.st,
    q.jcd::date, q.subd::date, q.appd::date,
    q.slag::numeric, q.alag::numeric, q.sla::int, q.brc,
    q.rst, q.bkl, q.nt
  from (values
    ('Ravi Kumar','Apollo Chennai','FSR-2026-0001','breakdown',
     '2026-07-20','2026-07-20','2026-07-21',5.5,20.0,24,false,'approved',false,
     'Breakdown FSR submitted same day and approved next day'),
    ('Suresh Nair','Fortis Gurgaon','FSR-2026-0002','preventive',
     '2026-07-19','2026-07-21',null,40.0,null,24,true,'under_review',false,
     'PM report submitted 40h late — SLA breached, awaiting review'),
    ('Amit Sharma','Manipal Bengaluru','FSR-2026-0003','installation',
     '2026-07-18','2026-07-18','2026-07-19',3.0,22.0,48,false,'approved',false,
     'Installation report submitted on-day and approved within SLA'),
    ('Priya Menon','AIIMS Delhi','FSR-2026-0004','calibration',
     '2026-07-17',null,null,null,null,24,true,'pending_submission',true,
     'Calibration report not yet submitted — backlog, SLA already breached'),
    ('Vijay Reddy','CMC Vellore','FSR-2026-0005','amc_visit',
     '2026-07-16','2026-07-16','2026-07-17',4.0,18.0,48,false,'approved',false,
     'AMC visit report cleared quickly within SLA'),
    ('Deepak Joshi','KIMS Hyderabad','FSR-2026-0006','breakdown',
     '2026-07-15','2026-07-17',null,44.0,null,24,true,'returned',false,
     'Breakdown report returned for missing fault photos — SLA breached'),
    ('Anil Gupta','Yashoda Hyderabad','FSR-2026-0007','preventive',
     '2026-07-15','2026-07-16','2026-07-17',26.0,20.0,24,true,'approved',false,
     'PM report slightly late at 26h but approved after review'),
    ('Karthik Iyer','Kokilaben Mumbai','FSR-2026-0008','installation',
     '2026-07-14','2026-07-14','2026-07-15',6.0,24.0,48,false,'approved',false,
     'Installation commissioning report submitted on-time'),
    ('Ravi Kumar','Narayana Bengaluru','FSR-2026-0009','calibration',
     '2026-07-13','2026-07-15',null,48.0,null,24,true,'under_review',true,
     'Calibration report 48h late — backlog flagged, under review'),
    ('Suresh Nair','Medanta Gurgaon','FSR-2026-0010','breakdown',
     '2026-07-12','2026-07-12','2026-07-13',2.5,19.0,24,false,'approved',false,
     'Fast turnaround breakdown report — well within SLA'),
    ('Amit Sharma','Apollo Chennai','FSR-2026-0011','amc_visit',
     '2026-07-11','2026-07-13',null,45.0,null,48,false,'submitted',false,
     'AMC report submitted within 48h SLA, awaiting review assignment'),
    ('Priya Menon','Fortis Gurgaon','FSR-2026-0012','preventive',
     '2026-07-10',null,null,null,null,24,true,'pending_submission',true,
     'PM report overdue — engineer on leave, backlog accumulating'),
    ('Vijay Reddy','Manipal Bengaluru','FSR-2026-0013','breakdown',
     '2026-07-09','2026-07-11','2026-07-12',50.0,22.0,24,true,'approved',false,
     'Breakdown report very late at 50h, approved after escalation'),
    ('Deepak Joshi','AIIMS Delhi','FSR-2026-0014','calibration',
     '2026-07-08','2026-07-08','2026-07-09',5.0,21.0,24,false,'approved',false,
     'Calibration report submitted same day and approved on-time'),
    ('Anil Gupta','CMC Vellore','FSR-2026-0015','installation',
     '2026-07-07','2026-07-09',null,46.0,null,48,false,'returned',false,
     'Installation report returned for incomplete commissioning checklist'),
    ('Karthik Iyer','KIMS Hyderabad','FSR-2026-0016','amc_visit',
     '2026-07-06','2026-07-08','2026-07-10',42.0,40.0,24,true,'approved',false,
     'AMC report late submission and slow approval — both stages lagging')
  ) as q(eng, hosp, rn, st, jcd, subd, appd, slag, alag, sla, brc, rst, bkl, nt);

  -- CAPA seed — attach to specific reports via report_number
  insert into public.report_turnaround_capa_actions_r3512 (
    organization_id, report_turnaround_id, finding_category, root_cause, corrective_action,
    capa_status, lag_impact_hours, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.lag::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('FSR-2026-0002','late_submission','engineer_workload_high','engineer_reminder_workflow','in_progress',16.0,'Service Head - North','2026-07-25',null,'Late PM submission; automated reminder workflow being enforced for engineer'),
    ('FSR-2026-0004','backlog_accumulation','engineer_workload_high','escalate_to_supervisor','open',24.0,'Regional Ops Manager','2026-07-24',null,'Calibration report backlog; escalated to supervisor for coverage'),
    ('FSR-2026-0006','report_returned_rework','incomplete_data_capture','mobile_app_offline_capture','verification_pending',20.0,'QA Lead','2026-07-22',null,'Report returned for missing photos; offline capture enabled for field kit'),
    ('FSR-2026-0009','sla_breach','field_connectivity_issue','mobile_app_offline_capture','in_progress',24.0,'Field Ops Lead','2026-07-23',null,'Poor site connectivity delayed calibration report sync; offline mode rollout'),
    ('FSR-2026-0012','backlog_accumulation','engineer_workload_high','add_approver_backup','escalated',30.0,'Service Head - North','2026-07-20',null,'Engineer on leave with no backup; backup coverage roster being added'),
    ('FSR-2026-0013','sla_breach','process_bottleneck','process_reengineering','closed',26.0,'Regional Ops Manager','2026-07-18','2026-07-16','Breakdown approval bottleneck resolved; approval routing reengineered'),
    ('FSR-2026-0015','report_returned_rework','training_gap','retrain_engineer','open',18.0,'QA Lead','2026-07-26',null,'Incomplete commissioning checklist; engineer retraining on template scheduled'),
    ('FSR-2026-0016','approval_delay','approver_unavailable','add_approver_backup','overdue',22.0,'Service Head - South','2026-07-19',null,'Slow approval due to approver unavailability; CAPA overdue, backup pending')
  ) as q(rn, fc, rc, ca, cst, lag, own, tcd, acd, nt)
  join public.report_turnaround_r3512 e
    on e.organization_id = v_org_id and e.report_number = q.rn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Report-status distribution
create or replace function public.founder_r3512_report_status_rollup()
returns table(report_status text, reports bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.report_turnaround_r3512)
  select l.report_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.report_turnaround_r3512 l
  group by l.report_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3512_report_status_rollup() from public, anon;
grant execute on function public.founder_r3512_report_status_rollup() to authenticated;

-- 2) Engineer turnaround scorecard
create or replace function public.founder_r3512_engineer_scorecard()
returns table(
  engineer_name text,
  total_reports bigint,
  submitted bigint,
  approved bigint,
  returned bigint,
  pending bigint,
  sla_breaches bigint,
  avg_submission_lag_hours numeric,
  avg_approval_lag_hours numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.report_status in ('submitted','under_review'))::bigint,
    count(*) filter (where l.report_status = 'approved')::bigint,
    count(*) filter (where l.report_status = 'returned')::bigint,
    count(*) filter (where l.report_status = 'pending_submission')::bigint,
    count(*) filter (where l.sla_breached = true)::bigint,
    round(avg(l.submission_lag_hours), 1),
    round(avg(l.approval_lag_hours), 1),
    round(100.0 * count(*) filter (where l.sla_breached = false)::numeric / nullif(count(*),0), 1)
  from public.report_turnaround_r3512 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3512_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3512_engineer_scorecard() to authenticated;

-- 3) Service-type × report-status matrix
create or replace function public.founder_r3512_service_type_status_matrix()
returns table(service_type text, report_status text, reports bigint, sla_breaches bigint, avg_submission_lag_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_type, l.report_status, count(*)::bigint,
    count(*) filter (where l.sla_breached = true)::bigint,
    round(avg(l.submission_lag_hours), 1)
  from public.report_turnaround_r3512 l
  group by l.service_type, l.report_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3512_service_type_status_matrix() from public, anon;
grant execute on function public.founder_r3512_service_type_status_matrix() to authenticated;

-- 4) Monthly submission-lag trend
create or replace function public.founder_r3512_monthly_submission_lag_trend()
returns table(
  submission_month date,
  reports bigint,
  avg_submission_lag_hours numeric,
  avg_approval_lag_hours numeric,
  sla_breaches bigint,
  backlog bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.job_completed_date)::date,
    count(*)::bigint,
    round(avg(l.submission_lag_hours), 1),
    round(avg(l.approval_lag_hours), 1),
    count(*) filter (where l.sla_breached = true)::bigint,
    count(*) filter (where l.backlog_flag = true)::bigint
  from public.report_turnaround_r3512 l
  group by date_trunc('month', l.job_completed_date)
  order by date_trunc('month', l.job_completed_date) desc;
end;
$$;

revoke execute on function public.founder_r3512_monthly_submission_lag_trend() from public, anon;
grant execute on function public.founder_r3512_monthly_submission_lag_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3512_capa_status_board()
returns table(capa_status text, findings bigint, avg_lag_impact_hours numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.lag_impact_hours), 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.report_turnaround_capa_actions_r3512 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3512_capa_status_board() from public, anon;
grant execute on function public.founder_r3512_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3512_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_lag_impact_hours numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.report_turnaround_capa_actions_r3512)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.lag_impact_hours),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.report_turnaround_capa_actions_r3512 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3512_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3512_root_cause_pareto() to authenticated;

-- 7) Lag-impact digest (by finding category)
create or replace function public.founder_r3512_lag_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_lag_impact_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.lag_impact_hours),0)::numeric
  from public.report_turnaround_capa_actions_r3512 c
  group by c.finding_category
  order by coalesce(sum(c.lag_impact_hours),0) desc;
end;
$$;

revoke execute on function public.founder_r3512_lag_impact_digest() from public, anon;
grant execute on function public.founder_r3512_lag_impact_digest() to authenticated;

-- 8) High-risk queue (pending / returned / under-review / SLA-breached / backlog)
create or replace function public.founder_r3512_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  report_number text,
  service_type text,
  job_completed_date date,
  report_status text,
  submission_lag_hours numeric,
  sla_hours int,
  sla_breached boolean,
  backlog_flag boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.report_number, l.service_type, l.job_completed_date,
    l.report_status, l.submission_lag_hours, l.sla_hours, l.sla_breached, l.backlog_flag, l.notes
  from public.report_turnaround_r3512 l
  where l.report_status in ('pending_submission','returned','under_review')
     or l.sla_breached = true
     or l.backlog_flag = true
  order by l.sla_breached desc, l.job_completed_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3512_high_risk_queue() from public, anon;
grant execute on function public.founder_r3512_high_risk_queue() to authenticated;
