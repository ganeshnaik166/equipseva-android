-- Round 3290: Customer Hospital OT Surgical Scrub-Station Water-Purity QC Audit
-- Scrub-station QA — tap-actuation type × filtration/water-purity × timer/dispenser × drainage/backsplash containment × verdict × CAPA

-- =============================================================================
-- TABLE 1: ot_scrub_station_r3290 — per-scrub-station QC checks
-- =============================================================================
create table if not exists public.ot_scrub_station_r3290 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  station_code text not null,
  ot_number text not null,
  check_date date not null,
  tap_actuation_type text not null check (tap_actuation_type in (
    'sensor','knee_lever','elbow_lever','foot_pedal'
  )),
  tap_function_ok boolean not null,
  water_temp_stable boolean not null,
  bacterial_filter_status text not null check (bacterial_filter_status in (
    'fresh','due_soon','overdue','missing'
  )),
  water_sample_result text not null check (water_sample_result in (
    'pass','borderline','fail'
  )),
  scrub_timer_ok text not null check (scrub_timer_ok in (
    'ok','faulty','not_present'
  )),
  antiseptic_dispenser_ok boolean not null,
  drainage_hygiene_ok boolean not null,
  backsplash_containment_ok boolean not null,
  last_water_test_date date,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','station_closed'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_scrub_station_r3290 enable row level security;

create index if not exists idx_ot_scrub_station_r3290_org on public.ot_scrub_station_r3290(organization_id);
create index if not exists idx_ot_scrub_station_r3290_date on public.ot_scrub_station_r3290(check_date);
create index if not exists idx_ot_scrub_station_r3290_verdict on public.ot_scrub_station_r3290(qc_verdict);

