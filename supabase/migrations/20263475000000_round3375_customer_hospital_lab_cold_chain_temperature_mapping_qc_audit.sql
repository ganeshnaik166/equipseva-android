-- Round 3375: Customer Hospital Clinical-Lab Cold-Chain Temperature-Mapping QC Audit
-- Lab cold-chain QA — unit type × temperature-mapping × uniformity × MKT × excursions × door seal × logger cal × alarm test × backup power × CAPA

-- =============================================================================
-- TABLE 1: lab_cold_chain_r3375 — per-unit cold-chain QC checks
-- =============================================================================
create table if not exists public.lab_cold_chain_r3375 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  unit_code text not null,
  unit_type text not null check (unit_type in (
    'reagent_fridge_2_8','sample_freezer_minus20','sample_freezer_minus80',
    'controlled_room_storage','walk_in_cold_room','benchtop_fridge'
  )),
  lab_section text not null,
  check_date date not null,
  temp_mapping_done boolean not null,
  warmest_point_c numeric(5,2),
  coldest_point_c numeric(5,2),
  uniformity_within_spec boolean not null,
  mean_kinetic_temp_ok boolean not null,
  excursions_last_30 int not null,
  door_seal_condition text not null check (door_seal_condition in (
    'good','worn','leaking'
  )),
  logger_calibration_ok boolean not null,
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  backup_power_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','quarantined'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_cold_chain_r3375 enable row level security;

create index if not exists idx_lab_cold_chain_r3375_org on public.lab_cold_chain_r3375(organization_id);
create index if not exists idx_lab_cold_chain_r3375_date on public.lab_cold_chain_r3375(check_date);
create index if not exists idx_lab_cold_chain_r3375_verdict on public.lab_cold_chain_r3375(qc_verdict);

