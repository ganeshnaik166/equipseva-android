-- Round 3501: Founder Capital Work-in-Progress (CWIP) Capitalization / Aging Board
-- CWIP register — project × asset category × CWIP balance × capitalized YTD × spend/budget × aging days × pct complete × capitalization status × expected cap date × trend × CAPA

-- =============================================================================
-- TABLE 1: cwip_capitalization_r3501 — per-project CWIP capitalization & aging
-- =============================================================================
create table if not exists public.cwip_capitalization_r3501 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  cwip_code text not null,
  project_name text not null,
  asset_category text not null check (asset_category in (
    'medical_equipment','it_infrastructure','facility_civil_works','fleet_vehicles',
    'service_tooling','software_platform','leasehold_improvements','biomedical_lab_setup'
  )),
  cwip_balance_rupees numeric(14,2) not null,
  capitalized_ytd_rupees numeric(14,2) not null default 0,
  spend_to_date_rupees numeric(14,2) not null,
  budget_rupees numeric(14,2) not null,
  aging_days int not null,
  pct_complete numeric(5,2),
  capitalization_status text not null check (capitalization_status in (
    'active','ready_to_capitalize','stalled','over_budget','capitalized'
  )),
  expected_cap_date date,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cwip_capitalization_r3501 enable row level security;

create index if not exists idx_cwip_capitalization_r3501_org on public.cwip_capitalization_r3501(organization_id);
create index if not exists idx_cwip_capitalization_r3501_status on public.cwip_capitalization_r3501(capitalization_status);
create index if not exists idx_cwip_capitalization_r3501_cap_date on public.cwip_capitalization_r3501(expected_cap_date);

