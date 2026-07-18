-- Round 3241: Founder Tax-Compliance (GST/TDS/Advance-Tax) Filing Calendar & Notice Tracker
-- Tax board — filing type × period × due/filed dates × days early/late × tax paid × notice status × penalty risk × CAPA

-- =============================================================================
-- TABLE 1: tax_filing_r3241 — statutory filing calendar & notice log
-- =============================================================================
create table if not exists public.tax_filing_r3241 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  entity_gstin text not null,
  filing_type text not null check (filing_type in (
    'gstr1','gstr3b','gstr9_annual','tds_24q','tds_26q','advance_tax','itr','roc_agm'
  )),
  filing_period text not null,
  due_date date not null,
  filed_date date,
  days_early_late int,
  tax_paid_rupees numeric(12,2),
  notice_received boolean not null default false,
  notice_status text not null check (notice_status in (
    'no_notice','notice_received','reply_drafted','reply_filed',
    'hearing_scheduled','demand_raised','appeal_filed','closed_no_demand'
  )),
  penalty_risk text not null check (penalty_risk in (
    'none','low','medium','high','critical'
  )),
  filing_verdict text not null check (filing_verdict in (
    'filed_on_time','filed_early','filed_late','pending_due','overdue_not_filed','under_notice'
  )),
  filing_ref text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tax_filing_r3241 enable row level security;

create index if not exists idx_tax_filing_r3241_org on public.tax_filing_r3241(organization_id);
create index if not exists idx_tax_filing_r3241_due on public.tax_filing_r3241(due_date);
create index if not exists idx_tax_filing_r3241_verdict on public.tax_filing_r3241(filing_verdict);

