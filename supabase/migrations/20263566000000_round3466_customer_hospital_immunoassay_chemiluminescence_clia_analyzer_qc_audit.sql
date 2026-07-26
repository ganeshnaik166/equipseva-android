-- Round 3466: Customer Hospital Immunoassay Chemiluminescence (CLIA) Analyzer QC Audit
-- Hospital immunoassay chemiluminescence (CLIA) analyzer QC — thyroid/cardiac/tumor markers, RLU signal,
-- carryover, deviation, QC level, tolerance, calibration date, verdict, CAPA closure.

-- =============================================================================
-- TABLE 1: immunoassay_clia_qc_r3466 — per-parameter CLIA analyzer QC checks
-- =============================================================================
create table if not exists public.immunoassay_clia_qc_r3466 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'tsh_uiuml','troponin_ngml','psa_ngml','vit_d_ngml','rlu_signal','carryover_pct'
  )),
  reference_value numeric(14,3),
  measured_value numeric(14,3),
  deviation_pct numeric(8,2),
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

alter table public.immunoassay_clia_qc_r3466 enable row level security;

create index if not exists idx_immunoassay_clia_qc_r3466_org on public.immunoassay_clia_qc_r3466(organization_id);
create index if not exists idx_immunoassay_clia_qc_r3466_caldate on public.immunoassay_clia_qc_r3466(calibration_date);
create index if not exists idx_immunoassay_clia_qc_r3466_verdict on public.immunoassay_clia_qc_r3466(qc_verdict);

