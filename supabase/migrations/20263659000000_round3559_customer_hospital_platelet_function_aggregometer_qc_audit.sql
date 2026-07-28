-- Round 3559: Customer Hospital Platelet-Function Aggregometer QC Audit
-- Platelet aggregometer QC — device model x channel x agonist x parameter x reference/measured x deviation x tolerance x calibration x verdict x CAPA

-- =============================================================================
-- TABLE 1: aggregometer_qc_r3559 — per-device platelet aggregometer QC checks
-- =============================================================================
create table if not exists public.aggregometer_qc_r3559 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  channel text not null check (channel in (
    'channel_1','channel_2','channel_3','channel_4','all_channels'
  )),
  agonist text not null check (agonist in (
    'adp','collagen','arachidonic_acid','epinephrine','ristocetin','thrombin','not_applicable'
  )),
  parameter text not null check (parameter in (
    'aggregation_pct_accuracy','optical_baseline','stir_speed_rpm','channel_temp_c','response_time_sec','carryover_pct'
  )),
  reference_value numeric(8,2),
  measured_value numeric(8,2),
  deviation_pct numeric(6,2),
  within_tolerance boolean not null,
  channel_temp_c numeric(4,1),
  stir_speed_rpm int,
  calibration_date date not null,
  calibration_current boolean not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.aggregometer_qc_r3559 enable row level security;

create index if not exists idx_aggregometer_qc_r3559_org on public.aggregometer_qc_r3559(organization_id);
create index if not exists idx_aggregometer_qc_r3559_date on public.aggregometer_qc_r3559(calibration_date);
create index if not exists idx_aggregometer_qc_r3559_verdict on public.aggregometer_qc_r3559(qc_verdict);

