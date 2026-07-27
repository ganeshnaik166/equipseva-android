-- Round 3504: Engineer Technical-Documentation / Manual-Firmware Version-Control Tracker
-- Doc currency QA — document type × device model × current vs latest version × versions-behind
-- × currency status × controlled-copy × distribution coverage × obsolescence CAPA

-- =============================================================================
-- TABLE 1: doc_version_control_r3504 — per-document version-currency tracker
-- =============================================================================
create table if not exists public.doc_version_control_r3504 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  device_model text not null,
  document_ref text not null,
  document_type text not null check (document_type in (
    'service_manual','user_manual','wiring_diagram','firmware','sop','safety_notice'
  )),
  current_version text,
  latest_version text,
  versions_behind int not null default 0,
  currency_status text not null check (currency_status in (
    'current','minor_behind','major_behind','obsolete','missing'
  )),
  last_updated date not null,
  controlled_copy boolean not null,
  distribution_pct numeric(5,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doc_version_control_r3504 enable row level security;

create index if not exists idx_doc_version_control_r3504_org on public.doc_version_control_r3504(organization_id);
create index if not exists idx_doc_version_control_r3504_status on public.doc_version_control_r3504(currency_status);
create index if not exists idx_doc_version_control_r3504_type on public.doc_version_control_r3504(document_type);

-- =============================================================================
-- TABLE 2: doc_version_control_capa_actions_r3504 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.doc_version_control_capa_actions_r3504 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  doc_log_id uuid not null references public.doc_version_control_r3504(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'version_obsolete','manual_missing','firmware_outdated','uncontrolled_copy',
    'distribution_gap','wiring_diagram_outdated','sop_outdated','safety_notice_unacknowledged'
  )),
  root_cause text not null check (root_cause in (
    'oem_update_not_received','no_update_subscription','engineer_not_notified','document_control_gap',
    'firmware_push_failed','legacy_device_unsupported','pending_investigation','vendor_portal_access_lost'
  )),
  corrective_action text not null check (corrective_action in (
    'download_latest_version','request_oem_manual','apply_firmware_update','recall_uncontrolled_copies',
    'redistribute_to_sites','subscribe_oem_updates','retrain_engineer','decommission_document','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','iso_13485_deviation','patient_safety_risk','internal_only','none'
  )),
  owner text not null,
  estimated_cost_rupees numeric(12,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.doc_version_control_capa_actions_r3504 enable row level security;

create index if not exists idx_doc_version_control_capa_r3504_log on public.doc_version_control_capa_actions_r3504(doc_log_id);
create index if not exists idx_doc_version_control_capa_r3504_status on public.doc_version_control_capa_actions_r3504(capa_status);

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

  -- 16 document version-control rows
  insert into public.doc_version_control_r3504 (
    organization_id, engineer_name, device_model, document_ref, document_type,
    current_version, latest_version, versions_behind, currency_status, last_updated,
    controlled_copy, distribution_pct, notes
  )
  select v_org_id, q.eng, q.model, q.ref, q.dtype,
    q.curv, q.latv, q.vb, q.cstat, q.lupd::date,
    q.cc, q.dist::numeric, q.nt
  from (values
    ('Ravi Kumar','GE Logiq P9 Ultrasound','DOC-USG-001','service_manual',
     'SM-4.2','SM-4.2',0,'current','2026-07-10',true,100,'Service manual current with OEM revision'),
    ('Ravi Kumar','GE Logiq P9 Ultrasound','DOC-USG-002','firmware',
     'FW-11.0.3','FW-11.2.0',2,'minor_behind','2026-06-15',true,80,'Firmware two minor revisions behind, update scheduled'),
    ('Anjali Sharma','Philips IntelliVue MX550','DOC-MON-011','service_manual',
     'SM-2.1','SM-3.0',3,'major_behind','2026-03-20',true,60,'Monitor service manual a major version behind'),
    ('Anjali Sharma','Philips IntelliVue MX550','DOC-MON-012','wiring_diagram',
     'WD-1.0','WD-1.0',0,'current','2026-07-05',true,100,'Wiring diagram matches installed configuration'),
    ('Suresh Patel','Drager Fabius GS Anesthesia','DOC-ANES-021','user_manual',
     'UM-5.0','UM-5.0',0,'current','2026-07-12',true,100,'User manual current'),
    ('Suresh Patel','Drager Fabius GS Anesthesia','DOC-ANES-022','firmware',
     'FW-3.4','FW-4.1',4,'major_behind','2026-01-18',false,40,'Anesthesia firmware major behind, uncontrolled copy in use'),
    ('Meena Nair','Mindray BeneHeart D6 Defibrillator','DOC-DEFIB-031','safety_notice',
     'SN-2019-04','SN-2024-02',5,'obsolete','2019-09-10',false,20,'Safety notice obsolete, superseded field notices not distributed'),
    ('Meena Nair','Mindray BeneHeart D6 Defibrillator','DOC-DEFIB-032','service_manual',
     'SM-1.5','SM-1.6',1,'minor_behind','2026-05-22',true,90,'Defib service manual one minor revision behind'),
    ('Arjun Reddy','Siemens Somatom CT Scanner','DOC-CT-041','sop',
     'SOP-QA-7','SOP-QA-8',1,'minor_behind','2026-06-01',true,85,'CT daily QA SOP minor update pending'),
    ('Arjun Reddy','Siemens Somatom CT Scanner','DOC-CT-042','firmware',
     'FW-VA48','FW-VA48',0,'current','2026-07-08',true,100,'CT firmware current'),
    ('Kavya Iyer','Fresenius 4008S Dialysis','DOC-DIAL-051','service_manual',
     null,null,0,'missing','2026-02-14',false,0,'Service manual missing for legacy dialysis unit'),
    ('Kavya Iyer','Fresenius 4008S Dialysis','DOC-DIAL-052','user_manual',
     'UM-2.0','UM-2.0',0,'current','2026-07-01',true,100,'Dialysis user manual current'),
    ('Rohit Verma','Maquet Servo-i Ventilator','DOC-VENT-061','firmware',
     'FW-6.1','FW-8.0',6,'obsolete','2020-11-30',false,15,'Ventilator firmware obsolete, OEM support ended'),
    ('Rohit Verma','Maquet Servo-i Ventilator','DOC-VENT-062','wiring_diagram',
     'WD-2.2','WD-2.3',1,'minor_behind','2026-06-20',true,88,'Ventilator wiring diagram minor revision behind'),
    ('Priya Menon','Stryker SDC3 Endoscopy','DOC-ENDO-071','service_manual',
     'SM-3.0','SM-4.5',3,'major_behind','2026-04-02',true,55,'Endoscopy service manual major behind'),
    ('Priya Menon','Stryker SDC3 Endoscopy','DOC-ENDO-072','safety_notice',
     'SN-2025-01','SN-2025-01',0,'current','2026-07-15',true,100,'Safety notice acknowledged and current')
  ) as q(eng, model, ref, dtype, curv, latv, vb, cstat, lupd, cc, dist, nt);

  -- CAPA seed — attach to specific documents via document_ref
  insert into public.doc_version_control_capa_actions_r3504 (
    organization_id, doc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, owner, estimated_cost_rupees,
    target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.own, q.cost::numeric,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('DOC-USG-002','firmware_outdated','no_update_subscription','apply_firmware_update','in_progress','internal_only','Ravi Kumar',12000,'2026-08-05',null,'Firmware update scheduled during next PM visit'),
    ('DOC-MON-011','version_obsolete','oem_update_not_received','request_oem_manual','open','iso_13485_deviation','Anjali Sharma',8000,'2026-08-10',null,'Requested latest service manual from Philips'),
    ('DOC-ANES-022','uncontrolled_copy','document_control_gap','recall_uncontrolled_copies','escalated','nabh_finding','Suresh Patel',5000,'2026-08-01',null,'Uncontrolled firmware doc in use, recall issued'),
    ('DOC-DEFIB-031','safety_notice_unacknowledged','engineer_not_notified','redistribute_to_sites','overdue','patient_safety_risk','Meena Nair',15000,'2026-06-30',null,'Obsolete safety notice, redistribution overdue'),
    ('DOC-DIAL-051','manual_missing','vendor_portal_access_lost','request_oem_manual','open','cdsco_notifiable','Kavya Iyer',9000,'2026-08-15',null,'Service manual missing, portal access being restored'),
    ('DOC-VENT-061','firmware_outdated','legacy_device_unsupported','decommission_document','verification_pending','iso_13485_deviation','Rohit Verma',22000,'2026-07-20','2026-07-18','Legacy ventilator firmware obsolete, decommission documented'),
    ('DOC-ENDO-071','version_obsolete','oem_update_not_received','download_latest_version','closed','internal_only','Priya Menon',6000,'2026-07-10','2026-07-08','Downloaded and distributed latest endoscopy manual'),
    ('DOC-DEFIB-032','distribution_gap','firmware_push_failed','redistribute_to_sites','in_progress','internal_only','Meena Nair',3000,'2026-08-08',null,'Minor revision, redistribution in progress')
  ) as q(ref, fc, rc, ca, cst, ri, own, cost, tcd, acd, nt)
  join public.doc_version_control_r3504 e
    on e.organization_id = v_org_id and e.document_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Currency-status distribution
create or replace function public.founder_r3504_currency_status_rollup()
returns table(currency_status text, documents bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doc_version_control_r3504)
  select l.currency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.doc_version_control_r3504 l
  group by l.currency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3504_currency_status_rollup() from public, anon;
grant execute on function public.founder_r3504_currency_status_rollup() to authenticated;

-- 2) Document-type scorecard
create or replace function public.founder_r3504_document_type_scorecard()
returns table(
  document_type text,
  total_docs bigint,
  current_docs bigint,
  minor_behind bigint,
  major_behind bigint,
  obsolete_docs bigint,
  missing_docs bigint,
  controlled_copies bigint,
  current_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.document_type,
    count(*)::bigint,
    count(*) filter (where l.currency_status = 'current')::bigint,
    count(*) filter (where l.currency_status = 'minor_behind')::bigint,
    count(*) filter (where l.currency_status = 'major_behind')::bigint,
    count(*) filter (where l.currency_status = 'obsolete')::bigint,
    count(*) filter (where l.currency_status = 'missing')::bigint,
    count(*) filter (where l.controlled_copy = true)::bigint,
    round(100.0 * count(*) filter (where l.currency_status = 'current')::numeric / nullif(count(*),0), 1)
  from public.doc_version_control_r3504 l
  group by l.document_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3504_document_type_scorecard() from public, anon;
grant execute on function public.founder_r3504_document_type_scorecard() to authenticated;

-- 3) Document-type × currency-status matrix
create or replace function public.founder_r3504_doc_type_currency_matrix()
returns table(document_type text, currency_status text, documents bigint, avg_versions_behind numeric, avg_distribution_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.document_type, l.currency_status, count(*)::bigint,
    round(avg(l.versions_behind), 2),
    round(avg(l.distribution_pct), 1)
  from public.doc_version_control_r3504 l
  group by l.document_type, l.currency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3504_doc_type_currency_matrix() from public, anon;
grant execute on function public.founder_r3504_doc_type_currency_matrix() to authenticated;

-- 4) Monthly currency trend (by document last-updated month)
create or replace function public.founder_r3504_monthly_currency_trend()
returns table(month text, documents bigint, current_docs bigint, obsolete_missing bigint, avg_versions_behind numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select to_char(date_trunc('month', l.last_updated), 'YYYY-MM'),
    count(*)::bigint,
    count(*) filter (where l.currency_status = 'current')::bigint,
    count(*) filter (where l.currency_status in ('obsolete','missing'))::bigint,
    round(avg(l.versions_behind), 2)
  from public.doc_version_control_r3504 l
  group by date_trunc('month', l.last_updated)
  order by date_trunc('month', l.last_updated) desc;
end;
$$;

revoke execute on function public.founder_r3504_monthly_currency_trend() from public, anon;
grant execute on function public.founder_r3504_monthly_currency_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3504_capa_status_board()
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
  from public.doc_version_control_capa_actions_r3504 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3504_capa_status_board() from public, anon;
grant execute on function public.founder_r3504_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3504_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.doc_version_control_capa_actions_r3504)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.doc_version_control_capa_actions_r3504 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3504_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3504_root_cause_pareto() to authenticated;

