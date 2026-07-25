-- Round 3440: Engineer Consignment-Stock / Vendor-Managed-Inventory (VMI) Reconciliation Tracker
-- Field spare-parts consignment / VMI stock reconciliation — location × part × supplier × stock type ×
-- system vs physical qty × variance qty/value × recon status × aging × discrepancy flag × CAPA

-- =============================================================================
-- TABLE 1: consignment_vmi_recon_r3440 — per-part consignment/VMI stock reconciliation
-- =============================================================================
create table if not exists public.consignment_vmi_recon_r3440 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recon_ref text not null,
  engineer_name text not null,
  location_name text not null,
  part_name text not null,
  part_code text not null,
  supplier_name text not null,
  stock_type text not null check (stock_type in (
    'consignment','vmi','owned_buffer'
  )),
  system_qty int not null,
  physical_qty int not null,
  variance_qty int not null,
  variance_value_rupees numeric(14,2),
  recon_status text not null check (recon_status in (
    'matched','short','excess','under_investigation','adjusted'
  )),
  last_count_date date not null,
  aging_days int,
  discrepancy_flag boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.consignment_vmi_recon_r3440 enable row level security;

create index if not exists idx_consignment_vmi_recon_r3440_org on public.consignment_vmi_recon_r3440(organization_id);
create index if not exists idx_consignment_vmi_recon_r3440_date on public.consignment_vmi_recon_r3440(last_count_date);
create index if not exists idx_consignment_vmi_recon_r3440_status on public.consignment_vmi_recon_r3440(recon_status);

