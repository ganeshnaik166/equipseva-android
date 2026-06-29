-- Round 3019: Hospital Chain Quarterly OT Surgeon-Headlight Battery Pack Reserve & Cycle Audit

create table if not exists hospital_chain_headlight_battery_reserve_r3019 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_name text not null,
  hospital_branch text not null,
  ot_room_code text not null,
  surgeon_name text not null,
  battery_pack_serial text not null,
  pack_model text not null check (pack_model in ('LiON-4400','LiON-6800','LiPo-3200','LiPo-5200','NiMH-2400')),
  capacity_mah int not null check (capacity_mah between 2000 and 8000),
  current_cycle_count int not null check (current_cycle_count between 0 and 1500),
  rated_max_cycles int not null check (rated_max_cycles between 300 and 2000),
  health_percent numeric(5,2) not null check (health_percent between 0 and 100),
  reserve_status text not null check (reserve_status in ('primary','reserve','retired','quarantined','in_repair')),
  last_full_charge_at timestamptz,
  last_audit_at date,
  next_audit_due date not null,
  quarter_label text not null check (quarter_label in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4')),
  flagged_for_replacement boolean not null default false
);

alter table hospital_chain_headlight_battery_reserve_r3019 enable row level security;
drop policy if exists hcbr_r3019_founder_all on hospital_chain_headlight_battery_reserve_r3019;
create policy hcbr_r3019_founder_all on hospital_chain_headlight_battery_reserve_r3019 for all to authenticated using (is_founder()) with check (is_founder());

create table if not exists hospital_chain_headlight_cycle_audit_events_r3019 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  battery_pack_serial text not null,
  chain_name text not null,
  audit_quarter text not null check (audit_quarter in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4')),
  event_type text not null check (event_type in ('cycle_logged','health_test','reserve_promoted','retired','quarantined','replaced','calibrated')),
  event_at timestamptz not null,
  cycles_added int not null default 0 check (cycles_added between 0 and 200),
  health_delta numeric(5,2) not null default 0 check (health_delta between -100 and 100),
  auditor_name text not null,
  notes text
);

alter table hospital_chain_headlight_cycle_audit_events_r3019 enable row level security;
drop policy if exists hccae_r3019_founder_all on hospital_chain_headlight_cycle_audit_events_r3019;
create policy hccae_r3019_founder_all on hospital_chain_headlight_cycle_audit_events_r3019 for all to authenticated using (is_founder()) with check (is_founder());

