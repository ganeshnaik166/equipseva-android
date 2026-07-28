-- Round 3567: Customer Hospital Mediastinoscope Endoscope QC Audit
-- Mediastinoscope endoscope imaging QC — parameter × device model × reference vs measured × deviation × tolerance × channel leak × light output × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: mediastinoscope_qc_r3567 — per-device imaging QC checks
-- =============================================================================
create table if not exists public.mediastinoscope_qc_r3567 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','light_transmission','viewing_angle_deg',
    'color_fidelity','focus_clarity','seal_leak_test'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  channel_leak_pass boolean not null,
  light_output_ok boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mediastinoscope_qc_r3567 enable row level security;

create index if not exists idx_mediastinoscope_qc_r3567_org on public.mediastinoscope_qc_r3567(organization_id);
create index if not exists idx_mediastinoscope_qc_r3567_date on public.mediastinoscope_qc_r3567(calibration_date);
create index if not exists idx_mediastinoscope_qc_r3567_verdict on public.mediastinoscope_qc_r3567(qc_verdict);

-- =============================================================================
-- TABLE 2: mediastinoscope_qc_capa_actions_r3567 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.mediastinoscope_qc_capa_actions_r3567 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.mediastinoscope_qc_r3567(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_resolution_out_of_tolerance','light_transmission_low','viewing_angle_deviation',
    'color_fidelity_drift','focus_clarity_degraded','seal_leak_detected',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lens_scratched','fiber_optic_bundle_damaged','light_source_aged','ccd_sensor_degraded',
    'seal_gasket_worn','objective_lens_misaligned','operator_handling_damage',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'polish_or_replace_lens','replace_fiber_bundle','replace_light_source','replace_ccd_module',
    'replace_seal_gasket','realign_optics','retrain_ot_staff',
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

alter table public.mediastinoscope_qc_capa_actions_r3567 enable row level security;

create index if not exists idx_mediastinoscope_capa_r3567_log on public.mediastinoscope_qc_capa_actions_r3567(qc_log_id);
create index if not exists idx_mediastinoscope_capa_r3567_status on public.mediastinoscope_qc_capa_actions_r3567(capa_status);

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

  -- 15 QC check rows
  insert into public.mediastinoscope_qc_r3567 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    channel_leak_pass, light_output_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.leak, q.light, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','MED-APL-01','Storz 10970','image_resolution',
     15,14.6,-2.67,true,true,true,'2026-07-05','pass','Rigid mediastinoscope resolution target chart within tolerance'),
    ('Apollo Chennai','MED-APL-02','Storz 10970','light_transmission',
     100,94,-6.0,true,true,true,'2026-07-05','pass','Light transmission nominal across fiber bundle'),
    ('Fortis Gurgaon','MED-FRT-11','Wolf 8654','seal_leak_test',
     0,0.1,null,true,true,true,'2026-07-04','pass','Channel seal leak rate within spec'),
    ('Fortis Gurgaon','MED-FRT-12','Wolf 8654','image_resolution',
     15,11.2,-25.33,false,true,true,'2026-07-04','fail','Resolution well below spec — objective lens scratched'),
    ('Manipal Bengaluru','MED-MNP-21','Olympus WA','color_fidelity',
     100,91,-9.0,true,true,true,'2026-07-02','conditional_pass','Colour fidelity drift flagged for recheck'),
    ('Manipal Bengaluru','MED-MNP-22','Olympus WA','focus_clarity',
     100,97,-3.0,true,true,true,'2026-07-02','pass','Focus clarity within tolerance'),
    ('AIIMS Delhi','MED-AIM-31','Storz 10970','light_transmission',
     100,78,-22.0,false,true,false,'2026-06-30','fail','Light transmission low — fiber optic bundle damaged'),
    ('AIIMS Delhi','MED-AIM-32','Storz 10970','viewing_angle_deg',
     50,48,-4.0,true,true,true,'2026-06-30','pass','Viewing angle within tolerance'),
    ('CMC Vellore','MED-CMC-41','Wolf 8654','seal_leak_test',
     0,0.9,null,false,false,true,'2026-06-29','fail','Channel seal leak exceeds limit — gasket worn'),
    ('CMC Vellore','MED-CMC-42','Wolf 8654','color_fidelity',
     100,95,-5.0,true,true,true,'2026-06-29','pass','Colour fidelity within tolerance'),
    ('KIMS Hyderabad','MED-KIM-51','Stryker 1588','focus_clarity',
     100,88,-12.0,false,true,true,'2026-06-28','conditional_pass','Focus clarity degraded — optics realign scheduled'),
    ('KIMS Hyderabad','MED-KIM-52','Stryker 1588','image_resolution',
     15,14.9,-0.67,true,true,true,'2026-06-28','pass','Resolution within tolerance post-service'),
    ('Yashoda Hyderabad','MED-YSH-61','Olympus WA','viewing_angle_deg',
     50,44,-12.0,false,true,true,'2026-06-27','conditional_pass','Viewing angle deviation flagged for recheck'),
    ('Kokilaben Mumbai','MED-KKB-71','Storz 10970','light_transmission',
     100,65,-35.0,false,false,false,'2026-06-27','fail','Severe light loss and channel leak — removed from OT'),
    ('Kokilaben Mumbai','MED-KKB-72','Storz 10970','image_resolution',
     15,13.8,-8.0,true,true,true,'2026-06-27','pass','Resolution within tolerance')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, leak, light, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.mediastinoscope_qc_capa_actions_r3567 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MED-FRT-12','image_resolution_out_of_tolerance','lens_scratched','polish_or_replace_lens','in_progress','iso_13485_deviation','2026-07-08',null,28000.00,'Objective lens scratched — polish/replace in progress'),
    ('MED-AIM-31','light_transmission_low','fiber_optic_bundle_damaged','replace_fiber_bundle','escalated','patient_safety_alert','2026-07-06',null,65000.00,'Fiber bundle damaged — escalated to OEM'),
    ('MED-CMC-41','seal_leak_detected','seal_gasket_worn','replace_seal_gasket','open','nabh_finding','2026-07-05',null,9500.00,'Channel seal gasket worn — replacement kit ordered'),
    ('MED-KKB-71','light_transmission_low','fiber_optic_bundle_damaged','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-29',72000.00,'Scope removed from service; loaner deployed and validated'),
    ('MED-MNP-21','color_fidelity_drift','ccd_sensor_degraded','replace_ccd_module','verification_pending','internal_only','2026-07-06',null,41000.00,'CCD module replaced — verify colour chart next case'),
    ('MED-KIM-51','focus_clarity_degraded','objective_lens_misaligned','realign_optics','overdue','internal_only','2026-07-01',null,12000.00,'Optics realignment past target — vendor delay'),
    ('MED-YSH-61','viewing_angle_deviation','operator_handling_damage','retrain_ot_staff','open','none','2026-07-09',null,0.00,'Handling damage — OT staff retraining scheduled'),
    ('MED-FRT-11','calibration_overdue','preventive_service_backlog','schedule_oem_service','closed','internal_only','2026-06-30','2026-06-29',6000.00,'Preventive service completed on schedule')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.mediastinoscope_qc_r3567 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3567_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mediastinoscope_qc_r3567)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mediastinoscope_qc_r3567 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3567_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3567_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3567_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  leak_fail bigint,
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
    count(*) filter (where l.channel_leak_pass = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.mediastinoscope_qc_r3567 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3567_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3567_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3567_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.mediastinoscope_qc_r3567 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3567_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3567_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3567_monthly_accuracy_trend()
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
  from public.mediastinoscope_qc_r3567 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3567_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3567_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3567_capa_status_board()
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
  from public.mediastinoscope_qc_capa_actions_r3567 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3567_capa_status_board() from public, anon;
grant execute on function public.founder_r3567_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3567_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mediastinoscope_qc_capa_actions_r3567)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mediastinoscope_qc_capa_actions_r3567 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3567_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3567_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by regulatory impact)
create or replace function public.founder_r3567_accuracy_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.mediastinoscope_qc_capa_actions_r3567 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3567_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3567_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail)
create or replace function public.founder_r3567_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  within_tolerance boolean,
  channel_leak_pass boolean,
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
    l.qc_verdict, l.deviation_pct, l.within_tolerance, l.channel_leak_pass, l.notes
  from public.mediastinoscope_qc_r3567 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.channel_leak_pass = false
     or l.light_output_ok = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3567_high_risk_queue() from public, anon;
grant execute on function public.founder_r3567_high_risk_queue() to authenticated;
