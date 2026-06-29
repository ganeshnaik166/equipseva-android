-- Round 2959 — Hospital Chain Quarterly Equipment Software EULA & Open-Source Compliance Audit
-- HEAVY ★★★★

create table if not exists hospital_chain_eula_audits_r2959 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_code text not null,
  chain_name text not null,
  quarter text not null,
  audit_status text not null check (audit_status in ('scheduled','in_progress','completed','flagged','remediation','closed')),
  equipment_units_in_scope int not null default 0,
  eula_versions_reviewed int not null default 0,
  oss_components_identified int not null default 0,
  license_violations_found int not null default 0,
  risk_score numeric(5,2) not null default 0,
  legal_owner text not null,
  audit_started_on date not null,
  audit_completed_on date,
  next_review_due date not null,
  notes text
);

create table if not exists hospital_chain_eula_findings_r2959 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references hospital_chain_eula_audits_r2959(id) on delete cascade,
  equipment_serial text not null,
  equipment_make text not null,
  software_component text not null,
  license_family text not null check (license_family in ('proprietary_eula','gpl_v2','gpl_v3','lgpl','agpl','mit','apache_2','bsd_3','mpl','cc_by_sa','unknown')),
  finding_type text not null check (finding_type in ('missing_attribution','copyleft_violation','expired_eula','indemnity_gap','export_control','source_disclosure_missing','no_finding')),
  severity text not null check (severity in ('p0','p1','p2','p3','info')),
  remediation_status text not null check (remediation_status in ('open','triaged','vendor_contacted','patched','accepted_risk','closed')),
  remediation_owner text not null,
  remediation_due date not null,
  remediation_cost_rupees bigint not null default 0
);

alter table hospital_chain_eula_audits_r2959 enable row level security;
alter table hospital_chain_eula_findings_r2959 enable row level security;

drop policy if exists eula_audits_select_r2959 on hospital_chain_eula_audits_r2959;
create policy eula_audits_select_r2959 on hospital_chain_eula_audits_r2959 for select using (is_founder());

drop policy if exists eula_findings_select_r2959 on hospital_chain_eula_findings_r2959;
create policy eula_findings_select_r2959 on hospital_chain_eula_findings_r2959 for select using (is_founder());

revoke all on hospital_chain_eula_audits_r2959 from public, anon;
revoke all on hospital_chain_eula_findings_r2959 from public, anon;
grant select on hospital_chain_eula_audits_r2959 to authenticated;
grant select on hospital_chain_eula_findings_r2959 to authenticated;

