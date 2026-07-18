-- Round 3262: Customer Hospital / Fertility-Clinic IVF & Embryology Lab Equipment QC Audit
-- IVF lab QA — device type × lab area × CO2/O2/temp stability × VOC filter × LN2 level × low-level alarm × calibration traceability × cleanroom particle × CAPA

-- =============================================================================
-- TABLE 1: ivf_lab_qc_r3262 — per-device embryology-lab equipment QC checks
-- =============================================================================
create table if not exists public.ivf_lab_qc_r3262 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  clinic_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'co2_incubator','tri_gas_incubator','micromanipulator_icsi',
    'laser_hatching','ln2_cryostorage_dewar','embryo_witness_system'
  )),
  lab_area text not null,
  check_date date not null,
  co2_pct_error numeric(5,2),
  o2_pct_error numeric(5,2),
  temp_stability_error_c numeric(4,2),
  voc_filter_status text not null check (voc_filter_status in (
    'fresh','due_soon','overdue','not_applicable'
  )),
  ln2_level_pct numeric(5,2),
  low_level_alarm_test text not null check (low_level_alarm_test in (
    'pass','fail','not_tested','not_applicable'
  )),
  calibration_traceable boolean not null,
  cleanroom_particle_ok boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ivf_lab_qc_r3262 enable row level security;

create index if not exists idx_ivf_lab_qc_r3262_org on public.ivf_lab_qc_r3262(organization_id);
create index if not exists idx_ivf_lab_qc_r3262_date on public.ivf_lab_qc_r3262(check_date);
create index if not exists idx_ivf_lab_qc_r3262_verdict on public.ivf_lab_qc_r3262(qc_verdict);

