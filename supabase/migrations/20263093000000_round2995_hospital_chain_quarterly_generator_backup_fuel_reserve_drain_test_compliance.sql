-- Round 2995 — Hospital Chain Quarterly Generator-Backup Fuel Reserve & Drain Test Compliance
-- HEAVY ★★★★

create table if not exists generator_fuel_reserve_r2995 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_code text not null,
  hospital_site text not null,
  generator_tag text not null,
  capacity_kva int not null,
  fuel_type text not null check (fuel_type in ('diesel_hsd','diesel_bs6','biodiesel_b20','dual_fuel_lpg')),
  tank_capacity_litres int not null,
  current_reserve_litres int not null,
  reserve_percent int not null,
  quarter_label text not null check (quarter_label in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  reserve_status text not null check (reserve_status in ('above_target','at_target','below_target','critical_low','overfilled')),
  last_topup_on date not null,
  next_topup_due date not null,
  region text not null check (region in ('south','north','east','west','central')),
  monthly_burn_rate_litres int not null,
  days_of_autonomy int not null,
  compliance_flag text not null check (compliance_flag in ('green','amber','red')),
  notes text
);

create table if not exists generator_drain_test_r2995 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_code text not null,
  hospital_site text not null,
  generator_tag text not null,
  test_date date not null,
  quarter_label text not null check (quarter_label in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  test_outcome text not null check (test_outcome in ('passed','passed_with_obs','failed_load_drop','failed_no_start','failed_voltage','aborted_safety')),
  load_held_percent int not null,
  duration_minutes int not null,
  fuel_consumed_litres int not null,
  ambient_temp_c int not null,
  observed_by text not null,
  nabh_witness text not null check (nabh_witness in ('present','absent','remote_video','self_certified')),
  defect_class text not null check (defect_class in ('none','minor','major','critical','safety_hold')),
  rectified_on date,
  cert_uploaded text not null check (cert_uploaded in ('yes','no','pending_qa','rejected_qa')),
  region text not null check (region in ('south','north','east','west','central')),
  follow_up_action text
);

alter table generator_fuel_reserve_r2995 enable row level security;
alter table generator_drain_test_r2995 enable row level security;

drop policy if exists fuel_reserve_founder_select on generator_fuel_reserve_r2995;
create policy fuel_reserve_founder_select on generator_fuel_reserve_r2995 for select to authenticated using (is_founder());

drop policy if exists drain_test_founder_select on generator_drain_test_r2995;
create policy drain_test_founder_select on generator_drain_test_r2995 for select to authenticated using (is_founder());

insert into generator_fuel_reserve_r2995 (chain_code, hospital_site, generator_tag, capacity_kva, fuel_type, tank_capacity_litres, current_reserve_litres, reserve_percent, quarter_label, reserve_status, last_topup_on, next_topup_due, region, monthly_burn_rate_litres, days_of_autonomy, compliance_flag, notes) values
('APOLLO','Apollo Jubilee Hyderabad','GEN-A1',1250,'diesel_bs6',5000,4600,92,'q2_2026','above_target','2026-06-01'::date,'2026-07-15'::date,'south',1100,42,'green','top-tier'),
('APOLLO','Apollo Bengaluru Bannerghatta','GEN-A2',1000,'diesel_bs6',4000,2800,70,'q2_2026','at_target','2026-05-28'::date,'2026-07-10'::date,'south',900,31,'green','seasonal'),
('MANIPAL','Manipal Whitefield','GEN-M1',1500,'diesel_hsd',6000,3200,53,'q2_2026','below_target','2026-05-20'::date,'2026-06-25'::date,'south',1300,23,'amber','topup queued'),
('FORTIS','Fortis Mulund Mumbai','GEN-F1',1250,'diesel_bs6',5000,1100,22,'q2_2026','critical_low','2026-05-10'::date,'2026-06-22'::date,'west',1200,9,'red','escalated p1'),
('MAX','Max Saket Delhi','GEN-X1',2000,'dual_fuel_lpg',8000,7600,95,'q2_2026','overfilled','2026-06-05'::date,'2026-08-01'::date,'north',1500,50,'green','overfill ok'),
('AIIMS','AIIMS Rishikesh','GEN-I1',1500,'diesel_hsd',6000,4200,70,'q2_2026','at_target','2026-06-02'::date,'2026-07-12'::date,'north',1400,29,'green','steady'),
('KIMS','KIMS Secunderabad','GEN-K1',1000,'diesel_bs6',4000,3400,85,'q2_2026','above_target','2026-06-08'::date,'2026-07-20'::date,'south',800,42,'green','healthy') on conflict do nothing;

