-- Round 3191: Customer Hospital Nurse-Call & Code-Blue Alert System Latency Audit
-- Nurse-call QA log — zone/ward × call type × trigger-to-display × display-to-ack × annunciator × battery backup × escalation tier × dead zone × CAPA

-- =============================================================================
-- TABLE 1: nurse_call_r3191 — individual nurse-call / code-blue latency tests
-- =============================================================================
create table if not exists public.nurse_call_r3191 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_name text not null,
  zone_code text not null,
  system_make text not null,
  test_code text not null,
  test_date date not null,
  call_type text not null check (call_type in (
    'routine_bedside','bathroom_pull_cord','code_blue',
    'staff_assist','nurse_presence_cancel','shower_emergency'
  )),
  bed_or_point_code text not null,
  trigger_to_display_seconds numeric(6,2) not null,
  display_to_ack_seconds numeric(6,2),
  annunciator_working boolean not null default true,
  dome_light_working boolean not null default true,
  battery_backup_result text check (battery_backup_result in (
    'pass','fail','partial_wards_only','not_tested'
  )),
  escalation_tier_result text check (escalation_tier_result in (
    'tier1_only_pass','tier2_pass','tier3_pass','tier2_fail','tier3_fail','not_tested'
  )),
  dead_zone_found boolean not null default false,
  dead_zone_location text,
  tested_by_profile_id uuid references public.profiles(id) on delete set null,
  latency_verdict text not null check (latency_verdict in (
    'within_target','marginal','breach','critical_breach','retest_required','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nurse_call_r3191 enable row level security;

create index if not exists idx_nurse_call_r3191_org on public.nurse_call_r3191(organization_id);
create index if not exists idx_nurse_call_r3191_date on public.nurse_call_r3191(test_date);
create index if not exists idx_nurse_call_r3191_verdict on public.nurse_call_r3191(latency_verdict);

-- =============================================================================
-- TABLE 2: nurse_call_capa_actions_r3191 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.nurse_call_capa_actions_r3191 (
  id uuid primary key default gen_random_uuid(),
  nurse_call_id uuid not null references public.nurse_call_r3191(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'latency_breach','annunciator_failure','battery_backup_failure','escalation_failure',
    'dead_zone','dome_light_failure','wiring_fault','software_config_error',
    'preventive_maintenance_due','operator_error'
  )),
  root_cause text not null check (root_cause in (
    'nurse_console_firmware_bug','wireless_repeater_gap','ups_battery_expired',
    'loose_junction_wiring','paging_gateway_misconfig','call_point_switch_worn',
    'network_switch_overload','staffing_console_unmanned','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'update_console_firmware','install_wireless_repeater','replace_ups_battery',
    'rewire_junction_box','reconfigure_paging_gateway','replace_call_point',
    'segregate_network_vlan','retrain_ward_staff','schedule_amc_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','patient_safety_alert','internal_only','none','fire_safety_linked','insurance_audit_flag'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.nurse_call_capa_actions_r3191 enable row level security;

create index if not exists idx_nurse_call_capa_r3191_call on public.nurse_call_capa_actions_r3191(nurse_call_id);
create index if not exists idx_nurse_call_capa_r3191_status on public.nurse_call_capa_actions_r3191(capa_status);

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

  -- 13 nurse-call latency test rows
  insert into public.nurse_call_r3191 (
    organization_id, hospital_name, ward_name, zone_code, system_make, test_code, test_date,
    call_type, bed_or_point_code, trigger_to_display_seconds, display_to_ack_seconds,
    annunciator_working, dome_light_working, battery_backup_result, escalation_tier_result,
    dead_zone_found, dead_zone_location, latency_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.zone, q.mk, q.tc, q.td::date,
    q.ct, q.bp, q.tds, q.das,
    q.ann, q.dome, q.bb, q.esc,
    q.dz, q.dzl, q.lv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU Ward 4','ZONE-A','Rauland Responder 5','NC-APL-001','2026-07-02','code_blue','ICU4-B07',
     1.40,3.20,true,true,'pass','tier3_pass',false,null,'within_target','Code-blue drill — console and overhead page under 2 sec'),
    ('Apollo Hyderabad Jubilee Hills','General Ward 7','ZONE-B','Rauland Responder 5','NC-APL-002','2026-07-02','routine_bedside','GW7-B12',
     4.80,41.00,true,true,'pass','tier1_only_pass',false,null,'marginal','Ack slow during shift-change handover'),
    ('Fortis Bannerghatta Bengaluru','CCU Ward 2','ZONE-A','Ascom Telligence','NC-FRT-001','2026-07-01','code_blue','CCU2-B03',
     6.50,12.00,false,true,'pass','tier2_fail',false,null,'critical_breach','Annunciator silent at nurse station — display only'),
    ('Fortis Bannerghatta Bengaluru','Ortho Ward 5','ZONE-C','Ascom Telligence','NC-FRT-002','2026-07-01','bathroom_pull_cord','OW5-BTH2',
     2.10,18.50,true,true,'fail','tier1_only_pass',false,null,'breach','Call point dead on UPS changeover — battery bank expired'),
    ('Manipal Whitefield Bengaluru','Pediatric Ward 3','ZONE-B','Schrack Seconet VISOCALL','NC-MNP-001','2026-06-30','routine_bedside','PW3-B09',
     1.90,22.00,true,true,'pass','tier2_pass',false,null,'within_target','Routine bedside call — clean run'),
    ('Manipal Whitefield Bengaluru','Maternity Ward 6','ZONE-D','Schrack Seconet VISOCALL','NC-MNP-002','2026-06-30','code_blue','MW6-B01',
     2.20,4.10,true,false,'pass','tier3_pass',true,'Corridor near lift lobby','breach','Dome light dead plus wireless dead zone at lift lobby'),
    ('AIIMS New Delhi Ansari Nagar','Emergency Ward 1','ZONE-A','Hill-Rom NaviCare','NC-AIM-001','2026-06-29','code_blue','EW1-B04',
     1.10,2.80,true,true,'pass','tier3_pass',false,null,'within_target','Fastest code-blue chain in the audit'),
    ('AIIMS New Delhi Ansari Nagar','General Ward 9','ZONE-E','Hill-Rom NaviCare','NC-AIM-002','2026-06-29','staff_assist','GW9-B21',
     8.90,55.00,true,true,'not_tested','tier2_fail',true,'North wing beds 21-24 bay','critical_breach','Repeater gap — 8.9 sec trigger-to-display'),
    ('KIMS Secunderabad','ICU Ward 2','ZONE-A','Amico Alert4','NC-KIM-001','2026-06-28','code_blue','ICU2-B05',
     3.60,9.00,true,true,'pass','tier2_pass',false,null,'marginal','Display OK — paging gateway added 2 sec queue delay'),
    ('Care Hospitals Banjara Hills','Cardiac Ward 3','ZONE-B','Ackermann clino','NC-CAR-001','2026-06-28','bathroom_pull_cord','CW3-BTH1',
     2.40,15.00,true,true,'pass','tier1_only_pass',false,null,'within_target','Pull-cord chain passed on first attempt'),
    ('Yashoda Somajiguda Hyderabad','Neuro Ward 4','ZONE-C','Rauland Responder 4','NC-YSH-001','2026-06-27','routine_bedside','NW4-B14',
     5.20,38.00,true,true,'partial_wards_only','tier2_fail',false,null,'breach','Legacy console — tier-2 RMO page never delivered'),
    ('St John''s Bengaluru','Oncology Ward 5','ZONE-B','Ascom Telligence','NC-STJ-001','2026-06-27','shower_emergency','ONC5-SH02',
     2.00,11.00,true,true,'pass','tier2_pass',false,null,'within_target','Shower emergency chain within target'),
    ('Rainbow Children''s Hyderabad','NICU Ward 1','ZONE-A','Schrack Seconet VISOCALL','NC-RBW-001','2026-06-26','code_blue','NICU1-B02',
     2.60,null,true,true,'pass','not_tested',false,null,'pending_review','Ack timestamp not captured — logger fault, retest scheduled')
  ) as q(hosp, ward, zone, mk, tc, td, ct, bp, tds, das, ann, dome, bb, esc, dz, dzl, lv, nt);

  -- CAPA seed — attach to specific tests via test_code
  insert into public.nurse_call_capa_actions_r3191 (
    nurse_call_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('NC-FRT-001','annunciator_failure','nurse_console_firmware_bug','update_console_firmware','2026-07-08',null,'in_progress','patient_safety_alert',18000.00,'Ascom console firmware patch scheduled with OEM'),
    ('NC-FRT-002','battery_backup_failure','ups_battery_expired','replace_ups_battery','2026-07-06','2026-07-04','closed','nabh_finding',22000.00,'UPS battery bank replaced and load-tested'),
    ('NC-MNP-002','dead_zone','wireless_repeater_gap','install_wireless_repeater','2026-07-10',null,'in_progress','patient_safety_alert',35000.00,'Repeater ordered for lift-lobby corridor'),
    ('NC-AIM-002','latency_breach','wireless_repeater_gap','install_wireless_repeater','2026-07-05',null,'escalated','nabh_finding',42000.00,'North wing bay needs two repeaters — escalated to biomedical head'),
    ('NC-YSH-001','escalation_failure','paging_gateway_misconfig','reconfigure_paging_gateway','2026-07-03',null,'overdue','patient_safety_alert',8000.00,'Tier-2 RMO page rule missing — overdue past target'),
    ('NC-KIM-001','latency_breach','paging_gateway_misconfig','reconfigure_paging_gateway','2026-07-09',null,'verification_pending','internal_only',5500.00,'Gateway queue tuned — retest pending'),
    ('NC-RBW-001','software_config_error','pending_investigation','none_required','2026-07-12',null,'open','internal_only',0.00,'Ack logger fault under joint investigation with vendor')
  ) as q(tc_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.nurse_call_r3191 e
    on e.organization_id = v_org_id and e.test_code = q.tc_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Latency verdict distribution
create or replace function public.founder_r3191_latency_verdict_rollup()
returns table(latency_verdict text, tests bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nurse_call_r3191)
  select l.latency_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.nurse_call_r3191 l
  group by l.latency_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3191_latency_verdict_rollup() from public, anon;
grant execute on function public.founder_r3191_latency_verdict_rollup() to authenticated;

-- 2) Hospital-level latency scorecard
create or replace function public.founder_r3191_hospital_scorecard()
returns table(
  hospital_name text,
  total_tests bigint,
  within_target bigint,
  breaches bigint,
  critical_breaches bigint,
  dead_zones bigint,
  annunciator_failures bigint,
  avg_trigger_display_sec numeric,
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
    count(*) filter (where l.latency_verdict = 'within_target')::bigint,
    count(*) filter (where l.latency_verdict = 'breach')::bigint,
    count(*) filter (where l.latency_verdict = 'critical_breach')::bigint,
    count(*) filter (where l.dead_zone_found)::bigint,
    count(*) filter (where not l.annunciator_working)::bigint,
    round(avg(l.trigger_to_display_seconds), 2),
    round(100.0 * count(*) filter (where l.latency_verdict = 'within_target')::numeric / nullif(count(*),0), 1)
  from public.nurse_call_r3191 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3191_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3191_hospital_scorecard() to authenticated;

-- 3) Call type × escalation tier matrix
create or replace function public.founder_r3191_call_type_matrix()
returns table(call_type text, escalation_tier_result text, tests bigint, within_target bigint, avg_trigger_display_sec numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.call_type, l.escalation_tier_result, count(*)::bigint,
    count(*) filter (where l.latency_verdict = 'within_target')::bigint,
    round(avg(l.trigger_to_display_seconds), 2)
  from public.nurse_call_r3191 l
  group by l.call_type, l.escalation_tier_result
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3191_call_type_matrix() from public, anon;
grant execute on function public.founder_r3191_call_type_matrix() to authenticated;

-- 4) Daily latency trend
create or replace function public.founder_r3191_daily_latency_trend()
returns table(test_date date, tests bigint, code_blue_tests bigint, avg_trigger_display_sec numeric, avg_display_ack_sec numeric, breaches bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.test_date,
    count(*)::bigint,
    count(*) filter (where l.call_type = 'code_blue')::bigint,
    round(avg(l.trigger_to_display_seconds), 2),
    round(avg(l.display_to_ack_seconds), 2),
    count(*) filter (where l.latency_verdict in ('breach','critical_breach'))::bigint
  from public.nurse_call_r3191 l
  group by l.test_date
  order by l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3191_daily_latency_trend() from public, anon;
grant execute on function public.founder_r3191_daily_latency_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3191_capa_status_board()
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
  from public.nurse_call_capa_actions_r3191 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3191_capa_status_board() from public, anon;
grant execute on function public.founder_r3191_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3191_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.nurse_call_capa_actions_r3191)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.nurse_call_capa_actions_r3191 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3191_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3191_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3191_regulatory_impact_digest()
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
  from public.nurse_call_capa_actions_r3191 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3191_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3191_regulatory_impact_digest() to authenticated;

-- 8) High-risk test queue (top individual concerns)
create or replace function public.founder_r3191_high_risk_queue()
returns table(
  hospital_name text,
  ward_name text,
  zone_code text,
  test_date date,
  call_type text,
  trigger_to_display_seconds numeric,
  latency_verdict text,
  escalation_tier_result text,
  dead_zone_found text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_name, l.zone_code, l.test_date,
    l.call_type, l.trigger_to_display_seconds, l.latency_verdict, l.escalation_tier_result,
    case when l.dead_zone_found then 'yes' else 'no' end, l.notes
  from public.nurse_call_r3191 l
  where l.latency_verdict in ('breach','critical_breach','retest_required','pending_review')
     or l.dead_zone_found
     or not l.annunciator_working
     or l.battery_backup_result = 'fail'
     or l.escalation_tier_result in ('tier2_fail','tier3_fail')
  order by l.test_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3191_high_risk_queue() from public, anon;
grant execute on function public.founder_r3191_high_risk_queue() to authenticated;
