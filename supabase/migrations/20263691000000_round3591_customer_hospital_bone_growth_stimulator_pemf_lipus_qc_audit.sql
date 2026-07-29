-- Round 3591: Customer Hospital Bone-Growth Stimulator (PEMF / LIPUS) QC Audit
-- Hospital bone-growth stimulator QA — PEMF magnetic field + LIPUS ultrasound — device model ×
-- parameter (field strength gauss, output current mA, LIPUS intensity mW/cm2, frequency kHz,
-- treatment-timer accuracy, waveform integrity) × reference vs measured × deviation × tolerance ×
-- calibration date × QC verdict × CAPA closure.

-- =============================================================================
-- TABLE 1: bone_growth_qc_r3591 — per-device PEMF/LIPUS parameter QC checks
-- =============================================================================
create table if not exists public.bone_growth_qc_r3591 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'pemf_field_strength_gauss','output_current_ma','lipus_intensity_mw_cm2',
    'frequency_khz','treatment_timer_accuracy','waveform_integrity'
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

alter table public.bone_growth_qc_r3591 enable row level security;

create index if not exists idx_bone_growth_qc_r3591_org on public.bone_growth_qc_r3591(organization_id);
create index if not exists idx_bone_growth_qc_r3591_date on public.bone_growth_qc_r3591(calibration_date);
create index if not exists idx_bone_growth_qc_r3591_verdict on public.bone_growth_qc_r3591(qc_verdict);

