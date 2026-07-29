-- Round 3582: Customer Hospital Gamma Knife Stereotactic Radiosurgery QC Audit
-- Gamma Knife SRS QA — parameter (source output/dose-rate/positioning/timer/coincidence/helmet uniformity)
-- x device model x reference vs measured x deviation % x within-tolerance x calibration x verdict x CAPA

-- =============================================================================
-- TABLE 1: gamma_knife_qc_r3582 — per-parameter radiosurgery accuracy QC checks
-- =============================================================================
create table if not exists public.gamma_knife_qc_r3582 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'source_output_gy_min','dose_rate_accuracy','positioning_accuracy_mm',
    'timer_accuracy','radiation_coincidence_mm','helmet_dose_uniformity'
  )),
  reference_value numeric(10,2) not null,
  measured_value numeric(10,2) not null,
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gamma_knife_qc_r3582 enable row level security;

create index if not exists idx_gamma_knife_qc_r3582_org on public.gamma_knife_qc_r3582(organization_id);
create index if not exists idx_gamma_knife_qc_r3582_cal on public.gamma_knife_qc_r3582(calibration_date);
create index if not exists idx_gamma_knife_qc_r3582_verdict on public.gamma_knife_qc_r3582(qc_verdict);

-- =============================================================================
-- TABLE 2: gamma_knife_qc_capa_actions_r3582 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.gamma_knife_qc_capa_actions_r3582 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.gamma_knife_qc_r3582(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'source_output_out_of_tolerance','dose_rate_out_of_tolerance','positioning_out_of_tolerance',
    'timer_out_of_tolerance','radiation_coincidence_out_of_tolerance','helmet_uniformity_out_of_tolerance',
    'calibration_overdue','reference_standard_expired','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'source_decay_uncorrected','sector_drive_fault','couch_positioning_drift','focus_alignment_error',
    'timer_electronics_fault','calibration_standard_expired','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output_with_tg_protocol','update_source_decay_in_tps','service_sector_drive',
    'recalibrate_patient_positioning','realign_focus','replace_reference_dosimeter','retrain_physics_staff',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_finding','nabh_finding','cdsco_notifiable','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gamma_knife_qc_capa_actions_r3582 enable row level security;

create index if not exists idx_gamma_knife_capa_r3582_log on public.gamma_knife_qc_capa_actions_r3582(qc_log_id);
create index if not exists idx_gamma_knife_capa_r3582_status on public.gamma_knife_qc_capa_actions_r3582(capa_status);

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

  -- 16 radiosurgery QC check rows
  insert into public.gamma_knife_qc_r3582 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','GK-APL-01','Leksell Gamma Knife Icon','source_output_gy_min',
     3.00,2.98,-0.67,true,'2026-07-05','pass','Co-60 source output within decay-corrected expectation — annual output QC pass'),
    ('Apollo Chennai','GK-APL-02','Leksell Gamma Knife Icon','dose_rate_accuracy',
     100.00,99.20,-0.80,true,'2026-07-05','pass','Dose-rate accuracy within +/-3% — daily QA pass'),
    ('Fortis Gurgaon','GK-FRT-11','Leksell Gamma Knife Perfexion','positioning_accuracy_mm',
     0.50,0.62,24.00,true,'2026-07-04','conditional_pass','Positioning 0.62mm — within 1mm action limit but above baseline, monitor'),
    ('Fortis Gurgaon','GK-FRT-12','Leksell Gamma Knife Perfexion','radiation_coincidence_mm',
     0.50,1.15,130.00,false,'2026-07-04','fail','Radiation/mechanical isocenter coincidence 1.15mm — exceeds 1mm tolerance, focus check needed'),
    ('Manipal Bengaluru','GK-MNP-21','Leksell Gamma Knife Icon','timer_accuracy',
     100.00,100.10,0.10,true,'2026-07-02','pass','Timer/linearity accuracy nominal — treatment time delivery verified'),
    ('Manipal Bengaluru','GK-MNP-22','Leksell Gamma Knife Icon','helmet_dose_uniformity',
     100.00,97.40,-2.60,false,'2026-07-02','conditional_pass','Sector dose uniformity 2.6% low — one sector drive suspected, verify'),
    ('AIIMS Delhi','GK-AIM-31','Leksell Gamma Knife 4C','source_output_gy_min',
     2.60,2.58,-0.77,true,'2026-06-30','pass','Ageing 4C source output within decay curve — output factor updated in TPS'),
    ('AIIMS Delhi','GK-AIM-32','Leksell Gamma Knife 4C','positioning_accuracy_mm',
     0.50,1.20,140.00,false,'2026-06-30','fail','Positioning 1.20mm exceeds 1mm limit — patient positioning system recalibration required'),
    ('CMC Vellore','GK-CMC-41','Leksell Gamma Knife Perfexion','dose_rate_accuracy',
     100.00,98.90,-1.10,true,'2026-06-29','conditional_pass','Dose rate within tolerance but annual TG-QA calibration overdue'),
    ('CMC Vellore','GK-CMC-42','Leksell Gamma Knife Perfexion','timer_accuracy',
     100.00,99.95,-0.05,true,'2026-06-29','pass','Timer accuracy nominal — QC pass'),
    ('KIMS Hyderabad','GK-KIM-51','Leksell Gamma Knife Icon','source_output_gy_min',
     3.00,2.80,-6.67,false,'2026-06-28','fail','Output 6.7% below decay-corrected expectation — source output QA fail, physics review'),
    ('KIMS Hyderabad','GK-KIM-52','Leksell Gamma Knife Icon','helmet_dose_uniformity',
     100.00,99.10,-0.90,true,'2026-06-28','pass','Sector dose uniformity within +/-2% — pass'),
    ('Yashoda Hyderabad','GK-YSH-61','Leksell Gamma Knife 4C','radiation_coincidence_mm',
     0.50,0.70,40.00,true,'2026-06-27','conditional_pass','Coincidence 0.70mm — within 1mm but above 0.5mm baseline, trend watch'),
    ('Kokilaben Mumbai','GK-KKB-71','Leksell Gamma Knife Perfexion','positioning_accuracy_mm',
     0.50,0.48,-4.00,true,'2026-06-26','pass','Positioning 0.48mm — excellent, within baseline'),
    ('Kokilaben Mumbai','GK-KKB-72','Leksell Gamma Knife Perfexion','dose_rate_accuracy',
     100.00,95.50,-4.50,false,'2026-06-26','fail','Dose rate 4.5% low — exceeds +/-3% tolerance, output recalibration required'),
    ('Rainbow Hyderabad','GK-RNB-81','Leksell Gamma Knife Icon','helmet_dose_uniformity',
     100.00,98.80,-1.20,true,'2026-06-25','pass','Sector dose uniformity nominal — SRS QC pass')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.gamma_knife_qc_capa_actions_r3582 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('GK-FRT-12','radiation_coincidence_out_of_tolerance','focus_alignment_error','realign_focus','in_progress','aerb_finding','2026-07-08',null,55000.00,'Isocenter coincidence 1.15mm — focus alignment service, AERB QA record updated'),
    ('GK-MNP-22','helmet_uniformity_out_of_tolerance','sector_drive_fault','service_sector_drive','verification_pending','patient_safety_alert','2026-07-06',null,120000.00,'Sector dose 2.6% low — sector drive serviced, verify uniformity on next QA'),
    ('GK-AIM-32','positioning_out_of_tolerance','couch_positioning_drift','recalibrate_patient_positioning','escalated','aerb_finding','2026-07-05',null,80000.00,'Positioning 1.20mm — patient positioning system recalibration escalated to OEM'),
    ('GK-KIM-51','source_output_out_of_tolerance','source_decay_uncorrected','update_source_decay_in_tps','open','patient_safety_alert','2026-07-07',null,45000.00,'Output 6.7% low — decay factor stale in TPS, physics review + reload assessment'),
    ('GK-KKB-72','dose_rate_out_of_tolerance','calibration_standard_expired','recalibrate_output_with_tg_protocol','closed','cdsco_notifiable','2026-07-03','2026-06-30',30000.00,'Dose rate 4.5% low — recalibrated per TG-178 with valid dosimeter, validated'),
    ('GK-FRT-11','positioning_out_of_tolerance','operator_setup_error','retrain_physics_staff','open','internal_only','2026-07-09',null,5000.00,'Positioning trend 0.62mm from setup variance — physics staff retraining scheduled'),
    ('GK-CMC-41','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','nabh_finding','2026-07-01',null,60000.00,'Annual TG-QA calibration overdue — OEM visit past target, vendor slot delayed'),
    ('GK-YSH-61','reference_standard_expired','calibration_standard_expired','replace_reference_dosimeter','in_progress','aerb_finding','2026-07-10',null,25000.00,'Coincidence trend watch — reference dosimeter certificate expired, replacement in transit')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.gamma_knife_qc_r3582 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3582_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gamma_knife_qc_r3582)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gamma_knife_qc_r3582 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3582_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3582_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3582_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
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
  from public.gamma_knife_qc_r3582 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3582_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3582_device_model_scorecard() to authenticated;

-- 3) Parameter x verdict matrix
create or replace function public.founder_r3582_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
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
  from public.gamma_knife_qc_r3582 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3582_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3582_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3582_monthly_calibration_trend()
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
  from public.gamma_knife_qc_r3582 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3582_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3582_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3582_capa_status_board()
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
  from public.gamma_knife_qc_capa_actions_r3582 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3582_capa_status_board() from public, anon;
grant execute on function public.founder_r3582_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3582_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gamma_knife_qc_capa_actions_r3582)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gamma_knife_qc_capa_actions_r3582 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3582_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3582_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3582_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tolerance_checks bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
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
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.gamma_knife_qc_r3582 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3582_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3582_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3582_high_risk_queue()
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
  from public.gamma_knife_qc_r3582 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3582_high_risk_queue() from public, anon;
grant execute on function public.founder_r3582_high_risk_queue() to authenticated;
