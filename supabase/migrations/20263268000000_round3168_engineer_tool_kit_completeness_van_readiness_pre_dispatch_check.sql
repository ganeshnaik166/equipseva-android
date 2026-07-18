-- Round 3168: Engineer Tool-Kit Completeness & Van-Readiness Pre-Dispatch Check
-- Pre-dispatch readiness log — engineer × kit category × items expected/present × calibrated-tool × PPE × spare stock × fuel/vehicle × readiness score × dispatch verdict + CAPA

-- =============================================================================
-- TABLE 1: tool_kit_readiness_r3168 — per-dispatch kit & van readiness check
-- =============================================================================
create table if not exists public.tool_kit_readiness_r3168 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  engineer_name text not null,
  destination_hospital_name text not null,
  dispatch_ref text not null,
  van_vehicle_reg text,
  kit_category text not null check (kit_category in (
    'biomedical_general','anesthesia_workstation','ventilator_icu','dialysis_ro',
    'ot_electrosurgical','imaging_xray_cath','sterilizer_autoclave','patient_monitor',
    'infusion_syringe_pump','cold_chain_refrigeration','laboratory_analyzer','oxygen_pipeline_gas'
  )),
  expected_item_count int not null,
  present_item_count int not null,
  calibrated_tool_status text not null check (calibrated_tool_status in (
    'all_valid','one_expiring_soon','one_expired','multiple_expired','calibration_cert_missing','not_required'
  )),
  ppe_status text not null check (ppe_status in (
    'complete','partial','expired_items','missing_critical','not_applicable'
  )),
  spare_stock_status text not null check (spare_stock_status in (
    'fully_stocked','minor_shortfall','critical_shortfall','wrong_parts_loaded','not_verified'
  )),
  fuel_vehicle_status text not null check (fuel_vehicle_status in (
    'ready','low_fuel','service_due','breakdown_risk','vehicle_unavailable'
  )),
  readiness_score numeric(5,2) not null,
  dispatch_verdict text not null check (dispatch_verdict in (
    'cleared_for_dispatch','conditional_dispatch','hold_pending_fix','blocked','rechecking','stood_down'
  )),
  check_date date not null,
  checked_at timestamptz not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tool_kit_readiness_r3168 enable row level security;

create index if not exists idx_tool_kit_readiness_r3168_org on public.tool_kit_readiness_r3168(organization_id);
create index if not exists idx_tool_kit_readiness_r3168_date on public.tool_kit_readiness_r3168(check_date);
create index if not exists idx_tool_kit_readiness_r3168_verdict on public.tool_kit_readiness_r3168(dispatch_verdict);

