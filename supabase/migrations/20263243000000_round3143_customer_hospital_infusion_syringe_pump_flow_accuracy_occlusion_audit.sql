-- Round 3143: Customer Hospital Infusion & Syringe Pump Flow-Accuracy & Occlusion Audit
-- Infusion/syringe/PCA pump QA log — pump type × test profile × flow error % × occlusion alarm pressure/response × bolus accuracy × verdict × CAPA

-- =============================================================================
-- TABLE 1: infusion_pump_r3143 — individual pump flow-accuracy & occlusion tests
-- =============================================================================
create table if not exists public.infusion_pump_r3143 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_code text not null,
  pump_asset_tag text not null,
  pump_model text not null,
  test_number int not null,
  test_date date not null,
  test_started_at timestamptz not null,
  test_ended_at timestamptz,
  pump_type text not null check (pump_type in (
    'volumetric_pump','syringe_pump','pca_pump','ambulatory_pump','enteral_pump','elastomeric_pump'
  )),
  test_profile text not null check (test_profile in (
    'flow_accuracy_trumpet','occlusion_alarm_test','bolus_accuracy_test',
    'rate_accuracy_low_flow','rate_accuracy_high_flow','backpressure_test',
    'air_in_line_alarm_test','downstream_occlusion_test'
  )),
  set_rate_ml_h numeric(7,2) not null,
  measured_rate_ml_h numeric(7,2),
  flow_error_pct numeric(5,2),
  occlusion_pressure_setting text check (occlusion_pressure_setting in ('low','medium','high','not_applicable')),
  occlusion_alarm_pressure_mmhg numeric(6,1),
  occlusion_response_time_sec int,
  bolus_volume_ml numeric(6,2),
  bolus_accuracy_pct numeric(5,2),
  air_in_line_alarm_result text check (air_in_line_alarm_result in ('pass','fail','not_run','not_applicable')),
  flow_accuracy_verdict text check (flow_accuracy_verdict in ('within_spec','marginal','out_of_spec','not_run')),
  operator_profile_id uuid references public.profiles(id) on delete set null,
  test_verdict text not null check (test_verdict in (
    'passed','conditional_pass','failed','quarantined','removed_from_service','pending_review','recalibration_required'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infusion_pump_r3143 enable row level security;

create index if not exists idx_infusion_pump_r3143_org on public.infusion_pump_r3143(organization_id);
create index if not exists idx_infusion_pump_r3143_date on public.infusion_pump_r3143(test_date);
create index if not exists idx_infusion_pump_r3143_verdict on public.infusion_pump_r3143(test_verdict);

-- =============================================================================
-- TABLE 2: infusion_pump_capa_actions_r3143 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.infusion_pump_capa_actions_r3143 (
  id uuid primary key default gen_random_uuid(),
  pump_log_id uuid not null references public.infusion_pump_r3143(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'flow_rate_deviation','occlusion_alarm_failure','occlusion_response_slow','bolus_inaccuracy',
    'air_in_line_failure','battery_failure','mechanical_wear','software_fault',
    'preventive_maintenance_due','keypad_fault'
  )),
  root_cause text not null check (root_cause in (
    'peristaltic_mechanism_wear','pressure_sensor_drift','tubing_incompatibility','occlusion_sensor_fault',
    'battery_degraded','firmware_bug','calibration_expired','motor_gear_wear',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_peristaltic_mechanism','recalibrate_pressure_sensor','replace_occlusion_sensor','firmware_upgrade',
    'replace_battery_pack','recalibrate_flow','retrain_operator','quarantine_pump',
    'remove_from_service','schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
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

alter table public.infusion_pump_capa_actions_r3143 enable row level security;

create index if not exists idx_infusion_pump_capa_r3143_log on public.infusion_pump_capa_actions_r3143(pump_log_id);
create index if not exists idx_infusion_pump_capa_r3143_status on public.infusion_pump_capa_actions_r3143(capa_status);

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

  -- 14 pump test rows
  insert into public.infusion_pump_r3143 (
    organization_id, hospital_name, ward_code, pump_asset_tag, pump_model,
    test_number, test_date, test_started_at, test_ended_at,
    pump_type, test_profile, set_rate_ml_h, measured_rate_ml_h, flow_error_pct,
    occlusion_pressure_setting, occlusion_alarm_pressure_mmhg, occlusion_response_time_sec,
    bolus_volume_ml, bolus_accuracy_pct, air_in_line_alarm_result, flow_accuracy_verdict,
    test_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.model,
    q.tn::int, q.td::date, q.ts::timestamptz, q.te::timestamptz,
    q.pt, q.prof, q.sr, q.mr, q.fe,
    q.ops, q.oap, q.ort, q.bv, q.ba, q.ail, q.fav,
    q.tv, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-2','IP-APL-101','BBraun Infusomat Space','1','2026-07-01','2026-07-01 09:00:00+05:30','2026-07-01 09:20:00+05:30',
     'volumetric_pump','flow_accuracy_trumpet',25.00,25.15,0.60,null,null,null,null,null,'pass','within_spec','passed','2026-07-01 09:30:00+05:30','Trumpet-curve flow accuracy within +/-2% across all intervals'),
    ('Apollo Hyderabad Jubilee Hills','ICU-2','IP-APL-102','Fresenius Agilia VP','1','2026-07-01','2026-07-01 10:00:00+05:30','2026-07-01 10:35:00+05:30',
     'volumetric_pump','rate_accuracy_low_flow',1.00,1.08,8.00,null,null,null,null,null,'pass','out_of_spec','recalibration_required',null,'Low-flow 1 mL/h reads 1.08 — 8% over spec, calibration lapsed'),
    ('Fortis Bannerghatta Bengaluru','NICU-1','IP-FRT-210','Medtronic McKinley','5','2026-07-01','2026-07-01 06:30:00+05:30','2026-07-01 07:00:00+05:30',
     'syringe_pump','occlusion_alarm_test',2.00,null,null,'high',780.0,95,null,null,'pass','not_run','failed',null,'Occlusion alarm fired at 95s vs 60s target — response too slow'),
    ('Fortis Bannerghatta Bengaluru','NICU-1','IP-FRT-211','Terumo TE-SS830','2','2026-07-01','2026-07-01 07:20:00+05:30','2026-07-01 07:55:00+05:30',
     'syringe_pump','bolus_accuracy_test',5.00,5.10,2.00,'medium',525.0,18,1.00,12.00,'pass','marginal','failed',null,'PCA bolus delivered 12% over target volume'),
    ('Manipal Whitefield Bengaluru','ICU-3','IP-MNP-320','BBraun Perfusor Space','8','2026-06-30','2026-06-30 08:15:00+05:30','2026-06-30 08:40:00+05:30',
     'syringe_pump','flow_accuracy_trumpet',5.00,5.02,0.40,null,null,null,null,null,'pass','within_spec','passed','2026-06-30 08:50:00+05:30','Post-PM verification cycle passed'),
    ('Manipal Whitefield Bengaluru','Oncology','IP-MNP-321','Smiths CADD Solis','3','2026-06-30','2026-06-30 09:30:00+05:30','2026-06-30 10:05:00+05:30',
     'pca_pump','bolus_accuracy_test',4.00,4.05,1.25,'medium',500.0,20,0.50,3.00,'pass','within_spec','passed','2026-06-30 10:15:00+05:30','PCA lockout and bolus accuracy within spec'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','IP-AIM-430','Fresenius Agilia SP','12','2026-06-30','2026-06-30 06:00:00+05:30','2026-06-30 06:25:00+05:30',
     'syringe_pump','rate_accuracy_high_flow',200.00,199.50,0.25,null,null,null,null,null,'pass','within_spec','passed','2026-06-30 06:35:00+05:30','High-flow 200 mL/h accuracy within +/-0.5%'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','IP-AIM-431','BBraun Infusomat Space','3','2026-06-30','2026-06-30 07:00:00+05:30','2026-06-30 07:30:00+05:30',
     'volumetric_pump','air_in_line_alarm_test',100.00,100.10,0.10,null,null,null,null,null,'fail','within_spec','quarantined',null,'Air-in-line sensor failed to alarm on 0.5 mL bolus of air'),
    ('KIMS Secunderabad','ICU-1','IP-KIM-140','Mindray SK-500III','28','2026-06-29','2026-06-29 05:45:00+05:30','2026-06-29 06:10:00+05:30',
     'syringe_pump','occlusion_alarm_test',3.00,null,null,'low',310.0,45,null,null,'pass','not_run','conditional_pass','2026-06-29 06:20:00+05:30','Low-pressure occlusion 45s — within band, monitor next PM'),
    ('KIMS Secunderabad','ICU-1','IP-KIM-141','Fresenius Agilia VP','29','2026-06-29','2026-06-29 06:30:00+05:30','2026-06-29 07:05:00+05:30',
     'volumetric_pump','downstream_occlusion_test',10.00,10.20,2.00,'high',820.0,110,null,null,'pass','marginal','removed_from_service',null,'Downstream occlusion alarm 110s — pump withdrawn from service'),
    ('Care Hospitals Banjara Hills','ICU-2','IP-CAR-050','Terumo TE-LF610','11','2026-06-29','2026-06-29 09:00:00+05:30','2026-06-29 09:35:00+05:30',
     'volumetric_pump','backpressure_test',50.00,51.50,3.00,'medium',540.0,22,null,null,'pass','marginal','recalibration_required',null,'Backpressure 300 mmHg induced 3% flow error — recalibration due'),
    ('Yashoda Somajiguda Hyderabad','HDU-6','IP-YSH-180','BBraun Infusomat Space','67','2026-06-28','2026-06-28 06:30:00+05:30','2026-06-28 06:55:00+05:30',
     'volumetric_pump','flow_accuracy_trumpet',25.00,25.05,0.20,null,null,null,null,null,'pass','within_spec','passed','2026-06-28 07:05:00+05:30','Routine daily flow-accuracy check passed'),
    ('St John''s Bengaluru','Ward-1','IP-STJ-030','Fresenius Kabi Enteral','9','2026-06-28','2026-06-28 05:50:00+05:30','2026-06-28 06:15:00+05:30',
     'enteral_pump','rate_accuracy_low_flow',20.00,20.30,1.50,null,null,null,null,null,'not_applicable','within_spec','passed','2026-06-28 06:25:00+05:30','Enteral feed rate accuracy within spec'),
    ('Rainbow Children''s Hyderabad','NICU-3','IP-RBW-090','Medtronic McKinley','24','2026-06-27','2026-06-27 07:00:00+05:30','2026-06-27 07:40:00+05:30',
     'syringe_pump','rate_accuracy_low_flow',0.50,0.58,16.00,'low',300.0,30,null,null,'pass','out_of_spec','pending_review',null,'Neonatal 0.5 mL/h reads 0.58 — 16% error, under review')
  ) as q(hosp, ward, tag, model, tn, td, ts, te, pt, prof, sr, mr, fe, ops, oap, ort, bv, ba, ail, fav, tv, rel, nt);

  -- CAPA seed — attach to specific pump tests by asset tag
  insert into public.infusion_pump_capa_actions_r3143 (
    pump_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('IP-FRT-210','occlusion_response_slow','occlusion_sensor_fault','replace_occlusion_sensor','2026-07-22',null,'in_progress','patient_safety_alert',38000.00,'Occlusion alarm 95s vs 60s target — sensor replacement ordered'),
    ('IP-FRT-211','bolus_inaccuracy','motor_gear_wear','recalibrate_flow','2026-07-20',null,'open','iso_13485_deviation',9500.00,'Bolus 12% over — gear backlash suspected on syringe drive'),
    ('IP-AIM-431','air_in_line_failure','firmware_bug','firmware_upgrade','2026-07-19','2026-07-17','closed','cdsco_notifiable',0.00,'Air-in-line alarm silent — firmware v3.2 applied and verified'),
    ('IP-KIM-141','occlusion_response_slow','occlusion_sensor_fault','remove_from_service','2026-07-18',null,'escalated','patient_safety_alert',52000.00,'Downstream occlusion 110s — pump pulled, replacement AMC raised'),
    ('IP-APL-102','flow_rate_deviation','calibration_expired','recalibrate_flow','2026-07-25',null,'verification_pending','nabh_finding',6500.00,'Low-flow 8% error — annual calibration lapsed 40 days'),
    ('IP-RBW-090','flow_rate_deviation','motor_gear_wear','schedule_amc_visit','2026-07-15',null,'overdue','nabh_finding',15000.00,'Neonatal 0.5 mL/h 16% error — AMC visit overdue 3 days')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.infusion_pump_r3143 e
    on e.organization_id = v_org_id and e.pump_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Test verdict distribution
create or replace function public.founder_r3143_verdict_rollup()
returns table(test_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infusion_pump_r3143)
  select l.test_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.infusion_pump_r3143 l
  group by l.test_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3143_verdict_rollup() from public, anon;
grant execute on function public.founder_r3143_verdict_rollup() to authenticated;

-- 2) Hospital-level pump QA scorecard
create or replace function public.founder_r3143_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  passed bigint,
  failed bigint,
  quarantined bigint,
  out_of_spec bigint,
  occlusion_slow bigint,
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
    count(*) filter (where l.test_verdict in ('passed','conditional_pass'))::bigint,
    count(*) filter (where l.test_verdict in ('failed','removed_from_service'))::bigint,
    count(*) filter (where l.test_verdict = 'quarantined')::bigint,
    count(*) filter (where l.flow_accuracy_verdict = 'out_of_spec')::bigint,
    count(*) filter (where l.occlusion_response_time_sec > 60)::bigint,
    round(100.0 * count(*) filter (where l.test_verdict in ('passed','conditional_pass'))::numeric / nullif(count(*),0), 1)
  from public.infusion_pump_r3143 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3143_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3143_hospital_scorecard() to authenticated;

-- 3) Pump type × test profile matrix
create or replace function public.founder_r3143_pump_profile_matrix()
returns table(pump_type text, test_profile text, tests bigint, passed bigint, avg_flow_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pump_type, l.test_profile, count(*)::bigint,
    count(*) filter (where l.test_verdict in ('passed','conditional_pass'))::bigint,
    round(avg(l.flow_error_pct), 2)
  from public.infusion_pump_r3143 l
  group by l.pump_type, l.test_profile
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3143_pump_profile_matrix() from public, anon;
grant execute on function public.founder_r3143_pump_profile_matrix() to authenticated;

-- 4) Flow-accuracy & occlusion daily trend
create or replace function public.founder_r3143_flow_occlusion_daily_trend()
returns table(test_date date, tests bigint, within_spec bigint, marginal bigint, out_of_spec bigint, occlusion_slow bigint, avg_flow_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.flow_accuracy_verdict = 'within_spec')::bigint,
    count(*) filter (where l.flow_accuracy_verdict = 'marginal')::bigint,
    count(*) filter (where l.flow_accuracy_verdict = 'out_of_spec')::bigint,
    count(*) filter (where l.occlusion_response_time_sec > 60)::bigint,
    round(avg(l.flow_error_pct), 2)
  from public.infusion_pump_r3143 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3143_flow_occlusion_daily_trend() from public, anon;
grant execute on function public.founder_r3143_flow_occlusion_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3143_capa_status_board()
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
  from public.infusion_pump_capa_actions_r3143 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3143_capa_status_board() from public, anon;
grant execute on function public.founder_r3143_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3143_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infusion_pump_capa_actions_r3143)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.infusion_pump_capa_actions_r3143 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3143_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3143_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3143_regulatory_impact_digest()
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
  from public.infusion_pump_capa_actions_r3143 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3143_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3143_regulatory_impact_digest() to authenticated;

-- 8) High-risk pumps priority queue
create or replace function public.founder_r3143_high_risk_pumps()
returns table(
  hospital_name text,
  ward_code text,
  pump_asset_tag text,
  pump_model text,
  test_date date,
  pump_type text,
  test_verdict text,
  flow_error_pct numeric,
  occlusion_response_time_sec int,
  flow_accuracy_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_code, l.pump_asset_tag, l.pump_model, l.test_date,
    l.pump_type, l.test_verdict, l.flow_error_pct, l.occlusion_response_time_sec,
    l.flow_accuracy_verdict, l.notes
  from public.infusion_pump_r3143 l
  where l.test_verdict in ('failed','quarantined','removed_from_service','pending_review','recalibration_required')
     or l.flow_accuracy_verdict = 'out_of_spec'
     or l.air_in_line_alarm_result = 'fail'
     or l.occlusion_response_time_sec > 60
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3143_high_risk_pumps() from public, anon;
grant execute on function public.founder_r3143_high_risk_pumps() to authenticated;
