-- Round 3138: Customer Hospital Dialysis Machine Water-Treatment & Endotoxin Compliance Audit
-- RO water loop test log — sample point × endotoxin EU/mL × TVC CFU × chlorine/chloramine × hardness × conductivity × verdict + CAPA

-- =============================================================================
-- TABLE 1: dialysis_water_r3138 — individual RO water loop sample tests
-- =============================================================================
create table if not exists public.dialysis_water_r3138 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  dialysis_unit_code text not null,
  sample_ref text not null,
  water_system_model text not null,
  test_standard text not null check (test_standard in (
    'aami_rd52','iso_23500','iso_13959','european_pharmacopoeia','aami_ultrapure','ispd_guideline'
  )),
  sample_point text not null check (sample_point in (
    'post_ro_membrane','pre_ultrafilter','post_ultrafilter','distribution_loop_start',
    'distribution_loop_return','dialysis_machine_inlet','mixing_tank','storage_tank',
    'softener_outlet','carbon_filter_outlet'
  )),
  test_date date not null,
  sampled_at timestamptz not null,
  endotoxin_eu_per_ml numeric(6,3),
  endotoxin_verdict text check (endotoxin_verdict in (
    'within_limit','action_level','max_allowable_exceeded','not_tested'
  )),
  tvc_cfu_per_ml numeric(8,1),
  tvc_verdict text check (tvc_verdict in (
    'within_limit','action_level','max_allowable_exceeded','not_tested'
  )),
  chlorine_mg_per_l numeric(5,3),
  chloramine_mg_per_l numeric(5,3),
  chlorine_verdict text check (chlorine_verdict in (
    'within_limit','exceeds_limit','not_tested'
  )),
  hardness_mg_per_l numeric(6,2),
  hardness_verdict text check (hardness_verdict in (
    'within_limit','exceeds_limit','not_tested'
  )),
  conductivity_us_per_cm numeric(6,2),
  water_quality_grade text not null check (water_quality_grade in (
    'ultrapure_dialysis_water','standard_dialysis_water','substandard_water','fails_standard'
  )),
  overall_verdict text not null check (overall_verdict in (
    'compliant','conditional_pass','action_required','non_compliant','loop_quarantine','recall_treatment'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dialysis_water_r3138 enable row level security;

create index if not exists idx_dialysis_water_r3138_org on public.dialysis_water_r3138(organization_id);
create index if not exists idx_dialysis_water_r3138_date on public.dialysis_water_r3138(test_date);
create index if not exists idx_dialysis_water_r3138_verdict on public.dialysis_water_r3138(overall_verdict);

-- =============================================================================
-- TABLE 2: dialysis_water_capa_actions_r3138 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.dialysis_water_capa_actions_r3138 (
  id uuid primary key default gen_random_uuid(),
  water_test_id uuid not null references public.dialysis_water_r3138(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'endotoxin_exceedance','tvc_exceedance','chlorine_breakthrough','chloramine_breakthrough',
    'hardness_high','conductivity_drift','ro_membrane_fouling','biofilm_contamination',
    'disinfection_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'ro_membrane_degraded','carbon_filter_exhausted','softener_resin_exhausted',
    'uv_lamp_failure','ultrafilter_breach','biofilm_in_loop','inadequate_disinfection',
    'feed_water_quality_poor','sensor_drift','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_ro_membrane','replace_carbon_filter','regenerate_softener_resin',
    'replace_uv_lamp','replace_ultrafilter','heat_disinfect_loop','chemical_disinfect_loop',
    'recalibrate_sensor','schedule_amc_visit','none_required','flush_and_resample'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','aami_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dialysis_water_capa_actions_r3138 enable row level security;

create index if not exists idx_dialysis_water_capa_r3138_test on public.dialysis_water_capa_actions_r3138(water_test_id);
create index if not exists idx_dialysis_water_capa_r3138_status on public.dialysis_water_capa_actions_r3138(capa_status);

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

  -- 14 water-loop sample test rows
  insert into public.dialysis_water_r3138 (
    organization_id, hospital_name, dialysis_unit_code, sample_ref, water_system_model,
    test_standard, sample_point, test_date, sampled_at,
    endotoxin_eu_per_ml, endotoxin_verdict, tvc_cfu_per_ml, tvc_verdict,
    chlorine_mg_per_l, chloramine_mg_per_l, chlorine_verdict,
    hardness_mg_per_l, hardness_verdict, conductivity_us_per_cm,
    water_quality_grade, overall_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.unit, q.sref, q.model,
    q.std, q.spoint, q.tdate::date, q.sampled::timestamptz,
    q.endo, q.endo_v, q.tvc, q.tvc_v,
    q.cl, q.chlm, q.cl_v,
    q.hard, q.hard_v, q.cond,
    q.grade, q.overall, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','DU-A','DW-APL-01','Fresenius AquaUNO RO',
     'aami_ultrapure','dialysis_machine_inlet','2026-07-15','2026-07-15 06:20:00+05:30',
     0.012,'within_limit',0.05,'within_limit',0.010,0.020,'within_limit',0.50,'within_limit',4.20,
     'ultrapure_dialysis_water','compliant','2026-07-15 12:00:00+05:30','Monthly ultrapure surveillance — machine inlet clean'),
    ('Apollo Hyderabad Jubilee Hills','DU-A','DW-APL-02','Fresenius AquaUNO RO',
     'aami_ultrapure','distribution_loop_return','2026-07-15','2026-07-15 06:35:00+05:30',
     0.028,'action_level',0.09,'within_limit',0.008,0.018,'within_limit',0.60,'within_limit',4.80,
     'standard_dialysis_water','conditional_pass',null,'Loop return endotoxin at action level — schedule disinfection'),
    ('Fortis Bannerghatta Bengaluru','DU-1','DW-FRT-01','B.Braun Aquaboss RO',
     'aami_rd52','distribution_loop_return','2026-07-14','2026-07-14 05:40:00+05:30',
     2.400,'max_allowable_exceeded',180.0,'max_allowable_exceeded',0.020,0.030,'within_limit',1.20,'within_limit',6.10,
     'fails_standard','loop_quarantine',null,'Endotoxin 2.4 EU/mL & TVC 180 CFU/mL — biofilm suspected, loop quarantined'),
    ('Fortis Bannerghatta Bengaluru','DU-1','DW-FRT-02','B.Braun Aquaboss RO',
     'aami_rd52','post_ro_membrane','2026-07-14','2026-07-14 06:05:00+05:30',
     0.040,'action_level',12.0,'within_limit',0.600,0.120,'exceeds_limit',1.10,'within_limit',9.50,
     'substandard_water','action_required',null,'Chlorine 0.6 mg/L breakthrough post-RO — carbon filter exhausted'),
    ('Manipal Whitefield Bengaluru','DU-2','DW-MNP-01','Fresenius AquaC RO',
     'iso_23500','dialysis_machine_inlet','2026-07-14','2026-07-14 07:10:00+05:30',
     0.030,'action_level',55.0,'action_level',0.012,0.022,'within_limit',0.90,'within_limit',5.40,
     'standard_dialysis_water','action_required',null,'Both endotoxin & TVC at action level — resample after disinfect'),
    ('Manipal Whitefield Bengaluru','DU-2','DW-MNP-02','Fresenius AquaC RO',
     'iso_23500','dialysis_machine_inlet','2026-07-16','2026-07-16 06:50:00+05:30',
     0.015,'within_limit',8.0,'within_limit',0.010,0.020,'within_limit',0.85,'within_limit',5.10,
     'standard_dialysis_water','compliant','2026-07-16 11:30:00+05:30','Post heat-disinfection resample — back within limit'),
    ('AIIMS New Delhi Ansari Nagar','DU-5','DW-AIM-01','Fresenius AquaUNO RO',
     'aami_ultrapure','post_ultrafilter','2026-07-13','2026-07-13 06:00:00+05:30',
     0.010,'within_limit',0.02,'within_limit',0.006,0.014,'within_limit',0.40,'within_limit',3.90,
     'ultrapure_dialysis_water','compliant','2026-07-13 10:00:00+05:30','Post-ultrafilter ultrapure — excellent'),
    ('AIIMS New Delhi Ansari Nagar','DU-5','DW-AIM-02','Fresenius AquaUNO RO',
     'aami_ultrapure','distribution_loop_start','2026-07-13','2026-07-13 06:20:00+05:30',
     0.018,'within_limit',0.08,'within_limit',0.009,0.016,'within_limit',0.70,'within_limit',18.50,
     'standard_dialysis_water','action_required',null,'Conductivity drift 18.5 uS/cm — RO membrane rejection dropping'),
    ('KIMS Secunderabad','DU-4','DW-KIM-01','B.Braun Aquaboss RO',
     'aami_rd52','softener_outlet','2026-07-12','2026-07-12 05:50:00+05:30',
     0.022,'action_level',10.0,'within_limit',0.014,0.024,'within_limit',8.50,'exceeds_limit',7.20,
     'substandard_water','action_required',null,'Feed hardness 8.5 mg/L past softener — resin exhausted'),
    ('KIMS Secunderabad','DU-4','DW-KIM-02','B.Braun Aquaboss RO',
     'aami_rd52','softener_outlet','2026-07-16','2026-07-16 05:55:00+05:30',
     0.016,'within_limit',6.0,'within_limit',0.012,0.020,'within_limit',0.60,'within_limit',6.80,
     'standard_dialysis_water','compliant','2026-07-16 10:15:00+05:30','Post resin-regeneration — hardness restored'),
    ('Care Hospitals Banjara Hills','DU-2','DW-CAR-01','Fresenius AquaC RO',
     'iso_23500','dialysis_machine_inlet','2026-07-12','2026-07-12 06:30:00+05:30',
     0.020,'within_limit',15.0,'within_limit',0.011,0.019,'within_limit',0.75,'within_limit',5.60,
     'standard_dialysis_water','compliant','2026-07-12 11:00:00+05:30','Routine standard water — compliant'),
    ('Yashoda Somajiguda Hyderabad','DU-6','DW-YSH-01','B.Braun Aquaboss RO',
     'aami_rd52','distribution_loop_return','2026-07-11','2026-07-11 05:45:00+05:30',
     1.200,'action_level',120.0,'max_allowable_exceeded',0.018,0.028,'within_limit',1.30,'within_limit',7.90,
     'fails_standard','non_compliant',null,'TVC 120 CFU/mL exceeds max — RO membrane fouling suspected'),
    ('St John''s Bengaluru','DU-1','DW-STJ-01','Fresenius AquaC RO',
     'iso_23500','post_ultrafilter','2026-07-11','2026-07-11 06:15:00+05:30',
     0.013,'within_limit',3.0,'within_limit',0.008,0.015,'within_limit',0.55,'within_limit',4.60,
     'ultrapure_dialysis_water','compliant','2026-07-11 10:30:00+05:30','Weekly post-UF check — ultrapure'),
    ('Rainbow Children''s Hyderabad','DU-3','DW-RBW-01','Fresenius AquaUNO RO',
     'aami_ultrapure','carbon_filter_outlet','2026-07-10','2026-07-10 06:40:00+05:30',
     0.035,'action_level',9.0,'within_limit',0.080,0.150,'exceeds_limit',0.65,'within_limit',5.00,
     'substandard_water','recall_treatment',null,'Chloramine 0.15 mg/L breakthrough — pediatric unit, treatment recalled')
  ) as q(hosp, unit, sref, model, std, spoint, tdate, sampled,
         endo, endo_v, tvc, tvc_v, cl, chlm, cl_v, hard, hard_v, cond, grade, overall, rel, nt);

  -- CAPA seed — attach to specific samples via sample_ref
  insert into public.dialysis_water_capa_actions_r3138 (
    water_test_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('DW-FRT-01','endotoxin_exceedance','biofilm_in_loop','heat_disinfect_loop',
     '2026-07-18',null,'escalated','patient_safety_alert',85000.00,'Loop quarantined — hot-water disinfect 85C plus resample before release'),
    ('DW-FRT-02','chlorine_breakthrough','carbon_filter_exhausted','replace_carbon_filter',
     '2026-07-17',null,'in_progress','aami_deviation',22000.00,'Activated carbon bed exhausted — replacement carbon ordered'),
    ('DW-KIM-01','hardness_high','softener_resin_exhausted','regenerate_softener_resin',
     '2026-07-15','2026-07-16','closed','internal_only',8000.00,'Softener resin regenerated & brine tank refilled — hardness restored'),
    ('DW-YSH-01','tvc_exceedance','ro_membrane_degraded','replace_ro_membrane',
     '2026-07-20',null,'open','cdsco_notifiable',145000.00,'RO membrane rejection dropped — full membrane bank replacement quoted'),
    ('DW-RBW-01','chloramine_breakthrough','carbon_filter_exhausted','replace_carbon_filter',
     '2026-07-14',null,'escalated','patient_safety_alert',30000.00,'Pediatric unit — chloramine breakthrough, dual carbon beds to be replaced'),
    ('DW-AIM-02','conductivity_drift','sensor_drift','recalibrate_sensor',
     '2026-07-19',null,'verification_pending','aami_deviation',5500.00,'Conductivity meter recalibrated — verify RO rejection trend over 3 days')
  ) as q(sref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.dialysis_water_r3138 e
    on e.organization_id = v_org_id and e.sample_ref = q.sref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Overall verdict distribution
create or replace function public.founder_r3138_verdict_rollup()
returns table(overall_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dialysis_water_r3138)
  select l.overall_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dialysis_water_r3138 l
  group by l.overall_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3138_verdict_rollup() from public, anon;
grant execute on function public.founder_r3138_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3138_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  compliant bigint,
  action_required bigint,
  non_compliant bigint,
  endotoxin_exceed bigint,
  tvc_exceed bigint,
  chlorine_exceed bigint,
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
    count(*) filter (where l.overall_verdict = 'compliant')::bigint,
    count(*) filter (where l.overall_verdict = 'action_required')::bigint,
    count(*) filter (where l.overall_verdict in ('non_compliant','loop_quarantine','recall_treatment'))::bigint,
    count(*) filter (where l.endotoxin_verdict = 'max_allowable_exceeded')::bigint,
    count(*) filter (where l.tvc_verdict = 'max_allowable_exceeded')::bigint,
    count(*) filter (where l.chlorine_verdict = 'exceeds_limit')::bigint,
    round(100.0 * count(*) filter (where l.overall_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.dialysis_water_r3138 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3138_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3138_hospital_scorecard() to authenticated;

-- 3) Sample-point × standard breakdown matrix
create or replace function public.founder_r3138_sample_point_matrix()
returns table(sample_point text, test_standard text, tests bigint, compliant bigint, avg_endotoxin numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.sample_point, l.test_standard, count(*)::bigint,
    count(*) filter (where l.overall_verdict = 'compliant')::bigint,
    round(avg(l.endotoxin_eu_per_ml), 3)
  from public.dialysis_water_r3138 l
  group by l.sample_point, l.test_standard
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3138_sample_point_matrix() from public, anon;
grant execute on function public.founder_r3138_sample_point_matrix() to authenticated;

-- 4) Daily compliance trend
create or replace function public.founder_r3138_water_daily_trend()
returns table(test_date date, compliant bigint, action_required bigint, non_compliant bigint, endotoxin_exceed bigint, tvc_exceed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*) filter (where l.overall_verdict = 'compliant')::bigint,
    count(*) filter (where l.overall_verdict = 'action_required')::bigint,
    count(*) filter (where l.overall_verdict in ('non_compliant','loop_quarantine','recall_treatment'))::bigint,
    count(*) filter (where l.endotoxin_verdict = 'max_allowable_exceeded')::bigint,
    count(*) filter (where l.tvc_verdict = 'max_allowable_exceeded')::bigint
  from public.dialysis_water_r3138 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3138_water_daily_trend() from public, anon;
grant execute on function public.founder_r3138_water_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3138_capa_status_board()
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
  from public.dialysis_water_capa_actions_r3138 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3138_capa_status_board() from public, anon;
grant execute on function public.founder_r3138_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3138_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dialysis_water_capa_actions_r3138)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dialysis_water_capa_actions_r3138 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3138_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3138_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3138_regulatory_impact_digest()
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
  from public.dialysis_water_capa_actions_r3138 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3138_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3138_regulatory_impact_digest() to authenticated;

-- 8) High-risk samples priority queue
create or replace function public.founder_r3138_high_risk_samples()
returns table(
  hospital_name text,
  dialysis_unit_code text,
  sample_ref text,
  sample_point text,
  test_date date,
  overall_verdict text,
  endotoxin_verdict text,
  tvc_verdict text,
  chlorine_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.dialysis_unit_code, l.sample_ref, l.sample_point, l.test_date,
    l.overall_verdict, l.endotoxin_verdict, l.tvc_verdict, l.chlorine_verdict, l.notes
  from public.dialysis_water_r3138 l
  where l.overall_verdict in ('action_required','non_compliant','loop_quarantine','recall_treatment','conditional_pass')
     or l.endotoxin_verdict = 'max_allowable_exceeded'
     or l.tvc_verdict = 'max_allowable_exceeded'
     or l.chlorine_verdict = 'exceeds_limit'
     or l.hardness_verdict = 'exceeds_limit'
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3138_high_risk_samples() from public, anon;
grant execute on function public.founder_r3138_high_risk_samples() to authenticated;
