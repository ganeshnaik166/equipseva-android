-- Round 3194: Customer Hospital Haemodialysis Machine Conductivity & Disinfection-Cycle Audit
-- HD machine QA log — dialysate conductivity × temperature × blood-leak/air detectors × heparin-pump accuracy × disinfection cycle × CAPA

-- =============================================================================
-- TABLE 1: hd_machine_r3194 — individual haemodialysis machine QA audits
-- =============================================================================
create table if not exists public.hd_machine_r3194 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  dialysis_unit_code text not null,
  machine_asset_tag text not null,
  machine_model text not null,
  audit_date date not null,
  dialysate_conductivity_ms_cm numeric(5,2) not null,
  dialysate_temperature_c numeric(4,1) not null,
  blood_leak_detector_test text not null check (blood_leak_detector_test in (
    'pass','fail','not_tested','intermittent_alarm'
  )),
  air_detector_test text not null check (air_detector_test in (
    'pass','fail','not_tested','delayed_response'
  )),
  heparin_pump_accuracy_pct numeric(5,2),
  heparin_pump_verdict text not null check (heparin_pump_verdict in (
    'within_tolerance','out_of_tolerance','borderline','not_tested'
  )),
  disinfection_cycle_type text not null check (disinfection_cycle_type in (
    'heat_disinfection','citric_acid_heat','chemical_hypochlorite','chemical_peracetic','none_skipped'
  )),
  disinfection_cycle_completed boolean not null default false,
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','restricted_use','out_of_service','pending_review','recalibration_needed','condemned'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hd_machine_r3194 enable row level security;

create index if not exists idx_hd_machine_r3194_org on public.hd_machine_r3194(organization_id);
create index if not exists idx_hd_machine_r3194_date on public.hd_machine_r3194(audit_date);
create index if not exists idx_hd_machine_r3194_verdict on public.hd_machine_r3194(audit_verdict);