-- =============================================================================
-- TABLE 2: aggregometer_qc_capa_actions_r3559 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.aggregometer_qc_capa_actions_r3559 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.aggregometer_qc_r3559(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'aggregation_accuracy_out_of_tolerance','optical_baseline_drift','stir_speed_out_of_spec',
    'channel_temp_out_of_range','response_time_slow','carryover_high',
    'calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'led_photodetector_aging','stir_bar_motor_wear','heater_block_drift','cuvette_contamination',
    'reagent_lot_variation','optical_path_fouling','firmware_config_error','operator_technique_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_optics','replace_led_photodetector','replace_stir_motor','service_heater_block',
    'clean_optical_path','replace_cuvette_batch','requalify_reagent_lot','update_firmware',
    'retrain_lab_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabl_finding','cdsco_notifiable','none','internal_only','iso_15189_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.aggregometer_qc_capa_actions_r3559 enable row level security;

create index if not exists idx_aggregometer_capa_r3559_log on public.aggregometer_qc_capa_actions_r3559(qc_log_id);
create index if not exists idx_aggregometer_capa_r3559_status on public.aggregometer_qc_capa_actions_r3559(capa_status);

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
  insert into public.aggregometer_qc_r3559 (
    organization_id, hospital_name, device_code, device_model, channel, agonist, parameter,
    reference_value, measured_value, deviation_pct, within_tolerance,
    channel_temp_c, stir_speed_rpm, calibration_date, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.chan, q.agon, q.param,
    q.refv, q.measv, q.devp, q.wtol,
    q.temp, q.stir, q.caldate::date, q.calcur, q.qv, q.nt
  from (values
    ('Apollo Chennai','AGG-APL-01','ChronoLog_700','channel_1','adp','aggregation_pct_accuracy',
     80,79.2,-1.0,true,37.0,1000,'2026-07-05',true,'pass','ADP aggregation accuracy within plus/minus 3% tolerance'),
    ('Apollo Chennai','AGG-APL-02','ChronoLog_700','channel_2','collagen','optical_baseline',
     100,99.4,-0.6,true,37.0,1000,'2026-07-05',true,'pass','Optical baseline transmittance stable'),
    ('Fortis Gurgaon','AGG-FRT-11','Helena_AggRAM','channel_1','arachidonic_acid','aggregation_pct_accuracy',
     85,81.0,-4.7,false,37.1,1000,'2026-07-04',true,'conditional_pass','AA aggregation 4.7% low near tolerance edge — recheck'),
    ('Fortis Gurgaon','AGG-FRT-12','Helena_AggRAM','channel_3','ristocetin','response_time_sec',
     5.0,6.8,36.0,false,37.0,1000,'2026-07-04',true,'fail','Response time 36% slow on ristocetin channel'),
    ('Manipal Bengaluru','AGG-MNP-21','BioData_PAP8E','channel_4','epinephrine','carryover_pct',
     0.0,2.1,null,false,37.0,1000,'2026-07-03',true,'fail','Carryover 2.1% exceeds 1% limit — cuvette contamination suspected'),
    ('Manipal Bengaluru','AGG-MNP-22','BioData_PAP8E','all_channels','not_applicable','channel_temp_c',
     37.0,37.2,0.5,true,37.2,1000,'2026-07-03',true,'pass','Heater block temperature within plus/minus 0.5 C'),
    ('AIIMS Delhi','AGG-AIM-31','Sysmex_CN6000','channel_1','adp','stir_speed_rpm',
     1000,1042,4.2,false,37.0,1042,'2026-07-02',true,'conditional_pass','Stir speed 4.2% high — motor drift trend flagged'),
    ('AIIMS Delhi','AGG-AIM-32','Sysmex_CN6000','channel_2','collagen','aggregation_pct_accuracy',
     82,60.5,-26.2,false,36.4,980,'2026-06-30',false,'fail','Collagen aggregation 26% low with temp and stir out — calibration overdue'),
    ('CMC Vellore','AGG-CMC-41','ChronoLog_700','channel_3','thrombin','optical_baseline',
     100,100.2,0.2,true,37.0,1000,'2026-06-29',true,'pass','Baseline optical QC pass'),
    ('CMC Vellore','AGG-CMC-42','ChronoLog_700','channel_1','adp','aggregation_pct_accuracy',
     80,77.8,-2.8,true,37.0,1000,'2026-05-28',false,'conditional_pass','ADP accuracy ok but calibration overdue — recal scheduled'),
    ('KIMS Hyderabad','AGG-KIM-51','Helena_AggRAM','channel_2','ristocetin','response_time_sec',
     5.0,5.2,4.0,true,37.0,1000,'2026-06-28',true,'pass','Ristocetin response time within tolerance'),
    ('KIMS Hyderabad','AGG-KIM-52','Helena_AggRAM','channel_4','arachidonic_acid','carryover_pct',
     0.0,0.4,null,true,37.0,1000,'2026-06-28',true,'pass','Carryover 0.4% within limit'),
    ('Yashoda Hyderabad','AGG-YSH-61','BioData_PAP8E','channel_1','epinephrine','channel_temp_c',
     37.0,36.2,-2.2,false,36.2,1000,'2026-06-27',true,'conditional_pass','Channel temp 0.8 C low — heater block service due'),
    ('Kokilaben Mumbai','AGG-KKB-71','Sysmex_CN6000','all_channels','not_applicable','stir_speed_rpm',
     1000,890,-11.0,false,36.8,890,'2026-06-26',false,'fail','Stir motor 11% under speed across channels — removed pending service'),
    ('Rainbow Hyderabad','AGG-RNB-81','ChronoLog_700','channel_2','collagen','aggregation_pct_accuracy',
     84,83.1,-1.1,true,37.0,1000,'2026-07-06',true,'pass','Collagen aggregation accuracy pass post-AMC'),
    ('Narayana Bengaluru','AGG-NAR-91','Helena_AggRAM','channel_3','adp','optical_baseline',
     100,96.5,-3.5,false,37.0,1000,'2026-07-01',true,'conditional_pass','Optical baseline drift 3.5% — clean optical path')
  ) as q(hosp, dcode, dmodel, chan, agon, param, refv, measv, devp, wtol, temp, stir, caldate, calcur, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.aggregometer_qc_capa_actions_r3559 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.own, q.nt
  from (values
    ('AGG-FRT-12','response_time_slow','firmware_config_error','update_firmware','in_progress','iso_15189_deviation','2026-07-10',null,6500.00,'Biomedical Engg','Firmware timing parameters updated — verify response time'),
    ('AGG-MNP-21','carryover_high','cuvette_contamination','replace_cuvette_batch','open','nabl_finding','2026-07-08',null,12000.00,'Lab QC Lead','Contaminated cuvette lot quarantined — new batch ordered'),
    ('AGG-AIM-31','stir_speed_out_of_spec','stir_bar_motor_wear','replace_stir_motor','verification_pending','internal_only','2026-07-09',null,18500.00,'OEM Service','Stir motor replaced — verify RPM across channels'),
    ('AGG-AIM-32','aggregation_accuracy_out_of_tolerance','heater_block_drift','service_heater_block','escalated','patient_safety_alert','2026-07-07',null,32000.00,'Biomedical Engg','Temp and stir drift with overdue cal — escalated to OEM'),
    ('AGG-KKB-71','stir_speed_out_of_spec','stir_bar_motor_wear','schedule_oem_service','closed','cdsco_notifiable','2026-07-04','2026-06-30',41000.00,'OEM Service','Stir drive assembly replaced and requalified'),
    ('AGG-NAR-91','optical_baseline_drift','optical_path_fouling','clean_optical_path','verification_pending','internal_only','2026-07-08',null,3500.00,'Lab Technologist','Optical path cleaned — recheck baseline transmittance'),
    ('AGG-CMC-42','calibration_overdue','preventive_service_backlog','schedule_oem_service','overdue','internal_only','2026-06-30',null,9000.00,'Biomedical Engg','Recalibration past target date — vendor scheduling delay'),
    ('AGG-YSH-61','channel_temp_out_of_range','heater_block_drift','service_heater_block','open','iso_15189_deviation','2026-07-11',null,15000.00,'OEM Service','Heater block temperature calibration scheduled')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, own, nt)
  join public.aggregometer_qc_r3559 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3559_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.aggregometer_qc_r3559)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.aggregometer_qc_r3559 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3559_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3559_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3559_device_model_scorecard()
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
  from public.aggregometer_qc_r3559 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3559_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3559_device_model_scorecard() to authenticated;

-- 3) Parameter × verdict matrix
create or replace function public.founder_r3559_parameter_verdict_matrix()
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
  from public.aggregometer_qc_r3559 l
  group by l.parameter, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3559_parameter_verdict_matrix() from public, anon;
grant execute on function public.founder_r3559_parameter_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3559_monthly_calibration_trend()
returns table(cal_month text, checks bigint, passed bigint, failed bigint, out_of_tolerance bigint, avg_deviation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(l.calibration_date, 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    count(*) filter (where l.within_tolerance = false)::bigint,
    round(avg(l.deviation_pct), 2)
  from public.aggregometer_qc_r3559 l
  group by to_char(l.calibration_date, 'YYYY-MM')
  order by to_char(l.calibration_date, 'YYYY-MM') desc;
end;
$$;

revoke execute on function public.founder_r3559_monthly_calibration_trend() from public, anon;
grant execute on function public.founder_r3559_monthly_calibration_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3559_capa_status_board()
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
  from public.aggregometer_qc_capa_actions_r3559 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3559_capa_status_board() from public, anon;
grant execute on function public.founder_r3559_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3559_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.aggregometer_qc_capa_actions_r3559)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.aggregometer_qc_capa_actions_r3559 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3559_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3559_root_cause_pareto() to authenticated;

-- 7) Accuracy / regulatory impact digest
create or replace function public.founder_r3559_accuracy_impact_digest()
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
  from public.aggregometer_qc_capa_actions_r3559 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3559_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3559_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3559_high_risk_queue()
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
  from public.aggregometer_qc_r3559 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.within_tolerance = false
     or l.calibration_current = false
  order by abs(l.deviation_pct) desc nulls last, l.calibration_date desc;
end;
$$;

revoke execute on function public.founder_r3559_high_risk_queue() from public, anon;
grant execute on function public.founder_r3559_high_risk_queue() to authenticated;
