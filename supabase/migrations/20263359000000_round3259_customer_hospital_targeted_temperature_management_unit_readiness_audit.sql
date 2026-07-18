-- Round 3259: Customer Hospital Targeted-Temperature-Management (TTM) Unit Readiness Audit
-- ICU TTM readiness — system type × setpoint accuracy × water level × pad/blanket stock × tubing × temp probe × alarm test × disinfection × drill × CAPA

-- =============================================================================
-- TABLE 1: ttm_readiness_r3259 — per-unit TTM readiness checks
-- =============================================================================
create table if not exists public.ttm_readiness_r3259 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  unit_code text not null,
  system_type text not null check (system_type in (
    'water_blanket_unit','gel_pad_surface','intravascular_console','air_cooling_wrap'
  )),
  icu_unit text not null,
  check_date date not null,
  setpoint_accuracy_error_c numeric(4,2),
  water_level_ok boolean not null,
  pad_blanket_stock text not null check (pad_blanket_stock in (
    'adequate','low','expired_stock','none'
  )),
  tubing_condition text not null check (tubing_condition in (
    'good','kinked','cracked','leak_detected'
  )),
  patient_temp_probe_ok text not null check (patient_temp_probe_ok in (
    'pass','drift','fail'
  )),
  alarm_function_test text not null check (alarm_function_test in (
    'pass','fail','not_tested'
  )),
  disinfection_cycle_current boolean not null,
  response_drill_this_quarter boolean not null,
  readiness_verdict text not null check (readiness_verdict in (
    'mission_ready','conditional','not_ready','out_of_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.ttm_readiness_r3259 enable row level security;

create index if not exists idx_ttm_readiness_r3259_org on public.ttm_readiness_r3259(organization_id);
create index if not exists idx_ttm_readiness_r3259_date on public.ttm_readiness_r3259(check_date);
create index if not exists idx_ttm_readiness_r3259_verdict on public.ttm_readiness_r3259(readiness_verdict);

-- =============================================================================
-- TABLE 2: ttm_readiness_capa_actions_r3259 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.ttm_readiness_capa_actions_r3259 (
  id uuid primary key default gen_random_uuid(),
  check_id uuid not null references public.ttm_readiness_r3259(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'setpoint_drift','water_system_fault','consumable_stockout','tubing_failure',
    'temp_probe_fault','alarm_failure','disinfection_lapse','drill_noncompliance','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'chiller_compressor_wear','water_pump_degraded','procurement_delay','tubing_aging',
    'probe_cable_damaged','alarm_board_fault','staff_shortage','training_gap',
    'pending_investigation','service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_setpoint_controller','replace_chiller_compressor','service_water_pump','expedite_consumable_order',
    'replace_tubing_set','replace_temp_probe','repair_alarm_board','run_disinfection_cycle',
    'schedule_mock_drill','remove_from_service','schedule_oem_service','none_required'
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

alter table public.ttm_readiness_capa_actions_r3259 enable row level security;

create index if not exists idx_ttm_capa_r3259_check on public.ttm_readiness_capa_actions_r3259(check_id);
create index if not exists idx_ttm_capa_r3259_status on public.ttm_readiness_capa_actions_r3259(capa_status);

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
  insert into public.ttm_readiness_r3259 (
    organization_id, hospital_name, unit_code, system_type, icu_unit,
    check_date, setpoint_accuracy_error_c, water_level_ok, pad_blanket_stock,
    tubing_condition, patient_temp_probe_ok, alarm_function_test,
    disinfection_cycle_current, response_drill_this_quarter,
    readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.st, q.icu,
    q.cd::date, q.err, q.wl, q.stock,
    q.tub, q.probe, q.alarm,
    q.dis, q.drill,
    q.rv, q.nt
  from (values
    ('Apollo Chennai Greams Road','TTM-APL-01','water_blanket_unit','MICU','2026-07-03',
     0.12,true,'adequate','good','pass','pass',true,true,'mission_ready','Quarterly readiness check — all systems nominal'),
    ('Apollo Chennai Greams Road','TTM-APL-02','gel_pad_surface','CTICU','2026-07-03',
     0.35,true,'low','good','pass','pass',true,false,'conditional','Gel pad stock down to 2 sets and Q3 response drill pending'),
    ('Fortis Gurgaon','TTM-FRT-11','intravascular_console','Cardiac ICU','2026-07-02',
     0.08,true,'adequate','good','pass','pass',true,true,'mission_ready','Post-arrest cooling console verified on mock catheter loop'),
    ('Fortis Gurgaon','TTM-FRT-12','water_blanket_unit','Neuro ICU','2026-07-02',
     0.95,false,'adequate','leak_detected','pass','pass',false,true,'not_ready','Reservoir low with leak at manifold — pulled for service'),
    ('Manipal Bengaluru Old Airport Road','TTM-MNP-21','gel_pad_surface','MICU','2026-07-01',
     0.22,true,'adequate','good','drift','pass',true,true,'conditional','Core probe drifting 0.4C vs reference — recalibration booked'),
    ('Manipal Bengaluru Old Airport Road','TTM-MNP-22','water_blanket_unit','SICU','2026-07-01',
     0.18,true,'adequate','kinked','pass','pass',true,true,'conditional','Return line kink at trolley hinge — routing fix scheduled'),
    ('AIIMS New Delhi Ansari Nagar','TTM-AIM-31','intravascular_console','Trauma ICU','2026-06-30',
     0.10,true,'adequate','good','pass','fail',true,true,'not_ready','High-temp alarm silent at 38.5C challenge — alarm board suspect'),
    ('AIIMS New Delhi Ansari Nagar','TTM-AIM-32','water_blanket_unit','MICU','2026-06-30',
     0.15,true,'adequate','good','pass','pass',true,true,'mission_ready','Annual readiness check clean pass'),
    ('CMC Vellore','TTM-CMC-41','gel_pad_surface','Neuro ICU','2026-06-29',
     0.28,true,'expired_stock','good','pass','pass',true,false,'not_ready','All gel pads past expiry — replacement stock order raised'),
    ('CMC Vellore','TTM-CMC-42','water_blanket_unit','PICU','2026-06-29',
     0.20,true,'adequate','good','pass','pass',false,true,'conditional','Disinfection cycle overdue by 12 days — slot booked'),
    ('KIMS Secunderabad Hyderabad','TTM-KIM-51','air_cooling_wrap','MICU','2026-06-28',
     0.45,true,'adequate','good','pass','pass',true,true,'mission_ready','Wrap blower and temperature control within limits'),
    ('KIMS Secunderabad Hyderabad','TTM-KIM-52','intravascular_console','Cardiac ICU','2026-06-28',
     1.60,true,'adequate','cracked','fail','pass',true,true,'out_of_service','Setpoint 1.6C off and probe channel dead — OEM call logged'),
    ('Max Saket New Delhi','TTM-MAX-61','water_blanket_unit','CTICU','2026-06-27',
     0.14,true,'adequate','good','pass','pass',true,true,'mission_ready','Ready — hoses and clamps replaced during AMC visit'),
    ('Narayana Health City Bengaluru','TTM-NAR-71','gel_pad_surface','Cardiac ICU','2026-06-27',
     null,true,'low','good','pass','not_tested',true,false,'conditional','Check cut short by case load — alarm test and drill pending')
  ) as q(hosp, code, st, icu, cd, err, wl, stock, tub, probe, alarm, dis, drill, rv, nt);

  -- CAPA seed — attach to specific checks via unit code
  insert into public.ttm_readiness_capa_actions_r3259 (
    check_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('TTM-FRT-12','tubing_failure','tubing_aging','replace_tubing_set','in_progress','internal_only','2026-07-08',null,14500.00,'Manifold gasket and return hose replacement in progress'),
    ('TTM-AIM-31','alarm_failure','alarm_board_fault','repair_alarm_board','escalated','patient_safety_alert','2026-07-05',null,38000.00,'Silent high-temp alarm — escalated to OEM, unit quarantined'),
    ('TTM-CMC-41','consumable_stockout','procurement_delay','expedite_consumable_order','open','nabh_finding','2026-07-10',null,52000.00,'Emergency PO for 20 gel pad sets raised with vendor'),
    ('TTM-KIM-52','setpoint_drift','chiller_compressor_wear','schedule_oem_service','escalated','cdsco_notifiable','2026-07-12',null,145000.00,'Compressor and probe channel repair quote awaited from OEM'),
    ('TTM-CMC-42','disinfection_lapse','staff_shortage','run_disinfection_cycle','closed','internal_only','2026-07-01','2026-06-30',0.00,'Cycle run and log updated — roster fixed for monthly cadence'),
    ('TTM-MNP-21','temp_probe_fault','probe_cable_damaged','replace_temp_probe','verification_pending','iso_13485_deviation','2026-07-06',null,6800.00,'New probe fitted — verification against reference thermometer due'),
    ('TTM-APL-02','drill_noncompliance','training_gap','schedule_mock_drill','overdue','internal_only','2026-06-25',null,0.00,'Q3 hypothermia response drill past target date')
  ) as q(code, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.ttm_readiness_r3259 e
    on e.organization_id = v_org_id and e.unit_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3259_readiness_verdict_rollup()
returns table(readiness_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ttm_readiness_r3259)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.ttm_readiness_r3259 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3259_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3259_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3259_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  mission_ready bigint,
  conditional bigint,
  not_ready bigint,
  probe_issues bigint,
  alarm_fail bigint,
  disinfection_lapse bigint,
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
    count(*) filter (where l.readiness_verdict in ('not_ready','out_of_service'))::bigint,
    count(*) filter (where l.patient_temp_probe_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.alarm_function_test = 'fail')::bigint,
    count(*) filter (where l.disinfection_cycle_current = false)::bigint,
    round(100.0 * count(*) filter (where l.readiness_verdict = 'mission_ready')::numeric / nullif(count(*),0), 1)
  from public.ttm_readiness_r3259 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3259_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3259_hospital_scorecard() to authenticated;

-- 3) System type × ICU unit matrix
create or replace function public.founder_r3259_system_icu_matrix()
returns table(system_type text, icu_unit text, checks bigint, mission_ready bigint, avg_setpoint_error_c numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.system_type, l.icu_unit, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'mission_ready')::bigint,
    round(avg(l.setpoint_accuracy_error_c), 2)
  from public.ttm_readiness_r3259 l
  group by l.system_type, l.icu_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3259_system_icu_matrix() from public, anon;
grant execute on function public.founder_r3259_system_icu_matrix() to authenticated;

-- 4) Daily readiness check trend
create or replace function public.founder_r3259_daily_check_trend()
returns table(check_date date, checks bigint, mission_ready bigint, not_ready bigint, probe_issues bigint, alarm_fail bigint)
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
    count(*) filter (where l.patient_temp_probe_ok in ('drift','fail'))::bigint,
    count(*) filter (where l.alarm_function_test = 'fail')::bigint
  from public.ttm_readiness_r3259 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3259_daily_check_trend() from public, anon;
grant execute on function public.founder_r3259_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3259_capa_status_board()
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
  from public.ttm_readiness_capa_actions_r3259 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3259_capa_status_board() from public, anon;
grant execute on function public.founder_r3259_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3259_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.ttm_readiness_capa_actions_r3259)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.ttm_readiness_capa_actions_r3259 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3259_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3259_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3259_regulatory_impact_digest()
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
  from public.ttm_readiness_capa_actions_r3259 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3259_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3259_regulatory_impact_digest() to authenticated;

-- 8) High-risk readiness queue (top individual concerns)
create or replace function public.founder_r3259_high_risk_queue()
returns table(
  hospital_name text,
  icu_unit text,
  unit_code text,
  check_date date,
  readiness_verdict text,
  pad_blanket_stock text,
  tubing_condition text,
  patient_temp_probe_ok text,
  alarm_function_test text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.icu_unit, l.unit_code, l.check_date,
    l.readiness_verdict, l.pad_blanket_stock, l.tubing_condition, l.patient_temp_probe_ok,
    l.alarm_function_test, l.notes
  from public.ttm_readiness_r3259 l
  where l.readiness_verdict in ('conditional','not_ready','out_of_service')
     or l.pad_blanket_stock in ('low','expired_stock','none')
     or l.tubing_condition in ('kinked','cracked','leak_detected')
     or l.patient_temp_probe_ok in ('drift','fail')
     or l.alarm_function_test in ('fail','not_tested')
     or l.water_level_ok = false
     or l.disinfection_cycle_current = false
     or l.response_drill_this_quarter = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3259_high_risk_queue() from public, anon;
grant execute on function public.founder_r3259_high_risk_queue() to authenticated;
