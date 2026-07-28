-- Round 3514: Customer Hospital Dental Intraoral RVG Sensor / X-Ray QC Audit
-- Dental intraoral RVG sensor / X-ray QC — parameter (kVp accuracy, exposure time, spatial resolution,
-- entrance dose, sensor dead pixels, image contrast) x reference/measured/deviation x within-tolerance x
-- calibration date x qc verdict x device model x CAPA closure across Indian hospital dental radiography.

-- =============================================================================
-- TABLE 1: dental_rvg_qc_r3514 — per-parameter dental RVG / X-ray QC measurements
-- =============================================================================
create table if not exists public.dental_rvg_qc_r3514 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  qc_ref text not null,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'kvp_accuracy','exposure_time_ms','spatial_resolution_lppm',
    'entrance_dose_ugy','sensor_dead_pixels','image_contrast'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  tolerance_limit_pct numeric(5,2),
  calibration_date date not null,
  next_calibration_date date,
  tester_name text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_rvg_qc_r3514 enable row level security;

create index if not exists idx_dental_rvg_qc_r3514_org on public.dental_rvg_qc_r3514(organization_id);
create index if not exists idx_dental_rvg_qc_r3514_date on public.dental_rvg_qc_r3514(calibration_date);
create index if not exists idx_dental_rvg_qc_r3514_verdict on public.dental_rvg_qc_r3514(qc_verdict);

