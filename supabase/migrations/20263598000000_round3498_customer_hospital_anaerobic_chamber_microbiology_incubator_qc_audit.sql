-- Round 3498: Customer Hospital Anaerobic Chamber / Microbiology Incubator QC Audit
-- Anaerobic chamber & microbiology incubator QA — parameter (O2 ppm, temp, humidity, H2, CO2, anaerobic indicator)
-- × reference vs measured × deviation % × tolerance × catalyst condition × indicator status × gas supply × CAPA

-- =============================================================================
-- TABLE 1: anaerobic_chamber_qc_r3498 — per-device parameter QC checks
-- =============================================================================
create table if not exists public.anaerobic_chamber_qc_r3498 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  chamber_type text not null check (chamber_type in (
    'anaerobic_chamber','co2_incubator','microbiology_incubator','anaerobic_jar_system'
  )),
  unit_location text not null,
  parameter text not null check (parameter in (
    'o2_ppm','temp_c','humidity_pct','h2_pct','co2_pct','anaerobic_indicator'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(8,2),
  within_tolerance boolean not null,
  catalyst_condition text not null check (catalyst_condition in (
    'good','saturated','regenerated','replace_due','not_applicable'
  )),
  indicator_status text not null check (indicator_status in (
    'colorless_anaerobic','blue_oxygen_present','not_applicable'
  )),
  gas_supply_ok boolean not null,
  calibration_current boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.anaerobic_chamber_qc_r3498 enable row level security;

create index if not exists idx_anaerobic_chamber_qc_r3498_org on public.anaerobic_chamber_qc_r3498(organization_id);
create index if not exists idx_anaerobic_chamber_qc_r3498_date on public.anaerobic_chamber_qc_r3498(calibration_date);
create index if not exists idx_anaerobic_chamber_qc_r3498_verdict on public.anaerobic_chamber_qc_r3498(qc_verdict);

-- =============================================================================
-- TABLE 2: anaerobic_chamber_qc_capa_actions_r3498 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.anaerobic_chamber_qc_capa_actions_r3498 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.anaerobic_chamber_qc_r3498(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'o2_ppm_out_of_tolerance','temperature_deviation','humidity_deviation','h2_concentration_low',
    'co2_concentration_out_of_range','anaerobic_indicator_positive','catalyst_saturated',
    'gas_supply_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'catalyst_exhausted','gas_cylinder_empty','chamber_seal_leak','sensor_drift',
    'heater_element_fault','humidity_pan_dry','door_gasket_worn','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_catalyst','replace_gas_cylinder','reseal_chamber_door','recalibrate_sensor',
    'replace_heater_element','refill_humidity_pan','replace_door_gasket','retrain_lab_staff',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.anaerobic_chamber_qc_capa_actions_r3498 enable row level security;

create index if not exists idx_anaerobic_chamber_capa_r3498_log on public.anaerobic_chamber_qc_capa_actions_r3498(qc_log_id);
create index if not exists idx_anaerobic_chamber_capa_r3498_status on public.anaerobic_chamber_qc_capa_actions_r3498(capa_status);

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

  -- 16 QC check rows
  insert into public.anaerobic_chamber_qc_r3498 (
    organization_id, hospital_name, device_code, device_model, chamber_type, unit_location,
    parameter, reference_value, measured_value, deviation_pct, within_tolerance,
    catalyst_condition, indicator_status, gas_supply_ok, calibration_current, calibration_date,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.ctype, q.uloc,
    q.param, q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol,
    q.catc, q.inds, q.gas, q.calcur, q.caldate::date,
    q.qv, q.nt
  from (values
    ('Apollo Chennai','ANC-APL-O2-01','Whitley A35','anaerobic_chamber','microbiology_lab',
     'o2_ppm',5.0,4.2,-16.0,true,'good','colorless_anaerobic',true,true,'2026-07-05','pass','Chamber O2 4.2 ppm within anaerobic target'),
    ('Apollo Chennai','INC-APL-CO2-02','Thermo Forma 1029','co2_incubator','blood_culture_lab',
     'co2_pct',5.0,5.1,2.0,true,'not_applicable','not_applicable',true,true,'2026-07-05','pass','CO2 incubator setpoint holding 5.1%'),
    ('Fortis Gurgaon','ANC-FRT-TEMP-11','Whitley A45','anaerobic_chamber','microbiology_lab',
     'temp_c',37.0,37.6,1.62,true,'good','colorless_anaerobic',true,true,'2026-07-04','conditional_pass','Temp 37.6C slightly high, monitoring upward drift'),
    ('Fortis Gurgaon','ANC-FRT-O2-12','Whitley A45','anaerobic_chamber','microbiology_lab',
     'o2_ppm',5.0,42.0,740.0,false,'saturated','blue_oxygen_present',true,true,'2026-07-04','fail','O2 spike 42 ppm, indicator blue — catalyst saturated'),
    ('Manipal Bengaluru','INC-MNP-HUM-21','Binder CB170','co2_incubator','microbiology_lab',
     'humidity_pct',90.0,71.0,-21.11,false,'not_applicable','not_applicable',false,false,'2026-07-03','fail','Humidity dropped to 71%, water pan dry and cal overdue'),
    ('Manipal Bengaluru','INC-MNP-CO2-22','Binder CB170','co2_incubator','microbiology_lab',
     'co2_pct',5.0,4.9,-2.0,true,'not_applicable','not_applicable',true,true,'2026-07-03','pass','CO2 5.0% nominal'),
    ('AIIMS Delhi','ANC-AIM-H2-31','Baker Ruskinn Bugbox','anaerobic_chamber','tb_lab',
     'h2_pct',5.0,3.4,-32.0,false,'good','blue_oxygen_present',false,true,'2026-07-02','fail','H2 low 3.4%, gas cylinder near empty, indicator blue'),
    ('AIIMS Delhi','ANC-AIM-IND-32','Baker Ruskinn Bugbox','anaerobic_chamber','tb_lab',
     'anaerobic_indicator',null,null,null,true,'good','colorless_anaerobic',true,true,'2026-07-02','pass','Resazurin indicator colorless — anaerobic confirmed'),
    ('CMC Vellore','INC-CMC-TEMP-41','Memmert INCO153','microbiology_incubator','bacteriology',
     'temp_c',37.0,37.1,0.27,true,'not_applicable','not_applicable',true,true,'2026-07-01','pass','Incubator temp stable at 37.1C'),
    ('CMC Vellore','ANC-CMC-O2-42','Don Whitley DG250','anaerobic_chamber','bacteriology',
     'o2_ppm',5.0,12.0,140.0,false,'replace_due','blue_oxygen_present',true,true,'2026-07-01','conditional_pass','O2 elevated 12 ppm, catalyst replacement due'),
    ('KIMS Hyderabad','INC-KIM-CO2-51','Panasonic MCO-170','co2_incubator','blood_culture_lab',
     'co2_pct',5.0,5.0,0.0,true,'not_applicable','not_applicable',true,true,'2026-06-30','pass','CO2 incubator QC pass post-AMC'),
    ('KIMS Hyderabad','INC-KIM-HUM-52','Panasonic MCO-170','co2_incubator','blood_culture_lab',
     'humidity_pct',90.0,86.0,-4.44,true,'not_applicable','not_applicable',true,false,'2026-06-30','conditional_pass','Humidity 86% acceptable but calibration overdue'),
    ('Yashoda Hyderabad','ANC-YSH-TEMP-61','Whitley A35','anaerobic_chamber','microbiology_lab',
     'temp_c',37.0,36.9,-0.27,true,'good','colorless_anaerobic',true,true,'2026-06-29','pass','Chamber temp nominal at 36.9C'),
    ('Yashoda Hyderabad','ANC-YSH-H2-62','Baker Ruskinn Bugbox','anaerobic_chamber','tb_lab',
     'h2_pct',5.0,4.8,-4.0,true,'good','colorless_anaerobic',true,true,'2026-06-29','pass','H2 4.8% within tolerance'),
    ('Kokilaben Mumbai','ANC-KKB-O2-71','Whitley A45','anaerobic_chamber','microbiology_lab',
     'o2_ppm',5.0,88.0,1660.0,false,'replace_due','blue_oxygen_present',false,false,'2026-06-28','fail','Severe O2 ingress 88 ppm, seal leak, chamber removed from use'),
    ('Kokilaben Mumbai','INC-KKB-CO2-72','Thermo Forma 1029','co2_incubator','microbiology_lab',
     'co2_pct',5.0,6.4,28.0,false,'not_applicable','not_applicable',true,true,'2026-06-28','fail','CO2 overshoot 6.4%, sensor drift suspected')
  ) as q(hosp, dcode, dmodel, ctype, uloc, param, refv, measv, devp, wtol, catc, inds, gas, calcur, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.anaerobic_chamber_qc_capa_actions_r3498 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('ANC-FRT-O2-12','catalyst_saturated','catalyst_exhausted','replace_catalyst','in_progress','iso_15189_deviation','Dr. Meera Nair','2026-07-08',null,3500.00,'Palladium catalyst saturated — sachets replaced, verifying O2 recovery'),
    ('INC-MNP-HUM-21','humidity_deviation','humidity_pan_dry','refill_humidity_pan','open','nabh_finding','Ravi Kulkarni','2026-07-07',null,1200.00,'Water pan refilled; humidity sensor to be recalibrated'),
    ('ANC-AIM-H2-31','gas_supply_failure','gas_cylinder_empty','replace_gas_cylinder','escalated','patient_safety_alert','Dr. S. Krishnan','2026-07-06',null,6800.00,'Anaerobic gas-mix cylinder empty — replacement escalated to vendor'),
    ('ANC-CMC-O2-42','o2_ppm_out_of_tolerance','catalyst_exhausted','replace_catalyst','verification_pending','internal_only','Anitha George','2026-07-05',null,3500.00,'Catalyst replaced — verify O2 ppm on next cycle'),
    ('ANC-KKB-O2-71','anaerobic_indicator_positive','chamber_seal_leak','reseal_chamber_door','closed','cdsco_notifiable','Dr. Prakash Rao','2026-07-04','2026-06-30',22000.00,'Door seal leak repaired, chamber revalidated and returned to service'),
    ('INC-KKB-CO2-72','co2_concentration_out_of_range','sensor_drift','recalibrate_sensor','open','iso_15189_deviation','Sunita Desai','2026-07-09',null,4500.00,'CO2 sensor drift — recalibration scheduled with OEM'),
    ('INC-KIM-HUM-52','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','Ramesh Babu','2026-06-30',null,5000.00,'Annual calibration overdue — OEM visit past target date'),
    ('ANC-FRT-TEMP-11','temperature_deviation','heater_element_fault','replace_heater_element','in_progress','nabh_finding','Dr. Meera Nair','2026-07-08',null,8500.00,'Temp drift to 37.6C — heater element inspection underway')
  ) as q(dcode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.anaerobic_chamber_qc_r3498 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3498_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.anaerobic_chamber_qc_r3498)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.anaerobic_chamber_qc_r3498 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3498_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3498_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3498_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  catalyst_issue bigint,
  calibration_overdue bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.catalyst_condition in ('saturated','replace_due'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.anaerobic_chamber_qc_r3498 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3498_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3498_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3498_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.anaerobic_chamber_qc_r3498 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3498_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3498_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3498_monthly_accuracy_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.anaerobic_chamber_qc_r3498 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3498_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3498_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3498_capa_status_board()
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
  from public.anaerobic_chamber_qc_capa_actions_r3498 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3498_capa_status_board() from public, anon;
grant execute on function public.founder_r3498_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3498_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.anaerobic_chamber_qc_capa_actions_r3498)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.anaerobic_chamber_qc_capa_actions_r3498 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3498_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3498_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3498_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  fail_checks bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.anaerobic_chamber_qc_r3498 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3498_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3498_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / at-risk)
create or replace function public.founder_r3498_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
  catalyst_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter,
    l.reference_value, l.measured_value, l.deviation_pct,
    l.qc_verdict, l.catalyst_condition, l.notes
  from public.anaerobic_chamber_qc_r3498 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.catalyst_condition in ('saturated','replace_due')
     or l.indicator_status = 'blue_oxygen_present'
     or l.gas_supply_ok = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3498_high_risk_queue() from public, anon;
grant execute on function public.founder_r3498_high_risk_queue() to authenticated;
