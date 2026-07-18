-- Round 3273: Founder Fixed-Asset Register, Depreciation & Capex Governance Board
-- Fixed-asset register — asset class × depreciation method × capitalized cost × accumulated depreciation × net book value × physical verification × insurance × capex approval × asset verdict × CAPA

-- =============================================================================
-- TABLE 1: fixed_asset_register_r3273 — individual fixed-asset records
-- =============================================================================
create table if not exists public.fixed_asset_register_r3273 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_tag text not null,
  asset_class text not null check (asset_class in (
    'test_equipment_calibrators','workshop_tools','it_hardware','office_furniture',
    'vehicles','leasehold_improvements','demo_medical_equipment'
  )),
  description text not null,
  location_city text not null,
  acquisition_date date not null,
  capitalized_cost_rupees numeric(14,2) not null,
  depreciation_method text not null check (depreciation_method in (
    'slm','wdv'
  )),
  useful_life_years int not null,
  accumulated_depreciation_rupees numeric(14,2) not null,
  net_book_value_rupees numeric(14,2) not null,
  physical_verification_status text not null check (physical_verification_status in (
    'verified','not_located','under_repair','disposed_pending'
  )),
  insured boolean not null,
  capex_approval_ref text,
  asset_verdict text not null check (asset_verdict in (
    'in_use_healthy','underutilized','impairment_review','disposal_candidate','not_located_writeoff'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fixed_asset_register_r3273 enable row level security;

create index if not exists idx_fixed_asset_register_r3273_org on public.fixed_asset_register_r3273(organization_id);
create index if not exists idx_fixed_asset_register_r3273_class on public.fixed_asset_register_r3273(asset_class);
create index if not exists idx_fixed_asset_register_r3273_verdict on public.fixed_asset_register_r3273(asset_verdict);

-- =============================================================================
-- TABLE 2: fixed_asset_register_capa_actions_r3273 — CAPA & governance actions
-- =============================================================================
create table if not exists public.fixed_asset_register_capa_actions_r3273 (
  id uuid primary key default gen_random_uuid(),
  asset_log_id uuid not null references public.fixed_asset_register_r3273(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'physical_verification','impairment_review','disposal_action','insurance_gap',
    'capex_approval_gap','depreciation_correction','asset_not_located'
  )),
  root_cause text not null check (root_cause in (
    'asset_relocated_untracked','tag_missing','obsolete_technology','damaged_beyond_repair',
    'no_capex_approval_on_file','insurance_lapsed','depreciation_misposted',
    'pending_investigation','vendor_buyback_pending'
  )),
  corrective_action text not null check (corrective_action in (
    'physical_recount','tag_and_reconcile','impair_and_revalue','initiate_disposal',
    'file_capex_approval','renew_insurance','repost_depreciation','write_off_asset','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  governance_impact text not null check (governance_impact in (
    'statutory_audit_flag','internal_control_gap','none','internal_only',
    'ind_as_impairment','insurance_exposure'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fixed_asset_register_capa_actions_r3273 enable row level security;

create index if not exists idx_fixed_asset_capa_r3273_log on public.fixed_asset_register_capa_actions_r3273(asset_log_id);
create index if not exists idx_fixed_asset_capa_r3273_status on public.fixed_asset_register_capa_actions_r3273(capa_status);

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

  -- 14 fixed-asset rows
  insert into public.fixed_asset_register_r3273 (
    organization_id, asset_tag, asset_class, description, location_city,
    acquisition_date, capitalized_cost_rupees, depreciation_method, useful_life_years,
    accumulated_depreciation_rupees, net_book_value_rupees, physical_verification_status,
    insured, capex_approval_ref, asset_verdict, notes
  )
  select v_org_id, q.tag, q.cls, q.descr, q.city,
    q.acq::date, q.cost::numeric, q.method, q.life::int,
    q.accum::numeric, q.nbv::numeric, q.pvs,
    q.ins, q.capex, q.verdict, q.nt
  from (values
    ('FA-CAL-001','test_equipment_calibrators','Fluke Biomedical ESA615 electrical safety analyzer','Chennai',
     '2023-04-12',385000,'slm',7,137500,247500,'verified',true,'CAPEX-2023-014','in_use_healthy','Primary ESA for South zone — calibrated and tagged'),
    ('FA-CAL-002','test_equipment_calibrators','Fluke ProSim 8 vital-signs simulator','Gurgaon',
     '2022-09-03',295000,'slm',7,148000,147000,'verified',true,'CAPEX-2022-041','in_use_healthy','North zone patient simulator in daily use'),
    ('FA-TOOL-101','workshop_tools','Bosch GWS angle grinder plus calibrated tool cabinet set','Bengaluru',
     '2024-01-20',68000,'wdv',5,21000,47000,'verified',true,'CAPEX-2024-006','in_use_healthy','Bench-repair tool set'),
    ('FA-IT-201','it_hardware','Dell PowerEdge T350 field-ops server','Hyderabad',
     '2023-07-15',240000,'wdv',5,128000,112000,'verified',true,'CAPEX-2023-030','in_use_healthy','Hosts local dispatch cache'),
    ('FA-IT-202','it_hardware','Lenovo ThinkPad fleet of 8 engineer laptops','Chennai',
     '2022-06-10',640000,'wdv',4,512000,128000,'under_repair',true,'CAPEX-2022-022','underutilized','3 of 8 units in repair — utilization low'),
    ('FA-FURN-301','office_furniture','Modular workstations and storage — Chennai HQ fit-out','Chennai',
     '2021-11-05',420000,'slm',10,189000,231000,'verified',false,'CAPEX-2021-055','in_use_healthy','HQ furniture — insurance rider lapsed'),
    ('FA-VEH-401','vehicles','Tata Ace service van — South fleet','Vellore',
     '2021-03-18',780000,'wdv',8,546000,234000,'verified',true,'CAPEX-2021-009','underutilized','Low mileage after 2025 route change'),
    ('FA-VEH-402','vehicles','Mahindra Bolero pickup — North fleet','Gurgaon',
     '2020-08-22',890000,'wdv',8,756500,133500,'not_located',true,'CAPEX-2020-018','not_located_writeoff','Not traced in Q2 physical count — write-off review'),
    ('FA-LHI-501','leasehold_improvements','Delhi depot electrical and HVAC fit-out','Delhi',
     '2022-02-14',560000,'slm',9,217000,343000,'verified',true,'CAPEX-2022-004','in_use_healthy','Depot improvements amortized over lease'),
    ('FA-DEMO-601','demo_medical_equipment','Mindray patient-monitor demo unit','Bengaluru',
     '2023-10-09',310000,'wdv',5,130000,180000,'verified',true,'CAPEX-2023-047','in_use_healthy','Sales demo pool — well utilized'),
    ('FA-DEMO-602','demo_medical_equipment','GE Vscan portable ultrasound demo','Hyderabad',
     '2021-12-01',520000,'wdv',5,468000,52000,'verified',true,'CAPEX-2021-061','impairment_review','Superseded model — impairment review'),
    ('FA-CAL-003','test_equipment_calibrators','Rigel Uni-Sim vital-signs analyzer','Gurgaon',
     '2019-05-30',265000,'slm',7,265000,0,'disposed_pending',false,'CAPEX-2019-012','disposal_candidate','Fully depreciated and obsolete — disposal candidate'),
    ('FA-TOOL-102','workshop_tools','Hydraulic lift table and torque calibration jig','Vellore',
     '2024-05-08',95000,'wdv',5,15000,80000,'verified',true,'CAPEX-2024-021','in_use_healthy','New workshop jig'),
    ('FA-IT-203','it_hardware','Cisco Meraki network stack — Chennai HQ','Chennai',
     '2020-02-11',180000,'wdv',5,171000,9000,'disposed_pending',true,'CAPEX-2020-003','disposal_candidate','EOL network gear — replacement approved, pending e-waste disposal')
  ) as q(tag, cls, descr, city, acq, cost, method, life, accum, nbv, pvs, ins, capex, verdict, nt);

  -- CAPA seed — attach to specific at-risk assets via asset tag
  insert into public.fixed_asset_register_capa_actions_r3273 (
    asset_log_id, finding_category, root_cause, corrective_action,
    capa_status, governance_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.gi, q.tcd::date, q.acd::date,
    q.cost::numeric, q.nt
  from (values
    ('FA-VEH-402','asset_not_located','asset_relocated_untracked','physical_recount','in_progress','statutory_audit_flag','2026-07-25',null,15000,'Van not traced — depot recount and GPS log pull underway'),
    ('FA-FURN-301','insurance_gap','insurance_lapsed','renew_insurance','open','insurance_exposure','2026-07-30',null,22000,'HQ furniture rider lapsed — reinstate under fire policy'),
    ('FA-DEMO-602','impairment_review','obsolete_technology','impair_and_revalue','verification_pending','ind_as_impairment','2026-07-20',null,0,'Vscan superseded — impair NBV to recoverable value'),
    ('FA-CAL-003','disposal_action','obsolete_technology','initiate_disposal','escalated','internal_control_gap','2026-07-15',null,8000,'Obsolete analyzer — board disposal approval pending'),
    ('FA-IT-203','disposal_action','obsolete_technology','initiate_disposal','closed','internal_only','2026-07-05','2026-07-04',6000,'EOL Meraki stack e-waste disposal completed'),
    ('FA-IT-202','physical_verification','damaged_beyond_repair','write_off_asset','overdue','internal_control_gap','2026-06-28',null,12000,'3 laptops beyond economic repair — write-off overdue'),
    ('FA-VEH-401','physical_verification','asset_relocated_untracked','tag_and_reconcile','in_progress','internal_only','2026-07-22',null,3000,'Van re-tag and route reconciliation')
  ) as q(tag, fc, rc, ca, cst, gi, tcd, acd, cost, nt)
  join public.fixed_asset_register_r3273 e
    on e.organization_id = v_org_id and e.asset_tag = q.tag;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Asset verdict distribution
create or replace function public.founder_r3273_asset_verdict_rollup()
returns table(asset_verdict text, assets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fixed_asset_register_r3273)
  select l.asset_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fixed_asset_register_r3273 l
  group by l.asset_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3273_asset_verdict_rollup() from public, anon;
grant execute on function public.founder_r3273_asset_verdict_rollup() to authenticated;

-- 2) Location-level asset scorecard
create or replace function public.founder_r3273_location_scorecard()
returns table(
  location_city text,
  total_assets bigint,
  in_use_healthy bigint,
  underutilized bigint,
  impairment_review bigint,
  disposal_candidate bigint,
  not_located bigint,
  net_book_value_rupees numeric,
  insured_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.location_city,
    count(*)::bigint,
    count(*) filter (where l.asset_verdict = 'in_use_healthy')::bigint,
    count(*) filter (where l.asset_verdict = 'underutilized')::bigint,
    count(*) filter (where l.asset_verdict = 'impairment_review')::bigint,
    count(*) filter (where l.asset_verdict = 'disposal_candidate')::bigint,
    count(*) filter (where l.asset_verdict = 'not_located_writeoff' or l.physical_verification_status = 'not_located')::bigint,
    coalesce(sum(l.net_book_value_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.insured)::numeric / nullif(count(*),0), 1)
  from public.fixed_asset_register_r3273 l
  group by l.location_city
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3273_location_scorecard() from public, anon;
grant execute on function public.founder_r3273_location_scorecard() to authenticated;

-- 3) Asset class × depreciation method matrix
create or replace function public.founder_r3273_class_method_matrix()
returns table(asset_class text, depreciation_method text, assets bigint, capitalized_cost_rupees numeric, net_book_value_rupees numeric, avg_useful_life_years numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_class, l.depreciation_method, count(*)::bigint,
    coalesce(sum(l.capitalized_cost_rupees),0)::numeric,
    coalesce(sum(l.net_book_value_rupees),0)::numeric,
    round(avg(l.useful_life_years), 1)
  from public.fixed_asset_register_r3273 l
  group by l.asset_class, l.depreciation_method
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3273_class_method_matrix() from public, anon;
grant execute on function public.founder_r3273_class_method_matrix() to authenticated;

-- 4) Acquisition-date trend
create or replace function public.founder_r3273_acquisition_trend()
returns table(acquisition_date date, assets bigint, capitalized_cost_rupees numeric, net_book_value_rupees numeric, impairment_review bigint, disposal_candidate bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.acquisition_date,
    count(*)::bigint,
    coalesce(sum(l.capitalized_cost_rupees),0)::numeric,
    coalesce(sum(l.net_book_value_rupees),0)::numeric,
    count(*) filter (where l.asset_verdict = 'impairment_review')::bigint,
    count(*) filter (where l.asset_verdict = 'disposal_candidate')::bigint
  from public.fixed_asset_register_r3273 l
  group by l.acquisition_date
  order by l.acquisition_date desc;
end;
$$;

revoke execute on function public.founder_r3273_acquisition_trend() from public, anon;
grant execute on function public.founder_r3273_acquisition_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3273_capa_status_board()
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
  from public.fixed_asset_register_capa_actions_r3273 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3273_capa_status_board() from public, anon;
grant execute on function public.founder_r3273_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3273_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fixed_asset_register_capa_actions_r3273)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fixed_asset_register_capa_actions_r3273 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3273_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3273_root_cause_pareto() to authenticated;

-- 7) Governance impact digest (cost / risk digest)
create or replace function public.founder_r3273_governance_impact_digest()
returns table(governance_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.governance_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.fixed_asset_register_capa_actions_r3273 c
  group by c.governance_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3273_governance_impact_digest() from public, anon;
grant execute on function public.founder_r3273_governance_impact_digest() to authenticated;

-- 8) High-risk asset queue (top individual concerns)
create or replace function public.founder_r3273_high_risk_queue()
returns table(
  asset_tag text,
  asset_class text,
  location_city text,
  acquisition_date date,
  net_book_value_rupees numeric,
  physical_verification_status text,
  insured boolean,
  asset_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_tag, l.asset_class, l.location_city, l.acquisition_date,
    l.net_book_value_rupees, l.physical_verification_status, l.insured,
    l.asset_verdict, l.notes
  from public.fixed_asset_register_r3273 l
  where l.asset_verdict in ('underutilized','impairment_review','disposal_candidate','not_located_writeoff')
     or l.physical_verification_status in ('not_located','under_repair','disposed_pending')
     or l.insured = false
  order by l.net_book_value_rupees desc, l.asset_tag;
end;
$$;

revoke execute on function public.founder_r3273_high_risk_queue() from public, anon;
grant execute on function public.founder_r3273_high_risk_queue() to authenticated;
