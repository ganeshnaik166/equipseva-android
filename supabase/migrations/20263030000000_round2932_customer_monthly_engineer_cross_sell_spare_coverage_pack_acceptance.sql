-- Round 2932 — Customer Monthly Engineer Cross-Sell Spare Coverage Pack Acceptance
-- 1500/50 milestone crossing batch HEAVY ★★★★

-- =========================================================================
-- TABLE 1: cross-sell offers presented to customers monthly by engineers
-- =========================================================================
create table if not exists customer_monthly_xsell_offers_r2932 (
  id uuid primary key default gen_random_uuid(),
  customer_org_id uuid,
  engineer_user_id uuid,
  pack_name text not null,
  pack_tier text not null check (pack_tier in ('starter','standard','premium','enterprise')),
  monthly_price_rupees integer not null,
  spare_coverage_count integer not null,
  offered_at timestamptz not null default now(),
  expires_at timestamptz not null,
  status text not null default 'offered' check (status in ('offered','viewed','accepted','declined','expired')),
  region text not null,
  device_category text not null,
  created_at timestamptz not null default now()
);

alter table customer_monthly_xsell_offers_r2932 enable row level security;

drop policy if exists pol_xsell_offers_r2932_select on customer_monthly_xsell_offers_r2932;
create policy pol_xsell_offers_r2932_select on customer_monthly_xsell_offers_r2932 for select using (is_founder());

-- =========================================================================
-- TABLE 2: acceptance events + spare coverage pack details
-- =========================================================================
create table if not exists customer_xsell_acceptance_events_r2932 (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid references customer_monthly_xsell_offers_r2932(id) on delete cascade,
  customer_org_id uuid,
  engineer_user_id uuid,
  event_type text not null check (event_type in ('view','click','accept','decline','renewal','churn')),
  event_at timestamptz not null default now(),
  contract_value_rupees integer not null default 0,
  engineer_commission_rupees integer not null default 0,
  spare_units_covered integer not null default 0,
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  region text not null,
  pack_tier text not null,
  created_at timestamptz not null default now()
);

alter table customer_xsell_acceptance_events_r2932 enable row level security;

drop policy if exists pol_xsell_events_r2932_select on customer_xsell_acceptance_events_r2932;
create policy pol_xsell_events_r2932_select on customer_xsell_acceptance_events_r2932 for select using (is_founder());

-- =========================================================================
-- SEED DATA — offers (18 rows)
-- =========================================================================
insert into customer_monthly_xsell_offers_r2932
  (pack_name, pack_tier, monthly_price_rupees, spare_coverage_count, offered_at, expires_at, status, region, device_category) values
