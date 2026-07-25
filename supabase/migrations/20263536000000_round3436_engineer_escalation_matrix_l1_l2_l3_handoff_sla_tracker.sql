-- Round 3436: Engineer Escalation-Matrix L1/L2/L3 Handoff & SLA Tracker
-- Support-ticket escalation matrix L1->L2->L3(->OEM) handoff + SLA adherence tracker —
-- engineer × ticket × hospital × current tier × escalation reason × escalated-from × handoff status ×
-- SLA hours × elapsed hours × breach × raised/resolved dates × CAPA closure

-- =============================================================================
-- TABLE 1: escalation_l1_l2_l3_sla_r3436 — per-ticket escalation handoff & SLA log
-- =============================================================================
create table if not exists public.escalation_l1_l2_l3_sla_r3436 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  ticket_code text not null,
  hospital_name text not null,
  current_tier text not null check (current_tier in (
    'l1','l2','l3','oem'
  )),
  escalation_reason text not null check (escalation_reason in (
    'complexity','parts_unavailable','warranty_oem','repeat_failure','sla_risk','customer_request'
  )),
  escalated_from text check (escalated_from in (
    'l1','l2','l3'
  )),
  handoff_status text not null check (handoff_status in (
    'open','accepted','in_progress','resolved','bounced_back'
  )),
  sla_hours int,
  elapsed_hours int,
  breached boolean not null,
  raised_date date not null,
  resolved_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.escalation_l1_l2_l3_sla_r3436 enable row level security;

create index if not exists idx_escalation_l1_l2_l3_sla_r3436_org on public.escalation_l1_l2_l3_sla_r3436(organization_id);
create index if not exists idx_escalation_l1_l2_l3_sla_r3436_date on public.escalation_l1_l2_l3_sla_r3436(raised_date);
create index if not exists idx_escalation_l1_l2_l3_sla_r3436_status on public.escalation_l1_l2_l3_sla_r3436(handoff_status);

