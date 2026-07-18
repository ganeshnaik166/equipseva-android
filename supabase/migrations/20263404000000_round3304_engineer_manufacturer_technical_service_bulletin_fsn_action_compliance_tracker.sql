-- Round 3304: Engineer Manufacturer Technical-Service-Bulletin (TSB) & Field-Safety-Notice (FSN) Action-Compliance Tracker
-- OEM bulletin action across the installed base — vendor × bulletin type × equipment type × criticality × affected/actioned/overdue units × compliance verdict × CAPA expedite/escalation

-- =============================================================================
-- TABLE 1: oem_bulletin_action_r3304 — per bulletin-unit action-compliance rows
-- =============================================================================
create table if not exists public.oem_bulletin_action_r3304 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  oem_vendor text not null,
  bulletin_ref text not null,
  bulletin_type text not null check (bulletin_type in (
    'technical_service_bulletin','field_safety_notice','mandatory_upgrade','voluntary_recall','software_advisory'
  )),
  equipment_type text not null check (equipment_type in (
    'patient_monitor','ventilator','infusion_pump','imaging','dialysis','defibrillator','anesthesia'
  )),
  site_name text not null,
  criticality text not null check (criticality in (
    'safety_critical','performance','informational'
  )),
  affected_units int not null,
  units_actioned int not null,
  overdue_units int not null,
  issue_date date not null,
  oem_deadline date not null,
  assigned_engineer text not null,
  action_type text not null check (action_type in (
    'firmware_update','part_replacement','inspection','label_update','decommission'
  )),
  completion_pct numeric(5,2) not null,
  compliance_verdict text not null check (compliance_verdict in (
    'fully_actioned','on_track','at_risk','overdue','not_started'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_bulletin_action_r3304 enable row level security;

create index if not exists idx_oem_bulletin_action_r3304_org on public.oem_bulletin_action_r3304(organization_id);
create index if not exists idx_oem_bulletin_action_r3304_issue on public.oem_bulletin_action_r3304(issue_date);
create index if not exists idx_oem_bulletin_action_r3304_verdict on public.oem_bulletin_action_r3304(compliance_verdict);

-- =============================================================================
-- TABLE 2: oem_bulletin_action_capa_actions_r3304 — CAPA expedite/escalation actions
-- =============================================================================
create table if not exists public.oem_bulletin_action_capa_actions_r3304 (
  id uuid primary key default gen_random_uuid(),
  bulletin_id uuid not null references public.oem_bulletin_action_r3304(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missed_oem_deadline','parts_unavailable','customer_access_denied','unit_in_continuous_use',
    'awaiting_customer_approval','firmware_incompatibility','preventive_backlog'
  )),
  root_cause text not null check (root_cause in (
    'parts_supply_delay','engineer_capacity_shortage','customer_downtime_unavailable','oem_shipment_delay',
    'incompatible_installed_firmware','approval_pending','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'expedite_parts_shipment','assign_additional_engineer','schedule_customer_downtime','escalate_to_oem',
    'decommission_and_replace','customer_management_escalation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_notifiable','mdr_field_action','patient_safety_alert','iso_13485_deviation','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.oem_bulletin_action_capa_actions_r3304 enable row level security;

create index if not exists idx_oem_bulletin_capa_r3304_bulletin on public.oem_bulletin_action_capa_actions_r3304(bulletin_id);
create index if not exists idx_oem_bulletin_capa_r3304_status on public.oem_bulletin_action_capa_actions_r3304(capa_status);

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

  -- 14 bulletin-action rows
  insert into public.oem_bulletin_action_r3304 (
    organization_id, oem_vendor, bulletin_ref, bulletin_type, equipment_type, site_name, criticality,
    affected_units, units_actioned, overdue_units, issue_date, oem_deadline, assigned_engineer,
    action_type, completion_pct, compliance_verdict, notes
  )
  select v_org_id, q.vendor, q.ref, q.btype, q.etype, q.site, q.crit,
    q.affected::int, q.actioned::int, q.overdue::int, q.idate::date, q.deadline::date, q.eng,
    q.atype, q.cpct::numeric, q.verdict, q.notes
  from (values
    ('Philips Healthcare','FSN-2026-PM-014','field_safety_notice','patient_monitor','Apollo Chennai','safety_critical',
     18,18,0,'2026-05-10','2026-06-30','Rajesh Iyer','firmware_update',100.0,'fully_actioned','IntelliVue MX alarm-latch firmware rolled to all 18 units'),
    ('GE Healthcare','TSB-GE-CARE-0231','technical_service_bulletin','patient_monitor','Fortis Gurgaon','performance',
     12,9,0,'2026-06-01','2026-07-31','Anita Desai','firmware_update',75.0,'on_track','CARESCAPE B650 NIBP module patch — 9 of 12 done'),
    ('Draeger','FSN-DR-VENT-2026-07','field_safety_notice','ventilator','Manipal Bengaluru','safety_critical',
     8,3,5,'2026-04-15','2026-05-31','Vikram Nair','part_replacement',37.5,'overdue','Evita expiratory valve recall — 5 units past OEM deadline'),
    ('Medtronic','VR-MDT-DEFIB-118','voluntary_recall','defibrillator','AIIMS Delhi','safety_critical',
     6,6,0,'2026-05-20','2026-07-15','Priya Menon','part_replacement',100.0,'fully_actioned','LIFEPAK battery latch recall closed — all replaced'),
    ('B Braun','TSB-BB-PUMP-0450','technical_service_bulletin','infusion_pump','CMC Vellore','performance',
     40,22,0,'2026-06-10','2026-08-15','Suresh Kumar','inspection',55.0,'on_track','Infusomat flow-sensor inspection sweep in progress'),
    ('Siemens Healthineers','MU-SIE-IMG-2026-03','mandatory_upgrade','imaging','KIMS Hyderabad','safety_critical',
     4,1,2,'2026-04-28','2026-06-10','Deepak Reddy','firmware_update',25.0,'overdue','MAGNETOM gradient-controller upgrade — 2 units overdue on downtime slot'),
    ('Fresenius','FSN-FRE-DIAL-2026-22','field_safety_notice','dialysis','Apollo Chennai','safety_critical',
     15,12,1,'2026-05-05','2026-06-20','Lakshmi Rao','part_replacement',80.0,'at_risk','4008S bicarbonate line clamp — 1 overdue, 2 pending customer slot'),
    ('GE Healthcare','TSB-GE-ANES-0512','technical_service_bulletin','anesthesia','Fortis Gurgaon','performance',
     5,5,0,'2026-06-15','2026-08-01','Anita Desai','inspection',100.0,'fully_actioned','Aisys vaporizer seat inspection complete'),
    ('Mindray','SA-MR-MON-2026-09','software_advisory','patient_monitor','Manipal Bengaluru','informational',
     30,0,0,'2026-07-01','2026-09-30','Karthik Subramanian','firmware_update',0.0,'not_started','BeneVision SpO2 trend advisory — scheduling window opens Aug'),
    ('Nihon Kohden','FSN-NK-DEFIB-2026-05','field_safety_notice','defibrillator','AIIMS Delhi','safety_critical',
     7,4,3,'2026-04-02','2026-05-15','Priya Menon','part_replacement',57.1,'overdue','Cardiolife energy-select recall — 3 units past deadline, escalated'),
    ('Hamilton Medical','MU-HAM-VENT-2026-11','mandatory_upgrade','ventilator','CMC Vellore','safety_critical',
     10,8,0,'2026-05-25','2026-07-20','Suresh Kumar','firmware_update',80.0,'on_track','HAMILTON-C6 O2-cell driver upgrade — 8 of 10'),
    ('Baxter','TSB-BAX-PUMP-0338','technical_service_bulletin','infusion_pump','KIMS Hyderabad','performance',
     25,14,4,'2026-05-12','2026-06-25','Deepak Reddy','inspection',56.0,'at_risk','Sigma Spectrum keypad wear — 4 overdue, parts en route'),
    ('Canon Medical','TSB-CAN-IMG-0207','technical_service_bulletin','imaging','Yashoda Hyderabad','performance',
     3,3,0,'2026-06-20','2026-08-30','Deepak Reddy','label_update',100.0,'fully_actioned','Aquilion CT scan-plan label update done'),
    ('Getinge','VR-GET-VENT-2026-02','voluntary_recall','ventilator','Rainbow Hyderabad','safety_critical',
     9,2,6,'2026-03-18','2026-05-01','Vikram Nair','decommission',22.2,'overdue','Servo-i inspiratory check-valve recall — 6 overdue, 2 decommissioned pending replacement')
  ) as q(vendor, ref, btype, etype, site, crit, affected, actioned, overdue, idate, deadline, eng, atype, cpct, verdict, notes);

  -- CAPA seed — attach to specific bulletins via bulletin_ref
  insert into public.oem_bulletin_action_capa_actions_r3304 (
    bulletin_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('FSN-DR-VENT-2026-07','missed_oem_deadline','parts_supply_delay','expedite_parts_shipment','escalated','cdsco_notifiable','2026-06-05',null,85000.00,'5 Evita valves past deadline — expedited air-freight from OEM'),
    ('MU-SIE-IMG-2026-03','unit_in_continuous_use','customer_downtime_unavailable','schedule_customer_downtime','in_progress','patient_safety_alert','2026-06-15',null,40000.00,'Gradient-controller upgrade needs 6h downtime — slot booked with radiology'),
    ('FSN-NK-DEFIB-2026-05','missed_oem_deadline','oem_shipment_delay','escalate_to_oem','escalated','mdr_field_action','2026-05-20',null,120000.00,'3 defib energy-select boards past deadline — OEM RMA escalated'),
    ('VR-GET-VENT-2026-02','parts_unavailable','parts_supply_delay','decommission_and_replace','open','cdsco_notifiable','2026-05-10',null,260000.00,'6 Servo-i units past recall deadline — 2 decommissioned, replacements ordered'),
    ('FSN-FRE-DIAL-2026-22','awaiting_customer_approval','approval_pending','customer_management_escalation','in_progress','iso_13485_deviation','2026-06-25',null,22000.00,'1 dialysis unit overdue — 2 units pending customer slot approval'),
    ('TSB-BAX-PUMP-0338','parts_unavailable','parts_supply_delay','expedite_parts_shipment','verification_pending','internal_only','2026-06-30','2026-07-02',31000.00,'Keypad kits received — 4 pumps re-inspected, verifying'),
    ('VR-MDT-DEFIB-118','preventive_backlog','engineer_capacity_shortage','assign_additional_engineer','closed','internal_only','2026-07-01','2026-06-28',15000.00,'Recall closed after adding a second field engineer')
  ) as q(ref, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.oem_bulletin_action_r3304 e
    on e.organization_id = v_org_id and e.bulletin_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance verdict distribution
create or replace function public.founder_r3304_compliance_verdict_rollup()
returns table(compliance_verdict text, bulletins bigint, affected_units bigint, overdue_units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_bulletin_action_r3304)
  select l.compliance_verdict, count(*)::bigint,
         coalesce(sum(l.affected_units),0)::bigint,
         coalesce(sum(l.overdue_units),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.oem_bulletin_action_r3304 l
  group by l.compliance_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3304_compliance_verdict_rollup() from public, anon;
grant execute on function public.founder_r3304_compliance_verdict_rollup() to authenticated;

-- 2) OEM vendor scorecard
create or replace function public.founder_r3304_vendor_scorecard()
returns table(
  oem_vendor text,
  total_bulletins bigint,
  fully_actioned bigint,
  on_track bigint,
  at_risk bigint,
  overdue bigint,
  affected_units bigint,
  units_actioned bigint,
  action_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_vendor,
    count(*)::bigint,
    count(*) filter (where l.compliance_verdict = 'fully_actioned')::bigint,
    count(*) filter (where l.compliance_verdict = 'on_track')::bigint,
    count(*) filter (where l.compliance_verdict = 'at_risk')::bigint,
    count(*) filter (where l.compliance_verdict = 'overdue')::bigint,
    coalesce(sum(l.affected_units),0)::bigint,
    coalesce(sum(l.units_actioned),0)::bigint,
    round(100.0 * coalesce(sum(l.units_actioned),0)::numeric / nullif(sum(l.affected_units),0), 1)
  from public.oem_bulletin_action_r3304 l
  group by l.oem_vendor
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3304_vendor_scorecard() from public, anon;
grant execute on function public.founder_r3304_vendor_scorecard() to authenticated;

-- 3) Bulletin type × equipment type matrix
create or replace function public.founder_r3304_bulletin_equipment_matrix()
returns table(bulletin_type text, equipment_type text, bulletins bigint, affected_units bigint, units_actioned bigint, overdue_units bigint, avg_completion_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bulletin_type, l.equipment_type, count(*)::bigint,
    coalesce(sum(l.affected_units),0)::bigint,
    coalesce(sum(l.units_actioned),0)::bigint,
    coalesce(sum(l.overdue_units),0)::bigint,
    round(avg(l.completion_pct), 1)
  from public.oem_bulletin_action_r3304 l
  group by l.bulletin_type, l.equipment_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3304_bulletin_equipment_matrix() from public, anon;
grant execute on function public.founder_r3304_bulletin_equipment_matrix() to authenticated;

-- 4) Daily bulletin issue trend
create or replace function public.founder_r3304_bulletin_trend()
returns table(issue_date date, bulletins bigint, affected_units bigint, units_actioned bigint, overdue_units bigint, at_risk_or_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.issue_date,
    count(*)::bigint,
    coalesce(sum(l.affected_units),0)::bigint,
    coalesce(sum(l.units_actioned),0)::bigint,
    coalesce(sum(l.overdue_units),0)::bigint,
    count(*) filter (where l.compliance_verdict in ('at_risk','overdue'))::bigint
  from public.oem_bulletin_action_r3304 l
  group by l.issue_date
  order by l.issue_date desc;
end;
$$;

revoke execute on function public.founder_r3304_bulletin_trend() from public, anon;
grant execute on function public.founder_r3304_bulletin_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3304_capa_status_board()
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
  from public.oem_bulletin_action_capa_actions_r3304 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3304_capa_status_board() from public, anon;
grant execute on function public.founder_r3304_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3304_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.oem_bulletin_action_capa_actions_r3304)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.oem_bulletin_action_capa_actions_r3304 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3304_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3304_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3304_regulatory_impact_digest()
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
  from public.oem_bulletin_action_capa_actions_r3304 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3304_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3304_regulatory_impact_digest() to authenticated;

-- 8) High-risk bulletin action queue
create or replace function public.founder_r3304_high_risk_queue()
returns table(
  oem_vendor text,
  bulletin_ref text,
  site_name text,
  equipment_type text,
  criticality text,
  oem_deadline date,
  compliance_verdict text,
  affected_units int,
  units_actioned int,
  overdue_units int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.oem_vendor, l.bulletin_ref, l.site_name, l.equipment_type, l.criticality,
    l.oem_deadline, l.compliance_verdict, l.affected_units, l.units_actioned, l.overdue_units, l.notes
  from public.oem_bulletin_action_r3304 l
  where l.compliance_verdict in ('at_risk','overdue','not_started')
     or l.overdue_units > 0
  order by l.oem_deadline asc, l.oem_vendor;
end;
$$;

revoke execute on function public.founder_r3304_high_risk_queue() from public, anon;
grant execute on function public.founder_r3304_high_risk_queue() to authenticated;
