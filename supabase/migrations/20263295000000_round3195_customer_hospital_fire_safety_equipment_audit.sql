-- Round 3195: Customer Hospital Fire-Safety Equipment (Extinguisher/Hydrant/Smoke-Detector) Audit
-- Fire-safety asset audit — asset type × pressure × refill × detector test × panel zone × evacuation route × NOC × CAPA

-- =============================================================================
-- TABLE 1: fire_safety_r3195 — individual fire-safety asset audit entries
-- =============================================================================
create table if not exists public.fire_safety_r3195 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  building_block text not null,
  floor_zone text not null,
  asset_tag text not null,
  asset_type text not null check (asset_type in (
    'extinguisher_abc','extinguisher_co2','extinguisher_water','extinguisher_foam',
    'fire_hydrant','hose_reel','smoke_detector','heat_detector',
    'sprinkler_head','fire_door','fire_alarm_panel','exit_signage'
  )),
  audit_date date not null,
  audited_at timestamptz not null,
  pressure_gauge_status text check (pressure_gauge_status in (
    'in_green_zone','overcharged','undercharged','gauge_missing','not_applicable'
  )),
  refill_due_date date,
  refill_status text not null check (refill_status in (
    'current','due_within_30_days','overdue','not_applicable'
  )),
  detector_test_result text check (detector_test_result in (
    'pass','fail','intermittent','not_tested','not_applicable'
  )),
  panel_zone_status text check (panel_zone_status in (
    'normal','zone_fault','zone_isolated','panel_offline','not_applicable'
  )),
  evacuation_route_status text not null check (evacuation_route_status in (
    'clear','partially_blocked','blocked','signage_missing'
  )),
  hydrant_flow_lpm numeric(6,1),
  noc_status text not null check (noc_status in (
    'valid','expiring_within_90_days','expired','renewal_in_process','not_available'
  )),
  noc_expiry_date date,
  audit_verdict text not null check (audit_verdict in (
    'compliant','minor_nonconformity','major_nonconformity',
    'critical_failure','pending_reaudit','conditionally_compliant'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fire_safety_r3195 enable row level security;

create index if not exists idx_fire_safety_r3195_org on public.fire_safety_r3195(organization_id);
create index if not exists idx_fire_safety_r3195_date on public.fire_safety_r3195(audit_date);
create index if not exists idx_fire_safety_r3195_verdict on public.fire_safety_r3195(audit_verdict);

-- =============================================================================
-- TABLE 2: fire_safety_capa_actions_r3195 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.fire_safety_capa_actions_r3195 (
  id uuid primary key default gen_random_uuid(),
  fire_safety_id uuid not null references public.fire_safety_r3195(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pressure_loss','refill_overdue','detector_fail','panel_zone_fault',
    'route_blocked','noc_lapse','hydrant_low_flow','sprinkler_obstruction',
    'fire_door_defect','signage_missing','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'cylinder_seal_leak','vendor_refill_backlog','detector_dust_contamination',
    'wiring_loop_break','storage_encroachment','documentation_lapse',
    'pump_pressure_drop','corroded_valve','door_closer_worn',
    'budget_approval_pending','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_cylinder','expedite_refill_contract','clean_and_retest_detector',
    'repair_wiring_loop','clear_and_mark_route','renew_noc_application',
    'service_hydrant_pump','replace_valve','replace_door_closer',
    'conduct_fire_drill','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'fire_noc_risk','nabh_finding','municipal_notice','none','internal_only','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fire_safety_capa_actions_r3195 enable row level security;

create index if not exists idx_fire_safety_capa_r3195_log on public.fire_safety_capa_actions_r3195(fire_safety_id);
create index if not exists idx_fire_safety_capa_r3195_status on public.fire_safety_capa_actions_r3195(capa_status);

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

  -- 14 fire-safety audit rows
  insert into public.fire_safety_r3195 (
    organization_id, hospital_name, building_block, floor_zone, asset_tag, asset_type,
    audit_date, audited_at, pressure_gauge_status, refill_due_date, refill_status,
    detector_test_result, panel_zone_status, evacuation_route_status, hydrant_flow_lpm,
    noc_status, noc_expiry_date, audit_verdict, notes
  )
  select v_org_id, q.hosp, q.blk, q.fz, q.tag, q.atype,
    q.ad::date, q.aud::timestamptz, q.pg, q.rd::date, q.rs,
    q.dt, q.pz, q.ev, q.flow,
    q.noc, q.ne::date, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','Block A','GF-Lobby','FS-APL-001','extinguisher_abc',
     '2026-07-10','2026-07-10 09:15:00+05:30','in_green_zone','2026-12-15','current',
     'not_applicable','not_applicable','clear',null,'valid','2027-03-31','compliant','Annual maintenance sticker present and legible'),
    ('Apollo Hyderabad Jubilee Hills','Block B','3F-ICU-Corridor','FS-APL-014','smoke_detector',
     '2026-07-10','2026-07-10 10:05:00+05:30','not_applicable',null,'not_applicable',
     'fail','zone_fault','clear',null,'valid','2027-03-31','major_nonconformity','Detector no response on aerosol test — zone 7 fault on panel'),
    ('Fortis Bannerghatta Bengaluru','Tower 1','GF-East-Yard','FS-FRT-003','fire_hydrant',
     '2026-07-09','2026-07-09 08:30:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','not_applicable','clear',620.0,'valid','2026-11-30','major_nonconformity','Flow 620 LPM below 900 LPM requirement — pump pressure drop'),
    ('Fortis Bannerghatta Bengaluru','Tower 2','2F-Cath-Lab','FS-FRT-021','extinguisher_co2',
     '2026-07-09','2026-07-09 09:20:00+05:30','undercharged','2026-06-20','overdue',
     'not_applicable','not_applicable','clear',null,'valid','2026-11-30','critical_failure','CO2 weight 18 pct below rated — refill overdue 19 days'),
    ('Manipal Whitefield Bengaluru','Main Block','4F-Ward-Stairwell','FS-MNP-008','fire_door',
     '2026-07-08','2026-07-08 11:10:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','not_applicable','partially_blocked',null,'expiring_within_90_days','2026-09-15','minor_nonconformity','Door closer slow — wedge holding door open removed on spot'),
    ('Manipal Whitefield Bengaluru','Main Block','5F-OT-Complex','FS-MNP-019','sprinkler_head',
     '2026-07-08','2026-07-08 12:00:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','normal','clear',null,'expiring_within_90_days','2026-09-15','compliant','Sprinkler heads clear of storage; 45 cm clearance maintained'),
    ('AIIMS New Delhi Ansari Nagar','OPD Block','1F-Fire-Control-Room','FS-AIM-002','fire_alarm_panel',
     '2026-07-07','2026-07-07 07:45:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','panel_offline','clear',null,'valid','2027-01-31','critical_failure','Panel offline after wiring loop break — hot work nearby suspected'),
    ('AIIMS New Delhi Ansari Nagar','OPD Block','2F-Records','FS-AIM-027','extinguisher_water',
     '2026-07-07','2026-07-07 08:30:00+05:30','in_green_zone','2027-01-10','current',
     'not_applicable','not_applicable','clear',null,'valid','2027-01-31','compliant','Hydro-test date embossed and legible'),
    ('KIMS Secunderabad','Block C','GF-Service-Corridor','FS-KIM-006','exit_signage',
     '2026-07-06','2026-07-06 10:15:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','not_applicable','blocked',null,'expired','2026-05-31','critical_failure','Exit corridor blocked by stored mattresses; fire NOC expired'),
    ('KIMS Secunderabad','Block C','3F-Ward-Landing','FS-KIM-017','hose_reel',
     '2026-07-06','2026-07-06 11:00:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','not_applicable','clear',310.0,'expired','2026-05-31','pending_reaudit','Hose reel nozzle corroded — flow marginal, reaudit after valve replacement'),
    ('Care Hospitals Banjara Hills','Main Wing','B1-Kitchen','FS-CAR-004','heat_detector',
     '2026-07-05','2026-07-05 09:40:00+05:30','not_applicable',null,'not_applicable',
     'pass','normal','clear',null,'valid','2027-02-28','compliant','Heat detector responded within 30 seconds on test'),
    ('Yashoda Somajiguda Hyderabad','Tower B','GF-Generator-Yard','FS-YSH-010','extinguisher_foam',
     '2026-07-04','2026-07-04 08:20:00+05:30','gauge_missing','2026-08-05','due_within_30_days',
     'not_applicable','not_applicable','clear',null,'renewal_in_process','2026-07-31','minor_nonconformity','Pressure gauge glass missing; refill due within 30 days'),
    ('St John''s Bengaluru','Academic Block','2F-Library','FS-STJ-012','smoke_detector',
     '2026-07-03','2026-07-03 10:50:00+05:30','not_applicable',null,'not_applicable',
     'intermittent','zone_isolated','clear',null,'valid','2026-12-31','minor_nonconformity','Detector intermittent — zone isolated pending cleaning'),
    ('Rainbow Children''s Hyderabad','NICU Block','1F-NICU-Store','FS-RBW-007','sprinkler_head',
     '2026-07-02','2026-07-02 09:00:00+05:30','not_applicable',null,'not_applicable',
     'not_applicable','normal','partially_blocked',null,'valid','2026-10-31','major_nonconformity','Storage racks within 30 cm of sprinkler heads — obstruction risk')
  ) as q(hosp, blk, fz, tag, atype, ad, aud, pg, rd, rs, dt, pz, ev, flow, noc, ne, verdict, nt);

  -- CAPA seed — attach to specific audited assets by asset tag
  insert into public.fire_safety_capa_actions_r3195 (
    fire_safety_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('FS-APL-014','detector_fail','detector_dust_contamination','clean_and_retest_detector','2026-07-18',null,'in_progress','nabh_finding',2500.00,'ICU corridor detector cleaning by AMC vendor booked'),
    ('FS-FRT-003','hydrant_low_flow','pump_pressure_drop','service_hydrant_pump','2026-07-20',null,'open','fire_noc_risk',65000.00,'Jockey pump service quote awaited'),
    ('FS-FRT-021','refill_overdue','vendor_refill_backlog','expedite_refill_contract','2026-07-15','2026-07-14','closed','internal_only',4800.00,'CO2 cylinder swapped with charged spare'),
    ('FS-AIM-002','panel_zone_fault','wiring_loop_break','repair_wiring_loop','2026-07-12',null,'escalated','patient_safety_alert',38000.00,'Loop break traced to OPD renovation zone — fire watch posted'),
    ('FS-KIM-006','route_blocked','storage_encroachment','clear_and_mark_route','2026-07-08',null,'overdue','municipal_notice',12000.00,'Housekeeping clearance pending; NOC renewal blocked'),
    ('FS-RBW-007','sprinkler_obstruction','storage_encroachment','clear_and_mark_route','2026-07-25',null,'verification_pending','nabh_finding',6000.00,'Racks relocated — clearance photo verification pending')
  ) as q(tag, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.fire_safety_r3195 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3195_audit_verdict_rollup()
returns table(audit_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fire_safety_r3195)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fire_safety_r3195 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3195_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3195_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level fire-safety scorecard
create or replace function public.founder_r3195_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  compliant bigint,
  major_nc bigint,
  critical bigint,
  detector_fails bigint,
  routes_blocked bigint,
  noc_lapsed bigint,
  compliance_pct numeric
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
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'major_nonconformity')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_failure')::bigint,
    count(*) filter (where l.detector_test_result in ('fail','intermittent'))::bigint,
    count(*) filter (where l.evacuation_route_status in ('blocked','partially_blocked'))::bigint,
    count(*) filter (where l.noc_status in ('expired','not_available'))::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.fire_safety_r3195 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3195_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3195_hospital_scorecard() to authenticated;

-- 3) Asset-type verdict matrix
create or replace function public.founder_r3195_asset_type_matrix()
returns table(asset_type text, audits bigint, compliant bigint, minor_nc bigint, major_nc bigint, critical bigint, avg_hydrant_flow_lpm numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_type, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'minor_nonconformity')::bigint,
    count(*) filter (where l.audit_verdict = 'major_nonconformity')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_failure')::bigint,
    round(avg(l.hydrant_flow_lpm), 1)
  from public.fire_safety_r3195 l
  group by l.asset_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3195_asset_type_matrix() from public, anon;
grant execute on function public.founder_r3195_asset_type_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3195_daily_trend()
returns table(audit_date date, audits bigint, compliant bigint, critical bigint, detector_fails bigint, routes_blocked bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'compliant')::bigint,
    count(*) filter (where l.audit_verdict = 'critical_failure')::bigint,
    count(*) filter (where l.detector_test_result in ('fail','intermittent'))::bigint,
    count(*) filter (where l.evacuation_route_status in ('blocked','partially_blocked'))::bigint
  from public.fire_safety_r3195 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3195_daily_trend() from public, anon;
grant execute on function public.founder_r3195_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3195_capa_status_board()
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
  from public.fire_safety_capa_actions_r3195 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3195_capa_status_board() from public, anon;
grant execute on function public.founder_r3195_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3195_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fire_safety_capa_actions_r3195)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fire_safety_capa_actions_r3195 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3195_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3195_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3195_regulatory_impact_digest()
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
  from public.fire_safety_capa_actions_r3195 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3195_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3195_regulatory_impact_digest() to authenticated;

-- 8) High-risk assets queue (top individual concerns)
create or replace function public.founder_r3195_high_risk_queue()
returns table(
  hospital_name text,
  building_block text,
  floor_zone text,
  asset_tag text,
  asset_type text,
  audit_date date,
  audit_verdict text,
  evacuation_route_status text,
  noc_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.building_block, l.floor_zone, l.asset_tag, l.asset_type,
    l.audit_date, l.audit_verdict, l.evacuation_route_status, l.noc_status, l.notes
  from public.fire_safety_r3195 l
  where l.audit_verdict in ('major_nonconformity','critical_failure','pending_reaudit')
     or l.evacuation_route_status in ('blocked','partially_blocked','signage_missing')
     or l.noc_status in ('expired','not_available')
     or l.detector_test_result in ('fail','intermittent')
     or l.refill_status = 'overdue'
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3195_high_risk_queue() from public, anon;
grant execute on function public.founder_r3195_high_risk_queue() to authenticated;
