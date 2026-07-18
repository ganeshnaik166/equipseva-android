-- Round 3140: Customer Hospital Anaesthesia Machine Vaporizer & Circuit-Leak Pre-Use Audit
-- Pre-use machine check log — agent × vaporizer output % × low-pressure leak × circuit leak × O2 flush × scavenging × backup O2 × verdict × CAPA

-- =============================================================================
-- TABLE 1: anaesthesia_machine_r3140 — individual pre-use anaesthesia machine checks
-- =============================================================================
create table if not exists public.anaesthesia_machine_r3140 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ot_room_code text not null,
  machine_asset_tag text not null,
  machine_model text not null,
  check_number int not null,
  check_date date not null,
  check_started_at timestamptz not null,
  check_completed_at timestamptz,
  anaesthetic_agent text not null check (anaesthetic_agent in (
    'sevoflurane','isoflurane','desflurane','halothane','no_agent_loaded'
  )),
  vaporizer_type text not null check (vaporizer_type in (
    'tec7_selectatec','aladin2_cassette','d_vapor_desflurane','draeger_vapor2000','sigma_delta','no_vaporizer'
  )),
  vaporizer_output_pct numeric(4,2),
  vaporizer_output_verdict text not null check (vaporizer_output_verdict in (
    'within_tolerance','above_tolerance','below_tolerance','not_tested'
  )),
  low_pressure_leak_ml_per_min numeric(6,2),
  low_pressure_leak_verdict text not null check (low_pressure_leak_verdict in (
    'pass','fail','borderline','not_run'
  )),
  circuit_leak_test text not null check (circuit_leak_test in (
    'pass','fail','borderline','not_run'
  )),
  o2_flush_test text not null check (o2_flush_test in (
    'pass','fail','not_tested'
  )),
  scavenging_test text not null check (scavenging_test in (
    'pass','fail','disconnected','not_tested'
  )),
  backup_o2_cylinder text not null check (backup_o2_cylinder in (
    'full','adequate','low','empty','absent'
  )),
  operator_profile_id uuid references public.profiles(id) on delete set null,
  machine_verdict text not null check (machine_verdict in (
    'released_for_use','conditional_use','quarantined','withdrawn_from_service','pending_review','recall_needed'
  )),
  released_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.anaesthesia_machine_r3140 enable row level security;

create index if not exists idx_anaesthesia_machine_r3140_org on public.anaesthesia_machine_r3140(organization_id);
create index if not exists idx_anaesthesia_machine_r3140_date on public.anaesthesia_machine_r3140(check_date);
create index if not exists idx_anaesthesia_machine_r3140_verdict on public.anaesthesia_machine_r3140(machine_verdict);

