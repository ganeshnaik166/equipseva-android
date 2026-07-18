-- Round 3279: Customer Hospital NPWT (Negative-Pressure Wound Therapy) Pump Fleet QC Audit
-- Wound-vac fleet QA — pump type × target pressure accuracy × leak/blockage alarm × canister seal × battery runtime × infection-control clean × accessories stock × calibration × CAPA

-- =============================================================================
-- TABLE 1: npwt_pump_qc_r3279 — individual NPWT pump QC checks
-- =============================================================================
create table if not exists public.npwt_pump_qc_r3279 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  pump_code text not null,
  pump_type text not null check (pump_type in (
    'stationary_npwt','portable_npwt','single_use_disposable','instillation_npwt'
  )),
  ward text not null,
  check_date date not null,
  target_pressure_mmhg int not null,
  pressure_delivery_error_mmhg numeric(6,2),
  leak_alarm_test text not null check (leak_alarm_test in (
    'pass','fail','not_tested'
  )),
  blockage_alarm_test text not null check (blockage_alarm_test in (
    'pass','fail','not_tested'
  )),
  canister_seal_ok boolean not null default true,
  battery_runtime_hours numeric(5,2),
  therapy_hours_logged int,
  infection_control_clean_ok boolean not null default true,
  accessories_stock text not null check (accessories_stock in (
    'adequate','low','out_of_stock'
  )),
  calibration_current boolean not null default true,
  qc_verdict text not null check (qc_verdict in (
    'pass','conditional_pass','fail','removed_from_service'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.npwt_pump_qc_r3279 enable row level security;

create index if not exists idx_npwt_pump_qc_r3279_org on public.npwt_pump_qc_r3279(organization_id);
create index if not exists idx_npwt_pump_qc_r3279_date on public.npwt_pump_qc_r3279(check_date);
create index if not exists idx_npwt_pump_qc_r3279_verdict on public.npwt_pump_qc_r3279(qc_verdict);

-- =============================================================================
-- TABLE 2: npwt_pump_qc_capa_actions_r3279 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.npwt_pump_qc_capa_actions_r3279 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  qc_log_id uuid not null references public.npwt_pump_qc_r3279(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'pressure_delivery_deviation','leak_alarm_failure','blockage_alarm_failure','canister_seal_failure',
    'battery_runtime_low','infection_control_breach','accessories_stockout','calibration_overdue','preventive_maintenance_due'
  )),
  root_cause text not null check (root_cause in (
    'pump_pressure_transducer_drift','alarm_sensor_fault','canister_gasket_worn','battery_degraded',
    'tubing_kink_or_leak','cleaning_protocol_lapse','consumable_supply_delay','calibration_backlog',
    'pending_investigation','operator_setup_error'
  )),
  corrective_action text not null check (corrective_action in (
    'recalibrate_pressure_sensor','replace_alarm_sensor','replace_canister_gasket','replace_battery_pack',
    'replace_tubing_set','reprocess_and_disinfect','expedite_consumable_restock','schedule_oem_service',
    'retrain_ward_staff','remove_from_service','none_required'
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

alter table public.npwt_pump_qc_capa_actions_r3279 enable row level security;

create index if not exists idx_npwt_capa_r3279_log on public.npwt_pump_qc_capa_actions_r3279(qc_log_id);
create index if not exists idx_npwt_capa_r3279_status on public.npwt_pump_qc_capa_actions_r3279(capa_status);

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

  -- 14 NPWT pump QC rows
  insert into public.npwt_pump_qc_r3279 (
    organization_id, hospital_name, pump_code, pump_type, ward, check_date,
    target_pressure_mmhg, pressure_delivery_error_mmhg, leak_alarm_test, blockage_alarm_test,
    canister_seal_ok, battery_runtime_hours, therapy_hours_logged, infection_control_clean_ok,
    accessories_stock, calibration_current, qc_verdict, notes
  )
  select v_org_id, q.hosp, q.code, q.ptype, q.ward, q.cd::date,
    q.tgt, q.perr, q.leak, q.block,
    q.seal, q.batt, q.thrs, q.infc,
    q.acc, q.cal, q.qv, q.nt
  from (values
    ('Apollo Chennai Greams Road','NPWT-APL-01','stationary_npwt','Surgical ICU','2026-07-02',
     125,3.5,'pass','pass',true,8.5,96,true,'adequate',true,'pass','Routine quarterly QC — pressure and alarms nominal'),
    ('Apollo Chennai Greams Road','NPWT-APL-02','portable_npwt','Ortho Ward','2026-07-02',
     100,12.0,'pass','pass',true,4.2,72,true,'low',true,'conditional_pass','Pressure delivery 12 mmHg above tolerance — recheck booked'),
    ('Fortis Gurgaon','NPWT-FRT-11','instillation_npwt','Plastic Surgery','2026-07-01',
     125,4.0,'fail','pass',true,6.0,60,true,'adequate',true,'removed_from_service','Leak alarm missed challenge — unit pulled from ward'),
    ('Fortis Gurgaon','NPWT-FRT-12','stationary_npwt','Vascular Ward','2026-07-01',
     150,18.5,'pass','fail',false,7.5,84,true,'adequate',false,'fail','Blockage alarm no-trip and canister seal leak found'),
    ('Manipal Bengaluru Old Airport Road','NPWT-MNP-21','portable_npwt','Trauma Ward','2026-06-30',
     100,2.0,'pass','pass',true,3.1,48,true,'adequate',true,'conditional_pass','Battery runtime 3.1h below 4h floor — battery watch'),
    ('Manipal Bengaluru Old Airport Road','NPWT-MNP-22','single_use_disposable','Diabetic Foot Clinic','2026-06-30',
     75,1.5,'not_tested','not_tested',true,null,24,true,'adequate',true,'pass','Single-use disposable — alarms not user-testable, spot pass'),
    ('AIIMS Delhi Ansari Nagar','NPWT-AIM-31','instillation_npwt','Burns Unit','2026-06-29',
     125,22.0,'pass','pass',true,5.5,90,false,'low',true,'fail','Instillation cycle 22 mmHg off and cleaning protocol lapse'),
    ('AIIMS Delhi Ansari Nagar','NPWT-AIM-32','stationary_npwt','General Surgery','2026-06-29',
     100,3.0,'pass','pass',true,8.0,78,true,'adequate',true,'pass','Annual QC clean pass'),
    ('CMC Vellore','NPWT-CMC-41','portable_npwt','Colorectal Ward','2026-06-28',
     125,9.5,'pass','pass',true,4.0,66,true,'out_of_stock',true,'conditional_pass','Foam dressing kits out of stock — therapy continuity risk'),
    ('CMC Vellore','NPWT-CMC-42','single_use_disposable','Wound Care OPD','2026-06-28',
     80,2.5,'not_tested','not_tested',true,null,30,true,'adequate',true,'pass','Disposable unit spot-check pass'),
    ('KIMS Hyderabad','NPWT-KIM-51','stationary_npwt','Cardiothoracic ICU','2026-06-27',
     125,5.0,'pass','pass',false,7.0,88,true,'adequate',true,'conditional_pass','Canister seal marginal — gasket replacement scheduled'),
    ('KIMS Hyderabad','NPWT-KIM-52','instillation_npwt','Plastic Surgery','2026-06-27',
     150,4.5,'pass','pass',true,6.5,54,true,'adequate',true,'pass','Post-AMC verification pass'),
    ('Yashoda Hyderabad Somajiguda','NPWT-YSH-61','portable_npwt','Ortho Ward','2026-06-26',
     100,null,'not_tested','not_tested',true,null,null,false,'low',false,'removed_from_service','QC aborted — pump powering off intermittently, sent to biomed'),
    ('Rainbow Bengaluru Marathahalli','NPWT-RBW-71','single_use_disposable','Paediatric Surgery','2026-06-26',
     50,1.0,'not_tested','not_tested',true,null,20,true,'adequate',true,'pass','Paediatric low-pressure protocol verified')
  ) as q(hosp, code, ptype, ward, cd, tgt, perr, leak, block, seal, batt, thrs, infc, acc, cal, qv, nt);

  -- CAPA seed — attach to specific pump checks via pump_code
  insert into public.npwt_pump_qc_capa_actions_r3279 (
    organization_id, qc_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('NPWT-FRT-11','leak_alarm_failure','alarm_sensor_fault','replace_alarm_sensor','in_progress','patient_safety_alert','2026-07-06',null,15000.00,'Alarm sensor replaced — awaiting leak re-challenge test'),
    ('NPWT-FRT-12','blockage_alarm_failure','canister_gasket_worn','replace_canister_gasket','escalated','cdsco_notifiable','2026-07-05',null,28000.00,'No blockage trip and seal leak — escalated to OEM engineer'),
    ('NPWT-AIM-31','pressure_delivery_deviation','pump_pressure_transducer_drift','recalibrate_pressure_sensor','open','nabh_finding','2026-07-08',null,34000.00,'Instillation pressure 22 mmHg off — transducer recal pending'),
    ('NPWT-MNP-21','battery_runtime_low','battery_degraded','replace_battery_pack','closed','iso_13485_deviation','2026-07-02','2026-06-30',9500.00,'Battery pack replaced, runtime restored to 6.2h'),
    ('NPWT-CMC-41','accessories_stockout','consumable_supply_delay','expedite_consumable_restock','verification_pending','internal_only','2026-07-04',null,0.00,'Foam dressing PO expedited — verify stock on delivery'),
    ('NPWT-KIM-51','canister_seal_failure','canister_gasket_worn','replace_canister_gasket','overdue','internal_only','2026-06-24',null,6500.00,'Gasket replacement past target date — AMC vendor delayed'),
    ('NPWT-YSH-61','preventive_maintenance_due','pending_investigation','schedule_oem_service','open','patient_safety_alert','2026-07-07',null,42000.00,'Intermittent power fault — OEM diagnostic scheduled')
  ) as q(tag, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.npwt_pump_qc_r3279 e
    on e.organization_id = v_org_id and e.pump_code = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) QC verdict distribution
create or replace function public.founder_r3279_qc_verdict_rollup()
returns table(qc_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.npwt_pump_qc_r3279)
  select l.qc_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.npwt_pump_qc_r3279 l
  group by l.qc_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3279_qc_verdict_rollup() from public, anon;
grant execute on function public.founder_r3279_qc_verdict_rollup() to authenticated;

-- 2) Hospital-level QC scorecard
create or replace function public.founder_r3279_hospital_scorecard()
returns table(
  hospital_name text,
  total_checks bigint,
  passed bigint,
  conditional bigint,
  failed bigint,
  leak_alarm_fail bigint,
  blockage_alarm_fail bigint,
  seal_fail bigint,
  pass_pct numeric
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
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict = 'conditional_pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.leak_alarm_test = 'fail')::bigint,
    count(*) filter (where l.blockage_alarm_test = 'fail')::bigint,
    count(*) filter (where l.canister_seal_ok = false)::bigint,
    round(100.0 * count(*) filter (where l.qc_verdict = 'pass')::numeric / nullif(count(*),0), 1)
  from public.npwt_pump_qc_r3279 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3279_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3279_hospital_scorecard() to authenticated;

-- 3) Pump type × ward matrix
create or replace function public.founder_r3279_pump_type_ward_matrix()
returns table(pump_type text, ward text, checks bigint, passed bigint, avg_pressure_error_mmhg numeric, avg_battery_runtime_hours numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.pump_type, l.ward, count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    round(avg(l.pressure_delivery_error_mmhg), 2),
    round(avg(l.battery_runtime_hours), 1)
  from public.npwt_pump_qc_r3279 l
  group by l.pump_type, l.ward
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3279_pump_type_ward_matrix() from public, anon;
grant execute on function public.founder_r3279_pump_type_ward_matrix() to authenticated;

-- 4) Daily QC trend
create or replace function public.founder_r3279_daily_qc_trend()
returns table(check_date date, checks bigint, passed bigint, failed bigint, leak_alarm_fail bigint, blockage_alarm_fail bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.qc_verdict = 'pass')::bigint,
    count(*) filter (where l.qc_verdict in ('fail','removed_from_service'))::bigint,
    count(*) filter (where l.leak_alarm_test = 'fail')::bigint,
    count(*) filter (where l.blockage_alarm_test = 'fail')::bigint
  from public.npwt_pump_qc_r3279 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3279_daily_qc_trend() from public, anon;
grant execute on function public.founder_r3279_daily_qc_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3279_capa_status_board()
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
  from public.npwt_pump_qc_capa_actions_r3279 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3279_capa_status_board() from public, anon;
grant execute on function public.founder_r3279_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3279_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.npwt_pump_qc_capa_actions_r3279)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.npwt_pump_qc_capa_actions_r3279 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3279_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3279_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3279_regulatory_impact_digest()
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
  from public.npwt_pump_qc_capa_actions_r3279 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3279_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3279_regulatory_impact_digest() to authenticated;

-- 8) High-risk QC queue (top individual concerns)
create or replace function public.founder_r3279_high_risk_queue()
returns table(
  hospital_name text,
  pump_code text,
  ward text,
  check_date date,
  qc_verdict text,
  leak_alarm_test text,
  blockage_alarm_test text,
  accessories_stock text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.pump_code, l.ward, l.check_date,
    l.qc_verdict, l.leak_alarm_test, l.blockage_alarm_test, l.accessories_stock, l.notes
  from public.npwt_pump_qc_r3279 l
  where l.qc_verdict in ('conditional_pass','fail','removed_from_service')
     or l.leak_alarm_test = 'fail'
     or l.blockage_alarm_test = 'fail'
     or l.canister_seal_ok = false
     or l.infection_control_clean_ok = false
     or l.accessories_stock in ('low','out_of_stock')
     or l.calibration_current = false
  order by l.check_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3279_high_risk_queue() from public, anon;
grant execute on function public.founder_r3279_high_risk_queue() to authenticated;
