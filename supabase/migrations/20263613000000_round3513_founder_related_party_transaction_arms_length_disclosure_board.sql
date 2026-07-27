-- Round 3513: Founder Related-Party-Transaction Arms-Length / Disclosure Board
-- RPT governance - related party × relationship × transaction type × arms-length pricing/variance ×
-- approval & disclosure compliance × monthly trend × CAPA closure across SEBI LODR / board surfaces

-- =============================================================================
-- TABLE 1: related_party_txn_r3513 - per-transaction arms-length & disclosure record
-- =============================================================================
create table if not exists public.related_party_txn_r3513 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  txn_code text not null,
  related_party text not null,
  relationship text not null check (relationship in (
    'director','promoter','subsidiary','associate','kmp','relative'
  )),
  transaction_type text not null check (transaction_type in (
    'sale','purchase','loan','guarantee','lease','service','reimbursement'
  )),
  pricing_basis text not null check (pricing_basis in (
    'market_price','cost_plus','independent_valuation','negotiated','not_benchmarked'
  )),
  amount_rupees numeric(14,2) not null,
  arms_length_benchmark_rupees numeric(14,2),
  variance_pct numeric(6,2),
  approval_status text not null check (approval_status in (
    'board_approved','audit_committee_approved','pending','ratification_needed','non_compliant'
  )),
  board_resolution_ref text,
  disclosed boolean not null,
  period_month date not null,
  risk_level text not null check (risk_level in ('low','medium','high')),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.related_party_txn_r3513 enable row level security;

create index if not exists idx_related_party_txn_r3513_org on public.related_party_txn_r3513(organization_id);
create index if not exists idx_related_party_txn_r3513_month on public.related_party_txn_r3513(period_month);
create index if not exists idx_related_party_txn_r3513_appr on public.related_party_txn_r3513(approval_status);

-- =============================================================================
-- TABLE 2: related_party_txn_capa_actions_r3513 - CAPA & disclosure remediation
-- =============================================================================
create table if not exists public.related_party_txn_capa_actions_r3513 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  txn_id uuid not null references public.related_party_txn_r3513(id) on delete cascade,
  txn_code text not null,
  finding_category text not null check (finding_category in (
    'pricing_above_benchmark','no_arms_length_benchmark','missing_board_approval','missing_disclosure',
    'ratification_pending','loan_without_terms','guarantee_without_commission','related_party_conflict'
  )),
  root_cause text not null check (root_cause in (
    'benchmark_not_obtained','approval_process_gap','disclosure_oversight','pricing_policy_deviation',
    'documentation_incomplete','conflict_of_interest','pending_valuation','process_control_weakness'
  )),
  corrective_action text not null check (corrective_action in (
    'obtain_independent_valuation','seek_board_ratification','file_disclosure','renegotiate_pricing',
    'execute_agreement','recover_excess_amount','strengthen_rpt_policy','escalate_to_audit_committee','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  disclosure_impact text not null check (disclosure_impact in (
    'sebi_lodr_disclosure','board_disclosure','audit_committee_reporting','statutory_filing','none','internal_only'
  )),
  impact_rupees numeric(14,2),
  owner_name text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.related_party_txn_capa_actions_r3513 enable row level security;

create index if not exists idx_related_party_capa_r3513_org on public.related_party_txn_capa_actions_r3513(organization_id);
create index if not exists idx_related_party_capa_r3513_txn on public.related_party_txn_capa_actions_r3513(txn_id);
create index if not exists idx_related_party_capa_r3513_status on public.related_party_txn_capa_actions_r3513(capa_status);

