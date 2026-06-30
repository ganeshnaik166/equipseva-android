-- Round 3118: Pediatric ICU Incubator Servo-Temperature Humidity Calibration Audit
-- NICU/PICU quarterly audit: air vs servo skin temp, humidity drift, O2 mix, alarm self-test, CAPA

set search_path = public, pg_temp;

-- =========================================================================
-- Table 1: per-incubator audit visit record
-- =========================================================================
create table if not exists picu_incubator_audits_r3118 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  hospital_name text not null,
  ward_code text not null check (ward_code in ('NICU-L1','NICU-L2','NICU-L3','PICU-A','PICU-B','SCBU')),
  incubator_asset_tag text not null,
  incubator_model text not null check (incubator_model in (
    'Drager Isolette 8000+','GE Giraffe OmniBed','Atom Dual Incu i','Phoenix Phoebe',
    'Fanem 2186 IT','Natus Neo-Blue Incu','Medela Calix-N'
  )),
  audit_quarter text not null check (audit_quarter in ('2026-Q1','2026-Q2','2026-Q3','2026-Q4')),
  audit_date date not null,
  audited_by_engineer_id uuid references engineers(id) on delete set null,
  mode_audited text not null check (mode_audited in ('air_only','servo_skin','dual_mode','transport')),
  air_setpoint_c numeric(4,1) not null check (air_setpoint_c between 28.0 and 39.0),
  air_measured_c numeric(4,1) not null check (air_measured_c between 25.0 and 42.0),
  skin_setpoint_c numeric(4,1) check (skin_setpoint_c between 35.0 and 37.5),
  skin_measured_c numeric(4,1) check (skin_measured_c between 30.0 and 40.0),
  humidity_setpoint_pct numeric(4,1) not null check (humidity_setpoint_pct between 30.0 and 95.0),
  humidity_measured_pct numeric(4,1) not null check (humidity_measured_pct between 10.0 and 99.0),
  o2_setpoint_pct numeric(4,1) check (o2_setpoint_pct between 21.0 and 65.0),
  o2_measured_pct numeric(4,1) check (o2_measured_pct between 18.0 and 70.0),
  air_drift_c numeric(4,2) generated always as (air_measured_c - air_setpoint_c) stored,
  humidity_drift_pct numeric(4,2) generated always as (humidity_measured_pct - humidity_setpoint_pct) stored,
  alarm_self_test_result text not null check (alarm_self_test_result in ('pass','warning','fail','not_run')),
  alarm_fail_codes text,
  servo_probe_condition text check (servo_probe_condition in ('good','frayed','replaced','missing','n_a')),
  hepa_filter_age_days integer check (hepa_filter_age_days between 0 and 1825),
  overall_verdict text not null check (overall_verdict in ('pass','conditional_pass','fail','rework_required')),
  neonatal_safety_risk text not null check (neonatal_safety_risk in ('none','low','medium','high','critical')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_picu_audits_r3118_org on picu_incubator_audits_r3118(organization_id);
create index if not exists idx_picu_audits_r3118_qtr on picu_incubator_audits_r3118(audit_quarter);
create index if not exists idx_picu_audits_r3118_verdict on picu_incubator_audits_r3118(overall_verdict);

-- =========================================================================
-- Table 2: CAPA items raised from audits
-- =========================================================================
create table if not exists picu_incubator_capa_r3118 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references picu_incubator_audits_r3118(id) on delete cascade,
  capa_code text not null,
  capa_category text not null check (capa_category in (
    'temp_drift','humidity_drift','o2_mix_drift','alarm_failure','probe_replacement',
    'hepa_filter_change','calibration_recert','firmware_update','training','documentation'
  )),
  severity text not null check (severity in ('p0_neonatal_critical','p1_high','p2_medium','p3_low')),
  finding_summary text not null,
  corrective_action text not null,
  preventive_action text,
  owner_role text not null check (owner_role in ('biomed_engineer','vendor','nicu_incharge','quality_manager','founder_review')),
  target_close_date date not null,
  actual_close_date date,
  status text not null check (status in ('open','in_progress','closed','escalated','rejected','verified')),
  cost_estimate_rupees integer check (cost_estimate_rupees between 0 and 5000000),
  cost_actual_rupees integer check (cost_actual_rupees between 0 and 5000000),
  evidence_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists idx_picu_capa_r3118_audit on picu_incubator_capa_r3118(audit_id);
create index if not exists idx_picu_capa_r3118_status on picu_incubator_capa_r3118(status);
create index if not exists idx_picu_capa_r3118_severity on picu_incubator_capa_r3118(severity);

-- =========================================================================
-- Seeds
-- =========================================================================
do $seed$
declare
  v_org uuid;
  v_eng uuid;
  v_audit_1 uuid;
  v_audit_2 uuid;
  v_audit_3 uuid;
  v_audit_4 uuid;
  v_audit_5 uuid;
  v_audit_6 uuid;
begin
  select id into v_org from organizations order by created_at asc limit 1;
  if v_org is null then
    return;
  end if;

  select id into v_eng from engineers order by created_at asc limit 1;

  -- Audits (6 rows)
  insert into picu_incubator_audits_r3118 (
    organization_id, hospital_name, ward_code, incubator_asset_tag, incubator_model,
    audit_quarter, audit_date, audited_by_engineer_id, mode_audited,
    air_setpoint_c, air_measured_c, skin_setpoint_c, skin_measured_c,
    humidity_setpoint_pct, humidity_measured_pct, o2_setpoint_pct, o2_measured_pct,
    alarm_self_test_result, alarm_fail_codes, servo_probe_condition,
    hepa_filter_age_days, overall_verdict, neonatal_safety_risk, notes
  ) values
  (v_org, 'Rainbow Children''s Hospital Hyderabad', 'NICU-L3', 'INC-RBC-NICU-014', 'Drager Isolette 8000+',
   '2026-Q2', '2026-04-12', v_eng, 'servo_skin',
   36.5, 36.7, 36.8, 36.9, 65.0, 63.2, 28.0, 27.6,
   'pass', null, 'good', 142, 'pass', 'low', 'All parameters within +/-0.3C; HEPA in spec.'),

  (v_org, 'Rainbow Children''s Hospital Hyderabad', 'NICU-L2', 'INC-RBC-NICU-021', 'GE Giraffe OmniBed',
   '2026-Q2', '2026-04-12', v_eng, 'dual_mode',
   36.0, 36.9, 36.8, 37.4, 70.0, 58.3, 30.0, 28.4,
   'warning', 'AL-204-humidity-low', 'good', 388, 'conditional_pass', 'medium',
   'Humidity drift -11.7pp; reservoir refill cycle off. Recommend hepa change at 18mo mark.'),

  (v_org, 'Apollo Cradle Bengaluru Marathahalli', 'NICU-L3', 'INC-APC-NICU-007', 'Atom Dual Incu i',
   '2026-Q2', '2026-04-18', v_eng, 'servo_skin',
   36.5, 37.8, 37.0, 38.6, 60.0, 41.0, 30.0, 22.8,
   'fail', 'AL-101-skin-overtemp; AL-307-o2-undermix', 'frayed', 612, 'fail', 'critical',
   'Skin overtemp 1.6C above setpoint; O2 7.2pp under; probe frayed - removed from service immediately.'),

  (v_org, 'Fortis La Femme Chennai', 'PICU-A', 'INC-FLF-PICU-003', 'Phoenix Phoebe',
   '2026-Q2', '2026-04-22', v_eng, 'air_only',
   34.0, 34.2, null, null, 55.0, 54.1, null, null,
   'pass', null, 'n_a', 95, 'pass', 'none', 'Routine PICU transport-bay incubator; air mode only.'),

  (v_org, 'Manipal Hospital Whitefield NICU', 'NICU-L2', 'INC-MHW-NICU-019', 'Fanem 2186 IT',
   '2026-Q2', '2026-04-25', v_eng, 'dual_mode',
   36.2, 36.4, 36.8, 37.0, 75.0, 72.6, 25.0, 24.1,
   'pass', null, 'replaced', 31, 'pass', 'low', 'Probe replaced at start of quarter; new HEPA installed Mar-2026.'),

  (v_org, 'KIMS Cuddles Kondapur', 'SCBU', 'INC-KMS-SCBU-002', 'Natus Neo-Blue Incu',
   '2026-Q2', '2026-04-28', v_eng, 'transport',
   35.5, 35.9, 36.5, 37.2, 50.0, 47.8, null, null,
   'warning', 'AL-509-battery-low', 'good', 256, 'conditional_pass', 'medium',
   'Transport battery alarm at 11min runtime; replace UPS pack before next quarter.');

  -- Fetch ids
  select id into v_audit_1 from picu_incubator_audits_r3118 where incubator_asset_tag = 'INC-RBC-NICU-014' limit 1;
  select id into v_audit_2 from picu_incubator_audits_r3118 where incubator_asset_tag = 'INC-RBC-NICU-021' limit 1;
  select id into v_audit_3 from picu_incubator_audits_r3118 where incubator_asset_tag = 'INC-APC-NICU-007' limit 1;
  select id into v_audit_4 from picu_incubator_audits_r3118 where incubator_asset_tag = 'INC-FLF-PICU-003' limit 1;
  select id into v_audit_5 from picu_incubator_audits_r3118 where incubator_asset_tag = 'INC-MHW-NICU-019' limit 1;
  select id into v_audit_6 from picu_incubator_audits_r3118 where incubator_asset_tag = 'INC-KMS-SCBU-002' limit 1;

  -- CAPA items (12 rows linked to the 6 audits)
  insert into picu_incubator_capa_r3118 (
    audit_id, capa_code, capa_category, severity, finding_summary, corrective_action,
    preventive_action, owner_role, target_close_date, actual_close_date, status,
    cost_estimate_rupees, cost_actual_rupees, evidence_url
  ) values
  (v_audit_2, 'CAPA-3118-001', 'humidity_drift', 'p2_medium',
   'Humidity measured 58.3% vs setpoint 70% (-11.7pp drift)',
   'Descale reservoir, replace humidifier wick, recalibrate RH sensor',
   'Add monthly RH spot-check to PM checklist',
   'biomed_engineer', '2026-05-15', '2026-05-09', 'closed', 8500, 7200,
   'https://evidence.equipseva.in/r3118/capa001.pdf'),

  (v_audit_2, 'CAPA-3118-002', 'hepa_filter_change', 'p3_low',
   'HEPA filter age 388 days, approaching 18-month replacement',
   'Schedule HEPA replacement at 18-month mark',
   'Auto-flag HEPA > 540 days in dashboard',
   'biomed_engineer', '2026-07-01', null, 'in_progress', 12000, null, null),

  (v_audit_3, 'CAPA-3118-003', 'temp_drift', 'p0_neonatal_critical',
   'Skin probe overtemp 1.6C - neonatal hyperthermia risk',
   'Remove unit from service; replace skin probe; full recert before return',
   'Mandatory probe inspection at every audit; add probe-age tracking',
   'vendor', '2026-04-20', '2026-04-19', 'verified', 35000, 38500,
   'https://evidence.equipseva.in/r3118/capa003-probe.pdf'),

  (v_audit_3, 'CAPA-3118-004', 'o2_mix_drift', 'p0_neonatal_critical',
   'O2 measured 22.8% vs setpoint 30% (-7.2pp) - ROP/hypoxia risk',
   'Recalibrate O2 cell, replace if drift persists, full mixing valve service',
   'Add O2 cell expiry tracking; flag cells > 2yr',
   'vendor', '2026-04-20', '2026-04-19', 'verified', 18000, 16500,
   'https://evidence.equipseva.in/r3118/capa004-o2.pdf'),

  (v_audit_3, 'CAPA-3118-005', 'alarm_failure', 'p1_high',
   'Skin overtemp + O2 undermix alarms triggered correctly but no escalation logged',
   'Configure alarm-relay to nurse station; verify audible + visual',
   'Quarterly alarm-to-station end-to-end test',
   'nicu_incharge', '2026-05-31', null, 'in_progress', 5500, null, null),

  (v_audit_3, 'CAPA-3118-006', 'probe_replacement', 'p1_high',
   'Servo skin probe frayed at strain-relief',
   'Replaced with OEM probe part #SP-2200-N',
   'Stock minimum 2 spare probes per NICU',
   'biomed_engineer', '2026-04-19', '2026-04-19', 'closed', 4200, 4200, null),

  (v_audit_6, 'CAPA-3118-007', 'calibration_recert', 'p2_medium',
   'Transport battery cut off at 11min vs 60min spec',
   'Replace transport UPS pack; recert battery hold-up',
   'Add transport runtime test to quarterly audit',
   'biomed_engineer', '2026-06-15', null, 'open', 22000, null, null),

  (v_audit_5, 'CAPA-3118-008', 'documentation', 'p3_low',
   'HEPA replacement log not signed off',
   'Backfill HEPA replacement record with engineer signature',
   'Lock incubator out-of-service if PM log incomplete',
   'quality_manager', '2026-05-10', '2026-05-08', 'closed', 0, 0, null),

  (v_audit_1, 'CAPA-3118-009', 'training', 'p3_low',
   'Two NICU nurses not yet trained on Isolette 8000+ alarm panel',
   'Schedule OEM-led 2hr training session',
   'Add new-staff incubator training to onboarding checklist',
   'nicu_incharge', '2026-06-30', null, 'open', 0, null, null),

  (v_audit_3, 'CAPA-3118-010', 'firmware_update', 'p2_medium',
   'Unit still on firmware v3.1; v3.4 fixes O2 mixing valve drift',
   'OEM to push firmware v3.4 during recert',
   'Quarterly firmware-version sweep across fleet',
   'vendor', '2026-04-20', '2026-04-19', 'verified', 0, 0, null),

  (v_audit_2, 'CAPA-3118-011', 'alarm_failure', 'p2_medium',
   'Humidity-low alarm AL-204 triggered but no caregiver acknowledgement logged',
   'Enable mandatory ack with PIN on humidity alarms',
   'Audit alarm-ack compliance monthly',
   'nicu_incharge', '2026-06-01', null, 'in_progress', 3000, null, null),

  (v_audit_4, 'CAPA-3118-012', 'documentation', 'p3_low',
   'Transport-bay incubator missing serial number on asset register',
   'Update asset register, affix new serialised label',
   'Reconcile transport-bay assets every quarter',
   'quality_manager', '2026-05-20', '2026-05-19', 'closed', 0, 0, null);

end
$seed$;

-- =========================================================================
-- RPC 1: per-ward audit verdict rollup
-- =========================================================================
create or replace function rpc_picu_audit_ward_rollup_r3118()
returns table (
  ward_code text,
  total_audits bigint,
  pass_count bigint,
  conditional_count bigint,
  fail_count bigint,
  critical_risk_count bigint,
  avg_air_drift_c numeric,
  avg_humidity_drift_pp numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      a.ward_code,
      count(*)::bigint,
      count(*) filter (where a.overall_verdict = 'pass')::bigint,
      count(*) filter (where a.overall_verdict = 'conditional_pass')::bigint,
      count(*) filter (where a.overall_verdict in ('fail','rework_required'))::bigint,
      count(*) filter (where a.neonatal_safety_risk = 'critical')::bigint,
      round(avg(a.air_drift_c)::numeric, 2),
      round(avg(a.humidity_drift_pct)::numeric, 2)
    from picu_incubator_audits_r3118 a
    group by a.ward_code
    order by a.ward_code;
end;
$$;

revoke execute on function rpc_picu_audit_ward_rollup_r3118() from public, anon;
grant execute on function rpc_picu_audit_ward_rollup_r3118() to authenticated;

-- =========================================================================
-- RPC 2: model fleet drift summary
-- =========================================================================
create or replace function rpc_picu_audit_model_drift_r3118()
returns table (
  incubator_model text,
  units_audited bigint,
  max_air_drift_c numeric,
  max_humidity_drift_pp numeric,
  models_with_critical bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      a.incubator_model,
      count(*)::bigint,
      round(max(abs(a.air_drift_c))::numeric, 2),
      round(max(abs(a.humidity_drift_pct))::numeric, 2),
      count(*) filter (where a.neonatal_safety_risk = 'critical')::bigint
    from picu_incubator_audits_r3118 a
    group by a.incubator_model
    order by max(abs(a.air_drift_c)) desc;
end;
$$;

revoke execute on function rpc_picu_audit_model_drift_r3118() from public, anon;
grant execute on function rpc_picu_audit_model_drift_r3118() to authenticated;

-- =========================================================================
-- RPC 3: alarm self-test summary
-- =========================================================================
create or replace function rpc_picu_alarm_selftest_r3118()
returns table (
  alarm_self_test_result text,
  result_count bigint,
  units_with_codes bigint,
  share_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_total bigint;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  select count(*) into v_total from picu_incubator_audits_r3118;
  if v_total = 0 then v_total := 1; end if;

  return query
    select
      a.alarm_self_test_result,
      count(*)::bigint,
      count(*) filter (where a.alarm_fail_codes is not null)::bigint,
      round((count(*)::numeric / v_total) * 100, 1)
    from picu_incubator_audits_r3118 a
    group by a.alarm_self_test_result
    order by count(*) desc;
end;
$$;

revoke execute on function rpc_picu_alarm_selftest_r3118() from public, anon;
grant execute on function rpc_picu_alarm_selftest_r3118() to authenticated;

-- =========================================================================
-- RPC 4: CAPA severity board
-- =========================================================================
create or replace function rpc_picu_capa_severity_r3118()
returns table (
  severity text,
  total_items bigint,
  open_or_in_progress bigint,
  closed_or_verified bigint,
  escalated_count bigint,
  total_cost_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      c.severity,
      count(*)::bigint,
      count(*) filter (where c.status in ('open','in_progress'))::bigint,
      count(*) filter (where c.status in ('closed','verified'))::bigint,
      count(*) filter (where c.status = 'escalated')::bigint,
      coalesce(sum(coalesce(c.cost_actual_rupees, c.cost_estimate_rupees, 0)),0)::bigint
    from picu_incubator_capa_r3118 c
    group by c.severity
    order by case c.severity
      when 'p0_neonatal_critical' then 0
      when 'p1_high' then 1
      when 'p2_medium' then 2
      when 'p3_low' then 3
      else 99
    end;
end;
$$;

revoke execute on function rpc_picu_capa_severity_r3118() from public, anon;
grant execute on function rpc_picu_capa_severity_r3118() to authenticated;

-- =========================================================================
-- RPC 5: CAPA category breakdown
-- =========================================================================
create or replace function rpc_picu_capa_category_r3118()
returns table (
  capa_category text,
  item_count bigint,
  open_count bigint,
  avg_target_lead_days numeric,
  total_actual_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      c.capa_category,
      count(*)::bigint,
      count(*) filter (where c.status in ('open','in_progress','escalated'))::bigint,
      round(avg(c.target_close_date - (select audit_date from picu_incubator_audits_r3118 a where a.id = c.audit_id))::numeric, 1),
      coalesce(sum(coalesce(c.cost_actual_rupees, 0)),0)::bigint
    from picu_incubator_capa_r3118 c
    group by c.capa_category
    order by count(*) desc;
end;
$$;

revoke execute on function rpc_picu_capa_category_r3118() from public, anon;
grant execute on function rpc_picu_capa_category_r3118() to authenticated;

-- =========================================================================
-- RPC 6: hospital-level safety scorecard
-- =========================================================================
create or replace function rpc_picu_hospital_scorecard_r3118()
returns table (
  hospital_name text,
  audits_this_quarter bigint,
  critical_findings bigint,
  open_p0_p1_capas bigint,
  pass_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      a.hospital_name,
      count(distinct a.id)::bigint,
      count(*) filter (where a.neonatal_safety_risk = 'critical')::bigint,
      (select count(*)::bigint
         from picu_incubator_capa_r3118 c
         join picu_incubator_audits_r3118 aa on aa.id = c.audit_id
         where aa.hospital_name = a.hospital_name
           and c.severity in ('p0_neonatal_critical','p1_high')
           and c.status in ('open','in_progress','escalated')),
      round(
        (count(*) filter (where a.overall_verdict = 'pass')::numeric
          / nullif(count(*)::numeric, 0)) * 100, 1
      )
    from picu_incubator_audits_r3118 a
    group by a.hospital_name
    order by count(*) filter (where a.neonatal_safety_risk = 'critical') desc, a.hospital_name;
end;
$$;

revoke execute on function rpc_picu_hospital_scorecard_r3118() from public, anon;
grant execute on function rpc_picu_hospital_scorecard_r3118() to authenticated;

-- =========================================================================
-- RPC 7: open CAPA backlog list (worst-first)
-- =========================================================================
create or replace function rpc_picu_open_capa_backlog_r3118()
returns table (
  capa_code text,
  severity text,
  capa_category text,
  hospital_name text,
  ward_code text,
  asset_tag text,
  target_close_date date,
  days_to_target integer,
  owner_role text,
  status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      c.capa_code,
      c.severity,
      c.capa_category,
      a.hospital_name,
      a.ward_code,
      a.incubator_asset_tag,
      c.target_close_date,
      (c.target_close_date - current_date)::integer,
      c.owner_role,
      c.status
    from picu_incubator_capa_r3118 c
    join picu_incubator_audits_r3118 a on a.id = c.audit_id
    where c.status in ('open','in_progress','escalated')
    order by
      case c.severity
        when 'p0_neonatal_critical' then 0
        when 'p1_high' then 1
        when 'p2_medium' then 2
        when 'p3_low' then 3
        else 99
      end,
      c.target_close_date asc;
end;
$$;

revoke execute on function rpc_picu_open_capa_backlog_r3118() from public, anon;
grant execute on function rpc_picu_open_capa_backlog_r3118() to authenticated;

-- =========================================================================
-- RPC 8: HEPA filter / probe condition risk roll-up
-- =========================================================================
create or replace function rpc_picu_consumables_risk_r3118()
returns table (
  servo_probe_condition text,
  units bigint,
  avg_hepa_age_days numeric,
  units_with_critical_risk bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;

  return query
    select
      coalesce(a.servo_probe_condition, 'unspecified'),
      count(*)::bigint,
      round(avg(a.hepa_filter_age_days)::numeric, 0),
      count(*) filter (where a.neonatal_safety_risk = 'critical')::bigint
    from picu_incubator_audits_r3118 a
    group by a.servo_probe_condition
    order by count(*) desc;
end;
$$;

revoke execute on function rpc_picu_consumables_risk_r3118() from public, anon;
grant execute on function rpc_picu_consumables_risk_r3118() to authenticated;
