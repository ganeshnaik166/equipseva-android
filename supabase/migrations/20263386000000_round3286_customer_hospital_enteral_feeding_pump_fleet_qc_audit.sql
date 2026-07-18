-- Round 3286: Customer Hospital Enteral (Tube) Feeding-Pump Fleet QC Audit
-- Enteral pump QA — pump type × flow-rate accuracy × occlusion alarm × air-in-line alarm × dose-volume × keypad-lock × battery runtime × giving-set / ENFit misconnection safety × calibration × CAPA

-- =============================================================================
-- TABLE 1: enteral_feeding_pump_r3286 — per-pump QC checks
-- =============================================================================
create table if not exists public.enteral_feeding_pump_r3286 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  pump_code text not null,
  pump_type text not null check (pump_type in (
    'stationary_enteral','ambulatory_enteral','icu_enteral','neonatal_enteral'
  )),
  ward text not null,
  check_date date not null,
  flow_rate_accuracy_error_pct numeric(5,2),
  occlusion_alarm_test text not null check (occlusion_alarm_test in (
    'pass','fail','not_tested'
  )),
  air_in_line_alarm_test text not null check (air_in_line_alarm_test in (
    'pass','fail','not_tested'
  )),
  dose_volume_accuracy_ok boolean not null,
  keypad_lock_ok boolean not null,
  battery_runtime_hours numeric(5,2),
  giving_set_compatibility_ok boolean not null,
  cleaning_hygiene_ok boolean not null,
  misconnection_safety_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.enteral_feeding_pump_r3286 enable row level security;

create index if not exists idx_enteral_pump_r3286_org on public.enteral_feeding_pump_r3286(organization_id);
create index if not exists idx_enteral_pump_r3286_date on public.enteral_feeding_pump_r3286(check_date);
create index if not exists idx_enteral_pump_r3286_verdict on public.enteral_feeding_pump_r3286(qc_verdict);