insert into hospital_chain_headlight_battery_reserve_r3019 (chain_name, hospital_branch, ot_room_code, surgeon_name, battery_pack_serial, pack_model, capacity_mah, current_cycle_count, rated_max_cycles, health_percent, reserve_status, last_full_charge_at, last_audit_at, next_audit_due, quarter_label, flagged_for_replacement) values
('Apollo','Hyderabad-Jubilee','OT-A1','Dr. Reddy','HL-PACK-0001','LiON-6800',6800,420,1500,92.50,'primary','2026-06-25 08:00'::timestamptz,'2026-06-15'::date,'2026-09-15'::date,'2026-Q2',false),
('Apollo','Hyderabad-Jubilee','OT-A2','Dr. Khan','HL-PACK-0002','LiON-6800',6800,1180,1500,71.20,'reserve','2026-06-20 09:00'::timestamptz,'2026-06-15'::date,'2026-09-15'::date,'2026-Q2',true),
('Apollo','Chennai-Greams','OT-B1','Dr. Iyer','HL-PACK-0003','LiON-4400',4400,260,1200,95.10,'primary','2026-06-26 07:30'::timestamptz,'2026-06-10'::date,'2026-09-10'::date,'2026-Q2',false),
('Apollo','Chennai-Greams','OT-B2','Dr. Menon','HL-PACK-0004','LiPo-5200',5200,805,1000,68.40,'reserve','2026-06-22 10:15'::timestamptz,'2026-06-12'::date,'2026-09-12'::date,'2026-Q2',true),
('Fortis','Bangalore-Bannerghatta','OT-C1','Dr. Rao','HL-PACK-0005','LiON-6800',6800,140,1500,98.20,'primary','2026-06-27 06:45'::timestamptz,'2026-06-18'::date,'2026-09-18'::date,'2026-Q2',false),
('Fortis','Bangalore-Bannerghatta','OT-C2','Dr. Shetty','HL-PACK-0006','LiPo-3200',3200,560,800,74.50,'reserve','2026-06-19 11:00'::timestamptz,'2026-06-14'::date,'2026-09-14'::date,'2026-Q2',false),
('Fortis','Mumbai-Mulund','OT-D1','Dr. Kapoor','HL-PACK-0007','LiON-6800',6800,1420,1500,55.80,'retired',null::timestamptz,'2026-06-08'::date,'2026-09-08'::date,'2026-Q2',true),
('Fortis','Mumbai-Mulund','OT-D2','Dr. Joshi','HL-PACK-0008','LiPo-5200',5200,310,1000,90.10,'primary','2026-06-28 08:20'::timestamptz,'2026-06-16'::date,'2026-09-16'::date,'2026-Q2',false),
('Manipal','Delhi-Dwarka','OT-E1','Dr. Singh','HL-PACK-0009','LiON-4400',4400,690,1200,78.30,'primary','2026-06-24 09:30'::timestamptz,'2026-06-11'::date,'2026-09-11'::date,'2026-Q2',false),
('Manipal','Delhi-Dwarka','OT-E2','Dr. Verma','HL-PACK-0010','NiMH-2400',2400,1050,1300,62.40,'reserve','2026-06-21 12:00'::timestamptz,'2026-06-13'::date,'2026-09-13'::date,'2026-Q2',true),
('Manipal','Pune-Baner','OT-F1','Dr. Deshmukh','HL-PACK-0011','LiON-6800',6800,90,1500,99.10,'primary','2026-06-28 07:00'::timestamptz,'2026-06-20'::date,'2026-09-20'::date,'2026-Q2',false),
('Manipal','Pune-Baner','OT-F2','Dr. Patil','HL-PACK-0012','LiPo-3200',3200,470,800,80.20,'reserve','2026-06-23 10:45'::timestamptz,'2026-06-17'::date,'2026-09-17'::date,'2026-Q2',false),
('Max','Delhi-Saket','OT-G1','Dr. Bhatia','HL-PACK-0013','LiON-6800',6800,350,1500,89.50,'primary','2026-06-26 09:00'::timestamptz,'2026-06-09'::date,'2026-09-09'::date,'2026-Q2',false),
('Max','Delhi-Saket','OT-G2','Dr. Sharma','HL-PACK-0014','LiPo-5200',5200,890,1000,63.70,'quarantined',null::timestamptz,'2026-06-07'::date,'2026-09-07'::date,'2026-Q2',true),
('Max','Gurgaon-Sector56','OT-H1','Dr. Aggarwal','HL-PACK-0015','LiON-4400',4400,210,1200,93.40,'primary','2026-06-27 08:30'::timestamptz,'2026-06-19'::date,'2026-09-19'::date,'2026-Q2',false),
('Narayana','Bangalore-Health-City','OT-I1','Dr. Shetty','HL-PACK-0016','LiON-6800',6800,580,1500,85.10,'reserve','2026-06-25 11:30'::timestamptz,'2026-06-21'::date,'2026-09-21'::date,'2026-Q2',false),
('Narayana','Bangalore-Health-City','OT-I2','Dr. Hegde','HL-PACK-0017','LiPo-3200',3200,720,800,58.30,'in_repair',null::timestamptz,'2026-06-05'::date,'2026-09-05'::date,'2026-Q2',true),
('Medanta','Gurgaon-Sector38','OT-J1','Dr. Trehan','HL-PACK-0018','LiON-6800',6800,180,1500,96.80,'primary','2026-06-28 06:30'::timestamptz,'2026-06-22'::date,'2026-09-22'::date,'2026-Q2',false),
('Medanta','Gurgaon-Sector38','OT-J2','Dr. Bansal','HL-PACK-0019','LiPo-5200',5200,640,1000,76.40,'reserve','2026-06-24 13:00'::timestamptz,'2026-06-18'::date,'2026-09-18'::date,'2026-Q2',false),
('AIIMS','Delhi-Ansari','OT-K1','Dr. Khanna','HL-PACK-0020','LiON-4400',4400,1100,1200,52.50,'retired',null::timestamptz,'2026-06-04'::date,'2026-09-04'::date,'2026-Q2',true);

