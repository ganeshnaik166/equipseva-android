-- Round 3153: Founder Regulatory Licence & Statutory-Renewal Calendar
-- Licence register — authority × licence type × issued/expiry × days-to-expiry × renewal owner × renewal status × criticality + CAPA

-- =============================================================================
-- TABLE 1: regulatory_licence_r3153 — statutory licence register
-- =============================================================================
create table if not exists public.regulatory_licence_r3153 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  site_city text not null,
  authority text not null check (authority in (
    'cdsco','nabh','nabl','gst','pf_esi','labour','fire','pollution',
    'biomedical_waste','aerb','drug_control_state','income_tax'
  )),
  licence_type text not null check (licence_type in (
    'manufacturing_licence','import_licence','accreditation_certificate','gst_registration',
    'pf_registration','esi_registration','labour_licence','fire_noc','pollution_consent',
    'radiation_safety_licence','blood_bank_licence','biomedical_waste_authorization',
    'trade_licence','pharmacy_licence'
  )),
  licence_no text not null,
  issued_date date not null,
  expiry_date date not null,
  renewal_owner text not null,
  renewal_status text not null check (renewal_status in (
    'not_started','in_preparation','documents_pending','submitted',
    'under_review','renewed','rejected','expired','lapsed'
  )),
  criticality text not null check (criticality in (
    'critical','high','medium','low','informational'
  )),
  statutory_fee_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.regulatory_licence_r3153 enable row level security;

create index if not exists idx_reg_licence_r3153_org on public.regulatory_licence_r3153(organization_id);
create index if not exists idx_reg_licence_r3153_expiry on public.regulatory_licence_r3153(expiry_date);
create index if not exists idx_reg_licence_r3153_status on public.regulatory_licence_r3153(renewal_status);

