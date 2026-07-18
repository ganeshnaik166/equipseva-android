-- Round 3215: Customer Hospital Ambulance Equipment (Transport-Vent/Monitor/Suction) Readiness Audit
-- Ambulance QA log — vehicle reg × equipment category × battery hours × mounting × O2 cylinder pressure × inverter × last-drill × CAPA

-- =============================================================================
-- TABLE 1: ambulance_equip_r3215 — individual ambulance equipment readiness audits
-- =============================================================================
create table if not exists public.ambulance_equip_r3215 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ambulance_reg_no text not null,
  ambulance_type text not null check (ambulance_type in (
    'als_advanced_life_support','bls_basic_life_support','patient_transport_vehicle',
    'neonatal_ambulance','mobile_icu','organ_transport_vehicle'
  )),
  equipment_category text not null check (equipment_category in (
    'transport_ventilator','defibrillator_monitor','multipara_monitor',
    'suction_machine','oxygen_delivery','infusion_pump','scoop_stretcher_immobilization'
  )),
  equipment_make_model text not null,
  asset_tag text not null,
  audit_date date not null,
  battery_backup_hours numeric(4,1),
  battery_status text check (battery_status in (
    'healthy','degraded','needs_replacement','not_holding_charge','not_applicable'
  )),
  mounting_secure boolean not null default false,
  o2_cylinder_pressure_bar numeric(5,1),
  o2_pressure_verdict text check (o2_pressure_verdict in (
    'adequate','low_refill_needed','critical_empty','not_applicable'
  )),
  inverter_status text check (inverter_status in (
    'working','faulty','intermittent','not_installed'
  )),
  last_drill_date date,
  functional_test_result text not null check (functional_test_result in (
    'pass','fail','pass_with_observations','not_tested'
  )),
  auditor_profile_id uuid references public.profiles(id) on delete set null,
  readiness_verdict text not null check (readiness_verdict in (
    'road_ready','conditionally_ready','grounded','awaiting_parts','decommission_recommended','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ambulance_equip_r3215 enable row level security;

create index if not exists idx_ambulance_equip_r3215_org on public.ambulance_equip_r3215(organization_id);
create index if not exists idx_ambulance_equip_r3215_date on public.ambulance_equip_r3215(audit_date);
create index if not exists idx_ambulance_equip_r3215_verdict on public.ambulance_equip_r3215(readiness_verdict);

-- =============================================================================
-- TABLE 2: ambulance_equip_capa_actions_r3215 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ambulance_equip_capa_actions_r3215 (
  id uuid primary key default gen_random_uuid(),
  equip_audit_id uuid not null references public.ambulance_equip_r3215(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'battery_backup_low','mounting_loose','o2_pressure_low','inverter_fault',
    'functional_test_fail','drill_overdue','consumable_expired','calibration_overdue','physical_damage','documentation_gap'
  )),
  root_cause text not null check (root_cause in (
    'battery_end_of_life','vibration_loosened_bracket','o2_refill_vendor_delay',
    'inverter_wiring_fault','charger_dock_faulty','operator_training_gap',
    'amc_service_backlog','spare_unavailable','procurement_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_battery_pack','refit_mounting_bracket','refill_o2_cylinder',
    'repair_inverter_wiring','replace_charger_dock','conduct_mock_drill',
    'schedule_amc_visit','ground_vehicle_until_fix','swap_standby_unit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','state_transport_authority','none','internal_only','aers_reportable','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ambulance_equip_capa_actions_r3215 enable row level security;

create index if not exists idx_ambulance_capa_r3215_audit on public.ambulance_equip_capa_actions_r3215(equip_audit_id);
create index if not exists idx_ambulance_capa_r3215_status on public.ambulance_equip_capa_actions_r3215(capa_status);

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

  -- 14 audit rows
  insert into public.ambulance_equip_r3215 (
    organization_id, hospital_name, ambulance_reg_no, ambulance_type,
    equipment_category, equipment_make_model, asset_tag, audit_date,
    battery_backup_hours, battery_status, mounting_secure,
    o2_cylinder_pressure_bar, o2_pressure_verdict, inverter_status,
    last_drill_date, functional_test_result, readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.reg, q.atype,
    q.ecat, q.model, q.tag, q.ad::date,
    q.bh, q.bs, q.ms,
    q.o2p, q.o2v, q.inv,
    q.dr::date, q.ftr, q.rv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','TS09PA4521','als_advanced_life_support','transport_ventilator','Hamilton T1','AMB-APL-101','2026-07-02',
     6.5,'healthy',true,165.0,'adequate','working','2026-06-20','pass','road_ready','Vent passed full pre-departure checklist'),
    ('Apollo Hyderabad Jubilee Hills','TS09PA4521','als_advanced_life_support','defibrillator_monitor','Zoll X Series','AMB-APL-102','2026-07-02',
     2.1,'degraded',true,165.0,'adequate','working','2026-06-20','pass_with_observations','conditionally_ready','Defib battery holds only 2.1 hrs — replacement pack ordered'),
    ('Fortis Bannerghatta Bengaluru','KA01AJ7743','mobile_icu','transport_ventilator','Drager Oxylog 3000 Plus','AMB-FRT-201','2026-07-01',
     5.0,'healthy',false,142.0,'adequate','working','2026-05-28','fail','grounded','Vent bracket loose and flow-sensor fault — MICU grounded'),
    ('Fortis Bannerghatta Bengaluru','KA01AJ7743','mobile_icu','suction_machine','Laerdal LSU','AMB-FRT-202','2026-07-01',
     1.2,'needs_replacement',true,142.0,'adequate','working','2026-05-28','fail','grounded','Suction vacuum below 500 mmHg spec'),
    ('Manipal Whitefield Bengaluru','KA53MC9910','bls_basic_life_support','oxygen_delivery','BPC Flowmeter Twin Kit','AMB-MNP-301','2026-06-30',
     null,'not_applicable',true,58.0,'low_refill_needed','not_installed','2026-06-10','pass_with_observations','conditionally_ready','O2 at 58 bar — refill before next shift'),
    ('Manipal Whitefield Bengaluru','KA53MC9910','bls_basic_life_support','multipara_monitor','Mindray uMEC10','AMB-MNP-302','2026-06-30',
     4.0,'healthy',true,58.0,'low_refill_needed','not_installed','2026-06-10','pass','conditionally_ready','Monitor fine; vehicle held for O2 refill'),
    ('AIIMS New Delhi Ansari Nagar','DL01GC5566','neonatal_ambulance','transport_ventilator','Fanem Babypod Vent','AMB-AIM-401','2026-06-29',
     7.0,'healthy',true,178.0,'adequate','working','2026-06-25','pass','road_ready','Neonatal circuit leak test passed'),
    ('AIIMS New Delhi Ansari Nagar','DL01GC5567','als_advanced_life_support','infusion_pump','B Braun Perfusor Space','AMB-AIM-402','2026-06-29',
     3.5,'healthy',true,170.0,'adequate','intermittent','2026-04-02','pass_with_observations','conditionally_ready','Inverter output drops on ignition crank; quarterly drill overdue'),
    ('KIMS Secunderabad','TS08UB2214','als_advanced_life_support','defibrillator_monitor','Philips Tempus LS','AMB-KIM-501','2026-06-28',
     0.8,'not_holding_charge',true,130.0,'adequate','faulty',null,'fail','grounded','Defib battery dead and inverter fault — no drill on record'),
    ('KIMS Secunderabad','TS08UB2215','patient_transport_vehicle','suction_machine','SSCOR Quickdraw','AMB-KIM-502','2026-06-28',
     2.5,'degraded',false,12.0,'critical_empty','not_installed','2026-03-15','fail','grounded','O2 nearly empty and suction unit unsecured — PTV pulled from roster'),
    ('Care Hospitals Banjara Hills','TS09CB8830','als_advanced_life_support','multipara_monitor','Schiller Truscope','AMB-CAR-601','2026-06-27',
     5.5,'healthy',true,155.0,'adequate','working','2026-06-18','pass','road_ready','All parameters within spec'),
    ('Yashoda Somajiguda Hyderabad','TS09YD3341','mobile_icu','transport_ventilator','Hamilton T1','AMB-YSH-701','2026-06-27',
     6.0,'healthy',true,148.0,'adequate','working','2026-06-22','pass','road_ready','MICU cleared for cardiac transfers'),
    ('St John''s Bengaluru','KA01SJ6674','bls_basic_life_support','oxygen_delivery','Rotameter Twin Kit','AMB-STJ-801','2026-06-26',
     null,'not_applicable',true,95.0,'adequate','not_installed','2026-05-30','pass','road_ready','Humidifier bottle replaced during audit'),
    ('Rainbow Children''s Hyderabad','TS09RB2278','neonatal_ambulance','defibrillator_monitor','Zoll Propaq MD','AMB-RBW-901','2026-06-25',
     3.0,'degraded',true,88.0,'adequate','working',null,'pass_with_observations','pending_review','Paediatric pads expiring in 3 weeks; drill date not documented')
  ) as q(hosp, reg, atype, ecat, model, tag, ad, bh, bs, ms, o2p, o2v, inv, dr, ftr, rv, nt);

  -- CAPA seed — attach to specific audits by asset tag
  insert into public.ambulance_equip_capa_actions_r3215 (
    equip_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('AMB-APL-102','battery_backup_low','battery_end_of_life','replace_battery_pack','2026-07-10',null,'in_progress','internal_only',58000.00,'Zoll SurePower replacement pack on purchase order'),
    ('AMB-FRT-201','mounting_loose','vibration_loosened_bracket','refit_mounting_bracket','2026-07-04',null,'verification_pending','nabh_finding',6500.00,'Bracket re-torqued; road vibration test pending'),
    ('AMB-FRT-202','functional_test_fail','amc_service_backlog','schedule_amc_visit','2026-07-08',null,'escalated','patient_safety_alert',18000.00,'Suction below spec on grounded MICU — escalated to OEM service'),
    ('AMB-KIM-501','inverter_fault','inverter_wiring_fault','repair_inverter_wiring','2026-07-06',null,'open','state_transport_authority',9500.00,'Auto-electrician visit booked for wiring harness'),
    ('AMB-KIM-502','o2_pressure_low','o2_refill_vendor_delay','refill_o2_cylinder','2026-06-30','2026-06-29','closed','patient_safety_alert',1200.00,'Cylinder swapped from central manifold stock'),
    ('AMB-MNP-301','o2_pressure_low','o2_refill_vendor_delay','refill_o2_cylinder','2026-07-01','2026-07-01','closed','internal_only',1100.00,'Refilled same day; vendor SLA under review'),
    ('AMB-AIM-402','drill_overdue','operator_training_gap','conduct_mock_drill','2026-07-12',null,'open','nabh_finding',0.00,'Quarterly evacuation-and-equipment drill scheduled'),
    ('AMB-RBW-901','consumable_expired','procurement_delay','swap_standby_unit','2026-07-05',null,'overdue','patient_safety_alert',5400.00,'Paediatric pads past reorder point — standby unit deployed')
  ) as q(tag_key, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.ambulance_equip_r3215 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3215_readiness_verdict_rollup()
returns table(readiness_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ambulance_equip_r3215)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ambulance_equip_r3215 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3215_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3215_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3215_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  road_ready bigint,
  conditionally_ready bigint,
  grounded bigint,
  test_failures bigint,
  avg_battery_hours numeric,
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
    count(*) filter (where l.readiness_verdict = 'road_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'conditionally_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'grounded')::bigint,
    count(*) filter (where l.functional_test_result = 'fail')::bigint,
    round(avg(l.battery_backup_hours), 1),
    round(100.0 * count(*) filter (where l.readiness_verdict = 'road_ready')::numeric / nullif(count(*),0), 1)
  from public.ambulance_equip_r3215 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3215_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3215_hospital_scorecard() to authenticated;

-- 3) Equipment category × ambulance type matrix
create or replace function public.founder_r3215_equipment_type_matrix()
returns table(equipment_category text, ambulance_type text, audits bigint, road_ready bigint, avg_battery_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_category, l.ambulance_type, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'road_ready')::bigint,
    round(avg(l.battery_backup_hours), 1)
  from public.ambulance_equip_r3215 l
  group by l.equipment_category, l.ambulance_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3215_equipment_type_matrix() from public, anon;
grant execute on function public.founder_r3215_equipment_type_matrix() to authenticated;

-- 4) Daily readiness trend
create or replace function public.founder_r3215_daily_readiness_trend()
returns table(audit_date date, audits bigint, road_ready bigint, conditionally_ready bigint, grounded bigint, test_failures bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'road_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'conditionally_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'grounded')::bigint,
    count(*) filter (where l.functional_test_result = 'fail')::bigint
  from public.ambulance_equip_r3215 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3215_daily_readiness_trend() from public, anon;
grant execute on function public.founder_r3215_daily_readiness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3215_capa_status_board()
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
  from public.ambulance_equip_capa_actions_r3215 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3215_capa_status_board() from public, anon;
grant execute on function public.founder_r3215_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3215_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ambulance_equip_capa_actions_r3215)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ambulance_equip_capa_actions_r3215 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3215_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3215_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3215_regulatory_impact_digest()
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
  from public.ambulance_equip_capa_actions_r3215 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3215_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3215_regulatory_impact_digest() to authenticated;

-- 8) High-risk audits queue (top individual concerns)
create or replace function public.founder_r3215_high_risk_queue()
returns table(
  hospital_name text,
  ambulance_reg_no text,
  equipment_category text,
  asset_tag text,
  audit_date date,
  readiness_verdict text,
  battery_status text,
  o2_pressure_verdict text,
  inverter_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ambulance_reg_no, l.equipment_category, l.asset_tag, l.audit_date,
    l.readiness_verdict, l.battery_status, l.o2_pressure_verdict, l.inverter_status, l.notes
  from public.ambulance_equip_r3215 l
  where l.readiness_verdict in ('grounded','awaiting_parts','decommission_recommended','pending_review','conditionally_ready')
     or l.battery_status in ('needs_replacement','not_holding_charge')
     or l.o2_pressure_verdict in ('low_refill_needed','critical_empty')
     or l.inverter_status in ('faulty','intermittent')
     or l.functional_test_result = 'fail'
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3215_high_risk_queue() from public, anon;
grant execute on function public.founder_r3215_high_risk_queue() to authenticated;
