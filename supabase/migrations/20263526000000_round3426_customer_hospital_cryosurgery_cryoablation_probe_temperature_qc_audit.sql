-- Round 3426: Customer Hospital Cryosurgery / Cryoablation Probe Temperature QC Audit
-- Cryo probe QA — probe type × gas type × target/achieved temperature × freeze/thaw cycle × iceball diameter
--   × thermocouple verification × Joule-Thomson check × calibration currency × QC verdict × CAPA closure

-- =============================================================================
-- TABLE 1: cryo_probe_qc_r3426 — per-device cryosurgery/cryoablation probe QC checks
-- =============================================================================
create table if not exists public.cryo_probe_qc_r3426 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  probe_type text not null check (probe_type in (
    'cryoprobe','cryoablation_catheter','cryospray','cryo_needle'
  )),
  gas_type text not null check (gas_type in (
    'nitrous_oxide','argon','co2','liquid_nitrogen'
  )),
  target_temp_c numeric(6,2),
  achieved_min_temp_c numeric(6,2),
  freeze_cycle_sec int,
  thaw_cycle_sec int,
  iceball_diameter_mm numeric(6,2),
  thermocouple_verified boolean not null,
  joule_thomson_ok boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cryo_probe_qc_r3426 enable row level security;

create index if not exists idx_cryo_probe_qc_r3426_org on public.cryo_probe_qc_r3426(organization_id);
create index if not exists idx_cryo_probe_qc_r3426_cal on public.cryo_probe_qc_r3426(calibration_date);
create index if not exists idx_cryo_probe_qc_r3426_verdict on public.cryo_probe_qc_r3426(qc_verdict);

