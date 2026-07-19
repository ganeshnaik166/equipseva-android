-- Round 3322: Customer Hospital Physiotherapy Electrotherapy Modality QC Audit
-- Physio electrotherapy QA — device type × output-dose accuracy × timer × applicator/electrode × ultrasound ERA/BNR × leakage current × intensity control × safety cutoff × laser goggles × calibration × CAPA

-- =============================================================================
-- TABLE 1: physiotherapy_electrotherapy_r3322 — per-device electrotherapy QC checks
-- =============================================================================
create table if not exists public.physiotherapy_electrotherapy_r3322 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'tens_unit','ift_unit','shortwave_diathermy','therapeutic_ultrasound','lllt_laser','muscle_stimulator'
  )),
  department text not null,
  check_date date not null,
  output_dose_accuracy_error_pct numeric(5,2),
  timer_accuracy_ok boolean not null,
  applicator_electrode_condition text not null check (applicator_electrode_condition in (
    'good','worn','cracked','replace_due'
  )),
  ultrasound_era_bnr_ok text not null check (ultrasound_era_bnr_ok in (
    'ok','degraded','not_applicable'
  )),
  leakage_current_ua numeric(6,1),
  intensity_control_ok boolean not null,
  safety_cutoff_ok boolean not null,
  laser_goggles_available text not null check (laser_goggles_available in (
    'yes','no','not_applicable'
  )),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.physiotherapy_electrotherapy_r3322 enable row level security;

create index if not exists idx_physio_electro_r3322_org on public.physiotherapy_electrotherapy_r3322(organization_id);
create index if not exists idx_physio_electro_r3322_date on public.physiotherapy_electrotherapy_r3322(check_date);
create index if not exists idx_physio_electro_r3322_verdict on public.physiotherapy_electrotherapy_r3322(qc_verdict);

