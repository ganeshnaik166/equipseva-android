-- Round 3187: Customer Hospital Emergency-Trolley (Crash-Cart) Readiness & Restock Audit
-- Crash-cart audit — location × seal × drug-expiry × defib × suction × airway kit × O2 level × checklist × restock TAT × CAPA

-- =============================================================================
-- TABLE 1: crash_cart_r3187 — individual crash-cart readiness audits
-- =============================================================================
create table if not exists public.crash_cart_r3187 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  ward_name text not null,
  cart_code text not null,
  audit_date date not null,
  audited_at timestamptz not null,
  cart_location text not null check (cart_location in (
    'icu','picu','nicu','emergency_room','operation_theatre',
    'general_ward','cath_lab','dialysis_unit','recovery_room'
  )),
  seal_status text not null check (seal_status in (
    'intact','broken_documented','broken_undocumented','missing','tampered'
  )),
  drug_expiry_nearest_days int not null,
  defib_status text not null check (defib_status in (
    'charged_ready','charging','battery_low','battery_dead','failed_self_test','not_present'
  )),
  suction_status text not null check (suction_status in (
    'working','weak_vacuum','not_working','missing_tubing','not_present'
  )),
  airway_kit_status text not null check (airway_kit_status in (
    'complete','missing_items','expired_items','not_present'
  )),
  o2_cylinder_level text not null check (o2_cylinder_level in (
    'full','three_quarter','half','quarter','near_empty','empty','missing'
  )),
  checklist_signed boolean not null default false,
  last_restock_tat_hours numeric(6,2),
  auditor_profile_id uuid references public.profiles(id) on delete set null,
  readiness_verdict text not null check (readiness_verdict in (
    'fully_ready','ready_with_observations','restock_required','critical_gap','out_of_service','pending_review'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crash_cart_r3187 enable row level security;

create index if not exists idx_crash_cart_r3187_org on public.crash_cart_r3187(organization_id);
create index if not exists idx_crash_cart_r3187_date on public.crash_cart_r3187(audit_date);
create index if not exists idx_crash_cart_r3187_verdict on public.crash_cart_r3187(readiness_verdict);

-- =============================================================================
-- TABLE 2: crash_cart_capa_actions_r3187 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.crash_cart_capa_actions_r3187 (
  id uuid primary key default gen_random_uuid(),
  crash_cart_id uuid not null references public.crash_cart_r3187(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'expired_drug','seal_breach','defib_battery','suction_failure','airway_kit_gap',
    'o2_cylinder_low','checklist_lapse','restock_delay','documentation_gap','equipment_missing'
  )),
  root_cause text not null check (root_cause in (
    'pharmacy_supply_delay','nursing_workload','battery_end_of_life',
    'biomedical_pm_backlog','vendor_stockout','process_noncompliance',
    'training_gap','par_level_wrong','store_indent_delay','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'replace_expired_drugs','reseal_and_log','replace_defib_battery',
    'service_suction_unit','replenish_airway_kit','swap_o2_cylinder',
    'retrain_nursing_staff','revise_par_levels','schedule_biomedical_visit','none_required'
  )),
  responsible_engineer_id uuid references public.engineers(id) on delete set null,
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'nabh_finding','patient_safety_alert','code_blue_readiness_risk','iso_13485_deviation','internal_only','none'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.crash_cart_capa_actions_r3187 enable row level security;

create index if not exists idx_crash_cart_capa_r3187_cart on public.crash_cart_capa_actions_r3187(crash_cart_id);
create index if not exists idx_crash_cart_capa_r3187_status on public.crash_cart_capa_actions_r3187(capa_status);

-- =============================================================================
-- SEED DATA — reference first organization only (per rule 8)
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 13 crash-cart audit rows
  insert into public.crash_cart_r3187 (
    organization_id, hospital_name, ward_name, cart_code, audit_date, audited_at,
    cart_location, seal_status, drug_expiry_nearest_days, defib_status,
    suction_status, airway_kit_status, o2_cylinder_level, checklist_signed,
    last_restock_tat_hours, readiness_verdict, notes
  )
  select v_org_id, q.hosp, q.ward, q.cart, q.ad::date, q.ats::timestamptz,
    q.loc, q.seal, q.ded, q.defib,
    q.suc, q.awy, q.o2, q.cs,
    q.tat, q.rv, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','ICU-A','CC-APL-001','2026-07-14','2026-07-14 07:30:00+05:30',
     'icu','intact',92,'charged_ready','working','complete','full',true,4.50,'fully_ready','Model crash cart — all par levels met'),
    ('Apollo Hyderabad Jubilee Hills','ER Bay 2','CC-APL-002','2026-07-14','2026-07-14 08:10:00+05:30',
     'emergency_room','intact',12,'charged_ready','working','complete','three_quarter',true,6.00,'ready_with_observations','Adrenaline batch expires in 12 days — reorder placed'),
    ('Fortis Bannerghatta Bengaluru','MICU','CC-FRT-003','2026-07-13','2026-07-13 06:45:00+05:30',
     'icu','broken_undocumented',45,'charged_ready','working','missing_items','half',false,26.00,'restock_required','Seal broken without register entry — two oral airways missing'),
    ('Fortis Bannerghatta Bengaluru','Cath Lab','CC-FRT-004','2026-07-13','2026-07-13 07:20:00+05:30',
     'cath_lab','intact',3,'battery_low','working','complete','full',true,8.25,'critical_gap','Atropine expires in 3 days and defib battery at 40 percent'),
    ('Manipal Whitefield Bengaluru','SICU','CC-MNP-005','2026-07-13','2026-07-13 09:00:00+05:30',
     'icu','intact',60,'charged_ready','weak_vacuum','complete','full',true,5.75,'ready_with_observations','Suction vacuum 220 mmHg vs 300 spec — service logged'),
    ('Manipal Whitefield Bengaluru','General Ward 4B','CC-MNP-006','2026-07-12','2026-07-12 10:30:00+05:30',
     'general_ward','missing',30,'charged_ready','working','expired_items','quarter',false,52.00,'critical_gap','Seal missing, expired ET tubes, O2 at quarter'),
    ('AIIMS New Delhi Ansari Nagar','Emergency Red Zone','CC-AIM-007','2026-07-12','2026-07-12 06:15:00+05:30',
     'emergency_room','intact',120,'charged_ready','working','complete','full',true,3.00,'fully_ready','Fastest restock TAT in network'),
    ('AIIMS New Delhi Ansari Nagar','NICU','CC-AIM-008','2026-07-12','2026-07-12 07:00:00+05:30',
     'nicu','intact',75,'failed_self_test','working','complete','full',true,4.00,'out_of_service','Defib failed self-test — paediatric pads circuit error'),
    ('KIMS Secunderabad','Dialysis Unit','CC-KIM-009','2026-07-11','2026-07-11 08:40:00+05:30',
     'dialysis_unit','broken_documented',40,'charged_ready','working','complete','half',true,18.50,'ready_with_observations','Seal opened for code blue — restock done, O2 swap pending'),
    ('Care Hospitals Banjara Hills','OT Recovery','CC-CAR-010','2026-07-11','2026-07-11 09:30:00+05:30',
     'recovery_room','intact',8,'charging','working','complete','three_quarter',true,7.00,'restock_required','Two lignocaine vials within 8 days of expiry'),
    ('Yashoda Somajiguda Hyderabad','OT-2','CC-YSH-011','2026-07-10','2026-07-10 07:45:00+05:30',
     'operation_theatre','intact',55,'charged_ready','working','complete','full',true,5.00,'fully_ready','Routine weekly audit clear'),
    ('St John''s Bengaluru','Emergency Triage','CC-STJ-012','2026-07-10','2026-07-10 06:30:00+05:30',
     'emergency_room','tampered',25,'charged_ready','not_working','missing_items','near_empty',false,60.00,'critical_gap','Suction motor dead and O2 near empty — cart pulled from service'),
    ('Rainbow Children''s Hyderabad','PICU','CC-RBW-013','2026-07-09','2026-07-09 08:00:00+05:30',
     'picu','intact',15,'battery_dead','working','complete','full',false,9.00,'pending_review','Defib battery dead on paediatric cart — spare fitted, review pending')
  ) as q(hosp, ward, cart, ad, ats, loc, seal, ded, defib, suc, awy, o2, cs, tat, rv, nt);

  -- CAPA seed — attach to specific carts
  insert into public.crash_cart_capa_actions_r3187 (
    crash_cart_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.st, q.ri, q.cost, q.nt
  from (values
    ('CC-FRT-003','seal_breach','process_noncompliance','reseal_and_log','2026-07-16',null,'in_progress','nabh_finding',1500.00,'Nurse in-charge counselled; missing airways replenished'),
    ('CC-FRT-004','defib_battery','battery_end_of_life','replace_defib_battery','2026-07-15','2026-07-14','closed','patient_safety_alert',38000.00,'New battery fitted and self-test passed'),
    ('CC-MNP-005','suction_failure','biomedical_pm_backlog','service_suction_unit','2026-07-18',null,'verification_pending','internal_only',6500.00,'Vacuum rebuilt to 320 mmHg — verification audit due'),
    ('CC-MNP-006','expired_drug','pharmacy_supply_delay','replace_expired_drugs','2026-07-14',null,'overdue','code_blue_readiness_risk',9200.00,'ET tubes and expired vials awaiting pharmacy indent'),
    ('CC-AIM-008','defib_battery','battery_end_of_life','schedule_biomedical_visit','2026-07-20',null,'escalated','patient_safety_alert',52000.00,'Paediatric defib module sent to OEM — loaner requested'),
    ('CC-STJ-012','o2_cylinder_low','vendor_stockout','swap_o2_cylinder','2026-07-12',null,'open','code_blue_readiness_risk',2800.00,'Type-D cylinder vendor stockout — borrowing from central store')
  ) as q(cart_key, fc, rc, ca, tcd, acd, st, ri, cost, nt)
  join public.crash_cart_r3187 e
    on e.organization_id = v_org_id and e.cart_code = q.cart_key;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Readiness verdict distribution
create or replace function public.founder_r3187_readiness_verdict_rollup()
returns table(readiness_verdict text, carts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crash_cart_r3187)
  select l.readiness_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.crash_cart_r3187 l
  group by l.readiness_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3187_readiness_verdict_rollup() from public, anon;
grant execute on function public.founder_r3187_readiness_verdict_rollup() to authenticated;

-- 2) Hospital-level readiness scorecard
create or replace function public.founder_r3187_hospital_scorecard()
returns table(
  hospital_name text,
  total_audits bigint,
  fully_ready bigint,
  restock_required bigint,
  critical_gaps bigint,
  out_of_service bigint,
  seal_issues bigint,
  defib_issues bigint,
  checklist_signed_pct numeric,
  readiness_pct numeric
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
    count(*) filter (where l.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where l.readiness_verdict = 'restock_required')::bigint,
    count(*) filter (where l.readiness_verdict = 'critical_gap')::bigint,
    count(*) filter (where l.readiness_verdict = 'out_of_service')::bigint,
    count(*) filter (where l.seal_status in ('broken_undocumented','missing','tampered'))::bigint,
    count(*) filter (where l.defib_status in ('battery_low','battery_dead','failed_self_test','not_present'))::bigint,
    round(100.0 * count(*) filter (where l.checklist_signed)::numeric / nullif(count(*),0), 1),
    round(100.0 * count(*) filter (where l.readiness_verdict in ('fully_ready','ready_with_observations'))::numeric / nullif(count(*),0), 1)
  from public.crash_cart_r3187 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3187_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3187_hospital_scorecard() to authenticated;

-- 3) Cart-location readiness matrix
create or replace function public.founder_r3187_location_matrix()
returns table(
  cart_location text,
  audits bigint,
  fully_ready bigint,
  critical_gaps bigint,
  avg_drug_expiry_days numeric,
  avg_restock_tat_hours numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cart_location, count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where l.readiness_verdict in ('critical_gap','out_of_service'))::bigint,
    round(avg(l.drug_expiry_nearest_days), 1),
    round(avg(l.last_restock_tat_hours), 2)
  from public.crash_cart_r3187 l
  group by l.cart_location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3187_location_matrix() from public, anon;
