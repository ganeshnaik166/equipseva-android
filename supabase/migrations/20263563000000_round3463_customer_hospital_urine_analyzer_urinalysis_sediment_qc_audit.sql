-- Round 3463: Customer Hospital Urine Analyzer / Urinalysis (Sediment) QC Audit
-- Automated urine analyzer QA — strip chemistry + sediment microscopy: device model × parameter × unit ×
-- reference vs measured × deviation × flow-cell condition × calibration currency × QC verdict × CAPA

-- =============================================================================
-- TABLE 1: urine_analyzer_qc_r3463 — per-parameter urinalysis QC checks
-- =============================================================================
create table if not exists public.urine_analyzer_qc_r3463 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'strip_color_accuracy','ph','specific_gravity','protein','glucose','sediment_particle_count'
  )),
  unit text not null check (unit in (
    'central_lab','emergency_lab','nephrology_lab','opd_lab'
  )),
  check_date date not null,
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  flow_cell_ok boolean not null,
  strip_lot text,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.urine_analyzer_qc_r3463 enable row level security;

create index if not exists idx_urine_analyzer_qc_r3463_org on public.urine_analyzer_qc_r3463(organization_id);
create index if not exists idx_urine_analyzer_qc_r3463_date on public.urine_analyzer_qc_r3463(check_date);
create index if not exists idx_urine_analyzer_qc_r3463_verdict on public.urine_analyzer_qc_r3463(qc_verdict);

