-- Round 3084 — Customer Monthly Engineer Hospital Patient Identity Wristband Scanner-Decode Compliance

create table if not exists patient_id_wristband_scans_r3084 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_org_id uuid,
  engineer_id uuid,
  scanned_at timestamptz not null,
  wristband_code text not null,
  decode_status text not null check (decode_status in ('decoded','partial','failed','expired','tampered')),
  ward_label text,
  device_model text,
  scan_month date not null,
  ms_to_decode int,
  compliance_state text not null check (compliance_state in ('compliant','warn','non_compliant','review'))
);
alter table patient_id_wristband_scans_r3084 enable row level security;
drop policy if exists wbs_r3084_founder on patient_id_wristband_scans_r3084;
create policy wbs_r3084_founder on patient_id_wristband_scans_r3084 for select using (is_founder());

create table if not exists patient_id_wristband_compliance_findings_r3084 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  hospital_org_id uuid,
  engineer_id uuid,
  finding_month date not null,
  finding_type text not null check (finding_type in ('expired_band','duplicate_id','illegible','missing_band','wrong_patient','tamper')),
  severity text not null check (severity in ('low','medium','high','critical')),
  resolution_state text not null check (resolution_state in ('open','acknowledged','resolved','escalated')),
  detected_at timestamptz,
  resolved_at timestamptz,
  notes text
);
alter table patient_id_wristband_compliance_findings_r3084 enable row level security;
drop policy if exists wbc_r3084_founder on patient_id_wristband_compliance_findings_r3084;
create policy wbc_r3084_founder on patient_id_wristband_compliance_findings_r3084 for select using (is_founder());

insert into patient_id_wristband_scans_r3084 (scanned_at, wristband_code, decode_status, ward_label, device_model, scan_month, ms_to_decode, compliance_state) values
  ('2026-06-01 08:12:00+05:30'::timestamptz,'WB-0001','decoded','ICU-1','Zebra DS2208','2026-06-01'::date,140,'compliant'),
  ('2026-06-02 09:22:00+05:30'::timestamptz,'WB-0002','decoded','ICU-2','Zebra DS2208','2026-06-01'::date,165,'compliant'),
  ('2026-06-03 10:01:00+05:30'::timestamptz,'WB-0003','partial','ER','Honeywell CT40','2026-06-01'::date,820,'warn'),
  ('2026-06-04 11:33:00+05:30'::timestamptz,'WB-0004','failed','OPD','Honeywell CT40','2026-06-01'::date,null,'non_compliant'),
  ('2026-06-05 12:45:00+05:30'::timestamptz,'WB-0005','decoded','Ward-A','Zebra TC52','2026-06-01'::date,195,'compliant'),
  ('2026-06-06 13:50:00+05:30'::timestamptz,'WB-0006','expired','Ward-B','Zebra TC52','2026-06-01'::date,210,'non_compliant'),
  ('2026-06-07 14:55:00+05:30'::timestamptz,'WB-0007','decoded','Ward-C','Datalogic Memor','2026-06-01'::date,180,'compliant'),
  ('2026-06-08 15:30:00+05:30'::timestamptz,'WB-0008','tampered','ICU-3','Zebra DS2208','2026-06-01'::date,null,'non_compliant'),
  ('2026-06-09 16:10:00+05:30'::timestamptz,'WB-0009','decoded','Ward-D','Zebra TC52','2026-06-01'::date,205,'compliant'),
  ('2026-06-10 17:25:00+05:30'::timestamptz,'WB-0010','decoded','OPD','Honeywell CT40','2026-06-01'::date,175,'compliant'),
  ('2026-06-11 08:15:00+05:30'::timestamptz,'WB-0011','partial','ER','Honeywell CT40','2026-06-01'::date,720,'warn'),
  ('2026-06-12 09:30:00+05:30'::timestamptz,'WB-0012','decoded','ICU-1','Zebra DS2208','2026-06-01'::date,150,'compliant'),
  ('2026-06-13 10:42:00+05:30'::timestamptz,'WB-0013','decoded','Ward-A','Zebra TC52','2026-06-01'::date,160,'compliant'),
  ('2026-06-14 11:55:00+05:30'::timestamptz,'WB-0014','failed','Ward-B','Datalogic Memor','2026-06-01'::date,null,'review'),
  ('2026-06-15 12:10:00+05:30'::timestamptz,'WB-0015','decoded','Ward-C','Zebra TC52','2026-06-01'::date,190,'compliant'),
  ('2026-06-16 13:18:00+05:30'::timestamptz,'WB-0016','decoded','ICU-2','Zebra DS2208','2026-06-01'::date,170,'compliant'),
  ('2026-06-17 14:30:00+05:30'::timestamptz,'WB-0017','expired','Ward-D','Honeywell CT40','2026-06-01'::date,230,'warn'),
  ('2026-06-18 15:45:00+05:30'::timestamptz,'WB-0018','decoded','OPD','Honeywell CT40','2026-06-01'::date,185,'compliant');

