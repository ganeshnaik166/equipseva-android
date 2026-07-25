-- Round 3434: Customer Hospital CPM (Continuous Passive Motion) ROM-Therapy QC Audit
-- CPM rehab machine QA — joint × set/measured ROM angle × ROM deviation × set/measured speed × force limit × emergency-stop × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: cpm_rom_qc_r3434 — per-device CPM ROM-therapy QC checks
-- =============================================================================
create table if not exists public.cpm_rom_qc_r3434 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  joint text not null check (joint in (
    'knee','shoulder','elbow','hip','ankle','wrist'
  )),
  set_rom_deg numeric(6,2),
  measured_rom_deg numeric(6,2),
  rom_deviation_deg numeric(6,2),
  set_speed_cpm numeric(6,2),
  measured_speed_cpm numeric(6,2),
  force_limit_n numeric(6,2),
  emergency_stop_ok boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cpm_rom_qc_r3434 enable row level security;

create index if not exists idx_cpm_rom_qc_r3434_org on public.cpm_rom_qc_r3434(organization_id);
create index if not exists idx_cpm_rom_qc_r3434_cal on public.cpm_rom_qc_r3434(calibration_date);
create index if not exists idx_cpm_rom_qc_r3434_verdict on public.cpm_rom_qc_r3434(qc_verdict);

