-- Round 3202: Customer Hospital Fetal-Monitor (CTG) Transducer & Trace-Quality Audit
-- CTG QA log — monitor model × toco sensitivity × US signal % × paper speed × FHR simulator vs display × alarm limits × belt/strap × trace legibility × CAPA

-- =============================================================================
-- TABLE 1: fetal_monitor_r3202 — individual CTG monitor QA audits
-- =============================================================================
create table if not exists public.fetal_monitor_r3202 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_code text not null,
  monitor_asset_tag text not null,
  monitor_model text not null,
  audit_date date not null,
  audited_at timestamptz not null,
  toco_sensitivity text not null check (toco_sensitivity in (
    'normal','reduced','oversensitive','no_response','intermittent_dropout'
  )),
  us_transducer_signal_pct numeric(5,2),
  us_transducer_condition text not null check (us_transducer_condition in (
    'good','crystal_damage','cable_fault','housing_cracked','gel_port_blocked','replaced_recently'
  )),
  paper_speed_setting text not null check (paper_speed_setting in (
    'one_cm_per_min','two_cm_per_min','three_cm_per_min'
  )),
  paper_speed_deviation_pct numeric(5,2),
  fhr_simulator_bpm int,
  fhr_displayed_bpm int,
  fhr_accuracy_verdict text check (fhr_accuracy_verdict in (
    'within_2_bpm','within_5_bpm','out_of_tolerance','not_tested'
  )),
  alarm_limits_test text not null check (alarm_limits_test in (
    'pass','fail_high_alarm','fail_low_alarm','fail_both','not_run'
  )),
  belt_strap_condition text not null check (belt_strap_condition in (
    'good','worn','frayed','elastic_lost','missing','replaced_during_audit'
  )),
  trace_legibility text not null check (trace_legibility in (
    'crisp','acceptable','faint','patchy','illegible'
  )),
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','fit_with_observations','needs_service','remove_from_service','pending_review','conditional_use'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fetal_monitor_r3202 enable row level security;

create index if not exists idx_fetal_monitor_r3202_org on public.fetal_monitor_r3202(organization_id);
create index if not exists idx_fetal_monitor_r3202_date on public.fetal_monitor_r3202(audit_date);
create index if not exists idx_fetal_monitor_r3202_verdict on public.fetal_monitor_r3202(audit_verdict);

