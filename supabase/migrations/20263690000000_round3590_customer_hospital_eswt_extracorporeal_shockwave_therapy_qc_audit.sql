-- Round 3590: Customer Hospital ESWT Extracorporeal Shockwave Therapy QC Audit
-- Hospital ESWT (orthopedic / urology, non-lithotripsy) QA — device model × parameter × energy flux density × pressure × pulse frequency × shock count × probe output × focal depth × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: eswt_qc_r3590 — per-device ESWT shockwave-therapy QC checks
-- =============================================================================
create table if not exists public.eswt_qc_r3590 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  application_area text not null check (application_area in (
    'orthopedic','urology','musculoskeletal','wound_care'
  )),
  parameter text not null check (parameter in (
    'energy_flux_density_mj_mm2','pulse_frequency_hz','pressure_bar',
    'shock_count_accuracy','probe_output_stability','focal_depth_mm'
  )),
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  within_tolerance boolean not null,
  probe_serial text,
  pulses_delivered_total int,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eswt_qc_r3590 enable row level security;

create index if not exists idx_eswt_qc_r3590_org on public.eswt_qc_r3590(organization_id);
create index if not exists idx_eswt_qc_r3590_date on public.eswt_qc_r3590(calibration_date);
create index if not exists idx_eswt_qc_r3590_verdict on public.eswt_qc_r3590(qc_verdict);

