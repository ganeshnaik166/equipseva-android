-- Round 3473: Founder Order-Book / Backlog-Coverage & Revenue-Visibility Board
-- Forward revenue visibility per product line × region — order book, backlog, run-rate, coverage months
-- vs target, aged backlog %, coverage status, monthly trend, and CAPA (recovery-action) closure.

-- =============================================================================
-- TABLE 1: order_book_backlog_r3473 — per product-line/region order-book coverage snapshot
-- =============================================================================
create table if not exists public.order_book_backlog_r3473 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  book_code text not null,
  product_line text not null,
  region text not null,
  order_book_value_rupees numeric(16,2) not null,
  backlog_value_rupees numeric(16,2) not null,
  monthly_run_rate_rupees numeric(16,2) not null,
  coverage_months numeric(6,2) not null,
  target_coverage_months numeric(6,2) not null,
  aged_backlog_pct numeric(5,2) not null,
  coverage_status text not null check (coverage_status in (
    'healthy','adequate','thin','critical'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.order_book_backlog_r3473 enable row level security;

create index if not exists idx_order_book_backlog_r3473_org on public.order_book_backlog_r3473(organization_id);
create index if not exists idx_order_book_backlog_r3473_month on public.order_book_backlog_r3473(period_month);
create index if not exists idx_order_book_backlog_r3473_status on public.order_book_backlog_r3473(coverage_status);

-- =============================================================================
-- TABLE 2: order_book_backlog_capa_actions_r3473 — CAPA / revenue-recovery actions
-- =============================================================================
create table if not exists public.order_book_backlog_capa_actions_r3473 (
  id uuid primary key default gen_random_uuid(),
  backlog_id uuid not null references public.order_book_backlog_r3473(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'coverage_below_target','aged_backlog_high','run_rate_decline','order_intake_slowdown',
    'backlog_concentration_risk','delivery_slippage','pricing_erosion','cancellation_risk'
  )),
  root_cause text not null check (root_cause in (
    'demand_softening','supply_chain_delay','sales_pipeline_gap','customer_deferral',
    'competitive_loss','pricing_pressure','capacity_constraint','forecast_error',
    'pending_investigation','credit_hold'
  )),
  corrective_action text not null check (corrective_action in (
    'accelerate_pipeline','expedite_deliveries','reprioritize_backlog','renegotiate_pricing',
    'add_capacity','targeted_promotion','account_recovery_plan','revise_forecast',
    'escalate_to_leadership','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  revenue_impact text not null check (revenue_impact in (
    'revenue_at_risk','revenue_deferred','margin_pressure','none','forecast_reaffirmed','recognition_delay'
  )),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  revenue_at_risk_rupees numeric(16,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.order_book_backlog_capa_actions_r3473 enable row level security;

create index if not exists idx_order_book_backlog_capa_r3473_link on public.order_book_backlog_capa_actions_r3473(backlog_id);
create index if not exists idx_order_book_backlog_capa_r3473_status on public.order_book_backlog_capa_actions_r3473(capa_status);

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

  -- 16 order-book coverage snapshot rows
  insert into public.order_book_backlog_r3473 (
    organization_id, book_code, product_line, region,
    order_book_value_rupees, backlog_value_rupees, monthly_run_rate_rupees,
    coverage_months, target_coverage_months, aged_backlog_pct,
    coverage_status, period_month, trend_dir, notes
  )
  select v_org_id, q.bcode, q.pline, q.region,
    q.obv, q.bkv, q.mrr,
    q.covm, q.tgtm, q.aged,
    q.cstat, q.pmon::date, q.trend, q.nt
  from (values
    ('OB-CTN-01','imaging_ct','north',48500000,29000000,4200000,6.9,6.0,9.5,'healthy','2026-07-01','improving','CT order book strong in north; coverage above target'),
    ('OB-CTS-02','imaging_ct','south',36000000,18000000,3600000,5.0,6.0,14.0,'adequate','2026-07-01','stable','CT south coverage near target; some aging in backlog'),
    ('OB-MRIN-03','imaging_mri','north',62000000,41000000,5200000,7.9,7.0,8.0,'healthy','2026-07-01','improving','MRI north well covered on institutional pipeline'),
    ('OB-MRIW-04','imaging_mri','west',28000000,9000000,4800000,1.9,7.0,22.0,'critical','2026-07-01','worsening','MRI west backlog thin and aging; pipeline gap'),
    ('OB-PMON-05','patient_monitoring','south',21000000,15500000,2600000,6.0,5.0,7.5,'healthy','2026-07-01','stable','Monitoring south healthy coverage vs target'),
    ('OB-PMOE-06','patient_monitoring','east',14000000,6200000,2800000,2.2,5.0,18.0,'thin','2026-07-01','worsening','Monitoring east thin coverage; order intake slowdown'),
    ('OB-VENT-07','ventilators','north',18500000,7400000,3100000,2.4,5.0,26.0,'thin','2026-07-01','worsening','Ventilator backlog aging post-COVID normalization'),
    ('OB-DIAL-08','dialysis_systems','west',33000000,24000000,3400000,7.1,6.0,10.0,'healthy','2026-07-01','improving','Dialysis west strong AMC-linked pipeline'),
    ('OB-SURG-09','surgical_equipment','south',26500000,11000000,3900000,2.8,6.0,16.5,'thin','2026-07-01','stable','Surgical south coverage below target on pricing pressure'),
    ('OB-LABN-10','lab_analyzers','north',31000000,20000000,3200000,6.3,6.0,11.0,'adequate','2026-07-01','stable','Lab analyzers north near target coverage'),
    ('OB-USGE-11','ultrasound','east',12500000,3800000,2400000,1.6,5.0,30.0,'critical','2026-07-01','worsening','Ultrasound east critical; cancellations rising'),
    ('OB-CTN-12','imaging_ct','north',45000000,26000000,4100000,6.3,6.0,12.0,'healthy','2026-06-01','stable','CT north June baseline coverage'),
    ('OB-MRIW-13','imaging_mri','west',27000000,11000000,4700000,2.3,7.0,20.0,'critical','2026-06-01','worsening','MRI west June — same weak coverage trend'),
    ('OB-VENT-14','ventilators','north',19000000,9000000,3000000,3.0,5.0,21.0,'thin','2026-06-01','stable','Ventilator June baseline; aging watch'),
    ('OB-USGE-15','ultrasound','east',13000000,5000000,2450000,2.0,5.0,25.0,'thin','2026-05-01','worsening','Ultrasound east May — deterioration began'),
    ('OB-DIAL-16','dialysis_systems','west',30000000,22000000,3300000,6.7,6.0,9.0,'healthy','2026-05-01','improving','Dialysis west May strong coverage')
  ) as q(bcode, pline, region, obv, bkv, mrr, covm, tgtm, aged, cstat, pmon, trend, nt);

  -- CAPA / revenue-recovery seed — attach to specific lines via book_code
  insert into public.order_book_backlog_capa_actions_r3473 (
    backlog_id, finding_category, root_cause, corrective_action,
    capa_status, revenue_impact, owner, target_closure_date, actual_closure_date,
    revenue_at_risk_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.rar, q.nt
  from (values
    ('OB-MRIW-04','coverage_below_target','sales_pipeline_gap','accelerate_pipeline','in_progress','revenue_at_risk','Rahul Menon (West Sales)','2026-08-15',null,18000000,'MRI west pipeline rebuild; targeting three institutional deals'),
    ('OB-USGE-11','cancellation_risk','competitive_loss','account_recovery_plan','escalated','revenue_at_risk','Sneha Iyer (East Sales)','2026-08-10',null,9000000,'Ultrasound east losing to competitor pricing; recovery plan'),
    ('OB-VENT-07','aged_backlog_high','demand_softening','reprioritize_backlog','open','revenue_deferred','Amit Deshpande (North Ops)','2026-08-20',null,6000000,'Ventilator aged backlog; reprioritize to active firm orders'),
    ('OB-PMOE-06','order_intake_slowdown','sales_pipeline_gap','targeted_promotion','open','revenue_at_risk','Priya Nair (East Sales)','2026-08-18',null,4500000,'Monitoring east targeted promotion to lift intake'),
    ('OB-SURG-09','coverage_below_target','pricing_pressure','renegotiate_pricing','verification_pending','margin_pressure','Vikram Rao (South Sales)','2026-08-05',null,3800000,'Surgical south pricing renegotiation with two hospitals'),
    ('OB-MRIW-13','delivery_slippage','supply_chain_delay','expedite_deliveries','closed','recognition_delay','Rahul Menon (West Ops)','2026-07-05','2026-07-12',5200000,'MRI west deliveries expedited; revenue recognition recovered'),
    ('OB-CTS-02','aged_backlog_high','customer_deferral','revise_forecast','closed','forecast_reaffirmed','Kavya Reddy (South Sales)','2026-07-08','2026-07-15',0,'CT south deferrals confirmed short-term; forecast reaffirmed'),
    ('OB-USGE-15','cancellation_risk','forecast_error','escalate_to_leadership','overdue','revenue_at_risk','Sneha Iyer (East Sales)','2026-07-10',null,7000000,'Ultrasound east flagged since May; escalation now overdue')
  ) as q(bcode, fc, rc, ca, cst, ri, own, tcd, acd, rar, nt)
  join public.order_book_backlog_r3473 e
    on e.organization_id = v_org_id and e.book_code = q.bcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage-status distribution
create or replace function public.founder_r3473_coverage_status_rollup()
returns table(coverage_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.order_book_backlog_r3473)
  select l.coverage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.order_book_backlog_r3473 l
  group by l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3473_coverage_status_rollup() from public, anon;
grant execute on function public.founder_r3473_coverage_status_rollup() to authenticated;

-- 2) Product-line coverage scorecard
create or replace function public.founder_r3473_product_line_scorecard()
returns table(
  product_line text,
  total_lines bigint,
  total_order_book_rupees numeric,
  total_backlog_rupees numeric,
  avg_coverage_months numeric,
  avg_target_coverage_months numeric,
  avg_aged_backlog_pct numeric,
  healthy bigint,
  critical_thin bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line,
    count(*)::bigint,
    coalesce(sum(l.order_book_value_rupees),0)::numeric,
    coalesce(sum(l.backlog_value_rupees),0)::numeric,
    round(avg(l.coverage_months), 2),
    round(avg(l.target_coverage_months), 2),
    round(avg(l.aged_backlog_pct), 2),
    count(*) filter (where l.coverage_status = 'healthy')::bigint,
    count(*) filter (where l.coverage_status in ('thin','critical'))::bigint
  from public.order_book_backlog_r3473 l
  group by l.product_line
  order by coalesce(sum(l.order_book_value_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3473_product_line_scorecard() from public, anon;
grant execute on function public.founder_r3473_product_line_scorecard() to authenticated;

-- 3) Product-line × coverage-status matrix
create or replace function public.founder_r3473_product_line_coverage_matrix()
returns table(product_line text, coverage_status text, lines bigint, total_backlog_rupees numeric, avg_coverage_months numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_line, l.coverage_status, count(*)::bigint,
    coalesce(sum(l.backlog_value_rupees),0)::numeric,
    round(avg(l.coverage_months), 2)
  from public.order_book_backlog_r3473 l
  group by l.product_line, l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3473_product_line_coverage_matrix() from public, anon;
grant execute on function public.founder_r3473_product_line_coverage_matrix() to authenticated;

-- 4) Monthly coverage trend
create or replace function public.founder_r3473_monthly_coverage_trend()
returns table(
  period_month date,
  lines bigint,
  total_order_book_rupees numeric,
  total_backlog_rupees numeric,
  avg_coverage_months numeric,
  critical_thin bigint
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
    coalesce(sum(l.order_book_value_rupees),0)::numeric,
    coalesce(sum(l.backlog_value_rupees),0)::numeric,
    round(avg(l.coverage_months), 2),
    count(*) filter (where l.coverage_status in ('thin','critical'))::bigint
  from public.order_book_backlog_r3473 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3473_monthly_coverage_trend() from public, anon;
grant execute on function public.founder_r3473_monthly_coverage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3473_capa_status_board()
returns table(capa_status text, findings bigint, avg_revenue_at_risk_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.revenue_at_risk_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.order_book_backlog_capa_actions_r3473 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3473_capa_status_board() from public, anon;
grant execute on function public.founder_r3473_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3473_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_revenue_at_risk_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.order_book_backlog_capa_actions_r3473)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.revenue_at_risk_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.order_book_backlog_capa_actions_r3473 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3473_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3473_root_cause_pareto() to authenticated;

-- 7) Revenue-visibility impact digest
create or replace function public.founder_r3473_revenue_impact_digest()
returns table(revenue_impact text, findings bigint, open_findings bigint, total_revenue_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.revenue_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.revenue_at_risk_rupees),0)::numeric
  from public.order_book_backlog_capa_actions_r3473 c
  group by c.revenue_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3473_revenue_impact_digest() from public, anon;
grant execute on function public.founder_r3473_revenue_impact_digest() to authenticated;

-- 8) High-risk coverage queue (critical / thin / aged / worsening)
create or replace function public.founder_r3473_high_risk_queue()
returns table(
  product_line text,
  region text,
  book_code text,
  period_month date,
  coverage_status text,
  coverage_months numeric,
  target_coverage_months numeric,
  aged_backlog_pct numeric,
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
  select l.product_line, l.region, l.book_code, l.period_month,
    l.coverage_status, l.coverage_months, l.target_coverage_months,
    l.aged_backlog_pct, l.trend_dir, l.notes
  from public.order_book_backlog_r3473 l
  where l.coverage_status in ('thin','critical')
     or l.aged_backlog_pct >= 18
     or l.coverage_months < l.target_coverage_months
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.aged_backlog_pct desc;
end;
$$;

revoke execute on function public.founder_r3473_high_risk_queue() from public, anon;
grant execute on function public.founder_r3473_high_risk_queue() to authenticated;
