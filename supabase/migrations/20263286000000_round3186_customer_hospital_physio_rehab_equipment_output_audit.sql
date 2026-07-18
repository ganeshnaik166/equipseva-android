-- Round 3186: Customer Hospital Physiotherapy & Rehab Equipment (SWD/US/TENS/CPM) Output Audit
-- Physio equipment QA — device type × set intensity vs measured output × output error % × timer accuracy × electrode/applicator condition × patient-safety cutoff × CAPA

-- =============================================================================
-- TABLE 1: physio_rehab_r3186 — individual physio-equipment output audits
-- =============================================================================
create table if not exists public.physio_rehab_r3186 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  physio_unit_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'swd_shortwave_diathermy','ultrasound_therapy_1mhz','ultrasound_therapy_3mhz',
    'tens_dual_channel','ift_interferential','cpm_knee','cpm_elbow','lumbar_traction','cervical_traction'
  )),
  test_date date not null,
  tested_at timestamptz,
  set_intensity_value numeric(8,2) not null,
  set_intensity_unit text not null check (set_intensity_unit in (
    'watts','watts_per_cm2','milliamps','degrees_rom','kilograms_force'
  )),
  measured_output_value numeric(8,2),
  output_error_pct numeric(6,2),
  timer_set_minutes int,
  timer_measured_seconds int,
  timer_accuracy_verdict text not null check (timer_accuracy_verdict in (
    'within_tolerance','runs_fast','runs_slow','timer_fail','not_tested'
  )),
  electrode_applicator_condition text not null check (electrode_applicator_condition in (
    'good','worn','cracked_housing','frayed_cable','gel_pad_expired','replace_immediately'
  )),
  patient_safety_cutoff_test text not null check (patient_safety_cutoff_test in (
    'pass','fail','intermittent','not_tested'
  )),
  overall_verdict text not null check (overall_verdict in (
    'fit_for_use','restricted_use','out_of_service','calibration_due','condemn_recommended','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.physio_rehab_r3186 enable row level security;

create index if not exists idx_physio_rehab_r3186_org on public.physio_rehab_r3186(organization_id);
create index if not exists idx_physio_rehab_r3186_date on public.physio_rehab_r3186(test_date);
create index if not exists idx_physio_rehab_r3186_verdict on public.physio_rehab_r3186(overall_verdict);

-- =============================================================================
-- TABLE 2: physio_rehab_capa_actions_r3186 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.physio_rehab_capa_actions_r3186 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.physio_rehab_r3186(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'output_over_delivery','output_under_delivery','timer_drift','electrode_degraded',
    'safety_cutoff_fail','applicator_crystal_worn','cable_insulation_damage',
    'calibration_overdue','operator_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_crystal_aging','output_capacitor_drift','potentiometer_worn',
    'electrode_pad_expired','cable_flex_fatigue','timer_relay_sticky',
    'mains_voltage_fluctuation','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output','replace_transducer','replace_electrode_pads',
    'replace_patient_cable','replace_timer_module','withdraw_from_service',
    'retrain_operator','schedule_amc_visit','condemn_device','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.physio_rehab_capa_actions_r3186 enable row level security;

create index if not exists idx_physio_capa_r3186_audit on public.physio_rehab_capa_actions_r3186(audit_id);
create index if not exists idx_physio_capa_r3186_status on public.physio_rehab_capa_actions_r3186(capa_status);

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

  -- 14 audit rows
  insert into public.physio_rehab_r3186 (
    organization_id, hospital_name, physio_unit_code, device_asset_tag, device_model,
    device_type, test_date, tested_at,
    set_intensity_value, set_intensity_unit, measured_output_value, output_error_pct,
    timer_set_minutes, timer_measured_seconds, timer_accuracy_verdict,
    electrode_applicator_condition, patient_safety_cutoff_test,
    overall_verdict, notes
  )
  select v_org_id, q.hosp, q.unit, q.tag, q.model,
    q.dt, q.td::date, q.ta::timestamptz,
    q.siv, q.siu, q.mov, q.oep,
    q.tsm, q.tms, q.tav,
    q.eac, q.psc,
    q.ov, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','PHY-1','PR-APL-101','BTL 4825S Premium','ultrasound_therapy_1mhz','2026-07-02','2026-07-02 09:15:00+05:30',
     1.50,'watts_per_cm2',1.56,4.00,10,602,'within_tolerance','good','pass','fit_for_use','Annual output check — within IEC tolerance'),
    ('Apollo Hyderabad Jubilee Hills','PHY-1','PR-APL-102','Enraf-Nonius Curapuls 970','swd_shortwave_diathermy','2026-07-02','2026-07-02 10:05:00+05:30',
     250.00,'watts',212.00,-15.20,15,905,'within_tolerance','worn','pass','calibration_due','SWD output -15.2 pct — beyond 10 pct tolerance'),
    ('Fortis Bannerghatta Bengaluru','PHY-2','PR-FRT-210','Chattanooga Intelect TENS','tens_dual_channel','2026-07-01','2026-07-01 08:30:00+05:30',
     40.00,'milliamps',52.50,31.30,20,1210,'within_tolerance','gel_pad_expired','fail','out_of_service','Over-delivery 31 pct and safety cutoff failed — unit withdrawn'),
    ('Fortis Bannerghatta Bengaluru','PHY-2','PR-FRT-214','Kinetec Spectra Knee CPM','cpm_knee','2026-07-01','2026-07-01 09:20:00+05:30',
     90.00,'degrees_rom',84.00,-6.70,30,1798,'within_tolerance','good','pass','fit_for_use','ROM within clinical tolerance'),
    ('Manipal Whitefield Bengaluru','PHY-1','PR-MNP-305','Technomed SWD 500','swd_shortwave_diathermy','2026-06-30','2026-06-30 11:10:00+05:30',
     300.00,'watts',298.00,-0.70,20,1195,'within_tolerance','good','pass','fit_for_use','Post-AMC verification run'),
    ('Manipal Whitefield Bengaluru','PHY-1','PR-MNP-309','Chattanooga Triton DTS','lumbar_traction','2026-06-30','2026-06-30 12:00:00+05:30',
     30.00,'kilograms_force',24.50,-18.30,15,940,'runs_slow','frayed_cable','intermittent','out_of_service','Traction under-pulls and cable frayed — withdrawn'),
    ('AIIMS New Delhi Ansari Nagar','PHY-3','PR-AIM-410','EMS Physio Sonopuls 190','ultrasound_therapy_3mhz','2026-06-29','2026-06-29 09:45:00+05:30',
     1.00,'watts_per_cm2',1.02,2.00,8,481,'within_tolerance','good','pass','fit_for_use','3 MHz head verified with wattmeter'),
    ('AIIMS New Delhi Ansari Nagar','PHY-3','PR-AIM-412','Enraf-Nonius Endomed 482','ift_interferential','2026-06-29','2026-06-29 10:30:00+05:30',
     50.00,'milliamps',49.20,-1.60,12,718,'within_tolerance','cracked_housing','pass','restricted_use','Housing crack — supervised use only pending part'),
    ('KIMS Secunderabad','PHY-2','PR-KIM-520','Kinetec Performa CPM','cpm_knee','2026-06-28','2026-06-28 08:15:00+05:30',
     110.00,'degrees_rom',96.00,-12.70,45,2704,'within_tolerance','worn','pass','calibration_due','ROM under target — potentiometer wear suspected'),
    ('KIMS Secunderabad','PHY-2','PR-KIM-522','Johari Digital TENS 4C','tens_dual_channel','2026-06-28','2026-06-28 09:00:00+05:30',
     30.00,'milliamps',30.40,1.30,15,962,'runs_slow','good','pass','restricted_use','Timer 6.9 pct slow — sessions over-run'),
    ('Care Hospitals Banjara Hills','PHY-1','PR-CAR-608','Technomed TT-200','cervical_traction','2026-06-27','2026-06-27 10:20:00+05:30',
     12.00,'kilograms_force',12.10,0.80,10,601,'within_tolerance','good','pass','fit_for_use','Cervical traction verified with load cell'),
    ('Yashoda Somajiguda Hyderabad','PHY-4','PR-YSH-702','Enraf-Nonius Curapuls 670','swd_shortwave_diathermy','2026-06-27','2026-06-27 11:15:00+05:30',
     200.00,'watts',178.00,-11.00,15,null,'timer_fail','worn','not_tested','pending_review','Timer failed to terminate — test aborted, cutoff untested'),
    ('St John''s Bengaluru','PHY-2','PR-STJ-810','BTL 4710 Smart','ultrasound_therapy_1mhz','2026-06-26','2026-06-26 09:10:00+05:30',
     2.00,'watts_per_cm2',2.62,31.00,10,604,'within_tolerance','good','pass','condemn_recommended','Output +31 pct — transducer crystal aging, unit 12 years old'),
    ('Rainbow Children''s Hyderabad','PHY-1','PR-RBW-905','Chattanooga Primera TENS','tens_dual_channel','2026-06-26','2026-06-26 10:40:00+05:30',
     25.00,'milliamps',25.60,2.40,20,1203,'within_tolerance','gel_pad_expired','pass','restricted_use','Gel pads expired — replace before paediatric use')
  ) as q(hosp, unit, tag, model, dt, td, ta, siv, siu, mov, oep, tsm, tms, tav, eac, psc, ov, nt);

  -- CAPA seed — attach to specific audited devices
  insert into public.physio_rehab_capa_actions_r3186 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('PR-FRT-210','safety_cutoff_fail','output_capacitor_drift','withdraw_from_service','2026-07-08',null,'escalated','patient_safety_alert',18500.00,'TENS over-delivery with failed cutoff — unit sealed and tagged'),
    ('PR-MNP-309','output_under_delivery','cable_flex_fatigue','replace_patient_cable','2026-07-10','2026-07-09','closed','internal_only',6200.00,'Traction cable assembly replaced, retest -1.2 pct'),
    ('PR-STJ-810','output_over_delivery','transducer_crystal_aging','condemn_device','2026-07-20',null,'in_progress','cdsco_notifiable',145000.00,'Condemnation memo raised — replacement budget requested'),
    ('PR-YSH-702','timer_drift','timer_relay_sticky','replace_timer_module','2026-07-12',null,'verification_pending','iso_13485_deviation',9800.00,'New timer module fitted — verification retest pending'),
    ('PR-KIM-520','calibration_overdue','potentiometer_worn','recalibrate_output','2026-07-15',null,'open','nabh_finding',7500.00,'ROM calibration overdue 60 days — flagged in NABH mock audit'),
    ('PR-APL-102','output_under_delivery','output_capacitor_drift','recalibrate_output','2026-07-14',null,'in_progress','none',5400.00,'SWD output -15.2 pct — recalibration visit booked'),
    ('PR-RBW-905','electrode_degraded','electrode_pad_expired','replace_electrode_pads','2026-07-06','2026-07-05','closed','internal_only',1200.00,'Paediatric gel pads replaced from ward stock')
  ) as q(tag, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.physio_rehab_r3186 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Overall verdict distribution
create or replace function public.founder_r3186_verdict_rollup()
returns table(overall_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.physio_rehab_r3186)
  select l.overall_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.physio_rehab_r3186 l
  group by l.overall_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3186_verdict_rollup() from public, anon;
grant execute on function public.founder_r3186_verdict_rollup() to authenticated;

-- 2) Hospital-level scorecard
create or replace function public.founder_r3186_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  out_of_service bigint,
  condemn_recommended bigint,
  cutoff_fails bigint,
  avg_output_error_pct numeric,
  fit_pct numeric
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
    count(*) filter (where l.overall_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.overall_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.overall_verdict = 'condemn_recommended')::bigint,
    count(*) filter (where l.patient_safety_cutoff_test in ('fail','intermittent'))::bigint,
    round(avg(l.output_error_pct), 2),
    round(100.0 * count(*) filter (where l.overall_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.physio_rehab_r3186 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3186_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3186_hospital_scorecard() to authenticated;

-- 3) Device-type matrix
create or replace function public.founder_r3186_device_type_matrix()
returns table(device_type text, audits bigint, fit_for_use bigint, avg_abs_output_error_pct numeric, timer_fails bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, count(*)::bigint,
    count(*) filter (where l.overall_verdict = 'fit_for_use')::bigint,
    round(avg(abs(l.output_error_pct)), 2),
    count(*) filter (where l.timer_accuracy_verdict in ('timer_fail','runs_fast','runs_slow'))::bigint
  from public.physio_rehab_r3186 l
  group by l.device_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3186_device_type_matrix() from public, anon;
grant execute on function public.founder_r3186_device_type_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3186_daily_trend()
returns table(test_date date, audits bigint, fit_for_use bigint, out_of_service bigint, cutoff_fails bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.overall_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.overall_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.patient_safety_cutoff_test in ('fail','intermittent'))::bigint
  from public.physio_rehab_r3186 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3186_daily_trend() from public, anon;
grant execute on function public.founder_r3186_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3186_capa_status_board()
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
  from public.physio_rehab_capa_actions_r3186 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3186_capa_status_board() from public, anon;
grant execute on function public.founder_r3186_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3186_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.physio_rehab_capa_actions_r3186)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.physio_rehab_capa_actions_r3186 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3186_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3186_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3186_regulatory_impact_digest()
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
  from public.physio_rehab_capa_actions_r3186 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3186_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3186_regulatory_impact_digest() to authenticated;

-- 8) High-risk devices queue (top individual concerns)
create or replace function public.founder_r3186_high_risk_devices()
returns table(
  hospital_name text,
  physio_unit_code text,
  device_asset_tag text,
  device_type text,
  test_date date,
  overall_verdict text,
  output_error_pct numeric,
  patient_safety_cutoff_test text,
  electrode_applicator_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.physio_unit_code, l.device_asset_tag, l.device_type, l.test_date,
    l.overall_verdict, l.output_error_pct, l.patient_safety_cutoff_test, l.electrode_applicator_condition, l.notes
  from public.physio_rehab_r3186 l
  where l.overall_verdict in ('restricted_use','out_of_service','calibration_due','condemn_recommended','pending_review')
     or l.patient_safety_cutoff_test in ('fail','intermittent')
     or abs(l.output_error_pct) > 10
     or l.electrode_applicator_condition in ('frayed_cable','cracked_housing','gel_pad_expired','replace_immediately')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3186_high_risk_devices() from public, anon;
grant execute on function public.founder_r3186_high_risk_devices() to authenticated;
