-- Round 3272: Engineer Spare-Part Reorder-Point & Safety-Stock Discipline Tracker
-- Per SKU-location stock discipline — store location × equipment family × on-hand vs reorder-point/safety-stock × days-of-cover × ABC class × stock verdict + replenishment/rationalization CAPA

-- =============================================================================
-- TABLE 1: spare_part_reorder_r3272 — per SKU-location stock discipline rows
-- =============================================================================
create table if not exists public.spare_part_reorder_r3272 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  store_location text not null check (store_location in (
    'chennai_hub','gurgaon_hub','bengaluru_hub','hyderabad_hub','van_stock_pooled'
  )),
  part_sku text not null,
  part_name text not null,
  equipment_family text not null check (equipment_family in (
    'patient_monitor','infusion_pump','ventilator','imaging','dialysis','general'
  )),
  on_hand_qty int not null,
  reorder_point int not null,
  safety_stock int not null,
  avg_monthly_consumption numeric(8,2) not null,
  lead_time_days int not null,
  stockout_days_last_90 int not null,
  open_po_qty int not null,
  days_of_cover numeric(8,2),
  abc_class text not null check (abc_class in (
    'a_critical','b_important','c_routine'
  )),
  stock_verdict text not null check (stock_verdict in (
    'healthy','reorder_now','below_safety','stockout','overstocked','dead_stock'
  )),
  review_date date not null,
  reviewed_at timestamptz not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spare_part_reorder_r3272 enable row level security;

create index if not exists idx_spare_part_reorder_r3272_org on public.spare_part_reorder_r3272(organization_id);
create index if not exists idx_spare_part_reorder_r3272_date on public.spare_part_reorder_r3272(review_date);
create index if not exists idx_spare_part_reorder_r3272_verdict on public.spare_part_reorder_r3272(stock_verdict);

