-- Round 3451: Customer Hospital Flow Cytometer Fluorescence-Calibration QC Audit
-- Flow cytometer QC — measured parameter × excitation laser × reference vs measured × deviation % × within-tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: flow_cytometer_qc_r3451 — per-parameter flow cytometer calibration QC checks
-- =============================================================================
create table if not exists public.flow_cytometer_qc_r3451 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'fsc_cv_pct','ssc_cv_pct','fl1_mfi','fl2_mfi','laser_delay','bead_recovery_pct'
  )),
  reference_value numeric(12,3) not null,
  measured_value numeric(12,3) not null,
  deviation_pct numeric(8,2) not null,
  laser text not null check (laser in (
    'blue_488','red_640','violet_405','uv_355'
  )),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.flow_cytometer_qc_r3451 enable row level security;

create index if not exists idx_flow_cytometer_qc_r3451_org on public.flow_cytometer_qc_r3451(organization_id);
create index if not exists idx_flow_cytometer_qc_r3451_date on public.flow_cytometer_qc_r3451(calibration_date);
create index if not exists idx_flow_cytometer_qc_r3451_verdict on public.flow_cytometer_qc_r3451(qc_verdict);

-- =============================================================================
-- TABLE 2: flow_cytometer_qc_capa_actions_r3451 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.flow_cytometer_qc_capa_actions_r3451 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.flow_cytometer_qc_r3451(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'fluorescence_cv_out_of_tolerance','scatter_cv_out_of_tolerance','mfi_drift',
    'laser_delay_misalignment','bead_recovery_low','calibration_overdue',
    'laser_power_degraded','optical_filter_contamination'
  )),
  root_cause text not null check (root_cause in (
    'laser_power_drift','pmt_voltage_drift','optical_alignment_error','fluidics_instability',
    'bead_lot_expired','filter_degraded','operator_setup_error','software_config_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'realign_laser','recalibrate_pmt_voltage','replace_bead_lot','clean_fluidics',
    'replace_optical_filter','update_software_config','retrain_lab_staff',
    'schedule_oem_service','remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.flow_cytometer_qc_capa_actions_r3451 enable row level security;

create index if not exists idx_flow_cytometer_capa_r3451_log on public.flow_cytometer_qc_capa_actions_r3451(qc_log_id);
create index if not exists idx_flow_cytometer_capa_r3451_status on public.flow_cytometer_qc_capa_actions_r3451(capa_status);

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
  insert into public.flow_cytometer_qc_r3451 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, laser,
    within_tolerance, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.laser,
    q.wtol, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','FC-APL-01','BD FACSCanto II','fsc_cv_pct',
     2.0,1.8,-10.0,'blue_488',true,'2026-07-05','pass','FSC %CV within spec at 1.8'),
    ('Apollo Chennai','FC-APL-02','BD FACSCanto II','fl1_mfi',
     5000,4950,-1.0,'blue_488',true,'2026-07-05','pass','FITC FL1 median fluorescence on target'),
    ('Fortis Gurgaon','FC-FRT-11','BD FACSLyric','ssc_cv_pct',
     2.5,3.4,36.0,'blue_488',false,'2026-07-04','conditional_pass','SSC %CV elevated — fluidics clean advised'),
    ('Fortis Gurgaon','FC-FRT-12','BD FACSLyric','fl2_mfi',
     8000,6400,-20.0,'blue_488',false,'2026-07-04','fail','PE FL2 MFI down 20% — PMT/laser power drift'),
    ('Manipal Bengaluru','FC-MNP-21','Beckman Navios EX','laser_delay',
     40.0,44.5,11.25,'red_640',false,'2026-07-03','fail','Red 640 laser delay out of alignment'),
    ('Manipal Bengaluru','FC-MNP-22','Beckman Navios EX','bead_recovery_pct',
     95.0,96.2,1.26,'red_640',true,'2026-07-03','pass','Rainbow bead recovery nominal'),
    ('AIIMS Delhi','FC-AIM-31','Cytek Aurora','fl1_mfi',
     5000,5100,2.0,'violet_405',true,'2026-07-02','pass','Violet 405 FL1 MFI on target'),
    ('AIIMS Delhi','FC-AIM-32','Cytek Aurora','fsc_cv_pct',
     2.0,2.2,10.0,'blue_488',true,'2026-07-02','conditional_pass','FSC %CV mildly high but within action limit'),
    ('CMC Vellore','FC-CMC-41','BD FACSCelesta','bead_recovery_pct',
     95.0,88.0,-7.37,'blue_488',false,'2026-07-01','conditional_pass','Bead recovery below 90 — recheck bead lot'),
    ('CMC Vellore','FC-CMC-42','BD FACSCelesta','fl2_mfi',
     8000,7900,-1.25,'blue_488',true,'2026-07-01','pass','PE FL2 MFI nominal'),
    ('KIMS Hyderabad','FC-KIM-51','BD FACSCanto II','ssc_cv_pct',
     2.5,2.4,-4.0,'blue_488',true,'2026-06-30','pass','SSC %CV within spec'),
    ('KIMS Hyderabad','FC-KIM-52','BD FACSCanto II','laser_delay',
     40.0,40.3,0.75,'blue_488',true,'2026-06-30','pass','Blue 488 laser delay nominal'),
    ('Tata Memorial Mumbai','FC-TMH-61','Cytek Aurora','fl1_mfi',
     5000,3800,-24.0,'uv_355',false,'2026-06-29','fail','UV 355 FL1 MFI collapsed — laser power degraded'),
    ('Tata Memorial Mumbai','FC-TMH-62','Cytek Aurora','fsc_cv_pct',
     2.0,5.1,155.0,'uv_355',false,'2026-06-29','fail','FSC %CV grossly high — fluidics instability'),
    ('Yashoda Hyderabad','FC-YSH-71','Beckman Navios EX','fl2_mfi',
     8000,8050,0.63,'violet_405',true,'2026-06-28','pass','Violet 405 FL2 MFI on target'),
    ('Kokilaben Mumbai','FC-KKB-81','BD FACSLyric','bead_recovery_pct',
     95.0,79.0,-16.84,'red_640',false,'2026-06-27','fail','Red 640 bead recovery poor — optical filter contamination')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, laser, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.flow_cytometer_qc_capa_actions_r3451 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FC-FRT-12','mfi_drift','pmt_voltage_drift','recalibrate_pmt_voltage','in_progress','iso_15189_deviation','2026-07-08',null,12000.00,'PE FL2 MFI drop — PMT voltage re-cal in progress'),
    ('FC-MNP-21','laser_delay_misalignment','optical_alignment_error','realign_laser','open','internal_only','2026-07-07',null,9000.00,'Red 640 laser delay re-alignment scheduled'),
    ('FC-TMH-61','mfi_drift','laser_power_drift','schedule_oem_service','escalated','patient_safety_alert','2026-07-06',null,55000.00,'UV 355 laser power degraded — OEM service escalated'),
    ('FC-TMH-62','scatter_cv_out_of_tolerance','fluidics_instability','clean_fluidics','verification_pending','nabl_finding','2026-07-05',null,7000.00,'Fluidics flush done — verify FSC %CV next run'),
    ('FC-KKB-81','bead_recovery_low','filter_degraded','replace_optical_filter','closed','cdsco_notifiable','2026-07-02','2026-06-30',15000.00,'Optical filter replaced; bead recovery restored to 96%'),
    ('FC-FRT-11','scatter_cv_out_of_tolerance','fluidics_instability','clean_fluidics','open','internal_only','2026-07-08',null,4000.00,'SSC %CV elevated — fluidics clean queued'),
    ('FC-CMC-41','bead_recovery_low','bead_lot_expired','replace_bead_lot','overdue','internal_only','2026-07-03',null,3500.00,'Bead lot past expiry — replacement lot overdue from vendor'),
    ('FC-AIM-32','scatter_cv_out_of_tolerance','operator_setup_error','retrain_lab_staff','closed','none','2026-07-04','2026-07-03',0.00,'Operator gain setup corrected; lab staff retrained')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.flow_cytometer_qc_r3451 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3451_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.flow_cytometer_qc_r3451)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.flow_cytometer_qc_r3451 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3451_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3451_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3451_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_abs_deviation_pct numeric,
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
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.flow_cytometer_qc_r3451 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3451_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3451_device_model_scorecard() to authenticated;

