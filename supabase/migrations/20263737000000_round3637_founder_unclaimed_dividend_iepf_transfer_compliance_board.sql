-- Round 3637: Founder Unclaimed-Dividend / IEPF Transfer Compliance Board
-- Unclaimed-dividend log — dividend year × instrument × unclaimed/claimed/transferred amounts × due-for-transfer × shareholders × days-to-7yr-deadline × shares-transfer-due × transfer-status verdict × CAPA

-- =============================================================================
-- TABLE 1: iepf_r3637 — per-instrument unclaimed-dividend / IEPF transfer records
-- =============================================================================
create table if not exists public.iepf_r3637 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  dividend_year text not null,
  instrument_ref text not null,
  period_month date not null,
  unclaimed_amount_rupees numeric(14,2) not null,
  claimed_amount_rupees numeric(14,2) not null,
  transferred_to_iepf_rupees numeric(14,2) not null,
  due_for_transfer_rupees numeric(14,2) not null,
  shareholders_count int not null,
  days_to_7yr_deadline int not null,
  shares_transfer_due int not null,
  transfer_status text not null check (transfer_status in (
    'current','approaching_deadline','due_for_transfer','transferred','overdue'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.iepf_r3637 enable row level security;

create index if not exists idx_iepf_r3637_org on public.iepf_r3637(organization_id);
create index if not exists idx_iepf_r3637_period on public.iepf_r3637(period_month);
create index if not exists idx_iepf_r3637_status on public.iepf_r3637(transfer_status);

-- =============================================================================
-- TABLE 2: iepf_capa_actions_r3637 — CAPA & compliance actions
-- =============================================================================
create table if not exists public.iepf_capa_actions_r3637 (
  id uuid primary key default gen_random_uuid(),
  iepf_log_id uuid not null references public.iepf_r3637(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'transfer_deadline_missed','shares_not_transferred','unclaimed_amount_mismatch',
    'shareholder_untraceable','iepf_5_filing_pending','dividend_register_error',
    'nodal_officer_gap','refund_claim_backlog','bank_reconciliation_gap','form_iepf_2_overdue'
  )),
  root_cause text not null check (root_cause in (
    'manual_register_tracking','rta_data_sync_failure','shareholder_kyc_incomplete',
    'demat_mismatch','legal_review_backlog','clerical_entry_error',
    'board_calendar_slip','pending_investigation','iepf_portal_downtime'
  )),
  corrective_action text not null check (corrective_action in (
    'transfer_shares_to_iepf','file_form_iepf_2','file_form_iepf_4','reconcile_dividend_register',
    'trace_shareholder_kyc','appoint_nodal_officer','migrate_to_rta_software',
    'board_ratification','legal_opinion_obtained','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'companies_act_iepf_rules','sebi_lodr_disclosure','mca_penalty_exposure','none','internal_only','shareholder_grievance'
  )),
  exposure_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.iepf_capa_actions_r3637 enable row level security;

create index if not exists idx_iepf_capa_r3637_log on public.iepf_capa_actions_r3637(iepf_log_id);
create index if not exists idx_iepf_capa_r3637_status on public.iepf_capa_actions_r3637(capa_status);

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

  -- 16 instrument rows
  insert into public.iepf_r3637 (
    organization_id, dividend_year, instrument_ref, period_month,
    unclaimed_amount_rupees, claimed_amount_rupees, transferred_to_iepf_rupees, due_for_transfer_rupees,
    shareholders_count, days_to_7yr_deadline, shares_transfer_due, transfer_status, trend_dir, notes
  )
  select v_org_id, q.dy, q.iref, q.pm::date,
    q.unc, q.clm, q.trf, q.dft,
    q.shc, q.d2d, q.shr, q.tst, q.trd, q.nt
  from (values
    ('FY2015-16','DIV-FY1516-FINAL','2024-09-01',
     0.00,738000.00,512000.00,0.00,210,-420,0,'transferred','stable','FY15-16 final dividend and underlying shares transferred to IEPF Sep-2024'),
    ('FY2015-16','DIV-FY1516-INTERIM','2024-05-01',
     0.00,305000.00,214000.00,0.00,132,-450,0,'transferred','stable','Interim dividend IEPF transfer completed; IEPF-1 challan filed'),
    ('FY2016-17','DIV-FY1617-FINAL','2026-07-01',
     185000.00,640000.00,0.00,185000.00,96,-45,4200,'overdue','worsening','7-yr window lapsed May-2026; IEPF-4 share transfer overdue'),
    ('FY2016-17','DIV-FY1617-INTERIM','2026-07-01',
     92000.00,268000.00,0.00,92000.00,54,-12,1800,'overdue','worsening','Interim unclaimed past deadline; nodal-officer filing pending'),
    ('FY2017-18','DIV-FY1718-FINAL','2026-07-01',
     240000.00,812000.00,0.00,240000.00,128,20,5600,'due_for_transfer','worsening','7-yr deadline in 20 days; IEPF-2 statement prepared'),
    ('FY2017-18','DIV-FY1718-INTERIM','2026-07-01',
     118000.00,402000.00,0.00,118000.00,71,42,2600,'due_for_transfer','stable','Share-transfer batch queued with RTA'),
    ('FY2018-19','DIV-FY1819-FINAL','2026-07-01',
     356000.00,905000.00,0.00,0.00,164,168,0,'approaching_deadline','stable','Reminder letters dispatched to 164 shareholders'),
    ('FY2018-19','DIV-FY1819-INTERIM','2026-07-01',
     142000.00,388000.00,0.00,0.00,88,196,0,'approaching_deadline','improving','Second reminder cycle; 22 claims received this quarter'),
    ('FY2018-19','DIV-FY1819-SPECIAL','2026-07-01',
     210000.00,560000.00,0.00,0.00,103,210,0,'approaching_deadline','stable','Special dividend unclaimed pool under 7-yr watch'),
    ('FY2019-20','DIV-FY1920-FINAL','2026-07-01',
     268000.00,1120000.00,0.00,0.00,142,540,0,'current','improving','Well within window; claim ratio improving post e-KYC drive'),
    ('FY2019-20','DIV-FY1920-INTERIM','2026-07-01',
     96000.00,512000.00,0.00,0.00,61,560,0,'current','stable','Routine unclaimed-pool monitoring'),
    ('FY2020-21','DIV-FY2021-FINAL','2026-07-01',
     154000.00,980000.00,0.00,0.00,98,900,0,'current','stable','Unclaimed pool stable; no action due'),
    ('FY2020-21','DIV-FY2021-INTERIM','2026-07-01',
     72000.00,430000.00,0.00,0.00,47,920,0,'current','improving','Claims tracking ahead of prior year'),
    ('FY2021-22','DIV-FY2122-FINAL','2026-07-01',
     132000.00,1240000.00,0.00,0.00,84,1280,0,'current','improving','Recent year; low unclaimed balance'),
    ('FY2022-23','DIV-FY2223-FINAL','2026-07-01',
     98000.00,1360000.00,0.00,0.00,66,1640,0,'current','stable','Recent dividend; unclaimed within norms'),
    ('FY2023-24','DIV-FY2324-FINAL','2026-07-01',
     61000.00,1510000.00,0.00,0.00,43,2000,0,'current','improving','Latest FY; minimal unclaimed post-digital payouts')
  ) as q(dy, iref, pm, unc, clm, trf, dft, shc, d2d, shr, tst, trd, nt);

  -- CAPA seed — attach to specific instruments via instrument_ref
  insert into public.iepf_capa_actions_r3637 (
    iepf_log_id, finding_category, root_cause, corrective_action,
    capa_status, regulatory_impact, exposure_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.exp, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('DIV-FY1617-FINAL','shares_not_transferred','legal_review_backlog','transfer_shares_to_iepf',
     'escalated','mca_penalty_exposure',185000.00,'Ganesh (Company Secretary)','2026-07-31',null,'IEPF-4 share transfer overdue; penalty exposure accruing daily'),
    ('DIV-FY1617-INTERIM','iepf_5_filing_pending','clerical_entry_error','file_form_iepf_2',
     'overdue','companies_act_iepf_rules',92000.00,'Priya Nair (RTA Liaison)','2026-07-20',null,'Interim IEPF-2 statement filing missed target date'),
    ('DIV-FY1718-FINAL','transfer_deadline_missed','board_calendar_slip','board_ratification',
     'in_progress','companies_act_iepf_rules',240000.00,'Ganesh (Company Secretary)','2026-07-28',null,'Board note for share-transfer approval circulated'),
    ('DIV-FY1718-INTERIM','shareholder_untraceable','shareholder_kyc_incomplete','trace_shareholder_kyc',
     'in_progress','shareholder_grievance',118000.00,'Priya Nair (RTA Liaison)','2026-08-05',null,'71 shareholders untraceable; KYC-refresh drive underway'),
    ('DIV-FY1819-FINAL','refund_claim_backlog','rta_data_sync_failure','migrate_to_rta_software',
     'verification_pending','internal_only',45000.00,'Rohit Desai (Finance)','2026-08-10',null,'Refund-claim queue backlog cleared; verifying RTA sync'),
    ('DIV-FY1516-FINAL','dividend_register_error','clerical_entry_error','reconcile_dividend_register',
     'closed','internal_only',0.00,'Rohit Desai (Finance)','2026-06-30','2026-06-25','Register reconciled post-IEPF transfer; challan matched'),
    ('DIV-FY2223-FINAL','bank_reconciliation_gap','demat_mismatch','reconcile_dividend_register',
     'open','internal_only',12000.00,'Rohit Desai (Finance)','2026-08-15',null,'Demat vs register mismatch on 3 folios flagged'),
    ('DIV-FY1718-FINAL','form_iepf_2_overdue','iepf_portal_downtime','file_form_iepf_2',
     'escalated','mca_penalty_exposure',60000.00,'Ganesh (Company Secretary)','2026-07-25',null,'IEPF portal downtime delayed Form IEPF-2 upload')
  ) as q(iref, fc, rc, ca, cst, ri, exp, ownr, tcd, acd, nt)
  join public.iepf_r3637 e
    on e.organization_id = v_org_id and e.instrument_ref = q.iref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Transfer-status distribution
create or replace function public.founder_r3637_transfer_status_rollup()
returns table(transfer_status text, instruments bigint, total_due_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.iepf_r3637)
  select i.transfer_status, count(*)::bigint,
         coalesce(sum(i.due_for_transfer_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.iepf_r3637 i
  group by i.transfer_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3637_transfer_status_rollup() from public, anon;
grant execute on function public.founder_r3637_transfer_status_rollup() to authenticated;

-- 2) Dividend-year scorecard
create or replace function public.founder_r3637_dividend_year_scorecard()
returns table(
  dividend_year text,
  instruments bigint,
  shareholders bigint,
  total_unclaimed_rupees numeric,
  total_claimed_rupees numeric,
  total_due_rupees numeric,
  transferred_rupees numeric,
  overdue bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.dividend_year,
    count(*)::bigint,
    coalesce(sum(i.shareholders_count),0)::bigint,
    coalesce(sum(i.unclaimed_amount_rupees),0)::numeric,
    coalesce(sum(i.claimed_amount_rupees),0)::numeric,
    coalesce(sum(i.due_for_transfer_rupees),0)::numeric,
    coalesce(sum(i.transferred_to_iepf_rupees),0)::numeric,
    count(*) filter (where i.transfer_status = 'overdue')::bigint
  from public.iepf_r3637 i
  group by i.dividend_year
  order by i.dividend_year desc;
end;
$$;

revoke execute on function public.founder_r3637_dividend_year_scorecard() from public, anon;
grant execute on function public.founder_r3637_dividend_year_scorecard() to authenticated;

-- 3) Dividend-year × transfer-status matrix
create or replace function public.founder_r3637_year_status_matrix()
returns table(dividend_year text, transfer_status text, instruments bigint, total_due_rupees numeric, shareholders bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.dividend_year, i.transfer_status, count(*)::bigint,
    coalesce(sum(i.due_for_transfer_rupees),0)::numeric,
    coalesce(sum(i.shareholders_count),0)::bigint
  from public.iepf_r3637 i
  group by i.dividend_year, i.transfer_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3637_year_status_matrix() from public, anon;
grant execute on function public.founder_r3637_year_status_matrix() to authenticated;

-- 4) Monthly transfer trend
create or replace function public.founder_r3637_monthly_transfer_trend()
returns table(period_month date, instruments bigint, total_transferred_rupees numeric, total_due_rupees numeric, shares_transfer_due bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.period_month,
    count(*)::bigint,
    coalesce(sum(i.transferred_to_iepf_rupees),0)::numeric,
    coalesce(sum(i.due_for_transfer_rupees),0)::numeric,
    coalesce(sum(i.shares_transfer_due),0)::bigint
  from public.iepf_r3637 i
  group by i.period_month
  order by i.period_month desc;
end;
$$;

revoke execute on function public.founder_r3637_monthly_transfer_trend() from public, anon;
grant execute on function public.founder_r3637_monthly_transfer_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3637_capa_status_board()
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
  from public.iepf_capa_actions_r3637 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3637_capa_status_board() from public, anon;
grant execute on function public.founder_r3637_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3637_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.iepf_capa_actions_r3637)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.iepf_capa_actions_r3637 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3637_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3637_root_cause_pareto() to authenticated;

-- 7) IEPF exposure digest (by trend direction)
create or replace function public.founder_r3637_iepf_exposure_digest()
returns table(
  trend_dir text,
  instruments bigint,
  total_unclaimed_rupees numeric,
  total_due_rupees numeric,
  total_transferred_rupees numeric,
  shareholders bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select i.trend_dir,
    count(*)::bigint,
    coalesce(sum(i.unclaimed_amount_rupees),0)::numeric,
    coalesce(sum(i.due_for_transfer_rupees),0)::numeric,
    coalesce(sum(i.transferred_to_iepf_rupees),0)::numeric,
    coalesce(sum(i.shareholders_count),0)::bigint
  from public.iepf_r3637 i
  group by i.trend_dir
  order by coalesce(sum(i.due_for_transfer_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3637_iepf_exposure_digest() from public, anon;
grant execute on function public.founder_r3637_iepf_exposure_digest() to authenticated;

-- 8) High-risk transfer queue (overdue / due-for-transfer / approaching)
create or replace function public.founder_r3637_high_risk_queue()
returns table(
  dividend_year text,
  instrument_ref text,
  period_month date,
  unclaimed_amount_rupees numeric,
  due_for_transfer_rupees numeric,
  shareholders_count int,
  days_to_7yr_deadline int,
  shares_transfer_due int,
  transfer_status text,
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
  select i.dividend_year, i.instrument_ref, i.period_month,
    i.unclaimed_amount_rupees, i.due_for_transfer_rupees, i.shareholders_count,
    i.days_to_7yr_deadline, i.shares_transfer_due, i.transfer_status, i.trend_dir, i.notes
  from public.iepf_r3637 i
  where i.transfer_status in ('overdue','due_for_transfer','approaching_deadline')
  order by case i.transfer_status
             when 'overdue' then 0
             when 'due_for_transfer' then 1
             when 'approaching_deadline' then 2
             else 3
           end,
           i.days_to_7yr_deadline asc;
end;
$$;

revoke execute on function public.founder_r3637_high_risk_queue() from public, anon;
grant execute on function public.founder_r3637_high_risk_queue() to authenticated;
