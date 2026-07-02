-- Round 3062: Engineer Monthly Customer Site Steriliser Door Gasket & Pressure Seal Audit
-- Batch 440 milestone

set search_path = public, pg_temp;

-- ============================================================
-- TABLE 1: monthly audit visits
-- ============================================================
create table if not exists steriliser_gasket_audit_visits_r3062 (
  id uuid primary key default gen_random_uuid(),
  audit_month date not null,
  engineer_code text not null,
  hospital_code text not null,
  steriliser_asset_tag text not null,
  steriliser_model text not null,
  gasket_material text not null check (gasket_material in ('silicone','epdm','viton','nitrile','ptfe')),
  gasket_age_months int not null check (gasket_age_months between 0 and 96),
  pressure_seal_kpa numeric(7,2) not null check (pressure_seal_kpa between 0 and 350),
  leak_rate_ml_per_min numeric(6,2) not null check (leak_rate_ml_per_min between 0 and 50),
  visual_condition text not null check (visual_condition in ('pristine','minor_wear','cracks','tear','hardened')),
  replacement_recommended boolean not null,
  next_audit_due date,
  audit_status text not null check (audit_status in ('passed','passed_with_notes','flagged','failed','re_audit_required')),
  engineer_notes text,
  created_at timestamptz not null default now()
);

alter table steriliser_gasket_audit_visits_r3062 enable row level security;

drop policy if exists sgav_r3062_founder_read on steriliser_gasket_audit_visits_r3062;
create policy sgav_r3062_founder_read on steriliser_gasket_audit_visits_r3062
  for select using (is_founder());

insert into steriliser_gasket_audit_visits_r3062
  (audit_month, engineer_code, hospital_code, steriliser_asset_tag, steriliser_model, gasket_material, gasket_age_months, pressure_seal_kpa, leak_rate_ml_per_min, visual_condition, replacement_recommended, next_audit_due, audit_status, engineer_notes)