-- =============================================================================
-- TABLE 2: hd_machine_capa_actions_r3194 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hd_machine_capa_actions_r3194 (
  id uuid primary key default gen_random_uuid(),
  machine_log_id uuid not null references public.hd_machine_r3194(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'conductivity_out_of_range','temperature_deviation','blood_leak_detector_fail','air_detector_fail',
    'heparin_pump_drift','disinfection_incomplete','residual_disinfectant_detected','water_quality_endotoxin',
    'preventive_maintenance_due','operator_error'
  )),
  root_cause text not null check (root_cause in (
    'conductivity_cell_drift','concentrate_pump_wear','heater_element_degraded',
    'detector_sensor_fouled','ultrasonic_sensor_misaligned','peristaltic_tubing_worn',
    'descale_backlog','hard_feed_water','bleach_dosing_error','operator_shift_handover_gap',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_conductivity_cell','replace_concentrate_pump','replace_heater_element',
    'clean_blood_leak_detector','realign_air_detector','replace_heparin_pump_tubing',
    'rerun_disinfection_cycle','descale_hydraulics','retrain_operator','schedule_amc_visit','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_23500_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hd_machine_capa_actions_r3194 enable row level security;

create index if not exists idx_hd_capa_r3194_machine on public.hd_machine_capa_actions_r3194(machine_log_id);
create index if not exists idx_hd_capa_r3194_status on public.hd_machine_capa_actions_r3194(capa_status);

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

  -- 13 machine audit rows
  insert into public.hd_machine_r3194 (
    organization_id, hospital_name, dialysis_unit_code, machine_asset_tag, machine_model,
    audit_date, dialysate_conductivity_ms_cm, dialysate_temperature_c,
    blood_leak_detector_test, air_detector_test,
    heparin_pump_accuracy_pct, heparin_pump_verdict,
    disinfection_cycle_type, disinfection_cycle_completed,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.unit, q.tag, q.model,
    q.ad::date, q.cond, q.temp,
    q.blt, q.adt,
    q.hpa, q.hpv,
    q.dct, q.dcc,
    q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','HDU-A','HD-APL-101','Fresenius 4008S','2026-07-10',14.10,36.5,
     'pass','pass',99.20,'within_tolerance','heat_disinfection',true,'fit_for_use','Routine monthly QA — all parameters nominal'),
    ('Apollo Hyderabad Jubilee Hills','HDU-A','HD-APL-102','Fresenius 4008S','2026-07-10',15.30,36.4,
     'pass','pass',97.80,'within_tolerance','citric_acid_heat',true,'restricted_use','Conductivity 15.3 above 14.6 alert band — restricted to low-flux sessions'),
    ('Fortis Bannerghatta Bengaluru','HDU-1','HD-FRT-201','Nipro Surdial X','2026-07-09',13.90,36.6,
     'fail','pass',98.90,'within_tolerance','heat_disinfection',true,'out_of_service','Blood-leak detector failed challenge test — machine pulled from roster'),
    ('Fortis Bannerghatta Bengaluru','HDU-1','HD-FRT-202','Nipro Surdial X','2026-07-09',14.05,36.5,
     'pass','delayed_response',96.40,'borderline','chemical_hypochlorite',true,'pending_review','Air detector alarm delayed 2.1s; heparin pump at tolerance edge'),
    ('Manipal Whitefield Bengaluru','HDU-2','HD-MNP-301','B Braun Dialog+','2026-07-08',14.20,37.9,
     'pass','pass',99.00,'within_tolerance','heat_disinfection',true,'recalibration_needed','Dialysate temp 37.9C above 37.5 limit — heater control drifting'),
    ('Manipal Whitefield Bengaluru','HDU-2','HD-MNP-302','B Braun Dialog+','2026-07-08',14.15,36.4,
     'pass','pass',99.40,'within_tolerance','citric_acid_heat',false,'restricted_use','Citric heat cycle aborted at 78 percent — rerun scheduled tonight'),
    ('AIIMS New Delhi Ansari Nagar','HDU-3','HD-AIM-401','Fresenius 5008S','2026-07-07',14.00,36.5,
     'pass','pass',99.60,'within_tolerance','heat_disinfection',true,'fit_for_use','Reference machine — used for cross-checking conductivity meters'),
    ('AIIMS New Delhi Ansari Nagar','HDU-3','HD-AIM-402','Fresenius 5008S','2026-07-07',12.60,36.3,
     'pass','pass',98.20,'within_tolerance','chemical_peracetic',true,'out_of_service','Conductivity 12.6 below 13.0 floor — concentrate pump suspected'),
    ('KIMS Secunderabad','HDU-B','HD-KIM-501','Nikkiso DBB-27','2026-07-06',14.30,36.6,
     'pass','fail',null,'not_tested','heat_disinfection',true,'out_of_service','Air detector failed bubble challenge — immediate removal from service'),
    ('Care Hospitals Banjara Hills','HDU-1','HD-CAR-601','B Braun Dialog iQ','2026-07-06',14.25,36.5,
     'pass','pass',91.50,'out_of_tolerance','citric_acid_heat',true,'recalibration_needed','Heparin pump delivering 8.5 percent under set rate'),
    ('Yashoda Somajiguda Hyderabad','HDU-2','HD-YSH-701','Fresenius 4008B','2026-07-05',14.10,36.4,
     'pass','pass',98.70,'within_tolerance','none_skipped',false,'pending_review','Disinfection skipped after last shift — machine held pending cycle'),
    ('St John''s Bengaluru','HDU-1','HD-STJ-801','Nipro Surdial 55 Plus','2026-07-05',14.05,36.5,
     'pass','pass',99.10,'within_tolerance','heat_disinfection',true,'fit_for_use','Quarterly audit clean — next due October'),
    ('Rainbow Children''s Hyderabad','HDU-P','HD-RBW-901','Fresenius 4008S NG','2026-07-04',14.18,36.2,
     'intermittent_alarm','pass',98.00,'within_tolerance','heat_disinfection',true,'restricted_use','Blood-leak detector intermittent alarm — paediatric use suspended')
  ) as q(hosp, unit, tag, model, ad, cond, temp, blt, adt, hpa, hpv, dct, dcc, av, nt);

  -- CAPA seed — attach to specific machines
  insert into public.hd_machine_capa_actions_r3194 (
    machine_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('HD-FRT-201','blood_leak_detector_fail','detector_sensor_fouled','clean_blood_leak_detector','2026-07-14',null,'in_progress','patient_safety_alert',8500.00,'Optical window cleaned; challenge retest pending'),
    ('HD-AIM-402','conductivity_out_of_range','concentrate_pump_wear','replace_concentrate_pump','2026-07-12',null,'escalated','cdsco_notifiable',62000.00,'Pump kit on order from Fresenius — loaner machine deployed'),
    ('HD-KIM-501','air_detector_fail','ultrasonic_sensor_misaligned','realign_air_detector','2026-07-10','2026-07-08','closed','nabh_finding',4200.00,'Sensor realigned and bubble challenge passed'),
    ('HD-CAR-601','heparin_pump_drift','peristaltic_tubing_worn','replace_heparin_pump_tubing','2026-07-11',null,'verification_pending','iso_23500_deviation',3100.00,'New tubing fitted; 24h accuracy verification running'),
    ('HD-MNP-301','temperature_deviation','heater_element_degraded','replace_heater_element','2026-07-13',null,'open','internal_only',18500.00,'Heater element quote approved'),
    ('HD-MNP-302','disinfection_incomplete','descale_backlog','rerun_disinfection_cycle','2026-07-09','2026-07-08','closed','internal_only',0.00,'Cycle rerun completed and logged'),
    ('HD-YSH-701','disinfection_incomplete','operator_shift_handover_gap','retrain_operator','2026-07-08',null,'overdue','nabh_finding',0.00,'Night-shift checklist updated; retraining overdue'),
    ('HD-RBW-901','blood_leak_detector_fail','detector_sensor_fouled','clean_blood_leak_detector','2026-07-15',null,'open','patient_safety_alert',6800.00,'Intermittent alarm — detector board also under evaluation')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.hd_machine_r3194 e
    on e.organization_id = v_org_id and e.machine_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3194_audit_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hd_machine_r3194)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hd_machine_r3194 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3194_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3194_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3194_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  out_of_service bigint,
  blood_leak_fails bigint,
  air_detector_fails bigint,
  disinfection_incomplete bigint,
  avg_conductivity numeric,
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
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.blood_leak_detector_test in ('fail','intermittent_alarm'))::bigint,
    count(*) filter (where l.air_detector_test in ('fail','delayed_response'))::bigint,
    count(*) filter (where not l.disinfection_cycle_completed)::bigint,
    round(avg(l.dialysate_conductivity_ms_cm), 2),
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.hd_machine_r3194 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3194_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3194_hospital_scorecard() to authenticated;

