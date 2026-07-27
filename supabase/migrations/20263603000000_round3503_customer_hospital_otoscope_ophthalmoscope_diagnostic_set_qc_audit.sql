-- Round 3503: Customer Hospital Otoscope / Ophthalmoscope Diagnostic-Set QC Audit
-- Diagnostic-set QA — device model × parameter (light output, color temp, optical clarity, battery voltage,
-- aperture alignment, lens focus) × reference vs measured × deviation × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: otoscope_diag_set_qc_r3503 — per-parameter otoscope/ophthalmoscope QC checks
-- =============================================================================
create table if not exists public.otoscope_diag_set_qc_r3503 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'light_output_lux','color_temp_k','optical_clarity','battery_voltage_v','aperture_alignment','lens_focus'
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

alter table public.otoscope_diag_set_qc_r3503 enable row level security;

create index if not exists idx_otoscope_diag_set_qc_r3503_org on public.otoscope_diag_set_qc_r3503(organization_id);
create index if not exists idx_otoscope_diag_set_qc_r3503_date on public.otoscope_diag_set_qc_r3503(calibration_date);
create index if not exists idx_otoscope_diag_set_qc_r3503_verdict on public.otoscope_diag_set_qc_r3503(qc_verdict);

-- =============================================================================
-- TABLE 2: otoscope_diag_set_qc_capa_actions_r3503 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.otoscope_diag_set_qc_capa_actions_r3503 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.otoscope_diag_set_qc_r3503(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'light_output_low','color_temp_drift','optical_clarity_degraded','battery_voltage_low',
    'aperture_misaligned','lens_focus_off','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'led_bulb_degraded','lamp_aging','battery_end_of_life','lens_scratched','lens_fogging',
    'aperture_wheel_worn','focus_mechanism_loose','connector_corrosion',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_led_bulb','replace_lamp','replace_battery','clean_optics','replace_lens',
    'recalibrate_light_output','realign_aperture','adjust_focus_mechanism',
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

alter table public.otoscope_diag_set_qc_capa_actions_r3503 enable row level security;

create index if not exists idx_otoscope_diag_set_capa_r3503_log on public.otoscope_diag_set_qc_capa_actions_r3503(qc_log_id);
create index if not exists idx_otoscope_diag_set_capa_r3503_status on public.otoscope_diag_set_qc_capa_actions_r3503(capa_status);

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

  -- 15 QC check rows
  insert into public.otoscope_diag_set_qc_r3503 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devpct::numeric, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','OTO-APL-01','Welch Allyn 3.5V Diagnostic Set','light_output_lux',
     1000,985,1.5,true,'2026-07-03','pass','Otoscope halogen light output within tolerance'),
    ('Apollo Chennai','OPH-APL-02','Welch Allyn 3.5V Diagnostic Set','optical_clarity',
     100,98,2.0,true,'2026-07-03','pass','Ophthalmoscope optics clear, no fogging'),
    ('Fortis Gurgaon','OTO-FRT-11','Heine Beta 200','color_temp_k',
     3000,3120,4.0,true,'2026-07-02','conditional_pass','Color temperature slightly warm — monitor at next QC'),
    ('Fortis Gurgaon','OPH-FRT-12','Heine Beta 200','battery_voltage_v',
     3.6,3.1,13.9,false,'2026-07-02','fail','Rechargeable handle voltage low, out of tolerance'),
    ('Manipal Bengaluru','OTO-MNP-21','Riester Ri-Scope L','light_output_lux',
     1000,720,28.0,false,'2026-07-01','fail','Bulb degraded, light output 28% below reference'),
    ('Manipal Bengaluru','OPH-MNP-22','Riester Ri-Scope L','lens_focus',
     100,99,1.0,true,'2026-07-01','pass','Focus wheel accurate across diopter range'),
    ('AIIMS Delhi','OTO-AIM-31','Keeler Standard','aperture_alignment',
     100,92,8.0,true,'2026-06-30','conditional_pass','Aperture wheel slightly misaligned — flagged'),
    ('AIIMS Delhi','OPH-AIM-32','Keeler Standard','optical_clarity',
     100,85,15.0,false,'2026-06-30','fail','Lens scratched, optical clarity degraded'),
    ('CMC Vellore','OTO-CMC-41','Welch Allyn MacroView','light_output_lux',
     1200,1185,1.25,true,'2026-06-29','pass','MacroView LED light output nominal'),
    ('CMC Vellore','OPH-CMC-42','Welch Allyn MacroView','color_temp_k',
     4000,3980,0.5,true,'2026-06-29','pass','Color temperature within spec'),
    ('KIMS Hyderabad','OTO-KIM-51','Heine Mini 3000','battery_voltage_v',
     2.5,2.45,2.0,true,'2026-06-28','pass','Pocket otoscope battery voltage good'),
    ('KIMS Hyderabad','OPH-KIM-52','Heine Mini 3000','lens_focus',
     100,94,6.0,true,'2026-06-28','conditional_pass','Focus mechanism loose — recheck due'),
    ('Yashoda Hyderabad','OTO-YSH-61','Riester Ri-Scope L','aperture_alignment',
     100,78,22.0,false,'2026-06-27','fail','Aperture wheel worn, alignment out of tolerance'),
    ('Kokilaben Mumbai','OPH-KKB-71','Welch Allyn 3.5V Diagnostic Set','optical_clarity',
     100,99,1.0,true,'2026-06-27','pass','Ophthalmoscope optics clean post service'),
    ('Kokilaben Mumbai','OTO-KKB-72','Heine Beta 200','light_output_lux',
     1000,830,17.0,false,'2026-06-26','fail','Halogen lamp aging, light output low')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.otoscope_diag_set_qc_capa_actions_r3503 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('OPH-FRT-12','battery_voltage_low','battery_end_of_life','replace_battery','in_progress','internal_only','2026-07-06',null,3500.00,'Rechargeable handle battery replacement ordered'),
    ('OTO-MNP-21','light_output_low','led_bulb_degraded','replace_led_bulb','closed','iso_13485_deviation','2026-07-04','2026-07-03',1200.00,'Bulb replaced, light output restored and verified'),
    ('OPH-AIM-32','optical_clarity_degraded','lens_scratched','replace_lens','escalated','patient_safety_alert','2026-07-03',null,18000.00,'Scratched objective lens — escalated to OEM for replacement'),
    ('OTO-YSH-61','aperture_misaligned','aperture_wheel_worn','realign_aperture','open','nabh_finding','2026-07-05',null,4500.00,'Aperture wheel worn — realignment and part replacement pending'),
    ('OTO-KKB-72','light_output_low','lamp_aging','replace_lamp','verification_pending','internal_only','2026-07-02',null,900.00,'Halogen lamp replaced — verify output next QC'),
    ('OTO-AIM-31','aperture_misaligned','aperture_wheel_worn','realign_aperture','closed','internal_only','2026-07-01','2026-06-30',2200.00,'Aperture realigned and verified'),
    ('OPH-KIM-52','lens_focus_off','focus_mechanism_loose','adjust_focus_mechanism','overdue','internal_only','2026-06-30',null,1500.00,'Focus mechanism adjustment past target date'),
    ('OTO-FRT-11','color_temp_drift','lamp_aging','recalibrate_light_output','open','none','2026-07-07',null,0.00,'Color temperature drift — recalibration scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.otoscope_diag_set_qc_r3503 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3503_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.otoscope_diag_set_qc_r3503)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.otoscope_diag_set_qc_r3503 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3503_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3503_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3503_device_model_scorecard()
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
  from public.otoscope_diag_set_qc_r3503 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3503_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3503_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3503_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_measured numeric, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.measured_value), 2),
    round(avg(l.deviation_pct), 2)
  from public.otoscope_diag_set_qc_r3503 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3503_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3503_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3503_monthly_calibration_trend()
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
  from public.otoscope_diag_set_qc_r3503 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3503_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3503_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3503_capa_status_board()
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
  from public.otoscope_diag_set_qc_capa_actions_r3503 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3503_capa_status_board() from public, anon;
grant execute on function public.founder_r3503_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3503_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.otoscope_diag_set_qc_capa_actions_r3503)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.otoscope_diag_set_qc_capa_actions_r3503 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3503_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3503_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3503_accuracy_impact_digest()
returns table(parameter text, checks bigint, within_tol bigint, out_of_tol bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.otoscope_diag_set_qc_r3503 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3503_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3503_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3503_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
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
    l.qc_verdict, l.deviation_pct, l.within_tolerance, l.notes
  from public.otoscope_diag_set_qc_r3503 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.deviation_pct desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3503_high_risk_queue() from public, anon;
grant execute on function public.founder_r3503_high_risk_queue() to authenticated;
