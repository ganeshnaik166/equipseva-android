-- Round 3339: Customer Hospital OR-Integration & Robotic-Surgery Console QC Audit
-- OT QC — system type × vendor × video routing × image latency × robotic-arm calibration × instrument recognition × 3D-display alignment × e-stop × network recording × sterile-drape interface × CAPA

-- =============================================================================
-- TABLE 1: or_robotic_qc_r3339 — per-system OR-integration / robotic-console QC checks
-- =============================================================================
create table if not exists public.or_robotic_qc_r3339 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  system_code text not null,
  system_type text not null check (system_type in (
    'or_integration_video','robotic_surgeon_console','robotic_patient_cart','robotic_vision_cart','4k_3d_display_wall'
  )),
  system_vendor text not null check (system_vendor in (
    'intuitive_da_vinci','medtronic_hugo_ras','cmr_surgical_versius','stryker_1788',
    'karl_storz_or1','olympus_visera_elite','getinge_tegris','sony_nucleus'
  )),
  ot_number text not null,
  check_date date not null,
  video_routing_ok boolean not null,
  image_latency_ok text not null check (image_latency_ok in (
    'ok','lag_detected','fail'
  )),
  robotic_arm_calibration_ok text not null check (robotic_arm_calibration_ok in (
    'pass','drift','fail','not_applicable'
  )),
  instrument_recognition_ok boolean not null,
  three_d_display_alignment_ok boolean not null,
  emergency_stop_ok boolean not null,
  network_recording_ok boolean not null,
  sterile_drape_interface_ok boolean not null,
  error_log_reviewed boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.or_robotic_qc_r3339 enable row level security;

create index if not exists idx_or_robotic_qc_r3339_org on public.or_robotic_qc_r3339(organization_id);
create index if not exists idx_or_robotic_qc_r3339_date on public.or_robotic_qc_r3339(check_date);
create index if not exists idx_or_robotic_qc_r3339_verdict on public.or_robotic_qc_r3339(qc_verdict);

