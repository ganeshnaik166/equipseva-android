-- Round 3287: Customer Hospital PCA / Epidural Analgesia Pump Fleet QC Audit
-- High-alert opioid delivery QA — pump type × department × bolus-dose accuracy × lockout interval
-- × four-hour limit × drug-library currency × antitamper lock × air/occlusion alarm × event-log
-- download × battery runtime × keypad audit trail × calibration currency × CAPA closure

-- =============================================================================
-- TABLE 1: pca_pump_qc_r3287 — individual PCA / epidural pump QC checks
-- =============================================================================
create table if not exists public.pca_pump_qc_r3287 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  pump_code text not null,
  pump_type text not null check (pump_type in (
    'pca_iv','pca_epidural','ambulatory_pca','neuraxial_pump'
  )),
  department text not null,
  check_date date not null,
  bolus_dose_accuracy_error_pct numeric(5,2),
  lockout_interval_verified boolean not null,
  four_hour_limit_enforced boolean not null,
  drug_library_current boolean not null,
  antitamper_lock_ok boolean not null,
  air_occlusion_alarm_test text not null check (air_occlusion_alarm_test in (
    'pass','fail','not_tested'
  )),
  event_log_download_ok boolean not null,
  battery_runtime_hours numeric(5,2),
  keypad_audit_trail_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pca_pump_qc_r3287 enable row level security;

create index if not exists idx_pca_pump_qc_r3287_org on public.pca_pump_qc_r3287(organization_id);
create index if not exists idx_pca_pump_qc_r3287_date on public.pca_pump_qc_r3287(check_date);
create index if not exists idx_pca_pump_qc_r3287_verdict on public.pca_pump_qc_r3287(qc_verdict);

