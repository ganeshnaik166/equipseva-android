-- Round 3607: Founder Cost of Quality (COQ) — Prevention / Appraisal / Failure Cost Board
-- COQ ledger — business unit × period × prevention × appraisal × internal-failure × external-failure
--   × total COQ × COQ % revenue × target × cost-of-good-quality × cost-of-poor-quality × status × trend × CAPA

-- =============================================================================
-- TABLE 1: coq_cost_r3607 — per business-unit / month cost-of-quality bucket ledger
-- =============================================================================
create table if not exists public.coq_cost_r3607 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  business_unit text not null,
  coq_code text not null,
  period_month date not null,
  prevention_cost_rupees numeric(14,2) not null,
  appraisal_cost_rupees numeric(14,2) not null,
  internal_failure_cost_rupees numeric(14,2) not null,
  external_failure_cost_rupees numeric(14,2) not null,
  total_coq_rupees numeric(16,2) not null,
  coq_as_pct_revenue numeric(6,2),
  target_coq_pct numeric(6,2),
  cost_of_good_quality_rupees numeric(14,2),
  cost_of_poor_quality_rupees numeric(14,2),
  coq_status text not null check (coq_status in (
    'optimized','on_target','elevated','failure_heavy','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.coq_cost_r3607 enable row level security;

create index if not exists idx_coq_cost_r3607_org on public.coq_cost_r3607(organization_id);
create index if not exists idx_coq_cost_r3607_period on public.coq_cost_r3607(period_month);
create index if not exists idx_coq_cost_r3607_status on public.coq_cost_r3607(coq_status);

-- =============================================================================
-- TABLE 2: coq_cost_capa_actions_r3607 — CAPA & cost-reduction actions
-- =============================================================================
create table if not exists public.coq_cost_capa_actions_r3607 (
  id uuid primary key default gen_random_uuid(),
  coq_id uuid not null references public.coq_cost_r3607(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'external_failure_spike','internal_scrap_rework_high','appraisal_underspend','prevention_underinvest',
    'warranty_claim_surge','coq_pct_over_target','field_failure_recurrence','supplier_quality_defect',
    'calibration_rework_cost','training_gap_cost'
  )),
  root_cause text not null check (root_cause in (
    'inadequate_prevention_investment','supplier_component_defect','engineer_skill_gap','process_not_standardized',
    'inspection_coverage_low','design_reliability_issue','spare_parts_quality_issue','pending_investigation',
    'tooling_calibration_drift','documentation_error'
  )),
  corrective_action text not null check (corrective_action in (
    'increase_prevention_training','tighten_incoming_inspection','supplier_corrective_action','standardize_service_process',
    'redesign_reliability_fix','expand_appraisal_coverage','rework_root_cause_fix','recall_and_replace',
    'update_sop_documentation','none_required'
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

alter table public.coq_cost_capa_actions_r3607 enable row level security;

create index if not exists idx_coq_cost_capa_r3607_coq on public.coq_cost_capa_actions_r3607(coq_id);
create index if not exists idx_coq_cost_capa_r3607_status on public.coq_cost_capa_actions_r3607(capa_status);

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

  -- 15 COQ ledger rows
  insert into public.coq_cost_r3607 (
    organization_id, business_unit, coq_code, period_month,
    prevention_cost_rupees, appraisal_cost_rupees, internal_failure_cost_rupees, external_failure_cost_rupees,
    total_coq_rupees, coq_as_pct_revenue, target_coq_pct,
    cost_of_good_quality_rupees, cost_of_poor_quality_rupees, coq_status, trend_dir, notes
  )
  select v_org_id, q.bu, q.ccode, q.pm::date,
    q.prev, q.appr, q.intf, q.extf,
    q.tot, q.pctr, q.tgt,
    q.cogq, q.copq, q.stat, q.trnd, q.nt
  from (values
    ('amc_services','COQ-AMC-2601','2026-01-01',320000,210000,145000,90000,765000,3.6,3.5,530000,235000,'on_target','stable','AMC services COQ near target for the month'),
    ('amc_services','COQ-AMC-2602','2026-02-01',340000,205000,120000,70000,735000,3.3,3.5,545000,190000,'optimized','improving','Preventive-maintenance investment lowering failure cost'),
    ('spare_parts','COQ-SPR-2601','2026-01-01',180000,240000,310000,260000,990000,5.9,4.0,420000,570000,'failure_heavy','worsening','Spare-parts scrap and warranty claims well above target'),
    ('spare_parts','COQ-SPR-2602','2026-02-01',210000,250000,280000,220000,960000,5.5,4.0,460000,500000,'failure_heavy','improving','Supplier CAPA underway but poor-quality cost still elevated'),
    ('projects','COQ-PRJ-2601','2026-01-01',450000,380000,220000,150000,1200000,4.2,4.0,830000,370000,'elevated','stable','Turnkey project commissioning rework driving internal failure'),
    ('projects','COQ-PRJ-2602','2026-02-01',470000,360000,180000,120000,1130000,3.9,4.0,830000,300000,'on_target','improving','Fewer commissioning defects brought COQ back to target'),
    ('diagnostics','COQ-DGN-2601','2026-01-01',260000,300000,95000,60000,715000,3.1,3.2,560000,155000,'optimized','improving','Diagnostics lab QC well controlled, low failure cost'),
    ('diagnostics','COQ-DGN-2602','2026-02-01',250000,290000,130000,110000,780000,3.4,3.2,540000,240000,'elevated','worsening','Reagent recalibration rework raising internal failure cost'),
    ('rentals','COQ-RNT-2601','2026-01-01',140000,160000,240000,310000,850000,6.8,4.5,300000,550000,'critical','worsening','Rental fleet field failures and SLA penalties, prevention underfunded'),
    ('rentals','COQ-RNT-2602','2026-02-01',190000,175000,200000,250000,815000,6.1,4.5,365000,450000,'failure_heavy','improving','Rental downtime penalties easing after prevention top-up'),
    ('amc_services','COQ-AMC-2603','2026-03-01',360000,215000,100000,55000,730000,3.1,3.5,575000,155000,'optimized','improving','Best AMC cost-of-quality month of the quarter'),
    ('spare_parts','COQ-SPR-2603','2026-03-01',230000,260000,240000,180000,910000,5.0,4.0,490000,420000,'elevated','improving','Incoming inspection tightened, scrap trending down'),
    ('projects','COQ-PRJ-2603','2026-03-01',480000,350000,160000,100000,1090000,3.7,4.0,830000,260000,'on_target','stable','Project quality stabilizing with standardized commissioning SOP'),
    ('diagnostics','COQ-DGN-2603','2026-03-01',280000,310000,90000,50000,730000,3.0,3.2,590000,140000,'optimized','improving','Diagnostics COQ under target, appraisal spend efficient'),
    ('rentals','COQ-RNT-2603','2026-03-01',220000,190000,210000,300000,920000,6.5,4.5,410000,510000,'critical','worsening','Rental external failures persist, SLA penalties keep COPQ critical')
  ) as q(bu, ccode, pm, prev, appr, intf, extf, tot, pctr, tgt, cogq, copq, stat, trnd, nt);

  -- CAPA seed — attach to specific ledger rows by coq_code
  insert into public.coq_cost_capa_actions_r3607 (
    coq_id, finding_category, root_cause, corrective_action,
    capa_status, cost_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('COQ-SPR-2601','warranty_claim_surge','supplier_component_defect','supplier_corrective_action','in_progress',570000.00,'Rakesh Menon','2026-03-15',null,'Spare-parts warranty-claim surge — supplier 8D corrective action open'),
    ('COQ-RNT-2601','external_failure_spike','design_reliability_issue','recall_and_replace','escalated',610000.00,'Sunil Katariya','2026-03-01',null,'Rental fleet field-failure spike — reliability recall escalated to OEM'),
    ('COQ-RNT-2603','field_failure_recurrence','inspection_coverage_low','expand_appraisal_coverage','open',300000.00,'Sunil Katariya','2026-04-10',null,'Recurring rental failures, SLA penalties mounting — widen inspection'),
    ('COQ-PRJ-2601','coq_pct_over_target','process_not_standardized','standardize_service_process','verification_pending',220000.00,'Anita Desai','2026-03-20',null,'Commissioning rework over target — SOP standardization in verification'),
    ('COQ-DGN-2602','calibration_rework_cost','tooling_calibration_drift','rework_root_cause_fix','closed',130000.00,'Priya Nair','2026-03-05','2026-02-28','Reagent recalibration root cause fixed and cost verified down'),
    ('COQ-SPR-2602','internal_scrap_rework_high','spare_parts_quality_issue','tighten_incoming_inspection','in_progress',500000.00,'Rakesh Menon','2026-03-25',null,'Incoming inspection tightened, scrap and rework being monitored'),
    ('COQ-RNT-2602','prevention_underinvest','inadequate_prevention_investment','increase_prevention_training','overdue',250000.00,'Sunil Katariya','2026-02-28',null,'Prevention budget top-up and training delayed past target date'),
    ('COQ-AMC-2601','appraisal_underspend','engineer_skill_gap','increase_prevention_training','closed',45000.00,'Deepak Rao','2026-02-15','2026-02-10','Engineer refresher training completed to lift appraisal coverage')
  ) as q(ccode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.coq_cost_r3607 e
    on e.organization_id = v_org_id and e.coq_code = q.ccode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) COQ status distribution
create or replace function public.founder_r3607_coq_status_rollup()
returns table(coq_status text, records bigint, total_coq_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coq_cost_r3607)
  select l.coq_status, count(*)::bigint,
         coalesce(sum(l.total_coq_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.coq_cost_r3607 l
  group by l.coq_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3607_coq_status_rollup() from public, anon;
grant execute on function public.founder_r3607_coq_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3607_business_unit_scorecard()
returns table(
  business_unit text,
  records bigint,
  total_prevention_rupees numeric,
  total_appraisal_rupees numeric,
  total_internal_failure_rupees numeric,
  total_external_failure_rupees numeric,
  total_coq_rupees numeric,
  avg_coq_pct_revenue numeric
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
    coalesce(sum(l.prevention_cost_rupees),0)::numeric,
    coalesce(sum(l.appraisal_cost_rupees),0)::numeric,
    coalesce(sum(l.internal_failure_cost_rupees),0)::numeric,
    coalesce(sum(l.external_failure_cost_rupees),0)::numeric,
    coalesce(sum(l.total_coq_rupees),0)::numeric,
    round(avg(l.coq_as_pct_revenue), 2)
  from public.coq_cost_r3607 l
  group by l.business_unit
  order by coalesce(sum(l.total_coq_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3607_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3607_business_unit_scorecard() to authenticated;

-- 3) Business-unit × COQ-status matrix
create or replace function public.founder_r3607_bu_status_matrix()
returns table(business_unit text, coq_status text, records bigint, total_coq_rupees numeric, avg_coq_pct_revenue numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.coq_status, count(*)::bigint,
    coalesce(sum(l.total_coq_rupees),0)::numeric,
    round(avg(l.coq_as_pct_revenue), 2)
  from public.coq_cost_r3607 l
  group by l.business_unit, l.coq_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3607_bu_status_matrix() from public, anon;
grant execute on function public.founder_r3607_bu_status_matrix() to authenticated;

-- 4) Monthly COQ trend
create or replace function public.founder_r3607_monthly_coq_trend()
returns table(
  period_month date,
  records bigint,
  total_coq_rupees numeric,
  prevention_rupees numeric,
  appraisal_rupees numeric,
  internal_failure_rupees numeric,
  external_failure_rupees numeric
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
    coalesce(sum(l.total_coq_rupees),0)::numeric,
    coalesce(sum(l.prevention_cost_rupees),0)::numeric,
    coalesce(sum(l.appraisal_cost_rupees),0)::numeric,
    coalesce(sum(l.internal_failure_cost_rupees),0)::numeric,
    coalesce(sum(l.external_failure_cost_rupees),0)::numeric
  from public.coq_cost_r3607 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3607_monthly_coq_trend() from public, anon;
grant execute on function public.founder_r3607_monthly_coq_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3607_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
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
  from public.coq_cost_capa_actions_r3607 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3607_capa_status_board() from public, anon;
grant execute on function public.founder_r3607_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3607_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coq_cost_capa_actions_r3607)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.cost_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.coq_cost_capa_actions_r3607 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3607_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3607_root_cause_pareto() to authenticated;

-- 7) Cost-of-poor-quality digest by business unit
create or replace function public.founder_r3607_poor_quality_cost_digest()
returns table(
  business_unit text,
  records bigint,
  total_internal_failure_rupees numeric,
  total_external_failure_rupees numeric,
  total_copq_rupees numeric,
  total_cogq_rupees numeric,
  copq_share_pct numeric
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
    coalesce(sum(l.internal_failure_cost_rupees),0)::numeric,
    coalesce(sum(l.external_failure_cost_rupees),0)::numeric,
    coalesce(sum(l.cost_of_poor_quality_rupees),0)::numeric,
    coalesce(sum(l.cost_of_good_quality_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.cost_of_poor_quality_rupees),0) / nullif(sum(l.total_coq_rupees),0), 1)
  from public.coq_cost_r3607 l
  group by l.business_unit
  order by coalesce(sum(l.cost_of_poor_quality_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3607_poor_quality_cost_digest() from public, anon;
grant execute on function public.founder_r3607_poor_quality_cost_digest() to authenticated;

-- 8) High-risk COQ queue (failure_heavy / critical)
create or replace function public.founder_r3607_high_risk_queue()
returns table(
  business_unit text,
  coq_code text,
  period_month date,
  total_coq_rupees numeric,
  coq_as_pct_revenue numeric,
  target_coq_pct numeric,
  cost_of_poor_quality_rupees numeric,
  coq_status text,
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
  select l.business_unit, l.coq_code, l.period_month, l.total_coq_rupees,
    l.coq_as_pct_revenue, l.target_coq_pct, l.cost_of_poor_quality_rupees,
    l.coq_status, l.trend_dir, l.notes
  from public.coq_cost_r3607 l
  where l.coq_status in ('failure_heavy','critical')
  order by case l.coq_status
             when 'critical' then 0
             when 'failure_heavy' then 1
             else 2
           end,
           l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3607_high_risk_queue() from public, anon;
grant execute on function public.founder_r3607_high_risk_queue() to authenticated;
