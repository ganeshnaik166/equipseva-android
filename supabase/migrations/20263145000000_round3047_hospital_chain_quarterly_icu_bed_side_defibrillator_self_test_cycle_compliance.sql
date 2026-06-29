-- Round 3047 — Hospital Chain Quarterly ICU Bed-Side Defibrillator Self-Test Cycle Compliance
-- Two tables tracking quarterly self-test cycles for ICU bed-side defibrillators across hospital chains
-- plus seven founder-gated RPCs surfacing fleet compliance metrics.

create table if not exists defib_self_test_cycles_r3047 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  hospital_code text not null,
  icu_ward_code text not null,
  bed_number int not null check (bed_number between 1 and 60),
  defib_asset_tag text not null,
  manufacturer text not null check (manufacturer in ('philips','zoll','stryker','mindray','nihon_kohden','schiller')),
  quarter_label text not null check (quarter_label in ('2025-Q1','2025-Q2','2025-Q3','2025-Q4','2026-Q1','2026-Q2')),
  scheduled_at timestamptz not null,
  executed_at timestamptz,
  cycle_state text not null check (cycle_state in ('scheduled','in_progress','passed','failed','aborted','overdue')),
  battery_charge_pct numeric(5,2) check (battery_charge_pct >= 0 and battery_charge_pct <= 100),
  pad_expiry_days_remaining int check (pad_expiry_days_remaining >= -60 and pad_expiry_days_remaining <= 365),
  shock_delivery_joules numeric(6,2) check (shock_delivery_joules >= 0 and shock_delivery_joules <= 360),
  ecg_capture_ok boolean,
  self_diagnostic_code text,
  tester_name text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists defib_compliance_incidents_r3047 (
  id uuid primary key default gen_random_uuid(),
  chain_code text not null,
  hospital_code text not null,
  icu_ward_code text not null,
  defib_asset_tag text not null,
  incident_kind text not null check (incident_kind in ('missed_cycle','failed_test','battery_low','pad_expired','ecg_lead_fault','firmware_outdated','asset_missing','manual_override')),
  severity text not null check (severity in ('p0','p1','p2','p3')),
  detected_at timestamptz not null,
  resolved_at timestamptz,
  remediation_state text not null check (remediation_state in ('open','in_progress','remediated','escalated','waived')),
  downtime_hours numeric(6,2) check (downtime_hours >= 0 and downtime_hours <= 720),
  patients_at_risk_count int check (patients_at_risk_count >= 0 and patients_at_risk_count <= 30),
  cost_impact_rupees int check (cost_impact_rupees >= 0 and cost_impact_rupees <= 5000000),
  owner_name text not null,
  root_cause text,
  created_at timestamptz not null default now()
);

alter table defib_self_test_cycles_r3047 enable row level security;
alter table defib_compliance_incidents_r3047 enable row level security;

drop policy if exists defib_self_test_cycles_r3047_founder_all on defib_self_test_cycles_r3047;
create policy defib_self_test_cycles_r3047_founder_all on defib_self_test_cycles_r3047
  for all to authenticated using (is_founder()) with check (is_founder());

drop policy if exists defib_compliance_incidents_r3047_founder_all on defib_compliance_incidents_r3047;
create policy defib_compliance_incidents_r3047_founder_all on defib_compliance_incidents_r3047
  for all to authenticated using (is_founder()) with check (is_founder());