-- =============================================================================
-- TABLE 2: enteral_feeding_pump_capa_actions_r3286 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.enteral_feeding_pump_capa_actions_r3286 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.enteral_feeding_pump_r3286(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'flow_rate_deviation','occlusion_alarm_failure','air_in_line_alarm_failure','dose_volume_inaccuracy',
    'keypad_lock_failure','battery_runtime_low','giving_set_incompatibility','cleaning_hygiene_deficiency',
    'misconnection_safety_risk','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_mechanism_wear','occlusion_sensor_fault','air_sensor_fault','flow_calibration_drift',
    'keypad_membrane_worn','battery_degraded','incompatible_giving_set_stock','inadequate_cleaning_protocol',
    'non_enfit_connector_present','software_config_error','operator_setup_error','pending_investigation',
    'preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_flow_rate','replace_occlusion_sensor','replace_air_sensor','replace_keypad_membrane',
    'replace_battery_pack','swap_to_enfit_giving_sets','reinforce_cleaning_protocol','retrofit_enfit_connectors',
    'update_software_config','retrain_ward_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','enfit_iso80369_deviation','patient_safety_alert',
    'iso_13485_deviation','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.enteral_feeding_pump_capa_actions_r3286 enable row level security;

create index if not exists idx_enteral_pump_capa_r3286_log on public.enteral_feeding_pump_capa_actions_r3286(qc_log_id);
create index if not exists idx_enteral_pump_capa_r3286_status on public.enteral_feeding_pump_capa_actions_r3286(capa_status);

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

  -- 14 QC check rows
  insert into public.enteral_feeding_pump_r3286 (
    organization_id, hospital_name, pump_code, pump_type, ward, check_date,
    flow_rate_accuracy_error_pct, occlusion_alarm_test, air_in_line_alarm_test,
    dose_volume_accuracy_ok, keypad_lock_ok, battery_runtime_hours,
    giving_set_compatibility_ok, cleaning_hygiene_ok, misconnection_safety_ok,
    calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ptype, q.ward, q.cdate::date,
    q.ferr, q.oat, q.aat,
    q.dva, q.klk, q.brt,
    q.gsc, q.chy, q.msc,
    q.calc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','EFP-APL-101','icu_enteral','MICU','2026-07-08',
     1.20,'pass','pass',true,true,6.5,true,true,true,true,'pass','Quarterly QC — all parameters within spec'),
    ('Apollo Chennai Greams Road','EFP-APL-102','stationary_enteral','Gastroenterology Ward','2026-07-08',
     7.80,'pass','pass',true,true,5.0,true,true,true,true,'conditional_pass','Flow error 7.8% above 5% tolerance — recheck booked'),
    ('Fortis Gurgaon','EFP-FRT-201','neonatal_enteral','NICU','2026-07-07',
     0.60,'pass','fail',true,true,4.5,true,true,true,true,'removed_from_service','Air-in-line alarm missed 0.5 mL bubble challenge — unit pulled from NICU'),
    ('Fortis Gurgaon','EFP-FRT-202','icu_enteral','SICU','2026-07-07',
     2.10,'fail','pass',false,true,3.2,true,true,true,false,'fail','Occlusion alarm did not trip at 12 psi; dose-volume off and calibration lapsed'),
    ('Manipal Bengaluru Old Airport Road','EFP-MNP-301','stationary_enteral','General Medicine','2026-07-06',
     0.90,'pass','pass',true,false,6.0,true,true,true,true,'conditional_pass','Keypad lock intermittent — membrane replacement scheduled'),
    ('Manipal Bengaluru Old Airport Road','EFP-MNP-302','ambulatory_enteral','Home-Care Discharge','2026-07-06',
     1.50,'pass','pass',true,true,1.8,true,true,true,true,'conditional_pass','Battery runtime 1.8h below 4h ambulatory minimum — pack aging'),
    ('AIIMS New Delhi Ansari Nagar','EFP-AIM-401','icu_enteral','Neuro ICU','2026-07-05',
     3.40,'pass','pass',true,true,5.5,false,true,true,true,'conditional_pass','Giving-set incompatible with new ENFit stock — compatibility review'),
    ('AIIMS New Delhi Ansari Nagar','EFP-AIM-402','stationary_enteral','Oncology Ward','2026-07-05',
     0.40,'pass','pass',true,true,6.2,true,true,true,true,'pass','Annual QC clean pass'),
    ('CMC Vellore','EFP-CMC-501','neonatal_enteral','NICU','2026-07-04',
     9.60,'fail','pass',false,true,4.0,true,true,true,false,'fail','Flow error 9.6% and occlusion alarm failed — pump mechanism wear suspected'),
    ('CMC Vellore','EFP-CMC-502','icu_enteral','PICU','2026-07-04',
     1.10,'pass','pass',true,true,5.8,true,false,true,true,'conditional_pass','Cleaning/hygiene deficiency — residue in pump channel, deep-clean ordered'),
    ('KIMS Hyderabad','EFP-KIM-601','stationary_enteral','Nephrology Ward','2026-07-03',
     0.70,'pass','pass',true,true,6.0,true,true,false,true,'fail','Non-ENFit legacy connector found — misconnection risk, retrofit required'),
    ('KIMS Hyderabad','EFP-KIM-602','ambulatory_enteral','Palliative Care','2026-07-03',
     1.30,'pass','pass',true,true,5.2,true,true,true,true,'pass','Post-AMC verification pass'),
    ('Yashoda Hyderabad Somajiguda','EFP-YSH-701','stationary_enteral','Surgical Ward','2026-07-02',
     null,'not_tested','not_tested',false,true,null,true,true,true,false,'removed_from_service','QC aborted — pump powered down mid-test, calibration expired, unit withdrawn'),
    ('Rainbow Children''s Bengaluru','EFP-RBW-801','neonatal_enteral','NICU-2','2026-07-02',
     0.50,'pass','pass',true,true,4.8,true,true,true,true,'pass','Neonatal micro-dose protocol verified')
  ) as q(hosp, code, ptype, ward, cdate, ferr, oat, aat, dva, klk, brt, gsc, chy, msc, calc, qv, nt);

  -- CAPA seed — attach to specific checks via pump_code
  insert into public.enteral_feeding_pump_capa_actions_r3286 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('EFP-FRT-201','air_in_line_alarm_failure','air_sensor_fault','replace_air_sensor','in_progress','patient_safety_alert','2026-07-11',null,22000.00,'Air sensor swapped — awaiting bubble re-challenge in NICU'),
    ('EFP-FRT-202','occlusion_alarm_failure','occlusion_sensor_fault','replace_occlusion_sensor','escalated','cdsco_notifiable','2026-07-10',null,34000.00,'No occlusion trip at 12 psi — escalated to OEM; calibration also lapsed'),
    ('EFP-CMC-501','flow_rate_deviation','pump_mechanism_wear','recalibrate_flow_rate','open','nabh_finding','2026-07-14',null,46000.00,'Peristaltic rotor mechanism worn — recalibrate then reassess'),
    ('EFP-KIM-601','misconnection_safety_risk','non_enfit_connector_present','retrofit_enfit_connectors','open','enfit_iso80369_deviation','2026-07-16',null,15000.00,'Legacy Luer giving-set port found — ENFit retrofit per ISO 80369-3'),
    ('EFP-MNP-302','battery_runtime_low','battery_degraded','replace_battery_pack','verification_pending','internal_only','2026-07-09',null,8500.00,'Battery pack replaced — verify 4h runtime on next ambulatory check'),
    ('EFP-CMC-502','cleaning_hygiene_deficiency','inadequate_cleaning_protocol','reinforce_cleaning_protocol','closed','iso_13485_deviation','2026-07-08','2026-07-05',3000.00,'Deep-clean completed and ward SOP re-briefed'),
    ('EFP-YSH-701','calibration_overdue','flow_calibration_drift','schedule_oem_service','overdue','internal_only','2026-07-01',null,12000.00,'Calibration past due and pump withdrawn — OEM service visit delayed')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.enteral_feeding_pump_r3286 e
    on e.organization_id = v_org_id and e.pump_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3286_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.enteral_feeding_pump_r3286)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.enteral_feeding_pump_r3286 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3286_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3286_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3286_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  occlusion_fail bigint,
  air_alarm_fail bigint,
  calibration_lapsed bigint,
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
    count(*) filter (where l.occlusion_alarm_test = 'fail')::bigint,
    count(*) filter (where l.air_in_line_alarm_test = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.enteral_feeding_pump_r3286 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3286_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3286_hospital_scorecard() to authenticated;

-- 3) Pump type × ward matrix
create or replace function public.founder_r3286_pump_type_ward_matrix()
returns table(pump_type text, ward text, audits bigint, passed bigint, avg_flow_error_pct numeric, avg_battery_runtime_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pump_type, l.ward, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.flow_rate_accuracy_error_pct), 2),
    round(avg(l.battery_runtime_hours), 1)
  from public.enteral_feeding_pump_r3286 l
  group by l.pump_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3286_pump_type_ward_matrix() from public, anon;
