-- Round 3457: Founder Price-Book / List-Price Margin-Governance & Approval Board
-- Price-book governance log — SKU × product line × list/floor/realized price × standard cost × list/realized margin
--   × discount band × approval status × last revised × price trend × margin-impact CAPA

-- =============================================================================
-- TABLE 1: price_book_governance_r3457 — per-SKU list-price & margin governance
-- =============================================================================
create table if not exists public.price_book_governance_r3457 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sku text not null,
  product_line text not null,
  list_price_rupees numeric(14,2) not null,
  floor_price_rupees numeric(14,2) not null,
  avg_realized_price_rupees numeric(14,2),
  standard_cost_rupees numeric(14,2) not null,
  list_margin_pct numeric(6,2),
  realized_margin_pct numeric(6,2),
  discount_band text not null check (discount_band in (
    '0-5','5-10','10-20','20-30','30plus'
  )),
  approval_status text not null check (approval_status in (
    'within_policy','needs_l1_approval','needs_l2_approval','below_floor_breach'
  )),
  last_revised date not null,
  price_trend text not null check (price_trend in (
    'increased','held','decreased'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_book_governance_r3457 enable row level security;

create index if not exists idx_pbg_r3457_org on public.price_book_governance_r3457(organization_id);
create index if not exists idx_pbg_r3457_revised on public.price_book_governance_r3457(last_revised);
create index if not exists idx_pbg_r3457_status on public.price_book_governance_r3457(approval_status);

-- =============================================================================
-- TABLE 2: price_book_governance_capa_actions_r3457 — CAPA & governance actions
-- =============================================================================
create table if not exists public.price_book_governance_capa_actions_r3457 (
  id uuid primary key default gen_random_uuid(),
  price_book_id uuid not null references public.price_book_governance_r3457(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'below_floor_sale','unapproved_discount','margin_erosion','list_price_stale',
    'cost_increase_unpassed','price_override_missing_approval','competitive_underpricing',
    'bundle_leakage','rebate_overpayment','currency_pass_through_gap'
  )),
  root_cause text not null check (root_cause in (
    'sales_discretion_abuse','outdated_cost_master','competitor_price_pressure',
    'approval_workflow_bypass','fx_input_cost_spike','volume_commitment_shortfall',
    'crm_price_sync_error','pending_investigation','promotional_stacking','channel_partner_leakage'
  )),
  corrective_action text not null check (corrective_action in (
    'reprice_to_floor','enforce_approval_gate','update_cost_master','renegotiate_customer_price',
    'withdraw_unapproved_discount','refresh_list_price','clawback_rebate',
    'escalate_to_pricing_council','retrain_sales_team','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  margin_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.price_book_governance_capa_actions_r3457 enable row level security;

create index if not exists idx_pbg_capa_r3457_book on public.price_book_governance_capa_actions_r3457(price_book_id);
create index if not exists idx_pbg_capa_r3457_status on public.price_book_governance_capa_actions_r3457(capa_status);

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

  -- 16 price-book rows
  insert into public.price_book_governance_r3457 (
    organization_id, sku, product_line, list_price_rupees, floor_price_rupees,
    avg_realized_price_rupees, standard_cost_rupees, list_margin_pct, realized_margin_pct,
    discount_band, approval_status, last_revised, price_trend, notes
  )
  select v_org_id, q.sku, q.pl, q.listp, q.floorp,
    q.realp, q.stdcost, q.lmarg, q.rmarg,
    q.dband, q.astat, q.lrev::date, q.ptrend, q.nt
  from (values
    ('PM-BEDSIDE-12','Patient Monitoring',185000,148000,172000,121000,34.6,29.7,
     '5-10','within_policy','2026-06-15','held','Bedside multipara monitor — realized margin healthy'),
    ('PM-CENTRAL-STN','Patient Monitoring',640000,512000,498000,430000,32.8,13.7,
     '20-30','needs_l2_approval','2026-05-20','decreased','Central station discounted well past floor — L2 review'),
    ('VENT-ICU-PRO','Ventilation',1250000,1000000,1180000,860000,31.2,27.1,
     '5-10','within_policy','2026-06-01','increased','ICU ventilator list revised up on cost pass-through'),
    ('VENT-TRANSPORT','Ventilation',480000,384000,372000,330000,31.3,11.3,
     '20-30','below_floor_breach','2026-04-10','decreased','Transport ventilator sold below floor at tender'),
    ('DIAL-HD-STD','Dialysis',720000,576000,690000,470000,34.7,31.9,
     '0-5','within_policy','2026-06-20','held','HD machine standard config, strong realization'),
    ('DIAL-RO-PLANT','Dialysis Water',950000,760000,812000,620000,34.7,23.6,
     '10-20','needs_l1_approval','2026-05-05','held','RO plant bundle discount sitting at L1 band'),
    ('IMG-USG-COLOR','Imaging',1650000,1320000,1290000,1080000,34.5,16.3,
     '20-30','needs_l2_approval','2026-03-28','decreased','Colour doppler USG margin eroding under competition'),
    ('IMG-CARM-HD','Imaging',4200000,3360000,3980000,2900000,31.0,27.1,
     '5-10','within_policy','2026-06-10','increased','C-arm HD list revised up after cost refresh'),
    ('SURG-DIATHERMY','Surgical',310000,248000,236000,205000,33.9,13.1,
     '20-30','below_floor_breach','2026-04-22','decreased','Electrosurgical unit below floor on large tender'),
    ('STER-AUTOCLAVE','Sterilization',420000,336000,405000,268000,36.2,33.8,
     '0-5','within_policy','2026-06-18','held','Autoclave — best-in-class margin held'),
    ('INF-PUMP-VOLU','Infusion',68000,54000,61000,44000,35.3,27.9,
     '5-10','within_policy','2026-06-05','held','Volumetric infusion pump within policy'),
    ('INF-SYRINGE-4CH','Infusion',95000,76000,71000,63000,33.7,11.3,
     '20-30','needs_l2_approval','2026-05-12','decreased','4-channel syringe pump discounted deep'),
    ('DIAG-HEMATOLOGY','Diagnostics',880000,704000,690000,560000,36.4,18.8,
     '20-30','needs_l1_approval','2026-05-25','decreased','5-part hematology analyzer under import pressure'),
    ('DEFIB-BIPHASIC','Emergency Care',265000,212000,254000,172000,35.1,32.3,
     '0-5','within_policy','2026-06-22','held','Biphasic defibrillator strong realization'),
    ('AMC-MONITOR-GOLD','Service Contracts',42000,33000,30500,21000,50.0,31.1,
     '30plus','below_floor_breach','2026-04-01','decreased','Gold AMC discounted beyond 30pct below floor'),
    ('SPARE-SPO2-SENSOR','Spare Parts',8500,6800,7900,5200,38.8,34.2,
     '5-10','within_policy','2026-06-28','increased','SpO2 sensor spare — list uplift held')
  ) as q(sku, pl, listp, floorp, realp, stdcost, lmarg, rmarg, dband, astat, lrev, ptrend, nt);

  -- CAPA seed — attach to specific SKUs by business key
  insert into public.price_book_governance_capa_actions_r3457 (
    price_book_id, finding_category, root_cause, corrective_action,
    capa_status, margin_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PM-CENTRAL-STN','unapproved_discount','approval_workflow_bypass','enforce_approval_gate',
     'in_progress',142000,'Anita Deshpande','2026-07-30',null,'22pct discount cleared without L2 sign-off'),
    ('VENT-TRANSPORT','below_floor_sale','sales_discretion_abuse','reprice_to_floor',
     'escalated',108000,'Rahul Menon','2026-07-28',null,'Sold Rs 12k below floor at district hospital tender'),
    ('IMG-USG-COLOR','margin_erosion','competitor_price_pressure','renegotiate_customer_price',
     'open',360000,'Sneha Kulkarni','2026-08-05',null,'Realized margin fell to 16pct vs 34pct list'),
    ('SURG-DIATHERMY','below_floor_sale','approval_workflow_bypass','withdraw_unapproved_discount',
     'verification_pending',12000,'Rahul Menon','2026-07-24',null,'Floor breach flagged; awaiting revised PO'),
    ('AMC-MONITOR-GOLD','below_floor_sale','promotional_stacking','escalate_to_pricing_council',
     'overdue',2500,'Priya Nair','2026-07-10',null,'Festive plus volume discount stacked below floor'),
    ('IMG-CARM-HD','cost_increase_unpassed','outdated_cost_master','update_cost_master',
     'closed',0,'Vikram Shah','2026-07-05','2026-07-02','Cost master refreshed; list revised up 4pct'),
    ('DIAG-HEMATOLOGY','competitive_underpricing','competitor_price_pressure','escalate_to_pricing_council',
     'in_progress',190000,'Sneha Kulkarni','2026-08-02',null,'Analyzer losing to imported brand on price'),
    ('INF-SYRINGE-4CH','unapproved_discount','crm_price_sync_error','enforce_approval_gate',
     'open',24000,'Anita Deshpande','2026-07-31',null,'CRM pushed stale list; deep discount auto-approved')
  ) as q(sku, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.price_book_governance_r3457 e
    on e.organization_id = v_org_id and e.sku = q.sku;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Approval-status distribution
create or replace function public.founder_r3457_approval_status_rollup()
returns table(approval_status text, skus bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_book_governance_r3457)
  select p.approval_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.price_book_governance_r3457 p
  group by p.approval_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3457_approval_status_rollup() from public, anon;
grant execute on function public.founder_r3457_approval_status_rollup() to authenticated;

-- 2) Product-line margin scorecard
create or replace function public.founder_r3457_product_line_scorecard()
returns table(
  product_line text,
  skus bigint,
  within_policy bigint,
  needs_approval bigint,
  below_floor bigint,
  avg_list_margin_pct numeric,
  avg_realized_margin_pct numeric,
  margin_gap_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.product_line,
    count(*)::bigint,
    count(*) filter (where p.approval_status = 'within_policy')::bigint,
    count(*) filter (where p.approval_status in ('needs_l1_approval','needs_l2_approval'))::bigint,
    count(*) filter (where p.approval_status = 'below_floor_breach')::bigint,
    round(avg(p.list_margin_pct), 2),
    round(avg(p.realized_margin_pct), 2),
    round(avg(p.list_margin_pct) - avg(p.realized_margin_pct), 2)
  from public.price_book_governance_r3457 p
  group by p.product_line
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3457_product_line_scorecard() from public, anon;
grant execute on function public.founder_r3457_product_line_scorecard() to authenticated;

-- 3) Discount-band × approval-status matrix
create or replace function public.founder_r3457_discount_approval_matrix()
returns table(discount_band text, approval_status text, skus bigint, avg_realized_margin_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.discount_band, p.approval_status, count(*)::bigint,
    round(avg(p.realized_margin_pct), 2)
  from public.price_book_governance_r3457 p
  group by p.discount_band, p.approval_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3457_discount_approval_matrix() from public, anon;
grant execute on function public.founder_r3457_discount_approval_matrix() to authenticated;

-- 4) Monthly margin trend (by last-revised month)
create or replace function public.founder_r3457_monthly_margin_trend()
returns table(
  revised_month date,
  skus bigint,
  avg_list_margin_pct numeric,
  avg_realized_margin_pct numeric,
  below_floor bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', p.last_revised)::date,
    count(*)::bigint,
    round(avg(p.list_margin_pct), 2),
    round(avg(p.realized_margin_pct), 2),
    count(*) filter (where p.approval_status = 'below_floor_breach')::bigint
  from public.price_book_governance_r3457 p
  group by date_trunc('month', p.last_revised)
  order by date_trunc('month', p.last_revised) desc;
end;
$$;

revoke execute on function public.founder_r3457_monthly_margin_trend() from public, anon;
grant execute on function public.founder_r3457_monthly_margin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3457_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.margin_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.price_book_governance_capa_actions_r3457 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3457_capa_status_board() from public, anon;
grant execute on function public.founder_r3457_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3457_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.price_book_governance_capa_actions_r3457)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.margin_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.price_book_governance_capa_actions_r3457 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3457_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3457_root_cause_pareto() to authenticated;

-- 7) Margin-impact digest (by finding category)
create or replace function public.founder_r3457_margin_impact_digest()
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
    coalesce(sum(c.margin_impact_rupees),0)::numeric
  from public.price_book_governance_capa_actions_r3457 c
  group by c.finding_category
  order by coalesce(sum(c.margin_impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3457_margin_impact_digest() from public, anon;
grant execute on function public.founder_r3457_margin_impact_digest() to authenticated;

-- 8) High-risk queue (below-floor / needs-approval / eroding margin)
create or replace function public.founder_r3457_high_risk_queue()
returns table(
  sku text,
  product_line text,
  list_price_rupees numeric,
  floor_price_rupees numeric,
  avg_realized_price_rupees numeric,
  realized_margin_pct numeric,
  discount_band text,
  approval_status text,
  price_trend text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.sku, p.product_line, p.list_price_rupees, p.floor_price_rupees,
    p.avg_realized_price_rupees, p.realized_margin_pct, p.discount_band,
    p.approval_status, p.price_trend, p.notes
  from public.price_book_governance_r3457 p
  where p.approval_status in ('needs_l1_approval','needs_l2_approval','below_floor_breach')
     or p.price_trend = 'decreased'
     or p.realized_margin_pct < 20
     or p.avg_realized_price_rupees < p.floor_price_rupees
  order by case p.approval_status
             when 'below_floor_breach' then 0
             when 'needs_l2_approval' then 1
             when 'needs_l1_approval' then 2
             else 3
           end,
           p.realized_margin_pct asc;
end;
$$;

revoke execute on function public.founder_r3457_high_risk_queue() from public, anon;
grant execute on function public.founder_r3457_high_risk_queue() to authenticated;
