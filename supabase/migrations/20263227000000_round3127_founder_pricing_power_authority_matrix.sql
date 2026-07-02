-- Round 3127: Founder Pricing Power & Discount-Approval Authority Matrix
-- HEAVY ★★★★ — pricing audit: list × ceiling × floor × discount thresholds × win-rate × leakage × breach log

begin;

-- ============================================================================
-- TABLE 1: pricing_power_matrix_r3127
-- Per-SKU/service pricing envelope + win-rate + leakage rollup
-- ============================================================================
create table if not exists public.pricing_power_matrix_r3127 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sku_code text not null,
  service_category text not null check (service_category in (
    'amc_class_a','amc_class_b','amc_super_specialty',
    'repair_dental','repair_imaging','repair_lab','repair_or',
    'spare_part_oem','spare_part_refurb','training_supervised'
  )),
  customer_tier text not null check (customer_tier in (
    'tier1_apex_hospital','tier2_multispecialty','tier3_clinic_chain',
    'tier4_standalone_clinic','tier5_diagnostic_lab','government'
  )),
  list_price_rupees numeric(14,2) not null check (list_price_rupees > 0),
  ceiling_price_rupees numeric(14,2) not null check (ceiling_price_rupees >= list_price_rupees),
  floor_price_rupees numeric(14,2) not null check (floor_price_rupees > 0 and floor_price_rupees <= list_price_rupees),
  target_margin_pct numeric(5,2) not null check (target_margin_pct between 0 and 80),
  cogs_rupees numeric(14,2) not null check (cogs_rupees > 0),
  quotes_issued_qty integer not null default 0 check (quotes_issued_qty >= 0),
  quotes_won_qty integer not null default 0 check (quotes_won_qty >= 0 and quotes_won_qty <= quotes_issued_qty),
  avg_realized_price_rupees numeric(14,2) check (avg_realized_price_rupees is null or avg_realized_price_rupees > 0),
  leakage_vs_list_pct numeric(6,2),
  pricing_power_score numeric(5,2) check (pricing_power_score is null or pricing_power_score between 0 and 100),
  last_repriced_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists pricing_power_matrix_r3127_org_idx
  on public.pricing_power_matrix_r3127(organization_id);
create index if not exists pricing_power_matrix_r3127_cat_tier_idx
  on public.pricing_power_matrix_r3127(service_category, customer_tier);

alter table public.pricing_power_matrix_r3127 enable row level security;

drop policy if exists pricing_power_matrix_r3127_founder_all on public.pricing_power_matrix_r3127;
create policy pricing_power_matrix_r3127_founder_all
  on public.pricing_power_matrix_r3127 for all
  using (public.is_founder()) with check (public.is_founder());