-- =============================================================================
-- TABLE 2: cwip_capitalization_capa_actions_r3501 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.cwip_capitalization_capa_actions_r3501 (
  id uuid primary key default gen_random_uuid(),
  cwip_id uuid not null references public.cwip_capitalization_r3501(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'stuck_cwip_not_capitalized','over_budget_overrun','commissioning_delay','depreciation_not_started',
    'missing_capitalization_docs','asset_register_mismatch','impairment_indicator','aged_beyond_policy',
    'partial_capitalization_pending','scope_change_pending_approval'
  )),
  root_cause text not null check (root_cause in (
    'vendor_delivery_delay','pending_installation_signoff','commissioning_not_complete',
    'capitalization_policy_ambiguity','asset_not_ready_for_use','budget_overrun_scope_creep',
    'documentation_incomplete','pending_investigation','fixed_asset_register_sync_lag',
    'depreciation_start_date_dispute'
  )),
  corrective_action text not null check (corrective_action in (
    'capitalize_and_start_depreciation','obtain_installation_certificate','complete_commissioning',
    'revise_capex_budget','update_capitalization_policy','impairment_provision','reconcile_asset_register',
    'expedite_vendor_closure','obtain_management_approval','write_off_abandoned_cwip','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  audit_impact text not null check (audit_impact in (
    'ind_as_16_capitalization','depreciation_understated','impairment_review',
    'statutory_audit_qualification','none','internal_only'
  )),
  cwip_balance_at_risk_rupees numeric(14,2),
  estimated_cost_rupees numeric(12,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.cwip_capitalization_capa_actions_r3501 enable row level security;

create index if not exists idx_cwip_capitalization_capa_r3501_cwip on public.cwip_capitalization_capa_actions_r3501(cwip_id);
create index if not exists idx_cwip_capitalization_capa_r3501_status on public.cwip_capitalization_capa_actions_r3501(capa_status);

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

  -- 16 CWIP project rows
  insert into public.cwip_capitalization_r3501 (
    organization_id, cwip_code, project_name, asset_category,
    cwip_balance_rupees, capitalized_ytd_rupees, spend_to_date_rupees, budget_rupees,
    aging_days, pct_complete, capitalization_status, expected_cap_date, trend_dir, notes
  )
  select v_org_id, q.code, q.proj, q.cat,
    q.bal, q.cap_ytd, q.spend, q.budget,
    q.aging, q.pctc, q.status, q.ecd::date, q.trend, q.nt
  from (values
    ('CWIP-2025-001','Cath Lab Angiography Suite - Apollo Chennai','medical_equipment',
     18500000,0,18500000,20000000,95,92.50,'active','2026-09-30','improving','Biplane cath lab install; awaiting AERB layout approval'),
    ('CWIP-2025-002','Hospital HIS/EMR Rollout - Pan India','software_platform',
     9200000,0,9200000,8500000,240,88.00,'over_budget','2026-08-31','worsening','EMR customization overran budget by 8 percent'),
    ('CWIP-2024-014','Biomedical Calibration Lab - Bengaluru','biomedical_lab_setup',
     6400000,0,6400000,6500000,30,100.00,'ready_to_capitalize','2026-08-01','stable','NABL lab commissioned; capitalization docs in review'),
    ('CWIP-2024-009','Central Sterile Services Dept - Fortis Gurgaon','facility_civil_works',
     12800000,0,12800000,12000000,410,70.00,'stalled','2026-12-31','worsening','CSSD civil works stalled; vendor dispute unresolved'),
    ('CWIP-2025-005','MRI 3T Suite - Manipal Whitefield','medical_equipment',
     42000000,0,41500000,45000000,120,90.00,'active','2026-10-15','improving','MRI magnet ramped; RF shielding sign-off pending'),
    ('CWIP-2023-021','Service Fleet EVs - South Zone','fleet_vehicles',
     3200000,3200000,3200000,3000000,15,100.00,'capitalized',null,'stable','Capitalized Apr 2026; depreciation started'),
    ('CWIP-2024-018','Data Center Colocation - Hyderabad','it_infrastructure',
     5600000,0,5600000,6000000,65,85.00,'active','2026-09-10','stable','Rack build 85 pct; UPS commissioning next'),
    ('CWIP-2025-011','Field Service Tooling Kits - National','service_tooling',
     2400000,0,2400000,2200000,180,95.00,'over_budget','2026-08-20','worsening','Calibrated torque tooling costs above plan'),
    ('CWIP-2024-003','OT Modular Upgrade - AIIMS Delhi','leasehold_improvements',
     15200000,0,15200000,16000000,300,60.00,'stalled','2026-11-30','worsening','Modular OT panels stuck at customs; commissioning frozen'),
    ('CWIP-2025-020','Ventilator Refurb Line - Pune','medical_equipment',
     4800000,0,4800000,5000000,45,100.00,'ready_to_capitalize','2026-08-05','improving','Refurb line ready; awaiting installation certificate'),
    ('CWIP-2024-027','CRM / Field App Platform','software_platform',
     3600000,3600000,3600000,3500000,10,100.00,'capitalized',null,'stable','Marketplace + CRM platform capitalized Jun 2026'),
    ('CWIP-2025-008','Warehouse Automation - Nagpur Hub','facility_civil_works',
     7100000,0,7100000,7500000,90,78.00,'active','2026-10-01','improving','Conveyor + WMS integration in progress'),
    ('CWIP-2023-015','Legacy Server Migration','it_infrastructure',
     2100000,0,2100000,1800000,520,55.00,'stalled','2027-01-31','worsening','Aged CWIP 520 days; migration abandoned candidate'),
    ('CWIP-2025-014','Dialysis Water Treatment Plant - KIMS','biomedical_lab_setup',
     8900000,0,8900000,9000000,55,96.00,'active','2026-09-20','stable','RO plant install; endotoxin validation pending'),
    ('CWIP-2024-031','Regional Office Fit-out - Mumbai','leasehold_improvements',
     5400000,5400000,5400000,5200000,20,100.00,'capitalized',null,'improving','Fit-out capitalized May 2026; minor variance absorbed'),
    ('CWIP-2025-017','C-Arm Imaging Units - Multi-site','medical_equipment',
     11200000,0,11200000,11000000,150,82.00,'over_budget','2026-09-05','worsening','Three C-arms; install overtime pushed cost above budget')
  ) as q(code, proj, cat, bal, cap_ytd, spend, budget, aging, pctc, status, ecd, trend, nt);

  -- CAPA seed — attach to specific projects by cwip_code
  insert into public.cwip_capitalization_capa_actions_r3501 (
    cwip_id, finding_category, root_cause, corrective_action,
    capa_status, audit_impact, cwip_balance_at_risk_rupees, estimated_cost_rupees,
    owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ai, q.bar, q.cost,
    q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CWIP-2024-009','commissioning_delay','vendor_delivery_delay','expedite_vendor_closure',
     'escalated','depreciation_understated',12800000,250000,'CFO Office','2026-08-15',null,'CSSD 410 days aged; escalated for vendor arbitration'),
    ('CWIP-2024-003','aged_beyond_policy','asset_not_ready_for_use','complete_commissioning',
     'in_progress','depreciation_understated',15200000,180000,'Projects Head','2026-09-30',null,'Customs-held panels; commissioning restart planned'),
    ('CWIP-2024-014','missing_capitalization_docs','documentation_incomplete','obtain_installation_certificate',
     'verification_pending','ind_as_16_capitalization',6400000,15000,'Finance Controller','2026-08-01',null,'NABL lab ready; installation certificate awaited to capitalize'),
    ('CWIP-2025-002','over_budget_overrun','budget_overrun_scope_creep','revise_capex_budget',
     'open','internal_only',9200000,700000,'IT Program Lead','2026-08-31',null,'EMR scope creep; supplementary capex note to board'),
    ('CWIP-2023-015','impairment_indicator','pending_investigation','write_off_abandoned_cwip',
     'escalated','impairment_review',2100000,2100000,'Finance Controller','2026-08-10',null,'Abandoned migration; impairment / write-off assessment'),
    ('CWIP-2025-020','stuck_cwip_not_capitalized','pending_installation_signoff','capitalize_and_start_depreciation',
     'in_progress','ind_as_16_capitalization',4800000,12000,'Biomedical Head','2026-08-05',null,'Refurb line ready; capitalize on signoff'),
    ('CWIP-2024-018','depreciation_not_started','commissioning_not_complete','complete_commissioning',
     'open','depreciation_understated',5600000,90000,'IT Infra Lead','2026-09-10',null,'UPS commissioning pending before capitalization'),
    ('CWIP-2024-027','asset_register_mismatch','fixed_asset_register_sync_lag','reconcile_asset_register',
     'closed','statutory_audit_qualification',3600000,25000,'Finance Controller','2026-07-15','2026-07-10','FAR reconciled post-capitalization; audit query cleared')
  ) as q(code, fc, rc, ca, cst, ai, bar, cost, own, tcd, acd, nt)
  join public.cwip_capitalization_r3501 e
    on e.organization_id = v_org_id and e.cwip_code = q.code;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Capitalization status distribution
