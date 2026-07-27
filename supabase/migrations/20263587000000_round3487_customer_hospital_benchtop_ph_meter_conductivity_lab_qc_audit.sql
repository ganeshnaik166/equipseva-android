-- Round 3487: Customer Hospital Benchtop pH-Meter / Conductivity (Lab) QC Audit
-- Lab benchtop pH / conductivity meter QC — slope % × offset mV × pH4/pH7 buffers × conductivity µS × temp comp × deviation × tolerance × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: ph_conductivity_qc_r3487 — per-device pH/conductivity meter QC checks
-- =============================================================================
create table if not exists public.ph_conductivity_qc_r3487 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  lab_section text not null check (lab_section in (
    'biochemistry','microbiology','water_treatment','dialysis_lab','central_lab'
  )),
  parameter text not null check (parameter in (
    'ph_slope_pct','ph_offset_mv','ph4_buffer','ph7_buffer','conductivity_us','temp_comp_c'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  next_calibration_date date,
  calibration_current boolean not null,
  technician text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ph_conductivity_qc_r3487 enable row level security;

create index if not exists idx_ph_conductivity_qc_r3487_org on public.ph_conductivity_qc_r3487(organization_id);
create index if not exists idx_ph_conductivity_qc_r3487_date on public.ph_conductivity_qc_r3487(calibration_date);
create index if not exists idx_ph_conductivity_qc_r3487_verdict on public.ph_conductivity_qc_r3487(qc_verdict);

-- =============================================================================
-- TABLE 2: ph_conductivity_qc_capa_actions_r3487 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ph_conductivity_qc_capa_actions_r3487 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ph_conductivity_qc_r3487(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'slope_out_of_tolerance','offset_drift','buffer_reading_error','conductivity_deviation',
    'temp_compensation_error','calibration_overdue','electrode_degraded','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'electrode_aging','reference_junction_clogged','buffer_solution_expired','temperature_probe_fault',
    'conductivity_cell_fouled','operator_calibration_error','meter_electronics_drift',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_meter','replace_ph_electrode','clean_reference_junction','replace_buffer_solutions',
    'replace_temperature_probe','clean_conductivity_cell','retrain_lab_staff',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ph_conductivity_qc_capa_actions_r3487 enable row level security;

create index if not exists idx_ph_conductivity_capa_r3487_log on public.ph_conductivity_qc_capa_actions_r3487(qc_log_id);
create index if not exists idx_ph_conductivity_capa_r3487_status on public.ph_conductivity_qc_capa_actions_r3487(capa_status);

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
  insert into public.ph_conductivity_qc_r3487 (
    organization_id, hospital_name, device_code, device_model, lab_section, parameter,
    reference_value, measured_value, deviation_pct, tolerance_pct, within_tolerance,
    calibration_date, next_calibration_date, calibration_current, technician, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.lab, q.param,
    q.refval, q.measval, q.devpct, q.tolpct, q.wtol,
    q.caldate::date, q.nextcal::date, q.calcur, q.tech, q.qv, q.nt
  from (values
    ('Apollo Chennai','PH-APL-01','Eutech pH700','biochemistry','ph_slope_pct',
     100,99.2,-0.8,5,true,'2026-07-03','2026-10-03',true,'S. Kumar','pass','Slope 99.2% within +/-5% — biochem bench meter QC pass'),
    ('Apollo Chennai','PH-APL-02','Eutech pH700','biochemistry','ph_offset_mv',
     0,8.5,2.8,15,true,'2026-07-03','2026-10-03',true,'S. Kumar','pass','Offset 8.5 mV within +/-15 mV limit'),
    ('Fortis Gurgaon','PH-FRT-11','Mettler S220','central_lab','ph4_buffer',
     4.00,4.03,0.75,2,true,'2026-07-02','2026-10-02',true,'R. Mehta','pass','pH4 buffer check nominal'),
    ('Fortis Gurgaon','PH-FRT-12','Mettler S220','central_lab','ph7_buffer',
     7.00,7.18,2.57,2,false,'2026-07-02','2026-10-02',true,'R. Mehta','fail','pH7 buffer reads 7.18 — exceeds +/-2% tolerance, electrode aging'),
    ('Manipal Bengaluru','CND-MNP-21','Hanna HI5522','water_treatment','conductivity_us',
     1413,1421,0.57,3,true,'2026-07-01','2026-10-01',true,'A. Rao','pass','Conductivity 1421 uS/cm vs 1413 standard — within +/-3%'),
    ('Manipal Bengaluru','CND-MNP-22','Hanna HI5522','dialysis_lab','conductivity_us',
     1413,1489,5.38,3,false,'2026-07-01','2026-10-01',false,'A. Rao','fail','Conductivity cell fouled — 5.4% high, calibration overdue, removed for cleaning'),
    ('AIIMS Delhi','PH-AIM-31','Thermo Orion Star A215','biochemistry','ph_slope_pct',
     100,94.6,-5.4,5,false,'2026-06-30','2026-09-30',true,'P. Singh','fail','Slope 94.6% below 95% floor — electrode end of life'),
    ('AIIMS Delhi','PH-AIM-32','Thermo Orion Star A215','biochemistry','temp_comp_c',
     25.0,25.3,1.2,4,true,'2026-06-30','2026-09-30',true,'P. Singh','pass','Temperature compensation nominal'),
    ('CMC Vellore','PH-CMC-41','Hach HQ430d','central_lab','ph_offset_mv',
     0,18.0,6.0,15,false,'2026-06-29','2026-09-29',true,'J. Thomas','fail','Offset 18 mV exceeds +/-15 mV — reference junction clogged'),
    ('CMC Vellore','PH-CMC-42','Hach HQ430d','central_lab','ph4_buffer',
     4.00,4.05,1.25,2,true,'2026-06-29','2026-09-29',true,'J. Thomas','conditional_pass','pH4 slightly high at 4.05 — recheck with fresh buffer'),
    ('KIMS Hyderabad','PH-KIM-51','Eutech pH700','microbiology','ph7_buffer',
     7.00,7.02,0.29,2,true,'2026-06-28','2026-09-28',true,'V. Reddy','pass','pH7 buffer check pass in micro lab'),
    ('KIMS Hyderabad','CND-KIM-52','Hanna HI5522','water_treatment','conductivity_us',
     1413,1450,2.62,3,true,'2026-06-28','2026-09-28',true,'V. Reddy','conditional_pass','Conductivity drift 2.6% — trending up, monitor RO feedwater'),
    ('Yashoda Hyderabad','PH-YSH-61','Mettler S220','dialysis_lab','ph_slope_pct',
     100,97.8,-2.2,5,true,'2026-06-27','2026-09-27',true,'K. Naidu','pass','Slope 97.8% acceptable for dialysate QC'),
    ('Yashoda Hyderabad','PH-YSH-62','Mettler S220','dialysis_lab','temp_comp_c',
     25.0,26.1,4.4,4,false,'2026-06-27','2026-09-27',true,'K. Naidu','fail','Temp comp 26.1C vs 25C ref exceeds +/-4% — temperature probe fault'),
    ('Kokilaben Mumbai','PH-KKB-71','Thermo Orion Star A215','central_lab','ph_offset_mv',
     0,6.2,2.1,15,true,'2026-06-26','2026-09-26',true,'D. Shah','pass','Offset within limit post-electrode replacement'),
    ('Kokilaben Mumbai','CND-KKB-72','Hach HQ430d','water_treatment','conductivity_us',
     1413,1398,-1.06,3,true,'2026-06-26','2026-09-26',false,'D. Shah','conditional_pass','Conductivity within +/-3% but calibration overdue — schedule recal')
  ) as q(hosp, dcode, dmodel, lab, param, refval, measval, devpct, tolpct, wtol, caldate, nextcal, calcur, tech, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ph_conductivity_qc_capa_actions_r3487 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PH-FRT-12','buffer_reading_error','electrode_aging','replace_ph_electrode','in_progress','iso_15189_deviation','2026-07-08',null,6500.00,'pH7 buffer error — electrode replacement in progress'),
    ('CND-MNP-22','conductivity_deviation','conductivity_cell_fouled','clean_conductivity_cell','open','nabl_finding','2026-07-06',null,3500.00,'Conductivity cell fouled — scheduled cleaning and recal'),
    ('PH-AIM-31','slope_out_of_tolerance','electrode_aging','replace_ph_electrode','escalated','patient_safety_alert','2026-07-05',null,7200.00,'Slope below floor — electrode EOL, escalated for biochem analyzer dependency'),
    ('PH-CMC-41','offset_drift','reference_junction_clogged','clean_reference_junction','verification_pending','internal_only','2026-07-04',null,1200.00,'Reference junction cleaned — verify offset next QC'),
    ('PH-YSH-62','temp_compensation_error','temperature_probe_fault','replace_temperature_probe','closed','iso_15189_deviation','2026-07-03','2026-07-02',4800.00,'Temperature probe replaced and verified — dialysate QC restored'),
    ('CND-KIM-52','conductivity_deviation','meter_electronics_drift','recalibrate_meter','open','internal_only','2026-07-07',null,0.00,'Conductivity drift trending — recalibration scheduled'),
    ('CND-KKB-72','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','nabl_finding','2026-07-02',null,9000.00,'Calibration overdue past target — OEM service delayed'),
    ('PH-CMC-42','buffer_reading_error','buffer_solution_expired','replace_buffer_solutions','closed','internal_only','2026-07-01','2026-06-30',900.00,'Expired pH4 buffer replaced — recheck passed')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ph_conductivity_qc_r3487 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3487_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ph_conductivity_qc_r3487)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ph_conductivity_qc_r3487 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3487_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3487_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3487_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  cal_overdue bigint,
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
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ph_conductivity_qc_r3487 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3487_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3487_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3487_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.ph_conductivity_qc_r3487 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3487_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3487_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3487_monthly_calibration_trend()
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.ph_conductivity_qc_r3487 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3487_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3487_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3487_capa_status_board()
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
  from public.ph_conductivity_qc_capa_actions_r3487 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3487_capa_status_board() from public, anon;
grant execute on function public.founder_r3487_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3487_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ph_conductivity_qc_capa_actions_r3487)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ph_conductivity_qc_capa_actions_r3487 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3487_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3487_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3487_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  in_tolerance bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
  worst_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.ph_conductivity_qc_r3487 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3487_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3487_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3487_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.calibration_date,
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.notes
  from public.ph_conductivity_qc_r3487 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3487_high_risk_queue() from public, anon;
grant execute on function public.founder_r3487_high_risk_queue() to authenticated;
