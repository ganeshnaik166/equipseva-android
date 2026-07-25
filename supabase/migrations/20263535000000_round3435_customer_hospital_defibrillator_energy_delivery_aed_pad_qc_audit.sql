-- Round 3435: Customer Hospital Defibrillator Energy-Delivery / AED Pad QC Audit
-- Defib/AED QA — defib type × set vs delivered energy × energy deviation × charge time × sync mode × pad expiry × battery health × ECG recorder × calibration × CAPA

-- =============================================================================
-- TABLE 1: defib_energy_aed_qc_r3435 — per-device defibrillator/AED energy-delivery QC checks
-- =============================================================================
create table if not exists public.defib_energy_aed_qc_r3435 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  defib_type text not null check (defib_type in (
    'manual','aed','biphasic_manual','wearable'
  )),
  set_energy_joules numeric(6,2),
  delivered_energy_joules numeric(6,2),
  energy_deviation_pct numeric(6,2),
  charge_time_sec numeric(6,2),
  sync_mode_ok boolean not null,
  pad_expiry_date date,
  battery_health_pct int,
  ecg_recorder_ok boolean not null,
  calibration_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.defib_energy_aed_qc_r3435 enable row level security;

create index if not exists idx_defib_energy_aed_qc_r3435_org on public.defib_energy_aed_qc_r3435(organization_id);
create index if not exists idx_defib_energy_aed_qc_r3435_cal on public.defib_energy_aed_qc_r3435(calibration_date);
create index if not exists idx_defib_energy_aed_qc_r3435_verdict on public.defib_energy_aed_qc_r3435(qc_verdict);

