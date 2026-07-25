-- Round 3404: Engineer Vendor-Invoice Three-Way-Match Discrepancy Tracker
-- AP finance-integrity — vendor × spend category × three-way match (PO vs GRN vs invoice) × discrepancy type × resolution status × match verdict × aging × CAPA controls

-- =============================================================================
-- TABLE 1: vendor_invoice_match_r3404 — per-invoice three-way-match check
-- =============================================================================
create table if not exists public.vendor_invoice_match_r3404 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  invoice_ref text not null,
  po_ref text,
  grn_ref text,
  spend_category text not null check (spend_category in (
    'spare_parts','logistics','it_saas','professional_services','consumables','tools'
  )),
  invoice_date date not null,
  invoice_value_rupees numeric(14,2) not null,
  po_value_rupees numeric(14,2),
  grn_value_rupees numeric(14,2),
  quantity_match boolean not null,
  price_match boolean not null,
  tax_gst_match boolean not null,
  three_way_matched boolean not null,
  discrepancy_type text not null check (discrepancy_type in (
    'no_discrepancy','price_variance','quantity_variance','tax_mismatch','missing_grn','duplicate_invoice','no_po'
  )),
  discrepancy_value_rupees numeric(14,2),
  resolution_status text not null check (resolution_status in (
    'matched_approved','on_hold','disputed_vendor','corrected','rejected'
  )),
  aging_days int not null,
  match_verdict text not null check (match_verdict in (
    'clean_pay','minor_variance_pay','hold_investigate','dispute','reject'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_invoice_match_r3404 enable row level security;

create index if not exists idx_vendor_invoice_match_r3404_org on public.vendor_invoice_match_r3404(organization_id);
create index if not exists idx_vendor_invoice_match_r3404_date on public.vendor_invoice_match_r3404(invoice_date);
create index if not exists idx_vendor_invoice_match_r3404_verdict on public.vendor_invoice_match_r3404(match_verdict);

-- =============================================================================
-- TABLE 2: vendor_invoice_match_capa_actions_r3404 — CAPA & control actions
-- =============================================================================
create table if not exists public.vendor_invoice_match_capa_actions_r3404 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  match_log_id uuid not null references public.vendor_invoice_match_r3404(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'price_variance','quantity_variance','tax_gst_mismatch','missing_grn',
    'duplicate_invoice','missing_po','aging_breach','master_data_error'
  )),
  root_cause text not null check (root_cause in (
    'vendor_overbilling','po_not_updated','grn_not_posted','gst_rate_error',
    'catalog_price_stale','duplicate_submission','short_shipment','contract_price_mismatch',
    'pending_investigation','manual_entry_error'
  )),
  corrective_action text not null check (corrective_action in (
    'request_credit_note','correct_po','post_grn','correct_gst','update_price_master',
    'reject_duplicate','hold_payment','dispute_with_vendor','escalate_to_finance_head',
    'approve_with_tolerance','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  control_impact text not null check (control_impact in (
    'ap_payment_hold','gst_itc_risk','budget_overspend','none','internal_only',
    'audit_finding','duplicate_payment_averted'
  )),
  target_closure_date date,
  actual_closure_date date,
  recovery_amount_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_invoice_match_capa_actions_r3404 enable row level security;

create index if not exists idx_vendor_invoice_capa_r3404_org on public.vendor_invoice_match_capa_actions_r3404(organization_id);
create index if not exists idx_vendor_invoice_capa_r3404_log on public.vendor_invoice_match_capa_actions_r3404(match_log_id);
create index if not exists idx_vendor_invoice_capa_r3404_status on public.vendor_invoice_match_capa_actions_r3404(capa_status);

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

  -- 14 invoice three-way-match rows
  insert into public.vendor_invoice_match_r3404 (
    organization_id, vendor_name, invoice_ref, po_ref, grn_ref, spend_category, invoice_date,
    invoice_value_rupees, po_value_rupees, grn_value_rupees,
    quantity_match, price_match, tax_gst_match, three_way_matched,
    discrepancy_type, discrepancy_value_rupees, resolution_status, aging_days, match_verdict, notes
  )
  select v_org_id, q.vendor, q.inv, q.po, q.grn, q.cat, q.idate::date,
    q.ival, q.poval, q.grnval,
    q.qm, q.pm, q.tm, q.twm,
    q.dtype, q.dval, q.rstatus, q.aging::int, q.verdict, q.nt
  from (values
    ('Siemens Healthineers India','INV-SIE-4401','PO-SIE-8801','GRN-SIE-9901','spare_parts','2026-07-10',
     245000.00,245000.00,245000.00,true,true,true,true,'no_discrepancy',0.00,'matched_approved',4,'clean_pay','CT tube spare — PO, GRN and invoice fully aligned for Apollo Chennai CSSD'),
    ('GE Healthcare Spares','INV-GE-2210','PO-GE-5510','GRN-GE-6610','spare_parts','2026-07-10',
     132500.00,130000.00,130000.00,true,false,true,false,'price_variance',2500.00,'corrected',6,'minor_variance_pay','Unit price 1.9% above PO — within 2% tolerance, price master updated then paid'),
    ('Blue Dart Logistics','INV-BDL-3110','PO-BDL-7710','GRN-BDL-8810','logistics','2026-07-09',
     56000.00,56000.00,56000.00,true,true,true,true,'no_discrepancy',0.00,'matched_approved',5,'clean_pay','Spare-parts courier freight for Fortis Gurgaon — matched clean'),
    ('Freshworks SaaS','INV-FRW-3301',null,null,'it_saas','2026-07-09',
     89000.00,null,null,false,false,true,false,'no_po',89000.00,'on_hold',12,'hold_investigate','Helpdesk SaaS auto-renew billed with no PO raised — payment held for retro PO'),
    ('Deloitte Advisory','INV-DEL-5501','PO-DEL-4401','GRN-DEL-5401','professional_services','2026-07-08',
     189000.00,180000.00,180000.00,true,true,false,false,'tax_mismatch',9000.00,'disputed_vendor',15,'dispute','GST charged at 18% vs 12% applicable on advisory — ITC at risk, disputed with vendor'),
    ('3M India Consumables','INV-3M-6601','PO-3M-2201','GRN-3M-3301','consumables','2026-07-08',
     60000.00,60000.00,48000.00,false,true,true,false,'quantity_variance',12000.00,'on_hold',8,'hold_investigate','Invoiced 100 units but GRN confirms 80 received at Manipal Bengaluru — short shipment'),
    ('Bosch Tools India','INV-BSH-7010','PO-BSH-9010','GRN-BSH-1010','tools','2026-07-07',
     34000.00,34000.00,34000.00,true,true,true,true,'no_discrepancy',0.00,'matched_approved',3,'clean_pay','Torque wrench calibration toolkit — three-way match clean'),
    ('Philips Service Spares','INV-PHL-7701','PO-PHL-5501','GRN-PHL-6601','spare_parts','2026-07-07',
     78000.00,78000.00,78000.00,true,true,true,false,'duplicate_invoice',78000.00,'rejected',3,'reject','Duplicate of already-paid invoice INV-PHL-7699 — rejected before payment'),
    ('DTDC Express','INV-DTD-8801','PO-DTD-2202',null,'logistics','2026-07-06',
     42000.00,42000.00,null,false,true,true,false,'missing_grn',42000.00,'on_hold',10,'hold_investigate','Freight invoice received but service GRN not posted by ops — receipt unconfirmed'),
    ('Zoho Corporation','INV-ZOH-1010','PO-ZOH-3010','GRN-ZOH-4010','it_saas','2026-07-06',
     145000.00,145000.00,145000.00,true,true,true,true,'no_discrepancy',0.00,'matched_approved',4,'clean_pay','Annual field-app license against approved PO — matched and approved'),
    ('KPMG Consulting','INV-KPM-4510','PO-KPM-6610','GRN-KPM-7710','professional_services','2026-07-05',
     245000.00,200000.00,200000.00,true,false,true,false,'price_variance',45000.00,'disputed_vendor',18,'dispute','Consulting day-rate 22% above contract rate — disputed, hold pending credit note'),
    ('Romsons Consumables','INV-ROM-2810','PO-ROM-4810','GRN-ROM-5810','consumables','2026-07-05',
     28000.00,28000.00,28000.00,true,true,true,true,'no_discrepancy',0.00,'matched_approved',6,'clean_pay','Disposable BP cuffs for AIIMS Delhi — matched clean'),
    ('Stanley Tools','INV-STN-2680','PO-STN-4680','GRN-STN-5680','tools','2026-07-04',
     26800.00,25000.00,25000.00,true,true,false,false,'tax_mismatch',1800.00,'corrected',5,'minor_variance_pay','GST rounding mismatch INR 1800 — corrected, minor variance approved for pay'),
    ('Drager India Spares','INV-DRG-9901','PO-DRG-1101','GRN-DRG-2201','spare_parts','2026-07-03',
     156000.00,78000.00,78000.00,false,false,true,false,'quantity_variance',78000.00,'rejected',22,'reject','Invoiced double the received quantity for CMC Vellore ventilator spares — rejected')
  ) as q(vendor, inv, po, grn, cat, idate, ival, poval, grnval, qm, pm, tm, twm, dtype, dval, rstatus, aging, verdict, nt);

  -- CAPA seed — attach to at-risk invoices via invoice_ref
  insert into public.vendor_invoice_match_capa_actions_r3404 (
    organization_id, match_log_id, finding_category, root_cause, corrective_action,
    capa_status, control_impact, target_closure_date, actual_closure_date,
    recovery_amount_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.tcd::date, q.acd::date,
    q.rec, q.nt
  from (values
    ('INV-GE-2210','price_variance','catalog_price_stale','update_price_master','in_progress','budget_overspend','2026-07-14',null,2500.00,'Price master stale vs current contract — updating rate, minor variance approved'),
    ('INV-FRW-3301','missing_po','po_not_updated','correct_po','open','ap_payment_hold','2026-07-15',null,89000.00,'SaaS auto-renew without PO — raising retrospective PO before AP release'),
    ('INV-DEL-5501','tax_gst_mismatch','gst_rate_error','correct_gst','escalated','gst_itc_risk','2026-07-12',null,9000.00,'GST 18% vs 12% applicable — ITC exposure, escalated to finance head, disputed'),
    ('INV-3M-6601','quantity_variance','short_shipment','request_credit_note','verification_pending','ap_payment_hold','2026-07-13',null,12000.00,'Short shipment of 20 units — credit note requested, verifying against GRN'),
    ('INV-PHL-7701','duplicate_invoice','duplicate_submission','reject_duplicate','closed','duplicate_payment_averted','2026-07-09','2026-07-08',78000.00,'Duplicate of paid INV-PHL-7699 — rejected, double payment of INR 78000 averted'),
    ('INV-DTD-8801','missing_grn','grn_not_posted','post_grn','open','ap_payment_hold','2026-07-11',null,42000.00,'Service GRN not posted by ops — following up receipt confirmation before pay'),
    ('INV-DRG-9901','quantity_variance','vendor_overbilling','dispute_with_vendor','escalated','audit_finding','2026-07-16',null,78000.00,'Invoiced double received qty — rejected and disputed, flagged to audit')
  ) as q(inv, fc, rc, ca, cst, ci, tcd, acd, rec, nt)
  join public.vendor_invoice_match_r3404 e
    on e.organization_id = v_org_id and e.invoice_ref = q.inv;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Match verdict distribution
create or replace function public.founder_r3404_match_verdict_rollup()
returns table(match_verdict text, invoices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_invoice_match_r3404)
  select l.match_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vendor_invoice_match_r3404 l
  group by l.match_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3404_match_verdict_rollup() from public, anon;
grant execute on function public.founder_r3404_match_verdict_rollup() to authenticated;

-- 2) Vendor-level match scorecard
create or replace function public.founder_r3404_vendor_scorecard()
returns table(
  vendor_name text,
  total_invoices bigint,
  clean_pay bigint,
  minor_variance bigint,
  hold_dispute_reject bigint,
  three_way_matched_count bigint,
  discrepancy_value_rupees numeric,
  match_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name,
    count(*)::bigint,
    count(*) filter (where l.match_verdict = 'clean_pay')::bigint,
    count(*) filter (where l.match_verdict = 'minor_variance_pay')::bigint,
    count(*) filter (where l.match_verdict in ('hold_investigate','dispute','reject'))::bigint,
    count(*) filter (where l.three_way_matched = true)::bigint,
    coalesce(sum(l.discrepancy_value_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.match_verdict in ('clean_pay','minor_variance_pay'))::numeric / nullif(count(*),0), 1)
  from public.vendor_invoice_match_r3404 l
  group by l.vendor_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3404_vendor_scorecard() from public, anon;
grant execute on function public.founder_r3404_vendor_scorecard() to authenticated;

-- 3) Spend-category × discrepancy-type matrix
create or replace function public.founder_r3404_category_discrepancy_matrix()
returns table(spend_category text, discrepancy_type text, invoices bigint, three_way_matched_count bigint, discrepancy_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.spend_category, l.discrepancy_type, count(*)::bigint,
    count(*) filter (where l.three_way_matched = true)::bigint,
    coalesce(sum(l.discrepancy_value_rupees),0)::numeric
  from public.vendor_invoice_match_r3404 l
  group by l.spend_category, l.discrepancy_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3404_category_discrepancy_matrix() from public, anon;
grant execute on function public.founder_r3404_category_discrepancy_matrix() to authenticated;

-- 4) Daily three-way-match trend
create or replace function public.founder_r3404_daily_match_trend()
returns table(invoice_date date, invoices bigint, clean_pay bigint, discrepancies bigint, hold_dispute bigint, discrepancy_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.invoice_date,
    count(*)::bigint,
    count(*) filter (where l.match_verdict = 'clean_pay')::bigint,
    count(*) filter (where l.discrepancy_type <> 'no_discrepancy')::bigint,
    count(*) filter (where l.match_verdict in ('hold_investigate','dispute','reject'))::bigint,
    coalesce(sum(l.discrepancy_value_rupees),0)::numeric
  from public.vendor_invoice_match_r3404 l
  group by l.invoice_date
  order by l.invoice_date desc;
end;
$$;

revoke execute on function public.founder_r3404_daily_match_trend() from public, anon;
grant execute on function public.founder_r3404_daily_match_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3404_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.vendor_invoice_match_capa_actions_r3404 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3404_capa_status_board() from public, anon;
grant execute on function public.founder_r3404_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3404_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_invoice_match_capa_actions_r3404)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vendor_invoice_match_capa_actions_r3404 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3404_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3404_root_cause_pareto() to authenticated;

-- 7) Control-impact digest
create or replace function public.founder_r3404_impact_digest()
returns table(control_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.control_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_amount_rupees),0)::numeric
  from public.vendor_invoice_match_capa_actions_r3404 c
  group by c.control_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3404_impact_digest() from public, anon;
grant execute on function public.founder_r3404_impact_digest() to authenticated;

-- 8) High-risk invoice queue
create or replace function public.founder_r3404_high_risk_queue()
returns table(
  vendor_name text,
  invoice_ref text,
  po_ref text,
  grn_ref text,
  spend_category text,
  invoice_date date,
  invoice_value_rupees numeric,
  discrepancy_type text,
  discrepancy_value_rupees numeric,
  resolution_status text,
  aging_days int,
  match_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.invoice_ref, l.po_ref, l.grn_ref, l.spend_category,
    l.invoice_date, l.invoice_value_rupees, l.discrepancy_type, l.discrepancy_value_rupees,
    l.resolution_status, l.aging_days, l.match_verdict, l.notes
  from public.vendor_invoice_match_r3404 l
  where l.match_verdict in ('hold_investigate','dispute','reject')
     or l.three_way_matched = false
     or l.discrepancy_type <> 'no_discrepancy'
     or l.resolution_status in ('on_hold','disputed_vendor','rejected')
     or l.aging_days > 15
  order by l.aging_days desc, l.vendor_name;
end;
$$;

revoke execute on function public.founder_r3404_high_risk_queue() from public, anon;
grant execute on function public.founder_r3404_high_risk_queue() to authenticated;
