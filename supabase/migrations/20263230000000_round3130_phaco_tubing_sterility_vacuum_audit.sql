-- Round 3130 — Phaco tubing-set sterility & vacuum performance audit
-- Two round-suffixed tables, seven founder-gated SECURITY DEFINER RPCs returning rollups.

-- =========================================================
-- Table 1: phaco tubing-set sterility audit
-- =========================================================
create table if not exists public.phaco_tubing_sterility_audit_r3130 (
  id bigserial primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  audit_date date not null,
  surgeon_name text not null,
  case_count_in_session int not null check (case_count_in_session between 1 and 40),
  tubing_set_lot text not null,
  cassette_serial text not null,
  cassette_reuse_count int not null check (cassette_reuse_count between 0 and 20),
  sterility_method text not null check (sterility_method in (
    'ethylene_oxide','plasma_h2o2','steam_autoclave','single_use_pack','gamma_irradiated'
  )),
  bowie_dick_result text not null check (bowie_dick_result in ('pass','fail','not_applicable')),
  bioburden_cfu_per_ml numeric(8,2),
  endotoxin_eu_per_ml numeric(8,3),
  visible_residue_check text not null check (visible_residue_check in (
    'clean','viscoelastic_residue','blood_residue','cortical_matter','particulate_matter'
  )),
  integrity_pressure_test_mmhg int,
  leak_detected boolean not null default false,
  audit_verdict text not null check (audit_verdict in (
    'sterile_pass','marginal_release','quarantine','reject_discard','recall_lot'
  )),
  capa_action_required boolean not null default false,
  capa_owner_name text,
  capa_due_date date,
  created_at timestamptz not null default now()
);

create index if not exists idx_phaco_sterility_r3130_org on public.phaco_tubing_sterility_audit_r3130(organization_id);
create index if not exists idx_phaco_sterility_r3130_verdict on public.phaco_tubing_sterility_audit_r3130(audit_verdict);

-- =========================================================
-- Table 2: vacuum & aspiration performance log
-- =========================================================
create table if not exists public.phaco_vacuum_performance_log_r3130 (
  id bigserial primary key,
  audit_id bigint not null references public.phaco_tubing_sterility_audit_r3130(id) on delete cascade,
  measurement_phase text not null check (measurement_phase in (
    'pre_case_calibration','sculpt_phase','quadrant_removal','epinucleus_removal',
    'cortical_cleanup','viscoelastic_removal','post_case_check'
  )),
  target_vacuum_mmhg int not null check (target_vacuum_mmhg between 0 and 700),
  actual_vacuum_mmhg int not null check (actual_vacuum_mmhg between 0 and 700),
  vacuum_rise_time_ms int not null check (vacuum_rise_time_ms between 0 and 5000),
  aspiration_flow_cc_per_min numeric(5,2) not null check (aspiration_flow_cc_per_min between 0 and 60),
  bottle_height_cm int not null check (bottle_height_cm between 30 and 130),
  occlusion_break_surge_mmhg int,
  irrigation_pressure_drop_pct numeric(5,2),
  fluidics_alarm_triggered boolean not null default false,
  alarm_type text check (alarm_type in (
    'none','vacuum_loss','occlusion_persistent','cassette_full','tubing_kink','air_in_line'
  )),
  cross_contamination_risk_tier text not null check (cross_contamination_risk_tier in (
    'tier_0_negligible','tier_1_low','tier_2_moderate','tier_3_high','tier_4_critical'
  )),
  patient_age_band text not null check (patient_age_band in (
    'under_50','50_to_64','65_to_74','75_to_84','85_plus'
  )),
  intraop_complication text not null check (intraop_complication in (
    'none','posterior_capsule_rupture','iris_prolapse','wound_burn','dropped_nucleus','endothelial_damage'
  )),
  capa_recommendation text,
  measured_at timestamptz not null default now()
);

create index if not exists idx_phaco_vacuum_r3130_audit on public.phaco_vacuum_performance_log_r3130(audit_id);
create index if not exists idx_phaco_vacuum_r3130_risk on public.phaco_vacuum_performance_log_r3130(cross_contamination_risk_tier);

