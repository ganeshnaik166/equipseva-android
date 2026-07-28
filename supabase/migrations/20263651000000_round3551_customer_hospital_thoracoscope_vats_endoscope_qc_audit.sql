-- Round 3551: Customer Hospital Thoracoscope (VATS) Endoscope QC Audit
-- Thoracoscope VATS imaging QC — parameter × reference vs measured × deviation × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: thoracoscope_qc_r3551 — per-parameter thoracoscope imaging QC checks
-- =============================================================================
create table if not exists public.thoracoscope_qc_r3551 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','light_transmission','viewing_angle_deg','color_fidelity','focus_clarity','seal_leak_test'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.thoracoscope_qc_r3551 enable row level security;

create index if not exists idx_thoracoscope_qc_r3551_org on public.thoracoscope_qc_r3551(organization_id);
create index if not exists idx_thoracoscope_qc_r3551_caldate on public.thoracoscope_qc_r3551(calibration_date);
create index if not exists idx_thoracoscope_qc_r3551_verdict on public.thoracoscope_qc_r3551(qc_verdict);

-- =============================================================================
-- TABLE 2: thoracoscope_qc_capa_actions_r3551 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.thoracoscope_qc_capa_actions_r3551 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.thoracoscope_qc_r3551(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'resolution_below_spec','light_transmission_loss','viewing_angle_deviation','color_fidelity_drift',
    'focus_blur','seal_leak_detected','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'fiber_bundle_damaged','lens_fogging_seal_failure','light_guide_degraded','ccd_sensor_aging',
    'optical_coating_wear','mechanical_misalignment','operator_handling_damage',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_fiber_bundle','reseal_and_leak_test','replace_light_guide','replace_ccd_module',
    'recalibrate_optics','realign_optical_path','send_to_oem_repair','retrain_ot_staff',
    'remove_from_service','none_required'
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

alter table public.thoracoscope_qc_capa_actions_r3551 enable row level security;

create index if not exists idx_thoracoscope_capa_r3551_log on public.thoracoscope_qc_capa_actions_r3551(qc_log_id);
create index if not exists idx_thoracoscope_capa_r3551_status on public.thoracoscope_qc_capa_actions_r3551(capa_status);

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
  insert into public.thoracoscope_qc_r3551 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','THS-APL-01','Olympus LTF-VP','image_resolution',
     60,59,-1.7,true,'2026-07-05','pass','VATS thoracoscope resolution within spec (line pairs/mm)'),
    ('Apollo Chennai','THS-APL-02','Olympus LTF-VP','light_transmission',
     100,96,-4.0,true,'2026-07-05','pass','Light transmission 96% — nominal'),
    ('Apollo Chennai','THS-APL-03','Stryker 1588 AIM','color_fidelity',
     95,90,-5.3,true,'2026-07-05','conditional_pass','Slight color drift, within action limit — recheck next quarter'),
    ('Fortis Gurgaon','THS-FRT-11','Karl Storz Image1 S','focus_clarity',
     100,82,-18.0,false,'2026-07-04','fail','Focus blur at working distance — lens fogging suspected'),
    ('Fortis Gurgaon','THS-FRT-12','Karl Storz Image1 S','seal_leak_test',
     0,3,null,false,'2026-07-04','fail','Seal leak test failed — pressure drop 3 mbar'),
    ('Fortis Gurgaon','THS-FRT-13','Karl Storz Image1 S','viewing_angle_deg',
     30,30,0.0,true,'2026-07-04','pass','Viewing angle nominal at 30 deg'),
    ('Manipal Bengaluru','THS-MNP-21','Olympus LTF-VP','image_resolution',
     60,52,-13.3,false,'2026-07-02','fail','Resolution below spec — fiber bundle damage suspected'),
    ('Manipal Bengaluru','THS-MNP-22','Stryker 1588 AIM','light_transmission',
     100,88,-12.0,false,'2026-07-02','conditional_pass','Light transmission loss — light guide aging, monitor'),
    ('AIIMS Delhi','THS-AIM-31','Karl Storz Image1 S','color_fidelity',
     95,94,-1.1,true,'2026-06-30','pass','Color fidelity within spec'),
    ('AIIMS Delhi','THS-AIM-32','Olympus LTF-VP','focus_clarity',
     100,97,-3.0,true,'2026-06-30','pass','Focus clarity good across field'),
    ('CMC Vellore','THS-CMC-41','Stryker 1588 AIM','seal_leak_test',
     0,0,0.0,true,'2026-06-28','pass','Seal leak test passed — no pressure drop'),
    ('CMC Vellore','THS-CMC-42','Karl Storz Image1 S','viewing_angle_deg',
     30,33,10.0,false,'2026-06-28','conditional_pass','Viewing angle deviation 3 deg — realignment scheduled'),
    ('KIMS Hyderabad','THS-KIM-51','Olympus LTF-VP','image_resolution',
     60,58,-3.3,true,'2026-06-26','pass','Resolution within tolerance post-AMC'),
    ('KIMS Hyderabad','THS-KIM-52','Stryker 1588 AIM','light_transmission',
     100,79,-21.0,false,'2026-06-26','fail','Severe light loss — light guide replacement needed'),
    ('Kokilaben Mumbai','THS-KKB-61','Karl Storz Image1 S','focus_clarity',
     100,90,-10.0,false,'2026-06-25','conditional_pass','Focus degraded — optics recalibration due'),
    ('Yashoda Hyderabad','THS-YSH-71','Olympus LTF-VP','seal_leak_test',
     0,5,null,false,'2026-06-24','fail','Major seal leak 5 mbar — removed pending reseal')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.thoracoscope_qc_capa_actions_r3551 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('THS-FRT-11','focus_blur','lens_fogging_seal_failure','reseal_and_leak_test','in_progress','iso_13485_deviation','2026-07-08',null,18000.00,'Focus blur from lens fogging — reseal and re-test optics'),
    ('THS-FRT-12','seal_leak_detected','lens_fogging_seal_failure','reseal_and_leak_test','escalated','patient_safety_alert','2026-07-07',null,22000.00,'Seal leak 3 mbar — sterility risk, escalated to OEM'),
    ('THS-MNP-21','resolution_below_spec','fiber_bundle_damaged','replace_fiber_bundle','open','cdsco_notifiable','2026-07-06',null,145000.00,'Resolution below spec — fiber bundle replacement quoted'),
    ('THS-MNP-22','light_transmission_loss','light_guide_degraded','replace_light_guide','verification_pending','internal_only','2026-07-05',null,26000.00,'Light guide replaced — verify transmission next case'),
    ('THS-CMC-42','viewing_angle_deviation','mechanical_misalignment','realign_optical_path','open','nabh_finding','2026-07-09',null,9000.00,'Viewing angle 3 deg off — optical realignment scheduled'),
    ('THS-KIM-52','light_transmission_loss','light_guide_degraded','replace_light_guide','overdue','iso_13485_deviation','2026-06-30',null,26000.00,'Severe light loss — replacement past target, vendor delay'),
    ('THS-KKB-61','focus_blur','optical_coating_wear','recalibrate_optics','closed','internal_only','2026-06-28','2026-06-27',7500.00,'Optics recalibrated — focus restored and validated'),
    ('THS-YSH-71','seal_leak_detected','lens_fogging_seal_failure','remove_from_service','escalated','patient_safety_alert','2026-06-27',null,32000.00,'Major seal leak 5 mbar — removed from service pending reseal')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.thoracoscope_qc_r3551 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3551_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.thoracoscope_qc_r3551)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.thoracoscope_qc_r3551 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3551_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3551_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3551_device_model_scorecard()
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
  from public.thoracoscope_qc_r3551 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3551_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3551_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3551_parameter_verdict_matrix()
