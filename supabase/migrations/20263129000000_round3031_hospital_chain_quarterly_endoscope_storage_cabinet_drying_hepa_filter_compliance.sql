-- Round 3031 — Hospital Chain Quarterly Endoscope Storage-Cabinet Drying & HEPA Filter Compliance

create table if not exists endoscope_drying_cabinets_r3031 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_name text not null,
  hospital_site text not null,
  cabinet_asset_tag text not null,
  cabinet_model text not null,
  scope_capacity int not null check (scope_capacity between 2 and 24),
  hepa_filter_serial text,
  hepa_install_date date not null,
  hepa_replacement_due date not null,
  last_drying_audit_at timestamptz,
  drying_airflow_lpm numeric(6,2) check (drying_airflow_lpm is null or (drying_airflow_lpm between 0 and 200)),
  particle_count_0_5um int check (particle_count_0_5um is null or particle_count_0_5um between 0 and 1000000),
  compliance_status text not null check (compliance_status in ('compliant','watch','breach','overdue','quarantined')),
  quarter_label text not null check (quarter_label in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026')),
  storage_temperature_c numeric(4,1) check (storage_temperature_c is null or (storage_temperature_c between 10 and 35)),
  storage_humidity_pct numeric(4,1) check (storage_humidity_pct is null or (storage_humidity_pct between 0 and 100))
);

create table if not exists endoscope_drying_findings_r3031 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  cabinet_id uuid references endoscope_drying_cabinets_r3031(id) on delete cascade,
  finding_code text not null,
  severity text not null check (severity in ('info','low','medium','high','critical')),
  finding_category text not null check (finding_category in ('hepa_overdue','drying_failure','humidity_breach','airflow_low','particle_high','scope_contamination','door_seal','log_gap')),
  observation text not null,
  remediation_due date,
  closed_at timestamptz,
  closure_status text not null check (closure_status in ('open','in_progress','closed','escalated','accepted_risk')),
  fine_risk_rupees int check (fine_risk_rupees is null or fine_risk_rupees between 0 and 10000000)
);

alter table endoscope_drying_cabinets_r3031 enable row level security;
alter table endoscope_drying_findings_r3031 enable row level security;

drop policy if exists r3031_cab_founder_all on endoscope_drying_cabinets_r3031;
create policy r3031_cab_founder_all on endoscope_drying_cabinets_r3031 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists r3031_find_founder_all on endoscope_drying_findings_r3031;
create policy r3031_find_founder_all on endoscope_drying_findings_r3031 for all to authenticated using (is_founder()) with check (is_founder());

