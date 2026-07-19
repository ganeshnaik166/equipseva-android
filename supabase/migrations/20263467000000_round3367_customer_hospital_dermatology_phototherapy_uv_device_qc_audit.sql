-- Round 3367: Customer Hospital Dermatology Phototherapy & UV-Treatment Device QC Audit
-- Derm phototherapy QA — device type × department × irradiance accuracy × dosimetry cal × lamp life × timer accuracy × eye-shield/PPE × uniformity × e-stop × CAPA

-- =============================================================================
-- TABLE 1: derm_phototherapy_r3367 — per-device phototherapy/UV QC checks
-- =============================================================================
create table if not exists public.derm_phototherapy_r3367 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'nb_uvb_cabinet','puva_unit','excimer_308nm','targeted_uv_handpiece','uva1_device'
  )),
  department text not null,
  check_date date not null,
  uv_irradiance_error_pct numeric(5,2),
  dosimetry_calibration_ok boolean not null,
  lamp_hours int not null,
  lamp_replacement_due boolean not null,
  timer_accuracy_ok boolean not null,
  patient_eye_shield_available boolean not null,
  operator_ppe_available boolean not null,
  uniformity_across_cabinet_ok text not null check (uniformity_across_cabinet_ok in (
    'ok','uneven','fail','not_applicable'
  )),
  emergency_stop_ok boolean not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.derm_phototherapy_r3367 enable row level security;

create index if not exists idx_derm_phototherapy_r3367_org on public.derm_phototherapy_r3367(organization_id);
create index if not exists idx_derm_phototherapy_r3367_date on public.derm_phototherapy_r3367(check_date);
create index if not exists idx_derm_phototherapy_r3367_verdict on public.derm_phototherapy_r3367(qc_verdict);

-- =============================================================================
-- TABLE 2: derm_phototherapy_capa_actions_r3367 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.derm_phototherapy_capa_actions_r3367 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.derm_phototherapy_r3367(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'irradiance_out_of_tolerance','dosimetry_calibration_lapsed','lamp_end_of_life','timer_inaccuracy',
    'uniformity_failure','eye_shield_missing','operator_ppe_missing','emergency_stop_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lamp_aging','ballast_degradation','dosimeter_out_of_calibration','timer_circuit_drift',
    'reflector_degradation','consumable_stockout','interlock_switch_fault','operator_training_gap',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_uv_lamps','recalibrate_dosimeter','adjust_replace_timer','clean_replace_reflector',
    'restock_eye_shields','issue_uv_ppe','repair_emergency_stop','retrain_phototherapy_staff',
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

alter table public.derm_phototherapy_capa_actions_r3367 enable row level security;

create index if not exists idx_derm_photo_capa_r3367_log on public.derm_phototherapy_capa_actions_r3367(qc_log_id);
create index if not exists idx_derm_photo_capa_r3367_status on public.derm_phototherapy_capa_actions_r3367(capa_status);

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

  -- 14 phototherapy/UV QC rows
  insert into public.derm_phototherapy_r3367 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    uv_irradiance_error_pct, dosimetry_calibration_ok, lamp_hours, lamp_replacement_due,
    timer_accuracy_ok, patient_eye_shield_available, operator_ppe_available,
    uniformity_across_cabinet_ok, emergency_stop_ok, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.dtype, q.dept, q.chk::date,
    q.irr::numeric, q.dcal, q.lhrs::int, q.lrepl,
    q.tacc, q.eyesh, q.ppe,
    q.unif, q.estop, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','PHO-APL-01','nb_uvb_cabinet','Dermatology','2026-07-03',
     2.1,true,820,false,true,true,true,'ok',true,true,'pass','Quarterly QC — irradiance within tolerance'),
    ('Apollo Chennai','PHO-APL-02','puva_unit','Phototherapy Unit','2026-07-03',
     6.4,true,1450,false,true,true,true,'ok',true,true,'conditional_pass','Irradiance error 6.4% above 5% action limit — recheck booked'),
    ('Fortis Gurgaon','PHO-FRT-11','excimer_308nm','Dermatology','2026-07-02',
     1.2,true,300,false,true,true,true,'not_applicable',true,true,'pass','Excimer 308nm targeted — spot dosimetry nominal'),
    ('Fortis Gurgaon','PHO-FRT-12','nb_uvb_cabinet','Phototherapy Unit','2026-07-02',
     12.5,false,2100,true,true,true,true,'uneven',true,false,'fail','Irradiance 12.5% low, dosimeter cal expired, lamps past life — pulled from schedule'),
    ('Manipal Bengaluru','PHO-MNP-21','puva_unit','Skin OPD','2026-07-01',
     3.0,true,980,false,true,true,true,'ok',true,true,'pass','PUVA unit — UVA output within tolerance'),
    ('Manipal Bengaluru','PHO-MNP-22','targeted_uv_handpiece','Dermatology','2026-07-01',
     4.2,true,540,false,false,true,true,'not_applicable',true,true,'conditional_pass','Timer accuracy off 8% on 30s dose — service booked'),
    ('AIIMS Delhi','PHO-AIM-31','nb_uvb_cabinet','Dermatology','2026-06-30',
     2.8,true,1180,false,true,false,true,'ok',true,true,'conditional_pass','Patient eye-shields missing — supplied same day, revisit to confirm'),
    ('AIIMS Delhi','PHO-AIM-32','uva1_device','Phototherapy Unit','2026-06-30',
     5.5,true,1620,false,true,true,true,'ok',true,true,'conditional_pass','UVA1 high-dose — irradiance error 5.5% marginal, trending watch'),
    ('CMC Vellore','PHO-CMC-41','nb_uvb_cabinet','Skin OPD','2026-06-29',
     1.5,true,640,false,true,true,true,'ok',true,true,'pass','Annual QC clean'),
    ('CMC Vellore','PHO-CMC-42','excimer_308nm','Dermatology','2026-06-29',
     9.8,false,410,false,true,true,false,'not_applicable',true,false,'fail','Excimer output 9.8% off, dosimeter cal lapsed, operator UV goggles absent — held'),
    ('KIMS Hyderabad','PHO-KIM-51','puva_unit','Phototherapy Unit','2026-06-28',
     7.1,true,1890,true,true,true,true,'uneven',true,true,'conditional_pass','Cabinet uneven output top vs bottom, lamps due — replacement scheduled'),
    ('KIMS Hyderabad','PHO-KIM-52','nb_uvb_cabinet','Dermatology','2026-06-28',
     null,false,2400,true,false,true,true,'fail',false,false,'removed_from_service','E-stop unresponsive, lamps end-of-life, dosimetry not done — tagged out of service'),
    ('Yashoda Hyderabad','PHO-YSH-61','targeted_uv_handpiece','Skin OPD','2026-06-27',
     3.6,true,220,false,true,true,true,'not_applicable',true,true,'pass','Handpiece for vitiligo — dose delivery verified'),
    ('Rainbow Hyderabad','PHO-RBW-71','nb_uvb_cabinet','Dermatology','2026-06-27',
     1.1,true,90,false,true,true,true,'ok',true,true,'pass','New cabinet commissioning QC — baseline dosimetry verified')
  ) as q(hosp, code, dtype, dept, chk, irr, dcal, lhrs, lrepl, tacc, eyesh, ppe, unif, estop, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.derm_phototherapy_capa_actions_r3367 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PHO-FRT-12','irradiance_out_of_tolerance','lamp_aging','replace_uv_lamps','open','nabh_finding','2026-07-09',null,45000.00,'Full lamp bank replacement + re-dosimetry required'),
    ('PHO-CMC-42','dosimetry_calibration_lapsed','dosimeter_out_of_calibration','recalibrate_dosimeter','in_progress','iso_13485_deviation','2026-07-06',null,12000.00,'Dosimeter sent for NABL calibration'),
    ('PHO-KIM-52','emergency_stop_failure','interlock_switch_fault','repair_emergency_stop','escalated','patient_safety_alert','2026-07-02',null,22000.00,'E-stop non-functional — device tagged out, OEM escalation raised'),
    ('PHO-KIM-51','lamp_end_of_life','lamp_aging','replace_uv_lamps','open','internal_only','2026-07-10',null,38000.00,'PUVA lamp set on order — uneven output confirmed'),
    ('PHO-MNP-22','timer_inaccuracy','timer_circuit_drift','adjust_replace_timer','verification_pending','internal_only','2026-07-05',null,8000.00,'Timer board recalibrated — verify on next dose check'),
    ('PHO-AIM-31','eye_shield_missing','consumable_stockout','restock_eye_shields','closed','nabh_finding','2026-07-01','2026-06-30',3500.00,'Eye-shield stock replenished same day and verified'),
    ('PHO-APL-02','irradiance_out_of_tolerance','ballast_degradation','schedule_oem_service','overdue','internal_only','2026-06-28',null,15000.00,'OEM service past target date — vendor follow-up pending')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.derm_phototherapy_r3367 e
    on e.organization_id = v_org_id and e.device_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3367_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.derm_phototherapy_r3367)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.derm_phototherapy_r3367 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3367_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3367_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3367_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  dosimetry_fail bigint,
  lamp_due bigint,
  calibration_lapsed bigint,
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
    count(*) filter (where l.dosimetry_calibration_ok = false)::bigint,
    count(*) filter (where l.lamp_replacement_due = true)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.derm_phototherapy_r3367 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3367_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3367_hospital_scorecard() to authenticated;

