-- Round 3609: Founder Compensation-Ratio / Payroll-Cost Efficiency Board
-- Payroll finance log — department × period × headcount × total comp × revenue × comp-to-revenue ratio ×
-- target ratio × avg cost/head × revenue/head × variable-pay % × attrition × comp-efficiency status × CAPA

-- =============================================================================
-- TABLE 1: comp_ratio_r3609 — per-department monthly compensation-ratio metrics
-- =============================================================================
create table if not exists public.comp_ratio_r3609 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  metric_code text not null,
  department text not null,
  period_month date not null,
  headcount int not null,
  total_comp_rupees numeric(16,2) not null,
  revenue_rupees numeric(16,2) not null,
  comp_to_revenue_pct numeric(6,2) not null,
  target_comp_ratio_pct numeric(6,2) not null,
  avg_cost_per_head_rupees numeric(16,2),
  revenue_per_head_rupees numeric(16,2),
  variable_pay_pct numeric(5,2),
  attrition_pct numeric(5,2),
  comp_status text not null check (comp_status in (
    'efficient','on_target','elevated','over_weight','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.comp_ratio_r3609 enable row level security;

create index if not exists idx_comp_ratio_r3609_org on public.comp_ratio_r3609(organization_id);
create index if not exists idx_comp_ratio_r3609_period on public.comp_ratio_r3609(period_month);
create index if not exists idx_comp_ratio_r3609_status on public.comp_ratio_r3609(comp_status);

-- =============================================================================
-- TABLE 2: comp_ratio_capa_actions_r3609 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.comp_ratio_capa_actions_r3609 (
  id uuid primary key default gen_random_uuid(),
  metric_id uuid not null references public.comp_ratio_r3609(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'comp_ratio_over_target','headcount_over_plan','variable_pay_overrun','revenue_per_head_low',
    'attrition_spike','offer_inflation','contractor_cost_leak','bench_cost_high',
    'promotion_cost_creep','payroll_leakage'
  )),
  root_cause text not null check (root_cause in (
    'aggressive_hiring','revenue_shortfall','wage_inflation','skill_premium_bidding',
    'high_attrition_backfill','bench_underutilization','over_engineered_org',
    'incentive_design_flaw','forex_cost_pressure','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'hiring_freeze','backfill_deferral','variable_pay_recalibration','revenue_ramp_plan',
    'role_consolidation','bench_redeployment','comp_band_revision','automation_investment',
    'outsourcing_shift','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  cost_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.comp_ratio_capa_actions_r3609 enable row level security;

create index if not exists idx_comp_ratio_capa_r3609_metric on public.comp_ratio_capa_actions_r3609(metric_id);
create index if not exists idx_comp_ratio_capa_r3609_status on public.comp_ratio_capa_actions_r3609(capa_status);

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

  -- 16 department-month metric rows
  insert into public.comp_ratio_r3609 (
    organization_id, metric_code, department, period_month, headcount,
    total_comp_rupees, revenue_rupees, comp_to_revenue_pct, target_comp_ratio_pct,
    avg_cost_per_head_rupees, revenue_per_head_rupees, variable_pay_pct, attrition_pct,
    comp_status, trend_dir, notes
  )
  select v_org_id, q.mcode, q.dept, q.pmonth::date, q.hc,
    q.tcomp, q.rev, q.ctr, q.tgt,
    q.cph, q.rph, q.vpp, q.attr,
    q.sts, q.trd, q.nt
  from (values
    ('CR-AMC-2604','amc_services','2026-04-01',42,12600000,84000000,15.00,16.00,300000,2000000,12.0,9.5,
     'efficient','improving','AMC contract book scaling; comp ratio below target'),
    ('CR-AMC-2605','amc_services','2026-05-01',44,13400000,86000000,15.58,16.00,304545,1954545,12.0,10.0,
     'on_target','stable','Steady AMC margins after annual increment cycle'),
    ('CR-AMC-2606','amc_services','2026-06-01',45,14100000,82000000,17.20,16.00,313333,1822222,13.0,12.0,
     'elevated','worsening','Renewal slippage cut revenue and pushed ratio above target'),
    ('CR-SPR-2604','spare_parts','2026-04-01',18,4300000,52000000,8.27,9.00,238889,2888889,8.0,7.0,
     'efficient','stable','Spare-parts trading lean on headcount'),
    ('CR-SPR-2606','spare_parts','2026-06-01',19,4600000,49000000,9.39,9.00,242105,2578947,8.0,8.0,
     'on_target','stable','Parts margin steady; ratio marginally over target'),
    ('CR-PRJ-2604','projects','2026-04-01',30,15000000,60000000,25.00,20.00,500000,2000000,18.0,14.0,
     'over_weight','worsening','Turnkey project delays leaving engineering bench idle'),
    ('CR-PRJ-2605','projects','2026-05-01',31,15500000,55000000,28.18,20.00,500000,1774194,18.0,16.0,
     'critical','worsening','Project revenue slipped; ratio critical with bench cost leaking'),
    ('CR-PRJ-2606','projects','2026-06-01',29,14200000,68000000,20.88,20.00,489655,2344828,17.0,13.0,
     'elevated','improving','Milestone billing recovered; still just above target'),
    ('CR-DIA-2604','diagnostics','2026-04-01',26,7800000,65000000,12.00,13.00,300000,2500000,10.0,9.0,
     'efficient','improving','Diagnostics rentals and reagents scaling well'),
    ('CR-DIA-2606','diagnostics','2026-06-01',27,8300000,63000000,13.17,13.00,307407,2333333,10.0,10.0,
     'on_target','stable','Diagnostics segment on plan'),
    ('CR-RNT-2604','rentals','2026-04-01',14,3600000,40000000,9.00,11.00,257143,2857143,7.0,6.0,
     'efficient','stable','Equipment rental fleet high asset-yield, low comp load'),
    ('CR-RNT-2606','rentals','2026-06-01',15,3900000,38000000,10.26,11.00,260000,2533333,7.0,7.0,
     'efficient','stable','Rentals remain lean and efficient'),
    ('CR-FLD-2605','field_service','2026-05-01',60,21000000,96000000,21.87,19.00,350000,1600000,15.0,18.0,
     'over_weight','worsening','Field-service attrition backfill inflated payroll'),
    ('CR-FLD-2606','field_service','2026-06-01',58,20200000,99000000,20.40,19.00,348276,1706897,15.0,16.0,
     'elevated','improving','Attrition easing; ratio trending back toward target'),
    ('CR-SLS-2605','sales','2026-05-01',22,9900000,45000000,22.00,18.00,450000,2045455,30.0,15.0,
     'over_weight','worsening','Sales incentive overrun against a soft order book'),
    ('CR-COR-2606','corporate','2026-06-01',25,11250000,30000000,37.50,12.00,450000,1200000,20.0,8.0,
     'critical','worsening','Corporate overhead cost center; ratio high by design, under review')
  ) as q(mcode, dept, pmonth, hc, tcomp, rev, ctr, tgt, cph, rph, vpp, attr, sts, trd, nt);

  -- CAPA seed — attach to specific metric rows by metric_code
  insert into public.comp_ratio_capa_actions_r3609 (
    metric_id, finding_category, root_cause, corrective_action,
    capa_status, cost_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CR-PRJ-2605','comp_ratio_over_target','revenue_shortfall','revenue_ramp_plan',
     'escalated',2500000,'CFO Office','2026-07-31',null,'Projects ratio critical; revenue-ramp plan tabled to board'),
    ('CR-PRJ-2604','bench_cost_high','bench_underutilization','bench_redeployment',
     'in_progress',1200000,'Projects Head','2026-07-15',null,'Idle engineers being redeployed to AMC backlog'),
    ('CR-FLD-2605','attrition_spike','high_attrition_backfill','comp_band_revision',
     'in_progress',900000,'Service Ops','2026-07-20',null,'Backfill wages above band; revising field-engineer bands'),
    ('CR-SLS-2605','variable_pay_overrun','incentive_design_flaw','variable_pay_recalibration',
     'verification_pending',700000,'Sales Finance','2026-07-10',null,'Reworking incentive slabs to gate payout on collections'),
    ('CR-COR-2606','payroll_leakage','over_engineered_org','role_consolidation',
     'open',1500000,'CHRO','2026-08-05',null,'Corporate overhead review; consolidating overlapping roles'),
    ('CR-AMC-2606','revenue_per_head_low','revenue_shortfall','revenue_ramp_plan',
     'closed',0,'AMC Head','2026-06-30','2026-06-28','Renewal desk added; revenue-per-head restored'),
    ('CR-SPR-2606','comp_ratio_over_target','wage_inflation','comp_band_revision',
     'overdue',300000,'Parts Lead','2026-06-25',null,'Band revision slipped past target date'),
    ('CR-DIA-2606','headcount_over_plan','aggressive_hiring','hiring_freeze',
     'closed',0,'Diagnostics Head','2026-06-20','2026-06-18','Two open reqs frozen; headcount aligned to plan')
  ) as q(mcode, fc, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.comp_ratio_r3609 e
    on e.organization_id = v_org_id and e.metric_code = q.mcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Comp-status distribution
create or replace function public.founder_r3609_comp_status_rollup()
returns table(comp_status text, records bigint, total_headcount bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.comp_ratio_r3609)
  select r.comp_status, count(*)::bigint,
         coalesce(sum(r.headcount),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.comp_ratio_r3609 r
  group by r.comp_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3609_comp_status_rollup() from public, anon;
grant execute on function public.founder_r3609_comp_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3609_department_scorecard()
returns table(
  department text,
  periods bigint,
  total_headcount bigint,
  total_comp_rupees numeric,
  total_revenue_rupees numeric,
  blended_comp_to_revenue_pct numeric,
  avg_revenue_per_head_rupees numeric,
  over_weight_periods bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.department,
    count(*)::bigint,
    coalesce(sum(r.headcount),0)::bigint,
    coalesce(sum(r.total_comp_rupees),0)::numeric,
    coalesce(sum(r.revenue_rupees),0)::numeric,
    round(100.0 * coalesce(sum(r.total_comp_rupees),0) / nullif(sum(r.revenue_rupees),0), 2),
    round(avg(r.revenue_per_head_rupees), 0),
    count(*) filter (where r.comp_status in ('over_weight','critical'))::bigint
  from public.comp_ratio_r3609 r
  group by r.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3609_department_scorecard() from public, anon;
grant execute on function public.founder_r3609_department_scorecard() to authenticated;

-- 3) Department × comp-status matrix
create or replace function public.founder_r3609_department_status_matrix()
returns table(department text, comp_status text, records bigint, total_headcount bigint, avg_comp_to_revenue_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.department, r.comp_status, count(*)::bigint,
    coalesce(sum(r.headcount),0)::bigint,
    round(avg(r.comp_to_revenue_pct), 2)
  from public.comp_ratio_r3609 r
  group by r.department, r.comp_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3609_department_status_matrix() from public, anon;
grant execute on function public.founder_r3609_department_status_matrix() to authenticated;

-- 4) Monthly comp-ratio trend
create or replace function public.founder_r3609_monthly_comp_ratio_trend()
returns table(
  period_month date,
  records bigint,
  total_comp_rupees numeric,
  total_revenue_rupees numeric,
  blended_comp_to_revenue_pct numeric,
  avg_attrition_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.period_month,
    count(*)::bigint,
    coalesce(sum(r.total_comp_rupees),0)::numeric,
    coalesce(sum(r.revenue_rupees),0)::numeric,
    round(100.0 * coalesce(sum(r.total_comp_rupees),0) / nullif(sum(r.revenue_rupees),0), 2),
    round(avg(r.attrition_pct), 1)
  from public.comp_ratio_r3609 r
  group by r.period_month
  order by r.period_month desc;
end;
$$;

revoke execute on function public.founder_r3609_monthly_comp_ratio_trend() from public, anon;
grant execute on function public.founder_r3609_monthly_comp_ratio_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3609_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.cost_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.comp_ratio_capa_actions_r3609 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3609_capa_status_board() from public, anon;
grant execute on function public.founder_r3609_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3609_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.comp_ratio_capa_actions_r3609)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.comp_ratio_capa_actions_r3609 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3609_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3609_root_cause_pareto() to authenticated;

-- 7) Payroll-cost digest (per-department cost efficiency)
create or replace function public.founder_r3609_payroll_cost_digest()
returns table(
  department text,
  total_headcount bigint,
  total_comp_rupees numeric,
  total_revenue_rupees numeric,
  comp_to_revenue_pct numeric,
  avg_cost_per_head_rupees numeric,
  revenue_per_head_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.department,
    coalesce(sum(r.headcount),0)::bigint,
    coalesce(sum(r.total_comp_rupees),0)::numeric,
    coalesce(sum(r.revenue_rupees),0)::numeric,
    round(100.0 * coalesce(sum(r.total_comp_rupees),0) / nullif(sum(r.revenue_rupees),0), 2),
    round(coalesce(sum(r.total_comp_rupees),0) / nullif(sum(r.headcount),0), 0),
    round(coalesce(sum(r.revenue_rupees),0) / nullif(sum(r.headcount),0), 0)
  from public.comp_ratio_r3609 r
  group by r.department
  order by coalesce(sum(r.total_comp_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3609_payroll_cost_digest() from public, anon;
grant execute on function public.founder_r3609_payroll_cost_digest() to authenticated;

-- 8) High-risk queue (over_weight / critical metrics)
create or replace function public.founder_r3609_high_risk_queue()
returns table(
  department text,
  metric_code text,
  period_month date,
  headcount int,
  comp_to_revenue_pct numeric,
  target_comp_ratio_pct numeric,
  revenue_per_head_rupees numeric,
  attrition_pct numeric,
  comp_status text,
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
  select r.department, r.metric_code, r.period_month, r.headcount,
    r.comp_to_revenue_pct, r.target_comp_ratio_pct, r.revenue_per_head_rupees,
    r.attrition_pct, r.comp_status, r.trend_dir, r.notes
  from public.comp_ratio_r3609 r
  where r.comp_status in ('over_weight','critical')
     or r.comp_to_revenue_pct > r.target_comp_ratio_pct
     or r.trend_dir = 'worsening'
  order by case r.comp_status
             when 'critical' then 0
             when 'over_weight' then 1
             when 'elevated' then 2
             else 3
           end,
           r.comp_to_revenue_pct desc;
end;
$$;

revoke execute on function public.founder_r3609_high_risk_queue() from public, anon;
grant execute on function public.founder_r3609_high_risk_queue() to authenticated;
