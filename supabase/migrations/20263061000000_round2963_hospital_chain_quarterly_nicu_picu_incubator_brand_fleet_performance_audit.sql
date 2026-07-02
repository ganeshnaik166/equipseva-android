-- Round r2963 — Hospital Chain Quarterly NICU/PICU Incubator-Brand Fleet-Performance Audit
-- 2 tables, 7 RPCs, founder-gated

create table if not exists incubator_brand_fleet_units_r2963 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_site text not null,
  ward_type text not null check (ward_type in ('NICU','PICU','NICU+PICU','Step-down NICU')),
  brand text not null check (brand in ('GE Giraffe','Drager Caleo','Atom Dual','Phoenix Phototherapy','Fanem','Natus Neoblue','Ibis Medical')),
  model_code text not null,
  unit_serial text not null,
  installed_on date not null,
  uptime_pct numeric(5,2) not null check (uptime_pct between 0 and 100),
  mttr_hours numeric(6,2) not null check (mttr_hours >= 0),
  mtbf_days numeric(6,2) not null check (mtbf_days >= 0),
  incidents_q int not null default 0 check (incidents_q >= 0),
  fleet_status text not null check (fleet_status in ('green','amber','red','retired')),
  created_at timestamptz not null default now()
);

alter table incubator_brand_fleet_units_r2963 enable row level security;
revoke all on incubator_brand_fleet_units_r2963 from public, anon;
grant select on incubator_brand_fleet_units_r2963 to authenticated;
drop policy if exists fleet_units_r2963_founder on incubator_brand_fleet_units_r2963;
create policy fleet_units_r2963_founder on incubator_brand_fleet_units_r2963 to authenticated using (is_founder());

