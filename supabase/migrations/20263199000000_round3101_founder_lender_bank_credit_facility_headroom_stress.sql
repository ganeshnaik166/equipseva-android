-- Round r3101 — Founder Quarterly Strategic Engineer-Founder Lender-Bank Credit Facility Headroom Stress Tracker
-- Working-capital line + invoice discounting + overdraft headroom
-- bank × sanctioned vs utilized × covenant compliance × interest cover × headroom under stress

set search_path = public, pg_temp;

-- =====================================================================
-- TABLE 1: credit_facility_lines_r3101
-- One row per lender × facility (working capital, invoice discounting, overdraft, term loan)
-- =====================================================================
create table if not exists credit_facility_lines_r3101 (
  id uuid primary key default gen_random_uuid(),
  lender_name text not null,
  lender_type text not null check (lender_type in (
    'public_sector_bank', 'private_sector_bank', 'small_finance_bank',
    'nbfc', 'fintech_lender', 'invoice_discounting_platform', 'foreign_bank'
  )),
  facility_type text not null check (facility_type in (
    'working_capital_demand_loan', 'cash_credit_overdraft',
    'invoice_discounting', 'bill_discounting', 'term_loan',
    'letter_of_credit_sublimit', 'bank_guarantee_sublimit',
    'merchant_cash_advance', 'revolving_credit_line'
  )),
  facility_code text not null unique,
  sanctioned_limit_rupees bigint not null check (sanctioned_limit_rupees > 0),
  current_utilization_rupees bigint not null default 0 check (current_utilization_rupees >= 0),
  interest_rate_pct numeric(6,3) not null check (interest_rate_pct >= 0 and interest_rate_pct <= 36),
  collateral_type text not null check (collateral_type in (
    'unsecured', 'fd_lien', 'book_debts_hypothecation', 'stock_hypothecation',
    'property_mortgage', 'promoter_guarantee', 'corporate_guarantee', 'mixed_collateral'
  )),
  covenant_status text not null check (covenant_status in (
    'compliant', 'watchlist', 'breach_minor', 'breach_major', 'cure_period', 'waived'
  )),
  sanction_date date not null,
  next_review_date date not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_cf_lines_r3101_lender_type on credit_facility_lines_r3101(lender_type);
create index if not exists idx_cf_lines_r3101_covenant on credit_facility_lines_r3101(covenant_status);

-- =====================================================================
-- TABLE 2: credit_facility_stress_snapshots_r3101
-- Quarterly stress snapshot per facility — covenant ratios + headroom under scenarios
-- =====================================================================
create table if not exists credit_facility_stress_snapshots_r3101 (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references credit_facility_lines_r3101(id) on delete cascade,
  fiscal_quarter text not null check (fiscal_quarter ~ '^FY[0-9]{2}-Q[1-4]$'),
  snapshot_date date not null,
  scenario text not null check (scenario in (
    'base_case', 'mild_stress', 'moderate_stress', 'severe_stress',
    'liquidity_shock', 'rate_hike_200bps', 'amc_churn_20pct', 'monsoon_seasonality'
  )),
  ebitda_rupees bigint not null,
  interest_expense_rupees bigint not null check (interest_expense_rupees >= 0),
  interest_cover_ratio numeric(6,2) not null,
  debt_service_cover_ratio numeric(6,2) not null,
  current_ratio numeric(6,2) not null check (current_ratio >= 0),
  debt_to_equity_ratio numeric(6,2) not null check (debt_to_equity_ratio >= 0),
  projected_utilization_rupees bigint not null check (projected_utilization_rupees >= 0),
  headroom_rupees bigint not null,
  headroom_days_runway integer not null check (headroom_days_runway >= 0),
  covenant_breach_flag boolean not null default false,
  remediation_action text check (remediation_action in (
    'none_required', 'monitor_weekly', 'reduce_utilization', 'inject_promoter_equity',
    'renegotiate_covenant', 'refinance_facility', 'invoke_cure_period',
    'partial_prepayment', 'collateral_top_up', 'lender_meeting_scheduled'
  )),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_cf_stress_r3101_facility on credit_facility_stress_snapshots_r3101(facility_id);
create index if not exists idx_cf_stress_r3101_quarter on credit_facility_stress_snapshots_r3101(fiscal_quarter);
create index if not exists idx_cf_stress_r3101_scenario on credit_facility_stress_snapshots_r3101(scenario);

-- =====================================================================
-- SEEDS — 8 facilities + 16 stress snapshots = 24 rows total
-- =====================================================================
insert into credit_facility_lines_r3101 (
  lender_name, lender_type, facility_type, facility_code,
  sanctioned_limit_rupees, current_utilization_rupees, interest_rate_pct,
  collateral_type, covenant_status, sanction_date, next_review_date, notes
) values
  ('State Bank of India', 'public_sector_bank', 'cash_credit_overdraft', 'SBI-CC-HYD-001',
   25000000, 18750000, 9.250, 'book_debts_hypothecation', 'compliant',
   '2025-04-15', '2026-09-30', 'Primary OD line — Hyderabad branch, renewed FY26'),
  ('HDFC Bank', 'private_sector_bank', 'working_capital_demand_loan', 'HDFC-WCDL-002',
   15000000, 12000000, 10.500, 'mixed_collateral', 'compliant',
   '2025-07-01', '2026-12-31', 'WCDL against spare parts inventory + book debts'),
  ('ICICI Bank', 'private_sector_bank', 'invoice_discounting', 'ICICI-ID-003',
   20000000, 14200000, 11.750, 'book_debts_hypothecation', 'watchlist',
   '2025-09-10', '2026-08-15', 'Hospital invoice discounting — Apollo + Yashoda receivables'),
  ('AU Small Finance Bank', 'small_finance_bank', 'cash_credit_overdraft', 'AU-OD-004',
   8000000, 7600000, 12.250, 'fd_lien', 'breach_minor',
   '2025-06-20', '2026-07-20', 'Minor breach — current ratio dipped to 1.18 vs 1.25 covenant'),
  ('Bajaj Finserv', 'nbfc', 'merchant_cash_advance', 'BAJAJ-MCA-005',
   5000000, 4750000, 16.500, 'unsecured', 'cure_period',
   '2025-10-05', '2026-07-05', 'Cure period until 2026-07-15 — DSCR remediation in progress'),
  ('KredX', 'invoice_discounting_platform', 'bill_discounting', 'KREDX-BD-006',
   10000000, 6800000, 13.250, 'book_debts_hypothecation', 'compliant',
   '2025-11-12', '2026-11-12', 'Hospital bill discounting — 60-day tenor, AAA buyer rated'),
  ('Yes Bank', 'private_sector_bank', 'letter_of_credit_sublimit', 'YES-LC-007',
   12000000, 4500000, 8.750, 'corporate_guarantee', 'compliant',
   '2025-08-25', '2026-10-25', 'LC sublimit for imported spare parts from Siemens Germany'),
  ('Lendingkart', 'fintech_lender', 'revolving_credit_line', 'LK-RCL-008',
   6000000, 5950000, 18.500, 'promoter_guarantee', 'breach_major',
   '2025-05-30', '2026-06-30', 'Major breach — debt-to-equity 3.2 vs 2.5 covenant, lender mtg scheduled')
on conflict (facility_code) do nothing;

insert into credit_facility_stress_snapshots_r3101 (
  facility_id, fiscal_quarter, snapshot_date, scenario,
  ebitda_rupees, interest_expense_rupees, interest_cover_ratio, debt_service_cover_ratio,
  current_ratio, debt_to_equity_ratio, projected_utilization_rupees, headroom_rupees,
  headroom_days_runway, covenant_breach_flag, remediation_action, notes
)
select f.id, q.fq, q.sd, q.sc, q.eb, q.ie, q.icr, q.dscr, q.cr, q.de, q.pu, q.hr, q.hd, q.br, q.ra, q.nt
from credit_facility_lines_r3101 f
join (values
  ('SBI-CC-HYD-001', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.85, 1.65, 1.40, 18750000::bigint, 6250000::bigint, 92, false, 'none_required',
   'Q1 base case — comfortable headroom, ICR well above 4.0 covenant'),
  ('SBI-CC-HYD-001', 'FY26-Q1', date '2026-06-15', 'rate_hike_200bps',
   42500000::bigint, 5350000::bigint, 7.94, 2.20, 1.55, 1.45, 21000000::bigint, 4000000::bigint, 58, false, 'monitor_weekly',
   'Q1 +200bps stress — ICR holds, headroom thins to 58 days'),
  ('HDFC-WCDL-002', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.85, 1.65, 1.40, 12000000::bigint, 3000000::bigint, 75, false, 'none_required',
   'WCDL base case — 80% drawn, 20% headroom'),
  ('HDFC-WCDL-002', 'FY26-Q1', date '2026-06-15', 'amc_churn_20pct',
   34000000::bigint, 4250000::bigint, 8.00, 2.10, 1.42, 1.55, 14500000::bigint, 500000::bigint, 12, true, 'reduce_utilization',
   'AMC churn 20% scenario — covenant breach flagged, immediate utilization reduction'),
  ('ICICI-ID-003', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.85, 1.65, 1.40, 14200000::bigint, 5800000::bigint, 88, false, 'monitor_weekly',
   'Invoice discounting base case — Apollo + Yashoda performing'),
  ('ICICI-ID-003', 'FY26-Q1', date '2026-06-15', 'moderate_stress',
   38000000::bigint, 4250000::bigint, 8.94, 2.45, 1.50, 1.50, 17500000::bigint, 2500000::bigint, 35, false, 'monitor_weekly',
   'Moderate stress — hospital DSO stretched to 75 days, watchlist holds'),
  ('AU-OD-004', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.20, 1.18, 1.40, 7600000::bigint, 400000::bigint, 18, true, 'inject_promoter_equity',
   'Current ratio 1.18 vs 1.25 covenant — promoter equity injection 30L planned'),
  ('AU-OD-004', 'FY26-Q1', date '2026-06-15', 'liquidity_shock',
   42500000::bigint, 4250000::bigint, 10.00, 1.65, 0.95, 1.55, 8000000::bigint, 0::bigint, 0, true, 'renegotiate_covenant',
   'Liquidity shock — zero headroom, covenant renegotiation required'),
  ('BAJAJ-MCA-005', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.10, 1.45, 1.80, 4750000::bigint, 250000::bigint, 8, true, 'partial_prepayment',
   'MCA cure period active — DSCR 2.10 vs 2.25 covenant, 5L prepayment scheduled'),
  ('BAJAJ-MCA-005', 'FY26-Q1', date '2026-06-15', 'severe_stress',
   30000000::bigint, 4250000::bigint, 7.06, 1.45, 1.20, 2.10, 5000000::bigint, 0::bigint, 0, true, 'refinance_facility',
   'Severe stress — refinance required, NBFC quote in hand from Tata Capital'),
  ('KREDX-BD-006', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.85, 1.65, 1.40, 6800000::bigint, 3200000::bigint, 95, false, 'none_required',
   'KredX BD comfortable — AAA buyer pool, 60-day tenor predictable'),
  ('KREDX-BD-006', 'FY26-Q1', date '2026-06-15', 'monsoon_seasonality',
   36000000::bigint, 4250000::bigint, 8.47, 2.30, 1.55, 1.45, 8500000::bigint, 1500000::bigint, 42, false, 'monitor_weekly',
   'Monsoon Q1 dip in dental + diagnostic equipment service revenue'),
  ('YES-LC-007', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.85, 1.65, 1.40, 4500000::bigint, 7500000::bigint, 180, false, 'none_required',
   'LC sublimit — Siemens CT scanner part imports, low utilization'),
  ('YES-LC-007', 'FY26-Q1', date '2026-06-15', 'mild_stress',
   40000000::bigint, 4250000::bigint, 9.41, 2.70, 1.60, 1.42, 6000000::bigint, 6000000::bigint, 145, false, 'none_required',
   'Mild stress — INR depreciation 3% nudges LC utilization up'),
  ('LK-RCL-008', 'FY26-Q1', date '2026-06-15', 'base_case',
   42500000::bigint, 4250000::bigint, 10.00, 2.85, 1.30, 3.20, 5950000::bigint, 50000::bigint, 2, true, 'lender_meeting_scheduled',
   'Major covenant breach — D/E 3.2 vs 2.5, lender meeting 2026-06-25'),
  ('LK-RCL-008', 'FY26-Q1', date '2026-06-15', 'severe_stress',
   28000000::bigint, 4250000::bigint, 6.59, 1.25, 1.05, 3.80, 6000000::bigint, 0::bigint, 0, true, 'collateral_top_up',
   'Severe stress — promoter collateral top-up 25L being arranged')
) as q(fc, fq, sd, sc, eb, ie, icr, dscr, cr, de, pu, hr, hd, br, ra, nt) on f.facility_code = q.fc;

-- =====================================================================
-- RPC 1: facility_portfolio_summary
-- =====================================================================
create or replace function facility_portfolio_summary_r3101()
returns table(
  lender_type text,
  facility_count bigint,
  total_sanctioned_rupees bigint,
  total_utilized_rupees bigint,
  total_headroom_rupees bigint,
  utilization_pct numeric,
  avg_interest_rate_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    f.lender_type,
    count(*)::bigint,
    sum(f.sanctioned_limit_rupees)::bigint,
    sum(f.current_utilization_rupees)::bigint,
    sum(f.sanctioned_limit_rupees - f.current_utilization_rupees)::bigint,
    round(100.0 * sum(f.current_utilization_rupees)::numeric / nullif(sum(f.sanctioned_limit_rupees), 0), 2),
    round(avg(f.interest_rate_pct)::numeric, 3)
  from credit_facility_lines_r3101 f
  group by f.lender_type
  order by sum(f.sanctioned_limit_rupees) desc;
end;
$$;

revoke execute on function facility_portfolio_summary_r3101() from public, anon;
grant execute on function facility_portfolio_summary_r3101() to authenticated;

-- =====================================================================
-- RPC 2: covenant_status_breakdown
-- =====================================================================
create or replace function covenant_status_breakdown_r3101()
returns table(
  covenant_status text,
  facility_count bigint,
  exposure_rupees bigint,
  pct_of_portfolio numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  total_exposure bigint;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  select coalesce(sum(current_utilization_rupees), 0) into total_exposure from credit_facility_lines_r3101;
  return query
  select
    f.covenant_status,
    count(*)::bigint,
    sum(f.current_utilization_rupees)::bigint,
    round(100.0 * sum(f.current_utilization_rupees)::numeric / nullif(total_exposure, 0), 2)
  from credit_facility_lines_r3101 f
  group by f.covenant_status
  order by sum(f.current_utilization_rupees) desc;
end;
$$;

revoke execute on function covenant_status_breakdown_r3101() from public, anon;
grant execute on function covenant_status_breakdown_r3101() to authenticated;

-- =====================================================================
-- RPC 3: facility_headroom_ranking
-- =====================================================================
create or replace function facility_headroom_ranking_r3101()
returns table(
  facility_code text,
  lender_name text,
  facility_type text,
  sanctioned_rupees bigint,
  utilized_rupees bigint,
  headroom_rupees bigint,
  utilization_pct numeric,
  covenant_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    f.facility_code,
    f.lender_name,
    f.facility_type,
    f.sanctioned_limit_rupees,
    f.current_utilization_rupees,
    (f.sanctioned_limit_rupees - f.current_utilization_rupees)::bigint,
    round(100.0 * f.current_utilization_rupees::numeric / nullif(f.sanctioned_limit_rupees, 0), 2),
    f.covenant_status
  from credit_facility_lines_r3101 f
  order by (f.sanctioned_limit_rupees - f.current_utilization_rupees) asc;
end;
$$;

revoke execute on function facility_headroom_ranking_r3101() from public, anon;
grant execute on function facility_headroom_ranking_r3101() to authenticated;

-- =====================================================================
-- RPC 4: stress_scenario_summary
-- =====================================================================
create or replace function stress_scenario_summary_r3101()
returns table(
  scenario text,
  snapshot_count bigint,
  avg_interest_cover_ratio numeric,
  avg_dscr numeric,
  breach_count bigint,
  total_headroom_rupees bigint,
  avg_runway_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    s.scenario,
    count(*)::bigint,
    round(avg(s.interest_cover_ratio)::numeric, 2),
    round(avg(s.debt_service_cover_ratio)::numeric, 2),
    sum(case when s.covenant_breach_flag then 1 else 0 end)::bigint,
    sum(s.headroom_rupees)::bigint,
    round(avg(s.headroom_days_runway)::numeric, 1)
  from credit_facility_stress_snapshots_r3101 s
  group by s.scenario
  order by avg(s.headroom_days_runway) asc;
end;
$$;

revoke execute on function stress_scenario_summary_r3101() from public, anon;
grant execute on function stress_scenario_summary_r3101() to authenticated;

-- =====================================================================
-- RPC 5: covenant_breach_drilldown
-- =====================================================================
create or replace function covenant_breach_drilldown_r3101()
returns table(
  facility_code text,
  lender_name text,
  scenario text,
  interest_cover_ratio numeric,
  debt_service_cover_ratio numeric,
  current_ratio numeric,
  debt_to_equity_ratio numeric,
  headroom_rupees bigint,
  remediation_action text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    f.facility_code,
    f.lender_name,
    s.scenario,
    s.interest_cover_ratio,
    s.debt_service_cover_ratio,
    s.current_ratio,
    s.debt_to_equity_ratio,
    s.headroom_rupees,
    s.remediation_action
  from credit_facility_stress_snapshots_r3101 s
  join credit_facility_lines_r3101 f on f.id = s.facility_id
  where s.covenant_breach_flag = true
  order by s.headroom_rupees asc, s.debt_service_cover_ratio asc;
end;
$$;

revoke execute on function covenant_breach_drilldown_r3101() from public, anon;
grant execute on function covenant_breach_drilldown_r3101() to authenticated;

-- =====================================================================
-- RPC 6: interest_cover_distribution
-- =====================================================================
create or replace function interest_cover_distribution_r3101()
returns table(
  cover_band text,
  snapshot_count bigint,
  pct_of_total numeric,
  avg_headroom_rupees bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  total_count bigint;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  select count(*) into total_count from credit_facility_stress_snapshots_r3101;
  return query
  select
    case
      when s.interest_cover_ratio >= 10 then '01_excellent_gte_10x'
      when s.interest_cover_ratio >= 5 then '02_strong_5x_to_10x'
      when s.interest_cover_ratio >= 3 then '03_adequate_3x_to_5x'
      when s.interest_cover_ratio >= 1.5 then '04_thin_1_5x_to_3x'
      else '05_distressed_lt_1_5x'
    end as cover_band,
    count(*)::bigint,
    round(100.0 * count(*)::numeric / nullif(total_count, 0), 2),
    avg(s.headroom_rupees)::bigint
  from credit_facility_stress_snapshots_r3101 s
  group by 1
  order by 1;
end;
$$;

revoke execute on function interest_cover_distribution_r3101() from public, anon;
grant execute on function interest_cover_distribution_r3101() to authenticated;

-- =====================================================================
-- RPC 7: remediation_action_queue
-- =====================================================================
create or replace function remediation_action_queue_r3101()
returns table(
  remediation_action text,
  action_count bigint,
  affected_facilities bigint,
  total_exposure_rupees bigint,
  min_runway_days integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    s.remediation_action,
    count(*)::bigint,
    count(distinct s.facility_id)::bigint,
    sum(s.projected_utilization_rupees)::bigint,
    min(s.headroom_days_runway)
  from credit_facility_stress_snapshots_r3101 s
  where s.remediation_action is not null
    and s.remediation_action <> 'none_required'
  group by s.remediation_action
  order by min(s.headroom_days_runway) asc;
end;
$$;

revoke execute on function remediation_action_queue_r3101() from public, anon;
grant execute on function remediation_action_queue_r3101() to authenticated;

-- =====================================================================
-- RPC 8: facility_type_concentration
-- =====================================================================
create or replace function facility_type_concentration_r3101()
returns table(
  facility_type text,
  facility_count bigint,
  total_sanctioned_rupees bigint,
  total_utilized_rupees bigint,
  weighted_avg_rate_pct numeric,
  pct_of_total_sanctioned numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  total_sanc bigint;
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  select coalesce(sum(sanctioned_limit_rupees), 0) into total_sanc from credit_facility_lines_r3101;
  return query
  select
    f.facility_type,
    count(*)::bigint,
    sum(f.sanctioned_limit_rupees)::bigint,
    sum(f.current_utilization_rupees)::bigint,
    round(
      sum(f.interest_rate_pct * f.current_utilization_rupees)::numeric
        / nullif(sum(f.current_utilization_rupees), 0),
      3
    ),
    round(100.0 * sum(f.sanctioned_limit_rupees)::numeric / nullif(total_sanc, 0), 2)
  from credit_facility_lines_r3101 f
  group by f.facility_type
  order by sum(f.sanctioned_limit_rupees) desc;
end;
$$;

revoke execute on function facility_type_concentration_r3101() from public, anon;
grant execute on function facility_type_concentration_r3101() to authenticated;

-- =====================================================================
-- RPC 9: collateral_exposure_breakdown
-- =====================================================================
create or replace function collateral_exposure_breakdown_r3101()
returns table(
  collateral_type text,
  facility_count bigint,
  total_exposure_rupees bigint,
  avg_interest_rate_pct numeric,
  watchlist_or_breach_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then
    raise exception 'forbidden';
  end if;
  return query
  select
    f.collateral_type,
    count(*)::bigint,
    sum(f.current_utilization_rupees)::bigint,
    round(avg(f.interest_rate_pct)::numeric, 3),
    sum(case when f.covenant_status in ('watchlist', 'breach_minor', 'breach_major', 'cure_period') then 1 else 0 end)::bigint
  from credit_facility_lines_r3101 f
  group by f.collateral_type
  order by sum(f.current_utilization_rupees) desc;
end;
$$;

revoke execute on function collateral_exposure_breakdown_r3101() from public, anon;
grant execute on function collateral_exposure_breakdown_r3101() to authenticated;