-- =============================================================================
-- TABLE 2: anaesthesia_machine_capa_actions_r3140 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.anaesthesia_machine_capa_actions_r3140 (
  id uuid primary key default gen_random_uuid(),
  check_log_id uuid not null references public.anaesthesia_machine_r3140(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'vaporizer_output_drift','low_pressure_leak','circuit_leak','o2_flush_failure',
    'scavenging_failure','backup_o2_depleted','agent_misfill','preventive_maintenance_due','sensor_fault','valve_leak'
  )),
  root_cause text not null check (root_cause in (
    'vaporizer_seal_worn','o_ring_perished','soda_lime_canister_loose','breathing_circuit_cracked',
    'apl_valve_stuck','flow_sensor_drift','check_valve_faulty','operator_setup_error',
    'calibration_overdue','pending_investigation','preventive_service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_vaporizer_seal','replace_o_ring','reseat_soda_lime_canister','replace_breathing_circuit',
    'service_apl_valve','recalibrate_flow_sensor','replace_check_valve','retrain_operator',
    'schedule_amc_visit','send_vaporizer_for_calibration','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','patient_safety_alert'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.anaesthesia_machine_capa_actions_r3140 enable row level security;

create index if not exists idx_anaesthesia_capa_r3140_check on public.anaesthesia_machine_capa_actions_r3140(check_log_id);
create index if not exists idx_anaesthesia_capa_r3140_status on public.anaesthesia_machine_capa_actions_r3140(capa_status);

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

  -- 14 pre-use check rows
  insert into public.anaesthesia_machine_r3140 (
    organization_id, hospital_name, ot_room_code, machine_asset_tag, machine_model,
    check_number, check_date, check_started_at, check_completed_at,
    anaesthetic_agent, vaporizer_type, vaporizer_output_pct, vaporizer_output_verdict,
    low_pressure_leak_ml_per_min, low_pressure_leak_verdict,
    circuit_leak_test, o2_flush_test, scavenging_test, backup_o2_cylinder,
    machine_verdict, released_at, notes
  )
  select v_org_id, q.hosp, q.ot, q.tag, q.model,
    q.cn, q.cd::date, q.cs::timestamptz, q.ce::timestamptz,
    q.agent, q.vap, q.vout, q.voutv,
    q.lpleak, q.lpv, q.cleak, q.o2f, q.scav, q.bo2,
    q.verdict, q.rel::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','OT-2','AM-APL-021','GE Aisys CS2',1,'2026-07-15','2026-07-15 06:05:00+05:30','2026-07-15 06:25:00+05:30',
     'sevoflurane','aladin2_cassette',2.05,'within_tolerance',45.00,'pass','pass','pass','pass','full','released_for_use','2026-07-15 06:30:00+05:30','Routine morning pre-use check all pass'),
    ('Apollo Hyderabad Jubilee Hills','OT-4','AM-APL-024','Draeger Perseus A500',2,'2026-07-15','2026-07-15 06:40:00+05:30','2026-07-15 07:05:00+05:30',
     'desflurane','d_vapor_desflurane',6.10,'within_tolerance',60.00,'pass','pass','pass','pass','adequate','released_for_use','2026-07-15 07:10:00+05:30','Desflurane D-Vapor within spec'),
    ('Fortis Bannerghatta Bengaluru','OT-1','AM-FRT-009','Draeger Fabius Plus',8,'2026-07-15','2026-07-15 05:35:00+05:30','2026-07-15 06:00:00+05:30',
     'sevoflurane','tec7_selectatec',1.40,'below_tolerance',210.00,'fail','pass','pass','pass','adequate','quarantined',null,'LP leak 210 mL/min exceeds 150 threshold; vaporizer under-delivering'),
    ('Fortis Bannerghatta Bengaluru','OT-3','AM-FRT-012','GE Avance CS2',9,'2026-07-15','2026-07-15 06:20:00+05:30','2026-07-15 06:45:00+05:30',
     'isoflurane','tec7_selectatec',1.15,'within_tolerance',30.00,'pass','fail','pass','pass','low','conditional_use','2026-07-15 06:50:00+05:30','O2 flush weak; backup cylinder low — flagged for service'),
    ('Manipal Whitefield Bengaluru','OT-2','AM-MNP-018','Mindray A7',15,'2026-07-14','2026-07-14 07:15:00+05:30','2026-07-14 07:40:00+05:30',
     'sevoflurane','sigma_delta',2.20,'within_tolerance',55.00,'pass','pass','pass','disconnected','full','withdrawn_from_service',null,'Scavenging disconnected — theatre pollution risk; machine withdrawn'),
    ('Manipal Whitefield Bengaluru','OT-5','AM-MNP-022','Draeger Primus',16,'2026-07-14','2026-07-14 08:00:00+05:30','2026-07-14 08:20:00+05:30',
     'sevoflurane','aladin2_cassette',1.98,'within_tolerance',40.00,'pass','pass','pass','pass','full','released_for_use','2026-07-14 08:25:00+05:30','Post-service verification pass'),
    ('AIIMS New Delhi Ansari Nagar','OT-6','AM-AIM-030','GE Aisys CS2',42,'2026-07-14','2026-07-14 06:10:00+05:30','2026-07-14 06:35:00+05:30',
     'desflurane','d_vapor_desflurane',5.80,'below_tolerance',70.00,'pass','pass','pass','pass','adequate','conditional_use','2026-07-14 06:40:00+05:30','Desflurane output slightly low; monitor, cassette recal booked'),
    ('AIIMS New Delhi Ansari Nagar','OT-2','AM-AIM-033','Draeger Perseus A500',43,'2026-07-14','2026-07-14 07:00:00+05:30','2026-07-14 07:30:00+05:30',
     'isoflurane','draeger_vapor2000',1.20,'within_tolerance',35.00,'pass','pass','pass','pass','full','released_for_use','2026-07-14 07:35:00+05:30','Standard iso setup, all checks pass'),
    ('KIMS Secunderabad','OT-4','AM-KIM-014','Penlon Prima 465',28,'2026-07-13','2026-07-13 05:50:00+05:30','2026-07-13 06:15:00+05:30',
     'halothane','tec7_selectatec',0.90,'within_tolerance',180.00,'fail','pass','pass','pass','adequate','quarantined',null,'Circuit leak detected at Y-piece; halothane legacy machine'),
    ('KIMS Secunderabad','OT-1','AM-KIM-011','Draeger Fabius Plus',29,'2026-07-13','2026-07-13 06:30:00+05:30','2026-07-13 06:50:00+05:30',
     'sevoflurane','tec7_selectatec',2.60,'above_tolerance',50.00,'pass','pass','pass','pass','full','pending_review',null,'Vaporizer over-delivering 2.6% at 2.0 dial — recal required'),
    ('Care Hospitals Banjara Hills','OT-2','AM-CAR-007','Mindray A7',11,'2026-07-13','2026-07-13 09:05:00+05:30','2026-07-13 09:25:00+05:30',
     'sevoflurane','sigma_delta',2.02,'within_tolerance',48.00,'pass','pass','pass','pass','full','released_for_use','2026-07-13 09:30:00+05:30','Routine daily check'),
    ('Yashoda Somajiguda Hyderabad','OT-6','AM-YSH-020','GE Avance CS2',67,'2026-07-12','2026-07-12 06:35:00+05:30','2026-07-12 06:55:00+05:30',
     'sevoflurane','aladin2_cassette',2.08,'within_tolerance',52.00,'pass','pass','pass','pass','adequate','released_for_use','2026-07-12 07:00:00+05:30','Monitored pre-use, pass'),
    ('St John''s Bengaluru','OT-1','AM-STJ-005','Draeger Primus',9,'2026-07-12','2026-07-12 05:55:00+05:30','2026-07-12 06:20:00+05:30',
     'isoflurane','draeger_vapor2000',1.10,'within_tolerance',120.00,'borderline','pass','pass','pass','adequate','conditional_use','2026-07-12 06:25:00+05:30','LP leak 120 borderline; retest next shift'),
    ('Rainbow Children''s Hyderabad','OT-3','AM-RBW-012','Penlon Prima 465',24,'2026-07-11','2026-07-11 07:05:00+05:30',null,
     'no_agent_loaded','no_vaporizer',null,'not_tested',null,'not_run','not_run','not_tested','not_tested','empty','recall_needed',null,'Backup O2 empty, agent not loaded, check aborted — recall for full service')
  ) as q(hosp, ot, tag, model, cn, cd, cs, ce, agent, vap, vout, voutv, lpleak, lpv, cleak, o2f, scav, bo2, verdict, rel, nt);

  -- CAPA seed — attach to specific checks
  insert into public.anaesthesia_machine_capa_actions_r3140 (
    check_log_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select c.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('Fortis Bannerghatta Bengaluru', 8, 'low_pressure_leak','vaporizer_seal_worn','replace_vaporizer_seal','2026-07-20',null,'in_progress','nabh_finding',18000.00,'Vaporizer seal kit ordered; machine quarantined'),
    ('Manipal Whitefield Bengaluru',  15, 'scavenging_failure','operator_setup_error','retrain_operator','2026-07-19',null,'escalated','patient_safety_alert',9500.00,'Scavenging line disconnected — OT pollution; escalated to biomed head'),
    ('KIMS Secunderabad',             28, 'circuit_leak','breathing_circuit_cracked','replace_breathing_circuit','2026-07-18','2026-07-15','closed','iso_13485_deviation',3200.00,'Cracked Y-piece replaced, retest pass'),
    ('KIMS Secunderabad',             29, 'vaporizer_output_drift','calibration_overdue','send_vaporizer_for_calibration','2026-07-22',null,'open','cdsco_notifiable',15000.00,'Vaporizer over-delivering; sent to OEM for calibration'),
    ('AIIMS New Delhi Ansari Nagar',  42, 'vaporizer_output_drift','flow_sensor_drift','recalibrate_flow_sensor','2026-07-21',null,'verification_pending','internal_only',6500.00,'Desflurane cassette flow sensor recal in progress'),
    ('Rainbow Children''s Hyderabad', 24, 'backup_o2_depleted','preventive_service_backlog','schedule_amc_visit','2026-07-17',null,'overdue','nabh_finding',12000.00,'Backup O2 empty + PM overdue; AMC visit overdue by 2 days')
  ) as q(hosp_key, cn_key, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.anaesthesia_machine_r3140 c
    on c.organization_id = v_org_id and c.hospital_name = q.hosp_key and c.check_number = q.cn_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Machine verdict distribution
create or replace function public.founder_r3140_verdict_rollup()
returns table(machine_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.anaesthesia_machine_r3140)
  select l.machine_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.anaesthesia_machine_r3140 l
  group by l.machine_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3140_verdict_rollup() from public, anon;
grant execute on function public.founder_r3140_verdict_rollup() to authenticated;

-- 2) Hospital-level fitness scorecard
create or replace function public.founder_r3140_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  released bigint,
  quarantined bigint,
  withdrawn bigint,
  lp_leak_fail bigint,
  circuit_fail bigint,
  vaporizer_drift bigint,
  fitness_pct numeric
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
    count(*) filter (where l.machine_verdict = 'released_for_use')::bigint,
    count(*) filter (where l.machine_verdict = 'quarantined')::bigint,
    count(*) filter (where l.machine_verdict = 'withdrawn_from_service')::bigint,
    count(*) filter (where l.low_pressure_leak_verdict = 'fail')::bigint,
    count(*) filter (where l.circuit_leak_test = 'fail')::bigint,
    count(*) filter (where l.vaporizer_output_verdict in ('above_tolerance','below_tolerance'))::bigint,
    round(100.0 * count(*) filter (where l.machine_verdict = 'released_for_use')::numeric / nullif(count(*),0), 1)
  from public.anaesthesia_machine_r3140 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3140_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3140_hospital_scorecard() to authenticated;

