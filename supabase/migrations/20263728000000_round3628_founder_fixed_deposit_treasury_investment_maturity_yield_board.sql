-- Round 3628: Founder Fixed-Deposit / Treasury-Investment Maturity & Yield Board
-- FD / treasury ladder — instrument × institution × principal × interest rate × accrued interest × maturity value × days-to-maturity × benchmark yield × yield spread × lien × maturity bucket × yield-status verdict × CAPA

-- =============================================================================
-- TABLE 1: fd_treasury_r3628 — per-instrument fixed-deposit / treasury holdings
-- =============================================================================
create table if not exists public.fd_treasury_r3628 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  instrument_code text not null,
  instrument_name text not null,
  institution text not null,
  period_month date not null,
  principal_rupees numeric(14,2) not null,
  interest_rate_pct numeric(5,2) not null,
  accrued_interest_rupees numeric(14,2),
  maturity_value_rupees numeric(14,2),
  days_to_maturity int,
  benchmark_yield_pct numeric(5,2),
  yield_spread_pct numeric(6,2),
  lien_marked boolean not null,
  maturity_bucket text not null check (maturity_bucket in (
    '0_30_days','31_90_days','91_180_days','over_180_days'
  )),
  yield_status text not null check (yield_status in (
    'optimal','on_benchmark','below_benchmark','idle_surplus','lien_locked'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fd_treasury_r3628 enable row level security;

create index if not exists idx_fd_treasury_r3628_org on public.fd_treasury_r3628(organization_id);
create index if not exists idx_fd_treasury_r3628_month on public.fd_treasury_r3628(period_month);
create index if not exists idx_fd_treasury_r3628_status on public.fd_treasury_r3628(yield_status);

-- =============================================================================
-- TABLE 2: fd_treasury_capa_actions_r3628 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.fd_treasury_capa_actions_r3628 (
  id uuid primary key default gen_random_uuid(),
  fd_id uuid not null references public.fd_treasury_r3628(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'maturity_ladder_concentration','idle_surplus_uninvested','below_benchmark_yield',
    'premature_withdrawal_penalty','lien_documentation_gap','interest_accrual_mismatch',
    'auto_renewal_at_low_rate','tds_reconciliation_gap','counterparty_concentration','unclaimed_matured_deposit'
  )),
  root_cause text not null check (root_cause in (
    'manual_treasury_tracking','delayed_reinvestment_decision','rate_negotiation_not_done',
    'bank_system_sync_failure','policy_ambiguity','cashflow_forecast_error',
    'clerical_entry_error','pending_investigation','approval_workflow_delay','benchmark_not_reviewed'
  )),
  corrective_action text not null check (corrective_action in (
    'sweep_to_higher_yield_fd','ladder_maturities','renegotiate_rate','break_and_reinvest',
    'update_lien_documentation','reconcile_interest_accrual','disable_auto_renewal',
    'file_tds_correction','diversify_counterparty','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'rbi_deposit_norms','companies_act_filing','income_tax_tds','none','internal_only','audit_observation'
  )),
  target_closure_date date,
  actual_closure_date date,
  impact_rupees numeric(14,2),
  owner text,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.fd_treasury_capa_actions_r3628 enable row level security;

create index if not exists idx_fd_treasury_capa_r3628_fd on public.fd_treasury_capa_actions_r3628(fd_id);
create index if not exists idx_fd_treasury_capa_r3628_status on public.fd_treasury_capa_actions_r3628(capa_status);

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

  -- 16 FD / treasury instrument rows
  insert into public.fd_treasury_r3628 (
    organization_id, instrument_code, instrument_name, institution, period_month,
    principal_rupees, interest_rate_pct, accrued_interest_rupees, maturity_value_rupees, days_to_maturity,
    benchmark_yield_pct, yield_spread_pct, lien_marked, maturity_bucket, yield_status, trend_dir, notes
  )
  select v_org_id, q.icode, q.iname, q.inst, q.pmon::date,
    q.prin, q.irate, q.accr, q.mval, q.d2m,
    q.byield, q.spread, q.lien, q.mbkt, q.ystat, q.tdir, q.nt
  from (values
    ('FD-SBI-001','SBI 91-Day Bulk FD','State Bank of India','2026-07-01',
     5000000,7.10,42000.00,5089000.00,74,7.00,0.10,false,'31_90_days','on_benchmark','stable','Core AMC float parked at SBI, rate at benchmark'),
    ('FD-HDFC-002','HDFC Corporate FD 180D','HDFC Bank','2026-07-01',
     8000000,7.45,118000.00,8298000.00,150,7.05,0.40,false,'91_180_days','optimal','improving','Spare-parts import buffer; negotiated +40bps over card rate'),
    ('FD-ICICI-003','ICICI iWish RD Sweep','ICICI Bank','2026-06-01',
     3000000,6.50,22000.00,3060000.00,20,6.90,-0.40,false,'0_30_days','below_benchmark','worsening','Sweep account auto-renewed at low card rate; below benchmark'),
    ('FD-AXIS-004','Axis Liquid Surplus FD','Axis Bank','2026-07-01',
     2500000,6.25,8500.00,2512000.00,12,7.00,-0.75,false,'0_30_days','idle_surplus','worsening','Diagnostics collection surplus sitting idle at savings-linked rate'),
    ('FD-KOTAK-005','Kotak 1Y Cumulative FD','Kotak Mahindra Bank','2026-05-01',
     6000000,7.30,210000.00,6438000.00,220,7.10,0.20,true,'over_180_days','lien_locked','stable','Lien-marked against bank guarantee for AIIMS project'),
    ('FD-YES-006','Yes Bank Bulk FD','Yes Bank','2026-06-01',
     4000000,7.75,95000.00,4155000.00,60,7.10,0.65,false,'31_90_days','optimal','improving','Higher NBFC-tier rate captured on projects escrow'),
    ('FD-BOB-007','Bank of Baroda 1Y FD','Bank of Baroda','2026-04-01',
     3500000,6.80,145000.00,3688000.00,300,7.05,-0.25,false,'over_180_days','below_benchmark','worsening','Long lock at stale rate; reinvestment review pending'),
    ('FD-IDFC-008','IDFC First 91D FD','IDFC First Bank','2026-07-01',
     4500000,7.50,41000.00,4589000.00,80,7.10,0.40,false,'31_90_days','optimal','stable','Projects milestone receipt laddered at 91 days'),
    ('FD-SBI-009','SBI Flexi OD-linked FD','State Bank of India','2026-06-01',
     7000000,7.00,130000.00,7175000.00,130,7.05,-0.05,true,'91_180_days','lien_locked','stable','OD-linked; lien against working-capital overdraft limit'),
    ('FD-HDFC-010','HDFC 30D Short FD','HDFC Bank','2026-07-01',
     2000000,6.40,3500.00,2004000.00,8,7.00,-0.60,false,'0_30_days','idle_surplus','worsening','GST-payout surplus idle; sweep to higher-yield pending'),
    ('FD-ICICI-011','ICICI 1Y Bulk FD','ICICI Bank','2026-05-01',
     9000000,7.40,320000.00,9666000.00,200,7.10,0.30,false,'over_180_days','optimal','improving','Largest single deposit; annual projects reserve'),
    ('FD-AXIS-012','Axis 6M FD','Axis Bank','2026-06-01',
     3200000,7.05,58000.00,3312000.00,100,7.05,0.00,false,'91_180_days','on_benchmark','stable','AMC renewals reserve at card rate'),
    ('FD-KOTAK-013','Kotak 45D FD','Kotak Mahindra Bank','2026-07-01',
     1500000,6.60,4200.00,1512000.00,25,7.00,-0.40,false,'0_30_days','below_benchmark','worsening','Small parcel below benchmark; consolidate at maturity'),
    ('FD-TBILL-014','182-Day T-Bill','RBI Treasury','2026-04-01',
     5000000,6.95,140000.00,5175000.00,160,7.05,-0.10,false,'91_180_days','on_benchmark','stable','Sovereign T-bill; safety over yield for compliance reserve'),
    ('FD-BOB-015','BoB 15D Ultra-Short FD','Bank of Baroda','2026-07-01',
     1800000,6.20,1500.00,1803000.00,10,7.00,-0.80,false,'0_30_days','idle_surplus','worsening','Payroll float idle; lowest-yield parcel in book'),
    ('FD-IDFC-016','IDFC First 1Y FD','IDFC First Bank','2026-05-01',
     4200000,7.60,175000.00,4519000.00,240,7.10,0.50,true,'over_180_days','lien_locked','improving','Lien-marked for spare-parts LC margin at IDFC')
  ) as q(icode, iname, inst, pmon, prin, irate, accr, mval, d2m, byield, spread, lien, mbkt, ystat, tdir, nt);

  -- CAPA seed — attach to specific instruments by instrument_code
  insert into public.fd_treasury_capa_actions_r3628 (
    fd_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, target_closure_date, actual_closure_date,
    impact_rupees, owner, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.impact, q.ownr, q.nt
  from (values
    ('FD-AXIS-004','idle_surplus_uninvested','delayed_reinvestment_decision','sweep_to_higher_yield_fd','in_progress','internal_only','2026-08-05',null,45000.00,'Treasury Desk — Kavya','Diagnostics surplus to be swept into 90D higher-yield FD'),
    ('FD-ICICI-003','auto_renewal_at_low_rate','benchmark_not_reviewed','disable_auto_renewal','open','internal_only','2026-08-10',null,28000.00,'Treasury Desk — Kavya','Auto-renew flag on iWish sweep to be disabled at maturity'),
    ('FD-BOB-007','below_benchmark_yield','rate_negotiation_not_done','renegotiate_rate','escalated','audit_observation','2026-07-28',null,62000.00,'Finance Controller — Vikram','Long-lock BoB FD 25bps under benchmark; escalate to relationship manager'),
    ('FD-BOB-015','idle_surplus_uninvested','cashflow_forecast_error','sweep_to_higher_yield_fd','verification_pending','internal_only','2026-08-01',null,18000.00,'Treasury Desk — Kavya','Payroll float over-provisioned; consolidate into ladder'),
    ('FD-KOTAK-005','lien_documentation_gap','clerical_entry_error','update_lien_documentation','closed','companies_act_filing','2026-07-15','2026-07-12',0.00,'Company Secretary — Priya','Lien letter for AIIMS BG re-executed and filed'),
    ('FD-HDFC-010','idle_surplus_uninvested','approval_workflow_delay','ladder_maturities','overdue','internal_only','2026-07-20',null,22000.00,'Treasury Desk — Kavya','GST-payout surplus sweep approval overdue with CFO'),
    ('FD-KOTAK-013','below_benchmark_yield','manual_treasury_tracking','break_and_reinvest','open','none','2026-08-15',null,9000.00,'Treasury Desk — Kavya','Small parcel to break and consolidate at maturity'),
    ('FD-TBILL-014','tds_reconciliation_gap','bank_system_sync_failure','file_tds_correction','in_progress','income_tax_tds','2026-08-08',null,35000.00,'Finance Controller — Vikram','Form 26AS mismatch on T-bill interest; file correction')
  ) as q(icode, fc, rc, ca, cst, ri, tcd, acd, impact, ownr, nt)
  join public.fd_treasury_r3628 e
    on e.organization_id = v_org_id and e.instrument_code = q.icode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Yield-status distribution
create or replace function public.founder_r3628_yield_status_rollup()
returns table(yield_status text, instruments bigint, total_principal_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fd_treasury_r3628)
  select f.yield_status, count(*)::bigint,
         coalesce(sum(f.principal_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.fd_treasury_r3628 f
  group by f.yield_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3628_yield_status_rollup() from public, anon;
grant execute on function public.founder_r3628_yield_status_rollup() to authenticated;

-- 2) Institution scorecard
create or replace function public.founder_r3628_institution_scorecard()
returns table(
  institution text,
  deposits bigint,
  total_principal_rupees numeric,
  total_accrued_rupees numeric,
  below_benchmark bigint,
  idle_surplus bigint,
  avg_yield_spread_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.institution,
    count(*)::bigint,
    coalesce(sum(f.principal_rupees),0)::numeric,
    coalesce(sum(f.accrued_interest_rupees),0)::numeric,
    count(*) filter (where f.yield_status = 'below_benchmark')::bigint,
    count(*) filter (where f.yield_status = 'idle_surplus')::bigint,
    round(avg(f.yield_spread_pct), 2)
  from public.fd_treasury_r3628 f
  group by f.institution
  order by coalesce(sum(f.principal_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3628_institution_scorecard() from public, anon;
grant execute on function public.founder_r3628_institution_scorecard() to authenticated;

-- 3) Maturity-bucket × yield-status matrix
create or replace function public.founder_r3628_bucket_status_matrix()
returns table(maturity_bucket text, yield_status text, instruments bigint, total_principal_rupees numeric, avg_yield_spread_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.maturity_bucket, f.yield_status, count(*)::bigint,
    coalesce(sum(f.principal_rupees),0)::numeric,
    round(avg(f.yield_spread_pct), 2)
  from public.fd_treasury_r3628 f
  group by f.maturity_bucket, f.yield_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3628_bucket_status_matrix() from public, anon;
grant execute on function public.founder_r3628_bucket_status_matrix() to authenticated;

-- 4) Monthly yield trend
create or replace function public.founder_r3628_monthly_yield_trend()
returns table(
  period_month date,
  deposits bigint,
  total_principal_rupees numeric,
  avg_interest_rate_pct numeric,
  avg_benchmark_yield_pct numeric,
  avg_yield_spread_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.period_month,
    count(*)::bigint,
    coalesce(sum(f.principal_rupees),0)::numeric,
    round(avg(f.interest_rate_pct), 2),
    round(avg(f.benchmark_yield_pct), 2),
    round(avg(f.yield_spread_pct), 2)
  from public.fd_treasury_r3628 f
  group by f.period_month
  order by f.period_month desc;
end;
$$;

revoke execute on function public.founder_r3628_monthly_yield_trend() from public, anon;
grant execute on function public.founder_r3628_monthly_yield_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3628_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
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
  from public.fd_treasury_capa_actions_r3628 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3628_capa_status_board() from public, anon;
grant execute on function public.founder_r3628_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3628_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.fd_treasury_capa_actions_r3628)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.fd_treasury_capa_actions_r3628 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3628_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3628_root_cause_pareto() to authenticated;

-- 7) Idle-surplus / below-benchmark digest by institution
create or replace function public.founder_r3628_idle_surplus_digest()
returns table(
  institution text,
  idle_surplus_instruments bigint,
  below_benchmark_instruments bigint,
  idle_principal_rupees numeric,
  avg_yield_spread_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.institution,
    count(*) filter (where f.yield_status = 'idle_surplus')::bigint,
    count(*) filter (where f.yield_status = 'below_benchmark')::bigint,
    coalesce(sum(f.principal_rupees) filter (where f.yield_status in ('idle_surplus','below_benchmark')),0)::numeric,
    round(avg(f.yield_spread_pct) filter (where f.yield_status in ('idle_surplus','below_benchmark')), 2)
  from public.fd_treasury_r3628 f
  group by f.institution
  having count(*) filter (where f.yield_status in ('idle_surplus','below_benchmark')) > 0
  order by coalesce(sum(f.principal_rupees) filter (where f.yield_status in ('idle_surplus','below_benchmark')),0) desc;
end;
$$;

revoke execute on function public.founder_r3628_idle_surplus_digest() from public, anon;
grant execute on function public.founder_r3628_idle_surplus_digest() to authenticated;

-- 8) High-risk queue (below_benchmark / idle_surplus instruments)
create or replace function public.founder_r3628_high_risk_queue()
returns table(
  instrument_code text,
  instrument_name text,
  institution text,
  period_month date,
  principal_rupees numeric,
  interest_rate_pct numeric,
  benchmark_yield_pct numeric,
  yield_spread_pct numeric,
  maturity_bucket text,
  yield_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select f.instrument_code, f.instrument_name, f.institution, f.period_month,
    f.principal_rupees, f.interest_rate_pct, f.benchmark_yield_pct, f.yield_spread_pct,
    f.maturity_bucket, f.yield_status, f.notes
  from public.fd_treasury_r3628 f
  where f.yield_status in ('below_benchmark','idle_surplus')
  order by f.yield_spread_pct asc, f.principal_rupees desc;
end;
$$;

revoke execute on function public.founder_r3628_high_risk_queue() from public, anon;
grant execute on function public.founder_r3628_high_risk_queue() to authenticated;
