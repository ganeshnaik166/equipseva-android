-- Round 3406: Customer Hospital Coronary IVUS / FFR / Rotablator Cath-Lab QC Audit
-- Coronary-physiology & intravascular-imaging QA — device type × cath-lab × pullback accuracy × pressure cal % × transducer/catheter × rotational speed × aiming display × hemodynamics connectivity × disposable stock × leakage µA × CAPA

-- =============================================================================
-- TABLE 1: coronary_ivus_ffr_qc_r3406 — per-device cath-lab imaging/physiology QC checks
-- =============================================================================
create table if not exists public.coronary_ivus_ffr_qc_r3406 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'ivus_console','oct_coronary','ffr_ifr_console','rotablator_console','shockwave_ivl'
  )),
  cath_lab text not null check (cath_lab in (
    'cath_lab_1','cath_lab_2','cath_lab_3','hybrid_or','ep_lab'
  )),
  check_date date not null,
  image_pullback_accuracy_ok boolean not null,
  pressure_calibration_error_pct numeric(5,2),
  transducer_catheter_ok text not null check (transducer_catheter_ok in (
    'ok','degraded','fail','not_applicable'
  )),
  rotational_speed_accuracy_ok text not null check (rotational_speed_accuracy_ok in (
    'ok','drift','fail','not_applicable'
  )),
  aiming_display_ok boolean not null,
  connectivity_hemodynamics_ok boolean not null,
  disposable_stock text not null check (disposable_stock in (
    'adequate','low','out_of_stock'
  )),
  electrical_safety_leakage_ua numeric(6,2),
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.coronary_ivus_ffr_qc_r3406 enable row level security;

create index if not exists idx_coronary_ivus_ffr_qc_r3406_org on public.coronary_ivus_ffr_qc_r3406(organization_id);
create index if not exists idx_coronary_ivus_ffr_qc_r3406_date on public.coronary_ivus_ffr_qc_r3406(check_date);
create index if not exists idx_coronary_ivus_ffr_qc_r3406_verdict on public.coronary_ivus_ffr_qc_r3406(qc_verdict);

