-- Round 3354: Customer Hospital Radiotherapy MLC / EPID / IGRT Positioning QC Audit
-- Linac positioning QA — subsystem type × MLC leaf error × picket-fence × EPID image quality × IGRT/CBCT isocenter × couch shift × gating latency × Winston-Lutz × laser coincidence × calibration × CAPA

-- =============================================================================
-- TABLE 1: radiotherapy_positioning_qc_r3354 — per-subsystem positioning QC checks
-- =============================================================================
create table if not exists public.radiotherapy_positioning_qc_r3354 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  linac_code text not null,
  linac_vendor text not null check (linac_vendor in (
    'varian_truebeam','varian_halcyon','varian_clinac_ix','elekta_versa_hd','elekta_synergy','elekta_infinity'
  )),
  qc_ref text not null,
  subsystem_type text not null check (subsystem_type in (
    'mlc_leaf_positioning','epid_portal_imaging','igrt_cbct','surface_guided_rt','respiratory_gating','laser_alignment'
  )),
  check_date date not null,
  checked_at timestamptz not null,
  mlc_leaf_position_error_mm numeric(5,2),
  picket_fence_pass boolean,
  epid_image_quality_ok boolean,
  igrt_isocenter_accuracy_mm numeric(5,2),
  couch_shift_accuracy_ok boolean,
  gating_latency_ok text not null check (gating_latency_ok in (
    'ok','high','not_applicable'
  )),
  winston_lutz_pass boolean,
  laser_coincidence_ok boolean,
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.radiotherapy_positioning_qc_r3354 enable row level security;

create index if not exists idx_rt_pos_qc_r3354_org on public.radiotherapy_positioning_qc_r3354(organization_id);
create index if not exists idx_rt_pos_qc_r3354_date on public.radiotherapy_positioning_qc_r3354(check_date);
create index if not exists idx_rt_pos_qc_r3354_verdict on public.radiotherapy_positioning_qc_r3354(qc_verdict);