-- Seed audits (16 rows)
insert into hospital_chain_eula_audits_r2959 (chain_code, chain_name, quarter, audit_status, equipment_units_in_scope, eula_versions_reviewed, oss_components_identified, license_violations_found, risk_score, legal_owner, audit_started_on, audit_completed_on, next_review_due, notes) values
('APLO','Apollo Hospitals','2026-Q2','completed',412,38,127,4,18.40,'Priya Menon','2026-04-01'::date,'2026-04-22'::date,'2026-07-01'::date,'Clean except 4 GPL attribution gaps'),
('FORT','Fortis Healthcare','2026-Q2','flagged',287,29,98,11,42.10,'Rohit Kapoor','2026-04-03'::date,'2026-04-28'::date,'2026-07-03'::date,'AGPL embedded in radiology console'),
('MAXH','Max Healthcare','2026-Q2','remediation',198,22,76,7,31.20,'Sneha Iyer','2026-04-05'::date,'2026-05-02'::date,'2026-07-05'::date,'Source disclosure pending from vendor'),
('MANI','Manipal Hospitals','2026-Q2','completed',342,33,112,2,12.80,'Vikram Rao','2026-04-08'::date,'2026-04-30'::date,'2026-07-08'::date,'Strong baseline'),
('NARA','Narayana Health','2026-Q2','completed',256,27,89,3,16.50,'Anand Kumar','2026-04-10'::date,'2026-05-05'::date,'2026-07-10'::date,'Cardiac MRI EULA renewed'),
('KIMS','KIMS Hospitals','2026-Q2','in_progress',178,18,64,5,26.30,'Lakshmi Devi','2026-04-12'::date,null,'2026-07-12'::date,'Hyderabad sites pending'),
('YASH','Yashoda Hospitals','2026-Q2','flagged',145,16,58,9,38.70,'Suresh Reddy','2026-04-14'::date,'2026-05-10'::date,'2026-07-14'::date,'Two p1 copyleft violations'),
('AIIM','AIIMS Delhi','2026-Q2','completed',389,42,134,1,8.20,'Dr Mehta','2026-04-15'::date,'2026-05-12'::date,'2026-07-15'::date,'Government baseline excellent'),
('CMC','CMC Vellore','2026-Q2','completed',267,28,92,3,15.40,'Dr Thomas','2026-04-16'::date,'2026-05-08'::date,'2026-07-16'::date,'Academic licensing reviewed'),
('TATA','Tata Memorial','2026-Q2','remediation',201,24,81,6,29.10,'Ramesh Pillai','2026-04-18'::date,'2026-05-14'::date,'2026-07-18'::date,'Linear accelerator firmware OSS'),
('MEDA','Medanta','2026-Q2','scheduled',312,0,0,0,0.00,'Kavita Singh','2026-06-01'::date,null,'2026-09-01'::date,'Q3 cycle starting'),
('ARTM','Artemis Hospitals','2026-Q2','in_progress',156,14,52,4,22.80,'Pooja Sharma','2026-04-20'::date,null,'2026-07-20'::date,'Gurgaon scan in progress'),
('CLBL','Columbia Asia','2026-Q2','completed',124,18,68,2,11.60,'Arjun Nair','2026-04-22'::date,'2026-05-15'::date,'2026-07-22'::date,'Bangalore consolidated'),
('GLBH','Global Health','2026-Q2','flagged',98,12,44,8,35.90,'Deepika Bose','2026-04-25'::date,'2026-05-18'::date,'2026-07-25'::date,'AGPL violation in PACS'),
('RGCI','Rajiv Gandhi Cancer','2026-Q2','closed',87,15,51,0,7.40,'Dr Saxena','2026-04-26'::date,'2026-05-20'::date,'2026-07-26'::date,'Best-in-class audit'),
('SHKR','Shankar Netralaya','2026-Q2','completed',64,9,38,1,9.80,'Dr Krishnan','2026-04-28'::date,'2026-05-22'::date,'2026-07-28'::date,'Ophthalmology niche');

