-- Round 3350: Customer Hospital DSA / Biplane Angiography Imaging-Chain QC Audit
-- Interventional angio QA — system type × image quality × flat-panel dead-pixels × subtraction registration × dose-rate limit × contrast resolution × frame-rate accuracy × table/gantry × road-map × radiation safety × calibration × CAPA

-- =============================================================================
-- TABLE 1: dsa_angio_imaging_r3350 — per-system imaging-chain QC checks
-- =============================================================================
create table if not exists public.dsa_angio_imaging_r3350 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  system_code text not null,
  system_type text not null check (system_type in (
    'single_plane_dsa','biplane_dsa','rotational_3d_angio','hybrid_or_angio','mobile_dsa'
  )),
  department text not null,
  check_date date not null,
  image_quality_ok text not null check (image_quality_ok in (
    'excellent','acceptable','degraded','fail'
  )),
  flat_panel_dead_pixel_count int not null,
  subtraction_registration_ok boolean not null,
  dose_rate_within_limit boolean not null,
  contrast_resolution_ok boolean not null,
  frame_rate_accuracy_ok boolean not null,
  table_gantry_movement_ok boolean not null,
  road_map_function_ok boolean not null,
  radiation_safety_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dsa_angio_imaging_r3350 enable row level security;

create index if not exists idx_dsa_angio_imaging_r3350_org on public.dsa_angio_imaging_r3350(organization_id);
create index if not exists idx_dsa_angio_imaging_r3350_date on public.dsa_angio_imaging_r3350(check_date);
create index if not exists idx_dsa_angio_imaging_r3350_verdict on public.dsa_angio_imaging_r3350(qc_verdict);

