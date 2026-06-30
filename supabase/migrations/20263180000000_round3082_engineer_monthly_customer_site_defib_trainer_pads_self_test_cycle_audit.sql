-- Round 3082: Engineer Monthly Customer Site Defibrillator Trainer-Pads & Self-Test Cycle Audit

-- ============ TABLE 1: trainer pads inventory ============
create table if not exists engineer_defib_trainer_pads_r3082 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  engineer_id uuid references engineers(id) on delete set null,
  hospital_id uuid references profiles(id) on delete set null,
  site_code text not null,
  device_model text not null,
  pads_serial text,
  pads_lot text,
  expiry_date date not null,
  last_swap_date date,
  next_swap_due date not null,
  pad_condition text not null check (pad_condition in ('fresh','good','degraded','expired','missing')),
  swap_status text not null check (swap_status in ('ok','due_soon','overdue','swapped','missing')),
  audit_month date not null,
  notes text
);

alter table engineer_defib_trainer_pads_r3082 enable row level security;

drop policy if exists pads_r3082_select on engineer_defib_trainer_pads_r3082;
create policy pads_r3082_select on engineer_defib_trainer_pads_r3082 for select using (is_founder());

-- ============ TABLE 2: self-test cycle log ============
create table if not exists engineer_defib_self_test_cycles_r3082 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  engineer_id uuid references engineers(id) on delete set null,
  hospital_id uuid references profiles(id) on delete set null,
  site_code text not null,
  device_serial text not null,
  cycle_date date not null,
  cycle_type text not null check (cycle_type in ('daily','weekly','monthly','quarterly')),
  cycle_result text not null check (cycle_result in ('pass','warn','fail','skipped','missed')),
  battery_pct int check (battery_pct between 0 and 100),
  joules_delivered numeric(6,2),
  fault_code text,
  duration_seconds int,
  audit_month date not null,
  remediation text
);

alter table engineer_defib_self_test_cycles_r3082 enable row level security;

drop policy if exists tests_r3082_select on engineer_defib_self_test_cycles_r3082;
create policy tests_r3082_select on engineer_defib_self_test_cycles_r3082 for select using (is_founder());

-- ============ SEEDS: trainer pads (16) ============
insert into engineer_defib_trainer_pads_r3082
  (site_code, device_model, pads_serial, pads_lot, expiry_date, last_swap_date, next_swap_due, pad_condition, swap_status, audit_month, notes)
values
  ('HYD-APL-01','Zoll AED Plus','PAD-A1001','LOT-2526-A','2026-09-15'::date,'2026-03-12'::date,'2026-09-12'::date,'good','due_soon','2026-06-01'::date,'Trainer pads near expiry'),
  ('HYD-KIM-02','Philips HS1','PAD-A1002','LOT-2526-B','2026-12-01'::date,'2026-06-01'::date,'2026-12-01'::date,'fresh','ok','2026-06-01'::date,null),
  ('BLR-MAN-03','Stryker LIFEPAK CR2','PAD-A1003','LOT-2425-C','2026-05-20'::date,'2025-11-20'::date,'2026-05-20'::date,'expired','overdue','2026-06-01'::date,'Past expiry — swap immediately'),
  ('CHN-APL-04','Zoll AED 3','PAD-A1004','LOT-2526-D','2027-01-10'::date,'2026-05-15'::date,'2026-11-15'::date,'fresh','ok','2026-06-01'::date,null),
  ('MUM-FOR-05','Philips FRx','PAD-A1005','LOT-2425-E','2026-04-05'::date,'2025-10-05'::date,'2026-04-05'::date,'expired','overdue','2026-06-01'::date,'Expired 2mo ago'),
  ('PUN-RUB-06','Cardiac Science G5','PAD-A1006','LOT-2526-F','2027-02-22'::date,'2026-04-22'::date,'2026-10-22'::date,'good','ok','2026-06-01'::date,null),
  ('KOL-AMI-07','Defibtech Lifeline','PAD-A1007','LOT-2526-G','2026-08-30'::date,'2026-02-28'::date,'2026-08-28'::date,'good','due_soon','2026-06-01'::date,'Due in 2 months'),
  ('AHM-STE-08','Zoll AED Plus','PAD-A1008',null,'2026-07-15'::date,null,'2026-07-15'::date,'degraded','due_soon','2026-06-01'::date,'No swap log — assume original'),
  ('JAI-FOR-09','Philips HS1','PAD-A1009','LOT-2526-I','2026-11-05'::date,'2026-05-05'::date,'2026-11-05'::date,'fresh','swapped','2026-06-01'::date,'Just swapped'),
  ('LKO-MED-10','Stryker LIFEPAK CR2','PAD-A1010','LOT-2425-J','2026-03-18'::date,'2025-09-18'::date,'2026-03-18'::date,'expired','overdue','2026-06-01'::date,'3 months past'),
  ('HYD-CON-11','Zoll AED 3','PAD-A1011','LOT-2526-K','2027-04-01'::date,'2026-06-10'::date,'2026-12-10'::date,'fresh','ok','2026-06-01'::date,null),
  ('BLR-NAR-12','Philips FRx',null,null,'2026-06-30'::date,null,'2026-06-30'::date,'missing','missing','2026-06-01'::date,'Pads cabinet empty'),
  ('CHN-MIO-13','Cardiac Science G5','PAD-A1013','LOT-2526-M','2026-10-08'::date,'2026-04-08'::date,'2026-10-08'::date,'good','due_soon','2026-06-01'::date,null),
  ('MUM-LIL-14','Defibtech Lifeline','PAD-A1014','LOT-2425-N','2026-02-14'::date,'2025-08-14'::date,'2026-02-14'::date,'expired','overdue','2026-06-01'::date,'4 months past — urgent'),
  ('PUN-JEH-15','Zoll AED Plus','PAD-A1015','LOT-2526-O','2026-12-25'::date,'2026-06-15'::date,'2026-12-15'::date,'fresh','swapped','2026-06-01'::date,'Fresh swap this audit'),
  ('KOL-CMR-16','Philips HS1','PAD-A1016','LOT-2526-P','2026-09-30'::date,'2026-03-30'::date,'2026-09-30'::date,'good','due_soon','2026-06-01'::date,null);

