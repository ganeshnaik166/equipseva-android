-- Round 3586: Customer Hospital CyberKnife Robotic Radiosurgery QC Audit
-- CyberKnife robotic-arm linac QC — parameter (beam output / targeting / tracking latency / MU linearity /
-- isocenter accuracy / collimator size) × device model × reference vs measured × deviation × tolerance × CAPA

-- =============================================================================
-- TABLE 1: cyberknife_qc_r3586 — per-device robotic-radiosurgery QC checks
-- =============================================================================
create table if not exists public.cyberknife_qc_r3586 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'beam_output_cgy_mu','targeting_accuracy_mm','tracking_latency_ms',
    'mu_linearity','isocenter_accuracy_mm','collimator_size_mm'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  tolerance_pct numeric(6,2),
  within_tolerance boolean not null,
  calibration_date date not null,
  calibration_current boolean not null,
  physicist text,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cyberknife_qc_r3586 enable row level security;

create index if not exists idx_cyberknife_qc_r3586_org on public.cyberknife_qc_r3586(organization_id);
create index if not exists idx_cyberknife_qc_r3586_date on public.cyberknife_qc_r3586(calibration_date);
create index if not exists idx_cyberknife_qc_r3586_verdict on public.cyberknife_qc_r3586(qc_verdict);