('Dialysis Spare Shield', 'standard', 8500, 12, (now() - interval '28 days')::timestamptz, (now() + interval '2 days')::timestamptz, 'accepted', 'Hyderabad', 'dialysis'),
('Ventilator Coverage Pro', 'premium', 14500, 20, (now() - interval '25 days')::timestamptz, (now() + interval '5 days')::timestamptz, 'accepted', 'Mumbai', 'ventilator'),
('ECG Pack Starter', 'starter', 3200, 6, (now() - interval '22 days')::timestamptz, (now() + interval '8 days')::timestamptz, 'viewed', 'Bengaluru', 'ecg'),
('OT Lights Coverage', 'standard', 6800, 10, (now() - interval '20 days')::timestamptz, (now() + interval '10 days')::timestamptz, 'accepted', 'Chennai', 'ot_lights'),
('Anesthesia Pack', 'premium', 15800, 22, (now() - interval '18 days')::timestamptz, (now() + interval '12 days')::timestamptz, 'declined', 'Delhi', 'anesthesia'),
('Defib Coverage', 'standard', 7400, 11, (now() - interval '15 days')::timestamptz, (now() + interval '15 days')::timestamptz, 'accepted', 'Pune', 'defibrillator'),
('Patient Monitor Pack', 'starter', 2900, 5, (now() - interval '14 days')::timestamptz, (now() + interval '16 days')::timestamptz, 'viewed', 'Kolkata', 'patient_monitor'),
('Enterprise Hospital Bundle', 'enterprise', 48000, 80, (now() - interval '12 days')::timestamptz, (now() + interval '18 days')::timestamptz, 'accepted', 'Hyderabad', 'multi'),
('Ultrasound Spare Shield', 'premium', 16500, 24, (now() - interval '10 days')::timestamptz, (now() + interval '20 days')::timestamptz, 'accepted', 'Mumbai', 'ultrasound'),
('X-Ray Coverage', 'standard', 9200, 14, (now() - interval '9 days')::timestamptz, (now() + interval '21 days')::timestamptz, 'offered', 'Bengaluru', 'xray'),
('Surgical Tools Pack', 'starter', 3800, 7, (now() - interval '8 days')::timestamptz, (now() + interval '22 days')::timestamptz, 'offered', 'Chennai', 'surgical'),
('Endoscope Premium', 'premium', 18200, 26, (now() - interval '7 days')::timestamptz, (now() + interval '23 days')::timestamptz, 'accepted', 'Delhi', 'endoscope'),
('CT Scanner Pack', 'enterprise', 52000, 90, (now() - interval '6 days')::timestamptz, (now() + interval '24 days')::timestamptz, 'declined', 'Pune', 'ct'),
('Pulse Oximeter Bundle', 'starter', 2400, 4, (now() - interval '5 days')::timestamptz, (now() + interval '25 days')::timestamptz, 'accepted', 'Hyderabad', 'pulse_ox'),
('Infusion Pump Coverage', 'standard', 6200, 9, (now() - interval '4 days')::timestamptz, (now() + interval '26 days')::timestamptz, 'viewed', 'Mumbai', 'infusion'),
('MRI Coverage Premium', 'enterprise', 58000, 95, (now() - interval '3 days')::timestamptz, (now() + interval '27 days')::timestamptz, 'offered', 'Bengaluru', 'mri'),
('Lab Analyzer Pack', 'premium', 13800, 18, (now() - interval '45 days')::timestamptz, (now() - interval '15 days')::timestamptz, 'expired', 'Chennai', 'lab'),
('Autoclave Coverage', 'starter', 2800, 5, (now() - interval '50 days')::timestamptz, (now() - interval '20 days')::timestamptz, 'expired', 'Delhi', 'autoclave');

-- =========================================================================
-- SEED DATA — acceptance events (22 rows)
-- =========================================================================
insert into customer_xsell_acceptance_events_r2932
  (event_type, event_at, contract_value_rupees, engineer_commission_rupees, spare_units_covered, payment_status, region, pack_tier) values
('view', (now() - interval '28 days')::timestamptz, 0, 0, 0, 'pending', 'Hyderabad', 'standard'),
('click', (now() - interval '28 days')::timestamptz, 0, 0, 0, 'pending', 'Hyderabad', 'standard'),
('accept', (now() - interval '27 days')::timestamptz, 102000, 8160, 12, 'paid', 'Hyderabad', 'standard'),
('accept', (now() - interval '24 days')::timestamptz, 174000, 13920, 20, 'paid', 'Mumbai', 'premium'),
('view', (now() - interval '22 days')::timestamptz, 0, 0, 0, 'pending', 'Bengaluru', 'starter'),
('accept', (now() - interval '19 days')::timestamptz, 81600, 6528, 10, 'paid', 'Chennai', 'standard'),
('decline', (now() - interval '17 days')::timestamptz, 0, 0, 0, 'pending', 'Delhi', 'premium'),
('accept', (now() - interval '14 days')::timestamptz, 88800, 7104, 11, 'paid', 'Pune', 'standard'),
('view', (now() - interval '13 days')::timestamptz, 0, 0, 0, 'pending', 'Kolkata', 'starter'),
('accept', (now() - interval '11 days')::timestamptz, 576000, 46080, 80, 'paid', 'Hyderabad', 'enterprise'),
('accept', (now() - interval '9 days')::timestamptz, 198000, 15840, 24, 'paid', 'Mumbai', 'premium'),
('click', (now() - interval '8 days')::timestamptz, 0, 0, 0, 'pending', 'Bengaluru', 'standard'),
('accept', (now() - interval '6 days')::timestamptz, 218400, 17472, 26, 'paid', 'Delhi', 'premium'),
('decline', (now() - interval '5 days')::timestamptz, 0, 0, 0, 'pending', 'Pune', 'enterprise'),
('accept', (now() - interval '4 days')::timestamptz, 28800, 2304, 4, 'paid', 'Hyderabad', 'starter'),
('view', (now() - interval '3 days')::timestamptz, 0, 0, 0, 'pending', 'Mumbai', 'standard'),
('renewal', (now() - interval '2 days')::timestamptz, 102000, 8160, 12, 'paid', 'Hyderabad', 'standard'),
('renewal', (now() - interval '2 days')::timestamptz, 174000, 13920, 20, 'paid', 'Mumbai', 'premium'),
('churn', (now() - interval '1 days')::timestamptz, 0, 0, 0, 'refunded', 'Chennai', 'premium'),
('accept', (now() - interval '1 days')::timestamptz, 81600, 6528, 10, 'pending', 'Chennai', 'standard'),
('view', now()::timestamptz, 0, 0, 0, 'pending', 'Bengaluru', 'enterprise'),
('click', now()::timestamptz, 0, 0, 0, 'pending', 'Delhi', 'standard');

