-- Round 3075 — Hospital Chain Quarterly Infant Incubator Probe-Drift & Skin-Temperature Safety Audit
-- HEAVY ★★★★

create table if not exists incubator_probe_drift_audits_r3075 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  hospital_chain text not null,
  facility_code text not null,
  nicu_unit text not null,
  incubator_serial text not null,
  manufacturer text not null,
  probe_type text not null check (probe_type in ('skin_temp_primary','skin_temp_secondary','air_temp','humidity','dual_skin')),
  audit_quarter text not null check (audit_quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026')),
  reference_temp_celsius numeric(5,2) not null,
  measured_temp_celsius numeric(5,2) not null,
  drift_celsius numeric(5,2) not null,
  drift_severity text not null check (drift_severity in ('within_tolerance','minor_drift','major_drift','critical_drift','probe_failure')),
  babies_at_risk int not null default 0,
  action_taken text check (action_taken in ('recalibrated','probe_replaced','unit_quarantined','vendor_callback','no_action_needed')),
  last_calibration_date date,
  next_due_date date,
  technician_name text,
  audited_at timestamptz
);

create table if not exists incubator_safety_remediation_r3075 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid references incubator_probe_drift_audits_r3075(id) on delete set null,
  hospital_chain text not null,
  remediation_type text not null check (remediation_type in ('probe_swap','full_recalibration','firmware_update','vendor_rma','unit_decommission','training_refresh')),
  priority text not null check (priority in ('p0_immediate','p1_24h','p2_7d','p3_quarterly')),
  remediation_cost_rupees int not null default 0,
  remediation_status text not null check (remediation_status in ('open','assigned','in_progress','completed','escalated','deferred')),
  assigned_vendor text,
  resolution_notes text,
  completed_at timestamptz
);

alter table incubator_probe_drift_audits_r3075 enable row level security;
alter table incubator_safety_remediation_r3075 enable row level security;

drop policy if exists founder_read_drift_r3075 on incubator_probe_drift_audits_r3075;
create policy founder_read_drift_r3075 on incubator_probe_drift_audits_r3075 for select to authenticated using (is_founder());

drop policy if exists founder_read_rem_r3075 on incubator_safety_remediation_r3075;
create policy founder_read_rem_r3075 on incubator_safety_remediation_r3075 for select to authenticated using (is_founder());

