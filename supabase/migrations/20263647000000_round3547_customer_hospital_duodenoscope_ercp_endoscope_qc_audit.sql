-- Round 3547: Customer Hospital Duodenoscope (ERCP) Endoscope QC Audit
-- Duodenoscope ERCP QA — elevator mechanism × image resolution × channel seal leak × reprocess leak × light output × angulation × distal cap integrity × reference-vs-measured accuracy × CAPA

-- =============================================================================
-- TABLE 1: duodenoscope_qc_r3547 — per-device duodenoscope QC parameter checks
-- =============================================================================
create table if not exists public.duodenoscope_qc_r3547 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','elevator_movement_deg','light_output_lux','channel_seal_leak','angulation_deg','distal_cap_integrity'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.duodenoscope_qc_r3547 enable row level security;

create index if not exists idx_duodenoscope_qc_r3547_org on public.duodenoscope_qc_r3547(organization_id);
create index if not exists idx_duodenoscope_qc_r3547_date on public.duodenoscope_qc_r3547(calibration_date);
create index if not exists idx_duodenoscope_qc_r3547_verdict on public.duodenoscope_qc_r3547(qc_verdict);

-- =============================================================================
-- TABLE 2: duodenoscope_qc_capa_actions_r3547 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.duodenoscope_qc_capa_actions_r3547 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.duodenoscope_qc_r3547(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_resolution_degraded','elevator_movement_restricted','light_output_low',
    'channel_seal_leak_detected','angulation_out_of_spec','distal_cap_damaged',
    'reprocess_leak_test_failure','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'elevator_mechanism_wear','sealing_o_ring_degraded','ccd_sensor_degraded','light_guide_fiber_broken',
    'angulation_wire_stretched','distal_cap_adhesive_failure','operator_handling_damage',
    'channel_liner_perforation','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_elevator_mechanism','replace_sealing_o_ring','replace_ccd_sensor','repair_light_guide',
    'retension_angulation_wire','replace_distal_cap','retrain_reprocessing_staff',
    'remove_from_service','schedule_oem_service','reseal_channel','none_required'
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

alter table public.duodenoscope_qc_capa_actions_r3547 enable row level security;

create index if not exists idx_duodenoscope_capa_r3547_log on public.duodenoscope_qc_capa_actions_r3547(qc_log_id);
create index if not exists idx_duodenoscope_capa_r3547_status on public.duodenoscope_qc_capa_actions_r3547(capa_status);

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

  -- 16 QC parameter-check rows
  insert into public.duodenoscope_qc_r3547 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','DUO-APL-01','Olympus TJF-Q190V','image_resolution',
     1080,1078,0.19,true,'2026-07-05','pass','HD image resolution within spec, CCD clean'),
    ('Apollo Chennai','DUO-APL-02','Fujifilm ED-580XT','elevator_movement_deg',
     45,44.5,1.11,true,'2026-07-05','pass','Elevator full range of motion verified'),
    ('Fortis Gurgaon','DUO-FRT-11','Pentax ED34-i10T2','channel_seal_leak',
     0,12,null,false,'2026-07-04','fail','Reprocess leak test failed — 12 mmHg pressure drop, channel seal breach'),
    ('Fortis Gurgaon','DUO-FRT-12','Olympus TJF-Q190V','light_output_lux',
     8000,7100,11.25,false,'2026-07-04','conditional_pass','Light output 11% below spec — light guide aging'),
    ('Manipal Bengaluru','DUO-MNP-21','Fujifilm ED-580XT','angulation_deg',
     130,118,9.23,false,'2026-07-03','fail','Up-angulation restricted, wire stretched beyond limit'),
    ('Manipal Bengaluru','DUO-MNP-22','Pentax ED34-i10T2','distal_cap_integrity',
     100,100,0,true,'2026-07-03','pass','Distal cap intact, adhesive seal good'),
    ('AIIMS Delhi','DUO-AIM-31','Olympus TJF-Q190V','image_resolution',
     1080,1042,3.52,true,'2026-07-02','conditional_pass','Slight resolution drop, CCD cleaning advised'),
    ('AIIMS Delhi','DUO-AIM-32','Fujifilm ED-580XT','channel_seal_leak',
     0,0,0,true,'2026-07-02','pass','Leak test passed, no pressure drop'),
    ('CMC Vellore','DUO-CMC-41','Pentax ED34-i10T2','elevator_movement_deg',
     45,41,8.89,false,'2026-07-01','conditional_pass','Elevator movement slightly restricted, lubrication done'),
    ('CMC Vellore','DUO-CMC-42','Olympus TJF-Q190V','light_output_lux',
     8000,7950,0.63,true,'2026-07-01','pass','Light output within tolerance'),
    ('KIMS Hyderabad','DUO-KIM-51','Fujifilm ED-580XT','angulation_deg',
     130,129,0.77,true,'2026-06-30','pass','Angulation full range within spec'),
    ('KIMS Hyderabad','DUO-KIM-52','Pentax ED34-i10T2','distal_cap_integrity',
     100,82,18,false,'2026-06-30','fail','Distal cap adhesive failure, cap loose — removed from service'),
    ('Yashoda Hyderabad','DUO-YSH-61','Olympus TJF-Q190V','channel_seal_leak',
     0,6,null,false,'2026-06-29','conditional_pass','Minor leak 6 mmHg — reprocess repeated, watch'),
    ('Kokilaben Mumbai','DUO-KKB-71','Fujifilm ED-580XT','image_resolution',
     1080,960,11.11,false,'2026-06-29','fail','Image resolution well below spec, CCD sensor degraded'),
    ('Kokilaben Mumbai','DUO-KKB-72','Pentax ED34-i10T2','elevator_movement_deg',
     45,45,0,true,'2026-06-28','pass','Elevator movement nominal post-service'),
    ('Medanta Gurgaon','DUO-MDT-81','Olympus TJF-Q190V','angulation_deg',
     130,122,6.15,false,'2026-06-28','conditional_pass','Down-angulation slightly reduced, monitor')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, qv, nt);

  -- CAPA seed — 9 rows attached to specific checks via device_code
  insert into public.duodenoscope_qc_capa_actions_r3547 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('DUO-FRT-11','channel_seal_leak_detected','channel_liner_perforation','reseal_channel','in_progress','patient_safety_alert','2026-07-08',null,38000.00,'Channel liner perforation confirmed — resealing and re-leak-test'),
    ('DUO-FRT-12','light_output_low','light_guide_fiber_broken','repair_light_guide','open','iso_13485_deviation','2026-07-10',null,52000.00,'Light guide fiber bundle partially broken — OEM repair quoted'),
    ('DUO-MNP-21','angulation_out_of_spec','angulation_wire_stretched','retension_angulation_wire','escalated','nabh_finding','2026-07-07',null,29000.00,'Up-angulation wire stretched beyond limit — escalated to OEM'),
    ('DUO-AIM-31','image_resolution_degraded','ccd_sensor_degraded','replace_ccd_sensor','verification_pending','internal_only','2026-07-09',null,64000.00,'CCD module cleaned; resolution re-check pending'),
    ('DUO-CMC-41','elevator_movement_restricted','elevator_mechanism_wear','replace_elevator_mechanism','open','iso_13485_deviation','2026-07-11',null,71000.00,'Elevator mechanism worn — replacement scheduled'),
    ('DUO-KIM-52','distal_cap_damaged','distal_cap_adhesive_failure','replace_distal_cap','closed','cdsco_notifiable','2026-07-05','2026-07-02',9500.00,'Distal cap replaced and integrity verified; back in service'),
    ('DUO-YSH-61','reprocess_leak_test_failure','sealing_o_ring_degraded','replace_sealing_o_ring','in_progress','internal_only','2026-07-06',null,6800.00,'O-ring seal replaced — repeat leak test scheduled'),
    ('DUO-KKB-71','image_resolution_degraded','ccd_sensor_degraded','replace_ccd_sensor','overdue','patient_safety_alert','2026-07-01',null,64000.00,'CCD sensor replacement past target — vendor delay'),
    ('DUO-MDT-81','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','open','none','2026-07-12',null,18000.00,'Preventive service due — OEM visit booked')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.duodenoscope_qc_r3547 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3547_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.duodenoscope_qc_r3547)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.duodenoscope_qc_r3547 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3547_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3547_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3547_device_model_scorecard()
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
  from public.duodenoscope_qc_r3547 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3547_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3547_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3547_parameter_verdict_matrix()
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
  from public.duodenoscope_qc_r3547 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3547_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3547_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3547_monthly_calibration_trend()
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
  from public.duodenoscope_qc_r3547 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3547_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3547_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3547_capa_status_board()
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
  from public.duodenoscope_qc_capa_actions_r3547 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3547_capa_status_board() from public, anon;
grant execute on function public.founder_r3547_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3547_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.duodenoscope_qc_capa_actions_r3547)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.duodenoscope_qc_capa_actions_r3547 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3547_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3547_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3547_accuracy_impact_digest()
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
  select l.parameter,
    count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.within_tolerance = true)::numeric / nullif(count(*),0), 1)
  from public.duodenoscope_qc_r3547 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc;
end;
$$;

revoke execute on function public.founder_r3547_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3547_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail concerns)
create or replace function public.founder_r3547_high_risk_queue()
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
  from public.duodenoscope_qc_r3547 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or (l.parameter = 'channel_seal_leak' and l.qc_verdict <> 'pass')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3547_high_risk_queue() from public, anon;
grant execute on function public.founder_r3547_high_risk_queue() to authenticated;
