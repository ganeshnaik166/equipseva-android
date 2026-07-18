-- Round 3218: Customer Hospital ECG-Machine 12-Lead Signal-Quality & Filter Audit
-- ECG QA log — machine model × lead-off detection × 1mV calibration pulse × paper speed 25/50mm × filters (AC/muscle/drift) × signal noise × interpretation module × cable condition × CAPA

-- =============================================================================
-- TABLE 1: ecg_machine_r3218 — individual 12-lead ECG machine QA audits
-- =============================================================================
create table if not exists public.ecg_machine_r3218 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  department_code text not null,
  ecg_asset_tag text not null,
  machine_model text not null,
  audit_date date not null,
  audited_at timestamptz not null,
  lead_off_detection text not null check (lead_off_detection in (
    'all_leads_detected','ra_lead_fault','la_lead_fault','ll_lead_fault',
    'chest_lead_fault','multiple_lead_fault','intermittent_dropout','not_tested'
  )),
  calibration_pulse_result text not null check (calibration_pulse_result in (
    'within_2_percent','within_5_percent','out_of_tolerance','no_pulse_output','not_tested'
  )),
  calibration_pulse_mv numeric(5,3),
  paper_speed_25_result text not null check (paper_speed_25_result in (
    'accurate','fast_out_of_spec','slow_out_of_spec','jitter_variation','not_tested'
  )),
  paper_speed_50_result text not null check (paper_speed_50_result in (
    'accurate','fast_out_of_spec','slow_out_of_spec','jitter_variation','not_tested'
  )),
  paper_speed_error_pct numeric(5,2),
  ac_filter_setting text not null check (ac_filter_setting in (
    'on_50hz','on_60hz','off','auto_detect'
  )),
  muscle_filter_setting text not null check (muscle_filter_setting in (
    'on_25hz','on_35hz','off'
  )),
  drift_filter_setting text not null check (drift_filter_setting in (
    'on_0_05hz','on_0_5hz','off'
  )),
  signal_noise_level text not null check (signal_noise_level in (
    'clean','minor_artifact','moderate_noise','severe_noise','unreadable'
  )),
  noise_microvolts numeric(7,2),
  interpretation_module_version text,
  interpretation_module_status text not null check (interpretation_module_status in (
    'current','update_available','obsolete','not_installed'
  )),
  cable_condition text not null check (cable_condition in (
    'good','worn_insulation','broken_clip','intermittent_core','frayed_shield','replaced_during_audit'
  )),
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','restricted_use','recalibration_required','out_of_service','condemn_recommended','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ecg_machine_r3218 enable row level security;

create index if not exists idx_ecg_machine_r3218_org on public.ecg_machine_r3218(organization_id);
create index if not exists idx_ecg_machine_r3218_date on public.ecg_machine_r3218(audit_date);
create index if not exists idx_ecg_machine_r3218_verdict on public.ecg_machine_r3218(audit_verdict);

-- =============================================================================
-- TABLE 2: ecg_machine_capa_actions_r3218 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ecg_machine_capa_actions_r3218 (
  id uuid primary key default gen_random_uuid(),
  ecg_machine_id uuid not null references public.ecg_machine_r3218(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'calibration_pulse_fail','paper_speed_deviation','lead_off_fault','excessive_noise',
    'filter_misconfiguration','cable_damage','interpretation_module_obsolete','operator_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'cable_wear','electrode_clip_corrosion','earthing_fault','motor_roller_wear',
    'firmware_outdated','sensor_drift','ambient_emi_interference',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_patient_cable','replace_lead_clips','recalibrate_amplifier','service_paper_drive',
    'upgrade_interpretation_firmware','fix_earthing_bond','shield_emi_source',
    'retrain_operator','schedule_amc_visit','initiate_condemnation','none_required'
  )),
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

alter table public.ecg_machine_capa_actions_r3218 enable row level security;

