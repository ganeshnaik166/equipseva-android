-- Round 3482: Customer Hospital CO2 Incubator (Cell-Culture) QC Audit
-- CO2 incubator cell-culture QC — parameter (temp / CO2% / humidity / O2 / recovery time / HEPA particle count)
-- x reference vs measured x deviation% x tolerance x contamination guard x door-seal / HEPA x calibration x CAPA

-- =============================================================================
-- TABLE 1: co2_incubator_qc_r3482 — per-device / per-parameter CO2 incubator QC checks
-- =============================================================================
create table if not exists public.co2_incubator_qc_r3482 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'temp_c','co2_pct','humidity_pct','o2_pct','recovery_time_min','hepa_particle_count'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(8,2),
  within_tolerance boolean not null,
  co2_sensor_type text not null check (co2_sensor_type in (
    'ir','tcd','not_applicable'
  )),
  contamination_check text not null check (contamination_check in (
    'clean','fungal_growth','bacterial_growth','not_tested'
  )),
  door_seal_ok boolean not null,
  hepa_filter_ok boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.co2_incubator_qc_r3482 enable row level security;

create index if not exists idx_co2_incubator_qc_r3482_org on public.co2_incubator_qc_r3482(organization_id);
create index if not exists idx_co2_incubator_qc_r3482_cal on public.co2_incubator_qc_r3482(calibration_date);
create index if not exists idx_co2_incubator_qc_r3482_verdict on public.co2_incubator_qc_r3482(qc_verdict);

