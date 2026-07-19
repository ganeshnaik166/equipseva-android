-- Round 3329: Founder Spare-Parts Obsolescence, Slow-Moving & Inventory Write-Down Board
-- Inventory-finance governance — store × equipment family × on-hand value × months-since-movement × movement class × installed-base linkage × shelf life × provision % × disposal route × inventory verdict × CAPA

-- =============================================================================
-- TABLE 1: spare_parts_obsolescence_r3329 — per SKU/store obsolescence records
-- =============================================================================
create table if not exists public.spare_parts_obsolescence_r3329 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  store_location text not null,
  part_sku text not null,
  part_name text not null,
  equipment_family text not null check (equipment_family in (
    'patient_monitor','imaging','dialysis','infusion_pump','ventilator','lab_analyzer','legacy_discontinued'
  )),
  on_hand_qty int not null,
  on_hand_value_rupees numeric(14,2) not null,
  last_movement_date date not null,
  months_since_movement int not null,
  movement_class text not null check (movement_class in (
    'fast','slow','non_moving','dead','obsolete'
  )),
  linked_installed_base int not null,
  shelf_life_expiry date,
  provision_pct numeric(5,2),
  provision_amount_rupees numeric(14,2),
  disposal_route text not null check (disposal_route in (
    'retain','discount_sell','return_to_oem','scrap','donate','write_off'
  )),
  inventory_verdict text not null check (inventory_verdict in (
    'healthy','watch','provision_needed','write_down_now','dispose'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spare_parts_obsolescence_r3329 enable row level security;

create index if not exists idx_spare_parts_obsolescence_r3329_org on public.spare_parts_obsolescence_r3329(organization_id);
create index if not exists idx_spare_parts_obsolescence_r3329_moved on public.spare_parts_obsolescence_r3329(last_movement_date);
create index if not exists idx_spare_parts_obsolescence_r3329_verdict on public.spare_parts_obsolescence_r3329(inventory_verdict);

-- =============================================================================
-- TABLE 2: spare_parts_obsolescence_capa_actions_r3329 — liquidation / provision / return actions
-- =============================================================================
create table if not exists public.spare_parts_obsolescence_capa_actions_r3329 (
  id uuid primary key default gen_random_uuid(),
  part_log_id uuid not null references public.spare_parts_obsolescence_r3329(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'obsolete_stock_write_off','slow_moving_provision','dead_stock_liquidation','expiry_imminent',
    'oem_return_eligible','installed_base_end_of_life','excess_reorder_error'
  )),
  root_cause text not null check (root_cause in (
    'over_procurement','demand_forecast_error','equipment_fleet_retired','supplier_moq_bulk',
    'engineering_change_order','no_disposal_process','pending_investigation','shelf_life_lapse'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_write_down','book_provision','liquidate_discount_sale','return_to_oem_credit',
    'scrap_and_dispose','donate_to_institution','adjust_reorder_point','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'pnl_write_down','provision_increase','oem_credit_recovery','none','internal_only','audit_qualification_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.spare_parts_obsolescence_capa_actions_r3329 enable row level security;

create index if not exists idx_spare_parts_obsolescence_capa_r3329_log on public.spare_parts_obsolescence_capa_actions_r3329(part_log_id);
create index if not exists idx_spare_parts_obsolescence_capa_r3329_status on public.spare_parts_obsolescence_capa_actions_r3329(capa_status);

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

  -- 14 SKU/store obsolescence rows
  insert into public.spare_parts_obsolescence_r3329 (
    organization_id, store_location, part_sku, part_name, equipment_family,
    on_hand_qty, on_hand_value_rupees, last_movement_date, months_since_movement, movement_class,
    linked_installed_base, shelf_life_expiry, provision_pct, provision_amount_rupees,
    disposal_route, inventory_verdict, notes
  )
  select v_org_id, q.store, q.sku, q.pname, q.fam,
    q.qty, q.val, q.lmd::date, q.msm, q.mc,
    q.lib, q.sle::date, q.ppct, q.pamt,
    q.dr, q.verdict, q.nt
  from (values
    ('Apollo Chennai Central Store','SP-PM-1001','Philips MP70 SpO2 module','patient_monitor',
     24,480000.00,'2026-06-20',1,'fast',310,null,0.00,0.00,'retain','healthy','High-turn consumable across Apollo monitor fleet'),
    ('Fortis Gurgaon Regional Store','SP-IMG-2044','GE CT detector cooling fan','imaging',
     6,720000.00,'2026-02-10',5,'slow',42,null,15.00,108000.00,'retain','watch','Fitment only on GE Revolution installed base'),
    ('Manipal Bengaluru Store','SP-DIA-3120','Fresenius 4008S dialysate filter','dialysis',
     60,300000.00,'2025-09-05',10,'non_moving',18,'2026-11-30',50.00,150000.00,'discount_sell','provision_needed','Fleet shrank after 4008S retirement; shelf life expiring'),
    ('AIIMS Delhi Biomedical Store','SP-VEN-4088','Drager Evita XL expiratory valve','ventilator',
     15,525000.00,'2025-01-15',18,'dead',4,null,90.00,472500.00,'return_to_oem','write_down_now','Evita XL fleet decommissioned; OEM buyback under review'),
    ('CMC Vellore Store','SP-LEG-5001','Nihon Kohden BSM-2301 CRT display','legacy_discontinued',
     8,96000.00,'2024-06-01',25,'obsolete',0,null,100.00,96000.00,'scrap','dispose','CRT monitors fully retired; no installed base left'),
    ('KIMS Hyderabad Store','SP-INF-6033','BD Alaris pump door assembly','infusion_pump',
     30,210000.00,'2026-03-18',4,'slow',140,null,10.00,21000.00,'retain','watch','Slowing after Alaris software recall; monitor demand'),
    ('Apollo Chennai Central Store','SP-LAB-7011','Roche Cobas c311 ISE electrode','lab_analyzer',
     22,264000.00,'2025-08-22',11,'non_moving',9,'2027-03-31',40.00,105600.00,'return_to_oem','provision_needed','Cobas c311 replaced by c503 at most Apollo labs'),
    ('Fortis Gurgaon Regional Store','SP-PM-8027','Mindray T8 parameter board','patient_monitor',
     12,360000.00,'2025-02-28',17,'dead',3,null,85.00,306000.00,'write_off','write_down_now','T8 fleet migrated to N-series; boards non-interchangeable'),
    ('Manipal Bengaluru Store','SP-IMG-9002','Siemens MRI gradient coil coolant pump','imaging',
     4,880000.00,'2026-06-10',1,'fast',22,null,0.00,0.00,'retain','healthy','Critical MRI spare; strategic stock retained'),
    ('AIIMS Delhi Biomedical Store','SP-DIA-1077','Nipro Surdial bicarbonate cartridge','dialysis',
     45,135000.00,'2024-10-12',21,'obsolete',0,'2026-04-30',100.00,135000.00,'donate','dispose','Surdial units gone; cartridges past shelf life, non-saleable'),
    ('CMC Vellore Store','SP-VEN-1145','Hamilton C1 flow sensor','ventilator',
     50,250000.00,'2026-01-25',6,'slow',65,'2027-09-30',15.00,37500.00,'retain','watch','Consumption dipped after single-use policy change'),
    ('KIMS Hyderabad Store','SP-LEG-1230','Datex-Ohmeda S/5 anaesthesia gas module','legacy_discontinued',
     5,425000.00,'2025-03-30',16,'dead',2,null,80.00,340000.00,'return_to_oem','write_down_now','S/5 platform EOL by GE; only 2 units left in field'),
    ('Apollo Chennai Central Store','SP-INF-1350','B.Braun Perfusor syringe clamp','infusion_pump',
     80,160000.00,'2026-06-28',0,'fast',420,null,0.00,0.00,'retain','healthy','Fastest-moving infusion spare across South stores'),
    ('Manipal Bengaluru Store','SP-LAB-1490','Sysmex XN-1000 sheath reagent valve','lab_analyzer',
     18,288000.00,'2025-07-08',12,'non_moving',7,'2026-12-31',45.00,129600.00,'discount_sell','provision_needed','XN-1000 partially replaced by XN-1500; slow burn')
  ) as q(store, sku, pname, fam, qty, val, lmd, msm, mc, lib, sle, ppct, pamt, dr, verdict, nt);

  -- CAPA seed — attach to specific SKUs by part_sku
  insert into public.spare_parts_obsolescence_capa_actions_r3329 (
    part_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SP-DIA-3120','slow_moving_provision','demand_forecast_error','book_provision',
     'in_progress','provision_increase','2026-08-15',null,150000.00,'Fresenius fleet down to 18 units; 50% provision booked'),
    ('SP-VEN-4088','dead_stock_liquidation','equipment_fleet_retired','return_to_oem_credit',
     'escalated','oem_credit_recovery','2026-08-05',null,472500.00,'Drager buyback quote awaited; escalated to CFO'),
    ('SP-LEG-5001','obsolete_stock_write_off','equipment_fleet_retired','scrap_and_dispose',
     'closed','pnl_write_down','2026-07-10','2026-07-05',96000.00,'CRT displays scrapped via e-waste vendor; write-off booked'),
    ('SP-PM-8027','dead_stock_liquidation','engineering_change_order','raise_write_down',
     'open','pnl_write_down','2026-08-20',null,306000.00,'T8 boards non-interchangeable; full write-down proposed'),
    ('SP-DIA-1077','expiry_imminent','shelf_life_lapse','donate_to_institution',
     'overdue','audit_qualification_risk','2026-06-30',null,135000.00,'Cartridges past expiry; donation paperwork overdue, audit flag'),
    ('SP-LAB-7011','oem_return_eligible','equipment_fleet_retired','return_to_oem_credit',
     'verification_pending','oem_credit_recovery','2026-08-12',null,105600.00,'Roche accepts c311 electrode return for credit; awaiting RMA'),
    ('SP-LEG-1230','installed_base_end_of_life','equipment_fleet_retired','raise_write_down',
     'open','provision_increase','2026-08-25',null,340000.00,'GE S/5 EOL; only 2 field units; 80% provision to write-down')
  ) as q(sku, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.spare_parts_obsolescence_r3329 e
    on e.organization_id = v_org_id and e.part_sku = q.sku;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Inventory verdict distribution
create or replace function public.founder_r3329_inventory_verdict_rollup()
returns table(inventory_verdict text, skus bigint, total_value_rupees numeric, total_provision_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spare_parts_obsolescence_r3329)
  select s.inventory_verdict, count(*)::bigint,
         coalesce(sum(s.on_hand_value_rupees),0)::numeric,
         coalesce(sum(s.provision_amount_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.spare_parts_obsolescence_r3329 s
  group by s.inventory_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3329_inventory_verdict_rollup() from public, anon;
grant execute on function public.founder_r3329_inventory_verdict_rollup() to authenticated;

-- 2) Store-level obsolescence scorecard
create or replace function public.founder_r3329_store_scorecard()
returns table(
  store_location text,
  total_skus bigint,
  healthy bigint,
  watch bigint,
  provision_needed bigint,
  write_down_now bigint,
  dispose bigint,
  total_value_rupees numeric,
  total_provision_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.store_location,
    count(*)::bigint,
    count(*) filter (where s.inventory_verdict = 'healthy')::bigint,
    count(*) filter (where s.inventory_verdict = 'watch')::bigint,
    count(*) filter (where s.inventory_verdict = 'provision_needed')::bigint,
    count(*) filter (where s.inventory_verdict = 'write_down_now')::bigint,
    count(*) filter (where s.inventory_verdict = 'dispose')::bigint,
    coalesce(sum(s.on_hand_value_rupees),0)::numeric,
    coalesce(sum(s.provision_amount_rupees),0)::numeric
  from public.spare_parts_obsolescence_r3329 s
  group by s.store_location
  order by coalesce(sum(s.provision_amount_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3329_store_scorecard() from public, anon;
grant execute on function public.founder_r3329_store_scorecard() to authenticated;

-- 3) Equipment family × movement class matrix
create or replace function public.founder_r3329_family_movement_matrix()
returns table(equipment_family text, movement_class text, skus bigint, total_value_rupees numeric, total_provision_rupees numeric, avg_months_since_movement numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.equipment_family, s.movement_class, count(*)::bigint,
    coalesce(sum(s.on_hand_value_rupees),0)::numeric,
    coalesce(sum(s.provision_amount_rupees),0)::numeric,
    round(avg(s.months_since_movement), 1)
  from public.spare_parts_obsolescence_r3329 s
  group by s.equipment_family, s.movement_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3329_family_movement_matrix() from public, anon;
grant execute on function public.founder_r3329_family_movement_matrix() to authenticated;

-- 4) Last-movement date trend
create or replace function public.founder_r3329_movement_date_trend()
returns table(last_movement_date date, skus bigint, total_value_rupees numeric, non_moving_skus bigint, dead_or_obsolete_skus bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.last_movement_date,
    count(*)::bigint,
    coalesce(sum(s.on_hand_value_rupees),0)::numeric,
    count(*) filter (where s.movement_class = 'non_moving')::bigint,
    count(*) filter (where s.movement_class in ('dead','obsolete'))::bigint
  from public.spare_parts_obsolescence_r3329 s
  group by s.last_movement_date
  order by s.last_movement_date desc;
end;
$$;

revoke execute on function public.founder_r3329_movement_date_trend() from public, anon;
grant execute on function public.founder_r3329_movement_date_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3329_capa_status_board()
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
  from public.spare_parts_obsolescence_capa_actions_r3329 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3329_capa_status_board() from public, anon;
grant execute on function public.founder_r3329_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3329_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.spare_parts_obsolescence_capa_actions_r3329)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.spare_parts_obsolescence_capa_actions_r3329 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3329_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3329_root_cause_pareto() to authenticated;

-- 7) Financial impact digest
create or replace function public.founder_r3329_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.spare_parts_obsolescence_capa_actions_r3329 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3329_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3329_financial_impact_digest() to authenticated;

-- 8) High-risk stock queue (top write-down / disposal concerns)
create or replace function public.founder_r3329_high_risk_stock_queue()
returns table(
  store_location text,
  part_sku text,
  part_name text,
  equipment_family text,
  on_hand_qty int,
  on_hand_value_rupees numeric,
  months_since_movement int,
  movement_class text,
  inventory_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.store_location, s.part_sku, s.part_name, s.equipment_family,
    s.on_hand_qty, s.on_hand_value_rupees, s.months_since_movement,
    s.movement_class, s.inventory_verdict, s.notes
  from public.spare_parts_obsolescence_r3329 s
  where s.inventory_verdict in ('provision_needed','write_down_now','dispose')
     or s.movement_class in ('non_moving','dead','obsolete')
  order by case s.inventory_verdict
             when 'dispose' then 0
             when 'write_down_now' then 1
             when 'provision_needed' then 2
             else 3
           end,
           s.on_hand_value_rupees desc;
end;
$$;

revoke execute on function public.founder_r3329_high_risk_stock_queue() from public, anon;
grant execute on function public.founder_r3329_high_risk_stock_queue() to authenticated;
