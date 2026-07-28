-- Round 3546: Customer Hospital Hysteroscope (Gynecology Endoscope) QC Audit
-- Hysteroscope imaging + fluid-management QA — device model × QC parameter (image resolution,
-- light transmission, viewing angle, fluid flow, color fidelity, seal leak) × reference vs measured
-- × deviation × tolerance × calibration accuracy trend × CAPA closure.

-- =============================================================================
-- TABLE 1: hysteroscope_qc_r3546 — per-device hysteroscope QC parameter checks
-- =============================================================================
create table if not exists public.hysteroscope_qc_r3546 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'image_resolution','light_transmission','viewing_angle_deg','fluid_flow_ml','color_fidelity','seal_leak_test'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  qc_technician text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hysteroscope_qc_r3546 enable row level security;

create index if not exists idx_hysteroscope_qc_r3546_org on public.hysteroscope_qc_r3546(organization_id);
create index if not exists idx_hysteroscope_qc_r3546_date on public.hysteroscope_qc_r3546(calibration_date);
create index if not exists idx_hysteroscope_qc_r3546_verdict on public.hysteroscope_qc_r3546(qc_verdict);

-- =============================================================================
-- TABLE 2: hysteroscope_qc_capa_actions_r3546 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.hysteroscope_qc_capa_actions_r3546 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.hysteroscope_qc_r3546(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'image_resolution_low','light_transmission_loss','viewing_angle_deviation','fluid_flow_out_of_spec',
    'color_fidelity_drift','seal_leak_detected','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'lens_scratched','fiber_bundle_broken','ccd_sensor_degraded','light_guide_worn','seal_gasket_worn',
    'o_ring_perished','fluid_channel_blocked','operator_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'polish_replace_lens','replace_fiber_bundle','replace_ccd_module','replace_light_guide','replace_seal_gasket',
    'replace_o_ring','flush_fluid_channel','recalibrate_white_balance','retrain_staff','send_oem_service','none_required'
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
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hysteroscope_qc_capa_actions_r3546 enable row level security;

create index if not exists idx_hysteroscope_qc_capa_r3546_log on public.hysteroscope_qc_capa_actions_r3546(qc_log_id);
create index if not exists idx_hysteroscope_qc_capa_r3546_status on public.hysteroscope_qc_capa_actions_r3546(capa_status);

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

  -- 16 QC parameter check rows
  insert into public.hysteroscope_qc_r3546 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    calibration_date, qc_technician, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devp::numeric, q.wtol,
    q.caldate::date, q.tech, q.qv, q.nt
  from (values
    ('Apollo Chennai','HYS-APL-01','Karl Storz Hopkins II','image_resolution',
     1080,1072,0.74,true,'2026-07-05','R. Kumar','pass','4mm rigid hysteroscope resolution within spec'),
    ('Apollo Chennai','HYS-APL-01','Karl Storz Hopkins II','light_transmission',
     100,96.5,3.50,true,'2026-07-05','R. Kumar','pass','Light transmission 96.5% of baseline'),
    ('Apollo Chennai','HYS-APL-02','Olympus HYF-XP','viewing_angle_deg',
     30,30.4,1.33,true,'2026-07-04','R. Kumar','pass','Flexible hysteroscope viewing angle nominal'),
    ('Fortis Gurgaon','HYS-FRT-11','Stryker 1288 HD','fluid_flow_ml',
     350,318,9.14,false,'2026-07-03','S. Mehta','conditional_pass','Fluid inflow reduced — channel partial obstruction suspected'),
    ('Fortis Gurgaon','HYS-FRT-11','Stryker 1288 HD','seal_leak_test',
     200,150,25.00,false,'2026-07-03','S. Mehta','fail','Leak test failed — seal holds only 150 mbar vs 200 mbar reference'),
    ('Fortis Gurgaon','HYS-FRT-12','Richard Wolf Panoview','color_fidelity',
     100,88,12.00,false,'2026-07-02','S. Mehta','fail','Color fidelity delta-E out of spec — white balance drift'),
    ('Manipal Bengaluru','HYS-MNP-21','Karl Storz Hopkins II','image_resolution',
     1080,1068,1.11,true,'2026-07-01','A. Rao','pass','Rigid hysteroscope image resolution pass'),
    ('Manipal Bengaluru','HYS-MNP-21','Karl Storz Hopkins II','light_transmission',
     100,79,21.00,false,'2026-07-01','A. Rao','fail','Light transmission dropped to 79% — fiber bundle damage'),
    ('AIIMS Delhi','HYS-AIM-31','Olympus OTV-S190','viewing_angle_deg',
     30,33.5,11.67,false,'2026-06-30','P. Singh','conditional_pass','Viewing angle deviation 3.5deg — objective realignment needed'),
    ('AIIMS Delhi','HYS-AIM-31','Olympus OTV-S190','color_fidelity',
     100,97,3.00,true,'2026-06-30','P. Singh','pass','Color fidelity within tolerance post white-balance'),
    ('CMC Vellore','HYS-CMC-41','Olympus HYF-XP','fluid_flow_ml',
     350,346,1.14,true,'2026-06-29','J. Thomas','pass','Continuous-flow hysteroscope fluid management nominal'),
    ('CMC Vellore','HYS-CMC-41','Olympus HYF-XP','seal_leak_test',
     200,205,2.50,true,'2026-06-29','J. Thomas','pass','Leak test held above reference pressure'),
    ('KIMS Hyderabad','HYS-KIM-51','Stryker 1288 HD','image_resolution',
     1080,1010,6.48,false,'2026-06-28','M. Reddy','conditional_pass','Resolution reduced — lens surface scratches noted'),
    ('KIMS Hyderabad','HYS-KIM-52','Richard Wolf Panoview','light_transmission',
     100,94,6.00,true,'2026-06-28','M. Reddy','pass','Light transmission acceptable'),
    ('Yashoda Hyderabad','HYS-YSH-61','Karl Storz Hopkins II','seal_leak_test',
     200,120,40.00,false,'2026-06-27','K. Nair','fail','Major seal leak — O-ring perished, sterility risk'),
    ('Kokilaben Mumbai','HYS-KKB-71','Olympus OTV-S190','color_fidelity',
     100,99,1.00,true,'2026-06-27','D. Shah','pass','4K hysteroscope color fidelity pass post-AMC')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devp, wtol, caldate, tech, qv, nt);

  -- CAPA seed — attach to specific checks via (device_code, parameter)
  insert into public.hysteroscope_qc_capa_actions_r3546 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.owner, q.nt
  from (values
    ('HYS-FRT-11','fluid_flow_ml','fluid_flow_out_of_spec','fluid_channel_blocked','flush_fluid_channel','in_progress','internal_only','2026-07-08',null,6500,'S. Mehta','Inflow channel flushed — reverify flow rate next case'),
    ('HYS-FRT-11','seal_leak_test','seal_leak_detected','seal_gasket_worn','replace_seal_gasket','open','patient_safety_alert','2026-07-07',null,12000,'S. Mehta','Seal leak — replacement gasket ordered, scope quarantined'),
    ('HYS-FRT-12','color_fidelity','color_fidelity_drift','ccd_sensor_degraded','recalibrate_white_balance','verification_pending','internal_only','2026-07-06',null,3000,'S. Mehta','White balance recalibrated — verify delta-E next case'),
    ('HYS-MNP-21','light_transmission','light_transmission_loss','fiber_bundle_broken','replace_fiber_bundle','escalated','cdsco_notifiable','2026-07-05',null,85000,'A. Rao','Fiber bundle damage — OEM repair escalated'),
    ('HYS-AIM-31','viewing_angle_deg','viewing_angle_deviation','operator_error','retrain_staff','closed','internal_only','2026-07-03','2026-07-02',0,'P. Singh','Objective realigned and staff retrained on handling'),
    ('HYS-KIM-51','image_resolution','image_resolution_low','lens_scratched','polish_replace_lens','open','nabh_finding','2026-07-04',null,28000,'M. Reddy','Lens scratches — polish vs replace assessment pending'),
    ('HYS-YSH-61','seal_leak_test','seal_leak_detected','o_ring_perished','replace_o_ring','overdue','patient_safety_alert','2026-06-30',null,9500,'K. Nair','Major leak — O-ring replacement past target, vendor delay'),
    ('HYS-MNP-21','image_resolution','preventive_maintenance_due','preventive_service_backlog','send_oem_service','open','iso_13485_deviation','2026-07-09',null,15000,'A. Rao','AMC preventive service due — bundled with fiber-bundle repair')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, owner, nt)
  join public.hysteroscope_qc_r3546 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3546_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hysteroscope_qc_r3546)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hysteroscope_qc_r3546 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3546_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3546_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3546_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  leak_fail bigint,
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
    count(*) filter (where l.parameter = 'seal_leak_test' and l.within_tolerance = false)::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.hysteroscope_qc_r3546 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3546_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3546_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3546_parameter_verdict_matrix()
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.hysteroscope_qc_r3546 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3546_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3546_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3546_monthly_calibration_trend()
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
    round(avg(abs(l.deviation_pct)), 2)
  from public.hysteroscope_qc_r3546 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3546_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3546_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3546_capa_status_board()
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
  from public.hysteroscope_qc_capa_actions_r3546 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3546_capa_status_board() from public, anon;
grant execute on function public.founder_r3546_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3546_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hysteroscope_qc_capa_actions_r3546)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hysteroscope_qc_capa_actions_r3546 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3546_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3546_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (regulatory impact × accuracy)
create or replace function public.founder_r3546_accuracy_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(avg(abs(m.deviation_pct)), 2)
  from public.hysteroscope_qc_capa_actions_r3546 c
  join public.hysteroscope_qc_r3546 m on m.id = c.qc_log_id
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3546_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3546_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / leak-fail concerns)
create or replace function public.founder_r3546_high_risk_queue()
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
  from public.hysteroscope_qc_r3546 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or (l.parameter = 'seal_leak_test' and l.within_tolerance = false)
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3546_high_risk_queue() from public, anon;
grant execute on function public.founder_r3546_high_risk_queue() to authenticated;