-- =============================================================================
-- TABLE 2: physiotherapy_electrotherapy_capa_actions_r3322 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.physiotherapy_electrotherapy_capa_actions_r3322 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.physiotherapy_electrotherapy_r3322(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dose_accuracy_deviation','timer_inaccuracy','applicator_electrode_wear','ultrasound_era_bnr_degraded',
    'excess_leakage_current','intensity_control_fault','safety_cutoff_failure','laser_safety_noncompliance',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_crystal_aging','electrode_pad_worn','cable_lead_damaged','timer_circuit_drift',
    'output_stage_fault','insulation_degradation','missing_laser_goggles','calibration_lapsed',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_ultrasound_transducer','replace_electrode_pads','replace_cable_lead','recalibrate_output_dose',
    'repair_timer_circuit','replace_output_module','repair_insulation','issue_laser_goggles',
    'perform_calibration','retrain_physio_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','aerb_laser_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.physiotherapy_electrotherapy_capa_actions_r3322 enable row level security;

create index if not exists idx_physio_electro_capa_r3322_log on public.physiotherapy_electrotherapy_capa_actions_r3322(qc_log_id);
create index if not exists idx_physio_electro_capa_r3322_status on public.physiotherapy_electrotherapy_capa_actions_r3322(capa_status);

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

  -- 14 electrotherapy QC rows
  insert into public.physiotherapy_electrotherapy_r3322 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    output_dose_accuracy_error_pct, timer_accuracy_ok, applicator_electrode_condition,
    ultrasound_era_bnr_ok, leakage_current_ua, intensity_control_ok, safety_cutoff_ok,
    laser_goggles_available, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.dept, q.cdate::date,
    q.dose::numeric, q.timer_ok, q.cond,
    q.era, q.leak::numeric, q.intensity_ok, q.cutoff_ok,
    q.goggles, q.calib, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','PHY-APL-TENS-01','tens_unit','Physiotherapy OPD','2026-07-10',
     1.80,true,'good','not_applicable',45.0,true,true,'not_applicable',true,'pass','Monthly QC — output within tolerance'),
    ('Apollo Chennai Greams Road','PHY-APL-IFT-02','ift_unit','Physiotherapy OPD','2026-07-10',
     3.20,true,'good','not_applicable',60.0,true,true,'not_applicable',true,'pass','IFT sweep frequency and carrier verified'),
    ('Fortis Gurgaon','PHY-FRT-US-01','therapeutic_ultrasound','Rehabilitation','2026-07-09',
     7.50,true,'worn','degraded',85.0,true,true,'not_applicable',true,'conditional_pass','ERA/BNR degraded and dose error 7.5% over 5% tolerance — watch'),
    ('Fortis Gurgaon','PHY-FRT-SWD-02','shortwave_diathermy','Rehabilitation','2026-07-09',
     2.10,true,'good','not_applicable',120.0,true,false,'not_applicable',true,'fail','Safety cutoff did not trip on overload — unit tagged out'),
    ('Manipal Bengaluru Old Airport Road','PHY-MNP-LLLT-01','lllt_laser','Sports Injury Clinic','2026-07-08',
     4.10,true,'good','not_applicable',30.0,true,true,'no',true,'fail','Class 3B laser goggles missing at station — failed safety check'),
    ('Manipal Bengaluru Old Airport Road','PHY-MNP-MS-02','muscle_stimulator','Neuro Rehab','2026-07-08',
     2.40,true,'worn','not_applicable',55.0,true,true,'not_applicable',true,'conditional_pass','Electrode pads worn — replacement advised before next cycle'),
    ('AIIMS New Delhi Ansari Nagar','PHY-AIM-TENS-03','tens_unit','Pain Clinic','2026-07-07',
     1.20,false,'good','not_applicable',40.0,true,true,'not_applicable',true,'conditional_pass','Timer 8% fast on 20-min cycle — recalibration booked'),
    ('AIIMS New Delhi Ansari Nagar','PHY-AIM-US-04','therapeutic_ultrasound','Physiotherapy OPD','2026-07-07',
     12.00,true,'cracked','degraded',95.0,true,true,'not_applicable',false,'removed_from_service','Transducer face cracked, ERA degraded, calibration lapsed — withdrawn'),
    ('CMC Vellore','PHY-CMC-IFT-01','ift_unit','Rehabilitation','2026-07-06',
     3.60,true,'good','not_applicable',65.0,true,true,'not_applicable',true,'pass','Quarterly QC clean pass'),
    ('CMC Vellore','PHY-CMC-SWD-02','shortwave_diathermy','Rehabilitation','2026-07-06',
     6.20,true,'good','not_applicable',180.0,false,true,'not_applicable',true,'fail','Leakage 180 uA over limit and intensity control erratic'),
    ('KIMS Hyderabad Secunderabad','PHY-KIM-LLLT-02','lllt_laser','Sports Injury Clinic','2026-07-05',
     2.90,true,'good','not_applicable',25.0,true,true,'yes',true,'pass','LLLT dose verified, OD5 goggles present and logged'),
    ('KIMS Hyderabad Secunderabad','PHY-KIM-US-03','therapeutic_ultrasound','Rehabilitation','2026-07-05',
     4.80,true,'replace_due','ok',70.0,true,true,'not_applicable',true,'conditional_pass','Applicator head replace-due next cycle — ERA still ok'),
    ('Care Hospitals Banjara Hills Hyderabad','PHY-CAR-MS-01','muscle_stimulator','Neuro Rehab','2026-07-04',
     2.00,true,'good','not_applicable',50.0,true,true,'not_applicable',true,'pass','NMES output verified within tolerance'),
    ('Narayana Health Bengaluru','PHY-NAR-TENS-04','tens_unit','Pain Clinic','2026-07-04',
     null,false,'cracked','not_applicable',null,false,false,'not_applicable',false,'removed_from_service','Device dead on arrival, casing cracked — QC aborted, withdrawn')
  ) as q(hosp, code, dtype, dept, cdate, dose, timer_ok, cond, era, leak, intensity_ok, cutoff_ok, goggles, calib, verdict, nt);

  -- CAPA seed — attach to specific checks via device code
  insert into public.physiotherapy_electrotherapy_capa_actions_r3322 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PHY-FRT-US-01','ultrasound_era_bnr_degraded','transducer_crystal_aging','replace_ultrasound_transducer','in_progress','iso_13485_deviation','2026-07-16',null,55000.00,'Transducer on order from OEM — bench ERA test pending'),
    ('PHY-FRT-SWD-02','safety_cutoff_failure','output_stage_fault','replace_output_module','escalated','patient_safety_alert','2026-07-13',null,38000.00,'Overload cutoff inoperative — escalated to biomedical lead'),
    ('PHY-MNP-LLLT-01','laser_safety_noncompliance','missing_laser_goggles','issue_laser_goggles','closed','aerb_laser_notifiable','2026-07-10','2026-07-09',4500.00,'Two pairs of OD5 goggles issued and logged — closed'),
    ('PHY-AIM-US-04','ultrasound_era_bnr_degraded','transducer_crystal_aging','replace_ultrasound_transducer','open','nabh_finding','2026-07-18',null,62000.00,'Cracked transducer condemned — replacement quote awaited'),
    ('PHY-CMC-SWD-02','excess_leakage_current','insulation_degradation','repair_insulation','verification_pending','cdsco_notifiable','2026-07-14',null,28000.00,'Mains insulation repaired — awaiting repeat leakage test'),
    ('PHY-KIM-US-03','applicator_electrode_wear','transducer_crystal_aging','replace_ultrasound_transducer','open','internal_only','2026-07-15',null,51000.00,'Applicator head flagged replace-due — scheduled next PM'),
    ('PHY-NAR-TENS-04','intensity_control_fault','output_stage_fault','remove_from_service','overdue','patient_safety_alert','2026-07-02',null,15000.00,'Dead unit past target closure — disposal paperwork overdue')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.physiotherapy_electrotherapy_r3322 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3322_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.physiotherapy_electrotherapy_r3322)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.physiotherapy_electrotherapy_r3322 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3322_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3322_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3322_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  safety_cutoff_fail bigint,
  leakage_fail bigint,
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
    count(*) filter (where l.safety_cutoff_ok = false)::bigint,
    count(*) filter (where l.leakage_current_ua > 100)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.physiotherapy_electrotherapy_r3322 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3322_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3322_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3322_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_dose_error_pct numeric, avg_leakage_ua numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.output_dose_accuracy_error_pct), 2),
    round(avg(l.leakage_current_ua), 1)
  from public.physiotherapy_electrotherapy_r3322 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3322_device_department_matrix() from public, anon;
