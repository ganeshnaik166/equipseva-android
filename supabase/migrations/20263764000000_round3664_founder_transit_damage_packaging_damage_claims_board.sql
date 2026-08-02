-- Round 3664: Transit-Damage / Packaging-Damage Claims Board
-- Logistics claims QA — incident × lane × carrier × damage category × claim status × recovery % × days-to-settle × trend × CAPA

-- =============================================================================
-- TABLE 1: transit_damage_r3664 — per-incident transit/packaging damage claims
-- =============================================================================
create table if not exists public.transit_damage_r3664 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  incident_ref text not null,
  lane_name text not null,
  carrier_name text not null,
  period_month date not null,
  shipment_value_rupees numeric(14,2) not null,
  damage_value_rupees numeric(14,2) not null,
  damage_pct numeric(5,2) not null,
  claim_filed boolean not null,
  claim_amount_rupees numeric(14,2),
  claim_recovered_rupees numeric(14,2),
  recovery_pct numeric(5,2),
  days_to_settle int,
  damage_category text not null check (damage_category in (
    'physical_impact','moisture_ingress','temperature_excursion','mishandling','packaging_failure'
  )),
  claim_status text not null check (claim_status in (
    'recovered','partially_recovered','under_process','rejected','not_filed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.transit_damage_r3664 enable row level security;

create index if not exists idx_transit_damage_r3664_org on public.transit_damage_r3664(organization_id);
create index if not exists idx_transit_damage_r3664_month on public.transit_damage_r3664(period_month);
create index if not exists idx_transit_damage_r3664_status on public.transit_damage_r3664(claim_status);

-- =============================================================================
-- TABLE 2: transit_damage_capa_actions_r3664 — CAPA & claims-process actions
-- =============================================================================
create table if not exists public.transit_damage_capa_actions_r3664 (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.transit_damage_r3664(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'inadequate_cushioning','carrier_rough_handling','reefer_equipment_failure',
    'monsoon_exposure','pallet_stacking_error','labeling_gap_fragile',
    'claim_documentation_lapse','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'redesign_packaging_spec','switch_carrier_on_lane','add_impact_moisture_indicators',
    'enforce_reefer_telemetry','retrain_warehouse_loaders','tighten_claim_sop_timelines',
    'negotiate_carrier_sla_penalty','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_at_risk_rupees numeric(12,2),
  action_owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.transit_damage_capa_actions_r3664 enable row level security;

create index if not exists idx_transit_damage_capa_r3664_incident on public.transit_damage_capa_actions_r3664(incident_id);
create index if not exists idx_transit_damage_capa_r3664_status on public.transit_damage_capa_actions_r3664(capa_status);

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

  -- 16 damage incident rows
  insert into public.transit_damage_r3664 (
    organization_id, incident_ref, lane_name, carrier_name, period_month,
    shipment_value_rupees, damage_value_rupees, damage_pct, claim_filed,
    claim_amount_rupees, claim_recovered_rupees, recovery_pct, days_to_settle,
    damage_category, claim_status, trend_dir, notes
  )
  select v_org_id, q.iref, q.lane, q.carr, q.pmon::date,
    q.shipval, q.dmgval, q.dmgp, q.cfiled,
    q.clamt, q.crec, q.recp, q.dsettle,
    q.dcat, q.cstat, q.tdir, q.nt
  from (values
    ('TD-2026-001','Mumbai-Delhi','BlueDart Surface','2026-04-01',
     1850000.00,92500.00,5.00,true,90000.00,88500.00,98.3,34,
     'physical_impact','recovered','improving','Crate impact at Bhiwandi hub — near-full recovery from carrier insurance'),
    ('TD-2026-002','Chennai-Bengaluru','TCI Express','2026-04-01',
     920000.00,36800.00,4.00,true,36800.00,20200.00,54.9,52,
     'packaging_failure','partially_recovered','stable','Corner crush on monitor cartons — carrier disputed packaging spec'),
    ('TD-2026-003','Nhava Sheva-Ahmedabad','VRL Logistics','2026-04-01',
     2400000.00,168000.00,7.00,true,165000.00,0.00,0.0,61,
     'moisture_ingress','rejected','worsening','Monsoon tarpaulin failure at port yard — claim rejected citing packaging clause'),
    ('TD-2026-004','Delhi Air Cargo-Lucknow','Delhivery Freight','2026-05-01',
     760000.00,15200.00,2.00,false,null,null,null,null,
     'mishandling','not_filed','stable','Minor scuffs below deductible — claim not filed'),
    ('TD-2026-005','Kolkata-Guwahati','Gati-KWE','2026-05-01',
     1320000.00,105600.00,8.00,true,102000.00,null,null,null,
     'physical_impact','under_process','worsening','Forklift puncture at Guwahati depot — surveyor report awaited'),
    ('TD-2026-006','Pune-Hyderabad','Safexpress','2026-05-01',
     680000.00,13600.00,2.00,true,13600.00,13600.00,100.0,28,
     'packaging_failure','recovered','improving','ESD pouch tear — full recovery, packaging spec updated'),
    ('TD-2026-007','Mumbai-Nagpur','Rivigo Cold Chain','2026-05-01',
     2100000.00,189000.00,9.00,true,185000.00,92500.00,50.0,66,
     'temperature_excursion','partially_recovered','worsening','Reefer excursion 6 hrs — 50% settlement on reagent kits'),
    ('TD-2026-008','Bengaluru-Kochi','TCI Express','2026-05-01',
     540000.00,10800.00,2.00,false,null,null,null,null,
     'mishandling','not_filed','stable','Cosmetic dent on trolley panel — absorbed internally'),
    ('TD-2026-009','Delhi-Jaipur','BlueDart Surface','2026-06-01',
     880000.00,26400.00,3.00,true,26400.00,24600.00,93.2,22,
     'physical_impact','recovered','improving','Drop at sortation belt — quick settlement under SLA'),
    ('TD-2026-010','Chennai Port-Coimbatore','VRL Logistics','2026-06-01',
     1650000.00,132000.00,8.00,true,128000.00,null,null,null,
     'moisture_ingress','under_process','worsening','Container sweat damage on X-ray detector — joint survey scheduled'),
    ('TD-2026-011','Hyderabad-Visakhapatnam','Gati-KWE','2026-06-01',
     720000.00,21600.00,3.00,true,21600.00,0.00,0.0,48,
     'mishandling','rejected','stable','Rejected for late intimation beyond 7-day claim window'),
    ('TD-2026-012','Ahmedabad-Indore','Safexpress','2026-06-01',
     980000.00,19600.00,2.00,true,19600.00,18400.00,93.9,31,
     'packaging_failure','recovered','stable','Strap abrasion — recovered, honeycomb wrap added to SOP'),
    ('TD-2026-013','Mumbai-Delhi','Delhivery Freight','2026-07-01',
     2250000.00,247500.00,11.00,true,240000.00,null,null,null,
     'physical_impact','under_process','worsening','Pallet toppled in line-haul — highest damage value this quarter'),
    ('TD-2026-014','Chennai-Bengaluru','TCI Express','2026-07-01',
     830000.00,16600.00,2.00,true,16600.00,15900.00,95.8,19,
     'packaging_failure','recovered','improving','Repeat corner-crush lane — recovered fast after spec escalation'),
    ('TD-2026-015','Kolkata-Guwahati','Rivigo Cold Chain','2026-07-01',
     1480000.00,118400.00,8.00,true,115000.00,57500.00,50.0,58,
     'temperature_excursion','partially_recovered','worsening','Genset failure on NH27 — partial settlement, lane under review'),
    ('TD-2026-016','Nhava Sheva-Ahmedabad','VRL Logistics','2026-07-01',
     1120000.00,44800.00,4.00,false,null,null,null,null,
     'moisture_ingress','not_filed','worsening','Claim window lapsed unfiled — escalated internally for SOP fix')
  ) as q(iref, lane, carr, pmon, shipval, dmgval, dmgp, cfiled, clamt, crec, recp, dsettle, dcat, cstat, tdir, nt);

  -- CAPA seed — attach to specific incidents via incident_ref
  insert into public.transit_damage_capa_actions_r3664 (
    incident_id, root_cause, corrective_action, capa_status,
    recovery_at_risk_rupees, action_owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.risk, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('TD-2026-003','monsoon_exposure','redesign_packaging_spec','escalated',168000.00,'Logistics Head - West','2026-07-10',null,'Rejected claim — moving to marine-grade barrier wrap and carrier SLA renegotiation'),
    ('TD-2026-005','carrier_rough_handling','retrain_warehouse_loaders','in_progress',102000.00,'Regional Ops Manager - East','2026-07-20',null,'Forklift puncture — depot loader retraining with Gati-KWE underway'),
    ('TD-2026-007','reefer_equipment_failure','enforce_reefer_telemetry','verification_pending',92500.00,'Cold Chain Lead','2026-07-15',null,'Telemetry mandate live on Mumbai-Nagpur reefers — verifying next 3 runs'),
    ('TD-2026-010','monsoon_exposure','add_impact_moisture_indicators','open',128000.00,'Logistics Head - South','2026-07-25',null,'Desiccant plus humidity indicators to be added on port lanes before survey closes'),
    ('TD-2026-011','claim_documentation_lapse','tighten_claim_sop_timelines','closed',21600.00,'Claims Desk Manager','2026-07-05','2026-06-30','48-hr intimation SLA added to claims SOP after late-filing rejection'),
    ('TD-2026-013','pallet_stacking_error','retrain_warehouse_loaders','escalated',240000.00,'Line-haul Vendor Manager','2026-07-18',null,'Toppled pallet — stacking audit escalated to Delhivery national account team'),
    ('TD-2026-015','reefer_equipment_failure','switch_carrier_on_lane','open',57500.00,'Cold Chain Lead','2026-07-30',null,'Second genset failure on Kolkata-Guwahati — evaluating alternate cold-chain carrier'),
    ('TD-2026-016','claim_documentation_lapse','tighten_claim_sop_timelines','overdue',44800.00,'Claims Desk Manager','2026-07-12',null,'Claim window lapsed unfiled — SOP reminder automation past target date')
  ) as q(iref, rc, ca, cst, risk, ownr, tcd, acd, nt)
  join public.transit_damage_r3664 e
    on e.organization_id = v_org_id and e.incident_ref = q.iref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Claim status distribution
create or replace function public.founder_r3664_claim_status_rollup()
returns table(claim_status text, incidents bigint, total_damage_value_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transit_damage_r3664)
  select l.claim_status, count(*)::bigint,
         coalesce(sum(l.damage_value_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.transit_damage_r3664 l
  group by l.claim_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3664_claim_status_rollup() from public, anon;
grant execute on function public.founder_r3664_claim_status_rollup() to authenticated;

-- 2) Carrier scorecard
create or replace function public.founder_r3664_carrier_scorecard()
returns table(
  carrier_name text,
  total_incidents bigint,
  claims_filed bigint,
  recovered bigint,
  rejected bigint,
  total_damage_value_rupees numeric,
  total_recovered_rupees numeric,
  avg_recovery_pct numeric,
  avg_days_to_settle numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.carrier_name,
    count(*)::bigint,
    count(*) filter (where l.claim_filed = true)::bigint,
    count(*) filter (where l.claim_status = 'recovered')::bigint,
    count(*) filter (where l.claim_status = 'rejected')::bigint,
    coalesce(sum(l.damage_value_rupees),0)::numeric,
    coalesce(sum(l.claim_recovered_rupees),0)::numeric,
    round(avg(l.recovery_pct), 1),
    round(avg(l.days_to_settle)::numeric, 1)
  from public.transit_damage_r3664 l
  group by l.carrier_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3664_carrier_scorecard() from public, anon;
grant execute on function public.founder_r3664_carrier_scorecard() to authenticated;

-- 3) Damage category × claim status matrix
create or replace function public.founder_r3664_category_status_matrix()
returns table(damage_category text, claim_status text, incidents bigint, total_damage_value_rupees numeric, avg_damage_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.damage_category, l.claim_status, count(*)::bigint,
    coalesce(sum(l.damage_value_rupees),0)::numeric,
    round(avg(l.damage_pct), 2)
  from public.transit_damage_r3664 l
  group by l.damage_category, l.claim_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3664_category_status_matrix() from public, anon;
grant execute on function public.founder_r3664_category_status_matrix() to authenticated;

-- 4) Monthly damage trend
create or replace function public.founder_r3664_monthly_damage_trend()
returns table(period_month date, incidents bigint, total_shipment_value_rupees numeric, total_damage_value_rupees numeric, total_recovered_rupees numeric, avg_damage_pct numeric, worsening_lanes bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.shipment_value_rupees),0)::numeric,
    coalesce(sum(l.damage_value_rupees),0)::numeric,
    coalesce(sum(l.claim_recovered_rupees),0)::numeric,
    round(avg(l.damage_pct), 2),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.transit_damage_r3664 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3664_monthly_damage_trend() from public, anon;
grant execute on function public.founder_r3664_monthly_damage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3664_capa_status_board()
returns table(capa_status text, actions bigint, avg_recovery_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.transit_damage_capa_actions_r3664 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3664_capa_status_board() from public, anon;
grant execute on function public.founder_r3664_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3664_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.transit_damage_capa_actions_r3664)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.transit_damage_capa_actions_r3664 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3664_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3664_root_cause_pareto() to authenticated;

-- 7) Recovery impact digest (by trend direction)
create or replace function public.founder_r3664_recovery_impact_digest()
returns table(trend_dir text, incidents bigint, total_damage_value_rupees numeric, total_claim_amount_rupees numeric, total_recovered_rupees numeric, overall_recovery_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_dir, count(*)::bigint,
    coalesce(sum(l.damage_value_rupees),0)::numeric,
    coalesce(sum(l.claim_amount_rupees),0)::numeric,
    coalesce(sum(l.claim_recovered_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.claim_recovered_rupees),0) / nullif(coalesce(sum(l.claim_amount_rupees),0),0), 1)
  from public.transit_damage_r3664 l
  group by l.trend_dir
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3664_recovery_impact_digest() from public, anon;
grant execute on function public.founder_r3664_recovery_impact_digest() to authenticated;

-- 8) High-risk queue (rejected / not-filed / worsening)
create or replace function public.founder_r3664_high_risk_queue()
returns table(
  incident_ref text,
  lane_name text,
  carrier_name text,
  period_month date,
  damage_category text,
  claim_status text,
  damage_value_rupees numeric,
  claim_amount_rupees numeric,
  recovery_pct numeric,
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
  select l.incident_ref, l.lane_name, l.carrier_name, l.period_month,
    l.damage_category, l.claim_status, l.damage_value_rupees,
    l.claim_amount_rupees, l.recovery_pct, l.trend_dir, l.notes
  from public.transit_damage_r3664 l
  where l.claim_status in ('rejected','not_filed')
     or l.trend_dir = 'worsening'
     or l.damage_pct >= 8.0
  order by l.period_month desc, l.damage_value_rupees desc;
end;
$$;

revoke all on function public.founder_r3664_high_risk_queue() from public, anon;
grant execute on function public.founder_r3664_high_risk_queue() to authenticated;
