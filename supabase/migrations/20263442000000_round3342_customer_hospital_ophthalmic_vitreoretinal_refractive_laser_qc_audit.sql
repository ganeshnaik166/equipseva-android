-- Round 3342: Customer Hospital Ophthalmic Surgical-Laser & Vitreoretinal-Suite QC Audit
-- Ophthalmic QA — device type × department × cut-rate × vacuum/fluidics × laser-energy error × beam alignment × eye-tracker × gas/fluid exchange × cal-pattern × safety interlock × disposables × calibration × CAPA

-- =============================================================================
-- TABLE 1: ophthalmic_laser_qc_r3342 — per-device QC checks
-- =============================================================================
create table if not exists public.ophthalmic_laser_qc_r3342 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_type text not null check (device_type in (
    'vitrectomy_machine','femtosecond_laser','excimer_laser','phaco_vitrectomy_combo','endolaser_photocoagulator'
  )),
  department text not null,
  check_date date not null,
  cut_rate_accuracy_ok boolean,
  vacuum_fluidics_ok boolean,
  laser_energy_output_error_pct numeric(5,2),
  beam_delivery_alignment_ok boolean,
  eye_tracker_ok text not null check (eye_tracker_ok in (
    'ok','drift','fail','not_applicable'
  )),
  gas_fluid_exchange_ok boolean,
  calibration_test_pattern_pass boolean,
  safety_shutter_interlock_ok boolean,
  disposables_stock text not null check (disposables_stock in (
    'adequate','low','out_of_stock'
  )),
  calibration_current boolean,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ophthalmic_laser_qc_r3342 enable row level security;

create index if not exists idx_ophthalmic_laser_qc_r3342_org on public.ophthalmic_laser_qc_r3342(organization_id);
create index if not exists idx_ophthalmic_laser_qc_r3342_date on public.ophthalmic_laser_qc_r3342(check_date);
create index if not exists idx_ophthalmic_laser_qc_r3342_verdict on public.ophthalmic_laser_qc_r3342(qc_verdict);

