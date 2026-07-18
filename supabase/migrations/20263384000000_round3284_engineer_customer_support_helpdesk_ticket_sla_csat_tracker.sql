-- Round 3284: Engineer / Ops Customer-Support Helpdesk Ticket SLA & CSAT Tracker
-- Service-desk QA — ticket channel × category × priority × first-response SLA × resolution SLA × reopen × field-escalation × CSAT × verdict + coaching/process CAPA

-- =============================================================================
-- TABLE 1: support_helpdesk_ticket_r3284 — individual support-desk tickets
-- =============================================================================
create table if not exists public.support_helpdesk_ticket_r3284 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  ticket_code text not null,
  hospital_name text not null,
  agent_name text not null,
  channel text not null check (channel in (
    'phone','email','whatsapp','portal','on_site_escalation'
  )),
  category text not null check (category in (
    'breakdown','calibration_request','consumable_order','warranty_query','complaint','info_request'
  )),
  priority text not null check (priority in (
    'p1_critical','p2_high','p3_normal','p4_low'
  )),
  created_date date not null,
  first_response_minutes int,
  resolution_hours numeric(6,2),
  sla_first_response_met boolean,
  sla_resolution_met boolean,
  reopened_count int not null default 0,
  escalated_to_field boolean not null default false,
  csat_score int check (csat_score is null or csat_score between 1 and 5),
  ticket_verdict text not null check (ticket_verdict in (
    'resolved_within_sla','resolved_breached_sla','open_on_track','open_overdue','escalated'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.support_helpdesk_ticket_r3284 enable row level security;

create index if not exists idx_support_helpdesk_ticket_r3284_org on public.support_helpdesk_ticket_r3284(organization_id);
create index if not exists idx_support_helpdesk_ticket_r3284_date on public.support_helpdesk_ticket_r3284(created_date);
create index if not exists idx_support_helpdesk_ticket_r3284_verdict on public.support_helpdesk_ticket_r3284(ticket_verdict);

-- =============================================================================
-- TABLE 2: support_helpdesk_ticket_capa_actions_r3284 — coaching / process CAPA
-- =============================================================================
create table if not exists public.support_helpdesk_ticket_capa_actions_r3284 (
  id uuid primary key default gen_random_uuid(),
  ticket_log_id uuid not null references public.support_helpdesk_ticket_r3284(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sla_first_response_breach','sla_resolution_breach','repeated_reopen','low_csat',
    'misrouted_ticket','escalation_delay','knowledge_gap'
  )),
  root_cause text not null check (root_cause in (
    'staffing_shortage','agent_training_gap','triage_misclassification','parts_delay',
    'vendor_dependency','system_downtime','unclear_customer_info','process_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'agent_coaching','update_triage_playbook','add_staffing','create_kb_article',
    'revise_sla_policy','faster_field_escalation','vendor_follow_up','root_cause_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  customer_impact text not null check (customer_impact in (
    'sla_credit_due','patient_care_delay','reputation_risk','contract_penalty_risk','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.support_helpdesk_ticket_capa_actions_r3284 enable row level security;

create index if not exists idx_support_helpdesk_capa_r3284_ticket on public.support_helpdesk_ticket_capa_actions_r3284(ticket_log_id);
create index if not exists idx_support_helpdesk_capa_r3284_status on public.support_helpdesk_ticket_capa_actions_r3284(capa_status);

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

  -- 14 support-ticket rows
  insert into public.support_helpdesk_ticket_r3284 (
    organization_id, ticket_code, hospital_name, agent_name, channel, category, priority,
    created_date, first_response_minutes, resolution_hours, sla_first_response_met,
    sla_resolution_met, reopened_count, escalated_to_field, csat_score, ticket_verdict, notes
  )
  select v_org_id, q.tc, q.hosp, q.agent, q.chan, q.cat, q.prio,
    q.cd::date, q.frm, q.rh, q.frmet,
    q.resmet, q.reopen, q.esc, q.csat, q.tv, q.nt
  from (values
    ('TKT-24001','Apollo Chennai','Priya Nair','phone','breakdown','p1_critical',
     '2026-07-16',6,3.50,true,true,0,true,5,'resolved_within_sla','Ventilator down in ICU — field engineer dispatched, resolved in 3.5h'),
    ('TKT-24002','Fortis Gurgaon','Rohit Sharma','whatsapp','breakdown','p1_critical',
     '2026-07-16',22,9.00,false,false,1,true,2,'resolved_breached_sla','Missed 15-min first-response SLA; reopened once after temp fix'),
    ('TKT-24003','Manipal Bengaluru','Anjali Menon','email','calibration_request','p3_normal',
     '2026-07-15',45,20.00,true,true,0,false,4,'resolved_within_sla','Calibration slot booked and completed within SLA'),
    ('TKT-24004','AIIMS Delhi','Karthik Reddy','portal','complaint','p2_high',
     '2026-07-15',90,48.00,false,false,2,true,1,'resolved_breached_sla','Repeated infusion-pump complaint; escalated to field, low CSAT'),
    ('TKT-24005','CMC Vellore','Sneha Iyer','phone','warranty_query','p4_low',
     '2026-07-14',30,6.00,true,true,0,false,5,'resolved_within_sla','Warranty coverage confirmed and communicated'),
    ('TKT-24006','KIMS Hyderabad','Vikram Singh','whatsapp','consumable_order','p3_normal',
     '2026-07-14',18,12.00,true,true,0,false,4,'resolved_within_sla','ECG electrode consumables dispatched same day'),
    ('TKT-24007','Apollo Chennai','Deepa Rao','on_site_escalation','breakdown','p1_critical',
     '2026-07-13',10,null,true,false,0,true,null,'open_overdue','Cath-lab table fault; spare part awaited, past 4h resolution SLA'),
    ('TKT-24008','Fortis Gurgaon','Arjun Pillai','email','info_request','p4_low',
     '2026-07-13',55,3.00,true,true,0,false,4,'resolved_within_sla','Service manual PDF shared with biomed team'),
    ('TKT-24009','Manipal Bengaluru','Fatima Sheikh','portal','breakdown','p2_high',
     '2026-07-12',40,null,false,false,1,true,null,'open_overdue','Autoclave door-seal leak; first-response SLA missed, still open past SLA'),
    ('TKT-24010','AIIMS Delhi','Priya Nair','phone','calibration_request','p3_normal',
     '2026-07-12',25,18.00,true,true,1,false,3,'resolved_within_sla','Reopened for paperwork correction, then closed within SLA'),
    ('TKT-24011','CMC Vellore','Rohit Sharma','whatsapp','complaint','p2_high',
     '2026-07-11',12,null,true,false,0,true,null,'escalated','Recurring patient-monitor fault escalated to field engineering'),
    ('TKT-24012','KIMS Hyderabad','Anjali Menon','email','consumable_order','p3_normal',
     '2026-07-11',60,30.00,false,true,0,false,3,'resolved_breached_sla','First-response SLA breached due to email-queue backlog'),
    ('TKT-24013','Yashoda Hyderabad','Karthik Reddy','phone','breakdown','p1_critical',
     '2026-07-10',8,null,true,true,0,false,null,'open_on_track','Dialysis machine alarm; within SLA, in progress on track'),
    ('TKT-24014','Rainbow Bengaluru','Sneha Iyer','portal','warranty_query','p4_low',
     '2026-07-10',120,40.00,false,true,0,false,2,'resolved_breached_sla','Portal ticket sat unassigned — late first response')
  ) as q(tc, hosp, agent, chan, cat, prio, cd, frm, rh, frmet, resmet, reopen, esc, csat, tv, nt);

  -- 7 CAPA / coaching action rows — attach to breached / reopened / low-CSAT tickets by ticket_code
  insert into public.support_helpdesk_ticket_capa_actions_r3284 (
    ticket_log_id, finding_category, root_cause, corrective_action,
    capa_status, customer_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TKT-24002','sla_first_response_breach','staffing_shortage','add_staffing','in_progress','sla_credit_due','2026-07-20',null,15000.00,'Night-shift WhatsApp queue understaffed — adding on-call agent'),
    ('TKT-24004','repeated_reopen','agent_training_gap','agent_coaching','open','patient_care_delay','2026-07-22',null,8000.00,'Infusion-pump complaint reopened twice — coaching on closure criteria'),
    ('TKT-24007','escalation_delay','parts_delay','faster_field_escalation','escalated','contract_penalty_risk','2026-07-19',null,42000.00,'Cath-lab table part delayed — expedite field dispatch, SLA-credit risk'),
    ('TKT-24009','sla_resolution_breach','vendor_dependency','vendor_follow_up','overdue','patient_care_delay','2026-07-15',null,12000.00,'Autoclave vendor SLA slipped — resolution past target closure'),
    ('TKT-24011','escalation_delay','process_gap','update_triage_playbook','verification_pending','reputation_risk','2026-07-18',null,5000.00,'Recurring monitor fault — added auto-escalation rule, verifying'),
    ('TKT-24012','sla_first_response_breach','staffing_shortage','revise_sla_policy','closed','internal_only','2026-07-16','2026-07-14',0.00,'Email backlog — SLA policy updated with triage window'),
    ('TKT-24014','misrouted_ticket','triage_misclassification','create_kb_article','closed','sla_credit_due','2026-07-15','2026-07-13',3500.00,'Portal warranty ticket misrouted — KB article and routing rule added')
  ) as q(tag, fc, rc, ca, cst, ci, tcd, acd, cost, nt)
  join public.support_helpdesk_ticket_r3284 e
    on e.organization_id = v_org_id and e.ticket_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Ticket verdict distribution
create or replace function public.founder_r3284_ticket_verdict_rollup()
returns table(ticket_verdict text, tickets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.support_helpdesk_ticket_r3284)
  select l.ticket_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.support_helpdesk_ticket_r3284 l
  group by l.ticket_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3284_ticket_verdict_rollup() from public, anon;
grant execute on function public.founder_r3284_ticket_verdict_rollup() to authenticated;

-- 2) Agent-level SLA & CSAT scorecard
create or replace function public.founder_r3284_agent_scorecard()
returns table(
  agent_name text,
  total_tickets bigint,
  within_sla bigint,
  breached bigint,
  fr_sla_met bigint,
  res_sla_met bigint,
  escalated bigint,
  avg_csat numeric,
  sla_met_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.agent_name,
    count(*)::bigint,
    count(*) filter (where l.ticket_verdict = 'resolved_within_sla')::bigint,
    count(*) filter (where l.ticket_verdict = 'resolved_breached_sla')::bigint,
    count(*) filter (where l.sla_first_response_met)::bigint,
    count(*) filter (where l.sla_resolution_met)::bigint,
    count(*) filter (where l.escalated_to_field)::bigint,
    round(avg(l.csat_score), 2),
    round(100.0 * count(*) filter (where l.sla_first_response_met and l.sla_resolution_met)::numeric / nullif(count(*),0), 1)
  from public.support_helpdesk_ticket_r3284 l
  group by l.agent_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3284_agent_scorecard() from public, anon;
grant execute on function public.founder_r3284_agent_scorecard() to authenticated;

-- 3) Channel × category matrix
create or replace function public.founder_r3284_channel_category_matrix()
returns table(channel text, category text, tickets bigint, within_sla bigint, avg_first_response_minutes numeric, avg_resolution_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.channel, l.category, count(*)::bigint,
    count(*) filter (where l.ticket_verdict = 'resolved_within_sla')::bigint,
    round(avg(l.first_response_minutes), 1),
    round(avg(l.resolution_hours), 1)
  from public.support_helpdesk_ticket_r3284 l
  group by l.channel, l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3284_channel_category_matrix() from public, anon;
grant execute on function public.founder_r3284_channel_category_matrix() to authenticated;

-- 4) Daily ticket SLA trend
create or replace function public.founder_r3284_daily_ticket_trend()
returns table(created_date date, tickets bigint, within_sla bigint, breached bigint, fr_breach bigint, escalated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.created_date,
    count(*)::bigint,
    count(*) filter (where l.ticket_verdict = 'resolved_within_sla')::bigint,
    count(*) filter (where l.ticket_verdict = 'resolved_breached_sla')::bigint,
    count(*) filter (where l.sla_first_response_met = false)::bigint,
    count(*) filter (where l.escalated_to_field)::bigint
  from public.support_helpdesk_ticket_r3284 l
  group by l.created_date
  order by l.created_date desc;
end;
$$;

revoke execute on function public.founder_r3284_daily_ticket_trend() from public, anon;
grant execute on function public.founder_r3284_daily_ticket_trend() to authenticated;

-- 5) CAPA / coaching action status board
create or replace function public.founder_r3284_capa_status_board()
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
  from public.support_helpdesk_ticket_capa_actions_r3284 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3284_capa_status_board() from public, anon;
grant execute on function public.founder_r3284_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3284_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.support_helpdesk_ticket_capa_actions_r3284)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.support_helpdesk_ticket_capa_actions_r3284 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3284_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3284_root_cause_pareto() to authenticated;

-- 7) Customer-impact / SLA-risk digest
create or replace function public.founder_r3284_customer_impact_digest()
returns table(customer_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.customer_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.support_helpdesk_ticket_capa_actions_r3284 c
  group by c.customer_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3284_customer_impact_digest() from public, anon;
grant execute on function public.founder_r3284_customer_impact_digest() to authenticated;

-- 8) High-risk ticket queue (SLA breaches, overdue, reopened, low CSAT)
create or replace function public.founder_r3284_high_risk_queue()
returns table(
  hospital_name text,
  ticket_code text,
  agent_name text,
  created_date date,
  channel text,
  category text,
  priority text,
  ticket_verdict text,
  reopened_count integer,
  csat_score integer,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ticket_code, l.agent_name, l.created_date,
    l.channel, l.category, l.priority, l.ticket_verdict,
    l.reopened_count, l.csat_score, l.notes
  from public.support_helpdesk_ticket_r3284 l
  where l.ticket_verdict in ('resolved_breached_sla','open_overdue','escalated')
     or l.sla_first_response_met = false
     or l.sla_resolution_met = false
     or l.reopened_count > 0
     or (l.csat_score is not null and l.csat_score <= 2)
  order by l.created_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3284_high_risk_queue() from public, anon;
grant execute on function public.founder_r3284_high_risk_queue() to authenticated;
