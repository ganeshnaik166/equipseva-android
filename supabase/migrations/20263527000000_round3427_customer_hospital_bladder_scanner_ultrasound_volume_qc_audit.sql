-- Round 3427: Customer Hospital Bladder-Scanner Ultrasound Bladder-Volume QC Audit
-- Portable bladder-scanner (ultrasound post-void-residual volume) QA — device model × ward × phantom vs
-- measured volume × deviation % × probe frequency × scan plane × battery health × transducer condition ×
-- calibration currency × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 — per-device volume-accuracy QC checks
-- =============================================================================
create table if not exists public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  ward_or_dept text not null,
  phantom_volume_ml numeric(7,2),
  measured_volume_ml numeric(7,2),
  deviation_pct numeric(6,2),
  probe_frequency_mhz numeric(4,2),
  scan_plane text not null check (scan_plane in (
    'sagittal','transverse','both'
  )),
  battery_health_pct int,
  transducer_ok boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 enable row level security;

create index if not exists idx_bladder_scanner_qc_r3427_org on public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427(organization_id);
create index if not exists idx_bladder_scanner_qc_r3427_caldate on public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427(calibration_date);
create index if not exists idx_bladder_scanner_qc_r3427_verdict on public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427(qc_verdict);

-- =============================================================================
-- TABLE 2: customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'volume_accuracy_out_of_tolerance','deviation_exceeds_limit','transducer_fault',
    'battery_degraded','calibration_overdue','probe_frequency_drift',
    'image_quality_poor','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_element_degraded','probe_wear','battery_end_of_life','software_algorithm_error',
    'operator_technique_error','coupling_gel_insufficient','calibration_drift',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_scanner','replace_transducer','replace_battery','update_firmware',
    'retrain_nursing_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427 enable row level security;

