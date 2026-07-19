-- Round 3344: Engineer Remote-Monitoring Alert Triage & Proactive-Intervention Tracker
-- Connected-equipment alert ops — equipment type × alert source × severity × category × SLA triage × triage action × prevented breakdown × intervention verdict × CAPA

-- =============================================================================
-- TABLE 1: remote_monitoring_alert_r3344 — per-alert triage & intervention log
-- =============================================================================
create table if not exists public.remote_monitoring_alert_r3344 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  equipment_type text not null check (equipment_type in (
    'imaging','dialysis','patient_monitoring','ventilator_fleet','lab_analyzer','sterilizer'
  )),
  device_code text not null,
  alert_source text not null check (alert_source in (
    'device_telemetry','iot_sensor','predictive_model','customer_reported','threshold_breach'
  )),
  alert_severity text not null check (alert_severity in (
    'critical_imminent','high','medium','informational'
  )),
  alert_date date not null,
  alert_category text not null check (alert_category in (
    'component_wear','temperature_drift','error_code','consumable_low','calibration_due','network_offline'
  )),
  triaged_within_sla boolean not null default false,
  triage_action text not null check (triage_action in (
    'remote_fix','dispatch_scheduled','parts_ordered','monitor_watch','false_alert','customer_advised'
  )),
  prevented_breakdown boolean not null default false,
  response_hours numeric(6,2),
  intervention_verdict text not null check (intervention_verdict in (
    'resolved_remotely','prevented_onsite','breakdown_occurred','false_positive','open_monitoring'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_monitoring_alert_r3344 enable row level security;

create index if not exists idx_rma_r3344_org on public.remote_monitoring_alert_r3344(organization_id);
create index if not exists idx_rma_r3344_date on public.remote_monitoring_alert_r3344(alert_date);
create index if not exists idx_rma_r3344_verdict on public.remote_monitoring_alert_r3344(intervention_verdict);

-- =============================================================================
-- TABLE 2: remote_monitoring_alert_capa_actions_r3344 — model-tuning / process CAPA
-- =============================================================================
create table if not exists public.remote_monitoring_alert_capa_actions_r3344 (
  id uuid primary key default gen_random_uuid(),
  alert_log_id uuid not null references public.remote_monitoring_alert_r3344(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'false_positive_alert','missed_alert','late_triage','sla_breach',
    'model_drift','sensor_miscalibration','alert_fatigue','escalation_gap'
  )),
  root_cause text not null check (root_cause in (
    'threshold_too_tight','threshold_too_loose','model_needs_retraining','sensor_fault',
    'connectivity_gap','staffing_gap','process_gap','vendor_firmware_bug','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'retune_threshold','retrain_predictive_model','replace_sensor','fix_connectivity',
    'add_triage_staff','update_runbook','firmware_update','escalate_to_oem','dispatch_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'sla_penalty_risk','contract_breach','patient_safety_alert','none','internal_only','warranty_claim'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.remote_monitoring_alert_capa_actions_r3344 enable row level security;

create index if not exists idx_rma_capa_r3344_log on public.remote_monitoring_alert_capa_actions_r3344(alert_log_id);
create index if not exists idx_rma_capa_r3344_status on public.remote_monitoring_alert_capa_actions_r3344(capa_status);

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

  -- 14 alert-triage rows
  insert into public.remote_monitoring_alert_r3344 (
    organization_id, hospital_name, equipment_type, device_code, alert_source,
    alert_severity, alert_date, alert_category, triaged_within_sla, triage_action,
    prevented_breakdown, response_hours, intervention_verdict, notes
  )
  select v_org_id, q.hosp, q.etype, q.dev, q.src,
    q.sev, q.adate::date, q.cat, q.sla, q.action,
    q.prevented, q.rhrs, q.verdict, q.nt
  from (values
    ('Apollo Chennai Greams Road','imaging','APL-CT-01','predictive_model','high','2026-07-16','component_wear',true,'dispatch_scheduled',true,3.5,'prevented_onsite','CT tube arc-count predicted end-of-life — tube swap scheduled before failure'),
    ('Apollo Chennai Greams Road','dialysis','APL-DIA-14','device_telemetry','medium','2026-07-16','consumable_low',true,'remote_fix',true,0.5,'resolved_remotely','Concentrate-low alarm — remote reset and biomed restocked same shift'),
    ('Fortis Gurgaon','patient_monitoring','FRT-MON-07','iot_sensor','critical_imminent','2026-07-15','temperature_drift',true,'dispatch_scheduled',true,1.2,'prevented_onsite','Central-station rack over-temp — cooling fan replaced pre-failure'),
    ('Fortis Gurgaon','ventilator_fleet','FRT-VEN-22','device_telemetry','high','2026-07-15','error_code',false,'parts_ordered',false,9.5,'breakdown_occurred','Blower error E-041 missed SLA — ventilator down before parts arrived'),
    ('Manipal Bengaluru Old Airport Rd','lab_analyzer','MNP-LAB-05','threshold_breach','medium','2026-07-14','calibration_due',true,'customer_advised',true,2.0,'resolved_remotely','QC drift flagged — advised recalibration, analyzer back in range'),
    ('Manipal Bengaluru Old Airport Rd','sterilizer','MNP-STE-03','iot_sensor','high','2026-07-14','temperature_drift',true,'dispatch_scheduled',true,4.0,'prevented_onsite','Autoclave chamber RTD drift — sensor replaced before cycle failure'),
    ('AIIMS Delhi Ansari Nagar','imaging','AIM-MRI-02','predictive_model','critical_imminent','2026-07-13','component_wear',false,'dispatch_scheduled',false,14.0,'breakdown_occurred','MRI chiller compressor predicted failure — dispatch late, imaging down 6h'),
    ('AIIMS Delhi Ansari Nagar','patient_monitoring','AIM-MON-11','customer_reported','medium','2026-07-13','network_offline',true,'remote_fix',true,0.8,'resolved_remotely','Bedside monitors offline — remote network-switch reboot restored telemetry'),
    ('CMC Vellore','dialysis','CMC-DIA-09','device_telemetry','high','2026-07-12','component_wear',true,'parts_ordered',true,5.5,'prevented_onsite','RO pump vibration trend — pump rebuilt before membrane damage'),
    ('CMC Vellore','ventilator_fleet','CMC-VEN-18','predictive_model','informational','2026-07-12','calibration_due',true,'monitor_watch',true,0.0,'open_monitoring','O2 sensor aging trend — under watch, no intervention yet'),
    ('KIMS Hyderabad','lab_analyzer','KIM-LAB-21','threshold_breach','high','2026-07-11','error_code',false,'false_alert',false,6.0,'false_positive','Recurring reagent-temp alarm — investigation found sensor noise, no real fault'),
    ('KIMS Hyderabad','imaging','KIM-CT-04','iot_sensor','medium','2026-07-11','network_offline',true,'remote_fix',true,0.3,'resolved_remotely','CT console DICOM link down — remote gateway restart restored connectivity'),
    ('Narayana Health Bengaluru','sterilizer','NAR-STE-07','device_telemetry','critical_imminent','2026-07-10','error_code',false,'dispatch_scheduled',false,11.0,'breakdown_occurred','Door-seal pressure fault ignored overnight — sterilizer failed mid-cycle'),
    ('Medanta Gurugram','ventilator_fleet','MED-VEN-30','predictive_model','high','2026-07-10','component_wear',true,'dispatch_scheduled',true,3.0,'prevented_onsite','Turbine bearing wear predicted — proactive turbine swap during off-shift')
  ) as q(hosp, etype, dev, src, sev, adate, cat, sla, action, prevented, rhrs, verdict, nt);

  -- CAPA seed — attach to specific alerts via device_code
  insert into public.remote_monitoring_alert_capa_actions_r3344 (
    alert_log_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('FRT-VEN-22','sla_breach','staffing_gap','add_triage_staff','open','sla_penalty_risk','2026-07-22',null,45000.00,'Night-shift triage gap — vent breakdown missed SLA; adding on-call biomed'),
    ('AIM-MRI-02','late_triage','process_gap','update_runbook','in_progress','contract_breach','2026-07-20',null,60000.00,'Predictive alert not actioned in time — chiller dispatch SOP updated'),
    ('NAR-STE-07','missed_alert','process_gap','update_runbook','escalated','patient_safety_alert','2026-07-19',null,38000.00,'Overnight critical alert not escalated — sterilizer failed mid-cycle; escalation path fixed'),
    ('KIM-LAB-21','false_positive_alert','threshold_too_tight','retune_threshold','verification_pending','internal_only','2026-07-18',null,5000.00,'Reagent-temp threshold too tight causing noise alarms — retuned, verifying'),
    ('KIM-LAB-21','model_drift','model_needs_retraining','retrain_predictive_model','open','internal_only','2026-07-25',null,15000.00,'Analyzer alert model over-firing — scheduled retraining with 90-day data'),
    ('CMC-VEN-18','sensor_miscalibration','sensor_fault','replace_sensor','closed','warranty_claim','2026-07-14','2026-07-13',8000.00,'O2 sensor aging confirmed — replaced under warranty proactively'),
    ('FRT-VEN-22','escalation_gap','vendor_firmware_bug','firmware_update','overdue','sla_penalty_risk','2026-07-14',null,0.00,'Blower E-041 recurring — OEM firmware patch pending past target date')
  ) as q(dev, fc, rc, ca, cst, bi, tcd, acd, cost, nt)
  join public.remote_monitoring_alert_r3344 e
    on e.organization_id = v_org_id and e.device_code = q.dev;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Intervention verdict distribution
create or replace function public.founder_r3344_verdict_rollup()
returns table(intervention_verdict text, alerts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_monitoring_alert_r3344)
  select l.intervention_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.remote_monitoring_alert_r3344 l
  group by l.intervention_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3344_verdict_rollup() from public, anon;
grant execute on function public.founder_r3344_verdict_rollup() to authenticated;

-- 2) Hospital-level triage scorecard
create or replace function public.founder_r3344_hospital_scorecard()
returns table(
  hospital_name text,
  total_alerts bigint,
  resolved_remotely bigint,
  prevented bigint,
  breakdowns bigint,
  false_positives bigint,
  sla_met bigint,
  prevented_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.intervention_verdict = 'resolved_remotely')::bigint,
    count(*) filter (where l.intervention_verdict = 'prevented_onsite')::bigint,
    count(*) filter (where l.intervention_verdict = 'breakdown_occurred')::bigint,
    count(*) filter (where l.intervention_verdict = 'false_positive')::bigint,
    count(*) filter (where l.triaged_within_sla)::bigint,
    round(100.0 * count(*) filter (where l.prevented_breakdown)::numeric / nullif(count(*),0), 1)
  from public.remote_monitoring_alert_r3344 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3344_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3344_hospital_scorecard() to authenticated;

-- 3) Equipment type × alert source matrix
create or replace function public.founder_r3344_equipment_source_matrix()
returns table(equipment_type text, alert_source text, alerts bigint, prevented bigint, breakdowns bigint, avg_response_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.equipment_type, l.alert_source, count(*)::bigint,
    count(*) filter (where l.prevented_breakdown)::bigint,
    count(*) filter (where l.intervention_verdict = 'breakdown_occurred')::bigint,
    round(avg(l.response_hours), 2)
  from public.remote_monitoring_alert_r3344 l
  group by l.equipment_type, l.alert_source
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3344_equipment_source_matrix() from public, anon;
grant execute on function public.founder_r3344_equipment_source_matrix() to authenticated;

-- 4) Daily alert trend
create or replace function public.founder_r3344_daily_alert_trend()
returns table(alert_date date, alerts bigint, critical bigint, breakdowns bigint, sla_met bigint, avg_response_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.alert_date,
    count(*)::bigint,
    count(*) filter (where l.alert_severity = 'critical_imminent')::bigint,
    count(*) filter (where l.intervention_verdict = 'breakdown_occurred')::bigint,
    count(*) filter (where l.triaged_within_sla)::bigint,
    round(avg(l.response_hours), 2)
  from public.remote_monitoring_alert_r3344 l
  group by l.alert_date
  order by l.alert_date desc;
end;
$$;

revoke execute on function public.founder_r3344_daily_alert_trend() from public, anon;
grant execute on function public.founder_r3344_daily_alert_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3344_capa_status_board()
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
  from public.remote_monitoring_alert_capa_actions_r3344 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3344_capa_status_board() from public, anon;
grant execute on function public.founder_r3344_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3344_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.remote_monitoring_alert_capa_actions_r3344)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.remote_monitoring_alert_capa_actions_r3344 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3344_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3344_root_cause_pareto() to authenticated;

-- 7) Business-impact digest
create or replace function public.founder_r3344_business_impact_digest()
returns table(business_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.business_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.remote_monitoring_alert_capa_actions_r3344 c
  group by c.business_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3344_business_impact_digest() from public, anon;
grant execute on function public.founder_r3344_business_impact_digest() to authenticated;

-- 8) High-risk alert queue (top individual concerns)
create or replace function public.founder_r3344_high_risk_queue()
returns table(
  hospital_name text,
  device_code text,
  equipment_type text,
  alert_date date,
  alert_severity text,
  alert_category text,
  triage_action text,
  intervention_verdict text,
  response_hours numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.device_code, l.equipment_type, l.alert_date,
    l.alert_severity, l.alert_category, l.triage_action, l.intervention_verdict,
    l.response_hours, l.notes
  from public.remote_monitoring_alert_r3344 l
  where l.alert_severity in ('critical_imminent','high')
     or l.intervention_verdict in ('breakdown_occurred','open_monitoring')
     or l.triaged_within_sla = false
     or l.prevented_breakdown = false
  order by l.alert_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3344_high_risk_queue() from public, anon;
grant execute on function public.founder_r3344_high_risk_queue() to authenticated;
