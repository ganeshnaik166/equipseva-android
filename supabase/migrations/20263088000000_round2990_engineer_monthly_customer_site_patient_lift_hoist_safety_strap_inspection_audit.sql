-- Round r2990: Engineer Monthly Customer Site Patient-Lift-Hoist Safety Strap Inspection Audit

create table if not exists engineer_hoist_strap_inspections_r2990 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  inspection_month date not null,
  customer_site_name text not null,
  city text not null,
  engineer_name text not null,
  hoist_asset_tag text not null,
  hoist_model text not null,
  strap_count_inspected int not null check (strap_count_inspected between 1 and 40),
  straps_passed int not null check (straps_passed between 0 and 40),
  straps_failed int not null check (straps_failed between 0 and 40),
  fray_findings int not null default 0 check (fray_findings between 0 and 40),
  stitch_failures int not null default 0 check (stitch_failures between 0 and 40),
  load_test_kg int not null check (load_test_kg between 50 and 400),
  pass_rate_pct numeric(5,2) not null check (pass_rate_pct between 0 and 100),
  risk_band text not null check (risk_band in ('green','amber','red','black')),
  status text not null check (status in ('scheduled','in_progress','completed','overdue','escalated')),
  notes text
);

create table if not exists engineer_hoist_strap_findings_r2990 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  inspection_id uuid references engineer_hoist_strap_inspections_r2990(id) on delete cascade,
  finding_date date not null,
  strap_serial text not null,
  defect_type text not null check (defect_type in ('fray','stitch_failure','buckle_corrosion','load_tag_missing','date_expired','tear','chemical_damage')),
  severity text not null check (severity in ('observation','minor','major','critical')),
  action_taken text not null check (action_taken in ('replaced','quarantined','tagged_out','monitor','escalated_oem')),
  replacement_cost_rupees int not null check (replacement_cost_rupees between 500 and 25000),
  resolved boolean not null default false
);

alter table engineer_hoist_strap_inspections_r2990 enable row level security;
alter table engineer_hoist_strap_findings_r2990 enable row level security;

drop policy if exists founder_read_insp_r2990 on engineer_hoist_strap_inspections_r2990;
create policy founder_read_insp_r2990 on engineer_hoist_strap_inspections_r2990 for select using (is_founder());

drop policy if exists founder_read_find_r2990 on engineer_hoist_strap_findings_r2990;
create policy founder_read_find_r2990 on engineer_hoist_strap_findings_r2990 for select using (is_founder());

