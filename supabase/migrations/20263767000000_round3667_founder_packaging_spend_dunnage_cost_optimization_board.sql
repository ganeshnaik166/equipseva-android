-- Round 3667: Founder Packaging-Spend / Dunnage Cost-Optimization Board
-- Packaging & dunnage spend — packaging type × supplier × month × cost-per-shipment × target variance × reuse × damage linkage × eco-material share × CAPA

-- =============================================================================
-- TABLE 1: packaging_spend_r3667 — per-packaging-line monthly spend records
-- =============================================================================
create table if not exists public.packaging_spend_r3667 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  pack_code text not null,
  packaging_type text not null,
  supplier_name text not null,
  period_month date not null,
  shipments_packed int not null,
  packaging_spend_rupees numeric(12,2),
  cost_per_shipment_rupees numeric(10,2),
  target_cost_rupees numeric(10,2),
  variance_pct numeric(6,2),
  reuse_pct numeric(5,2),
  damage_incidents_linked int,
  weight_added_kg numeric(6,2),
  eco_material_pct numeric(5,2),
  pack_category text not null check (pack_category in (
    'wooden_crate','corrugated_box','foam_insert','thermocol','pallet_wrap','custom_case'
  )),
  spend_status text not null check (spend_status in (
    'optimized','on_target','elevated','wasteful','damage_prone'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.packaging_spend_r3667 enable row level security;

create index if not exists idx_packaging_spend_r3667_org on public.packaging_spend_r3667(organization_id);
create index if not exists idx_packaging_spend_r3667_month on public.packaging_spend_r3667(period_month);
create index if not exists idx_packaging_spend_r3667_status on public.packaging_spend_r3667(spend_status);

-- =============================================================================
-- TABLE 2: packaging_spend_capa_actions_r3667 — cost-optimization CAPA actions
-- =============================================================================
create table if not exists public.packaging_spend_capa_actions_r3667 (
  id uuid primary key default gen_random_uuid(),
  spend_row_id uuid not null references public.packaging_spend_r3667(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'over_specified_packaging','single_use_material','supplier_price_hike','no_reuse_loop',
    'wrong_pack_category','manual_pack_process','freight_damage_feedback_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'switch_to_reusable_crate','renegotiate_supplier_rate','right_size_packaging','introduce_reuse_loop',
    'standardize_pack_spec','switch_supplier','add_cushioning_upgrade','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  savings_potential_rupees numeric(12,2),
  action_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.packaging_spend_capa_actions_r3667 enable row level security;

create index if not exists idx_packaging_spend_capa_r3667_row on public.packaging_spend_capa_actions_r3667(spend_row_id);
create index if not exists idx_packaging_spend_capa_r3667_status on public.packaging_spend_capa_actions_r3667(capa_status);

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

  -- 16 packaging spend rows
  insert into public.packaging_spend_r3667 (
    organization_id, pack_code, packaging_type, supplier_name, period_month,
    shipments_packed, packaging_spend_rupees, cost_per_shipment_rupees, target_cost_rupees,
    variance_pct, reuse_pct, damage_incidents_linked, weight_added_kg, eco_material_pct,
    pack_category, spend_status, trend_dir, notes
  )
  select v_org_id, q.pcode, q.ptype, q.supp, q.pmon::date,
    q.shp, q.spend, q.cps, q.tgt,
    q.varp, q.reup, q.dmg, q.wkg, q.ecop,
    q.pcat, q.sst, q.trd, q.nt
  from (values
    ('PKG-WC-PUN-0726','Export wooden crate 1200x800','Bharat Crates Bhiwandi','2026-07-01',
     42,378000,9000,7500,20.0,35.0,1,18.5,10.0,'wooden_crate','elevated','worsening','Mumbai-Pune export crates over target after timber surcharge'),
    ('PKG-CB-DEL-0726','5-ply corrugated master carton','DS Smith India Greater Noida','2026-07-01',
     310,201500,650,700,-7.1,0.0,2,1.2,68.0,'corrugated_box','optimized','improving','Delhi NCR carton rate renegotiated - running under target'),
    ('PKG-FI-BLR-0726','Die-cut foam insert - patient monitors','Supack Industries Pune','2026-07-01',
     120,144000,1200,1000,20.0,0.0,0,0.8,12.0,'foam_insert','elevated','stable','Foam insert over-specified for Bengaluru monitor SKUs'),
    ('PKG-TH-CHN-0726','Thermocol moulded set - infusion pumps','EcoPack Chennai','2026-07-01',
     95,47500,500,450,11.1,0.0,4,0.6,0.0,'thermocol','damage_prone','worsening','Thermocol cracking on Chennai-Madurai lane - 4 damage incidents linked'),
    ('PKG-PW-HYD-0726','Stretch pallet wrap rolls','Uflex Noida','2026-07-01',
     180,36000,200,220,-9.1,0.0,0,0.4,25.0,'pallet_wrap','optimized','stable','Hyderabad DC pallet wrap consumption per shipment trending down'),
    ('PKG-CC-MUM-0726','Custom flight case - C-arm accessories','Nefab India Chakan','2026-07-01',
     8,96000,12000,10000,20.0,80.0,0,22.0,15.0,'custom_case','elevated','improving','Flight-case pool for Mumbai C-arm kits - reuse loop maturing'),
    ('PKG-WC-AHM-0726','Domestic wooden crate - CT tables','Bharat Crates Bhiwandi','2026-07-01',
     15,157500,10500,8000,31.3,20.0,2,20.0,5.0,'wooden_crate','wasteful','worsening','Ahmedabad CT-table crates heavily over-built for domestic lane'),
    ('PKG-CB-KOL-0726','3-ply corrugated inner box','Packman Industries Kolkata','2026-07-01',
     260,91000,350,340,2.9,0.0,1,0.5,55.0,'corrugated_box','on_target','stable','Kolkata inner boxes holding at target rate'),
    ('PKG-FI-PUN-0626','EPE foam insert - ventilator spares','Supack Industries Pune','2026-06-01',
     110,99000,900,950,-5.3,0.0,0,0.7,20.0,'foam_insert','on_target','improving','Ventilator spare inserts right-sized in June revision'),
    ('PKG-TH-CHN-0626','Thermocol moulded set - infusion pumps','EcoPack Chennai','2026-06-01',
     90,40500,450,450,0.0,0.0,2,0.6,0.0,'thermocol','on_target','stable','June baseline before Chennai lane damage spike'),
    ('PKG-WC-PUN-0626','Export wooden crate 1200x800','Bharat Crates Bhiwandi','2026-06-01',
     40,340000,8500,7500,13.3,35.0,1,18.5,10.0,'wooden_crate','elevated','worsening','Export crate cost creeping up - timber index rising'),
    ('PKG-PW-HYD-0626','Stretch pallet wrap rolls','Uflex Noida','2026-06-01',
     175,38500,220,220,0.0,0.0,0,0.4,25.0,'pallet_wrap','on_target','stable','Pallet wrap at target across Hyderabad DC in June'),
    ('PKG-CC-DEL-0626','Custom case - cath-lab probe kits','Nefab India Chakan','2026-06-01',
     6,84000,14000,11000,27.3,75.0,1,24.0,15.0,'custom_case','wasteful','stable','Probe-kit custom cases far over target - reusable pool proposed'),
    ('PKG-CB-DEL-0626','5-ply corrugated master carton','DS Smith India Greater Noida','2026-06-01',
     295,221250,750,700,7.1,0.0,3,1.2,68.0,'corrugated_box','elevated','improving','June cartons pre-renegotiation with 3 damage incidents on Delhi-Jaipur leg'),
    ('PKG-FI-MUM-0726','Anti-static foam - PCB service parts','Supack Industries Pune','2026-07-01',
     60,90000,1500,1400,7.1,0.0,0,0.3,8.0,'foam_insert','on_target','stable','ESD foam for field-service PCB shipments within tolerance'),
    ('PKG-TH-JAI-0726','Thermocol box - reagent cold chain','EcoPack Chennai','2026-07-01',
     48,33600,700,600,16.7,0.0,3,0.9,0.0,'thermocol','damage_prone','worsening','Jaipur reagent cold-chain boxes crushing in transit - repeat damage')
  ) as q(pcode, ptype, supp, pmon, shp, spend, cps, tgt, varp, reup, dmg, wkg, ecop, pcat, sst, trd, nt);

  -- CAPA seed — attach to specific spend rows via pack_code
  insert into public.packaging_spend_capa_actions_r3667 (
    spend_row_id, root_cause, corrective_action, capa_status,
    savings_potential_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.sav, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PKG-WC-AHM-0726','over_specified_packaging','right_size_packaging','in_progress',45000,'Ravi Deshmukh','2026-08-10',null,'CT-table crate spec being downsized for domestic lanes'),
    ('PKG-TH-CHN-0726','single_use_material','add_cushioning_upgrade','open',22000,'Meena Iyer','2026-08-05',null,'Corner cushioning upgrade to stop Chennai-Madurai crush damage'),
    ('PKG-WC-PUN-0726','supplier_price_hike','renegotiate_supplier_rate','escalated',60000,'Arjun Nair','2026-07-28',null,'Timber surcharge dispute escalated to procurement head'),
    ('PKG-CC-DEL-0626','wrong_pack_category','switch_to_reusable_crate','verification_pending',52000,'Sunita Rao','2026-07-25',null,'Probe kits moving to reusable crate pool - pilot completed'),
    ('PKG-FI-BLR-0726','over_specified_packaging','standardize_pack_spec','open',30000,'Ravi Deshmukh','2026-08-12',null,'Foam insert spec standardization across monitor SKUs'),
    ('PKG-TH-JAI-0726','freight_damage_feedback_gap','right_size_packaging','overdue',18000,'Meena Iyer','2026-07-20',null,'Reagent cold-chain box redesign past target - vendor sample delay'),
    ('PKG-CB-DEL-0626','no_reuse_loop','introduce_reuse_loop','closed',26000,'Arjun Nair','2026-07-10','2026-07-08','Carton reuse loop live on Delhi NCR return legs'),
    ('PKG-CC-MUM-0726','manual_pack_process','standardize_pack_spec','in_progress',15000,'Sunita Rao','2026-08-15',null,'Flight-case packing SOP standardization underway')
  ) as q(pcode, rc, ca, cst, sav, own, tcd, acd, nt)
  join public.packaging_spend_r3667 e
    on e.organization_id = v_org_id and e.pack_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Spend status distribution
create or replace function public.founder_r3667_spend_status_rollup()
returns table(spend_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.packaging_spend_r3667)
  select l.spend_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.packaging_spend_r3667 l
  group by l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3667_spend_status_rollup() from public, anon;
grant execute on function public.founder_r3667_spend_status_rollup() to authenticated;

-- 2) Supplier packaging scorecard
create or replace function public.founder_r3667_supplier_scorecard()
returns table(
  supplier_name text,
  records bigint,
  optimized bigint,
  on_target bigint,
  elevated bigint,
  wasteful_or_damage bigint,
  total_spend_rupees numeric,
  avg_cost_per_shipment numeric,
  avg_variance_pct numeric
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
    count(*) filter (where l.spend_status = 'optimized')::bigint,
    count(*) filter (where l.spend_status = 'on_target')::bigint,
    count(*) filter (where l.spend_status = 'elevated')::bigint,
    count(*) filter (where l.spend_status in ('wasteful','damage_prone'))::bigint,
    coalesce(sum(l.packaging_spend_rupees),0)::numeric,
    round(avg(l.cost_per_shipment_rupees), 0),
    round(avg(l.variance_pct), 1)
  from public.packaging_spend_r3667 l
  group by l.supplier_name
  order by coalesce(sum(l.packaging_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3667_supplier_scorecard() from public, anon;
grant execute on function public.founder_r3667_supplier_scorecard() to authenticated;

-- 3) Pack-category × spend-status matrix
create or replace function public.founder_r3667_category_status_matrix()
returns table(pack_category text, spend_status text, records bigint, total_spend_rupees numeric, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pack_category, l.spend_status, count(*)::bigint,
    coalesce(sum(l.packaging_spend_rupees),0)::numeric,
    round(avg(l.variance_pct), 1)
  from public.packaging_spend_r3667 l
  group by l.pack_category, l.spend_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3667_category_status_matrix() from public, anon;
grant execute on function public.founder_r3667_category_status_matrix() to authenticated;

-- 4) Monthly packaging spend trend
create or replace function public.founder_r3667_monthly_spend_trend()
returns table(period_month date, records bigint, shipments bigint, total_spend_rupees numeric, avg_cost_per_shipment numeric, damage_incidents bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.shipments_packed),0)::bigint,
    coalesce(sum(l.packaging_spend_rupees),0)::numeric,
    round(avg(l.cost_per_shipment_rupees), 0),
    coalesce(sum(l.damage_incidents_linked),0)::bigint
  from public.packaging_spend_r3667 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3667_monthly_spend_trend() from public, anon;
grant execute on function public.founder_r3667_monthly_spend_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3667_capa_status_board()
returns table(capa_status text, actions bigint, avg_savings_potential_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.savings_potential_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.packaging_spend_capa_actions_r3667 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3667_capa_status_board() from public, anon;
grant execute on function public.founder_r3667_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3667_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_savings_potential_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.packaging_spend_capa_actions_r3667)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.savings_potential_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.packaging_spend_capa_actions_r3667 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3667_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3667_root_cause_pareto() to authenticated;

-- 7) Cost-variance digest by packaging type
create or replace function public.founder_r3667_cost_variance_digest()
returns table(packaging_type text, records bigint, avg_variance_pct numeric, max_variance_pct numeric, total_spend_rupees numeric, excess_spend_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.packaging_type, count(*)::bigint,
    round(avg(l.variance_pct), 1),
    max(l.variance_pct)::numeric,
    coalesce(sum(l.packaging_spend_rupees),0)::numeric,
    coalesce(sum(greatest(l.cost_per_shipment_rupees - l.target_cost_rupees, 0) * l.shipments_packed),0)::numeric
  from public.packaging_spend_r3667 l
  group by l.packaging_type
  order by coalesce(sum(greatest(l.cost_per_shipment_rupees - l.target_cost_rupees, 0) * l.shipments_packed),0) desc;
end;
$$;

revoke all on function public.founder_r3667_cost_variance_digest() from public, anon;
grant execute on function public.founder_r3667_cost_variance_digest() to authenticated;

-- 8) High-risk packaging queue (wasteful / damage-prone / worsening)
create or replace function public.founder_r3667_high_risk_queue()
returns table(
  pack_code text,
  packaging_type text,
  supplier_name text,
  pack_category text,
  period_month date,
  spend_status text,
  variance_pct numeric,
  damage_incidents_linked int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pack_code, l.packaging_type, l.supplier_name, l.pack_category, l.period_month,
    l.spend_status, l.variance_pct, l.damage_incidents_linked, l.trend_dir, l.notes
  from public.packaging_spend_r3667 l
  where l.spend_status in ('wasteful','damage_prone')
     or l.trend_dir = 'worsening'
     or l.variance_pct > 15
     or l.damage_incidents_linked >= 3
  order by l.period_month desc, l.variance_pct desc;
end;
$$;

revoke all on function public.founder_r3667_high_risk_queue() from public, anon;
grant execute on function public.founder_r3667_high_risk_queue() to authenticated;