-- =============================================================================
-- TABLE 2: cryo_probe_qc_capa_actions_r3426 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cryo_probe_qc_capa_actions_r3426 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cryo_probe_qc_r3426(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'insufficient_cooling','thermocouple_unverified','joule_thomson_fault','gas_supply_low',
    'iceball_undersized','calibration_overdue','probe_damage','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'gas_supply_depleted','jt_orifice_clogged','thermocouple_drift','probe_seal_leak',
    'valve_regulator_fault','operator_setup_error','sensor_end_of_life','pending_investigation',
    'preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'regas_and_recalibrate','replace_thermocouple','clear_jt_orifice','replace_probe',
    'replace_regulator_valve','retrain_clinical_staff','remove_from_service','schedule_oem_service',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cryo_probe_qc_capa_actions_r3426 enable row level security;

create index if not exists idx_cryo_probe_qc_capa_r3426_log on public.cryo_probe_qc_capa_actions_r3426(qc_log_id);
create index if not exists idx_cryo_probe_qc_capa_r3426_status on public.cryo_probe_qc_capa_actions_r3426(capa_status);

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

  -- 16 cryo probe QC check rows
  insert into public.cryo_probe_qc_r3426 (
    organization_id, hospital_name, device_code, device_model, probe_type, gas_type,
    target_temp_c, achieved_min_temp_c, freeze_cycle_sec, thaw_cycle_sec, iceball_diameter_mm,
    thermocouple_verified, joule_thomson_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.ptype, q.gas,
    q.ttemp, q.atemp, q.frz::int, q.thaw::int, q.ice,
    q.tc, q.jt, q.cdate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CRYO-APL-01','Galil SeedNet','cryoablation_catheter','argon',
     -140.0,-152.0,600,60,32.0,true,true,'2026-07-05','pass','Argon JT cryoablation reached -152C, iceball 32mm within tolerance'),
    ('Apollo Chennai','CRYO-APL-02','Endocare CryoTouch','cryoprobe','nitrous_oxide',
     -60.0,-78.0,480,90,22.0,true,true,'2026-07-05','pass','N2O cryoprobe QC pass, thermocouple verified'),
    ('Fortis Gurgaon','CRYO-FRT-11','Erbe Erbokryo CA','cryoprobe','co2',
     -78.0,-70.0,420,75,18.0,true,true,'2026-07-04','conditional_pass','CO2 probe under-cooled to -70C vs -78 target — regas advised'),
    ('Fortis Gurgaon','CRYO-FRT-12','Galil IceRod','cryoablation_catheter','argon',
     -140.0,-118.0,600,60,24.0,false,false,'2026-07-04','fail','JT cooling insufficient (-118C) and thermocouple unverified — service raised'),
    ('Manipal Bengaluru','CRYO-MNP-21','Metrum CryoFlex','cryospray','liquid_nitrogen',
     -196.0,-196.0,30,20,null,true,true,'2026-07-03','pass','LN2 cryospray dermatology QC pass, spot freeze'),
    ('Manipal Bengaluru','CRYO-MNP-22','Endocare CryoNeedle','cryo_needle','nitrous_oxide',
     -70.0,-82.0,360,60,16.0,true,true,'2026-07-03','pass','N2O cryo needle QC nominal'),
    ('AIIMS Delhi','CRYO-AIM-31','Galil Presice','cryoablation_catheter','argon',
     -150.0,-160.0,720,90,38.0,true,true,'2026-06-30','pass','Renal cryoablation iceball 38mm reached target temperature'),
    ('AIIMS Delhi','CRYO-AIM-32','Erbe Erbokryo','cryoprobe','co2',
     -78.0,-52.0,300,60,14.0,false,true,'2026-06-30','fail','CO2 probe only reached -52C, thermocouple drift — removed for regas/cal'),
    ('CMC Vellore','CRYO-CMC-41','Metrum CryoS','cryospray','liquid_nitrogen',
     -196.0,-190.0,25,15,null,true,true,'2026-06-29','pass','LN2 cryospray QC pass'),
    ('CMC Vellore','CRYO-CMC-42','Galil SeedNet','cryoablation_catheter','argon',
     -140.0,-132.0,540,60,26.0,true,true,'2026-06-29','conditional_pass','Achieved -132C slightly warm of -140 target — recheck next case'),
    ('KIMS Hyderabad','CRYO-KIM-51','Endocare CryoTouch','cryoprobe','nitrous_oxide',
     -60.0,-76.0,450,90,20.0,true,true,'2026-06-28','pass','N2O cryoprobe QC pass post-AMC'),
    ('KIMS Hyderabad','CRYO-KIM-52','Galil IceSphere','cryoablation_catheter','argon',
     -145.0,-101.0,600,45,19.0,false,false,'2026-06-28','fail','Severe under-cooling -101C, small iceball, JT clog suspected — removed'),
    ('Tata Memorial Mumbai','CRYO-TMH-61','Galil Presice','cryoablation_catheter','argon',
     -150.0,-158.0,780,120,40.0,true,true,'2026-06-27','pass','Hepatic cryoablation QC pass, iceball 40mm'),
    ('Tata Memorial Mumbai','CRYO-TMH-62','Erbe Erbokryo CA','cryoprobe','co2',
     -78.0,-80.0,400,70,21.0,true,true,'2026-06-27','pass','CO2 bronchoscopic cryoprobe QC pass'),
    ('Medanta Gurgaon','CRYO-MDN-71','Endocare CryoNeedle','cryo_needle','nitrous_oxide',
     -70.0,-58.0,300,45,12.0,false,true,'2026-06-26','conditional_pass','Cryo needle reached only -58C, thermocouple unverified — flagged'),
    ('Medanta Gurgaon','CRYO-MDN-72','Metrum CryoFlex','cryospray','liquid_nitrogen',
     -196.0,-175.0,20,15,null,true,false,'2026-06-26','fail','LN2 delivery restriction, only -175C, valve/JT fault — removed from service')
  ) as q(hosp, dcode, dmodel, ptype, gas, ttemp, atemp, frz, thaw, ice, tc, jt, cdate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cryo_probe_qc_capa_actions_r3426 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.owner, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CRYO-FRT-12','insufficient_cooling','jt_orifice_clogged','clear_jt_orifice','in_progress','iso_13485_deviation','Biomed - R. Nair','2026-07-08',null,18000.00,'JT orifice cleared; thermocouple re-verify pending'),
    ('CRYO-AIM-32','thermocouple_unverified','thermocouple_drift','replace_thermocouple','verification_pending','nabh_finding','Biomed - S. Rao','2026-07-06',null,9500.00,'Thermocouple replaced, CO2 regas done — verify next case'),
    ('CRYO-KIM-52','joule_thomson_fault','jt_orifice_clogged','replace_probe','escalated','patient_safety_alert','Clinical Eng - A. Gupta','2026-07-05',null,62000.00,'Severe under-cooling, catheter replaced — escalated to Galil OEM'),
    ('CRYO-MDN-72','joule_thomson_fault','valve_regulator_fault','replace_regulator_valve','open','cdsco_notifiable','Biomed - P. Menon','2026-07-04',null,27000.00,'LN2 valve/regulator fault — replacement ordered'),
    ('CRYO-FRT-11','insufficient_cooling','gas_supply_depleted','regas_and_recalibrate','closed','internal_only','Biomed - R. Nair','2026-07-02','2026-06-30',4200.00,'CO2 cylinder swapped and recalibrated — closed'),
    ('CRYO-CMC-42','iceball_undersized','gas_supply_depleted','regas_and_recalibrate','verification_pending','internal_only','Biomed - J. Thomas','2026-07-03',null,3800.00,'Argon regas — verify iceball size next procedure'),
    ('CRYO-MDN-71','thermocouple_unverified','sensor_end_of_life','replace_thermocouple','open','none','Biomed - P. Menon','2026-07-07',null,8800.00,'Cryo needle thermocouple end-of-life — replacement scheduled'),
    ('CRYO-TMH-62','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','Biomed - M. Iyer','2026-06-28',null,15000.00,'Annual PM for bronchoscopic cryoprobe overdue — OEM slot pending')
  ) as q(dcode, fc, rc, ca, cst, ri, owner, tcd, acd, cost, nt)
  join public.cryo_probe_qc_r3426 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3426_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cryo_probe_qc_r3426)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cryo_probe_qc_r3426 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3426_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3426_qc_verdict_rollup() to authenticated;

