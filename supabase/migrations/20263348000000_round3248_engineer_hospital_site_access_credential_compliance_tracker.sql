-- Round 3248: Engineer Hospital Site-Access Credential Compliance Tracker
-- Field-force compliance — credential type × issuing authority × expiry runway × blocked site visits × compliance verdict × renewal CAPA

-- =============================================================================
-- TABLE 1: engineer_site_credential_r3248 — per engineer-credential records
-- =============================================================================
create table if not exists public.engineer_site_credential_r3248 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  region text not null,
  credential_ref text not null,
  credential_type text not null check (credential_type in (
    'hospital_gate_pass','vaccination_hep_b','vaccination_covid','police_verification',
    'background_check','ot_entry_training','radiation_safety_badge'
  )),
  issuing_authority text not null,
  issue_date date not null,
  expiry_date date,
  days_to_expiry int,
  status text not null check (status in (
    'valid','expiring_30d','expired','rejected','pending_renewal'
  )),
  blocked_site_visits int not null default 0,
  last_verified_date date,
  compliance_verdict text not null check (compliance_verdict in (
    'compliant','at_risk','non_compliant','grace_period'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_site_credential_r3248 enable row level security;

create index if not exists idx_eng_site_cred_r3248_org on public.engineer_site_credential_r3248(organization_id);
create index if not exists idx_eng_site_cred_r3248_status on public.engineer_site_credential_r3248(status);
create index if not exists idx_eng_site_cred_r3248_verdict on public.engineer_site_credential_r3248(compliance_verdict);

-- =============================================================================
-- TABLE 2: engineer_site_credential_capa_actions_r3248 — renewal / escalation CAPA
-- =============================================================================
create table if not exists public.engineer_site_credential_capa_actions_r3248 (
  id uuid primary key default gen_random_uuid(),
  credential_id uuid not null references public.engineer_site_credential_r3248(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'credential_expired','expiry_imminent','application_rejected','verification_lapsed',
    'site_visit_blocked','renewal_stalled','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'engineer_delay','authority_processing_backlog','document_mismatch','fee_unpaid',
    'medical_record_missing','address_proof_outdated','pending_investigation','tracking_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_renewal_application','escalate_to_issuing_authority','schedule_vaccination_dose',
    'resubmit_documents','pay_renewal_fee','book_training_slot','issue_temporary_pass',
    'reassign_site_coverage','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'hospital_access_blocked','aerb_notifiable','nabh_finding','client_contract_breach','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_site_credential_capa_actions_r3248 enable row level security;

create index if not exists idx_eng_site_cred_capa_r3248_cred on public.engineer_site_credential_capa_actions_r3248(credential_id);
create index if not exists idx_eng_site_cred_capa_r3248_status on public.engineer_site_credential_capa_actions_r3248(capa_status);

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

  -- 14 engineer-credential rows
  insert into public.engineer_site_credential_r3248 (
    organization_id, engineer_name, region, credential_ref, credential_type,
    issuing_authority, issue_date, expiry_date, days_to_expiry,
    status, blocked_site_visits, last_verified_date, compliance_verdict, notes
  )
  select v_org_id, q.eng, q.reg, q.ref, q.ctype,
    q.auth, q.isd::date, q.exd::date, q.dte,
    q.st, q.bsv, q.lvd::date, q.cv, q.nt
  from (values
    ('Rajesh Kumar','Chennai','CRED-RJK-001','hospital_gate_pass','Apollo Chennai Security Cell',
     '2025-08-01','2026-07-31',13,'expiring_30d',0,'2026-07-15','at_risk','Gate pass expires end of month — renewal filed at security desk'),
    ('Rajesh Kumar','Chennai','CRED-RJK-002','radiation_safety_badge','AERB eLORA Portal',
     '2025-01-10','2027-01-09',175,'valid',0,'2026-07-10','compliant','TLD badge current — quarterly dose reading submitted'),
    ('Priya Nair','Vellore','CRED-PRN-001','vaccination_hep_b','CMC Vellore Staff Clinic',
     '2023-06-20',null,null,'valid',0,'2026-07-01','compliant','Full 3-dose series with anti-HBs titre report on file'),
    ('Amit Sharma','Gurgaon','CRED-AMS-001','police_verification','Gurugram Police Commissionerate',
     '2024-05-12','2026-05-11',-68,'expired',3,'2026-07-12','non_compliant','PVC expired — 3 Fortis Gurgaon visits blocked in June'),
    ('Amit Sharma','Gurgaon','CRED-AMS-002','hospital_gate_pass','Fortis Gurgaon Admin Office',
     '2026-02-01','2027-01-31',197,'valid',0,'2026-07-12','compliant','Annual contractor pass active'),
    ('Vikram Singh','Delhi','CRED-VKS-001','ot_entry_training','AIIMS Delhi OT Committee',
     '2025-07-30','2026-07-29',11,'expiring_30d',0,'2026-07-14','at_risk','OT asepsis refresher slot booked for 24 Jul'),
    ('Deepak Patil','Bengaluru','CRED-DPP-001','background_check','Manipal Bengaluru HR Vendor Cell',
     '2026-06-05',null,null,'pending_renewal',1,'2026-07-08','grace_period','Re-verification underway — temporary escorted access granted'),
    ('Deepak Patil','Bengaluru','CRED-DPP-002','vaccination_covid','Manipal Staff Health Clinic',
     '2025-11-15','2026-11-14',119,'valid',0,'2026-07-08','compliant','Booster dose current'),
    ('Anil Reddy','Hyderabad','CRED-ANR-001','hospital_gate_pass','KIMS Secunderabad Security',
     '2025-07-01','2026-06-30',-18,'expired',2,'2026-07-16','grace_period','KIMS granted 30-day grace — renewal in process'),
    ('Anil Reddy','Hyderabad','CRED-ANR-002','radiation_safety_badge','AERB eLORA Portal',
     '2026-03-01','2027-02-28',225,'valid',0,'2026-07-05','compliant','Cath-lab service badge current'),
    ('Kavitha Iyer','Chennai','CRED-KVI-001','ot_entry_training','Apollo Chennai OT Committee',
     '2024-12-10','2025-12-09',-221,'expired',4,'2026-07-11','non_compliant','OT training lapsed 7 months — CSSD and OT visits blocked'),
    ('Manoj Verma','Delhi','CRED-MNV-001','police_verification','Delhi Police Vendor Cell',
     '2026-04-18','2028-04-17',639,'valid',0,'2026-07-09','compliant','Fresh PVC valid two years'),
    ('Sandeep Joshi','Mumbai','CRED-SDJ-001','background_check','Lilavati Mumbai Contractor Desk',
     '2026-01-20',null,null,'rejected',2,'2026-07-13','non_compliant','Address mismatch in dossier — application rejected, resubmission due'),
    ('Suresh Menon','Kochi','CRED-SRM-001','vaccination_hep_b','Aster Medcity Staff Clinic',
     '2026-05-02',null,null,'pending_renewal',0,'2026-07-06','grace_period','Dose 2 of 3 complete — titre check pending')
  ) as q(eng, reg, ref, ctype, auth, isd, exd, dte, st, bsv, lvd, cv, nt);

  -- CAPA seed — attach to specific credentials via credential_ref
  insert into public.engineer_site_credential_capa_actions_r3248 (
    credential_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CRED-AMS-001','credential_expired','authority_processing_backlog','expedite_renewal_application','escalated','hospital_access_blocked','2026-07-25',null,1500.00,'PVC renewal escalated to vendor-cell SPOC — visits rerouted meanwhile'),
    ('CRED-ANR-001','credential_expired','engineer_delay','pay_renewal_fee','in_progress','internal_only','2026-07-22',null,800.00,'Renewal fee paid — pass printing awaited at KIMS security'),
    ('CRED-KVI-001','renewal_stalled','engineer_delay','book_training_slot','overdue','nabh_finding','2026-06-30',null,3500.00,'OT refresher slot missed twice — past target date'),
    ('CRED-SDJ-001','application_rejected','document_mismatch','resubmit_documents','open','client_contract_breach','2026-07-30',null,0.00,'Aadhaar address updated — dossier resubmission this week'),
    ('CRED-RJK-001','expiry_imminent','tracking_gap','expedite_renewal_application','verification_pending','internal_only','2026-07-28',null,500.00,'Renewal filed — awaiting Apollo security counter-sign'),
    ('CRED-VKS-001','expiry_imminent','engineer_delay','book_training_slot','in_progress','internal_only','2026-07-26',null,2000.00,'Refresher booked 24 Jul — certificate upload pending'),
    ('CRED-DPP-001','verification_lapsed','authority_processing_backlog','issue_temporary_pass','closed','hospital_access_blocked','2026-07-10','2026-07-08',0.00,'Escorted temporary pass issued while re-verification completes')
  ) as q(ref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.engineer_site_credential_r3248 e
    on e.organization_id = v_org_id and e.credential_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3248_compliance_verdict_rollup()
returns table(compliance_verdict text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_site_credential_r3248)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_site_credential_r3248 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3248_compliance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3248_compliance_verdict_rollup() to authenticated;

-- 2) Region-level compliance scorecard
create or replace function public.founder_r3248_region_scorecard()
returns table(
  region text,
  total_records bigint,
  compliant bigint,
  at_risk bigint,
  non_compliant bigint,
  expired_creds bigint,
  blocked_visits bigint,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'compliant')::bigint,
    count(*) filter (where l.compliance_verdict = 'at_risk')::bigint,
    count(*) filter (where l.compliance_verdict = 'non_compliant')::bigint,
    count(*) filter (where l.status = 'expired')::bigint,
    coalesce(sum(l.blocked_site_visits),0)::bigint,
    round(100.0 * count(*) filter (where l.compliance_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.engineer_site_credential_r3248 l
  group by l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3248_region_scorecard() from public, anon;
grant execute on function public.founder_r3248_region_scorecard() to authenticated;

-- 3) Credential type × status matrix
create or replace function public.founder_r3248_credential_status_matrix()
returns table(credential_type text, status text, records bigint, avg_days_to_expiry numeric, blocked_visits bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.credential_type, l.status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1),
    coalesce(sum(l.blocked_site_visits),0)::bigint
  from public.engineer_site_credential_r3248 l
  group by l.credential_type, l.status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3248_credential_status_matrix() from public, anon;
grant execute on function public.founder_r3248_credential_status_matrix() to authenticated;

-- 4) Daily verification trend
create or replace function public.founder_r3248_daily_verification_trend()
returns table(last_verified_date date, records bigint, compliant bigint, non_compliant bigint, blocked_visits bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.last_verified_date,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'compliant')::bigint,
    count(*) filter (where l.compliance_verdict = 'non_compliant')::bigint,
    coalesce(sum(l.blocked_site_visits),0)::bigint
  from public.engineer_site_credential_r3248 l
  group by l.last_verified_date
  order by l.last_verified_date desc;
end;
$$;

revoke execute on function public.founder_r3248_daily_verification_trend() from public, anon;
grant execute on function public.founder_r3248_daily_verification_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3248_capa_status_board()
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
  from public.engineer_site_credential_capa_actions_r3248 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3248_capa_status_board() from public, anon;
grant execute on function public.founder_r3248_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3248_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_site_credential_capa_actions_r3248)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_site_credential_capa_actions_r3248 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3248_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3248_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3248_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.engineer_site_credential_capa_actions_r3248 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3248_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3248_regulatory_impact_digest() to authenticated;

-- 8) High-risk credential queue (top individual concerns)
create or replace function public.founder_r3248_high_risk_queue()
returns table(
  engineer_name text,
  region text,
  credential_ref text,
  credential_type text,
  issuing_authority text,
  expiry_date date,
  days_to_expiry int,
  status text,
  blocked_site_visits int,
  compliance_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.region, l.credential_ref, l.credential_type,
    l.issuing_authority, l.expiry_date, l.days_to_expiry, l.status,
    l.blocked_site_visits, l.compliance_verdict, l.notes
  from public.engineer_site_credential_r3248 l
  where l.status in ('expiring_30d','expired','rejected','pending_renewal')
     or l.compliance_verdict in ('at_risk','non_compliant','grace_period')
     or l.blocked_site_visits > 0
  order by l.days_to_expiry asc nulls last, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3248_high_risk_queue() from public, anon;
grant execute on function public.founder_r3248_high_risk_queue() to authenticated;
