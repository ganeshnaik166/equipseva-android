-- Round 3630: Founder Suspense / Clearing-Account Unreconciled-Items Board
-- Finance ops — suspense & clearing-account aging + clearing discipline per account:
-- account type × clearing status × balances × items count × oldest-item aging × cleared-within-month %
-- × unexplained exposure × trend direction × CAPA closure.

-- =============================================================================
-- TABLE 1: suspense_acct_r3630 — per-account, per-month clearing/suspense position
-- =============================================================================
create table if not exists public.suspense_acct_r3630 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  account_code text not null,
  account_name text not null,
  account_type text not null check (account_type in (
    'bank_suspense','payment_gateway_clearing','gst_input_clearing','inter_company_clearing',
    'payroll_clearing','grn_inventory_clearing','customer_advance_clearing','vendor_advance_clearing'
  )),
  period_month date not null,
  opening_balance_rupees numeric(14,2) not null,
  debits_rupees numeric(14,2) not null,
  credits_rupees numeric(14,2) not null,
  closing_balance_rupees numeric(14,2) not null,
  items_count int not null,
  oldest_item_days int not null,
  cleared_within_month_pct numeric(5,2) not null,
  unexplained_rupees numeric(14,2) not null,
  clearing_status text not null check (clearing_status in (
    'cleared','clearing','aged','stale','unexplained'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.suspense_acct_r3630 enable row level security;

create index if not exists idx_suspense_acct_r3630_org on public.suspense_acct_r3630(organization_id);
create index if not exists idx_suspense_acct_r3630_month on public.suspense_acct_r3630(period_month);
create index if not exists idx_suspense_acct_r3630_status on public.suspense_acct_r3630(clearing_status);

-- =============================================================================
-- TABLE 2: suspense_acct_capa_actions_r3630 — CAPA & clearing-discipline actions
-- =============================================================================
create table if not exists public.suspense_acct_capa_actions_r3630 (
  id uuid primary key default gen_random_uuid(),
  suspense_id uuid not null references public.suspense_acct_r3630(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'unmatched_bank_credit','unmatched_bank_debit','gateway_settlement_gap','gst_credit_mismatch',
    'intercompany_imbalance','payroll_variance','grn_invoice_gap','advance_unadjusted',
    'duplicate_entry','fx_revaluation_gap'
  )),
  root_cause text not null check (root_cause in (
    'timing_difference','missing_documentation','system_interface_error','manual_posting_error',
    'vendor_not_invoiced','customer_not_allocated','bank_charges_unbooked','gst_portal_mismatch',
    'pending_investigation','fx_rate_difference'
  )),
  corrective_action text not null check (corrective_action in (
    'match_and_clear','obtain_documentation','fix_interface_mapping','reverse_and_repost',
    'book_pending_invoice','allocate_to_customer','book_bank_charges','reconcile_gst_portal',
    'write_off_immaterial','escalate_to_controller','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  materiality text not null check (materiality in (
    'immaterial','minor','material','significant','critical'
  )),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.suspense_acct_capa_actions_r3630 enable row level security;

create index if not exists idx_suspense_acct_capa_r3630_link on public.suspense_acct_capa_actions_r3630(suspense_id);
create index if not exists idx_suspense_acct_capa_r3630_status on public.suspense_acct_capa_actions_r3630(capa_status);

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

  -- 16 account-month rows
  insert into public.suspense_acct_r3630 (
    organization_id, account_code, account_name, account_type, period_month,
    opening_balance_rupees, debits_rupees, credits_rupees, closing_balance_rupees,
    items_count, oldest_item_days, cleared_within_month_pct, unexplained_rupees,
    clearing_status, trend_dir, notes
  )
  select v_org_id, q.acode, q.aname, q.atype, q.pmon::date,
    q.opb::numeric, q.deb::numeric, q.cred::numeric, q.clb::numeric,
    q.itc::int, q.oldd::int, q.cwm::numeric, q.unx::numeric,
    q.cst, q.trd, q.nt
  from (values
    ('SUS-BANK-01','HDFC Bank Suspense - Collections','bank_suspense','2026-07-01',
     1250000,3400000,3100000,1550000,42,55,78.5,320000,'clearing','improving','Collections suspense — most items cleared within 30 days'),
    ('SUS-BANK-02','ICICI Bank Suspense - Disbursements','bank_suspense','2026-07-01',
     880000,2100000,2350000,630000,28,96,61.2,210000,'aged','stable','Several disbursement items aging past 90 days'),
    ('CLR-PG-01','Razorpay Payment Gateway Clearing','payment_gateway_clearing','2026-07-01',
     540000,4200000,4050000,690000,63,18,92.4,45000,'clearing','improving','Gateway settlements largely T+2; small residual'),
    ('CLR-PG-02','PayU Gateway Clearing - Diagnostics','payment_gateway_clearing','2026-07-01',
     210000,1800000,1720000,290000,31,12,95.1,12000,'cleared','stable','Diagnostics gateway near-fully reconciled'),
    ('CLR-GST-01','GST Input Credit Clearing','gst_input_clearing','2026-07-01',
     1950000,980000,640000,2290000,74,148,33.6,1180000,'stale','worsening','GST 2B mismatch — large unexplained input-credit backlog'),
    ('CLR-IC-01','Inter-Company Clearing - Mumbai Branch','inter_company_clearing','2026-07-01',
     720000,1500000,1350000,870000,22,72,68.0,260000,'aged','stable','Branch reconciliation lag on spare-parts transfers'),
    ('CLR-PAY-01','Payroll Clearing Account','payroll_clearing','2026-07-01',
     60000,4800000,4790000,70000,9,8,97.8,5000,'cleared','improving','Payroll clearing near zero after monthly run'),
    ('CLR-GRN-01','GRN / Inventory Clearing - Spare Parts','grn_inventory_clearing','2026-07-01',
     1340000,2600000,2200000,1740000,88,112,54.3,620000,'aged','worsening','GRN-invoice gap on imported spare parts growing'),
    ('CLR-CADV-01','Customer Advance Clearing - Projects','customer_advance_clearing','2026-07-01',
     3200000,1500000,900000,3800000,35,205,22.1,1650000,'stale','worsening','Project advances not adjusted against milestones'),
    ('CLR-VADV-01','Vendor Advance Clearing - AMC','vendor_advance_clearing','2026-07-01',
     410000,700000,780000,330000,18,44,74.6,88000,'clearing','improving','AMC vendor advances clearing steadily'),
    ('SUS-BANK-01B','HDFC Bank Suspense - Collections','bank_suspense','2026-06-01',
     980000,3200000,2930000,1250000,47,61,71.0,410000,'aged','stable','June collections suspense position'),
    ('CLR-GST-01B','GST Input Credit Clearing','gst_input_clearing','2026-06-01',
     1710000,1050000,810000,1950000,69,121,38.4,990000,'stale','worsening','June GST input-credit mismatch'),
    ('CLR-GRN-01B','GRN / Inventory Clearing - Spare Parts','grn_inventory_clearing','2026-06-01',
     1120000,2400000,2180000,1340000,79,98,58.9,540000,'aged','stable','June GRN-invoice clearing'),
    ('CLR-CADV-01B','Customer Advance Clearing - Projects','customer_advance_clearing','2026-06-01',
     2900000,1200000,900000,3200000,33,178,26.0,1420000,'stale','worsening','June project-advance backlog'),
    ('CLR-PG-01B','Razorpay Payment Gateway Clearing','payment_gateway_clearing','2026-05-01',
     480000,3900000,3840000,540000,58,20,90.0,60000,'clearing','stable','May gateway clearing position'),
    ('CLR-UNX-01','Unidentified Receipts Suspense','bank_suspense','2026-07-01',
     150000,620000,300000,470000,14,240,0.0,470000,'unexplained','worsening','Fully unexplained receipts pending identification')
  ) as q(acode, aname, atype, pmon, opb, deb, cred, clb, itc, oldd, cwm, unx, cst, trd, nt);

  -- CAPA seed — attach to specific accounts via account_code
  insert into public.suspense_acct_capa_actions_r3630 (
    suspense_id, finding_category, root_cause, corrective_action,
    capa_status, materiality, owner, target_closure_date, actual_closure_date,
    impact_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.mat, q.ownr, q.tcd::date, q.acd::date,
    q.imp::numeric, q.nt
  from (values
    ('CLR-GST-01','gst_credit_mismatch','gst_portal_mismatch','reconcile_gst_portal','in_progress','significant','Finance Controller','2026-08-15',null,1180000,'GST 2B reconciliation underway with vendor follow-ups'),
    ('CLR-CADV-01','advance_unadjusted','customer_not_allocated','allocate_to_customer','open','critical','Projects Finance','2026-08-31',null,1650000,'Milestone-wise adjustment of project customer advances pending'),
    ('CLR-GRN-01','grn_invoice_gap','vendor_not_invoiced','book_pending_invoice','in_progress','material','Procurement Finance','2026-08-20',null,620000,'GRN-invoice gap on imported spare parts being booked'),
    ('SUS-BANK-02','unmatched_bank_debit','bank_charges_unbooked','book_bank_charges','verification_pending','minor','Treasury','2026-08-10',null,210000,'Disbursement bank charges being booked to clear items'),
    ('CLR-IC-01','intercompany_imbalance','system_interface_error','fix_interface_mapping','escalated','material','IT Finance Systems','2026-08-05',null,260000,'Inter-company interface mapping fix escalated to ERP team'),
    ('CLR-UNX-01','unmatched_bank_credit','pending_investigation','escalate_to_controller','escalated','significant','Finance Controller','2026-08-01',null,470000,'Unidentified receipts escalated for customer identification'),
    ('SUS-BANK-01','unmatched_bank_credit','timing_difference','match_and_clear','closed','immaterial','Treasury','2026-07-20','2026-07-18',320000,'Timing-difference collections matched and cleared'),
    ('CLR-VADV-01','advance_unadjusted','missing_documentation','obtain_documentation','closed','minor','AMC Finance','2026-07-15','2026-07-12',88000,'AMC vendor advance documentation obtained and adjusted')
  ) as q(acode, fc, rc, ca, cst, mat, ownr, tcd, acd, imp, nt)
  join public.suspense_acct_r3630 e
    on e.organization_id = v_org_id and e.account_code = q.acode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Clearing-status distribution
create or replace function public.founder_r3630_clearing_status_rollup()
returns table(clearing_status text, accounts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.suspense_acct_r3630)
  select l.clearing_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.suspense_acct_r3630 l
  group by l.clearing_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3630_clearing_status_rollup() from public, anon;
grant execute on function public.founder_r3630_clearing_status_rollup() to authenticated;

-- 2) Account-type scorecard
create or replace function public.founder_r3630_account_type_scorecard()
returns table(
  account_type text,
  total_accounts bigint,
  cleared bigint,
  clearing bigint,
  aged bigint,
  stale bigint,
  unexplained bigint,
  avg_cleared_pct numeric,
  total_unexplained_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.account_type,
    count(*)::bigint,
    count(*) filter (where l.clearing_status = 'cleared')::bigint,
    count(*) filter (where l.clearing_status = 'clearing')::bigint,
    count(*) filter (where l.clearing_status = 'aged')::bigint,
    count(*) filter (where l.clearing_status = 'stale')::bigint,
    count(*) filter (where l.clearing_status = 'unexplained')::bigint,
    round(avg(l.cleared_within_month_pct), 1),
    coalesce(sum(l.unexplained_rupees),0)::numeric
  from public.suspense_acct_r3630 l
  group by l.account_type
  order by coalesce(sum(l.unexplained_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3630_account_type_scorecard() from public, anon;
grant execute on function public.founder_r3630_account_type_scorecard() to authenticated;

-- 3) Account-type × clearing-status matrix
create or replace function public.founder_r3630_account_type_status_matrix()
returns table(account_type text, clearing_status text, accounts bigint, total_unexplained_rupees numeric, avg_oldest_item_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.account_type, l.clearing_status, count(*)::bigint,
    coalesce(sum(l.unexplained_rupees),0)::numeric,
    round(avg(l.oldest_item_days), 1)
  from public.suspense_acct_r3630 l
  group by l.account_type, l.clearing_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3630_account_type_status_matrix() from public, anon;
grant execute on function public.founder_r3630_account_type_status_matrix() to authenticated;

-- 4) Monthly clearing trend
create or replace function public.founder_r3630_monthly_clearing_trend()
returns table(period_month date, accounts bigint, cleared bigint, aged_or_stale bigint, avg_cleared_pct numeric, total_unexplained_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    count(*) filter (where l.clearing_status in ('cleared','clearing'))::bigint,
    count(*) filter (where l.clearing_status in ('aged','stale','unexplained'))::bigint,
    round(avg(l.cleared_within_month_pct), 1),
    coalesce(sum(l.unexplained_rupees),0)::numeric
  from public.suspense_acct_r3630 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3630_monthly_clearing_trend() from public, anon;
grant execute on function public.founder_r3630_monthly_clearing_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3630_capa_status_board()
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
  from public.suspense_acct_capa_actions_r3630 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3630_capa_status_board() from public, anon;
grant execute on function public.founder_r3630_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3630_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.suspense_acct_capa_actions_r3630)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.suspense_acct_capa_actions_r3630 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3630_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3630_root_cause_pareto() to authenticated;

-- 7) Unexplained-impact digest (by materiality)
create or replace function public.founder_r3630_unexplained_impact_digest()
returns table(materiality text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.materiality, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric
  from public.suspense_acct_capa_actions_r3630 c
  group by c.materiality
  order by coalesce(sum(c.impact_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3630_unexplained_impact_digest() from public, anon;
grant execute on function public.founder_r3630_unexplained_impact_digest() to authenticated;

-- 8) High-risk queue (stale / unexplained / aged clearing accounts)
create or replace function public.founder_r3630_high_risk_queue()
returns table(
  account_code text,
  account_name text,
  account_type text,
  period_month date,
  clearing_status text,
  closing_balance_rupees numeric,
  items_count int,
  oldest_item_days int,
  unexplained_rupees numeric,
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
  select l.account_code, l.account_name, l.account_type, l.period_month,
    l.clearing_status, l.closing_balance_rupees, l.items_count, l.oldest_item_days,
    l.unexplained_rupees, l.trend_dir, l.notes
  from public.suspense_acct_r3630 l
  where l.clearing_status in ('aged','stale','unexplained')
     or l.trend_dir = 'worsening'
     or l.oldest_item_days >= 90
     or l.cleared_within_month_pct < 50
  order by l.unexplained_rupees desc, l.oldest_item_days desc;
end;
$$;

revoke execute on function public.founder_r3630_high_risk_queue() from public, anon;
grant execute on function public.founder_r3630_high_risk_queue() to authenticated;
