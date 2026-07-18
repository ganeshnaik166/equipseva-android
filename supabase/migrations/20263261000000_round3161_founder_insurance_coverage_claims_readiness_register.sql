-- Round 3161: Founder Insurance-Coverage & Claims-Readiness Register
-- Policy register — policy type × insurer × sum insured × premium × renewal × coverage gap × claims × readiness score × CAPA

-- =============================================================================
-- TABLE 1: insurance_coverage_r3161 — one row per policy / cover
-- =============================================================================
create table if not exists public.insurance_coverage_r3161 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  policy_type text not null check (policy_type in (
    'professional_indemnity','public_liability','asset_fire_property','cyber_liability',
    'gmc_group_medical','directors_officers','marine_transit','workmen_compensation'
  )),
  insurer_name text not null,
  policy_number text not null,
  sum_insured_rupees numeric(14,2) not null,
  premium_rupees numeric(12,2) not null,
  policy_start_date date not null,
  renewal_date date not null,
  coverage_gap_flag text not null check (coverage_gap_flag in (
    'no_gap','minor_gap','material_gap','uninsured_exposure','over_insured','sub_limit_breach'
  )),
  claims_filed int not null default 0,
  claim_status text not null check (claim_status in (
    'no_claims','filed_pending','under_assessment','approved','settled','partially_settled','repudiated'
  )),
  readiness_score int not null,
  readiness_verdict text not null check (readiness_verdict in (
    'claims_ready','minor_gaps','remediation_needed','high_exposure','non_compliant','audit_ready'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.insurance_coverage_r3161 enable row level security;

create index if not exists idx_insurance_coverage_r3161_org on public.insurance_coverage_r3161(organization_id);
create index if not exists idx_insurance_coverage_r3161_renewal on public.insurance_coverage_r3161(renewal_date);
create index if not exists idx_insurance_coverage_r3161_verdict on public.insurance_coverage_r3161(readiness_verdict);

-- =============================================================================
-- TABLE 2: insurance_coverage_capa_actions_r3161 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.insurance_coverage_capa_actions_r3161 (
  id uuid primary key default gen_random_uuid(),
  coverage_id uuid not null references public.insurance_coverage_r3161(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'coverage_gap','expired_policy','sum_insured_inadequate','premium_overdue','claim_documentation_missing',
    'renewal_lapse_risk','sub_limit_exposure','exclusion_ambiguity','kyc_incomplete','regulatory_filing_pending'
  )),
  root_cause text not null check (root_cause in (
    'valuation_outdated','broker_delay','budget_constraint','documentation_backlog','policy_misclassification',
    'insurer_dispute','process_gap','awareness_gap','pending_investigation','vendor_noncompliance'
  )),
  corrective_action text not null check (corrective_action in (
    'renew_policy','increase_sum_insured','file_claim_documents','revalue_assets','negotiate_premium',
    'add_cyber_rider','escalate_to_insurer','engage_new_broker','complete_kyc','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','irdai_notifiable','none','internal_only','board_risk_committee','litigation_risk'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.insurance_coverage_capa_actions_r3161 enable row level security;

create index if not exists idx_insurance_capa_r3161_coverage on public.insurance_coverage_capa_actions_r3161(coverage_id);
create index if not exists idx_insurance_capa_r3161_status on public.insurance_coverage_capa_actions_r3161(capa_status);

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

  -- 13 policy rows
  insert into public.insurance_coverage_r3161 (
    organization_id, hospital_name, policy_type, insurer_name, policy_number,
    sum_insured_rupees, premium_rupees, policy_start_date, renewal_date,
    coverage_gap_flag, claims_filed, claim_status, readiness_score, readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.pt, q.ins, q.pol,
    q.si, q.prem, q.psd::date, q.rnw::date,
    q.gap, q.cf, q.cst, q.rs, q.rv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','professional_indemnity','ICICI Lombard','POL-APL-PI-2401',
     100000000.00,850000.00,'2025-08-01','2026-07-31','no_gap',2,'under_assessment',88,'claims_ready','PI cover for 400 empanelled doctors'),
    ('Apollo Hyderabad Jubilee Hills','asset_fire_property','New India Assurance','POL-APL-AS-2402',
     2500000000.00,4200000.00,'2025-04-01','2026-03-31','minor_gap',0,'no_claims',74,'minor_gaps','Building revaluation pending — reinstatement value understated'),
    ('Fortis Bannerghatta Bengaluru','cyber_liability','HDFC Ergo','POL-FRT-CY-2403',
     150000000.00,1250000.00,'2025-09-15','2026-09-14','sub_limit_breach',1,'filed_pending',61,'remediation_needed','Ransomware sub-limit only 20% of SI — inadequate'),
    ('Fortis Bannerghatta Bengaluru','public_liability','Bajaj Allianz','POL-FRT-PL-2404',
     50000000.00,320000.00,'2025-06-01','2026-05-31','no_gap',0,'no_claims',90,'audit_ready','Third-party premises liability current'),
    ('Manipal Whitefield Bengaluru','gmc_group_medical','Star Health','POL-MNP-GMC-2405',
     200000000.00,6800000.00,'2025-07-01','2026-06-30','sub_limit_breach',5,'partially_settled',79,'minor_gaps','Staff GMC — maternity sub-limit exhausted mid-year'),
    ('Manipal Whitefield Bengaluru','professional_indemnity','ICICI Lombard','POL-MNP-PI-2406',
     80000000.00,640000.00,'2025-05-20','2026-05-19','no_gap',3,'settled',85,'claims_ready','Two OB-GYN claims settled within limits'),
    ('AIIMS New Delhi Ansari Nagar','asset_fire_property','Oriental Insurance','POL-AIM-AS-2407',
     5000000000.00,7500000.00,'2025-04-01','2026-03-31','uninsured_exposure',0,'no_claims',52,'high_exposure','New research block not yet added to policy schedule'),
    ('AIIMS New Delhi Ansari Nagar','directors_officers','Tata AIG','POL-AIM-DO-2408',
     250000000.00,1900000.00,'2025-10-01','2026-09-30','no_gap',1,'under_assessment',83,'claims_ready','D&O for governing body — one regulatory notice'),
    ('KIMS Secunderabad','cyber_liability','HDFC Ergo','POL-KIM-CY-2409',
     100000000.00,900000.00,'2024-12-01','2026-01-31','material_gap',2,'repudiated',44,'non_compliant','Policy lapsed 3 months — claim repudiated for non-renewal'),
    ('Care Hospitals Banjara Hills','workmen_compensation','National Insurance','POL-CAR-WC-2410',
     30000000.00,210000.00,'2025-08-15','2026-08-14','no_gap',4,'settled',87,'claims_ready','WC claims for lab staff settled promptly'),
    ('Yashoda Somajiguda Hyderabad','marine_transit','New India Assurance','POL-YSH-MT-2411',
     40000000.00,180000.00,'2025-03-01','2026-02-28','minor_gap',1,'approved',76,'minor_gaps','Equipment transit — new MRI import in transit'),
    ('St John''s Bengaluru','professional_indemnity','Bajaj Allianz','POL-STJ-PI-2412',
     90000000.00,700000.00,'2025-06-10','2026-06-09','material_gap',6,'under_assessment',58,'remediation_needed','Rising med-mal claims — SI inadequate vs exposure'),
    ('Rainbow Children''s Hyderabad','gmc_group_medical','Star Health','POL-RBW-GMC-2413',
     60000000.00,2100000.00,'2025-07-15','2026-07-14','over_insured',0,'no_claims',71,'minor_gaps','GMC over-insured relative to headcount — premium optimization')
  ) as q(hosp, pt, ins, pol, si, prem, psd, rnw, gap, cf, cst, rs, rv, nt);

  -- 6 CAPA / follow-up actions — attach to specific policies
  insert into public.insurance_coverage_capa_actions_r3161 (
    coverage_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('POL-FRT-CY-2403','sub_limit_exposure','policy_misclassification','add_cyber_rider','2026-08-15',null,'in_progress','board_risk_committee',1250000.00,'Adding ransomware rider to raise sub-limit to full SI'),
    ('POL-AIM-AS-2407','sum_insured_inadequate','valuation_outdated','increase_sum_insured','2026-04-30',null,'escalated','board_risk_committee',7500000.00,'Research block worth 80cr not on schedule — urgent endorsement'),
    ('POL-KIM-CY-2409','renewal_lapse_risk','broker_delay','engage_new_broker','2026-02-15','2026-02-20','closed','litigation_risk',900000.00,'Reinstated with new broker after lapse — claim in dispute'),
    ('POL-STJ-PI-2412','sum_insured_inadequate','budget_constraint','increase_sum_insured','2026-06-30',null,'open','nabh_finding',700000.00,'SI to be raised to 15cr given claims frequency'),
    ('POL-APL-AS-2402','coverage_gap','valuation_outdated','revalue_assets','2026-03-15','2026-03-10','closed','internal_only',250000.00,'Chartered surveyor revaluation completed pre-renewal'),
    ('POL-MNP-GMC-2405','claim_documentation_missing','documentation_backlog','file_claim_documents','2026-07-10',null,'overdue','irdai_notifiable',180000.00,'Pending discharge summaries holding partial settlement')
  ) as q(pol_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.insurance_coverage_r3161 e
    on e.organization_id = v_org_id and e.policy_number = q.pol_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3161_readiness_verdict_rollup()
returns table(readiness_verdict text, policies bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.insurance_coverage_r3161)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.insurance_coverage_r3161 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3161_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3161_readiness_verdict_rollup() to authenticated;

-- 2) Entity / hospital readiness scorecard
create or replace function public.founder_r3161_entity_scorecard()
returns table(
  hospital_name text,
  total_policies bigint,
  claims_ready bigint,
  high_exposure bigint,
  non_compliant bigint,
  gaps bigint,
  total_claims_filed bigint,
  avg_readiness numeric,
  total_sum_insured numeric
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
    count(*) filter (where l.readiness_verdict in ('claims_ready','audit_ready'))::bigint,
    count(*) filter (where l.readiness_verdict = 'high_exposure')::bigint,
    count(*) filter (where l.readiness_verdict = 'non_compliant')::bigint,
    count(*) filter (where l.coverage_gap_flag in ('minor_gap','material_gap','uninsured_exposure','sub_limit_breach'))::bigint,
    coalesce(sum(l.claims_filed),0)::bigint,
    round(avg(l.readiness_score), 1),
    coalesce(sum(l.sum_insured_rupees),0)::numeric
  from public.insurance_coverage_r3161 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3161_entity_scorecard() from public, anon;
grant execute on function public.founder_r3161_entity_scorecard() to authenticated;

-- 3) Policy-type × coverage-gap matrix
create or replace function public.founder_r3161_policy_type_matrix()
returns table(policy_type text, coverage_gap_flag text, policies bigint, total_sum_insured numeric, avg_readiness numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_type, l.coverage_gap_flag, count(*)::bigint,
    coalesce(sum(l.sum_insured_rupees),0)::numeric,
    round(avg(l.readiness_score), 1)
  from public.insurance_coverage_r3161 l
  group by l.policy_type, l.coverage_gap_flag
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3161_policy_type_matrix() from public, anon;
grant execute on function public.founder_r3161_policy_type_matrix() to authenticated;

-- 4) Renewal timeline trend
create or replace function public.founder_r3161_renewal_trend()
returns table(renewal_date date, renewals bigint, total_premium numeric, avg_readiness numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.renewal_date, count(*)::bigint,
    coalesce(sum(l.premium_rupees),0)::numeric,
    round(avg(l.readiness_score), 1)
  from public.insurance_coverage_r3161 l
  group by l.renewal_date
  order by l.renewal_date;
end;
$$;

revoke execute on function public.founder_r3161_renewal_trend() from public, anon;
grant execute on function public.founder_r3161_renewal_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3161_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.insurance_coverage_capa_actions_r3161 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3161_capa_status_board() from public, anon;
grant execute on function public.founder_r3161_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3161_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.insurance_coverage_capa_actions_r3161)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.insurance_coverage_capa_actions_r3161 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3161_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3161_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3161_regulatory_impact_digest()
returns table(regulatory_impact text, actions bigint, open_actions bigint, total_cost_rupees numeric)
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
  from public.insurance_coverage_capa_actions_r3161 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3161_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3161_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (individual policies of concern)
create or replace function public.founder_r3161_high_risk_queue()
returns table(
  hospital_name text,
  policy_type text,
  insurer_name text,
  renewal_date date,
  coverage_gap_flag text,
  claim_status text,
  readiness_score int,
  readiness_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.policy_type, l.insurer_name, l.renewal_date,
    l.coverage_gap_flag, l.claim_status, l.readiness_score, l.readiness_verdict, l.notes
  from public.insurance_coverage_r3161 l
  where l.readiness_verdict in ('remediation_needed','high_exposure','non_compliant')
     or l.coverage_gap_flag in ('material_gap','uninsured_exposure','sub_limit_breach')
     or l.claim_status = 'repudiated'
  order by l.readiness_score, l.renewal_date;
end;
$$;

revoke execute on function public.founder_r3161_high_risk_queue() from public, anon;
grant execute on function public.founder_r3161_high_risk_queue() to authenticated;