-- =============================================================================
-- TABLE 2: coronary_ivus_ffr_qc_capa_actions_r3406 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.coronary_ivus_ffr_qc_capa_actions_r3406 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.coronary_ivus_ffr_qc_r3406(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_pullback_accuracy_out_of_tolerance','pressure_calibration_out_of_tolerance',
    'transducer_catheter_degraded','rotational_speed_out_of_tolerance','aiming_display_fault',
    'connectivity_hemodynamics_failure','disposable_stock_shortage','electrical_safety_leakage_high',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_wire_degraded','pressure_sensor_drift','motor_drive_wear','optical_fiber_degraded',
    'display_module_fault','network_interface_error','consumable_supply_delay','insulation_leakage',
    'software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_pressure_wire','replace_imaging_catheter','replace_rotational_burr_drive',
    'replace_optical_fiber','repair_display_module','reconfigure_network_interface',
    'replenish_disposable_stock','repair_electrical_insulation','update_software_config',
    'retrain_cathlab_staff','remove_from_service','schedule_oem_service','none_required'
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

alter table public.coronary_ivus_ffr_qc_capa_actions_r3406 enable row level security;

create index if not exists idx_coronary_ivus_ffr_capa_r3406_log on public.coronary_ivus_ffr_qc_capa_actions_r3406(qc_log_id);
create index if not exists idx_coronary_ivus_ffr_capa_r3406_status on public.coronary_ivus_ffr_qc_capa_actions_r3406(capa_status);

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
  insert into public.coronary_ivus_ffr_qc_r3406 (
    organization_id, hospital_name, device_code, device_type, cath_lab, check_date,
    image_pullback_accuracy_ok, pressure_calibration_error_pct, transducer_catheter_ok,
    rotational_speed_accuracy_ok, aiming_display_ok, connectivity_hemodynamics_ok,
    disposable_stock, electrical_safety_leakage_ua, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.lab, q.cdate::date,
    q.pull, q.perr, q.trans,
    q.rot, q.aim, q.conn,
    q.stock, q.leak, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','IVUS-APL-01','ivus_console','cath_lab_1','2026-07-05',
     true,null,'ok','not_applicable',true,true,'adequate',8.4,true,'pass','IVUS console pullback accuracy within tolerance'),
    ('Apollo Chennai','OCT-APL-02','oct_coronary','cath_lab_2','2026-07-05',
     true,null,'ok','not_applicable',true,true,'adequate',9.1,true,'pass','OCT coronary optical pullback QC clean'),
    ('Fortis Gurgaon','FFR-FRT-11','ffr_ifr_console','cath_lab_1','2026-07-04',
     true,1.8,'ok','not_applicable',true,true,'low',7.6,true,'conditional_pass','FFR pressure wire cal 1.8 pct and disposable stock low'),
    ('Fortis Gurgaon','ROTA-FRT-12','rotablator_console','cath_lab_2','2026-07-04',
     true,null,'not_applicable','drift',true,true,'adequate',12.2,true,'conditional_pass','Rotablator burr speed drift flagged on high-rpm test'),
    ('Manipal Bengaluru','IVUS-MNP-21','ivus_console','cath_lab_3','2026-07-03',
     false,null,'degraded','not_applicable',true,false,'adequate',15.5,true,'fail','IVUS pullback accuracy failed and hemodynamics link down'),
    ('Manipal Bengaluru','SIVL-MNP-22','shockwave_ivl','hybrid_or','2026-07-03',
     true,null,'ok','not_applicable',true,true,'adequate',6.9,true,'pass','Shockwave IVL generator QC nominal'),
    ('AIIMS Delhi','FFR-AIM-31','ffr_ifr_console','cath_lab_1','2026-07-02',
     true,2.9,'ok','not_applicable',true,true,'adequate',10.4,true,'conditional_pass','FFR/iFR pressure cal error 2.9 pct near upper limit'),
    ('AIIMS Delhi','ROTA-AIM-32','rotablator_console','cath_lab_2','2026-07-02',
     true,null,'not_applicable','fail',true,false,'low',22.8,false,'fail','Rotablator speed accuracy fail, connectivity down, leakage high, cal overdue'),
    ('CMC Vellore','OCT-CMC-41','oct_coronary','cath_lab_1','2026-07-01',
     true,null,'ok','not_applicable',true,true,'adequate',7.2,true,'pass','OCT coronary console QC pass'),
    ('CMC Vellore','IVUS-CMC-42','ivus_console','cath_lab_2','2026-07-01',
     true,null,'degraded','not_applicable',true,true,'low',9.8,false,'conditional_pass','IVUS imaging catheter degraded and calibration overdue — replacement ordered'),
    ('KIMS Hyderabad','FFR-KIM-51','ffr_ifr_console','cath_lab_1','2026-06-30',
     true,0.9,'ok','not_applicable',true,true,'adequate',8.0,true,'pass','FFR pressure wire cal 0.9 pct — pass post-AMC'),
    ('KIMS Hyderabad','SIVL-KIM-52','shockwave_ivl','ep_lab','2026-06-30',
     true,null,'ok','not_applicable',true,true,'out_of_stock',6.4,true,'conditional_pass','Shockwave IVL emitter QC ok but disposable stock out'),
    ('Yashoda Hyderabad','ROTA-YSH-61','rotablator_console','cath_lab_3','2026-06-29',
     true,null,'not_applicable','ok',true,true,'adequate',11.1,true,'pass','Rotablator console QC nominal'),
    ('Kokilaben Mumbai','IVUS-KKB-71','ivus_console','hybrid_or','2026-06-29',
     false,null,'fail','not_applicable',false,false,'out_of_stock',28.6,false,'removed_from_service','IVUS console multiple failures with high leakage — removed from service')
  ) as q(hosp, dcode, dtype, lab, cdate, pull, perr, trans, rot, aim, conn, stock, leak, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.coronary_ivus_ffr_qc_capa_actions_r3406 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FFR-FRT-11','pressure_calibration_out_of_tolerance','pressure_sensor_drift','recalibrate_pressure_wire','in_progress','iso_13485_deviation','2026-07-08',null,14000.00,'Pressure wire recalibrated; verification pending'),
    ('ROTA-AIM-32','rotational_speed_out_of_tolerance','motor_drive_wear','replace_rotational_burr_drive','escalated','patient_safety_alert','2026-07-06',null,68000.00,'Rotablator drive fail with high leakage — escalated to OEM'),
    ('IVUS-MNP-21','image_pullback_accuracy_out_of_tolerance','transducer_wire_degraded','replace_imaging_catheter','open','nabh_finding','2026-07-07',null,42000.00,'IVUS imaging catheter degraded — replacement kit ordered'),
    ('IVUS-KKB-71','electrical_safety_leakage_high','insulation_leakage','remove_from_service','closed','cdsco_notifiable','2026-07-03','2026-06-30',52000.00,'High leakage console removed; replacement validated'),
    ('IVUS-CMC-42','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-07-01',null,9500.00,'IVUS calibration past due — OEM service scheduling delayed'),
    ('SIVL-KIM-52','disposable_stock_shortage','consumable_supply_delay','replenish_disposable_stock','open','none','2026-07-05',null,0.00,'Shockwave IVL disposables out of stock — reorder placed'),
    ('ROTA-FRT-12','rotational_speed_out_of_tolerance','motor_drive_wear','schedule_oem_service','verification_pending','internal_only','2026-07-08',null,18000.00,'Rotablator drift — OEM speed calibration scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.coronary_ivus_ffr_qc_r3406 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3406_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coronary_ivus_ffr_qc_r3406)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.coronary_ivus_ffr_qc_r3406 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3406_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3406_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3406_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  imaging_fail bigint,
  leakage_high bigint,
  calibration_overdue bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.image_pullback_accuracy_ok = false)::bigint,
    count(*) filter (where l.electrical_safety_leakage_ua > 20)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.coronary_ivus_ffr_qc_r3406 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3406_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3406_hospital_scorecard() to authenticated;

-- 3) Device-type × cath-lab matrix
create or replace function public.founder_r3406_device_type_lab_matrix()
returns table(device_type text, cath_lab text, checks bigint, passed bigint, failed bigint, avg_pressure_cal_error_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.cath_lab, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    round(avg(l.pressure_calibration_error_pct), 2)
  from public.coronary_ivus_ffr_qc_r3406 l
  group by l.device_type, l.cath_lab
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3406_device_type_lab_matrix() from public, anon;
grant execute on function public.founder_r3406_device_type_lab_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3406_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, imaging_fail bigint, leakage_high bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.image_pullback_accuracy_ok = false)::bigint,
    count(*) filter (where l.electrical_safety_leakage_ua > 20)::bigint
  from public.coronary_ivus_ffr_qc_r3406 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3406_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3406_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3406_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.coronary_ivus_ffr_qc_capa_actions_r3406 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3406_capa_status_board() from public, anon;
grant execute on function public.founder_r3406_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3406_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.coronary_ivus_ffr_qc_capa_actions_r3406)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.coronary_ivus_ffr_qc_capa_actions_r3406 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3406_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3406_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3406_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.coronary_ivus_ffr_qc_capa_actions_r3406 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3406_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3406_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3406_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  cath_lab text,
  check_date date,
  qc_verdict text,
  transducer_catheter_ok text,
  rotational_speed_accuracy_ok text,
  disposable_stock text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.cath_lab, l.check_date,
    l.qc_verdict, l.transducer_catheter_ok, l.rotational_speed_accuracy_ok, l.disposable_stock, l.notes
  from public.coronary_ivus_ffr_qc_r3406 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.image_pullback_accuracy_ok = false
     or l.aiming_display_ok = false
     or l.connectivity_hemodynamics_ok = false
     or l.transducer_catheter_ok in ('degraded','fail')
     or l.rotational_speed_accuracy_ok in ('drift','fail')
     or l.disposable_stock in ('low','out_of_stock')
     or l.electrical_safety_leakage_ua > 20
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3406_high_risk_queue() from public, anon;
grant execute on function public.founder_r3406_high_risk_queue() to authenticated;
