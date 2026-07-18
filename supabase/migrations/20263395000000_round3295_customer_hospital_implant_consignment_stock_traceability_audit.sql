-- Round 3295: Customer Hospital High-Value Implant & Consignment-Stock Traceability & Par-Level Audit
-- Implant stock traceability — implant category × consignment owner × on-hand vs par × UDI barcode × expiry / short-dated × implant-log reconciliation × stock verdict × CAPA

-- =============================================================================
-- TABLE 1: implant_consignment_r3295 — per SKU-location consignment stock audits
-- =============================================================================
create table if not exists public.implant_consignment_r3295 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  store_location text not null,
  implant_category text not null check (implant_category in (
    'ortho_joint','cardiac_stent','pacemaker_icd','intraocular_lens','spinal_cage','vascular_graft'
  )),
  sku_code text not null,
  lot_batch text not null,
  audit_date date not null,
  on_hand_qty int not null,
  par_level int not null,
  consignment_owner text not null check (consignment_owner in (
    'oem_consignment','hospital_owned','distributor_managed'
  )),
  udi_barcode_present boolean not null,
  expiry_date date not null,
  days_to_expiry int not null,
  expired_or_shortdated_qty int not null,
  usage_last_90 int not null,
  implant_log_reconciled boolean not null,
  temperature_sensitive boolean not null,
  stock_verdict text not null check (stock_verdict in (
    'healthy','reorder_now','expiry_risk','expired_quarantine','reconciliation_gap','overstocked'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.implant_consignment_r3295 enable row level security;

create index if not exists idx_implant_consignment_r3295_org on public.implant_consignment_r3295(organization_id);
create index if not exists idx_implant_consignment_r3295_date on public.implant_consignment_r3295(audit_date);
create index if not exists idx_implant_consignment_r3295_verdict on public.implant_consignment_r3295(stock_verdict);

-- =============================================================================
-- TABLE 2: implant_consignment_capa_actions_r3295 — reconciliation / expiry / replenishment CAPA
-- =============================================================================
create table if not exists public.implant_consignment_capa_actions_r3295 (
  id uuid primary key default gen_random_uuid(),
  stock_log_id uuid not null references public.implant_consignment_r3295(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'expiry_shortdated','stock_below_par','stock_overstocked','reconciliation_discrepancy',
    'udi_barcode_missing','temperature_excursion','consignment_billing_mismatch','recall_notice'
  )),
  root_cause text not null check (root_cause in (
    'oem_replenishment_delay','usage_not_logged','expired_not_removed','par_level_miscalculated',
    'barcode_not_scanned','cold_chain_failure','distributor_stock_error','manual_count_error',
    'pending_investigation','recall_from_manufacturer'
  )),
  corrective_action text not null check (corrective_action in (
    'return_to_oem','quarantine_expired_stock','replenish_to_par','recount_and_reconcile',
    'rescan_udi_barcodes','adjust_par_level','escalate_to_distributor','update_consignment_agreement',
    'remove_recalled_lot','none_required'
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

alter table public.implant_consignment_capa_actions_r3295 enable row level security;

create index if not exists idx_implant_consignment_capa_r3295_log on public.implant_consignment_capa_actions_r3295(stock_log_id);
create index if not exists idx_implant_consignment_capa_r3295_status on public.implant_consignment_capa_actions_r3295(capa_status);

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

  -- 14 consignment stock audit rows
  insert into public.implant_consignment_r3295 (
    organization_id, hospital_name, store_location, implant_category, sku_code, lot_batch,
    audit_date, on_hand_qty, par_level, consignment_owner, udi_barcode_present,
    expiry_date, days_to_expiry, expired_or_shortdated_qty, usage_last_90,
    implant_log_reconciled, temperature_sensitive, stock_verdict, notes
  )
  select v_org_id, q.hosp, q.loc, q.cat, q.sku, q.lot,
    q.adt::date, q.onh, q.par, q.owner, q.udi,
    q.exp::date, q.dte, q.expq, q.use90,
    q.recon, q.tempsens, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','OT-Store-3','ortho_joint','ORTHO-KNEE-PS-9','LOT-AJ2451','2026-07-05',
     12,8,'oem_consignment',true,'2027-09-30',452,0,22,true,false,'healthy','Knee PS system above par, UDI scanned, OEM consignment'),
    ('Apollo Chennai Greams Road','Cathlab-Store','cardiac_stent','STENT-DES-275','LOT-CS7781','2026-07-05',
     3,10,'oem_consignment',true,'2027-03-15',253,0,41,true,false,'reorder_now','DES 2.75mm 3 of 10 below par — high PCI usage, reorder now'),
    ('Fortis Gurgaon','Cardiac-Store','pacemaker_icd','PACE-DDDR-45','LOT-PM3390','2026-07-04',
     4,3,'distributor_managed',true,'2026-08-20',47,1,6,true,false,'expiry_risk','One DDDR pacer 47 days to expiry — short-dated, arrange swap'),
    ('Fortis Gurgaon','Eye-OT','intraocular_lens','IOL-ASPH-22D','LOT-IOL5502','2026-07-04',
     40,25,'hospital_owned',true,'2028-01-31',577,0,88,true,false,'overstocked','Aspheric IOL 40 vs par 25 — overstocked on slow-moving power'),
    ('Manipal Bengaluru Old Airport Rd','Spine-Store','spinal_cage','SPINE-TLIF-12','LOT-SC1180','2026-07-03',
     6,6,'oem_consignment',false,'2027-06-30',361,0,14,false,false,'reconciliation_gap','TLIF cage physical 6 vs implant log 8 — UDI not scanned, unreconciled'),
    ('Manipal Bengaluru Old Airport Rd','Vascular-Store','vascular_graft','VGRAFT-PTFE-8','LOT-VG2205','2026-07-03',
     5,4,'distributor_managed',true,'2027-11-15',499,0,9,true,false,'healthy','PTFE graft at par, log reconciled, healthy'),
    ('AIIMS Delhi Ansari Nagar','OT-Central-Store','ortho_joint','ORTHO-HIP-UNCEM','LOT-AJ9902','2026-07-02',
     2,6,'oem_consignment',true,'2027-02-28',241,0,19,true,false,'reorder_now','Uncemented hip cups 2 of 6 below par — reorder now'),
    ('AIIMS Delhi Ansari Nagar','Cathlab-Store-2','cardiac_stent','STENT-BVS-30','LOT-CS4410','2026-07-02',
     8,6,'oem_consignment',true,'2026-06-27',-5,3,12,true,false,'expired_quarantine','BVS 3.0mm — 3 units expired 5 days ago, quarantine and return'),
    ('CMC Vellore','Ortho-Store','spinal_cage','SPINE-PLIF-10','LOT-SC8830','2026-07-01',
     9,5,'hospital_owned',true,'2027-08-31',426,0,7,true,false,'overstocked','PLIF cage 9 vs par 5 — overstock after case cancellations'),
    ('CMC Vellore','Eye-Store','intraocular_lens','IOL-TORIC-T3','LOT-IOL6621','2026-07-01',
     6,8,'distributor_managed',true,'2026-09-05',66,2,15,true,false,'expiry_risk','Toric IOL 66 days short-dated and below par — rotate stock'),
    ('KIMS Hyderabad','Cardiac-Store','pacemaker_icd','ICD-VR-77','LOT-PM7120','2026-06-30',
     3,3,'oem_consignment',true,'2027-12-31',549,0,4,true,false,'healthy','Single-chamber ICD at par, reconciled, healthy'),
    ('KIMS Hyderabad','OT-Store-1','ortho_joint','ORTHO-SHLDR-RT','LOT-AJ3345','2026-06-30',
     4,4,'oem_consignment',false,'2027-05-20',324,0,11,false,false,'reconciliation_gap','Reverse shoulder — implant log mismatch, 4 physical vs 5 billed'),
    ('Narayana Health Bengaluru','Vascular-Store','vascular_graft','VGRAFT-DACRON-6','LOT-VG9908','2026-06-29',
     1,5,'distributor_managed',true,'2027-10-10',468,0,8,true,false,'reorder_now','Dacron graft critically low 1 of 5 — reorder before AAA cases'),
    ('Kokilaben Mumbai','Cathlab-Cold-Store','cardiac_stent','STENT-DEB-25','LOT-CS5567','2026-06-29',
     7,6,'oem_consignment',true,'2027-04-18',293,0,33,true,true,'healthy','Drug-eluting balloon temp-sensitive, cold chain logged ok, healthy')
  ) as q(hosp, loc, cat, sku, lot, adt, onh, par, owner, udi, exp, dte, expq, use90, recon, tempsens, verdict, nt);

  -- CAPA seed — attach to specific stock rows via sku_code
  insert into public.implant_consignment_capa_actions_r3295 (
    stock_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('STENT-DES-275','stock_below_par','oem_replenishment_delay','replenish_to_par','in_progress','patient_safety_alert','2026-07-12',null,0.00,'DES 2.75 critical for PCI — expedite OEM consignment replenishment'),
    ('PACE-DDDR-45','expiry_shortdated','expired_not_removed','return_to_oem','open','cdsco_notifiable','2026-07-15',null,0.00,'Short-dated DDDR pacer — arrange OEM swap for fresh-dated unit'),
    ('STENT-BVS-30','expiry_shortdated','expired_not_removed','quarantine_expired_stock','escalated','patient_safety_alert','2026-07-05','2026-07-03',5000.00,'3 BVS units expired — quarantined and returned, FEFO not followed'),
    ('SPINE-TLIF-12','reconciliation_discrepancy','usage_not_logged','recount_and_reconcile','open','nabh_finding','2026-07-14',null,0.00,'TLIF cage physical vs log gap — recount and reconcile implant log'),
    ('ORTHO-SHLDR-RT','consignment_billing_mismatch','distributor_stock_error','escalate_to_distributor','in_progress','iso_13485_deviation','2026-07-16',null,3000.00,'Reverse shoulder billed 5 vs 4 physical — escalate to distributor for credit'),
    ('VGRAFT-DACRON-6','stock_below_par','oem_replenishment_delay','replenish_to_par','open','internal_only','2026-07-10',null,0.00,'Dacron graft 1 of 5 — replenish before scheduled AAA cases'),
    ('SPINE-PLIF-10','stock_overstocked','par_level_miscalculated','adjust_par_level','verification_pending','internal_only','2026-07-20',null,0.00,'PLIF cage overstock — recalculate par level from 90-day usage')
  ) as q(sku, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.implant_consignment_r3295 e
    on e.organization_id = v_org_id and e.sku_code = q.sku;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Stock verdict distribution
create or replace function public.founder_r3295_stock_verdict_rollup()
returns table(stock_verdict text, skus bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.implant_consignment_r3295)
  select l.stock_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.implant_consignment_r3295 l
  group by l.stock_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3295_stock_verdict_rollup() from public, anon;
grant execute on function public.founder_r3295_stock_verdict_rollup() to authenticated;

-- 2) Hospital-level stock scorecard
create or replace function public.founder_r3295_hospital_scorecard()
returns table(
  hospital_name text,
  total_skus bigint,
  healthy bigint,
  reorder_now bigint,
  expiry_or_expired bigint,
  reconciliation_gap bigint,
  below_par bigint,
  unreconciled bigint,
  healthy_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.stock_verdict = 'healthy')::bigint,
    count(*) filter (where l.stock_verdict = 'reorder_now')::bigint,
    count(*) filter (where l.stock_verdict in ('expiry_risk','expired_quarantine'))::bigint,
    count(*) filter (where l.stock_verdict = 'reconciliation_gap')::bigint,
    count(*) filter (where l.on_hand_qty < l.par_level)::bigint,
    count(*) filter (where l.implant_log_reconciled = false)::bigint,
    round(100.0 * count(*) filter (where l.stock_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.implant_consignment_r3295 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3295_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3295_hospital_scorecard() to authenticated;

-- 3) Implant category × consignment owner matrix
create or replace function public.founder_r3295_category_owner_matrix()
returns table(implant_category text, consignment_owner text, skus bigint, healthy bigint, avg_days_to_expiry numeric, total_expired_qty bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.implant_category, l.consignment_owner, count(*)::bigint,
    count(*) filter (where l.stock_verdict = 'healthy')::bigint,
    round(avg(l.days_to_expiry), 0),
    coalesce(sum(l.expired_or_shortdated_qty),0)::bigint
  from public.implant_consignment_r3295 l
  group by l.implant_category, l.consignment_owner
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3295_category_owner_matrix() from public, anon;
grant execute on function public.founder_r3295_category_owner_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3295_daily_audit_trend()
returns table(audit_date date, skus bigint, healthy bigint, reorder_now bigint, expiry_risk bigint, reconciliation_gap bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.stock_verdict = 'healthy')::bigint,
    count(*) filter (where l.stock_verdict = 'reorder_now')::bigint,
    count(*) filter (where l.stock_verdict in ('expiry_risk','expired_quarantine'))::bigint,
    count(*) filter (where l.stock_verdict = 'reconciliation_gap')::bigint
  from public.implant_consignment_r3295 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3295_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3295_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3295_capa_status_board()
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
  from public.implant_consignment_capa_actions_r3295 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3295_capa_status_board() from public, anon;
grant execute on function public.founder_r3295_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3295_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.implant_consignment_capa_actions_r3295)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.implant_consignment_capa_actions_r3295 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3295_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3295_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3295_regulatory_impact_digest()
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
  from public.implant_consignment_capa_actions_r3295 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3295_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3295_regulatory_impact_digest() to authenticated;

-- 8) High-risk stock queue (top individual concerns)
create or replace function public.founder_r3295_high_risk_queue()
returns table(
  hospital_name text,
  store_location text,
  sku_code text,
  implant_category text,
  consignment_owner text,
  on_hand_qty int,
  par_level int,
  days_to_expiry int,
  stock_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.store_location, l.sku_code, l.implant_category,
    l.consignment_owner, l.on_hand_qty, l.par_level, l.days_to_expiry,
    l.stock_verdict, l.notes
  from public.implant_consignment_r3295 l
  where l.stock_verdict in ('reorder_now','expiry_risk','expired_quarantine','reconciliation_gap','overstocked')
     or l.on_hand_qty < l.par_level
     or l.days_to_expiry <= 90
     or l.expired_or_shortdated_qty > 0
     or l.implant_log_reconciled = false
     or l.udi_barcode_present = false
  order by l.days_to_expiry asc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3295_high_risk_queue() from public, anon;
grant execute on function public.founder_r3295_high_risk_queue() to authenticated;
