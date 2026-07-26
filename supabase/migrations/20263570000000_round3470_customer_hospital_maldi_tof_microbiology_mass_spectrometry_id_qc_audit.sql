-- Round 3470: Customer Hospital MALDI-TOF Microbiology Mass-Spectrometry (Organism ID) QC Audit
-- MALDI-TOF microbiology mass-spectrometry organism-ID QA — parameter × device model × mass accuracy × laser energy × resolution × calibrant score × vacuum × ID confidence × tolerance × calibration currency × CAPA

-- =============================================================================
-- TABLE 1: maldi_tof_qc_r3470 — per-parameter MALDI-TOF organism-ID QC checks
-- =============================================================================
create table if not exists public.maldi_tof_qc_r3470 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null check (device_model in (
    'bruker_biotyper_sirius','biomerieux_vitek_ms','biomerieux_vitek_ms_prime',
    'autobio_autof_ms1000','zybio_ex_s2600'
  )),
  parameter text not null check (parameter in (
    'mass_accuracy_ppm','laser_energy_pct','resolution_fwhm','calibrant_score','vacuum_mbar','id_confidence_pct'
  )),
  reference_value numeric(12,4) not null,
  measured_value numeric(12,4) not null,
  deviation_pct numeric(7,2) not null,
  tolerance_limit_pct numeric(7,2) not null,
  within_tolerance boolean not null,
  calibrant_lot text,
  spectra_quality text not null check (spectra_quality in (
    'excellent','good','fair','poor'
  )),
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.maldi_tof_qc_r3470 enable row level security;

create index if not exists idx_maldi_tof_qc_r3470_org on public.maldi_tof_qc_r3470(organization_id);
create index if not exists idx_maldi_tof_qc_r3470_date on public.maldi_tof_qc_r3470(calibration_date);
create index if not exists idx_maldi_tof_qc_r3470_verdict on public.maldi_tof_qc_r3470(qc_verdict);