-- 3) Disinfection cycle type matrix
create or replace function public.founder_r3194_disinfection_cycle_matrix()
returns table(disinfection_cycle_type text, audits bigint, completed bigint, fit_for_use bigint, avg_conductivity numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.disinfection_cycle_type, count(*)::bigint,
    count(*) filter (where l.disinfection_cycle_completed)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.dialysate_conductivity_ms_cm), 2)
  from public.hd_machine_r3194 l
  group by l.disinfection_cycle_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3194_disinfection_cycle_matrix() from public, anon;
grant execute on function public.founder_r3194_disinfection_cycle_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3194_daily_audit_trend()
returns table(audit_date date, audits bigint, fit_for_use bigint, out_of_service bigint, detector_fails bigint, avg_conductivity numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.blood_leak_detector_test in ('fail','intermittent_alarm')
                        or l.air_detector_test in ('fail','delayed_response'))::bigint,
    round(avg(l.dialysate_conductivity_ms_cm), 2)
  from public.hd_machine_r3194 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3194_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3194_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3194_capa_status_board()
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
  from public.hd_machine_capa_actions_r3194 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3194_capa_status_board() from public, anon;
grant execute on function public.founder_r3194_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3194_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hd_machine_capa_actions_r3194)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hd_machine_capa_actions_r3194 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3194_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3194_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3194_regulatory_impact_digest()
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
  from public.hd_machine_capa_actions_r3194 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3194_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3194_regulatory_impact_digest() to authenticated;

-- 8) High-risk machines queue
create or replace function public.founder_r3194_high_risk_machines()
returns table(
  hospital_name text,
  dialysis_unit_code text,
  machine_asset_tag text,
  audit_date date,
  audit_verdict text,
  blood_leak_detector_test text,
  air_detector_test text,
  heparin_pump_verdict text,
  disinfection_cycle_type text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.dialysis_unit_code, l.machine_asset_tag, l.audit_date,
    l.audit_verdict, l.blood_leak_detector_test, l.air_detector_test,
    l.heparin_pump_verdict, l.disinfection_cycle_type, l.notes
  from public.hd_machine_r3194 l
  where l.audit_verdict in ('restricted_use','out_of_service','pending_review','recalibration_needed','condemned')
     or l.blood_leak_detector_test in ('fail','intermittent_alarm')
     or l.air_detector_test in ('fail','delayed_response')
     or l.heparin_pump_verdict = 'out_of_tolerance'
     or not l.disinfection_cycle_completed
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3194_high_risk_machines() from public, anon;
grant execute on function public.founder_r3194_high_risk_machines() to authenticated;