-- =============================================================================
-- TABLE 2: dsa_angio_imaging_capa_actions_r3350 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dsa_angio_imaging_capa_actions_r3350 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.dsa_angio_imaging_r3350(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_quality_degradation','dead_pixel_cluster','subtraction_misregistration','dose_rate_exceedance',
    'contrast_resolution_loss','frame_rate_inaccuracy','table_gantry_fault','road_map_failure',
    'radiation_safety_interlock','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'flat_panel_detector_aging','xray_tube_wear','generator_calibration_drift','image_processor_fault',
    'gantry_encoder_fault','collimator_filter_fault','software_config_error','operator_setup_error',
    'interlock_sensor_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_flat_panel_detector','replace_xray_tube','recalibrate_generator','service_image_processor',
    'replace_gantry_encoder','service_collimator','update_software_config','retrain_cathlab_staff',
    'repair_safety_interlock','remove_from_service','schedule_oem_service','none_required'
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

alter table public.dsa_angio_imaging_capa_actions_r3350 enable row level security;

create index if not exists idx_dsa_angio_capa_r3350_log on public.dsa_angio_imaging_capa_actions_r3350(qc_log_id);
create index if not exists idx_dsa_angio_capa_r3350_status on public.dsa_angio_imaging_capa_actions_r3350(capa_status);

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

  -- 14 imaging-chain QC rows
  insert into public.dsa_angio_imaging_r3350 (
    organization_id, hospital_name, system_code, system_type, department, check_date,
    image_quality_ok, flat_panel_dead_pixel_count, subtraction_registration_ok,
    dose_rate_within_limit, contrast_resolution_ok, frame_rate_accuracy_ok,
    table_gantry_movement_ok, road_map_function_ok, radiation_safety_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.scode, q.stype, q.dept, q.cdate::date,
    q.iq, q.dpx::int, q.subreg,
    q.doserate, q.contrast, q.framerate,
    q.tblgantry, q.roadmap, q.radsafety, q.calcurrent,
    q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','DSA-APL-01','biplane_dsa','Neuro Intervention','2026-07-05',
     'excellent',2,true,true,true,true,true,true,true,true,'pass','Quarterly imaging-chain QC — all parameters nominal'),
    ('Apollo Chennai Greams Road','DSA-APL-02','single_plane_dsa','Cardiology Cath-Lab','2026-07-05',
     'acceptable',6,true,true,true,true,true,true,true,true,'pass','Annual QC — flat-panel and dose-rate within limits'),
    ('Fortis Gurgaon','DSA-FRT-01','biplane_dsa','Neuro Intervention','2026-07-04',
     'degraded',41,false,true,false,true,true,true,true,true,'conditional_pass','Dead-pixel cluster 41 and subtraction misregistration — vendor booked'),
    ('Fortis Gurgaon','DSA-FRT-02','rotational_3d_angio','Interventional Radiology','2026-07-04',
     'fail',88,false,false,false,false,true,false,true,false,'removed_from_service','Detector failing across chain — system pulled from service'),
    ('Manipal Bengaluru Old Airport Road','DSA-MNP-01','hybrid_or_angio','Hybrid OR','2026-07-03',
     'acceptable',9,true,true,true,true,true,true,true,true,'pass','Post-PM verification pass'),
    ('Manipal Bengaluru Old Airport Road','DSA-MNP-02','biplane_dsa','Neuro Intervention','2026-07-03',
     'degraded',18,true,false,true,true,true,true,true,true,'conditional_pass','Dose-rate above reference at high magnification — AERB dose review'),
    ('AIIMS Delhi Ansari Nagar','DSA-AIM-01','biplane_dsa','Neuro Intervention','2026-07-02',
     'excellent',1,true,true,true,true,true,true,true,true,'pass','Biplane neuro suite QC nominal'),
    ('AIIMS Delhi Ansari Nagar','DSA-AIM-02','single_plane_dsa','Cardiology Cath-Lab','2026-07-02',
     'degraded',12,true,true,true,false,true,true,true,true,'conditional_pass','Frame-rate 12.6 fps vs 15 fps setpoint — pulse-generator check'),
    ('CMC Vellore','DSA-CMC-01','mobile_dsa','Operating Theatre','2026-07-01',
     'acceptable',7,true,true,true,true,false,true,true,true,'conditional_pass','Mobile C-arm gantry rotation drift — encoder service due'),
    ('CMC Vellore','DSA-CMC-02','biplane_dsa','Interventional Radiology','2026-07-01',
     'fail',63,false,true,false,true,true,false,false,false,'fail','Road-map function down and safety interlock intermittent — OEM escalation'),
    ('KIMS Hyderabad','DSA-KIM-01','hybrid_or_angio','Hybrid OR','2026-06-30',
     'excellent',3,true,true,true,true,true,true,true,true,'pass','Cardiac hybrid suite QC nominal'),
    ('KIMS Hyderabad','DSA-KIM-02','rotational_3d_angio','Interventional Radiology','2026-06-30',
     'acceptable',14,true,true,true,true,true,true,true,false,'conditional_pass','3D-rotational reconstruction OK but calibration certificate expired — recal booked'),
    ('Medanta Gurugram','DSA-MED-01','biplane_dsa','Neuro Intervention','2026-06-29',
     'acceptable',5,true,true,true,true,true,true,true,true,'pass','Annual imaging-chain QC pass'),
    ('Narayana Health Bengaluru','DSA-NHB-01','single_plane_dsa','Cardiology Cath-Lab','2026-06-29',
     'degraded',22,true,false,false,true,true,true,true,true,'conditional_pass','Low-contrast detectability reduced and dose-rate high — detector gain recal due')
  ) as q(hosp, scode, stype, dept, cdate, iq, dpx, subreg, doserate, contrast, framerate, tblgantry, roadmap, radsafety, calcurrent, qv, nt);

  -- CAPA seed — attach to specific systems via system_code
  insert into public.dsa_angio_imaging_capa_actions_r3350 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DSA-FRT-01','image_quality_degradation','flat_panel_detector_aging','replace_flat_panel_detector','in_progress','patient_safety_alert','2026-07-12',null,285000.00,'Detector aging with dead-pixel cluster — replacement panel quoted, awaiting PO'),
    ('DSA-FRT-02','dead_pixel_cluster','flat_panel_detector_aging','replace_flat_panel_detector','escalated','cdsco_notifiable','2026-07-11',null,320000.00,'88 dead pixels across active area — system out of service, OEM escalation'),
    ('DSA-MNP-02','dose_rate_exceedance','generator_calibration_drift','recalibrate_generator','open','aerb_notifiable','2026-07-13',null,45000.00,'Dose-rate above AERB reference at high mag — recal and dose survey booked'),
    ('DSA-CMC-01','table_gantry_fault','gantry_encoder_fault','replace_gantry_encoder','open','nabh_finding','2026-07-09',null,62000.00,'Mobile C-arm rotation encoder drift — replacement encoder on order'),
    ('DSA-CMC-02','radiation_safety_interlock','interlock_sensor_fault','repair_safety_interlock','escalated','aerb_notifiable','2026-07-08',null,38000.00,'Safety interlock intermittent — system quarantined pending AERB clearance'),
    ('DSA-KIM-02','calibration_overdue','preventive_service_backlog','schedule_oem_service','verification_pending','iso_13485_deviation','2026-07-07',null,52000.00,'Calibration certificate expired — OEM recal scheduled, verifying result'),
    ('DSA-AIM-02','frame_rate_inaccuracy','generator_calibration_drift','recalibrate_generator','closed','internal_only','2026-07-05','2026-07-06',22000.00,'Pulse-generator recalibrated, frame-rate within tolerance — closed')
  ) as q(scode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.dsa_angio_imaging_r3350 e
    on e.organization_id = v_org_id and e.system_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3350_qc_verdict_rollup()
returns table(qc_verdict text, systems bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dsa_angio_imaging_r3350)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dsa_angio_imaging_r3350 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3350_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3350_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3350_hospital_scorecard()
returns table(
  hospital_name text,
  total_systems bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  image_quality_fail bigint,
  dose_exceedance bigint,
  radiation_safety_fail bigint,
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
    count(*) filter (where l.image_quality_ok in ('degraded','fail'))::bigint,
    count(*) filter (where l.dose_rate_within_limit = false)::bigint,
    count(*) filter (where l.radiation_safety_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.dsa_angio_imaging_r3350 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3350_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3350_hospital_scorecard() to authenticated;

-- 3) System-type × department matrix
create or replace function public.founder_r3350_system_department_matrix()
returns table(system_type text, department text, systems bigint, passed bigint, avg_dead_pixel_count numeric, dose_exceedance bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.flat_panel_dead_pixel_count), 1),
    count(*) filter (where l.dose_rate_within_limit = false)::bigint
  from public.dsa_angio_imaging_r3350 l
  group by l.system_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3350_system_department_matrix() from public, anon;
grant execute on function public.founder_r3350_system_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3350_daily_qc_trend()
returns table(check_date date, systems bigint, passed bigint, failed bigint, image_quality_fail bigint, dose_exceedance bigint)
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
    count(*) filter (where l.image_quality_ok in ('degraded','fail'))::bigint,
    count(*) filter (where l.dose_rate_within_limit = false)::bigint
  from public.dsa_angio_imaging_r3350 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3350_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3350_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3350_capa_status_board()
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
  from public.dsa_angio_imaging_capa_actions_r3350 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3350_capa_status_board() from public, anon;
grant execute on function public.founder_r3350_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3350_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dsa_angio_imaging_capa_actions_r3350)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dsa_angio_imaging_capa_actions_r3350 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3350_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3350_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3350_regulatory_impact_digest()
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
  from public.dsa_angio_imaging_capa_actions_r3350 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3350_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3350_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3350_high_risk_queue()
