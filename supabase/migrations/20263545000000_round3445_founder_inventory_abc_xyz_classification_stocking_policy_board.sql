-- Round 3445: Founder Inventory ABC-XYZ Classification / Stocking-Policy Board
-- Spare-parts inventory ABC (annual value) x XYZ (demand variability) classification + stocking-policy
-- alignment — part x category x abc-class x xyz-class x annual value x demand CV x stock/reorder/safety
-- x stocking policy x policy alignment x turns x CAPA closure

-- =============================================================================
-- TABLE 1: abc_xyz_inventory_policy_r3445 — per-part ABC/XYZ classification & stocking policy
-- =============================================================================
create table if not exists public.abc_xyz_inventory_policy_r3445 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  part_name text not null,
  part_code text not null,
  category text not null,
  abc_class text not null check (abc_class in ('A','B','C')),
  xyz_class text not null check (xyz_class in ('X','Y','Z')),
  annual_consumption_value_rupees numeric(14,2) not null,
  demand_cv_pct numeric(6,2),
  current_stock_qty int not null,
  reorder_point int not null,
  safety_stock int not null,
  stocking_policy text not null check (stocking_policy in (
    'tight_jit','moderate_buffer','high_buffer','make_to_order','review_obsolete'
  )),
  policy_alignment text not null check (policy_alignment in (
    'aligned','over_stocked','under_stocked','mismatched'
  )),
  turns_per_year numeric(6,2),
  review_date date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.abc_xyz_inventory_policy_r3445 enable row level security;

create index if not exists idx_abc_xyz_inv_policy_r3445_org on public.abc_xyz_inventory_policy_r3445(organization_id);
create index if not exists idx_abc_xyz_inv_policy_r3445_date on public.abc_xyz_inventory_policy_r3445(review_date);
create index if not exists idx_abc_xyz_inv_policy_r3445_align on public.abc_xyz_inventory_policy_r3445(policy_alignment);

