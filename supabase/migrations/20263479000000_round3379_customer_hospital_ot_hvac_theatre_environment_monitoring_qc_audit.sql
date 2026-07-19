-- Round 3379: Customer Hospital Operating-Theatre HVAC & Environment-Monitoring QC Audit
-- OT air QA — OT class × air-changes/hour × positive-pressure cascade × HEPA integrity × laminar-flow velocity × temp/humidity × ISO particle class × DP alarm × filter status × CAPA

-- =============================================================================
-- TABLE 1: ot_hvac_env_r3379 — per-OT HVAC & environment monitoring QC checks
-- =============================================================================
create table if not exists public.ot_hvac_env_r3379 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_code text not null,
  ot_class text not null check (ot_class in (
    'ultra_clean_laminar','conventional_positive_pressure','modular_ot','hybrid_ot','minor_ot'
  )),
  check_date date not null,
  air_changes_per_hour numeric(6,2),
  positive_pressure_pa numeric(6,2),
  hepa_filter_integrity_ok boolean,
  laminar_flow_velocity_ok text not null check (laminar_flow_velocity_ok in (
    'ok','low','fail','not_applicable'
  )),
  temperature_c numeric(4,1),
  humidity_pct numeric(5,2),
  temp_humidity_in_spec boolean not null,
  particle_count_iso_class text not null check (particle_count_iso_class in (
    'iso5','iso6','iso7','iso8','out_of_spec'
  )),
  differential_pressure_alarm_ok boolean not null,
  filter_replacement_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','ot_downgraded'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_hvac_env_r3379 enable row level security;

create index if not exists idx_ot_hvac_env_r3379_org on public.ot_hvac_env_r3379(organization_id);
create index if not exists idx_ot_hvac_env_r3379_date on public.ot_hvac_env_r3379(check_date);
create index if not exists idx_ot_hvac_env_r3379_verdict on public.ot_hvac_env_r3379(qc_verdict);

