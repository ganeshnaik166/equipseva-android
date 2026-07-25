-- Round 3439: Customer Hospital Transcutaneous Bilirubin (Neonatal Jaundice Meter) QC Audit
-- TcB bilirubinometer QA — device model × ward × phantom-vs-measured reading × deviation × TSB correlation × optics × calibration × verdict × CAPA

-- =============================================================================
-- TABLE 1: tcb_bilirubin_qc_r3439 — per-device transcutaneous bilirubin QC checks
-- =============================================================================
create table if not exists public.tcb_bilirubin_qc_r3439 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  device_code text not null,
  device_model text not null,
  ward_or_dept text not null,
  check_date date not null,
  phantom_tcb_value numeric(5,2),
  measured_tcb_value numeric(5,2),
  deviation_pct numeric(5,2),
  tsb_correlation_pct numeric(5,2),
  optics_ok boolean not null,
  probe_condition text not null check (probe_condition in (
    'good','worn','cracked','replace_due'
  )),
  calibration_current boolean not null,
  calibration_date date not null,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tcb_bilirubin_qc_r3439 enable row level security;

create index if not exists idx_tcb_bilirubin_qc_r3439_org on public.tcb_bilirubin_qc_r3439(organization_id);
create index if not exists idx_tcb_bilirubin_qc_r3439_date on public.tcb_bilirubin_qc_r3439(check_date);
create index if not exists idx_tcb_bilirubin_qc_r3439_verdict on public.tcb_bilirubin_qc_r3439(qc_verdict);

