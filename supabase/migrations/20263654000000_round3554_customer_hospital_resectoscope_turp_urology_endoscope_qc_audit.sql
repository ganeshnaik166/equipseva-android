-- Round 3554: Customer Hospital Resectoscope (TURP Urology Endoscope) QC Audit
-- Resectoscope TURP QC — parameter × reference vs measured × deviation × tolerance × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: resectoscope_qc_r3554 — per-parameter resectoscope QC checks
-- =============================================================================
create table if not exists public.resectoscope_qc_r3554 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','cutting_loop_current','light_transmission','irrigation_flow_ml','viewing_angle_deg','seal_leak_test'
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

alter table public.resectoscope_qc_r3554 enable row level security;

create index if not exists idx_resectoscope_qc_r3554_org on public.resectoscope_qc_r3554(organization_id);
create index if not exists idx_resectoscope_qc_r3554_caldate on public.resectoscope_qc_r3554(calibration_date);
create index if not exists idx_resectoscope_qc_r3554_verdict on public.resectoscope_qc_r3554(qc_verdict);

-- =============================================================================
-- TABLE 2: resectoscope_qc_capa_actions_r3554 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.resectoscope_qc_capa_actions_r3554 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.resectoscope_qc_r3554(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_resolution_degraded','cutting_loop_current_out_of_tolerance','light_transmission_loss',
    'irrigation_flow_restricted','viewing_angle_deviation','seal_leak_detected',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'fiber_bundle_damaged','lens_fogging_delamination','hf_electrode_worn','loop_insulation_degraded',
    'irrigation_channel_blocked','objective_lens_misaligned','seal_gasket_perished',
    'operator_handling_damage','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_fiber_bundle','replace_optics_module','replace_cutting_loop','recalibrate_hf_generator',
    'clean_flush_irrigation_channel','realign_objective_lens','replace_seal_gasket','retrain_ot_staff',
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

alter table public.resectoscope_qc_capa_actions_r3554 enable row level security;

create index if not exists idx_resectoscope_capa_r3554_log on public.resectoscope_qc_capa_actions_r3554(qc_log_id);
create index if not exists idx_resectoscope_capa_r3554_status on public.resectoscope_qc_capa_actions_r3554(capa_status);

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
  insert into public.resectoscope_qc_r3554 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devpct::numeric, q.wtol,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','RES-APL-01','Karl Storz 27040 SL','image_resolution',
     1080,1076,0.37,true,'2026-07-05','pass','HD resectoscope image resolution within spec'),
    ('Apollo Chennai','RES-APL-01','Karl Storz 27040 SL','light_transmission',
     95,93,2.11,true,'2026-07-05','pass','Fiber-optic light transmission nominal'),
    ('Fortis Mumbai','RES-FRT-11','Olympus OES Pro','cutting_loop_current',
     120,132,10.00,false,'2026-07-04','fail','HF cutting loop current 10% over reference — recalibrate generator'),
    ('Fortis Mumbai','RES-FRT-11','Olympus OES Pro','irrigation_flow_ml',
     300,255,15.00,false,'2026-07-04','conditional_pass','Continuous-flow irrigation restricted 15% — channel flush due'),
    ('Manipal Bengaluru','RES-MNP-21','Richard Wolf 8654','viewing_angle_deg',
     30,30.2,0.67,true,'2026-07-03','pass','30-degree telescope angle within tolerance'),
    ('Manipal Bengaluru','RES-MNP-22','Richard Wolf 8654','seal_leak_test',
     0,0,0,true,'2026-07-03','pass','Leak test passed — no pressure drop'),
    ('AIIMS Delhi','RES-AIM-31','Karl Storz 27040 SL','seal_leak_test',
     0,18,100,false,'2026-07-02','fail','Seal leak detected — 18 mmHg pressure drop, sheath removed'),
    ('AIIMS Delhi','RES-AIM-31','Karl Storz 27040 SL','image_resolution',
     1080,940,12.96,false,'2026-07-02','fail','Image resolution degraded — fiber bundle broken strands'),
    ('CMC Vellore','RES-CMC-41','Olympus OES Pro','light_transmission',
     95,78,17.89,false,'2026-07-01','conditional_pass','Light transmission loss 18% — lens fogging noted'),
    ('CMC Vellore','RES-CMC-41','Olympus OES Pro','cutting_loop_current',
     120,121,0.83,true,'2026-07-01','pass','Cutting loop current within tolerance'),
    ('KIMS Hyderabad','RES-KIM-51','Richard Wolf 8654','irrigation_flow_ml',
     300,298,0.67,true,'2026-06-30','pass','Continuous-flow irrigation nominal'),
    ('KIMS Hyderabad','RES-KIM-52','Karl Storz 27040 SL','viewing_angle_deg',
     12,14.5,20.83,false,'2026-06-30','conditional_pass','Viewing angle deviation on 12-degree scope — objective lens misaligned'),
    ('Yashoda Hyderabad','RES-YSH-61','Olympus OES Pro','image_resolution',
     1080,1078,0.19,true,'2026-06-29','pass','Resolution nominal post-service'),
    ('Kokilaben Mumbai','RES-KKB-71','Richard Wolf 8654','seal_leak_test',
     0,22,100,false,'2026-06-28','fail','Major seal leak — gasket perished, removed from service'),
    ('Kokilaben Mumbai','RES-KKB-72','Karl Storz 27040 SL','cutting_loop_current',
     120,126,5.00,false,'2026-06-28','conditional_pass','Cutting current 5% high — monitor and recalibrate'),
    ('Narayana Bengaluru','RES-NAR-81','Olympus OES Pro','light_transmission',
     95,94,1.05,true,'2026-06-27','pass','Light transmission within spec')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, wtol, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code + parameter
  insert into public.resectoscope_qc_capa_actions_r3554 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('RES-FRT-11','cutting_loop_current','cutting_loop_current_out_of_tolerance','hf_electrode_worn','recalibrate_hf_generator','in_progress','iso_13485_deviation','2026-07-10',null,18000.00,'HF generator recalibrated; verify loop current next case'),
    ('RES-FRT-11','irrigation_flow_ml','irrigation_flow_restricted','irrigation_channel_blocked','clean_flush_irrigation_channel','open','internal_only','2026-07-09',null,3500.00,'Continuous-flow channel flush scheduled'),
    ('RES-AIM-31','seal_leak_test','seal_leak_detected','seal_gasket_perished','replace_seal_gasket','escalated','patient_safety_alert','2026-07-08',null,9500.00,'Sheath seal leak — escalated to OEM for gasket replacement'),
    ('RES-AIM-31','image_resolution','image_resolution_degraded','fiber_bundle_damaged','replace_fiber_bundle','open','cdsco_notifiable','2026-07-12',null,62000.00,'Broken fiber strands — light-cable and bundle replacement quoted'),
    ('RES-CMC-41','light_transmission','light_transmission_loss','lens_fogging_delamination','replace_optics_module','verification_pending','nabh_finding','2026-07-07',null,41000.00,'Optics module replaced — verify transmission on next audit'),
    ('RES-KIM-52','viewing_angle_deg','viewing_angle_deviation','objective_lens_misaligned','realign_objective_lens','closed','internal_only','2026-07-05','2026-07-04',12000.00,'Objective lens realigned and validated'),
    ('RES-KKB-71','seal_leak_test','seal_leak_detected','seal_gasket_perished','remove_from_service','closed','cdsco_notifiable','2026-07-02','2026-06-30',58000.00,'Perished gasket — scope removed, replacement sheath installed'),
    ('RES-KKB-72','cutting_loop_current','cutting_loop_current_out_of_tolerance','loop_insulation_degraded','replace_cutting_loop','overdue','internal_only','2026-07-01',null,2800.00,'Cutting loop replacement past target — vendor delay')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.resectoscope_qc_r3554 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3554_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.resectoscope_qc_r3554)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.resectoscope_qc_r3554 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3554_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3554_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3554_device_model_scorecard()
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
  from public.resectoscope_qc_r3554 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3554_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3554_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3554_parameter_verdict_matrix()
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
  from public.resectoscope_qc_r3554 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3554_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3554_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3554_monthly_accuracy_trend()
returns table(cal_month date, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.calibration_date)::date as cal_month,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.resectoscope_qc_r3554 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3554_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3554_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3554_capa_status_board()
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
  from public.resectoscope_qc_capa_actions_r3554 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3554_capa_status_board() from public, anon;
grant execute on function public.founder_r3554_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3554_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.resectoscope_qc_capa_actions_r3554)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.resectoscope_qc_capa_actions_r3554 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3554_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3554_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3554_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tolerance_count bigint,
  out_of_tolerance_count bigint,
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
  from public.resectoscope_qc_r3554 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3554_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3554_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail)
create or replace function public.founder_r3554_high_risk_queue()
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
  from public.resectoscope_qc_r3554 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3554_high_risk_queue() from public, anon;
grant execute on function public.founder_r3554_high_risk_queue() to authenticated;