-- =============================================================================
-- TABLE 2: bone_growth_qc_capa_actions_r3591 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.bone_growth_qc_capa_actions_r3591 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.bone_growth_qc_r3591(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'field_strength_out_of_tolerance','output_current_deviation','lipus_intensity_low',
    'frequency_drift','treatment_timer_inaccurate','waveform_distortion',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'coil_degradation','transducer_wear','power_supply_drift','oscillator_aging',
    'timer_circuit_fault','firmware_calibration_error','connector_corrosion',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output','replace_coil','replace_transducer','replace_power_supply',
    'update_firmware','repair_timer_circuit','clean_replace_connector','retrain_operator',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.bone_growth_qc_capa_actions_r3591 enable row level security;

create index if not exists idx_bone_growth_capa_r3591_log on public.bone_growth_qc_capa_actions_r3591(qc_log_id);
create index if not exists idx_bone_growth_capa_r3591_status on public.bone_growth_qc_capa_actions_r3591(capa_status);

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
  insert into public.bone_growth_qc_r3591 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol,
    q.caldt::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','PEMF-APL-01','Orthofix PhysioStim','pemf_field_strength_gauss',
     20.000,19.6,-2.00,true,'2026-07-05','pass','PEMF field strength within +/-5% tolerance'),
    ('Apollo Chennai','LIP-APL-02','Bioventus Exogen','lipus_intensity_mw_cm2',
     30.000,30.2,0.67,true,'2026-07-05','pass','LIPUS SATA intensity nominal at 30 mW/cm2'),
    ('Fortis Gurgaon','PEMF-FRT-11','DJO OrthoPak','output_current_ma',
     25.000,23.1,-7.60,false,'2026-07-04','conditional_pass','Output current 7.6% low — coil aging suspected, recheck scheduled'),
    ('Fortis Gurgaon','LIP-FRT-12','Bioventus Exogen','frequency_khz',
     1500.000,1500.5,0.03,true,'2026-07-04','pass','LIPUS transducer frequency stable at 1.5 MHz'),
    ('Manipal Bengaluru','PEMF-MNP-21','Biomet EBI','pemf_field_strength_gauss',
     20.000,15.8,-21.00,false,'2026-06-20','fail','Field strength 21% below spec — coil degradation, removed pending repair'),
    ('Manipal Bengaluru','LIP-MNP-22','Bioventus Exogen','lipus_intensity_mw_cm2',
     30.000,26.4,-12.00,false,'2026-06-20','fail','LIPUS intensity 12% low — transducer wear'),
    ('AIIMS Delhi','PEMF-AIM-31','Orthofix PhysioStim','treatment_timer_accuracy',
     20.000,20.3,1.50,true,'2026-06-15','pass','Treatment timer within 1.5% over 20-min cycle'),
    ('AIIMS Delhi','PEMF-AIM-32','DJO OrthoPak','waveform_integrity',
     100.000,91.0,-9.00,false,'2026-06-15','conditional_pass','Waveform fidelity 91% — minor distortion on scope, monitor'),
    ('CMC Vellore','LIP-CMC-41','Bioventus Exogen','lipus_intensity_mw_cm2',
     30.000,29.7,-1.00,true,'2026-05-18','pass','LIPUS intensity nominal within band'),
    ('CMC Vellore','PEMF-CMC-42','Biomet EBI','frequency_khz',
     0.075,0.076,1.33,true,'2026-05-18','pass','PEMF pulse frequency ~75 Hz within tolerance'),
    ('KIMS Hyderabad','PEMF-KIM-51','Orthofix PhysioStim','output_current_ma',
     25.000,24.6,-1.60,true,'2026-05-10','pass','Output current within tolerance'),
    ('KIMS Hyderabad','PEMF-KIM-52','DJO OrthoPak','pemf_field_strength_gauss',
     20.000,18.9,-5.50,false,'2026-05-10','conditional_pass','Field strength 5.5% low — just over band, recalibrate'),
    ('Yashoda Hyderabad','LIP-YSH-61','Bioventus Exogen','treatment_timer_accuracy',
     20.000,22.1,10.50,false,'2026-04-22','fail','Timer runs 10.5% long — timer circuit fault, removed'),
    ('Yashoda Hyderabad','PEMF-YSH-62','Biomet EBI','waveform_integrity',
     100.000,99.0,-1.00,true,'2026-04-22','pass','Waveform integrity nominal'),
    ('Kokilaben Mumbai','PEMF-KKB-71','Orthofix PhysioStim','pemf_field_strength_gauss',
     20.000,12.0,-40.00,false,'2026-04-14','fail','Field strength 40% below spec — power supply drift, removed from service'),
    ('Kokilaben Mumbai','LIP-KKB-72','Bioventus Exogen','frequency_khz',
     1500.000,1487.0,-0.87,true,'2026-04-14','pass','LIPUS frequency within +/-1% of 1.5 MHz')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldt, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.bone_growth_qc_capa_actions_r3591 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PEMF-FRT-11','output_current_deviation','coil_degradation','recalibrate_output','in_progress','iso_13485_deviation','2026-07-08',null,12000.00,'Output current recalibrated; verification pending'),
    ('PEMF-MNP-21','field_strength_out_of_tolerance','coil_degradation','replace_coil','open','nabh_finding','2026-07-06',null,85000.00,'Coil degraded 21% below spec — replacement coil ordered'),
    ('LIP-MNP-22','lipus_intensity_low','transducer_wear','replace_transducer','escalated','patient_safety_alert','2026-07-05',null,62000.00,'LIPUS transducer worn — escalated to Bioventus'),
    ('PEMF-AIM-32','waveform_distortion','oscillator_aging','schedule_oem_service','verification_pending','internal_only','2026-07-07',null,18000.00,'Waveform distortion — OEM scope service scheduled'),
    ('PEMF-KIM-52','field_strength_out_of_tolerance','power_supply_drift','recalibrate_output','closed','internal_only','2026-07-02','2026-06-30',5000.00,'Field strength recalibrated and re-verified within band'),
    ('LIP-YSH-61','treatment_timer_inaccurate','timer_circuit_fault','repair_timer_circuit','open','cdsco_notifiable','2026-07-04',null,27000.00,'Timer 10.5% long — timer board repair'),
    ('PEMF-KKB-71','field_strength_out_of_tolerance','power_supply_drift','replace_power_supply','escalated','patient_safety_alert','2026-07-03',null,96000.00,'40% field loss — power supply replacement, unit removed'),
    ('LIP-CMC-41','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,9000.00,'Annual LIPUS calibration overdue — vendor scheduling delay')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.bone_growth_qc_r3591 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3591_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bone_growth_qc_r3591)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bone_growth_qc_r3591 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3591_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3591_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3591_device_model_scorecard()
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
  from public.bone_growth_qc_r3591 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3591_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3591_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3591_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.bone_growth_qc_r3591 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3591_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3591_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3591_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.calibration_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.bone_growth_qc_r3591 l
  group by to_char(l.calibration_date, 'YYYY-MM')
  order by to_char(l.calibration_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3591_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3591_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3591_capa_status_board()
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
  from public.bone_growth_qc_capa_actions_r3591 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3591_capa_status_board() from public, anon;
grant execute on function public.founder_r3591_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3591_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bone_growth_qc_capa_actions_r3591)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bone_growth_qc_capa_actions_r3591 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3591_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3591_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (regulatory impact × linked deviation)
create or replace function public.founder_r3591_accuracy_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, avg_deviation_pct numeric, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.bone_growth_qc_capa_actions_r3591 c
  join public.bone_growth_qc_r3591 l on l.id = c.qc_log_id
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3591_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3591_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3591_high_risk_queue()
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
  within_tolerance text,
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct,
    case when l.within_tolerance then 'within' else 'out_of_tolerance' end, l.notes
  from public.bone_growth_qc_r3591 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3591_high_risk_queue() from public, anon;
grant execute on function public.founder_r3591_high_risk_queue() to authenticated;
