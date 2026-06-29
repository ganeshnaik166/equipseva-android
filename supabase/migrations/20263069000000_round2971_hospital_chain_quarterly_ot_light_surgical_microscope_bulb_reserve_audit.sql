-- Round 2971: Hospital Chain Quarterly OT-Light & Surgical-Microscope Bulb Reserve Audit
-- HEAVY ★★★★

create table if not exists ot_light_bulb_reserve_audits_r2971 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_site text not null,
  ot_room_code text not null,
  fixture_type text not null check (fixture_type in ('ot_main_light','ot_satellite_light','surgical_microscope','endoscope_source','headlight_charger')),
  bulb_model text not null,
  bulb_sku text not null,
  par_level int not null check (par_level >= 0),
  on_hand_qty int not null check (on_hand_qty >= 0),
  reserve_gap int not null,
  last_replaced_on date not null,
  mean_burn_hours numeric(8,1) not null check (mean_burn_hours >= 0),
  status text not null check (status in ('healthy','watch','short','critical','expired')),
  audited_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

alter table ot_light_bulb_reserve_audits_r2971 enable row level security;
revoke all on ot_light_bulb_reserve_audits_r2971 from public, anon;

drop policy if exists ot_bulb_reserve_r2971_founder_read on ot_light_bulb_reserve_audits_r2971;
create policy ot_bulb_reserve_r2971_founder_read on ot_light_bulb_reserve_audits_r2971
  for select using (is_founder());

create table if not exists ot_bulb_reorder_signals_r2971 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_site text not null,
  bulb_sku text not null,
  signal_kind text not null check (signal_kind in ('reorder_now','reorder_soon','consolidate_with_chain','swap_to_led','sunset_legacy')),
  urgency text not null check (urgency in ('p0','p1','p2','p3')),
  recommended_qty int not null check (recommended_qty >= 0),
  unit_cost_rupees int not null check (unit_cost_rupees >= 0),
  lead_time_days int not null check (lead_time_days >= 0),
  vendor_name text not null,
  raised_at timestamptz not null default now(),
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

alter table ot_bulb_reorder_signals_r2971 enable row level security;
revoke all on ot_bulb_reorder_signals_r2971 from public, anon;

drop policy if exists ot_bulb_signals_r2971_founder_read on ot_bulb_reorder_signals_r2971;
create policy ot_bulb_signals_r2971_founder_read on ot_bulb_reorder_signals_r2971
  for select using (is_founder());

-- seed audits (16)
insert into ot_light_bulb_reserve_audits_r2971 (chain_name, hospital_site, ot_room_code, fixture_type, bulb_model, bulb_sku, par_level, on_hand_qty, reserve_gap, last_replaced_on, mean_burn_hours, status, notes) values
('Apollo','Hyd-Jubilee','OT-1','ot_main_light','MAQUET HLX-150','SKU-MAQ-150',8,2,-6,'2026-05-12'::date,1820.5,'critical','Cardiac OT, daily use'),
('Apollo','Hyd-Jubilee','OT-2','surgical_microscope','LEICA M530 OHX','SKU-LEI-530',4,3,-1,'2026-04-02'::date,640.0,'short','Neurosurgery'),
('Apollo','Chen-Greams','OT-3','ot_satellite_light','BERCHTOLD CHROMA-D','SKU-BER-CHD',6,6,0,'2026-03-18'::date,910.0,'healthy',null),
('Manipal','Blr-OldAirport','OT-1','endoscope_source','OLYMPUS CLV-S190','SKU-OLY-190',5,1,-4,'2026-05-30'::date,1240.0,'critical','GI suite'),
('Manipal','Blr-OldAirport','OT-4','ot_main_light','STERIS HARMONY LED','SKU-STE-LED',10,9,-1,'2026-02-20'::date,3200.0,'watch','LED candidate'),
('Manipal','Pune-Baner','OT-2','surgical_microscope','ZEISS OPMI VARIO 700','SKU-ZEI-700',3,0,-3,'2026-06-01'::date,710.0,'critical','ENT, no spare'),
('Fortis','Mum-Mulund','OT-1','ot_main_light','MAQUET HLX-150','SKU-MAQ-150',8,8,0,'2026-04-08'::date,1450.0,'healthy',null),
('Fortis','Gur-Sec44','OT-3','ot_satellite_light','BERCHTOLD CHROMA-D','SKU-BER-CHD',6,2,-4,'2026-05-22'::date,1010.0,'short','Orthopedic OT'),
('Fortis','Gur-Sec44','OT-5','headlight_charger','WELCH ALLYN 49020','SKU-WAL-490',4,4,0,'2025-12-11'::date,520.0,'healthy',null),
('Max','Del-Saket','OT-2','endoscope_source','KARL STORZ XENON 300','SKU-KSZ-300',5,5,0,'2026-03-04'::date,880.0,'healthy',null),
('Max','Del-Saket','OT-6','surgical_microscope','LEICA M530 OHX','SKU-LEI-530',4,1,-3,'2026-05-18'::date,690.0,'critical','Spine'),
('Narayana','Blr-HSR','OT-1','ot_main_light','MAQUET HLX-150','SKU-MAQ-150',8,4,-4,'2026-04-25'::date,1990.0,'short','Cardiac, high-volume'),
('Narayana','Hyd-Gachi','OT-3','ot_satellite_light','BERCHTOLD CHROMA-D','SKU-BER-CHD',6,5,-1,'2026-05-05'::date,860.0,'watch',null),
('AIIMS','Del-Ansari','OT-7','headlight_charger','WELCH ALLYN 49020','SKU-WAL-490',4,0,-4,'2026-06-10'::date,1100.0,'expired','Lifecycle ended'),
('Yashoda','Hyd-Somajiguda','OT-2','surgical_microscope','ZEISS OPMI VARIO 700','SKU-ZEI-700',3,3,0,'2026-02-14'::date,520.0,'healthy',null),
('KIMS','Hyd-Secun','OT-4','endoscope_source','OLYMPUS CLV-S190','SKU-OLY-190',5,3,-2,'2026-04-19'::date,1330.0,'short','GI');