values
  ('2026-06-01'::date, 'ENG-IN-101', 'HOSP-HYD-08', 'STR-A4421', 'Getinge HS6610', 'silicone', 18, 245.50, 1.20, 'minor_wear', false, '2026-07-01'::date, 'passed', 'Minor surface wear on outer ring'),
  ('2026-06-01'::date, 'ENG-IN-102', 'HOSP-BLR-12', 'STR-B7732', 'Steris Amsco 400', 'epdm', 32, 198.25, 4.80, 'cracks', true, '2026-06-08'::date, 'flagged', 'Hairline cracks at 4 o clock position'),
  ('2026-06-01'::date, 'ENG-IN-103', 'HOSP-CHN-04', 'STR-C9912', 'Tuttnauer 3870EA', 'viton', 6, 268.00, 0.40, 'pristine', false, '2026-07-01'::date, 'passed', 'Recently replaced gasket holding well'),
  ('2026-06-01'::date, 'ENG-IN-104', 'HOSP-DEL-21', 'STR-D1145', 'Belimed WD290', 'silicone', 24, 220.75, 2.10, 'minor_wear', false, '2026-07-01'::date, 'passed_with_notes', 'Schedule preventive replacement Q3'),
  ('2026-06-01'::date, 'ENG-IN-105', 'HOSP-MUM-15', 'STR-E5567', 'Matachana S1000', 'nitrile', 48, 175.00, 8.50, 'tear', true, '2026-06-05'::date, 'failed', 'Visible tear 8mm - immediate swap'),
  ('2026-06-01'::date, 'ENG-IN-106', 'HOSP-PUN-09', 'STR-F2298', 'Getinge HS6610', 'silicone', 12, 252.30, 0.90, 'pristine', false, '2026-07-01'::date, 'passed', null),
  ('2026-06-01'::date, 'ENG-IN-107', 'HOSP-AHM-03', 'STR-G8841', 'Steris Amsco 600', 'ptfe', 60, 188.50, 6.20, 'hardened', true, '2026-06-15'::date, 'flagged', 'Material hardened past spec'),
  ('2026-06-01'::date, 'ENG-IN-101', 'HOSP-HYD-09', 'STR-H3367', 'Tuttnauer 5075', 'epdm', 8, 261.80, 0.60, 'pristine', false, '2026-07-01'::date, 'passed', null),
  ('2026-06-01'::date, 'ENG-IN-108', 'HOSP-KOL-06', 'STR-I4423', 'Belimed WD290', 'viton', 36, 215.40, 3.30, 'minor_wear', false, '2026-07-01'::date, 'passed_with_notes', 'Monitor leak rate next cycle'),
  ('2026-06-01'::date, 'ENG-IN-102', 'HOSP-BLR-13', 'STR-J7789', 'Matachana S1000', 'silicone', 20, 234.20, 1.80, 'minor_wear', false, '2026-07-01'::date, 'passed', 'Within tolerance'),
  ('2026-05-01'::date, 'ENG-IN-103', 'HOSP-CHN-05', 'STR-K1156', 'Getinge HS6610', 'silicone', 27, 210.50, 5.10, 'cracks', true, '2026-05-10'::date, 'flagged', 'Cracks observed last month'),
  ('2026-05-01'::date, 'ENG-IN-104', 'HOSP-DEL-22', 'STR-L9023', 'Steris Amsco 400', 'epdm', 14, 248.90, 1.40, 'minor_wear', false, '2026-06-01'::date, 'passed', null),
  ('2026-05-01'::date, 'ENG-IN-105', 'HOSP-MUM-16', 'STR-M4478', 'Tuttnauer 3870EA', 'viton', 4, 271.20, 0.30, 'pristine', false, '2026-06-01'::date, 'passed', null),
  ('2026-05-01'::date, 'ENG-IN-106', 'HOSP-PUN-10', 'STR-N6612', 'Belimed WD290', 'nitrile', 52, 162.50, 12.40, 'tear', true, '2026-05-05'::date, 'failed', 'Catastrophic tear during test'),
  ('2026-05-01'::date, 'ENG-IN-107', 'HOSP-AHM-04', 'STR-O2245', 'Matachana S1000', 'silicone', 16, 240.60, 1.90, 'minor_wear', false, '2026-06-01'::date, 'passed', null),
  ('2026-06-01'::date, 'ENG-IN-108', 'HOSP-KOL-07', 'STR-P5589', 'Steris Amsco 600', 'ptfe', 72, 145.30, 18.20, 'hardened', true, '2026-06-03'::date, 'failed', 'Past end-of-life by 12 months'),
  ('2026-06-01'::date, 'ENG-IN-101', 'HOSP-HYD-10', 'STR-Q1167', 'Getinge HS6610', 'silicone', 10, 256.70, 0.80, 'pristine', false, '2026-07-01'::date, 'passed', null),
  ('2026-06-01'::date, 'ENG-IN-102', 'HOSP-BLR-14', 'STR-R8834', 'Tuttnauer 5075', 'viton', 22, 228.40, 2.50, 'minor_wear', false, '2026-07-01'::date, 'passed_with_notes', null);

-- ============================================================
-- TABLE 2: gasket replacement orders
-- ============================================================
create table if not exists steriliser_gasket_replacement_orders_r3062 (
  id uuid primary key default gen_random_uuid(),
  audit_visit_ref text not null,
  engineer_code text not null,
  hospital_code text not null,
  part_sku text not null,
  part_brand text not null check (part_brand in ('oem_getinge','oem_steris','oem_tuttnauer','oem_belimed','oem_matachana','generic_certified')),
  unit_cost_rupees numeric(10,2) not null check (unit_cost_rupees between 0 and 50000),
  quantity int not null check (quantity between 1 and 20),
  order_status text not null check (order_status in ('drafted','approved','dispatched','installed','verified','cancelled')),
  approval_tier text not null check (approval_tier in ('auto','engineer','supervisor','founder')),
  ordered_at timestamptz,
  installed_at timestamptz,
  warranty_months int not null check (warranty_months between 0 and 36),
  created_at timestamptz not null default now()
);

alter table steriliser_gasket_replacement_orders_r3062 enable row level security;

