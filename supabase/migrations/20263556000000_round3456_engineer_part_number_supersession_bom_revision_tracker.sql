-- Round 3456: Engineer Part-Number Supersession / BOM-Revision Tracker
-- OEM part-number supersession / BOM revision change tracking — change type × device model × old/new part × compatibility × affected units × stock disposition × rollout status × CAPA

-- =============================================================================
-- TABLE 1: part_supersession_bom_r3456 — per-change supersession / BOM revision log
-- =============================================================================
create table if not exists public.part_supersession_bom_r3456 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  change_ref text not null,
  device_model text not null,
  old_part_no text not null,
  new_part_no text not null,
  part_name text not null,
  change_type text not null check (change_type in (
    'supersession','bom_revision','obsolescence','substitution','recall_replacement'
  )),
  compatibility text not null check (compatibility in (
    'drop_in','requires_rework','requires_firmware','not_compatible','pending_review'
  )),
  affected_units int not null,
  stock_on_hand int not null,
  disposition text not null check (disposition in (
    'use_first','scrap','return_oem','rework','quarantine'
  )),
  rollout_status text not null check (rollout_status in (
    'draft','pending_approval','approved','in_rollout','completed','on_hold'
  )),
  effective_date date not null,
  notified boolean not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.part_supersession_bom_r3456 enable row level security;

create index if not exists idx_part_supersession_bom_r3456_org on public.part_supersession_bom_r3456(organization_id);
create index if not exists idx_part_supersession_bom_r3456_eff on public.part_supersession_bom_r3456(effective_date);
create index if not exists idx_part_supersession_bom_r3456_ctype on public.part_supersession_bom_r3456(change_type);

