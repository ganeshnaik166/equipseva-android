-- Round 3213: Founder Product-Roadmap Commitment vs Delivery Slippage Board
-- Roadmap commitment log — feature × committed quarter × committed-to × planned vs shipped × slip days × scope-cut × reason × verdict; + recovery/CAPA actions

-- =============================================================================
-- TABLE 1: roadmap_slippage_r3213 — individual roadmap commitments & outcomes
-- =============================================================================
create table if not exists public.roadmap_slippage_r3213 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  committed_to_entity text not null,
  feature_code text not null,
  feature_name text not null,
  feature_area text not null check (feature_area in (
    'marketplace','payments_escrow','amc_contracts','engineer_dispatch',
    'inventory_parts','compliance_kyc','analytics_reporting','mobile_app_core'
  )),
  committed_quarter text not null check (committed_quarter in (
    'fy26_q1','fy26_q2','fy26_q3','fy26_q4','fy27_q1'
  )),
  committed_to text not null check (committed_to in (
    'customer_contract','board_okr','internal_okr',
    'sales_deal_dependency','regulatory_deadline','partner_integration'
  )),
  planned_ship_date date not null,
  actual_ship_date date,
  slip_days int,
  scope_cut boolean not null default false,
  slip_reason_category text not null check (slip_reason_category in (
    'no_slip','engineering_underestimate','dependency_delay','scope_creep',
    'hiring_gap','production_incident_diversion','customer_reprioritization','tech_debt_blocker'
  )),
  delivery_verdict text not null check (delivery_verdict in (
    'on_time','shipped_early','shipped_late','scope_cut_shipped',
    'slipped_next_quarter','at_risk','cancelled'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roadmap_slippage_r3213 enable row level security;

create index if not exists idx_roadmap_slippage_r3213_org on public.roadmap_slippage_r3213(organization_id);
create index if not exists idx_roadmap_slippage_r3213_planned on public.roadmap_slippage_r3213(planned_ship_date);
create index if not exists idx_roadmap_slippage_r3213_verdict on public.roadmap_slippage_r3213(delivery_verdict);

-- =============================================================================
-- TABLE 2: roadmap_slippage_capa_actions_r3213 — recovery/CAPA actions
-- =============================================================================
create table if not exists public.roadmap_slippage_capa_actions_r3213 (
  id uuid primary key default gen_random_uuid(),
  slippage_id uuid not null references public.roadmap_slippage_r3213(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'missed_customer_commitment','missed_board_okr','repeat_slippage',
    'scope_cut_regression','estimation_failure','communication_gap'
  )),
  root_cause text not null check (root_cause in (
    'optimistic_estimation','unplanned_incident_load','vendor_api_delay',
    'underspecified_requirements','key_engineer_attrition',
    'parallel_project_overload','tech_debt_surprise','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_estimation_buffer','split_into_phases','hire_backfill',
    'freeze_scope_after_commit','weekly_customer_update_cadence',
    'dedicated_incident_rotation','descope_and_renegotiate','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'contract_penalty_risk','board_escalation','none','internal_only',
    'customer_churn_risk','regulatory_deadline_risk'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.roadmap_slippage_capa_actions_r3213 enable row level security;

create index if not exists idx_roadmap_slippage_capa_r3213_parent on public.roadmap_slippage_capa_actions_r3213(slippage_id);
create index if not exists idx_roadmap_slippage_capa_r3213_status on public.roadmap_slippage_capa_actions_r3213(capa_status);

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

  -- 14 roadmap commitment rows
  insert into public.roadmap_slippage_r3213 (
    organization_id, committed_to_entity, feature_code, feature_name, feature_area,
    committed_quarter, committed_to, planned_ship_date, actual_ship_date,
    slip_days, scope_cut, slip_reason_category, delivery_verdict, notes
  )
  select v_org_id, q.ent, q.fcode, q.fname, q.area,
    q.cq, q.cto, q.pd::date, q.sd::date,
    q.slip, q.cut, q.reason, q.verdict, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','RM-2026-001','Multi-site AMC renewal dashboard','amc_contracts',
     'fy26_q1','customer_contract','2026-04-15','2026-04-12',-3,false,'no_slip','shipped_early','Shipped 3 days ahead of contract commitment'),
    ('Apollo Hyderabad Jubilee Hills','RM-2026-002','OT equipment downtime SLA alerts','engineer_dispatch',
     'fy26_q1','customer_contract','2026-05-10','2026-06-02',23,false,'engineering_underestimate','shipped_late','Underestimated pager-integration effort by three sprints'),
    ('Fortis Bannerghatta Bengaluru','RM-2026-003','Escrow milestone auto-release v2','payments_escrow',
     'fy26_q1','sales_deal_dependency','2026-05-20','2026-05-20',0,false,'no_slip','on_time','Blocking clause in Fortis renewal — shipped on the day'),
    ('Fortis Bannerghatta Bengaluru','RM-2026-004','Spare-parts inventory sync API','inventory_parts',
     'fy26_q2','partner_integration','2026-06-15',null,33,false,'dependency_delay','at_risk','Partner API sandbox still not provisioned'),
    ('Manipal Whitefield Bengaluru','RM-2026-005','Engineer geo-routing optimizer','engineer_dispatch',
     'fy26_q1','customer_contract','2026-04-30','2026-06-18',49,true,'scope_creep','scope_cut_shipped','Dropped multi-day route planning to ship core routing'),
    ('AIIMS New Delhi Ansari Nagar','RM-2026-006','CDSCO device-recall traceability','compliance_kyc',
     'fy26_q1','regulatory_deadline','2026-05-31','2026-05-28',-3,false,'no_slip','shipped_early','Regulatory deadline met with buffer'),
    ('AIIMS New Delhi Ansari Nagar','RM-2026-007','Tender-compliant quote generator','analytics_reporting',
     'fy26_q2','customer_contract','2026-07-01',null,17,false,'production_incident_diversion','at_risk','Team diverted to Code Red incident rotation'),
    ('KIMS Secunderabad','RM-2026-008','Biomedical asset QR audit trail','compliance_kyc',
     'fy26_q1','customer_contract','2026-04-20','2026-05-25',35,false,'hiring_gap','shipped_late','Backend hire joined six weeks late'),
    ('Care Hospitals Banjara Hills','RM-2026-009','AMC invoice GST auto-reconcile','amc_contracts',
     'fy26_q2','customer_contract','2026-06-30','2026-06-30',0,false,'no_slip','on_time','Finance team validated on UAT day itself'),
    ('Yashoda Somajiguda Hyderabad','RM-2026-010','Marketplace bid analytics pack','marketplace',
     'fy26_q2','sales_deal_dependency','2026-06-10',null,38,false,'customer_reprioritization','slipped_next_quarter','Yashoda asked to prioritize dispatch SLA work first'),
    ('St John''s Bengaluru','RM-2026-011','Training-record e-sign module','mobile_app_core',
     'fy26_q2','customer_contract','2026-07-05','2026-07-15',10,false,'tech_debt_blocker','shipped_late','Legacy auth refactor blocked the e-sign flow'),
    ('Rainbow Children''s Hyderabad','RM-2026-012','Pediatric device calibration planner','analytics_reporting',
     'fy26_q2','customer_contract','2026-07-10',null,8,false,'engineering_underestimate','at_risk','Calibration interval engine more complex than sized'),
    ('EquipSeva Board','RM-2026-013','Unified founder ops console v3','analytics_reporting',
     'fy26_q1','board_okr','2026-05-15','2026-05-15',0,false,'no_slip','on_time','Board OKR delivered inside the quarter'),
    ('EquipSeva Platform Team','RM-2026-014','Legacy escrow ledger rewrite','payments_escrow',
     'fy26_q1','internal_okr','2026-06-01',null,47,true,'tech_debt_blocker','cancelled','Cancelled — superseded by v2 auto-release architecture')
  ) as q(ent, fcode, fname, area, cq, cto, pd, sd, slip, cut, reason, verdict, nt);

  -- CAPA seed — attach to specific commitments by feature_code
  insert into public.roadmap_slippage_capa_actions_r3213 (
    slippage_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('RM-2026-002','missed_customer_commitment','optimistic_estimation','add_estimation_buffer','2026-07-15',null,'in_progress','customer_churn_risk',120000.00,'Apollo CIO escalated the 23-day slip in QBR'),
    ('RM-2026-005','scope_cut_regression','underspecified_requirements','freeze_scope_after_commit','2026-07-20',null,'open','contract_penalty_risk',250000.00,'Manipal contract carries a per-week LD clause'),
    ('RM-2026-008','estimation_failure','key_engineer_attrition','hire_backfill','2026-06-30','2026-06-24','closed','internal_only',480000.00,'Backfill hired; onboarding complete'),
    ('RM-2026-004','missed_customer_commitment','vendor_api_delay','weekly_customer_update_cadence','2026-07-25',null,'escalated','customer_churn_risk',0.00,'Weekly Fortis sync started; partner still blocking'),
    ('RM-2026-007','repeat_slippage','unplanned_incident_load','dedicated_incident_rotation','2026-07-10',null,'overdue','regulatory_deadline_risk',90000.00,'Incident-rotation staffing plan not yet approved'),
    ('RM-2026-010','communication_gap','parallel_project_overload','descope_and_renegotiate','2026-07-18','2026-07-12','closed','board_escalation',60000.00,'Renegotiated Q3 date signed off by Yashoda')
  ) as q(fcode, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.roadmap_slippage_r3213 e
    on e.organization_id = v_org_id and e.feature_code = q.fcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Delivery verdict distribution
create or replace function public.founder_r3213_delivery_verdict_rollup()
returns table(delivery_verdict text, features bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roadmap_slippage_r3213)
  select l.delivery_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.roadmap_slippage_r3213 l
  group by l.delivery_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3213_delivery_verdict_rollup() from public, anon;
grant execute on function public.founder_r3213_delivery_verdict_rollup() to authenticated;

-- 2) Committed-to entity scorecard
create or replace function public.founder_r3213_entity_scorecard()
returns table(
  committed_to_entity text,
  total_features bigint,
  on_time_count bigint,
  late_count bigint,
  at_risk_count bigint,
  scope_cuts bigint,
  avg_slip_days numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committed_to_entity,
    count(*)::bigint,
    count(*) filter (where l.delivery_verdict in ('on_time','shipped_early'))::bigint,
    count(*) filter (where l.delivery_verdict = 'shipped_late')::bigint,
    count(*) filter (where l.delivery_verdict in ('at_risk','slipped_next_quarter'))::bigint,
    count(*) filter (where l.scope_cut)::bigint,
    round(avg(l.slip_days)::numeric, 1),
    round(100.0 * count(*) filter (where l.delivery_verdict in ('on_time','shipped_early'))::numeric / nullif(count(*),0), 1)
  from public.roadmap_slippage_r3213 l
  group by l.committed_to_entity
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3213_entity_scorecard() from public, anon;
grant execute on function public.founder_r3213_entity_scorecard() to authenticated;

-- 3) Committed quarter × feature area matrix
create or replace function public.founder_r3213_quarter_area_matrix()
returns table(committed_quarter text, feature_area text, features bigint, late_or_slipped bigint, avg_slip_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committed_quarter, l.feature_area, count(*)::bigint,
    count(*) filter (where l.delivery_verdict in ('shipped_late','slipped_next_quarter','at_risk','cancelled'))::bigint,
    round(avg(l.slip_days)::numeric, 1)
  from public.roadmap_slippage_r3213 l
  group by l.committed_quarter, l.feature_area
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3213_quarter_area_matrix() from public, anon;
grant execute on function public.founder_r3213_quarter_area_matrix() to authenticated;

-- 4) Monthly slip trend (by planned ship month)
create or replace function public.founder_r3213_monthly_slip_trend()
returns table(plan_month date, features bigint, shipped bigint, late bigint, avg_slip_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select (date_trunc('month', l.planned_ship_date))::date,
    count(*)::bigint,
    count(*) filter (where l.actual_ship_date is not null)::bigint,
    count(*) filter (where l.delivery_verdict in ('shipped_late','slipped_next_quarter'))::bigint,
    round(avg(l.slip_days)::numeric, 1)
  from public.roadmap_slippage_r3213 l
  group by (date_trunc('month', l.planned_ship_date))::date
  order by (date_trunc('month', l.planned_ship_date))::date desc;
end;
$$;

revoke execute on function public.founder_r3213_monthly_slip_trend() from public, anon;
grant execute on function public.founder_r3213_monthly_slip_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3213_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_or_escalated bigint)
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
  from public.roadmap_slippage_capa_actions_r3213 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3213_capa_status_board() from public, anon;
grant execute on function public.founder_r3213_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3213_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.roadmap_slippage_capa_actions_r3213)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.roadmap_slippage_capa_actions_r3213 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3213_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3213_root_cause_pareto() to authenticated;

-- 7) Commitment impact digest
create or replace function public.founder_r3213_commitment_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','verification_pending','overdue','escalated'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.roadmap_slippage_capa_actions_r3213 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3213_commitment_impact_digest() from public, anon;
grant execute on function public.founder_r3213_commitment_impact_digest() to authenticated;

-- 8) High-risk commitments queue
create or replace function public.founder_r3213_high_risk_commitments()
returns table(
  committed_to_entity text,
  feature_code text,
  feature_name text,
  committed_quarter text,
  committed_to text,
  planned_ship_date date,
  slip_days int,
  delivery_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.committed_to_entity, l.feature_code, l.feature_name, l.committed_quarter,
    l.committed_to, l.planned_ship_date, l.slip_days, l.delivery_verdict, l.notes
  from public.roadmap_slippage_r3213 l
  where l.delivery_verdict in ('at_risk','shipped_late','slipped_next_quarter','cancelled')
     or l.scope_cut
  order by l.slip_days desc nulls last, l.planned_ship_date;
end;
$$;

revoke execute on function public.founder_r3213_high_risk_commitments() from public, anon;
grant execute on function public.founder_r3213_high_risk_commitments() to authenticated;
