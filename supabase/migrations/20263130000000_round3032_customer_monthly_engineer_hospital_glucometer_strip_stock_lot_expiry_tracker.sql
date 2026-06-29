-- Round r3032 — Customer Monthly Engineer Hospital Glucometer Strip-Stock & Lot Expiry Tracker
-- HEAVY ★★★★ founder console pack

-- =========================
-- TABLE 1: strip stock lots
-- =========================
create table if not exists public.glucometer_strip_lots_r3032 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_name text not null,
  hospital_city text not null,
  engineer_name text not null,
  customer_account_code text not null,
  lot_number text not null,
  brand text not null check (brand in ('accu_chek','onetouch','contour','freestyle','dr_morepen','sd_codefree')),
  strip_count_initial int not null check (strip_count_initial between 25 and 600),
  strip_count_remaining int not null check (strip_count_remaining between 0 and 600),
  unit_cost_rupees numeric(10,2) not null check (unit_cost_rupees between 5 and 60),
  lot_received_on date not null,
  lot_expiry_on date not null,
  storage_status text not null check (storage_status in ('in_stock','low','depleted','expired','quarantined')),
  cold_chain_breach boolean not null default false,
  monthly_burn_rate int check (monthly_burn_rate between 0 and 400),
  reorder_triggered_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.glucometer_strip_lots_r3032 enable row level security;

drop policy if exists glucometer_strip_lots_r3032_founder_read on public.glucometer_strip_lots_r3032;
create policy glucometer_strip_lots_r3032_founder_read on public.glucometer_strip_lots_r3032
  for select to authenticated using (is_founder());

insert into public.glucometer_strip_lots_r3032
  (hospital_org_name, hospital_city, engineer_name, customer_account_code, lot_number, brand,
   strip_count_initial, strip_count_remaining, unit_cost_rupees, lot_received_on, lot_expiry_on,
   storage_status, cold_chain_breach, monthly_burn_rate, reorder_triggered_at, notes)
select 'Apollo Jubilee Hills', 'Hyderabad', 'Ravi Teja', 'CUST-AP-0011', 'AC2026-A-441', 'accu_chek',
       300, 142, 24.50, '2026-04-12'::date, '2027-04-11'::date, 'in_stock', false, 110,
       '2026-06-14 09:12:00'::timestamptz, 'Top runner — Type 2 cluster'
union all
select 'Yashoda Somajiguda', 'Hyderabad', 'Naveen Kumar', 'CUST-YS-0023', 'OT-26-B-882', 'onetouch',
       200, 18, 19.75, '2026-03-02'::date, '2026-09-30'::date, 'low', false, 95,
       '2026-06-18 11:40:00'::timestamptz, 'Reorder placed — confirm by Friday'
union all
select 'KIMS Secunderabad', 'Hyderabad', 'Pradeep Rao', 'CUST-KI-0044', 'CTR-26-C-117', 'contour',
       250, 0, 22.10, '2026-01-20'::date, '2026-12-15'::date, 'depleted', false, 130,
       '2026-06-10 08:00:00'::timestamptz, 'OOS since 19 Jun — escalate'
union all
select 'Manipal Vijayawada', 'Vijayawada', 'Surya Prakash', 'CUST-MV-0102', 'FS-25-D-559', 'freestyle',
       300, 96, 27.00, '2025-11-05'::date, '2026-07-04'::date, 'in_stock', false, 80,
       '2026-06-12 10:15:00'::timestamptz, 'Expiry < 30d — swap-out plan'
union all
select 'Care Banjara', 'Hyderabad', 'Md Imran', 'CUST-CB-0066', 'DM-26-E-201', 'dr_morepen',
       100, 64, 11.50, '2026-05-18'::date, '2027-05-17'::date, 'in_stock', false, 35,
       null::timestamptz, 'Low volume — OPD only'