insert into defib_self_test_cycles_r3047 (chain_code,hospital_code,icu_ward_code,bed_number,defib_asset_tag,manufacturer,quarter_label,scheduled_at,executed_at,cycle_state,battery_charge_pct,pad_expiry_days_remaining,shock_delivery_joules,ecg_capture_ok,self_diagnostic_code,tester_name,notes) values
('apollo','APL-HYD-01','MICU-A',1,'DEF-APL-HYD-0001','philips','2026-Q1','2026-01-12 08:00:00+05:30'::timestamptz,'2026-01-12 08:14:00+05:30'::timestamptz,'passed',98.50,180,200.00,true,'OK-0000','Sister Pratibha','clean cycle'),
('apollo','APL-HYD-01','MICU-A',2,'DEF-APL-HYD-0002','philips','2026-Q1','2026-01-12 08:30:00+05:30'::timestamptz,'2026-01-12 08:42:00+05:30'::timestamptz,'passed',96.20,165,200.00,true,'OK-0000','Sister Pratibha',null),
('apollo','APL-HYD-01','SICU-B',5,'DEF-APL-HYD-0005','zoll','2026-Q1','2026-01-13 09:00:00+05:30'::timestamptz,'2026-01-13 09:11:00+05:30'::timestamptz,'failed',62.00,30,150.00,false,'ERR-ECG-LEAD','Tech Ramesh','ECG lead III intermittent'),
('apollo','APL-BLR-02','CCU-1',3,'DEF-APL-BLR-0011','zoll','2026-Q1','2026-01-15 07:30:00+05:30'::timestamptz,null,'overdue',0.00,-12,0.00,null,null,'Tech Akhil','asset off-floor for repaint'),
('apollo','APL-CHN-03','NICU-2',1,'DEF-APL-CHN-0021','mindray','2026-Q1','2026-01-18 10:00:00+05:30'::timestamptz,'2026-01-18 10:08:00+05:30'::timestamptz,'passed',100.00,240,200.00,true,'OK-0000','Sister Vidya','new pads installed'),
('fortis','FRT-DEL-01','MICU-A',4,'DEF-FRT-DEL-0004','stryker','2026-Q1','2026-01-20 08:00:00+05:30'::timestamptz,'2026-01-20 08:19:00+05:30'::timestamptz,'passed',91.40,210,200.00,true,'OK-0000','Tech Suman',null),
('fortis','FRT-DEL-01','MICU-A',7,'DEF-FRT-DEL-0007','stryker','2026-Q1','2026-01-20 09:00:00+05:30'::timestamptz,'2026-01-20 09:33:00+05:30'::timestamptz,'aborted',45.00,90,0.00,null,'ERR-BAT-LOW','Tech Suman','aborted at battery check'),
('fortis','FRT-MUM-02','SICU-C',2,'DEF-FRT-MUM-0014','schiller','2026-Q1','2026-01-22 11:00:00+05:30'::timestamptz,'2026-01-22 11:21:00+05:30'::timestamptz,'passed',88.00,150,200.00,true,'OK-0000','Tech Farah',null),
('fortis','FRT-MUM-02','SICU-C',6,'DEF-FRT-MUM-0018','schiller','2026-Q1','2026-01-22 11:45:00+05:30'::timestamptz,null,'in_progress',74.00,75,0.00,null,null,'Tech Farah','tester paused mid-cycle'),
('manipal','MNP-BLR-01','MICU-A',1,'DEF-MNP-BLR-0001','nihon_kohden','2026-Q1','2026-01-25 08:00:00+05:30'::timestamptz,'2026-01-25 08:12:00+05:30'::timestamptz,'passed',99.10,195,200.00,true,'OK-0000','Tech Hari',null),
('manipal','MNP-BLR-01','MICU-A',2,'DEF-MNP-BLR-0002','nihon_kohden','2026-Q1','2026-01-25 08:30:00+05:30'::timestamptz,'2026-01-25 08:46:00+05:30'::timestamptz,'passed',97.00,180,200.00,true,'OK-0000','Tech Hari',null),
('manipal','MNP-BLR-01','SICU-B',3,'DEF-MNP-BLR-0008','nihon_kohden','2026-Q1','2026-01-25 09:00:00+05:30'::timestamptz,'2026-01-25 09:28:00+05:30'::timestamptz,'failed',55.00,5,100.00,false,'ERR-PAD-EXP','Tech Hari','pads within 5 days expiry'),
('manipal','MNP-VJW-02','CCU-1',1,'DEF-MNP-VJW-0021','mindray','2026-Q1','2026-01-27 10:00:00+05:30'::timestamptz,'2026-01-27 10:14:00+05:30'::timestamptz,'passed',93.00,220,200.00,true,'OK-0000','Tech Lakshmi',null),
('medanta','MDT-GGN-01','MICU-A',2,'DEF-MDT-GGN-0002','philips','2026-Q1','2026-01-29 08:00:00+05:30'::timestamptz,null,'scheduled',null,null,null,null,null,'Sister Anu','awaiting quarterly window'),
('medanta','MDT-GGN-01','SICU-B',4,'DEF-MDT-GGN-0009','philips','2026-Q1','2026-01-29 09:00:00+05:30'::timestamptz,'2026-01-29 09:23:00+05:30'::timestamptz,'passed',95.00,165,200.00,true,'OK-0000','Sister Anu',null),
('apollo','APL-HYD-01','MICU-A',1,'DEF-APL-HYD-0001','philips','2025-Q4','2025-10-10 08:00:00+05:30'::timestamptz,'2025-10-10 08:13:00+05:30'::timestamptz,'passed',97.80,270,200.00,true,'OK-0000','Sister Pratibha',null),
('apollo','APL-BLR-02','CCU-1',3,'DEF-APL-BLR-0011','zoll','2025-Q4','2025-10-12 07:30:00+05:30'::timestamptz,'2025-10-12 08:01:00+05:30'::timestamptz,'failed',60.00,40,140.00,false,'ERR-ECG-LEAD','Tech Akhil','recurring ECG fault'),
('fortis','FRT-DEL-01','MICU-A',7,'DEF-FRT-DEL-0007','stryker','2025-Q4','2025-10-14 09:00:00+05:30'::timestamptz,'2025-10-14 09:25:00+05:30'::timestamptz,'aborted',42.00,100,0.00,null,'ERR-BAT-LOW','Tech Suman','battery low Q4 too'),
('manipal','MNP-BLR-01','SICU-B',3,'DEF-MNP-BLR-0008','nihon_kohden','2025-Q4','2025-10-16 09:00:00+05:30'::timestamptz,'2025-10-16 09:18:00+05:30'::timestamptz,'passed',89.00,95,200.00,true,'OK-0000','Tech Hari','pads were fresh in Q4');