grant execute on function public.founder_r3322_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3322_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, safety_cutoff_fail bigint, calibration_overdue bigint)
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
    count(*) filter (where l.safety_cutoff_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.physiotherapy_electrotherapy_r3322 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3322_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3322_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3322_capa_status_board()
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
  from public.physiotherapy_electrotherapy_capa_actions_r3322 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3322_capa_status_board() from public, anon;
grant execute on function public.founder_r3322_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3322_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.physiotherapy_electrotherapy_capa_actions_r3322)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.physiotherapy_electrotherapy_capa_actions_r3322 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3322_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3322_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3322_regulatory_impact_digest()
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
  from public.physiotherapy_electrotherapy_capa_actions_r3322 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3322_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3322_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3322_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  applicator_electrode_condition text,
  ultrasound_era_bnr_ok text,
  laser_goggles_available text,
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
    l.qc_verdict, l.applicator_electrode_condition, l.ultrasound_era_bnr_ok,
    l.laser_goggles_available, l.notes
  from public.physiotherapy_electrotherapy_r3322 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.safety_cutoff_ok = false
     or l.intensity_control_ok = false
     or l.timer_accuracy_ok = false
     or l.calibration_current = false
     or l.applicator_electrode_condition in ('cracked','replace_due')
     or l.ultrasound_era_bnr_ok = 'degraded'
     or l.laser_goggles_available = 'no'
     or l.leakage_current_ua > 100
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3322_high_risk_queue() from public, anon;
grant execute on function public.founder_r3322_high_risk_queue() to authenticated;
