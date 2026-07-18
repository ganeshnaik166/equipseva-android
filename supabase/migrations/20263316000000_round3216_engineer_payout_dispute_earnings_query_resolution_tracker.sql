-- Round 3216: Engineer Payout-Dispute & Earnings-Query Resolution Tracker
-- Payout dispute log — query type × raised channel × resolution days × outcome × satisfaction × verdict × CAPA

-- =============================================================================
-- TABLE 1: payout_dispute_r3216 — individual payout disputes / earnings queries
-- =============================================================================
create table if not exists public.payout_dispute_r3216 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  dispute_ref text not null,
  query_type text not null check (query_type in (
    'missing_payout','wrong_amount','tds_query','incentive_miss'
  )),
  raised_via text not null check (raised_via in (
    'app_ticket','call_support','whatsapp','email','field_manager'
  )),
  disputed_amount_rupees numeric(12,2) not null,
  settled_amount_rupees numeric(12,2),
  raised_date date not null,
  resolved_date date,
  resolution_days int,
  outcome text check (outcome in ('paid','adjusted','rejected','explained')),
  dispute_verdict text not null check (dispute_verdict in (
    'resolved_engineer_favour','resolved_company_favour','partially_resolved',
    'under_review','escalated_finance','withdrawn'
  )),
  engineer_satisfaction text not null check (engineer_satisfaction in (
    'very_satisfied','satisfied','neutral','dissatisfied','very_dissatisfied','not_captured'
  )),
  engineer_id uuid references public.engineers(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.payout_dispute_r3216 enable row level security;

create index if not exists idx_payout_dispute_r3216_org on public.payout_dispute_r3216(organization_id);
create index if not exists idx_payout_dispute_r3216_date on public.payout_dispute_r3216(raised_date);
create index if not exists idx_payout_dispute_r3216_verdict on public.payout_dispute_r3216(dispute_verdict);

-- =============================================================================
-- TABLE 2: payout_dispute_capa_actions_r3216 — CAPA & process-fix actions
-- =============================================================================
create table if not exists public.payout_dispute_capa_actions_r3216 (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.payout_dispute_r3216(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'payout_calc_bug','bank_detail_mismatch','tds_rate_error','incentive_rule_gap',
    'ledger_sync_delay','manual_entry_error','policy_ambiguity','duplicate_deduction'
  )),
  root_cause text not null check (root_cause in (
    'rate_card_outdated','payout_engine_defect','ifsc_validation_missing',
    'tds_slab_misconfigured','incentive_criteria_undocumented','reconciliation_backlog',
    'ops_manual_override','engineer_kyc_incomplete','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'patch_payout_engine','update_rate_card','fix_tds_configuration',
    'publish_incentive_policy','automate_reconciliation','revalidate_bank_details',
    'retrain_ops_team','issue_manual_adjustment','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'tds_compliance','gst_impact','labour_law_exposure','none','internal_only','contractual_breach'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.payout_dispute_capa_actions_r3216 enable row level security;

create index if not exists idx_payout_dispute_capa_r3216_dispute on public.payout_dispute_capa_actions_r3216(dispute_id);
create index if not exists idx_payout_dispute_capa_r3216_status on public.payout_dispute_capa_actions_r3216(capa_status);

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

  -- 13 payout dispute rows
  insert into public.payout_dispute_r3216 (
    organization_id, engineer_name, hospital_name, dispute_ref,
    query_type, raised_via, disputed_amount_rupees, settled_amount_rupees,
    raised_date, resolved_date, resolution_days,
    outcome, dispute_verdict, engineer_satisfaction, notes
  )
  select v_org_id, q.eng, q.hosp, q.ref,
    q.qt, q.via, q.damt, q.samt,
    q.rd::date, q.res::date, q.days,
    q.oc, q.dv, q.sat, q.nt
  from (values
    ('Ravi Kumar','Apollo Hyderabad Jubilee Hills','PDQ-3216-001','missing_payout','app_ticket',8500.00,8500.00,
     '2026-07-01','2026-07-04',3,'paid','resolved_engineer_favour','satisfied','UPI payout stuck in ledger sync — released after reconciliation'),
    ('Suresh Babu','Fortis Bannerghatta Bengaluru','PDQ-3216-002','wrong_amount','call_support',12400.00,10900.00,
     '2026-07-02','2026-07-08',6,'adjusted','partially_resolved','neutral','Rate card mismatch on ventilator PM visit — differential adjusted'),
    ('Mohammed Irfan','Manipal Whitefield Bengaluru','PDQ-3216-003','tds_query','email',2100.00,null,
     '2026-07-03',null,null,null,'under_review','not_captured','TDS deducted at 10 pct instead of 1 pct — finance reviewing 194C vs 194J'),
    ('Anil Sharma','AIIMS New Delhi Ansari Nagar','PDQ-3216-004','incentive_miss','app_ticket',5000.00,5000.00,
     '2026-06-28','2026-07-05',7,'paid','resolved_engineer_favour','very_satisfied','Code Red completion bonus missed by incentive engine — back-paid'),
    ('Prakash Reddy','KIMS Secunderabad','PDQ-3216-005','missing_payout','whatsapp',15750.00,null,
     '2026-07-05',null,null,null,'escalated_finance','dissatisfied','Bank IFSC changed mid-cycle — payout bounced, re-KYC pending'),
    ('Venkatesh Rao','Care Hospitals Banjara Hills','PDQ-3216-006','wrong_amount','app_ticket',9800.00,9800.00,
     '2026-06-25','2026-06-27',2,'explained','resolved_company_favour','neutral','Engineer misread GST-inclusive quote — breakdown shared, no change due'),
    ('Deepak Nair','Yashoda Somajiguda Hyderabad','PDQ-3216-007','incentive_miss','field_manager',3500.00,null,
     '2026-06-30','2026-07-06',6,'rejected','resolved_company_favour','dissatisfied','SLA bonus claim rejected — job closed 4 hours past SLA window'),
    ('Karthik Iyer','St John''s Bengaluru','PDQ-3216-008','tds_query','email',1850.00,1850.00,
     '2026-06-26','2026-07-01',5,'paid','resolved_engineer_favour','satisfied','Duplicate TDS entry reversed and refunded with payout cycle'),
    ('Rajesh Gupta','Rainbow Children''s Hyderabad','PDQ-3216-009','missing_payout','call_support',22000.00,22000.00,
     '2026-06-24','2026-06-30',6,'paid','resolved_engineer_favour','satisfied','Multi-job settlement skipped one invoice — full amount released'),
    ('Ravi Kumar','Apollo Hyderabad Jubilee Hills','PDQ-3216-010','wrong_amount','app_ticket',4200.00,null,
     '2026-07-08',null,null,null,'under_review','not_captured','Spare-part reimbursement computed on MRP not invoice value'),
    ('Suresh Babu','Fortis Bannerghatta Bengaluru','PDQ-3216-011','incentive_miss','whatsapp',2500.00,1250.00,
     '2026-07-04','2026-07-10',6,'adjusted','partially_resolved','neutral','Referral incentive split between two engineers per policy'),
    ('Mohammed Irfan','Manipal Whitefield Bengaluru','PDQ-3216-012','missing_payout','app_ticket',6900.00,null,
     '2026-07-09',null,null,null,'withdrawn','not_captured','Engineer withdrew — payout arrived in next cycle before review started'),
    ('Anil Sharma','AIIMS New Delhi Ansari Nagar','PDQ-3216-013','tds_query','field_manager',3100.00,null,
     '2026-07-07',null,null,null,'escalated_finance','very_dissatisfied','Form 16A not issued for FY quarter — CA escalation raised')
  ) as q(eng, hosp, ref, qt, via, damt, samt, rd, res, days, oc, dv, sat, nt);

  -- CAPA seed — attach to specific disputes
  insert into public.payout_dispute_capa_actions_r3216 (
    dispute_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PDQ-3216-001','ledger_sync_delay','reconciliation_backlog','automate_reconciliation','2026-07-20',null,'in_progress','internal_only',35000.00,'Nightly ledger sync job to replace weekly manual reconciliation'),
    ('PDQ-3216-002','payout_calc_bug','rate_card_outdated','update_rate_card','2026-07-12','2026-07-10','closed','contractual_breach',0.00,'Ventilator PM rate card v3 published to payout engine'),
    ('PDQ-3216-003','tds_rate_error','tds_slab_misconfigured','fix_tds_configuration','2026-07-15',null,'verification_pending','tds_compliance',8000.00,'194C vs 194J mapping fix deployed — CA sign-off pending'),
    ('PDQ-3216-005','bank_detail_mismatch','ifsc_validation_missing','revalidate_bank_details','2026-07-18',null,'escalated','none',12000.00,'Penny-drop verification to be added on bank-detail edit'),
    ('PDQ-3216-004','incentive_rule_gap','incentive_criteria_undocumented','publish_incentive_policy','2026-07-10','2026-07-08','closed','internal_only',0.00,'Code Red bonus rules published in engineer handbook'),
    ('PDQ-3216-013','manual_entry_error','reconciliation_backlog','retrain_ops_team','2026-07-05',null,'overdue','tds_compliance',5000.00,'Form 16A issuance SOP overdue — quarterly TDS filings at risk')
  ) as q(ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.payout_dispute_r3216 e
    on e.organization_id = v_org_id and e.dispute_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Dispute verdict distribution
create or replace function public.founder_r3216_verdict_rollup()
returns table(dispute_verdict text, disputes bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.payout_dispute_r3216)
  select l.dispute_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.payout_dispute_r3216 l
  group by l.dispute_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3216_verdict_rollup() from public, anon;
grant execute on function public.founder_r3216_verdict_rollup() to authenticated;

-- 2) Engineer-level dispute scorecard
create or replace function public.founder_r3216_engineer_scorecard()
returns table(
  engineer_name text,
  total_disputes bigint,
  resolved bigint,
  paid bigint,
  adjusted bigint,
  rejected bigint,
  avg_resolution_days numeric,
  total_disputed_rupees numeric,
  resolution_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.resolved_date is not null)::bigint,
    count(*) filter (where l.outcome = 'paid')::bigint,
    count(*) filter (where l.outcome = 'adjusted')::bigint,
    count(*) filter (where l.outcome = 'rejected')::bigint,
    round(avg(l.resolution_days)::numeric, 1),
    coalesce(sum(l.disputed_amount_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.resolved_date is not null)::numeric / nullif(count(*),0), 1)
  from public.payout_dispute_r3216 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3216_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3216_engineer_scorecard() to authenticated;

-- 3) Query-type × outcome matrix
create or replace function public.founder_r3216_query_outcome_matrix()
returns table(query_type text, outcome text, disputes bigint, avg_resolution_days numeric, disputed_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.query_type, coalesce(l.outcome, 'pending'), count(*)::bigint,
    round(avg(l.resolution_days)::numeric, 1),
    coalesce(sum(l.disputed_amount_rupees),0)::numeric
  from public.payout_dispute_r3216 l
  group by l.query_type, l.outcome
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3216_query_outcome_matrix() from public, anon;
grant execute on function public.founder_r3216_query_outcome_matrix() to authenticated;

-- 4) Daily raised/resolved trend
create or replace function public.founder_r3216_daily_trend()
returns table(raised_date date, disputes bigint, resolved bigint, pending bigint, disputed_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.raised_date,
    count(*)::bigint,
    count(*) filter (where l.resolved_date is not null)::bigint,
    count(*) filter (where l.resolved_date is null)::bigint,
    coalesce(sum(l.disputed_amount_rupees),0)::numeric
  from public.payout_dispute_r3216 l
  group by l.raised_date
  order by l.raised_date desc;
end;
$$;

revoke execute on function public.founder_r3216_daily_trend() from public, anon;
grant execute on function public.founder_r3216_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3216_capa_status_board()
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
  from public.payout_dispute_capa_actions_r3216 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3216_capa_status_board() from public, anon;
grant execute on function public.founder_r3216_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3216_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.payout_dispute_capa_actions_r3216)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.payout_dispute_capa_actions_r3216 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3216_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3216_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3216_regulatory_impact_digest()
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
  from public.payout_dispute_capa_actions_r3216 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3216_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3216_regulatory_impact_digest() to authenticated;

-- 8) High-risk / unresolved dispute queue
create or replace function public.founder_r3216_high_risk_queue()
returns table(
  engineer_name text,
  hospital_name text,
  dispute_ref text,
  query_type text,
  raised_date date,
  disputed_amount_rupees numeric,
  dispute_verdict text,
  engineer_satisfaction text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.hospital_name, l.dispute_ref, l.query_type, l.raised_date,
    l.disputed_amount_rupees, l.dispute_verdict, l.engineer_satisfaction, l.notes
  from public.payout_dispute_r3216 l
  where l.dispute_verdict in ('under_review','escalated_finance')
     or l.outcome = 'rejected'
     or l.engineer_satisfaction in ('dissatisfied','very_dissatisfied')
  order by l.raised_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3216_high_risk_queue() from public, anon;
grant execute on function public.founder_r3216_high_risk_queue() to authenticated;
