-- Round 3430: Customer Hospital Nerve-Stimulator / Train-of-Four (TOF) Neuromuscular-Monitor QC Audit
-- Peripheral-nerve-stimulator + TOF neuromuscular monitor QC — stim mode × output current × pulse width ×
-- TOF ratio × electrode impedance × output tolerance × battery × calibration × verdict × CAPA closure

-- =============================================================================
-- TABLE 1: nerve_stim_tof_qc_r3430 — per-device NMT/TOF QC checks
-- =============================================================================
create table if not exists public.nerve_stim_tof_qc_r3430 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  stim_mode text not null check (stim_mode in (
    'single_twitch','train_of_four','tetanic','double_burst','post_tetanic_count'
  )),
  set_current_ma numeric(6,2),
  measured_current_ma numeric(6,2),
  pulse_width_us int,
  tof_ratio_pct numeric(5,2),
  electrode_impedance_kohm numeric(6,2),
  output_within_tol boolean not null,
  battery_ok boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nerve_stim_tof_qc_r3430 enable row level security;

create index if not exists idx_nerve_stim_tof_qc_r3430_org on public.nerve_stim_tof_qc_r3430(organization_id);
create index if not exists idx_nerve_stim_tof_qc_r3430_date on public.nerve_stim_tof_qc_r3430(calibration_date);
create index if not exists idx_nerve_stim_tof_qc_r3430_verdict on public.nerve_stim_tof_qc_r3430(qc_verdict);

-- =============================================================================
-- TABLE 2: nerve_stim_tof_qc_capa_actions_r3430 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.nerve_stim_tof_qc_capa_actions_r3430 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.nerve_stim_tof_qc_r3430(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'output_current_out_of_tolerance','tof_ratio_inaccurate','pulse_width_deviation',
    'electrode_impedance_high','battery_failure','calibration_overdue',
    'stim_mode_malfunction','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'output_stage_drift','battery_end_of_life','electrode_lead_damaged','connector_corrosion',
    'firmware_config_error','operator_setup_error','sensor_degraded',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_output','replace_battery','replace_electrode_leads','clean_replace_connector',
    'update_firmware','retrain_anesthesia_staff','remove_from_service',
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

alter table public.nerve_stim_tof_qc_capa_actions_r3430 enable row level security;

create index if not exists idx_nerve_stim_tof_capa_r3430_log on public.nerve_stim_tof_qc_capa_actions_r3430(qc_log_id);
create index if not exists idx_nerve_stim_tof_capa_r3430_status on public.nerve_stim_tof_qc_capa_actions_r3430(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3430_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nerve_stim_tof_qc_r3430)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nerve_stim_tof_qc_r3430 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3430_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3430_qc_verdict_rollup() to authenticated;

-- 2) Stim-mode QC scorecard
create or replace function public.founder_r3430_stim_mode_scorecard()
returns table(
  stim_mode text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tol bigint,
  battery_fail bigint,
  avg_tof_ratio_pct numeric,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.stim_mode,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.output_within_tol = false)::bigint,
    count(*) filter (where l.battery_ok = false)::bigint,
    round(avg(l.tof_ratio_pct), 1),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.nerve_stim_tof_qc_r3430 l
  group by l.stim_mode
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3430_stim_mode_scorecard() from public, anon;
grant execute on function public.founder_r3430_stim_mode_scorecard() to authenticated;

-- 3) Stim-mode × verdict matrix
create or replace function public.founder_r3430_stim_mode_verdict_matrix()
returns table(stim_mode text, qc_verdict text, checks bigint, avg_tof_ratio_pct numeric, avg_current_error_ma numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.stim_mode, l.qc_verdict, count(*)::bigint,
    round(avg(l.tof_ratio_pct), 1),
    round(avg(abs(l.measured_current_ma - l.set_current_ma)), 2)
  from public.nerve_stim_tof_qc_r3430 l
  group by l.stim_mode, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3430_stim_mode_verdict_matrix() from public, anon;
grant execute on function public.founder_r3430_stim_mode_verdict_matrix() to authenticated;

-- 4) Monthly calibration trend
create or replace function public.founder_r3430_monthly_calibration_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tol bigint, battery_fail bigint)
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
    count(*) filter (where l.output_within_tol = false)::bigint,
    count(*) filter (where l.battery_ok = false)::bigint
  from public.nerve_stim_tof_qc_r3430 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3430_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3430_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3430_capa_status_board()
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
  from public.nerve_stim_tof_qc_capa_actions_r3430 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3430_capa_status_board() from public, anon;
