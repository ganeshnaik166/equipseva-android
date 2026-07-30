-- Round 3608: Founder Credit-Note / Debit-Note / Billing-Adjustment Reconciliation Board
-- Founder finance — credit-note / debit-note / billing-adjustment reconciliation + adjustment leakage
-- per business unit × period × credit/debit values × gross sales × adjustment % × returns × pricing errors ×
-- unapproved value × adjustment status × trend × CAPA closure.

-- =============================================================================
-- TABLE 1: credit_note_r3608 — per-business-unit monthly billing-adjustment fact
-- =============================================================================
create table if not exists public.credit_note_r3608 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  adjustment_ref text not null,
  business_unit text not null,
  period_month date not null,
  credit_notes_count int not null,
  credit_notes_value_rupees numeric(14,2) not null,
  debit_notes_count int not null,
  debit_notes_value_rupees numeric(14,2) not null,
  gross_sales_rupees numeric(14,2) not null,
  adjustment_pct numeric(6,2),
  returns_value_rupees numeric(14,2),
  pricing_error_value_rupees numeric(14,2),
  unapproved_value_rupees numeric(14,2),
  adjustment_status text not null check (adjustment_status in (
    'clean','minor','elevated','leakage_risk','control_gap'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.credit_note_r3608 enable row level security;

create index if not exists idx_credit_note_r3608_org on public.credit_note_r3608(organization_id);
create index if not exists idx_credit_note_r3608_month on public.credit_note_r3608(period_month);
create index if not exists idx_credit_note_r3608_status on public.credit_note_r3608(adjustment_status);

-- =============================================================================
-- TABLE 2: credit_note_capa_actions_r3608 — CAPA & leakage remediation actions
-- =============================================================================
create table if not exists public.credit_note_capa_actions_r3608 (
  id uuid primary key default gen_random_uuid(),
  adjustment_log_id uuid not null references public.credit_note_r3608(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'unapproved_credit_note','pricing_error','duplicate_billing','returns_not_reconciled',
    'tax_adjustment_error','post_sale_discount_leakage','debit_note_shortfall',
    'manual_override','system_config_error','pending_review'
  )),
  root_cause text not null check (root_cause in (
    'manual_pricing_error','master_data_stale','approval_workflow_bypass','system_config_error',
    'returns_process_gap','tax_rate_misapplied','duplicate_invoice','sales_incentive_misuse',
    'pending_investigation','reconciliation_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'reverse_credit_note','correct_pricing_master','enforce_approval_workflow','fix_system_config',
    'reconcile_returns','recover_from_customer','update_tax_master','retrain_billing_staff',
    'write_off_approved','escalate_to_finance_head','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.credit_note_capa_actions_r3608 enable row level security;

create index if not exists idx_credit_note_capa_r3608_log on public.credit_note_capa_actions_r3608(adjustment_log_id);
create index if not exists idx_credit_note_capa_r3608_status on public.credit_note_capa_actions_r3608(capa_status);

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

  -- 16 billing-adjustment fact rows
  insert into public.credit_note_r3608 (
    organization_id, adjustment_ref, business_unit, period_month,
    credit_notes_count, credit_notes_value_rupees, debit_notes_count, debit_notes_value_rupees,
    gross_sales_rupees, adjustment_pct, returns_value_rupees, pricing_error_value_rupees,
    unapproved_value_rupees, adjustment_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.bu, q.pm::date,
    q.cnc, q.cnv, q.dnc, q.dnv,
    q.gs, q.apct, q.rv, q.pev,
    q.uv, q.ast, q.td, q.nt
  from (values
    ('CN-AMC-2607','amc_services','2026-07-01',14,480000,3,90000,8600000,5.6,210000,40000,0,'minor','stable','AMC service credit notes within tolerance'),
    ('CN-SPR-2607','spare_parts','2026-07-01',22,760000,5,140000,6400000,11.9,320000,180000,95000,'elevated','worsening','Spare-parts pricing errors and unapproved credits rising'),
    ('CN-PRJ-2607','projects','2026-07-01',6,1250000,2,300000,15200000,8.2,0,220000,180000,'leakage_risk','worsening','Project milestone billing adjustments — large unapproved credit exposure'),
    ('CN-DIA-2607','diagnostics','2026-07-01',9,190000,1,25000,4100000,4.6,60000,15000,0,'minor','improving','Diagnostics reagent returns reconciled'),
    ('CN-RNT-2607','rentals','2026-07-01',4,88000,1,12000,2200000,3.9,20000,8000,0,'clean','stable','Rental billing adjustments clean'),
    ('CN-AMC-2606','amc_services','2026-06-01',17,620000,4,110000,8300000,7.4,240000,130000,60000,'elevated','worsening','AMC credit notes climbing on contract renewals'),
    ('CN-SPR-2606','spare_parts','2026-06-01',19,700000,6,160000,6100000,12.6,300000,210000,140000,'leakage_risk','worsening','Spare-parts duplicate billing and manual overrides flagged'),
    ('CN-PRJ-2606','projects','2026-06-01',5,980000,1,150000,14100000,7.1,0,120000,90000,'elevated','stable','Project adjustments elevated but controlled'),
    ('CN-DIA-2606','diagnostics','2026-06-01',11,240000,2,40000,4300000,5.6,80000,30000,10000,'minor','stable','Diagnostics adjustments minor'),
    ('CN-RNT-2606','rentals','2026-06-01',3,64000,1,9000,2050000,3.3,15000,5000,0,'clean','improving','Rentals clean'),
    ('CN-AMC-2605','amc_services','2026-05-01',12,410000,2,60000,8100000,5.2,180000,45000,0,'minor','stable','AMC baseline month'),
    ('CN-SPR-2605','spare_parts','2026-05-01',24,880000,7,190000,5900000,15.8,360000,260000,220000,'control_gap','worsening','Spare-parts control gap — approval workflow bypassed on multiple credits'),
    ('CN-PRJ-2605','projects','2026-05-01',7,1420000,3,340000,13800000,10.9,0,280000,240000,'leakage_risk','worsening','Project post-sale discount leakage detected'),
    ('CN-DIA-2605','diagnostics','2026-05-01',8,170000,1,20000,4000000,4.2,55000,12000,0,'clean','improving','Diagnostics clean baseline'),
    ('CN-RNT-2605','rentals','2026-05-01',5,102000,2,18000,2150000,4.8,25000,20000,15000,'minor','worsening','Rentals minor adjustment uptick'),
    ('CN-DIA-2607B','diagnostics','2026-07-01',13,300000,2,55000,4250000,6.8,90000,70000,40000,'elevated','worsening','Diagnostics tax adjustment errors flagged for review')
  ) as q(ref, bu, pm, cnc, cnv, dnc, dnv, gs, apct, rv, pev, uv, ast, td, nt);

  -- CAPA seed — attach to specific fact rows via adjustment_ref
  insert into public.credit_note_capa_actions_r3608 (
    adjustment_log_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CN-PRJ-2607','unapproved_credit_note','approval_workflow_bypass','enforce_approval_workflow','in_progress',180000,'Finance Controller','2026-07-20',null,'Unapproved project credit notes under review — workflow being enforced'),
    ('CN-SPR-2605','manual_override','sales_incentive_misuse','recover_from_customer','escalated',220000,'Regional Sales Head','2026-07-15',null,'Spare-parts control gap escalated to finance head for recovery'),
    ('CN-PRJ-2605','post_sale_discount_leakage','master_data_stale','correct_pricing_master','open',240000,'Pricing Manager','2026-07-25',null,'Post-sale discount leakage — pricing master correction pending'),
    ('CN-SPR-2606','duplicate_billing','duplicate_invoice','reverse_credit_note','closed',140000,'Billing Lead','2026-06-30','2026-06-28','Duplicate spare-parts invoices reversed and reconciled'),
    ('CN-SPR-2607','pricing_error','manual_pricing_error','correct_pricing_master','verification_pending',95000,'Pricing Manager','2026-07-18',null,'Spare-parts pricing errors corrected — verifying next cycle'),
    ('CN-AMC-2606','unapproved_credit_note','approval_workflow_bypass','enforce_approval_workflow','overdue',60000,'AMC Manager','2026-06-25',null,'AMC unapproved credits past target — workflow enforcement overdue'),
    ('CN-DIA-2607B','tax_adjustment_error','tax_rate_misapplied','update_tax_master','open',40000,'Tax Analyst','2026-07-28',null,'Diagnostics tax rate misapplied — updating tax master'),
    ('CN-RNT-2605','returns_not_reconciled','returns_process_gap','reconcile_returns','in_progress',15000,'Ops Coordinator','2026-07-22',null,'Rentals returns reconciliation in progress')
  ) as q(ref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.credit_note_r3608 e
    on e.organization_id = v_org_id and e.adjustment_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Adjustment-status distribution
create or replace function public.founder_r3608_adjustment_status_rollup()
returns table(adjustment_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.credit_note_r3608)
  select l.adjustment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.credit_note_r3608 l
  group by l.adjustment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3608_adjustment_status_rollup() from public, anon;
grant execute on function public.founder_r3608_adjustment_status_rollup() to authenticated;

-- 2) Business-unit scorecard
create or replace function public.founder_r3608_business_unit_scorecard()
returns table(
  business_unit text,
  entries bigint,
  total_credit_value_rupees numeric,
  total_debit_value_rupees numeric,
  total_gross_sales_rupees numeric,
  avg_adjustment_pct numeric,
  total_unapproved_rupees numeric,
  leakage_flag bigint
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
    coalesce(sum(l.credit_notes_value_rupees),0)::numeric,
    coalesce(sum(l.debit_notes_value_rupees),0)::numeric,
    coalesce(sum(l.gross_sales_rupees),0)::numeric,
    round(avg(l.adjustment_pct), 2),
    coalesce(sum(l.unapproved_value_rupees),0)::numeric,
    count(*) filter (where l.adjustment_status in ('leakage_risk','control_gap'))::bigint
  from public.credit_note_r3608 l
  group by l.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3608_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3608_business_unit_scorecard() to authenticated;

-- 3) Business-unit × adjustment-status matrix
create or replace function public.founder_r3608_bu_status_matrix()
returns table(
  business_unit text,
  adjustment_status text,
  entries bigint,
  credit_value_rupees numeric,
  unapproved_value_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.adjustment_status, count(*)::bigint,
    coalesce(sum(l.credit_notes_value_rupees),0)::numeric,
    coalesce(sum(l.unapproved_value_rupees),0)::numeric
  from public.credit_note_r3608 l
  group by l.business_unit, l.adjustment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3608_bu_status_matrix() from public, anon;
grant execute on function public.founder_r3608_bu_status_matrix() to authenticated;

-- 4) Monthly adjustment trend
create or replace function public.founder_r3608_monthly_adjustment_trend()
returns table(
  period_month date,
  entries bigint,
  credit_notes_value_rupees numeric,
  debit_notes_value_rupees numeric,
  gross_sales_rupees numeric,
  avg_adjustment_pct numeric,
  leakage_entries bigint
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
    coalesce(sum(l.credit_notes_value_rupees),0)::numeric,
    coalesce(sum(l.debit_notes_value_rupees),0)::numeric,
    coalesce(sum(l.gross_sales_rupees),0)::numeric,
    round(avg(l.adjustment_pct), 2),
    count(*) filter (where l.adjustment_status in ('leakage_risk','control_gap'))::bigint
  from public.credit_note_r3608 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3608_monthly_adjustment_trend() from public, anon;
grant execute on function public.founder_r3608_monthly_adjustment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3608_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.credit_note_capa_actions_r3608 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3608_capa_status_board() from public, anon;
grant execute on function public.founder_r3608_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3608_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.credit_note_capa_actions_r3608)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.credit_note_capa_actions_r3608 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3608_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3608_root_cause_pareto() to authenticated;

-- 7) Adjustment-impact digest (by finding category)
create or replace function public.founder_r3608_adjustment_impact_digest()
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
    coalesce(sum(c.impact_rupees),0)::numeric
  from public.credit_note_capa_actions_r3608 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3608_adjustment_impact_digest() from public, anon;
grant execute on function public.founder_r3608_adjustment_impact_digest() to authenticated;

-- 8) High-risk leakage queue (leakage_risk / control_gap / elevated / worsening)
create or replace function public.founder_r3608_high_risk_queue()
returns table(
  business_unit text,
  adjustment_ref text,
  period_month date,
  adjustment_status text,
  adjustment_pct numeric,
  credit_notes_value_rupees numeric,
  unapproved_value_rupees numeric,
  pricing_error_value_rupees numeric,
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
  select l.business_unit, l.adjustment_ref, l.period_month, l.adjustment_status,
    l.adjustment_pct, l.credit_notes_value_rupees, l.unapproved_value_rupees,
    l.pricing_error_value_rupees, l.trend_dir, l.notes
  from public.credit_note_r3608 l
  where l.adjustment_status in ('elevated','leakage_risk','control_gap')
     or l.trend_dir = 'worsening'
     or coalesce(l.unapproved_value_rupees,0) > 0
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3608_high_risk_queue() from public, anon;
grant execute on function public.founder_r3608_high_risk_queue() to authenticated;
