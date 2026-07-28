-- Round 3555: Customer Hospital Nephroscope (Percutaneous Endoscope) QC Audit
-- Nephroscope QA — device model × parameter (image resolution, light transmission, channel flow,
-- viewing angle, color fidelity, seal leak) × reference vs measured × deviation × tolerance × verdict × CAPA

-- =============================================================================
-- TABLE 1: nephroscope_qc_r3555 — per-device nephroscope optical/flow/leak QC checks
-- =============================================================================
create table if not exists public.nephroscope_qc_r3555 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','light_transmission','channel_flow_ml','viewing_angle_deg','color_fidelity','seal_leak_test'
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

alter table public.nephroscope_qc_r3555 enable row level security;

create index if not exists idx_nephroscope_qc_r3555_org on public.nephroscope_qc_r3555(organization_id);
create index if not exists idx_nephroscope_qc_r3555_date on public.nephroscope_qc_r3555(calibration_date);
create index if not exists idx_nephroscope_qc_r3555_verdict on public.nephroscope_qc_r3555(qc_verdict);

-- =============================================================================
-- TABLE 2: nephroscope_qc_capa_actions_r3555 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.nephroscope_qc_capa_actions_r3555 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.nephroscope_qc_r3555(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_resolution_degraded','light_transmission_loss','channel_flow_restricted',
    'viewing_angle_deviation','color_fidelity_drift','seal_leak_detected',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'fiber_bundle_broken','lens_scratched','light_guide_degraded','channel_obstruction',
    'seal_gasket_worn','ccd_sensor_aged','sterilization_damage','operator_handling_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'repair_fiber_bundle','replace_lens','replace_light_guide','clear_channel',
    'replace_seal_gasket','replace_ccd_module','recalibrate_optics','remove_from_service',
    'schedule_oem_service','retrain_endoscopy_staff','none_required'
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

alter table public.nephroscope_qc_capa_actions_r3555 enable row level security;

create index if not exists idx_nephroscope_capa_r3555_log on public.nephroscope_qc_capa_actions_r3555(qc_log_id);
create index if not exists idx_nephroscope_capa_r3555_status on public.nephroscope_qc_capa_actions_r3555(capa_status);

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
  insert into public.nephroscope_qc_r3555 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refval, q.measval, q.devpct, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','NPH-APL-01','Storz 27290 AMA','image_resolution',
     60,59,1.7,true,'2026-07-05','pass','PCNL nephroscope resolution 59 lp/mm within tolerance'),
    ('Apollo Chennai','NPH-APL-02','Olympus OES-4000','light_transmission',
     95,93,2.1,true,'2026-07-05','pass','Light transmission 93 pct nominal post-service'),
    ('Apollo Chennai','NPH-APL-03','Storz 27290 AMA','channel_flow_ml',
     120,118,1.7,true,'2026-07-04','pass','Irrigation channel flow 118 ml/min acceptable'),
    ('Fortis Gurgaon','NPH-FRT-11','Wolf 8968','channel_flow_ml',
     120,92,23.3,false,'2026-07-03','fail','Irrigation channel flow restricted — partial obstruction'),
    ('Fortis Gurgaon','NPH-FRT-12','Storz 27290 AMA','seal_leak_test',
     0,0.8,80.0,false,'2026-07-03','fail','Seal leak 0.8 mbar/min — fluid ingress risk, removed for repair'),
    ('Fortis Gurgaon','NPH-FRT-13','Olympus OES-4000','viewing_angle_deg',
     12,11.4,5.0,true,'2026-07-02','conditional_pass','Viewing angle 11.4 deg slight deviation — monitor'),
    ('Manipal Bengaluru','NPH-MNP-21','Wolf 8968','image_resolution',
     60,48,20.0,false,'2026-07-01','fail','Resolution 48 lp/mm — fiber bundle breakage suspected'),
    ('Manipal Bengaluru','NPH-MNP-22','Storz 27292 Rigid','color_fidelity',
     100,97,3.0,true,'2026-07-01','pass','Color fidelity dE 3.0 within tolerance'),
    ('AIIMS Delhi','NPH-AIM-31','Olympus WA22001A','light_transmission',
     95,82,13.7,false,'2026-06-30','fail','Light transmission 82 pct — light guide degraded'),
    ('AIIMS Delhi','NPH-AIM-32','Storz 27290 AMA','image_resolution',
     60,58,3.3,true,'2026-06-30','pass','Resolution 58 lp/mm within tolerance'),
    ('CMC Vellore','NPH-CMC-41','Wolf 8968','viewing_angle_deg',
     12,12,0.0,true,'2026-06-29','pass','Viewing angle exact at 12 deg'),
    ('CMC Vellore','NPH-CMC-42','Olympus OES-4000','seal_leak_test',
     0,0.3,30.0,false,'2026-06-29','conditional_pass','Minor seal leak 0.3 mbar/min — gasket watch'),
    ('KIMS Hyderabad','NPH-KIM-51','Storz 27290 AMA','channel_flow_ml',
     120,121,0.8,true,'2026-06-28','pass','Channel flow 121 ml/min nominal'),
    ('KIMS Hyderabad','NPH-KIM-52','Storz 27292 Rigid','color_fidelity',
     100,90,10.0,false,'2026-06-28','fail','Color fidelity dE 10 — CCD sensor aging'),
    ('Yashoda Hyderabad','NPH-YSH-61','Olympus WA22001A','image_resolution',
     60,57,5.0,true,'2026-06-27','conditional_pass','Resolution 57 lp/mm borderline — schedule recheck'),
    ('Kokilaben Mumbai','NPH-KKB-71','Wolf 8968','seal_leak_test',
     0,1.2,120.0,false,'2026-06-27','fail','Major seal leak 1.2 mbar/min — sterilization damage, removed from service')
  ) as q(hosp, dcode, dmodel, param, refval, measval, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.nephroscope_qc_capa_actions_r3555 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NPH-FRT-11','channel_flow_restricted','channel_obstruction','clear_channel','in_progress','iso_13485_deviation','2026-07-08',null,9000.00,'Channel flushed and inspected — flow retest pending'),
    ('NPH-FRT-12','seal_leak_detected','seal_gasket_worn','replace_seal_gasket','open','patient_safety_alert','2026-07-07',null,14000.00,'Distal seal gasket replacement kit ordered'),
    ('NPH-MNP-21','image_resolution_degraded','fiber_bundle_broken','repair_fiber_bundle','escalated','cdsco_notifiable','2026-07-06',null,68000.00,'Broken fiber bundle — escalated to Wolf service'),
    ('NPH-AIM-31','light_transmission_loss','light_guide_degraded','replace_light_guide','verification_pending','iso_13485_deviation','2026-07-05',null,42000.00,'Light guide replaced — transmission retest scheduled'),
    ('NPH-KIM-52','color_fidelity_drift','ccd_sensor_aged','replace_ccd_module','open','internal_only','2026-07-10',null,55000.00,'CCD module aging — replacement quote awaited'),
    ('NPH-KKB-71','seal_leak_detected','sterilization_damage','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-30',72000.00,'Scope damaged in autoclave — removed, replacement sourced'),
    ('NPH-CMC-42','seal_leak_detected','seal_gasket_worn','replace_seal_gasket','overdue','internal_only','2026-06-30',null,12000.00,'Gasket replacement past target — vendor delay'),
    ('NPH-FRT-13','viewing_angle_deviation','operator_handling_error','retrain_endoscopy_staff','closed','internal_only','2026-07-04','2026-07-03',0.00,'Angle deviation due to handling — staff retrained')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.nephroscope_qc_r3555 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3555_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nephroscope_qc_r3555)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nephroscope_qc_r3555 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3555_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3555_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3555_device_model_scorecard()
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
  from public.nephroscope_qc_r3555 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3555_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3555_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3555_parameter_verdict_matrix()
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
  from public.nephroscope_qc_r3555 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3555_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3555_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3555_monthly_calibration_trend()
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
  from public.nephroscope_qc_r3555 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3555_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3555_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3555_capa_status_board()
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
  from public.nephroscope_qc_capa_actions_r3555 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3555_capa_status_board() from public, anon;
grant execute on function public.founder_r3555_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3555_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nephroscope_qc_capa_actions_r3555)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nephroscope_qc_capa_actions_r3555 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3555_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3555_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3555_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
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
    count(*) filter (where l.within_tolerance = true)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.nephroscope_qc_r3555 l
  group by l.parameter
  order by round(avg(l.deviation_pct), 2) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3555_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3555_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail concerns)
create or replace function public.founder_r3555_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  reference_value numeric,
  measured_value numeric,
  deviation_pct numeric,
  calibration_date date,
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
  select l.hospital_name, l.device_code, l.device_model, l.parameter,
    l.reference_value, l.measured_value, l.deviation_pct,
    l.calibration_date, l.qc_verdict, l.notes
  from public.nephroscope_qc_r3555 l
  where l.within_tolerance = false
     or l.qc_verdict in ('conditional_pass','fail')
     or (l.parameter = 'seal_leak_test' and l.measured_value > 0)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3555_high_risk_queue() from public, anon;
grant execute on function public.founder_r3555_high_risk_queue() to authenticated;
