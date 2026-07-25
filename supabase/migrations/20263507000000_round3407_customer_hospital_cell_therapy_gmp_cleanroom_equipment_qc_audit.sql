-- Round 3407: Customer Hospital Cell-Therapy GMP Cleanroom Equipment QC Audit
-- Cell-therapy / GMP cleanroom cell-processing QC — device type × cleanroom grade × temperature accuracy × CO2/O2 control × closed-system sterility × freeze-rate profile × particle count × viable cell recovery × data integrity × calibration × CAPA

-- =============================================================================
-- TABLE 1: cell_therapy_gmp_qc_r3407 — per-device GMP cell-processing QC checks
-- =============================================================================
create table if not exists public.cell_therapy_gmp_qc_r3407 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'closed_bioreactor','automated_cell_processor','controlled_rate_freezer',
    'cell_washer','cleanroom_particle_monitor','co2_incubator_gmp'
  )),
  cleanroom_grade text not null check (cleanroom_grade in (
    'grade_a','grade_b','grade_c','grade_d'
  )),
  check_date date not null,
  temperature_accuracy_error_c numeric(5,2),
  co2_o2_control_ok boolean not null,
  sterility_closed_system_ok boolean not null,
  freeze_rate_profile_ok text not null check (freeze_rate_profile_ok in (
    'ok','drift','fail','not_applicable'
  )),
  particle_count_in_spec boolean not null,
  viable_cell_recovery_ok boolean not null,
  data_integrity_audit_trail_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cell_therapy_gmp_qc_r3407 enable row level security;

create index if not exists idx_cell_therapy_gmp_qc_r3407_org on public.cell_therapy_gmp_qc_r3407(organization_id);
create index if not exists idx_cell_therapy_gmp_qc_r3407_date on public.cell_therapy_gmp_qc_r3407(check_date);
create index if not exists idx_cell_therapy_gmp_qc_r3407_verdict on public.cell_therapy_gmp_qc_r3407(qc_verdict);

