-- Round 3383: Customer Hospital Clinical Alarm-Management, Alarm-Fatigue & Secondary-Alerting Escalation Audit
-- Alarm QA — care area × monitor platform × middleware × alarm load/bed/day × actionable ratio × default-limit customization
--   × secondary alerting × nurse-call escalation × silence-policy × middleware uptime × sentinel alarm events × CAPA

-- =============================================================================
-- TABLE 1: clinical_alarm_r3383 — per unit/system alarm-management checks
-- =============================================================================
create table if not exists public.clinical_alarm_r3383 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  unit_code text not null,
  care_area text not null check (care_area in (
    'icu','ccu','nicu','step_down','general_ward','ot_recovery'
  )),
  physiological_monitor_model text not null check (physiological_monitor_model in (
    'philips_intellivue_mx800','philips_intellivue_mx550','ge_carescape_b650','ge_carescape_b850',
    'mindray_benevision_n22','mindray_epm_series','nihon_kohden_lifescope','drager_infinity_m540'
  )),
  alarm_middleware_platform text not null check (alarm_middleware_platform in (
    'philips_careevent','connexall','bernoulli_health','vocera_platform',
    'ascom_unite','mindray_alarm_gateway','spok_care_connect','none'
  )),
  check_date date not null,
  check_started_at timestamptz not null,
  alarm_load_per_bed_per_day numeric(6,1) not null,
  actionable_alarm_pct numeric(5,2) not null,
  non_actionable_alarm_pct numeric(5,2),
  default_limits_customized boolean not null,
  secondary_alerting_ok text not null check (secondary_alerting_ok in (
    'ok','delayed','not_configured','failed'
  )),
  escalation_to_nurse_call_ok boolean not null,
  alarm_silence_policy_followed boolean not null,
  alarm_middleware_uptime_pct numeric(5,2),
  staff_alarm_training_current boolean not null,
  sentinel_alarm_event int not null default 0,
  audit_verdict text not null check (audit_verdict in (
    'well_managed','needs_tuning','alarm_fatigue_risk','escalation_gap','patient_safety_risk'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.clinical_alarm_r3383 enable row level security;

create index if not exists idx_clinical_alarm_r3383_org on public.clinical_alarm_r3383(organization_id);
create index if not exists idx_clinical_alarm_r3383_date on public.clinical_alarm_r3383(check_date);
create index if not exists idx_clinical_alarm_r3383_verdict on public.clinical_alarm_r3383(audit_verdict);

-- =============================================================================
-- TABLE 2: clinical_alarm_capa_actions_r3383 — CAPA tuning/policy/escalation actions
-- =============================================================================
create table if not exists public.clinical_alarm_capa_actions_r3383 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.clinical_alarm_r3383(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excessive_alarm_load','low_actionable_ratio','default_limits_not_customized','secondary_alerting_gap',
    'escalation_to_nurse_call_failure','alarm_silence_policy_breach','middleware_downtime',
    'staff_training_lapse','sentinel_alarm_event'
  )),
  root_cause text not null check (root_cause in (
    'limits_left_at_factory_default','middleware_integration_error','nurse_call_interface_down',
    'wifi_coverage_gap','alerting_device_shortage','policy_not_enforced','training_backlog',
    'monitor_firmware_bug','pending_investigation','staffing_shortage'
  )),
  corrective_action text not null check (corrective_action in (
    'customize_alarm_limits_by_unit','tune_alarm_delays_thresholds','reconfigure_secondary_alerting',
    'repair_nurse_call_integration','expand_wifi_coverage','procure_alerting_devices',
    'enforce_silence_policy','retrain_clinical_staff','update_monitor_firmware',
    'escalate_to_biomed_vendor','none_required'
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

alter table public.clinical_alarm_capa_actions_r3383 enable row level security;

create index if not exists idx_clinical_alarm_capa_r3383_log on public.clinical_alarm_capa_actions_r3383(audit_log_id);
create index if not exists idx_clinical_alarm_capa_r3383_status on public.clinical_alarm_capa_actions_r3383(capa_status);

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

  -- 14 alarm-management check rows
  insert into public.clinical_alarm_r3383 (
    organization_id, hospital_name, unit_code, care_area, physiological_monitor_model,
    alarm_middleware_platform, check_date, check_started_at,
    alarm_load_per_bed_per_day, actionable_alarm_pct, non_actionable_alarm_pct,
    default_limits_customized, secondary_alerting_ok, escalation_to_nurse_call_ok,
    alarm_silence_policy_followed, alarm_middleware_uptime_pct, staff_alarm_training_current,
    sentinel_alarm_event, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.unit, q.area, q.mon,
    q.mw, q.cd::date, q.cs::timestamptz,
    q.load, q.act, q.nonact,
    q.dlc, q.sa, q.esc,
    q.sil, q.up, q.train,
    q.sent, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','ICU-APL-1','icu','philips_intellivue_mx800','philips_careevent','2026-07-10','2026-07-10 08:10:00+05:30',
     165.0,22.50,77.50,true,'ok',true,true,99.4,true,0,'well_managed','Limits customised per bay; secondary alerting to Ascom handsets within 12s'),
    ('Apollo Chennai Greams Road','CCU-APL-2','ccu','ge_carescape_b650','connexall','2026-07-10','2026-07-10 09:05:00+05:30',
     240.0,14.00,86.00,false,'delayed',true,true,97.1,true,0,'needs_tuning','SpO2 low limits left at default 90; delayed secondary push averaging 34s'),
    ('Fortis Gurgaon','ICU-FRT-1','icu','philips_intellivue_mx550','philips_careevent','2026-07-09','2026-07-09 07:40:00+05:30',
     310.0,9.50,90.50,false,'delayed',true,false,95.8,false,1,'alarm_fatigue_risk','310 alarms/bed/day, 9.5% actionable — heavy fatigue; one missed brady flagged'),
    ('Fortis Gurgaon','NICU-FRT-2','nicu','ge_carescape_b850','connexall','2026-07-09','2026-07-09 08:35:00+05:30',
     190.0,30.00,70.00,true,'ok',true,true,99.0,true,0,'well_managed','Neonatal limits per weight band; nurse-call escalation verified on live test'),
    ('Manipal Bengaluru Old Airport Road','ICU-MNP-1','icu','mindray_benevision_n22','mindray_alarm_gateway','2026-07-08','2026-07-08 06:55:00+05:30',
     275.0,12.00,88.00,false,'not_configured',false,false,92.5,false,2,'patient_safety_risk','Secondary alerting never configured; two sentinel events (missed VT) this quarter'),
    ('Manipal Bengaluru Old Airport Road','SD-MNP-2','step_down','mindray_epm_series','mindray_alarm_gateway','2026-07-08','2026-07-08 07:50:00+05:30',
     120.0,26.00,74.00,true,'ok',true,true,98.6,true,0,'well_managed','Step-down thresholds tuned; silence policy adhered on audit walk-through'),
    ('AIIMS Delhi Ansari Nagar','ICU-AIM-1','icu','drager_infinity_m540','ascom_unite','2026-07-07','2026-07-07 06:20:00+05:30',
     205.0,18.50,81.50,true,'delayed',true,true,96.3,true,0,'needs_tuning','Escalation ok but Ascom Unite latency 28s over 20s SLA — middleware tuning due'),
    ('AIIMS Delhi Ansari Nagar','GW-AIM-2','general_ward','nihon_kohden_lifescope','spok_care_connect','2026-07-07','2026-07-07 07:15:00+05:30',
     85.0,33.00,67.00,true,'ok',true,true,99.2,true,0,'well_managed','Telemetry ward well controlled; Spok routing to charge-nurse phone stable'),
    ('CMC Vellore','CCU-CMC-1','ccu','philips_intellivue_mx800','philips_careevent','2026-07-06','2026-07-06 08:00:00+05:30',
     260.0,15.00,85.00,false,'failed',false,true,88.4,true,1,'escalation_gap','Secondary alerting failed handoff at shift change; nurse-call bridge down 6h'),
    ('CMC Vellore','OTR-CMC-2','ot_recovery','ge_carescape_b650','connexall','2026-07-06','2026-07-06 09:10:00+05:30',
     140.0,24.00,76.00,true,'ok',true,true,98.9,true,0,'well_managed','PACU recovery bays clean; escalation to anaesthesia pager verified'),
    ('KIMS Hyderabad','ICU-KIM-1','icu','mindray_benevision_n22','none','2026-07-05','2026-07-05 06:45:00+05:30',
     330.0,8.00,92.00,false,'not_configured',false,false,null,false,3,'patient_safety_risk','No alarm middleware deployed; highest load, lowest actionable, 3 sentinel events'),
    ('KIMS Hyderabad','NICU-KIM-2','nicu','ge_carescape_b850','bernoulli_health','2026-07-05','2026-07-05 07:40:00+05:30',
     175.0,28.00,72.00,true,'ok',true,true,99.5,true,0,'well_managed','Bernoulli analytics suppressing artefact; actionable ratio healthy at 28%'),
    ('Yashoda Hyderabad Somajiguda','SD-YSH-1','step_down','nihon_kohden_lifescope','vocera_platform','2026-07-04','2026-07-04 08:25:00+05:30',
     155.0,20.00,80.00,true,'delayed',true,false,94.7,true,0,'needs_tuning','Silence-policy breach — nurses parking alarms 15min; Vocera delayed on B-wing'),
    ('Rainbow Childrens Bengaluru Marathahalli','NICU-RBW-1','nicu','philips_intellivue_mx550','philips_careevent','2026-07-04','2026-07-04 09:20:00+05:30',
     225.0,16.50,83.50,false,'delayed',true,true,97.8,false,1,'alarm_fatigue_risk','High neonatal load; staff alarm training lapsed, defaults not customised')
  ) as q(hosp, unit, area, mon, mw, cd, cs, load, act, nonact, dlc, sa, esc, sil, up, train, sent, verdict, nt);

  -- CAPA seed — attach to specific checks via unit_code
  insert into public.clinical_alarm_capa_actions_r3383 (
    audit_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ICU-FRT-1','excessive_alarm_load','limits_left_at_factory_default','customize_alarm_limits_by_unit','in_progress','patient_safety_alert','2026-07-22',null,45000.00,'Bay-level limit sets being built with intensivists to lift actionable ratio'),
    ('ICU-MNP-1','secondary_alerting_gap','middleware_integration_error','reconfigure_secondary_alerting','escalated','patient_safety_alert','2026-07-18',null,120000.00,'Mindray gateway never bound to handsets — escalated to biomed + OEM'),
    ('CCU-CMC-1','escalation_to_nurse_call_failure','nurse_call_interface_down','repair_nurse_call_integration','open','nabh_finding','2026-07-24',null,85000.00,'HL7 bridge to nurse-call dropped at shift change; interface engine restart + monitor'),
    ('ICU-KIM-1','middleware_downtime','alerting_device_shortage','procure_alerting_devices','escalated','cdsco_notifiable','2026-07-16',null,210000.00,'No middleware/devices at all — capex approval sought for Connexall + handsets'),
    ('CCU-APL-2','low_actionable_ratio','limits_left_at_factory_default','tune_alarm_delays_thresholds','verification_pending','internal_only','2026-07-15',null,30000.00,'Alarm delays added on SpO2/HR; awaiting one-week post-tuning load recount'),
    ('NICU-RBW-1','staff_training_lapse','training_backlog','retrain_clinical_staff','closed','internal_only','2026-07-12','2026-07-11',15000.00,'Alarm-management refresher completed for 18 NICU nurses; competency signed off'),
    ('SD-YSH-1','alarm_silence_policy_breach','policy_not_enforced','enforce_silence_policy','overdue','iso_13485_deviation','2026-07-08',null,8000.00,'Silence-duration cap not enforced in policy; SOP revision past target date')
  ) as q(unit, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.clinical_alarm_r3383 e
    on e.organization_id = v_org_id and e.unit_code = q.unit;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3383_verdict_rollup()
returns table(audit_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.clinical_alarm_r3383)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.clinical_alarm_r3383 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3383_verdict_rollup() from public, anon;
grant execute on function public.founder_r3383_verdict_rollup() to authenticated;

-- 2) Hospital-level alarm-management scorecard
create or replace function public.founder_r3383_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  well_managed bigint,
  needs_tuning bigint,
  fatigue_risk bigint,
  escalation_gap bigint,
  patient_safety bigint,
  secondary_alerting_issues bigint,
  escalation_fail bigint,
  well_managed_pct numeric
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
    count(*) filter (where l.audit_verdict = 'well_managed')::bigint,
    count(*) filter (where l.audit_verdict = 'needs_tuning')::bigint,
    count(*) filter (where l.audit_verdict = 'alarm_fatigue_risk')::bigint,
    count(*) filter (where l.audit_verdict = 'escalation_gap')::bigint,
    count(*) filter (where l.audit_verdict = 'patient_safety_risk')::bigint,
    count(*) filter (where l.secondary_alerting_ok in ('delayed','not_configured','failed'))::bigint,
    count(*) filter (where l.escalation_to_nurse_call_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'well_managed')::numeric / nullif(count(*),0), 1)
  from public.clinical_alarm_r3383 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3383_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3383_hospital_scorecard() to authenticated;

-- 3) Monitor platform × alarm-middleware platform matrix
create or replace function public.founder_r3383_monitor_middleware_matrix()
returns table(physiological_monitor_model text, alarm_middleware_platform text, checks bigint, well_managed bigint, avg_alarm_load numeric, avg_actionable_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.physiological_monitor_model, l.alarm_middleware_platform, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'well_managed')::bigint,
    round(avg(l.alarm_load_per_bed_per_day), 1),
    round(avg(l.actionable_alarm_pct), 2)
  from public.clinical_alarm_r3383 l
  group by l.physiological_monitor_model, l.alarm_middleware_platform
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3383_monitor_middleware_matrix() from public, anon;
grant execute on function public.founder_r3383_monitor_middleware_matrix() to authenticated;

