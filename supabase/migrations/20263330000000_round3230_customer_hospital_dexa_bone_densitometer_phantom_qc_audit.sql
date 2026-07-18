-- Round 3230: Customer Hospital Bone-Densitometer (DEXA) Calibration & Phantom-Scan QC Audit
-- DEXA QA log — scanner model × spine-phantom BMD vs reference × CV % × drift trend × laser alignment × table travel × radiation survey × operator cert × CAPA

-- =============================================================================
-- TABLE 1: dexa_qc_r3230 — individual DEXA phantom-scan QC runs
-- =============================================================================
create table if not exists public.dexa_qc_r3230 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  department_code text not null,
  qc_ref text not null,
  scanner_asset_tag text not null,
  scanner_model text not null,
  qc_date date not null,
  qc_performed_at timestamptz,
  phantom_type text not null check (phantom_type in (
    'spine_phantom_hologic','european_spine_phantom','aluminum_spine_phantom',
    'hydroxyapatite_block','forearm_phantom','whole_body_phantom'
  )),
  reference_bmd_g_cm2 numeric(6,4) not null,
  measured_bmd_g_cm2 numeric(6,4) not null,
  bmd_deviation_pct numeric(5,2),
  cv_percent numeric(5,2),
  drift_trend_flag text not null check (drift_trend_flag in (
    'stable','upward_drift','downward_drift','oscillating','step_change','insufficient_data'
  )),
  laser_alignment_result text not null check (laser_alignment_result in (
    'aligned','minor_offset','misaligned','not_checked'
  )),
  table_travel_result text not null check (table_travel_result in (
    'smooth_full_range','sticking','limited_travel','abnormal_noise','not_checked'
  )),
  radiation_survey_usv_hr numeric(6,2),
  radiation_survey_verdict text not null check (radiation_survey_verdict in (
    'within_limits','elevated','exceeds_limits','not_measured'
  )),
  operator_cert_current boolean not null default false,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','recalibration_required','service_call_required','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dexa_qc_r3230 enable row level security;

create index if not exists idx_dexa_qc_r3230_org on public.dexa_qc_r3230(organization_id);
create index if not exists idx_dexa_qc_r3230_date on public.dexa_qc_r3230(qc_date);
create index if not exists idx_dexa_qc_r3230_verdict on public.dexa_qc_r3230(qc_verdict);

