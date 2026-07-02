-- Round 3027: Hospital Chain Quarterly Pneumatic-Tube System End-Station Wear & Capsule Catalog Audit

create table if not exists ptube_end_station_wear_r3027 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_code text not null,
  hospital_site text not null,
  station_code text not null,
  station_zone text not null check (station_zone in ('er','icu','lab','pharmacy','blood_bank','radiology','or','ward')),
  install_date date,
  last_audit_at timestamptz,
  next_audit_due date,
  gasket_wear_pct numeric(5,2) check (gasket_wear_pct >= 0 and gasket_wear_pct <= 100),
  diverter_wear_pct numeric(5,2) check (diverter_wear_pct >= 0 and diverter_wear_pct <= 100),
  blower_hours int check (blower_hours >= 0),
  noise_db numeric(5,2) check (noise_db >= 0 and noise_db <= 140),
  capsule_arrival_count_q int check (capsule_arrival_count_q >= 0),
  jam_count_q int check (jam_count_q >= 0),
  status text not null check (status in ('healthy','watch','degraded','critical','offline'))
);

create table if not exists ptube_capsule_catalog_r3027 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_code text not null,
  capsule_sku text not null,
  capsule_size text not null check (capsule_size in ('100mm','110mm','150mm','160mm','200mm')),
  use_class text not null check (use_class in ('blood','lab_sample','pharmacy','document','sterile','radioisotope')),
  on_hand int check (on_hand >= 0),
  lost_q int check (lost_q >= 0),
  damaged_q int check (damaged_q >= 0),
  reorder_threshold int check (reorder_threshold >= 0),
  unit_cost_rupees numeric(10,2) check (unit_cost_rupees >= 0),
  last_restock_at timestamptz,
  vendor_org text,
  status text not null check (status in ('in_stock','low','reorder','obsolete','recalled'))
);

alter table ptube_end_station_wear_r3027 enable row level security;
alter table ptube_capsule_catalog_r3027 enable row level security;

drop policy if exists ptesw_r3027_founder_all on ptube_end_station_wear_r3027;
create policy ptesw_r3027_founder_all on ptube_end_station_wear_r3027 for all using (is_founder()) with check (is_founder());

drop policy if exists ptcc_r3027_founder_all on ptube_capsule_catalog_r3027;
create policy ptcc_r3027_founder_all on ptube_capsule_catalog_r3027 for all using (is_founder()) with check (is_founder());