-- =============================================================================
-- TABLE 2: maldi_tof_qc_capa_actions_r3470 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.maldi_tof_qc_capa_actions_r3470 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.maldi_tof_qc_r3470(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'mass_accuracy_out_of_tolerance','laser_energy_low','resolution_degraded','calibrant_score_low',
    'vacuum_out_of_range','id_confidence_low','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'detector_aging','laser_source_degraded','calibrant_expired','vacuum_pump_fault',
    'ion_source_contamination','software_config_error','operator_prep_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_instrument','replace_calibrant','service_laser_source','service_vacuum_pump',
    'clean_ion_source','replace_detector','update_software_config','retrain_lab_staff',
    'schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.maldi_tof_qc_capa_actions_r3470 enable row level security;

create index if not exists idx_maldi_tof_capa_r3470_log on public.maldi_tof_qc_capa_actions_r3470(qc_log_id);
create index if not exists idx_maldi_tof_capa_r3470_status on public.maldi_tof_qc_capa_actions_r3470(capa_status);

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
  insert into public.maldi_tof_qc_r3470 (
    organization_id, hospital_name, device_code, device_model, parameter,
    reference_value, measured_value, deviation_pct, tolerance_limit_pct, within_tolerance,
    calibrant_lot, spectra_quality, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.param,
    q.refv, q.measv, q.devpct, q.tolpct, q.wtol,
    q.clot, q.spq, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','MTOF-APL-01','bruker_biotyper_sirius','mass_accuracy_ppm',
     5.0,2.1,1.2,3.0,true,'CAL-BTS-2601','excellent','2026-07-05',true,'pass','Bruker Biotyper Sirius mass accuracy within tolerance; calibrant nominal'),
    ('Apollo Chennai','MTOF-APL-01','bruker_biotyper_sirius','id_confidence_pct',
     99.9,99.4,0.5,2.0,true,'CAL-BTS-2601','excellent','2026-07-05',true,'pass','Organism ID confidence high across daily QC reference panel'),
    ('Fortis Gurgaon','MTOF-FRT-11','biomerieux_vitek_ms','calibrant_score',
     2.0,1.75,12.5,10.0,false,'VMS-LOT-0442','good','2026-07-04',true,'conditional_pass','VITEK MS calibrant (E. coli) score below 2.0 target — recalibrate'),
    ('Fortis Gurgaon','MTOF-FRT-12','biomerieux_vitek_ms','laser_energy_pct',
     100.0,82.0,18.0,10.0,false,'VMS-LOT-0442','fair','2026-07-04',true,'fail','Laser energy dropped to 82 pct — laser source degradation suspected'),
    ('Manipal Bengaluru','MTOF-MNP-21','biomerieux_vitek_ms_prime','resolution_fwhm',
     8000.0,6200.0,22.5,12.0,false,'VMSP-LOT-0330','poor','2026-06-28',false,'fail','Resolution FWHM degraded and calibration overdue — flagged for OEM service'),
    ('Manipal Bengaluru','MTOF-MNP-22','biomerieux_vitek_ms_prime','vacuum_mbar',
     3.0,3.1,3.3,15.0,true,'VMSP-LOT-0331','good','2026-06-28',true,'pass','Source vacuum within range (x10^-7 mbar); QC nominal'),
    ('AIIMS Delhi','MTOF-AIM-31','bruker_biotyper_sirius','mass_accuracy_ppm',
     5.0,4.6,2.4,3.0,true,'CAL-BTS-2607','good','2026-06-30',true,'conditional_pass','Mass accuracy trending toward limit — monitor at next calibration'),
    ('AIIMS Delhi','MTOF-AIM-32','autobio_autof_ms1000','id_confidence_pct',
     99.9,91.0,8.9,5.0,false,'AF-LOT-1180','fair','2026-06-30',true,'fail','Autof MS1000 ID confidence low on gram-negative panel — reprep and recalibrate'),
    ('CMC Vellore','MTOF-CMC-41','bruker_biotyper_sirius','calibrant_score',
     2.0,2.15,1.0,10.0,true,'CAL-BTS-2605','excellent','2026-06-27',true,'pass','Bruker BTS calibrant score above 2.0 — pass'),
    ('CMC Vellore','MTOF-CMC-42','zybio_ex_s2600','laser_energy_pct',
     100.0,96.0,4.0,10.0,true,'ZY-LOT-0088','good','2026-06-27',true,'pass','Zybio EXS2600 laser energy nominal'),
    ('KIMS Hyderabad','MTOF-KIM-51','biomerieux_vitek_ms','vacuum_mbar',
     3.0,4.2,40.0,15.0,false,'VMS-LOT-0501','poor','2026-05-30',false,'fail','Vacuum out of range — turbo pump fault suspected, calibration overdue'),
    ('KIMS Hyderabad','MTOF-KIM-52','biomerieux_vitek_ms','resolution_fwhm',
     8000.0,7600.0,5.0,12.0,true,'VMS-LOT-0501','good','2026-05-30',true,'pass','Resolution FWHM within tolerance post-service'),
    ('Yashoda Hyderabad','MTOF-YSH-61','autobio_autof_ms1000','mass_accuracy_ppm',
     5.0,3.2,1.8,3.0,true,'AF-LOT-1190','good','2026-05-22',true,'pass','Autof MS1000 mass accuracy within spec'),
    ('Yashoda Hyderabad','MTOF-YSH-62','autobio_autof_ms1000','calibrant_score',
     2.0,1.9,5.0,10.0,true,'AF-LOT-1190','good','2026-05-22',true,'conditional_pass','Calibrant score marginal but acceptable — recheck scheduled'),
    ('Kokilaben Mumbai','MTOF-KKB-71','zybio_ex_s2600','id_confidence_pct',
     99.9,88.0,11.9,5.0,false,'ZY-LOT-0090','poor','2026-05-18',false,'fail','ID confidence low with poor spectra and overdue calibration — removed from routine'),
    ('Kokilaben Mumbai','MTOF-KKB-72','zybio_ex_s2600','vacuum_mbar',
     3.0,3.0,0.0,15.0,true,'ZY-LOT-0090','excellent','2026-05-18',true,'pass','Vacuum nominal on secondary analyser')
  ) as q(hosp, dcode, dmodel, param, refv, measv, devpct, tolpct, wtol, clot, spq, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.maldi_tof_qc_capa_actions_r3470 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MTOF-FRT-11','calibrant_score_low','calibrant_expired','replace_calibrant','in_progress','iso_15189_deviation','2026-07-08',null,6500.00,'VITEK MS calibrant lot expired — fresh lot loaded, verifying score'),
    ('MTOF-FRT-12','laser_energy_low','laser_source_degraded','service_laser_source','escalated','cdsco_notifiable','2026-07-10',null,185000.00,'Laser energy at 82 pct — OEM laser module service escalated'),
    ('MTOF-MNP-21','resolution_degraded','detector_aging','replace_detector','open','iso_15189_deviation','2026-07-12',null,240000.00,'FWHM resolution degraded with overdue calibration — detector replacement quoted'),
    ('MTOF-AIM-32','id_confidence_low','operator_prep_error','retrain_lab_staff','verification_pending','internal_only','2026-07-06',null,3000.00,'Target plate prep error — staff retrained, verifying ID confidence'),
    ('MTOF-KIM-51','vacuum_out_of_range','vacuum_pump_fault','service_vacuum_pump','escalated','nabl_finding','2026-07-09',null,95000.00,'Turbo pump fault — vacuum out of range, OEM service escalated'),
    ('MTOF-KKB-71','id_confidence_low','ion_source_contamination','clean_ion_source','closed','nabh_finding','2026-07-02','2026-06-25',12000.00,'Ion source cleaned and recalibrated — ID confidence restored'),
    ('MTOF-YSH-62','calibration_overdue','calibrant_expired','replace_calibrant','closed','internal_only','2026-05-28','2026-05-24',6500.00,'Calibrant refreshed on schedule — score restored'),
    ('MTOF-AIM-31','mass_accuracy_out_of_tolerance','detector_aging','recalibrate_instrument','open','internal_only','2026-07-07',null,0.00,'Mass accuracy drift monitored — recalibration scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.maldi_tof_qc_r3470 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3470_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.maldi_tof_qc_r3470)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.maldi_tof_qc_r3470 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3470_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3470_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3470_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
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
  select l.device_model,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.maldi_tof_qc_r3470 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3470_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3470_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3470_parameter_verdict_matrix()
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
  from public.maldi_tof_qc_r3470 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3470_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3470_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3470_monthly_accuracy_trend()
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
  from public.maldi_tof_qc_r3470 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3470_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3470_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3470_capa_status_board()
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
  from public.maldi_tof_qc_capa_actions_r3470 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3470_capa_status_board() from public, anon;
grant execute on function public.founder_r3470_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3470_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.maldi_tof_qc_capa_actions_r3470)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.maldi_tof_qc_capa_actions_r3470 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3470_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3470_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (per-parameter deviation impact)
create or replace function public.founder_r3470_accuracy_impact_digest()
returns table(parameter text, checks bigint, out_of_tolerance bigint, failed bigint, avg_deviation_pct numeric, max_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.parameter, count(*)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(max(l.deviation_pct), 2)
  from public.maldi_tof_qc_r3470 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3470_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3470_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed checks)
create or replace function public.founder_r3470_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  measured_value numeric,
  deviation_pct numeric,
  spectra_quality text,
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
    l.qc_verdict, l.measured_value, l.deviation_pct, l.spectra_quality, l.notes
  from public.maldi_tof_qc_r3470 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
     or l.spectra_quality in ('fair','poor')
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3470_high_risk_queue() from public, anon;
grant execute on function public.founder_r3470_high_risk_queue() to authenticated;