-- =============================================================================
-- TABLE 2: cyberknife_qc_capa_actions_r3586 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cyberknife_qc_capa_actions_r3586 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cyberknife_qc_r3586(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'beam_output_out_of_tolerance','targeting_accuracy_out_of_tolerance','tracking_latency_excess',
    'mu_linearity_deviation','isocenter_accuracy_out_of_tolerance','collimator_size_error',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'beam_energy_drift','robotic_arm_calibration_drift','imaging_system_misalignment',
    'tracking_algorithm_latency','monitor_chamber_drift','collimator_mechanical_wear',
    'software_config_error','operator_setup_error','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_beam_output','recalibrate_robotic_arm','realign_imaging_system','update_tracking_software',
    'replace_monitor_chamber','service_collimator_assembly','update_software_config','retrain_physics_staff',
    'remove_from_clinical_use','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'aerb_notifiable','aerb_finding','nabh_finding','iso_13485_deviation',
    'patient_safety_alert','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cyberknife_qc_capa_actions_r3586 enable row level security;

create index if not exists idx_cyberknife_capa_r3586_log on public.cyberknife_qc_capa_actions_r3586(qc_log_id);
create index if not exists idx_cyberknife_capa_r3586_status on public.cyberknife_qc_capa_actions_r3586(capa_status);

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
  insert into public.cyberknife_qc_r3586 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, tolerance_pct, within_tolerance,
    calibration_date, calibration_current, physicist, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv::numeric, q.measv::numeric, q.devpct::numeric, q.tolpct::numeric, q.wtol,
    q.caldate::date, q.calcur, q.phys, q.qv, q.nt
  from (values
    ('Apollo Chennai','CK-APL-01','CyberKnife S7','beam_output_cgy_mu',
     1.000,0.998,0.20,2.00,true,'2026-07-05',true,'Dr R Nair','pass','Daily output within TG-51 2% tolerance'),
    ('Apollo Chennai','CK-APL-01','CyberKnife S7','targeting_accuracy_mm',
     0.50,0.42,16.00,90.00,true,'2026-07-05',true,'Dr R Nair','pass','End-to-end targeting 0.42 mm, under 0.95 mm limit'),
    ('Tata Memorial Mumbai','CK-TMH-11','CyberKnife M6','tracking_latency_ms',
     115.0,118.0,2.61,5.00,true,'2026-07-04',true,'Dr S Iyer','pass','Synchrony respiratory tracking latency within spec'),
    ('Tata Memorial Mumbai','CK-TMH-11','CyberKnife M6','mu_linearity',
     1.000,1.004,0.40,1.00,true,'2026-07-04',true,'Dr S Iyer','pass','MU linearity across 5-500 MU nominal'),
    ('HCG Bangalore','CK-HCG-21','CyberKnife VSI','isocenter_accuracy_mm',
     0.30,0.55,83.33,66.67,false,'2026-07-03',true,'Dr P Rao','conditional_pass','Winston-Lutz isocenter 0.55 mm above action level'),
    ('HCG Bangalore','CK-HCG-21','CyberKnife VSI','beam_output_cgy_mu',
     1.000,0.975,2.50,2.00,false,'2026-07-03',true,'Dr P Rao','fail','Output 2.5% low — exceeds 2% tolerance, recal required'),
    ('AIIMS Delhi','CK-AIM-31','CyberKnife G4','collimator_size_mm',
     10.00,10.35,3.50,2.00,false,'2026-06-28',false,'Dr M Gupta','fail','Iris 10 mm field 3.5% oversize and calibration overdue'),
    ('AIIMS Delhi','CK-AIM-31','CyberKnife G4','targeting_accuracy_mm',
     0.50,1.10,120.00,90.00,false,'2026-06-28',false,'Dr M Gupta','fail','Total targeting error 1.10 mm exceeds 0.95 mm limit'),
    ('Fortis Mohali','CK-FRT-41','CyberKnife M6','tracking_latency_ms',
     115.0,132.0,14.78,5.00,false,'2026-06-27',true,'Dr A Singh','conditional_pass','Tracking latency 132 ms elevated — model update advised'),
    ('Fortis Mohali','CK-FRT-41','CyberKnife M6','mu_linearity',
     1.000,1.002,0.20,1.00,true,'2026-06-27',true,'Dr A Singh','pass','MU linearity nominal'),
    ('Manipal Bengaluru','CK-MNP-51','CyberKnife S7','beam_output_cgy_mu',
     1.000,1.006,0.60,2.00,true,'2026-06-25',true,'Dr K Menon','pass','Daily output constancy pass'),
    ('Manipal Bengaluru','CK-MNP-51','CyberKnife S7','isocenter_accuracy_mm',
     0.30,0.28,6.67,66.67,true,'2026-06-25',true,'Dr K Menon','pass','Winston-Lutz isocenter 0.28 mm excellent'),
    ('Yashoda Hyderabad','CK-YSH-61','CyberKnife VSI','collimator_size_mm',
     15.00,15.10,0.67,2.00,true,'2026-06-24',true,'Dr V Reddy','pass','Fixed 15 mm collimator field size verified'),
    ('Yashoda Hyderabad','CK-YSH-61','CyberKnife VSI','mu_linearity',
     1.000,0.985,1.50,1.00,false,'2026-06-24',true,'Dr V Reddy','conditional_pass','MU linearity 1.5% deviation at low MU — monitor'),
    ('Amrita Kochi','CK-AMR-71','CyberKnife G4','beam_output_cgy_mu',
     1.000,0.960,4.00,2.00,false,'2026-06-22',false,'Dr N Pillai','fail','Output 4% low, monitor chamber suspect, unit down for service')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, tolpct, wtol, caldate, calcur, phys, qv, nt);

  -- CAPA seed — attach to specific checks via device_code + parameter
  insert into public.cyberknife_qc_capa_actions_r3586 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('CK-HCG-21','beam_output_cgy_mu','beam_output_out_of_tolerance','beam_energy_drift','recalibrate_beam_output','in_progress','aerb_finding','2026-07-08',null,45000.00,'Beam output 2.5% low — TG-51 recalibration scheduled'),
    ('CK-AIM-31','targeting_accuracy_mm','targeting_accuracy_out_of_tolerance','robotic_arm_calibration_drift','recalibrate_robotic_arm','escalated','patient_safety_alert','2026-07-02',null,120000.00,'Targeting 1.10 mm — robotic arm recalibration, cases held'),
    ('CK-AIM-31','collimator_size_mm','collimator_size_error','collimator_mechanical_wear','service_collimator_assembly','open','aerb_notifiable','2026-07-04',null,68000.00,'Iris collimator oversize plus calibration overdue — OEM service raised'),
    ('CK-AMR-71','beam_output_cgy_mu','beam_output_out_of_tolerance','monitor_chamber_drift','replace_monitor_chamber','escalated','aerb_notifiable','2026-06-30',null,210000.00,'Output 4% low, monitor chamber replacement — unit down'),
    ('CK-FRT-41','tracking_latency_ms','tracking_latency_excess','tracking_algorithm_latency','update_tracking_software','verification_pending','iso_13485_deviation','2026-07-01',null,15000.00,'Synchrony tracking model rebuilt — verify latency next QA'),
    ('CK-HCG-21','isocenter_accuracy_mm','isocenter_accuracy_out_of_tolerance','imaging_system_misalignment','realign_imaging_system','closed','internal_only','2026-07-06','2026-07-05',22000.00,'kV imaging realigned, Winston-Lutz 0.55 to 0.30 mm verified'),
    ('CK-YSH-61','mu_linearity','mu_linearity_deviation','software_config_error','update_software_config','open','internal_only','2026-07-05',null,5000.00,'Low-MU linearity flag — dose-rate config review'),
    ('CK-MNP-51','beam_output_cgy_mu','preventive_maintenance_due','preventive_service_backlog','schedule_oem_service','overdue','none','2026-07-10',null,30000.00,'Annual OEM PM past target date — vendor scheduling')
  ) as q(dcode, param, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cyberknife_qc_r3586 e
    on e.organization_id = v_org_id and e.device_code = q.dcode and e.parameter = q.param;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3586_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cyberknife_qc_r3586)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cyberknife_qc_r3586 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3586_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3586_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3586_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  calibration_overdue bigint,
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
    count(*) filter (where l.calibration_current = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cyberknife_qc_r3586 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3586_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3586_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3586_parameter_verdict_matrix()
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
  from public.cyberknife_qc_r3586 l
  group by l.parameter, l.qc_verdict
  order by l.parameter, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3586_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3586_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration/accuracy trend
create or replace function public.founder_r3586_monthly_qc_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.calibration_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cyberknife_qc_r3586 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3586_monthly_qc_trend() from public, anon;
grant execute on function public.founder_r3586_monthly_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3586_capa_status_board()
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
  from public.cyberknife_qc_capa_actions_r3586 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3586_capa_status_board() from public, anon;
grant execute on function public.founder_r3586_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3586_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cyberknife_qc_capa_actions_r3586)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cyberknife_qc_capa_actions_r3586 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3586_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3586_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory impact digest
create or replace function public.founder_r3586_accuracy_impact_digest()
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
  from public.cyberknife_qc_capa_actions_r3586 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3586_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3586_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3586_high_risk_queue()
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
  from public.cyberknife_qc_r3586 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3586_high_risk_queue() from public, anon;
grant execute on function public.founder_r3586_high_risk_queue() to authenticated;