insert into defib_compliance_incidents_r3047 (chain_code,hospital_code,icu_ward_code,defib_asset_tag,incident_kind,severity,detected_at,resolved_at,remediation_state,downtime_hours,patients_at_risk_count,cost_impact_rupees,owner_name,root_cause) values
('apollo','APL-HYD-01','SICU-B','DEF-APL-HYD-0005','ecg_lead_fault','p1','2026-01-13 09:11:00+05:30'::timestamptz,'2026-01-14 14:00:00+05:30'::timestamptz,'remediated',29.00,2,45000,'Biomed Hari','lead III connector corroded'),
('apollo','APL-BLR-02','CCU-1','DEF-APL-BLR-0011','missed_cycle','p0','2026-01-15 07:30:00+05:30'::timestamptz,null,'escalated',168.50,4,180000,'Biomed Kiran','asset off-floor for repaint with no swap unit'),
('apollo','APL-CHN-03','NICU-2','DEF-APL-CHN-0021','firmware_outdated','p3','2026-01-18 10:08:00+05:30'::timestamptz,'2026-01-19 11:00:00+05:30'::timestamptz,'remediated',0.00,0,0,'Biomed Sneha','firmware 3.1.2 vs 3.4.0 latest'),
('fortis','FRT-DEL-01','MICU-A','DEF-FRT-DEL-0007','battery_low','p1','2026-01-20 09:33:00+05:30'::timestamptz,'2026-01-21 16:00:00+05:30'::timestamptz,'remediated',30.50,1,68000,'Biomed Suman','battery cell degradation cycle 412'),
('fortis','FRT-MUM-02','SICU-C','DEF-FRT-MUM-0018','manual_override','p2','2026-01-22 11:45:00+05:30'::timestamptz,null,'in_progress',12.00,0,15000,'Biomed Farah','tester paused for hand-off mid-cycle'),
('manipal','MNP-BLR-01','SICU-B','DEF-MNP-BLR-0008','pad_expired','p1','2026-01-25 09:28:00+05:30'::timestamptz,'2026-01-25 17:00:00+05:30'::timestamptz,'remediated',7.50,1,12000,'Biomed Hari','pads slipped past 90-day reorder threshold'),
('manipal','MNP-VJW-02','CCU-1','DEF-MNP-VJW-0021','firmware_outdated','p3','2026-01-27 10:14:00+05:30'::timestamptz,null,'open',0.00,0,0,'Biomed Lakshmi','firmware 4.0.1 vs 4.1.0 latest'),
('medanta','MDT-GGN-01','MICU-A','DEF-MDT-GGN-0002','missed_cycle','p2','2026-01-29 08:00:00+05:30'::timestamptz,null,'open',24.00,1,30000,'Biomed Anu','quarterly window not booked in roster'),
('apollo','APL-BLR-02','CCU-1','DEF-APL-BLR-0011','ecg_lead_fault','p1','2025-10-12 08:01:00+05:30'::timestamptz,'2025-10-13 13:00:00+05:30'::timestamptz,'remediated',29.00,3,55000,'Biomed Kiran','same lead III fault recurring quarterly'),
('fortis','FRT-DEL-01','MICU-A','DEF-FRT-DEL-0007','battery_low','p2','2025-10-14 09:25:00+05:30'::timestamptz,'2025-10-15 12:00:00+05:30'::timestamptz,'remediated',26.50,2,52000,'Biomed Suman','battery cell wear Q4'),
('apollo','APL-HYD-01','MICU-A','DEF-APL-HYD-0002','asset_missing','p0','2025-12-05 14:00:00+05:30'::timestamptz,'2025-12-06 09:00:00+05:30'::timestamptz,'remediated',19.00,3,210000,'Biomed Hari','unit taken for OT loaner not logged'),
('fortis','FRT-MUM-02','SICU-C','DEF-FRT-MUM-0014','pad_expired','p2','2025-11-22 08:00:00+05:30'::timestamptz,'2025-11-22 14:00:00+05:30'::timestamptz,'waived','6.00',0,8000,'Biomed Farah','pads expired same day cycle ran — risk waived'),
('manipal','MNP-BLR-01','MICU-A','DEF-MNP-BLR-0001','firmware_outdated','p3','2025-11-30 10:00:00+05:30'::timestamptz,'2025-12-01 11:00:00+05:30'::timestamptz,'remediated',0.00,0,0,'Biomed Hari','firmware 4.0.8 vs 4.1.0 latest'),
('apollo','APL-CHN-03','NICU-2','DEF-APL-CHN-0021','failed_test','p1','2025-09-18 10:00:00+05:30'::timestamptz,'2025-09-19 16:00:00+05:30'::timestamptz,'remediated',30.00,1,42000,'Biomed Sneha','shock delivery 60J short of 200J target');