-- =============================================================================
-- TABLE 2: fetal_monitor_capa_actions_r3202 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.fetal_monitor_capa_actions_r3202 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.fetal_monitor_r3202(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'toco_no_response','us_signal_weak','paper_speed_drift','fhr_out_of_tolerance',
    'alarm_limits_fail','belt_strap_degraded','trace_illegible','printer_head_worn',
    'cable_damage','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_crystal_ageing','cable_flex_fatigue','printer_head_wear','roller_slippage',
    'gel_ingress','strap_elastic_fatigue','alarm_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_us_transducer','replace_toco_transducer','replace_transducer_cable',
    'replace_printer_head','recalibrate_paper_drive','reconfigure_alarm_limits',
    'replace_belt_straps','retrain_staff','schedule_amc_visit','none_required'
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

alter table public.fetal_monitor_capa_actions_r3202 enable row level security;

create index if not exists idx_fetal_monitor_capa_r3202_audit on public.fetal_monitor_capa_actions_r3202(audit_id);
create index if not exists idx_fetal_monitor_capa_r3202_status on public.fetal_monitor_capa_actions_r3202(capa_status);

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

  -- 14 CTG audit rows
  insert into public.fetal_monitor_r3202 (
    organization_id, hospital_name, ward_code, monitor_asset_tag, monitor_model,
    audit_date, audited_at,
    toco_sensitivity, us_transducer_signal_pct, us_transducer_condition,
    paper_speed_setting, paper_speed_deviation_pct,
    fhr_simulator_bpm, fhr_displayed_bpm, fhr_accuracy_verdict,
    alarm_limits_test, belt_strap_condition, trace_legibility,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.model,
    q.ad::date, q.ats::timestamptz,
    q.toco, q.sig, q.usc,
    q.pss, q.psd,
    q.sim, q.disp, q.facc,
    q.alarm, q.belt, q.trace,
    q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','LDR-1','FM-APL-101','Philips Avalon FM30','2026-07-10','2026-07-10 09:15:00+05:30',
     'normal',96.00,'good','one_cm_per_min',0.80,140,141,'within_2_bpm','pass','good','crisp','fit_for_use','Annual QA — all parameters nominal'),
    ('Apollo Hyderabad Jubilee Hills','LDR-2','FM-APL-102','Philips Avalon FM20','2026-07-10','2026-07-10 10:05:00+05:30',
     'reduced',78.50,'cable_fault','one_cm_per_min',1.20,140,143,'within_5_bpm','pass','worn','acceptable','fit_with_observations','Toco pickup weak on palpation test — cable suspected'),
    ('Fortis Bannerghatta Bengaluru','LW-1','FM-FRT-201','GE Corometrics 170','2026-07-09','2026-07-09 08:40:00+05:30',
     'no_response',88.00,'good','three_cm_per_min',0.50,120,120,'within_2_bpm','pass','frayed','acceptable','needs_service','Toco channel flat — no contraction trace recorded'),
    ('Fortis Bannerghatta Bengaluru','LW-2','FM-FRT-202','GE Corometrics 170','2026-07-09','2026-07-09 09:30:00+05:30',
     'normal',55.00,'crystal_damage','three_cm_per_min',0.70,150,158,'out_of_tolerance','fail_high_alarm','good','patchy','remove_from_service','US signal 55% with dropout; FHR reads +8 bpm; high alarm silent'),
    ('Manipal Whitefield Bengaluru','LDR-3','FM-MNP-301','Edan F9','2026-07-08','2026-07-08 11:00:00+05:30',
     'normal',91.00,'good','one_cm_per_min',4.60,130,131,'within_2_bpm','pass','good','faint','needs_service','Paper running slow 4.6% — trace compressed; printer head faint'),
    ('Manipal Whitefield Bengaluru','ANC-1','FM-MNP-302','Edan F9','2026-07-08','2026-07-08 12:10:00+05:30',
     'oversensitive',94.00,'good','one_cm_per_min',0.90,110,110,'within_2_bpm','pass','replaced_during_audit','crisp','fit_with_observations','Toco baseline jittery; belts replaced on the spot'),
    ('AIIMS New Delhi Ansari Nagar','LR-9','FM-AIM-401','BPL FM 9852','2026-07-07','2026-07-07 07:45:00+05:30',
     'normal',97.50,'good','one_cm_per_min',0.40,210,211,'within_2_bpm','pass','good','crisp','fit_for_use','Tachycardia simulation tracked correctly'),
    ('AIIMS New Delhi Ansari Nagar','LR-10','FM-AIM-402','BPL FM 9852','2026-07-07','2026-07-07 08:50:00+05:30',
     'intermittent_dropout',82.00,'gel_port_blocked','two_cm_per_min',1.10,80,84,'within_5_bpm','fail_low_alarm','worn','acceptable','conditional_use','Bradycardia low alarm delayed 12 s; use with bedside watch'),
    ('KIMS Secunderabad','LDR-1','FM-KIM-501','Bionet FC-1400','2026-07-06','2026-07-06 10:20:00+05:30',
     'normal',93.00,'good','one_cm_per_min',0.60,140,140,'within_2_bpm','pass','good','crisp','fit_for_use','Clean pass on all channels'),
    ('KIMS Secunderabad','LDR-2','FM-KIM-502','Bionet FC-1400','2026-07-06','2026-07-06 11:15:00+05:30',
     'reduced',68.00,'housing_cracked','one_cm_per_min',2.30,140,149,'out_of_tolerance','fail_both','elastic_lost','illegible','remove_from_service','Multiple failures — condemned pending replacement'),
    ('Care Hospitals Banjara Hills','MW-3','FM-CAR-601','Contec CMS800G','2026-07-05','2026-07-05 09:00:00+05:30',
     'normal',90.00,'good','two_cm_per_min',0.90,130,132,'within_2_bpm','pass','good','acceptable','fit_for_use','Budget unit performing within spec'),
    ('Yashoda Somajiguda Hyderabad','LDR-4','FM-YSH-701','Philips Avalon FM30','2026-07-04','2026-07-04 08:30:00+05:30',
     'normal',89.50,'replaced_recently','one_cm_per_min',0.50,140,141,'within_2_bpm','pass','good','crisp','fit_for_use','New US transducer fitted last month — verified'),
    ('St John''s Bengaluru','LW-5','FM-STJ-801','Huntleigh Sonicaid Team 3','2026-07-03','2026-07-03 10:45:00+05:30',
     'normal',86.00,'good','one_cm_per_min',1.00,140,144,'within_5_bpm','not_run','worn','faint','pending_review','Alarm test skipped — simulator battery dead; retest booked'),
    ('Rainbow Children''s Hyderabad','LDR-2','FM-RBW-901','Edan F9','2026-07-02','2026-07-02 09:40:00+05:30',
     'normal',95.00,'good','one_cm_per_min',0.70,140,140,'within_2_bpm','pass','good','crisp','fit_for_use','Perinatal unit QA pass')
  ) as q(hosp, ward, tag, model, ad, ats, toco, sig, usc, pss, psd, sim, disp, facc, alarm, belt, trace, verdict, nt);

  -- CAPA seed — attach to specific monitors by asset tag
  insert into public.fetal_monitor_capa_actions_r3202 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('FM-FRT-201','toco_no_response','transducer_crystal_ageing','replace_toco_transducer','2026-07-16',null,'in_progress','patient_safety_alert',22000.00,'Toco transducer replacement in transit from GE'),
    ('FM-FRT-202','us_signal_weak','transducer_crystal_ageing','replace_us_transducer','2026-07-15',null,'escalated','patient_safety_alert',48000.00,'US crystal damage plus silent high alarm — unit pulled from labour ward'),
    ('FM-FRT-202','alarm_limits_fail','alarm_config_error','reconfigure_alarm_limits','2026-07-12','2026-07-11','closed','nabh_finding',0.00,'High alarm limit had been set to 200 bpm; reset to 160'),
    ('FM-MNP-301','paper_speed_drift','roller_slippage','recalibrate_paper_drive','2026-07-14','2026-07-13','closed','iso_13485_deviation',3500.00,'Drive roller cleaned and recalibrated to 1 cm/min'),
    ('FM-KIM-502','trace_illegible','printer_head_wear','replace_printer_head','2026-07-20',null,'open','cdsco_notifiable',12500.00,'Unit condemned pending printer head and strap kit'),
    ('FM-AIM-402','alarm_limits_fail','pending_investigation','schedule_amc_visit','2026-07-19',null,'verification_pending','patient_safety_alert',6000.00,'Low alarm latency retest after AMC service visit'),
    ('FM-APL-102','cable_damage','cable_flex_fatigue','replace_transducer_cable','2026-07-22',null,'open','internal_only',8500.00,'Toco cable intermittent at connector strain relief'),
    ('FM-STJ-801','preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-07-08',null,'overdue','nabh_finding',15000.00,'Simulator battery and annual PM both overdue')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.fetal_monitor_r3202 e
    on e.organization_id = v_org_id and e.monitor_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3202_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fetal_monitor_r3202)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fetal_monitor_r3202 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3202_verdict_rollup() from public, anon;