insert into hospital_chain_headlight_cycle_audit_events_r3019 (battery_pack_serial, chain_name, audit_quarter, event_type, event_at, cycles_added, health_delta, auditor_name, notes) values
('HL-PACK-0001','Apollo','2026-Q2','cycle_logged','2026-06-15 09:00'::timestamptz,40,-1.20,'Auditor Rao','Q2 cycle log'),
('HL-PACK-0002','Apollo','2026-Q2','health_test','2026-06-15 10:00'::timestamptz,0,-3.50,'Auditor Rao','Reserve health degraded'),
('HL-PACK-0003','Apollo','2026-Q2','calibrated','2026-06-10 11:00'::timestamptz,0,2.10,'Auditor Iyer','Calibration done'),
('HL-PACK-0004','Apollo','2026-Q2','reserve_promoted','2026-06-12 14:00'::timestamptz,30,-2.40,'Auditor Iyer','Demoted from primary'),
('HL-PACK-0005','Fortis','2026-Q2','cycle_logged','2026-06-18 08:30'::timestamptz,20,-0.50,'Auditor Rao','Low cycles, healthy'),
('HL-PACK-0006','Fortis','2026-Q2','health_test','2026-06-14 09:45'::timestamptz,0,-4.20,'Auditor Shetty','Mid-cycle degradation'),
('HL-PACK-0007','Fortis','2026-Q2','retired','2026-06-08 15:00'::timestamptz,0,-15.40,'Auditor Kapoor','End of life'),
('HL-PACK-0008','Fortis','2026-Q2','cycle_logged','2026-06-16 10:00'::timestamptz,55,-1.80,'Auditor Joshi','Heavy use OT'),
('HL-PACK-0009','Manipal','2026-Q2','cycle_logged','2026-06-11 11:15'::timestamptz,70,-3.10,'Auditor Singh','Q2 logged'),
('HL-PACK-0010','Manipal','2026-Q2','health_test','2026-06-13 12:30'::timestamptz,0,-5.60,'Auditor Verma','NiMH aging fast'),
('HL-PACK-0011','Manipal','2026-Q2','calibrated','2026-06-20 09:00'::timestamptz,0,1.80,'Auditor Deshmukh','New pack calibration'),
('HL-PACK-0012','Manipal','2026-Q2','cycle_logged','2026-06-17 13:00'::timestamptz,45,-2.20,'Auditor Patil','Reserve in active use'),
('HL-PACK-0013','Max','2026-Q2','cycle_logged','2026-06-09 14:30'::timestamptz,35,-1.50,'Auditor Bhatia','Stable'),
('HL-PACK-0014','Max','2026-Q2','quarantined','2026-06-07 16:00'::timestamptz,0,-8.30,'Auditor Sharma','Bulge detected'),
('HL-PACK-0015','Max','2026-Q2','health_test','2026-06-19 10:30'::timestamptz,0,-0.80,'Auditor Aggarwal','Healthy'),
('HL-PACK-0016','Narayana','2026-Q2','reserve_promoted','2026-06-21 11:00'::timestamptz,25,-1.90,'Auditor Shetty','Moved to reserve'),
('HL-PACK-0017','Narayana','2026-Q2','quarantined','2026-06-05 12:00'::timestamptz,0,-7.40,'Auditor Hegde','Sent to repair'),
('HL-PACK-0018','Medanta','2026-Q2','calibrated','2026-06-22 08:15'::timestamptz,0,2.40,'Auditor Trehan','Fresh calibration'),
('HL-PACK-0019','Medanta','2026-Q2','cycle_logged','2026-06-18 14:00'::timestamptz,50,-2.80,'Auditor Bansal','Reserve usage rising'),
('HL-PACK-0020','AIIMS','2026-Q2','retired','2026-06-04 17:00'::timestamptz,0,-12.80,'Auditor Khanna','End of life retire');