-- =============================================================================
-- TABLE 2: pca_pump_qc_capa_actions_r3287 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.pca_pump_qc_capa_actions_r3287 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.pca_pump_qc_r3287(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'bolus_accuracy_deviation','lockout_interval_failure','four_hour_limit_failure',
    'drug_library_outdated','antitamper_breach','air_occlusion_alarm_failure',
    'event_log_failure','keypad_audit_trail_failure','calibration_overdue',
    'battery_runtime_low','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_mechanism_wear','occlusion_sensor_drift','drug_library_not_pushed',
    'firmware_config_error','battery_degraded','keypad_membrane_fault',
    'tamper_lock_worn','operator_programming_error','pending_investigation',
    'preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_pump_mechanism','recalibrate_occlusion_sensor','push_current_drug_library',
    'update_firmware_config','replace_battery_pack','replace_keypad_membrane',
    'replace_tamper_lock','retrain_pain_service_staff','remove_from_service',
    'schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pca_pump_qc_capa_actions_r3287 enable row level security;

create index if not exists idx_pca_pump_capa_r3287_log on public.pca_pump_qc_capa_actions_r3287(qc_log_id);
create index if not exists idx_pca_pump_capa_r3287_status on public.pca_pump_qc_capa_actions_r3287(capa_status);

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

  -- 14 PCA / epidural pump QC rows
  insert into public.pca_pump_qc_r3287 (
    organization_id, hospital_name, pump_code, pump_type, department, check_date,
    bolus_dose_accuracy_error_pct, lockout_interval_verified, four_hour_limit_enforced,
    drug_library_current, antitamper_lock_ok, air_occlusion_alarm_test, event_log_download_ok,
    battery_runtime_hours, keypad_audit_trail_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ptype, q.dept, q.cd::date,
    q.bde, q.liv, q.fhl, q.dlc, q.atl, q.aoa, q.eld,
    q.brh, q.kat, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai','PCA-APL-01','pca_iv','Post-Surgical ICU','2026-07-05',
     1.20,true,true,true,true,'pass',true,22.5,true,true,'pass','Routine QC — all high-alert checks nominal'),
    ('Apollo Chennai','PCA-APL-02','pca_epidural','Labour & Delivery','2026-07-05',
     7.80,true,true,false,true,'pass',true,18.0,true,true,'conditional_pass','Bolus error 7.8% over 5% and drug library one version behind'),
    ('Fortis Gurgaon','PCA-FRT-11','pca_iv','Oncology Ward','2026-07-04',
     2.40,false,true,true,true,'pass',true,20.5,true,true,'conditional_pass','Lockout interval not verified on retest — reprogram booked'),
    ('Fortis Gurgaon','PCA-FRT-12','ambulatory_pca','Palliative Care','2026-07-04',
     3.10,true,false,true,false,'fail',true,9.5,true,true,'fail','Four-hour limit not enforced and antitamper lock defeated — high risk'),
    ('Manipal Bengaluru','PCA-MNP-21','neuraxial_pump','Pain Management','2026-07-03',
     1.80,true,true,true,true,'pass',true,24.0,true,false,'conditional_pass','Calibration certificate expired — OEM recert scheduled'),
    ('Manipal Bengaluru','PCA-MNP-22','pca_iv','Post-Surgical ICU','2026-07-03',
     12.60,true,true,true,true,'fail',false,16.5,true,true,'removed_from_service','Air/occlusion alarm did not trigger on test and bolus error 12.6% — pump pulled'),
    ('AIIMS Delhi','PCA-AIM-31','pca_epidural','Neurosurgery ICU','2026-07-02',
     0.90,true,true,true,true,'pass',true,21.0,true,true,'pass','Annual QC clean pass'),
    ('AIIMS Delhi','PCA-AIM-32','pca_iv','Emergency Ward','2026-07-02',
     2.20,true,true,false,true,'not_tested',true,19.0,false,true,'conditional_pass','Drug library outdated and keypad audit trail unreadable — flagged'),
    ('CMC Vellore','PCA-CMC-41','ambulatory_pca','Oncology Ward','2026-07-01',
     5.40,true,true,true,true,'pass',true,8.5,true,true,'conditional_pass','Battery runtime 8.5h below 12h minimum — battery pack watch'),
    ('CMC Vellore','PCA-CMC-42','neuraxial_pump','Pain Management','2026-07-01',
     1.10,true,true,true,true,'pass',true,23.5,true,true,'pass','Post-AMC verification pass'),
    ('KIMS Hyderabad','PCA-KIM-51','pca_iv','Post-Surgical ICU','2026-06-30',
     9.30,true,true,true,false,'pass',true,17.0,true,true,'fail','Antitamper lock breach found — unauthorized rate change possible'),
    ('KIMS Hyderabad','PCA-KIM-52','pca_epidural','Labour & Delivery','2026-06-30',
     2.00,true,true,true,true,'pass',true,20.0,true,true,'pass','Quarterly QC pass'),
    ('Kokilaben Mumbai','PCA-KOK-61','pca_iv','Cardiac ICU','2026-06-29',
     null,false,false,false,false,'not_tested',false,null,false,false,'removed_from_service','QC aborted — pump powers off intermittently, checks not run, pulled from service'),
    ('Narayana Health Bengaluru','PCA-NAR-71','ambulatory_pca','Palliative Care','2026-06-29',
     1.50,true,true,true,true,'pass',true,26.0,true,true,'pass','Home-care ambulatory pump QC pass')
  ) as q(hosp, code, ptype, dept, cd, bde, liv, fhl, dlc, atl, aoa, eld, brh, kat, cc, qv, nt);

  -- CAPA seed — attach to specific checks via pump code
  insert into public.pca_pump_qc_capa_actions_r3287 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PCA-FRT-12','four_hour_limit_failure','firmware_config_error','update_firmware_config','escalated','patient_safety_alert','2026-07-09',null,15000.00,'Four-hour dose limit config restored — pending verification on next case day'),
    ('PCA-MNP-22','air_occlusion_alarm_failure','occlusion_sensor_drift','recalibrate_occlusion_sensor','open','cdsco_notifiable','2026-07-10',null,34000.00,'Air/occlusion alarm did not trigger — occlusion sensor board on order from OEM'),
    ('PCA-KIM-51','antitamper_breach','tamper_lock_worn','replace_tamper_lock','in_progress','patient_safety_alert','2026-07-08',null,8500.00,'Tamper-lock kit fitted — keypad audit re-test pending'),
    ('PCA-AIM-32','drug_library_outdated','drug_library_not_pushed','push_current_drug_library','closed','iso_13485_deviation','2026-07-05','2026-07-03',0.00,'Current drug library v9.2 pushed to all Emergency Ward pumps'),
    ('PCA-CMC-41','battery_runtime_low','battery_degraded','replace_battery_pack','open','internal_only','2026-07-07',null,6500.00,'Battery runtime 8.5h below 12h floor — replacement pack ordered'),
    ('PCA-MNP-21','calibration_overdue','preventive_service_backlog','schedule_oem_service','verification_pending','nabh_finding','2026-07-06',null,12000.00,'OEM recertification scheduled — cert due before next clinical use'),
    ('PCA-KOK-61','preventive_maintenance_due','pending_investigation','remove_from_service','overdue','patient_safety_alert','2026-06-27',null,45000.00,'Pump powers off intermittently — sent to OEM, root cause under investigation')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.pca_pump_qc_r3287 e
    on e.organization_id = v_org_id and e.pump_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3287_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pca_pump_qc_r3287)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pca_pump_qc_r3287 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3287_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3287_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3287_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  alarm_fail bigint,
  antitamper_fail bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.air_occlusion_alarm_test = 'fail')::bigint,
    count(*) filter (where l.antitamper_lock_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.pca_pump_qc_r3287 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3287_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3287_hospital_scorecard() to authenticated;

-- 3) Pump type × department matrix
create or replace function public.founder_r3287_pump_type_department_matrix()
returns table(pump_type text, department text, checks bigint, passed bigint, avg_bolus_error_pct numeric, avg_battery_runtime_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pump_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.bolus_dose_accuracy_error_pct), 2),
    round(avg(l.battery_runtime_hours), 1)
  from public.pca_pump_qc_r3287 l
  group by l.pump_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3287_pump_type_department_matrix() from public, anon;