returns table(
  hospital_name text,
  system_code text,
  system_type text,
  department text,
  check_date date,
  qc_verdict text,
  image_quality_ok text,
  flat_panel_dead_pixel_count int,
  failed_checks text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.system_code, l.system_type, l.department, l.check_date,
    l.qc_verdict, l.image_quality_ok, l.flat_panel_dead_pixel_count,
    concat_ws(', ',
      case when l.image_quality_ok in ('degraded','fail') then 'image_quality' end,
      case when l.subtraction_registration_ok = false then 'subtraction' end,
      case when l.dose_rate_within_limit = false then 'dose_rate' end,
      case when l.contrast_resolution_ok = false then 'contrast' end,
      case when l.frame_rate_accuracy_ok = false then 'frame_rate' end,
      case when l.table_gantry_movement_ok = false then 'table_gantry' end,
      case when l.road_map_function_ok = false then 'road_map' end,
      case when l.radiation_safety_ok = false then 'radiation_safety' end,
      case when l.calibration_current = false then 'calibration' end,
      case when l.flat_panel_dead_pixel_count > 20 then 'dead_pixels' end
    ),
    l.notes
  from public.dsa_angio_imaging_r3350 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.image_quality_ok in ('degraded','fail')
     or l.subtraction_registration_ok = false
     or l.dose_rate_within_limit = false
     or l.contrast_resolution_ok = false
     or l.frame_rate_accuracy_ok = false
     or l.table_gantry_movement_ok = false
     or l.road_map_function_ok = false
     or l.radiation_safety_ok = false
     or l.calibration_current = false
     or l.flat_panel_dead_pixel_count > 20
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3350_high_risk_queue() from public, anon;
grant execute on function public.founder_r3350_high_risk_queue() to authenticated;