-- =============================================================================
-- TABLE 2: ivf_lab_qc_capa_actions_r3262 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ivf_lab_qc_capa_actions_r3262 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ivf_lab_qc_r3262(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'co2_deviation','o2_deviation','temp_instability','voc_filter_overdue','ln2_low_level',
    'alarm_test_failure','calibration_not_traceable','cleanroom_particle_excursion',
    'witness_system_fault','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'co2_sensor_drift','o2_sensor_drift','door_seal_worn','heater_control_fault','voc_filter_saturated',
    'ln2_supply_interruption','dewar_vacuum_loss','alarm_misconfigured','calibration_lapsed',
    'hepa_filter_degraded','witness_tag_reader_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_co2_sensor','recalibrate_o2_sensor','replace_door_seal','service_heater_control',
    'replace_voc_filter','restore_ln2_supply','replace_dewar','reconfigure_alarm','recalibrate_and_certify',
    'replace_hepa_filter','replace_witness_reader','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','eshre_deviation','iso_15189_deviation','art_act_notifiable',
    'patient_safety_alert','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ivf_lab_qc_capa_actions_r3262 enable row level security;

create index if not exists idx_ivf_lab_qc_capa_r3262_log on public.ivf_lab_qc_capa_actions_r3262(qc_log_id);
create index if not exists idx_ivf_lab_qc_capa_r3262_status on public.ivf_lab_qc_capa_actions_r3262(capa_status);

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
  insert into public.ivf_lab_qc_r3262 (
    organization_id, clinic_name, device_code, device_type, lab_area, check_date,
    co2_pct_error, o2_pct_error, temp_stability_error_c, voc_filter_status,
    ln2_level_pct, low_level_alarm_test, calibration_traceable, cleanroom_particle_ok,
    qc_verdict, notes
  )
  select v_org_id, q.clinic, q.code, q.dtype, q.area, q.cdate::date,
    q.co2err, q.o2err, q.temperr, q.voc,
    q.ln2, q.alarm, q.caltrace, q.cleanroom,
    q.verdict, q.nt
  from (values
    ('Nova IVF Ahmedabad','INC-NOV-01','co2_incubator','embryology_lab','2026-07-05',
     0.4,0.3,0.1,'fresh',null,'not_applicable',true,true,'pass','Benchtop CO2 incubator all gases within spec'),
    ('Nova IVF Ahmedabad','INC-NOV-02','tri_gas_incubator','embryology_lab','2026-07-05',
     0.6,1.4,0.2,'due_soon',null,'not_applicable',true,true,'conditional_pass','O2 1.4% off 5% setpoint; VOC filter due soon'),
    ('Cloudnine Bengaluru','ICSI-CLB-11','micromanipulator_icsi','micromanipulation_suite','2026-07-04',
     null,null,0.3,'not_applicable',null,'not_applicable',true,true,'pass','ICSI rig stage drift within tolerance'),
    ('Cloudnine Bengaluru','LZR-CLB-12','laser_hatching','micromanipulation_suite','2026-07-04',
     null,null,null,'not_applicable',null,'not_applicable',false,true,'conditional_pass','Laser pulse-energy certificate lapsed; recalibration booked'),
    ('Apollo Fertility Chennai','DEW-APF-21','ln2_cryostorage_dewar','cryostorage_room','2026-07-03',
     null,null,null,'not_applicable',78.0,'pass',true,true,'pass','LN2 dewar level healthy; low-level alarm verified'),
    ('Apollo Fertility Chennai','DEW-APF-22','ln2_cryostorage_dewar','cryostorage_room','2026-07-03',
     null,null,null,'not_applicable',22.0,'fail',true,true,'fail','Dewar at 22% and low-level alarm did not trigger'),
    ('Fortis La Femme Delhi','INC-FLF-31','co2_incubator','embryology_lab','2026-07-02',
     1.9,0.5,0.6,'overdue',null,'not_applicable',true,false,'fail','CO2 1.9% deviation, VOC filter overdue, particle count out'),
    ('Fortis La Femme Delhi','WIT-FLF-32','embryo_witness_system','embryology_lab','2026-07-02',
     null,null,null,'not_applicable',null,'not_tested',true,true,'conditional_pass','Witness RFID reader intermittent on 2 of 30 tags'),
    ('Manipal Bengaluru','INC-MNP-41','co2_incubator','embryology_lab','2026-07-01',
     0.3,0.4,0.1,'fresh',null,'not_applicable',true,true,'pass','Routine QC clean pass'),
    ('Milann Bengaluru','TRG-MIL-51','tri_gas_incubator','embryology_lab','2026-06-30',
     0.5,0.9,0.9,'due_soon',null,'not_applicable',true,true,'conditional_pass','Temp stability 0.9C above 0.5C target; door-seal watch'),
    ('Indira IVF Pune','DEW-IND-61','ln2_cryostorage_dewar','cryostorage_room','2026-06-29',
     null,null,null,'not_applicable',12.0,'fail',false,true,'removed_from_service','Dewar vacuum loss, rapid boil-off; samples relocated'),
    ('KIMS Hyderabad','ICSI-KIM-71','micromanipulator_icsi','micromanipulation_suite','2026-06-28',
     null,null,0.2,'not_applicable',null,'not_applicable',true,true,'pass','Micromanipulator injection axis calibrated'),
    ('CMC Vellore','LZR-CMC-81','laser_hatching','micromanipulation_suite','2026-06-27',
     null,null,null,'not_applicable',null,'not_applicable',true,true,'pass','Laser hatching objective aperture verified'),
    ('AIIMS Delhi','WIT-AIM-91','embryo_witness_system','embryology_lab','2026-06-26',
     null,null,null,'not_applicable',null,'not_tested',false,true,'conditional_pass','Witness system audit-trail export failed; vendor patch pending')
  ) as q(clinic, code, dtype, area, cdate, co2err, o2err, temperr, voc, ln2, alarm, caltrace, cleanroom, verdict, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.ivf_lab_qc_capa_actions_r3262 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DEW-APF-22','alarm_test_failure','alarm_misconfigured','reconfigure_alarm','in_progress','patient_safety_alert','2026-07-07',null,15000.00,'Low-level alarm setpoint corrected; re-test on next round'),
    ('INC-FLF-31','co2_deviation','co2_sensor_drift','recalibrate_co2_sensor','open','nabh_finding','2026-07-09',null,28000.00,'CO2 sensor recalibration scheduled with OEM engineer'),
    ('INC-FLF-31','voc_filter_overdue','voc_filter_saturated','replace_voc_filter','in_progress','iso_15189_deviation','2026-07-08',null,9000.00,'Overdue VOC/HEPA filter cartridge on order'),
    ('DEW-IND-61','ln2_low_level','dewar_vacuum_loss','replace_dewar','escalated','art_act_notifiable','2026-07-06',null,240000.00,'Vacuum-jacket failure; replacement cryo-dewar procurement escalated'),
    ('LZR-CLB-12','calibration_not_traceable','calibration_lapsed','recalibrate_and_certify','verification_pending','eshre_deviation','2026-07-10',null,32000.00,'Laser energy meter cert renewed; awaiting verification pulse test'),
    ('TRG-MIL-51','temp_instability','door_seal_worn','replace_door_seal','closed','internal_only','2026-07-03','2026-07-02',6500.00,'Door gasket replaced; temp stability back to 0.3C'),
    ('WIT-AIM-91','witness_system_fault','witness_tag_reader_fault','replace_witness_reader','overdue','internal_only','2026-06-30',null,18000.00,'RFID reader RMA past target date — vendor delay')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ivf_lab_qc_r3262 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3262_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ivf_lab_qc_r3262)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ivf_lab_qc_r3262 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3262_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3262_qc_verdict_rollup() to authenticated;

-- 2) Clinic-level QC scorecard
create or replace function public.founder_r3262_clinic_scorecard()
returns table(
  clinic_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  ln2_alarm_fail bigint,
  voc_overdue bigint,
  calibration_gap bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.clinic_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.low_level_alarm_test = 'fail')::bigint,
    count(*) filter (where l.voc_filter_status = 'overdue')::bigint,
    count(*) filter (where l.calibration_traceable = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ivf_lab_qc_r3262 l
  group by l.clinic_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3262_clinic_scorecard() from public, anon;
grant execute on function public.founder_r3262_clinic_scorecard() to authenticated;

-- 3) Device type × lab area matrix
create or replace function public.founder_r3262_device_lab_area_matrix()
returns table(device_type text, lab_area text, checks bigint, passed bigint, avg_temp_stability_error_c numeric, avg_co2_pct_error numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.lab_area, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.temp_stability_error_c), 2),
    round(avg(l.co2_pct_error), 2)
  from public.ivf_lab_qc_r3262 l
  group by l.device_type, l.lab_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3262_device_lab_area_matrix() from public, anon;
