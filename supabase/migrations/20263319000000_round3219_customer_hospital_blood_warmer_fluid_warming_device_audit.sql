-- Round 3219: Customer Hospital Blood-Warmer & Fluid-Infusion Warming Device Audit
-- Warmer QA — device type × set/output temp × temp error × over-temp alarm × flow-rate range × disposable-set compatibility × CAPA

-- =============================================================================
-- TABLE 1: blood_warmer_r3219 — individual warming-device audit runs
-- =============================================================================
create table if not exists public.blood_warmer_r3219 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_code text not null,
  device_asset_tag text not null,
  device_model text not null,
  device_type text not null check (device_type in (
    'blood_warmer','fluid_warmer','forced_air_warming','warming_mattress'
  )),
  test_date date not null,
  tested_at timestamptz not null,
  set_temperature_c numeric(5,2) not null,
  output_temperature_c numeric(5,2),
  temp_error_c numeric(5,2),
  over_temp_alarm_result text check (over_temp_alarm_result in (
    'pass','fail','alarm_late','alarm_absent','not_tested'
  )),
  flow_rate_range_ok boolean,
  flow_rate_ml_min numeric(7,2),
  disposable_set_compatibility text check (disposable_set_compatibility in (
    'compatible','incompatible','substitute_used','not_applicable'
  )),
  technician_profile_id uuid references public.profiles(id) on delete set null,
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','restricted_use','out_of_service','calibration_due','recall_needed','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.blood_warmer_r3219 enable row level security;

create index if not exists idx_blood_warmer_r3219_org on public.blood_warmer_r3219(organization_id);
create index if not exists idx_blood_warmer_r3219_date on public.blood_warmer_r3219(test_date);
create index if not exists idx_blood_warmer_r3219_verdict on public.blood_warmer_r3219(audit_verdict);