-- correct dual rows
insert into generator_fuel_reserve_r2995 (chain_code, hospital_site, generator_tag, capacity_kva, fuel_type, tank_capacity_litres, current_reserve_litres, reserve_percent, quarter_label, reserve_status, last_topup_on, next_topup_due, region, monthly_burn_rate_litres, days_of_autonomy, compliance_flag, notes) values
('KIMS','KIMS Kondapur','GEN-K2',1250,'diesel_bs6',5000,2400,48,'q2_2026','below_target','2026-05-22'::date,'2026-06-28'::date,'south',1100,21,'amber','topup mon'),
('NARAYANA','Narayana Bommasandra','GEN-N1',1500,'biodiesel_b20',6000,5400,90,'q2_2026','above_target','2026-06-03'::date,'2026-07-22'::date,'south',1300,41,'green','b20 trial'),
('NARAYANA','Narayana Kolkata HSR','GEN-N2',1000,'diesel_hsd',4000,800,20,'q2_2026','critical_low','2026-05-08'::date,'2026-06-20'::date,'east',1200,6,'red','flood risk'),
('MEDANTA','Medanta Gurugram','GEN-D1',2000,'diesel_bs6',8000,6800,85,'q2_2026','above_target','2026-06-04'::date,'2026-07-25'::date,'north',1700,40,'green','clean'),
('AMRI','AMRI Salt Lake Kolkata','GEN-R1',1250,'diesel_hsd',5000,2750,55,'q2_2026','at_target','2026-05-30'::date,'2026-07-05'::date,'east',1200,22,'amber','watch'),
('YASHODA','Yashoda Somajiguda Hyderabad','GEN-Y1',1500,'diesel_bs6',6000,5100,85,'q2_2026','above_target','2026-06-07'::date,'2026-07-28'::date,'south',1400,36,'green','stable'),
('CARE','CARE Banjara Hills Hyderabad','GEN-C1',1000,'diesel_bs6',4000,1600,40,'q2_2026','below_target','2026-05-18'::date,'2026-06-26'::date,'south',900,17,'amber','topup wk'),
('GLOBAL','Global Lakdikapul Hyderabad','GEN-G1',1250,'diesel_hsd',5000,4750,95,'q2_2026','overfilled','2026-06-09'::date,'2026-08-05'::date,'south',1100,43,'green','overfill ok'),
('ASTER','Aster CMI Bengaluru','GEN-S1',1500,'biodiesel_b20',6000,3600,60,'q2_2026','at_target','2026-05-26'::date,'2026-07-08'::date,'south',1300,27,'green','b20'),
('COLUMBIA','Columbia Asia Yeshwantpur','GEN-O1',1000,'diesel_bs6',4000,3000,75,'q2_2026','at_target','2026-06-01'::date,'2026-07-14'::date,'south',850,35,'green','steady'),
('RAINBOW','Rainbow Childrens Banjara','GEN-B1',800,'diesel_bs6',3000,2700,90,'q2_2026','above_target','2026-06-06'::date,'2026-07-30'::date,'south',650,41,'green','peds'),
('SAKRA','Sakra World Bengaluru','GEN-K3',1250,'diesel_hsd',5000,1250,25,'q2_2026','critical_low','2026-05-12'::date,'2026-06-23'::date,'south',1100,11,'red','vendor delay'),
('FORTIS','Fortis Bannerghatta Bengaluru','GEN-F2',1500,'diesel_bs6',6000,4800,80,'q2_2026','above_target','2026-06-04'::date,'2026-07-19'::date,'south',1300,36,'green','ok'),
('MANIPAL','Manipal Hebbal','GEN-M2',1000,'diesel_bs6',4000,2000,50,'q2_2026','below_target','2026-05-20'::date,'2026-06-27'::date,'south',900,22,'amber','topup queued'),
('AIIMS','AIIMS Bhubaneswar','GEN-I2',2000,'diesel_hsd',8000,5600,70,'q2_2026','at_target','2026-06-02'::date,'2026-07-18'::date,'east',1800,30,'green','steady'),
('MAX','Max Patparganj Delhi','GEN-X2',1500,'dual_fuel_lpg',6000,5400,90,'q2_2026','above_target','2026-06-05'::date,'2026-07-29'::date,'north',1300,41,'green','dual fuel'),
('APOLLO','Apollo Greams Chennai','GEN-A3',2000,'diesel_bs6',8000,2400,30,'q2_2026','critical_low','2026-05-09'::date,'2026-06-21'::date,'south',1800,13,'red','rush topup');