-- =============================================================================
-- TABLE 2: tcb_bilirubin_qc_capa_actions_r3439 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.tcb_bilirubin_qc_capa_actions_r3439 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.tcb_bilirubin_qc_r3439(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'reading_out_of_tolerance','tsb_correlation_low','optics_contamination','calibration_drift',
    'calibration_overdue','probe_damaged','phantom_check_failure','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'optical_window_soiled','led_source_degraded','detector_drift','probe_end_of_life',
    'calibration_expired','operator_technique_error','firmware_config_error',
    'pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'clean_optical_window','recalibrate_with_phantom','replace_probe_tip','replace_led_module',
    'replace_optical_sensor','update_firmware','retrain_nursing_staff',
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

alter table public.tcb_bilirubin_qc_capa_actions_r3439 enable row level security;

create index if not exists idx_tcb_bilirubin_capa_r3439_log on public.tcb_bilirubin_qc_capa_actions_r3439(qc_log_id);
create index if not exists idx_tcb_bilirubin_capa_r3439_status on public.tcb_bilirubin_qc_capa_actions_r3439(capa_status);

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

  -- 16 TcB QC check rows
  insert into public.tcb_bilirubin_qc_r3439 (
    organization_id, hospital_name, device_code, device_model, ward_or_dept, check_date,
    phantom_tcb_value, measured_tcb_value, deviation_pct, tsb_correlation_pct, optics_ok,
    probe_condition, calibration_current, calibration_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.dcode, q.dmodel, q.ward, q.cdate::date,
    q.phantom, q.measured, q.devpct, q.tsbpct, q.optics,
    q.probe, q.calcur, q.caldate::date, q.qv, q.nt
  from (values
    ('Apollo Chennai','TCB-APL-01','Draeger JM-105','nicu','2026-07-05',
     12.0,12.3,2.5,96.5,true,'good',true,'2026-06-15','pass','TcB within tolerance vs phantom, strong TSB correlation'),
    ('Apollo Chennai','TCB-APL-02','Philips BiliChek','postnatal_ward','2026-07-05',
     8.0,8.2,2.5,95.1,true,'good',true,'2026-06-15','pass','Postnatal ward jaundice meter QC nominal'),
    ('Fortis Gurgaon','TCB-FRT-11','Draeger JM-103','nicu','2026-07-02',
     15.0,16.4,9.3,88.0,true,'worn',true,'2026-05-20','conditional_pass','Deviation 9.3% approaching limit, probe worn — recheck scheduled'),
    ('Fortis Gurgaon','TCB-FRT-12','Konica Minolta JM-105','well_baby_nursery','2026-07-02',
     10.0,12.8,28.0,74.0,false,'cracked',false,'2026-04-10','fail','Optics contamination, 28% deviation, low TSB correlation, calibration overdue'),
    ('Manipal Bengaluru','TCB-MNP-21','Draeger JM-105','nicu','2026-06-28',
     11.0,11.2,1.8,97.2,true,'good',true,'2026-06-01','pass','QC pass post preventive maintenance'),
    ('Manipal Bengaluru','TCB-MNP-22','Philips BiliChek','pediatrics','2026-06-28',
     9.0,9.9,10.0,86.5,true,'worn',true,'2026-05-05','conditional_pass','Deviation 10% at limit — optical window cleaned, recheck scheduled'),
    ('AIIMS Delhi','TCB-AIM-31','Draeger JM-105','nicu','2026-06-25',
     13.0,13.4,3.1,94.8,true,'good',true,'2026-06-10','pass','AIIMS NICU jaundice meter QC pass'),
    ('AIIMS Delhi','TCB-AIM-32','Konica Minolta JM-105','labor_delivery','2026-06-25',
     7.0,9.1,30.0,70.0,false,'replace_due',false,'2026-03-22','fail','Detector drift, 30% deviation, optics fail, probe replace-due'),
    ('CMC Vellore','TCB-CMC-41','Draeger JM-103','postnatal_ward','2026-06-20',
     10.0,10.3,3.0,95.5,true,'good',true,'2026-06-02','pass','QC pass, correlation strong'),
    ('CMC Vellore','TCB-CMC-42','Philips BiliChek','nicu','2026-06-20',
     14.0,15.1,7.9,90.0,true,'good',false,'2026-04-18','conditional_pass','Accuracy acceptable but calibration overdue — recal ordered'),
    ('KIMS Hyderabad','TCB-KIM-51','Draeger JM-105','nicu','2026-05-30',
     12.0,12.1,0.8,98.0,true,'good',true,'2026-05-15','pass','QC pass, excellent correlation'),
    ('KIMS Hyderabad','TCB-KIM-52','Konica Minolta JM-105','well_baby_nursery','2026-05-30',
     8.0,8.9,11.3,84.0,true,'worn',true,'2026-05-01','conditional_pass','Deviation 11.3% over limit — probe worn, cleaning done, verify'),
    ('Yashoda Hyderabad','TCB-YSH-61','Draeger JM-103','nicu','2026-05-28',
     11.0,11.4,3.6,93.0,true,'good',true,'2026-05-10','pass','Yashoda NICU meter nominal'),
    ('Kokilaben Mumbai','TCB-KKB-71','Philips BiliChek','labor_delivery','2026-05-25',
     9.0,12.2,35.6,66.0,false,'cracked',false,'2026-02-14','fail','Cracked probe, LED degraded, 35.6% deviation — removed for service'),
    ('Rainbow Hyderabad','TCB-RNB-81','Draeger JM-105','nicu','2026-07-08',
     13.0,13.2,1.5,97.0,true,'good',true,'2026-06-20','pass','Rainbow Children NICU meter QC pass'),
    ('Rainbow Hyderabad','TCB-RNB-82','Konica Minolta JM-105','pediatrics','2026-07-08',
     10.0,11.5,15.0,80.0,true,'worn',true,'2026-05-18','conditional_pass','Deviation 15% out of tolerance — optical window cleaning + recheck')
  ) as q(hosp, dcode, dmodel, ward, cdate, phantom, measured, devpct, tsbpct, optics, probe, calcur, caldate, qv, nt);

  -- CAPA seed — attach to specific checks via device_code
  insert into public.tcb_bilirubin_qc_capa_actions_r3439 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TCB-FRT-11','reading_out_of_tolerance','probe_end_of_life','replace_probe_tip','in_progress','iso_13485_deviation','2026-07-06',null,9500.00,'Probe worn — replacement tip ordered, recheck pending'),
    ('TCB-FRT-12','optics_contamination','optical_window_soiled','clean_optical_window','escalated','patient_safety_alert','2026-07-05',null,3000.00,'Optics contamination with 28% deviation — escalated, unit quarantined'),
    ('TCB-MNP-22','reading_out_of_tolerance','operator_technique_error','retrain_nursing_staff','verification_pending','internal_only','2026-07-04',null,0.00,'Technique-related variance — nursing retrained, verify next audit'),
    ('TCB-AIM-32','tsb_correlation_low','detector_drift','replace_optical_sensor','open','cdsco_notifiable','2026-07-08',null,42000.00,'Detector drift, 30% deviation — optical sensor replacement scheduled'),
    ('TCB-CMC-42','calibration_overdue','calibration_expired','recalibrate_with_phantom','closed','nabh_finding','2026-06-28','2026-06-24',5000.00,'Recalibrated with phantom set — verdict restored to pass'),
    ('TCB-KIM-52','reading_out_of_tolerance','optical_window_soiled','clean_optical_window','closed','internal_only','2026-06-05','2026-06-02',1500.00,'Optical window cleaned — deviation back within tolerance'),
    ('TCB-KKB-71','phantom_check_failure','led_source_degraded','replace_led_module','overdue','cdsco_notifiable','2026-06-10',null,28000.00,'LED module replacement past target — vendor delay, unit out of service'),
    ('TCB-RNB-82','reading_out_of_tolerance','probe_end_of_life','replace_probe_tip','open','nabh_finding','2026-07-15',null,9500.00,'Deviation 15% out of tolerance — probe tip replacement pending')
  ) as q(dcode, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.tcb_bilirubin_qc_r3439 e
    on e.organization_id = v_org_id and e.device_code = q.dcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3439_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tcb_bilirubin_qc_r3439)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tcb_bilirubin_qc_r3439 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3439_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3439_qc_verdict_rollup() to authenticated;

-- 2) Device-model QC scorecard
create or replace function public.founder_r3439_device_model_scorecard()
returns table(
  device_model text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  optics_fail bigint,
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
    count(*) filter (where l.optics_ok = false)::bigint,
    count(*) filter (where l.deviation_pct > 10)::bigint,
    count(*) filter (where l.calibration_current = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.tcb_bilirubin_qc_r3439 l
  group by l.device_model
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3439_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3439_device_model_scorecard() to authenticated;

-- 3) Ward × verdict matrix
create or replace function public.founder_r3439_ward_verdict_matrix()
returns table(ward_or_dept text, qc_verdict text, checks bigint, avg_deviation_pct numeric, avg_tsb_correlation_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ward_or_dept, l.qc_verdict, count(*)::bigint,
    round(avg(l.deviation_pct), 2),
    round(avg(l.tsb_correlation_pct), 2)
  from public.tcb_bilirubin_qc_r3439 l
  group by l.ward_or_dept, l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3439_ward_verdict_matrix() from public, anon;
grant execute on function public.founder_r3439_ward_verdict_matrix() to authenticated;

-- 4) Monthly calibration / accuracy trend
create or replace function public.founder_r3439_monthly_accuracy_trend()
returns table(month text, checks bigint, passed bigint, failed bigint, avg_deviation_pct numeric, avg_tsb_correlation_pct numeric, calibration_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.check_date), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'fail')::bigint,
    round(avg(l.deviation_pct), 2),
    round(avg(l.tsb_correlation_pct), 2),
    count(*) filter (where l.calibration_current = false)::bigint
  from public.tcb_bilirubin_qc_r3439 l
  group by date_trunc('month', l.check_date)
  order by date_trunc('month', l.check_date) desc;
