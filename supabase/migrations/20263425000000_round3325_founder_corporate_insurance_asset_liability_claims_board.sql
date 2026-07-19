-- Round 3325: Founder Corporate Insurance, Asset-Liability & Claims Governance Board
-- Corporate insurance portfolio — policy × insurance type × insurer × sum insured × premium × coverage adequacy × claims YTD × settlement × renewal verdict × CAPA

-- =============================================================================
-- TABLE 1: corporate_insurance_r3325 — per-policy portfolio + claims record
-- =============================================================================
create table if not exists public.corporate_insurance_r3325 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  policy_name text not null,
  insurance_type text not null check (insurance_type in (
    'asset_fire_burglary','public_liability','professional_indemnity','product_liability',
    'marine_transit','directors_officers','cyber_liability','group_asset_floater'
  )),
  insurer text not null,
  sum_insured_rupees numeric(14,2) not null,
  annual_premium_rupees numeric(12,2) not null,
  policy_start date not null,
  policy_end date not null,
  coverage_adequacy text not null check (coverage_adequacy in (
    'adequate','underinsured','overinsured','gap_identified'
  )),
  claims_filed_ytd int not null default 0,
  claims_amount_rupees numeric(14,2) not null default 0,
  claims_settled_rupees numeric(14,2) not null default 0,
  claims_pending int not null default 0,
  deductible_rupees numeric(12,2) not null default 0,
  broker text not null,
  renewal_verdict text not null check (renewal_verdict in (
    'renew_as_is','renegotiate','increase_cover','add_coverage_gap','consolidate','review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.corporate_insurance_r3325 enable row level security;

create index if not exists idx_corporate_insurance_r3325_org on public.corporate_insurance_r3325(organization_id);
create index if not exists idx_corporate_insurance_r3325_end on public.corporate_insurance_r3325(policy_end);
create index if not exists idx_corporate_insurance_r3325_verdict on public.corporate_insurance_r3325(renewal_verdict);

-- =============================================================================
-- TABLE 2: corporate_insurance_capa_actions_r3325 — coverage/claims/renewal CAPA
-- =============================================================================
create table if not exists public.corporate_insurance_capa_actions_r3325 (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.corporate_insurance_r3325(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'coverage_gap','underinsurance','claim_dispute','premium_overpay',
    'policy_lapse_risk','deductible_too_high','exclusion_concern','renewal_overdue'
  )),
  root_cause text not null check (root_cause in (
    'valuation_outdated','asset_addition_unreported','broker_oversight','insurer_delay',
    'documentation_incomplete','market_rate_change','claims_history_adverse','pending_review'
  )),
  corrective_action text not null check (corrective_action in (
    'revalue_and_increase_cover','add_coverage_gap_endorsement','renegotiate_premium',
    'escalate_claim_settlement','consolidate_policies','raise_deductible_review',
    'file_documentation','switch_insurer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  risk_impact text not null check (risk_impact in (
    'board_escalation','financial_material','none','internal_only','audit_finding','statutory_compliance'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.corporate_insurance_capa_actions_r3325 enable row level security;

create index if not exists idx_corp_ins_capa_r3325_policy on public.corporate_insurance_capa_actions_r3325(policy_id);
create index if not exists idx_corp_ins_capa_r3325_status on public.corporate_insurance_capa_actions_r3325(capa_status);

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

  -- 14 policy rows
  insert into public.corporate_insurance_r3325 (
    organization_id, policy_name, insurance_type, insurer,
    sum_insured_rupees, annual_premium_rupees, policy_start, policy_end,
    coverage_adequacy, claims_filed_ytd, claims_amount_rupees, claims_settled_rupees,
    claims_pending, deductible_rupees, broker, renewal_verdict, notes
  )
  select v_org_id, q.pn, q.it, q.ins,
    q.si, q.prem, q.ps::date, q.pe::date,
    q.cadq, q.cfy, q.camt, q.cset,
    q.cpen, q.ded, q.brk, q.rv, q.nt
  from (values
    ('Standard Fire & Special Perils - HQ & Warehouses','asset_fire_burglary','New India Assurance',
     250000000,425000,'2025-04-01','2026-03-31','adequate',1,850000,850000,0,100000,'Marsh India','renew_as_is','HQ Chennai plus 3 regional warehouses on schedule'),
    ('Public Liability - Field Service Ops','public_liability','ICICI Lombard',
     100000000,310000,'2025-04-01','2026-03-31','adequate',0,0,0,0,50000,'Marsh India','renew_as_is','Third-party bodily injury and property at customer sites'),
    ('Professional Indemnity - Biomedical Engineers','professional_indemnity','Bajaj Allianz',
     150000000,720000,'2025-06-01','2026-05-31','underinsured',2,4200000,1800000,1,250000,'Aon India','increase_cover','PI limit 15cr low vs contract exposure - raise to 25cr'),
    ('Product Liability - Spare Parts Distribution','product_liability','Tata AIG',
     120000000,540000,'2025-05-15','2026-05-14','gap_identified',1,2600000,0,1,200000,'Prudent Insurance Brokers','add_coverage_gap','Refurbished parts not covered - endorsement needed'),
    ('Marine Transit - Equipment Movement','marine_transit','Oriental Insurance',
     80000000,185000,'2025-04-01','2026-03-31','adequate',3,950000,720000,1,25000,'Howden India','renew_as_is','Open cover for inland plus import transit'),
    ('Directors & Officers Liability','directors_officers','HDFC Ergo',
     200000000,1150000,'2025-07-01','2026-06-30','adequate',0,0,0,0,500000,'Marsh India','renegotiate','Premium high vs peer benchmark - renegotiate at renewal'),
    ('Cyber Liability - Platform & Data','cyber_liability','ICICI Lombard',
     90000000,680000,'2025-08-01','2026-07-31','underinsured',1,3100000,900000,1,300000,'Aon India','increase_cover','Ransomware sub-limit inadequate for SaaS exposure'),
    ('Group Asset Floater - Diagnostic Loaners','group_asset_floater','United India Insurance',
     60000000,220000,'2025-04-01','2026-03-31','overinsured',0,0,0,0,40000,'Prudent Insurance Brokers','consolidate','Loaner fleet shrunk - reduce SI and consolidate'),
    ('Standard Fire - Regional Service Centres','asset_fire_burglary','National Insurance',
     90000000,165000,'2025-09-01','2026-08-31','gap_identified',1,1400000,1400000,0,50000,'Howden India','add_coverage_gap','Hyderabad centre not on schedule - add location'),
    ('Public Liability - Warehouse & Logistics','public_liability','SBI General',
     75000000,145000,'2025-04-01','2026-03-31','adequate',0,0,0,0,25000,'Anand Rathi Insurance Brokers','review','Pending vendor contract review before renewal'),
    ('Professional Indemnity - Calibration Lab','professional_indemnity','Cholamandalam MS',
     50000000,260000,'2025-10-01','2026-09-30','adequate',1,620000,620000,0,100000,'Aon India','renew_as_is','NABL cal-lab errors and omissions cover'),
    ('Product Liability - OEM Resale','product_liability','Reliance General',
     100000000,480000,'2025-05-01','2026-04-30','underinsured',2,5400000,2100000,2,250000,'Marsh India','increase_cover','Two open recall-linked claims - raise limit'),
    ('Marine Transit - Import Consignments','marine_transit','Bajaj Allianz',
     120000000,240000,'2025-04-01','2026-03-31','adequate',2,1850000,1600000,0,30000,'Howden India','renew_as_is','CIF import cover for high-value modalities'),
    ('Cyber Liability - Endpoint & Field Devices','cyber_liability','Tata AIG',
     40000000,210000,'2025-11-01','2026-10-31','gap_identified',0,0,0,0,150000,'Prudent Insurance Brokers','add_coverage_gap','BYOD field tablets excluded - add endorsement')
  ) as q(pn, it, ins, si, prem, ps, pe, cadq, cfy, camt, cset, cpen, ded, brk, rv, nt);

  -- CAPA seed — attach to at-risk policies via policy_name
  insert into public.corporate_insurance_capa_actions_r3325 (
    policy_id, finding_category, root_cause, corrective_action,
    capa_status, risk_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Professional Indemnity - Biomedical Engineers','underinsurance','valuation_outdated','revalue_and_increase_cover','in_progress','board_escalation','2026-05-31',null,720000,'PI limit 15cr vs 25cr contract exposure - board approval sought'),
    ('Product Liability - Spare Parts Distribution','coverage_gap','asset_addition_unreported','add_coverage_gap_endorsement','open','financial_material','2026-04-30',null,180000,'Refurbished-parts SKUs excluded - endorsement quote pending'),
    ('Cyber Liability - Platform & Data','underinsurance','market_rate_change','renegotiate_premium','escalated','board_escalation','2026-06-15',null,350000,'Ransomware sub-limit 3cr inadequate - escalated to CFO'),
    ('Standard Fire - Regional Service Centres','policy_lapse_risk','documentation_incomplete','file_documentation','closed','audit_finding','2026-03-15','2026-03-10',45000,'Hyderabad centre added to schedule - endorsement issued'),
    ('Product Liability - OEM Resale','claim_dispute','claims_history_adverse','escalate_claim_settlement','overdue','financial_material','2026-02-28',null,260000,'Two recall claims 54L disputed - insurer delaying settlement'),
    ('Cyber Liability - Endpoint & Field Devices','exclusion_concern','broker_oversight','add_coverage_gap_endorsement','verification_pending','internal_only','2026-05-10',null,90000,'BYOD field tablets exclusion - broker sourcing endorsement'),
    ('Group Asset Floater - Diagnostic Loaners','premium_overpay','asset_addition_unreported','consolidate_policies','open','internal_only','2026-03-31',null,0,'Loaner fleet reduced 40pct - consolidate and cut SI at renewal')
  ) as q(pn, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.corporate_insurance_r3325 e
    on e.organization_id = v_org_id and e.policy_name = q.pn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Renewal verdict distribution
create or replace function public.founder_r3325_renewal_verdict_rollup()
returns table(renewal_verdict text, policies bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.corporate_insurance_r3325)
  select l.renewal_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.corporate_insurance_r3325 l
  group by l.renewal_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3325_renewal_verdict_rollup() from public, anon;
grant execute on function public.founder_r3325_renewal_verdict_rollup() to authenticated;

-- 2) Insurer scorecard
create or replace function public.founder_r3325_insurer_scorecard()
returns table(
  insurer text,
  policies bigint,
  total_sum_insured_rupees numeric,
  total_premium_rupees numeric,
  claims_filed bigint,
  total_claims_amount_rupees numeric,
  total_settled_rupees numeric,
  claims_pending bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.insurer,
    count(*)::bigint,
    coalesce(sum(l.sum_insured_rupees),0)::numeric,
    coalesce(sum(l.annual_premium_rupees),0)::numeric,
    coalesce(sum(l.claims_filed_ytd),0)::bigint,
    coalesce(sum(l.claims_amount_rupees),0)::numeric,
    coalesce(sum(l.claims_settled_rupees),0)::numeric,
    coalesce(sum(l.claims_pending),0)::bigint
  from public.corporate_insurance_r3325 l
  group by l.insurer
  order by coalesce(sum(l.sum_insured_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3325_insurer_scorecard() from public, anon;
grant execute on function public.founder_r3325_insurer_scorecard() to authenticated;

-- 3) Insurance type × coverage adequacy matrix
create or replace function public.founder_r3325_type_adequacy_matrix()
returns table(insurance_type text, coverage_adequacy text, policies bigint, total_sum_insured_rupees numeric, total_premium_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.insurance_type, l.coverage_adequacy, count(*)::bigint,
    coalesce(sum(l.sum_insured_rupees),0)::numeric,
    coalesce(sum(l.annual_premium_rupees),0)::numeric
  from public.corporate_insurance_r3325 l
  group by l.insurance_type, l.coverage_adequacy
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3325_type_adequacy_matrix() from public, anon;
grant execute on function public.founder_r3325_type_adequacy_matrix() to authenticated;

-- 4) Policy renewal / expiry trend by end date
create or replace function public.founder_r3325_renewal_expiry_trend()
returns table(policy_end date, policies bigint, total_sum_insured_rupees numeric, total_premium_rupees numeric, underinsured bigint, gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_end,
    count(*)::bigint,
    coalesce(sum(l.sum_insured_rupees),0)::numeric,
    coalesce(sum(l.annual_premium_rupees),0)::numeric,
    count(*) filter (where l.coverage_adequacy = 'underinsured')::bigint,
    count(*) filter (where l.coverage_adequacy = 'gap_identified')::bigint
  from public.corporate_insurance_r3325 l
  group by l.policy_end
  order by l.policy_end;
end;
$$;

revoke execute on function public.founder_r3325_renewal_expiry_trend() from public, anon;
grant execute on function public.founder_r3325_renewal_expiry_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3325_capa_status_board()
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
  from public.corporate_insurance_capa_actions_r3325 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3325_capa_status_board() from public, anon;
grant execute on function public.founder_r3325_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3325_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.corporate_insurance_capa_actions_r3325)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.corporate_insurance_capa_actions_r3325 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3325_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3325_root_cause_pareto() to authenticated;

-- 7) Risk impact digest
create or replace function public.founder_r3325_risk_impact_digest()
returns table(risk_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.risk_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.corporate_insurance_capa_actions_r3325 c
  group by c.risk_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3325_risk_impact_digest() from public, anon;
grant execute on function public.founder_r3325_risk_impact_digest() to authenticated;

-- 8) High-risk policy queue (coverage gaps, underinsurance, pending claims)
create or replace function public.founder_r3325_high_risk_queue()
returns table(
  policy_name text,
  insurance_type text,
  insurer text,
  coverage_adequacy text,
  renewal_verdict text,
  sum_insured_rupees numeric,
  claims_pending int,
  claims_amount_rupees numeric,
  policy_end date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.policy_name, l.insurance_type, l.insurer, l.coverage_adequacy,
    l.renewal_verdict, l.sum_insured_rupees, l.claims_pending, l.claims_amount_rupees,
    l.policy_end, l.notes
  from public.corporate_insurance_r3325 l
  where l.coverage_adequacy in ('underinsured','gap_identified')
     or l.renewal_verdict in ('increase_cover','add_coverage_gap','renegotiate','review')
     or l.claims_pending > 0
  order by l.claims_pending desc, l.sum_insured_rupees desc;
end;
$$;

revoke execute on function public.founder_r3325_high_risk_queue() from public, anon;
grant execute on function public.founder_r3325_high_risk_queue() to authenticated;
