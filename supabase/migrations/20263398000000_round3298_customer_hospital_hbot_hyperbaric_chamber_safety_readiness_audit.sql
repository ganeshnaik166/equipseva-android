-- Round 3298: Customer Hospital HBOT Hyperbaric-Chamber Safety & Readiness Audit
-- Fire-risk-critical (pressurized O2): chamber type × pressure-test × O2-control × fire-suppression deluge ×
-- grounding/antistatic × prohibited-items screening × comms × decompression-drill × acrylic-hull × ventilation air-break × gauge-cal × readiness verdict × CAPA

-- =============================================================================
-- TABLE 1: hbot_chamber_r3298 — per-chamber safety & readiness checks
-- =============================================================================
create table if not exists public.hbot_chamber_r3298 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  chamber_code text not null,
  chamber_type text not null check (chamber_type in (
    'monoplace','multiplace','topical_o2'
  )),
  department text not null,
  check_date date not null,
  pressure_test_ok boolean,
  o2_concentration_control_ok boolean,
  fire_suppression_ready boolean,
  grounding_antistatic_ok boolean,
  prohibited_items_screening_ok boolean,
  communication_system_ok boolean,
  emergency_decompression_drill_current boolean,
  acrylic_hull_inspection text not null check (acrylic_hull_inspection in (
    'pass','crazing','scratches','replace_due','not_applicable'
  )),
  ventilation_air_break_ok boolean,
  gauge_calibration_current boolean,
  readiness_verdict text not null check (readiness_verdict in (
    'mission_ready','conditional','not_ready','out_of_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hbot_chamber_r3298 enable row level security;

create index if not exists idx_hbot_chamber_r3298_org on public.hbot_chamber_r3298(organization_id);
create index if not exists idx_hbot_chamber_r3298_date on public.hbot_chamber_r3298(check_date);
create index if not exists idx_hbot_chamber_r3298_verdict on public.hbot_chamber_r3298(readiness_verdict);

-- =============================================================================
-- TABLE 2: hbot_chamber_capa_actions_r3298 — CAPA findings for not-ready chambers
-- =============================================================================
create table if not exists public.hbot_chamber_capa_actions_r3298 (
  id uuid primary key default gen_random_uuid(),
  check_log_id uuid not null references public.hbot_chamber_r3298(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'fire_suppression_gap','pressure_test_failure','o2_control_failure','grounding_antistatic_gap',
    'prohibited_items_screening_gap','communication_failure','decompression_drill_lapsed',
    'acrylic_hull_defect','ventilation_air_break_gap','gauge_calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'deluge_valve_fault','o2_analyzer_drift','grounding_strap_damaged','staff_screening_lapse',
    'intercom_hardware_failure','drill_schedule_backlog','acrylic_crazing_uv_aging','ventilation_valve_stuck',
    'gauge_out_of_calibration','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'service_deluge_valve','recalibrate_o2_analyzer','replace_grounding_strap','retrain_screening_staff',
    'repair_intercom','schedule_decompression_drill','replace_acrylic_hull','service_ventilation_valve',
    'recalibrate_gauges','remove_from_service','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nfpa_99_finding','nabh_finding','peso_notifiable','none','internal_only','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.hbot_chamber_capa_actions_r3298 enable row level security;

create index if not exists idx_hbot_capa_r3298_log on public.hbot_chamber_capa_actions_r3298(check_log_id);
create index if not exists idx_hbot_capa_r3298_status on public.hbot_chamber_capa_actions_r3298(capa_status);

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

  -- 14 chamber readiness rows
  insert into public.hbot_chamber_r3298 (
    organization_id, hospital_name, chamber_code, chamber_type, department, check_date,
    pressure_test_ok, o2_concentration_control_ok, fire_suppression_ready, grounding_antistatic_ok,
    prohibited_items_screening_ok, communication_system_ok, emergency_decompression_drill_current,
    acrylic_hull_inspection, ventilation_air_break_ok, gauge_calibration_current,
    readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ctype, q.dept, q.cdt::date,
    q.pt, q.o2, q.fire, q.gnd,
    q.screen, q.comm, q.decomp,
    q.hull, q.vent, q.gauge,
    q.verdict, q.nt
  from (values
    ('Apollo Chennai','HBOT-1','multiplace','Hyperbaric Medicine','2026-07-02',
     true,true,true,true, true,true,true, 'pass',true,true, 'mission_ready','Monthly readiness check — all systems nominal'),
    ('Apollo Chennai','HBOT-2','monoplace','Wound Care','2026-07-02',
     true,true,true,true, true,true,false, 'pass',true,true, 'conditional','Decompression drill lapsed 40 days — drill rebooked'),
    ('Fortis Gurgaon','HBOT-1','multiplace','Hyperbaric Medicine','2026-07-01',
     true,true,false,true, true,true,true, 'pass',true,true, 'not_ready','Deluge fire-suppression failed activation test — chamber held'),
    ('Fortis Gurgaon','HBOT-2','topical_o2','Wound Care','2026-07-01',
     true,false,true,true, true,true,true, 'not_applicable',true,false, 'conditional','O2 analyzer drift and gauges overdue — recal scheduled'),
    ('Manipal Bengaluru','HBOT-1','monoplace','Hyperbaric Medicine','2026-06-30',
     true,true,true,false, true,true,true, 'pass',true,true, 'not_ready','Antistatic grounding strap open circuit — spark risk, pulled'),
    ('Manipal Bengaluru','HBOT-2','multiplace','Critical Care','2026-06-30',
     true,true,true,true, false,true,true, 'scratches',true,true, 'conditional','Prohibited-items screening checklist unsigned for 3 dives'),
    ('AIIMS Delhi','HBOT-1','multiplace','Hyperbaric Medicine','2026-06-29',
     true,true,true,true, true,false,true, 'pass',true,true, 'conditional','Intercom to attendant intermittent — hardware swap due'),
    ('AIIMS Delhi','HBOT-2','monoplace','Wound Care','2026-06-29',
     true,true,true,true, true,true,true, 'pass',true,true, 'mission_ready','Quarterly PESO vessel inspection clean'),
    ('CMC Vellore','HBOT-1','multiplace','Hyperbaric Medicine','2026-06-28',
     false,true,true,true, true,true,true, 'crazing',true,true, 'not_ready','Pressure-hold dropped 0.3 bar over 10 min and hull crazing'),
    ('KIMS Hyderabad','HBOT-1','monoplace','Hyperbaric Medicine','2026-06-28',
     true,true,true,true, true,true,true, 'pass',false,true, 'conditional','Ventilation air-break valve slow to open — service booked'),
    ('KIMS Hyderabad','HBOT-2','topical_o2','Wound Care','2026-06-27',
     true,true,true,true, true,true,true, 'not_applicable',true,true, 'mission_ready','Topical O2 unit — readiness verified'),
    ('Amrita Kochi','HBOT-1','multiplace','Hyperbaric Medicine','2026-06-27',
     false,false,false,true, true,false,false, 'replace_due',false,false, 'out_of_service','Decommissioned pending major overhaul — multiple failures'),
    ('Narayana Health Bengaluru','HBOT-1','monoplace','Wound Care','2026-06-26',
     true,true,true,true, true,true,true, 'pass',true,true, 'mission_ready','New chamber commissioning readiness pass'),
    ('Medanta Gurgaon','HBOT-1','multiplace','Hyperbaric Medicine','2026-06-26',
     true,true,true,true, false,true,false, 'scratches',true,false, 'not_ready','Screening lapse plus gauges and drill overdue — held for CAPA')
  ) as q(hosp, code, ctype, dept, cdt, pt, o2, fire, gnd, screen, comm, decomp, hull, vent, gauge, verdict, nt);

  -- CAPA seed — attach to specific chambers via hospital + chamber code
  insert into public.hbot_chamber_capa_actions_r3298 (
    check_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Fortis Gurgaon','HBOT-1','fire_suppression_gap','deluge_valve_fault','service_deluge_valve','escalated','nfpa_99_finding','2026-07-05',null,145000.00,'Deluge valve failed to trigger at test pressure — OEM escalation'),
    ('Manipal Bengaluru','HBOT-1','grounding_antistatic_gap','grounding_strap_damaged','replace_grounding_strap','in_progress','patient_safety_alert','2026-07-04',null,22000.00,'Grounding strap replaced — awaiting continuity re-test'),
    ('CMC Vellore','HBOT-1','pressure_test_failure','acrylic_crazing_uv_aging','replace_acrylic_hull','open','peso_notifiable','2026-07-12',null,860000.00,'Acrylic hull crazing with pressure leak — full hull replacement quoted'),
    ('Fortis Gurgaon','HBOT-2','o2_control_failure','o2_analyzer_drift','recalibrate_o2_analyzer','closed','nabh_finding','2026-07-03','2026-07-02',15000.00,'O2 analyzer recalibrated and gauges certified'),
    ('Amrita Kochi','HBOT-1','gauge_calibration_overdue','gauge_out_of_calibration','remove_from_service','verification_pending','peso_notifiable','2026-07-08',null,0.00,'Chamber out of service — overhaul scope under review'),
    ('AIIMS Delhi','HBOT-1','communication_failure','intercom_hardware_failure','repair_intercom','open','internal_only','2026-07-06',null,9500.00,'Intercom module on order from vendor'),
    ('Medanta Gurgaon','HBOT-1','decompression_drill_lapsed','drill_schedule_backlog','schedule_decompression_drill','overdue','patient_safety_alert','2026-06-30',null,0.00,'Emergency decompression drill overdue — past target date')
  ) as q(hosp, code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.hbot_chamber_r3298 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp and e.chamber_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3298_readiness_verdict_rollup()
returns table(readiness_verdict text, chambers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hbot_chamber_r3298)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.hbot_chamber_r3298 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3298_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3298_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3298_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  mission_ready bigint,
  conditional bigint,
  not_ready bigint,
  out_of_service bigint,
  fire_suppression_gaps bigint,
  pressure_test_fail bigint,
  gauge_cal_overdue bigint,
  ready_pct numeric
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
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'conditional')::bigint,
    count(*) filter (where l.readiness_verdict = 'not_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.fire_suppression_ready is not true)::bigint,
    count(*) filter (where l.pressure_test_ok is not true)::bigint,
    count(*) filter (where l.gauge_calibration_current is not true)::bigint,
    round(100.0 * count(*) filter (where l.readiness_verdict = 'mission_ready')::numeric / nullif(count(*),0), 1)
  from public.hbot_chamber_r3298 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3298_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3298_hospital_scorecard() to authenticated;

-- 3) Chamber type × department matrix
create or replace function public.founder_r3298_chamber_type_department_matrix()
returns table(chamber_type text, department text, checks bigint, mission_ready bigint, not_ready bigint, ready_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.chamber_type, l.department, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    count(*) filter (where l.readiness_verdict in ('not_ready','out_of_service'))::bigint,
    round(100.0 * count(*) filter (where l.readiness_verdict = 'mission_ready')::numeric / nullif(count(*),0), 1)
  from public.hbot_chamber_r3298 l
  group by l.chamber_type, l.department
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3298_chamber_type_department_matrix() from public, anon;
grant execute on function public.founder_r3298_chamber_type_department_matrix() to authenticated;

-- 4) Daily readiness trend
create or replace function public.founder_r3298_daily_readiness_trend()
returns table(check_date date, checks bigint, mission_ready bigint, not_ready bigint, out_of_service bigint, fire_suppression_gaps bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'not_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.fire_suppression_ready is not true)::bigint
  from public.hbot_chamber_r3298 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3298_daily_readiness_trend() from public, anon;
grant execute on function public.founder_r3298_daily_readiness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3298_capa_status_board()
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
  from public.hbot_chamber_capa_actions_r3298 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3298_capa_status_board() from public, anon;
grant execute on function public.founder_r3298_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3298_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.hbot_chamber_capa_actions_r3298)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.hbot_chamber_capa_actions_r3298 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3298_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3298_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3298_regulatory_impact_digest()
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
  from public.hbot_chamber_capa_actions_r3298 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3298_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3298_regulatory_impact_digest() to authenticated;

-- 8) High-risk readiness queue (individual chambers needing attention)
create or replace function public.founder_r3298_high_risk_queue()
returns table(
  hospital_name text,
  chamber_code text,
  chamber_type text,
  department text,
  check_date date,
  readiness_verdict text,
  fire_suppression_ready boolean,
  pressure_test_ok boolean,
  o2_concentration_control_ok boolean,
  acrylic_hull_inspection text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.chamber_code, l.chamber_type, l.department, l.check_date,
    l.readiness_verdict, l.fire_suppression_ready, l.pressure_test_ok, l.o2_concentration_control_ok,
    l.acrylic_hull_inspection, l.notes
  from public.hbot_chamber_r3298 l
  where l.readiness_verdict in ('conditional','not_ready','out_of_service')
     or l.fire_suppression_ready is not true
     or l.pressure_test_ok is not true
     or l.o2_concentration_control_ok is not true
     or l.grounding_antistatic_ok is not true
     or l.emergency_decompression_drill_current is not true
     or l.gauge_calibration_current is not true
     or l.acrylic_hull_inspection in ('crazing','scratches','replace_due')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3298_high_risk_queue() from public, anon;
grant execute on function public.founder_r3298_high_risk_queue() to authenticated;
