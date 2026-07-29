-- Round 3589: Founder Debt-Service-Coverage (DSCR) / Interest-Cover / Liquidity Board
-- Founder finance QA — business unit × period × EBITDA × interest expense × principal due × debt service × DSCR ratio × target DSCR × interest cover × cash headroom × coverage status × trend × CAPA

-- =============================================================================
-- TABLE 1: dscr_board_r3589 — per business-unit / period DSCR & liquidity coverage
-- =============================================================================
create table if not exists public.dscr_board_r3589 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  board_ref text not null,
  business_unit text not null,
  period_month date not null,
  ebitda_rupees numeric(14,2),
  interest_expense_rupees numeric(14,2),
  principal_due_rupees numeric(14,2),
  debt_service_rupees numeric(14,2),
  dscr_ratio numeric(6,2),
  target_dscr numeric(6,2),
  interest_cover_ratio numeric(6,2),
  cash_headroom_rupees numeric(14,2),
  coverage_status text not null check (coverage_status in (
    'comfortable','adequate','tight','breach_risk','breached'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dscr_board_r3589 enable row level security;

create index if not exists idx_dscr_board_r3589_org on public.dscr_board_r3589(organization_id);
create index if not exists idx_dscr_board_r3589_period on public.dscr_board_r3589(period_month);
create index if not exists idx_dscr_board_r3589_status on public.dscr_board_r3589(coverage_status);

-- =============================================================================
-- TABLE 2: dscr_board_capa_actions_r3589 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.dscr_board_capa_actions_r3589 (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.dscr_board_r3589(id) on delete cascade,
  finding_ref text not null,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'dscr_below_target','interest_cover_thin','cash_headroom_low','debt_service_spike',
    'ebitda_shortfall','covenant_breach','refinance_due','principal_bullet_due'
  )),
  root_cause text not null check (root_cause in (
    'revenue_shortfall','margin_compression','rate_hike_floating_debt','working_capital_drain',
    'capex_overrun','delayed_receivables','bullet_repayment_bunching','fx_cost_increase','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'renegotiate_tenor','refinance_lower_rate','accelerate_collections','defer_capex',
    'inject_promoter_equity','draw_working_capital_line','cost_rationalization',
    'covenant_waiver_request','hedge_interest_rate','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  coverage_impact text not null check (coverage_impact in (
    'covenant_breach','lender_notifiable','internal_only','none','board_escalation','rating_watch'
  )),
  impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dscr_board_capa_actions_r3589 enable row level security;

create index if not exists idx_dscr_board_capa_r3589_board on public.dscr_board_capa_actions_r3589(board_id);
create index if not exists idx_dscr_board_capa_r3589_status on public.dscr_board_capa_actions_r3589(capa_status);

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

  -- 16 DSCR / liquidity coverage rows
  insert into public.dscr_board_r3589 (
    organization_id, board_ref, business_unit, period_month,
    ebitda_rupees, interest_expense_rupees, principal_due_rupees, debt_service_rupees,
    dscr_ratio, target_dscr, interest_cover_ratio, cash_headroom_rupees,
    coverage_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.bu, q.pm::date,
    q.ebitda, q.intexp, q.prin, q.ds,
    q.dscr, q.tgt, q.icr, q.headroom,
    q.cst, q.trd, q.nt
  from (values
    ('DSCR-MES-2604','Medical Equipment Sales','2026-04-01',
     9200000,1200000,2600000,3800000,2.42,1.50,7.67,5400000,'comfortable','improving','Equipment sales EBITDA strong; DSCR well above covenant'),
    ('DSCR-MES-2605','Medical Equipment Sales','2026-05-01',
     8800000,1250000,2600000,3850000,2.29,1.50,7.04,5100000,'comfortable','stable','Stable coverage on equipment line'),
    ('DSCR-AMC-2604','AMC & Service','2026-04-01',
     4200000,900000,1800000,2700000,1.56,1.35,4.67,2100000,'adequate','stable','AMC recurring revenue keeps DSCR adequate'),
    ('DSCR-AMC-2605','AMC & Service','2026-05-01',
     3900000,950000,1800000,2750000,1.42,1.35,4.11,1700000,'adequate','worsening','Margin compression trimming AMC coverage'),
    ('DSCR-SPR-2604','Spares & Consumables','2026-04-01',
     2600000,700000,1400000,2100000,1.24,1.25,3.71,900000,'tight','worsening','Spares DSCR slipped just under target on receivables drag'),
    ('DSCR-SPR-2605','Spares & Consumables','2026-05-01',
     2400000,720000,1400000,2120000,1.13,1.25,3.33,600000,'breach_risk','worsening','Consumables coverage nearing breach — collections lag'),
    ('DSCR-RNT-2604','Rental Fleet','2026-04-01',
     5600000,1600000,2200000,3800000,1.47,1.40,3.50,2800000,'adequate','improving','Rental utilisation recovering'),
    ('DSCR-RNT-2605','Rental Fleet','2026-05-01',
     5900000,1650000,2200000,3850000,1.53,1.40,3.58,3100000,'adequate','improving','Fleet coverage improving on higher utilisation'),
    ('DSCR-DIA-2604','Diagnostics Imaging','2026-04-01',
     7100000,2100000,3000000,5100000,1.39,1.45,3.38,2600000,'tight','worsening','Imaging capex-heavy debt service — DSCR under target'),
    ('DSCR-DIA-2605','Diagnostics Imaging','2026-05-01',
     6400000,2200000,3000000,5200000,1.23,1.45,2.91,1400000,'breach_risk','worsening','Imaging coverage at breach risk after rate hike'),
    ('DSCR-CGRP-2604','Group Consolidated','2026-04-01',
     28700000,6500000,11000000,17500000,1.64,1.35,4.42,13800000,'adequate','stable','Consolidated group DSCR adequate'),
    ('DSCR-CGRP-2605','Group Consolidated','2026-05-01',
     27400000,6770000,11000000,17770000,1.54,1.35,4.05,11900000,'adequate','worsening','Group coverage easing as unit margins soften'),
    ('DSCR-DIA-2603','Diagnostics Imaging','2026-03-01',
     6900000,1950000,3000000,4950000,1.39,1.45,3.54,2900000,'tight','stable','Prior-month imaging coverage tight'),
    ('DSCR-SPR-2606','Spares & Consumables','2026-06-01',
     2100000,760000,1400000,2160000,0.97,1.25,2.76,200000,'breached','worsening','Consumables DSCR below 1.0 — covenant breached, lender informed'),
    ('DSCR-RNT-2606','Rental Fleet','2026-06-01',
     6200000,1700000,2200000,3900000,1.59,1.40,3.65,3400000,'adequate','improving','Rental fleet DSCR strengthening'),
    ('DSCR-MES-2606','Medical Equipment Sales','2026-06-01',
     9600000,1230000,2600000,3830000,2.51,1.50,7.80,5900000,'comfortable','improving','Equipment sales best coverage of year')
  ) as q(ref, bu, pm, ebitda, intexp, prin, ds, dscr, tgt, icr, headroom, cst, trd, nt);

  -- CAPA seed — attach to specific board rows via board_ref
  insert into public.dscr_board_capa_actions_r3589 (
    board_id, finding_ref, finding_category, root_cause, corrective_action,
    capa_status, coverage_impact, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fref, q.fc, q.rc, q.ca,
    q.cst, q.ci, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DSCR-SPR-2605','FND-SPR-01','dscr_below_target','delayed_receivables','accelerate_collections','in_progress','internal_only',600000,'Head of Credit Control','2026-06-15',null,'Collections drive launched to lift consumables DSCR'),
    ('DSCR-DIA-2605','FND-DIA-01','interest_cover_thin','rate_hike_floating_debt','hedge_interest_rate','open','lender_notifiable',900000,'Group Treasurer','2026-06-30',null,'Imaging line floating-rate exposure to be hedged'),
    ('DSCR-SPR-2606','FND-SPR-02','covenant_breach','revenue_shortfall','covenant_waiver_request','escalated','covenant_breach',1200000,'CFO','2026-06-20',null,'DSCR below 1.0 — waiver request filed with lender'),
    ('DSCR-DIA-2604','FND-DIA-02','cash_headroom_low','capex_overrun','defer_capex','closed','board_escalation',750000,'COO','2026-05-10','2026-05-08','Imaging capex deferred to restore headroom'),
    ('DSCR-AMC-2605','FND-AMC-01','ebitda_shortfall','margin_compression','cost_rationalization','verification_pending','internal_only',420000,'Service Head','2026-06-25',null,'AMC cost base rationalised — verifying margin recovery'),
    ('DSCR-DIA-2605','FND-DIA-03','debt_service_spike','bullet_repayment_bunching','renegotiate_tenor','open','rating_watch',3000000,'Group Treasurer','2026-07-10',null,'Imaging bullet repayment bunching — renegotiating tenor'),
    ('DSCR-SPR-2604','FND-SPR-03','cash_headroom_low','working_capital_drain','draw_working_capital_line','overdue','lender_notifiable',600000,'Head of Credit Control','2026-05-20',null,'WC line drawdown to cover spares headroom — past target'),
    ('DSCR-CGRP-2605','FND-GRP-01','refinance_due','fx_cost_increase','refinance_lower_rate','in_progress','board_escalation',5000000,'CFO','2026-07-15',null,'Group refinancing at lower rate to protect consolidated DSCR')
  ) as q(bref, fref, fc, rc, ca, cst, ci, impact, ownr, tcd, acd, nt)
  join public.dscr_board_r3589 e
    on e.organization_id = v_org_id and e.board_ref = q.bref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Coverage-status distribution
create or replace function public.founder_r3589_coverage_status_rollup()
returns table(coverage_status text, periods bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dscr_board_r3589)
  select l.coverage_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dscr_board_r3589 l
  group by l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3589_coverage_status_rollup() from public, anon;
grant execute on function public.founder_r3589_coverage_status_rollup() to authenticated;

-- 2) Business-unit DSCR scorecard
create or replace function public.founder_r3589_business_unit_scorecard()
returns table(
  business_unit text,
  periods bigint,
  comfortable bigint,
  adequate bigint,
  at_risk bigint,
  avg_dscr numeric,
  min_dscr numeric,
  avg_interest_cover numeric,
  avg_headroom_rupees numeric,
  below_target bigint
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
    count(*) filter (where l.coverage_status = 'comfortable')::bigint,
    count(*) filter (where l.coverage_status = 'adequate')::bigint,
    count(*) filter (where l.coverage_status in ('tight','breach_risk','breached'))::bigint,
    round(avg(l.dscr_ratio), 2),
    round(min(l.dscr_ratio), 2),
    round(avg(l.interest_cover_ratio), 2),
    round(avg(l.cash_headroom_rupees), 0),
    count(*) filter (where l.dscr_ratio < l.target_dscr)::bigint
  from public.dscr_board_r3589 l
  group by l.business_unit
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3589_business_unit_scorecard() from public, anon;
grant execute on function public.founder_r3589_business_unit_scorecard() to authenticated;

-- 3) Business-unit × coverage-status matrix
create or replace function public.founder_r3589_unit_coverage_matrix()
returns table(business_unit text, coverage_status text, periods bigint, avg_dscr numeric, avg_headroom_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.business_unit, l.coverage_status, count(*)::bigint,
    round(avg(l.dscr_ratio), 2),
    round(avg(l.cash_headroom_rupees), 0)
  from public.dscr_board_r3589 l
  group by l.business_unit, l.coverage_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3589_unit_coverage_matrix() from public, anon;
grant execute on function public.founder_r3589_unit_coverage_matrix() to authenticated;

-- 4) Monthly DSCR trend
create or replace function public.founder_r3589_monthly_dscr_trend()
returns table(period_month date, periods bigint, avg_dscr numeric, min_dscr numeric, avg_interest_cover numeric, avg_headroom_rupees numeric, at_risk bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.dscr_ratio), 2),
    round(min(l.dscr_ratio), 2),
    round(avg(l.interest_cover_ratio), 2),
    round(avg(l.cash_headroom_rupees), 0),
    count(*) filter (where l.coverage_status in ('tight','breach_risk','breached'))::bigint
  from public.dscr_board_r3589 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3589_monthly_dscr_trend() from public, anon;
