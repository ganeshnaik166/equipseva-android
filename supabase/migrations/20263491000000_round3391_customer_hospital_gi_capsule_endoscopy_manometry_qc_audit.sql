-- Round 3391: Customer Hospital GI Capsule-Endoscopy & Motility (Manometry) QC Audit
-- GI diagnostics QA — device type × department × sensor cal × pressure accuracy × battery × data download × probe × image capture × reference cal × hygiene × CAPA

-- =============================================================================
-- TABLE 1: gi_motility_qc_r3391 — per-device QC checks
-- =============================================================================
create table if not exists public.gi_motility_qc_r3391 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'capsule_endoscopy_recorder','esophageal_manometry','anorectal_manometry',
    'ph_impedance_recorder','gastric_emptying_analyzer','breath_test_analyzer'
  )),
  department text not null,
  check_date date not null,
  sensor_calibration_ok boolean not null,
  pressure_channel_accuracy_error_pct numeric(5,2),
  recorder_battery_ok boolean not null,
  data_download_ok boolean not null,
  catheter_probe_condition text not null check (catheter_probe_condition in (
    'good','worn','damaged','replace_due','not_applicable'
  )),
  image_capture_ok text not null check (image_capture_ok in (
    'ok','degraded','fail','not_applicable'
  )),
  reference_calibration_ok boolean not null,
  hygiene_disinfection_ok boolean not null,
  software_version_current boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gi_motility_qc_r3391 enable row level security;

create index if not exists idx_gi_motility_qc_r3391_org on public.gi_motility_qc_r3391(organization_id);
create index if not exists idx_gi_motility_qc_r3391_date on public.gi_motility_qc_r3391(check_date);
create index if not exists idx_gi_motility_qc_r3391_verdict on public.gi_motility_qc_r3391(qc_verdict);