-- =============================================================================
-- TABLE 2: regulatory_licence_capa_actions_r3153 — follow-up & CAPA actions
-- =============================================================================
create table if not exists public.regulatory_licence_capa_actions_r3153 (
  id uuid primary key default gen_random_uuid(),
  licence_id uuid not null references public.regulatory_licence_r3153(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'expiry_overdue','renewal_not_started','documents_missing','fee_unpaid',
    'inspection_pending','non_conformity_raised','authority_query',
    'penalty_notice_received','condition_not_met','owner_gap','preventive_renewal_due'
  )),
  root_cause text not null check (root_cause in (
    'owner_unassigned','documents_delay','budget_approval_pending','authority_backlog',
    'portal_technical_issue','missed_reminder','vendor_consultant_delay',
    'regulatory_change','incomplete_application','pending_investigation','resource_constraint'
  )),
  corrective_action text not null check (corrective_action in (
    'assign_renewal_owner','submit_application','pay_statutory_fee','engage_consultant',
    'schedule_inspection','escalate_to_management','file_compliance_response',
    'gather_documents','request_extension','set_calendar_reminder','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'statutory_non_compliance','penalty_risk','licence_suspension_risk','operations_halt_risk',
    'none','internal_only','patient_safety_alert','reputational_risk'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.regulatory_licence_capa_actions_r3153 enable row level security;

create index if not exists idx_reg_licence_capa_r3153_licence on public.regulatory_licence_capa_actions_r3153(licence_id);
create index if not exists idx_reg_licence_capa_r3153_status on public.regulatory_licence_capa_actions_r3153(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 13 licence register rows
  insert into public.regulatory_licence_r3153 (
    organization_id, entity_name, site_city, authority, licence_type, licence_no,
    issued_date, expiry_date, renewal_owner, renewal_status, criticality,
    statutory_fee_rupees, notes
  )
  select v_org_id, q.ent, q.city, q.auth, q.ltype, q.lno,
    q.iss::date, q.exp::date, q.owner, q.status, q.crit,
    q.fee, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Hyderabad','cdsco','blood_bank_licence','BB-TS-APL-2211',
     '2024-08-01','2026-08-15','Dr. Meera Rao','submitted','critical',25000.00,'Blood bank licence renewal filed, awaiting CDSCO inspection'),
    ('Apollo Hyderabad Jubilee Hills','Hyderabad','nabh','accreditation_certificate','NABH-H-2024-0912',
     '2023-09-10','2026-09-09','Quality Head Sunita','in_preparation','high',180000.00,'NABH 5th edition reassessment documents underway'),
    ('Fortis Bannerghatta Bengaluru','Bengaluru','pollution','pollution_consent','KSPCB-CFO-8841',
     '2023-07-01','2026-06-30','Facilities Mgr Anil','expired','critical',45000.00,'Consent to operate lapsed — renewal overdue 18 days'),
    ('Fortis Bannerghatta Bengaluru','Bengaluru','fire','fire_noc','FIRE-BLR-5590',
     '2024-01-15','2027-01-14','Facilities Mgr Anil','renewed','high',30000.00,'Fire NOC renewed after mock drill clearance'),
    ('Manipal Whitefield Bengaluru','Bengaluru','biomedical_waste','biomedical_waste_authorization','BMW-KAR-3301',
     '2024-03-01','2026-08-05','EHS Officer Kavya','documents_pending','critical',18000.00,'BMW authorization renewal — CBWTF tie-up letter pending'),
    ('Manipal Whitefield Bengaluru','Bengaluru','gst','gst_registration','29AABCM1234P1Z5',
     '2021-04-01','2099-12-31','Finance Ctrl Ramesh','renewed','low',0.00,'GST registration active — no periodic renewal'),
    ('AIIMS New Delhi Ansari Nagar','New Delhi','aerb','radiation_safety_licence','AERB-RSL-DL-771',
     '2023-11-20','2026-07-25','RSO Dr. Khanna','under_review','critical',60000.00,'AERB eLORA renewal under review — days to expiry critical'),
    ('AIIMS New Delhi Ansari Nagar','New Delhi','pf_esi','pf_registration','DLCPM0012345000',
     '2019-06-01','2099-12-31','HR Head Priya','renewed','medium',0.00,'EPF code active — monthly ECR compliance tracked separately'),
    ('KIMS Secunderabad','Secunderabad','drug_control_state','pharmacy_licence','DL-TS-20B-4417',
     '2024-05-10','2026-07-31','Chief Pharmacist Naidu','not_started','high',12000.00,'Form 20B/21B retail drug licence renewal not yet initiated'),
    ('Care Hospitals Banjara Hills','Hyderabad','labour','labour_licence','LAB-TS-CL-2290',
     '2023-08-01','2026-08-31','HR Mgr Fatima','submitted','medium',8500.00,'Contract labour licence renewal submitted on Shram Suvidha'),
    ('Yashoda Somajiguda Hyderabad','Hyderabad','nabl','accreditation_certificate','NABL-MC-2489',
     '2024-02-15','2026-09-20','Lab Director Rao','in_preparation','high',95000.00,'NABL ISO 15189 lab surveillance assessment prep'),
    ('St John''s Bengaluru','Bengaluru','cdsco','blood_bank_licence','BB-KAR-STJ-1180',
     '2022-06-25','2026-06-24','Blood Bank Officer','lapsed','critical',25000.00,'Blood bank licence lapsed — operations continuity risk'),
    ('Rainbow Children''s Hyderabad','Hyderabad','fire','fire_noc','FIRE-HYD-7742',
     '2023-12-01','2026-08-10','Admin Head Deepa','documents_pending','medium',22000.00,'Fire NOC renewal — updated building plan awaited')
  ) as q(ent, city, auth, ltype, lno, iss, exp, owner, status, crit, fee, nt);

  -- CAPA seed — attach to specific licences by licence_no
  insert into public.regulatory_licence_capa_actions_r3153 (
    licence_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select l.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('KSPCB-CFO-8841','expiry_overdue','missed_reminder','submit_application','2026-07-25',null,'in_progress','licence_suspension_risk',45000.00,'CFO renewal overdue — KSPCB portal application in progress'),
    ('BB-KAR-STJ-1180','expiry_overdue','owner_unassigned','assign_renewal_owner','2026-07-22',null,'escalated','operations_halt_risk',25000.00,'Blood bank lapsed — escalated, interim owner assigned'),
    ('AERB-RSL-DL-771','inspection_pending','authority_backlog','file_compliance_response','2026-07-24',null,'verification_pending','penalty_risk',60000.00,'AERB query on QA equipment — response filed'),
    ('DL-TS-20B-4417','renewal_not_started','owner_unassigned','assign_renewal_owner','2026-07-20',null,'open','penalty_risk',12000.00,'Drug licence renewal not started — nearing expiry'),
    ('BMW-KAR-3301','documents_missing','vendor_consultant_delay','gather_documents','2026-07-28',null,'in_progress','statutory_non_compliance',18000.00,'CBWTF agreement copy pending from waste vendor'),
    ('BB-TS-APL-2211','inspection_pending','authority_backlog','schedule_inspection','2026-08-05','2026-07-15','closed','none',25000.00,'CDSCO inspection completed, renewal cleared')
  ) as q(lno_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.regulatory_licence_r3153 l
    on l.organization_id = v_org_id and l.licence_no = q.lno_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Renewal status distribution
create or replace function public.founder_r3153_renewal_status_rollup()
returns table(renewal_status text, licences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.regulatory_licence_r3153)
  select l.renewal_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.regulatory_licence_r3153 l
  group by l.renewal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3153_renewal_status_rollup() from public, anon;
grant execute on function public.founder_r3153_renewal_status_rollup() to authenticated;

-- 2) Entity / hospital compliance scorecard
create or replace function public.founder_r3153_entity_scorecard()
returns table(
  entity_name text,
  total_licences bigint,
  renewed bigint,
  expiring_soon bigint,
  expired_lapsed bigint,
  critical bigint,
  avg_days_to_expiry numeric,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.renewal_status = 'renewed')::bigint,
    count(*) filter (where l.expiry_date >= current_date and l.expiry_date <= current_date + 30)::bigint,
    count(*) filter (where l.renewal_status in ('expired','lapsed') or l.expiry_date < current_date)::bigint,
    count(*) filter (where l.criticality = 'critical')::bigint,
    round(avg((l.expiry_date - current_date))::numeric, 1),
    round(100.0 * count(*) filter (where l.renewal_status = 'renewed')::numeric / nullif(count(*),0), 1)
  from public.regulatory_licence_r3153 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3153_entity_scorecard() from public, anon;
grant execute on function public.founder_r3153_entity_scorecard() to authenticated;

-- 3) Authority × licence-type matrix
create or replace function public.founder_r3153_authority_type_matrix()
returns table(authority text, licence_type text, licences bigint, renewed bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.authority, l.licence_type, count(*)::bigint,
    count(*) filter (where l.renewal_status = 'renewed')::bigint,
    round(avg((l.expiry_date - current_date))::numeric, 1)
  from public.regulatory_licence_r3153 l
  group by l.authority, l.licence_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3153_authority_type_matrix() from public, anon;
grant execute on function public.founder_r3153_authority_type_matrix() to authenticated;

-- 4) Expiry-by-month trend
create or replace function public.founder_r3153_expiry_month_trend()
returns table(expiry_month date, licences bigint, expired bigint, renewed bigint, critical bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.expiry_date)::date,
    count(*)::bigint,
    count(*) filter (where l.renewal_status in ('expired','lapsed') or l.expiry_date < current_date)::bigint,
    count(*) filter (where l.renewal_status = 'renewed')::bigint,
    count(*) filter (where l.criticality = 'critical')::bigint
  from public.regulatory_licence_r3153 l
  group by date_trunc('month', l.expiry_date)
  order by date_trunc('month', l.expiry_date);
