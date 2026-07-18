-- Round 3142: Customer Hospital ICU Ventilator Preventive-Maintenance & Alarm-Test Compliance Audit
-- Ventilator PM log — ventilation mode × tidal-volume/PEEP/FiO2 accuracy × leak test × alarm battery × HME filter × apnoea/disconnect alarm test × verdict × CAPA

-- =============================================================================
-- TABLE 1: ventilator_pm_r3142 — individual ventilator PM / alarm-test runs
-- =============================================================================
create table if not exists public.ventilator_pm_r3142 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  icu_unit_code text not null,
  ventilator_asset_tag text not null,
  ventilator_model text not null,
  pm_number int not null,
  pm_date date not null,
  pm_started_at timestamptz not null,
  pm_ended_at timestamptz,
  ventilation_mode_tested text not null check (ventilation_mode_tested in (
    'volume_control_ac','pressure_control_ac','simv_vc','simv_pc',
    'pressure_support','cpap','aprv','niv_bilevel','high_flow_nasal'
  )),
  tidal_volume_set_ml int,
  tidal_volume_measured_ml int,
  tidal_volume_accuracy_pct numeric(5,2),
  tidal_volume_verdict text not null check (tidal_volume_verdict in (
    'within_tolerance','minor_deviation','out_of_tolerance','not_tested'
  )),
  peep_set_cmh2o numeric(4,1),
  peep_measured_cmh2o numeric(4,1),
  peep_verdict text not null check (peep_verdict in (
    'within_tolerance','minor_deviation','out_of_tolerance','not_tested'
  )),
  fio2_set_pct numeric(5,2),
  fio2_measured_pct numeric(5,2),
  fio2_verdict text not null check (fio2_verdict in (
    'within_tolerance','minor_deviation','out_of_tolerance','not_tested'
  )),
  leak_test_result text not null check (leak_test_result in (
    'pass','fail','borderline','not_run'
  )),
  alarm_battery_result text not null check (alarm_battery_result in (
    'pass','fail','depleted','not_tested'
  )),
  hme_filter_status text not null check (hme_filter_status in (
    'replaced','ok','overdue','not_applicable'
  )),
  apnoea_alarm_test text not null check (apnoea_alarm_test in (
    'pass','fail','not_tested'
  )),
  disconnect_alarm_test text not null check (disconnect_alarm_test in (
    'pass','fail','not_tested'
  )),
  oxygen_sensor_status text not null check (oxygen_sensor_status in (
    'ok','calibrated','replaced','failed','not_applicable'
  )),
  technician_profile_id uuid references public.profiles(id) on delete set null,
  pm_verdict text not null check (pm_verdict in (
    'passed','conditional_pass','failed','quarantined','recall_needed','pending_review'
  )),
  returned_to_service_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ventilator_pm_r3142 enable row level security;

create index if not exists idx_ventilator_pm_r3142_org on public.ventilator_pm_r3142(organization_id);
create index if not exists idx_ventilator_pm_r3142_date on public.ventilator_pm_r3142(pm_date);
create index if not exists idx_ventilator_pm_r3142_verdict on public.ventilator_pm_r3142(pm_verdict);

