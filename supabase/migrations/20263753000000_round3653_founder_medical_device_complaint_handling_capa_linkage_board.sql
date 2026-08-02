-- Round 3653: Founder Medical-Device Complaint-Handling / CAPA-Linkage Board
-- Complaint-handling discipline — intake channel × complaint category × device × monthly volume ×
-- investigation % × CAPA linkage % × days-to-close × reportable events × backlog aging × CAPA actions

-- =============================================================================
-- TABLE 1: complaint_capa_r3653 — per-category monthly complaint-handling records
-- =============================================================================
create table if not exists public.complaint_capa_r3653 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  record_code text not null,
  complaint_category text not null,
  device_name text not null,
  period_month date not null,
  complaints_received int not null,
  investigations_opened int not null,
  investigation_pct numeric(5,2),
  capa_linked int not null,
  capa_linkage_pct numeric(5,2),
  avg_days_to_close numeric(6,1),
  reportable_events int not null,
  trend_flag boolean not null,
  oldest_open_days int not null,
  intake_channel text not null check (intake_channel in (
    'field_engineer','hospital_direct','distributor','helpline','regulator'
  )),
  handling_status text not null check (handling_status in (
    'closed_on_time','on_track','investigation_backlog','capa_gap','overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.complaint_capa_r3653 enable row level security;

create index if not exists idx_complaint_capa_r3653_org on public.complaint_capa_r3653(organization_id);
create index if not exists idx_complaint_capa_r3653_month on public.complaint_capa_r3653(period_month);
create index if not exists idx_complaint_capa_r3653_status on public.complaint_capa_r3653(handling_status);

-- =============================================================================
-- TABLE 2: complaint_capa_capa_actions_r3653 — CAPA actions linked to complaint records
-- =============================================================================
create table if not exists public.complaint_capa_capa_actions_r3653 (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.complaint_capa_r3653(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'design_deficiency','component_failure','use_error','manufacturing_defect',
    'software_bug','labeling_inadequate','supplier_quality_issue','inadequate_training',
    'process_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'design_change','component_lot_replacement','software_patch','ifu_labeling_update',
    'field_safety_corrective_action','retraining_program','supplier_corrective_action',
    'process_sop_revision','enhanced_incoming_inspection','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.complaint_capa_capa_actions_r3653 enable row level security;

create index if not exists idx_complaint_capa_capa_r3653_link on public.complaint_capa_capa_actions_r3653(complaint_id);
create index if not exists idx_complaint_capa_capa_r3653_status on public.complaint_capa_capa_actions_r3653(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Handling-status distribution
create or replace function public.founder_r3653_handling_status_rollup()
returns table(handling_status text, records bigint, complaints bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.complaint_capa_r3653)
  select l.handling_status, count(*)::bigint,
         coalesce(sum(l.complaints_received),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.complaint_capa_r3653 l
  group by l.handling_status
  order by count(*) desc;
end;
$$;

-- 2) Intake-channel scorecard
create or replace function public.founder_r3653_intake_channel_scorecard()
returns table(
  intake_channel text,
  records bigint,
  complaints bigint,
  investigations bigint,
  capa_linked bigint,
  reportable_events bigint,
  avg_linkage_pct numeric,
  avg_days_to_close numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.intake_channel,
    count(*)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    coalesce(sum(l.investigations_opened),0)::bigint,
    coalesce(sum(l.capa_linked),0)::bigint,
    coalesce(sum(l.reportable_events),0)::bigint,
    round(avg(l.capa_linkage_pct), 1),
    round(avg(l.avg_days_to_close), 1)
  from public.complaint_capa_r3653 l
  group by l.intake_channel
  order by count(*) desc;
end;
$$;

-- 3) Intake-channel × handling-status matrix
create or replace function public.founder_r3653_channel_status_matrix()
returns table(intake_channel text, handling_status text, records bigint, complaints bigint, avg_linkage_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.intake_channel, l.handling_status, count(*)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    round(avg(l.capa_linkage_pct), 1)
  from public.complaint_capa_r3653 l
  group by l.intake_channel, l.handling_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly complaint trend
create or replace function public.founder_r3653_monthly_complaint_trend()
returns table(period_month date, records bigint, complaints bigint, investigations bigint, capa_linked bigint, reportable_events bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    coalesce(sum(l.investigations_opened),0)::bigint,
    coalesce(sum(l.capa_linked),0)::bigint,
    coalesce(sum(l.reportable_events),0)::bigint
  from public.complaint_capa_r3653 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3653_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.complaint_capa_capa_actions_r3653 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3653_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.complaint_capa_capa_actions_r3653)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.complaint_capa_capa_actions_r3653 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Backlog-impact digest by complaint category
create or replace function public.founder_r3653_backlog_impact_digest()
returns table(
  complaint_category text,
  records bigint,
  complaints bigint,
  reportable_events bigint,
  backlog_records bigint,
  max_oldest_open_days int,
  avg_linkage_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.complaint_category,
    count(*)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    coalesce(sum(l.reportable_events),0)::bigint,
    count(*) filter (where l.handling_status in ('investigation_backlog','capa_gap','overdue'))::bigint,
    max(l.oldest_open_days)::int,
    round(avg(l.capa_linkage_pct), 1)
  from public.complaint_capa_r3653 l
  group by l.complaint_category
  order by coalesce(sum(l.complaints_received),0) desc;
end;
$$;

-- 8) High-risk queue (capa_gap / overdue / worsening / aged backlog)
create or replace function public.founder_r3653_high_risk_queue()
returns table(
  record_code text,
  complaint_category text,
  device_name text,
  period_month date,
  intake_channel text,
  handling_status text,
  trend_dir text,
  capa_linkage_pct numeric,
  oldest_open_days int,
  reportable_events int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.record_code, l.complaint_category, l.device_name, l.period_month,
    l.intake_channel, l.handling_status, l.trend_dir,
    l.capa_linkage_pct, l.oldest_open_days, l.reportable_events, l.notes
  from public.complaint_capa_r3653 l
  where l.handling_status in ('capa_gap','overdue')
     or (l.trend_flag = true and l.trend_dir = 'worsening')
     or l.oldest_open_days > 60
  order by l.period_month desc, l.oldest_open_days desc;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only
-- =============================================================================
revoke all on function public.founder_r3653_handling_status_rollup() from public, anon;
revoke all on function public.founder_r3653_intake_channel_scorecard() from public, anon;
revoke all on function public.founder_r3653_channel_status_matrix() from public, anon;
revoke all on function public.founder_r3653_monthly_complaint_trend() from public, anon;
revoke all on function public.founder_r3653_capa_status_board() from public, anon;
revoke all on function public.founder_r3653_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3653_backlog_impact_digest() from public, anon;
revoke all on function public.founder_r3653_high_risk_queue() from public, anon;

grant execute on function public.founder_r3653_handling_status_rollup() to authenticated;
grant execute on function public.founder_r3653_intake_channel_scorecard() to authenticated;
grant execute on function public.founder_r3653_channel_status_matrix() to authenticated;
grant execute on function public.founder_r3653_monthly_complaint_trend() to authenticated;
grant execute on function public.founder_r3653_capa_status_board() to authenticated;
grant execute on function public.founder_r3653_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3653_backlog_impact_digest() to authenticated;
grant execute on function public.founder_r3653_high_risk_queue() to authenticated;

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

  -- 16 complaint-handling records
  insert into public.complaint_capa_r3653 (
    organization_id, record_code, complaint_category, device_name, period_month,
    complaints_received, investigations_opened, investigation_pct, capa_linked, capa_linkage_pct,
    avg_days_to_close, reportable_events, trend_flag, oldest_open_days,
    intake_channel, handling_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.ccat, q.dname, q.pmonth::date,
    q.crec, q.invop, q.invpct, q.clink, q.clpct,
    q.adtc, q.repev, q.tflag, q.oopen,
    q.ichan, q.hstat, q.tdir, q.nt
  from (values
    ('CMP-VENT-2607A','alarm_malfunction','ICU Ventilator VX-500','2026-07-01',
     14,14,100.00,12,85.71,18.4,1,false,22,'hospital_direct','on_track','improving',
     'Alarm complaints investigated same week; two CAPA linkages pending'),
    ('CMP-VENT-2606A','oxygen_sensor_drift','ICU Ventilator VX-500','2026-06-01',
     11,10,90.91,7,63.64,26.0,1,true,48,'field_engineer','capa_gap','worsening',
     'O2 sensor drift cluster — CAPA linkage below 70 percent threshold'),
    ('CMP-INF-2607A','flow_inaccuracy','Infusion Pump IP-220','2026-07-01',
     19,17,89.47,15,78.95,21.2,0,false,31,'distributor','on_track','stable',
     'Flow accuracy complaints steady; distributor intake dominates'),
    ('CMP-INF-2606A','occlusion_false_alarm','Infusion Pump IP-220','2026-06-01',
     23,18,78.26,11,47.83,35.6,0,true,74,'helpline','investigation_backlog','worsening',
     'Occlusion false-alarm backlog — five investigations not yet opened'),
    ('CMP-MON-2607A','ecg_lead_artifact','Patient Monitor PM-900','2026-07-01',
     9,9,100.00,9,100.00,12.1,0,false,10,'hospital_direct','closed_on_time','improving',
     'All lead-artifact complaints closed within SLA with CAPA linkage'),
    ('CMP-MON-2606A','display_blank','Patient Monitor PM-900','2026-06-01',
     6,6,100.00,5,83.33,19.8,0,false,17,'field_engineer','on_track','stable',
     'Display blanking traced to connector lot; one linkage open'),
    ('CMP-DIA-2607A','conductivity_alarm','Dialysis Machine DM-330','2026-07-01',
     12,11,91.67,8,66.67,29.4,1,true,52,'hospital_direct','capa_gap','worsening',
     'Conductivity alarm cluster; CAPA linkage lagging investigations'),
    ('CMP-DIA-2606A','blood_leak_detector','Dialysis Machine DM-330','2026-06-01',
     8,8,100.00,8,100.00,15.3,2,false,9,'regulator','closed_on_time','stable',
     'Two MDR-reportable blood-leak events closed with FSCA linkage'),
    ('CMP-DEF-2607A','battery_failure','Defibrillator DF-100','2026-07-01',
     16,13,81.25,9,56.25,41.7,2,true,88,'field_engineer','overdue','worsening',
     'Battery swelling complaints overdue — oldest open 88 days'),
    ('CMP-DEF-2606A','paddle_cable_fault','Defibrillator DF-100','2026-06-01',
     7,7,100.00,6,85.71,22.5,1,false,20,'distributor','on_track','improving',
     'Cable fault complaints on track; supplier CAPA in verification'),
    ('CMP-CARM-2607A','image_noise','C-Arm CA-700','2026-07-01',
     5,5,100.00,4,80.00,24.9,0,false,26,'hospital_direct','on_track','stable',
     'Image-noise complaints tied to detector lot; CAPA linked'),
    ('CMP-CARM-2606A','xray_tube_overheat','C-Arm CA-700','2026-06-01',
     4,3,75.00,2,50.00,38.2,1,true,65,'helpline','investigation_backlog','worsening',
     'Tube overheat complaint aging past 60 days without investigation'),
    ('CMP-SYR-2607A','keypad_unresponsive','Syringe Pump SP-110','2026-07-01',
     10,10,100.00,10,100.00,11.6,0,false,8,'helpline','closed_on_time','improving',
     'Keypad complaints closed on time after firmware patch CAPA'),
    ('CMP-VENT-2605A','humidifier_leak','ICU Ventilator VX-500','2026-05-01',
     9,9,100.00,9,100.00,16.8,0,false,6,'hospital_direct','closed_on_time','stable',
     'Humidifier leak complaints fully closed with process CAPA'),
    ('CMP-MON-2605A','spo2_probe_failure','Patient Monitor PM-900','2026-05-01',
     13,12,92.31,7,53.85,33.9,1,true,58,'distributor','capa_gap','stable',
     'SpO2 probe failures — supplier CAPA not yet linked to six complaints'),
    ('CMP-DIA-2605A','heparin_pump_stall','Dialysis Machine DM-330','2026-05-01',
     5,4,80.00,3,60.00,44.0,1,false,79,'regulator','overdue','stable',
     'Regulator-forwarded stall complaint overdue for closure evidence')
  ) as q(rcode, ccat, dname, pmonth, crec, invop, invpct, clink, clpct, adtc, repev, tflag, oopen, ichan, hstat, tdir, nt);

  -- 8 CAPA actions — attach to specific complaint records via record_code
  insert into public.complaint_capa_capa_actions_r3653 (
    complaint_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CMP-VENT-2606A','component_failure','component_lot_replacement','in_progress',
     185000.00,'Ravi Iyer (QA/RA)','2026-08-10',null,
     'O2 sensor lot recall in progress; replacement sensors dispatched'),
    ('CMP-INF-2606A','software_bug','software_patch','verification_pending',
     95000.00,'Meera Krishnan (Engineering)','2026-08-05',null,
     'Occlusion algorithm patch deployed to pilot fleet; monitoring alarm rates'),
    ('CMP-DEF-2607A','supplier_quality_issue','supplier_corrective_action','escalated',
     240000.00,'Arjun Nair (SQE)','2026-07-28',null,
     'Battery supplier 8D overdue — escalated to management review'),
    ('CMP-DIA-2607A','design_deficiency','design_change','open',
     320000.00,'Sunita Rao (R&D)','2026-08-25',null,
     'Conductivity cell redesign ECO drafted; risk file update pending'),
    ('CMP-MON-2605A','supplier_quality_issue','enhanced_incoming_inspection','overdue',
     60000.00,'Arjun Nair (SQE)','2026-07-15',null,
     'SpO2 probe incoming AQL tightening past target date'),
    ('CMP-CARM-2606A','pending_investigation','none_required','open',
     0.00,'Vikram Shetty (Service QA)','2026-08-05',null,
     'Tube overheat investigation to determine CAPA need'),
    ('CMP-SYR-2607A','software_bug','software_patch','closed',
     48000.00,'Meera Krishnan (Engineering)','2026-07-20','2026-07-18',
     'Keypad firmware v2.4 released; effectiveness check passed'),
    ('CMP-DIA-2606A','use_error','retraining_program','closed',
     35000.00,'Priya Menon (Clinical Apps)','2026-06-30','2026-06-27',
     'Blood-leak detector priming retraining completed at both sites')
  ) as q(rcode, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.complaint_capa_r3653 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;
