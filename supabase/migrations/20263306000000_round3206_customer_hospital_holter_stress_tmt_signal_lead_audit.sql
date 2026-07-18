-- Round 3206: Customer Hospital Holter/Stress-Test (TMT) System Signal & Lead-Integrity Audit
-- Holter/TMT QA — system type × lead integrity × signal noise uV × treadmill speed/grade × emergency-stop × defib-readiness × baseline drift × CAPA

-- =============================================================================
-- TABLE 1: holter_tmt_r3206 — individual Holter/TMT system audits
-- =============================================================================
create table if not exists public.holter_tmt_r3206 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  cardiology_lab_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  system_type text not null check (system_type in (
    'holter_3_channel','holter_12_channel','tmt_treadmill','ambulatory_bp','stress_echo_combo'
  )),
  audit_date date not null,
  audited_at timestamptz not null,
  lead_integrity text not null check (lead_integrity in (
    'all_leads_ok','intermittent_dropout','lead_off_artifact',
    'cable_fracture','electrode_gel_dried','connector_corroded'
  )),
  signal_noise_uv numeric(6,2),
  ecg_baseline_drift text not null check (ecg_baseline_drift in (
    'within_limits','mild_wander','severe_wander','not_measured'
  )),
  treadmill_speed_error_pct numeric(5,2),
  treadmill_grade_error_pct numeric(5,2),
  speed_grade_verdict text check (speed_grade_verdict in ('pass','fail','borderline','not_applicable')),
  emergency_stop_test text not null check (emergency_stop_test in (
    'pass','fail','sluggish_response','not_tested','not_applicable'
  )),
  defib_nearby_check text not null check (defib_nearby_check in (
    'crash_cart_ready','defib_missing','defib_battery_low','defib_pads_expired','not_checked'
  )),
  technician_profile_id uuid references public.profiles(id) on delete set null,
  audit_verdict text not null check (audit_verdict in (
    'cleared','restricted_use','out_of_service','recalibration_needed','pending_review','conditional_clear'
  )),
  cleared_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.holter_tmt_r3206 enable row level security;

create index if not exists idx_holter_tmt_r3206_org on public.holter_tmt_r3206(organization_id);
create index if not exists idx_holter_tmt_r3206_date on public.holter_tmt_r3206(audit_date);
create index if not exists idx_holter_tmt_r3206_verdict on public.holter_tmt_r3206(audit_verdict);

