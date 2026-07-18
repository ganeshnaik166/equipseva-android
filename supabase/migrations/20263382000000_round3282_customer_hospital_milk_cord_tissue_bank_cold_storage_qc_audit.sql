-- Round 3282: Customer Hospital Milk-Bank / Cord-Blood / Tissue-Bank Cold-Storage & Processing QC Audit
-- Cold-chain QA — device type × bank type × temperature-in-range × pasteurization Holder cycle × LN2 level × alarm test × chart recorder × backup power × contamination control × calibration × CAPA

-- =============================================================================
-- TABLE 1: milk_tissue_bank_qc_r3282 — per-device cold-storage / processing QC checks
-- =============================================================================
create table if not exists public.milk_tissue_bank_qc_r3282 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'milk_pasteurizer','minus20_freezer','minus80_freezer','ln2_cryotank',
    'refrigerated_centrifuge','controlled_rate_freezer','milk_analyzer'
  )),
  bank_type text not null check (bank_type in (
    'milk_bank','cord_blood_bank','tissue_bank'
  )),
  check_date date not null,
  temp_reading_c numeric(6,2),
  temp_in_range boolean not null,
  pasteurization_cycle_ok text not null check (pasteurization_cycle_ok in (
    'pass','fail','not_applicable'
  )),
  ln2_level_pct numeric(5,2),
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  chart_recorder_ok boolean not null,
  backup_power_ok boolean not null,
  contamination_control_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','quarantined'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.milk_tissue_bank_qc_r3282 enable row level security;

create index if not exists idx_milk_tissue_bank_qc_r3282_org on public.milk_tissue_bank_qc_r3282(organization_id);
create index if not exists idx_milk_tissue_bank_qc_r3282_date on public.milk_tissue_bank_qc_r3282(check_date);
create index if not exists idx_milk_tissue_bank_qc_r3282_verdict on public.milk_tissue_bank_qc_r3282(qc_verdict);

