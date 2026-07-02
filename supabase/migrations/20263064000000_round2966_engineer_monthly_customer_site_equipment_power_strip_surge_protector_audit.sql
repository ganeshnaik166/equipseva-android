-- Round r2966: Engineer Monthly Customer Site Equipment Power-Strip & Surge-Protector Audit
-- HEAVY ★★★★

create table if not exists power_strip_audits_r2966 (
  id uuid primary key default gen_random_uuid(),
  audit_code text not null unique,
  engineer_name text not null,
  customer_site text not null,
  city text not null,
  audit_date date not null,
  device_count int not null check (device_count >= 0),
  failed_count int not null check (failed_count >= 0),
  outcome text not null check (outcome in ('pass','fail','partial','escalated')),
  surge_joules_avg int not null check (surge_joules_avg >= 0),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists power_strip_findings_r2966 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references power_strip_audits_r2966(id) on delete cascade,
  finding_type text not null check (finding_type in ('overload','no_surge','damaged_socket','wrong_rating','daisy_chain','grounding_fault')),
  severity text not null check (severity in ('low','med','high','critical')),
  status text not null check (status in ('open','remediated','accepted_risk','deferred')),
  remediation_cost_rupees int not null check (remediation_cost_rupees >= 0),
  reported_at date not null,
  created_at timestamptz not null default now()
);

alter table power_strip_audits_r2966 enable row level security;
alter table power_strip_findings_r2966 enable row level security;

drop policy if exists psa_r2966_founder on power_strip_audits_r2966;
create policy psa_r2966_founder on power_strip_audits_r2966 for select using (is_founder());

drop policy if exists psf_r2966_founder on power_strip_findings_r2966;
create policy psf_r2966_founder on power_strip_findings_r2966 for select using (is_founder());

-- Seed audits
insert into power_strip_audits_r2966 (audit_code, engineer_name, customer_site, city, audit_date, device_count, failed_count, outcome, surge_joules_avg, notes) values
('PSA-2966-001','Ravi Kumar','Apollo Jubilee Hills','Hyderabad','2026-06-01'::date,42,3,'pass',1800,'Routine OK'),
('PSA-2966-002','Sunita Reddy','Yashoda Secunderabad','Hyderabad','2026-06-02'::date,58,9,'partial',1200,'9 strips failing'),
('PSA-2966-003','Mohan Iyer','Manipal Bangalore','Bangalore','2026-06-03'::date,71,2,'pass',2100,'Good shape'),
('PSA-2966-004','Priya Sharma','Fortis Mulund','Mumbai','2026-06-04'::date,33,12,'fail',800,'Mass replacement needed'),
('PSA-2966-005','Arjun Nair','AIIMS Delhi','Delhi','2026-06-05'::date,89,5,'partial',1500,'5 daisy-chained'),
('PSA-2966-006','Kavita Joshi','KIMS Hyderabad','Hyderabad','2026-06-06'::date,46,1,'pass',1900,'Clean'),
('PSA-2966-007','Deepak Verma','Max Saket','Delhi','2026-06-07'::date,52,15,'escalated',600,'Critical grounding fault'),
('PSA-2966-008','Rajesh Pillai','Narayana Bangalore','Bangalore','2026-06-08'::date,64,4,'pass',1700,'OK'),
('PSA-2966-009','Anita Desai','Lilavati Mumbai','Mumbai','2026-06-09'::date,38,7,'partial',1100,'7 overloaded'),
('PSA-2966-010','Vikram Singh','Medanta Gurgaon','Gurgaon','2026-06-10'::date,75,3,'pass',1850,'Pass'),
('PSA-2966-011','Sneha Patel','Sterling Ahmedabad','Ahmedabad','2026-06-11'::date,29,8,'fail',900,'Old infra'),
('PSA-2966-012','Karthik Reddy','Continental Hyderabad','Hyderabad','2026-06-12'::date,55,2,'pass',2000,'Good'),
('PSA-2966-013','Lakshmi Iyer','SRMC Chennai','Chennai','2026-06-13'::date,67,11,'fail',700,'Replace all'),
('PSA-2966-014','Ankit Gupta','PGI Chandigarh','Chandigarh','2026-06-14'::date,82,6,'partial',1300,'6 issues'),
('PSA-2966-015','Pooja Malhotra','Hinduja Mumbai','Mumbai','2026-06-15'::date,44,1,'pass',1950,'Clean'),
('PSA-2966-016','Sanjay Rao','BGS Bangalore','Bangalore','2026-06-16'::date,36,4,'pass',1600,'OK'),
('PSA-2966-017','Meera Khan','Wockhardt Mumbai','Mumbai','2026-06-17'::date,49,13,'escalated',500,'Critical fail'),
('PSA-2966-018','Rohit Mehta','Ruby Hall Pune','Pune','2026-06-18'::date,58,3,'pass',1750,'Pass');

