-- Round 3535: Customer Hospital Nerve-Integrity Monitor (NIM / EMG) QC Audit
-- Intra-op nerve integrity monitor QA — device model × parameter (stim current, EMG threshold,
-- event latency, electrode impedance, artifact rejection, audio alert) × reference vs measured ×
-- deviation % × tolerance × calibration date × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: nerve_integrity_qc_r3535 — per-parameter NIM / intra-op EMG QC checks
-- =============================================================================
create table if not exists public.nerve_integrity_qc_r3535 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'stim_current_ma','emg_threshold_uv','event_latency_ms',
    'electrode_impedance_kohm','artifact_rejection','audio_alert_db'
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
  created_at timestamptz not null default now()
);

alter table public.nerve_integrity_qc_r3535 enable row level security;

create index if not exists idx_nerve_integrity_qc_r3535_org on public.nerve_integrity_qc_r3535(organization_id);
create index if not exists idx_nerve_integrity_qc_r3535_caldate on public.nerve_integrity_qc_r3535(calibration_date);
create index if not exists idx_nerve_integrity_qc_r3535_verdict on public.nerve_integrity_qc_r3535(qc_verdict);

-- =============================================================================
-- TABLE 2: nerve_integrity_qc_capa_actions_r3535 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.nerve_integrity_qc_capa_actions_r3535 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.nerve_integrity_qc_r3535(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stim_current_out_of_tolerance','emg_threshold_drift','event_latency_error',
    'electrode_impedance_high','artifact_rejection_degraded','audio_alert_low',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'stimulator_probe_wear','electrode_pad_dried','cable_connector_damaged',
    'amplifier_gain_drift','software_config_error','operator_setup_error',
    'speaker_module_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_stimulator','replace_electrode_set','replace_probe','replace_cable',
    'adjust_amplifier_gain','update_software_config','retrain_ot_staff',
    'replace_speaker_module','schedule_oem_service','remove_from_service','none_required'
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

alter table public.nerve_integrity_qc_capa_actions_r3535 enable row level security;

create index if not exists idx_nerve_integrity_capa_r3535_log on public.nerve_integrity_qc_capa_actions_r3535(qc_log_id);
create index if not exists idx_nerve_integrity_capa_r3535_status on public.nerve_integrity_qc_capa_actions_r3535(capa_status);

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
  insert into public.nerve_integrity_qc_r3535 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','NIM-APL-01','Medtronic NIM Vital','stim_current_ma',
     1.00,1.02,2.0,true,'2026-07-05','pass','Stim current within +/-5% at 1.0 mA setpoint'),
    ('Apollo Chennai','NIM-APL-02','Medtronic NIM Vital','emg_threshold_uv',
     100.0,104.0,4.0,true,'2026-07-05','pass','EMG detection threshold nominal at 100 uV'),
    ('Fortis Gurgaon','NIM-FRT-11','Medtronic NIM-Response 3.0','electrode_impedance_kohm',
     5.00,9.80,96.0,false,'2026-07-04','fail','Return electrode impedance 9.8 kohm, above 5 kohm limit'),
    ('Fortis Gurgaon','NIM-FRT-12','Medtronic NIM-Response 3.0','event_latency_ms',
     5.00,5.40,8.0,true,'2026-07-04','conditional_pass','Event latency 5.4 ms, upper edge of tolerance, recheck'),
    ('Manipal Bengaluru','NIM-MNP-21','Inomed C2 NerveMonitor','stim_current_ma',
     0.50,0.58,16.0,false,'2026-07-03','fail','Stim current 16% high at 0.5 mA, stimulator drift'),
    ('Manipal Bengaluru','NIM-MNP-22','Inomed C2 NerveMonitor','artifact_rejection',
     95.0,93.5,-1.6,true,'2026-07-03','pass','Artifact rejection ratio 93.5% within spec'),
    ('AIIMS Delhi','NIM-AIM-31','Neurosign V4','audio_alert_db',
     85.0,79.0,-7.1,false,'2026-07-02','fail','Audio alert only 79 dB in OT ambient, below 85 dB requirement'),
    ('AIIMS Delhi','NIM-AIM-32','Neurosign V4','emg_threshold_uv',
     100.0,112.0,12.0,false,'2026-07-02','conditional_pass','EMG threshold drifted 12% high, amplifier gain check due'),
    ('CMC Vellore','NIM-CMC-41','Dr Langer Avalanche XT','electrode_impedance_kohm',
     5.00,4.20,-16.0,true,'2026-07-01','pass','Electrode impedance 4.2 kohm, good contact'),
    ('CMC Vellore','NIM-CMC-42','Dr Langer Avalanche XT','event_latency_ms',
     5.00,5.05,1.0,true,'2026-07-01','pass','Event latency nominal at 5.05 ms'),
    ('KIMS Hyderabad','NIM-KIM-51','Medtronic NIM Vital','stim_current_ma',
     2.00,2.04,2.0,true,'2026-06-30','pass','Stim current accurate at 2.0 mA'),
    ('KIMS Hyderabad','NIM-KIM-52','Medtronic NIM Vital','audio_alert_db',
     85.0,84.0,-1.2,true,'2026-06-30','conditional_pass','Audio alert 84 dB, borderline, speaker check advised'),
    ('Yashoda Hyderabad','NIM-YSH-61','Inomed C2 NerveMonitor','artifact_rejection',
     95.0,88.0,-7.4,false,'2026-06-29','fail','Artifact rejection degraded to 88%, cautery interference'),
    ('Kokilaben Mumbai','NIM-KKB-71','Medtronic NIM-Response 3.0','electrode_impedance_kohm',
     5.00,11.50,130.0,false,'2026-06-28','fail','Dried electrode pads, impedance 11.5 kohm, removed pending replace'),
    ('Kokilaben Mumbai','NIM-KKB-72','Medtronic NIM-Response 3.0','emg_threshold_uv',
     100.0,98.0,-2.0,true,'2026-06-28','pass','EMG threshold within tolerance'),
    ('Narayana Bengaluru','NIM-NRY-81','Neurosign V4','event_latency_ms',
     5.00,6.20,24.0,false,'2026-06-27','fail','Event latency 6.2 ms, 24% high, software timing config error')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.nerve_integrity_qc_capa_actions_r3535 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NIM-FRT-11','electrode_impedance_high','electrode_pad_dried','replace_electrode_set','in_progress','internal_only','2026-07-08',null,4200.00,'Electrode set replaced; verify impedance next case'),
    ('NIM-MNP-21','stim_current_out_of_tolerance','stimulator_probe_wear','recalibrate_stimulator','open','iso_13485_deviation','2026-07-07',null,18000.00,'Stimulator drift 16% at 0.5 mA, recalibration and probe check'),
    ('NIM-AIM-31','audio_alert_low','speaker_module_fault','replace_speaker_module','escalated','patient_safety_alert','2026-07-06',null,9500.00,'OT audio alert below 85 dB, patient-safety escalation'),
    ('NIM-AIM-32','emg_threshold_drift','amplifier_gain_drift','adjust_amplifier_gain','verification_pending','internal_only','2026-07-07',null,6000.00,'Amplifier gain adjusted, verify EMG threshold'),
    ('NIM-YSH-61','artifact_rejection_degraded','cable_connector_damaged','replace_cable','open','nabh_finding','2026-07-05',null,7800.00,'Cautery interference from damaged shield, cable replacement'),
    ('NIM-KKB-71','electrode_impedance_high','electrode_pad_dried','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-30',15500.00,'Removed from service; new electrode kit fitted and validated'),
    ('NIM-NRY-81','event_latency_error','software_config_error','update_software_config','overdue','iso_13485_deviation','2026-06-30',null,0.00,'Timing config patch past target date, vendor delay'),
    ('NIM-KIM-52','audio_alert_low','speaker_module_fault','schedule_oem_service','open','internal_only','2026-07-04',null,3200.00,'Borderline audio 84 dB, OEM service scheduled for speaker check')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.nerve_integrity_qc_r3535 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3535_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nerve_integrity_qc_r3535)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nerve_integrity_qc_r3535 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3535_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3535_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3535_device_model_scorecard()
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
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.nerve_integrity_qc_r3535 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3535_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3535_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3535_parameter_verdict_matrix()
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.nerve_integrity_qc_r3535 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3535_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3535_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3535_monthly_calibration_trend()
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
  from public.nerve_integrity_qc_r3535 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3535_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3535_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3535_capa_status_board()
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
  from public.nerve_integrity_qc_capa_actions_r3535 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3535_capa_status_board() from public, anon;
grant execute on function public.founder_r3535_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3535_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nerve_integrity_qc_capa_actions_r3535)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nerve_integrity_qc_capa_actions_r3535 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3535_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3535_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (regulatory impact)
create or replace function public.founder_r3535_accuracy_impact_digest()
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
  from public.nerve_integrity_qc_capa_actions_r3535 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3535_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3535_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3535_high_risk_queue()
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
  from public.nerve_integrity_qc_r3535 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3535_high_risk_queue() from public, anon;
grant execute on function public.founder_r3535_high_risk_queue() to authenticated;