-- Seed inspections (16 rows)
insert into engineer_hoist_strap_inspections_r2990 (inspection_month, customer_site_name, city, engineer_name, hoist_asset_tag, hoist_model, strap_count_inspected, straps_passed, straps_failed, fray_findings, stitch_failures, load_test_kg, pass_rate_pct, risk_band, status, notes) values
('2026-06-01'::date, 'Apollo Jubilee Hills', 'Hyderabad', 'Ravi Kumar', 'HST-AP-001', 'Arjo Maxi Move', 12, 11, 1, 1, 0, 250, 91.67, 'green', 'completed', 'one strap retired'),
('2026-06-01'::date, 'KIMS Secunderabad', 'Hyderabad', 'Suresh Naidu', 'HST-KIMS-014', 'Hill-Rom Liko', 10, 8, 2, 1, 1, 200, 80.00, 'amber', 'completed', 'two fray cases'),
('2026-06-01'::date, 'Fortis BG Road', 'Bangalore', 'Anand Reddy', 'HST-FT-022', 'Invacare Reliant', 14, 14, 0, 0, 0, 300, 100.00, 'green', 'completed', 'clean'),
('2026-06-01'::date, 'Manipal Whitefield', 'Bangalore', 'Priya Iyer', 'HST-MN-007', 'Arjo Sara Plus', 8, 6, 2, 2, 0, 180, 75.00, 'amber', 'completed', 'fray under load'),
('2026-06-01'::date, 'Max Saket', 'Delhi', 'Vikram Singh', 'HST-MX-031', 'Hill-Rom Viking', 16, 13, 3, 2, 1, 275, 81.25, 'amber', 'completed', 'stitching weak'),
('2026-06-01'::date, 'AIIMS Trauma', 'Delhi', 'Rohit Gupta', 'HST-AI-002', 'Arjo Maxi Sky', 20, 16, 4, 3, 1, 350, 80.00, 'amber', 'completed', 'high traffic ward'),
('2026-06-01'::date, 'Tata Memorial', 'Mumbai', 'Manish Joshi', 'HST-TM-019', 'Liko Golvo', 18, 14, 4, 2, 2, 320, 77.78, 'amber', 'completed', 'oncology floor'),
('2026-06-01'::date, 'Hinduja Mahim', 'Mumbai', 'Deepak Shetty', 'HST-HJ-011', 'Invacare Birdie', 6, 3, 3, 1, 2, 150, 50.00, 'red', 'escalated', 'half failed'),
('2026-06-01'::date, 'CMC Vellore', 'Vellore', 'Joseph Thomas', 'HST-CMC-005', 'Arjo Tenor', 10, 10, 0, 0, 0, 220, 100.00, 'green', 'completed', 'exemplary'),
('2026-06-01'::date, 'PGI Chandigarh', 'Chandigarh', 'Harpreet Kaur', 'HST-PGI-008', 'Hill-Rom Likorall', 12, 9, 3, 2, 1, 240, 75.00, 'amber', 'completed', 'aged straps'),
('2026-06-01'::date, 'Narayana Bengaluru', 'Bangalore', 'Karthik Rao', 'HST-NH-027', 'Arjo Maxi Twin', 14, 12, 2, 1, 1, 290, 85.71, 'green', 'completed', 'within band'),
('2026-06-01'::date, 'Medanta Gurgaon', 'Gurgaon', 'Sandeep Yadav', 'HST-MD-016', 'Liko M220', 22, 17, 5, 3, 2, 380, 77.27, 'amber', 'completed', 'replace batch'),
('2026-06-01'::date, 'Yashoda Somajiguda', 'Hyderabad', 'Lakshmi Devi', 'HST-YS-009', 'Arjo Sara 3000', 10, 5, 5, 3, 2, 200, 50.00, 'red', 'escalated', 'critical'),
('2026-06-01'::date, 'Sterling Ahmedabad', 'Ahmedabad', 'Nirav Patel', 'HST-ST-013', 'Invacare RPS', 8, 7, 1, 1, 0, 175, 87.50, 'green', 'completed', 'fine'),
('2026-06-01'::date, 'Wockhardt Mumbai', 'Mumbai', 'Asif Khan', 'HST-WK-024', 'Liko Sabina', 12, 8, 4, 2, 2, 260, 66.67, 'red', 'escalated', 'urgent action'),
('2026-06-01'::date, 'Kokilaben Mumbai', 'Mumbai', 'Mahesh Pillai', 'HST-KB-018', 'Arjo Carendo', 4, 1, 3, 2, 1, 120, 25.00, 'black', 'escalated', 'tag out');

-- Seed findings (18 rows)
insert into engineer_hoist_strap_findings_r2990 (finding_date, strap_serial, defect_type, severity, action_taken, replacement_cost_rupees, resolved) values
('2026-06-02'::date, 'SS-AP-A1', 'fray', 'minor', 'replaced', 4500, true),
('2026-06-02'::date, 'SS-KIMS-B3', 'stitch_failure', 'major', 'replaced', 5200, true),
('2026-06-03'::date, 'SS-KIMS-B5', 'fray', 'minor', 'replaced', 4500, true),
('2026-06-03'::date, 'SS-MN-C2', 'fray', 'major', 'quarantined', 4800, false),
('2026-06-04'::date, 'SS-MN-C4', 'fray', 'minor', 'replaced', 4500, true),
('2026-06-04'::date, 'SS-MX-D1', 'stitch_failure', 'major', 'replaced', 5500, true),
('2026-06-05'::date, 'SS-MX-D3', 'fray', 'minor', 'replaced', 4500, true),
('2026-06-05'::date, 'SS-AI-E2', 'fray', 'major', 'replaced', 5000, true),
('2026-06-06'::date, 'SS-AI-E5', 'date_expired', 'observation', 'tagged_out', 4500, true),
('2026-06-06'::date, 'SS-HJ-F1', 'tear', 'critical', 'tagged_out', 6000, false),
('2026-06-07'::date, 'SS-HJ-F2', 'stitch_failure', 'critical', 'escalated_oem', 6500, false),
('2026-06-07'::date, 'SS-HJ-F3', 'fray', 'major', 'replaced', 5000, true),
('2026-06-08'::date, 'SS-YS-G1', 'chemical_damage', 'critical', 'escalated_oem', 8500, false),
('2026-06-08'::date, 'SS-YS-G3', 'fray', 'major', 'quarantined', 4800, false),
('2026-06-09'::date, 'SS-WK-H2', 'buckle_corrosion', 'major', 'replaced', 7200, true),
('2026-06-09'::date, 'SS-WK-H4', 'stitch_failure', 'major', 'replaced', 5500, true),
('2026-06-10'::date, 'SS-KB-J1', 'tear', 'critical', 'escalated_oem', 9500, false),
('2026-06-10'::date, 'SS-KB-J3', 'load_tag_missing', 'minor', 'tagged_out', 1500, true);

