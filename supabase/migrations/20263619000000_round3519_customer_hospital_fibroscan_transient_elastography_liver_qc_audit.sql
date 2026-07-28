-- Round 3519: Customer Hospital FibroScan Transient-Elastography (Liver) QC Audit
-- Hospital FibroScan transient elastography QA — liver stiffness (kPa) / CAP (dB/m) / probe frequency / IQR-median / success rate / shear-wave speed × device model × reference-vs-measured accuracy × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: fibroscan_qc_r3519 — per-device FibroScan transient-elastography QC checks
-- =============================================================================
create table if not exists public.fibroscan_qc_r3519 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'stiffness_kpa','cap_dbm','probe_frequency_mhz','iqr_med_pct','success_rate_pct','shear_wave_speed'
  )),
  reference_value numeric(10,3) not null,
  measured_value numeric(10,3) not null,
  deviation_pct numeric(6,2) not null,
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fibroscan_qc_r3519 enable row level security;

create index if not exists idx_fibroscan_qc_r3519_org on public.fibroscan_qc_r3519(organization_id);
create index if not exists idx_fibroscan_qc_r3519_caldate on public.fibroscan_qc_r3519(calibration_date);
create index if not exists idx_fibroscan_qc_r3519_verdict on public.fibroscan_qc_r3519(qc_verdict);

