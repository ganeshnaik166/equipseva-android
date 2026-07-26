-- Round 3459: Customer Hospital Video Laryngoscope (Airway Management) QC Audit
-- Video laryngoscope airway-management QA — camera/light/battery/blade/display parameter checks
-- × reference vs measured × deviation × tolerance × verdict × device model × CAPA closure

-- =============================================================================
-- TABLE 1: video_laryngoscope_qc_r3459 — per-parameter video laryngoscope QC checks
-- =============================================================================
create table if not exists public.video_laryngoscope_qc_r3459 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','light_output_lux','battery_runtime_min',
    'anti_fog_ok','display_latency_ms','blade_integrity'
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

alter table public.video_laryngoscope_qc_r3459 enable row level security;

create index if not exists idx_video_laryngoscope_qc_r3459_org on public.video_laryngoscope_qc_r3459(organization_id);
create index if not exists idx_video_laryngoscope_qc_r3459_cal on public.video_laryngoscope_qc_r3459(calibration_date);
create index if not exists idx_video_laryngoscope_qc_r3459_verdict on public.video_laryngoscope_qc_r3459(qc_verdict);

-- =============================================================================
-- TABLE 2: video_laryngoscope_qc_capa_actions_r3459 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.video_laryngoscope_qc_capa_actions_r3459 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.video_laryngoscope_qc_r3459(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_resolution_low','light_output_low','battery_runtime_short','anti_fog_failure',
    'display_latency_high','blade_damage','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'camera_module_degraded','led_module_aging','battery_end_of_life','anti_fog_coating_worn',
    'display_board_fault','blade_wear','firmware_config_error','operator_handling_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_camera_module','replace_led_module','replace_battery','recoat_anti_fog',
    'replace_display_board','replace_blade','update_firmware','retrain_airway_staff',
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

alter table public.video_laryngoscope_qc_capa_actions_r3459 enable row level security;

create index if not exists idx_video_laryngoscope_capa_r3459_log on public.video_laryngoscope_qc_capa_actions_r3459(qc_log_id);
create index if not exists idx_video_laryngoscope_capa_r3459_status on public.video_laryngoscope_qc_capa_actions_r3459(capa_status);

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

  -- 16 QC parameter-check rows
  insert into public.video_laryngoscope_qc_r3459 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','VL-APL-01','C-MAC','image_resolution',
     720,720,0.0,true,'2026-07-05','pass','C-MAC image resolution 720 TV lines within spec'),
    ('Apollo Chennai','VL-APL-02','GlideScope','light_output_lux',
     3500,3460,-1.1,true,'2026-07-05','pass','GlideScope light output 3460 lux within tolerance'),
    ('Fortis Gurgaon','VL-FRT-11','McGrath MAC','battery_runtime_min',
     90,78,-13.3,false,'2026-07-04','conditional_pass','McGrath battery runtime degraded to 78 min — battery aging'),
    ('Fortis Gurgaon','VL-FRT-12','C-MAC','anti_fog_ok',
     5,14,180.0,false,'2026-07-04','fail','Anti-fog clear time 14s vs 5s spec — coating worn'),
    ('Manipal Bengaluru','VL-MNP-21','King Vision','display_latency_ms',
     60,61,1.7,true,'2026-07-03','pass','King Vision display latency 61ms within limit'),
    ('Manipal Bengaluru','VL-MNP-22','Airtraq','blade_integrity',
     100,100,0.0,true,'2026-07-03','pass','Airtraq disposable blade integrity intact'),
    ('AIIMS Delhi','VL-AIM-31','GlideScope','image_resolution',
     1080,1040,-3.7,true,'2026-07-02','conditional_pass','GlideScope resolution slightly reduced — camera module monitor'),
    ('AIIMS Delhi','VL-AIM-32','C-MAC','light_output_lux',
     3500,2900,-17.1,false,'2026-07-02','fail','C-MAC light output 2900 lux — LED module degraded'),
    ('CMC Vellore','VL-CMC-41','McGrath MAC','display_latency_ms',
     60,95,58.3,false,'2026-07-01','fail','McGrath display latency 95ms — display board fault'),
    ('CMC Vellore','VL-CMC-42','King Vision','battery_runtime_min',
     120,118,-1.7,true,'2026-07-01','pass','King Vision battery runtime nominal'),
    ('KIMS Hyderabad','VL-KIM-51','C-MAC','anti_fog_ok',
     5,5,0.0,true,'2026-06-30','pass','C-MAC anti-fog clears in 5s — pass'),
    ('KIMS Hyderabad','VL-KIM-52','Airtraq','blade_integrity',
     100,72,-28.0,false,'2026-06-30','conditional_pass','Airtraq blade optics scratched — score 72, replacement ordered'),
    ('Yashoda Hyderabad','VL-YSH-61','GlideScope','battery_runtime_min',
     90,88,-2.2,true,'2026-06-29','pass','GlideScope battery runtime within spec'),
    ('Yashoda Hyderabad','VL-YSH-62','McGrath MAC','image_resolution',
     720,640,-11.1,false,'2026-06-29','fail','McGrath resolution dropped to 640 lines — camera degraded'),
    ('Kokilaben Mumbai','VL-KKB-71','C-MAC','display_latency_ms',
     60,66,10.0,true,'2026-06-28','conditional_pass','C-MAC latency 66ms borderline — firmware update advised'),
    ('Kokilaben Mumbai','VL-KKB-72','King Vision','light_output_lux',
     3500,3520,0.6,true,'2026-06-28','pass','King Vision light output nominal post-service')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- 8 CAPA rows — attach to specific checks via device_code
  insert into public.video_laryngoscope_qc_capa_actions_r3459 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('VL-FRT-12','anti_fog_failure','anti_fog_coating_worn','recoat_anti_fog','in_progress','internal_only','2026-07-10',null,6500.00,'Anti-fog coating reapplied — verify clear time next case'),
    ('VL-AIM-32','light_output_low','led_module_aging','replace_led_module','open','iso_13485_deviation','2026-07-09',null,28000.00,'LED illumination module replacement scheduled'),
    ('VL-CMC-41','display_latency_high','display_board_fault','replace_display_board','escalated','patient_safety_alert','2026-07-08',null,42000.00,'High latency risk during intubation — escalated to OEM'),
    ('VL-YSH-62','image_resolution_low','camera_module_degraded','replace_camera_module','closed','cdsco_notifiable','2026-07-06','2026-07-04',55000.00,'Camera module replaced and resolution validated'),
    ('VL-FRT-11','battery_runtime_short','battery_end_of_life','replace_battery','verification_pending','internal_only','2026-07-11',null,9500.00,'Battery pack replaced — verify runtime on next charge cycle'),
    ('VL-KIM-52','blade_damage','blade_wear','replace_blade','open','nabh_finding','2026-07-12',null,12000.00,'Scratched blade optics — replacement blade set ordered'),
    ('VL-KKB-71','display_latency_high','firmware_config_error','update_firmware','overdue','internal_only','2026-07-02',null,0.00,'Firmware update to reduce latency past target date — vendor delay'),
    ('VL-AIM-31','calibration_overdue','preventive_service_backlog','schedule_oem_service','open','none','2026-07-14',null,15000.00,'Camera degradation trend — OEM preventive service scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.video_laryngoscope_qc_r3459 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3459_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.video_laryngoscope_qc_r3459)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.video_laryngoscope_qc_r3459 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3459_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3459_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3459_device_model_scorecard()
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
  from public.video_laryngoscope_qc_r3459 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3459_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3459_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3459_parameter_verdict_matrix()
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
  from public.video_laryngoscope_qc_r3459 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3459_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3459_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3459_monthly_calibration_trend()
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
  from public.video_laryngoscope_qc_r3459 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3459_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3459_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3459_capa_status_board()
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
  from public.video_laryngoscope_qc_capa_actions_r3459 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3459_capa_status_board() from public, anon;
grant execute on function public.founder_r3459_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3459_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.video_laryngoscope_qc_capa_actions_r3459)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.video_laryngoscope_qc_capa_actions_r3459 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3459_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3459_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter deviation impact)
create or replace function public.founder_r3459_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  failed bigint,
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.video_laryngoscope_qc_r3459 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3459_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3459_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3459_high_risk_queue()
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
  from public.video_laryngoscope_qc_r3459 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.within_tolerance asc, abs(l.deviation_pct) desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3459_high_risk_queue() from public, anon;
grant execute on function public.founder_r3459_high_risk_queue() to authenticated;
