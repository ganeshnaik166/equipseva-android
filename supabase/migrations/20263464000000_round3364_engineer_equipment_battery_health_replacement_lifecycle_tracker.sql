-- Round 3364: Engineer Equipment Battery Health & Replacement Lifecycle Tracker
-- Battery-backed medical devices — chemistry × measured capacity × charge cycles × runtime test × age × replacement-due × health status × lifecycle verdict × CAPA

-- =============================================================================
-- TABLE 1: battery_health_r3364 — per battery/device health & lifecycle record
-- =============================================================================
create table if not exists public.battery_health_r3364 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  equipment_type text not null check (equipment_type in (
    'patient_monitor','infusion_pump','transport_ventilator','defibrillator',
    'ups_backup','syringe_pump','portable_ecg'
  )),
  battery_chemistry text not null check (battery_chemistry in (
    'li_ion','sealed_lead_acid','nimh','lifepo4'
  )),
  assessment_date date not null,
  assessed_at timestamptz not null,
  install_date date not null,
  rated_capacity_pct numeric(5,1) not null,
  measured_capacity_pct numeric(5,1),
  capacity_degradation_pct numeric(5,1),
  charge_cycles int,
  runtime_test_minutes numeric(6,1),
  runtime_meets_spec boolean not null,
  battery_age_months int not null,
  replacement_due_date date,
  health_status text not null check (health_status in (
    'healthy','monitor','replace_soon','replace_now','failed'
  )),
  lifecycle_verdict text not null check (lifecycle_verdict in (
    'in_service_healthy','plan_replacement','replace_immediately','safety_risk','replaced_closed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.battery_health_r3364 enable row level security;

create index if not exists idx_battery_health_r3364_org on public.battery_health_r3364(organization_id);
create index if not exists idx_battery_health_r3364_date on public.battery_health_r3364(assessment_date);
create index if not exists idx_battery_health_r3364_verdict on public.battery_health_r3364(lifecycle_verdict);

-- =============================================================================
-- TABLE 2: battery_health_capa_actions_r3364 — CAPA & replacement actions
-- =============================================================================
create table if not exists public.battery_health_capa_actions_r3364 (
  id uuid primary key default gen_random_uuid(),
  battery_log_id uuid not null references public.battery_health_r3364(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'capacity_degradation','runtime_below_spec','excessive_charge_cycles','battery_overdue',
    'swelling_detected','charge_fault','preventive_replacement_due'
  )),
  root_cause text not null check (root_cause in (
    'normal_end_of_life','deep_discharge_abuse','overcharge_damage','high_temperature_exposure',
    'manufacturing_defect','charger_fault','deferred_maintenance','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_battery_pack','replace_and_recondition_charger','expedite_procurement','remove_device_from_service',
    'recalibrate_battery_gauge','update_pm_schedule','retire_device','none_required'
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

alter table public.battery_health_capa_actions_r3364 enable row level security;

create index if not exists idx_battery_capa_r3364_log on public.battery_health_capa_actions_r3364(battery_log_id);
create index if not exists idx_battery_capa_r3364_status on public.battery_health_capa_actions_r3364(capa_status);

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

  -- 14 battery health rows
  insert into public.battery_health_r3364 (
    organization_id, hospital_name, device_code, equipment_type, battery_chemistry,
    assessment_date, assessed_at, install_date,
    rated_capacity_pct, measured_capacity_pct, capacity_degradation_pct,
    charge_cycles, runtime_test_minutes, runtime_meets_spec,
    battery_age_months, replacement_due_date, health_status, lifecycle_verdict, notes
  )
  select v_org_id, q.hosp, q.dev, q.eqt, q.chem,
    q.adt::date, q.ats::timestamptz, q.idt::date,
    q.rated, q.meas, q.degr,
    q.cyc, q.rtm, q.rms,
    q.age, q.rdd::date, q.hs, q.lv, q.nt
  from (values
    ('Apollo Chennai','PM-APL-CHN-101','patient_monitor','li_ion','2026-07-10','2026-07-10 09:20:00+05:30','2024-02-15',
     100.0,94.0,6.0,210,240.0,true,29,'2027-02-15','healthy','in_service_healthy','Capacity 94% at 29 months — within spec, next check Q4'),
    ('Fortis Gurgaon','IP-FRT-GGN-201','infusion_pump','li_ion','2026-07-09','2026-07-09 10:05:00+05:30','2023-06-10',
     100.0,86.0,14.0,380,180.0,true,37,'2026-12-10','monitor','plan_replacement','Degradation 14% — schedule replacement before year end'),
    ('Manipal Bengaluru','TV-MNP-BLR-301','transport_ventilator','li_ion','2026-07-08','2026-07-08 08:40:00+05:30','2022-09-05',
     100.0,78.0,22.0,520,95.0,false,46,'2026-09-05','replace_soon','plan_replacement','Runtime 95 min below 120 min spec — replacement due Sep'),
    ('AIIMS Delhi','DF-AIM-DEL-401','defibrillator','sealed_lead_acid','2026-07-08','2026-07-08 07:15:00+05:30','2021-11-20',
     100.0,64.0,36.0,0,6.0,false,56,'2026-07-31','replace_now','replace_immediately','SLA at 64% — fails shock-count test, replace this month'),
    ('CMC Vellore','UPS-CMC-VEL-501','ups_backup','sealed_lead_acid','2026-07-07','2026-07-07 11:30:00+05:30','2020-05-12',
     100.0,48.0,52.0,0,4.0,false,74,'2026-06-30','failed','safety_risk','UPS holdover 4 min vs 15 min spec — OT backup at risk, overdue'),
    ('KIMS Hyderabad','SP-KIM-HYD-601','syringe_pump','li_ion','2026-07-07','2026-07-07 09:50:00+05:30','2024-08-01',
     100.0,96.0,4.0,140,300.0,true,23,'2027-08-01','healthy','in_service_healthy','New-generation pack, 96% at 23 months'),
    ('Apollo Chennai','ECG-APL-CHN-701','portable_ecg','nimh','2026-07-06','2026-07-06 14:10:00+05:30','2023-03-18',
     100.0,82.0,18.0,410,150.0,true,40,'2026-11-30','monitor','plan_replacement','NiMH memory effect suspected — reconditioning cycle scheduled'),
    ('Fortis Gurgaon','DF-FRT-GGN-801','defibrillator','lifepo4','2026-07-06','2026-07-06 08:05:00+05:30','2024-11-25',
     100.0,98.0,2.0,90,45.0,true,20,'2027-11-25','healthy','in_service_healthy','LiFePO4 pack excellent at 98%, low cycle count'),
    ('Manipal Bengaluru','PM-MNP-BLR-901','patient_monitor','li_ion','2026-07-05','2026-07-05 10:40:00+05:30','2021-07-14',
     100.0,68.0,32.0,610,55.0,false,60,'2026-07-20','replace_now','replace_immediately','ICU monitor runtime 55 min vs 90 min — replace before next audit'),
    ('AIIMS Delhi','TV-AIM-DEL-1001','transport_ventilator','li_ion','2026-07-05','2026-07-05 06:30:00+05:30','2020-10-30',
     100.0,52.0,48.0,780,38.0,false,69,'2026-06-15','failed','safety_risk','Transport vent pack swollen, 52% capacity — device grounded, overdue'),
    ('CMC Vellore','IP-CMC-VEL-1101','infusion_pump','nimh','2026-07-04','2026-07-04 13:20:00+05:30','2022-12-08',
     100.0,76.0,24.0,460,130.0,true,43,'2026-10-08','replace_soon','plan_replacement','NiMH at 76% — replacement pack requisitioned'),
    ('KIMS Hyderabad','UPS-KIM-HYD-1201','ups_backup','sealed_lead_acid','2026-07-04','2026-07-04 09:15:00+05:30','2023-01-22',
     100.0,84.0,16.0,0,12.0,true,41,'2027-01-22','monitor','plan_replacement','Lab UPS 84% — holdover 12 min, monitor next quarter'),
    ('Narayana Health Bengaluru','PM-NAR-BLR-1301','patient_monitor','li_ion','2026-07-03','2026-07-03 11:00:00+05:30','2026-06-20',
     100.0,100.0,0.0,8,250.0,true,1,'2029-06-20','healthy','replaced_closed','Battery replaced 20-Jun, new pack commissioned and verified'),
    ('Medanta Gurugram','SP-MED-GGN-1401','syringe_pump','li_ion','2026-07-03','2026-07-03 08:30:00+05:30','2025-01-10',
     100.0,91.0,9.0,120,280.0,true,18,'2028-01-10','healthy','in_service_healthy','Capacity 91% at 18 months, nominal')
  ) as q(hosp, dev, eqt, chem, adt, ats, idt, rated, meas, degr, cyc, rtm, rms, age, rdd, hs, lv, nt);

  -- CAPA seed — attach to specific devices via device_code
  insert into public.battery_health_capa_actions_r3364 (
    battery_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DF-AIM-DEL-401','capacity_degradation','normal_end_of_life','replace_battery_pack','open','patient_safety_alert','2026-07-31',null,22000.00,'SLA defib battery order placed with OEM'),
    ('UPS-CMC-VEL-501','runtime_below_spec','deferred_maintenance','replace_battery_pack','overdue','nabh_finding','2026-06-30',null,35000.00,'OT UPS holdover fails 15 min spec — overdue, expedite'),
    ('PM-MNP-BLR-901','runtime_below_spec','normal_end_of_life','replace_battery_pack','in_progress','internal_only','2026-07-20',null,12000.00,'ICU monitor pack replacement scheduled this week'),
    ('TV-AIM-DEL-1001','swelling_detected','high_temperature_exposure','remove_device_from_service','escalated','cdsco_notifiable','2026-06-25',null,48000.00,'Swollen pack — device grounded, CDSCO adverse-event review'),
    ('TV-MNP-BLR-301','runtime_below_spec','normal_end_of_life','expedite_procurement','open','iso_13485_deviation','2026-09-05',null,46000.00,'Transport vent replacement pack requisitioned'),
    ('PM-NAR-BLR-1301','preventive_replacement_due','normal_end_of_life','replace_battery_pack','closed','internal_only','2026-06-20','2026-06-20',11500.00,'Battery replaced and verified — CAPA closed'),
    ('IP-CMC-VEL-1101','capacity_degradation','normal_end_of_life','expedite_procurement','verification_pending','internal_only','2026-10-08',null,9500.00,'NiMH replacement pack on order — verify runtime post-swap')
  ) as q(dev, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.battery_health_r3364 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Lifecycle verdict distribution
create or replace function public.founder_r3364_lifecycle_verdict_rollup()
returns table(lifecycle_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.battery_health_r3364)
  select l.lifecycle_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.battery_health_r3364 l
  group by l.lifecycle_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3364_lifecycle_verdict_rollup() from public, anon;
grant execute on function public.founder_r3364_lifecycle_verdict_rollup() to authenticated;

-- 2) Hospital-level battery health scorecard
create or replace function public.founder_r3364_hospital_scorecard()
returns table(
  hospital_name text,
  total_devices bigint,
  healthy bigint,
  plan_replace bigint,
  replace_now bigint,
  failed bigint,
  runtime_fail bigint,
  overdue bigint,
  healthy_pct numeric
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
    count(*) filter (where l.health_status = 'healthy')::bigint,
    count(*) filter (where l.health_status in ('monitor','replace_soon'))::bigint,
    count(*) filter (where l.health_status = 'replace_now')::bigint,
    count(*) filter (where l.health_status = 'failed')::bigint,
    count(*) filter (where l.runtime_meets_spec = false)::bigint,
    count(*) filter (where l.replacement_due_date < current_date)::bigint,
    round(100.0 * count(*) filter (where l.health_status = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.battery_health_r3364 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3364_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3364_hospital_scorecard() to authenticated;

-- 3) Equipment type × battery chemistry matrix
create or replace function public.founder_r3364_equipment_chemistry_matrix()
returns table(equipment_type text, battery_chemistry text, devices bigint, healthy bigint, avg_degradation_pct numeric, avg_charge_cycles numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.battery_chemistry, count(*)::bigint,
    count(*) filter (where l.health_status = 'healthy')::bigint,
    round(avg(l.capacity_degradation_pct), 1),
    round(avg(l.charge_cycles), 0)
  from public.battery_health_r3364 l
  group by l.equipment_type, l.battery_chemistry
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3364_equipment_chemistry_matrix() from public, anon;
grant execute on function public.founder_r3364_equipment_chemistry_matrix() to authenticated;

-- 4) Daily assessment trend
create or replace function public.founder_r3364_daily_assessment_trend()
returns table(assessment_date date, devices bigint, healthy bigint, failed bigint, runtime_fail bigint, replace_now bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.assessment_date,
    count(*)::bigint,
    count(*) filter (where l.health_status = 'healthy')::bigint,
    count(*) filter (where l.health_status = 'failed')::bigint,
    count(*) filter (where l.runtime_meets_spec = false)::bigint,
    count(*) filter (where l.health_status = 'replace_now')::bigint
  from public.battery_health_r3364 l
  group by l.assessment_date
  order by l.assessment_date desc;
end;
$$;

revoke execute on function public.founder_r3364_daily_assessment_trend() from public, anon;
grant execute on function public.founder_r3364_daily_assessment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3364_capa_status_board()
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
  from public.battery_health_capa_actions_r3364 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3364_capa_status_board() from public, anon;
grant execute on function public.founder_r3364_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3364_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.battery_health_capa_actions_r3364)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.battery_health_capa_actions_r3364 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3364_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3364_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3364_regulatory_impact_digest()
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
  from public.battery_health_capa_actions_r3364 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3364_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3364_regulatory_impact_digest() to authenticated;

-- 8) High-risk battery queue (top individual concerns)
create or replace function public.founder_r3364_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  equipment_type text,
  battery_chemistry text,
  assessment_date date,
  measured_capacity_pct numeric,
  capacity_degradation_pct numeric,
  runtime_meets_spec boolean,
  health_status text,
  lifecycle_verdict text,
  replacement_due_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.equipment_type, l.battery_chemistry,
    l.assessment_date, l.measured_capacity_pct, l.capacity_degradation_pct,
    l.runtime_meets_spec, l.health_status, l.lifecycle_verdict, l.replacement_due_date, l.notes
  from public.battery_health_r3364 l
  where l.health_status in ('replace_soon','replace_now','failed')
     or l.lifecycle_verdict in ('replace_immediately','safety_risk')
     or l.runtime_meets_spec = false
     or l.replacement_due_date < current_date
  order by l.assessment_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3364_high_risk_queue() from public, anon;
grant execute on function public.founder_r3364_high_risk_queue() to authenticated;
