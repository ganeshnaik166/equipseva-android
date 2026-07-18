-- Round 3258: Customer Hospital Ophthalmic Refraction-Lane Equipment QC Audit
-- Refraction-lane QA — device type × model-eye verification × sphere/cylinder accuracy × chart luminance × lens-disc condition × chin-rest hygiene × printer output × annual calibration × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_refraction_qc_r3258 — per-device refraction-lane QC checks
-- =============================================================================
create table if not exists public.ophthalmic_refraction_qc_r3258 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'autorefractor','phoropter_manual','phoropter_digital','keratometer','lensmeter','chart_projector_lcd'
  )),
  opd_lane text not null,
  check_date date not null,
  model_eye_verification text not null check (model_eye_verification in (
    'pass','drift_detected','fail','not_applicable'
  )),
  sphere_accuracy_error_d numeric(4,2),
  cylinder_axis_error_deg numeric(4,1),
  chart_luminance_ok boolean,
  lens_disc_condition text check (lens_disc_condition in (
    'clean','scratched','sticking','jammed'
  )),
  chin_rest_hygiene_ok boolean,
  printer_output_ok text not null check (printer_output_ok in (
    'ok','faded','faulty','not_configured'
  )),
  annual_calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_refraction_qc_r3258 enable row level security;

