-- Round 3603: Founder CAPEX Plan-vs-Actual / Capital-Budget Utilization Board
-- CAPEX plan-vs-actual log — project × business unit × period × budget × actual × committed × utilization % × variance % × forecast-at-completion × physical progress × capitalized × budget status × trend × CAPA

-- =============================================================================
-- TABLE 1: capex_budget_r3603 — per-project capital-budget utilization records
-- =============================================================================
create table if not exists public.capex_budget_r3603 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_code text not null,
  project_name text not null,
  business_unit text not null,
  period_month date not null,
  capex_budget_rupees numeric(16,2) not null,
  capex_actual_rupees numeric(16,2) not null,
  capex_committed_rupees numeric(16,2) not null,
  budget_utilization_pct numeric(6,2) not null,
  variance_pct numeric(6,2) not null,
  forecast_at_completion_rupees numeric(16,2) not null,
  physical_progress_pct numeric(5,2) not null,
  capitalized_rupees numeric(16,2) not null,
  budget_status text not null check (budget_status in (
    'on_budget','under_spent','over_budget','stalled','reforecast'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capex_budget_r3603 enable row level security;

create index if not exists idx_capex_budget_r3603_org on public.capex_budget_r3603(organization_id);
create index if not exists idx_capex_budget_r3603_period on public.capex_budget_r3603(period_month);
create index if not exists idx_capex_budget_r3603_status on public.capex_budget_r3603(budget_status);

-- =============================================================================
-- TABLE 2: capex_budget_capa_actions_r3603 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.capex_budget_capa_actions_r3603 (
  id uuid primary key default gen_random_uuid(),
  capex_id uuid not null references public.capex_budget_r3603(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'budget_overrun','commitment_exceeds_budget','stalled_project','forecast_overrun',
    'under_utilization','capitalization_delay','scope_creep','vendor_price_escalation',
    'fx_cost_increase','approval_pending'
  )),
  root_cause text not null check (root_cause in (
    'scope_change','vendor_price_escalation','forex_movement','execution_delay',
    'estimation_error','regulatory_change','supply_chain_disruption','funding_constraint',
    'pending_investigation','change_order_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'rebaseline_budget','reforecast_completion','value_engineering','renegotiate_vendor_contract',
    'defer_scope','accelerate_execution','reallocate_capital','escalate_to_board',
    'capitalize_wip','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_severity text not null check (impact_severity in (
    'critical','high','medium','low','negligible'
  )),
  budget_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capex_budget_capa_actions_r3603 enable row level security;

create index if not exists idx_capex_capa_r3603_capex on public.capex_budget_capa_actions_r3603(capex_id);
create index if not exists idx_capex_capa_r3603_status on public.capex_budget_capa_actions_r3603(capa_status);

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

  -- 16 capex project rows
  insert into public.capex_budget_r3603 (
    organization_id, project_code, project_name, business_unit, period_month,
    capex_budget_rupees, capex_actual_rupees, capex_committed_rupees, budget_utilization_pct,
    variance_pct, forecast_at_completion_rupees, physical_progress_pct, capitalized_rupees,
    budget_status, trend_dir, notes
  )
  select v_org_id, q.pcode, q.pname, q.bu, q.pmonth::date,
    q.budg, q.act, q.comm, q.util,
    q.varp, q.fac, q.prog, q.capd,
    q.bstat, q.tdir, q.nt
  from (values
    ('PRJ-CATH-APL-01','Cath Lab Turnkey - Apollo Chennai','projects','2026-07-01',
     45000000,43200000,900000,98.00,-0.90,44600000,96.00,0,'on_budget','stable','OT-integrated cath lab nearing handover; within sanctioned budget'),
    ('PRJ-MOT-FRT-02','Modular OT Build - Fortis Gurgaon','projects','2026-07-01',
     62000000,58000000,9000000,108.10,8.10,67000000,82.00,0,'over_budget','worsening','HVAC and medical-gas change orders pushed FAC 8 pct over sanction'),
    ('DGN-CT-AIM-03','CT 128-Slice Upgrade - AIIMS Delhi','diagnostics','2026-07-01',
     38000000,36500000,500000,97.40,-1.30,37500000,94.00,0,'on_budget','improving','Refurb-to-new CT swap on track for acceptance'),
    ('DGN-PACS-MNP-04','PACS/RIS Rollout - Manipal Cluster','diagnostics','2026-06-01',
     22000000,12000000,3000000,68.20,-15.00,18700000,55.00,0,'under_spent','stable','Multi-site PACS phased slower; capex under-run so far'),
    ('AMC-VAN-STH-05','Service Van Fleet Expansion - South','amc_services','2026-07-01',
     15000000,14200000,300000,96.70,-0.50,14900000,90.00,8000000,'on_budget','improving','12 fitted-out service vans; part-capitalized to fixed assets'),
    ('AMC-TOOL-06','Field Diagnostic Tools Refresh','amc_services','2026-06-01',
     6000000,6800000,200000,116.70,16.70,7000000,100.00,6800000,'over_budget','worsening','Calibrated tool kits pricier post import-duty hike'),
    ('SPR-WMS-PUN-07','Parts Warehouse WMS + Racking - Pune','spare_parts','2026-07-01',
     28000000,9000000,5000000,50.00,-8.00,25800000,40.00,0,'reforecast','improving','WMS go-live rebaselined to Q3; forecast trimmed'),
    ('SPR-DEP-KOL-08','Regional Parts Depot - Kolkata','spare_parts','2026-05-01',
     18000000,3000000,1000000,22.20,0.00,18000000,15.00,0,'stalled','worsening','Depot lease dispute stalled civil works'),
    ('RNT-VENT-09','Ventilator Rental Fleet - Tranche 2','rentals','2026-07-01',
     20000000,19500000,0,97.50,-2.00,19600000,100.00,19500000,'on_budget','stable','60-unit ICU ventilator rental pool commissioned and capitalized'),
    ('RNT-DIAL-10','Dialysis Machine Rental Pool - West','rentals','2026-06-01',
     26000000,27500000,1500000,111.50,11.50,29000000,95.00,24000000,'over_budget','worsening','RO water-plant add-on pushed rental capex over budget'),
    ('PRJ-MRI-YSH-11','MRI 3T Installation - Yashoda Hyderabad','projects','2026-05-01',
     85000000,80000000,3000000,97.60,-2.40,83000000,92.00,0,'on_budget','improving','Magnet install and RF cage complete; ramping to acceptance'),
    ('DGN-CATH-KIM-12','Cath Lab Biplane - KIMS Secunderabad','diagnostics','2026-04-01',
     55000000,60000000,4000000,116.40,16.40,64000000,88.00,0,'over_budget','worsening','Import forex and structural retrofit blew past sanction'),
    ('AMC-CAL-13','Regional Calibration Lab Setup','amc_services','2026-07-01',
     12000000,5000000,4000000,75.00,-6.00,11300000,60.00,0,'under_spent','stable','NABL-scope calibration lab; equipment PO staggered'),
    ('SPR-BUF-14','Spares Buffer Stock Capitalization','spare_parts','2026-06-01',
     9000000,8900000,0,98.90,-0.60,8950000,100.00,8900000,'on_budget','stable','Critical-spare buffer for install base capitalized'),
    ('PRJ-ICU-CAR-15','Modular ICU Turnkey - Care Nagpur','projects','2026-03-01',
     40000000,6000000,2000000,20.00,0.00,40000000,10.00,0,'stalled','worsening','Client financial close pending; mobilization frozen'),
    ('RNT-INF-16','Infusion Pump Rental Pool - East','rentals','2026-07-01',
     7000000,4200000,1200000,77.10,-9.00,6400000,70.00,3000000,'reforecast','improving','Demand softer than plan; forecast reforecast down')
  ) as q(pcode, pname, bu, pmonth, budg, act, comm, util, varp, fac, prog, capd, bstat, tdir, nt);

  -- CAPA seed — attach to specific projects by project_code
  insert into public.capex_budget_capa_actions_r3603 (
    capex_id, finding_category, root_cause, corrective_action,
    capa_status, impact_severity, budget_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.sev, q.imp, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('PRJ-MOT-FRT-02','budget_overrun','scope_change','rebaseline_budget',
     'in_progress','high',5000000,'Rajesh Menon (PMO)','2026-08-15',null,'HVAC/med-gas change orders; rebaseline heading to board'),
    ('DGN-CATH-KIM-12','fx_cost_increase','forex_movement','renegotiate_vendor_contract',
     'escalated','critical',9000000,'Anita Desai (Finance)','2026-07-31',null,'Forex hedge missed; supplementary sanction escalated'),
    ('SPR-DEP-KOL-08','stalled_project','execution_delay','escalate_to_board',
     'escalated','high',0,'Suresh Iyer (Ops)','2026-08-10',null,'Depot lease dispute; legal and board decision needed'),
    ('PRJ-ICU-CAR-15','approval_pending','funding_constraint','defer_scope',
     'open','medium',0,'Priya Nair (PMO)','2026-09-01',null,'Client financial close pending; scope deferred'),
    ('RNT-DIAL-10','scope_creep','scope_change','value_engineering',
     'verification_pending','medium',3000000,'Karthik Rao (Rentals)','2026-07-25',null,'RO plant add-on value-engineering options under review'),
    ('AMC-TOOL-06','vendor_price_escalation','vendor_price_escalation','renegotiate_vendor_contract',
     'closed','low',800000,'Deepa Shetty (AMC)','2026-07-05','2026-07-02','Re-tendered calibrated tool kits; savings locked'),
    ('SPR-WMS-PUN-07','forecast_overrun','estimation_error','reforecast_completion',
     'in_progress','medium',2200000,'Vikram Joshi (SCM)','2026-08-20',null,'WMS scope re-estimated; forecast-at-completion updated'),
    ('DGN-PACS-MNP-04','under_utilization','change_order_backlog','accelerate_execution',
     'open','low',0,'Meera Krishnan (IT)','2026-08-05',null,'Phased PACS lagging plan; accelerate remaining sites')
  ) as q(pcode, fc, rc, ca, cst, sev, imp, ownr, tcd, acd, nt)
  join public.capex_budget_r3603 e
    on e.organization_id = v_org_id and e.project_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Budget-status distribution
create or replace function public.founder_r3603_budget_status_rollup()
returns table(budget_status text, projects bigint, total_budget_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capex_budget_r3603)
  select b.budget_status, count(*)::bigint,
         coalesce(sum(b.capex_budget_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.capex_budget_r3603 b
  group by b.budget_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3603_budget_status_rollup() from public, anon;
grant execute on function public.founder_r3603_budget_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3603_business_unit_scorecard()
returns table(
  business_unit text,
  total_projects bigint,
  on_budget bigint,
  over_budget bigint,
  stalled bigint,
  total_budget_rupees numeric,
  total_actual_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.business_unit,
    count(*)::bigint,
    count(*) filter (where b.budget_status = 'on_budget')::bigint,
    count(*) filter (where b.budget_status = 'over_budget')::bigint,
    count(*) filter (where b.budget_status = 'stalled')::bigint,
    coalesce(sum(b.capex_budget_rupees),0)::numeric,
    coalesce(sum(b.capex_actual_rupees),0)::numeric,
    round(avg(b.budget_utilization_pct), 2)
  from public.capex_budget_r3603 b
  group by b.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3603_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3603_business_unit_scorecard() to authenticated;

-- 3) Business-unit × budget-status matrix
create or replace function public.founder_r3603_bu_status_matrix()
returns table(business_unit text, budget_status text, projects bigint, total_budget_rupees numeric, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.business_unit, b.budget_status, count(*)::bigint,
    coalesce(sum(b.capex_budget_rupees),0)::numeric,
    round(avg(b.variance_pct), 2)
  from public.capex_budget_r3603 b
  group by b.business_unit, b.budget_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3603_bu_status_matrix() from public, anon;
grant execute on function public.founder_r3603_bu_status_matrix() to authenticated;

-- 4) Monthly capex trend
create or replace function public.founder_r3603_monthly_capex_trend()
returns table(
  period_month date,
  projects bigint,
  total_budget_rupees numeric,
  total_actual_rupees numeric,
  total_committed_rupees numeric,
  avg_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.period_month,
    count(*)::bigint,
    coalesce(sum(b.capex_budget_rupees),0)::numeric,
    coalesce(sum(b.capex_actual_rupees),0)::numeric,
    coalesce(sum(b.capex_committed_rupees),0)::numeric,
    round(avg(b.budget_utilization_pct), 2)
  from public.capex_budget_r3603 b
  group by b.period_month
  order by b.period_month desc;
end;
$$;

revoke execute on function public.founder_r3603_monthly_capex_trend() from public, anon;
grant execute on function public.founder_r3603_monthly_capex_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3603_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.budget_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.capex_budget_capa_actions_r3603 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3603_capa_status_board() from public, anon;
grant execute on function public.founder_r3603_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3603_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capex_budget_capa_actions_r3603)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.budget_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.capex_budget_capa_actions_r3603 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3603_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3603_root_cause_pareto() to authenticated;

-- 7) Variance-impact digest
create or replace function public.founder_r3603_variance_impact_digest()
returns table(impact_severity text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.impact_severity, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.budget_impact_rupees),0)::numeric
  from public.capex_budget_capa_actions_r3603 c
  group by c.impact_severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3603_variance_impact_digest() from public, anon;
grant execute on function public.founder_r3603_variance_impact_digest() to authenticated;

-- 8) High-risk capex queue (over_budget / stalled / reforecast)
create or replace function public.founder_r3603_high_risk_queue()
returns table(
  project_name text,
  project_code text,
  business_unit text,
  period_month date,
  budget_status text,
  budget_utilization_pct numeric,
  variance_pct numeric,
  forecast_at_completion_rupees numeric,
  physical_progress_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select b.project_name, b.project_code, b.business_unit, b.period_month,
    b.budget_status, b.budget_utilization_pct, b.variance_pct,
    b.forecast_at_completion_rupees, b.physical_progress_pct, b.notes
  from public.capex_budget_r3603 b
  where b.budget_status in ('over_budget','stalled','reforecast')
     or b.variance_pct > 5
     or b.trend_dir = 'worsening'
  order by case b.budget_status
             when 'over_budget' then 0
             when 'stalled' then 1
             when 'reforecast' then 2
             else 3
           end,
           b.variance_pct desc;
end;
$$;

revoke execute on function public.founder_r3603_high_risk_queue() from public, anon;
grant execute on function public.founder_r3603_high_risk_queue() to authenticated;
