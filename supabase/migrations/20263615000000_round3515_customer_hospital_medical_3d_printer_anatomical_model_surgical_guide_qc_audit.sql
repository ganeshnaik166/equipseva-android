-- Round 3515: Customer Hospital Medical 3D-Printer (Anatomical-Model / Surgical-Guide) QC Audit
-- Hospital medical 3D printer (anatomical models / surgical guides) QC — dimensional accuracy, layer resolution,
-- XY accuracy, build repeatability, material density, warpage × tolerance × verdict × calibration × CAPA

-- =============================================================================
-- TABLE 1: med_3d_printer_qc_r3515 — per-parameter 3D-printer QC measurements
-- =============================================================================
create table if not exists public.med_3d_printer_qc_r3515 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  parameter text not null check (parameter in (
    'dimensional_accuracy_mm','layer_resolution_um','xy_accuracy_mm','build_repeatability','material_density','warpage_mm'
  )),
  print_technology text not null check (print_technology in (
    'sla','dlp','fdm','sls','material_jetting','polyjet'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  tolerance_band_pct numeric(6,2),
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.med_3d_printer_qc_r3515 enable row level security;

create index if not exists idx_med_3d_printer_qc_r3515_org on public.med_3d_printer_qc_r3515(organization_id);
create index if not exists idx_med_3d_printer_qc_r3515_date on public.med_3d_printer_qc_r3515(calibration_date);
create index if not exists idx_med_3d_printer_qc_r3515_verdict on public.med_3d_printer_qc_r3515(qc_verdict);

-- =============================================================================
-- TABLE 2: med_3d_printer_qc_capa_actions_r3515 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.med_3d_printer_qc_capa_actions_r3515 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.med_3d_printer_qc_r3515(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dimensional_accuracy_out_of_tolerance','layer_resolution_degraded','xy_accuracy_drift',
    'build_repeatability_failure','material_density_deviation','warpage_excessive',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'printer_axis_miscalibration','worn_build_platform','resin_material_degraded','laser_galvo_drift',
    'nozzle_extruder_wear','thermal_warpage','software_slicer_config_error','operator_setup_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_axes','replace_build_platform','replace_resin_material','realign_laser_galvo',
    'replace_nozzle_extruder','adjust_thermal_settings','update_slicer_config','retrain_biomedical_staff',
    'quarantine_printer','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.med_3d_printer_qc_capa_actions_r3515 enable row level security;

create index if not exists idx_med_3d_printer_capa_r3515_log on public.med_3d_printer_qc_capa_actions_r3515(qc_log_id);
create index if not exists idx_med_3d_printer_capa_r3515_status on public.med_3d_printer_qc_capa_actions_r3515(capa_status);

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

  -- 16 QC measurement rows
  insert into public.med_3d_printer_qc_r3515 (
    organization_id, hospital_name, device_code, device_model, parameter, print_technology,
    reference_value, measured_value, deviation_pct, within_tolerance, tolerance_band_pct,
    calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param, q.tech,
    q.rv, q.mv, q.dev, q.wt, q.tb,
    q.cd::date, q.cc, q.qv, q.nt
  from (values
    ('Apollo Chennai','3DP-APL-01','Formlabs Form 3B+','dimensional_accuracy_mm','sla',
     50.000,50.080,0.16,true,0.50,'2026-07-05',true,'pass','Skull anatomical model within +/-0.5% dimensional tolerance'),
    ('Apollo Chennai','3DP-APL-02','Stratasys J5 MediJet','layer_resolution_um','polyjet',
     27.000,28.000,3.70,true,5.00,'2026-07-05',true,'pass','Surgical guide layer resolution within spec'),
    ('Apollo Chennai','3DP-APL-03','3D Systems ProJet','material_density','material_jetting',
     1.180,1.185,0.42,true,1.00,'2026-07-05',true,'pass','Material density of guide resin within tolerance'),
    ('Fortis Gurgaon','3DP-FRT-11','Formlabs Form 3B+','xy_accuracy_mm','sla',
     25.000,25.220,0.88,false,0.50,'2026-07-04',true,'conditional_pass','XY accuracy drift beyond band on cranial guide — monitor'),
    ('Fortis Gurgaon','3DP-FRT-12','EnvisionTEC Vida','dimensional_accuracy_mm','dlp',
     40.000,41.400,3.50,false,1.00,'2026-07-04',false,'fail','Dental surgical guide oversized 3.5% and calibration overdue'),
    ('Fortis Gurgaon','3DP-FRT-13','Ultimaker S5','warpage_mm','fdm',
     0.300,0.520,73.33,false,null,'2026-07-04',true,'fail','Excessive warpage 0.52mm on mandible model exceeds 0.3mm limit'),
    ('Manipal Bengaluru','3DP-MNP-21','Ultimaker S5','build_repeatability','fdm',
     100.000,96.500,3.50,false,2.00,'2026-07-03',true,'fail','FDM anatomical model build repeatability failure across batch'),
    ('Manipal Bengaluru','3DP-MNP-22','Formlabs Form 3B+','warpage_mm','sla',
     0.300,0.180,-40.00,true,null,'2026-07-03',true,'pass','Minor warpage 0.18mm within 0.3mm limit on maxilla model'),
    ('Manipal Bengaluru','3DP-MNP-23','Stratasys J5 MediJet','layer_resolution_um','polyjet',
     27.000,27.400,1.48,true,5.00,'2026-07-03',true,'pass','PolyJet layer resolution nominal on surgical guide'),
    ('AIIMS Delhi','3DP-AIM-31','EOS P 110','material_density','sls',
     0.950,0.910,-4.21,false,3.00,'2026-07-02',true,'conditional_pass','SLS nylon model density low 4.2% — infill review'),
    ('AIIMS Delhi','3DP-AIM-32','Formlabs Form 3B+','dimensional_accuracy_mm','sla',
     60.000,60.150,0.25,true,0.50,'2026-07-02',true,'pass','Vertebra anatomical model dimensional accuracy pass'),
    ('AIIMS Delhi','3DP-AIM-33','3D Systems ProJet','xy_accuracy_mm','material_jetting',
     30.000,30.900,3.00,false,1.00,'2026-07-02',false,'fail','XY accuracy out of tolerance and calibration overdue on guide printer'),
    ('CMC Vellore','3DP-CMC-41','Ultimaker S5','layer_resolution_um','fdm',
     100.000,108.000,8.00,false,5.00,'2026-07-01',true,'conditional_pass','FDM layer resolution coarse 8% — nozzle inspection'),
    ('CMC Vellore','3DP-CMC-42','EnvisionTEC Vida','dimensional_accuracy_mm','dlp',
     45.000,45.090,0.20,true,1.00,'2026-07-01',true,'pass','DLP dental guide dimensional accuracy within tolerance'),
    ('KIMS Hyderabad','3DP-KIM-51','Formlabs Form 3B+','build_repeatability','sla',
     100.000,99.400,0.60,true,2.00,'2026-06-30',true,'pass','SLA build repeatability within limit post-AMC'),
    ('Kokilaben Mumbai','3DP-KKB-61','EOS P 110','warpage_mm','sls',
     0.300,0.680,126.67,false,null,'2026-06-29',false,'fail','Severe warpage 0.68mm on pelvis model, calibration overdue — printer quarantined')
  ) as q(hosp, dcode, dmodel, param, tech, rv, mv, dev, wt, tb, cd, cc, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.med_3d_printer_qc_capa_actions_r3515 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('3DP-FRT-12','dimensional_accuracy_out_of_tolerance','printer_axis_miscalibration','recalibrate_axes','in_progress','iso_13485_deviation','Biomed Team','2026-07-08',null,18000.00,'Dental guide oversized — axes recalibration in progress'),
    ('3DP-FRT-13','warpage_excessive','thermal_warpage','adjust_thermal_settings','open','nabh_finding','Priya Nair','2026-07-07',null,9500.00,'Mandible warpage — chamber thermal profile adjustment planned'),
    ('3DP-MNP-21','build_repeatability_failure','nozzle_extruder_wear','replace_nozzle_extruder','verification_pending','internal_only','Rahul Menon','2026-07-06',null,6500.00,'Extruder nozzle replaced — verifying repeatability next batch'),
    ('3DP-AIM-31','material_density_deviation','resin_material_degraded','replace_resin_material','closed','internal_only','Biomed Team','2026-07-05','2026-07-04',22000.00,'SLS nylon powder lot replaced — density restored'),
    ('3DP-AIM-33','xy_accuracy_drift','laser_galvo_drift','realign_laser_galvo','escalated','cdsco_notifiable','Vendor OEM','2026-07-06',null,41000.00,'XY accuracy fail with calibration overdue — escalated to OEM'),
    ('3DP-CMC-41','layer_resolution_degraded','software_slicer_config_error','update_slicer_config','open','none','Anitha R','2026-07-09',null,0.00,'Slicer layer-height profile corrected — reprint scheduled'),
    ('3DP-KKB-61','warpage_excessive','printer_axis_miscalibration','quarantine_printer','escalated','patient_safety_alert','Biomed Team','2026-07-04',null,55000.00,'Severe warpage, printer quarantined pending OEM service'),
    ('3DP-FRT-11','xy_accuracy_drift','printer_axis_miscalibration','recalibrate_axes','overdue','internal_only','Biomed Team','2026-07-02',null,12000.00,'XY drift on cranial guide printer — recalibration past target date')
  ) as q(dcode, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.med_3d_printer_qc_r3515 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3515_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.med_3d_printer_qc_r3515)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.med_3d_printer_qc_r3515 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3515_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3515_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3515_device_model_scorecard()
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
  from public.med_3d_printer_qc_r3515 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3515_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3515_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3515_parameter_verdict_matrix()
returns table(parameter text, qc_verdict text, checks bigint, avg_deviation_pct numeric, out_of_tolerance bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    count(*) filter (where l.within_tolerance = false)::bigint
  from public.med_3d_printer_qc_r3515 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3515_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3515_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3515_monthly_accuracy_trend()
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
  from public.med_3d_printer_qc_r3515 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3515_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3515_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3515_capa_status_board()
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
  from public.med_3d_printer_qc_capa_actions_r3515 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3515_capa_status_board() from public, anon;
grant execute on function public.founder_r3515_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3515_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.med_3d_printer_qc_capa_actions_r3515)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.med_3d_printer_qc_capa_actions_r3515 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3515_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3515_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per parameter)
create or replace function public.founder_r3515_accuracy_impact_digest()
returns table(parameter text, checks bigint, avg_deviation_pct numeric, max_deviation_pct numeric, out_of_tolerance bigint, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2),
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint
  from public.med_3d_printer_qc_r3515 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3515_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3515_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed / calibration overdue)
create or replace function public.founder_r3515_high_risk_queue()
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
  from public.med_3d_printer_qc_r3515 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3515_high_risk_queue() from public, anon;
grant execute on function public.founder_r3515_high_risk_queue() to authenticated;