create table if not exists incubator_brand_audit_findings_r2963 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  brand text not null,
  finding_quarter text not null check (finding_quarter in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4')),
  finding_category text not null check (finding_category in ('safety','reliability','calibration','spares','warranty','training','recall')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  units_affected int not null default 0 check (units_affected >= 0),
  cost_impact_rupees numeric(14,2) not null default 0,
  remediation_status text not null check (remediation_status in ('open','in_progress','resolved','escalated')),
  created_at timestamptz not null default now()
);

alter table incubator_brand_audit_findings_r2963 enable row level security;
revoke all on incubator_brand_audit_findings_r2963 from public, anon;
grant select on incubator_brand_audit_findings_r2963 to authenticated;
drop policy if exists findings_r2963_founder on incubator_brand_audit_findings_r2963;
create policy findings_r2963_founder on incubator_brand_audit_findings_r2963 to authenticated using (is_founder());

-- Seed fleet units (20 rows)
insert into incubator_brand_fleet_units_r2963 (chain_name, hospital_site, ward_type, brand, model_code, unit_serial, installed_on, uptime_pct, mttr_hours, mtbf_days, incidents_q, fleet_status) values
('Rainbow Children','Hyderabad Banjara','NICU','GE Giraffe','OmniBed-G7','GEH-2201','2024-03-12'::date, 99.40, 3.2, 88.5, 1, 'green'),
('Rainbow Children','Hyderabad Banjara','PICU','Drager Caleo','C500','DRG-3145','2024-05-22'::date, 98.10, 5.8, 64.0, 2, 'amber'),
('Rainbow Children','Bangalore Marathahalli','NICU','GE Giraffe','OmniBed-G7','GEH-2289','2024-04-18'::date, 99.70, 2.1, 102.3, 0, 'green'),
('Rainbow Children','Chennai Guindy','NICU+PICU','Atom Dual','Dual-Incu-V8','ATM-4412','2024-06-09'::date, 97.20, 7.4, 52.1, 3, 'amber'),
('Apollo Cradle','Delhi Nehru Place','NICU','Drager Caleo','C500','DRG-3209','2024-02-14'::date, 96.30, 9.1, 41.5, 4, 'red'),
('Apollo Cradle','Hyderabad Jubilee','PICU','Phoenix Phototherapy','Brilliance Pro','PHX-5501','2024-07-01'::date, 99.10, 4.0, 76.2, 1, 'green'),
('Apollo Cradle','Mumbai Andheri','NICU','GE Giraffe','OmniBed-G7','GEH-2310','2024-08-15'::date, 98.80, 4.5, 71.0, 2, 'green'),
('Cloudnine','Bangalore Whitefield','NICU','Fanem','1186-Vision','FNM-6602','2024-01-20'::date, 95.40, 11.2, 33.8, 5, 'red'),
('Cloudnine','Bangalore Jayanagar','NICU+PICU','Natus Neoblue','LED-Blanket-X','NAT-7708','2024-09-03'::date, 99.50, 3.0, 91.0, 1, 'green'),
('Cloudnine','Gurgaon Sector 47','PICU','Atom Dual','Dual-Incu-V8','ATM-4502','2024-10-11'::date, 97.80, 6.5, 58.4, 2, 'amber'),
('Fortis La Femme','Delhi Greater Kailash','NICU','GE Giraffe','OmniBed-G7','GEH-2401','2024-03-29'::date, 99.20, 3.5, 84.0, 1, 'green'),
('Fortis La Femme','Bangalore Richmond','Step-down NICU','Ibis Medical','MiniIncu-2','IBS-8801','2024-04-07'::date, 96.90, 8.2, 47.3, 3, 'amber'),
('Manipal Hospitals','Bangalore Old Airport','NICU','Drager Caleo','C500','DRG-3402','2024-05-14'::date, 98.40, 5.1, 68.0, 2, 'green'),
('Manipal Hospitals','Pune Baner','PICU','Atom Dual','Dual-Incu-V8','ATM-4611','2024-06-26'::date, 95.10, 12.5, 29.4, 6, 'red'),
('Manipal Hospitals','Jaipur Sirsi Road','NICU+PICU','GE Giraffe','OmniBed-G7','GEH-2515','2024-11-05'::date, 99.60, 2.8, 95.5, 0, 'green'),
('Motherhood','Pune Kharadi','NICU','Fanem','1186-Vision','FNM-6705','2024-02-28'::date, 94.20, 14.0, 24.0, 7, 'red'),
('Motherhood','Bangalore Indiranagar','PICU','Phoenix Phototherapy','Brilliance Pro','PHX-5610','2024-07-19'::date, 99.30, 3.8, 80.0, 1, 'green'),
('Motherhood','Chennai Alwarpet','NICU','Natus Neoblue','LED-Blanket-X','NAT-7812','2024-08-08'::date, 98.20, 5.4, 62.5, 2, 'amber'),
('Aster Women','Kochi Kakkanad','NICU+PICU','Ibis Medical','MiniIncu-2','IBS-8910','2024-09-21'::date, 92.10, 18.5, 18.2, 9, 'retired'),
('Aster Women','Bangalore Whitefield','NICU','GE Giraffe','OmniBed-G7','GEH-2620','2024-10-30'::date, 99.80, 1.9, 110.0, 0, 'green');

-- Seed audit findings (18 rows)
insert into incubator_brand_audit_findings_r2963 (chain_name, brand, finding_quarter, finding_category, severity, units_affected, cost_impact_rupees, remediation_status) values
('Rainbow Children','GE Giraffe','2026-Q2','calibration','p2', 2, 45000.00, 'resolved'),
('Rainbow Children','Drager Caleo','2026-Q2','reliability','p1', 1, 180000.00, 'in_progress'),
('Rainbow Children','Atom Dual','2026-Q1','spares','p2', 3, 92000.00, 'resolved'),
('Apollo Cradle','Drager Caleo','2026-Q2','safety','p0', 1, 650000.00, 'escalated'),
('Apollo Cradle','GE Giraffe','2026-Q3','warranty','p3', 2, 22000.00, 'resolved'),
('Apollo Cradle','Phoenix Phototherapy','2026-Q3','training','p2', 4, 38000.00, 'in_progress'),
('Cloudnine','Fanem','2026-Q1','recall','p0', 1, 850000.00, 'escalated'),
('Cloudnine','Fanem','2026-Q2','reliability','p1', 1, 290000.00, 'open'),
('Cloudnine','Atom Dual','2026-Q3','calibration','p2', 2, 56000.00, 'resolved'),
('Cloudnine','Natus Neoblue','2026-Q4','spares','p3', 1, 14000.00, 'resolved'),
('Fortis La Femme','Ibis Medical','2026-Q2','safety','p1', 3, 420000.00, 'in_progress'),
('Fortis La Femme','GE Giraffe','2026-Q3','training','p3', 5, 28000.00, 'resolved'),
('Manipal Hospitals','Atom Dual','2026-Q1','reliability','p0', 1, 720000.00, 'escalated'),
('Manipal Hospitals','Atom Dual','2026-Q2','spares','p1', 2, 165000.00, 'open'),
('Manipal Hospitals','Drager Caleo','2026-Q3','warranty','p2', 1, 48000.00, 'resolved'),
('Motherhood','Fanem','2026-Q1','recall','p0', 2, 980000.00, 'escalated'),
('Motherhood','Fanem','2026-Q2','safety','p1', 2, 360000.00, 'in_progress'),
('Aster Women','Ibis Medical','2026-Q2','reliability','p0', 1, 1200000.00, 'escalated');

-- RPC 1: brand fleet performance summary
create or replace function rpc_r2963_brand_fleet_summary()
returns table (brand text, total_units int, avg_uptime numeric, avg_mttr numeric, red_units int, retired_units int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.brand,
         count(*)::int,
         round(avg(f.uptime_pct), 2),
         round(avg(f.mttr_hours), 2),
         (count(*) filter (where f.fleet_status = 'red'))::int,
         (count(*) filter (where f.fleet_status = 'retired'))::int
  from incubator_brand_fleet_units_r2963 f
  group by f.brand
  order by avg(f.uptime_pct) desc;
end $$;
revoke all on function rpc_r2963_brand_fleet_summary() from public, anon;
grant execute on function rpc_r2963_brand_fleet_summary() to authenticated;

-- RPC 2: chain-level fleet health
create or replace function rpc_r2963_chain_fleet_health()
returns table (chain_name text, total_units int, green_units int, amber_units int, red_units int, avg_uptime numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.chain_name,
         count(*)::int,
         (count(*) filter (where f.fleet_status = 'green'))::int,
         (count(*) filter (where f.fleet_status = 'amber'))::int,
         (count(*) filter (where f.fleet_status = 'red'))::int,
         round(avg(f.uptime_pct), 2)
  from incubator_brand_fleet_units_r2963 f
  group by f.chain_name
  order by count(*) desc;
end $$;
revoke all on function rpc_r2963_chain_fleet_health() from public, anon;
grant execute on function rpc_r2963_chain_fleet_health() to authenticated;

-- RPC 3: worst-performing units (mttr DESC)
create or replace function rpc_r2963_worst_units()
returns table (chain_name text, hospital_site text, brand text, unit_serial text, uptime_pct numeric, mttr_hours numeric, incidents_q int, fleet_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.chain_name, f.hospital_site, f.brand, f.unit_serial, f.uptime_pct, f.mttr_hours, f.incidents_q, f.fleet_status
  from incubator_brand_fleet_units_r2963 f
  where f.fleet_status in ('red','retired') or f.uptime_pct < 97
  order by f.mttr_hours desc
  limit 15;
end $$;
revoke all on function rpc_r2963_worst_units() from public, anon;
grant execute on function rpc_r2963_worst_units() to authenticated;

-- RPC 4: ward-type performance
create or replace function rpc_r2963_ward_type_perf()
returns table (ward_type text, units int, avg_uptime numeric, avg_mtbf numeric, total_incidents int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.ward_type,
         count(*)::int,
         round(avg(f.uptime_pct), 2),
         round(avg(f.mtbf_days), 2),
         sum(f.incidents_q)::int
  from incubator_brand_fleet_units_r2963 f
  group by f.ward_type
  order by avg(f.uptime_pct) desc;
end $$;
revoke all on function rpc_r2963_ward_type_perf() from public, anon;
grant execute on function rpc_r2963_ward_type_perf() to authenticated;

-- RPC 5: open p0/p1 findings
create or replace function rpc_r2963_open_critical_findings()
returns table (chain_name text, brand text, finding_quarter text, finding_category text, severity text, units_affected int, cost_impact_rupees numeric, remediation_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.chain_name, a.brand, a.finding_quarter, a.finding_category, a.severity, a.units_affected, a.cost_impact_rupees, a.remediation_status
  from incubator_brand_audit_findings_r2963 a
  where a.severity in ('p0','p1') and a.remediation_status in ('open','in_progress','escalated')
  order by a.severity, a.cost_impact_rupees desc;
end $$;
revoke all on function rpc_r2963_open_critical_findings() from public, anon;
grant execute on function rpc_r2963_open_critical_findings() to authenticated;

-- RPC 6: brand audit cost rollup
create or replace function rpc_r2963_brand_cost_rollup()
returns table (brand text, findings int, p0_count int, total_cost numeric, units_affected_total int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.brand,
         count(*)::int,
         (count(*) filter (where a.severity = 'p0'))::int,
         sum(a.cost_impact_rupees),
         sum(a.units_affected)::int
  from incubator_brand_audit_findings_r2963 a
  group by a.brand
  order by sum(a.cost_impact_rupees) desc;
end $$;
revoke all on function rpc_r2963_brand_cost_rollup() from public, anon;
grant execute on function rpc_r2963_brand_cost_rollup() to authenticated;

-- RPC 7: quarterly trend
create or replace function rpc_r2963_quarterly_trend()
returns table (finding_quarter text, findings int, p0_count int, total_cost numeric, resolved_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.finding_quarter,
         count(*)::int,
         (count(*) filter (where a.severity = 'p0'))::int,
         sum(a.cost_impact_rupees),
         (count(*) filter (where a.remediation_status = 'resolved'))::int
  from incubator_brand_audit_findings_r2963 a
  group by a.finding_quarter
  order by a.finding_quarter;
end $$;
revoke all on function rpc_r2963_quarterly_trend() from public, anon;
grant execute on function rpc_r2963_quarterly_trend() to authenticated;
