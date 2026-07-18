-- Round 3223: Customer Hospital Telemetry Central Station Coverage & Alarm-Escalation Audit
-- Telemetry QA — ward zone × beds monitored × transmitters × signal dropout × antenna gaps × display latency × escalation tiers × battery swap × CAPA

-- =============================================================================
-- TABLE 1: telemetry_station_r3223 — central-station coverage audit log
-- =============================================================================
create table if not exists public.telemetry_station_r3223 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  station_code text not null,
  ward_zone text not null check (ward_zone in (
    'icu_zone_a','icu_zone_b','ccu','step_down_unit',
    'cardiac_ward','emergency_observation','post_op_recovery','general_ward_monitored'
  )),
  central_station_model text not null,
  audit_date date not null,
  beds_monitored int not null,
  transmitters_active int not null,
  signal_dropout_pct numeric(5,2) not null,
  antenna_coverage_gap text not null check (antenna_coverage_gap in (
    'none','single_dead_zone','multiple_dead_zones','corridor_gap',
    'lift_lobby_gap','washroom_gap','stairwell_gap'
  )),
  central_display_latency_sec numeric(5,2) not null,
  alarm_escalation_tiers_test text not null check (alarm_escalation_tiers_test in (
    'all_tiers_pass','partial_pass','tier1_local_only',
    'tier2_station_fail','tier3_paging_fail','not_tested'
  )),
  battery_swap_compliance text not null check (battery_swap_compliance in (
    'fully_compliant','minor_lapses','major_lapses','no_log_maintained','not_applicable'
  )),
  coverage_verdict text not null check (coverage_verdict in (
    'fully_compliant','minor_gaps','major_gaps','critical_failure','pending_review','conditional_pass'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.telemetry_station_r3223 enable row level security;

create index if not exists idx_telemetry_station_r3223_org on public.telemetry_station_r3223(organization_id);
create index if not exists idx_telemetry_station_r3223_date on public.telemetry_station_r3223(audit_date);
create index if not exists idx_telemetry_station_r3223_verdict on public.telemetry_station_r3223(coverage_verdict);

-- =============================================================================
-- TABLE 2: telemetry_station_capa_actions_r3223 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.telemetry_station_capa_actions_r3223 (
  id uuid primary key default gen_random_uuid(),
  station_audit_id uuid not null references public.telemetry_station_r3223(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'signal_dropout_high','antenna_dead_zone','display_latency_breach','escalation_tier_fail',
    'battery_log_lapse','transmitter_shortfall','central_station_freeze','pager_integration_fail'
  )),
  root_cause text not null check (root_cause in (
    'antenna_cable_damaged','access_point_offline','channel_interference',
    'ups_battery_degraded','software_version_outdated','staffing_gap_night_shift',
    'transmitter_battery_stockout','network_switch_fault','building_renovation_shielding','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_antenna_run','add_repeater_node','reassign_wmts_channel',
    'upgrade_cms_software','replace_ups_batteries','retrain_ward_staff',
    'restock_transmitter_batteries','replace_network_switch','schedule_rf_site_survey','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','patient_safety_alert','internal_only','none','iso_13485_deviation','cdsco_notifiable'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.telemetry_station_capa_actions_r3223 enable row level security;

create index if not exists idx_telemetry_capa_r3223_audit on public.telemetry_station_capa_actions_r3223(station_audit_id);
create index if not exists idx_telemetry_capa_r3223_status on public.telemetry_station_capa_actions_r3223(capa_status);

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

  -- 14 station audit rows
  insert into public.telemetry_station_r3223 (
    organization_id, hospital_name, station_code, ward_zone, central_station_model,
    audit_date, beds_monitored, transmitters_active, signal_dropout_pct,
    antenna_coverage_gap, central_display_latency_sec, alarm_escalation_tiers_test,
    battery_swap_compliance, coverage_verdict, notes
  )
  select v_org_id, q.hosp, q.sc, q.wz, q.model,
    q.ad::date, q.bm, q.ta, q.sd,
    q.acg, q.lat, q.aet,
    q.bsc, q.cv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','TCS-APL-01','icu_zone_a','Philips IntelliVue PIC iX','2026-07-02',24,24,0.40,
     'none',1.20,'all_tiers_pass','fully_compliant','fully_compliant','Reference ward — clean RF survey last quarter'),
    ('Apollo Hyderabad Jubilee Hills','TCS-APL-02','step_down_unit','Philips IntelliVue PIC iX','2026-07-02',16,14,2.10,
     'corridor_gap',1.80,'partial_pass','minor_lapses','minor_gaps','Two transmitters in service; corridor near lift drops signal'),
    ('Fortis Bannerghatta Bengaluru','TCS-FRT-01','ccu','GE CARESCAPE Central Station','2026-07-01',12,12,6.50,
     'multiple_dead_zones',2.40,'tier2_station_fail','major_lapses','critical_failure','Dropout 6.5% and station alarm relay failed during drill'),
    ('Fortis Bannerghatta Bengaluru','TCS-FRT-02','cardiac_ward','GE CARESCAPE Central Station','2026-07-01',20,18,3.20,
     'lift_lobby_gap',2.00,'tier3_paging_fail','minor_lapses','major_gaps','Pager gateway did not fire tier-3 escalation'),
    ('Manipal Whitefield Bengaluru','TCS-MNP-01','icu_zone_b','Mindray BeneVision CMS','2026-06-30',18,18,0.90,
     'none',1.50,'all_tiers_pass','fully_compliant','fully_compliant','Post-upgrade audit — CMS v5.2'),
    ('Manipal Whitefield Bengaluru','TCS-MNP-02','post_op_recovery','Mindray BeneVision CMS','2026-06-30',10,9,1.60,
     'washroom_gap',1.70,'partial_pass','minor_lapses','minor_gaps','Single washroom shadow zone; repeater quote requested'),
    ('AIIMS New Delhi Ansari Nagar','TCS-AIM-01','emergency_observation','Philips IntelliVue PIC iX','2026-06-29',30,26,4.80,
     'stairwell_gap',3.10,'tier2_station_fail','no_log_maintained','major_gaps','Four transmitters awaiting battery stock; latency breach at 3.1s'),
    ('AIIMS New Delhi Ansari Nagar','TCS-AIM-02','icu_zone_a','Philips IntelliVue PIC iX','2026-06-29',22,22,0.70,
     'none',1.30,'all_tiers_pass','fully_compliant','fully_compliant','Flagship ICU — exemplary battery log'),
    ('KIMS Secunderabad','TCS-KIM-01','general_ward_monitored','Spacelabs Xhibit Central','2026-06-28',28,24,5.90,
     'multiple_dead_zones',2.80,'not_tested','major_lapses','critical_failure','Escalation drill skipped two quarters running'),
    ('Care Hospitals Banjara Hills','TCS-CAR-01','ccu','Nihon Kohden CNS-6201','2026-06-28',14,14,1.10,
     'none',1.40,'all_tiers_pass','minor_lapses','minor_gaps','Battery swaps logged late on night shift'),
    ('Yashoda Somajiguda Hyderabad','TCS-YSH-01','cardiac_ward','GE CARESCAPE Central Station','2026-06-27',26,25,2.60,
     'corridor_gap',1.90,'partial_pass','minor_lapses','minor_gaps','One corridor bay drops during shift change'),
    ('St John''s Bengaluru','TCS-STJ-01','step_down_unit','Mindray BeneVision CMS','2026-06-26',12,12,0.50,
     'none',1.10,'all_tiers_pass','fully_compliant','fully_compliant','Weekly tier drill documented'),
    ('Rainbow Children''s Hyderabad','TCS-RBW-01','icu_zone_b','Philips IntelliVue PIC iX','2026-06-25',20,17,7.40,
     'lift_lobby_gap',3.60,'tier1_local_only','no_log_maintained','pending_review','Renovation shielding suspected — RF survey booked'),
    ('Rainbow Children''s Hyderabad','TCS-RBW-02','post_op_recovery','Philips IntelliVue PIC iX','2026-06-25',8,8,1.90,
     'washroom_gap',1.60,'partial_pass','minor_lapses','conditional_pass','Cleared pending repeater install within 30 days')
  ) as q(hosp, sc, wz, model, ad, bm, ta, sd, acg, lat, aet, bsc, cv, nt);

  -- CAPA seed — attach to specific station audits
  insert into public.telemetry_station_capa_actions_r3223 (
    station_audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('TCS-FRT-01','signal_dropout_high','channel_interference','reassign_wmts_channel','2026-07-08',null,'in_progress','patient_safety_alert',18000.00,'Co-channel interference from neighbouring tower block'),
    ('TCS-FRT-02','pager_integration_fail','network_switch_fault','replace_network_switch','2026-07-06',null,'escalated','nabh_finding',42000.00,'Tier-3 paging path down — escalated to OEM'),
    ('TCS-AIM-01','battery_log_lapse','transmitter_battery_stockout','restock_transmitter_batteries','2026-07-03','2026-07-01','closed','internal_only',9500.00,'Stock replenished; swap log restarted'),
    ('TCS-KIM-01','escalation_tier_fail','staffing_gap_night_shift','retrain_ward_staff','2026-07-10',null,'open','nabh_finding',6000.00,'Quarterly escalation drill to be rescheduled'),
    ('TCS-KIM-01','antenna_dead_zone','antenna_cable_damaged','replace_antenna_run','2026-06-30',null,'overdue','iso_13485_deviation',54000.00,'Cable run replacement overdue 12 days'),
    ('TCS-RBW-01','antenna_dead_zone','building_renovation_shielding','schedule_rf_site_survey','2026-07-12',null,'verification_pending','patient_safety_alert',35000.00,'Survey vendor booked; interim bedside alarms enabled'),
    ('TCS-APL-02','display_latency_breach','software_version_outdated','upgrade_cms_software','2026-07-15',null,'open','none',125000.00,'CMS upgrade quote approved; scheduled with OEM')
  ) as q(sc_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.telemetry_station_r3223 e
    on e.organization_id = v_org_id and e.station_code = q.sc_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage verdict distribution
create or replace function public.founder_r3223_coverage_verdict_rollup()
returns table(coverage_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.telemetry_station_r3223)
  select l.coverage_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.telemetry_station_r3223 l
  group by l.coverage_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3223_coverage_verdict_rollup() from public, anon;
grant execute on function public.founder_r3223_coverage_verdict_rollup() to authenticated;

-- 2) Hospital-level coverage scorecard
create or replace function public.founder_r3223_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fully_compliant bigint,
  major_gap_audits bigint,
  critical_failures bigint,
  avg_dropout_pct numeric,
  avg_latency_sec numeric,
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
    count(*) filter (where l.coverage_verdict = 'fully_compliant')::bigint,
    count(*) filter (where l.coverage_verdict = 'major_gaps')::bigint,
    count(*) filter (where l.coverage_verdict = 'critical_failure')::bigint,
    round(avg(l.signal_dropout_pct), 2),
    round(avg(l.central_display_latency_sec), 2),
    round(100.0 * count(*) filter (where l.coverage_verdict = 'fully_compliant')::numeric / nullif(count(*),0), 1)
  from public.telemetry_station_r3223 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3223_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3223_hospital_scorecard() to authenticated;

-- 3) Ward zone × escalation-tier test matrix
create or replace function public.founder_r3223_ward_escalation_matrix()
returns table(ward_zone text, alarm_escalation_tiers_test text, audits bigint, total_beds bigint, avg_dropout_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.ward_zone, l.alarm_escalation_tiers_test, count(*)::bigint,
    coalesce(sum(l.beds_monitored),0)::bigint,
    round(avg(l.signal_dropout_pct), 2)
  from public.telemetry_station_r3223 l
  group by l.ward_zone, l.alarm_escalation_tiers_test
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3223_ward_escalation_matrix() from public, anon;
grant execute on function public.founder_r3223_ward_escalation_matrix() to authenticated;

-- 4) Daily dropout & latency trend
create or replace function public.founder_r3223_daily_dropout_trend()
returns table(audit_date date, audits bigint, avg_dropout_pct numeric, max_latency_sec numeric, dead_zone_audits bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    round(avg(l.signal_dropout_pct), 2),
    max(l.central_display_latency_sec),
    count(*) filter (where l.antenna_coverage_gap <> 'none')::bigint
  from public.telemetry_station_r3223 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3223_daily_dropout_trend() from public, anon;
grant execute on function public.founder_r3223_daily_dropout_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3223_capa_status_board()
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
  from public.telemetry_station_capa_actions_r3223 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3223_capa_status_board() from public, anon;
grant execute on function public.founder_r3223_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3223_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.telemetry_station_capa_actions_r3223)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.telemetry_station_capa_actions_r3223 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3223_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3223_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3223_regulatory_impact_digest()
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
  from public.telemetry_station_capa_actions_r3223 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3223_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3223_regulatory_impact_digest() to authenticated;

-- 8) High-risk stations queue (top individual concerns)
create or replace function public.founder_r3223_high_risk_stations()
returns table(
  hospital_name text,
  station_code text,
  ward_zone text,
  audit_date date,
  coverage_verdict text,
  signal_dropout_pct numeric,
  central_display_latency_sec numeric,
  alarm_escalation_tiers_test text,
  battery_swap_compliance text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.station_code, l.ward_zone, l.audit_date,
    l.coverage_verdict, l.signal_dropout_pct, l.central_display_latency_sec,
    l.alarm_escalation_tiers_test, l.battery_swap_compliance, l.notes
  from public.telemetry_station_r3223 l
  where l.coverage_verdict in ('major_gaps','critical_failure','pending_review','conditional_pass')
     or l.signal_dropout_pct > 3.0
     or l.alarm_escalation_tiers_test in ('tier1_local_only','tier2_station_fail','tier3_paging_fail','not_tested')
     or l.battery_swap_compliance in ('major_lapses','no_log_maintained')
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3223_high_risk_stations() from public, anon;
grant execute on function public.founder_r3223_high_risk_stations() to authenticated;