-- ============ SEEDS: self-test cycles (20) ============
insert into engineer_defib_self_test_cycles_r3082
  (site_code, device_serial, cycle_date, cycle_type, cycle_result, battery_pct, joules_delivered, fault_code, duration_seconds, audit_month, remediation)
values
  ('HYD-APL-01','DEV-7001','2026-06-01'::date,'monthly','pass',92,200.00,null,45,'2026-06-01'::date,null),
  ('HYD-KIM-02','DEV-7002','2026-06-01'::date,'monthly','pass',88,200.00,null,42,'2026-06-01'::date,null),
  ('BLR-MAN-03','DEV-7003','2026-06-01'::date,'monthly','fail',34,150.00,'E-204',78,'2026-06-01'::date,'Battery + capacitor swap scheduled'),
  ('CHN-APL-04','DEV-7004','2026-06-01'::date,'monthly','pass',95,200.00,null,40,'2026-06-01'::date,null),
  ('MUM-FOR-05','DEV-7005','2026-06-01'::date,'monthly','warn',62,195.50,'W-110',55,'2026-06-01'::date,'Monitor battery weekly'),
  ('PUN-RUB-06','DEV-7006','2026-06-01'::date,'monthly','pass',90,200.00,null,43,'2026-06-01'::date,null),
  ('KOL-AMI-07','DEV-7007','2026-06-01'::date,'monthly','pass',87,200.00,null,41,'2026-06-01'::date,null),
  ('AHM-STE-08','DEV-7008','2026-06-01'::date,'monthly','missed',null,null,null,null,'2026-06-01'::date,'Engineer absent — reschedule'),
  ('JAI-FOR-09','DEV-7009','2026-06-01'::date,'monthly','pass',93,200.00,null,44,'2026-06-01'::date,null),
  ('LKO-MED-10','DEV-7010','2026-06-01'::date,'monthly','fail',18,120.00,'E-301',92,'2026-06-01'::date,'Device flagged for replacement'),
  ('HYD-CON-11','DEV-7011','2026-06-01'::date,'monthly','pass',96,200.00,null,39,'2026-06-01'::date,null),
  ('BLR-NAR-12','DEV-7012','2026-06-01'::date,'monthly','skipped',null,null,null,null,'2026-06-01'::date,'Pads missing — cannot test'),
  ('CHN-MIO-13','DEV-7013','2026-06-01'::date,'monthly','warn',71,200.00,'W-115',52,'2026-06-01'::date,'Pad impedance drift'),
  ('MUM-LIL-14','DEV-7014','2026-06-01'::date,'monthly','fail',22,140.00,'E-204',88,'2026-06-01'::date,'Capacitor charge fault'),
  ('PUN-JEH-15','DEV-7015','2026-06-01'::date,'monthly','pass',94,200.00,null,40,'2026-06-01'::date,null),
  ('KOL-CMR-16','DEV-7016','2026-06-01'::date,'monthly','pass',89,200.00,null,42,'2026-06-01'::date,null),
  ('HYD-APL-01','DEV-7001','2026-05-15'::date,'weekly','pass',93,200.00,null,38,'2026-05-01'::date,null),
  ('BLR-MAN-03','DEV-7003','2026-05-15'::date,'weekly','warn',45,175.00,'W-208',60,'2026-05-01'::date,'Battery declining'),
  ('LKO-MED-10','DEV-7010','2026-05-15'::date,'weekly','fail',24,130.00,'E-301',85,'2026-05-01'::date,'Escalated last month'),
  ('MUM-LIL-14','DEV-7014','2026-05-15'::date,'weekly','warn',31,160.00,'W-204',70,'2026-05-01'::date,'Schedule full inspection');

-- ============ RPCs ============