-- Seeds: incubator_probe_drift_audits_r3075 (20 rows)
insert into incubator_probe_drift_audits_r3075 (hospital_chain, facility_code, nicu_unit, incubator_serial, manufacturer, probe_type, audit_quarter, reference_temp_celsius, measured_temp_celsius, drift_celsius, drift_severity, babies_at_risk, action_taken, last_calibration_date, next_due_date, technician_name, audited_at) values
('Apollo Cradle','APC-HYD-01','NICU-A','GE-GIRA-9981','GE Healthcare','skin_temp_primary','Q2-2026',36.50,36.55,0.05,'within_tolerance',0,'no_action_needed','2026-03-15'::date,'2026-09-15'::date,'R Naidu','2026-06-10T09:15:00+05:30'::timestamptz),
('Rainbow Children','RNB-BLR-02','NICU-B','DRG-8800-22','Drager','skin_temp_secondary','Q2-2026',36.50,36.92,0.42,'minor_drift',2,'recalibrated','2026-02-20'::date,'2026-08-20'::date,'V Kumar','2026-06-11T10:30:00+05:30'::timestamptz),
('Fortis Mother','FOR-NCR-03','NICU-1','GE-GIRA-9982','GE Healthcare','dual_skin','Q2-2026',36.50,37.45,0.95,'major_drift',4,'probe_replaced','2026-01-10'::date,'2026-07-10'::date,'S Mehra','2026-06-12T11:00:00+05:30'::timestamptz),
('Manipal Hospitals','MAN-BLR-04','NICU-East','PHIL-CRT-553','Philips','air_temp','Q2-2026',32.00,32.10,0.10,'within_tolerance',0,'no_action_needed','2026-04-01'::date,'2026-10-01'::date,'P Iyer','2026-06-13T08:45:00+05:30'::timestamptz),
('Cloudnine','CLN-CHN-05','NICU-North','GE-GIRA-9985','GE Healthcare','skin_temp_primary','Q2-2026',36.50,38.12,1.62,'critical_drift',6,'unit_quarantined','2025-12-05'::date,'2026-06-05'::date,'K Sundar','2026-06-14T14:20:00+05:30'::timestamptz),
('Apollo Cradle','APC-HYD-01','NICU-B','DRG-8801-15','Drager','humidity','Q2-2026',55.00,58.50,3.50,'minor_drift',1,'recalibrated','2026-03-15'::date,'2026-09-15'::date,'R Naidu','2026-06-10T10:00:00+05:30'::timestamptz),
('Rainbow Children','RNB-HYD-06','NICU-A','GE-GIRA-9990','GE Healthcare','skin_temp_primary','Q2-2026',36.50,36.48,-0.02,'within_tolerance',0,'no_action_needed','2026-04-20'::date,'2026-10-20'::date,'L Reddy','2026-06-11T12:15:00+05:30'::timestamptz),
('Fortis Mother','FOR-MUM-07','NICU-2','PHIL-CRT-560','Philips','skin_temp_secondary','Q2-2026',36.50,37.78,1.28,'critical_drift',3,'probe_replaced','2025-11-25'::date,'2026-05-25'::date,'A Pillai','2026-06-12T15:30:00+05:30'::timestamptz),
('Manipal Hospitals','MAN-MNG-08','NICU-West','DRG-8810-09','Drager','dual_skin','Q2-2026',36.50,36.75,0.25,'minor_drift',2,'recalibrated','2026-03-30'::date,'2026-09-30'::date,'D Shetty','2026-06-13T09:30:00+05:30'::timestamptz),
('Cloudnine','CLN-BLR-09','NICU-Central','GE-GIRA-9991','GE Healthcare','air_temp','Q2-2026',32.00,33.85,1.85,'major_drift',5,'vendor_callback','2025-12-12'::date,'2026-06-12'::date,'M Bose','2026-06-14T16:00:00+05:30'::timestamptz),
('Apollo Cradle','APC-CHN-10','NICU-A','PHIL-CRT-575','Philips','skin_temp_primary','Q1-2026',36.50,36.62,0.12,'within_tolerance',0,'no_action_needed','2025-12-01'::date,'2026-06-01'::date,'T Raghav','2026-03-15T11:00:00+05:30'::timestamptz),
('Rainbow Children','RNB-CHN-11','NICU-C','GE-GIRA-9992','GE Healthcare','skin_temp_secondary','Q1-2026',36.50,37.21,0.71,'minor_drift',3,'recalibrated','2025-11-15'::date,'2026-05-15'::date,'B Kannan','2026-03-16T13:45:00+05:30'::timestamptz),
('Fortis Mother','FOR-PUN-12','NICU-1','DRG-8820-44','Drager','humidity','Q2-2026',55.00,62.40,7.40,'major_drift',2,'probe_replaced','2026-01-25'::date,'2026-07-25'::date,'N Joshi','2026-06-15T10:15:00+05:30'::timestamptz),
('Manipal Hospitals','MAN-JAI-13','NICU-A','GE-GIRA-9993','GE Healthcare','skin_temp_primary','Q2-2026',36.50,39.10,2.60,'probe_failure',7,'unit_quarantined','2025-10-05'::date,'2026-04-05'::date,'V Sharma','2026-06-16T11:45:00+05:30'::timestamptz),
('Cloudnine','CLN-PUN-14','NICU-A','PHIL-CRT-580','Philips','dual_skin','Q2-2026',36.50,36.58,0.08,'within_tolerance',0,'no_action_needed','2026-04-10'::date,'2026-10-10'::date,'C Kale','2026-06-17T09:00:00+05:30'::timestamptz),
('Apollo Cradle','APC-NCR-15','NICU-South','DRG-8830-31','Drager','skin_temp_secondary','Q2-2026',36.50,37.35,0.85,'major_drift',4,'probe_replaced','2025-12-20'::date,'2026-06-20'::date,'G Khanna','2026-06-18T14:00:00+05:30'::timestamptz),
('Rainbow Children','RNB-BLR-02','NICU-D','GE-GIRA-9994','GE Healthcare','air_temp','Q2-2026',32.00,32.05,0.05,'within_tolerance',0,'no_action_needed','2026-04-25'::date,'2026-10-25'::date,'V Kumar','2026-06-18T15:30:00+05:30'::timestamptz),
('Fortis Mother','FOR-NCR-03','NICU-3','PHIL-CRT-590','Philips','skin_temp_primary','Q2-2026',36.50,38.65,2.15,'probe_failure',5,'vendor_callback','2025-10-15'::date,'2026-04-15'::date,'S Mehra','2026-06-19T10:30:00+05:30'::timestamptz),
('Manipal Hospitals','MAN-BLR-04','NICU-East','GE-GIRA-9995','GE Healthcare','humidity','Q2-2026',55.00,56.20,1.20,'within_tolerance',0,'no_action_needed','2026-04-01'::date,'2026-10-01'::date,'P Iyer','2026-06-19T11:15:00+05:30'::timestamptz),
('Cloudnine','CLN-CHN-05','NICU-North','DRG-8840-77','Drager','dual_skin','Q2-2026',36.50,37.08,0.58,'minor_drift',3,'recalibrated','2026-01-30'::date,'2026-07-30'::date,'K Sundar','2026-06-20T08:30:00+05:30'::timestamptz);