-- =========================================================================
-- RPC 1: funnel summary
-- =========================================================================
create or replace function rpc_r2932_acceptance_funnel()
returns table (stage text, event_count integer, pct_of_views numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_views integer;
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  select (count(*) filter (where event_type = 'view'))::int into v_views from customer_xsell_acceptance_events_r2932;
  if v_views = 0 then v_views := 1; end if;
  return query
    select 'view'::text, (count(*) filter (where event_type='view'))::int,
      round(((count(*) filter (where event_type='view'))::numeric / v_views::numeric) * 100, 2)
    from customer_xsell_acceptance_events_r2932
    union all
    select 'click'::text, (count(*) filter (where event_type='click'))::int,
      round(((count(*) filter (where event_type='click'))::numeric / v_views::numeric) * 100, 2)
    from customer_xsell_acceptance_events_r2932
    union all
    select 'accept'::text, (count(*) filter (where event_type='accept'))::int,
      round(((count(*) filter (where event_type='accept'))::numeric / v_views::numeric) * 100, 2)
    from customer_xsell_acceptance_events_r2932
    union all
    select 'decline'::text, (count(*) filter (where event_type='decline'))::int,
      round(((count(*) filter (where event_type='decline'))::numeric / v_views::numeric) * 100, 2)
    from customer_xsell_acceptance_events_r2932;
end $$;

revoke execute on function rpc_r2932_acceptance_funnel() from public, anon;
grant execute on function rpc_r2932_acceptance_funnel() to authenticated;

-- =========================================================================
-- RPC 2: revenue by tier
-- =========================================================================
create or replace function rpc_r2932_revenue_by_tier()
returns table (pack_tier text, total_contract_rupees bigint, total_commission_rupees bigint, accept_count integer)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select e.pack_tier, sum(e.contract_value_rupees)::bigint, sum(e.engineer_commission_rupees)::bigint,
      (count(*) filter (where e.event_type='accept'))::int
    from customer_xsell_acceptance_events_r2932 e
    where e.event_type in ('accept','renewal')
    group by e.pack_tier
    order by sum(e.contract_value_rupees) desc;
end $$;

revoke execute on function rpc_r2932_revenue_by_tier() from public, anon;
grant execute on function rpc_r2932_revenue_by_tier() to authenticated;

-- =========================================================================
-- RPC 3: regional acceptance heatmap
-- =========================================================================
create or replace function rpc_r2932_regional_heatmap()
returns table (region text, offers_count integer, accepts_count integer, acceptance_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.region, count(*)::int,
      (count(*) filter (where o.status='accepted'))::int,
      round(((count(*) filter (where o.status='accepted'))::numeric / nullif(count(*),0)::numeric) * 100, 2)
    from customer_monthly_xsell_offers_r2932 o
    group by o.region
    order by (count(*) filter (where o.status='accepted'))::int desc;
end $$;

revoke execute on function rpc_r2932_regional_heatmap() from public, anon;
grant execute on function rpc_r2932_regional_heatmap() to authenticated;

-- =========================================================================
-- RPC 4: top device categories
-- =========================================================================
create or replace function rpc_r2932_top_device_categories()
returns table (device_category text, offers_count integer, avg_price_rupees integer, total_spare_units integer)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.device_category, count(*)::int,
      avg(o.monthly_price_rupees)::int,
      sum(o.spare_coverage_count)::int
    from customer_monthly_xsell_offers_r2932 o
    group by o.device_category
    order by count(*) desc
    limit 10;
end $$;

revoke execute on function rpc_r2932_top_device_categories() from public, anon;
grant execute on function rpc_r2932_top_device_categories() to authenticated;

-- =========================================================================
-- RPC 5: daily acceptance trend (last 30 days)
-- =========================================================================
create or replace function rpc_r2932_daily_trend()
returns table (day_bucket date, accept_count integer, contract_revenue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select (e.event_at::date)::date,
      (count(*) filter (where e.event_type='accept'))::int,
      sum(e.contract_value_rupees)::bigint
    from customer_xsell_acceptance_events_r2932 e
    where e.event_at >= (now() - interval '30 days')::timestamptz
    group by e.event_at::date
    order by e.event_at::date desc;
end $$;

revoke execute on function rpc_r2932_daily_trend() from public, anon;
grant execute on function rpc_r2932_daily_trend() to authenticated;

-- =========================================================================
-- RPC 6: expiring offers (urgency)
-- =========================================================================
create or replace function rpc_r2932_expiring_offers()
returns table (pack_name text, pack_tier text, region text, expires_at timestamptz, hours_remaining integer)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.pack_name, o.pack_tier, o.region, o.expires_at,
      (extract(epoch from (o.expires_at - now())) / 3600)::int
    from customer_monthly_xsell_offers_r2932 o
    where o.status in ('offered','viewed')
      and o.expires_at > now()
    order by o.expires_at asc
    limit 15;
end $$;

revoke execute on function rpc_r2932_expiring_offers() from public, anon;
grant execute on function rpc_r2932_expiring_offers() to authenticated;

-- =========================================================================
-- RPC 7: churn risk summary
-- =========================================================================
create or replace function rpc_r2932_churn_summary()
returns table (metric text, value_text text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select 'total_accepts'::text, (count(*) filter (where event_type='accept'))::text from customer_xsell_acceptance_events_r2932
    union all
    select 'total_renewals'::text, (count(*) filter (where event_type='renewal'))::text from customer_xsell_acceptance_events_r2932
    union all
    select 'total_churns'::text, (count(*) filter (where event_type='churn'))::text from customer_xsell_acceptance_events_r2932
    union all
    select 'net_revenue_rupees'::text, coalesce(sum(contract_value_rupees) filter (where event_type in ('accept','renewal')),0)::text from customer_xsell_acceptance_events_r2932
    union all
    select 'paid_pct'::text,
      round(((count(*) filter (where payment_status='paid'))::numeric / nullif(count(*) filter (where event_type in ('accept','renewal')),0)::numeric) * 100, 2)::text
    from customer_xsell_acceptance_events_r2932;
end $$;

revoke execute on function rpc_r2932_churn_summary() from public, anon;
grant execute on function rpc_r2932_churn_summary() to authenticated;

-- =========================================================================
-- RPC 8: high-value enterprise offers
-- =========================================================================
create or replace function rpc_r2932_enterprise_pipeline()
returns table (pack_name text, region text, device_category text, monthly_price_rupees integer, status text, offered_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select o.pack_name, o.region, o.device_category, o.monthly_price_rupees, o.status, o.offered_at
    from customer_monthly_xsell_offers_r2932 o
    where o.pack_tier in ('premium','enterprise')
    order by o.monthly_price_rupees desc
    limit 15;
end $$;

revoke execute on function rpc_r2932_enterprise_pipeline() from public, anon;
grant execute on function rpc_r2932_enterprise_pipeline() to authenticated;