insert into patient_id_wristband_compliance_findings_r3084 (finding_month, finding_type, severity, resolution_state, detected_at, resolved_at, notes) values
  ('2026-06-01'::date,'expired_band','medium','resolved','2026-06-02 08:00:00+05:30'::timestamptz,'2026-06-02 12:00:00+05:30'::timestamptz,'Reissued band'),
  ('2026-06-01'::date,'duplicate_id','high','escalated','2026-06-03 09:30:00+05:30'::timestamptz,null,'Two patients share ID'),
  ('2026-06-01'::date,'illegible','low','resolved','2026-06-04 10:15:00+05:30'::timestamptz,'2026-06-04 11:00:00+05:30'::timestamptz,'Reprint OK'),
  ('2026-06-01'::date,'missing_band','high','acknowledged','2026-06-05 11:20:00+05:30'::timestamptz,null,'ER admission gap'),
  ('2026-06-01'::date,'wrong_patient','critical','escalated','2026-06-06 12:40:00+05:30'::timestamptz,null,'Near-miss medication'),
  ('2026-06-01'::date,'tamper','critical','open','2026-06-07 14:00:00+05:30'::timestamptz,null,'Band cut and re-glued'),
  ('2026-06-01'::date,'expired_band','medium','resolved','2026-06-08 15:10:00+05:30'::timestamptz,'2026-06-08 16:30:00+05:30'::timestamptz,'OPD batch reissue'),
  ('2026-06-01'::date,'illegible','low','resolved','2026-06-09 16:25:00+05:30'::timestamptz,'2026-06-09 17:00:00+05:30'::timestamptz,'Ribbon swap'),
  ('2026-06-01'::date,'duplicate_id','high','resolved','2026-06-10 09:50:00+05:30'::timestamptz,'2026-06-10 14:00:00+05:30'::timestamptz,'Reassigned MRN'),
  ('2026-06-01'::date,'missing_band','medium','acknowledged','2026-06-11 10:30:00+05:30'::timestamptz,null,'Ward transfer slip'),
  ('2026-06-01'::date,'expired_band','low','resolved','2026-06-12 11:00:00+05:30'::timestamptz,'2026-06-12 12:00:00+05:30'::timestamptz,'Standard reissue'),
  ('2026-06-01'::date,'tamper','high','escalated','2026-06-13 13:00:00+05:30'::timestamptz,null,'Suspected ID swap'),
  ('2026-06-01'::date,'wrong_patient','high','resolved','2026-06-14 14:20:00+05:30'::timestamptz,'2026-06-14 18:00:00+05:30'::timestamptz,'Caught at scan'),
  ('2026-06-01'::date,'illegible','low','open','2026-06-15 15:35:00+05:30'::timestamptz,null,'Printer fade');

create or replace function founder_r3084_monthly_scan_volume()
returns table(scan_month date, total_scans int, decoded int, failed int, tampered int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.scan_month,
      count(*)::int,
      (count(*) filter (where s.decode_status='decoded'))::int,
      (count(*) filter (where s.decode_status='failed'))::int,
      (count(*) filter (where s.decode_status='tampered'))::int
    from patient_id_wristband_scans_r3084 s
    group by s.scan_month order by s.scan_month;
end$$;

create or replace function founder_r3084_decode_status_breakdown()
returns table(decode_status text, n int, avg_ms numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.decode_status, count(*)::int, round(avg(s.ms_to_decode)::numeric,1)
    from patient_id_wristband_scans_r3084 s
    group by s.decode_status order by s.decode_status;
end$$;

create or replace function founder_r3084_compliance_state_mix()
returns table(compliance_state text, n int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.compliance_state, count(*)::int
    from patient_id_wristband_scans_r3084 s
    group by s.compliance_state order by s.compliance_state;
end$$;

create or replace function founder_r3084_ward_performance()
returns table(ward_label text, scans int, non_compliant int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(s.ward_label,'unknown'), count(*)::int,
      (count(*) filter (where s.compliance_state='non_compliant'))::int
    from patient_id_wristband_scans_r3084 s
    group by s.ward_label order by 2 desc;
end$$;

create or replace function founder_r3084_device_decode_speed()
returns table(device_model text, scans int, avg_ms numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select coalesce(s.device_model,'unknown'), count(*)::int,
      round(avg(s.ms_to_decode)::numeric,1)
    from patient_id_wristband_scans_r3084 s
    group by s.device_model order by 2 desc;
end$$;

create or replace function founder_r3084_finding_severity_mix()
returns table(severity text, n int, open_n int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.severity, count(*)::int,
      (count(*) filter (where f.resolution_state in ('open','acknowledged','escalated')))::int
    from patient_id_wristband_compliance_findings_r3084 f
    group by f.severity order by f.severity;
end$$;

create or replace function founder_r3084_open_findings()
returns table(finding_type text, severity text, resolution_state text, notes text, detected_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select f.finding_type, f.severity, f.resolution_state, f.notes, f.detected_at
    from patient_id_wristband_compliance_findings_r3084 f
    where f.resolution_state in ('open','acknowledged','escalated')
    order by f.detected_at desc;
end$$;

revoke all on function founder_r3084_monthly_scan_volume() from public, anon;
revoke all on function founder_r3084_decode_status_breakdown() from public, anon;
revoke all on function founder_r3084_compliance_state_mix() from public, anon;
revoke all on function founder_r3084_ward_performance() from public, anon;
revoke all on function founder_r3084_device_decode_speed() from public, anon;
revoke all on function founder_r3084_finding_severity_mix() from public, anon;
revoke all on function founder_r3084_open_findings() from public, anon;

grant execute on function founder_r3084_monthly_scan_volume() to authenticated;
grant execute on function founder_r3084_decode_status_breakdown() to authenticated;
grant execute on function founder_r3084_compliance_state_mix() to authenticated;
grant execute on function founder_r3084_ward_performance() to authenticated;
grant execute on function founder_r3084_device_decode_speed() to authenticated;
grant execute on function founder_r3084_finding_severity_mix() to authenticated;
grant execute on function founder_r3084_open_findings() to authenticated;