-- ============================================================================
-- TABLE 2: discount_authority_breach_r3127
-- Discount-approval threshold breaches + authority escalations
-- ============================================================================
create table if not exists public.discount_authority_breach_r3127 (
  id uuid primary key default gen_random_uuid(),
  matrix_id uuid references public.pricing_power_matrix_r3127(id) on delete set null,
  quote_reference text not null,
  approver_profile_id uuid references public.profiles(id) on delete set null,
  requested_discount_pct numeric(5,2) not null check (requested_discount_pct >= 0 and requested_discount_pct <= 100),
  approved_discount_pct numeric(5,2) check (approved_discount_pct is null or (approved_discount_pct >= 0 and approved_discount_pct <= 100)),
  authority_level_required text not null check (authority_level_required in (
    'sales_rep','sales_manager','vp_sales','coo','founder_ceo','board'
  )),
  authority_level_used text not null check (authority_level_used in (
    'sales_rep','sales_manager','vp_sales','coo','founder_ceo','board'
  )),
  breach_severity text not null check (breach_severity in (
    'within_authority','minor_breach','material_breach','grave_breach','policy_violation'
  )),
  margin_impact_rupees numeric(14,2) not null,
  resolution_status text not null check (resolution_status in (
    'pending_review','approved_retroactively','rejected_recouped','rejected_writeoff','escalated_board'
  )),
  decided_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists discount_authority_breach_r3127_matrix_idx
  on public.discount_authority_breach_r3127(matrix_id);
create index if not exists discount_authority_breach_r3127_sev_idx
  on public.discount_authority_breach_r3127(breach_severity);

alter table public.discount_authority_breach_r3127 enable row level security;

drop policy if exists discount_authority_breach_r3127_founder_all on public.discount_authority_breach_r3127;
create policy discount_authority_breach_r3127_founder_all
  on public.discount_authority_breach_r3127 for all
  using (public.is_founder()) with check (public.is_founder());

-- ============================================================================
-- SEED: 12 pricing matrix rows
-- ============================================================================
do $seed$
declare
  v_org uuid;
begin
  select id into v_org from public.organizations order by created_at asc limit 1;
  if v_org is null then
    return;
  end if;

  insert into public.pricing_power_matrix_r3127 (
    organization_id, sku_code, service_category, customer_tier,
    list_price_rupees, ceiling_price_rupees, floor_price_rupees,
    target_margin_pct, cogs_rupees, quotes_issued_qty, quotes_won_qty,
    avg_realized_price_rupees, leakage_vs_list_pct, pricing_power_score,
    last_repriced_at, notes
  ) values
    (v_org, 'AMC-DENTAL-A-T1', 'amc_class_a', 'tier1_apex_hospital',
     480000.00, 540000.00, 420000.00, 42.00, 278400.00, 28, 18,
     445000.00, 7.29, 78.50, now() - interval '14 days',
     'Apollo + Manipal quotes; ceiling held at AIIMS bid'),

    (v_org, 'AMC-IMG-B-T2', 'amc_class_b', 'tier2_multispecialty',
     185000.00, 210000.00, 158000.00, 36.50, 117475.00, 42, 24,
     172500.00, 6.76, 71.20, now() - interval '21 days',
     'X-ray + CT mid-tier; Yashoda discounts to 10pct routinely'),

    (v_org, 'AMC-SS-CATH-T1', 'amc_super_specialty', 'tier1_apex_hospital',
     1250000.00, 1450000.00, 1080000.00, 48.00, 650000.00, 14, 9,
     1180000.00, 5.60, 84.30, now() - interval '7 days',
     'Cath lab AMC; Medanta + Fortis defended price'),

    (v_org, 'RPR-DENTAL-T4', 'repair_dental', 'tier4_standalone_clinic',
     8500.00, 9200.00, 7100.00, 38.00, 5270.00, 186, 142,
     7950.00, 6.47, 68.40, now() - interval '30 days',
     'Standalone dental chair repair; price-sensitive'),

    (v_org, 'RPR-IMG-T2', 'repair_imaging', 'tier2_multispecialty',
     42000.00, 48000.00, 34000.00, 40.00, 25200.00, 64, 41,
     38500.00, 8.33, 73.10, now() - interval '12 days',
     'Imaging breakdowns; LCS Continental at floor'),

    (v_org, 'RPR-LAB-T5', 'repair_lab', 'tier5_diagnostic_lab',
     18500.00, 21000.00, 15200.00, 34.50, 12122.50, 98, 71,
     17200.00, 7.03, 65.80, now() - interval '18 days',
     'Lab analyzer repair; Dr Lal chain leverages volume'),

    (v_org, 'RPR-OR-T1', 'repair_or', 'tier1_apex_hospital',
     185000.00, 215000.00, 158000.00, 45.00, 101750.00, 22, 15,
     176000.00, 4.86, 81.70, now() - interval '9 days',
     'OR table + light repair; emergency premium holds'),

    (v_org, 'SPR-OEM-CATH', 'spare_part_oem', 'tier1_apex_hospital',
     320000.00, 360000.00, 295000.00, 28.00, 230400.00, 36, 22,
     308000.00, 3.75, 82.90, now() - interval '5 days',
     'OEM cath consumable; Philips channel mark-up locked'),

    (v_org, 'SPR-REFURB-XRAY', 'spare_part_refurb', 'tier3_clinic_chain',
     54000.00, 62000.00, 42500.00, 32.50, 36450.00, 78, 52,
     49800.00, 7.78, 69.30, now() - interval '22 days',
     'Refurb X-ray tube; chain bulk pricing pressure'),

    (v_org, 'TRN-SUP-T2', 'training_supervised', 'tier2_multispecialty',
     65000.00, 74000.00, 54000.00, 52.00, 31200.00, 31, 19,
     61500.00, 5.38, 76.50, now() - interval '11 days',
     'Supervised engineer training; high-margin add-on'),

    (v_org, 'AMC-DENTAL-A-T3', 'amc_class_a', 'tier3_clinic_chain',
     245000.00, 280000.00, 198000.00, 39.00, 149450.00, 56, 33,
     224000.00, 8.57, 67.80, now() - interval '26 days',
     'Clydental + Clove chain AMC; aggressive discounting'),

    (v_org, 'RPR-IMG-GOV', 'repair_imaging', 'government',
     38000.00, 42000.00, 28000.00, 22.00, 29640.00, 19, 8,
     32500.00, 14.47, 48.20, now() - interval '45 days',
     'Govt tender pricing; State of TS leakage worst');
end;
$seed$;

-- ============================================================================
-- SEED: 12 discount-authority breach rows
-- ============================================================================
do $seed2$
declare
  v_matrix_a uuid;
  v_matrix_b uuid;
  v_matrix_c uuid;
  v_matrix_d uuid;
  v_profile uuid;
begin
  select id into v_matrix_a from public.pricing_power_matrix_r3127 where sku_code = 'AMC-DENTAL-A-T1' limit 1;
  select id into v_matrix_b from public.pricing_power_matrix_r3127 where sku_code = 'AMC-IMG-B-T2' limit 1;
  select id into v_matrix_c from public.pricing_power_matrix_r3127 where sku_code = 'RPR-IMG-GOV' limit 1;
  select id into v_matrix_d from public.pricing_power_matrix_r3127 where sku_code = 'SPR-REFURB-XRAY' limit 1;
  select id into v_profile from public.profiles order by created_at asc limit 1;

  insert into public.discount_authority_breach_r3127 (
    matrix_id, quote_reference, approver_profile_id,
    requested_discount_pct, approved_discount_pct,
    authority_level_required, authority_level_used,
    breach_severity, margin_impact_rupees, resolution_status,
    decided_at, notes
  ) values
    (v_matrix_a, 'QT-2026-04181-APOLLO', v_profile, 8.50, 8.50,
     'sales_manager', 'sales_manager', 'within_authority',
     -40800.00, 'approved_retroactively', now() - interval '6 days',
     'Apollo Hyderabad routine 8.5pct; within manager band'),

    (v_matrix_b, 'QT-2026-04221-YASHODA', v_profile, 14.50, 12.00,
     'vp_sales', 'sales_manager', 'material_breach',
     -22200.00, 'rejected_recouped', now() - interval '4 days',
     'Manager approved 12pct without VP signoff; recovered in next renewal'),

    (v_matrix_c, 'QT-2026-04244-TSGOVT', v_profile, 28.00, 26.50,
     'founder_ceo', 'vp_sales', 'grave_breach',
     -10070.00, 'rejected_writeoff', now() - interval '8 days',
     'TS government tender; VP signed 26.5pct below floor — founder gate skipped'),

    (v_matrix_d, 'QT-2026-04101-CLOVE', v_profile, 18.00, 17.00,
     'vp_sales', 'vp_sales', 'within_authority',
     -9180.00, 'approved_retroactively', now() - interval '10 days',
     'Clove chain bulk — VP within ladder'),

    (v_matrix_a, 'QT-2026-04302-MANIPAL', v_profile, 11.00, 10.50,
     'coo', 'coo', 'within_authority',
     -50400.00, 'approved_retroactively', now() - interval '3 days',
     'Manipal Vijayawada multi-site; COO signed'),

    (v_matrix_b, 'QT-2026-04155-KIMS', v_profile, 16.50, 16.50,
     'vp_sales', 'sales_rep', 'policy_violation',
     -30525.00, 'escalated_board', now() - interval '12 days',
     'Sales rep self-approved 16.5pct on KIMS; board escalation'),

    (v_matrix_c, 'QT-2026-04188-APGOVT', v_profile, 32.00, 30.00,
     'board', 'coo', 'grave_breach',
     -11400.00, 'rejected_writeoff', now() - interval '15 days',
     'AP government tender; board-only authority breached by COO'),

    (v_matrix_a, 'QT-2026-04275-AIIMS', v_profile, 6.50, 6.50,
     'sales_rep', 'sales_rep', 'within_authority',
     -31200.00, 'approved_retroactively', now() - interval '5 days',
     'AIIMS Nagpur within rep authority'),

    (v_matrix_b, 'QT-2026-04211-CONT', v_profile, 13.00, 11.50,
     'vp_sales', 'sales_manager', 'minor_breach',
     -21275.00, 'approved_retroactively', now() - interval '7 days',
     'LCS Continental — manager went 0.5pct over band'),

    (v_matrix_d, 'QT-2026-04144-METRO', v_profile, 21.50, null,
     'founder_ceo', 'sales_manager', 'material_breach',
     -11610.00, 'pending_review', null,
     'Metro chain — founder review pending'),

    (v_matrix_c, 'QT-2026-04266-KAGOVT', v_profile, 35.50, 33.00,
     'board', 'vp_sales', 'grave_breach',
     -12540.00, 'escalated_board', now() - interval '20 days',
     'Karnataka government tender; floor breached and authority breached'),

    (v_matrix_a, 'QT-2026-04299-FORTIS', v_profile, 9.50, 9.00,
     'sales_manager', 'sales_manager', 'within_authority',
     -43200.00, 'approved_retroactively', now() - interval '2 days',
     'Fortis Gurgaon; within band');
end;
$seed2$;

-- ============================================================================
-- RPC 1: pricing_power_matrix_overview_r3127
-- ============================================================================
create or replace function public.pricing_power_matrix_overview_r3127()
returns table (
  sku_code text,
  service_category text,
  customer_tier text,
  list_price_rupees numeric,
  ceiling_price_rupees numeric,
  floor_price_rupees numeric,
  avg_realized_price_rupees numeric,
  leakage_vs_list_pct numeric,
  pricing_power_score numeric,
  win_rate_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select p.sku_code, p.service_category, p.customer_tier,
         p.list_price_rupees, p.ceiling_price_rupees, p.floor_price_rupees,
         p.avg_realized_price_rupees, p.leakage_vs_list_pct, p.pricing_power_score,
         case when p.quotes_issued_qty > 0
              then round((p.quotes_won_qty::numeric * 100.0) / p.quotes_issued_qty, 2)
              else 0::numeric end,
         p.notes
  from public.pricing_power_matrix_r3127 p
  order by p.pricing_power_score desc nulls last;
end;
$fn$;

revoke execute on function public.pricing_power_matrix_overview_r3127() from public, anon;
grant execute on function public.pricing_power_matrix_overview_r3127() to authenticated;

-- ============================================================================
-- RPC 2: pricing_leakage_by_category_r3127
-- ============================================================================
create or replace function public.pricing_leakage_by_category_r3127()
returns table (
  service_category text,
  sku_count integer,
  avg_list_price numeric,
  avg_realized_price numeric,
  avg_leakage_pct numeric,
  total_quotes_issued integer,
  total_quotes_won integer,
  category_win_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select p.service_category,
         count(*)::integer,
         round(avg(p.list_price_rupees), 2),
         round(avg(p.avg_realized_price_rupees), 2),
         round(avg(p.leakage_vs_list_pct), 2),
         sum(p.quotes_issued_qty)::integer,
         sum(p.quotes_won_qty)::integer,
         case when sum(p.quotes_issued_qty) > 0
              then round((sum(p.quotes_won_qty)::numeric * 100.0) / sum(p.quotes_issued_qty), 2)
              else 0::numeric end
  from public.pricing_power_matrix_r3127 p
  group by p.service_category
  order by avg(p.leakage_vs_list_pct) desc nulls last;
end;
$fn$;

revoke execute on function public.pricing_leakage_by_category_r3127() from public, anon;
grant execute on function public.pricing_leakage_by_category_r3127() to authenticated;

-- ============================================================================
-- RPC 3: pricing_power_by_tier_r3127
-- ============================================================================
create or replace function public.pricing_power_by_tier_r3127()
returns table (
  customer_tier text,
  sku_count integer,
  avg_pricing_power_score numeric,
  avg_leakage_pct numeric,
  avg_win_rate_pct numeric,
  total_realized_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select p.customer_tier,
         count(*)::integer,
         round(avg(p.pricing_power_score), 2),
         round(avg(p.leakage_vs_list_pct), 2),
         round(avg(case when p.quotes_issued_qty > 0
                        then (p.quotes_won_qty::numeric * 100.0) / p.quotes_issued_qty
                        else 0 end), 2),
         round(sum(coalesce(p.avg_realized_price_rupees, 0) * p.quotes_won_qty), 2)
  from public.pricing_power_matrix_r3127 p
  group by p.customer_tier
  order by avg(p.pricing_power_score) desc nulls last;
end;
$fn$;

revoke execute on function public.pricing_power_by_tier_r3127() from public, anon;
grant execute on function public.pricing_power_by_tier_r3127() to authenticated;

-- ============================================================================
-- RPC 4: floor_ceiling_envelope_r3127
-- ============================================================================
create or replace function public.floor_ceiling_envelope_r3127()
returns table (
  sku_code text,
  service_category text,
  customer_tier text,
  floor_price_rupees numeric,
  list_price_rupees numeric,
  ceiling_price_rupees numeric,
  ceiling_premium_pct numeric,
  floor_discount_pct numeric,
  cogs_rupees numeric,
  floor_margin_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select p.sku_code, p.service_category, p.customer_tier,
         p.floor_price_rupees, p.list_price_rupees, p.ceiling_price_rupees,
         round(((p.ceiling_price_rupees - p.list_price_rupees) * 100.0) / p.list_price_rupees, 2),
         round(((p.list_price_rupees - p.floor_price_rupees) * 100.0) / p.list_price_rupees, 2),
         p.cogs_rupees,
         round(((p.floor_price_rupees - p.cogs_rupees) * 100.0) / p.floor_price_rupees, 2)
  from public.pricing_power_matrix_r3127 p
  order by p.service_category, p.customer_tier;
end;
$fn$;

revoke execute on function public.floor_ceiling_envelope_r3127() from public, anon;
grant execute on function public.floor_ceiling_envelope_r3127() to authenticated;

-- ============================================================================
-- RPC 5: discount_breach_log_r3127
-- ============================================================================
create or replace function public.discount_breach_log_r3127()
returns table (
  quote_reference text,
  sku_code text,
  requested_discount_pct numeric,
  approved_discount_pct numeric,
  authority_level_required text,
  authority_level_used text,
  breach_severity text,
  margin_impact_rupees numeric,
  resolution_status text,
  decided_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select b.quote_reference,
         coalesce(p.sku_code, '(unknown)'),
         b.requested_discount_pct, b.approved_discount_pct,
         b.authority_level_required, b.authority_level_used,
         b.breach_severity, b.margin_impact_rupees,
         b.resolution_status, b.decided_at
  from public.discount_authority_breach_r3127 b
  left join public.pricing_power_matrix_r3127 p on p.id = b.matrix_id
  order by b.created_at desc;
end;
$fn$;

revoke execute on function public.discount_breach_log_r3127() from public, anon;
grant execute on function public.discount_breach_log_r3127() to authenticated;

-- ============================================================================
-- RPC 6: breach_severity_rollup_r3127
-- ============================================================================
create or replace function public.breach_severity_rollup_r3127()
returns table (
  breach_severity text,
  breach_count integer,
  total_margin_impact_rupees numeric,
  avg_requested_discount_pct numeric,
  pending_count integer,
  writeoff_count integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select b.breach_severity,
         count(*)::integer,
         round(sum(b.margin_impact_rupees), 2),
         round(avg(b.requested_discount_pct), 2),
         count(*) filter (where b.resolution_status = 'pending_review')::integer,
         count(*) filter (where b.resolution_status = 'rejected_writeoff')::integer
  from public.discount_authority_breach_r3127 b
  group by b.breach_severity
  order by sum(b.margin_impact_rupees) asc;
end;
$fn$;

revoke execute on function public.breach_severity_rollup_r3127() from public, anon;
grant execute on function public.breach_severity_rollup_r3127() to authenticated;

-- ============================================================================
-- RPC 7: authority_ladder_compliance_r3127
-- ============================================================================
create or replace function public.authority_ladder_compliance_r3127()
returns table (
  authority_level_required text,
  total_breaches integer,
  within_authority_count integer,
  out_of_authority_count integer,
  compliance_pct numeric,
  total_margin_loss_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select b.authority_level_required,
         count(*)::integer,
         count(*) filter (where b.authority_level_used = b.authority_level_required)::integer,
         count(*) filter (where b.authority_level_used <> b.authority_level_required)::integer,
         round((count(*) filter (where b.authority_level_used = b.authority_level_required)::numeric * 100.0) / nullif(count(*),0), 2),
         round(sum(b.margin_impact_rupees), 2)
  from public.discount_authority_breach_r3127 b
  group by b.authority_level_required
  order by b.authority_level_required;
end;
$fn$;

revoke execute on function public.authority_ladder_compliance_r3127() from public, anon;
grant execute on function public.authority_ladder_compliance_r3127() to authenticated;

-- ============================================================================
-- RPC 8: pricing_power_top_leakage_skus_r3127
-- ============================================================================
create or replace function public.pricing_power_top_leakage_skus_r3127()
returns table (
  sku_code text,
  service_category text,
  customer_tier text,
  leakage_vs_list_pct numeric,
  margin_lost_rupees numeric,
  quotes_won_qty integer,
  pricing_power_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;

  return query
  select p.sku_code, p.service_category, p.customer_tier,
         p.leakage_vs_list_pct,
         round((p.list_price_rupees - coalesce(p.avg_realized_price_rupees, p.list_price_rupees)) * p.quotes_won_qty, 2),
         p.quotes_won_qty, p.pricing_power_score, p.notes
  from public.pricing_power_matrix_r3127 p
  where p.leakage_vs_list_pct is not null
  order by p.leakage_vs_list_pct desc
  limit 8;
end;
$fn$;

revoke execute on function public.pricing_power_top_leakage_skus_r3127() from public, anon;
grant execute on function public.pricing_power_top_leakage_skus_r3127() to authenticated;

commit;
