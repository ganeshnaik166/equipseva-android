-- Round 3243: Customer Hospital Blood-Bank Component-Storage Equipment QC Audit
-- Blood-bank QA — platelet agitator-incubators (20-24C + continuous agitation) & -30/-40C plasma freezers ×
-- temp-in-range × agitation × alarm test × door seal × chart recorder × backup power × verdict × CAPA

-- =============================================================================
-- TABLE 1: bloodbank_storage_qc_r3243 — per-unit component-storage QC checks
-- =============================================================================
create table if not exists public.bloodbank_storage_qc_r3243 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  unit_code text not null,
  equipment_type text not null check (equipment_type in (
    'platelet_agitator','plasma_freezer_minus30','plasma_freezer_minus40','plasma_thawing_bath'
  )),
  check_date date not null,
  temp_reading_c numeric(5,1) not null,
  temp_in_range boolean not null,
  agitation_rpm int,
  agitation_ok text not null check (agitation_ok in (
    'ok','stopped','erratic','not_applicable'
  )),
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  door_seal_condition text not null check (door_seal_condition in (
    'good','worn','leaking'
  )),
  chart_recorder_or_logger text not null check (chart_recorder_or_logger in (
    'working','faulty','missing'
  )),
  backup_power_ok boolean not null,
  audit_verdict text not null check (audit_verdict in (
    'pass','conditional_pass','fail','quarantined'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bloodbank_storage_qc_r3243 enable row level security;

create index if not exists idx_bloodbank_storage_qc_r3243_org on public.bloodbank_storage_qc_r3243(organization_id);
create index if not exists idx_bloodbank_storage_qc_r3243_date on public.bloodbank_storage_qc_r3243(check_date);
create index if not exists idx_bloodbank_storage_qc_r3243_verdict on public.bloodbank_storage_qc_r3243(audit_verdict);

-- =============================================================================
-- TABLE 2: bloodbank_storage_qc_capa_actions_r3243 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.bloodbank_storage_qc_capa_actions_r3243 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.bloodbank_storage_qc_r3243(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_excursion','agitation_failure','alarm_failure','door_seal_defect',
    'chart_recorder_fault','backup_power_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compressor_fault','agitator_motor_failure','door_gasket_worn','temp_sensor_drift',
    'alarm_module_fault','chart_recorder_fault','ups_battery_failure','power_supply_issue',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'repair_compressor','replace_agitator_motor','replace_door_gasket','recalibrate_temp_sensor',
    'replace_alarm_module','replace_chart_recorder','replace_ups_battery','relocate_components',
    'quarantine_and_discard_units','schedule_oem_service','retrain_bloodbank_staff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','nbtc_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bloodbank_storage_qc_capa_actions_r3243 enable row level security;

create index if not exists idx_bloodbank_capa_r3243_log on public.bloodbank_storage_qc_capa_actions_r3243(qc_log_id);
create index if not exists idx_bloodbank_capa_r3243_status on public.bloodbank_storage_qc_capa_actions_r3243(capa_status);

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

  -- 14 per-unit QC check rows
  insert into public.bloodbank_storage_qc_r3243 (
    organization_id, hospital_name, unit_code, equipment_type, check_date,
    temp_reading_c, temp_in_range, agitation_rpm, agitation_ok, alarm_test,
    door_seal_condition, chart_recorder_or_logger, backup_power_ok, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.unit, q.etype, q.cdate::date,
    q.temp::numeric, q.tinr, q.rpm::int, q.aok, q.alarm,
    q.seal, q.chart, q.backup, q.verdict, q.nt
  from (values
    ('Apollo Chennai','PA-01','platelet_agitator','2026-07-02',
     22.4,true,62,'ok','pass','good','working',true,'pass','Platelet agitator within 20-24C, agitation steady at 62 rpm'),
    ('Apollo Chennai','PF-01','plasma_freezer_minus30','2026-07-02',
     -31.2,true,null,'not_applicable','pass','good','working',true,'pass','Plasma freezer stable at -31.2C, alarm and recorder verified'),
    ('Fortis Gurgaon','PA-02','platelet_agitator','2026-07-01',
     25.6,false,58,'erratic','pass','worn','working',true,'conditional_pass','Temp 25.6C above 24C ceiling, agitation erratic — motor watch'),
    ('Fortis Gurgaon','PF-02','plasma_freezer_minus40','2026-07-01',
     -36.8,false,null,'not_applicable','fail','good','faulty',true,'fail','Warmed to -36.8C, high-temp alarm did not trigger, recorder faulty'),
    ('Manipal Bengaluru','PA-03','platelet_agitator','2026-06-30',
     21.8,true,65,'ok','pass','good','working',true,'pass','Nominal quarterly check, agitation 65 rpm'),
    ('Manipal Bengaluru','TB-01','plasma_thawing_bath','2026-06-30',
     37.1,true,null,'not_applicable','pass','good','working',true,'pass','Thawing bath at 37.1C, within tolerance'),
    ('AIIMS Delhi','PA-04','platelet_agitator','2026-06-29',
     23.9,true,0,'stopped','pass','good','working',true,'quarantined','Agitator motor stopped overnight — platelet units quarantined pending review'),
    ('AIIMS Delhi','PF-03','plasma_freezer_minus30','2026-06-29',
     -28.4,false,null,'not_applicable','pass','worn','working',false,'conditional_pass','Freezer -28.4C above -30 target, gasket worn, backup power failed test'),
    ('CMC Vellore','PF-04','plasma_freezer_minus40','2026-06-28',
     -41.3,true,null,'not_applicable','pass','good','working',true,'pass','Stable at -41.3C, all safeguards verified'),
    ('CMC Vellore','PA-05','platelet_agitator','2026-06-28',
     24.2,false,61,'ok','not_tested','good','working',true,'conditional_pass','Temp 24.2C marginally over ceiling, alarm not tested this cycle'),
    ('KIMS Hyderabad','PF-05','plasma_freezer_minus30','2026-06-27',
     -30.6,true,null,'not_applicable','fail','leaking','missing',true,'fail','Alarm failed test, door seal leaking, no chart recorder fitted'),
    ('KIMS Hyderabad','TB-02','plasma_thawing_bath','2026-06-27',
     39.4,false,null,'not_applicable','pass','good','working',true,'fail','Thawing bath overheated to 39.4C — risk to plasma proteins'),
    ('Narayana Health Bengaluru','PA-06','platelet_agitator','2026-06-26',
     22.0,true,63,'ok','pass','good','working',true,'pass','Nominal quarterly check, agitation 63 rpm'),
    ('Medanta Gurgaon','PF-06','plasma_freezer_minus40','2026-06-26',
     -33.1,false,null,'not_applicable','fail','worn','faulty',false,'quarantined','Freezer -33.1C well above -40 target, alarm and recorder faulty, backup failed — units quarantined')
  ) as q(hosp, unit, etype, cdate, temp, tinr, rpm, aok, alarm, seal, chart, backup, verdict, nt);

  -- CAPA seed — attach to specific units via unit_code
  insert into public.bloodbank_storage_qc_capa_actions_r3243 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('PA-02','agitation_failure','agitator_motor_failure','replace_agitator_motor','in_progress','nbtc_deviation','2026-07-06',null,55000.00,'Erratic agitation and warm chamber — motor and drive belt on order'),
    ('PF-02','alarm_failure','alarm_module_fault','replace_alarm_module','escalated','cdsco_notifiable','2026-07-05',null,38000.00,'High-temp alarm silent at -36.8C — escalated to OEM engineer'),
    ('PA-04','agitation_failure','agitator_motor_failure','replace_agitator_motor','open','patient_safety_alert','2026-07-04',null,72000.00,'Motor seized overnight — platelet units quarantined, replacement on order'),
    ('PF-03','door_seal_defect','door_gasket_worn','replace_door_gasket','closed','nabh_finding','2026-07-01','2026-06-30',8500.00,'Gasket replaced, temp recovered to -30.4C, backup UPS re-tested OK'),
    ('PF-05','chart_recorder_fault','chart_recorder_fault','replace_chart_recorder','open','nbtc_deviation','2026-07-08',null,26000.00,'Chart recorder to be fitted, door seal replacement also scheduled'),
    ('TB-02','temperature_excursion','temp_sensor_drift','recalibrate_temp_sensor','verification_pending','internal_only','2026-07-03',null,6000.00,'Thermostat recalibrated — verifying 37C setpoint over next thaw cycle'),
    ('PF-06','temperature_excursion','compressor_fault','repair_compressor','overdue','patient_safety_alert','2026-06-24',null,95000.00,'Compressor repair past target — AMC vendor delayed, units quarantined')
  ) as q(unit, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.bloodbank_storage_qc_r3243 e
    on e.organization_id = v_org_id and e.unit_code = q.unit;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3243_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bloodbank_storage_qc_r3243)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bloodbank_storage_qc_r3243 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3243_verdict_rollup() from public, anon;
grant execute on function public.founder_r3243_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3243_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  quarantined bigint,
  temp_out_of_range bigint,
  alarm_fail bigint,
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
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.audit_verdict = 'fail')::bigint,
    count(*) filter (where l.audit_verdict = 'quarantined')::bigint,
    count(*) filter (where l.temp_in_range = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.bloodbank_storage_qc_r3243 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3243_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3243_hospital_scorecard() to authenticated;

-- 3) Equipment type × door-seal condition matrix
create or replace function public.founder_r3243_equipment_matrix()
returns table(equipment_type text, door_seal_condition text, audits bigint, passed bigint, avg_temp_reading_c numeric, temp_out_of_range bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.door_seal_condition, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    round(avg(l.temp_reading_c), 1),
    count(*) filter (where l.temp_in_range = false)::bigint
  from public.bloodbank_storage_qc_r3243 l
  group by l.equipment_type, l.door_seal_condition
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3243_equipment_matrix() from public, anon;
grant execute on function public.founder_r3243_equipment_matrix() to authenticated;

-- 4) Daily QC check trend
create or replace function public.founder_r3243_daily_check_trend()
returns table(check_date date, audits bigint, passed bigint, failed bigint, temp_out_of_range bigint, alarm_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.temp_in_range = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint
  from public.bloodbank_storage_qc_r3243 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3243_daily_check_trend() from public, anon;
grant execute on function public.founder_r3243_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3243_capa_status_board()
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
  from public.bloodbank_storage_qc_capa_actions_r3243 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3243_capa_status_board() from public, anon;
grant execute on function public.founder_r3243_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3243_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bloodbank_storage_qc_capa_actions_r3243)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bloodbank_storage_qc_capa_actions_r3243 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3243_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3243_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3243_regulatory_impact_digest()
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
  from public.bloodbank_storage_qc_capa_actions_r3243 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3243_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3243_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3243_high_risk_queue()
returns table(
  hospital_name text,
  unit_code text,
  equipment_type text,
  check_date date,
  audit_verdict text,
  temp_reading_c numeric,
  temp_in_range boolean,
  agitation_ok text,
  alarm_test text,
  door_seal_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.unit_code, l.equipment_type, l.check_date,
    l.audit_verdict, l.temp_reading_c, l.temp_in_range, l.agitation_ok,
    l.alarm_test, l.door_seal_condition, l.notes
  from public.bloodbank_storage_qc_r3243 l
  where l.audit_verdict in ('conditional_pass','fail','quarantined')
     or l.temp_in_range = false
     or l.agitation_ok in ('stopped','erratic')
     or l.alarm_test = 'fail'
     or l.door_seal_condition in ('worn','leaking')
     or l.chart_recorder_or_logger in ('faulty','missing')
     or l.backup_power_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3243_high_risk_queue() from public, anon;
grant execute on function public.founder_r3243_high_risk_queue() to authenticated;
