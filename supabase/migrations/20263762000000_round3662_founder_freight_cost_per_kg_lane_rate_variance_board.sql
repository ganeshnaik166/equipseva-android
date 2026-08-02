-- Round 3662: Founder Freight Cost-per-Kg / Lane-Rate Variance Board
-- Logistics finance — lane × carrier × mode × monthly cost-per-kg × contracted-rate variance × express share × fuel surcharge × leakage CAPA

-- =============================================================================
-- TABLE 1: freight_cost_r3662 — per-lane per-carrier monthly freight cost facts
-- =============================================================================
create table if not exists public.freight_cost_r3662 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  lane_ref text not null,
  lane_name text not null,
  carrier_name text not null,
  period_month date not null,
  shipments int not null,
  total_weight_kg numeric(12,2) not null,
  freight_spend_rupees numeric(14,2) not null,
  cost_per_kg_rupees numeric(10,2) not null,
  contracted_rate_rupees numeric(10,2) not null,
  rate_variance_pct numeric(6,2) not null,
  express_shipments_pct numeric(5,2),
  fuel_surcharge_pct numeric(5,2),
  mode text not null check (mode in (
    'air','surface_express','surface_ltl','rail','courier'
  )),
  cost_status text not null check (cost_status in (
    'under_contract','on_contract','above_contract','spot_heavy','leakage'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.freight_cost_r3662 enable row level security;

create index if not exists idx_freight_cost_r3662_org on public.freight_cost_r3662(organization_id);
create index if not exists idx_freight_cost_r3662_month on public.freight_cost_r3662(period_month);
create index if not exists idx_freight_cost_r3662_status on public.freight_cost_r3662(cost_status);

-- =============================================================================
-- TABLE 2: freight_cost_capa_actions_r3662 — freight-cost leakage CAPA actions
-- =============================================================================
create table if not exists public.freight_cost_capa_actions_r3662 (
  id uuid primary key default gen_random_uuid(),
  lane_record_id uuid not null references public.freight_cost_r3662(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'fuel_surcharge_creep','spot_booking_over_contract','carrier_rate_misapplied',
    'express_mode_overuse','volumetric_weight_billing','contract_rate_expired',
    'minimum_chargeable_weight','invoice_billing_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_lane_rate','enforce_contract_rate_in_tms','shift_mode_to_surface',
    'consolidate_shipments','carrier_invoice_audit_recovery','cap_express_approvals',
    'rebid_lane_rfq','update_fuel_surcharge_matrix','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  monthly_leakage_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.freight_cost_capa_actions_r3662 enable row level security;

create index if not exists idx_freight_capa_r3662_lane on public.freight_cost_capa_actions_r3662(lane_record_id);
create index if not exists idx_freight_capa_r3662_status on public.freight_cost_capa_actions_r3662(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Cost-status distribution
create or replace function public.founder_r3662_cost_status_rollup()
returns table(cost_status text, lanes bigint, total_spend_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.freight_cost_r3662)
  select l.cost_status, count(*)::bigint,
    coalesce(sum(l.freight_spend_rupees),0)::numeric,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.freight_cost_r3662 l
  group by l.cost_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3662_cost_status_rollup() from public, anon;
grant execute on function public.founder_r3662_cost_status_rollup() to authenticated;

-- 2) Carrier scorecard
create or replace function public.founder_r3662_carrier_scorecard()
returns table(
  carrier_name text,
  lanes bigint,
  total_shipments bigint,
  total_spend_rupees numeric,
  avg_cost_per_kg numeric,
  avg_rate_variance_pct numeric,
  leakage_lanes bigint,
  worsening_lanes bigint,
  on_or_under_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.carrier_name,
    count(*)::bigint,
    coalesce(sum(l.shipments),0)::bigint,
    coalesce(sum(l.freight_spend_rupees),0)::numeric,
    round(avg(l.cost_per_kg_rupees), 2),
    round(avg(l.rate_variance_pct), 2),
    count(*) filter (where l.cost_status in ('leakage','spot_heavy'))::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint,
    round(100.0 * count(*) filter (where l.cost_status in ('under_contract','on_contract'))::numeric / nullif(count(*),0), 1)
  from public.freight_cost_r3662 l
  group by l.carrier_name
  order by coalesce(sum(l.freight_spend_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3662_carrier_scorecard() from public, anon;
grant execute on function public.founder_r3662_carrier_scorecard() to authenticated;

-- 3) Mode × cost-status matrix
create or replace function public.founder_r3662_mode_cost_status_matrix()
returns table(mode text, cost_status text, lanes bigint, avg_cost_per_kg numeric, avg_rate_variance_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.mode, l.cost_status, count(*)::bigint,
    round(avg(l.cost_per_kg_rupees), 2),
    round(avg(l.rate_variance_pct), 2)
  from public.freight_cost_r3662 l
  group by l.mode, l.cost_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3662_mode_cost_status_matrix() from public, anon;
grant execute on function public.founder_r3662_mode_cost_status_matrix() to authenticated;

-- 4) Monthly cost-per-kg trend
create or replace function public.founder_r3662_monthly_cost_trend()
returns table(
  period_month date,
  lanes bigint,
  shipments bigint,
  total_weight_kg numeric,
  total_spend_rupees numeric,
  avg_cost_per_kg numeric,
  avg_rate_variance_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.shipments),0)::bigint,
    coalesce(sum(l.total_weight_kg),0)::numeric,
    coalesce(sum(l.freight_spend_rupees),0)::numeric,
    round(avg(l.cost_per_kg_rupees), 2),
    round(avg(l.rate_variance_pct), 2)
  from public.freight_cost_r3662 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3662_monthly_cost_trend() from public, anon;
grant execute on function public.founder_r3662_monthly_cost_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3662_capa_status_board()
returns table(capa_status text, actions bigint, total_monthly_leakage_rupees numeric, avg_monthly_leakage_rupees numeric, overdue_or_escalated bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.monthly_leakage_rupees),0)::numeric,
    round(avg(c.monthly_leakage_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.freight_cost_capa_actions_r3662 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3662_capa_status_board() from public, anon;
grant execute on function public.founder_r3662_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3662_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_leakage_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.freight_cost_capa_actions_r3662)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.monthly_leakage_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.freight_cost_capa_actions_r3662 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3662_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3662_root_cause_pareto() to authenticated;

-- 7) Rate-variance digest (by trend direction)
create or replace function public.founder_r3662_rate_variance_digest()
returns table(
  trend_dir text,
  lanes bigint,
  avg_rate_variance_pct numeric,
  max_rate_variance_pct numeric,
  total_spend_rupees numeric,
  above_contract_lanes bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir, count(*)::bigint,
    round(avg(l.rate_variance_pct), 2),
    max(l.rate_variance_pct)::numeric,
    coalesce(sum(l.freight_spend_rupees),0)::numeric,
    count(*) filter (where l.cost_status in ('above_contract','spot_heavy','leakage'))::bigint
  from public.freight_cost_r3662 l
  group by l.trend_dir
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3662_rate_variance_digest() from public, anon;
grant execute on function public.founder_r3662_rate_variance_digest() to authenticated;

-- 8) High-risk lane queue (leakage / spot-heavy / worsening)
create or replace function public.founder_r3662_high_risk_queue()
returns table(
  lane_ref text,
  lane_name text,
  carrier_name text,
  mode text,
  period_month date,
  cost_per_kg_rupees numeric,
  contracted_rate_rupees numeric,
  rate_variance_pct numeric,
  cost_status text,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lane_ref, l.lane_name, l.carrier_name, l.mode, l.period_month,
    l.cost_per_kg_rupees, l.contracted_rate_rupees, l.rate_variance_pct,
    l.cost_status, l.trend_dir, l.notes
  from public.freight_cost_r3662 l
  where l.cost_status in ('leakage','spot_heavy','above_contract')
     or l.trend_dir = 'worsening'
     or l.rate_variance_pct > 10.0
  order by l.rate_variance_pct desc, l.period_month desc;
end;
$$;

revoke all on function public.founder_r3662_high_risk_queue() from public, anon;
grant execute on function public.founder_r3662_high_risk_queue() to authenticated;

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

  -- 16 lane-month freight cost rows
  insert into public.freight_cost_r3662 (
    organization_id, lane_ref, lane_name, carrier_name, period_month,
    shipments, total_weight_kg, freight_spend_rupees, cost_per_kg_rupees,
    contracted_rate_rupees, rate_variance_pct, express_shipments_pct,
    fuel_surcharge_pct, mode, cost_status, trend_dir, notes
  )
  select v_org_id, q.lref, q.lname, q.cname, q.pmon::date,
    q.shp, q.twkg, q.spend, q.cpk,
    q.crate, q.rvar, q.expct,
    q.fsur, q.md, q.cst, q.tdir, q.nt
  from (values
    ('LN-MUMDEL-BD-2604','Mumbai-Delhi','Blue Dart Express','2026-04-01',
     142,18650,3168600,169.90,155.00,9.60,38.50,14.20,'air','above_contract','worsening','April fuel surcharge revision pushed air cost-per-kg above contracted slab'),
    ('LN-MUMDEL-BD-2605','Mumbai-Delhi','Blue Dart Express','2026-05-01',
     151,19480,3436300,176.40,155.00,13.80,44.00,15.50,'air','leakage','worsening','Express air share at 44 pct on Mumbai-Delhi — leakage vs contracted air rate'),
    ('LN-CHNBLR-TCI-2605','Chennai-Bengaluru','TCI Express','2026-05-01',
     96,24800,555500,22.40,23.00,-2.60,8.00,9.00,'surface_express','under_contract','improving','Consolidated twice-weekly milk run holding below contracted surface rate'),
    ('LN-CHNBLR-TCI-2606','Chennai-Bengaluru','TCI Express','2026-06-01',
     104,26350,603400,22.90,23.00,-0.40,9.50,9.40,'surface_express','on_contract','stable','Lane tracking on contract; diesel pass-through within band'),
    ('LN-DELHYD-DL-2606','Delhi-Hyderabad','Delhivery','2026-06-01',
     71,15200,483400,31.80,28.50,11.60,6.00,10.80,'surface_ltl','above_contract','worsening','Expired LTL slab applied on invoices — audit recovery raised'),
    ('LN-NHVPUN-VRL-2606','Nhava Sheva-Pune','VRL Logistics','2026-06-01',
     44,32600,476000,14.60,14.50,0.70,0.00,8.20,'surface_ltl','on_contract','stable','Import container de-stuffing haulage from Nhava Sheva CFS on contract'),
    ('LN-DELKOL-AI-2606','Delhi Air Cargo-Kolkata','Air India Cargo','2026-06-01',
     33,5450,862200,158.20,148.00,6.90,100.00,16.10,'air','above_contract','stable','Volumetric billing on low-density consumables inflating chargeable weight'),
    ('LN-MUMAMD-SFX-2605','Mumbai-Ahmedabad','Safexpress','2026-05-01',
     62,14100,279200,19.80,21.00,-5.70,4.00,8.80,'surface_express','under_contract','improving','Renegotiated April rate card delivering 5.7 pct under contract'),
    ('LN-BLRHYD-GK-2606','Bengaluru-Hyderabad','Gati KWE','2026-06-01',
     58,12750,336600,26.40,24.00,10.00,12.50,11.00,'surface_express','above_contract','worsening','Lane contract lapsed in May — carrier billing at spot card'),
    ('LN-PUNCHN-CCR-2606','Pune-Chennai','Concor Rail','2026-06-01',
     12,68400,670300,9.80,10.20,-3.90,0.00,6.50,'rail','under_contract','stable','Domestic container rail for bulky install kits under contracted rate'),
    ('LN-DELMUM-XB-2606','Delhi-Mumbai','XpressBees','2026-06-01',
     210,3150,291700,92.60,84.00,10.20,61.00,12.40,'courier','spot_heavy','worsening','Engineer spare-part couriers booked outside TMS at spot rates'),
    ('LN-CHNSPR-TVS-2605','Chennai Port-Sriperumbudur','TVS Supply Chain','2026-05-01',
     27,41200,531500,12.90,12.60,2.40,0.00,7.90,'surface_ltl','on_contract','stable','Port-to-plant FTL shuttle steady; detention charges controlled'),
    ('LN-MUMKOL-RV-2606','Mumbai-Kolkata','Rivigo','2026-06-01',
     49,16900,586400,34.70,29.50,17.60,18.00,13.60,'surface_express','leakage','worsening','Monsoon capacity crunch pushed spot share — 17.6 pct over contracted rate'),
    ('LN-DELCHD-SFX-2606','Delhi-Chandigarh','Safexpress','2026-06-01',
     38,8900,163800,18.40,18.20,1.10,2.50,8.50,'surface_ltl','on_contract','improving','Short-haul north lane stable after depot cut-off change'),
    ('LN-HYDVJA-GK-2606','Hyderabad-Vijayawada','Gati KWE','2026-06-01',
     26,6400,138900,21.70,19.80,9.60,5.00,10.20,'surface_ltl','above_contract','stable','Duplicate docket charges detected on Vijayawada deliveries'),
    ('LN-MUMDEL-DL-2606','Mumbai-Delhi','Delhivery','2026-06-01',
     88,21500,533200,24.80,25.50,-2.70,7.00,9.80,'surface_express','under_contract','improving','Air-to-surface mode-shift pilot lane running under contracted rate')
  ) as q(lref, lname, cname, pmon, shp, twkg, spend, cpk, crate, rvar, expct, fsur, md, cst, tdir, nt);

  -- CAPA seed — attach to specific lane records via lane_ref
  insert into public.freight_cost_capa_actions_r3662 (
    lane_record_id, root_cause, corrective_action, capa_status,
    monthly_leakage_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.leak, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('LN-MUMDEL-BD-2605','express_mode_overuse','shift_mode_to_surface','in_progress',486000.00,'Logistics Head - West','2026-07-15',null,'Air-to-surface mode-shift pilot live on Delhivery; track June exit run-rate'),
    ('LN-MUMKOL-RV-2606','spot_booking_over_contract','rebid_lane_rfq','open',88000.00,'Regional Logistics Manager - East','2026-07-20',null,'Monsoon capacity crunch pushed spot share; RFQ pack issued to four carriers'),
    ('LN-DELMUM-XB-2606','spot_booking_over_contract','cap_express_approvals','escalated',29500.00,'Service Parts Ops Lead','2026-07-10',null,'Spare-part couriers booked outside TMS; approval gate escalated to COO'),
    ('LN-DELHYD-DL-2606','carrier_rate_misapplied','carrier_invoice_audit_recovery','verification_pending',50200.00,'Freight Audit Analyst','2026-07-12',null,'Delhivery applied expired LTL slab; credit note under verification'),
    ('LN-MUMDEL-BD-2604','fuel_surcharge_creep','update_fuel_surcharge_matrix','closed',152000.00,'Logistics Head - West','2026-06-30','2026-06-24','FSC matrix re-pegged to IOCL diesel index via contract addendum'),
    ('LN-BLRHYD-GK-2606','contract_rate_expired','renegotiate_lane_rate','in_progress',34600.00,'Procurement Manager - Freight','2026-07-18',null,'Gati KWE lane contract lapsed in May; renegotiation at 24.5 per kg underway'),
    ('LN-DELKOL-AI-2606','volumetric_weight_billing','consolidate_shipments','open',41800.00,'Regional Logistics Manager - East','2026-07-25',null,'Volumetric billing on low-density consumables; consolidate to twice-weekly air'),
    ('LN-HYDVJA-GK-2606','invoice_billing_error','carrier_invoice_audit_recovery','overdue',12400.00,'Freight Audit Analyst','2026-06-28',null,'Duplicate docket charges on Vijayawada lane; recovery pending past target date')
  ) as q(lref, rc, ca, cst, leak, ownr, tcd, acd, nt)
  join public.freight_cost_r3662 e
    on e.organization_id = v_org_id and e.lane_ref = q.lref;
end;
$seed$;
