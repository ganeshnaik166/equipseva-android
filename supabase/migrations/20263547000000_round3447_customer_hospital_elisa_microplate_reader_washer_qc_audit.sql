-- Round 3447: Customer Hospital ELISA Microplate Reader / Washer QC Audit
-- Immunoassay lab QA — instrument type × parameter (absorbance linearity, wavelength accuracy,
-- wash residual, dispense accuracy, optical crosstalk, plate uniformity) × reference vs measured ×
-- deviation × tolerance × calibration currency × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: elisa_microplate_qc_r3447 — per-device ELISA reader/washer QC checks
-- =============================================================================
create table if not exists public.elisa_microplate_qc_r3447 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  instrument_type text not null check (instrument_type in (
    'microplate_reader','microplate_washer','combined_reader_washer'
  )),
  parameter text not null check (parameter in (
    'absorbance_linearity','wavelength_accuracy_nm','wash_residual_ul',
    'dispense_accuracy_pct','crosstalk_pct','plate_uniformity'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.elisa_microplate_qc_r3447 enable row level security;

create index if not exists idx_elisa_microplate_qc_r3447_org on public.elisa_microplate_qc_r3447(organization_id);
create index if not exists idx_elisa_microplate_qc_r3447_date on public.elisa_microplate_qc_r3447(calibration_date);
create index if not exists idx_elisa_microplate_qc_r3447_verdict on public.elisa_microplate_qc_r3447(qc_verdict);

-- =============================================================================
-- TABLE 2: elisa_microplate_qc_capa_actions_r3447 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.elisa_microplate_qc_capa_actions_r3447 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.elisa_microplate_qc_r3447(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'absorbance_linearity_out_of_tolerance','wavelength_shift','wash_residual_high',
    'dispense_volume_inaccurate','optical_crosstalk_high','plate_uniformity_fail',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lamp_intensity_drift','filter_degraded','optics_contamination','wash_manifold_clog',
    'dispenser_pump_wear','tubing_leak','photodiode_aging','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_lamp','replace_optical_filter','clean_optics','clean_or_replace_wash_manifold',
    'replace_dispenser_pump','replace_tubing','recalibrate_absorbance','update_software_config',
    'retrain_lab_staff','schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','iso_15189_deviation',
    'none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.elisa_microplate_qc_capa_actions_r3447 enable row level security;

create index if not exists idx_elisa_microplate_capa_r3447_log on public.elisa_microplate_qc_capa_actions_r3447(qc_log_id);
create index if not exists idx_elisa_microplate_capa_r3447_status on public.elisa_microplate_qc_capa_actions_r3447(capa_status);

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

  -- 15 QC check rows
  insert into public.elisa_microplate_qc_r3447 (
    organization_id, hospital_name, device_code, device_model, instrument_type, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.itype, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','ELISA-APL-01','BioTek Synergy H1','microplate_reader','absorbance_linearity',
     1.000,0.994,0.6,true,'2026-07-05',true,'pass','Absorbance linearity within 2% across OD range'),
    ('Apollo Chennai','WASH-APL-02','BioTek ELx50','microplate_washer','wash_residual_ul',
     2.0,2.3,15.0,true,'2026-07-05',true,'pass','Residual 2.3 uL within 3 uL wash limit'),
    ('Fortis Gurgaon','ELISA-FRT-11','Thermo Multiskan FC','microplate_reader','wavelength_accuracy_nm',
     450.0,451.8,0.4,true,'2026-07-04',true,'conditional_pass','Wavelength +1.8 nm drift at 450 nm filter — trend flagged'),
    ('Fortis Gurgaon','WASH-FRT-12','Thermo Wellwash Versa','microplate_washer','wash_residual_ul',
     2.0,5.4,170.0,false,'2026-07-04',true,'fail','Residual 5.4 uL exceeds limit — wash manifold clog suspected'),
    ('Manipal Bengaluru','ELISA-MNP-21','Bio-Rad iMark','microplate_reader','crosstalk_pct',
     0.0,0.8,0.8,true,'2026-07-03',true,'pass','Optical crosstalk 0.8% below 1% limit'),
    ('Manipal Bengaluru','WASH-MNP-22','Tecan HydroFlex','microplate_washer','dispense_accuracy_pct',
     100.0,96.5,3.5,true,'2026-07-03',true,'conditional_pass','Dispense 96.5% near lower limit — pump wear watch'),
    ('AIIMS Delhi','ELISA-AIM-31','Thermo Multiskan GO','microplate_reader','plate_uniformity',
     100.0,92.0,8.0,false,'2026-06-30',true,'fail','Plate uniformity CV high — lamp intensity uneven'),
    ('AIIMS Delhi','WASH-AIM-32','BioTek 405 TS','microplate_washer','wash_residual_ul',
     2.0,2.1,5.0,true,'2026-06-30',true,'pass','Residual within limit post-maintenance'),
    ('CMC Vellore','ELISA-CMC-41','Erba Lisascan EM','microplate_reader','absorbance_linearity',
     1.000,0.965,3.5,false,'2026-06-29',false,'fail','Absorbance linearity 3.5% error and calibration overdue'),
    ('CMC Vellore','ELISA-CMC-42','Agappe Mispa Revo','microplate_reader','wavelength_accuracy_nm',
     405.0,405.4,0.1,true,'2026-06-29',true,'pass','Wavelength accuracy nominal at 405 nm'),
    ('KIMS Hyderabad','ELISA-KIM-51','Tecan Sunrise','microplate_reader','crosstalk_pct',
     0.0,1.6,1.6,false,'2026-06-28',true,'fail','Optical crosstalk 1.6% exceeds 1% — optics contamination'),
    ('KIMS Hyderabad','WASH-KIM-52','BioTek ELx405','microplate_washer','dispense_accuracy_pct',
     100.0,99.2,0.8,true,'2026-06-28',true,'pass','Dispense accuracy within 2% tolerance'),
    ('Yashoda Hyderabad','ELISA-YSH-61','Thermo Multiskan FC','microplate_reader','plate_uniformity',
     100.0,98.0,2.0,true,'2026-06-27',true,'pass','Plate uniformity CV within spec'),
    ('Kokilaben Mumbai','WASH-KKB-71','Tecan HydroFlex','microplate_washer','wash_residual_ul',
     2.0,6.8,240.0,false,'2026-06-27',false,'fail','Residual 6.8 uL, manifold clogged, calibration overdue — removed pending service'),
    ('Kokilaben Mumbai','ELISA-KKB-72','BioTek Synergy HTX','microplate_reader','absorbance_linearity',
     1.000,0.988,1.2,true,'2026-06-27',true,'conditional_pass','Absorbance 1.2% error within limit — monitor next QC')
  ) as q(hosp, dcode, dmodel, itype, param, refv, measv, devp, wtol, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.elisa_microplate_qc_capa_actions_r3447 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WASH-FRT-12','wash_residual_high','wash_manifold_clog','clean_or_replace_wash_manifold','in_progress','nabl_finding','2026-07-08',null,6000.00,'Manifold cleaned — re-verify residual next run'),
    ('ELISA-AIM-31','plate_uniformity_fail','lamp_intensity_drift','replace_lamp','open','nabh_finding','2026-07-06',null,18000.00,'Reader lamp replacement scheduled'),
    ('ELISA-CMC-41','absorbance_linearity_out_of_tolerance','filter_degraded','recalibrate_absorbance','escalated','iso_15189_deviation','2026-07-05',null,12000.00,'Absorbance drift plus overdue cal — escalated to OEM'),
    ('ELISA-KIM-51','optical_crosstalk_high','optics_contamination','clean_optics','verification_pending','internal_only','2026-07-04',null,3500.00,'Optics cleaned — verify crosstalk on retest'),
    ('WASH-KKB-71','wash_residual_high','wash_manifold_clog','remove_from_service','escalated','patient_safety_alert','2026-07-03',null,22000.00,'Washer removed — manifold and tubing replacement pending'),
    ('ELISA-FRT-11','wavelength_shift','filter_degraded','replace_optical_filter','closed','nabl_finding','2026-07-02','2026-07-06',9000.00,'Filter replaced and wavelength re-verified within tolerance'),
    ('WASH-MNP-22','dispense_volume_inaccurate','dispenser_pump_wear','replace_dispenser_pump','open','internal_only','2026-07-07',null,14000.00,'Dispenser pump wear — replacement ordered'),
    ('ELISA-KKB-72','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-01',null,0.00,'Preventive maintenance due — OEM PM visit backlog')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.elisa_microplate_qc_r3447 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3447_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.elisa_microplate_qc_r3447)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.elisa_microplate_qc_r3447 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3447_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3447_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3447_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
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
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.elisa_microplate_qc_r3447 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3447_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3447_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3447_parameter_verdict_matrix()
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
  from public.elisa_microplate_qc_r3447 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3447_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3447_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3447_monthly_calibration_trend()
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
  from public.elisa_microplate_qc_r3447 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3447_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3447_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3447_capa_status_board()
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
  from public.elisa_microplate_qc_capa_actions_r3447 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3447_capa_status_board() from public, anon;
grant execute on function public.founder_r3447_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3447_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.elisa_microplate_qc_capa_actions_r3447)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.elisa_microplate_qc_capa_actions_r3447 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3447_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3447_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3447_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, failed bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.elisa_microplate_qc_r3447 l
  group by l.parameter
  order by max(l.deviation_pct) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3447_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3447_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3447_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  within_tolerance boolean,
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
    l.qc_verdict, l.deviation_pct, l.within_tolerance, l.notes
  from public.elisa_microplate_qc_r3447 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.deviation_pct desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3447_high_risk_queue() from public, anon;
grant execute on function public.founder_r3447_high_risk_queue() to authenticated;