insert into ptube_end_station_wear_r3027 (chain_code, hospital_site, station_code, station_zone, install_date, last_audit_at, next_audit_due, gasket_wear_pct, diverter_wear_pct, blower_hours, noise_db, capsule_arrival_count_q, jam_count_q, status) values
('apollo','apollo_jubilee','ST-ER-01','er','2022-03-10'::date,'2026-06-01'::timestamptz,'2026-09-01'::date,42.5,28.0,18420,72.4,4820,7,'healthy'),
('apollo','apollo_jubilee','ST-ICU-02','icu','2022-03-12'::date,'2026-06-01'::timestamptz,'2026-09-01'::date,58.2,44.0,21100,76.8,5920,14,'watch'),
('apollo','apollo_jubilee','ST-LAB-03','lab','2022-03-15'::date,'2026-06-02'::timestamptz,'2026-09-02'::date,72.0,61.0,24800,79.2,8100,28,'degraded'),
('apollo','apollo_secunderabad','ST-PH-04','pharmacy','2023-01-20'::date,'2026-06-03'::timestamptz,'2026-09-03'::date,22.0,18.0,9200,68.0,3120,3,'healthy'),
('apollo','apollo_secunderabad','ST-BB-05','blood_bank','2023-01-22'::date,'2026-06-03'::timestamptz,'2026-09-03'::date,38.0,30.0,11400,70.1,2890,5,'healthy'),
('yashoda','yashoda_somajiguda','ST-ER-06','er','2021-08-05'::date,'2026-06-04'::timestamptz,'2026-09-04'::date,85.0,78.0,31200,82.5,9450,42,'critical'),
('yashoda','yashoda_somajiguda','ST-OR-07','or','2021-08-07'::date,'2026-06-04'::timestamptz,'2026-09-04'::date,68.0,55.0,27300,77.0,6700,18,'degraded'),
('yashoda','yashoda_secunderabad','ST-RAD-08','radiology','2022-11-12'::date,'2026-06-05'::timestamptz,'2026-09-05'::date,33.0,24.0,12800,71.2,3400,4,'healthy'),
('yashoda','yashoda_secunderabad','ST-WD-09','ward','2022-11-14'::date,null,'2026-09-05'::date,null,null,null,null,null,null,'offline'),
('kims','kims_secunderabad','ST-ER-10','er','2023-05-18'::date,'2026-06-06'::timestamptz,'2026-09-06'::date,28.0,22.0,8400,69.5,3680,2,'healthy'),
('kims','kims_secunderabad','ST-ICU-11','icu','2023-05-20'::date,'2026-06-06'::timestamptz,'2026-09-06'::date,46.0,38.0,10200,73.1,4920,9,'watch'),
('kims','kims_kondapur','ST-LAB-12','lab','2023-09-22'::date,'2026-06-07'::timestamptz,'2026-09-07'::date,18.0,12.0,5400,67.0,2210,1,'healthy'),
('care','care_banjara','ST-PH-13','pharmacy','2022-06-30'::date,'2026-06-08'::timestamptz,'2026-09-08'::date,55.0,48.0,19800,75.4,5180,11,'watch'),
('care','care_banjara','ST-BB-14','blood_bank','2022-07-01'::date,'2026-06-08'::timestamptz,'2026-09-08'::date,80.0,72.0,28400,81.0,6200,35,'critical'),
('care','care_hitech','ST-OR-15','or','2024-02-10'::date,'2026-06-09'::timestamptz,'2026-09-09'::date,15.0,10.0,3200,66.2,1820,0,'healthy'),
('continental','continental_gachibowli','ST-ER-16','er','2021-11-04'::date,'2026-06-10'::timestamptz,'2026-09-10'::date,62.0,54.0,25600,76.9,7100,22,'degraded'),
('continental','continental_gachibowli','ST-ICU-17','icu','2021-11-06'::date,'2026-06-10'::timestamptz,'2026-09-10'::date,70.0,62.0,28100,78.4,8200,30,'degraded'),
('aig','aig_gachibowli','ST-LAB-18','lab','2023-03-15'::date,'2026-06-11'::timestamptz,'2026-09-11'::date,25.0,20.0,7800,69.0,3220,2,'healthy'),
('aig','aig_gachibowli','ST-RAD-19','radiology','2023-03-17'::date,'2026-06-11'::timestamptz,'2026-09-11'::date,30.0,24.0,8600,70.4,2900,3,'healthy'),
('rainbow','rainbow_banjara','ST-WD-20','ward','2022-09-08'::date,'2026-06-12'::timestamptz,'2026-09-12'::date,48.0,40.0,16200,73.8,4400,8,'watch'),
('rainbow','rainbow_hitech','ST-PH-21','pharmacy','2024-01-05'::date,'2026-06-12'::timestamptz,'2026-09-12'::date,12.0,8.0,2800,65.5,1420,0,'healthy'),
('sunshine','sunshine_paradise','ST-OR-22','or','2020-12-01'::date,'2026-06-13'::timestamptz,'2026-09-13'::date,92.0,88.0,38400,84.2,10800,55,'critical');

