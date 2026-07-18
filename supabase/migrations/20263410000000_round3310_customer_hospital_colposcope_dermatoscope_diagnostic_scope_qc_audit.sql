-- Round 3310: Customer Hospital Colposcope / Dermatoscope Diagnostic-Scope QC Audit
-- Gynae & derm diagnostic-scope QA — device type × optics clarity × magnification × illumination × green-filter × image-capture × cryo temperature × focus × infection-control × calibration × CAPA

-- =============================================================================
-- TABLE 1: diag_scope_qc_r3310 — per-device diagnostic-scope QC checks
-- =============================================================================
create table if not exists public.diag_scope_qc_r3310 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'optical_colposcope','video_colposcope','handheld_dermatoscope',
    'polarized_dermatoscope','cryotherapy_gun','led_examination_light'
  )),
  clinic text not null,
  check_date date not null,
  optics_clarity text not null check (optics_clarity in (
    'clear','minor_haze','degraded','fail'
  )),
  magnification_accuracy_ok boolean not null,
  illumination_lux_ok boolean not null,
  green_filter_ok text not null check (green_filter_ok in (
    'ok','degraded','not_applicable'
  )),
  image_capture_ok boolean not null,
  cryo_temperature_ok text not null check (cryo_temperature_ok in (
    'ok','weak','not_applicable'
  )),
  focus_mechanism_ok boolean not null,
  infection_control_wipe_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.diag_scope_qc_r3310 enable row level security;

create index if not exists idx_diag_scope_qc_r3310_org on public.diag_scope_qc_r3310(organization_id);
create index if not exists idx_diag_scope_qc_r3310_date on public.diag_scope_qc_r3310(check_date);
create index if not exists idx_diag_scope_qc_r3310_verdict on public.diag_scope_qc_r3310(qc_verdict);

