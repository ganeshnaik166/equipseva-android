-- Round 3462: Customer Hospital Electrolyte Analyzer (ISE) Point-of-Care QC Audit
-- ISE electrolyte QA — device model × parameter (Na/K/Cl/iCa/pH/slope) × QC level × reference vs measured × deviation × tolerance × calibration currency × verdict × CAPA

-- =============================================================================
-- TABLE 1: electrolyte_analyzer_qc_r3462 — per-parameter ISE QC checks
-- =============================================================================
create table if not exists public.electrolyte_analyzer_qc_r3462 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'sodium_mmol','potassium_mmol','chloride_mmol','ical_mmol','ph','ise_slope_mv'
  )),
  reference_value numeric(8,3),
  measured_value numeric(8,3),
  deviation_pct numeric(8,3),
  qc_level text not null check (qc_level in (
    'level1_low','level2_normal','level3_high'
  )),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.electrolyte_analyzer_qc_r3462 enable row level security;

create index if not exists idx_electrolyte_qc_r3462_org on public.electrolyte_analyzer_qc_r3462(organization_id);
create index if not exists idx_electrolyte_qc_r3462_cal on public.electrolyte_analyzer_qc_r3462(calibration_date);
create index if not exists idx_electrolyte_qc_r3462_verdict on public.electrolyte_analyzer_qc_r3462(qc_verdict);