-- =============================================================================
-- TABLE 2: ventilator_pm_capa_actions_r3142 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ventilator_pm_capa_actions_r3142 (
  id uuid primary key default gen_random_uuid(),
  pm_log_id uuid not null references public.ventilator_pm_r3142(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'tidal_volume_out_of_tolerance','peep_out_of_tolerance','fio2_out_of_tolerance',
    'leak_detected','alarm_battery_fail','apnoea_alarm_fail','disconnect_alarm_fail',
    'oxygen_sensor_fail','hme_filter_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'flow_sensor_drift','oxygen_sensor_expired','expiratory_valve_worn',
    'patient_circuit_leak','battery_end_of_life','pcb_alarm_fault',
    'calibration_overdue','filter_backlog','software_bug','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_flow_sensor','replace_oxygen_sensor','replace_expiratory_valve',
    'replace_patient_circuit','replace_battery_pack','recalibrate_ventilator',
    'replace_hme_filter','firmware_update','retrain_operator','schedule_amc_visit','none_required'
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

alter table public.ventilator_pm_capa_actions_r3142 enable row level security;

create index if not exists idx_ventilator_pm_capa_r3142_pm on public.ventilator_pm_capa_actions_r3142(pm_log_id);
create index if not exists idx_ventilator_pm_capa_r3142_status on public.ventilator_pm_capa_actions_r3142(capa_status);

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

  -- 13 ventilator PM rows
  insert into public.ventilator_pm_r3142 (
    organization_id, hospital_name, icu_unit_code, ventilator_asset_tag, ventilator_model,
    pm_number, pm_date, pm_started_at, pm_ended_at,
    ventilation_mode_tested, tidal_volume_set_ml, tidal_volume_measured_ml, tidal_volume_accuracy_pct, tidal_volume_verdict,
    peep_set_cmh2o, peep_measured_cmh2o, peep_verdict,
    fio2_set_pct, fio2_measured_pct, fio2_verdict,
    leak_test_result, alarm_battery_result, hme_filter_status,
    apnoea_alarm_test, disconnect_alarm_test, oxygen_sensor_status,
    pm_verdict, returned_to_service_at, notes
  )
  select v_org_id, q.hosp, q.icu, q.tag, q.model,
    q.pn, q.pd::date, q.ps::timestamptz, q.pe::timestamptz,
    q.mode, q.tvs, q.tvm, q.tva, q.tvv,
    q.pes, q.pem, q.pev,
    q.fis, q.fim, q.fiv,
    q.leak, q.alarm, q.hme,
    q.apn, q.disc, q.o2,
    q.verdict, q.rts::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-1','VN-APL-101','Hamilton C6',1,'2026-07-14','2026-07-14 08:00:00+05:30','2026-07-14 09:10:00+05:30',
     'volume_control_ac',450,447,99.33,'within_tolerance',5.0,5.1,'within_tolerance',40.00,40.50,'within_tolerance',
     'pass','pass','replaced','pass','pass','ok','passed','2026-07-14 09:30:00+05:30','Routine quarterly PM all within tolerance'),
    ('Apollo Hyderabad Jubilee Hills','ICU-2','VN-APL-102','Drager Evita V500',7,'2026-07-14','2026-07-14 10:00:00+05:30','2026-07-14 11:00:00+05:30',
     'simv_vc',500,491,98.20,'within_tolerance',8.0,8.2,'within_tolerance',50.00,50.80,'within_tolerance',
     'pass','pass','overdue','pass','pass','calibrated','conditional_pass','2026-07-14 11:20:00+05:30','HME filter overdue — quarterly PM backlog flagged'),
    ('Fortis Bannerghatta Bengaluru','ICU-3','VN-FRT-201','Maquet Servo-i',12,'2026-07-13','2026-07-13 07:30:00+05:30','2026-07-13 08:50:00+05:30',
     'pressure_control_ac',420,381,90.71,'out_of_tolerance',6.0,6.2,'within_tolerance',60.00,61.10,'within_tolerance',
     'pass','pass','ok','pass','pass','ok','failed',null,'Delivered TV 9% low — flow sensor drift suspected'),
    ('Fortis Bannerghatta Bengaluru','ICU-1','VN-FRT-202','Hamilton G5',5,'2026-07-13','2026-07-13 09:10:00+05:30','2026-07-13 10:15:00+05:30',
     'pressure_support',400,398,99.50,'within_tolerance',5.0,5.0,'within_tolerance',35.00,35.20,'within_tolerance',
     'pass','pass','replaced','pass','pass','ok','passed','2026-07-13 10:35:00+05:30','Post flow-sensor swap verification cycle'),
    ('Manipal Whitefield Bengaluru','ICU-2','VN-MNP-301','Drager Savina 300',20,'2026-07-12','2026-07-12 08:20:00+05:30','2026-07-12 09:40:00+05:30',
     'simv_pc',480,472,98.33,'within_tolerance',7.0,7.1,'within_tolerance',55.00,55.60,'within_tolerance',
     'pass','pass','ok','fail','pass','ok','recall_needed',null,'Apnoea alarm did not annunciate — alarm PCB fault, unit withdrawn'),
    ('AIIMS New Delhi Ansari Nagar','ICU-4','VN-AIM-401','Puritan Bennett 980',33,'2026-07-12','2026-07-12 06:15:00+05:30','2026-07-12 07:20:00+05:30',
     'volume_control_ac',500,496,99.20,'within_tolerance',8.0,8.1,'within_tolerance',60.00,60.90,'within_tolerance',
     'pass','fail','ok','pass','pass','ok','quarantined',null,'Backup battery failed load test — held pending replacement'),
    ('AIIMS New Delhi Ansari Nagar','ICU-5','VN-AIM-402','Hamilton C6',34,'2026-07-11','2026-07-11 07:00:00+05:30','2026-07-11 08:05:00+05:30',
     'aprv',450,449,99.78,'within_tolerance',10.0,10.1,'within_tolerance',70.00,70.40,'within_tolerance',
     'pass','pass','replaced','pass','pass','calibrated','passed','2026-07-11 08:25:00+05:30','APRV high-PEEP release verified'),
    ('KIMS Secunderabad','ICU-1','VN-KIM-501','Maquet Servo-u',18,'2026-07-11','2026-07-11 09:00:00+05:30','2026-07-11 10:10:00+05:30',
     'pressure_control_ac',430,425,98.84,'within_tolerance',6.0,6.1,'within_tolerance',50.00,44.20,'out_of_tolerance',
     'pass','pass','ok','pass','pass','failed','quarantined',null,'FiO2 reads 44% at 50% set — O2 sensor expired, held'),
    ('Care Hospitals Banjara Hills','ICU-3','VN-CAR-601','Drager Evita V300',9,'2026-07-10','2026-07-10 08:40:00+05:30','2026-07-10 09:45:00+05:30',
     'niv_bilevel',400,397,99.25,'within_tolerance',5.0,5.1,'within_tolerance',40.00,40.30,'within_tolerance',
     'pass','pass','ok','pass','pass','ok','passed','2026-07-10 10:05:00+05:30','NIV bilevel leak-compensated PM clean'),
    ('Yashoda Somajiguda Hyderabad','ICU-2','VN-YSH-701','Hamilton T1',41,'2026-07-10','2026-07-10 06:30:00+05:30','2026-07-10 07:30:00+05:30',
     'high_flow_nasal',350,349,99.71,'within_tolerance',4.0,4.0,'within_tolerance',45.00,45.30,'within_tolerance',
     'pass','pass','replaced','pass','pass','ok','passed','2026-07-10 07:50:00+05:30','Transport vent HFNC delivery verified'),
    ('St John''s Bengaluru','ICU-1','VN-STJ-801','Drager Savina 300',6,'2026-07-09','2026-07-09 08:00:00+05:30','2026-07-09 09:05:00+05:30',
     'cpap',300,296,98.67,'within_tolerance',5.0,5.2,'minor_deviation',30.00,30.60,'within_tolerance',
     'borderline','pass','ok','pass','pass','ok','conditional_pass','2026-07-09 09:25:00+05:30','Minor PEEP drift + borderline circuit leak — monitor'),
    ('Rainbow Children''s Hyderabad','NICU-1','VN-RBW-901','Hamilton C1 neo',15,'2026-07-09','2026-07-09 09:20:00+05:30',null,
     'pressure_control_ac',60,54,90.00,'out_of_tolerance',5.0,5.3,'minor_deviation',40.00,40.80,'within_tolerance',
     'fail','pass','ok','pass','pass','ok','pending_review',null,'Neonatal circuit leak — 6ml TV shortfall, awaiting circuit swap'),
    ('Manipal Whitefield Bengaluru','ICU-4','VN-MNP-302','Maquet Servo-i',21,'2026-07-08','2026-07-08 07:10:00+05:30','2026-07-08 08:15:00+05:30',
     'volume_control_ac',470,466,99.15,'within_tolerance',7.0,7.0,'within_tolerance',55.00,55.40,'within_tolerance',
     'pass','pass','replaced','pass','pass','calibrated','passed','2026-07-08 08:35:00+05:30','Routine PM post-calibration all green')
  ) as q(hosp, icu, tag, model, pn, pd, ps, pe, mode, tvs, tvm, tva, tvv, pes, pem, pev, fis, fim, fiv, leak, alarm, hme, apn, disc, o2, verdict, rts, nt);

  -- CAPA seed — attach to specific ventilator PM rows by asset tag
  insert into public.ventilator_pm_capa_actions_r3142 (
    pm_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('VN-FRT-201','tidal_volume_out_of_tolerance','flow_sensor_drift','replace_flow_sensor','2026-07-18',null,'in_progress','nabh_finding',18000.00,'Proximal flow sensor drifted 9% — replacement on order'),
    ('VN-MNP-301','apnoea_alarm_fail','pcb_alarm_fault','firmware_update','2026-07-16',null,'escalated','patient_safety_alert',25000.00,'Alarm PCB replaced + firmware reflash — unit off duty till verified'),
    ('VN-KIM-501','fio2_out_of_tolerance','oxygen_sensor_expired','replace_oxygen_sensor','2026-07-15','2026-07-13','closed','cdsco_notifiable',9500.00,'Galvanic O2 cell replaced and 2-point calibrated, retest passed'),
    ('VN-AIM-401','alarm_battery_fail','battery_end_of_life','replace_battery_pack','2026-07-17',null,'verification_pending','iso_13485_deviation',7200.00,'Internal battery below 40% capacity at 5-year mark'),
    ('VN-RBW-901','leak_detected','patient_circuit_leak','replace_patient_circuit','2026-07-14',null,'open','nabh_finding',3200.00,'Neonatal limb microtear — heated circuit replacement staged'),
    ('VN-APL-102','preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-07-05',null,'overdue','internal_only',15000.00,'HME/filter PM overdue 9 days — visible in NABH walkthrough')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.ventilator_pm_r3142 e
    on e.organization_id = v_org_id and e.ventilator_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) PM verdict distribution