grant execute on function public.founder_r3187_location_matrix() to authenticated;

-- 4) Daily audit trend
create or replace function public.founder_r3187_daily_trend()
returns table(
  audit_date date,
  audits bigint,
  fully_ready bigint,
  critical_gaps bigint,
  seal_intact bigint,
  checklist_signed bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.audit_date,
    count(*)::bigint,
    count(*) filter (where l.readiness_verdict = 'fully_ready')::bigint,
    count(*) filter (where l.readiness_verdict in ('critical_gap','out_of_service'))::bigint,
    count(*) filter (where l.seal_status = 'intact')::bigint,
    count(*) filter (where l.checklist_signed)::bigint
  from public.crash_cart_r3187 l
  group by l.audit_date
  order by l.audit_date desc;
end;
$$;

revoke execute on function public.founder_r3187_daily_trend() from public, anon;
grant execute on function public.founder_r3187_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3187_capa_status_board()
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
  from public.crash_cart_capa_actions_r3187 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3187_capa_status_board() from public, anon;
grant execute on function public.founder_r3187_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3187_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.crash_cart_capa_actions_r3187)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.crash_cart_capa_actions_r3187 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3187_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3187_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3187_regulatory_impact_digest()
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
  from public.crash_cart_capa_actions_r3187 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3187_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3187_regulatory_impact_digest() to authenticated;

-- 8) High-risk carts queue (top individual concerns)
create or replace function public.founder_r3187_high_risk_carts()
returns table(
  hospital_name text,
  ward_name text,
  cart_code text,
  audit_date date,
  readiness_verdict text,
  seal_status text,
  defib_status text,
  suction_status text,
  o2_cylinder_level text,
  drug_expiry_nearest_days int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.ward_name, l.cart_code, l.audit_date,
    l.readiness_verdict, l.seal_status, l.defib_status, l.suction_status,
    l.o2_cylinder_level, l.drug_expiry_nearest_days, l.notes
  from public.crash_cart_r3187 l
  where l.readiness_verdict in ('restock_required','critical_gap','out_of_service','pending_review')
     or l.seal_status in ('broken_undocumented','missing','tampered')
     or l.defib_status in ('battery_low','battery_dead','failed_self_test','not_present')
     or l.suction_status in ('not_working','not_present')
     or l.o2_cylinder_level in ('near_empty','empty','missing')
     or l.drug_expiry_nearest_days <= 15
  order by l.audit_date desc, l.hospital_name;
end;
$$;

revoke execute on function public.founder_r3187_high_risk_carts() from public, anon;
grant execute on function public.founder_r3187_high_risk_carts() to authenticated;
