-- Round 3146: Customer Hospital Defibrillator & AED Readiness / Energy-Delivery Audit
-- Defib/AED readiness log — device type × set/delivered energy × energy error % × charge time × battery × pads expiry × self-test × ECG trace × verdict × CAPA

-- =============================================================================
-- TABLE 1: defibrillator_r3146 — individual defibrillator/AED readiness checks
-- =============================================================================
create table if not exists public.defibrillator_r3146 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_location text not null,
  defib_asset_tag text not null,
  defib_model text not null,
  device_type text not null check (device_type in (
    'manual_monophasic','manual_biphasic','aed_fully_automatic','aed_semi_automatic',
    'biphasic_truncated_exponential','pulsed_biphasic','wearable_cardioverter'
  )),
  test_date date not null,
  tested_at timestamptz not null,
  set_energy_joules numeric(6,2) not null,
  delivered_energy_joules numeric(6,2),
  energy_error_pct numeric(5,2),
  charge_time_seconds numeric(5,2),
  battery_percent numeric(5,2),
  battery_health text not null check (battery_health in (
    'healthy','degraded','replace_soon','end_of_life','not_assessed'
  )),
  pads_type text not null check (pads_type in (
    'adult_pads','pediatric_pads','internal_paddles','external_paddles','multifunction_pads','training_pads'
  )),
  pads_expiry_date date,
  pads_status text not null check (pads_status in (
    'valid','expiring_soon','expired','missing','not_checked'
  )),
  self_test_result text not null check (self_test_result in (
    'pass','fail','warning','not_run','manual_override'
  )),
  ecg_trace_quality text not null check (ecg_trace_quality in (
    'clean','baseline_wander','noisy','artifact','flatline','not_captured'
  )),
  operator_profile_id uuid references public.profiles(id) on delete set null,
  readiness_verdict text not null check (readiness_verdict in (
    'ready','conditional_ready','not_ready','quarantined','out_of_service','recall_needed','pending_review'
  )),
  next_service_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.defibrillator_r3146 enable row level security;

create index if not exists idx_defibrillator_r3146_org on public.defibrillator_r3146(organization_id);
create index if not exists idx_defibrillator_r3146_date on public.defibrillator_r3146(test_date);
create index if not exists idx_defibrillator_r3146_verdict on public.defibrillator_r3146(readiness_verdict);

