-- Round 3309: Founder Procurement Cost-Savings, Should-Cost & Vendor-Negotiation Board
-- Procurement governance — category × vendor × sourcing-event × baseline vs should-cost vs
-- negotiated × savings ₹/pct × savings-type × payment-terms × single-source risk × verdict × CAPA

-- =============================================================================
-- TABLE 1: procurement_savings_r3309 — per procurement / negotiation outcome
-- =============================================================================
create table if not exists public.procurement_savings_r3309 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  procurement_ref text not null,
  category text not null check (category in (
    'spare_parts','test_tools','logistics_freight','it_saas',
    'professional_services','office_admin','vehicle_fleet'
  )),
  vendor text not null,
  sourcing_event text not null check (sourcing_event in (
    'annual_rate_contract','spot_buy','rfq_competitive','renewal_negotiation','single_source'
  )),
  baseline_cost_rupees numeric(14,2) not null,
  should_cost_estimate_rupees numeric(14,2),
  negotiated_cost_rupees numeric(14,2) not null,
  savings_rupees numeric(14,2),
  savings_pct numeric(6,2),
  savings_type text not null check (savings_type in (
    'hard_saving','cost_avoidance','value_add'
  )),
  payment_terms_days int not null,
  contract_start date not null,
  savings_realized boolean not null default false,
  single_source_risk boolean not null default false,
  procurement_verdict text not null check (procurement_verdict in (
    'target_beaten','on_target','below_target','renegotiate','consolidate_vendors'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.procurement_savings_r3309 enable row level security;

create index if not exists idx_procurement_savings_r3309_org on public.procurement_savings_r3309(organization_id);
create index if not exists idx_procurement_savings_r3309_start on public.procurement_savings_r3309(contract_start);
create index if not exists idx_procurement_savings_r3309_verdict on public.procurement_savings_r3309(procurement_verdict);

-- =============================================================================
-- TABLE 2: procurement_savings_capa_actions_r3309 — renegotiation / de-risking actions
-- =============================================================================
create table if not exists public.procurement_savings_capa_actions_r3309 (
  id uuid primary key default gen_random_uuid(),
  procurement_id uuid not null references public.procurement_savings_r3309(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'below_target_savings','single_source_dependency','price_variance_high','payment_terms_unfavorable',
    'should_cost_gap','vendor_consolidation_opportunity','contract_renewal_due'
  )),
  root_cause text not null check (root_cause in (
    'weak_negotiation_leverage','single_source_lock_in','specification_over_engineered','demand_not_aggregated',
    'market_price_increase','vendor_pricing_opaque','pending_investigation','budget_pressure'
  )),
  corrective_action text not null check (corrective_action in (
    'rebid_competitive_rfq','renegotiate_rate_contract','consolidate_to_fewer_vendors','qualify_second_source',
    'value_engineer_spec','aggregate_demand','extend_payment_terms','escalate_to_leadership','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.procurement_savings_capa_actions_r3309 enable row level security;

create index if not exists idx_procurement_savings_capa_r3309_proc on public.procurement_savings_capa_actions_r3309(procurement_id);
create index if not exists idx_procurement_savings_capa_r3309_status on public.procurement_savings_capa_actions_r3309(capa_status);

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

  -- 14 procurement / negotiation rows
  insert into public.procurement_savings_r3309 (
    organization_id, procurement_ref, category, vendor, sourcing_event,
    baseline_cost_rupees, should_cost_estimate_rupees, negotiated_cost_rupees,
    savings_rupees, savings_pct, savings_type, payment_terms_days, contract_start,
    savings_realized, single_source_risk, procurement_verdict, notes
  )
  select v_org_id, q.ref, q.cat, q.ven, q.se,
    q.base, q.should, q.neg,
    q.sav, q.savpct, q.savtype, q.pterms, q.cstart::date,
    q.realized, q.ssr, q.verdict, q.nt
  from (values
    ('PRC-3309-01','spare_parts','GE Healthcare India','annual_rate_contract',
     1250000.00,1150000.00,1090000.00,160000.00,12.80,'hard_saving',45,'2026-04-01',
     true,false,'target_beaten','Annual rate contract beat should-cost — 12.8% vs baseline'),
    ('PRC-3309-02','test_tools','Fluke Biomedical','rfq_competitive',
     880000.00,820000.00,812000.00,68000.00,7.73,'hard_saving',30,'2026-04-15',
     true,false,'on_target','Competitive RFQ landed near should-cost — analyzer bundle'),
    ('PRC-3309-03','logistics_freight','Blue Dart Express','renewal_negotiation',
     640000.00,560000.00,622000.00,18000.00,2.81,'cost_avoidance',30,'2026-05-01',
     false,false,'below_target','Freight rate held near baseline — 2.8% below 8% target'),
    ('PRC-3309-04','it_saas','Zoho Corporation','renewal_negotiation',
     540000.00,470000.00,486000.00,54000.00,10.00,'hard_saving',60,'2026-04-10',
     true,false,'on_target','CRM renewal negotiated to 10% off list — seats trued up'),
    ('PRC-3309-05','professional_services','Deloitte India','single_source',
     1500000.00,1250000.00,1425000.00,75000.00,5.00,'cost_avoidance',45,'2026-05-05',
     false,true,'renegotiate','Single-source consultant — only 5%, renegotiate scope & rate'),
    ('PRC-3309-06','spare_parts','Philips Healthcare','single_source',
     980000.00,780000.00,960000.00,20000.00,2.04,'cost_avoidance',30,'2026-05-12',
     false,true,'consolidate_vendors','OEM-locked spares — 2% only, qualify second source'),
    ('PRC-3309-07','vehicle_fleet','Mahindra Logistics','rfq_competitive',
     720000.00,640000.00,648000.00,72000.00,10.00,'hard_saving',30,'2026-06-01',
     true,false,'target_beaten','Field-van lease rebid — 10% under baseline'),
    ('PRC-3309-08','office_admin','Staples India','spot_buy',
     210000.00,185000.00,192000.00,18000.00,8.57,'hard_saving',15,'2026-06-03',
     true,false,'on_target','Consumables spot buy — volume break applied'),
    ('PRC-3309-09','it_saas','Freshworks','renewal_negotiation',
     460000.00,400000.00,402000.00,58000.00,12.61,'hard_saving',60,'2026-06-08',
     true,false,'target_beaten','Helpdesk renewal beat should-cost — annual prepay discount'),
    ('PRC-3309-10','test_tools','Rigel Medical','spot_buy',
     350000.00,320000.00,348000.00,2000.00,0.57,'cost_avoidance',30,'2026-06-12',
     false,false,'below_target','Spot buy near list — 0.6% only, aggregate demand'),
    ('PRC-3309-11','logistics_freight','Delhivery','annual_rate_contract',
     590000.00,510000.00,522000.00,68000.00,11.53,'hard_saving',45,'2026-05-20',
     true,false,'target_beaten','Reverse-logistics rate contract — 11.5% under baseline'),
    ('PRC-3309-12','professional_services','KPMG India','rfq_competitive',
     1100000.00,950000.00,968000.00,132000.00,12.00,'cost_avoidance',60,'2026-04-22',
     true,false,'target_beaten','Statutory audit rebid — 12% avoidance vs prior firm'),
    ('PRC-3309-13','spare_parts','Siemens Healthineers','single_source',
     1350000.00,1080000.00,1330000.00,20000.00,1.48,'cost_avoidance',30,'2026-06-18',
     false,true,'renegotiate','CT-tube single-source — 1.5% only, should-cost gap 20%'),
    ('PRC-3309-14','vehicle_fleet','Tata Motors Fleet','annual_rate_contract',
     900000.00,null,828000.00,72000.00,8.00,'value_add',45,'2026-05-28',
     true,false,'on_target','Fleet AMC bundled telematics at no cost — value-add')
  ) as q(ref, cat, ven, se, base, should, neg, sav, savpct, savtype, pterms, cstart, realized, ssr, verdict, nt);

  -- CAPA seed — attach to at-risk procurements via procurement_ref
  insert into public.procurement_savings_capa_actions_r3309 (
    procurement_id, finding_category, root_cause, corrective_action,
    capa_status, target_closure_date, actual_closure_date, estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('PRC-3309-03','below_target_savings','weak_negotiation_leverage','rebid_competitive_rfq','open','2026-07-25',null,15000.00,'Freight held near baseline — take renewal to competitive RFQ'),
    ('PRC-3309-05','single_source_dependency','single_source_lock_in','renegotiate_rate_contract','in_progress','2026-07-20',null,25000.00,'Consultant scope & rate renegotiation under way'),
    ('PRC-3309-06','vendor_consolidation_opportunity','single_source_lock_in','qualify_second_source','escalated','2026-07-15',null,40000.00,'OEM-locked spares — qualify alternate supplier, escalated'),
    ('PRC-3309-10','below_target_savings','demand_not_aggregated','aggregate_demand','open','2026-07-30',null,8000.00,'Fragmented spot buys — aggregate into annual rate contract'),
    ('PRC-3309-13','should_cost_gap','vendor_pricing_opaque','value_engineer_spec','overdue','2026-06-30',null,55000.00,'Should-cost gap 20% on CT tube — spec review overdue'),
    ('PRC-3309-03','payment_terms_unfavorable','weak_negotiation_leverage','extend_payment_terms','closed','2026-07-10','2026-07-08',0.00,'Extended to 45-day terms — closed'),
    ('PRC-3309-06','price_variance_high','market_price_increase','escalate_to_leadership','verification_pending','2026-07-18',null,12000.00,'OEM price rise 8% — escalated, verifying countermeasure')
  ) as q(ref, fc, rc, ca, cst, tcd, acd, cost, nt)
  join public.procurement_savings_r3309 e
    on e.organization_id = v_org_id and e.procurement_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Procurement verdict distribution
create or replace function public.founder_r3309_verdict_rollup()
returns table(procurement_verdict text, deals bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.procurement_savings_r3309)
  select l.procurement_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.procurement_savings_r3309 l
  group by l.procurement_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3309_verdict_rollup() from public, anon;
grant execute on function public.founder_r3309_verdict_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3309_category_scorecard()
returns table(
  category text,
  deals bigint,
  target_beaten bigint,
  on_target bigint,
  below_target bigint,
  single_source_deals bigint,
  total_savings_rupees numeric,
  avg_savings_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.procurement_verdict = 'target_beaten')::bigint,
    count(*) filter (where l.procurement_verdict = 'on_target')::bigint,
    count(*) filter (where l.procurement_verdict in ('below_target','renegotiate','consolidate_vendors'))::bigint,
    count(*) filter (where l.single_source_risk)::bigint,
    coalesce(sum(l.savings_rupees),0)::numeric,
    round(avg(l.savings_pct), 2)
  from public.procurement_savings_r3309 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3309_category_scorecard() from public, anon;
grant execute on function public.founder_r3309_category_scorecard() to authenticated;

-- 3) Category × sourcing-event matrix
create or replace function public.founder_r3309_category_sourcing_matrix()
returns table(
  category text,
  sourcing_event text,
  deals bigint,
  total_savings_rupees numeric,
  avg_savings_pct numeric,
  realized bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.sourcing_event, count(*)::bigint,
    coalesce(sum(l.savings_rupees),0)::numeric,
    round(avg(l.savings_pct), 2),
    count(*) filter (where l.savings_realized)::bigint
  from public.procurement_savings_r3309 l
  group by l.category, l.sourcing_event
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3309_category_sourcing_matrix() from public, anon;
grant execute on function public.founder_r3309_category_sourcing_matrix() to authenticated;

-- 4) Contract-start savings trend
create or replace function public.founder_r3309_savings_trend()
returns table(
  contract_start date,
  deals bigint,
  total_baseline_rupees numeric,
  total_negotiated_rupees numeric,
  total_savings_rupees numeric,
  realized bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_start,
    count(*)::bigint,
    coalesce(sum(l.baseline_cost_rupees),0)::numeric,
    coalesce(sum(l.negotiated_cost_rupees),0)::numeric,
    coalesce(sum(l.savings_rupees),0)::numeric,
    count(*) filter (where l.savings_realized)::bigint
  from public.procurement_savings_r3309 l
  group by l.contract_start
  order by l.contract_start desc;
end;
$$;

revoke execute on function public.founder_r3309_savings_trend() from public, anon;
grant execute on function public.founder_r3309_savings_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3309_capa_status_board()
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
  from public.procurement_savings_capa_actions_r3309 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3309_capa_status_board() from public, anon;
grant execute on function public.founder_r3309_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3309_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.procurement_savings_capa_actions_r3309)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.procurement_savings_capa_actions_r3309 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3309_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3309_root_cause_pareto() to authenticated;

-- 7) Savings-type cost digest
create or replace function public.founder_r3309_savings_type_digest()
returns table(
  savings_type text,
  deals bigint,
  total_savings_rupees numeric,
  realized_savings_rupees numeric,
  avg_savings_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.savings_type, count(*)::bigint,
    coalesce(sum(l.savings_rupees),0)::numeric,
    coalesce(sum(l.savings_rupees) filter (where l.savings_realized),0)::numeric,
    round(avg(l.savings_pct), 2)
  from public.procurement_savings_r3309 l
  group by l.savings_type
  order by coalesce(sum(l.savings_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3309_savings_type_digest() from public, anon;
grant execute on function public.founder_r3309_savings_type_digest() to authenticated;

-- 8) High-risk procurement queue
create or replace function public.founder_r3309_high_risk_queue()
returns table(
  procurement_ref text,
  category text,
  vendor text,
  sourcing_event text,
  contract_start date,
  procurement_verdict text,
  savings_pct numeric,
  savings_type text,
  single_source_risk boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.procurement_ref, l.category, l.vendor, l.sourcing_event, l.contract_start,
    l.procurement_verdict, l.savings_pct, l.savings_type, l.single_source_risk, l.notes
  from public.procurement_savings_r3309 l
  where l.procurement_verdict in ('below_target','renegotiate','consolidate_vendors')
     or l.single_source_risk
     or l.savings_realized = false
  order by l.contract_start desc, l.procurement_ref;
end;
$$;

revoke execute on function public.founder_r3309_high_risk_queue() from public, anon;
grant execute on function public.founder_r3309_high_risk_queue() to authenticated;
