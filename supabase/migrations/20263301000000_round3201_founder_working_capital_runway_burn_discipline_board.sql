-- Round 3201: Founder Working-Capital Runway & Burn-Discipline Board
-- Monthly runway ledger — opening cash × collections × gross/net burn × runway months × burn multiple × variance vs plan × discipline verdict × CAPA

-- =============================================================================
-- TABLE 1: runway_burn_r3201 — monthly working-capital runway & burn log
-- =============================================================================
create table if not exists public.runway_burn_r3201 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_name text not null,
  board_ref text not null,
  period_month date not null,
  opening_cash_lakhs numeric(12,2) not null,
  collections_lakhs numeric(12,2) not null,
  gross_burn_lakhs numeric(12,2) not null,
  net_burn_lakhs numeric(12,2) not null,
  closing_cash_lakhs numeric(12,2),
  runway_months numeric(5,1),
  burn_multiple numeric(5,2),
  variance_vs_plan_pct numeric(6,2),
  burn_category text not null check (burn_category in (
    'payroll_heavy','inventory_buildup','marketing_spend','capex_expansion',
    'debt_service','balanced_opex','one_time_settlement','receivables_slippage'
  )),
  collections_health text not null check (collections_health in (
    'ahead_of_plan','on_plan','minor_slippage','major_slippage','collections_freeze'
  )),
  runway_band text not null check (runway_band in (
    'above_24_months','12_to_24_months','6_to_12_months','3_to_6_months','below_3_months'
  )),
  discipline_verdict text not null check (discipline_verdict in (
    'exemplary','disciplined','watch','recovering','overspend','critical_overspend'
  )),
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.runway_burn_r3201 enable row level security;

create index if not exists idx_runway_burn_r3201_org on public.runway_burn_r3201(organization_id);
create index if not exists idx_runway_burn_r3201_month on public.runway_burn_r3201(period_month);
create index if not exists idx_runway_burn_r3201_verdict on public.runway_burn_r3201(discipline_verdict);

