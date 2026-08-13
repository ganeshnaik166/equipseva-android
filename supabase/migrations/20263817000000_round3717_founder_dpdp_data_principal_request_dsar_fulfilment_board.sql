-- Round 3717: Founder DPDP Data-Principal Request (DSAR) Fulfilment Board
-- DPDP data-principal request (access/correction/erasure/nominee/grievance) fulfilment SLA per request
-- (request-handling ops; NOT the consent/breach-readiness register) — requester type × request class ×
-- fulfilment status × days-to-fulfil × identity verification × DPO escalation × CAPA

-- =============================================================================
-- TABLE 1: dsar_r3717 — per-request DPDP data-principal request fulfilment log
-- =============================================================================
create table if not exists public.dsar_r3717 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  request_ref text not null,
  requester_type text not null check (requester_type in (
    'customer','employee','ex_employee','vendor_partner','job_applicant'
  )),
  period_month date not null,
  request_date date not null,
  statutory_due_date date not null,
  fulfilled_date date,
  days_to_fulfil int,
  within_sla boolean not null,
  identity_verified boolean not null,
  records_systems_touched int,
  partial_fulfilment boolean not null,
  escalated_to_dpo boolean not null,
  request_class text not null check (request_class in (
    'access_copy','correction','erasure','nominee_exercise','grievance'
  )),
  fulfilment_status text not null check (fulfilment_status in (
    'fulfilled_on_time','fulfilled_late','in_progress','overdue','rejected_documented'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dsar_r3717 enable row level security;

create index if not exists idx_dsar_r3717_org on public.dsar_r3717(organization_id);
create index if not exists idx_dsar_r3717_request_date on public.dsar_r3717(request_date);
create index if not exists idx_dsar_r3717_status on public.dsar_r3717(fulfilment_status);

-- =============================================================================
-- TABLE 2: dsar_capa_actions_r3717 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dsar_capa_actions_r3717 (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.dsar_r3717(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'process_delay_internal','identity_verification_pending','system_data_retrieval_delay',
    'legal_review_required','third_party_data_processor_delay','requester_non_response',
    'complex_multi_system_request','staff_training_gap','backlog_volume_surge','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_processing','escalate_to_dpo','engage_third_party_processor','conduct_identity_reverification',
    'legal_review_completion','staff_retraining','process_automation_upgrade','close_with_documented_reason',
    'additional_resource_allocation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_penalty_exposure_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dsar_capa_actions_r3717 enable row level security;

create index if not exists idx_dsar_capa_actions_r3717_request on public.dsar_capa_actions_r3717(request_id);
create index if not exists idx_dsar_capa_actions_r3717_status on public.dsar_capa_actions_r3717(capa_status);

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

  -- 16 DSAR fulfilment rows
  insert into public.dsar_r3717 (
    organization_id, request_ref, requester_type, period_month, request_date, statutory_due_date,
    fulfilled_date, days_to_fulfil, within_sla, identity_verified, records_systems_touched,
    partial_fulfilment, escalated_to_dpo, request_class, fulfilment_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.rtype, q.pmonth::date, q.rdate::date, q.due::date,
    q.fdate::date, q.days, q.sla, q.idv, q.recs, q.partial, q.esc, q.rclass, q.fstatus, q.trend, q.nt
  from (values
    ('DSAR-2026-0705-001','customer','2026-07-01','2026-07-05','2026-08-04','2026-07-20',
     15,true,true,3,false,false,'access_copy','fulfilled_on_time','improving',
     'Customer requested copy of AMC service records for compressor units — provided via secure portal.'),
    ('DSAR-2026-0705-002','employee','2026-07-01','2026-07-05','2026-07-20','2026-07-19',
     14,true,true,2,false,false,'correction','fulfilled_on_time','stable',
     'Employee HR record correction — bank account details updated in payroll system.'),
    ('DSAR-2026-0706-003','ex_employee','2026-07-01','2026-07-06','2026-08-05','2026-07-25',
     19,true,true,4,false,false,'access_copy','fulfilled_on_time','stable',
     'Ex-employee requested copy of payroll and PF contribution records — provided.'),
    ('DSAR-2026-0708-004','vendor_partner','2026-07-01','2026-07-08','2026-08-07',null,
     null,false,true,4,false,true,'erasure','overdue','worsening',
     'Vendor contact-data erasure pending legal review of statutory retention obligations — escalated to DPO.'),
    ('DSAR-2026-0709-005','customer','2026-07-01','2026-07-09','2026-07-24','2026-08-02',
     24,false,true,2,false,false,'correction','fulfilled_late','worsening',
     'Address correction delayed due to CRM sync backlog on ventilator AMC account.'),
    ('DSAR-2026-0710-006','job_applicant','2026-07-01','2026-07-10','2026-07-25','2026-07-18',
     8,true,true,1,false,false,'erasure','fulfilled_on_time','improving',
     'Rejected job-applicant resume data erasure completed within SLA.'),
    ('DSAR-2026-0712-007','customer','2026-07-01','2026-07-12','2026-08-11',null,
     null,true,true,5,false,false,'access_copy','in_progress','stable',
     'Multi-system service-history export in progress — biomedical equipment usage logs across five systems.'),
    ('DSAR-2026-0713-008','employee','2026-07-01','2026-07-13','2026-07-28','2026-08-06',
     24,false,true,2,true,true,'grievance','fulfilled_late','worsening',
     'Grievance on internal data-sharing consent handled late with partial fulfilment — escalated to DPO.'),
    ('DSAR-2026-0715-009','customer','2026-07-01','2026-07-15','2026-08-14','2026-07-30',
     15,true,true,3,false,false,'nominee_exercise','fulfilled_on_time','improving',
     'Nominee exercised access rights post data-principal demise — nomination documents verified.'),
    ('DSAR-2026-0718-010','vendor_partner','2026-07-01','2026-07-18','2026-08-02','2026-07-29',
     11,true,false,1,false,false,'grievance','rejected_documented','stable',
     'Grievance rejected — requester failed identity verification; decision documented and communicated.'),
    ('DSAR-2026-0720-011','customer','2026-07-01','2026-07-20','2026-08-19','2026-08-01',
     12,true,true,2,false,false,'correction','fulfilled_on_time','stable',
     'Equipment ownership record name correction completed for imaging-system account.'),
    ('DSAR-2026-0722-012','employee','2026-07-01','2026-07-22','2026-08-21',null,
     null,true,true,3,false,false,'erasure','in_progress','stable',
     'Former field-engineer data erasure in progress across CRM and field-service systems.'),
    ('DSAR-2026-0801-013','customer','2026-08-01','2026-08-01','2026-08-31','2026-08-09',
     8,true,true,4,false,false,'access_copy','fulfilled_on_time','improving',
     'Access copy of AMC and warranty claim history provided promptly for dialysis machine fleet.'),
    ('DSAR-2026-0802-014','job_applicant','2026-08-01','2026-08-02','2026-08-17',null,
     null,false,false,1,false,true,'access_copy','overdue','worsening',
     'Applicant identity verification stalled — request past internal SLA, escalated to DPO.'),
    ('DSAR-2026-0803-015','customer','2026-08-01','2026-08-03','2026-08-18','2026-08-08',
     5,true,true,1,false,false,'grievance','rejected_documented','improving',
     'Grievance on marketing calls found not attributable to company — rejection documented.'),
    ('DSAR-2026-0804-016','vendor_partner','2026-08-01','2026-08-04','2026-09-03',null,
     null,true,true,2,false,false,'nominee_exercise','in_progress','stable',
     'Nominee exercise request under legal review for vendor contract data access.')
  ) as q(ref, rtype, pmonth, rdate, due, fdate, days, sla, idv, recs, partial, esc, rclass, fstatus, trend, nt);

  -- CAPA seed — attach to specific requests via request_ref
  insert into public.dsar_capa_actions_r3717 (
    request_id, root_cause, corrective_action, capa_status,
    estimated_penalty_exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.pen, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DSAR-2026-0708-004','legal_review_required','legal_review_completion','escalated',185000.00,
     'Legal & Compliance','2026-08-15',null,'Retention-period assessment pending outside counsel opinion; DPO escalation active.'),
    ('DSAR-2026-0709-005','system_data_retrieval_delay','process_automation_upgrade','in_progress',25000.00,
     'CRM Ops','2026-08-20',null,'CRM sync backlog causing correction delays — automation ticket raised.'),
    ('DSAR-2026-0713-008','staff_training_gap','staff_retraining','verification_pending',60000.00,
     'Customer Support Lead','2026-08-18',null,'Support team retrained on consent-grievance SOP; awaiting QA sign-off.'),
    ('DSAR-2026-0718-010','identity_verification_pending','conduct_identity_reverification','closed',0.00,
     'Privacy Desk','2026-07-28','2026-07-27','Rejection communicated with documented reasoning; no further action required.'),
    ('DSAR-2026-0722-012','complex_multi_system_request','expedite_processing','open',15000.00,
     'IT Systems','2026-08-25',null,'Erasure spans CRM, field-service and payroll systems — cross-team coordination underway.'),
    ('DSAR-2026-0802-014','identity_verification_pending','escalate_to_dpo','overdue',90000.00,
     'Privacy Desk','2026-08-16',null,'Applicant unresponsive to verification requests — DPO escalation raised past internal SLA.'),
    ('DSAR-2026-0803-015','requester_non_response','close_with_documented_reason','closed',0.00,
     'Privacy Desk','2026-08-10','2026-08-08','No further correspondence from requester; grievance closed with documentation.'),
    ('DSAR-2026-0712-007','backlog_volume_surge','additional_resource_allocation','in_progress',10000.00,
     'Data Protection Team','2026-08-20',null,'Temporary surge in access-copy volume; additional analyst assigned to clear backlog.')
  ) as q(ref, rc, ca, cst, pen, own, tcd, acd, nt)
  join public.dsar_r3717 e
    on e.organization_id = v_org_id and e.request_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Fulfilment status distribution
create or replace function public.founder_r3717_fulfilment_status_rollup()
returns table(fulfilment_status text, requests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dsar_r3717)
  select l.fulfilment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dsar_r3717 l
  group by l.fulfilment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3717_fulfilment_status_rollup() from public, anon;
grant execute on function public.founder_r3717_fulfilment_status_rollup() to authenticated;

-- 2) Requester-type scorecard
create or replace function public.founder_r3717_requester_type_scorecard()
returns table(
  requester_type text,
  total_requests bigint,
  on_time bigint,
  late bigint,
  in_progress bigint,
  overdue bigint,
  escalated bigint,
  sla_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.requester_type,
    count(*)::bigint,
    count(*) filter (where l.fulfilment_status = 'fulfilled_on_time')::bigint,
    count(*) filter (where l.fulfilment_status = 'fulfilled_late')::bigint,
    count(*) filter (where l.fulfilment_status = 'in_progress')::bigint,
    count(*) filter (where l.fulfilment_status = 'overdue')::bigint,
    count(*) filter (where l.escalated_to_dpo = true)::bigint,
    round(100.0 * count(*) filter (where l.fulfilment_status = 'fulfilled_on_time')::numeric / nullif(count(*),0), 1)
  from public.dsar_r3717 l
  group by l.requester_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3717_requester_type_scorecard() from public, anon;
grant execute on function public.founder_r3717_requester_type_scorecard() to authenticated;

-- 3) Request class × fulfilment status matrix
create or replace function public.founder_r3717_request_class_status_matrix()
returns table(request_class text, fulfilment_status text, requests bigint, avg_days_to_fulfil numeric, escalated_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.request_class, l.fulfilment_status, count(*)::bigint,
    round(avg(l.days_to_fulfil), 1),
    count(*) filter (where l.escalated_to_dpo = true)::bigint
  from public.dsar_r3717 l
  group by l.request_class, l.fulfilment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3717_request_class_status_matrix() from public, anon;
grant execute on function public.founder_r3717_request_class_status_matrix() to authenticated;

-- 4) Monthly fulfilment trend
create or replace function public.founder_r3717_monthly_fulfilment_trend()
returns table(period_month date, requests bigint, on_time bigint, late bigint, overdue bigint, avg_days_to_fulfil numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.fulfilment_status = 'fulfilled_on_time')::bigint,
    count(*) filter (where l.fulfilment_status = 'fulfilled_late')::bigint,
    count(*) filter (where l.fulfilment_status = 'overdue')::bigint,
    round(avg(l.days_to_fulfil), 1)
  from public.dsar_r3717 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3717_monthly_fulfilment_trend() from public, anon;
grant execute on function public.founder_r3717_monthly_fulfilment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3717_capa_status_board()
returns table(capa_status text, findings bigint, avg_penalty_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_penalty_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.dsar_capa_actions_r3717 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3717_capa_status_board() from public, anon;
grant execute on function public.founder_r3717_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3717_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_penalty_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dsar_capa_actions_r3717)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_penalty_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dsar_capa_actions_r3717 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3717_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3717_root_cause_pareto() to authenticated;

-- 7) Overdue digest
create or replace function public.founder_r3717_overdue_digest()
returns table(request_class text, overdue_count bigint, escalated_count bigint, avg_records_systems_touched numeric, oldest_due_date date)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.request_class,
    count(*)::bigint,
    count(*) filter (where l.escalated_to_dpo = true)::bigint,
    round(avg(l.records_systems_touched), 1),
    min(l.statutory_due_date)
  from public.dsar_r3717 l
  where l.fulfilment_status = 'overdue'
  group by l.request_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3717_overdue_digest() from public, anon;
grant execute on function public.founder_r3717_overdue_digest() to authenticated;

-- 8) High-risk queue (overdue / fulfilled late)
create or replace function public.founder_r3717_high_risk_queue()
returns table(
  request_ref text,
  requester_type text,
  request_class text,
  request_date date,
  statutory_due_date date,
  fulfilment_status text,
  days_to_fulfil int,
  escalated_to_dpo boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.request_ref, l.requester_type, l.request_class, l.request_date, l.statutory_due_date,
    l.fulfilment_status, l.days_to_fulfil, l.escalated_to_dpo, l.notes
  from public.dsar_r3717 l
  where l.fulfilment_status in ('overdue','fulfilled_late')
  order by l.statutory_due_date asc;
end;
$$;

revoke execute on function public.founder_r3717_high_risk_queue() from public, anon;
grant execute on function public.founder_r3717_high_risk_queue() to authenticated;