-- Seed cabinets (16 rows)
insert into endoscope_drying_cabinets_r3031 (chain_name, hospital_site, cabinet_asset_tag, cabinet_model, scope_capacity, hepa_filter_serial, hepa_install_date, hepa_replacement_due, last_drying_audit_at, drying_airflow_lpm, particle_count_0_5um, compliance_status, quarter_label, storage_temperature_c, storage_humidity_pct) values
('Apollo','Jubilee Hills','CAB-AP-JUB-01','Wassenburg DRY350',8,'HEPA-A1-7781','2025-09-12','2026-09-12','2026-06-18 09:00+00',92.50,1820,'compliant','Q2-2026',21.5,38.0),
('Apollo','Hyderguda','CAB-AP-HYD-02','Wassenburg DRY350',8,'HEPA-A2-7782','2025-04-02','2026-04-02','2026-06-15 10:00+00',61.20,8400,'breach','Q2-2026',24.0,52.0),
('Yashoda','Somajiguda','CAB-YS-SOM-01','Olympus EDC-1000',12,'HEPA-Y1-3301','2025-11-20','2026-11-20','2026-06-19 08:30+00',104.00,1100,'compliant','Q2-2026',20.5,35.5),
('Yashoda','Secunderabad','CAB-YS-SEC-02','Olympus EDC-1000',12,'HEPA-Y2-3302','2024-12-10','2025-12-10','2026-05-30 11:00+00',55.00,12000,'overdue','Q2-2026',26.5,58.0),
('Continental','Gachibowli','CAB-CT-GAC-01','SciCan HSC-8',10,'HEPA-C1-5511','2025-08-05','2026-08-05','2026-06-20 12:00+00',88.75,2100,'compliant','Q2-2026',22.0,40.0),
('Care','Banjara Hills','CAB-CR-BNJ-01','SciCan HSC-8',10,'HEPA-CR-5512','2025-01-15','2026-01-15','2026-06-10 09:15+00',73.40,4800,'watch','Q2-2026',23.5,46.0),
('KIMS','Kondapur','CAB-KM-KON-01','Wassenburg DRY350',8,'HEPA-K1-2201','2025-07-22','2026-07-22','2026-06-17 14:00+00',95.10,1650,'compliant','Q2-2026',21.0,37.0),
('KIMS','Sunshine','CAB-KM-SUN-02','Olympus EDC-1000',12,'HEPA-K2-2202','2024-08-30','2025-08-30','2026-04-22 10:45+00',42.00,18500,'quarantined','Q2-2026',28.0,64.5),
('Manipal','Tarnaka','CAB-MN-TRN-01','SciCan HSC-8',10,'HEPA-M1-9911','2025-10-08','2026-10-08','2026-06-21 07:30+00',91.20,1900,'compliant','Q2-2026',21.5,38.5),
('Rainbow','Madhapur','CAB-RB-MAD-01','Wassenburg DRY350',6,'HEPA-R1-4401','2025-06-14','2026-06-14','2026-06-19 11:30+00',69.50,5200,'watch','Q2-2026',23.0,44.0),
('Star','LB Nagar','CAB-ST-LBN-01','Olympus EDC-1000',12,'HEPA-S1-8811','2025-03-25','2026-03-25','2026-05-28 09:00+00',58.00,9600,'breach','Q2-2026',25.5,55.0),
('Sunshine','Paradise','CAB-SS-PAR-01','SciCan HSC-8',10,'HEPA-SS-7711','2025-12-01','2026-12-01','2026-06-20 13:00+00',97.80,1400,'compliant','Q2-2026',20.0,36.0),
('Citizens','Nallagandla','CAB-CZ-NAL-01','Wassenburg DRY350',8,null,'2025-05-10','2026-05-10',null,null,null,'overdue','Q2-2026',null,null),
('AIG','Gachibowli','CAB-AIG-GAC-01','Olympus EDC-1000',12,'HEPA-AIG-6601','2025-09-30','2026-09-30','2026-06-21 15:00+00',103.50,1250,'compliant','Q2-2026',20.5,35.0),
('Asian','Kukatpally','CAB-AS-KKP-01','SciCan HSC-8',10,'HEPA-AS-3399','2025-02-18','2026-02-18','2026-06-12 10:00+00',64.00,7200,'breach','Q2-2026',24.5,50.5),
('Maxivision','Banjara','CAB-MX-BNJ-01','Wassenburg DRY350',6,'HEPA-MX-1199','2025-11-05','2026-11-05','2026-06-19 12:45+00',89.00,2400,'watch','Q2-2026',22.5,41.0);

