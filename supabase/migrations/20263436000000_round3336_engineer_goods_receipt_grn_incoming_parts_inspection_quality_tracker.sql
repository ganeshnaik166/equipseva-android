-- Round 3336: Engineer Goods-Receipt (GRN) & Incoming-Parts Inspection Quality Tracker
-- Inbound supply-chain QA — equipment family × vendor × PO-match × physical-damage × documentation × genuineness × lot-expiry × put-away × discrepancy × GRN verdict × CAPA

-- =============================================================================
-- TABLE 1: goods_receipt_grn_r3336 — per-GRN incoming inspection records
-- =============================================================================
create table if not exists public.goods_receipt_grn_r3336 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  store_location text not null,
  grn_code text not null,
  oem_or_vendor text not null,
  po_ref text not null,
  equipment_family text not null check (equipment_family in (
    'patient_monitor','imaging','dialysis','infusion_pump','ventilator','lab_analyzer','general'
  )),
  receipt_date date not null,
  items_expected int not null,
  items_received int not null,
  quantity_match boolean not null,
  physical_damage text not null check (physical_damage in (
    'none','minor','major','rejected'
  )),
  documentation_complete boolean not null,
  genuineness_verified boolean not null,
  lot_expiry_captured boolean not null,
  put_away_time_hours numeric(6,2),
  discrepancy_type text not null check (discrepancy_type in (
    'no_discrepancy','short_supply','excess','wrong_part','damaged','doc_missing','counterfeit_suspected'
  )),
  grn_verdict text not null check (grn_verdict in (
    'accepted','accepted_with_deviation','partial_hold','rejected_returned','quarantine_investigation'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.goods_receipt_grn_r3336 enable row level security;

create index if not exists idx_goods_receipt_grn_r3336_org on public.goods_receipt_grn_r3336(organization_id);
create index if not exists idx_goods_receipt_grn_r3336_date on public.goods_receipt_grn_r3336(receipt_date);
create index if not exists idx_goods_receipt_grn_r3336_verdict on public.goods_receipt_grn_r3336(grn_verdict);

-- =============================================================================
-- TABLE 2: goods_receipt_grn_capa_actions_r3336 — CAPA / vendor-followup actions
-- =============================================================================
create table if not exists public.goods_receipt_grn_capa_actions_r3336 (
  id uuid primary key default gen_random_uuid(),
  grn_log_id uuid not null references public.goods_receipt_grn_r3336(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'quantity_short_supply','excess_supply','wrong_part_received','physical_damage','documentation_missing',
    'counterfeit_suspected','expiry_not_captured','put_away_delay','vendor_quality_issue'
  )),
  root_cause text not null check (root_cause in (
    'vendor_packing_error','courier_transit_damage','po_mismatch','vendor_substituted_part','missing_coa',
    'grey_market_supply','vendor_documentation_gap','store_process_gap','pending_investigation','vendor_capacity_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_debit_note','return_to_vendor','request_replacement_shipment','quarantine_and_investigate',
    'obtain_missing_documents','escalate_to_oem','blacklist_vendor_batch','retrain_store_staff','accept_with_deviation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.goods_receipt_grn_capa_actions_r3336 enable row level security;

create index if not exists idx_goods_receipt_grn_capa_r3336_log on public.goods_receipt_grn_capa_actions_r3336(grn_log_id);
create index if not exists idx_goods_receipt_grn_capa_r3336_status on public.goods_receipt_grn_capa_actions_r3336(capa_status);

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

  -- 14 GRN inspection rows
  insert into public.goods_receipt_grn_r3336 (
    organization_id, store_location, grn_code, oem_or_vendor, po_ref, equipment_family,
    receipt_date, items_expected, items_received, quantity_match, physical_damage,
    documentation_complete, genuineness_verified, lot_expiry_captured, put_away_time_hours,
    discrepancy_type, grn_verdict, notes
  )
  select v_org_id, q.sloc, q.grn, q.vend, q.po, q.fam,
    q.rdate::date, q.iexp::int, q.irec::int, q.qmatch, q.pdmg,
    q.doccomp, q.genv, q.lotexp, q.putaway::numeric,
    q.disc, q.verdict, q.nt
  from (values
    ('Chennai Central Store','GRN-CHN-5001','GE Healthcare','PO-EQS-4471','patient_monitor',
     '2026-07-10',12,12,true,'none',true,true,true,3.5,'no_discrepancy','accepted','Full PO received; COA and warranty cards attached'),
    ('Chennai Central Store','GRN-CHN-5002','Nihon Kohden','PO-EQS-4472','patient_monitor',
     '2026-07-10',8,6,false,'none',true,true,true,6.0,'short_supply','partial_hold','Short 2 SpO2 modules vs PO — debit note raised on Nihon Kohden'),
    ('Gurgaon North Hub','GRN-GGN-6001','Philips','PO-EQS-4480','imaging',
     '2026-07-09',4,4,true,'minor',true,true,true,8.5,'damaged','accepted_with_deviation','Minor crate dent on 1 ultrasound probe — cosmetic, accepted with deviation'),
    ('Gurgaon North Hub','GRN-GGN-6002','Siemens Healthineers','PO-EQS-4481','imaging',
     '2026-07-09',6,6,true,'major',true,true,false,10.0,'damaged','quarantine_investigation','CT tube shock-watch tripped in transit — quarantined pending investigation'),
    ('Bengaluru South Store','GRN-BLR-7001','Fresenius Medical Care','PO-EQS-4490','dialysis',
     '2026-07-08',20,20,true,'none',false,true,false,4.0,'doc_missing','partial_hold','Dialyzer lot COA missing — hold pending Fresenius QA documents'),
    ('Bengaluru South Store','GRN-BLR-7002','Mindray','PO-EQS-4491','infusion_pump',
     '2026-07-08',10,10,true,'none',true,true,true,2.5,'no_discrepancy','accepted','Infusion pump spares clean receipt; genuineness verified'),
    ('Delhi Central Store','GRN-DEL-8001','Draeger','PO-EQS-4500','ventilator',
     '2026-07-07',5,5,true,'none',true,false,true,5.5,'counterfeit_suspected','quarantine_investigation','Ventilator flow-sensor holograms fail anti-counterfeit check — grey-market suspected'),
    ('Delhi Central Store','GRN-DEL-8002','Skanray Technologies','PO-EQS-4501','ventilator',
     '2026-07-07',7,7,true,'none',true,true,true,3.0,'no_discrepancy','accepted','Skanray ventilator spares verified genuine; docs complete'),
    ('Vellore Regional Store','GRN-VLR-9001','Erba Mannheim','PO-EQS-4510','lab_analyzer',
     '2026-07-06',15,18,false,'none',true,true,true,4.5,'excess','accepted_with_deviation','Vendor shipped 3 excess reagent kits — retained, PO amended'),
    ('Hyderabad Store','GRN-HYD-1001','BPL Medical Technologies','PO-EQS-4520','patient_monitor',
     '2026-07-05',9,9,true,'none',false,true,false,7.0,'doc_missing','partial_hold','Warranty cards missing for BPL monitors — vendor follow-up raised'),
    ('Hyderabad Store','GRN-HYD-1002','Trivitron Healthcare','PO-EQS-4521','lab_analyzer',
     '2026-07-05',6,4,false,'none',true,true,true,5.0,'wrong_part','rejected_returned','Wrong analyzer PCB variant shipped — returned to Trivitron for correct part'),
    ('Chennai Central Store','GRN-CHN-5003','GE Healthcare','PO-EQS-4530','imaging',
     '2026-07-04',3,3,true,'rejected',true,true,true,12.0,'damaged','rejected_returned','MRI gradient-coil crate crushed in transit — rejected, insurance claim filed'),
    ('Gurgaon North Hub','GRN-GGN-6003','Fresenius Medical Care','PO-EQS-4531','dialysis',
     '2026-07-04',25,25,true,'none',true,true,false,4.0,'no_discrepancy','accepted_with_deviation','Lot expiry not captured at receipt — corrected in WMS, deviation logged'),
    ('Bengaluru South Store','GRN-BLR-7003','Nihon Kohden','PO-EQS-4540','general',
     '2026-07-03',30,30,true,'none',true,true,true,2.0,'no_discrepancy','accepted','General consumables clean receipt; put-away same shift')
  ) as q(sloc, grn, vend, po, fam, rdate, iexp, irec, qmatch, pdmg, doccomp, genv, lotexp, putaway, disc, verdict, nt);

  -- CAPA seed — attach to specific GRNs via grn_code
  insert into public.goods_receipt_grn_capa_actions_r3336 (
    grn_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('GRN-CHN-5002','quantity_short_supply','vendor_packing_error','raise_debit_note','in_progress','internal_only','2026-07-15',null,22000.00,'Debit note raised for 2 missing SpO2 modules; awaiting vendor credit'),
    ('GRN-GGN-6002','physical_damage','courier_transit_damage','request_replacement_shipment','escalated','patient_safety_alert','2026-07-14',null,480000.00,'Shock-watch tripped — replacement CT tube demanded from Siemens, patient-safety hold'),
    ('GRN-BLR-7001','documentation_missing','missing_coa','obtain_missing_documents','open','iso_13485_deviation','2026-07-16',null,0.00,'Awaiting dialyzer lot COA from Fresenius QA before stock release'),
    ('GRN-DEL-8001','counterfeit_suspected','grey_market_supply','quarantine_and_investigate','escalated','cdsco_notifiable','2026-07-13',null,95000.00,'Anti-counterfeit hologram failure — CDSCO notification prepared, vendor batch frozen'),
    ('GRN-HYD-1002','wrong_part_received','vendor_substituted_part','return_to_vendor','closed','internal_only','2026-07-12','2026-07-09',15000.00,'Wrong PCB variant returned to Trivitron; correct part reshipped and received'),
    ('GRN-CHN-5003','physical_damage','courier_transit_damage','return_to_vendor','in_progress','nabh_finding','2026-07-18',null,1250000.00,'Crushed MRI gradient coil rejected — insurance claim plus GE replacement in progress'),
    ('GRN-HYD-1001','documentation_missing','vendor_documentation_gap','obtain_missing_documents','overdue','internal_only','2026-07-10',null,3000.00,'BPL warranty cards overdue from vendor — second reminder sent')
  ) as q(grn, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.goods_receipt_grn_r3336 e
    on e.organization_id = v_org_id and e.grn_code = q.grn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) GRN verdict distribution
create or replace function public.founder_r3336_grn_verdict_rollup()
returns table(grn_verdict text, receipts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.goods_receipt_grn_r3336)
  select l.grn_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.goods_receipt_grn_r3336 l
  group by l.grn_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3336_grn_verdict_rollup() from public, anon;
grant execute on function public.founder_r3336_grn_verdict_rollup() to authenticated;

-- 2) Store-level GRN scorecard
create or replace function public.founder_r3336_store_scorecard()
returns table(
  store_location text,
  total_receipts bigint,
  accepted bigint,
  with_deviation bigint,
  held_or_rejected bigint,
  major_damage bigint,
  doc_incomplete bigint,
  counterfeit_flag bigint,
  accept_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_location,
    count(*)::bigint,
    count(*) filter (where l.grn_verdict = 'accepted')::bigint,
    count(*) filter (where l.grn_verdict = 'accepted_with_deviation')::bigint,
    count(*) filter (where l.grn_verdict in ('partial_hold','rejected_returned','quarantine_investigation'))::bigint,
    count(*) filter (where l.physical_damage in ('major','rejected'))::bigint,
    count(*) filter (where l.documentation_complete = false)::bigint,
    count(*) filter (where l.discrepancy_type = 'counterfeit_suspected' or l.genuineness_verified = false)::bigint,
    round(100.0 * count(*) filter (where l.grn_verdict = 'accepted')::numeric / nullif(count(*),0), 1)
  from public.goods_receipt_grn_r3336 l
  group by l.store_location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3336_store_scorecard() from public, anon;
grant execute on function public.founder_r3336_store_scorecard() to authenticated;

-- 3) Equipment-family × vendor matrix
create or replace function public.founder_r3336_family_vendor_matrix()
returns table(equipment_family text, oem_or_vendor text, receipts bigint, accepted bigint, avg_put_away_hours numeric, discrepancy_receipts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_family, l.oem_or_vendor, count(*)::bigint,
    count(*) filter (where l.grn_verdict = 'accepted')::bigint,
    round(avg(l.put_away_time_hours), 1),
    count(*) filter (where l.discrepancy_type <> 'no_discrepancy')::bigint
  from public.goods_receipt_grn_r3336 l
  group by l.equipment_family, l.oem_or_vendor
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3336_family_vendor_matrix() from public, anon;
grant execute on function public.founder_r3336_family_vendor_matrix() to authenticated;

-- 4) Daily receipt trend
create or replace function public.founder_r3336_daily_receipt_trend()
returns table(receipt_date date, receipts bigint, accepted bigint, rejected bigint, damage_flag bigint, counterfeit_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.receipt_date,
    count(*)::bigint,
    count(*) filter (where l.grn_verdict = 'accepted')::bigint,
    count(*) filter (where l.grn_verdict in ('rejected_returned','quarantine_investigation'))::bigint,
    count(*) filter (where l.physical_damage in ('major','rejected'))::bigint,
    count(*) filter (where l.discrepancy_type = 'counterfeit_suspected' or l.genuineness_verified = false)::bigint
  from public.goods_receipt_grn_r3336 l
  group by l.receipt_date
  order by l.receipt_date desc;
end;
$$;

revoke execute on function public.founder_r3336_daily_receipt_trend() from public, anon;
grant execute on function public.founder_r3336_daily_receipt_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3336_capa_status_board()
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
  from public.goods_receipt_grn_capa_actions_r3336 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3336_capa_status_board() from public, anon;
grant execute on function public.founder_r3336_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3336_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.goods_receipt_grn_capa_actions_r3336)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.goods_receipt_grn_capa_actions_r3336 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3336_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3336_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3336_regulatory_impact_digest()
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
  from public.goods_receipt_grn_capa_actions_r3336 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3336_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3336_regulatory_impact_digest() to authenticated;

-- 8) High-risk GRN queue (top individual concerns)
create or replace function public.founder_r3336_high_risk_queue()
returns table(
  store_location text,
  grn_code text,
  oem_or_vendor text,
  receipt_date date,
  grn_verdict text,
  physical_damage text,
  discrepancy_type text,
  documentation_complete boolean,
  genuineness_verified boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_location, l.grn_code, l.oem_or_vendor, l.receipt_date,
    l.grn_verdict, l.physical_damage, l.discrepancy_type,
    l.documentation_complete, l.genuineness_verified, l.notes
  from public.goods_receipt_grn_r3336 l
  where l.grn_verdict in ('accepted_with_deviation','partial_hold','rejected_returned','quarantine_investigation')
     or l.physical_damage in ('major','rejected')
     or l.discrepancy_type <> 'no_discrepancy'
     or l.documentation_complete = false
     or l.genuineness_verified = false
     or l.quantity_match = false
  order by l.receipt_date desc, l.store_location;
end;
$$;

revoke execute on function public.founder_r3336_high_risk_queue() from public, anon;
grant execute on function public.founder_r3336_high_risk_queue() to authenticated;
