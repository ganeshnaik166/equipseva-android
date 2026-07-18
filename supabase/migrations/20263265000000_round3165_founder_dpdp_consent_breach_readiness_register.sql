-- Round 3165: Founder Data-Privacy (DPDP) Consent & Breach-Readiness Register
-- DPDP register — data category × processing purpose × consent basis × retention × subject-request SLA × breach drill × readiness score × gap flag × status + CAPA

-- =============================================================================
-- TABLE 1: dpdp_readiness_r3165 — per-entity data-privacy readiness register
-- =============================================================================
create table if not exists public.dpdp_readiness_r3165 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  entity_unit text not null,
  register_ref text not null,
  data_category text not null check (data_category in (
    'patient_pii','patient_health_records','payment_card_data','biometric_data',
    'staff_hr_data','insurance_claims','device_telemetry','contact_directory'
  )),
  processing_purpose text not null check (processing_purpose in (
    'clinical_care_delivery','billing_and_payments','insurance_claim_processing','appointment_scheduling',
    'regulatory_reporting','analytics_and_research','marketing_communication','vendor_service_delivery'
  )),
  consent_basis text not null check (consent_basis in (
    'explicit_consent','legitimate_use_care','legal_obligation','contract_performance',
    'vital_interest_emergency','deemed_consent','consent_withdrawn','consent_expired'
  )),
  retention_days int not null,
  subject_request_sla_days int,
  breach_drill_date date,
  dpo_owner text not null,
  readiness_score numeric(5,2),
  gap_flag text not null check (gap_flag in (
    'no_gap','minor_gap','moderate_gap','major_gap','critical_gap'
  )),
  status text not null check (status in (
    'compliant','remediation_in_progress','non_compliant','under_review',
    'breach_notified','exempt','pending_assessment'
  )),
  created_at timestamptz not null default now()
);

alter table public.dpdp_readiness_r3165 enable row level security;

create index if not exists idx_dpdp_readiness_r3165_org on public.dpdp_readiness_r3165(organization_id);
create index if not exists idx_dpdp_readiness_r3165_category on public.dpdp_readiness_r3165(data_category);
create index if not exists idx_dpdp_readiness_r3165_status on public.dpdp_readiness_r3165(status);

