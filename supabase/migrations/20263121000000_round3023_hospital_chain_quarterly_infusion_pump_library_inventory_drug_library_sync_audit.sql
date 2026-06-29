-- Round 3023 — Hospital Chain Quarterly Infusion-Pump Library Inventory & Drug-Library Sync Audit
-- Batch 430 milestone · HEAVY ★★★★

create table if not exists infusion_pump_inventory_r3023 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_site text not null,
  pump_model text not null,
  pump_serial text not null unique,
  ward text not null,
  firmware_version text,
  drug_library_version text,
  last_sync_at timestamptz,
  sync_status text not null check (sync_status in ('current','stale','out_of_sync','offline','quarantined')),
  asset_status text not null check (asset_status in ('in_service','in_repair','retired','reserve')),
  quarter text not null check (quarter ~ '^[0-9]{4}-Q[1-4]$'),
  audited_at timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists drug_library_sync_audit_r3023 (
  id uuid primary key default gen_random_uuid(),
  chain_name text not null,
  hospital_site text not null,
  library_version text not null,
  approved_by_pharmacy text not null,
  push_initiated_at timestamptz not null,
  push_completed_at timestamptz,
  pumps_targeted int not null check (pumps_targeted >= 0),
  pumps_synced int not null check (pumps_synced >= 0),
  pumps_failed int not null check (pumps_failed >= 0),
  variance_flag text not null check (variance_flag in ('none','minor','moderate','severe')),
  remediation_status text not null check (remediation_status in ('pending','in_progress','closed','escalated')),
  quarter text not null check (quarter ~ '^[0-9]{4}-Q[1-4]$'),
  created_at timestamptz default now()
);

alter table infusion_pump_inventory_r3023 enable row level security;
alter table drug_library_sync_audit_r3023 enable row level security;

drop policy if exists ipi_r3023_founder_all on infusion_pump_inventory_r3023;
create policy ipi_r3023_founder_all on infusion_pump_inventory_r3023 for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists dlsa_r3023_founder_all on drug_library_sync_audit_r3023;
create policy dlsa_r3023_founder_all on drug_library_sync_audit_r3023 for all to authenticated using (is_founder()) with check (is_founder());