-- 3) Agent × vaporizer breakdown matrix
create or replace function public.founder_r3140_agent_vaporizer_matrix()
returns table(anaesthetic_agent text, vaporizer_type text, checks bigint, released bigint, avg_output_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.anaesthetic_agent, l.vaporizer_type, count(*)::bigint,
    count(*) filter (where l.machine_verdict = 'released_for_use')::bigint,
    round(avg(l.vaporizer_output_pct), 2)
  from public.anaesthesia_machine_r3140 l
  group by l.anaesthetic_agent, l.vaporizer_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3140_agent_vaporizer_matrix() from public, anon;
grant execute on function public.founder_r3140_agent_vaporizer_matrix() to authenticated;

-- 4) Low-pressure & circuit leak daily trend
create or replace function public.founder_r3140_leak_daily_trend()
returns table(check_date date, lp_pass bigint, lp_fail bigint, lp_borderline bigint, circuit_pass bigint, circuit_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*) filter (where l.low_pressure_leak_verdict = 'pass')::bigint,
    count(*) filter (where l.low_pressure_leak_verdict = 'fail')::bigint,
    count(*) filter (where l.low_pressure_leak_verdict = 'borderline')::bigint,
    count(*) filter (where l.circuit_leak_test = 'pass')::bigint,
    count(*) filter (where l.circuit_leak_test = 'fail')::bigint
  from public.anaesthesia_machine_r3140 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3140_leak_daily_trend() from public, anon;
