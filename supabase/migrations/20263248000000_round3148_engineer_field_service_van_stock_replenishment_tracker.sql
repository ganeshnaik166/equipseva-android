-- Round 3148: Engineer Field-Service Van Stock & Consumables Replenishment Tracker
-- Van boot-stock lines — engineer × part category × on-hand/min/reorder × stockout × consumption rate × status + replenishment/CAPA

-- =============================================================================
-- TABLE 1: van_stock_r3148 — per-engineer van boot-stock consumable lines
-- =============================================================================
create table if not exists public.van_stock_r3148 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  base_hospital_name text not null,
  van_registration text not null,
  part_category text not null check (part_category in (
    'sensors_probes','cables_leads','batteries_power','filters_consumables',
    'tubing_circuits','calibration_kits','fuses_electronics','mechanical_spares',
    'disposables_sterile','adhesives_fixings'
  )),
  part_name text not null,
  part_sku text not null,
  unit_of_measure text not null check (unit_of_measure in (
    'each','box','pack','metre','litre','set','roll'
  )),
  on_hand_qty int not null,
  min_qty int not null,
  reorder_qty int not null,
  criticality text not null check (criticality in (
    'critical_life_support','high','medium','low','consumable'
  )),
  storage_condition text not null check (storage_condition in (
    'ambient','cold_chain_2_8c','dry_desiccant','anti_static','controlled_humidity'
  )),
  consumption_rate_per_week numeric(6,2),
  last_replenished_date date,
  expiry_date date,
  stockout_flag boolean not null default false,
  bin_location text,
  stock_status text not null check (stock_status in (
    'in_stock','low_stock','stockout','reorder_raised','replenished','overstock','expired_writeoff'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.van_stock_r3148 enable row level security;

create index if not exists idx_van_stock_r3148_org on public.van_stock_r3148(organization_id);
create index if not exists idx_van_stock_r3148_replenished on public.van_stock_r3148(last_replenished_date);
create index if not exists idx_van_stock_r3148_status on public.van_stock_r3148(stock_status);

-- =============================================================================
-- TABLE 2: van_stock_capa_actions_r3148 — replenishment & CAPA actions
-- =============================================================================
create table if not exists public.van_stock_capa_actions_r3148 (
  id uuid primary key default gen_random_uuid(),
  van_stock_id uuid not null references public.van_stock_r3148(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stockout_critical_part','below_min_threshold','expired_stock_found','consumption_spike',
    'reorder_not_raised','wrong_part_stocked','cold_chain_breach','inventory_count_mismatch',
    'damaged_in_transit','slow_moving_overstock'
  )),
  root_cause text not null check (root_cause in (
    'demand_forecast_miss','supplier_lead_time_long','reorder_point_too_low','engineer_did_not_report',
    'central_store_out_of_stock','cold_chain_equipment_failure','manual_count_error','seasonal_demand_surge',
    'pending_investigation','budget_hold_procurement'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_supplier_po','raise_reorder_now','transfer_from_other_van','increase_reorder_point',
    'writeoff_expired_stock','retrain_engineer_reporting','repair_cold_chain_box','recount_and_reconcile',
    'none_required','renegotiate_supplier_sla'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'patient_safety_risk','sla_breach_customer','nabh_finding','none','internal_only','warranty_impact'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.van_stock_capa_actions_r3148 enable row level security;

create index if not exists idx_van_stock_capa_r3148_stock on public.van_stock_capa_actions_r3148(van_stock_id);
create index if not exists idx_van_stock_capa_r3148_status on public.van_stock_capa_actions_r3148(capa_status);

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

  -- 14 van-stock lines
  insert into public.van_stock_r3148 (
    organization_id, engineer_name, base_hospital_name, van_registration,
    part_category, part_name, part_sku, unit_of_measure,
    on_hand_qty, min_qty, reorder_qty, criticality, storage_condition,
    consumption_rate_per_week, last_replenished_date, expiry_date,
    stockout_flag, bin_location, stock_status, notes
  )
  select v_org_id, q.eng, q.hosp, q.van,
    q.cat, q.pn, q.sku, q.uom,
    q.oh, q.mn, q.ro, q.crit, q.store,
    q.cons, q.lrd::date, q.exp::date,
    q.so, q.bin, q.st, q.nt
  from (values
    ('Ramesh Kumar','Apollo Hyderabad Jubilee Hills','TS09-EQ-1420',
     'sensors_probes','Masimo SpO2 finger sensor','SKU-SPO2-001','each',
     8,4,12,'high','ambient',2.50,'2026-07-10','2027-06-30',false,'A1','in_stock','Routine SpO2 sensor stock'),
    ('Ramesh Kumar','Apollo Hyderabad Jubilee Hills','TS09-EQ-1420',
     'batteries_power','Li-ion battery pack Philips MX40','SKU-BAT-014','each',
     1,3,6,'critical_life_support','ambient',1.00,'2026-06-20','2028-01-31',false,'B2','low_stock','Below min — telemetry pack batteries'),
    ('Suresh Nair','Fortis Bannerghatta Bengaluru','KA05-EQ-3312',
     'cables_leads','ECG 5-lead trunk cable','SKU-ECG-007','each',
     0,2,5,'high','ambient',0.80,'2026-05-15',null,true,'C1','stockout','Stockout — two open jobs waiting'),
    ('Suresh Nair','Fortis Bannerghatta Bengaluru','KA05-EQ-3312',
     'filters_consumables','Ventilator HEPA filter Drager','SKU-FLT-022','pack',
     12,4,10,'medium','dry_desiccant',3.50,'2026-07-12','2027-03-31',false,'D3','in_stock','Well stocked HEPA filters'),
    ('Anil Reddy','Manipal Whitefield Bengaluru','KA53-EQ-2201',
     'tubing_circuits','Anaesthesia breathing circuit','SKU-TUB-030','set',
     2,5,15,'high','dry_desiccant',4.00,'2026-06-28','2027-09-30',false,'E1','low_stock','Consumption spike this month'),
    ('Anil Reddy','Manipal Whitefield Bengaluru','KA53-EQ-2201',
     'calibration_kits','NIBP calibration kit','SKU-CAL-009','set',
     3,1,2,'medium','anti_static',0.25,'2026-07-01','2027-12-31',false,'F2','in_stock','Quarterly calibration kit'),
    ('Vikram Singh','AIIMS New Delhi Ansari Nagar','DL01-EQ-5590',
     'fuses_electronics','T2A ceramic fuse assorted','SKU-FUS-041','box',
     25,10,50,'low','anti_static',5.00,'2026-07-14',null,false,'G1','overstock','Bulk buy — overstock vs usage'),
    ('Vikram Singh','AIIMS New Delhi Ansari Nagar','DL01-EQ-5590',
     'disposables_sterile','Sterile ultrasound probe cover','SKU-DIS-018','pack',
     0,6,20,'high','controlled_humidity',6.00,'2026-05-30','2026-07-10',true,'H2','expired_writeoff','Expired stock written off — now stockout'),
    ('Farhan Ali','KIMS Secunderabad','TS07-EQ-8834',
     'mechanical_spares','Infusion pump peristaltic rotor','SKU-MEC-055','each',
     4,2,6,'medium','ambient',1.20,'2026-07-05',null,false,'I3','in_stock','Standard mechanical spare'),
    ('Farhan Ali','KIMS Secunderabad','TS07-EQ-8834',
     'batteries_power','Defibrillator battery Zoll','SKU-BAT-061','each',
     1,2,4,'critical_life_support','ambient',0.50,'2026-06-10','2027-08-31',false,'J1','reorder_raised','PO raised for defib batteries'),
    ('Deepak Rao','Care Hospitals Banjara Hills','TS08-EQ-4417',
     'adhesives_fixings','ECG electrode adhesive gel','SKU-ADH-027','roll',
     15,5,12,'consumable','cold_chain_2_8c',4.50,'2026-07-08','2027-01-31',false,'K2','in_stock','Cold-chain gel stock ok'),
    ('Karthik Menon','Yashoda Somajiguda Hyderabad','TS09-EQ-6673',
     'sensors_probes','Temperature probe skin YSI-400','SKU-TMP-072','each',
     2,4,10,'high','ambient',2.00,'2026-06-25',null,false,'L1','low_stock','Below min after two replacements'),
    ('Joseph Thomas','St John''s Bengaluru','KA01-EQ-9902',
     'cables_leads','SpO2 extension cable','SKU-CAB-088','each',
     6,3,8,'medium','ambient',1.50,'2026-07-15',null,false,'M2','replenished','Just replenished this week'),
    ('Priya Sharma','Rainbow Children''s Hyderabad','TS10-EQ-1156',
     'filters_consumables','Neonatal ventilator filter','SKU-FLT-095','pack',
     0,8,24,'critical_life_support','controlled_humidity',7.00,'2026-05-20','2026-08-15',true,'N1','stockout','Critical neonatal filter stockout — urgent')
  ) as q(eng, hosp, van, cat, pn, sku, uom, oh, mn, ro, crit, store, cons, lrd, exp, so, bin, st, nt);

  -- CAPA seed — attach to specific van-stock lines via SKU
  insert into public.van_stock_capa_actions_r3148 (
    van_stock_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select v.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('SKU-ECG-007','stockout_critical_part','central_store_out_of_stock','expedite_supplier_po',
     '2026-07-22',null,'in_progress','sla_breach_customer',18000.00,'Central store dry — expedite PO with vendor'),
    ('SKU-DIS-018','expired_stock_found','demand_forecast_miss','writeoff_expired_stock',
     '2026-07-20','2026-07-16','closed','warranty_impact',9500.00,'Wrote off 6 expired probe covers, reforecast demand'),
    ('SKU-FLT-095','stockout_critical_part','seasonal_demand_surge','transfer_from_other_van',
     '2026-07-19',null,'escalated','patient_safety_risk',24000.00,'Neonatal ICU demand surge — escalated to procurement head'),
    ('SKU-BAT-014','below_min_threshold','reorder_point_too_low','increase_reorder_point',
     '2026-07-25',null,'open','none',0.00,'Raise reorder point from 3 to 5 for MX40 packs'),
    ('SKU-TUB-030','consumption_spike','seasonal_demand_surge','raise_reorder_now',
     '2026-07-21',null,'in_progress','sla_breach_customer',12000.00,'OT volume up — reorder circuits now'),
    ('SKU-BAT-061','below_min_threshold','supplier_lead_time_long','renegotiate_supplier_sla',
     '2026-07-30',null,'open','patient_safety_risk',15000.00,'Zoll battery lead time 6 weeks — renegotiate SLA')
  ) as q(sku_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.van_stock_r3148 v
    on v.organization_id = v_org_id and v.part_sku = q.sku_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Stock status distribution
create or replace function public.founder_r3148_stock_status_rollup()
returns table(stock_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.van_stock_r3148)
  select v.stock_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.van_stock_r3148 v
  group by v.stock_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3148_stock_status_rollup() from public, anon;
grant execute on function public.founder_r3148_stock_status_rollup() to authenticated;

-- 2) Hospital / base scorecard
create or replace function public.founder_r3148_hospital_scorecard()
returns table(
  base_hospital_name text,
  total_lines bigint,
  in_stock bigint,
  low_stock bigint,
  stockouts bigint,
  critical_lines bigint,
  avg_consumption numeric,
  health_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.base_hospital_name,
    count(*)::bigint,
    count(*) filter (where v.stock_status = 'in_stock')::bigint,
    count(*) filter (where v.stock_status = 'low_stock')::bigint,
    count(*) filter (where v.stock_status = 'stockout')::bigint,
    count(*) filter (where v.criticality = 'critical_life_support')::bigint,
    round(avg(v.consumption_rate_per_week), 2),
    round(100.0 * count(*) filter (where v.stock_status in ('in_stock','replenished','overstock'))::numeric / nullif(count(*),0), 1)
  from public.van_stock_r3148 v
  group by v.base_hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3148_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3148_hospital_scorecard() to authenticated;

-- 3) Part category × criticality matrix
create or replace function public.founder_r3148_category_matrix()
returns table(part_category text, criticality text, lines bigint, stockouts bigint, avg_on_hand numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.part_category, v.criticality, count(*)::bigint,
    count(*) filter (where v.stock_status = 'stockout')::bigint,
    round(avg(v.on_hand_qty), 2)
  from public.van_stock_r3148 v
  group by v.part_category, v.criticality
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3148_category_matrix() from public, anon;
grant execute on function public.founder_r3148_category_matrix() to authenticated;

-- 4) Replenishment daily trend
create or replace function public.founder_r3148_replenishment_trend()
returns table(last_replenished_date date, replenished bigint, stockouts bigint, low_stock bigint, avg_on_hand numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.last_replenished_date,
    count(*)::bigint,
    count(*) filter (where v.stock_status = 'stockout')::bigint,
    count(*) filter (where v.stock_status = 'low_stock')::bigint,
    round(avg(v.on_hand_qty), 2)
  from public.van_stock_r3148 v
  where v.last_replenished_date is not null
  group by v.last_replenished_date
  order by v.last_replenished_date desc;
end;
$$;

revoke execute on function public.founder_r3148_replenishment_trend() from public, anon;
grant execute on function public.founder_r3148_replenishment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3148_capa_status_board()
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
  from public.van_stock_capa_actions_r3148 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3148_capa_status_board() from public, anon;
grant execute on function public.founder_r3148_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3148_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.van_stock_capa_actions_r3148)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.van_stock_capa_actions_r3148 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3148_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3148_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3148_regulatory_impact_digest()
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
  from public.van_stock_capa_actions_r3148 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3148_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3148_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority replenishment queue
create or replace function public.founder_r3148_priority_queue()
returns table(
  engineer_name text,
  base_hospital_name text,
  van_registration text,
  part_name text,
  part_category text,
  on_hand_qty int,
  min_qty int,
  criticality text,
  stock_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.engineer_name, v.base_hospital_name, v.van_registration, v.part_name, v.part_category,
    v.on_hand_qty, v.min_qty, v.criticality, v.stock_status, v.notes
  from public.van_stock_r3148 v
  where v.stock_status in ('stockout','low_stock','reorder_raised','expired_writeoff')
     or v.stockout_flag = true
     or v.criticality = 'critical_life_support'
  order by
    case v.stock_status
      when 'stockout' then 0
      when 'expired_writeoff' then 1
      when 'low_stock' then 2
      else 3
    end,
    v.base_hospital_name;
end;
$$;

revoke execute on function public.founder_r3148_priority_queue() from public, anon;
grant execute on function public.founder_r3148_priority_queue() to authenticated;