-- remove malformed insert if any
delete from generator_fuel_reserve_r2995 where reserve_status = 'above_target' and hospital_site = 'KIMS Secunderabad' and reserve_percent = 85 and current_reserve_litres = 3400 and notes = 'healthy';

insert into generator_fuel_reserve_r2995 (chain_code, hospital_site, generator_tag, capacity_kva, fuel_type, tank_capacity_litres, current_reserve_litres, reserve_percent, quarter_label, reserve_status, last_topup_on, next_topup_due, region, monthly_burn_rate_litres, days_of_autonomy, compliance_flag, notes) values
('KIMS','KIMS Secunderabad','GEN-K1',1000,'diesel_bs6',4000,3400,85,'q2_2026','above_target','2026-06-08'::date,'2026-07-20'::date,'south',800,42,'green','healthy');

insert into generator_drain_test_r2995 (chain_code, hospital_site, generator_tag, test_date, quarter_label, test_outcome, load_held_percent, duration_minutes, fuel_consumed_litres, ambient_temp_c, observed_by, nabh_witness, defect_class, rectified_on, cert_uploaded, region, follow_up_action) values
('APOLLO','Apollo Jubilee Hyderabad','GEN-A1','2026-06-10'::date,'q2_2026','passed',100,240,420,34,'Eng Ramesh','present','none',null,'yes','south','filed'),
('APOLLO','Apollo Bengaluru Bannerghatta','GEN-A2','2026-06-11'::date,'q2_2026','passed_with_obs',95,180,310,32,'Eng Priya','present','minor','2026-06-13'::date,'yes','south','vent cleaned'),
('MANIPAL','Manipal Whitefield','GEN-M1','2026-06-08'::date,'q2_2026','failed_load_drop',62,90,180,36,'Eng Suresh','remote_video','major','2026-06-15'::date,'pending_qa','south','AVR replace'),
('FORTIS','Fortis Mulund Mumbai','GEN-F1','2026-06-09'::date,'q2_2026','failed_no_start',0,15,12,38,'Eng Kapoor','present','critical','2026-06-14'::date,'rejected_qa','west','starter swap'),
('MAX','Max Saket Delhi','GEN-X1','2026-06-12'::date,'q2_2026','passed',100,300,510,40,'Eng Sinha','present','none',null,'yes','north','filed'),
('AIIMS','AIIMS Rishikesh','GEN-I1','2026-06-07'::date,'q2_2026','passed',100,240,395,28,'Eng Negi','present','none',null,'yes','north','filed'),
('KIMS','KIMS Secunderabad','GEN-K1','2026-06-10'::date,'q2_2026','passed_with_obs',92,180,275,33,'Eng Latha','self_certified','minor','2026-06-12'::date,'yes','south','battery topup'),
('KIMS','KIMS Kondapur','GEN-K2','2026-06-09'::date,'q2_2026','failed_voltage',78,120,210,34,'Eng Raju','absent','major',null,'no','south','AVR pending'),
('NARAYANA','Narayana Bommasandra','GEN-N1','2026-06-11'::date,'q2_2026','passed',100,240,400,30,'Eng Kiran','present','none',null,'yes','south','b20 ok'),
('NARAYANA','Narayana Kolkata HSR','GEN-N2','2026-06-08'::date,'q2_2026','aborted_safety',0,5,4,35,'Eng Bose','present','safety_hold','2026-06-16'::date,'rejected_qa','east','tank leak'),
('MEDANTA','Medanta Gurugram','GEN-D1','2026-06-12'::date,'q2_2026','passed',100,300,580,37,'Eng Khanna','present','none',null,'yes','north','filed'),
('AMRI','AMRI Salt Lake Kolkata','GEN-R1','2026-06-09'::date,'q2_2026','passed_with_obs',96,210,360,33,'Eng Das','remote_video','minor','2026-06-11'::date,'yes','east','exhaust clean'),
('YASHODA','Yashoda Somajiguda Hyderabad','GEN-Y1','2026-06-10'::date,'q2_2026','passed',100,240,410,34,'Eng Rao','present','none',null,'yes','south','filed'),
('CARE','CARE Banjara Hills Hyderabad','GEN-C1','2026-06-08'::date,'q2_2026','failed_load_drop',70,150,220,35,'Eng Vinod','self_certified','major','2026-06-13'::date,'pending_qa','south','breaker swap'),
('GLOBAL','Global Lakdikapul Hyderabad','GEN-G1','2026-06-11'::date,'q2_2026','passed',100,300,490,33,'Eng Reddy','present','none',null,'yes','south','filed'),
('ASTER','Aster CMI Bengaluru','GEN-S1','2026-06-10'::date,'q2_2026','passed_with_obs',94,210,340,31,'Eng Iyer','present','minor','2026-06-12'::date,'yes','south','b20 obs'),
('COLUMBIA','Columbia Asia Yeshwantpur','GEN-O1','2026-06-09'::date,'q2_2026','passed',100,210,300,32,'Eng Murthy','present','none',null,'yes','south','filed'),
('RAINBOW','Rainbow Childrens Banjara','GEN-B1','2026-06-11'::date,'q2_2026','passed',100,180,240,33,'Eng Latha','present','none',null,'yes','south','peds ok'),
('SAKRA','Sakra World Bengaluru','GEN-K3','2026-06-08'::date,'q2_2026','failed_no_start',0,20,18,36,'Eng Babu','absent','critical',null,'no','south','ECU fault'),
('FORTIS','Fortis Bannerghatta Bengaluru','GEN-F2','2026-06-12'::date,'q2_2026','passed',100,240,400,34,'Eng Mohan','present','none',null,'yes','south','filed'),
('MANIPAL','Manipal Hebbal','GEN-M2','2026-06-09'::date,'q2_2026','passed_with_obs',91,180,280,33,'Eng Suresh','remote_video','minor','2026-06-11'::date,'yes','south','vent cleaned'),
('AIIMS','AIIMS Bhubaneswar','GEN-I2','2026-06-10'::date,'q2_2026','passed',100,300,560,32,'Eng Patro','present','none',null,'yes','east','filed'),
('MAX','Max Patparganj Delhi','GEN-X2','2026-06-11'::date,'q2_2026','passed_with_obs',95,240,400,38,'Eng Sinha','present','minor','2026-06-13'::date,'yes','north','dual fuel obs'),
('APOLLO','Apollo Greams Chennai','GEN-A3','2026-06-08'::date,'q2_2026','failed_voltage',74,120,240,37,'Eng Suresh','self_certified','major','2026-06-14'::date,'pending_qa','south','AVR replace');