-- =============================================================================
-- TABLE 2: consignment_vmi_recon_capa_actions_r3440 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.consignment_vmi_recon_capa_actions_r3440 (
  id uuid primary key default gen_random_uuid(),
  recon_log_id uuid not null references public.consignment_vmi_recon_r3440(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stock_short','stock_excess','value_variance','aging_stock','consignment_unbilled',
    'vmi_replenishment_gap','miscount','system_not_updated','damaged_expired_stock','pending_investigation'
  )),
  root_cause text not null check (root_cause in (
    'goods_receipt_not_posted','issue_not_recorded','supplier_delivery_short','pilferage_suspected',
    'wrong_bin_location','barcode_scan_error','return_not_processed','expiry_writeoff_pending',
    'system_sync_failure','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'post_goods_receipt','record_stock_issue','raise_supplier_debit_note','physical_recount',
    'relocate_to_correct_bin','adjust_system_qty','process_return','writeoff_expired_stock',
    'reconcile_consignment_billing','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  variance_impact text not null check (variance_impact in (
    'financial_leakage','supplier_recoverable','audit_finding','none','internal_only','write_off'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.consignment_vmi_recon_capa_actions_r3440 enable row level security;

create index if not exists idx_consignment_vmi_capa_r3440_log on public.consignment_vmi_recon_capa_actions_r3440(recon_log_id);
create index if not exists idx_consignment_vmi_capa_r3440_status on public.consignment_vmi_recon_capa_actions_r3440(capa_status);

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

  -- 16 reconciliation rows
  insert into public.consignment_vmi_recon_r3440 (
    organization_id, recon_ref, engineer_name, location_name, part_name, part_code,
    supplier_name, stock_type, system_qty, physical_qty, variance_qty, variance_value_rupees,
    recon_status, last_count_date, aging_days, discrepancy_flag, notes
  )
  select v_org_id, q.rf, q.eng, q.loc, q.pname, q.pcode,
    q.sup, q.stype, q.sysq, q.phyq, q.varq, q.varv,
    q.rst, q.lcd::date, q.agd, q.disc, q.nt
  from (values
    ('RCN-0001','Rajesh Kumar','Apollo Chennai Store','Ventilator Flow Sensor','VFS-1001','Draeger India',
     'vmi',40,40,0,0.00,'matched','2026-07-10',5,false,'VMI flow sensors match system count'),
    ('RCN-0002','Priya Nair','Fortis Gurgaon Depot','Patient Monitor SpO2 Board','SPO2-2200','Philips India',
     'consignment',12,9,-3,54000.00,'short','2026-07-09',22,true,'Consignment SpO2 boards short by 3 — issues not posted'),
    ('RCN-0003','Amit Sharma','Manipal Bengaluru Store','Infusion Pump Battery','IPB-3050','BPL Medical',
     'owned_buffer',60,66,6,9000.00,'excess','2026-07-08',8,true,'Buffer batteries excess — returns not processed in system'),
    ('RCN-0004','Sunil Reddy','AIIMS Delhi Biomed','CT Detector Board','CTD-4400','GE Healthcare India',
     'consignment',3,2,-1,480000.00,'under_investigation','2026-06-28',62,true,'High-value CT detector board missing — pilferage suspected'),
    ('RCN-0005','Vikram Singh','CMC Vellore Store','ECG Cable Set','ECG-5010','Nihon Kohden India',
     'vmi',80,80,0,0.00,'matched','2026-07-11',3,false,'VMI ECG cables reconciled clean'),
    ('RCN-0006','Deepa Menon','KIMS Hyderabad Depot','Ultrasound TEE Probe','TEE-6600','Philips India',
     'consignment',4,3,-1,320000.00,'short','2026-06-20',70,true,'TEE probe short and aging 70 days — supplier debit note pending'),
    ('RCN-0007','Arun Patel','Yashoda Hyderabad Store','Defibrillator Battery Pack','DFB-7020','BPL Medical',
     'owned_buffer',25,24,-1,7000.00,'adjusted','2026-07-07',15,false,'One defib battery written off after recount — system adjusted'),
    ('RCN-0008','Kavya Iyer','Kokilaben Mumbai Store','Anesthesia Vaporizer','VAP-8800','Draeger India',
     'consignment',6,6,0,0.00,'matched','2026-07-10',6,false,'Consignment vaporizers match'),
    ('RCN-0009','Rajesh Kumar','Apollo Chennai Store','X-ray Tube Insert','XTI-1100','Siemens Healthineers',
     'consignment',5,4,-1,650000.00,'under_investigation','2026-06-25',65,true,'X-ray tube insert unaccounted — high value under investigation'),
    ('RCN-0010','Priya Nair','Fortis Gurgaon Depot','Dialysis Dialyzer','DLZ-2300','Trivitron Healthcare',
     'vmi',200,210,10,25000.00,'excess','2026-07-09',12,true,'VMI dialyzers excess — replenishment double-counted'),
    ('RCN-0011','Amit Sharma','Manipal Bengaluru Store','C-Arm Image Intensifier','CII-3900','Siemens Healthineers',
     'consignment',2,2,0,0.00,'matched','2026-07-08',9,false,'C-arm image intensifier consignment matched'),
    ('RCN-0012','Sunil Reddy','AIIMS Delhi Biomed','Endoscope Light Guide','ELG-4700','Trivitron Healthcare',
     'owned_buffer',15,12,-3,45000.00,'short','2026-06-30',55,true,'Endoscope light guides short — damaged units not recorded'),
    ('RCN-0013','Vikram Singh','CMC Vellore Store','Autoclave Door Gasket','ADG-5500','BPL Medical',
     'vmi',50,50,0,0.00,'matched','2026-07-11',4,false,'VMI gaskets match system'),
    ('RCN-0014','Deepa Menon','KIMS Hyderabad Depot','MRI Gradient Coil Fuse','MGC-6100','GE Healthcare India',
     'consignment',8,7,-1,180000.00,'under_investigation','2026-06-22',68,true,'MRI gradient coil fuse short — GRN not posted, aging'),
    ('RCN-0015','Arun Patel','Yashoda Hyderabad Store','OT Light LED Module','OTL-7700','Trivitron Healthcare',
     'owned_buffer',30,31,1,3500.00,'excess','2026-07-06',18,true,'OT light LED module excess — return posted twice'),
    ('RCN-0016','Kavya Iyer','Kokilaben Mumbai Store','Centrifuge Rotor','CFR-8100','Mindray India',
     'vmi',18,18,0,0.00,'matched','2026-07-10',7,false,'Centrifuge rotors VMI reconciled')
  ) as q(rf, eng, loc, pname, pcode, sup, stype, sysq, phyq, varq, varv, rst, lcd, agd, disc, nt);

  -- CAPA seed — attach to specific reconciliations via recon_ref
  insert into public.consignment_vmi_recon_capa_actions_r3440 (
    recon_log_id, finding_category, root_cause, corrective_action,
    capa_status, variance_impact, owner, target_closure_date, actual_closure_date,
    estimated_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.vi, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RCN-0002','stock_short','issue_not_recorded','record_stock_issue','in_progress','internal_only','Priya Nair','2026-07-16',null,54000.00,'Reconstruct issue records for 3 SpO2 boards'),
    ('RCN-0004','stock_short','pilferage_suspected','physical_recount','escalated','financial_leakage','Sunil Reddy','2026-07-14',null,480000.00,'High-value CT board — escalated to security and finance'),
    ('RCN-0003','stock_excess','return_not_processed','process_return','open','internal_only','Amit Sharma','2026-07-18',null,9000.00,'Post pending battery returns in system'),
    ('RCN-0006','consignment_unbilled','supplier_delivery_short','raise_supplier_debit_note','verification_pending','supplier_recoverable','Deepa Menon','2026-07-12',null,320000.00,'Debit note raised to Philips for short TEE probe'),
    ('RCN-0009','value_variance','pilferage_suspected','physical_recount','escalated','financial_leakage','Rajesh Kumar','2026-07-13',null,650000.00,'Full audit of X-ray tube inserts — CCTV review underway'),
    ('RCN-0010','vmi_replenishment_gap','system_sync_failure','adjust_system_qty','closed','write_off','Priya Nair','2026-07-16','2026-07-14',25000.00,'System qty corrected after VMI double-count'),
    ('RCN-0012','damaged_expired_stock','expiry_writeoff_pending','writeoff_expired_stock','open','write_off','Sunil Reddy','2026-07-17',null,45000.00,'Write off damaged light guides after approval'),
    ('RCN-0014','aging_stock','goods_receipt_not_posted','post_goods_receipt','overdue','audit_finding','Deepa Menon','2026-07-05',null,180000.00,'GRN posting overdue — aging 68 days, audit flag'),
    ('RCN-0015','stock_excess','return_not_processed','process_return','closed','internal_only','Arun Patel','2026-07-10','2026-07-12',3500.00,'Duplicate return reversed in system')
  ) as q(rf, fc, rc, ca, cst, vi, own, tcd, acd, cost, nt)
  join public.consignment_vmi_recon_r3440 e
    on e.organization_id = v_org_id and e.recon_ref = q.rf;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reconciliation status distribution
create or replace function public.founder_r3440_recon_status_rollup()
returns table(recon_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.consignment_vmi_recon_r3440)
  select l.recon_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.consignment_vmi_recon_r3440 l
  group by l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3440_recon_status_rollup() from public, anon;
grant execute on function public.founder_r3440_recon_status_rollup() to authenticated;

-- 2) Supplier-level reconciliation scorecard
create or replace function public.founder_r3440_supplier_scorecard()
returns table(
  supplier_name text,
  total_records bigint,
  matched bigint,
  short bigint,
  excess bigint,
  under_investigation bigint,
  discrepancy_records bigint,
  total_variance_value_rupees numeric,
  match_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name,
    count(*)::bigint,
    count(*) filter (where l.recon_status = 'matched')::bigint,
    count(*) filter (where l.recon_status = 'short')::bigint,
    count(*) filter (where l.recon_status = 'excess')::bigint,
    count(*) filter (where l.recon_status = 'under_investigation')::bigint,
    count(*) filter (where l.discrepancy_flag = true)::bigint,
    coalesce(sum(l.variance_value_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.recon_status = 'matched')::numeric / nullif(count(*),0), 1)
  from public.consignment_vmi_recon_r3440 l
  group by l.supplier_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3440_supplier_scorecard() from public, anon;
grant execute on function public.founder_r3440_supplier_scorecard() to authenticated;

-- 3) Stock-type × recon-status matrix
create or replace function public.founder_r3440_stock_type_status_matrix()
returns table(stock_type text, recon_status text, records bigint, total_variance_qty bigint, total_variance_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.stock_type, l.recon_status, count(*)::bigint,
    coalesce(sum(l.variance_qty),0)::bigint,
    coalesce(sum(l.variance_value_rupees),0)::numeric
  from public.consignment_vmi_recon_r3440 l
  group by l.stock_type, l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3440_stock_type_status_matrix() from public, anon;
grant execute on function public.founder_r3440_stock_type_status_matrix() to authenticated;

-- 4) Monthly reconciliation trend
create or replace function public.founder_r3440_monthly_recon_trend()
returns table(recon_month date, records bigint, matched bigint, discrepancies bigint, total_variance_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.last_count_date)::date,
    count(*)::bigint,
    count(*) filter (where l.recon_status = 'matched')::bigint,
    count(*) filter (where l.recon_status in ('short','excess','under_investigation'))::bigint,
    coalesce(sum(l.variance_value_rupees),0)::numeric
  from public.consignment_vmi_recon_r3440 l
  group by date_trunc('month', l.last_count_date)
  order by date_trunc('month', l.last_count_date) desc;
end;
$$;

revoke execute on function public.founder_r3440_monthly_recon_trend() from public, anon;
grant execute on function public.founder_r3440_monthly_recon_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3440_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.consignment_vmi_recon_capa_actions_r3440 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3440_capa_status_board() from public, anon;
grant execute on function public.founder_r3440_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3440_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.consignment_vmi_recon_capa_actions_r3440)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.consignment_vmi_recon_capa_actions_r3440 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3440_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3440_root_cause_pareto() to authenticated;