-- =============================================================================
-- TABLE 2: defibrillator_capa_actions_r3146 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.defibrillator_capa_actions_r3146 (
  id uuid primary key default gen_random_uuid(),
  defib_log_id uuid not null references public.defibrillator_r3146(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'energy_delivery_error','charge_time_excessive','battery_depleted','pads_expired',
    'self_test_fail','ecg_noise','waveform_anomaly','device_offline','operator_error','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'capacitor_degraded','battery_end_of_life','pads_stock_lapsed','firmware_bug',
    'electrode_connector_fault','sensor_drift','operator_setup_error',
    'environmental_interference','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_battery','replace_pads','recalibrate_energy_output','replace_capacitor_bank',
    'firmware_update','replace_cable_harness','retrain_operator','quarantine_device',
    'trigger_recall','schedule_amc_visit','none_required'
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

alter table public.defibrillator_capa_actions_r3146 enable row level security;

create index if not exists idx_defibrillator_capa_r3146_log on public.defibrillator_capa_actions_r3146(defib_log_id);
create index if not exists idx_defibrillator_capa_r3146_status on public.defibrillator_capa_actions_r3146(capa_status);

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

  -- 14 defibrillator/AED readiness rows
  insert into public.defibrillator_r3146 (
    organization_id, hospital_name, device_location, defib_asset_tag, defib_model, device_type,
    test_date, tested_at,
    set_energy_joules, delivered_energy_joules, energy_error_pct, charge_time_seconds, battery_percent,
    battery_health, pads_type, pads_expiry_date, pads_status,
    self_test_result, ecg_trace_quality, readiness_verdict, next_service_at, notes
  )
  select v_org_id, q.hosp, q.loc, q.tag, q.model, q.dt,
    q.td::date, q.ta::timestamptz,
    q.se, q.de, q.ee, q.ct, q.bat,
    q.bh, q.pt, q.pe::date, q.ps,
    q.st, q.eq, q.rv, q.nc::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-1','DEF-APL-101','Zoll R Series','manual_biphasic',
     '2026-07-10','2026-07-10 06:15:00+05:30',200.00,198.40,-0.80,4.20,97.00,
     'healthy','multifunction_pads','2027-03-01','valid','pass','clean','ready','2026-08-10 06:00:00+05:30','Monthly readiness check — within tolerance'),
    ('Apollo Hyderabad Jubilee Hills','ER-2','DEF-APL-102','Philips HeartStart XL+','aed_semi_automatic',
     '2026-07-10','2026-07-10 07:00:00+05:30',150.00,149.10,-0.60,3.80,92.00,
     'healthy','adult_pads','2026-12-15','valid','pass','clean','ready','2026-08-10 07:00:00+05:30','Crash-cart AED self-test green'),
    ('Fortis Bannerghatta Bengaluru','OT-1','DEF-FRT-201','Zoll M Series','manual_biphasic',
     '2026-07-09','2026-07-09 05:40:00+05:30',360.00,300.20,-16.61,9.50,62.00,
     'degraded','multifunction_pads','2026-11-01','valid','warning','baseline_wander','not_ready',null,'Delivered energy 16.6% low at 360J — capacitor suspect'),
    ('Fortis Bannerghatta Bengaluru','CCU-1','DEF-FRT-202','Nihon Kohden TEC-5600','biphasic_truncated_exponential',
     '2026-07-09','2026-07-09 06:30:00+05:30',200.00,null,null,null,8.00,
     'end_of_life','adult_pads','2026-10-01','valid','fail','flatline','out_of_service',null,'Battery 8% — self-test failed, pulled from service'),
    ('Manipal Whitefield Bengaluru','ER-1','DEF-MNP-301','Schiller Defigard Touch 7','aed_fully_automatic',
     '2026-07-08','2026-07-08 08:20:00+05:30',150.00,148.80,-0.80,4.00,88.00,
     'healthy','adult_pads','2026-06-20','expired','pass','clean','not_ready',null,'Pads expired 20 Jun — device otherwise functional'),
    ('Manipal Whitefield Bengaluru','ICU-2','DEF-MNP-302','Zoll R Series','manual_biphasic',
     '2026-07-08','2026-07-08 09:10:00+05:30',200.00,199.60,-0.20,4.10,95.00,
     'healthy','multifunction_pads','2027-01-10','valid','pass','clean','ready','2026-08-08 09:00:00+05:30','Post-service verification cycle passed'),
    ('AIIMS New Delhi Ansari Nagar','ER-3','DEF-AIM-401','Philips HeartStart MRx','manual_biphasic',
     '2026-07-07','2026-07-07 06:05:00+05:30',360.00,357.10,-0.81,5.20,90.00,
     'healthy','multifunction_pads','2027-02-01','valid','pass','clean','ready','2026-08-07 06:00:00+05:30','Full-energy discharge test nominal'),
    ('AIIMS New Delhi Ansari Nagar','NICU','DEF-AIM-402','Zoll X Series','pulsed_biphasic',
     '2026-07-07','2026-07-07 07:15:00+05:30',50.00,49.60,-0.80,3.20,94.00,
     'healthy','pediatric_pads','2026-12-01','valid','pass','clean','ready','2026-08-07 07:00:00+05:30','Neonatal energy setting verified'),
    ('KIMS Secunderabad','OT-4','DEF-KIM-501','GE Responder 2000','manual_monophasic',
     '2026-07-06','2026-07-06 05:50:00+05:30',300.00,282.00,-6.00,12.30,71.00,
     'degraded','external_paddles','2026-11-20','valid','warning','noisy','conditional_ready',null,'Charge time 12.3s exceeds 10s spec — monitor'),
    ('KIMS Secunderabad','Ward-5','DEF-KIM-502','Mindray BeneHeart D6','aed_semi_automatic',
     '2026-07-06','2026-07-06 07:00:00+05:30',200.00,null,null,null,55.00,
     'replace_soon','adult_pads','2026-10-10','valid','fail','artifact','quarantined',null,'Daily self-test fail code E07 — quarantined'),
    ('Care Hospitals Banjara Hills','ICU-1','DEF-CAR-601','Zoll R Series','manual_biphasic',
     '2026-07-05','2026-07-05 06:40:00+05:30',200.00,198.90,-0.55,4.30,96.00,
     'healthy','multifunction_pads','2027-04-01','valid','pass','clean','ready','2026-08-05 06:00:00+05:30','Routine monthly — all parameters green'),
    ('Yashoda Somajiguda Hyderabad','ER-2','DEF-YSH-701','Philips HeartStart FRx','aed_fully_automatic',
     '2026-07-04','2026-07-04 08:00:00+05:30',150.00,149.40,-0.40,3.90,84.00,
     'degraded','adult_pads','2026-08-05','expiring_soon','pass','clean','conditional_ready','2026-08-01 08:00:00+05:30','Pads expire in ~4 weeks — replacement flagged'),
    ('St John''s Bengaluru','OT-2','DEF-STJ-801','Nihon Kohden Cardiolife TEC-8300','manual_biphasic',
     '2026-07-04','2026-07-04 05:55:00+05:30',360.00,351.20,-2.44,6.10,89.00,
     'healthy','multifunction_pads','2027-01-25','valid','warning','artifact','recall_needed',null,'Waveform anomaly — vendor recall advisory active'),
    ('Rainbow Children''s Hyderabad','NICU','DEF-RBW-901','Zoll X Series','pulsed_biphasic',
     '2026-07-03','2026-07-03 07:20:00+05:30',50.00,48.20,-3.60,3.40,78.00,
     'degraded','pediatric_pads','2026-11-15','valid','pass','noisy','pending_review',null,'ECG trace noisy — awaiting biomedical review')
  ) as q(hosp, loc, tag, model, dt, td, ta, se, de, ee, ct, bat, bh, pt, pe, ps, st, eq, rv, nc, nt);

  -- CAPA seed — attach to specific devices by asset tag
  insert into public.defibrillator_capa_actions_r3146 (
    defib_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('DEF-FRT-201','energy_delivery_error','capacitor_degraded','recalibrate_energy_output','2026-07-16',null,'in_progress','nabh_finding',38000.00,'Energy output 16% low — service engineer scheduled'),
    ('DEF-FRT-202','battery_depleted','battery_end_of_life','replace_battery','2026-07-12','2026-07-11','closed','patient_safety_alert',9500.00,'OEM battery pack replaced, self-test now green'),
    ('DEF-MNP-301','pads_expired','pads_stock_lapsed','replace_pads','2026-07-11',null,'in_progress','patient_safety_alert',6500.00,'Emergency pads dispatched from central store'),
    ('DEF-KIM-501','charge_time_excessive','capacitor_degraded','replace_capacitor_bank','2026-07-15',null,'verification_pending','iso_13485_deviation',42000.00,'Capacitor bank on order — interim monitoring'),
    ('DEF-KIM-502','self_test_fail','firmware_bug','firmware_update','2026-07-13',null,'escalated','nabh_finding',5000.00,'E07 fault — OEM firmware patch escalated'),
    ('DEF-STJ-801','waveform_anomaly','firmware_bug','trigger_recall','2026-07-20',null,'open','patient_safety_alert',0.00,'Vendor recall advisory — unit tagged do-not-use'),
    ('DEF-RBW-901','preventive_maintenance_due','preventive_service_backlog','schedule_amc_visit','2026-06-30',null,'overdue','internal_only',12000.00,'Quarterly PM overdue — AMC visit backlogged')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.defibrillator_r3146 e
    on e.organization_id = v_org_id and e.defib_asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3146_readiness_verdict_rollup()
returns table(readiness_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.defibrillator_r3146)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.defibrillator_r3146 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3146_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3146_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3146_hospital_scorecard()
returns table(
  hospital_name text,
  total_devices bigint,
  ready bigint,
  not_ready bigint,
  out_of_service bigint,
  self_test_fail bigint,
  pads_expired bigint,
  avg_energy_error numeric,
  readiness_pct numeric
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
    count(*) filter (where l.readiness_verdict = 'ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'not_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.self_test_result = 'fail')::bigint,
    count(*) filter (where l.pads_status = 'expired')::bigint,
    round(avg(l.energy_error_pct), 2),
    round(100.0 * count(*) filter (where l.readiness_verdict = 'ready')::numeric / nullif(count(*),0), 1)
  from public.defibrillator_r3146 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3146_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3146_hospital_scorecard() to authenticated;

-- 3) Device-type × energy-delivery matrix
create or replace function public.founder_r3146_device_energy_matrix()
returns table(
  device_type text,
  tests bigint,
  ready bigint,
  avg_set_energy numeric,
  avg_delivered_energy numeric,
  avg_energy_error numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'ready')::bigint,
    round(avg(l.set_energy_joules), 2),
    round(avg(l.delivered_energy_joules), 2),
    round(avg(l.energy_error_pct), 2)
  from public.defibrillator_r3146 l
  group by l.device_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3146_device_energy_matrix() from public, anon;
grant execute on function public.founder_r3146_device_energy_matrix() to authenticated;

-- 4) Daily readiness trend
create or replace function public.founder_r3146_readiness_daily_trend()
returns table(
  test_date date,
  tests bigint,
  ready bigint,
  not_ready bigint,
  self_test_fail bigint,
  pads_expired bigint,
  avg_energy_error numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'not_ready')::bigint,
    count(*) filter (where l.self_test_result = 'fail')::bigint,
    count(*) filter (where l.pads_status = 'expired')::bigint,
    round(avg(l.energy_error_pct), 2)
  from public.defibrillator_r3146 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3146_readiness_daily_trend() from public, anon;