-- RPC 1: reserve summary by chain
create or replace function r2995_reserve_summary_by_chain()
returns table(chain_code text, sites int, avg_reserve_pct int, red_sites int, amber_sites int, green_sites int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.chain_code,
    count(*)::int,
    avg(g.reserve_percent)::int,
    (count(*) filter (where g.compliance_flag='red'))::int,
    (count(*) filter (where g.compliance_flag='amber'))::int,
    (count(*) filter (where g.compliance_flag='green'))::int
  from generator_fuel_reserve_r2995 g
  group by g.chain_code
  order by red_sites desc, amber_sites desc;
end;$$;

-- RPC 2: critical low sites
create or replace function r2995_critical_low_sites()
returns table(chain_code text, hospital_site text, generator_tag text, reserve_percent int, days_of_autonomy int, next_topup_due date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.chain_code, g.hospital_site, g.generator_tag, g.reserve_percent, g.days_of_autonomy, g.next_topup_due
  from generator_fuel_reserve_r2995 g
  where g.reserve_status in ('critical_low','below_target')
  order by g.reserve_percent asc;
end;$$;

-- RPC 3: drain test outcome distribution
create or replace function r2995_drain_outcome_distribution()
returns table(test_outcome text, n int, avg_load int, avg_duration int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.test_outcome, count(*)::int, avg(d.load_held_percent)::int, avg(d.duration_minutes)::int
  from generator_drain_test_r2995 d
  group by d.test_outcome
  order by n desc;
end;$$;

-- RPC 4: defect breakdown by region
create or replace function r2995_defect_by_region()
returns table(region text, critical int, major int, minor int, safety_hold int, none_clean int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.region,
    (count(*) filter (where d.defect_class='critical'))::int,
    (count(*) filter (where d.defect_class='major'))::int,
    (count(*) filter (where d.defect_class='minor'))::int,
    (count(*) filter (where d.defect_class='safety_hold'))::int,
    (count(*) filter (where d.defect_class='none'))::int
  from generator_drain_test_r2995 d
  group by d.region
  order by critical desc, major desc;
end;$$;

-- RPC 5: fuel-type mix
create or replace function r2995_fuel_type_mix()
returns table(fuel_type text, sites int, total_capacity_litres bigint, total_reserve_litres bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.fuel_type, count(*)::int, sum(g.tank_capacity_litres)::bigint, sum(g.current_reserve_litres)::bigint
  from generator_fuel_reserve_r2995 g
  group by g.fuel_type
  order by sites desc;
end;$$;

-- RPC 6: nabh witness coverage
create or replace function r2995_nabh_witness_coverage()
returns table(nabh_witness text, tests int, pass_rate_pct int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.nabh_witness,
    count(*)::int,
    (100.0 * (count(*) filter (where d.test_outcome in ('passed','passed_with_obs'))) / nullif(count(*),0))::int
  from generator_drain_test_r2995 d
  group by d.nabh_witness
  order by tests desc;
end;$$;

-- RPC 7: cert upload backlog
create or replace function r2995_cert_upload_backlog()
returns table(cert_uploaded text, n int, last_test_date date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select d.cert_uploaded, count(*)::int, max(d.test_date)
  from generator_drain_test_r2995 d
  group by d.cert_uploaded
  order by n desc;
end;$$;

-- RPC 8: cross-join risk score per site
create or replace function r2995_site_risk_score()
returns table(chain_code text, hospital_site text, reserve_pct int, last_outcome text, defect_class text, risk_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select g.chain_code, g.hospital_site, g.reserve_percent,
    coalesce(d.test_outcome,'no_test') as last_outcome,
    coalesce(d.defect_class,'none') as defect_class,
    (case when g.reserve_percent < 30 then 40 when g.reserve_percent < 60 then 20 else 0 end
     + case when d.defect_class='critical' then 40 when d.defect_class='major' then 25 when d.defect_class='safety_hold' then 35 when d.defect_class='minor' then 10 else 0 end
     + case when d.test_outcome like 'failed%' then 15 when d.test_outcome='aborted_safety' then 20 else 0 end)::int as risk_score
  from generator_fuel_reserve_r2995 g
  left join generator_drain_test_r2995 d on d.generator_tag = g.generator_tag and d.hospital_site = g.hospital_site
  order by risk_score desc
  limit 20;
end;$$;

revoke all on function r2995_reserve_summary_by_chain() from public, anon;
revoke all on function r2995_critical_low_sites() from public, anon;
revoke all on function r2995_drain_outcome_distribution() from public, anon;
revoke all on function r2995_defect_by_region() from public, anon;
revoke all on function r2995_fuel_type_mix() from public, anon;
revoke all on function r2995_nabh_witness_coverage() from public, anon;
revoke all on function r2995_cert_upload_backlog() from public, anon;
revoke all on function r2995_site_risk_score() from public, anon;

grant execute on function r2995_reserve_summary_by_chain() to authenticated;
grant execute on function r2995_critical_low_sites() to authenticated;
grant execute on function r2995_drain_outcome_distribution() to authenticated;
grant execute on function r2995_defect_by_region() to authenticated;
grant execute on function r2995_fuel_type_mix() to authenticated;
grant execute on function r2995_nabh_witness_coverage() to authenticated;
grant execute on function r2995_cert_upload_backlog() to authenticated;
grant execute on function r2995_site_risk_score() to authenticated;