-- =============================================================================
-- TABLE 2: runway_burn_capa_actions_r3201 — burn-discipline CAPA actions
-- =============================================================================
create table if not exists public.runway_burn_capa_actions_r3201 (
  id uuid primary key default gen_random_uuid(),
  runway_burn_id uuid not null references public.runway_burn_r3201(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'burn_overrun','collections_slippage','runway_breach','plan_variance_breach',
    'burn_multiple_deterioration','vendor_cost_creep','payroll_overrun','discretionary_spend_leak'
  )),
  root_cause text not null check (root_cause in (
    'headcount_ahead_of_plan','discount_heavy_deals','receivables_aging',
    'vendor_price_escalation','marketing_cac_overrun','unbudgeted_capex',
    'fx_or_interest_costs','forecast_model_error','one_time_legal_settlement','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'hiring_freeze','renegotiate_vendor_contracts','collections_task_force',
    'cut_discretionary_marketing','defer_capex','tighten_credit_terms',
    'rebuild_forecast_model','bridge_financing','zero_based_budget_reset','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'board_reportable','investor_covenant_breach','statutory_dues_risk','audit_flag','internal_only','none'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.runway_burn_capa_actions_r3201 enable row level security;

create index if not exists idx_runway_capa_r3201_parent on public.runway_burn_capa_actions_r3201(runway_burn_id);
create index if not exists idx_runway_capa_r3201_status on public.runway_burn_capa_actions_r3201(capa_status);

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

  -- 13 monthly runway ledger rows
  insert into public.runway_burn_r3201 (
    organization_id, entity_name, board_ref, period_month,
    opening_cash_lakhs, collections_lakhs, gross_burn_lakhs, net_burn_lakhs, closing_cash_lakhs,
    runway_months, burn_multiple, variance_vs_plan_pct,
    burn_category, collections_health, runway_band, discipline_verdict,
    reviewed_at, notes
  )
  select v_org_id, q.ent, q.ref, q.pm::date,
    q.oc, q.cl, q.gb, q.nb, q.cc,
    q.rm, q.bm, q.vp,
    q.bc, q.ch, q.rb, q.dv,
    q.rev::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','RWB-APL-2606','2026-06-01',420.00,96.50,78.00,-18.50,438.50,30.0,0.62,-4.20,
     'balanced_opex','ahead_of_plan','above_24_months','exemplary','2026-07-02 10:00:00+05:30','Collections beat plan; cash-accretive month'),
    ('Apollo Hyderabad Jubilee Hills','RWB-APL-2607','2026-07-01',438.50,88.00,92.00,4.00,434.50,28.5,0.90,6.10,
     'payroll_heavy','on_plan','above_24_months','disciplined','2026-07-15 10:30:00+05:30','Annual increments landed; within tolerance'),
    ('Fortis Bannerghatta Bengaluru','RWB-FRT-2606','2026-06-01',310.00,54.00,88.00,34.00,276.00,8.1,2.40,18.70,
     'marketing_spend','minor_slippage','6_to_12_months','overspend','2026-07-03 11:00:00+05:30','CAC overrun on south-cluster campaign'),
    ('Fortis Bannerghatta Bengaluru','RWB-FRT-2607','2026-07-01',276.00,49.50,95.50,46.00,230.00,5.0,2.95,27.40,
     'marketing_spend','major_slippage','3_to_6_months','critical_overspend','2026-07-16 09:15:00+05:30','Runway below 6 months; spend freeze proposed'),
    ('Manipal Whitefield Bengaluru','RWB-MNP-2606','2026-06-01',265.00,72.00,81.00,9.00,256.00,14.2,1.10,3.90,
     'inventory_buildup','on_plan','12_to_24_months','disciplined','2026-07-02 15:00:00+05:30','Spare-parts inventory build for AMC season'),
    ('Manipal Whitefield Bengaluru','RWB-MNP-2607','2026-07-01',256.00,61.00,90.50,29.50,226.50,7.7,1.85,14.60,
     'inventory_buildup','minor_slippage','6_to_12_months','watch','2026-07-16 14:20:00+05:30','Inventory ahead of consumption; receivables aging up'),
    ('AIIMS New Delhi Ansari Nagar','RWB-AIM-2606','2026-06-01',512.00,120.00,84.00,-36.00,548.00,36.0,0.55,-8.30,
     'balanced_opex','ahead_of_plan','above_24_months','exemplary','2026-07-01 12:00:00+05:30','GeM tender collections landed early'),
    ('AIIMS New Delhi Ansari Nagar','RWB-AIM-2607','2026-07-01',548.00,64.00,86.00,22.00,526.00,23.9,1.35,9.80,
     'debt_service','minor_slippage','12_to_24_months','watch','2026-07-17 10:45:00+05:30','Two government invoices slipped to Q3'),
    ('KIMS Secunderabad','RWB-KIM-2607','2026-07-01',198.00,41.00,76.50,35.50,162.50,4.6,2.60,22.10,
     'capex_expansion','major_slippage','3_to_6_months','critical_overspend','2026-07-15 16:00:00+05:30','Unbudgeted cath-lab tooling capex hit'),
    ('Care Hospitals Banjara Hills','RWB-CAR-2607','2026-07-01',240.00,58.00,66.00,8.00,232.00,29.0,1.05,2.40,
     'balanced_opex','on_plan','above_24_months','disciplined','2026-07-14 11:30:00+05:30','Steady month; plan variance within 5 percent'),
    ('Yashoda Somajiguda Hyderabad','RWB-YSH-2607','2026-07-01',175.00,47.50,71.00,23.50,151.50,6.4,1.95,12.90,
     'one_time_settlement','minor_slippage','6_to_12_months','watch','2026-07-13 09:40:00+05:30','Vendor arbitration settlement paid out'),
    ('St John''s Bengaluru','RWB-STJ-2607','2026-07-01',142.00,39.00,58.50,19.50,122.50,6.3,1.70,8.20,
     'payroll_heavy','on_plan','6_to_12_months','recovering','2026-07-12 17:10:00+05:30','Post-freeze payroll normalizing; second clean month'),
    ('Rainbow Children''s Hyderabad','RWB-RBW-2607','2026-07-01',96.00,22.00,49.00,27.00,69.00,2.6,3.40,31.60,
     'receivables_slippage','collections_freeze','below_3_months','critical_overspend',null,'TPA reconciliation dispute froze collections')
  ) as q(ent, ref, pm, oc, cl, gb, nb, cc, rm, bm, vp, bc, ch, rb, dv, rev, nt);

  -- 6 CAPA action rows — attach to specific ledger rows via board_ref
  insert into public.runway_burn_capa_actions_r3201 (
    runway_burn_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cs, q.ri, q.cost, q.nt
  from (values
    ('RWB-FRT-2607','burn_overrun','marketing_cac_overrun','cut_discretionary_marketing','2026-07-25',null,'in_progress','board_reportable',150000.00,'Paid-media freeze for south cluster; CFO sign-off weekly'),
    ('RWB-FRT-2607','runway_breach','forecast_model_error','bridge_financing','2026-08-10',null,'escalated','investor_covenant_breach',250000.00,'Venture-debt bridge term sheet under negotiation'),
    ('RWB-KIM-2607','plan_variance_breach','unbudgeted_capex','defer_capex','2026-07-30',null,'open','audit_flag',80000.00,'Cath-lab tooling deferred to Q4 board cycle'),
    ('RWB-RBW-2607','collections_slippage','receivables_aging','collections_task_force','2026-07-22',null,'overdue','statutory_dues_risk',60000.00,'TPA dispute war room; TDS remittance ring-fenced'),
    ('RWB-MNP-2607','burn_multiple_deterioration','headcount_ahead_of_plan','hiring_freeze','2026-08-05',null,'in_progress','internal_only',0.00,'Backfill-only policy till burn multiple under 1.5'),
    ('RWB-STJ-2607','discretionary_spend_leak','vendor_price_escalation','renegotiate_vendor_contracts','2026-07-18','2026-07-15','closed','none',35000.00,'Courier and travel vendors re-tendered; 11 percent saved')
  ) as q(ref, fc, rc, ca, tcd, acd, cs, ri, cost, nt)
  join public.runway_burn_r3201 e
    on e.organization_id = v_org_id and e.board_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Discipline verdict distribution
create or replace function public.founder_r3201_discipline_verdict_rollup()
returns table(discipline_verdict text, months bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.runway_burn_r3201)
  select l.discipline_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.runway_burn_r3201 l
  group by l.discipline_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3201_discipline_verdict_rollup() from public, anon;
grant execute on function public.founder_r3201_discipline_verdict_rollup() to authenticated;

-- 2) Entity-level runway scorecard
create or replace function public.founder_r3201_entity_scorecard()
returns table(
  entity_name text,
  months_tracked bigint,
  total_collections_lakhs numeric,
  total_gross_burn_lakhs numeric,
  total_net_burn_lakhs numeric,
  avg_burn_multiple numeric,
  avg_variance_pct numeric,
  disciplined_months bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    coalesce(sum(l.collections_lakhs),0)::numeric,
    coalesce(sum(l.gross_burn_lakhs),0)::numeric,
    coalesce(sum(l.net_burn_lakhs),0)::numeric,
    round(avg(l.burn_multiple), 2),
    round(avg(l.variance_vs_plan_pct), 1),
    count(*) filter (where l.discipline_verdict in ('exemplary','disciplined'))::bigint
  from public.runway_burn_r3201 l
  group by l.entity_name
  order by count(*) desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3201_entity_scorecard() from public, anon;
grant execute on function public.founder_r3201_entity_scorecard() to authenticated;

-- 3) Burn category × collections health matrix
create or replace function public.founder_r3201_burn_category_matrix()
returns table(burn_category text, collections_health text, months bigint, avg_net_burn_lakhs numeric, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.burn_category, l.collections_health, count(*)::bigint,
    round(avg(l.net_burn_lakhs), 2),
    round(avg(l.variance_vs_plan_pct), 1)
  from public.runway_burn_r3201 l
  group by l.burn_category, l.collections_health
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3201_burn_category_matrix() from public, anon;
grant execute on function public.founder_r3201_burn_category_matrix() to authenticated;

-- 4) Monthly cash & burn trend
create or replace function public.founder_r3201_monthly_trend()
returns table(period_month date, entities bigint, total_collections_lakhs numeric, total_gross_burn_lakhs numeric, total_net_burn_lakhs numeric, avg_burn_multiple numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(distinct l.entity_name)::bigint,
    coalesce(sum(l.collections_lakhs),0)::numeric,
    coalesce(sum(l.gross_burn_lakhs),0)::numeric,
    coalesce(sum(l.net_burn_lakhs),0)::numeric,
    round(avg(l.burn_multiple), 2)
  from public.runway_burn_r3201 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3201_monthly_trend() from public, anon;
grant execute on function public.founder_r3201_monthly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3201_capa_status_board()
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
  from public.runway_burn_capa_actions_r3201 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3201_capa_status_board() from public, anon;
grant execute on function public.founder_r3201_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3201_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.runway_burn_capa_actions_r3201)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.runway_burn_capa_actions_r3201 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3201_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3201_root_cause_pareto() to authenticated;

-- 7) Regulatory / governance impact digest
create or replace function public.founder_r3201_regulatory_impact_digest()
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
  from public.runway_burn_capa_actions_r3201 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3201_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3201_regulatory_impact_digest() to authenticated;

-- 8) High-risk runway queue (top individual concerns)
create or replace function public.founder_r3201_high_risk_queue()
returns table(
  entity_name text,
  board_ref text,
  period_month date,
  closing_cash_lakhs numeric,
  runway_months numeric,
  burn_multiple numeric,
  variance_vs_plan_pct numeric,
  discipline_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name, l.board_ref, l.period_month,
    l.closing_cash_lakhs, l.runway_months, l.burn_multiple, l.variance_vs_plan_pct,
    l.discipline_verdict, l.notes
  from public.runway_burn_r3201 l
  where l.discipline_verdict in ('overspend','critical_overspend')
     or l.runway_band in ('below_3_months','3_to_6_months')
     or l.collections_health in ('major_slippage','collections_freeze')
  order by l.period_month desc, l.runway_months asc nulls last, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3201_high_risk_queue() from public, anon;
grant execute on function public.founder_r3201_high_risk_queue() to authenticated;
