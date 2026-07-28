-- Round 3549: Founder R&D Tax-Credit / Weighted-Deduction Incentive Board
-- R&D tax-credit / weighted-deduction claim tracking + eligibility — project × category × eligible spend × weighted deduction % × deduction claimed × tax benefit × documentation status × claim status × monthly trend × CAPA

-- =============================================================================
-- TABLE 1: rnd_tax_credit_r3549 — per-project R&D tax-credit / weighted-deduction claims
-- =============================================================================
create table if not exists public.rnd_tax_credit_r3549 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  claim_code text not null,
  entity_name text not null,
  project_name text not null,
  rnd_category text not null check (rnd_category in (
    'product_dev','process_improvement','software','clinical_validation','prototype','other'
  )),
  financial_year text not null,
  period_month date not null,
  eligible_spend_rupees numeric(14,2) not null,
  weighted_deduction_pct numeric(6,2) not null,
  deduction_claimed_rupees numeric(14,2) not null,
  tax_benefit_rupees numeric(14,2) not null,
  documentation_status text not null check (documentation_status in (
    'complete','partial','missing','under_review'
  )),
  claim_status text not null check (claim_status in (
    'filed','approved','queried','disallowed','pending'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rnd_tax_credit_r3549 enable row level security;

create index if not exists idx_rnd_tax_credit_r3549_org on public.rnd_tax_credit_r3549(organization_id);
create index if not exists idx_rnd_tax_credit_r3549_month on public.rnd_tax_credit_r3549(period_month);
create index if not exists idx_rnd_tax_credit_r3549_status on public.rnd_tax_credit_r3549(claim_status);

-- =============================================================================
-- TABLE 2: rnd_tax_credit_capa_actions_r3549 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.rnd_tax_credit_capa_actions_r3549 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  claim_code text not null,
  finding_category text not null check (finding_category in (
    'missing_timesheet_evidence','ineligible_expense_claimed','weighted_rate_misapplied',
    'documentation_incomplete','project_not_dsir_approved','capitalization_error',
    'duplicate_claim','late_filing'
  )),
  root_cause text not null check (root_cause in (
    'poor_record_keeping','misinterpretation_of_rules','dsir_approval_lapsed',
    'vendor_invoice_missing','staff_allocation_untracked','accounting_system_gap',
    'pending_investigation','filing_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'reconstruct_timesheets','reclassify_expense','refile_amended_return',
    'obtain_dsir_certificate','strengthen_documentation','engage_tax_consultant',
    'remove_ineligible_claim','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'dsir_notifiable','income_tax_scrutiny','none','internal_only','penalty_risk','claim_reversal_risk'
  )),
  recovered_benefit_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rnd_tax_credit_capa_actions_r3549 enable row level security;

create index if not exists idx_rnd_tax_credit_capa_r3549_org on public.rnd_tax_credit_capa_actions_r3549(organization_id);
create index if not exists idx_rnd_tax_credit_capa_r3549_code on public.rnd_tax_credit_capa_actions_r3549(claim_code);
create index if not exists idx_rnd_tax_credit_capa_r3549_status on public.rnd_tax_credit_capa_actions_r3549(capa_status);

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

  -- 16 R&D tax-credit claim rows
  insert into public.rnd_tax_credit_r3549 (
    organization_id, claim_code, entity_name, project_name, rnd_category, financial_year,
    period_month, eligible_spend_rupees, weighted_deduction_pct, deduction_claimed_rupees,
    tax_benefit_rupees, documentation_status, claim_status, notes
  )
  select v_org_id, q.ccode, q.ent, q.proj, q.cat, q.fy,
    q.pm::date, q.espend, q.wpct, q.dclaim,
    q.tben, q.docst, q.clst, q.nt
  from (values
    ('RND-2024-01','EquipSeva Labs','Predictive Failure ML Engine','software','2024-25',
     '2024-06-01',4800000,150,7200000,1800000,'complete','approved','DSIR-approved software R&D — 150% weighted deduction approved by AO'),
    ('RND-2024-02','EquipSeva Labs','Portable Dialysis Unit Prototype','prototype','2024-25',
     '2024-07-01',6200000,150,9300000,2325000,'complete','approved','In-house prototype build — weighted deduction approved'),
    ('RND-2024-03','EquipSeva Devices','Ventilator Firmware v3','product_dev','2024-25',
     '2024-08-01',3100000,100,3100000,775000,'partial','filed','Firmware product development — vendor invoice pending on record'),
    ('RND-2024-04','EquipSeva Devices','RO Water Plant IoT Retrofit','process_improvement','2024-25',
     '2024-09-01',1800000,100,1800000,450000,'under_review','queried','AO queried 150% claim on process improvement — under review'),
    ('RND-2024-05','EquipSeva Clinical','Infusion Pump Clinical Validation','clinical_validation','2024-25',
     '2024-10-01',5400000,150,8100000,2025000,'complete','approved','Clinical validation study — DSIR recognised, approved'),
    ('RND-2024-06','EquipSeva Labs','AI Triage Scheduling Module','software','2024-25',
     '2024-11-01',2600000,150,3900000,975000,'missing','disallowed','Marketing spend misclassified as R&D — claim disallowed'),
    ('RND-2024-07','EquipSeva Devices','Autoclave Sensor Redesign','product_dev','2024-25',
     '2024-12-01',2200000,100,2200000,550000,'partial','queried','Engineer timesheet evidence incomplete — queried by AO'),
    ('RND-2024-08','EquipSeva Clinical','Endoscope Reprocessing Study','clinical_validation','2025-26',
     '2025-04-01',4100000,150,6150000,1537500,'under_review','pending','Filing delayed past due date — pending submission'),
    ('RND-2024-09','EquipSeva Labs','Spare-Parts Demand Forecast Engine','software','2025-26',
     '2025-05-01',3300000,150,4950000,1237500,'complete','filed','Software R&D filed with full documentation'),
    ('RND-2024-10','EquipSeva Devices','Modular Dental Chair Prototype','prototype','2025-26',
     '2025-06-01',2900000,150,4350000,1087500,'partial','queried','Prototype BOM invoices incomplete — queried'),
    ('RND-2024-11','EquipSeva Labs','Calibration Lab Automation','process_improvement','2025-26',
     '2025-07-01',1500000,100,1500000,375000,'complete','approved','Process automation claim approved at 100%'),
    ('RND-2024-12','EquipSeva Clinical','Dialysis Water Endotoxin Assay','clinical_validation','2025-26',
     '2025-08-01',3700000,150,5550000,1387500,'missing','disallowed','DSIR recognition lapsed — claim disallowed'),
    ('RND-2024-13','EquipSeva Devices','Patient Monitor Alarm Redesign','product_dev','2025-26',
     '2025-09-01',2400000,100,2400000,600000,'partial','filed','Product development claim filed — docs being strengthened'),
    ('RND-2024-14','EquipSeva Labs','Biomed Asset Blockchain Ledger','other','2025-26',
     '2025-10-01',1200000,100,1200000,300000,'under_review','pending','Eligibility of blockchain ledger R&D under internal review'),
    ('RND-2024-15','EquipSeva Devices','Surgical Drill Torque Controller','product_dev','2025-26',
     '2025-11-01',3900000,150,5850000,1462500,'complete','filed','Torque controller product development filed with DSIR cert'),
    ('RND-2024-16','EquipSeva Clinical','Telemetry Coverage Optimization','software','2025-26',
     '2025-12-01',2050000,150,3075000,768750,'partial','queried','Classification software vs process queried by AO')
  ) as q(ccode, ent, proj, cat, fy, pm, espend, wpct, dclaim, tben, docst, clst, nt);

  -- 8 CAPA rows — org-scoped, linked to claims via claim_code
  insert into public.rnd_tax_credit_capa_actions_r3549 (
    organization_id, claim_code, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, recovered_benefit_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, q.ccode, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.rec, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('RND-2024-06','ineligible_expense_claimed','misinterpretation_of_rules','remove_ineligible_claim','closed','claim_reversal_risk',975000,'Tax Team','2025-02-15','2025-02-10','Marketing spend wrongly claimed as software R&D — removed and refiled'),
    ('RND-2024-12','project_not_dsir_approved','dsir_approval_lapsed','obtain_dsir_certificate','escalated','claim_reversal_risk',1387500,'R&D Finance','2025-11-30',null,'DSIR recognition lapsed for clinical lab — reapplication in progress'),
    ('RND-2024-04','weighted_rate_misapplied','misinterpretation_of_rules','refile_amended_return','in_progress','income_tax_scrutiny',450000,'Tax Team','2025-01-31',null,'AO queried 150% rate on process improvement — refiling at 100%'),
    ('RND-2024-07','missing_timesheet_evidence','staff_allocation_untracked','reconstruct_timesheets','verification_pending','penalty_risk',550000,'R&D Finance','2025-02-28',null,'Engineer time allocation not logged — reconstructing from JIRA'),
    ('RND-2024-10','documentation_incomplete','poor_record_keeping','strengthen_documentation','open','internal_only',1087500,'Priya Nair','2025-08-31',null,'Prototype BOM invoices incomplete — collating vendor bills'),
    ('RND-2024-16','weighted_rate_misapplied','accounting_system_gap','engage_tax_consultant','in_progress','income_tax_scrutiny',768750,'Tax Team','2025-09-30',null,'Telemetry classed as software vs process — consultant engaged'),
    ('RND-2024-03','documentation_incomplete','vendor_invoice_missing','strengthen_documentation','closed','internal_only',0,'Rahul Menon','2024-12-20','2024-12-18','Firmware vendor invoice retrieved — documentation completed'),
    ('RND-2024-08','late_filing','filing_delay','refile_amended_return','overdue','penalty_risk',1537500,'R&D Finance','2025-07-15',null,'Clinical validation claim filing delayed past due date')
  ) as q(ccode, fc, rc, ca, cst, ri, rec, own, tcd, acd, nt);
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Claim status distribution
create or replace function public.founder_r3549_claim_status_rollup()
returns table(claim_status text, claims bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rnd_tax_credit_r3549)
  select l.claim_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.rnd_tax_credit_r3549 l
  group by l.claim_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3549_claim_status_rollup() from public, anon;
grant execute on function public.founder_r3549_claim_status_rollup() to authenticated;

-- 2) R&D category scorecard
create or replace function public.founder_r3549_category_scorecard()
returns table(
  rnd_category text,
  total_claims bigint,
  approved bigint,
  filed bigint,
  queried bigint,
  disallowed bigint,
  pending bigint,
  total_eligible_spend_rupees numeric,
  total_deduction_claimed_rupees numeric,
  total_tax_benefit_rupees numeric,
  approval_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rnd_category,
    count(*)::bigint,
    count(*) filter (where l.claim_status = 'approved')::bigint,
    count(*) filter (where l.claim_status = 'filed')::bigint,
    count(*) filter (where l.claim_status = 'queried')::bigint,
    count(*) filter (where l.claim_status = 'disallowed')::bigint,
    count(*) filter (where l.claim_status = 'pending')::bigint,
    coalesce(sum(l.eligible_spend_rupees),0)::numeric,
    coalesce(sum(l.deduction_claimed_rupees),0)::numeric,
    coalesce(sum(l.tax_benefit_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.claim_status = 'approved')::numeric / nullif(count(*),0), 1)
  from public.rnd_tax_credit_r3549 l
  group by l.rnd_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3549_category_scorecard() from public, anon;
grant execute on function public.founder_r3549_category_scorecard() to authenticated;

-- 3) R&D category × claim status matrix
create or replace function public.founder_r3549_category_status_matrix()
returns table(
  rnd_category text,
  claim_status text,
  claims bigint,
  total_eligible_spend_rupees numeric,
  total_tax_benefit_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.rnd_category, l.claim_status, count(*)::bigint,
    coalesce(sum(l.eligible_spend_rupees),0)::numeric,
    coalesce(sum(l.tax_benefit_rupees),0)::numeric
  from public.rnd_tax_credit_r3549 l
  group by l.rnd_category, l.claim_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3549_category_status_matrix() from public, anon;
grant execute on function public.founder_r3549_category_status_matrix() to authenticated;

-- 4) Monthly claim trend
create or replace function public.founder_r3549_monthly_claim_trend()
returns table(
  period_month date,
  claims bigint,
  approved bigint,
  disallowed bigint,
  queried bigint,
  total_tax_benefit_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.claim_status = 'approved')::bigint,
    count(*) filter (where l.claim_status = 'disallowed')::bigint,
    count(*) filter (where l.claim_status = 'queried')::bigint,
    coalesce(sum(l.tax_benefit_rupees),0)::numeric
  from public.rnd_tax_credit_r3549 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3549_monthly_claim_trend() from public, anon;
grant execute on function public.founder_r3549_monthly_claim_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3549_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovered_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovered_benefit_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.rnd_tax_credit_capa_actions_r3549 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3549_capa_status_board() from public, anon;
grant execute on function public.founder_r3549_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3549_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovered_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rnd_tax_credit_capa_actions_r3549)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovered_benefit_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.rnd_tax_credit_capa_actions_r3549 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3549_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3549_root_cause_pareto() to authenticated;