-- =============================================================================
-- TABLE 2: diag_scope_qc_capa_actions_r3310 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.diag_scope_qc_capa_actions_r3310 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.diag_scope_qc_r3310(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'optics_degradation','magnification_drift','illumination_low','green_filter_fault',
    'image_capture_failure','cryo_temperature_weak','focus_mechanism_fault',
    'infection_control_gap','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lens_fungus_contamination','led_module_aging','fiber_optic_damage','filter_coating_degraded',
    'sensor_cable_fault','cryo_gas_low','focus_gear_worn','cleaning_protocol_lapse',
    'calibration_backlog','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'clean_or_replace_optics','replace_led_module','replace_fiber_bundle','replace_green_filter',
    'replace_image_sensor','refill_or_service_cryo','repair_focus_mechanism','reinforce_cleaning_sop',
    'recalibrate_device','remove_from_service','schedule_oem_service','none_required'
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

alter table public.diag_scope_qc_capa_actions_r3310 enable row level security;

create index if not exists idx_diag_scope_capa_r3310_log on public.diag_scope_qc_capa_actions_r3310(qc_log_id);
create index if not exists idx_diag_scope_capa_r3310_status on public.diag_scope_qc_capa_actions_r3310(capa_status);

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

  -- 14 diagnostic-scope QC rows
  insert into public.diag_scope_qc_r3310 (
    organization_id, hospital_name, device_code, device_type, clinic, check_date,
    optics_clarity, magnification_accuracy_ok, illumination_lux_ok, green_filter_ok,
    image_capture_ok, cryo_temperature_ok, focus_mechanism_ok, infection_control_wipe_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.clinic, q.chkd::date,
    q.oc, q.mag, q.illum, q.gf,
    q.imgc, q.cryo, q.focus, q.infc,
    q.calc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','DSQ-APL-C01','optical_colposcope','Gynae OPD','2026-07-05',
     'clear',true,true,'ok',true,'not_applicable',true,true,true,'pass','Quarterly QC — optics and calibration nominal'),
    ('Apollo Chennai Greams Road','DSQ-APL-V02','video_colposcope','Colposcopy Suite','2026-07-05',
     'minor_haze',true,true,'degraded',true,'not_applicable',true,true,true,'conditional_pass','Green-filter coating hazy — image review affected, recheck booked'),
    ('Fortis Gurgaon','DSQ-FRT-D01','handheld_dermatoscope','Dermatology OPD','2026-07-04',
     'clear',true,true,'not_applicable',false,'not_applicable',true,true,true,'pass',null),
    ('Fortis Gurgaon','DSQ-FRT-P02','polarized_dermatoscope','Derm Clinic 2','2026-07-04',
     'degraded',false,true,'not_applicable',true,'not_applicable',true,false,false,'fail','Polarizer degraded + magnification off + calibration overdue'),
    ('Manipal Bengaluru Old Airport Road','DSQ-MNP-CR1','cryotherapy_gun','Derm Procedure Room','2026-07-03',
     'clear',true,true,'not_applicable',false,'ok',true,true,true,'pass','Cryo tip temperature within spec'),
    ('Manipal Bengaluru Old Airport Road','DSQ-MNP-CR2','cryotherapy_gun','Derm Procedure Room 2','2026-07-03',
     'clear',true,true,'not_applicable',false,'weak',true,true,true,'conditional_pass','Cryo tip temperature weak — gas cylinder low, refill scheduled'),
    ('AIIMS Delhi Ansari Nagar','DSQ-AIM-V01','video_colposcope','Gynae Colposcopy','2026-07-02',
     'fail',true,false,'degraded',false,'not_applicable',false,true,false,'removed_from_service','Optics fail + illumination low + focus stuck — pulled from service'),
    ('AIIMS Delhi Ansari Nagar','DSQ-AIM-C02','optical_colposcope','Gynae OPD 2','2026-07-02',
     'clear',true,true,'ok',true,'not_applicable',true,true,true,'pass',null),
    ('CMC Vellore','DSQ-CMC-D01','handheld_dermatoscope','Dermatology Unit','2026-07-01',
     'minor_haze',true,true,'not_applicable',false,'not_applicable',true,false,true,'conditional_pass','Contact plate hazy + infection-control wipe log gap'),
    ('CMC Vellore','DSQ-CMC-L02','led_examination_light','Exam Room 3','2026-07-01',
     'clear',true,false,'not_applicable',false,'not_applicable',true,true,true,'conditional_pass','Illumination lux below spec — LED array aging'),
    ('KIMS Hyderabad','DSQ-KIM-P01','polarized_dermatoscope','Derm OPD','2026-06-30',
     'clear',true,true,'not_applicable',true,'not_applicable',true,true,true,'pass',null),
    ('KIMS Hyderabad','DSQ-KIM-CR2','cryotherapy_gun','Derm Procedure','2026-06-30',
     'clear',true,true,'not_applicable',false,'weak',true,true,false,'fail','Cryo output weak and calibration lapsed — service required'),
    ('Rainbow Children''s Hyderabad','DSQ-RBW-V01','video_colposcope','Adolescent Gynae','2026-06-29',
     'clear',true,true,'ok',true,'not_applicable',true,true,true,'pass',null),
    ('KIMS Hyderabad','DSQ-KIM-D03','handheld_dermatoscope','Derm OPD 2','2026-06-29',
     'degraded',false,true,'not_applicable',false,'not_applicable',false,true,false,'removed_from_service','Lens fungus + focus fail — removed, OEM optics service')
  ) as q(hosp, dcode, dtype, clinic, chkd, oc, mag, illum, gf, imgc, cryo, focus, infc, calc, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.diag_scope_qc_capa_actions_r3310 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DSQ-FRT-P02','optics_degradation','filter_coating_degraded','clean_or_replace_optics','in_progress','internal_only','2026-07-09',null,15000.00,'Polarizer + magnification issue — optics service in progress'),
    ('DSQ-AIM-V01','optics_degradation','fiber_optic_damage','replace_fiber_bundle','escalated','patient_safety_alert','2026-07-06',null,38000.00,'Video-colposcopy pulled — optics + focus repair escalated to OEM'),
    ('DSQ-MNP-CR2','cryo_temperature_weak','cryo_gas_low','refill_or_service_cryo','closed','internal_only','2026-07-05','2026-07-04',6500.00,'Gas cylinder refilled — tip temperature verified in range'),
    ('DSQ-KIM-CR2','cryo_temperature_weak','cryo_gas_low','refill_or_service_cryo','open','nabh_finding','2026-07-07',null,9000.00,'Cryo output weak + calibration lapsed — OEM service booked'),
    ('DSQ-KIM-D03','optics_degradation','lens_fungus_contamination','clean_or_replace_optics','in_progress','iso_13485_deviation','2026-07-08',null,22000.00,'Lens fungus — dispatched for OEM optics service'),
    ('DSQ-CMC-D01','infection_control_gap','cleaning_protocol_lapse','reinforce_cleaning_sop','verification_pending','nabh_finding','2026-07-05',null,0.00,'Wipe-log gap — SOP retraining done, audit verification pending'),
    ('DSQ-CMC-L02','illumination_low','led_module_aging','replace_led_module','overdue','internal_only','2026-06-28',null,11000.00,'LED array aging — replacement past target date, vendor delay')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.diag_scope_qc_r3310 e
    on e.organization_id = v_org_id and e.device_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3310_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.diag_scope_qc_r3310)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.diag_scope_qc_r3310 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3310_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3310_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3310_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  optics_fail bigint,
  illumination_fail bigint,
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
    count(*) filter (where l.optics_clarity in ('degraded','fail'))::bigint,
    count(*) filter (where l.illumination_lux_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.diag_scope_qc_r3310 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3310_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3310_hospital_scorecard() to authenticated;

-- 3) Device-type × optics-clarity matrix
create or replace function public.founder_r3310_device_type_clarity_matrix()
returns table(device_type text, optics_clarity text, checks bigint, passed bigint, magnification_fail bigint, focus_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.optics_clarity, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.magnification_accuracy_ok = false)::bigint,
    count(*) filter (where l.focus_mechanism_ok = false)::bigint
  from public.diag_scope_qc_r3310 l
  group by l.device_type, l.optics_clarity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3310_device_type_clarity_matrix() from public, anon;
