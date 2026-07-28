-- Round 3530: Customer Hospital Vein-Finder / Vein-Viewer (Infrared) QC Audit
-- Vein finder / vein viewer (infrared/transillumination) QC — device model × parameter × reference vs measured
-- × deviation × tolerance × calibration date × verdict × CAPA closure (light output, contrast, depth, battery)

-- =============================================================================
-- TABLE 1: vein_finder_qc_r3530 — per-device infrared vein-finder QC measurements
-- =============================================================================
create table if not exists public.vein_finder_qc_r3530 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'ir_light_output','image_contrast','projection_alignment_mm',
    'depth_penetration_mm','battery_runtime_min','resolution'
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

alter table public.vein_finder_qc_r3530 enable row level security;

create index if not exists idx_vein_finder_qc_r3530_org on public.vein_finder_qc_r3530(organization_id);
create index if not exists idx_vein_finder_qc_r3530_caldate on public.vein_finder_qc_r3530(calibration_date);
create index if not exists idx_vein_finder_qc_r3530_verdict on public.vein_finder_qc_r3530(qc_verdict);

-- =============================================================================
-- TABLE 2: vein_finder_qc_capa_actions_r3530 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.vein_finder_qc_capa_actions_r3530 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.vein_finder_qc_r3530(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ir_light_output_low','image_contrast_degraded','projection_misalignment',
    'depth_penetration_shortfall','battery_runtime_short','resolution_degraded',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'led_array_degraded','ir_sensor_drift','optics_misaligned','battery_end_of_life',
    'lens_contamination','projector_module_fault','firmware_config_error',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_led_array','recalibrate_ir_sensor','realign_optics','replace_battery_pack',
    'clean_lens_optics','replace_projector_module','update_firmware','retrain_clinical_staff',
    'remove_from_service','schedule_oem_service','none_required'
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

alter table public.vein_finder_qc_capa_actions_r3530 enable row level security;

create index if not exists idx_vein_finder_capa_r3530_log on public.vein_finder_qc_capa_actions_r3530(qc_log_id);
create index if not exists idx_vein_finder_capa_r3530_status on public.vein_finder_qc_capa_actions_r3530(capa_status);

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

  -- 16 QC measurement rows
  insert into public.vein_finder_qc_r3530 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.dev, q.wtol,
    q.caldt::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','VF-APL-01','AccuVein AV500','ir_light_output',
     100,98.5,-1.5,true,'2026-07-05','pass','IR light output within 2% of reference'),
    ('Apollo Chennai','VF-APL-02','AccuVein AV500','image_contrast',
     5.0,4.9,-2.0,true,'2026-07-05','pass','Vein-to-background contrast nominal'),
    ('Fortis Gurgaon','VF-FRT-11','VeinViewer Flex','projection_alignment_mm',
     0.0,0.4,0.4,true,'2026-07-04','pass','Projection registration offset within 0.5 mm'),
    ('Fortis Gurgaon','VF-FRT-12','VeinViewer Flex','depth_penetration_mm',
     10.0,8.2,-18.0,false,'2026-07-04','conditional_pass','Depth penetration reduced — recheck after lens clean'),
    ('Manipal Bengaluru','VF-MNP-21','AccuVein AV400','battery_runtime_min',
     180,132,-26.7,false,'2026-07-03','fail','Battery runtime well below spec — pack aged'),
    ('Manipal Bengaluru','VF-MNP-22','AccuVein AV400','ir_light_output',
     100,82,-18.0,false,'2026-07-03','fail','IR LED array output degraded beyond tolerance'),
    ('AIIMS Delhi','VF-AIM-31','VeinViewer Vision2','resolution',
     5.0,4.6,-8.0,false,'2026-06-30','conditional_pass','Resolution slightly low — projector focus adjusted'),
    ('AIIMS Delhi','VF-AIM-32','VeinViewer Vision2','image_contrast',
     5.0,4.95,-1.0,true,'2026-06-30','pass','Contrast within tolerance'),
    ('CMC Vellore','VF-CMC-41','AccuVein AV500','projection_alignment_mm',
     0.0,1.2,1.2,false,'2026-06-29','fail','Projection misaligned 1.2 mm — optics realignment needed'),
    ('CMC Vellore','VF-CMC-42','AccuVein AV500','depth_penetration_mm',
     10.0,9.6,-4.0,true,'2026-06-29','pass','Depth penetration nominal'),
    ('KIMS Hyderabad','VF-KIM-51','Wee-Sight','battery_runtime_min',
     120,110,-8.3,true,'2026-06-28','conditional_pass','Battery runtime marginal — monitor next cycle'),
    ('KIMS Hyderabad','VF-KIM-52','Wee-Sight','resolution',
     4.0,3.9,-2.5,true,'2026-06-28','pass','Resolution within tolerance'),
    ('Yashoda Hyderabad','VF-YSH-61','VeinViewer Flex','ir_light_output',
     100,97,-3.0,true,'2026-06-27','pass','IR output nominal post-service'),
    ('Kokilaben Mumbai','VF-KKB-71','AccuVein AV400','image_contrast',
     5.0,3.6,-28.0,false,'2026-06-27','fail','Contrast poor — sensor drift, unit removed for service'),
    ('Kokilaben Mumbai','VF-KKB-72','AccuVein AV400','depth_penetration_mm',
     10.0,7.0,-30.0,false,'2026-06-26','fail','Depth penetration severely reduced — optics contamination'),
    ('Narayana Bengaluru','VF-NAR-81','VeinViewer Vision2','projection_alignment_mm',
     0.0,0.3,0.3,true,'2026-06-26','pass','Projection alignment within spec')
  ) as q(hosp, dcode, dmodel, param, refv, measv, dev, wtol, caldt, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.vein_finder_qc_capa_actions_r3530 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('VF-FRT-12','depth_penetration_shortfall','lens_contamination','clean_lens_optics','verification_pending','internal_only','2026-07-08',null,3000.00,'Lens cleaned — verify depth next QC'),
    ('VF-MNP-21','battery_runtime_short','battery_end_of_life','replace_battery_pack','in_progress','iso_13485_deviation','2026-07-07',null,9500.00,'Battery pack replacement ordered'),
    ('VF-MNP-22','ir_light_output_low','led_array_degraded','replace_led_array','open','nabh_finding','2026-07-07',null,22000.00,'LED array degraded — replacement scheduled'),
    ('VF-AIM-31','resolution_degraded','projector_module_fault','realign_optics','closed','internal_only','2026-07-02','2026-07-01',1500.00,'Projector focus adjusted and verified'),
    ('VF-CMC-41','projection_misalignment','optics_misaligned','realign_optics','escalated','patient_safety_alert','2026-07-04',null,6500.00,'Projection off 1.2 mm — escalated to OEM'),
    ('VF-KKB-71','image_contrast_degraded','ir_sensor_drift','recalibrate_ir_sensor','in_progress','cdsco_notifiable','2026-07-03',null,12000.00,'IR sensor drift — recalibration in progress'),
    ('VF-KKB-72','depth_penetration_shortfall','lens_contamination','clean_lens_optics','closed','internal_only','2026-06-30','2026-06-29',2500.00,'Optics cleaned and re-tested — passed'),
    ('VF-KIM-51','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-01',null,4000.00,'PM overdue — vendor scheduling delay')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.vein_finder_qc_r3530 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3530_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vein_finder_qc_r3530)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vein_finder_qc_r3530 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3530_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3530_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3530_device_model_scorecard()
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
  from public.vein_finder_qc_r3530 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3530_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3530_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3530_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, out_of_tolerance bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.within_tolerance = false)::bigint
  from public.vein_finder_qc_r3530 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3530_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3530_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3530_monthly_accuracy_trend()
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
  from public.vein_finder_qc_r3530 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3530_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3530_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3530_capa_status_board()
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
  from public.vein_finder_qc_capa_actions_r3530 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3530_capa_status_board() from public, anon;
grant execute on function public.founder_r3530_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3530_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vein_finder_qc_capa_actions_r3530)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vein_finder_qc_capa_actions_r3530 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3530_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3530_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3530_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  failed bigint,
  avg_deviation_pct numeric,
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
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.vein_finder_qc_r3530 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3530_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3530_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3530_high_risk_queue()
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
  from public.vein_finder_qc_r3530 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by abs(l.deviation_pct) desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3530_high_risk_queue() from public, anon;
grant execute on function public.founder_r3530_high_risk_queue() to authenticated;