-- =========================================================
-- Seeds — 12+ rows split across both tables
-- =========================================================
with org as (
  select id from public.organizations order by created_at asc nulls last, id asc limit 1
), ins_audit as (
  insert into public.phaco_tubing_sterility_audit_r3130(
    organization_id, hospital_name, ot_room_code, audit_date, surgeon_name,
    case_count_in_session, tubing_set_lot, cassette_serial, cassette_reuse_count,
    sterility_method, bowie_dick_result, bioburden_cfu_per_ml, endotoxin_eu_per_ml,
    visible_residue_check, integrity_pressure_test_mmhg, leak_detected, audit_verdict,
    capa_action_required, capa_owner_name, capa_due_date
  )
  select org.id, q.hospital_name, q.ot_room_code, q.audit_date::date, q.surgeon_name,
         q.case_count_in_session, q.tubing_set_lot, q.cassette_serial, q.cassette_reuse_count,
         q.sterility_method, q.bowie_dick_result, q.bioburden_cfu_per_ml, q.endotoxin_eu_per_ml,
         q.visible_residue_check, q.integrity_pressure_test_mmhg, q.leak_detected, q.audit_verdict,
         q.capa_action_required, q.capa_owner_name, q.capa_due_date::date
  from org, (values
    ('LV Prasad Eye Institute Hyderabad','OT-CATA-01','2026-06-15','Dr Saumya Iyer',18,'LOT-ALCN-PH-77231','CAS-CEN-44210',0,'single_use_pack','not_applicable',0.10,0.012,'clean',520,false,'sterile_pass',false,null,null),
    ('Sankara Nethralaya Chennai','OT-PHACO-02','2026-06-15','Dr Ravindran Pillai',24,'LOT-BAUS-2611','CAS-BAUS-9911',3,'plasma_h2o2','pass',1.40,0.058,'viscoelastic_residue',505,false,'marginal_release',true,'CSSD Lead Geetha','2026-06-22'),
    ('Aravind Eye Hospital Madurai','OT-CATA-03','2026-06-16','Dr Manimegalai S',30,'LOT-AMOX-55109','CAS-AMO-77452',1,'ethylene_oxide','pass',0.30,0.020,'clean',515,false,'sterile_pass',false,null,null),
    ('Dr Agarwal Eye Hospital Bangalore','OT-FEMTO-01','2026-06-16','Dr Karthik Reddy',12,'LOT-ZEISS-88812','CAS-ZS-12044',6,'steam_autoclave','fail',8.20,0.180,'blood_residue',460,true,'quarantine',true,'OT Sr Nurse Lakshmi','2026-06-19'),
    ('Narayana Nethralaya Bangalore','OT-CATA-04','2026-06-17','Dr Aishwarya Nair',20,'LOT-ALCN-PH-77231','CAS-CEN-44210',0,'single_use_pack','not_applicable',0.05,0.008,'clean',525,false,'sterile_pass',false,null,null),
    ('Centre for Sight Delhi','OT-PHACO-05','2026-06-17','Dr Prabhjot Singh',16,'LOT-BAUS-2612','CAS-BAUS-9912',9,'plasma_h2o2','pass',3.10,0.110,'cortical_matter',498,false,'reject_discard',true,'Quality Mgr Anand','2026-06-21'),
    ('Disha Eye Hospital Kolkata','OT-CATA-02','2026-06-18','Dr Sumana Bhattacharya',22,'LOT-AMOX-55110','CAS-AMO-77452',2,'ethylene_oxide','pass',0.80,0.030,'clean',510,false,'sterile_pass',false,null,null),
    ('St John''s Medical College Bangalore','OT-EYE-01','2026-06-18','Dr Vivek Cherian',8,'LOT-RECALL-X3','CAS-X3-00781',12,'gamma_irradiated','not_applicable',12.40,0.420,'particulate_matter',430,true,'recall_lot',true,'Biomed Head Joseph','2026-06-20')
  ) as q(hospital_name, ot_room_code, audit_date, surgeon_name, case_count_in_session,
          tubing_set_lot, cassette_serial, cassette_reuse_count, sterility_method,
          bowie_dick_result, bioburden_cfu_per_ml, endotoxin_eu_per_ml, visible_residue_check,
          integrity_pressure_test_mmhg, leak_detected, audit_verdict,
          capa_action_required, capa_owner_name, capa_due_date)
  returning id, hospital_name
)
insert into public.phaco_vacuum_performance_log_r3130(
  audit_id, measurement_phase, target_vacuum_mmhg, actual_vacuum_mmhg, vacuum_rise_time_ms,
  aspiration_flow_cc_per_min, bottle_height_cm, occlusion_break_surge_mmhg,
  irrigation_pressure_drop_pct, fluidics_alarm_triggered, alarm_type,
  cross_contamination_risk_tier, patient_age_band, intraop_complication, capa_recommendation
)
select a.id, v.measurement_phase, v.target_vacuum_mmhg, v.actual_vacuum_mmhg, v.vacuum_rise_time_ms,
       v.aspiration_flow_cc_per_min, v.bottle_height_cm, v.occlusion_break_surge_mmhg,
       v.irrigation_pressure_drop_pct, v.fluidics_alarm_triggered, v.alarm_type,
       v.cross_contamination_risk_tier, v.patient_age_band, v.intraop_complication, v.capa_recommendation
