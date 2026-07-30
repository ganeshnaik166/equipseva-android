-- Round 3633: Founder Cost-Audit / Cost-Records (Sec-148) Compliance Board
-- Cost-records (Companies Act sec-148) compliance log — cost-centre × product-group × period × records-maintained ×
-- reconciliation variance × material/conversion/overhead cost × under/over absorption × observations × filing due ×
-- compliance status × trend × CAPA closure

-- =============================================================================
-- TABLE 1: cost_audit_r3633 — per-cost-centre cost-records compliance facts
-- =============================================================================
create table if not exists public.cost_audit_r3633 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  record_ref text not null,
  cost_centre text not null,
  product_group text not null,
  period_month date not null,
  cost_records_maintained boolean not null,
  reconciliation_variance_pct numeric(6,2),
  material_cost_rupees numeric(14,2),
  conversion_cost_rupees numeric(14,2),
  overhead_absorbed_rupees numeric(14,2),
  under_over_absorption_rupees numeric(14,2),
  observations_count int not null default 0,
  filing_due_date date,
  compliance_status text not null check (compliance_status in (
    'compliant','on_track','records_gap','observation_open','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cost_audit_r3633 enable row level security;

create index if not exists idx_cost_audit_r3633_org on public.cost_audit_r3633(organization_id);
create index if not exists idx_cost_audit_r3633_period on public.cost_audit_r3633(period_month);
create index if not exists idx_cost_audit_r3633_status on public.cost_audit_r3633(compliance_status);

-- =============================================================================
-- TABLE 2: cost_audit_capa_actions_r3633 — CAPA & observation-closure actions
-- =============================================================================
create table if not exists public.cost_audit_capa_actions_r3633 (
  id uuid primary key default gen_random_uuid(),
  cost_record_id uuid not null references public.cost_audit_r3633(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cost_records_gap','reconciliation_variance','overhead_absorption_error','material_cost_misallocation',
    'conversion_cost_misallocation','filing_delay','observation_unresolved','cost_sheet_missing'
  )),
  root_cause text not null check (root_cause in (
    'missing_supporting_vouchers','erp_posting_error','overhead_rate_outdated','cost_centre_mapping_error',
    'inventory_valuation_mismatch','manual_journal_error','pending_investigation','process_gap_untrained_staff',
    'vendor_reconciliation_pending','allocation_basis_incorrect'
  )),
  corrective_action text not null check (corrective_action in (
    'reconstruct_cost_records','correct_erp_postings','revise_overhead_rate','remap_cost_centre',
    'revalue_inventory','post_adjustment_entry','retrain_finance_staff','implement_monthly_reconciliation',
    'escalate_to_cost_auditor','none_required'
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

alter table public.cost_audit_capa_actions_r3633 enable row level security;

create index if not exists idx_cost_audit_capa_r3633_rec on public.cost_audit_capa_actions_r3633(cost_record_id);
create index if not exists idx_cost_audit_capa_r3633_status on public.cost_audit_capa_actions_r3633(capa_status);

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

  -- 16 cost-records compliance rows
  insert into public.cost_audit_r3633 (
    organization_id, record_ref, cost_centre, product_group, period_month,
    cost_records_maintained, reconciliation_variance_pct, material_cost_rupees, conversion_cost_rupees,
    overhead_absorbed_rupees, under_over_absorption_rupees, observations_count, filing_due_date,
    compliance_status, trend_dir, notes
  )
  select v_org_id, q.rref, q.cc, q.pg, q.pmon::date,
    q.crm, q.rvp, q.mcr, q.ccr,
    q.oar, q.uoar, q.obs, q.fdd::date,
    q.cstat, q.tdir, q.nt
  from (values
    ('CST-AMC-2605','AMC South Zone','amc_services','2026-05-01',
     true,0.4,1250000,680000,420000,12000,0,'2026-09-30','compliant','improving','AMC cost records maintained; reconciliation within tolerance'),
    ('CST-SPR-2605','Spare Parts Warehouse','spare_parts','2026-05-01',
     true,1.2,3400000,210000,180000,45000,1,'2026-09-30','on_track','stable','Spares valuation minor variance; one observation on slow-moving stock'),
    ('CST-PRJ-2605','Turnkey Projects North','projects','2026-05-01',
     false,6.8,8900000,1200000,950000,310000,3,'2026-09-30','records_gap','worsening','Project WIP cost records incomplete; supporting vouchers missing'),
    ('CST-DIA-2605','Diagnostics Lab Ops','diagnostics','2026-05-01',
     true,2.1,560000,340000,290000,-22000,2,'2026-09-30','observation_open','stable','Reagent cost allocation observations open with cost auditor'),
    ('CST-AMC-2606','AMC South Zone','amc_services','2026-06-01',
     true,0.6,1310000,700000,440000,9000,0,'2026-10-31','compliant','improving','AMC June cost records clean; no reconciliation variance'),
    ('CST-SPR-2606','Spare Parts Warehouse','spare_parts','2026-06-01',
     true,3.4,3600000,225000,195000,88000,2,'2026-10-31','observation_open','worsening','Inventory valuation mismatch versus ERP; observations raised'),
    ('CST-PRJ-2606','Turnkey Projects North','projects','2026-06-01',
     false,9.2,9600000,1350000,1010000,520000,4,'2026-10-31','non_compliant','worsening','Project cost sheet not maintained; large under-absorption; non-compliant'),
    ('CST-DIA-2606','Diagnostics Lab Ops','diagnostics','2026-06-01',
     true,1.8,590000,355000,300000,-15000,1,'2026-10-31','on_track','improving','Diagnostics overhead absorption improving month-on-month'),
    ('CST-AMC-2607','AMC West Zone','amc_services','2026-07-01',
     true,0.9,980000,520000,330000,14000,0,'2026-11-30','compliant','stable','West AMC cost records maintained and reconciled'),
    ('CST-SPR-2607','Spare Parts Warehouse','spare_parts','2026-07-01',
     false,5.6,3720000,240000,205000,132000,3,'2026-11-30','records_gap','worsening','Spares cost records gap; GRN versus invoice reconciliation pending'),
    ('CST-PRJ-2607','Turnkey Projects South','projects','2026-07-01',
     true,4.3,7200000,1100000,880000,240000,2,'2026-11-30','observation_open','improving','Project South improving after adjustment entries; two observations open'),
    ('CST-DIA-2607','Diagnostics Lab Ops','diagnostics','2026-07-01',
     true,1.1,610000,370000,315000,-8000,0,'2026-11-30','compliant','improving','Diagnostics July cost records compliant'),
    ('CST-CON-2607','Consumables Distribution','consumables','2026-07-01',
     true,2.7,1450000,160000,140000,36000,1,'2026-11-30','on_track','stable','Consumables on track; minor overhead absorption variance'),
    ('CST-REF-2607','Refurbishment Unit','refurbishment','2026-07-01',
     false,7.9,2100000,890000,560000,180000,3,'2026-11-30','non_compliant','worsening','Refurb labour cost not captured; cost records gap escalated to non-compliant'),
    ('CST-AMC-2607E','AMC East Zone','amc_services','2026-07-01',
     true,1.4,870000,470000,300000,21000,1,'2026-11-30','on_track','stable','East AMC one observation on subcontractor cost allocation'),
    ('CST-DIA-2607H','Diagnostics Hub Central','diagnostics','2026-07-01',
     true,3.1,720000,410000,350000,42000,2,'2026-11-30','observation_open','worsening','Central diagnostics hub overhead over-absorption; observations open')
  ) as q(rref, cc, pg, pmon, crm, rvp, mcr, ccr, oar, uoar, obs, fdd, cstat, tdir, nt);

  -- CAPA seed — attach to specific cost records by record_ref
  insert into public.cost_audit_capa_actions_r3633 (
    cost_record_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CST-PRJ-2605','cost_records_gap','missing_supporting_vouchers','reconstruct_cost_records',
     'in_progress',310000,'Ravi Menon (Cost Controller)','2026-08-15',null,'Reconstructing project WIP records from subcontractor bills'),
    ('CST-PRJ-2606','cost_sheet_missing','process_gap_untrained_staff','implement_monthly_reconciliation',
     'escalated',520000,'Ravi Menon (Cost Controller)','2026-08-10',null,'Non-compliant project; escalated to statutory cost auditor'),
    ('CST-SPR-2606','reconciliation_variance','inventory_valuation_mismatch','revalue_inventory',
     'verification_pending',88000,'Priya Nair (Inventory Lead)','2026-08-05',null,'Inventory revalued to weighted-average; awaiting audit verification'),
    ('CST-SPR-2607','cost_records_gap','vendor_reconciliation_pending','correct_erp_postings',
     'open',132000,'Priya Nair (Inventory Lead)','2026-08-20',null,'GRN versus invoice reconciliation pending with vendors'),
    ('CST-REF-2607','cost_sheet_missing','allocation_basis_incorrect','remap_cost_centre',
     'overdue',180000,'Anil Kumar (Plant Finance)','2026-07-20',null,'Refurb labour cost mapping overdue; past target closure'),
    ('CST-DIA-2605','observation_unresolved','allocation_basis_incorrect','post_adjustment_entry',
     'closed',22000,'Sunita Rao (Lab Finance)','2026-07-10','2026-07-08','Reagent allocation basis corrected; observation closed'),
    ('CST-SPR-2605','observation_unresolved','erp_posting_error','correct_erp_postings',
     'closed',45000,'Priya Nair (Inventory Lead)','2026-07-05','2026-07-03','Slow-moving stock provision posted; observation resolved'),
    ('CST-DIA-2607H','overhead_absorption_error','overhead_rate_outdated','revise_overhead_rate',
     'in_progress',42000,'Sunita Rao (Lab Finance)','2026-08-25',null,'Overhead rate under revision for central diagnostics hub')
  ) as q(rref, fc, rc, ca, cst, fi, own, tcd, acd, nt)
  join public.cost_audit_r3633 e
    on e.organization_id = v_org_id and e.record_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3633_compliance_status_rollup()
returns table(compliance_status text, records bigint, observations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cost_audit_r3633)
  select l.compliance_status, count(*)::bigint,
         coalesce(sum(l.observations_count),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cost_audit_r3633 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3633_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3633_compliance_status_rollup() to authenticated;

-- 2) Product-group scorecard
create or replace function public.founder_r3633_product_group_scorecard()
returns table(
  product_group text,
  total_records bigint,
  compliant bigint,
  records_gap bigint,
  non_compliant bigint,
  observations bigint,
  records_maintained bigint,
  avg_variance_pct numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_group,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'records_gap')::bigint,
    count(*) filter (where l.compliance_status = 'non_compliant')::bigint,
    coalesce(sum(l.observations_count),0)::bigint,
    count(*) filter (where l.cost_records_maintained = true)::bigint,
    round(avg(l.reconciliation_variance_pct), 2),
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.cost_audit_r3633 l
  group by l.product_group
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3633_product_group_scorecard() from public, anon;
grant execute on function public.founder_r3633_product_group_scorecard() to authenticated;

-- 3) Product-group × compliance-status matrix
create or replace function public.founder_r3633_product_group_status_matrix()
returns table(product_group text, compliance_status text, records bigint, observations bigint, total_under_over_absorption_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_group, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.observations_count),0)::bigint,
    coalesce(sum(l.under_over_absorption_rupees),0)::numeric
  from public.cost_audit_r3633 l
  group by l.product_group, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3633_product_group_status_matrix() from public, anon;
grant execute on function public.founder_r3633_product_group_status_matrix() to authenticated;

-- 4) Monthly compliance trend
create or replace function public.founder_r3633_monthly_compliance_trend()
returns table(period_month date, records bigint, compliant bigint, non_compliant bigint, records_gap bigint, observations bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'non_compliant')::bigint,
    count(*) filter (where l.compliance_status = 'records_gap')::bigint,
    coalesce(sum(l.observations_count),0)::bigint
  from public.cost_audit_r3633 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3633_monthly_compliance_trend() from public, anon;