-- =============================================================================
-- TABLE 2: cpm_rom_qc_capa_actions_r3434 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cpm_rom_qc_capa_actions_r3434 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cpm_rom_qc_r3434(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'rom_out_of_tolerance','speed_out_of_tolerance','force_limit_exceeded',
    'emergency_stop_failure','calibration_overdue','mechanical_wear',
    'sensor_drift','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'encoder_drift','gearbox_wear','actuator_fault','control_board_error',
    'sensor_miscalibration','operator_setup_error','pending_investigation',
    'preventive_service_backlog','worn_bearing'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_encoder','replace_gearbox','replace_actuator','replace_control_board',
    'recalibrate_sensor','retrain_therapy_staff','remove_from_service',
    'schedule_oem_service','none_required'
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

alter table public.cpm_rom_qc_capa_actions_r3434 enable row level security;

create index if not exists idx_cpm_rom_qc_capa_r3434_log on public.cpm_rom_qc_capa_actions_r3434(qc_log_id);
create index if not exists idx_cpm_rom_qc_capa_r3434_status on public.cpm_rom_qc_capa_actions_r3434(capa_status);

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

  -- 16 CPM ROM-therapy QC check rows
  insert into public.cpm_rom_qc_r3434 (
    organization_id, hospital_name, device_code, device_model, joint,
    set_rom_deg, measured_rom_deg, rom_deviation_deg, set_speed_cpm, measured_speed_cpm,
    force_limit_n, emergency_stop_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.joint,
    q.srom, q.mrom, q.rdev, q.sspeed, q.mspeed,
    q.flim, q.estop, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CPM-APL-01','Kinetec Optima Knee','knee',
     110,109,1.0,2.0,2.0,120,true,'2026-07-03','pass','Knee CPM QC within tolerance'),
    ('Apollo Chennai','CPM-APL-02','Artromot K1 Knee','knee',
     120,116,4.0,1.5,1.4,120,true,'2026-07-03','conditional_pass','ROM 4 deg short of setpoint — recalibration advised'),
    ('Fortis Gurgaon','CPM-FRT-11','Artromot S3 Shoulder','shoulder',
     90,82,8.0,1.0,0.9,90,true,'2026-06-15','fail','Shoulder ROM 8 deg deviation out of tolerance'),
    ('Fortis Gurgaon','CPM-FRT-12','Kinetec Centura Elbow','elbow',
     130,129,1.0,2.0,2.1,80,true,'2026-06-15','pass','Elbow CPM QC nominal'),
    ('Manipal Bengaluru','CPM-MNP-21','ORMED Artromot Hip','hip',
     100,94,6.0,1.2,1.0,150,false,'2026-05-20','fail','Hip CPM emergency-stop failed and ROM 6 deg off'),
    ('Manipal Bengaluru','CPM-MNP-22','Chattanooga OptiFlex Knee','knee',
     115,114,1.0,2.5,2.5,120,true,'2026-06-28','pass','Knee CPM QC pass post-AMC'),
    ('AIIMS Delhi','CPM-AIM-31','Kinetec Optima Knee','knee',
     120,117,3.0,2.0,1.8,120,true,'2026-06-30','conditional_pass','ROM 3 deg deviation with speed drift trend'),
    ('AIIMS Delhi','CPM-AIM-32','Artromot SP3 Ankle','ankle',
     45,40,5.0,1.5,1.4,60,true,'2026-05-10','fail','Ankle ROM 5 deg short and calibration overdue'),
    ('CMC Vellore','CPM-CMC-41','Kinetec Maestra Wrist','wrist',
     70,69,1.0,1.8,1.8,40,true,'2026-06-29','pass','Wrist/hand CPM QC pass'),
    ('CMC Vellore','CPM-CMC-42','Artromot S3 Shoulder','shoulder',
     120,113,7.0,1.0,0.8,90,true,'2026-06-05','fail','Shoulder ROM 7 deg deviation and speed low'),
    ('KIMS Hyderabad','CPM-KIM-51','Kinetec Optima Knee','knee',
     110,110,0.0,2.0,2.0,120,true,'2026-07-01','pass','Knee CPM QC pass'),
    ('KIMS Hyderabad','CPM-KIM-52','ORMED Artromot Hip','hip',
     95,92,3.0,1.2,1.1,150,true,'2026-06-20','conditional_pass','Hip ROM 3 deg with force-sensor recheck due'),
    ('Yashoda Hyderabad','CPM-YSH-61','Chattanooga OptiFlex Elbow','elbow',
     130,128,2.0,2.0,1.9,80,true,'2026-06-27','pass','Elbow CPM QC nominal'),
    ('Yashoda Hyderabad','CPM-YSH-62','Kinetec Optima Knee','knee',
     120,108,12.0,2.5,2.0,120,false,'2026-04-30','fail','Knee ROM 12 deg deviation, e-stop failed, removed'),
    ('Kokilaben Mumbai','CPM-KKB-71','Artromot SP3 Ankle','ankle',
     50,49,1.0,1.5,1.5,60,true,'2026-07-02','pass','Ankle CPM QC pass'),
    ('Kokilaben Mumbai','CPM-KKB-72','Kinetec Maestra Wrist','wrist',
     80,74,6.0,1.8,1.5,40,true,'2026-05-15','fail','Wrist ROM 6 deg deviation and calibration overdue')
  ) as q(hosp, dcode, dmodel, joint, srom, mrom, rdev, sspeed, mspeed, flim, estop, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cpm_rom_qc_capa_actions_r3434 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CPM-FRT-11','rom_out_of_tolerance','encoder_drift','recalibrate_encoder','in_progress','iso_13485_deviation','2026-06-25',null,12000.00,'Shoulder ROM encoder recalibration in progress'),
    ('CPM-MNP-21','emergency_stop_failure','control_board_error','replace_control_board','escalated','patient_safety_alert','2026-06-05',null,38000.00,'E-stop failure escalated to OEM'),
    ('CPM-AIM-32','calibration_overdue','preventive_service_backlog','schedule_oem_service','open','nabh_finding','2026-06-20',null,9000.00,'Ankle CPM calibration overdue — OEM visit scheduled'),
    ('CPM-CMC-42','rom_out_of_tolerance','gearbox_wear','replace_gearbox','verification_pending','internal_only','2026-06-18',null,27000.00,'Gearbox replaced — verify ROM next PM'),
    ('CPM-YSH-62','mechanical_wear','worn_bearing','remove_from_service','closed','cdsco_notifiable','2026-05-10','2026-05-08',52000.00,'Worn bearing — unit removed and rebuilt'),
    ('CPM-KKB-72','calibration_overdue','sensor_miscalibration','recalibrate_sensor','overdue','internal_only','2026-06-01',null,6000.00,'Wrist sensor recalibration past due — parts delay'),
    ('CPM-APL-02','rom_out_of_tolerance','encoder_drift','recalibrate_encoder','closed','internal_only','2026-07-10','2026-07-08',5000.00,'Knee encoder recalibrated and verified'),
    ('CPM-KIM-52','speed_out_of_tolerance','operator_setup_error','retrain_therapy_staff','open','none','2026-07-05',null,0.00,'Speed setup retraining scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cpm_rom_qc_r3434 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3434_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cpm_rom_qc_r3434)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cpm_rom_qc_r3434 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3434_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3434_qc_verdict_rollup() to authenticated;

-- 2) Joint-level QC scorecard
create or replace function public.founder_r3434_joint_scorecard()
returns table(
  joint text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  estop_fail bigint,
  avg_rom_deviation_deg numeric,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.joint,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    round(avg(abs(l.rom_deviation_deg)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cpm_rom_qc_r3434 l
  group by l.joint
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3434_joint_scorecard() from public, anon;
grant execute on function public.founder_r3434_joint_scorecard() to authenticated;

-- 3) Joint × verdict matrix
create or replace function public.founder_r3434_joint_verdict_matrix()
returns table(joint text, qc_verdict text, checks bigint, avg_rom_deviation_deg numeric, avg_speed_deviation_cpm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.joint, l.qc_verdict, count(*)::bigint,
    round(avg(abs(l.rom_deviation_deg)), 2),
    round(avg(abs(l.set_speed_cpm - l.measured_speed_cpm)), 2)
  from public.cpm_rom_qc_r3434 l
  group by l.joint, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3434_joint_verdict_matrix() from public, anon;
grant execute on function public.founder_r3434_joint_verdict_matrix() to authenticated;

-- 4) Monthly calibration trend
create or replace function public.founder_r3434_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, estop_fail bigint, avg_rom_deviation_deg numeric)
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
    count(*) filter (where l.emergency_stop_ok = false)::bigint,
    round(avg(abs(l.rom_deviation_deg)), 2)
  from public.cpm_rom_qc_r3434 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3434_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3434_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3434_capa_status_board()
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
  from public.cpm_rom_qc_capa_actions_r3434 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3434_capa_status_board() from public, anon;
grant execute on function public.founder_r3434_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3434_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cpm_rom_qc_capa_actions_r3434)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cpm_rom_qc_capa_actions_r3434 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3434_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3434_root_cause_pareto() to authenticated;

-- 7) ROM-accuracy impact digest (deviation bands)
create or replace function public.founder_r3434_rom_accuracy_impact_digest()
returns table(accuracy_band text, checks bigint, avg_rom_deviation_deg numeric, avg_speed_deviation_cpm numeric, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    case
      when abs(l.rom_deviation_deg) <= 2 then 'within_2deg'
      when abs(l.rom_deviation_deg) <= 5 then 'within_5deg'
      when abs(l.rom_deviation_deg) <= 10 then 'within_10deg'
      else 'over_10deg'
    end as accuracy_band,
    count(*)::bigint,
    round(avg(abs(l.rom_deviation_deg)), 2),
    round(avg(abs(l.set_speed_cpm - l.measured_speed_cpm)), 2),
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.cpm_rom_qc_r3434 l
  group by 1
  order by min(abs(l.rom_deviation_deg));
end;
$$;

revoke execute on function public.founder_r3434_rom_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3434_rom_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3434_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  joint text,
  calibration_date date,
  qc_verdict text,
  set_rom_deg numeric,
  measured_rom_deg numeric,
  rom_deviation_deg numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.joint, l.calibration_date,
    l.qc_verdict, l.set_rom_deg, l.measured_rom_deg, l.rom_deviation_deg, l.notes
  from public.cpm_rom_qc_r3434 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.emergency_stop_ok = false
     or abs(l.rom_deviation_deg) > 5
  order by abs(l.rom_deviation_deg) desc, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3434_high_risk_queue() from public, anon;
grant execute on function public.founder_r3434_high_risk_queue() to authenticated;
