-- Round 3641: Medical-Device Post-Market Surveillance (PMS) Board
-- Post-market surveillance / PSUR — device × class × period × field units × complaint-rate ppm × field actions × signal detection × PMS/PSUR status × CAPA

-- =============================================================================
-- TABLE 1: pms_r3641 — per-device / per-period post-market surveillance metrics
-- =============================================================================
create table if not exists public.pms_r3641 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  report_ref text not null,
  device_name text not null,
  device_class text not null,
  period_month date not null,
  units_in_field int not null,
  complaints_received int not null,
  complaint_rate_ppm numeric(12,2),
  field_actions int not null,
  pms_report_due_date date,
  psur_submitted boolean not null,
  trend_signal text not null check (trend_signal in (
    'stable','emerging_signal','rising','adverse_trend','recall_trigger'
  )),
  surveillance_status text not null check (surveillance_status in (
    'active','on_track','data_gap','signal_review','escalated'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pms_r3641 enable row level security;

create index if not exists idx_pms_r3641_org on public.pms_r3641(organization_id);
create index if not exists idx_pms_r3641_period on public.pms_r3641(period_month);
create index if not exists idx_pms_r3641_status on public.pms_r3641(surveillance_status);

-- =============================================================================
-- TABLE 2: pms_capa_actions_r3641 — CAPA & regulatory follow-up actions
-- =============================================================================
create table if not exists public.pms_capa_actions_r3641 (
  id uuid primary key default gen_random_uuid(),
  pms_id uuid not null references public.pms_r3641(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'complaint_underreporting','signal_detection_gap','device_malfunction_pattern',
    'labeling_ambiguity','user_error_trend','supplier_component_defect',
    'software_defect','data_collection_gap','pending_investigation','no_action_required'
  )),
  corrective_action text not null check (corrective_action in (
    'file_psur_update','initiate_field_safety_notice','issue_field_correction',
    'update_ifu_labeling','design_change_capa','supplier_corrective_action',
    'software_patch_release','enhance_complaint_handling','notify_cdsco','initiate_recall','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.pms_capa_actions_r3641 enable row level security;

create index if not exists idx_pms_capa_r3641_pms on public.pms_capa_actions_r3641(pms_id);
create index if not exists idx_pms_capa_r3641_status on public.pms_capa_actions_r3641(capa_status);

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

  -- 16 PMS surveillance rows
  insert into public.pms_r3641 (
    organization_id, report_ref, device_name, device_class, period_month,
    units_in_field, complaints_received, complaint_rate_ppm, field_actions,
    pms_report_due_date, psur_submitted, trend_signal, surveillance_status, trend_dir, notes
  )
  select v_org_id, q.rref, q.dname, q.dclass, q.pmon::date,
    q.units::int, q.compl::int, q.crate::numeric, q.factions::int,
    q.duedate::date, q.psub, q.tsig, q.sstat, q.tdir, q.nt
  from (values
    ('PMS-VENT-2601','ICU Ventilator V500','class_c','2026-01-01',
     3200,12,3750.00,1,'2026-02-15',true,'stable','on_track','stable','Q1 ventilator PMS - complaint rate within expected band'),
    ('PMS-INFP-2601','Volumetric Infusion Pump','class_b','2026-01-01',
     8400,26,3095.24,2,'2026-02-15',true,'rising','signal_review','worsening','Infusion pump occlusion-alarm complaints trending up'),
    ('PMS-MON-2601','Multiparameter Patient Monitor','class_b','2026-01-01',
     5600,7,1250.00,0,'2026-02-15',true,'stable','active','stable','Patient monitor PMS nominal for Q1'),
    ('PMS-DIAL-2601','Hemodialysis Machine','class_c','2026-01-01',
     1450,9,6206.90,1,'2026-02-15',false,'emerging_signal','data_gap','worsening','Dialysis machine PSUR pending - complaint data incomplete'),
    ('PMS-DEFIB-2601','Biphasic Defibrillator','class_c','2026-01-01',
     2100,15,7142.86,3,'2026-02-15',true,'adverse_trend','escalated','worsening','Defibrillator energy-delivery complaints - FSN under review'),
    ('PMS-CARM-2602','Mobile C-Arm Imaging','class_c','2026-02-01',
     680,3,4411.76,0,'2026-03-15',true,'stable','on_track','improving','C-arm PMS stable after firmware update'),
    ('PMS-SYRP-2602','Syringe Infusion Pump','class_b','2026-02-01',
     7200,31,4305.56,2,'2026-03-15',false,'rising','signal_review','worsening','Syringe pump flow-accuracy signal emerging'),
    ('PMS-ANES-2602','Anesthesia Workstation','class_c','2026-02-01',
     1300,5,3846.15,0,'2026-03-15',true,'stable','active','stable','Anesthesia workstation PMS nominal'),
    ('PMS-OXIM-2602','Fingertip Pulse Oximeter','class_a','2026-02-01',
     15400,44,2857.14,1,'2026-03-15',true,'rising','on_track','worsening','Pulse oximeter SpO2 drift complaints rising - monitoring'),
    ('PMS-ECG-2603','12-Lead ECG Machine','class_b','2026-03-01',
     4100,6,1463.41,0,'2026-04-15',true,'stable','active','stable','ECG machine PMS nominal'),
    ('PMS-CT-2603','CT Scanner 128-slice','class_c','2026-03-01',
     210,4,19047.62,1,'2026-04-15',false,'emerging_signal','data_gap','worsening','CT scanner tube-arc complaints - installed-base data gap'),
    ('PMS-USG-2603','Portable Ultrasound','class_b','2026-03-01',
     3300,8,2424.24,0,'2026-04-15',true,'stable','on_track','improving','Ultrasound PMS stable'),
    ('PMS-DIAT-2603','Surgical Diathermy Unit','class_c','2026-03-01',
     1900,17,8947.37,2,'2026-04-15',true,'adverse_trend','escalated','worsening','Diathermy burn-complaint cluster - field correction issued'),
    ('PMS-BGA-2604','Blood Gas Analyzer','class_b','2026-04-01',
     990,5,5050.51,0,'2026-05-15',false,'emerging_signal','data_gap','stable','Blood gas analyzer PSUR overdue - data reconciliation'),
    ('PMS-WARM-2604','Infant Radiant Warmer','class_c','2026-04-01',
     760,11,14473.68,2,'2026-05-15',true,'recall_trigger','escalated','worsening','Infant warmer overheat complaints exceeded recall threshold'),
    ('PMS-PHOTO-2604','Phototherapy Unit','class_b','2026-04-01',
     1250,3,2400.00,0,'2026-05-15',true,'stable','active','improving','Phototherapy unit PMS nominal')
  ) as q(rref, dname, dclass, pmon, units, compl, crate, factions, duedate, psub, tsig, sstat, tdir, nt);

  -- CAPA seed — attach to specific reports via report_ref
  insert into public.pms_capa_actions_r3641 (
    pms_id, root_cause, corrective_action, capa_status,
    estimated_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost::numeric, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('PMS-INFP-2601','device_malfunction_pattern','initiate_field_safety_notice','in_progress',85000.00,'Regulatory Affairs (Priya Nair)','2026-03-10',null,'Occlusion-alarm FSN drafted; verification pending'),
    ('PMS-DIAL-2601','data_collection_gap','enhance_complaint_handling','open',40000.00,'QA Lead (Rakesh Menon)','2026-03-05',null,'Close PSUR data gap before next reporting cycle'),
    ('PMS-DEFIB-2601','device_malfunction_pattern','issue_field_correction','escalated',120000.00,'Regulatory Affairs (Priya Nair)','2026-03-01',null,'Energy-delivery cluster escalated to CDSCO liaison'),
    ('PMS-SYRP-2602','signal_detection_gap','file_psur_update','in_progress',30000.00,'QA Analyst (Anita Rao)','2026-04-01',null,'Flow-accuracy signal captured in PSUR update'),
    ('PMS-OXIM-2602','labeling_ambiguity','update_ifu_labeling','verification_pending',18000.00,'Labeling (Suresh Iyer)','2026-04-01',null,'IFU SpO2 accuracy statement clarified - verifying'),
    ('PMS-CT-2603','signal_detection_gap','supplier_corrective_action','open',260000.00,'Supplier Quality (Vikram Shah)','2026-05-01',null,'Tube-arc SCAR raised with X-ray tube supplier'),
    ('PMS-DIAT-2603','device_malfunction_pattern','issue_field_correction','closed',95000.00,'Regulatory Affairs (Priya Nair)','2026-04-20','2026-04-18','Diathermy field correction completed and verified'),
    ('PMS-WARM-2604','device_malfunction_pattern','initiate_recall','escalated',540000.00,'Regulatory Affairs (Priya Nair)','2026-05-05',null,'Overheat complaints exceeded threshold - recall initiated, CDSCO notified')
  ) as q(rref, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.pms_r3641 e
    on e.organization_id = v_org_id and e.report_ref = q.rref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Surveillance status distribution
create or replace function public.founder_r3641_surveillance_status_rollup()
returns table(surveillance_status text, reports bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pms_r3641)
  select l.surveillance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.pms_r3641 l
  group by l.surveillance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3641_surveillance_status_rollup() from public, anon;
grant execute on function public.founder_r3641_surveillance_status_rollup() to authenticated;

-- 2) Device-class scorecard
create or replace function public.founder_r3641_device_class_scorecard()
returns table(
  device_class text,
  reports bigint,
  total_units_in_field bigint,
  total_complaints bigint,
  avg_complaint_rate_ppm numeric,
  total_field_actions bigint,
  escalated bigint,
  psur_submitted_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class,
    count(*)::bigint,
    coalesce(sum(l.units_in_field),0)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    round(avg(l.complaint_rate_ppm), 2),
    coalesce(sum(l.field_actions),0)::bigint,
    count(*) filter (where l.surveillance_status = 'escalated')::bigint,
    round(100.0 * count(*) filter (where l.psur_submitted = true)::numeric / nullif(count(*),0), 1)
  from public.pms_r3641 l
  group by l.device_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3641_device_class_scorecard() from public, anon;
grant execute on function public.founder_r3641_device_class_scorecard() to authenticated;

-- 3) Device-class × surveillance-status matrix
create or replace function public.founder_r3641_device_class_status_matrix()
returns table(device_class text, surveillance_status text, reports bigint, total_complaints bigint, avg_complaint_rate_ppm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_class, l.surveillance_status, count(*)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    round(avg(l.complaint_rate_ppm), 2)
  from public.pms_r3641 l
  group by l.device_class, l.surveillance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3641_device_class_status_matrix() from public, anon;
grant execute on function public.founder_r3641_device_class_status_matrix() to authenticated;

-- 4) Monthly complaint-rate trend
create or replace function public.founder_r3641_monthly_complaint_rate_trend()
returns table(period_month date, reports bigint, total_units bigint, total_complaints bigint, avg_complaint_rate_ppm numeric, total_field_actions bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.units_in_field),0)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    round(avg(l.complaint_rate_ppm), 2),
    coalesce(sum(l.field_actions),0)::bigint
  from public.pms_r3641 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3641_monthly_complaint_rate_trend() from public, anon;
grant execute on function public.founder_r3641_monthly_complaint_rate_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3641_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
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
  from public.pms_capa_actions_r3641 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3641_capa_status_board() from public, anon;
grant execute on function public.founder_r3641_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3641_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.pms_capa_actions_r3641)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.pms_capa_actions_r3641 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3641_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3641_root_cause_pareto() to authenticated;

-- 7) Signal digest
create or replace function public.founder_r3641_signal_digest()
returns table(trend_signal text, reports bigint, total_complaints bigint, avg_complaint_rate_ppm numeric, total_field_actions bigint, escalated bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.trend_signal, count(*)::bigint,
    coalesce(sum(l.complaints_received),0)::bigint,
    round(avg(l.complaint_rate_ppm), 2),
    coalesce(sum(l.field_actions),0)::bigint,
    count(*) filter (where l.surveillance_status = 'escalated')::bigint
  from public.pms_r3641 l
  group by l.trend_signal
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3641_signal_digest() from public, anon;
grant execute on function public.founder_r3641_signal_digest() to authenticated;

-- 8) High-risk surveillance queue
create or replace function public.founder_r3641_high_risk_queue()
returns table(
  device_name text,
  report_ref text,
  device_class text,
  period_month date,
  surveillance_status text,
  trend_signal text,
  trend_dir text,
  complaint_rate_ppm numeric,
  field_actions int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, l.report_ref, l.device_class, l.period_month,
    l.surveillance_status, l.trend_signal, l.trend_dir,
    l.complaint_rate_ppm, l.field_actions, l.notes
  from public.pms_r3641 l
  where l.surveillance_status in ('signal_review','escalated')
     or l.trend_signal in ('rising','adverse_trend','recall_trigger')
     or l.trend_dir = 'worsening'
     or l.psur_submitted = false
  order by l.period_month desc, l.device_name;
end;
$$;

revoke execute on function public.founder_r3641_high_risk_queue() from public, anon;
grant execute on function public.founder_r3641_high_risk_queue() to authenticated;
