-- Round 3370: Customer Hospital Central Medical-Gas Plant (Air / Vacuum / Manifold) QC Audit
-- Source-side plant QA — plant type × pressure setpoint × dew-point × air purity × duplex changeover × reserve bank × alarm panel × NRV × filter × ventilation × CAPA

-- =============================================================================
-- TABLE 1: medical_gas_plant_r3370 — per-plant / subsystem source-side QC checks
-- =============================================================================
create table if not exists public.medical_gas_plant_r3370 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  plant_code text not null,
  plant_type text not null check (plant_type in (
    'medical_air_compressor','medical_vacuum_plant','agss_scavenging',
    'manifold_room_oxygen','manifold_room_n2o','instrument_air'
  )),
  location text not null,
  check_date date not null,
  pressure_setpoint_ok boolean not null,
  dew_point_ok text not null check (dew_point_ok in (
    'ok','high_moisture','fail','not_applicable'
  )),
  air_purity_ok boolean not null,
  duplex_redundancy_ok boolean not null,
  reserve_bank_days numeric(5,1),
  alarm_panel_test text not null check (alarm_panel_test in (
    'pass','fail','not_tested'
  )),
  non_return_valve_ok boolean not null,
  filter_condition text not null check (filter_condition in (
    'clean','due','blocked','replace_due'
  )),
  plant_room_ventilation_ok boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','plant_shutdown_risk'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.medical_gas_plant_r3370 enable row level security;

create index if not exists idx_medical_gas_plant_r3370_org on public.medical_gas_plant_r3370(organization_id);
create index if not exists idx_medical_gas_plant_r3370_date on public.medical_gas_plant_r3370(check_date);
create index if not exists idx_medical_gas_plant_r3370_verdict on public.medical_gas_plant_r3370(qc_verdict);

