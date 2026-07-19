-- Round 3371: Customer Hospital Biomedical-Engineering Department Test-Equipment QC Audit
-- Biomed test-tool QA — tool type × self-test × calibration traceability × cal-due window × accuracy verification × reference cross-check × firmware × physical condition × usage log × CAPA

-- =============================================================================
-- TABLE 1: biomed_test_equipment_r3371 — per-tool biomed test-equipment QC checks
-- =============================================================================
create table if not exists public.biomed_test_equipment_r3371 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  tool_code text not null,
  tool_type text not null check (tool_type in (
    'defibrillator_analyzer','esu_analyzer','electrical_safety_analyzer','patient_simulator',
    'infusion_pump_analyzer','spo2_simulator','nibp_simulator'
  )),
  biomed_dept text not null,
  check_date date not null,
  self_test_pass boolean not null,
  calibration_traceable boolean not null,
  calibration_due_date date not null,
  days_to_cal_due int not null,
  accuracy_verification_ok text not null check (accuracy_verification_ok in (
    'pass','drift','fail'
  )),
  reference_cross_check_ok boolean not null,
  firmware_current boolean not null,
  physical_condition text not null check (physical_condition in (
    'good','worn','damaged','replace_due'
  )),
  usage_log_maintained boolean not null,
  tool_verdict text not null check (tool_verdict in (
    'in_cal_trusted','cal_due_soon','overdue_untrusted','accuracy_review','retire'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.biomed_test_equipment_r3371 enable row level security;

create index if not exists idx_biomed_test_equipment_r3371_org on public.biomed_test_equipment_r3371(organization_id);
create index if not exists idx_biomed_test_equipment_r3371_date on public.biomed_test_equipment_r3371(check_date);
create index if not exists idx_biomed_test_equipment_r3371_verdict on public.biomed_test_equipment_r3371(tool_verdict);

-- =============================================================================
-- TABLE 2: biomed_test_equipment_capa_actions_r3371 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.biomed_test_equipment_capa_actions_r3371 (
  id uuid primary key default gen_random_uuid(),
  check_log_id uuid not null references public.biomed_test_equipment_r3371(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_overdue','calibration_traceability_missing','accuracy_drift','self_test_failure',
    'reference_cross_check_failure','firmware_outdated','physical_damage','usage_log_lapse','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'calibration_cycle_lapsed','nabl_cert_not_on_file','sensor_reference_drift','internal_component_wear',
    'firmware_update_skipped','physical_mishandling','documentation_process_gap','vendor_calibration_backlog',
    'end_of_life_hardware','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'send_for_external_calibration','obtain_nabl_traceable_cert','recalibrate_and_verify','replace_worn_component',
    'apply_firmware_update','repair_physical_damage','reinstate_usage_log_process','quarantine_from_service',
    'replace_test_tool','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','nabl_traceability_gap','patient_safety_risk','internal_only','none','iso_13485_deviation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.biomed_test_equipment_capa_actions_r3371 enable row level security;

create index if not exists idx_biomed_capa_r3371_log on public.biomed_test_equipment_capa_actions_r3371(check_log_id);
create index if not exists idx_biomed_capa_r3371_status on public.biomed_test_equipment_capa_actions_r3371(capa_status);

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

  -- 14 biomed test-equipment QC rows
  insert into public.biomed_test_equipment_r3371 (
    organization_id, hospital_name, tool_code, tool_type, biomed_dept,
    check_date, self_test_pass, calibration_traceable, calibration_due_date, days_to_cal_due,
    accuracy_verification_ok, reference_cross_check_ok, firmware_current, physical_condition,
    usage_log_maintained, tool_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ttype, q.dept,
    q.cd::date, q.stp, q.ct, q.cdd::date, q.dtc,
    q.avo, q.rcc, q.fc, q.pc,
    q.ulm, q.tv, q.nt
  from (values
    ('Apollo Chennai Greams Road','BME-APL-DA01','defibrillator_analyzer','Clinical Engineering - Cardiology Wing',
     '2026-07-02',true,true,'2026-11-15',136,'pass',true,true,'good',true,'in_cal_trusted',
     'Annual QC clean — biphasic energy accuracy within 2% across all settings'),
    ('Apollo Chennai Greams Road','BME-APL-ES02','esu_analyzer','Clinical Engineering - OT Complex',
     '2026-07-02',true,true,'2026-08-05',24,'pass',true,true,'good',true,'cal_due_soon',
     'HF leakage and power accuracy nominal; calibration due in 24 days'),
    ('Fortis Gurgaon','BME-FRT-ES03','electrical_safety_analyzer','Biomedical Engineering Dept',
     '2026-07-01',true,false,'2026-06-10',-21,'drift',false,true,'worn',true,'overdue_untrusted',
     'Cal cert expired 21 days ago and no NABL traceability — pulled from use'),
    ('Fortis Gurgaon','BME-FRT-PS04','patient_simulator','Biomedical Engineering Dept',
     '2026-07-01',true,true,'2026-09-20',81,'drift',true,false,'good',true,'accuracy_review',
     'ECG amplitude drift 6% vs reference — under accuracy review, firmware update pending'),
    ('Manipal Bengaluru Old Airport Road','BME-MNP-IP05','infusion_pump_analyzer','Clinical Engineering - ICU Block',
     '2026-06-30',true,true,'2026-12-01',154,'pass',true,true,'good',true,'in_cal_trusted',
     'Flow and occlusion accuracy verified against reference standard'),
    ('Manipal Bengaluru Old Airport Road','BME-MNP-SP06','spo2_simulator','Clinical Engineering - ICU Block',
     '2026-06-30',true,true,'2026-07-25',25,'pass',true,true,'worn',false,'cal_due_soon',
     'SpO2 R-curve within spec; usage-log gaps flagged and calibration due soon'),
    ('AIIMS Delhi Ansari Nagar','BME-AIM-DA07','defibrillator_analyzer','Department of Biomedical Engineering',
     '2026-06-29',false,true,'2026-05-01',-59,'fail',false,false,'replace_due',true,'retire',
     'Self-test fail and energy readings unstable — beyond economic repair, retire'),
    ('AIIMS Delhi Ansari Nagar','BME-AIM-NB08','nibp_simulator','Department of Biomedical Engineering',
     '2026-06-29',true,true,'2026-10-10',103,'pass',true,true,'good',true,'in_cal_trusted',
     'Static pressure and dynamic BP simulation within tolerance'),
    ('CMC Vellore','BME-CMC-ES09','esu_analyzer','Bioengineering Division',
     '2026-06-28',true,true,'2026-08-30',63,'drift',true,true,'good',true,'accuracy_review',
     'HF power output reading drift 4.5% — cross-check booked before next OT QC cycle'),
    ('CMC Vellore','BME-CMC-ES10','electrical_safety_analyzer','Bioengineering Division',
     '2026-06-28',true,true,'2027-01-15',201,'pass',true,true,'good',true,'in_cal_trusted',
     'Leakage current and earth-bond measurement verified NABL-traceable'),
    ('KIMS Hyderabad Kondapur','BME-KIM-IP11','infusion_pump_analyzer','Biomedical Engineering Cell',
     '2026-06-27',true,false,'2026-06-05',-22,'pass',true,true,'worn',false,'overdue_untrusted',
     'Passes self-test but calibration lapsed 22 days and no traceable cert on file'),
    ('KIMS Hyderabad Kondapur','BME-KIM-PS12','patient_simulator','Biomedical Engineering Cell',
     '2026-06-27',true,true,'2026-07-30',33,'pass',true,true,'good',true,'cal_due_soon',
     'Multiparameter simulation nominal; schedule recalibration within the month'),
    ('Narayana Health Bengaluru','BME-NAR-SP13','spo2_simulator','Clinical Engineering Services',
     '2026-06-26',true,true,'2026-09-05',71,'drift',false,true,'worn',true,'accuracy_review',
     'SpO2 simulation reads 3% low at 80% saturation — reference cross-check failed, under review'),
    ('Kokilaben Dhirubhai Ambani Mumbai','BME-KOK-DA14','defibrillator_analyzer','Biomedical Engineering Department',
     '2026-06-25',true,true,'2026-12-20',178,'pass',true,true,'good',true,'in_cal_trusted',
     'Biphasic energy and sync-cardioversion timing verified within spec')
  ) as q(hosp, code, ttype, dept, cd, stp, ct, cdd, dtc, avo, rcc, fc, pc, ulm, tv, nt);

  -- CAPA seed — attach to specific checks via tool_code
  insert into public.biomed_test_equipment_capa_actions_r3371 (
    check_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('BME-FRT-ES03','calibration_traceability_missing','nabl_cert_not_on_file','obtain_nabl_traceable_cert','in_progress','nabl_traceability_gap','2026-07-20',null,15000.00,'Sent to NABL lab for traceable calibration; interim tool borrowed from OT'),
    ('BME-FRT-PS04','accuracy_drift','firmware_update_skipped','apply_firmware_update','open','internal_only','2026-07-18',null,0.00,'ECG amplitude drift traced to old firmware; OEM update package requested'),
    ('BME-AIM-DA07','self_test_failure','end_of_life_hardware','replace_test_tool','escalated','patient_safety_risk','2026-08-15',null,285000.00,'Analyzer beyond economic repair — capital request raised for replacement unit'),
    ('BME-KIM-IP11','calibration_overdue','vendor_calibration_backlog','send_for_external_calibration','overdue','nabh_finding','2026-06-25',null,22000.00,'Calibration vendor backlog; escalated to procurement, tool quarantined meanwhile'),
    ('BME-NAR-SP13','reference_cross_check_failure','sensor_reference_drift','recalibrate_and_verify','verification_pending','iso_13485_deviation','2026-07-12',null,9500.00,'SpO2 low-saturation reading recalibrated; awaiting cross-check verification'),
    ('BME-CMC-ES09','accuracy_drift','sensor_reference_drift','recalibrate_and_verify','closed','internal_only','2026-07-05','2026-07-03',8000.00,'HF power drift corrected on recalibration; verified within 1.5% and closed'),
    ('BME-MNP-SP06','usage_log_lapse','documentation_process_gap','reinstate_usage_log_process','open','nabh_finding','2026-07-15',null,0.00,'Usage-log gaps flagged; digital log sheet reinstated and staff briefed')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.biomed_test_equipment_r3371 e
    on e.organization_id = v_org_id and e.tool_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Tool verdict distribution
create or replace function public.founder_r3371_tool_verdict_rollup()
returns table(tool_verdict text, tools bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.biomed_test_equipment_r3371)
  select l.tool_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.biomed_test_equipment_r3371 l
  group by l.tool_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3371_tool_verdict_rollup() from public, anon;
grant execute on function public.founder_r3371_tool_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3371_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  trusted bigint,
  due_soon bigint,
  overdue_untrusted bigint,
  accuracy_review bigint,
  retire bigint,
  trusted_pct numeric
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
    count(*) filter (where l.tool_verdict = 'in_cal_trusted')::bigint,
    count(*) filter (where l.tool_verdict = 'cal_due_soon')::bigint,
    count(*) filter (where l.tool_verdict = 'overdue_untrusted')::bigint,
    count(*) filter (where l.tool_verdict = 'accuracy_review')::bigint,
    count(*) filter (where l.tool_verdict = 'retire')::bigint,
    round(100.0 * count(*) filter (where l.tool_verdict = 'in_cal_trusted')::numeric / nullif(count(*),0), 1)
  from public.biomed_test_equipment_r3371 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3371_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3371_hospital_scorecard() to authenticated;

-- 3) Tool type × accuracy-verification matrix
create or replace function public.founder_r3371_tool_type_accuracy_matrix()
returns table(tool_type text, accuracy_verification_ok text, checks bigint, trusted bigint, avg_days_to_cal_due numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.tool_type, l.accuracy_verification_ok, count(*)::bigint,
    count(*) filter (where l.tool_verdict = 'in_cal_trusted')::bigint,
    round(avg(l.days_to_cal_due), 1)
  from public.biomed_test_equipment_r3371 l
  group by l.tool_type, l.accuracy_verification_ok
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3371_tool_type_accuracy_matrix() from public, anon;
grant execute on function public.founder_r3371_tool_type_accuracy_matrix() to authenticated;

-- 4) Daily QC check trend
create or replace function public.founder_r3371_daily_check_trend()
returns table(check_date date, checks bigint, trusted bigint, overdue_untrusted bigint, accuracy_issues bigint, self_test_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.tool_verdict = 'in_cal_trusted')::bigint,
    count(*) filter (where l.tool_verdict = 'overdue_untrusted')::bigint,
    count(*) filter (where l.accuracy_verification_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.self_test_pass = false)::bigint
  from public.biomed_test_equipment_r3371 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3371_daily_check_trend() from public, anon;
grant execute on function public.founder_r3371_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3371_capa_status_board()
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
  from public.biomed_test_equipment_capa_actions_r3371 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3371_capa_status_board() from public, anon;
grant execute on function public.founder_r3371_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3371_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.biomed_test_equipment_capa_actions_r3371)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.biomed_test_equipment_capa_actions_r3371 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3371_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3371_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3371_regulatory_impact_digest()
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
  from public.biomed_test_equipment_capa_actions_r3371 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3371_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3371_regulatory_impact_digest() to authenticated;

-- 8) High-risk tool queue (top individual concerns)
create or replace function public.founder_r3371_high_risk_queue()
returns table(
  hospital_name text,
  tool_code text,
  tool_type text,
  check_date date,
  tool_verdict text,
  accuracy_verification_ok text,
  calibration_traceable boolean,
  days_to_cal_due int,
  physical_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.tool_code, l.tool_type, l.check_date,
    l.tool_verdict, l.accuracy_verification_ok, l.calibration_traceable, l.days_to_cal_due,
    l.physical_condition, l.notes
  from public.biomed_test_equipment_r3371 l
  where l.tool_verdict in ('cal_due_soon','overdue_untrusted','accuracy_review','retire')
     or l.accuracy_verification_ok in ('drift','fail')
     or l.calibration_traceable = false
     or l.self_test_pass = false
     or l.physical_condition in ('damaged','replace_due')
     or l.days_to_cal_due < 30
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3371_high_risk_queue() from public, anon;
grant execute on function public.founder_r3371_high_risk_queue() to authenticated;
