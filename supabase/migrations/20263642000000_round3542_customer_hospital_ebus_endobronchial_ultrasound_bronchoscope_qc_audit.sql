-- Round 3542: Customer Hospital EBUS Endobronchial-Ultrasound Bronchoscope QC Audit
-- Hospital EBUS bronchoscope QC — ultrasound freq × image resolution × angulation × light output × channel seal leak × doppler sensitivity × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: ebus_qc_r3542 — per-parameter EBUS bronchoscope QC measurements
-- =============================================================================
create table if not exists public.ebus_qc_r3542 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  qc_ref text not null,
  parameter text not null check (parameter in (
    'ultrasound_freq_mhz','image_resolution','angulation_deg','light_output_lux','channel_seal_leak','doppler_sensitivity'
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

alter table public.ebus_qc_r3542 enable row level security;

create index if not exists idx_ebus_qc_r3542_org on public.ebus_qc_r3542(organization_id);
create index if not exists idx_ebus_qc_r3542_date on public.ebus_qc_r3542(calibration_date);
create index if not exists idx_ebus_qc_r3542_verdict on public.ebus_qc_r3542(qc_verdict);
create index if not exists idx_ebus_qc_r3542_ref on public.ebus_qc_r3542(qc_ref);

-- =============================================================================
-- TABLE 2: ebus_qc_capa_actions_r3542 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ebus_qc_capa_actions_r3542 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  qc_ref text not null,
  qc_log_id uuid references public.ebus_qc_r3542(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'ultrasound_freq_drift','image_resolution_degraded','angulation_out_of_spec','light_output_low',
    'channel_seal_leak','doppler_sensitivity_loss','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_element_aging','probe_wear','angulation_cable_stretch','light_guide_degraded',
    'seal_gasket_worn','doppler_crystal_fault','calibration_drift','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_transducer','replace_probe','adjust_angulation_mechanism','replace_light_guide',
    'replace_seal_gasket','service_doppler_module','schedule_oem_service','retrain_staff',
    'remove_from_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ebus_qc_capa_actions_r3542 enable row level security;

create index if not exists idx_ebus_qc_capa_r3542_log on public.ebus_qc_capa_actions_r3542(qc_log_id);
create index if not exists idx_ebus_qc_capa_r3542_status on public.ebus_qc_capa_actions_r3542(capa_status);

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

  -- 16 EBUS QC measurement rows
  insert into public.ebus_qc_r3542 (
    organization_id, hospital_name, device_code, device_model, qc_ref, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.qref, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','EBUS-APL-01','Olympus BF-UC190F','EBUS-APL-01-FREQ','ultrasound_freq_mhz',
     7.50,7.52,0.27,true,'2026-07-05','pass','Convex EBUS ultrasound frequency within spec'),
    ('Apollo Chennai','EBUS-APL-01','Olympus BF-UC190F','EBUS-APL-01-IMG','image_resolution',
     0.50,0.53,6.00,true,'2026-07-05','pass','Axial image resolution nominal at 20 MHz'),
    ('Apollo Chennai','EBUS-APL-02','Fujifilm EB-530US','EBUS-APL-02-ANG','angulation_deg',
     120.0,112.0,6.67,false,'2026-07-04','conditional_pass','Tip up-angulation reduced to 112 deg — cable stretch'),
    ('Fortis Gurgaon','EBUS-FRT-11','Olympus BF-UC190F','EBUS-FRT-11-LEAK','channel_seal_leak',
     0.0,8.5,null,false,'2026-07-03','fail','Channel seal leak 8.5 mbar/min — fluid ingress risk, removed'),
    ('Fortis Gurgaon','EBUS-FRT-11','Olympus BF-UC190F','EBUS-FRT-11-LIGHT','light_output_lux',
     4500,3200,28.89,false,'2026-07-03','fail','Light output 3200 lux — light guide bundle degraded'),
    ('Fortis Gurgaon','EBUS-FRT-12','Pentax EB19-J10U','EBUS-FRT-12-FREQ','ultrasound_freq_mhz',
     7.50,7.48,0.27,true,'2026-07-02','pass','Ultrasound frequency stable post-calibration'),
    ('Manipal Bengaluru','EBUS-MNP-21','Fujifilm EB-530US','EBUS-MNP-21-DOP','doppler_sensitivity',
     5.00,6.80,36.00,false,'2026-06-30','fail','Doppler velocity threshold elevated — crystal fault suspected'),
    ('Manipal Bengaluru','EBUS-MNP-21','Fujifilm EB-530US','EBUS-MNP-21-IMG','image_resolution',
     0.50,0.58,16.00,false,'2026-06-30','conditional_pass','Axial resolution borderline — probe service recommended'),
    ('AIIMS Delhi','EBUS-AIM-31','Olympus BF-UC190F','EBUS-AIM-31-ANG','angulation_deg',
     120.0,119.0,0.83,true,'2026-06-29','pass','Angulation within tolerance post-service'),
    ('AIIMS Delhi','EBUS-AIM-31','Olympus BF-UC190F','EBUS-AIM-31-LEAK','channel_seal_leak',
     0.0,1.2,null,true,'2026-06-29','conditional_pass','Minor seal leak 1.2 mbar/min within watch limit'),
    ('CMC Vellore','EBUS-CMC-41','Pentax EB19-J10U','EBUS-CMC-41-FREQ','ultrasound_freq_mhz',
     7.50,7.51,0.13,true,'2026-06-28','pass','Frequency calibration verified'),
    ('CMC Vellore','EBUS-CMC-41','Pentax EB19-J10U','EBUS-CMC-41-LIGHT','light_output_lux',
     4500,4420,1.78,true,'2026-06-28','pass','Light output nominal'),
    ('KIMS Hyderabad','EBUS-KIM-51','Fujifilm EB-530US','EBUS-KIM-51-DOP','doppler_sensitivity',
     5.00,5.10,2.00,true,'2026-06-27','pass','Doppler sensitivity within spec'),
    ('KIMS Hyderabad','EBUS-KIM-52','Olympus BF-UC190F','EBUS-KIM-52-IMG','image_resolution',
     0.50,0.51,2.00,true,'2026-06-27','pass','Image resolution pass on annual QC'),
    ('Yashoda Hyderabad','EBUS-YSH-61','Pentax EB19-J10U','EBUS-YSH-61-LEAK','channel_seal_leak',
     0.0,6.0,null,false,'2026-06-26','fail','Channel seal leak 6.0 mbar/min — seal gasket worn'),
    ('Kokilaben Mumbai','EBUS-KKB-71','Olympus BF-UC190F','EBUS-KKB-71-ANG','angulation_deg',
     120.0,105.0,12.50,false,'2026-06-25','fail','Tip angulation 105 deg out of spec — mechanism service required')
  ) as q(hosp, dcode, dmodel, qref, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific measurements via qc_ref
  insert into public.ebus_qc_capa_actions_r3542 (
    organization_id, qc_ref, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, q.qref, e.id, q.fc, q.rc, q.ca,
    q.cst, q.cost::numeric, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('EBUS-APL-02-ANG','angulation_out_of_spec','angulation_cable_stretch','adjust_angulation_mechanism','in_progress',18000,'Biomed - S. Rao','2026-07-12',null,'Angulation mechanism adjustment scheduled'),
    ('EBUS-FRT-11-LEAK','channel_seal_leak','seal_gasket_worn','replace_seal_gasket','escalated',42000,'Biomed - A. Kumar','2026-07-10',null,'Seal leak escalated to OEM — scope quarantined'),
    ('EBUS-FRT-11-LIGHT','light_output_low','light_guide_degraded','replace_light_guide','open',55000,'Biomed - A. Kumar','2026-07-15',null,'Light guide bundle replacement quoted'),
    ('EBUS-MNP-21-DOP','doppler_sensitivity_loss','doppler_crystal_fault','service_doppler_module','verification_pending',68000,'Biomed - P. Nair','2026-07-08',null,'Doppler module serviced — verification scan pending'),
    ('EBUS-MNP-21-IMG','image_resolution_degraded','transducer_element_aging','replace_probe','open',210000,'Biomed - P. Nair','2026-07-20',null,'Convex probe nearing end of life — replacement PO raised'),
    ('EBUS-YSH-61-LEAK','channel_seal_leak','seal_gasket_worn','replace_seal_gasket','closed',39000,'Biomed - R. Iyer','2026-07-01','2026-06-30','Seal gasket replaced and leak test passed'),
    ('EBUS-KKB-71-ANG','angulation_out_of_spec','angulation_cable_stretch','schedule_oem_service','overdue',47000,'Biomed - M. Shah','2026-06-30',null,'OEM angulation service overdue — vendor delay'),
    ('EBUS-AIM-31-LEAK','preventive_maintenance_due','calibration_drift','none_required','closed',0,'Biomed - K. Menon','2026-07-05','2026-07-02','Minor leak monitored — within limit, no action needed')
  ) as q(qref, fc, rc, ca, cst, cost, own, tcd, acd, nt)
  join public.ebus_qc_r3542 e
    on e.organization_id = v_org_id and e.qc_ref = q.qref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3542_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ebus_qc_r3542)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ebus_qc_r3542 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3542_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3542_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3542_device_model_scorecard()
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
  from public.ebus_qc_r3542 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3542_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3542_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3542_parameter_verdict_matrix()
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
  from public.ebus_qc_r3542 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3542_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3542_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3542_monthly_calibration_trend()
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
  from public.ebus_qc_r3542 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3542_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3542_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3542_capa_status_board()
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
  from public.ebus_qc_capa_actions_r3542 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3542_capa_status_board() from public, anon;
grant execute on function public.founder_r3542_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3542_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ebus_qc_capa_actions_r3542)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ebus_qc_capa_actions_r3542 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3542_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3542_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3542_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  fail_checks bigint,
  avg_deviation_pct numeric,
  max_deviation_pct numeric
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.ebus_qc_r3542 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3542_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3542_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail)
create or replace function public.founder_r3542_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  qc_verdict text,
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
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.notes
  from public.ebus_qc_r3542 l
  where l.within_tolerance = false
     or l.qc_verdict in ('conditional_pass','fail')
     or (l.parameter = 'channel_seal_leak' and l.qc_verdict = 'fail')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3542_high_risk_queue() from public, anon;
grant execute on function public.founder_r3542_high_risk_queue() to authenticated;
