-- Round 3610: Founder Debt Maturity Ladder / Refinancing Profile Board
-- Founder finance — debt maturity ladder × refinancing profile × rollover risk per facility × lender ×
-- maturity bucket × refinance status × covenant headroom × interest-rate reset exposure × CAPA closure

-- =============================================================================
-- TABLE 1: debt_maturity_r3610 — per-facility debt maturity / refinancing profile
-- =============================================================================
create table if not exists public.debt_maturity_r3610 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  facility_name text not null,
  lender text not null,
  tranche_code text not null,
  period_month date not null,
  outstanding_rupees numeric(16,2),
  interest_rate_pct numeric(6,2),
  principal_due_rupees numeric(16,2),
  rollover_risk_score numeric(6,2),
  covenant_headroom_pct numeric(6,2),
  next_reset_date date,
  maturity_bucket text not null check (maturity_bucket in (
    '0_6_months','6_12_months','1_3_years','3_5_years','over_5_years'
  )),
  refinance_status text not null check (refinance_status in (
    'refinanced','committed','in_progress','at_risk','unaddressed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.debt_maturity_r3610 enable row level security;

create index if not exists idx_debt_maturity_r3610_org on public.debt_maturity_r3610(organization_id);
create index if not exists idx_debt_maturity_r3610_month on public.debt_maturity_r3610(period_month);
create index if not exists idx_debt_maturity_r3610_status on public.debt_maturity_r3610(refinance_status);

-- =============================================================================
-- TABLE 2: debt_maturity_capa_actions_r3610 — CAPA & refinancing actions
-- =============================================================================
create table if not exists public.debt_maturity_capa_actions_r3610 (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.debt_maturity_r3610(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'near_term_maturity_concentration','covenant_headroom_thin','rollover_dependency_high',
    'interest_rate_reset_exposure','refinancing_delay','lender_concentration_risk',
    'principal_bullet_due','documentation_pending'
  )),
  root_cause text not null check (root_cause in (
    'market_liquidity_tight','rate_hike_cycle','delayed_lender_sanction','covenant_breach_risk',
    'single_lender_dependence','bullet_repayment_structure','cash_flow_shortfall',
    'pending_investigation','credit_rating_pressure','collateral_revaluation_pending'
  )),
  corrective_action text not null check (corrective_action in (
    'negotiate_refinance','secure_committed_line','diversify_lenders','extend_tenor',
    'hedge_interest_rate','prepay_from_surplus','restructure_covenant','arrange_bridge_facility',
    'escalate_to_board','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_impact_rupees numeric(16,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.debt_maturity_capa_actions_r3610 enable row level security;

create index if not exists idx_debt_maturity_capa_r3610_debt on public.debt_maturity_capa_actions_r3610(debt_id);
create index if not exists idx_debt_maturity_capa_r3610_status on public.debt_maturity_capa_actions_r3610(capa_status);

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

  -- 16 debt-facility rows
  insert into public.debt_maturity_r3610 (
    organization_id, facility_name, lender, tranche_code, period_month,
    outstanding_rupees, interest_rate_pct, principal_due_rupees, rollover_risk_score,
    covenant_headroom_pct, next_reset_date, maturity_bucket, refinance_status, trend_dir, notes
  )
  select v_org_id, q.fname, q.lender, q.tcode, q.pmonth::date,
    q.outr, q.irate, q.pdue, q.rrisk,
    q.chead, q.nreset::date, q.mbucket, q.rstatus, q.tdir, q.nt
  from (values
    ('Term Loan - Chennai Service Hub','HDFC Bank','TL-CHN-2101','2026-08-01',
     185000000,9.35,15000000,38,22.5,'2026-11-01','0_6_months','in_progress','improving','Chennai service-hub term loan; refinance term sheet under negotiation'),
    ('Working Capital Line - Mumbai','ICICI Bank','WC-MUM-2202','2026-08-01',
     92000000,8.75,92000000,55,12.0,'2026-09-15','0_6_months','at_risk','worsening','WC line renewal due; lender review pending, headroom thin'),
    ('NCD Series A','Kotak Mahindra Bank','NCD-A-2303','2026-09-01',
     250000000,10.10,0,30,28.0,'2027-03-01','1_3_years','committed','stable','Listed NCD; put option 2028, committed rollover backstop arranged'),
    ('ECB Loan - Diagnostics Import','State Bank of India','ECB-DIAG-2404','2026-09-01',
     140000000,7.25,20000000,48,15.5,'2026-12-01','6_12_months','in_progress','stable','ECB for diagnostics imaging import; hedge review due before reset'),
    ('Equipment Lease - Rentals BU','Tata Capital','LSE-RENT-2505','2026-08-01',
     68000000,11.40,8000000,60,9.5,'2026-10-01','0_6_months','at_risk','worsening','Rentals fleet lease near reset; covenant headroom thin'),
    ('Term Loan - Spare Parts Warehouse','Axis Bank','TL-SPR-2606','2026-10-01',
     110000000,9.10,12000000,35,24.0,'2027-01-01','1_3_years','refinanced','improving','Spare-parts warehouse loan refinanced at lower spread'),
    ('Project Finance - Hospital Build-out','Yes Bank','PF-PROJ-2707','2026-11-01',
     320000000,10.75,0,68,8.0,'2027-05-01','1_3_years','at_risk','worsening','Turnkey project finance; lender concentration and thin covenant headroom'),
    ('Bridge Loan - AMC Services','Bajaj Finance','BR-AMC-2808','2026-08-01',
     45000000,12.20,45000000,72,6.5,'2026-09-01','0_6_months','unaddressed','worsening','Short-term bridge on AMC receivables; no refinance plan yet'),
    ('Term Loan - Bengaluru Center','HDFC Bank','TL-BLR-2909','2027-02-01',
     160000000,9.20,14000000,33,26.5,'2027-08-01','1_3_years','committed','stable','Bengaluru center loan; committed sanction for FY28 rollover'),
    ('NCD Series B','ICICI Bank','NCD-B-3010','2028-06-01',
     300000000,9.95,0,28,30.0,'2028-06-01','1_3_years','committed','improving','Longer NCD tranche; strong headroom, committed backstop'),
    ('Working Capital Demand Loan','State Bank of India','WC-SBI-3111','2026-09-01',
     78000000,8.50,78000000,50,14.0,'2026-10-15','6_12_months','in_progress','stable','Demand loan renewal in progress with existing lender'),
    ('ECB - Projects Division','Standard Chartered','ECB-PROJ-3212','2029-04-01',
     210000000,6.90,0,40,20.0,'2027-04-01','3_5_years','committed','stable','Long-tenor ECB for projects; annual reset, fully hedged'),
    ('Term Loan - Diagnostics Expansion','Axis Bank','TL-DIAG-3313','2031-01-01',
     175000000,9.05,10000000,25,32.0,'2028-01-01','over_5_years','refinanced','improving','Diagnostics expansion loan refinanced; long tenor secured'),
    ('Lease Finance - Imaging Fleet','Tata Capital','LSE-IMG-3414','2027-03-01',
     95000000,11.10,11000000,58,11.0,'2026-12-15','6_12_months','at_risk','worsening','Imaging fleet lease; reset approaching, refinance not yet secured'),
    ('Promoter Loan - Unsecured','Kotak Mahindra Bank','PL-PROM-3515','2026-10-01',
     55000000,13.00,55000000,65,7.5,'2026-11-15','0_6_months','unaddressed','worsening','Unsecured promoter-backed loan; bullet due, no refi initiated'),
    ('Term Loan - Corporate HQ','HDFC Bank','TL-HQ-3616','2032-07-01',
     130000000,8.90,9000000,22,35.0,'2029-07-01','over_5_years','refinanced','improving','HQ property loan refinanced at improved rate; long runway')
  ) as q(fname, lender, tcode, pmonth, outr, irate, pdue, rrisk, chead, nreset, mbucket, rstatus, tdir, nt);

  -- CAPA seed — attach to specific facilities via tranche_code
  insert into public.debt_maturity_capa_actions_r3610 (
    debt_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.exp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('WC-MUM-2202','near_term_maturity_concentration','market_liquidity_tight','secure_committed_line','in_progress',92000000,'Treasury - R. Iyer','2026-09-10',null,'Committed line negotiation with ICICI for WC renewal'),
    ('LSE-RENT-2505','covenant_headroom_thin','covenant_breach_risk','restructure_covenant','open',68000000,'CFO Office','2026-09-30',null,'Requesting covenant reset from Tata Capital ahead of rate reset'),
    ('PF-PROJ-2707','lender_concentration_risk','single_lender_dependence','diversify_lenders','escalated',320000000,'Head of Debt - S. Rao','2026-10-15',null,'Syndication to reduce Yes Bank concentration; escalated to board'),
    ('BR-AMC-2808','rollover_dependency_high','cash_flow_shortfall','arrange_bridge_facility','overdue',45000000,'Treasury - R. Iyer','2026-08-20',null,'Bridge rollover past target; AMC receivables collection lagging'),
    ('TL-CHN-2101','interest_rate_reset_exposure','rate_hike_cycle','hedge_interest_rate','verification_pending',15000000,'Treasury Desk','2026-09-05',null,'IRS hedge placed on Chennai loan reset; awaiting confirmation'),
    ('TL-SPR-2606','refinancing_delay','delayed_lender_sanction','negotiate_refinance','closed',12000000,'CFO Office','2026-08-15','2026-08-12','Spare-parts loan refinanced at Axis; closed ahead of maturity'),
    ('PL-PROM-3515','principal_bullet_due','bullet_repayment_structure','prepay_from_surplus','open',55000000,'Founder / CFO','2026-11-01',null,'Bullet repayment; evaluating surplus prepayment vs refinance'),
    ('LSE-IMG-3414','interest_rate_reset_exposure','credit_rating_pressure','extend_tenor','in_progress',95000000,'Treasury Desk','2026-12-01',null,'Seeking tenor extension on imaging lease before December reset')
  ) as q(tcode, fc, rc, ca, cst, exp, ownr, tcd, acd, nt)
  join public.debt_maturity_r3610 e
    on e.organization_id = v_org_id and e.tranche_code = q.tcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Refinance status distribution
create or replace function public.founder_r3610_refinance_status_rollup()
returns table(refinance_status text, facilities bigint, total_outstanding_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.debt_maturity_r3610)
  select l.refinance_status, count(*)::bigint,
         coalesce(sum(l.outstanding_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.debt_maturity_r3610 l
  group by l.refinance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3610_refinance_status_rollup() from public, anon;
grant execute on function public.founder_r3610_refinance_status_rollup() to authenticated;

-- 2) Lender-level scorecard
create or replace function public.founder_r3610_lender_scorecard()
returns table(
  lender text,
  tranches bigint,
  refinanced bigint,
  committed bigint,
  in_progress bigint,
  at_risk bigint,
  unaddressed bigint,
  total_outstanding_rupees numeric,
  avg_rollover_risk numeric,
  addressed_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.lender,
    count(*)::bigint,
    count(*) filter (where l.refinance_status = 'refinanced')::bigint,
    count(*) filter (where l.refinance_status = 'committed')::bigint,
    count(*) filter (where l.refinance_status = 'in_progress')::bigint,
    count(*) filter (where l.refinance_status = 'at_risk')::bigint,
    count(*) filter (where l.refinance_status = 'unaddressed')::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    round(avg(l.rollover_risk_score), 1),
    round(100.0 * count(*) filter (where l.refinance_status in ('refinanced','committed'))::numeric / nullif(count(*),0), 1)
  from public.debt_maturity_r3610 l
  group by l.lender
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3610_lender_scorecard() from public, anon;
grant execute on function public.founder_r3610_lender_scorecard() to authenticated;

-- 3) Maturity bucket × refinance status matrix
create or replace function public.founder_r3610_bucket_status_matrix()
returns table(maturity_bucket text, refinance_status text, tranches bigint, total_outstanding_rupees numeric, avg_rollover_risk numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.maturity_bucket, l.refinance_status, count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    round(avg(l.rollover_risk_score), 1)
  from public.debt_maturity_r3610 l
  group by l.maturity_bucket, l.refinance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3610_bucket_status_matrix() from public, anon;
grant execute on function public.founder_r3610_bucket_status_matrix() to authenticated;

-- 4) Monthly maturity trend
create or replace function public.founder_r3610_monthly_maturity_trend()
returns table(period_month date, tranches bigint, total_principal_due_rupees numeric, total_outstanding_rupees numeric, at_risk bigint, avg_rollover_risk numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.principal_due_rupees),0)::numeric,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    count(*) filter (where l.refinance_status in ('at_risk','unaddressed'))::bigint,
    round(avg(l.rollover_risk_score), 1)
  from public.debt_maturity_r3610 l
  group by l.period_month
  order by l.period_month;
end;
$$;

revoke execute on function public.founder_r3610_monthly_maturity_trend() from public, anon;
grant execute on function public.founder_r3610_monthly_maturity_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3610_capa_status_board()
returns table(capa_status text, findings bigint, avg_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.exposure_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.debt_maturity_capa_actions_r3610 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3610_capa_status_board() from public, anon;
grant execute on function public.founder_r3610_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3610_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.debt_maturity_capa_actions_r3610)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.exposure_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.debt_maturity_capa_actions_r3610 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3610_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3610_root_cause_pareto() to authenticated;

-- 7) Rollover-risk digest (by maturity bucket)
create or replace function public.founder_r3610_rollover_risk_digest()
returns table(
  maturity_bucket text,
  tranches bigint,
  total_outstanding_rupees numeric,
  total_principal_due_rupees numeric,
  avg_rollover_risk numeric,
  avg_covenant_headroom_pct numeric,
  at_risk bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.maturity_bucket,
    count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    coalesce(sum(l.principal_due_rupees),0)::numeric,
    round(avg(l.rollover_risk_score), 1),
    round(avg(l.covenant_headroom_pct), 1),
    count(*) filter (where l.refinance_status in ('at_risk','unaddressed'))::bigint
  from public.debt_maturity_r3610 l
  group by l.maturity_bucket
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3610_rollover_risk_digest() from public, anon;
grant execute on function public.founder_r3610_rollover_risk_digest() to authenticated;

-- 8) High-risk refinancing queue (at_risk / unaddressed and thin headroom)
create or replace function public.founder_r3610_high_risk_queue()
returns table(
  facility_name text,
  lender text,
  tranche_code text,
  period_month date,
  maturity_bucket text,
  refinance_status text,
  outstanding_rupees numeric,
  rollover_risk_score numeric,
  covenant_headroom_pct numeric,
  next_reset_date date,
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
  select l.facility_name, l.lender, l.tranche_code, l.period_month, l.maturity_bucket,
    l.refinance_status, l.outstanding_rupees, l.rollover_risk_score, l.covenant_headroom_pct,
    l.next_reset_date, l.trend_dir, l.notes
  from public.debt_maturity_r3610 l
  where l.refinance_status in ('at_risk','unaddressed')
     or l.rollover_risk_score >= 55
     or l.covenant_headroom_pct <= 12
     or l.trend_dir = 'worsening'
  order by l.rollover_risk_score desc nulls last, l.period_month;
end;
$$;

revoke execute on function public.founder_r3610_high_risk_queue() from public, anon;
grant execute on function public.founder_r3610_high_risk_queue() to authenticated;