-- =============================================================================
-- TABLE 2: blood_warmer_capa_actions_r3219 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.blood_warmer_capa_actions_r3219 (
  id uuid primary key default gen_random_uuid(),
  warmer_log_id uuid not null references public.blood_warmer_r3219(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'over_temp_alarm_fail','temperature_overshoot','temperature_undershoot','flow_restriction',
    'disposable_set_mismatch','heater_plate_scorching','calibration_overdue','sensor_cable_damage',
    'display_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'thermistor_drift','heater_plate_scale_buildup','controller_relay_worn','firmware_outdated',
    'non_oem_disposable_set','kinked_tubing_practice','power_supply_unstable','sensor_cable_wear',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_thermistor','replace_heater_plate','replace_controller_relay','update_firmware',
    'stock_oem_disposable_sets','retrain_nursing_staff','withdraw_device_from_use','replace_sensor_cable',
    'schedule_amc_visit','none_required'
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

alter table public.blood_warmer_capa_actions_r3219 enable row level security;

create index if not exists idx_blood_warmer_capa_r3219_log on public.blood_warmer_capa_actions_r3219(warmer_log_id);
create index if not exists idx_blood_warmer_capa_r3219_status on public.blood_warmer_capa_actions_r3219(capa_status);

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

  -- 14 warmer audit rows
  insert into public.blood_warmer_r3219 (
    organization_id, hospital_name, ward_code, device_asset_tag, device_model,
    device_type, test_date, tested_at,
    set_temperature_c, output_temperature_c, temp_error_c,
    over_temp_alarm_result, flow_rate_range_ok, flow_rate_ml_min,
    disposable_set_compatibility, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.tag, q.model,
    q.dt, q.td::date, q.ta::timestamptz,
    q.st, q.ot, q.te,
    q.oa, q.fok, q.fr,
    q.dsc, q.av, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-2','BW-APL-101','Barkey S-line','blood_warmer','2026-07-02','2026-07-02 08:15:00+05:30',
     38.00,37.80,-0.20,'pass',true,150.00,'compatible','fit_for_use','Routine quarterly QA — within spec'),
    ('Apollo Hyderabad Jubilee Hills','OT-4','FAW-APL-114','3M Bair Hugger 775','forced_air_warming','2026-07-02','2026-07-02 09:00:00+05:30',
     43.00,42.60,-0.40,'pass',true,null,'compatible','fit_for_use','Hose-end temp within 43C safety limit'),
    ('Fortis Bannerghatta Bengaluru','ER-1','BW-FRT-052','Smiths Level 1 H-1200','blood_warmer','2026-07-01','2026-07-01 07:30:00+05:30',
     41.00,43.90,2.90,'fail',true,500.00,'compatible','out_of_service','Overshoot to 43.9C with silent alarm — withdrawn immediately'),
    ('Fortis Bannerghatta Bengaluru','ICU-3','FW-FRT-060','Stihler Astotherm Plus','fluid_warmer','2026-07-01','2026-07-01 08:10:00+05:30',
     39.00,38.70,-0.30,'pass',false,45.00,'substitute_used','restricted_use','Flow restricted on substitute set — OEM sets out of stock'),
    ('Manipal Whitefield Bengaluru','NICU-1','WM-MNP-201','Inditherm Alpha','warming_mattress','2026-06-30','2026-06-30 10:00:00+05:30',
     37.00,36.40,-0.60,'pass',null,null,'not_applicable','calibration_due','Surface temp low by 0.6C — calibration due 20 days'),
    ('Manipal Whitefield Bengaluru','OT-1','BW-MNP-205','Barkey autotime','blood_warmer','2026-06-30','2026-06-30 11:05:00+05:30',
     38.00,38.10,0.10,'pass',true,300.00,'compatible','fit_for_use','Post-service verification passed'),
    ('AIIMS New Delhi Ansari Nagar','Trauma-OT','BW-AIM-310','Smiths HOTLINE HL-90','blood_warmer','2026-06-29','2026-06-29 06:45:00+05:30',
     41.50,41.20,-0.30,'alarm_late',true,250.00,'compatible','restricted_use','Over-temp alarm sounded 12s late — restricted pending service'),
    ('AIIMS New Delhi Ansari Nagar','ICU-7','FAW-AIM-322','Stryker Mistral-Air','forced_air_warming','2026-06-29','2026-06-29 07:30:00+05:30',
     38.00,37.90,-0.10,'pass',true,null,'compatible','fit_for_use','Blanket coupling seal replaced last month'),
    ('KIMS Secunderabad','CTVS-OT','FW-KIM-410','Biegler BW 685','fluid_warmer','2026-06-28','2026-06-28 08:00:00+05:30',
     39.00,41.80,2.80,'fail',true,200.00,'compatible','recall_needed','Overshoot with silent alarm — infusion batch recalled'),
    ('KIMS Secunderabad','ER-2','BW-KIM-402','Smiths Level 1 H-1200','blood_warmer','2026-06-28','2026-06-28 09:10:00+05:30',
     41.00,40.70,-0.30,'pass',true,480.00,'incompatible','restricted_use','Non-OEM disposable set fitted — pressure alarm chatter'),
    ('Care Hospitals Banjara Hills','ICU-1','WM-CAR-505','KanMed OperaTherm 202','warming_mattress','2026-06-27','2026-06-27 10:30:00+05:30',
     38.00,37.90,-0.10,'pass',null,null,'not_applicable','fit_for_use','Annual QA passed'),
    ('Yashoda Somajiguda Hyderabad','OT-2','BW-YSH-601','Barkey S-line','blood_warmer','2026-06-27','2026-06-27 07:45:00+05:30',
     38.00,35.90,-2.10,'not_tested',true,320.00,'compatible','pending_review','Undershoot 2.1C — heater plate suspected, review pending'),
    ('St John''s Bengaluru','ER-1','FW-STJ-702','Stihler Astoflow','fluid_warmer','2026-06-26','2026-06-26 08:20:00+05:30',
     39.00,38.90,-0.10,'pass',true,180.00,'compatible','fit_for_use','Weekly check normal'),
    ('Rainbow Children''s Hyderabad','PICU-1','FAW-RBW-801','3M Bair Hugger 675','forced_air_warming','2026-06-26','2026-06-26 09:40:00+05:30',
     38.00,39.60,1.60,'alarm_absent',true,null,'compatible','out_of_service','Hose-end 39.6C on 38C set with no alarm — removed from PICU')
  ) as q(hosp, ward, tag, model, dt, td, ta, st, ot, te, oa, fok, fr, dsc, av, nt);

  -- CAPA seed — attach to specific audited devices
  insert into public.blood_warmer_capa_actions_r3219 (
    warmer_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('BW-FRT-052','over_temp_alarm_fail','thermistor_drift','recalibrate_thermistor','2026-07-06',null,'in_progress','patient_safety_alert',18500.00,'Thermistor kit ordered from Smiths'),
    ('FW-KIM-410','temperature_overshoot','controller_relay_worn','replace_controller_relay','2026-07-04',null,'escalated','cdsco_notifiable',36000.00,'Second overshoot this quarter — escalated to OEM'),
    ('BW-YSH-601','temperature_undershoot','heater_plate_scale_buildup','replace_heater_plate','2026-07-08',null,'open','internal_only',22000.00,'Heater plate scaled from hard-water flushing'),
    ('FAW-RBW-801','over_temp_alarm_fail','firmware_outdated','update_firmware','2026-07-03','2026-07-01','closed','nabh_finding',0.00,'OEM firmware patch applied and alarm retested'),
    ('FW-FRT-060','disposable_set_mismatch','non_oem_disposable_set','stock_oem_disposable_sets','2026-07-10',null,'verification_pending','iso_13485_deviation',9500.00,'OEM sets PO raised — verifying flow after restock'),
    ('BW-KIM-402','disposable_set_mismatch','non_oem_disposable_set','retrain_nursing_staff','2026-06-25',null,'overdue','nabh_finding',4500.00,'Store issued wrong sets — retraining overdue'),
    ('WM-MNP-201','calibration_overdue','preventive_service_backlog','schedule_amc_visit','2026-07-12',null,'open','none',7500.00,'Mattress calibration overdue 20 days')
  ) as q(tagk, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.blood_warmer_r3219 e
    on e.organization_id = v_org_id and e.device_asset_tag = q.tagk;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3219_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_warmer_r3219)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.blood_warmer_r3219 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3219_verdict_rollup() from public, anon;
grant execute on function public.founder_r3219_verdict_rollup() to authenticated;

-- 2) Hospital-level warmer scorecard
create or replace function public.founder_r3219_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fit_for_use bigint,
  restricted bigint,
  out_of_service bigint,
  alarm_fails bigint,
  avg_abs_temp_error_c numeric,
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
    count(*) filter (where l.audit_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.over_temp_alarm_result in ('fail','alarm_late','alarm_absent'))::bigint,
    round(avg(abs(l.temp_error_c)), 2),
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.blood_warmer_r3219 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3219_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3219_hospital_scorecard() to authenticated;