-- =============================================================================
-- TABLE 2: medical_gas_plant_capa_actions_r3370 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.medical_gas_plant_capa_actions_r3370 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.medical_gas_plant_r3370(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pressure_setpoint_deviation','dew_point_high_moisture','air_purity_failure','duplex_changeover_failure',
    'low_reserve_bank','alarm_panel_failure','non_return_valve_fault','filter_blocked',
    'plant_room_ventilation_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compressor_wear','dryer_desiccant_exhausted','filter_saturation','changeover_valve_stuck',
    'regulator_drift','alarm_sensor_fault','check_valve_seized','ventilation_fan_failure',
    'oil_carryover','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'overhaul_compressor','replace_desiccant_dryer','replace_filter_element','service_changeover_valve',
    'recalibrate_regulator','replace_alarm_sensor','replace_non_return_valve','repair_ventilation_fan',
    'replenish_reserve_bank','retrain_plant_staff','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_7396_1_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.medical_gas_plant_capa_actions_r3370 enable row level security;

create index if not exists idx_medical_gas_plant_capa_r3370_log on public.medical_gas_plant_capa_actions_r3370(qc_log_id);
create index if not exists idx_medical_gas_plant_capa_r3370_status on public.medical_gas_plant_capa_actions_r3370(capa_status);

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

  -- 14 plant / subsystem QC rows
  insert into public.medical_gas_plant_r3370 (
    organization_id, hospital_name, plant_code, plant_type, location, check_date,
    pressure_setpoint_ok, dew_point_ok, air_purity_ok, duplex_redundancy_ok, reserve_bank_days,
    alarm_panel_test, non_return_valve_ok, filter_condition, plant_room_ventilation_ok,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ptype, q.loc, q.cd::date,
    q.pset, q.dew, q.purity, q.duplex, q.reserve::numeric,
    q.alarm, q.nrv, q.filt, q.vent,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','MGP-APL-AIR1','medical_air_compressor','Basement Plant Room A','2026-07-03',
     true,'ok',true,true,4.5,'pass',true,'clean',true,'pass','Duplex compressor plant nominal; dew point -46C at 4 bar'),
    ('Apollo Chennai Greams Road','MGP-APL-VAC1','medical_vacuum_plant','Basement Plant Room A','2026-07-03',
     true,'not_applicable',true,true,3.0,'pass',true,'clean',true,'pass','Triplex vacuum plant; auto-changeover verified on all pumps'),
    ('Fortis Gurgaon','MGP-FRT-AIR1','medical_air_compressor','Utility Block Level -1','2026-07-02',
     true,'high_moisture',true,true,3.5,'pass',true,'due',true,'conditional_pass','Dew point risen to +2C — desiccant dryer nearing exhaustion'),
    ('Fortis Gurgaon','MGP-FRT-AGSS1','agss_scavenging','OT Complex 2nd Floor','2026-07-02',
     false,'not_applicable',true,false,null,'fail',true,'due',true,'fail','AGSS flow low across 4 theatres; standby blower not starting on changeover'),
    ('Manipal Bengaluru Old Airport Rd','MGP-MNP-O2M1','manifold_room_oxygen','Oxygen Manifold Room','2026-07-01',
     true,'not_applicable',true,true,1.5,'pass',true,'clean',true,'conditional_pass','Reserve cylinder bank down to 1.5 days — refill order raised'),
    ('Manipal Bengaluru Old Airport Rd','MGP-MNP-VAC1','medical_vacuum_plant','Basement Utility','2026-07-01',
     true,'not_applicable',true,false,2.5,'pass',true,'clean',true,'fail','Auto-changeover to standby vacuum pump failed on test — running single pump'),
    ('AIIMS Delhi Ansari Nagar','MGP-AIM-AIR1','medical_air_compressor','Plant Room Block C','2026-06-30',
     true,'ok',false,true,4.0,'pass',true,'due',true,'plant_shutdown_risk','CO 6 ppm above 5 ppm limit and oil carryover detected — plant isolation risk'),
    ('AIIMS Delhi Ansari Nagar','MGP-AIM-N2O1','manifold_room_n2o','N2O Manifold Room','2026-06-30',
     true,'not_applicable',true,true,5.5,'pass',true,'clean',true,'pass','N2O manifold nominal; non-return valves and alarms verified'),
    ('CMC Vellore','MGP-CMC-IA1','instrument_air','Biomedical Plant Room','2026-06-29',
     true,'ok',true,true,3.0,'pass',true,'clean',true,'pass','Instrument air (powered surgical tools) dew point and purity within spec'),
    ('CMC Vellore','MGP-CMC-AGSS1','agss_scavenging','OT Complex Ground Floor','2026-06-29',
     true,'not_applicable',true,true,null,'pass',true,'clean',false,'conditional_pass','Plant room ventilation fan tripping on overload — ambient rising, service due'),
    ('KIMS Hyderabad','MGP-KIM-AIR1','medical_air_compressor','Basement Plant Room','2026-06-28',
     true,'high_moisture',true,true,3.5,'pass',true,'blocked',true,'fail','Intake and coalescing filters blocked; dew point high — plant output derated'),
    ('KIMS Hyderabad','MGP-KIM-O2M1','manifold_room_oxygen','Oxygen Manifold Room','2026-06-28',
     true,'not_applicable',true,true,2.0,'fail',true,'clean',true,'plant_shutdown_risk','Master alarm panel dead — no O2 low-pressure annunciation to hospital'),
    ('Narayana Health Bengaluru','MGP-NAR-VAC1','medical_vacuum_plant','Health City Utility','2026-06-27',
     true,'not_applicable',true,true,3.5,'pass',true,'clean',true,'pass','Vacuum plant post-AMC verification clean; changeover and NRV verified'),
    ('Medanta Gurugram','MGP-MED-AIR1','medical_air_compressor','Utility Basement','2026-06-27',
     true,'ok',true,true,4.0,'not_tested',false,'clean',true,'conditional_pass','Standby compressor non-return valve back-leaking; alarm panel test deferred')
  ) as q(hosp, code, ptype, loc, cd, pset, dew, purity, duplex, reserve, alarm, nrv, filt, vent, verdict, nt);

  -- CAPA seed — attach to specific plants via plant_code
  insert into public.medical_gas_plant_capa_actions_r3370 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('MGP-FRT-AGSS1','duplex_changeover_failure','changeover_valve_stuck','service_changeover_valve','escalated','patient_safety_alert','2026-07-06',null,55000.00,'AGSS standby blower not starting — 4 theatres on single blower, OEM escalated'),
    ('MGP-MNP-VAC1','duplex_changeover_failure','changeover_valve_stuck','service_changeover_valve','in_progress','iso_7396_1_deviation','2026-07-05',null,38000.00,'Changeover to standby vacuum pump failed on test — solenoid on order'),
    ('MGP-AIM-AIR1','air_purity_failure','oil_carryover','overhaul_compressor','open','cdsco_notifiable','2026-07-04',null,145000.00,'CO 6 ppm and oil carryover — compressor overhaul plus coalescing filter change'),
    ('MGP-CMC-AGSS1','plant_room_ventilation_fault','ventilation_fan_failure','repair_ventilation_fan','verification_pending','internal_only','2026-07-02',null,9500.00,'Ventilation fan overload relay replaced — verify plant room temp on recheck'),
    ('MGP-KIM-AIR1','filter_blocked','filter_saturation','replace_filter_element','closed','nabh_finding','2026-07-01','2026-06-29',22000.00,'Intake plus coalescing filters and desiccant replaced; dew point back to -44C'),
    ('MGP-KIM-O2M1','alarm_panel_failure','alarm_sensor_fault','replace_alarm_sensor','escalated','patient_safety_alert','2026-07-01',null,67000.00,'Master alarm panel dead — no O2 low-pressure annunciation; temporary manned watch'),
    ('MGP-MED-AIR1','non_return_valve_fault','check_valve_seized','replace_non_return_valve','overdue','internal_only','2026-06-25',null,14000.00,'Standby compressor NRV back-leak; alarm panel test still deferred — past target')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.medical_gas_plant_r3370 e
    on e.organization_id = v_org_id and e.plant_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3370_qc_verdict_rollup()
