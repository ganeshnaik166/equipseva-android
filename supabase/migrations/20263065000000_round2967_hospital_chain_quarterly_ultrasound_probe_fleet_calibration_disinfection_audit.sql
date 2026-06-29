-- Round 2967 — Hospital Chain Quarterly Ultrasound-Probe Fleet Calibration & Disinfection Audit
-- Two tables (_r2967) + seven SECURITY DEFINER RPCs gated by is_founder().

create table if not exists ultrasound_probe_fleet_r2967 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_name text not null,
  hospital_site text not null,
  probe_serial text not null unique,
  probe_type text not null check (probe_type in ('curvilinear','linear','phased','endocavity','tee','volumetric_4d')),
  modality text not null check (modality in ('general_imaging','cardiology','obstetrics','emergency','vascular','msk')),
  acquired_on date not null,
  last_calibration_at date not null,
  next_calibration_due date not null,
  last_disinfection_at timestamptz not null,
  disinfection_method text not null check (disinfection_method in ('trophon_hpv','cidex_opa','sterrad','wipe_low_level','uv_c_chamber')),
  calibration_status text not null check (calibration_status in ('compliant','due_soon','overdue','failed_recall')),
  disinfection_status text not null check (disinfection_status in ('compliant','missed_cycle','contamination_flag','quarantined')),
  quarter_label text not null check (quarter_label in ('Q1_2026','Q2_2026','Q3_2026','Q4_2026','Q1_2027')),
  fleet_value_inr bigint not null check (fleet_value_inr >= 0),
  utilization_hours_quarter int not null check (utilization_hours_quarter >= 0)
);

create table if not exists ultrasound_probe_audit_findings_r2967 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  probe_id uuid not null references ultrasound_probe_fleet_r2967(id) on delete cascade,
  finding_code text not null check (finding_code in ('cal_drift','seal_breach','crystal_degraded','cable_fray','lens_crack','high_voltage_leak','disinfection_log_gap','operator_certification_expired')),
  severity text not null check (severity in ('critical','major','minor','observation')),
  detected_on date not null,
  remediation_due date not null,
  remediation_status text not null check (remediation_status in ('open','in_progress','remediated','escalated','accepted_risk')),
  cost_to_remediate_inr bigint not null check (cost_to_remediate_inr >= 0),
  patient_safety_impact text not null check (patient_safety_impact in ('none','low','moderate','high','critical')),
  auditor_handle text not null,
  notes text not null
);

alter table ultrasound_probe_fleet_r2967 enable row level security;
alter table ultrasound_probe_audit_findings_r2967 enable row level security;

drop policy if exists probe_fleet_r2967_founder_read on ultrasound_probe_fleet_r2967;
create policy probe_fleet_r2967_founder_read on ultrasound_probe_fleet_r2967
  for select to authenticated using (is_founder());

drop policy if exists probe_findings_r2967_founder_read on ultrasound_probe_audit_findings_r2967;
create policy probe_findings_r2967_founder_read on ultrasound_probe_audit_findings_r2967
  for select to authenticated using (is_founder());

revoke all on ultrasound_probe_fleet_r2967 from public, anon;
revoke all on ultrasound_probe_audit_findings_r2967 from public, anon;
grant select on ultrasound_probe_fleet_r2967 to authenticated;
grant select on ultrasound_probe_audit_findings_r2967 to authenticated;