-- =============================================================================
-- TABLE 2: ophthalmic_laser_qc_capa_actions_r3342 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ophthalmic_laser_qc_capa_actions_r3342 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ophthalmic_laser_qc_r3342(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'cut_rate_deviation','vacuum_fluidics_fault','laser_energy_deviation','beam_alignment_fault',
    'eye_tracker_fault','gas_fluid_exchange_fault','calibration_pattern_failure','safety_interlock_failure',
    'disposables_stockout','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'cutter_pneumatic_wear','fluidics_cassette_fault','laser_source_degradation','beam_optics_misaligned',
    'tracker_camera_fault','valve_seal_leak','software_config_error','operator_setup_error',
    'consumable_supply_delay','preventive_service_backlog','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_cutter_probe','service_fluidics_module','recalibrate_laser_energy','realign_beam_delivery',
    'recalibrate_eye_tracker','replace_valve_seal','update_software_config','retrain_ot_staff',
    'replenish_disposables','remove_from_service','schedule_oem_service','none_required'
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

alter table public.ophthalmic_laser_qc_capa_actions_r3342 enable row level security;

create index if not exists idx_ophthalmic_capa_r3342_log on public.ophthalmic_laser_qc_capa_actions_r3342(qc_log_id);
create index if not exists idx_ophthalmic_capa_r3342_status on public.ophthalmic_laser_qc_capa_actions_r3342(capa_status);

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

  -- 14 per-device QC rows
  insert into public.ophthalmic_laser_qc_r3342 (
    organization_id, hospital_name, device_code, device_type, department, check_date,
    cut_rate_accuracy_ok, vacuum_fluidics_ok, laser_energy_output_error_pct, beam_delivery_alignment_ok,
    eye_tracker_ok, gas_fluid_exchange_ok, calibration_test_pattern_pass, safety_shutter_interlock_ok,
    disposables_stock, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dtype, q.dept, q.cdt::date,
    q.cra, q.vfo, q.leo::numeric, q.bda::boolean, q.eto, q.gfe, q.ctp, q.ssi,
    q.dst, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','DEV-APL-VR1','vitrectomy_machine','Vitreoretinal OT','2026-07-03',
     true,true,null,null,'not_applicable',true,true,true,'adequate',true,'pass','Constellation vitrectomy — cut rate & fluidics nominal'),
    ('Apollo Chennai Greams Road','DEV-APL-FS1','femtosecond_laser','Cataract OT','2026-07-03',
     null,null,2.10,true,'ok',null,true,true,'adequate',true,'pass','Femto cataract laser — energy error 2.1% within tolerance'),
    ('Fortis Gurgaon','DEV-FRT-EX1','excimer_laser','Refractive Suite','2026-07-02',
     null,null,6.40,true,'drift',null,true,true,'low',true,'conditional_pass','Excimer energy 6.4% over 5% limit and tracker drift — recheck booked'),
    ('Fortis Gurgaon','DEV-FRT-PV1','phaco_vitrectomy_combo','Vitreoretinal OT','2026-07-02',
     true,false,3.20,true,'not_applicable',true,true,true,'adequate',true,'conditional_pass','Combo phaco-vitrectomy — vacuum fluidics unstable on aspiration test'),
    ('Manipal Bengaluru Old Airport Road','DEV-MNP-EX1','excimer_laser','LASIK Suite','2026-07-01',
     null,null,1.80,false,'fail',null,false,true,'adequate',true,'fail','Beam delivery misaligned & eye-tracker failed centration — pattern test failed'),
    ('Manipal Bengaluru Old Airport Road','DEV-MNP-VR1','vitrectomy_machine','Vitreoretinal OT','2026-07-01',
     false,true,null,null,'not_applicable',true,true,true,'adequate',true,'conditional_pass','Cut-rate accuracy off at 10k cpm setting — probe watch'),
    ('AIIMS Delhi Ansari Nagar','DEV-AIM-FS1','femtosecond_laser','Cataract OT','2026-06-30',
     null,null,8.90,true,'ok',null,true,false,'adequate',false,'removed_from_service','Safety shutter interlock open-circuit & calibration overdue — unit locked out'),
    ('AIIMS Delhi Ansari Nagar','DEV-AIM-EN1','endolaser_photocoagulator','Retina Clinic','2026-06-30',
     null,null,0.90,true,'not_applicable',null,true,true,'adequate',true,'pass','Green endolaser photocoagulator — energy output within 1%'),
    ('CMC Vellore','DEV-CMC-PV1','phaco_vitrectomy_combo','Vitreoretinal OT','2026-06-29',
     true,true,4.10,true,'not_applicable',false,true,true,'low',true,'conditional_pass','Gas-fluid exchange pressure low & endolaser disposables running low'),
    ('CMC Vellore','DEV-CMC-EX1','excimer_laser','Refractive Suite','2026-06-29',
     null,null,12.50,true,'fail',null,false,true,'out_of_stock',false,'removed_from_service','Excimer energy 12.5% high, tracker fail, gas out of stock — pulled from service'),
    ('KIMS Hyderabad','DEV-KIM-VR1','vitrectomy_machine','Vitreoretinal OT','2026-06-28',
     true,true,null,null,'not_applicable',true,true,true,'adequate',true,'pass','Quarterly QC clean pass'),
    ('KIMS Hyderabad','DEV-KIM-FS1','femtosecond_laser','LASIK Suite','2026-06-28',
     null,null,3.60,true,'drift',null,true,true,'adequate',true,'conditional_pass','Eye-tracker drift beyond 2 sigma on grid test — recalibration scheduled'),
    ('Narayana Nethralaya Bengaluru','DEV-NNL-EN1','endolaser_photocoagulator','Retina Clinic','2026-06-27',
     null,null,null,false,'not_applicable',null,false,true,'adequate',false,'fail','Beam delivery alignment failed, pattern test aborted, calibration lapsed'),
    ('Sankara Nethralaya Chennai','DEV-SNK-EX1','excimer_laser','Refractive Suite','2026-06-27',
     null,null,2.40,true,'ok',null,true,true,'adequate',true,'pass','Refractive suite excimer — annual QC nominal')
  ) as q(hosp, dcode, dtype, dept, cdt, cra, vfo, leo, bda, eto, gfe, ctp, ssi, dst, cc, qv, nt);

  -- CAPA seed — attach to specific devices via device_code
  insert into public.ophthalmic_laser_qc_capa_actions_r3342 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('DEV-FRT-EX1','laser_energy_deviation','laser_source_degradation','recalibrate_laser_energy','in_progress','nabh_finding','2026-07-07',null,38000.00,'Excimer energy 6.4% over limit — fluence recalibration in progress'),
    ('DEV-FRT-PV1','vacuum_fluidics_fault','fluidics_cassette_fault','service_fluidics_module','in_progress','patient_safety_alert','2026-07-07',null,22000.00,'Fluidics cassette replaced — awaiting aspiration re-test'),
    ('DEV-MNP-EX1','beam_alignment_fault','beam_optics_misaligned','realign_beam_delivery','escalated','cdsco_notifiable','2026-07-06',null,55000.00,'Beam path realignment escalated to OEM applications engineer'),
    ('DEV-AIM-FS1','safety_interlock_failure','pending_investigation','remove_from_service','open','patient_safety_alert','2026-07-05',null,48000.00,'Shutter interlock open-circuit — device tagged out pending OEM diagnosis'),
    ('DEV-CMC-EX1','laser_energy_deviation','laser_source_degradation','recalibrate_laser_energy','open','cdsco_notifiable','2026-07-09',null,130000.00,'Excimer energy 12.5% high — laser gas fill & source check ordered'),
    ('DEV-NNL-EN1','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','iso_13485_deviation','2026-06-25',null,15000.00,'Endolaser calibration lapsed — OEM service past target date'),
    ('DEV-CMC-PV1','gas_fluid_exchange_fault','valve_seal_leak','replace_valve_seal','closed','internal_only','2026-07-01','2026-06-30',9000.00,'Air-fluid exchange valve seal replaced — pressure verified')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ophthalmic_laser_qc_r3342 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3342_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_laser_qc_r3342)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ophthalmic_laser_qc_r3342 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3342_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3342_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3342_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  energy_error_high bigint,
  interlock_fail bigint,
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
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.laser_energy_output_error_pct > 5)::bigint,
    count(*) filter (where l.safety_shutter_interlock_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ophthalmic_laser_qc_r3342 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3342_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3342_hospital_scorecard() to authenticated;

-- 3) Device-type × department matrix
create or replace function public.founder_r3342_device_department_matrix()
returns table(device_type text, department text, checks bigint, passed bigint, avg_energy_error_pct numeric, interlock_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_type, l.department, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.laser_energy_output_error_pct), 2),
    count(*) filter (where l.safety_shutter_interlock_ok = false)::bigint
  from public.ophthalmic_laser_qc_r3342 l
  group by l.device_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3342_device_department_matrix() from public, anon;