-- Seed findings (18 rows)
insert into endoscope_drying_findings_r3031 (cabinet_id, finding_code, severity, finding_category, observation, remediation_due, closed_at, closure_status, fine_risk_rupees) values
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-AP-HYD-02'),'F-HEPA-001','high','airflow_low','Airflow 61 LPM below 80 LPM threshold','2026-06-30',null,'open',250000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-AP-HYD-02'),'F-PART-002','high','particle_high','Particle count 8400 exceeds Class 7 limit','2026-06-28',null,'in_progress',180000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-YS-SEC-02'),'F-HEPA-003','critical','hepa_overdue','HEPA replacement overdue by 192 days','2026-06-25',null,'escalated',500000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-YS-SEC-02'),'F-HUM-004','high','humidity_breach','Humidity 58% exceeds 50% ceiling','2026-07-05',null,'open',120000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-CR-BNJ-01'),'F-LOG-005','medium','log_gap','3 missing daily drying logs in May','2026-07-10','2026-06-18 10:00+00','closed',40000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-KM-SUN-02'),'F-CONT-006','critical','scope_contamination','2 colonoscopes failed ATP swab post-storage','2026-06-22',null,'escalated',750000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-KM-SUN-02'),'F-HEPA-007','critical','hepa_overdue','HEPA overdue 295 days','2026-06-22',null,'escalated',500000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-KM-SUN-02'),'F-DOOR-008','high','door_seal','Door gasket compromised on bay 4','2026-07-01',null,'in_progress',75000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-RB-MAD-01'),'F-AIR-009','medium','airflow_low','Airflow 69 LPM trending downward','2026-07-15',null,'open',50000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-ST-LBN-01'),'F-PART-010','high','particle_high','Particle 9600 in clean bay','2026-06-29',null,'open',150000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-ST-LBN-01'),'F-DRY-011','high','drying_failure','3 scopes wet at 4-hour check','2026-06-26',null,'in_progress',200000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-CZ-NAL-01'),'F-HEPA-012','critical','hepa_overdue','HEPA serial not recorded; replacement overdue','2026-06-24',null,'escalated',600000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-CZ-NAL-01'),'F-LOG-013','high','log_gap','Quarterly audit never performed','2026-06-30',null,'open',300000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-AS-KKP-01'),'F-HUM-014','medium','humidity_breach','Humidity 50.5% just over ceiling','2026-07-08',null,'in_progress',60000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-AS-KKP-01'),'F-AIR-015','medium','airflow_low','Airflow 64 LPM','2026-07-12',null,'open',45000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-MX-BNJ-01'),'F-PART-016','low','particle_high','Particle 2400 marginally over','2026-07-20','2026-06-20 09:00+00','closed',15000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-AP-JUB-01'),'F-INF-017','info','log_gap','One log entry late by 30 min','2026-07-25','2026-06-19 11:00+00','closed',5000),
((select id from endoscope_drying_cabinets_r3031 where cabinet_asset_tag='CAB-YS-SOM-01'),'F-INF-018','info','door_seal','Visual inspection scheduled','2026-07-30',null,'accepted_risk',null);