-- =============================================================================
-- TABLE 2: ot_hvac_env_capa_actions_r3379 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ot_hvac_env_capa_actions_r3379 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ot_hvac_env_r3379(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'air_change_deficiency','positive_pressure_loss','hepa_integrity_breach','laminar_flow_failure',
    'temp_humidity_excursion','particle_count_excursion','dp_alarm_failure','filter_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'ahu_fan_belt_worn','hepa_filter_loaded','damper_misadjusted','door_interlock_bypassed',
    'chiller_capacity_shortfall','humidifier_fault','sensor_calibration_drift','ductwork_leak',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_hepa_filter','rebalance_air_flow','adjust_pressure_cascade','service_ahu',
    'recalibrate_dp_sensor','repair_humidifier','seal_ductwork','replace_fan_belt',
    'downgrade_ot_pending_fix','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_14644_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_hvac_env_capa_actions_r3379 enable row level security;

create index if not exists idx_ot_hvac_capa_r3379_log on public.ot_hvac_env_capa_actions_r3379(qc_log_id);
create index if not exists idx_ot_hvac_capa_r3379_status on public.ot_hvac_env_capa_actions_r3379(capa_status);

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

  -- 14 OT HVAC / environment QC rows
  insert into public.ot_hvac_env_r3379 (
    organization_id, hospital_name, ot_code, ot_class, check_date,
    air_changes_per_hour, positive_pressure_pa, hepa_filter_integrity_ok, laminar_flow_velocity_ok,
    temperature_c, humidity_pct, temp_humidity_in_spec, particle_count_iso_class,
    differential_pressure_alarm_ok, filter_replacement_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.cls, q.cd::date,
    q.ach, q.pp, q.hepa, q.lam,
    q.tc, q.hum, q.ths, q.iso,
    q.dpa, q.frc, q.qv, q.nt
  from (values
    ('Apollo Chennai','OT-01','ultra_clean_laminar','2026-07-02',24.0,15.0,true,'ok',20.5,52.0,true,'iso5',true,true,'pass','Quarterly OT validation — all parameters within NABH and ISO 14644 limits'),
    ('Apollo Chennai','OT-02','conventional_positive_pressure','2026-07-02',19.0,12.0,true,'not_applicable',21.0,55.0,true,'iso7',true,true,'pass','Conventional positive-pressure OT nominal'),
    ('Fortis Gurgaon','OT-01','ultra_clean_laminar','2026-07-01',18.0,11.0,true,'low',20.0,54.0,true,'iso6',true,true,'conditional_pass','Laminar velocity low at canopy edge — recheck booked'),
    ('Fortis Gurgaon','OT-03','hybrid_ot','2026-07-01',16.0,6.0,false,'ok',22.5,58.0,false,'iso7',true,false,'fail','HEPA integrity breach on DOP test, temp/humidity out of spec, filter overdue'),
    ('Manipal Bengaluru','OT-02','modular_ot','2026-06-30',21.0,13.0,true,'not_applicable',20.8,50.0,true,'iso7',true,true,'pass','Modular OT annual validation pass'),
    ('Manipal Bengaluru','OT-04','conventional_positive_pressure','2026-06-30',14.0,8.0,true,'not_applicable',21.5,61.0,false,'iso8',true,true,'conditional_pass','ACH 14 below 15 minimum and humidity 61 pct above ceiling — AHU balance due'),
    ('AIIMS Delhi','OT-05','ultra_clean_laminar','2026-06-29',22.0,14.0,true,'ok',19.5,48.0,true,'iso5',true,true,'pass','Neuro OT laminar canopy verified'),
    ('AIIMS Delhi','OT-06','hybrid_ot','2026-06-29',12.0,-3.0,false,'fail',24.5,66.0,false,'out_of_spec',false,false,'ot_downgraded','Negative pressure cascade, HEPA fail, DP alarm dead — OT downgraded pending rectification'),
    ('CMC Vellore','OT-01','conventional_positive_pressure','2026-06-28',20.0,12.5,true,'not_applicable',21.2,53.0,true,'iso7',true,true,'pass','General surgery OT pass'),
    ('CMC Vellore','OT-07','minor_ot','2026-06-28',15.0,9.0,true,'not_applicable',22.0,57.0,true,'iso8',true,true,'pass','Minor procedure OT within relaxed limits'),
    ('KIMS Hyderabad','OT-02','ultra_clean_laminar','2026-06-27',17.0,10.0,true,'low',20.0,51.0,true,'iso6',false,true,'conditional_pass','Laminar velocity low and DP alarm not annunciating — sensor recal due'),
    ('KIMS Hyderabad','OT-03','modular_ot','2026-06-27',23.0,13.5,true,'not_applicable',20.6,49.0,true,'iso7',true,true,'pass','Post-AMC modular OT verification pass'),
    ('Medanta Gurgaon','OT-08','hybrid_ot','2026-06-26',13.0,7.0,false,'ok',23.5,62.0,true,'out_of_spec',true,false,'fail','Particle count out of ISO spec and HEPA loaded — filter replacement overdue'),
    ('Narayana Health Bengaluru','OT-01','minor_ot','2026-06-26',null,null,null,'not_applicable',null,null,false,'out_of_spec',false,false,'fail','Validation aborted — AHU tripped, no airflow readings captured, revisit scheduled')
  ) as q(hosp, ot, cls, cd, ach, pp, hepa, lam, tc, hum, ths, iso, dpa, frc, qv, nt);

  -- CAPA seed — attach to specific OT checks via (hospital_name, ot_code)
  insert into public.ot_hvac_env_capa_actions_r3379 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Fortis Gurgaon','OT-03','hepa_integrity_breach','hepa_filter_loaded','replace_hepa_filter','in_progress','nabh_finding','2026-07-06',null,45000.00,'HEPA DOP fail — replacement terminal filter on order'),
    ('AIIMS Delhi','OT-06','positive_pressure_loss','damper_misadjusted','adjust_pressure_cascade','escalated','patient_safety_alert','2026-07-03',null,85000.00,'Negative cascade — OT closed, cascade rebalance escalated to OEM'),
    ('Manipal Bengaluru','OT-04','air_change_deficiency','ahu_fan_belt_worn','service_ahu','open','nabh_finding','2026-07-05',null,32000.00,'ACH below minimum — AHU fan-belt service scheduled'),
    ('KIMS Hyderabad','OT-02','dp_alarm_failure','sensor_calibration_drift','recalibrate_dp_sensor','verification_pending','iso_14644_deviation','2026-07-04',null,8000.00,'DP alarm silent — sensor recalibrated, verify next round'),
    ('Medanta Gurgaon','OT-08','particle_count_excursion','hepa_filter_loaded','replace_hepa_filter','overdue','nabh_finding','2026-06-28',null,48000.00,'Particle count out of spec — filter replacement overdue, AMC vendor delayed'),
    ('Fortis Gurgaon','OT-01','laminar_flow_failure','hepa_filter_loaded','rebalance_air_flow','closed','internal_only','2026-07-04','2026-07-03',15000.00,'Laminar velocity restored after airflow rebalance'),
    ('Narayana Health Bengaluru','OT-01','preventive_maintenance_due','ahu_fan_belt_worn','service_ahu','open','patient_safety_alert','2026-07-02',null,52000.00,'AHU tripped — full service and re-validation required')
  ) as q(hosp, ot, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ot_hvac_env_r3379 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp and e.ot_code = q.ot;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3379_qc_verdict_rollup()
returns table(qc_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_hvac_env_r3379)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ot_hvac_env_r3379 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3379_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3379_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3379_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  hepa_fail bigint,
  laminar_fail bigint,
  dp_alarm_fail bigint,
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
    count(*) filter (where l.qc_verdict in ('fail','ot_downgraded'))::bigint,
    count(*) filter (where l.hepa_filter_integrity_ok = false)::bigint,
    count(*) filter (where l.laminar_flow_velocity_ok in ('low','fail'))::bigint,
    count(*) filter (where l.differential_pressure_alarm_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ot_hvac_env_r3379 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3379_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3379_hospital_scorecard() to authenticated;

-- 3) OT class × ISO particle class matrix
create or replace function public.founder_r3379_ot_class_iso_matrix()
returns table(ot_class text, particle_count_iso_class text, checks bigint, passed bigint, avg_air_changes numeric, avg_positive_pressure_pa numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ot_class, l.particle_count_iso_class, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.air_changes_per_hour), 1),
    round(avg(l.positive_pressure_pa), 1)
  from public.ot_hvac_env_r3379 l
  group by l.ot_class, l.particle_count_iso_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3379_ot_class_iso_matrix() from public, anon;
grant execute on function public.founder_r3379_ot_class_iso_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3379_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, hepa_fail bigint, temp_humidity_fail bigint)
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
    count(*) filter (where l.qc_verdict in ('fail','ot_downgraded'))::bigint,
    count(*) filter (where l.hepa_filter_integrity_ok = false)::bigint,
    count(*) filter (where l.temp_humidity_in_spec = false)::bigint
  from public.ot_hvac_env_r3379 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3379_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3379_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3379_capa_status_board()
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
  from public.ot_hvac_env_capa_actions_r3379 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3379_capa_status_board() from public, anon;
