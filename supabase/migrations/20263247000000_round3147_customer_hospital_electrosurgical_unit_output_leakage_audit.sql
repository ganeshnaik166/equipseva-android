-- Round 3147: Customer Hospital Electrosurgical Unit (Diathermy) Output & Leakage-Current Audit
-- ESU QA log — output mode × set/measured power × power error % × HF leakage × REM/patient-plate alarm × LF leakage × verdict + CAPA

-- =============================================================================
-- TABLE 1: electrosurgical_unit_r3147 — individual ESU output & leakage test runs
-- =============================================================================
create table if not exists public.electrosurgical_unit_r3147 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  esu_asset_tag text not null,
  esu_model text not null,
  test_number int not null,
  test_date date not null,
  test_started_at timestamptz not null,
  test_ended_at timestamptz,
  output_mode text not null check (output_mode in (
    'monopolar_cut','monopolar_coag','monopolar_blend','bipolar_cut',
    'bipolar_coag','vessel_sealing','argon_coag','fulguration'
  )),
  set_power_watts numeric(6,2) not null,
  measured_power_watts numeric(6,2) not null,
  power_error_pct numeric(5,2) not null,
  load_resistance_ohms numeric(7,2),
  hf_leakage_current_ma numeric(6,2),
  hf_leakage_verdict text check (hf_leakage_verdict in ('pass','fail','borderline','not_run')),
  rem_patient_plate_alarm text not null check (rem_patient_plate_alarm in (
    'alarm_functional','alarm_did_not_trigger','contact_quality_fault','no_rem_capability','not_applicable'
  )),
  low_frequency_leakage_ua numeric(7,2),
  lf_leakage_verdict text check (lf_leakage_verdict in ('pass','fail','borderline','not_run')),
  test_standard text not null check (test_standard in (
    'iec_60601_2_2','iec_62353','aami_standard','manufacturer_ifu','nabh_protocol'
  )),
  operator_profile_id uuid references public.profiles(id) on delete set null,
  test_verdict text not null check (test_verdict in (
    'passed','failed','conditional_pass','quarantined','recalibration_needed','pending_review','removed_from_service'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.electrosurgical_unit_r3147 enable row level security;

create index if not exists idx_esu_r3147_org on public.electrosurgical_unit_r3147(organization_id);
create index if not exists idx_esu_r3147_date on public.electrosurgical_unit_r3147(test_date);
create index if not exists idx_esu_r3147_verdict on public.electrosurgical_unit_r3147(test_verdict);

-- =============================================================================
-- TABLE 2: electrosurgical_unit_capa_actions_r3147 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.electrosurgical_unit_capa_actions_r3147 (
  id uuid primary key default gen_random_uuid(),
  esu_test_id uuid not null references public.electrosurgical_unit_r3147(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'power_output_deviation','hf_leakage_high','lf_leakage_high','rem_alarm_failure',
    'patient_plate_fault','calibration_drift','footswitch_fault','cable_insulation_breach',
    'isolation_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'generator_aging','output_stage_drift','damaged_hf_cable','worn_footswitch',
    'patient_plate_connector_corroded','rem_board_fault','insulation_degraded',
    'calibration_overdue','operator_setup_error','pending_investigation','power_supply_instability'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_generator','replace_hf_cable','replace_patient_plate_cable','repair_rem_board',
    'replace_footswitch','replace_output_module','retrain_operator','quarantine_unit',
    'schedule_amc_visit','none_required','dielectric_retest'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iec_60601_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.electrosurgical_unit_capa_actions_r3147 enable row level security;

create index if not exists idx_esu_capa_r3147_test on public.electrosurgical_unit_capa_actions_r3147(esu_test_id);
create index if not exists idx_esu_capa_r3147_status on public.electrosurgical_unit_capa_actions_r3147(capa_status);

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

  -- 14 ESU output & leakage test rows
  insert into public.electrosurgical_unit_r3147 (
    organization_id, hospital_name, ot_room_code, esu_asset_tag, esu_model,
    test_number, test_date, test_started_at, test_ended_at,
    output_mode, set_power_watts, measured_power_watts, power_error_pct, load_resistance_ohms,
    hf_leakage_current_ma, hf_leakage_verdict, rem_patient_plate_alarm,
    low_frequency_leakage_ua, lf_leakage_verdict, test_standard,
    test_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.tn::int, q.td::date, q.ts::timestamptz, q.te::timestamptz,
    q.om, q.sp, q.mp, q.pe, q.lr,
    q.hf, q.hfv, q.rem,
    q.lf, q.lfv, q.std,
    q.tv, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-3','ESU-APL-021','Medtronic Valleylab FT10','1','2026-07-01','2026-07-01 06:10:00+05:30','2026-07-01 06:40:00+05:30',
     'monopolar_cut',300,297,-1.00,300,52.00,'pass','alarm_functional',95.00,'pass','iec_60601_2_2','passed','2026-07-01 07:00:00+05:30','Annual QA cut mode within tolerance'),
    ('Apollo Hyderabad Jubilee Hills','OT-3','ESU-APL-021','Medtronic Valleylab FT10','2','2026-07-01','2026-07-01 06:45:00+05:30','2026-07-01 07:15:00+05:30',
     'monopolar_coag',120,118,-1.67,300,48.00,'pass','alarm_functional',88.00,'pass','iec_60601_2_2','passed','2026-07-01 07:30:00+05:30','Coag mode nominal output'),
    ('Fortis Bannerghatta Bengaluru','OT-1','ESU-FRT-014','Erbe VIO 300 D','8','2026-07-01','2026-07-01 05:30:00+05:30','2026-07-01 06:05:00+05:30',
     'monopolar_coag',80,86,7.50,500,168.00,'fail','alarm_functional',140.00,'borderline','iec_60601_2_2','failed',null,'HF leakage 168 mA exceeds 150 mA limit'),
    ('Fortis Bannerghatta Bengaluru','OT-1','ESU-FRT-014','Erbe VIO 300 D','9','2026-07-01','2026-07-01 06:20:00+05:30','2026-07-01 06:50:00+05:30',
     'monopolar_blend',150,151,0.67,300,60.00,'pass','alarm_did_not_trigger',96.00,'pass','iec_60601_2_2','removed_from_service',null,'REM alarm failed to trigger on plate disconnect unit removed'),
    ('Manipal Whitefield Bengaluru','OT-2','ESU-MNP-030','Covidien ForceTriad','15','2026-06-30','2026-06-30 08:15:00+05:30','2026-06-30 08:50:00+05:30',
     'monopolar_cut',300,268,-10.67,300,58.00,'pass','alarm_functional',110.00,'pass','iec_60601_2_2','recalibration_needed',null,'Cut power 10.7 pct low output stage drift suspected'),
    ('Manipal Whitefield Bengaluru','OT-2','ESU-MNP-030','Covidien ForceTriad','16','2026-06-30','2026-06-30 09:30:00+05:30','2026-06-30 10:05:00+05:30',
     'vessel_sealing',95,94,-1.05,50,40.00,'pass','not_applicable',75.00,'pass','manufacturer_ifu','passed','2026-06-30 10:20:00+05:30','Post recalibration verification passed'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','ESU-AIM-042','Bowa ARC 400','42','2026-06-30','2026-06-30 06:00:00+05:30','2026-06-30 06:35:00+05:30',
     'bipolar_cut',40,40,0.00,100,38.00,'pass','not_applicable',70.00,'pass','iec_62353','passed','2026-06-30 06:50:00+05:30','Neurosurgery bipolar precise output'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','ESU-AIM-042','Bowa ARC 400','43','2026-06-30','2026-06-30 07:00:00+05:30','2026-06-30 07:40:00+05:30',
     'argon_coag',120,114,-5.00,500,145.00,'borderline','alarm_functional',118.00,'pass','iec_60601_2_2','conditional_pass','2026-06-30 07:55:00+05:30','HF leakage 145 mA near limit monitor next cycle'),
    ('KIMS Secunderabad','OT-4','ESU-KIM-018','Olympus ESG-400','28','2026-06-29','2026-06-29 05:45:00+05:30','2026-06-29 06:20:00+05:30',
     'monopolar_coag',90,88,-2.22,500,62.00,'pass','alarm_functional',520.00,'fail','iec_62353','quarantined',null,'Enclosure leakage 520 uA exceeds 500 uA limit earth fault suspected'),
    ('KIMS Secunderabad','OT-4','ESU-KIM-018','Olympus ESG-400','29','2026-06-29','2026-06-29 06:40:00+05:30','2026-06-29 07:10:00+05:30',
     'monopolar_cut',200,205,2.50,300,55.00,'pass','contact_quality_fault',102.00,'pass','iec_60601_2_2','removed_from_service',null,'CQM contact quality fault return electrode circuit unit pulled'),
    ('Care Hospitals Banjara Hills','OT-2','ESU-CAR-009','Medtronic Valleylab FX8','11','2026-06-29','2026-06-29 09:00:00+05:30','2026-06-29 09:30:00+05:30',
     'bipolar_coag',50,50,0.00,100,42.00,'pass','not_applicable',80.00,'pass','iec_60601_2_2','passed','2026-06-29 09:45:00+05:30','Routine bipolar check within spec'),
    ('Yashoda Somajiguda Hyderabad','OT-6','ESU-YSH-025','Erbe VIO 3','67','2026-06-28','2026-06-28 06:30:00+05:30','2026-06-28 07:05:00+05:30',
     'monopolar_cut',250,248,-0.80,300,50.00,'pass','alarm_functional',90.00,'pass','iec_60601_2_2','passed','2026-06-28 07:20:00+05:30','Monthly QA within tolerance'),
    ('St John''s Bengaluru','OT-1','ESU-STJ-006','KLS Martin maXium','9','2026-06-28','2026-06-28 05:50:00+05:30','2026-06-28 06:25:00+05:30',
     'fulguration',80,79,-1.25,500,130.00,'pass','alarm_functional',115.00,'pass','nabh_protocol','passed','2026-06-28 06:40:00+05:30','Fulguration spray coag output stable'),
    ('Rainbow Children''s Hyderabad','OT-3','ESU-RBW-012','Soring CPC','24','2026-06-27','2026-06-27 07:00:00+05:30',null,
     'bipolar_coag',30,26,-13.33,100,41.00,'borderline','not_applicable',68.00,'pass','manufacturer_ifu','pending_review',null,'Pediatric low power output unstable test aborted mid run')
  ) as q(hosp, ot, tag, model, tn, td, ts, te, om, sp, mp, pe, lr, hf, hfv, rem, lf, lfv, std, tv, rel, nt)
  where q.tn ~ '^[0-9]+$';

  -- CAPA seed — attach to specific tests
  insert into public.electrosurgical_unit_capa_actions_r3147 (
    esu_test_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru', 8, 'hf_leakage_high','insulation_degraded','replace_hf_cable','2026-07-05',null,'in_progress','patient_safety_alert',18000.00,'HF active cable insulation breached replacement ordered'),
    ('Fortis Bannerghatta Bengaluru', 9, 'rem_alarm_failure','rem_board_fault','repair_rem_board','2026-07-05',null,'escalated','cdsco_notifiable',35000.00,'REM board did not alarm on plate disconnect safety critical'),
    ('Manipal Whitefield Bengaluru', 15, 'power_output_deviation','output_stage_drift','recalibrate_generator','2026-07-02','2026-06-30','closed','iec_60601_deviation',9000.00,'Output recalibrated cut power restored to spec'),
    ('KIMS Secunderabad',            28, 'lf_leakage_high','insulation_degraded','dielectric_retest','2026-07-03',null,'verification_pending','nabh_finding',7500.00,'Earth leakage 520 uA insulation resistance retest scheduled'),
    ('KIMS Secunderabad',            29, 'patient_plate_fault','patient_plate_connector_corroded','replace_patient_plate_cable','2026-07-04',null,'open','patient_safety_alert',6000.00,'CQM contact fault plate connector corroded cable replaced'),
    ('Rainbow Children''s Hyderabad', 24, 'calibration_drift','calibration_overdue','schedule_amc_visit','2026-07-06',null,'open','internal_only',5000.00,'Low power instability pediatric unit calibration overdue'),
    ('Apollo Hyderabad Jubilee Hills',1, 'preventive_maintenance_due','calibration_overdue','schedule_amc_visit','2026-07-15',null,'open','none',12000.00,'Annual dielectric strength PM due next quarter')
  ) as q(hosp_key, tn_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.electrosurgical_unit_r3147 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp_key and e.test_number = q.tn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Test verdict distribution
create or replace function public.founder_r3147_verdict_rollup()
returns table(test_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.electrosurgical_unit_r3147)
  select l.test_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.electrosurgical_unit_r3147 l
  group by l.test_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3147_verdict_rollup() from public, anon;
grant execute on function public.founder_r3147_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3147_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  passed bigint,
  quarantined bigint,
  removed bigint,
  hf_fail bigint,
  lf_fail bigint,
  rem_issues bigint,
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
    count(*) filter (where l.test_verdict = 'passed')::bigint,
    count(*) filter (where l.test_verdict = 'quarantined')::bigint,
    count(*) filter (where l.test_verdict = 'removed_from_service')::bigint,
    count(*) filter (where l.hf_leakage_verdict = 'fail')::bigint,
    count(*) filter (where l.lf_leakage_verdict = 'fail')::bigint,
    count(*) filter (where l.rem_patient_plate_alarm in ('alarm_did_not_trigger','contact_quality_fault'))::bigint,
    round(100.0 * count(*) filter (where l.test_verdict = 'passed')::numeric / nullif(count(*),0), 1)
  from public.electrosurgical_unit_r3147 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3147_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3147_hospital_scorecard() to authenticated;

-- 3) Output-mode × test-standard matrix
create or replace function public.founder_r3147_mode_standard_matrix()
returns table(output_mode text, test_standard text, tests bigint, passed bigint, avg_power_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.output_mode, l.test_standard, count(*)::bigint,
    count(*) filter (where l.test_verdict = 'passed')::bigint,
    round(avg(l.power_error_pct), 2)
  from public.electrosurgical_unit_r3147 l
  group by l.output_mode, l.test_standard
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3147_mode_standard_matrix() from public, anon;
grant execute on function public.founder_r3147_mode_standard_matrix() to authenticated;

-- 4) HF & LF leakage daily trend
create or replace function public.founder_r3147_leakage_daily_trend()
returns table(test_date date, hf_pass bigint, hf_fail bigint, lf_pass bigint, lf_fail bigint, lf_borderline bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*) filter (where l.hf_leakage_verdict = 'pass')::bigint,
    count(*) filter (where l.hf_leakage_verdict = 'fail')::bigint,
    count(*) filter (where l.lf_leakage_verdict = 'pass')::bigint,
    count(*) filter (where l.lf_leakage_verdict = 'fail')::bigint,
    count(*) filter (where l.lf_leakage_verdict = 'borderline')::bigint
  from public.electrosurgical_unit_r3147 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3147_leakage_daily_trend() from public, anon;
grant execute on function public.founder_r3147_leakage_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3147_capa_status_board()
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
  from public.electrosurgical_unit_capa_actions_r3147 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3147_capa_status_board() from public, anon;
grant execute on function public.founder_r3147_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3147_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.electrosurgical_unit_capa_actions_r3147)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.electrosurgical_unit_capa_actions_r3147 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3147_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3147_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3147_regulatory_impact_digest()
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
  from public.electrosurgical_unit_capa_actions_r3147 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3147_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3147_regulatory_impact_digest() to authenticated;

-- 8) High-risk ESU priority queue (top individual concerns)
create or replace function public.founder_r3147_high_risk_units()
returns table(
  hospital_name text,
  ot_room_code text,
  esu_asset_tag text,
  test_date date,
  test_verdict text,
  output_mode text,
  hf_leakage_verdict text,
  lf_leakage_verdict text,
  rem_patient_plate_alarm text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.esu_asset_tag, l.test_date,
    l.test_verdict, l.output_mode, l.hf_leakage_verdict, l.lf_leakage_verdict, l.rem_patient_plate_alarm, l.notes
  from public.electrosurgical_unit_r3147 l
  where l.test_verdict in ('failed','quarantined','recalibration_needed','pending_review','removed_from_service','conditional_pass')
     or l.hf_leakage_verdict = 'fail'
     or l.lf_leakage_verdict = 'fail'
     or l.rem_patient_plate_alarm in ('alarm_did_not_trigger','contact_quality_fault')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3147_high_risk_units() from public, anon;
grant execute on function public.founder_r3147_high_risk_units() to authenticated;
