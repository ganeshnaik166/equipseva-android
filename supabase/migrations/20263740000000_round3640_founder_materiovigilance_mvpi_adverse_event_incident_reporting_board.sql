-- Round 3640: Founder Materiovigilance (MvPI) Adverse-Event / Incident Reporting Board
-- Materiovigilance (MvPI/CDSCO) adverse-event & device-malfunction incident reporting — per report:
-- event type × severity × report status × time-to-report × patients affected × CDSCO notification ×
-- root-cause identification × CAPA linkage × trend direction × CAPA closure.

-- =============================================================================
-- TABLE 1: materiovigilance_r3640 — per-report adverse-event / incident records
-- =============================================================================
create table if not exists public.materiovigilance_r3640 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  report_ref text not null,
  device_name text not null,
  period_month date not null,
  event_type text not null check (event_type in (
    'death','serious_injury','malfunction','near_miss','no_harm'
  )),
  severity text not null check (severity in (
    'critical','major','moderate','minor'
  )),
  days_to_report int not null,
  patients_affected int not null,
  reported_to_cdsco boolean not null,
  root_cause_identified boolean not null,
  capa_linked boolean not null,
  report_status text not null check (report_status in (
    'submitted','under_investigation','capa_initiated','closed','overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.materiovigilance_r3640 enable row level security;

create index if not exists idx_materiovigilance_r3640_org on public.materiovigilance_r3640(organization_id);
create index if not exists idx_materiovigilance_r3640_month on public.materiovigilance_r3640(period_month);
create index if not exists idx_materiovigilance_r3640_status on public.materiovigilance_r3640(report_status);

-- =============================================================================
-- TABLE 2: materiovigilance_capa_actions_r3640 — CAPA & regulatory follow-up
-- =============================================================================
create table if not exists public.materiovigilance_capa_actions_r3640 (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.materiovigilance_r3640(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'device_malfunction','use_error','labeling_deficiency','software_anomaly','material_degradation',
    'sterility_breach','battery_power_failure','sensor_measurement_error','mechanical_failure','biocompatibility_reaction'
  )),
  root_cause text not null check (root_cause in (
    'design_flaw','manufacturing_defect','component_wear','improper_maintenance','user_handling_error',
    'storage_condition_breach','software_bug','supplier_quality_issue','pending_investigation','end_of_life'
  )),
  corrective_action text not null check (corrective_action in (
    'field_safety_corrective_action','device_recall','software_update','design_change','supplier_requalification',
    'user_retraining','labeling_update','preventive_maintenance','quarantine_and_replace','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','mdr_reportable','fsca_issued','recall_class_a','none','internal_only'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.materiovigilance_capa_actions_r3640 enable row level security;

create index if not exists idx_materiovigilance_capa_r3640_report on public.materiovigilance_capa_actions_r3640(report_id);
create index if not exists idx_materiovigilance_capa_r3640_status on public.materiovigilance_capa_actions_r3640(capa_status);

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

  -- 16 incident report rows
  insert into public.materiovigilance_r3640 (
    organization_id, report_ref, device_name, period_month, event_type, severity,
    days_to_report, patients_affected, reported_to_cdsco, root_cause_identified, capa_linked,
    report_status, trend_dir, notes
  )
  select v_org_id, q.rref, q.dname, q.pmon::date, q.etype, q.sev,
    q.d2r, q.paff, q.rcdsco, q.rci, q.clink,
    q.rstat, q.tdir, q.nt
  from (values
    ('MVPI-2026-001','ICU Ventilator','2026-07-01','malfunction','major',
     5,1,true,true,true,'capa_initiated','improving','Flow sensor gave erratic tidal-volume readings during use'),
    ('MVPI-2026-002','Infusion Pump','2026-07-01','serious_injury','critical',
     3,2,true,true,true,'under_investigation','worsening','Over-delivery event — patient required clinical intervention'),
    ('MVPI-2026-003','Patient Monitor','2026-06-01','malfunction','minor',
     12,0,false,true,false,'closed','stable','SpO2 module intermittently blanked — resolved via firmware update'),
    ('MVPI-2026-004','Dialysis Machine','2026-06-01','serious_injury','critical',
     2,1,true,true,true,'capa_initiated','improving','Blood-leak detector false-negative during haemodialysis session'),
    ('MVPI-2026-005','Defibrillator','2026-06-01','malfunction','major',
     8,0,true,false,false,'under_investigation','worsening','Failed to charge on first attempt during code-blue drill'),
    ('MVPI-2026-006','Syringe Pump','2026-05-01','near_miss','moderate',
     6,0,false,true,true,'closed','stable','Occlusion alarm delayed by 40s — near miss, no patient harm'),
    ('MVPI-2026-007','Anesthesia Workstation','2026-05-01','malfunction','major',
     15,0,true,true,true,'overdue','worsening','Vaporizer output concentration drifted beyond labelled spec'),
    ('MVPI-2026-008','C-Arm','2026-05-01','no_harm','minor',
     20,0,false,false,false,'closed','stable','Image intensifier flicker — cosmetic only, no patient impact'),
    ('MVPI-2026-009','ECG Machine','2026-07-01','malfunction','moderate',
     4,0,false,true,true,'capa_initiated','improving','Lead-off detection unreliable on limb leads'),
    ('MVPI-2026-010','Pulse Oximeter','2026-06-01','no_harm','minor',
     9,0,false,true,false,'closed','stable','Probe cable insulation cracking noted on inspection'),
    ('MVPI-2026-011','Infusion Pump','2026-07-01','death','critical',
     1,1,true,true,true,'under_investigation','worsening','Free-flow event during inter-ward transport — fatal outcome under review'),
    ('MVPI-2026-012','CT Scanner','2026-05-01','malfunction','major',
     18,0,true,false,false,'overdue','worsening','Gantry rotation fault mid-scan — repeat exposure required'),
    ('MVPI-2026-013','Warming Blanket','2026-06-01','serious_injury','major',
     7,1,true,true,true,'capa_initiated','stable','Forced-air blanket hot-spot burn — thermostat fault suspected'),
    ('MVPI-2026-014','Ultrasound Scanner','2026-06-01','no_harm','minor',
     25,0,false,false,false,'closed','stable','Probe image dropout — piezo element degradation'),
    ('MVPI-2026-015','Surgical Stapler','2026-07-01','serious_injury','critical',
     2,1,true,true,true,'under_investigation','worsening','Misfire with incomplete staple line — re-operation needed'),
    ('MVPI-2026-016','Transport Ventilator','2026-05-01','malfunction','moderate',
     11,0,true,true,true,'submitted','improving','Battery drained faster than rated endurance during transfer')
  ) as q(rref, dname, pmon, etype, sev, d2r, paff, rcdsco, rci, clink, rstat, tdir, nt);

  -- CAPA seed — attach to specific reports via report_ref
  insert into public.materiovigilance_capa_actions_r3640 (
    report_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.ownr, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('MVPI-2026-002','device_malfunction','design_flaw','field_safety_corrective_action','in_progress','fsca_issued','QA Lead - Ananya','2026-08-10',null,250000.00,'FSCA drafted for over-delivery risk — awaiting CDSCO acknowledgement'),
    ('MVPI-2026-004','sensor_measurement_error','manufacturing_defect','design_change','in_progress','cdsco_notifiable','R&D - Rakesh','2026-08-15',null,180000.00,'Blood-leak detector redesign under design-verification'),
    ('MVPI-2026-011','device_malfunction','design_flaw','device_recall','escalated','recall_class_a','RA Head - Meera','2026-08-05',null,900000.00,'Class A recall initiated for free-flow risk — batch traceback ongoing'),
    ('MVPI-2026-007','material_degradation','component_wear','preventive_maintenance','overdue','cdsco_notifiable','Service - Vikram','2026-07-20',null,65000.00,'Vaporizer seal replacement program past target closure date'),
    ('MVPI-2026-001','sensor_measurement_error','supplier_quality_issue','supplier_requalification','verification_pending','mdr_reportable','SQA - Priya','2026-08-01',null,45000.00,'Flow-sensor supplier requalified — verifying incoming lots'),
    ('MVPI-2026-013','device_malfunction','manufacturing_defect','quarantine_and_replace','closed','fsca_issued','QA Lead - Ananya','2026-07-15','2026-07-12',120000.00,'Faulty thermostat batch quarantined and affected units replaced'),
    ('MVPI-2026-015','mechanical_failure','manufacturing_defect','device_recall','open','recall_class_a','RA Head - Meera','2026-08-20',null,540000.00,'Stapler misfire — recall lot scope being defined'),
    ('MVPI-2026-009','software_anomaly','software_bug','software_update','closed','internal_only','SW - Nikhil','2026-07-18','2026-07-16',30000.00,'Lead-off detection firmware patch deployed and verified')
  ) as q(rref, fc, rc, ca, cst, ri, ownr, tcd, acd, cost, nt)
  join public.materiovigilance_r3640 e
    on e.organization_id = v_org_id and e.report_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Report-status distribution
create or replace function public.founder_r3640_report_status_rollup()
returns table(report_status text, reports bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.materiovigilance_r3640)
  select l.report_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.materiovigilance_r3640 l
  group by l.report_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3640_report_status_rollup() from public, anon;
grant execute on function public.founder_r3640_report_status_rollup() to authenticated;

-- 2) Event-type scorecard
create or replace function public.founder_r3640_event_type_scorecard()
returns table(
  event_type text,
  total_reports bigint,
  critical bigint,
  overdue bigint,
  reported_cdsco bigint,
  capa_linked_reports bigint,
  avg_days_to_report numeric,
  total_patients bigint,
  cdsco_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.event_type,
    count(*)::bigint,
    count(*) filter (where l.severity = 'critical')::bigint,
    count(*) filter (where l.report_status = 'overdue')::bigint,
    count(*) filter (where l.reported_to_cdsco = true)::bigint,
    count(*) filter (where l.capa_linked = true)::bigint,
    round(avg(l.days_to_report), 1),
    coalesce(sum(l.patients_affected),0)::bigint,
    round(100.0 * count(*) filter (where l.reported_to_cdsco = true)::numeric / nullif(count(*),0), 1)
  from public.materiovigilance_r3640 l
  group by l.event_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3640_event_type_scorecard() from public, anon;
grant execute on function public.founder_r3640_event_type_scorecard() to authenticated;

-- 3) Event-type × severity matrix
create or replace function public.founder_r3640_event_type_severity_matrix()
returns table(event_type text, severity text, reports bigint, closed bigint, overdue bigint, avg_days_to_report numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.event_type, l.severity, count(*)::bigint,
    count(*) filter (where l.report_status = 'closed')::bigint,
    count(*) filter (where l.report_status = 'overdue')::bigint,
    round(avg(l.days_to_report), 1)
  from public.materiovigilance_r3640 l
  group by l.event_type, l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3640_event_type_severity_matrix() from public, anon;
grant execute on function public.founder_r3640_event_type_severity_matrix() to authenticated;

-- 4) Monthly incident trend
create or replace function public.founder_r3640_monthly_incident_trend()
returns table(period_month date, reports bigint, closed bigint, overdue bigint, total_patients bigint, avg_days_to_report numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.report_status = 'closed')::bigint,
    count(*) filter (where l.report_status = 'overdue')::bigint,
    coalesce(sum(l.patients_affected),0)::bigint,
    round(avg(l.days_to_report), 1)
  from public.materiovigilance_r3640 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3640_monthly_incident_trend() from public, anon;
grant execute on function public.founder_r3640_monthly_incident_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3640_capa_status_board()
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
  from public.materiovigilance_capa_actions_r3640 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3640_capa_status_board() from public, anon;
grant execute on function public.founder_r3640_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3640_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.materiovigilance_capa_actions_r3640)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.materiovigilance_capa_actions_r3640 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3640_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3640_root_cause_pareto() to authenticated;

-- 7) Severity-impact digest
create or replace function public.founder_r3640_severity_impact_digest()
returns table(severity text, reports bigint, total_patients bigint, reported_cdsco bigint, open_reports bigint, avg_days_to_report numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.severity, count(*)::bigint,
    coalesce(sum(l.patients_affected),0)::bigint,
    count(*) filter (where l.reported_to_cdsco = true)::bigint,
    count(*) filter (where l.report_status in ('submitted','under_investigation','capa_initiated','overdue'))::bigint,
    round(avg(l.days_to_report), 1)
  from public.materiovigilance_r3640 l
  group by l.severity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3640_severity_impact_digest() from public, anon;
grant execute on function public.founder_r3640_severity_impact_digest() to authenticated;

-- 8) High-risk queue (overdue / under-investigation / critical)
create or replace function public.founder_r3640_high_risk_queue()
returns table(
  report_ref text,
  device_name text,
  event_type text,
  severity text,
  period_month date,
  report_status text,
  days_to_report int,
  patients_affected int,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.report_ref, l.device_name, l.event_type, l.severity, l.period_month,
    l.report_status, l.days_to_report, l.patients_affected, l.trend_dir, l.notes
  from public.materiovigilance_r3640 l
  where l.report_status in ('overdue','under_investigation')
     or l.severity = 'critical'
     or l.event_type in ('death','serious_injury')
     or l.reported_to_cdsco = false
     or l.root_cause_identified = false
     or l.capa_linked = false
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.severity;
end;
$$;

revoke execute on function public.founder_r3640_high_risk_queue() from public, anon;
grant execute on function public.founder_r3640_high_risk_queue() to authenticated;
