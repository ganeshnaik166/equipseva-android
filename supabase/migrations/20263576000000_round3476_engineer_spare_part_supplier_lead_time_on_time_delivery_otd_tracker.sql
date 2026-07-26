-- Round 3476: Engineer Spare-Part Supplier Lead-Time / On-Time-Delivery (OTD) Tracker
-- Spare-part supplier lead-time / OTD-OTIF performance — supplier x part x PO x promised vs actual lead days x
-- lead variance x qty ordered/received x OTD status x OTIF x expedite x order/received date x CAPA closure

-- =============================================================================
-- TABLE 1: part_leadtime_otd_r3476 — per-PO supplier lead-time / OTD records
-- =============================================================================
create table if not exists public.part_leadtime_otd_r3476 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_name text not null,
  part_name text not null,
  part_code text not null,
  po_number text not null,
  promised_lead_days int not null,
  actual_lead_days int not null,
  lead_variance_days int not null,
  qty_ordered int not null,
  qty_received int not null,
  otd_status text not null check (otd_status in (
    'on_time','early','minor_delay','major_delay','partial'
  )),
  otif_met boolean not null,
  expedited boolean not null,
  order_date date not null,
  received_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.part_leadtime_otd_r3476 enable row level security;

create index if not exists idx_part_leadtime_otd_r3476_org on public.part_leadtime_otd_r3476(organization_id);
create index if not exists idx_part_leadtime_otd_r3476_date on public.part_leadtime_otd_r3476(order_date);
create index if not exists idx_part_leadtime_otd_r3476_status on public.part_leadtime_otd_r3476(otd_status);

