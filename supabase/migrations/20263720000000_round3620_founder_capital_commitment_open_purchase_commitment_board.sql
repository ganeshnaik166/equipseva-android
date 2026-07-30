-- Round 3620: Founder Capital-Commitment / Open-Purchase-Commitment Board
-- Founder finance — contracted-not-executed (open purchase commitment) tracking per business unit:
-- commitment ref x business unit x period x contracted/executed/open value x budget coverage x
-- expected completion x aging x po type x commitment status x trend x CAPA closure.

-- =============================================================================
-- TABLE 1: capital_commitment_r3620 — per-commitment open-purchase-commitment facts
-- =============================================================================
create table if not exists public.capital_commitment_r3620 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  commitment_ref text not null,
  business_unit text not null,
  period_month date not null,
  contracted_value_rupees numeric(14,2) not null,
  executed_value_rupees numeric(14,2),
  open_commitment_rupees numeric(14,2) not null,
  budget_covered_pct numeric(5,2),
  expected_completion_date date,
  aging_days integer,
  po_type text not null check (po_type in (
    'capex','opex','project','amc','inventory'
  )),
  commitment_status text not null check (commitment_status in (
    'on_schedule','committed','delayed','over_committed','budget_gap'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capital_commitment_r3620 enable row level security;

create index if not exists idx_capital_commitment_r3620_org on public.capital_commitment_r3620(organization_id);
create index if not exists idx_capital_commitment_r3620_month on public.capital_commitment_r3620(period_month);
create index if not exists idx_capital_commitment_r3620_status on public.capital_commitment_r3620(commitment_status);

-- =============================================================================
-- TABLE 2: capital_commitment_capa_actions_r3620 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.capital_commitment_capa_actions_r3620 (
  id uuid primary key default gen_random_uuid(),
  commitment_log_id uuid not null references public.capital_commitment_r3620(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'open_commitment_overrun','budget_gap','execution_delay','vendor_slippage',
    'over_commitment','scope_change','price_escalation','payment_milestone_slip'
  )),
  root_cause text not null check (root_cause in (
    'vendor_delivery_delay','budget_shortfall','scope_creep','price_escalation',
    'approval_delay','forecast_error','contract_amendment','pending_investigation',
    'supplier_capacity_constraint','fx_movement'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_contract','rephase_delivery_schedule','reallocate_budget','cancel_open_po',
    'escalate_to_procurement','revise_forecast','split_commitment','expedite_vendor','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capital_commitment_capa_actions_r3620 enable row level security;

create index if not exists idx_capital_commitment_capa_r3620_log on public.capital_commitment_capa_actions_r3620(commitment_log_id);
create index if not exists idx_capital_commitment_capa_r3620_status on public.capital_commitment_capa_actions_r3620(capa_status);

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

  -- 16 commitment rows
  insert into public.capital_commitment_r3620 (
    organization_id, commitment_ref, business_unit, period_month,
    contracted_value_rupees, executed_value_rupees, open_commitment_rupees, budget_covered_pct,
    expected_completion_date, aging_days, po_type, commitment_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.bu, q.pm::date,
    q.cv, q.ev, q.oc, q.bcp,
    q.ecd::date, q.ag, q.pt, q.cs, q.td, q.nt
  from (values
    ('CMT-2601','capital_equipment','2026-07-01',12000000,3000000,9000000,78.0,'2026-12-15',45,'capex','committed','stable','New CT scanner PO — 25% executed, on track'),
    ('CMT-2602','projects','2026-07-01',8500000,8500000,0,100.0,'2026-06-30',5,'project','on_schedule','improving','Turnkey ICU project fully executed and closed'),
    ('CMT-2603','amc_services','2026-07-01',3200000,1600000,1600000,92.0,'2026-11-30',30,'amc','committed','stable','Annual AMC contract — half executed'),
    ('CMT-2604','spare_parts','2026-06-01',1500000,400000,1100000,65.0,'2026-09-15',72,'inventory','delayed','worsening','Spare-parts inventory PO delayed — vendor slippage'),
    ('CMT-2605','diagnostics','2026-06-01',6000000,2000000,4000000,55.0,'2026-10-31',88,'capex','budget_gap','worsening','Diagnostics lab expansion — budget gap flagged'),
    ('CMT-2606','rentals','2026-07-01',2400000,600000,1800000,100.0,'2026-12-31',20,'opex','on_schedule','stable','Equipment rental commitment — monthly draws on schedule'),
    ('CMT-2607','projects','2026-06-01',15000000,4500000,10500000,70.0,'2027-01-31',95,'project','over_committed','worsening','Multi-site rollout over-committed vs approved budget'),
    ('CMT-2608','capital_equipment','2026-05-01',9800000,9800000,0,100.0,'2026-05-20',3,'capex','on_schedule','improving','Ventilator fleet PO fully received and closed'),
    ('CMT-2609','amc_services','2026-07-01',2100000,700000,1400000,88.0,'2026-12-01',35,'amc','committed','stable','Biomedical AMC — quarterly billing in progress'),
    ('CMT-2610','spare_parts','2026-06-01',1800000,900000,900000,60.0,'2026-09-30',66,'inventory','budget_gap','worsening','Consumables commitment exceeds spare-parts budget line'),
    ('CMT-2611','diagnostics','2026-07-01',5200000,1300000,3900000,80.0,'2026-11-15',40,'capex','committed','stable','Radiology upgrade — phased execution underway'),
    ('CMT-2612','rentals','2026-06-01',1200000,1200000,0,100.0,'2026-06-28',8,'opex','on_schedule','stable','Short-term rental commitment settled in full'),
    ('CMT-2613','projects','2026-05-01',22000000,5500000,16500000,68.0,'2027-03-31',110,'project','over_committed','worsening','Greenfield hospital project — heavy open commitment'),
    ('CMT-2614','opex_supplies','2026-07-01',900000,300000,600000,95.0,'2026-10-15',25,'opex','committed','improving','Recurring supplies PO — within budget'),
    ('CMT-2615','capital_equipment','2026-06-01',7400000,2200000,5200000,58.0,'2026-12-20',80,'capex','budget_gap','worsening','Cath-lab equipment — funding gap under review'),
    ('CMT-2616','amc_services','2026-05-01',2800000,2800000,0,100.0,'2026-05-31',2,'amc','on_schedule','stable','Sterilizer AMC executed and closed for the year')
  ) as q(cref, bu, pm, cv, ev, oc, bcp, ecd, ag, pt, cs, td, nt);

  -- CAPA seed — attach to specific commitments via commitment_ref
  insert into public.capital_commitment_capa_actions_r3620 (
    commitment_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CMT-2605','budget_gap','budget_shortfall','reallocate_budget','in_progress',400000,'Finance Controller','2026-08-15',null,'Diagnostics budget gap — reallocation from contingency in progress'),
    ('CMT-2607','over_commitment','scope_creep','renegotiate_contract','escalated',1200000,'Procurement Head','2026-08-10',null,'Rollout over-committed — renegotiating phased scope with vendor'),
    ('CMT-2604','execution_delay','vendor_delivery_delay','expedite_vendor','open',150000,'Supply Chain Lead','2026-08-20',null,'Spare-parts delivery slipped — expediting with alternate vendor'),
    ('CMT-2610','budget_gap','forecast_error','revise_forecast','verification_pending',90000,'Category Manager','2026-08-05',null,'Consumables forecast revised; verifying against spare-parts budget'),
    ('CMT-2613','over_commitment','budget_shortfall','rephase_delivery_schedule','open',2000000,'Project Director','2026-09-30',null,'Greenfield open commitment rephased to align with funding'),
    ('CMT-2615','budget_gap','price_escalation','escalate_to_procurement','escalated',520000,'CFO Office','2026-08-25',null,'Cath-lab price escalation — funding gap escalated to board'),
    ('CMT-2601','execution_delay','approval_delay','revise_forecast','closed',0,'PMO','2026-07-20','2026-07-18','CT scanner milestone approval resolved; forecast updated'),
    ('CMT-2609','payment_milestone_slip','contract_amendment','split_commitment','overdue',75000,'Finance Controller','2026-07-15',null,'AMC billing milestone slipped past target date'),
    ('CMT-2611','execution_delay','supplier_capacity_constraint','rephase_delivery_schedule','in_progress',180000,'Procurement Head','2026-08-30',null,'Radiology upgrade phase slip — supplier capacity constrained')
  ) as q(cref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.capital_commitment_r3620 e
    on e.organization_id = v_org_id and e.commitment_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Commitment status distribution
create or replace function public.founder_r3620_commitment_status_rollup()
returns table(commitment_status text, commitments bigint, total_open_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capital_commitment_r3620)
  select l.commitment_status, count(*)::bigint,
         coalesce(sum(l.open_commitment_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.capital_commitment_r3620 l
  group by l.commitment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3620_commitment_status_rollup() from public, anon;
grant execute on function public.founder_r3620_commitment_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3620_business_unit_scorecard()
returns table(
  business_unit text,
  total_commitments bigint,
  contracted_rupees numeric,
  executed_rupees numeric,
  open_rupees numeric,
  over_committed bigint,
  budget_gap bigint,
  avg_budget_covered_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit,
    count(*)::bigint,
    coalesce(sum(l.contracted_value_rupees),0)::numeric,
    coalesce(sum(l.executed_value_rupees),0)::numeric,
    coalesce(sum(l.open_commitment_rupees),0)::numeric,
    count(*) filter (where l.commitment_status = 'over_committed')::bigint,
    count(*) filter (where l.commitment_status = 'budget_gap')::bigint,
    round(avg(l.budget_covered_pct), 1)
  from public.capital_commitment_r3620 l
  group by l.business_unit
  order by coalesce(sum(l.open_commitment_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3620_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3620_business_unit_scorecard() to authenticated;

-- 3) PO-type x commitment-status matrix
create or replace function public.founder_r3620_po_type_status_matrix()
returns table(po_type text, commitment_status text, commitments bigint, total_open_rupees numeric, avg_aging_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.po_type, l.commitment_status, count(*)::bigint,
    coalesce(sum(l.open_commitment_rupees),0)::numeric,
    round(avg(l.aging_days), 1)
  from public.capital_commitment_r3620 l
  group by l.po_type, l.commitment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3620_po_type_status_matrix() from public, anon;
grant execute on function public.founder_r3620_po_type_status_matrix() to authenticated;

-- 4) Monthly commitment trend
create or replace function public.founder_r3620_monthly_commitment_trend()
returns table(period_month date, commitments bigint, contracted_rupees numeric, executed_rupees numeric, open_rupees numeric, over_committed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.contracted_value_rupees),0)::numeric,
    coalesce(sum(l.executed_value_rupees),0)::numeric,
    coalesce(sum(l.open_commitment_rupees),0)::numeric,
    count(*) filter (where l.commitment_status = 'over_committed')::bigint
  from public.capital_commitment_r3620 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3620_monthly_commitment_trend() from public, anon;
grant execute on function public.founder_r3620_monthly_commitment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3620_capa_status_board()
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
  from public.capital_commitment_capa_actions_r3620 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3620_capa_status_board() from public, anon;
grant execute on function public.founder_r3620_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3620_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capital_commitment_capa_actions_r3620)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.capital_commitment_capa_actions_r3620 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3620_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3620_root_cause_pareto() to authenticated;

-- 7) Open-commitment digest (by PO type)
create or replace function public.founder_r3620_open_commitment_digest()
returns table(po_type text, commitments bigint, total_open_rupees numeric, avg_budget_covered_pct numeric, delayed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.po_type, count(*)::bigint,
    coalesce(sum(l.open_commitment_rupees),0)::numeric,
    round(avg(l.budget_covered_pct), 1),
    count(*) filter (where l.commitment_status in ('delayed','over_committed','budget_gap'))::bigint
  from public.capital_commitment_r3620 l
  group by l.po_type
  order by coalesce(sum(l.open_commitment_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3620_open_commitment_digest() from public, anon;
grant execute on function public.founder_r3620_open_commitment_digest() to authenticated;

-- 8) High-risk commitment queue (over_committed / budget_gap)
create or replace function public.founder_r3620_high_risk_queue()
returns table(
  commitment_ref text,
  business_unit text,
  po_type text,
  period_month date,
  contracted_value_rupees numeric,
  open_commitment_rupees numeric,
  budget_covered_pct numeric,
  aging_days integer,
  commitment_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.commitment_ref, l.business_unit, l.po_type, l.period_month,
    l.contracted_value_rupees, l.open_commitment_rupees, l.budget_covered_pct,
    l.aging_days, l.commitment_status, l.notes
  from public.capital_commitment_r3620 l
  where l.commitment_status in ('over_committed','budget_gap','delayed')
     or l.trend_dir = 'worsening'
     or l.aging_days >= 75
  order by l.open_commitment_rupees desc, l.aging_days desc;
end;
$$;

revoke execute on function public.founder_r3620_high_risk_queue() from public, anon;
grant execute on function public.founder_r3620_high_risk_queue() to authenticated;