insert into infusion_pump_inventory_r3023 (chain_name, hospital_site, pump_model, pump_serial, ward, firmware_version, drug_library_version, last_sync_at, sync_status, asset_status, quarter) values
('Apollo','Hyderabad-Jubilee','BBraun Infusomat Space','SN-AP-0001','ICU-A','2.4.1','DL-2026.1','2026-06-20T08:30:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Apollo','Hyderabad-Jubilee','BBraun Infusomat Space','SN-AP-0002','ICU-A','2.4.1','DL-2026.1','2026-06-20T08:31:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Apollo','Chennai-Greams','Baxter Sigma Spectrum','SN-AP-0003','NICU','8.2.0','DL-2025.4','2026-04-12T10:00:00Z'::timestamptz,'stale','in_service','2026-Q2'),
('Apollo','Chennai-Greams','Baxter Sigma Spectrum','SN-AP-0004','NICU','8.2.0','DL-2025.4','2026-04-12T10:01:00Z'::timestamptz,'stale','in_service','2026-Q2'),
('Apollo','Bengaluru-Bannerghatta','ICU Medical Plum 360','SN-AP-0005','OT-3','12.1.3','DL-2026.1','2026-06-21T09:15:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Apollo','Bengaluru-Bannerghatta','ICU Medical Plum 360','SN-AP-0006','OT-3',null,null,null,'offline','in_repair','2026-Q2'),
('Manipal','Bengaluru-Old Airport','BBraun Perfusor Space','SN-MN-0007','Onco','3.0.2','DL-2026.1','2026-06-19T07:45:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Manipal','Bengaluru-Old Airport','BBraun Perfusor Space','SN-MN-0008','Onco','3.0.2','DL-2025.4','2026-05-02T11:20:00Z'::timestamptz,'out_of_sync','in_service','2026-Q2'),
('Manipal','Jaipur','Mindray BeneFusion','SN-MN-0009','PICU','5.1.0','DL-2026.1','2026-06-22T06:00:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Manipal','Jaipur','Mindray BeneFusion','SN-MN-0010','PICU','5.0.9','DL-2025.3','2026-03-10T05:30:00Z'::timestamptz,'quarantined','in_repair','2026-Q2'),
('Fortis','Gurugram','Baxter Sigma Spectrum','SN-FT-0011','Cardiac','8.2.0','DL-2026.1','2026-06-23T12:00:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Fortis','Gurugram','Baxter Sigma Spectrum','SN-FT-0012','Cardiac','8.2.0','DL-2026.1','2026-06-23T12:02:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Fortis','Mohali','BBraun Infusomat Space','SN-FT-0013','ICU-B','2.4.0','DL-2025.4','2026-05-15T14:00:00Z'::timestamptz,'stale','in_service','2026-Q2'),
('Fortis','Mohali','BBraun Infusomat Space','SN-FT-0014','ICU-B','2.4.0','DL-2025.4','2026-05-15T14:01:00Z'::timestamptz,'stale','in_service','2026-Q2'),
('Fortis','Noida','ICU Medical Plum 360','SN-FT-0015','OT-1','12.1.3','DL-2026.1','2026-06-24T08:00:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Max','Saket','BBraun Infusomat Space','SN-MX-0016','ICU-C','2.4.1','DL-2026.1','2026-06-25T09:30:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Max','Patparganj','Baxter Sigma Spectrum','SN-MX-0017','NICU','8.2.0','DL-2026.1','2026-06-25T09:31:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Max','Patparganj','Baxter Sigma Spectrum','SN-MX-0018','NICU',null,null,null,'offline','retired','2026-Q2'),
('Narayana','Bengaluru-HSR','Mindray BeneFusion','SN-NR-0019','Cardiac','5.1.0','DL-2026.1','2026-06-26T10:00:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Narayana','Bengaluru-HSR','Mindray BeneFusion','SN-NR-0020','Cardiac','5.1.0','DL-2025.4','2026-05-28T10:01:00Z'::timestamptz,'out_of_sync','in_service','2026-Q2'),
('Narayana','Kolkata','BBraun Perfusor Space','SN-NR-0021','Onco','3.0.2','DL-2026.1','2026-06-27T11:00:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Narayana','Kolkata','BBraun Perfusor Space','SN-NR-0022','Onco','3.0.1','DL-2025.4','2026-05-30T11:01:00Z'::timestamptz,'stale','in_service','2026-Q2'),
('Kokilaben','Mumbai','ICU Medical Plum 360','SN-KK-0023','ICU-D','12.1.3','DL-2026.1','2026-06-28T13:00:00Z'::timestamptz,'current','in_service','2026-Q2'),
('Kokilaben','Mumbai','ICU Medical Plum 360','SN-KK-0024','ICU-D','12.1.2','DL-2025.4','2026-04-22T13:01:00Z'::timestamptz,'quarantined','in_repair','2026-Q2');