-- =============================================================================
-- TABLE 2: lab_cold_chain_capa_actions_r3375 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.lab_cold_chain_capa_actions_r3375 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.lab_cold_chain_r3375(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_excursion','uniformity_out_of_spec','mkt_exceeded','door_seal_failure',
    'logger_calibration_overdue','alarm_test_failure','backup_power_failure',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'compressor_degradation','door_gasket_worn','overstocking_airflow_blocked','logger_drift',
    'alarm_misconfigured','power_backup_battery_dead','thermostat_fault','ambient_hvac_load',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_compressor','replace_door_gasket','reorganize_load_airflow','recalibrate_logger',
    'reconfigure_alarm','replace_backup_battery','replace_thermostat','relocate_unit',
    'quarantine_and_revalidate','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.lab_cold_chain_capa_actions_r3375 enable row level security;

create index if not exists idx_lab_cold_chain_capa_r3375_log on public.lab_cold_chain_capa_actions_r3375(qc_log_id);
create index if not exists idx_lab_cold_chain_capa_r3375_status on public.lab_cold_chain_capa_actions_r3375(capa_status);

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

  -- 14 cold-chain QC rows
  insert into public.lab_cold_chain_r3375 (
    organization_id, hospital_name, unit_code, unit_type, lab_section, check_date,
    temp_mapping_done, warmest_point_c, coldest_point_c, uniformity_within_spec,
    mean_kinetic_temp_ok, excursions_last_30, door_seal_condition, logger_calibration_ok,
    alarm_test, backup_power_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.uc, q.ut, q.ls, q.cd::date,
    q.tmd, q.warm, q.cold, q.unif,
    q.mkt, q.exc, q.seal, q.logcal,
    q.alarm, q.bkup, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','RF-01','reagent_fridge_2_8','Biochemistry','2026-07-05',
     true,7.20,3.10,true,true,0,'good',true,'pass',true,true,'pass','Quarterly mapping — all 9 points within 2-8C'),
    ('Apollo Chennai','FZ-20-01','sample_freezer_minus20','Microbiology','2026-07-05',
     true,-16.50,-23.00,true,true,1,'good',true,'pass',true,true,'pass','One brief excursion during defrost — within limits'),
    ('Fortis Gurgaon','FZ-80-01','sample_freezer_minus80','Molecular Lab','2026-07-04',
     true,-68.00,-82.00,false,true,2,'worn',true,'pass',true,true,'conditional_pass','Warmest corner -68C above -70C target — reload racks'),
    ('Fortis Gurgaon','RF-02','reagent_fridge_2_8','Biochemistry','2026-07-04',
     true,9.40,2.80,false,false,5,'leaking',true,'fail',false,true,'fail','Warmest point 9.4C above 8C ceiling and door seal leaking'),
    ('Manipal Bengaluru','CR-01','controlled_room_storage','Histopathology','2026-07-03',
     true,24.80,19.50,true,true,0,'good',true,'pass',true,true,'pass','Controlled room 20-25C band held all cycle'),
    ('Manipal Bengaluru','WICR-01','walk_in_cold_room','Blood Bank','2026-07-03',
     true,6.90,2.20,true,true,3,'worn',false,'not_tested',true,false,'conditional_pass','Logger calibration overdue and alarm not exercised this visit'),
    ('AIIMS Delhi','FZ-80-02','sample_freezer_minus80','Molecular Lab','2026-07-02',
     true,-62.00,-79.00,false,false,8,'worn',true,'fail',false,true,'quarantined','MKT exceeded -70C — specimens quarantined pending re-test'),
    ('AIIMS Delhi','RF-03','reagent_fridge_2_8','Immunology','2026-07-02',
     true,7.80,3.60,true,true,1,'good',true,'pass',true,true,'pass','Immunoassay reagent fridge nominal'),
    ('CMC Vellore','BF-01','benchtop_fridge','Serology','2026-07-01',
     false,null,null,false,true,2,'good',true,'not_tested',true,true,'conditional_pass','Multi-point mapping deferred — single-probe only this cycle'),
    ('CMC Vellore','FZ-20-02','sample_freezer_minus20','Blood Bank','2026-07-01',
     true,-17.00,-24.50,true,true,0,'good',true,'pass',true,true,'pass','Plasma freezer within -18 to -25C'),
    ('KIMS Hyderabad','WICR-02','walk_in_cold_room','Central Store','2026-06-30',
     true,8.60,3.00,false,false,6,'leaking',false,'fail',false,false,'fail','Backup power dead, seal leaking, 6 excursions — critical'),
    ('KIMS Hyderabad','RF-04','reagent_fridge_2_8','Biochemistry','2026-06-30',
     true,6.50,2.90,true,true,0,'good',true,'pass',true,true,'pass','Routine QC pass'),
    ('Narayana Health Bengaluru','FZ-80-03','sample_freezer_minus80','Biobank','2026-06-29',
     true,-71.00,-84.00,true,true,1,'good',true,'pass',true,true,'pass','Biobank ULT freezer uniform, backup CO2 verified'),
    ('Medanta Gurugram','CR-02','controlled_room_storage','Reagent Store','2026-06-29',
     true,26.50,20.10,false,false,4,'worn',true,'not_tested',true,false,'conditional_pass','Upper range 26.5C near 27C ceiling and logger cal overdue')
  ) as q(hosp, uc, ut, ls, cd, tmd, warm, cold, unif, mkt, exc, seal, logcal, alarm, bkup, calcur, qv, nt);

  -- CAPA seed — attach to specific units via unit_code
  insert into public.lab_cold_chain_capa_actions_r3375 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RF-02','temperature_excursion','thermostat_fault','replace_thermostat','in_progress','patient_safety_alert','2026-07-10',null,22000.00,'Reagent fridge over 8C — thermostat replacement scheduled'),
    ('FZ-80-02','mkt_exceeded','compressor_degradation','replace_compressor','escalated','cdsco_notifiable','2026-07-08',null,185000.00,'-80C MKT breach; specimens quarantined; OEM escalated'),
    ('WICR-01','logger_calibration_overdue','logger_drift','recalibrate_logger','closed','iso_15189_deviation','2026-07-06','2026-07-04',8000.00,'Data logger recalibrated and re-verified'),
    ('WICR-02','backup_power_failure','power_backup_battery_dead','replace_backup_battery','open','nabh_finding','2026-07-12',null,35000.00,'Walk-in cold room backup battery bank dead — replacing'),
    ('FZ-80-01','uniformity_out_of_spec','overstocking_airflow_blocked','reorganize_load_airflow','verification_pending','internal_only','2026-07-09',null,0.00,'Racks reorganised for airflow; re-mapping scheduled'),
    ('CR-02','calibration_overdue','logger_drift','recalibrate_logger','overdue','internal_only','2026-06-28',null,6500.00,'Logger calibration past due date — vendor delayed'),
    ('BF-01','preventive_maintenance_due','pending_investigation','schedule_oem_service','open','internal_only','2026-07-11',null,4000.00,'Multi-point mapping kit due — OEM PM visit booked')
  ) as q(uc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.lab_cold_chain_r3375 e
    on e.organization_id = v_org_id and e.unit_code = q.uc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3375_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_cold_chain_r3375)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.lab_cold_chain_r3375 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3375_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3375_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3375_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  quarantined bigint,
  seal_issues bigint,
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.qc_verdict = 'quarantined')::bigint,
    count(*) filter (where l.door_seal_condition in ('worn','leaking'))::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.lab_cold_chain_r3375 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3375_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3375_hospital_scorecard() to authenticated;

