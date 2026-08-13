-- Round 3720: Founder Internal IT Service-Desk Employee Ticket SLA Board
-- INTERNAL employee IT support tickets (hardware, access provisioning, software/app, network
-- connectivity, security incidents) -- SLA, first-response time, resolution time, repeat-ticket
-- rate. Distinct from any CUSTOMER/ENGINEER-FACING support-helpdesk-ticket-SLA-CSAT page -- this
-- ship is purely internal/employee-facing IT support.

-- =============================================================================
-- TABLE 1: it_svcdesk_r3720 -- per-department/month internal IT service-desk ticket log
-- =============================================================================
create table if not exists public.it_svcdesk_r3720 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  ticket_ref text not null,
  department text not null,
  period_month date not null,
  tickets_raised int not null,
  tickets_resolved int not null,
  avg_first_response_hours numeric,
  avg_resolution_hours numeric,
  sla_breaches int,
  repeat_tickets int,
  escalated_to_vendor int,
  csat_score numeric,
  issue_class text not null check (issue_class in (
    'hardware','access_provisioning','software_app','network_connectivity','security_incident'
  )),
  ticket_status text not null check (ticket_status in (
    'resolved_within_sla','resolved_late','open_within_sla','open_breached','escalated'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.it_svcdesk_r3720 enable row level security;

create index if not exists idx_it_svcdesk_r3720_org on public.it_svcdesk_r3720(organization_id);
create index if not exists idx_it_svcdesk_r3720_period on public.it_svcdesk_r3720(period_month);
create index if not exists idx_it_svcdesk_r3720_status on public.it_svcdesk_r3720(ticket_status);

-- =============================================================================
-- TABLE 2: it_svcdesk_capa_actions_r3720 -- CAPA & corrective actions
-- =============================================================================
create table if not exists public.it_svcdesk_capa_actions_r3720 (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid references public.it_svcdesk_r3720(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in (
    'open','in_progress','closed','overdue'
  )),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.it_svcdesk_capa_actions_r3720 enable row level security;

create index if not exists idx_it_svcdesk_capa_actions_r3720_ticket on public.it_svcdesk_capa_actions_r3720(ticket_id);
create index if not exists idx_it_svcdesk_capa_actions_r3720_status on public.it_svcdesk_capa_actions_r3720(capa_status);

-- =============================================================================
-- SEED DATA -- reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 internal IT service-desk rows
  insert into public.it_svcdesk_r3720 (
    organization_id, ticket_ref, department, period_month, tickets_raised, tickets_resolved,
    avg_first_response_hours, avg_resolution_hours, sla_breaches, repeat_tickets,
    escalated_to_vendor, csat_score, issue_class, ticket_status, trend_dir, notes
  )
  select v_org_id, q.tref, q.dept, q.pmonth::date, q.raised, q.resolved,
    q.fresp::numeric, q.res::numeric, q.breach, q.rpt, q.esc, q.csat::numeric,
    q.iclass, q.tstat, q.trend, q.nt
  from (values
    ('ITSD-2026-07-001','Field Service','2026-07-01',42,38,1.5,6.2,3,4,1,4.2,
     'hardware','resolved_within_sla','stable',
     'Laptop and biomedical-tablet break/fix requests for field engineers -- steady volume.'),
    ('ITSD-2026-07-002','Sales','2026-07-01',35,29,2.1,9.8,6,5,0,3.6,
     'access_provisioning','resolved_late','worsening',
     'New-hire CRM and VPN access provisioning delayed due to manager approval backlog.'),
    ('ITSD-2026-07-003','Finance','2026-07-01',18,17,0.9,4.1,1,1,0,4.5,
     'software_app','resolved_within_sla','improving',
     'ERP and Tally licensing requests resolved promptly this cycle.'),
    ('ITSD-2026-07-004','Service Ops','2026-07-01',51,40,3.4,14.6,11,9,2,3.1,
     'network_connectivity','open_breached','worsening',
     'Branch office WAN link flapping causing repeated connectivity tickets and SLA breaches.'),
    ('ITSD-2026-07-005','HR','2026-07-01',12,12,1.2,3.5,0,0,0,4.7,
     'access_provisioning','resolved_within_sla','stable',
     'Onboarding and offboarding access changes handled within SLA all month.'),
    ('ITSD-2026-07-006','Security','2026-07-01',9,6,0.6,11.2,2,1,1,3.8,
     'security_incident','escalated','worsening',
     'Phishing-click incidents on employee mailboxes escalated to security vendor for forensics.'),
    ('ITSD-2026-07-007','Warehouse','2026-07-01',27,24,2.8,8.4,4,3,0,3.9,
     'hardware','resolved_within_sla','stable',
     'Barcode-scanner and handheld-device repairs for spare-parts warehouse staff.'),
    ('ITSD-2026-07-008','Support','2026-07-01',31,22,1.9,12.7,7,6,1,3.2,
     'software_app','open_within_sla','worsening',
     'Helpdesk CRM plugin instability causing repeated software tickets, fix in progress.'),
    ('ITSD-2026-08-009','Field Service','2026-08-01',39,35,1.4,5.9,2,3,1,4.3,
     'hardware','resolved_within_sla','improving',
     'Continued steady hardware break/fix volume for field engineers, faster turnaround.'),
    ('ITSD-2026-08-010','Sales','2026-08-01',28,25,1.7,7.2,3,2,0,4.0,
     'access_provisioning','resolved_within_sla','improving',
     'Access-provisioning backlog cleared after approval-workflow automation went live.'),
    ('ITSD-2026-08-011','Finance','2026-08-01',15,10,2.2,10.4,4,2,0,3.4,
     'network_connectivity','open_breached','worsening',
     'Intermittent VPN drops for finance team working from branch offices.'),
    ('ITSD-2026-08-012','Service Ops','2026-08-01',48,44,2.6,9.1,5,7,1,3.7,
     'network_connectivity','resolved_late','stable',
     'Branch WAN link stabilised mid-month after ISP circuit replacement.'),
    ('ITSD-2026-08-013','HR','2026-08-01',10,9,1.0,4.8,1,0,0,4.4,
     'software_app','resolved_within_sla','stable',
     'HRMS leave-module access issues resolved within SLA.'),
    ('ITSD-2026-08-014','Security','2026-08-01',7,4,0.8,15.5,3,2,2,2.9,
     'security_incident','open_breached','worsening',
     'Suspicious login attempts on two employee accounts under active investigation.'),
    ('ITSD-2026-08-015','Warehouse','2026-08-01',23,21,2.3,6.6,2,1,0,4.1,
     'hardware','resolved_within_sla','stable',
     'Handheld scanner battery replacements and repairs completed on schedule.'),
    ('ITSD-2026-08-016','Support','2026-08-01',26,20,1.6,8.9,4,3,1,3.5,
     'software_app','escalated','stable',
     'Helpdesk CRM plugin vendor engaged after repeated instability tickets.')
  ) as q(tref, dept, pmonth, raised, resolved, fresp, res, breach, rpt, esc, csat, iclass, tstat, trend, nt);

  -- CAPA seed -- attach to specific tickets via ticket_ref
  insert into public.it_svcdesk_capa_actions_r3720 (
    ticket_id, root_cause, corrective_action, capa_status, owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('ITSD-2026-07-002','Manager approval workflow bottleneck','Automate access-provisioning approval chain','closed',
     'IT Ops Lead','2026-07-25','2026-07-24','Approval automation deployed; provisioning turnaround improved next cycle.'),
    ('ITSD-2026-07-004','Branch WAN circuit instability','Replace ISP circuit and add failover link','in_progress',
     'Network Team','2026-08-20',null,'Failover link ordered; ISP circuit replacement scheduled for mid-August.'),
    ('ITSD-2026-07-006','Employee phishing susceptibility','Mandatory security-awareness refresher training','open',
     'Security Team','2026-08-25',null,'Training module rollout planned org-wide after two mailbox compromises.'),
    ('ITSD-2026-07-008','Helpdesk CRM plugin instability','Engage vendor for plugin patch','overdue',
     'Support Systems','2026-08-05',null,'Vendor patch delayed past target date; escalation raised internally.'),
    ('ITSD-2026-08-011','VPN gateway capacity constraint','Upgrade VPN concentrator capacity','in_progress',
     'Network Team','2026-08-28',null,'Capacity upgrade order placed; interim QoS rules applied to reduce drops.'),
    ('ITSD-2026-08-014','Weak password reuse on employee accounts','Force password reset and enable MFA','open',
     'Security Team','2026-08-22',null,'Two accounts locked pending investigation; org-wide MFA rollout accelerated.'),
    ('ITSD-2026-08-016','Helpdesk CRM plugin instability','Vendor patch validation and rollback plan','in_progress',
     'Support Systems','2026-08-30',null,'Vendor provided beta patch; validating in staging before production rollout.'),
    ('ITSD-2026-07-004','Repeat connectivity tickets from same branch','Deploy monitoring probe at branch router','closed',
     'Network Team','2026-07-30','2026-07-29','Proactive monitoring probe deployed to catch flapping before user reports.')
  ) as q(tref, rc, ca, cst, own, tcd, acd, nt)
  join public.it_svcdesk_r3720 e
    on e.organization_id = v_org_id and e.ticket_ref = q.tref;
end;
$seed$;

-- =============================================================================
-- RPCs -- 8 founder-gated rollups
-- =============================================================================

-- 1) Ticket status distribution
create or replace function public.founder_r3720_ticket_status_rollup()
returns table(ticket_status text, tickets bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.it_svcdesk_r3720)
  select l.ticket_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.it_svcdesk_r3720 l
  group by l.ticket_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3720_ticket_status_rollup() from public, anon;
grant execute on function public.founder_r3720_ticket_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3720_department_scorecard()
returns table(
  department text,
  total_raised bigint,
  total_resolved bigint,
  avg_first_response_hours numeric,
  avg_resolution_hours numeric,
  total_sla_breaches bigint,
  total_repeat_tickets bigint,
  avg_csat_score numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    coalesce(sum(l.tickets_raised),0)::bigint,
    coalesce(sum(l.tickets_resolved),0)::bigint,
    round(avg(l.avg_first_response_hours), 1),
    round(avg(l.avg_resolution_hours), 1),
    coalesce(sum(l.sla_breaches),0)::bigint,
    coalesce(sum(l.repeat_tickets),0)::bigint,
    round(avg(l.csat_score), 1)
  from public.it_svcdesk_r3720 l
  group by l.department
  order by coalesce(sum(l.tickets_raised),0) desc;
end;
$$;

revoke execute on function public.founder_r3720_department_scorecard() from public, anon;
grant execute on function public.founder_r3720_department_scorecard() to authenticated;

-- 3) Issue class x ticket status matrix
create or replace function public.founder_r3720_issue_class_status_matrix()
returns table(issue_class text, ticket_status text, tickets bigint, avg_resolution_hours numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.issue_class, l.ticket_status, count(*)::bigint,
    round(avg(l.avg_resolution_hours), 1)
  from public.it_svcdesk_r3720 l
  group by l.issue_class, l.ticket_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3720_issue_class_status_matrix() from public, anon;
grant execute on function public.founder_r3720_issue_class_status_matrix() to authenticated;

-- 4) Monthly resolution trend
create or replace function public.founder_r3720_monthly_resolution_trend()
returns table(
  period_month date,
  tickets_raised bigint,
  tickets_resolved bigint,
  avg_resolution_hours numeric,
  sla_breaches bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    coalesce(sum(l.tickets_raised),0)::bigint,
    coalesce(sum(l.tickets_resolved),0)::bigint,
    round(avg(l.avg_resolution_hours), 1),
    coalesce(sum(l.sla_breaches),0)::bigint
  from public.it_svcdesk_r3720 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3720_monthly_resolution_trend() from public, anon;
grant execute on function public.founder_r3720_monthly_resolution_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3720_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.it_svcdesk_capa_actions_r3720 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3720_capa_status_board() from public, anon;
grant execute on function public.founder_r3720_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3720_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.it_svcdesk_capa_actions_r3720)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.it_svcdesk_capa_actions_r3720 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3720_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3720_root_cause_pareto() to authenticated;

-- 7) SLA breach digest
create or replace function public.founder_r3720_breach_digest()
returns table(
  issue_class text,
  breached_tickets bigint,
  total_sla_breaches bigint,
  avg_resolution_hours numeric,
  vendor_escalations bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.issue_class,
    count(*)::bigint,
    coalesce(sum(l.sla_breaches),0)::bigint,
    round(avg(l.avg_resolution_hours), 1),
    coalesce(sum(l.escalated_to_vendor),0)::bigint
  from public.it_svcdesk_r3720 l
  where l.ticket_status in ('open_breached','resolved_late','escalated')
  group by l.issue_class
  order by coalesce(sum(l.sla_breaches),0) desc;
end;
$$;

revoke execute on function public.founder_r3720_breach_digest() from public, anon;
grant execute on function public.founder_r3720_breach_digest() to authenticated;

-- 8) High-risk queue (open breached / escalated)
create or replace function public.founder_r3720_high_risk_queue()
returns table(
  ticket_ref text,
  department text,
  issue_class text,
  ticket_status text,
  period_month date,
  avg_resolution_hours numeric,
  sla_breaches int,
  csat_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ticket_ref, l.department, l.issue_class, l.ticket_status, l.period_month,
    l.avg_resolution_hours, l.sla_breaches, l.csat_score, l.notes
  from public.it_svcdesk_r3720 l
  where l.ticket_status in ('open_breached','escalated')
  order by l.period_month desc, l.avg_resolution_hours desc
  limit 20;
end;
$$;

revoke execute on function public.founder_r3720_high_risk_queue() from public, anon;
grant execute on function public.founder_r3720_high_risk_queue() to authenticated;