union all
select 'Rainbow Hospitals', 'Hyderabad', 'Ravi Teja', 'CUST-RB-0077', 'SD-26-F-340', 'sd_codefree',
       150, 11, 9.80, '2026-04-29'::date, '2027-04-28'::date, 'low', false, 42,
       '2026-06-19 14:00:00'::timestamptz, 'Pediatric IPD — keep buffered'
union all
select 'AIG Gachibowli', 'Hyderabad', 'Naveen Kumar', 'CUST-AI-0088', 'AC2026-A-509', 'accu_chek',
       400, 220, 25.00, '2026-05-10'::date, '2027-05-09'::date, 'in_stock', false, 160,
       null::timestamptz, 'Tier-A — never let drop below 80'
union all
select 'Star Banjara', 'Hyderabad', 'Pradeep Rao', 'CUST-ST-0099', 'OT-26-B-921', 'onetouch',
       200, 0, 19.75, '2025-12-01'::date, '2026-06-15'::date, 'expired', false, 70,
       '2026-06-09 07:30:00'::timestamptz, 'EXPIRED — disposal log filed'
union all
select 'Continental Nallagandla', 'Hyderabad', 'Surya Prakash', 'CUST-CN-0110', 'CTR-26-C-228', 'contour',
       250, 188, 22.10, '2026-06-01'::date, '2027-05-31'::date, 'in_stock', false, 50,
       null::timestamptz, 'New onboard — burn ramping'
union all
select 'Sunshine Paradise', 'Hyderabad', 'Md Imran', 'CUST-SS-0121', 'FS-26-D-672', 'freestyle',
       100, 8, 27.00, '2026-04-22'::date, '2027-04-21'::date, 'low', false, 28,
       '2026-06-20 09:00:00'::timestamptz, 'Reorder PO #4471 in transit'
union all
select 'Citizen Hospital', 'Hyderabad', 'Ravi Teja', 'CUST-CT-0132', 'AC2025-A-388', 'accu_chek',
       300, 0, 24.50, '2025-09-15'::date, '2026-06-10'::date, 'expired', true, 100,
       '2026-06-11 16:00:00'::timestamptz, 'Expired + cold-chain breach — credit-noted'
union all
select 'Olive Hospitals', 'Hyderabad', 'Naveen Kumar', 'CUST-OL-0143', 'DM-26-E-455', 'dr_morepen',
       150, 102, 11.50, '2026-05-25'::date, '2027-05-24'::date, 'in_stock', false, 38,
       null::timestamptz, 'Stable — Tier-C'
union all
select 'KIMS Kurnool', 'Kurnool', 'Pradeep Rao', 'CUST-KK-0154', 'SD-26-F-411', 'sd_codefree',
       200, 41, 9.80, '2026-03-19'::date, '2026-12-18'::date, 'low', false, 55,
       '2026-06-17 12:00:00'::timestamptz, 'Distance — keep 2-week buffer'
union all
select 'Amaravati Multispeciality', 'Guntur', 'Surya Prakash', 'CUST-AM-0165', 'OT-26-B-1001', 'onetouch',
       250, 134, 19.75, '2026-05-30'::date, '2027-05-29'::date, 'in_stock', true, 60,
       null::timestamptz, 'Cold-chain breach during transit — under review'
union all
select 'Pinnacle Vizag', 'Visakhapatnam', 'Md Imran', 'CUST-PV-0176', 'CTR-26-C-330', 'contour',
       300, 175, 22.10, '2026-04-08'::date, '2027-04-07'::date, 'in_stock', false, 78,
       null::timestamptz, 'Coastal — humidity logger fine'
union all
select 'Maxivision Eye', 'Hyderabad', 'Ravi Teja', 'CUST-MX-0187', 'FS-26-D-790', 'freestyle',
       100, 0, 27.00, '2025-10-12'::date, '2026-07-10'::date, 'quarantined', false, 22,
       '2026-06-08 10:00:00'::timestamptz, 'Quarantined — manufacturer recall notice';