-- =============================================================================
-- TABLE 2: or_robotic_qc_capa_actions_r3339 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.or_robotic_qc_capa_actions_r3339 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.or_robotic_qc_r3339(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'video_routing_failure','image_latency','robotic_arm_drift','instrument_recognition_failure',
    '3d_display_misalignment','emergency_stop_failure','network_recording_failure',
    'sterile_drape_interface_fault','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'video_matrix_switch_fault','network_congestion','encoder_latency','arm_encoder_drift',
    'instrument_rfid_reader_fault','display_calibration_drift','estop_circuit_fault','recording_server_full',
    'drape_sensor_misread','software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_video_matrix_switch','optimize_network_qos','replace_encoder_module','recalibrate_robotic_arm',
    'replace_rfid_reader','recalibrate_3d_display','repair_estop_circuit','expand_recording_storage',
    'replace_drape_sensor','update_software_config','retrain_ot_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.or_robotic_qc_capa_actions_r3339 enable row level security;

create index if not exists idx_or_robotic_capa_r3339_log on public.or_robotic_qc_capa_actions_r3339(qc_log_id);
create index if not exists idx_or_robotic_capa_r3339_status on public.or_robotic_qc_capa_actions_r3339(capa_status);

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
  insert into public.or_robotic_qc_r3339 (
    organization_id, hospital_name, system_code, system_type, system_vendor, ot_number, check_date,
    video_routing_ok, image_latency_ok, robotic_arm_calibration_ok, instrument_recognition_ok,
    three_d_display_alignment_ok, emergency_stop_ok, network_recording_ok, sterile_drape_interface_ok,
    error_log_reviewed, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.scode, q.stype, q.vendor, q.otn, q.cdate::date,
    q.vro, q.ilo, q.rack, q.irk,
    q.tdda, q.eso, q.nro, q.sdio,
    q.elr, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','SYS-APL-C01','robotic_surgeon_console','intuitive_da_vinci','OT-3','2026-07-10',
     true,'ok','pass',true,true,true,true,true,true,true,'pass','da Vinci Xi surgeon console QC — all parameters nominal'),
    ('Apollo Chennai Greams Road','SYS-APL-C02','robotic_patient_cart','intuitive_da_vinci','OT-3','2026-07-10',
     true,'ok','drift',true,true,true,true,true,true,true,'conditional_pass','Arm 3 minor drift within recheck window — monitor next case'),
    ('Fortis Gurgaon','SYS-FRT-V01','or_integration_video','karl_storz_or1','OT-1','2026-07-09',
     true,'lag_detected','not_applicable',true,true,true,true,true,true,true,'conditional_pass','Routing OK but 180ms latency on laparoscope source — network QoS review'),
    ('Fortis Gurgaon','SYS-FRT-D01','4k_3d_display_wall','sony_nucleus','OT-1','2026-07-09',
     true,'ok','not_applicable',true,false,true,true,true,true,true,'fail','3D polarizer alignment off — recalibration required before robotic list'),
    ('Manipal Bengaluru Old Airport Rd','SYS-MNP-C01','robotic_surgeon_console','cmr_surgical_versius','OT-5','2026-07-08',
     true,'ok','pass',true,true,true,true,true,true,true,'pass','Versius surgeon console annual QC pass'),
    ('Manipal Bengaluru Old Airport Rd','SYS-MNP-V02','robotic_vision_cart','cmr_surgical_versius','OT-5','2026-07-08',
     true,'ok','not_applicable',false,true,true,true,true,true,true,'conditional_pass','Instrument recognition intermittent on bipolar — RFID reader watch'),
    ('AIIMS Delhi Ansari Nagar','SYS-AIM-C01','robotic_patient_cart','medtronic_hugo_ras','OT-2','2026-07-07',
     true,'ok','fail',true,true,false,true,true,true,true,'removed_from_service','Arm 2 calibration fail and e-stop unresponsive — cart quarantined'),
    ('AIIMS Delhi Ansari Nagar','SYS-AIM-V01','or_integration_video','stryker_1788','OT-4','2026-07-07',
     true,'ok','not_applicable',true,true,true,true,true,true,true,'pass','1788 OR integration QC clean'),
    ('CMC Vellore','SYS-CMC-D01','4k_3d_display_wall','olympus_visera_elite','OT-6','2026-07-06',
     true,'ok','not_applicable',true,true,true,true,true,true,true,'pass','VISERA Elite II 4K display wall aligned'),
    ('CMC Vellore','SYS-CMC-C01','robotic_surgeon_console','intuitive_da_vinci','OT-7','2026-07-06',
     true,'lag_detected','pass',true,true,true,false,true,true,true,'fail','Network recording dropped frames and 3D feed lag — recording server check'),
    ('KIMS Hyderabad Kondapur','SYS-KIM-C01','robotic_patient_cart','medtronic_hugo_ras','OT-3','2026-07-05',
     true,'ok','drift',true,true,true,true,true,true,false,'conditional_pass','Calibration certificate lapsed — recal scheduled with OEM'),
    ('KIMS Hyderabad Kondapur','SYS-KIM-V01','or_integration_video','getinge_tegris','OT-1','2026-07-05',
     false,'fail','not_applicable',true,true,true,true,true,true,true,'fail','Tegris routing matrix switch fault — no video to display 2'),
    ('Fortis Mulund Mumbai','SYS-FRT-C03','robotic_vision_cart','stryker_1788','OT-2','2026-07-04',
     true,'ok','not_applicable',true,true,true,true,true,true,true,'pass',null),
    ('Narayana Health Bengaluru','SYS-NRY-C01','robotic_surgeon_console','medtronic_hugo_ras','OT-8','2026-07-04',
     true,'ok','pass',true,true,true,true,true,true,true,'pass','Hugo RAS surgeon console QC pass')
  ) as q(hosp, scode, stype, vendor, otn, cdate, vro, ilo, rack, irk, tdda, eso, nro, sdio, elr, cc, qv, nt);

  -- CAPA seed — attach to specific checks via system_code
  insert into public.or_robotic_qc_capa_actions_r3339 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SYS-FRT-D01','3d_display_misalignment','display_calibration_drift','recalibrate_3d_display','in_progress','nabh_finding','2026-07-14',null,35000.00,'3D polarizer recal booked with Sony field engineer'),
    ('SYS-AIM-C01','emergency_stop_failure','estop_circuit_fault','repair_estop_circuit','escalated','patient_safety_alert','2026-07-11',null,120000.00,'E-stop unresponsive — Medtronic field service escalated, cart quarantined'),
    ('SYS-CMC-C01','network_recording_failure','recording_server_full','expand_recording_storage','open','iso_13485_deviation','2026-07-13',null,58000.00,'Recording server at capacity — storage expansion quoted'),
    ('SYS-KIM-V01','video_routing_failure','video_matrix_switch_fault','replace_video_matrix_switch','open','cdsco_notifiable','2026-07-12',null,90000.00,'Tegris matrix switch RMA raised with Getinge'),
    ('SYS-MNP-V02','instrument_recognition_failure','instrument_rfid_reader_fault','replace_rfid_reader','verification_pending','internal_only','2026-07-15',null,26000.00,'RFID reader swapped — verify on next Versius case day'),
    ('SYS-KIM-C01','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','nabh_finding','2026-07-02',null,15000.00,'Calibration cert lapsed 3 days — OEM slot pending'),
    ('SYS-FRT-V01','image_latency','network_congestion','optimize_network_qos','closed','internal_only','2026-07-12','2026-07-11',8000.00,'QoS priority applied to OR video VLAN — latency back to 40ms')
  ) as q(scode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.or_robotic_qc_r3339 e
    on e.organization_id = v_org_id and e.system_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3339_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.or_robotic_qc_r3339)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.or_robotic_qc_r3339 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3339_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3339_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3339_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  latency_fail bigint,
  arm_cal_fail bigint,
  estop_fail bigint,
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
    count(*) filter (where l.image_latency_ok in ('lag_detected','fail'))::bigint,
    count(*) filter (where l.robotic_arm_calibration_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.or_robotic_qc_r3339 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3339_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3339_hospital_scorecard() to authenticated;

-- 3) Vendor × system-type matrix
create or replace function public.founder_r3339_vendor_system_matrix()
returns table(system_vendor text, system_type text, checks bigint, passed bigint, latency_issues bigint, arm_cal_issues bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_vendor, l.system_type, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.image_latency_ok in ('lag_detected','fail'))::bigint,
    count(*) filter (where l.robotic_arm_calibration_ok in ('drift','fail'))::bigint
  from public.or_robotic_qc_r3339 l
  group by l.system_vendor, l.system_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3339_vendor_system_matrix() from public, anon;
