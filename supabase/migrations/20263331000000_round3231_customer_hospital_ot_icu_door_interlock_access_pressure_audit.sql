-- Round 3231: Customer Hospital OT/ICU Door-Interlock, Access-Control & Pressure-Cascade Audit
-- Access QA — zone × interlock pair test × auto-door sensor × access-card log × pressure cascade × door seal × emergency release × CAPA

-- =============================================================================
-- TABLE 1: door_interlock_r3231 — individual door/zone access audits
-- =============================================================================
create table if not exists public.door_interlock_r3231 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  zone_code text not null,
  zone_type text not null check (zone_type in (
    'operating_theatre','icu_critical_care','isolation_negative_pressure',
    'cssd_sterile_store','bone_marrow_transplant_unit','cath_lab'
  )),
  door_pair_code text not null,
  audit_date date not null,
  audited_at timestamptz,
  interlock_pair_test text not null check (interlock_pair_test in (
    'both_doors_lock','single_door_fail','both_fail','override_stuck','pass_with_delay','not_tested'
  )),
  auto_door_sensor text not null check (auto_door_sensor in (
    'functional','slow_response','no_detection','intermittent','sensor_misaligned','not_applicable'
  )),
  access_card_log_working boolean not null default false,
  pressure_cascade_pa numeric(5,1),
  pressure_direction_correct boolean,
  pressure_cascade_verdict text not null check (pressure_cascade_verdict in (
    'cascade_correct','reversed_flow','insufficient_differential','fluctuating','not_measured'
  )),
  door_seal_integrity text not null check (door_seal_integrity in (
    'intact','minor_wear','gasket_torn','misaligned_frame','air_leak_audible','replaced_recently'
  )),
  emergency_release_test text not null check (emergency_release_test in (
    'released_instantly','delayed_release','failed_to_release','manual_override_only','not_tested'
  )),
  audited_by_profile_id uuid references public.profiles(id) on delete set null,
  overall_verdict text not null check (overall_verdict in (
    'compliant','minor_gaps','major_nonconformity','critical_fail','pending_review','conditional_pass'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.door_interlock_r3231 enable row level security;

create index if not exists idx_door_interlock_r3231_org on public.door_interlock_r3231(organization_id);
create index if not exists idx_door_interlock_r3231_date on public.door_interlock_r3231(audit_date);
create index if not exists idx_door_interlock_r3231_verdict on public.door_interlock_r3231(overall_verdict);

-- =============================================================================
-- TABLE 2: door_interlock_capa_actions_r3231 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.door_interlock_capa_actions_r3231 (
  id uuid primary key default gen_random_uuid(),
  audit_id uuid not null references public.door_interlock_r3231(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'interlock_bypass','sensor_failure','access_log_gap','pressure_reversal',
    'seal_degradation','emergency_release_fail','card_reader_offline',
    'door_held_open_alarm_mute','preventive_maintenance_due','training_gap'
  )),
  root_cause text not null check (root_cause in (
    'controller_relay_worn','sensor_misalignment','door_closer_spring_fatigue',
    'gasket_aging','ahu_imbalance','exhaust_fan_failure','card_reader_firmware_bug',
    'network_switch_down','staff_tailgating_practice','pending_investigation','service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_interlock_controller','realign_door_sensor','replace_door_gasket',
    'rebalance_ahu_dampers','service_exhaust_fan','update_reader_firmware',
    'restore_network_link','retrain_staff_access_policy','schedule_amc_visit',
    'install_door_position_alarm','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','fire_safety_notice','none','internal_only','iso_14644_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.door_interlock_capa_actions_r3231 enable row level security;

create index if not exists idx_door_interlock_capa_r3231_audit on public.door_interlock_capa_actions_r3231(audit_id);
create index if not exists idx_door_interlock_capa_r3231_status on public.door_interlock_capa_actions_r3231(capa_status);

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

  -- 13 audit rows
  insert into public.door_interlock_r3231 (
    organization_id, hospital_name, zone_code, zone_type, door_pair_code,
    audit_date, audited_at, interlock_pair_test, auto_door_sensor,
    access_card_log_working, pressure_cascade_pa, pressure_direction_correct,
    pressure_cascade_verdict, door_seal_integrity, emergency_release_test,
    overall_verdict, notes
  )
  select v_org_id, q.hosp, q.zc, q.zt, q.dp,
    q.ad::date, q.aud::timestamptz, q.ipt, q.ads,
    q.acl, q.pcp, q.pdc,
    q.pcv, q.dsi, q.ert,
    q.ov, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','APL-OT-3','operating_theatre','DP-OT3-A/B','2026-07-02','2026-07-02 08:30:00+05:30',
     'both_doors_lock','functional',true,15.5,true,'cascade_correct','intact','released_instantly','compliant','Quarterly access audit — all checks green'),
    ('Apollo Hyderabad Jubilee Hills','APL-CSSD-1','cssd_sterile_store','DP-CSSD-PASS','2026-07-02','2026-07-02 10:00:00+05:30',
     'single_door_fail','functional',true,12.0,true,'cascade_correct','minor_wear','released_instantly','minor_gaps','Pass-through hatch interlock releases early on clean side'),
    ('Fortis Bannerghatta Bengaluru','FRT-ICU-2','icu_critical_care','DP-ICU2-MAIN','2026-07-01','2026-07-01 09:15:00+05:30',
     'both_doors_lock','slow_response',false,8.0,true,'insufficient_differential','intact','released_instantly','minor_gaps','Card log server offline 3 days — no swipe history'),
    ('Fortis Bannerghatta Bengaluru','FRT-ISO-4','isolation_negative_pressure','DP-ISO4-ANTE','2026-07-01','2026-07-01 11:40:00+05:30',
     'both_doors_lock','functional',true,6.5,false,'reversed_flow','air_leak_audible','released_instantly','critical_fail','Anteroom reading +6.5 Pa — should be negative; exhaust fan tripped'),
    ('Manipal Whitefield Bengaluru','MNP-OT-1','operating_theatre','DP-OT1-A/B','2026-06-30','2026-06-30 07:45:00+05:30',
     'override_stuck','functional',true,14.0,true,'cascade_correct','intact','delayed_release','major_nonconformity','Interlock override key stuck in bypass — doors free-swing'),
    ('Manipal Whitefield Bengaluru','MNP-CSSD-2','cssd_sterile_store','DP-CSSD-DIRTY','2026-06-30','2026-06-30 09:20:00+05:30',
     'both_doors_lock','functional',true,10.5,true,'cascade_correct','gasket_torn','released_instantly','minor_gaps','Dirty-side door gasket torn 20 cm along bottom edge'),
    ('AIIMS New Delhi Ansari Nagar','AIM-OT-5','operating_theatre','DP-OT5-A/B','2026-06-29','2026-06-29 08:00:00+05:30',
     'both_doors_lock','functional',true,16.0,true,'cascade_correct','intact','released_instantly','compliant','NABH audit prep — zero findings'),
    ('AIIMS New Delhi Ansari Nagar','AIM-BMT-1','bone_marrow_transplant_unit','DP-BMT1-ANTE','2026-06-29','2026-06-29 10:30:00+05:30',
     'both_doors_lock','intermittent',true,18.5,true,'fluctuating','intact','released_instantly','minor_gaps','Positive pressure swings 12-19 Pa with AHU cycling'),
    ('KIMS Secunderabad','KIM-ICU-1','icu_critical_care','DP-ICU1-MAIN','2026-06-28','2026-06-28 09:00:00+05:30',
     'both_fail','no_detection',false,null,null,'not_measured','misaligned_frame','failed_to_release','critical_fail','Both interlock doors unlock together; emergency release jammed'),
    ('Care Hospitals Banjara Hills','CAR-OT-2','operating_theatre','DP-OT2-A/B','2026-06-28','2026-06-28 11:15:00+05:30',
     'pass_with_delay','functional',true,13.5,true,'cascade_correct','minor_wear','released_instantly','conditional_pass','Interlock releases after 9 s — spec is 5 s max'),
    ('Yashoda Somajiguda Hyderabad','YSH-ISO-2','isolation_negative_pressure','DP-ISO2-ANTE','2026-06-27','2026-06-27 08:45:00+05:30',
     'both_doors_lock','functional',true,-12.5,true,'cascade_correct','intact','released_instantly','compliant','Negative cascade verified with smoke pencil'),
    ('St John''s Bengaluru','STJ-OT-1','operating_theatre','DP-OT1-A/B','2026-06-27','2026-06-27 10:20:00+05:30',
     'both_doors_lock','sensor_misaligned',true,15.0,true,'cascade_correct','intact','not_tested','pending_review','Auto-door opens for trolleys only when centred; emergency test deferred'),
    ('Rainbow Children''s Hyderabad','RBW-ICU-3','icu_critical_care','DP-PICU3-MAIN','2026-06-26','2026-06-26 09:30:00+05:30',
     'both_doors_lock','functional',false,9.5,true,'insufficient_differential','minor_wear','released_instantly','minor_gaps','Card reader logs blank since firmware update')
  ) as q(hosp, zc, zt, dp, ad, aud, ipt, ads, acl, pcp, pdc, pcv, dsi, ert, ov, nt);

  -- 7 CAPA rows — attach to specific audits via zone_code
  insert into public.door_interlock_capa_actions_r3231 (
    audit_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('FRT-ISO-4','pressure_reversal','exhaust_fan_failure','service_exhaust_fan','2026-07-04',null,'escalated','patient_safety_alert',38000.00,'Isolation room out of service until negative pressure restored'),
    ('KIM-ICU-1','interlock_bypass','controller_relay_worn','replace_interlock_controller','2026-07-06',null,'in_progress','nabh_finding',52000.00,'Controller relay pack ordered; doors on manual guard till fitted'),
    ('KIM-ICU-1','emergency_release_fail','door_closer_spring_fatigue','install_door_position_alarm','2026-07-08',null,'open','fire_safety_notice',18500.00,'Release lever jams under load — fire officer notified'),
    ('MNP-OT-1','interlock_bypass','pending_investigation','retrain_staff_access_policy','2026-07-05','2026-07-01','closed','internal_only',0.00,'Override key removed; staff briefed on bypass policy'),
    ('MNP-CSSD-2','seal_degradation','gasket_aging','replace_door_gasket','2026-07-10',null,'verification_pending','iso_14644_deviation',6200.00,'New gasket fitted; particle re-count scheduled'),
    ('FRT-ICU-2','access_log_gap','network_switch_down','restore_network_link','2026-06-25',null,'overdue','nabh_finding',4500.00,'Switch RMA pending 8 days — swipe logs still not syncing'),
    ('RBW-ICU-3','card_reader_offline','card_reader_firmware_bug','update_reader_firmware','2026-07-09',null,'in_progress','internal_only',2500.00,'Vendor patch scheduled for weekend window')
  ) as q(zc, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.door_interlock_r3231 e
    on e.organization_id = v_org_id and e.zone_code = q.zc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Overall verdict distribution
create or replace function public.founder_r3231_verdict_rollup()
returns table(overall_verdict text, audits bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.door_interlock_r3231)
  select l.overall_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.door_interlock_r3231 l
  group by l.overall_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3231_verdict_rollup() from public, anon;
grant execute on function public.founder_r3231_verdict_rollup() to authenticated;

-- 2) Hospital-level access-compliance scorecard
create or replace function public.founder_r3231_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  compliant bigint,
  critical_fails bigint,
  interlock_fails bigint,
  pressure_fails bigint,
  card_log_down bigint,
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
    count(*) filter (where l.overall_verdict = 'compliant')::bigint,
    count(*) filter (where l.overall_verdict = 'critical_fail')::bigint,
    count(*) filter (where l.interlock_pair_test in ('single_door_fail','both_fail','override_stuck'))::bigint,
    count(*) filter (where l.pressure_cascade_verdict in ('reversed_flow','insufficient_differential'))::bigint,
    count(*) filter (where not l.access_card_log_working)::bigint,
    round(100.0 * count(*) filter (where l.overall_verdict = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.door_interlock_r3231 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3231_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3231_hospital_scorecard() to authenticated;

-- 3) Zone-type matrix
create or replace function public.founder_r3231_zone_type_matrix()
returns table(zone_type text, audits bigint, compliant bigint, critical_fails bigint, avg_pressure_pa numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.zone_type, count(*)::bigint,
    count(*) filter (where l.overall_verdict = 'compliant')::bigint,
    count(*) filter (where l.overall_verdict = 'critical_fail')::bigint,
    round(avg(l.pressure_cascade_pa), 1)
  from public.door_interlock_r3231 l
  group by l.zone_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3231_zone_type_matrix() from public, anon;
grant execute on function public.founder_r3231_zone_type_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3231_daily_trend()
returns table(audit_date date, audits bigint, compliant bigint, critical_fails bigint, pressure_issues bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date, count(*)::bigint,
    count(*) filter (where l.overall_verdict = 'compliant')::bigint,
    count(*) filter (where l.overall_verdict = 'critical_fail')::bigint,
    count(*) filter (where l.pressure_cascade_verdict in ('reversed_flow','insufficient_differential','fluctuating'))::bigint
  from public.door_interlock_r3231 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3231_daily_trend() from public, anon;
grant execute on function public.founder_r3231_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3231_capa_status_board()
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
  from public.door_interlock_capa_actions_r3231 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3231_capa_status_board() from public, anon;
grant execute on function public.founder_r3231_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3231_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.door_interlock_capa_actions_r3231)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.door_interlock_capa_actions_r3231 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3231_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3231_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3231_regulatory_impact_digest()
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
  from public.door_interlock_capa_actions_r3231 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3231_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3231_regulatory_impact_digest() to authenticated;

-- 8) High-risk zones queue (top individual concerns)
create or replace function public.founder_r3231_high_risk_queue()
returns table(
  hospital_name text,
  zone_code text,
  zone_type text,
  audit_date date,
  overall_verdict text,
  interlock_pair_test text,
  pressure_cascade_verdict text,
  emergency_release_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.zone_code, l.zone_type, l.audit_date,
    l.overall_verdict, l.interlock_pair_test, l.pressure_cascade_verdict, l.emergency_release_test, l.notes
  from public.door_interlock_r3231 l
  where l.overall_verdict in ('critical_fail','major_nonconformity','pending_review','conditional_pass')
     or l.interlock_pair_test in ('single_door_fail','both_fail','override_stuck')
     or l.pressure_cascade_verdict = 'reversed_flow'
     or l.emergency_release_test = 'failed_to_release'
     or not l.access_card_log_working
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3231_high_risk_queue() from public, anon;
grant execute on function public.founder_r3231_high_risk_queue() to authenticated;
