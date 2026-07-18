-- Round 3199: Customer Hospital OT & ICU UPS / Inverter Battery-Bank Health Audit
-- UPS QA log — location × capacity kVA × load % × bank voltage × backup runtime × transfer time × battery age × thermal scan × CAPA

-- =============================================================================
-- TABLE 1: ups_battery_r3199 — individual UPS / inverter battery-bank audits
-- =============================================================================
create table if not exists public.ups_battery_r3199 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ups_asset_tag text not null,
  ups_make_model text not null,
  ups_location text not null check (ups_location in (
    'operation_theatre','icu','nicu','cath_lab','pathology_lab',
    'radiology','server_room','blood_bank'
  )),
  audit_date date not null,
  audited_at timestamptz not null,
  ups_topology text not null check (ups_topology in (
    'online_double_conversion','line_interactive','offline_standby','modular_parallel_redundant'
  )),
  capacity_kva numeric(6,2) not null,
  measured_load_pct numeric(5,2) not null,
  battery_bank_voltage_v numeric(6,2) not null,
  nominal_bank_voltage_v numeric(6,2) not null,
  backup_runtime_min numeric(6,2),
  transfer_time_ms numeric(6,2),
  battery_age_months int not null,
  battery_chemistry text not null check (battery_chemistry in (
    'vrla_smf','tubular_flooded','lithium_ion_lfp','nickel_cadmium'
  )),
  thermal_scan_result text not null check (thermal_scan_result in (
    'normal','warm_terminal','hot_spot_detected','thermal_runaway_risk','not_performed'
  )),
  audit_verdict text not null check (audit_verdict in (
    'healthy','watch','degraded','replace_battery_bank','critical_fail','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ups_battery_r3199 enable row level security;

create index if not exists idx_ups_battery_r3199_org on public.ups_battery_r3199(organization_id);
create index if not exists idx_ups_battery_r3199_date on public.ups_battery_r3199(audit_date);
create index if not exists idx_ups_battery_r3199_verdict on public.ups_battery_r3199(audit_verdict);

-- =============================================================================
-- TABLE 2: ups_battery_capa_actions_r3199 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ups_battery_capa_actions_r3199 (
  id uuid primary key default gen_random_uuid(),
  ups_audit_id uuid not null references public.ups_battery_r3199(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'runtime_below_spec','battery_end_of_life','thermal_hot_spot','transfer_time_exceeded',
    'overload_condition','voltage_imbalance','ventilation_inadequate','bypass_left_engaged','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'battery_sulfation_aged','cell_internal_short','charger_float_mis_set','room_temperature_high',
    'load_growth_unplanned','loose_terminal_connection','ventilation_blocked','pending_investigation','amc_service_lapsed'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_battery_bank','replace_faulty_cells','recalibrate_charger_float','torque_terminals_retest',
    'add_cooling_ventilation','redistribute_load','schedule_amc_visit','conduct_full_discharge_test','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','fire_safety_notifiable','none','internal_only','electrical_safety_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ups_battery_capa_actions_r3199 enable row level security;

create index if not exists idx_ups_capa_r3199_audit on public.ups_battery_capa_actions_r3199(ups_audit_id);
create index if not exists idx_ups_capa_r3199_status on public.ups_battery_capa_actions_r3199(capa_status);

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

  -- 14 UPS battery-bank audit rows
  insert into public.ups_battery_r3199 (
    organization_id, hospital_name, ups_asset_tag, ups_make_model, ups_location,
    audit_date, audited_at, ups_topology,
    capacity_kva, measured_load_pct, battery_bank_voltage_v, nominal_bank_voltage_v,
    backup_runtime_min, transfer_time_ms, battery_age_months,
    battery_chemistry, thermal_scan_result, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.tag, q.model, q.loc,
    q.ad::date, q.adt::timestamptz, q.topo,
    q.kva, q.ld, q.bbv, q.nbv,
    q.rt, q.tt, q.age,
    q.chem, q.scan, q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','UPS-APL-OT-01','Emerson Liebert NXC 60','operation_theatre','2026-07-10','2026-07-10 06:30:00+05:30','online_double_conversion',
     60.00,48.50,432.10,432.00,42.00,0.00,14,'vrla_smf','normal','healthy','OT wing UPS healthy — runtime above 30-min spec'),
    ('Apollo Hyderabad Jubilee Hills','UPS-APL-ICU-02','APC Galaxy VS 40','icu','2026-07-10','2026-07-10 07:15:00+05:30','online_double_conversion',
     40.00,72.30,428.60,432.00,18.50,0.00,38,'vrla_smf','warm_terminal','watch','Runtime trending down — bank at 38 months'),
    ('Fortis Bannerghatta Bengaluru','UPS-FRT-OT-01','Vertiv Liebert ITA2 30','operation_theatre','2026-07-09','2026-07-09 05:45:00+05:30','online_double_conversion',
     30.00,81.40,415.20,432.00,9.80,0.00,52,'vrla_smf','hot_spot_detected','replace_battery_bank','Runtime 9.8 min vs 30-min spec — bank past end of life'),
    ('Fortis Bannerghatta Bengaluru','UPS-FRT-SRV-03','Schneider Smart-UPS SRT 10','server_room','2026-07-09','2026-07-09 06:30:00+05:30','online_double_conversion',
     10.00,64.00,192.40,192.00,25.60,0.00,20,'lithium_ion_lfp','normal','healthy','HIS server room — LFP bank stable'),
    ('Manipal Whitefield Bengaluru','UPS-MNP-ICU-01','Emerson Liebert NX 80','icu','2026-07-08','2026-07-08 08:00:00+05:30','modular_parallel_redundant',
     80.00,55.20,430.80,432.00,33.40,0.00,26,'vrla_smf','normal','healthy','N+1 modular — both strings balanced'),
    ('Manipal Whitefield Bengaluru','UPS-MNP-LAB-04','Numeric Digital HP 20','pathology_lab','2026-07-08','2026-07-08 09:10:00+05:30','line_interactive',
     20.00,88.60,238.90,240.00,7.20,6.80,44,'tubular_flooded','warm_terminal','degraded','Overloaded at 88% — analyzers tripped last month'),
    ('AIIMS New Delhi Ansari Nagar','UPS-AIM-OT-02','Vertiv Liebert EXM 100','operation_theatre','2026-07-07','2026-07-07 06:15:00+05:30','online_double_conversion',
     100.00,61.70,478.30,480.00,36.90,0.00,17,'vrla_smf','normal','healthy','Central OT block audit clean'),
    ('AIIMS New Delhi Ansari Nagar','UPS-AIM-CTH-05','APC Galaxy 5500 60','cath_lab','2026-07-07','2026-07-07 07:40:00+05:30','online_double_conversion',
     60.00,69.90,411.50,432.00,11.30,0.00,49,'vrla_smf','thermal_runaway_risk','critical_fail','Cell 18 bulging at 61C — immediate isolation ordered'),
    ('KIMS Secunderabad','UPS-KIM-ICU-01','Consul Neowatt Falcon 40','icu','2026-07-06','2026-07-06 05:50:00+05:30','online_double_conversion',
     40.00,58.40,425.70,432.00,22.10,0.00,31,'vrla_smf','normal','watch','Bank 6.3V below nominal — float charger check due'),
    ('Care Hospitals Banjara Hills','UPS-CAR-SRV-02','Schneider Smart-UPS SRT 8','server_room','2026-07-05','2026-07-05 09:30:00+05:30','line_interactive',
     8.00,42.10,190.80,192.00,28.70,8.40,23,'vrla_smf','normal','healthy','PACS server room within spec'),
    ('Yashoda Somajiguda Hyderabad','UPS-YSH-OT-03','Vertiv Liebert ITA2 40','operation_theatre','2026-07-04','2026-07-04 06:45:00+05:30','online_double_conversion',
     40.00,77.80,421.90,432.00,13.60,0.00,41,'vrla_smf','hot_spot_detected','degraded','Terminal hot spot 58C on string B — torque check needed'),
    ('St John''s Bengaluru','UPS-STJ-BLB-01','Numeric Digital HP 10','blood_bank','2026-07-03','2026-07-03 08:20:00+05:30','offline_standby',
     10.00,35.60,118.70,120.00,19.40,12.60,29,'tubular_flooded','not_performed','pending_review','Thermal camera unavailable — rescan scheduled'),
    ('Rainbow Children''s Hyderabad','UPS-RBW-NIC-01','APC Galaxy VS 30','nicu','2026-07-02','2026-07-02 07:10:00+05:30','online_double_conversion',
     30.00,66.20,429.40,432.00,31.80,0.00,12,'vrla_smf','normal','healthy','NICU bank new — commissioning audit passed'),
    ('Rainbow Children''s Hyderabad','UPS-RBW-RAD-02','Consul Neowatt Falcon 20','radiology','2026-07-02','2026-07-02 08:30:00+05:30','line_interactive',
     20.00,74.50,236.20,240.00,9.10,7.90,47,'vrla_smf','warm_terminal','replace_battery_bank','CT console UPS below 10-min runtime — replacement quoted')
  ) as q(hosp, tag, model, loc, ad, adt, topo, kva, ld, bbv, nbv, rt, tt, age, chem, scan, vd, nt);

  -- CAPA seed — attach to specific UPS audits by asset tag
  insert into public.ups_battery_capa_actions_r3199 (
    ups_audit_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cst, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('UPS-FRT-OT-01','battery_end_of_life','battery_sulfation_aged','replace_battery_bank','in_progress','nabh_finding','2026-07-20',null,485000.00,'40-jar 12V 42Ah bank quoted — PO raised'),
    ('UPS-AIM-CTH-05','thermal_hot_spot','cell_internal_short','replace_faulty_cells','escalated','patient_safety_alert','2026-07-12',null,96000.00,'Bulging cell isolated — cath lab on raw-power bypass risk'),
    ('UPS-MNP-LAB-04','overload_condition','load_growth_unplanned','redistribute_load','open','electrical_safety_deviation','2026-07-25',null,18000.00,'Move two analyzers to spare feeder'),
    ('UPS-YSH-OT-03','thermal_hot_spot','loose_terminal_connection','torque_terminals_retest','closed','internal_only','2026-07-08','2026-07-07',2500.00,'All inter-cell links re-torqued to 11 Nm — rescan normal'),
    ('UPS-KIM-ICU-01','voltage_imbalance','charger_float_mis_set','recalibrate_charger_float','verification_pending','none','2026-07-15',null,4000.00,'Float raised to 2.27 V/cell — 72h observation running'),
    ('UPS-RBW-RAD-02','runtime_below_spec','amc_service_lapsed','schedule_amc_visit','overdue','nabh_finding','2026-07-01',null,262000.00,'AMC lapsed in March — replacement bank plus AMC renewal quote')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ups_battery_r3199 e
    on e.organization_id = v_org_id and e.ups_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3199_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ups_battery_r3199)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ups_battery_r3199 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3199_verdict_rollup() from public, anon;
grant execute on function public.founder_r3199_verdict_rollup() to authenticated;

-- 2) Hospital-level battery-bank scorecard
create or replace function public.founder_r3199_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  healthy bigint,
  watch bigint,
  degraded bigint,
  replace_needed bigint,
  critical_fail bigint,
  avg_runtime_min numeric,
  avg_battery_age_months numeric,
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
    count(*) filter (where l.audit_verdict = 'healthy')::bigint,
    count(*) filter (where l.audit_verdict = 'watch')::bigint,
    count(*) filter (where l.audit_verdict = 'degraded')::bigint,
    count(*) filter (where l.audit_verdict = 'replace_battery_bank')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_fail')::bigint,
    round(avg(l.backup_runtime_min), 1),
    round(avg(l.battery_age_months), 1),
    round(100.0 * count(*) filter (where l.audit_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.ups_battery_r3199 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3199_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3199_hospital_scorecard() to authenticated;

-- 3) Location × topology breakdown
create or replace function public.founder_r3199_location_topology_matrix()
returns table(ups_location text, ups_topology text, audits bigint, avg_load_pct numeric, avg_runtime_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ups_location, l.ups_topology, count(*)::bigint,
    round(avg(l.measured_load_pct), 1),
    round(avg(l.backup_runtime_min), 1)
  from public.ups_battery_r3199 l
  group by l.ups_location, l.ups_topology
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3199_location_topology_matrix() from public, anon;
grant execute on function public.founder_r3199_location_topology_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3199_daily_trend()
returns table(audit_date date, audits bigint, healthy bigint, watch bigint, degraded_or_replace bigint, critical_fail bigint, avg_runtime_min numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'healthy')::bigint,
    count(*) filter (where l.audit_verdict = 'watch')::bigint,
    count(*) filter (where l.audit_verdict in ('degraded','replace_battery_bank'))::bigint,
    count(*) filter (where l.audit_verdict = 'critical_fail')::bigint,
    round(avg(l.backup_runtime_min), 1)
  from public.ups_battery_r3199 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3199_daily_trend() from public, anon;
grant execute on function public.founder_r3199_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3199_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees), 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ups_battery_capa_actions_r3199 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3199_capa_status_board() from public, anon;
grant execute on function public.founder_r3199_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3199_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ups_battery_capa_actions_r3199)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ups_battery_capa_actions_r3199 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3199_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3199_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3199_regulatory_impact_digest()
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
  from public.ups_battery_capa_actions_r3199 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3199_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3199_regulatory_impact_digest() to authenticated;

-- 8) High-risk UPS queue (top individual concerns)
create or replace function public.founder_r3199_high_risk_queue()
returns table(
  hospital_name text,
  ups_asset_tag text,
  ups_location text,
  audit_date date,
  audit_verdict text,
  thermal_scan_result text,
  backup_runtime_min numeric,
  battery_age_months int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ups_asset_tag, l.ups_location, l.audit_date,
    l.audit_verdict, l.thermal_scan_result, l.backup_runtime_min, l.battery_age_months, l.notes
  from public.ups_battery_r3199 l
  where l.audit_verdict in ('degraded','replace_battery_bank','critical_fail','pending_review')
     or l.thermal_scan_result in ('hot_spot_detected','thermal_runaway_risk')
     or l.backup_runtime_min < 15
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3199_high_risk_queue() from public, anon;
grant execute on function public.founder_r3199_high_risk_queue() to authenticated;
