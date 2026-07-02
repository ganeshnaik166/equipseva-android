-- Round r3078 — Engineer Monthly Customer Site CT Scanner X-Ray Tube Burn-In Cycle & Heat Audit

create table if not exists ct_tube_burnin_cycles_r3078 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  customer_site text not null,
  scanner_model text not null,
  tube_serial text not null,
  cycle_month date not null,
  engineer_name text not null,
  cycle_status text not null check (cycle_status in ('scheduled','in_progress','completed','aborted','deferred')),
  burnin_minutes int not null check (burnin_minutes between 0 and 240),
  peak_anode_heat_kHU numeric(8,2) not null check (peak_anode_heat_kHU >= 0),
  cooling_time_minutes int not null check (cooling_time_minutes >= 0),
  arc_events int not null default 0 check (arc_events >= 0),
  pass_fail text not null check (pass_fail in ('pass','marginal','fail','pending')),
  next_cycle_due date,
  notes text
);

create table if not exists ct_tube_heat_audits_r3078 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  cycle_id uuid references ct_tube_burnin_cycles_r3078(id) on delete cascade,
  audit_timestamp timestamptz not null,
  anode_temp_celsius numeric(6,2) not null,
  oil_temp_celsius numeric(6,2) not null,
  housing_temp_celsius numeric(6,2) not null,
  heat_units_used_kHU numeric(8,2) not null check (heat_units_used_kHU >= 0),
  cooling_curve_ok boolean not null default true,
  thermal_alert_level text not null check (thermal_alert_level in ('none','watch','warn','critical')),
  remediation text
);

alter table ct_tube_burnin_cycles_r3078 enable row level security;
alter table ct_tube_heat_audits_r3078 enable row level security;

drop policy if exists ct_burnin_founder_r3078 on ct_tube_burnin_cycles_r3078;
create policy ct_burnin_founder_r3078 on ct_tube_burnin_cycles_r3078 for select to authenticated using (is_founder());

drop policy if exists ct_heat_founder_r3078 on ct_tube_heat_audits_r3078;
create policy ct_heat_founder_r3078 on ct_tube_heat_audits_r3078 for select to authenticated using (is_founder());

insert into ct_tube_burnin_cycles_r3078 (customer_site, scanner_model, tube_serial, cycle_month, engineer_name, cycle_status, burnin_minutes, peak_anode_heat_kHU, cooling_time_minutes, arc_events, pass_fail, next_cycle_due, notes) values
('Apollo Jubilee Hills','GE Revolution EVO','MX240-A8821','2026-06-01'::date,'Ravi Kumar','completed',45,5800.00,18,0,'pass','2026-07-01'::date,'Clean cycle, no anomalies'),
('KIMS Secunderabad','Siemens Somatom go.Top','SOM-7712','2026-06-02'::date,'Pradeep N','completed',60,6200.50,22,1,'pass','2026-07-02'::date,'One micro-arc, within tolerance'),
('Yashoda Somajiguda','Philips Incisive CT','PH-INC-3344','2026-06-03'::date,'Anil Reddy','completed',50,5950.75,20,0,'pass','2026-07-03'::date,null),
('Continental Gachibowli','Canon Aquilion Lightning','CAN-AQL-9921','2026-06-04'::date,'Sasi M','completed',55,6050.00,25,2,'marginal','2026-07-04'::date,'Marginal arcs, monitor closely'),
('Medicover HiTech','GE Optima CT660','GE-OPT-5512','2026-06-05'::date,'Hari V','completed',45,5700.25,17,0,'pass','2026-07-05'::date,null),
('AIG Hospitals','Siemens Somatom Drive','SOM-DR-8801','2026-06-06'::date,'Krishna T','aborted',15,2100.00,8,5,'fail','2026-06-13'::date,'Excessive arcs aborted cycle'),
('Care Banjara','GE BrightSpeed Elite','GE-BSE-2244','2026-06-07'::date,'Ravi Kumar','completed',60,6400.00,24,1,'pass','2026-07-07'::date,null),
('Sunshine Paradise','Philips Brilliance 64','PH-BR64-1188','2026-06-08'::date,'Pradeep N','completed',50,5850.50,19,0,'pass','2026-07-08'::date,null),
('Star Banjara','Siemens Somatom Definition','SOM-DEF-7799','2026-06-09'::date,'Anil Reddy','in_progress',30,3900.00,0,1,'pending',null,'Cycle running at audit time'),
('Rainbow Vikrampuri','GE Revolution Frontier','GE-RF-6633','2026-06-10'::date,'Sasi M','completed',45,5750.00,18,0,'pass','2026-07-10'::date,null),
('Citizens Specialty','Canon Aquilion Prime','CAN-AP-4477','2026-06-11'::date,'Hari V','deferred',0,0.00,0,0,'pending','2026-06-18'::date,'Customer requested reschedule'),
('Asian Institute Neuro','Siemens Somatom Force','SOM-FORCE-9988','2026-06-12'::date,'Krishna T','completed',75,7800.00,32,3,'marginal','2026-07-12'::date,'High-end tube, marginal pass'),
('Olive Hospital','GE LightSpeed VCT','GE-LV-1122','2026-06-13'::date,'Ravi Kumar','completed',55,6100.00,22,1,'pass','2026-07-13'::date,null),
('Vasavi Hospital','Philips Ingenuity Core','PH-IC-3355','2026-06-14'::date,'Pradeep N','completed',50,5900.00,20,0,'pass','2026-07-14'::date,null),
('Mythri Hospitals','Siemens Somatom Emotion','SOM-EM-7766','2026-06-15'::date,'Anil Reddy','completed',45,5650.50,17,0,'pass','2026-07-15'::date,null),
('Renova Soumya','Canon Aquilion ONE','CAN-AONE-8844','2026-06-16'::date,'Sasi M','aborted',20,2500.00,10,4,'fail','2026-06-23'::date,'Tube failing burn-in, RMA pending'),
('PACE Hospitals','GE Optima CT540','GE-OPT540-2211','2026-06-17'::date,'Hari V','completed',60,6300.00,23,1,'pass','2026-07-17'::date,null),
('SLG Hospitals','Philips Access CT','PH-ACC-5599','2026-06-18'::date,'Krishna T','completed',45,5550.25,18,0,'pass','2026-07-18'::date,null),
('Maxcure Hospitals','Siemens Somatom Perspective','SOM-PER-3322','2026-06-19'::date,'Ravi Kumar','completed',50,5850.00,21,1,'pass','2026-07-19'::date,null),
('Pranaam Hospitals','GE Revolution CT','GE-RCT-9911','2026-06-20'::date,'Pradeep N','scheduled',0,0.00,0,0,'pending','2026-06-22'::date,'Scheduled for next slot');

