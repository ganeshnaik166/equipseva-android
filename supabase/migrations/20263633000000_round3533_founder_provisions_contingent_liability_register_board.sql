-- Round 3533: Founder Provisions / Contingent-Liability Register Board
-- Founder provisions & contingent-liability register — liability type × probability × provision adequacy ×
-- gross exposure × provision made × contingent disclosed × expected resolution × monthly trend × CAPA closure

-- =============================================================================
-- TABLE 1: contingent_liability_r3533 — per-item provision / contingent-liability register
-- =============================================================================
create table if not exists public.contingent_liability_r3533 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  item_name text not null,
  liability_type text not null check (liability_type in (
    'litigation','tax_dispute','warranty','guarantee','regulatory','onerous_contract','other'
  )),
  gross_exposure_rupees numeric(16,2),
  provision_made_rupees numeric(16,2),
  contingent_disclosed_rupees numeric(16,2),
  probability text not null check (probability in (
    'remote','possible','probable','virtually_certain'
  )),
  provision_status text not null check (provision_status in (
    'adequate','under_provided','over_provided','no_provision','settled'
  )),
  expected_resolution date,
  period_month date not null,
  counterparty text,
  jurisdiction text,
  matter_reference text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.contingent_liability_r3533 enable row level security;

create index if not exists idx_contingent_liability_r3533_org on public.contingent_liability_r3533(organization_id);
create index if not exists idx_contingent_liability_r3533_month on public.contingent_liability_r3533(period_month);
create index if not exists idx_contingent_liability_r3533_status on public.contingent_liability_r3533(provision_status);

