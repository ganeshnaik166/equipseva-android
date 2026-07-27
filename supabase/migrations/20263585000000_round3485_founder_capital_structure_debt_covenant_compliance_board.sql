-- Round 3485: Founder Capital-Structure / Debt-Covenant Compliance Board
-- Capital structure QA — facility × lender × covenant type × required vs actual × headroom × outstanding exposure × compliance status × test cadence × trend × CAPA

-- =============================================================================
-- TABLE 1: capital_structure_covenant_r3485 — per-facility covenant test results
-- =============================================================================
create table if not exists public.capital_structure_covenant_r3485 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  facility_name text not null,
  lender text not null,
  covenant_ref text not null,
  covenant_type text not null check (covenant_type in (
    'leverage_ratio','dscr','interest_coverage','current_ratio','min_net_worth','capex_cap'
  )),
  required_value numeric(18,2),
  actual_value numeric(18,2),
  headroom_pct numeric(6,2),
  outstanding_rupees numeric(18,2),
  compliance_status text not null check (compliance_status in (
    'compliant','watch','breach_risk','breached','waived'
  )),
  test_date date not null,
  next_test_date date,
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capital_structure_covenant_r3485 enable row level security;

create index if not exists idx_cap_struct_covenant_r3485_org on public.capital_structure_covenant_r3485(organization_id);
create index if not exists idx_cap_struct_covenant_r3485_date on public.capital_structure_covenant_r3485(test_date);
create index if not exists idx_cap_struct_covenant_r3485_status on public.capital_structure_covenant_r3485(compliance_status);

