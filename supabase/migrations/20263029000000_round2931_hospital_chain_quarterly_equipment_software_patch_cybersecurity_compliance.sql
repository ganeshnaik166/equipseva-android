-- Round 2931: Hospital Chain Quarterly Equipment Software-Patch & Cybersecurity Compliance
-- HEAVY ★★★★ · 1500/50 milestone crossing batch

create table if not exists hospital_chain_patch_cycles_r2931 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  chain_name text not null,
  quarter_label text not null,
  cycle_start_date date not null,
  cycle_end_date date not null,
  total_devices int not null default 0,
  patched_devices int not null default 0,
  critical_cves_open int not null default 0,
  compliance_status text not null check (compliance_status in ('compliant','at_risk','non_compliant','overdue')),
  sla_hours_remaining int not null default 0,
  cyber_score numeric(5,2) not null default 0,
  owner_email text
);

create table if not exists hospital_chain_patch_devices_r2931 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  cycle_id uuid references hospital_chain_patch_cycles_r2931(id) on delete cascade,
  device_model text not null,
  serial_no text not null,
  os_version text not null,
  required_patch_version text not null,
  current_patch_version text not null,
  patch_state text not null check (patch_state in ('pending','scheduled','in_progress','patched','failed','rolled_back')),
  cve_count int not null default 0,
  severity text not null check (severity in ('p0','p1','p2','p3')),
  last_scanned_at timestamptz not null default now()::timestamptz,
  next_window_at timestamptz
);

alter table hospital_chain_patch_cycles_r2931 enable row level security;
alter table hospital_chain_patch_devices_r2931 enable row level security;