-- =============================================================================
-- TABLE 2: contingent_liability_capa_actions_r3533 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.contingent_liability_capa_actions_r3533 (
  id uuid primary key default gen_random_uuid(),
  liability_id uuid not null references public.contingent_liability_r3533(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'under_provisioned','over_provisioned','disclosure_gap','contingent_not_disclosed',
    'stale_valuation','missing_legal_opinion','probability_reassessment','settlement_pending','audit_observation'
  )),
  root_cause text not null check (root_cause in (
    'adverse_legal_development','valuation_estimate_revised','new_claim_received','regulatory_change',
    'delayed_management_review','incomplete_documentation','counterparty_dispute',
    'pending_investigation','prior_period_error','settlement_negotiation'
  )),
  corrective_action text not null check (corrective_action in (
    'increase_provision','reduce_provision','add_disclosure_note','obtain_legal_opinion','revalue_exposure',
    'escalate_to_board','engage_external_counsel','settle_and_close','update_accounting_policy','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  provision_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.contingent_liability_capa_actions_r3533 enable row level security;

create index if not exists idx_contingent_liability_capa_r3533_link on public.contingent_liability_capa_actions_r3533(liability_id);
create index if not exists idx_contingent_liability_capa_r3533_status on public.contingent_liability_capa_actions_r3533(capa_status);

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

  -- 15 register rows
  insert into public.contingent_liability_r3533 (
    organization_id, item_name, liability_type, gross_exposure_rupees, provision_made_rupees,
    contingent_disclosed_rupees, probability, provision_status, expected_resolution, period_month,
    counterparty, jurisdiction, matter_reference, notes
  )
  select v_org_id, q.itm, q.ltype, q.gross::numeric, q.prov::numeric,
    q.contd::numeric, q.prob, q.pstat, q.eres::date, q.pmon::date,
    q.cparty, q.juris, q.mref, q.nt
  from (values
    ('GST demand FY22 Chennai','tax_dispute',8500000,5000000,3500000,'probable','under_provided','2026-12-31','2026-07-01',
     'GST Commissionerate Chennai','tax_authority','GST/DRC-01/2022','Show-cause demand on input credit; provision at 60% pending appeal advice'),
    ('Warranty pool FY26 X-ray tubes','warranty',3200000,3200000,0,'possible','adequate','2027-03-31','2026-07-01',
     'Installed base','internal','WARR-FY26','Rolling warranty accrual for X-ray tube failures within cover'),
    ('Bank guarantee AIIMS tender','guarantee',5000000,0,5000000,'remote','no_provision','2027-06-30','2026-07-01',
     'AIIMS Delhi','contract','BG-AIIMS-118','Performance BG on supply tender; disclosed as contingent liability'),
    ('Service contract dispute Fortis','litigation',4200000,2000000,2200000,'possible','under_provided','2026-11-30','2026-07-01',
     'Fortis Healthcare','arbitration','ARB-2025-07','AMC billing dispute in arbitration; partial provision held'),
    ('Employee gratuity shortfall','other',2600000,2600000,0,'probable','adequate','2026-09-30','2026-06-01',
     'Actuarial valuation','internal','ACT-GRAT-26','Actuarial gratuity shortfall fully provided per AS-15'),
    ('Income tax reassessment AY21','tax_dispute',6800000,1500000,5300000,'possible','under_provided','2027-01-31','2026-06-01',
     'Income Tax Department','tax_authority','ITBA/AY21','Reassessment on disallowed expenses; provision under review'),
    ('Onerous AMC Manipal loss','onerous_contract',1800000,1800000,0,'virtually_certain','adequate','2026-08-31','2026-06-01',
     'Manipal Hospitals','contract','AMC-MNP-014','Loss-making AMC; onerous contract provision recognised in full'),
    ('CDSCO penalty notice','regulatory',1200000,0,1200000,'possible','no_provision','2026-10-31','2026-05-01',
     'CDSCO','regulator','CDSCO/SCN/091','Regulatory penalty notice on labelling; disclosed pending reply'),
    ('Product liability claim ventilator','litigation',9500000,3000000,6500000,'probable','under_provided','2027-04-30','2026-05-01',
     'Patient family','high_court','WP-2025-4471','Product liability writ; provision below counsel estimate'),
    ('Excess warranty provision reversal','warranty',1500000,2500000,0,'remote','over_provided','2026-08-31','2026-05-01',
     'Installed base','internal','WARR-REV-25','Claims trend below accrual; excess provision to be reversed'),
    ('Sales tax C-form pending','tax_dispute',900000,900000,0,'possible','adequate','2026-12-31','2026-04-01',
     'Commercial Tax Department','tax_authority','CST-CFORM-24','C-form mismatch demand fully provided pending collection'),
    ('Vendor breach counterclaim','litigation',3400000,0,3400000,'remote','no_provision','2027-02-28','2026-04-01',
     'Siemens Healthineers','arbitration','ARB-VEND-09','Counterclaim on supply breach; remote, disclosed only'),
    ('Performance guarantee KIMS','guarantee',2200000,0,2200000,'possible','no_provision','2026-12-31','2026-04-01',
     'KIMS Hyderabad','contract','PBG-KIMS-77','Performance bank guarantee outstanding; contingent disclosed'),
    ('Settled labour dispute Pune','litigation',1700000,0,0,'virtually_certain','settled','2026-06-15','2026-06-01',
     'Ex-employee union','tribunal','ID-PUNE-2024','Industrial dispute settled and paid; no further exposure'),
    ('Over-provided tax appeal won','tax_dispute',700000,2000000,0,'remote','over_provided','2026-07-15','2026-07-01',
     'ITAT Mumbai','tribunal','ITAT-M-33','Appeal won at ITAT; excess provision to be written back')
  ) as q(itm, ltype, gross, prov, contd, prob, pstat, eres, pmon, cparty, juris, mref, nt);

  -- CAPA seed — attach to specific register items via item_name
  insert into public.contingent_liability_capa_actions_r3533 (
    liability_id, finding_category, root_cause, corrective_action,
    capa_status, provision_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('GST demand FY22 Chennai','under_provisioned','valuation_estimate_revised','increase_provision','in_progress',3500000,'CFO','2026-08-31',null,'Top-up provision to full demand pending appeal advice'),
    ('Product liability claim ventilator','under_provisioned','adverse_legal_development','engage_external_counsel','escalated',6500000,'General Counsel','2026-09-15',null,'Escalated to board; external counsel appointed for defence'),
    ('Income tax reassessment AY21','under_provisioned','new_claim_received','increase_provision','open',5300000,'Head of Tax','2026-08-30',null,'Reassessment order under review; provision assessment pending'),
    ('CDSCO penalty notice','contingent_not_disclosed','regulatory_change','add_disclosure_note','verification_pending',1200000,'Compliance Lead','2026-08-10',null,'Contingent disclosure note drafted for audit committee sign-off'),
    ('Bank guarantee AIIMS tender','disclosure_gap','incomplete_documentation','add_disclosure_note','closed',5000000,'Finance Controller','2026-07-20','2026-07-18','BG now disclosed in contingent-liabilities schedule'),
    ('Excess warranty provision reversal','over_provisioned','valuation_estimate_revised','reduce_provision','closed',1000000,'Financial Controller','2026-07-31','2026-07-25','Excess warranty provision reversed after claims-trend review'),
    ('Service contract dispute Fortis','probability_reassessment','settlement_negotiation','obtain_legal_opinion','overdue',2200000,'General Counsel','2026-07-05',null,'Legal opinion overdue; arbitration hearing date awaited'),
    ('Over-provided tax appeal won','over_provisioned','prior_period_error','reduce_provision','closed',1300000,'Head of Tax','2026-07-20','2026-07-16','Appeal won at ITAT; excess provision written back to P&L')
  ) as q(itm, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.contingent_liability_r3533 e
    on e.organization_id = v_org_id and e.item_name = q.itm;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Provision-status distribution
create or replace function public.founder_r3533_provision_status_rollup()
returns table(provision_status text, items bigint, gross_exposure_rupees numeric, provision_made_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.contingent_liability_r3533)
  select l.provision_status,
    count(*)::bigint,
    coalesce(sum(l.gross_exposure_rupees),0)::numeric,
    coalesce(sum(l.provision_made_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.contingent_liability_r3533 l
  group by l.provision_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3533_provision_status_rollup() from public, anon;
grant execute on function public.founder_r3533_provision_status_rollup() to authenticated;

-- 2) Liability-type scorecard
create or replace function public.founder_r3533_liability_type_scorecard()
returns table(
  liability_type text,
  items bigint,
  gross_exposure_rupees numeric,
  provision_made_rupees numeric,
  contingent_disclosed_rupees numeric,
  under_provided bigint,
  no_provision bigint,
  coverage_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.liability_type,
    count(*)::bigint,
    coalesce(sum(l.gross_exposure_rupees),0)::numeric,
    coalesce(sum(l.provision_made_rupees),0)::numeric,
    coalesce(sum(l.contingent_disclosed_rupees),0)::numeric,
    count(*) filter (where l.provision_status = 'under_provided')::bigint,
    count(*) filter (where l.provision_status = 'no_provision')::bigint,
    round(100.0 * coalesce(sum(l.provision_made_rupees),0) / nullif(coalesce(sum(l.gross_exposure_rupees),0),0), 1)
  from public.contingent_liability_r3533 l
  group by l.liability_type
  order by coalesce(sum(l.gross_exposure_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3533_liability_type_scorecard() from public, anon;
grant execute on function public.founder_r3533_liability_type_scorecard() to authenticated;

-- 3) Liability-type × probability matrix
create or replace function public.founder_r3533_liability_probability_matrix()
returns table(liability_type text, probability text, items bigint, gross_exposure_rupees numeric, under_provided bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.liability_type, l.probability,
    count(*)::bigint,
    coalesce(sum(l.gross_exposure_rupees),0)::numeric,
    count(*) filter (where l.provision_status = 'under_provided')::bigint
  from public.contingent_liability_r3533 l
  group by l.liability_type, l.probability
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3533_liability_probability_matrix() from public, anon;
grant execute on function public.founder_r3533_liability_probability_matrix() to authenticated;

-- 4) Monthly exposure trend
create or replace function public.founder_r3533_monthly_exposure_trend()
returns table(
  period_month date,
  items bigint,
  gross_exposure_rupees numeric,
  provision_made_rupees numeric,
  contingent_disclosed_rupees numeric,
  under_provided bigint
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
    coalesce(sum(l.gross_exposure_rupees),0)::numeric,
    coalesce(sum(l.provision_made_rupees),0)::numeric,
    coalesce(sum(l.contingent_disclosed_rupees),0)::numeric,
    count(*) filter (where l.provision_status = 'under_provided')::bigint
  from public.contingent_liability_r3533 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3533_monthly_exposure_trend() from public, anon;
grant execute on function public.founder_r3533_monthly_exposure_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3533_capa_status_board()
returns table(capa_status text, actions bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.provision_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.contingent_liability_capa_actions_r3533 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3533_capa_status_board() from public, anon;
grant execute on function public.founder_r3533_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3533_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.contingent_liability_capa_actions_r3533)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.provision_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.contingent_liability_capa_actions_r3533 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3533_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3533_root_cause_pareto() to authenticated;

-- 7) Exposure-impact digest (by CAPA finding category)
create or replace function public.founder_r3533_exposure_impact_digest()
returns table(finding_category text, actions bigint, open_actions bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.provision_impact_rupees),0)::numeric
  from public.contingent_liability_capa_actions_r3533 c
  group by c.finding_category
  order by coalesce(sum(c.provision_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3533_exposure_impact_digest() from public, anon;
grant execute on function public.founder_r3533_exposure_impact_digest() to authenticated;

-- 8) High-risk queue (under-provided / probable / large-exposure)
create or replace function public.founder_r3533_high_risk_queue()
returns table(
  item_name text,
  liability_type text,
  probability text,
  provision_status text,
  gross_exposure_rupees numeric,
  provision_made_rupees numeric,
  contingent_disclosed_rupees numeric,
  expected_resolution date,
  counterparty text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.item_name, l.liability_type, l.probability, l.provision_status,
    l.gross_exposure_rupees, l.provision_made_rupees, l.contingent_disclosed_rupees,
    l.expected_resolution, l.counterparty, l.notes
  from public.contingent_liability_r3533 l
  where l.provision_status in ('under_provided','no_provision')
     or l.probability in ('probable','virtually_certain')
     or l.gross_exposure_rupees >= 5000000
  order by l.gross_exposure_rupees desc nulls last, l.item_name;
end;
$$;

revoke execute on function public.founder_r3533_high_risk_queue() from public, anon;
grant execute on function public.founder_r3533_high_risk_queue() to authenticated;
