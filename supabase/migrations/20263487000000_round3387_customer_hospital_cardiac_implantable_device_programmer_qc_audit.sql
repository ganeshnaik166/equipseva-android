-- Round 3387: Customer Hospital Cardiac Implantable-Device Programmer QC Audit
-- Programmer QA — device type × department × telemetry wand × comm test × battery × printer × software version × vendor compat × touch cal × emergency pacing × data export × CAPA

-- =============================================================================
-- TABLE 1: cardiac_programmer_qc_r3387 — per-programmer QC checks
-- =============================================================================
create table if not exists public.cardiac_programmer_qc_r3387 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  programmer_code text not null,
  device_type text not null check (device_type in (
    'pacemaker_programmer','icd_programmer','crt_programmer',
    'remote_monitoring_receiver','multi_vendor_programmer'
  )),
  department text not null,
  check_date date not null,
  telemetry_wand_ok boolean not null,
  communication_test_pass text not null check (communication_test_pass in (
    'pass','intermittent','fail'
  )),
  battery_charge_ok boolean not null,
  printer_output_ok text not null check (printer_output_ok in (
    'ok','faded','faulty','not_configured'
  )),
  software_version_current boolean not null,
  vendor_compatibility_ok boolean not null,
  screen_touch_calibration_ok boolean not null,
  emergency_pacing_function_ok boolean not null,
  data_export_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cardiac_programmer_qc_r3387 enable row level security;

create index if not exists idx_cardiac_programmer_qc_r3387_org on public.cardiac_programmer_qc_r3387(organization_id);
create index if not exists idx_cardiac_programmer_qc_r3387_date on public.cardiac_programmer_qc_r3387(check_date);
create index if not exists idx_cardiac_programmer_qc_r3387_verdict on public.cardiac_programmer_qc_r3387(qc_verdict);