-- Seed findings (22 rows)
insert into hospital_chain_eula_findings_r2959 (audit_id, equipment_serial, equipment_make, software_component, license_family, finding_type, severity, remediation_status, remediation_owner, remediation_due, remediation_cost_rupees)
select a.id, v.serial, v.make, v.comp, v.lic, v.ft, v.sev, v.rem, v.own, v.due, v.cost
from hospital_chain_eula_audits_r2959 a
join (values
  ('APLO','GE-MRI-7741','GE Healthcare','BusyBox userland','gpl_v2','missing_attribution','p2','closed','Priya Menon','2026-05-15'::date,45000::bigint),
  ('APLO','SI-CT-2293','Siemens','OpenSSL stack','apache_2','no_finding','info','closed','Priya Menon','2026-05-20'::date,0::bigint),
  ('APLO','PH-USG-1140','Philips','glibc','lgpl','missing_attribution','p3','closed','Priya Menon','2026-05-22'::date,12000::bigint),
  ('APLO','MN-VTL-3387','Mindray','linux-kernel-4.19','gpl_v2','source_disclosure_missing','p1','closed','Priya Menon','2026-05-25'::date,180000::bigint),
  ('FORT','SI-MRI-5521','Siemens','ffmpeg-x264','gpl_v3','copyleft_violation','p0','vendor_contacted','Rohit Kapoor','2026-06-15'::date,950000::bigint),
  ('FORT','GE-XR-8812','GE Healthcare','MongoDB community','agpl','copyleft_violation','p0','triaged','Rohit Kapoor','2026-06-20'::date,750000::bigint),
  ('FORT','PH-MON-9923','Philips','redis','bsd_3','no_finding','info','closed','Rohit Kapoor','2026-06-01'::date,0::bigint),
  ('FORT','CR-ECG-4456','Carestream','expired-eula-2024','proprietary_eula','expired_eula','p1','patched','Rohit Kapoor','2026-06-10'::date,225000::bigint),
  ('MAXH','MN-DEF-7788','Mindray','linux-kernel-5.4','gpl_v2','source_disclosure_missing','p1','vendor_contacted','Sneha Iyer','2026-06-25'::date,140000::bigint),
  ('MAXH','SI-PET-1102','Siemens','indemnity-clause-gap','proprietary_eula','indemnity_gap','p2','triaged','Sneha Iyer','2026-06-28'::date,85000::bigint),
  ('MANI','GE-ANE-3340','GE Healthcare','BusyBox','gpl_v2','missing_attribution','p3','closed','Vikram Rao','2026-05-30'::date,8000::bigint),
  ('NARA','PH-CMR-5567','Philips','OpenCV','apache_2','no_finding','info','closed','Anand Kumar','2026-05-28'::date,0::bigint),
  ('NARA','MN-VTL-8891','Mindray','zlib','mit','no_finding','info','closed','Anand Kumar','2026-05-29'::date,0::bigint),
  ('KIMS','SI-CT-2244','Siemens','export-control-china','proprietary_eula','export_control','p1','open','Lakshmi Devi','2026-07-05'::date,0::bigint),
  ('YASH','GE-MRI-9981','GE Healthcare','ffmpeg-libav','lgpl','copyleft_violation','p1','triaged','Suresh Reddy','2026-07-10'::date,420000::bigint),
  ('YASH','MN-INF-3320','Mindray','curl','mit','missing_attribution','p3','patched','Suresh Reddy','2026-06-15'::date,5000::bigint),
  ('AIIM','SI-LIN-7740','Siemens','custom-firmware','proprietary_eula','no_finding','info','closed','Dr Mehta','2026-06-01'::date,0::bigint),
  ('CMC','PH-USG-4451','Philips','linux-yocto','gpl_v2','missing_attribution','p3','closed','Dr Thomas','2026-06-05'::date,15000::bigint),
  ('TATA','VRN-LIN-2298','Varian','tensorflow-lite','apache_2','indemnity_gap','p2','vendor_contacted','Ramesh Pillai','2026-07-12'::date,95000::bigint),
  ('GLBH','GE-PAC-6678','GE Healthcare','postgres-agpl-fork','agpl','copyleft_violation','p0','open','Deepika Bose','2026-07-18'::date,850000::bigint),
  ('GLBH','SI-RAD-1198','Siemens','imagemagick','mpl','source_disclosure_missing','p1','triaged','Deepika Bose','2026-07-22'::date,320000::bigint),
  ('CLBL','PH-VENT-8843','Philips','newlib','bsd_3','no_finding','info','closed','Arjun Nair','2026-06-10'::date,0::bigint)
) v(chain, serial, make, comp, lic, ft, sev, rem, own, due, cost) on v.chain = a.chain_code
where a.quarter = '2026-Q2';

