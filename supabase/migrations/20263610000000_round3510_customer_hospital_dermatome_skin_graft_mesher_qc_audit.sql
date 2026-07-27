-- Round 3510: Customer Hospital Dermatome / Skin-Graft Mesher QC Audit
-- Hospital dermatome / skin-graft mesher QC — blade oscillation, graft thickness, depth accuracy,
-- mesh ratio, width accuracy, blade sharpness × device model × parameter × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: dermatome_qc_r3510 — per-device dermatome / mesher QC checks
-- =============================================================================
create table if not exists public.dermatome_qc_r3510 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'oscillation_rpm','set_thickness_mm','measured_thickness_mm',
    'blade_sharpness','mesh_ratio','width_accuracy_mm'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  tolerance_band_pct numeric(5,2),
  calibration_date date not null,
  next_calibration_date date,
  technician text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dermatome_qc_r3510 enable row level security;

create index if not exists idx_dermatome_qc_r3510_org on public.dermatome_qc_r3510(organization_id);
create index if not exists idx_dermatome_qc_r3510_date on public.dermatome_qc_r3510(calibration_date);
create index if not exists idx_dermatome_qc_r3510_verdict on public.dermatome_qc_r3510(qc_verdict);

-- =============================================================================
-- TABLE 2: dermatome_qc_capa_actions_r3510 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dermatome_qc_capa_actions_r3510 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.dermatome_qc_r3510(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'thickness_out_of_tolerance','oscillation_rpm_out_of_tolerance','blade_dull',
    'mesh_ratio_deviation','width_accuracy_out_of_tolerance','depth_accuracy_drift',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'blade_wear','motor_wear','depth_gauge_miscalibration','mesh_roller_worn',
    'operator_setup_error','spring_tension_loss','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_blade','recalibrate_depth_gauge','replace_mesh_roller','service_motor',
    'adjust_spring_tension','retrain_ot_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.dermatome_qc_capa_actions_r3510 enable row level security;

create index if not exists idx_dermatome_capa_r3510_log on public.dermatome_qc_capa_actions_r3510(qc_log_id);
create index if not exists idx_dermatome_capa_r3510_status on public.dermatome_qc_capa_actions_r3510(capa_status);

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
  insert into public.dermatome_qc_r3510 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, tolerance_band_pct,
    calibration_date, next_calibration_date, technician, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol, q.tolband,
    q.caldate::date, q.nextcal::date, q.tech, q.qv, q.nt
  from (values
    ('Apollo Chennai','DRM-APL-01','Zimmer Air Dermatome','oscillation_rpm',
     4500.0,4460.0,-0.9,true,5.0,'2026-07-05','2027-01-05','S. Kumar','pass','Oscillation speed within 5% band'),
    ('Apollo Chennai','DRM-APL-01','Zimmer Air Dermatome','measured_thickness_mm',
     0.40,0.41,2.5,true,10.0,'2026-07-05','2027-01-05','S. Kumar','pass','Graft thickness accurate at 0.4 mm setting'),
    ('Fortis Gurgaon','DRM-FRT-11','Aesculap Acculan 3Ti','set_thickness_mm',
     0.30,0.34,13.3,false,10.0,'2026-07-04',null,'A. Mehta','conditional_pass','Thickness dial reads high — recalibrate depth gauge'),
    ('Fortis Gurgaon','MSH-FRT-12','Zimmer Skin Graft Mesher','mesh_ratio',
     1.5,1.5,0.0,true,5.0,'2026-07-04','2027-01-04','A. Mehta','pass','Mesh ratio 1.5:1 verified'),
    ('Manipal Bengaluru','DRM-MNP-21','Humeca D80 Dermatome','blade_sharpness',
     100.0,62.0,-38.0,false,20.0,'2026-06-20',null,'R. Rao','fail','Blade sharpness index low — replace blade'),
    ('Manipal Bengaluru','DRM-MNP-22','Nouvag Dermatome','oscillation_rpm',
     4000.0,3980.0,-0.5,true,5.0,'2026-06-20','2026-12-20','R. Rao','pass','Motor oscillation nominal'),
    ('AIIMS Delhi','DRM-AIM-31','Zimmer Air Dermatome','measured_thickness_mm',
     0.50,0.55,10.0,false,8.0,'2026-06-18',null,'P. Singh','conditional_pass','Thickness slightly over tolerance — monitor'),
    ('AIIMS Delhi','MSH-AIM-32','Humeca Mesher','width_accuracy_mm',
     76.0,74.5,-2.0,true,5.0,'2026-06-18','2026-12-18','P. Singh','pass','Graft width within spec'),
    ('CMC Vellore','DRM-CMC-41','Padgett Electric Dermatome','blade_sharpness',
     100.0,88.0,-12.0,true,20.0,'2026-06-15','2026-12-15','J. Thomas','pass','Blade acceptable, monitor at next PM'),
    ('CMC Vellore','DRM-CMC-42','Zimmer Air Dermatome','set_thickness_mm',
     0.20,0.20,0.0,true,10.0,'2026-06-15','2026-12-15','J. Thomas','pass','Fine graft setting verified'),
    ('KIMS Hyderabad','DRM-KIM-51','Aesculap Acculan 3Ti','oscillation_rpm',
     4500.0,4200.0,-6.7,false,5.0,'2026-06-12',null,'V. Reddy','conditional_pass','RPM below band — service motor'),
    ('KIMS Hyderabad','MSH-KIM-52','Zimmer Skin Graft Mesher','mesh_ratio',
     3.0,2.6,-13.3,false,8.0,'2026-06-12',null,'V. Reddy','fail','Mesh roller worn — ratio off spec'),
    ('Yashoda Hyderabad','DRM-YSH-61','Humeca D80 Dermatome','width_accuracy_mm',
     100.0,99.0,-1.0,true,5.0,'2026-06-10','2026-12-10','K. Naidu','pass','Width accuracy nominal'),
    ('Kokilaben Mumbai','DRM-KKB-71','Nouvag Dermatome','measured_thickness_mm',
     0.60,0.72,20.0,false,10.0,'2026-05-24',null,'D. Shah','fail','Depth gauge grossly off — removed pending calibration'),
    ('Kokilaben Mumbai','DRM-KKB-72','Padgett Electric Dermatome','blade_sharpness',
     100.0,95.0,-5.0,true,20.0,'2026-05-22','2026-11-22','D. Shah','pass','Blade sharp'),
    ('Apollo Chennai','MSH-APL-03','Humeca Mesher','width_accuracy_mm',
     76.0,79.0,3.9,true,5.0,'2026-07-05','2027-01-05','S. Kumar','pass','Mesher width verified')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, tolband, caldate, nextcal, tech, qv, nt);

  -- CAPA seed — attach to specific checks via device_code (all unique codes)
  insert into public.dermatome_qc_capa_actions_r3510 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DRM-FRT-11','thickness_out_of_tolerance','depth_gauge_miscalibration','recalibrate_depth_gauge','in_progress','iso_13485_deviation','2026-07-10',null,6500.00,'Depth gauge recalibration scheduled'),
    ('DRM-MNP-21','blade_dull','blade_wear','replace_blade','open','nabh_finding','2026-07-08',null,3500.00,'Blade sharpness index low — replacement blade ordered'),
    ('DRM-AIM-31','thickness_out_of_tolerance','depth_gauge_miscalibration','recalibrate_depth_gauge','verification_pending','internal_only','2026-07-06',null,5000.00,'Depth gauge adjusted — verify on next graft'),
    ('DRM-KIM-51','oscillation_rpm_out_of_tolerance','motor_wear','service_motor','escalated','patient_safety_alert','2026-07-05',null,22000.00,'RPM below tolerance — motor service escalated to OEM'),
    ('MSH-KIM-52','mesh_ratio_deviation','mesh_roller_worn','replace_mesh_roller','open','cdsco_notifiable','2026-07-04',null,18000.00,'Mesh roller worn — ratio off spec, replacement ordered'),
    ('DRM-KKB-71','thickness_out_of_tolerance','depth_gauge_miscalibration','remove_from_service','closed','iso_13485_deviation','2026-07-02','2026-06-30',12000.00,'Removed and recalibrated — validated back in service'),
    ('DRM-CMC-41','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,4000.00,'Blade PM overdue — vendor delay'),
    ('MSH-AIM-32','calibration_overdue','preventive_service_backlog','schedule_oem_service','open','none','2026-07-12',null,4000.00,'Annual calibration due — OEM visit scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.dermatome_qc_r3510 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3510_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dermatome_qc_r3510)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dermatome_qc_r3510 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3510_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3510_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3510_device_model_scorecard()
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
  from public.dermatome_qc_r3510 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3510_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3510_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3510_parameter_verdict_matrix()
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
  from public.dermatome_qc_r3510 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3510_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3510_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3510_monthly_calibration_trend()
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
  from public.dermatome_qc_r3510 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3510_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3510_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3510_capa_status_board()
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
  from public.dermatome_qc_capa_actions_r3510 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3510_capa_status_board() from public, anon;
grant execute on function public.founder_r3510_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3510_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dermatome_qc_capa_actions_r3510)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dermatome_qc_capa_actions_r3510 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3510_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3510_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (deviation severity bands)
create or replace function public.founder_r3510_accuracy_impact_digest()
returns table(accuracy_band text, checks bigint, out_of_tolerance bigint, flagged bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when l.deviation_pct is null then 'unknown'
      when abs(l.deviation_pct) <= 2 then 'within_2pct'
      when abs(l.deviation_pct) <= 5 then 'band_2_to_5pct'
      when abs(l.deviation_pct) <= 10 then 'band_5_to_10pct'
      else 'over_10pct'
    end,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict in ('fail','conditional_pass'))::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.dermatome_qc_r3510 l
  group by 1
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3510_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3510_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3510_high_risk_queue()
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
  from public.dermatome_qc_r3510 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or abs(coalesce(l.deviation_pct,0)) > 10
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3510_high_risk_queue() from public, anon;
grant execute on function public.founder_r3510_high_risk_queue() to authenticated;
