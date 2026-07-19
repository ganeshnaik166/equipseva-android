-- Round 3352: Engineer Inventory Cycle-Count, Physical-Stock Verification & Bin-Location Accuracy Tracker
-- Store/van inventory ops — store location × count type × equipment family × system-vs-physical variance × bin accuracy × root cause × CAPA

-- =============================================================================
-- TABLE 1: inv_cycle_count_r3352 — per cycle-count / physical-verification event
-- =============================================================================
create table if not exists public.inv_cycle_count_r3352 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  store_location text not null check (store_location in (
    'chennai_hub','gurgaon_hub','bengaluru_hub','hyderabad_hub','van_stock_pooled'
  )),
  count_code text not null,
  count_type text not null check (count_type in (
    'abc_cycle_count','full_physical','spot_check','van_reconciliation','high_value_daily'
  )),
  equipment_family text not null check (equipment_family in (
    'patient_monitor','imaging','dialysis','infusion_pump','ventilator','general'
  )),
  count_date date not null,
  skus_counted int not null,
  system_qty int not null,
  physical_qty int not null,
  variance_units int not null,
  variance_value_rupees numeric(14,2) not null,
  bin_location_accuracy_pct numeric(5,2) not null,
  mismatched_skus int not null,
  root_cause text not null check (root_cause in (
    'no_variance','misplacement','unrecorded_issue','theft_shrinkage','receipt_error','system_lag'
  )),
  adjustment_approved boolean not null default false,
  count_verdict text not null check (count_verdict in (
    'accurate','minor_variance','major_variance','investigate_shrinkage','reconcile_system'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inv_cycle_count_r3352 enable row level security;

create index if not exists idx_inv_cycle_count_r3352_org on public.inv_cycle_count_r3352(organization_id);
create index if not exists idx_inv_cycle_count_r3352_date on public.inv_cycle_count_r3352(count_date);
create index if not exists idx_inv_cycle_count_r3352_verdict on public.inv_cycle_count_r3352(count_verdict);

-- =============================================================================
-- TABLE 2: inv_cycle_count_capa_actions_r3352 — CAPA / investigation actions
-- =============================================================================
create table if not exists public.inv_cycle_count_capa_actions_r3352 (
  id uuid primary key default gen_random_uuid(),
  count_log_id uuid not null references public.inv_cycle_count_r3352(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'variance_investigation','bin_relabel','stock_adjustment','shrinkage_probe',
    'receipt_correction','process_retrain','cycle_count_frequency'
  )),
  root_cause text not null check (root_cause in (
    'misplacement','unrecorded_issue','theft_shrinkage','receipt_error',
    'system_lag','pending_investigation','process_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'relocate_and_relabel_bin','post_stock_adjustment','write_off_shrinkage','correct_grn_entry',
    'retrain_store_staff','increase_count_frequency','reconcile_erp','escalate_to_security','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'write_off_required','stock_adjustment_posted','audit_flag','none','shrinkage_provision','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.inv_cycle_count_capa_actions_r3352 enable row level security;

create index if not exists idx_inv_cycle_capa_r3352_log on public.inv_cycle_count_capa_actions_r3352(count_log_id);
create index if not exists idx_inv_cycle_capa_r3352_status on public.inv_cycle_count_capa_actions_r3352(capa_status);

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

  -- 14 cycle-count rows
  insert into public.inv_cycle_count_r3352 (
    organization_id, store_location, count_code, count_type, equipment_family,
    count_date, skus_counted, system_qty, physical_qty, variance_units,
    variance_value_rupees, bin_location_accuracy_pct, mismatched_skus, root_cause,
    adjustment_approved, count_verdict, notes
  )
  select v_org_id, q.loc, q.code, q.ctype, q.fam,
    q.cdate::date, q.skus::int, q.sysq::int, q.physq::int, q.varu::int,
    q.varv::numeric, q.bin::numeric, q.mis::int, q.rc,
    q.adj, q.verdict, q.nt
  from (values
    ('chennai_hub','CC-CHN-2601','abc_cycle_count','patient_monitor','2026-07-14',
     42,138,138,0,0.00,100.00,0,'no_variance',true,'accurate',
     'ABC A-class monitor cycle count — nil variance; counted by storekeeper Ramesh Kumar'),
    ('chennai_hub','CC-CHN-2602','high_value_daily','imaging','2026-07-14',
     12,12,11,-1,-285000.00,91.70,1,'misplacement',true,'minor_variance',
     'One portable ultrasound probe found in wrong bin — relocated, adjustment posted'),
    ('gurgaon_hub','CC-GGN-3101','full_physical','infusion_pump','2026-07-13',
     88,512,498,-14,-168000.00,84.10,9,'receipt_error',false,'major_variance',
     'GRN mismatch on Bharat Medic infusion sets — pending reconciliation'),
    ('gurgaon_hub','CC-GGN-3102','spot_check','ventilator','2026-07-13',
     6,18,18,0,0.00,100.00,0,'no_variance',true,'accurate',
     'Spot check on ICU ventilator loaners — matched'),
    ('bengaluru_hub','CC-BLR-2401','abc_cycle_count','dialysis','2026-07-12',
     34,210,205,-5,-97500.00,88.20,4,'unrecorded_issue',false,'reconcile_system',
     'Dialysis consumables issued to Manipal job not booked in ERP — reconcile'),
    ('bengaluru_hub','CC-BLR-2402','van_reconciliation','general','2026-07-12',
     56,340,331,-9,-41200.00,79.50,7,'misplacement',true,'minor_variance',
     'Van 07 return reconciliation — spares mis-binned, corrected on floor'),
    ('hyderabad_hub','CC-HYD-2201','full_physical','patient_monitor','2026-07-11',
     61,288,271,-17,-510000.00,76.30,12,'theft_shrinkage',false,'investigate_shrinkage',
     'SpO2 modules short by 17 units beyond tolerance — security probe opened'),
    ('hyderabad_hub','CC-HYD-2202','high_value_daily','imaging','2026-07-11',
     9,9,9,0,0.00,100.00,0,'no_variance',true,'accurate',
     'C-arm image intensifier tubes daily high-value count — nil variance'),
    ('van_stock_pooled','CC-VAN-5501','van_reconciliation','infusion_pump','2026-07-10',
     44,176,169,-7,-58800.00,81.80,6,'system_lag',true,'minor_variance',
     'Pooled van stock lag — field-app issues synced late; adjusted'),
    ('van_stock_pooled','CC-VAN-5502','spot_check','general','2026-07-10',
     30,150,143,-7,-22400.00,83.30,5,'misplacement',false,'reconcile_system',
     'Consumables across 3 vans mismatched — reconcile pooled bins'),
    ('chennai_hub','CC-CHN-2603','full_physical','dialysis','2026-07-09',
     52,400,388,-12,-132000.00,82.70,8,'receipt_error',false,'major_variance',
     'RO membrane receipt double-counted at GRN — needs correction'),
    ('gurgaon_hub','CC-GGN-3103','abc_cycle_count','imaging','2026-07-08',
     20,64,62,-2,-390000.00,90.00,2,'misplacement',true,'minor_variance',
     'Two ultrasound transducers sitting in transit bin — relocated'),
    ('bengaluru_hub','CC-BLR-2403','high_value_daily','ventilator','2026-07-08',
     8,24,21,-3,-720000.00,72.50,3,'theft_shrinkage',false,'investigate_shrinkage',
     'Three ICU ventilator flow sensors unaccounted — escalated to security'),
    ('hyderabad_hub','CC-HYD-2203','van_reconciliation','patient_monitor','2026-07-07',
     38,190,190,0,0.00,100.00,0,'no_variance',true,'accurate',
     'Van 12 monitor accessories reconciliation — fully matched')
  ) as q(loc, code, ctype, fam, cdate, skus, sysq, physq, varu, varv, bin, mis, rc, adj, verdict, nt);

  -- CAPA seed — attach to specific counts via count_code
  insert into public.inv_cycle_count_capa_actions_r3352 (
    count_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('CC-GGN-3101','receipt_correction','receipt_error','correct_grn_entry','in_progress','stock_adjustment_posted','2026-07-18',null,12000.00,'GRN corrected for Bharat Medic infusion sets — verifying ERP posting'),
    ('CC-HYD-2201','shrinkage_probe','theft_shrinkage','escalate_to_security','escalated','audit_flag','2026-07-20',null,510000.00,'SpO2 module shortfall — CCTV pull and security investigation, storekeeper Anil Reddy'),
    ('CC-BLR-2401','variance_investigation','unrecorded_issue','reconcile_erp','closed','stock_adjustment_posted','2026-07-15','2026-07-14',97500.00,'Unbooked Manipal issue traced and posted — reconciled'),
    ('CC-CHN-2602','bin_relabel','misplacement','relocate_and_relabel_bin','closed','none','2026-07-16','2026-07-15',3500.00,'Ultrasound probe re-binned and bin labels corrected'),
    ('CC-CHN-2603','receipt_correction','receipt_error','correct_grn_entry','open','stock_adjustment_posted','2026-07-19',null,15000.00,'RO membrane GRN double-count under correction'),
    ('CC-BLR-2403','shrinkage_probe','theft_shrinkage','write_off_shrinkage','overdue','shrinkage_provision','2026-07-12',null,720000.00,'Ventilator flow sensors shrinkage — write-off pending approval, past due'),
    ('CC-VAN-5502','process_retrain','process_gap','increase_count_frequency','verification_pending','internal_only','2026-07-17',null,4000.00,'Van storekeepers retrained; van count frequency raised to weekly')
  ) as q(code, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.inv_cycle_count_r3352 e
    on e.organization_id = v_org_id and e.count_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Count verdict distribution
create or replace function public.founder_r3352_count_verdict_rollup()
returns table(count_verdict text, counts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inv_cycle_count_r3352)
  select l.count_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.inv_cycle_count_r3352 l
  group by l.count_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3352_count_verdict_rollup() from public, anon;
grant execute on function public.founder_r3352_count_verdict_rollup() to authenticated;

-- 2) Store-location scorecard
create or replace function public.founder_r3352_store_scorecard()
returns table(
  store_location text,
  total_counts bigint,
  accurate bigint,
  minor_variance bigint,
  major_variance bigint,
  investigate bigint,
  total_variance_units bigint,
  total_variance_value_rupees numeric,
  avg_bin_accuracy_pct numeric,
  accurate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_location,
    count(*)::bigint,
    count(*) filter (where l.count_verdict = 'accurate')::bigint,
    count(*) filter (where l.count_verdict = 'minor_variance')::bigint,
    count(*) filter (where l.count_verdict = 'major_variance')::bigint,
    count(*) filter (where l.count_verdict in ('investigate_shrinkage','reconcile_system'))::bigint,
    coalesce(sum(l.variance_units),0)::bigint,
    coalesce(sum(l.variance_value_rupees),0)::numeric,
    round(avg(l.bin_location_accuracy_pct), 1),
    round(100.0 * count(*) filter (where l.count_verdict = 'accurate')::numeric / nullif(count(*),0), 1)
  from public.inv_cycle_count_r3352 l
  group by l.store_location
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3352_store_scorecard() from public, anon;
grant execute on function public.founder_r3352_store_scorecard() to authenticated;

-- 3) Store-location × equipment-family matrix
create or replace function public.founder_r3352_location_family_matrix()
returns table(store_location text, equipment_family text, counts bigint, accurate bigint, avg_variance_value_rupees numeric, avg_bin_accuracy_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_location, l.equipment_family, count(*)::bigint,
    count(*) filter (where l.count_verdict = 'accurate')::bigint,
    round(avg(l.variance_value_rupees), 0),
    round(avg(l.bin_location_accuracy_pct), 1)
  from public.inv_cycle_count_r3352 l
  group by l.store_location, l.equipment_family
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3352_location_family_matrix() from public, anon;
grant execute on function public.founder_r3352_location_family_matrix() to authenticated;

-- 4) Daily count trend
create or replace function public.founder_r3352_daily_count_trend()
returns table(count_date date, counts bigint, accurate bigint, major_variance bigint, total_variance_value_rupees numeric, avg_bin_accuracy_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.count_date,
    count(*)::bigint,
    count(*) filter (where l.count_verdict = 'accurate')::bigint,
    count(*) filter (where l.count_verdict in ('major_variance','investigate_shrinkage'))::bigint,
    coalesce(sum(l.variance_value_rupees),0)::numeric,
    round(avg(l.bin_location_accuracy_pct), 1)
  from public.inv_cycle_count_r3352 l
  group by l.count_date
  order by l.count_date desc;
end;
$$;

revoke execute on function public.founder_r3352_daily_count_trend() from public, anon;
grant execute on function public.founder_r3352_daily_count_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3352_capa_status_board()
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
  from public.inv_cycle_count_capa_actions_r3352 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3352_capa_status_board() from public, anon;
grant execute on function public.founder_r3352_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3352_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.inv_cycle_count_capa_actions_r3352)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.inv_cycle_count_capa_actions_r3352 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3352_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3352_root_cause_pareto() to authenticated;

-- 7) Financial impact digest
create or replace function public.founder_r3352_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.inv_cycle_count_capa_actions_r3352 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3352_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3352_financial_impact_digest() to authenticated;

-- 8) High-risk count queue (top individual concerns)
create or replace function public.founder_r3352_high_risk_queue()
returns table(
  store_location text,
  count_code text,
  equipment_family text,
  count_date date,
  count_verdict text,
  variance_units int,
  variance_value_rupees numeric,
  bin_location_accuracy_pct numeric,
  root_cause text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_location, l.count_code, l.equipment_family, l.count_date,
    l.count_verdict, l.variance_units, l.variance_value_rupees, l.bin_location_accuracy_pct,
    l.root_cause, l.notes
  from public.inv_cycle_count_r3352 l
  where l.count_verdict in ('minor_variance','major_variance','investigate_shrinkage','reconcile_system')
     or l.root_cause in ('theft_shrinkage','misplacement','unrecorded_issue','receipt_error','system_lag')
     or l.bin_location_accuracy_pct < 85.0
     or (l.variance_units <> 0 and not l.adjustment_approved)
  order by l.count_date desc, l.store_location;
end;
$$;

revoke execute on function public.founder_r3352_high_risk_queue() from public, anon;
grant execute on function public.founder_r3352_high_risk_queue() to authenticated;