-- RPCs
create or replace function rpc_r2990_inspection_overview()
returns table(inspection_month date, sites int, total_straps int, passed int, failed int, avg_pass_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.inspection_month,
    (count(distinct i.customer_site_name))::int,
    (sum(i.strap_count_inspected))::int,
    (sum(i.straps_passed))::int,
    (sum(i.straps_failed))::int,
    round(avg(i.pass_rate_pct),2)
  from engineer_hoist_strap_inspections_r2990 i
  group by i.inspection_month
  order by i.inspection_month desc;
end; $$;

create or replace function rpc_r2990_risk_band_breakdown()
returns table(risk_band text, sites int, avg_pass_pct numeric, total_failed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.risk_band, (count(*))::int, round(avg(i.pass_rate_pct),2), (sum(i.straps_failed))::int
  from engineer_hoist_strap_inspections_r2990 i
  group by i.risk_band
  order by case i.risk_band when 'black' then 1 when 'red' then 2 when 'amber' then 3 else 4 end;
end; $$;

create or replace function rpc_r2990_engineer_performance()
returns table(engineer_name text, inspections int, avg_pass_pct numeric, escalations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.engineer_name,
    (count(*))::int,
    round(avg(i.pass_rate_pct),2),
    (count(*) filter (where i.status = 'escalated'))::int
  from engineer_hoist_strap_inspections_r2990 i
  group by i.engineer_name
  order by avg(i.pass_rate_pct) desc;
end; $$;

create or replace function rpc_r2990_red_black_sites()
returns table(customer_site_name text, city text, risk_band text, pass_rate_pct numeric, straps_failed int, notes text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.customer_site_name, i.city, i.risk_band, i.pass_rate_pct, i.straps_failed, i.notes
  from engineer_hoist_strap_inspections_r2990 i
  where i.risk_band in ('red','black')
  order by i.pass_rate_pct asc;
end; $$;

create or replace function rpc_r2990_defect_mix()
returns table(defect_type text, occurrences int, critical_count int, avg_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.defect_type,
    (count(*))::int,
    (count(*) filter (where f.severity = 'critical'))::int,
    round(avg(f.replacement_cost_rupees),0)
  from engineer_hoist_strap_findings_r2990 f
  group by f.defect_type
  order by count(*) desc;
end; $$;

create or replace function rpc_r2990_unresolved_findings()
returns table(finding_date date, strap_serial text, defect_type text, severity text, action_taken text, replacement_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_date, f.strap_serial, f.defect_type, f.severity, f.action_taken, f.replacement_cost_rupees
  from engineer_hoist_strap_findings_r2990 f
  where f.resolved = false
  order by f.finding_date desc;
end; $$;

create or replace function rpc_r2990_city_rollup()
returns table(city text, sites int, avg_pass_pct numeric, total_failed int, escalations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.city,
    (count(*))::int,
    round(avg(i.pass_rate_pct),2),
    (sum(i.straps_failed))::int,
    (count(*) filter (where i.status = 'escalated'))::int
  from engineer_hoist_strap_inspections_r2990 i
  group by i.city
  order by avg(i.pass_rate_pct) asc;
end; $$;

revoke all on function rpc_r2990_inspection_overview() from public, anon;
revoke all on function rpc_r2990_risk_band_breakdown() from public, anon;
revoke all on function rpc_r2990_engineer_performance() from public, anon;
revoke all on function rpc_r2990_red_black_sites() from public, anon;
revoke all on function rpc_r2990_defect_mix() from public, anon;
revoke all on function rpc_r2990_unresolved_findings() from public, anon;
revoke all on function rpc_r2990_city_rollup() from public, anon;

grant execute on function rpc_r2990_inspection_overview() to authenticated;
grant execute on function rpc_r2990_risk_band_breakdown() to authenticated;
grant execute on function rpc_r2990_engineer_performance() to authenticated;
grant execute on function rpc_r2990_red_black_sites() to authenticated;
grant execute on function rpc_r2990_defect_mix() to authenticated;
grant execute on function rpc_r2990_unresolved_findings() to authenticated;
grant execute on function rpc_r2990_city_rollup() to authenticated;