-- =============================================================================
-- SEED DATA - reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 related-party transaction rows
  insert into public.related_party_txn_r3513 (
    organization_id, txn_code, related_party, relationship, transaction_type, pricing_basis,
    amount_rupees, arms_length_benchmark_rupees, variance_pct, approval_status, board_resolution_ref,
    disclosed, period_month, risk_level, notes
  )
  select v_org_id, q.tcode, q.party, q.rel, q.ttype, q.pbasis,
    q.amt, q.bench, q.varpct, q.appr, q.bres,
    q.disc, q.pmon::date, q.risk, q.nt
  from (values
    ('RPT-2601','Sundaram Promoters LLP','promoter','lease','market_price',
     2400000,2350000,2.1,'board_approved','BR-2026-011',true,'2026-06-01','low','Office lease from promoter entity at near-market rent'),
    ('RPT-2602','Meridian Subsidiary Pvt Ltd','subsidiary','sale','cost_plus',
     18500000,18000000,2.8,'board_approved','BR-2026-012',true,'2026-06-01','low','Intercompany equipment sale to WOS on cost-plus 8 percent'),
    ('RPT-2603','K. Raghavan (Director)','director','service','negotiated',
     1200000,900000,33.3,'ratification_needed',null,false,'2026-06-01','high','Advisory fees to director above benchmark, not yet disclosed'),
    ('RPT-2604','Vaidya Associates','associate','purchase','independent_valuation',
     7600000,7500000,1.3,'audit_committee_approved','AC-2026-004',true,'2026-05-01','low','Raw material purchase from associate at valuer price'),
    ('RPT-2605','Anil Mehta (KMP)','kmp','loan','not_benchmarked',
     5000000,null,null,'pending',null,false,'2026-05-01','high','Unsecured loan to KMP pending audit-committee benchmark'),
    ('RPT-2606','Deepa Rao (Relative)','relative','service','negotiated',
     450000,320000,40.6,'non_compliant',null,false,'2026-05-01','high','Consultancy to director relative, no arms-length basis, undisclosed'),
    ('RPT-2607','Meridian Subsidiary Pvt Ltd','subsidiary','guarantee','market_price',
     30000000,30000000,0.0,'board_approved','BR-2026-014',true,'2026-04-01','medium','Corporate guarantee for subsidiary term loan, commission under review'),
    ('RPT-2608','Sundaram Promoters LLP','promoter','purchase','cost_plus',
     9800000,9200000,6.5,'audit_committee_approved','AC-2026-005',true,'2026-04-01','medium','Packaging supply from promoter LLP, slight premium noted'),
    ('RPT-2609','Vaidya Associates','associate','reimbursement','market_price',
     380000,380000,0.0,'board_approved','BR-2026-015',true,'2026-04-01','low','Shared-service cost reimbursement at actuals'),
    ('RPT-2610','K. Raghavan (Director)','director','lease','independent_valuation',
     2100000,2000000,5.0,'board_approved','BR-2026-016',true,'2026-03-01','low','Warehouse lease from director within valuer range'),
    ('RPT-2611','Orbit Holdings (Promoter)','promoter','loan','not_benchmarked',
     12000000,null,null,'ratification_needed',null,false,'2026-03-01','high','Inter-corporate deposit to promoter holding, benchmark pending'),
    ('RPT-2612','Meridian Subsidiary Pvt Ltd','subsidiary','sale','cost_plus',
     22000000,21500000,2.3,'board_approved','BR-2026-017',true,'2026-03-01','low','Finished-goods transfer to subsidiary on cost-plus'),
    ('RPT-2613','Anil Mehta (KMP)','kmp','reimbursement','market_price',
     260000,260000,0.0,'audit_committee_approved','AC-2026-006',true,'2026-02-01','low','Travel reimbursement to KMP at actuals'),
    ('RPT-2614','Deepa Rao (Relative)','relative','purchase','negotiated',
     1650000,1400000,17.9,'pending',null,true,'2026-02-01','medium','Supply contract with director relative above benchmark, board note pending'),
    ('RPT-2615','Orbit Holdings (Promoter)','promoter','service','cost_plus',
     5400000,5100000,5.9,'board_approved','BR-2026-018',true,'2026-02-01','medium','Management shared-service fee to promoter holding'),
    ('RPT-2616','Vaidya Associates','associate','guarantee','not_benchmarked',
     15000000,null,null,'non_compliant',null,false,'2026-01-01','high','Guarantee extended to associate without pricing or disclosure')
  ) as q(tcode, party, rel, ttype, pbasis, amt, bench, varpct, appr, bres, disc, pmon, risk, nt);

  -- CAPA seed - attach to specific transactions via txn_code
  insert into public.related_party_txn_capa_actions_r3513 (
    organization_id, txn_id, txn_code, finding_category, root_cause, corrective_action,
    capa_status, disclosure_impact, impact_rupees, owner_name, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.tcode, q.fcat, q.rcause, q.caction,
    q.cstat, q.dimp, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RPT-2603','pricing_above_benchmark','pricing_policy_deviation','renegotiate_pricing','in_progress','audit_committee_reporting',300000,'CFO - Priya Nair','2026-07-15',null,'Director advisory fee 33 percent above benchmark; renegotiation underway'),
    ('RPT-2605','no_arms_length_benchmark','benchmark_not_obtained','obtain_independent_valuation','open','sebi_lodr_disclosure',5000000,'Company Secretary - R. Menon','2026-07-20',null,'KMP loan needs independent benchmark and documented terms'),
    ('RPT-2606','missing_disclosure','conflict_of_interest','file_disclosure','escalated','sebi_lodr_disclosure',450000,'Company Secretary - R. Menon','2026-07-10',null,'Relative consultancy undisclosed and non-arms-length; escalated'),
    ('RPT-2611','no_arms_length_benchmark','pending_valuation','obtain_independent_valuation','in_progress','audit_committee_reporting',12000000,'Treasury - S. Iyer','2026-07-25',null,'Inter-corporate deposit to promoter holding, benchmark pending'),
    ('RPT-2614','pricing_above_benchmark','documentation_incomplete','seek_board_ratification','verification_pending','board_disclosure',250000,'CFO - Priya Nair','2026-07-18',null,'Relative supply contract 18 percent over benchmark; board note drafted'),
    ('RPT-2616','guarantee_without_commission','process_control_weakness','strengthen_rpt_policy','open','sebi_lodr_disclosure',15000000,'Legal - A. Fernandes','2026-08-01',null,'Guarantee to associate without commission or disclosure'),
    ('RPT-2608','pricing_above_benchmark','pricing_policy_deviation','renegotiate_pricing','closed','audit_committee_reporting',600000,'Procurement - V. Das','2026-06-20','2026-06-18','Promoter packaging premium renegotiated back to benchmark'),
    ('RPT-2607','missing_board_approval','documentation_incomplete','execute_agreement','closed','board_disclosure',0,'Legal - A. Fernandes','2026-06-15','2026-06-12','Guarantee commission policy documented and board-approved')
  ) as q(tcode, fcat, rcause, caction, cstat, dimp, impact, ownr, tcd, acd, nt)
  join public.related_party_txn_r3513 e
    on e.organization_id = v_org_id and e.txn_code = q.tcode;
