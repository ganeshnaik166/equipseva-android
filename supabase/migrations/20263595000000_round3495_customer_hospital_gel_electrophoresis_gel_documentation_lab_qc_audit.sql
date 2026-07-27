-- Round 3495: Customer Hospital Gel Electrophoresis / Gel-Documentation (Lab) QC Audit
-- Hospital lab gel electrophoresis + gel-documentation imaging QC — power-supply voltage/current,
-- UV transilluminator intensity, band resolution, CCD camera linearity × device model × verdict × CAPA

-- =============================================================================
-- TABLE 1: gel_electrophoresis_qc_r3495 — per-parameter gel/gel-doc QC checks
-- =============================================================================
create table if not exists public.gel_electrophoresis_qc_r3495 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'set_voltage_v','measured_voltage_v','set_current_ma','uv_intensity','band_resolution','camera_linearity'
  )),
  reference_value numeric(12,4),
  measured_value numeric(12,4),
  deviation_pct numeric(8,3),
  measurement_unit text,
  within_tolerance boolean not null,
  calibration_date date not null,
  technician_name text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gel_electrophoresis_qc_r3495 enable row level security;

create index if not exists idx_gel_electrophoresis_qc_r3495_org on public.gel_electrophoresis_qc_r3495(organization_id);
create index if not exists idx_gel_electrophoresis_qc_r3495_date on public.gel_electrophoresis_qc_r3495(calibration_date);
create index if not exists idx_gel_electrophoresis_qc_r3495_verdict on public.gel_electrophoresis_qc_r3495(qc_verdict);