create or replace function public.founder_r3142_pm_verdict_rollup()
returns table(pm_verdict text, pm_checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ventilator_pm_r3142)
  select l.pm_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ventilator_pm_r3142 l
  group by l.pm_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3142_pm_verdict_rollup() from public, anon;
grant execute on function public.founder_r3142_pm_verdict_rollup() to authenticated;

-- 2) Hospital-level compliance scorecard
create or replace function public.founder_r3142_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  quarantined bigint,
  recalls bigint,
  tv_fail bigint,
  fio2_fail bigint,
  alarm_fail bigint,
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
    count(*) filter (where l.pm_verdict in ('passed','conditional_pass'))::bigint,
    count(*) filter (where l.pm_verdict = 'quarantined')::bigint,
    count(*) filter (where l.pm_verdict = 'recall_needed')::bigint,
    count(*) filter (where l.tidal_volume_verdict = 'out_of_tolerance')::bigint,
    count(*) filter (where l.fio2_verdict = 'out_of_tolerance')::bigint,
    count(*) filter (where l.apnoea_alarm_test = 'fail' or l.disconnect_alarm_test = 'fail' or l.alarm_battery_result in ('fail','depleted'))::bigint,
    round(100.0 * count(*) filter (where l.pm_verdict in ('passed','conditional_pass'))::numeric / nullif(count(*),0), 1)
  from public.ventilator_pm_r3142 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3142_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3142_hospital_scorecard() to authenticated;

