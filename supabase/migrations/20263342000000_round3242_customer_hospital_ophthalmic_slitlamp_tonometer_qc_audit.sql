-- Round 3242: Customer Hospital Ophthalmology OPD Slit-Lamp & Tonometer QC Audit
-- Eye-OPD QA — device type × illumination × optics clarity × tonometer calibration error × probe/prism condition × disinfection log × mount stability × QC verdict × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_slitlamp_tonometer_r3242 — per-device QC checks
-- =============================================================================
create table if not exists public.ophthalmic_slitlamp_tonometer_r3242 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'slit_lamp','goldmann_tonometer','non_contact_tonometer','icare_rebound'
  )),
  exam_room text not null,
  check_date date not null,
  illumination_lux_or_pct numeric(6,1),
  optics_clarity text not null check (optics_clarity in (
    'clear','minor_haze','degraded'
  )),
  tonometer_calibration_error_mmhg numeric(4,1),
  probe_or_prism_condition text not null check (probe_or_prism_condition in (
    'good','scratched','replace_due','not_applicable'
  )),
  disinfection_log_ok boolean not null,
  mount_stability text not null check (mount_stability in (
    'stable','loose','play_detected'
  )),
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  checked_by text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_slitlamp_tonometer_r3242 enable row level security;

create index if not exists idx_ophthal_slitlamp_r3242_org on public.ophthalmic_slitlamp_tonometer_r3242(organization_id);
create index if not exists idx_ophthal_slitlamp_r3242_date on public.ophthalmic_slitlamp_tonometer_r3242(check_date);
create index if not exists idx_ophthal_slitlamp_r3242_verdict on public.ophthalmic_slitlamp_tonometer_r3242(qc_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_slitlamp_tonometer_capa_actions_r3242 — CAPA findings
-- =============================================================================
create table if not exists public.ophthalmic_slitlamp_tonometer_capa_actions_r3242 (
  id uuid primary key default gen_random_uuid(),
  qc_check_id uuid not null references public.ophthalmic_slitlamp_tonometer_r3242(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'illumination_low','optics_degradation','tonometer_calibration_drift','prism_probe_wear',
    'disinfection_lapse','mount_instability','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'bulb_led_aging','optics_fungus_haze','calibration_weight_error','prism_scratches',
    'staff_process_gap','mounting_screw_loose','pending_investigation','service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_bulb_led','clean_and_defungus_optics','recalibrate_tonometer','replace_prism_or_probe',
    'retrain_opd_staff','tighten_and_service_mount','remove_from_service','schedule_oem_service','none_required'
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

alter table public.ophthalmic_slitlamp_tonometer_capa_actions_r3242 enable row level security;

create index if not exists idx_ophthal_capa_r3242_check on public.ophthalmic_slitlamp_tonometer_capa_actions_r3242(qc_check_id);
create index if not exists idx_ophthal_capa_r3242_status on public.ophthalmic_slitlamp_tonometer_capa_actions_r3242(capa_status);

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
  insert into public.ophthalmic_slitlamp_tonometer_r3242 (
    organization_id, hospital_name, device_code, device_type, exam_room,
    check_date, illumination_lux_or_pct, optics_clarity,
    tonometer_calibration_error_mmhg, probe_or_prism_condition,
    disinfection_log_ok, mount_stability, qc_verdict, checked_by, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.room,
    q.cdate::date, q.illum, q.optics,
    q.cerr, q.ppc,
    q.dis, q.mnt, q.qv, q.cb, q.nt
  from (values
    ('Apollo Chennai Greams Road','SL-APL-001','slit_lamp','OPD-EYE-1','2026-07-03',
     94.0,'clear',null,'not_applicable',true,'stable','pass','Ramesh Iyer','Quarterly QC — illumination and optics nominal'),
    ('Apollo Chennai Greams Road','GT-APL-002','goldmann_tonometer','OPD-EYE-1','2026-07-03',
     null,'clear',0.5,'good',true,'stable','pass','Ramesh Iyer','Calibration within 0.5 mmHg at 20 and 60 check positions'),
    ('Fortis Gurgaon','SL-FRT-101','slit_lamp','OPD-EYE-2','2026-07-02',
     68.5,'minor_haze',null,'not_applicable',true,'loose','conditional_pass','Priya Nair','Illumination 68.5% below 75% floor and swivel arm loose'),
    ('Fortis Gurgaon','NCT-FRT-102','non_contact_tonometer','OPD-EYE-2','2026-07-02',
     null,'clear',1.8,'good',false,'stable','conditional_pass','Priya Nair','Disinfection log missing 4 entries over last fortnight'),
    ('Manipal Bengaluru Old Airport Road','GT-MNP-201','goldmann_tonometer','OPD-EYE-1','2026-07-01',
     null,'clear',3.6,'scratched',true,'stable','fail','Arjun Mehta','Calibration 3.6 mmHg off at 2g weight — prism also scratched'),
    ('Manipal Bengaluru Old Airport Road','SL-MNP-202','slit_lamp','OPD-EYE-3','2026-07-01',
     88.0,'clear',null,'not_applicable',true,'stable','pass','Arjun Mehta','Clean pass post bulb replacement'),
    ('AIIMS New Delhi RP Centre','SL-AIM-301','slit_lamp','OPD-EYE-4','2026-06-30',
     55.0,'degraded',null,'not_applicable',true,'play_detected','removed_from_service','Sunita Reddy','Fungal haze on objective and joystick play — unit pulled'),
    ('AIIMS New Delhi RP Centre','ICR-AIM-302','icare_rebound','OPD-EYE-4','2026-06-30',
     null,'clear',1.1,'good',true,'stable','pass','Sunita Reddy','Rebound tonometer verified with reference test probe'),
    ('CMC Vellore','GT-CMC-401','goldmann_tonometer','OPD-EYE-2','2026-06-29',
     null,'minor_haze',2.4,'replace_due',false,'stable','fail','Vikram Singh','Prism past disinfection cycle limit and 2.4 mmHg drift'),
    ('CMC Vellore','NCT-CMC-402','non_contact_tonometer','OPD-EYE-2','2026-06-29',
     null,'clear',0.9,'good',true,'stable','pass','Vikram Singh','Puff nozzle alignment verified against manometer'),
    ('KIMS Hyderabad','SL-KIM-501','slit_lamp','OPD-EYE-1','2026-06-28',
     91.5,'clear',null,'not_applicable',true,'stable','pass','Kavitha Krishnan','Annual QC clean pass'),
    ('KIMS Hyderabad','NCT-KIM-502','non_contact_tonometer','OPD-EYE-1','2026-06-28',
     null,'clear',4.2,'good',true,'loose','fail','Kavitha Krishnan','Reads 4.2 mmHg high vs Goldmann reference — chin rest loose'),
    ('Sankara Nethralaya Chennai','GT-SNK-601','goldmann_tonometer','OPD-EYE-5','2026-06-27',
     null,'clear',0.4,'good',true,'stable','pass','Deepak Sharma','Reference standard check — exemplary calibration log'),
    ('LV Prasad Eye Institute Hyderabad','SL-LVP-701','slit_lamp','OPD-EYE-2','2026-06-27',
     72.0,'minor_haze',null,'not_applicable',true,'stable','conditional_pass','Deepak Sharma','Illumination marginal at 72% and early eyepiece haze — cleaning scheduled')
  ) as q(hosp, code, dtype, room, cdate, illum, optics, cerr, ppc, dis, mnt, qv, cb, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.ophthalmic_slitlamp_tonometer_capa_actions_r3242 (
    qc_check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SL-FRT-101','illumination_low','bulb_led_aging','replace_bulb_led','in_progress','internal_only','2026-07-08',null,3500.00,'LED module ordered — swivel arm tightened on-site'),
    ('GT-MNP-201','tonometer_calibration_drift','calibration_weight_error','recalibrate_tonometer','open','nabh_finding','2026-07-09',null,6000.00,'Calibration bar check failed at 2g position — OEM jig booked'),
    ('SL-AIM-301','optics_degradation','optics_fungus_haze','remove_from_service','escalated','patient_safety_alert','2026-07-05',null,48000.00,'Fungal etching on objective — unit condemned pending replacement'),
    ('GT-CMC-401','prism_probe_wear','prism_scratches','replace_prism_or_probe','closed','iso_13485_deviation','2026-07-02','2026-06-30',5200.00,'New applanation prism fitted and disinfection cycle log reset'),
    ('NCT-KIM-502','tonometer_calibration_drift','pending_investigation','schedule_oem_service','verification_pending','internal_only','2026-07-06',null,15000.00,'Reads high vs Goldmann — OEM serviced pressure chamber, reverify due'),
    ('NCT-FRT-102','disinfection_lapse','staff_process_gap','retrain_opd_staff','overdue','nabh_finding','2026-06-25',null,0.00,'Retraining past target date — OPD nursing roster clash'),
    ('SL-LVP-701','optics_degradation','optics_fungus_haze','clean_and_defungus_optics','in_progress','none','2026-07-10',null,2500.00,'Eyepiece haze cleaning scheduled with optics kit')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ophthalmic_slitlamp_tonometer_r3242 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3242_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_slitlamp_tonometer_r3242)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_slitlamp_tonometer_r3242 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3242_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3242_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3242_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  disinfection_lapses bigint,
  calib_out_of_tol bigint,
  mount_issues bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.disinfection_log_ok = false)::bigint,
    count(*) filter (where abs(coalesce(l.tonometer_calibration_error_mmhg, 0)) > 2.0)::bigint,
    count(*) filter (where l.mount_stability in ('loose','play_detected'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_slitlamp_tonometer_r3242 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3242_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3242_hospital_scorecard() to authenticated;

-- 3) Device type × optics clarity matrix
create or replace function public.founder_r3242_device_optics_matrix()
returns table(device_type text, optics_clarity text, checks bigint, passed bigint, avg_calibration_error_mmhg numeric, avg_illumination_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.optics_clarity, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.tonometer_calibration_error_mmhg), 1),
    round(avg(l.illumination_lux_or_pct), 1)
  from public.ophthalmic_slitlamp_tonometer_r3242 l
  group by l.device_type, l.optics_clarity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3242_device_optics_matrix() from public, anon;
grant execute on function public.founder_r3242_device_optics_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3242_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, disinfection_lapses bigint, calib_out_of_tol bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.disinfection_log_ok = false)::bigint,
    count(*) filter (where abs(coalesce(l.tonometer_calibration_error_mmhg, 0)) > 2.0)::bigint
  from public.ophthalmic_slitlamp_tonometer_r3242 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3242_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3242_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3242_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ophthalmic_slitlamp_tonometer_capa_actions_r3242 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3242_capa_status_board() from public, anon;
grant execute on function public.founder_r3242_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3242_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_slitlamp_tonometer_capa_actions_r3242)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_slitlamp_tonometer_capa_actions_r3242 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3242_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3242_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3242_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.ophthalmic_slitlamp_tonometer_capa_actions_r3242 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3242_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3242_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3242_high_risk_queue()
returns table(
  hospital_name text,
  exam_room text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  tonometer_calibration_error_mmhg numeric,
  probe_or_prism_condition text,
  mount_stability text,
  disinfection_log_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.exam_room, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.tonometer_calibration_error_mmhg, l.probe_or_prism_condition,
    l.mount_stability, l.disinfection_log_ok, l.notes
  from public.ophthalmic_slitlamp_tonometer_r3242 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.optics_clarity = 'degraded'
     or l.probe_or_prism_condition in ('scratched','replace_due')
     or l.mount_stability in ('loose','play_detected')
     or l.disinfection_log_ok = false
     or abs(coalesce(l.tonometer_calibration_error_mmhg, 0)) > 2.0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3242_high_risk_queue() from public, anon;
grant execute on function public.founder_r3242_high_risk_queue() to authenticated;