-- Seed cycles (15 rows)
insert into hospital_chain_patch_cycles_r2931 (chain_name, quarter_label, cycle_start_date, cycle_end_date, total_devices, patched_devices, critical_cves_open, compliance_status, sla_hours_remaining, cyber_score, owner_email) values
('Apollo Hospitals','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,420,398,2,'compliant',312,94.5,'cio@apollo.example'),
('Fortis Healthcare','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,312,260,8,'at_risk',96,78.2,'security@fortis.example'),
('Manipal Hospitals','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,265,265,0,'compliant',720,99.1,'patch@manipal.example'),
('Max Healthcare','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,198,142,14,'non_compliant',0,52.8,'cyber@max.example'),
('Narayana Health','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,340,329,3,'compliant',240,91.7,'it@narayana.example'),
('AIIMS Delhi','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,512,480,5,'at_risk',168,84.3,'patch@aiims.example'),
('KIMS Hyderabad','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,178,178,0,'compliant',840,98.5,'cio@kims.example'),
('Yashoda Hospitals','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,225,201,4,'at_risk',120,81.4,'security@yashoda.example'),
('Continental Hospitals','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,140,98,11,'non_compliant',0,48.6,'it@continental.example'),
('Rainbow Childrens','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,165,165,0,'compliant',600,97.2,'cio@rainbow.example'),
('Medanta','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,288,272,2,'compliant',432,93.1,'cyber@medanta.example'),
('Columbia Asia','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,212,188,6,'at_risk',72,76.9,'patch@columbia.example'),
('SevenHills','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,156,89,18,'overdue',0,38.2,'admin@sevenhills.example'),
('Kokilaben Ambani','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,310,305,1,'compliant',480,95.8,'cio@kokilaben.example'),
('Lilavati Hospital','Q2 FY26','2026-04-01'::date,'2026-06-30'::date,178,156,5,'at_risk',144,79.5,'it@lilavati.example');

-- Seed devices (24 rows)
insert into hospital_chain_patch_devices_r2931 (cycle_id, device_model, serial_no, os_version, required_patch_version, current_patch_version, patch_state, cve_count, severity, last_scanned_at, next_window_at)
select c.id, m.model, m.serial, m.os_v, m.req_v, m.cur_v, m.state, m.cves, m.sev, '2026-06-20T08:00:00Z'::timestamptz, m.win
from hospital_chain_patch_cycles_r2931 c
cross join lateral (values
  ('GE Vivid E95','VE95-001','VxWorks 7.0','7.0.3-p12','7.0.3-p12','patched',0,'p3','2026-07-05T02:00:00Z'::timestamptz),
  ('Philips IntelliVue MX800','MX800-014','Linux 4.19','4.19.244','4.19.230','pending',7,'p1','2026-06-25T01:00:00Z'::timestamptz),
  ('Siemens Magnetom Aera','MAG-A22','Syngo VE11','VE11C-SP3','VE11C-SP2','scheduled',3,'p2','2026-06-28T03:00:00Z'::timestamptz),
  ('Mindray BeneVision N17','BV-N17-08','Linux 5.10','5.10.180','5.10.140','failed',12,'p0','2026-06-22T00:00:00Z'::timestamptz),
  ('Dragerwerk Evita V600','EV600-03','VxWorks 6.9','6.9.4-p8','6.9.4-p8','patched',0,'p3','2026-09-01T02:00:00Z'::timestamptz),
  ('Hologic Selenia 3Dimensions','HOL-3D-11','Windows 10 IoT','22H2-KB5034441','22H2-KB5034441','patched',0,'p3','2026-08-15T04:00:00Z'::timestamptz),
  ('Stryker Vocera B3000','VOC-B3-44','Linux 4.14','4.14.330','4.14.290','in_progress',5,'p1','2026-06-23T02:00:00Z'::timestamptz),
  ('Olympus CV-1500','CV1500-07','Windows 7 Embedded','SP1-KB4534314','SP1-KB4534314','rolled_back',9,'p0','2026-06-21T01:00:00Z'::timestamptz)
) m(model, serial, os_v, req_v, cur_v, state, cves, sev, win)
where c.chain_name in ('Apollo Hospitals','Fortis Healthcare','Manipal Hospitals')
limit 24;

create or replace function r2931_summary()
returns table(total_cycles bigint, compliant bigint, at_risk bigint, non_compliant bigint, overdue bigint, avg_cyber_score numeric, total_devices bigint, patched bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select
    count(*),
    (count(*) filter (where compliance_status='compliant'))::bigint,
    (count(*) filter (where compliance_status='at_risk'))::bigint,
    (count(*) filter (where compliance_status='non_compliant'))::bigint,
    (count(*) filter (where compliance_status='overdue'))::bigint,
    round(avg(cyber_score),2),
    sum(total_devices)::bigint,
    sum(patched_devices)::bigint
  from hospital_chain_patch_cycles_r2931;
end$$;

create or replace function r2931_cycles_by_status()
returns table(compliance_status text, n bigint, devices bigint, open_cves bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.compliance_status, count(*), sum(c.total_devices)::bigint, sum(c.critical_cves_open)::bigint
  from hospital_chain_patch_cycles_r2931 c group by c.compliance_status order by 2 desc;
end$$;

create or replace function r2931_top_risk_chains()
returns table(chain_name text, cyber_score numeric, critical_cves_open int, sla_hours_remaining int, compliance_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.chain_name, c.cyber_score, c.critical_cves_open, c.sla_hours_remaining, c.compliance_status
  from hospital_chain_patch_cycles_r2931 c order by c.cyber_score asc limit 10;
end$$;

create or replace function r2931_device_state_mix()
returns table(patch_state text, n bigint, total_cves bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select d.patch_state, count(*), sum(d.cve_count)::bigint
  from hospital_chain_patch_devices_r2931 d group by d.patch_state order by 2 desc;
end$$;

create or replace function r2931_severity_breakdown()
returns table(severity text, n bigint, avg_cves numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select d.severity, count(*), round(avg(d.cve_count),2)
  from hospital_chain_patch_devices_r2931 d group by d.severity order by 1 asc;
end$$;

create or replace function r2931_sla_burn_list()
returns table(chain_name text, sla_hours_remaining int, critical_cves_open int, compliance_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.chain_name, c.sla_hours_remaining, c.critical_cves_open, c.compliance_status
  from hospital_chain_patch_cycles_r2931 c
  where c.sla_hours_remaining <= 168 order by c.sla_hours_remaining asc;
end$$;

create or replace function r2931_failed_devices()
returns table(device_model text, serial_no text, os_version text, current_patch_version text, required_patch_version text, cve_count int, severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select d.device_model, d.serial_no, d.os_version, d.current_patch_version, d.required_patch_version, d.cve_count, d.severity
  from hospital_chain_patch_devices_r2931 d
  where d.patch_state in ('failed','rolled_back','pending') order by d.cve_count desc;
end$$;

create or replace function r2931_patch_coverage()
returns table(chain_name text, total_devices int, patched_devices int, coverage_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select c.chain_name, c.total_devices, c.patched_devices,
    case when c.total_devices=0 then 0::numeric else round(c.patched_devices::numeric/c.total_devices*100,2) end
  from hospital_chain_patch_cycles_r2931 c order by 4 asc;
end$$;

revoke execute on function r2931_summary() from public, anon;
revoke execute on function r2931_cycles_by_status() from public, anon;
revoke execute on function r2931_top_risk_chains() from public, anon;
revoke execute on function r2931_device_state_mix() from public, anon;
revoke execute on function r2931_severity_breakdown() from public, anon;
revoke execute on function r2931_sla_burn_list() from public, anon;
revoke execute on function r2931_failed_devices() from public, anon;
revoke execute on function r2931_patch_coverage() from public, anon;

grant execute on function r2931_summary() to authenticated;
grant execute on function r2931_cycles_by_status() to authenticated;
grant execute on function r2931_top_risk_chains() to authenticated;
grant execute on function r2931_device_state_mix() to authenticated;
grant execute on function r2931_severity_breakdown() to authenticated;
grant execute on function r2931_sla_burn_list() to authenticated;
grant execute on function r2931_failed_devices() to authenticated;
grant execute on function r2931_patch_coverage() to authenticated;