-- 7) Variance-value impact digest
create or replace function public.founder_r3440_variance_value_impact_digest()
returns table(variance_impact text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.variance_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric
  from public.consignment_vmi_recon_capa_actions_r3440 c
  group by c.variance_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3440_variance_value_impact_digest() from public, anon;
grant execute on function public.founder_r3440_variance_value_impact_digest() to authenticated;

-- 8) High-risk variance queue (large / aging discrepancies)
create or replace function public.founder_r3440_high_risk_queue()
returns table(
  engineer_name text,
  location_name text,
  part_name text,
  part_code text,
  supplier_name text,
  stock_type text,
  recon_status text,
  variance_qty int,
  variance_value_rupees numeric,
  aging_days int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.location_name, l.part_name, l.part_code, l.supplier_name,
    l.stock_type, l.recon_status, l.variance_qty, l.variance_value_rupees, l.aging_days, l.notes
  from public.consignment_vmi_recon_r3440 l
  where l.recon_status in ('short','excess','under_investigation','adjusted')
     or l.discrepancy_flag = true
     or coalesce(l.aging_days,0) >= 45
     or coalesce(l.variance_value_rupees,0) >= 100000
  order by coalesce(l.variance_value_rupees,0) desc, coalesce(l.aging_days,0) desc;
end;
$$;

revoke execute on function public.founder_r3440_high_risk_queue() from public, anon;
grant execute on function public.founder_r3440_high_risk_queue() to authenticated;