end;
$$;

revoke execute on function public.founder_r3153_expiry_month_trend() from public, anon;
grant execute on function public.founder_r3153_expiry_month_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3153_capa_status_board()
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
  from public.regulatory_licence_capa_actions_r3153 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3153_capa_status_board() from public, anon;
grant execute on function public.founder_r3153_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3153_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.regulatory_licence_capa_actions_r3153)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.regulatory_licence_capa_actions_r3153 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3153_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3153_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3153_regulatory_impact_digest()
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
  from public.regulatory_licence_capa_actions_r3153 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3153_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3153_regulatory_impact_digest() to authenticated;

-- 8) Priority renewal queue (high-risk individual licences)
create or replace function public.founder_r3153_priority_renewal_queue()
returns table(
  entity_name text,
  authority text,
  licence_type text,
  licence_no text,
  expiry_date date,
  days_to_expiry int,
  renewal_owner text,
  renewal_status text,
  criticality text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.authority, l.licence_type, l.licence_no, l.expiry_date,
    (l.expiry_date - current_date)::int, l.renewal_owner, l.renewal_status, l.criticality, l.notes
  from public.regulatory_licence_r3153 l
  where l.renewal_status in ('not_started','documents_pending','expired','lapsed','rejected')
     or l.expiry_date <= current_date + 45
     or l.criticality = 'critical'
  order by l.expiry_date, l.criticality;
end;
$$;

revoke execute on function public.founder_r3153_priority_renewal_queue() from public, anon;
grant execute on function public.founder_r3153_priority_renewal_queue() to authenticated;
