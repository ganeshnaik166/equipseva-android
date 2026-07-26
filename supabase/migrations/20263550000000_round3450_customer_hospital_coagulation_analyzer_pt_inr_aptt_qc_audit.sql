-- Round 3450: Customer Hospital Coagulation Analyzer (PT/INR/aPTT) QC Audit
-- Coagulation analyzer QA — parameter (PT/INR/aPTT/fibrinogen/D-dimer/control) × device model × reference vs measured × deviation × qc level × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: coag_analyzer_qc_r3450 — per-parameter coagulation analyzer QC checks
-- =============================================================================
create table if not exists public.coag_analyzer_qc_r3450 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'pt_sec','inr','aptt_sec','fibrinogen_mgdl','d_dimer','control_level'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  qc_level text not null check (qc_level in (
    'normal','abnormal_low','abnormal_high'
  )),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.coag_analyzer_qc_r3450 enable row level security;

create index if not exists idx_coag_analyzer_qc_r3450_org on public.coag_analyzer_qc_r3450(organization_id);
create index if not exists idx_coag_analyzer_qc_r3450_caldate on public.coag_analyzer_qc_r3450(calibration_date);
create index if not exists idx_coag_analyzer_qc_r3450_verdict on public.coag_analyzer_qc_r3450(qc_verdict);

