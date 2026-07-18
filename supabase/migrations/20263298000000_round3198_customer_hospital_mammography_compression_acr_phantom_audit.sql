-- Round 3198: Customer Hospital Mammography Compression-Force & Image-Quality (ACR Phantom) Audit
-- Mammo QA log — unit model × compression force N × kVp accuracy × AEC × ACR phantom score (fibers/specks/masses) × mean glandular dose × artifact check × CAPA

-- =============================================================================
-- TABLE 1: mammography_qa_r3198 — individual mammography QA test runs
-- =============================================================================
create table if not exists public.mammography_qa_r3198 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  qa_ref_code text not null,
  mammo_unit_tag text not null,
  unit_model text not null,
  unit_type text not null check (unit_type in (
    'ffdm_2d','dbt_tomosynthesis','cr_mammography','screen_film','contrast_enhanced'
  )),
  test_type text not null check (test_type in (
    'annual_full','semiannual','routine_weekly','post_repair','acceptance','physicist_survey'
  )),
  test_date date not null,
  compression_force_n numeric(6,2) not null,
  force_accuracy_verdict text not null check (force_accuracy_verdict in (
    'pass','fail','borderline','not_tested'
  )),
  kvp_set numeric(4,1),
  kvp_measured numeric(4,1),
  kvp_accuracy_verdict text check (kvp_accuracy_verdict in ('pass','fail','borderline','not_tested')),
  aec_test_result text check (aec_test_result in ('pass','fail','drift_within_limits','not_run')),
  acr_fibers_seen numeric(3,1),
  acr_speck_groups_seen numeric(3,1),
  acr_masses_seen numeric(3,1),
  mean_glandular_dose_mgy numeric(4,2),
  artifact_check text check (artifact_check in (
    'clean','minor_artifacts','grid_lines','detector_defect','processing_artifact','not_run'
  )),
  physicist_profile_id uuid references public.profiles(id) on delete set null,
  qa_verdict text not null check (qa_verdict in (
    'pass','conditional_pass','fail_minor','fail_major','unit_suspended','pending_physicist_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mammography_qa_r3198 enable row level security;

create index if not exists idx_mammo_qa_r3198_org on public.mammography_qa_r3198(organization_id);
create index if not exists idx_mammo_qa_r3198_date on public.mammography_qa_r3198(test_date);
create index if not exists idx_mammo_qa_r3198_verdict on public.mammography_qa_r3198(qa_verdict);

-- =============================================================================
-- TABLE 2: mammography_qa_capa_actions_r3198 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.mammography_qa_capa_actions_r3198 (
  id uuid primary key default gen_random_uuid(),
  qa_log_id uuid not null references public.mammography_qa_r3198(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'compression_force_fail','kvp_drift','aec_fail','phantom_score_fail',
    'dose_exceeds_limit','artifact_detected','paddle_damage','detector_calibration_due',
    'operator_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compression_paddle_worn','force_sensor_drift','generator_calibration_drift',
    'aec_detector_aging','detector_ghosting','phantom_positioning_error',
    'processing_algorithm_update','grid_misalignment','tube_aging',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_compression_paddle','recalibrate_force_sensor','recalibrate_generator',
    'recalibrate_aec','detector_flat_field_recalibration','realign_grid',
    'replace_xray_tube','retrain_technologist','suspend_unit_pending_service',
    'schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','nabh_finding','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.mammography_qa_capa_actions_r3198 enable row level security;

create index if not exists idx_mammo_capa_r3198_qa on public.mammography_qa_capa_actions_r3198(qa_log_id);
create index if not exists idx_mammo_capa_r3198_status on public.mammography_qa_capa_actions_r3198(capa_status);

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

  -- 13 QA test rows
  insert into public.mammography_qa_r3198 (
    organization_id, hospital_name, qa_ref_code, mammo_unit_tag, unit_model, unit_type, test_type, test_date,
    compression_force_n, force_accuracy_verdict, kvp_set, kvp_measured, kvp_accuracy_verdict, aec_test_result,
    acr_fibers_seen, acr_speck_groups_seen, acr_masses_seen, mean_glandular_dose_mgy,
    artifact_check, qa_verdict, notes
  )
  select v_org_id, q.hosp, q.ref, q.tag, q.model, q.utype, q.ttype, q.td::date,
    q.cf, q.fav, q.kset, q.kmeas, q.kav, q.aec,
    q.fib, q.spk, q.mas, q.mgd,
    q.art, q.qv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','MQA-2026-001','MG-APL-101','Hologic Selenia Dimensions','dbt_tomosynthesis','annual_full','2026-07-02',
     118.00,'pass',28.0,28.1,'pass','pass',5.0,4.0,4.0,1.42,'clean','pass','Annual physicist survey — all parameters within AERB limits'),
    ('Apollo Hyderabad Jubilee Hills','MQA-2026-002','MG-APL-101','Hologic Selenia Dimensions','dbt_tomosynthesis','routine_weekly','2026-07-09',
     116.50,'pass',28.0,28.1,'pass','pass',4.5,4.0,3.5,1.44,'clean','pass','Weekly phantom — stable versus annual baseline'),
    ('Fortis Bannerghatta Bengaluru','MQA-2026-003','MG-FRT-055','GE Senographe Pristina','ffdm_2d','annual_full','2026-07-03',
     96.00,'fail',28.0,29.6,'fail','drift_within_limits',3.5,3.0,3.0,1.88,'minor_artifacts','fail_major','Compression 96 N below 111 N minimum; kVp off by 1.6'),
    ('Fortis Bannerghatta Bengaluru','MQA-2026-004','MG-FRT-055','GE Senographe Pristina','ffdm_2d','post_repair','2026-07-11',
     121.00,'pass',28.0,28.2,'pass','pass',5.0,4.0,4.0,1.52,'clean','pass','Post-repair re-test after force sensor and generator recalibration'),
    ('Manipal Whitefield Bengaluru','MQA-2026-005','MG-MNP-032','Siemens Mammomat Revelation','dbt_tomosynthesis','semiannual','2026-07-04',
     124.00,'pass',29.0,29.1,'pass','pass',5.5,4.0,4.0,1.38,'grid_lines','conditional_pass','Faint grid lines on phantom image — monitor at next survey'),
    ('AIIMS New Delhi Ansari Nagar','MQA-2026-006','MG-AIM-077','Fujifilm Amulet Innovality','dbt_tomosynthesis','annual_full','2026-07-05',
     119.50,'pass',30.0,30.1,'pass','pass',6.0,5.0,4.5,1.35,'clean','pass','Reference unit — best phantom score in fleet'),
    ('AIIMS New Delhi Ansari Nagar','MQA-2026-007','MG-AIM-078','Fujifilm Amulet Innovality','dbt_tomosynthesis','routine_weekly','2026-07-12',
     112.00,'borderline',30.0,30.0,'pass','pass',4.0,3.0,3.0,1.60,'clean','conditional_pass','Force at lower tolerance edge — recheck in 2 weeks'),
    ('KIMS Secunderabad','MQA-2026-008','MG-KIM-019','Hologic Selenia Dimensions','ffdm_2d','annual_full','2026-07-06',
     130.00,'pass',28.0,28.3,'pass','fail',3.5,2.5,2.5,3.20,'processing_artifact','fail_major','AEC underexposing; phantom below ACR minimum; MGD 3.2 above 3.0 mGy limit'),
    ('KIMS Secunderabad','MQA-2026-009','MG-KIM-019','Hologic Selenia Dimensions','ffdm_2d','post_repair','2026-07-14',
     127.00,'pass',28.0,28.1,'pass','pass',4.5,3.5,3.5,1.75,'clean','pending_physicist_review','Post-AEC-recalibration phantom images sent to physicist'),
    ('Care Hospitals Banjara Hills','MQA-2026-010','MG-CAR-044','Philips MicroDose SI','ffdm_2d','acceptance','2026-07-07',
     122.00,'pass',32.0,32.1,'pass','pass',5.0,4.0,4.0,1.20,'clean','pass','New unit acceptance test passed — lowest MGD in fleet'),
    ('Yashoda Somajiguda Hyderabad','MQA-2026-011','MG-YSH-026','GE Senographe Crystal Nova','cr_mammography','annual_full','2026-07-08',
     105.00,'fail',28.0,28.4,'pass','pass',3.0,3.0,2.5,2.80,'detector_defect','unit_suspended','Compression below minimum plus dead CR plate rows — unit suspended'),
    ('St John''s Bengaluru','MQA-2026-012','MG-STJ-008','Siemens Mammomat Fusion','ffdm_2d','semiannual','2026-07-10',
     117.00,'pass',28.0,27.9,'pass','pass',4.5,4.0,3.5,1.58,'clean','pass','Semiannual QA nominal'),
    ('Rainbow Children''s Hyderabad','MQA-2026-013','MG-RBW-051','Hologic 3Dimensions','dbt_tomosynthesis','routine_weekly','2026-07-13',
     114.00,'pass',29.0,30.5,'fail','drift_within_limits',4.0,3.5,3.0,1.95,'minor_artifacts','fail_minor','kVp measured 30.5 vs 29.0 set — generator drift; weekly phantom marginal')
  ) as q(hosp, ref, tag, model, utype, ttype, td, cf, fav, kset, kmeas, kav, aec, fib, spk, mas, mgd, art, qv, nt);

  -- CAPA seed — attach to specific QA tests
  insert into public.mammography_qa_capa_actions_r3198 (
    qa_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.st, q.ri, q.cost, q.nt
  from (values
    ('MQA-2026-003','compression_force_fail','force_sensor_drift','recalibrate_force_sensor','2026-07-10','2026-07-11','closed','aerb_notifiable',18500.00,'Force sensor recalibrated; verified in post-repair test MQA-2026-004'),
    ('MQA-2026-003','kvp_drift','generator_calibration_drift','recalibrate_generator','2026-07-10','2026-07-11','closed','internal_only',22000.00,'Generator kVp recalibrated alongside force sensor'),
    ('MQA-2026-008','aec_fail','aec_detector_aging','recalibrate_aec','2026-07-13','2026-07-14','verification_pending','patient_safety_alert',35000.00,'AEC recalibrated; awaiting physicist sign-off on MQA-2026-009'),
    ('MQA-2026-011','compression_force_fail','compression_paddle_worn','replace_compression_paddle','2026-07-15',null,'in_progress','aerb_notifiable',42000.00,'Paddle and force sensor kit ordered from GE'),
    ('MQA-2026-011','artifact_detected','detector_ghosting','suspend_unit_pending_service','2026-07-20',null,'escalated','patient_safety_alert',260000.00,'Dead CR plate rows — CR reader service escalated; screening moved to backup unit'),
    ('MQA-2026-013','kvp_drift','generator_calibration_drift','recalibrate_generator','2026-07-12',null,'overdue','nabh_finding',24000.00,'Generator drift recheck overdue — flagged for NABH mock audit')
  ) as q(ref, fc, rc, ca, tcd, acd, st, ri, cost, nt)
  join public.mammography_qa_r3198 e
    on e.organization_id = v_org_id and e.qa_ref_code = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QA verdict distribution
create or replace function public.founder_r3198_qa_verdict_rollup()
returns table(qa_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mammography_qa_r3198)
  select l.qa_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.mammography_qa_r3198 l
  group by l.qa_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3198_qa_verdict_rollup() from public, anon;
grant execute on function public.founder_r3198_qa_verdict_rollup() to authenticated;

-- 2) Hospital-level QA scorecard
create or replace function public.founder_r3198_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  suspended bigint,
  avg_phantom_score numeric,
  avg_mgd_mgy numeric,
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
    count(*) filter (where l.qa_verdict = 'pass')::bigint,
    count(*) filter (where l.qa_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qa_verdict in ('fail_minor','fail_major'))::bigint,
    count(*) filter (where l.qa_verdict = 'unit_suspended')::bigint,
    round(avg(l.acr_fibers_seen + l.acr_speck_groups_seen + l.acr_masses_seen), 1),
    round(avg(l.mean_glandular_dose_mgy), 2),
    round(100.0 * count(*) filter (where l.qa_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.mammography_qa_r3198 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3198_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3198_hospital_scorecard() to authenticated;

-- 3) Unit-type × test-type breakdown
create or replace function public.founder_r3198_unit_test_matrix()
returns table(unit_type text, test_type text, tests bigint, passed bigint, avg_force_n numeric, avg_phantom_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_type, l.test_type, count(*)::bigint,
    count(*) filter (where l.qa_verdict = 'pass')::bigint,
    round(avg(l.compression_force_n), 1),
    round(avg(l.acr_fibers_seen + l.acr_speck_groups_seen + l.acr_masses_seen), 1)
  from public.mammography_qa_r3198 l
  group by l.unit_type, l.test_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3198_unit_test_matrix() from public, anon;
grant execute on function public.founder_r3198_unit_test_matrix() to authenticated;

-- 4) Daily QA trend
create or replace function public.founder_r3198_daily_qa_trend()
returns table(test_date date, tests bigint, passed bigint, failed bigint, avg_phantom_score numeric, avg_mgd_mgy numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.qa_verdict = 'pass')::bigint,
    count(*) filter (where l.qa_verdict in ('fail_minor','fail_major','unit_suspended'))::bigint,
    round(avg(l.acr_fibers_seen + l.acr_speck_groups_seen + l.acr_masses_seen), 1),
    round(avg(l.mean_glandular_dose_mgy), 2)
  from public.mammography_qa_r3198 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3198_daily_qa_trend() from public, anon;
grant execute on function public.founder_r3198_daily_qa_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3198_capa_status_board()
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
  from public.mammography_qa_capa_actions_r3198 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3198_capa_status_board() from public, anon;
grant execute on function public.founder_r3198_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3198_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.mammography_qa_capa_actions_r3198)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.mammography_qa_capa_actions_r3198 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3198_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3198_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3198_regulatory_impact_digest()
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
  from public.mammography_qa_capa_actions_r3198 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3198_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3198_regulatory_impact_digest() to authenticated;

-- 8) High-risk units list (top individual concerns)
create or replace function public.founder_r3198_high_risk_units()
returns table(
  hospital_name text,
  mammo_unit_tag text,
  unit_model text,
  test_date date,
  qa_verdict text,
  compression_force_n numeric,
  aec_test_result text,
  phantom_total numeric,
  mean_glandular_dose_mgy numeric,
  artifact_check text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.mammo_unit_tag, l.unit_model, l.test_date,
    l.qa_verdict, l.compression_force_n, l.aec_test_result,
    (l.acr_fibers_seen + l.acr_speck_groups_seen + l.acr_masses_seen)::numeric,
    l.mean_glandular_dose_mgy, l.artifact_check, l.notes
  from public.mammography_qa_r3198 l
  where l.qa_verdict in ('fail_minor','fail_major','unit_suspended','pending_physicist_review','conditional_pass')
     or l.force_accuracy_verdict in ('fail','borderline')
     or l.kvp_accuracy_verdict = 'fail'
     or l.aec_test_result = 'fail'
     or l.artifact_check in ('detector_defect','processing_artifact')
     or l.mean_glandular_dose_mgy > 3.0
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3198_high_risk_units() from public, anon;
grant execute on function public.founder_r3198_high_risk_units() to authenticated;
