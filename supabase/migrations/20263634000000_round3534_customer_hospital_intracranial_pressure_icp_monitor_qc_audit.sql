-- Round 3534: Customer Hospital Intracranial-Pressure (ICP) Monitor QC Audit
-- ICP monitor QC — pressure accuracy × zero drift × transducer sensitivity × waveform fidelity ×
-- response time × temperature stability × deviation × tolerance × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: icp_monitor_qc_r3534 — per-parameter ICP monitor QC measurements
-- =============================================================================
create table if not exists public.icp_monitor_qc_r3534 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'icp_accuracy_mmhg','zero_drift_mmhg','transducer_sensitivity','waveform_fidelity',
    'response_time_ms','temperature_stability'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.icp_monitor_qc_r3534 enable row level security;

create index if not exists idx_icp_monitor_qc_r3534_org on public.icp_monitor_qc_r3534(organization_id);
create index if not exists idx_icp_monitor_qc_r3534_caldate on public.icp_monitor_qc_r3534(calibration_date);
create index if not exists idx_icp_monitor_qc_r3534_verdict on public.icp_monitor_qc_r3534(qc_verdict);

-- =============================================================================
-- TABLE 2: icp_monitor_qc_capa_actions_r3534 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.icp_monitor_qc_capa_actions_r3534 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.icp_monitor_qc_r3534(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','zero_drift_excessive','transducer_sensitivity_low',
    'waveform_distortion','response_time_slow','temperature_instability',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_aging','zero_reference_drift','cable_connector_damaged','air_bubble_in_line',
    'strain_gauge_fatigue','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','ambient_temperature_swing'
  )),
  corrective_action text not null check (corrective_action in (
    'rezero_and_recalibrate','replace_transducer','replace_cable','purge_and_flush_line',
    'replace_strain_gauge','update_software_config','retrain_neuro_staff',
    'remove_from_service','schedule_oem_service','stabilize_environment','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  accuracy_impact text not null check (accuracy_impact in (
    'measurement_unreliable','clinical_risk','none','internal_only','trend_watch','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.icp_monitor_qc_capa_actions_r3534 enable row level security;

create index if not exists idx_icp_monitor_capa_r3534_log on public.icp_monitor_qc_capa_actions_r3534(qc_log_id);
create index if not exists idx_icp_monitor_capa_r3534_status on public.icp_monitor_qc_capa_actions_r3534(capa_status);

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
  insert into public.icp_monitor_qc_r3534 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','ICP-APL-01','Integra Camino','icp_accuracy_mmhg',
     20.00,20.40,2.00,true,'2026-07-05','pass','ICP accuracy within +/-2 mmHg at 20 mmHg reference'),
    ('Apollo Chennai','ICP-APL-02','Integra Camino','zero_drift_mmhg',
     0.00,0.30,1.50,true,'2026-07-05','pass','Zero drift 0.3 mmHg over 24h — within limit'),
    ('Fortis Gurgaon','ICP-FRT-11','Codman Microsensor','icp_accuracy_mmhg',
     20.00,21.80,9.00,false,'2026-07-04','conditional_pass','Accuracy 9% high at 20 mmHg — recalibration advised'),
    ('Fortis Gurgaon','ICP-FRT-12','Codman Microsensor','zero_drift_mmhg',
     0.00,2.10,10.50,false,'2026-07-04','fail','Zero drift 2.1 mmHg exceeds 2 mmHg limit'),
    ('Manipal Bengaluru','ICP-MNP-21','Raumedic Neurovent','transducer_sensitivity',
     5.00,4.60,8.00,false,'2026-06-30','conditional_pass','Transducer sensitivity 8% below spec uV/mmHg'),
    ('Manipal Bengaluru','ICP-MNP-22','Raumedic Neurovent','waveform_fidelity',
     95.00,93.00,2.10,true,'2026-06-30','pass','Waveform fidelity score 93/100 — P2 morphology intact'),
    ('AIIMS Delhi','ICP-AIM-31','Sophysa Pressio','response_time_ms',
     120.00,128.00,6.70,true,'2026-06-28','conditional_pass','Response time 128 ms — within 150 ms limit, upward trend'),
    ('AIIMS Delhi','ICP-AIM-32','Sophysa Pressio','icp_accuracy_mmhg',
     20.00,23.40,17.00,false,'2026-06-28','fail','Accuracy 17% out of tolerance — removed for service'),
    ('CMC Vellore','ICP-CMC-41','Spiegelberg','temperature_stability',
     37.00,37.20,0.50,true,'2026-06-25','pass','Temperature stability drift 0.2 C — within limit'),
    ('CMC Vellore','ICP-CMC-42','Spiegelberg','zero_drift_mmhg',
     0.00,0.50,2.50,true,'2026-06-25','pass','Zero drift 0.5 mmHg — nominal'),
    ('KIMS Hyderabad','ICP-KIM-51','Integra Camino','icp_accuracy_mmhg',
     20.00,20.20,1.00,true,'2026-05-30','pass','Accuracy 1% — pass post AMC'),
    ('KIMS Hyderabad','ICP-KIM-52','Integra Camino','waveform_fidelity',
     95.00,88.00,7.40,false,'2026-05-30','conditional_pass','Waveform fidelity 88/100 — damping suspected'),
    ('Yashoda Hyderabad','ICP-YSH-61','Codman Microsensor','transducer_sensitivity',
     5.00,5.05,1.00,true,'2026-05-28','pass','Sensitivity within 1% of spec'),
    ('Kokilaben Mumbai','ICP-KKB-71','Raumedic Neurovent','icp_accuracy_mmhg',
     20.00,24.60,23.00,false,'2026-05-26','fail','Accuracy 23% out of tolerance — transducer replaced'),
    ('Kokilaben Mumbai','ICP-KKB-72','Sophysa Pressio','response_time_ms',
     120.00,165.00,37.50,false,'2026-05-26','fail','Response time 165 ms exceeds 150 ms limit'),
    ('Narayana Bengaluru','ICP-NRY-81','Spiegelberg','temperature_stability',
     37.00,38.40,3.80,false,'2026-07-02','conditional_pass','Temperature drift 1.4 C — ambient control issue')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.icp_monitor_qc_capa_actions_r3534 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, accuracy_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ai, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ICP-FRT-12','zero_drift_excessive','zero_reference_drift','rezero_and_recalibrate','in_progress','measurement_unreliable','Biomedical - R. Nair','2026-07-08',null,12000.00,'Zero drift 2.1 mmHg — re-zeroed, verification pending'),
    ('ICP-AIM-32','accuracy_out_of_tolerance','transducer_aging','replace_transducer','open','clinical_risk','Biomedical - S. Rao','2026-07-06',null,58000.00,'Accuracy 17% out — transducer replacement scheduled'),
    ('ICP-KKB-71','accuracy_out_of_tolerance','transducer_aging','replace_transducer','closed','patient_safety_alert','OEM - Raumedic','2026-06-02','2026-05-29',61000.00,'Transducer replaced and revalidated at 20 mmHg'),
    ('ICP-KKB-72','response_time_slow','cable_connector_damaged','replace_cable','escalated','clinical_risk','Biomedical - A. Menon','2026-06-01',null,9500.00,'Response 165 ms — cable connector suspect, escalated to OEM'),
    ('ICP-FRT-11','accuracy_out_of_tolerance','strain_gauge_fatigue','rezero_and_recalibrate','verification_pending','trend_watch','Biomedical - R. Nair','2026-07-09',null,4000.00,'Recalibrated — verify accuracy next QC'),
    ('ICP-MNP-21','transducer_sensitivity_low','transducer_aging','schedule_oem_service','open','internal_only','Biomedical - K. Iyer','2026-07-10',null,15000.00,'Sensitivity 8% low — OEM service booked'),
    ('ICP-KIM-52','waveform_distortion','air_bubble_in_line','purge_and_flush_line','closed','none','Nursing - Neuro ICU','2026-06-05','2026-06-01',0.00,'Line purged, damping resolved, waveform restored'),
    ('ICP-NRY-81','temperature_instability','ambient_temperature_swing','stabilize_environment','overdue','trend_watch','Facilities - HVAC','2026-07-12',null,22000.00,'Ambient control fix past target — HVAC vendor delay')
  ) as q(dcode, fc, rc, ca, cst, ai, own, tcd, acd, cost, nt)
  join public.icp_monitor_qc_r3534 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3534_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.icp_monitor_qc_r3534)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.icp_monitor_qc_r3534 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3534_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3534_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3534_device_model_scorecard()
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
  from public.icp_monitor_qc_r3534 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3534_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3534_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3534_parameter_verdict_matrix()
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
  from public.icp_monitor_qc_r3534 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3534_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3534_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3534_monthly_calibration_trend()
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
  from public.icp_monitor_qc_r3534 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3534_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3534_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3534_capa_status_board()
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
  from public.icp_monitor_qc_capa_actions_r3534 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3534_capa_status_board() from public, anon;
grant execute on function public.founder_r3534_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3534_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.icp_monitor_qc_capa_actions_r3534)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.icp_monitor_qc_capa_actions_r3534 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3534_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3534_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest
create or replace function public.founder_r3534_accuracy_impact_digest()
returns table(accuracy_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.accuracy_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.icp_monitor_qc_capa_actions_r3534 c
  group by c.accuracy_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3534_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3534_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3534_high_risk_queue()
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
  from public.icp_monitor_qc_r3534 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.deviation_pct desc nulls last, l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3534_high_risk_queue() from public, anon;
grant execute on function public.founder_r3534_high_risk_queue() to authenticated;
