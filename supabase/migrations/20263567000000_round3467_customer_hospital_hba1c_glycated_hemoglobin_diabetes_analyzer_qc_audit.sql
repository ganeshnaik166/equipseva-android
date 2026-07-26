-- Round 3467: Customer Hospital HbA1c / Glycated-Hemoglobin Diabetes Analyzer QC Audit
-- Hospital HbA1c / glycated-hemoglobin analyzer (HPLC/boronate) QC — diabetes monitoring, NGSP alignment.
-- device model × parameter × reference vs measured × deviation × QC level × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: hba1c_analyzer_qc_r3467 — per-device HbA1c analyzer QC checks
-- =============================================================================
create table if not exists public.hba1c_analyzer_qc_r3467 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'hba1c_pct','retention_time_min','peak_area_cv','ngsp_alignment','column_pressure_bar','carryover_pct'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(7,2),
  qc_level text not null check (qc_level in (
    'level1_normal','level2_elevated'
  )),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hba1c_analyzer_qc_r3467 enable row level security;

create index if not exists idx_hba1c_analyzer_qc_r3467_org on public.hba1c_analyzer_qc_r3467(organization_id);
create index if not exists idx_hba1c_analyzer_qc_r3467_caldate on public.hba1c_analyzer_qc_r3467(calibration_date);
create index if not exists idx_hba1c_analyzer_qc_r3467_verdict on public.hba1c_analyzer_qc_r3467(qc_verdict);