-- =============================================================================
-- TABLE 2: tax_filing_capa_actions_r3241 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.tax_filing_capa_actions_r3241 (
  id uuid primary key default gen_random_uuid(),
  filing_id uuid not null references public.tax_filing_r3241(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'late_filing','short_payment','interest_liability','notice_scn','mismatch_2a_3b',
    'tds_short_deduction','advance_tax_shortfall','data_entry_error','portal_outage','reconciliation_gap'
  )),
  root_cause text not null check (root_cause in (
    'vendor_invoice_delay','cash_flow_crunch','portal_technical_glitch',
    'ca_bandwidth_shortage','incorrect_hsn_mapping','tds_rate_confusion',
    'books_reconciliation_backlog','key_person_dependency','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'file_with_late_fee','pay_interest_and_file','engage_new_ca_firm',
    'automate_gst_reconciliation','set_compliance_calendar_alerts','revise_return',
    'reply_to_notice','create_tax_reserve_fund','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'gst_notice_risk','income_tax_scrutiny','roc_penalty','interest_only','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tax_filing_capa_actions_r3241 enable row level security;

create index if not exists idx_tax_capa_r3241_filing on public.tax_filing_capa_actions_r3241(filing_id);
create index if not exists idx_tax_capa_r3241_status on public.tax_filing_capa_actions_r3241(capa_status);

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

  -- 14 filing rows
  insert into public.tax_filing_r3241 (
    organization_id, entity_name, entity_gstin, filing_type, filing_period,
    due_date, filed_date, days_early_late, tax_paid_rupees,
    notice_received, notice_status, penalty_risk, filing_verdict, filing_ref, notes
  )
  select v_org_id, q.ent, q.gstin, q.ft, q.fp,
    q.dd::date, q.fd::date, q.del, q.paid,
    q.nr, q.ns, q.pr, q.fv, q.ref, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','36AAACA1111A1Z5','gstr1','2026-06','2026-07-11','2026-07-09',-2,0.00,false,'no_notice','none','filed_early','GSTR1-2026-06-APL','Outward supplies filed 2 days early'),
    ('Apollo Hyderabad Jubilee Hills','36AAACA1111A1Z5','gstr3b','2026-06','2026-07-20',null,null,null,false,'no_notice','low','pending_due','GSTR3B-2026-06-APL','ITC reconciliation pending on 14 vendor invoices'),
    ('Fortis Bannerghatta Bengaluru','29AABCF2222B1Z8','gstr3b','2026-05','2026-06-20','2026-06-24',4,184500.00,false,'no_notice','medium','filed_late','GSTR3B-2026-05-FRT','Filed 4 days late — late fee and interest on cash liability paid'),
    ('Fortis Bannerghatta Bengaluru','29AABCF2222B1Z8','tds_24q','Q1 FY26-27','2026-07-31',null,null,null,false,'no_notice','low','pending_due','TDS24Q-Q1-FRT','Salary TDS return — challan mapping in progress'),
    ('Manipal Whitefield Bengaluru','29AAECM3333C1Z2','advance_tax','Q1 FY26-27','2026-06-15','2026-06-14',-1,1250000.00,false,'no_notice','none','filed_on_time','ADVTAX-Q1-MNP','First instalment paid a day early'),
    ('Manipal Whitefield Bengaluru','29AAECM3333C1Z2','gstr1','2026-05','2026-06-11','2026-06-11',0,0.00,false,'no_notice','none','filed_on_time','GSTR1-2026-05-MNP','Filed on due date — nil late fee'),
    ('AIIMS New Delhi Ansari Nagar','07AAAGA4444D1Z6','tds_26q','Q4 FY25-26','2026-05-31','2026-06-18',18,462000.00,true,'notice_received','high','under_notice','TDS26Q-Q4-AIM','Late filing — section 234E fee notice received'),
    ('KIMS Secunderabad','36AAFCK5555E1Z9','gstr3b','2026-04','2026-05-20','2026-05-20',0,98000.00,true,'reply_filed','medium','under_notice','GSTR3B-2026-04-KIM','ASMT-10 for 2A vs 3B mismatch — reply filed'),
    ('KIMS Secunderabad','36AAFCK5555E1Z9','itr','FY25-26','2026-10-31',null,null,null,false,'no_notice','low','pending_due','ITR-FY2526-KIM','Tax audit under section 44AB in progress'),
    ('Care Hospitals Banjara Hills','36AADCC6666F1Z3','roc_agm','FY25-26','2026-09-30',null,null,null,false,'no_notice','medium','pending_due','ROCAGM-FY2526-CAR','AGM notice draft with company secretary'),
    ('Yashoda Somajiguda Hyderabad','36AACCY7777G1Z7','gstr3b','2026-05','2026-06-20',null,null,null,true,'demand_raised','critical','overdue_not_filed','GSTR3B-2026-05-YSH','Not filed 28 days past due — DRC-01 demand raised'),
    ('St John''s Bengaluru','29AABTS8888H1Z1','gstr9_annual','FY25-26','2026-12-31',null,null,null,false,'no_notice','low','pending_due','GSTR9-FY2526-STJ','Annual return — reconciliation workpapers started'),
    ('Rainbow Children''s Hyderabad','36AAHCR9999J1Z4','advance_tax','Q1 FY26-27','2026-06-15','2026-06-28',13,310000.00,false,'no_notice','medium','filed_late','ADVTAX-Q1-RBW','Instalment 13 days late — section 234C interest accrued'),
    ('Apollo Hyderabad Jubilee Hills','36AAACA1111A1Z5','tds_24q','Q4 FY25-26','2026-05-31','2026-05-29',-2,895000.00,true,'closed_no_demand','none','filed_early','TDS24Q-Q4-APL','Justification notice resolved — closed with no demand')
  ) as q(ent, gstin, ft, fp, dd, fd, del, paid, nr, ns, pr, fv, ref, nt);

  -- 6 CAPA rows — attach to specific filings via filing_ref
  insert into public.tax_filing_capa_actions_r3241 (
    filing_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('GSTR3B-2026-05-FRT','late_filing','vendor_invoice_delay','automate_gst_reconciliation','2026-07-15',null,'in_progress','interest_only',45000.00,'GST reconciliation tool purchase order raised'),
    ('TDS26Q-Q4-AIM','notice_scn','key_person_dependency','reply_to_notice','2026-07-10',null,'escalated','income_tax_scrutiny',92400.00,'CA drafting 234E reply — single-signatory bottleneck flagged'),
    ('GSTR3B-2026-04-KIM','mismatch_2a_3b','books_reconciliation_backlog','revise_return','2026-06-30','2026-06-27','closed','gst_notice_risk',15000.00,'ASMT-10 reply accepted — no further demand'),
    ('GSTR3B-2026-05-YSH','notice_scn','cash_flow_crunch','pay_interest_and_file','2026-07-08',null,'overdue','gst_notice_risk',218000.00,'DRC-01 — funds arranged, filing this week'),
    ('ADVTAX-Q1-RBW','advance_tax_shortfall','cash_flow_crunch','create_tax_reserve_fund','2026-07-20',null,'open','interest_only',18600.00,'Automated monthly sweep to tax reserve account'),
    ('GSTR3B-2026-06-APL','reconciliation_gap','vendor_invoice_delay','set_compliance_calendar_alerts','2026-07-19',null,'in_progress','none',0.00,'Vendor follow-up cadence added to compliance calendar')
  ) as q(ref_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.tax_filing_r3241 e
    on e.organization_id = v_org_id and e.filing_ref = q.ref_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Filing verdict distribution
create or replace function public.founder_r3241_filing_verdict_rollup()
returns table(filing_verdict text, filings bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tax_filing_r3241)
  select f.filing_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tax_filing_r3241 f
  group by f.filing_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3241_filing_verdict_rollup() from public, anon;
grant execute on function public.founder_r3241_filing_verdict_rollup() to authenticated;

-- 2) Entity-level compliance scorecard
create or replace function public.founder_r3241_entity_scorecard()
returns table(
  entity_name text,
  total_filings bigint,
  on_time bigint,
  late bigint,
  pending bigint,
  overdue bigint,
  notices bigint,
  total_tax_paid_rupees numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.entity_name,
    count(*)::bigint,
    count(*) filter (where f.filing_verdict in ('filed_on_time','filed_early'))::bigint,
    count(*) filter (where f.filing_verdict = 'filed_late')::bigint,
    count(*) filter (where f.filing_verdict = 'pending_due')::bigint,
    count(*) filter (where f.filing_verdict = 'overdue_not_filed')::bigint,
    count(*) filter (where f.notice_received)::bigint,
    coalesce(sum(f.tax_paid_rupees),0)::numeric,
    round(100.0 * count(*) filter (where f.filing_verdict in ('filed_on_time','filed_early'))::numeric / nullif(count(*),0), 1)
  from public.tax_filing_r3241 f
  group by f.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3241_entity_scorecard() from public, anon;
grant execute on function public.founder_r3241_entity_scorecard() to authenticated;

-- 3) Filing-type matrix
create or replace function public.founder_r3241_filing_type_matrix()
returns table(
  filing_type text,
  filings bigint,
  on_time bigint,
  late bigint,
  notices bigint,
  avg_days_early_late numeric,
  total_tax_paid_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.filing_type, count(*)::bigint,
    count(*) filter (where f.filing_verdict in ('filed_on_time','filed_early'))::bigint,
    count(*) filter (where f.filing_verdict = 'filed_late')::bigint,
    count(*) filter (where f.notice_received)::bigint,
    round(avg(f.days_early_late)::numeric, 1),
    coalesce(sum(f.tax_paid_rupees),0)::numeric
  from public.tax_filing_r3241 f
  group by f.filing_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3241_filing_type_matrix() from public, anon;
grant execute on function public.founder_r3241_filing_type_matrix() to authenticated;

-- 4) Due-date calendar trend
create or replace function public.founder_r3241_due_date_trend()
returns table(due_date date, filings_due bigint, filed bigint, pending bigint, overdue bigint, notices bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.due_date,
    count(*)::bigint,
    count(*) filter (where f.filed_date is not null)::bigint,
    count(*) filter (where f.filing_verdict = 'pending_due')::bigint,
    count(*) filter (where f.filing_verdict = 'overdue_not_filed')::bigint,
    count(*) filter (where f.notice_received)::bigint
  from public.tax_filing_r3241 f
  group by f.due_date
  order by f.due_date asc;
end;
$$;

revoke execute on function public.founder_r3241_due_date_trend() from public, anon;
grant execute on function public.founder_r3241_due_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3241_capa_status_board()
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
  from public.tax_filing_capa_actions_r3241 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3241_capa_status_board() from public, anon;
grant execute on function public.founder_r3241_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3241_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tax_filing_capa_actions_r3241)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tax_filing_capa_actions_r3241 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3241_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3241_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3241_regulatory_impact_digest()
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
  from public.tax_filing_capa_actions_r3241 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3241_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3241_regulatory_impact_digest() to authenticated;

-- 8) High-risk filings queue
create or replace function public.founder_r3241_high_risk_queue()
returns table(
  entity_name text,
  filing_type text,
  filing_period text,
  due_date date,
  filed_date date,
  filing_verdict text,
  notice_status text,
  penalty_risk text,
  tax_paid_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.entity_name, f.filing_type, f.filing_period, f.due_date, f.filed_date,
    f.filing_verdict, f.notice_status, f.penalty_risk, f.tax_paid_rupees, f.notes
  from public.tax_filing_r3241 f
  where f.penalty_risk in ('high','critical')
     or f.filing_verdict in ('overdue_not_filed','under_notice','filed_late')
     or f.notice_received
  order by f.due_date asc, f.entity_name;
end;
$$;

revoke execute on function public.founder_r3241_high_risk_queue() from public, anon;
grant execute on function public.founder_r3241_high_risk_queue() to authenticated;
