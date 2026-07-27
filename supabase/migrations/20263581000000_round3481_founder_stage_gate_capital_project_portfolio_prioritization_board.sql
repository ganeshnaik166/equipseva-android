-- Round 3481: Founder Stage-Gate Capital-Project Portfolio Prioritization Board
-- Capital-project portfolio governance — project x sponsor x category x gate stage x investment x ROI x
-- strategic/risk scores x priority rank x go/no-go decision x target gate date x CAPA closure

-- =============================================================================
-- TABLE 1: stage_gate_portfolio_r3481 — per-project stage-gate prioritization record
-- =============================================================================
create table if not exists public.stage_gate_portfolio_r3481 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_code text not null,
  project_name text not null,
  sponsor text not null,
  category text not null,
  gate_stage text not null check (gate_stage in (
    'idea','feasibility','business_case','approved','in_execution','launched','on_hold','killed'
  )),
  investment_rupees numeric(14,2),
  expected_roi_pct numeric(6,2),
  strategic_score int,
  risk_score int,
  priority_rank int,
  gate_decision text not null check (gate_decision in (
    'go','conditional_go','hold','no_go','recycle'
  )),
  target_gate_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.stage_gate_portfolio_r3481 enable row level security;

create index if not exists idx_stage_gate_portfolio_r3481_org on public.stage_gate_portfolio_r3481(organization_id);
create index if not exists idx_stage_gate_portfolio_r3481_stage on public.stage_gate_portfolio_r3481(gate_stage);
create index if not exists idx_stage_gate_portfolio_r3481_decision on public.stage_gate_portfolio_r3481(gate_decision);