-- =============================================================================
-- TABLE 2: eswt_qc_capa_actions_r3590 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.eswt_qc_capa_actions_r3590 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.eswt_qc_r3590(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'energy_flux_out_of_tolerance','pressure_out_of_tolerance','pulse_frequency_drift',
    'shock_count_inaccuracy','probe_output_instability','focal_depth_deviation',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'probe_wear','power_supply_drift','compressor_pressure_fault','coupling_gel_interface_issue',
    'sensor_miscalibration','firmware_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','transducer_degradation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output','replace_probe','service_compressor','replace_transducer',
    'update_firmware','retrain_operator','remove_from_service','schedule_oem_service',
    'adjust_coupling_procedure','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.eswt_qc_capa_actions_r3590 enable row level security;

create index if not exists idx_eswt_qc_capa_r3590_log on public.eswt_qc_capa_actions_r3590(qc_log_id);
create index if not exists idx_eswt_qc_capa_r3590_status on public.eswt_qc_capa_actions_r3590(capa_status);

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

  -- 16 ESWT QC check rows
  insert into public.eswt_qc_r3590 (
    organization_id, hospital_name, device_code, device_model, application_area, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    probe_serial, pulses_delivered_total, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.area, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.pserial, q.pulses, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','ESWT-APL-01','Storz Duolith SD1','orthopedic','energy_flux_density_mj_mm2',
     0.20,0.20,0.0,true,'PRB-APL-1001',152000,'2026-07-05',true,'pass','EFD within tolerance — quarterly QC'),
    ('Apollo Chennai','ESWT-APL-02','EMS Swiss DolorClast','musculoskeletal','pressure_bar',
     3.50,3.55,1.4,true,'PRB-APL-1002',88000,'2026-07-05',true,'pass','Radial pressure nominal'),
    ('Fortis Gurgaon','ESWT-FRT-11','Zimmer enPuls Pro','orthopedic','pulse_frequency_hz',
     8.0,8.6,7.5,false,'PRB-FRT-2011',205000,'2026-07-04',true,'conditional_pass','Pulse frequency 7.5% high — recalibrate soon'),
    ('Fortis Gurgaon','ESWT-FRT-12','Storz Masterpuls MP200','musculoskeletal','probe_output_stability',
     100.0,88.0,-12.0,false,'PRB-FRT-2012',240000,'2026-07-04',false,'fail','Probe output unstable, 12% drop and cal overdue'),
    ('Manipal Bengaluru','ESWT-MNP-21','Dornier Aries','urology','energy_flux_density_mj_mm2',
     0.35,0.31,-11.4,false,'PRB-MNP-3021',178000,'2026-07-03',true,'fail','Uro ESWT EFD 11% low — output verification failed'),
    ('Manipal Bengaluru','ESWT-MNP-22','Chattanooga Intelect RPW','orthopedic','shock_count_accuracy',
     2000.0,1996.0,-0.2,true,'PRB-MNP-3022',61000,'2026-07-03',true,'pass','Shock count within tolerance'),
    ('AIIMS Delhi','ESWT-AIM-31','BTL-6000 SWT','orthopedic','focal_depth_mm',
     30.0,30.4,1.3,true,'PRB-AIM-4031',133000,'2026-07-02',true,'pass','Focal depth on target'),
    ('AIIMS Delhi','ESWT-AIM-32','Storz Duolith SD1','urology','pressure_bar',
     4.00,4.36,9.0,false,'PRB-AIM-4032',199000,'2026-07-02',true,'conditional_pass','Pressure 9% high — trend watch'),
    ('CMC Vellore','ESWT-CMC-41','EMS Swiss DolorClast','musculoskeletal','pulse_frequency_hz',
     10.0,9.9,-1.0,true,'PRB-CMC-5041',74000,'2026-07-01',true,'pass','Frequency within tolerance'),
    ('CMC Vellore','ESWT-CMC-42','Zimmer enPuls Pro','wound_care','probe_output_stability',
     100.0,97.0,-3.0,true,'PRB-CMC-5042',46000,'2026-07-01',true,'conditional_pass','Minor output variance under 5%'),
    ('KIMS Hyderabad','ESWT-KIM-51','Storz Masterpuls MP200','orthopedic','energy_flux_density_mj_mm2',
     0.25,0.245,-2.0,true,'PRB-KIM-6051',121000,'2026-06-30',true,'pass','EFD within 2%'),
    ('KIMS Hyderabad','ESWT-KIM-52','Chattanooga Intelect RPW','musculoskeletal','shock_count_accuracy',
     2500.0,2560.0,2.4,false,'PRB-KIM-6052',158000,'2026-06-30',false,'conditional_pass','Shock count 2.4% over and cal overdue'),
    ('Yashoda Hyderabad','ESWT-YSH-61','Dornier Aries','urology','focal_depth_mm',
     45.0,41.0,-8.9,false,'PRB-YSH-7061',212000,'2026-06-29',true,'fail','Uro focal depth 8.9% shallow — refocus service needed'),
    ('Kokilaben Mumbai','ESWT-KKB-71','BTL-6000 SWT','orthopedic','pressure_bar',
     3.50,3.10,-11.4,false,'PRB-KKB-8071',267000,'2026-06-28',false,'fail','Pressure 11% low, probe worn, cal overdue — removed pending service'),
    ('Kokilaben Mumbai','ESWT-KKB-72','Storz Duolith SD1','musculoskeletal','probe_output_stability',
     100.0,99.0,-1.0,true,'PRB-KKB-8072',55000,'2026-06-28',true,'pass','Output stable'),
    ('Medanta Gurgaon','ESWT-MDT-81','Zimmer enPuls Pro','orthopedic','energy_flux_density_mj_mm2',
     0.18,0.205,13.9,false,'PRB-MDT-9081',231000,'2026-06-27',false,'fail','EFD 13.9% high — major deviation, output calibration failed')
  ) as q(hosp, dcode, dmodel, area, param, refv, measv, devp, wtol, pserial, pulses, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.eswt_qc_capa_actions_r3590 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ESWT-FRT-11','pulse_frequency_drift','sensor_miscalibration','recalibrate_output','in_progress','iso_13485_deviation','Biomedical Engg — Fortis','2026-07-08',null,12000.00,'Frequency sensor recalibrated — verify next session'),
    ('ESWT-FRT-12','probe_output_instability','probe_wear','replace_probe','escalated','patient_safety_alert','OEM Storz Service','2026-07-07',null,68000.00,'Probe end-of-life; replacement escalated to OEM'),
    ('ESWT-MNP-21','energy_flux_out_of_tolerance','power_supply_drift','service_compressor','open','cdsco_notifiable','Biomedical Engg — Manipal','2026-07-06',null,41000.00,'Uro ESWT power module drift — CDSCO notifiable'),
    ('ESWT-AIM-32','pressure_out_of_tolerance','compressor_pressure_fault','service_compressor','verification_pending','internal_only','Facilities — AIIMS','2026-07-06',null,22000.00,'Compressor serviced — pressure verification pending'),
    ('ESWT-KIM-52','shock_count_inaccuracy','firmware_config_error','update_firmware','closed','internal_only','Biomedical Engg — KIMS','2026-07-04','2026-07-02',0.00,'Firmware updated; shock counter recalibrated and verified'),
    ('ESWT-YSH-61','focal_depth_deviation','transducer_degradation','replace_transducer','overdue','nabh_finding','OEM Dornier Service','2026-07-01',null,95000.00,'Focal transducer degraded — replacement past target, vendor delay'),
    ('ESWT-KKB-71','calibration_overdue','preventive_service_backlog','remove_from_service','escalated','nabh_finding','Biomedical Engg — Kokilaben','2026-07-02',null,54000.00,'Multiple deviations plus overdue cal — removed pending full service'),
    ('ESWT-MDT-81','energy_flux_out_of_tolerance','transducer_degradation','replace_transducer','open','cdsco_notifiable','OEM Zimmer Service','2026-07-05',null,72000.00,'EFD 13.9% high — major deviation, transducer replacement raised')
  ) as q(dcode, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.eswt_qc_r3590 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3590_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eswt_qc_r3590)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.eswt_qc_r3590 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3590_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3590_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3590_device_model_scorecard()
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
  from public.eswt_qc_r3590 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3590_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3590_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3590_parameter_verdict_matrix()
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
  from public.eswt_qc_r3590 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3590_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3590_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3590_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
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
  from public.eswt_qc_r3590 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3590_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3590_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3590_capa_status_board()
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
  from public.eswt_qc_capa_actions_r3590 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3590_capa_status_board() from public, anon;
grant execute on function public.founder_r3590_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3590_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.eswt_qc_capa_actions_r3590)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.eswt_qc_capa_actions_r3590 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3590_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3590_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (deviation severity bands)
create or replace function public.founder_r3590_accuracy_impact_digest()
returns table(severity_band text, checks bigint, out_of_tolerance bigint, failed bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with banded as (
    select l.*,
      case
        when l.within_tolerance then 'within_tolerance'
        when abs(l.deviation_pct) < 5 then 'minor_lt_5pct'
        when abs(l.deviation_pct) < 10 then 'moderate_5_10pct'
        else 'major_gte_10pct'
      end as severity_band
    from public.eswt_qc_r3590 l
  )
  select b.severity_band, count(*)::bigint,
    count(*) filter (where b.within_tolerance = false)::bigint,
    count(*) filter (where b.qc_verdict = 'fail')::bigint,
    round(avg(abs(b.deviation_pct)), 2)
  from banded b
  group by b.severity_band
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3590_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3590_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3590_high_risk_queue()
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
  from public.eswt_qc_r3590 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3590_high_risk_queue() from public, anon;
grant execute on function public.founder_r3590_high_risk_queue() to authenticated;