-- =============================================================================
-- TABLE 2: abc_xyz_inventory_policy_capa_actions_r3445 — CAPA & stocking-policy corrective actions
-- =============================================================================
create table if not exists public.abc_xyz_inventory_policy_capa_actions_r3445 (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.abc_xyz_inventory_policy_r3445(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'excess_stock_capital_locked','stockout_risk','obsolete_inventory','misclassified_abc',
    'misclassified_xyz','policy_mismatch','reorder_point_wrong','safety_stock_inadequate',
    'low_inventory_turns','demand_variability_unmanaged'
  )),
  root_cause text not null check (root_cause in (
    'demand_forecast_error','lead_time_variability','supplier_moq_constraint','manual_classification_error',
    'no_periodic_review','erp_data_error','engineering_change_obsolescence','bulk_purchase_discount_overbuy',
    'pending_investigation','consumption_pattern_shift'
  )),
  corrective_action text not null check (corrective_action in (
    'reduce_reorder_point','increase_safety_stock','switch_to_jit','switch_to_make_to_order',
    'reclassify_part','liquidate_obsolete_stock','renegotiate_supplier_moq','implement_periodic_review',
    'correct_erp_master_data','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'working_capital_high','service_level_risk','write_off_required','audit_finding','none','internal_only'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(14,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.abc_xyz_inventory_policy_capa_actions_r3445 enable row level security;

create index if not exists idx_abc_xyz_inv_capa_r3445_policy on public.abc_xyz_inventory_policy_capa_actions_r3445(policy_id);
create index if not exists idx_abc_xyz_inv_capa_r3445_status on public.abc_xyz_inventory_policy_capa_actions_r3445(capa_status);

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

  -- 16 inventory classification rows
  insert into public.abc_xyz_inventory_policy_r3445 (
    organization_id, part_name, part_code, category, abc_class, xyz_class,
    annual_consumption_value_rupees, demand_cv_pct, current_stock_qty, reorder_point, safety_stock,
    stocking_policy, policy_alignment, turns_per_year, review_date, notes
  )
  select v_org_id, q.pname, q.pcode, q.cat, q.abc, q.xyz,
    q.acv, q.cv, q.cstock, q.rop, q.ss,
    q.policy, q.align, q.turns, q.rdate::date, q.nt
  from (values
    ('X-ray Tube Assembly','XRT-GE-001','imaging','A','X',
     4500000,8.5,3,2,1,'tight_jit','aligned',6.2,'2026-07-05','GE X-ray tube — high value, stable demand, JIT aligned'),
    ('CT Gantry Slip Ring','CT-SLR-002','imaging','A','Y',
     2800000,22.0,4,2,2,'moderate_buffer','aligned',4.1,'2026-07-05','CT slip ring — moderate variability, buffer appropriate'),
    ('MRI Gradient Coil','MRI-GRC-003','imaging','A','Z',
     6200000,48.0,2,1,1,'make_to_order','over_stocked',1.8,'2026-07-04','MRI coil overstocked vs erratic demand — capital locked'),
    ('Ventilator Flow Sensor','VNT-FLS-011','respiratory','B','X',
     380000,6.0,40,25,12,'moderate_buffer','aligned',9.5,'2026-07-04','Ventilator flow sensor — steady consumables demand'),
    ('Ventilator O2 Cell','VNT-O2C-012','respiratory','B','Y',
     260000,28.0,60,30,15,'high_buffer','over_stocked',3.2,'2026-07-03','O2 cells overstocked — buffer too high for turns'),
    ('Dialyzer Membrane','DLY-MEM-021','renal','A','X',
     3200000,9.0,500,300,150,'tight_jit','aligned',12.5,'2026-07-03','Dialyzer membranes — high turns, JIT aligned'),
    ('Dialysis Bloodline Set','DLY-BLS-022','renal','B','X',
     420000,7.0,800,500,200,'moderate_buffer','under_stocked',8.8,'2026-06-20','Bloodline sets running below reorder — stockout risk'),
    ('Infusion Pump Battery','INF-BAT-031','critical_care','C','Z',
     45000,55.0,120,20,10,'review_obsolete','over_stocked',0.9,'2026-06-20','Legacy pump batteries — obsolete, low turns, write-off candidate'),
    ('Patient Monitor SpO2 Probe','MON-SPO-032','monitoring','B','X',
     310000,11.0,90,60,30,'moderate_buffer','aligned',7.4,'2026-06-18','SpO2 probes — stable demand, buffer aligned'),
    ('ECG Electrode Cable','MON-ECG-033','monitoring','C','X',
     68000,5.0,200,120,60,'tight_jit','aligned',10.2,'2026-06-18','ECG cables — low value high volume, JIT works'),
    ('Defibrillator Battery Pack','CRT-DFB-041','critical_care','B','Y',
     240000,26.0,30,18,9,'moderate_buffer','mismatched',4.6,'2026-06-15','Defib batteries — ABC/XYZ mismatch vs applied policy'),
    ('Anesthesia Vaporizer Seal Kit','ANS-VAP-042','anesthesia','C','Y',
     52000,33.0,40,15,8,'high_buffer','over_stocked',2.1,'2026-05-22','Vaporizer seals overstocked — buffer excessive for class'),
    ('Ultrasound Transducer Probe','USG-TRD-051','imaging','A','Y',
     1850000,19.0,6,3,2,'moderate_buffer','aligned',5.5,'2026-05-22','Ultrasound probe — high value, moderate buffer aligned'),
    ('Surgical Cautery Handpiece','SRG-CTR-052','surgical','C','X',
     88000,8.0,150,90,45,'tight_jit','aligned',11.0,'2026-05-20','Cautery handpieces — steady, JIT aligned'),
    ('Autoclave Door Gasket','CSD-AUT-061','sterilization','C','Z',
     34000,62.0,80,10,5,'review_obsolete','over_stocked',0.6,'2026-05-20','Autoclave gaskets — very low turns, review for obsolescence'),
    ('Endoscope Light Guide Bundle','END-LGB-071','endoscopy','A','Z',
     2400000,44.0,3,2,1,'make_to_order','under_stocked',2.4,'2026-05-18','Endoscope light guide — high value erratic, below reorder')
  ) as q(pname, pcode, cat, abc, xyz, acv, cv, cstock, rop, ss, policy, align, turns, rdate, nt);

  -- CAPA seed — attach to specific parts via part_code
  insert into public.abc_xyz_inventory_policy_capa_actions_r3445 (
    policy_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.tcd::date, q.acd::date,
    q.cost, q.own, q.nt
  from (values
    ('MRI-GRC-003','excess_stock_capital_locked','demand_forecast_error','switch_to_make_to_order','in_progress','working_capital_high','2026-07-20',null,6200000.00,'Stores Manager','MRI coil moved to make-to-order — surplus unit to be returned to OEM'),
    ('DLY-BLS-022','stockout_risk','supplier_moq_constraint','increase_safety_stock','open','service_level_risk','2026-07-15',null,42000.00,'Renal Unit Lead','Bloodline safety stock raised; alt vendor with lower MOQ sourced'),
    ('INF-BAT-031','obsolete_inventory','engineering_change_obsolescence','liquidate_obsolete_stock','closed','write_off_required','2026-07-10','2026-07-08',45000.00,'Biomed Engineer','Legacy pump batteries written off; new-model batteries stocked'),
    ('CRT-DFB-041','policy_mismatch','manual_classification_error','reclassify_part','verification_pending','internal_only','2026-07-18',null,12000.00,'Inventory Analyst','Defib battery reclassified B/Y — verify policy next review'),
    ('CSD-AUT-061','obsolete_inventory','no_periodic_review','liquidate_obsolete_stock','escalated','write_off_required','2026-07-12',null,34000.00,'Stores Manager','Autoclave gaskets flagged obsolete — escalated for disposal approval'),
    ('END-LGB-071','stockout_risk','lead_time_variability','increase_safety_stock','open','service_level_risk','2026-07-22',null,96000.00,'Endoscopy Lead','High-value light guide below reorder — expedite PO, raise safety stock'),
    ('VNT-O2C-012','excess_stock_capital_locked','demand_forecast_error','reduce_reorder_point','in_progress','working_capital_high','2026-07-16',null,26000.00,'Respiratory Lead','O2 cell reorder point lowered to free working capital'),
    ('ANS-VAP-042','excess_stock_capital_locked','no_periodic_review','switch_to_jit','overdue','working_capital_high','2026-07-05',null,15000.00,'Inventory Analyst','Vaporizer seals — JIT switch overdue, vendor lead time pending')
  ) as q(pcode, fc, rc, ca, cst, bi, tcd, acd, cost, own, nt)
  join public.abc_xyz_inventory_policy_r3445 e
    on e.organization_id = v_org_id and e.part_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Policy-alignment distribution
create or replace function public.founder_r3445_policy_alignment_rollup()
returns table(policy_alignment text, parts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.abc_xyz_inventory_policy_r3445)
  select l.policy_alignment, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.abc_xyz_inventory_policy_r3445 l
  group by l.policy_alignment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3445_policy_alignment_rollup() from public, anon;
grant execute on function public.founder_r3445_policy_alignment_rollup() to authenticated;

-- 2) ABC-class scorecard
create or replace function public.founder_r3445_abc_class_scorecard()
returns table(
  abc_class text,
  parts bigint,
  aligned bigint,
  over_stocked bigint,
  under_stocked bigint,
  mismatched bigint,
  total_annual_value_rupees numeric,
  avg_turns numeric,
  aligned_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.abc_class,
    count(*)::bigint,
    count(*) filter (where l.policy_alignment = 'aligned')::bigint,
    count(*) filter (where l.policy_alignment = 'over_stocked')::bigint,
    count(*) filter (where l.policy_alignment = 'under_stocked')::bigint,
    count(*) filter (where l.policy_alignment = 'mismatched')::bigint,
    coalesce(sum(l.annual_consumption_value_rupees),0)::numeric,
    round(avg(l.turns_per_year), 2),
    round(100.0 * count(*) filter (where l.policy_alignment = 'aligned')::numeric / nullif(count(*),0), 1)
  from public.abc_xyz_inventory_policy_r3445 l
  group by l.abc_class
  order by l.abc_class;
end;
$$;

revoke execute on function public.founder_r3445_abc_class_scorecard() from public, anon;
grant execute on function public.founder_r3445_abc_class_scorecard() to authenticated;

-- 3) ABC-class x XYZ-class matrix
create or replace function public.founder_r3445_abc_xyz_matrix()
returns table(
  abc_class text,
  xyz_class text,
  parts bigint,
  aligned bigint,
  mismatched bigint,
  total_annual_value_rupees numeric,
  avg_demand_cv_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.abc_class, l.xyz_class, count(*)::bigint,
    count(*) filter (where l.policy_alignment = 'aligned')::bigint,
    count(*) filter (where l.policy_alignment in ('mismatched','over_stocked','under_stocked'))::bigint,
    coalesce(sum(l.annual_consumption_value_rupees),0)::numeric,
    round(avg(l.demand_cv_pct), 1)
  from public.abc_xyz_inventory_policy_r3445 l
  group by l.abc_class, l.xyz_class
  order by l.abc_class, l.xyz_class;
end;
$$;

revoke execute on function public.founder_r3445_abc_xyz_matrix() from public, anon;
grant execute on function public.founder_r3445_abc_xyz_matrix() to authenticated;

-- 4) Monthly value / turns trend
create or replace function public.founder_r3445_monthly_value_trend()
returns table(
  review_month date,
  parts bigint,
  total_annual_value_rupees numeric,
  avg_turns numeric,
  misaligned bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.review_date::timestamp)::date,
    count(*)::bigint,
    coalesce(sum(l.annual_consumption_value_rupees),0)::numeric,
    round(avg(l.turns_per_year), 2),
    count(*) filter (where l.policy_alignment <> 'aligned')::bigint
  from public.abc_xyz_inventory_policy_r3445 l
  group by date_trunc('month', l.review_date::timestamp)
  order by date_trunc('month', l.review_date::timestamp) desc;
end;
$$;

revoke execute on function public.founder_r3445_monthly_value_trend() from public, anon;
grant execute on function public.founder_r3445_monthly_value_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3445_capa_status_board()
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
  from public.abc_xyz_inventory_policy_capa_actions_r3445 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3445_capa_status_board() from public, anon;
grant execute on function public.founder_r3445_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3445_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.abc_xyz_inventory_policy_capa_actions_r3445)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.abc_xyz_inventory_policy_capa_actions_r3445 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3445_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3445_root_cause_pareto() to authenticated;

-- 7) Value-impact digest (by business impact)
create or replace function public.founder_r3445_value_impact_digest()
returns table(business_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.business_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.abc_xyz_inventory_policy_capa_actions_r3445 c
  group by c.business_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3445_value_impact_digest() from public, anon;
grant execute on function public.founder_r3445_value_impact_digest() to authenticated;

-- 8) High-risk stocking queue (mismatched / over-under-stocked / low-turns)
create or replace function public.founder_r3445_high_risk_queue()
returns table(
  part_name text,
  part_code text,
  category text,
  abc_class text,
  xyz_class text,
  policy_alignment text,
  stocking_policy text,
  annual_consumption_value_rupees numeric,
  turns_per_year numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.part_name, l.part_code, l.category, l.abc_class, l.xyz_class,
    l.policy_alignment, l.stocking_policy, l.annual_consumption_value_rupees, l.turns_per_year, l.notes
  from public.abc_xyz_inventory_policy_r3445 l
  where l.policy_alignment in ('over_stocked','under_stocked','mismatched')
     or l.turns_per_year < 2.0
     or l.demand_cv_pct >= 40.0
     or l.current_stock_qty < l.reorder_point
  order by l.annual_consumption_value_rupees desc, l.part_name;
end;
$$;

revoke execute on function public.founder_r3445_high_risk_queue() from public, anon;
grant execute on function public.founder_r3445_high_risk_queue() to authenticated;
