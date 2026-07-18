-- Round 3315: Customer Hospital Swallow-Study (FEES / Videofluoroscopy) Equipment QC Audit
-- Dysphagia lab QA — device type × scope image quality × light source × fluoroscopy dose × frame rate × recording sync × radiation safety × scope leak test × reprocessing × calibration × CAPA

-- =============================================================================
-- TABLE 1: swallow_study_qc_r3315 — per-device swallow-study equipment QC checks
-- =============================================================================
create table if not exists public.swallow_study_qc_r3315 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'fees_scope','fees_tower','videofluoroscopy_system','swallow_recording_station','barium_prep_station'
  )),
  department text not null,
  check_date date not null,
  scope_image_quality text check (scope_image_quality in (
    'excellent','acceptable','degraded','fail'
  )),
  light_source_ok boolean,
  fluoroscopy_dose_rate_ok text not null check (fluoroscopy_dose_rate_ok in (
    'ok','high','not_applicable'
  )),
  frame_rate_adequate boolean,
  recording_sync_ok boolean,
  radiation_safety_ok text not null check (radiation_safety_ok in (
    'ok','apron_gap','not_applicable'
  )),
  scope_leak_test text not null check (scope_leak_test in (
    'pass','minor_leak','fail','not_applicable'
  )),
  reprocessing_traceable boolean,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.swallow_study_qc_r3315 enable row level security;

create index if not exists idx_swallow_study_qc_r3315_org on public.swallow_study_qc_r3315(organization_id);
create index if not exists idx_swallow_study_qc_r3315_date on public.swallow_study_qc_r3315(check_date);
create index if not exists idx_swallow_study_qc_r3315_verdict on public.swallow_study_qc_r3315(qc_verdict);