-- =============================================================================
-- TABLE 2: escalation_l1_l2_l3_sla_capa_actions_r3436 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.escalation_l1_l2_l3_sla_capa_actions_r3436 (
  id uuid primary key default gen_random_uuid(),
  escalation_log_id uuid not null references public.escalation_l1_l2_l3_sla_r3436(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sla_breach','repeated_bounce_back','tier_skip','aging_ticket',
    'oem_handoff_delay','parts_delay','misrouted_escalation','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'knowledge_gap','parts_lead_time','oem_dependency','documentation_missing','diagnostic_delay',
    'staffing_shortage','tooling_unavailable','process_gap','vendor_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'l2_training','expedite_parts','oem_contract_review','update_knowledge_base','add_diagnostic_tooling',
    'staffing_reallocation','process_revision','escalation_matrix_update','vendor_sla_penalty','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  breach_severity text not null check (breach_severity in (
    'critical','major','moderate','minor','none'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.escalation_l1_l2_l3_sla_capa_actions_r3436 enable row level security;

create index if not exists idx_escalation_l1_l2_l3_sla_capa_r3436_log on public.escalation_l1_l2_l3_sla_capa_actions_r3436(escalation_log_id);
create index if not exists idx_escalation_l1_l2_l3_sla_capa_r3436_status on public.escalation_l1_l2_l3_sla_capa_actions_r3436(capa_status);

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

  -- 16 escalation ticket rows
  insert into public.escalation_l1_l2_l3_sla_r3436 (
    organization_id, engineer_name, ticket_code, hospital_name, current_tier,
    escalation_reason, escalated_from, handoff_status, sla_hours, elapsed_hours,
    breached, raised_date, resolved_date, notes
  )
  select v_org_id, q.eng, q.tc, q.hosp, q.ct,
    q.er, q.ef, q.hs, q.slah::int, q.elh::int,
    q.br, q.rd::date, q.resd::date, q.nt
  from (values
    ('Ravi Kumar','TKT-APL-1001','Apollo Chennai','l2','complexity','l1','resolved',24,18,
     false,'2026-07-03','2026-07-04','Ventilator control board fault escalated to L2, resolved within SLA'),
    ('Anil Sharma','TKT-APL-1002','Apollo Chennai','l3','repeat_failure','l2','in_progress',48,52,
     true,'2026-07-02',null,'Recurring CT gantry error escalated L2->L3, SLA breached awaiting spare'),
    ('Priya Nair','TKT-FRT-2001','Fortis Gurgaon','oem','warranty_oem','l3','open',72,80,
     true,'2026-06-30',null,'MRI cold-head under warranty handed to OEM, breach on OEM response'),
    ('Suresh Reddy','TKT-FRT-2002','Fortis Gurgaon','l2','parts_unavailable','l1','bounced_back',24,30,
     true,'2026-07-01',null,'Infusion pump escalation bounced back to L1 for missing serial numbers'),
    ('Deepak Menon','TKT-MNP-3001','Manipal Bengaluru','l1','sla_risk',null,'accepted',12,6,
     false,'2026-07-04',null,'Dialysis machine alarm — L1 accepted, SLA risk flagged proactively'),
    ('Kavya Iyer','TKT-MNP-3002','Manipal Bengaluru','l3','complexity','l2','resolved',48,40,
     false,'2026-06-29','2026-07-01','Cath-lab table drive fault resolved at L3 within SLA'),
    ('Manoj Gupta','TKT-AIM-4001','AIIMS Delhi','l2','customer_request','l1','in_progress',24,20,
     false,'2026-07-03',null,'Endoscopy tower escalated on customer request, L2 in progress'),
    ('Vijay Rao','TKT-AIM-4002','AIIMS Delhi','oem','warranty_oem','l3','bounced_back',72,96,
     true,'2026-06-27',null,'Linac interlock under OEM warranty bounced back, aging breach'),
    ('Ravi Kumar','TKT-CMC-5001','CMC Vellore','l2','complexity','l1','resolved',24,16,
     false,'2026-07-02','2026-07-03','Anaesthesia workstation fault resolved at L2 in SLA'),
    ('Anil Sharma','TKT-CMC-5002','CMC Vellore','l3','parts_unavailable','l2','open',48,60,
     true,'2026-06-28',null,'Ultrasound probe fault, spare unavailable, L3 open past SLA'),
    ('Priya Nair','TKT-KIM-6001','KIMS Hyderabad','l1','complexity',null,'accepted',12,4,
     false,'2026-07-05',null,'Patient monitor calibration query handled at L1'),
    ('Suresh Reddy','TKT-KIM-6002','KIMS Hyderabad','l2','sla_risk','l1','in_progress',24,22,
     false,'2026-07-04',null,'Ventilator flow-sensor drift, L2 nearing SLA window'),
    ('Deepak Menon','TKT-YSH-7001','Yashoda Hyderabad','l3','repeat_failure','l2','bounced_back',48,54,
     true,'2026-06-30',null,'Repeat C-arm image dropout bounced from L3, SLA breached'),
    ('Kavya Iyer','TKT-KKB-8001','Kokilaben Mumbai','oem','warranty_oem','l3','in_progress',72,68,
     false,'2026-07-01',null,'PET-CT detector warranty handoff to OEM, within SLA'),
    ('Manoj Gupta','TKT-NAR-9001','Narayana Bengaluru','l2','customer_request','l1','resolved',24,12,
     false,'2026-07-03','2026-07-03','Defibrillator battery escalated on request, resolved same day'),
    ('Vijay Rao','TKT-MED-9101','Medanta Gurgaon','l3','parts_unavailable','l2','open',48,66,
     true,'2026-06-26',null,'Dialysis RO plant control board, spare on order, SLA breached')
  ) as q(eng, tc, hosp, ct, er, ef, hs, slah, elh, br, rd, resd, nt);

  -- CAPA seed — attach to specific tickets via ticket_code
  insert into public.escalation_l1_l2_l3_sla_capa_actions_r3436 (
    escalation_log_id, finding_category, root_cause, corrective_action,
    capa_status, breach_severity, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.sev, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TKT-APL-1002','aging_ticket','parts_lead_time','expedite_parts','in_progress','major','Anil Sharma','2026-07-08',null,18000.00,'CT gantry spare expedited; awaiting delivery to clear L3 breach'),
    ('TKT-FRT-2001','oem_handoff_delay','oem_dependency','oem_contract_review','open','critical','Priya Nair','2026-07-07',null,0.00,'MRI OEM SLA breach — escalating warranty contract review with vendor'),
    ('TKT-FRT-2002','repeated_bounce_back','documentation_missing','update_knowledge_base','verification_pending','moderate','Suresh Reddy','2026-07-06',null,2500.00,'Handoff checklist updated to prevent serial-number bounce-backs'),
    ('TKT-AIM-4002','sla_breach','oem_dependency','vendor_sla_penalty','escalated','critical','Vijay Rao','2026-07-05',null,45000.00,'Linac OEM warranty breach — invoking SLA penalty clause'),
    ('TKT-CMC-5002','parts_delay','parts_lead_time','expedite_parts','open','major','Anil Sharma','2026-07-04',null,12000.00,'Ultrasound probe spare on order; interim loaner arranged'),
    ('TKT-YSH-7001','repeated_bounce_back','knowledge_gap','l2_training','closed','moderate','Deepak Menon','2026-07-03','2026-07-05',6000.00,'L2 trained on C-arm image-chain diagnostics; bounce-back closed'),
    ('TKT-MED-9101','aging_ticket','vendor_delay','vendor_sla_penalty','overdue','major','Vijay Rao','2026-06-30',null,15000.00,'RO control board vendor past due — penalty and re-source in progress'),
    ('TKT-KIM-6002','misrouted_escalation','process_gap','escalation_matrix_update','open','minor','Suresh Reddy','2026-07-07',null,0.00,'Escalation matrix updated to route flow-sensor issues to correct tier')
  ) as q(tc, fc, rc, ca, cst, sev, ownr, tcd, acd, cost, nt)
  join public.escalation_l1_l2_l3_sla_r3436 e
    on e.organization_id = v_org_id and e.ticket_code = q.tc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Handoff-status distribution
create or replace function public.founder_r3436_handoff_status_rollup()
returns table(handoff_status text, tickets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.escalation_l1_l2_l3_sla_r3436)
  select l.handoff_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.escalation_l1_l2_l3_sla_r3436 l
  group by l.handoff_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3436_handoff_status_rollup() from public, anon;
grant execute on function public.founder_r3436_handoff_status_rollup() to authenticated;

-- 2) Tier scorecard
create or replace function public.founder_r3436_tier_scorecard()
returns table(
  current_tier text,
  total_tickets bigint,
  resolved bigint,
  open_tickets bigint,
  bounced bigint,
  breached bigint,
  avg_elapsed_hours numeric,
  breach_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.current_tier,
    count(*)::bigint,
    count(*) filter (where l.handoff_status = 'resolved')::bigint,
    count(*) filter (where l.handoff_status in ('open','accepted','in_progress'))::bigint,
    count(*) filter (where l.handoff_status = 'bounced_back')::bigint,
    count(*) filter (where l.breached)::bigint,
    round(avg(l.elapsed_hours), 1),
    round(100.0 * count(*) filter (where l.breached)::numeric / nullif(count(*),0), 1)
  from public.escalation_l1_l2_l3_sla_r3436 l
  group by l.current_tier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3436_tier_scorecard() from public, anon;
grant execute on function public.founder_r3436_tier_scorecard() to authenticated;

-- 3) Tier × escalation-reason matrix
create or replace function public.founder_r3436_tier_reason_matrix()
returns table(current_tier text, escalation_reason text, tickets bigint, resolved bigint, breached bigint, avg_elapsed_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.current_tier, l.escalation_reason, count(*)::bigint,
    count(*) filter (where l.handoff_status = 'resolved')::bigint,
    count(*) filter (where l.breached)::bigint,
    round(avg(l.elapsed_hours), 1)
  from public.escalation_l1_l2_l3_sla_r3436 l
  group by l.current_tier, l.escalation_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3436_tier_reason_matrix() from public, anon;
grant execute on function public.founder_r3436_tier_reason_matrix() to authenticated;

-- 4) Monthly escalation trend
create or replace function public.founder_r3436_monthly_escalation_trend()
returns table(escalation_month text, tickets bigint, resolved bigint, breached bigint, bounced bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.raised_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.handoff_status = 'resolved')::bigint,
    count(*) filter (where l.breached)::bigint,
    count(*) filter (where l.handoff_status = 'bounced_back')::bigint
  from public.escalation_l1_l2_l3_sla_r3436 l
  group by to_char(l.raised_date, 'YYYY-MM')
  order by to_char(l.raised_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3436_monthly_escalation_trend() from public, anon;
grant execute on function public.founder_r3436_monthly_escalation_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3436_capa_status_board()
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
  from public.escalation_l1_l2_l3_sla_capa_actions_r3436 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3436_capa_status_board() from public, anon;
grant execute on function public.founder_r3436_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3436_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.escalation_l1_l2_l3_sla_capa_actions_r3436)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.escalation_l1_l2_l3_sla_capa_actions_r3436 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3436_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3436_root_cause_pareto() to authenticated;

-- 7) SLA-breach impact digest (by breach severity)
create or replace function public.founder_r3436_sla_breach_impact_digest()
returns table(breach_severity text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.breach_severity, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.escalation_l1_l2_l3_sla_capa_actions_r3436 c
  group by c.breach_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3436_sla_breach_impact_digest() from public, anon;
grant execute on function public.founder_r3436_sla_breach_impact_digest() to authenticated;

-- 8) High-risk escalation queue (breached / aging / bounced)
create or replace function public.founder_r3436_high_risk_queue()
returns table(
  hospital_name text,
  ticket_code text,
  engineer_name text,
  current_tier text,
  escalation_reason text,
  handoff_status text,
  sla_hours int,
  elapsed_hours int,
  breached boolean,
  raised_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ticket_code, l.engineer_name, l.current_tier,
    l.escalation_reason, l.handoff_status, l.sla_hours, l.elapsed_hours,
    l.breached, l.raised_date, l.notes
  from public.escalation_l1_l2_l3_sla_r3436 l
  where l.breached
     or l.handoff_status = 'bounced_back'
     or l.handoff_status in ('open','accepted','in_progress')
     or l.elapsed_hours > l.sla_hours
     or l.current_tier = 'oem'
  order by l.breached desc, l.elapsed_hours desc, l.raised_date desc;
end;
$$;

revoke execute on function public.founder_r3436_high_risk_queue() from public, anon;
grant execute on function public.founder_r3436_high_risk_queue() to authenticated;
