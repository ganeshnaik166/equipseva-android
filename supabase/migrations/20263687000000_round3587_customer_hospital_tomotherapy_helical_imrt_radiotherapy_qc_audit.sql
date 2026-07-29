-- Round 3587: Customer Hospital TomoTherapy Helical IMRT Radiotherapy QC Audit
-- TomoTherapy helical IMRT QA — device model × QC parameter × reference/measured × deviation × tolerance × verdict × CAPA (AERB regulated)

-- =============================================================================
-- TABLE 1: tomotherapy_qc_r3587 — per-parameter TomoTherapy helical IMRT QC checks
-- =============================================================================
create table if not exists public.tomotherapy_qc_r3587 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'output_constancy','gantry_rotation_accuracy','couch_speed_accuracy',
    'mlc_leaf_timing_ms','beam_sync_accuracy','red_green_laser_align_mm'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  within_tolerance boolean not null,
  qa_physicist text,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tomotherapy_qc_r3587 enable row level security;

create index if not exists idx_tomotherapy_qc_r3587_org on public.tomotherapy_qc_r3587(organization_id);
create index if not exists idx_tomotherapy_qc_r3587_date on public.tomotherapy_qc_r3587(calibration_date);
create index if not exists idx_tomotherapy_qc_r3587_verdict on public.tomotherapy_qc_r3587(qc_verdict);

