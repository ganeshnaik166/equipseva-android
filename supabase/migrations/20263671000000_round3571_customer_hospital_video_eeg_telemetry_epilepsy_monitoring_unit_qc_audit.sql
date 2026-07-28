-- Round 3571: Customer Hospital Video-EEG Telemetry / Epilepsy-Monitoring-Unit (EMU) QC Audit
-- Video-EEG / EMU QC — EEG channel count, video sync offset, electrode impedance, sampling rate,
-- baseline noise, recording uptime × reference vs measured × deviation × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: video_eeg_emu_qc_r3571 — per-parameter video-EEG / EMU QC measurements
-- =============================================================================
create table if not exists public.video_eeg_emu_qc_r3571 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'channel_count_ok','video_sync_ms','electrode_impedance_kohm',
    'sampling_rate_hz','noise_uv','recording_uptime_pct'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.video_eeg_emu_qc_r3571 enable row level security;

create index if not exists idx_video_eeg_emu_qc_r3571_org on public.video_eeg_emu_qc_r3571(organization_id);
create index if not exists idx_video_eeg_emu_qc_r3571_date on public.video_eeg_emu_qc_r3571(calibration_date);
create index if not exists idx_video_eeg_emu_qc_r3571_verdict on public.video_eeg_emu_qc_r3571(qc_verdict);