-- 7) Tax-benefit impact digest by documentation status
create or replace function public.founder_r3549_tax_benefit_impact_digest()
returns table(
  documentation_status text,
  claims bigint,
  total_eligible_spend_rupees numeric,
  total_deduction_claimed_rupees numeric,
  total_tax_benefit_rupees numeric,
  avg_weighted_deduction_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.documentation_status,
    count(*)::bigint,
    coalesce(sum(l.eligible_spend_rupees),0)::numeric,
    coalesce(sum(l.deduction_claimed_rupees),0)::numeric,
    coalesce(sum(l.tax_benefit_rupees),0)::numeric,
    round(avg(l.weighted_deduction_pct), 1)
  from public.rnd_tax_credit_r3549 l
  group by l.documentation_status
  order by coalesce(sum(l.tax_benefit_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3549_tax_benefit_impact_digest() from public, anon;
grant execute on function public.founder_r3549_tax_benefit_impact_digest() to authenticated;

-- 8) High-risk claim queue (disallowed / queried / missing or under-review docs)
create or replace function public.founder_r3549_high_risk_queue()
returns table(
  entity_name text,
  claim_code text,
  project_name text,
  rnd_category text,
  period_month date,
  claim_status text,
  documentation_status text,
  eligible_spend_rupees numeric,
  tax_benefit_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.claim_code, l.project_name, l.rnd_category, l.period_month,
    l.claim_status, l.documentation_status, l.eligible_spend_rupees, l.tax_benefit_rupees, l.notes
  from public.rnd_tax_credit_r3549 l
  where l.claim_status in ('disallowed','queried','pending')
     or l.documentation_status in ('missing','under_review')
  order by l.period_month desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3549_high_risk_queue() from public, anon;
grant execute on function public.founder_r3549_high_risk_queue() to authenticated;
