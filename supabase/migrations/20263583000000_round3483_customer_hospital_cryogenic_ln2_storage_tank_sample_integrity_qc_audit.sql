-- Round 3483: Customer Hospital Cryogenic LN2 Storage-Tank Sample-Integrity QC Audit
-- Hospital biobank cryogenic LN2 storage-tank QC — LN2 level, vapor-phase temp, evaporation rate,
-- low-level & O2-deficiency alarms, fill-cycle, sample integrity, accuracy vs reference, verdict, CAPA

-- =============================================================================
-- TABLE 1: cryo_ln2_qc_r3483 — per-tank cryogenic LN2 storage QC checks
-- =============================================================================
create table if not exists public.cryo_ln2_qc_r3483 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  biobank_zone text not null check (biobank_zone in (
    'stem_cell','cord_blood','ivf_embryo','tissue_bank','vaccine_store','general_cryo'
  )),
  parameter text not null check (parameter in (
    'ln2_level_pct','vapor_temp_c','evaporation_rate_lpd','low_level_alarm','fill_cycle_days','o2_deficiency_alarm'
  )),
  reference_value numeric(10,2),
  measured_value numeric(10,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  alarm_ok boolean not null,
  sample_integrity_ok boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cryo_ln2_qc_r3483 enable row level security;

create index if not exists idx_cryo_ln2_qc_r3483_org on public.cryo_ln2_qc_r3483(organization_id);
create index if not exists idx_cryo_ln2_qc_r3483_date on public.cryo_ln2_qc_r3483(calibration_date);
create index if not exists idx_cryo_ln2_qc_r3483_verdict on public.cryo_ln2_qc_r3483(qc_verdict);

-- =============================================================================
-- TABLE 2: cryo_ln2_qc_capa_actions_r3483 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cryo_ln2_qc_capa_actions_r3483 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.cryo_ln2_qc_r3483(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'ln2_level_low','vapor_temp_high','evaporation_rate_high','low_level_alarm_failure',
    'o2_deficiency_alarm_failure','fill_cycle_overdue','sample_integrity_risk',
    'calibration_overdue','accuracy_out_of_tolerance','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'vacuum_insulation_loss','lid_seal_degraded','autofill_valve_stuck','ln2_supply_delay',
    'sensor_drift','alarm_module_fault','o2_sensor_expired','operator_fill_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'top_up_ln2','replace_vacuum_jacket','replace_lid_gasket','repair_autofill_valve',
    'recalibrate_sensor','replace_o2_sensor','replace_alarm_module','relocate_samples',
    'retrain_biobank_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','sample_loss_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cryo_ln2_qc_capa_actions_r3483 enable row level security;

create index if not exists idx_cryo_ln2_capa_r3483_log on public.cryo_ln2_qc_capa_actions_r3483(qc_log_id);
create index if not exists idx_cryo_ln2_capa_r3483_status on public.cryo_ln2_qc_capa_actions_r3483(capa_status);

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
  insert into public.cryo_ln2_qc_r3483 (
    organization_id, hospital_name, device_code, device_model, biobank_zone, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance, alarm_ok, sample_integrity_ok,
    calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.bzone, q.param,
    q.refv, q.measv, q.devp, q.wtol, q.alarmok, q.sampint,
    q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','CRYO-APL-01','MVE HEco 1500','stem_cell','ln2_level_pct',
     80.00,78.50,-1.88,true,true,true,'2026-07-05','pass','LN2 level 78.5% within control band'),
    ('Apollo Chennai','CRYO-APL-02','Thermo CryoPlus 2','cord_blood','vapor_temp_c',
     -190.00,-188.50,0.79,true,true,true,'2026-07-05','pass','Vapor-phase neck temp -188.5C within limit'),
    ('Fortis Gurgaon','CRYO-FRT-11','Chart MVE 1839','ivf_embryo','evaporation_rate_lpd',
     1.20,1.55,29.17,false,true,true,'2026-07-04','conditional_pass','Evaporation 1.55 L/day above 1.2 spec — vacuum check advised'),
    ('Fortis Gurgaon','CRYO-FRT-12','Taylor-Wharton XT34','tissue_bank','ln2_level_pct',
     80.00,52.00,-35.00,false,false,false,'2026-07-04','fail','Level fell to 52%, low-level alarm did not fire — samples at risk'),
    ('Manipal Bengaluru','CRYO-MNP-21','MVE HEco 1500','vaccine_store','fill_cycle_days',
     7.00,7.00,0.00,true,true,true,'2026-07-03','pass','Auto-fill cycle 7 days on schedule'),
    ('Manipal Bengaluru','CRYO-MNP-22','Thermo CryoPlus 2','stem_cell','o2_deficiency_alarm',
     null,null,null,true,true,true,'2026-07-03','pass','O2 deficiency alarm test passed at 19.5% setpoint'),
    ('AIIMS Delhi','CRYO-AIM-31','Chart MVE 1839','cord_blood','vapor_temp_c',
     -190.00,-182.00,4.21,false,true,true,'2026-07-02','conditional_pass','Neck temp -182C, upper samples warmer than spec — reposition inventory'),
    ('AIIMS Delhi','CRYO-AIM-32','Taylor-Wharton XT34','ivf_embryo','low_level_alarm',
     null,null,null,true,false,true,'2026-07-02','fail','Low-level alarm failed to annunciate during drain test'),
    ('CMC Vellore','CRYO-CMC-41','MVE HEco 1500','tissue_bank','evaporation_rate_lpd',
     1.20,1.15,-4.17,true,true,true,'2026-07-01','pass','Evaporation 1.15 L/day within spec'),
    ('CMC Vellore','CRYO-CMC-42','Thermo CryoPlus 2','general_cryo','ln2_level_pct',
     80.00,71.00,-11.25,false,true,true,'2026-07-01','conditional_pass','Level 71%, autofill valve sluggish — monitor closely'),
    ('KIMS Hyderabad','CRYO-KIM-51','Chart MVE 1839','stem_cell','o2_deficiency_alarm',
     null,null,null,true,true,true,'2026-06-30','pass','O2 depletion sensor within calibration'),
    ('KIMS Hyderabad','CRYO-KIM-52','Taylor-Wharton XT34','cord_blood','fill_cycle_days',
     7.00,11.00,57.14,false,true,true,'2026-06-30','conditional_pass','Fill cycle stretched to 11 days — supply delay, refill expedited'),
    ('Yashoda Hyderabad','CRYO-YSH-61','MVE HEco 1500','vaccine_store','vapor_temp_c',
     -190.00,-189.20,0.42,true,true,true,'2026-06-29','pass','Vaccine cryostore vapor temp nominal'),
    ('Kokilaben Mumbai','CRYO-KKB-71','Taylor-Wharton XT34','ivf_embryo','ln2_level_pct',
     80.00,38.00,-52.50,false,false,false,'2026-06-28','fail','Critical low level 38% with alarm failure — embryo samples relocated, integrity compromised'),
    ('Kokilaben Mumbai','CRYO-KKB-72','Chart MVE 1839','tissue_bank','evaporation_rate_lpd',
     1.20,2.10,75.00,false,true,false,'2026-06-28','fail','Evaporation 2.1 L/day — vacuum insulation failing, samples migrated to backup tank'),
    ('Narayana Bengaluru','CRYO-NAR-81','MVE HEco 1500','general_cryo','o2_deficiency_alarm',
     null,null,null,true,false,true,'2026-06-27','conditional_pass','O2 alarm buzzer weak — audible test marginal, module service scheduled')
  ) as q(hosp, dcode, dmodel, bzone, param, refv, measv, devp, wtol, alarmok, sampint, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.cryo_ln2_qc_capa_actions_r3483 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('CRYO-FRT-12','low_level_alarm_failure','alarm_module_fault','replace_alarm_module','escalated','sample_loss_alert','2026-07-08',null,65000.00,'Level drop with alarm miss — alarm module replacement, OEM escalation, samples inspected'),
    ('CRYO-FRT-11','evaporation_rate_high','vacuum_insulation_loss','replace_vacuum_jacket','in_progress','iso_15189_deviation','2026-07-10',null,145000.00,'Evaporation above spec — vacuum jacket service in progress'),
    ('CRYO-AIM-31','vapor_temp_high','sensor_drift','recalibrate_sensor','verification_pending','internal_only','2026-07-06',null,12000.00,'Neck temp warm — inventory repositioned, temp sensor recalibrated'),
    ('CRYO-AIM-32','low_level_alarm_failure','alarm_module_fault','replace_alarm_module','open','cdsco_notifiable','2026-07-07',null,38000.00,'Low-level alarm non-functional — module replacement ordered'),
    ('CRYO-CMC-42','ln2_level_low','autofill_valve_stuck','repair_autofill_valve','closed','internal_only','2026-07-05','2026-07-04',22000.00,'Autofill valve cleaned and reseated — level restored'),
    ('CRYO-KIM-52','fill_cycle_overdue','ln2_supply_delay','top_up_ln2','closed','none','2026-07-03','2026-07-01',9000.00,'Manual top-up performed, supply contract reviewed'),
    ('CRYO-KKB-71','sample_integrity_risk','autofill_valve_stuck','relocate_samples','escalated','sample_loss_alert','2026-07-02',null,210000.00,'Critical low level with alarm failure — IVF embryo samples relocated to backup, integrity investigation open'),
    ('CRYO-KKB-72','evaporation_rate_high','vacuum_insulation_loss','replace_vacuum_jacket','escalated','cdsco_notifiable','2026-07-02',null,175000.00,'Vacuum insulation failing — samples migrated, tank quarantined pending jacket replacement'),
    ('CRYO-NAR-81','o2_deficiency_alarm_failure','alarm_module_fault','replace_alarm_module','open','nabh_finding','2026-07-04',null,28000.00,'O2 deficiency alarm buzzer weak — module service scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cryo_ln2_qc_r3483 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3483_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cryo_ln2_qc_r3483)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cryo_ln2_qc_r3483 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3483_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3483_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3483_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  alarm_fail bigint,
  out_of_tolerance bigint,
  integrity_fail bigint,
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
    count(*) filter (where l.alarm_ok = false)::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.sample_integrity_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cryo_ln2_qc_r3483 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3483_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3483_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3483_parameter_verdict_matrix()
returns table(
  parameter text,
  checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  avg_deviation_pct numeric
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cryo_ln2_qc_r3483 l
  group by l.parameter
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3483_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3483_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3483_monthly_calibration_trend()
returns table(
  cal_month date,
  checks bigint,
  passed bigint,
  failed bigint,
  alarm_fail bigint,
  avg_deviation_pct numeric
)
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
    count(*) filter (where l.alarm_ok = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.cryo_ln2_qc_r3483 l
  group by date_trunc('month', l.calibration_date)
  order by date_trunc('month', l.calibration_date) desc;
end;
$$;

revoke execute on function public.founder_r3483_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3483_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3483_capa_status_board()
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
  from public.cryo_ln2_qc_capa_actions_r3483 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3483_capa_status_board() from public, anon;
grant execute on function public.founder_r3483_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3483_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cryo_ln2_qc_capa_actions_r3483)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cryo_ln2_qc_capa_actions_r3483 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3483_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3483_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by parameter)
create or replace function public.founder_r3483_accuracy_impact_digest()
returns table(
  parameter text,
  checks bigint,
  out_of_tolerance bigint,
  fails bigint,
  avg_abs_deviation_pct numeric,
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
    count(*) filter (where l.within_tolerance = false)::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(abs(l.deviation_pct)), 2),
    round(max(abs(l.deviation_pct)), 2)
  from public.cryo_ln2_qc_r3483 l
  group by l.parameter
  order by count(*) filter (where l.within_tolerance = false) desc, count(*) desc;
end;
$$;

revoke execute on function public.founder_r3483_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3483_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / alarm-fail / integrity-risk)
create or replace function public.founder_r3483_high_risk_queue()
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
  from public.cryo_ln2_qc_r3483 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.alarm_ok = false
     or l.sample_integrity_ok = false
  order by l.calibration_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3483_high_risk_queue() from public, anon;
grant execute on function public.founder_r3483_high_risk_queue() to authenticated;
