-- Round 3548: Engineer Service-Ticket Reopen / Reclosure Quality Tracker
-- First-close quality & reopen analytics — reopen reason × first-close quality × reclosure status × days-to-reopen × repeat-reopen × CAPA closure

-- =============================================================================
-- TABLE 1: ticket_reopen_r3548 — per-ticket reopen / reclosure quality records
-- =============================================================================
create table if not exists public.ticket_reopen_r3548 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  ticket_code text not null,
  device_model text not null,
  reopen_reason text not null check (reopen_reason in (
    'issue_recurred','incomplete_fix','wrong_diagnosis','customer_dissatisfied','part_failed','documentation'
  )),
  reopen_count int not null,
  days_to_reopen int not null,
  original_close_date date not null,
  reopen_date date not null,
  reclosure_status text not null check (reclosure_status in (
    'permanently_closed','reopened_again','escalated','pending','root_caused'
  )),
  first_close_quality text not null check (first_close_quality in (
    'good','marginal','poor'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ticket_reopen_r3548 enable row level security;

create index if not exists idx_ticket_reopen_r3548_org on public.ticket_reopen_r3548(organization_id);
create index if not exists idx_ticket_reopen_r3548_date on public.ticket_reopen_r3548(reopen_date);
create index if not exists idx_ticket_reopen_r3548_status on public.ticket_reopen_r3548(reclosure_status);

-- =============================================================================
-- TABLE 2: ticket_reopen_capa_actions_r3548 — CAPA & quality actions
-- =============================================================================
create table if not exists public.ticket_reopen_capa_actions_r3548 (
  id uuid primary key default gen_random_uuid(),
  ticket_log_id uuid not null references public.ticket_reopen_r3548(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'repeat_reopen','fix_did_not_hold','misdiagnosis','poor_documentation',
    'part_defect','customer_escalation','sla_breach','pending_root_cause'
  )),
  root_cause text not null check (root_cause in (
    'incomplete_repair','wrong_part_used','diagnostic_error','skill_gap','defective_spare',
    'no_functional_test','poor_handover_notes','pending_investigation','intermittent_fault','environmental_factor'
  )),
  corrective_action text not null check (corrective_action in (
    'redo_repair','replace_part','senior_reassignment','engineer_retraining','add_functional_test',
    'improve_documentation','rca_and_permanent_fix','escalate_to_oem','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_severity text not null check (impact_severity in (
    'low','medium','high','critical'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  rework_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ticket_reopen_capa_actions_r3548 enable row level security;

create index if not exists idx_ticket_reopen_capa_r3548_log on public.ticket_reopen_capa_actions_r3548(ticket_log_id);
create index if not exists idx_ticket_reopen_capa_r3548_status on public.ticket_reopen_capa_actions_r3548(capa_status);

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

  -- 16 ticket reopen rows
  insert into public.ticket_reopen_r3548 (
    organization_id, engineer_name, hospital_name, ticket_code, device_model,
    reopen_reason, reopen_count, days_to_reopen, original_close_date, reopen_date,
    reclosure_status, first_close_quality, notes
  )
  select v_org_id, q.eng, q.hosp, q.tcode, q.model,
    q.reason, q.rcount, q.days, q.ocd::date, q.rd::date,
    q.rstat, q.fcq, q.nt
  from (values
    ('Ramesh Kumar','Apollo Chennai','TKT-APL-1001','GE Vivid S60 Ultrasound','incomplete_fix',1,4,'2026-06-20','2026-06-24','permanently_closed','marginal','Probe re-seated; permanently closed after second visit'),
    ('Ramesh Kumar','Apollo Chennai','TKT-APL-1002','Mindray BeneVision N22','issue_recurred',2,9,'2026-06-15','2026-06-24','reopened_again','poor','Same alarm fault recurred twice — needs RCA'),
    ('Suresh Iyer','Fortis Gurgaon','TKT-FRT-2001','Philips MX550 Monitor','wrong_diagnosis',1,3,'2026-06-22','2026-06-25','root_caused','marginal','Initial diagnosis wrong; root-caused to power module'),
    ('Suresh Iyer','Fortis Gurgaon','TKT-FRT-2002','Drager Fabius GS Anesthesia','part_failed',1,6,'2026-06-18','2026-06-24','permanently_closed','good','Flow sensor replaced; held on recheck'),
    ('Anita Desai','Manipal Bengaluru','TKT-MNP-3001','Siemens Acuson X300','issue_recurred',3,12,'2026-06-10','2026-06-22','escalated','poor','Third reopen — escalated to OEM'),
    ('Anita Desai','Manipal Bengaluru','TKT-MNP-3002','Nihon Kohden BSM-6000','documentation',1,2,'2026-06-24','2026-06-26','permanently_closed','marginal','Reopened due to missing service report; docs completed'),
    ('Vikram Singh','AIIMS Delhi','TKT-AIM-4001','GE Carescape B650','customer_dissatisfied',1,5,'2026-06-19','2026-06-24','pending','marginal','Customer unhappy with response time; awaiting review'),
    ('Vikram Singh','AIIMS Delhi','TKT-AIM-4002','Maquet Servo-i Ventilator','incomplete_fix',2,8,'2026-06-12','2026-06-20','reopened_again','poor','Expiratory valve issue not fully resolved'),
    ('Priya Menon','CMC Vellore','TKT-CMC-5001','Fresenius 4008S Dialysis','part_failed',1,4,'2026-06-21','2026-06-25','permanently_closed','good','Conductivity cell replaced; closed clean'),
    ('Priya Menon','CMC Vellore','TKT-CMC-5002','Philips HeartStart XL','wrong_diagnosis',2,10,'2026-06-11','2026-06-21','escalated','poor','Battery vs board misdiagnosis; escalated'),
    ('Karthik Rao','KIMS Hyderabad','TKT-KIM-6001','Mindray DC-70 Ultrasound','issue_recurred',1,7,'2026-06-17','2026-06-24','root_caused','marginal','Image freeze recurred; root cause board fault'),
    ('Karthik Rao','KIMS Hyderabad','TKT-KIM-6002','Trivitron X-Ray DR','documentation',1,3,'2026-06-23','2026-06-26','permanently_closed','good','Reopened for calibration record; completed'),
    ('Deepa Nair','Yashoda Hyderabad','TKT-YSH-7001','GE Datex Ohmeda Aisys','incomplete_fix',1,5,'2026-06-20','2026-06-25','pending','marginal','Vaporizer leak partially fixed; recheck pending'),
    ('Deepa Nair','Yashoda Hyderabad','TKT-YSH-7002','Skanray Star 55 Monitor','part_failed',2,11,'2026-06-09','2026-06-20','reopened_again','poor','SpO2 board replaced twice — defective spares suspected'),
    ('Mohan Pillai','Kokilaben Mumbai','TKT-KKB-8001','Siemens Somatom CT','customer_dissatisfied',1,6,'2026-06-16','2026-06-22','escalated','poor','Downtime complaint; escalated to service head'),
    ('Mohan Pillai','Kokilaben Mumbai','TKT-KKB-8002','Roche Cobas c311 Analyzer','issue_recurred',1,4,'2026-06-22','2026-06-26','permanently_closed','good','Pipettor recalibrated; held on recheck')
  ) as q(eng, hosp, tcode, model, reason, rcount, days, ocd, rd, rstat, fcq, nt);

  -- CAPA seed — attach to specific tickets via ticket_code
  insert into public.ticket_reopen_capa_actions_r3548 (
    ticket_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_severity, owner, target_closure_date, actual_closure_date,
    rework_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.sev, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TKT-APL-1002','repeat_reopen','intermittent_fault','rca_and_permanent_fix','in_progress','high','Ramesh Kumar','2026-07-05',null,18000.00,'Recurrent alarm fault — RCA in progress'),
    ('TKT-MNP-3001','customer_escalation','defective_spare','escalate_to_oem','escalated','critical','Anita Desai','2026-07-03',null,42000.00,'Third reopen escalated to OEM for board replacement'),
    ('TKT-AIM-4002','fix_did_not_hold','incomplete_repair','redo_repair','open','high','Vikram Singh','2026-07-06',null,15500.00,'Expiratory valve rework scheduled'),
    ('TKT-CMC-5002','misdiagnosis','diagnostic_error','engineer_retraining','verification_pending','medium','Priya Menon','2026-07-04',null,6000.00,'Retraining on battery vs board diagnostics'),
    ('TKT-YSH-7002','part_defect','defective_spare','replace_part','closed','high','Deepa Nair','2026-07-02','2026-06-27',22000.00,'Defective SpO2 boards returned; new lot fitted'),
    ('TKT-KKB-8001','customer_escalation','skill_gap','senior_reassignment','escalated','critical','Mohan Pillai','2026-07-03',null,28000.00,'CT downtime escalated; senior engineer reassigned'),
    ('TKT-FRT-2001','pending_root_cause','pending_investigation','rca_and_permanent_fix','open','medium','Suresh Iyer','2026-07-07',null,9000.00,'Power module RCA pending'),
    ('TKT-KIM-6001','fix_did_not_hold','no_functional_test','add_functional_test','overdue','medium','Karthik Rao','2026-06-30',null,7500.00,'Add post-repair functional test to close-out')
  ) as q(tcode, fc, rc, ca, cst, sev, own, tcd, acd, cost, nt)
  join public.ticket_reopen_r3548 e
    on e.organization_id = v_org_id and e.ticket_code = q.tcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reclosure status distribution
create or replace function public.founder_r3548_reclosure_status_rollup()
returns table(reclosure_status text, tickets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ticket_reopen_r3548)
  select l.reclosure_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ticket_reopen_r3548 l
  group by l.reclosure_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3548_reclosure_status_rollup() from public, anon;
grant execute on function public.founder_r3548_reclosure_status_rollup() to authenticated;

-- 2) Engineer first-close quality scorecard
create or replace function public.founder_r3548_engineer_scorecard()
returns table(
  engineer_name text,
  total_tickets bigint,
  permanently_closed bigint,
  reopened_again bigint,
  escalated bigint,
  poor_quality bigint,
  repeat_reopens bigint,
  avg_days_to_reopen numeric,
  good_close_pct numeric
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
    count(*) filter (where l.reclosure_status = 'permanently_closed')::bigint,
    count(*) filter (where l.reclosure_status = 'reopened_again')::bigint,
    count(*) filter (where l.reclosure_status = 'escalated')::bigint,
    count(*) filter (where l.first_close_quality = 'poor')::bigint,
    count(*) filter (where l.reopen_count > 1)::bigint,
    round(avg(l.days_to_reopen), 1),
    round(100.0 * count(*) filter (where l.first_close_quality = 'good')::numeric / nullif(count(*),0), 1)
  from public.ticket_reopen_r3548 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3548_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3548_engineer_scorecard() to authenticated;

-- 3) Reopen reason × first-close quality matrix
create or replace function public.founder_r3548_reason_quality_matrix()
returns table(reopen_reason text, first_close_quality text, tickets bigint, reopened_again bigint, avg_days_to_reopen numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.reopen_reason, l.first_close_quality, count(*)::bigint,
    count(*) filter (where l.reclosure_status = 'reopened_again')::bigint,
    round(avg(l.days_to_reopen), 1)
  from public.ticket_reopen_r3548 l
  group by l.reopen_reason, l.first_close_quality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3548_reason_quality_matrix() from public, anon;
grant execute on function public.founder_r3548_reason_quality_matrix() to authenticated;

-- 4) Monthly reopen trend
create or replace function public.founder_r3548_monthly_reopen_trend()
returns table(reopen_month date, tickets bigint, reopened_again bigint, escalated bigint, poor_quality bigint, avg_days_to_reopen numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.reopen_date)::date,
    count(*)::bigint,
    count(*) filter (where l.reclosure_status = 'reopened_again')::bigint,
    count(*) filter (where l.reclosure_status = 'escalated')::bigint,
    count(*) filter (where l.first_close_quality = 'poor')::bigint,
    round(avg(l.days_to_reopen), 1)
  from public.ticket_reopen_r3548 l
  group by date_trunc('month', l.reopen_date)
  order by date_trunc('month', l.reopen_date) desc;
end;
$$;

revoke execute on function public.founder_r3548_monthly_reopen_trend() from public, anon;
grant execute on function public.founder_r3548_monthly_reopen_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3548_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.rework_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ticket_reopen_capa_actions_r3548 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3548_capa_status_board() from public, anon;
grant execute on function public.founder_r3548_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3548_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ticket_reopen_capa_actions_r3548)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.rework_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ticket_reopen_capa_actions_r3548 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3548_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3548_root_cause_pareto() to authenticated;

-- 7) Reopen impact digest (by severity)
create or replace function public.founder_r3548_reopen_impact_digest()
returns table(impact_severity text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_severity, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.rework_cost_rupees),0)::numeric
  from public.ticket_reopen_capa_actions_r3548 c
  group by c.impact_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3548_reopen_impact_digest() from public, anon;
grant execute on function public.founder_r3548_reopen_impact_digest() to authenticated;

-- 8) High-risk reclosure queue
create or replace function public.founder_r3548_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  ticket_code text,
  device_model text,
  reopen_reason text,
  reopen_count int,
  days_to_reopen int,
  reclosure_status text,
  first_close_quality text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.ticket_code, l.device_model,
    l.reopen_reason, l.reopen_count, l.days_to_reopen,
    l.reclosure_status, l.first_close_quality, l.notes
  from public.ticket_reopen_r3548 l
  where l.reclosure_status in ('reopened_again','escalated')
     or l.first_close_quality = 'poor'
     or l.reopen_count > 1
     or l.reclosure_status = 'pending'
  order by l.reopen_count desc, l.days_to_reopen desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3548_high_risk_queue() from public, anon;
grant execute on function public.founder_r3548_high_risk_queue() to authenticated;
