-- Round 3341: Founder Import-Procurement Forex / LC / Customs-Clearance Governance Board
-- Trade finance — import shipment × origin × payment/LC status × forex hedge × customs duty × CHA clearance × landed cost × verdict × CAPA

-- =============================================================================
-- TABLE 1: import_forex_lc_r3341 — per import shipment trade-finance / clearance record
-- =============================================================================
create table if not exists public.import_forex_lc_r3341 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  shipment_ref text not null,
  oem_supplier text not null,
  origin_country text not null check (origin_country in (
    'usa','germany','japan','china','south_korea','singapore'
  )),
  equipment_or_parts text not null,
  destination_site text not null,
  shipment_date date not null,
  invoice_value_usd numeric(14,2) not null,
  inr_booked_rate numeric(8,4) not null,
  payment_mode text not null check (payment_mode in (
    'letter_of_credit','advance_tt','open_account','dp_da'
  )),
  lc_status text not null check (lc_status in (
    'not_applicable','lc_opened','documents_negotiated','lc_expired','discrepancy'
  )),
  forex_hedged boolean not null default false,
  hedge_rate numeric(8,4),
  customs_duty_rupees numeric(14,2),
  bcd_igst_paid boolean not null default false,
  cha_clearance_status text not null check (cha_clearance_status in (
    'pending','in_clearance','cleared','detained_query','demurrage_risk'
  )),
  landed_cost_inr numeric(14,2),
  days_in_transit int not null,
  shipment_verdict text not null check (shipment_verdict in (
    'on_track','lc_action_needed','customs_query','demurrage_risk','forex_loss_exposure','cleared_closed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.import_forex_lc_r3341 enable row level security;

create index if not exists idx_import_forex_lc_r3341_org on public.import_forex_lc_r3341(org_id);
create index if not exists idx_import_forex_lc_r3341_date on public.import_forex_lc_r3341(shipment_date);
create index if not exists idx_import_forex_lc_r3341_verdict on public.import_forex_lc_r3341(shipment_verdict);

-- =============================================================================
-- TABLE 2: import_forex_lc_capa_actions_r3341 — LC / customs / forex / demurrage CAPA actions
-- =============================================================================
create table if not exists public.import_forex_lc_capa_actions_r3341 (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.import_forex_lc_r3341(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'lc_discrepancy','lc_expiry','customs_duty_query','cha_demurrage',
    'forex_unhedged_exposure','documentation_gap','payment_delay','preventive_review'
  )),
  root_cause text not null check (root_cause in (
    'bank_document_mismatch','hs_code_misclassification','delayed_lc_amendment','cha_filing_delay',
    'forex_rate_movement','supplier_documentation_error','port_congestion','internal_approval_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'amend_lc_terms','negotiate_documents','reclassify_hs_code','expedite_cha_filing',
    'book_forward_hedge','pay_demurrage_release','escalate_to_bank','retrain_import_desk','schedule_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'forex_loss','demurrage_charge','duty_penalty','none','internal_only','shipment_delay'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.import_forex_lc_capa_actions_r3341 enable row level security;

create index if not exists idx_import_forex_lc_capa_r3341_ship on public.import_forex_lc_capa_actions_r3341(shipment_id);
create index if not exists idx_import_forex_lc_capa_r3341_status on public.import_forex_lc_capa_actions_r3341(capa_status);

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

  -- 14 import shipment rows
  insert into public.import_forex_lc_r3341 (
    org_id, shipment_ref, oem_supplier, origin_country, equipment_or_parts, destination_site,
    shipment_date, invoice_value_usd, inr_booked_rate, payment_mode, lc_status,
    forex_hedged, hedge_rate, customs_duty_rupees, bcd_igst_paid, cha_clearance_status,
    landed_cost_inr, days_in_transit, shipment_verdict, notes
  )
  select v_org_id, q.ref, q.oem, q.orig, q.eqp, q.dest,
    q.sdate::date, q.invusd, q.bookrate, q.pmode, q.lcst,
    q.hedged, q.hrate, q.duty, q.bcdigst, q.cha,
    q.landed, q.dit, q.verdict, q.nt
  from (values
    ('SHP-GE-2601','GE Healthcare','usa','CT X-ray tube assembly','EquipSeva Chennai Warehouse',
     '2026-06-28',128000.00,83.20,'letter_of_credit','documents_negotiated',
     true,83.05,1420000.00,true,'cleared',12180000.00,22,'cleared_closed','LC documents negotiated, BCD+IGST paid, cleared and delivered'),
    ('SHP-SIE-2602','Siemens Healthineers','germany','MRI gradient coil','Apollo Chennai',
     '2026-07-02',96000.00,83.40,'letter_of_credit','lc_opened',
     true,83.10,null,false,'in_clearance',null,14,'on_track','LC opened, goods in customs clearance, duty assessment awaited'),
    ('SHP-CAN-2603','Canon Medical Systems','japan','Cath-lab flat-panel detector','Fortis Gurgaon',
     '2026-06-25',152000.00,83.10,'letter_of_credit','discrepancy',
     true,82.95,1680000.00,false,'detained_query',null,30,'lc_action_needed','LC document discrepancy on B/L date — bank refused negotiation'),
    ('SHP-MIN-2604','Mindray','china','Patient monitor SpO2 boards','KIMS Hyderabad',
     '2026-06-20',42000.00,83.60,'advance_tt','not_applicable',
     false,null,380000.00,true,'demurrage_risk',null,28,'demurrage_risk','Container at Chennai port, CHA filing delayed, demurrage accruing'),
    ('SHP-SAM-2605','Samsung Medison','south_korea','Ultrasound transducer probes','Manipal Bengaluru',
     '2026-07-05',58000.00,83.30,'dp_da','not_applicable',
     false,null,null,false,'pending',null,8,'on_track','DP/DA shipment in transit, documents awaited at bank'),
    ('SHP-MDT-2606','Medtronic APAC','singapore','Ventilator turbine blower','AIIMS Delhi',
     '2026-06-18',74000.00,82.80,'open_account','not_applicable',
     false,null,690000.00,true,'cleared',6820000.00,19,'forex_loss_exposure','Unhedged open-account — INR weakened to 84.10 at payment, forex loss'),
    ('SHP-DRG-2607','Drager Medical','germany','Anesthesia vaporizer units','CMC Vellore',
     '2026-06-30',61000.00,83.35,'letter_of_credit','documents_negotiated',
     true,83.15,720000.00,true,'cleared',5980000.00,21,'cleared_closed','LC negotiated, hedged, duty paid, cleared and closed'),
    ('SHP-NK-2608','Nihon Kohden','japan','Defibrillator battery packs','EquipSeva Mumbai Hub',
     '2026-07-08',23000.00,83.50,'advance_tt','not_applicable',
     false,null,210000.00,false,'in_clearance',null,11,'customs_query','HS code query on lithium battery classification raised by customs'),
    ('SHP-FUJ-2609','Fujifilm Healthcare','japan','Endoscopy CCD modules','Apollo Chennai',
     '2026-06-22',89000.00,83.15,'letter_of_credit','lc_expired',
     true,82.90,null,false,'pending',null,26,'lc_action_needed','LC expired before shipment — amendment and validity extension needed'),
    ('SHP-GE-2610','GE Healthcare','usa','Infusion pump spares','Fortis Gurgaon',
     '2026-07-10',34000.00,83.45,'open_account','not_applicable',
     false,null,null,false,'pending',null,5,'on_track','Open-account low-value spares, awaiting shipment documents'),
    ('SHP-EDN-2611','Edan Instruments','china','ECG machine spares','KIMS Hyderabad',
     '2026-06-15',18000.00,83.70,'dp_da','not_applicable',
     false,null,165000.00,true,'demurrage_risk',null,33,'demurrage_risk','DA documents delayed at collecting bank — demurrage risk at port'),
    ('SHP-SHZ-2612','Shimadzu','japan','C-arm image intensifier','EquipSeva Chennai Warehouse',
     '2026-06-27',112000.00,83.05,'letter_of_credit','documents_negotiated',
     true,82.85,1310000.00,true,'cleared',10460000.00,24,'cleared_closed','LC negotiated and hedged, cleared customs, delivered to warehouse'),
    ('SHP-HOL-2613','Hologic','usa','Mammography detector board','Apollo Chennai',
     '2026-07-03',143000.00,83.55,'letter_of_credit','discrepancy',
     true,83.20,null,false,'detained_query',null,20,'customs_query','Customs valuation query plus LC B/L discrepancy — goods detained'),
    ('SHP-BD-2614','Becton Dickinson','singapore','Infusion consumable spares','CMC Vellore',
     '2026-06-12',27000.00,82.60,'advance_tt','not_applicable',
     false,null,240000.00,true,'cleared',2510000.00,15,'forex_loss_exposure','Unhedged advance TT paid at 84.30 vs booked 82.60 — forex loss booked')
  ) as q(ref, oem, orig, eqp, dest, sdate, invusd, bookrate, pmode, lcst, hedged, hrate, duty, bcdigst, cha, landed, dit, verdict, nt);

  -- CAPA seed — attach to at-risk shipments via shipment_ref
  insert into public.import_forex_lc_capa_actions_r3341 (
    shipment_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SHP-CAN-2603','lc_discrepancy','bank_document_mismatch','negotiate_documents','escalated','shipment_delay','2026-07-12',null,85000.00,'Bank refused negotiation on B/L date mismatch — escalated to LC issuing bank'),
    ('SHP-MIN-2604','cha_demurrage','cha_filing_delay','expedite_cha_filing','in_progress','demurrage_charge','2026-07-09',null,120000.00,'Container demurrage accruing at Chennai port — CHA expediting bill of entry'),
    ('SHP-MDT-2606','forex_unhedged_exposure','forex_rate_movement','book_forward_hedge','closed','forex_loss','2026-07-01','2026-06-30',195000.00,'Unhedged open-account paid at 84.10 — loss booked, forward-cover policy updated'),
    ('SHP-NK-2608','customs_duty_query','hs_code_misclassification','reclassify_hs_code','in_progress','duty_penalty','2026-07-14',null,46000.00,'Lithium battery HS code queried — reclassification filed with customs'),
    ('SHP-FUJ-2609','lc_expiry','delayed_lc_amendment','amend_lc_terms','open','shipment_delay','2026-07-13',null,60000.00,'LC expired pre-shipment — amendment for validity extension pending bank approval'),
    ('SHP-EDN-2611','cha_demurrage','port_congestion','pay_demurrage_release','overdue','demurrage_charge','2026-06-28',null,138000.00,'DA documents delayed at collecting bank — demurrage past target, release overdue'),
    ('SHP-HOL-2613','documentation_gap','supplier_documentation_error','negotiate_documents','verification_pending','duty_penalty','2026-07-11',null,72000.00,'Customs valuation query plus LC B/L discrepancy — corrected docs submitted for assessment')
  ) as q(ref, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.import_forex_lc_r3341 e
    on e.org_id = v_org_id and e.shipment_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Shipment verdict distribution
create or replace function public.founder_r3341_shipment_verdict_rollup()
returns table(shipment_verdict text, shipments bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.import_forex_lc_r3341)
  select l.shipment_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.import_forex_lc_r3341 l
  group by l.shipment_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3341_shipment_verdict_rollup() from public, anon;
grant execute on function public.founder_r3341_shipment_verdict_rollup() to authenticated;

-- 2) Supplier-level trade-finance scorecard
create or replace function public.founder_r3341_supplier_scorecard()
returns table(
  oem_supplier text,
  total_shipments bigint,
  cleared bigint,
  lc_action bigint,
  customs_query bigint,
  demurrage_risk bigint,
  forex_exposure bigint,
  cleared_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_supplier,
    count(*)::bigint,
    count(*) filter (where l.shipment_verdict = 'cleared_closed')::bigint,
    count(*) filter (where l.shipment_verdict = 'lc_action_needed')::bigint,
    count(*) filter (where l.shipment_verdict = 'customs_query')::bigint,
    count(*) filter (where l.shipment_verdict = 'demurrage_risk')::bigint,
    count(*) filter (where l.shipment_verdict = 'forex_loss_exposure')::bigint,
    round(100.0 * count(*) filter (where l.shipment_verdict = 'cleared_closed')::numeric / nullif(count(*),0), 1)
  from public.import_forex_lc_r3341 l
  group by l.oem_supplier
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3341_supplier_scorecard() from public, anon;
grant execute on function public.founder_r3341_supplier_scorecard() to authenticated;

-- 3) Origin-country × payment-mode matrix
create or replace function public.founder_r3341_origin_payment_matrix()
returns table(origin_country text, payment_mode text, shipments bigint, cleared bigint, avg_invoice_value_usd numeric, avg_landed_cost_inr numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.origin_country, l.payment_mode, count(*)::bigint,
    count(*) filter (where l.shipment_verdict = 'cleared_closed')::bigint,
    round(avg(l.invoice_value_usd), 0),
    round(avg(l.landed_cost_inr), 0)
  from public.import_forex_lc_r3341 l
  group by l.origin_country, l.payment_mode
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3341_origin_payment_matrix() from public, anon;
grant execute on function public.founder_r3341_origin_payment_matrix() to authenticated;

-- 4) Daily import / clearance trend
create or replace function public.founder_r3341_daily_clearance_trend()
returns table(shipment_date date, shipments bigint, cleared bigint, lc_action bigint, customs_query bigint, demurrage_risk bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.shipment_date,
    count(*)::bigint,
    count(*) filter (where l.shipment_verdict = 'cleared_closed')::bigint,
    count(*) filter (where l.shipment_verdict = 'lc_action_needed')::bigint,
    count(*) filter (where l.shipment_verdict = 'customs_query')::bigint,
    count(*) filter (where l.shipment_verdict = 'demurrage_risk')::bigint
  from public.import_forex_lc_r3341 l
  group by l.shipment_date
  order by l.shipment_date desc;
end;
$$;

revoke execute on function public.founder_r3341_daily_clearance_trend() from public, anon;
grant execute on function public.founder_r3341_daily_clearance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3341_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.import_forex_lc_capa_actions_r3341 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3341_capa_status_board() from public, anon;
grant execute on function public.founder_r3341_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3341_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.import_forex_lc_capa_actions_r3341)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.import_forex_lc_capa_actions_r3341 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3341_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3341_root_cause_pareto() to authenticated;

-- 7) Financial-impact / cost-risk digest
create or replace function public.founder_r3341_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.import_forex_lc_capa_actions_r3341 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3341_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3341_financial_impact_digest() to authenticated;

-- 8) High-risk shipment queue (top individual concerns)
create or replace function public.founder_r3341_high_risk_queue()
returns table(
  oem_supplier text,
  shipment_ref text,
  origin_country text,
  shipment_date date,
  shipment_verdict text,
  lc_status text,
  cha_clearance_status text,
  invoice_value_usd numeric,
  days_in_transit int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_supplier, l.shipment_ref, l.origin_country, l.shipment_date,
    l.shipment_verdict, l.lc_status, l.cha_clearance_status,
    l.invoice_value_usd, l.days_in_transit, l.notes
  from public.import_forex_lc_r3341 l
  where l.shipment_verdict in ('lc_action_needed','customs_query','demurrage_risk','forex_loss_exposure')
     or l.lc_status in ('lc_expired','discrepancy')
     or l.cha_clearance_status in ('detained_query','demurrage_risk')
  order by l.shipment_date desc, l.oem_supplier;
end;
$$;

revoke execute on function public.founder_r3341_high_risk_queue() from public, anon;
grant execute on function public.founder_r3341_high_risk_queue() to authenticated;