grant execute on function public.founder_r3287_pump_type_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3287_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, alarm_fail bigint, antitamper_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.air_occlusion_alarm_test = 'fail')::bigint,
    count(*) filter (where l.antitamper_lock_ok = false)::bigint
  from public.pca_pump_qc_r3287 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3287_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3287_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3287_capa_status_board()
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
  from public.pca_pump_qc_capa_actions_r3287 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3287_capa_status_board() from public, anon;
grant execute on function public.founder_r3287_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3287_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pca_pump_qc_capa_actions_r3287)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pca_pump_qc_capa_actions_r3287 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3287_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3287_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3287_regulatory_impact_digest()
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
  from public.pca_pump_qc_capa_actions_r3287 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3287_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3287_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3287_high_risk_queue()
returns table(
  hospital_name text,
  pump_code text,
  pump_type text,
  department text,
  check_date date,
  qc_verdict text,
  air_occlusion_alarm_test text,
  antitamper_lock text,
  four_hour_limit text,
  calibration text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.pump_code, l.pump_type, l.department, l.check_date,
    l.qc_verdict, l.air_occlusion_alarm_test,
    case when l.antitamper_lock_ok then 'ok' else 'breach' end,
    case when l.four_hour_limit_enforced then 'enforced' else 'not_enforced' end,
    case when l.calibration_current then 'current' else 'overdue' end,
    l.notes
  from public.pca_pump_qc_r3287 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.air_occlusion_alarm_test = 'fail'
     or l.antitamper_lock_ok = false
     or l.four_hour_limit_enforced = false
     or l.lockout_interval_verified = false
     or l.drug_library_current = false
     or l.calibration_current = false
     or l.keypad_audit_trail_ok = false
     or l.event_log_download_ok = false
     or l.bolus_dose_accuracy_error_pct > 5
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3287_high_risk_queue() from public, anon;
grant execute on function public.founder_r3287_high_risk_queue() to authenticated;
