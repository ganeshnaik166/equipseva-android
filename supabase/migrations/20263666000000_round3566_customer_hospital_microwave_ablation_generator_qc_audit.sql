-- Round 3566: Customer Hospital Microwave-Ablation Generator QC Audit
-- Microwave ablation generator QA — device model × parameter (set/delivered power, frequency, reflected power, ablation time, antenna temp) × reference vs measured × deviation × tolerance × antenna type × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: microwave_ablation_qc_r3566 — per-parameter generator QC checks
-- =============================================================================
create table if not exists public.microwave_ablation_qc_r3566 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  check_ref text not null,
  parameter text not null check (parameter in (
    'set_power_w','delivered_power_w','frequency_ghz','reflected_power_pct','ablation_time_sec','antenna_temp_c'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  within_tolerance boolean not null,
  antenna_type text not null check (antenna_type in (
    'straight','cooled_shaft','water_cooled','loop'
  )),
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.microwave_ablation_qc_r3566 enable row level security;

create index if not exists idx_microwave_ablation_qc_r3566_org on public.microwave_ablation_qc_r3566(organization_id);
create index if not exists idx_microwave_ablation_qc_r3566_cal on public.microwave_ablation_qc_r3566(calibration_date);
create index if not exists idx_microwave_ablation_qc_r3566_verdict on public.microwave_ablation_qc_r3566(qc_verdict);

-- =============================================================================
-- TABLE 2: microwave_ablation_qc_capa_actions_r3566 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.microwave_ablation_qc_capa_actions_r3566 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.microwave_ablation_qc_r3566(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'set_power_error','delivered_power_low','frequency_drift','reflected_power_high',
    'ablation_timer_drift','antenna_temp_high','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'magnetron_degraded','antenna_impedance_mismatch','cable_connector_loss','cooling_flow_restricted',
    'control_board_drift','oscillator_drift','operator_setup_error','sensor_fault',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_magnetron','replace_antenna','replace_cable_connector','service_cooling_system',
    'recalibrate_generator','replace_control_board','retrain_biomed_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text not null,
  estimated_cost_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.microwave_ablation_qc_capa_actions_r3566 enable row level security;

create index if not exists idx_microwave_ablation_capa_r3566_log on public.microwave_ablation_qc_capa_actions_r3566(qc_log_id);
create index if not exists idx_microwave_ablation_capa_r3566_status on public.microwave_ablation_qc_capa_actions_r3566(capa_status);

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
  insert into public.microwave_ablation_qc_r3566 (
    organization_id, hospital_name, device_code, device_model, check_ref, parameter,
    reference_value, measured_value, deviation_pct, tolerance_pct, within_tolerance,
    antenna_type, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.cref, q.param,
    q.refv, q.measv, q.devp, q.tolp, q.wtol,
    q.atype, q.caldt::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','MWA-APL-01','NeuWave Certus 140','MWA-APL-01-setpwr','set_power_w',
     100,100,0.0,5.0,true,'cooled_shaft','2026-06-15','pass','Set-power output matches console — within tolerance'),
    ('Apollo Chennai','MWA-APL-01','NeuWave Certus 140','MWA-APL-01-delpwr','delivered_power_w',
     100,96,-4.0,5.0,true,'cooled_shaft','2026-06-15','pass','Delivered power 96W at 100W setpoint — acceptable cable loss'),
    ('Apollo Chennai','MWA-APL-01','NeuWave Certus 140','MWA-APL-01-freq','frequency_ghz',
     2.45,2.45,0.0,2.0,true,'cooled_shaft','2026-06-15','pass','ISM-band frequency on target at 2.45 GHz'),
    ('Fortis Mohali','MWA-FRT-11','Emprint HP','MWA-FRT-11-delpwr','delivered_power_w',
     100,88,-12.0,5.0,false,'water_cooled','2026-06-12','fail','Delivered power 12% low — magnetron output degraded'),
    ('Fortis Mohali','MWA-FRT-11','Emprint HP','MWA-FRT-11-refpwr','reflected_power_pct',
     3.0,7.5,150.0,20.0,false,'water_cooled','2026-06-12','fail','Reflected power high — antenna impedance mismatch'),
    ('Fortis Mohali','MWA-FRT-11','Emprint HP','MWA-FRT-11-antmp','antenna_temp_c',
     60,68,13.3,10.0,false,'water_cooled','2026-06-12','conditional_pass','Antenna shaft temp elevated — cooling flow being checked'),
    ('Manipal Bengaluru','MWA-MNP-21','Solero MTA','MWA-MNP-21-setpwr','set_power_w',
     140,141,0.7,5.0,true,'straight','2026-06-20','pass','Set power accurate at 140W'),
    ('Manipal Bengaluru','MWA-MNP-21','Solero MTA','MWA-MNP-21-time','ablation_time_sec',
     600,604,0.7,3.0,true,'straight','2026-06-20','pass','Timer within 1% — verified with reference stopwatch'),
    ('AIIMS Delhi','MWA-AIM-31','Amica-GEN','MWA-AIM-31-freq','frequency_ghz',
     2.45,2.46,0.4,2.0,true,'straight','2026-06-18','pass','Frequency stable within band'),
    ('AIIMS Delhi','MWA-AIM-31','Amica-GEN','MWA-AIM-31-delpwr','delivered_power_w',
     100,94,-6.0,5.0,false,'straight','2026-06-18','conditional_pass','Delivered power slightly low — recheck after connector service'),
    ('CMC Vellore','MWA-CMC-41','AveCure MedWaves','MWA-CMC-41-antmp','antenna_temp_c',
     60,61,1.7,10.0,true,'loop','2026-06-22','pass','Antenna temp nominal at rated dwell'),
    ('CMC Vellore','MWA-CMC-41','AveCure MedWaves','MWA-CMC-41-refpwr','reflected_power_pct',
     3.0,3.4,13.3,20.0,true,'loop','2026-06-22','pass','Reflected power within limit'),
    ('KIMS Hyderabad','MWA-KIM-51','NeuWave Certus 140','MWA-KIM-51-setpwr','set_power_w',
     100,103,3.0,5.0,true,'cooled_shaft','2026-05-28','pass','Set power within tolerance'),
    ('KIMS Hyderabad','MWA-KIM-51','NeuWave Certus 140','MWA-KIM-51-time','ablation_time_sec',
     600,630,5.0,3.0,false,'cooled_shaft','2026-05-28','fail','Ablation timer 5% long — control board drift'),
    ('Yashoda Hyderabad','MWA-YSH-61','Emprint HP','MWA-YSH-61-freq','frequency_ghz',
     2.45,2.44,-0.4,2.0,true,'water_cooled','2026-05-30','pass','Frequency on target post-PM'),
    ('Kokilaben Mumbai','MWA-KKB-71','Solero MTA','MWA-KKB-71-delpwr','delivered_power_w',
     140,120,-14.3,5.0,false,'straight','2026-05-25','fail','Delivered power 14% low — magnetron replacement required')
  ) as q(hosp, dcode, dmodel, cref, param, refv, measv, devp, tolp, wtol, atype, caldt, qv, nt);

  -- CAPA seed — attach to specific checks via check_ref
  insert into public.microwave_ablation_qc_capa_actions_r3566 (
    organization_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, estimated_cost_rupees,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.cost,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('MWA-FRT-11-delpwr','delivered_power_low','magnetron_degraded','replace_magnetron','in_progress','patient_safety_alert','Ravi Kumar (Biomed)',185000.00,'2026-07-05',null,'Magnetron output degraded — replacement ordered from OEM'),
    ('MWA-FRT-11-refpwr','reflected_power_high','antenna_impedance_mismatch','replace_antenna','open','iso_13485_deviation','Ravi Kumar (Biomed)',42000.00,'2026-07-04',null,'High reflected power — antenna mismatch, replace applicator'),
    ('MWA-FRT-11-antmp','antenna_temp_high','cooling_flow_restricted','service_cooling_system','verification_pending','internal_only','Priya Nair (Biomed)',15000.00,'2026-07-03',null,'Cooling line flushed — verify shaft temp next case'),
    ('MWA-AIM-31-delpwr','delivered_power_low','cable_connector_loss','replace_cable_connector','closed','internal_only','Deepak Rao (Biomed)',8500.00,'2026-06-25','2026-06-24','Connector replaced — delivered power restored to spec'),
    ('MWA-KIM-51-time','ablation_timer_drift','control_board_drift','replace_control_board','escalated','cdsco_notifiable','Anita Sharma (Biomed)',96000.00,'2026-06-10',null,'Timer 5% long — control board flagged, escalated to OEM'),
    ('MWA-KKB-71-delpwr','delivered_power_low','magnetron_degraded','replace_magnetron','overdue','patient_safety_alert','Suresh Menon (Biomed)',210000.00,'2026-06-05',null,'Magnetron replacement overdue — vendor lead-time delay'),
    ('MWA-APL-01-delpwr','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','Vikram Iyer (Biomed)',0.00,'2026-07-15',null,'Routine PM scheduled — no fault, cable loss within spec'),
    ('MWA-KIM-51-setpwr','calibration_overdue','preventive_service_backlog','recalibrate_generator','closed','nabh_finding','Anita Sharma (Biomed)',12000.00,'2026-06-01','2026-05-28','Annual calibration completed and certificate filed')
  ) as q(cref, fc, rc, ca, cst, ri, own, cost, tcd, acd, nt)
  join public.microwave_ablation_qc_r3566 e
    on e.organization_id = v_org_id and e.check_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3566_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.microwave_ablation_qc_r3566)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.microwave_ablation_qc_r3566 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3566_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3566_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3566_device_model_scorecard()
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
  from public.microwave_ablation_qc_r3566 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3566_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3566_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3566_parameter_verdict_matrix()
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
  from public.microwave_ablation_qc_r3566 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3566_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3566_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3566_monthly_accuracy_trend()
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
  from public.microwave_ablation_qc_r3566 l
  where l.calibration_date is not null
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3566_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3566_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3566_capa_status_board()
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
  from public.microwave_ablation_qc_capa_actions_r3566 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3566_capa_status_board() from public, anon;
grant execute on function public.founder_r3566_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3566_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.microwave_ablation_qc_capa_actions_r3566)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.microwave_ablation_qc_capa_actions_r3566 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3566_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3566_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3566_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tolerance_count bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric,
  within_tolerance_pct numeric
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
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1)
  from public.microwave_ablation_qc_r3566 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3566_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3566_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3566_high_risk_queue()
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
  from public.microwave_ablation_qc_r3566 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3566_high_risk_queue() from public, anon;
grant execute on function public.founder_r3566_high_risk_queue() to authenticated;