-- =============================================================================
-- TABLE 2: gi_motility_qc_capa_actions_r3391 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.gi_motility_qc_capa_actions_r3391 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.gi_motility_qc_r3391(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sensor_calibration_drift','pressure_accuracy_out_of_tolerance','battery_depleted',
    'data_download_failure','probe_damaged','image_capture_degraded',
    'reference_calibration_failure','hygiene_failure','software_outdated','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_drift','catheter_end_of_life','battery_end_of_life','connectivity_fault',
    'improper_handling','reprocessing_error','software_update_pending','operator_setup_error',
    'pending_investigation','preventive_service_backlog','optics_degraded'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_sensor','replace_catheter_probe','replace_battery','repair_connectivity',
    'requalify_reprocessing','apply_software_update','recalibrate','retrain_gi_staff',
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

alter table public.gi_motility_qc_capa_actions_r3391 enable row level security;

create index if not exists idx_gi_motility_capa_r3391_log on public.gi_motility_qc_capa_actions_r3391(qc_log_id);
create index if not exists idx_gi_motility_capa_r3391_status on public.gi_motility_qc_capa_actions_r3391(capa_status);

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

  insert into public.gi_motility_qc_r3391 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    sensor_calibration_ok, pressure_channel_accuracy_error_pct, recorder_battery_ok, data_download_ok,
    catheter_probe_condition, image_capture_ok, reference_calibration_ok,
    hygiene_disinfection_ok, software_version_current, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.sensorcal, q.perr, q.batt, q.download,
    q.probe, q.img, q.refcal,
    q.hyg, q.swver, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','GI-APL-01','capsule_endoscopy_recorder','gastroenterology','2026-07-03',
     true,null,true,true,'not_applicable','ok',true,true,true,true,'pass','Quarterly QC — capsule recorder image capture and download nominal'),
    ('Apollo Chennai','GI-APL-02','esophageal_manometry','gastroenterology','2026-07-03',
     true,1.2,true,true,'good','not_applicable',true,true,true,true,'pass','High-resolution esophageal manometry channels within tolerance'),
    ('Fortis Gurgaon','GI-FRT-11','anorectal_manometry','gastroenterology','2026-07-02',
     true,3.6,true,true,'worn','not_applicable',true,true,true,true,'conditional_pass','Anorectal manometry pressure error 3.6% and catheter worn — recheck booked'),
    ('Fortis Gurgaon','GI-FRT-12','ph_impedance_recorder','gastroenterology','2026-07-02',
     false,null,false,false,'damaged','not_applicable',false,true,true,true,'fail','Sensor-cal failed, battery weak, download and reference-cal failed'),
    ('Manipal Bengaluru','GI-MNP-21','capsule_endoscopy_recorder','gastroenterology','2026-07-01',
     true,null,true,true,'not_applicable','degraded',true,true,false,false,'conditional_pass','Capsule image capture degraded, software update and calibration overdue'),
    ('Manipal Bengaluru','GI-MNP-22','breath_test_analyzer','gastroenterology','2026-07-01',
     true,null,true,true,'not_applicable','not_applicable',true,true,true,true,'pass','Urea breath-test analyser QC nominal'),
    ('AIIMS Delhi','GI-AIM-31','esophageal_manometry','gastroenterology','2026-06-30',
     true,1.8,true,true,'good','not_applicable',true,true,true,true,'conditional_pass','Manometry accuracy 1.8% within limit but drift trend flagged'),
    ('AIIMS Delhi','GI-AIM-32','gastric_emptying_analyzer','nuclear_medicine','2026-06-30',
     true,null,false,true,'not_applicable','not_applicable',true,false,true,true,'fail','Recorder battery failed and hygiene log missing — pulled'),
    ('CMC Vellore','GI-CMC-41','anorectal_manometry','gastroenterology','2026-06-29',
     true,0.9,true,true,'good','not_applicable',true,true,true,true,'pass','Anorectal manometry QC pass'),
    ('CMC Vellore','GI-CMC-42','ph_impedance_recorder','gastroenterology','2026-06-29',
     true,null,true,true,'replace_due','not_applicable',true,true,true,false,'conditional_pass','pH-impedance catheter replace-due and calibration overdue — plan swap'),
    ('KIMS Hyderabad','GI-KIM-51','capsule_endoscopy_recorder','gastroenterology','2026-06-28',
     true,null,true,true,'not_applicable','ok',true,true,true,true,'pass','Capsule recorder QC pass post-AMC'),
    ('KIMS Hyderabad','GI-KIM-52','esophageal_manometry','gastroenterology','2026-06-28',
     true,2.1,true,true,'worn','not_applicable',true,true,true,true,'conditional_pass','Manometry catheter worn, accuracy 2.1% — monitor and plan catheter change'),
    ('Yashoda Hyderabad','GI-YSH-61','breath_test_analyzer','gastroenterology','2026-06-27',
     true,null,true,true,'not_applicable','not_applicable',true,true,true,true,'pass','Breath-test analyser QC nominal'),
    ('Kokilaben Mumbai','GI-KKB-71','ph_impedance_recorder','gastroenterology','2026-06-27',
     false,null,false,false,'damaged','not_applicable',false,false,false,false,'removed_from_service','Multiple failures across sensor, battery, download and hygiene — removed')
  ) as q(hosp, dcode, dtype, dept, cdate, sensorcal, perr, batt, download, probe, img, refcal, hyg, swver, calcur, qv, nt);

  insert into public.gi_motility_qc_capa_actions_r3391 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('GI-FRT-12','sensor_calibration_drift','sensor_drift','recalibrate_sensor','in_progress','iso_13485_deviation','2026-07-06',null,18000.00,'pH sensor recalibration; battery and connectivity checks after'),
    ('GI-MNP-21','image_capture_degraded','optics_degraded','apply_software_update','open','internal_only','2026-07-05',null,9000.00,'Capsule recorder firmware update queued; recheck capture'),
    ('GI-AIM-32','battery_depleted','battery_end_of_life','replace_battery','escalated','patient_safety_alert','2026-07-04',null,11000.00,'Recorder battery and hygiene lapse escalated'),
    ('GI-KKB-71','sensor_calibration_drift','catheter_end_of_life','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',36000.00,'Recorder removed; catheter set replaced and revalidated'),
    ('GI-FRT-11','pressure_accuracy_out_of_tolerance','catheter_end_of_life','replace_catheter_probe','verification_pending','internal_only','2026-07-05',null,22000.00,'Manometry catheter replaced — verify accuracy next study'),
    ('GI-CMC-42','calibration_overdue','software_update_pending','recalibrate','overdue','internal_only','2026-06-30',null,7500.00,'pH-impedance calibration past target — vendor delay'),
    ('GI-KIM-52','probe_damaged','improper_handling','replace_catheter_probe','open','none','2026-07-07',null,20000.00,'Worn manometry catheter replacement ordered; handling retrain')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.gi_motility_qc_r3391 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3391_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gi_motility_qc_r3391)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gi_motility_qc_r3391 l group by l.qc_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3391_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3391_qc_verdict_rollup() to authenticated;