grant execute on function public.founder_r3342_device_department_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3342_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, interlock_fail bigint, calibration_overdue bigint)
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
    count(*) filter (where l.safety_shutter_interlock_ok = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint
  from public.ophthalmic_laser_qc_r3342 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3342_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3342_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3342_capa_status_board()
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
  from public.ophthalmic_laser_qc_capa_actions_r3342 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3342_capa_status_board() from public, anon;
grant execute on function public.founder_r3342_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3342_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ophthalmic_laser_qc_capa_actions_r3342)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ophthalmic_laser_qc_capa_actions_r3342 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3342_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3342_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3342_regulatory_impact_digest()
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
  from public.ophthalmic_laser_qc_capa_actions_r3342 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3342_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3342_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3342_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_type text,
  department text,
  check_date date,
  qc_verdict text,
  eye_tracker_ok text,
  disposables_stock text,
  laser_energy_output_error_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_type, l.department, l.check_date,
    l.qc_verdict, l.eye_tracker_ok, l.disposables_stock, l.laser_energy_output_error_pct, l.notes
  from public.ophthalmic_laser_qc_r3342 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.eye_tracker_ok in ('drift','fail')
     or l.safety_shutter_interlock_ok = false
     or l.calibration_current = false
     or l.calibration_test_pattern_pass = false
     or l.disposables_stock = 'out_of_stock'
     or l.laser_energy_output_error_pct > 5
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3342_high_risk_queue() from public, anon;
grant execute on function public.founder_r3342_high_risk_queue() to authenticated;
