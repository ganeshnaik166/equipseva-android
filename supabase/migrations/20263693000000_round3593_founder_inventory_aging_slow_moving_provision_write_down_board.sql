-- Round 3593: Founder Inventory-Aging / Slow-Moving Provision & Write-Down Board
-- Inventory aging QA — item category × warehouse × period × aging bucket × provision status × NRV write-down × trend × CAPA

-- =============================================================================
-- TABLE 1: inventory_aging_r3593 — per-SKU aging & provision fact rows
-- =============================================================================
create table if not exists public.inventory_aging_r3593 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  item_code text not null,
  item_name text not null,
  item_category text not null,
  warehouse text not null,
  period_month date not null,
  stock_value_rupees numeric(14,2) not null,
  qty_on_hand int not null,
  days_since_last_movement int not null,
  provision_pct numeric(5,2) not null,
  provision_rupees numeric(14,2) not null,
  net_realizable_value_rupees numeric(14,2) not null,
  aging_bucket text not null check (aging_bucket in (
    '0_90_days','91_180_days','181_365_days','over_365_days'
  )),
  provision_status text not null check (provision_status in (
    'healthy','watch','slow_moving','obsolete','write_off'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inventory_aging_r3593 enable row level security;

create index if not exists idx_inventory_aging_r3593_org on public.inventory_aging_r3593(organization_id);
create index if not exists idx_inventory_aging_r3593_period on public.inventory_aging_r3593(period_month);
create index if not exists idx_inventory_aging_r3593_status on public.inventory_aging_r3593(provision_status);

-- =============================================================================
-- TABLE 2: inventory_aging_capa_actions_r3593 — CAPA & disposition actions
-- =============================================================================
create table if not exists public.inventory_aging_capa_actions_r3593 (
  id uuid primary key default gen_random_uuid(),
  aging_id uuid not null references public.inventory_aging_r3593(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excess_stock','obsolete_inventory','slow_moving_sku','nrv_below_cost',
    'expiry_risk','provision_shortfall','dead_stock','overstock_seasonal'
  )),
  root_cause text not null check (root_cause in (
    'over_procurement','demand_forecast_error','discontinued_product','supplier_moq_excess',
    'pricing_erosion','shelf_life_expiry','project_cancellation','spare_part_superseded',
    'pending_investigation','warehouse_transfer_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'liquidation_sale','return_to_supplier','write_off_provision','repurpose_internal',
    'scrap_disposal','price_markdown','bundle_promotion','transfer_to_demand_site',
    'none_required','vendor_buyback'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inventory_aging_capa_actions_r3593 enable row level security;

create index if not exists idx_inventory_aging_capa_r3593_link on public.inventory_aging_capa_actions_r3593(aging_id);
create index if not exists idx_inventory_aging_capa_r3593_status on public.inventory_aging_capa_actions_r3593(capa_status);

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

  -- 16 inventory aging rows
  insert into public.inventory_aging_r3593 (
    organization_id, item_code, item_name, item_category, warehouse, period_month,
    stock_value_rupees, qty_on_hand, days_since_last_movement, provision_pct, provision_rupees,
    net_realizable_value_rupees, aging_bucket, provision_status, trend_dir, notes
  )
  select v_org_id, q.icode, q.iname, q.icat, q.whse, q.pmon::date,
    q.sval, q.qty, q.dslm, q.ppct, q.prup,
    q.nrv, q.abkt, q.pstat, q.tdir, q.nt
  from (values
    ('CONS-DEF-001','Defibrillator Pads Adult','consumables','Chennai Central WH','2026-07-01',
     120000.00,240,45,0.00,0.00,120000.00,'0_90_days','healthy','stable','Fast-moving defib pads, healthy turns'),
    ('SPR-ECG-014','ECG Lead Cable Set','spare_parts','Delhi NCR WH','2026-07-01',
     340000.00,85,120,15.00,51000.00,289000.00,'91_180_days','watch','stable','ECG lead cables aging into watch bucket'),
    ('DIAG-GLU-022','Glucometer Strips Lot','consumables','Mumbai West WH','2026-07-01',
     210000.00,1500,210,40.00,84000.00,126000.00,'181_365_days','slow_moving','worsening','Near-expiry glucometer strips, slow moving'),
    ('MON-SPO2-033','SpO2 Finger Sensors','patient_monitoring','Bengaluru South WH','2026-07-01',
     175000.00,60,95,10.00,17500.00,157500.00,'91_180_days','watch','improving','SpO2 sensors moving after promo'),
    ('IMG-USG-041','Ultrasound Probe Covers','imaging_accessories','Hyderabad WH','2026-07-01',
     95000.00,800,400,60.00,57000.00,38000.00,'over_365_days','obsolete','worsening','Superseded probe model covers, obsolete'),
    ('SURG-BLD-052','Surgical Blade Assortment','surgical_instruments','Chennai Central WH','2026-06-01',
     68000.00,340,30,0.00,0.00,68000.00,'0_90_days','healthy','stable','Surgical blades healthy stock'),
    ('SPR-VNT-061','Ventilator Flow Sensor','spare_parts','Delhi NCR WH','2026-06-01',
     480000.00,24,500,90.00,432000.00,48000.00,'over_365_days','write_off','worsening','Discontinued ventilator model spare, write-off'),
    ('DIAG-XRY-072','X-Ray Film Cassettes','imaging_accessories','Mumbai West WH','2026-06-01',
     130000.00,45,320,50.00,65000.00,65000.00,'181_365_days','slow_moving','stable','Analog X-ray cassettes, digital shift slow moving'),
    ('MON-BP-083','NIBP Cuff Adult Reusable','patient_monitoring','Bengaluru South WH','2026-06-01',
     88000.00,220,60,0.00,0.00,88000.00,'0_90_days','healthy','improving','NIBP cuffs healthy demand'),
    ('CONS-SUT-094','Absorbable Sutures Box','consumables','Hyderabad WH','2026-06-01',
     156000.00,400,175,20.00,31200.00,124800.00,'91_180_days','watch','stable','Sutures aging, monitor expiry'),
    ('SPR-CTG-105','CT Gantry Slip Ring','spare_parts','Kolkata East WH','2026-05-01',
     920000.00,3,600,75.00,690000.00,230000.00,'over_365_days','obsolete','worsening','Legacy CT slip ring, obsolete high value'),
    ('SURG-LAP-116','Laparoscopy Trocar Set','surgical_instruments','Delhi NCR WH','2026-05-01',
     265000.00,40,140,25.00,66250.00,198750.00,'91_180_days','slow_moving','worsening','Trocar sets slow after new vendor'),
    ('DIAG-HEM-127','Hematology Reagent Kit','consumables','Chennai Central WH','2026-05-01',
     198000.00,120,260,55.00,108900.00,89100.00,'181_365_days','slow_moving','worsening','Reagent kit near expiry, slow moving'),
    ('IMG-MRI-138','MRI Coil Cushions','imaging_accessories','Bengaluru South WH','2026-05-01',
     74000.00,150,90,5.00,3700.00,70300.00,'0_90_days','watch','improving','MRI cushions minor provision'),
    ('MON-TEL-149','Telemetry Battery Pack','patient_monitoring','Hyderabad WH','2026-05-01',
     305000.00,90,380,65.00,198250.00,106750.00,'over_365_days','write_off','worsening','Obsolete telemetry batteries, write-off candidate'),
    ('SPR-INF-150','Infusion Pump Valve Kit','spare_parts','Mumbai West WH','2026-07-01',
     142000.00,200,110,12.00,17040.00,124960.00,'91_180_days','watch','stable','Infusion pump valves aging watch')
  ) as q(icode, iname, icat, whse, pmon, sval, qty, dslm, ppct, prup, nrv, abkt, pstat, tdir, nt);

  -- CAPA seed — attach to specific SKUs via item_code
  insert into public.inventory_aging_capa_actions_r3593 (
    aging_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('IMG-USG-041','obsolete_inventory','spare_part_superseded','write_off_provision','in_progress',57000.00,'Ravi Menon','2026-08-15',null,'Superseded probe covers, provision booked, disposal pending'),
    ('SPR-VNT-061','dead_stock','discontinued_product','scrap_disposal','open',432000.00,'Anita Desai','2026-08-30',null,'Discontinued ventilator spare, scrap approval sought'),
    ('IMG-MRI-138','provision_shortfall','pricing_erosion','price_markdown','closed',3700.00,'Suresh Iyer','2026-07-20','2026-07-18','Markdown applied, cushions cleared'),
    ('SPR-CTG-105','obsolete_inventory','spare_part_superseded','vendor_buyback','escalated',690000.00,'Priya Nair','2026-08-10',null,'High-value CT slip ring, negotiating vendor buyback'),
    ('MON-TEL-149','dead_stock','shelf_life_expiry','scrap_disposal','overdue',198250.00,'Vikram Rao','2026-07-10',null,'Telemetry batteries expired, disposal overdue'),
    ('DIAG-GLU-022','expiry_risk','over_procurement','liquidation_sale','in_progress',84000.00,'Meera Krishnan','2026-08-05',null,'Near-expiry strips, liquidation to clinics'),
    ('DIAG-HEM-127','slow_moving_sku','demand_forecast_error','price_markdown','verification_pending',108900.00,'Arjun Pillai','2026-08-12',null,'Reagent kits marked down, verify offtake'),
    ('DIAG-XRY-072','obsolete_inventory','pricing_erosion','return_to_supplier','open',65000.00,'Kavya Reddy','2026-08-20',null,'Analog cassettes, return-to-supplier requested')
  ) as q(icode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.inventory_aging_r3593 e
    on e.organization_id = v_org_id and e.item_code = q.icode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Provision status distribution
create or replace function public.founder_r3593_provision_status_rollup()
returns table(provision_status text, items bigint, stock_value_rupees numeric, provision_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inventory_aging_r3593)
  select l.provision_status, count(*)::bigint,
         coalesce(sum(l.stock_value_rupees),0)::numeric,
         coalesce(sum(l.provision_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.inventory_aging_r3593 l
  group by l.provision_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3593_provision_status_rollup() from public, anon;
grant execute on function public.founder_r3593_provision_status_rollup() to authenticated;

-- 2) Item-category scorecard
create or replace function public.founder_r3593_item_category_scorecard()
returns table(
  item_category text,
  total_items bigint,
  stock_value_rupees numeric,
  provision_rupees numeric,
  net_realizable_value_rupees numeric,
  obsolete_items bigint,
  write_off_items bigint,
  provision_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.item_category,
    count(*)::bigint,
    coalesce(sum(l.stock_value_rupees),0)::numeric,
    coalesce(sum(l.provision_rupees),0)::numeric,
    coalesce(sum(l.net_realizable_value_rupees),0)::numeric,
    count(*) filter (where l.provision_status = 'obsolete')::bigint,
    count(*) filter (where l.provision_status = 'write_off')::bigint,
    round(100.0 * coalesce(sum(l.provision_rupees),0) / nullif(sum(l.stock_value_rupees),0), 1)
  from public.inventory_aging_r3593 l
  group by l.item_category
  order by coalesce(sum(l.provision_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3593_item_category_scorecard() from public, anon;
grant execute on function public.founder_r3593_item_category_scorecard() to authenticated;

-- 3) Aging-bucket × provision-status matrix
create or replace function public.founder_r3593_aging_bucket_status_matrix()
returns table(aging_bucket text, provision_status text, items bigint, stock_value_rupees numeric, provision_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.aging_bucket, l.provision_status, count(*)::bigint,
    coalesce(sum(l.stock_value_rupees),0)::numeric,
    coalesce(sum(l.provision_rupees),0)::numeric
  from public.inventory_aging_r3593 l
  group by l.aging_bucket, l.provision_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3593_aging_bucket_status_matrix() from public, anon;
grant execute on function public.founder_r3593_aging_bucket_status_matrix() to authenticated;

-- 4) Monthly provision trend
create or replace function public.founder_r3593_monthly_provision_trend()
returns table(period_month date, items bigint, stock_value_rupees numeric, provision_rupees numeric, net_realizable_value_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.stock_value_rupees),0)::numeric,
    coalesce(sum(l.provision_rupees),0)::numeric,
    coalesce(sum(l.net_realizable_value_rupees),0)::numeric
  from public.inventory_aging_r3593 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3593_monthly_provision_trend() from public, anon;
grant execute on function public.founder_r3593_monthly_provision_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3593_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.financial_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.inventory_aging_capa_actions_r3593 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3593_capa_status_board() from public, anon;
grant execute on function public.founder_r3593_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3593_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inventory_aging_capa_actions_r3593)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.inventory_aging_capa_actions_r3593 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3593_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3593_root_cause_pareto() to authenticated;

-- 7) Provision-impact digest by warehouse
create or replace function public.founder_r3593_provision_impact_digest()
returns table(
  warehouse text,
  items bigint,
  stock_value_rupees numeric,
  provision_rupees numeric,
  net_realizable_value_rupees numeric,
  provision_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.warehouse, count(*)::bigint,
    coalesce(sum(l.stock_value_rupees),0)::numeric,
    coalesce(sum(l.provision_rupees),0)::numeric,
    coalesce(sum(l.net_realizable_value_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.provision_rupees),0) / nullif(sum(l.stock_value_rupees),0), 1)
  from public.inventory_aging_r3593 l
  group by l.warehouse
  order by coalesce(sum(l.provision_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3593_provision_impact_digest() from public, anon;
grant execute on function public.founder_r3593_provision_impact_digest() to authenticated;

-- 8) High-risk (obsolete/write-off) queue
create or replace function public.founder_r3593_high_risk_queue()
returns table(
  item_code text,
  item_name text,
  item_category text,
  warehouse text,
  period_month date,
  aging_bucket text,
  provision_status text,
  provision_pct numeric,
  provision_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.item_code, l.item_name, l.item_category, l.warehouse, l.period_month,
    l.aging_bucket, l.provision_status, l.provision_pct, l.provision_rupees, l.notes
  from public.inventory_aging_r3593 l
  where l.provision_status in ('obsolete','write_off','slow_moving')
     or l.aging_bucket = 'over_365_days'
     or l.trend_dir = 'worsening'
  order by l.provision_rupees desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3593_high_risk_queue() from public, anon;
grant execute on function public.founder_r3593_high_risk_queue() to authenticated;