-- Seeds: incubator_safety_remediation_r3075 (18 rows)
insert into incubator_safety_remediation_r3075 (hospital_chain, remediation_type, priority, remediation_cost_rupees, remediation_status, assigned_vendor, resolution_notes, completed_at) values
('Apollo Cradle','firmware_update','p3_quarterly',5000,'completed','GE Healthcare India','Routine firmware bump v3.2.1','2026-06-10T16:00:00+05:30'::timestamptz),
('Rainbow Children','probe_swap','p2_7d',12500,'completed','Drager Medical','Replaced secondary skin probe','2026-06-11T17:30:00+05:30'::timestamptz),
('Fortis Mother','probe_swap','p1_24h',28000,'completed','GE Healthcare India','Dual-skin probe failed factory test','2026-06-13T09:00:00+05:30'::timestamptz),
('Manipal Hospitals','full_recalibration','p3_quarterly',8500,'completed','Equipseva Cert Tech','Quarterly recal closed','2026-06-13T14:00:00+05:30'::timestamptz),
('Cloudnine','unit_decommission','p0_immediate',185000,'in_progress','GE Healthcare India','Critical drift; unit pulled, replacement loaner shipped',null),
('Apollo Cradle','full_recalibration','p2_7d',8500,'completed','Equipseva Cert Tech','Humidity sensor recalibrated','2026-06-11T11:00:00+05:30'::timestamptz),
('Rainbow Children','training_refresh','p3_quarterly',3500,'completed','Equipseva Training','NICU nursing refresher cycle','2026-06-12T13:00:00+05:30'::timestamptz),
('Fortis Mother','vendor_rma','p1_24h',0,'escalated','Philips India','RMA #PHI-2026-4471, awaiting replacement',null),
('Manipal Hospitals','probe_swap','p2_7d',12500,'completed','Drager Medical','Dual-skin probe replaced','2026-06-13T16:30:00+05:30'::timestamptz),
('Cloudnine','vendor_rma','p1_24h',0,'open','GE Healthcare India','Air temp drift flagged for vendor callback',null),
('Apollo Cradle','firmware_update','p3_quarterly',5000,'deferred','Philips India','Deferred to Q3 maintenance window',null),
('Rainbow Children','full_recalibration','p2_7d',8500,'in_progress','Equipseva Cert Tech','Secondary probe drift; tech scheduled',null),
('Fortis Mother','probe_swap','p1_24h',12500,'completed','Drager Medical','Humidity probe replaced','2026-06-16T14:00:00+05:30'::timestamptz),
('Manipal Hospitals','unit_decommission','p0_immediate',195000,'assigned','GE Healthcare India','Probe failure - babies relocated to standby unit',null),
('Cloudnine','training_refresh','p3_quarterly',3500,'completed','Equipseva Training','Baseline NICU temp safety drill','2026-06-17T11:30:00+05:30'::timestamptz),
('Apollo Cradle','probe_swap','p1_24h',12500,'in_progress','Drager Medical','Secondary skin probe replacement queued',null),
('Fortis Mother','vendor_rma','p0_immediate',0,'escalated','Philips India','Probe failure - vendor field engineer en route',null),
('Cloudnine','full_recalibration','p2_7d',8500,'open','Equipseva Cert Tech','Dual-skin recal queued for next slot',null);