drop policy if exists sgro_r3062_founder_read on steriliser_gasket_replacement_orders_r3062;
create policy sgro_r3062_founder_read on steriliser_gasket_replacement_orders_r3062
  for select using (is_founder());

insert into steriliser_gasket_replacement_orders_r3062
  (audit_visit_ref, engineer_code, hospital_code, part_sku, part_brand, unit_cost_rupees, quantity, order_status, approval_tier, ordered_at, installed_at, warranty_months)
values
  ('AV-2026-06-001', 'ENG-IN-102', 'HOSP-BLR-12', 'GSK-EPDM-B7732-A', 'oem_steris', 4250.00, 1, 'installed', 'engineer', '2026-06-02 09:15:00+05:30'::timestamptz, '2026-06-08 11:00:00+05:30'::timestamptz, 12),
  ('AV-2026-06-005', 'ENG-IN-105', 'HOSP-MUM-15', 'GSK-NIT-E5567-B', 'generic_certified', 1850.00, 1, 'installed', 'engineer', '2026-06-02 10:30:00+05:30'::timestamptz, '2026-06-05 14:20:00+05:30'::timestamptz, 6),
  ('AV-2026-06-007', 'ENG-IN-107', 'HOSP-AHM-03', 'GSK-PTFE-G8841-C', 'oem_steris', 6700.00, 1, 'dispatched', 'supervisor', '2026-06-03 08:45:00+05:30'::timestamptz, null::timestamptz, 18),
  ('AV-2026-05-011', 'ENG-IN-103', 'HOSP-CHN-05', 'GSK-SIL-K1156-A', 'oem_getinge', 5400.00, 1, 'verified', 'engineer', '2026-05-02 09:00:00+05:30'::timestamptz, '2026-05-10 13:30:00+05:30'::timestamptz, 12),
  ('AV-2026-05-014', 'ENG-IN-106', 'HOSP-PUN-10', 'GSK-NIT-N6612-D', 'oem_belimed', 3200.00, 1, 'verified', 'engineer', '2026-05-02 10:00:00+05:30'::timestamptz, '2026-05-05 15:45:00+05:30'::timestamptz, 12),
  ('AV-2026-06-016', 'ENG-IN-108', 'HOSP-KOL-07', 'GSK-PTFE-P5589-E', 'oem_steris', 7200.00, 1, 'approved', 'founder', null::timestamptz, null::timestamptz, 18),
  ('AV-2026-06-002', 'ENG-IN-102', 'HOSP-BLR-12', 'GSK-EPDM-B7732-B', 'generic_certified', 2100.00, 2, 'drafted', 'engineer', null::timestamptz, null::timestamptz, 6),
  ('AV-2026-06-008', 'ENG-IN-108', 'HOSP-KOL-06', 'GSK-VIT-I4423-F', 'oem_belimed', 5850.00, 1, 'drafted', 'supervisor', null::timestamptz, null::timestamptz, 12),
  ('AV-2026-05-013', 'ENG-IN-105', 'HOSP-MUM-16', 'GSK-VIT-M4478-G', 'oem_tuttnauer', 4900.00, 1, 'verified', 'auto', '2026-05-02 11:30:00+05:30'::timestamptz, '2026-05-09 10:15:00+05:30'::timestamptz, 12),
  ('AV-2026-06-011', 'ENG-IN-103', 'HOSP-CHN-04', 'GSK-VIT-C9912-H', 'oem_tuttnauer', 5100.00, 1, 'approved', 'auto', '2026-06-04 09:30:00+05:30'::timestamptz, null::timestamptz, 12),
  ('AV-2026-05-006', 'ENG-IN-101', 'HOSP-HYD-09', 'GSK-SIL-H3367-I', 'oem_getinge', 5600.00, 1, 'cancelled', 'engineer', null::timestamptz, null::timestamptz, 0),
  ('AV-2026-06-006', 'ENG-IN-106', 'HOSP-PUN-09', 'GSK-SIL-F2298-J', 'oem_getinge', 5750.00, 1, 'drafted', 'engineer', null::timestamptz, null::timestamptz, 12),
  ('AV-2026-06-009', 'ENG-IN-101', 'HOSP-HYD-08', 'GSK-SIL-A4421-K', 'oem_getinge', 5650.00, 1, 'approved', 'supervisor', '2026-06-05 14:00:00+05:30'::timestamptz, null::timestamptz, 12),
  ('AV-2026-06-010', 'ENG-IN-102', 'HOSP-BLR-13', 'GSK-SIL-J7789-L', 'oem_matachana', 4400.00, 1, 'dispatched', 'engineer', '2026-06-06 10:00:00+05:30'::timestamptz, null::timestamptz, 12),
  ('AV-2026-06-012', 'ENG-IN-104', 'HOSP-DEL-21', 'GSK-SIL-D1145-M', 'oem_belimed', 5300.00, 1, 'drafted', 'engineer', null::timestamptz, null::timestamptz, 12),
  ('AV-2026-06-018', 'ENG-IN-102', 'HOSP-BLR-14', 'GSK-VIT-R8834-N', 'oem_tuttnauer', 4950.00, 1, 'drafted', 'engineer', null::timestamptz, null::timestamptz, 12);