-- =============================================================================
-- TABLE 2: radiotherapy_positioning_qc_capa_actions_r3354 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.radiotherapy_positioning_qc_capa_actions_r3354 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.radiotherapy_positioning_qc_r3354(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'mlc_leaf_position_error','picket_fence_failure','epid_image_quality','igrt_isocenter_error',
    'couch_shift_error','gating_latency_high','winston_lutz_failure','laser_misalignment',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'mlc_motor_wear','mlc_calibration_drift','epid_panel_degradation','cbct_registration_error',
    'couch_encoder_fault','gating_sensor_latency','isocenter_drift','laser_mount_shift',
    'software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_mlc_leaves','replace_mlc_motor','replace_epid_panel','recalibrate_cbct_registration',
    'service_couch_encoder','tune_gating_system','realign_isocenter','realign_lasers',
    'update_software_config','retrain_rt_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_finding','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.radiotherapy_positioning_qc_capa_actions_r3354 enable row level security;

create index if not exists idx_rt_pos_qc_capa_r3354_log on public.radiotherapy_positioning_qc_capa_actions_r3354(qc_log_id);
create index if not exists idx_rt_pos_qc_capa_r3354_status on public.radiotherapy_positioning_qc_capa_actions_r3354(capa_status);

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

  -- 14 positioning-QC rows
  insert into public.radiotherapy_positioning_qc_r3354 (
    organization_id, hospital_name, linac_code, linac_vendor, qc_ref,
    subsystem_type, check_date, checked_at,
    mlc_leaf_position_error_mm, picket_fence_pass, epid_image_quality_ok,
    igrt_isocenter_accuracy_mm, couch_shift_accuracy_ok, gating_latency_ok,
    winston_lutz_pass, laser_coincidence_ok, calibration_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.linac, q.vendor, q.ref,
    q.sub, q.cd::date, q.cat::timestamptz,
    q.mlc, q.pf, q.epid,
    q.iso, q.couch, q.gate,
    q.wl, q.laser, q.calib,
    q.qv, q.nt
  from (values
    ('Apollo Cancer Centre Chennai','LINAC-APL-1','varian_truebeam','RT-APL-101','mlc_leaf_positioning','2026-07-05','2026-07-05 07:10:00+05:30',
     0.35,true,true,0.42,true,'not_applicable',true,true,true,'pass','Monthly MLC QC — picket-fence clean, max leaf error 0.35mm'),
    ('Apollo Cancer Centre Chennai','LINAC-APL-1','varian_truebeam','RT-APL-102','mlc_leaf_positioning','2026-07-05','2026-07-05 08:00:00+05:30',
     1.15,false,null,null,null,'not_applicable',null,null,true,'fail','Picket-fence failed — max leaf error 1.15mm exceeds 1mm tolerance'),
    ('Fortis Memorial Gurgaon','LINAC-FMG-1','elekta_versa_hd','RT-FMG-201','epid_portal_imaging','2026-07-04','2026-07-04 06:45:00+05:30',
     null,null,true,null,null,'not_applicable',null,null,true,'pass','EPID flatness and symmetry within spec'),
    ('Fortis Memorial Gurgaon','LINAC-FMG-1','elekta_versa_hd','RT-FMG-202','epid_portal_imaging','2026-07-04','2026-07-04 07:30:00+05:30',
     null,null,false,null,null,'not_applicable',null,null,true,'conditional_pass','EPID panel dead-pixel cluster — image quality degraded, physicist watch'),
    ('Manipal Hospital Old Airport Road Bengaluru','LINAC-MNP-2','varian_halcyon','RT-MNP-301','igrt_cbct','2026-07-03','2026-07-03 08:15:00+05:30',
     null,null,true,0.68,true,'not_applicable',true,null,true,'pass','CBCT-to-plan isocenter 0.68mm, couch auto-shift verified'),
    ('Manipal Hospital Old Airport Road Bengaluru','LINAC-MNP-2','varian_halcyon','RT-MNP-302','igrt_cbct','2026-07-03','2026-07-03 09:00:00+05:30',
     null,null,true,1.85,false,'not_applicable',false,null,true,'fail','CBCT isocenter 1.85mm off and couch shift out of tolerance'),
    ('AIIMS Delhi','LINAC-AIM-3','elekta_synergy','RT-AIM-401','respiratory_gating','2026-07-02','2026-07-02 07:20:00+05:30',
     null,null,null,null,null,'ok',null,null,true,'pass','Gated beam-on latency within 60ms window'),
    ('AIIMS Delhi','LINAC-AIM-3','elekta_synergy','RT-AIM-402','respiratory_gating','2026-07-02','2026-07-02 08:10:00+05:30',
     null,null,null,null,null,'high',null,null,true,'conditional_pass','Gating latency high — beam-on delay 120ms, RPM box re-test booked'),
    ('CMC Vellore','LINAC-CMC-1','varian_clinac_ix','RT-CMC-501','laser_alignment','2026-07-01','2026-07-01 06:30:00+05:30',
     null,null,null,null,null,'not_applicable',null,false,true,'fail','Sagittal laser 2mm off isocenter — patient setup risk'),
    ('CMC Vellore','LINAC-CMC-1','varian_clinac_ix','RT-CMC-502','surface_guided_rt','2026-07-01','2026-07-01 07:15:00+05:30',
     null,null,null,0.55,true,'not_applicable',null,true,true,'pass','SGRT surface-to-CBCT agreement 0.55mm'),
    ('KIMS Hyderabad','LINAC-KIM-2','elekta_infinity','RT-KIM-601','igrt_cbct','2026-06-30','2026-06-30 08:20:00+05:30',
     null,null,true,0.90,true,'not_applicable',false,null,false,'removed_from_service','Winston-Lutz failed and MU calibration lapsed — linac withdrawn'),
    ('Tata Memorial Hospital Mumbai','LINAC-TMH-4','varian_truebeam','RT-TMH-701','mlc_leaf_positioning','2026-06-29','2026-06-29 07:05:00+05:30',
     0.28,true,null,null,null,'not_applicable',null,null,true,'pass','MLC leaf QC nominal, picket-fence clean'),
    ('HCG Cancer Centre Bengaluru','LINAC-HCG-1','varian_halcyon','RT-HCG-801','surface_guided_rt','2026-06-28','2026-06-28 08:40:00+05:30',
     null,null,null,1.40,false,'not_applicable',null,true,true,'conditional_pass','SGRT tracking drift, couch correction borderline at 1.4mm'),
    ('Amrita Hospital Kochi','LINAC-AMR-2','elekta_versa_hd','RT-AMR-901','laser_alignment','2026-06-28','2026-06-28 06:50:00+05:30',
     null,null,null,null,null,'not_applicable',null,true,true,'pass','Room laser coincidence within 1mm of isocenter')
  ) as q(hosp, linac, vendor, ref, sub, cd, cat, mlc, pf, epid, iso, couch, gate, wl, laser, calib, qv, nt);

  -- CAPA seed — attach to specific checks via qc_ref
  insert into public.radiotherapy_positioning_qc_capa_actions_r3354 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RT-APL-102','mlc_leaf_position_error','mlc_calibration_drift','recalibrate_mlc_leaves','open','aerb_finding','2026-07-12',null,55000.00,'Leaf bank B recalibration scheduled with Varian field engineer'),
    ('RT-FMG-202','epid_image_quality','epid_panel_degradation','replace_epid_panel','in_progress','iso_13485_deviation','2026-07-15',null,320000.00,'aS1200 panel replacement quoted by Elekta, PO raised'),
    ('RT-MNP-302','igrt_isocenter_error','isocenter_drift','realign_isocenter','escalated','patient_safety_alert','2026-07-08',null,45000.00,'CBCT/MV isocenter coincidence escalated, treatments paused on unit'),
    ('RT-AIM-402','gating_latency_high','gating_sensor_latency','tune_gating_system','verification_pending','internal_only','2026-07-09',null,15000.00,'RPM camera firmware updated, awaiting gated end-to-end re-test'),
    ('RT-CMC-501','laser_misalignment','laser_mount_shift','realign_lasers','closed','internal_only','2026-07-05','2026-07-03',8000.00,'Wall lasers realigned to isocenter within 1mm, verified'),
    ('RT-KIM-601','winston_lutz_failure','isocenter_drift','remove_from_service','escalated','aerb_finding','2026-07-06',null,90000.00,'Linac withdrawn pending OEM isocenter service and AERB intimation'),
    ('RT-HCG-801','couch_shift_error','couch_encoder_fault','service_couch_encoder','overdue','nabh_finding','2026-06-30',null,60000.00,'Couch encoder service past target date — AMC vendor delayed')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.radiotherapy_positioning_qc_r3354 e
    on e.organization_id = v_org_id and e.qc_ref = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3354_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.radiotherapy_positioning_qc_r3354)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.radiotherapy_positioning_qc_r3354 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3354_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3354_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3354_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  picket_fence_fail bigint,
  winston_lutz_fail bigint,
  calibration_lapsed bigint,
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
    count(*) filter (where l.picket_fence_pass = false)::bigint,
    count(*) filter (where l.winston_lutz_pass = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.radiotherapy_positioning_qc_r3354 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3354_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3354_hospital_scorecard() to authenticated;

-- 3) Subsystem type × linac vendor matrix
create or replace function public.founder_r3354_subsystem_vendor_matrix()
returns table(subsystem_type text, linac_vendor text, checks bigint, passed bigint, avg_mlc_leaf_error_mm numeric, avg_igrt_isocenter_mm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.subsystem_type, l.linac_vendor, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.mlc_leaf_position_error_mm), 2),
    round(avg(l.igrt_isocenter_accuracy_mm), 2)
  from public.radiotherapy_positioning_qc_r3354 l
  group by l.subsystem_type, l.linac_vendor
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3354_subsystem_vendor_matrix() from public, anon;
grant execute on function public.founder_r3354_subsystem_vendor_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3354_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, picket_fence_fail bigint, winston_lutz_fail bigint)
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
    count(*) filter (where l.picket_fence_pass = false)::bigint,
    count(*) filter (where l.winston_lutz_pass = false)::bigint
  from public.radiotherapy_positioning_qc_r3354 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3354_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3354_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3354_capa_status_board()
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
  from public.radiotherapy_positioning_qc_capa_actions_r3354 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3354_capa_status_board() from public, anon;