-- 3) Ventilation-mode × tidal-volume verdict matrix
create or replace function public.founder_r3142_mode_accuracy_matrix()
returns table(ventilation_mode_tested text, tidal_volume_verdict text, checks bigint, passed bigint, avg_tv_accuracy numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ventilation_mode_tested, l.tidal_volume_verdict, count(*)::bigint,
    count(*) filter (where l.pm_verdict in ('passed','conditional_pass'))::bigint,
    round(avg(l.tidal_volume_accuracy_pct), 2)
  from public.ventilator_pm_r3142 l
  group by l.ventilation_mode_tested, l.tidal_volume_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3142_mode_accuracy_matrix() from public, anon;
grant execute on function public.founder_r3142_mode_accuracy_matrix() to authenticated;

-- 4) Alarm & leak daily trend
create or replace function public.founder_r3142_alarm_daily_trend()
returns table(pm_date date, apnoea_pass bigint, apnoea_fail bigint, disconnect_pass bigint, disconnect_fail bigint, leak_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pm_date,
    count(*) filter (where l.apnoea_alarm_test = 'pass')::bigint,
    count(*) filter (where l.apnoea_alarm_test = 'fail')::bigint,
    count(*) filter (where l.disconnect_alarm_test = 'pass')::bigint,
    count(*) filter (where l.disconnect_alarm_test = 'fail')::bigint,
    count(*) filter (where l.leak_test_result in ('fail','borderline'))::bigint
  from public.ventilator_pm_r3142 l
  group by l.pm_date
  order by l.pm_date desc;
end;
$$;

revoke execute on function public.founder_r3142_alarm_daily_trend() from public, anon;
grant execute on function public.founder_r3142_alarm_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3142_capa_status_board()
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
  from public.ventilator_pm_capa_actions_r3142 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3142_capa_status_board() from public, anon;
grant execute on function public.founder_r3142_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3142_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ventilator_pm_capa_actions_r3142)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ventilator_pm_capa_actions_r3142 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3142_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3142_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3142_regulatory_impact_digest()
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
  from public.ventilator_pm_capa_actions_r3142 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3142_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3142_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority PM queue
create or replace function public.founder_r3142_high_risk_checks()
returns table(
  hospital_name text,
  icu_unit_code text,
  ventilator_asset_tag text,
  pm_date date,
  pm_verdict text,
  tidal_volume_verdict text,
  fio2_verdict text,
  apnoea_alarm_test text,
  disconnect_alarm_test text,
  leak_test_result text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.icu_unit_code, l.ventilator_asset_tag, l.pm_date,
    l.pm_verdict, l.tidal_volume_verdict, l.fio2_verdict,
    l.apnoea_alarm_test, l.disconnect_alarm_test, l.leak_test_result, l.notes
  from public.ventilator_pm_r3142 l
  where l.pm_verdict in ('failed','quarantined','recall_needed','pending_review','conditional_pass')
     or l.tidal_volume_verdict = 'out_of_tolerance'
     or l.fio2_verdict = 'out_of_tolerance'
     or l.peep_verdict = 'out_of_tolerance'
     or l.apnoea_alarm_test = 'fail'
     or l.disconnect_alarm_test = 'fail'
     or l.alarm_battery_result in ('fail','depleted')
     or l.leak_test_result in ('fail','borderline')
  order by l.pm_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3142_high_risk_checks() from public, anon;
grant execute on function public.founder_r3142_high_risk_checks() to authenticated;
