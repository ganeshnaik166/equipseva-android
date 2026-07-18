-- Round 3247: Customer Hospital CSSD Ultrasonic-Cleaner & Washer-Disinfector Cycle-Efficacy Audit
-- CSSD decontamination QA — machine type × soil/TOSI test × cavitation foil test × A0 thermal disinfection × detergent dosing × filter screen × chamber condition × printout log × CAPA

-- =============================================================================
-- TABLE 1: cssd_decontam_r3247 — per-cycle/machine decontamination-efficacy checks
-- =============================================================================
create table if not exists public.cssd_decontam_r3247 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  machine_code text not null,
  machine_type text not null check (machine_type in (
    'ultrasonic_cleaner','washer_disinfector','cart_washer','drying_cabinet'
  )),
  check_date date not null,
  cycle_count_today int not null,
  soil_test_result text not null check (soil_test_result in (
    'pass','fail','not_run'
  )),
  cavitation_test text not null check (cavitation_test in (
    'pass','weak','fail','not_applicable'
  )),
  temp_a0_achieved boolean not null,
  detergent_dosing_ok text not null check (detergent_dosing_ok in (
    'ok','under_dosing','over_dosing','empty'
  )),
  filter_screen_condition text not null check (filter_screen_condition in (
    'clean','partially_blocked','blocked'
  )),
  chamber_condition text not null check (chamber_condition in (
    'good','scale_buildup','corrosion'
  )),
  printout_or_log_ok boolean not null,
  audit_verdict text not null check (audit_verdict in (
    'pass','conditional_pass','fail','quarantined'
  )),
  checked_by text not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cssd_decontam_r3247 enable row level security;

create index if not exists idx_cssd_decontam_r3247_org on public.cssd_decontam_r3247(organization_id);
create index if not exists idx_cssd_decontam_r3247_date on public.cssd_decontam_r3247(check_date);
create index if not exists idx_cssd_decontam_r3247_verdict on public.cssd_decontam_r3247(audit_verdict);