returns table(qc_verdict text, plants bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.medical_gas_plant_r3370)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.medical_gas_plant_r3370 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3370_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3370_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3370_hospital_scorecard()
returns table(
  hospital_name text,
  total_plants bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  dew_point_issues bigint,
  air_purity_fail bigint,
  duplex_fail bigint,
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
    count(*) filter (where l.qc_verdict in ('fail','plant_shutdown_risk'))::bigint,
    count(*) filter (where l.dew_point_ok in ('high_moisture','fail'))::bigint,
    count(*) filter (where l.air_purity_ok = false)::bigint,
    count(*) filter (where l.duplex_redundancy_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.medical_gas_plant_r3370 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3370_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3370_hospital_scorecard() to authenticated;

-- 3) Plant type × dew-point condition matrix
create or replace function public.founder_r3370_plant_dewpoint_matrix()
returns table(plant_type text, dew_point_ok text, plants bigint, passed bigint, avg_reserve_bank_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.plant_type, l.dew_point_ok, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.reserve_bank_days), 1)
  from public.medical_gas_plant_r3370 l
  group by l.plant_type, l.dew_point_ok
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3370_plant_dewpoint_matrix() from public, anon;
grant execute on function public.founder_r3370_plant_dewpoint_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3370_daily_qc_trend()
returns table(check_date date, plants bigint, passed bigint, failed bigint, shutdown_risk bigint, dew_point_issues bigint)
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.qc_verdict = 'plant_shutdown_risk')::bigint,
    count(*) filter (where l.dew_point_ok in ('high_moisture','fail'))::bigint
  from public.medical_gas_plant_r3370 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3370_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3370_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3370_capa_status_board()
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
  from public.medical_gas_plant_capa_actions_r3370 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3370_capa_status_board() from public, anon;
grant execute on function public.founder_r3370_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3370_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.medical_gas_plant_capa_actions_r3370)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.medical_gas_plant_capa_actions_r3370 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3370_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3370_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3370_regulatory_impact_digest()
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
  from public.medical_gas_plant_capa_actions_r3370 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3370_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3370_regulatory_impact_digest() to authenticated;

-- 8) High-risk plant QC queue (top individual concerns)
create or replace function public.founder_r3370_high_risk_queue()
returns table(
  hospital_name text,
  plant_code text,
  plant_type text,
  location text,
  check_date date,
  qc_verdict text,
  dew_point_ok text,
  alarm_panel_test text,
  filter_condition text,
  reserve_bank_days numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.plant_code, l.plant_type, l.location, l.check_date,
    l.qc_verdict, l.dew_point_ok, l.alarm_panel_test, l.filter_condition, l.reserve_bank_days, l.notes
  from public.medical_gas_plant_r3370 l
  where l.qc_verdict in ('conditional_pass','fail','plant_shutdown_risk')
     or l.dew_point_ok in ('high_moisture','fail')
     or l.air_purity_ok = false
     or l.duplex_redundancy_ok = false
     or l.alarm_panel_test = 'fail'
     or l.filter_condition in ('blocked','replace_due')
     or l.non_return_valve_ok = false
     or l.plant_room_ventilation_ok = false
     or l.reserve_bank_days < 2
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3370_high_risk_queue() from public, anon;
grant execute on function public.founder_r3370_high_risk_queue() to authenticated;
