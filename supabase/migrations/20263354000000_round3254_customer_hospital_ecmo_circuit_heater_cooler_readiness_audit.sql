-- Round 3254: Customer Hospital ECMO Circuit & Heater-Cooler Readiness Audit
-- ECMO readiness — component type × self-test × flow-probe cal × heater-cooler temp stability × water-circuit disinfection × battery backup × circuit prime × emergency drill × alarm test × CAPA

-- =============================================================================
-- TABLE 1: ecmo_readiness_r3254 — per-system ECMO readiness checks
-- =============================================================================
create table if not exists public.ecmo_readiness_r3254 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  system_code text not null,
  component_type text not null check (component_type in (
    'ecmo_console','centrifugal_pump','heater_cooler_unit','oxygenator_stock','backup_hand_crank'
  )),
  icu_unit text not null,
  check_date date not null,
  self_test_pass boolean not null,
  flow_probe_calibration_ok boolean,
  heater_cooler_temp_stability_c numeric(4,2),
  water_circuit_disinfection_current boolean,
  battery_backup_minutes int,
  circuit_primed_ready text not null check (circuit_primed_ready in (
    'ready','needs_priming','expired_prime','not_applicable'
  )),
  emergency_drill_done_this_quarter boolean not null,
  alarm_test text not null check (alarm_test in (
    'pass','fail','not_tested'
  )),
  readiness_verdict text not null check (readiness_verdict in (
    'mission_ready','conditional','not_ready','out_of_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ecmo_readiness_r3254 enable row level security;

create index if not exists idx_ecmo_readiness_r3254_org on public.ecmo_readiness_r3254(organization_id);
create index if not exists idx_ecmo_readiness_r3254_date on public.ecmo_readiness_r3254(check_date);
create index if not exists idx_ecmo_readiness_r3254_verdict on public.ecmo_readiness_r3254(readiness_verdict);

-- =============================================================================
-- TABLE 2: ecmo_readiness_capa_actions_r3254 — CAPA findings for not-ready systems
-- =============================================================================
create table if not exists public.ecmo_readiness_capa_actions_r3254 (
  id uuid primary key default gen_random_uuid(),
  readiness_check_id uuid not null references public.ecmo_readiness_r3254(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'self_test_failure','flow_probe_calibration','heater_cooler_temp_drift',
    'water_circuit_disinfection_lapse','battery_backup_degraded','circuit_prime_expired',
    'oxygenator_stock_below_par','alarm_test_failure','drill_noncompliance','hand_crank_missing'
  )),
  root_cause text not null check (root_cause in (
    'pump_head_bearing_wear','flow_probe_sensor_drift','heater_cooler_scale_buildup',
    'disinfection_schedule_missed','battery_end_of_life','prime_protocol_lapse',
    'alarm_speaker_fault','staffing_shortage_no_drill','spare_not_stocked',
    'procurement_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_pump_head','recalibrate_flow_probe','descale_heater_cooler','run_disinfection_cycle',
    'replace_battery_pack','re_prime_circuit','replace_alarm_module','schedule_emergency_drill',
    'stock_backup_hand_crank','expedite_oxygenator_purchase','schedule_oem_service','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ecmo_readiness_capa_actions_r3254 enable row level security;

create index if not exists idx_ecmo_capa_r3254_check on public.ecmo_readiness_capa_actions_r3254(readiness_check_id);
create index if not exists idx_ecmo_capa_r3254_status on public.ecmo_readiness_capa_actions_r3254(capa_status);

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

  -- 14 readiness check rows
  insert into public.ecmo_readiness_r3254 (
    organization_id, hospital_name, system_code, component_type, icu_unit,
    check_date, self_test_pass, flow_probe_calibration_ok,
    heater_cooler_temp_stability_c, water_circuit_disinfection_current,
    battery_backup_minutes, circuit_primed_ready, emergency_drill_done_this_quarter,
    alarm_test, readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.sys, q.comp, q.icu,
    q.cd::date, q.stp, q.fpc,
    q.hct, q.wcd,
    q.bbm, q.cpr, q.edq,
    q.alm, q.rv, q.nt
  from (values
    ('Apollo Chennai Greams Road','ECMO-APL-01','ecmo_console','CTVS ICU','2026-07-10',
     true,true,null,null,92,'ready',true,'pass','mission_ready','Cardiohelp console — full readiness pass'),
    ('Apollo Chennai Greams Road','HCU-APL-01','heater_cooler_unit','CTVS ICU','2026-07-10',
     true,null,0.30,true,45,'not_applicable',true,'pass','mission_ready','HCU disinfected 05 Jul — temp stable within 0.3C'),
    ('Apollo Chennai Greams Road','PMP-APL-02','centrifugal_pump','CTVS ICU','2026-07-10',
     true,false,null,null,88,'ready',true,'pass','conditional','Flow probe reading 8% low vs ultrasonic reference — recal booked'),
    ('Fortis Memorial Gurgaon','ECMO-FRT-01','ecmo_console','Cardiac ICU','2026-07-09',
     false,true,null,null,12,'needs_priming',false,'fail','not_ready','Self-test error E-42 and battery only 12 min — console pulled to biomed'),
    ('Fortis Memorial Gurgaon','HCU-FRT-01','heater_cooler_unit','Cardiac ICU','2026-07-09',
     true,null,1.80,false,40,'not_applicable',false,'pass','not_ready','Disinfection overdue 3 weeks — NTM/Legionella risk; temp drift 1.8C'),
    ('Manipal Old Airport Road Bengaluru','ECMO-MNP-01','ecmo_console','MICU','2026-07-08',
     true,true,null,null,95,'ready',true,'pass','mission_ready','Rotaflow console clean pass — drill logged 30 Jun'),
    ('Manipal Old Airport Road Bengaluru','CRK-MNP-01','backup_hand_crank','MICU','2026-07-08',
     true,null,null,null,null,'not_applicable',true,'not_tested','conditional','Hand crank present but mounting bracket missing — loose in drawer'),
    ('AIIMS New Delhi Ansari Nagar','ECMO-AIM-01','ecmo_console','CTVS ICU','2026-07-07',
     true,true,null,null,60,'expired_prime',true,'pass','conditional','Wet-primed circuit exceeded 30-day window — re-prime scheduled'),
    ('AIIMS New Delhi Ansari Nagar','OXY-AIM-01','oxygenator_stock','CTVS ICU','2026-07-07',
     true,null,null,null,null,'not_applicable',true,'not_tested','not_ready','Only 1 adult oxygenator in stock against par level of 3'),
    ('CMC Vellore','ECMO-CMC-01','ecmo_console','PICU','2026-07-06',
     true,true,null,null,90,'ready',true,'pass','mission_ready','Paediatric circuit ready — drill done 28 Jun with Dr Priya Varghese'),
    ('CMC Vellore','HCU-CMC-01','heater_cooler_unit','PICU','2026-07-06',
     false,null,2.60,true,35,'not_applicable',true,'fail','out_of_service','Compressor fault — temp swing 2.6C and alarm silent; unit tagged out'),
    ('KIMS Secunderabad','ECMO-KIM-01','ecmo_console','ECMO Unit','2026-07-05',
     true,true,null,null,25,'ready',false,'pass','conditional','Battery holds 25 min vs 60 min spec; quarterly drill overdue'),
    ('KIMS Secunderabad','PMP-KIM-02','centrifugal_pump','ECMO Unit','2026-07-05',
     true,true,null,null,85,'ready',true,'pass','mission_ready','Backup pump head verified by Suresh Nair with hand-crank drill'),
    ('Narayana Health City Bengaluru','ECMO-NRY-01','ecmo_console','CTVS ICU','2026-07-04',
     true,true,null,null,94,'ready',true,'pass','mission_ready','Full readiness pass post-AMC service by Ramesh Iyer')
  ) as q(hosp, sys, comp, icu, cd, stp, fpc, hct, wcd, bbm, cpr, edq, alm, rv, nt);

  -- CAPA seed — attach to specific readiness checks via system code
  insert into public.ecmo_readiness_capa_actions_r3254 (
    readiness_check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PMP-APL-02','flow_probe_calibration','flow_probe_sensor_drift','recalibrate_flow_probe','in_progress','internal_only','2026-07-15',null,8500.00,'Ultrasonic reference recalibration booked with OEM engineer'),
    ('ECMO-FRT-01','self_test_failure','battery_end_of_life','replace_battery_pack','escalated','patient_safety_alert','2026-07-12',null,145000.00,'E-42 board fault plus battery EOL — OEM engineer on site 11 Jul'),
    ('HCU-FRT-01','water_circuit_disinfection_lapse','disinfection_schedule_missed','run_disinfection_cycle','open','nabh_finding','2026-07-11',null,6000.00,'NTM swab sent to micro lab; disinfection cycle slotted overnight'),
    ('CRK-MNP-01','hand_crank_missing','spare_not_stocked','stock_backup_hand_crank','closed','internal_only','2026-07-10','2026-07-09',3500.00,'New bracket fitted — crank now mounted on console rail'),
    ('OXY-AIM-01','oxygenator_stock_below_par','procurement_delay','expedite_oxygenator_purchase','open','patient_safety_alert','2026-07-14',null,380000.00,'Two adult oxygenators on expedited purchase order'),
    ('HCU-CMC-01','alarm_test_failure','alarm_speaker_fault','replace_alarm_module','overdue','cdsco_notifiable','2026-07-01',null,54000.00,'Compressor plus alarm module replacement past target — vendor delay'),
    ('ECMO-AIM-01','circuit_prime_expired','prime_protocol_lapse','re_prime_circuit','verification_pending','iso_13485_deviation','2026-07-09',null,22000.00,'Fresh circuit primed — perfusionist sign-off pending')
  ) as q(sys, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ecmo_readiness_r3254 e
    on e.organization_id = v_org_id and e.system_code = q.sys;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3254_readiness_verdict_rollup()
returns table(readiness_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ecmo_readiness_r3254)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ecmo_readiness_r3254 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3254_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3254_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3254_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  mission_ready bigint,
  conditional bigint,
  not_ready bigint,
  out_of_service bigint,
  self_test_fail bigint,
  disinfection_lapse bigint,
  mission_ready_pct numeric
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
    count(*) filter (where l.self_test_pass = false)::bigint,
    count(*) filter (where l.water_circuit_disinfection_current = false)::bigint,
    round(100.0 * count(*) filter (where l.readiness_verdict = 'mission_ready')::numeric / nullif(count(*),0), 1)
  from public.ecmo_readiness_r3254 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3254_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3254_hospital_scorecard() to authenticated;

-- 3) Component type × ICU unit matrix
create or replace function public.founder_r3254_component_icu_matrix()
returns table(component_type text, icu_unit text, checks bigint, mission_ready bigint, avg_battery_backup_minutes numeric, avg_temp_stability_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.component_type, l.icu_unit, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    round(avg(l.battery_backup_minutes)::numeric, 0),
    round(avg(l.heater_cooler_temp_stability_c), 2)
  from public.ecmo_readiness_r3254 l
  group by l.component_type, l.icu_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3254_component_icu_matrix() from public, anon;
grant execute on function public.founder_r3254_component_icu_matrix() to authenticated;

-- 4) Daily readiness trend
create or replace function public.founder_r3254_daily_readiness_trend()
returns table(check_date date, checks bigint, mission_ready bigint, not_ready bigint, self_test_fail bigint, alarm_fail bigint)
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
    count(*) filter (where l.readiness_verdict in ('not_ready','out_of_service'))::bigint,
    count(*) filter (where l.self_test_pass = false)::bigint,
    count(*) filter (where l.alarm_test = 'fail')::bigint
  from public.ecmo_readiness_r3254 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3254_daily_readiness_trend() from public, anon;
grant execute on function public.founder_r3254_daily_readiness_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3254_capa_status_board()
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
  from public.ecmo_readiness_capa_actions_r3254 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3254_capa_status_board() from public, anon;
grant execute on function public.founder_r3254_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3254_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ecmo_readiness_capa_actions_r3254)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ecmo_readiness_capa_actions_r3254 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3254_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3254_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3254_regulatory_impact_digest()
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
  from public.ecmo_readiness_capa_actions_r3254 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3254_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3254_regulatory_impact_digest() to authenticated;

-- 8) High-risk readiness queue (top individual concerns)
create or replace function public.founder_r3254_high_risk_queue()
returns table(
  hospital_name text,
  system_code text,
  component_type text,
  icu_unit text,
  check_date date,
  readiness_verdict text,
  circuit_primed_ready text,
  alarm_test text,
  battery_backup_minutes int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.system_code, l.component_type, l.icu_unit, l.check_date,
    l.readiness_verdict, l.circuit_primed_ready, l.alarm_test,
    l.battery_backup_minutes, l.notes
  from public.ecmo_readiness_r3254 l
  where l.readiness_verdict in ('conditional','not_ready','out_of_service')
     or l.self_test_pass = false
     or l.flow_probe_calibration_ok = false
     or l.water_circuit_disinfection_current = false
     or l.alarm_test = 'fail'
     or l.circuit_primed_ready in ('needs_priming','expired_prime')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3254_high_risk_queue() from public, anon;
grant execute on function public.founder_r3254_high_risk_queue() to authenticated;
