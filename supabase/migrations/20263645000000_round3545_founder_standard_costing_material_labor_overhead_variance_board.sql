-- Round 3545: Founder Standard-Costing Material/Labor/Overhead Variance Board
-- Standard costing — material/labor/overhead variance analysis (price/usage/efficiency/rate/volume/mix)
-- Main fact: per cost-element variance entry × product line × standard vs actual × variance decomposition × verdict × CAPA

-- =============================================================================
-- TABLE 1: standard_costing_r3545 — per cost-element standard-vs-actual variance entries
-- =============================================================================
create table if not exists public.standard_costing_r3545 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cost_entry_code text not null,
  product_line text not null,
  cost_element text not null check (cost_element in (
    'material','labor','variable_overhead','fixed_overhead'
  )),
  standard_cost_rupees numeric(14,2) not null,
  actual_cost_rupees numeric(14,2) not null,
  total_variance_rupees numeric(14,2) not null,
  price_rate_variance_rupees numeric(14,2),
  usage_efficiency_variance_rupees numeric(14,2),
  variance_pct numeric(6,2),
  variance_driver text not null check (variance_driver in (
    'price','usage','efficiency','rate','volume','mix'
  )),
  variance_type text not null check (variance_type in (
    'favorable','adverse','neutral'
  )),
  cost_center text not null,
  period_month date not null,
  recurring boolean not null,
  reviewed boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.standard_costing_r3545 enable row level security;

create index if not exists idx_standard_costing_r3545_org on public.standard_costing_r3545(organization_id);
create index if not exists idx_standard_costing_r3545_period on public.standard_costing_r3545(period_month);
create index if not exists idx_standard_costing_r3545_type on public.standard_costing_r3545(variance_type);

