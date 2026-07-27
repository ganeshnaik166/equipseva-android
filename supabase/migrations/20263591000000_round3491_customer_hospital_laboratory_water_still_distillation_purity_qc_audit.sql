-- Round 3491: Customer Hospital Laboratory Water-Still / Distillation Purity QC Audit
-- Lab water still / distillation unit QC — parameter x measured-vs-reference x deviation x tolerance x calibration x verdict x CAPA

-- =============================================================================
-- TABLE 1: water_still_qc_r3491 — per-parameter water-still purity QC checks
-- =============================================================================
create table if not exists public.water_still_qc_r3491 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  lab_section text not null check (lab_section in (
    'microbiology','biochemistry','pathology','molecular','central_lab'
  )),
  parameter text not null check (parameter in (
    'conductivity_us','resistivity_mohm','toc_ppb','output_rate_lph','ph','bacterial_cfu'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(7,2),
  within_tolerance boolean not null,
  sample_point text not null check (sample_point in (
    'outlet','storage_tank','distribution_loop','point_of_use'
  )),
  test_date date not null,
  calibration_date date,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.water_still_qc_r3491 enable row level security;

create index if not exists idx_water_still_qc_r3491_org on public.water_still_qc_r3491(organization_id);
create index if not exists idx_water_still_qc_r3491_date on public.water_still_qc_r3491(test_date);
create index if not exists idx_water_still_qc_r3491_verdict on public.water_still_qc_r3491(qc_verdict);

-- =============================================================================
-- TABLE 2: water_still_qc_capa_actions_r3491 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.water_still_qc_capa_actions_r3491 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.water_still_qc_r3491(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'conductivity_out_of_spec','resistivity_low','toc_high','output_rate_low',
    'ph_out_of_range','bacterial_contamination','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'resin_bed_exhausted','membrane_fouling','heater_element_scaling','condenser_scaling',
    'feed_water_quality','sensor_drift','operator_setup_error','pending_investigation',
    'preventive_service_backlog','storage_tank_contamination'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_resin_bed','descale_boiler_condenser','replace_membrane','sanitize_system',
    'recalibrate_sensor','flush_distribution_loop','retrain_lab_staff','remove_from_service',
    'schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','nabh_finding','cdsco_notifiable','none','internal_only',
    'iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.water_still_qc_capa_actions_r3491 enable row level security;

create index if not exists idx_water_still_capa_r3491_log on public.water_still_qc_capa_actions_r3491(qc_log_id);
create index if not exists idx_water_still_capa_r3491_status on public.water_still_qc_capa_actions_r3491(capa_status);

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
  insert into public.water_still_qc_r3491 (
    organization_id, hospital_name, device_code, device_model, lab_section, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, sample_point,
    test_date, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.lsec, q.param,
    q.refv, q.measv, q.devp, q.wtol, q.spoint,
    q.tdate::date, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','WS-APL-01','Merck Milli-Q IX 7003','biochemistry','conductivity_us',
     1.30,1.40,7.69,true,'outlet','2026-07-05','2026-04-10',true,'pass','Type I outlet conductivity within spec at 25C'),
    ('Apollo Chennai','WS-APL-02','Merck Milli-Q IX 7003','biochemistry','toc_ppb',
     50.00,42.00,-16.00,true,'point_of_use','2026-07-05','2026-04-10',true,'pass','TOC well below 50 ppb limit'),
    ('Fortis Gurgaon','WS-FRT-11','Sartorius Arium Pro','molecular','resistivity_mohm',
     18.20,17.60,-3.30,true,'distribution_loop','2026-07-06','2026-03-22',true,'conditional_pass','Resistivity marginal, downward drift flagged for watch'),
    ('Fortis Gurgaon','WS-FRT-12','Sartorius Arium Pro','molecular','conductivity_us',
     1.30,2.80,115.38,false,'outlet','2026-07-06','2026-03-22',true,'fail','Conductivity 2.8 uS out of spec — resin bed suspected exhausted'),
    ('Manipal Bengaluru','WS-MNP-21','Bibby Aquatron A4000D','central_lab','output_rate_lph',
     4.00,2.60,-35.00,false,'outlet','2026-07-08','2026-05-01',true,'fail','Distillation output rate dropped to 2.6 L/h — boiler scaling'),
    ('Manipal Bengaluru','WS-MNP-22','Bibby Aquatron A4000D','central_lab','ph',
     6.50,6.70,3.08,true,'storage_tank','2026-07-08','2026-05-01',true,'pass','pH of distillate within 5.0-7.0 acceptance band'),
    ('AIIMS Delhi','WS-AIM-31','Elga PURELAB Flex','microbiology','bacterial_cfu',
     10.00,85.00,750.00,false,'storage_tank','2026-06-18','2026-02-14',true,'fail','Heterotrophic plate count 85 CFU/mL — storage tank contamination'),
    ('AIIMS Delhi','WS-AIM-32','Elga PURELAB Flex','microbiology','toc_ppb',
     50.00,68.00,36.00,false,'distribution_loop','2026-06-18','2026-02-14',true,'conditional_pass','TOC elevated at 68 ppb — membrane polish due'),
    ('CMC Vellore','WS-CMC-41','Merck Milli-Q Direct 16','pathology','conductivity_us',
     1.30,1.35,3.85,true,'point_of_use','2026-06-20','2026-04-02',true,'pass','Conductivity stable, cartridge healthy'),
    ('CMC Vellore','WS-CMC-42','Merck Milli-Q Direct 16','pathology','resistivity_mohm',
     18.20,15.10,-17.03,false,'outlet','2026-06-20','2026-04-02',true,'fail','Resistivity fell to 15.1 MOhm — membrane fouling confirmed'),
    ('KIMS Hyderabad','WS-KIM-51','Thermo Barnstead GenPure','biochemistry','ph',
     6.50,5.90,-9.23,false,'distribution_loop','2026-06-22','2026-01-30',false,'conditional_pass','pH low at 5.9 with feed-water CO2 ingress; calibration overdue'),
    ('KIMS Hyderabad','WS-KIM-52','Thermo Barnstead GenPure','biochemistry','output_rate_lph',
     4.00,3.80,-5.00,true,'outlet','2026-05-24','2026-01-30',true,'pass','Output rate within tolerance post service'),
    ('Yashoda Hyderabad','WS-YSH-61','Elga PURELAB Chorus','microbiology','bacterial_cfu',
     10.00,8.00,-20.00,true,'point_of_use','2026-05-26','2026-03-15',true,'pass','Plate count 8 CFU/mL within microbial limit'),
    ('Yashoda Hyderabad','WS-YSH-62','Elga PURELAB Chorus','microbiology','toc_ppb',
     50.00,130.00,160.00,false,'storage_tank','2026-05-26','2025-11-15',false,'fail','TOC 130 ppb with overdue calibration — full sanitization required'),
    ('Kokilaben Mumbai','WS-KKB-71','Sartorius Arium Comfort','central_lab','conductivity_us',
     1.30,1.90,46.15,false,'outlet','2026-05-12','2026-02-08',true,'conditional_pass','Conductivity 1.9 uS drift — sensor recalibration ordered'),
    ('Kokilaben Mumbai','WS-KKB-72','Sartorius Arium Comfort','central_lab','resistivity_mohm',
     18.20,18.00,-1.10,true,'point_of_use','2026-05-12','2026-02-08',true,'pass','Resistivity nominal at point of use')
  ) as q(hosp, dcode, dmodel, lsec, param, refv, measv, devp, wtol, spoint, tdate, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.water_still_qc_capa_actions_r3491 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WS-FRT-12','conductivity_out_of_spec','resin_bed_exhausted','replace_resin_bed','in_progress','nabl_finding','2026-07-12',null,45000.00,'DI resin bed exhausted — replacement cartridge on order'),
    ('WS-MNP-21','output_rate_low','heater_element_scaling','descale_boiler_condenser','open','iso_15189_deviation','2026-07-15',null,18000.00,'Boiler and condenser scaling — descale and flow test scheduled'),
    ('WS-AIM-31','bacterial_contamination','storage_tank_contamination','sanitize_system','escalated','patient_safety_alert','2026-06-25',null,32000.00,'Tank biofilm suspected — hot sanitization and re-swab escalated'),
    ('WS-CMC-42','resistivity_low','membrane_fouling','replace_membrane','verification_pending','internal_only','2026-06-28',null,27000.00,'RO membrane replaced — verifying resistivity recovery'),
    ('WS-YSH-62','toc_high','membrane_fouling','replace_membrane','overdue','nabh_finding','2026-06-05',null,24000.00,'TOC breach with overdue cal — membrane swap past target date'),
    ('WS-KKB-71','conductivity_out_of_spec','sensor_drift','recalibrate_sensor','closed','internal_only','2026-05-18','2026-05-15',4000.00,'Conductivity sensor recalibrated and verified'),
    ('WS-KIM-51','ph_out_of_range','feed_water_quality','flush_distribution_loop','open','none','2026-06-30',null,6000.00,'CO2 ingress in feed — loop flush and vent filter check'),
    ('WS-AIM-32','toc_high','membrane_fouling','replace_membrane','in_progress','iso_15189_deviation','2026-06-30',null,22000.00,'Polish membrane replacement underway to bring TOC in spec')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.water_still_qc_r3491 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3491_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.water_still_qc_r3491)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.water_still_qc_r3491 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3491_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3491_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3491_device_model_scorecard()
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
  from public.water_still_qc_r3491 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3491_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3491_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3491_parameter_verdict_matrix()
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
  from public.water_still_qc_r3491 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3491_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3491_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3491_monthly_qc_trend()
returns table(
  month_start date,
  checks bigint,
  passed bigint,
  failed bigint,
  out_of_tolerance bigint,
  calibration_overdue bigint,
  avg_deviation_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.test_date)::date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.water_still_qc_r3491 l
  group by date_trunc('month', l.test_date)
  order by date_trunc('month', l.test_date) desc;
end;
$$;

revoke execute on function public.founder_r3491_monthly_qc_trend() from public, anon;
grant execute on function public.founder_r3491_monthly_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3491_capa_status_board()
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
  from public.water_still_qc_capa_actions_r3491 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3491_capa_status_board() from public, anon;
grant execute on function public.founder_r3491_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3491_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.water_still_qc_capa_actions_r3491)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.water_still_qc_capa_actions_r3491 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3491_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3491_root_cause_pareto() to authenticated;

-- 7) Accuracy impact digest (per-parameter deviation profile)
create or replace function public.founder_r3491_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  within_tol bigint,
  out_of_tol bigint,
  avg_deviation_pct numeric,
  max_abs_deviation_pct numeric
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
    round(max(abs(l.deviation_pct)), 2)
  from public.water_still_qc_r3491 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3491_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3491_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3491_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  test_date date,
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
  select l.hospital_name, l.device_code, l.device_model, l.parameter, l.test_date,
    l.reference_value, l.measured_value, l.deviation_pct, l.qc_verdict, l.notes
  from public.water_still_qc_r3491 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3491_high_risk_queue() from public, anon;
grant execute on function public.founder_r3491_high_risk_queue() to authenticated;
