-- Round 3227: Customer Hospital Surgical-Table Accessories & Patient-Positioning Device Audit
-- Positioning QA — accessory type × attachment lock test × padding integrity × pressure-injury risk × sterilizable × load rating × inventory × CAPA

-- =============================================================================
-- TABLE 1: positioning_device_r3227 — surgical-table accessory / positioning device audits
-- =============================================================================
create table if not exists public.positioning_device_r3227 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  accessory_asset_tag text not null,
  accessory_type text not null check (accessory_type in (
    'arm_board','lithotomy_stirrups','head_ring_horseshoe','gel_pad_positioner',
    'lateral_clamp_support','traction_attachment','bean_bag_vacuum','leg_holder_knee_crutch'
  )),
  attachment_interface text not null check (attachment_interface in (
    'side_rail_clamp','dedicated_socket','strap_velcro','carbon_fibre_slot','integrated_table_module'
  )),
  audit_date date not null,
  attachment_lock_test text not null check (attachment_lock_test in (
    'pass','fail','slips_under_load','loose_play','not_applicable'
  )),
  padding_integrity text not null check (padding_integrity in (
    'intact','minor_wear','cracked_foam','torn_cover','gel_leak','missing_padding','contaminated_stain'
  )),
  pressure_injury_risk_score int not null check (pressure_injury_risk_score between 0 and 10),
  sterilizable_flag boolean not null default false,
  load_rating_kg numeric(6,2),
  load_rating_ok boolean not null default true,
  inventory_complete boolean not null default true,
  audit_verdict text not null check (audit_verdict in (
    'fit_for_use','conditional_use','repair_needed','replace_immediately','quarantined','pending_review'
  )),
  auditor_profile_id uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.positioning_device_r3227 enable row level security;

create index if not exists idx_positioning_device_r3227_org on public.positioning_device_r3227(organization_id);
create index if not exists idx_positioning_device_r3227_date on public.positioning_device_r3227(audit_date);
create index if not exists idx_positioning_device_r3227_verdict on public.positioning_device_r3227(audit_verdict);