-- =============================================================================
-- TABLE 2: ot_scrub_station_capa_actions_r3290 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ot_scrub_station_capa_actions_r3290 (
  id uuid primary key default gen_random_uuid(),
  qc_log_id uuid not null references public.ot_scrub_station_r3290(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'water_purity_failure','bacterial_filter_overdue','tap_malfunction','timer_fault',
    'dispenser_fault','drainage_hygiene_issue','backsplash_containment_breach',
    'temperature_instability','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'filter_past_service_life','biofilm_in_pipework','sensor_valve_failure','solenoid_valve_stuck',
    'timer_pcb_fault','dispenser_pump_failure','drain_trap_blocked','backsplash_seal_degraded',
    'mixing_valve_fault','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_bacterial_filter','chlorine_shock_disinfection','replace_sensor_valve','replace_solenoid_valve',
    'replace_timer_module','replace_dispenser_pump','clear_drain_trap','reseal_backsplash',
    'recalibrate_mixing_valve','close_station_pending_repair','retrain_ot_staff','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation',
    'patient_safety_alert','infection_control_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ot_scrub_station_capa_actions_r3290 enable row level security;

create index if not exists idx_ot_scrub_capa_r3290_log on public.ot_scrub_station_capa_actions_r3290(qc_log_id);
create index if not exists idx_ot_scrub_capa_r3290_status on public.ot_scrub_station_capa_actions_r3290(capa_status);

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

  -- 14 scrub-station QC rows
  insert into public.ot_scrub_station_r3290 (
    organization_id, hospital_name, station_code, ot_number, check_date,
    tap_actuation_type, tap_function_ok, water_temp_stable, bacterial_filter_status,
    water_sample_result, scrub_timer_ok, antiseptic_dispenser_ok, drainage_hygiene_ok,
    backsplash_containment_ok, last_water_test_date, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.stn, q.otn, q.cd::date,
    q.tat, q.tfok, q.wts, q.bfs,
    q.wsr, q.sto, q.adok, q.dhok,
    q.bcok, q.lwt::date, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','SCR-APL-01','OT-1','2026-07-02','sensor',true,true,'fresh','pass','ok',true,true,true,'2026-06-15','pass','Routine QC — all parameters within limits'),
    ('Apollo Chennai Greams Road','SCR-APL-02','OT-2','2026-07-02','sensor',true,true,'due_soon','pass','ok',true,true,true,'2026-06-15','conditional_pass','Bacterial filter due within 2 weeks — replacement scheduled'),
    ('Fortis Gurgaon','SCR-FRT-01','OT-1','2026-07-01','knee_lever',true,true,'overdue','borderline','ok',true,true,true,'2026-05-20','conditional_pass','Filter overdue and TVC borderline at 90 CFU/mL — filter change booked'),
    ('Fortis Gurgaon','SCR-FRT-02','OT-3','2026-07-01','elbow_lever',false,true,'fresh','pass','faulty',true,true,true,'2026-06-18','conditional_pass','Tap intermittent and scrub timer faulty — maintenance raised'),
    ('Manipal Bengaluru Old Airport Road','SCR-MNP-01','OT-1','2026-06-30','sensor',true,false,'fresh','pass','ok',true,true,true,'2026-06-20','conditional_pass','Water temp unstable, swings 28-45C — mixing valve check due'),
    ('Manipal Bengaluru Old Airport Road','SCR-MNP-02','OT-2','2026-06-30','foot_pedal',true,true,'overdue','fail','ok',true,true,true,'2026-05-05','fail','Pseudomonas detected in water sample and filter overdue — station closed'),
    ('AIIMS Delhi Ansari Nagar','SCR-AIM-01','OT-4','2026-06-29','elbow_lever',true,true,'fresh','pass','ok',false,true,true,'2026-06-22','conditional_pass','Antiseptic dispenser empty/not dispensing — pump serviced'),
    ('AIIMS Delhi Ansari Nagar','SCR-AIM-02','OT-5','2026-06-29','sensor',true,true,'fresh','pass','ok',true,true,true,'2026-06-22','pass','Annual QC clean pass'),
    ('CMC Vellore','SCR-CMC-01','OT-1','2026-06-28','knee_lever',true,true,'due_soon','borderline','ok',true,false,true,'2026-06-01','conditional_pass','Drainage hygiene poor — standing water at trap, TVC borderline'),
    ('CMC Vellore','SCR-CMC-02','OT-2','2026-06-28','sensor',false,true,'missing','fail','not_present',true,true,false,'2026-04-28','station_closed','No bacterial filter fitted, tap failed, backsplash breach — station closed pending refit'),
    ('KIMS Hyderabad','SCR-KIM-01','OT-1','2026-06-27','sensor',true,true,'fresh','pass','ok',true,true,true,'2026-06-19','pass','Post-refurbishment verification pass'),
    ('KIMS Hyderabad','SCR-KIM-02','OT-2','2026-06-27','knee_lever',true,true,'overdue','fail','ok',true,true,true,'2026-04-30','fail','High TVC 480 CFU/mL and filter overdue — remedial disinfection ordered'),
    ('Care Hospitals Banjara Hills','SCR-CAR-01','OT-3','2026-06-26','foot_pedal',true,false,'due_soon','pass','faulty',true,true,true,'2026-06-10','conditional_pass','Timer freezes at 90s and temp drifts — dual maintenance items'),
    ('Yashoda Somajiguda Hyderabad','SCR-YSH-01','OT-1','2026-06-26','sensor',true,true,'fresh','pass','ok',true,true,true,'2026-06-21','pass','Routine QC nominal')
  ) as q(hosp, stn, otn, cd, tat, tfok, wts, bfs, wsr, sto, adok, dhok, bcok, lwt, qv, nt);

  -- CAPA seed — attach to specific stations via station_code
  insert into public.ot_scrub_station_capa_actions_r3290 (
    qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('SCR-FRT-01','bacterial_filter_overdue','filter_past_service_life','replace_bacterial_filter','in_progress','infection_control_alert','2026-07-06',null,8500.00,'Filter overdue 6 weeks — replacement in progress'),
    ('SCR-MNP-02','water_purity_failure','biofilm_in_pipework','chlorine_shock_disinfection','escalated','patient_safety_alert','2026-07-05',null,55000.00,'Pseudomonas positive — station closed, shock disinfection escalated'),
    ('SCR-FRT-02','timer_fault','timer_pcb_fault','replace_timer_module','open','internal_only','2026-07-08',null,14000.00,'Timer PCB fault — module on order'),
    ('SCR-CMC-02','tap_malfunction','sensor_valve_failure','replace_sensor_valve','open','infection_control_alert','2026-07-09',null,16500.00,'Sensor tap failed and no filter fitted — station closed, refit ordered'),
    ('SCR-KIM-02','water_purity_failure','biofilm_in_pipework','chlorine_shock_disinfection','verification_pending','cdsco_notifiable','2026-07-04',null,48000.00,'TVC 480 CFU/mL — disinfection done, awaiting re-sample'),
    ('SCR-AIM-01','dispenser_fault','dispenser_pump_failure','replace_dispenser_pump','closed','internal_only','2026-07-01','2026-06-30',6500.00,'Dispenser pump replaced, dispensing verified'),
    ('SCR-CMC-01','drainage_hygiene_issue','drain_trap_blocked','clear_drain_trap','overdue','nabh_finding','2026-06-25',null,4000.00,'Drain trap blockage past target date — housekeeping escalation')
  ) as q(stn, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ot_scrub_station_r3290 e
    on e.organization_id = v_org_id and e.station_code = q.stn;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3290_qc_verdict_rollup()
returns table(qc_verdict text, stations bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_scrub_station_r3290)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ot_scrub_station_r3290 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3290_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3290_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3290_hospital_scorecard()
returns table(
  hospital_name text,
  total_stations bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  water_sample_fail bigint,
  filter_overdue bigint,
  timer_fault bigint,
  pass_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','station_closed'))::bigint,
    count(*) filter (where l.water_sample_result in ('borderline','fail'))::bigint,
    count(*) filter (where l.bacterial_filter_status in ('overdue','missing'))::bigint,
    count(*) filter (where l.scrub_timer_ok in ('faulty','not_present'))::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.ot_scrub_station_r3290 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3290_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3290_hospital_scorecard() to authenticated;

-- 3) Tap-actuation type × bacterial-filter status matrix
create or replace function public.founder_r3290_tap_filter_matrix()
returns table(tap_actuation_type text, bacterial_filter_status text, stations bigint, passed bigint, failed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.tap_actuation_type, l.bacterial_filter_status, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','station_closed'))::bigint
  from public.ot_scrub_station_r3290 l
  group by l.tap_actuation_type, l.bacterial_filter_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3290_tap_filter_matrix() from public, anon;
grant execute on function public.founder_r3290_tap_filter_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3290_daily_qc_trend()
returns table(check_date date, stations bigint, passed bigint, failed bigint, water_sample_fail bigint, filter_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','station_closed'))::bigint,
    count(*) filter (where l.water_sample_result in ('borderline','fail'))::bigint,
    count(*) filter (where l.bacterial_filter_status in ('overdue','missing'))::bigint
  from public.ot_scrub_station_r3290 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3290_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3290_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3290_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.ot_scrub_station_capa_actions_r3290 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3290_capa_status_board() from public, anon;
grant execute on function public.founder_r3290_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3290_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ot_scrub_station_capa_actions_r3290)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ot_scrub_station_capa_actions_r3290 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3290_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3290_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3290_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.ot_scrub_station_capa_actions_r3290 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3290_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3290_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3290_high_risk_queue()
returns table(
  hospital_name text,
  station_code text,
  ot_number text,
  check_date date,
  qc_verdict text,
  tap_actuation_type text,
  bacterial_filter_status text,
  water_sample_result text,
  scrub_timer_ok text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.station_code, l.ot_number, l.check_date,
    l.qc_verdict, l.tap_actuation_type, l.bacterial_filter_status, l.water_sample_result,
    l.scrub_timer_ok, l.notes
  from public.ot_scrub_station_r3290 l
  where l.qc_verdict in ('conditional_pass','fail','station_closed')
     or l.water_sample_result in ('borderline','fail')
     or l.bacterial_filter_status in ('overdue','missing')
     or l.scrub_timer_ok in ('faulty','not_present')
     or l.tap_function_ok = false
     or l.water_temp_stable = false
     or l.antiseptic_dispenser_ok = false
     or l.drainage_hygiene_ok = false
     or l.backsplash_containment_ok = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3290_high_risk_queue() from public, anon;
grant execute on function public.founder_r3290_high_risk_queue() to authenticated;