create index if not exists idx_ophthalmic_qc_r3258_org on public.ophthalmic_refraction_qc_r3258(organization_id);
create index if not exists idx_ophthalmic_qc_r3258_date on public.ophthalmic_refraction_qc_r3258(check_date);
create index if not exists idx_ophthalmic_qc_r3258_verdict on public.ophthalmic_refraction_qc_r3258(qc_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_refraction_qc_capa_actions_r3258 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ophthalmic_refraction_qc_capa_actions_r3258 (
  id uuid primary key default gen_random_uuid(),
  qc_check_id uuid not null references public.ophthalmic_refraction_qc_r3258(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'sphere_accuracy_drift','axis_alignment_error','model_eye_failure','lens_disc_mechanical',
    'chart_luminance_low','printer_output_failure','hygiene_lapse','calibration_overdue'
  )),
  root_cause text not null check (root_cause in (
    'optical_head_misalignment','lens_disc_dirt_ingress','projector_lamp_aging','printer_head_worn',
    'calibration_vendor_backlog','operator_handling_damage','disinfection_protocol_lapse','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_with_model_eye','clean_and_lubricate_lens_disc','replace_projector_lamp','replace_printer_head',
    'schedule_oem_calibration','retrain_optometry_staff','remove_from_service','deep_clean_and_disinfect','none_required'
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

alter table public.ophthalmic_refraction_qc_capa_actions_r3258 enable row level security;

create index if not exists idx_ophthalmic_capa_r3258_check on public.ophthalmic_refraction_qc_capa_actions_r3258(qc_check_id);
create index if not exists idx_ophthalmic_capa_r3258_status on public.ophthalmic_refraction_qc_capa_actions_r3258(capa_status);

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
  insert into public.ophthalmic_refraction_qc_r3258 (
    organization_id, hospital_name, device_code, device_type, opd_lane,
    check_date, model_eye_verification, sphere_accuracy_error_d, cylinder_axis_error_deg,
    chart_luminance_ok, lens_disc_condition, chin_rest_hygiene_ok,
    printer_output_ok, annual_calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dev, q.dt, q.lane,
    q.cd::date, q.mev, q.sph, q.axz,
    q.lum, q.ldc, q.chin,
    q.prn, q.cal, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','ARF-APL-101','autorefractor','OPD-LANE-1','2026-07-03','pass',
     0.12,2.0,null,null,true,'ok',true,'pass','Quarterly QC — sphere within 0.25 D of model eye'),
    ('Apollo Chennai Greams Road','CHP-APL-102','chart_projector_lcd','OPD-LANE-1','2026-07-03','not_applicable',
     null,null,true,null,null,'not_configured',true,'pass','Luminance 210 cd/m2 — chart legible at 6 m'),
    ('Fortis Gurgaon Sector 44','ARF-FRT-201','autorefractor','OPD-LANE-2','2026-07-02','drift_detected',
     0.62,3.5,null,null,true,'faded',false,'conditional_pass','Sphere drift 0.62 D and printer faded — recalibration booked'),
    ('Fortis Gurgaon Sector 44','PHR-FRT-202','phoropter_manual','OPD-LANE-2','2026-07-02','not_applicable',
     null,null,null,'sticking',true,'not_configured',true,'conditional_pass','Cylinder lens disc sticking at -2.00 D step'),
    ('Manipal Old Airport Road Bengaluru','KER-MNP-301','keratometer','OPD-LANE-1','2026-07-01','pass',
     0.09,1.0,null,null,true,'ok',true,'pass','Calibration spheres verified — within tolerance'),
    ('Manipal Old Airport Road Bengaluru','LSM-MNP-302','lensmeter','OPD-LANE-1','2026-07-01','fail',
     0.88,6.0,null,'scratched',null,'faulty',false,'fail','Reads +0.88 D high on reference lens — pulled for service'),
    ('AIIMS New Delhi RP Centre','PHR-AIM-401','phoropter_digital','OPD-LANE-3','2026-06-30','pass',
     0.05,0.5,null,'clean',true,'ok',true,'pass','Digital phoropter sync with acuity chart verified'),
    ('AIIMS New Delhi RP Centre','ARF-AIM-402','autorefractor','OPD-LANE-4','2026-06-30','fail',
     1.25,8.0,null,null,false,'ok',false,'removed_from_service','Model eye fail 1.25 D and chin rest soiled — unit removed'),
    ('CMC Vellore Schell Eye Hospital','CHP-CMC-501','chart_projector_lcd','OPD-LANE-2','2026-06-29','not_applicable',
     null,null,false,null,null,'not_configured',true,'fail','Luminance 85 cd/m2 below 120 floor — lamp aging'),
    ('CMC Vellore Schell Eye Hospital','KER-CMC-502','keratometer','OPD-LANE-2','2026-06-29','pass',
     0.11,1.5,null,null,true,'ok',true,'pass','Annual QC clean pass'),
    ('KIMS Secunderabad','PHR-KIM-601','phoropter_manual','OPD-LANE-1','2026-06-28','not_applicable',
     null,null,null,'jammed',false,'not_configured',true,'fail','Sphere disc jammed at +3.00 D — mechanical service raised'),
    ('Sankara Nethralaya Chennai','ARF-SNK-701','autorefractor','OPD-LANE-5','2026-06-27','pass',
     0.18,2.5,null,null,true,'ok',true,'pass','High-volume lane QC — all parameters nominal'),
    ('LV Prasad Eye Institute Hyderabad','LSM-LVP-801','lensmeter','OPD-LANE-2','2026-06-27','drift_detected',
     0.42,4.5,null,'clean',null,'ok',true,'conditional_pass','Axis error 4.5 deg above 3 deg tolerance — watch list'),
    ('Aravind Eye Hospital Madurai','PHR-ARV-901','phoropter_digital','OPD-LANE-3','2026-06-26','not_applicable',
     null,null,null,'clean',true,'faulty',true,'conditional_pass','Rx printer faulty — manual transcription in use')
  ) as q(hosp, dev, dt, lane, cd, mev, sph, axz, lum, ldc, chin, prn, cal, qv, nt);

  -- CAPA seed — attach to specific QC checks via device code
  insert into public.ophthalmic_refraction_qc_capa_actions_r3258 (
    qc_check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ARF-FRT-201','sphere_accuracy_drift','optical_head_misalignment','recalibrate_with_model_eye','in_progress','internal_only','2026-07-08',null,15000.00,'OEM engineer Suresh Iyer scheduled for on-site recalibration'),
    ('PHR-FRT-202','lens_disc_mechanical','lens_disc_dirt_ingress','clean_and_lubricate_lens_disc','closed','none','2026-07-05','2026-07-04',3500.00,'Disc stripped, cleaned and lubricated — smooth action restored'),
    ('LSM-MNP-302','model_eye_failure','calibration_vendor_backlog','schedule_oem_calibration','escalated','nabh_finding','2026-07-06',null,22000.00,'Vendor backlog 3 weeks — escalated to biomedical head Priya Nair'),
    ('ARF-AIM-402','model_eye_failure','operator_handling_damage','remove_from_service','verification_pending','patient_safety_alert','2026-07-04',null,85000.00,'Unit dropped during lane shift — replacement quote from Nidek awaited'),
    ('CHP-CMC-501','chart_luminance_low','projector_lamp_aging','replace_projector_lamp','open','internal_only','2026-07-07',null,8500.00,'LCD backlight module on order — interim printed chart in use'),
    ('PHR-KIM-601','lens_disc_mechanical','pending_investigation','schedule_oem_calibration','overdue','nabh_finding','2026-06-25',null,12000.00,'Past target date — OEM visit slipped twice, chased by Ramesh Kulkarni'),
    ('PHR-ARV-901','printer_output_failure','printer_head_worn','replace_printer_head','in_progress','none','2026-07-09',null,4200.00,'Thermal head replacement in progress — spares from Chennai depot')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ophthalmic_refraction_qc_r3258 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3258_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_refraction_qc_r3258)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_refraction_qc_r3258 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3258_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3258_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3258_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  model_eye_issues bigint,
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
    count(*) filter (where l.model_eye_verification in ('drift_detected','fail'))::bigint,
    count(*) filter (where not l.annual_calibration_current)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_refraction_qc_r3258 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3258_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3258_hospital_scorecard() to authenticated;

-- 3) Device type × OPD lane matrix
create or replace function public.founder_r3258_device_lane_matrix()
returns table(device_type text, opd_lane text, checks bigint, passed bigint, avg_sphere_error_d numeric, avg_axis_error_deg numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.opd_lane, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.sphere_accuracy_error_d), 2),
    round(avg(l.cylinder_axis_error_deg), 1)
  from public.ophthalmic_refraction_qc_r3258 l
  group by l.device_type, l.opd_lane
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3258_device_lane_matrix() from public, anon;
grant execute on function public.founder_r3258_device_lane_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3258_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, model_eye_issues bigint, calibration_lapsed bigint)
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
    count(*) filter (where l.model_eye_verification in ('drift_detected','fail'))::bigint,
    count(*) filter (where not l.annual_calibration_current)::bigint
  from public.ophthalmic_refraction_qc_r3258 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3258_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3258_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3258_capa_status_board()
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
  from public.ophthalmic_refraction_qc_capa_actions_r3258 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3258_capa_status_board() from public, anon;
grant execute on function public.founder_r3258_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3258_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_refraction_qc_capa_actions_r3258)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_refraction_qc_capa_actions_r3258 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3258_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3258_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3258_regulatory_impact_digest()
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
  from public.ophthalmic_refraction_qc_capa_actions_r3258 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3258_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3258_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3258_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  opd_lane text,
  check_date date,
  qc_verdict text,
  model_eye_verification text,
  lens_disc_condition text,
  printer_output_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.opd_lane, l.check_date,
    l.qc_verdict, l.model_eye_verification, l.lens_disc_condition, l.printer_output_ok,
    l.notes
  from public.ophthalmic_refraction_qc_r3258 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.model_eye_verification in ('drift_detected','fail')
     or l.lens_disc_condition in ('sticking','jammed')
     or l.printer_output_ok in ('faded','faulty')
     or l.chart_luminance_ok = false
     or l.chin_rest_hygiene_ok = false
     or l.annual_calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3258_high_risk_queue() from public, anon;
grant execute on function public.founder_r3258_high_risk_queue() to authenticated;