insert into ptube_capsule_catalog_r3027 (chain_code, capsule_sku, capsule_size, use_class, on_hand, lost_q, damaged_q, reorder_threshold, unit_cost_rupees, last_restock_at, vendor_org, status) values
('apollo','CAP-AP-160-BLOOD','160mm','blood',48,3,2,30,1850.00,'2026-05-20'::timestamptz,'pevco_india','in_stock'),
('apollo','CAP-AP-110-LAB','110mm','lab_sample',120,8,5,80,420.00,'2026-05-22'::timestamptz,'pevco_india','in_stock'),
('apollo','CAP-AP-150-PH','150mm','pharmacy',22,2,1,30,1200.00,'2026-04-18'::timestamptz,'aerocom_apac','low'),
('apollo','CAP-AP-100-DOC','100mm','document',6,1,0,20,180.00,'2026-03-10'::timestamptz,'swisslog','reorder'),
('yashoda','CAP-YA-160-BLOOD','160mm','blood',32,5,4,25,1920.00,'2026-05-12'::timestamptz,'pevco_india','in_stock'),
('yashoda','CAP-YA-110-LAB','110mm','lab_sample',88,12,6,60,440.00,'2026-05-14'::timestamptz,'pevco_india','in_stock'),
('yashoda','CAP-YA-200-STR','200mm','sterile',4,0,2,15,3400.00,null,'aerocom_apac','reorder'),
('yashoda','CAP-YA-150-RAD','150mm','radioisotope',0,0,0,8,8200.00,'2025-11-02'::timestamptz,'swisslog','recalled'),
('kims','CAP-KM-160-BLOOD','160mm','blood',58,2,1,30,1820.00,'2026-06-01'::timestamptz,'pevco_india','in_stock'),
('kims','CAP-KM-110-LAB','110mm','lab_sample',140,6,3,80,410.00,'2026-06-02'::timestamptz,'pevco_india','in_stock'),
('kims','CAP-KM-100-DOC','100mm','document',45,2,1,20,175.00,'2026-05-25'::timestamptz,'aerocom_apac','in_stock'),
('care','CAP-CR-150-PH','150mm','pharmacy',18,4,2,25,1240.00,'2026-04-30'::timestamptz,'pevco_india','low'),
('care','CAP-CR-160-BLOOD','160mm','blood',12,3,2,30,1880.00,'2026-04-12'::timestamptz,'swisslog','reorder'),
('care','CAP-CR-110-LAB','110mm','lab_sample',72,8,5,60,430.00,'2026-05-18'::timestamptz,'pevco_india','in_stock'),
('continental','CAP-CN-160-BLOOD','160mm','blood',38,4,3,30,1850.00,'2026-05-08'::timestamptz,'pevco_india','in_stock'),
('continental','CAP-CN-110-LAB','110mm','lab_sample',96,10,4,80,425.00,'2026-05-09'::timestamptz,'pevco_india','in_stock'),
('continental','CAP-CN-200-STR','200mm','sterile',7,1,0,12,3500.00,'2026-03-22'::timestamptz,'aerocom_apac','reorder'),
('aig','CAP-AG-160-BLOOD','160mm','blood',64,1,1,30,1840.00,'2026-06-05'::timestamptz,'pevco_india','in_stock'),
('aig','CAP-AG-150-RAD','150mm','radioisotope',9,0,0,8,8100.00,'2026-04-02'::timestamptz,'swisslog','in_stock'),
('rainbow','CAP-RB-110-LAB','110mm','lab_sample',82,5,2,60,420.00,'2026-05-28'::timestamptz,'pevco_india','in_stock'),
('rainbow','CAP-RB-150-PH','150mm','pharmacy',26,3,1,25,1220.00,'2026-05-29'::timestamptz,'pevco_india','in_stock'),
('sunshine','CAP-SS-160-BLOOD','160mm','blood',5,6,4,30,1900.00,'2026-02-14'::timestamptz,'swisslog','reorder'),
('sunshine','CAP-SS-110-LAB','110mm','lab_sample',34,15,8,80,440.00,'2026-04-04'::timestamptz,'pevco_india','low'),
('sunshine','CAP-SS-100-DOC','100mm','document',0,3,2,20,185.00,'2025-12-18'::timestamptz,'aerocom_apac','obsolete');

