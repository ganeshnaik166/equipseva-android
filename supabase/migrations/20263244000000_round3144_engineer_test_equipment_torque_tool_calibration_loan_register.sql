-- Round 3144: Engineer Test-Equipment & Torque-Tool Calibration Loan Register
-- BMET test-gear register — instrument × asset tag × cal-due × cal-status × loaned-to engineer × loan/return × condition × verdict + loan/CAPA actions

-- =============================================================================
-- TABLE 1: engineer_test_equipment_r3144 — test-gear + calibration + loan log
-- =============================================================================
create table if not exists public.engineer_test_equipment_r3144 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  store_location_code text not null,
  instrument_type text not null check (instrument_type in (
    'electrical_safety_analyser','defibrillator_analyser','patient_monitor_simulator',
    'infusion_pump_analyser','torque_wrench','digital_multimeter','tachometer',
    'pressure_gauge_tester','gas_flow_analyser','spo2_simulator','esu_analyser','ventilator_tester'
  )),
  instrument_model text not null,
  asset_tag text not null,
  serial_number text,
  calibration_lab text,
  cal_certificate_no text,
  last_calibration_date date,
  cal_due_date date not null,
  cal_status text not null check (cal_status in (
    'calibrated_in_tolerance','calibration_due','calibration_overdue','out_of_tolerance',
    'awaiting_calibration','calibration_in_progress','cert_expired','not_required'
  )),
  loaned_to_name text,
  loaned_to_engineer_id uuid references public.engineers(id) on delete set null,
  loan_out_date date,
  expected_return_date date,
  actual_return_date date,
  loan_status text not null check (loan_status in (
    'available_in_store','loaned_out','overdue_return','returned_ok',
    'returned_damaged','lost_in_field','reserved','in_calibration'
  )),
  condition_on_return text check (condition_on_return in (
    'good_working','minor_wear','probe_damaged','out_of_calibration',
    'physical_damage','not_returned','battery_faulty','case_seal_broken'
  )),
  torque_setpoint_nm numeric(6,2),
  as_found_error_pct numeric(6,2),
  register_verdict text not null check (register_verdict in (
    'fit_for_use','quarantined','recall_from_field','send_for_calibration',
    'condemn_dispose','pending_review','conditional_use','loan_blocked'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_test_equipment_r3144 enable row level security;

create index if not exists idx_eng_test_equip_r3144_org on public.engineer_test_equipment_r3144(organization_id);
create index if not exists idx_eng_test_equip_r3144_due on public.engineer_test_equipment_r3144(cal_due_date);
create index if not exists idx_eng_test_equip_r3144_verdict on public.engineer_test_equipment_r3144(register_verdict);

-- =============================================================================
-- TABLE 2: engineer_test_equipment_capa_actions_r3144 — CAPA & loan actions
-- =============================================================================
create table if not exists public.engineer_test_equipment_capa_actions_r3144 (
  id uuid primary key default gen_random_uuid(),
  test_equipment_id uuid not null references public.engineer_test_equipment_r3144(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_overdue','out_of_tolerance','probe_damaged','not_returned_by_engineer',
    'cert_lost','physical_damage','loan_record_missing','uncertainty_exceeded',
    'battery_failure','torque_drift'
  )),
  root_cause text not null check (root_cause in (
    'engineer_retention_over_limit','harsh_field_handling','lab_backlog','vendor_cal_delay',
    'probe_wear','transport_damage','calibration_interval_too_long','store_process_gap',
    'battery_end_of_life','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'recall_and_recalibrate','replace_probe','issue_replacement_unit','shorten_cal_interval',
    'retrain_engineer_handling','expedite_lab_dispatch','write_off_and_procure',
    'update_loan_sop','replace_battery','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','nabl_traceability_gap','cdsco_notifiable','iso_13485_deviation',
    'internal_only','patient_safety_alert','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.engineer_test_equipment_capa_actions_r3144 enable row level security;

create index if not exists idx_eng_test_capa_r3144_equip on public.engineer_test_equipment_capa_actions_r3144(test_equipment_id);
create index if not exists idx_eng_test_capa_r3144_status on public.engineer_test_equipment_capa_actions_r3144(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 14 test-equipment register rows
  insert into public.engineer_test_equipment_r3144 (
    organization_id, hospital_name, store_location_code, instrument_type, instrument_model,
    asset_tag, serial_number, calibration_lab, cal_certificate_no,
    last_calibration_date, cal_due_date, cal_status,
    loaned_to_name, loan_out_date, expected_return_date, actual_return_date,
    loan_status, condition_on_return, torque_setpoint_nm, as_found_error_pct,
    register_verdict, notes
  )
  select v_org_id, q.hosp, q.loc, q.itype, q.model,
    q.tag, q.sn, q.lab, q.cert,
    q.lcd::date, q.cdd::date, q.cstat,
    q.eng, q.lod::date, q.erd::date, q.ard::date,
    q.lstat, q.cond, q.torque, q.aserr,
    q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','BME-STORE-01','electrical_safety_analyser','Fluke ESA615','TE-APL-001','ESA615-88213','Fluke Calibration Bengaluru','NABL-CC-2026-1188','2026-01-15','2027-01-14','calibrated_in_tolerance','Ravi Kumar','2026-07-10','2026-07-17',null,'loaned_out',null,null,0.20,'fit_for_use','ESA on loan for Apollo OT rounds'),
    ('Apollo Hyderabad Jubilee Hills','BME-STORE-01','torque_wrench','Norbar TTi 50','TE-APL-014','TTi50-4471','Norbar Torque Tools India','NABL-TQ-2026-0442','2025-08-20','2026-08-19','calibration_due','Ravi Kumar','2026-07-05','2026-07-12','2026-07-11','returned_ok','good_working',25.00,1.10,'fit_for_use','Ortho drill torque checks'),
    ('Fortis Bannerghatta Bengaluru','BME-STORE-02','defibrillator_analyser','Fluke Impulse 7000DP','TE-FRT-007','IMP7000-2231','Fluke Calibration Bengaluru','NABL-CC-2025-0912','2025-06-30','2026-06-29','calibration_overdue','Suresh Nair','2026-06-20',null,null,'overdue_return',null,null,3.40,'recall_from_field','Analyser overdue cal AND overdue return from field'),
    ('Fortis Bannerghatta Bengaluru','BME-STORE-02','digital_multimeter','Fluke 87V','TE-FRT-019','87V-77120','Fluke Calibration Bengaluru','NABL-CC-2026-0331','2026-02-10','2027-02-09','out_of_tolerance','Suresh Nair','2026-07-01','2026-07-08','2026-07-09','returned_damaged','out_of_calibration',null,4.80,'quarantined','Returned reading 4.8 pct high — quarantined'),
    ('Manipal Whitefield Bengaluru','BME-STORE-03','patient_monitor_simulator','Fluke ProSim 8','TE-MNP-021','PROSIM8-5540','Manipal Metrology Cell','NABL-CC-2026-0777','2026-03-05','2027-03-04','calibrated_in_tolerance','Anil Desai','2026-07-12','2026-07-19',null,'loaned_out',null,null,0.50,'fit_for_use','ProSim on ICU rounds'),
    ('Manipal Whitefield Bengaluru','BME-STORE-03','infusion_pump_analyser','Fluke IDA-5','TE-MNP-030','IDA5-9987','Bangalore NABL Metrology Lab','NABL-CC-2025-1450','2025-07-01','2026-07-15','awaiting_calibration','Anil Desai',null,null,null,'in_calibration',null,null,null,'send_for_calibration','Due 15 Jul — dispatched to lab'),
    ('AIIMS New Delhi Ansari Nagar','BME-STORE-04','tachometer','Extech 461920','TE-AIM-033','461920-3312','AIIMS Biomedical Metrology','NABL-CC-2026-0210','2026-01-20','2027-01-19','calibrated_in_tolerance','Deepak Sharma','2026-07-08','2026-07-15','2026-07-14','returned_ok','good_working',null,0.30,'fit_for_use','Centrifuge RPM verification'),
    ('AIIMS New Delhi Ansari Nagar','BME-STORE-04','esu_analyser','Fluke QA-ES III','TE-AIM-041','QAESIII-6650','Fluke Calibration Bengaluru','NABL-CC-2025-1601','2025-06-10','2026-06-09','calibration_overdue','Deepak Sharma','2026-05-15',null,null,'lost_in_field',null,null,null,'recall_from_field','Not returned since May — presumed lost'),
    ('KIMS Secunderabad','BME-STORE-05','pressure_gauge_tester','Additel 681','TE-KIM-011','ADT681-1120','KIMS Cal Lab','NABL-CC-2026-0505','2026-04-01','2027-03-31','calibrated_in_tolerance','Mohan Rao','2026-07-09','2026-07-16',null,'loaned_out',null,null,0.80,'fit_for_use','NIBP and ventilator pressure checks'),
    ('KIMS Secunderabad','BME-STORE-05','torque_wrench','Stahlwille 730/12','TE-KIM-018','SW73012-7781','Stahlwille India Cal','NABL-TQ-2025-0990','2025-05-12','2026-05-11','calibration_overdue','Mohan Rao','2026-06-28','2026-07-05','2026-07-06','returned_damaged','out_of_calibration',40.00,6.20,'send_for_calibration','Torque drift 6.2 pct — overdue since May'),
    ('Care Hospitals Banjara Hills','BME-STORE-06','spo2_simulator','Fluke Index 2XL','TE-CAR-005','IDX2XL-3390','Care Metrology Services','NABL-CC-2026-0640','2026-05-01','2027-04-30','calibrated_in_tolerance','Vinod Reddy','2026-07-11','2026-07-18',null,'loaned_out',null,null,0.40,'fit_for_use','SpO2 accuracy checks in NICU'),
    ('Yashoda Somajiguda Hyderabad','BME-STORE-07','gas_flow_analyser','Fluke VT650','TE-YSH-018','VT650-8850','Yashoda Biomed Lab','NABL-CC-2024-1990','2024-11-01','2025-10-31','cert_expired','Kiran Babu',null,null,null,'available_in_store','physical_damage',null,null,'condemn_dispose','Cert expired 2025, casing cracked — condemn'),
    ('St John''s Bengaluru','BME-STORE-08','ventilator_tester','IMT Analytics FlowAnalyser PF-300','TE-STJ-003','PF300-2205','IMT Analytics Cal Partner','NABL-CC-2026-0088','2026-02-01','2027-01-31','calibrated_in_tolerance','Joseph Mathew','2026-07-06','2026-07-13','2026-07-13','returned_ok','minor_wear',null,0.90,'fit_for_use','Ventilator flow and pressure verification'),
    ('Rainbow Children''s Hyderabad','BME-STORE-09','electrical_safety_analyser','Rigel 288+','TE-RBW-009','RIGEL288-4410','Rainbow Cal Cell','NABL-CC-2026-0155','2026-01-05','2027-01-04','calibration_in_progress','Sanjay Gupta','2026-07-03','2026-07-10',null,'overdue_return',null,null,1.90,'conditional_use','Loan overdue 8 days — engineer reminded')
  ) as q(hosp, loc, itype, model, tag, sn, lab, cert, lcd, cdd, cstat, eng, lod, erd, ard, lstat, cond, torque, aserr, verdict, nt);

  -- CAPA seed — attach to specific test-equipment by asset tag
  insert into public.engineer_test_equipment_capa_actions_r3144 (
    test_equipment_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cstat, q.ri, q.cost, q.nt
  from (values
    ('TE-FRT-007','not_returned_by_engineer','engineer_retention_over_limit','recall_and_recalibrate','2026-07-10',null,'in_progress','nabl_traceability_gap',12000.00,'Analyser held 30+ days in field, cal lapsed'),
    ('TE-FRT-019','out_of_tolerance','probe_wear','replace_probe','2026-07-15',null,'open','iso_13485_deviation',3500.00,'87V leads worn, reading 4.8 pct high'),
    ('TE-AIM-041','not_returned_by_engineer','engineer_retention_over_limit','issue_replacement_unit','2026-07-20',null,'escalated','patient_safety_alert',185000.00,'Unit presumed lost — procure replacement, escalate'),
    ('TE-KIM-018','torque_drift','calibration_interval_too_long','shorten_cal_interval','2026-07-12','2026-07-08','closed','nabh_finding',6500.00,'Interval cut to 6 months, recalibrated'),
    ('TE-YSH-018','cert_lost','vendor_cal_delay','write_off_and_procure','2026-06-30',null,'overdue','nabl_traceability_gap',220000.00,'Cert expired 8 months, casing cracked — write off'),
    ('TE-RBW-009','not_returned_by_engineer','store_process_gap','update_loan_sop','2026-07-14',null,'open','internal_only',0.00,'No return-reminder SOP — implement 7-day auto-alert')
  ) as q(tag, fc, rc, ca, tcd, acd, cstat, ri, cost, nt)
  join public.engineer_test_equipment_r3144 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Register verdict distribution
create or replace function public.founder_r3144_register_verdict_rollup()
returns table(register_verdict text, items bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_test_equipment_r3144)
  select l.register_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.engineer_test_equipment_r3144 l
  group by l.register_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3144_register_verdict_rollup() from public, anon;
grant execute on function public.founder_r3144_register_verdict_rollup() to authenticated;

-- 2) Hospital-level register scorecard
create or replace function public.founder_r3144_hospital_scorecard()
returns table(
  hospital_name text,
  total_items bigint,
  fit_for_use bigint,
  quarantined bigint,
  recalls bigint,
  overdue_cal bigint,
  on_loan bigint,
  not_returned bigint,
  ready_pct numeric
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
    count(*) filter (where l.register_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.register_verdict = 'quarantined')::bigint,
    count(*) filter (where l.register_verdict = 'recall_from_field')::bigint,
    count(*) filter (where l.cal_status in ('calibration_overdue','cert_expired'))::bigint,
    count(*) filter (where l.loan_status = 'loaned_out')::bigint,
    count(*) filter (where l.loan_status in ('overdue_return','lost_in_field'))::bigint,
    round(100.0 * count(*) filter (where l.register_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.engineer_test_equipment_r3144 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3144_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3144_hospital_scorecard() to authenticated;

-- 3) Instrument type × cal status matrix
create or replace function public.founder_r3144_instrument_status_matrix()
returns table(instrument_type text, cal_status text, items bigint, on_loan bigint, avg_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.instrument_type, l.cal_status, count(*)::bigint,
    count(*) filter (where l.loan_status = 'loaned_out')::bigint,
    round(avg(l.as_found_error_pct), 2)
  from public.engineer_test_equipment_r3144 l
  group by l.instrument_type, l.cal_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3144_instrument_status_matrix() from public, anon;
grant execute on function public.founder_r3144_instrument_status_matrix() to authenticated;

-- 4) Calibration-due date trend
create or replace function public.founder_r3144_calibration_due_trend()
returns table(cal_due_date date, items bigint, in_tolerance bigint, overdue bigint, out_of_tol bigint, awaiting bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cal_due_date,
    count(*)::bigint,
    count(*) filter (where l.cal_status = 'calibrated_in_tolerance')::bigint,
    count(*) filter (where l.cal_status in ('calibration_overdue','cert_expired'))::bigint,
    count(*) filter (where l.cal_status = 'out_of_tolerance')::bigint,
    count(*) filter (where l.cal_status in ('awaiting_calibration','calibration_in_progress','calibration_due'))::bigint
  from public.engineer_test_equipment_r3144 l
  group by l.cal_due_date
  order by l.cal_due_date desc;
end;
$$;

revoke execute on function public.founder_r3144_calibration_due_trend() from public, anon;
grant execute on function public.founder_r3144_calibration_due_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3144_capa_status_board()
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
  from public.engineer_test_equipment_capa_actions_r3144 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3144_capa_status_board() from public, anon;
grant execute on function public.founder_r3144_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3144_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.engineer_test_equipment_capa_actions_r3144)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.engineer_test_equipment_capa_actions_r3144 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3144_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3144_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3144_regulatory_impact_digest()
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
  from public.engineer_test_equipment_capa_actions_r3144 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3144_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3144_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (individual concerns)
create or replace function public.founder_r3144_high_risk_queue()
returns table(
  hospital_name text,
  store_location_code text,
  asset_tag text,
  instrument_type text,
  cal_due_date date,
  cal_status text,
  loan_status text,
  condition_on_return text,
  register_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.store_location_code, l.asset_tag, l.instrument_type, l.cal_due_date,
    l.cal_status, l.loan_status, l.condition_on_return, l.register_verdict, l.notes
  from public.engineer_test_equipment_r3144 l
  where l.register_verdict in ('quarantined','recall_from_field','send_for_calibration','condemn_dispose','pending_review','conditional_use','loan_blocked')
     or l.cal_status in ('calibration_overdue','out_of_tolerance','cert_expired')
     or l.loan_status in ('overdue_return','lost_in_field','returned_damaged')
  order by l.cal_due_date asc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3144_high_risk_queue() from public, anon;
grant execute on function public.founder_r3144_high_risk_queue() to authenticated;