returns table(
  parameter text,
  checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.thoracoscope_qc_r3551 l
  group by l.parameter
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3551_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3551_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3551_monthly_accuracy_trend()
returns table(
  cal_month date,
  checks bigint,
  passed bigint,
  failed bigint,
  out_of_tolerance bigint,
  avg_deviation_pct numeric
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
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.thoracoscope_qc_r3551 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3551_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3551_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3551_capa_status_board()
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
  from public.thoracoscope_qc_capa_actions_r3551 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3551_capa_status_board() from public, anon;
grant execute on function public.founder_r3551_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3551_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.thoracoscope_qc_capa_actions_r3551)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.thoracoscope_qc_capa_actions_r3551 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3551_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3551_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3551_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tolerance_count bigint,
  out_of_tolerance_count bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric,
  fail_count bigint
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
    round(avg(l.deviation_pct), 2),
    round(max(abs(l.deviation_pct)), 2),
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.thoracoscope_qc_r3551 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3551_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3551_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail)
create or replace function public.founder_r3551_high_risk_queue()
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
    l.qc_verdict, l.reference_value, l.measured_value, l.deviation_pct, l.notes
  from public.thoracoscope_qc_r3551 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or (l.parameter = 'seal_leak_test' and l.qc_verdict <> 'pass')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3551_high_risk_queue() from public, anon;
grant execute on function public.founder_r3551_high_risk_queue() to authenticated;