-- 3) Unit-type × lab-section matrix
create or replace function public.founder_r3375_unit_type_section_matrix()
returns table(unit_type text, lab_section text, checks bigint, passed bigint, avg_warmest_c numeric, avg_excursions numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.unit_type, l.lab_section, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.warmest_point_c), 2),
    round(avg(l.excursions_last_30), 1)
  from public.lab_cold_chain_r3375 l
  group by l.unit_type, l.lab_section
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3375_unit_type_section_matrix() from public, anon;
grant execute on function public.founder_r3375_unit_type_section_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3375_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, quarantined bigint, excursion_units bigint)
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
    count(*) filter (where l.qc_verdict = 'quarantined')::bigint,
    count(*) filter (where l.excursions_last_30 > 0)::bigint
  from public.lab_cold_chain_r3375 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3375_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3375_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3375_capa_status_board()
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
  from public.lab_cold_chain_capa_actions_r3375 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3375_capa_status_board() from public, anon;
grant execute on function public.founder_r3375_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3375_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.lab_cold_chain_capa_actions_r3375)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.lab_cold_chain_capa_actions_r3375 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3375_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3375_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3375_regulatory_impact_digest()
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
  from public.lab_cold_chain_capa_actions_r3375 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3375_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3375_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3375_high_risk_queue()
returns table(
  hospital_name text,
  unit_code text,
  unit_type text,
  check_date date,
  qc_verdict text,
  warmest_point_c numeric,
  excursions_last_30 int,
  door_seal_condition text,
  alarm_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.unit_code, l.unit_type, l.check_date,
    l.qc_verdict, l.warmest_point_c, l.excursions_last_30, l.door_seal_condition,
    l.alarm_test, l.notes
  from public.lab_cold_chain_r3375 l
  where l.qc_verdict in ('conditional_pass','fail','quarantined')
     or l.door_seal_condition = 'leaking'
     or l.alarm_test = 'fail'
     or l.excursions_last_30 >= 4
     or l.uniformity_within_spec = false
     or l.mean_kinetic_temp_ok = false
     or l.backup_power_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3375_high_risk_queue() from public, anon;
grant execute on function public.founder_r3375_high_risk_queue() to authenticated;