create or replace function public.founder_r3391_hospital_scorecard()
returns table(
  hospital_name text, total_checks bigint, passed bigint, conditional bigint, failed bigint,
  download_fail bigint, battery_issue bigint, calibration_overdue bigint, pass_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.data_download_ok = false)::bigint,
    count(*) filter (where l.recorder_battery_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.gi_motility_qc_r3391 l group by l.hospital_name order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3391_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3391_hospital_scorecard() to authenticated;

create or replace function public.founder_r3391_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, avg_pressure_error_pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.pressure_channel_accuracy_error_pct), 2)
  from public.gi_motility_qc_r3391 l group by l.device_type, l.department order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3391_device_department_matrix() from public, anon;
grant execute on function public.founder_r3391_device_department_matrix() to authenticated;

create or replace function public.founder_r3391_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, download_fail bigint, battery_issue bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.data_download_ok = false)::bigint,
    count(*) filter (where l.recorder_battery_ok = false)::bigint
  from public.gi_motility_qc_r3391 l group by l.check_date order by l.check_date desc;
end;
$$;
revoke execute on function public.founder_r3391_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3391_daily_qc_trend() to authenticated;

create or replace function public.founder_r3391_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.gi_motility_qc_capa_actions_r3391 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3391_capa_status_board() from public, anon;
grant execute on function public.founder_r3391_capa_status_board() to authenticated;

create or replace function public.founder_r3391_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gi_motility_qc_capa_actions_r3391)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gi_motility_qc_capa_actions_r3391 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3391_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3391_root_cause_pareto() to authenticated;

create or replace function public.founder_r3391_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.gi_motility_qc_capa_actions_r3391 c group by c.regulatory_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3391_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3391_regulatory_impact_digest() to authenticated;

create or replace function public.founder_r3391_high_risk_queue()
returns table(
  hospital_name text, device_code text, device_type text, department text, check_date date,
  qc_verdict text, catheter_probe_condition text, image_capture_ok text, pressure_channel_accuracy_error_pct numeric, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.catheter_probe_condition, l.image_capture_ok, l.pressure_channel_accuracy_error_pct, l.notes
  from public.gi_motility_qc_r3391 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.sensor_calibration_ok = false
     or l.recorder_battery_ok = false
     or l.data_download_ok = false
     or l.catheter_probe_condition in ('worn','damaged','replace_due')
     or l.image_capture_ok in ('degraded','fail')
     or l.reference_calibration_ok = false
     or l.hygiene_disinfection_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;
revoke execute on function public.founder_r3391_high_risk_queue() from public, anon;
grant execute on function public.founder_r3391_high_risk_queue() to authenticated;
