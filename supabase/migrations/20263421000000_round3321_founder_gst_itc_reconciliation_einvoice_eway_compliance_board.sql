-- Round 3321: Founder GST ITC-Reconciliation & E-Invoice / E-Way-Bill Compliance Board
-- GST tax-compliance — area x GSTIN/vendor x ITC matched/at-risk x IRN coverage x e-way coverage x mismatch reason x filing status x compliance verdict x CAPA

-- =============================================================================
-- TABLE 1: gst_itc_compliance_r3321 — per period-vendor/segment GST compliance rows
-- =============================================================================
create table if not exists public.gst_itc_compliance_r3321 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  period_month text not null,
  area text not null check (area in (
    'itc_reconciliation','einvoice_generation','eway_bill','gstr1_filing','gstr3b_filing','rcm_reverse_charge'
  )),
  gstin_or_vendor text not null,
  invoice_count int not null,
  matched_itc_rupees numeric(14,2),
  unmatched_itc_rupees numeric(14,2),
  itc_at_risk_rupees numeric(14,2),
  einvoice_irn_coverage_pct numeric(5,2),
  eway_bill_coverage_pct numeric(5,2),
  mismatch_reason text not null check (mismatch_reason in (
    'fully_matched','vendor_not_filed','value_mismatch','gstin_error','missing_irn','eway_expired','rcm_pending'
  )),
  filing_status text not null check (filing_status in (
    'filed_on_time','filed_late','pending','notice_received'
  )),
  compliance_verdict text not null check (compliance_verdict in (
    'compliant','itc_recovery_action','vendor_followup','filing_overdue','notice_response_due'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gst_itc_compliance_r3321 enable row level security;

create index if not exists idx_gst_itc_compliance_r3321_org on public.gst_itc_compliance_r3321(org_id);
create index if not exists idx_gst_itc_compliance_r3321_period on public.gst_itc_compliance_r3321(period_month);
create index if not exists idx_gst_itc_compliance_r3321_verdict on public.gst_itc_compliance_r3321(compliance_verdict);

-- =============================================================================
-- TABLE 2: gst_itc_compliance_capa_actions_r3321 — CAPA & recovery/filing actions
-- =============================================================================
create table if not exists public.gst_itc_compliance_capa_actions_r3321 (
  id uuid primary key default gen_random_uuid(),
  recon_id uuid not null references public.gst_itc_compliance_r3321(id) on delete cascade,
  org_id uuid not null references public.organizations(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'itc_mismatch','vendor_non_filing','missing_einvoice_irn','eway_bill_gap',
    'gstr_filing_delay','rcm_liability','value_mismatch','gstin_validation'
  )),
  root_cause text not null check (root_cause in (
    'vendor_gstr1_not_filed','vendor_wrong_gstin','invoice_value_mismatch','irn_not_generated',
    'eway_bill_expired','portal_reconciliation_lag','rcm_not_discharged','internal_data_entry_error',
    'pending_investigation','filing_process_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'vendor_followup_notice','hold_vendor_payment','file_itc_reversal','generate_missing_irn',
    'regenerate_eway_bill','amend_gstr1','discharge_rcm_liability','correct_gstin_master',
    'file_belated_return','respond_to_notice','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'gst_notice_risk','itc_reversal_risk','none','internal_only','interest_penalty_exposure','audit_flag'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gst_itc_compliance_capa_actions_r3321 enable row level security;

create index if not exists idx_gst_itc_capa_r3321_recon on public.gst_itc_compliance_capa_actions_r3321(recon_id);
create index if not exists idx_gst_itc_capa_r3321_status on public.gst_itc_compliance_capa_actions_r3321(capa_status);

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

  -- 14 period-vendor/segment compliance rows
  insert into public.gst_itc_compliance_r3321 (
    org_id, period_month, area, gstin_or_vendor, invoice_count,
    matched_itc_rupees, unmatched_itc_rupees, itc_at_risk_rupees,
    einvoice_irn_coverage_pct, eway_bill_coverage_pct,
    mismatch_reason, filing_status, compliance_verdict, notes
  )
  select v_org_id, q.pm, q.ar, q.gv, q.ic,
    q.mi, q.ui, q.atr,
    q.irn, q.eway,
    q.mr, q.fs, q.cv, q.nt
  from (values
    ('2026-06','itc_reconciliation','33AACCM1234K1Z5 Medtronic India Chennai',210,
     1845000.00,0.00,0.00,100.00,100.00,'fully_matched','filed_on_time','compliant','GSTR-2B fully matched to purchase register'),
    ('2026-06','itc_reconciliation','29AABCS4567L1ZP Siemens Healthineers Bengaluru',96,
     720000.00,340000.00,340000.00,100.00,98.00,'vendor_not_filed','filed_on_time','itc_recovery_action','Vendor GSTR-1 not filed for Rs 3.4L ITC — held for follow-up'),
    ('2026-06','itc_reconciliation','27AAACG9012M1Z8 GE Healthcare Mumbai',143,
     1120000.00,88000.00,88000.00,100.00,100.00,'value_mismatch','filed_on_time','vendor_followup','Invoice value mismatch Rs 88k vs 2B — amendment requested'),
    ('2026-06','rcm_reverse_charge','07AAGFF3344N1ZQ Bluedart Freight Logistics Delhi',38,
     152000.00,0.00,96000.00,0.00,0.00,'rcm_pending','pending','itc_recovery_action','RCM on GTA freight Rs 96k not yet discharged in 3B'),
    ('2026-06','einvoice_generation','33AABCA1332L1ZP Apollo Hospitals Chennai',320,
     0.00,0.00,0.00,96.50,0.00,'missing_irn','filed_on_time','vendor_followup','11 B2B invoices without IRN — regenerate before GSTR-1'),
    ('2026-06','einvoice_generation','06AABCF5678P1ZL Fortis Healthcare Gurgaon',205,
     0.00,0.00,0.00,100.00,0.00,'fully_matched','filed_on_time','compliant','All e-invoices IRN-generated on time'),
    ('2026-06','eway_bill','29AAECM8901Q1ZR Manipal Hospitals Bengaluru',180,
     0.00,0.00,0.00,0.00,91.00,'eway_expired','filed_on_time','vendor_followup','16 consignments e-way bill expired before delivery'),
    ('2026-06','eway_bill','07AAACA1122R1ZT AIIMS New Delhi',142,
     0.00,0.00,0.00,0.00,100.00,'fully_matched','filed_on_time','compliant','Full e-way coverage on dispatch'),
    ('2026-06','gstr1_filing','33AAGCE2233S1ZU EquipSeva HO Chennai',512,
     0.00,0.00,0.00,99.00,96.00,'fully_matched','filed_on_time','compliant','GSTR-1 filed by 11th — outward supplies reconciled'),
    ('2026-05','gstr3b_filing','33AAGCE2233S1ZU EquipSeva HO Chennai',498,
     0.00,0.00,0.00,0.00,0.00,'fully_matched','filed_late','filing_overdue','GSTR-3B filed 6 days late — interest Rs 4.2k paid'),
    ('2026-05','itc_reconciliation','33AAKCS7788T1ZV Surgical Sutures Coimbatore',64,
     210000.00,145000.00,145000.00,100.00,100.00,'gstin_error','pending','vendor_followup','Wrong GSTIN on vendor invoices — Rs 1.45L ITC blocked'),
    ('2026-06','itc_reconciliation','24AADCP4455U1ZW Philips India Ahmedabad',88,
     640000.00,0.00,0.00,100.00,100.00,'fully_matched','filed_on_time','compliant','Fully matched, no ITC at risk'),
    ('2026-04','gstr3b_filing','33AAGCE2233S1ZU EquipSeva HO Chennai',470,
     0.00,0.00,0.00,0.00,0.00,'value_mismatch','notice_received','notice_response_due','Dept notice DRC-01A on ITC excess Rs 2.1L — reply due'),
    ('2026-06','rcm_reverse_charge','36AAHCL6677V1ZX Iyer Legal & Advisory Hyderabad',12,
     45000.00,0.00,27000.00,0.00,0.00,'rcm_pending','filed_on_time','itc_recovery_action','RCM on legal fees Rs 27k pending self-invoice')
  ) as q(pm, ar, gv, ic, mi, ui, atr, irn, eway, mr, fs, cv, nt);

  -- CAPA seed — attach to at-risk / non-compliant rows via period + area + vendor key
  insert into public.gst_itc_compliance_capa_actions_r3321 (
    recon_id, org_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, v_org_id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('2026-06','itc_reconciliation','29AABCS4567L1ZP Siemens Healthineers Bengaluru',
     'vendor_non_filing','vendor_gstr1_not_filed','vendor_followup_notice','in_progress','itc_reversal_risk','2026-07-15',null,340000.00,'Follow-up with Siemens to file GSTR-1; Rs 3.4L ITC recoverable'),
    ('2026-06','itc_reconciliation','27AAACG9012M1Z8 GE Healthcare Mumbai',
     'value_mismatch','invoice_value_mismatch','amend_gstr1','open','itc_reversal_risk','2026-07-20',null,88000.00,'Requested GE credit note / amendment for Rs 88k mismatch'),
    ('2026-06','rcm_reverse_charge','07AAGFF3344N1ZQ Bluedart Freight Logistics Delhi',
     'rcm_liability','rcm_not_discharged','discharge_rcm_liability','open','interest_penalty_exposure','2026-07-20',null,96000.00,'Self-invoice + pay RCM Rs 96k on GTA freight in next 3B'),
    ('2026-06','einvoice_generation','33AABCA1332L1ZP Apollo Hospitals Chennai',
     'missing_einvoice_irn','irn_not_generated','generate_missing_irn','verification_pending','internal_only','2026-07-10','2026-07-08',0.00,'IRNs generated for 11 invoices; verify before GSTR-1 push'),
    ('2026-06','eway_bill','29AAECM8901Q1ZR Manipal Hospitals Bengaluru',
     'eway_bill_gap','eway_bill_expired','regenerate_eway_bill','in_progress','audit_flag','2026-07-12',null,15000.00,'16 expired e-way bills — regenerate and update delivery proof'),
    ('2026-05','itc_reconciliation','33AAKCS7788T1ZV Surgical Sutures Coimbatore',
     'gstin_validation','vendor_wrong_gstin','correct_gstin_master','open','itc_reversal_risk','2026-07-18',null,145000.00,'Wrong GSTIN — correct vendor master, request revised invoices'),
    ('2026-04','gstr3b_filing','33AAGCE2233S1ZU EquipSeva HO Chennai',
     'gstr_filing_delay','filing_process_delay','respond_to_notice','escalated','gst_notice_risk','2026-07-14',null,210000.00,'DRC-01A notice reply drafted with CA — Rs 2.1L ITC defense')
  ) as q(pm, ar, gv, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.gst_itc_compliance_r3321 e
    on e.org_id = v_org_id and e.period_month = q.pm and e.area = q.ar and e.gstin_or_vendor = q.gv;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3321_compliance_verdict_rollup()
returns table(compliance_verdict text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gst_itc_compliance_r3321)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gst_itc_compliance_r3321 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3321_compliance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3321_compliance_verdict_rollup() to authenticated;

-- 2) Vendor / GSTIN ITC scorecard
create or replace function public.founder_r3321_vendor_scorecard()
returns table(
  gstin_or_vendor text,
  entries bigint,
  total_invoices bigint,
  matched_itc_rupees numeric,
  unmatched_itc_rupees numeric,
  itc_at_risk_rupees numeric,
  avg_irn_coverage_pct numeric,
  avg_eway_coverage_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gstin_or_vendor,
    count(*)::bigint,
    sum(l.invoice_count)::bigint,
    coalesce(sum(l.matched_itc_rupees),0)::numeric,
    coalesce(sum(l.unmatched_itc_rupees),0)::numeric,
    coalesce(sum(l.itc_at_risk_rupees),0)::numeric,
    round(avg(l.einvoice_irn_coverage_pct), 1),
    round(avg(l.eway_bill_coverage_pct), 1)
  from public.gst_itc_compliance_r3321 l
  group by l.gstin_or_vendor
  order by coalesce(sum(l.itc_at_risk_rupees),0) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3321_vendor_scorecard() from public, anon;
grant execute on function public.founder_r3321_vendor_scorecard() to authenticated;

-- 3) Area x mismatch-reason matrix
create or replace function public.founder_r3321_area_reason_matrix()
returns table(area text, mismatch_reason text, entries bigint, itc_at_risk_rupees numeric, avg_irn_coverage_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.area, l.mismatch_reason, count(*)::bigint,
    coalesce(sum(l.itc_at_risk_rupees),0)::numeric,
    round(avg(l.einvoice_irn_coverage_pct), 1)
  from public.gst_itc_compliance_r3321 l
  group by l.area, l.mismatch_reason
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3321_area_reason_matrix() from public, anon;
grant execute on function public.founder_r3321_area_reason_matrix() to authenticated;

-- 4) Period-month trend
create or replace function public.founder_r3321_period_trend()
returns table(period_month text, entries bigint, total_invoices bigint, matched_itc_rupees numeric, itc_at_risk_rupees numeric, notices bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    sum(l.invoice_count)::bigint,
    coalesce(sum(l.matched_itc_rupees),0)::numeric,
    coalesce(sum(l.itc_at_risk_rupees),0)::numeric,
    count(*) filter (where l.filing_status = 'notice_received')::bigint
  from public.gst_itc_compliance_r3321 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3321_period_trend() from public, anon;
grant execute on function public.founder_r3321_period_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3321_capa_status_board()
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
  from public.gst_itc_compliance_capa_actions_r3321 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3321_capa_status_board() from public, anon;
grant execute on function public.founder_r3321_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3321_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gst_itc_compliance_capa_actions_r3321)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gst_itc_compliance_capa_actions_r3321 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3321_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3321_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3321_regulatory_impact_digest()
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
  from public.gst_itc_compliance_capa_actions_r3321 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3321_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3321_regulatory_impact_digest() to authenticated;

-- 8) High-risk ITC / filing queue (top individual concerns)
create or replace function public.founder_r3321_high_risk_queue()
returns table(
  period_month text,
  area text,
  gstin_or_vendor text,
  invoice_count int,
  itc_at_risk_rupees numeric,
  mismatch_reason text,
  filing_status text,
  compliance_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, l.area, l.gstin_or_vendor, l.invoice_count,
    l.itc_at_risk_rupees, l.mismatch_reason, l.filing_status, l.compliance_verdict, l.notes
  from public.gst_itc_compliance_r3321 l
  where l.compliance_verdict in ('itc_recovery_action','vendor_followup','filing_overdue','notice_response_due')
     or l.mismatch_reason in ('vendor_not_filed','value_mismatch','gstin_error','missing_irn','eway_expired','rcm_pending')
     or l.filing_status in ('filed_late','pending','notice_received')
     or coalesce(l.itc_at_risk_rupees,0) > 0
  order by coalesce(l.itc_at_risk_rupees,0) desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3321_high_risk_queue() from public, anon;
grant execute on function public.founder_r3321_high_risk_queue() to authenticated;