-- =============================================================================
-- TABLE 2: electrolyte_analyzer_qc_capa_actions_r3462 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.electrolyte_analyzer_qc_capa_actions_r3462 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.electrolyte_analyzer_qc_r3462(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','ise_slope_drift','qc_level_failure','calibration_overdue',
    'electrode_degraded','reference_electrode_fault','sample_handling_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'ise_electrode_end_of_life','reference_electrode_depleted','calibrator_expired','sample_contamination',
    'protein_buildup_membrane','temperature_instability','operator_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_ise_electrode','replace_reference_electrode','recalibrate_analyzer','replace_calibrator_lot',
    'clean_flush_fluidics','condition_membrane','retrain_lab_staff','schedule_oem_service',
    'remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.electrolyte_analyzer_qc_capa_actions_r3462 enable row level security;

create index if not exists idx_electrolyte_capa_r3462_log on public.electrolyte_analyzer_qc_capa_actions_r3462(qc_log_id);
create index if not exists idx_electrolyte_capa_r3462_status on public.electrolyte_analyzer_qc_capa_actions_r3462(capa_status);

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

  -- 16 ISE QC check rows
  insert into public.electrolyte_analyzer_qc_r3462 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, qc_level, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devpct, q.qclvl, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','ELEC-APL-01','Roche Cobas b221','sodium_mmol',
     140.0,140.6,0.4,'level2_normal',true,'2026-07-05','pass','Na ISE L2 QC within tolerance'),
    ('Apollo Chennai','ELEC-APL-01','Roche Cobas b221','potassium_mmol',
     4.00,4.05,1.2,'level2_normal',true,'2026-07-05','pass','K ISE L2 QC nominal'),
    ('Fortis Gurgaon','ELEC-FRT-11','Radiometer ABL800','sodium_mmol',
     120.0,116.4,-3.0,'level1_low',false,'2026-07-04','conditional_pass','Na L1-low QC drift near limit — recheck due'),
    ('Fortis Gurgaon','ELEC-FRT-11','Radiometer ABL800','ise_slope_mv',
     59.0,54.2,-8.1,'level2_normal',false,'2026-07-04','fail','Na ISE slope below 55 mV — electrode aging'),
    ('Manipal Bengaluru','ELEC-MNP-21','Siemens RapidPoint 500','ph',
     7.40,7.39,-0.1,'level2_normal',true,'2026-07-03','pass','pH sensor L2 QC pass'),
    ('Manipal Bengaluru','ELEC-MNP-21','Siemens RapidPoint 500','ical_mmol',
     1.15,1.28,11.3,'level3_high',false,'2026-07-03','fail','Ionised Ca high-level QC out of tolerance'),
    ('AIIMS Delhi','ELEC-AIM-31','Nova Biomedical Stat Profile','chloride_mmol',
     100.0,101.5,1.5,'level2_normal',true,'2026-07-02','pass','Cl ISE L2 QC pass'),
    ('AIIMS Delhi','ELEC-AIM-31','Nova Biomedical Stat Profile','potassium_mmol',
     6.50,6.98,7.4,'level3_high',false,'2026-07-02','fail','K high-level QC exceeds tolerance — reference electrode suspect'),
    ('CMC Vellore','ELEC-CMC-41','Werfen GEM 5000','sodium_mmol',
     160.0,158.9,-0.7,'level3_high',true,'2026-07-01','pass','Na high-level QC pass'),
    ('CMC Vellore','ELEC-CMC-41','Werfen GEM 5000','ph',
     7.20,7.26,0.8,'level1_low',true,'2026-07-01','conditional_pass','pH low-level QC within extended limit — monitor'),
    ('KIMS Hyderabad','ELEC-KIM-51','i-STAT Alinity','ical_mmol',
     1.15,1.16,0.9,'level2_normal',true,'2026-06-30','pass','iCa POC cartridge L2 QC pass'),
    ('KIMS Hyderabad','ELEC-KIM-52','Roche Cobas b221','potassium_mmol',
     3.00,3.24,8.0,'level1_low',false,'2026-06-30','fail','K low-level QC out of tolerance — calibrator expired'),
    ('Yashoda Hyderabad','ELEC-YSH-61','Radiometer ABL800','chloride_mmol',
     80.0,82.1,2.6,'level1_low',true,'2026-06-29','conditional_pass','Cl low-level QC near upper limit — flush fluidics'),
    ('Kokilaben Mumbai','ELEC-KKB-71','Siemens RapidPoint 500','ise_slope_mv',
     59.0,60.4,2.4,'level2_normal',true,'2026-06-28','pass','Na ISE slope healthy'),
    ('Kokilaben Mumbai','ELEC-KKB-71','Siemens RapidPoint 500','sodium_mmol',
     140.0,134.8,-3.7,'level2_normal',false,'2026-06-28','fail','Na accuracy out of tolerance — protein buildup on membrane'),
    ('Narayana Bengaluru','ELEC-NAR-81','Nova Biomedical Stat Profile','ical_mmol',
     1.30,1.31,0.8,'level3_high',true,'2026-06-27','pass','iCa high-level QC pass')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, qclvl, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via (device_code, parameter)
  insert into public.electrolyte_analyzer_qc_capa_actions_r3462 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ELEC-FRT-11','ise_slope_mv','ise_slope_drift','ise_electrode_end_of_life','replace_ise_electrode','in_progress','nabl_finding','2026-07-08',null,18500.00,'Na ISE slope below spec — electrode replacement in progress'),
    ('ELEC-MNP-21','ical_mmol','accuracy_out_of_tolerance','reference_electrode_depleted','replace_reference_electrode','open','patient_safety_alert','2026-07-07',null,12000.00,'iCa high bias — reference electrode depleted'),
    ('ELEC-AIM-31','potassium_mmol','qc_level_failure','reference_electrode_depleted','recalibrate_analyzer','verification_pending','nabl_finding','2026-07-06',null,3500.00,'K high L3 QC fail — recalibrated, verifying'),
    ('ELEC-KIM-52','potassium_mmol','calibration_overdue','calibrator_expired','replace_calibrator_lot','closed','internal_only','2026-07-03','2026-07-01',2200.00,'Expired calibrator lot replaced — QC restored'),
    ('ELEC-KKB-71','sodium_mmol','accuracy_out_of_tolerance','protein_buildup_membrane','clean_flush_fluidics','escalated','nabh_finding','2026-07-05',null,6800.00,'Na accuracy drift — protein buildup on membrane, escalated'),
    ('ELEC-FRT-11','sodium_mmol','accuracy_out_of_tolerance','pending_investigation','recalibrate_analyzer','open','internal_only','2026-07-09',null,1500.00,'Na L1-low drift near limit — under investigation'),
    ('ELEC-YSH-61','chloride_mmol','sample_handling_error','operator_error','retrain_lab_staff','closed','internal_only','2026-07-02','2026-06-30',900.00,'Cl low-level QC near limit — operator retrained'),
    ('ELEC-CMC-41','ph','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','none','2026-07-01',null,15000.00,'pH module PM overdue — OEM service scheduled')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.electrolyte_analyzer_qc_r3462 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3462_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.electrolyte_analyzer_qc_r3462)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.electrolyte_analyzer_qc_r3462 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3462_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3462_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3462_device_model_scorecard()
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
  from public.electrolyte_analyzer_qc_r3462 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3462_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3462_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3462_parameter_verdict_matrix()
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
  from public.electrolyte_analyzer_qc_r3462 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3462_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3462_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3462_monthly_accuracy_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date as cal_month,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.electrolyte_analyzer_qc_r3462 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3462_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3462_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3462_capa_status_board()
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
  from public.electrolyte_analyzer_qc_capa_actions_r3462 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3462_capa_status_board() from public, anon;
grant execute on function public.founder_r3462_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3462_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.electrolyte_analyzer_qc_capa_actions_r3462)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.electrolyte_analyzer_qc_capa_actions_r3462 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3462_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3462_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3462_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  failed bigint,
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.electrolyte_analyzer_qc_r3462 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3462_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3462_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3462_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  qc_level text,
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
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.qc_level,
    l.calibration_date, l.qc_verdict, l.reference_value, l.measured_value,
    l.deviation_pct, l.within_tolerance, l.notes
  from public.electrolyte_analyzer_qc_r3462 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3462_high_risk_queue() from public, anon;
grant execute on function public.founder_r3462_high_risk_queue() to authenticated;