-- =============================================================================
-- TABLE 2: swallow_study_qc_capa_actions_r3315 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.swallow_study_qc_capa_actions_r3315 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.swallow_study_qc_r3315(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_quality_degraded','light_source_failure','fluoroscopy_dose_high','frame_rate_insufficient',
    'recording_sync_failure','radiation_safety_gap','scope_leak_detected','reprocessing_traceability_gap',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'scope_fiber_damage','light_source_bulb_aging','fluoroscopy_tube_drift','frame_rate_config_error',
    'recording_cable_fault','lead_apron_worn','scope_seal_degraded','reprocessing_log_missing',
    'calibration_backlog','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_scope_fiber_bundle','replace_light_source_bulb','recalibrate_fluoroscopy_dose','correct_frame_rate_config',
    'replace_recording_cable','replace_lead_apron','repair_scope_seal','restore_reprocessing_log',
    'schedule_calibration','retrain_swallow_lab_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.swallow_study_qc_capa_actions_r3315 enable row level security;

create index if not exists idx_swallow_capa_r3315_log on public.swallow_study_qc_capa_actions_r3315(qc_log_id);
create index if not exists idx_swallow_capa_r3315_status on public.swallow_study_qc_capa_actions_r3315(capa_status);

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

  -- 14 device QC rows
  insert into public.swallow_study_qc_r3315 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    scope_image_quality, light_source_ok, fluoroscopy_dose_rate_ok, frame_rate_adequate,
    recording_sync_ok, radiation_safety_ok, scope_leak_test, reprocessing_traceable,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.siq, q.lso, q.fdr, q.fra,
    q.rso, q.rsa, q.slt, q.rt,
    q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','FEES-APL-01','fees_scope','ENT','2026-07-05',
     'excellent',true,'not_applicable',true,true,'not_applicable','pass',true,true,'pass','Quarterly FEES scope QC — optics, channel and light nominal'),
    ('Apollo Chennai Greams Road','VFSS-APL-02','videofluoroscopy_system','Radiology','2026-07-05',
     'acceptable',null,'ok',true,true,'ok','not_applicable',true,true,'pass','VFSS suite — dose within DRL, 30fps confirmed, apron intact'),
    ('Fortis Gurgaon','FEES-FRT-11','fees_scope','ENT','2026-07-04',
     'degraded',true,'not_applicable',true,true,'not_applicable','minor_leak',true,true,'conditional_pass','Image degraded from fiber aging and minor channel leak — recheck booked'),
    ('Fortis Gurgaon','VFSS-FRT-12','videofluoroscopy_system','Radiology','2026-07-04',
     'acceptable',null,'high',true,true,'apron_gap','not_applicable',true,true,'fail','Dose rate above DRL and lead apron gap at seam — held for review'),
    ('Manipal Bengaluru','REC-MNP-21','swallow_recording_station','Speech Therapy','2026-07-03',
     'acceptable',null,'not_applicable',false,false,'not_applicable','not_applicable',true,false,'fail','Recording sync lost, frame rate dropped to 24fps, calibration expired'),
    ('Manipal Bengaluru','FEES-MNP-22','fees_tower','ENT','2026-07-03',
     'excellent',true,'not_applicable',true,true,'not_applicable','not_applicable',true,true,'pass','FEES tower light source, display and capture chain nominal'),
    ('AIIMS Delhi Ansari Nagar','VFSS-AIM-31','videofluoroscopy_system','Radiology','2026-07-02',
     'degraded',null,'high',false,true,'apron_gap','not_applicable',true,false,'removed_from_service','High dose, 15fps only, apron gap and calibration lapsed — removed from service'),
    ('AIIMS Delhi Ansari Nagar','FEES-AIM-32','fees_scope','ENT','2026-07-02',
     'acceptable',true,'not_applicable',true,true,'not_applicable','pass',true,true,'pass','Annual FEES scope QC clean pass'),
    ('CMC Vellore','PREP-CMC-41','barium_prep_station','Radiology','2026-07-01',
     null,null,'not_applicable',null,null,'not_applicable','not_applicable',true,true,'pass','Barium prep station — mixing, viscosity kit and labelling verified'),
    ('CMC Vellore','REC-CMC-42','swallow_recording_station','Speech Therapy','2026-07-01',
     'acceptable',null,'not_applicable',true,true,'not_applicable','not_applicable',true,true,'pass','Recording station 30fps capture and sync verified'),
    ('KIMS Hyderabad','FEES-KIM-51','fees_scope','ENT','2026-06-30',
     'fail',false,'not_applicable',true,true,'not_applicable','fail',false,true,'removed_from_service','Light source dead, leak test failed, reprocessing log missing — scope pulled'),
    ('KIMS Hyderabad','VFSS-KIM-52','videofluoroscopy_system','Radiology','2026-06-30',
     'acceptable',null,'ok',true,true,'ok','not_applicable',true,true,'pass','VFSS QC nominal, dose within reference, sync verified'),
    ('SGPGI Lucknow','VFSS-SGP-61','videofluoroscopy_system','Neurology','2026-06-29',
     'degraded',null,'ok',false,true,'ok','not_applicable',true,false,'conditional_pass','Frame rate 25fps below 30fps target and calibration due — conditional'),
    ('Amrita Kochi','FEES-AMR-71','fees_scope','Rehabilitation','2026-06-29',
     'acceptable',true,'not_applicable',true,false,'not_applicable','minor_leak',true,true,'conditional_pass','Recording sync intermittent and minor channel leak — recheck booked')
  ) as q(hosp, dcode, dtype, dept, cdate, siq, lso, fdr, fra, rso, rsa, slt, rt, cc, qv, nt);

  -- CAPA seed — attach to specific device checks via device_code
  insert into public.swallow_study_qc_capa_actions_r3315 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FEES-FRT-11','image_quality_degraded','scope_fiber_damage','replace_scope_fiber_bundle','in_progress','nabh_finding','2026-07-12',null,145000.00,'Fiber bundle replacement quoted; interim scope in service'),
    ('VFSS-FRT-12','radiation_safety_gap','lead_apron_worn','replace_lead_apron','escalated','aerb_notifiable','2026-07-10',null,28000.00,'Apron seam gap — AERB notifiable, dose audit ordered'),
    ('REC-MNP-21','recording_sync_failure','recording_cable_fault','replace_recording_cable','open','internal_only','2026-07-14',null,9500.00,'Sync and frame-rate loss traced to capture cable — part on order'),
    ('VFSS-AIM-31','fluoroscopy_dose_high','fluoroscopy_tube_drift','recalibrate_fluoroscopy_dose','escalated','aerb_notifiable','2026-07-09',null,210000.00,'Tube output drift; OEM dose recal plus apron replacement scheduled'),
    ('FEES-KIM-51','scope_leak_detected','scope_seal_degraded','repair_scope_seal','open','patient_safety_alert','2026-07-11',null,52000.00,'Leak, dead light source and missing reprocessing log — scope quarantined'),
    ('VFSS-SGP-61','frame_rate_insufficient','frame_rate_config_error','correct_frame_rate_config','verification_pending','internal_only','2026-07-06','2026-07-04',0.00,'Frame rate reset to 30fps in acquisition profile — verifying on next study'),
    ('FEES-AMR-71','scope_leak_detected','scope_seal_degraded','repair_scope_seal','closed','internal_only','2026-07-03','2026-07-02',6800.00,'Minor channel leak sealed; re-leak-test passed')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.swallow_study_qc_r3315 e
    on e.organization_id = v_org_id and e.device_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3315_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.swallow_study_qc_r3315)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.swallow_study_qc_r3315 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3315_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3315_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3315_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  image_fail bigint,
  leak_fail bigint,
  radiation_gap bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.scope_image_quality in ('degraded','fail'))::bigint,
    count(*) filter (where l.scope_leak_test in ('minor_leak','fail'))::bigint,
    count(*) filter (where l.radiation_safety_ok = 'apron_gap')::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.swallow_study_qc_r3315 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3315_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3315_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3315_device_dept_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, pass_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.swallow_study_qc_r3315 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3315_device_dept_matrix() from public, anon;
grant execute on function public.founder_r3315_device_dept_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3315_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, image_fail bigint, calibration_lapsed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.scope_image_quality in ('degraded','fail'))::bigint,
    count(*) filter (where l.calibration_current is false)::bigint
  from public.swallow_study_qc_r3315 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3315_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3315_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3315_capa_status_board()
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
  from public.swallow_study_qc_capa_actions_r3315 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3315_capa_status_board() from public, anon;
grant execute on function public.founder_r3315_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3315_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.swallow_study_qc_capa_actions_r3315)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.swallow_study_qc_capa_actions_r3315 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3315_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3315_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3315_regulatory_impact_digest()
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
  from public.swallow_study_qc_capa_actions_r3315 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3315_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3315_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (individual concerns)
create or replace function public.founder_r3315_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  scope_image_quality text,
  fluoroscopy_dose_rate_ok text,
  radiation_safety_ok text,
  scope_leak_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.scope_image_quality, l.fluoroscopy_dose_rate_ok,
    l.radiation_safety_ok, l.scope_leak_test, l.notes
  from public.swallow_study_qc_r3315 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.scope_image_quality in ('degraded','fail')
     or l.fluoroscopy_dose_rate_ok = 'high'
     or l.radiation_safety_ok = 'apron_gap'
     or l.scope_leak_test in ('minor_leak','fail')
     or l.light_source_ok is false
     or l.frame_rate_adequate is false
     or l.recording_sync_ok is false
     or l.reprocessing_traceable is false
     or l.calibration_current is false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3315_high_risk_queue() from public, anon;
grant execute on function public.founder_r3315_high_risk_queue() to authenticated;