-- RPC 1: chain-level rollup
create or replace function rpc_r3031_chain_rollup()
returns table (chain_name text, cabinets int, compliant int, breach int, overdue int, quarantined int, avg_airflow numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select c.chain_name,
           count(*)::int,
           (count(*) filter (where c.compliance_status='compliant'))::int,
           (count(*) filter (where c.compliance_status='breach'))::int,
           (count(*) filter (where c.compliance_status='overdue'))::int,
           (count(*) filter (where c.compliance_status='quarantined'))::int,
           round(avg(c.drying_airflow_lpm),2)
    from endoscope_drying_cabinets_r3031 c
    group by c.chain_name
    order by c.chain_name;
end $$;

-- RPC 2: HEPA replacement schedule
create or replace function rpc_r3031_hepa_schedule()
returns table (chain_name text, hospital_site text, cabinet_asset_tag text, hepa_filter_serial text, hepa_replacement_due date, days_to_due int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select c.chain_name, c.hospital_site, c.cabinet_asset_tag, c.hepa_filter_serial, c.hepa_replacement_due,
           (c.hepa_replacement_due - current_date)::int
    from endoscope_drying_cabinets_r3031 c
    order by c.hepa_replacement_due asc;
end $$;

-- RPC 3: open findings by severity
create or replace function rpc_r3031_open_findings()
returns table (severity text, open_count int, total_fine_risk int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select f.severity,
           (count(*) filter (where f.closure_status in ('open','in_progress','escalated')))::int,
           coalesce(sum(f.fine_risk_rupees) filter (where f.closure_status in ('open','in_progress','escalated')),0)::int
    from endoscope_drying_findings_r3031 f
    group by f.severity
    order by case f.severity when 'critical' then 1 when 'high' then 2 when 'medium' then 3 when 'low' then 4 else 5 end;
end $$;

-- RPC 4: category breakdown
create or replace function rpc_r3031_category_breakdown()
returns table (finding_category text, total int, open_int int, closed_int int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select f.finding_category,
           count(*)::int,
           (count(*) filter (where f.closure_status in ('open','in_progress','escalated')))::int,
           (count(*) filter (where f.closure_status = 'closed'))::int
    from endoscope_drying_findings_r3031 f
    group by f.finding_category
    order by count(*) desc;
end $$;

-- RPC 5: airflow watchlist
create or replace function rpc_r3031_airflow_watchlist()
returns table (cabinet_asset_tag text, chain_name text, drying_airflow_lpm numeric, particle_count_0_5um int, compliance_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select c.cabinet_asset_tag, c.chain_name, c.drying_airflow_lpm, c.particle_count_0_5um, c.compliance_status
    from endoscope_drying_cabinets_r3031 c
    where c.drying_airflow_lpm is null or c.drying_airflow_lpm < 80
    order by c.drying_airflow_lpm asc nulls first;
end $$;

-- RPC 6: quarter compliance %
create or replace function rpc_r3031_quarter_compliance()
returns table (quarter_label text, total int, compliant int, compliance_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select c.quarter_label,
           count(*)::int,
           (count(*) filter (where c.compliance_status='compliant'))::int,
           round(100.0 * (count(*) filter (where c.compliance_status='compliant'))::numeric / nullif(count(*),0), 1)
    from endoscope_drying_cabinets_r3031 c
    group by c.quarter_label
    order by c.quarter_label;
end $$;

-- RPC 7: top fine-risk findings
create or replace function rpc_r3031_top_fine_risk()
returns table (finding_code text, severity text, finding_category text, observation text, fine_risk_rupees int, closure_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select f.finding_code, f.severity, f.finding_category, f.observation, f.fine_risk_rupees, f.closure_status
    from endoscope_drying_findings_r3031 f
    where f.fine_risk_rupees is not null
    order by f.fine_risk_rupees desc
    limit 10;
end $$;

-- RPC 8: escalated count
create or replace function rpc_r3031_escalated_summary()
returns table (chain_name text, escalated_findings int, total_fine_risk int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
    select c.chain_name,
           (count(*) filter (where f.closure_status='escalated'))::int,
           coalesce(sum(f.fine_risk_rupees) filter (where f.closure_status='escalated'),0)::int
    from endoscope_drying_cabinets_r3031 c
    left join endoscope_drying_findings_r3031 f on f.cabinet_id = c.id
    group by c.chain_name
    order by (count(*) filter (where f.closure_status='escalated'))::int desc;
end $$;

revoke all on function rpc_r3031_chain_rollup() from public, anon;
revoke all on function rpc_r3031_hepa_schedule() from public, anon;
revoke all on function rpc_r3031_open_findings() from public, anon;
revoke all on function rpc_r3031_category_breakdown() from public, anon;
revoke all on function rpc_r3031_airflow_watchlist() from public, anon;
revoke all on function rpc_r3031_quarter_compliance() from public, anon;
revoke all on function rpc_r3031_top_fine_risk() from public, anon;
revoke all on function rpc_r3031_escalated_summary() from public, anon;

grant execute on function rpc_r3031_chain_rollup() to authenticated;
grant execute on function rpc_r3031_hepa_schedule() to authenticated;
grant execute on function rpc_r3031_open_findings() to authenticated;
grant execute on function rpc_r3031_category_breakdown() to authenticated;
grant execute on function rpc_r3031_airflow_watchlist() to authenticated;
grant execute on function rpc_r3031_quarter_compliance() to authenticated;
grant execute on function rpc_r3031_top_fine_risk() to authenticated;
grant execute on function rpc_r3031_escalated_summary() to authenticated;
