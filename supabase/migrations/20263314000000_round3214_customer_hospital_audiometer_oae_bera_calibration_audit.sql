-- Round 3214: Customer Hospital Audiometer & OAE/BERA Screening-Equipment Calibration Audit
-- Audiology QA log — device type × frequency dB accuracy × transducer × booth ambient noise × biologic check × probe tip × annual cal × CAPA

-- =============================================================================
-- TABLE 1: audiometer_qa_r3214 — individual audiology-equipment calibration checks
-- =============================================================================
create table if not exists public.audiometer_qa_r3214 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  audiology_room_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'diagnostic_audiometer','screening_audiometer','oae_screener',
    'bera_abr_system','tympanometer','hybrid_oae_abr'
  )),
  check_date date not null,
  checked_at timestamptz not null,
  transducer_type text not null check (transducer_type in (
    'supra_aural_headphone','circum_aural_headphone','insert_earphone',
    'bone_vibrator','free_field_speaker','oae_probe','abr_electrode_set','tympanometry_probe'
  )),
  frequency_accuracy_result text not null check (frequency_accuracy_result in (
    'within_0_5_db','within_1_db','within_3_db','deviation_3_to_5_db','deviation_over_5_db','not_tested'
  )),
  max_deviation_db numeric(5,2),
  reference_tone_frequency_hz int,
  booth_ambient_noise_db numeric(5,2),
  booth_noise_verdict text check (booth_noise_verdict in (
    'compliant_iso8253','marginal','non_compliant','not_measured'
  )),
  biologic_check_result text not null check (biologic_check_result in (
    'pass','threshold_shift_5db','threshold_shift_over_10db','fail','not_done'
  )),
  probe_tip_condition text check (probe_tip_condition in (
    'clean_intact','debris_present','cracked','blocked','replaced','not_applicable'
  )),
  annual_calibration_valid boolean not null default false,
  calibration_due_date date,
  calibration_verdict text not null check (calibration_verdict in (
    'fit_for_use','restricted_use','recalibration_required','out_of_service','pending_review','conditional_use'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.audiometer_qa_r3214 enable row level security;

create index if not exists idx_audiometer_qa_r3214_org on public.audiometer_qa_r3214(organization_id);
create index if not exists idx_audiometer_qa_r3214_date on public.audiometer_qa_r3214(check_date);
create index if not exists idx_audiometer_qa_r3214_verdict on public.audiometer_qa_r3214(calibration_verdict);

-- =============================================================================
-- TABLE 2: audiometer_qa_capa_actions_r3214 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.audiometer_qa_capa_actions_r3214 (
  id uuid primary key default gen_random_uuid(),
  qa_log_id uuid not null references public.audiometer_qa_r3214(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'frequency_deviation','output_level_drift','booth_noise_exceeded','biologic_check_fail',
    'probe_tip_defect','transducer_damage','calibration_expired','electrode_impedance_high',
    'software_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_cushion_worn','cable_intermittent','probe_tip_debris','booth_seal_degraded',
    'hvac_noise_ingress','sensor_drift','operator_handling_error','coupler_mismatch',
    'firmware_bug','pending_investigation','calibration_vendor_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_transducer','replace_probe_tips','reseal_booth_door','relocate_hvac_duct',
    'send_for_lab_calibration','recalibrate_on_site','retrain_audiologist','update_firmware',
    'withdraw_device','schedule_amc_visit','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_8253_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.audiometer_qa_capa_actions_r3214 enable row level security;

create index if not exists idx_audiometer_capa_r3214_log on public.audiometer_qa_capa_actions_r3214(qa_log_id);
create index if not exists idx_audiometer_capa_r3214_status on public.audiometer_qa_capa_actions_r3214(capa_status);

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

  -- 14 audiology QA log rows
  insert into public.audiometer_qa_r3214 (
    organization_id, hospital_name, audiology_room_code, device_asset_tag, device_model,
    device_type, check_date, checked_at, transducer_type,
    frequency_accuracy_result, max_deviation_db, reference_tone_frequency_hz,
    booth_ambient_noise_db, booth_noise_verdict, biologic_check_result, probe_tip_condition,
    annual_calibration_valid, calibration_due_date, calibration_verdict, notes
  )
  select v_org_id, q.hosp, q.room, q.tag, q.model,
    q.dt, q.cd::date, q.ca::timestamptz, q.tt,
    q.fa, q.md, q.rf,
    q.bn, q.bv, q.bc, q.pc,
    q.acv, q.cdd::date, q.cv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','AUD-1','AUD-APL-001','GSI AudioStar Pro','diagnostic_audiometer','2026-07-14','2026-07-14 09:10:00+05:30','insert_earphone',
     'within_0_5_db',0.40,1000,28.50,'compliant_iso8253','pass','not_applicable',true,'2027-01-15','fit_for_use','Annual NABL cert on file; all octaves within 0.5 dB'),
    ('Apollo Hyderabad Jubilee Hills','AUD-1','AUD-APL-002','Interacoustics AD629','diagnostic_audiometer','2026-07-14','2026-07-14 10:05:00+05:30','bone_vibrator',
     'within_1_db',0.90,500,28.50,'compliant_iso8253','pass','not_applicable',true,'2027-01-15','fit_for_use','Bone conduction within tolerance at 500 Hz'),
    ('Fortis Bannerghatta Bengaluru','NBS-2','OAE-FRT-003','Otodynamics Otoport','oae_screener','2026-07-13','2026-07-13 08:30:00+05:30','oae_probe',
     'not_tested',null,null,31.00,'marginal','not_done','debris_present',true,'2026-11-20','restricted_use','Probe tip debris — DPOAE run aborted, cleaning kit ordered'),
    ('Fortis Bannerghatta Bengaluru','AUD-3','ABR-FRT-004','Interacoustics Eclipse','bera_abr_system','2026-07-13','2026-07-13 09:20:00+05:30','abr_electrode_set',
     'within_1_db',0.80,2000,31.00,'marginal','pass','clean_intact',true,'2026-11-20','fit_for_use','Click stimulus verified against reference coupler'),
    ('Manipal Whitefield Bengaluru','AUD-2','AUD-MNP-005','Maico MA42','screening_audiometer','2026-07-12','2026-07-12 11:15:00+05:30','supra_aural_headphone',
     'deviation_over_5_db',6.30,4000,29.00,'compliant_iso8253','threshold_shift_over_10db','not_applicable',false,'2026-05-30','out_of_service','6.3 dB drift at 4 kHz plus biologic shift — withdrawn from service'),
    ('Manipal Whitefield Bengaluru','ENT-OPD-1','TYM-MNP-006','GSI TympStar Pro','tympanometer','2026-07-12','2026-07-12 12:00:00+05:30','tympanometry_probe',
     'not_tested',null,null,29.00,'compliant_iso8253','not_done','cracked',true,'2026-12-10','restricted_use','Probe shell cracked — 226 Hz tymp still reads, replacement ordered'),
    ('AIIMS New Delhi Ansari Nagar','AUD-5','AUD-AIM-007','Interacoustics AC40','diagnostic_audiometer','2026-07-11','2026-07-11 09:00:00+05:30','circum_aural_headphone',
     'within_0_5_db',0.30,1000,26.80,'compliant_iso8253','pass','not_applicable',true,'2027-03-01','fit_for_use','Reference audiometer for residency training'),
    ('AIIMS New Delhi Ansari Nagar','AUD-5','ABR-AIM-008','Natus Bio-logic NavPro','bera_abr_system','2026-07-11','2026-07-11 10:40:00+05:30','abr_electrode_set',
     'within_3_db',2.40,2000,26.80,'compliant_iso8253','threshold_shift_5db','clean_intact',true,'2027-03-01','conditional_use','Biologic 5 dB shift — repeat check with fresh electrodes scheduled'),
    ('KIMS Secunderabad','AUD-4','AUD-KIM-009','GSI Pello','diagnostic_audiometer','2026-07-10','2026-07-10 08:45:00+05:30','insert_earphone',
     'deviation_3_to_5_db',4.10,8000,35.50,'non_compliant','pass','not_applicable',true,'2026-10-05','recalibration_required','Booth ambient 35.5 dB(A) exceeds ISO 8253-1 limit; 8 kHz off by 4.1 dB'),
    ('Care Hospitals Banjara Hills','NBS-1','OAE-CAR-010','Maico EroScan','oae_screener','2026-07-10','2026-07-10 10:20:00+05:30','oae_probe',
     'within_1_db',0.70,2000,30.20,'marginal','pass','clean_intact',true,'2026-09-18','fit_for_use','Newborn hearing screening probe check clean'),
    ('Yashoda Somajiguda Hyderabad','AUD-6','AUD-YSH-011','Interacoustics AD528','screening_audiometer','2026-07-09','2026-07-09 09:30:00+05:30','supra_aural_headphone',
     'within_1_db',1.00,1000,27.50,'compliant_iso8253','pass','not_applicable',false,'2026-06-22','recalibration_required','Annual calibration lapsed 17 days — outputs still in tolerance'),
    ('St John''s Bengaluru','AUD-1','ABR-STJ-012','Intelligent Hearing SmartEP','bera_abr_system','2026-07-09','2026-07-09 11:10:00+05:30','insert_earphone',
     'within_0_5_db',0.20,1000,25.90,'compliant_iso8253','pass','clean_intact',true,'2027-02-14','fit_for_use','Best-in-fleet booth at 25.9 dB(A)'),
    ('Rainbow Children''s Hyderabad','NBS-3','OAE-RBW-013','Otodynamics ILO292','hybrid_oae_abr','2026-07-08','2026-07-08 08:15:00+05:30','oae_probe',
     'not_tested',null,null,33.80,'non_compliant','fail','blocked',false,'2026-04-30','out_of_service','Probe blocked, booth non-compliant, calibration expired — NBS line halted'),
    ('Rainbow Children''s Hyderabad','AUD-2','AUD-RBW-014','Maico Pilot Test','screening_audiometer','2026-07-08','2026-07-08 09:00:00+05:30','free_field_speaker',
     'within_3_db',2.80,500,33.80,'non_compliant','pass','not_applicable',true,'2026-12-01','pending_review','Free-field play audiometry pending booth remediation')
  ) as q(hosp, room, tag, model, dt, cd, ca, tt, fa, md, rf, bn, bv, bc, pc, acv, cdd, cv, nt);

  -- CAPA seed — attach to specific devices by asset tag
  insert into public.audiometer_qa_capa_actions_r3214 (
    qa_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('AUD-MNP-005','output_level_drift','sensor_drift','send_for_lab_calibration','2026-07-25',null,'in_progress','patient_safety_alert',22000.00,'Unit shipped to NABL lab; loaner screening audiometer issued'),
    ('OAE-FRT-003','probe_tip_defect','probe_tip_debris','replace_probe_tips','2026-07-20','2026-07-16','closed','internal_only',1800.00,'Probe tip pack replaced — DPOAE recheck passed'),
    ('AUD-KIM-009','booth_noise_exceeded','hvac_noise_ingress','relocate_hvac_duct','2026-08-05',null,'open','nabh_finding',35000.00,'HVAC duct directly above booth — civil work quote received'),
    ('TYM-MNP-006','probe_tip_defect','operator_handling_error','replace_probe_tips','2026-07-22',null,'verification_pending','internal_only',2600.00,'Probe shell replaced — awaiting audiologist verification run'),
    ('OAE-RBW-013','calibration_expired','calibration_vendor_backlog','send_for_lab_calibration','2026-07-30',null,'escalated','cdsco_notifiable',24000.00,'Vendor backlog 6 weeks — newborn screening diverted to sister unit'),
    ('AUD-YSH-011','calibration_expired','calibration_vendor_backlog','schedule_amc_visit','2026-07-12',null,'overdue','nabh_finding',15000.00,'Calibration overdue — flagged for upcoming NABH audit'),
    ('ABR-AIM-008','electrode_impedance_high','cable_intermittent','replace_transducer','2026-07-28',null,'in_progress','iso_8253_deviation',9500.00,'Intermittent electrode lead — replacement set on order')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.audiometer_qa_r3214 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Calibration verdict distribution
create or replace function public.founder_r3214_calibration_verdict_rollup()
returns table(calibration_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.audiometer_qa_r3214)
  select l.calibration_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.audiometer_qa_r3214 l
  group by l.calibration_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3214_calibration_verdict_rollup() from public, anon;
grant execute on function public.founder_r3214_calibration_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3214_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  fit_for_use bigint,
  out_of_service bigint,
  recal_required bigint,
  booth_noncompliant bigint,
  biologic_fail bigint,
  cal_expired bigint,
  compliance_pct numeric
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
    count(*) filter (where l.calibration_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.calibration_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.calibration_verdict = 'recalibration_required')::bigint,
    count(*) filter (where l.booth_noise_verdict = 'non_compliant')::bigint,
    count(*) filter (where l.biologic_check_result in ('fail','threshold_shift_over_10db'))::bigint,
    count(*) filter (where not l.annual_calibration_valid)::bigint,
    round(100.0 * count(*) filter (where l.calibration_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.audiometer_qa_r3214 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3214_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3214_hospital_scorecard() to authenticated;

-- 3) Device type × transducer breakdown
create or replace function public.founder_r3214_device_transducer_matrix()
returns table(device_type text, transducer_type text, checks bigint, fit_for_use bigint, avg_deviation_db numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.transducer_type, count(*)::bigint,
    count(*) filter (where l.calibration_verdict = 'fit_for_use')::bigint,
    round(avg(l.max_deviation_db), 2)
  from public.audiometer_qa_r3214 l
  group by l.device_type, l.transducer_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3214_device_transducer_matrix() from public, anon;
grant execute on function public.founder_r3214_device_transducer_matrix() to authenticated;

-- 4) Daily check trend
create or replace function public.founder_r3214_daily_check_trend()
returns table(check_date date, checks bigint, fit_for_use bigint, recal_required bigint, out_of_service bigint, booth_noncompliant bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.calibration_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.calibration_verdict = 'recalibration_required')::bigint,
    count(*) filter (where l.calibration_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.booth_noise_verdict = 'non_compliant')::bigint
  from public.audiometer_qa_r3214 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3214_daily_check_trend() from public, anon;
grant execute on function public.founder_r3214_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3214_capa_status_board()
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
  from public.audiometer_qa_capa_actions_r3214 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3214_capa_status_board() from public, anon;
grant execute on function public.founder_r3214_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3214_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.audiometer_qa_capa_actions_r3214)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.audiometer_qa_capa_actions_r3214 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3214_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3214_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3214_regulatory_impact_digest()
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
  from public.audiometer_qa_capa_actions_r3214 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3214_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3214_regulatory_impact_digest() to authenticated;

-- 8) High-risk devices queue (top individual concerns)
create or replace function public.founder_r3214_high_risk_devices()
returns table(
  hospital_name text,
  audiology_room_code text,
  device_asset_tag text,
  device_type text,
  check_date date,
  calibration_verdict text,
  frequency_accuracy_result text,
  booth_noise_verdict text,
  biologic_check_result text,
  probe_tip_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.audiology_room_code, l.device_asset_tag, l.device_type, l.check_date,
    l.calibration_verdict, l.frequency_accuracy_result, l.booth_noise_verdict,
    l.biologic_check_result, l.probe_tip_condition, l.notes
  from public.audiometer_qa_r3214 l
  where l.calibration_verdict in ('restricted_use','recalibration_required','out_of_service','pending_review','conditional_use')
     or l.biologic_check_result in ('fail','threshold_shift_over_10db')
     or l.frequency_accuracy_result in ('deviation_3_to_5_db','deviation_over_5_db')
     or l.booth_noise_verdict = 'non_compliant'
     or l.probe_tip_condition in ('debris_present','cracked','blocked')
     or not l.annual_calibration_valid
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3214_high_risk_devices() from public, anon;
grant execute on function public.founder_r3214_high_risk_devices() to authenticated;
