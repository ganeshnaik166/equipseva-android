-- Round 3469: Founder Revenue-per-FTE / Employee-Productivity Efficiency Board
-- Per department/function — headcount FTE × revenue × revenue-per-FTE × target × gross-profit-per-FTE
-- × utilization × productivity status × monthly trend × CAPA closure

-- =============================================================================
-- TABLE 1: revenue_per_fte_r3469 — per-department/function productivity fact table
-- =============================================================================
create table if not exists public.revenue_per_fte_r3469 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  record_code text not null,
  department text not null,
  function_area text not null,
  headcount_fte numeric(8,2) not null,
  revenue_rupees numeric(16,2) not null,
  revenue_per_fte_rupees numeric(16,2) not null,
  target_rev_per_fte_rupees numeric(16,2) not null,
  gross_profit_per_fte_rupees numeric(16,2),
  utilization_pct numeric(5,2),
  productivity_status text not null check (productivity_status in (
    'above_target','on_target','below_target','critical_low'
  )),
  period_month date not null,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.revenue_per_fte_r3469 enable row level security;

create index if not exists idx_revenue_per_fte_r3469_org on public.revenue_per_fte_r3469(organization_id);
create index if not exists idx_revenue_per_fte_r3469_period on public.revenue_per_fte_r3469(period_month);
create index if not exists idx_revenue_per_fte_r3469_status on public.revenue_per_fte_r3469(productivity_status);