-- =============================================================================
-- TABLE 2: part_leadtime_otd_capa_actions_r3476 — CAPA & supply actions
-- =============================================================================
create table if not exists public.part_leadtime_otd_capa_actions_r3476 (
  id uuid primary key default gen_random_uuid(),
  otd_log_id uuid not null references public.part_leadtime_otd_r3476(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'late_delivery','partial_shipment','lead_time_variance','expedite_required',
    'supplier_capacity_shortfall','logistics_delay','customs_clearance_delay',
    'quality_hold','forecast_miss','repeat_late_supplier'
  )),
  root_cause text not null check (root_cause in (
    'supplier_production_backlog','raw_material_shortage','freight_carrier_delay',
    'customs_documentation_error','incoming_qc_hold','demand_forecast_error',
    'po_placed_late','supplier_capacity_constraint','transport_strike','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_shipment','dual_source_supplier','increase_safety_stock','renegotiate_lead_time_sla',
    'switch_freight_mode','supplier_development_plan','update_reorder_point',
    'escalate_to_supplier_management','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  supply_impact text not null check (supply_impact in (
    'stockout_risk','sla_breach','none','internal_only','contract_penalty','patient_care_delay'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.part_leadtime_otd_capa_actions_r3476 enable row level security;

create index if not exists idx_part_leadtime_capa_r3476_log on public.part_leadtime_otd_capa_actions_r3476(otd_log_id);
create index if not exists idx_part_leadtime_capa_r3476_status on public.part_leadtime_otd_capa_actions_r3476(capa_status);

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

  -- 16 PO lead-time / OTD rows
  insert into public.part_leadtime_otd_r3476 (
    organization_id, supplier_name, part_name, part_code, po_number,
    promised_lead_days, actual_lead_days, lead_variance_days, qty_ordered, qty_received,
    otd_status, otif_met, expedited, order_date, received_date, notes
  )
  select v_org_id, q.sup, q.pnm, q.pcode, q.po,
    q.pld::int, q.ald::int, q.lvd::int, q.qord::int, q.qrec::int,
    q.otd, q.otif, q.xpd, q.odate::date, q.rdate::date, q.nt
  from (values
    ('Siemens Healthineers India','X-ray tube assembly','XRT-9001','PO-2026-0451',
     30,28,-2,2,2,'early',true,false,'2026-05-02','2026-05-30','CT X-ray tube delivered 2 days early — OTIF met'),
    ('GE Healthcare India','DR flat panel detector','DRP-3102','PO-2026-0452',
     45,45,0,1,1,'on_time',true,false,'2026-05-05','2026-06-19','DR panel arrived on promised date, in full'),
    ('Philips India','Patient monitor mainboard','PMB-7781','PO-2026-0453',
     21,26,5,4,4,'minor_delay',false,false,'2026-05-10','2026-06-05','Mainboards 5 days late — minor delay, OTIF missed'),
    ('Trivitron Healthcare','Ventilator turbine','VTB-2205','PO-2026-0454',
     20,41,21,3,3,'major_delay',false,true,'2026-05-12','2026-06-22','Ventilator turbine 21 days late — expedited air freight'),
    ('Wipro GE','CT slip ring brush set','CSR-4410','PO-2026-0455',
     35,33,-2,6,6,'early',true,false,'2026-05-15','2026-06-17','Slip ring brushes 2 days early, in full'),
    ('Nihon Kohden India','ECG cable set','ECG-1120','PO-2026-0456',
     14,14,0,20,20,'on_time',true,false,'2026-06-01','2026-06-15','ECG cable sets on time and in full'),
    ('Mindray India','SpO2 sensor board','SPO-6640','PO-2026-0457',
     18,30,12,10,6,'partial',false,false,'2026-06-03','2026-07-03','Only 6 of 10 SpO2 boards received — partial shipment'),
    ('Drager India','Anaesthesia flow sensor','AFS-3390','PO-2026-0458',
     25,48,23,5,5,'major_delay',false,true,'2026-06-05','2026-07-23','Flow sensors 23 days late — customs clearance delay'),
    ('BPL Medical','Defibrillator battery pack','DBP-8802','PO-2026-0459',
     12,11,-1,15,15,'early',true,false,'2026-06-08','2026-06-19','Defib batteries 1 day early, in full'),
    ('Skanray Technologies','Infusion pump motor','IPM-5150','PO-2026-0460',
     22,29,7,8,8,'minor_delay',false,false,'2026-06-10','2026-07-09','Infusion pump motors 7 days late'),
    ('Trivitron Healthcare','Dialysis pump rotor','DPR-9910','PO-2026-0461',
     28,55,27,4,2,'partial',false,true,'2026-06-12','2026-08-06','Dialysis rotors: 2 of 4, 27 days late — repeat late supplier'),
    ('Siemens Healthineers India','MRI gradient coil fan','MGF-2077','PO-2026-0462',
     40,38,-2,2,2,'early',true,false,'2026-06-14','2026-07-22','MRI coil fans 2 days early'),
    ('Poly Medicure','Oxygen concentrator sieve bed','OCS-3388','PO-2026-0463',
     16,24,8,12,12,'minor_delay',false,false,'2026-06-18','2026-07-12','Sieve beds 8 days late'),
    ('Allengers','Autoclave door gasket','ADG-1201','PO-2026-0464',
     10,10,0,30,30,'on_time',true,false,'2026-06-20','2026-06-30','Autoclave gaskets on time and in full'),
    ('GE Healthcare India','Ultrasound TR probe','UTP-7050','PO-2026-0465',
     32,60,28,3,3,'major_delay',false,true,'2026-06-22','2026-08-21','US probes 28 days late — supplier capacity shortfall, expedited'),
    ('Mindray India','Centrifuge rotor','CFR-4455','PO-2026-0466',
     24,23,-1,5,5,'early',true,false,'2026-06-25','2026-07-18','Centrifuge rotors 1 day early, in full')
  ) as q(sup, pnm, pcode, po, pld, ald, lvd, qord, qrec, otd, otif, xpd, odate, rdate, nt);

  -- CAPA seed — attach to specific POs via po_number
  insert into public.part_leadtime_otd_capa_actions_r3476 (
    otd_log_id, finding_category, root_cause, corrective_action,
    capa_status, supply_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PO-2026-0453','late_delivery','freight_carrier_delay','switch_freight_mode','closed','internal_only','Rajesh Kumar','2026-06-15','2026-06-12',8000.00,'Mainboards received; premium carrier locked for future POs'),
    ('PO-2026-0454','late_delivery','supplier_production_backlog','dual_source_supplier','in_progress','patient_care_delay','Anita Desai','2026-07-10',null,55000.00,'Ventilator turbine backlog — qualifying a second source'),
    ('PO-2026-0457','partial_shipment','raw_material_shortage','increase_safety_stock','open','stockout_risk','Vikram Nair','2026-07-20',null,12000.00,'Only 6 of 10 boards — raising safety stock and chasing balance'),
    ('PO-2026-0458','customs_clearance_delay','customs_documentation_error','escalate_to_supplier_management','escalated','contract_penalty','Priya Menon','2026-07-15',null,22000.00,'Customs docs error caused 23-day delay — penalty clause invoked'),
    ('PO-2026-0461','repeat_late_supplier','supplier_capacity_constraint','supplier_development_plan','in_progress','sla_breach','Anita Desai','2026-08-05',null,40000.00,'Third late PO this quarter — supplier development plan initiated'),
    ('PO-2026-0460','lead_time_variance','demand_forecast_error','update_reorder_point','verification_pending','internal_only','Rajesh Kumar','2026-07-18',null,5000.00,'Reorder point updated — verifying next cycle'),
    ('PO-2026-0465','supplier_capacity_shortfall','supplier_capacity_constraint','renegotiate_lead_time_sla','overdue','sla_breach','Priya Menon','2026-07-05',null,30000.00,'Probe capacity shortfall — SLA renegotiation past target date'),
    ('PO-2026-0463','expedite_required','po_placed_late','expedite_shipment','closed','internal_only','Vikram Nair','2026-07-14','2026-07-12',3500.00,'PO placed late; expedited — auto-reorder process fixed')
  ) as q(po, fc, rc, ca, cst, si, own, tcd, acd, cost, nt)
  join public.part_leadtime_otd_r3476 e
    on e.organization_id = v_org_id and e.po_number = q.po;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) OTD status distribution
create or replace function public.founder_r3476_otd_status_rollup()
returns table(otd_status text, orders bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.part_leadtime_otd_r3476)
  select l.otd_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.part_leadtime_otd_r3476 l
  group by l.otd_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3476_otd_status_rollup() from public, anon;
grant execute on function public.founder_r3476_otd_status_rollup() to authenticated;

-- 2) Supplier scorecard
create or replace function public.founder_r3476_supplier_scorecard()
returns table(
  supplier_name text,
  total_orders bigint,
  on_time bigint,
  early bigint,
  delayed bigint,
  partial bigint,
  otif_met_count bigint,
  avg_lead_variance_days numeric,
  otd_pct numeric
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
    count(*) filter (where l.otd_status = 'on_time')::bigint,
    count(*) filter (where l.otd_status = 'early')::bigint,
    count(*) filter (where l.otd_status in ('minor_delay','major_delay'))::bigint,
    count(*) filter (where l.otd_status = 'partial')::bigint,
    count(*) filter (where l.otif_met = true)::bigint,
    round(avg(l.lead_variance_days), 1),
    round(100.0 * count(*) filter (where l.otd_status in ('on_time','early'))::numeric / nullif(count(*),0), 1)
  from public.part_leadtime_otd_r3476 l
  group by l.supplier_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3476_supplier_scorecard() from public, anon;
grant execute on function public.founder_r3476_supplier_scorecard() to authenticated;

-- 3) Supplier x OTD-status matrix
create or replace function public.founder_r3476_supplier_otd_matrix()
returns table(supplier_name text, otd_status text, orders bigint, avg_variance_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name, l.otd_status, count(*)::bigint,
    round(avg(l.lead_variance_days), 1)
  from public.part_leadtime_otd_r3476 l
  group by l.supplier_name, l.otd_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3476_supplier_otd_matrix() from public, anon;
grant execute on function public.founder_r3476_supplier_otd_matrix() to authenticated;

-- 4) Monthly OTD trend
create or replace function public.founder_r3476_monthly_otd_trend()
returns table(order_month text, orders bigint, on_time bigint, delayed bigint, partial bigint, otif_met_count bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.order_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.otd_status in ('on_time','early'))::bigint,
    count(*) filter (where l.otd_status in ('minor_delay','major_delay'))::bigint,
    count(*) filter (where l.otd_status = 'partial')::bigint,
    count(*) filter (where l.otif_met = true)::bigint
  from public.part_leadtime_otd_r3476 l
  group by to_char(l.order_date, 'YYYY-MM')
  order by to_char(l.order_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3476_monthly_otd_trend() from public, anon;
grant execute on function public.founder_r3476_monthly_otd_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3476_capa_status_board()
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
  from public.part_leadtime_otd_capa_actions_r3476 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3476_capa_status_board() from public, anon;
grant execute on function public.founder_r3476_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3476_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.part_leadtime_otd_capa_actions_r3476)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.part_leadtime_otd_capa_actions_r3476 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3476_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3476_root_cause_pareto() to authenticated;