-- 4) Daily check trend
create or replace function public.founder_r3383_daily_check_trend()
returns table(check_date date, checks bigint, well_managed bigint, patient_safety_risk bigint, secondary_alerting_fail bigint, escalation_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'well_managed')::bigint,
    count(*) filter (where l.audit_verdict = 'patient_safety_risk')::bigint,
    count(*) filter (where l.secondary_alerting_ok in ('not_configured','failed'))::bigint,
    count(*) filter (where l.escalation_to_nurse_call_ok = false)::bigint
  from public.clinical_alarm_r3383 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3383_daily_check_trend() from public, anon;
grant execute on function public.founder_r3383_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3383_capa_status_board()
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
  from public.clinical_alarm_capa_actions_r3383 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3383_capa_status_board() from public, anon;
grant execute on function public.founder_r3383_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3383_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.clinical_alarm_capa_actions_r3383)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.clinical_alarm_capa_actions_r3383 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3383_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3383_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3383_regulatory_impact_digest()
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
  from public.clinical_alarm_capa_actions_r3383 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3383_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3383_regulatory_impact_digest() to authenticated;

-- 8) High-risk alarm-management queue (top individual concerns)
create or replace function public.founder_r3383_high_risk_queue()
returns table(
  hospital_name text,
  unit_code text,
  care_area text,
  check_date date,
  audit_verdict text,
  secondary_alerting_ok text,
  escalation_to_nurse_call_ok boolean,
  alarm_middleware_uptime_pct numeric,
  sentinel_alarm_event int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.unit_code, l.care_area, l.check_date,
    l.audit_verdict, l.secondary_alerting_ok, l.escalation_to_nurse_call_ok,
    l.alarm_middleware_uptime_pct, l.sentinel_alarm_event, l.notes
  from public.clinical_alarm_r3383 l
  where l.audit_verdict in ('needs_tuning','alarm_fatigue_risk','escalation_gap','patient_safety_risk')
     or l.secondary_alerting_ok in ('not_configured','failed')
     or l.escalation_to_nurse_call_ok = false
     or l.sentinel_alarm_event > 0
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3383_high_risk_queue() from public, anon;
grant execute on function public.founder_r3383_high_risk_queue() to authenticated;
