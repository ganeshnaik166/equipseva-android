-- Round 3314: Customer Hospital ENT Voice & Balance-Lab Equipment QC Audit
-- ENT QA — device type × strobe-sync × camera image × scope fiber/leak × VNG cal × posturography force cal × infection control × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: ent_stroboscopy_qc_r3314 — per-device ENT / balance-lab QC checks
-- =============================================================================
create table if not exists public.ent_stroboscopy_qc_r3314 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'videostroboscopy','rigid_laryngoscope_tower','flexible_laryngoscope',
    'vng_goggles','dynamic_posturography','rotary_chair'
  )),
  department text not null,
  check_date date not null,
  light_source_output_ok boolean,
  strobe_sync_accuracy_ok text check (strobe_sync_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  camera_image_quality text check (camera_image_quality in (
    'excellent','acceptable','degraded','fail'
  )),
  scope_fiber_integrity_ok boolean,
  vng_calibration_ok text check (vng_calibration_ok in (
    'pass','drift','not_applicable'
  )),
  platform_force_calibration_ok text check (platform_force_calibration_ok in (
    'pass','fail','not_applicable'
  )),
  leak_test_scope text check (leak_test_scope in (
    'pass','minor_leak','fail','not_applicable'
  )),
  infection_control_ok boolean,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ent_stroboscopy_qc_r3314 enable row level security;

create index if not exists idx_ent_stroboscopy_qc_r3314_org on public.ent_stroboscopy_qc_r3314(org_id);
create index if not exists idx_ent_stroboscopy_qc_r3314_date on public.ent_stroboscopy_qc_r3314(check_date);
create index if not exists idx_ent_stroboscopy_qc_r3314_verdict on public.ent_stroboscopy_qc_r3314(qc_verdict);

-- =============================================================================
-- TABLE 2: ent_stroboscopy_qc_capa_actions_r3314 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ent_stroboscopy_qc_capa_actions_r3314 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.ent_stroboscopy_qc_r3314(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'light_source_degraded','strobe_sync_drift','camera_image_degraded','scope_fiber_damage',
    'vng_calibration_drift','platform_force_calibration_fail','scope_leak','infection_control_gap',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lamp_end_of_life','strobe_trigger_board_fault','camera_ccd_degradation','fiber_bundle_broken',
    'vng_sensor_drift','force_plate_load_cell_drift','scope_seal_failure','reprocessing_protocol_gap',
    'calibration_backlog','operator_setup_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_light_source_lamp','replace_strobe_board','replace_camera_head','repair_fiber_bundle',
    'recalibrate_vng','recalibrate_force_platform','reseal_scope','reprocess_and_reculture',
    'schedule_calibration','retrain_ent_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.ent_stroboscopy_qc_capa_actions_r3314 enable row level security;

create index if not exists idx_ent_stroboscopy_capa_r3314_org on public.ent_stroboscopy_qc_capa_actions_r3314(org_id);
create index if not exists idx_ent_stroboscopy_capa_r3314_log on public.ent_stroboscopy_qc_capa_actions_r3314(qc_log_id);
create index if not exists idx_ent_stroboscopy_capa_r3314_status on public.ent_stroboscopy_qc_capa_actions_r3314(capa_status);

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

  -- 14 QC check rows
  insert into public.ent_stroboscopy_qc_r3314 (
    org_id, hospital_name, device_code, device_type, department, check_date,
    light_source_output_ok, strobe_sync_accuracy_ok, camera_image_quality,
    scope_fiber_integrity_ok, vng_calibration_ok, platform_force_calibration_ok,
    leak_test_scope, infection_control_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdate::date,
    q.lso, q.ssa, q.ciq,
    q.sfi, q.vng, q.pfc,
    q.lts, q.ic, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai','ENT-STRB-APC-01','videostroboscopy','ENT OPD','2026-07-05',
     true,'ok','excellent',true,'not_applicable','not_applicable','pass',true,true,'pass','Quarterly QC — all parameters within spec'),
    ('Apollo Chennai','ENT-RLT-APC-02','rigid_laryngoscope_tower','ENT OT','2026-07-05',
     true,'not_applicable','acceptable',true,'not_applicable','not_applicable','pass',true,true,'pass','Camera tower + rigid scope QC clean'),
    ('Fortis Gurgaon','ENT-STRB-FGN-01','videostroboscopy','ENT OPD','2026-07-04',
     true,'drift','degraded',true,'not_applicable','not_applicable','pass',true,true,'conditional_pass','Strobe sync drift + image slightly degraded — lamp hours high'),
    ('Fortis Gurgaon','ENT-FLS-FGN-02','flexible_laryngoscope','ENT OPD','2026-07-04',
     true,'not_applicable','acceptable',false,'not_applicable','not_applicable','minor_leak',true,true,'conditional_pass','Fiber bundle integrity failing + minor leak on channel test'),
    ('Manipal Bengaluru','ENT-VNG-MNB-01','vng_goggles','Vestibular Lab','2026-07-03',
     true,'not_applicable','acceptable',null,'pass','not_applicable','not_applicable',true,true,'pass','VNG goggle calibration verified against target board'),
    ('Manipal Bengaluru','ENT-CDP-MNB-02','dynamic_posturography','Balance Lab','2026-07-03',
     null,'not_applicable',null,null,'not_applicable','pass','not_applicable',true,true,'pass','Force platform calibration within tolerance'),
    ('AIIMS Delhi','ENT-STRB-AID-01','videostroboscopy','ENT OPD','2026-07-02',
     false,'fail','fail',true,'not_applicable','not_applicable','pass',true,false,'fail','Light source output low + strobe trigger failed — calibration lapsed'),
    ('AIIMS Delhi','ENT-FLS-AID-02','flexible_laryngoscope','ENT Endoscopy','2026-07-02',
     true,'not_applicable','degraded',false,'not_applicable','not_applicable','fail',false,true,'removed_from_service','Leak test failed + reprocessing gap — scope quarantined'),
    ('CMC Vellore','ENT-RTC-CMC-01','rotary_chair','Vestibular Lab','2026-07-01',
     null,'not_applicable',null,null,'not_applicable','not_applicable','not_applicable',true,true,'pass','Rotary chair velocity-step check nominal'),
    ('CMC Vellore','ENT-CDP-CMC-02','dynamic_posturography','Balance Lab','2026-07-01',
     null,'not_applicable',null,null,'not_applicable','fail','not_applicable',true,false,'fail','Force plate load-cell drift beyond limit — calibration overdue'),
    ('KIMS Hyderabad','ENT-VNG-KIM-01','vng_goggles','Vestibular Lab','2026-06-30',
     true,'not_applicable','acceptable',null,'drift','not_applicable','not_applicable',true,true,'conditional_pass','VNG calibration drift — recalibration scheduled'),
    ('KIMS Hyderabad','ENT-RLT-KIM-02','rigid_laryngoscope_tower','ENT OT','2026-06-30',
     true,'not_applicable','excellent',true,'not_applicable','not_applicable','pass',true,true,'pass','Rigid scope + tower imaging excellent'),
    ('Kokilaben Mumbai','ENT-STRB-KKM-01','videostroboscopy','ENT OPD','2026-06-29',
     true,'ok','acceptable',true,'not_applicable','not_applicable','minor_leak',true,true,'conditional_pass','Minor leak on stroboscope sheath — monitor next cycle'),
    ('Medanta Gurugram','ENT-FLS-MDG-01','flexible_laryngoscope','ENT Endoscopy','2026-06-29',
     true,'not_applicable','fail',false,'not_applicable','not_applicable','fail',true,false,'removed_from_service','Camera CCD degradation + leak fail + calibration overdue — withdrawn')
  ) as q(hosp, dcode, dtype, dept, cdate, lso, ssa, ciq, sfi, vng, pfc, lts, ic, cc, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ent_stroboscopy_qc_capa_actions_r3314 (
    org_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ENT-STRB-FGN-01','strobe_sync_drift','strobe_trigger_board_fault','replace_strobe_board','in_progress','internal_only','2026-07-12',null,45000.00,'Strobe trigger board on order from OEM'),
    ('ENT-FLS-FGN-02','scope_fiber_damage','fiber_bundle_broken','repair_fiber_bundle','open','iso_13485_deviation','2026-07-14',null,68000.00,'Fiber bundle repair quote from OEM pending'),
    ('ENT-STRB-AID-01','light_source_degraded','lamp_end_of_life','replace_light_source_lamp','closed','nabh_finding','2026-07-06','2026-07-04',22000.00,'Xenon lamp replaced + system recalibrated'),
    ('ENT-FLS-AID-02','infection_control_gap','reprocessing_protocol_gap','reprocess_and_reculture','escalated','patient_safety_alert','2026-07-05',null,15000.00,'Scope quarantined — leak repair + reculture before reuse'),
    ('ENT-CDP-CMC-02','platform_force_calibration_fail','force_plate_load_cell_drift','recalibrate_force_platform','open','iso_13485_deviation','2026-07-09',null,38000.00,'Load-cell recalibration + calibration certificate renewal'),
    ('ENT-VNG-KIM-01','vng_calibration_drift','vng_sensor_drift','recalibrate_vng','verification_pending','internal_only','2026-07-07',null,6000.00,'VNG recalibrated — awaiting verification run'),
    ('ENT-FLS-MDG-01','camera_image_degraded','camera_ccd_degradation','replace_camera_head','overdue','cdsco_notifiable','2026-06-30',null,95000.00,'Camera head + calibration overdue — AMC vendor delayed')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ent_stroboscopy_qc_r3314 e
    on e.org_id = v_org_id and e.device_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3314_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ent_stroboscopy_qc_r3314)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ent_stroboscopy_qc_r3314 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3314_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3314_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3314_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  strobe_sync_fail bigint,
  camera_fail bigint,
  leak_fail bigint,
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
    count(*) filter (where l.strobe_sync_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.camera_image_quality in ('degraded','fail'))::bigint,
    count(*) filter (where l.leak_test_scope in ('minor_leak','fail'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ent_stroboscopy_qc_r3314 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3314_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3314_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3314_device_type_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint
  from public.ent_stroboscopy_qc_r3314 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3314_device_type_department_matrix() from public, anon;
grant execute on function public.founder_r3314_device_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3314_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, strobe_sync_fail bigint, camera_fail bigint)
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
    count(*) filter (where l.strobe_sync_accuracy_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.camera_image_quality in ('degraded','fail'))::bigint
  from public.ent_stroboscopy_qc_r3314 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3314_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3314_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3314_capa_status_board()
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
  from public.ent_stroboscopy_qc_capa_actions_r3314 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3314_capa_status_board() from public, anon;
grant execute on function public.founder_r3314_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3314_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ent_stroboscopy_qc_capa_actions_r3314)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ent_stroboscopy_qc_capa_actions_r3314 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3314_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3314_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3314_regulatory_impact_digest()
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
  from public.ent_stroboscopy_qc_capa_actions_r3314 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3314_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3314_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (individual device concerns)
create or replace function public.founder_r3314_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  strobe_sync_accuracy_ok text,
  camera_image_quality text,
  leak_test_scope text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.strobe_sync_accuracy_ok, l.camera_image_quality, l.leak_test_scope, l.notes
  from public.ent_stroboscopy_qc_r3314 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.strobe_sync_accuracy_ok in ('drift','fail')
     or l.camera_image_quality in ('degraded','fail')
     or l.leak_test_scope in ('minor_leak','fail')
     or l.platform_force_calibration_ok = 'fail'
     or l.vng_calibration_ok = 'drift'
     or l.light_source_output_ok = false
     or l.scope_fiber_integrity_ok = false
     or l.infection_control_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3314_high_risk_queue() from public, anon;
grant execute on function public.founder_r3314_high_risk_queue() to authenticated;