-- =============================================================================
-- TABLE 2: co2_incubator_qc_capa_actions_r3482 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.co2_incubator_qc_capa_actions_r3482 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.co2_incubator_qc_r3482(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'co2_out_of_tolerance','temperature_out_of_tolerance','humidity_out_of_tolerance',
    'o2_out_of_tolerance','slow_recovery_time','hepa_particle_excursion',
    'contamination_detected','door_seal_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'co2_sensor_drift','temperature_sensor_drift','humidity_reservoir_dry','o2_sensor_degraded',
    'door_gasket_worn','hepa_filter_clogged','contamination_ingress','gas_supply_regulator_fault',
    'operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_co2_sensor','recalibrate_temperature','refill_humidity_reservoir','replace_o2_sensor',
    'replace_door_gasket','replace_hepa_filter','decontamination_cycle','replace_gas_regulator',
    'retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','gmp_deviation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.co2_incubator_qc_capa_actions_r3482 enable row level security;

create index if not exists idx_co2_incubator_capa_r3482_log on public.co2_incubator_qc_capa_actions_r3482(qc_log_id);
create index if not exists idx_co2_incubator_capa_r3482_status on public.co2_incubator_qc_capa_actions_r3482(capa_status);

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

  -- 16 QC check rows
  insert into public.co2_incubator_qc_r3482 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    co2_sensor_type, contamination_check, door_seal_ok, hepa_filter_ok,
    calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.rv, q.mv, q.dev, q.wt,
    q.sensortype, q.contam, q.dseal, q.hepa,
    q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','CO2-APL-01','Thermo Forma 3110','temp_c',
     37.0,37.1,0.27,true,'not_applicable','clean',true,true,'2026-07-05',true,'pass','Temperature within +/-0.3C — IVF lab incubator QC pass'),
    ('Apollo Chennai','CO2-APL-02','Thermo Forma 3110','co2_pct',
     5.0,5.1,2.00,true,'ir','clean',true,true,'2026-07-05',true,'pass','IR CO2 sensor within tolerance vs Fyrite reference'),
    ('Apollo Chennai','CO2-APL-03','Panasonic MCO-170AIC','humidity_pct',
     95.0,92.0,-3.16,true,'not_applicable','clean',true,true,'2026-06-15',true,'conditional_pass','Humidity marginally low — reservoir top-up advised'),
    ('Fortis Gurgaon','CO2-FRT-11','Binder CB170','co2_pct',
     5.0,5.9,18.00,false,'tcd','clean',true,true,'2026-06-10',true,'fail','TCD CO2 reading 18% high — sensor drift, out of tolerance'),
    ('Fortis Gurgaon','CO2-FRT-12','Binder CB170','temp_c',
     37.0,38.2,3.24,false,'not_applicable','clean',false,true,'2026-06-10',true,'fail','Chamber over-temp and door seal leak on load test'),
    ('Manipal Bengaluru','CO2-MNP-21','Eppendorf Galaxy 170S','o2_pct',
     5.0,5.4,8.00,true,'not_applicable','clean',true,true,'2026-05-20',true,'conditional_pass','Tri-gas low-O2 setpoint 8% high — recheck N2 supply'),
    ('Manipal Bengaluru','CO2-MNP-22','Eppendorf Galaxy 170S','hepa_particle_count',
     100.0,95.0,-5.00,true,'not_applicable','clean',true,true,'2026-05-20',true,'pass','In-chamber HEPA particle count below action limit'),
    ('AIIMS Delhi','CO2-AIM-31','Thermo Heracell 150i','recovery_time_min',
     5.0,8.5,70.00,false,'not_applicable','clean',true,true,'2026-05-12',true,'fail','CO2 recovery after door-open exceeds 5 min target'),
    ('AIIMS Delhi','CO2-AIM-32','Memmert ICO150','hepa_particle_count',
     100.0,4200.0,4100.00,false,'not_applicable','fungal_growth',true,false,'2026-04-28',false,'fail','HEPA particle excursion with fungal growth and overdue cal'),
    ('CMC Vellore','CO2-CMC-41','Thermo Forma 3110','co2_pct',
     5.0,5.0,0.00,true,'ir','clean',true,true,'2026-04-20',true,'pass','IR CO2 exact to reference — QC pass'),
    ('CMC Vellore','CO2-CMC-42','Panasonic MCO-170AIC','humidity_pct',
     95.0,88.0,-7.37,false,'not_applicable','not_tested',true,true,'2026-04-20',false,'conditional_pass','Humidity low and calibration overdue — reservoir refill due'),
    ('KIMS Hyderabad','CO2-KIM-51','Binder CB170','temp_c',
     37.0,37.0,0.00,true,'not_applicable','clean',true,true,'2026-07-01',true,'pass','Temperature exact to reference — QC pass'),
    ('KIMS Hyderabad','CO2-KIM-52','Eppendorf Galaxy 170S','co2_pct',
     5.0,4.6,-8.00,true,'ir','clean',true,true,'2026-07-01',true,'conditional_pass','CO2 8% low — within alert band, recalibration advised'),
    ('Yashoda Hyderabad','CO2-YSH-61','Thermo Heracell 240i','o2_pct',
     5.0,6.2,24.00,false,'not_applicable','bacterial_growth',false,false,'2026-06-25',false,'fail','O2 far off setpoint, bacterial growth, seal and HEPA fail'),
    ('Kokilaben Mumbai','CO2-KKB-71','Memmert ICO150','recovery_time_min',
     5.0,5.2,4.00,true,'not_applicable','clean',true,true,'2026-05-30',true,'pass','Recovery time within target after door-open test'),
    ('Kokilaben Mumbai','CO2-KKB-72','Panasonic MCO-170AIC','hepa_particle_count',
     100.0,130.0,30.00,true,'not_applicable','clean',true,true,'2026-04-15',true,'conditional_pass','Particle count slightly elevated — pre-filter clean scheduled')
  ) as q(hosp, dcode, dmodel, param, rv, mv, dev, wt, sensortype, contam, dseal, hepa, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.co2_incubator_qc_capa_actions_r3482 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CO2-FRT-11','co2_out_of_tolerance','co2_sensor_drift','recalibrate_co2_sensor','in_progress','iso_15189_deviation','2026-06-20',null,12000.00,'CO2 sensor span-calibrated with certified gas — verification pending'),
    ('CO2-FRT-12','temperature_out_of_tolerance','door_gasket_worn','replace_door_gasket','open','nabh_finding','2026-06-18',null,8500.00,'Door gasket replacement scheduled; over-temp on load test'),
    ('CO2-AIM-31','slow_recovery_time','gas_supply_regulator_fault','replace_gas_regulator','verification_pending','internal_only','2026-05-25',null,15000.00,'CO2 regulator replaced — recovery-time retest queued'),
    ('CO2-AIM-32','contamination_detected','contamination_ingress','decontamination_cycle','escalated','gmp_deviation','2026-05-05',null,55000.00,'Fungal growth — full decon cycle and HEPA swap, cultures escalated'),
    ('CO2-YSH-61','contamination_detected','hepa_filter_clogged','replace_hepa_filter','open','cdsco_notifiable','2026-07-08',null,42000.00,'Bacterial growth with seal and HEPA failure — unit quarantined'),
    ('CO2-CMC-42','humidity_out_of_tolerance','humidity_reservoir_dry','refill_humidity_reservoir','closed','internal_only','2026-04-25','2026-04-22',500.00,'Humidity reservoir refilled and RH re-verified — closed'),
    ('CO2-KIM-52','co2_out_of_tolerance','co2_sensor_drift','recalibrate_co2_sensor','closed','internal_only','2026-07-05','2026-07-03',3000.00,'CO2 sensor recalibrated to reference — QC re-passed'),
    ('CO2-APL-03','humidity_out_of_tolerance','humidity_reservoir_dry','refill_humidity_reservoir','overdue','internal_only','2026-06-25',null,500.00,'Reservoir refill overdue — RH trending low across cases')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.co2_incubator_qc_r3482 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3482_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.co2_incubator_qc_r3482)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.co2_incubator_qc_r3482 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3482_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3482_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3482_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  contamination_flag bigint,
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
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.contamination_check in ('fungal_growth','bacterial_growth'))::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.co2_incubator_qc_r3482 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3482_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3482_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3482_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, out_of_tolerance bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.within_tolerance = false)::bigint
  from public.co2_incubator_qc_r3482 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3482_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3482_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3482_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.calibration_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.co2_incubator_qc_r3482 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3482_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3482_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3482_capa_status_board()
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
  from public.co2_incubator_qc_capa_actions_r3482 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3482_capa_status_board() from public, anon;
grant execute on function public.founder_r3482_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3482_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.co2_incubator_qc_capa_actions_r3482)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.co2_incubator_qc_capa_actions_r3482 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3482_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3482_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3482_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tolerance_count bigint,
  out_of_tolerance_count bigint,
  avg_abs_deviation_pct numeric,
  max_abs_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.co2_incubator_qc_r3482 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3482_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3482_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3482_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  contamination_check text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.calibration_date,
    l.qc_verdict, l.deviation_pct, l.contamination_check, l.notes
  from public.co2_incubator_qc_r3482 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.contamination_check in ('fungal_growth','bacterial_growth')
     or l.door_seal_ok = false
     or l.hepa_filter_ok = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3482_high_risk_queue() from public, anon;
grant execute on function public.founder_r3482_high_risk_queue() to authenticated;
