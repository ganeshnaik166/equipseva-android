-- Round 3384: Engineer Customer-Site Power-Quality, Voltage-Stabilizer, Isolation-Transformer & UPS Site-Audit Tracker
-- Field electrical audit — equipment protected × region × voltage stability × earthing × isolation transformer × stabilizer × UPS runtime × spike/surge × CAPA

-- =============================================================================
-- TABLE 1: power_quality_audit_r3384 — per customer-site electrical environment audit
-- =============================================================================
create table if not exists public.power_quality_audit_r3384 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  hospital_name text not null,
  region text not null,
  audit_code text not null,
  equipment_protected text not null check (equipment_protected in (
    'mri','ct','cath_lab','lab_analyzers','dialysis','patient_monitoring','server_room'
  )),
  audit_date date not null,
  mains_voltage_stable boolean not null,
  voltage_range_ok text not null check (voltage_range_ok in (
    'ok','high','low','fluctuating'
  )),
  earthing_resistance_ohm numeric(6,2),
  earthing_within_spec boolean not null,
  isolation_transformer_ok text not null check (isolation_transformer_ok in (
    'ok','fault','not_present','not_required'
  )),
  stabilizer_function_ok boolean not null,
  ups_runtime_minutes numeric(6,1),
  ups_runtime_adequate boolean not null,
  spike_surge_protection_ok boolean not null,
  neutral_earth_voltage_ok boolean not null,
  power_events_last_90 int not null,
  power_verdict text not null check (power_verdict in (
    'healthy','stabilizer_action','earthing_fault','ups_upgrade','spike_risk','critical_power_risk'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.power_quality_audit_r3384 enable row level security;

create index if not exists idx_power_quality_r3384_org on public.power_quality_audit_r3384(organization_id);
create index if not exists idx_power_quality_r3384_date on public.power_quality_audit_r3384(audit_date);
create index if not exists idx_power_quality_r3384_verdict on public.power_quality_audit_r3384(power_verdict);

-- =============================================================================
-- TABLE 2: power_quality_capa_actions_r3384 — electrical rectification CAPA actions
-- =============================================================================
create table if not exists public.power_quality_capa_actions_r3384 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.power_quality_audit_r3384(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'voltage_instability','earthing_out_of_spec','isolation_transformer_fault','stabilizer_malfunction',
    'ups_runtime_shortfall','spike_surge_exposure','neutral_earth_voltage_high','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'utility_supply_fluctuation','earth_pit_dried_out','loose_neutral_connection','stabilizer_relay_worn',
    'ups_battery_aged','missing_surge_arrestor','transformer_winding_fault','load_growth_uncounted',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'install_servo_stabilizer','recondition_earth_pit','tighten_neutral_bonding','replace_ups_battery_bank',
    'install_surge_protection_device','replace_isolation_transformer','upgrade_ups_capacity','retrain_site_electrician',
    'schedule_oem_service','escalate_to_utility','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cea_electrical_safety','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.power_quality_capa_actions_r3384 enable row level security;

create index if not exists idx_power_quality_capa_r3384_audit on public.power_quality_capa_actions_r3384(audit_id);
create index if not exists idx_power_quality_capa_r3384_status on public.power_quality_capa_actions_r3384(capa_status);

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

  -- 14 site-audit rows
  insert into public.power_quality_audit_r3384 (
    organization_id, engineer_name, hospital_name, region, audit_code, equipment_protected,
    audit_date, mains_voltage_stable, voltage_range_ok,
    earthing_resistance_ohm, earthing_within_spec, isolation_transformer_ok,
    stabilizer_function_ok, ups_runtime_minutes, ups_runtime_adequate,
    spike_surge_protection_ok, neutral_earth_voltage_ok, power_events_last_90,
    power_verdict, notes
  )
  select v_org_id, q.eng, q.hosp, q.reg, q.code, q.equip,
    q.adate::date, q.mvs, q.vro,
    q.eres, q.ews, q.ito,
    q.sfo, q.upm, q.upa,
    q.ssp, q.nev, q.pe90::int,
    q.pv, q.nt
  from (values
    ('Ramesh Iyer','Apollo Chennai Greams Road','South','PQ-APL-01','mri','2026-07-03',
     true,'ok',0.85,true,'ok',true,42.0,true,true,true,2,'healthy','Quarterly power audit — earth pit 0.85 ohm, all parameters nominal'),
    ('Ramesh Iyer','Apollo Chennai Greams Road','South','PQ-APL-02','ct','2026-07-03',
     false,'fluctuating',1.20,true,'ok',true,38.0,true,true,true,9,'stabilizer_action','CT feeder swinging plus-minus 12 percent — servo stabilizer recommended'),
    ('Anil Kumar','Fortis Gurgaon','North','PQ-FRT-01','cath_lab','2026-07-02',
     true,'ok',5.60,false,'ok',true,35.0,true,true,false,6,'earthing_fault','Earth resistance 5.6 ohm above 5 ohm spec, neutral-earth voltage 3.8V high'),
    ('Anil Kumar','Fortis Gurgaon','North','PQ-FRT-02','lab_analyzers','2026-07-02',
     false,'high',0.90,true,'not_required',true,28.0,false,true,true,4,'ups_upgrade','Lab UPS runtime 28 min below 45 min target for analyzers, mains often high'),
    ('Suresh Nair','Manipal Bengaluru Old Airport Rd','South','PQ-MNP-01','dialysis','2026-07-01',
     true,'ok',1.10,true,'ok',true,55.0,true,true,true,1,'healthy','Dialysis water plant supply stable, UPS 55 min autonomy'),
    ('Suresh Nair','Manipal Bengaluru Old Airport Rd','South','PQ-MNP-02','patient_monitoring','2026-07-01',
     true,'ok',2.40,true,'fault',true,40.0,true,false,true,7,'spike_risk','OT isolation transformer faulted, surge arrestor missing on ICU feeder'),
    ('Deepak Sharma','AIIMS Delhi Ansari Nagar','North','PQ-AIM-01','mri','2026-06-30',
     false,'low',0.70,true,'ok',false,32.0,false,true,true,11,'critical_power_risk','MRI mains sagging low, stabilizer not correcting, UPS runtime short — critical'),
    ('Deepak Sharma','AIIMS Delhi Ansari Nagar','North','PQ-AIM-02','server_room','2026-06-30',
     true,'ok',0.95,true,'not_required',true,120.0,true,true,true,3,'healthy','Data centre dual-UPS, 120 min autonomy verified'),
    ('Thomas Varghese','CMC Vellore','South','PQ-CMC-01','ct','2026-06-29',
     true,'ok',6.80,false,'ok',true,44.0,true,true,false,5,'earthing_fault','Earth pit dried out 6.8 ohm, neutral-earth voltage 4.1V — pit reconditioning raised'),
    ('Thomas Varghese','CMC Vellore','South','PQ-CMC-02','lab_analyzers','2026-06-29',
     true,'ok',1.00,true,'ok',true,50.0,true,true,true,2,'healthy','Central lab supply healthy, all checks in spec'),
    ('Rajesh Patil','Kokilaben Mumbai','West','PQ-KOK-01','cath_lab','2026-06-28',
     false,'fluctuating',1.30,true,'ok',false,30.0,false,false,true,14,'critical_power_risk','Cath-lab stabilizer relay chattering, UPS aged, 14 power events in 90 days'),
    ('Rajesh Patil','Kokilaben Mumbai','West','PQ-KOK-02','patient_monitoring','2026-06-28',
     true,'ok',null,true,'ok',true,null,true,true,true,2,'healthy','Routine — earth and UPS not retested this cycle, prior values in spec'),
    ('Sourav Banerjee','AMRI Kolkata Dhakuria','East','PQ-AMR-01','dialysis','2026-06-27',
     true,'high',1.50,true,'ok',true,36.0,false,true,true,8,'ups_upgrade','Dialysis UPS 36 min short of 60 min target, mains frequently high'),
    ('Sourav Banerjee','AMRI Kolkata Dhakuria','East','PQ-AMR-02','mri','2026-06-27',
     true,'ok',2.10,true,'not_present',true,48.0,true,false,true,6,'spike_risk','MRI feeder no isolation transformer, surge protection absent — SPD proposed')
  ) as q(eng, hosp, reg, code, equip, adate, mvs, vro, eres, ews, ito, sfo, upm, upa, ssp, nev, pe90, pv, nt);

  -- CAPA seed — attach to specific audits by audit_code
  insert into public.power_quality_capa_actions_r3384 (
    audit_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PQ-FRT-01','earthing_out_of_spec','earth_pit_dried_out','recondition_earth_pit','in_progress','cea_electrical_safety','2026-07-09',null,45000.00,'Earth pit reconditioning scheduled, neutral-earth voltage to be rechecked'),
    ('PQ-AIM-01','voltage_instability','utility_supply_fluctuation','install_servo_stabilizer','escalated','patient_safety_alert','2026-07-06',null,180000.00,'MRI critical — 40kVA servo stabilizer quote raised, utility escalation open'),
    ('PQ-KOK-01','ups_runtime_shortfall','ups_battery_aged','replace_ups_battery_bank','open','nabh_finding','2026-07-10',null,220000.00,'Cath-lab UPS battery bank end-of-life, replacement PO pending'),
    ('PQ-MNP-02','isolation_transformer_fault','transformer_winding_fault','replace_isolation_transformer','open','patient_safety_alert','2026-07-08',null,135000.00,'OT isolation transformer faulted — supply on temporary bypass'),
    ('PQ-FRT-02','ups_runtime_shortfall','load_growth_uncounted','upgrade_ups_capacity','verification_pending','internal_only','2026-07-05',null,96000.00,'Lab load grew, UPS upsized to 20kVA — verify runtime on next visit'),
    ('PQ-CMC-01','earthing_out_of_spec','earth_pit_dried_out','recondition_earth_pit','closed','iso_13485_deviation','2026-07-01','2026-06-30',38000.00,'Earth pit watered and salted, resistance back to 1.9 ohm'),
    ('PQ-AMR-02','spike_surge_exposure','missing_surge_arrestor','install_surge_protection_device','overdue','internal_only','2026-06-26',null,28000.00,'SPD install past target date — vendor mobilisation delayed')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.power_quality_audit_r3384 e
    on e.organization_id = v_org_id and e.audit_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Power verdict distribution
create or replace function public.founder_r3384_power_verdict_rollup()
returns table(power_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.power_quality_audit_r3384)
  select l.power_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.power_quality_audit_r3384 l
  group by l.power_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3384_power_verdict_rollup() from public, anon;
grant execute on function public.founder_r3384_power_verdict_rollup() to authenticated;

-- 2) Hospital power-quality scorecard
create or replace function public.founder_r3384_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  healthy bigint,
  action_needed bigint,
  critical bigint,
  earthing_fail bigint,
  ups_inadequate bigint,
  spike_exposed bigint,
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
    count(*) filter (where l.power_verdict = 'healthy')::bigint,
    count(*) filter (where l.power_verdict in ('stabilizer_action','earthing_fault','ups_upgrade','spike_risk'))::bigint,
    count(*) filter (where l.power_verdict = 'critical_power_risk')::bigint,
    count(*) filter (where l.earthing_within_spec = false)::bigint,
    count(*) filter (where l.ups_runtime_adequate = false)::bigint,
    count(*) filter (where l.spike_surge_protection_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.power_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.power_quality_audit_r3384 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3384_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3384_hospital_scorecard() to authenticated;

-- 3) Equipment protected × region matrix
create or replace function public.founder_r3384_equipment_region_matrix()
returns table(equipment_protected text, region text, audits bigint, healthy bigint, avg_earthing_ohm numeric, avg_ups_minutes numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_protected, l.region, count(*)::bigint,
    count(*) filter (where l.power_verdict = 'healthy')::bigint,
    round(avg(l.earthing_resistance_ohm), 2),
    round(avg(l.ups_runtime_minutes), 1)
  from public.power_quality_audit_r3384 l
  group by l.equipment_protected, l.region
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3384_equipment_region_matrix() from public, anon;
grant execute on function public.founder_r3384_equipment_region_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3384_daily_audit_trend()
returns table(audit_date date, audits bigint, healthy bigint, critical bigint, earthing_fail bigint, ups_inadequate bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.power_verdict = 'healthy')::bigint,
    count(*) filter (where l.power_verdict = 'critical_power_risk')::bigint,
    count(*) filter (where l.earthing_within_spec = false)::bigint,
    count(*) filter (where l.ups_runtime_adequate = false)::bigint
  from public.power_quality_audit_r3384 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3384_daily_audit_trend() from public, anon;
grant execute on function public.founder_r3384_daily_audit_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3384_capa_status_board()
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
  from public.power_quality_capa_actions_r3384 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3384_capa_status_board() from public, anon;
grant execute on function public.founder_r3384_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3384_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.power_quality_capa_actions_r3384)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.power_quality_capa_actions_r3384 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3384_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3384_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3384_regulatory_impact_digest()
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
  from public.power_quality_capa_actions_r3384 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3384_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3384_regulatory_impact_digest() to authenticated;

-- 8) High-risk power-quality queue (unhealthy or protection-gap sites)
create or replace function public.founder_r3384_high_risk_queue()
returns table(
  hospital_name text,
  region text,
  audit_code text,
  audit_date date,
  power_verdict text,
  voltage_range_ok text,
  earthing_status text,
  isolation_transformer_ok text,
  ups_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.region, l.audit_code, l.audit_date,
    l.power_verdict, l.voltage_range_ok,
    case when l.earthing_within_spec then 'within_spec' else 'out_of_spec' end,
    l.isolation_transformer_ok,
    case when l.ups_runtime_adequate then 'adequate' else 'inadequate' end,
    l.notes
  from public.power_quality_audit_r3384 l
  where l.power_verdict in ('stabilizer_action','earthing_fault','ups_upgrade','spike_risk','critical_power_risk')
     or l.earthing_within_spec = false
     or l.ups_runtime_adequate = false
     or l.spike_surge_protection_ok = false
     or l.neutral_earth_voltage_ok = false
     or l.mains_voltage_stable = false
     or l.isolation_transformer_ok = 'fault'
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3384_high_risk_queue() from public, anon;
grant execute on function public.founder_r3384_high_risk_queue() to authenticated;