-- =============================================================================
-- TABLE 2: urine_analyzer_qc_capa_actions_r3463 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.urine_analyzer_qc_capa_actions_r3463 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.urine_analyzer_qc_r3463(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'strip_color_miscalibration','ph_out_of_tolerance','specific_gravity_drift','protein_false_result',
    'glucose_accuracy_deviation','sediment_count_discrepancy','flow_cell_contamination',
    'calibration_overdue','reagent_lot_issue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reagent_strip_expired','flow_cell_dirty','optics_lamp_degraded','calibrator_lot_variance',
    'pipette_clog','software_threshold_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','sample_carryover'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_reagent_strips','clean_flow_cell','replace_optics_lamp','recalibrate_analyzer',
    'clear_pipette_clog','update_software_threshold','retrain_lab_staff',
    'remove_from_service','schedule_oem_service','run_carryover_wash','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cap_finding','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.urine_analyzer_qc_capa_actions_r3463 enable row level security;

create index if not exists idx_urine_analyzer_capa_r3463_log on public.urine_analyzer_qc_capa_actions_r3463(qc_log_id);
create index if not exists idx_urine_analyzer_capa_r3463_status on public.urine_analyzer_qc_capa_actions_r3463(capa_status);

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
  insert into public.urine_analyzer_qc_r3463 (
    organization_id, hospital_name, device_code, device_model, parameter, unit, check_date,
    reference_value, measured_value, deviation_pct, flow_cell_ok, strip_lot, calibration_date,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.model, q.param, q.unit, q.cdate::date,
    q.refv, q.measv, q.devp, q.flow, q.lot, q.caldate::date,
    q.qv, q.nt
  from (values
    ('Apollo Chennai','UA-APL-01','Sysmex UF-5000','sediment_particle_count','central_lab','2026-07-05',
     250,248,0.80,true,'STRIP-A231','2026-06-15','pass','Sediment particle count within QC range'),
    ('Apollo Chennai','UA-APL-02','Roche Cobas u 411','strip_color_accuracy','emergency_lab','2026-07-05',
     100,98,2.00,true,'STRIP-B118','2026-06-15','pass','Strip color pads read within tolerance'),
    ('Fortis Gurgaon','UA-FRT-11','Arkray Aution Max AX-4030','ph','nephrology_lab','2026-07-04',
     6.00,6.30,5.00,true,'STRIP-C044','2026-06-10','conditional_pass','pH 5% high vs control — recheck next run'),
    ('Fortis Gurgaon','UA-FRT-12','Beckman Iris iChem VELOCITY','glucose','central_lab','2026-07-04',
     100,128,28.00,true,'STRIP-C045','2026-06-10','fail','Glucose control 28% high — reagent strip lot suspected'),
    ('Manipal Bengaluru','UA-MNP-21','Sysmex UF-1500','sediment_particle_count','central_lab','2026-07-03',
     300,372,24.00,false,'STRIP-D210','2026-05-28','fail','Flow cell contaminated, sediment count 24% high'),
    ('Manipal Bengaluru','UA-MNP-22','Roche Cobas u 601','specific_gravity','nephrology_lab','2026-07-03',
     1.015,1.016,0.10,true,'STRIP-D211','2026-06-20','pass','Specific gravity control within tolerance'),
    ('AIIMS Delhi','UA-AIM-31','Sysmex UF-5000','protein','central_lab','2026-07-02',
     30,33,10.00,true,'STRIP-E077','2026-06-18','conditional_pass','Protein 10% high — trend flagged for review'),
    ('AIIMS Delhi','UA-AIM-32','Mindray EH-2090','glucose','emergency_lab','2026-07-02',
     100,101,1.00,true,'STRIP-E078','2026-06-18','pass','Glucose control within limit'),
    ('CMC Vellore','UA-CMC-41','Arkray Aution Max AX-4030','strip_color_accuracy','opd_lab','2026-07-01',
     100,89,11.00,true,'STRIP-F133','2026-06-05','fail','Strip color accuracy 11% off — optics lamp degraded'),
    ('CMC Vellore','UA-CMC-42','Roche Cobas u 411','ph','central_lab','2026-07-01',
     6.00,6.05,0.83,true,'STRIP-F134','2026-06-05','pass','pH control within tolerance'),
    ('KIMS Hyderabad','UA-KIM-51','Sysmex UF-1500','specific_gravity','nephrology_lab','2026-06-30',
     1.020,1.025,0.49,false,'STRIP-G090','2026-05-15','conditional_pass','SG slightly high and flow cell flagged, calibration overdue'),
    ('KIMS Hyderabad','UA-KIM-52','Mindray EH-2090','sediment_particle_count','central_lab','2026-06-30',
     280,279,0.36,true,'STRIP-G091','2026-06-22','pass','Sediment count nominal'),
    ('Yashoda Hyderabad','UA-YSH-61','Beckman Iris iChem VELOCITY','protein','central_lab','2026-06-29',
     30,45,50.00,false,'STRIP-H055','2026-05-10','fail','Protein 50% high, flow cell fault — removed pending service'),
    ('Kokilaben Mumbai','UA-KKB-71','Roche Cobas u 601','glucose','emergency_lab','2026-06-29',
     100,96,4.00,true,'STRIP-J012','2026-06-19','pass','Glucose control within tolerance'),
    ('Kokilaben Mumbai','UA-KKB-72','Sysmex UF-5000','ph','nephrology_lab','2026-06-28',
     6.00,6.42,7.00,true,'STRIP-J013','2026-06-19','conditional_pass','pH 7% high — recalibration scheduled'),
    ('Apollo Chennai','UA-APL-03','Arkray Aution Max AX-4030','strip_color_accuracy','opd_lab','2026-06-28',
     100,82,18.00,false,'STRIP-A232','2026-05-05','fail','Strip color badly off with flow cell fault, calibration long overdue')
  ) as q(hosp, dcode, model, param, unit, cdate, refv, measv, devp, flow, lot, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.urine_analyzer_qc_capa_actions_r3463 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('UA-FRT-12','glucose_accuracy_deviation','reagent_strip_expired','replace_reagent_strips','in_progress','iso_15189_deviation','2026-07-08',null,9000.00,'Reagent strip lot recalled — replacement lot in QC'),
    ('UA-MNP-21','flow_cell_contamination','flow_cell_dirty','clean_flow_cell','verification_pending','internal_only','2026-07-06',null,3500.00,'Flow cell cleaned — verify sediment count next run'),
    ('UA-CMC-41','strip_color_miscalibration','optics_lamp_degraded','replace_optics_lamp','open','nabl_finding','2026-07-09',null,26000.00,'Optics lamp degraded — replacement scheduled'),
    ('UA-YSH-61','protein_false_result','flow_cell_dirty','remove_from_service','escalated','patient_safety_alert','2026-07-05',null,41000.00,'Analyzer removed; false protein positives — escalated to OEM'),
    ('UA-KKB-72','ph_out_of_tolerance','calibrator_lot_variance','recalibrate_analyzer','open','internal_only','2026-07-10',null,2000.00,'Recalibration scheduled after pH drift'),
    ('UA-APL-03','calibration_overdue','preventive_service_backlog','recalibrate_analyzer','overdue','nabl_finding','2026-06-30',null,18000.00,'Calibration long overdue — PM backlog, vendor delay'),
    ('UA-KIM-51','specific_gravity_drift','flow_cell_dirty','clean_flow_cell','closed','internal_only','2026-07-04','2026-07-02',3500.00,'Flow cell cleaned and SG re-verified — closed'),
    ('UA-FRT-11','ph_out_of_tolerance','calibrator_lot_variance','recalibrate_analyzer','closed','internal_only','2026-07-06','2026-07-03',2000.00,'Recalibrated with new calibrator lot — pH back in range')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.urine_analyzer_qc_r3463 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3463_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.urine_analyzer_qc_r3463)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.urine_analyzer_qc_r3463 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3463_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3463_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3463_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  flow_cell_fail bigint,
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
    count(*) filter (where l.flow_cell_ok = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.urine_analyzer_qc_r3463 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3463_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3463_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3463_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.urine_analyzer_qc_r3463 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3463_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3463_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3463_monthly_accuracy_trend()
returns table(month date, checks bigint, passed bigint, failed bigint, flow_cell_fail bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.check_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.flow_cell_ok = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.urine_analyzer_qc_r3463 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3463_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3463_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3463_capa_status_board()
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
  from public.urine_analyzer_qc_capa_actions_r3463 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3463_capa_status_board() from public, anon;
grant execute on function public.founder_r3463_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3463_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.urine_analyzer_qc_capa_actions_r3463)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.urine_analyzer_qc_capa_actions_r3463 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3463_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3463_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter out-of-tolerance)
create or replace function public.founder_r3463_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric,
  flow_cell_fail bigint
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
    count(*) filter (where l.qc_verdict in ('conditional_pass','fail'))::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2),
    count(*) filter (where l.flow_cell_ok = false)::bigint
  from public.urine_analyzer_qc_r3463 l
  group by l.parameter
  order by count(*) filter (where l.qc_verdict in ('conditional_pass','fail')) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3463_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3463_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / flow-cell fault)
create or replace function public.founder_r3463_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  unit text,
  check_date date,
  qc_verdict text,
  deviation_pct numeric,
  flow_cell_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.unit, l.check_date,
    l.qc_verdict, l.deviation_pct, l.flow_cell_ok, l.notes
  from public.urine_analyzer_qc_r3463 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.flow_cell_ok = false
     or l.deviation_pct >= 10
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3463_high_risk_queue() from public, anon;
grant execute on function public.founder_r3463_high_risk_queue() to authenticated;