-- seed signals (14)
insert into ot_bulb_reorder_signals_r2971 (chain_name, hospital_site, bulb_sku, signal_kind, urgency, recommended_qty, unit_cost_rupees, lead_time_days, vendor_name, resolved) values
('Apollo','Hyd-Jubilee','SKU-MAQ-150','reorder_now','p0',6,18500,14,'MAQUET India',false),
('Apollo','Hyd-Jubilee','SKU-LEI-530','reorder_soon','p1',2,42000,21,'Leica India',false),
('Manipal','Blr-OldAirport','SKU-OLY-190','reorder_now','p0',5,9800,10,'Olympus India',false),
('Manipal','Blr-OldAirport','SKU-STE-LED','swap_to_led','p3',1,210000,45,'Steris Healthcare',false),
('Manipal','Pune-Baner','SKU-ZEI-700','reorder_now','p0',3,38500,28,'Zeiss India',false),
('Fortis','Gur-Sec44','SKU-BER-CHD','reorder_now','p1',5,14200,18,'Berchtold/Stryker',false),
('Max','Del-Saket','SKU-LEI-530','reorder_now','p0',4,42000,21,'Leica India',false),
('Narayana','Blr-HSR','SKU-MAQ-150','consolidate_with_chain','p1',12,17200,14,'MAQUET India',false),
('Narayana','Hyd-Gachi','SKU-BER-CHD','reorder_soon','p2',2,14200,18,'Berchtold/Stryker',false),
('AIIMS','Del-Ansari','SKU-WAL-490','sunset_legacy','p2',0,0,0,'Welch Allyn',true),
('KIMS','Hyd-Secun','SKU-OLY-190','reorder_soon','p1',3,9800,10,'Olympus India',false),
('Apollo','Chen-Greams','SKU-BER-CHD','reorder_soon','p3',2,14200,18,'Berchtold/Stryker',false),
('Fortis','Mum-Mulund','SKU-MAQ-150','reorder_soon','p3',2,18500,14,'MAQUET India',true),
('Yashoda','Hyd-Somajiguda','SKU-ZEI-700','reorder_soon','p3',1,38500,28,'Zeiss India',false);