-- =============================================================================
-- TABLE 2: positioning_device_capa_actions_r3227 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.positioning_device_capa_actions_r3227 (
  id uuid primary key default gen_random_uuid(),
  device_audit_id uuid not null references public.positioning_device_r3227(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'lock_failure','padding_degradation','pressure_injury_risk','sterilization_gap',
    'load_rating_breach','missing_inventory','corrosion_damage','labeling_missing'
  )),
  root_cause text not null check (root_cause in (
    'clamp_mechanism_worn','foam_aging','cover_material_torn','gel_migration',
    'overloading_misuse','improper_cleaning_agent','storage_damage','procurement_spec_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_clamp_assembly','replace_gel_pad','reupholster_cover','retrain_ot_staff',
    'procure_replacement','remove_from_service','deep_clean_re_sterilize','update_inventory_register','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','patient_safety_alert','none','internal_only','iso_13485_deviation','insurance_liability'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.positioning_device_capa_actions_r3227 enable row level security;

create index if not exists idx_positioning_capa_r3227_device on public.positioning_device_capa_actions_r3227(device_audit_id);
create index if not exists idx_positioning_capa_r3227_status on public.positioning_device_capa_actions_r3227(capa_status);

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

  -- 13 positioning-device audit rows
  insert into public.positioning_device_r3227 (
    organization_id, hospital_name, ot_room_code, accessory_asset_tag,
    accessory_type, attachment_interface, audit_date,
    attachment_lock_test, padding_integrity, pressure_injury_risk_score,
    sterilizable_flag, load_rating_kg, load_rating_ok, inventory_complete,
    audit_verdict, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag,
    q.acc, q.iface, q.ad::date,
    q.lt, q.pad, q.risk,
    q.ster, q.lkg, q.lok, q.inv,
    q.vd, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-2','PD-APL-101','arm_board','side_rail_clamp','2026-07-02',
     'pass','intact',2,true,180.00,true,true,'fit_for_use','Carbon-fibre arm board locks firm at all angles'),
    ('Apollo Hyderabad Jubilee Hills','OT-2','PD-APL-102','gel_pad_positioner','strap_velcro','2026-07-02',
     'not_applicable','gel_leak',7,false,120.00,true,true,'replace_immediately','Gel migrated to one edge — uneven sacral support'),
    ('Fortis Bannerghatta Bengaluru','OT-1','PD-FRT-201','lithotomy_stirrups','dedicated_socket','2026-07-01',
     'slips_under_load','minor_wear',6,true,135.00,false,true,'repair_needed','Boot clamp slips under 20 kg lateral pull'),
    ('Fortis Bannerghatta Bengaluru','OT-1','PD-FRT-202','traction_attachment','dedicated_socket','2026-07-01',
     'fail','intact',5,true,220.00,true,false,'quarantined','Traction bar lock pin missing from kit'),
    ('Manipal Whitefield Bengaluru','OT-3','PD-MNP-301','head_ring_horseshoe','strap_velcro','2026-06-30',
     'not_applicable','cracked_foam',8,true,40.00,true,true,'replace_immediately','Foam cracked through — occipital pressure-injury risk'),
    ('Manipal Whitefield Bengaluru','OT-3','PD-MNP-302','lateral_clamp_support','side_rail_clamp','2026-06-30',
     'pass','intact',3,true,150.00,true,true,'fit_for_use','Lateral brace bites rail cleanly, pads supple'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','PD-AIM-401','bean_bag_vacuum','strap_velcro','2026-06-29',
     'not_applicable','torn_cover',7,false,160.00,true,false,'repair_needed','Vacuum bean bag cover torn near valve — loses shape mid-case'),
    ('AIIMS New Delhi Ansari Nagar','OT-5','PD-AIM-402','arm_board','side_rail_clamp','2026-06-29',
     'pass','minor_wear',4,true,180.00,true,true,'conditional_use','Pad edge wear — reupholster at next PM window'),
    ('KIMS Secunderabad','OT-4','PD-KIM-501','leg_holder_knee_crutch','dedicated_socket','2026-06-28',
     'pass','intact',3,true,140.00,true,true,'fit_for_use','Knee crutch pair complete with sterilizable pads'),
    ('Care Hospitals Banjara Hills','OT-2','PD-CAR-601','gel_pad_positioner','strap_velcro','2026-06-28',
     'not_applicable','missing_padding',9,false,100.00,true,false,'quarantined','Sacral gel pad missing from positioning set'),
    ('Yashoda Somajiguda Hyderabad','OT-6','PD-YSH-701','lithotomy_stirrups','side_rail_clamp','2026-06-27',
     'pass','intact',2,true,135.00,true,true,'fit_for_use','Yellofin-type stirrups fully serviceable'),
    ('St John''s Bengaluru','OT-1','PD-STJ-801','lateral_clamp_support','side_rail_clamp','2026-06-27',
     'fail','minor_wear',6,true,150.00,true,true,'repair_needed','Clamp jaw pitted — does not bite rail; cleaning agent suspected'),
    ('Rainbow Children''s Hyderabad','OT-3','PD-RBW-901','head_ring_horseshoe','strap_velcro','2026-06-26',
     'not_applicable','intact',3,true,30.00,true,true,'pending_review','Paediatric size-range verification pending against case mix')
  ) as q(hosp, ot, tag, acc, iface, ad, lt, pad, risk, ster, lkg, lok, inv, vd, nt);

  -- CAPA seed — attach to specific device audits via asset tag
  insert into public.positioning_device_capa_actions_r3227 (
    device_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.st, q.ri, q.cost, q.nt
  from (values
    ('PD-APL-102','padding_degradation','gel_migration','replace_gel_pad','2026-07-08',null,'in_progress','patient_safety_alert',18500.00,'OEM gel pad on order — loaner pad issued to OT-2'),
    ('PD-FRT-201','lock_failure','clamp_mechanism_worn','replace_clamp_assembly','2026-07-06',null,'open','nabh_finding',9200.00,'Stirrup boot clamp kit quoted by vendor'),
    ('PD-FRT-202','missing_inventory','storage_damage','procure_replacement','2026-07-10',null,'escalated','patient_safety_alert',32000.00,'Lock pin lost — traction cases diverted to OT-2 table'),
    ('PD-MNP-301','pressure_injury_risk','foam_aging','procure_replacement','2026-07-04','2026-07-02','closed','internal_only',6500.00,'New horseshoe head ring received and inducted'),
    ('PD-CAR-601','missing_inventory','procurement_spec_gap','update_inventory_register','2026-06-25',null,'overdue','nabh_finding',12000.00,'Sacral pad missing since June audit — register still unreconciled'),
    ('PD-STJ-801','lock_failure','improper_cleaning_agent','retrain_ot_staff','2026-07-09',null,'verification_pending','iso_13485_deviation',0.00,'Corrosive cleaner pitted clamp jaw — staff retrained on IFU agents')
  ) as q(tag, fc, rc, ca, tcd, acd, st, ri, cost, nt)
  join public.positioning_device_r3227 e
    on e.organization_id = v_org_id and e.accessory_asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3227_verdict_rollup()
returns table(audit_verdict text, devices bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.positioning_device_r3227)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.positioning_device_r3227 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3227_verdict_rollup() from public, anon;
grant execute on function public.founder_r3227_verdict_rollup() to authenticated;

-- 2) Hospital-level positioning-safety scorecard
create or replace function public.founder_r3227_hospital_scorecard()
returns table(
  hospital_name text,
  total_devices bigint,
  fit_for_use bigint,
  repair_needed bigint,
  replace_immediately bigint,
  lock_failures bigint,
  high_risk_devices bigint,
  avg_risk_score numeric,
  fit_pct numeric
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
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    count(*) filter (where l.audit_verdict = 'repair_needed')::bigint,
    count(*) filter (where l.audit_verdict = 'replace_immediately')::bigint,
    count(*) filter (where l.attachment_lock_test in ('fail','slips_under_load','loose_play'))::bigint,
    count(*) filter (where l.pressure_injury_risk_score >= 7)::bigint,
    round(avg(l.pressure_injury_risk_score)::numeric, 1),
    round(100.0 * count(*) filter (where l.audit_verdict = 'fit_for_use')::numeric / nullif(count(*),0), 1)
  from public.positioning_device_r3227 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3227_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3227_hospital_scorecard() to authenticated;

-- 3) Accessory type × attachment interface matrix
create or replace function public.founder_r3227_accessory_type_matrix()
returns table(accessory_type text, attachment_interface text, devices bigint, fit_for_use bigint, avg_risk_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.accessory_type, l.attachment_interface, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'fit_for_use')::bigint,
    round(avg(l.pressure_injury_risk_score)::numeric, 1)
  from public.positioning_device_r3227 l
  group by l.accessory_type, l.attachment_interface
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3227_accessory_type_matrix() from public, anon;
grant execute on function public.founder_r3227_accessory_type_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3227_audit_daily_trend()
returns table(audit_date date, audited bigint, lock_pass bigint, lock_fail bigint, high_risk bigint, inventory_gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.attachment_lock_test = 'pass')::bigint,
    count(*) filter (where l.attachment_lock_test in ('fail','slips_under_load','loose_play'))::bigint,
    count(*) filter (where l.pressure_injury_risk_score >= 7)::bigint,
    count(*) filter (where not l.inventory_complete)::bigint
  from public.positioning_device_r3227 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3227_audit_daily_trend() from public, anon;
grant execute on function public.founder_r3227_audit_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3227_capa_status_board()
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
  from public.positioning_device_capa_actions_r3227 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3227_capa_status_board() from public, anon;
grant execute on function public.founder_r3227_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3227_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.positioning_device_capa_actions_r3227)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.positioning_device_capa_actions_r3227 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3227_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3227_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3227_regulatory_impact_digest()
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
  from public.positioning_device_capa_actions_r3227 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3227_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3227_regulatory_impact_digest() to authenticated;

-- 8) High-risk device queue (top individual concerns)
create or replace function public.founder_r3227_high_risk_queue()
returns table(
  hospital_name text,
  ot_room_code text,
  accessory_asset_tag text,
  accessory_type text,
  audit_date date,
  audit_verdict text,
  attachment_lock_test text,
  padding_integrity text,
  pressure_injury_risk_score int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.accessory_asset_tag, l.accessory_type, l.audit_date,
    l.audit_verdict, l.attachment_lock_test, l.padding_integrity, l.pressure_injury_risk_score, l.notes
  from public.positioning_device_r3227 l
  where l.audit_verdict in ('repair_needed','replace_immediately','quarantined','pending_review')
     or l.attachment_lock_test in ('fail','slips_under_load','loose_play')
     or l.pressure_injury_risk_score >= 7
     or not l.load_rating_ok
     or not l.inventory_complete
  order by l.pressure_injury_risk_score desc, l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3227_high_risk_queue() from public, anon;
grant execute on function public.founder_r3227_high_risk_queue() to authenticated;