-- RPC 1: Chain-level wear summary
create or replace function ptube_r3027_chain_wear_summary()
returns table(chain_code text, station_count int, critical_count int, degraded_count int, avg_gasket numeric, avg_diverter numeric, total_jams int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.chain_code,
    count(*)::int,
    (count(*) filter (where w.status='critical'))::int,
    (count(*) filter (where w.status='degraded'))::int,
    round(avg(w.gasket_wear_pct),2),
    round(avg(w.diverter_wear_pct),2),
    coalesce(sum(w.jam_count_q),0)::int
  from ptube_end_station_wear_r3027 w
  group by w.chain_code
  order by (count(*) filter (where w.status='critical'))::int desc, w.chain_code;
end;$$;

-- RPC 2: Critical stations needing immediate replacement
create or replace function ptube_r3027_critical_stations()
returns table(chain_code text, hospital_site text, station_code text, station_zone text, gasket_wear_pct numeric, diverter_wear_pct numeric, jam_count_q int, next_audit_due date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.chain_code, w.hospital_site, w.station_code, w.station_zone, w.gasket_wear_pct, w.diverter_wear_pct, w.jam_count_q, w.next_audit_due
  from ptube_end_station_wear_r3027 w
  where w.status in ('critical','degraded')
  order by w.gasket_wear_pct desc nulls last, w.jam_count_q desc;
end;$$;

-- RPC 3: Zone wear breakdown
create or replace function ptube_r3027_zone_wear()
returns table(station_zone text, station_count int, avg_gasket numeric, max_gasket numeric, total_arrivals bigint, total_jams int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.station_zone,
    count(*)::int,
    round(avg(w.gasket_wear_pct),2),
    max(w.gasket_wear_pct),
    coalesce(sum(w.capsule_arrival_count_q),0)::bigint,
    coalesce(sum(w.jam_count_q),0)::int
  from ptube_end_station_wear_r3027 w
  group by w.station_zone
  order by avg(w.gasket_wear_pct) desc nulls last;
end;$$;

-- RPC 4: Capsule catalog reorder list
create or replace function ptube_r3027_capsule_reorder_list()
returns table(chain_code text, capsule_sku text, capsule_size text, use_class text, on_hand int, reorder_threshold int, status text, unit_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.chain_code, c.capsule_sku, c.capsule_size, c.use_class, c.on_hand, c.reorder_threshold, c.status, c.unit_cost_rupees
  from ptube_capsule_catalog_r3027 c
  where c.status in ('low','reorder','recalled','obsolete')
  order by c.status, c.chain_code;
end;$$;

-- RPC 5: Capsule loss/damage by use_class
create or replace function ptube_r3027_capsule_loss_by_class()
returns table(use_class text, sku_count int, total_lost int, total_damaged int, total_on_hand int, est_loss_value_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.use_class,
    count(*)::int,
    coalesce(sum(c.lost_q),0)::int,
    coalesce(sum(c.damaged_q),0)::int,
    coalesce(sum(c.on_hand),0)::int,
    round(coalesce(sum((c.lost_q + c.damaged_q) * c.unit_cost_rupees),0),2)
  from ptube_capsule_catalog_r3027 c
  group by c.use_class
  order by sum((c.lost_q + c.damaged_q) * c.unit_cost_rupees) desc nulls last;
end;$$;

-- RPC 6: Audit due in next 30 days
create or replace function ptube_r3027_audits_due_soon()
returns table(chain_code text, hospital_site text, station_code text, next_audit_due date, status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select w.chain_code, w.hospital_site, w.station_code, w.next_audit_due, w.status
  from ptube_end_station_wear_r3027 w
  where w.next_audit_due is not null and w.next_audit_due <= (current_date + interval '90 days')::date
  order by w.next_audit_due asc;
end;$$;

-- RPC 7: Vendor capsule exposure
create or replace function ptube_r3027_vendor_exposure()
returns table(vendor_org text, sku_count int, total_on_hand int, total_lost int, recalled_count int, exposure_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select coalesce(c.vendor_org,'unknown') as vendor_org,
    count(*)::int,
    coalesce(sum(c.on_hand),0)::int,
    coalesce(sum(c.lost_q),0)::int,
    (count(*) filter (where c.status='recalled'))::int,
    round(coalesce(sum(c.on_hand * c.unit_cost_rupees),0),2)
  from ptube_capsule_catalog_r3027 c
  group by c.vendor_org
  order by sum(c.on_hand * c.unit_cost_rupees) desc nulls last;
end;$$;

revoke all on function ptube_r3027_chain_wear_summary() from public, anon;
revoke all on function ptube_r3027_critical_stations() from public, anon;
revoke all on function ptube_r3027_zone_wear() from public, anon;
revoke all on function ptube_r3027_capsule_reorder_list() from public, anon;
revoke all on function ptube_r3027_capsule_loss_by_class() from public, anon;
revoke all on function ptube_r3027_audits_due_soon() from public, anon;
revoke all on function ptube_r3027_vendor_exposure() from public, anon;

grant execute on function ptube_r3027_chain_wear_summary() to authenticated;
grant execute on function ptube_r3027_critical_stations() to authenticated;
grant execute on function ptube_r3027_zone_wear() to authenticated;
grant execute on function ptube_r3027_capsule_reorder_list() to authenticated;
grant execute on function ptube_r3027_capsule_loss_by_class() to authenticated;
grant execute on function ptube_r3027_audits_due_soon() to authenticated;
grant execute on function ptube_r3027_vendor_exposure() to authenticated;