-- =============================================================================
-- TABLE 2: tomotherapy_qc_capa_actions_r3587 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.tomotherapy_qc_capa_actions_r3587 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.tomotherapy_qc_r3587(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'output_constancy_drift','gantry_rotation_out_of_tolerance','couch_speed_error',
    'mlc_leaf_timing_fault','beam_sync_out_of_tolerance','laser_alignment_error',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'linac_output_drift','gantry_drive_wear','couch_drive_calibration','mlc_actuator_fault',
    'beam_control_electronics','laser_mount_shift','software_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output','service_gantry_drive','recalibrate_couch','replace_mlc_actuator',
    'service_beam_control','realign_lasers','update_software_config','retrain_physics_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','aerb_license_condition','nabh_finding','cdsco_notifiable',
    'iso_13485_deviation','patient_safety_alert','internal_only','none'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tomotherapy_qc_capa_actions_r3587 enable row level security;

create index if not exists idx_tomotherapy_capa_r3587_log on public.tomotherapy_qc_capa_actions_r3587(qc_log_id);
create index if not exists idx_tomotherapy_capa_r3587_status on public.tomotherapy_qc_capa_actions_r3587(capa_status);

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
  insert into public.tomotherapy_qc_r3587 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, tolerance_pct,
    within_tolerance, qa_physicist, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.tolp,
    q.wtol, q.physn, q.caldt::date, q.verd, q.nt
  from (values
    ('Tata Memorial Mumbai','TOMO-TMH-01','Radixact X9','output_constancy',
     1.000,1.004,0.40,2.0,true,'Dr. Menon','2026-07-05','pass','Daily output constancy within 2% AERB action level'),
    ('Tata Memorial Mumbai','TOMO-TMH-01','Radixact X9','gantry_rotation_accuracy',
     360.0,360.4,0.11,1.0,true,'Dr. Menon','2026-07-05','pass','Gantry rotation accuracy nominal at 0.4 deg'),
    ('Apollo Chennai','TOMO-APL-02','TomoTherapy HDA','mlc_leaf_timing_ms',
     20.0,21.8,9.00,5.0,false,'Dr. Rao','2026-07-04','fail','MLC leaf timing 9% slow — exceeds 5% tolerance, treatments halted'),
    ('Apollo Chennai','TOMO-APL-02','TomoTherapy HDA','couch_speed_accuracy',
     5.00,5.06,1.20,2.0,true,'Dr. Rao','2026-07-04','pass','Couch translation speed within tolerance'),
    ('AIIMS Delhi','TOMO-AIM-03','Radixact X7','beam_sync_accuracy',
     100.0,98.2,1.80,2.0,true,'Dr. Sharma','2026-07-03','conditional_pass','Beam sync near 2% edge — monitor trend'),
    ('AIIMS Delhi','TOMO-AIM-03','Radixact X7','red_green_laser_align_mm',
     0.0,0.5,0.50,1.0,true,'Dr. Sharma','2026-07-03','pass','Red-green laser alignment 0.5 mm within 1 mm'),
    ('HCG Bangalore','TOMO-HCG-04','TomoTherapy HD','output_constancy',
     1.000,1.031,3.10,2.0,false,'Dr. Iyer','2026-07-02','fail','Output constancy 3.1% high — recalibration required per AERB'),
    ('HCG Bangalore','TOMO-HCG-04','TomoTherapy HD','gantry_rotation_accuracy',
     360.0,361.2,0.33,1.0,true,'Dr. Iyer','2026-07-02','pass','Gantry rotation within tolerance'),
    ('Rajiv Gandhi Cancer Delhi','TOMO-RGC-05','Radixact X9','couch_speed_accuracy',
     5.00,5.18,3.60,2.0,false,'Dr. Kapoor','2026-07-01','fail','Couch speed 3.6% fast — drive recalibration needed'),
    ('Rajiv Gandhi Cancer Delhi','TOMO-RGC-05','Radixact X9','mlc_leaf_timing_ms',
     20.0,20.4,2.00,5.0,true,'Dr. Kapoor','2026-07-01','pass','MLC leaf timing within tolerance'),
    ('Adyar Cancer Chennai','TOMO-ADC-06','TomoTherapy HDA','beam_sync_accuracy',
     100.0,96.5,3.50,2.0,false,'Dr. Natarajan','2026-06-30','fail','Beam sync 3.5% off — beam control electronics suspect'),
    ('Adyar Cancer Chennai','TOMO-ADC-06','TomoTherapy HDA','red_green_laser_align_mm',
     0.0,1.4,1.40,1.0,false,'Dr. Natarajan','2026-06-30','conditional_pass','Laser align 1.4 mm exceeds 1 mm — realign scheduled'),
    ('Kidwai Bangalore','TOMO-KDW-07','Radixact X7','output_constancy',
     1.000,1.009,0.90,2.0,true,'Dr. Prasad','2026-06-29','pass','Output constancy within tolerance post-service'),
    ('Kidwai Bangalore','TOMO-KDW-07','Radixact X7','gantry_rotation_accuracy',
     360.0,362.5,0.69,1.0,true,'Dr. Prasad','2026-06-29','conditional_pass','Gantry drift trend flagged — within tolerance but rising'),
    ('Amrita Kochi','TOMO-AMR-08','TomoTherapy HD','mlc_leaf_timing_ms',
     20.0,23.0,15.00,5.0,false,'Dr. Nair','2026-06-28','fail','MLC leaf timing 15% slow — actuator fault, unit down'),
    ('Amrita Kochi','TOMO-AMR-08','TomoTherapy HD','couch_speed_accuracy',
     5.00,5.04,0.80,2.0,true,'Dr. Nair','2026-06-28','pass','Couch speed within tolerance')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, tolp, wtol, physn, caldt, verd, nt);

  -- CAPA seed — attach to specific checks via device_code + parameter
  insert into public.tomotherapy_qc_capa_actions_r3587 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TOMO-APL-02','mlc_leaf_timing_ms','mlc_leaf_timing_fault','mlc_actuator_fault','replace_mlc_actuator','in_progress','aerb_notifiable','Biomedical Engineering','2026-07-09',null,185000.00,'MLC actuator replacement scheduled; treatments suspended pending recheck'),
    ('TOMO-HCG-04','output_constancy','output_constancy_drift','linac_output_drift','recalibrate_output','closed','aerb_license_condition','Radiation Safety Officer','2026-07-05','2026-07-04',42000.00,'Output recalibrated to 0.4% and revalidated per AERB license condition'),
    ('TOMO-RGC-05','couch_speed_accuracy','couch_speed_error','couch_drive_calibration','recalibrate_couch','verification_pending','iso_13485_deviation','Service Engineer','2026-07-06',null,28000.00,'Couch drive recalibrated — verification IMRT run pending'),
    ('TOMO-ADC-06','beam_sync_accuracy','beam_sync_out_of_tolerance','beam_control_electronics','service_beam_control','escalated','patient_safety_alert','OEM Field Service','2026-07-05',null,240000.00,'Beam sync fault escalated to Accuray — patient safety hold in place'),
    ('TOMO-ADC-06','red_green_laser_align_mm','laser_alignment_error','laser_mount_shift','realign_lasers','open','internal_only','QA Physics','2026-07-07',null,6500.00,'Red-green laser mount shifted — realignment kit ordered'),
    ('TOMO-AMR-08','mlc_leaf_timing_ms','mlc_leaf_timing_fault','mlc_actuator_fault','remove_from_service','escalated','aerb_notifiable','Radiation Safety Officer','2026-07-04',null,320000.00,'Unit removed from service — AERB notified of 15% MLC timing deviation'),
    ('TOMO-AIM-03','beam_sync_accuracy','beam_sync_out_of_tolerance','beam_control_electronics','schedule_oem_service','open','nabh_finding','QA Physics','2026-07-08',null,15000.00,'Beam sync near edge — OEM diagnostic service scheduled'),
    ('TOMO-KDW-07','gantry_rotation_accuracy','gantry_rotation_out_of_tolerance','gantry_drive_wear','service_gantry_drive','overdue','internal_only','Service Engineer','2026-07-03',null,54000.00,'Gantry drive wear service past target date — vendor slot delayed'),
    ('TOMO-TMH-01','gantry_rotation_accuracy','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','Biomedical Engineering','2026-07-15',null,0.00,'Quarterly preventive maintenance due — booking OEM visit')
  ) as q(dcode, param, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.tomotherapy_qc_r3587 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3587_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tomotherapy_qc_r3587)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tomotherapy_qc_r3587 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3587_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3587_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3587_device_model_scorecard()
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
  from public.tomotherapy_qc_r3587 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3587_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3587_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3587_parameter_verdict_matrix()
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
  from public.tomotherapy_qc_r3587 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3587_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3587_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3587_monthly_calibration_trend()
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
  from public.tomotherapy_qc_r3587 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3587_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3587_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3587_capa_status_board()
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
  from public.tomotherapy_qc_capa_actions_r3587 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3587_capa_status_board() from public, anon;
grant execute on function public.founder_r3587_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3587_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tomotherapy_qc_capa_actions_r3587)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tomotherapy_qc_capa_actions_r3587 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3587_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3587_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3587_accuracy_impact_digest()
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
  from public.tomotherapy_qc_r3587 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3587_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3587_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3587_high_risk_queue()
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
  from public.tomotherapy_qc_r3587 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.deviation_pct desc nulls last;
end;
$$;

revoke execute on function public.founder_r3587_high_risk_queue() from public, anon;
grant execute on function public.founder_r3587_high_risk_queue() to authenticated;