-- 7) Obsolescence-impact digest (by regulatory impact)
create or replace function public.founder_r3504_obsolescence_impact_digest()
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
  from public.doc_version_control_capa_actions_r3504 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3504_obsolescence_impact_digest() from public, anon;
grant execute on function public.founder_r3504_obsolescence_impact_digest() to authenticated;

-- 8) High-risk documentation queue (obsolete / missing / major-behind)
create or replace function public.founder_r3504_high_risk_queue()
returns table(
  engineer_name text,
  device_model text,
  document_ref text,
  document_type text,
  currency_status text,
  current_version text,
  latest_version text,
  versions_behind int,
  last_updated date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.engineer_name, l.device_model, l.document_ref, l.document_type,
    l.currency_status, l.current_version, l.latest_version, l.versions_behind,
    l.last_updated, l.notes
  from public.doc_version_control_r3504 l
  where l.currency_status in ('obsolete','missing','major_behind')
     or l.controlled_copy = false
     or l.versions_behind >= 3
     or coalesce(l.distribution_pct, 0) < 60
  order by l.versions_behind desc, l.last_updated asc;
end;
$$;

revoke execute on function public.founder_r3504_high_risk_queue() from public, anon;
grant execute on function public.founder_r3504_high_risk_queue() to authenticated;
