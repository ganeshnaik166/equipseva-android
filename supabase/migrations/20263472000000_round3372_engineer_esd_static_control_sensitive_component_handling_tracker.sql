-- Round 3372: Engineer ESD & Static-Control Sensitive-Component Handling Tracker
-- Per job/workstation ESD audit — engineer × location × component × wrist-strap/mat/ionizer/packaging/humidity/grounding/training × mishandling × latent-failure × compliance verdict + CAPA

-- =============================================================================
-- TABLE 1: esd_static_control_r3372 — per job/workstation ESD handling audits
-- =============================================================================
create table if not exists public.esd_static_control_r3372 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  location text not null check (location in (
    'workshop_bench','field_site','parts_store','repair_lab'
  )),
  job_code text not null,
  component_type text not null check (component_type in (
    'imaging_detector_board','monitor_mainboard','sensor_module','power_supply_pcb','firmware_chip','general_pcb'
  )),
  audit_date date not null,
  wrist_strap_used boolean not null,
  esd_mat_grounded boolean not null,
  ionizer_used text not null check (ionizer_used in (
    'yes','no','not_required'
  )),
  esd_bag_packaging_ok boolean not null,
  humidity_controlled_ok boolean not null,
  grounding_continuity_tested boolean not null,
  esd_training_current boolean not null,
  mishandling_incident text not null check (mishandling_incident in (
    'none','dropped','ungrounded_touch','wrong_packaging','static_event'
  )),
  latent_failure_reported boolean not null,
  compliance_verdict text not null check (compliance_verdict in (
    'fully_compliant','minor_gap','major_violation','damage_incident','retrain'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esd_static_control_r3372 enable row level security;

create index if not exists idx_esd_static_control_r3372_org on public.esd_static_control_r3372(organization_id);
create index if not exists idx_esd_static_control_r3372_date on public.esd_static_control_r3372(audit_date);
create index if not exists idx_esd_static_control_r3372_verdict on public.esd_static_control_r3372(compliance_verdict);

-- =============================================================================
-- TABLE 2: esd_static_control_capa_actions_r3372 — CAPA & process actions
-- =============================================================================
create table if not exists public.esd_static_control_capa_actions_r3372 (
  id uuid primary key default gen_random_uuid(),
  audit_log_id uuid not null references public.esd_static_control_r3372(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_wrist_strap','ungrounded_mat','no_ionizer','improper_esd_packaging','humidity_out_of_range',
    'grounding_continuity_fail','training_lapsed','mishandling_event','latent_failure_investigation','preventive_process_gap'
  )),
  root_cause text not null check (root_cause in (
    'wrist_strap_not_worn','mat_ground_cord_disconnected','ionizer_not_deployed','wrong_packaging_used',
    'humidity_control_failure','ground_point_high_resistance','training_overdue','rushed_field_handling',
    'process_not_documented','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_wrist_strap','reconnect_mat_ground','deploy_ionizer','issue_esd_bags','install_humidity_control',
    'repair_ground_point','schedule_esd_retraining','revise_handling_sop','quarantine_component','escalate_to_qa','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'iso_13485_deviation','warranty_risk','none','internal_only','oem_warranty_void','customer_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.esd_static_control_capa_actions_r3372 enable row level security;

create index if not exists idx_esd_capa_r3372_log on public.esd_static_control_capa_actions_r3372(audit_log_id);
create index if not exists idx_esd_capa_r3372_status on public.esd_static_control_capa_actions_r3372(capa_status);

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

  -- 14 ESD handling audit rows
  insert into public.esd_static_control_r3372 (
    organization_id, engineer_name, location, job_code, component_type, audit_date,
    wrist_strap_used, esd_mat_grounded, ionizer_used, esd_bag_packaging_ok,
    humidity_controlled_ok, grounding_continuity_tested, esd_training_current,
    mishandling_incident, latent_failure_reported, compliance_verdict, notes
  )
  select v_org_id, q.eng, q.loc, q.jc, q.ct, q.ad::date,
    q.wsu, q.emg, q.ion, q.ebp,
    q.hco, q.gct, q.etr,
    q.mi, q.lfr, q.cv, q.nt
  from (values
    ('Ramesh Iyer','workshop_bench','JOB-APL-3301','imaging_detector_board','2026-07-10',
     true,true,'yes',true,true,true,true,'none',false,'fully_compliant','Apollo Chennai CT detector board reflow — full ESD protocol observed'),
    ('Ramesh Iyer','field_site','JOB-APL-3302','monitor_mainboard','2026-07-10',
     true,false,'not_required',true,false,true,true,'none',false,'minor_gap','Apollo Chennai field swap — no grounded mat on site, portable strap only, humidity uncontrolled'),
    ('Anjali Nair','repair_lab','JOB-FRT-3303','sensor_module','2026-07-09',
     false,true,'yes',true,true,true,true,'ungrounded_touch',false,'major_violation','Fortis Gurgaon — technician handled sensor module without wrist strap, ungrounded touch logged'),
    ('Anjali Nair','workshop_bench','JOB-FRT-3304','power_supply_pcb','2026-07-09',
     true,true,'no',true,true,true,true,'none',false,'fully_compliant','Fortis Gurgaon PSU board repair — clean handling audit'),
    ('Vikram Reddy','parts_store','JOB-MNP-3305','firmware_chip','2026-07-08',
     true,true,'yes',false,true,true,true,'wrong_packaging',false,'minor_gap','Manipal Bengaluru firmware chips returned in non-ESD tray — repackaged'),
    ('Vikram Reddy','workshop_bench','JOB-MNP-3306','imaging_detector_board','2026-07-08',
     true,true,'yes',true,true,true,true,'none',false,'fully_compliant','Manipal Bengaluru CT detector handling audit passed'),
    ('Suresh Menon','repair_lab','JOB-AIM-3307','monitor_mainboard','2026-07-07',
     false,false,'no',true,true,false,false,'static_event',true,'damage_incident','AIIMS Delhi — static discharge during mainboard insertion, latent fault suspected, ESD training lapsed'),
    ('Suresh Menon','workshop_bench','JOB-AIM-3308','general_pcb','2026-07-07',
     true,true,'not_required',true,true,true,true,'none',false,'fully_compliant','AIIMS Delhi general PCB rework — nominal'),
    ('Priya Sharma','field_site','JOB-CMC-3309','sensor_module','2026-07-06',
     true,false,'not_required',true,false,true,true,'none',false,'minor_gap','CMC Vellore field sensor replacement — humidity not controlled at site'),
    ('Priya Sharma','repair_lab','JOB-CMC-3310','power_supply_pcb','2026-07-06',
     false,true,'no',true,true,true,true,'dropped',true,'damage_incident','CMC Vellore — PSU board dropped on bench, no wrist strap, latent failure reported'),
    ('Karthik Rao','workshop_bench','JOB-KIM-3311','firmware_chip','2026-07-05',
     true,true,'yes',true,true,true,false,'none',false,'retrain','KIMS Hyderabad — all controls in place but engineer ESD certification expired, retrain required'),
    ('Karthik Rao','parts_store','JOB-KIM-3312','general_pcb','2026-07-05',
     true,true,'not_required',false,true,true,true,'wrong_packaging',false,'minor_gap','KIMS Hyderabad spare PCBs stored without ESD bags in bin 4'),
    ('Deepak Verma','repair_lab','JOB-YSH-3313','imaging_detector_board','2026-07-04',
     false,false,'no',false,false,false,false,'ungrounded_touch',true,'major_violation','Yashoda Hyderabad — multiple ESD controls absent on detector rework, escalated to QA'),
    ('Fatima Sheikh','workshop_bench','JOB-CAR-3314','sensor_module','2026-07-04',
     true,true,'yes',true,true,true,true,'none',false,'fully_compliant','Care Hospitals Hyderabad sensor module audit — full compliance')
  ) as q(eng, loc, jc, ct, ad, wsu, emg, ion, ebp, hco, gct, etr, mi, lfr, cv, nt);

  -- CAPA seed — attach to specific audits via job_code
  insert into public.esd_static_control_capa_actions_r3372 (
    audit_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('JOB-FRT-3303','missing_wrist_strap','wrist_strap_not_worn','schedule_esd_retraining','in_progress','iso_13485_deviation','2026-07-14',null,8000.00,'Engineer coached; wrist-strap continuity check added to job checklist'),
    ('JOB-AIM-3307','latent_failure_investigation','pending_investigation','quarantine_component','escalated','oem_warranty_void','2026-07-12',null,45000.00,'Static event on mainboard — board quarantined, OEM warranty at risk pending failure analysis'),
    ('JOB-CMC-3310','mishandling_event','rushed_field_handling','revise_handling_sop','open','warranty_risk','2026-07-15',null,22000.00,'PSU dropped without strap — latent failure test pending, SOP revision underway'),
    ('JOB-KIM-3311','training_lapsed','training_overdue','schedule_esd_retraining','verification_pending','internal_only','2026-07-11',null,3500.00,'ESD certification renewal booked — verify current status on next audit'),
    ('JOB-YSH-3313','grounding_continuity_fail','ground_point_high_resistance','repair_ground_point','escalated','customer_safety_alert','2026-07-10',null,15000.00,'Bench ground point high resistance and multiple controls absent — escalated to QA'),
    ('JOB-MNP-3305','improper_esd_packaging','wrong_packaging_used','issue_esd_bags','closed','none','2026-07-09','2026-07-08',2000.00,'Firmware chips repackaged in moisture-barrier ESD bags; parts-store audit closed'),
    ('JOB-APL-3302','humidity_out_of_range','humidity_control_failure','install_humidity_control','overdue','internal_only','2026-07-06',null,12000.00,'Field-site humidity uncontrolled — portable dehumidifier procurement past target date')
  ) as q(jc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.esd_static_control_r3372 e
    on e.organization_id = v_org_id and e.job_code = q.jc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3372_verdict_rollup()
returns table(compliance_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esd_static_control_r3372)
  select l.compliance_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.esd_static_control_r3372 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3372_verdict_rollup() from public, anon;
grant execute on function public.founder_r3372_verdict_rollup() to authenticated;

-- 2) Engineer-level ESD scorecard
create or replace function public.founder_r3372_engineer_scorecard()
returns table(
  engineer_name text,
  total_audits bigint,
  fully_compliant bigint,
  minor_gap bigint,
  major_violation bigint,
  damage_incident bigint,
  wrist_strap_gaps bigint,
  mat_ground_gaps bigint,
  latent_failures bigint,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'fully_compliant')::bigint,
    count(*) filter (where l.compliance_verdict = 'minor_gap')::bigint,
    count(*) filter (where l.compliance_verdict in ('major_violation','retrain'))::bigint,
    count(*) filter (where l.compliance_verdict = 'damage_incident')::bigint,
    count(*) filter (where l.wrist_strap_used = false)::bigint,
    count(*) filter (where l.esd_mat_grounded = false)::bigint,
    count(*) filter (where l.latent_failure_reported = true)::bigint,
    round(100.0 * count(*) filter (where l.compliance_verdict = 'fully_compliant')::numeric / nullif(count(*),0), 1)
  from public.esd_static_control_r3372 l
  group by l.engineer_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3372_engineer_scorecard() from public, anon;
grant execute on function public.founder_r3372_engineer_scorecard() to authenticated;

-- 3) Location × component-type matrix
create or replace function public.founder_r3372_location_component_matrix()
returns table(location text, component_type text, audits bigint, fully_compliant bigint, mishandling_incidents bigint, latent_failures bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.location, l.component_type, count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'fully_compliant')::bigint,
    count(*) filter (where l.mishandling_incident <> 'none')::bigint,
    count(*) filter (where l.latent_failure_reported = true)::bigint
  from public.esd_static_control_r3372 l
  group by l.location, l.component_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3372_location_component_matrix() from public, anon;
grant execute on function public.founder_r3372_location_component_matrix() to authenticated;

-- 4) Daily compliance trend
create or replace function public.founder_r3372_daily_compliance_trend()
returns table(audit_date date, audits bigint, fully_compliant bigint, violations bigint, mishandling_incidents bigint, latent_failures bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'fully_compliant')::bigint,
    count(*) filter (where l.compliance_verdict in ('major_violation','damage_incident','retrain'))::bigint,
    count(*) filter (where l.mishandling_incident <> 'none')::bigint,
    count(*) filter (where l.latent_failure_reported = true)::bigint
  from public.esd_static_control_r3372 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3372_daily_compliance_trend() from public, anon;
grant execute on function public.founder_r3372_daily_compliance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3372_capa_status_board()
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
  from public.esd_static_control_capa_actions_r3372 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3372_capa_status_board() from public, anon;
grant execute on function public.founder_r3372_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3372_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.esd_static_control_capa_actions_r3372)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.esd_static_control_capa_actions_r3372 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3372_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3372_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3372_regulatory_impact_digest()
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
  from public.esd_static_control_capa_actions_r3372 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3372_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3372_regulatory_impact_digest() to authenticated;

-- 8) High-risk ESD handling queue (top individual concerns)
create or replace function public.founder_r3372_high_risk_queue()
returns table(
  engineer_name text,
  location text,
  job_code text,
  component_type text,
  audit_date date,
  compliance_verdict text,
  mishandling_incident text,
  wrist_strap text,
  latent_failure text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.location, l.job_code, l.component_type, l.audit_date,
    l.compliance_verdict, l.mishandling_incident,
    case when l.wrist_strap_used then 'used' else 'missing' end,
    case when l.latent_failure_reported then 'reported' else 'none' end,
    l.notes
  from public.esd_static_control_r3372 l
  where l.compliance_verdict in ('minor_gap','major_violation','damage_incident','retrain')
     or l.mishandling_incident <> 'none'
     or l.latent_failure_reported = true
     or l.wrist_strap_used = false
     or l.esd_mat_grounded = false
     or l.grounding_continuity_tested = false
     or l.esd_training_current = false
  order by l.audit_date desc, l.engineer_name;
end;
$$;

revoke execute on function public.founder_r3372_high_risk_queue() from public, anon;
grant execute on function public.founder_r3372_high_risk_queue() to authenticated;