-- Seed fleet (18 rows)
insert into ultrasound_probe_fleet_r2967 (chain_name, hospital_site, probe_serial, probe_type, modality, acquired_on, last_calibration_at, next_calibration_due, last_disinfection_at, disinfection_method, calibration_status, disinfection_status, quarter_label, fleet_value_inr, utilization_hours_quarter) values
('Apollo Multi-Specialty','Apollo Jubilee Hills','APX-CRV-100021','curvilinear','general_imaging','2024-03-12'::date,'2026-03-04'::date,'2026-09-04'::date,'2026-06-19T06:30:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',420000,612),
('Apollo Multi-Specialty','Apollo Secunderabad','APX-LIN-100044','linear','vascular','2023-11-02'::date,'2026-02-18'::date,'2026-08-18'::date,'2026-06-18T19:10:00+05:30'::timestamptz,'cidex_opa','due_soon','compliant','Q2_2026',365000,540),
('Apollo Multi-Specialty','Apollo Secunderabad','APX-PHS-100051','phased','cardiology','2022-08-21'::date,'2025-12-30'::date,'2026-06-30'::date,'2026-06-15T11:00:00+05:30'::timestamptz,'sterrad','overdue','missed_cycle','Q2_2026',810000,704),
('Apollo Multi-Specialty','Apollo Hyderguda','APX-TEE-100068','tee','cardiology','2024-09-14'::date,'2026-05-22'::date,'2026-11-22'::date,'2026-06-20T08:45:00+05:30'::timestamptz,'cidex_opa','compliant','compliant','Q2_2026',1480000,318),
('Manipal Hospitals','Manipal Vijayawada','MNP-ENV-200013','endocavity','obstetrics','2024-01-05'::date,'2026-04-09'::date,'2026-10-09'::date,'2026-06-20T17:20:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',540000,488),
('Manipal Hospitals','Manipal Old Airport Rd','MNP-CRV-200027','curvilinear','emergency','2023-05-19'::date,'2025-11-28'::date,'2026-05-28'::date,'2026-06-17T14:55:00+05:30'::timestamptz,'wipe_low_level','overdue','contamination_flag','Q2_2026',395000,820),
('Manipal Hospitals','Manipal Whitefield','MNP-VOL-200033','volumetric_4d','obstetrics','2025-02-08'::date,'2026-05-15'::date,'2026-11-15'::date,'2026-06-19T09:00:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',1690000,442),
('Manipal Hospitals','Manipal Yeshwanthpur','MNP-LIN-200049','linear','msk','2024-07-22'::date,'2026-03-31'::date,'2026-09-30'::date,'2026-06-18T12:30:00+05:30'::timestamptz,'cidex_opa','compliant','compliant','Q2_2026',310000,396),
('Fortis Healthcare','Fortis Bannerghatta','FTS-PHS-300004','phased','cardiology','2022-12-11'::date,'2025-09-04'::date,'2026-03-04'::date,'2026-06-12T07:40:00+05:30'::timestamptz,'sterrad','failed_recall','quarantined','Q2_2026',795000,128),
('Fortis Healthcare','Fortis BG Road','FTS-CRV-300017','curvilinear','general_imaging','2024-04-30'::date,'2026-04-14'::date,'2026-10-14'::date,'2026-06-21T08:15:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',410000,560),
('Fortis Healthcare','Fortis Cunningham','FTS-LIN-300025','linear','vascular','2023-08-17'::date,'2026-01-12'::date,'2026-07-12'::date,'2026-06-19T16:00:00+05:30'::timestamptz,'cidex_opa','due_soon','compliant','Q2_2026',355000,612),
('Fortis Healthcare','Fortis Nagarbhavi','FTS-ENV-300031','endocavity','obstetrics','2025-01-23'::date,'2026-05-02'::date,'2026-11-02'::date,'2026-06-20T11:25:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',525000,372),
('Yashoda Group','Yashoda Somajiguda','YSH-TEE-400008','tee','cardiology','2023-04-09'::date,'2025-10-21'::date,'2026-04-21'::date,'2026-06-14T05:55:00+05:30'::timestamptz,'sterrad','overdue','missed_cycle','Q2_2026',1455000,244),
('Yashoda Group','Yashoda Malakpet','YSH-CRV-400019','curvilinear','emergency','2024-10-04'::date,'2026-04-19'::date,'2026-10-19'::date,'2026-06-21T07:05:00+05:30'::timestamptz,'uv_c_chamber','compliant','compliant','Q2_2026',420000,748),
('Yashoda Group','Yashoda Secunderabad','YSH-VOL-400024','volumetric_4d','obstetrics','2025-03-18'::date,'2026-05-26'::date,'2026-11-26'::date,'2026-06-20T13:40:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',1715000,358),
('KIMS Hospitals','KIMS Kondapur','KMS-LIN-500011','linear','msk','2024-06-05'::date,'2026-02-09'::date,'2026-08-09'::date,'2026-06-18T18:30:00+05:30'::timestamptz,'cidex_opa','due_soon','compliant','Q2_2026',335000,420),
('KIMS Hospitals','KIMS Begumpet','KMS-PHS-500022','phased','cardiology','2023-02-27'::date,'2025-08-15'::date,'2026-02-15'::date,'2026-06-10T09:50:00+05:30'::timestamptz,'sterrad','failed_recall','quarantined','Q2_2026',775000,96),
('KIMS Hospitals','KIMS Gachibowli','KMS-CRV-500036','curvilinear','general_imaging','2024-12-01'::date,'2026-05-08'::date,'2026-11-08'::date,'2026-06-21T06:20:00+05:30'::timestamptz,'trophon_hpv','compliant','compliant','Q2_2026',418000,584);