-- =============================================================================
-- TABLE 2: defib_energy_aed_qc_capa_actions_r3435 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.defib_energy_aed_qc_capa_actions_r3435 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.defib_energy_aed_qc_r3435(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'energy_out_of_tolerance','delivered_energy_shortfall','sync_mode_failure','charge_time_excessive',
    'pad_expired','battery_low','ecg_recorder_fault','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'capacitor_degradation','internal_calibration_drift','battery_end_of_life','pad_stock_expired',
    'ecg_module_fault','firmware_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_energy_output','replace_capacitor_module','replace_battery','replace_pad_stock',
    'repair_ecg_recorder','update_firmware','retrain_clinical_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.defib_energy_aed_qc_capa_actions_r3435 enable row level security;

create index if not exists idx_defib_energy_aed_capa_r3435_log on public.defib_energy_aed_qc_capa_actions_r3435(qc_log_id);
create index if not exists idx_defib_energy_aed_capa_r3435_status on public.defib_energy_aed_qc_capa_actions_r3435(capa_status);

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
  insert into public.defib_energy_aed_qc_r3435 (
    organization_id, hospital_name, device_code, device_model, defib_type,
    set_energy_joules, delivered_energy_joules, energy_deviation_pct, charge_time_sec,
    sync_mode_ok, pad_expiry_date, battery_health_pct, ecg_recorder_ok, calibration_date,
    qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.dtype,
    q.setj, q.delj, q.devpct, q.chgt,
    q.syncok, q.padexp::date, q.batt, q.ecgok, q.caldate::date,
    q.qv, q.nt
  from (values
    ('Apollo Chennai','DEF-APL-01','LifePak 20e','biphasic_manual',
     200,197.5,-1.25,6.5,true,'2027-05-01',96,true,'2026-07-05','pass',
     'Quarterly QC — biphasic energy within 1.5% and pads current'),
    ('Apollo Chennai','AED-APL-02','Zoll AED Plus','aed',
     150,149.0,-0.67,8.0,true,'2027-02-01',92,true,'2026-07-05','pass',
     'AED self-test clean, pads and battery in date'),
    ('Fortis Gurgaon','DEF-FRT-11','Philips HeartStart XL','biphasic_manual',
     200,182.0,-9.0,7.2,true,'2026-08-01',78,true,'2026-07-02','conditional_pass',
     'Delivered energy 9% low — near tolerance, recalibration flagged'),
    ('Fortis Gurgaon','DEF-FRT-12','LifePak 15','manual',
     360,300.0,-16.67,9.5,false,'2026-06-15',61,false,'2026-07-02','fail',
     'Energy 16.7% low, sync fail, ECG recorder dead and pads expired'),
    ('Manipal Bengaluru','AED-MNP-21','Zoll AED 3','aed',
     200,205.0,2.5,7.0,true,'2027-09-01',88,true,'2026-06-28','pass',
     'AED delivered energy within 2.5%, all self-tests pass'),
    ('Manipal Bengaluru','WCD-MNP-22','Zoll LifeVest','wearable',
     150,150.0,0.0,null,true,null,94,true,'2026-06-28','pass',
     'Wearable cardioverter defibrillator monitored QC nominal'),
    ('AIIMS Delhi','DEF-AIM-31','Philips HeartStart MRx','biphasic_manual',
     200,191.0,-4.5,6.8,true,'2026-09-15',84,true,'2026-06-30','conditional_pass',
     'Energy 4.5% low with widening deviation trend — watch'),
    ('AIIMS Delhi','DEF-AIM-32','LifePak 20','manual',
     360,312.0,-13.33,10.5,false,'2026-07-10',55,true,'2026-06-30','fail',
     'Manual defib 13% shortfall, sync failed and battery low'),
    ('CMC Vellore','AED-CMC-41','Philips HeartStart FRx','aed',
     150,148.0,-1.33,8.5,true,'2027-01-01',90,true,'2026-06-25','pass',
     'AED FRx pads current, energy within 1.5%'),
    ('CMC Vellore','DEF-CMC-42','Nihon Kohden TEC-5600','biphasic_manual',
     200,200.0,0.0,6.0,true,'2026-08-20',70,true,'2026-05-20','conditional_pass',
     'Energy spot-on but pad rotation and battery health declining'),
    ('KIMS Hyderabad','DEF-KIM-51','LifePak 20e','biphasic_manual',
     200,196.0,-2.0,6.4,true,'2027-04-01',93,true,'2026-05-18','pass',
     'Post-AMC QC pass, energy within 2%'),
    ('KIMS Hyderabad','AED-KIM-52','Zoll AED Plus','aed',
     120,121.0,0.83,7.5,true,'2026-07-20',47,true,'2026-05-18','conditional_pass',
     'Pads expired and battery at 47% — replacement scheduled'),
    ('Yashoda Hyderabad','WCD-YSH-61','Zoll LifeVest','wearable',
     150,149.0,-0.67,null,true,null,91,true,'2026-05-15','pass',
     'Wearable defibrillator garment QC nominal, battery healthy'),
    ('Kokilaben Mumbai','DEF-KKB-71','Philips HeartStart XL+','biphasic_manual',
     360,300.0,-16.67,11.0,false,'2026-06-01',40,false,'2026-04-30','fail',
     'Energy 16.7% low, sync + ECG fail, battery 40% and pads expired'),
    ('Kokilaben Mumbai','AED-KKB-72','Cardiac Science G5','aed',
     200,198.0,-1.0,8.2,true,'2027-06-01',89,true,'2026-04-28','pass',
     'AED G5 pads and battery in date, energy within 1%'),
    ('Narayana Bengaluru','DEF-NAR-81','LifePak 15','manual',
     360,348.0,-3.33,9.0,true,'2026-10-01',82,true,'2026-07-10','conditional_pass',
     'Manual defib energy within 3.3% — sync verification requested')
  ) as q(hosp, dcode, dmodel, dtype, setj, delj, devpct, chgt, syncok, padexp, batt, ecgok, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.defib_energy_aed_qc_capa_actions_r3435 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DEF-FRT-12','energy_out_of_tolerance','capacitor_degradation','replace_capacitor_module','in_progress','iso_13485_deviation','2026-07-30',null,85000.00,'Energy delivery 16.7% low — capacitor bank flagged for replacement'),
    ('DEF-KKB-71','energy_out_of_tolerance','capacitor_degradation','remove_from_service','escalated','patient_safety_alert','2026-07-28',null,120000.00,'Multiple failures — removed pending capacitor and battery replacement'),
    ('DEF-AIM-32','delivered_energy_shortfall','internal_calibration_drift','recalibrate_energy_output','open','cdsco_notifiable','2026-07-31',null,22000.00,'Manual defib 13% shortfall — OEM recalibration booked'),
    ('AED-KIM-52','pad_expired','pad_stock_expired','replace_pad_stock','verification_pending','nabh_finding','2026-07-27',null,6500.00,'Expired AED pads plus low battery — pad stock replaced'),
    ('DEF-FRT-11','energy_out_of_tolerance','internal_calibration_drift','recalibrate_energy_output','closed','internal_only','2026-07-06','2026-07-05',15000.00,'Recalibrated — delivered energy back within 3%'),
    ('DEF-CMC-42','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-10',null,18000.00,'Battery health declining and pad rotation — PM overdue'),
    ('DEF-KKB-71','battery_low','battery_end_of_life','replace_battery','in_progress','patient_safety_alert','2026-07-29',null,34000.00,'Battery at 40% — replacement pack en route'),
    ('DEF-FRT-12','ecg_recorder_fault','ecg_module_fault','repair_ecg_recorder','open','iso_13485_deviation','2026-08-02',null,12000.00,'ECG strip recorder non-functional — module repair scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.defib_energy_aed_qc_r3435 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3435_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.defib_energy_aed_qc_r3435)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.defib_energy_aed_qc_r3435 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3435_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3435_qc_verdict_rollup() to authenticated;

-- 2) Defib-type scorecard
create or replace function public.founder_r3435_defib_type_scorecard()
returns table(
  defib_type text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  sync_fail bigint,
  expired_pad bigint,
  low_battery bigint,
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
  select l.defib_type,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.sync_mode_ok = false)::bigint,
    count(*) filter (where l.pad_expiry_date is not null and l.pad_expiry_date < current_date)::bigint,
    count(*) filter (where l.battery_health_pct is not null and l.battery_health_pct < 50)::bigint,
    round(avg(l.energy_deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.defib_energy_aed_qc_r3435 l
  group by l.defib_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3435_defib_type_scorecard() from public, anon;
grant execute on function public.founder_r3435_defib_type_scorecard() to authenticated;

-- 3) Defib-type × verdict matrix
create or replace function public.founder_r3435_defib_type_verdict_matrix()
returns table(defib_type text, qc_verdict text, checks bigint, avg_deviation_pct numeric, avg_charge_time_sec numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.defib_type, l.qc_verdict, count(*)::bigint,
    round(avg(l.energy_deviation_pct), 2),
    round(avg(l.charge_time_sec), 2)
  from public.defib_energy_aed_qc_r3435 l
  group by l.defib_type, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3435_defib_type_verdict_matrix() from public, anon;
grant execute on function public.founder_r3435_defib_type_verdict_matrix() to authenticated;

-- 4) Monthly calibration trend
create or replace function public.founder_r3435_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, avg_deviation_pct numeric, avg_battery_health numeric)
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
    round(avg(l.energy_deviation_pct), 2),
    round(avg(l.battery_health_pct), 1)
  from public.defib_energy_aed_qc_r3435 l
  where l.calibration_date is not null
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3435_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3435_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3435_capa_status_board()
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
  from public.defib_energy_aed_qc_capa_actions_r3435 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3435_capa_status_board() from public, anon;
grant execute on function public.founder_r3435_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3435_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.defib_energy_aed_qc_capa_actions_r3435)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.defib_energy_aed_qc_capa_actions_r3435 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3435_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3435_root_cause_pareto() to authenticated;

-- 7) Energy-accuracy impact digest
create or replace function public.founder_r3435_energy_accuracy_digest()
returns table(
  defib_type text,
  checks bigint,
  avg_set_joules numeric,
  avg_delivered_joules numeric,
  avg_deviation_pct numeric,
  out_of_tolerance bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.defib_type,
    count(*)::bigint,
    round(avg(l.set_energy_joules), 1),
    round(avg(l.delivered_energy_joules), 1),
    round(avg(l.energy_deviation_pct), 2),
    count(*) filter (where l.energy_deviation_pct is not null and abs(l.energy_deviation_pct) > 10)::bigint
  from public.defib_energy_aed_qc_r3435 l
  group by l.defib_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3435_energy_accuracy_digest() from public, anon;
grant execute on function public.founder_r3435_energy_accuracy_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / expired-pad / failed)
create or replace function public.founder_r3435_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  defib_type text,
  calibration_date date,
  qc_verdict text,
  energy_deviation_pct numeric,
  charge_time_sec numeric,
  battery_health_pct int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.defib_type, l.calibration_date,
    l.qc_verdict, l.energy_deviation_pct, l.charge_time_sec, l.battery_health_pct, l.notes
  from public.defib_energy_aed_qc_r3435 l
  where l.qc_verdict in ('conditional_pass','fail')
     or (l.energy_deviation_pct is not null and abs(l.energy_deviation_pct) > 10)
     or l.sync_mode_ok = false
     or l.ecg_recorder_ok = false
     or (l.pad_expiry_date is not null and l.pad_expiry_date < current_date)
     or (l.battery_health_pct is not null and l.battery_health_pct < 50)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3435_high_risk_queue() from public, anon;
grant execute on function public.founder_r3435_high_risk_queue() to authenticated;