-- =============================================================================
-- TABLE 2: holter_tmt_capa_actions_r3206 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.holter_tmt_capa_actions_r3206 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.holter_tmt_r3206(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'lead_integrity_fail','signal_noise_high','baseline_drift_severe',
    'speed_grade_out_of_tolerance','emergency_stop_fail','defib_readiness_gap',
    'hookup_technique_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'patient_cable_worn','electrode_stock_expired','treadmill_belt_worn',
    'grade_actuator_drift','estop_switch_stuck','mains_earth_leakage',
    'skin_prep_skipped','defib_battery_aged','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_patient_cable','replace_electrode_stock','replace_treadmill_belt',
    'recalibrate_speed_grade','replace_estop_switch','fix_earth_bonding',
    'retrain_technician','replace_defib_battery','schedule_amc_visit','none_required'
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

alter table public.holter_tmt_capa_actions_r3206 enable row level security;

create index if not exists idx_holter_tmt_capa_r3206_audit on public.holter_tmt_capa_actions_r3206(audit_id);
create index if not exists idx_holter_tmt_capa_r3206_status on public.holter_tmt_capa_actions_r3206(capa_status);

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
  insert into public.holter_tmt_r3206 (
    organization_id, hospital_name, cardiology_lab_code, device_asset_tag, device_model,
    system_type, audit_date, audited_at,
    lead_integrity, signal_noise_uv, ecg_baseline_drift,
    treadmill_speed_error_pct, treadmill_grade_error_pct, speed_grade_verdict,
    emergency_stop_test, defib_nearby_check,
    audit_verdict, cleared_at, notes
  )
  select v_org_id, q.hosp, q.lab, q.tag, q.model,
    q.st, q.ad::date, q.aud::timestamptz,
    q.li, q.noise, q.drift,
    q.spe, q.gre, q.sgv,
    q.est, q.dfc,
    q.av, q.cl::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CARD-LAB-1','HT-APL-101','GE CASE 6.5','tmt_treadmill','2026-07-02','2026-07-02 09:15:00+05:30',
     'all_leads_ok',8.50,'within_limits',1.20,0.80,'pass','pass','crash_cart_ready','cleared','2026-07-02 10:00:00+05:30','Quarterly TMT audit — all parameters within tolerance'),
    ('Apollo Hyderabad Jubilee Hills','CARD-LAB-1','HT-APL-102','GE SEER 1000','holter_3_channel','2026-07-02','2026-07-02 11:00:00+05:30',
     'intermittent_dropout',42.00,'mild_wander',null,null,'not_applicable','not_applicable','crash_cart_ready','restricted_use',null,'Channel 2 dropout on cable flex test — patient cable suspect'),
    ('Fortis Bannerghatta Bengaluru','CARD-LAB-2','HT-FRT-201','Schiller CS-200','tmt_treadmill','2026-07-01','2026-07-01 08:30:00+05:30',
     'all_leads_ok',12.00,'within_limits',6.50,1.10,'fail','pass','crash_cart_ready','recalibration_needed',null,'Belt speed error 6.5 pct at 10 km/h — outside 2 pct tolerance'),
    ('Fortis Bannerghatta Bengaluru','CARD-LAB-2','HT-FRT-202','Mortara XScribe','tmt_treadmill','2026-07-01','2026-07-01 10:15:00+05:30',
     'lead_off_artifact',65.00,'severe_wander',1.40,0.90,'pass','fail','defib_pads_expired','out_of_service',null,'Emergency stop unresponsive and defib pads expired — unit pulled'),
    ('Manipal Whitefield Bengaluru','CARD-LAB-1','HT-MNP-301','Philips DigiTrak XT','holter_12_channel','2026-06-30','2026-06-30 09:00:00+05:30',
     'electrode_gel_dried',55.00,'mild_wander',null,null,'not_applicable','not_applicable','crash_cart_ready','restricted_use',null,'Electrode stock past expiry — noise floor 55 uV'),
    ('Manipal Whitefield Bengaluru','CARD-LAB-1','HT-MNP-302','Mortara Ambulo 2400','ambulatory_bp','2026-06-30','2026-06-30 10:30:00+05:30',
     'all_leads_ok',6.00,'within_limits',null,null,'not_applicable','not_applicable','not_checked','cleared','2026-06-30 11:00:00+05:30','ABP monitor verified against reference sphygmomanometer'),
    ('AIIMS New Delhi Ansari Nagar','CARD-LAB-3','HT-AIM-401','GE CASE 6.5','tmt_treadmill','2026-06-29','2026-06-29 08:00:00+05:30',
     'all_leads_ok',9.00,'within_limits',0.80,0.60,'pass','pass','crash_cart_ready','cleared','2026-06-29 09:00:00+05:30','Annual audit — speed and grade errors under 1 pct'),
    ('AIIMS New Delhi Ansari Nagar','CARD-LAB-3','HT-AIM-402','Schiller MT-101','holter_3_channel','2026-06-29','2026-06-29 10:00:00+05:30',
     'connector_corroded',78.00,'severe_wander',null,null,'not_applicable','not_applicable','crash_cart_ready','out_of_service',null,'50 Hz mains hum at 78 uV — corroded connector found'),
    ('KIMS Secunderabad','CARD-LAB-1','HT-KIM-501','Mortara XScribe','tmt_treadmill','2026-06-28','2026-06-28 09:30:00+05:30',
     'all_leads_ok',11.00,'mild_wander',2.80,3.40,'borderline','sluggish_response','defib_battery_low','pending_review',null,'Grade error 3.4 pct borderline; e-stop response 2.1 s sluggish'),
    ('Care Hospitals Banjara Hills','CARD-LAB-2','HT-CAR-601','BPL Dynatrac','tmt_treadmill','2026-06-28','2026-06-28 11:00:00+05:30',
     'all_leads_ok',10.00,'within_limits',1.00,0.70,'pass','pass','crash_cart_ready','cleared','2026-06-28 11:45:00+05:30','Routine audit clean'),
    ('Yashoda Somajiguda Hyderabad','CARD-LAB-1','HT-YSH-701','Philips StressVue','tmt_treadmill','2026-06-27','2026-06-27 08:45:00+05:30',
     'intermittent_dropout',38.00,'mild_wander',1.50,1.20,'pass','pass','crash_cart_ready','conditional_clear','2026-06-27 09:30:00+05:30','V5 lead dropout during stage 3 — cable on watch list'),
    ('St John''s Bengaluru','CARD-LAB-1','HT-STJ-801','GE SEER 1000','holter_3_channel','2026-06-27','2026-06-27 10:00:00+05:30',
     'all_leads_ok',7.50,'within_limits',null,null,'not_applicable','not_applicable','not_checked','cleared','2026-06-27 10:30:00+05:30','Holter fleet spot check clean'),
    ('Rainbow Children''s Hyderabad','CARD-LAB-1','HT-RBW-901','Schiller CS-200','tmt_treadmill','2026-06-26','2026-06-26 09:00:00+05:30',
     'cable_fracture',92.00,'severe_wander',1.10,0.90,'pass','pass','crash_cart_ready','out_of_service',null,'Paediatric cable fracture at yoke — 92 uV artifact'),
    ('Rainbow Children''s Hyderabad','CARD-LAB-1','HT-RBW-902','Mortara Ambulo 2400','ambulatory_bp','2026-06-26','2026-06-26 10:15:00+05:30',
     'all_leads_ok',5.00,'not_measured',null,null,'not_applicable','not_applicable','not_checked','cleared','2026-06-26 10:45:00+05:30','ABP monitor verified — cuff calibration within 2 mmHg')
  ) as q(hosp, lab, tag, model, st, ad, aud, li, noise, drift, spe, gre, sgv, est, dfc, av, cl, nt);

  -- CAPA seed — attach to specific audits by asset tag
  insert into public.holter_tmt_capa_actions_r3206 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('HT-APL-102','lead_integrity_fail','patient_cable_worn','replace_patient_cable','2026-07-08',null,'in_progress','internal_only',18500.00,'Replacement 3-lead patient cable ordered from GE'),
    ('HT-FRT-201','speed_grade_out_of_tolerance','treadmill_belt_worn','recalibrate_speed_grade','2026-07-06',null,'in_progress','nabh_finding',22000.00,'Belt replacement and speed calibration combined in one visit'),
    ('HT-FRT-202','emergency_stop_fail','estop_switch_stuck','replace_estop_switch','2026-07-04','2026-07-03','closed','patient_safety_alert',9500.00,'E-stop switch replaced; defib pads restocked same visit'),
    ('HT-AIM-402','signal_noise_high','mains_earth_leakage','fix_earth_bonding','2026-07-10',null,'verification_pending','iso_13485_deviation',6000.00,'Earth bonding redone — retest scheduled with biomedical team'),
    ('HT-KIM-501','defib_readiness_gap','defib_battery_aged','replace_defib_battery','2026-07-05',null,'escalated','patient_safety_alert',32000.00,'Second low-battery finding this quarter — escalated to admin'),
    ('HT-RBW-901','lead_integrity_fail','patient_cable_worn','replace_patient_cable','2026-06-30',null,'overdue','nabh_finding',15500.00,'Paediatric cable on OEM backorder — closure overdue')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.holter_tmt_r3206 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3206_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.holter_tmt_r3206)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.holter_tmt_r3206 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3206_verdict_rollup() from public, anon;