create index if not exists idx_bladder_scanner_capa_r3427_log on public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427(qc_log_id);
create index if not exists idx_bladder_scanner_capa_r3427_status on public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427(capa_status);

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
  insert into public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 (
    organization_id, hospital_name, device_code, device_model, ward_or_dept,
    phantom_volume_ml, measured_volume_ml, deviation_pct, probe_frequency_mhz, scan_plane,
    battery_health_pct, transducer_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.ward,
    q.phantom, q.measured, q.dev, q.freq, q.plane,
    q.batt, q.tok, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','BSC-APL-01','Verathon BVI 9400','urology',
     400,392,-2.0,3.7,'both',95,true,'2026-06-20','pass','Quarterly QC — BVI 9400 within tolerance band'),
    ('Apollo Chennai','BSC-APL-02','Verathon Prime Plus','post_op_ward',
     200,206,3.0,3.7,'transverse',88,true,'2026-06-20','pass','Prime Plus PVR accuracy nominal on 200ml phantom'),
    ('Fortis Gurgaon','BSC-FRT-11','Caresono PadScan HD5','general_ward',
     500,470,-6.0,2.5,'both',72,true,'2026-06-18','conditional_pass','Deviation -6% approaching limit — recalibration flagged'),
    ('Fortis Gurgaon','BSC-FRT-12','Verathon BVI 6100','icu',
     300,255,-15.0,3.7,'sagittal',40,false,'2026-06-18','fail','Transducer fault, -15% deviation and low battery health'),
    ('Manipal Bengaluru','BSC-MNP-21','Mcube Biocon-700','urology',
     400,384,-4.0,3.5,'both',80,true,'2026-06-15','pass','Biocon-700 within ±5% on 400ml phantom'),
    ('Manipal Bengaluru','BSC-MNP-22','Verathon BVI 9400','nephrology',
     250,300,20.0,3.7,'transverse',55,true,'2026-06-15','fail','Over-read +20% out of tolerance — firmware algorithm suspected'),
    ('AIIMS Delhi','BSC-AIM-31','Verathon Prime Plus','urology',
     500,515,3.0,3.7,'both',91,true,'2026-06-22','pass','Prime Plus PVR QC pass on 500ml phantom'),
    ('AIIMS Delhi','BSC-AIM-32','Caresono PadScan HD5','emergency',
     150,138,-8.0,2.5,'sagittal',33,true,'2026-06-22','conditional_pass','Deviation -8% and battery health low — battery replacement due'),
    ('CMC Vellore','BSC-CMC-41','Verathon BVI 6100','general_ward',
     400,408,2.0,3.7,'both',84,true,'2026-06-10','pass','BVI 6100 QC pass post-AMC service'),
    ('CMC Vellore','BSC-CMC-42','Mcube Biocon-700','post_op_ward',
     300,261,-13.0,3.5,'transverse',60,true,'2026-06-10','fail','Under-read -13% — probe wear suspected, transducer swap ordered'),
    ('KIMS Hyderabad','BSC-KIM-51','Verathon BVI 9400','urology',
     500,490,-2.0,3.7,'both',96,true,'2026-06-25','pass','BVI 9400 QC pass on 500ml phantom'),
    ('KIMS Hyderabad','BSC-KIM-52','Verathon Prime Plus','icu',
     200,214,7.0,3.7,'both',47,true,'2026-06-25','conditional_pass','Deviation +7% and calibration overdue — recalibration scheduled'),
    ('Yashoda Hyderabad','BSC-YSH-61','Caresono PadScan HD5','nephrology',
     350,336,-4.0,2.5,'transverse',78,true,'2026-05-28','pass','PadScan HD5 QC nominal on 350ml phantom'),
    ('Kokilaben Mumbai','BSC-KKB-71','Verathon BVI 6100','emergency',
     300,240,-20.0,3.7,'sagittal',25,false,'2026-05-20','fail','Transducer fault, -20% deviation and critically low battery — removed from service'),
    ('Kokilaben Mumbai','BSC-KKB-72','Mcube Biocon-700','urology',
     450,459,2.0,3.5,'both',90,true,'2026-06-28','pass','Biocon-700 QC pass on 450ml phantom'),
    ('Narayana Bengaluru','BSC-NRY-81','Verathon BVI 9400','post_op_ward',
     400,372,-7.0,3.7,'both',52,true,'2026-06-05','conditional_pass','Deviation -7% — preventive maintenance backlog flagged')
  ) as q(hosp, dcode, model, ward, phantom, measured, dev, freq, plane, batt, tok, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.owner, q.nt
  from (values
    ('BSC-FRT-12','transducer_fault','transducer_element_degraded','replace_transducer','in_progress','iso_13485_deviation','2026-06-28',null,42000.00,'Biomedical Engineering','Transducer replacement in progress — -15% deviation on 300ml phantom'),
    ('BSC-MNP-22','volume_accuracy_out_of_tolerance','software_algorithm_error','update_firmware','open','cdsco_notifiable','2026-06-30',null,12000.00,'OEM Service','Over-read +20% — firmware algorithm update requested from OEM'),
    ('BSC-CMC-42','deviation_exceeds_limit','probe_wear','replace_transducer','verification_pending','internal_only','2026-06-25',null,38000.00,'Biomedical Engineering','Probe wear — transducer replaced, verify accuracy next QC'),
    ('BSC-KKB-71','transducer_fault','transducer_element_degraded','remove_from_service','closed','patient_safety_alert','2026-05-25','2026-05-22',45000.00,'Nursing Superintendent','Removed from service — replacement unit deployed and validated'),
    ('BSC-FRT-11','deviation_exceeds_limit','calibration_drift','recalibrate_scanner','closed','internal_only','2026-06-22','2026-06-21',6000.00,'Biomedical Engineering','Recalibrated — deviation back within tolerance'),
    ('BSC-AIM-32','battery_degraded','battery_end_of_life','replace_battery','open','none','2026-07-02',null,8500.00,'Biomedical Engineering','Battery health 33% — replacement battery pack ordered'),
    ('BSC-KIM-52','calibration_overdue','calibration_drift','recalibrate_scanner','overdue','nabh_finding','2026-06-27',null,6000.00,'Quality Cell','Calibration overdue — recalibration past target date, vendor delay'),
    ('BSC-NRY-81','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','escalated','internal_only','2026-06-10',null,15000.00,'Biomedical Engineering','Preventive maintenance backlog — escalated to OEM scheduling')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, owner, nt)
  join public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3427_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3427_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3427_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3427_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  avg_deviation_pct numeric,
  avg_battery_health_pct numeric,
  transducer_faults bigint,
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
    round(avg(l.deviation_pct), 2),
    round(avg(l.battery_health_pct)::numeric, 1),
    count(*) filter (where l.transducer_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3427_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3427_device_model_scorecard() to authenticated;

-- 3) Ward × verdict matrix
create or replace function public.founder_r3427_ward_verdict_matrix()
returns table(ward_or_dept text, qc_verdict text, checks bigint, avg_deviation_pct numeric, transducer_faults bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ward_or_dept, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.transducer_ok = false)::bigint
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 l
  group by l.ward_or_dept, l.qc_verdict
  order by l.ward_or_dept, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3427_ward_verdict_matrix() from public, anon;
grant execute on function public.founder_r3427_ward_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3427_monthly_calibration_trend()
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
    count(*) filter (where abs(l.deviation_pct) > 15)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3427_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3427_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3427_capa_status_board()
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
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3427_capa_status_board() from public, anon;
grant execute on function public.founder_r3427_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3427_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_capa_actions_r3427 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3427_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3427_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest — QC checks bucketed by volume-deviation tolerance band
create or replace function public.founder_r3427_accuracy_impact_digest()
returns table(tolerance_band text, checks bigint, passed bigint, failed bigint, avg_deviation_pct numeric, max_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select band.tolerance_band,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 l
  cross join lateral (
    select case
      when abs(coalesce(l.deviation_pct, 0)) <= 5 then 'within_5pct'
      when abs(coalesce(l.deviation_pct, 0)) <= 10 then 'within_10pct'
      when abs(coalesce(l.deviation_pct, 0)) <= 15 then 'marginal_10_15pct'
      else 'out_of_tolerance_gt15pct'
    end as tolerance_band
  ) band
  group by band.tolerance_band
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3427_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3427_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / transducer / low battery)
create or replace function public.founder_r3427_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  ward_or_dept text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  measured_volume_ml numeric,
  battery_health_pct int,
  transducer_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.ward_or_dept, l.calibration_date,
    l.qc_verdict, l.deviation_pct, l.measured_volume_ml, l.battery_health_pct,
    case when l.transducer_ok then 'ok' else 'fault' end, l.notes
  from public.customer_hospital_bladder_scanner_ultrasound_volume_qc_r3427 l
  where l.qc_verdict in ('conditional_pass','fail')
     or abs(l.deviation_pct) > 15
     or l.transducer_ok = false
     or l.battery_health_pct < 40
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3427_high_risk_queue() from public, anon;
grant execute on function public.founder_r3427_high_risk_queue() to authenticated;