-- =========================
-- TABLE 2: monthly engineer hospital deliveries
-- =========================
create table if not exists public.glucometer_strip_monthly_engineer_deliveries_r3032 (
  id uuid primary key default gen_random_uuid(),
  hospital_org_name text not null,
  engineer_name text not null,
  delivery_month date not null,
  strips_delivered int not null check (strips_delivered between 0 and 2000),
  strips_consumed int not null check (strips_consumed between 0 and 2000),
  expired_units int not null check (expired_units between 0 and 500),
  quarantined_units int not null check (quarantined_units between 0 and 500),
  on_time_delivery boolean not null,
  invoice_amount_rupees numeric(12,2) not null check (invoice_amount_rupees between 0 and 250000),
  customer_satisfaction_score int check (customer_satisfaction_score between 1 and 5),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.glucometer_strip_monthly_engineer_deliveries_r3032 enable row level security;

drop policy if exists glucometer_strip_monthly_engineer_deliveries_r3032_founder_read on public.glucometer_strip_monthly_engineer_deliveries_r3032;
create policy glucometer_strip_monthly_engineer_deliveries_r3032_founder_read on public.glucometer_strip_monthly_engineer_deliveries_r3032
  for select to authenticated using (is_founder());

insert into public.glucometer_strip_monthly_engineer_deliveries_r3032
  (hospital_org_name, engineer_name, delivery_month, strips_delivered, strips_consumed,
   expired_units, quarantined_units, on_time_delivery, invoice_amount_rupees, customer_satisfaction_score, notes)
select 'Apollo Jubilee Hills','Ravi Teja','2026-06-01'::date, 300, 158, 0, 0, true, 7350.00, 5, 'Smooth — repeat order auto-approved'
union all
select 'Yashoda Somajiguda','Naveen Kumar','2026-06-01'::date, 200, 182, 0, 0, true, 3950.00, 4, 'On-time despite traffic'
union all
select 'KIMS Secunderabad','Pradeep Rao','2026-06-01'::date, 250, 250, 0, 0, false, 5525.00, 2, 'Late by 2 days — OOS gap'
union all
select 'Manipal Vijayawada','Surya Prakash','2026-06-01'::date, 300, 204, 0, 0, true, 8100.00, 5, 'Big batch — vehicle escort'
union all
select 'Care Banjara','Md Imran','2026-06-01'::date, 100, 36, 0, 0, true, 1150.00, 4, 'Steady small lot'
union all
select 'Rainbow Hospitals','Ravi Teja','2026-06-01'::date, 150, 139, 0, 0, true, 1470.00, 5, 'Ped IPD smooth'
union all
select 'AIG Gachibowli','Naveen Kumar','2026-06-01'::date, 400, 180, 0, 0, true, 10000.00, 5, 'Tier-A — buffer healthy'
union all
select 'Star Banjara','Pradeep Rao','2026-06-01'::date, 200, 200, 200, 0, false, 3950.00, 1, '200 expired — credit note ₹3950'
union all
select 'Continental Nallagandla','Surya Prakash','2026-06-01'::date, 250, 62, 0, 0, true, 5525.00, 4, 'Ramp month'
union all
select 'Sunshine Paradise','Md Imran','2026-06-01'::date, 100, 92, 0, 0, true, 2700.00, 4, 'Reorder triggered'
union all
select 'Citizen Hospital','Ravi Teja','2026-06-01'::date, 300, 300, 300, 0, false, 7350.00, 1, 'Cold-chain breach + expired'
union all
select 'Olive Hospitals','Naveen Kumar','2026-06-01'::date, 150, 48, 0, 0, true, 1725.00, 4, 'Tier-C steady'
union all
select 'KIMS Kurnool','Pradeep Rao','2026-06-01'::date, 200, 159, 0, 0, true, 1960.00, 3, 'Distance fine — driver swap'
union all
select 'Amaravati Multispeciality','Surya Prakash','2026-06-01'::date, 250, 116, 0, 250, true, 4937.50, 3, 'Quarantined post-breach'
union all
select 'Pinnacle Vizag','Md Imran','2026-06-01'::date, 300, 125, 0, 0, true, 6630.00, 4, 'Coastal route OK'
union all
select 'Maxivision Eye','Ravi Teja','2026-06-01'::date, 100, 0, 0, 100, false, 2700.00, 1, 'Manufacturer recall'
union all
select 'Apollo Jubilee Hills','Ravi Teja','2026-05-01'::date, 300, 120, 0, 0, true, 7350.00, 5, 'May steady'
union all
select 'KIMS Secunderabad','Pradeep Rao','2026-05-01'::date, 250, 220, 0, 0, true, 5525.00, 4, 'May on-time';

-- =========================
-- RPCs (7) — all is_founder gated
-- =========================

-- 1) summary KPI
create or replace function public.founder_r3032_strip_inventory_summary()
returns table(
  total_lots int,
  in_stock_lots int,
  low_lots int,
  depleted_lots int,
  expired_lots int,
  quarantined_lots int,
  total_remaining_strips bigint,
  estimated_stock_value_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where storage_status = 'in_stock'))::int,
    (count(*) filter (where storage_status = 'low'))::int,
    (count(*) filter (where storage_status = 'depleted'))::int,
    (count(*) filter (where storage_status = 'expired'))::int,
    (count(*) filter (where storage_status = 'quarantined'))::int,
    coalesce(sum(strip_count_remaining), 0)::bigint,
    coalesce(sum(strip_count_remaining * unit_cost_rupees), 0)::numeric
  from public.glucometer_strip_lots_r3032;