grant execute on function public.founder_r3339_vendor_system_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3339_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, latency_fail bigint, arm_cal_fail bigint)
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
    count(*) filter (where l.image_latency_ok in ('lag_detected','fail'))::bigint,
    count(*) filter (where l.robotic_arm_calibration_ok in ('drift','fail'))::bigint
  from public.or_robotic_qc_r3339 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3339_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3339_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3339_capa_status_board()
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
  from public.or_robotic_qc_capa_actions_r3339 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3339_capa_status_board() from public, anon;
grant execute on function public.founder_r3339_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3339_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.or_robotic_qc_capa_actions_r3339)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.or_robotic_qc_capa_actions_r3339 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3339_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3339_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3339_regulatory_impact_digest()
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
  from public.or_robotic_qc_capa_actions_r3339 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3339_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3339_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3339_high_risk_queue()
returns table(
  hospital_name text,
  ot_number text,
  system_code text,
  system_type text,
  check_date date,
  qc_verdict text,
  image_latency_ok text,
  robotic_arm_calibration_ok text,
  emergency_stop_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_number, l.system_code, l.system_type, l.check_date,
    l.qc_verdict, l.image_latency_ok, l.robotic_arm_calibration_ok, l.emergency_stop_ok, l.notes
  from public.or_robotic_qc_r3339 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.image_latency_ok in ('lag_detected','fail')
     or l.robotic_arm_calibration_ok in ('drift','fail')
     or l.emergency_stop_ok = false
     or l.video_routing_ok = false
     or l.three_d_display_alignment_ok = false
     or l.instrument_recognition_ok = false
     or l.network_recording_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3339_high_risk_queue() from public, anon;
grant execute on function public.founder_r3339_high_risk_queue() to authenticated;