-- ============================================================
-- RPC 1: monthly audit summary
-- ============================================================
create or replace function fn_r3062_monthly_audit_summary()
returns table (
  audit_month date,
  total_audits int,
  passed_count int,
  flagged_count int,
  failed_count int,
  pass_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    v.audit_month,
    count(*)::int as total_audits,
    (count(*) filter (where v.audit_status in ('passed','passed_with_notes')))::int as passed_count,
    (count(*) filter (where v.audit_status = 'flagged'))::int as flagged_count,
    (count(*) filter (where v.audit_status = 'failed'))::int as failed_count,
    round(100.0 * (count(*) filter (where v.audit_status in ('passed','passed_with_notes')))::numeric / nullif(count(*),0), 2) as pass_rate_pct
  from steriliser_gasket_audit_visits_r3062 v
  group by v.audit_month
  order by v.audit_month desc;
end;
$$;

revoke all on function fn_r3062_monthly_audit_summary() from public, anon;
grant execute on function fn_r3062_monthly_audit_summary() to authenticated;

-- ============================================================
-- RPC 2: engineer leaderboard
-- ============================================================
create or replace function fn_r3062_engineer_leaderboard()
returns table (
  engineer_code text,
  audits_completed int,
  flagged_or_failed int,
  avg_seal_kpa numeric,
  avg_leak_rate numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    v.engineer_code,
    count(*)::int as audits_completed,
    (count(*) filter (where v.audit_status in ('flagged','failed')))::int as flagged_or_failed,
    round(avg(v.pressure_seal_kpa), 2) as avg_seal_kpa,
    round(avg(v.leak_rate_ml_per_min), 2) as avg_leak_rate
  from steriliser_gasket_audit_visits_r3062 v
  group by v.engineer_code
  order by audits_completed desc;
end;
$$;

revoke all on function fn_r3062_engineer_leaderboard() from public, anon;
grant execute on function fn_r3062_engineer_leaderboard() to authenticated;

-- ============================================================
-- RPC 3: gasket material risk profile
-- ============================================================
create or replace function fn_r3062_gasket_material_risk()
returns table (
  gasket_material text,
  total_audits int,
  failure_count int,
  avg_age_months numeric,
  avg_leak_rate numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    v.gasket_material,
    count(*)::int as total_audits,
    (count(*) filter (where v.audit_status = 'failed'))::int as failure_count,
    round(avg(v.gasket_age_months), 1) as avg_age_months,
    round(avg(v.leak_rate_ml_per_min), 2) as avg_leak_rate
  from steriliser_gasket_audit_visits_r3062 v
  group by v.gasket_material
  order by failure_count desc;
end;
$$;

revoke all on function fn_r3062_gasket_material_risk() from public, anon;
grant execute on function fn_r3062_gasket_material_risk() to authenticated;

-- ============================================================
-- RPC 4: hospitals with flagged audits
-- ============================================================
create or replace function fn_r3062_hospitals_flagged()
returns table (
  hospital_code text,
  steriliser_asset_tag text,
  audit_month date,
  audit_status text,
  leak_rate_ml_per_min numeric,
  next_audit_due date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.hospital_code, v.steriliser_asset_tag, v.audit_month, v.audit_status, v.leak_rate_ml_per_min, v.next_audit_due
  from steriliser_gasket_audit_visits_r3062 v
  where v.audit_status in ('flagged','failed','re_audit_required')
  order by v.audit_month desc, v.leak_rate_ml_per_min desc;
end;
$$;

revoke all on function fn_r3062_hospitals_flagged() from public, anon;
grant execute on function fn_r3062_hospitals_flagged() to authenticated;

-- ============================================================
-- RPC 5: replacement order pipeline
-- ============================================================
create or replace function fn_r3062_replacement_pipeline()
returns table (
  order_status text,
  order_count int,
  total_value_rupees numeric,
  avg_warranty_months numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    o.order_status,
    count(*)::int as order_count,
    round(sum(o.unit_cost_rupees * o.quantity), 2) as total_value_rupees,
    round(avg(o.warranty_months), 1) as avg_warranty_months
  from steriliser_gasket_replacement_orders_r3062 o
  group by o.order_status
  order by order_count desc;
end;
$$;

revoke all on function fn_r3062_replacement_pipeline() from public, anon;
grant execute on function fn_r3062_replacement_pipeline() to authenticated;

-- ============================================================
-- RPC 6: brand spend breakdown
-- ============================================================
create or replace function fn_r3062_brand_spend()
returns table (
  part_brand text,
  order_count int,
  units_total int,
  total_spend_rupees numeric,
  avg_unit_cost numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    o.part_brand,
    count(*)::int as order_count,
    sum(o.quantity)::int as units_total,
    round(sum(o.unit_cost_rupees * o.quantity), 2) as total_spend_rupees,
    round(avg(o.unit_cost_rupees), 2) as avg_unit_cost
  from steriliser_gasket_replacement_orders_r3062 o
  where o.order_status <> 'cancelled'
  group by o.part_brand
  order by total_spend_rupees desc;
end;
$$;

revoke all on function fn_r3062_brand_spend() from public, anon;
grant execute on function fn_r3062_brand_spend() to authenticated;

-- ============================================================
-- RPC 7: overdue replacements (approved but not installed)
-- ============================================================
create or replace function fn_r3062_overdue_replacements()
returns table (
  audit_visit_ref text,
  engineer_code text,
  hospital_code text,
  part_sku text,
  order_status text,
  ordered_at timestamptz,
  days_since_order int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    o.audit_visit_ref, o.engineer_code, o.hospital_code, o.part_sku, o.order_status, o.ordered_at,
    case when o.ordered_at is null then 0 else extract(day from (now() - o.ordered_at))::int end as days_since_order
  from steriliser_gasket_replacement_orders_r3062 o
  where o.order_status in ('approved','dispatched','drafted')
  order by o.ordered_at nulls last;
end;
$$;

revoke all on function fn_r3062_overdue_replacements() from public, anon;
grant execute on function fn_r3062_overdue_replacements() to authenticated;

-- ============================================================
-- RPC 8: approval tier mix
-- ============================================================
create or replace function fn_r3062_approval_tier_mix()
returns table (
  approval_tier text,
  order_count int,
  total_value_rupees numeric,
  pct_of_orders numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  total_orders int;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select count(*) into total_orders from steriliser_gasket_replacement_orders_r3062;
  return query
  select
    o.approval_tier,
    count(*)::int as order_count,
    round(sum(o.unit_cost_rupees * o.quantity), 2) as total_value_rupees,
    round(100.0 * count(*)::numeric / nullif(total_orders,0), 2) as pct_of_orders
  from steriliser_gasket_replacement_orders_r3062 o
  group by o.approval_tier
  order by order_count desc;
end;
$$;

revoke all on function fn_r3062_approval_tier_mix() from public, anon;
grant execute on function fn_r3062_approval_tier_mix() to authenticated;
