-- Round 3507: Customer Hospital Orthopedic Cast-Saw / Plaster-Cutter QC Audit
-- Ortho oscillating cast saw / plaster cutter QC — parameter × device model × unit × oscillation speed × blade wear × dust extraction × noise × vibration × depth guard × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: cast_saw_qc_r3507 — per-parameter cast-saw / plaster-cutter QC checks
-- =============================================================================
create table if not exists public.cast_saw_qc_r3507 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  location text not null check (location in (
    'plaster_room','orthopedic_ot','fracture_clinic','emergency','ward'
  )),
  parameter text not null check (parameter in (
    'oscillation_rpm','blade_wear_pct','dust_extraction_flow','noise_db','vibration_level','depth_guard_mm'
  )),
  measurement_unit text not null,
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  blade_condition text not null check (blade_condition in (
    'good','worn','chipped','replace_due'
  )),
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cast_saw_qc_r3507 enable row level security;

create index if not exists idx_cast_saw_qc_r3507_org on public.cast_saw_qc_r3507(organization_id);
create index if not exists idx_cast_saw_qc_r3507_date on public.cast_saw_qc_r3507(calibration_date);
create index if not exists idx_cast_saw_qc_r3507_verdict on public.cast_saw_qc_r3507(qc_verdict);

-- =============================================================================
-- TABLE 2: cast_saw_qc_capa_actions_r3507 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cast_saw_qc_capa_actions_r3507 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cast_saw_qc_r3507(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'speed_out_of_tolerance','blade_wear_excessive','dust_extraction_low_flow','noise_exceedance',
    'vibration_high','depth_guard_deviation','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'motor_bearing_wear','blade_end_of_life','extraction_filter_clogged','drive_belt_slippage',
    'guard_misalignment','controller_calibration_drift','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_speed_controller','replace_blade','replace_extraction_filter','replace_drive_belt',
    'realign_depth_guard','service_motor_bearing','retrain_ot_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','staff_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cast_saw_qc_capa_actions_r3507 enable row level security;

create index if not exists idx_cast_saw_capa_r3507_log on public.cast_saw_qc_capa_actions_r3507(qc_log_id);
create index if not exists idx_cast_saw_capa_r3507_status on public.cast_saw_qc_capa_actions_r3507(capa_status);

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
  insert into public.cast_saw_qc_r3507 (
    organization_id, hospital_name, device_code, device_model, location, parameter,
    measurement_unit, reference_value, measured_value, deviation_pct, within_tolerance,
    blade_condition, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.loc, q.param,
    q.munit, q.refv, q.measv, q.dev, q.wtol,
    q.blade, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CS-APL-01','DeSoutter CleanCast CC5','orthopedic_ot','oscillation_rpm',
     'rpm',18000,17850,0.83,true,'good','2026-07-05','pass','Oscillation speed within tolerance post-service'),
    ('Apollo Chennai','CS-APL-02','DeSoutter CleanCast CC5','plaster_room','dust_extraction_flow',
     'lpm',250,238,4.80,true,'good','2026-07-05','pass','Dust extraction flow nominal'),
    ('Fortis Gurgaon','CS-FRT-11','Stryker Cast Cutter 986','fracture_clinic','blade_wear_pct',
     'pct',25,28,12.00,false,'worn','2026-07-04','conditional_pass','Blade wear 28% over 25% limit — replacement due'),
    ('Fortis Gurgaon','CS-FRT-12','Stryker Cast Cutter 986','orthopedic_ot','noise_db',
     'db',85,94,10.59,false,'worn','2026-07-04','fail','Noise 94 dB exceeds 85 dB limit — bearing wear suspected'),
    ('Manipal Bengaluru','CS-MNP-21','DeSoutter CC4','plaster_room','oscillation_rpm',
     'rpm',18000,16200,10.00,false,'good','2026-07-03','fail','Speed 10% low — drive belt slippage'),
    ('Manipal Bengaluru','CS-MNP-22','Zimmer 2100','ward','depth_guard_mm',
     'mm',3.0,3.1,3.33,true,'good','2026-07-03','pass','Depth guard within 0.1 mm of setpoint'),
    ('AIIMS Delhi','CS-AIM-31','Stryker Cast Cutter 986','fracture_clinic','vibration_level',
     'mm_per_s',4.5,5.2,15.56,false,'chipped','2026-06-30','fail','Vibration high with chipped blade — removed pending blade'),
    ('AIIMS Delhi','CS-AIM-32','DeSoutter CleanCast CC5','orthopedic_ot','dust_extraction_flow',
     'lpm',250,195,22.00,false,'good','2026-06-30','conditional_pass','Extraction flow 22% low — filter clogged'),
    ('CMC Vellore','CS-CMC-41','Zimmer 2100','plaster_room','blade_wear_pct',
     'pct',25,22,12.00,true,'worn','2026-06-29','conditional_pass','Blade wear 22% — schedule replacement soon'),
    ('CMC Vellore','CS-CMC-42','Zimmer 2100','emergency','noise_db',
     'db',85,81,4.71,true,'good','2026-06-29','pass','Noise 81 dB within limit'),
    ('KIMS Hyderabad','CS-KIM-51','DeSoutter CC4','orthopedic_ot','oscillation_rpm',
     'rpm',18000,18120,0.67,true,'good','2026-06-28','pass','Speed nominal post-calibration'),
    ('KIMS Hyderabad','CS-KIM-52','DeSoutter CC4','fracture_clinic','depth_guard_mm',
     'mm',3.0,3.6,20.00,false,'good','2026-06-28','conditional_pass','Depth guard misaligned 0.6 mm — realign due'),
    ('Yashoda Hyderabad','CS-YSH-61','Stryker Cast Cutter 986','ward','vibration_level',
     'mm_per_s',4.5,4.3,4.44,true,'good','2026-06-27','pass','Vibration 4.3 mm/s within limit'),
    ('Kokilaben Mumbai','CS-KKB-71','Zimmer 2100','orthopedic_ot','noise_db',
     'db',85,98,15.29,false,'chipped','2026-06-27','fail','Excess noise 98 dB with chipped blade — removed from service'),
    ('Kokilaben Mumbai','CS-KKB-72','DeSoutter CleanCast CC5','plaster_room','dust_extraction_flow',
     'lpm',250,244,2.40,true,'good','2026-06-26','pass','Extraction flow nominal'),
    ('Narayana Bengaluru','CS-NAR-81','DeSoutter CC4','fracture_clinic','blade_wear_pct',
     'pct',25,30,20.00,false,'replace_due','2026-06-26','conditional_pass','Blade wear 30% over limit — replace immediately')
  ) as q(hosp, dcode, dmodel, loc, param, munit, refv, measv, dev, wtol, blade, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cast_saw_qc_capa_actions_r3507 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CS-FRT-11','blade_wear_excessive','blade_end_of_life','replace_blade','in_progress','internal_only','2026-07-08',null,3500.00,'Blade 28% over limit — replacement scheduled'),
    ('CS-FRT-12','noise_exceedance','motor_bearing_wear','service_motor_bearing','escalated','staff_safety_alert','2026-07-07',null,18000.00,'Noise 94 dB — bearing service escalated to OEM'),
    ('CS-MNP-21','speed_out_of_tolerance','drive_belt_slippage','replace_drive_belt','open','iso_13485_deviation','2026-07-06',null,4200.00,'Speed 10% low — drive belt replacement'),
    ('CS-AIM-31','vibration_high','blade_end_of_life','remove_from_service','closed','cdsco_notifiable','2026-07-04','2026-07-02',3500.00,'Chipped blade removed; new blade fitted and validated'),
    ('CS-AIM-32','dust_extraction_low_flow','extraction_filter_clogged','replace_extraction_filter','verification_pending','nabh_finding','2026-07-05',null,2600.00,'Extraction filter replaced — verify flow next PM'),
    ('CS-KIM-52','depth_guard_deviation','guard_misalignment','realign_depth_guard','open','internal_only','2026-07-06',null,1500.00,'Depth guard 0.6 mm off — realign scheduled'),
    ('CS-KKB-71','noise_exceedance','motor_bearing_wear','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-29',22000.00,'High noise with chipped blade — unit removed and rebuilt'),
    ('CS-NAR-81','blade_wear_excessive','preventive_service_backlog','replace_blade','overdue','internal_only','2026-06-30',null,3500.00,'Blade replacement overdue — PM backlog')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cast_saw_qc_r3507 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3507_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cast_saw_qc_r3507)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cast_saw_qc_r3507 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3507_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3507_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3507_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
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
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cast_saw_qc_r3507 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3507_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3507_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3507_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cast_saw_qc_r3507 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3507_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3507_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3507_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cast_saw_qc_r3507 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3507_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3507_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3507_capa_status_board()
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
  from public.cast_saw_qc_capa_actions_r3507 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3507_capa_status_board() from public, anon;
grant execute on function public.founder_r3507_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3507_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cast_saw_qc_capa_actions_r3507)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cast_saw_qc_capa_actions_r3507 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3507_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3507_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3507_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric,
  within_tolerance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1)
  from public.cast_saw_qc_r3507 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3507_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3507_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3507_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  blade_condition text,
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.blade_condition, l.notes
  from public.cast_saw_qc_r3507 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.blade_condition in ('chipped','replace_due')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3507_high_risk_queue() from public, anon;
grant execute on function public.founder_r3507_high_risk_queue() to authenticated;
