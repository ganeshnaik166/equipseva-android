-- Round 3666: Founder Reverse-Logistics / Returns-Processing Cycle Board
-- Reverse logistics — return type × origin region × intake-to-disposition cycle × restock/scrap/refurb split × credit issued × processing status × trend × CAPA

-- =============================================================================
-- TABLE 1: reverse_logistics_r3666 — per-return-lot processing cycle facts
-- =============================================================================
create table if not exists public.reverse_logistics_r3666 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  return_ref text not null,
  origin_region text not null,
  period_month date not null,
  units_returned int not null,
  return_value_rupees numeric(14,2),
  days_in_transit int,
  days_to_disposition int,
  restocked_units int,
  scrapped_units int,
  refurbished_units int,
  credit_issued_rupees numeric(14,2),
  disposition_pct numeric(5,1),
  return_type text not null check (return_type in (
    'defective','loaner_return','core_return','expired','wrong_shipment'
  )),
  processing_status text not null check (processing_status in (
    'dispositioned','processing','awaiting_inspection','aging','stuck'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.reverse_logistics_r3666 enable row level security;

create index if not exists idx_reverse_logistics_r3666_org on public.reverse_logistics_r3666(organization_id);
create index if not exists idx_reverse_logistics_r3666_month on public.reverse_logistics_r3666(period_month);
create index if not exists idx_reverse_logistics_r3666_status on public.reverse_logistics_r3666(processing_status);

-- =============================================================================
-- TABLE 2: reverse_logistics_capa_actions_r3666 — CAPA actions on return lots
-- =============================================================================
create table if not exists public.reverse_logistics_capa_actions_r3666 (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.reverse_logistics_r3666(id) on delete cascade,
  root_cause text not null check (root_cause in (
    'inspection_capacity_shortfall','damaged_in_transit','documentation_mismatch',
    'supplier_credit_dispute','spare_part_backorder','rma_not_pre_approved',
    'erp_workflow_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_inspection_shift','expedite_spare_parts','escalate_credit_settlement',
    'fix_erp_rma_workflow','retrain_warehouse_team','improve_return_packaging',
    'pre_approve_rma_digitally','scrap_and_write_off','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  value_at_risk_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.reverse_logistics_capa_actions_r3666 enable row level security;

create index if not exists idx_reverse_logistics_capa_r3666_ret on public.reverse_logistics_capa_actions_r3666(return_id);
create index if not exists idx_reverse_logistics_capa_r3666_status on public.reverse_logistics_capa_actions_r3666(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Processing status distribution
create or replace function public.founder_r3666_processing_status_rollup()
returns table(processing_status text, return_lots bigint, total_units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.reverse_logistics_r3666)
  select l.processing_status, count(*)::bigint,
         coalesce(sum(l.units_returned),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.reverse_logistics_r3666 l
  group by l.processing_status
  order by count(*) desc;
end;
$$;

-- 2) Origin-region scorecard
create or replace function public.founder_r3666_origin_region_scorecard()
returns table(
  origin_region text,
  return_lots bigint,
  total_units bigint,
  total_value_rupees numeric,
  dispositioned_lots bigint,
  stuck_or_aging bigint,
  avg_days_to_disposition numeric,
  avg_disposition_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.origin_region,
    count(*)::bigint,
    coalesce(sum(l.units_returned),0)::bigint,
    coalesce(sum(l.return_value_rupees),0)::numeric,
    count(*) filter (where l.processing_status = 'dispositioned')::bigint,
    count(*) filter (where l.processing_status in ('stuck','aging'))::bigint,
    round(avg(l.days_to_disposition)::numeric, 1),
    round(avg(l.disposition_pct)::numeric, 1)
  from public.reverse_logistics_r3666 l
  group by l.origin_region
  order by count(*) desc;
end;
$$;

-- 3) Return-type × processing-status matrix
create or replace function public.founder_r3666_return_type_status_matrix()
returns table(return_type text, processing_status text, return_lots bigint, total_units bigint, avg_days_to_disposition numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.return_type, l.processing_status, count(*)::bigint,
    coalesce(sum(l.units_returned),0)::bigint,
    round(avg(l.days_to_disposition)::numeric, 1)
  from public.reverse_logistics_r3666 l
  group by l.return_type, l.processing_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly returns trend
create or replace function public.founder_r3666_monthly_returns_trend()
returns table(period_month date, return_lots bigint, total_units bigint, total_value_rupees numeric, credit_issued_rupees numeric, avg_days_to_disposition numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.units_returned),0)::bigint,
    coalesce(sum(l.return_value_rupees),0)::numeric,
    coalesce(sum(l.credit_issued_rupees),0)::numeric,
    round(avg(l.days_to_disposition)::numeric, 1)
  from public.reverse_logistics_r3666 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3666_capa_status_board()
returns table(capa_status text, actions bigint, avg_value_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.value_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.reverse_logistics_capa_actions_r3666 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3666_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_value_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.reverse_logistics_capa_actions_r3666)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.value_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.reverse_logistics_capa_actions_r3666 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Disposition-cycle digest per return type
create or replace function public.founder_r3666_disposition_cycle_digest()
returns table(
  return_type text,
  return_lots bigint,
  avg_days_in_transit numeric,
  avg_days_to_disposition numeric,
  restocked_units bigint,
  scrapped_units bigint,
  refurbished_units bigint,
  avg_disposition_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.return_type,
    count(*)::bigint,
    round(avg(l.days_in_transit)::numeric, 1),
    round(avg(l.days_to_disposition)::numeric, 1),
    coalesce(sum(l.restocked_units),0)::bigint,
    coalesce(sum(l.scrapped_units),0)::bigint,
    coalesce(sum(l.refurbished_units),0)::bigint,
    round(avg(l.disposition_pct)::numeric, 1)
  from public.reverse_logistics_r3666 l
  group by l.return_type
  order by count(*) desc;
end;
$$;

-- 8) High-risk (stuck / aging) queue
create or replace function public.founder_r3666_high_risk_queue()
returns table(
  return_ref text,
  origin_region text,
  period_month date,
  return_type text,
  processing_status text,
  trend_dir text,
  days_to_disposition int,
  units_returned int,
  disposition_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.return_ref, l.origin_region, l.period_month, l.return_type,
    l.processing_status, l.trend_dir, l.days_to_disposition, l.units_returned,
    l.disposition_pct, l.notes
  from public.reverse_logistics_r3666 l
  where l.processing_status in ('stuck','aging','awaiting_inspection')
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.days_to_disposition desc;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3666_processing_status_rollup() from public, anon;
revoke all on function public.founder_r3666_origin_region_scorecard() from public, anon;
revoke all on function public.founder_r3666_return_type_status_matrix() from public, anon;
revoke all on function public.founder_r3666_monthly_returns_trend() from public, anon;
revoke all on function public.founder_r3666_capa_status_board() from public, anon;
revoke all on function public.founder_r3666_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3666_disposition_cycle_digest() from public, anon;
revoke all on function public.founder_r3666_high_risk_queue() from public, anon;

grant execute on function public.founder_r3666_processing_status_rollup() to authenticated;
grant execute on function public.founder_r3666_origin_region_scorecard() to authenticated;
grant execute on function public.founder_r3666_return_type_status_matrix() to authenticated;
grant execute on function public.founder_r3666_monthly_returns_trend() to authenticated;
grant execute on function public.founder_r3666_capa_status_board() to authenticated;
grant execute on function public.founder_r3666_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3666_disposition_cycle_digest() to authenticated;
grant execute on function public.founder_r3666_high_risk_queue() to authenticated;

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

  -- 16 return-lot rows
  insert into public.reverse_logistics_r3666 (
    organization_id, return_ref, origin_region, period_month,
    units_returned, return_value_rupees, days_in_transit, days_to_disposition,
    restocked_units, scrapped_units, refurbished_units, credit_issued_rupees,
    disposition_pct, return_type, processing_status, trend_dir, notes
  )
  select v_org_id, q.rref, q.region, q.pmon::date,
    q.units, q.rval, q.transit, q.dispo,
    q.restk, q.scrap, q.refurb, q.credit,
    q.dpct, q.rtype, q.pstat, q.tdir, q.nt
  from (values
    ('RET-MUM-0401','Mumbai','2026-04-01',
     42,610000.00,3,6,28,6,8,540000.00,100.0,'defective','dispositioned','improving',
     'Defective infusion-pump lot — full disposition within SLA at Bhiwandi hub'),
    ('RET-DEL-0402','Delhi NCR','2026-04-01',
     18,240000.00,4,9,10,4,4,195000.00,100.0,'loaner_return','dispositioned','stable',
     'Loaner ventilators back post hospital trial — restocked after refurb check'),
    ('RET-BLR-0403','Bengaluru','2026-04-01',
     9,85000.00,2,15,0,9,0,0.00,100.0,'expired','dispositioned','stable',
     'Expired ECG electrode lots scrapped per SOP with disposal certificate'),
    ('RET-CHN-0501','Chennai','2026-05-01',
     35,510000.00,5,11,20,5,10,430000.00,100.0,'defective','dispositioned','improving',
     'Patient-monitor returns — refurb line cleared the inspection backlog'),
    ('RET-HYD-0502','Hyderabad','2026-05-01',
     12,150000.00,6,18,5,3,2,88000.00,83.3,'core_return','processing','stable',
     'Core returns from AMC swaps — 2 units pending bench inspection'),
    ('RET-PUN-0503','Pune','2026-05-01',
     7,98000.00,2,4,7,0,0,98000.00,100.0,'wrong_shipment','dispositioned','improving',
     'Wrong-shipment syringe pumps back via Mumbai-Pune route — restocked same week'),
    ('RET-KOL-0504','Kolkata','2026-05-01',
     22,310000.00,8,26,8,6,3,152000.00,77.3,'defective','aging','worsening',
     'Defibrillator returns aging — inspection bay capacity constraint at Dankuni'),
    ('RET-MUM-0601','Mumbai','2026-06-01',
     48,690000.00,3,8,30,8,10,585000.00,100.0,'defective','dispositioned','improving',
     'Monthly defective consolidation — ERP auto-RMA removed transit paperwork'),
    ('RET-DEL-0602','Delhi NCR','2026-06-01',
     15,205000.00,4,21,4,2,3,72000.00,60.0,'loaner_return','processing','stable',
     'Loaner CPAP fleet — 6 units held for deep-clean validation before restock'),
    ('RET-AHM-0603','Ahmedabad','2026-06-01',
     11,132000.00,7,32,2,3,1,41000.00,54.5,'core_return','stuck','worsening',
     'Core-return credits disputed by packaging supplier — units stuck at dock'),
    ('RET-BLR-0604','Bengaluru','2026-06-01',
     6,52000.00,3,10,0,6,0,0.00,100.0,'expired','dispositioned','stable',
     'Expired reagent kits scrapped — cold-chain disposal vendor engaged'),
    ('RET-CHN-0605','Chennai','2026-06-01',
     9,118000.00,5,17,3,1,2,58000.00,66.7,'wrong_shipment','awaiting_inspection','stable',
     'Wrong-shipment BP monitors awaiting serial-number verification in CRM'),
    ('RET-MUM-0701','Mumbai','2026-07-01',
     39,565000.00,2,5,26,5,8,505000.00,100.0,'defective','dispositioned','improving',
     'July defective lot — field-app pre-triage lifted first-pass disposition'),
    ('RET-HYD-0702','Hyderabad','2026-07-01',
     14,178000.00,6,24,3,2,2,64000.00,50.0,'defective','aging','worsening',
     'Suction-apparatus returns aging — spare-part wait from OEM'),
    ('RET-KOL-0703','Kolkata','2026-07-01',
     10,142000.00,9,35,1,2,1,30000.00,40.0,'core_return','stuck','worsening',
     'Cores stuck pending supplier credit reconciliation in ERP'),
    ('RET-PUN-0704','Pune','2026-07-01',
     8,96000.00,2,3,6,1,1,84000.00,100.0,'loaner_return','dispositioned','improving',
     'Loaner oximeters back via Mumbai-Pune route — restocked after QC')
  ) as q(rref, region, pmon, units, rval, transit, dispo, restk, scrap, refurb, credit, dpct, rtype, pstat, tdir, nt);

  -- CAPA seed — attach to specific return lots via return_ref
  insert into public.reverse_logistics_capa_actions_r3666 (
    return_id, root_cause, corrective_action, capa_status,
    value_at_risk_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.risk, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RET-KOL-0504','inspection_capacity_shortfall','add_inspection_shift','in_progress',158000.00,'Warehouse Ops — Kolkata','2026-07-25',null,'Second inspection shift approved; backlog burn-down tracked weekly'),
    ('RET-AHM-0603','supplier_credit_dispute','escalate_credit_settlement','escalated',91000.00,'Finance — Reverse Logistics','2026-07-20',null,'Packaging-supplier credit dispute escalated to commercial head'),
    ('RET-DEL-0602','documentation_mismatch','pre_approve_rma_digitally','verification_pending',133000.00,'Field Service — Delhi NCR','2026-07-22',null,'Digital RMA pre-approval rolled out in field-app — verifying next cycle'),
    ('RET-HYD-0702','spare_part_backorder','expedite_spare_parts','open',114000.00,'Service Parts — Hyderabad','2026-08-05',null,'OEM spare kits air-freighted; refurb queue to resume'),
    ('RET-KOL-0703','erp_workflow_gap','fix_erp_rma_workflow','overdue',112000.00,'IT — ERP Team','2026-07-15',null,'ERP credit-reconciliation step missing for core returns — patch past due'),
    ('RET-CHN-0605','rma_not_pre_approved','retrain_warehouse_team','in_progress',60000.00,'Warehouse Ops — Chennai','2026-07-28',null,'Wrong-shipment intake retraining underway; serial-verification SOP updated'),
    ('RET-MUM-0401','damaged_in_transit','improve_return_packaging','closed',70000.00,'Logistics — West Region','2026-06-30','2026-06-24','Foam-in-place return packaging adopted for pump returns'),
    ('RET-BLR-0403','pending_investigation','scrap_and_write_off','closed',85000.00,'QA — Bengaluru','2026-05-15','2026-05-10','Expired electrode lot scrapped with certified disposal — write-off booked')
  ) as q(rref, rc, ca, cst, risk, ownr, tcd, acd, nt)
  join public.reverse_logistics_r3666 e
    on e.organization_id = v_org_id and e.return_ref = q.rref;
end;
$seed$;