-- 3) Device-type breakdown matrix
create or replace function public.founder_r3219_device_type_matrix()
returns table(device_type text, audits bigint, fit_for_use bigint, alarm_fails bigint, avg_abs_temp_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.over_temp_alarm_result in ('fail','alarm_late','alarm_absent'))::bigint,
    round(avg(abs(l.temp_error_c)), 2)
  from public.blood_warmer_r3219 l
  group by l.device_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3219_device_type_matrix() from public, anon;
grant execute on function public.founder_r3219_device_type_matrix() to authenticated;

-- 4) Alarm & flow daily trend
create or replace function public.founder_r3219_daily_trend()
returns table(test_date date, audits bigint, alarm_pass bigint, alarm_fail bigint, flow_ok bigint, flow_not_ok bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.over_temp_alarm_result = 'pass')::bigint,
    count(*) filter (where l.over_temp_alarm_result in ('fail','alarm_late','alarm_absent'))::bigint,
    count(*) filter (where l.flow_rate_range_ok is true)::bigint,
    count(*) filter (where l.flow_rate_range_ok is false)::bigint
  from public.blood_warmer_r3219 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3219_daily_trend() from public, anon;
grant execute on function public.founder_r3219_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3219_capa_status_board()
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
  from public.blood_warmer_capa_actions_r3219 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3219_capa_status_board() from public, anon;
grant execute on function public.founder_r3219_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3219_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.blood_warmer_capa_actions_r3219)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.blood_warmer_capa_actions_r3219 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3219_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3219_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3219_regulatory_impact_digest()
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
  from public.blood_warmer_capa_actions_r3219 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3219_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3219_regulatory_impact_digest() to authenticated;

-- 8) High-risk devices queue (top individual concerns)
create or replace function public.founder_r3219_high_risk_devices()
returns table(
  hospital_name text,
  ward_code text,
  device_asset_tag text,
  device_type text,
  test_date date,
  audit_verdict text,
  over_temp_alarm_result text,
  temp_error_c numeric,
  disposable_set_compatibility text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_code, l.device_asset_tag, l.device_type, l.test_date,
    l.audit_verdict, l.over_temp_alarm_result, l.temp_error_c, l.disposable_set_compatibility, l.notes
  from public.blood_warmer_r3219 l
  where l.audit_verdict in ('restricted_use','out_of_service','calibration_due','recall_needed','pending_review')
     or l.over_temp_alarm_result in ('fail','alarm_late','alarm_absent')
     or abs(l.temp_error_c) >= 1.0
     or l.disposable_set_compatibility = 'incompatible'
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3219_high_risk_devices() from public, anon;
grant execute on function public.founder_r3219_high_risk_devices() to authenticated;
