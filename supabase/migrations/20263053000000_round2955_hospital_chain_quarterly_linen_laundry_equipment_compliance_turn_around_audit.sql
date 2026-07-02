-- Round 2955: Hospital Chain Quarterly Linen-Laundry Equipment Compliance & Turn-Around Audit

create table if not exists hospital_chain_linen_audits_r2955 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  facility_code text not null,
  quarter text not null check (quarter in ('Q1','Q2','Q3','Q4')),
  fiscal_year int not null,
  equipment_type text not null check (equipment_type in ('washer_extractor','tunnel_washer','tumble_dryer','flatwork_ironer','folder_stacker','barrier_washer')),
  units_installed int not null,
  units_compliant int not null,
  avg_turnaround_minutes int not null,
  sla_minutes int not null,
  compliance_score numeric(5,2) not null,
  audit_status text not null check (audit_status in ('pass','watch','fail','remediation')),
  auditor_name text not null,
  audited_at timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists hospital_chain_linen_findings_r2955 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid references hospital_chain_linen_audits_r2955(id) on delete cascade,
  finding_code text not null,
  severity text not null check (severity in ('low','medium','high','critical')),
  category text not null check (category in ('temperature','chemical','cycle_time','maintenance','documentation','hygiene','calibration')),
  description text not null,
  remediation_days int not null,
  closed boolean not null default false,
  estimated_cost_rupees int not null,
  created_at timestamptz default now()
);

alter table hospital_chain_linen_audits_r2955 enable row level security;
alter table hospital_chain_linen_findings_r2955 enable row level security;

drop policy if exists r2955_audits_founder on hospital_chain_linen_audits_r2955;
create policy r2955_audits_founder on hospital_chain_linen_audits_r2955 for select using (is_founder());

drop policy if exists r2955_findings_founder on hospital_chain_linen_findings_r2955;
create policy r2955_findings_founder on hospital_chain_linen_findings_r2955 for select using (is_founder());

insert into hospital_chain_linen_audits_r2955 (chain_name, facility_code, quarter, fiscal_year, equipment_type, units_installed, units_compliant, avg_turnaround_minutes, sla_minutes, compliance_score, audit_status, auditor_name, audited_at)
select * from (values
  ('Apollo Hospitals','APL-HYD-01','Q1',2026,'tunnel_washer',4,4,52,60,98.5,'pass','R. Krishnan','2026-04-12'::timestamptz),
  ('Apollo Hospitals','APL-CHN-02','Q1',2026,'washer_extractor',8,7,68,60,87.2,'watch','R. Krishnan','2026-04-15'::timestamptz),
  ('Apollo Hospitals','APL-BLR-03','Q1',2026,'tumble_dryer',6,6,45,50,96.1,'pass','S. Iyer','2026-04-18'::timestamptz),
  ('Manipal Hospitals','MNP-BLR-01','Q1',2026,'tunnel_washer',3,2,72,60,78.4,'fail','S. Iyer','2026-04-20'::timestamptz),
  ('Manipal Hospitals','MNP-BLR-04','Q1',2026,'flatwork_ironer',2,2,38,45,94.7,'pass','P. Naidu','2026-04-22'::timestamptz),
  ('Fortis Healthcare','FRT-DEL-01','Q1',2026,'barrier_washer',5,4,58,60,89.3,'watch','P. Naidu','2026-04-25'::timestamptz),
  ('Fortis Healthcare','FRT-MUM-02','Q1',2026,'folder_stacker',4,3,42,40,82.6,'watch','M. Joshi','2026-04-28'::timestamptz),
  ('Max Healthcare','MAX-DEL-01','Q1',2026,'washer_extractor',6,6,48,60,97.8,'pass','M. Joshi','2026-05-02'::timestamptz),
  ('Max Healthcare','MAX-DEL-03','Q1',2026,'tunnel_washer',3,1,85,60,62.4,'remediation','R. Krishnan','2026-05-05'::timestamptz),
  ('Narayana Health','NRY-BLR-01','Q1',2026,'tumble_dryer',8,8,40,50,99.1,'pass','S. Iyer','2026-05-08'::timestamptz),
  ('Narayana Health','NRY-KOL-02','Q1',2026,'barrier_washer',4,3,55,60,86.9,'watch','P. Naidu','2026-05-10'::timestamptz),
  ('AIIMS Network','AIIMS-DEL-01','Q1',2026,'tunnel_washer',6,6,50,60,95.4,'pass','M. Joshi','2026-05-12'::timestamptz),
  ('AIIMS Network','AIIMS-BHO-02','Q1',2026,'washer_extractor',4,2,78,60,71.2,'fail','R. Krishnan','2026-05-14'::timestamptz),
  ('Medanta Hospitals','MED-GUR-01','Q1',2026,'flatwork_ironer',3,3,42,45,93.6,'pass','S. Iyer','2026-05-16'::timestamptz),
  ('Medanta Hospitals','MED-LKO-02','Q1',2026,'folder_stacker',2,1,48,40,68.5,'remediation','P. Naidu','2026-05-18'::timestamptz),
  ('KIMS Hospitals','KIMS-HYD-01','Q1',2026,'barrier_washer',3,3,52,60,96.7,'pass','M. Joshi','2026-05-20'::timestamptz),
  ('Yashoda Hospitals','YSH-HYD-01','Q1',2026,'tunnel_washer',2,2,55,60,92.8,'pass','R. Krishnan','2026-05-22'::timestamptz),
  ('Continental Hospitals','CNT-HYD-01','Q1',2026,'washer_extractor',4,3,62,60,84.5,'watch','S. Iyer','2026-05-24'::timestamptz)
) as t(chain_name, facility_code, quarter, fiscal_year, equipment_type, units_installed, units_compliant, avg_turnaround_minutes, sla_minutes, compliance_score, audit_status, auditor_name, audited_at);

insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'high', 'temperature', 'Wash cycle temperature 8C below CDC threshold', 14, false, 45000 from hospital_chain_linen_audits_r2955 where facility_code='APL-CHN-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'critical', 'cycle_time', 'Turnaround 12 min over SLA for OT linen', 7, false, 120000 from hospital_chain_linen_audits_r2955 where facility_code='MNP-BLR-01' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-002', 'medium', 'chemical', 'Chemical dosing pump miscalibrated', 21, true, 28000 from hospital_chain_linen_audits_r2955 where facility_code='MNP-BLR-01' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'medium', 'maintenance', 'Belt wear on folder beyond threshold', 30, false, 65000 from hospital_chain_linen_audits_r2955 where facility_code='FRT-MUM-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'critical', 'hygiene', 'Cross-contamination risk: barrier seal breach', 3, false, 180000 from hospital_chain_linen_audits_r2955 where facility_code='MAX-DEL-03' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-002', 'high', 'temperature', 'Tunnel zone 3 temp drop intermittent', 10, false, 95000 from hospital_chain_linen_audits_r2955 where facility_code='MAX-DEL-03' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'low', 'documentation', 'Daily log gaps on weekends', 14, true, 5000 from hospital_chain_linen_audits_r2955 where facility_code='NRY-KOL-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'high', 'calibration', 'Temp probe drift +/- 3C', 7, false, 35000 from hospital_chain_linen_audits_r2955 where facility_code='AIIMS-BHO-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-002', 'critical', 'cycle_time', 'Cycle time 30% above spec', 5, false, 150000 from hospital_chain_linen_audits_r2955 where facility_code='AIIMS-BHO-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'medium', 'maintenance', 'Folder stacker bearing replacement overdue', 21, false, 42000 from hospital_chain_linen_audits_r2955 where facility_code='MED-LKO-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'low', 'documentation', 'Calibration cert expired 12 days', 7, true, 3000 from hospital_chain_linen_audits_r2955 where facility_code='CNT-HYD-01' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'medium', 'hygiene', 'Lint filter cleaning frequency below spec', 14, false, 12000 from hospital_chain_linen_audits_r2955 where facility_code='FRT-DEL-01' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'high', 'chemical', 'Detergent batch QC variance', 10, false, 55000 from hospital_chain_linen_audits_r2955 where facility_code='APL-CHN-02' limit 1;
insert into hospital_chain_linen_findings_r2955 (audit_id, finding_code, severity, category, description, remediation_days, closed, estimated_cost_rupees)
select id, 'F-' || substr(facility_code,1,6) || '-001', 'low', 'documentation', 'Shift handover log incomplete', 14, true, 2500 from hospital_chain_linen_audits_r2955 where facility_code='NRY-BLR-01' limit 1;

revoke all on hospital_chain_linen_audits_r2955 from public, anon;
revoke all on hospital_chain_linen_findings_r2955 from public, anon;
grant select on hospital_chain_linen_audits_r2955 to authenticated;
grant select on hospital_chain_linen_findings_r2955 to authenticated;