-- 7) Lead-variance impact digest
create or replace function public.founder_r3476_lead_variance_impact_digest()
returns table(
  otd_status text,
  orders bigint,
  total_variance_days bigint,
  avg_variance_days numeric,
  total_qty_short bigint,
  expedited_orders bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.otd_status,
    count(*)::bigint,
    coalesce(sum(l.lead_variance_days),0)::bigint,
    round(avg(l.lead_variance_days), 1),
    coalesce(sum(l.qty_ordered - l.qty_received),0)::bigint,
    count(*) filter (where l.expedited = true)::bigint
  from public.part_leadtime_otd_r3476 l
  group by l.otd_status
  order by coalesce(sum(l.lead_variance_days),0) desc;
end;
$$;

revoke execute on function public.founder_r3476_lead_variance_impact_digest() from public, anon;
grant execute on function public.founder_r3476_lead_variance_impact_digest() to authenticated;

-- 8) High-risk queue (major-delay / partial / repeat-late)
create or replace function public.founder_r3476_high_risk_queue()
returns table(
  supplier_name text,
  part_name text,
  part_code text,
  po_number text,
  order_date date,
  otd_status text,
  promised_lead_days int,
  actual_lead_days int,
  lead_variance_days int,
  qty_ordered int,
  qty_received int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_name, l.part_name, l.part_code, l.po_number, l.order_date,
    l.otd_status, l.promised_lead_days, l.actual_lead_days, l.lead_variance_days,
    l.qty_ordered, l.qty_received, l.notes
  from public.part_leadtime_otd_r3476 l
  where l.otd_status in ('major_delay','partial')
     or l.lead_variance_days > 3
     or l.otif_met = false
     or l.qty_received < l.qty_ordered
     or l.expedited = true
  order by l.lead_variance_days desc, l.order_date desc;
end;
$$;

revoke execute on function public.founder_r3476_high_risk_queue() from public, anon;
grant execute on function public.founder_r3476_high_risk_queue() to authenticated;
