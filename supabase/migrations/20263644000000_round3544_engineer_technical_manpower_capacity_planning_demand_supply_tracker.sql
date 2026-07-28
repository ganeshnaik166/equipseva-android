-- Round 3544: Engineer Technical-Manpower Capacity-Planning (Demand/Supply) Tracker
-- Field-engineering capacity plans — region × skill category × month × demand hours × available FTE × supply hours × capacity gap × utilization × contractor hours × hiring needed × coverage-status verdict × CAPA

-- =============================================================================
-- TABLE 1: manpower_capacity_r3544 — per-region/skill/month capacity plan rows
-- =============================================================================
create table if not exists public.manpower_capacity_r3544 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_code text not null,
  region text not null,
  skill_category text not null check (skill_category in (
    'imaging','lab','biomedical','it_network','hvac_utility','general'
  )),
  period_month date not null,
  demand_hours numeric(10,2) not null,
  available_fte numeric(6,2) not null,
  supply_hours numeric(10,2) not null,
  capacity_gap_hours numeric(10,2) not null,
  utilization_pct numeric(6,2),
  backlog_tickets int,
  pm_visits_due int,
  overtime_hours numeric(10,2),
  contractor_hours numeric(10,2),
  hiring_needed int not null,
  coverage_status text not null check (coverage_status in (
    'surplus','balanced','tight','shortfall','critical_shortfall'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.manpower_capacity_r3544 enable row level security;

create index if not exists idx_manpower_capacity_r3544_org on public.manpower_capacity_r3544(organization_id);
create index if not exists idx_manpower_capacity_r3544_month on public.manpower_capacity_r3544(period_month);
create index if not exists idx_manpower_capacity_r3544_status on public.manpower_capacity_r3544(coverage_status);

-- =============================================================================
-- TABLE 2: manpower_capacity_capa_actions_r3544 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.manpower_capacity_capa_actions_r3544 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  capacity_id uuid not null references public.manpower_capacity_r3544(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'demand_supply_gap','skill_shortage','high_utilization_burnout','pm_backlog',
    'excess_contractor_dependence','attrition_risk','coverage_shortfall','fte_underutilized'
  )),
  root_cause text not null check (root_cause in (
    'headcount_freeze','attrition_unbacked','demand_spike_new_installs','training_pipeline_lag',
    'geographic_maldistribution','contractor_cost_overrun','absenteeism_high','skill_mismatch',
    'pending_investigation','seasonal_demand_surge'
  )),
  corrective_action text not null check (corrective_action in (
    'initiate_hiring','engage_contractors','cross_skill_training','redistribute_workload',
    'realign_regions','reduce_scope_backlog','retention_intervention','escalate_to_leadership',
    'defer_low_priority_pm','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  service_impact text not null check (service_impact in (
    'sla_breach_risk','patient_care_delay','pm_slippage','contract_penalty_risk','none','internal_only'
  )),
  owner text not null,
  gap_hours_impact numeric(10,2),
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.manpower_capacity_capa_actions_r3544 enable row level security;

create index if not exists idx_manpower_capacity_capa_r3544_link on public.manpower_capacity_capa_actions_r3544(capacity_id);
create index if not exists idx_manpower_capacity_capa_r3544_status on public.manpower_capacity_capa_actions_r3544(capa_status);

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

  -- 16 capacity-plan rows
  insert into public.manpower_capacity_r3544 (
    organization_id, plan_code, region, skill_category, period_month,
    demand_hours, available_fte, supply_hours, capacity_gap_hours, utilization_pct,
    backlog_tickets, pm_visits_due, overtime_hours, contractor_hours, hiring_needed,
    coverage_status, notes
  )
  select v_org_id, q.pcode, q.region, q.skill, q.pmonth::date,
    q.demand, q.fte, q.supply, q.gap, q.util,
    q.backlog, q.pmdue, q.ot, q.contractor, q.hire,
    q.cov, q.nt
  from (values
    ('CP-DEL-IMG-2607','Delhi NCR','imaging','2026-07-01',
     1680,9,1440,240,116.7,22,14,120,160,1,'shortfall','Imaging engineers stretched — CT/MRI new installs raising demand'),
    ('CP-DEL-LAB-2607','Delhi NCR','lab','2026-07-01',
     980,6,960,20,102.1,6,9,30,40,0,'tight','Lab analyzer coverage tight but manageable'),
    ('CP-MUM-IMG-2607','Mumbai-Pune','imaging','2026-07-01',
     2100,10,1600,500,131.3,34,18,210,320,2,'critical_shortfall','Severe imaging shortfall — attrition of two senior engineers'),
    ('CP-MUM-BME-2607','Mumbai-Pune','biomedical','2026-07-01',
     1500,9,1520,-20,98.7,4,12,20,0,0,'balanced','Biomedical FTE balanced with demand'),
    ('CP-BLR-ITN-2607','Bengaluru','it_network','2026-07-01',
     720,5,880,-160,81.8,2,5,0,0,0,'surplus','IT/network bandwidth surplus — reallocate to PACS rollout'),
    ('CP-BLR-BME-2607','Bengaluru','biomedical','2026-07-01',
     1320,8,1200,120,110.0,12,10,80,80,1,'shortfall','Biomedical PM backlog building on ventilators'),
    ('CP-CHN-HVC-2607','Chennai','hvac_utility','2026-07-01',
     640,4,600,40,106.7,5,7,40,60,0,'tight','HVAC/utility coverage tight during summer load'),
    ('CP-CHN-GEN-2607','Chennai','general','2026-07-01',
     520,4,640,-120,81.3,1,4,0,0,0,'surplus','General field engineers under-utilized in Chennai'),
    ('CP-HYD-IMG-2607','Hyderabad','imaging','2026-07-01',
     1450,8,1280,170,113.3,18,11,90,120,1,'shortfall','Cath-lab demand surge post two new installs'),
    ('CP-KOL-LAB-2607','Kolkata','lab','2026-07-01',
     860,5,720,140,119.4,14,8,70,90,1,'shortfall','Lab coverage short in East region — training lag'),
    ('CP-DEL-IMG-2606','Delhi NCR','imaging','2026-06-01',
     1560,9,1500,60,104.0,10,12,60,80,0,'tight','June imaging demand tight ahead of installs'),
    ('CP-MUM-IMG-2606','Mumbai-Pune','imaging','2026-06-01',
     1900,11,1760,140,108.0,20,15,120,160,1,'shortfall','Imaging shortfall emerging in June'),
    ('CP-BLR-ITN-2606','Bengaluru','it_network','2026-06-01',
     700,5,900,-200,77.8,1,4,0,0,0,'surplus','IT surplus in June'),
    ('CP-HYD-IMG-2606','Hyderabad','imaging','2026-06-01',
     1300,8,1280,20,101.6,8,9,30,40,0,'tight','Hyderabad imaging balanced-to-tight in June'),
    ('CP-MUM-IMG-2605','Mumbai-Pune','imaging','2026-05-01',
     1720,11,1720,0,100.0,12,13,60,80,0,'balanced','May imaging balanced'),
    ('CP-CHN-HVC-2605','Chennai','hvac_utility','2026-05-01',
     560,4,620,-60,90.3,2,5,0,20,0,'surplus','Pre-summer HVAC surplus in May')
  ) as q(pcode, region, skill, pmonth, demand, fte, supply, gap, util, backlog, pmdue, ot, contractor, hire, cov, nt);

  -- CAPA seed — attach to specific plans via plan_code
  insert into public.manpower_capacity_capa_actions_r3544 (
    capacity_id, organization_id, finding_category, root_cause, corrective_action,
    capa_status, service_impact, owner, gap_hours_impact,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, e.organization_id, q.fc, q.rc, q.ca,
    q.cst, q.si, q.owner, q.impact,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('CP-MUM-IMG-2607','demand_supply_gap','attrition_unbacked','initiate_hiring','in_progress','sla_breach_risk','Regional Ops Head - West',500,'2026-08-15',null,'Two imaging reqs opened; interim contractors engaged'),
    ('CP-DEL-IMG-2607','coverage_shortfall','demand_spike_new_installs','engage_contractors','open','pm_slippage','Zonal Manager - North',240,'2026-08-10',null,'CT/MRI installs raised demand; contractor PO raised'),
    ('CP-BLR-BME-2607','pm_backlog','training_pipeline_lag','cross_skill_training','in_progress','patient_care_delay','Biomed Lead - South',120,'2026-08-05',null,'Ventilator PM backlog; cross-skilling two engineers'),
    ('CP-HYD-IMG-2607','skill_shortage','seasonal_demand_surge','redistribute_workload','verification_pending','sla_breach_risk','Zonal Manager - South',170,'2026-08-01',null,'Cath-lab surge; workload rebalanced with Bengaluru'),
    ('CP-KOL-LAB-2607','skill_shortage','geographic_maldistribution','realign_regions','open','pm_slippage','Regional Ops Head - East',140,'2026-08-20',null,'East region lab thin; realignment proposal drafted'),
    ('CP-MUM-IMG-2606','high_utilization_burnout','absenteeism_high','retention_intervention','closed','internal_only','HRBP - West',140,'2026-07-10','2026-07-08','Overtime curbed; retention bonus approved'),
    ('CP-CHN-HVC-2607','excess_contractor_dependence','contractor_cost_overrun','reduce_scope_backlog','escalated','contract_penalty_risk','Facilities Lead - South',40,'2026-07-25',null,'HVAC contractor spend over budget — escalated'),
    ('CP-DEL-IMG-2606','coverage_shortfall','demand_spike_new_installs','initiate_hiring','overdue','sla_breach_risk','Zonal Manager - North',60,'2026-07-15',null,'Hiring req aging past target — vendor delay'),
    ('CP-BLR-ITN-2607','fte_underutilized','skill_mismatch','redistribute_workload','closed','internal_only','IT Ops Lead - South',160,'2026-07-05','2026-07-03','Reallocated IT engineers to PACS rollout')
  ) as q(pcode, fc, rc, ca, cst, si, owner, impact, tcd, acd, nt)
  join public.manpower_capacity_r3544 e
    on e.organization_id = v_org_id and e.plan_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage-status distribution
create or replace function public.founder_r3544_coverage_status_rollup()
returns table(coverage_status text, plans bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.manpower_capacity_r3544)
  select l.coverage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.manpower_capacity_r3544 l
  group by l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3544_coverage_status_rollup() from public, anon;
grant execute on function public.founder_r3544_coverage_status_rollup() to authenticated;

-- 2) Skill-category scorecard
create or replace function public.founder_r3544_skill_category_scorecard()
returns table(
  skill_category text,
  plans bigint,
  total_demand_hours numeric,
  total_supply_hours numeric,
  total_gap_hours numeric,
  avg_utilization_pct numeric,
  shortfall_plans bigint,
  hiring_needed_total bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.skill_category,
    count(*)::bigint,
    coalesce(sum(l.demand_hours),0)::numeric,
    coalesce(sum(l.supply_hours),0)::numeric,
    coalesce(sum(l.capacity_gap_hours),0)::numeric,
    round(avg(l.utilization_pct), 1),
    count(*) filter (where l.coverage_status in ('shortfall','critical_shortfall'))::bigint,
    coalesce(sum(l.hiring_needed),0)::bigint
  from public.manpower_capacity_r3544 l
  group by l.skill_category
  order by coalesce(sum(l.capacity_gap_hours),0) desc;
end;
$$;

revoke execute on function public.founder_r3544_skill_category_scorecard() from public, anon;
grant execute on function public.founder_r3544_skill_category_scorecard() to authenticated;

-- 3) Skill-category × coverage-status matrix
create or replace function public.founder_r3544_skill_coverage_matrix()
returns table(skill_category text, coverage_status text, plans bigint, total_gap_hours numeric, avg_utilization_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.skill_category, l.coverage_status, count(*)::bigint,
    coalesce(sum(l.capacity_gap_hours),0)::numeric,
    round(avg(l.utilization_pct), 1)
  from public.manpower_capacity_r3544 l
  group by l.skill_category, l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3544_skill_coverage_matrix() from public, anon;
grant execute on function public.founder_r3544_skill_coverage_matrix() to authenticated;

-- 4) Monthly capacity trend
create or replace function public.founder_r3544_monthly_capacity_trend()
returns table(
  period_month date,
  plans bigint,
  total_demand_hours numeric,
  total_supply_hours numeric,
  total_gap_hours numeric,
  avg_utilization_pct numeric
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
    coalesce(sum(l.demand_hours),0)::numeric,
    coalesce(sum(l.supply_hours),0)::numeric,
    coalesce(sum(l.capacity_gap_hours),0)::numeric,
    round(avg(l.utilization_pct), 1)
  from public.manpower_capacity_r3544 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3544_monthly_capacity_trend() from public, anon;
grant execute on function public.founder_r3544_monthly_capacity_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3544_capa_status_board()
returns table(capa_status text, findings bigint, avg_gap_impact numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.gap_hours_impact)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.manpower_capacity_capa_actions_r3544 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3544_capa_status_board() from public, anon;
grant execute on function public.founder_r3544_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3544_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_gap_impact numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.manpower_capacity_capa_actions_r3544)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.gap_hours_impact),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.manpower_capacity_capa_actions_r3544 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3544_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3544_root_cause_pareto() to authenticated;