grant execute on function public.founder_r3589_monthly_dscr_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3589_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, escalated_flag bigint)
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
  from public.dscr_board_capa_actions_r3589 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3589_capa_status_board() from public, anon;
grant execute on function public.founder_r3589_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3589_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dscr_board_capa_actions_r3589)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dscr_board_capa_actions_r3589 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3589_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3589_root_cause_pareto() to authenticated;

-- 7) Coverage-impact digest
create or replace function public.founder_r3589_coverage_impact_digest()
returns table(coverage_impact text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.coverage_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric
  from public.dscr_board_capa_actions_r3589 c
  group by c.coverage_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3589_coverage_impact_digest() from public, anon;
grant execute on function public.founder_r3589_coverage_impact_digest() to authenticated;

-- 8) High-risk (breach / tight) queue
create or replace function public.founder_r3589_high_risk_queue()
returns table(
  business_unit text,
  board_ref text,
  period_month date,
  dscr_ratio numeric,
  target_dscr numeric,
  interest_cover_ratio numeric,
  cash_headroom_rupees numeric,
  coverage_status text,
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
  select l.business_unit, l.board_ref, l.period_month,
    l.dscr_ratio, l.target_dscr, l.interest_cover_ratio, l.cash_headroom_rupees,
    l.coverage_status, l.trend_dir, l.notes
  from public.dscr_board_r3589 l
  where l.coverage_status in ('tight','breach_risk','breached')
     or l.dscr_ratio < l.target_dscr
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.business_unit;
end;
$$;

revoke execute on function public.founder_r3589_high_risk_queue() from public, anon;
grant execute on function public.founder_r3589_high_risk_queue() to authenticated;