-- 3) Device type × department matrix
create or replace function public.founder_r3367_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_irradiance_error_pct numeric, avg_lamp_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.uv_irradiance_error_pct), 2),
    round(avg(l.lamp_hours), 0)
  from public.derm_phototherapy_r3367 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3367_device_department_matrix() from public, anon;
grant execute on function public.founder_r3367_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3367_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, dosimetry_fail bigint, lamp_due bigint)
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
    count(*) filter (where l.dosimetry_calibration_ok = false)::bigint,
    count(*) filter (where l.lamp_replacement_due = true)::bigint
  from public.derm_phototherapy_r3367 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3367_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3367_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3367_capa_status_board()
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
  from public.derm_phototherapy_capa_actions_r3367 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3367_capa_status_board() from public, anon;
grant execute on function public.founder_r3367_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3367_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.derm_phototherapy_capa_actions_r3367)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.derm_phototherapy_capa_actions_r3367 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3367_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3367_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3367_regulatory_impact_digest()
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
  from public.derm_phototherapy_capa_actions_r3367 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3367_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3367_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3367_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  check_date date,
  qc_verdict text,
  uniformity_across_cabinet_ok text,
  dosimetry_calibration_ok boolean,
  emergency_stop_ok boolean,
  calibration_current boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.check_date,
    l.qc_verdict, l.uniformity_across_cabinet_ok, l.dosimetry_calibration_ok,
    l.emergency_stop_ok, l.calibration_current, l.notes
  from public.derm_phototherapy_r3367 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.dosimetry_calibration_ok = false
     or l.lamp_replacement_due = true
     or l.timer_accuracy_ok = false
     or l.patient_eye_shield_available = false
     or l.operator_ppe_available = false
     or l.uniformity_across_cabinet_ok in ('uneven','fail')
     or l.emergency_stop_ok = false
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3367_high_risk_queue() from public, anon;
grant execute on function public.founder_r3367_high_risk_queue() to authenticated;
