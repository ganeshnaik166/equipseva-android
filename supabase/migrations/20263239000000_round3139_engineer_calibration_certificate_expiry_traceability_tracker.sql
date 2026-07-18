-- Round 3139: Engineer Calibration Certificate Expiry & Traceability Tracker
-- Per-instrument calibration certs — instrument type × NABL lab × issued/expiry × traceability standard × uncertainty × status + renewal/CAPA actions

-- =============================================================================
-- TABLE 1: engineer_calibration_r3139 — per-instrument calibration certificates
-- =============================================================================
create table if not exists public.engineer_calibration_r3139 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  engineer_name text not null,
  instrument_type text not null check (instrument_type in (
    'digital_pressure_gauge','infusion_pump_analyzer','defibrillator_analyzer',
    'electrical_safety_analyzer','patient_simulator','temperature_data_logger',
    'multimeter_dmm','torque_wrench','vacuum_gauge','spo2_simulator',
    'ecg_simulator','flow_analyzer_ventilator','tachometer_centrifuge','lux_meter'
  )),
  instrument_asset_tag text not null,
  instrument_model text not null,
  cert_number text not null,
  nabl_lab_name text not null,
  calibration_standard text not null check (calibration_standard in (
    'nabl_iso_iec_17025','si_traceable_nist','bipm_traceable','nplindia_traceable',
    'iso_6789_torque','iec_60601_electrical_safety','manufacturer_reference','in_house_reference_standard'
  )),
  calibration_method text not null check (calibration_method in (
    'comparison_against_reference','direct_measurement','deadweight_tester',
    'fixed_point_cell','simulation_playback','ratio_bridge'
  )),
  issued_date date not null,
  expiry_date date not null,
  measurement_uncertainty numeric(6,3) not null,
  uncertainty_unit text not null check (uncertainty_unit in (
    'percent_reading','percent_fsd','kpa','deg_c','millivolt',
    'ml_per_hour','joule','newton_metre','bpm','lux'
  )),
  cert_status text not null check (cert_status in (
    'valid','expiring_soon','expired','recalled','suspended','pending_recalibration','provisional'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_calibration_r3139 enable row level security;

create index if not exists idx_engineer_calibration_r3139_org on public.engineer_calibration_r3139(organization_id);
create index if not exists idx_engineer_calibration_r3139_expiry on public.engineer_calibration_r3139(expiry_date);
create index if not exists idx_engineer_calibration_r3139_status on public.engineer_calibration_r3139(cert_status);

-- =============================================================================
-- TABLE 2: engineer_calibration_capa_actions_r3139 — renewal & CAPA actions
-- =============================================================================
create table if not exists public.engineer_calibration_capa_actions_r3139 (
  id uuid primary key default gen_random_uuid(),
  calibration_id uuid not null references public.engineer_calibration_r3139(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'certificate_expired','certificate_expiring','uncertainty_out_of_spec','traceability_gap',
    'lab_accreditation_lapsed','instrument_out_of_tolerance','cert_document_missing',
    'recall_notice_issued','standard_superseded','drift_beyond_limit'
  )),
  root_cause text not null check (root_cause in (
    'calibration_overdue','lab_scope_not_accredited','instrument_drift','environmental_condition_drift',
    'reference_standard_expired','handling_damage','documentation_error','vendor_delay',
    'pending_investigation','budget_hold'
  )),
  corrective_action text not null check (corrective_action in (
    'schedule_recalibration','send_to_nabl_lab','replace_instrument','adjust_and_verify',
    'update_traceability_record','quarantine_instrument','switch_accredited_lab',
    'issue_recall','retrain_engineer','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','nabl_nonconformity','iso_13485_deviation',
    'internal_only','patient_safety_alert','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_calibration_capa_actions_r3139 enable row level security;

create index if not exists idx_engineer_calibration_capa_r3139_cal on public.engineer_calibration_capa_actions_r3139(calibration_id);
create index if not exists idx_engineer_calibration_capa_r3139_status on public.engineer_calibration_capa_actions_r3139(capa_status);

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

  -- 14 calibration certificate rows
  insert into public.engineer_calibration_r3139 (
    organization_id, hospital_name, engineer_name, instrument_type, instrument_asset_tag,
    instrument_model, cert_number, nabl_lab_name, calibration_standard, calibration_method,
    issued_date, expiry_date, measurement_uncertainty, uncertainty_unit, cert_status, notes
  )
  select v_org_id, q.hosp, q.eng, q.itype, q.tag, q.model, q.cert, q.lab, q.std, q.meth,
    q.issd::date, q.expd::date, q.unc, q.uunit, q.status, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Ramesh Kumar','digital_pressure_gauge','INS-APL-014','Fluke 700G31',
     'CAL-APL-1001','Fluke Calibration India','nabl_iso_iec_17025','comparison_against_reference',
     '2025-08-10','2026-08-10',0.250,'percent_reading','valid','Annual cal — 6.9 bar reference cell'),
    ('Apollo Hyderabad Jubilee Hills','Ramesh Kumar','infusion_pump_analyzer','INS-APL-022','IDA-1S',
     'CAL-APL-1002','Transcat NABL Lab','si_traceable_nist','comparison_against_reference',
     '2025-09-01','2026-09-01',1.500,'ml_per_hour','valid','Flow bench traceable to NIST'),
    ('Fortis Bannerghatta Bengaluru','Suresh Nair','defibrillator_analyzer','INS-FRT-007','Impulse 7000DP',
     'CAL-FRT-2001','Datrend Systems Cal Lab','iec_60601_electrical_safety','simulation_playback',
     '2025-06-15','2026-06-15',2.000,'joule','expired','Energy delivery cert lapsed 33 days'),
    ('Fortis Bannerghatta Bengaluru','Suresh Nair','electrical_safety_analyzer','INS-FRT-011','Rigel 288+',
     'CAL-FRT-2002','Rigel Medical India','iec_60601_electrical_safety','direct_measurement',
     '2025-05-20','2026-05-20',0.500,'millivolt','expired','Leakage-current cert expired — recal due'),
    ('Manipal Whitefield Bengaluru','Anita Rao','temperature_data_logger','INS-MNP-021','testo 174T',
     'CAL-MNP-3001','NPL India','nplindia_traceable','fixed_point_cell',
     '2025-07-25','2026-07-25',0.100,'deg_c','expiring_soon','Triple-point cell traceable to NPL'),
    ('Manipal Whitefield Bengaluru','Anita Rao','patient_simulator','INS-MNP-030','ProSim 8',
     'CAL-MNP-3002','Fluke Biomedical Cal','si_traceable_nist','simulation_playback',
     '2025-10-05','2026-10-05',1.000,'bpm','valid','Multi-parameter simulator verified'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','multimeter_dmm','INS-AIM-033','Fluke 87V',
     'CAL-AIM-4001','NPL India','si_traceable_nist','direct_measurement',
     '2025-04-12','2026-04-12',0.050,'percent_reading','recalled','Mfr recall on ADC batch — unit withdrawn'),
    ('AIIMS New Delhi Ansari Nagar','Vikram Singh','torque_wrench','INS-AIM-041','Mitutoyo 6906',
     'CAL-AIM-4002','Mitutoyo Cal Lab','iso_6789_torque','deadweight_tester',
     '2025-11-01','2026-11-01',4.000,'newton_metre','valid','ISO 6789 Type II class B verified'),
    ('KIMS Secunderabad','Priya Menon','spo2_simulator','INS-KIM-011','Index 2XL',
     'CAL-KIM-5001','Fluke Biomedical Cal','manufacturer_reference','simulation_playback',
     '2025-07-30','2026-07-30',2.000,'percent_reading','expiring_soon','SpO2 R-curve cert nearing expiry'),
    ('KIMS Secunderabad','Priya Menon','vacuum_gauge','INS-KIM-018','Fluke 700GP2',
     'CAL-KIM-5002','Transcat NABL Lab','nabl_iso_iec_17025','comparison_against_reference',
     '2025-03-18','2026-03-18',1.200,'kpa','expired','Suction gauge cert lapsed — NABL nonconformity'),
    ('Care Hospitals Banjara Hills','Mohan Das','flow_analyzer_ventilator','INS-CAR-005','Citrex H5',
     'CAL-CAR-6001','IMT Analytics Cal','si_traceable_nist','comparison_against_reference',
     '2025-09-22','2026-09-22',2.500,'ml_per_hour','valid','Ventilator flow analyzer traceable'),
    ('Yashoda Somajiguda Hyderabad','Lakshmi Iyer','ecg_simulator','INS-YSH-018','ProSim 4',
     'CAL-YSH-7001','Fluke Biomedical Cal','manufacturer_reference','simulation_playback',
     '2025-08-08','2026-08-08',1.000,'millivolt','expiring_soon','12-lead ECG amplitude cert expiring'),
    ('St John''s Bengaluru','Joseph Thomas','tachometer_centrifuge','INS-STJ-003','testo 470',
     'CAL-STJ-8001','In-House Metrology Cell','in_house_reference_standard','direct_measurement',
     '2025-06-01','2026-06-01',1.500,'percent_reading','suspended','In-house cal not NABL-scoped — suspended'),
    ('Rainbow Children''s Hyderabad','Deepa Reddy','lux_meter','INS-RBW-009','Konica T-10A',
     'CAL-RBW-9001','Konica Minolta Cal','manufacturer_reference','comparison_against_reference',
     '2025-02-14','2026-02-14',3.000,'lux','pending_recalibration','Phototherapy lux meter awaiting recal')
  ) as q(hosp, eng, itype, tag, model, cert, lab, std, meth, issd, expd, unc, uunit, status, nt);

  -- 6 CAPA / renewal action rows — attach to specific certificates by cert_number
  insert into public.engineer_calibration_capa_actions_r3139 (
    calibration_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('CAL-FRT-2001','certificate_expired','calibration_overdue','schedule_recalibration',
     '2026-07-25',null,'in_progress','nabh_finding',18000.00,'Defib analyzer overdue — recal booked with Datrend'),
    ('CAL-FRT-2002','certificate_expired','vendor_delay','send_to_nabl_lab',
     '2026-07-28',null,'open','iso_13485_deviation',22000.00,'ESA dispatched to Rigel NABL lab'),
    ('CAL-AIM-4001','recall_notice_issued','instrument_drift','replace_instrument',
     '2026-07-20','2026-07-15','closed','cdsco_notifiable',45000.00,'DMM recalled by mfr — unit replaced and verified'),
    ('CAL-KIM-5002','certificate_expired','calibration_overdue','schedule_recalibration',
     '2026-06-30',null,'overdue','nabl_nonconformity',9000.00,'Vacuum gauge cert lapsed — NABL nonconformity in audit'),
    ('CAL-STJ-8001','traceability_gap','lab_scope_not_accredited','switch_accredited_lab',
     '2026-08-05',null,'escalated','nabl_nonconformity',15000.00,'In-house cal not NABL-scoped — switching to accredited lab'),
    ('CAL-RBW-9001','certificate_expiring','reference_standard_expired','schedule_recalibration',
     '2026-07-22',null,'verification_pending','internal_only',5000.00,'Reference lux standard expired — recal pending')
  ) as q(cert_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.engineer_calibration_r3139 e
    on e.organization_id = v_org_id and e.cert_number = q.cert_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Certificate status distribution
create or replace function public.founder_r3139_cert_status_rollup()
returns table(cert_status text, certs bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_calibration_r3139)
  select l.cert_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_calibration_r3139 l
  group by l.cert_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3139_cert_status_rollup() from public, anon;
grant execute on function public.founder_r3139_cert_status_rollup() to authenticated;

-- 2) Hospital-level traceability scorecard
create or replace function public.founder_r3139_hospital_scorecard()
returns table(
  hospital_name text,
  total_certs bigint,
  valid_certs bigint,
  expiring_soon bigint,
  expired bigint,
  recalled bigint,
  suspended bigint,
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
    count(*) filter (where l.cert_status = 'valid')::bigint,
    count(*) filter (where l.cert_status = 'expiring_soon')::bigint,
    count(*) filter (where l.cert_status = 'expired')::bigint,
    count(*) filter (where l.cert_status = 'recalled')::bigint,
    count(*) filter (where l.cert_status = 'suspended')::bigint,
    round(100.0 * count(*) filter (where l.cert_status = 'valid')::numeric / nullif(count(*),0), 1)
  from public.engineer_calibration_r3139 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3139_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3139_hospital_scorecard() to authenticated;

-- 3) Instrument type × traceability standard breakdown
create or replace function public.founder_r3139_instrument_standard_matrix()
returns table(instrument_type text, calibration_standard text, certs bigint, valid_certs bigint, avg_uncertainty numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_type, l.calibration_standard, count(*)::bigint,
    count(*) filter (where l.cert_status = 'valid')::bigint,
    round(avg(l.measurement_uncertainty), 3)
  from public.engineer_calibration_r3139 l
  group by l.instrument_type, l.calibration_standard
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3139_instrument_standard_matrix() from public, anon;
grant execute on function public.founder_r3139_instrument_standard_matrix() to authenticated;

-- 4) Certificate expiry timeline trend
create or replace function public.founder_r3139_expiry_trend()
returns table(expiry_date date, certs bigint, valid_certs bigint, expiring_soon bigint, expired bigint, recalled bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.expiry_date,
    count(*)::bigint,
    count(*) filter (where l.cert_status = 'valid')::bigint,
    count(*) filter (where l.cert_status = 'expiring_soon')::bigint,
    count(*) filter (where l.cert_status = 'expired')::bigint,
    count(*) filter (where l.cert_status = 'recalled')::bigint
  from public.engineer_calibration_r3139 l
  group by l.expiry_date
  order by l.expiry_date desc;
end;
$$;

revoke execute on function public.founder_r3139_expiry_trend() from public, anon;
grant execute on function public.founder_r3139_expiry_trend() to authenticated;

-- 5) CAPA / renewal action status board
create or replace function public.founder_r3139_capa_status_board()
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
  from public.engineer_calibration_capa_actions_r3139 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3139_capa_status_board() from public, anon;
grant execute on function public.founder_r3139_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3139_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_calibration_capa_actions_r3139)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_calibration_capa_actions_r3139 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3139_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3139_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3139_regulatory_impact_digest()
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
  from public.engineer_calibration_capa_actions_r3139 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3139_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3139_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority certificate queue
create or replace function public.founder_r3139_priority_queue()
returns table(
  hospital_name text,
  engineer_name text,
  instrument_type text,
  cert_number text,
  nabl_lab_name text,
  expiry_date date,
  cert_status text,
  measurement_uncertainty numeric,
  uncertainty_unit text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.engineer_name, l.instrument_type, l.cert_number, l.nabl_lab_name,
    l.expiry_date, l.cert_status, l.measurement_uncertainty, l.uncertainty_unit, l.notes
  from public.engineer_calibration_r3139 l
  where l.cert_status in ('expired','recalled','suspended','expiring_soon','pending_recalibration')
  order by l.expiry_date asc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3139_priority_queue() from public, anon;
grant execute on function public.founder_r3139_priority_queue() to authenticated;