from ins_audit a
join (values
  ('LV Prasad Eye Institute Hyderabad','sculpt_phase',300,298,140,28.00,95,42,3.20,false,'none','tier_0_negligible','65_to_74','none',null),
  ('LV Prasad Eye Institute Hyderabad','quadrant_removal',450,448,150,32.00,100,55,4.10,false,'none','tier_1_low','65_to_74','none',null),
  ('Sankara Nethralaya Chennai','sculpt_phase',300,265,210,24.50,90,80,9.40,true,'vacuum_loss','tier_2_moderate','75_to_84','none','Recalibrate vacuum sensor; replace cassette gasket'),
  ('Sankara Nethralaya Chennai','cortical_cleanup',500,470,260,30.00,95,95,11.20,true,'occlusion_persistent','tier_2_moderate','75_to_84','none','Reduce cassette reuse threshold to 2'),
  ('Aravind Eye Hospital Madurai','quadrant_removal',450,447,145,32.00,100,48,3.80,false,'none','tier_0_negligible','50_to_64','none',null),
  ('Aravind Eye Hospital Madurai','viscoelastic_removal',550,548,160,38.00,105,52,4.20,false,'none','tier_1_low','65_to_74','none',null),
  ('Dr Agarwal Eye Hospital Bangalore','quadrant_removal',400,310,420,22.00,85,180,18.40,true,'tubing_kink','tier_3_high','75_to_84','wound_burn','Discard tubing set; full fluidics service'),
  ('Dr Agarwal Eye Hospital Bangalore','post_case_check',0,0,0,0.00,80,null,null,true,'air_in_line','tier_3_high','75_to_84','wound_burn','Quarantine cassette serial CAS-ZS-12044'),
  ('Narayana Nethralaya Bangalore','pre_case_calibration',300,300,130,28.00,95,40,2.80,false,'none','tier_0_negligible','50_to_64','none',null),
  ('Narayana Nethralaya Bangalore','sculpt_phase',350,349,135,30.00,98,42,3.10,false,'none','tier_0_negligible','65_to_74','none',null),
  ('Centre for Sight Delhi','cortical_cleanup',500,420,310,26.00,90,140,14.80,true,'cassette_full','tier_3_high','85_plus','iris_prolapse','Replace cassette mid-case; revise reuse SOP'),
  ('Centre for Sight Delhi','viscoelastic_removal',550,440,360,24.00,88,160,16.20,true,'occlusion_persistent','tier_3_high','85_plus','iris_prolapse','Block reuse beyond 5 cycles on cassette family'),
  ('Disha Eye Hospital Kolkata','quadrant_removal',450,446,150,32.00,100,50,4.00,false,'none','tier_1_low','65_to_74','none',null),
  ('Disha Eye Hospital Kolkata','epinucleus_removal',480,476,155,34.00,102,55,4.40,false,'none','tier_1_low','65_to_74','none',null),
  ('St John''s Medical College Bangalore','sculpt_phase',300,180,520,18.00,80,220,24.60,true,'vacuum_loss','tier_4_critical','85_plus','posterior_capsule_rupture','Lot recall LOT-RECALL-X3; notify CDSCO'),
  ('St John''s Medical College Bangalore','quadrant_removal',450,210,610,16.00,80,260,28.80,true,'air_in_line','tier_4_critical','85_plus','dropped_nucleus','Halt OT use; full equipment quarantine')
) as v(hospital_name, measurement_phase, target_vacuum_mmhg, actual_vacuum_mmhg, vacuum_rise_time_ms,
       aspiration_flow_cc_per_min, bottle_height_cm, occlusion_break_surge_mmhg,
       irrigation_pressure_drop_pct, fluidics_alarm_triggered, alarm_type,
       cross_contamination_risk_tier, patient_age_band, intraop_complication, capa_recommendation)
  on a.hospital_name = v.hospital_name;