-- =============================================================================
-- TABLE 2: capital_structure_covenant_capa_actions_r3485 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.capital_structure_covenant_capa_actions_r3485 (
  id uuid primary key default gen_random_uuid(),
  covenant_id uuid not null references public.capital_structure_covenant_r3485(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'leverage_above_cap','dscr_below_floor','icr_below_floor','current_ratio_below_floor',
    'net_worth_below_floor','capex_above_cap','headroom_erosion','test_reporting_delay'
  )),
  root_cause text not null check (root_cause in (
    'ebitda_decline','revenue_shortfall','margin_compression','debt_drawdown_increase',
    'interest_rate_hike','working_capital_stretch','one_time_charge','capex_overrun',
    'fx_impact','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_equity','refinance_facility','negotiate_waiver','reduce_capex','cost_rationalization',
    'accelerate_receivables','prepay_debt','renegotiate_covenant','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  capa_impact_rupees numeric(18,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.capital_structure_covenant_capa_actions_r3485 enable row level security;

create index if not exists idx_cap_struct_capa_r3485_covenant on public.capital_structure_covenant_capa_actions_r3485(covenant_id);
create index if not exists idx_cap_struct_capa_r3485_status on public.capital_structure_covenant_capa_actions_r3485(capa_status);

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

  -- 16 covenant test rows
  insert into public.capital_structure_covenant_r3485 (
    organization_id, facility_name, lender, covenant_ref, covenant_type,
    required_value, actual_value, headroom_pct, outstanding_rupees, compliance_status,
    test_date, next_test_date, trend_dir, notes
  )
  select v_org_id, q.fac, q.lend, q.ref, q.ctype,
    q.reqv, q.actv, q.hp, q.outr, q.cst,
    q.td::date, q.ntd::date, q.trend, q.nt
  from (values
    ('Term Loan A','SBI','TL-SBI-LEV','leverage_ratio',
     3.00,2.45,18.3,450000000,'compliant','2026-06-30','2026-09-30','improving','Net debt/EBITDA comfortably within 3.0x cap'),
    ('Term Loan A','SBI','TL-SBI-DSCR','dscr',
     1.25,1.42,13.6,450000000,'compliant','2026-06-30','2026-09-30','stable','DSCR above 1.25x floor with steady cash flows'),
    ('Working Capital Line','HDFC Bank','WCL-HDFC-CR','current_ratio',
     1.20,1.28,6.7,180000000,'watch','2026-06-30','2026-07-31','worsening','Current ratio drifting toward 1.20x floor'),
    ('Working Capital Line','HDFC Bank','WCL-HDFC-ICR','interest_coverage',
     3.00,2.60,-13.3,180000000,'breach_risk','2026-06-30','2026-07-31','worsening','ICR eroding on rising interest cost'),
    ('NCD Series I','ICICI Bank','NCD-ICICI-LEV','leverage_ratio',
     3.50,3.65,-4.3,600000000,'breached','2026-06-30','2026-09-30','worsening','Leverage breached 3.5x cap post debt drawdown'),
    ('NCD Series I','ICICI Bank','NCD-ICICI-NW','min_net_worth',
     2500000000,2820000000,12.8,600000000,'compliant','2026-06-30','2026-09-30','improving','Net worth above INR 250 Cr floor'),
    ('Capex Facility','Axis Bank','CPX-AXIS-CAP','capex_cap',
     500000000,470000000,6.0,320000000,'watch','2026-06-30','2026-09-30','worsening','Capex nearing annual cap of INR 50 Cr'),
    ('Term Loan B','Kotak Mahindra Bank','TLB-KOTAK-DSCR','dscr',
     1.30,1.18,-9.2,380000000,'breached','2026-06-30','2026-07-31','worsening','DSCR breached 1.30x floor on EBITDA decline'),
    ('Term Loan B','Kotak Mahindra Bank','TLB-KOTAK-LEV','leverage_ratio',
     3.25,3.10,4.6,380000000,'watch','2026-06-30','2026-07-31','stable','Leverage headroom thin under 3.25x cap'),
    ('ECB Loan','Yes Bank','ECB-YES-ICR','interest_coverage',
     2.50,3.20,28.0,220000000,'compliant','2026-06-30','2026-09-30','improving','Interest coverage strong post FX hedge'),
    ('ECB Loan','Yes Bank','ECB-YES-NW','min_net_worth',
     1800000000,1750000000,-2.8,220000000,'breach_risk','2026-06-30','2026-09-30','worsening','Net worth dipped below INR 180 Cr floor risk'),
    ('Revolving Credit','IndusInd Bank','RCF-INDUS-CR','current_ratio',
     1.10,1.35,22.7,140000000,'compliant','2026-06-30','2026-07-31','stable','Current ratio healthy above 1.10x floor'),
    ('Revolving Credit','IndusInd Bank','RCF-INDUS-LEV','leverage_ratio',
     4.00,3.85,3.8,140000000,'watch','2026-06-30','2026-07-31','worsening','Leverage headroom thin under 4.0x cap'),
    ('Mezzanine Note','Edelweiss','MEZ-EDEL-DSCR','dscr',
     1.15,1.05,-8.7,260000000,'breached','2026-06-30','2026-07-31','worsening','Mezzanine DSCR breached — waiver being negotiated'),
    ('Mezzanine Note','Edelweiss','MEZ-EDEL-CAP','capex_cap',
     300000000,285000000,5.0,260000000,'waived','2026-05-31','2026-08-31','stable','Capex cap breach waived for expansion quarter'),
    ('Bridge Facility','Bajaj Finserv','BRG-BAJAJ-ICR','interest_coverage',
     2.75,2.90,5.5,160000000,'watch','2026-06-30','2026-07-31','improving','ICR just above floor after refinancing')
  ) as q(fac, lend, ref, ctype, reqv, actv, hp, outr, cst, td, ntd, trend, nt);

  -- CAPA seed — attach to specific facilities via covenant_ref
  insert into public.capital_structure_covenant_capa_actions_r3485 (
    covenant_id, finding_category, root_cause, corrective_action,
    capa_status, capa_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('NCD-ICICI-LEV','leverage_above_cap','debt_drawdown_increase','prepay_debt','in_progress',25000000,'CFO','2026-08-15',null,'Prepay INR 2.5 Cr to bring leverage under 3.5x cap'),
    ('TLB-KOTAK-DSCR','dscr_below_floor','ebitda_decline','cost_rationalization','open',15000000,'FP&A Head','2026-08-31',null,'Cost rationalization program to restore DSCR above 1.30x'),
    ('WCL-HDFC-ICR','icr_below_floor','interest_rate_hike','refinance_facility','escalated',40000000,'Treasury','2026-08-10',null,'Refinance working-capital line at lower spread to lift ICR'),
    ('MEZ-EDEL-DSCR','dscr_below_floor','margin_compression','negotiate_waiver','verification_pending',0,'CFO','2026-07-31',null,'Waiver request filed with Edelweiss for the quarter'),
    ('ECB-YES-NW','net_worth_below_floor','one_time_charge','raise_equity','open',200000000,'Founder','2026-09-30',null,'Rights issue planned to shore up net worth above floor'),
    ('CPX-AXIS-CAP','capex_above_cap','capex_overrun','reduce_capex','in_progress',30000000,'COO','2026-08-20',null,'Defer non-critical capex to stay under annual cap'),
    ('WCL-HDFC-CR','current_ratio_below_floor','working_capital_stretch','accelerate_receivables','closed',12000000,'Controller','2026-06-30','2026-06-28','Receivables collection sprint restored current ratio'),
    ('RCF-INDUS-LEV','headroom_erosion','revenue_shortfall','renegotiate_covenant','overdue',8000000,'Treasury','2026-07-10',null,'Covenant reset talks running past the target date')
  ) as q(ref, fc, rc, ca, cst, imp, own, tcd, acd, nt)
  join public.capital_structure_covenant_r3485 e
    on e.organization_id = v_org_id and e.covenant_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3485_compliance_status_rollup()
returns table(compliance_status text, facilities bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capital_structure_covenant_r3485)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.capital_structure_covenant_r3485 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3485_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3485_compliance_status_rollup() to authenticated;

-- 2) Lender scorecard
create or replace function public.founder_r3485_lender_scorecard()
returns table(
  lender text,
  facilities bigint,
  compliant bigint,
  watch bigint,
  breach_risk bigint,
  breached bigint,
  waived bigint,
  total_outstanding_rupees numeric,
  avg_headroom_pct numeric,
  compliant_pct numeric
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
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'watch')::bigint,
    count(*) filter (where l.compliance_status = 'breach_risk')::bigint,
    count(*) filter (where l.compliance_status = 'breached')::bigint,
    count(*) filter (where l.compliance_status = 'waived')::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    round(avg(l.headroom_pct), 2),
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.capital_structure_covenant_r3485 l
  group by l.lender
  order by coalesce(sum(l.outstanding_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3485_lender_scorecard() from public, anon;
grant execute on function public.founder_r3485_lender_scorecard() to authenticated;

-- 3) Covenant-type × compliance-status matrix
create or replace function public.founder_r3485_covenant_status_matrix()
returns table(covenant_type text, compliance_status text, facilities bigint, avg_headroom_pct numeric, total_outstanding_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.covenant_type, l.compliance_status, count(*)::bigint,
    round(avg(l.headroom_pct), 2),
    coalesce(sum(l.outstanding_rupees),0)::numeric
  from public.capital_structure_covenant_r3485 l
  group by l.covenant_type, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3485_covenant_status_matrix() from public, anon;
grant execute on function public.founder_r3485_covenant_status_matrix() to authenticated;

-- 4) Monthly headroom trend
create or replace function public.founder_r3485_monthly_headroom_trend()
returns table(test_month date, tests bigint, avg_headroom_pct numeric, breached bigint, breach_risk bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select date_trunc('month', l.test_date)::date as test_month,
    count(*)::bigint,
    round(avg(l.headroom_pct), 2),
    count(*) filter (where l.compliance_status = 'breached')::bigint,
    count(*) filter (where l.compliance_status = 'breach_risk')::bigint
  from public.capital_structure_covenant_r3485 l
  group by date_trunc('month', l.test_date)
  order by date_trunc('month', l.test_date) desc;
end;
$$;

revoke execute on function public.founder_r3485_monthly_headroom_trend() from public, anon;
grant execute on function public.founder_r3485_monthly_headroom_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3485_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.capa_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.capital_structure_covenant_capa_actions_r3485 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3485_capa_status_board() from public, anon;
grant execute on function public.founder_r3485_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3485_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.capital_structure_covenant_capa_actions_r3485)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.capa_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.capital_structure_covenant_capa_actions_r3485 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3485_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3485_root_cause_pareto() to authenticated;

-- 7) Exposure-impact digest by covenant type
create or replace function public.founder_r3485_exposure_impact_digest()
returns table(covenant_type text, facilities bigint, total_outstanding_rupees numeric, avg_headroom_pct numeric, breached bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.covenant_type, count(*)::bigint,
    coalesce(sum(l.outstanding_rupees),0)::numeric,
    round(avg(l.headroom_pct), 2),
    count(*) filter (where l.compliance_status in ('breached','breach_risk'))::bigint
  from public.capital_structure_covenant_r3485 l
  group by l.covenant_type
  order by coalesce(sum(l.outstanding_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3485_exposure_impact_digest() from public, anon;
grant execute on function public.founder_r3485_exposure_impact_digest() to authenticated;

-- 8) High-risk covenant queue
create or replace function public.founder_r3485_high_risk_queue()
returns table(
  facility_name text,
  lender text,
  covenant_ref text,
  covenant_type text,
  required_value numeric,
  actual_value numeric,
  headroom_pct numeric,
  compliance_status text,
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
  select l.facility_name, l.lender, l.covenant_ref, l.covenant_type,
    l.required_value, l.actual_value, l.headroom_pct,
    l.compliance_status, l.trend_dir, l.notes
  from public.capital_structure_covenant_r3485 l
  where l.compliance_status in ('breach_risk','breached')
     or l.trend_dir = 'worsening'
  order by l.headroom_pct asc, l.test_date desc;
end;
$$;

revoke execute on function public.founder_r3485_high_risk_queue() from public, anon;
grant execute on function public.founder_r3485_high_risk_queue() to authenticated;