grant execute on function public.founder_r3379_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3379_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_hvac_env_capa_actions_r3379)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ot_hvac_env_capa_actions_r3379 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3379_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3379_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3379_regulatory_impact_digest()
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
  from public.ot_hvac_env_capa_actions_r3379 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3379_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3379_regulatory_impact_digest() to authenticated;

-- 8) High-risk OT queue (top individual concerns)
create or replace function public.founder_r3379_high_risk_queue()
returns table(
  hospital_name text,
  ot_code text,
  ot_class text,
  check_date date,
  qc_verdict text,
  laminar_flow_velocity_ok text,
  particle_count_iso_class text,
  hepa_integrity text,
  dp_alarm text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_code, l.ot_class, l.check_date,
    l.qc_verdict, l.laminar_flow_velocity_ok, l.particle_count_iso_class,
    case when l.hepa_filter_integrity_ok is null then 'no_data'
         when l.hepa_filter_integrity_ok then 'ok' else 'fail' end,
    case when l.differential_pressure_alarm_ok then 'ok' else 'fail' end,
    l.notes
  from public.ot_hvac_env_r3379 l
  where l.qc_verdict in ('conditional_pass','fail','ot_downgraded')
     or l.hepa_filter_integrity_ok = false
     or l.laminar_flow_velocity_ok in ('low','fail')
     or l.particle_count_iso_class = 'out_of_spec'
     or l.differential_pressure_alarm_ok = false
     or l.temp_humidity_in_spec = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3379_high_risk_queue() from public, anon;
grant execute on function public.founder_r3379_high_risk_queue() to authenticated;
