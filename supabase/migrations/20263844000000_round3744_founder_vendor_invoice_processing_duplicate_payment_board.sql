-- Round 3744: Founder Vendor Invoice-Processing / Duplicate-Payment Board
-- Accounts-payable invoice-processing accuracy — duplicate-invoice detection,
-- 3-way-match exceptions, processing TAT, duplicate-payment recovery. Distinct
-- from any credit-note/debit-note billing-adjustment-reconciliation page, which
-- is CUSTOMER-side billing, and from any P2P-cycle-time page, which is the
-- requisition-to-GRN cycle not invoice-payment accuracy.

-- =============================================================================
-- TABLE 1: ap_invoice_r3744 — per-vendor-month AP invoice-processing facts
-- =============================================================================
create table if not exists public.ap_invoice_r3744 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  invoice_category text not null,
  period_month date not null,
  invoices_processed int not null,
  duplicate_invoices_flagged int,
  three_way_match_exceptions int,
  avg_processing_days numeric,
  duplicate_payments_recovered_rupees numeric(12,2),
  duplicate_payments_at_risk_rupees numeric(12,2),
  early_payment_discount_captured_rupees numeric(12,2),
  manual_override_count int,
  invoice_class text not null check (invoice_class in (
    'spare_parts','services','capex','utilities','statutory_payments'
  )),
  processing_status text not null check (processing_status in (
    'clean_processed','minor_exceptions','duplicate_flagged','duplicate_paid_unrecovered','fraud_suspected'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ap_invoice_r3744 enable row level security;

create index if not exists idx_ap_invoice_r3744_org on public.ap_invoice_r3744(organization_id);
create index if not exists idx_ap_invoice_r3744_month on public.ap_invoice_r3744(period_month);
create index if not exists idx_ap_invoice_r3744_status on public.ap_invoice_r3744(processing_status);

-- =============================================================================
-- TABLE 2: ap_invoice_capa_actions_r3744 — CAPA for duplicate/exception gaps
-- =============================================================================
create table if not exists public.ap_invoice_capa_actions_r3744 (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid references public.ap_invoice_r3744(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ap_invoice_capa_actions_r3744 enable row level security;

create index if not exists idx_ap_invoice_capa_r3744_inv on public.ap_invoice_capa_actions_r3744(invoice_id);
create index if not exists idx_ap_invoice_capa_r3744_status on public.ap_invoice_capa_actions_r3744(capa_status);

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

  -- 16 vendor-month AP invoice-processing rows
  insert into public.ap_invoice_r3744 (
    organization_id, vendor_name, invoice_category, period_month, invoices_processed,
    duplicate_invoices_flagged, three_way_match_exceptions, avg_processing_days,
    duplicate_payments_recovered_rupees, duplicate_payments_at_risk_rupees,
    early_payment_discount_captured_rupees, manual_override_count,
    invoice_class, processing_status, trend_dir, notes
  )
  select v_org_id, q.vn, q.ic, q.pm::date, q.ip::int,
    q.dif::int, q.twme::int, q.apd::numeric,
    q.dpr::numeric, q.dpar::numeric,
    q.epdc::numeric, q.moc::int,
    q.cls, q.st, q.td, q.nt
  from (values
    ('Bharat Earthmovers Spares Pvt Ltd','Spare parts supply','2026-07-01',412,2,5,3.4,0,0,18500,3,'spare_parts','clean_processed','stable','All invoices cleared 3-way match within SLA'),
    ('Konnect Facility Services','Housekeeping and facility services','2026-07-01',86,1,3,4.1,0,42000,0,5,'services','minor_exceptions','stable','Minor rate mismatches resolved via PO amendment'),
    ('Titan Capital Equipment Leasing','Capex equipment lease','2026-06-01',18,1,1,6.8,0,0,0,2,'capex','clean_processed','improving','Lease invoices reconciled against asset register cleanly'),
    ('Sunrise Power Distribution Co','Utility electricity billing','2026-07-01',34,2,4,5.2,0,68000,0,4,'utilities','duplicate_flagged','worsening','Same meter-reading invoice resubmitted twice by vendor portal glitch'),
    ('National Statutory Filings Agency','Statutory and compliance payments','2026-07-01',22,0,0,2.1,0,0,0,0,'statutory_payments','clean_processed','stable','Statutory dues processed on due date with zero exceptions'),
    ('Precision Hydraulics Traders','Spare parts supply','2026-06-01',298,4,9,5.6,125000,0,9200,7,'spare_parts','duplicate_paid_unrecovered','worsening','Duplicate invoice slipped past match control — recovery notice sent, vendor yet to refund'),
    ('Metro Security & Manpower Services','Manpower and security services','2026-07-01',64,1,2,3.8,15000,0,0,2,'services','clean_processed','improving','One duplicate caught pre-payment and recovered same cycle'),
    ('Apex Tower Crane Rentals','Capex equipment lease','2026-05-01',12,0,2,7.5,0,0,0,1,'capex','minor_exceptions','stable','Rate escalation clause mismatch corrected before payment'),
    ('Ganga Water Utility Board','Utility water billing','2026-06-01',28,1,1,4.4,0,21000,0,1,'utilities','minor_exceptions','stable','Duplicate meter charge flagged and withheld at approval stage'),
    ('State GST Compliance Cell','Statutory and compliance payments','2026-06-01',20,1,0,2.9,0,35000,0,1,'statutory_payments','duplicate_flagged','worsening','Duplicate GST challan payment request caught by finance before disbursement'),
    ('Vishal Steel Fabricators','Spare parts supply','2026-07-01',187,6,11,6.9,0,215000,0,8,'spare_parts','fraud_suspected','worsening','Pattern of near-identical invoice numbers with altered bank details — flagged to internal audit'),
    ('CleanTech Facility Solutions','Housekeeping and facility services','2026-06-01',74,0,1,3.2,0,0,12500,1,'services','clean_processed','improving','Early-payment discount captured on bulk quarterly settlement'),
    ('Orion Diesel Generator Leasing','Capex equipment lease','2026-07-01',15,1,3,8.2,0,54000,0,3,'capex','duplicate_flagged','worsening','Duplicate lease-renewal invoice caught at 3-way match, awaiting vendor credit note'),
    ('Bharat Petroleum Corp Fuel Desk','Utility fuel and energy billing','2026-07-01',41,3,6,5.9,0,88000,0,5,'utilities','duplicate_paid_unrecovered','worsening','Two duplicate fuel-card invoices paid before flag raised — recovery in progress'),
    ('Regional Labour Compliance Office','Statutory and compliance payments','2026-05-01',19,0,0,2.4,0,0,0,0,'statutory_payments','clean_processed','stable','PF and ESI remittances processed without exception'),
    ('Om Sai Spare Parts Distributors','Spare parts supply','2026-05-01',156,2,4,4.7,38000,0,6100,2,'spare_parts','minor_exceptions','improving','Duplicate credit resolved and early-payment discount captured same month')
  ) as q(vn, ic, pm, ip, dif, twme, apd, dpr, dpar, epdc, moc, cls, st, td, nt);

  -- 8 CAPA rows — attach to invoice rows via vendor_name + period_month
  insert into public.ap_invoice_capa_actions_r3744 (
    invoice_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select i.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Sunrise Power Distribution Co','2026-07-01','Vendor billing portal auto-resubmitted same meter-reading invoice under a new number','Request vendor to disable auto-resubmission and enforce unique invoice-number validation at gateway','in_progress','AP Controls Manager','2026-08-25',null,'Vendor IT team engaged — fix expected before next billing cycle'),
    ('Precision Hydraulics Traders','2026-06-01','Duplicate-invoice detection rule missed near-duplicate with different invoice date','Tighten fuzzy-match rule to cover vendor+amount+PO combination regardless of invoice date','open','AP Process Owner','2026-08-28',null,'Refund demand letter sent to vendor; awaiting confirmation of credit note'),
    ('Vishal Steel Fabricators','2026-07-01','Suspected fraud pattern — sequential invoice numbers with altered bank account details','Suspend vendor payments pending internal audit and bank-detail re-verification','open','Internal Audit Head','2026-08-20',null,'Case escalated to internal audit and risk committee; payments frozen'),
    ('Orion Diesel Generator Leasing','2026-07-01','Lease-renewal invoice resubmitted before original credit note was processed','Enforce hold on renewal invoices until prior-cycle credit notes are fully closed','in_progress','AP Controls Manager','2026-08-22',null,'Vendor has issued credit note draft; awaiting finance validation'),
    ('Bharat Petroleum Corp Fuel Desk','2026-07-01','Fuel-card invoices processed manually outside automated 3-way match due to format mismatch','Onboard vendor to standard EDI invoice format to restore automated matching','in_progress','AP Automation Lead','2026-09-05',null,'Vendor integration testing scheduled for next sprint'),
    ('State GST Compliance Cell','2026-06-01','Manual re-entry of GST challan created duplicate payment request in queue','Restrict manual challan entry and route all statutory payments through single automated feed','closed','Statutory Compliance Lead','2026-07-15','2026-07-10','Automated feed now live; no repeat duplicates observed since fix'),
    ('Ganga Water Utility Board','2026-06-01','Duplicate meter-reading charge from utility billing system glitch','Add meter-reading-period uniqueness check to invoice intake validation','closed','AP Process Owner','2026-07-20','2026-07-18','Validation rule deployed; utility vendor also acknowledged billing system fix'),
    ('Apex Tower Crane Rentals','2026-05-01','Rate-escalation clause not reflected in PO before invoice submission','Update PO template to auto-apply agreed escalation schedule at contract renewal','overdue','Procurement-Finance Liaison','2026-08-05',null,'Fix pending sign-off from procurement; escalated past original target date')
  ) as q(vn, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.ap_invoice_r3744 i
    on i.organization_id = v_org_id and i.vendor_name = q.vn and i.period_month = q.pm::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Processing-status distribution
create or replace function public.founder_r3744_processing_status_rollup()
returns table(processing_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ap_invoice_r3744)
  select l.processing_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ap_invoice_r3744 l
  group by l.processing_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3744_processing_status_rollup() from public, anon;
grant execute on function public.founder_r3744_processing_status_rollup() to authenticated;

-- 2) Vendor scorecard
create or replace function public.founder_r3744_vendor_scorecard()
returns table(
  vendor_name text,
  records bigint,
  invoices_processed_total bigint,
  duplicate_flagged_total bigint,
  match_exceptions_total bigint,
  avg_processing_days numeric,
  duplicate_at_risk_rupees numeric,
  duplicate_recovered_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name,
    count(*)::bigint,
    coalesce(sum(l.invoices_processed),0)::bigint,
    coalesce(sum(l.duplicate_invoices_flagged),0)::bigint,
    coalesce(sum(l.three_way_match_exceptions),0)::bigint,
    round(avg(l.avg_processing_days), 1),
    coalesce(sum(l.duplicate_payments_at_risk_rupees),0),
    coalesce(sum(l.duplicate_payments_recovered_rupees),0)
  from public.ap_invoice_r3744 l
  group by l.vendor_name
  order by coalesce(sum(l.duplicate_payments_at_risk_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3744_vendor_scorecard() from public, anon;
grant execute on function public.founder_r3744_vendor_scorecard() to authenticated;

-- 3) Invoice-class x processing-status matrix
create or replace function public.founder_r3744_invoice_class_status_matrix()
returns table(invoice_class text, processing_status text, records bigint, avg_processing_days numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.invoice_class, l.processing_status, count(*)::bigint,
    round(avg(l.avg_processing_days), 1)
  from public.ap_invoice_r3744 l
  group by l.invoice_class, l.processing_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3744_invoice_class_status_matrix() from public, anon;
grant execute on function public.founder_r3744_invoice_class_status_matrix() to authenticated;

-- 4) Monthly exception trend
create or replace function public.founder_r3744_monthly_exception_trend()
returns table(
  period_month date,
  records bigint,
  duplicate_flagged_total bigint,
  match_exceptions_total bigint,
  avg_processing_days numeric,
  worsening_records bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.duplicate_invoices_flagged),0)::bigint,
    coalesce(sum(l.three_way_match_exceptions),0)::bigint,
    round(avg(l.avg_processing_days), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.ap_invoice_r3744 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3744_monthly_exception_trend() from public, anon;
grant execute on function public.founder_r3744_monthly_exception_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3744_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.ap_invoice_capa_actions_r3744 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3744_capa_status_board() from public, anon;
grant execute on function public.founder_r3744_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3744_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ap_invoice_capa_actions_r3744)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ap_invoice_capa_actions_r3744 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3744_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3744_root_cause_pareto() to authenticated;

-- 7) Duplicate-payment digest (vendors/months with duplicate-payment risk)
create or replace function public.founder_r3744_duplicate_payment_digest()
returns table(
  vendor_name text,
  records bigint,
  duplicate_flagged_total bigint,
  duplicate_at_risk_rupees numeric,
  duplicate_recovered_rupees numeric,
  unrecovered_records bigint,
  fraud_suspected_records bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name,
    count(*)::bigint,
    coalesce(sum(l.duplicate_invoices_flagged),0)::bigint,
    coalesce(sum(l.duplicate_payments_at_risk_rupees),0),
    coalesce(sum(l.duplicate_payments_recovered_rupees),0),
    count(*) filter (where l.processing_status = 'duplicate_paid_unrecovered')::bigint,
    count(*) filter (where l.processing_status = 'fraud_suspected')::bigint
  from public.ap_invoice_r3744 l
  where l.duplicate_invoices_flagged > 0
    or l.processing_status in ('duplicate_flagged','duplicate_paid_unrecovered','fraud_suspected')
  group by l.vendor_name
  order by coalesce(sum(l.duplicate_payments_at_risk_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3744_duplicate_payment_digest() from public, anon;
grant execute on function public.founder_r3744_duplicate_payment_digest() to authenticated;

-- 8) High-risk invoice queue (duplicate-paid-unrecovered / fraud-suspected, worst first)
create or replace function public.founder_r3744_high_risk_queue()
returns table(
  vendor_name text,
  invoice_category text,
  invoice_class text,
  period_month date,
  processing_status text,
  duplicate_payments_at_risk_rupees numeric,
  three_way_match_exceptions int,
  avg_processing_days numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.invoice_category, l.invoice_class, l.period_month,
    l.processing_status, l.duplicate_payments_at_risk_rupees,
    l.three_way_match_exceptions, l.avg_processing_days, l.notes
  from public.ap_invoice_r3744 l
  where l.processing_status in ('duplicate_paid_unrecovered','fraud_suspected')
  order by l.duplicate_payments_at_risk_rupees desc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3744_high_risk_queue() from public, anon;
grant execute on function public.founder_r3744_high_risk_queue() to authenticated;