grant execute on function public.founder_r3286_pump_type_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3286_daily_qc_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, occlusion_fail bigint, air_alarm_fail bigint)
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
    count(*) filter (where l.occlusion_alarm_test = 'fail')::bigint,
    count(*) filter (where l.air_in_line_alarm_test = 'fail')::bigint
  from public.enteral_feeding_pump_r3286 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3286_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3286_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3286_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.enteral_feeding_pump_capa_actions_r3286 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3286_capa_status_board() from public, anon;
grant execute on function public.founder_r3286_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3286_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.enteral_feeding_pump_capa_actions_r3286)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.enteral_feeding_pump_capa_actions_r3286 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3286_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3286_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3286_regulatory_impact_digest()
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
  from public.enteral_feeding_pump_capa_actions_r3286 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3286_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3286_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3286_high_risk_queue()
returns table(
  hospital_name text,
  pump_code text,
  pump_type text,
  ward text,
  check_date date,
  qc_verdict text,
  occlusion_alarm_test text,
  air_in_line_alarm_test text,
  calibration_current boolean,
  misconnection_safety_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.pump_code, l.pump_type, l.ward, l.check_date,
    l.qc_verdict, l.occlusion_alarm_test, l.air_in_line_alarm_test,
    l.calibration_current, l.misconnection_safety_ok, l.notes
  from public.enteral_feeding_pump_r3286 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.occlusion_alarm_test = 'fail'
     or l.air_in_line_alarm_test = 'fail'
     or l.dose_volume_accuracy_ok = false
     or l.giving_set_compatibility_ok = false
     or l.cleaning_hygiene_ok = false
     or l.misconnection_safety_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3286_high_risk_queue() from public, anon;
grant execute on function public.founder_r3286_high_risk_queue() to authenticated;
