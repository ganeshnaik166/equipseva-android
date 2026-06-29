-- Round 3036 — Customer Monthly Engineer Hospital Patient-ID-Wristband Printer & Ribbon Stock Tracker
-- HEAVY ★★★★ ship

set local search_path = public, pg_temp;

-- ============================================================
-- Table 1: wristband_printers_r3036
-- ============================================================
create table if not exists public.wristband_printers_r3036 (
  id uuid primary key default gen_random_uuid(),
  hospital_code text not null,
  hospital_name text not null,
  printer_model text not null,
  serial_number text not null,
  ward_location text,
  assigned_engineer text,
  printer_status text not null check (printer_status in ('operational','degraded','offline','retired','servicing')),
  print_health_pct numeric(5,2) not null check (print_health_pct >= 0 and print_health_pct <= 100),
  monthly_print_volume int not null check (monthly_print_volume >= 0),
  last_service_on date,
  next_service_due date,
  ribbon_remaining_pct numeric(5,2) not null check (ribbon_remaining_pct >= 0 and ribbon_remaining_pct <= 100),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.wristband_printers_r3036 enable row level security;

drop policy if exists wristband_printers_r3036_founder_select on public.wristband_printers_r3036;
create policy wristband_printers_r3036_founder_select on public.wristband_printers_r3036
  for select using (public.is_founder());

revoke all on public.wristband_printers_r3036 from public, anon;
grant select on public.wristband_printers_r3036 to authenticated;

insert into public.wristband_printers_r3036
  (hospital_code, hospital_name, printer_model, serial_number, ward_location, assigned_engineer, printer_status, print_health_pct, monthly_print_volume, last_service_on, next_service_due, ribbon_remaining_pct, notes)
values
  ('APO-HYD-01','Apollo Hyderabad','Zebra ZD510-HC','ZD510HC-A1001','Ward 3A','Ravi Kumar','operational',96.50,4280,'2026-05-12'::date,'2026-07-12'::date,72.00,'monthly OK'),
  ('FOR-MUM-02','Fortis Mumbai','Zebra ZD510-HC','ZD510HC-A1002','ICU 2','Suresh Iyer','operational',92.10,3850,'2026-05-20'::date,'2026-07-20'::date,58.50,'steady volume'),
  ('AII-DEL-03','AIIMS Delhi','Honeywell PC42d','HW-PC42-B0093','OPD wing','Priya Mehra','degraded',61.80,5120,'2026-04-18'::date,'2026-06-18'::date,18.00,'ribbon low, reorder'),
  ('MAN-BLR-04','Manipal Bangalore','TSC TDP-225W','TSC-225W-3301','Maternity','Karthik V','operational',88.40,2940,'2026-05-28'::date,'2026-07-28'::date,64.30,null),
  ('KIM-HYD-05','KIMS Hyderabad','Zebra ZD510-HC','ZD510HC-A1015','Emergency','Anil Reddy','operational',94.20,4990,'2026-06-02'::date,'2026-08-02'::date,80.10,'high volume site'),
  ('YAS-CHN-06','Yashoda Chennai','Brother QL-820NWB','BR-820-9920','Ward 1B','Lakshmi N','offline',0.00,0,'2026-03-15'::date,'2026-05-15'::date,42.00,'powerhead failure'),
  ('REL-MUM-07','Reliance Mumbai','Zebra ZD510-HC','ZD510HC-A1077','ICU 1',null,'servicing',45.00,1810,'2026-06-05'::date,'2026-07-05'::date,30.00,'in repair queue'),
  ('NAR-BLR-08','Narayana Bangalore','Honeywell PC42d','HW-PC42-B0102','Pediatric','Deepak S','operational',90.70,3320,'2026-05-25'::date,'2026-07-25'::date,55.00,null),
  ('MAX-DEL-09','Max Delhi','Zebra ZD510-HC','ZD510HC-A1088','Cardio','Priya Mehra','degraded',68.90,2780,'2026-04-22'::date,'2026-06-22'::date,22.50,'rollers worn'),
  ('CMC-VEL-10','CMC Vellore','TSC TDP-225W','TSC-225W-4410','Ward 5','Joseph T','operational',97.10,3680,'2026-06-08'::date,'2026-08-08'::date,75.00,'best site'),
  ('AST-KOL-11','Asian Heart Kolkata','Zebra ZD510-HC','ZD510HC-A1099','ICU 3','Subroto B','operational',85.30,2510,'2026-05-30'::date,'2026-07-30'::date,49.00,null),
  ('CON-CHN-12','Continental Chennai','Honeywell PC42d','HW-PC42-B0118','Maternity','Lakshmi N','operational',91.40,3070,'2026-06-01'::date,'2026-08-01'::date,67.50,null),
  ('JAS-AHM-13','Jaslok Ahmedabad','Zebra ZD510-HC','ZD510HC-A1120','OPD','Mahesh P','degraded',58.20,4100,'2026-04-10'::date,'2026-06-10'::date,15.00,'critical ribbon low'),
  ('STJ-BLR-14','St Johns Bangalore','TSC TDP-225W','TSC-225W-4521','Surgery','Karthik V','operational',93.60,2870,'2026-05-22'::date,'2026-07-22'::date,68.00,null),
  ('SAR-PUN-15','Sarvodaya Pune','Brother QL-820NWB','BR-820-9988','Ward 2','Nikhil R','retired',0.00,0,'2026-02-08'::date,null,8.00,'replaced by Zebra'),
  ('GLE-MUM-16','Gleneagles Mumbai','Zebra ZD510-HC','ZD510HC-A1140','ICU 4','Suresh Iyer','operational',89.50,3950,'2026-06-04'::date,'2026-08-04'::date,71.20,null),
  ('COL-HYD-17','Columbia Hyderabad','Honeywell PC42d','HW-PC42-B0150','Pediatric','Ravi Kumar','operational',87.80,2620,'2026-05-18'::date,'2026-07-18'::date,52.40,null),
  ('FOR-DEL-18','Fortis Delhi','Zebra ZD510-HC','ZD510HC-A1155','Emergency','Priya Mehra','degraded',64.10,4720,'2026-04-25'::date,'2026-06-25'::date,19.50,'service overdue');

-- ============================================================
-- Table 2: ribbon_stock_movements_r3036
-- ============================================================
create table if not exists public.ribbon_stock_movements_r3036 (
  id uuid primary key default gen_random_uuid(),
  hospital_code text not null,
  printer_serial text not null,
  movement_type text not null check (movement_type in ('issued','consumed','returned','expired','reordered','transferred')),
  movement_on date not null,
  rolls_count int not null,
  ribbon_sku text not null,
  unit_cost_rupees numeric(10,2) not null check (unit_cost_rupees >= 0),
  total_cost_rupees numeric(12,2) not null check (total_cost_rupees >= 0),
  handled_by_engineer text,
  approval_status text not null check (approval_status in ('pending','approved','rejected','auto_approved')),
  reorder_trigger text,
  remarks text,
  created_at timestamptz not null default now()
);

alter table public.ribbon_stock_movements_r3036 enable row level security;

drop policy if exists ribbon_stock_movements_r3036_founder_select on public.ribbon_stock_movements_r3036;
create policy ribbon_stock_movements_r3036_founder_select on public.ribbon_stock_movements_r3036
  for select using (public.is_founder());

revoke all on public.ribbon_stock_movements_r3036 from public, anon;
grant select on public.ribbon_stock_movements_r3036 to authenticated;

insert into public.ribbon_stock_movements_r3036
  (hospital_code, printer_serial, movement_type, movement_on, rolls_count, ribbon_sku, unit_cost_rupees, total_cost_rupees, handled_by_engineer, approval_status, reorder_trigger, remarks)
values
  ('APO-HYD-01','ZD510HC-A1001','issued','2026-06-01'::date,6,'ZB-WB-RIB-300','420.00',2520.00,'Ravi Kumar','approved','monthly_topup','routine'),
  ('FOR-MUM-02','ZD510HC-A1002','issued','2026-06-03'::date,5,'ZB-WB-RIB-300','420.00',2100.00,'Suresh Iyer','approved','monthly_topup',null),
  ('AII-DEL-03','HW-PC42-B0093','reordered','2026-06-09'::date,12,'HW-RIB-200','310.00',3720.00,'Priya Mehra','pending','low_stock_alert','below 20pct threshold'),
  ('MAN-BLR-04','TSC-225W-3301','consumed','2026-06-05'::date,4,'TSC-RIB-225','290.00',1160.00,'Karthik V','auto_approved',null,'consumption tick'),
  ('KIM-HYD-05','ZD510HC-A1015','issued','2026-06-02'::date,8,'ZB-WB-RIB-300','420.00',3360.00,'Anil Reddy','approved','monthly_topup','high volume site'),
  ('YAS-CHN-06','BR-820-9920','returned','2026-05-28'::date,2,'BR-RIB-DK22','380.00',760.00,'Lakshmi N','approved',null,'printer offline, return rolls'),
  ('REL-MUM-07','ZD510HC-A1077','transferred','2026-06-07'::date,3,'ZB-WB-RIB-300','420.00',1260.00,null,'approved',null,'moved to FOR-MUM-02'),
  ('NAR-BLR-08','HW-PC42-B0102','issued','2026-06-04'::date,5,'HW-RIB-200','310.00',1550.00,'Deepak S','approved','monthly_topup',null),
  ('MAX-DEL-09','ZD510HC-A1088','reordered','2026-06-08'::date,10,'ZB-WB-RIB-300','420.00',4200.00,'Priya Mehra','pending','low_stock_alert','urgent'),
  ('CMC-VEL-10','TSC-225W-4410','issued','2026-06-06'::date,6,'TSC-RIB-225','290.00',1740.00,'Joseph T','approved','monthly_topup',null),
  ('AST-KOL-11','ZD510HC-A1099','consumed','2026-06-09'::date,3,'ZB-WB-RIB-300','420.00',1260.00,'Subroto B','auto_approved',null,'usage tracking'),
  ('CON-CHN-12','HW-PC42-B0118','issued','2026-06-05'::date,4,'HW-RIB-200','310.00',1240.00,'Lakshmi N','approved','monthly_topup',null),
  ('JAS-AHM-13','ZD510HC-A1120','reordered','2026-06-10'::date,15,'ZB-WB-RIB-300','420.00',6300.00,'Mahesh P','approved','critical_low','expedited delivery'),
  ('STJ-BLR-14','TSC-225W-4521','issued','2026-06-07'::date,5,'TSC-RIB-225','290.00',1450.00,'Karthik V','approved','monthly_topup',null),
  ('SAR-PUN-15','BR-820-9988','expired','2026-05-20'::date,4,'BR-RIB-DK22','380.00',1520.00,null,'rejected',null,'printer retired, stock scrapped'),
  ('GLE-MUM-16','ZD510HC-A1140','issued','2026-06-08'::date,6,'ZB-WB-RIB-300','420.00',2520.00,'Suresh Iyer','approved','monthly_topup',null),
  ('COL-HYD-17','HW-PC42-B0150','consumed','2026-06-09'::date,3,'HW-RIB-200','310.00',930.00,'Ravi Kumar','auto_approved',null,null),
  ('FOR-DEL-18','ZD510HC-A1155','reordered','2026-06-11'::date,12,'ZB-WB-RIB-300','420.00',5040.00,'Priya Mehra','pending','low_stock_alert','overdue service'),
  ('APO-HYD-01','ZD510HC-A1001','consumed','2026-06-09'::date,2,'ZB-WB-RIB-300','420.00',840.00,'Ravi Kumar','auto_approved',null,'mid-month tick'),
  ('KIM-HYD-05','ZD510HC-A1015','consumed','2026-06-10'::date,4,'ZB-WB-RIB-300','420.00',1680.00,'Anil Reddy','auto_approved',null,'high volume');

-- ============================================================
-- RPC 1: printer fleet summary
-- ============================================================
create or replace function public.r3036_printer_fleet_summary()
returns table (
  total_printers int,
  operational_count int,
  degraded_count int,
  offline_count int,
  servicing_count int,
  retired_count int,
  avg_print_health numeric,
  total_monthly_volume bigint,
  avg_ribbon_remaining numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    count(*)::int as total_printers,
    (count(*) filter (where printer_status = 'operational'))::int as operational_count,
    (count(*) filter (where printer_status = 'degraded'))::int as degraded_count,
    (count(*) filter (where printer_status = 'offline'))::int as offline_count,
    (count(*) filter (where printer_status = 'servicing'))::int as servicing_count,
    (count(*) filter (where printer_status = 'retired'))::int as retired_count,
    round(avg(print_health_pct), 2) as avg_print_health,
    sum(monthly_print_volume)::bigint as total_monthly_volume,
    round(avg(ribbon_remaining_pct), 2) as avg_ribbon_remaining
  from public.wristband_printers_r3036;
end;
$$;

revoke all on function public.r3036_printer_fleet_summary() from public, anon;
grant execute on function public.r3036_printer_fleet_summary() to authenticated;

-- ============================================================
-- RPC 2: low ribbon printers
-- ============================================================
create or replace function public.r3036_low_ribbon_printers()
returns table (
  hospital_code text,
  hospital_name text,
  printer_model text,
  serial_number text,
  ribbon_remaining_pct numeric,
  monthly_print_volume int,
  printer_status text,
  assigned_engineer text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.hospital_code,
    p.hospital_name,
    p.printer_model,
    p.serial_number,
    p.ribbon_remaining_pct,
    p.monthly_print_volume,
    p.printer_status,
    p.assigned_engineer
  from public.wristband_printers_r3036 p
  where p.ribbon_remaining_pct < 30
  order by p.ribbon_remaining_pct asc;
end;
$$;

revoke all on function public.r3036_low_ribbon_printers() from public, anon;
grant execute on function public.r3036_low_ribbon_printers() to authenticated;

-- ============================================================
-- RPC 3: engineer workload
-- ============================================================
create or replace function public.r3036_engineer_workload()
returns table (
  engineer_name text,
  printers_assigned int,
  operational_count int,
  degraded_count int,
  total_volume bigint,
  avg_health numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.assigned_engineer as engineer_name,
    count(*)::int as printers_assigned,
    (count(*) filter (where p.printer_status = 'operational'))::int as operational_count,
    (count(*) filter (where p.printer_status = 'degraded'))::int as degraded_count,
    sum(p.monthly_print_volume)::bigint as total_volume,
    round(avg(p.print_health_pct), 2) as avg_health
  from public.wristband_printers_r3036 p
  where p.assigned_engineer is not null
  group by p.assigned_engineer
  order by printers_assigned desc;
end;
$$;

revoke all on function public.r3036_engineer_workload() from public, anon;
grant execute on function public.r3036_engineer_workload() to authenticated;

-- ============================================================
-- RPC 4: ribbon spend by hospital
-- ============================================================
create or replace function public.r3036_ribbon_spend_by_hospital()
returns table (
  hospital_code text,
  total_rolls int,
  total_spend_rupees numeric,
  movements_count int,
  pending_approvals int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    m.hospital_code,
    sum(m.rolls_count)::int as total_rolls,
    sum(m.total_cost_rupees) as total_spend_rupees,
    count(*)::int as movements_count,
    (count(*) filter (where m.approval_status = 'pending'))::int as pending_approvals
  from public.ribbon_stock_movements_r3036 m
  group by m.hospital_code
  order by total_spend_rupees desc;
end;
$$;

revoke all on function public.r3036_ribbon_spend_by_hospital() from public, anon;
grant execute on function public.r3036_ribbon_spend_by_hospital() to authenticated;

-- ============================================================
-- RPC 5: reorder queue
-- ============================================================
create or replace function public.r3036_reorder_queue()
returns table (
  hospital_code text,
  printer_serial text,
  movement_on date,
  rolls_count int,
  ribbon_sku text,
  total_cost_rupees numeric,
  approval_status text,
  reorder_trigger text,
  remarks text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    m.hospital_code,
    m.printer_serial,
    m.movement_on,
    m.rolls_count,
    m.ribbon_sku,
    m.total_cost_rupees,
    m.approval_status,
    m.reorder_trigger,
    m.remarks
  from public.ribbon_stock_movements_r3036 m
  where m.movement_type = 'reordered'
  order by m.movement_on desc;
end;
$$;

revoke all on function public.r3036_reorder_queue() from public, anon;
grant execute on function public.r3036_reorder_queue() to authenticated;

-- ============================================================
-- RPC 6: service-due printers
-- ============================================================
create or replace function public.r3036_service_due_printers()
returns table (
  hospital_code text,
  hospital_name text,
  printer_model text,
  serial_number text,
  last_service_on date,
  next_service_due date,
  days_overdue int,
  printer_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    p.hospital_code,
    p.hospital_name,
    p.printer_model,
    p.serial_number,
    p.last_service_on,
    p.next_service_due,
    (current_date - p.next_service_due)::int as days_overdue,
    p.printer_status
  from public.wristband_printers_r3036 p
  where p.next_service_due is not null
    and p.next_service_due <= current_date
  order by p.next_service_due asc;
end;
$$;

revoke all on function public.r3036_service_due_printers() from public, anon;
grant execute on function public.r3036_service_due_printers() to authenticated;

-- ============================================================
-- RPC 7: ribbon sku breakdown
-- ============================================================
create or replace function public.r3036_ribbon_sku_breakdown()
returns table (
  ribbon_sku text,
  total_rolls int,
  total_spend numeric,
  hospitals_using int,
  avg_unit_cost numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    m.ribbon_sku,
    sum(m.rolls_count)::int as total_rolls,
    sum(m.total_cost_rupees) as total_spend,
    count(distinct m.hospital_code)::int as hospitals_using,
    round(avg(m.unit_cost_rupees), 2) as avg_unit_cost
  from public.ribbon_stock_movements_r3036 m
  group by m.ribbon_sku
  order by total_spend desc;
end;
$$;

revoke all on function public.r3036_ribbon_sku_breakdown() from public, anon;
grant execute on function public.r3036_ribbon_sku_breakdown() to authenticated;

-- ============================================================
-- RPC 8: movement type stats
-- ============================================================
create or replace function public.r3036_movement_type_stats()
returns table (
  movement_type text,
  movements_count int,
  total_rolls int,
  total_value numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    m.movement_type,
    count(*)::int as movements_count,
    sum(m.rolls_count)::int as total_rolls,
    sum(m.total_cost_rupees) as total_value
  from public.ribbon_stock_movements_r3036 m
  group by m.movement_type
  order by total_value desc;
end;
$$;

revoke all on function public.r3036_movement_type_stats() from public, anon;
grant execute on function public.r3036_movement_type_stats() to authenticated;