create or replace function public.founder_r3501_capitalization_status_rollup()
returns table(capitalization_status text, projects bigint, total_cwip_balance_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cwip_capitalization_r3501)
  select l.capitalization_status, count(*)::bigint,
         coalesce(sum(l.cwip_balance_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.cwip_capitalization_r3501 l
  group by l.capitalization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3501_capitalization_status_rollup() from public, anon;
grant execute on function public.founder_r3501_capitalization_status_rollup() to authenticated;

-- 2) Asset-category scorecard
create or replace function public.founder_r3501_asset_category_scorecard()
returns table(
  asset_category text,
  total_projects bigint,
  ready_to_capitalize bigint,
  stalled bigint,
  over_budget bigint,
  capitalized bigint,
  total_cwip_balance_rupees numeric,
  avg_pct_complete numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_category,
    count(*)::bigint,
    count(*) filter (where l.capitalization_status = 'ready_to_capitalize')::bigint,
    count(*) filter (where l.capitalization_status = 'stalled')::bigint,
    count(*) filter (where l.capitalization_status = 'over_budget')::bigint,
    count(*) filter (where l.capitalization_status = 'capitalized')::bigint,
    coalesce(sum(l.cwip_balance_rupees),0)::numeric,
    round(avg(l.pct_complete), 1)
  from public.cwip_capitalization_r3501 l
  group by l.asset_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3501_asset_category_scorecard() from public, anon;
grant execute on function public.founder_r3501_asset_category_scorecard() to authenticated;

-- 3) Asset-category × capitalization-status matrix
create or replace function public.founder_r3501_category_status_matrix()
returns table(asset_category text, capitalization_status text, projects bigint, total_cwip_balance_rupees numeric, avg_aging_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_category, l.capitalization_status, count(*)::bigint,
    coalesce(sum(l.cwip_balance_rupees),0)::numeric,
    round(avg(l.aging_days), 1)
  from public.cwip_capitalization_r3501 l
  group by l.asset_category, l.capitalization_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3501_category_status_matrix() from public, anon;
grant execute on function public.founder_r3501_category_status_matrix() to authenticated;

-- 4) Monthly CWIP capitalization trend (by expected cap month)
create or replace function public.founder_r3501_monthly_cwip_trend()
returns table(cap_month date, projects bigint, total_cwip_balance_rupees numeric, capitalized_ytd_rupees numeric, avg_aging_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.expected_cap_date)::date, count(*)::bigint,
    coalesce(sum(l.cwip_balance_rupees),0)::numeric,
    coalesce(sum(l.capitalized_ytd_rupees),0)::numeric,
    round(avg(l.aging_days), 1)
  from public.cwip_capitalization_r3501 l
  where l.expected_cap_date is not null
  group by date_trunc('month', l.expected_cap_date)
  order by date_trunc('month', l.expected_cap_date) desc;
end;
$$;

revoke execute on function public.founder_r3501_monthly_cwip_trend() from public, anon;
grant execute on function public.founder_r3501_monthly_cwip_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3501_capa_status_board()
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
  from public.cwip_capitalization_capa_actions_r3501 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3501_capa_status_board() from public, anon;
grant execute on function public.founder_r3501_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3501_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.cwip_capitalization_capa_actions_r3501)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.cwip_capitalization_capa_actions_r3501 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3501_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3501_root_cause_pareto() to authenticated;

