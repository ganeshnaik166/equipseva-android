-- Round 3497: Founder Effective-Tax-Rate (ETR) / Tax-Provision Reconciliation Board
-- Book-vs-tax reconciliation — entity × period × pretax profit × current/deferred/total tax × statutory vs
-- effective rate × rate variance × reconciling item × provision status × trend × CAPA closure

-- =============================================================================
-- TABLE 1: effective_tax_rate_r3497 — per-entity/period tax-provision reconciliation
-- =============================================================================
create table if not exists public.effective_tax_rate_r3497 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity text not null,
  provision_ref text not null,
  period_month date not null,
  pretax_profit_rupees numeric(16,2) not null,
  current_tax_rupees numeric(16,2) not null,
  deferred_tax_rupees numeric(16,2) not null,
  total_tax_rupees numeric(16,2) not null,
  statutory_rate_pct numeric(6,2) not null,
  effective_rate_pct numeric(6,2) not null,
  rate_variance_pct numeric(6,2) not null,
  reconciling_item text not null check (reconciling_item in (
    'permanent_diff','timing_diff','mat_credit','exempt_income','disallowance','prior_period'
  )),
  provision_status text not null check (provision_status in (
    'reconciled','under_provided','over_provided','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.effective_tax_rate_r3497 enable row level security;

create index if not exists idx_effective_tax_rate_r3497_org on public.effective_tax_rate_r3497(organization_id);
create index if not exists idx_effective_tax_rate_r3497_period on public.effective_tax_rate_r3497(period_month);
create index if not exists idx_effective_tax_rate_r3497_status on public.effective_tax_rate_r3497(provision_status);

-- =============================================================================
-- TABLE 2: effective_tax_rate_capa_actions_r3497 — CAPA & reconciliation actions
-- =============================================================================
create table if not exists public.effective_tax_rate_capa_actions_r3497 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provision_id uuid not null references public.effective_tax_rate_r3497(id) on delete cascade,
  provision_ref text not null,
  finding_category text not null check (finding_category in (
    'rate_variance_high','under_provision','deferred_tax_error','mat_credit_unutilized',
    'disallowance_dispute','prior_period_adjustment','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'estimation_error','timing_difference_reversal','tax_law_change','transfer_pricing_adjustment',
    'provision_calculation_error','pending_assessment','system_mapping_error'
  )),
  corrective_action text not null check (corrective_action in (
    'true_up_provision','recompute_deferred_tax','file_revised_return','engage_tax_counsel',
    'update_tp_documentation','reconcile_mat_credit','strengthen_review_control','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  tax_impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.effective_tax_rate_capa_actions_r3497 enable row level security;

create index if not exists idx_effective_tax_rate_capa_r3497_prov on public.effective_tax_rate_capa_actions_r3497(provision_id);
create index if not exists idx_effective_tax_rate_capa_r3497_status on public.effective_tax_rate_capa_actions_r3497(capa_status);

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

  -- 16 provision-reconciliation rows
  insert into public.effective_tax_rate_r3497 (
    organization_id, entity, provision_ref, period_month,
    pretax_profit_rupees, current_tax_rupees, deferred_tax_rupees, total_tax_rupees,
    statutory_rate_pct, effective_rate_pct, rate_variance_pct,
    reconciling_item, provision_status, trend_dir, notes
  )
  select v_org_id, q.ent, q.pref, q.pmonth::date,
    q.pretax, q.curtax, q.deftax, q.tottax,
    q.statrate, q.effrate, q.ratevar,
    q.recitem, q.pstat, q.trd, q.nt
  from (values
    ('EquipSeva Healthcare Pvt Ltd','ETR-EHC-2601','2026-01-01',
     35000000,8600000,500000,9100000,25.17,26.00,0.83,'timing_diff','reconciled','improving','Q4 FY25-26 book-tax reconciliation clean'),
    ('EquipSeva Healthcare Pvt Ltd','ETR-EHC-2602','2026-02-01',
     36200000,8900000,450000,9350000,25.17,25.83,0.66,'permanent_diff','reconciled','stable','CSR spend permanent difference adjusted'),
    ('EquipSeva Healthcare Pvt Ltd','ETR-EHC-2603','2026-03-01',
     41000000,10100000,600000,10700000,25.17,26.10,0.93,'disallowance','under_provided','worsening','Sec 40(a)(ia) TDS disallowance under-provided'),
    ('EquipSeva Diagnostics Ltd','ETR-EDL-2601','2026-01-01',
     22500000,5900000,-300000,5600000,25.17,24.89,-0.28,'mat_credit','over_provided','improving','MAT credit set-off higher than estimate'),
    ('EquipSeva Diagnostics Ltd','ETR-EDL-2602','2026-02-01',
     24000000,6300000,200000,6500000,25.17,27.08,1.91,'disallowance','disputed','worsening','Sec 14A disallowance disputed at CIT(A)'),
    ('EquipSeva Diagnostics Ltd','ETR-EDL-2603','2026-03-01',
     26800000,6800000,350000,7150000,25.17,26.68,1.51,'timing_diff','under_provided','worsening','Depreciation timing difference under-provided'),
    ('EquipSeva Medtech LLP','ETR-EML-2601','2026-01-01',
     15200000,4200000,0,4200000,30.00,27.63,-2.37,'exempt_income','over_provided','improving','LLP slab; exempt partner income excluded'),
    ('EquipSeva Medtech LLP','ETR-EML-2602','2026-02-01',
     16800000,4900000,0,4900000,30.00,29.17,-0.83,'permanent_diff','reconciled','stable','LLP provision reconciled to return'),
    ('EquipSeva Rentals Pvt Ltd','ETR-ERP-2601','2026-01-01',
     18500000,4700000,250000,4950000,25.17,26.76,1.59,'timing_diff','under_provided','worsening','Lease equalisation timing difference'),
    ('EquipSeva Rentals Pvt Ltd','ETR-ERP-2602','2026-02-01',
     19200000,4850000,150000,5000000,25.17,26.04,0.87,'prior_period','disputed','stable','Prior-period rental income tax disputed'),
    ('EquipSeva Labs Pvt Ltd','ETR-ELP-2601','2026-01-01',
     12500000,3200000,100000,3300000,25.17,26.40,1.23,'disallowance','under_provided','worsening','R&D weighted deduction reversed — disallowance'),
    ('EquipSeva Labs Pvt Ltd','ETR-ELP-2602','2026-02-01',
     13800000,3450000,-120000,3330000,25.17,24.13,-1.04,'mat_credit','over_provided','improving','MAT credit utilised on lab income'),
    ('EquipSeva Healthcare Pvt Ltd','ETR-EHC-2604','2026-04-01',
     44000000,10900000,700000,11600000,25.17,26.36,1.19,'permanent_diff','reconciled','stable','Q1 FY26-27 provision reconciled'),
    ('EquipSeva Diagnostics Ltd','ETR-EDL-2604','2026-04-01',
     28900000,7100000,900000,8000000,25.17,27.68,2.51,'timing_diff','disputed','worsening','High deferred tax on WDV difference — disputed'),
    ('EquipSeva Medtech LLP','ETR-EML-2603','2026-03-01',
     17500000,5100000,0,5100000,30.00,29.14,-0.86,'exempt_income','reconciled','improving','Exempt income excluded; provision matches return'),
    ('EquipSeva Rentals Pvt Ltd','ETR-ERP-2603','2026-03-01',
     20100000,5050000,300000,5350000,25.17,26.62,1.45,'prior_period','under_provided','worsening','Prior-period adjustment under-provided')
  ) as q(ent, pref, pmonth, pretax, curtax, deftax, tottax, statrate, effrate, ratevar, recitem, pstat, trd, nt);

  -- CAPA seed — attach to specific provisions via provision_ref
  insert into public.effective_tax_rate_capa_actions_r3497 (
    organization_id, provision_id, provision_ref, finding_category, root_cause, corrective_action,
    capa_status, tax_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.pref, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('ETR-EHC-2603','disallowance_dispute','estimation_error','true_up_provision','in_progress',380000,'Tax Manager','2026-04-30',null,'Sec 40(a)(ia) TDS disallowance under-provided — provision trued up'),
    ('ETR-EDL-2602','disallowance_dispute','pending_assessment','engage_tax_counsel','escalated',640000,'Head of Tax','2026-05-15',null,'Sec 14A disallowance disputed at CIT(A) — counsel engaged'),
    ('ETR-EDL-2603','deferred_tax_error','timing_difference_reversal','recompute_deferred_tax','verification_pending',210000,'Finance Controller','2026-04-20',null,'Depreciation timing difference deferred tax recomputed'),
    ('ETR-ERP-2601','under_provision','provision_calculation_error','true_up_provision','closed',155000,'Tax Manager','2026-03-25','2026-03-22','Lease equalisation provision corrected and closed'),
    ('ETR-ERP-2602','prior_period_adjustment','pending_assessment','file_revised_return','open',92000,'Tax Manager','2026-05-31',null,'Prior-period rental income dispute — revised return under review'),
    ('ETR-EDL-2604','deferred_tax_error','tax_law_change','engage_tax_counsel','escalated',780000,'Head of Tax','2026-06-10',null,'High deferred tax on WDV difference disputed — law-change impact'),
    ('ETR-ELP-2601','disallowance_dispute','provision_calculation_error','strengthen_review_control','in_progress',145000,'Finance Controller','2026-04-15',null,'R&D weighted deduction reversal — review control strengthened'),
    ('ETR-ERP-2603','prior_period_adjustment','provision_calculation_error','true_up_provision','overdue',118000,'Tax Manager','2026-05-20',null,'Prior-period adjustment under-provided — true-up overdue')
  ) as q(pref, fc, rc, ca, cst, impact, own, tcd, acd, nt)
  join public.effective_tax_rate_r3497 e
    on e.organization_id = v_org_id and e.provision_ref = q.pref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Provision status distribution
create or replace function public.founder_r3497_provision_status_rollup()
returns table(provision_status text, provisions bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.effective_tax_rate_r3497)
  select l.provision_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.effective_tax_rate_r3497 l
  group by l.provision_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3497_provision_status_rollup() from public, anon;
grant execute on function public.founder_r3497_provision_status_rollup() to authenticated;

-- 2) Entity-level ETR scorecard
create or replace function public.founder_r3497_entity_scorecard()
returns table(
  entity text,
  total_provisions bigint,
  reconciled bigint,
  under_provided bigint,
  over_provided bigint,
  disputed bigint,
  avg_effective_rate_pct numeric,
  avg_variance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity,
    count(*)::bigint,
    count(*) filter (where l.provision_status = 'reconciled')::bigint,
    count(*) filter (where l.provision_status = 'under_provided')::bigint,
    count(*) filter (where l.provision_status = 'over_provided')::bigint,
    count(*) filter (where l.provision_status = 'disputed')::bigint,
    round(avg(l.effective_rate_pct), 2),
    round(avg(l.rate_variance_pct), 2)
  from public.effective_tax_rate_r3497 l
  group by l.entity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3497_entity_scorecard() from public, anon;
grant execute on function public.founder_r3497_entity_scorecard() to authenticated;

-- 3) Reconciling-item × provision-status matrix
create or replace function public.founder_r3497_reconciling_item_status_matrix()
returns table(reconciling_item text, provision_status text, provisions bigint, avg_variance_pct numeric, total_tax_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.reconciling_item, l.provision_status, count(*)::bigint,
    round(avg(l.rate_variance_pct), 2),
    coalesce(sum(l.total_tax_rupees),0)::numeric
  from public.effective_tax_rate_r3497 l
  group by l.reconciling_item, l.provision_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3497_reconciling_item_status_matrix() from public, anon;
grant execute on function public.founder_r3497_reconciling_item_status_matrix() to authenticated;

-- 4) Monthly ETR trend
create or replace function public.founder_r3497_monthly_etr_trend()
returns table(
  period_month date,
  provisions bigint,
  avg_statutory_rate_pct numeric,
  avg_effective_rate_pct numeric,
  avg_variance_pct numeric,
  total_tax_rupees numeric
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
    round(avg(l.statutory_rate_pct), 2),
    round(avg(l.effective_rate_pct), 2),
    round(avg(l.rate_variance_pct), 2),
    coalesce(sum(l.total_tax_rupees),0)::numeric
  from public.effective_tax_rate_r3497 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3497_monthly_etr_trend() from public, anon;
grant execute on function public.founder_r3497_monthly_etr_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3497_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.tax_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.effective_tax_rate_capa_actions_r3497 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3497_capa_status_board() from public, anon;
grant execute on function public.founder_r3497_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3497_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.effective_tax_rate_capa_actions_r3497)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.tax_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.effective_tax_rate_capa_actions_r3497 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3497_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3497_root_cause_pareto() to authenticated;

-- 7) Tax-impact digest (by finding category)
create or replace function public.founder_r3497_tax_impact_digest()
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
    coalesce(sum(c.tax_impact_rupees),0)::numeric
  from public.effective_tax_rate_capa_actions_r3497 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3497_tax_impact_digest() from public, anon;
grant execute on function public.founder_r3497_tax_impact_digest() to authenticated;

-- 8) High-risk provision queue (under-provided / disputed / high variance)
create or replace function public.founder_r3497_high_risk_queue()
returns table(
  entity text,
  provision_ref text,
  period_month date,
  reconciling_item text,
  provision_status text,
  effective_rate_pct numeric,
  rate_variance_pct numeric,
  total_tax_rupees numeric,
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
  select l.entity, l.provision_ref, l.period_month, l.reconciling_item, l.provision_status,
    l.effective_rate_pct, l.rate_variance_pct, l.total_tax_rupees, l.trend_dir, l.notes
  from public.effective_tax_rate_r3497 l
  where l.provision_status in ('under_provided','disputed')
     or abs(l.rate_variance_pct) >= 1.5
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.entity;
end;
$$;

revoke execute on function public.founder_r3497_high_risk_queue() from public, anon;
grant execute on function public.founder_r3497_high_risk_queue() to authenticated;