create or replace function fn_r3047_chain_compliance_summary()
returns table(chain_code text, total_cycles int, passed_cycles int, failed_cycles int, overdue_cycles int, pass_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.chain_code,
         count(*)::int as total_cycles,
         (count(*) filter (where c.cycle_state = 'passed'))::int as passed_cycles,
         (count(*) filter (where c.cycle_state = 'failed'))::int as failed_cycles,
         (count(*) filter (where c.cycle_state = 'overdue'))::int as overdue_cycles,
         round(100.0 * (count(*) filter (where c.cycle_state = 'passed'))::numeric / nullif(count(*),0), 2) as pass_rate_pct
  from defib_self_test_cycles_r3047 c
  group by c.chain_code
  order by pass_rate_pct asc nulls last;
end;$$;

create or replace function fn_r3047_quarter_trend()
returns table(quarter_label text, total_cycles int, passed_cycles int, failed_cycles int, aborted_cycles int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.quarter_label,
         count(*)::int,
         (count(*) filter (where c.cycle_state = 'passed'))::int,
         (count(*) filter (where c.cycle_state = 'failed'))::int,
         (count(*) filter (where c.cycle_state = 'aborted'))::int
  from defib_self_test_cycles_r3047 c
  group by c.quarter_label
  order by c.quarter_label;
end;$$;

create or replace function fn_r3047_manufacturer_failure_heatmap()
returns table(manufacturer text, total int, failed int, aborted int, failure_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.manufacturer,
         count(*)::int,
         (count(*) filter (where c.cycle_state = 'failed'))::int,
         (count(*) filter (where c.cycle_state = 'aborted'))::int,
         round(100.0 * (count(*) filter (where c.cycle_state in ('failed','aborted')))::numeric / nullif(count(*),0), 2)
  from defib_self_test_cycles_r3047 c
  group by c.manufacturer
  order by failure_rate_pct desc nulls last;
end;$$;

create or replace function fn_r3047_overdue_units()
returns table(chain_code text, hospital_code text, icu_ward_code text, defib_asset_tag text, scheduled_at timestamptz, days_overdue int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select c.chain_code, c.hospital_code, c.icu_ward_code, c.defib_asset_tag, c.scheduled_at,
         greatest(0, extract(day from (now() - c.scheduled_at))::int)
  from defib_self_test_cycles_r3047 c
  where c.cycle_state in ('overdue','scheduled') and c.scheduled_at < now()
  order by c.scheduled_at;
end;$$;

create or replace function fn_r3047_incident_severity_breakdown()
returns table(severity text, open_count int, resolved_count int, total_downtime_hours numeric, total_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.severity,
         (count(*) filter (where i.remediation_state in ('open','in_progress','escalated')))::int,
         (count(*) filter (where i.remediation_state = 'remediated'))::int,
         coalesce(sum(i.downtime_hours), 0)::numeric,
         coalesce(sum(i.cost_impact_rupees), 0)::int
  from defib_compliance_incidents_r3047 i
  group by i.severity
  order by i.severity;
end;$$;

create or replace function fn_r3047_top_risk_hospitals()
returns table(chain_code text, hospital_code text, open_incidents int, patients_at_risk int, total_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.chain_code, i.hospital_code,
         (count(*) filter (where i.remediation_state in ('open','in_progress','escalated')))::int,
         coalesce(sum(i.patients_at_risk_count), 0)::int,
         coalesce(sum(i.cost_impact_rupees), 0)::int
  from defib_compliance_incidents_r3047 i
  group by i.chain_code, i.hospital_code
  order by patients_at_risk desc, total_cost_rupees desc
  limit 10;
end;$$;

create or replace function fn_r3047_recurring_fault_assets()
returns table(defib_asset_tag text, chain_code text, hospital_code text, incident_count int, distinct_kinds int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select i.defib_asset_tag, i.chain_code, i.hospital_code,
         count(*)::int,
         count(distinct i.incident_kind)::int
  from defib_compliance_incidents_r3047 i
  group by i.defib_asset_tag, i.chain_code, i.hospital_code
  having count(*) >= 2
  order by incident_count desc;
end;$$;

revoke all on function fn_r3047_chain_compliance_summary() from public, anon;
revoke all on function fn_r3047_quarter_trend() from public, anon;
revoke all on function fn_r3047_manufacturer_failure_heatmap() from public, anon;
revoke all on function fn_r3047_overdue_units() from public, anon;
revoke all on function fn_r3047_incident_severity_breakdown() from public, anon;
revoke all on function fn_r3047_top_risk_hospitals() from public, anon;
revoke all on function fn_r3047_recurring_fault_assets() from public, anon;

grant execute on function fn_r3047_chain_compliance_summary() to authenticated;
grant execute on function fn_r3047_quarter_trend() to authenticated;
grant execute on function fn_r3047_manufacturer_failure_heatmap() to authenticated;
grant execute on function fn_r3047_overdue_units() to authenticated;
grant execute on function fn_r3047_incident_severity_breakdown() to authenticated;
grant execute on function fn_r3047_top_risk_hospitals() to authenticated;
grant execute on function fn_r3047_recurring_fault_assets() to authenticated;