end;
$seed$;

-- =============================================================================
-- RPCs - 8 founder-gated rollups
-- =============================================================================

-- 1) Approval-status distribution
create or replace function public.founder_r3513_approval_status_rollup()
returns table(approval_status text, txns bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.related_party_txn_r3513)
  select l.approval_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.related_party_txn_r3513 l
  group by l.approval_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3513_approval_status_rollup() from public, anon;
grant execute on function public.founder_r3513_approval_status_rollup() to authenticated;

-- 2) Relationship scorecard
create or replace function public.founder_r3513_relationship_scorecard()
returns table(
  relationship text,
  total_txns bigint,
  board_approved bigint,
  pending_txns bigint,
  non_compliant bigint,
  undisclosed bigint,
  high_variance bigint,
  total_amount_rupees numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.relationship,
    count(*)::bigint,
    count(*) filter (where l.approval_status in ('board_approved','audit_committee_approved'))::bigint,
    count(*) filter (where l.approval_status = 'pending')::bigint,
    count(*) filter (where l.approval_status = 'non_compliant')::bigint,
    count(*) filter (where l.disclosed = false)::bigint,
    count(*) filter (where abs(l.variance_pct) >= 15)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.approval_status in ('board_approved','audit_committee_approved') and l.disclosed = true)::numeric / nullif(count(*),0), 1)
  from public.related_party_txn_r3513 l
  group by l.relationship
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3513_relationship_scorecard() from public, anon;
grant execute on function public.founder_r3513_relationship_scorecard() to authenticated;

-- 3) Transaction-type × approval-status matrix
create or replace function public.founder_r3513_txn_type_approval_matrix()
returns table(transaction_type text, approval_status text, txns bigint, total_amount_rupees numeric, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.transaction_type, l.approval_status, count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    round(avg(l.variance_pct), 2)
  from public.related_party_txn_r3513 l
  group by l.transaction_type, l.approval_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3513_txn_type_approval_matrix() from public, anon;
grant execute on function public.founder_r3513_txn_type_approval_matrix() to authenticated;

-- 4) Monthly RPT trend
create or replace function public.founder_r3513_monthly_rpt_trend()
returns table(period_month date, txns bigint, total_amount_rupees numeric, non_compliant bigint, undisclosed bigint, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.amount_rupees),0)::numeric,
    count(*) filter (where l.approval_status = 'non_compliant')::bigint,
    count(*) filter (where l.disclosed = false)::bigint,
    round(avg(l.variance_pct), 2)
  from public.related_party_txn_r3513 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3513_monthly_rpt_trend() from public, anon;
grant execute on function public.founder_r3513_monthly_rpt_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3513_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.related_party_txn_capa_actions_r3513 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3513_capa_status_board() from public, anon;
grant execute on function public.founder_r3513_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3513_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.related_party_txn_capa_actions_r3513)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.related_party_txn_capa_actions_r3513 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3513_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3513_root_cause_pareto() to authenticated;

-- 7) Exposure-impact digest by disclosure surface
create or replace function public.founder_r3513_exposure_impact_digest()
returns table(disclosure_impact text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.disclosure_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric
  from public.related_party_txn_capa_actions_r3513 c
  group by c.disclosure_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3513_exposure_impact_digest() from public, anon;
grant execute on function public.founder_r3513_exposure_impact_digest() to authenticated;

-- 8) High-risk RPT queue (non-compliant / pending / high-variance / undisclosed)
create or replace function public.founder_r3513_high_risk_queue()
returns table(
  related_party text,
  txn_code text,
  relationship text,
  transaction_type text,
  period_month date,
  amount_rupees numeric,
  variance_pct numeric,
  approval_status text,
  disclosed_flag text,
  risk_level text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.related_party, l.txn_code, l.relationship, l.transaction_type, l.period_month,
    l.amount_rupees, l.variance_pct, l.approval_status,
    case when l.disclosed then 'disclosed' else 'not_disclosed' end,
    l.risk_level, l.notes
  from public.related_party_txn_r3513 l
  where l.risk_level = 'high'
     or l.approval_status in ('pending','ratification_needed','non_compliant')
     or l.disclosed = false
     or abs(l.variance_pct) >= 15
  order by l.period_month desc, l.related_party;
end;
$$;

revoke execute on function public.founder_r3513_high_risk_queue() from public, anon;
grant execute on function public.founder_r3513_high_risk_queue() to authenticated;