-- =============================================================================
-- TABLE 2: video_eeg_emu_qc_capa_actions_r3571 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.video_eeg_emu_qc_capa_actions_r3571 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.video_eeg_emu_qc_r3571(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'channel_count_shortfall','video_sync_out_of_tolerance','electrode_impedance_high',
    'sampling_rate_deviation','excess_noise','recording_uptime_low',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'amplifier_drift','electrode_cap_worn','gel_dried_out','cable_connector_damaged',
    'camera_sync_board_fault','software_config_error','operator_setup_error',
    'network_packet_loss','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_amplifier','replace_electrode_cap','reapply_electrode_gel','replace_cable',
    'replace_sync_board','update_software_config','retrain_eeg_tech','resolve_network_issue',
    'schedule_oem_service','none_required'
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

alter table public.video_eeg_emu_qc_capa_actions_r3571 enable row level security;

create index if not exists idx_video_eeg_emu_capa_r3571_log on public.video_eeg_emu_qc_capa_actions_r3571(qc_log_id);
create index if not exists idx_video_eeg_emu_capa_r3571_status on public.video_eeg_emu_qc_capa_actions_r3571(capa_status);

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
  insert into public.video_eeg_emu_qc_r3571 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','EMU-APL-01','Natus Quantum','channel_count_ok',
     64,64,0,true,'2026-07-05','pass','64-channel EMU headbox — all channels present and referenced'),
    ('Apollo Chennai','EMU-APL-02','Natus Quantum','electrode_impedance_kohm',
     5,4.1,-18,true,'2026-07-05','pass','All electrode impedances below 5 kOhm threshold'),
    ('Apollo Chennai','EMU-APL-03','Nihon Kohden EEG-1200','video_sync_ms',
     0,18,18,true,'2026-07-05','pass','Video-EEG sync offset 18 ms — within 40 ms limit'),
    ('Fortis Gurgaon','EMU-FRT-11','Cadwell Arc','electrode_impedance_kohm',
     5,11.8,136,false,'2026-07-04','fail','Impedance 11.8 kOhm on T5 — electrode cap worn'),
    ('Fortis Gurgaon','EMU-FRT-12','Cadwell Arc','noise_uv',
     1.0,3.6,260,false,'2026-07-04','fail','Baseline noise 3.6 uV — shielding/grounding issue'),
    ('Fortis Gurgaon','EMU-FRT-13','Compumedics Grael','sampling_rate_hz',
     256,256,0,true,'2026-07-04','pass','Sampling rate verified at 256 Hz'),
    ('Manipal Bengaluru','EMU-MNP-21','Micromed SD LTM','video_sync_ms',
     0,62,62,false,'2026-06-22','fail','Video sync 62 ms exceeds 40 ms — camera sync board fault'),
    ('Manipal Bengaluru','EMU-MNP-22','Micromed SD LTM','recording_uptime_pct',
     100,91.5,-8.5,false,'2026-06-22','conditional_pass','Recording uptime 91.5% — intermittent network packet loss'),
    ('AIIMS Delhi','EMU-AIM-31','Nicolet One','channel_count_ok',
     32,31,-3.1,false,'2026-06-15','conditional_pass','1 dead channel (Fp2) — headbox service scheduled'),
    ('AIIMS Delhi','EMU-AIM-32','Nicolet One','sampling_rate_hz',
     512,512,0,true,'2026-06-15','pass','512 Hz LTM sampling rate verified'),
    ('AIIMS Delhi','EMU-AIM-33','Natus Quantum','noise_uv',
     1.0,0.6,-40,true,'2026-06-15','pass','Low noise floor 0.6 uV — excellent signal quality'),
    ('CMC Vellore','EMU-CMC-41','Nihon Kohden EEG-1200','electrode_impedance_kohm',
     5,6.4,28,true,'2026-05-28','conditional_pass','Impedance 6.4 kOhm slightly high — reapply gel'),
    ('CMC Vellore','EMU-CMC-42','Nihon Kohden EEG-1200','recording_uptime_pct',
     100,99.7,-0.3,true,'2026-05-28','pass','Recording uptime 99.7% over 72 h LTM'),
    ('KIMS Hyderabad','EMU-KIM-51','Cadwell Arc','video_sync_ms',
     0,22,22,true,'2026-05-20','pass','Video sync 22 ms within tolerance'),
    ('KIMS Hyderabad','EMU-KIM-52','Compumedics Grael','sampling_rate_hz',
     256,250,-2.3,false,'2026-05-20','conditional_pass','Sampling drift to 250 Hz — recalibrate amplifier'),
    ('Kokilaben Mumbai','EMU-KKB-61','Micromed SD LTM','channel_count_ok',
     64,60,-6.3,false,'2026-05-10','fail','4 dead channels — headbox failure, removed for repair')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code (each device_code unique in main)
  insert into public.video_eeg_emu_qc_capa_actions_r3571 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('EMU-FRT-11','electrode_impedance_high','electrode_cap_worn','replace_electrode_cap','in_progress','internal_only','2026-07-08',null,6500.00,'T5 impedance 11.8 kOhm — electrode cap replaced, verifying'),
    ('EMU-FRT-12','excess_noise','cable_connector_damaged','replace_cable','escalated','iso_13485_deviation','2026-07-07',null,9200.00,'Baseline noise 3.6 uV — shielded jackbox cable on order'),
    ('EMU-MNP-21','video_sync_out_of_tolerance','camera_sync_board_fault','replace_sync_board','open','patient_safety_alert','2026-06-28',null,48000.00,'Video-EEG sync 62 ms — seizure semiology correlation at risk'),
    ('EMU-MNP-22','recording_uptime_low','network_packet_loss','resolve_network_issue','verification_pending','nabh_finding','2026-06-27',null,15000.00,'Uptime 91.5% — VLAN QoS reconfigured for EMU segment'),
    ('EMU-AIM-31','channel_count_shortfall','amplifier_drift','schedule_oem_service','open','cdsco_notifiable','2026-06-22',null,52000.00,'Dead Fp2 channel — Natus headbox OEM service booked'),
    ('EMU-KIM-52','sampling_rate_deviation','amplifier_drift','recalibrate_amplifier','closed','internal_only','2026-05-22','2026-05-22',3000.00,'Sampling drift to 250 Hz — recalibrated to 256 Hz'),
    ('EMU-KKB-61','channel_count_shortfall','electrode_cap_worn','schedule_oem_service','overdue','cdsco_notifiable','2026-05-18',null,58000.00,'4 dead channels — headbox RMA delayed by vendor'),
    ('EMU-CMC-41','calibration_overdue','gel_dried_out','reapply_electrode_gel','closed','internal_only','2026-06-01','2026-05-30',800.00,'Impedance 6.4 kOhm — gel reapplied, impedance now 3.9 kOhm')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.video_eeg_emu_qc_r3571 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3571_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.video_eeg_emu_qc_r3571)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.video_eeg_emu_qc_r3571 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3571_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3571_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3571_device_model_scorecard()
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
  from public.video_eeg_emu_qc_r3571 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3571_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3571_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3571_parameter_verdict_matrix()
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
  from public.video_eeg_emu_qc_r3571 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3571_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3571_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3571_monthly_accuracy_trend()
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
  from public.video_eeg_emu_qc_r3571 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3571_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3571_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3571_capa_status_board()
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
  from public.video_eeg_emu_qc_capa_actions_r3571 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3571_capa_status_board() from public, anon;
grant execute on function public.founder_r3571_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3571_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.video_eeg_emu_qc_capa_actions_r3571)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.video_eeg_emu_qc_capa_actions_r3571 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3571_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3571_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3571_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  failed bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.video_eeg_emu_qc_r3571 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3571_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3571_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3571_high_risk_queue()
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
  from public.video_eeg_emu_qc_r3571 l
  where l.within_tolerance = false
     or l.qc_verdict in ('conditional_pass','fail')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3571_high_risk_queue() from public, anon;
grant execute on function public.founder_r3571_high_risk_queue() to authenticated;