-- RPC 1: chain summary
create or replace function founder_r2971_chain_summary()
returns table(chain_name text, sites int, critical_count int, short_count int, healthy_count int, total_gap int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.chain_name,
    count(distinct a.hospital_site)::int,
    (count(*) filter (where a.status='critical'))::int,
    (count(*) filter (where a.status='short'))::int,
    (count(*) filter (where a.status='healthy'))::int,
    sum(case when a.reserve_gap < 0 then -a.reserve_gap else 0 end)::int
  from ot_light_bulb_reserve_audits_r2971 a
  group by a.chain_name
  order by total_gap desc;
end;$$;

revoke all on function founder_r2971_chain_summary() from public, anon;
grant execute on function founder_r2971_chain_summary() to authenticated;

-- RPC 2: critical fixtures
create or replace function founder_r2971_critical_fixtures()
returns table(chain_name text, hospital_site text, ot_room_code text, fixture_type text, bulb_model text, reserve_gap int, mean_burn_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.chain_name, a.hospital_site, a.ot_room_code, a.fixture_type, a.bulb_model, a.reserve_gap, a.mean_burn_hours
  from ot_light_bulb_reserve_audits_r2971 a
  where a.status in ('critical','expired')
  order by a.reserve_gap asc;
end;$$;

revoke all on function founder_r2971_critical_fixtures() from public, anon;
grant execute on function founder_r2971_critical_fixtures() to authenticated;

-- RPC 3: fixture mix
create or replace function founder_r2971_fixture_mix()
returns table(fixture_type text, audits int, avg_burn_hours numeric, short_or_worse int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.fixture_type, count(*)::int, round(avg(a.mean_burn_hours),1),
    (count(*) filter (where a.status in ('short','critical','expired')))::int
  from ot_light_bulb_reserve_audits_r2971 a
  group by a.fixture_type
  order by short_or_worse desc;
end;$$;

revoke all on function founder_r2971_fixture_mix() from public, anon;
grant execute on function founder_r2971_fixture_mix() to authenticated;

-- RPC 4: open reorder signals
create or replace function founder_r2971_open_signals()
returns table(chain_name text, hospital_site text, bulb_sku text, signal_kind text, urgency text, recommended_qty int, unit_cost_rupees int, lead_time_days int, vendor_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.chain_name, s.hospital_site, s.bulb_sku, s.signal_kind, s.urgency, s.recommended_qty, s.unit_cost_rupees, s.lead_time_days, s.vendor_name
  from ot_bulb_reorder_signals_r2971 s
  where s.resolved = false
  order by case s.urgency when 'p0' then 0 when 'p1' then 1 when 'p2' then 2 else 3 end, s.lead_time_days asc;
end;$$;

revoke all on function founder_r2971_open_signals() from public, anon;
grant execute on function founder_r2971_open_signals() to authenticated;

-- RPC 5: spend forecast
create or replace function founder_r2971_spend_forecast()
returns table(chain_name text, open_signals int, projected_rupees bigint, max_lead_days int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.chain_name,
    count(*)::int,
    sum(s.recommended_qty::bigint * s.unit_cost_rupees::bigint),
    coalesce(max(s.lead_time_days),0)::int
  from ot_bulb_reorder_signals_r2971 s
  where s.resolved = false
  group by s.chain_name
  order by projected_rupees desc nulls last;
end;$$;

revoke all on function founder_r2971_spend_forecast() from public, anon;
grant execute on function founder_r2971_spend_forecast() to authenticated;

-- RPC 6: vendor concentration
create or replace function founder_r2971_vendor_concentration()
returns table(vendor_name text, skus int, open_signals int, total_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.vendor_name,
    count(distinct s.bulb_sku)::int,
    (count(*) filter (where s.resolved=false))::int,
    sum(case when s.resolved=false then s.recommended_qty::bigint * s.unit_cost_rupees::bigint else 0 end)
  from ot_bulb_reorder_signals_r2971 s
  group by s.vendor_name
  order by total_rupees desc nulls last;
end;$$;

revoke all on function founder_r2971_vendor_concentration() from public, anon;
grant execute on function founder_r2971_vendor_concentration() to authenticated;

-- RPC 7: aging risk
create or replace function founder_r2971_aging_risk()
returns table(chain_name text, hospital_site text, bulb_model text, days_since_replace int, mean_burn_hours numeric, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select a.chain_name, a.hospital_site, a.bulb_model,
    (current_date - a.last_replaced_on)::int,
    a.mean_burn_hours, a.status
  from ot_light_bulb_reserve_audits_r2971 a
  where a.mean_burn_hours >= 800
  order by a.mean_burn_hours desc;
end;$$;

revoke all on function founder_r2971_aging_risk() from public, anon;
grant execute on function founder_r2971_aging_risk() to authenticated;