-- =============================================================================
-- TABLE 2: dpdp_readiness_capa_actions_r3165 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.dpdp_readiness_capa_actions_r3165 (
  id uuid primary key default gen_random_uuid(),
  readiness_id uuid not null references public.dpdp_readiness_r3165(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_consent_record','expired_retention_data','no_breach_drill','unencrypted_pii',
    'excessive_data_collection','no_dpo_assigned','delayed_subject_request','third_party_sharing_gap'
  )),
  root_cause text not null check (root_cause in (
    'process_not_defined','staff_untrained','legacy_system_limitation','vendor_noncompliance',
    'manual_tracking_error','policy_outdated','resource_constraint','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'implement_consent_management','deploy_encryption','define_retention_policy','conduct_breach_drill',
    'appoint_dpo','retrain_staff','update_vendor_contract','data_minimization_purge','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'dpdp_penalty_risk','cert_in_notifiable','nabh_finding','none','internal_only','patient_trust_impact'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dpdp_readiness_capa_actions_r3165 enable row level security;

create index if not exists idx_dpdp_capa_r3165_readiness on public.dpdp_readiness_capa_actions_r3165(readiness_id);
create index if not exists idx_dpdp_capa_r3165_status on public.dpdp_readiness_capa_actions_r3165(capa_status);

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

  -- 13 readiness register rows
  insert into public.dpdp_readiness_r3165 (
    organization_id, hospital_name, entity_unit, register_ref,
    data_category, processing_purpose, consent_basis,
    retention_days, subject_request_sla_days, breach_drill_date,
    dpo_owner, readiness_score, gap_flag, status
  )
  select v_org_id, q.hosp, q.unit, q.ref,
    q.dc, q.pp, q.cb,
    q.rd, q.sla, q.bdd::date,
    q.dpo, q.rs, q.gf, q.st
  from (values
    ('Apollo Hyderabad Jubilee Hills','Radiology PACS','DPR-APL-001',
     'patient_health_records','clinical_care_delivery','legitimate_use_care',
     3650,30,'2026-05-12','Dr. Anjali Rao',88.50,'minor_gap','compliant'),
    ('Apollo Hyderabad Jubilee Hills','Billing & TPA Desk','DPR-APL-002',
     'payment_card_data','billing_and_payments','contract_performance',
     1825,30,'2026-05-12','Dr. Anjali Rao',72.00,'moderate_gap','remediation_in_progress'),
    ('Fortis Bannerghatta Bengaluru','Registration Desk','DPR-FRT-001',
     'patient_pii','appointment_scheduling','explicit_consent',
     1095,45,'2026-04-20','Mr. Suresh Kamath',65.50,'major_gap','non_compliant'),
    ('Fortis Bannerghatta Bengaluru','Insurance Cell','DPR-FRT-002',
     'insurance_claims','insurance_claim_processing','legal_obligation',
     2555,45,'2026-04-20','Mr. Suresh Kamath',78.00,'moderate_gap','remediation_in_progress'),
    ('Manipal Whitefield Bengaluru','Genomics Lab','DPR-MNP-001',
     'biometric_data','analytics_and_research','explicit_consent',
     3650,30,'2026-06-01','Dr. Kavya Nair',55.00,'critical_gap','non_compliant'),
    ('Manipal Whitefield Bengaluru','HR Department','DPR-MNP-002',
     'staff_hr_data','regulatory_reporting','legal_obligation',
     2920,30,'2026-06-01','Dr. Kavya Nair',90.00,'no_gap','compliant'),
    ('AIIMS New Delhi Ansari Nagar','e-Hospital EHR','DPR-AIM-001',
     'patient_health_records','clinical_care_delivery','legitimate_use_care',
     5475,30,'2026-03-15','Dr. Ramesh Gupta',82.50,'minor_gap','compliant'),
    ('AIIMS New Delhi Ansari Nagar','Research Registry','DPR-AIM-002',
     'patient_health_records','analytics_and_research','deemed_consent',
     3650,60,'2026-03-15','Dr. Ramesh Gupta',48.00,'critical_gap','under_review'),
    ('KIMS Secunderabad','Cardiac Device Cloud','DPR-KIM-001',
     'device_telemetry','vendor_service_delivery','contract_performance',
     1825,45,null,'Ms. Priya Reddy',60.00,'major_gap','pending_assessment'),
    ('Care Hospitals Banjara Hills','Marketing CRM','DPR-CAR-001',
     'contact_directory','marketing_communication','consent_withdrawn',
     365,30,'2026-05-28','Mr. Arun Menon',40.00,'critical_gap','breach_notified'),
    ('Yashoda Somajiguda Hyderabad','Emergency Department','DPR-YSH-001',
     'patient_pii','clinical_care_delivery','vital_interest_emergency',
     1095,30,'2026-06-10','Dr. Sneha Iyer',85.00,'minor_gap','compliant'),
    ('St John''s Bengaluru','Pharmacy POS','DPR-STJ-001',
     'payment_card_data','billing_and_payments','contract_performance',
     1825,30,'2026-04-05','Mr. David Fernandes',70.00,'moderate_gap','remediation_in_progress'),
    ('Rainbow Children''s Hyderabad','Neonatal ICU','DPR-RBW-001',
     'patient_health_records','clinical_care_delivery','consent_expired',
     3650,30,null,'Dr. Meera Krishnan',58.00,'major_gap','under_review')
  ) as q(hosp, unit, ref, dc, pp, cb, rd, sla, bdd, dpo, rs, gf, st);

  -- CAPA seed — attach to specific register entries by register_ref
  insert into public.dpdp_readiness_capa_actions_r3165 (
    readiness_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('DPR-FRT-001','missing_consent_record','process_not_defined','implement_consent_management',
     '2026-08-15',null,'in_progress','dpdp_penalty_risk',250000.00,'Consent capture not digitized at registration desk'),
    ('DPR-MNP-001','unencrypted_pii','legacy_system_limitation','deploy_encryption',
     '2026-09-01',null,'escalated','cert_in_notifiable',480000.00,'Genomic data at rest unencrypted on legacy LIMS'),
    ('DPR-CAR-001','third_party_sharing_gap','vendor_noncompliance','update_vendor_contract',
     '2026-07-30','2026-07-20','closed','cert_in_notifiable',120000.00,'Marketing vendor shared list without DPA — CERT-In notified'),
    ('DPR-AIM-002','excessive_data_collection','policy_outdated','data_minimization_purge',
     '2026-08-20',null,'open','dpdp_penalty_risk',85000.00,'Research registry retains full PII beyond stated purpose'),
    ('DPR-KIM-001','no_breach_drill','resource_constraint','conduct_breach_drill',
     '2026-08-05',null,'open','internal_only',35000.00,'No breach simulation run for device-telemetry vendor'),
    ('DPR-RBW-001','delayed_subject_request','staff_untrained','retrain_staff',
     '2026-08-10',null,'verification_pending','patient_trust_impact',18000.00,'Parent access request took 40 days — SLA breached')
  ) as q(ref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.dpdp_readiness_r3165 e
    on e.organization_id = v_org_id and e.register_ref = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Status / verdict rollup
create or replace function public.founder_r3165_status_rollup()
returns table(status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dpdp_readiness_r3165)
  select l.status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dpdp_readiness_r3165 l
  group by l.status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3165_status_rollup() from public, anon;
grant execute on function public.founder_r3165_status_rollup() to authenticated;

-- 2) Hospital / entity readiness scorecard
create or replace function public.founder_r3165_hospital_scorecard()
returns table(
  hospital_name text,
  entries bigint,
  compliant bigint,
  non_compliant bigint,
  breach_notified bigint,
  critical_gaps bigint,
  avg_readiness numeric,
  compliance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.status = 'compliant')::bigint,
    count(*) filter (where l.status = 'non_compliant')::bigint,
    count(*) filter (where l.status = 'breach_notified')::bigint,
    count(*) filter (where l.gap_flag = 'critical_gap')::bigint,
    round(avg(l.readiness_score), 1),
    round(100.0 * count(*) filter (where l.status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.dpdp_readiness_r3165 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3165_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3165_hospital_scorecard() to authenticated;

-- 3) Data category × processing purpose matrix
create or replace function public.founder_r3165_category_matrix()
returns table(data_category text, processing_purpose text, entries bigint, avg_readiness numeric, avg_retention_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.data_category, l.processing_purpose, count(*)::bigint,
    round(avg(l.readiness_score), 1),
    round(avg(l.retention_days), 0)
  from public.dpdp_readiness_r3165 l
  group by l.data_category, l.processing_purpose
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3165_category_matrix() from public, anon;
grant execute on function public.founder_r3165_category_matrix() to authenticated;

-- 4) Breach-drill readiness trend (by drill date)
create or replace function public.founder_r3165_breach_drill_trend()
returns table(breach_drill_date date, drills bigint, avg_readiness numeric, high_gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.breach_drill_date,
    count(*)::bigint,
    round(avg(l.readiness_score), 1),
    count(*) filter (where l.gap_flag in ('major_gap','critical_gap'))::bigint
  from public.dpdp_readiness_r3165 l
  where l.breach_drill_date is not null
  group by l.breach_drill_date
  order by l.breach_drill_date desc;
end;
$$;

revoke execute on function public.founder_r3165_breach_drill_trend() from public, anon;
grant execute on function public.founder_r3165_breach_drill_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3165_capa_status_board()
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
  from public.dpdp_readiness_capa_actions_r3165 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3165_capa_status_board() from public, anon;
grant execute on function public.founder_r3165_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3165_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dpdp_readiness_capa_actions_r3165)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dpdp_readiness_capa_actions_r3165 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3165_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3165_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3165_regulatory_impact_digest()
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
  from public.dpdp_readiness_capa_actions_r3165 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3165_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3165_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority register queue
create or replace function public.founder_r3165_high_risk_register()
returns table(
  hospital_name text,
  entity_unit text,
  register_ref text,
  data_category text,
  consent_basis text,
  retention_days int,
  breach_drill_date date,
  gap_flag text,
  status text,
  dpo_owner text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.entity_unit, l.register_ref, l.data_category, l.consent_basis,
    l.retention_days, l.breach_drill_date, l.gap_flag, l.status, l.dpo_owner
  from public.dpdp_readiness_r3165 l
  where l.status in ('non_compliant','under_review','breach_notified','pending_assessment')
     or l.gap_flag in ('major_gap','critical_gap')
     or l.breach_drill_date is null
  order by l.breach_drill_date asc nulls first, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3165_high_risk_register() from public, anon;
grant execute on function public.founder_r3165_high_risk_register() to authenticated;
