-- Round 3389: Founder Driver-Based Rolling-Forecast & Scenario-Planning Board
-- FP&A model — forecast driver × category × current/base/upside/downside values × unit × forecast month × sensitivity-impact × trend × assumption-confidence × driver verdict × CAPA reforecast actions

-- =============================================================================
-- TABLE 1: forecast_driver_r3389 — per driver/line forecast + scenario values
-- =============================================================================
create table if not exists public.forecast_driver_r3389 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  account_name text not null,
  region text not null check (region in (
    'south','north','west','east','pan_india'
  )),
  driver_ref text not null,
  forecast_driver text not null check (forecast_driver in (
    'active_amc_contracts','avg_contract_value','breakdown_call_volume','spare_parts_attach_rate',
    'engineer_utilization','new_hospital_adds','churn_rate','collection_dso'
  )),
  category text not null check (category in (
    'revenue_driver','cost_driver','working_capital','headcount'
  )),
  current_value numeric(14,2) not null,
  base_case_value numeric(14,2) not null,
  upside_case_value numeric(14,2) not null,
  downside_case_value numeric(14,2) not null,
  unit text not null check (unit in (
    'contracts','rupees','pct','days','count'
  )),
  forecast_month text not null,
  sensitivity_impact_rupees numeric(14,2) not null,
  trend text not null check (trend in (
    'improving','stable','worsening'
  )),
  assumption_confidence text not null check (assumption_confidence in (
    'high','medium','low'
  )),
  driver_verdict text not null check (driver_verdict in (
    'on_plan','upside_lever','risk_watch','assumption_review','reforecast_trigger'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.forecast_driver_r3389 enable row level security;

create index if not exists idx_forecast_driver_r3389_org on public.forecast_driver_r3389(organization_id);
create index if not exists idx_forecast_driver_r3389_month on public.forecast_driver_r3389(forecast_month);
create index if not exists idx_forecast_driver_r3389_verdict on public.forecast_driver_r3389(driver_verdict);

-- =============================================================================
-- TABLE 2: forecast_driver_capa_actions_r3389 — assumption-validation / reforecast actions
-- =============================================================================
create table if not exists public.forecast_driver_capa_actions_r3389 (
  id uuid primary key default gen_random_uuid(),
  driver_log_id uuid not null references public.forecast_driver_r3389(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'aggressive_assumption','stale_input','driver_variance','model_error',
    'missing_scenario','sensitivity_understated','data_quality_gap','cadence_slip'
  )),
  root_cause text not null check (root_cause in (
    'optimistic_bias','outdated_actuals','formula_error','missing_driver_linkage',
    'unvalidated_assumption','market_shift','sales_pipeline_slip','pending_investigation','cost_inflation'
  )),
  corrective_action text not null check (corrective_action in (
    'revalidate_assumption','refresh_actuals','fix_model_formula','add_scenario_case',
    'rebuild_driver_link','reforecast_line','escalate_to_board','adjust_sensitivity_band','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  forecast_impact text not null check (forecast_impact in (
    'raises_forecast','lowers_forecast','no_change','widens_variance','timing_shift','board_escalation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.forecast_driver_capa_actions_r3389 enable row level security;

create index if not exists idx_forecast_driver_capa_r3389_log on public.forecast_driver_capa_actions_r3389(driver_log_id);
create index if not exists idx_forecast_driver_capa_r3389_status on public.forecast_driver_capa_actions_r3389(capa_status);

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

  -- 14 driver/line rows
  insert into public.forecast_driver_r3389 (
    organization_id, account_name, region, driver_ref, forecast_driver, category,
    current_value, base_case_value, upside_case_value, downside_case_value, unit,
    forecast_month, sensitivity_impact_rupees, trend, assumption_confidence, driver_verdict, notes
  )
  select v_org_id, q.acct, q.region, q.ref, q.drv, q.cat,
    q.cur, q.base, q.up, q.down, q.unit,
    q.fmonth, q.sens, q.trend, q.conf, q.verdict, q.nt
  from (values
    ('Apollo Chennai','south','FD-APL-01','active_amc_contracts','revenue_driver',
     42,46,50,40,'contracts','2026-09',1800000,'improving','high','on_plan','AMC renewals tracking ahead of base plan'),
    ('Apollo Chennai','south','FD-APL-02','avg_contract_value','revenue_driver',
     285000,300000,320000,270000,'rupees','2026-09',2400000,'stable','high','on_plan','Price uplift on renewals holding at 5 pct'),
    ('Fortis Gurgaon','north','FD-FRT-01','spare_parts_attach_rate','revenue_driver',
     34.00,38.00,44.00,30.00,'pct','2026-09',1250000,'improving','medium','upside_lever','Parts attach climbing on new catalog push'),
    ('Fortis Gurgaon','north','FD-FRT-02','collection_dso','working_capital',
     74,66,58,82,'days','2026-09',1650000,'worsening','medium','risk_watch','DSO slipped after two large hospital delays'),
    ('Manipal Bengaluru','south','FD-MNP-01','engineer_utilization','headcount',
     71.00,78.00,84.00,66.00,'pct','2026-09',980000,'improving','medium','on_plan','Utilization up after zone rebalancing'),
    ('Manipal Bengaluru','south','FD-MNP-02','breakdown_call_volume','cost_driver',
     320,300,270,360,'count','2026-09',720000,'worsening','low','assumption_review','Call-volume assumption may be understated vs trend'),
    ('AIIMS Delhi','north','FD-AIM-01','new_hospital_adds','revenue_driver',
     3,5,8,2,'count','2026-10',3200000,'stable','low','reforecast_trigger','Pipeline slipped, adds at risk for Q3'),
    ('AIIMS Delhi','north','FD-AIM-02','churn_rate','revenue_driver',
     6.50,5.00,3.50,9.00,'pct','2026-10',2100000,'worsening','medium','risk_watch','Two accounts flagged for non-renewal'),
    ('CMC Vellore','south','FD-CMC-01','active_amc_contracts','revenue_driver',
     28,31,35,25,'contracts','2026-09',1100000,'improving','high','upside_lever','Strong renewal intent from biomed team'),
    ('KIMS Hyderabad','south','FD-KIM-01','avg_contract_value','revenue_driver',
     240000,255000,275000,220000,'rupees','2026-10',1400000,'stable','medium','on_plan','Contract value steady on mid-tier mix'),
    ('KIMS Hyderabad','south','FD-KIM-02','engineer_utilization','headcount',
     63.00,75.00,82.00,58.00,'pct','2026-10',1300000,'worsening','low','reforecast_trigger','Two engineers on notice, utilization dropping'),
    ('Portfolio-wide','pan_india','FD-PTF-01','collection_dso','working_capital',
     69,60,54,78,'days','2026-09',2600000,'stable','medium','risk_watch','Blended DSO above 60-day target'),
    ('Portfolio-wide','pan_india','FD-PTF-02','spare_parts_attach_rate','revenue_driver',
     31.00,36.00,42.00,28.00,'pct','2026-11',1900000,'improving','medium','upside_lever','Attach-rate program scaling nationally'),
    ('Portfolio-wide','pan_india','FD-PTF-03','breakdown_call_volume','cost_driver',
     1450,1350,1200,1600,'count','2026-11',1750000,'worsening','low','assumption_review','National call volume trending above model')
  ) as q(acct, region, ref, drv, cat, cur, base, up, down, unit, fmonth, sens, trend, conf, verdict, nt);

  -- CAPA seed — attach to at-risk driver lines via driver_ref
  insert into public.forecast_driver_capa_actions_r3389 (
    driver_log_id, finding_category, root_cause, corrective_action,
    capa_status, forecast_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FD-FRT-02','driver_variance','outdated_actuals','refresh_actuals','in_progress','widens_variance','2026-08-05',null,0.00,'Refresh DSO actuals from AR ledger before month lock'),
    ('FD-AIM-01','aggressive_assumption','sales_pipeline_slip','reforecast_line','escalated','lowers_forecast','2026-08-02',null,0.00,'Pipeline coverage below plan — reforecast adds down'),
    ('FD-AIM-02','sensitivity_understated','market_shift','adjust_sensitivity_band','open','widens_variance','2026-08-10',null,12000.00,'Widen churn sensitivity band for downside case'),
    ('FD-MNP-02','aggressive_assumption','optimistic_bias','revalidate_assumption','open','widens_variance','2026-08-08',null,0.00,'Call-volume assumption optimistic vs trailing 3M actuals'),
    ('FD-KIM-02','driver_variance','unvalidated_assumption','reforecast_line','verification_pending','lowers_forecast','2026-08-04',null,0.00,'Utilization reforecast pending HR headcount confirm'),
    ('FD-PTF-03','model_error','formula_error','fix_model_formula','closed','no_change','2026-07-30','2026-07-28',8000.00,'Fixed double-count in national call-volume rollup'),
    ('FD-PTF-01','stale_input','outdated_actuals','refresh_actuals','overdue','timing_shift','2026-07-15',null,0.00,'Blended DSO input stale — refresh overdue this cycle')
  ) as q(ref, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.forecast_driver_r3389 e
    on e.organization_id = v_org_id and e.driver_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Driver verdict distribution
create or replace function public.founder_r3389_driver_verdict_rollup()
returns table(driver_verdict text, drivers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.forecast_driver_r3389)
  select l.driver_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.forecast_driver_r3389 l
  group by l.driver_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3389_driver_verdict_rollup() from public, anon;
grant execute on function public.founder_r3389_driver_verdict_rollup() to authenticated;

-- 2) Account-level scorecard
create or replace function public.founder_r3389_account_scorecard()
returns table(
  account_name text,
  total_drivers bigint,
  on_plan bigint,
  upside_lever bigint,
  risk_watch bigint,
  reforecast_trigger bigint,
  revenue_drivers bigint,
  cost_drivers bigint,
  total_sensitivity_rupees numeric,
  on_plan_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.account_name,
    count(*)::bigint,
    count(*) filter (where l.driver_verdict = 'on_plan')::bigint,
    count(*) filter (where l.driver_verdict = 'upside_lever')::bigint,
    count(*) filter (where l.driver_verdict = 'risk_watch')::bigint,
    count(*) filter (where l.driver_verdict = 'reforecast_trigger')::bigint,
    count(*) filter (where l.category = 'revenue_driver')::bigint,
    count(*) filter (where l.category = 'cost_driver')::bigint,
    coalesce(sum(l.sensitivity_impact_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.driver_verdict = 'on_plan')::numeric / nullif(count(*),0), 1)
  from public.forecast_driver_r3389 l
  group by l.account_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3389_account_scorecard() from public, anon;
grant execute on function public.founder_r3389_account_scorecard() to authenticated;

-- 3) Forecast month × category matrix
create or replace function public.founder_r3389_month_category_matrix()
returns table(
  forecast_month text,
  category text,
  drivers bigint,
  total_sensitivity_rupees numeric,
  risk_watch bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.forecast_month, l.category, count(*)::bigint,
    coalesce(sum(l.sensitivity_impact_rupees),0)::numeric,
    count(*) filter (where l.driver_verdict in ('risk_watch','assumption_review','reforecast_trigger'))::bigint
  from public.forecast_driver_r3389 l
  group by l.forecast_month, l.category
  order by l.forecast_month, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3389_month_category_matrix() from public, anon;
grant execute on function public.founder_r3389_month_category_matrix() to authenticated;

-- 4) Forecast month trend
create or replace function public.founder_r3389_forecast_month_trend()
returns table(
  forecast_month text,
  drivers bigint,
  on_plan bigint,
  risk_watch bigint,
  reforecast_trigger bigint,
  total_sensitivity_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.forecast_month,
    count(*)::bigint,
    count(*) filter (where l.driver_verdict = 'on_plan')::bigint,
    count(*) filter (where l.driver_verdict = 'risk_watch')::bigint,
    count(*) filter (where l.driver_verdict = 'reforecast_trigger')::bigint,
    coalesce(sum(l.sensitivity_impact_rupees),0)::numeric
  from public.forecast_driver_r3389 l
  group by l.forecast_month
  order by l.forecast_month desc;
end;
$$;

revoke execute on function public.founder_r3389_forecast_month_trend() from public, anon;
grant execute on function public.founder_r3389_forecast_month_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3389_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.forecast_driver_capa_actions_r3389 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3389_capa_status_board() from public, anon;
grant execute on function public.founder_r3389_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3389_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.forecast_driver_capa_actions_r3389)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.forecast_driver_capa_actions_r3389 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3389_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3389_root_cause_pareto() to authenticated;

-- 7) Forecast-impact digest
create or replace function public.founder_r3389_forecast_impact_digest()
returns table(forecast_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.forecast_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.forecast_driver_capa_actions_r3389 c
  group by c.forecast_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3389_forecast_impact_digest() from public, anon;
grant execute on function public.founder_r3389_forecast_impact_digest() to authenticated;

-- 8) High-risk driver queue (top individual concerns)
create or replace function public.founder_r3389_high_risk_queue()
returns table(
  account_name text,
  region text,
  driver_ref text,
  forecast_driver text,
  forecast_month text,
  current_value numeric,
  base_case_value numeric,
  downside_case_value numeric,
  trend text,
  assumption_confidence text,
  driver_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.account_name, l.region, l.driver_ref, l.forecast_driver, l.forecast_month,
    l.current_value, l.base_case_value, l.downside_case_value,
    l.trend, l.assumption_confidence, l.driver_verdict, l.notes
  from public.forecast_driver_r3389 l
  where l.driver_verdict in ('risk_watch','assumption_review','reforecast_trigger')
     or l.trend = 'worsening'
     or l.assumption_confidence = 'low'
  order by l.forecast_month, l.account_name;
end;
$$;

revoke execute on function public.founder_r3389_high_risk_queue() from public, anon;
grant execute on function public.founder_r3389_high_risk_queue() to authenticated;