-- =============================================================================
-- TABLE 2: dental_rvg_qc_capa_actions_r3514 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dental_rvg_qc_capa_actions_r3514 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.dental_rvg_qc_r3514(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'kvp_out_of_tolerance','exposure_time_drift','resolution_below_spec',
    'dose_out_of_tolerance','dead_pixel_cluster','contrast_degraded',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'generator_drift','timer_circuit_fault','sensor_scintillator_aging','sensor_pixel_defect',
    'collimator_misalignment','software_calibration_error','operator_technique_error',
    'pending_investigation','preventive_service_backlog','cable_connector_wear'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_generator','adjust_exposure_timer','replace_rvg_sensor','clean_recalibrate_sensor',
    'realign_collimator','update_calibration_software','retrain_radiology_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_finding','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dental_rvg_qc_capa_actions_r3514 enable row level security;

create index if not exists idx_dental_rvg_capa_r3514_org on public.dental_rvg_qc_capa_actions_r3514(organization_id);
create index if not exists idx_dental_rvg_capa_r3514_log on public.dental_rvg_qc_capa_actions_r3514(qc_log_id);
create index if not exists idx_dental_rvg_capa_r3514_status on public.dental_rvg_qc_capa_actions_r3514(capa_status);

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

  -- 16 QC measurement rows
  insert into public.dental_rvg_qc_r3514 (
    organization_id, qc_ref, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, tolerance_limit_pct,
    calibration_date, next_calibration_date, tester_name, qc_verdict, notes
  )
  select v_org_id, q.qref, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devpct, q.wtol, q.tollim,
    q.caldate::date, q.nextcal::date, q.tester, q.qv, q.nt
  from (values
    ('QC-RVG-0001','Apollo Chennai','RVG-APL-01','Carestream RVG 5200','kvp_accuracy',
     60,60.5,0.83,true,5,'2026-07-05','2027-07-05','S. Ramesh','pass','Quarterly kVp check within tolerance'),
    ('QC-RVG-0002','Apollo Chennai','RVG-APL-01','Carestream RVG 5200','exposure_time_ms',
     200,206,3.0,true,10,'2026-07-05','2027-07-05','S. Ramesh','pass','Exposure timer within 10% tolerance'),
    ('QC-RVG-0003','Apollo Chennai','RVG-APL-02','Dentsply Sirona Xios','spatial_resolution_lppm',
     20,18,-10.0,false,5,'2026-07-06','2027-07-06','S. Ramesh','conditional_pass','Line-pair resolution 18 lp/mm below 20 lp/mm spec'),
    ('QC-RVG-0004','Fortis Gurgaon','RVG-FRT-11','Kodak RVG 6100','entrance_dose_ugy',
     900,1080,20.0,false,10,'2026-07-08','2027-07-08','A. Menon','fail','Entrance dose 20% above reference — generator output high'),
    ('QC-RVG-0005','Fortis Gurgaon','RVG-FRT-11','Kodak RVG 6100','kvp_accuracy',
     65,61,-6.15,false,5,'2026-07-08','2027-07-08','A. Menon','conditional_pass','kVp reads 6% low — generator drift flagged'),
    ('QC-RVG-0006','Fortis Gurgaon','RVG-FRT-12','Planmeca ProSensor','sensor_dead_pixels',
     5,12,140.0,false,0,'2026-07-10','2027-07-10','A. Menon','fail','12 dead pixels vs 5 allowed — cluster near active area'),
    ('QC-RVG-0007','Manipal Bengaluru','RVG-MNP-21','Gendex GXS-700','image_contrast',
     0.85,0.82,-3.53,true,8,'2026-06-12','2027-06-12','R. Iyer','pass','Contrast ratio within tolerance'),
    ('QC-RVG-0008','Manipal Bengaluru','RVG-MNP-21','Gendex GXS-700','exposure_time_ms',
     250,278,11.2,false,10,'2026-06-12','2027-06-12','R. Iyer','conditional_pass','Exposure time 11% high — timer circuit drift'),
    ('QC-RVG-0009','AIIMS Delhi','RVG-AIM-31','Acteon Sopix','entrance_dose_ugy',
     800,812,1.5,true,10,'2026-06-15','2027-06-15','P. Nair','pass','Dose within AERB reference range'),
    ('QC-RVG-0010','AIIMS Delhi','RVG-AIM-32','Carestream RVG 5200','spatial_resolution_lppm',
     20,20,0.0,true,5,'2026-06-18','2027-06-18','P. Nair','pass','Resolution meets 20 lp/mm spec'),
    ('QC-RVG-0011','CMC Vellore','RVG-CMC-41','Dentsply Sirona Xios','kvp_accuracy',
     63,69,9.52,false,5,'2026-06-20','2027-06-20','J. Thomas','fail','kVp 9.5% high — generator recalibration required'),
    ('QC-RVG-0012','CMC Vellore','RVG-CMC-41','Dentsply Sirona Xios','image_contrast',
     0.90,0.71,-21.1,false,8,'2026-05-09','2027-05-09','J. Thomas','fail','Contrast degraded 21% — scintillator aging'),
    ('QC-RVG-0013','KIMS Hyderabad','RVG-KIM-51','Kodak RVG 6100','sensor_dead_pixels',
     5,2,-60.0,true,0,'2026-05-14','2027-05-14','V. Reddy','pass','Only 2 dead pixels — within limit'),
    ('QC-RVG-0014','KIMS Hyderabad','RVG-KIM-52','Planmeca ProSensor','exposure_time_ms',
     180,182,1.1,true,10,'2026-05-18','2027-05-18','V. Reddy','pass','Exposure timer nominal'),
    ('QC-RVG-0015','Yashoda Hyderabad','RVG-YSH-61','Gendex GXS-700','entrance_dose_ugy',
     850,1120,31.8,false,10,'2026-05-22','2027-05-22','K. Rao','fail','Dose 32% high and calibration overdue — AERB flag'),
    ('QC-RVG-0016','Kokilaben Mumbai','RVG-KKB-71','Acteon Sopix','spatial_resolution_lppm',
     22,15,-31.8,false,5,'2026-05-27','2027-05-27','D. Shah','fail','Resolution 15 lp/mm far below 22 lp/mm — sensor aging')
  ) as q(qref, hosp, dcode, dmodel, param, refv, measv, devpct, wtol, tollim, caldate, nextcal, tester, qv, nt);

  -- CAPA seed — attach to specific measurements via qc_ref business key
  insert into public.dental_rvg_qc_capa_actions_r3514 (
    organization_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('QC-RVG-0004','dose_out_of_tolerance','software_calibration_error','recalibrate_generator','in_progress','aerb_finding','Radiology QA','2026-07-20',null,18000.00,'Entrance dose 20% high — generator recalibration in progress; AERB dose log flagged'),
    ('QC-RVG-0006','dead_pixel_cluster','sensor_pixel_defect','replace_rvg_sensor','escalated','patient_safety_alert','Biomedical Engg','2026-07-18',null,145000.00,'Dead-pixel cluster exceeds limit — sensor replacement escalated to OEM'),
    ('QC-RVG-0011','kvp_out_of_tolerance','generator_drift','recalibrate_generator','closed','iso_13485_deviation','Radiology QA','2026-07-10','2026-07-08',22000.00,'kVp drift corrected and revalidated within tolerance'),
    ('QC-RVG-0012','contrast_degraded','sensor_scintillator_aging','replace_rvg_sensor','open','nabh_finding','Biomedical Engg','2026-07-22',null,138000.00,'Image contrast degraded — scintillator aging, sensor replacement quoted'),
    ('QC-RVG-0015','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','aerb_finding','Service Coordinator','2026-06-30',null,15000.00,'Dose high and calibration overdue — OEM PM past target date'),
    ('QC-RVG-0016','resolution_below_spec','sensor_scintillator_aging','replace_rvg_sensor','verification_pending','nabh_finding','Biomedical Engg','2026-06-25',null,132000.00,'Spatial resolution far below spec — replacement sensor installed, verify next QC'),
    ('QC-RVG-0005','kvp_out_of_tolerance','generator_drift','recalibrate_generator','in_progress','internal_only','Radiology QA','2026-07-19',null,12000.00,'kVp reading low — generator recalibration scheduled'),
    ('QC-RVG-0008','exposure_time_drift','timer_circuit_fault','adjust_exposure_timer','open','internal_only','Biomedical Engg','2026-07-21',null,9000.00,'Exposure-time drift beyond tolerance — timer circuit adjustment pending')
  ) as q(qref, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.dental_rvg_qc_r3514 e
    on e.organization_id = v_org_id and e.qc_ref = q.qref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3514_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_rvg_qc_r3514)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dental_rvg_qc_r3514 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3514_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3514_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3514_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
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
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.dental_rvg_qc_r3514 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3514_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3514_device_model_scorecard() to authenticated;

-- 3) Parameter x verdict matrix
create or replace function public.founder_r3514_parameter_verdict_matrix()
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
  from public.dental_rvg_qc_r3514 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3514_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3514_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3514_monthly_accuracy_trend()
returns table(
  calibration_month date,
  checks bigint,
  passed bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric
)
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
  from public.dental_rvg_qc_r3514 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3514_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3514_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3514_capa_status_board()
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
  from public.dental_rvg_qc_capa_actions_r3514 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3514_capa_status_board() from public, anon;
grant execute on function public.founder_r3514_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3514_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dental_rvg_qc_capa_actions_r3514)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dental_rvg_qc_capa_actions_r3514 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3514_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3514_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory-impact digest
create or replace function public.founder_r3514_accuracy_impact_digest()
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
  from public.dental_rvg_qc_capa_actions_r3514 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3514_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3514_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3514_high_risk_queue()
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.within_tolerance, l.notes
  from public.dental_rvg_qc_r3514 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3514_high_risk_queue() from public, anon;
grant execute on function public.founder_r3514_high_risk_queue() to authenticated;
