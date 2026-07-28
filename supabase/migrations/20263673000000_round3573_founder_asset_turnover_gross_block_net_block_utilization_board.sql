-- Round 3573: Founder Asset-Turnover / Gross-Block-Net-Block Utilization Board
-- Fixed-asset turnover analytics — asset class × business unit × gross-block vs net-block × revenue per asset rupee × utilization × efficiency status × trend × CAPA

-- =============================================================================
-- TABLE 1: asset_turnover_r3573 — per-asset-class monthly turnover / utilization fact
-- =============================================================================
create table if not exists public.asset_turnover_r3573 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_ref text not null,
  asset_class text not null,
  business_unit text not null,
  period_month date not null,
  gross_block_rupees numeric(16,2) not null,
  accumulated_depreciation_rupees numeric(16,2) not null,
  net_block_rupees numeric(16,2) not null,
  revenue_generated_rupees numeric(16,2) not null,
  asset_turnover_ratio numeric(8,2) not null,
  target_turnover_ratio numeric(8,2) not null,
  utilization_pct numeric(5,2) not null,
  efficiency_status text not null check (efficiency_status in (
    'high','on_target','underutilized','idle'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.asset_turnover_r3573 enable row level security;

create index if not exists idx_asset_turnover_r3573_org on public.asset_turnover_r3573(organization_id);
create index if not exists idx_asset_turnover_r3573_month on public.asset_turnover_r3573(period_month);
create index if not exists idx_asset_turnover_r3573_status on public.asset_turnover_r3573(efficiency_status);

-- =============================================================================
-- TABLE 2: asset_turnover_capa_actions_r3573 — CAPA & utilization remediation actions
-- =============================================================================
create table if not exists public.asset_turnover_capa_actions_r3573 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  turnover_id uuid references public.asset_turnover_r3573(id) on delete cascade,
  finding_category text not null check (finding_category in (
    'low_asset_turnover','idle_asset','underutilization','high_accumulated_depreciation',
    'revenue_shortfall','capacity_mismatch','deployment_delay','maintenance_downtime'
  )),
  root_cause text not null check (root_cause in (
    'demand_shortfall','over_capitalization','poor_deployment','equipment_downtime',
    'pricing_pressure','seasonal_lull','staffing_gap','process_inefficiency',
    'pending_investigation','end_of_life_asset'
  )),
  corrective_action text not null check (corrective_action in (
    'redeploy_asset','divest_idle_asset','increase_utilization_drive','renegotiate_pricing',
    'preventive_maintenance_plan','staff_augmentation','capacity_rebalancing','write_down_asset','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(16,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.asset_turnover_capa_actions_r3573 enable row level security;

create index if not exists idx_asset_turnover_capa_r3573_org on public.asset_turnover_capa_actions_r3573(organization_id);
create index if not exists idx_asset_turnover_capa_r3573_link on public.asset_turnover_capa_actions_r3573(turnover_id);
create index if not exists idx_asset_turnover_capa_r3573_status on public.asset_turnover_capa_actions_r3573(capa_status);

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

  -- 16 asset-turnover fact rows
  insert into public.asset_turnover_r3573 (
    organization_id, asset_ref, asset_class, business_unit, period_month,
    gross_block_rupees, accumulated_depreciation_rupees, net_block_rupees, revenue_generated_rupees,
    asset_turnover_ratio, target_turnover_ratio, utilization_pct,
    efficiency_status, trend_dir, notes
  )
  select v_org_id, q.aref, q.acls, q.bu, q.pm::date,
    q.gb, q.ad, q.nb, q.rev,
    q.tr, q.ttr, q.up,
    q.es, q.td, q.nt
  from (values
    ('CT-BLR-01','ct_scanner','diagnostics','2026-06-01',
     42000000,12600000,29400000,66000000,2.24,2.10,89.0,'high','improving','Flagship CT running double shifts, strong turnover'),
    ('MRI-BLR-02','mri_scanner','diagnostics','2026-06-01',
     78000000,23400000,54600000,82000000,1.50,1.60,72.5,'on_target','stable','MRI near target utilization, steady referral demand'),
    ('CATH-DEL-03','cath_lab','critical_care','2026-06-01',
     95000000,38000000,57000000,61000000,1.07,1.40,58.0,'underutilized','worsening','Cath lab volumes down, interventional caseload fell'),
    ('DIAL-DEL-04','dialysis_machine','renal','2026-06-01',
     18000000,9000000,9000000,27000000,3.00,2.50,94.0,'high','improving','Dialysis fleet at capacity, adding evening shifts'),
    ('VENT-CHN-05','ventilator','critical_care','2026-05-01',
     12000000,7200000,4800000,6000000,1.25,1.80,45.0,'underutilized','worsening','Ventilator fleet idle post-surge, low ICU occupancy'),
    ('USG-CHN-06','ultrasound','diagnostics','2026-05-01',
     9000000,3600000,5400000,15000000,2.78,2.30,86.0,'high','stable','Ultrasound strong OPD footfall across shifts'),
    ('LAB-MUM-07','lab_analyzer','pathology','2026-05-01',
     22000000,11000000,11000000,21000000,1.91,2.00,78.0,'on_target','improving','Auto-analyzer near target, reagent contract renewed'),
    ('OT-MUM-08','ot_equipment','surgical','2026-05-01',
     35000000,17500000,17500000,12000000,0.69,1.50,38.0,'idle','worsening','Modular OT-2 idle, elective surgeries deferred'),
    ('ENDO-HYD-09','endoscopy','surgical','2026-04-01',
     14000000,5600000,8400000,19000000,2.26,2.10,84.0,'high','improving','Endoscopy suite gaining GI referrals'),
    ('MON-HYD-10','patient_monitor','critical_care','2026-04-01',
     8000000,4800000,3200000,4200000,1.31,1.70,52.0,'underutilized','stable','Monitor pool underused in step-down ward'),
    ('CT-KOL-11','ct_scanner','diagnostics','2026-04-01',
     40000000,24000000,16000000,30000000,1.88,2.10,69.0,'on_target','stable','Ageing CT still productive, hovering near target'),
    ('MRI-KOL-12','mri_scanner','diagnostics','2026-03-01',
     82000000,41000000,41000000,34000000,0.83,1.60,41.0,'idle','worsening','New MRI ramp slow, referral base not yet built'),
    ('DIAL-KOL-13','dialysis_machine','renal','2026-03-01',
     16000000,6400000,9600000,22000000,2.29,2.50,82.0,'on_target','improving','Renal unit ramping, closing on target turnover'),
    ('CATH-PUN-14','cath_lab','critical_care','2026-03-01',
     90000000,27000000,63000000,88000000,1.40,1.40,79.0,'on_target','stable','Cath lab exactly on target this quarter'),
    ('RENT-PUN-15','rental_fleet','rental','2026-02-01',
     25000000,15000000,10000000,34000000,3.40,2.60,91.0,'high','improving','Rental fleet high churn, strong utilization'),
    ('OT-PUN-16','ot_equipment','surgical','2026-02-01',
     30000000,21000000,9000000,6000000,0.67,1.50,33.0,'idle','worsening','Legacy OT set idle, candidate for divestment')
  ) as q(aref, acls, bu, pm, gb, ad, nb, rev, tr, ttr, up, es, td, nt);

  -- 8 CAPA rows — attach to specific assets via asset_ref
  insert into public.asset_turnover_capa_actions_r3573 (
    organization_id, turnover_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CATH-DEL-03','underutilization','demand_shortfall','increase_utilization_drive','in_progress',12000000,'Rajesh Menon (BU Head Critical Care)','2026-08-15',null,'Interventional cardiology outreach camps to lift cath volumes'),
    ('VENT-CHN-05','underutilization','seasonal_lull','capacity_rebalancing','open',3500000,'Dr. Anita Rao (ICU Lead)','2026-08-30',null,'Redistribute ventilators to high-occupancy sister sites'),
    ('OT-MUM-08','idle_asset','poor_deployment','redeploy_asset','escalated',22000000,'Suresh Iyer (Surgical Ops)','2026-08-10',null,'Modular OT-2 idle — relocate to high-demand Pune surgical block'),
    ('MRI-KOL-12','low_asset_turnover','over_capitalization','increase_utilization_drive','in_progress',25000000,'Priya Nair (Diagnostics Head)','2026-09-15',null,'New MRI referral network build-out and radiologist tie-ups'),
    ('OT-PUN-16','idle_asset','end_of_life_asset','divest_idle_asset','closed',6000000,'Suresh Iyer (Surgical Ops)','2026-06-20','2026-06-18','Legacy OT equipment divested to secondary market'),
    ('MON-HYD-10','underutilization','process_inefficiency','redeploy_asset','verification_pending',1400000,'Kavita Deshpande (Biomed)','2026-07-25',null,'Monitor pool reallocated to ER — verifying utilization uplift'),
    ('CT-KOL-11','high_accumulated_depreciation','end_of_life_asset','write_down_asset','overdue',16000000,'Priya Nair (Diagnostics Head)','2026-07-05',null,'Ageing CT write-down assessment overdue with finance'),
    ('CATH-DEL-03','revenue_shortfall','pricing_pressure','renegotiate_pricing','open',8000000,'Rajesh Menon (BU Head Critical Care)','2026-08-20',null,'Renegotiate payer rates for interventional procedures')
  ) as q(aref, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.asset_turnover_r3573 e
    on e.organization_id = v_org_id and e.asset_ref = q.aref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Efficiency-status distribution
create or replace function public.founder_r3573_efficiency_status_rollup()
returns table(efficiency_status text, assets bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.asset_turnover_r3573)
  select l.efficiency_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.asset_turnover_r3573 l
  group by l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3573_efficiency_status_rollup() from public, anon;
grant execute on function public.founder_r3573_efficiency_status_rollup() to authenticated;

-- 2) Asset-class scorecard
create or replace function public.founder_r3573_asset_class_scorecard()
returns table(
  asset_class text,
  records bigint,
  high bigint,
  on_target bigint,
  underutilized bigint,
  idle bigint,
  avg_turnover numeric,
  avg_utilization_pct numeric,
  total_net_block_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_class,
    count(*)::bigint,
    count(*) filter (where l.efficiency_status = 'high')::bigint,
    count(*) filter (where l.efficiency_status = 'on_target')::bigint,
    count(*) filter (where l.efficiency_status = 'underutilized')::bigint,
    count(*) filter (where l.efficiency_status = 'idle')::bigint,
    round(avg(l.asset_turnover_ratio), 2),
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.net_block_rupees),0)::numeric
  from public.asset_turnover_r3573 l
  group by l.asset_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3573_asset_class_scorecard() from public, anon;
grant execute on function public.founder_r3573_asset_class_scorecard() to authenticated;

-- 3) Asset-class × efficiency-status matrix
create or replace function public.founder_r3573_asset_class_efficiency_matrix()
returns table(
  asset_class text,
  efficiency_status text,
  records bigint,
  avg_turnover numeric,
  avg_utilization_pct numeric,
  total_revenue_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.asset_class, l.efficiency_status, count(*)::bigint,
    round(avg(l.asset_turnover_ratio), 2),
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.revenue_generated_rupees),0)::numeric
  from public.asset_turnover_r3573 l
  group by l.asset_class, l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3573_asset_class_efficiency_matrix() from public, anon;
grant execute on function public.founder_r3573_asset_class_efficiency_matrix() to authenticated;

-- 4) Monthly turnover trend
create or replace function public.founder_r3573_monthly_turnover_trend()
returns table(
  period_month date,
  records bigint,
  avg_turnover numeric,
  avg_utilization_pct numeric,
  total_gross_block_rupees numeric,
  total_net_block_rupees numeric,
  total_revenue_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.asset_turnover_ratio), 2),
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.gross_block_rupees),0)::numeric,
    coalesce(sum(l.net_block_rupees),0)::numeric,
    coalesce(sum(l.revenue_generated_rupees),0)::numeric
  from public.asset_turnover_r3573 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3573_monthly_turnover_trend() from public, anon;