-- 3) Laser × verdict matrix
create or replace function public.founder_r3451_laser_verdict_matrix()
returns table(laser text, qc_verdict text, checks bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.laser, l.qc_verdict, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2)
  from public.flow_cytometer_qc_r3451 l
  group by l.laser, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3451_laser_verdict_matrix() from public, anon;
grant execute on function public.founder_r3451_laser_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3451_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_abs_deviation_pct numeric)
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.flow_cytometer_qc_r3451 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3451_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3451_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3451_capa_status_board()
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
  from public.flow_cytometer_qc_capa_actions_r3451 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3451_capa_status_board() from public, anon;
grant execute on function public.founder_r3451_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3451_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.flow_cytometer_qc_capa_actions_r3451)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.flow_cytometer_qc_capa_actions_r3451 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3451_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3451_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by measured parameter)
create or replace function public.founder_r3451_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, failed bigint, avg_abs_deviation_pct numeric, max_abs_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.flow_cytometer_qc_r3451 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3451_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3451_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3451_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  laser text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  tolerance_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.laser,
    l.calibration_date, l.qc_verdict, l.deviation_pct,
    case when l.within_tolerance then 'within' else 'out_of_tolerance' end,
    l.notes
  from public.flow_cytometer_qc_r3451 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3451_high_risk_queue() from public, anon;
grant execute on function public.founder_r3451_high_risk_queue() to authenticated;