-- Seed findings (22 rows)
insert into ultrasound_probe_audit_findings_r2967 (probe_id, finding_code, severity, detected_on, remediation_due, remediation_status, cost_to_remediate_inr, patient_safety_impact, auditor_handle, notes) values
((select id from ultrasound_probe_fleet_r2967 where probe_serial='APX-PHS-100051'),'cal_drift','major','2026-06-04'::date,'2026-07-04'::date,'in_progress',62000,'moderate','auditor_rgupta','Phased-array element drift > 8% on TGC sweep; vendor service ticket open.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='APX-LIN-100044'),'cable_fray','minor','2026-06-08'::date,'2026-07-22'::date,'open',9500,'low','auditor_rgupta','Strain-relief fray near connector; replacement boot ordered.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='MNP-CRV-200027'),'disinfection_log_gap','major','2026-06-10'::date,'2026-06-25'::date,'remediated',0,'moderate','auditor_bkrish','3 missed Trophon cycles backfilled; SOP retrained.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='MNP-CRV-200027'),'seal_breach','critical','2026-06-10'::date,'2026-06-17'::date,'escalated',145000,'high','auditor_bkrish','Acoustic lens seal failed dye test — quarantine pending vendor RMA.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='FTS-PHS-300004'),'crystal_degraded','critical','2026-05-29'::date,'2026-06-12'::date,'escalated',310000,'critical','auditor_skapoor','Element dropout on 14 of 64 channels; recall hold >= 14 days.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='FTS-PHS-300004'),'high_voltage_leak','critical','2026-05-29'::date,'2026-06-05'::date,'remediated',88000,'high','auditor_skapoor','Leakage current 612 microA > IEC 60601 limit; HV board swapped.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='FTS-LIN-300025'),'cal_drift','minor','2026-06-02'::date,'2026-07-12'::date,'open',24000,'low','auditor_skapoor','Drift within tolerance band; recalibration scheduled.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='YSH-TEE-400008'),'seal_breach','critical','2026-05-22'::date,'2026-06-05'::date,'escalated',420000,'critical','auditor_dvenkat','TEE bite-mark micro-tear; out of service until vendor inspection.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='YSH-TEE-400008'),'operator_certification_expired','major','2026-05-22'::date,'2026-06-22'::date,'in_progress',15000,'moderate','auditor_dvenkat','2 of 5 cardio sonographers expired BLS & HLD-handler cert.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='KMS-PHS-500022'),'crystal_degraded','critical','2026-05-18'::date,'2026-06-01'::date,'escalated',295000,'critical','auditor_pmehta','>= 18% element loss; manufacturer recall acknowledged.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='KMS-PHS-500022'),'disinfection_log_gap','major','2026-05-18'::date,'2026-06-15'::date,'remediated',0,'moderate','auditor_pmehta','Log gap pre-quarantine; non-applicable post-recall.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='KMS-LIN-500011'),'lens_crack','major','2026-06-12'::date,'2026-07-26'::date,'in_progress',58000,'moderate','auditor_pmehta','Hairline crack on lens; epoxy bond not approved — lens swap planned.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='APX-CRV-100021'),'cal_drift','observation','2026-06-15'::date,'2026-09-15'::date,'accepted_risk',0,'none','auditor_rgupta','<= 2% drift; within mfr tolerance.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='APX-TEE-100068'),'operator_certification_expired','minor','2026-06-16'::date,'2026-07-16'::date,'open',6000,'low','auditor_rgupta','1 sonographer cert lapsed 9 days.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='MNP-ENV-200013'),'cable_fray','observation','2026-06-13'::date,'2026-08-13'::date,'open',7800,'low','auditor_bkrish','Cosmetic only; flagged for next PM.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='MNP-VOL-200033'),'cal_drift','minor','2026-06-14'::date,'2026-07-28'::date,'in_progress',32000,'low','auditor_bkrish','4D volume reconstruction drift; firmware update queued.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='MNP-LIN-200049'),'cal_drift','observation','2026-06-11'::date,'2026-09-11'::date,'remediated',12000,'none','auditor_bkrish','Recal in-house; within spec.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='FTS-CRV-300017'),'disinfection_log_gap','minor','2026-06-09'::date,'2026-06-23'::date,'remediated',0,'low','auditor_skapoor','Single log gap; nurse manager retrained.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='FTS-ENV-300031'),'operator_certification_expired','observation','2026-06-07'::date,'2026-07-07'::date,'open',5500,'none','auditor_skapoor','Cert renewal scheduled in-house.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='YSH-CRV-400019'),'cal_drift','observation','2026-06-19'::date,'2026-09-19'::date,'accepted_risk',0,'none','auditor_dvenkat','Stable across last 3 quarters.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='YSH-VOL-400024'),'cable_fray','minor','2026-06-18'::date,'2026-08-02'::date,'open',11200,'low','auditor_dvenkat','Strain-relief replacement under warranty.'),
((select id from ultrasound_probe_fleet_r2967 where probe_serial='KMS-CRV-500036'),'cal_drift','observation','2026-06-20'::date,'2026-09-20'::date,'remediated',8000,'none','auditor_pmehta','Routine recal pass.');