insert into ct_tube_heat_audits_r3078 (cycle_id, audit_timestamp, anode_temp_celsius, oil_temp_celsius, housing_temp_celsius, heat_units_used_kHU, cooling_curve_ok, thermal_alert_level, remediation) values
(null,'2026-06-01 10:30:00+05:30'::timestamptz,1850.00,68.50,52.30,5800.00,true,'none',null),
(null,'2026-06-02 11:00:00+05:30'::timestamptz,1920.50,72.00,55.80,6200.50,true,'watch','Monitor oil temp'),
(null,'2026-06-03 09:45:00+05:30'::timestamptz,1880.25,70.10,53.40,5950.75,true,'none',null),
(null,'2026-06-04 14:15:00+05:30'::timestamptz,1955.00,74.50,57.20,6050.00,false,'warn','Cooling curve flattened — schedule chiller service'),
(null,'2026-06-05 08:30:00+05:30'::timestamptz,1820.50,67.00,50.90,5700.25,true,'none',null),
(null,'2026-06-06 12:00:00+05:30'::timestamptz,2150.00,82.00,68.40,2100.00,false,'critical','Aborted — RMA tube, escalate to vendor'),
(null,'2026-06-07 10:00:00+05:30'::timestamptz,1965.50,73.20,56.10,6400.00,true,'watch','Within spec but trending up'),
(null,'2026-06-08 11:30:00+05:30'::timestamptz,1875.00,69.50,52.80,5850.50,true,'none',null),
(null,'2026-06-09 13:45:00+05:30'::timestamptz,1300.00,55.00,42.00,3900.00,true,'none','Mid-cycle audit'),
(null,'2026-06-10 09:15:00+05:30'::timestamptz,1840.75,68.00,51.40,5750.00,true,'none',null),
(null,'2026-06-12 15:00:00+05:30'::timestamptz,2080.00,78.50,62.50,7800.00,true,'warn','High-end tube, near thermal ceiling'),
(null,'2026-06-13 10:45:00+05:30'::timestamptz,1890.00,70.50,53.90,6100.00,true,'none',null),
(null,'2026-06-14 11:00:00+05:30'::timestamptz,1870.25,69.80,52.60,5900.00,true,'none',null),
(null,'2026-06-15 09:30:00+05:30'::timestamptz,1815.00,66.50,50.20,5650.50,true,'none',null),
(null,'2026-06-16 14:30:00+05:30'::timestamptz,2200.00,85.00,72.00,2500.00,false,'critical','Tube housing overheated — RMA initiated'),
(null,'2026-06-17 10:15:00+05:30'::timestamptz,1925.00,71.80,54.90,6300.00,true,'watch',null),
(null,'2026-06-18 11:45:00+05:30'::timestamptz,1795.50,65.00,49.50,5550.25,true,'none',null),
(null,'2026-06-19 13:00:00+05:30'::timestamptz,1860.00,69.20,52.10,5850.00,true,'none',null);