grant execute on function public.founder_r3146_readiness_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3146_capa_status_board()
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
  from public.defibrillator_capa_actions_r3146 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3146_capa_status_board() from public, anon;
grant execute on function public.founder_r3146_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3146_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.defibrillator_capa_actions_r3146)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.defibrillator_capa_actions_r3146 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3146_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3146_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3146_regulatory_impact_digest()
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
  from public.defibrillator_capa_actions_r3146 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3146_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3146_regulatory_impact_digest() to authenticated;

-- 8) High-risk / priority queue (individual concerns)
create or replace function public.founder_r3146_high_risk_devices()
returns table(
  hospital_name text,
  device_location text,
  defib_asset_tag text,
  test_date date,
  readiness_verdict text,
  self_test_result text,
  battery_health text,
  pads_status text,
  energy_error_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_location, l.defib_asset_tag, l.test_date,
    l.readiness_verdict, l.self_test_result, l.battery_health, l.pads_status, l.energy_error_pct, l.notes
  from public.defibrillator_r3146 l
  where l.readiness_verdict in ('not_ready','quarantined','out_of_service','recall_needed','pending_review','conditional_ready')
     or l.self_test_result = 'fail'
     or l.pads_status = 'expired'
     or l.battery_health = 'end_of_life'
     or abs(l.energy_error_pct) > 10
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3146_high_risk_devices() from public, anon;
grant execute on function public.founder_r3146_high_risk_devices() to authenticated;