-- =============================================================================
-- TABLE 2: revenue_per_fte_capa_actions_r3469 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.revenue_per_fte_capa_actions_r3469 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  fte_record_id uuid references public.revenue_per_fte_r3469(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'below_target_revenue_per_fte','low_utilization','critical_low_productivity',
    'gross_profit_erosion','headcount_overstaffing','declining_trend','target_miss'
  )),
  root_cause text not null check (root_cause in (
    'overstaffing','skill_gap','low_billable_utilization','pricing_pressure',
    'attrition_backfill_lag','process_inefficiency','demand_shortfall',
    'tooling_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'rebalance_headcount','upskill_training','improve_utilization_tracking','reprice_contracts',
    'hiring_freeze','automation_investment','realign_territory','process_reengineering','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  productivity_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.revenue_per_fte_capa_actions_r3469 enable row level security;

create index if not exists idx_revenue_per_fte_capa_r3469_rec on public.revenue_per_fte_capa_actions_r3469(fte_record_id);
create index if not exists idx_revenue_per_fte_capa_r3469_status on public.revenue_per_fte_capa_actions_r3469(capa_status);

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

  -- 16 productivity rows
  insert into public.revenue_per_fte_r3469 (
    organization_id, record_code, department, function_area, headcount_fte,
    revenue_rupees, revenue_per_fte_rupees, target_rev_per_fte_rupees,
    gross_profit_per_fte_rupees, utilization_pct, productivity_status,
    period_month, trend_dir, notes
  )
  select v_org_id, q.rcode, q.dept, q.farea, q.hc,
    q.rev, q.rpf, q.trpf,
    q.gppf, q.util, q.pst,
    q.pm::date, q.td, q.nt
  from (values
    ('RPF-FS-01','Field Service','Biomedical Engineering',24,96000000,4000000,4500000,1400000,82,'below_target','2026-06-01','worsening','Field service billable hours below plan this month'),
    ('RPF-FS-02','Field Service','Biomedical Engineering',24,108000000,4500000,4500000,1600000,85,'on_target','2026-05-01','improving','Field service back on target after AMC uplift'),
    ('RPF-SL-01','Sales','Enterprise Hospital',12,180000000,15000000,12000000,5200000,78,'above_target','2026-06-01','improving','Enterprise deal closures ahead of target'),
    ('RPF-SL-02','Sales','Government Tenders',8,64000000,8000000,11000000,2100000,70,'below_target','2026-06-01','worsening','Government tender cycle slow, revenue-per-head lagging'),
    ('RPF-SP-01','Spare Parts','Supply Chain',10,42000000,4200000,5000000,900000,74,'below_target','2026-06-01','stable','Spare parts fulfilment below target on margin'),
    ('RPF-AMC-01','AMC Contracts','Contract Renewals',9,81000000,9000000,8000000,3400000,88,'above_target','2026-06-01','improving','AMC renewal engine outperforming plan'),
    ('RPF-CS-01','Customer Support','Call Center',18,27000000,1500000,2000000,300000,91,'critical_low','2026-06-01','worsening','Call center revenue-per-FTE critically low vs headcount'),
    ('RPF-IC-01','Installation','Commissioning',14,70000000,5000000,5000000,1500000,80,'on_target','2026-06-01','stable','Installation and commissioning meeting plan'),
    ('RPF-CAL-01','Calibration Lab','Metrology',6,21000000,3500000,4000000,1100000,76,'below_target','2026-06-01','stable','Calibration lab utilization below plan'),
    ('RPF-PRD-01','Product','Software Platform',11,33000000,3000000,6000000,800000,68,'critical_low','2026-06-01','worsening','Product platform monetization gap widening'),
    ('RPF-FIN-01','Finance and Ops','Shared Services',7,14000000,2000000,2500000,400000,84,'below_target','2026-06-01','stable','Shared services revenue-per-FTE marginally low'),
    ('RPF-MKT-01','Marketing','Demand Gen',5,20000000,4000000,3500000,1200000,79,'above_target','2026-06-01','improving','Marketing demand-gen driving pipeline efficiency'),
    ('RPF-FS-03','Field Service','Radiology Service',16,88000000,5500000,5000000,1900000,83,'above_target','2026-06-01','improving','Radiology service line strong revenue-per-engineer'),
    ('RPF-SL-03','Sales','Enterprise Hospital',12,156000000,13000000,12000000,4600000,81,'above_target','2026-05-01','stable','Enterprise sales sustaining above-target output'),
    ('RPF-CS-02','Customer Support','Call Center',18,30600000,1700000,2000000,350000,89,'below_target','2026-05-01','improving','Call center trending up but still below target'),
    ('RPF-SP-02','Spare Parts','Supply Chain',10,38000000,3800000,5000000,750000,72,'critical_low','2026-05-01','worsening','Spare parts margin critically low amid pricing pressure')
  ) as q(rcode, dept, farea, hc, rev, rpf, trpf, gppf, util, pst, pm, td, nt);

  -- CAPA seed — attach to specific records via record_code
  insert into public.revenue_per_fte_capa_actions_r3469 (
    organization_id, fte_record_id, finding_category, root_cause, corrective_action,
    capa_status, productivity_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('RPF-FS-01','below_target_revenue_per_fte','low_billable_utilization','improve_utilization_tracking','in_progress',2400000,'Rahul Mehta (Service Head)','2026-08-15',null,'Field service billable hours below plan — dispatch tracking rollout'),
    ('RPF-SL-02','target_miss','demand_shortfall','realign_territory','open',3600000,'Priya Nair (Sales Director)','2026-08-20',null,'Government tender cycle slow — territory realignment underway'),
    ('RPF-CS-01','critical_low_productivity','overstaffing','rebalance_headcount','escalated',5200000,'Anil Kumar (Support Lead)','2026-08-10',null,'Call center revenue-per-FTE critical — headcount vs volume mismatch'),
    ('RPF-PRD-01','critical_low_productivity','tooling_gap','automation_investment','open',6800000,'Sneha Rao (Product Head)','2026-09-01',null,'Product monetization gap — platform automation roadmap'),
    ('RPF-SP-01','below_target_revenue_per_fte','process_inefficiency','process_reengineering','verification_pending',1500000,'Vikram Shah (SCM Manager)','2026-08-05',null,'Spare parts fulfilment reengineered — verifying uplift'),
    ('RPF-CAL-01','low_utilization','skill_gap','upskill_training','open',900000,'Deepa Iyer (Lab Manager)','2026-08-25',null,'Calibration lab utilization low — cross-skilling technicians'),
    ('RPF-FIN-01','below_target_revenue_per_fte','process_inefficiency','automation_investment','closed',600000,'Meera Joshi (Finance Controller)','2026-07-10','2026-07-18','Shared-services automation deployed — impact realized'),
    ('RPF-SP-02','critical_low_productivity','pricing_pressure','reprice_contracts','overdue',3100000,'Vikram Shah (SCM Manager)','2026-07-05',null,'Spare parts margin critical — repricing overdue in vendor negotiation')
  ) as q(rcode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.revenue_per_fte_r3469 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Productivity status distribution
create or replace function public.founder_r3469_productivity_status_rollup()
returns table(productivity_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.revenue_per_fte_r3469)
  select l.productivity_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.revenue_per_fte_r3469 l
  group by l.productivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3469_productivity_status_rollup() from public, anon;
grant execute on function public.founder_r3469_productivity_status_rollup() to authenticated;

-- 2) Department scorecard
create or replace function public.founder_r3469_department_scorecard()
returns table(
  department text,
  entries bigint,
  above_target bigint,
  on_target bigint,
  below_target bigint,
  critical_low bigint,
  avg_rev_per_fte_rupees numeric,
  avg_util_pct numeric,
  on_target_or_better_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department,
    count(*)::bigint,
    count(*) filter (where l.productivity_status = 'above_target')::bigint,
    count(*) filter (where l.productivity_status = 'on_target')::bigint,
    count(*) filter (where l.productivity_status = 'below_target')::bigint,
    count(*) filter (where l.productivity_status = 'critical_low')::bigint,
    round(avg(l.revenue_per_fte_rupees), 0),
    round(avg(l.utilization_pct), 1),
    round(100.0 * count(*) filter (where l.productivity_status in ('above_target','on_target'))::numeric / nullif(count(*),0), 1)
  from public.revenue_per_fte_r3469 l
  group by l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3469_department_scorecard() from public, anon;
grant execute on function public.founder_r3469_department_scorecard() to authenticated;

-- 3) Department × productivity-status matrix
create or replace function public.founder_r3469_department_status_matrix()
returns table(
  department text,
  productivity_status text,
  entries bigint,
  avg_rev_per_fte_rupees numeric,
  avg_gross_profit_per_fte_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.department, l.productivity_status, count(*)::bigint,
    round(avg(l.revenue_per_fte_rupees), 0),
    round(avg(l.gross_profit_per_fte_rupees), 0)
  from public.revenue_per_fte_r3469 l
  group by l.department, l.productivity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3469_department_status_matrix() from public, anon;
grant execute on function public.founder_r3469_department_status_matrix() to authenticated;

-- 4) Monthly revenue-per-FTE trend
create or replace function public.founder_r3469_monthly_rev_per_fte_trend()
returns table(
  period_month date,
  entries bigint,
  total_headcount_fte numeric,
  total_revenue_rupees numeric,
  avg_rev_per_fte_rupees numeric,
  below_target bigint,
  critical_low bigint
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
    round(sum(l.headcount_fte), 2),
    coalesce(sum(l.revenue_rupees),0)::numeric,
    round(avg(l.revenue_per_fte_rupees), 0),
    count(*) filter (where l.productivity_status = 'below_target')::bigint,
    count(*) filter (where l.productivity_status = 'critical_low')::bigint
  from public.revenue_per_fte_r3469 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3469_monthly_rev_per_fte_trend() from public, anon;
grant execute on function public.founder_r3469_monthly_rev_per_fte_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3469_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.productivity_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.revenue_per_fte_capa_actions_r3469 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3469_capa_status_board() from public, anon;
grant execute on function public.founder_r3469_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3469_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.revenue_per_fte_capa_actions_r3469)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.productivity_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.revenue_per_fte_capa_actions_r3469 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3469_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3469_root_cause_pareto() to authenticated;

-- 7) Productivity-impact digest (by finding category)
create or replace function public.founder_r3469_productivity_impact_digest()
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
    coalesce(sum(c.productivity_impact_rupees),0)::numeric
  from public.revenue_per_fte_capa_actions_r3469 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3469_productivity_impact_digest() from public, anon;
grant execute on function public.founder_r3469_productivity_impact_digest() to authenticated;

-- 8) High-risk productivity queue (critical-low / below-target / worsening)
create or replace function public.founder_r3469_high_risk_queue()
returns table(
  department text,
  function_area text,
  record_code text,
  period_month date,
  productivity_status text,
  revenue_per_fte_rupees numeric,
  target_rev_per_fte_rupees numeric,
  utilization_pct numeric,
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
  select l.department, l.function_area, l.record_code, l.period_month,
    l.productivity_status, l.revenue_per_fte_rupees, l.target_rev_per_fte_rupees,
    l.utilization_pct, l.trend_dir, l.notes
  from public.revenue_per_fte_r3469 l
  where l.productivity_status in ('critical_low','below_target')
     or l.trend_dir = 'worsening'
     or l.revenue_per_fte_rupees < l.target_rev_per_fte_rupees
  order by l.period_month desc, l.department;
end;
$$;

revoke execute on function public.founder_r3469_high_risk_queue() from public, anon;
grant execute on function public.founder_r3469_high_risk_queue() to authenticated;