-- 7) Capacity-gap impact digest (by service impact)
create or replace function public.founder_r3544_capacity_gap_impact_digest()
returns table(service_impact text, findings bigint, open_findings bigint, total_gap_impact numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.service_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.gap_hours_impact),0)::numeric
  from public.manpower_capacity_capa_actions_r3544 c
  group by c.service_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3544_capacity_gap_impact_digest() from public, anon;
grant execute on function public.founder_r3544_capacity_gap_impact_digest() to authenticated;

-- 8) High-risk capacity queue (critical-shortfall / large-gap)
create or replace function public.founder_r3544_high_risk_queue()
returns table(
  region text,
  plan_code text,
  skill_category text,
  period_month date,
  coverage_status text,
  demand_hours numeric,
  supply_hours numeric,
  capacity_gap_hours numeric,
  utilization_pct numeric,
  hiring_needed int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.region, l.plan_code, l.skill_category, l.period_month, l.coverage_status,
    l.demand_hours, l.supply_hours, l.capacity_gap_hours, l.utilization_pct, l.hiring_needed, l.notes
  from public.manpower_capacity_r3544 l
  where l.coverage_status in ('shortfall','critical_shortfall')
     or l.capacity_gap_hours >= 100
     or l.utilization_pct >= 110
     or l.hiring_needed > 0
  order by l.capacity_gap_hours desc, l.utilization_pct desc;
end;
$$;

revoke execute on function public.founder_r3544_high_risk_queue() from public, anon;
grant execute on function public.founder_r3544_high_risk_queue() to authenticated;