-- 2) Probe-type QC scorecard
create or replace function public.founder_r3426_probe_type_scorecard()
returns table(
  probe_type text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  thermocouple_fail bigint,
  jt_fail bigint,
  avg_iceball_mm numeric,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.probe_type,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.thermocouple_verified = false)::bigint,
    count(*) filter (where l.joule_thomson_ok = false)::bigint,
    round(avg(l.iceball_diameter_mm), 1),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cryo_probe_qc_r3426 l
  group by l.probe_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3426_probe_type_scorecard() from public, anon;
grant execute on function public.founder_r3426_probe_type_scorecard() to authenticated;

-- 3) Gas-type × verdict matrix
create or replace function public.founder_r3426_gas_type_verdict_matrix()
returns table(
  gas_type text,
  qc_verdict text,
  checks bigint,
  avg_target_temp_c numeric,
  avg_achieved_min_temp_c numeric,
  avg_iceball_mm numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gas_type, l.qc_verdict, count(*)::bigint,
    round(avg(l.target_temp_c), 1),
    round(avg(l.achieved_min_temp_c), 1),
    round(avg(l.iceball_diameter_mm), 1)
  from public.cryo_probe_qc_r3426 l
  group by l.gas_type, l.qc_verdict
  order by l.gas_type, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3426_gas_type_verdict_matrix() from public, anon;
grant execute on function public.founder_r3426_gas_type_verdict_matrix() to authenticated;

-- 4) Monthly calibration trend
create or replace function public.founder_r3426_monthly_calibration_trend()
returns table(
  cal_month date,
  checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  thermocouple_fail bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.thermocouple_verified = false)::bigint
  from public.cryo_probe_qc_r3426 l
  where l.calibration_date is not null
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3426_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3426_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3426_capa_status_board()
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
  from public.cryo_probe_qc_capa_actions_r3426 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3426_capa_status_board() from public, anon;
grant execute on function public.founder_r3426_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3426_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cryo_probe_qc_capa_actions_r3426)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cryo_probe_qc_capa_actions_r3426 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3426_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3426_root_cause_pareto() to authenticated;

-- 7) Thermal-impact digest (per probe type)
create or replace function public.founder_r3426_thermal_impact_digest()
returns table(
  probe_type text,
  checks bigint,
  avg_target_temp_c numeric,
  avg_achieved_min_temp_c numeric,
  avg_temp_gap_c numeric,
  avg_freeze_cycle_sec numeric,
  avg_iceball_mm numeric,
  out_of_tolerance bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.probe_type,
    count(*)::bigint,
    round(avg(l.target_temp_c), 1),
    round(avg(l.achieved_min_temp_c), 1),
    round(avg(l.achieved_min_temp_c - l.target_temp_c), 1),
    round(avg(l.freeze_cycle_sec), 0),
    round(avg(l.iceball_diameter_mm), 1),
    count(*) filter (where l.achieved_min_temp_c > l.target_temp_c)::bigint
  from public.cryo_probe_qc_r3426 l
  group by l.probe_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3426_thermal_impact_digest() from public, anon;
grant execute on function public.founder_r3426_thermal_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / unverified)
create or replace function public.founder_r3426_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  probe_type text,
  gas_type text,
  calibration_date date,
  qc_verdict text,
  target_temp_c numeric,
  achieved_min_temp_c numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.probe_type, l.gas_type,
    l.calibration_date, l.qc_verdict, l.target_temp_c, l.achieved_min_temp_c, l.notes
  from public.cryo_probe_qc_r3426 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.thermocouple_verified = false
     or l.joule_thomson_ok = false
     or (l.achieved_min_temp_c is not null and l.target_temp_c is not null
         and l.achieved_min_temp_c > l.target_temp_c)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3426_high_risk_queue() from public, anon;
grant execute on function public.founder_r3426_high_risk_queue() to authenticated;