grant execute on function public.founder_r3354_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3354_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.radiotherapy_positioning_qc_capa_actions_r3354)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.radiotherapy_positioning_qc_capa_actions_r3354 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3354_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3354_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3354_regulatory_impact_digest()
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
  from public.radiotherapy_positioning_qc_capa_actions_r3354 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3354_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3354_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3354_high_risk_queue()
returns table(
  hospital_name text,
  linac_code text,
  subsystem_type text,
  check_date date,
  qc_verdict text,
  mlc_leaf_position_error_mm numeric,
  igrt_isocenter_accuracy_mm numeric,
  gating_latency_ok text,
  calibration_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.linac_code, l.subsystem_type, l.check_date,
    l.qc_verdict, l.mlc_leaf_position_error_mm, l.igrt_isocenter_accuracy_mm,
    l.gating_latency_ok, l.calibration_current, l.notes
  from public.radiotherapy_positioning_qc_r3354 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.picket_fence_pass = false
     or l.epid_image_quality_ok = false
     or l.couch_shift_accuracy_ok = false
     or l.winston_lutz_pass = false
     or l.laser_coincidence_ok = false
     or l.calibration_current = false
     or l.gating_latency_ok = 'high'
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3354_high_risk_queue() from public, anon;
grant execute on function public.founder_r3354_high_risk_queue() to authenticated;