grant execute on function public.founder_r3140_leak_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3140_capa_status_board()
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
  from public.anaesthesia_machine_capa_actions_r3140 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3140_capa_status_board() from public, anon;
grant execute on function public.founder_r3140_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3140_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.anaesthesia_machine_capa_actions_r3140)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.anaesthesia_machine_capa_actions_r3140 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3140_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3140_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3140_regulatory_impact_digest()
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
  from public.anaesthesia_machine_capa_actions_r3140 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3140_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3140_regulatory_impact_digest() to authenticated;

-- 8) High-risk machines list (top individual concerns)
create or replace function public.founder_r3140_high_risk_checks()
returns table(
  hospital_name text,
  ot_room_code text,
  machine_asset_tag text,
  check_date date,
  machine_verdict text,
  vaporizer_output_verdict text,
  low_pressure_leak_verdict text,
  circuit_leak_test text,
  scavenging_test text,
  backup_o2_cylinder text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ot_room_code, l.machine_asset_tag, l.check_date,
    l.machine_verdict, l.vaporizer_output_verdict, l.low_pressure_leak_verdict,
    l.circuit_leak_test, l.scavenging_test, l.backup_o2_cylinder, l.notes
  from public.anaesthesia_machine_r3140 l
  where l.machine_verdict in ('quarantined','withdrawn_from_service','recall_needed','pending_review','conditional_use')
     or l.low_pressure_leak_verdict = 'fail'
     or l.circuit_leak_test = 'fail'
     or l.vaporizer_output_verdict in ('above_tolerance','below_tolerance')
     or l.scavenging_test in ('fail','disconnected')
     or l.backup_o2_cylinder in ('low','empty','absent')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3140_high_risk_checks() from public, anon;
grant execute on function public.founder_r3140_high_risk_checks() to authenticated;