-- RPCs
create or replace function rpc_r2959_audit_overview()
returns table(chain_code text, chain_name text, audit_status text, units int, violations int, risk numeric, next_review date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.chain_code, a.chain_name, a.audit_status, a.equipment_units_in_scope, a.license_violations_found, a.risk_score, a.next_review_due
    from hospital_chain_eula_audits_r2959 a order by a.risk_score desc;
end $$;

create or replace function rpc_r2959_status_breakdown()
returns table(audit_status text, chain_count int, total_units int, total_violations int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.audit_status, count(*)::int, sum(a.equipment_units_in_scope)::int, sum(a.license_violations_found)::int
    from hospital_chain_eula_audits_r2959 a group by a.audit_status order by count(*) desc;
end $$;

create or replace function rpc_r2959_license_family_exposure()
returns table(license_family text, finding_count int, p0_count int, p1_count int, copyleft_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.license_family,
    count(*)::int,
    (count(*) filter (where f.severity = 'p0'))::int,
    (count(*) filter (where f.severity = 'p1'))::int,
    (count(*) filter (where f.finding_type = 'copyleft_violation'))::int
    from hospital_chain_eula_findings_r2959 f group by f.license_family order by count(*) desc;
end $$;

create or replace function rpc_r2959_open_findings()
returns table(chain_code text, equipment_serial text, software_component text, license_family text, severity text, remediation_status text, due date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.chain_code, f.equipment_serial, f.software_component, f.license_family, f.severity, f.remediation_status, f.remediation_due
    from hospital_chain_eula_findings_r2959 f
    join hospital_chain_eula_audits_r2959 a on a.id = f.audit_id
    where f.remediation_status in ('open','triaged','vendor_contacted')
    order by f.severity, f.remediation_due;
end $$;

create or replace function rpc_r2959_severity_pyramid()
returns table(severity text, count_total int, copyleft_share int, oss_share int, cost_rupees bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select f.severity,
    count(*)::int,
    (count(*) filter (where f.finding_type = 'copyleft_violation'))::int,
    (count(*) filter (where f.license_family in ('gpl_v2','gpl_v3','lgpl','agpl','mpl')))::int,
    coalesce(sum(f.remediation_cost_rupees),0)::bigint
    from hospital_chain_eula_findings_r2959 f group by f.severity order by f.severity;
end $$;

create or replace function rpc_r2959_remediation_cost_by_chain()
returns table(chain_code text, chain_name text, open_findings int, total_cost_rupees bigint, max_severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.chain_code, a.chain_name,
    (count(*) filter (where f.remediation_status not in ('closed','accepted_risk')))::int,
    coalesce(sum(f.remediation_cost_rupees),0)::bigint,
    min(f.severity)
    from hospital_chain_eula_audits_r2959 a
    left join hospital_chain_eula_findings_r2959 f on f.audit_id = a.id
    group by a.chain_code, a.chain_name order by sum(f.remediation_cost_rupees) desc nulls last;
end $$;

create or replace function rpc_r2959_upcoming_reviews()
returns table(chain_code text, chain_name text, next_review_due date, days_until int, audit_status text, legal_owner text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query select a.chain_code, a.chain_name, a.next_review_due,
    (a.next_review_due - current_date)::int, a.audit_status, a.legal_owner
    from hospital_chain_eula_audits_r2959 a
    where a.next_review_due >= current_date - 30
    order by a.next_review_due;
end $$;

revoke all on function rpc_r2959_audit_overview() from public, anon;
revoke all on function rpc_r2959_status_breakdown() from public, anon;
revoke all on function rpc_r2959_license_family_exposure() from public, anon;
revoke all on function rpc_r2959_open_findings() from public, anon;
revoke all on function rpc_r2959_severity_pyramid() from public, anon;
revoke all on function rpc_r2959_remediation_cost_by_chain() from public, anon;
revoke all on function rpc_r2959_upcoming_reviews() from public, anon;

grant execute on function rpc_r2959_audit_overview() to authenticated;
grant execute on function rpc_r2959_status_breakdown() to authenticated;
grant execute on function rpc_r2959_license_family_exposure() to authenticated;
grant execute on function rpc_r2959_open_findings() to authenticated;
grant execute on function rpc_r2959_severity_pyramid() to authenticated;
grant execute on function rpc_r2959_remediation_cost_by_chain() to authenticated;
grant execute on function rpc_r2959_upcoming_reviews() to authenticated;
