-- Round 3518: Customer Hospital Chemotherapy Compounding-Isolator / Cytotoxic-Hood QC Audit
-- Hospital chemo compounding isolator / cytotoxic safety cabinet QC — negative pressure × inflow/downflow velocity × HEPA integrity × particle count × containment leak × tolerance × calibration × CAPA

-- =============================================================================
-- TABLE 1: chemo_isolator_qc_r3518 — per-device isolator / cytotoxic-hood QC checks
-- =============================================================================
create table if not exists public.chemo_isolator_qc_r3518 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  cabinet_type text not null check (cabinet_type in (
    'cytotoxic_safety_cabinet_class_ii','compounding_isolator_negative',
    'compounding_isolator_positive','laminar_flow_hood'
  )),
  parameter text not null check (parameter in (
    'negative_pressure_pa','inflow_velocity_ms','downflow_velocity_ms',
    'hepa_integrity_pct','particle_count','containment_leak'
  )),
  reference_value numeric(10,3),
  measured_value numeric(10,3),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  hepa_leak_test text not null check (hepa_leak_test in (
    'pass','fail','not_applicable'
  )),
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.chemo_isolator_qc_r3518 enable row level security;

create index if not exists idx_chemo_isolator_qc_r3518_org on public.chemo_isolator_qc_r3518(organization_id);
create index if not exists idx_chemo_isolator_qc_r3518_date on public.chemo_isolator_qc_r3518(calibration_date);
create index if not exists idx_chemo_isolator_qc_r3518_verdict on public.chemo_isolator_qc_r3518(qc_verdict);

