-- Round 3635: Founder Dividend Distribution / Dividend-TDS (Sec-194) Compliance Board
-- Founder finance board — dividend declaration/payout per shareholder class × TDS deductible/deducted/deposited
-- (Sec 194) × rate × lower-deduction cases × compliance status × trend × CAPA closure

-- =============================================================================
-- TABLE 1: dividend_tds_r3635 — per shareholder-class dividend + TDS compliance fact
-- =============================================================================
create table if not exists public.dividend_tds_r3635 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  distribution_ref text not null,
  shareholder_class text not null,
  period_month date not null,
  dividend_declared_rupees numeric(14,2),
  dividend_paid_rupees numeric(14,2),
  tds_deductible_rupees numeric(14,2),
  tds_deducted_rupees numeric(14,2),
  tds_deposited_rupees numeric(14,2),
  shareholders_count int,
  tds_rate_pct numeric(5,2),
  lower_deduction_cases int,
  compliance_status text not null check (compliance_status in (
    'compliant','on_track','short_deducted','deposit_pending','non_compliant'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dividend_tds_r3635 enable row level security;

create index if not exists idx_dividend_tds_r3635_org on public.dividend_tds_r3635(organization_id);
create index if not exists idx_dividend_tds_r3635_month on public.dividend_tds_r3635(period_month);
create index if not exists idx_dividend_tds_r3635_status on public.dividend_tds_r3635(compliance_status);

-- =============================================================================
-- TABLE 2: dividend_tds_capa_actions_r3635 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.dividend_tds_capa_actions_r3635 (
  id uuid primary key default gen_random_uuid(),
  dividend_log_id uuid not null references public.dividend_tds_r3635(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'short_deduction','deposit_delay','rate_misapplication','pan_not_available',
    'lower_deduction_cert_missing','challan_mismatch','return_filing_delay','form_16a_pending'
  )),
  root_cause text not null check (root_cause in (
    'incorrect_tds_rate_applied','pan_not_furnished','lower_deduction_certificate_not_recorded',
    'manual_calculation_error','challan_data_entry_error','payment_gateway_delay',
    'system_config_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'deduct_shortfall_and_deposit','file_revised_return','update_tds_rate_master',
    'collect_pan_and_recompute','record_lower_deduction_certificate','reconcile_challan',
    'issue_form_16a','retrain_finance_team','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  exposure_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.dividend_tds_capa_actions_r3635 enable row level security;

create index if not exists idx_dividend_tds_capa_r3635_log on public.dividend_tds_capa_actions_r3635(dividend_log_id);
create index if not exists idx_dividend_tds_capa_r3635_status on public.dividend_tds_capa_actions_r3635(capa_status);

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

  -- 16 dividend + TDS compliance rows
  insert into public.dividend_tds_r3635 (
    organization_id, distribution_ref, shareholder_class, period_month,
    dividend_declared_rupees, dividend_paid_rupees, tds_deductible_rupees,
    tds_deducted_rupees, tds_deposited_rupees, shareholders_count, tds_rate_pct,
    lower_deduction_cases, compliance_status, trend_dir, notes
  )
  select v_org_id, q.dref, q.scls, q.pm::date,
    q.decl, q.paid, q.tded,
    q.tddd, q.tdep, q.shc, q.trt,
    q.ldc, q.cst, q.trd, q.nt
  from (values
    ('DIV-EQ-2603','equity_ordinary','2026-03-01',
     12000000,10800000,1200000,1200000,1200000,4200,10.0,0,'compliant','stable','Interim dividend equity — TDS deducted and deposited within due date'),
    ('DIV-EQ-2606','equity_ordinary','2026-06-01',
     15000000,13500000,1500000,1500000,1500000,4350,10.0,5,'compliant','improving','Final dividend equity — challans reconciled, Form 16A issued'),
    ('DIV-PR-2603','preference_shares','2026-03-01',
     3000000,2700000,300000,300000,300000,320,10.0,0,'compliant','stable','Preference dividend — fixed rate, TDS fully compliant'),
    ('DIV-PR-2606','preference_shares','2026-06-01',
     3200000,2880000,320000,288000,288000,330,9.0,2,'short_deducted','worsening','Rate misapplied at 9 pct vs 10 pct — shortfall across 32 holders'),
    ('DIV-PROMO-2606','promoter_group','2026-06-01',
     40000000,36000000,4000000,4000000,4000000,8,10.0,0,'compliant','stable','Promoter final dividend — TDS on time, no lower-deduction claims'),
    ('DIV-ESOP-2606','esop_holders','2026-06-01',
     2500000,2250000,250000,250000,0,210,10.0,0,'deposit_pending','stable','ESOP-holder dividend — deducted, challan deposit pending within due date'),
    ('DIV-FII-2606','fii_dii','2026-06-01',
     22000000,19800000,2200000,1760000,1760000,46,8.0,12,'short_deducted','worsening','FII treaty rate misread — 12 lower-deduction certs not recorded before payout'),
    ('DIV-RET-2606','retail_public','2026-06-01',
     8000000,7200000,800000,800000,800000,12500,10.0,320,'compliant','improving','Retail dividend — PAN validated, 320 lower-deduction certs honoured'),
    ('DIV-RET-2607','retail_public','2026-07-01',
     9500000,8550000,1900000,1710000,1710000,12800,20.0,0,'short_deducted','worsening','Retail missing-PAN bucket at 20 pct — 190k shortfall on no-PAN holders'),
    ('DIV-EQ-2607','equity_ordinary','2026-07-01',
     6000000,5400000,600000,600000,450000,4400,10.0,8,'deposit_pending','stable','Equity interim — partial challan deposit, balance pending deposit'),
    ('DIV-PROMO-2603','promoter_group','2026-03-01',
     35000000,31500000,3500000,3500000,3500000,8,10.0,0,'compliant','stable','Promoter interim dividend — fully compliant'),
    ('DIV-FII-2607','fii_dii','2026-07-01',
     18000000,16200000,1800000,0,0,40,0.0,40,'non_compliant','worsening','FII payout released before TDS deduction — full non-compliance, urgent CAPA'),
    ('DIV-ESOP-2603','esop_holders','2026-03-01',
     2000000,1800000,200000,200000,200000,195,10.0,0,'compliant','stable','ESOP interim dividend — compliant'),
    ('DIV-PR-2607','preference_shares','2026-07-01',
     3400000,3060000,340000,340000,340000,335,10.0,0,'compliant','improving','Preference final — corrected rate applied, compliant'),
    ('DIV-RET-2603','retail_public','2026-03-01',
     7000000,6300000,700000,630000,630000,12200,10.0,210,'short_deducted','stable','Retail interim — PAN mismatches under-deducted, revised return needed'),
    ('DIV-PROMO-2607','promoter_group','2026-07-01',
     30000000,27000000,3000000,3000000,2400000,8,10.0,0,'deposit_pending','stable','Promoter interim — TDS deducted, one challan tranche pending deposit')
  ) as q(dref, scls, pm, decl, paid, tded, tddd, tdep, shc, trt, ldc, cst, trd, nt);

  -- CAPA seed — attach to specific distributions via distribution_ref
  insert into public.dividend_tds_capa_actions_r3635 (
    dividend_log_id, finding_category, root_cause, corrective_action,
    capa_status, exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.expo, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DIV-PR-2606','rate_misapplication','incorrect_tds_rate_applied','update_tds_rate_master','in_progress',32000,'M. Iyer','2026-07-15',null,'Preference TDS at 9 pct vs 10 pct — rate master corrected, shortfall recovery in progress'),
    ('DIV-FII-2606','lower_deduction_cert_missing','lower_deduction_certificate_not_recorded','record_lower_deduction_certificate','open',440000,'A. Banerjee','2026-07-20',null,'FII lower-deduction certificates not recorded before payout — 12 cases under review'),
    ('DIV-RET-2607','pan_not_available','pan_not_furnished','collect_pan_and_recompute','in_progress',190000,'S. Rao','2026-07-18',null,'Missing-PAN holders taxed at 20 pct shortfall — PAN collection drive underway'),
    ('DIV-EQ-2607','deposit_delay','payment_gateway_delay','deduct_shortfall_and_deposit','verification_pending',150000,'R. Nair','2026-07-10',null,'Balance challan queued — awaiting bank confirmation of deposit'),
    ('DIV-FII-2607','short_deduction','system_config_error','deduct_shortfall_and_deposit','escalated',1800000,'A. Banerjee','2026-07-08',null,'FII payout released with zero TDS — escalated to CFO, urgent recovery and deposit'),
    ('DIV-RET-2603','short_deduction','manual_calculation_error','file_revised_return','closed',70000,'S. Rao','2026-06-30','2026-06-25','Retail under-deduction corrected, revised 26Q filed and deposited'),
    ('DIV-PROMO-2607','deposit_delay','challan_data_entry_error','reconcile_challan','overdue',600000,'R. Nair','2026-07-05',null,'Promoter challan tranche past due — reconciliation overdue, penalty risk'),
    ('DIV-EQ-2606','form_16a_pending','pending_investigation','issue_form_16a','closed',0,'M. Iyer','2026-06-28','2026-06-27','Form 16A issued to equity holders post-deposit — closed')
  ) as q(dref, fc, rc, ca, cst, expo, ownr, tcd, acd, nt)
  join public.dividend_tds_r3635 e
    on e.organization_id = v_org_id and e.distribution_ref = q.dref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3635_compliance_status_rollup()
returns table(compliance_status text, distributions bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dividend_tds_r3635)
  select l.compliance_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.dividend_tds_r3635 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3635_compliance_status_rollup() from public, anon;
grant execute on function public.founder_r3635_compliance_status_rollup() to authenticated;

-- 2) Shareholder-class scorecard
create or replace function public.founder_r3635_shareholder_class_scorecard()
returns table(
  shareholder_class text,
  distributions bigint,
  compliant bigint,
  short_deducted bigint,
  non_compliant bigint,
  total_declared_rupees numeric,
  total_tds_deducted_rupees numeric,
  total_tds_deposited_rupees numeric,
  compliant_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.shareholder_class,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'compliant')::bigint,
    count(*) filter (where l.compliance_status = 'short_deducted')::bigint,
    count(*) filter (where l.compliance_status = 'non_compliant')::bigint,
    coalesce(sum(l.dividend_declared_rupees),0)::numeric,
    coalesce(sum(l.tds_deducted_rupees),0)::numeric,
    coalesce(sum(l.tds_deposited_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.compliance_status = 'compliant')::numeric / nullif(count(*),0), 1)
  from public.dividend_tds_r3635 l
  group by l.shareholder_class
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3635_shareholder_class_scorecard() from public, anon;
grant execute on function public.founder_r3635_shareholder_class_scorecard() to authenticated;

-- 3) Shareholder-class × compliance-status matrix
create or replace function public.founder_r3635_class_status_matrix()
returns table(
  shareholder_class text,
  compliance_status text,
  distributions bigint,
  total_tds_deductible_rupees numeric,
  total_tds_deposited_rupees numeric,
  avg_tds_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.shareholder_class, l.compliance_status, count(*)::bigint,
    coalesce(sum(l.tds_deductible_rupees),0)::numeric,
    coalesce(sum(l.tds_deposited_rupees),0)::numeric,
    round(avg(l.tds_rate_pct), 2)
  from public.dividend_tds_r3635 l
  group by l.shareholder_class, l.compliance_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3635_class_status_matrix() from public, anon;
grant execute on function public.founder_r3635_class_status_matrix() to authenticated;

-- 4) Monthly TDS trend
create or replace function public.founder_r3635_monthly_tds_trend()
returns table(
  period_month date,
  distributions bigint,
  total_declared_rupees numeric,
  total_tds_deducted_rupees numeric,
  total_tds_deposited_rupees numeric,
  deposit_gap_rupees numeric
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
    coalesce(sum(l.dividend_declared_rupees),0)::numeric,
    coalesce(sum(l.tds_deducted_rupees),0)::numeric,
    coalesce(sum(l.tds_deposited_rupees),0)::numeric,
    coalesce(sum(l.tds_deducted_rupees - l.tds_deposited_rupees),0)::numeric
  from public.dividend_tds_r3635 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3635_monthly_tds_trend() from public, anon;
grant execute on function public.founder_r3635_monthly_tds_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3635_capa_status_board()
returns table(capa_status text, findings bigint, avg_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.dividend_tds_capa_actions_r3635 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3635_capa_status_board() from public, anon;
grant execute on function public.founder_r3635_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3635_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.dividend_tds_capa_actions_r3635)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.dividend_tds_capa_actions_r3635 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3635_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3635_root_cause_pareto() to authenticated;

-- 7) TDS-exposure digest by finding category
create or replace function public.founder_r3635_tds_exposure_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.exposure_rupees),0)::numeric
  from public.dividend_tds_capa_actions_r3635 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3635_tds_exposure_digest() from public, anon;
grant execute on function public.founder_r3635_tds_exposure_digest() to authenticated;

-- 8) High-risk queue (short-deducted / non-compliant / deposit-pending)
create or replace function public.founder_r3635_high_risk_queue()
returns table(
  shareholder_class text,
  distribution_ref text,
  period_month date,
  compliance_status text,
  tds_rate_pct numeric,
  tds_deductible_rupees numeric,
  tds_deducted_rupees numeric,
  tds_deposited_rupees numeric,
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
  select l.shareholder_class, l.distribution_ref, l.period_month,
    l.compliance_status, l.tds_rate_pct, l.tds_deductible_rupees,
    l.tds_deducted_rupees, l.tds_deposited_rupees, l.trend_dir, l.notes
  from public.dividend_tds_r3635 l
  where l.compliance_status in ('short_deducted','non_compliant','deposit_pending')
     or l.tds_deducted_rupees < l.tds_deductible_rupees
     or l.tds_deposited_rupees < l.tds_deducted_rupees
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.shareholder_class;
end;
$$;

revoke execute on function public.founder_r3635_high_risk_queue() from public, anon;
grant execute on function public.founder_r3635_high_risk_queue() to authenticated;
