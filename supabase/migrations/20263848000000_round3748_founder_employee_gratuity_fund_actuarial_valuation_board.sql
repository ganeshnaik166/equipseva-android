-- Round 3748: Founder Employee Gratuity Fund Actuarial Valuation Board
-- Employee gratuity defined-benefit obligation — actuarial valuation (Ind AS 19), fund
-- adequacy, discount-rate sensitivity, funding gap per entity. Distinct from any
-- employee-exit full-final-settlement-gratuity page, which is per-employee EXIT settlement
-- processing/TAT, not company-wide actuarial fund valuation.

-- =============================================================================
-- TABLE 1: gratuity_actuarial_r3748 — per-entity actuarial valuation facts
-- =============================================================================
create table if not exists public.gratuity_actuarial_r3748 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  valuation_date text not null,
  period_month date not null,
  defined_benefit_obligation_rupees numeric(14,2),
  fair_value_plan_assets_rupees numeric(14,2),
  funding_gap_rupees numeric(14,2),
  discount_rate_pct numeric,
  actuarial_gain_loss_rupees numeric(12,2),
  employees_covered int,
  contribution_made_rupees numeric(12,2),
  valuer_name text,
  valuation_class text not null check (valuation_class in (
    'annual_actuarial','interim_review','ind_as19_disclosure','fund_adequacy_test','sensitivity_analysis'
  )),
  funding_status text not null check (funding_status in (
    'fully_funded','adequately_funded','funding_gap','significant_deficit','valuation_overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gratuity_actuarial_r3748 enable row level security;

create index if not exists idx_gratuity_actuarial_r3748_org on public.gratuity_actuarial_r3748(organization_id);
create index if not exists idx_gratuity_actuarial_r3748_month on public.gratuity_actuarial_r3748(period_month);
create index if not exists idx_gratuity_actuarial_r3748_status on public.gratuity_actuarial_r3748(funding_status);

-- =============================================================================
-- TABLE 2: gratuity_actuarial_capa_actions_r3748 — CAPA for funding-gap/overdue findings
-- =============================================================================
create table if not exists public.gratuity_actuarial_capa_actions_r3748 (
  id uuid primary key default gen_random_uuid(),
  valuation_id uuid references public.gratuity_actuarial_r3748(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gratuity_actuarial_capa_actions_r3748 enable row level security;

create index if not exists idx_gratuity_actuarial_capa_r3748_main on public.gratuity_actuarial_capa_actions_r3748(valuation_id);
create index if not exists idx_gratuity_actuarial_capa_r3748_status on public.gratuity_actuarial_capa_actions_r3748(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Funding-status distribution
create or replace function public.founder_r3748_funding_status_rollup()
returns table(funding_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gratuity_actuarial_r3748)
  select l.funding_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gratuity_actuarial_r3748 l
  group by l.funding_status
  order by count(*) desc;
end;
$$;

-- 2) Entity scorecard
create or replace function public.founder_r3748_entity_scorecard()
returns table(
  entity_name text,
  records bigint,
  fully_funded bigint,
  adequately_funded bigint,
  funding_gap bigint,
  significant_deficit bigint,
  valuation_overdue bigint,
  total_dbo_rupees numeric,
  total_fva_rupees numeric,
  avg_discount_rate_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.funding_status = 'fully_funded')::bigint,
    count(*) filter (where l.funding_status = 'adequately_funded')::bigint,
    count(*) filter (where l.funding_status = 'funding_gap')::bigint,
    count(*) filter (where l.funding_status = 'significant_deficit')::bigint,
    count(*) filter (where l.funding_status = 'valuation_overdue')::bigint,
    coalesce(sum(l.defined_benefit_obligation_rupees), 0)::numeric,
    coalesce(sum(l.fair_value_plan_assets_rupees), 0)::numeric,
    round(avg(l.discount_rate_pct), 2)
  from public.gratuity_actuarial_r3748 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

-- 3) Valuation-class x funding-status matrix
create or replace function public.founder_r3748_valuation_class_status_matrix()
returns table(valuation_class text, funding_status text, records bigint, avg_funding_gap_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.valuation_class, l.funding_status, count(*)::bigint,
    round(avg(l.funding_gap_rupees), 2)
  from public.gratuity_actuarial_r3748 l
  group by l.valuation_class, l.funding_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly funding-gap trend
create or replace function public.founder_r3748_monthly_funding_gap_trend()
returns table(
  period_month date,
  records bigint,
  total_dbo_rupees numeric,
  total_fva_rupees numeric,
  total_funding_gap_rupees numeric,
  significant_deficit_records bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.defined_benefit_obligation_rupees), 0)::numeric,
    coalesce(sum(l.fair_value_plan_assets_rupees), 0)::numeric,
    coalesce(sum(l.funding_gap_rupees), 0)::numeric,
    count(*) filter (where l.funding_status = 'significant_deficit')::bigint
  from public.gratuity_actuarial_r3748 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3748_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.gratuity_actuarial_capa_actions_r3748 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3748_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gratuity_actuarial_capa_actions_r3748)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.gratuity_actuarial_capa_actions_r3748 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Deficit digest — entities currently in funding-gap or significant-deficit status
create or replace function public.founder_r3748_deficit_digest()
returns table(
  entity_name text,
  records bigint,
  funding_gap_records bigint,
  significant_deficit_records bigint,
  avg_funding_gap_rupees numeric,
  total_funding_gap_rupees numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.funding_status = 'funding_gap')::bigint,
    count(*) filter (where l.funding_status = 'significant_deficit')::bigint,
    round(avg(l.funding_gap_rupees), 2),
    coalesce(sum(l.funding_gap_rupees), 0)::numeric
  from public.gratuity_actuarial_r3748 l
  where l.funding_status in ('funding_gap','significant_deficit')
  group by l.entity_name
  order by coalesce(sum(l.funding_gap_rupees), 0) desc;
end;
$$;

-- 8) High-risk queue (significant deficit / overdue valuation, worst first)
create or replace function public.founder_r3748_high_risk_queue()
returns table(
  entity_name text,
  valuation_date text,
  period_month date,
  valuation_class text,
  funding_status text,
  funding_gap_rupees numeric,
  discount_rate_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.valuation_date, l.period_month, l.valuation_class,
    l.funding_status, l.funding_gap_rupees, l.discount_rate_pct, l.notes
  from public.gratuity_actuarial_r3748 l
  where l.funding_status in ('significant_deficit','valuation_overdue')
  order by l.funding_gap_rupees desc nulls last, l.period_month desc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants — founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3748_funding_status_rollup() from public, anon;
revoke all on function public.founder_r3748_entity_scorecard() from public, anon;
revoke all on function public.founder_r3748_valuation_class_status_matrix() from public, anon;
revoke all on function public.founder_r3748_monthly_funding_gap_trend() from public, anon;
revoke all on function public.founder_r3748_capa_status_board() from public, anon;
revoke all on function public.founder_r3748_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3748_deficit_digest() from public, anon;
revoke all on function public.founder_r3748_high_risk_queue() from public, anon;

grant execute on function public.founder_r3748_funding_status_rollup() to authenticated;
grant execute on function public.founder_r3748_entity_scorecard() to authenticated;
grant execute on function public.founder_r3748_valuation_class_status_matrix() to authenticated;
grant execute on function public.founder_r3748_monthly_funding_gap_trend() to authenticated;
grant execute on function public.founder_r3748_capa_status_board() to authenticated;
grant execute on function public.founder_r3748_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3748_deficit_digest() to authenticated;
grant execute on function public.founder_r3748_high_risk_queue() to authenticated;

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

  -- 16 actuarial valuation rows across entities, valuation classes, funding statuses & months
  insert into public.gratuity_actuarial_r3748 (
    organization_id, entity_name, valuation_date, period_month,
    defined_benefit_obligation_rupees, fair_value_plan_assets_rupees, funding_gap_rupees,
    discount_rate_pct, actuarial_gain_loss_rupees, employees_covered, contribution_made_rupees,
    valuer_name, valuation_class, funding_status, trend_dir, notes
  )
  select v_org_id, q.en, q.vd, q.pm::date,
    q.dbo, q.fva, q.fg,
    q.drp, q.agl, q.ec, q.cm,
    q.vn, q.vc, q.fs, q.td, q.nt
  from (values
    ('EquipSeva Industries Pvt Ltd','2026-03-31','2026-03-01',48500000.00,46200000.00,2300000.00,7.15,-850000.00,620,3200000.00,'K.Subramanian & Associates','annual_actuarial','adequately_funded','stable','FY26 annual valuation under Ind AS 19 — mortality table updated to IALM 2012-14'),
    ('EquipSeva Logistics Pvt Ltd','2026-03-31','2026-03-01',32800000.00,34500000.00,-1700000.00,7.10,620000.00,410,2100000.00,'Mercer India Actuarial Services','annual_actuarial','fully_funded','improving','Plan assets exceed DBO by Rs 17 lakh — strong equity returns in LIC group gratuity fund'),
    ('EquipSeva Rentals Pvt Ltd','2026-03-31','2026-03-01',61200000.00,48900000.00,12300000.00,7.20,-2100000.00,880,4500000.00,'K.Subramanian & Associates','annual_actuarial','funding_gap','worsening','Attrition assumption revised upward post fleet-ops attrition spike — DBO up 9% YoY'),
    ('EquipSeva Field Services Ltd','2026-03-31','2026-03-01',74500000.00,51200000.00,23300000.00,7.20,-3400000.00,1120,5100000.00,'Willis Towers Watson India','annual_actuarial','significant_deficit','worsening','Deficit widened after voluntary retirement scheme payouts exceeded plan asset draw — board flagged for top-up contribution'),
    ('EquipSeva Technologies Pvt Ltd','2026-03-31','2026-03-01',18400000.00,17900000.00,500000.00,7.10,-180000.00,240,1200000.00,'Mercer India Actuarial Services','annual_actuarial','adequately_funded','stable','Small deficit within tolerance — no additional funding action required'),
    ('EquipSeva Industries Pvt Ltd','2026-06-30','2026-06-01',49800000.00,46800000.00,3000000.00,7.05,-1300000.00,632,900000.00,'K.Subramanian & Associates','interim_review','funding_gap','worsening','Q1 interim review shows gap widening on lower discount rate — Q2 top-up under review'),
    ('EquipSeva Logistics Pvt Ltd','2026-06-30','2026-06-01',33500000.00,35100000.00,-1600000.00,7.00,410000.00,418,700000.00,'Mercer India Actuarial Services','interim_review','fully_funded','stable','Interim check confirms surplus position holding steady into Q2'),
    ('EquipSeva Rentals Pvt Ltd','2026-06-30','2026-06-01',62900000.00,49200000.00,13700000.00,7.05,-1900000.00,895,1500000.00,'K.Subramanian & Associates','interim_review','funding_gap','worsening','Gap widened further this quarter — trustee meeting scheduled to approve special contribution'),
    ('EquipSeva Field Services Ltd','2026-06-30','2026-06-01',76100000.00,51900000.00,24200000.00,7.05,-900000.00,1135,2200000.00,'Willis Towers Watson India','interim_review','significant_deficit','stable','Deficit holding near prior quarter level — special contribution plan awaiting board sign-off'),
    ('EquipSeva Industries Pvt Ltd','2026-03-31','2026-03-01',48500000.00,46200000.00,2300000.00,7.15,-850000.00,620,0.00,'K.Subramanian & Associates','ind_as19_disclosure','adequately_funded','stable','Ind AS 19 disclosure note prepared for FY26 statutory audit — actuarial assumptions table included'),
    ('EquipSeva Logistics Pvt Ltd','2026-03-31','2026-03-01',32800000.00,34500000.00,-1700000.00,7.10,620000.00,410,0.00,'Mercer India Actuarial Services','ind_as19_disclosure','fully_funded','improving','Disclosure note filed with FY26 financial statements — surplus disclosed as plan asset ceiling adjustment'),
    ('EquipSeva Rentals Pvt Ltd','2026-03-31','2026-03-01',61200000.00,48900000.00,12300000.00,7.20,-2100000.00,880,0.00,'K.Subramanian & Associates','ind_as19_disclosure','funding_gap','worsening','Auditor flagged widening deficit for enhanced disclosure under Ind AS 19 para 139'),
    ('EquipSeva Technologies Pvt Ltd','2026-07-31','2026-07-01',18600000.00,18500000.00,100000.00,7.05,-90000.00,245,300000.00,'Mercer India Actuarial Services','fund_adequacy_test','adequately_funded','stable','Quarterly fund adequacy test passed — coverage ratio at 99.5%'),
    ('EquipSeva Field Services Ltd','2026-07-31','2026-07-01',77200000.00,52400000.00,24800000.00,7.00,-1100000.00,1148,1800000.00,'Willis Towers Watson India','fund_adequacy_test','significant_deficit','worsening','Fund adequacy test fails minimum 75% coverage threshold — regulatory escalation triggered'),
    ('EquipSeva Exports Pvt Ltd','2025-03-31','2025-03-01',9200000.00,7800000.00,1400000.00,7.30,-300000.00,145,0.00,null,'annual_actuarial','valuation_overdue','worsening','FY25 valuation never refreshed — no actuarial certificate on file for 16 months, non-compliant with Ind AS 19 annual requirement'),
    ('EquipSeva Technologies Pvt Ltd','2026-07-31','2026-07-01',18700000.00,18450000.00,250000.00,7.00,-220000.00,248,400000.00,'Mercer India Actuarial Services','sensitivity_analysis','adequately_funded','stable','Sensitivity test: +/-1% discount rate shifts DBO by approx Rs 12 lakh — within board risk tolerance')
  ) as q(en, vd, pm, dbo, fva, fg, drp, agl, ec, cm, vn, vc, fs, td, nt);

  -- 8 CAPA rows — attach to valuation rows via entity_name + period_month + valuation_class
  insert into public.gratuity_actuarial_capa_actions_r3748 (
    valuation_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('EquipSeva Rentals Pvt Ltd','2026-03-01','annual_actuarial','Rising attrition and higher-than-assumed salary escalation widened DBO beyond plan asset growth','Increase employer contribution rate and revise salary escalation assumption for FY27 valuation','in_progress','Group CFO','2026-09-30',null,'Trustee board reviewing revised contribution schedule; interim funding of Rs 50 lakh approved'),
    ('EquipSeva Field Services Ltd','2026-03-01','annual_actuarial','Voluntary retirement scheme payouts drew down plan assets faster than fresh contributions replenished them','Infuse lump-sum special contribution and re-baseline mortality/attrition assumptions','open','Group CFO','2026-10-15',null,'Rs 1.5 crore special contribution proposal tabled for next board meeting'),
    ('EquipSeva Industries Pvt Ltd','2026-06-01','interim_review','Discount rate softened 10 bps against G-sec yield movement, inflating DBO at interim review','Monitor G-sec yield trend and pre-fund Q3 top-up if gap persists','in_progress','Finance Controller','2026-09-15',null,'Q2 top-up of Rs 20 lakh being processed ahead of Q3 review'),
    ('EquipSeva Rentals Pvt Ltd','2026-06-01','interim_review','Fleet-ops attrition assumption revision compounded with falling discount rate deepened funding gap quarter-on-quarter','Approve special trustee contribution and commission interim actuarial sensitivity study','overdue','Group CFO','2026-08-01',null,'Trustee meeting delayed twice — special contribution resolution now three weeks behind schedule'),
    ('EquipSeva Field Services Ltd','2026-06-01','interim_review','Deficit stable but large in absolute terms relative to plan size, requiring formal funding roadmap','Draft multi-quarter contribution roadmap to close deficit to adequately-funded threshold within 18 months','open','Group CFO','2026-11-30',null,'Roadmap draft circulated to audit committee for review'),
    ('EquipSeva Field Services Ltd','2026-07-01','fund_adequacy_test','Coverage ratio fell below regulatory 75% adequacy threshold triggering mandatory escalation','File regulatory intimation and execute emergency contribution to restore minimum coverage ratio','in_progress','Compliance Head','2026-08-31',null,'Emergency contribution of Rs 80 lakh sanctioned; regulatory filing in progress'),
    ('EquipSeva Exports Pvt Ltd','2025-03-01','annual_actuarial','Newly onboarded subsidiary did not have actuarial valuation engagement renewed after acquisition integration','Engage actuary immediately for overdue FY26 valuation and backdate Ind AS 19 disclosures','overdue','Group CFO','2026-06-30',null,'Valuer engagement letter signed in August — valuation report expected within 6 weeks'),
    ('EquipSeva Rentals Pvt Ltd','2026-03-01','ind_as19_disclosure','Widening deficit required enhanced note disclosure under Ind AS 19 para 139 not previously prepared','Prepare and file enhanced sensitivity and maturity-profile disclosures with statutory auditor','closed','Financial Reporting Lead','2026-05-15','2026-05-10','Enhanced disclosure note filed ahead of schedule; auditor sign-off obtained')
  ) as q(en, pm, vc, rc, ca, cst, ownr, tcd, acd, nt)
  join public.gratuity_actuarial_r3748 e
    on e.organization_id = v_org_id and e.entity_name = q.en and e.period_month = q.pm::date and e.valuation_class = q.vc;
end;
$seed$;