grant execute on function public.founder_r3206_verdict_rollup() to authenticated;

-- 2) Hospital-level clearance scorecard
create or replace function public.founder_r3206_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  cleared bigint,
  restricted bigint,
  out_of_service bigint,
  lead_faults bigint,
  estop_fails bigint,
  defib_gaps bigint,
  clearance_pct numeric
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
    count(*) filter (where l.audit_verdict = 'cleared')::bigint,
    count(*) filter (where l.audit_verdict = 'restricted_use')::bigint,
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.lead_integrity <> 'all_leads_ok')::bigint,
    count(*) filter (where l.emergency_stop_test in ('fail','sluggish_response'))::bigint,
    count(*) filter (where l.defib_nearby_check in ('defib_missing','defib_battery_low','defib_pads_expired'))::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'cleared')::numeric / nullif(count(*),0), 1)
  from public.holter_tmt_r3206 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3206_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3206_hospital_scorecard() to authenticated;

-- 3) System type × lead integrity matrix
create or replace function public.founder_r3206_system_lead_matrix()
returns table(system_type text, lead_integrity text, audits bigint, cleared bigint, avg_noise_uv numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_type, l.lead_integrity, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'cleared')::bigint,
    round(avg(l.signal_noise_uv), 2)
  from public.holter_tmt_r3206 l
  group by l.system_type, l.lead_integrity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3206_system_lead_matrix() from public, anon;
grant execute on function public.founder_r3206_system_lead_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3206_daily_trend()
returns table(audit_date date, audits bigint, cleared bigint, out_of_service bigint, estop_fails bigint, avg_noise_uv numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'cleared')::bigint,
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.emergency_stop_test in ('fail','sluggish_response'))::bigint,
    round(avg(l.signal_noise_uv), 2)
  from public.holter_tmt_r3206 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3206_daily_trend() from public, anon;
grant execute on function public.founder_r3206_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3206_capa_status_board()
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
  from public.holter_tmt_capa_actions_r3206 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3206_capa_status_board() from public, anon;
grant execute on function public.founder_r3206_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3206_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.holter_tmt_capa_actions_r3206)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.holter_tmt_capa_actions_r3206 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3206_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3206_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3206_regulatory_impact_digest()
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
  from public.holter_tmt_capa_actions_r3206 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3206_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3206_regulatory_impact_digest() to authenticated;

-- 8) High-risk audits queue (top individual concerns)
create or replace function public.founder_r3206_high_risk_audits()
returns table(
  hospital_name text,
  cardiology_lab_code text,
  device_asset_tag text,
  audit_date date,
  audit_verdict text,
  lead_integrity text,
  emergency_stop_test text,
  defib_nearby_check text,
  signal_noise_uv numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.cardiology_lab_code, l.device_asset_tag, l.audit_date,
    l.audit_verdict, l.lead_integrity, l.emergency_stop_test, l.defib_nearby_check, l.signal_noise_uv, l.notes
  from public.holter_tmt_r3206 l
  where l.audit_verdict in ('restricted_use','out_of_service','recalibration_needed','pending_review','conditional_clear')
     or l.lead_integrity <> 'all_leads_ok'
     or l.emergency_stop_test in ('fail','sluggish_response')
     or l.defib_nearby_check in ('defib_missing','defib_battery_low','defib_pads_expired')
     or l.signal_noise_uv > 50
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3206_high_risk_audits() from public, anon;
grant execute on function public.founder_r3206_high_risk_audits() to authenticated;
