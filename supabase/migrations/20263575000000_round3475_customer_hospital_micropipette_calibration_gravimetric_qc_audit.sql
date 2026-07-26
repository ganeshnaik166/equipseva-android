-- Round 3475: Customer Hospital Micropipette Gravimetric-Calibration QC Audit
-- Lab micropipette gravimetric calibration QA — device model × parameter (accuracy / precision CV / volume 10-100-1000µL / leak) × reference vs measured × deviation % × tolerance × CV × verdict × CAPA

-- =============================================================================
-- TABLE 1: micropipette_qc_r3475 — per-pipette gravimetric calibration QC checks
-- =============================================================================
create table if not exists public.micropipette_qc_r3475 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  lab_section text not null,
  device_code text not null,
  device_model text not null,
  manufacturer text not null,
  parameter text not null check (parameter in (
    'accuracy_pct','precision_cv_pct','volume_10ul','volume_100ul','volume_1000ul','leak_test'
  )),
  nominal_volume_ul numeric(10,2),
  reference_value numeric(12,4),
  measured_value numeric(12,4),
  deviation_pct numeric(6,2),
  tolerance_limit_pct numeric(6,2),
  within_tolerance boolean not null,
  cv_pct numeric(6,2),
  water_temp_c numeric(4,1),
  replicate_count int,
  calibration_date date not null,
  technician text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.micropipette_qc_r3475 enable row level security;

create index if not exists idx_micropipette_qc_r3475_org on public.micropipette_qc_r3475(organization_id);
create index if not exists idx_micropipette_qc_r3475_date on public.micropipette_qc_r3475(calibration_date);
create index if not exists idx_micropipette_qc_r3475_verdict on public.micropipette_qc_r3475(qc_verdict);