-- =============================================================================
-- TABLE 2: chemo_isolator_qc_capa_actions_r3518 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.chemo_isolator_qc_capa_actions_r3518 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.chemo_isolator_qc_r3518(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'negative_pressure_out_of_range','inflow_velocity_low','downflow_velocity_out_of_range',
    'hepa_integrity_failure','particle_count_excursion','containment_breach',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'hepa_filter_loaded','blower_degraded','damper_misadjusted','door_gasket_leak',
    'sensor_drift','glove_sleeve_breach','operator_setup_error',
    'pending_investigation','preventive_service_backlog','filter_seal_failure'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_hepa_filter','service_blower','readjust_damper','replace_door_gasket',
    'recalibrate_sensor','replace_glove_sleeve','retrain_pharmacy_staff',
    'remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','usp_800_deviation','staff_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.chemo_isolator_qc_capa_actions_r3518 enable row level security;

create index if not exists idx_chemo_isolator_capa_r3518_log on public.chemo_isolator_qc_capa_actions_r3518(qc_log_id);
create index if not exists idx_chemo_isolator_capa_r3518_status on public.chemo_isolator_qc_capa_actions_r3518(capa_status);

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
  insert into public.chemo_isolator_qc_r3518 (
    organization_id, hospital_name, device_code, device_model, cabinet_type, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, hepa_leak_test,
    calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.ctype, q.param,
    q.refv, q.measv, q.devp, q.wtol, q.hleak,
    q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','ISO-APL-01','ChemGuard CSC-II','cytotoxic_safety_cabinet_class_ii','negative_pressure_pa',
     -45,-44,2.2,true,'pass','2026-07-05',true,'pass','Class II CSC negative pressure within limit'),
    ('Apollo Chennai','ISO-APL-02','ChemGuard CSC-II','cytotoxic_safety_cabinet_class_ii','inflow_velocity_ms',
     0.50,0.53,6.0,true,'pass','2026-07-05',true,'pass','Inflow velocity above NSF-49 minimum'),
    ('Fortis Gurgaon','ISO-FRT-11','IsoCyto NX Isolator','compounding_isolator_negative','negative_pressure_pa',
     -60,-48,-20.0,false,'pass','2026-07-04',true,'fail','Negative pressure below spec — blower degraded'),
    ('Fortis Gurgaon','ISO-FRT-12','IsoCyto NX Isolator','compounding_isolator_negative','hepa_integrity_pct',
     99.99,99.95,-0.04,false,'fail','2026-07-04',true,'fail','HEPA integrity leak detected on aerosol scan'),
    ('Manipal Bengaluru','ISO-MNP-21','PharmaFlow LFH','laminar_flow_hood','downflow_velocity_ms',
     0.33,0.30,-9.1,false,'not_applicable','2026-07-03',true,'conditional_pass','Downflow marginally low — damper adjustment due'),
    ('Manipal Bengaluru','ISO-MNP-22','PharmaFlow LFH','laminar_flow_hood','particle_count',
     3520,2900,-17.6,true,'not_applicable','2026-07-03',true,'pass','ISO 5 particle count within class'),
    ('AIIMS Delhi','ISO-AIM-31','IsoCyto NX Isolator','compounding_isolator_negative','containment_leak',
     0,5.2,null,false,'fail','2026-06-30',false,'fail','KI-Discus containment leak index elevated — glove breach'),
    ('AIIMS Delhi','ISO-AIM-32','ChemGuard CSC-II','cytotoxic_safety_cabinet_class_ii','inflow_velocity_ms',
     0.50,0.41,-18.0,false,'pass','2026-06-30',true,'fail','Inflow velocity below minimum — HEPA loaded'),
    ('CMC Vellore','ISO-CMC-41','PharmaFlow LFH','laminar_flow_hood','downflow_velocity_ms',
     0.33,0.34,3.0,true,'not_applicable','2026-06-29',true,'pass','Downflow velocity nominal'),
    ('CMC Vellore','ISO-CMC-42','IsoCyto NX Isolator','compounding_isolator_negative','hepa_integrity_pct',
     99.99,99.99,0.0,true,'pass','2026-06-29',false,'conditional_pass','HEPA integrity OK but calibration overdue'),
    ('KIMS Hyderabad','ISO-KIM-51','ChemGuard CSC-II','cytotoxic_safety_cabinet_class_ii','particle_count',
     3520,3200,-9.1,true,'pass','2026-06-28',true,'pass','Particle count within ISO 5'),
    ('KIMS Hyderabad','ISO-KIM-52','IsoCyto NX Isolator','compounding_isolator_negative','negative_pressure_pa',
     -60,-58,-3.3,true,'pass','2026-06-28',true,'pass','Negative pressure within tolerance'),
    ('Yashoda Hyderabad','ISO-YSH-61','PharmaFlow LFH','laminar_flow_hood','hepa_integrity_pct',
     99.99,99.90,-0.09,false,'fail','2026-06-27',true,'conditional_pass','HEPA scan marginal — reseal scheduled'),
    ('Kokilaben Mumbai','ISO-KKB-71','IsoCyto NX Isolator','compounding_isolator_negative','containment_leak',
     0,8.4,null,false,'fail','2026-06-26',false,'fail','Containment breach — sleeve failure, removed from compounding'),
    ('Kokilaben Mumbai','ISO-KKB-72','ChemGuard CSC-II','cytotoxic_safety_cabinet_class_ii','downflow_velocity_ms',
     0.33,0.32,-3.0,true,'pass','2026-06-26',true,'pass','Downflow velocity within limit'),
    ('Rainbow Hyderabad','ISO-RNB-81','PharmaFlow LFH','laminar_flow_hood','inflow_velocity_ms',
     0.50,0.51,2.0,true,'not_applicable','2026-06-25',true,'pass','Inflow velocity nominal')
  ) as q(hosp, dcode, dmodel, ctype, param, refv, measv, devp, wtol, hleak, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.chemo_isolator_qc_capa_actions_r3518 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ISO-FRT-11','negative_pressure_out_of_range','blower_degraded','service_blower','in_progress','usp_800_deviation','2026-07-08',null,28000.00,'Blower serviced; re-test pressure pending'),
    ('ISO-FRT-12','hepa_integrity_failure','filter_seal_failure','replace_hepa_filter','open','cdsco_notifiable','2026-07-09',null,42000.00,'HEPA leak on scan — filter and seal replacement ordered'),
    ('ISO-MNP-21','downflow_velocity_out_of_range','damper_misadjusted','readjust_damper','verification_pending','internal_only','2026-07-07',null,6000.00,'Damper readjusted — verify downflow next PM'),
    ('ISO-AIM-31','containment_breach','glove_sleeve_breach','replace_glove_sleeve','escalated','staff_safety_alert','2026-07-04',null,15000.00,'Glove/sleeve breach — cytotoxic exposure risk escalated'),
    ('ISO-AIM-32','inflow_velocity_low','hepa_filter_loaded','replace_hepa_filter','closed','nabh_finding','2026-07-05','2026-07-02',39000.00,'Loaded HEPA replaced; inflow restored and validated'),
    ('ISO-CMC-42','calibration_overdue','sensor_drift','recalibrate_sensor','open','internal_only','2026-07-06',null,5000.00,'Airflow sensor recalibration scheduled'),
    ('ISO-YSH-61','hepa_integrity_failure','filter_seal_failure','replace_hepa_filter','overdue','nabh_finding','2026-07-01',null,18000.00,'HEPA reseal past target — vendor delay'),
    ('ISO-KKB-71','containment_breach','glove_sleeve_breach','remove_from_service','closed','cdsco_notifiable','2026-06-30','2026-06-27',52000.00,'Sleeve failure — isolator removed, replacement validated')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.chemo_isolator_qc_r3518 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3518_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.chemo_isolator_qc_r3518)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.chemo_isolator_qc_r3518 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3518_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3518_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3518_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  out_of_tolerance bigint,
  containment_fail bigint,
  cal_overdue bigint,
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
    count(*) filter (where l.parameter = 'containment_leak' and l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(avg(l.deviation_pct), 2),
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.chemo_isolator_qc_r3518 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3518_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3518_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3518_parameter_verdict_matrix()
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
  from public.chemo_isolator_qc_r3518 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3518_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3518_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3518_monthly_accuracy_trend()
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
  from public.chemo_isolator_qc_r3518 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3518_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3518_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3518_capa_status_board()
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
  from public.chemo_isolator_qc_capa_actions_r3518 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3518_capa_status_board() from public, anon;
grant execute on function public.founder_r3518_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3518_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.chemo_isolator_qc_capa_actions_r3518)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.chemo_isolator_qc_capa_actions_r3518 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3518_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3518_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory-impact digest
create or replace function public.founder_r3518_accuracy_impact_digest()
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
  from public.chemo_isolator_qc_capa_actions_r3518 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3518_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3518_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / containment-fail)
create or replace function public.founder_r3518_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  parameter text,
  calibration_date date,
  qc_verdict text,
  deviation_pct numeric,
  within_tolerance boolean,
  hepa_leak_test text,
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
    l.qc_verdict, l.deviation_pct, l.within_tolerance, l.hepa_leak_test, l.notes
  from public.chemo_isolator_qc_r3518 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.hepa_leak_test = 'fail'
     or l.parameter = 'containment_leak'
     or l.calibration_current = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3518_high_risk_queue() from public, anon;
grant execute on function public.founder_r3518_high_risk_queue() to authenticated;