-- =============================================================================
-- TABLE 2: coag_analyzer_qc_capa_actions_r3450 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.coag_analyzer_qc_capa_actions_r3450 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.coag_analyzer_qc_r3450(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'control_out_of_range','accuracy_deviation','reagent_deterioration','optics_fault',
    'calibration_overdue','clot_detection_error','temperature_control_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'reagent_lot_variation','reagent_expired','optical_channel_drift','lamp_degraded',
    'calibrator_lot_change','sample_handling_error','operator_setup_error',
    'pending_investigation','temperature_control_failure','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_analyzer','replace_reagent_lot','replace_calibrator','clean_replace_optics',
    'replace_lamp','rerun_controls','retrain_lab_staff','schedule_oem_service',
    'remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only',
    'iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.coag_analyzer_qc_capa_actions_r3450 enable row level security;

create index if not exists idx_coag_analyzer_capa_r3450_log on public.coag_analyzer_qc_capa_actions_r3450(qc_log_id);
create index if not exists idx_coag_analyzer_capa_r3450_status on public.coag_analyzer_qc_capa_actions_r3450(capa_status);

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
  insert into public.coag_analyzer_qc_r3450 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, qc_level, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.qlvl, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','COAG-APL-PT1','Sysmex CS-2500','pt_sec',
     12.5,12.6,0.80,'normal',true,'2026-07-05','pass','Quarterly PT control level 1 within tolerance'),
    ('Apollo Chennai','COAG-APL-INR1','Sysmex CS-2500','inr',
     1.00,1.02,2.00,'normal',true,'2026-07-05','pass','INR derived control within limit'),
    ('Fortis Gurgaon','COAG-FRT-APTT1','Stago STA-R Max','aptt_sec',
     30.00,33.50,11.67,'abnormal_high',false,'2026-07-04','conditional_pass','aPTT abnormal-high control drifting — reagent near expiry'),
    ('Fortis Gurgaon','COAG-FRT-PT2','Stago STA-R Max','pt_sec',
     12.00,15.80,31.67,'abnormal_high',false,'2026-07-04','fail','PT abnormal-high control out of tolerance — recalibrate'),
    ('Manipal Bengaluru','COAG-MNP-FIB1','Werfen ACL TOP 750','fibrinogen_mgdl',
     300.00,250.00,-16.67,'abnormal_low',false,'2026-07-03','fail','Fibrinogen low control failed — reagent lot variation'),
    ('Manipal Bengaluru','COAG-MNP-DD1','Werfen ACL TOP 750','d_dimer',
     0.50,0.52,4.00,'normal',true,'2026-07-03','pass','D-dimer normal control within range'),
    ('AIIMS Delhi','COAG-AIM-CTRL1','Sysmex CS-5100','control_level',
     1.00,1.03,3.00,'normal',true,'2026-06-30','pass','Level 1 and 2 daily controls within range'),
    ('AIIMS Delhi','COAG-AIM-APTT2','Sysmex CS-5100','aptt_sec',
     32.00,34.00,6.25,'normal',true,'2026-06-30','conditional_pass','aPTT trending upward within limit — monitor next run'),
    ('CMC Vellore','COAG-CMC-PT3','Stago STA Compact Max','pt_sec',
     12.50,12.40,-0.80,'normal',true,'2026-06-29','pass','PT normal control within tolerance'),
    ('CMC Vellore','COAG-CMC-INR2','Stago STA Compact Max','inr',
     2.50,3.20,28.00,'abnormal_high',false,'2026-06-29','fail','INR abnormal-high control out of tolerance — optics suspected'),
    ('KIMS Hyderabad','COAG-KIM-FIB2','Werfen ACL TOP 550','fibrinogen_mgdl',
     250.00,258.00,3.20,'normal',true,'2026-06-28','pass','Fibrinogen normal control within tolerance'),
    ('KIMS Hyderabad','COAG-KIM-DD2','Werfen ACL TOP 550','d_dimer',
     1.00,1.35,35.00,'abnormal_high',false,'2026-06-28','fail','D-dimer high control out of tolerance — reagent deterioration'),
    ('Yashoda Hyderabad','COAG-YSH-PT4','Sysmex CS-2500','pt_sec',
     12.00,12.90,7.50,'normal',true,'2026-06-27','conditional_pass','PT within limit but calibration overdue flagged'),
    ('Kokilaben Mumbai','COAG-KKB-APTT3','Stago STA-R Max','aptt_sec',
     30.00,41.00,36.67,'abnormal_high',false,'2026-06-26','fail','aPTT grossly out of tolerance — analyzer removed pending service'),
    ('Kokilaben Mumbai','COAG-KKB-CTRL2','Stago STA-R Max','control_level',
     1.00,0.98,-2.00,'normal',true,'2026-06-26','pass','Level 1 control within range post-service'),
    ('Medanta Gurgaon','COAG-MDT-FIB3','Werfen ACL TOP 750','fibrinogen_mgdl',
     400.00,300.00,-25.00,'abnormal_low',false,'2026-06-25','fail','Fibrinogen abnormal-low control failed — lamp degraded')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, qlvl, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.coag_analyzer_qc_capa_actions_r3450 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('COAG-FRT-APTT1','reagent_deterioration','reagent_expired','replace_reagent_lot','in_progress','nabl_finding','2026-07-08',null,12000.00,'aPTT reagent near expiry replaced — verify controls next run'),
    ('COAG-FRT-PT2','accuracy_deviation','calibrator_lot_change','recalibrate_analyzer','verification_pending','iso_15189_deviation','2026-07-07',null,8000.00,'PT recalibrated after calibrator lot change — pending verification'),
    ('COAG-MNP-FIB1','reagent_deterioration','reagent_lot_variation','replace_reagent_lot','open','nabl_finding','2026-07-06',null,15000.00,'Fibrinogen reagent lot variation — new lot ordered'),
    ('COAG-CMC-INR2','optics_fault','optical_channel_drift','clean_replace_optics','escalated','patient_safety_alert','2026-07-05',null,35000.00,'INR optical channel drift — OEM escalation raised'),
    ('COAG-KIM-DD2','reagent_deterioration','reagent_expired','replace_reagent_lot','closed','internal_only','2026-07-02','2026-06-30',9500.00,'D-dimer reagent replaced and controls re-passed'),
    ('COAG-KKB-APTT3','accuracy_deviation','temperature_control_failure','schedule_oem_service','escalated','cdsco_notifiable','2026-07-04',null,48000.00,'Analyzer removed — incubation temperature fault, OEM service booked'),
    ('COAG-MDT-FIB3','optics_fault','lamp_degraded','replace_lamp','overdue','iso_15189_deviation','2026-06-30',null,22000.00,'Lamp replacement past target date — vendor delay'),
    ('COAG-YSH-PT4','calibration_overdue','preventive_service_backlog','recalibrate_analyzer','open','internal_only','2026-07-09',null,0.00,'Calibration overdue — preventive maintenance scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.coag_analyzer_qc_r3450 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3450_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coag_analyzer_qc_r3450)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.coag_analyzer_qc_r3450 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3450_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3450_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3450_device_model_scorecard()
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
  from public.coag_analyzer_qc_r3450 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3450_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3450_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3450_parameter_verdict_matrix()
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
  from public.coag_analyzer_qc_r3450 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3450_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3450_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3450_monthly_accuracy_trend()
returns table(qc_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
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
  from public.coag_analyzer_qc_r3450 l
  group by to_char(l.calibration_date, 'YYYY-MM')
  order by to_char(l.calibration_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3450_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3450_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3450_capa_status_board()
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
  from public.coag_analyzer_qc_capa_actions_r3450 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3450_capa_status_board() from public, anon;
grant execute on function public.founder_r3450_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3450_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coag_analyzer_qc_capa_actions_r3450)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.coag_analyzer_qc_capa_actions_r3450 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3450_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3450_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3450_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric
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
  from public.coag_analyzer_qc_r3450 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3450_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3450_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3450_high_risk_queue()
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
  from public.coag_analyzer_qc_r3450 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.qc_level in ('abnormal_low','abnormal_high')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3450_high_risk_queue() from public, anon;
grant execute on function public.founder_r3450_high_risk_queue() to authenticated;