-- =============================================================================
-- TABLE 2: part_supersession_bom_capa_actions_r3456 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.part_supersession_bom_capa_actions_r3456 (
  id uuid primary key default gen_random_uuid(),
  change_log_id uuid not null references public.part_supersession_bom_r3456(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'unnotified_supersession','incompatible_substitution','obsolete_part_in_use','firmware_mismatch',
    'excess_obsolete_stock','recall_not_actioned','bom_revision_not_propagated','wrong_disposition',
    'stale_part_master','traceability_gap'
  )),
  root_cause text not null check (root_cause in (
    'oem_pcn_missed','engineering_change_backlog','supplier_discontinued','firmware_dependency_unflagged',
    'inventory_system_not_updated','field_notice_missed','documentation_error','vendor_lead_time',
    'pending_investigation','no_root_cause_assigned'
  )),
  corrective_action text not null check (corrective_action in (
    'notify_field_engineers','update_bom_master','order_superseding_part','apply_firmware_update',
    'quarantine_stock','return_to_oem','scrap_obsolete_stock','execute_recall_replacement',
    'retrain_procurement','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'cdsco_field_safety_notice','mdr_traceability','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.part_supersession_bom_capa_actions_r3456 enable row level security;

create index if not exists idx_part_supersession_bom_capa_r3456_log on public.part_supersession_bom_capa_actions_r3456(change_log_id);
create index if not exists idx_part_supersession_bom_capa_r3456_status on public.part_supersession_bom_capa_actions_r3456(capa_status);

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

  -- 16 change rows
  insert into public.part_supersession_bom_r3456 (
    organization_id, engineer_name, change_ref, device_model, old_part_no, new_part_no, part_name,
    change_type, compatibility, affected_units, stock_on_hand, disposition, rollout_status,
    effective_date, notified, notes
  )
  select v_org_id, q.eng, q.cref, q.model, q.oldpn, q.newpn, q.pname,
    q.ctype, q.compat, q.aunits, q.soh, q.disp, q.rstat,
    q.edate::date, q.notif, q.nt
  from (values
    ('Ravi Kumar','PCN-3456-01','Philips IntelliVue MX550','M8079A','M8079B','SpO2 Interface Cable',
     'supersession','drop_in',48,12,'use_first','in_rollout','2026-07-05',true,'OEM superseded SpO2 cable, drop-in — consume existing stock first'),
    ('Ravi Kumar','PCN-3456-02','GE Carescape B650','2050566-001','2050566-002','NIBP Pump Module',
     'bom_revision','requires_firmware',30,8,'use_first','approved','2026-07-04',true,'BOM rev C requires firmware 3.2 for new pump module'),
    ('Anita Desai','PCN-3456-03','Draeger Evita V500','8412710','8412735','O2 Sensor Cell',
     'obsolescence','requires_rework',60,25,'rework','in_rollout','2026-07-03',true,'O2 cell obsolete, new cell needs bracket rework'),
    ('Anita Desai','PCN-3456-04','Mindray BeneVision N22','115-018199-00','115-018199-01','Main Board Assembly',
     'recall_replacement','not_compatible',18,4,'return_oem','on_hold','2026-07-02',false,'Recall of main board, replacement not backward compatible — awaiting OEM'),
    ('Suresh Pillai','PCN-3456-05','Fresenius 4008S','M35952','M35953','Blood Pump Rotor',
     'substitution','requires_rework',22,6,'rework','approved','2026-07-01',true,'Substitute rotor from alternate supplier needs shaft rework'),
    ('Suresh Pillai','PCN-3456-06','Siemens Atellica','10827909','10827910','Reagent Probe',
     'supersession','drop_in',35,14,'use_first','completed','2026-06-30',true,'Reagent probe superseded, drop-in replacement completed'),
    ('Meena Nair','PCN-3456-07','Maquet Servo-i','6487180','6487200','Expiratory Cassette',
     'bom_revision','requires_rework',26,9,'rework','in_rollout','2026-06-29',true,'Cassette BOM revised, gasket rework required on install'),
    ('Meena Nair','PCN-3456-08','Nihon Kohden BSM-6000','SB-901P','SB-901D','Li-ion Battery Pack',
     'supersession','drop_in',80,40,'use_first','in_rollout','2026-06-28',true,'Battery pack superseded to higher capacity, drop-in fit'),
    ('Ravi Kumar','PCN-3456-09','Philips MX40','989803174941','989803196101','Telemetry Transmitter PCB',
     'obsolescence','not_compatible',15,3,'quarantine','on_hold','2026-06-27',false,'Transmitter PCB obsolete, replacement not compatible with old antenna'),
    ('Karthik Reddy','PCN-3456-10','GE Vivid E95','KTZ304444','KTZ304600','Probe Connector',
     'substitution','pending_review',12,5,'quarantine','pending_approval','2026-06-26',false,'Alternate probe connector under compatibility review'),
    ('Karthik Reddy','PCN-3456-11','Draeger Fabius','8605375','8605390','Vaporizer Seal Kit',
     'bom_revision','drop_in',40,20,'use_first','completed','2026-06-25',true,'Vaporizer seal kit BOM revised, drop-in seals'),
    ('Anita Desai','PCN-3456-12','Mindray DC-70','115-041116-00','115-041116-01','Ultrasound Power Supply',
     'supersession','requires_firmware',20,7,'use_first','approved','2026-06-24',true,'Power supply superseded, firmware flash required on install'),
    ('Suresh Pillai','PCN-3456-13','Fresenius 5008','M67901','M67950','Dialysate Filter Housing',
     'recall_replacement','requires_rework',34,11,'return_oem','in_rollout','2026-06-23',true,'Filter housing recall, replacement needs manifold rework'),
    ('Meena Nair','PCN-3456-14','Siemens Acuson','10041234','10041299','Beamformer Board',
     'obsolescence','not_compatible',9,2,'scrap','on_hold','2026-06-22',false,'Beamformer obsolete and not compatible — scrap old stock'),
    ('Karthik Reddy','PCN-3456-15','Nihon Kohden Life Scope','TR-900P','TR-900PA','ECG Trunk Cable',
     'supersession','drop_in',55,28,'use_first','completed','2026-06-21',true,'ECG trunk cable superseded, drop-in replacement'),
    ('Ravi Kumar','PCN-3456-16','Philips Efficia CM12','M3001A','M3002A','MMS Multi-Measurement Module',
     'substitution','not_compatible',14,3,'quarantine','on_hold','2026-06-20',false,'Substitute MMS module not compatible with dock, ageing obsolete stock')
  ) as q(eng, cref, model, oldpn, newpn, pname, ctype, compat, aunits, soh, disp, rstat, edate, notif, nt);

  -- CAPA seed — attach to specific changes via change_ref
  insert into public.part_supersession_bom_capa_actions_r3456 (
    change_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PCN-3456-04','recall_not_actioned','field_notice_missed','execute_recall_replacement','escalated','patient_safety_alert','Anita Desai','2026-07-10',null,46000.00,'Recall main board not actioned — escalated, OEM replacement pending'),
    ('PCN-3456-09','obsolete_part_in_use','supplier_discontinued','quarantine_stock','open','mdr_traceability','Ravi Kumar','2026-07-12',null,15000.00,'Obsolete transmitter PCB still in field — quarantine remaining stock'),
    ('PCN-3456-03','excess_obsolete_stock','engineering_change_backlog','update_bom_master','in_progress','iso_13485_deviation','Anita Desai','2026-07-08',null,8000.00,'25 obsolete O2 cells on hand — BOM master update in progress'),
    ('PCN-3456-13','recall_not_actioned','oem_pcn_missed','order_superseding_part','in_progress','cdsco_field_safety_notice','Suresh Pillai','2026-07-09',null,52000.00,'Filter housing recall — superseding part ordered, rollout underway'),
    ('PCN-3456-14','obsolete_part_in_use','supplier_discontinued','scrap_obsolete_stock','closed','internal_only','Meena Nair','2026-07-05','2026-07-04',3000.00,'Obsolete beamformer scrapped and part master retired'),
    ('PCN-3456-16','incompatible_substitution','documentation_error','return_to_oem','verification_pending','iso_13485_deviation','Ravi Kumar','2026-07-11',null,12000.00,'MMS substitute incompatible with dock — returned to OEM, verifying'),
    ('PCN-3456-02','firmware_mismatch','firmware_dependency_unflagged','apply_firmware_update','open','none','Ravi Kumar','2026-07-13',null,0.00,'NIBP module BOM rev needs firmware 3.2 flagged for rollout'),
    ('PCN-3456-10','unnotified_supersession','inventory_system_not_updated','notify_field_engineers','overdue','internal_only','Karthik Reddy','2026-07-03',null,2500.00,'Probe connector change not notified to field — overdue notification')
  ) as q(cref, fc, rc, ca, cst, ri, own, tcd, acd, cost, nt)
  join public.part_supersession_bom_r3456 e
    on e.organization_id = v_org_id and e.change_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Change-type distribution
create or replace function public.founder_r3456_change_type_rollup()
returns table(change_type text, changes bigint, affected_units bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.part_supersession_bom_r3456)
  select l.change_type, count(*)::bigint,
         coalesce(sum(l.affected_units),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.part_supersession_bom_r3456 l
  group by l.change_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3456_change_type_rollup() from public, anon;
grant execute on function public.founder_r3456_change_type_rollup() to authenticated;

-- 2) Device-model scorecard
create or replace function public.founder_r3456_device_model_scorecard()
returns table(
  device_model text,
  total_changes bigint,
  supersessions bigint,
  recalls bigint,
  not_compatible bigint,
  unnotified bigint,
  total_affected_units bigint,
  total_stock_on_hand bigint
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
    count(*) filter (where l.change_type = 'supersession')::bigint,
    count(*) filter (where l.change_type = 'recall_replacement')::bigint,
    count(*) filter (where l.compatibility = 'not_compatible')::bigint,
    count(*) filter (where l.notified = false)::bigint,
    coalesce(sum(l.affected_units),0)::bigint,
    coalesce(sum(l.stock_on_hand),0)::bigint
  from public.part_supersession_bom_r3456 l
  group by l.device_model
  order by count(*) desc, sum(l.affected_units) desc;
end;
$$;

revoke execute on function public.founder_r3456_device_model_scorecard() from public, anon;
grant execute on function public.founder_r3456_device_model_scorecard() to authenticated;

-- 3) Change-type × compatibility matrix
create or replace function public.founder_r3456_change_type_compat_matrix()
returns table(change_type text, compatibility text, changes bigint, affected_units bigint, stock_on_hand bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.change_type, l.compatibility, count(*)::bigint,
    coalesce(sum(l.affected_units),0)::bigint,
    coalesce(sum(l.stock_on_hand),0)::bigint
  from public.part_supersession_bom_r3456 l
  group by l.change_type, l.compatibility
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3456_change_type_compat_matrix() from public, anon;
grant execute on function public.founder_r3456_change_type_compat_matrix() to authenticated;

-- 4) Monthly change trend
create or replace function public.founder_r3456_monthly_change_trend()
returns table(change_month date, changes bigint, supersessions bigint, recalls bigint, not_compatible bigint, affected_units bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.effective_date)::date,
    count(*)::bigint,
    count(*) filter (where l.change_type = 'supersession')::bigint,
    count(*) filter (where l.change_type = 'recall_replacement')::bigint,
    count(*) filter (where l.compatibility = 'not_compatible')::bigint,
    coalesce(sum(l.affected_units),0)::bigint
  from public.part_supersession_bom_r3456 l
  group by date_trunc('month', l.effective_date)
  order by date_trunc('month', l.effective_date) desc;
end;
$$;

revoke execute on function public.founder_r3456_monthly_change_trend() from public, anon;
grant execute on function public.founder_r3456_monthly_change_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3456_capa_status_board()
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
  from public.part_supersession_bom_capa_actions_r3456 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3456_capa_status_board() from public, anon;
grant execute on function public.founder_r3456_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3456_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.part_supersession_bom_capa_actions_r3456)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.part_supersession_bom_capa_actions_r3456 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3456_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3456_root_cause_pareto() to authenticated;

-- 7) Affected-units impact digest
create or replace function public.founder_r3456_affected_units_digest()
returns table(
  change_type text,
  changes bigint,
  total_affected_units bigint,
  total_stock_on_hand bigint,
  avg_affected_units numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.change_type,
    count(*)::bigint,
    coalesce(sum(l.affected_units),0)::bigint,
    coalesce(sum(l.stock_on_hand),0)::bigint,
    round(avg(l.affected_units), 1)
  from public.part_supersession_bom_r3456 l
  group by l.change_type
  order by sum(l.affected_units) desc nulls last;
end;
$$;

revoke execute on function public.founder_r3456_affected_units_digest() from public, anon;
grant execute on function public.founder_r3456_affected_units_digest() to authenticated;

-- 8) High-risk change queue (not-compatible / recall / large stock / unnotified / on-hold)
create or replace function public.founder_r3456_high_risk_queue()
returns table(
  engineer_name text,
  change_ref text,
  device_model text,
  part_name text,
  old_part_no text,
  new_part_no text,
  change_type text,
  compatibility text,
  affected_units int,
  stock_on_hand int,
  disposition text,
  rollout_status text,
  effective_date date,
  notified boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.change_ref, l.device_model, l.part_name, l.old_part_no, l.new_part_no,
    l.change_type, l.compatibility, l.affected_units, l.stock_on_hand, l.disposition,
    l.rollout_status, l.effective_date, l.notified, l.notes
  from public.part_supersession_bom_r3456 l
  where l.compatibility in ('not_compatible','pending_review')
     or l.change_type in ('recall_replacement','obsolescence')
     or l.stock_on_hand >= 25
     or l.notified = false
     or l.rollout_status = 'on_hold'
  order by l.effective_date desc, l.device_model;
end;
$$;

revoke execute on function public.founder_r3456_high_risk_queue() from public, anon;
grant execute on function public.founder_r3456_high_risk_queue() to authenticated;