create or replace function founder_r3019_reserve_overview()
returns table(chain_name text, total_packs int, primary_packs int, reserve_packs int, retired_packs int, flagged_packs int, avg_health numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select b.chain_name,
    count(*)::int as total_packs,
    (count(*) filter (where b.reserve_status='primary'))::int as primary_packs,
    (count(*) filter (where b.reserve_status='reserve'))::int as reserve_packs,
    (count(*) filter (where b.reserve_status='retired'))::int as retired_packs,
    (count(*) filter (where b.flagged_for_replacement))::int as flagged_packs,
    round(avg(b.health_percent)::numeric,2) as avg_health
  from hospital_chain_headlight_battery_reserve_r3019 b
  group by b.chain_name
  order by b.chain_name;
end; $$;
revoke all on function founder_r3019_reserve_overview() from public, anon;
grant execute on function founder_r3019_reserve_overview() to authenticated;

create or replace function founder_r3019_cycle_consumption()
returns table(chain_name text, pack_serial text, cycles_used int, rated_max int, cycle_pct numeric, health_percent numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select b.chain_name, b.battery_pack_serial, b.current_cycle_count, b.rated_max_cycles,
    round((b.current_cycle_count::numeric / nullif(b.rated_max_cycles,0)::numeric) * 100, 2) as cycle_pct,
    b.health_percent
  from hospital_chain_headlight_battery_reserve_r3019 b
  order by cycle_pct desc nulls last;
end; $$;
revoke all on function founder_r3019_cycle_consumption() from public, anon;
grant execute on function founder_r3019_cycle_consumption() to authenticated;

create or replace function founder_r3019_replacement_queue()
returns table(chain_name text, branch text, pack_serial text, surgeon_name text, health_percent numeric, current_cycle_count int, reserve_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select b.chain_name, b.hospital_branch, b.battery_pack_serial, b.surgeon_name, b.health_percent, b.current_cycle_count, b.reserve_status
  from hospital_chain_headlight_battery_reserve_r3019 b
  where b.flagged_for_replacement
  order by b.health_percent asc;
end; $$;
revoke all on function founder_r3019_replacement_queue() from public, anon;
grant execute on function founder_r3019_replacement_queue() to authenticated;

create or replace function founder_r3019_quarter_event_breakdown()
returns table(audit_quarter text, event_type text, event_count int, total_cycles int, avg_health_delta numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select e.audit_quarter, e.event_type,
    count(*)::int as event_count,
    sum(e.cycles_added)::int as total_cycles,
    round(avg(e.health_delta)::numeric,2) as avg_health_delta
  from hospital_chain_headlight_cycle_audit_events_r3019 e
  group by e.audit_quarter, e.event_type
  order by e.audit_quarter, e.event_type;
end; $$;
revoke all on function founder_r3019_quarter_event_breakdown() from public, anon;
grant execute on function founder_r3019_quarter_event_breakdown() to authenticated;

create or replace function founder_r3019_pack_model_distribution()
returns table(pack_model text, pack_count int, avg_cycles numeric, avg_health numeric, retired_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select b.pack_model,
    count(*)::int as pack_count,
    round(avg(b.current_cycle_count)::numeric,2) as avg_cycles,
    round(avg(b.health_percent)::numeric,2) as avg_health,
    (count(*) filter (where b.reserve_status='retired'))::int as retired_count
  from hospital_chain_headlight_battery_reserve_r3019 b
  group by b.pack_model
  order by pack_count desc;
end; $$;
revoke all on function founder_r3019_pack_model_distribution() from public, anon;
grant execute on function founder_r3019_pack_model_distribution() to authenticated;

create or replace function founder_r3019_upcoming_audits()
returns table(chain_name text, branch text, pack_serial text, next_audit_due date, days_until int, reserve_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select b.chain_name, b.hospital_branch, b.battery_pack_serial, b.next_audit_due,
    (b.next_audit_due - current_date)::int as days_until, b.reserve_status
  from hospital_chain_headlight_battery_reserve_r3019 b
  order by b.next_audit_due asc;
end; $$;
revoke all on function founder_r3019_upcoming_audits() from public, anon;
grant execute on function founder_r3019_upcoming_audits() to authenticated;

create or replace function founder_r3019_recent_audit_events()
returns table(event_at timestamptz, chain_name text, pack_serial text, event_type text, cycles_added int, health_delta numeric, auditor_name text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select e.event_at, e.chain_name, e.battery_pack_serial, e.event_type, e.cycles_added, e.health_delta, e.auditor_name
  from hospital_chain_headlight_cycle_audit_events_r3019 e
  order by e.event_at desc
  limit 50;
end; $$;
revoke all on function founder_r3019_recent_audit_events() from public, anon;
grant execute on function founder_r3019_recent_audit_events() to authenticated;