-- =============================================================================
-- TABLE 2: cssd_decontam_capa_actions_r3247 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.cssd_decontam_capa_actions_r3247 (
  id uuid primary key default gen_random_uuid(),
  check_log_id uuid not null references public.cssd_decontam_r3247(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'soil_test_failure','cavitation_loss','thermal_disinfection_failure','detergent_dosing_fault',
    'filter_blockage','chamber_degradation','documentation_gap','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'transducer_degradation','dosing_pump_wear','heating_element_fault','water_quality_scale',
    'strainer_not_cleaned','detergent_stockout','operator_loading_error','printer_fault',
    'pending_investigation','service_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_transducer','recalibrate_dosing_pump','replace_heating_element','descale_chamber',
    'deep_clean_strainer','restock_detergent','retrain_cssd_staff','repair_printer',
    'quarantine_machine','schedule_oem_service','none_required'
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

alter table public.cssd_decontam_capa_actions_r3247 enable row level security;

create index if not exists idx_cssd_capa_r3247_log on public.cssd_decontam_capa_actions_r3247(check_log_id);
create index if not exists idx_cssd_capa_r3247_status on public.cssd_decontam_capa_actions_r3247(capa_status);

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

  -- 14 decontamination check rows
  insert into public.cssd_decontam_r3247 (
    organization_id, hospital_name, machine_code, machine_type, check_date,
    cycle_count_today, soil_test_result, cavitation_test, temp_a0_achieved,
    detergent_dosing_ok, filter_screen_condition, chamber_condition,
    printout_or_log_ok, audit_verdict, checked_by, notes
  )
  select v_org_id, q.hosp, q.mc, q.mt, q.cd::date,
    q.cyc, q.soil, q.cav, q.a0,
    q.dd, q.fsc, q.cc,
    q.plog, q.av, q.cb, q.nt
  from (values
    ('Apollo Chennai Greams Road','USC-APL-01','ultrasonic_cleaner','2026-07-02',
     9,'pass','pass',true,'ok','clean','good',true,'pass','Suresh Nair','Foil test even erosion — cavitation nominal, TOSI clean'),
    ('Apollo Chennai Greams Road','WD-APL-02','washer_disinfector','2026-07-02',
     12,'pass','not_applicable',true,'ok','clean','good',true,'pass','Suresh Nair','A0 3000 achieved — soil test coupons clear'),
    ('Fortis Gurgaon Sector 44','WD-FRT-01','washer_disinfector','2026-07-01',
     10,'fail','not_applicable',true,'under_dosing','partially_blocked','good',true,'fail','Ramesh Iyer','TOSI residue on 2 of 3 coupons — dosing pump under-delivering'),
    ('Fortis Gurgaon Sector 44','USC-FRT-02','ultrasonic_cleaner','2026-07-01',
     7,'pass','weak',true,'ok','clean','good',true,'conditional_pass','Ramesh Iyer','Foil erosion patchy centre-left — transducer bank on watch'),
    ('Manipal Old Airport Road Bengaluru','WD-MNP-01','washer_disinfector','2026-06-30',
     11,'pass','not_applicable',false,'ok','clean','scale_buildup',true,'fail','Kavitha Reddy','A0 fell short at 540 — heating element suspect plus chamber scale'),
    ('Manipal Old Airport Road Bengaluru','DC-MNP-02','drying_cabinet','2026-06-30',
     6,'not_run','not_applicable',true,'ok','partially_blocked','good',true,'conditional_pass','Kavitha Reddy','HEPA pre-filter partially blocked — swap scheduled'),
    ('AIIMS New Delhi Ansari Nagar','USC-AIM-01','ultrasonic_cleaner','2026-06-29',
     8,'pass','fail',true,'ok','clean','good',false,'quarantined','Vikram Singh','Foil test no erosion — transducer bank dead; cycle printout also blank'),
    ('AIIMS New Delhi Ansari Nagar','WD-AIM-02','washer_disinfector','2026-06-29',
     14,'pass','not_applicable',true,'ok','clean','good',true,'pass','Vikram Singh','Full pass — chemical and soil indicators clear'),
    ('CMC Vellore Main CSSD','CW-CMC-01','cart_washer','2026-06-28',
     5,'not_run','not_applicable',true,'over_dosing','clean','good',true,'conditional_pass','Anita George','Detergent over-dosing — foaming carryover on transport carts'),
    ('CMC Vellore Main CSSD','WD-CMC-02','washer_disinfector','2026-06-28',
     9,'pass','not_applicable',true,'ok','clean','good',true,'pass','Anita George','Routine weekly efficacy check clean'),
    ('KIMS Secunderabad','USC-KIM-01','ultrasonic_cleaner','2026-06-27',
     10,'fail','weak',true,'empty','blocked','good',true,'quarantined','Priya Menon','Detergent reservoir empty and strainer blocked — machine quarantined'),
    ('KIMS Secunderabad','WD-KIM-02','washer_disinfector','2026-06-27',
     13,'pass','not_applicable',true,'ok','clean','corrosion',true,'conditional_pass','Priya Menon','Corrosion spots near door seal — OEM inspection booked'),
    ('Max Saket New Delhi','WD-MAX-01','washer_disinfector','2026-06-26',
     12,'pass','not_applicable',true,'ok','clean','good',false,'conditional_pass','Arjun Mehta','Cycle printout faded — printer ribbon replacement due'),
    ('Kokilaben Ambani Mumbai','DC-KDA-01','drying_cabinet','2026-06-26',
     7,'not_run','not_applicable',true,'ok','clean','good',true,'pass','Sneha Kulkarni','Drying cabinet temperature uniformity verified')
  ) as q(hosp, mc, mt, cd, cyc, soil, cav, a0, dd, fsc, cc, plog, av, cb, nt);

  -- CAPA seed — attach to specific checks via machine code
  insert into public.cssd_decontam_capa_actions_r3247 (
    check_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('WD-FRT-01','soil_test_failure','dosing_pump_wear','recalibrate_dosing_pump','in_progress','nabh_finding','2026-07-06',null,22000.00,'Dosing pump recalibrated — TOSI re-run pending'),
    ('USC-AIM-01','cavitation_loss','transducer_degradation','replace_transducer','escalated','patient_safety_alert','2026-07-05',null,85000.00,'Transducer bank dead — instruments diverted to manual wash, OEM quote received'),
    ('WD-MNP-01','thermal_disinfection_failure','heating_element_fault','replace_heating_element','open','iso_13485_deviation','2026-07-08',null,46000.00,'Heating element on order — descale planned in same visit'),
    ('USC-KIM-01','detergent_dosing_fault','detergent_stockout','restock_detergent','closed','internal_only','2026-06-29','2026-06-28',6500.00,'Detergent restocked — released after retest'),
    ('USC-KIM-01','filter_blockage','strainer_not_cleaned','deep_clean_strainer','verification_pending','internal_only','2026-07-03',null,0.00,'Strainer deep-cleaned — foil retest scheduled'),
    ('WD-KIM-02','chamber_degradation','water_quality_scale','descale_chamber','open','nabh_finding','2026-07-10',null,18000.00,'Corrosion spots mapped — RO water feed audit added'),
    ('WD-MAX-01','documentation_gap','printer_fault','repair_printer','overdue','internal_only','2026-06-24',null,3500.00,'Ribbon replacement past target date — vendor delayed')
  ) as q(mc, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.cssd_decontam_r3247 e
    on e.organization_id = v_org_id and e.machine_code = q.mc;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Audit verdict distribution
create or replace function public.founder_r3247_audit_verdict_rollup()
returns table(audit_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cssd_decontam_r3247)
  select l.audit_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cssd_decontam_r3247 l
  group by l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3247_audit_verdict_rollup() from public, anon;
grant execute on function public.founder_r3247_audit_verdict_rollup() to authenticated;

-- 2) Hospital-level CSSD scorecard
create or replace function public.founder_r3247_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  quarantined bigint,
  soil_fail bigint,
  a0_missed bigint,
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
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.audit_verdict = 'fail')::bigint,
    count(*) filter (where l.audit_verdict = 'quarantined')::bigint,
    count(*) filter (where l.soil_test_result = 'fail')::bigint,
    count(*) filter (where not l.temp_a0_achieved)::bigint,
    round(100.0 * count(*) filter (where l.audit_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.cssd_decontam_r3247 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3247_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3247_hospital_scorecard() to authenticated;

-- 3) Machine type × audit verdict matrix
create or replace function public.founder_r3247_machine_verdict_matrix()
returns table(machine_type text, audit_verdict text, checks bigint, avg_cycles_today numeric, a0_achieved bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.machine_type, l.audit_verdict, count(*)::bigint,
    round(avg(l.cycle_count_today)::numeric, 1),
    count(*) filter (where l.temp_a0_achieved)::bigint
  from public.cssd_decontam_r3247 l
  group by l.machine_type, l.audit_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3247_machine_verdict_matrix() from public, anon;
grant execute on function public.founder_r3247_machine_verdict_matrix() to authenticated;

-- 4) Daily check trend
create or replace function public.founder_r3247_daily_check_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, soil_fail bigint, a0_missed bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.audit_verdict = 'pass')::bigint,
    count(*) filter (where l.audit_verdict in ('fail','quarantined'))::bigint,
    count(*) filter (where l.soil_test_result = 'fail')::bigint,
    count(*) filter (where not l.temp_a0_achieved)::bigint
  from public.cssd_decontam_r3247 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3247_daily_check_trend() from public, anon;
grant execute on function public.founder_r3247_daily_check_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3247_capa_status_board()
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
  from public.cssd_decontam_capa_actions_r3247 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3247_capa_status_board() from public, anon;
grant execute on function public.founder_r3247_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3247_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cssd_decontam_capa_actions_r3247)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cssd_decontam_capa_actions_r3247 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3247_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3247_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3247_regulatory_impact_digest()
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
  from public.cssd_decontam_capa_actions_r3247 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3247_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3247_regulatory_impact_digest() to authenticated;

-- 8) High-risk machine queue (top individual concerns)
create or replace function public.founder_r3247_high_risk_queue()
returns table(
  hospital_name text,
  machine_code text,
  machine_type text,
  check_date date,
  audit_verdict text,
  soil_test_result text,
  cavitation_test text,
  detergent_dosing_ok text,
  filter_screen_condition text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.machine_code, l.machine_type, l.check_date,
    l.audit_verdict, l.soil_test_result, l.cavitation_test, l.detergent_dosing_ok,
    l.filter_screen_condition, l.notes
  from public.cssd_decontam_r3247 l
  where l.audit_verdict in ('conditional_pass','fail','quarantined')
     or l.soil_test_result = 'fail'
     or l.cavitation_test in ('weak','fail')
     or not l.temp_a0_achieved
     or l.detergent_dosing_ok in ('under_dosing','over_dosing','empty')
     or l.filter_screen_condition in ('partially_blocked','blocked')
     or l.chamber_condition in ('scale_buildup','corrosion')
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3247_high_risk_queue() from public, anon;
grant execute on function public.founder_r3247_high_risk_queue() to authenticated;