create or replace function r2955_chain_summary()
returns table(chain_name text, facilities int, avg_compliance numeric, fails int, watches int, passes int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.chain_name,
    count(*)::int as facilities,
    round(avg(a.compliance_score),2) as avg_compliance,
    (count(*) filter (where a.audit_status='fail'))::int as fails,
    (count(*) filter (where a.audit_status='watch'))::int as watches,
    (count(*) filter (where a.audit_status='pass'))::int as passes
  from hospital_chain_linen_audits_r2955 a
  group by a.chain_name
  order by avg_compliance desc;
end$$;

create or replace function r2955_equipment_turnaround()
returns table(equipment_type text, units int, avg_turnaround int, avg_sla int, over_sla int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.equipment_type,
    sum(a.units_installed)::int as units,
    avg(a.avg_turnaround_minutes)::int as avg_turnaround,
    avg(a.sla_minutes)::int as avg_sla,
    (count(*) filter (where a.avg_turnaround_minutes > a.sla_minutes))::int as over_sla
  from hospital_chain_linen_audits_r2955 a
  group by a.equipment_type
  order by over_sla desc;
end$$;

create or replace function r2955_critical_findings()
returns table(facility_code text, chain_name text, finding_code text, category text, description text, remediation_days int, estimated_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.facility_code, a.chain_name, f.finding_code, f.category, f.description, f.remediation_days, f.estimated_cost_rupees
  from hospital_chain_linen_findings_r2955 f
  join hospital_chain_linen_audits_r2955 a on a.id = f.audit_id
  where f.severity = 'critical' and f.closed = false
  order by f.remediation_days asc;
end$$;

create or replace function r2955_status_distribution()
returns table(audit_status text, count int, avg_score numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_status, count(*)::int as count, round(avg(a.compliance_score),2) as avg_score
  from hospital_chain_linen_audits_r2955 a
  group by a.audit_status
  order by count desc;
end$$;

create or replace function r2955_finding_categories()
returns table(category text, total int, open int, closed int, total_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.category,
    count(*)::int as total,
    (count(*) filter (where f.closed = false))::int as open,
    (count(*) filter (where f.closed = true))::int as closed,
    sum(f.estimated_cost_rupees)::int as total_cost_rupees
  from hospital_chain_linen_findings_r2955 f
  group by f.category
  order by total desc;
end$$;

create or replace function r2955_worst_facilities()
returns table(facility_code text, chain_name text, equipment_type text, compliance_score numeric, avg_turnaround_minutes int, sla_minutes int, audit_status text)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.facility_code, a.chain_name, a.equipment_type, a.compliance_score, a.avg_turnaround_minutes, a.sla_minutes, a.audit_status
  from hospital_chain_linen_audits_r2955 a
  where a.audit_status in ('fail','remediation','watch')
  order by a.compliance_score asc
  limit 10;
end$$;

create or replace function r2955_kpis()
returns table(total_audits int, total_facilities int, total_units int, avg_compliance numeric, open_findings int, critical_open int, total_remediation_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    (select count(*)::int from hospital_chain_linen_audits_r2955),
    (select count(distinct facility_code)::int from hospital_chain_linen_audits_r2955),
    (select sum(units_installed)::int from hospital_chain_linen_audits_r2955),
    (select round(avg(compliance_score),2) from hospital_chain_linen_audits_r2955),
    (select (count(*) filter (where closed = false))::int from hospital_chain_linen_findings_r2955),
    (select (count(*) filter (where severity='critical' and closed=false))::int from hospital_chain_linen_findings_r2955),
    (select sum(estimated_cost_rupees) filter (where closed=false)::int from hospital_chain_linen_findings_r2955);
end$$;

revoke all on function r2955_chain_summary() from public, anon;
revoke all on function r2955_equipment_turnaround() from public, anon;
revoke all on function r2955_critical_findings() from public, anon;
revoke all on function r2955_status_distribution() from public, anon;
revoke all on function r2955_finding_categories() from public, anon;
revoke all on function r2955_worst_facilities() from public, anon;
revoke all on function r2955_kpis() from public, anon;

grant execute on function r2955_chain_summary() to authenticated;
grant execute on function r2955_equipment_turnaround() to authenticated;
grant execute on function r2955_critical_findings() to authenticated;
grant execute on function r2955_status_distribution() to authenticated;
grant execute on function r2955_finding_categories() to authenticated;
grant execute on function r2955_worst_facilities() to authenticated;
grant execute on function r2955_kpis() to authenticated;