-- RPC 1: pad condition rollup
create or replace function founder_r3082_pad_condition_rollup()
returns table(pad_condition text, n int, expired_n int, overdue_n int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.pad_condition,
         count(*)::int as n,
         (count(*) filter (where p.pad_condition = 'expired'))::int as expired_n,
         (count(*) filter (where p.swap_status = 'overdue'))::int as overdue_n
  from engineer_defib_trainer_pads_r3082 p
  group by p.pad_condition
  order by n desc;
end $$;

-- RPC 2: swap status by site
create or replace function founder_r3082_swap_status_by_site()
returns table(site_code text, device_model text, pad_condition text, swap_status text, next_swap_due date, expiry_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.site_code, p.device_model, p.pad_condition, p.swap_status, p.next_swap_due, p.expiry_date
  from engineer_defib_trainer_pads_r3082 p
  order by case p.swap_status when 'overdue' then 0 when 'missing' then 1 when 'due_soon' then 2 else 3 end, p.next_swap_due;
end $$;

-- RPC 3: self-test result rollup
create or replace function founder_r3082_self_test_rollup()
returns table(cycle_result text, n int, avg_battery numeric, avg_joules numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.cycle_result,
         count(*)::int as n,
         round(avg(t.battery_pct),1) as avg_battery,
         round(avg(t.joules_delivered),2) as avg_joules
  from engineer_defib_self_test_cycles_r3082 t
  group by t.cycle_result
  order by n desc;
end $$;

-- RPC 4: failed devices
create or replace function founder_r3082_failed_devices()
returns table(site_code text, device_serial text, cycle_result text, fault_code text, battery_pct int, remediation text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.site_code, t.device_serial, t.cycle_result, t.fault_code, t.battery_pct, t.remediation
  from engineer_defib_self_test_cycles_r3082 t
  where t.cycle_result in ('fail','warn')
  order by case t.cycle_result when 'fail' then 0 else 1 end, t.battery_pct;
end $$;

-- RPC 5: monthly compliance
create or replace function founder_r3082_monthly_compliance()
returns table(audit_month date, pads_tested int, pads_overdue int, tests_total int, tests_failed int, tests_missed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.audit_month,
         count(distinct p.site_code)::int as pads_tested,
         (count(*) filter (where p.swap_status = 'overdue'))::int as pads_overdue,
         (select count(*)::int from engineer_defib_self_test_cycles_r3082 t where t.audit_month = p.audit_month) as tests_total,
         (select (count(*) filter (where t.cycle_result = 'fail'))::int from engineer_defib_self_test_cycles_r3082 t where t.audit_month = p.audit_month) as tests_failed,
         (select (count(*) filter (where t.cycle_result in ('missed','skipped')))::int from engineer_defib_self_test_cycles_r3082 t where t.audit_month = p.audit_month) as tests_missed
  from engineer_defib_trainer_pads_r3082 p
  group by p.audit_month
  order by p.audit_month desc;
end $$;

-- RPC 6: fault code frequency
create or replace function founder_r3082_fault_code_frequency()
returns table(fault_code text, n int, sites_affected int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.fault_code,
         count(*)::int as n,
         count(distinct t.site_code)::int as sites_affected
  from engineer_defib_self_test_cycles_r3082 t
  where t.fault_code is not null
  group by t.fault_code
  order by n desc;
end $$;

-- RPC 7: urgent action queue
create or replace function founder_r3082_urgent_action_queue()
returns table(site_code text, issue text, severity text, detail text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select p.site_code,
         'pads_overdue'::text as issue,
         'high'::text as severity,
         (p.device_model || ' — expired ' || coalesce(p.expiry_date::text,'unknown'))::text as detail
  from engineer_defib_trainer_pads_r3082 p
  where p.swap_status in ('overdue','missing')
  union all
  select t.site_code,
         'device_fail'::text as issue,
         'critical'::text as severity,
         (t.device_serial || ' — fault ' || coalesce(t.fault_code,'NA'))::text as detail
  from engineer_defib_self_test_cycles_r3082 t
  where t.cycle_result = 'fail' and t.cycle_type = 'monthly'
  order by severity, site_code;
end $$;

-- ============ GRANTS ============
revoke all on function founder_r3082_pad_condition_rollup() from public, anon;
revoke all on function founder_r3082_swap_status_by_site() from public, anon;
revoke all on function founder_r3082_self_test_rollup() from public, anon;
revoke all on function founder_r3082_failed_devices() from public, anon;
revoke all on function founder_r3082_monthly_compliance() from public, anon;
revoke all on function founder_r3082_fault_code_frequency() from public, anon;
revoke all on function founder_r3082_urgent_action_queue() from public, anon;

grant execute on function founder_r3082_pad_condition_rollup() to authenticated;
grant execute on function founder_r3082_swap_status_by_site() to authenticated;
grant execute on function founder_r3082_self_test_rollup() to authenticated;
grant execute on function founder_r3082_failed_devices() to authenticated;
grant execute on function founder_r3082_monthly_compliance() to authenticated;
grant execute on function founder_r3082_fault_code_frequency() to authenticated;
grant execute on function founder_r3082_urgent_action_queue() to authenticated;
