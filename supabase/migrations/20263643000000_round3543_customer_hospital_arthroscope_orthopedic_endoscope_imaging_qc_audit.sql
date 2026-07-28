-- Round 3543: Customer Hospital Arthroscope (Orthopedic Endoscope) Imaging QC Audit
-- Orthopedic arthroscope imaging QA — device model x unit x parameter (resolution, light,
-- viewing angle, color fidelity, focus, seal leak) x reference vs measured x deviation x
-- within-tolerance x calibration currency x qc verdict x CAPA closure.

-- =============================================================================
-- TABLE 1: arthroscope_qc_r3543 — per-parameter arthroscope imaging QC checks
-- =============================================================================
create table if not exists public.arthroscope_qc_r3543 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  check_ref text not null,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  unit text not null check (unit in (
    'orthopedic_ot','sports_medicine_ot','arthroscopy_suite','day_care_ot'
  )),
  parameter text not null check (parameter in (
    'image_resolution','light_transmission','viewing_angle_deg','color_fidelity','focus_clarity','seal_leak_test'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  technician text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.arthroscope_qc_r3543 enable row level security;

create index if not exists idx_arthroscope_qc_r3543_org on public.arthroscope_qc_r3543(organization_id);
create index if not exists idx_arthroscope_qc_r3543_date on public.arthroscope_qc_r3543(calibration_date);
create index if not exists idx_arthroscope_qc_r3543_verdict on public.arthroscope_qc_r3543(qc_verdict);
create index if not exists idx_arthroscope_qc_r3543_ref on public.arthroscope_qc_r3543(check_ref);

-- =============================================================================
-- TABLE 2: arthroscope_qc_capa_actions_r3543 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.arthroscope_qc_capa_actions_r3543 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.arthroscope_qc_r3543(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'resolution_below_spec','light_transmission_loss','viewing_angle_deviation','color_fidelity_drift',
    'focus_clarity_degraded','seal_leak_detected','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'fiber_bundle_broken','lens_scratched','light_cable_degraded','ccd_sensor_aging','autoclave_seal_failure',
    'fluid_ingress','o_ring_worn','operator_handling_damage','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_fiber_bundle','repair_polish_lens','replace_light_cable','replace_ccd_module','reseal_and_leak_test',
    'replace_o_ring_set','send_to_oem_repair','retrain_ot_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.arthroscope_qc_capa_actions_r3543 enable row level security;

create index if not exists idx_arthroscope_capa_r3543_log on public.arthroscope_qc_capa_actions_r3543(qc_log_id);
create index if not exists idx_arthroscope_capa_r3543_status on public.arthroscope_qc_capa_actions_r3543(capa_status);

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

  -- 16 arthroscope QC check rows
  insert into public.arthroscope_qc_r3543 (
    organization_id, check_ref, hospital_name, device_code, device_model, unit, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, calibration_date,
    technician, qc_verdict, notes
  )
  select v_org_id, q.cref, q.hosp, q.dcode, q.model, q.unit, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol, q.caldate::date,
    q.tech, q.qv, q.nt
  from (values
    ('AQC-0001','Apollo Chennai','ART-APL-01','Stryker 1588 AIM','orthopedic_ot','image_resolution',
     1080,1072,0.74,true,'2026-07-05','R. Kumar','pass','Stryker 1588 tower resolution within spec'),
    ('AQC-0002','Apollo Chennai','ART-APL-01','Stryker 1588 AIM','orthopedic_ot','light_transmission',
     95,93.5,1.58,true,'2026-07-05','R. Kumar','pass','Light transmission nominal at 93.5 percent'),
    ('AQC-0003','Apollo Chennai','ART-APL-02','Karl Storz Image1 S','sports_medicine_ot','seal_leak_test',
     20,12,-40.0,true,'2026-07-05','R. Kumar','pass','Leak test 12 mbar/min, well under 20 threshold'),
    ('AQC-0004','Fortis Gurgaon','ART-FRT-11','Olympus Visera Elite II','arthroscopy_suite','image_resolution',
     1080,980,9.26,false,'2026-07-04','S. Nair','conditional_pass','Resolution below spec — fiber bundle aging'),
    ('AQC-0005','Fortis Gurgaon','ART-FRT-11','Olympus Visera Elite II','arthroscopy_suite','light_transmission',
     95,78,17.89,false,'2026-07-04','S. Nair','fail','Light transmission dropped to 78 percent — broken fiber bundle'),
    ('AQC-0006','Fortis Gurgaon','ART-FRT-12','Arthrex Synergy UHD4','orthopedic_ot','viewing_angle_deg',
     30,30.5,1.67,true,'2026-07-04','S. Nair','pass','30 degree scope angle within tolerance'),
    ('AQC-0007','Manipal Bengaluru','ART-MNP-21','Stryker 1588 AIM','day_care_ot','seal_leak_test',
     20,45,125.0,false,'2026-07-03','A. Rao','fail','Seal leak 45 mbar/min — fluid ingress risk'),
    ('AQC-0008','Manipal Bengaluru','ART-MNP-22','Karl Storz Image1 S','sports_medicine_ot','color_fidelity',
     98,96,2.04,true,'2026-07-03','A. Rao','pass','Color fidelity index within tolerance'),
    ('AQC-0009','AIIMS Delhi','ART-AIM-31','Olympus Visera Elite II','orthopedic_ot','focus_clarity',
     95,88,7.37,false,'2026-07-02','P. Singh','conditional_pass','Focus clarity marginal — lens polish scheduled'),
    ('AQC-0010','AIIMS Delhi','ART-AIM-31','Olympus Visera Elite II','orthopedic_ot','image_resolution',
     1080,1065,1.39,true,'2026-07-02','P. Singh','pass','Resolution within spec post-service'),
    ('AQC-0011','CMC Vellore','ART-CMC-41','Arthrex Synergy UHD4','arthroscopy_suite','light_transmission',
     95,94,1.05,true,'2026-07-01','J. Thomas','pass','Light transmission nominal'),
    ('AQC-0012','CMC Vellore','ART-CMC-42','Smith & Nephew Lens 4K','sports_medicine_ot','seal_leak_test',
     20,25,25.0,false,'2026-07-01','J. Thomas','conditional_pass','Minor leak 25 mbar/min — o-ring replacement due'),
    ('AQC-0013','KIMS Hyderabad','ART-KIM-51','Stryker 1588 AIM','orthopedic_ot','viewing_angle_deg',
     70,68,2.86,true,'2026-06-30','M. Reddy','pass','70 degree scope angle within tolerance'),
    ('AQC-0014','KIMS Hyderabad','ART-KIM-52','Karl Storz Image1 S','day_care_ot','color_fidelity',
     98,90,8.16,false,'2026-06-30','M. Reddy','conditional_pass','Color drift — white balance recalibrated'),
    ('AQC-0015','Yashoda Hyderabad','ART-YSH-61','Olympus Visera Elite II','arthroscopy_suite','focus_clarity',
     95,94,1.05,true,'2026-06-29','K. Das','pass','Focus clarity nominal'),
    ('AQC-0016','Kokilaben Mumbai','ART-KKB-71','Smith & Nephew Lens 4K','orthopedic_ot','seal_leak_test',
     20,60,200.0,false,'2026-06-29','V. Menon','fail','Severe seal leak 60 mbar/min — scope removed from service')
  ) as q(cref, hosp, dcode, model, unit, param, refv, measv, devp, wtol, caldate, tech, qv, nt);

  -- CAPA seed — attach to specific checks via check_ref
  insert into public.arthroscope_qc_capa_actions_r3543 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('AQC-0004','resolution_below_spec','fiber_bundle_broken','replace_fiber_bundle','in_progress','iso_13485_deviation','2026-07-10',null,85000.00,'Fiber bundle degraded — replacement kit ordered'),
    ('AQC-0005','light_transmission_loss','fiber_bundle_broken','replace_fiber_bundle','escalated','patient_safety_alert','2026-07-08',null,92000.00,'Severe transmission loss — escalated to OEM'),
    ('AQC-0007','seal_leak_detected','autoclave_seal_failure','reseal_and_leak_test','closed','cdsco_notifiable','2026-07-06','2026-07-04',34000.00,'Scope resealed and leak-tested — returned to service'),
    ('AQC-0009','focus_clarity_degraded','lens_scratched','repair_polish_lens','verification_pending','internal_only','2026-07-09',null,28000.00,'Objective lens polished — verify clarity next QC'),
    ('AQC-0012','seal_leak_detected','o_ring_worn','replace_o_ring_set','open','nabh_finding','2026-07-11',null,6500.00,'O-ring set replacement scheduled'),
    ('AQC-0014','color_fidelity_drift','ccd_sensor_aging','replace_ccd_module','overdue','internal_only','2026-07-05',null,120000.00,'CCD camera module replacement past target — vendor delay'),
    ('AQC-0016','seal_leak_detected','fluid_ingress','remove_from_service','escalated','patient_safety_alert','2026-07-07',null,150000.00,'Fluid ingress detected — scope removed, OEM repair quote pending'),
    ('AQC-0013','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-15',null,15000.00,'Annual preventive maintenance due — OEM service scheduled')
  ) as q(cref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.arthroscope_qc_r3543 e
    on e.organization_id = v_org_id and e.check_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3543_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.arthroscope_qc_r3543)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.arthroscope_qc_r3543 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3543_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3543_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3543_device_model_scorecard()
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
  from public.arthroscope_qc_r3543 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3543_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3543_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3543_parameter_verdict_matrix()
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
  from public.arthroscope_qc_r3543 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3543_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3543_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3543_monthly_calibration_trend()
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
  from public.arthroscope_qc_r3543 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3543_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3543_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3543_capa_status_board()
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
  from public.arthroscope_qc_capa_actions_r3543 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3543_capa_status_board() from public, anon;
grant execute on function public.founder_r3543_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3543_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.arthroscope_qc_capa_actions_r3543)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.arthroscope_qc_capa_actions_r3543 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3543_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3543_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3543_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, worst_deviation_pct numeric, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(max(abs(l.deviation_pct)), 2),
    round(avg(abs(l.deviation_pct)), 2)
  from public.arthroscope_qc_r3543 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3543_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3543_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail concerns)
create or replace function public.founder_r3543_high_risk_queue()
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
  from public.arthroscope_qc_r3543 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or (l.parameter = 'seal_leak_test' and l.within_tolerance = false)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3543_high_risk_queue() from public, anon;
grant execute on function public.founder_r3543_high_risk_queue() to authenticated;
