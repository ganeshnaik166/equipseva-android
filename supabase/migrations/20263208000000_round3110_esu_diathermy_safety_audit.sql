-- Round 3110: Customer Hospital Surgical Diathermy ESU Output-Power & Patient-Plate Safety Audit
-- Quarterly electrosurgical-unit (ESU/diathermy) audit:
--   set vs delivered watts x pure-cut/coag/blend mode x REM patient-plate impedance x leakage current x CAPA

-- ============================================================================
-- Table 1: ESU output-power & mode delivery measurements
-- ============================================================================
create table if not exists esu_output_power_audits_r3110 (
  id uuid primary key default gen_random_uuid(),
  audit_ref text not null unique,
  hospital_org_id uuid not null references organizations(id) on delete restrict,
  ot_room_label text not null,
  esu_make_model text not null,
  esu_serial_no text not null,
  audit_quarter text not null check (audit_quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026','Q1-2027')),
  audit_date date not null,
  mode text not null check (mode in ('pure_cut','blend_1','blend_2','blend_3','coag_soft','coag_fulgurate','coag_spray','bipolar')),
  set_watts numeric(6,1) not null check (set_watts > 0 and set_watts <= 400),
  delivered_watts_min numeric(6,1) not null check (delivered_watts_min >= 0),
  delivered_watts_max numeric(6,1) not null check (delivered_watts_max >= 0),
  delivered_watts_avg numeric(6,1) not null check (delivered_watts_avg >= 0),
  load_impedance_ohms integer not null check (load_impedance_ohms between 50 and 2000),
  hf_leakage_ma numeric(6,2) not null check (hf_leakage_ma >= 0),
  crest_factor numeric(4,2),
  deviation_pct numeric(6,2) generated always as (
    case when set_watts > 0 then ((delivered_watts_avg - set_watts) / set_watts) * 100 else 0 end
  ) stored,
  iec_60601_2_2_band text not null check (iec_60601_2_2_band in ('within_spec','marginal','out_of_spec','critical_out_of_spec')),
  outcome text not null check (outcome in ('passed','passed_with_note','failed_recalibrate','failed_withdraw','failed_replace')),
  engineer_id uuid references engineers(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_esu_audits_r3110_org on esu_output_power_audits_r3110(hospital_org_id);
create index if not exists idx_esu_audits_r3110_quarter on esu_output_power_audits_r3110(audit_quarter);
create index if not exists idx_esu_audits_r3110_outcome on esu_output_power_audits_r3110(outcome);

-- ============================================================================
-- Table 2: REM patient-plate impedance + CAPA tracking per audit
-- ============================================================================
create table if not exists esu_plate_capa_findings_r3110 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references esu_output_power_audits_r3110(id) on delete cascade,
  finding_ref text not null unique,
  rem_system text not null check (rem_system in ('split_plate_rem','dual_zone_contact','single_pad_no_rem','disposable_split','reusable_silicone')),
  plate_impedance_start_ohms integer check (plate_impedance_start_ohms between 5 and 500),
  plate_impedance_end_ohms integer check (plate_impedance_end_ohms between 5 and 500),
  rem_alarm_trigger_threshold_ohms integer check (rem_alarm_trigger_threshold_ohms between 10 and 300),
  contact_quality_pct numeric(5,2) check (contact_quality_pct between 0 and 100),
  burn_risk_level text not null check (burn_risk_level in ('negligible','low','moderate','high','critical')),
  leakage_lf_ma numeric(6,2) check (leakage_lf_ma >= 0),
  isolation_test_kv numeric(4,2),
  cable_integrity text not null check (cable_integrity in ('intact','minor_wear','damaged_shield','broken_strand','replace_now')),
  finding_severity text not null check (finding_severity in ('observation','minor_nc','major_nc','critical_nc')),
  capa_status text not null check (capa_status in ('open','in_progress','awaiting_part','re_test_due','closed','escalated_to_founder')),
  capa_owner text not null check (capa_owner in ('biomed_engineer','ot_incharge','vendor','hospital_admin','equipseva_engineer')),
  due_at timestamptz,
  closed_at timestamptz,
  remediation_notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_esu_capa_r3110_audit on esu_plate_capa_findings_r3110(audit_id);
create index if not exists idx_esu_capa_r3110_status on esu_plate_capa_findings_r3110(capa_status);
create index if not exists idx_esu_capa_r3110_severity on esu_plate_capa_findings_r3110(finding_severity);

-- ============================================================================
-- Seed data (12 rows across both tables)
-- ============================================================================
do $$
declare
  v_org uuid;
  v_eng uuid;
  v_a1 uuid; v_a2 uuid; v_a3 uuid; v_a4 uuid;
  v_a5 uuid; v_a6 uuid; v_a7 uuid;
begin
  select id into v_org from organizations order by created_at asc limit 1;
  if v_org is null then
    raise notice 'no organizations row — skipping r3110 seed';
    return;
  end if;

  select id into v_eng from engineers order by created_at asc limit 1;

  insert into esu_output_power_audits_r3110(
    audit_ref, hospital_org_id, ot_room_label, esu_make_model, esu_serial_no,
    audit_quarter, audit_date, mode, set_watts,
    delivered_watts_min, delivered_watts_max, delivered_watts_avg,
    load_impedance_ohms, hf_leakage_ma, crest_factor,
    iec_60601_2_2_band, outcome, engineer_id, notes
  ) values
    ('ESU-Q2-26-AP01', v_org, 'OT-1 Cardiac', 'Valleylab Force FX-C', 'FXC-IN-44218',
     'Q2-2026', '2026-04-12', 'pure_cut', 80.0, 76.4, 81.2, 78.9,
     300, 0.18, 1.45, 'within_spec', 'passed', v_eng,
     'Apollo Hyderabad — annual NABH audit, within IEC 60601-2-2 +/-20% band'),
    ('ESU-Q2-26-AP02', v_org, 'OT-1 Cardiac', 'Valleylab Force FX-C', 'FXC-IN-44218',
     'Q2-2026', '2026-04-12', 'coag_fulgurate', 60.0, 52.1, 58.4, 55.6,
     500, 0.42, 5.80, 'marginal', 'passed_with_note', v_eng,
     'Fulgurate deviation -7.3% — within band but crest factor trending high'),
    ('ESU-Q2-26-FT03', v_org, 'OT-2 General', 'Erbe VIO 300D', 'VIO-IN-77901',
     'Q2-2026', '2026-04-18', 'blend_2', 100.0, 88.2, 95.4, 91.8,
     500, 0.28, 2.10, 'within_spec', 'passed', v_eng,
     'Fortis BG Road — blend-mode delivered within -8.2% of set'),
    ('ESU-Q2-26-FT04', v_org, 'OT-2 General', 'Erbe VIO 300D', 'VIO-IN-77901',
     'Q2-2026', '2026-04-18', 'bipolar', 40.0, 38.1, 41.0, 39.6,
     100, 0.09, 1.30, 'within_spec', 'passed', v_eng,
     'Bipolar tight tolerance — neurosurgery list cleared'),
    ('ESU-Q3-26-MX05', v_org, 'OT-3 Ortho', 'Bovie IDS-310', 'IDS-IN-19883',
     'Q3-2026', '2026-07-04', 'coag_soft', 50.0, 32.0, 41.5, 36.8,
     500, 0.95, 4.20, 'out_of_spec', 'failed_recalibrate', v_eng,
     'Max Saket — coag soft delivering -26% of set; pulled from roster pending recal'),
    ('ESU-Q3-26-MX06', v_org, 'OT-3 Ortho', 'Bovie IDS-310', 'IDS-IN-19883',
     'Q3-2026', '2026-07-04', 'pure_cut', 70.0, 48.2, 60.1, 54.4,
     300, 1.20, 1.85, 'critical_out_of_spec', 'failed_withdraw', v_eng,
     'Pure-cut -22.3% deviation + HF leakage above 1mA — IMMEDIATE withdraw'),
    ('ESU-Q3-26-MN07', v_org, 'OT-4 Obs-Gyn', 'Medtronic Valleylab FT10', 'FT10-IN-55411',
     'Q3-2026', '2026-07-22', 'blend_1', 90.0, 86.0, 93.2, 89.1,
     500, 0.21, 1.95, 'within_spec', 'passed', v_eng,
     'Manipal Old Airport Rd — FT10 within spec across full sweep'),
    ('ESU-Q3-26-NR08', v_org, 'OT-1 Neuro', 'KLS Martin maXium smart C', 'MXM-IN-33902',
     'Q3-2026', '2026-08-14', 'bipolar', 30.0, 14.8, 22.4, 18.6,
     100, 0.62, 3.40, 'critical_out_of_spec', 'failed_replace', v_eng,
     'Narayana Health City — bipolar delivering 62% of set; replacement quoted'),
    ('ESU-Q4-26-KL09', v_org, 'OT-2 ENT', 'Olympus ESG-400', 'ESG-IN-66127',
     'Q4-2026', '2026-10-09', 'coag_spray', 45.0, 42.1, 47.0, 44.6,
     500, 0.31, 6.50, 'marginal', 'passed_with_note', v_eng,
     'Kokilaben Mumbai — crest factor 6.5 close to upper limit, monitor next quarter');

  -- pull audit IDs for CAPA findings
  select id into v_a1 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q2-26-AP02' limit 1;
  select id into v_a2 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q3-26-MX05' limit 1;
  select id into v_a3 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q3-26-MX06' limit 1;
  select id into v_a4 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q3-26-NR08' limit 1;
  select id into v_a5 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q4-26-KL09' limit 1;
  select id into v_a6 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q2-26-FT03' limit 1;
  select id into v_a7 from esu_output_power_audits_r3110 where audit_ref = 'ESU-Q3-26-MN07' limit 1;

  insert into esu_plate_capa_findings_r3110(
    audit_id, finding_ref, rem_system,
    plate_impedance_start_ohms, plate_impedance_end_ohms, rem_alarm_trigger_threshold_ohms,
    contact_quality_pct, burn_risk_level, leakage_lf_ma, isolation_test_kv,
    cable_integrity, finding_severity, capa_status, capa_owner,
    due_at, closed_at, remediation_notes
  ) values
    (v_a1, 'CAPA-AP02-001', 'split_plate_rem',
     45, 52, 135, 92.50, 'low', 0.08, 4.00,
     'intact', 'observation', 'closed', 'biomed_engineer',
     '2026-05-10T18:00:00+05:30'::timestamptz, '2026-05-08T11:20:00+05:30'::timestamptz,
     'Crest factor logged; vendor confirmed within published tolerance, no action required'),
    (v_a2, 'CAPA-MX05-002', 'split_plate_rem',
     78, 142, 135, 71.30, 'high', 0.55, 3.80,
     'minor_wear', 'major_nc', 'in_progress', 'equipseva_engineer',
     '2026-07-25T17:00:00+05:30'::timestamptz, null,
     'Re-calibration scheduled; plate cable shows wear at strain relief, replacement ordered'),
    (v_a3, 'CAPA-MX06-003', 'single_pad_no_rem',
     null, null, 200, 0.00, 'critical', 1.20, null,
     'broken_strand', 'critical_nc', 'escalated_to_founder', 'hospital_admin',
     '2026-07-08T12:00:00+05:30'::timestamptz, null,
     'No REM monitoring + broken plate cable strand — IMMEDIATE removal from service, founder escalation'),
    (v_a4, 'CAPA-NR08-004', 'dual_zone_contact',
     35, 88, 120, 84.10, 'moderate', 0.30, 4.20,
     'damaged_shield', 'major_nc', 'awaiting_part', 'vendor',
     '2026-09-15T16:00:00+05:30'::timestamptz, null,
     'Bipolar output low + plate shield damage; KLS Martin part ETA 18 days'),
    (v_a5, 'CAPA-KL09-005', 'disposable_split',
     22, 28, 100, 96.80, 'negligible', 0.05, 4.50,
     'intact', 'observation', 're_test_due', 'biomed_engineer',
     '2027-01-12T15:00:00+05:30'::timestamptz, null,
     'Crest factor watch — re-test scheduled with Q1-2027 audit'),
    (v_a6, 'CAPA-FT03-006', 'reusable_silicone',
     null, null, 150, 88.90, 'low', 0.12, 4.10,
     'intact', 'minor_nc', 'open', 'ot_incharge',
     '2026-05-30T18:00:00+05:30'::timestamptz, null,
     'Silicone plate showing surface tackiness loss — quote replacement set'),
    (v_a7, 'CAPA-MN07-007', 'split_plate_rem',
     40, 46, 135, 94.20, 'negligible', 0.10, 4.30,
     'intact', 'observation', 'closed', 'biomed_engineer',
     '2026-08-15T18:00:00+05:30'::timestamptz, '2026-08-02T10:00:00+05:30'::timestamptz,
     'Clean pass; documented for NABH evidence file');
end$$;

-- ============================================================================
-- Founder-gated RPCs (10 total)
-- ============================================================================

-- 1) Roster of all ESU audits with deviation
create or replace function founder_esu_audit_roster_r3110()
returns table(
  audit_ref text,
  ot_room_label text,
  esu_make_model text,
  audit_quarter text,
  audit_date date,
  mode text,
  set_watts numeric,
  delivered_watts_avg numeric,
  deviation_pct numeric,
  iec_60601_2_2_band text,
  outcome text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_ref, a.ot_room_label, a.esu_make_model,
         a.audit_quarter, a.audit_date, a.mode,
         a.set_watts, a.delivered_watts_avg, a.deviation_pct,
         a.iec_60601_2_2_band, a.outcome
  from esu_output_power_audits_r3110 a
  order by a.audit_date desc, a.audit_ref asc;
end;
$$;

revoke execute on function founder_esu_audit_roster_r3110() from public, anon;
grant execute on function founder_esu_audit_roster_r3110() to authenticated;

-- 2) Outcome rollup
create or replace function founder_esu_outcome_rollup_r3110()
returns table(outcome text, audit_count bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.outcome, count(*)::bigint,
         round(avg(a.deviation_pct)::numeric, 2)
  from esu_output_power_audits_r3110 a
  group by a.outcome
  order by count(*) desc;
end;
$$;

revoke execute on function founder_esu_outcome_rollup_r3110() from public, anon;
grant execute on function founder_esu_outcome_rollup_r3110() to authenticated;

-- 3) Mode x band cross-tab
create or replace function founder_esu_mode_band_crosstab_r3110()
returns table(mode text, iec_60601_2_2_band text, audit_count bigint, avg_abs_deviation numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.mode, a.iec_60601_2_2_band, count(*)::bigint,
         round(avg(abs(a.deviation_pct))::numeric, 2)
  from esu_output_power_audits_r3110 a
  group by a.mode, a.iec_60601_2_2_band
  order by a.mode, a.iec_60601_2_2_band;
end;
$$;

revoke execute on function founder_esu_mode_band_crosstab_r3110() from public, anon;
grant execute on function founder_esu_mode_band_crosstab_r3110() to authenticated;

-- 4) HF leakage offenders (above 0.3 mA)
create or replace function founder_esu_hf_leakage_offenders_r3110()
returns table(
  audit_ref text,
  esu_make_model text,
  mode text,
  hf_leakage_ma numeric,
  outcome text,
  audit_date date
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_ref, a.esu_make_model, a.mode, a.hf_leakage_ma, a.outcome, a.audit_date
  from esu_output_power_audits_r3110 a
  where a.hf_leakage_ma > 0.30
  order by a.hf_leakage_ma desc;
end;
$$;

revoke execute on function founder_esu_hf_leakage_offenders_r3110() from public, anon;
grant execute on function founder_esu_hf_leakage_offenders_r3110() to authenticated;

-- 5) CAPA roster
create or replace function founder_esu_capa_roster_r3110()
returns table(
  finding_ref text,
  audit_ref text,
  rem_system text,
  burn_risk_level text,
  finding_severity text,
  capa_status text,
  capa_owner text,
  due_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_ref, a.audit_ref, c.rem_system,
         c.burn_risk_level, c.finding_severity, c.capa_status,
         c.capa_owner, c.due_at
  from esu_plate_capa_findings_r3110 c
  join esu_output_power_audits_r3110 a on a.id = c.audit_id
  order by
    case c.finding_severity
      when 'critical_nc' then 1 when 'major_nc' then 2
      when 'minor_nc' then 3 else 4 end,
    c.due_at nulls last;
end;
$$;

revoke execute on function founder_esu_capa_roster_r3110() from public, anon;
grant execute on function founder_esu_capa_roster_r3110() to authenticated;

-- 6) Burn-risk distribution
create or replace function founder_esu_burn_risk_distribution_r3110()
returns table(burn_risk_level text, finding_count bigint, open_count bigint, avg_contact_quality numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.burn_risk_level, count(*)::bigint,
         count(*) filter (where c.capa_status not in ('closed'))::bigint,
         round(avg(c.contact_quality_pct)::numeric, 2)
  from esu_plate_capa_findings_r3110 c
  group by c.burn_risk_level
  order by
    case c.burn_risk_level
      when 'critical' then 1 when 'high' then 2 when 'moderate' then 3
      when 'low' then 4 else 5 end;
end;
$$;

revoke execute on function founder_esu_burn_risk_distribution_r3110() from public, anon;
grant execute on function founder_esu_burn_risk_distribution_r3110() to authenticated;

-- 7) CAPA aging
create or replace function founder_esu_capa_aging_r3110()
returns table(
  finding_ref text,
  capa_status text,
  capa_owner text,
  days_open numeric,
  due_at timestamptz,
  remediation_notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_ref, c.capa_status, c.capa_owner,
         round(extract(epoch from (coalesce(c.closed_at, now()) - c.created_at))::numeric / 86400.0, 1),
         c.due_at, c.remediation_notes
  from esu_plate_capa_findings_r3110 c
  where c.capa_status <> 'closed'
  order by c.created_at asc;
end;
$$;

revoke execute on function founder_esu_capa_aging_r3110() from public, anon;
grant execute on function founder_esu_capa_aging_r3110() to authenticated;

-- 8) Quarterly trend
create or replace function founder_esu_quarterly_trend_r3110()
returns table(
  audit_quarter text,
  audits bigint,
  failures bigint,
  failure_rate_pct numeric,
  avg_abs_deviation numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.audit_quarter,
         count(*)::bigint,
         count(*) filter (where a.outcome like 'failed%')::bigint,
         round(
           (count(*) filter (where a.outcome like 'failed%'))::numeric
           / nullif(count(*), 0) * 100, 2),
         round(avg(abs(a.deviation_pct))::numeric, 2)
  from esu_output_power_audits_r3110 a
  group by a.audit_quarter
  order by a.audit_quarter;
end;
$$;

revoke execute on function founder_esu_quarterly_trend_r3110() from public, anon;
grant execute on function founder_esu_quarterly_trend_r3110() to authenticated;

-- 9) Cable integrity hot list
create or replace function founder_esu_cable_integrity_hotlist_r3110()
returns table(
  finding_ref text,
  audit_ref text,
  cable_integrity text,
  rem_system text,
  burn_risk_level text,
  capa_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_ref, a.audit_ref, c.cable_integrity, c.rem_system,
         c.burn_risk_level, c.capa_status
  from esu_plate_capa_findings_r3110 c
  join esu_output_power_audits_r3110 a on a.id = c.audit_id
  where c.cable_integrity in ('minor_wear','damaged_shield','broken_strand','replace_now')
  order by
    case c.cable_integrity
      when 'broken_strand' then 1 when 'replace_now' then 2
      when 'damaged_shield' then 3 when 'minor_wear' then 4 else 5 end;
end;
$$;

revoke execute on function founder_esu_cable_integrity_hotlist_r3110() from public, anon;
grant execute on function founder_esu_cable_integrity_hotlist_r3110() to authenticated;

-- 10) Top headline KPIs
create or replace function founder_esu_safety_headline_r3110()
returns table(
  total_audits bigint,
  failed_audits bigint,
  critical_band_audits bigint,
  open_capas bigint,
  escalated_capas bigint,
  avg_abs_deviation numeric,
  max_hf_leakage_ma numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    (select count(*)::bigint from esu_output_power_audits_r3110),
    (select count(*)::bigint from esu_output_power_audits_r3110 where outcome like 'failed%'),
    (select count(*)::bigint from esu_output_power_audits_r3110 where iec_60601_2_2_band = 'critical_out_of_spec'),
    (select count(*)::bigint from esu_plate_capa_findings_r3110 where capa_status <> 'closed'),
    (select count(*)::bigint from esu_plate_capa_findings_r3110 where capa_status = 'escalated_to_founder'),
    (select round(avg(abs(deviation_pct))::numeric, 2) from esu_output_power_audits_r3110),
    (select max(hf_leakage_ma) from esu_output_power_audits_r3110);
end;
$$;

revoke execute on function founder_esu_safety_headline_r3110() from public, anon;
grant execute on function founder_esu_safety_headline_r3110() to authenticated;