-- 7) CWIP-balance impact digest (by audit impact)
create or replace function public.founder_r3501_cwip_balance_impact_digest()
returns table(audit_impact text, findings bigint, open_findings bigint, total_balance_at_risk_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.audit_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.cwip_balance_at_risk_rupees),0)::numeric
  from public.cwip_capitalization_capa_actions_r3501 c
  group by c.audit_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3501_cwip_balance_impact_digest() from public, anon;
grant execute on function public.founder_r3501_cwip_balance_impact_digest() to authenticated;

-- 8) High-risk CWIP queue (stalled / over-budget / aged / worsening)
create or replace function public.founder_r3501_high_risk_queue()
returns table(
  cwip_code text,
  project_name text,
  asset_category text,
  capitalization_status text,
  cwip_balance_rupees numeric,
  aging_days int,
  pct_complete numeric,
  expected_cap_date date,
  trend_dir text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cwip_code, l.project_name, l.asset_category, l.capitalization_status,
    l.cwip_balance_rupees, l.aging_days, l.pct_complete, l.expected_cap_date, l.trend_dir, l.notes
  from public.cwip_capitalization_r3501 l
  where l.capitalization_status in ('stalled','over_budget')
     or l.aging_days > 180
     or l.trend_dir = 'worsening'
  order by l.aging_days desc, l.cwip_balance_rupees desc;
end;
$$;

revoke execute on function public.founder_r3501_high_risk_queue() from public, anon;
grant execute on function public.founder_r3501_high_risk_queue() to authenticated;