-- =============================================================================
-- TABLE 2: stage_gate_portfolio_capa_actions_r3481 — CAPA & governance actions
-- =============================================================================
create table if not exists public.stage_gate_portfolio_capa_actions_r3481 (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.stage_gate_portfolio_r3481(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'roi_below_hurdle','strategic_misalignment','capex_overrun','schedule_slippage','regulatory_risk',
    'resource_constraint','market_risk_high','integration_dependency','scope_creep','stalled_in_gate'
  )),
  root_cause text not null check (root_cause in (
    'weak_business_case','optimistic_roi_assumptions','vendor_cost_escalation','regulatory_approval_delay',
    'talent_shortage','competing_priorities','market_demand_shift','scope_ambiguity','sponsor_unavailable','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'revise_business_case','rebaseline_budget','reprioritize_portfolio','defer_to_next_cycle','secure_additional_funding',
    'reassign_sponsor','de_scope_project','kill_project','commission_market_study','none_required'
  )),
  owner text not null,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  investment_impact text not null check (investment_impact in (
    'high_capital_at_risk','moderate_capital_at_risk','low_capital_at_risk','strategic_bet','none','sunk_cost_writeoff'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.stage_gate_portfolio_capa_actions_r3481 enable row level security;

create index if not exists idx_stage_gate_portfolio_capa_r3481_proj on public.stage_gate_portfolio_capa_actions_r3481(project_id);
create index if not exists idx_stage_gate_portfolio_capa_r3481_status on public.stage_gate_portfolio_capa_actions_r3481(capa_status);

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

  -- 16 portfolio project rows
  insert into public.stage_gate_portfolio_r3481 (
    organization_id, project_code, project_name, sponsor, category, gate_stage,
    investment_rupees, expected_roi_pct, strategic_score, risk_score, priority_rank,
    gate_decision, target_gate_date, notes
  )
  select v_org_id, q.pcode, q.pname, q.spons, q.cat, q.stage,
    q.inv, q.roi, q.ss, q.rs, q.pr,
    q.gdec, q.tgd::date, q.nt
  from (values
    ('PRJ-CT-01','Cath Lab Expansion Chennai','Dr. Ramesh Kumar','clinical_expansion','approved',
     85000000,18.5,9,4,1,'go','2026-08-10','Third cath lab approved; strong ROI and strategic fit'),
    ('PRJ-ON-02','Oncology Day-Care Centre','Dr. Priya Nair','clinical_expansion','business_case',
     62000000,15.2,8,5,3,'conditional_go','2026-08-20','Business case strong; awaiting oncologist hiring plan'),
    ('PRJ-DH-03','Unified EHR Rollout','Anil Mehta','digital_health','in_execution',
     45000000,12.0,9,6,2,'go','2026-07-30','Enterprise EHR mid-execution across 4 sites'),
    ('PRJ-DH-04','Tele-ICU Command Centre','Anil Mehta','digital_health','feasibility',
     38000000,20.0,7,7,6,'hold','2026-09-05','Tele-ICU on hold pending bandwidth feasibility'),
    ('PRJ-BM-05','MRI 3T Upgrade Bengaluru','Dr. Suresh Rao','biomedical_capex','approved',
     120000000,16.8,8,5,4,'go','2026-08-15','MRI upgrade approved; high utilisation forecast'),
    ('PRJ-BM-06','Linear Accelerator Replacement','Dr. Suresh Rao','biomedical_capex','business_case',
     155000000,14.0,9,6,5,'conditional_go','2026-09-12','LINAC replacement conditional on NABH radiation clearance'),
    ('PRJ-IN-07','New OT Complex Hyderabad','Meena Reddy','infrastructure','idea',
     210000000,13.5,7,8,9,'recycle','2026-10-01','OT complex recycled for rescoping; capex too high'),
    ('PRJ-SN-08','Satellite Dialysis Network','Vikram Shah','service_network','in_execution',
     54000000,22.0,8,4,3,'go','2026-07-28','Dialysis spokes rolling out; ahead of plan'),
    ('PRJ-RD-09','AI Radiology Triage Pilot','Dr. Kavita Iyer','r_and_d','feasibility',
     18000000,25.0,6,7,8,'hold','2026-09-18','AI triage pilot on hold; validation dataset pending'),
    ('PRJ-CP-10','NABH Re-accreditation Program','Sanjay Gupta','compliance','approved',
     12000000,8.0,8,3,7,'go','2026-08-05','Mandatory compliance program approved'),
    ('PRJ-DX-11','Molecular Diagnostics Lab','Dr. Kavita Iyer','diagnostics','business_case',
     72000000,19.5,8,6,5,'conditional_go','2026-09-25','Mol-dx lab conditional on genomics partnership'),
    ('PRJ-IN-12','Rooftop Solar & Backup','Meena Reddy','infrastructure','launched',
     28000000,11.0,6,3,10,'go','2026-07-15','Solar plant launched; opex savings tracking'),
    ('PRJ-ON-13','Proton Therapy Feasibility','Dr. Priya Nair','clinical_expansion','idea',
     480000000,10.0,7,9,12,'no_go','2026-10-10','Proton therapy no-go; capex and demand not justified'),
    ('PRJ-DH-14','Patient Mobile App v2','Anil Mehta','digital_health','on_hold',
     9000000,14.0,5,5,11,'hold','2026-08-30','App v2 on hold; competing IT priorities'),
    ('PRJ-BM-15','Cath Lab Robotics Add-on','Dr. Ramesh Kumar','biomedical_capex','killed',
     66000000,9.5,5,8,13,'no_go','2026-08-22','Robotics add-on killed; ROI below hurdle and high risk'),
    ('PRJ-SN-16','Home-Care Nursing Venture','Vikram Shah','service_network','feasibility',
     24000000,17.0,7,6,6,'conditional_go','2026-09-08','Home-care venture conditional on regulatory model')
  ) as q(pcode, pname, spons, cat, stage, inv, roi, ss, rs, pr, gdec, tgd, nt);

  -- CAPA seed — attach to specific projects via project_code
  insert into public.stage_gate_portfolio_capa_actions_r3481 (
    project_id, finding_category, root_cause, corrective_action, owner,
    capa_status, investment_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.own,
    q.cst, q.imp, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('PRJ-IN-07','capex_overrun','vendor_cost_escalation','rebaseline_budget','Meena Reddy',
     'in_progress','high_capital_at_risk','2026-09-15',null,500000.00,'OT complex capex rebaselining underway'),
    ('PRJ-DH-04','schedule_slippage','competing_priorities','defer_to_next_cycle','Anil Mehta',
     'open','moderate_capital_at_risk','2026-09-30',null,150000.00,'Tele-ICU deferred pending bandwidth study'),
    ('PRJ-RD-09','market_risk_high','market_demand_shift','commission_market_study','Dr. Kavita Iyer',
     'open','strategic_bet','2026-10-05',null,300000.00,'AI triage market study commissioned'),
    ('PRJ-ON-13','roi_below_hurdle','optimistic_roi_assumptions','kill_project','Dr. Priya Nair',
     'closed','sunk_cost_writeoff','2026-08-01','2026-07-25',800000.00,'Proton therapy shelved; feasibility spend written off'),
    ('PRJ-BM-15','roi_below_hurdle','weak_business_case','kill_project','Dr. Ramesh Kumar',
     'closed','sunk_cost_writeoff','2026-08-10','2026-08-05',1200000.00,'Robotics add-on killed post gate review'),
    ('PRJ-DH-14','stalled_in_gate','sponsor_unavailable','reassign_sponsor','Anil Mehta',
     'escalated','low_capital_at_risk','2026-08-28',null,90000.00,'App v2 stalled; sponsor bandwidth escalated to CIO'),
    ('PRJ-BM-06','regulatory_risk','regulatory_approval_delay','secure_additional_funding','Dr. Suresh Rao',
     'overdue','high_capital_at_risk','2026-07-20',null,250000.00,'LINAC AERB clearance overdue; funding contingency triggered'),
    ('PRJ-DX-11','strategic_misalignment','scope_ambiguity','revise_business_case','Dr. Kavita Iyer',
     'verification_pending','moderate_capital_at_risk','2026-09-20',null,180000.00,'Mol-dx scope clarified; business case revision in review')
  ) as q(pcode, fc, rc, ca, own, cst, imp, tcd, acd, cost, nt)
  join public.stage_gate_portfolio_r3481 e
    on e.organization_id = v_org_id and e.project_code = q.pcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Gate-decision distribution
create or replace function public.founder_r3481_gate_decision_rollup()
returns table(gate_decision text, projects bigint, total_investment_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.stage_gate_portfolio_r3481)
  select l.gate_decision, count(*)::bigint,
         coalesce(sum(l.investment_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.stage_gate_portfolio_r3481 l
  group by l.gate_decision
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3481_gate_decision_rollup() from public, anon;
grant execute on function public.founder_r3481_gate_decision_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3481_category_scorecard()
returns table(
  category text,
  total_projects bigint,
  go_count bigint,
  conditional_count bigint,
  no_go_count bigint,
  avg_strategic_score numeric,
  avg_risk_score numeric,
  total_investment_rupees numeric,
  go_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.gate_decision = 'go')::bigint,
    count(*) filter (where l.gate_decision = 'conditional_go')::bigint,
    count(*) filter (where l.gate_decision = 'no_go')::bigint,
    round(avg(l.strategic_score), 1),
    round(avg(l.risk_score), 1),
    coalesce(sum(l.investment_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.gate_decision = 'go')::numeric / nullif(count(*),0), 1)
  from public.stage_gate_portfolio_r3481 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3481_category_scorecard() from public, anon;
grant execute on function public.founder_r3481_category_scorecard() to authenticated;

-- 3) Gate-stage x gate-decision matrix
create or replace function public.founder_r3481_stage_decision_matrix()
returns table(gate_stage text, gate_decision text, projects bigint, total_investment_rupees numeric, avg_roi_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.gate_stage, l.gate_decision, count(*)::bigint,
    coalesce(sum(l.investment_rupees),0)::numeric,
    round(avg(l.expected_roi_pct), 2)
  from public.stage_gate_portfolio_r3481 l
  group by l.gate_stage, l.gate_decision
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3481_stage_decision_matrix() from public, anon;
grant execute on function public.founder_r3481_stage_decision_matrix() to authenticated;

-- 4) Monthly gate-progress trend (by target gate date)
create or replace function public.founder_r3481_monthly_gate_trend()
returns table(gate_month date, projects bigint, go_count bigint, no_go_count bigint, hold_count bigint, total_investment_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.target_gate_date)::date,
    count(*)::bigint,
    count(*) filter (where l.gate_decision = 'go')::bigint,
    count(*) filter (where l.gate_decision = 'no_go')::bigint,
    count(*) filter (where l.gate_decision = 'hold')::bigint,
    coalesce(sum(l.investment_rupees),0)::numeric
  from public.stage_gate_portfolio_r3481 l
  where l.target_gate_date is not null
  group by date_trunc('month', l.target_gate_date)
  order by date_trunc('month', l.target_gate_date) desc;
end;
$$;

revoke execute on function public.founder_r3481_monthly_gate_trend() from public, anon;
grant execute on function public.founder_r3481_monthly_gate_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3481_capa_status_board()
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
  from public.stage_gate_portfolio_capa_actions_r3481 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3481_capa_status_board() from public, anon;
grant execute on function public.founder_r3481_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3481_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.stage_gate_portfolio_capa_actions_r3481)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.stage_gate_portfolio_capa_actions_r3481 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3481_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3481_root_cause_pareto() to authenticated;

-- 7) Investment-impact digest
create or replace function public.founder_r3481_investment_impact_digest()
returns table(investment_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.investment_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.stage_gate_portfolio_capa_actions_r3481 c
  group by c.investment_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3481_investment_impact_digest() from public, anon;
grant execute on function public.founder_r3481_investment_impact_digest() to authenticated;

-- 8) High-risk portfolio queue (stalled / no-go / high risk-score)
create or replace function public.founder_r3481_high_risk_queue()
returns table(
  project_code text,
  project_name text,
  sponsor text,
  category text,
  gate_stage text,
  gate_decision text,
  investment_rupees numeric,
  strategic_score int,
  risk_score int,
  priority_rank int,
  target_gate_date date,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.project_code, l.project_name, l.sponsor, l.category, l.gate_stage,
    l.gate_decision, l.investment_rupees, l.strategic_score, l.risk_score, l.priority_rank,
    l.target_gate_date, l.notes
  from public.stage_gate_portfolio_r3481 l
  where l.gate_decision in ('no_go','hold','recycle')
     or l.gate_stage in ('on_hold','killed')
     or l.risk_score >= 7
  order by l.risk_score desc, l.priority_rank asc;
end;
$$;

revoke execute on function public.founder_r3481_high_risk_queue() from public, anon;
grant execute on function public.founder_r3481_high_risk_queue() to authenticated;