-- Fix: the 'occlusion_break_surge' phase literal above was wrong — patch it to a valid phase.
update public.phaco_vacuum_performance_log_r3130
set measurement_phase = 'quadrant_removal'
where measurement_phase = 'occlusion_break_surge';

-- =========================================================
-- RPCs (7) — founder-gated SECURITY DEFINER plpgsql, rollups
-- =========================================================

-- 1. Verdict mix per hospital
create or replace function public.founder_phaco_r3130_verdict_mix()
returns table(hospital_name text, total_audits bigint, sterile_pass bigint,
              marginal_release bigint, quarantine_cnt bigint, reject_discard bigint, recall_lot bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name,
         count(*)::bigint,
         count(*) filter (where a.audit_verdict='sterile_pass')::bigint,
         count(*) filter (where a.audit_verdict='marginal_release')::bigint,
         count(*) filter (where a.audit_verdict='quarantine')::bigint,
         count(*) filter (where a.audit_verdict='reject_discard')::bigint,
         count(*) filter (where a.audit_verdict='recall_lot')::bigint
  from public.phaco_tubing_sterility_audit_r3130 a
  group by a.hospital_name
  order by count(*) filter (where a.audit_verdict in ('quarantine','reject_discard','recall_lot')) desc;
end; $$;
revoke execute on function public.founder_phaco_r3130_verdict_mix() from public, anon;
grant execute on function public.founder_phaco_r3130_verdict_mix() to authenticated;

-- 2. Sterility-method bioburden rollup
create or replace function public.founder_phaco_r3130_sterility_method_rollup()
returns table(sterility_method text, audits bigint, avg_bioburden numeric, max_endotoxin numeric, leak_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.sterility_method,
         count(*)::bigint,
         round(avg(coalesce(a.bioburden_cfu_per_ml,0))::numeric, 2),
         max(a.endotoxin_eu_per_ml)::numeric,
         round((100.0 * count(*) filter (where a.leak_detected)) / nullif(count(*),0), 1)
  from public.phaco_tubing_sterility_audit_r3130 a
  group by a.sterility_method
  order by max(coalesce(a.bioburden_cfu_per_ml,0)) desc;
end; $$;
revoke execute on function public.founder_phaco_r3130_sterility_method_rollup() from public, anon;
grant execute on function public.founder_phaco_r3130_sterility_method_rollup() to authenticated;

-- 3. Cassette-reuse vs verdict correlation
create or replace function public.founder_phaco_r3130_cassette_reuse_risk()
returns table(reuse_band text, audits bigint, problem_verdicts bigint, problem_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with b as (
    select case
             when cassette_reuse_count = 0 then '0_single_use'
             when cassette_reuse_count between 1 and 3 then '1_to_3'
             when cassette_reuse_count between 4 and 7 then '4_to_7'
             else '8_plus'
           end as reuse_band,
           audit_verdict
    from public.phaco_tubing_sterility_audit_r3130
  )
  select b.reuse_band,
         count(*)::bigint,
         count(*) filter (where b.audit_verdict in ('quarantine','reject_discard','recall_lot'))::bigint,
         round((100.0 * count(*) filter (where b.audit_verdict in ('quarantine','reject_discard','recall_lot'))) / nullif(count(*),0), 1)
  from b
  group by b.reuse_band
  order by b.reuse_band;
end; $$;
revoke execute on function public.founder_phaco_r3130_cassette_reuse_risk() from public, anon;
grant execute on function public.founder_phaco_r3130_cassette_reuse_risk() to authenticated;

-- 4. Vacuum deviation by phase
create or replace function public.founder_phaco_r3130_vacuum_deviation_by_phase()
returns table(measurement_phase text, samples bigint, avg_target int, avg_actual int,
              avg_deviation numeric, alarm_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.measurement_phase,
         count(*)::bigint,
         avg(v.target_vacuum_mmhg)::int,
         avg(v.actual_vacuum_mmhg)::int,
         round(avg(v.target_vacuum_mmhg - v.actual_vacuum_mmhg)::numeric, 1),
         round((100.0 * count(*) filter (where v.fluidics_alarm_triggered)) / nullif(count(*),0), 1)
  from public.phaco_vacuum_performance_log_r3130 v
  group by v.measurement_phase
  order by avg(v.target_vacuum_mmhg - v.actual_vacuum_mmhg) desc;
end; $$;
revoke execute on function public.founder_phaco_r3130_vacuum_deviation_by_phase() from public, anon;
grant execute on function public.founder_phaco_r3130_vacuum_deviation_by_phase() to authenticated;

-- 5. Cross-contamination risk × age band
create or replace function public.founder_phaco_r3130_risk_by_age()
returns table(cross_contamination_risk_tier text, patient_age_band text, samples bigint,
              complication_cnt bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select v.cross_contamination_risk_tier, v.patient_age_band,
         count(*)::bigint,
         count(*) filter (where v.intraop_complication <> 'none')::bigint
  from public.phaco_vacuum_performance_log_r3130 v
  group by v.cross_contamination_risk_tier, v.patient_age_band
  order by v.cross_contamination_risk_tier, v.patient_age_band;
end; $$;
revoke execute on function public.founder_phaco_r3130_risk_by_age() from public, anon;
grant execute on function public.founder_phaco_r3130_risk_by_age() to authenticated;

-- 6. CAPA queue (open actions)
create or replace function public.founder_phaco_r3130_capa_queue()
returns table(hospital_name text, audit_date date, audit_verdict text,
              capa_owner_name text, capa_due_date date, days_to_due int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.hospital_name, a.audit_date, a.audit_verdict,
         a.capa_owner_name, a.capa_due_date,
         (a.capa_due_date - current_date)::int
  from public.phaco_tubing_sterility_audit_r3130 a
  where a.capa_action_required
  order by a.capa_due_date asc nulls last;
end; $$;
revoke execute on function public.founder_phaco_r3130_capa_queue() from public, anon;
grant execute on function public.founder_phaco_r3130_capa_queue() to authenticated;

-- 7. Lot-level recall signal
create or replace function public.founder_phaco_r3130_lot_recall_signal()
returns table(tubing_set_lot text, audits bigint, max_bioburden numeric,
              quarantine_or_recall bigint, recommend_recall boolean)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.tubing_set_lot,
         count(*)::bigint,
         max(coalesce(a.bioburden_cfu_per_ml,0))::numeric,
         count(*) filter (where a.audit_verdict in ('quarantine','reject_discard','recall_lot'))::bigint,
         (max(coalesce(a.bioburden_cfu_per_ml,0)) > 5.0
          or count(*) filter (where a.audit_verdict in ('reject_discard','recall_lot')) > 0)
  from public.phaco_tubing_sterility_audit_r3130 a
  group by a.tubing_set_lot
  order by max(coalesce(a.bioburden_cfu_per_ml,0)) desc;
end; $$;
revoke execute on function public.founder_phaco_r3130_lot_recall_signal() from public, anon;
grant execute on function public.founder_phaco_r3130_lot_recall_signal() to authenticated;

-- 8. Surgeon complication scoreboard
create or replace function public.founder_phaco_r3130_surgeon_scoreboard()
returns table(surgeon_name text, hospital_name text, sessions bigint, cases bigint,
              complications bigint, complication_rate_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select a.surgeon_name, a.hospital_name,
         count(distinct a.id)::bigint,
         sum(a.case_count_in_session)::bigint,
         count(*) filter (where v.intraop_complication <> 'none')::bigint,
         round((100.0 * count(*) filter (where v.intraop_complication <> 'none'))
               / nullif(count(v.id),0), 1)
  from public.phaco_tubing_sterility_audit_r3130 a
  left join public.phaco_vacuum_performance_log_r3130 v on v.audit_id = a.id
  group by a.surgeon_name, a.hospital_name
  order by count(*) filter (where v.intraop_complication <> 'none') desc, a.surgeon_name asc;
end; $$;
revoke execute on function public.founder_phaco_r3130_surgeon_scoreboard() from public, anon;
grant execute on function public.founder_phaco_r3130_surgeon_scoreboard() to authenticated;