create index if not exists idx_ecg_capa_r3218_machine on public.ecg_machine_capa_actions_r3218(ecg_machine_id);
create index if not exists idx_ecg_capa_r3218_status on public.ecg_machine_capa_actions_r3218(capa_status);

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

  -- 14 ECG machine audit rows
  insert into public.ecg_machine_r3218 (
    organization_id, hospital_name, department_code, ecg_asset_tag, machine_model,
    audit_date, audited_at,
    lead_off_detection, calibration_pulse_result, calibration_pulse_mv,
    paper_speed_25_result, paper_speed_50_result, paper_speed_error_pct,
    ac_filter_setting, muscle_filter_setting, drift_filter_setting,
    signal_noise_level, noise_microvolts, interpretation_module_version, interpretation_module_status,
    cable_condition, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.dept, q.tag, q.model,
    q.ad::date, q.aat::timestamptz,
    q.lod, q.cpr, q.cpm,
    q.ps25, q.ps50, q.pse,
    q.acf, q.mf, q.df,
    q.snl, q.nuv, q.imv, q.ims,
    q.cc, q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','CARD-ICU','ECG-APL-101','GE MAC 2000','2026-07-10','2026-07-10 09:15:00+05:30',
     'all_leads_detected','within_2_percent',1.002,'accurate','accurate',0.40,
     'on_50hz','off','on_0_05hz','clean',8.50,'Marquette 12SL v243','current',
     'good','fit_for_use','Annual QA — all parameters nominal'),
    ('Apollo Hyderabad Jubilee Hills','EMERGENCY','ECG-APL-102','GE MAC 600','2026-07-10','2026-07-10 10:05:00+05:30',
     'ra_lead_fault','within_2_percent',0.998,'accurate','accurate',0.60,
     'on_50hz','on_35hz','on_0_05hz','minor_artifact',22.00,'Marquette 12SL v239','update_available',
     'worn_insulation','restricted_use','RA lead-off intermittent — cable insulation worn at yoke'),
    ('Fortis Bannerghatta Bengaluru','CATH-LAB','ECG-FRT-201','Philips PageWriter TC30','2026-07-09','2026-07-09 08:30:00+05:30',
     'all_leads_detected','out_of_tolerance',1.087,'accurate','slow_out_of_spec',3.80,
     'on_50hz','off','on_0_5hz','moderate_noise',46.00,'Philips DXL v5.2','current',
     'good','recalibration_required','Cal pulse 8.7 percent high; 50mm sweep running slow'),
    ('Fortis Bannerghatta Bengaluru','OPD-CARDIO','ECG-FRT-202','BPL Cardiart 9108','2026-07-09','2026-07-09 09:40:00+05:30',
     'multiple_lead_fault','not_tested',null,'not_tested','not_tested',null,
     'off','off','off','unreadable',180.00,'BPL Interp v1.4','obsolete',
     'broken_clip','out_of_service','Three chest clips broken; all filters off; trace unreadable'),
    ('Manipal Whitefield Bengaluru','ICU-2','ECG-MNP-301','Schiller Cardiovit AT-102','2026-07-08','2026-07-08 11:00:00+05:30',
     'all_leads_detected','within_5_percent',1.034,'accurate','accurate',0.90,
     'on_50hz','on_25hz','on_0_05hz','clean',10.20,'Schiller ETM v4.1','current',
     'good','fit_for_use','Within tolerance; next QA due Jan 2027'),
    ('Manipal Whitefield Bengaluru','WARD-4B','ECG-MNP-302','BPL Cardiart 6208','2026-07-08','2026-07-08 12:10:00+05:30',
     'll_lead_fault','within_5_percent',0.962,'jitter_variation','accurate',2.10,
     'on_50hz','on_35hz','on_0_5hz','moderate_noise',58.00,'BPL Interp v2.0','update_available',
     'intermittent_core','restricted_use','25mm jitter from roller wear; LL clip corroded'),
    ('AIIMS New Delhi Ansari Nagar','CARDIOLOGY-OPD','ECG-AIM-401','GE MAC 5500 HD','2026-07-07','2026-07-07 08:00:00+05:30',
     'all_leads_detected','within_2_percent',1.005,'accurate','accurate',0.30,
     'on_50hz','off','on_0_05hz','clean',7.80,'Marquette 12SL v243','current',
     'good','fit_for_use','Reference machine for teaching block'),
    ('AIIMS New Delhi Ansari Nagar','CASUALTY','ECG-AIM-402','Philips PageWriter TC20','2026-07-07','2026-07-07 09:20:00+05:30',
     'chest_lead_fault','within_2_percent',1.011,'accurate','accurate',0.70,
     'on_60hz','on_35hz','on_0_05hz','severe_noise',95.00,'Philips DXL v5.0','update_available',
     'frayed_shield','restricted_use','AC filter left at 60Hz — 50Hz mains hum on baseline; V3 dropout'),
    ('KIMS Secunderabad','ICCU','ECG-KIM-501','Schiller Cardiovit FT-1','2026-07-06','2026-07-06 10:30:00+05:30',
     'all_leads_detected','no_pulse_output',null,'accurate','accurate',0.80,
     'on_50hz','on_25hz','on_0_05hz','minor_artifact',18.00,'Schiller ETM v3.8','obsolete',
     'good','recalibration_required','1mV cal key produces no pulse — amplifier board suspected'),
    ('KIMS Secunderabad','PRE-OP','ECG-KIM-502','BPL Cardiart 8108','2026-07-06','2026-07-06 11:45:00+05:30',
     'intermittent_dropout','within_5_percent',1.041,'slow_out_of_spec','slow_out_of_spec',4.60,
     'on_50hz','on_35hz','on_0_5hz','moderate_noise',52.00,'BPL Interp v1.9','update_available',
     'worn_insulation','recalibration_required','Both paper speeds about 4.6 percent slow; drive motor service due'),
    ('Care Hospitals Banjara Hills','DIALYSIS','ECG-CAR-601','Nihon Kohden ECG-2150','2026-07-05','2026-07-05 09:00:00+05:30',
     'all_leads_detected','within_2_percent',0.996,'accurate','accurate',0.50,
     'on_50hz','off','on_0_05hz','minor_artifact',24.00,'NK ECAPS-12C v7','current',
     'good','fit_for_use','Minor EMI from adjacent dialysis pumps; acceptable'),
    ('Yashoda Somajiguda Hyderabad','CCU','ECG-YSH-701','GE MAC 1200 ST','2026-07-04','2026-07-04 08:45:00+05:30',
     'ra_lead_fault','out_of_tolerance',0.882,'fast_out_of_spec','accurate',3.20,
     'on_50hz','on_35hz','off','severe_noise',110.00,'Marquette 12SL v221','obsolete',
     'frayed_shield','condemn_recommended','2009 unit: cal 11.8 percent low, baseline wander, firmware EOL'),
    ('St John''s Bengaluru','MEDICINE-OPD','ECG-STJ-801','Philips Efficia ECG100','2026-07-03','2026-07-03 10:15:00+05:30',
     'all_leads_detected','within_2_percent',1.008,'accurate','accurate',0.60,
     'on_50hz','on_25hz','on_0_05hz','clean',9.40,'Philips DXL v5.2','current',
     'good','fit_for_use','New unit commissioning QA passed'),
    ('Rainbow Children''s Hyderabad','PICU','ECG-RBW-901','Schiller Cardiovit AT-101','2026-07-02','2026-07-02 11:30:00+05:30',
     'la_lead_fault','within_5_percent',1.048,'accurate','not_tested',1.10,
     'on_50hz','on_25hz','on_0_5hz','moderate_noise',44.00,'Schiller ETM v4.0','current',
     'broken_clip','pending_review','Paediatric clip set damaged; 50mm test skipped pending clips')
  ) as q(hosp, dept, tag, model, ad, aat, lod, cpr, cpm, ps25, ps50, pse, acf, mf, df, snl, nuv, imv, ims, cc, vd, nt);

  -- CAPA seed — attach to specific machines by asset tag
  insert into public.ecg_machine_capa_actions_r3218 (
    ecg_machine_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('ECG-FRT-201','calibration_pulse_fail','sensor_drift','recalibrate_amplifier','2026-07-14',null,'in_progress','iso_13485_deviation',6500.00,'Philips service engineer visit booked'),
    ('ECG-FRT-202','cable_damage','electrode_clip_corrosion','replace_patient_cable','2026-07-16',null,'escalated','patient_safety_alert',9200.00,'Machine tagged out of service; loaner unit issued'),
    ('ECG-KIM-501','calibration_pulse_fail','pending_investigation','recalibrate_amplifier','2026-07-15',null,'open','nabh_finding',14000.00,'No 1mV output — amplifier board diagnostics pending'),
    ('ECG-KIM-502','paper_speed_deviation','motor_roller_wear','service_paper_drive','2026-07-12','2026-07-11','closed','internal_only',4800.00,'Drive roller replaced; both speeds within 1 percent'),
    ('ECG-YSH-701','excessive_noise','firmware_outdated','initiate_condemnation','2026-07-20',null,'verification_pending','cdsco_notifiable',0.00,'Condemnation memo raised; awaiting biomedical committee sign-off'),
    ('ECG-AIM-402','filter_misconfiguration','operator_setup_error','retrain_operator','2026-07-09','2026-07-08','closed','internal_only',0.00,'ECG techs retrained on 50Hz AC filter default'),
    ('ECG-MNP-302','lead_off_fault','electrode_clip_corrosion','replace_lead_clips','2026-07-13',null,'in_progress','none',1800.00,'Clip set on order from BPL distributor'),
    ('ECG-APL-102','preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-07-05',null,'overdue','nabh_finding',15000.00,'Quarterly PM overdue 5 days — flagged for NABH readiness')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.ecg_machine_r3218 e
    on e.organization_id = v_org_id and e.ecg_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3218_verdict_rollup()
returns table(audit_verdict text, machines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ecg_machine_r3218)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ecg_machine_r3218 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3218_verdict_rollup() from public, anon;
grant execute on function public.founder_r3218_verdict_rollup() to authenticated;

-- 2) Hospital-level QA scorecard
create or replace function public.founder_r3218_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  restricted bigint,
  out_of_service bigint,
  cal_fail bigint,
  severe_noise bigint,
  avg_speed_error_pct numeric,
  fit_pct numeric
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
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'restricted_use')::bigint,
    count(*) filter (where l.audit_verdict in ('out_of_service','condemn_recommended'))::bigint,
    count(*) filter (where l.calibration_pulse_result in ('out_of_tolerance','no_pulse_output'))::bigint,
    count(*) filter (where l.signal_noise_level in ('severe_noise','unreadable'))::bigint,
    round(avg(l.paper_speed_error_pct), 2),
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.ecg_machine_r3218 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3218_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3218_hospital_scorecard() to authenticated;

