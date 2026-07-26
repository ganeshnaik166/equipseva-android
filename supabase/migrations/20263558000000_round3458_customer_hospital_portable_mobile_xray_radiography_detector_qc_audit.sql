-- Round 3458: Customer Hospital Portable / Mobile X-Ray (Digital Radiography) Detector QC Audit
-- Portable/mobile DR QC — device model × parameter (kVp/mAs/output/DAP/DQE/collimation) × reference vs measured × deviation × tolerance × calibration date × verdict × CAPA

-- =============================================================================
-- TABLE 1: portable_xray_qc_r3458 — per-parameter portable/mobile DR QC checks
-- =============================================================================
create table if not exists public.portable_xray_qc_r3458 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'kvp_accuracy','mas_linearity','output_ugy','dose_area_product','detector_dqe','collimation_mm'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  department text,
  technologist text,
  created_at timestamptz not null default now()
);

alter table public.portable_xray_qc_r3458 enable row level security;

create index if not exists idx_portable_xray_qc_r3458_org on public.portable_xray_qc_r3458(organization_id);
create index if not exists idx_portable_xray_qc_r3458_caldate on public.portable_xray_qc_r3458(calibration_date);
create index if not exists idx_portable_xray_qc_r3458_verdict on public.portable_xray_qc_r3458(qc_verdict);