-- =============================================================================
-- TABLE 2: standard_costing_capa_actions_r3545 — CAPA & corrective actions on variances
-- =============================================================================
create table if not exists public.standard_costing_capa_actions_r3545 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  costing_id uuid not null references public.standard_costing_r3545(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'material_price_overrun','material_usage_excess','labor_rate_overrun','labor_efficiency_loss',
    'overhead_spending_overrun','overhead_volume_shortfall','mix_variance_adverse','yield_loss'
  )),
  root_cause text not null check (root_cause in (
    'supplier_price_hike','scrap_rework_high','overtime_premium','skill_gap_slowdown',
    'machine_downtime','energy_tariff_increase','forecast_volume_miss','spec_change',
    'pending_investigation','procurement_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_supplier_contract','tighten_bom_standards','optimize_shift_scheduling','operator_retraining',
    'preventive_maintenance_plan','energy_efficiency_project','revise_standard_rates','demand_replan',
    'none_required','value_engineering'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  variance_impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.standard_costing_capa_actions_r3545 enable row level security;

create index if not exists idx_standard_costing_capa_r3545_org on public.standard_costing_capa_actions_r3545(organization_id);
create index if not exists idx_standard_costing_capa_r3545_link on public.standard_costing_capa_actions_r3545(costing_id);
create index if not exists idx_standard_costing_capa_r3545_status on public.standard_costing_capa_actions_r3545(capa_status);

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

  -- 16 variance entries
  insert into public.standard_costing_r3545 (
    organization_id, cost_entry_code, product_line, cost_element,
    standard_cost_rupees, actual_cost_rupees, total_variance_rupees,
    price_rate_variance_rupees, usage_efficiency_variance_rupees, variance_pct,
    variance_driver, variance_type, cost_center, period_month, recurring, reviewed, notes
  )
  select v_org_id, q.ecode, q.pline, q.celem,
    q.stdc, q.actc, q.totvar,
    q.prvar, q.uevar, q.vpct,
    q.drv, q.vtype, q.cc, q.pm::date, q.rec, q.rev, q.nt
  from (values
    ('SC-DLY-0601','Dialysis Machines','material',1200000,1290000,90000,70000,20000,7.5,'price','adverse','Assembly-Chennai','2026-06-01',true,true,'Membrane import price hike drove material price variance'),
    ('SC-PMN-0602','Patient Monitors','material',800000,760000,-40000,-10000,-30000,-5.0,'usage','favorable','Electronics-Bengaluru','2026-06-01',false,true,'Yield improvement on display panels cut material usage'),
    ('SC-VNT-0603','Ventilators','labor',450000,495000,45000,35000,10000,10.0,'rate','adverse','Assembly-Pune','2026-06-01',true,true,'Overtime premium pushed labor rate variance adverse'),
    ('SC-INF-0604','Infusion Pumps','labor',300000,285000,-15000,-3000,-12000,-5.0,'efficiency','favorable','Assembly-Chennai','2026-06-01',false,true,'Line balancing improved labor efficiency'),
    ('SC-CRM-0605','C-Arm Imaging','variable_overhead',260000,286000,26000,6000,20000,10.0,'efficiency','adverse','Machining-Pune','2026-05-01',true,true,'Machine downtime inflated variable-overhead efficiency variance'),
    ('SC-ATC-0606','Autoclaves','fixed_overhead',500000,540000,40000,15000,25000,8.0,'volume','adverse','Assembly-Pune','2026-05-01',false,true,'Under-absorption from volume shortfall on autoclave line'),
    ('SC-SGL-0607','Surgical Lights','material',640000,672000,32000,12000,20000,5.0,'mix','adverse','Electronics-Bengaluru','2026-05-01',false,true,'Adverse mix toward premium LED modules'),
    ('SC-ANW-0608','Anesthesia Workstations','labor',520000,494000,-26000,-20000,-6000,-5.0,'rate','favorable','Assembly-Pune','2026-05-01',false,true,'Renegotiated contract-labor rates favorable'),
    ('SC-ECG-0609','ECG Systems','variable_overhead',180000,198000,18000,15000,3000,10.0,'price','adverse','Electronics-Bengaluru','2026-05-01',true,false,'Energy tariff increase raised variable-overhead spending'),
    ('SC-ULT-0610','Ultrasound Scanners','material',900000,903000,3000,3000,0,0.3,'price','neutral','Electronics-Bengaluru','2026-04-01',false,true,'Material price essentially on standard'),
    ('SC-OTT-0611','OT Tables','fixed_overhead',400000,380000,-20000,-5000,-15000,-5.0,'volume','favorable','Machining-Pune','2026-04-01',false,true,'Over-absorption from higher OT-table build volume'),
    ('SC-DEF-0612','Defibrillators','labor',350000,392000,42000,12000,30000,12.0,'efficiency','adverse','Assembly-Chennai','2026-04-01',true,true,'Skill-gap slowdown eroded labor efficiency'),
    ('SC-DLY-0613','Dialysis Machines','material',1200000,1260000,60000,10000,50000,5.0,'usage','adverse','Assembly-Chennai','2026-04-01',true,true,'Excess scrap and rework raised material usage variance'),
    ('SC-PMN-0614','Patient Monitors','variable_overhead',220000,209000,-11000,-2000,-9000,-5.0,'efficiency','favorable','Electronics-Bengaluru','2026-04-01',false,true,'Preventive-maintenance uptime improved overhead efficiency'),
    ('SC-VNT-0615','Ventilators','fixed_overhead',480000,508000,28000,28000,0,5.8,'rate','adverse','Assembly-Pune','2026-04-01',false,false,'Fixed-overhead spending above budgeted rate'),
    ('SC-INF-0616','Infusion Pumps','material',300000,301500,1500,500,1000,0.5,'mix','neutral','Assembly-Chennai','2026-04-01',false,true,'Minor mix drift within tolerance')
  ) as q(ecode, pline, celem, stdc, actc, totvar, prvar, uevar, vpct, drv, vtype, cc, pm, rec, rev, nt);

  -- CAPA seed — attach to specific entries via cost_entry_code
  insert into public.standard_costing_capa_actions_r3545 (
    organization_id, costing_id, finding_category, root_cause, corrective_action,
    capa_status, variance_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SC-DLY-0601','material_price_overrun','supplier_price_hike','renegotiate_supplier_contract','in_progress',90000,'Costing Lead - Chennai','2026-08-15',null,'Dual-sourcing membranes; interim price cap negotiated'),
    ('SC-VNT-0603','labor_rate_overrun','overtime_premium','optimize_shift_scheduling','open',45000,'Plant Manager - Pune','2026-08-10',null,'Rebalancing shift roster to cut overtime on ventilator line'),
    ('SC-CRM-0605','overhead_spending_overrun','machine_downtime','preventive_maintenance_plan','in_progress',26000,'Maintenance Head - Bengaluru','2026-08-20',null,'PM schedule tightened for C-Arm machining cell'),
    ('SC-ATC-0606','overhead_volume_shortfall','forecast_volume_miss','demand_replan','escalated',40000,'S&OP Manager','2026-08-05',null,'Volume shortfall escalated to S&OP for replanning'),
    ('SC-SGL-0607','mix_variance_adverse','spec_change','value_engineering','verification_pending',32000,'Design-to-Cost Lead','2026-07-30',null,'VE study on LED module mix awaiting verification'),
    ('SC-ECG-0609','overhead_spending_overrun','energy_tariff_increase','energy_efficiency_project','open',18000,'Facilities Head','2026-09-01',null,'Energy-efficiency retrofit scoped for Bengaluru plant'),
    ('SC-DEF-0612','labor_efficiency_loss','skill_gap_slowdown','operator_retraining','closed',42000,'Production Supervisor','2026-07-20','2026-07-18','Operator retraining completed; efficiency recovered'),
    ('SC-DLY-0613','material_usage_excess','scrap_rework_high','tighten_bom_standards','overdue',60000,'Quality Lead - Chennai','2026-07-15',null,'BOM/scrap standards revision overdue — pending sign-off')
  ) as q(ecode, fc, rc, ca, cst, impact, own, tcd, acd, nt)
  join public.standard_costing_r3545 e
    on e.organization_id = v_org_id and e.cost_entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Variance-type distribution
create or replace function public.founder_r3545_variance_type_rollup()
returns table(variance_type text, entries bigint, total_variance_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.standard_costing_r3545)
  select l.variance_type, count(*)::bigint,
         coalesce(sum(l.total_variance_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.standard_costing_r3545 l
  group by l.variance_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3545_variance_type_rollup() from public, anon;
grant execute on function public.founder_r3545_variance_type_rollup() to authenticated;

-- 2) Cost-element scorecard
create or replace function public.founder_r3545_cost_element_scorecard()
returns table(
  cost_element text,
  entries bigint,
  adverse bigint,
  favorable bigint,
  neutral bigint,
  total_standard_rupees numeric,
  total_actual_rupees numeric,
  total_variance_rupees numeric,
  adverse_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_element,
    count(*)::bigint,
    count(*) filter (where l.variance_type = 'adverse')::bigint,
    count(*) filter (where l.variance_type = 'favorable')::bigint,
    count(*) filter (where l.variance_type = 'neutral')::bigint,
    coalesce(sum(l.standard_cost_rupees),0)::numeric,
    coalesce(sum(l.actual_cost_rupees),0)::numeric,
    coalesce(sum(l.total_variance_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.variance_type = 'adverse')::numeric / nullif(count(*),0), 1)
  from public.standard_costing_r3545 l
  group by l.cost_element
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3545_cost_element_scorecard() from public, anon;
grant execute on function public.founder_r3545_cost_element_scorecard() to authenticated;

-- 3) Cost-element × variance-driver matrix
create or replace function public.founder_r3545_element_driver_matrix()
returns table(cost_element text, variance_driver text, entries bigint, adverse bigint, total_variance_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cost_element, l.variance_driver, count(*)::bigint,
    count(*) filter (where l.variance_type = 'adverse')::bigint,
    coalesce(sum(l.total_variance_rupees),0)::numeric
  from public.standard_costing_r3545 l
  group by l.cost_element, l.variance_driver
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3545_element_driver_matrix() from public, anon;
grant execute on function public.founder_r3545_element_driver_matrix() to authenticated;

-- 4) Monthly variance trend
create or replace function public.founder_r3545_monthly_variance_trend()
returns table(
  period_month date,
  entries bigint,
  adverse bigint,
  favorable bigint,
  total_variance_rupees numeric,
  price_rate_variance_rupees numeric,
  usage_efficiency_variance_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.variance_type = 'adverse')::bigint,
    count(*) filter (where l.variance_type = 'favorable')::bigint,
    coalesce(sum(l.total_variance_rupees),0)::numeric,
    coalesce(sum(l.price_rate_variance_rupees),0)::numeric,
    coalesce(sum(l.usage_efficiency_variance_rupees),0)::numeric
  from public.standard_costing_r3545 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3545_monthly_variance_trend() from public, anon;
grant execute on function public.founder_r3545_monthly_variance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3545_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.variance_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.standard_costing_capa_actions_r3545 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3545_capa_status_board() from public, anon;
grant execute on function public.founder_r3545_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3545_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.standard_costing_capa_actions_r3545)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.variance_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.standard_costing_capa_actions_r3545 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3545_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3545_root_cause_pareto() to authenticated;

-- 7) Variance-impact digest (by finding category)
create or replace function public.founder_r3545_variance_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.variance_impact_rupees),0)::numeric
  from public.standard_costing_capa_actions_r3545 c
  group by c.finding_category
  order by coalesce(sum(c.variance_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3545_variance_impact_digest() from public, anon;
grant execute on function public.founder_r3545_variance_impact_digest() to authenticated;

-- 8) High-risk variance queue (adverse / large / recurring)
create or replace function public.founder_r3545_high_risk_queue()
returns table(
  product_line text,
  cost_entry_code text,
  cost_element text,
  variance_driver text,
  period_month date,
  variance_type text,
  total_variance_rupees numeric,
  variance_pct numeric,
  recurring boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line, l.cost_entry_code, l.cost_element, l.variance_driver, l.period_month,
    l.variance_type, l.total_variance_rupees, l.variance_pct, l.recurring, l.notes
  from public.standard_costing_r3545 l
  where l.variance_type = 'adverse'
     or l.recurring = true
     or abs(coalesce(l.variance_pct,0)) >= 7.5
     or abs(coalesce(l.total_variance_rupees,0)) >= 40000
  order by abs(coalesce(l.total_variance_rupees,0)) desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3545_high_risk_queue() from public, anon;
grant execute on function public.founder_r3545_high_risk_queue() to authenticated;