-- =============================================================================
-- TABLE 2: cardiac_programmer_qc_capa_actions_r3387 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cardiac_programmer_qc_capa_actions_r3387 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cardiac_programmer_qc_r3387(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'telemetry_wand_failure','communication_failure','battery_depleted','printer_failure',
    'software_outdated','vendor_incompatibility','touch_calibration_drift',
    'emergency_pacing_failure','data_export_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'wand_cable_damaged','rf_module_fault','battery_end_of_life','printer_head_worn',
    'software_update_pending','unsupported_device_model','touchscreen_degraded',
    'operator_setup_error','pending_investigation','preventive_service_backlog','firmware_corruption'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_telemetry_wand','repair_rf_module','replace_battery','replace_printer_head',
    'apply_software_update','load_vendor_support_pack','recalibrate_touchscreen',
    'retrain_cardiology_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.cardiac_programmer_qc_capa_actions_r3387 enable row level security;

create index if not exists idx_cardiac_programmer_capa_r3387_log on public.cardiac_programmer_qc_capa_actions_r3387(qc_log_id);
create index if not exists idx_cardiac_programmer_capa_r3387_status on public.cardiac_programmer_qc_capa_actions_r3387(capa_status);

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

  insert into public.cardiac_programmer_qc_r3387 (
    organization_id, hospital_name, programmer_code, device_type, department, check_date,
    telemetry_wand_ok, communication_test_pass, battery_charge_ok, printer_output_ok,
    software_version_current, vendor_compatibility_ok, screen_touch_calibration_ok,
    emergency_pacing_function_ok, data_export_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.pcode, q.dtype, q.dept, q.cdate::date,
    q.wand, q.commtest, q.batt, q.printer,
    q.swver, q.vendcompat, q.touchcal,
    q.epace, q.dataexp, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','PGM-APL-01','pacemaker_programmer','cardiology_opd','2026-07-03',
     true,'pass',true,'ok',true,true,true,true,true,true,'pass','Quarterly QC — pacemaker programmer telemetry and pacing nominal'),
    ('Apollo Chennai','PGM-APL-02','icd_programmer','cath_lab','2026-07-03',
     true,'pass',true,'ok',true,true,true,true,true,true,'pass','ICD programmer QC pass, all functions verified'),
    ('Fortis Gurgaon','PGM-FRT-11','crt_programmer','cardiac_ot','2026-07-02',
     true,'intermittent',true,'faded',true,true,true,true,true,true,'conditional_pass','CRT programmer telemetry intermittent and printer faded — recheck booked'),
    ('Fortis Gurgaon','PGM-FRT-12','pacemaker_programmer','cardiology_opd','2026-07-02',
     false,'fail',true,'ok',false,true,true,true,false,true,'fail','Telemetry wand and comm test failed, software outdated and export failed'),
    ('Manipal Bengaluru','PGM-MNP-21','multi_vendor_programmer','cath_lab','2026-07-01',
     true,'pass',false,'ok',true,false,true,true,true,false,'conditional_pass','Battery not holding charge and vendor pack missing for one model — calibration overdue'),
    ('Manipal Bengaluru','PGM-MNP-22','remote_monitoring_receiver','cardiology_opd','2026-07-01',
     true,'pass',true,'not_configured',true,true,true,true,true,true,'conditional_pass','Remote monitoring receiver QC ok, printer not configured (not required)'),
    ('AIIMS Delhi','PGM-AIM-31','icd_programmer','cardiac_ot','2026-06-30',
     true,'pass',true,'ok',true,true,true,true,true,true,'pass','ICD programmer QC pass in cardiac OT'),
    ('AIIMS Delhi','PGM-AIM-32','pacemaker_programmer','emergency','2026-06-30',
     true,'intermittent',false,'faulty',true,true,false,true,true,true,'fail','Battery weak, printer faulty and touchscreen unresponsive — pulled for service'),
    ('CMC Vellore','PGM-CMC-41','crt_programmer','cath_lab','2026-06-29',
     true,'pass',true,'ok',true,true,true,true,true,true,'pass','CRT programmer QC pass'),
    ('CMC Vellore','PGM-CMC-42','multi_vendor_programmer','cardiology_opd','2026-06-29',
     true,'pass',true,'ok',false,true,true,true,true,false,'conditional_pass','Software update pending and calibration overdue — schedule update'),
    ('KIMS Hyderabad','PGM-KIM-51','pacemaker_programmer','cardiology_opd','2026-06-28',
     true,'pass',true,'ok',true,true,true,true,true,true,'pass','Pacemaker programmer QC pass post-AMC'),
    ('KIMS Hyderabad','PGM-KIM-52','icd_programmer','cath_lab','2026-06-28',
     true,'pass',true,'faded',true,true,true,false,true,true,'conditional_pass','Emergency pacing test failed once, printer faded — retest and print-head due'),
    ('Yashoda Hyderabad','PGM-YSH-61','remote_monitoring_receiver','cardiology_opd','2026-06-27',
     true,'pass',true,'ok',true,true,true,true,true,true,'pass','Remote monitoring receiver QC nominal'),
    ('Kokilaben Mumbai','PGM-KKB-71','icd_programmer','cardiac_ot','2026-06-27',
     false,'fail',false,'faulty',false,false,false,false,false,false,'removed_from_service','Multiple failures across telemetry, battery, pacing and export — removed from service')
  ) as q(hosp, pcode, dtype, dept, cdate, wand, commtest, batt, printer, swver, vendcompat, touchcal, epace, dataexp, calcur, qv, nt);

  insert into public.cardiac_programmer_qc_capa_actions_r3387 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PGM-FRT-12','communication_failure','rf_module_fault','repair_rf_module','in_progress','iso_13485_deviation','2026-07-06',null,28000.00,'RF module under repair; software update queued'),
    ('PGM-MNP-21','battery_depleted','battery_end_of_life','replace_battery','open','internal_only','2026-07-05',null,12000.00,'Programmer battery replacement and vendor support pack load'),
    ('PGM-AIM-32','printer_failure','printer_head_worn','replace_printer_head','escalated','patient_safety_alert','2026-07-04',null,9500.00,'Battery + printer + touchscreen failures escalated to OEM'),
    ('PGM-KKB-71','emergency_pacing_failure','firmware_corruption','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',65000.00,'Programmer removed; loaner deployed and validated'),
    ('PGM-KIM-52','emergency_pacing_failure','operator_setup_error','retrain_cardiology_staff','verification_pending','patient_safety_alert','2026-07-05',null,0.00,'Pacing test re-run planned; staff retrained on setup'),
    ('PGM-CMC-42','calibration_overdue','software_update_pending','apply_software_update','overdue','internal_only','2026-06-30',null,0.00,'Software update past target — vendor scheduling delay'),
    ('PGM-FRT-11','printer_failure','printer_head_worn','replace_printer_head','open','none','2026-07-07',null,7000.00,'Print head replacement ordered; telemetry recheck scheduled')
  ) as q(pcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cardiac_programmer_qc_r3387 e
    on e.organization_id = v_org_id and e.programmer_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3387_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cardiac_programmer_qc_r3387)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cardiac_programmer_qc_r3387 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3387_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3387_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3387_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  comm_fail bigint,
  battery_issue bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.communication_test_pass in ('intermittent','fail'))::bigint,
    count(*) filter (where l.battery_charge_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cardiac_programmer_qc_r3387 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3387_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3387_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3387_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, failed bigint, comm_fail bigint)
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
    count(*) filter (where l.communication_test_pass in ('intermittent','fail'))::bigint
  from public.cardiac_programmer_qc_r3387 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3387_device_department_matrix() from public, anon;
grant execute on function public.founder_r3387_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3387_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, comm_fail bigint, battery_issue bigint)
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
    count(*) filter (where l.communication_test_pass in ('intermittent','fail'))::bigint,
    count(*) filter (where l.battery_charge_ok = false)::bigint
  from public.cardiac_programmer_qc_r3387 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3387_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3387_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3387_capa_status_board()
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
  from public.cardiac_programmer_qc_capa_actions_r3387 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3387_capa_status_board() from public, anon;
grant execute on function public.founder_r3387_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3387_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cardiac_programmer_qc_capa_actions_r3387)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cardiac_programmer_qc_capa_actions_r3387 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3387_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3387_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3387_regulatory_impact_digest()
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
  from public.cardiac_programmer_qc_capa_actions_r3387 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3387_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3387_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue
create or replace function public.founder_r3387_high_risk_queue()
returns table(
  hospital_name text,
  programmer_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  communication_test_pass text,
  printer_output_ok text,
  emergency_pacing_function_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.programmer_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.communication_test_pass, l.printer_output_ok, l.emergency_pacing_function_ok, l.notes
  from public.cardiac_programmer_qc_r3387 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.telemetry_wand_ok = false
     or l.communication_test_pass in ('intermittent','fail')
     or l.battery_charge_ok = false
     or l.emergency_pacing_function_ok = false
     or l.data_export_ok = false
     or l.vendor_compatibility_ok = false
     or l.screen_touch_calibration_ok = false
     or l.calibration_current = false
     or l.printer_output_ok in ('faded','faulty')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3387_high_risk_queue() from public, anon;
grant execute on function public.founder_r3387_high_risk_queue() to authenticated;