end;
$$;

revoke execute on function public.founder_r3439_monthly_accuracy_trend() from public, anon;
grant execute on function public.founder_r3439_monthly_accuracy_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3439_capa_status_board()
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
  from public.tcb_bilirubin_qc_capa_actions_r3439 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3439_capa_status_board() from public, anon;
grant execute on function public.founder_r3439_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3439_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tcb_bilirubin_qc_capa_actions_r3439)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tcb_bilirubin_qc_capa_actions_r3439 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3439_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3439_root_cause_pareto() to authenticated;

-- 7) Accuracy-impact digest (by regulatory impact)
create or replace function public.founder_r3439_accuracy_impact_digest()
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
  from public.tcb_bilirubin_qc_capa_actions_r3439 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3439_accuracy_impact_digest() from public, anon;
grant execute on function public.founder_r3439_accuracy_impact_digest() to authenticated;

-- 8) High-risk QC queue (out-of-tolerance / failed)
create or replace function public.founder_r3439_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  device_model text,
  ward_or_dept text,
  check_date date,
  qc_verdict text,
  deviation_pct numeric,
  tsb_correlation_pct numeric,
  probe_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.device_model, l.ward_or_dept, l.check_date,
    l.qc_verdict, l.deviation_pct, l.tsb_correlation_pct, l.probe_condition, l.notes
  from public.tcb_bilirubin_qc_r3439 l
  where l.qc_verdict in ('conditional_pass','fail')
     or l.optics_ok = false
     or l.calibration_current = false
     or l.deviation_pct > 10
     or l.tsb_correlation_pct < 85
     or l.probe_condition in ('cracked','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3439_high_risk_queue() from public, anon;
grant execute on function public.founder_r3439_high_risk_queue() to authenticated;