grant execute on function public.founder_r3310_device_type_clarity_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3310_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, optics_fail bigint, calibration_overdue bigint)
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
    count(*) filter (where l.optics_clarity in ('degraded','fail'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.diag_scope_qc_r3310 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3310_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3310_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3310_capa_status_board()
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
  from public.diag_scope_qc_capa_actions_r3310 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3310_capa_status_board() from public, anon;
grant execute on function public.founder_r3310_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3310_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.diag_scope_qc_capa_actions_r3310)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.diag_scope_qc_capa_actions_r3310 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3310_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3310_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3310_regulatory_impact_digest()
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
  from public.diag_scope_qc_capa_actions_r3310 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3310_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3310_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3310_high_risk_queue()
returns table(
  hospital_name text,
  clinic text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  optics_clarity text,
  green_filter_ok text,
  cryo_temperature_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.clinic, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.optics_clarity, l.green_filter_ok, l.cryo_temperature_ok, l.notes
  from public.diag_scope_qc_r3310 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.optics_clarity in ('degraded','fail')
     or l.magnification_accuracy_ok = false
     or l.illumination_lux_ok = false
     or l.image_capture_ok = false
     or l.focus_mechanism_ok = false
     or l.infection_control_wipe_ok = false
     or l.calibration_current = false
     or l.cryo_temperature_ok = 'weak'
     or l.green_filter_ok = 'degraded'
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3310_high_risk_queue() from public, anon;
grant execute on function public.founder_r3310_high_risk_queue() to authenticated;