-- RPC 1: drift severity rollup
create or replace function founder_r3075_drift_severity_rollup()
returns table(drift_severity text, audits int, babies_at_risk int, avg_drift_celsius numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.drift_severity, count(*)::int as audits,
    coalesce(sum(a.babies_at_risk),0)::int as babies_at_risk,
    round(avg(abs(a.drift_celsius))::numeric, 3) as avg_drift_celsius
  from incubator_probe_drift_audits_r3075 a
  group by a.drift_severity
  order by audits desc;
end; $$;

-- RPC 2: hospital chain risk summary
create or replace function founder_r3075_chain_risk_summary()
returns table(hospital_chain text, total_audits int, critical_or_failure int, babies_at_risk int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain, count(*)::int as total_audits,
    (count(*) filter (where a.drift_severity in ('critical_drift','probe_failure')))::int as critical_or_failure,
    coalesce(sum(a.babies_at_risk),0)::int as babies_at_risk
  from incubator_probe_drift_audits_r3075 a
  group by a.hospital_chain
  order by babies_at_risk desc, critical_or_failure desc;
end; $$;

-- RPC 3: probe type drift profile
create or replace function founder_r3075_probe_type_profile()
returns table(probe_type text, audits int, max_abs_drift numeric, avg_abs_drift numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.probe_type, count(*)::int as audits,
    round(max(abs(a.drift_celsius))::numeric, 3) as max_abs_drift,
    round(avg(abs(a.drift_celsius))::numeric, 3) as avg_abs_drift
  from incubator_probe_drift_audits_r3075 a
  group by a.probe_type
  order by max_abs_drift desc;
end; $$;

-- RPC 4: overdue calibrations
create or replace function founder_r3075_overdue_calibrations()
returns table(hospital_chain text, facility_code text, incubator_serial text, next_due_date date, drift_severity text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain, a.facility_code, a.incubator_serial, a.next_due_date, a.drift_severity
  from incubator_probe_drift_audits_r3075 a
  where a.next_due_date is not null and a.next_due_date <= '2026-06-21'::date
  order by a.next_due_date asc;
end; $$;

-- RPC 5: remediation status board
create or replace function founder_r3075_remediation_status_board()
returns table(remediation_status text, items int, total_cost_rupees int, p0_count int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.remediation_status, count(*)::int as items,
    coalesce(sum(r.remediation_cost_rupees),0)::int as total_cost_rupees,
    (count(*) filter (where r.priority = 'p0_immediate'))::int as p0_count
  from incubator_safety_remediation_r3075 r
  group by r.remediation_status
  order by items desc;
end; $$;

-- RPC 6: vendor performance
create or replace function founder_r3075_vendor_performance()
returns table(assigned_vendor text, items int, completed int, open_or_escalated int, total_cost_rupees int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select coalesce(r.assigned_vendor,'(unassigned)') as assigned_vendor,
    count(*)::int as items,
    (count(*) filter (where r.remediation_status = 'completed'))::int as completed,
    (count(*) filter (where r.remediation_status in ('open','escalated')))::int as open_or_escalated,
    coalesce(sum(r.remediation_cost_rupees),0)::int as total_cost_rupees
  from incubator_safety_remediation_r3075 r
  group by coalesce(r.assigned_vendor,'(unassigned)')
  order by items desc;
end; $$;

-- RPC 7: top critical incidents
create or replace function founder_r3075_top_critical_incidents()
returns table(hospital_chain text, facility_code text, incubator_serial text, probe_type text, drift_celsius numeric, babies_at_risk int, action_taken text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_chain, a.facility_code, a.incubator_serial, a.probe_type, a.drift_celsius, a.babies_at_risk, a.action_taken
  from incubator_probe_drift_audits_r3075 a
  where a.drift_severity in ('critical_drift','probe_failure','major_drift')
  order by a.babies_at_risk desc, abs(a.drift_celsius) desc
  limit 15;
end; $$;

-- RPC 8: quarter trend
create or replace function founder_r3075_quarter_trend()
returns table(audit_quarter text, audits int, critical_or_failure int, babies_at_risk int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_quarter, count(*)::int as audits,
    (count(*) filter (where a.drift_severity in ('critical_drift','probe_failure')))::int as critical_or_failure,
    coalesce(sum(a.babies_at_risk),0)::int as babies_at_risk
  from incubator_probe_drift_audits_r3075 a
  group by a.audit_quarter
  order by a.audit_quarter asc;
end; $$;

revoke all on function founder_r3075_drift_severity_rollup() from public, anon;
revoke all on function founder_r3075_chain_risk_summary() from public, anon;
revoke all on function founder_r3075_probe_type_profile() from public, anon;
revoke all on function founder_r3075_overdue_calibrations() from public, anon;
revoke all on function founder_r3075_remediation_status_board() from public, anon;
revoke all on function founder_r3075_vendor_performance() from public, anon;
revoke all on function founder_r3075_top_critical_incidents() from public, anon;
revoke all on function founder_r3075_quarter_trend() from public, anon;

grant execute on function founder_r3075_drift_severity_rollup() to authenticated;
grant execute on function founder_r3075_chain_risk_summary() to authenticated;
grant execute on function founder_r3075_probe_type_profile() to authenticated;
grant execute on function founder_r3075_overdue_calibrations() to authenticated;
grant execute on function founder_r3075_remediation_status_board() to authenticated;
grant execute on function founder_r3075_vendor_performance() to authenticated;
grant execute on function founder_r3075_top_critical_incidents() to authenticated;
grant execute on function founder_r3075_quarter_trend() to authenticated;
