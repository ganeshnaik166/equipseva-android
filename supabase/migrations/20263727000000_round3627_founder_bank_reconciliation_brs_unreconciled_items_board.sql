-- Round 3627: Founder Bank Reconciliation (BRS) / Unreconciled-Items Board
-- Founder finance — bank account × month × book vs bank balance × difference × uncleared cheques ×
-- deposits in transit × unreconciled-item aging × reconciled % × recon status × trend × CAPA closure

-- =============================================================================
-- TABLE 1: bank_recon_r3627 — per-account monthly bank reconciliation fact table
-- =============================================================================
create table if not exists public.bank_recon_r3627 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  recon_ref text not null,
  bank_account text not null,
  bank_name text not null,
  period_month date not null,
  book_balance_rupees numeric(14,2),
  bank_balance_rupees numeric(14,2),
  difference_rupees numeric(14,2),
  uncleared_cheques_rupees numeric(14,2),
  deposits_in_transit_rupees numeric(14,2),
  unreconciled_items_count int,
  oldest_item_days int,
  reconciled_pct numeric(5,2),
  recon_status text not null check (recon_status in (
    'reconciled','minor_diff','material_diff','unreconciled','stale_items'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bank_recon_r3627 enable row level security;

create index if not exists idx_bank_recon_r3627_org on public.bank_recon_r3627(organization_id);
create index if not exists idx_bank_recon_r3627_period on public.bank_recon_r3627(period_month);
create index if not exists idx_bank_recon_r3627_status on public.bank_recon_r3627(recon_status);

-- =============================================================================
-- TABLE 2: bank_recon_capa_actions_r3627 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.bank_recon_capa_actions_r3627 (
  id uuid primary key default gen_random_uuid(),
  recon_id uuid not null references public.bank_recon_r3627(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'uncleared_cheque_aging','deposit_in_transit_delay','unrecorded_bank_charge','missing_book_entry',
    'duplicate_entry','unidentified_credit','interest_not_booked','material_balance_difference',
    'stale_unreconciled_item','bank_error'
  )),
  root_cause text not null check (root_cause in (
    'cheque_not_presented','clearing_delay','entry_omitted_in_books','timing_difference',
    'data_entry_error','bank_charge_unposted','reconciliation_backlog','system_integration_gap',
    'pending_investigation','bank_side_error'
  )),
  corrective_action text not null check (corrective_action in (
    'follow_up_with_bank','post_missing_entry','reverse_duplicate_entry','write_off_stale_item',
    'book_bank_charges','chase_cheque_clearance','reconcile_and_close','escalate_to_cfo',
    'fix_integration_mapping','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.bank_recon_capa_actions_r3627 enable row level security;

create index if not exists idx_bank_recon_capa_r3627_recon on public.bank_recon_capa_actions_r3627(recon_id);
create index if not exists idx_bank_recon_capa_r3627_status on public.bank_recon_capa_actions_r3627(capa_status);

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

  -- 16 monthly bank reconciliation rows
  insert into public.bank_recon_r3627 (
    organization_id, recon_ref, bank_account, bank_name, period_month,
    book_balance_rupees, bank_balance_rupees, difference_rupees, uncleared_cheques_rupees,
    deposits_in_transit_rupees, unreconciled_items_count, oldest_item_days, reconciled_pct,
    recon_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.acct, q.bank, q.pm::date,
    q.bookbal::numeric, q.bankbal::numeric, q.diff::numeric, q.unclr::numeric,
    q.dit::numeric, q.items::int, q.oldest::int, q.recpct::numeric,
    q.rst, q.trd, q.nt
  from (values
    ('BRS-202607-HDFC-AMC','HDFC-CA-AMC-8842','HDFC Bank','2026-07-01',
     12450000.00,12450000.00,0.00,0.00,0.00,0,0,100.00,'reconciled','stable','AMC services current account fully reconciled for July'),
    ('BRS-202607-ICICI-SPARES','ICICI-CA-SPARES-3310','ICICI Bank','2026-07-01',
     8320500.00,8298000.00,22500.00,22500.00,0.00,2,8,99.10,'minor_diff','improving','Spare-parts account — two uncleared vendor cheques within limit'),
    ('BRS-202607-SBI-PROJECTS','SBI-CA-PROJECTS-7781','State Bank of India','2026-07-01',
     21870000.00,20950000.00,920000.00,480000.00,260000.00,6,41,92.30,'material_diff','worsening','Projects account — large milestone deposit in transit plus uncleared subcontractor cheques'),
    ('BRS-202606-HDFC-AMC','HDFC-CA-AMC-8842','HDFC Bank','2026-06-01',
     11980000.00,11980000.00,0.00,0.00,0.00,0,0,100.00,'reconciled','stable','June AMC reconciliation clean'),
    ('BRS-202606-AXIS-DIAG','AXIS-CA-DIAG-2205','Axis Bank','2026-06-01',
     5640000.00,5602000.00,38000.00,18000.00,20000.00,3,15,98.60,'minor_diff','stable','Diagnostics collections account — minor timing differences'),
    ('BRS-202606-KOTAK-PAYROLL','KOTAK-CA-PAYROLL-9014','Kotak Mahindra Bank','2026-06-01',
     3210000.00,3210000.00,0.00,0.00,0.00,0,0,100.00,'reconciled','improving','Payroll disbursement account reconciled'),
    ('BRS-202606-YES-SPARES','YES-CA-SPARES-4402','Yes Bank','2026-06-01',
     4180000.00,3760000.00,420000.00,120000.00,0.00,9,96,88.40,'stale_items','worsening','Spare-parts account — stale unidentified credits over 90 days pending investigation'),
    ('BRS-202606-SBI-PROJECTS','SBI-CA-PROJECTS-7781','State Bank of India','2026-06-01',
     20110000.00,19230000.00,880000.00,510000.00,210000.00,7,55,91.70,'material_diff','worsening','Projects account carrying forward large uncleared items'),
    ('BRS-202605-HDFC-AMC','HDFC-CA-AMC-8842','HDFC Bank','2026-05-01',
     11540000.00,11529000.00,11000.00,11000.00,0.00,1,6,99.90,'reconciled','stable','May AMC — single small uncleared cheque, immaterial'),
    ('BRS-202605-ICICI-SPARES','ICICI-CA-SPARES-3310','ICICI Bank','2026-05-01',
     7980000.00,7605000.00,375000.00,95000.00,40000.00,8,74,90.20,'unreconciled','worsening','Spare-parts account — multiple unrecorded bank charges and unidentified debits'),
    ('BRS-202605-AXIS-DIAG','AXIS-CA-DIAG-2205','Axis Bank','2026-05-01',
     5210000.00,5210000.00,0.00,0.00,0.00,0,0,100.00,'reconciled','improving','Diagnostics account reconciled after prior cleanup'),
    ('BRS-202605-SBI-PROJECTS','SBI-CA-PROJECTS-7781','State Bank of India','2026-05-01',
     18760000.00,18100000.00,660000.00,380000.00,180000.00,5,48,93.10,'material_diff','stable','Projects account material difference from retention deposits in transit'),
    ('BRS-202604-KOTAK-PAYROLL','KOTAK-CA-PAYROLL-9014','Kotak Mahindra Bank','2026-04-01',
     2980000.00,2974000.00,6000.00,6000.00,0.00,1,4,99.80,'reconciled','stable','April payroll account immaterial uncleared cheque'),
    ('BRS-202604-YES-SPARES','YES-CA-SPARES-4402','Yes Bank','2026-04-01',
     3860000.00,3402000.00,458000.00,88000.00,0.00,11,128,84.90,'stale_items','worsening','Spare-parts account — long-aged stale items, reconciliation backlog'),
    ('BRS-202604-ICICI-SPARES','ICICI-CA-SPARES-3310','ICICI Bank','2026-04-01',
     7420000.00,7180000.00,240000.00,140000.00,60000.00,6,62,92.80,'unreconciled','stable','Spare-parts account unreconciled pending vendor cheque clearance'),
    ('BRS-202603-SBI-PROJECTS','SBI-CA-PROJECTS-7781','State Bank of India','2026-03-01',
     17240000.00,16980000.00,260000.00,160000.00,60000.00,4,33,96.40,'minor_diff','improving','Projects account minor timing difference at Q4 close')
  ) as q(ref, acct, bank, pm, bookbal, bankbal, diff, unclr, dit, items, oldest, recpct, rst, trd, nt);

  -- CAPA seed — attach to specific reconciliations via recon_ref
  insert into public.bank_recon_capa_actions_r3627 (
    recon_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp::numeric, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('BRS-202607-SBI-PROJECTS','material_balance_difference','clearing_delay','chase_cheque_clearance','in_progress',920000.00,'Ravi Menon (Finance Controller)','2026-07-20',null,'Chasing subcontractor cheque clearance and milestone deposit confirmation'),
    ('BRS-202606-YES-SPARES','stale_unreconciled_item','reconciliation_backlog','write_off_stale_item','escalated',420000.00,'Anita Rao (Accounts Manager)','2026-07-15',null,'Stale unidentified credits over 90 days escalated to CFO for write-off approval'),
    ('BRS-202605-ICICI-SPARES','unrecorded_bank_charge','bank_charge_unposted','book_bank_charges','closed',375000.00,'Suresh Iyer (Sr Accountant)','2026-06-05','2026-06-03','Bank charges and unidentified debits booked and account reconciled'),
    ('BRS-202606-SBI-PROJECTS','deposit_in_transit_delay','timing_difference','chase_cheque_clearance','in_progress',880000.00,'Ravi Menon (Finance Controller)','2026-07-18',null,'Retention deposits in transit — awaiting bank credit confirmation'),
    ('BRS-202605-SBI-PROJECTS','deposit_in_transit_delay','timing_difference','reconcile_and_close','verification_pending',660000.00,'Priya Nair (Accountant)','2026-06-25',null,'Deposits cleared next month — verifying closing reconciliation'),
    ('BRS-202604-YES-SPARES','stale_unreconciled_item','pending_investigation','escalate_to_cfo','overdue',458000.00,'Anita Rao (Accounts Manager)','2026-05-30',null,'Long-aged items past target date — investigation still pending, overdue'),
    ('BRS-202604-ICICI-SPARES','unidentified_credit','system_integration_gap','fix_integration_mapping','open',240000.00,'Karthik Subramanian (IT-Finance)','2026-07-25',null,'ERP-bank feed mapping gap creating unidentified credits — fix scheduled'),
    ('BRS-202607-ICICI-SPARES','uncleared_cheque_aging','cheque_not_presented','follow_up_with_bank','open',22500.00,'Suresh Iyer (Sr Accountant)','2026-07-22',null,'Two vendor cheques not yet presented — following up with vendors')
  ) as q(ref, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.bank_recon_r3627 e
    on e.organization_id = v_org_id and e.recon_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reconciliation status distribution
create or replace function public.founder_r3627_recon_status_rollup()
returns table(recon_status text, recons bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bank_recon_r3627)
  select l.recon_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.bank_recon_r3627 l
  group by l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3627_recon_status_rollup() from public, anon;
grant execute on function public.founder_r3627_recon_status_rollup() to authenticated;

-- 2) Bank-level reconciliation scorecard
create or replace function public.founder_r3627_bank_scorecard()
returns table(
  bank_name text,
  total_recons bigint,
  reconciled bigint,
  minor_diff bigint,
  material_diff bigint,
  unreconciled bigint,
  stale bigint,
  total_difference_rupees numeric,
  avg_reconciled_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bank_name,
    count(*)::bigint,
    count(*) filter (where l.recon_status = 'reconciled')::bigint,
    count(*) filter (where l.recon_status = 'minor_diff')::bigint,
    count(*) filter (where l.recon_status = 'material_diff')::bigint,
    count(*) filter (where l.recon_status = 'unreconciled')::bigint,
    count(*) filter (where l.recon_status = 'stale_items')::bigint,
    coalesce(sum(l.difference_rupees),0)::numeric,
    round(avg(l.reconciled_pct), 1)
  from public.bank_recon_r3627 l
  group by l.bank_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3627_bank_scorecard() from public, anon;
grant execute on function public.founder_r3627_bank_scorecard() to authenticated;

-- 3) Bank × reconciliation-status matrix
create or replace function public.founder_r3627_bank_status_matrix()
returns table(bank_name text, recon_status text, recons bigint, total_difference_rupees numeric, avg_oldest_item_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bank_name, l.recon_status, count(*)::bigint,
    coalesce(sum(l.difference_rupees),0)::numeric,
    round(avg(l.oldest_item_days), 1)
  from public.bank_recon_r3627 l
  group by l.bank_name, l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3627_bank_status_matrix() from public, anon;
grant execute on function public.founder_r3627_bank_status_matrix() to authenticated;

-- 4) Monthly reconciliation trend
create or replace function public.founder_r3627_monthly_recon_trend()
returns table(
  period_month date,
  recons bigint,
  reconciled bigint,
  material_diff bigint,
  unreconciled bigint,
  total_unreconciled_items bigint,
  total_difference_rupees numeric
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
    count(*) filter (where l.recon_status = 'reconciled')::bigint,
    count(*) filter (where l.recon_status = 'material_diff')::bigint,
    count(*) filter (where l.recon_status = 'unreconciled')::bigint,
    coalesce(sum(l.unreconciled_items_count),0)::bigint,
    coalesce(sum(l.difference_rupees),0)::numeric
  from public.bank_recon_r3627 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3627_monthly_recon_trend() from public, anon;
grant execute on function public.founder_r3627_monthly_recon_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3627_capa_status_board()
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
  from public.bank_recon_capa_actions_r3627 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3627_capa_status_board() from public, anon;
grant execute on function public.founder_r3627_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3627_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.bank_recon_capa_actions_r3627)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.bank_recon_capa_actions_r3627 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3627_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3627_root_cause_pareto() to authenticated;

-- 7) Unreconciled-impact digest (by finding category)
create or replace function public.founder_r3627_unreconciled_impact_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric
  from public.bank_recon_capa_actions_r3627 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3627_unreconciled_impact_digest() from public, anon;
grant execute on function public.founder_r3627_unreconciled_impact_digest() to authenticated;

-- 8) High-risk queue (material_diff / stale_items / unreconciled)
create or replace function public.founder_r3627_high_risk_queue()
returns table(
  bank_name text,
  bank_account text,
  recon_ref text,
  period_month date,
  recon_status text,
  difference_rupees numeric,
  unreconciled_items_count int,
  oldest_item_days int,
  reconciled_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bank_name, l.bank_account, l.recon_ref, l.period_month,
    l.recon_status, l.difference_rupees, l.unreconciled_items_count,
    l.oldest_item_days, l.reconciled_pct, l.notes
  from public.bank_recon_r3627 l
  where l.recon_status in ('material_diff','stale_items','unreconciled')
     or l.oldest_item_days >= 30
     or l.reconciled_pct < 95
  order by l.period_month desc, l.bank_name;
end;
$$;

revoke execute on function public.founder_r3627_high_risk_queue() from public, anon;
grant execute on function public.founder_r3627_high_risk_queue() to authenticated;