-- 3) Signal-noise × AC-filter matrix
create or replace function public.founder_r3218_noise_filter_matrix()
returns table(signal_noise_level text, ac_filter_setting text, machines bigint, fit_for_use bigint, avg_noise_microvolts numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.signal_noise_level, l.ac_filter_setting, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.noise_microvolts), 2)
  from public.ecg_machine_r3218 l
  group by l.signal_noise_level, l.ac_filter_setting
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3218_noise_filter_matrix() from public, anon;
grant execute on function public.founder_r3218_noise_filter_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3218_daily_audit_trend()
returns table(audit_date date, audits bigint, fit_for_use bigint, cal_fail bigint, severe_noise bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.calibration_pulse_result in ('out_of_tolerance','no_pulse_output'))::bigint,
    count(*) filter (where l.signal_noise_level in ('severe_noise','unreadable'))::bigint
  from public.ecg_machine_r3218 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3218_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3218_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3218_capa_status_board()
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
  from public.ecg_machine_capa_actions_r3218 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3218_capa_status_board() from public, anon;
grant execute on function public.founder_r3218_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3218_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ecg_machine_capa_actions_r3218)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ecg_machine_capa_actions_r3218 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3218_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3218_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3218_regulatory_impact_digest()
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
  from public.ecg_machine_capa_actions_r3218 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3218_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3218_regulatory_impact_digest() to authenticated;

-- 8) High-risk machines queue (top individual concerns)
create or replace function public.founder_r3218_high_risk_machines()
returns table(
  hospital_name text,
  department_code text,
  ecg_asset_tag text,
  machine_model text,
  audit_date date,
  audit_verdict text,
  calibration_pulse_result text,
  signal_noise_level text,
  cable_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.department_code, l.ecg_asset_tag, l.machine_model, l.audit_date,
    l.audit_verdict, l.calibration_pulse_result, l.signal_noise_level, l.cable_condition, l.notes
  from public.ecg_machine_r3218 l
  where l.audit_verdict in ('restricted_use','recalibration_required','out_of_service','condemn_recommended','pending_review')
     or l.calibration_pulse_result in ('out_of_tolerance','no_pulse_output')
     or l.signal_noise_level in ('severe_noise','unreadable')
     or l.lead_off_detection in ('multiple_lead_fault','intermittent_dropout')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3218_high_risk_machines() from public, anon;
grant execute on function public.founder_r3218_high_risk_machines() to authenticated;