-- =============================================================================
-- TABLE 2: gel_electrophoresis_qc_capa_actions_r3495 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.gel_electrophoresis_qc_capa_actions_r3495 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.gel_electrophoresis_qc_r3495(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'voltage_out_of_tolerance','current_out_of_tolerance','uv_intensity_degraded',
    'band_resolution_poor','camera_linearity_drift','power_supply_fault',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'power_supply_drift','uv_lamp_aging','ccd_sensor_degraded','electrode_corrosion',
    'buffer_contamination','firmware_calibration_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_power_supply','replace_uv_lamp','replace_ccd_camera','replace_electrode',
    'clean_and_replace_buffer','update_firmware','retrain_lab_staff',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','lab_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gel_electrophoresis_qc_capa_actions_r3495 enable row level security;

create index if not exists idx_gel_electrophoresis_capa_r3495_log on public.gel_electrophoresis_qc_capa_actions_r3495(qc_log_id);
create index if not exists idx_gel_electrophoresis_capa_r3495_status on public.gel_electrophoresis_qc_capa_actions_r3495(capa_status);

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

  -- 16 QC parameter rows
  insert into public.gel_electrophoresis_qc_r3495 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, measurement_unit,
    within_tolerance, calibration_date, technician_name, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.munit,
    q.wtol, q.caldate::date, q.tech, q.qv, q.nt
  from (values
    ('Apollo Chennai','GEL-APL-01','Bio-Rad PowerPac HC','set_voltage_v',
     100.00,100.50,0.500,'volts',true,'2026-07-05','R. Nair','pass','Power supply set-voltage within +/-2% tolerance'),
    ('Apollo Chennai','GEL-APL-01','Bio-Rad PowerPac HC','set_current_ma',
     400.00,398.00,-0.500,'milliamps',true,'2026-07-05','R. Nair','pass','Constant-current mode within tolerance'),
    ('Apollo Chennai','DOC-APL-02','Bio-Rad ChemiDoc MP','uv_intensity',
     100.00,92.00,-8.000,'percent',false,'2026-07-05','R. Nair','conditional_pass','UV transilluminator intensity down 8% — lamp aging, monitor'),
    ('Apollo Chennai','DOC-APL-02','Bio-Rad ChemiDoc MP','camera_linearity',
     0.9990,0.9970,-0.200,'r_squared',true,'2026-07-05','R. Nair','pass','CCD linearity R-squared within spec'),
    ('Fortis Mohali','GEL-FRT-11','GE Amersham ECL','measured_voltage_v',
     120.00,131.00,9.167,'volts',false,'2026-07-04','S. Gill','fail','Measured voltage 9.2% high — power supply drift out of tolerance'),
    ('Fortis Mohali','DOC-FRT-12','Syngene G:BOX Chemi','band_resolution',
     5.00,3.80,-24.000,'lp_per_mm',false,'2026-07-04','S. Gill','fail','Band resolution degraded — imaging optics need service'),
    ('Fortis Mohali','DOC-FRT-12','Syngene G:BOX Chemi','uv_intensity',
     100.00,98.00,-2.000,'percent',true,'2026-07-04','S. Gill','pass','UV intensity nominal'),
    ('Manipal Bengaluru','GEL-MNP-21','Cleaver omniPAC Pro','set_voltage_v',
     200.00,201.00,0.500,'volts',true,'2026-07-03','K. Rao','pass','Set-voltage QC pass post-AMC'),
    ('Manipal Bengaluru','GEL-MNP-21','Cleaver omniPAC Pro','set_current_ma',
     500.00,486.00,-2.800,'milliamps',false,'2026-07-03','K. Rao','conditional_pass','Current 2.8% low — monitor next cycle'),
    ('AIIMS Delhi','DOC-AIM-31','Azure Biosystems c300','camera_linearity',
     0.9990,0.9820,-1.702,'r_squared',false,'2026-07-02','P. Verma','fail','CCD linearity out of tolerance — sensor degraded'),
    ('AIIMS Delhi','DOC-AIM-31','Azure Biosystems c300','uv_intensity',
     100.00,85.00,-15.000,'percent',false,'2026-07-02','P. Verma','fail','UV lamp intensity 15% low — replace lamp'),
    ('CMC Vellore','GEL-CMC-41','Thermo Owl EC300','measured_voltage_v',
     100.00,100.80,0.800,'volts',true,'2026-07-01','J. Thomas','pass','Measured voltage within +/-2%'),
    ('CMC Vellore','DOC-CMC-42','Bio-Rad GelDoc Go','band_resolution',
     5.00,4.90,-2.000,'lp_per_mm',true,'2026-07-01','J. Thomas','pass','Band resolution nominal'),
    ('KIMS Hyderabad','GEL-KIM-51','Bio-Rad PowerPac Basic','set_current_ma',
     300.00,303.00,1.000,'milliamps',true,'2026-06-30','A. Reddy','pass','Constant-current within tolerance'),
    ('KIMS Hyderabad','DOC-KIM-52','Syngene InGenius3','uv_intensity',
     100.00,90.00,-10.000,'percent',false,'2026-06-30','A. Reddy','conditional_pass','UV intensity borderline — schedule lamp replacement'),
    ('Kokilaben Mumbai','DOC-KKB-61','Bio-Rad ChemiDoc XRS+','camera_linearity',
     0.9990,0.9950,-0.400,'r_squared',true,'2026-06-29','M. Shah','pass','Imaging linearity QC pass')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, munit, wtol, caldate, tech, qv, nt);

  -- CAPA seed — attach to specific checks via device_code + parameter
  insert into public.gel_electrophoresis_qc_capa_actions_r3495 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DOC-APL-02','uv_intensity','uv_intensity_degraded','uv_lamp_aging','replace_uv_lamp','in_progress','iso_15189_deviation','2026-07-12',null,18000.00,'UV lamp aging — replacement lamp on order'),
    ('GEL-FRT-11','measured_voltage_v','voltage_out_of_tolerance','power_supply_drift','recalibrate_power_supply','open','nabh_finding','2026-07-10',null,12000.00,'Power supply drift 9.2% — recalibration scheduled'),
    ('DOC-FRT-12','band_resolution','band_resolution_poor','ccd_sensor_degraded','replace_ccd_camera','escalated','cdsco_notifiable','2026-07-09',null,85000.00,'Resolution degraded — CCD module escalated to OEM'),
    ('GEL-MNP-21','set_current_ma','current_out_of_tolerance','firmware_calibration_error','update_firmware','verification_pending','internal_only','2026-07-08',null,3000.00,'Firmware cal offset applied — verify next run'),
    ('DOC-AIM-31','camera_linearity','camera_linearity_drift','ccd_sensor_degraded','replace_ccd_camera','open','iso_15189_deviation','2026-07-11',null,90000.00,'Camera linearity out of spec — CCD replacement quoted'),
    ('DOC-AIM-31','uv_intensity','uv_intensity_degraded','uv_lamp_aging','replace_uv_lamp','closed','none','2026-07-05','2026-07-04',18000.00,'UV lamp replaced and intensity re-verified'),
    ('DOC-KIM-52','uv_intensity','calibration_overdue','uv_lamp_aging','replace_uv_lamp','overdue','internal_only','2026-06-28',null,18000.00,'UV lamp replacement past target date — vendor delay'),
    ('DOC-CMC-42','band_resolution','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-15',null,6000.00,'Preventive imaging service due — OEM visit booked')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.gel_electrophoresis_qc_r3495 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3495_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gel_electrophoresis_qc_r3495)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gel_electrophoresis_qc_r3495 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3495_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3495_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3495_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
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
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.gel_electrophoresis_qc_r3495 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3495_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3495_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3495_parameter_verdict_matrix()
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
  from public.gel_electrophoresis_qc_r3495 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3495_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3495_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3495_monthly_accuracy_trend()
returns table(calibration_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
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
  from public.gel_electrophoresis_qc_r3495 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3495_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3495_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3495_capa_status_board()
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
  from public.gel_electrophoresis_qc_capa_actions_r3495 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3495_capa_status_board() from public, anon;
grant execute on function public.founder_r3495_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3495_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gel_electrophoresis_qc_capa_actions_r3495)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gel_electrophoresis_qc_capa_actions_r3495 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3495_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3495_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3495_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric,
  failed bigint
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
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2),
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.gel_electrophoresis_qc_r3495 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3495_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3495_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3495_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
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
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.notes
  from public.gel_electrophoresis_qc_r3495 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3495_high_risk_queue() from public, anon;
grant execute on function public.founder_r3495_high_risk_queue() to authenticated;