-- =============================================================================
-- TABLE 2: micropipette_qc_capa_actions_r3475 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.micropipette_qc_capa_actions_r3475 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.micropipette_qc_r3475(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'accuracy_out_of_tolerance','precision_cv_exceeded','volume_under_dispense','volume_over_dispense',
    'leak_test_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'piston_seal_wear','o_ring_degraded','tip_cone_damaged','spring_fatigue',
    'operator_technique_error','balance_environment_drift','contamination_residue',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_piston_seal','replace_o_ring','replace_tip_cone','recalibrate_adjust',
    'clean_and_decontaminate','retrain_lab_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cap_deviation','iso_15189_deviation','internal_only','none','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.micropipette_qc_capa_actions_r3475 enable row level security;

create index if not exists idx_micropipette_capa_r3475_log on public.micropipette_qc_capa_actions_r3475(qc_log_id);
create index if not exists idx_micropipette_capa_r3475_status on public.micropipette_qc_capa_actions_r3475(capa_status);

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

  -- 16 gravimetric calibration QC rows
  insert into public.micropipette_qc_r3475 (
    organization_id, hospital_name, lab_section, device_code, device_model, manufacturer,
    parameter, nominal_volume_ul, reference_value, measured_value, deviation_pct,
    tolerance_limit_pct, within_tolerance, cv_pct, water_temp_c, replicate_count,
    calibration_date, technician, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.sect, q.dcode, q.model, q.mfr,
    q.param, q.nvol, q.refv, q.meas, q.dev,
    q.tol, q.wtol, q.cv, q.wtemp, q.reps,
    q.cdate::date, q.tech, q.qv, q.nt
  from (values
    ('Apollo Chennai','biochemistry','PIP-APL-01','Eppendorf Research Plus','Eppendorf','volume_100ul',100,100.00,100.4,0.40,0.80,true,0.30,22.4,10,'2026-07-12','R. Menon','pass','P100 accuracy 0.40% within 0.80% tolerance'),
    ('Apollo Chennai','biochemistry','PIP-APL-02','Gilson Pipetman P200','Gilson','precision_cv_pct',200,null,null,0.18,0.30,true,0.18,22.4,10,'2026-07-12','R. Menon','pass','CV 0.18% within 0.30% precision limit'),
    ('Apollo Chennai','microbiology','PIP-APL-07','Thermo Finnpipette F1','Thermo Fisher','volume_1000ul',1000,1000.00,992.0,-0.80,0.60,false,0.45,22.8,10,'2026-07-11','S. Iyer','fail','1000uL under-dispensing 0.80% beyond 0.60% tolerance'),
    ('Fortis Gurgaon','molecular','PIP-FRT-11','Rainin Pipet-Lite XLS','Rainin','volume_10ul',10,10.00,10.09,0.90,1.00,true,0.85,23.1,10,'2026-07-09','A. Khanna','conditional_pass','10uL accuracy 0.90% near 1.0% limit — recheck next cycle'),
    ('Fortis Gurgaon','molecular','PIP-FRT-12','Eppendorf Reference 2','Eppendorf','leak_test',null,null,null,null,null,false,null,23.1,5,'2026-07-09','A. Khanna','fail','Leak test failed — meniscus drop, seal replacement due'),
    ('Fortis Gurgaon','biochemistry','PIP-FRT-15','Sartorius Tacta','Sartorius','accuracy_pct',100,null,null,0.35,0.80,true,null,22.9,10,'2026-07-08','A. Khanna','pass','Systematic error 0.35% within spec'),
    ('Manipal Bengaluru','hematology','PIP-MNP-21','Eppendorf Research Plus','Eppendorf','volume_100ul',100,100.00,99.1,-0.90,0.80,false,0.40,21.9,10,'2026-07-07','K. Rao','fail','P100 under by 0.90% beyond 0.80% tolerance — service required'),
    ('Manipal Bengaluru','hematology','PIP-MNP-22','Gilson Pipetman P200','Gilson','precision_cv_pct',200,null,null,0.42,0.30,false,0.42,21.9,10,'2026-07-07','K. Rao','fail','CV 0.42% exceeds 0.30% precision limit — piston wear suspected'),
    ('AIIMS Delhi','blood_bank','PIP-AIM-31','Thermo Finnpipette F1','Thermo Fisher','volume_1000ul',1000,1000.00,1003.5,0.35,0.60,true,0.28,22.2,10,'2026-07-06','P. Nair','pass','1000uL within accuracy tolerance'),
    ('AIIMS Delhi','biochemistry','PIP-AIM-33','Rainin Pipet-Lite XLS','Rainin','volume_10ul',10,10.00,10.14,1.40,1.00,false,1.10,22.5,10,'2026-07-06','P. Nair','fail','10uL over by 1.40% and CV high — recalibration and O-ring change'),
    ('CMC Vellore','microbiology','PIP-CMC-41','Eppendorf Reference 2','Eppendorf','volume_100ul',100,100.00,100.5,0.50,0.80,true,0.33,23.4,10,'2026-07-05','J. Thomas','pass','Reference 2 P100 nominal'),
    ('CMC Vellore','molecular','PIP-CMC-44','Sartorius Tacta','Sartorius','precision_cv_pct',20,null,null,0.55,0.60,true,0.55,23.4,10,'2026-07-05','J. Thomas','conditional_pass','CV 0.55% approaching 0.60% limit — monitor'),
    ('KIMS Hyderabad','biochemistry','PIP-KIM-51','Eppendorf Research Plus','Eppendorf','accuracy_pct',1000,null,null,0.20,0.60,true,null,22.0,10,'2026-07-04','M. Reddy','pass','Systematic error 0.20% within spec post-service'),
    ('KIMS Hyderabad','histopathology','PIP-KIM-53','Gilson Pipetman P200','Gilson','leak_test',null,null,null,null,null,true,null,22.0,5,'2026-07-04','M. Reddy','pass','Leak/tightness test pass'),
    ('Yashoda Hyderabad','hematology','PIP-YSH-61','Thermo Finnpipette F1','Thermo Fisher','volume_1000ul',1000,1000.00,995.8,-0.42,0.60,true,0.50,22.6,10,'2026-07-03','D. Varma','conditional_pass','1000uL accuracy ok but CV 0.50% trending up'),
    ('Kokilaben Mumbai','molecular','PIP-KKB-71','Rainin Pipet-Lite XLS','Rainin','volume_10ul',10,10.00,9.83,-1.70,1.00,false,1.30,23.0,10,'2026-07-02','N. Deshpande','fail','10uL under 1.70% with poor precision — removed pending service')
  ) as q(hosp, sect, dcode, model, mfr, param, nvol, refv, meas, dev, tol, wtol, cv, wtemp, reps, cdate, tech, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.micropipette_qc_capa_actions_r3475 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PIP-APL-07','volume_under_dispense','piston_seal_wear','replace_piston_seal','in_progress','nabl_finding','2026-07-16',null,3500.00,'1000uL under-dispensing — piston seal replaced, verification pending'),
    ('PIP-FRT-12','leak_test_failure','o_ring_degraded','replace_o_ring','open','iso_15189_deviation','2026-07-15',null,1200.00,'Leak on Reference 2 — O-ring kit ordered'),
    ('PIP-FRT-11','accuracy_out_of_tolerance','operator_technique_error','retrain_lab_staff','verification_pending','internal_only','2026-07-14',null,0.00,'10uL borderline — pre-wet technique retraining scheduled'),
    ('PIP-MNP-21','volume_under_dispense','spring_fatigue','recalibrate_adjust','escalated','nabl_finding','2026-07-13',null,4200.00,'P100 under-dispense beyond tolerance — escalated to OEM'),
    ('PIP-MNP-22','precision_cv_exceeded','piston_seal_wear','replace_piston_seal','in_progress','cap_deviation','2026-07-13',null,3500.00,'CV exceeded — seal and O-ring replaced'),
    ('PIP-AIM-33','volume_over_dispense','o_ring_degraded','replace_o_ring','closed','nabl_finding','2026-07-12','2026-07-15',1800.00,'10uL over-dispense corrected; O-ring changed and re-verified pass'),
    ('PIP-KKB-71','volume_under_dispense','tip_cone_damaged','remove_from_service','escalated','patient_safety_alert','2026-07-11',null,5200.00,'Damaged tip cone, poor precision — removed pending service'),
    ('PIP-CMC-44','precision_cv_exceeded','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-10',null,2600.00,'CV trending up — OEM preventive service past target date')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.micropipette_qc_r3475 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3475_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.micropipette_qc_r3475)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.micropipette_qc_r3475 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3475_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3475_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3475_device_model_scorecard()
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
    round(avg(abs(l.deviation_pct)), 3),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.micropipette_qc_r3475 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3475_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3475_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3475_parameter_verdict_matrix()
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
    round(avg(l.deviation_pct), 3)
  from public.micropipette_qc_r3475 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3475_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3475_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3475_monthly_trend()
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
    round(avg(abs(l.deviation_pct)), 3)
  from public.micropipette_qc_r3475 l
  group by 1
  order by 1 desc;
end;
$$;

revoke execute on function public.founder_r3475_monthly_trend() from public, anon;
grant execute on function public.founder_r3475_monthly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3475_capa_status_board()
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
  from public.micropipette_qc_capa_actions_r3475 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3475_capa_status_board() from public, anon;
grant execute on function public.founder_r3475_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3475_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.micropipette_qc_capa_actions_r3475)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.micropipette_qc_capa_actions_r3475 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3475_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3475_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (deviation severity bands)
create or replace function public.founder_r3475_accuracy_impact_digest()
returns table(severity_band text, checks bigint, out_of_tolerance bigint, failed bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when l.deviation_pct is null then 'no_deviation_metric'
      when abs(l.deviation_pct) <= 0.5 then 'within_half_pct'
      when abs(l.deviation_pct) <= 1.0 then 'half_to_one_pct'
      else 'over_one_pct'
    end as severity_band,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(abs(l.deviation_pct)), 3)
  from public.micropipette_qc_r3475 l
  group by 1
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3475_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3475_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / conditional)
create or replace function public.founder_r3475_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  tolerance_limit_pct numeric,
  cv_pct numeric,
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
    l.qc_verdict, l.deviation_pct, l.tolerance_limit_pct, l.cv_pct, l.notes
  from public.micropipette_qc_r3475 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3475_high_risk_queue() from public, anon;
grant execute on function public.founder_r3475_high_risk_queue() to authenticated;