insert into drug_library_sync_audit_r3023 (chain_name, hospital_site, library_version, approved_by_pharmacy, push_initiated_at, push_completed_at, pumps_targeted, pumps_synced, pumps_failed, variance_flag, remediation_status, quarter) values
('Apollo','Hyderabad-Jubilee','DL-2026.1','Dr. R. Iyer','2026-06-20T08:00:00Z'::timestamptz,'2026-06-20T08:45:00Z'::timestamptz,42,42,0,'none','closed','2026-Q2'),
('Apollo','Chennai-Greams','DL-2026.1','Dr. M. Krishnan','2026-06-21T08:00:00Z'::timestamptz,null,38,30,8,'severe','escalated','2026-Q2'),
('Apollo','Bengaluru-Bannerghatta','DL-2026.1','Dr. S. Pillai','2026-06-21T09:00:00Z'::timestamptz,'2026-06-21T09:30:00Z'::timestamptz,25,24,1,'minor','closed','2026-Q2'),
('Manipal','Bengaluru-Old Airport','DL-2026.1','Dr. A. Shenoy','2026-06-19T07:30:00Z'::timestamptz,'2026-06-19T08:10:00Z'::timestamptz,30,28,2,'moderate','in_progress','2026-Q2'),
('Manipal','Jaipur','DL-2026.1','Dr. K. Mehta','2026-06-22T05:30:00Z'::timestamptz,'2026-06-22T06:20:00Z'::timestamptz,18,17,1,'minor','closed','2026-Q2'),
('Manipal','Mangalore','DL-2026.1','Dr. P. Rao','2026-06-22T05:30:00Z'::timestamptz,null,22,15,7,'severe','escalated','2026-Q2'),
('Fortis','Gurugram','DL-2026.1','Dr. V. Khanna','2026-06-23T11:30:00Z'::timestamptz,'2026-06-23T12:15:00Z'::timestamptz,45,45,0,'none','closed','2026-Q2'),
('Fortis','Mohali','DL-2026.1','Dr. H. Sandhu','2026-06-23T11:30:00Z'::timestamptz,'2026-06-23T12:00:00Z'::timestamptz,28,25,3,'moderate','in_progress','2026-Q2'),
('Fortis','Noida','DL-2026.1','Dr. R. Bhatia','2026-06-24T07:30:00Z'::timestamptz,'2026-06-24T08:15:00Z'::timestamptz,33,33,0,'none','closed','2026-Q2'),
('Max','Saket','DL-2026.1','Dr. N. Verma','2026-06-25T09:00:00Z'::timestamptz,'2026-06-25T09:45:00Z'::timestamptz,40,39,1,'minor','closed','2026-Q2'),
('Max','Patparganj','DL-2026.1','Dr. S. Gupta','2026-06-25T09:00:00Z'::timestamptz,null,35,28,7,'severe','escalated','2026-Q2'),
('Narayana','Bengaluru-HSR','DL-2026.1','Dr. D. Reddy','2026-06-26T09:30:00Z'::timestamptz,'2026-06-26T10:15:00Z'::timestamptz,50,48,2,'moderate','in_progress','2026-Q2'),
('Narayana','Kolkata','DL-2026.1','Dr. B. Sen','2026-06-27T10:30:00Z'::timestamptz,'2026-06-27T11:20:00Z'::timestamptz,27,27,0,'none','closed','2026-Q2'),
('Kokilaben','Mumbai','DL-2026.1','Dr. F. Engineer','2026-06-28T12:30:00Z'::timestamptz,'2026-06-28T13:30:00Z'::timestamptz,32,30,2,'moderate','pending','2026-Q2'),
('Apollo','Hyderabad-Jubilee','DL-2025.4','Dr. R. Iyer','2026-03-15T08:00:00Z'::timestamptz,'2026-03-15T08:40:00Z'::timestamptz,40,40,0,'none','closed','2026-Q1'),
('Manipal','Jaipur','DL-2025.4','Dr. K. Mehta','2026-03-20T05:30:00Z'::timestamptz,'2026-03-20T06:00:00Z'::timestamptz,18,16,2,'moderate','closed','2026-Q1');