-- Seed findings
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'overload','high','open',3500,'2026-06-02'::date from power_strip_audits_r2966 where audit_code='PSA-2966-002' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'no_surge','critical','open',8000,'2026-06-04'::date from power_strip_audits_r2966 where audit_code='PSA-2966-004' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'daisy_chain','med','remediated',1200,'2026-06-05'::date from power_strip_audits_r2966 where audit_code='PSA-2966-005' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'grounding_fault','critical','open',15000,'2026-06-07'::date from power_strip_audits_r2966 where audit_code='PSA-2966-007' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'damaged_socket','high','remediated',2200,'2026-06-09'::date from power_strip_audits_r2966 where audit_code='PSA-2966-009' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'wrong_rating','med','accepted_risk',900,'2026-06-11'::date from power_strip_audits_r2966 where audit_code='PSA-2966-011' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'overload','high','open',4100,'2026-06-13'::date from power_strip_audits_r2966 where audit_code='PSA-2966-013' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'no_surge','high','deferred',5500,'2026-06-14'::date from power_strip_audits_r2966 where audit_code='PSA-2966-014' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'grounding_fault','critical','open',18000,'2026-06-17'::date from power_strip_audits_r2966 where audit_code='PSA-2966-017' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'damaged_socket','low','remediated',600,'2026-06-18'::date from power_strip_audits_r2966 where audit_code='PSA-2966-018' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'daisy_chain','med','remediated',1500,'2026-06-02'::date from power_strip_audits_r2966 where audit_code='PSA-2966-002' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'overload','low','accepted_risk',400,'2026-06-08'::date from power_strip_audits_r2966 where audit_code='PSA-2966-008' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'wrong_rating','high','open',2800,'2026-06-13'::date from power_strip_audits_r2966 where audit_code='PSA-2966-013' limit 1;
insert into power_strip_findings_r2966 (audit_id, finding_type, severity, status, remediation_cost_rupees, reported_at)
select id, 'no_surge','med','deferred',1700,'2026-06-15'::date from power_strip_audits_r2966 where audit_code='PSA-2966-015' limit 1;

-- RPCs
create or replace function r2966_audit_overview()
returns table(total_audits int, total_devices int, total_failed int, fail_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select count(*)::int,
         coalesce(sum(device_count),0)::int,
         coalesce(sum(failed_count),0)::int,
         round(coalesce(sum(failed_count),0)::numeric * 100.0 / nullif(sum(device_count),0), 2)
  from power_strip_audits_r2966;
end; $$;

create or replace function r2966_outcome_breakdown()
returns table(outcome text, audit_count int, total_devices int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.outcome, count(*)::int, coalesce(sum(a.device_count),0)::int
  from power_strip_audits_r2966 a
  group by a.outcome
  order by audit_count desc;
end; $$;

create or replace function r2966_city_summary()
returns table(city text, audit_count int, devices int, failed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.city, count(*)::int, coalesce(sum(a.device_count),0)::int, coalesce(sum(a.failed_count),0)::int
  from power_strip_audits_r2966 a
  group by a.city
  order by failed desc;
end; $$;

create or replace function r2966_finding_severity_mix()
returns table(severity text, finding_count int, open_count int, remediation_cost int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.severity,
         count(*)::int,
         (count(*) filter (where f.status='open'))::int,
         coalesce(sum(f.remediation_cost_rupees),0)::int
  from power_strip_findings_r2966 f
  group by f.severity
  order by finding_count desc;
end; $$;

create or replace function r2966_finding_type_mix()
returns table(finding_type text, finding_count int, critical_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.finding_type,
         count(*)::int,
         (count(*) filter (where f.severity='critical'))::int
  from power_strip_findings_r2966 f
  group by f.finding_type
  order by finding_count desc;
end; $$;

create or replace function r2966_engineer_leaderboard()
returns table(engineer_name text, audits int, devices int, failed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.engineer_name, count(*)::int, coalesce(sum(a.device_count),0)::int, coalesce(sum(a.failed_count),0)::int
  from power_strip_audits_r2966 a
  group by a.engineer_name
  order by devices desc
  limit 12;
end; $$;

create or replace function r2966_critical_open_findings()
returns table(audit_code text, customer_site text, finding_type text, remediation_cost int, reported_at date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_code, a.customer_site, f.finding_type, f.remediation_cost_rupees, f.reported_at
  from power_strip_findings_r2966 f
  join power_strip_audits_r2966 a on a.id = f.audit_id
  where f.severity in ('critical','high') and f.status='open'
  order by f.remediation_cost_rupees desc;
end; $$;

revoke all on function r2966_audit_overview() from public, anon;
revoke all on function r2966_outcome_breakdown() from public, anon;
revoke all on function r2966_city_summary() from public, anon;
revoke all on function r2966_finding_severity_mix() from public, anon;
revoke all on function r2966_finding_type_mix() from public, anon;
revoke all on function r2966_engineer_leaderboard() from public, anon;
revoke all on function r2966_critical_open_findings() from public, anon;

grant execute on function r2966_audit_overview() to authenticated;
grant execute on function r2966_outcome_breakdown() to authenticated;
grant execute on function r2966_city_summary() to authenticated;
grant execute on function r2966_finding_severity_mix() to authenticated;
grant execute on function r2966_finding_type_mix() to authenticated;
grant execute on function r2966_engineer_leaderboard() to authenticated;
grant execute on function r2966_critical_open_findings() to authenticated;
