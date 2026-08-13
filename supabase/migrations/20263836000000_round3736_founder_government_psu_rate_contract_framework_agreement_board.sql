-- Round 3736: Founder Government/PSU Rate-Contract & Framework-Agreement Board
-- Government/PSU rate-contract & framework-agreement compliance (GeM/DGS&D-style rate
-- contracts) — empanelment validity × order fulfillment × price-parity × CAPA
-- Distinct from any AMC/service-contract price-escalation board, which is customer-commercial,
-- not the government rate-contract regime.

-- =============================================================================
-- TABLE 1: rate_contract_r3736 — rate-contract & framework-agreement compliance facts
-- =============================================================================
create table if not exists public.rate_contract_r3736 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contract_ref text not null,
  contracting_authority text not null,
  period_month date not null,
  empanelment_valid_from date,
  empanelment_valid_to date,
  days_to_expiry int,
  orders_received int,
  orders_fulfilled_on_time int,
  price_parity_maintained boolean not null,
  penalty_clauses_triggered int,
  performance_bank_guarantee_rupees numeric(12,2),
  renewal_filed boolean not null,
  contract_class text not null check (contract_class in (
    'gem_rate_contract','dgs_and_d','state_psu_empanelment','csd_canteen_stores','institutional_tender'
  )),
  compliance_status text not null check (compliance_status in (
    'active_compliant','renewal_due','price_parity_breach','fulfillment_shortfall','delisted'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rate_contract_r3736 enable row level security;

create index if not exists idx_rate_contract_r3736_org on public.rate_contract_r3736(organization_id);
create index if not exists idx_rate_contract_r3736_month on public.rate_contract_r3736(period_month);
create index if not exists idx_rate_contract_r3736_status on public.rate_contract_r3736(compliance_status);

-- =============================================================================
-- TABLE 2: rate_contract_capa_actions_r3736 — CAPA for rate-contract compliance gaps
-- =============================================================================
create table if not exists public.rate_contract_capa_actions_r3736 (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid references public.rate_contract_r3736(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.rate_contract_capa_actions_r3736 enable row level security;

create index if not exists idx_rate_contract_capa_r3736_contract on public.rate_contract_capa_actions_r3736(contract_id);
create index if not exists idx_rate_contract_capa_r3736_status on public.rate_contract_capa_actions_r3736(capa_status);

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

  -- 16 rate-contract rows
  insert into public.rate_contract_r3736 (
    organization_id, contract_ref, contracting_authority, period_month,
    empanelment_valid_from, empanelment_valid_to, days_to_expiry,
    orders_received, orders_fulfilled_on_time, price_parity_maintained,
    penalty_clauses_triggered, performance_bank_guarantee_rupees, renewal_filed,
    contract_class, compliance_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.cauth, q.pm::date,
    q.evf::date, q.evt::date, q.dte::int,
    q.orec::int, q.oft::int, q.ppm,
    q.pen::int, q.pbg::numeric, q.rf,
    q.cls, q.cst, q.td, q.nt
  from (values
    ('GEM/RC/2026/0141','GeM - Central Procurement Cell','2026-07-01',
     '2025-04-01','2027-03-31',238,42,40,true,0,850000.00,true,'gem_rate_contract','active_compliant','stable','Hydraulic excavator rate contract renewed at par with L1 benchmark'),
    ('DGSD/2026/0072','DGS&D - Ministry of Defence','2026-07-01',
     '2024-09-01','2026-08-31',30,18,17,true,0,620000.00,false,'dgs_and_d','renewal_due','worsening','Renewal filing pending beyond internal SLA — 30 days to expiry'),
    ('MHPSU/EMP/2026/019','Maharashtra State PSU Empanelment Board','2026-06-01',
     '2025-01-15','2027-01-14',167,25,16,false,2,410000.00,true,'state_psu_empanelment','price_parity_breach','worsening','Quoted rate found above private-market benchmark in vigilance audit'),
    ('CSD/CANT/2026/303','Canteen Stores Department Zone HQ','2026-07-01',
     '2025-06-01','2027-05-31',292,60,58,true,0,275000.00,true,'csd_canteen_stores','active_compliant','stable','CSD depot spares supply steady, fill rate 96.7%'),
    ('AIIMS/INST/2026/054','AIIMS Institutional Tender Cell','2026-06-01',
     '2024-12-01','2026-11-30',121,12,7,true,1,190000.00,false,'institutional_tender','fulfillment_shortfall','worsening','Genset AMC turnaround slipped past contracted 72-hour window thrice'),
    ('GEM/RC/2026/0198','GeM - Ministry of Road Transport','2026-07-01',
     '2025-05-01','2027-04-30',260,33,33,true,0,720000.00,true,'gem_rate_contract','active_compliant','improving','100% on-time fulfillment for portable compressor rate contract'),
    ('DGSD/2026/0088','DGS&D - Border Roads Organisation','2026-05-01',
     '2023-11-01','2026-06-30',-14,8,2,false,4,150000.00,false,'dgs_and_d','delisted','worsening','Empanelment lapsed without renewal filing — delisted from BRO vendor panel'),
    ('MHPSU/EMP/2026/027','Gujarat State PSU Empanelment Board','2026-07-01',
     '2025-08-01','2027-07-31',352,20,19,true,0,330000.00,true,'state_psu_empanelment','active_compliant','stable','GPCL fuel-station compressor AMC empanelment on track'),
    ('CSD/CANT/2026/311','Canteen Stores Department Southern Command','2026-06-01',
     '2024-04-01','2026-09-15',46,45,44,true,0,260000.00,false,'csd_canteen_stores','renewal_due','stable','Renewal dossier drafted, awaiting depot commandant countersignature'),
    ('AIIMS/INST/2026/061','Institutional Tender Board - NIT Trichy','2026-07-01',
     '2025-02-01','2027-01-31',171,15,15,true,0,175000.00,true,'institutional_tender','active_compliant','improving','Lab equipment AMC tender fully compliant post Q2 corrective action'),
    ('GEM/RC/2026/0210','GeM - Central Warehousing Corporation','2026-05-01',
     '2024-02-01','2026-07-31',0,28,20,false,3,540000.00,false,'gem_rate_contract','price_parity_breach','worsening','Forklift rate contract flagged — quoted price 8% above GeM benchmark ceiling'),
    ('DGSD/2026/0095','DGS&D - Indian Ordnance Factories Board','2026-06-01',
     '2025-03-01','2027-02-28',199,22,21,true,0,480000.00,true,'dgs_and_d','active_compliant','stable','Ordnance factory material-handling rate contract stable, PBG renewed'),
    ('MHPSU/EMP/2026/034','Tamil Nadu State PSU Empanelment Board','2026-07-01',
     '2025-09-01','2027-08-31',383,10,4,true,1,220000.00,true,'state_psu_empanelment','fulfillment_shortfall','worsening','TANGEDCO substation genset call closures missed contracted turnaround in 6 of 10 orders'),
    ('CSD/CANT/2026/318','Canteen Stores Department Eastern Command','2026-05-01',
     '2023-05-01','2026-05-31',-74,5,1,false,5,95000.00,false,'csd_canteen_stores','delisted','worsening','Contract lapsed post repeated fulfillment failures — CSD panel removal notice issued'),
    ('AIIMS/INST/2026/070','Institutional Tender Cell - IIT Madras','2026-06-01',
     '2025-04-01','2027-03-31',238,9,9,true,0,140000.00,true,'institutional_tender','active_compliant','improving','Campus DG-set AMC tender fully on schedule, zero penalty clauses this cycle'),
    ('GEM/RC/2026/0225','GeM - Food Corporation of India','2026-07-01',
     '2025-06-15','2026-09-01',19,30,27,true,0,610000.00,false,'gem_rate_contract','renewal_due','stable','FCI grain-handling equipment rate contract renewal filing due within 3 weeks')
  ) as q(cref, cauth, pm, evf, evt, dte, orec, oft, ppm, pen, pbg, rf, cls, cst, td, nt);

  -- 8 CAPA rows — attach to contracts via contract_ref
  insert into public.rate_contract_capa_actions_r3736 (
    contract_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('DGSD/2026/0072','Renewal application drafted late due to PBG revalidation delay','Expedite PBG revalidation and file renewal via DGS&D portal before expiry','in_progress','Contracts Compliance Manager','2026-08-25',null,'PBG bank confirmation received, portal filing scheduled this week'),
    ('MHPSU/EMP/2026/019','Quoted rate not benchmarked against latest private-market rate card','Revise price list and submit parity undertaking to state PSU board','open','Pricing Desk Lead','2026-08-30',null,'Vigilance audit finding under response; revised rate card in draft'),
    ('AIIMS/INST/2026/054','Field service team understaffed for genset AMC turnaround SLA','Add dedicated AMC technician and pre-position spares at AIIMS depot','in_progress','Service Ops Manager','2026-08-20',null,'Second technician deployed 1-Aug; turnaround improving on last 2 calls'),
    ('DGSD/2026/0088','Renewal filing missed due to ownership gap after compliance-officer exit','Petition BRO for panel reinstatement with fresh empanelment application','overdue','Head of Contracts','2026-07-31',null,'Reinstatement application pending BRO procurement committee review'),
    ('CSD/CANT/2026/311','Depot commandant countersignature pending beyond routine cycle','Escalate to zonal CSD liaison officer for expedited countersignature','in_progress','Government Liaison Officer','2026-08-28',null,'Follow-up letter sent; countersignature expected within 10 days'),
    ('GEM/RC/2026/0210','Forklift rate quoted above GeM benchmark ceiling due to freight-cost revision','Resubmit revised bid within GeM benchmark ceiling and issue price-match undertaking','open','Pricing Desk Lead','2026-09-05',null,'GeM show-cause notice received 28-Jul; response under legal review'),
    ('MHPSU/EMP/2026/034','TANGEDCO substation call closures delayed by spare-parts logistics lag','Pre-stock critical genset spares at regional TANGEDCO substations','closed','Regional Service Manager','2026-07-20','2026-07-18','Regional spares hub operational; last 3 calls closed within SLA'),
    ('CSD/CANT/2026/318','Repeated fulfillment failures traced to depot understaffing and no escalation path','Rebuild depot service roster and file fresh CSD panel application with corrective undertaking','overdue','Head of Contracts','2026-07-15',null,'Fresh panel application drafted; awaiting CSD Eastern Command review slot')
  ) as q(cref, rc, ca, cst, ownr, tcd, acd, nt)
  join public.rate_contract_r3736 e
    on e.organization_id = v_org_id and e.contract_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3736_compliance_status_rollup()
returns table(compliance_status text, contracts bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rate_contract_r3736)
  select l.compliance_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.rate_contract_r3736 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3736_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3736_compliance_status_rollup() to authenticated;

-- 2) Contracting-authority scorecard
create or replace function public.founder_r3736_contracting_authority_scorecard()
returns table(
  contracting_authority text,
  contracts bigint,
  active_compliant bigint,
  renewal_due bigint,
  price_parity_breach bigint,
  fulfillment_shortfall bigint,
  delisted bigint,
  total_orders_received bigint,
  total_orders_fulfilled_on_time bigint,
  avg_pbg_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contracting_authority,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'active_compliant')::bigint,
    count(*) filter (where l.compliance_status = 'renewal_due')::bigint,
    count(*) filter (where l.compliance_status = 'price_parity_breach')::bigint,
    count(*) filter (where l.compliance_status = 'fulfillment_shortfall')::bigint,
    count(*) filter (where l.compliance_status = 'delisted')::bigint,
    coalesce(sum(l.orders_received),0)::bigint,
    coalesce(sum(l.orders_fulfilled_on_time),0)::bigint,
    round(avg(l.performance_bank_guarantee_rupees), 0)
  from public.rate_contract_r3736 l
  group by l.contracting_authority
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3736_contracting_authority_scorecard() from public, anon;
grant execute on function public.founder_r3736_contracting_authority_scorecard() to authenticated;

-- 3) Contract-class × compliance-status matrix
create or replace function public.founder_r3736_contract_class_status_matrix()
returns table(contract_class text, compliance_status text, contracts bigint, avg_days_to_expiry numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_class, l.compliance_status, count(*)::bigint,
    round(avg(l.days_to_expiry), 1)
  from public.rate_contract_r3736 l
  group by l.contract_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3736_contract_class_status_matrix() from public, anon;
grant execute on function public.founder_r3736_contract_class_status_matrix() to authenticated;

-- 4) Monthly fulfillment trend
create or replace function public.founder_r3736_monthly_fulfillment_trend()
returns table(
  period_month date,
  contracts bigint,
  total_orders_received bigint,
  total_orders_fulfilled_on_time bigint,
  fulfillment_rate_pct numeric,
  price_parity_breaches bigint,
  worsening_contracts bigint
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
    coalesce(sum(l.orders_received),0)::bigint,
    coalesce(sum(l.orders_fulfilled_on_time),0)::bigint,
    round((coalesce(sum(l.orders_fulfilled_on_time),0)::numeric / nullif(coalesce(sum(l.orders_received),0),0)) * 100.0, 1),
    count(*) filter (where l.price_parity_maintained = false)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.rate_contract_r3736 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3736_monthly_fulfillment_trend() from public, anon;
grant execute on function public.founder_r3736_monthly_fulfillment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3736_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.rate_contract_capa_actions_r3736 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3736_capa_status_board() from public, anon;
grant execute on function public.founder_r3736_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3736_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.rate_contract_capa_actions_r3736)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.rate_contract_capa_actions_r3736 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3736_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3736_root_cause_pareto() to authenticated;

-- 7) Penalty / price-parity-breach digest by contract class
create or replace function public.founder_r3736_penalty_digest()
returns table(
  contract_class text,
  contracts bigint,
  penalty_clauses_total bigint,
  price_parity_breaches bigint,
  avg_pbg_rupees numeric,
  renewal_not_filed bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_class,
    count(*)::bigint,
    coalesce(sum(l.penalty_clauses_triggered),0)::bigint,
    count(*) filter (where l.price_parity_maintained = false)::bigint,
    round(avg(l.performance_bank_guarantee_rupees), 0),
    count(*) filter (where l.renewal_filed = false)::bigint
  from public.rate_contract_r3736 l
  where l.penalty_clauses_triggered > 0 or l.price_parity_maintained = false
  group by l.contract_class
  order by coalesce(sum(l.penalty_clauses_triggered),0) desc;
end;
$$;

revoke all on function public.founder_r3736_penalty_digest() from public, anon;
grant execute on function public.founder_r3736_penalty_digest() to authenticated;

-- 8) High-risk contract queue (price-parity breach / delisted, worst first)
create or replace function public.founder_r3736_high_risk_queue()
returns table(
  contract_ref text,
  contracting_authority text,
  contract_class text,
  period_month date,
  compliance_status text,
  days_to_expiry int,
  orders_received int,
  orders_fulfilled_on_time int,
  penalty_clauses_triggered int,
  renewal_filed boolean,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_ref, l.contracting_authority, l.contract_class, l.period_month,
    l.compliance_status, l.days_to_expiry, l.orders_received, l.orders_fulfilled_on_time,
    l.penalty_clauses_triggered, l.renewal_filed, l.notes
  from public.rate_contract_r3736 l
  where l.compliance_status in ('price_parity_breach','delisted')
  order by l.days_to_expiry asc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3736_high_risk_queue() from public, anon;
grant execute on function public.founder_r3736_high_risk_queue() to authenticated;