-- =============================================================================
-- TABLE 2: tool_kit_readiness_capa_actions_r3168 — CAPA & corrective actions
-- =============================================================================
create table if not exists public.tool_kit_readiness_capa_actions_r3168 (
  id uuid primary key default gen_random_uuid(),
  readiness_log_id uuid not null references public.tool_kit_readiness_r3168(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missing_kit_items','calibration_expired','ppe_incomplete','spare_shortfall',
    'wrong_parts','fuel_low','vehicle_unserviceable','documentation_gap','tool_damaged','stock_mismatch'
  )),
  root_cause text not null check (root_cause in (
    'restock_process_gap','calibration_schedule_slip','procurement_delay','vehicle_maintenance_backlog',
    'engineer_oversight','store_issue_error','vendor_supply_delay','budget_hold','training_gap','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replenish_kit_items','recalibrate_tools','reissue_ppe','expedite_spare_procurement',
    'swap_correct_parts','refuel_vehicle','schedule_vehicle_service','update_checklist_sop','retrain_engineer','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','cdsco_notifiable','none','internal_only','iso_13485_deviation','sla_breach_risk'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.tool_kit_readiness_capa_actions_r3168 enable row level security;

create index if not exists idx_tool_kit_readiness_capa_r3168_log on public.tool_kit_readiness_capa_actions_r3168(readiness_log_id);
create index if not exists idx_tool_kit_readiness_capa_r3168_status on public.tool_kit_readiness_capa_actions_r3168(capa_status);

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

  -- 14 pre-dispatch readiness rows
  insert into public.tool_kit_readiness_r3168 (
    organization_id, engineer_name, destination_hospital_name, dispatch_ref, van_vehicle_reg,
    kit_category, expected_item_count, present_item_count,
    calibrated_tool_status, ppe_status, spare_stock_status, fuel_vehicle_status,
    readiness_score, dispatch_verdict, check_date, checked_at, notes
  )
  select v_org_id, q.eng, q.hosp, q.ref, q.van,
    q.cat, q.exp::int, q.pres::int,
    q.cal, q.ppe, q.spare, q.fuel,
    q.score, q.verdict, q.cd::date, q.ck::timestamptz, q.nt
  from (values
    ('Ravi Teja','Apollo Hyderabad Jubilee Hills','PDC-APL-01','TS09AB1234',
     'ventilator_icu',28,28,'all_valid','complete','fully_stocked','ready',
     98.50,'cleared_for_dispatch','2026-07-17','2026-07-17 06:15:00+05:30','Full ICU ventilator kit verified at store'),
    ('Ravi Teja','Apollo Hyderabad Jubilee Hills','PDC-APL-02','TS09AB1234',
     'anesthesia_workstation',22,20,'one_expiring_soon','complete','minor_shortfall','ready',
     86.00,'conditional_dispatch','2026-07-17','2026-07-17 07:00:00+05:30','2 airway adapters short; flow sensor cal expiring in 9 days'),
    ('Suresh Kumar','Fortis Bannerghatta Bengaluru','PDC-FRT-01','KA05CD5678',
     'dialysis_ro',30,25,'one_expired','partial','critical_shortfall','low_fuel',
     58.00,'hold_pending_fix','2026-07-17','2026-07-17 05:40:00+05:30','RO membrane spares short; TDS meter cal expired'),
    ('Suresh Kumar','Fortis Bannerghatta Bengaluru','PDC-FRT-02','KA05CD5678',
     'imaging_xray_cath',18,18,'all_valid','complete','fully_stocked','service_due',
     82.00,'conditional_dispatch','2026-07-17','2026-07-17 06:30:00+05:30','Kit complete but van service overdue 300 km'),
    ('Anitha Rao','Manipal Whitefield Bengaluru','PDC-MNP-01','KA03EF9012',
     'sterilizer_autoclave',26,19,'multiple_expired','missing_critical','wrong_parts_loaded','breakdown_risk',
     34.00,'blocked','2026-07-16','2026-07-16 08:20:00+05:30','Wrong gasket set loaded; two cal certs expired; van AC compressor noisy'),
    ('Anitha Rao','Manipal Whitefield Bengaluru','PDC-MNP-02','KA03EF9012',
     'patient_monitor',20,20,'all_valid','complete','fully_stocked','ready',
     96.00,'cleared_for_dispatch','2026-07-16','2026-07-16 09:10:00+05:30','SpO2 and NIBP simulator checks verified'),
    ('Vikram Singh','AIIMS New Delhi Ansari Nagar','PDC-AIM-01','DL01GH3456',
     'infusion_syringe_pump',24,23,'one_expiring_soon','complete','minor_shortfall','ready',
     88.50,'conditional_dispatch','2026-07-16','2026-07-16 06:05:00+05:30','One occlusion test weight missing; flow analyzer cal due soon'),
    ('Vikram Singh','AIIMS New Delhi Ansari Nagar','PDC-AIM-02','DL01GH3456',
     'oxygen_pipeline_gas',16,16,'all_valid','complete','fully_stocked','ready',
     97.00,'cleared_for_dispatch','2026-07-16','2026-07-16 07:20:00+05:30','Gas analyzer and leak-test kit complete'),
    ('Priya Menon','KIMS Secunderabad','PDC-KIM-01','TS07IJ7890',
     'laboratory_analyzer',32,28,'calibration_cert_missing','partial','minor_shortfall','low_fuel',
     62.00,'hold_pending_fix','2026-07-15','2026-07-15 05:55:00+05:30','Pipette cal certificate missing; reagent probe spares short'),
    ('Priya Menon','KIMS Secunderabad','PDC-KIM-02','TS07IJ7890',
     'cold_chain_refrigeration',14,10,'one_expired','expired_items','critical_shortfall','ready',
     45.00,'blocked','2026-07-15','2026-07-15 07:15:00+05:30','Data-logger cal expired; door gasket spares out of stock; PPE gloves expired'),
    ('Mohan Das','Care Hospitals Banjara Hills','PDC-CAR-01','TS08KL2345',
     'ot_electrosurgical',21,21,'all_valid','complete','fully_stocked','ready',
     95.50,'cleared_for_dispatch','2026-07-15','2026-07-15 09:05:00+05:30','ESU analyzer and return-electrode tester verified'),
    ('Mohan Das','Yashoda Somajiguda Hyderabad','PDC-YSH-01','TS08KL2345',
     'biomedical_general',35,31,'one_expiring_soon','partial','minor_shortfall','service_due',
     74.00,'conditional_dispatch','2026-07-14','2026-07-14 06:35:00+05:30','General kit mostly complete; multimeter cal expiring; van brake service due'),
    ('Suresh Kumar','St John''s Bengaluru','PDC-STJ-01','KA02MN6789',
     'imaging_xray_cath',19,17,'not_required','complete','not_verified','vehicle_unavailable',
     40.00,'stood_down','2026-07-14','2026-07-14 05:50:00+05:30','Assigned van in accident repair; dispatch stood down pending reallocation'),
    ('Ravi Teja','Rainbow Children''s Hyderabad','PDC-RBW-01','TS09AB1234',
     'ventilator_icu',27,26,'all_valid','complete','minor_shortfall','ready',
     90.00,'rechecking','2026-07-14','2026-07-14 07:40:00+05:30','Neonatal circuit adapter being sourced; recheck scheduled at 10:00')
  ) as q(eng, hosp, ref, van, cat, exp, pres, cal, ppe, spare, fuel, score, verdict, cd, ck, nt);

  -- CAPA seed — attach to specific dispatch checks
  insert into public.tool_kit_readiness_capa_actions_r3168 (
    readiness_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cs, q.ri, q.tcd::date, q.acd::date, q.cost, q.nt
  from (values
    ('PDC-FRT-01','spare_shortfall','procurement_delay','expedite_spare_procurement','in_progress','sla_breach_risk','2026-07-22',null,65000.00,'RO membrane and TDS meter cal; SLA at risk for dialysis site'),
    ('PDC-MNP-01','wrong_parts','store_issue_error','swap_correct_parts','escalated','nabh_finding','2026-07-20',null,18000.00,'Wrong gasket set issued from store; dispatch blocked'),
    ('PDC-KIM-02','calibration_expired','calibration_schedule_slip','recalibrate_tools','closed','iso_13485_deviation','2026-07-19','2026-07-17',9500.00,'Data-logger recalibrated and returned to kit'),
    ('PDC-KIM-01','documentation_gap','engineer_oversight','update_checklist_sop','verification_pending','internal_only','2026-07-21',null,2000.00,'Pipette cal certificate traced and filed; SOP updated'),
    ('PDC-STJ-01','vehicle_unserviceable','vehicle_maintenance_backlog','schedule_vehicle_service','overdue','sla_breach_risk','2026-07-16',null,42000.00,'Van in accident repair; standby vehicle allocation pending'),
    ('PDC-MNP-01','ppe_incomplete','restock_process_gap','reissue_ppe','open','internal_only','2026-07-23',null,3500.00,'Missing critical PPE for sterilizer job; reissue from central store')
  ) as q(ref, fc, rc, ca, cs, ri, tcd, acd, cost, nt)
  join public.tool_kit_readiness_r3168 e
    on e.organization_id = v_org_id and e.dispatch_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Dispatch verdict distribution
create or replace function public.founder_r3168_dispatch_verdict_rollup()
returns table(dispatch_verdict text, checks bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tool_kit_readiness_r3168)
  select l.dispatch_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.tool_kit_readiness_r3168 l
  group by l.dispatch_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3168_dispatch_verdict_rollup() from public, anon;
grant execute on function public.founder_r3168_dispatch_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3168_hospital_scorecard()
returns table(
  destination_hospital_name text,
  total_checks bigint,
  cleared bigint,
  conditional bigint,
  hold_blocked bigint,
  stood_down bigint,
  avg_readiness_score numeric,
  clearance_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.destination_hospital_name,
    count(*)::bigint,
    count(*) filter (where l.dispatch_verdict = 'cleared_for_dispatch')::bigint,
    count(*) filter (where l.dispatch_verdict = 'conditional_dispatch')::bigint,
    count(*) filter (where l.dispatch_verdict in ('hold_pending_fix','blocked'))::bigint,
    count(*) filter (where l.dispatch_verdict = 'stood_down')::bigint,
    round(avg(l.readiness_score), 1),
    round(100.0 * count(*) filter (where l.dispatch_verdict = 'cleared_for_dispatch')::numeric / nullif(count(*),0), 1)
  from public.tool_kit_readiness_r3168 l
  group by l.destination_hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3168_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3168_hospital_scorecard() to authenticated;

-- 3) Kit-category readiness matrix
create or replace function public.founder_r3168_kit_category_matrix()
returns table(
  kit_category text,
  checks bigint,
  cleared bigint,
  avg_readiness_score numeric,
  avg_expected_items numeric,
  avg_present_items numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.kit_category, count(*)::bigint,
    count(*) filter (where l.dispatch_verdict = 'cleared_for_dispatch')::bigint,
    round(avg(l.readiness_score), 1),
    round(avg(l.expected_item_count), 1),
    round(avg(l.present_item_count), 1)
  from public.tool_kit_readiness_r3168 l
  group by l.kit_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3168_kit_category_matrix() from public, anon;
grant execute on function public.founder_r3168_kit_category_matrix() to authenticated;

-- 4) Readiness daily trend
create or replace function public.founder_r3168_readiness_daily_trend()
returns table(
  check_date date,
  checks bigint,
  cleared bigint,
  conditional bigint,
  hold_blocked bigint,
  avg_readiness_score numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.check_date,
    count(*)::bigint,
    count(*) filter (where l.dispatch_verdict = 'cleared_for_dispatch')::bigint,
    count(*) filter (where l.dispatch_verdict = 'conditional_dispatch')::bigint,
    count(*) filter (where l.dispatch_verdict in ('hold_pending_fix','blocked'))::bigint,
    round(avg(l.readiness_score), 1)
  from public.tool_kit_readiness_r3168 l
  group by l.check_date
  order by l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3168_readiness_daily_trend() from public, anon;
grant execute on function public.founder_r3168_readiness_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3168_capa_status_board()
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
  from public.tool_kit_readiness_capa_actions_r3168 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3168_capa_status_board() from public, anon;
grant execute on function public.founder_r3168_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3168_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.tool_kit_readiness_capa_actions_r3168)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.tool_kit_readiness_capa_actions_r3168 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3168_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3168_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3168_regulatory_impact_digest()
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
  from public.tool_kit_readiness_capa_actions_r3168 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3168_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3168_regulatory_impact_digest() to authenticated;

-- 8) Priority / high-risk dispatch queue
create or replace function public.founder_r3168_priority_dispatch_queue()
returns table(
  destination_hospital_name text,
  engineer_name text,
  dispatch_ref text,
  kit_category text,
  check_date date,
  dispatch_verdict text,
  calibrated_tool_status text,
  ppe_status text,
  spare_stock_status text,
  fuel_vehicle_status text,
  readiness_score numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.destination_hospital_name, l.engineer_name, l.dispatch_ref, l.kit_category, l.check_date,
    l.dispatch_verdict, l.calibrated_tool_status, l.ppe_status, l.spare_stock_status,
    l.fuel_vehicle_status, l.readiness_score, l.notes
  from public.tool_kit_readiness_r3168 l
  where l.dispatch_verdict in ('hold_pending_fix','blocked','rechecking','stood_down')
     or l.readiness_score < 75
     or l.calibrated_tool_status in ('one_expired','multiple_expired','calibration_cert_missing')
     or l.ppe_status in ('missing_critical','expired_items')
     or l.spare_stock_status in ('critical_shortfall','wrong_parts_loaded')
     or l.fuel_vehicle_status in ('breakdown_risk','vehicle_unavailable')
  order by l.readiness_score asc, l.check_date desc;
end;
$$;

revoke execute on function public.founder_r3168_priority_dispatch_queue() from public, anon;
grant execute on function public.founder_r3168_priority_dispatch_queue() to authenticated;
