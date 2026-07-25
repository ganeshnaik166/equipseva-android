-- Round 3438: Customer Hospital Bispectral-Index (BIS) / Depth-of-Anesthesia Monitor QC Audit
-- BIS / processed-EEG depth-of-anesthesia monitor QC — parameter × device model × index accuracy × EMG × signal quality × suppression ratio × sensor lot × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: bis_depth_anesthesia_qc_r3438 — per-device BIS depth-of-anesthesia QC checks
-- =============================================================================
create table if not exists public.bis_depth_anesthesia_qc_r3438 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'bis_index','emg_db','signal_quality_index','suppression_ratio','burst_count'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  sensor_lot text,
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bis_depth_anesthesia_qc_r3438 enable row level security;

create index if not exists idx_bis_depth_anesthesia_qc_r3438_org on public.bis_depth_anesthesia_qc_r3438(organization_id);
create index if not exists idx_bis_depth_anesthesia_qc_r3438_cal on public.bis_depth_anesthesia_qc_r3438(calibration_date);
create index if not exists idx_bis_depth_anesthesia_qc_r3438_verdict on public.bis_depth_anesthesia_qc_r3438(qc_verdict);

-- =============================================================================
-- TABLE 2: bis_depth_anesthesia_qc_capa_actions_r3438 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.bis_depth_anesthesia_qc_capa_actions_r3438 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.bis_depth_anesthesia_qc_r3438(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'index_accuracy_out_of_tolerance','emg_interference_high','signal_quality_low',
    'suppression_ratio_error','burst_count_drift','sensor_lot_defect',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_electrode_degraded','emg_electrical_interference','patient_movement_artifact',
    'cable_impedance_high','module_calibration_drift','software_algorithm_error',
    'operator_setup_error','pending_investigation','sensor_lot_recall','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_bis_sensor','recalibrate_module','replace_patient_cable','reduce_emg_interference',
    'update_software','retrain_anesthesia_staff','quarantine_sensor_lot','schedule_oem_service',
    'remove_from_service','none_required'
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
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bis_depth_anesthesia_qc_capa_actions_r3438 enable row level security;

create index if not exists idx_bis_depth_anesthesia_capa_r3438_log on public.bis_depth_anesthesia_qc_capa_actions_r3438(qc_log_id);
create index if not exists idx_bis_depth_anesthesia_capa_r3438_status on public.bis_depth_anesthesia_qc_capa_actions_r3438(capa_status);

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
  insert into public.bis_depth_anesthesia_qc_r3438 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, sensor_lot,
    within_tolerance, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval::numeric, q.measval::numeric, q.devpct::numeric, q.slot,
    q.wtol, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','BIS-APL-01','BIS Complete','bis_index',
     45.0,45.4,0.9,'BIS-QUATRO-L2451',true,'2026-07-05','pass','BIS index simulator check within tolerance'),
    ('Apollo Chennai','BIS-APL-02','BIS VISTA','signal_quality_index',
     100.0,98.0,2.0,'BIS-QUATRO-L2451',true,'2026-07-05','pass','SQI nominal at 98 on 4-channel sensor'),
    ('Fortis Gurgaon','BIS-FRT-11','BISx','emg_db',
     30.0,41.0,36.7,'BIS-EXT-L3120',false,'2026-07-04','conditional_pass','EMG elevated to 41 dB from electrocautery interference'),
    ('Fortis Gurgaon','BIS-FRT-12','BIS Complete','bis_index',
     60.0,66.5,10.8,'BIS-QUATRO-L3055',false,'2026-07-04','fail','BIS index 66.5 vs 60 reference — 10.8% high, out of tolerance'),
    ('Manipal Bengaluru','BIS-MNP-21','A-3000','suppression_ratio',
     0.0,6.0,null,'BIS-QUATRO-L2988',false,'2026-07-03','fail','Suppression ratio nonzero at 6% during zero-input test — module fault'),
    ('Manipal Bengaluru','BIS-MNP-22','BIS Advance','burst_count',
     12.0,12.0,0.0,'BIS-QUATRO-L2988',true,'2026-07-03','pass','Burst count matches simulator reference'),
    ('AIIMS Delhi','BIS-AIM-31','BIS VISTA','bis_index',
     40.0,41.2,3.0,'BIS-QUATRO-L3101',true,'2026-06-30','conditional_pass','BIS index 3% high — upward drift trend flagged for recheck'),
    ('AIIMS Delhi','BIS-AIM-32','BISx','signal_quality_index',
     100.0,74.0,26.0,'BIS-EXT-L2870',false,'2026-06-30','fail','SQI collapsed to 74 — sensor impedance high, artifact'),
    ('CMC Vellore','BIS-CMC-41','BIS Complete','emg_db',
     30.0,33.0,10.0,'BIS-QUATRO-L3210',true,'2026-06-29','pass','EMG within acceptable band'),
    ('CMC Vellore','BIS-CMC-42','A-3000','bis_index',
     50.0,51.0,2.0,'BIS-QUATRO-L3210',true,'2026-06-29','pass','Index accuracy pass post-AMC'),
    ('KIMS Hyderabad','BIS-KIM-51','BIS VISTA','suppression_ratio',
     0.0,0.0,0.0,'BIS-QUATRO-L3298',true,'2026-06-28','pass','Suppression ratio zero as expected'),
    ('KIMS Hyderabad','BIS-KIM-52','BIS Advance','burst_count',
     15.0,18.0,20.0,'BIS-QUATRO-L3298',false,'2026-06-28','conditional_pass','Burst count 18 vs 15 — algorithm drift, monitor'),
    ('Yashoda Hyderabad','BIS-YSH-61','BIS Complete','bis_index',
     45.0,44.6,0.9,'BIS-QUATRO-L3350',true,'2026-06-27','pass','Index QC nominal'),
    ('Kokilaben Mumbai','BIS-KKB-71','BISx','emg_db',
     30.0,55.0,83.3,'BIS-EXT-L2601',false,'2026-06-27','fail','EMG 55 dB — severe interference, sensor lot suspected defective, removed'),
    ('Medanta Gurgaon','BIS-MDT-81','BIS VISTA','signal_quality_index',
     100.0,96.0,4.0,'BIS-QUATRO-L3401',true,'2026-06-26','pass','SQI 96 — pass'),
    ('Narayana Bengaluru','BIS-NRY-91','A-3000','suppression_ratio',
     0.0,4.0,null,'BIS-QUATRO-L3410',false,'2026-06-26','fail','Suppression ratio 4% at zero input — calibration overdue, module drift')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, slot, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.bis_depth_anesthesia_qc_capa_actions_r3438 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BIS-FRT-12','index_accuracy_out_of_tolerance','module_calibration_drift','recalibrate_module','in_progress','iso_13485_deviation','2026-07-08',null,12000.00,'Module recalibrated; verify index accuracy next case'),
    ('BIS-MNP-21','suppression_ratio_error','software_algorithm_error','update_software','open','cdsco_notifiable','2026-07-07',null,25000.00,'Suppression ratio fault — firmware patch requested from OEM'),
    ('BIS-AIM-32','signal_quality_low','cable_impedance_high','replace_patient_cable','escalated','patient_safety_alert','2026-07-05',null,6500.00,'Cable impedance high — SQI collapse, escalated'),
    ('BIS-KKB-71','sensor_lot_defect','sensor_lot_recall','quarantine_sensor_lot','closed','cdsco_notifiable','2026-07-02','2026-06-29',38000.00,'Lot BIS-EXT-L2601 quarantined; replacement sensors validated'),
    ('BIS-FRT-11','emg_interference_high','emg_electrical_interference','reduce_emg_interference','verification_pending','internal_only','2026-07-07',null,3000.00,'Electrocautery grounding corrected — verify EMG next OT list'),
    ('BIS-NRY-91','calibration_overdue','module_calibration_drift','recalibrate_module','overdue','nabh_finding','2026-06-30',null,15000.00,'Calibration past due — vendor visit delayed'),
    ('BIS-KIM-52','burst_count_drift','software_algorithm_error','update_software','open','none','2026-07-09',null,0.00,'Burst-count algorithm drift — monitor, software update pending'),
    ('BIS-AIM-31','index_accuracy_out_of_tolerance','module_calibration_drift','recalibrate_module','verification_pending','internal_only','2026-07-06',null,9000.00,'Preemptive recal on upward drift — verify trend')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.bis_depth_anesthesia_qc_r3438 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3438_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bis_depth_anesthesia_qc_r3438)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bis_depth_anesthesia_qc_r3438 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3438_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3438_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3438_device_model_scorecard()
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
  from public.bis_depth_anesthesia_qc_r3438 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3438_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3438_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3438_parameter_verdict_matrix()
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
  from public.bis_depth_anesthesia_qc_r3438 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3438_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3438_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3438_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date as cal_month,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.bis_depth_anesthesia_qc_r3438 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3438_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3438_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3438_capa_status_board()
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
  from public.bis_depth_anesthesia_qc_capa_actions_r3438 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3438_capa_status_board() from public, anon;
grant execute on function public.founder_r3438_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3438_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bis_depth_anesthesia_qc_capa_actions_r3438)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bis_depth_anesthesia_qc_capa_actions_r3438 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3438_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3438_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3438_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
  avg_deviation_pct numeric,
  worst_deviation_pct numeric,
  failed_checks bigint
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
    round(max(l.deviation_pct), 2),
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.bis_depth_anesthesia_qc_r3438 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3438_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3438_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3438_high_risk_queue()
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
  from public.bis_depth_anesthesia_qc_r3438 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3438_high_risk_queue() from public, anon;
grant execute on function public.founder_r3438_high_risk_queue() to authenticated;
