-- Round 3615: Founder Reinvestment / Retention-Ratio (Plough-Back) Board
-- Founder finance — earnings retention / reinvestment (plough-back) ratio × business unit ×
-- net profit × dividends × retained earnings × capex reinvested × reinvestment ratio × target ×
-- growth rate × ROE × reinvestment status × trend × CAPA

-- =============================================================================
-- TABLE 1: reinvest_ratio_r3615 — per-business-unit / per-month reinvestment ratio facts
-- =============================================================================
create table if not exists public.reinvest_ratio_r3615 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_code text not null,
  business_unit text not null check (business_unit in (
    'amc_services','spare_parts','projects','diagnostics','rentals','refurbishment'
  )),
  period_month date not null,
  net_profit_rupees numeric(14,2) not null,
  dividends_paid_rupees numeric(14,2) not null,
  retained_earnings_rupees numeric(14,2) not null,
  retention_ratio_pct numeric(6,2) not null,
  capex_reinvested_rupees numeric(14,2) not null,
  reinvestment_ratio_pct numeric(6,2) not null,
  target_reinvestment_pct numeric(6,2) not null,
  growth_rate_pct numeric(6,2),
  roe_pct numeric(6,2),
  reinvestment_status text not null check (reinvestment_status in (
    'growth_reinvesting','balanced','under_reinvesting','over_distributing','starving'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.reinvest_ratio_r3615 enable row level security;

create index if not exists idx_reinvest_ratio_r3615_org on public.reinvest_ratio_r3615(organization_id);
create index if not exists idx_reinvest_ratio_r3615_month on public.reinvest_ratio_r3615(period_month);
create index if not exists idx_reinvest_ratio_r3615_status on public.reinvest_ratio_r3615(reinvestment_status);

-- =============================================================================
-- TABLE 2: reinvest_ratio_capa_actions_r3615 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.reinvest_ratio_capa_actions_r3615 (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.reinvest_ratio_r3615(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'under_reinvestment','excess_distribution','negative_retained_earnings','low_roe',
    'capex_shortfall','growth_stall','target_variance','cash_starvation'
  )),
  root_cause text not null check (root_cause in (
    'high_dividend_payout','weak_profitability','capex_deferred','working_capital_drain',
    'debt_servicing_pressure','market_slowdown','board_distribution_policy','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'reduce_dividend_payout','increase_capex_allocation','defer_distribution','reallocate_to_growth_unit',
    'improve_margin_program','raise_growth_capital','revise_target_ratio','board_policy_review','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  growth_impact text not null check (growth_impact in (
    'growth_at_risk','none','internal_only','board_review','investor_flag','strategic_priority'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  estimated_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.reinvest_ratio_capa_actions_r3615 enable row level security;

create index if not exists idx_reinvest_ratio_capa_r3615_entry on public.reinvest_ratio_capa_actions_r3615(entry_id);
create index if not exists idx_reinvest_ratio_capa_r3615_status on public.reinvest_ratio_capa_actions_r3615(capa_status);

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

  -- 16 reinvestment-ratio rows
  insert into public.reinvest_ratio_r3615 (
    organization_id, entry_code, business_unit, period_month,
    net_profit_rupees, dividends_paid_rupees, retained_earnings_rupees, retention_ratio_pct,
    capex_reinvested_rupees, reinvestment_ratio_pct, target_reinvestment_pct, growth_rate_pct,
    roe_pct, reinvestment_status, trend_dir, notes
  )
  select v_org_id, q.ecode, q.bu, q.pmon::date,
    q.npf, q.divp, q.rete, q.retr,
    q.capx, q.reir, q.tgtr, q.grw,
    q.roe, q.rstat, q.tdir, q.nt
  from (values
    ('RE-AMC-2604','amc_services','2026-04-01',
     5200000,1040000,4160000,80.0,3120000,60.0,55.0,18.5,22.4,'growth_reinvesting','improving','AMC recurring surplus ploughed into service tooling and technician expansion'),
    ('RE-AMC-2605','amc_services','2026-05-01',
     5400000,1080000,4320000,80.0,3240000,60.0,55.0,19.0,23.1,'growth_reinvesting','improving','AMC reinvestment sustained above target — calibration lab capex funded'),
    ('RE-SP-2604','spare_parts','2026-04-01',
     3100000,1550000,1550000,50.0,1085000,35.0,45.0,6.2,15.0,'under_reinvesting','worsening','Spare-parts margin diverted to dividend; capex below 45% target'),
    ('RE-SP-2605','spare_parts','2026-05-01',
     3200000,1600000,1600000,50.0,1120000,35.0,45.0,5.8,14.2,'under_reinvesting','worsening','Spare-parts reinvestment stalled — inventory expansion deferred'),
    ('RE-PRJ-2604','projects','2026-04-01',
     8600000,860000,7740000,90.0,6880000,80.0,65.0,26.4,28.0,'growth_reinvesting','improving','Turnkey project unit reinvesting aggressively into new installs'),
    ('RE-PRJ-2605','projects','2026-05-01',
     9100000,910000,8190000,90.0,7280000,80.0,65.0,27.1,29.2,'growth_reinvesting','stable','Projects plough-back steady; new-city expansion capex on plan'),
    ('RE-DIA-2604','diagnostics','2026-04-01',
     4400000,2200000,2200000,50.0,1980000,45.0,45.0,9.0,16.5,'balanced','stable','Diagnostics unit balanced payout vs reinvestment at target'),
    ('RE-DIA-2605','diagnostics','2026-05-01',
     4500000,2250000,2250000,50.0,2025000,45.0,45.0,9.3,16.8,'balanced','stable','Diagnostics reinvestment held at target — analyser refresh funded'),
    ('RE-RNT-2604','rentals','2026-04-01',
     2600000,2340000,260000,10.0,130000,5.0,40.0,1.2,8.5,'over_distributing','worsening','Rental unit distributing nearly all profit; fleet renewal starved'),
    ('RE-RNT-2605','rentals','2026-05-01',
     2500000,2250000,250000,10.0,125000,5.0,40.0,0.8,8.0,'over_distributing','worsening','Rentals payout again near 90% — fleet ageing risk rising'),
    ('RE-RFB-2604','refurbishment','2026-04-01',
     1800000,0,1800000,100.0,360000,20.0,50.0,2.5,9.2,'starving','worsening','Refurb unit retains all profit but underinvests — capex starved'),
    ('RE-RFB-2605','refurbishment','2026-05-01',
     1700000,0,1700000,100.0,340000,20.0,50.0,2.0,8.8,'starving','worsening','Refurb capex far below target despite full retention — cash trapped'),
    ('RE-AMC-2606','amc_services','2026-06-01',
     5600000,1120000,4480000,80.0,3360000,60.0,55.0,19.5,23.6,'growth_reinvesting','improving','AMC unit continues to lead plough-back — spares depot capex added'),
    ('RE-SP-2606','spare_parts','2026-06-01',
     3300000,1485000,1815000,55.0,1320000,40.0,45.0,7.0,15.4,'under_reinvesting','stable','Spare-parts reinvestment improving but still below 45% target'),
    ('RE-PRJ-2606','projects','2026-06-01',
     9400000,940000,8460000,90.0,7520000,80.0,65.0,28.0,30.1,'growth_reinvesting','improving','Projects ROE crosses 30% — reinvestment cycle compounding'),
    ('RE-DIA-2606','diagnostics','2026-06-01',
     4700000,1880000,2820000,60.0,2350000,50.0,45.0,11.0,17.6,'balanced','improving','Diagnostics stepping up reinvestment above target — new lab line')
  ) as q(ecode, bu, pmon, npf, divp, rete, retr, capx, reir, tgtr, grw, roe, rstat, tdir, nt);

  -- CAPA seed — attach to specific entries via entry_code
  insert into public.reinvest_ratio_capa_actions_r3615 (
    entry_id, finding_category, root_cause, corrective_action,
    capa_status, growth_impact, owner, target_closure_date, actual_closure_date,
    estimated_impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.gi, q.ownr, q.tcd::date, q.acd::date,
    q.imp, q.nt
  from (values
    ('RE-SP-2604','under_reinvestment','high_dividend_payout','reduce_dividend_payout','in_progress','board_review','Ravi Menon (CFO)','2026-06-15',null,1085000,'Spare-parts payout too high vs target — dividend policy under review'),
    ('RE-RNT-2604','excess_distribution','board_distribution_policy','defer_distribution','open','investor_flag','Priya Nair (Finance Controller)','2026-06-20',null,2210000,'Rental fleet renewal starved by over-distribution — defer next payout'),
    ('RE-RFB-2604','capex_shortfall','capex_deferred','increase_capex_allocation','open','growth_at_risk','Anil Kumar (Ops Head)','2026-06-30',null,1440000,'Refurb capex far below target — allocate growth budget'),
    ('RE-RFB-2605','cash_starvation','working_capital_drain','raise_growth_capital','escalated','strategic_priority','Anil Kumar (Ops Head)','2026-06-25',null,1360000,'Refurb unit cash-starved — escalate for growth-capital infusion'),
    ('RE-SP-2605','target_variance','weak_profitability','improve_margin_program','verification_pending','internal_only','Ravi Menon (CFO)','2026-06-18',null,1120000,'Spare-parts margin program running — verify next-month reinvestment'),
    ('RE-RNT-2605','growth_stall','market_slowdown','reallocate_to_growth_unit','overdue','board_review','Priya Nair (Finance Controller)','2026-06-10',null,2250000,'Rental growth stalled — reallocation past target date'),
    ('RE-SP-2606','under_reinvestment','capex_deferred','revise_target_ratio','closed','internal_only','Ravi Menon (CFO)','2026-06-28','2026-06-27',990000,'Spare-parts reinvestment target revised and capex restored — closed'),
    ('RE-DIA-2604','low_roe','high_dividend_payout','board_policy_review','closed','none','Priya Nair (Finance Controller)','2026-06-05','2026-06-04',0,'Diagnostics ROE reviewed; balanced policy confirmed — no further action')
  ) as q(ecode, fc, rc, ca, cst, gi, ownr, tcd, acd, imp, nt)
  join public.reinvest_ratio_r3615 e
    on e.organization_id = v_org_id and e.entry_code = q.ecode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reinvestment status distribution
create or replace function public.founder_r3615_reinvestment_status_rollup()
returns table(reinvestment_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.reinvest_ratio_r3615)
  select l.reinvestment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.reinvest_ratio_r3615 l
  group by l.reinvestment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3615_reinvestment_status_rollup() from public, anon;
grant execute on function public.founder_r3615_reinvestment_status_rollup() to authenticated;

-- 2) Business-unit reinvestment scorecard
create or replace function public.founder_r3615_business_unit_scorecard()
returns table(
  business_unit text,
  total_entries bigint,
  net_profit_rupees numeric,
  retained_earnings_rupees numeric,
  capex_reinvested_rupees numeric,
  avg_retention_ratio_pct numeric,
  avg_reinvestment_ratio_pct numeric,
  avg_roe_pct numeric,
  under_reinvesting bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit,
    count(*)::bigint,
    coalesce(sum(l.net_profit_rupees),0)::numeric,
    coalesce(sum(l.retained_earnings_rupees),0)::numeric,
    coalesce(sum(l.capex_reinvested_rupees),0)::numeric,
    round(avg(l.retention_ratio_pct), 1),
    round(avg(l.reinvestment_ratio_pct), 1),
    round(avg(l.roe_pct), 1),
    count(*) filter (where l.reinvestment_status in ('under_reinvesting','starving','over_distributing'))::bigint
  from public.reinvest_ratio_r3615 l
  group by l.business_unit
  order by coalesce(sum(l.net_profit_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3615_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3615_business_unit_scorecard() to authenticated;

-- 3) Business-unit × reinvestment-status matrix
create or replace function public.founder_r3615_business_unit_status_matrix()
returns table(business_unit text, reinvestment_status text, entries bigint, avg_reinvestment_ratio_pct numeric, avg_growth_rate_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.reinvestment_status, count(*)::bigint,
    round(avg(l.reinvestment_ratio_pct), 1),
    round(avg(l.growth_rate_pct), 1)
  from public.reinvest_ratio_r3615 l
  group by l.business_unit, l.reinvestment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3615_business_unit_status_matrix() from public, anon;
grant execute on function public.founder_r3615_business_unit_status_matrix() to authenticated;

-- 4) Monthly reinvestment trend
create or replace function public.founder_r3615_monthly_reinvestment_trend()
returns table(period_month date, entries bigint, avg_retention_ratio_pct numeric, avg_reinvestment_ratio_pct numeric, total_capex_reinvested_rupees numeric, under_reinvesting bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.retention_ratio_pct), 1),
    round(avg(l.reinvestment_ratio_pct), 1),
    coalesce(sum(l.capex_reinvested_rupees),0)::numeric,
    count(*) filter (where l.reinvestment_status in ('under_reinvesting','starving'))::bigint
  from public.reinvest_ratio_r3615 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3615_monthly_reinvestment_trend() from public, anon;
grant execute on function public.founder_r3615_monthly_reinvestment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3615_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.reinvest_ratio_capa_actions_r3615 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3615_capa_status_board() from public, anon;
grant execute on function public.founder_r3615_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3615_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.reinvest_ratio_capa_actions_r3615)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.reinvest_ratio_capa_actions_r3615 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3615_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3615_root_cause_pareto() to authenticated;

-- 7) Growth-impact digest
create or replace function public.founder_r3615_growth_impact_digest()
returns table(growth_impact text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.growth_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric
  from public.reinvest_ratio_capa_actions_r3615 c
  group by c.growth_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3615_growth_impact_digest() from public, anon;
grant execute on function public.founder_r3615_growth_impact_digest() to authenticated;

-- 8) High-risk reinvestment queue (starving / under-reinvesting / over-distributing)
create or replace function public.founder_r3615_high_risk_queue()
returns table(
  business_unit text,
  entry_code text,
  period_month date,
  reinvestment_status text,
  retention_ratio_pct numeric,
  reinvestment_ratio_pct numeric,
  target_reinvestment_pct numeric,
  roe_pct numeric,
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
  select l.business_unit, l.entry_code, l.period_month, l.reinvestment_status,
    l.retention_ratio_pct, l.reinvestment_ratio_pct, l.target_reinvestment_pct, l.roe_pct, l.trend_dir, l.notes
  from public.reinvest_ratio_r3615 l
  where l.reinvestment_status in ('starving','under_reinvesting','over_distributing')
     or l.reinvestment_ratio_pct < l.target_reinvestment_pct
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3615_high_risk_queue() from public, anon;
grant execute on function public.founder_r3615_high_risk_queue() to authenticated;
