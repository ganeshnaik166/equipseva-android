-- Round 3226: Customer Hospital Gamma-Camera / SPECT Uniformity & Collimator QC Audit
-- Nuclear-medicine QA log — intrinsic/extrinsic uniformity × collimator integrity × energy peak × COR × dose-calibrator constancy × wipe test × AERB records × CAPA

-- =============================================================================
-- TABLE 1: gamma_spect_r3226 — gamma camera / SPECT QC runs
-- =============================================================================
create table if not exists public.gamma_spect_r3226 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  nm_department_code text not null,
  camera_asset_tag text not null,
  camera_model text not null,
  qc_date date not null,
  qc_performed_at timestamptz not null,
  qc_frequency text not null check (qc_frequency in (
    'daily','weekly','monthly','quarterly','annual_full'
  )),
  radionuclide_used text not null check (radionuclide_used in (
    'tc_99m','co_57_sheet','i_131','ga_67','tl_201','f_18'
  )),
  intrinsic_uniformity_pct numeric(5,2) not null,
  extrinsic_uniformity_pct numeric(5,2),
  uniformity_verdict text not null check (uniformity_verdict in (
    'pass','fail','borderline','not_run'
  )),
  collimator_type text not null check (collimator_type in (
    'lehr_low_energy_high_res','leap_all_purpose','megp_medium_energy','hegp_high_energy','pinhole'
  )),
  collimator_integrity text not null check (collimator_integrity in (
    'intact','minor_dent','septal_penetration_damage','contaminated','core_misalignment','not_inspected'
  )),
  energy_peak_kev_offset numeric(5,2),
  energy_window_verdict text check (energy_window_verdict in (
    'within_2pct','drift_warning','out_of_tolerance','not_run'
  )),
  cor_error_mm numeric(4,2),
  cor_verdict text check (cor_verdict in (
    'pass','fail','borderline','not_run'
  )),
  dose_calibrator_constancy_pct numeric(5,2),
  dose_calibrator_verdict text check (dose_calibrator_verdict in (
    'within_5pct','deviation_warning','fail_recalibrate','not_run'
  )),
  wipe_test_result text not null check (wipe_test_result in (
    'clear','low_level_contamination','action_level_contamination','pending_lab','not_done'
  )),
  aerb_record_current boolean not null default false,
  qc_verdict text not null check (qc_verdict in (
    'cleared_clinical_use','conditional_clearance','restricted_planar_only',
    'suspended_pending_service','recalibration_needed','pending_physicist_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gamma_spect_r3226 enable row level security;

create index if not exists idx_gamma_spect_r3226_org on public.gamma_spect_r3226(organization_id);
create index if not exists idx_gamma_spect_r3226_date on public.gamma_spect_r3226(qc_date);
create index if not exists idx_gamma_spect_r3226_verdict on public.gamma_spect_r3226(qc_verdict);

-- =============================================================================
-- TABLE 2: gamma_spect_capa_actions_r3226 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.gamma_spect_capa_actions_r3226 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.gamma_spect_r3226(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'uniformity_fail','collimator_damage','energy_peak_drift','cor_error_exceeded',
    'dose_calibrator_deviation','wipe_test_contamination','aerb_record_lapse',
    'crystal_hydration','pmt_drift','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pmt_gain_drift','crystal_hydration_yellowing','collimator_handling_damage',
    'source_decay_uncorrected','gantry_mechanical_wear','electronics_board_fault',
    'radiopharmacy_spill','documentation_backlog','temperature_humidity_excursion','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retune_pmt_gains','replace_collimator','recalibrate_energy_peak','cor_recalibration',
    'decontaminate_and_rewipe','update_aerb_elora_records','schedule_oem_service',
    'replace_crystal_assembly','retrain_technologist','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_reportable','aerb_license_risk','nabh_finding','internal_only','none','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gamma_spect_capa_actions_r3226 enable row level security;

create index if not exists idx_gamma_capa_r3226_log on public.gamma_spect_capa_actions_r3226(qc_log_id);
create index if not exists idx_gamma_capa_r3226_status on public.gamma_spect_capa_actions_r3226(capa_status);

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

  -- 14 QC run rows
  insert into public.gamma_spect_r3226 (
    organization_id, hospital_name, nm_department_code, camera_asset_tag, camera_model,
    qc_date, qc_performed_at, qc_frequency, radionuclide_used,
    intrinsic_uniformity_pct, extrinsic_uniformity_pct, uniformity_verdict,
    collimator_type, collimator_integrity,
    energy_peak_kev_offset, energy_window_verdict,
    cor_error_mm, cor_verdict,
    dose_calibrator_constancy_pct, dose_calibrator_verdict,
    wipe_test_result, aerb_record_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dept, q.tag, q.model,
    q.qd::date, q.qp::timestamptz, q.freq, q.rn,
    q.iu, q.eu, q.uv,
    q.ct, q.ci,
    q.kev, q.ew,
    q.cor, q.cv,
    q.dc, q.dv,
    q.wt, q.aerb, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','NM-1','GC-APL-101','GE Discovery NM/CT 670','2026-07-02','2026-07-02 07:30:00+05:30','daily','tc_99m',
     2.85,3.40,'pass','lehr_low_energy_high_res','intact',0.80,'within_2pct',0.45,'pass',1.20,'within_5pct','clear',true,'cleared_clinical_use','Daily flood field uniform — camera cleared for SPECT list'),
    ('Apollo Hyderabad Jubilee Hills','NM-1','GC-APL-102','GE NM 830','2026-07-02','2026-07-02 08:15:00+05:30','weekly','co_57_sheet',
     5.60,6.90,'fail','leap_all_purpose','intact',1.40,'within_2pct',0.55,'pass',1.80,'within_5pct','clear',true,'suspended_pending_service','Integral uniformity 5.6 pct exceeds 5 pct limit — PMT bank drift suspected'),
    ('Fortis Bannerghatta Bengaluru','NM-2','GC-FRT-201','Siemens Symbia Intevo 6','2026-07-01','2026-07-01 07:00:00+05:30','daily','tc_99m',
     3.10,3.95,'pass','megp_medium_energy','minor_dent',1.10,'within_2pct',0.50,'pass',2.10,'within_5pct','clear',true,'restricted_planar_only','MEGP collimator edge dent — SPECT suspended on this head'),
    ('Fortis Bannerghatta Bengaluru','NM-2','GC-FRT-202','Siemens Symbia Evo Excel','2026-07-01','2026-07-01 08:00:00+05:30','weekly','tc_99m',
     3.40,4.10,'pass','lehr_low_energy_high_res','intact',1.00,'within_2pct',2.10,'fail',1.50,'within_5pct','clear',true,'recalibration_needed','COR error 2.1 mm exceeds 1.0 mm tolerance — tomography halted'),
    ('Manipal Whitefield Bengaluru','NM-1','GC-MNP-301','Philips BrightView XCT','2026-06-30','2026-06-30 07:45:00+05:30','daily','tc_99m',
     3.05,3.80,'pass','lehr_low_energy_high_res','intact',4.50,'out_of_tolerance',0.60,'pass',1.90,'within_5pct','clear',true,'recalibration_needed','Photopeak offset 4.5 keV off 140 keV — energy recalibration booked'),
    ('Manipal Whitefield Bengaluru','NM-1','GC-MNP-302','GE Discovery NM 630','2026-06-30','2026-06-30 09:00:00+05:30','monthly','co_57_sheet',
     2.60,3.10,'pass','leap_all_purpose','intact',0.60,'within_2pct',0.40,'pass',0.90,'within_5pct','clear',true,'cleared_clinical_use','Monthly extrinsic flood with Co-57 sheet — all within limits'),
    ('AIIMS New Delhi Ansari Nagar','NM-3','GC-AIM-401','Siemens Symbia T16','2026-06-29','2026-06-29 06:30:00+05:30','daily','tc_99m',
     2.95,3.55,'pass','lehr_low_energy_high_res','intact',0.90,'within_2pct',0.55,'pass',1.60,'within_5pct','action_level_contamination',true,'suspended_pending_service','Wipe test above action level near collimator cart — decontamination underway'),
    ('AIIMS New Delhi Ansari Nagar','NM-3','GC-AIM-402','Mediso AnyScan SC','2026-06-29','2026-06-29 08:00:00+05:30','quarterly','tc_99m',
     3.20,3.85,'pass','lehr_low_energy_high_res','intact',1.20,'within_2pct',0.65,'pass',7.80,'fail_recalibrate','clear',true,'conditional_clearance','Dose calibrator constancy 7.8 pct off Cs-137 reference — assays repeated on backup unit'),
    ('KIMS Secunderabad','NM-1','GC-KIM-501','GE Infinia Hawkeye 4','2026-06-28','2026-06-28 07:15:00+05:30','daily','tc_99m',
     4.90,5.40,'borderline','lehr_low_energy_high_res','intact',1.60,'drift_warning',0.85,'borderline',2.40,'within_5pct','clear',false,'pending_physicist_review','Borderline uniformity plus eLORA QA uploads lapsed — RSO review pending'),
    ('KIMS Secunderabad','NM-1','GC-KIM-502','Siemens Symbia S','2026-06-28','2026-06-28 10:00:00+05:30','annual_full','co_57_sheet',
     6.20,7.10,'fail','leap_all_purpose','intact',1.30,'within_2pct',0.70,'pass',1.40,'within_5pct','clear',false,'suspended_pending_service','Edge packing artifact — NaI crystal hydration yellowing seen on flood'),
    ('Care Hospitals Banjara Hills','NM-2','GC-CAR-601','Siemens e.cam Signature','2026-06-27','2026-06-27 07:30:00+05:30','weekly','tc_99m',
     3.30,3.90,'pass','lehr_low_energy_high_res','intact',0.70,'within_2pct',0.50,'pass',1.10,'within_5pct','clear',true,'cleared_clinical_use','Weekly intrinsic uniformity and COR both within limits'),
    ('Yashoda Somajiguda Hyderabad','NM-1','GC-YSH-701','GE Discovery NM/CT 870 DR','2026-06-27','2026-06-27 08:30:00+05:30','daily','i_131',
     3.15,4.20,'pass','hegp_high_energy','septal_penetration_damage',1.50,'within_2pct',0.60,'pass',1.70,'within_5pct','low_level_contamination',true,'suspended_pending_service','HEGP septal damage on star pattern — I-131 therapy imaging suspended'),
    ('St John''s Bengaluru','NM-1','GC-STJ-801','Philips ADAC Forte','2026-06-26','2026-06-26 07:00:00+05:30','monthly','tc_99m',
     3.60,4.30,'pass','lehr_low_energy_high_res','intact',1.80,'drift_warning',0.95,'borderline',2.90,'within_5pct','clear',true,'conditional_clearance','COR 0.95 mm near limit — repeat in 48 hours before SPECT list'),
    ('Rainbow Children''s Hyderabad','NM-1','GC-RBW-901','Mediso Nucline TH-22','2026-06-26','2026-06-26 09:15:00+05:30','weekly','tc_99m',
     2.70,3.20,'pass','pinhole','intact',0.50,'within_2pct',0.35,'pass',0.80,'within_5pct','clear',true,'cleared_clinical_use','Paediatric thyroid pinhole QC — all parameters nominal')
  ) as q(hosp, dept, tag, model, qd, qp, freq, rn, iu, eu, uv, ct, ci, kev, ew, cor, cv, dc, dv, wt, aerb, verdict, nt);

  -- CAPA seed — attach to specific cameras
  insert into public.gamma_spect_capa_actions_r3226 (
    qc_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('GC-APL-102','uniformity_fail','pmt_gain_drift','retune_pmt_gains','2026-07-08',null,'in_progress','nabh_finding',85000.00,'OEM engineer retuning PMT bank 3 — repeat flood after tune'),
    ('GC-FRT-201','collimator_damage','collimator_handling_damage','replace_collimator','2026-07-20',null,'open','internal_only',425000.00,'MEGP collimator dented during cart transfer — replacement quoted'),
    ('GC-FRT-202','cor_error_exceeded','gantry_mechanical_wear','cor_recalibration','2026-07-06','2026-07-04','closed','internal_only',30000.00,'COR recalibrated after gantry bearing service — error now 0.4 mm'),
    ('GC-MNP-301','energy_peak_drift','electronics_board_fault','recalibrate_energy_peak','2026-07-09',null,'verification_pending','nabh_finding',55000.00,'ADC board swapped — awaiting physicist verification flood'),
    ('GC-AIM-401','wipe_test_contamination','radiopharmacy_spill','decontaminate_and_rewipe','2026-07-03',null,'escalated','aerb_reportable',18000.00,'Tc-99m spill near injection room — RSO notified AERB'),
    ('GC-KIM-501','aerb_record_lapse','documentation_backlog','update_aerb_elora_records','2026-06-28',null,'overdue','aerb_license_risk',5000.00,'eLORA QA uploads pending two quarters — license renewal at risk'),
    ('GC-KIM-502','crystal_hydration','crystal_hydration_yellowing','replace_crystal_assembly','2026-08-15',null,'open','patient_safety_alert',1850000.00,'NaI crystal hydration edge artifact — replacement under capex approval'),
    ('GC-AIM-402','dose_calibrator_deviation','source_decay_uncorrected','retrain_technologist','2026-07-05','2026-07-02','closed','internal_only',0.00,'Cs-137 reference decay factor updated and technologist retrained')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.gamma_spect_r3226 e
    on e.organization_id = v_org_id and e.camera_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3226_qc_verdict_rollup()
returns table(qc_verdict text, qc_runs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gamma_spect_r3226)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gamma_spect_r3226 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3226_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3226_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3226_hospital_scorecard()
returns table(
  hospital_name text,
  total_qc_runs bigint,
  cleared bigint,
  suspended bigint,
  uniformity_flags bigint,
  collimator_damaged bigint,
  wipe_contaminated bigint,
  aerb_lapsed bigint,
  clearance_pct numeric
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
    count(*) filter (where l.qc_verdict = 'cleared_clinical_use')::bigint,
    count(*) filter (where l.qc_verdict = 'suspended_pending_service')::bigint,
    count(*) filter (where l.uniformity_verdict in ('fail','borderline'))::bigint,
    count(*) filter (where l.collimator_integrity in ('minor_dent','septal_penetration_damage','contaminated','core_misalignment'))::bigint,
    count(*) filter (where l.wipe_test_result in ('low_level_contamination','action_level_contamination'))::bigint,
    count(*) filter (where not l.aerb_record_current)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'cleared_clinical_use')::numeric / nullif(count(*),0), 1)
  from public.gamma_spect_r3226 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3226_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3226_hospital_scorecard() to authenticated;

-- 3) Camera model × collimator matrix
create or replace function public.founder_r3226_camera_collimator_matrix()
returns table(camera_model text, collimator_type text, qc_runs bigint, cleared bigint, avg_intrinsic_uniformity_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.camera_model, l.collimator_type, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'cleared_clinical_use')::bigint,
    round(avg(l.intrinsic_uniformity_pct), 2)
  from public.gamma_spect_r3226 l
  group by l.camera_model, l.collimator_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3226_camera_collimator_matrix() from public, anon;
grant execute on function public.founder_r3226_camera_collimator_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3226_qc_daily_trend()
returns table(qc_date date, qc_runs bigint, uniformity_pass bigint, uniformity_flags bigint, cor_flags bigint, energy_flags bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.qc_date,
    count(*)::bigint,
    count(*) filter (where l.uniformity_verdict = 'pass')::bigint,
    count(*) filter (where l.uniformity_verdict in ('fail','borderline'))::bigint,
    count(*) filter (where l.cor_verdict in ('fail','borderline'))::bigint,
    count(*) filter (where l.energy_window_verdict in ('out_of_tolerance','drift_warning'))::bigint
  from public.gamma_spect_r3226 l
  group by l.qc_date
  order by l.qc_date desc;
end;
$$;

revoke execute on function public.founder_r3226_qc_daily_trend() from public, anon;
grant execute on function public.founder_r3226_qc_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3226_capa_status_board()
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
  from public.gamma_spect_capa_actions_r3226 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3226_capa_status_board() from public, anon;
grant execute on function public.founder_r3226_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3226_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gamma_spect_capa_actions_r3226)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gamma_spect_capa_actions_r3226 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3226_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3226_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3226_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','escalated','overdue'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.gamma_spect_capa_actions_r3226 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3226_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3226_regulatory_impact_digest() to authenticated;

-- 8) High-risk cameras queue
create or replace function public.founder_r3226_high_risk_cameras()
returns table(
  hospital_name text,
  camera_asset_tag text,
  camera_model text,
  qc_date date,
  qc_verdict text,
  uniformity_verdict text,
  collimator_integrity text,
  wipe_test_result text,
  aerb_record_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.camera_asset_tag, l.camera_model, l.qc_date,
    l.qc_verdict, l.uniformity_verdict, l.collimator_integrity, l.wipe_test_result, l.aerb_record_current, l.notes
  from public.gamma_spect_r3226 l
  where l.qc_verdict in ('conditional_clearance','restricted_planar_only','suspended_pending_service','recalibration_needed','pending_physicist_review')
     or l.uniformity_verdict in ('fail','borderline')
     or l.collimator_integrity in ('minor_dent','septal_penetration_damage','contaminated','core_misalignment')
     or l.wipe_test_result in ('low_level_contamination','action_level_contamination')
     or not l.aerb_record_current
  order by l.qc_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3226_high_risk_cameras() from public, anon;
grant execute on function public.founder_r3226_high_risk_cameras() to authenticated;