end;
$$;

-- 2) expiring within 60 days
create or replace function public.founder_r3032_strip_expiring_lots()
returns table(
  hospital_org_name text,
  hospital_city text,
  lot_number text,
  brand text,
  strip_count_remaining int,
  lot_expiry_on date,
  days_to_expiry int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    l.hospital_org_name,
    l.hospital_city,
    l.lot_number,
    l.brand,
    l.strip_count_remaining,
    l.lot_expiry_on,
    (l.lot_expiry_on - current_date)::int as days_to_expiry
  from public.glucometer_strip_lots_r3032 l
  where l.lot_expiry_on <= (current_date + interval '60 days')::date
    and l.storage_status not in ('expired')
  order by l.lot_expiry_on asc;
end;
$$;

-- 3) low and depleted lots needing reorder
create or replace function public.founder_r3032_strip_reorder_queue()
returns table(
  hospital_org_name text,
  engineer_name text,
  brand text,
  strip_count_remaining int,
  monthly_burn_rate int,
  storage_status text,
  reorder_triggered_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    l.hospital_org_name,
    l.engineer_name,
    l.brand,
    l.strip_count_remaining,
    l.monthly_burn_rate,
    l.storage_status,
    l.reorder_triggered_at
  from public.glucometer_strip_lots_r3032 l
  where l.storage_status in ('low','depleted')
  order by l.strip_count_remaining asc;
end;
$$;

-- 4) engineer performance
create or replace function public.founder_r3032_engineer_performance()
returns table(
  engineer_name text,
  lots_managed int,
  hospitals_served int,
  expired_lots int,
  cold_chain_breaches int,
  total_remaining bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    l.engineer_name,
    count(*)::int,
    count(distinct l.hospital_org_name)::int,
    (count(*) filter (where l.storage_status = 'expired'))::int,
    (count(*) filter (where l.cold_chain_breach = true))::int,
    coalesce(sum(l.strip_count_remaining), 0)::bigint
  from public.glucometer_strip_lots_r3032 l
  group by l.engineer_name
  order by l.engineer_name;
end;
$$;

-- 5) brand mix
create or replace function public.founder_r3032_brand_mix()
returns table(
  brand text,
  lots int,
  total_remaining bigint,
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
    l.brand,
    count(*)::int,
    coalesce(sum(l.strip_count_remaining), 0)::bigint,
    round(avg(l.unit_cost_rupees), 2)
  from public.glucometer_strip_lots_r3032 l
  group by l.brand
  order by lots desc;
end;
$$;

-- 6) monthly delivery rollup
create or replace function public.founder_r3032_monthly_delivery_rollup()
returns table(
  delivery_month date,
  hospitals int,
  total_delivered bigint,
  total_consumed bigint,
  total_expired bigint,
  total_quarantined bigint,
  on_time_pct numeric,
  total_invoice_rupees numeric,
  avg_csat numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    d.delivery_month,
    count(distinct d.hospital_org_name)::int,
    coalesce(sum(d.strips_delivered),0)::bigint,
    coalesce(sum(d.strips_consumed),0)::bigint,
    coalesce(sum(d.expired_units),0)::bigint,
    coalesce(sum(d.quarantined_units),0)::bigint,
    case when count(*) > 0
      then round((count(*) filter (where d.on_time_delivery = true))::numeric * 100 / count(*), 1)
      else 0 end,
    coalesce(sum(d.invoice_amount_rupees),0)::numeric,
    round(coalesce(avg(d.customer_satisfaction_score),0), 2)
  from public.glucometer_strip_monthly_engineer_deliveries_r3032 d
  group by d.delivery_month
  order by d.delivery_month desc;
end;
$$;

-- 7) at-risk customer accounts
create or replace function public.founder_r3032_at_risk_accounts()
returns table(
  hospital_org_name text,
  csat int,
  on_time_delivery boolean,
  expired_units int,
  quarantined_units int,
  invoice_amount_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    d.hospital_org_name,
    d.customer_satisfaction_score,
    d.on_time_delivery,
    d.expired_units,
    d.quarantined_units,
    d.invoice_amount_rupees,
    d.notes
  from public.glucometer_strip_monthly_engineer_deliveries_r3032 d
  where d.customer_satisfaction_score <= 2
     or d.expired_units > 0
     or d.quarantined_units > 0
     or d.on_time_delivery = false
  order by d.customer_satisfaction_score asc nulls last, d.expired_units desc;
end;
$$;

-- =========================
-- GRANTS
-- =========================
revoke all on public.glucometer_strip_lots_r3032 from public, anon;
revoke all on public.glucometer_strip_monthly_engineer_deliveries_r3032 from public, anon;
grant select on public.glucometer_strip_lots_r3032 to authenticated;
grant select on public.glucometer_strip_monthly_engineer_deliveries_r3032 to authenticated;

revoke all on function public.founder_r3032_strip_inventory_summary() from public, anon;
revoke all on function public.founder_r3032_strip_expiring_lots() from public, anon;
revoke all on function public.founder_r3032_strip_reorder_queue() from public, anon;
revoke all on function public.founder_r3032_engineer_performance() from public, anon;
revoke all on function public.founder_r3032_brand_mix() from public, anon;
revoke all on function public.founder_r3032_monthly_delivery_rollup() from public, anon;
revoke all on function public.founder_r3032_at_risk_accounts() from public, anon;

grant execute on function public.founder_r3032_strip_inventory_summary() to authenticated;
grant execute on function public.founder_r3032_strip_expiring_lots() to authenticated;
grant execute on function public.founder_r3032_strip_reorder_queue() to authenticated;
grant execute on function public.founder_r3032_engineer_performance() to authenticated;
grant execute on function public.founder_r3032_brand_mix() to authenticated;
grant execute on function public.founder_r3032_monthly_delivery_rollup() to authenticated;
grant execute on function public.founder_r3032_at_risk_accounts() to authenticated;