grant execute on function public.founder_r3633_monthly_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3633_capa_status_board()
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
  from public.cost_audit_capa_actions_r3633 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3633_capa_status_board() from public, anon;
grant execute on function public.founder_r3633_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3633_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cost_audit_capa_actions_r3633)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.financial_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cost_audit_capa_actions_r3633 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3633_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3633_root_cause_pareto() to authenticated;

-- 7) Absorption-variance digest (by product group)
create or replace function public.founder_r3633_absorption_variance_digest()
returns table(
  product_group text,
  records bigint,
  total_material_cost_rupees numeric,
  total_conversion_cost_rupees numeric,
  total_overhead_absorbed_rupees numeric,
  total_under_over_absorption_rupees numeric,
  avg_variance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.product_group, count(*)::bigint,
    coalesce(sum(l.material_cost_rupees),0)::numeric,
    coalesce(sum(l.conversion_cost_rupees),0)::numeric,
    coalesce(sum(l.overhead_absorbed_rupees),0)::numeric,
    coalesce(sum(l.under_over_absorption_rupees),0)::numeric,
    round(avg(l.reconciliation_variance_pct), 2)
  from public.cost_audit_r3633 l
  group by l.product_group
  order by coalesce(sum(l.under_over_absorption_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3633_absorption_variance_digest() from public, anon;
grant execute on function public.founder_r3633_absorption_variance_digest() to authenticated;

-- 8) High-risk queue (records_gap / non_compliant)
create or replace function public.founder_r3633_high_risk_queue()
returns table(
  record_ref text,
  cost_centre text,
  product_group text,
  period_month date,
  compliance_status text,
  cost_records_maintained boolean,
  reconciliation_variance_pct numeric,
  under_over_absorption_rupees numeric,
  observations_count int,
  filing_due_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.record_ref, l.cost_centre, l.product_group, l.period_month,
    l.compliance_status, l.cost_records_maintained, l.reconciliation_variance_pct,
    l.under_over_absorption_rupees, l.observations_count, l.filing_due_date, l.notes
  from public.cost_audit_r3633 l
  where l.compliance_status in ('records_gap','non_compliant')
     or l.cost_records_maintained = false
     or l.observations_count >= 3
  order by case l.compliance_status
             when 'non_compliant' then 0
             when 'records_gap' then 1
             when 'observation_open' then 2
             else 3
           end,
           l.period_month desc, l.cost_centre;
end;
$$;

revoke execute on function public.founder_r3633_high_risk_queue() from public, anon;
grant execute on function public.founder_r3633_high_risk_queue() to authenticated;