-- =============================================================================
-- TABLE 2: portable_xray_qc_capa_actions_r3458 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.portable_xray_qc_capa_actions_r3458 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.portable_xray_qc_r3458(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'kvp_accuracy_out_of_tolerance','mas_linearity_out_of_tolerance','output_deviation',
    'dose_area_product_error','detector_dqe_degraded','collimation_misalignment',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'generator_drift','detector_panel_aging','collimator_misalignment','aec_sensor_fault',
    'software_calibration_error','cable_connector_fault','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_generator','replace_detector_panel','realign_collimator','replace_aec_sensor',
    'update_calibration_software','replace_cable','retrain_radiographer',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_finding','aerb_notifiable','nabh_finding','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.portable_xray_qc_capa_actions_r3458 enable row level security;

create index if not exists idx_portable_xray_capa_r3458_log on public.portable_xray_qc_capa_actions_r3458(qc_log_id);
create index if not exists idx_portable_xray_capa_r3458_status on public.portable_xray_qc_capa_actions_r3458(capa_status);

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
  insert into public.portable_xray_qc_r3458 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes, department, technologist
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol,
    q.caldt::date, q.qv, q.nt, q.dept, q.tech
  from (values
    ('Apollo Chennai','PXR-APL-01','GE Optima XR240amx','kvp_accuracy',
     80,79.2,-1.0,true,'2026-06-15','pass','kVp accuracy within +/-2% at 80 kVp setpoint','Radiology','R. Menon'),
    ('Apollo Chennai','PXR-APL-02','GE Optima XR240amx','mas_linearity',
     1.0,0.98,-2.0,true,'2026-06-15','pass','mAs linearity coefficient of variation within 0.05','Radiology','R. Menon'),
    ('Apollo Chennai','PXR-APL-03','GE Optima XR240amx','detector_dqe',
     0.65,0.63,-3.1,true,'2026-06-15','pass','Detector DQE nominal for CsI flat panel','Radiology','R. Menon'),
    ('Fortis Gurgaon','PXR-FRT-11','Siemens Mobilett Elara Max','output_ugy',
     100,92,-8.0,false,'2026-05-20','conditional_pass','Output 8% low at reference technique — generator recheck due','Radiology','S. Gupta'),
    ('Fortis Gurgaon','PXR-FRT-12','Siemens Mobilett Elara Max','kvp_accuracy',
     100,106.5,6.5,false,'2026-05-20','fail','kVp reads 6.5% high at 100 kVp — beyond +/-5% AERB limit','Radiology','S. Gupta'),
    ('Fortis Gurgaon','PXR-FRT-13','Siemens Mobilett Elara Max','collimation_mm',
     10,22,2.2,false,'2026-05-20','fail','Collimation light-field misalignment 22 mm at 100 cm SID — exceeds 2% SID','Radiology','S. Gupta'),
    ('Manipal Bengaluru','PXR-MNP-21','Philips MobileDiagnost wDR','detector_dqe',
     0.65,0.55,-15.4,false,'2026-05-10','fail','DQE degraded 15% — wireless DR panel aging suspected','Radiology','A. Rao'),
    ('Manipal Bengaluru','PXR-MNP-22','Philips MobileDiagnost wDR','dose_area_product',
     1.2,1.26,5.0,true,'2026-05-10','conditional_pass','DAP meter 5% high — within action limit, monitor trend','Radiology','A. Rao'),
    ('AIIMS Delhi','PXR-AIM-31','Samsung GM85','mas_linearity',
     1.0,1.09,9.0,false,'2026-04-22','fail','mAs linearity out of tolerance at low mAs stations','Radiology','K. Nair'),
    ('AIIMS Delhi','PXR-AIM-32','Samsung GM85','kvp_accuracy',
     70,70.7,1.0,true,'2026-04-22','pass','kVp accuracy within limit at 70 kVp','Radiology','K. Nair'),
    ('CMC Vellore','PXR-CMC-41','Fujifilm FDR nano','output_ugy',
     100,99,-1.0,true,'2026-04-15','pass','Output reproducible within 1% at reference technique','Radiology','J. Thomas'),
    ('CMC Vellore','PXR-CMC-42','Fujifilm FDR nano','collimation_mm',
     10,8,0.8,true,'2026-04-15','pass','Collimation within 2% SID tolerance','Radiology','J. Thomas'),
    ('KIMS Hyderabad','PXR-KIM-51','GE Optima XR240amx','dose_area_product',
     1.2,1.18,-1.7,true,'2026-06-03','pass','DAP meter agreement within 2%','Radiology','P. Reddy'),
    ('KIMS Hyderabad','PXR-KIM-52','GE Optima XR240amx','detector_dqe',
     0.65,0.60,-7.7,false,'2026-06-03','conditional_pass','DQE 8% low — schedule panel diagnostics','Radiology','P. Reddy'),
    ('Yashoda Hyderabad','PXR-YSH-61','Siemens Mobilett Elara Max','output_ugy',
     100,88,-12.0,false,'2026-05-05','fail','Output 12% low — AEC ion-chamber sensor fault suspected','Radiology','M. Iyer'),
    ('Kokilaben Mumbai','PXR-KKB-71','Philips MobileDiagnost wDR','kvp_accuracy',
     90,84.6,-6.0,false,'2026-04-08','fail','kVp 6% low at 90 kVp — generator calibration drift','Radiology','D. Shah')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldt, qv, nt, dept, tech);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.portable_xray_qc_capa_actions_r3458 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('PXR-FRT-11','output_deviation','generator_drift','recalibrate_generator','in_progress','aerb_finding','2026-05-30',null,18000.00,'Generator output recalibrated — verification re-test pending'),
    ('PXR-FRT-12','kvp_accuracy_out_of_tolerance','generator_drift','recalibrate_generator','verification_pending','aerb_notifiable','2026-05-28',null,22000.00,'kVp calibration adjusted, awaiting re-test at 100 kVp'),
    ('PXR-FRT-13','collimation_misalignment','collimator_misalignment','realign_collimator','closed','nabh_finding','2026-05-25','2026-05-24',9500.00,'Collimator light-field realigned and validated within tolerance'),
    ('PXR-MNP-21','detector_dqe_degraded','detector_panel_aging','replace_detector_panel','escalated','patient_safety_alert','2026-05-18',null,480000.00,'Wireless DR panel replacement escalated to OEM — image-quality risk'),
    ('PXR-AIM-31','mas_linearity_out_of_tolerance','software_calibration_error','update_calibration_software','open','internal_only','2026-05-05',null,6000.00,'mAs linearity recalibration via service software scheduled'),
    ('PXR-KIM-52','detector_dqe_degraded','detector_panel_aging','schedule_oem_service','overdue','aerb_finding','2026-06-15',null,35000.00,'Panel diagnostics OEM visit past target date — vendor delay'),
    ('PXR-YSH-61','output_deviation','aec_sensor_fault','replace_aec_sensor','in_progress','aerb_finding','2026-05-20',null,28000.00,'AEC ion-chamber sensor replacement in progress'),
    ('PXR-KKB-71','kvp_accuracy_out_of_tolerance','generator_drift','recalibrate_generator','closed','none','2026-06-12','2026-06-10',15000.00,'Generator drift corrected and kVp re-verified within +/-2%')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.portable_xray_qc_r3458 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3458_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.portable_xray_qc_r3458)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.portable_xray_qc_r3458 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3458_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3458_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3458_device_model_scorecard()
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
  from public.portable_xray_qc_r3458 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3458_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3458_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3458_parameter_verdict_matrix()
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
  from public.portable_xray_qc_r3458 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3458_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3458_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3458_monthly_calibration_trend()
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
  from public.portable_xray_qc_r3458 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3458_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3458_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3458_capa_status_board()
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
  from public.portable_xray_qc_capa_actions_r3458 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3458_capa_status_board() from public, anon;
grant execute on function public.founder_r3458_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3458_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.portable_xray_qc_capa_actions_r3458)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.portable_xray_qc_capa_actions_r3458 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3458_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3458_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (regulatory impact of accuracy findings)
create or replace function public.founder_r3458_accuracy_impact_digest()
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
  from public.portable_xray_qc_capa_actions_r3458 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3458_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3458_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3458_high_risk_queue()
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
  from public.portable_xray_qc_r3458 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by abs(coalesce(l.deviation_pct,0)) desc, l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3458_high_risk_queue() from public, anon;
grant execute on function public.founder_r3458_high_risk_queue() to authenticated;