-- =============================================================================
-- TABLE 2: spare_part_reorder_capa_actions_r3272 — replenishment / rationalization CAPA
-- =============================================================================
create table if not exists public.spare_part_reorder_capa_actions_r3272 (
  id uuid primary key default gen_random_uuid(),
  stock_row_id uuid not null references public.spare_part_reorder_r3272(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stockout','below_safety_stock','dead_stock','overstock',
    'reorder_point_breach','long_lead_time','consumption_spike','po_delay'
  )),
  root_cause text not null check (root_cause in (
    'demand_spike_unforecast','supplier_lead_time_slip','po_not_raised','min_max_misconfigured',
    'obsolete_equipment_retired','van_stock_hoarding','budget_hold_on_po','no_consumption_dead_sku',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_emergency_po','rebalance_from_hub','update_reorder_point','update_safety_stock',
    'return_to_supplier','redistribute_dead_stock','scrap_obsolete_stock','expedite_open_po',
    'set_min_max_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'sla_breach_risk','pm_delay_risk','revenue_loss','capital_tied_up',
    'patient_safety_risk','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spare_part_reorder_capa_actions_r3272 enable row level security;

create index if not exists idx_spare_part_capa_r3272_row on public.spare_part_reorder_capa_actions_r3272(stock_row_id);
create index if not exists idx_spare_part_capa_r3272_status on public.spare_part_reorder_capa_actions_r3272(capa_status);

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

  -- 14 SKU-location stock discipline rows
  insert into public.spare_part_reorder_r3272 (
    organization_id, store_location, part_sku, part_name, equipment_family,
    on_hand_qty, reorder_point, safety_stock, avg_monthly_consumption, lead_time_days,
    stockout_days_last_90, open_po_qty, days_of_cover, abc_class, stock_verdict,
    review_date, reviewed_at, notes
  )
  select v_org_id, q.loc, q.sku, q.pname, q.fam,
    q.onhand, q.rop, q.ss, q.amc, q.lead,
    q.sod, q.opo, q.doc, q.abc, q.verdict,
    q.rvd::date, q.rvt::timestamptz, q.nt
  from (values
    ('chennai_hub','MON-SPO2-CBL-08','Masimo LNCS SpO2 patient cable','patient_monitor',
     24,15,8,9.00,21,0,0,80.00,'b_important','healthy','2026-07-15','2026-07-15 10:20:00+05:30','Cycle count clean — cover well above reorder point'),
    ('chennai_hub','INF-PUMP-DOOR-SENS','Infusion pump door position sensor','infusion_pump',
     6,10,5,4.00,30,0,12,45.00,'a_critical','reorder_now','2026-07-15','2026-07-15 10:40:00+05:30','On-hand below reorder point — PO of 12 in flight'),
    ('gurgaon_hub','VEN-O2-SENSOR-CELL','Ventilator galvanic O2 sensor cell','ventilator',
     3,8,6,6.00,28,2,0,15.00,'a_critical','below_safety','2026-07-14','2026-07-14 09:15:00+05:30','Below safety stock — 2 stockout days last 90, no open PO'),
    ('gurgaon_hub','IMG-DR-DETECTOR-BAT','Portable DR flat-panel detector battery','imaging',
     0,4,2,2.50,45,11,4,0.00,'a_critical','stockout','2026-07-14','2026-07-14 09:35:00+05:30','Zero on-hand — 45-day lead, PO of 4 escalated to vendor'),
    ('bengaluru_hub','DIA-RO-MEMBRANE','Dialysis RO membrane element','dialysis',
     2,6,4,3.00,35,5,0,20.00,'a_critical','below_safety','2026-07-13','2026-07-13 08:50:00+05:30','Below safety — Manipal Whitefield demand spiked, raise PO'),
    ('bengaluru_hub','MON-ECG-LEADWIRE-5','ECG 5-lead patient wireset','patient_monitor',
     40,18,10,11.00,20,0,0,109.00,'b_important','healthy','2026-07-13','2026-07-13 09:05:00+05:30','Healthy cover — reviewed by Ramesh Iyer'),
    ('hyderabad_hub','INF-SYRINGE-PUMP-BAT','Syringe pump Li-ion battery pack','infusion_pump',
     55,12,6,3.50,25,0,0,471.00,'c_routine','overstocked','2026-07-12','2026-07-12 11:10:00+05:30','Overstocked — min/max misconfigured, cut reorder point'),
    ('hyderabad_hub','VEN-EXP-VALVE-DIAPH','Ventilator expiratory valve diaphragm','ventilator',
     9,10,5,5.00,30,0,20,54.00,'a_critical','reorder_now','2026-07-12','2026-07-12 11:30:00+05:30','Just under reorder point — KIMS PM cycle, PO of 20 open'),
    ('van_stock_pooled','MON-NIBP-CUFF-ADULT','NIBP reusable adult cuff','patient_monitor',
     30,20,12,14.00,15,0,0,64.00,'b_important','healthy','2026-07-11','2026-07-11 16:20:00+05:30','Pooled van stock healthy across field engineers'),
    ('van_stock_pooled','GEN-CASTER-WHEEL-5IN','Equipment trolley caster wheel 5in','general',
     4,0,0,0.00,20,0,0,0.00,'c_routine','dead_stock','2026-07-11','2026-07-11 16:40:00+05:30','No consumption in 18 months — obsolete trolley line'),
    ('chennai_hub','IMG-USG-PROBE-CBL','Ultrasound curvilinear probe cable','imaging',
     1,3,2,1.50,40,3,3,20.00,'a_critical','below_safety','2026-07-15','2026-07-15 12:05:00+05:30','Below safety — Apollo Chennai probe repair backlog'),
    ('gurgaon_hub','DIA-BLOOD-TUBING-SET','Dialysis arterial-venous blood tubing set','dialysis',
     120,60,40,55.00,18,0,0,65.00,'a_critical','healthy','2026-07-14','2026-07-14 10:05:00+05:30','High-volume consumable — Fortis Gurgaon cover healthy'),
    ('bengaluru_hub','VEN-FLOW-SENSOR','Ventilator proximal flow sensor','ventilator',
     0,6,4,4.50,32,8,0,0.00,'a_critical','stockout','2026-07-13','2026-07-13 09:25:00+05:30','Stockout — PO never raised, 8 stockout days last 90'),
    ('hyderabad_hub','GEN-PRINTER-PAPER-ROLL','Thermal recorder printer paper roll','general',
     200,50,30,20.00,10,0,0,300.00,'c_routine','overstocked','2026-07-12','2026-07-12 12:15:00+05:30','Overstocked routine consumable — capital tied up')
  ) as q(loc, sku, pname, fam, onhand, rop, ss, amc, lead, sod, opo, doc, abc, verdict, rvd, rvt, nt);

  -- CAPA seed — attach to at-risk SKU rows via part_sku
  insert into public.spare_part_reorder_capa_actions_r3272 (
    stock_row_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('INF-PUMP-DOOR-SENS','reorder_point_breach','po_not_raised','raise_emergency_po','in_progress','sla_breach_risk','2026-07-20',null,14000.00,'Reorder point breached — emergency PO raised with OEM'),
    ('VEN-O2-SENSOR-CELL','below_safety_stock','supplier_lead_time_slip','rebalance_from_hub','open','patient_safety_risk','2026-07-19',null,22000.00,'Below safety — pull 4 cells from Hyderabad hub to Gurgaon'),
    ('IMG-DR-DETECTOR-BAT','stockout','supplier_lead_time_slip','expedite_open_po','escalated','revenue_loss','2026-07-22',null,185000.00,'Detector down at Fortis Gurgaon — expedite 4-unit PO'),
    ('DIA-RO-MEMBRANE','below_safety_stock','demand_spike_unforecast','raise_emergency_po','open','patient_safety_risk','2026-07-21',null,95000.00,'Dialysis demand spike unforecast — emergency PO placed'),
    ('VEN-FLOW-SENSOR','stockout','po_not_raised','raise_emergency_po','overdue','patient_safety_risk','2026-07-10',null,28000.00,'Stockout overdue — PO never raised, escalate to store lead'),
    ('GEN-CASTER-WHEEL-5IN','dead_stock','obsolete_equipment_retired','scrap_obsolete_stock','closed','capital_tied_up','2026-07-08','2026-07-14',3000.00,'Dead stock for retired trolley line — scrapped and written off'),
    ('INF-SYRINGE-PUMP-BAT','overstock','min_max_misconfigured','update_reorder_point','verification_pending','capital_tied_up','2026-07-18',null,0.00,'Overstock from bad min/max — reorder point lowered, verifying')
  ) as q(sku, fc, rc, ca, cst, bi, tcd, acd, cost, nt)
  join public.spare_part_reorder_r3272 e
    on e.organization_id = v_org_id and e.part_sku = q.sku;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Stock verdict distribution
create or replace function public.founder_r3272_stock_verdict_rollup()
returns table(stock_verdict text, skus bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spare_part_reorder_r3272)
  select l.stock_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.spare_part_reorder_r3272 l
  group by l.stock_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3272_stock_verdict_rollup() from public, anon;
grant execute on function public.founder_r3272_stock_verdict_rollup() to authenticated;

-- 2) Store-location scorecard
create or replace function public.founder_r3272_location_scorecard()
returns table(
  store_location text,
  total_skus bigint,
  healthy bigint,
  reorder_now bigint,
  below_safety bigint,
  stockout bigint,
  dead_stock bigint,
  healthy_pct numeric
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
    count(*) filter (where l.stock_verdict = 'healthy')::bigint,
    count(*) filter (where l.stock_verdict = 'reorder_now')::bigint,
    count(*) filter (where l.stock_verdict = 'below_safety')::bigint,
    count(*) filter (where l.stock_verdict = 'stockout')::bigint,
    count(*) filter (where l.stock_verdict = 'dead_stock')::bigint,
    round(100.0 * count(*) filter (where l.stock_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.spare_part_reorder_r3272 l
  group by l.store_location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3272_location_scorecard() from public, anon;
grant execute on function public.founder_r3272_location_scorecard() to authenticated;

-- 3) Store-location × equipment-family matrix
create or replace function public.founder_r3272_location_family_matrix()
returns table(store_location text, equipment_family text, skus bigint, at_risk bigint, avg_days_of_cover numeric, total_stockout_days bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_location, l.equipment_family, count(*)::bigint,
    count(*) filter (where l.stock_verdict in ('reorder_now','below_safety','stockout','dead_stock'))::bigint,
    round(avg(l.days_of_cover), 1),
    coalesce(sum(l.stockout_days_last_90),0)::bigint
  from public.spare_part_reorder_r3272 l
  group by l.store_location, l.equipment_family
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3272_location_family_matrix() from public, anon;
grant execute on function public.founder_r3272_location_family_matrix() to authenticated;

-- 4) Daily review trend
create or replace function public.founder_r3272_daily_review_trend()
returns table(review_date date, skus_reviewed bigint, reorder_now bigint, below_safety bigint, stockout bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_date,
    count(*)::bigint,
    count(*) filter (where l.stock_verdict = 'reorder_now')::bigint,
    count(*) filter (where l.stock_verdict = 'below_safety')::bigint,
    count(*) filter (where l.stock_verdict = 'stockout')::bigint
  from public.spare_part_reorder_r3272 l
  group by l.review_date
  order by l.review_date desc;
end;
$$;

revoke execute on function public.founder_r3272_daily_review_trend() from public, anon;
grant execute on function public.founder_r3272_daily_review_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3272_capa_status_board()
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
  from public.spare_part_reorder_capa_actions_r3272 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3272_capa_status_board() from public, anon;
grant execute on function public.founder_r3272_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3272_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spare_part_reorder_capa_actions_r3272)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.spare_part_reorder_capa_actions_r3272 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3272_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3272_root_cause_pareto() to authenticated;

-- 7) Business impact digest
create or replace function public.founder_r3272_business_impact_digest()
returns table(business_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.business_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.spare_part_reorder_capa_actions_r3272 c
  group by c.business_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3272_business_impact_digest() from public, anon;
grant execute on function public.founder_r3272_business_impact_digest() to authenticated;

-- 8) High-risk stock queue (individual at-risk SKU-locations)
create or replace function public.founder_r3272_high_risk_queue()
returns table(
  store_location text,
  part_sku text,
  part_name text,
  equipment_family text,
  on_hand_qty int,
  reorder_point int,
  safety_stock int,
  days_of_cover numeric,
  stockout_days_last_90 int,
  abc_class text,
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
  select l.store_location, l.part_sku, l.part_name, l.equipment_family,
    l.on_hand_qty, l.reorder_point, l.safety_stock, l.days_of_cover,
    l.stockout_days_last_90, l.abc_class, l.stock_verdict, l.notes
  from public.spare_part_reorder_r3272 l
  where l.stock_verdict in ('reorder_now','below_safety','stockout','dead_stock')
     or l.stockout_days_last_90 > 0
     or (l.abc_class = 'a_critical' and l.on_hand_qty <= l.reorder_point)
  order by
    case l.stock_verdict
      when 'stockout' then 1
      when 'below_safety' then 2
      when 'reorder_now' then 3
      when 'dead_stock' then 4
      else 5
    end,
    l.stockout_days_last_90 desc,
    l.store_location;
end;
$$;

revoke execute on function public.founder_r3272_high_risk_queue() from public, anon;
grant execute on function public.founder_r3272_high_risk_queue() to authenticated;