-- =============================================================================
-- TABLE 2: hba1c_analyzer_qc_capa_actions_r3467 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hba1c_analyzer_qc_capa_actions_r3467 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.hba1c_analyzer_qc_r3467(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','retention_time_drift','peak_area_cv_high','ngsp_alignment_deviation',
    'column_pressure_high','carryover_high','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'analytical_column_aging','buffer_reagent_degraded','calibrator_lot_variance','sample_carryover_contamination',
    'pump_seal_wear','temperature_control_drift','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_analytical_column','replace_buffer_reagent','recalibrate_with_new_lot','run_carryover_flush',
    'replace_pump_seal','service_temperature_module','retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cap_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hba1c_analyzer_qc_capa_actions_r3467 enable row level security;

create index if not exists idx_hba1c_analyzer_capa_r3467_log on public.hba1c_analyzer_qc_capa_actions_r3467(qc_log_id);
create index if not exists idx_hba1c_analyzer_capa_r3467_status on public.hba1c_analyzer_qc_capa_actions_r3467(capa_status);

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
  insert into public.hba1c_analyzer_qc_r3467 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, qc_level, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.qlvl, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','HBA1C-APL-01','Bio-Rad D-100','hba1c_pct',
     5.400,5.500,1.90,'level1_normal',true,'2026-07-05','pass','Level 1 normal control within NGSP tolerance'),
    ('Apollo Chennai','HBA1C-APL-02','Bio-Rad D-100','hba1c_pct',
     9.500,9.700,2.10,'level2_elevated',true,'2026-07-05','pass','Level 2 elevated control within tolerance'),
    ('Fortis Gurgaon','HBA1C-FRT-11','Tosoh G8','retention_time_min',
     1.200,1.280,6.70,'level1_normal',false,'2026-07-04','conditional_pass','HbA1c peak retention-time drift — analytical column aging'),
    ('Fortis Gurgaon','HBA1C-FRT-12','Tosoh G8','peak_area_cv',
     1.500,3.400,126.70,'level2_elevated',false,'2026-07-04','fail','Peak-area %CV above 3% — imprecision on elevated control'),
    ('Manipal Bengaluru','HBA1C-MNP-21','Arkray HA-8180V','ngsp_alignment',
     100.000,97.200,-2.80,'level1_normal',false,'2026-07-03','fail','NGSP alignment bias exceeds plus/minus 2% — recalibration required'),
    ('Manipal Bengaluru','HBA1C-MNP-22','Arkray HA-8180V','hba1c_pct',
     5.500,5.600,1.80,'level1_normal',true,'2026-07-03','pass','Normal control within NGSP tolerance'),
    ('AIIMS Delhi','HBA1C-AIM-31','Bio-Rad D-100','column_pressure_bar',
     90.000,118.000,31.10,'level1_normal',false,'2026-07-02','fail','Column back-pressure high — clogged analytical column'),
    ('AIIMS Delhi','HBA1C-AIM-32','Bio-Rad D-100','hba1c_pct',
     9.400,9.500,1.10,'level2_elevated',true,'2026-07-02','pass','Elevated control within NGSP tolerance'),
    ('CMC Vellore','HBA1C-CMC-41','Tosoh G11','carryover_pct',
     0.100,0.420,320.00,'level2_elevated',false,'2026-07-01','fail','Carryover above 0.2% after high sample — flush required'),
    ('CMC Vellore','HBA1C-CMC-42','Tosoh G11','hba1c_pct',
     5.400,5.400,0.00,'level1_normal',true,'2026-07-01','pass','Normal control exact match with target'),
    ('KIMS Hyderabad','HBA1C-KIM-51','Arkray HA-8180V','retention_time_min',
     1.200,1.220,1.70,'level1_normal',true,'2026-06-30','pass','Retention time stable within elution window'),
    ('KIMS Hyderabad','HBA1C-KIM-52','Arkray HA-8180V','peak_area_cv',
     1.500,2.100,40.00,'level2_elevated',false,'2026-06-30','conditional_pass','%CV slightly elevated — monitor next QC run'),
    ('Yashoda Hyderabad','HBA1C-YSH-61','Tosoh G8','ngsp_alignment',
     100.000,99.400,-0.60,'level1_normal',true,'2026-06-29','pass','NGSP alignment within plus/minus 2% target'),
    ('Yashoda Hyderabad','HBA1C-YSH-62','Tosoh G8','hba1c_pct',
     9.600,10.100,5.20,'level2_elevated',false,'2026-06-29','conditional_pass','Elevated control high bias — calibrator lot variance suspected'),
    ('Kokilaben Mumbai','HBA1C-KKB-71','Bio-Rad D-100','column_pressure_bar',
     90.000,92.000,2.20,'level1_normal',true,'2026-06-28','pass','Column pressure nominal after preventive maintenance'),
    ('Kokilaben Mumbai','HBA1C-KKB-72','Bio-Rad D-100','carryover_pct',
     0.100,0.110,10.00,'level1_normal',true,'2026-06-28','pass','Carryover within acceptable limit')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, qlvl, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.hba1c_analyzer_qc_capa_actions_r3467 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('HBA1C-FRT-11','retention_time_drift','analytical_column_aging','replace_analytical_column','in_progress','iso_15189_deviation','2026-07-08',null,65000.00,'Analytical column past 10k injections — replacement scheduled'),
    ('HBA1C-FRT-12','peak_area_cv_high','buffer_reagent_degraded','replace_buffer_reagent','open','nabl_finding','2026-07-09',null,12000.00,'Elution buffer lot degraded — fresh lot on order'),
    ('HBA1C-MNP-21','ngsp_alignment_deviation','calibrator_lot_variance','recalibrate_with_new_lot','verification_pending','patient_safety_alert','2026-07-07',null,8500.00,'NGSP bias over 2% — recalibrated, awaiting verification run'),
    ('HBA1C-AIM-31','column_pressure_high','analytical_column_aging','replace_analytical_column','escalated','iso_15189_deviation','2026-07-06',null,65000.00,'Column back-pressure high — escalated to OEM for replacement'),
    ('HBA1C-CMC-41','carryover_high','sample_carryover_contamination','run_carryover_flush','closed','internal_only','2026-07-04','2026-07-02',1500.00,'Carryover flush cycle run — carryover back under 0.2%'),
    ('HBA1C-KIM-52','peak_area_cv_high','temperature_control_drift','service_temperature_module','open','internal_only','2026-07-05',null,9000.00,'Column oven temperature drift — service module scheduled'),
    ('HBA1C-YSH-62','accuracy_out_of_tolerance','calibrator_lot_variance','recalibrate_with_new_lot','overdue','nabl_finding','2026-07-02',null,8500.00,'Elevated control high bias — recalibration overdue, vendor delay'),
    ('HBA1C-APL-01','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','internal_only','2026-07-12',null,22000.00,'Annual PM due for D-100 — OEM visit to be scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.hba1c_analyzer_qc_r3467 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3467_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hba1c_analyzer_qc_r3467)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hba1c_analyzer_qc_r3467 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3467_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3467_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3467_device_model_scorecard()
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
  from public.hba1c_analyzer_qc_r3467 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3467_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3467_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3467_parameter_verdict_matrix()
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
  from public.hba1c_analyzer_qc_r3467 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3467_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3467_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3467_monthly_calibration_trend()
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
  from public.hba1c_analyzer_qc_r3467 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3467_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3467_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3467_capa_status_board()
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
  from public.hba1c_analyzer_qc_capa_actions_r3467 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3467_capa_status_board() from public, anon;
grant execute on function public.founder_r3467_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3467_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hba1c_analyzer_qc_capa_actions_r3467)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hba1c_analyzer_qc_capa_actions_r3467 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3467_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3467_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3467_accuracy_impact_digest()
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
  from public.hba1c_analyzer_qc_r3467 l
  group by l.parameter
  order by round(avg(abs(l.deviation_pct)), 2) desc;
end;
$$;

revoke execute on function public.founder_r3467_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3467_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3467_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  qc_level text,
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
    l.qc_verdict, l.qc_level, l.deviation_pct, l.within_tolerance, l.notes
  from public.hba1c_analyzer_qc_r3467 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3467_high_risk_queue() from public, anon;
grant execute on function public.founder_r3467_high_risk_queue() to authenticated;