grant execute on function public.founder_r3573_monthly_turnover_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3573_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.asset_turnover_capa_actions_r3573 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3573_capa_status_board() from public, anon;
grant execute on function public.founder_r3573_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3573_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.asset_turnover_capa_actions_r3573)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.asset_turnover_capa_actions_r3573 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3573_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3573_root_cause_pareto() to authenticated;

-- 7) Utilization-impact digest
create or replace function public.founder_r3573_utilization_impact_digest()
returns table(
  efficiency_status text,
  records bigint,
  avg_utilization_pct numeric,
  total_revenue_rupees numeric,
  total_net_block_rupees numeric,
  revenue_per_net_block_rupee numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.efficiency_status,
    count(*)::bigint,
    round(avg(l.utilization_pct), 1),
    coalesce(sum(l.revenue_generated_rupees),0)::numeric,
    coalesce(sum(l.net_block_rupees),0)::numeric,
    round(coalesce(sum(l.revenue_generated_rupees),0) / nullif(sum(l.net_block_rupees),0), 2)
  from public.asset_turnover_r3573 l
  group by l.efficiency_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3573_utilization_impact_digest() from public, anon;
grant execute on function public.founder_r3573_utilization_impact_digest() to authenticated;

-- 8) High-risk queue (idle / underutilized / below-target turnover)
create or replace function public.founder_r3573_high_risk_queue()
returns table(
  asset_class text,
  business_unit text,
  asset_ref text,
  period_month date,
  efficiency_status text,
  asset_turnover_ratio numeric,
  target_turnover_ratio numeric,
  utilization_pct numeric,
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
  select l.asset_class, l.business_unit, l.asset_ref, l.period_month,
    l.efficiency_status, l.asset_turnover_ratio, l.target_turnover_ratio,
    l.utilization_pct, l.trend_dir, l.notes
  from public.asset_turnover_r3573 l
  where l.efficiency_status in ('idle','underutilized')
     or l.asset_turnover_ratio < l.target_turnover_ratio
     or l.utilization_pct < 60
     or l.trend_dir = 'worsening'
  order by l.asset_turnover_ratio asc, l.utilization_pct asc;
end;
$$;

revoke execute on function public.founder_r3573_high_risk_queue() from public, anon;
grant execute on function public.founder_r3573_high_risk_queue() to authenticated;
