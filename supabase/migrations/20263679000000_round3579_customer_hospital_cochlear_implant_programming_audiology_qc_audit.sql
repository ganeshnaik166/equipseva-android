-- Round 3579: Customer Hospital Cochlear-Implant Programming / Audiology QC Audit
-- Cochlear implant programming / audiology station QC — parameter × device model × electrode impedance × stim output × telemetry link × threshold/comfort levels × programming accuracy × deviation × tolerance × CAPA

-- =============================================================================
-- TABLE 1: cochlear_implant_qc_r3579 — per-device programming / audiology QC checks
-- =============================================================================
create table if not exists public.cochlear_implant_qc_r3579 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'electrode_impedance_kohm','stim_output_level','telemetry_link_ok',
    'threshold_level','comfort_level','programming_accuracy'
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

alter table public.cochlear_implant_qc_r3579 enable row level security;

create index if not exists idx_cochlear_implant_qc_r3579_org on public.cochlear_implant_qc_r3579(organization_id);
create index if not exists idx_cochlear_implant_qc_r3579_date on public.cochlear_implant_qc_r3579(calibration_date);
create index if not exists idx_cochlear_implant_qc_r3579_verdict on public.cochlear_implant_qc_r3579(qc_verdict);

-- =============================================================================
-- TABLE 2: cochlear_implant_qc_capa_actions_r3579 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cochlear_implant_qc_capa_actions_r3579 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cochlear_implant_qc_r3579(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'electrode_impedance_out_of_range','stim_output_out_of_tolerance','telemetry_link_failure',
    'threshold_level_drift','comfort_level_drift','programming_accuracy_deviation',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'electrode_array_degradation','processor_hardware_fault','telemetry_coil_misalignment',
    'software_map_error','audiologist_setup_error','reference_standard_drift',
    'cable_connector_damaged','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'remap_and_recalibrate','replace_processor','realign_telemetry_coil','update_software_map',
    'retrain_audiology_staff','recalibrate_reference_standard','replace_cable',
    'schedule_oem_service','remove_from_service','none_required'
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

alter table public.cochlear_implant_qc_capa_actions_r3579 enable row level security;

create index if not exists idx_cochlear_implant_capa_r3579_log on public.cochlear_implant_qc_capa_actions_r3579(qc_log_id);
create index if not exists idx_cochlear_implant_capa_r3579_status on public.cochlear_implant_qc_capa_actions_r3579(capa_status);

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
  insert into public.cochlear_implant_qc_r3579 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CIQ-APL-01','nucleus_cp1000','electrode_impedance_kohm',
     7.0,7.2,2.9,true,'2026-07-05','pass','All 22 electrodes within impedance range'),
    ('Apollo Chennai','CIQ-APL-02','ab_naida_ci_q90','stim_output_level',
     200.0,204.0,2.0,true,'2026-07-05','pass','Stimulation output within tolerance band'),
    ('Fortis Gurgaon','CIQ-FRT-11','medel_sonnet_2','electrode_impedance_kohm',
     8.0,12.5,56.3,false,'2026-07-04','fail','Electrode impedance out of range on apical channels'),
    ('Fortis Gurgaon','CIQ-FRT-12','nucleus_cp1150','telemetry_link_ok',
     10.0,6.5,-35.0,false,'2026-07-04','fail','Telemetry link margin degraded — coil misalignment suspected'),
    ('Manipal Bengaluru','CIQ-MNP-21','ab_marvel_ci','threshold_level',
     100.0,118.0,18.0,false,'2026-07-03','conditional_pass','T-levels drifted upward — remap scheduled'),
    ('Manipal Bengaluru','CIQ-MNP-22','medel_rondo_3','comfort_level',
     200.0,205.0,2.5,true,'2026-07-03','pass','C-levels within comfort tolerance'),
    ('AIIMS Delhi','CIQ-AIM-31','nucleus_cp1000','programming_accuracy',
     100.0,92.0,-8.0,false,'2026-07-02','conditional_pass','Programming accuracy below target — software map recheck'),
    ('AIIMS Delhi','CIQ-AIM-32','ab_naida_ci_q90','telemetry_link_ok',
     10.0,9.6,-4.0,true,'2026-07-02','pass','Telemetry link margin nominal'),
    ('CMC Vellore','CIQ-CMC-41','medel_sonnet_2','threshold_level',
     100.0,101.0,1.0,true,'2026-07-01','pass','T-levels stable across sessions'),
    ('CMC Vellore','CIQ-CMC-42','nucleus_cp1150','stim_output_level',
     200.0,240.0,20.0,false,'2026-07-01','fail','Stim output exceeds safe limit — processor fault'),
    ('KIMS Hyderabad','CIQ-KIM-51','ab_marvel_ci','electrode_impedance_kohm',
     7.0,7.4,5.7,true,'2026-06-30','pass','Impedance within range post service'),
    ('KIMS Hyderabad','CIQ-KIM-52','medel_rondo_3','comfort_level',
     200.0,224.0,12.0,false,'2026-06-30','conditional_pass','C-levels elevated — patient discomfort, remap due'),
    ('Yashoda Hyderabad','CIQ-YSH-61','nucleus_cp1000','programming_accuracy',
     100.0,99.0,-1.0,true,'2026-06-29','pass','Programming accuracy nominal'),
    ('Kokilaben Mumbai','CIQ-KKB-71','ab_naida_ci_q90','electrode_impedance_kohm',
     8.0,15.0,87.5,false,'2026-06-28','fail','Multiple electrodes open circuit — array degradation'),
    ('Kokilaben Mumbai','CIQ-KKB-72','medel_sonnet_2','telemetry_link_ok',
     10.0,10.2,2.0,true,'2026-06-28','pass','Telemetry link stable, calibration current'),
    ('Narayana Bengaluru','CIQ-NAR-81','nucleus_cp1150','comfort_level',
     200.0,198.0,-1.0,true,'2026-06-27','pass','C-levels within tolerance')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cochlear_implant_qc_capa_actions_r3579 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CIQ-FRT-11','electrode_impedance_out_of_range','electrode_array_degradation','remap_and_recalibrate','in_progress','iso_13485_deviation','2026-07-08',null,18000.00,'Apical electrodes disabled in map — monitoring impedance trend'),
    ('CIQ-FRT-12','telemetry_link_failure','telemetry_coil_misalignment','realign_telemetry_coil','open','nabh_finding','2026-07-07',null,6500.00,'Coil position adjusted — reverify link margin next session'),
    ('CIQ-MNP-21','threshold_level_drift','software_map_error','update_software_map','verification_pending','internal_only','2026-07-06',null,3500.00,'New map uploaded — verify T-levels at follow-up'),
    ('CIQ-AIM-31','programming_accuracy_deviation','audiologist_setup_error','retrain_audiology_staff','in_progress','internal_only','2026-07-05',null,0.00,'Audiology staff refresher on mapping protocol'),
    ('CIQ-CMC-42','stim_output_out_of_tolerance','processor_hardware_fault','replace_processor','escalated','patient_safety_alert','2026-07-04',null,145000.00,'Processor overdriving output — unit removed, replacement escalated to OEM'),
    ('CIQ-KIM-52','comfort_level_drift','reference_standard_drift','recalibrate_reference_standard','open','none','2026-07-07',null,5000.00,'Reference audiometer recalibration scheduled'),
    ('CIQ-KKB-71','electrode_impedance_out_of_range','electrode_array_degradation','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-30',210000.00,'Array failure — explant referred to surgeon, CDSCO report filed'),
    ('CIQ-KIM-51','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-29',null,12000.00,'Annual OEM service past due — vendor scheduling')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cochlear_implant_qc_r3579 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3579_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cochlear_implant_qc_r3579)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cochlear_implant_qc_r3579 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3579_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3579_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3579_device_model_scorecard()
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
  from public.cochlear_implant_qc_r3579 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3579_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3579_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3579_parameter_verdict_matrix()
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
  from public.cochlear_implant_qc_r3579 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3579_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3579_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3579_monthly_accuracy_trend()
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
  from public.cochlear_implant_qc_r3579 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3579_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3579_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3579_capa_status_board()
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
  from public.cochlear_implant_qc_capa_actions_r3579 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3579_capa_status_board() from public, anon;
grant execute on function public.founder_r3579_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3579_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cochlear_implant_qc_capa_actions_r3579)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cochlear_implant_qc_capa_actions_r3579 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3579_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3579_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3579_accuracy_impact_digest()
returns table(parameter text, checks bigint, avg_deviation_pct numeric, max_deviation_pct numeric, out_of_tolerance bigint, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.cochlear_implant_qc_r3579 l
  group by l.parameter
  order by round(max(abs(l.deviation_pct)), 2) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3579_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3579_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3579_high_risk_queue()
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
  from public.cochlear_implant_qc_r3579 l
  where l.within_tolerance = false
     or l.qc_verdict in ('conditional_pass','fail')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3579_high_risk_queue() from public, anon;
grant execute on function public.founder_r3579_high_risk_queue() to authenticated;