grant execute on function public.founder_r3430_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3430_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nerve_stim_tof_qc_capa_actions_r3430)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nerve_stim_tof_qc_capa_actions_r3430 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3430_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3430_root_cause_pareto() to authenticated;

-- 7) Output-accuracy impact digest (per device model)
create or replace function public.founder_r3430_output_accuracy_impact_digest()
returns table(
  device_model text,
  checks bigint,
  avg_set_current_ma numeric,
  avg_measured_current_ma numeric,
  avg_abs_current_error_ma numeric,
  worst_current_error_ma numeric,
  out_of_tol bigint
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
    round(avg(l.set_current_ma), 2),
    round(avg(l.measured_current_ma), 2),
    round(avg(abs(l.measured_current_ma - l.set_current_ma)), 2),
    round(max(abs(l.measured_current_ma - l.set_current_ma)), 2),
    count(*) filter (where l.output_within_tol = false)::bigint
  from public.nerve_stim_tof_qc_r3430 l
  group by l.device_model
  order by avg(abs(l.measured_current_ma - l.set_current_ma)) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3430_output_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3430_output_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed individual checks)
create or replace function public.founder_r3430_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  stim_mode text,
  calibration_date date,
  qc_verdict text,
  set_current_ma numeric,
  measured_current_ma numeric,
  tof_ratio_pct numeric,
  electrode_impedance_kohm numeric,
  output_within_tol boolean,
  battery_ok boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.stim_mode, l.calibration_date,
    l.qc_verdict, l.set_current_ma, l.measured_current_ma, l.tof_ratio_pct,
    l.electrode_impedance_kohm, l.output_within_tol, l.battery_ok, l.notes
  from public.nerve_stim_tof_qc_r3430 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.output_within_tol = false
     or l.battery_ok = false
     or l.electrode_impedance_kohm > 6.0
     or abs(l.measured_current_ma - l.set_current_ma) > 3.0
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3430_high_risk_queue() from public, anon;
grant execute on function public.founder_r3430_high_risk_queue() to authenticated;

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

  -- 15 QC check rows
  insert into public.nerve_stim_tof_qc_r3430 (
    organization_id, hospital_name, device_code, device_model, stim_mode,
    set_current_ma, measured_current_ma, pulse_width_us, tof_ratio_pct, electrode_impedance_kohm,
    output_within_tol, battery_ok, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.smode,
    q.setc, q.measc, q.pw, q.tof, q.imp,
    q.otol, q.batt, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','TOF-APL-01','GE Carescape NMT','train_of_four',
     50.0,49.6,200,92.0,3.2,true,true,'2026-07-03','pass','TOF module QC nominal, ratio 92%'),
    ('Apollo Chennai','NST-APL-02','Fisher Paykel Innervator NS252','single_twitch',
     60.0,59.2,200,null,4.1,true,true,'2026-07-03','pass','Single-twitch supramaximal output within tolerance'),
    ('Fortis Gurgaon','TOF-FRT-11','Philips IntelliVue NMT','double_burst',
     50.0,47.0,200,88.0,6.8,true,true,'2026-07-02','conditional_pass','Electrode impedance high 6.8 kOhm — reduced skin prep, recheck'),
    ('Fortis Gurgaon','NST-FRT-12','GE Carescape NMT','tetanic',
     50.0,42.0,100,null,5.4,false,true,'2026-07-02','fail','Tetanic output 8 mA low, out of tolerance'),
    ('Manipal Bengaluru','TOF-MNP-21','Draeger TOF-Watch SX','train_of_four',
     50.0,49.8,300,95.0,2.9,true,true,'2026-07-01','pass','TOF-Watch acceleromyography QC pass'),
    ('Manipal Bengaluru','NST-MNP-22','Fisher Paykel Innervator NS252','post_tetanic_count',
     60.0,58.5,200,null,3.6,true,true,'2026-07-01','pass','PTC mode QC nominal'),
    ('AIIMS Delhi','TOF-AIM-31','GE Carescape NMT','train_of_four',
     50.0,45.5,200,78.0,4.9,true,false,'2026-06-29','conditional_pass','Battery low warning, TOF ratio drift — battery replacement due'),
    ('AIIMS Delhi','NST-AIM-32','Philips IntelliVue NMT','double_burst',
     50.0,36.0,200,null,9.2,false,true,'2026-06-29','fail','Impedance 9.2 kOhm and output 14 mA low — leads suspect'),
    ('CMC Vellore','TOF-CMC-41','Draeger TOF-Watch SX','train_of_four',
     50.0,49.9,300,94.0,2.7,true,true,'2026-06-28','pass','TOF QC pass post-AMC'),
    ('CMC Vellore','NST-CMC-42','Fisher Paykel Innervator NS252','single_twitch',
     60.0,58.0,200,null,3.9,true,true,'2026-06-28','conditional_pass','Calibration overdue by 12 days — recalibration scheduled'),
    ('KIMS Hyderabad','TOF-KIM-51','GE Carescape NMT','tetanic',
     50.0,49.4,100,null,3.1,true,true,'2026-06-27','pass','Tetanic 50 Hz output within tolerance'),
    ('KIMS Hyderabad','NST-KIM-52','Philips IntelliVue NMT','train_of_four',
     50.0,44.0,200,71.0,7.5,true,true,'2026-06-27','conditional_pass','TOF ratio low, impedance high — electrode set worn'),
    ('Yashoda Hyderabad','TOF-YSH-61','Draeger TOF-Watch SX','post_tetanic_count',
     60.0,59.0,200,null,2.8,true,true,'2026-06-26','pass','PTC and TOF cross-check nominal'),
    ('Kokilaben Mumbai','TOF-KKB-71','GE Carescape NMT','train_of_four',
     50.0,30.0,200,55.0,11.0,false,false,'2026-06-26','fail','Multiple failures: output 20 mA low, impedance 11 kOhm, battery fault — removed'),
    ('Kokilaben Mumbai','NST-KKB-72','Fisher Paykel Innervator NS252','double_burst',
     50.0,48.5,200,90.0,4.3,true,true,'2026-06-25','pass','DBS mode QC pass')
  ) as q(hosp, dcode, dmodel, smode, setc, measc, pw, tof, imp, otol, batt, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.nerve_stim_tof_qc_capa_actions_r3430 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NST-FRT-12','output_current_out_of_tolerance','output_stage_drift','recalibrate_output','in_progress','iso_13485_deviation','2026-07-06',null,12000.00,'Output stage recalibrated — verify tetanic amplitude'),
    ('NST-AIM-32','electrode_impedance_high','electrode_lead_damaged','replace_electrode_leads','open','nabh_finding','2026-07-05',null,3500.00,'Impedance 9.2 kOhm — lead set replacement ordered'),
    ('TOF-AIM-31','battery_failure','battery_end_of_life','replace_battery','verification_pending','internal_only','2026-07-04',null,2800.00,'Battery replaced — verify TOF ratio stability'),
    ('TOF-KKB-71','output_current_out_of_tolerance','output_stage_drift','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-28',58000.00,'Multi-fault unit removed; replacement stimulator validated'),
    ('TOF-FRT-11','electrode_impedance_high','connector_corrosion','clean_replace_connector','verification_pending','internal_only','2026-07-05',null,1500.00,'Connector cleaned — recheck double-burst impedance'),
    ('NST-CMC-42','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,9000.00,'Recalibration past target — OEM slot delayed'),
    ('NST-KIM-52','tof_ratio_inaccurate','sensor_degraded','replace_electrode_leads','open','none','2026-07-07',null,3500.00,'TOF ratio low — worn electrode set flagged'),
    ('TOF-KKB-71','battery_failure','battery_end_of_life','replace_battery','closed','patient_safety_alert','2026-07-01','2026-06-27',2800.00,'Battery fault on removed unit — logged for RCA')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.nerve_stim_tof_qc_r3430 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;