-- =============================================================================
-- TABLE 2: milk_tissue_bank_qc_capa_actions_r3282 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.milk_tissue_bank_qc_capa_actions_r3282 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.milk_tissue_bank_qc_r3282(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_excursion','pasteurization_cycle_failure','ln2_level_low','alarm_test_failure',
    'chart_recorder_fault','backup_power_failure','contamination_control_breach','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compressor_failure','door_seal_leak','ln2_autofill_valve_fault','alarm_sensor_miscalibrated',
    'chart_recorder_pen_fault','ups_battery_degraded','heater_element_fault','hepa_filter_breach',
    'calibration_lapsed','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_compressor','replace_door_gasket','repair_autofill_valve','recalibrate_alarm_sensor',
    'replace_chart_recorder','replace_ups_battery','replace_heater_element','replace_hepa_filter',
    'recalibrate_and_certify','transfer_samples_backup_unit','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.milk_tissue_bank_qc_capa_actions_r3282 enable row level security;

create index if not exists idx_milk_tissue_capa_r3282_log on public.milk_tissue_bank_qc_capa_actions_r3282(qc_log_id);
create index if not exists idx_milk_tissue_capa_r3282_status on public.milk_tissue_bank_qc_capa_actions_r3282(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 QC check rows
  insert into public.milk_tissue_bank_qc_r3282 (
    organization_id, hospital_name, device_code, device_type, bank_type,
    check_date, temp_reading_c, temp_in_range, pasteurization_cycle_ok, ln2_level_pct,
    alarm_test, chart_recorder_ok, backup_power_ok, contamination_control_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.btype,
    q.cdate::date, q.temp, q.tinr, q.pcyc, q.ln2,
    q.alarm, q.chart, q.backup, q.contam, q.calib,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','MB-PAST-01','milk_pasteurizer','milk_bank',
     '2026-07-05',62.40,true,'pass',null,
     'pass',true,true,true,true,
     'pass','Holder 62.5C/30min cycle verified; all parameters nominal'),
    ('Apollo Chennai Greams Road','MB-F20-02','minus20_freezer','milk_bank',
     '2026-07-05',-21.30,true,'not_applicable',null,
     'pass',true,true,true,true,
     'pass','Milk storage freezer within -18 to -25C band'),
    ('Fortis Gurgaon','CB-F80-11','minus80_freezer','cord_blood_bank',
     '2026-07-04',-78.60,true,'not_applicable',null,
     'pass',true,true,true,true,
     'pass','Cord-blood -80 freezer stable; chart recorder legible'),
    ('Fortis Gurgaon','CB-LN2-12','ln2_cryotank','cord_blood_bank',
     '2026-07-04',-192.00,true,'not_applicable',82.00,
     'pass',true,true,true,true,
     'pass','Vapor-phase LN2 dewar; auto-fill holding 82% level'),
    ('Manipal Bengaluru Old Airport Road','CB-CENT-21','refrigerated_centrifuge','cord_blood_bank',
     '2026-07-03',4.20,true,'not_applicable',null,
     'pass',true,true,true,true,
     'pass','Refrigerated centrifuge holding 4C through processing spins'),
    ('Manipal Bengaluru Old Airport Road','CB-CRF-22','controlled_rate_freezer','cord_blood_bank',
     '2026-07-03',-1.50,true,'not_applicable',null,
     'pass',true,true,true,true,
     'conditional_pass','Controlled-rate freeze profile OK but LN2 supply pressure low — PM watch'),
    ('Manipal Bengaluru Old Airport Road','MB-ANLY-23','milk_analyzer','milk_bank',
     '2026-07-03',40.10,true,'not_applicable',null,
     'not_tested',true,true,true,false,
     'conditional_pass','Milk analyzer calibration certificate expired; recal booked with OEM'),
    ('AIIMS Delhi Ansari Nagar','TB-F80-31','minus80_freezer','tissue_bank',
     '2026-07-02',-64.20,false,'not_applicable',null,
     'fail',false,true,true,true,
     'fail','Tissue -80 freezer drifted to -64C; alarm did not annunciate; recorder pen stuck'),
    ('AIIMS Delhi Ansari Nagar','TB-LN2-32','ln2_cryotank','tissue_bank',
     '2026-07-02',-188.50,true,'not_applicable',34.00,
     'fail',true,true,true,true,
     'quarantined','LN2 level critically low at 34%; auto-fill valve fault — samples quarantined'),
    ('CMC Vellore','MB-PAST-41','milk_pasteurizer','milk_bank',
     '2026-07-01',60.10,false,'fail',null,
     'pass',true,true,false,true,
     'fail','Holder cycle under-temp at 60.1C; contamination-control breach — batch discarded'),
    ('CMC Vellore','TB-CENT-42','refrigerated_centrifuge','tissue_bank',
     '2026-07-01',9.80,false,'not_applicable',null,
     'pass',true,false,true,true,
     'conditional_pass','Centrifuge chamber warmed to 9.8C; backup-power test failed — UPS battery weak'),
    ('KIMS Hyderabad','MB-F20-51','minus20_freezer','milk_bank',
     '2026-06-30',-19.80,true,'not_applicable',null,
     'pass',true,true,true,true,
     'pass','Milk freezer nominal; preventive maintenance completed'),
    ('KIMS Hyderabad','TB-CRF-52','controlled_rate_freezer','tissue_bank',
     '2026-06-30',-85.00,true,'not_applicable',null,
     'pass',true,true,true,false,
     'conditional_pass','Controlled-rate freezer profile OK; calibration certificate overdue'),
    ('KIMS Hyderabad','CB-F80-53','minus80_freezer','cord_blood_bank',
     '2026-06-30',-79.40,true,'not_applicable',null,
     'pass',true,true,true,true,
     'pass','Cord-blood -80 freezer stable; all checks pass')
  ) as q(hosp, dcode, dtype, btype, cdate, temp, tinr, pcyc, ln2, alarm, chart, backup, contam, calib, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.milk_tissue_bank_qc_capa_actions_r3282 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MB-ANLY-23','calibration_overdue','calibration_lapsed','recalibrate_and_certify','in_progress','nabh_finding','2026-07-10',null,8000.00,'Milk analyzer cal certificate expired — recal scheduled with OEM'),
    ('TB-F80-31','temperature_excursion','compressor_failure','replace_compressor','escalated','patient_safety_alert','2026-07-08',null,145000.00,'Tissue -80 drifted to -64C; compressor and alarm both faulted'),
    ('TB-LN2-32','ln2_level_low','ln2_autofill_valve_fault','repair_autofill_valve','open','cdsco_notifiable','2026-07-06',null,56000.00,'LN2 auto-fill valve stuck; samples quarantined to backup dewar'),
    ('MB-PAST-41','pasteurization_cycle_failure','heater_element_fault','replace_heater_element','closed','iso_15189_deviation','2026-07-04','2026-07-03',22000.00,'Holder heater under-temp; element replaced, cycle re-validated'),
    ('TB-CENT-42','backup_power_failure','ups_battery_degraded','replace_ups_battery','in_progress','internal_only','2026-07-05',null,15000.00,'Centrifuge UPS battery weak; replacement on order'),
    ('TB-CRF-52','calibration_overdue','calibration_lapsed','recalibrate_and_certify','overdue','nabh_finding','2026-06-28',null,9500.00,'Controlled-rate freezer calibration overdue past target date'),
    ('CB-CRF-22','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','verification_pending','internal_only','2026-07-07',null,12000.00,'LN2 supply pressure low; OEM preventive service scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.milk_tissue_bank_qc_r3282 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3282_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.milk_tissue_bank_qc_r3282)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.milk_tissue_bank_qc_r3282 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3282_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3282_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3282_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  quarantined bigint,
  temp_excursions bigint,
  alarm_fails bigint,
  calibration_lapsed bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.qc_verdict = 'quarantined')::bigint,
    count(*) filter (where l.temp_in_range = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.milk_tissue_bank_qc_r3282 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3282_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3282_hospital_scorecard() to authenticated;

-- 3) Device type × bank type matrix
create or replace function public.founder_r3282_device_bank_matrix()
returns table(device_type text, bank_type text, audits bigint, passed bigint, avg_temp_c numeric, at_risk bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.bank_type, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.temp_reading_c), 2),
    count(*) filter (where l.qc_verdict in ('fail','quarantined','conditional_pass'))::bigint
  from public.milk_tissue_bank_qc_r3282 l
  group by l.device_type, l.bank_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3282_device_bank_matrix() from public, anon;
grant execute on function public.founder_r3282_device_bank_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3282_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, temp_excursions bigint, alarm_fails bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.temp_in_range = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint
  from public.milk_tissue_bank_qc_r3282 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3282_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3282_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3282_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.milk_tissue_bank_qc_capa_actions_r3282 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3282_capa_status_board() from public, anon;
grant execute on function public.founder_r3282_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3282_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.milk_tissue_bank_qc_capa_actions_r3282)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.milk_tissue_bank_qc_capa_actions_r3282 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3282_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3282_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3282_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.milk_tissue_bank_qc_capa_actions_r3282 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3282_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3282_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3282_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  bank_type text,
  check_date date,
  qc_verdict text,
  temp_in_range boolean,
  alarm_test text,
  ln2_level_pct numeric,
  calibration_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.bank_type, l.check_date,
    l.qc_verdict, l.temp_in_range, l.alarm_test, l.ln2_level_pct, l.calibration_current, l.notes
  from public.milk_tissue_bank_qc_r3282 l
  where l.qc_verdict in ('conditional_pass','fail','quarantined')
     or l.temp_in_range = false
     or l.pasteurization_cycle_ok = 'fail'
     or l.alarm_test = 'fail'
     or l.chart_recorder_ok = false
     or l.backup_power_ok = false
     or l.contamination_control_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3282_high_risk_queue() from public, anon;
grant execute on function public.founder_r3282_high_risk_queue() to authenticated;