-- =============================================================================
-- TABLE 2: cell_therapy_gmp_qc_capa_actions_r3407 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cell_therapy_gmp_qc_capa_actions_r3407 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cell_therapy_gmp_qc_r3407(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'temperature_accuracy_out_of_tolerance','co2_o2_control_failure','sterility_breach_closed_system',
    'freeze_rate_profile_failure','particle_count_out_of_spec','viable_cell_recovery_low',
    'data_integrity_audit_trail_gap','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'sensor_drift','gas_supply_regulator_fault','single_use_set_defect','door_seal_hepa_leak',
    'compressor_refrigeration_fault','software_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog','audit_trail_config_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_sensor','replace_gas_regulator','replace_single_use_set','replace_hepa_filter',
    'service_refrigeration_unit','update_software_config','retrain_gmp_staff',
    'remove_from_service','schedule_oem_service','enable_audit_trail_controls','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','gmp_deviation','part_11_data_integrity','iso_13485_deviation',
    'patient_safety_alert','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cell_therapy_gmp_qc_capa_actions_r3407 enable row level security;

create index if not exists idx_cell_therapy_gmp_capa_r3407_log on public.cell_therapy_gmp_qc_capa_actions_r3407(qc_log_id);
create index if not exists idx_cell_therapy_gmp_capa_r3407_status on public.cell_therapy_gmp_qc_capa_actions_r3407(capa_status);

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

  -- 14 QC check rows
  insert into public.cell_therapy_gmp_qc_r3407 (
    organization_id, hospital_name, device_code, device_type, cleanroom_grade, check_date,
    temperature_accuracy_error_c, co2_o2_control_ok, sterility_closed_system_ok,
    freeze_rate_profile_ok, particle_count_in_spec, viable_cell_recovery_ok,
    data_integrity_audit_trail_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.grade, q.cdate::date,
    q.temperr, q.co2ok, q.sterility,
    q.freezerate, q.particle, q.viable,
    q.dataintegrity, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','BIOR-APL-01','closed_bioreactor','grade_a','2026-07-05',
     0.3,true,true,'not_applicable',true,true,true,true,'pass','Closed-system bioreactor QC — CAR-T expansion within spec'),
    ('Apollo Chennai','ACP-APL-02','automated_cell_processor','grade_b','2026-07-05',
     null,true,true,'not_applicable',true,true,true,true,'pass','Automated cell processor (CliniMACS-class) QC nominal'),
    ('Fortis Gurgaon','CRF-FRT-11','controlled_rate_freezer','grade_c','2026-07-04',
     0.8,true,true,'drift',true,true,true,true,'conditional_pass','Controlled-rate freezer profile drift near -40C node — recheck due'),
    ('Fortis Gurgaon','CRF-FRT-12','controlled_rate_freezer','grade_c','2026-07-04',
     2.5,true,true,'fail',true,false,true,true,'fail','Freeze-rate profile fail and viable recovery below threshold post-thaw'),
    ('Manipal Bengaluru','PART-MNP-21','cleanroom_particle_monitor','grade_a','2026-07-03',
     null,true,true,'not_applicable',false,true,true,false,'removed_from_service','Grade A particle monitor out of spec and calibration overdue — removed'),
    ('Manipal Bengaluru','CO2-MNP-22','co2_incubator_gmp','grade_b','2026-07-03',
     0.4,true,true,'not_applicable',true,true,true,true,'pass','GMP CO2 incubator QC nominal'),
    ('AIIMS Delhi','BIOR-AIM-31','closed_bioreactor','grade_a','2026-07-02',
     0.6,true,true,'not_applicable',true,true,true,true,'conditional_pass','Bioreactor gas control slight upward drift flagged for trend'),
    ('AIIMS Delhi','WASH-AIM-32','cell_washer','grade_b','2026-07-02',
     null,true,false,'not_applicable',true,false,true,true,'fail','Cell washer sterility breach in closed set with low viable recovery'),
    ('CMC Vellore','ACP-CMC-41','automated_cell_processor','grade_b','2026-07-01',
     null,true,true,'not_applicable',true,true,true,true,'pass','Automated cell processor QC pass'),
    ('CMC Vellore','PART-CMC-42','cleanroom_particle_monitor','grade_b','2026-07-01',
     null,true,true,'not_applicable',true,true,false,true,'conditional_pass','Particle monitor within spec but 21 CFR Part 11 audit-trail gap flagged'),
    ('KIMS Hyderabad','CO2-KIM-51','co2_incubator_gmp','grade_c','2026-06-30',
     0.5,true,true,'not_applicable',true,true,true,true,'pass','GMP CO2 incubator QC pass post-AMC'),
    ('KIMS Hyderabad','CRF-KIM-52','controlled_rate_freezer','grade_c','2026-06-30',
     0.9,true,true,'ok',true,true,true,false,'conditional_pass','CRF freeze profile OK but calibration overdue — recheck due'),
    ('Yashoda Hyderabad','BIOR-YSH-61','closed_bioreactor','grade_a','2026-06-29',
     0.2,true,true,'not_applicable',true,true,true,true,'pass','Closed bioreactor QC nominal — stem-cell expansion batch'),
    ('Kokilaben Mumbai','CO2-KKB-71','co2_incubator_gmp','grade_b','2026-06-29',
     3.1,false,false,'not_applicable',false,false,false,false,'removed_from_service','GMP incubator multiple failures — temp, CO2, sterility, particle — removed')
  ) as q(hosp, dcode, dtype, grade, cdate, temperr, co2ok, sterility, freezerate, particle, viable, dataintegrity, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cell_therapy_gmp_qc_capa_actions_r3407 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CRF-FRT-12','freeze_rate_profile_failure','compressor_refrigeration_fault','service_refrigeration_unit','in_progress','gmp_deviation','2026-07-08',null,55000.00,'Refrigeration serviced; re-validate freeze profile with dummy bags'),
    ('PART-MNP-21','particle_count_out_of_spec','door_seal_hepa_leak','replace_hepa_filter','escalated','patient_safety_alert','2026-07-06',null,38000.00,'Grade A HEPA leak — line quarantined, filter replacement escalated'),
    ('WASH-AIM-32','sterility_breach_closed_system','single_use_set_defect','replace_single_use_set','open','cdsco_notifiable','2026-07-05',null,12000.00,'Closed-set integrity breach — batch discarded, vendor lot investigation'),
    ('CO2-KKB-71','co2_o2_control_failure','gas_supply_regulator_fault','remove_from_service','closed','iso_13485_deviation','2026-07-03','2026-06-30',42000.00,'Incubator removed; regulator replaced and unit re-qualified'),
    ('PART-CMC-42','data_integrity_audit_trail_gap','audit_trail_config_gap','enable_audit_trail_controls','verification_pending','part_11_data_integrity','2026-07-06',null,9000.00,'Audit trail enabled — verify 21 CFR Part 11 compliance next review'),
    ('CRF-KIM-52','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-01',null,18000.00,'CRF calibration past target — OEM service delayed'),
    ('BIOR-AIM-31','co2_o2_control_failure','sensor_drift','recalibrate_sensor','open','gmp_deviation','2026-07-09',null,6500.00,'Gas sensor recalibration scheduled — monitor drift trend')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cell_therapy_gmp_qc_r3407 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3407_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cell_therapy_gmp_qc_r3407)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cell_therapy_gmp_qc_r3407 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3407_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3407_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3407_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  sterility_fail bigint,
  particle_fail bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.sterility_closed_system_ok = false)::bigint,
    count(*) filter (where l.particle_count_in_spec = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cell_therapy_gmp_qc_r3407 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3407_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3407_hospital_scorecard() to authenticated;

-- 3) Device-type × cleanroom-grade matrix
create or replace function public.founder_r3407_device_type_grade_matrix()
returns table(device_type text, cleanroom_grade text, checks bigint, passed bigint, failed bigint, avg_temp_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.cleanroom_grade, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.temperature_accuracy_error_c), 2)
  from public.cell_therapy_gmp_qc_r3407 l
  group by l.device_type, l.cleanroom_grade
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3407_device_type_grade_matrix() from public, anon;
grant execute on function public.founder_r3407_device_type_grade_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3407_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, sterility_fail bigint, particle_fail bigint)
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
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.sterility_closed_system_ok = false)::bigint,
    count(*) filter (where l.particle_count_in_spec = false)::bigint
  from public.cell_therapy_gmp_qc_r3407 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3407_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3407_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3407_capa_status_board()
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
  from public.cell_therapy_gmp_qc_capa_actions_r3407 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3407_capa_status_board() from public, anon;
grant execute on function public.founder_r3407_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3407_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cell_therapy_gmp_qc_capa_actions_r3407)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cell_therapy_gmp_qc_capa_actions_r3407 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3407_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3407_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3407_regulatory_impact_digest()
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
  from public.cell_therapy_gmp_qc_capa_actions_r3407 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3407_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3407_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3407_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  cleanroom_grade text,
  check_date date,
  qc_verdict text,
  freeze_rate_profile_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.cleanroom_grade, l.check_date,
    l.qc_verdict, l.freeze_rate_profile_ok, l.notes
  from public.cell_therapy_gmp_qc_r3407 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.co2_o2_control_ok = false
     or l.sterility_closed_system_ok = false
     or l.freeze_rate_profile_ok in ('drift','fail')
     or l.particle_count_in_spec = false
     or l.viable_cell_recovery_ok = false
     or l.data_integrity_audit_trail_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3407_high_risk_queue() from public, anon;
grant execute on function public.founder_r3407_high_risk_queue() to authenticated;