-- =============================================================================
-- TABLE 2: dexa_qc_capa_actions_r3230 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dexa_qc_capa_actions_r3230 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.dexa_qc_r3230(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'bmd_deviation_exceeds','cv_out_of_tolerance','drift_trend_alarm','laser_misalignment',
    'table_travel_fault','radiation_survey_elevated','operator_cert_lapsed',
    'phantom_damage','software_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'detector_aging','xray_tube_degradation','calibration_drift','mechanical_wear',
    'phantom_positioning_error','software_version_bug','shielding_gap',
    'operator_training_gap','power_fluctuation','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_scanner','replace_xray_tube','replace_detector_array','service_table_drive',
    'realign_laser','update_software_patch','retrain_operator','renew_operator_certification',
    'repeat_phantom_scan_series','schedule_amc_visit','add_radiation_shielding'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','cdsco_notifiable','iso_13485_deviation',
    'internal_only','none','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dexa_qc_capa_actions_r3230 enable row level security;

create index if not exists idx_dexa_capa_r3230_log on public.dexa_qc_capa_actions_r3230(qc_log_id);
create index if not exists idx_dexa_capa_r3230_status on public.dexa_qc_capa_actions_r3230(capa_status);

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

  -- 13 phantom-scan QC rows
  insert into public.dexa_qc_r3230 (
    organization_id, hospital_name, department_code, qc_ref, scanner_asset_tag, scanner_model,
    qc_date, qc_performed_at, phantom_type,
    reference_bmd_g_cm2, measured_bmd_g_cm2, bmd_deviation_pct, cv_percent,
    drift_trend_flag, laser_alignment_result, table_travel_result,
    radiation_survey_usv_hr, radiation_survey_verdict, operator_cert_current,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dept, q.ref, q.tag, q.model,
    q.qd::date, q.qat::timestamptz, q.ph,
    q.rbmd, q.mbmd, q.dev, q.cvp,
    q.drift, q.laser, q.tbl,
    q.rad, q.radv, q.cert,
    q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','RAD-2','QC-APL-001','DXA-APL-101','Hologic Horizon A','2026-07-01','2026-07-01 08:15:00+05:30',
     'spine_phantom_hologic',1.0250,1.0270,0.20,0.42,'stable','aligned','smooth_full_range',0.80,'within_limits',true,'pass','Daily phantom QC within tolerance'),
    ('Apollo Hyderabad Jubilee Hills','RAD-2','QC-APL-002','DXA-APL-101','Hologic Horizon A','2026-07-08','2026-07-08 08:20:00+05:30',
     'spine_phantom_hologic',1.0250,1.0380,1.27,0.95,'upward_drift','aligned','smooth_full_range',0.85,'within_limits',true,'conditional_pass','Upward drift over last 10 scans — placed on watch list'),
    ('Fortis Bannerghatta Bengaluru','RAD-1','QC-FRT-201','DXA-FRT-202','GE Lunar Prodigy Advance','2026-07-02','2026-07-02 07:45:00+05:30',
     'european_spine_phantom',1.1000,1.1230,2.09,1.10,'upward_drift','aligned','smooth_full_range',1.10,'within_limits',true,'fail','BMD deviation 2.09 pct exceeds 1.5 pct action limit'),
    ('Fortis Bannerghatta Bengaluru','RAD-1','QC-FRT-202','DXA-FRT-202','GE Lunar Prodigy Advance','2026-07-09','2026-07-09 07:50:00+05:30',
     'european_spine_phantom',1.1000,1.1180,1.64,2.35,'oscillating','aligned','smooth_full_range',1.15,'within_limits',true,'recalibration_required','CV 2.35 pct above 1.9 pct tolerance — detector suspect'),
    ('Manipal Whitefield Bengaluru','RAD-3','QC-MNP-301','DXA-MNP-303','GE Lunar iDXA','2026-07-03','2026-07-03 08:00:00+05:30',
     'european_spine_phantom',1.2500,1.2540,0.32,0.55,'stable','aligned','smooth_full_range',0.95,'within_limits',true,'pass','Weekly ESP scan nominal'),
    ('Manipal Whitefield Bengaluru','RAD-3','QC-MNP-302','DXA-MNP-303','GE Lunar iDXA','2026-07-10','2026-07-10 08:05:00+05:30',
     'european_spine_phantom',1.2500,1.2520,0.16,0.60,'stable','misaligned','smooth_full_range',0.90,'within_limits',true,'service_call_required','Laser crosshair off by 6 mm — patient positioning risk'),
    ('AIIMS New Delhi Ansari Nagar','RAD-5','QC-AIM-401','DXA-AIM-404','Hologic Discovery Wi','2026-07-04','2026-07-04 07:30:00+05:30',
     'spine_phantom_hologic',0.9980,1.0010,0.30,0.48,'stable','aligned','smooth_full_range',1.00,'within_limits',true,'pass','Daily QC pass — teaching block scanner'),
    ('AIIMS New Delhi Ansari Nagar','RAD-5','QC-AIM-402','DXA-AIM-404','Hologic Discovery Wi','2026-07-11','2026-07-11 07:35:00+05:30',
     'spine_phantom_hologic',0.9980,1.0005,0.25,0.52,'stable','aligned','smooth_full_range',4.80,'elevated',true,'pending_review','Survey 4.8 uSv/hr at console — shielding check ordered'),
    ('KIMS Secunderabad','RAD-2','QC-KIM-501','DXA-KIM-505','Osteosys Dexxum T','2026-07-05','2026-07-05 09:10:00+05:30',
     'aluminum_spine_phantom',0.9550,0.9380,-1.78,1.40,'downward_drift','minor_offset','smooth_full_range',1.30,'within_limits',false,'fail','Downward drift plus operator RSO certificate expired'),
    ('Care Hospitals Banjara Hills','RAD-1','QC-CAR-551','DXA-CAR-506','GE Lunar Prodigy Primo','2026-07-06','2026-07-06 08:40:00+05:30',
     'european_spine_phantom',1.1000,1.1040,0.36,0.65,'stable','aligned','smooth_full_range',0.75,'within_limits',true,'pass','Routine weekly phantom scan'),
    ('Yashoda Somajiguda Hyderabad','RAD-4','QC-YSH-601','DXA-YSH-607','Hologic Horizon W','2026-07-07','2026-07-07 08:25:00+05:30',
     'spine_phantom_hologic',1.0250,1.0290,0.39,0.70,'stable','aligned','sticking',0.88,'within_limits',true,'conditional_pass','Table sticking mid-travel — drive service booked'),
    ('St John''s Bengaluru','RAD-1','QC-STJ-651','DXA-STJ-608','GE Lunar iDXA','2026-07-12','2026-07-12 07:55:00+05:30',
     'whole_body_phantom',1.2500,1.2490,-0.08,0.50,'stable','aligned','smooth_full_range',0.92,'within_limits',true,'pass','Monthly whole-body phantom cross-check'),
    ('Rainbow Children''s Hyderabad','RAD-2','QC-RBW-701','DXA-RBW-709','Osteosys Primus','2026-07-13','2026-07-13 09:00:00+05:30',
     'forearm_phantom',0.5400,0.5560,2.96,1.80,'step_change','aligned','smooth_full_range',1.05,'within_limits',true,'pending_review','Step change after software update — repeat series scheduled')
  ) as q(hosp, dept, ref, tag, model, qd, qat, ph, rbmd, mbmd, dev, cvp, drift, laser, tbl, rad, radv, cert, verdict, nt);

  -- CAPA seed — attach to specific QC runs by qc_ref
  insert into public.dexa_qc_capa_actions_r3230 (
    qc_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.st, q.ri, q.cost, q.nt
  from (values
    ('QC-FRT-201','bmd_deviation_exceeds','calibration_drift','recalibrate_scanner','2026-07-12',null,'in_progress','nabh_finding',35000.00,'OEM calibration visit booked'),
    ('QC-FRT-202','cv_out_of_tolerance','detector_aging','replace_detector_array','2026-07-25',null,'escalated','patient_safety_alert',420000.00,'Detector array quote raised — T-score reporting on hold'),
    ('QC-MNP-302','laser_misalignment','mechanical_wear','realign_laser','2026-07-14','2026-07-12','closed','internal_only',8000.00,'Laser realigned and verified against phantom grid'),
    ('QC-AIM-402','radiation_survey_elevated','shielding_gap','add_radiation_shielding','2026-07-20',null,'verification_pending','aerb_notifiable',95000.00,'Lead barrier panel installed — AERB re-survey pending'),
    ('QC-KIM-501','operator_cert_lapsed','operator_training_gap','renew_operator_certification','2026-07-18',null,'open','nabh_finding',12000.00,'RSO refresher enrolment completed'),
    ('QC-YSH-601','table_travel_fault','mechanical_wear','service_table_drive','2026-07-16',null,'in_progress','internal_only',26000.00,'Table drive belt replacement parts ordered'),
    ('QC-RBW-701','drift_trend_alarm','software_version_bug','update_software_patch','2026-07-19',null,'open','iso_13485_deviation',5000.00,'Vendor hotfix pending validation')
  ) as q(ref, fc, rc, ca, tcd, acd, st, ri, cost, nt)
  join public.dexa_qc_r3230 e
    on e.organization_id = v_org_id and e.qc_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3230_qc_verdict_rollup()
returns table(qc_verdict text, scans bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dexa_qc_r3230)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dexa_qc_r3230 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3230_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3230_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3230_hospital_scorecard()
returns table(
  hospital_name text,
  total_scans bigint,
  passes bigint,
  fails bigint,
  recal_required bigint,
  cert_lapsed bigint,
  avg_cv_percent numeric,
  avg_deviation_pct numeric,
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.qc_verdict = 'recalibration_required')::bigint,
    count(*) filter (where not l.operator_cert_current)::bigint,
    round(avg(l.cv_percent), 2),
    round(avg(l.bmd_deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.dexa_qc_r3230 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3230_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3230_hospital_scorecard() to authenticated;

-- 3) Scanner model × phantom type matrix
create or replace function public.founder_r3230_scanner_phantom_matrix()
returns table(scanner_model text, phantom_type text, scans bigint, passes bigint, avg_cv_percent numeric, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.scanner_model, l.phantom_type, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.cv_percent), 2),
    round(avg(l.bmd_deviation_pct), 2)
  from public.dexa_qc_r3230 l
  group by l.scanner_model, l.phantom_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3230_scanner_phantom_matrix() from public, anon;
grant execute on function public.founder_r3230_scanner_phantom_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3230_daily_qc_trend()
returns table(qc_date date, scans bigint, passes bigint, fails bigint, avg_cv_percent numeric, avg_radiation_usv_hr numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.qc_date, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','recalibration_required'))::bigint,
    round(avg(l.cv_percent), 2),
    round(avg(l.radiation_survey_usv_hr), 2)
  from public.dexa_qc_r3230 l
  group by l.qc_date
  order by l.qc_date desc;
end;
$$;

revoke execute on function public.founder_r3230_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3230_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3230_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees), 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.dexa_qc_capa_actions_r3230 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3230_capa_status_board() from public, anon;
grant execute on function public.founder_r3230_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3230_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dexa_qc_capa_actions_r3230)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dexa_qc_capa_actions_r3230 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3230_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3230_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3230_regulatory_impact_digest()
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
  from public.dexa_qc_capa_actions_r3230 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3230_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3230_regulatory_impact_digest() to authenticated;

-- 8) High-risk scan queue (top individual concerns)
create or replace function public.founder_r3230_high_risk_scans()
returns table(
  hospital_name text,
  scanner_asset_tag text,
  scanner_model text,
  qc_date date,
  qc_verdict text,
  drift_trend_flag text,
  laser_alignment_result text,
  radiation_survey_verdict text,
  operator_cert_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.scanner_asset_tag, l.scanner_model, l.qc_date,
    l.qc_verdict, l.drift_trend_flag, l.laser_alignment_result, l.radiation_survey_verdict,
    l.operator_cert_current, l.notes
  from public.dexa_qc_r3230 l
  where l.qc_verdict in ('fail','recalibration_required','service_call_required','pending_review')
     or l.drift_trend_flag in ('upward_drift','downward_drift','step_change','oscillating')
     or l.laser_alignment_result in ('misaligned','minor_offset')
     or l.radiation_survey_verdict in ('elevated','exceeds_limits')
     or not l.operator_cert_current
  order by l.qc_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3230_high_risk_scans() from public, anon;
grant execute on function public.founder_r3230_high_risk_scans() to authenticated;