-- =============================================================================
-- TABLE 2: immunoassay_clia_qc_capa_actions_r3466 — CAPA & accuracy actions
-- =============================================================================
create table if not exists public.immunoassay_clia_qc_capa_actions_r3466 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.immunoassay_clia_qc_r3466(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','deviation_exceeds_limit','rlu_signal_drift',
    'carryover_exceeds_limit','calibration_expired','reagent_lot_shift',
    'control_out_of_range','precision_failure','temperature_excursion','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reagent_lot_variation','calibrator_degraded','optical_detector_drift',
    'probe_carryover_contamination','temperature_control_fault','operator_pipetting_error',
    'expired_reagent','software_config_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_analyzer','replace_reagent_lot','replace_calibrator','clean_probe_wash_station',
    'service_optical_module','repair_temperature_control','retrain_lab_staff','rerun_qc_controls',
    'schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  accuracy_impact text not null check (accuracy_impact in (
    'none','internal_only','iso_15189_deviation','nabl_finding','patient_result_impact','critical_value_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.immunoassay_clia_qc_capa_actions_r3466 enable row level security;

create index if not exists idx_immunoassay_clia_capa_r3466_log on public.immunoassay_clia_qc_capa_actions_r3466(qc_log_id);
create index if not exists idx_immunoassay_clia_capa_r3466_status on public.immunoassay_clia_qc_capa_actions_r3466(capa_status);

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
  insert into public.immunoassay_clia_qc_r3466 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, qc_level, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.param,
    q.refval, q.measval, q.devpct, q.qclvl, q.wtol,
    q.caldate::date, q.verdict, q.nt
  from (values
    ('Apollo Chennai','CLIA-APL-TSH01','Abbott Architect i2000','tsh_uiuml',
     2.500,2.550,2.00,'level2_normal',true,'2026-07-05','pass','TSH L2 control within tolerance'),
    ('Apollo Chennai','CLIA-APL-TRP02','Abbott Architect i2000','troponin_ngml',
     0.040,0.041,2.50,'level1_low',true,'2026-07-05','pass','Troponin low control within limit'),
    ('Apollo Chennai','CLIA-APL-PSA03','Abbott Architect i2000','psa_ngml',
     4.000,4.320,8.00,'level3_high',false,'2026-07-05','conditional_pass','PSA high control 8% deviation — recalibration advised'),
    ('Fortis Gurgaon','CLIA-FRT-TSH11','Roche Cobas e601','tsh_uiuml',
     2.500,2.900,16.00,'level2_normal',false,'2026-07-04','fail','TSH deviation 16% — reagent lot shift suspected'),
    ('Fortis Gurgaon','CLIA-FRT-VTD12','Roche Cobas e601','vit_d_ngml',
     30.000,31.200,4.00,'level2_normal',true,'2026-07-04','pass','Vitamin D control within 5% tolerance'),
    ('Fortis Gurgaon','CLIA-FRT-CAR13','Roche Cobas e601','carryover_pct',
     0.050,0.180,260.00,'level3_high',false,'2026-07-04','fail','Carryover 0.18% exceeds 0.10% limit — probe wash fault'),
    ('Manipal Bengaluru','CLIA-MNP-RLU21','Siemens Atellica IM','rlu_signal',
     150000.000,132000.000,-12.00,'level2_normal',false,'2026-07-03','fail','RLU signal 12% low — optical detector drift'),
    ('Manipal Bengaluru','CLIA-MNP-PSA22','Siemens Atellica IM','psa_ngml',
     4.000,4.080,2.00,'level3_high',true,'2026-07-03','pass','PSA high control within tolerance'),
    ('AIIMS Delhi','CLIA-AIM-TRP31','Beckman DxI 800','troponin_ngml',
     0.040,0.046,15.00,'level1_low',false,'2026-07-02','fail','Troponin low control 15% high — critical assay, escalated'),
    ('AIIMS Delhi','CLIA-AIM-TSH32','Beckman DxI 800','tsh_uiuml',
     2.500,2.575,3.00,'level2_normal',true,'2026-07-02','pass','TSH control within tolerance'),
    ('CMC Vellore','CLIA-CMC-VTD41','Ortho Vitros ECi','vit_d_ngml',
     30.000,33.000,10.00,'level3_high',false,'2026-07-01','conditional_pass','Vitamin D 10% deviation — calibrator degradation flagged'),
    ('CMC Vellore','CLIA-CMC-RLU42','Ortho Vitros ECi','rlu_signal',
     150000.000,147000.000,-2.00,'level2_normal',true,'2026-07-01','pass','RLU signal within tolerance'),
    ('KIMS Hyderabad','CLIA-KIM-TSH51','Abbott Architect i2000','tsh_uiuml',
     2.500,2.520,0.80,'level2_normal',true,'2026-06-30','pass','TSH QC pass post-calibration'),
    ('KIMS Hyderabad','CLIA-KIM-CAR52','Abbott Architect i2000','carryover_pct',
     0.050,0.090,80.00,'level3_high',false,'2026-06-30','conditional_pass','Carryover 0.09% near limit — wash station cleaned'),
    ('Yashoda Hyderabad','CLIA-YSH-PSA61','Roche Cobas e601','psa_ngml',
     4.000,3.960,-1.00,'level2_normal',true,'2026-06-29','pass','PSA normal control within tolerance'),
    ('Kokilaben Mumbai','CLIA-KKB-TRP71','Siemens Atellica IM','troponin_ngml',
     0.040,0.052,30.00,'level1_low',false,'2026-06-29','fail','Troponin 30% high with expired reagent — removed from QC release')
  ) as q(hosp, dcode, model, param, refval, measval, devpct, qclvl, wtol, caldate, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.immunoassay_clia_qc_capa_actions_r3466 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, accuracy_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ai, q.tcd::date, q.acd::date,
    q.cost, q.own, q.nt
  from (values
    ('CLIA-APL-PSA03','accuracy_out_of_tolerance','calibrator_degraded','recalibrate_analyzer','in_progress','internal_only','2026-07-09',null,6000.00,'Dr Meena Rao','PSA high control recalibration underway'),
    ('CLIA-FRT-TSH11','reagent_lot_shift','reagent_lot_variation','replace_reagent_lot','open','iso_15189_deviation','2026-07-08',null,18000.00,'Lab Mgr Suresh','TSH reagent lot flagged — replacement lot ordered'),
    ('CLIA-FRT-CAR13','carryover_exceeds_limit','probe_carryover_contamination','clean_probe_wash_station','verification_pending','patient_result_impact','2026-07-07',null,3500.00,'BMET Anil','Probe wash station serviced — verify carryover next run'),
    ('CLIA-MNP-RLU21','rlu_signal_drift','optical_detector_drift','service_optical_module','escalated','iso_15189_deviation','2026-07-06',null,42000.00,'Service Vendor','Optical module drift escalated to OEM'),
    ('CLIA-AIM-TRP31','control_out_of_range','calibrator_degraded','replace_calibrator','escalated','critical_value_risk','2026-07-05',null,9500.00,'Dr Kavita','Troponin critical assay — calibrator replaced, monitoring'),
    ('CLIA-CMC-VTD41','deviation_exceeds_limit','calibrator_degraded','replace_calibrator','closed','internal_only','2026-07-04','2026-07-02',8000.00,'Lab Mgr Rekha','Vitamin D calibrator replaced and verified'),
    ('CLIA-KIM-CAR52','carryover_exceeds_limit','probe_carryover_contamination','clean_probe_wash_station','closed','internal_only','2026-07-03','2026-06-30',2500.00,'BMET Ravi','Wash station cleaned — carryover back within limit'),
    ('CLIA-KKB-TRP71','control_out_of_range','expired_reagent','replace_reagent_lot','overdue','patient_result_impact','2026-07-02',null,14000.00,'Lab Mgr Deepa','Expired troponin reagent — replacement past target date')
  ) as q(dcode, fc, rc, ca, cst, ai, tcd, acd, cost, own, nt)
  join public.immunoassay_clia_qc_r3466 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3466_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.immunoassay_clia_qc_r3466)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.immunoassay_clia_qc_r3466 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3466_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3466_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3466_device_model_scorecard()
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
  from public.immunoassay_clia_qc_r3466 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3466_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3466_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3466_parameter_verdict_matrix()
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
  from public.immunoassay_clia_qc_r3466 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3466_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3466_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3466_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.calibration_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.immunoassay_clia_qc_r3466 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3466_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3466_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3466_capa_status_board()
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
  from public.immunoassay_clia_qc_capa_actions_r3466 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3466_capa_status_board() from public, anon;
grant execute on function public.founder_r3466_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3466_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.immunoassay_clia_qc_capa_actions_r3466)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.immunoassay_clia_qc_capa_actions_r3466 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3466_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3466_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest
create or replace function public.founder_r3466_accuracy_impact_digest()
returns table(accuracy_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.accuracy_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.immunoassay_clia_qc_capa_actions_r3466 c
  group by c.accuracy_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3466_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3466_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3466_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  qc_level text,
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
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.qc_level,
    l.calibration_date, l.qc_verdict, l.deviation_pct, l.within_tolerance, l.notes
  from public.immunoassay_clia_qc_r3466 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3466_high_risk_queue() from public, anon;
grant execute on function public.founder_r3466_high_risk_queue() to authenticated;