create or replace function inventory_overview_r3023()
returns table(chain_name text, pump_count bigint, current_sync int, stale int, out_of_sync int, offline int, quarantined int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select i.chain_name,
    count(*),
    (count(*) filter (where i.sync_status='current'))::int,
    (count(*) filter (where i.sync_status='stale'))::int,
    (count(*) filter (where i.sync_status='out_of_sync'))::int,
    (count(*) filter (where i.sync_status='offline'))::int,
    (count(*) filter (where i.sync_status='quarantined'))::int
  from infusion_pump_inventory_r3023 i
  group by i.chain_name
  order by i.chain_name;
end; $$;

create or replace function stale_pumps_r3023()
returns table(chain_name text, hospital_site text, pump_model text, pump_serial text, ward text, drug_library_version text, last_sync_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select i.chain_name, i.hospital_site, i.pump_model, i.pump_serial, i.ward, i.drug_library_version, i.last_sync_at
  from infusion_pump_inventory_r3023 i
  where i.sync_status in ('stale','out_of_sync','quarantined')
  order by i.last_sync_at nulls first;
end; $$;

create or replace function sync_audit_summary_r3023()
returns table(chain_name text, audits bigint, total_targeted bigint, total_synced bigint, total_failed bigint, sync_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.chain_name,
    count(*),
    sum(a.pumps_targeted)::bigint,
    sum(a.pumps_synced)::bigint,
    sum(a.pumps_failed)::bigint,
    round((sum(a.pumps_synced)::numeric / nullif(sum(a.pumps_targeted),0)) * 100, 2)
  from drug_library_sync_audit_r3023 a
  group by a.chain_name
  order by sync_rate_pct asc nulls last;
end; $$;

create or replace function severe_variance_sites_r3023()
returns table(chain_name text, hospital_site text, library_version text, pumps_targeted int, pumps_failed int, remediation_status text, push_initiated_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.chain_name, a.hospital_site, a.library_version, a.pumps_targeted, a.pumps_failed, a.remediation_status, a.push_initiated_at
  from drug_library_sync_audit_r3023 a
  where a.variance_flag in ('moderate','severe')
  order by a.pumps_failed desc;
end; $$;

create or replace function firmware_spread_r3023()
returns table(pump_model text, firmware_version text, units bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select coalesce(i.pump_model,'unknown'), coalesce(i.firmware_version,'(none)'), count(*)
  from infusion_pump_inventory_r3023 i
  group by i.pump_model, i.firmware_version
  order by i.pump_model, units desc;
end; $$;

create or replace function library_version_coverage_r3023()
returns table(drug_library_version text, units bigint, chains bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select coalesce(i.drug_library_version,'(none)'), count(*), count(distinct i.chain_name)
  from infusion_pump_inventory_r3023 i
  group by i.drug_library_version
  order by units desc;
end; $$;

create or replace function escalation_queue_r3023()
returns table(chain_name text, hospital_site text, library_version text, pumps_failed int, variance_flag text, push_initiated_at timestamptz, approved_by_pharmacy text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select a.chain_name, a.hospital_site, a.library_version, a.pumps_failed, a.variance_flag, a.push_initiated_at, a.approved_by_pharmacy
  from drug_library_sync_audit_r3023 a
  where a.remediation_status in ('pending','escalated','in_progress')
  order by case a.remediation_status when 'escalated' then 0 when 'pending' then 1 else 2 end, a.pumps_failed desc;
end; $$;

revoke all on infusion_pump_inventory_r3023 from public, anon;
revoke all on drug_library_sync_audit_r3023 from public, anon;
grant select, insert, update, delete on infusion_pump_inventory_r3023 to authenticated;
grant select, insert, update, delete on drug_library_sync_audit_r3023 to authenticated;

revoke all on function inventory_overview_r3023() from public, anon;
revoke all on function stale_pumps_r3023() from public, anon;
revoke all on function sync_audit_summary_r3023() from public, anon;
revoke all on function severe_variance_sites_r3023() from public, anon;
revoke all on function firmware_spread_r3023() from public, anon;
revoke all on function library_version_coverage_r3023() from public, anon;
revoke all on function escalation_queue_r3023() from public, anon;

grant execute on function inventory_overview_r3023() to authenticated;
grant execute on function stale_pumps_r3023() to authenticated;
grant execute on function sync_audit_summary_r3023() to authenticated;
grant execute on function severe_variance_sites_r3023() to authenticated;
grant execute on function firmware_spread_r3023() to authenticated;
grant execute on function library_version_coverage_r3023() to authenticated;
grant execute on function escalation_queue_r3023() to authenticated;