grant execute on function public.founder_r3262_device_lab_area_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3262_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, ln2_alarm_fail bigint, voc_overdue bigint)
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
    count(*) filter (where l.low_level_alarm_test = 'fail')::bigint,
    count(*) filter (where l.voc_filter_status = 'overdue')::bigint
  from public.ivf_lab_qc_r3262 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3262_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3262_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3262_capa_status_board()
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
  from public.ivf_lab_qc_capa_actions_r3262 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3262_capa_status_board() from public, anon;
grant execute on function public.founder_r3262_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3262_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ivf_lab_qc_capa_actions_r3262)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ivf_lab_qc_capa_actions_r3262 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3262_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3262_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3262_regulatory_impact_digest()
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
  from public.ivf_lab_qc_capa_actions_r3262 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3262_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3262_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3262_high_risk_queue()
returns table(
  clinic_name text,
  device_code text,
  device_type text,
  lab_area text,
  check_date date,
  qc_verdict text,
  voc_filter_status text,
  low_level_alarm_test text,
  ln2_level_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.clinic_name, l.device_code, l.device_type, l.lab_area, l.check_date,
    l.qc_verdict, l.voc_filter_status, l.low_level_alarm_test, l.ln2_level_pct, l.notes
  from public.ivf_lab_qc_r3262 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.voc_filter_status = 'overdue'
     or l.low_level_alarm_test = 'fail'
     or l.calibration_traceable = false
     or l.cleanroom_particle_ok = false
  order by l.check_date desc, l.clinic_name;
end;
$$;

revoke execute on function public.founder_r3262_high_risk_queue() from public, anon;
grant execute on function public.founder_r3262_high_risk_queue() to authenticated;