grant execute on function public.founder_r3202_verdict_rollup() to authenticated;

-- 2) Hospital-level CTG fleet scorecard
create or replace function public.founder_r3202_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  needs_service bigint,
  removed bigint,
  alarm_fails bigint,
  avg_us_signal_pct numeric,
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
    count(*) filter (where l.audit_verdict = 'needs_service')::bigint,
    count(*) filter (where l.audit_verdict = 'remove_from_service')::bigint,
    count(*) filter (where l.alarm_limits_test in ('fail_high_alarm','fail_low_alarm','fail_both'))::bigint,
    round(avg(l.us_transducer_signal_pct), 1),
    round(100.0 * count(*) filter (where l.audit_verdict in ('fit_for_use','fit_with_observations'))::numeric / nullif(count(*),0), 1)
  from public.fetal_monitor_r3202 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3202_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3202_hospital_scorecard() to authenticated;

-- 3) Monitor model × trace legibility matrix
create or replace function public.founder_r3202_model_trace_matrix()
returns table(monitor_model text, trace_legibility text, audits bigint, fit_for_use bigint, avg_us_signal_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.monitor_model, l.trace_legibility, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.us_transducer_signal_pct), 1)
  from public.fetal_monitor_r3202 l
  group by l.monitor_model, l.trace_legibility
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3202_model_trace_matrix() from public, anon;
grant execute on function public.founder_r3202_model_trace_matrix() to authenticated;

-- 4) Daily audit trend — alarm & FHR accuracy
create or replace function public.founder_r3202_daily_trend()
returns table(audit_date date, audits bigint, alarm_pass bigint, alarm_fail bigint, fhr_out_of_tolerance bigint, avg_paper_speed_dev_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.alarm_limits_test = 'pass')::bigint,
    count(*) filter (where l.alarm_limits_test in ('fail_high_alarm','fail_low_alarm','fail_both'))::bigint,
    count(*) filter (where l.fhr_accuracy_verdict = 'out_of_tolerance')::bigint,
    round(avg(l.paper_speed_deviation_pct), 2)
  from public.fetal_monitor_r3202 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3202_daily_trend() from public, anon;
grant execute on function public.founder_r3202_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3202_capa_status_board()
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
  from public.fetal_monitor_capa_actions_r3202 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3202_capa_status_board() from public, anon;
grant execute on function public.founder_r3202_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3202_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fetal_monitor_capa_actions_r3202)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fetal_monitor_capa_actions_r3202 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3202_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3202_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3202_regulatory_impact_digest()
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
  from public.fetal_monitor_capa_actions_r3202 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3202_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3202_regulatory_impact_digest() to authenticated;

-- 8) High-risk monitors queue (top individual concerns)
create or replace function public.founder_r3202_high_risk_monitors()
returns table(
  hospital_name text,
  ward_code text,
  monitor_asset_tag text,
  monitor_model text,
  audit_date date,
  audit_verdict text,
  toco_sensitivity text,
  alarm_limits_test text,
  trace_legibility text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_code, l.monitor_asset_tag, l.monitor_model, l.audit_date,
    l.audit_verdict, l.toco_sensitivity, l.alarm_limits_test, l.trace_legibility, l.notes
  from public.fetal_monitor_r3202 l
  where l.audit_verdict in ('needs_service','remove_from_service','pending_review','conditional_use')
     or l.toco_sensitivity in ('no_response','intermittent_dropout')
     or l.alarm_limits_test in ('fail_high_alarm','fail_low_alarm','fail_both')
     or l.fhr_accuracy_verdict = 'out_of_tolerance'
     or l.trace_legibility in ('patchy','illegible')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3202_high_risk_monitors() from public, anon;
grant execute on function public.founder_r3202_high_risk_monitors() to authenticated;