-- =============================================================================
-- TABLE 2: fibroscan_qc_capa_actions_r3519 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.fibroscan_qc_capa_actions_r3519 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.fibroscan_qc_r3519(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stiffness_out_of_tolerance','cap_out_of_tolerance','probe_frequency_drift','iqr_median_exceeded',
    'low_success_rate','shear_wave_speed_error','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'probe_transducer_drift','probe_end_of_life','coupling_gel_issue','operator_technique_error',
    'software_config_error','phantom_degraded','ambient_temperature_variation',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_device','replace_probe','update_software_config','retrain_operator','replace_phantom',
    'oem_service_visit','adjust_measurement_protocol','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','diagnostic_accuracy_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fibroscan_qc_capa_actions_r3519 enable row level security;

create index if not exists idx_fibroscan_capa_r3519_log on public.fibroscan_qc_capa_actions_r3519(qc_log_id);
create index if not exists idx_fibroscan_capa_r3519_status on public.fibroscan_qc_capa_actions_r3519(capa_status);

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
  insert into public.fibroscan_qc_r3519 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','FS-APL-01','FibroScan 630 Expert','stiffness_kpa',
     7.000,7.150,2.10,true,'2026-07-05','pass','M-probe stiffness phantom within 3% tolerance'),
    ('Apollo Chennai','FS-APL-02','FibroScan 630 Expert','cap_dbm',
     250.000,256.000,2.40,true,'2026-07-05','pass','CAP phantom check nominal, steatosis grading unaffected'),
    ('Fortis Gurgaon','FS-FRT-11','FibroScan 530 Compact','stiffness_kpa',
     7.000,7.950,13.57,false,'2026-06-30','fail','Stiffness over-reads, out of 5% tolerance — recalibrate'),
    ('Fortis Gurgaon','FS-FRT-12','FibroScan 530 Compact','iqr_med_pct',
     30.000,34.500,15.00,false,'2026-06-30','fail','IQR/median exceeds 30% acceptance limit'),
    ('Manipal Bengaluru','FS-MNP-21','FibroScan Touch 502','probe_frequency_mhz',
     3.500,3.520,0.57,true,'2026-07-02','pass','M-probe centre frequency within spec'),
    ('Manipal Bengaluru','FS-MNP-22','FibroScan Touch 502','success_rate_pct',
     90.000,78.000,13.33,false,'2026-07-02','conditional_pass','Success rate dropped below 80% — operator retraining flagged'),
    ('AIIMS Delhi','FS-AIM-31','FibroScan 630 Expert','cap_dbm',
     250.000,268.000,7.20,false,'2026-06-29','fail','CAP over-reads beyond 5% — probe drift suspected'),
    ('AIIMS Delhi','FS-AIM-32','FibroScan 630 Expert','shear_wave_speed',
     1.520,1.550,1.97,true,'2026-06-29','pass','Shear-wave speed phantom within tolerance'),
    ('CMC Vellore','FS-CMC-41','FibroScan 430 Mini','stiffness_kpa',
     7.000,7.250,3.57,true,'2026-06-28','conditional_pass','Slight upward stiffness bias trend flagged for watch'),
    ('CMC Vellore','FS-CMC-42','FibroScan 430 Mini','iqr_med_pct',
     30.000,22.000,26.67,true,'2026-06-28','pass','IQR/median well within acceptance limit'),
    ('KIMS Hyderabad','FS-KIM-51','FibroScan 530 Compact','cap_dbm',
     250.000,254.000,1.60,true,'2026-07-01','pass','CAP phantom pass post-AMC service'),
    ('KIMS Hyderabad','FS-KIM-52','FibroScan 530 Compact','probe_frequency_mhz',
     2.500,2.630,5.20,false,'2026-07-01','fail','XL-probe centre frequency out of 5% tolerance'),
    ('Yashoda Hyderabad','FS-YSH-61','FibroScan Touch 502','success_rate_pct',
     90.000,92.000,2.22,true,'2026-06-27','pass','Success rate nominal on M-probe cohort'),
    ('Kokilaben Mumbai','FS-KKB-71','FibroScan 630 Expert','stiffness_kpa',
     7.000,8.400,20.00,false,'2026-06-27','fail','Gross stiffness over-read — removed pending OEM service'),
    ('Kokilaben Mumbai','FS-KKB-72','FibroScan 630 Expert','shear_wave_speed',
     1.520,1.610,5.92,false,'2026-06-27','conditional_pass','Shear-wave speed marginally high — recheck scheduled'),
    ('Medanta Gurgaon','FS-MDA-81','FibroScan 430 Mini','iqr_med_pct',
     30.000,28.500,5.00,true,'2026-07-03','pass','IQR/median within limit, calibration current')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.fibroscan_qc_capa_actions_r3519 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FS-FRT-11','stiffness_out_of_tolerance','probe_transducer_drift','recalibrate_device','in_progress','iso_13485_deviation','2026-07-04',null,12000.00,'Device recalibrated against phantom; verification scan pending'),
    ('FS-FRT-12','iqr_median_exceeded','operator_technique_error','retrain_operator','open','internal_only','2026-07-06',null,3000.00,'Operator retraining on probe positioning scheduled'),
    ('FS-AIM-31','cap_out_of_tolerance','probe_transducer_drift','replace_probe','escalated','diagnostic_accuracy_alert','2026-07-03',null,185000.00,'CAP over-read affects steatosis grading — probe replacement escalated'),
    ('FS-KIM-52','probe_frequency_drift','probe_end_of_life','replace_probe','verification_pending','iso_13485_deviation','2026-07-05',null,190000.00,'XL-probe past service life — replacement installed, verifying frequency'),
    ('FS-KKB-71','stiffness_out_of_tolerance','phantom_degraded','oem_service_visit','closed','cdsco_notifiable','2026-07-02','2026-06-30',240000.00,'Removed from service; OEM recalibration completed and validated'),
    ('FS-KKB-72','shear_wave_speed_error','ambient_temperature_variation','adjust_measurement_protocol','closed','internal_only','2026-07-01','2026-06-29',0.00,'Scan-room temperature controlled; recheck passed'),
    ('FS-MNP-22','low_success_rate','operator_technique_error','retrain_operator','overdue','internal_only','2026-06-30',null,3000.00,'Retraining past target date — reschedule with lead sonographer'),
    ('FS-CMC-41','calibration_overdue','preventive_service_backlog','recalibrate_device','open','nabh_finding','2026-07-05',null,12000.00,'Upward bias with calibration due — recalibration booked')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.fibroscan_qc_r3519 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3519_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fibroscan_qc_r3519)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fibroscan_qc_r3519 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3519_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3519_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3519_device_model_scorecard()
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
  from public.fibroscan_qc_r3519 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3519_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3519_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3519_parameter_verdict_matrix()
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
  from public.fibroscan_qc_r3519 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3519_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3519_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3519_monthly_qc_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date::timestamp)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.fibroscan_qc_r3519 l
  group by date_trunc('month', l.calibration_date::timestamp)
  order by date_trunc('month', l.calibration_date::timestamp) desc;
end;
$$;

revoke execute on function public.founder_r3519_monthly_qc_trend() from public, anon;
grant execute on function public.founder_r3519_monthly_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3519_capa_status_board()
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
  from public.fibroscan_qc_capa_actions_r3519 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3519_capa_status_board() from public, anon;
grant execute on function public.founder_r3519_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3519_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fibroscan_qc_capa_actions_r3519)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fibroscan_qc_capa_actions_r3519 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3519_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3519_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest
create or replace function public.founder_r3519_accuracy_impact_digest()
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
  from public.fibroscan_qc_capa_actions_r3519 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3519_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3519_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3519_high_risk_queue()
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
  from public.fibroscan_qc_r3519 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.deviation_pct desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3519_high_risk_queue() from public, anon;
grant execute on function public.founder_r3519_high_risk_queue() to authenticated;
