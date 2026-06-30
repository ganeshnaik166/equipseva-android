-- Round 3107: Founder Quarterly Strategic Engineer-Founder Insurance Claims Recovery Pipeline Tracker
-- AMC + accidental damage + equipment-loss insurance claims pipeline with insurer, stage,
-- claimed vs settled amounts, ageing, broker, and recovery actions.

begin;

-- =========================================================================
-- Table 1: insurance_claims_pipeline_r3107
-- =========================================================================
create table if not exists public.insurance_claims_pipeline_r3107 (
  id uuid primary key default gen_random_uuid(),
  claim_reference text not null unique,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  claim_category text not null check (claim_category in (
    'amc_breakdown_cover',
    'accidental_damage',
    'equipment_loss',
    'fire_and_allied_perils',
    'transit_damage',
    'electrical_burnout',
    'water_ingress'
  )),
  equipment_kind text not null check (equipment_kind in (
    'ct_scanner',
    'mri_machine',
    'ultrasound',
    'patient_monitor',
    'ventilator',
    'dialysis_unit',
    'x_ray_unit',
    'autoclave',
    'dental_chair',
    'ophthalmic_unit',
    'anesthesia_workstation',
    'cath_lab'
  )),
  insurer_name text not null check (insurer_name in (
    'New India Assurance',
    'Oriental Insurance',
    'United India Insurance',
    'National Insurance',
    'ICICI Lombard',
    'HDFC ERGO',
    'Bajaj Allianz',
    'Tata AIG',
    'Reliance General',
    'Cholamandalam MS'
  )),
  broker_name text not null check (broker_name in (
    'Marsh India',
    'Aon India',
    'Howden India',
    'Prudent Insurance Brokers',
    'Anand Rathi Insurance',
    'Policybazaar Corporate',
    'Direct - No Broker'
  )),
  stage text not null check (stage in (
    'intimation_pending',
    'surveyor_assigned',
    'surveyor_inspection',
    'documents_pending',
    'documents_submitted',
    'insurer_review',
    'partial_approval',
    'final_approval',
    'settled',
    'rejected',
    'reopened',
    'litigation'
  )),
  claimed_amount_rupees numeric(14,2) not null check (claimed_amount_rupees >= 0),
  approved_amount_rupees numeric(14,2) check (approved_amount_rupees is null or approved_amount_rupees >= 0),
  settled_amount_rupees numeric(14,2) not null default 0 check (settled_amount_rupees >= 0),
  deductible_rupees numeric(14,2) not null default 0 check (deductible_rupees >= 0),
  recovery_ratio_pct numeric(6,2) not null default 0 check (recovery_ratio_pct >= 0 and recovery_ratio_pct <= 100),
  incident_date date not null,
  intimation_date date not null,
  surveyor_visit_date date,
  documents_submitted_date date,
  settlement_target_date date,
  settled_date date,
  ageing_days integer not null default 0 check (ageing_days >= 0),
  policy_number text not null,
  sum_insured_rupees numeric(14,2) not null check (sum_insured_rupees >= 0),
  premium_paid_rupees numeric(14,2) not null check (premium_paid_rupees >= 0),
  amc_contract_id uuid references public.amc_contracts(id) on delete set null,
  repair_job_id uuid references public.repair_jobs(id) on delete set null,
  engineer_id uuid references public.engineers(id) on delete set null,
  surveyor_name text,
  rejection_reason text check (rejection_reason is null or rejection_reason in (
    'policy_lapsed',
    'exclusion_clause',
    'late_intimation',
    'insufficient_documents',
    'fraud_suspicion',
    'pre_existing_damage',
    'wear_and_tear',
    'not_applicable'
  )),
  recovery_action text not null check (recovery_action in (
    'await_surveyor',
    'escalate_to_broker',
    'submit_pending_docs',
    'broker_pursue_settlement',
    'escalate_to_ombudsman',
    'file_consumer_complaint',
    'accept_partial_close',
    'no_action_required'
  )),
  priority text not null check (priority in ('low','medium','high','critical')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_icp_r3107_org on public.insurance_claims_pipeline_r3107(organization_id);
create index if not exists idx_icp_r3107_stage on public.insurance_claims_pipeline_r3107(stage);
create index if not exists idx_icp_r3107_insurer on public.insurance_claims_pipeline_r3107(insurer_name);

-- =========================================================================
-- Table 2: insurance_claim_recovery_actions_r3107
-- =========================================================================
create table if not exists public.insurance_claim_recovery_actions_r3107 (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null references public.insurance_claims_pipeline_r3107(id) on delete cascade,
  action_kind text not null check (action_kind in (
    'broker_followup',
    'insurer_email',
    'surveyor_pushback',
    'document_resubmission',
    'ombudsman_filing',
    'legal_notice',
    'partial_acceptance',
    'reopen_request',
    'photo_evidence_upload',
    'expert_opinion_sought'
  )),
  action_status text not null check (action_status in (
    'planned',
    'in_progress',
    'awaiting_response',
    'completed',
    'blocked',
    'escalated'
  )),
  owner_role text not null check (owner_role in (
    'founder',
    'ops_lead',
    'finance_lead',
    'engineer',
    'broker',
    'external_counsel'
  )),
  owner_profile_id uuid references public.profiles(id) on delete set null,
  amount_at_stake_rupees numeric(14,2) not null check (amount_at_stake_rupees >= 0),
  amount_recovered_rupees numeric(14,2) not null default 0 check (amount_recovered_rupees >= 0),
  due_date date not null,
  completed_date date,
  outcome text check (outcome is null or outcome in (
    'recovered_full',
    'recovered_partial',
    'rejected',
    'pending',
    'escalated_next_level',
    'withdrawn'
  )),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_icra_r3107_claim on public.insurance_claim_recovery_actions_r3107(claim_id);
create index if not exists idx_icra_r3107_status on public.insurance_claim_recovery_actions_r3107(action_status);

-- =========================================================================
-- Seed data
-- =========================================================================
do $seed$
declare
  v_org uuid;
  v_claim_a uuid;
  v_claim_b uuid;
  v_claim_c uuid;
  v_claim_d uuid;
begin
  select id into v_org from public.organizations order by created_at asc limit 1;
  if v_org is null then
    raise notice 'r3107 seed skipped: no organizations';
    return;
  end if;

  insert into public.insurance_claims_pipeline_r3107 (
    claim_reference, organization_id, claim_category, equipment_kind, insurer_name, broker_name,
    stage, claimed_amount_rupees, approved_amount_rupees, settled_amount_rupees, deductible_rupees,
    recovery_ratio_pct, incident_date, intimation_date, surveyor_visit_date, documents_submitted_date,
    settlement_target_date, settled_date, ageing_days, policy_number, sum_insured_rupees,
    premium_paid_rupees, surveyor_name, rejection_reason, recovery_action, priority
  ) values
    ('CLM-NIA-2026-0411', v_org, 'accidental_damage', 'ct_scanner', 'New India Assurance', 'Marsh India',
     'settled', 1850000, 1620000, 1620000, 50000, 87.57, '2026-03-12', '2026-03-14', '2026-03-19', '2026-03-25',
     '2026-05-30', '2026-05-22', 71, 'NIA/EQ/2024/8821', 25000000, 188000, 'Rakesh Kulkarni', 'not_applicable',
     'no_action_required', 'medium'),
    ('CLM-ICL-2026-0512', v_org, 'fire_and_allied_perils', 'mri_machine', 'ICICI Lombard', 'Aon India',
     'litigation', 9800000, 4200000, 0, 100000, 0.00, '2026-04-18', '2026-04-20', '2026-04-27', '2026-05-10',
     '2026-07-25', null, 64, 'ICL/CORP/9912', 95000000, 720000, 'Surveyor Synergy LLP', 'pre_existing_damage',
     'file_consumer_complaint', 'critical'),
    ('CLM-HDF-2026-0613', v_org, 'electrical_burnout', 'cath_lab', 'HDFC ERGO', 'Howden India',
     'insurer_review', 2750000, null, 0, 75000, 0.00, '2026-05-09', '2026-05-10', '2026-05-15', '2026-05-22',
     '2026-07-15', null, 42, 'HDFC/CORP/EQP/2287', 32000000, 412000, 'IRS Surveyors', null,
     'broker_pursue_settlement', 'high'),
    ('CLM-BAJ-2026-0714', v_org, 'water_ingress', 'patient_monitor', 'Bajaj Allianz', 'Prudent Insurance Brokers',
     'partial_approval', 380000, 215000, 215000, 25000, 56.58, '2026-04-02', '2026-04-04', '2026-04-09', '2026-04-15',
     '2026-06-10', '2026-06-04', 63, 'BAJ/CORP/4451', 4500000, 38000, 'Mehta Surveyors', null,
     'accept_partial_close', 'medium'),
    ('CLM-TAT-2026-0815', v_org, 'amc_breakdown_cover', 'ventilator', 'Tata AIG', 'Direct - No Broker',
     'documents_submitted', 145000, null, 0, 10000, 0.00, '2026-05-21', '2026-05-22', '2026-05-25', '2026-05-31',
     '2026-07-20', null, 30, 'TAG/AMC/1101', 1800000, 24500, 'TPA Mediclaim', null,
     'submit_pending_docs', 'medium'),
    ('CLM-OIC-2026-0916', v_org, 'transit_damage', 'autoclave', 'Oriental Insurance', 'Marsh India',
     'settled', 215000, 198000, 198000, 7500, 92.09, '2026-02-14', '2026-02-16', '2026-02-22', '2026-02-28',
     '2026-04-30', '2026-04-21', 64, 'OIC/MARINE/3309', 2200000, 18800, 'Marine Surveyor Singh', 'not_applicable',
     'no_action_required', 'low'),
    ('CLM-UIN-2026-1017', v_org, 'equipment_loss', 'ultrasound', 'United India Insurance', 'Anand Rathi Insurance',
     'rejected', 680000, 0, 0, 25000, 0.00, '2026-03-30', '2026-04-02', '2026-04-08', '2026-04-15',
     '2026-06-20', null, 81, 'UIN/CORP/5571', 7500000, 65000, 'CMC Surveyors', 'late_intimation',
     'escalate_to_ombudsman', 'high'),
    ('CLM-NAT-2026-1118', v_org, 'accidental_damage', 'dialysis_unit', 'National Insurance', 'Policybazaar Corporate',
     'surveyor_inspection', 920000, null, 0, 50000, 0.00, '2026-05-28', '2026-05-30', '2026-06-02', null,
     '2026-07-30', null, 22, 'NAT/CORP/8812', 11000000, 132000, 'Pioneer Surveyors', null,
     'await_surveyor', 'high'),
    ('CLM-REL-2026-1219', v_org, 'fire_and_allied_perils', 'x_ray_unit', 'Reliance General', 'Howden India',
     'final_approval', 1450000, 1280000, 0, 50000, 0.00, '2026-04-12', '2026-04-14', '2026-04-19', '2026-04-28',
     '2026-06-30', null, 69, 'REL/CORP/2274', 15500000, 248000, 'Indo Surveyors', null,
     'broker_pursue_settlement', 'medium'),
    ('CLM-CHL-2026-1320', v_org, 'electrical_burnout', 'anesthesia_workstation', 'Cholamandalam MS', 'Aon India',
     'reopened', 540000, 180000, 180000, 15000, 33.33, '2026-01-18', '2026-01-20', '2026-01-28', '2026-02-05',
     '2026-04-15', null, 152, 'CHL/CORP/1144', 6800000, 95000, 'Surveyor Pal', null,
     'escalate_to_ombudsman', 'critical'),
    ('CLM-NIA-2026-1421', v_org, 'amc_breakdown_cover', 'dental_chair', 'New India Assurance', 'Direct - No Broker',
     'intimation_pending', 95000, null, 0, 5000, 0.00, '2026-06-15', '2026-06-16', null, null,
     '2026-08-15', null, 5, 'NIA/AMC/6691', 850000, 12500, null, null,
     'await_surveyor', 'low'),
    ('CLM-ICL-2026-1522', v_org, 'water_ingress', 'ophthalmic_unit', 'ICICI Lombard', 'Prudent Insurance Brokers',
     'documents_pending', 312000, null, 0, 12000, 0.00, '2026-05-02', '2026-05-04', '2026-05-09', null,
     '2026-07-04', null, 48, 'ICL/CORP/7782', 3800000, 41000, 'Surveyor Synergy LLP', null,
     'submit_pending_docs', 'medium'),
    ('CLM-HDF-2026-1623', v_org, 'transit_damage', 'patient_monitor', 'HDFC ERGO', 'Marsh India',
     'partial_approval', 178000, 92000, 92000, 8000, 51.69, '2026-03-22', '2026-03-24', '2026-03-30', '2026-04-04',
     '2026-05-25', '2026-05-19', 56, 'HDF/MARINE/4451', 2100000, 22500, 'Marine Surveyor Singh', null,
     'accept_partial_close', 'low');

  select id into v_claim_a from public.insurance_claims_pipeline_r3107 where claim_reference = 'CLM-ICL-2026-0512' limit 1;
  select id into v_claim_b from public.insurance_claims_pipeline_r3107 where claim_reference = 'CLM-CHL-2026-1320' limit 1;
  select id into v_claim_c from public.insurance_claims_pipeline_r3107 where claim_reference = 'CLM-UIN-2026-1017' limit 1;
  select id into v_claim_d from public.insurance_claims_pipeline_r3107 where claim_reference = 'CLM-HDF-2026-0613' limit 1;

  insert into public.insurance_claim_recovery_actions_r3107 (
    claim_id, action_kind, action_status, owner_role, amount_at_stake_rupees, amount_recovered_rupees,
    due_date, completed_date, outcome, notes
  ) values
    (v_claim_a, 'legal_notice', 'in_progress', 'external_counsel', 4200000, 0, '2026-07-10', null, 'pending',
     'Section 138 + IRDAI complaint drafted; pre_existing_damage rebuttal with OEM certificate attached.'),
    (v_claim_a, 'broker_followup', 'escalated', 'broker', 4200000, 0, '2026-06-25', null, 'escalated_next_level',
     'Aon escalated to ICICI Lombard corporate desk; awaiting senior surveyor re-inspection.'),
    (v_claim_b, 'ombudsman_filing', 'awaiting_response', 'ops_lead', 360000, 0, '2026-07-05', null, 'pending',
     'IRDAI ombudsman intake done; hearing date pending; partial 180k already received Jan 2026.'),
    (v_claim_b, 'expert_opinion_sought', 'completed', 'engineer', 360000, 0, '2026-06-10', '2026-06-08', 'pending',
     'OEM service engineer report obtained — burnout caused by upstream voltage spike, not internal fault.'),
    (v_claim_c, 'ombudsman_filing', 'planned', 'ops_lead', 680000, 0, '2026-07-20', null, 'pending',
     'late_intimation rejection — preparing reasonable-cause submission with hospital outage log.'),
    (v_claim_c, 'document_resubmission', 'completed', 'finance_lead', 680000, 0, '2026-06-15', '2026-06-14', 'pending',
     'FIR, hospital incident log, and CCTV stills attached to ombudsman bundle.'),
    (v_claim_d, 'broker_followup', 'in_progress', 'broker', 2750000, 0, '2026-07-05', null, 'pending',
     'Howden pushing for 80% approval; HDFC ERGO surveyor report flags 20% pre-event wear.'),
    (v_claim_d, 'photo_evidence_upload', 'completed', 'engineer', 2750000, 0, '2026-05-20', '2026-05-18', 'pending',
     'Pre-event AMC inspection photos from Feb 2026 submitted to refute wear-and-tear assertion.'),
    (v_claim_d, 'insurer_email', 'awaiting_response', 'finance_lead', 2750000, 0, '2026-06-30', null, 'pending',
     'Formal letter to HDFC ERGO claims VP citing settlement precedent on similar cath-lab burnout claim.');
end;
$seed$;

-- =========================================================================
-- RPCs (founder-gated)
-- =========================================================================

create or replace function public.founder_r3107_pipeline_overview()
returns table(
  stage text,
  claim_count integer,
  claimed_total_rupees numeric,
  approved_total_rupees numeric,
  settled_total_rupees numeric,
  avg_ageing_days numeric,
  outstanding_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.stage,
    count(*)::int,
    sum(c.claimed_amount_rupees)::numeric,
    coalesce(sum(c.approved_amount_rupees),0)::numeric,
    sum(c.settled_amount_rupees)::numeric,
    round(avg(c.ageing_days)::numeric, 1),
    sum(coalesce(c.approved_amount_rupees, c.claimed_amount_rupees) - c.settled_amount_rupees)::numeric
  from public.insurance_claims_pipeline_r3107 c
  group by c.stage
  order by sum(c.claimed_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3107_pipeline_overview() from public, anon;
grant execute on function public.founder_r3107_pipeline_overview() to authenticated;

create or replace function public.founder_r3107_insurer_performance()
returns table(
  insurer_name text,
  claim_count integer,
  claimed_total_rupees numeric,
  settled_total_rupees numeric,
  recovery_pct numeric,
  avg_settlement_days numeric,
  rejected_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.insurer_name,
    count(*)::int,
    sum(c.claimed_amount_rupees)::numeric,
    sum(c.settled_amount_rupees)::numeric,
    round(case when sum(c.claimed_amount_rupees) = 0 then 0
      else (sum(c.settled_amount_rupees) / sum(c.claimed_amount_rupees)) * 100 end, 2),
    round(avg(c.ageing_days)::numeric, 1),
    count(*) filter (where c.stage = 'rejected')::int
  from public.insurance_claims_pipeline_r3107 c
  group by c.insurer_name
  order by sum(c.claimed_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3107_insurer_performance() from public, anon;
grant execute on function public.founder_r3107_insurer_performance() to authenticated;

create or replace function public.founder_r3107_broker_scorecard()
returns table(
  broker_name text,
  claim_count integer,
  claimed_total_rupees numeric,
  settled_total_rupees numeric,
  recovery_pct numeric,
  open_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.broker_name,
    count(*)::int,
    sum(c.claimed_amount_rupees)::numeric,
    sum(c.settled_amount_rupees)::numeric,
    round(case when sum(c.claimed_amount_rupees) = 0 then 0
      else (sum(c.settled_amount_rupees) / sum(c.claimed_amount_rupees)) * 100 end, 2),
    count(*) filter (where c.stage not in ('settled','rejected'))::int
  from public.insurance_claims_pipeline_r3107 c
  group by c.broker_name
  order by sum(c.claimed_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3107_broker_scorecard() from public, anon;
grant execute on function public.founder_r3107_broker_scorecard() to authenticated;

create or replace function public.founder_r3107_ageing_buckets()
returns table(
  bucket text,
  claim_count integer,
  outstanding_rupees numeric,
  critical_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when c.ageing_days <= 30 then '0-30 days'
      when c.ageing_days <= 60 then '31-60 days'
      when c.ageing_days <= 90 then '61-90 days'
      when c.ageing_days <= 120 then '91-120 days'
      else '120+ days'
    end as bucket,
    count(*)::int,
    sum(coalesce(c.approved_amount_rupees, c.claimed_amount_rupees) - c.settled_amount_rupees)::numeric,
    count(*) filter (where c.priority = 'critical')::int
  from public.insurance_claims_pipeline_r3107 c
  where c.stage not in ('settled','rejected')
  group by bucket
  order by min(c.ageing_days);
end;
$$;

revoke execute on function public.founder_r3107_ageing_buckets() from public, anon;
grant execute on function public.founder_r3107_ageing_buckets() to authenticated;

create or replace function public.founder_r3107_category_breakdown()
returns table(
  claim_category text,
  claim_count integer,
  claimed_total_rupees numeric,
  settled_total_rupees numeric,
  recovery_pct numeric,
  avg_deductible_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.claim_category,
    count(*)::int,
    sum(c.claimed_amount_rupees)::numeric,
    sum(c.settled_amount_rupees)::numeric,
    round(case when sum(c.claimed_amount_rupees) = 0 then 0
      else (sum(c.settled_amount_rupees) / sum(c.claimed_amount_rupees)) * 100 end, 2),
    round(avg(c.deductible_rupees)::numeric, 2)
  from public.insurance_claims_pipeline_r3107 c
  group by c.claim_category
  order by sum(c.claimed_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3107_category_breakdown() from public, anon;
grant execute on function public.founder_r3107_category_breakdown() to authenticated;

create or replace function public.founder_r3107_recovery_actions_summary()
returns table(
  action_kind text,
  action_count integer,
  open_count integer,
  amount_at_stake_rupees numeric,
  amount_recovered_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    a.action_kind,
    count(*)::int,
    count(*) filter (where a.action_status in ('planned','in_progress','awaiting_response','blocked','escalated'))::int,
    sum(a.amount_at_stake_rupees)::numeric,
    sum(a.amount_recovered_rupees)::numeric
  from public.insurance_claim_recovery_actions_r3107 a
  group by a.action_kind
  order by sum(a.amount_at_stake_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3107_recovery_actions_summary() from public, anon;
grant execute on function public.founder_r3107_recovery_actions_summary() to authenticated;

create or replace function public.founder_r3107_priority_watchlist()
returns table(
  claim_reference text,
  insurer_name text,
  stage text,
  priority text,
  claimed_amount_rupees numeric,
  outstanding_rupees numeric,
  ageing_days integer,
  recovery_action text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.claim_reference,
    c.insurer_name,
    c.stage,
    c.priority,
    c.claimed_amount_rupees,
    (coalesce(c.approved_amount_rupees, c.claimed_amount_rupees) - c.settled_amount_rupees)::numeric,
    c.ageing_days,
    c.recovery_action
  from public.insurance_claims_pipeline_r3107 c
  where c.priority in ('high','critical') and c.stage not in ('settled','rejected')
  order by
    case c.priority when 'critical' then 0 when 'high' then 1 else 2 end,
    c.ageing_days desc;
end;
$$;

revoke execute on function public.founder_r3107_priority_watchlist() from public, anon;
grant execute on function public.founder_r3107_priority_watchlist() to authenticated;

create or replace function public.founder_r3107_rejection_analysis()
returns table(
  rejection_reason text,
  claim_count integer,
  claimed_total_rupees numeric,
  insurers_affected integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    coalesce(c.rejection_reason, 'pending_decision') as rejection_reason,
    count(*)::int,
    sum(c.claimed_amount_rupees)::numeric,
    count(distinct c.insurer_name)::int
  from public.insurance_claims_pipeline_r3107 c
  where c.stage in ('rejected','partial_approval','litigation','reopened')
  group by coalesce(c.rejection_reason, 'pending_decision')
  order by sum(c.claimed_amount_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3107_rejection_analysis() from public, anon;
grant execute on function public.founder_r3107_rejection_analysis() to authenticated;

commit;
