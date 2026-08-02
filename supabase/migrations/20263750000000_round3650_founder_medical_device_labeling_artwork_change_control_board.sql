-- Round 3650: Medical-Device Labeling / Artwork Change-Control Board
-- Labeling QA — device × label component × component type × artwork version vs approved × versions in field × obsolete stock × open change requests × regulatory approval × control status × trend × CAPA

-- =============================================================================
-- TABLE 1: label_artwork_r3650 — per-device labeling / IFU artwork change-control records
-- =============================================================================
create table if not exists public.label_artwork_r3650 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  artwork_code text not null,
  device_name text not null,
  label_component text not null,
  component_type text not null check (component_type in (
    'primary_label','carton','ifu','e_ifu','udi_label','warning_insert'
  )),
  period_month date not null,
  current_version text not null,
  approved_version text not null,
  versions_in_field int not null,
  obsolete_stock_units int not null,
  change_requests_open int not null,
  regulatory_approval_needed boolean not null,
  last_change_date date,
  next_review_due date,
  control_status text not null check (control_status in (
    'current','change_in_progress','obsolete_in_field','uncontrolled','recall_linked'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.label_artwork_r3650 enable row level security;

create index if not exists idx_label_artwork_r3650_org on public.label_artwork_r3650(organization_id);
create index if not exists idx_label_artwork_r3650_month on public.label_artwork_r3650(period_month);
create index if not exists idx_label_artwork_r3650_status on public.label_artwork_r3650(control_status);

-- =============================================================================
-- TABLE 2: label_artwork_capa_actions_r3650 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.label_artwork_capa_actions_r3650 (
  id uuid primary key default gen_random_uuid(),
  artwork_id uuid not null references public.label_artwork_r3650(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'artwork_vendor_error','regulatory_update_missed','translation_error','udi_data_mismatch',
    'print_vendor_old_plate','change_control_bypassed','document_control_lapse','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reissue_artwork','quarantine_obsolete_stock','retrain_labeling_team','update_change_control_sop',
    'notify_regulatory_body','rework_labels','destroy_obsolete_stock','vendor_corrective_action','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_cost_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.label_artwork_capa_actions_r3650 enable row level security;

create index if not exists idx_label_artwork_capa_r3650_art on public.label_artwork_capa_actions_r3650(artwork_id);
create index if not exists idx_label_artwork_capa_r3650_status on public.label_artwork_capa_actions_r3650(capa_status);

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

  -- 16 labeling / artwork change-control rows
  insert into public.label_artwork_r3650 (
    organization_id, artwork_code, device_name, label_component, component_type,
    period_month, current_version, approved_version, versions_in_field,
    obsolete_stock_units, change_requests_open, regulatory_approval_needed,
    last_change_date, next_review_due, control_status, trend_dir, notes
  )
  select v_org_id, q.acode, q.dname, q.lcomp, q.ctype,
    q.pmon::date, q.curv, q.appv, q.vif,
    q.obs, q.cro, q.regap,
    q.lcd::date, q.nrd::date, q.cstat, q.trd, q.nt
  from (values
    ('LAC-VENT-01','ICU Ventilator VS-5','Primary device label','primary_label',
     '2026-07-01','v4.2','v4.2',1,0,0,false,'2026-03-14','2026-12-15','current','stable','UDI-compliant primary label current across installed base'),
    ('LAC-VENT-02','ICU Ventilator VS-5','Instructions for use booklet','ifu',
     '2026-07-01','v3.0','v3.1',2,340,1,true,'2026-06-20','2026-08-10','change_in_progress','improving','IFU rev v3.1 under CDSCO change assessment — contraindication text update'),
    ('LAC-VENT-03','ICU Ventilator VS-5','UDI barcode label','udi_label',
     '2026-05-01','v1.0','v1.0',1,0,0,false,'2026-01-15','2026-12-20','current','improving','GS1 DataMatrix verified grade A at last print run'),
    ('LAC-INFU-01','Infusion Pump IP-200','Primary device label','primary_label',
     '2026-07-01','v2.8','v2.8',1,0,0,false,'2026-01-22','2026-11-30','current','stable','Label spec aligned to MDR-2017 Schedule requirements'),
    ('LAC-INFU-02','Infusion Pump IP-200','Shelf carton artwork','carton',
     '2026-07-01','v2.1','v2.4',3,1250,2,true,'2026-05-30','2026-08-01','obsolete_in_field','worsening','Old carton stock at Bhiwandi and Nagpur depots pending quarantine'),
    ('LAC-INFU-03','Infusion Pump IP-200','Drug library warning insert','warning_insert',
     '2026-07-01','v1.0','v1.2',2,600,1,true,'2026-06-05','2026-07-25','uncontrolled','worsening','Insert printed from unapproved plate at print vendor'),
    ('LAC-MON-01','Patient Monitor PM-12','Primary device label','primary_label',
     '2026-06-01','v5.0','v5.0',1,0,0,false,'2026-02-18','2026-12-01','current','improving','Label harmonised post rebrand — no open change orders'),
    ('LAC-MON-02','Patient Monitor PM-12','Electronic IFU landing page','e_ifu',
     '2026-06-01','v5.0','v5.0',1,0,1,false,'2026-04-12','2026-09-15','change_in_progress','stable','Minor e-IFU screenshot refresh in progress — no reg impact'),
    ('LAC-MON-03','Patient Monitor PM-12','Shelf carton artwork','carton',
     '2026-07-01','v4.6','v4.8',2,90,1,false,'2026-06-10','2026-08-05','obsolete_in_field','stable','Residual carton stock at Chennai depot awaiting destruction'),
    ('LAC-DIAL-01','Dialysis Machine DX-9','UDI barcode label','udi_label',
     '2026-06-01','v1.4','v1.6',2,480,1,true,'2026-06-18','2026-07-20','recall_linked','worsening','UDI DI mismatch linked to field correction FSCA-114'),
    ('LAC-DIAL-02','Dialysis Machine DX-9','Instructions for use booklet','ifu',
     '2026-06-01','v2.2','v2.2',1,0,0,false,'2026-03-02','2026-10-30','current','stable','IFU current — bilingual Hindi-English edition in field'),
    ('LAC-DIAL-03','Dialysis Machine DX-9','Disinfectant warning insert','warning_insert',
     '2026-07-01','v1.5','v1.5',1,0,0,false,'2026-04-08','2026-10-12','current','stable','Citric-acid disinfection caution insert verified current'),
    ('LAC-DEFIB-01','Defibrillator DF-360','Primary device label','primary_label',
     '2026-05-01','v3.3','v3.3',1,0,0,false,'2025-12-10','2026-08-30','current','stable','Energy-rating label matches approved technical file'),
    ('LAC-DEFIB-02','Defibrillator DF-360','Pad expiry warning insert','warning_insert',
     '2026-05-01','v1.1','v1.3',2,150,1,true,'2026-05-22','2026-07-15','obsolete_in_field','improving','Old pad-expiry insert being swapped at scheduled service visits'),
    ('LAC-CARM-01','Surgical C-Arm CA-700','Radiation safety carton artwork','carton',
     '2026-05-01','v2.0','v2.0',1,0,0,false,'2026-02-25','2026-11-10','current','stable','AERB radiation trefoil placement verified on carton'),
    ('LAC-CARM-02','Surgical C-Arm CA-700','Electronic IFU portal','e_ifu',
     '2026-05-01','v1.9','v2.0',2,0,1,true,'2026-06-28','2026-07-30','change_in_progress','stable','AERB caution text update queued for e-IFU portal push')
  ) as q(acode, dname, lcomp, ctype, pmon, curv, appv, vif, obs, cro, regap, lcd, nrd, cstat, trd, nt);

  -- CAPA seed — attach to specific artwork records via artwork_code
  insert into public.label_artwork_capa_actions_r3650 (
    artwork_id, root_cause, corrective_action, capa_status,
    impact_cost_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.cost, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('LAC-INFU-02','print_vendor_old_plate','quarantine_obsolete_stock','in_progress',185000.00,'QA Manager - Ravi Iyer','2026-08-05',null,'1250 obsolete cartons under quarantine at Bhiwandi and Nagpur depots'),
    ('LAC-INFU-03','change_control_bypassed','vendor_corrective_action','escalated',92000.00,'RA Head - Meera Nair','2026-07-28',null,'Vendor printed insert without approved change order — SCAR issued'),
    ('LAC-DIAL-01','udi_data_mismatch','notify_regulatory_body','open',240000.00,'RA Head - Meera Nair','2026-08-10',null,'UDI DI mismatch reported with field correction FSCA-114 to CDSCO'),
    ('LAC-VENT-02','regulatory_update_missed','reissue_artwork','verification_pending',65000.00,'Labeling Lead - Anjali Deshpande','2026-08-01',null,'IFU v3.1 reissued with updated contraindication text — print proof under review'),
    ('LAC-VENT-02','translation_error','retrain_labeling_team','open',12000.00,'Training Lead - Kavya Menon','2026-08-15',null,'Hindi IFU translation error caught in review — refresher training planned'),
    ('LAC-DEFIB-02','artwork_vendor_error','rework_labels','closed',38000.00,'QA Manager - Ravi Iyer','2026-07-10','2026-07-08','Pad-expiry insert reworked and verified at service exchange'),
    ('LAC-MON-03','document_control_lapse','destroy_obsolete_stock','overdue',27000.00,'Stores Lead - Suresh Patil','2026-07-20',null,'Depot destruction certificate pending past target date'),
    ('LAC-CARM-02','regulatory_update_missed','update_change_control_sop','in_progress',15000.00,'Labeling Lead - Anjali Deshpande','2026-08-08',null,'AERB text change added to SOP regulatory-trigger checklist')
  ) as q(acode, rc, ca, cst, cost, ownr, tcd, acd, nt)
  join public.label_artwork_r3650 e
    on e.organization_id = v_org_id and e.artwork_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Control-status distribution
create or replace function public.founder_r3650_control_status_rollup()
returns table(control_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.label_artwork_r3650)
  select l.control_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.label_artwork_r3650 l
  group by l.control_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3650_control_status_rollup() from public, anon;
grant execute on function public.founder_r3650_control_status_rollup() to authenticated;

-- 2) Component-type scorecard
create or replace function public.founder_r3650_component_type_scorecard()
returns table(
  component_type text,
  total_records bigint,
  current_ok bigint,
  in_change bigint,
  obsolete_field bigint,
  uncontrolled_or_recall bigint,
  total_obsolete_units bigint,
  reg_approval_pending bigint,
  current_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.component_type,
    count(*)::bigint,
    count(*) filter (where l.control_status = 'current')::bigint,
    count(*) filter (where l.control_status = 'change_in_progress')::bigint,
    count(*) filter (where l.control_status = 'obsolete_in_field')::bigint,
    count(*) filter (where l.control_status in ('uncontrolled','recall_linked'))::bigint,
    coalesce(sum(l.obsolete_stock_units),0)::bigint,
    count(*) filter (where l.regulatory_approval_needed = true)::bigint,
    round(100.0 * count(*) filter (where l.control_status = 'current')::numeric / nullif(count(*),0), 1)
  from public.label_artwork_r3650 l
  group by l.component_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3650_component_type_scorecard() from public, anon;
grant execute on function public.founder_r3650_component_type_scorecard() to authenticated;

-- 3) Component-type × control-status matrix
create or replace function public.founder_r3650_component_status_matrix()
returns table(component_type text, control_status text, records bigint, total_obsolete_units bigint, open_change_requests bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.component_type, l.control_status, count(*)::bigint,
    coalesce(sum(l.obsolete_stock_units),0)::bigint,
    coalesce(sum(l.change_requests_open),0)::bigint
  from public.label_artwork_r3650 l
  group by l.component_type, l.control_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3650_component_status_matrix() from public, anon;
grant execute on function public.founder_r3650_component_status_matrix() to authenticated;

-- 4) Monthly change trend
create or replace function public.founder_r3650_monthly_change_trend()
returns table(period_month date, records bigint, open_change_requests bigint, total_obsolete_units bigint, worsening bigint, reg_approval_needed_cnt bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.change_requests_open),0)::bigint,
    coalesce(sum(l.obsolete_stock_units),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint,
    count(*) filter (where l.regulatory_approval_needed = true)::bigint
  from public.label_artwork_r3650 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3650_monthly_change_trend() from public, anon;
grant execute on function public.founder_r3650_monthly_change_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3650_capa_status_board()
returns table(capa_status text, actions bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.label_artwork_capa_actions_r3650 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3650_capa_status_board() from public, anon;
grant execute on function public.founder_r3650_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3650_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.label_artwork_capa_actions_r3650)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.label_artwork_capa_actions_r3650 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3650_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3650_root_cause_pareto() to authenticated;

-- 7) Obsolete-stock digest (per device)
create or replace function public.founder_r3650_obsolete_stock_digest()
returns table(device_name text, components bigint, total_obsolete_units bigint, recall_linked bigint, uncontrolled bigint, total_open_changes bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.device_name, count(*)::bigint,
    coalesce(sum(l.obsolete_stock_units),0)::bigint,
    count(*) filter (where l.control_status = 'recall_linked')::bigint,
    count(*) filter (where l.control_status = 'uncontrolled')::bigint,
    coalesce(sum(l.change_requests_open),0)::bigint
  from public.label_artwork_r3650 l
  group by l.device_name
  order by coalesce(sum(l.obsolete_stock_units),0) desc;
end;
$$;

revoke execute on function public.founder_r3650_obsolete_stock_digest() from public, anon;
grant execute on function public.founder_r3650_obsolete_stock_digest() to authenticated;

-- 8) High-risk artwork queue (uncontrolled / recall-linked / obsolete stock / version drift)
create or replace function public.founder_r3650_high_risk_queue()
returns table(
  device_name text,
  artwork_code text,
  label_component text,
  component_type text,
  period_month date,
  control_status text,
  current_version text,
  approved_version text,
  obsolete_stock_units int,
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
  select l.device_name, l.artwork_code, l.label_component, l.component_type, l.period_month,
    l.control_status, l.current_version, l.approved_version, l.obsolete_stock_units, l.trend_dir, l.notes
  from public.label_artwork_r3650 l
  where l.control_status in ('uncontrolled','recall_linked','obsolete_in_field')
     or l.trend_dir = 'worsening'
     or l.obsolete_stock_units > 0
     or l.current_version <> l.approved_version
  order by l.obsolete_stock_units desc, l.device_name;
end;
$$;

revoke execute on function public.founder_r3650_high_risk_queue() from public, anon;
grant execute on function public.founder_r3650_high_risk_queue() to authenticated;