-- RPC 1: chain-level fleet rollup
create or replace function founder_r2967_chain_fleet_rollup()
returns table (
  chain_name text,
  probes_total int,
  compliant_calibration int,
  overdue_calibration int,
  failed_recall int,
  contamination_or_quarantine int,
  fleet_value_inr bigint,
  utilization_hours bigint
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    f.chain_name,
    count(*)::int,
    (count(*) filter (where f.calibration_status = 'compliant'))::int,
    (count(*) filter (where f.calibration_status = 'overdue'))::int,
    (count(*) filter (where f.calibration_status = 'failed_recall'))::int,
    (count(*) filter (where f.disinfection_status in ('contamination_flag','quarantined')))::int,
    coalesce(sum(f.fleet_value_inr),0)::bigint,
    coalesce(sum(f.utilization_hours_quarter),0)::bigint
  from ultrasound_probe_fleet_r2967 f
  group by f.chain_name
  order by failed_recall desc, overdue_calibration desc, f.chain_name;
end;
$$;

-- RPC 2: probes overdue / failed-recall
create or replace function founder_r2967_overdue_probes()
returns table (
  chain_name text,
  hospital_site text,
  probe_serial text,
  probe_type text,
  modality text,
  calibration_status text,
  next_calibration_due date,
  days_past_due int,
  fleet_value_inr bigint
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    f.chain_name, f.hospital_site, f.probe_serial, f.probe_type, f.modality,
    f.calibration_status, f.next_calibration_due,
    greatest(0, (current_date - f.next_calibration_due))::int,
    f.fleet_value_inr
  from ultrasound_probe_fleet_r2967 f
  where f.calibration_status in ('overdue','failed_recall')
  order by (current_date - f.next_calibration_due) desc, f.fleet_value_inr desc;
end;
$$;

-- RPC 3: disinfection method mix
create or replace function founder_r2967_disinfection_method_mix()
returns table (
  disinfection_method text,
  probe_count int,
  compliant_count int,
  flagged_count int,
  share_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
declare total int;
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  select count(*) into total from ultrasound_probe_fleet_r2967;
  if total = 0 then total := 1; end if;
  return query
  select
    f.disinfection_method,
    count(*)::int,
    (count(*) filter (where f.disinfection_status = 'compliant'))::int,
    (count(*) filter (where f.disinfection_status in ('missed_cycle','contamination_flag','quarantined')))::int,
    round((count(*)::numeric * 100.0) / total, 2)
  from ultrasound_probe_fleet_r2967 f
  group by f.disinfection_method
  order by probe_count desc;
end;
$$;

-- RPC 4: critical findings open
create or replace function founder_r2967_critical_findings_open()
returns table (
  probe_serial text,
  chain_name text,
  hospital_site text,
  finding_code text,
  severity text,
  patient_safety_impact text,
  remediation_status text,
  cost_to_remediate_inr bigint,
  detected_on date,
  remediation_due date,
  auditor_handle text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    f.probe_serial, f.chain_name, f.hospital_site,
    af.finding_code, af.severity, af.patient_safety_impact,
    af.remediation_status, af.cost_to_remediate_inr,
    af.detected_on, af.remediation_due, af.auditor_handle
  from ultrasound_probe_audit_findings_r2967 af
  join ultrasound_probe_fleet_r2967 f on f.id = af.probe_id
  where af.severity in ('critical','major')
    and af.remediation_status in ('open','in_progress','escalated')
  order by
    case af.severity when 'critical' then 0 when 'major' then 1 else 2 end,
    af.remediation_due asc;
end;
$$;

-- RPC 5: modality risk heatmap
create or replace function founder_r2967_modality_risk_heatmap()
returns table (
  modality text,
  probes_total int,
  open_critical int,
  open_major int,
  high_or_critical_safety int,
  total_remediation_cost_inr bigint
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    f.modality,
    count(distinct f.id)::int,
    (count(*) filter (where af.severity = 'critical' and af.remediation_status in ('open','in_progress','escalated')))::int,
    (count(*) filter (where af.severity = 'major' and af.remediation_status in ('open','in_progress','escalated')))::int,
    (count(*) filter (where af.patient_safety_impact in ('high','critical')))::int,
    coalesce(sum(af.cost_to_remediate_inr) filter (where af.remediation_status in ('open','in_progress','escalated')),0)::bigint
  from ultrasound_probe_fleet_r2967 f
  left join ultrasound_probe_audit_findings_r2967 af on af.probe_id = f.id
  group by f.modality
  order by open_critical desc, open_major desc;
end;
$$;

-- RPC 6: auditor productivity
create or replace function founder_r2967_auditor_productivity()
returns table (
  auditor_handle text,
  findings_logged int,
  critical_findings int,
  remediated int,
  open_or_escalated int,
  remediation_close_rate_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  return query
  select
    af.auditor_handle,
    count(*)::int,
    (count(*) filter (where af.severity = 'critical'))::int,
    (count(*) filter (where af.remediation_status = 'remediated'))::int,
    (count(*) filter (where af.remediation_status in ('open','in_progress','escalated')))::int,
    round(
      ((count(*) filter (where af.remediation_status = 'remediated'))::numeric * 100.0)
      / greatest(count(*)::numeric, 1)
    , 2)
  from ultrasound_probe_audit_findings_r2967 af
  group by af.auditor_handle
  order by findings_logged desc;
end;
$$;

-- RPC 7: quarter executive summary
create or replace function founder_r2967_quarter_executive_summary()
returns table (
  metric text,
  value text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_total int;
  v_overdue int;
  v_failed int;
  v_quarantined int;
  v_value bigint;
  v_open_crit int;
  v_remediation_budget bigint;
  v_chains int;
begin
  if not is_founder() then raise exception 'not_authorized'; end if;
  select count(*), coalesce(sum(fleet_value_inr),0), count(distinct chain_name)
    into v_total, v_value, v_chains
    from ultrasound_probe_fleet_r2967;
  select
    (count(*) filter (where calibration_status = 'overdue'))::int,
    (count(*) filter (where calibration_status = 'failed_recall'))::int,
    (count(*) filter (where disinfection_status = 'quarantined'))::int
    into v_overdue, v_failed, v_quarantined
    from ultrasound_probe_fleet_r2967;
  select
    (count(*) filter (where severity = 'critical' and remediation_status in ('open','in_progress','escalated')))::int,
    coalesce(sum(cost_to_remediate_inr) filter (where remediation_status in ('open','in_progress','escalated')),0)::bigint
    into v_open_crit, v_remediation_budget
    from ultrasound_probe_audit_findings_r2967;

  return query
  select 'Quarter'::text, 'Q2 2026'::text
  union all select 'Hospital chains audited', v_chains::text
  union all select 'Probes in fleet', v_total::text
  union all select 'Overdue calibration', v_overdue::text
  union all select 'Failed-recall probes', v_failed::text
  union all select 'Quarantined probes', v_quarantined::text
  union all select 'Open critical findings', v_open_crit::text
  union all select 'Open remediation budget (INR)', v_remediation_budget::text
  union all select 'Total fleet value (INR)', v_value::text;
end;
$$;

revoke all on function founder_r2967_chain_fleet_rollup() from public, anon;
revoke all on function founder_r2967_overdue_probes() from public, anon;
revoke all on function founder_r2967_disinfection_method_mix() from public, anon;
revoke all on function founder_r2967_critical_findings_open() from public, anon;
revoke all on function founder_r2967_modality_risk_heatmap() from public, anon;
revoke all on function founder_r2967_auditor_productivity() from public, anon;
revoke all on function founder_r2967_quarter_executive_summary() from public, anon;

grant execute on function founder_r2967_chain_fleet_rollup() to authenticated;
grant execute on function founder_r2967_overdue_probes() to authenticated;
grant execute on function founder_r2967_disinfection_method_mix() to authenticated;
grant execute on function founder_r2967_critical_findings_open() to authenticated;
grant execute on function founder_r2967_modality_risk_heatmap() to authenticated;
grant execute on function founder_r2967_auditor_productivity() to authenticated;
grant execute on function founder_r2967_quarter_executive_summary() to authenticated;