create or replace function r3078_cycle_status_summary()
returns table(cycle_status text, n int, avg_minutes numeric, avg_peak_heat_kHU numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.cycle_status, count(*)::int,
           round(avg(c.burnin_minutes)::numeric,1),
           round(avg(c.peak_anode_heat_kHU)::numeric,1)
    from ct_tube_burnin_cycles_r3078 c
    group by c.cycle_status
    order by count(*) desc;
end; $$;

create or replace function r3078_pass_fail_breakdown()
returns table(pass_fail text, n int, sites_affected int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.pass_fail, count(*)::int, count(distinct c.customer_site)::int
    from ct_tube_burnin_cycles_r3078 c
    group by c.pass_fail
    order by count(*) desc;
end; $$;

create or replace function r3078_site_performance()
returns table(customer_site text, cycles int, completed int, failed int, avg_arcs numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.customer_site,
           count(*)::int,
           (count(*) filter (where c.cycle_status = 'completed'))::int,
           (count(*) filter (where c.pass_fail = 'fail'))::int,
           round(avg(c.arc_events)::numeric,2)
    from ct_tube_burnin_cycles_r3078 c
    group by c.customer_site
    order by count(*) desc;
end; $$;

create or replace function r3078_engineer_workload()
returns table(engineer_name text, cycles int, pass_rate_pct numeric, avg_cooling_min numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.engineer_name,
           count(*)::int,
           round((count(*) filter (where c.pass_fail = 'pass'))::numeric * 100.0 / nullif(count(*),0), 1),
           round(avg(c.cooling_time_minutes)::numeric,1)
    from ct_tube_burnin_cycles_r3078 c
    group by c.engineer_name
    order by count(*) desc;
end; $$;

create or replace function r3078_thermal_alerts()
returns table(thermal_alert_level text, n int, avg_anode_temp numeric, avg_housing_temp numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.thermal_alert_level, count(*)::int,
           round(avg(h.anode_temp_celsius)::numeric,1),
           round(avg(h.housing_temp_celsius)::numeric,1)
    from ct_tube_heat_audits_r3078 h
    group by h.thermal_alert_level
    order by count(*) desc;
end; $$;

create or replace function r3078_scanner_model_health()
returns table(scanner_model text, cycles int, avg_peak_heat numeric, fail_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select c.scanner_model, count(*)::int,
           round(avg(c.peak_anode_heat_kHU)::numeric,1),
           (count(*) filter (where c.pass_fail = 'fail'))::int
    from ct_tube_burnin_cycles_r3078 c
    group by c.scanner_model
    order by count(*) desc;
end; $$;

create or replace function r3078_cooling_curve_health()
returns table(cooling_curve_ok boolean, n int, avg_oil_temp numeric, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select h.cooling_curve_ok, count(*)::int,
           round(avg(h.oil_temp_celsius)::numeric,1),
           (count(*) filter (where h.thermal_alert_level = 'critical'))::int
    from ct_tube_heat_audits_r3078 h
    group by h.cooling_curve_ok
    order by count(*) desc;
end; $$;

revoke all on function r3078_cycle_status_summary() from public, anon;
revoke all on function r3078_pass_fail_breakdown() from public, anon;
revoke all on function r3078_site_performance() from public, anon;
revoke all on function r3078_engineer_workload() from public, anon;
revoke all on function r3078_thermal_alerts() from public, anon;
revoke all on function r3078_scanner_model_health() from public, anon;
revoke all on function r3078_cooling_curve_health() from public, anon;

grant execute on function r3078_cycle_status_summary() to authenticated;
grant execute on function r3078_pass_fail_breakdown() to authenticated;
grant execute on function r3078_site_performance() to authenticated;
grant execute on function r3078_engineer_workload() to authenticated;
grant execute on function r3078_thermal_alerts() to authenticated;
grant execute on function r3078_scanner_model_health() to authenticated;
grant execute on function r3078_cooling_curve_health() to authenticated;
