-- Round 3631: Founder Customer-Ledger Reconciliation / Debtor-Confirmation Board
-- Founder finance QA — customer ledger reconciliation (our books vs customer statement) × segment ×
-- confirmation status × recon status × difference/disputed rupees × unmatched receipts × trend × CAPA

-- =============================================================================
-- TABLE 1: customer_ledger_r3631 — per-customer ledger reconciliation fact rows
-- =============================================================================
create table if not exists public.customer_ledger_r3631 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  account_code text not null,
  customer_name text not null,
  segment text not null,
  period_month date not null,
  our_books_balance_rupees numeric(14,2),
  customer_statement_balance_rupees numeric(14,2),
  difference_rupees numeric(14,2),
  disputed_rupees numeric(14,2),
  unmatched_receipts_count int,
  last_confirmation_date date,
  confirmation_status text not null check (confirmation_status in (
    'confirmed','pending','partial','disputed','no_response'
  )),
  recon_status text not null check (recon_status in (
    'reconciled','minor_diff','material_diff','unreconciled','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.customer_ledger_r3631 enable row level security;

create index if not exists idx_customer_ledger_r3631_org on public.customer_ledger_r3631(organization_id);
create index if not exists idx_customer_ledger_r3631_month on public.customer_ledger_r3631(period_month);
create index if not exists idx_customer_ledger_r3631_recon on public.customer_ledger_r3631(recon_status);

-- =============================================================================
-- TABLE 2: customer_ledger_capa_actions_r3631 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.customer_ledger_capa_actions_r3631 (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references public.customer_ledger_r3631(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'balance_mismatch','unapplied_receipt','disputed_invoice','missing_confirmation',
    'credit_note_pending','tds_mismatch','duplicate_billing','fx_rate_difference',
    'cutoff_timing_diff','write_off_required'
  )),
  root_cause text not null check (root_cause in (
    'receipt_not_posted','invoice_not_received_by_customer','disputed_deliverable',
    'tds_deducted_not_recorded','credit_note_not_issued','pricing_dispute',
    'duplicate_invoice_raised','cutoff_timing','data_entry_error',
    'customer_unresponsive','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'post_pending_receipt','share_ledger_and_statement','resolve_dispute_with_customer',
    'record_tds_entry','issue_credit_note','reverse_duplicate_invoice','adjust_cutoff_entry',
    'correct_data_entry','escalate_to_collections','write_off_balance','none_required'
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

alter table public.customer_ledger_capa_actions_r3631 enable row level security;

create index if not exists idx_customer_ledger_capa_r3631_ledger on public.customer_ledger_capa_actions_r3631(ledger_id);
create index if not exists idx_customer_ledger_capa_r3631_status on public.customer_ledger_capa_actions_r3631(capa_status);

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

  -- 16 ledger reconciliation rows
  insert into public.customer_ledger_r3631 (
    organization_id, account_code, customer_name, segment, period_month,
    our_books_balance_rupees, customer_statement_balance_rupees, difference_rupees, disputed_rupees,
    unmatched_receipts_count, last_confirmation_date, confirmation_status, recon_status, trend_dir, notes
  )
  select v_org_id, q.acct, q.cust, q.seg, q.pmon::date,
    q.obal, q.cbal, q.diff, q.disp,
    q.unm, q.lcd::date, q.cstat, q.rstat, q.tdir, q.nt
  from (values
    ('DEB-APL-01','Apollo Hospitals Chennai','amc_services','2026-07-01',
     1250000,1250000,0,0,0,'2026-07-05','confirmed','reconciled','stable','AMC ledger fully agreed with signed customer confirmation'),
    ('DEB-FRT-02','Fortis Gurgaon','spare_parts','2026-07-01',
     845000,842500,2500,0,1,'2026-07-04','confirmed','minor_diff','improving','Small cutoff timing diff on last spare-parts invoice, one receipt unapplied'),
    ('DEB-MNP-03','Manipal Bengaluru','projects','2026-07-01',
     3200000,2950000,250000,180000,2,'2026-06-20','partial','material_diff','worsening','Project milestone billing disputed by customer, partial confirmation only'),
    ('DEB-AIM-04','AIIMS Delhi','diagnostics','2026-07-01',
     560000,560000,0,0,0,'2026-07-06','confirmed','reconciled','stable','Diagnostics consumable ledger reconciled and confirmed'),
    ('DEB-CMC-05','CMC Vellore','amc_services','2026-07-01',
     720000,705000,15000,15000,1,null,'disputed','disputed','worsening','AMC price escalation disputed, no confirmation returned'),
    ('DEB-KIM-06','KIMS Hyderabad','equipment_sales','2026-07-01',
     4100000,3600000,500000,0,3,'2026-06-15','pending','unreconciled','worsening','Large equipment-sale receipts not yet posted, confirmation pending'),
    ('DEB-YSH-07','Yashoda Hyderabad','spare_parts','2026-07-01',
     385000,384000,1000,0,0,'2026-07-02','confirmed','minor_diff','stable','Minor rounding diff on spare-parts ledger'),
    ('DEB-KKB-08','Kokilaben Mumbai','consumables','2026-07-01',
     925000,925000,0,0,0,'2026-07-07','confirmed','reconciled','improving','Consumables ledger reconciled, healthy payment trend'),
    ('DEB-NAR-09','Narayana Health Bengaluru','projects','2026-06-01',
     5600000,5200000,400000,250000,4,'2026-06-10','partial','material_diff','worsening','Turnkey project retention and disputed change-orders drive material gap'),
    ('DEB-MAX-10','Max Saket Delhi','amc_services','2026-06-01',
     1120000,1118000,2000,0,0,'2026-06-25','confirmed','minor_diff','stable','AMC ledger near-agreed, small credit-note timing diff'),
    ('DEB-MED-11','Medanta Gurgaon','diagnostics','2026-06-01',
     640000,610000,30000,30000,2,null,'no_response','unreconciled','worsening','No confirmation response for two cycles, diagnostics balance unverified'),
    ('DEB-RBY-12','Ruby Hall Pune','spare_parts','2026-06-01',
     275000,275000,0,0,0,'2026-06-28','confirmed','reconciled','stable','Spare-parts ledger reconciled and confirmed'),
    ('DEB-SGP-13','SGPGI Lucknow','equipment_sales','2026-06-01',
     2350000,2280000,70000,40000,1,'2026-06-12','partial','material_diff','improving','TDS deducted not recorded plus disputed freight on equipment sale'),
    ('DEB-AST-14','Aster Kochi','consumables','2026-06-01',
     410000,409500,500,0,0,'2026-06-30','confirmed','minor_diff','stable','Negligible consumables diff within tolerance'),
    ('DEB-TMH-15','Tata Memorial Mumbai','projects','2026-05-01',
     6800000,6800000,0,0,0,'2026-05-28','confirmed','reconciled','improving','Large project ledger fully reconciled and confirmed on schedule'),
    ('DEB-PGI-16','PGIMER Chandigarh','amc_services','2026-05-01',
     980000,890000,90000,60000,2,null,'disputed','disputed','worsening','AMC scope dispute with government account, confirmation withheld')
  ) as q(acct, cust, seg, pmon, obal, cbal, diff, disp, unm, lcd, cstat, rstat, tdir, nt);

  -- CAPA seed — attach to specific ledgers via account_code
  insert into public.customer_ledger_capa_actions_r3631 (
    ledger_id, finding_category, root_cause, corrective_action,
    capa_status, impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.imp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('DEB-MNP-03','balance_mismatch','disputed_deliverable','resolve_dispute_with_customer','in_progress',180000,'Ravi Menon','2026-07-15',null,'Joint reconciliation call scheduled on disputed project milestones'),
    ('DEB-CMC-05','disputed_invoice','pricing_dispute','resolve_dispute_with_customer','escalated',15000,'Anita Desai','2026-07-10',null,'AMC escalation clause disputed, escalated to commercial head'),
    ('DEB-KIM-06','unapplied_receipt','receipt_not_posted','post_pending_receipt','verification_pending',500000,'Suresh Iyer','2026-07-12',null,'Bank receipts identified, posting under verification against invoices'),
    ('DEB-NAR-09','balance_mismatch','disputed_deliverable','resolve_dispute_with_customer','open',250000,'Ravi Menon','2026-07-20',null,'Retention and change-order dispute to be settled with project PMO'),
    ('DEB-MED-11','missing_confirmation','customer_unresponsive','escalate_to_collections','overdue',30000,'Priya Nair','2026-06-30',null,'Two cycles no response, moved to collections follow-up'),
    ('DEB-SGP-13','tds_mismatch','tds_deducted_not_recorded','record_tds_entry','closed',40000,'Vikram Rao','2026-06-25','2026-06-24','TDS certificate received and booked, ledger agreed'),
    ('DEB-PGI-16','disputed_invoice','pricing_dispute','resolve_dispute_with_customer','in_progress',60000,'Anita Desai','2026-07-18',null,'Government AMC scope note being reconciled with tender terms'),
    ('DEB-FRT-02','unapplied_receipt','cutoff_timing','adjust_cutoff_entry','closed',2500,'Suresh Iyer','2026-07-08','2026-07-06','Cutoff receipt adjusted, spare-parts ledger reconciled')
  ) as q(acct, fc, rc, ca, cst, imp, ownr, tcd, acd, nt)
  join public.customer_ledger_r3631 e
    on e.organization_id = v_org_id and e.account_code = q.acct;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recon-status distribution
create or replace function public.founder_r3631_recon_status_rollup()
returns table(recon_status text, ledgers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.customer_ledger_r3631)
  select l.recon_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.customer_ledger_r3631 l
  group by l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3631_recon_status_rollup() from public, anon;
grant execute on function public.founder_r3631_recon_status_rollup() to authenticated;

-- 2) Segment-level reconciliation scorecard
create or replace function public.founder_r3631_segment_scorecard()
returns table(
  segment text,
  total_ledgers bigint,
  reconciled bigint,
  minor_diff bigint,
  material_diff bigint,
  unreconciled bigint,
  disputed_ledgers bigint,
  total_difference_rupees numeric,
  reconciled_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.segment,
    count(*)::bigint,
    count(*) filter (where l.recon_status = 'reconciled')::bigint,
    count(*) filter (where l.recon_status = 'minor_diff')::bigint,
    count(*) filter (where l.recon_status = 'material_diff')::bigint,
    count(*) filter (where l.recon_status = 'unreconciled')::bigint,
    count(*) filter (where l.recon_status = 'disputed')::bigint,
    coalesce(sum(l.difference_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.recon_status = 'reconciled')::numeric / nullif(count(*),0), 1)
  from public.customer_ledger_r3631 l
  group by l.segment
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3631_segment_scorecard() from public, anon;
grant execute on function public.founder_r3631_segment_scorecard() to authenticated;

-- 3) Confirmation-status × recon-status matrix
create or replace function public.founder_r3631_confirmation_recon_matrix()
returns table(confirmation_status text, recon_status text, ledgers bigint, total_difference_rupees numeric, total_disputed_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.confirmation_status, l.recon_status, count(*)::bigint,
    coalesce(sum(l.difference_rupees),0)::numeric,
    coalesce(sum(l.disputed_rupees),0)::numeric
  from public.customer_ledger_r3631 l
  group by l.confirmation_status, l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3631_confirmation_recon_matrix() from public, anon;
grant execute on function public.founder_r3631_confirmation_recon_matrix() to authenticated;

-- 4) Monthly reconciliation trend
create or replace function public.founder_r3631_monthly_recon_trend()
returns table(period_month date, ledgers bigint, reconciled bigint, material_diff bigint, unreconciled bigint, total_difference_rupees numeric)
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
    coalesce(sum(l.difference_rupees),0)::numeric
  from public.customer_ledger_r3631 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3631_monthly_recon_trend() from public, anon;
grant execute on function public.founder_r3631_monthly_recon_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3631_capa_status_board()
returns table(capa_status text, actions bigint, avg_impact_rupees numeric, overdue_flag bigint)
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
  from public.customer_ledger_capa_actions_r3631 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3631_capa_status_board() from public, anon;
grant execute on function public.founder_r3631_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3631_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.customer_ledger_capa_actions_r3631)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.customer_ledger_capa_actions_r3631 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3631_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3631_root_cause_pareto() to authenticated;

-- 7) Difference-impact digest by segment
create or replace function public.founder_r3631_difference_impact_digest()
returns table(
  segment text,
  ledgers bigint,
  our_books_total_rupees numeric,
  customer_statement_total_rupees numeric,
  net_difference_rupees numeric,
  disputed_total_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.segment, count(*)::bigint,
    coalesce(sum(l.our_books_balance_rupees),0)::numeric,
    coalesce(sum(l.customer_statement_balance_rupees),0)::numeric,
    coalesce(sum(l.difference_rupees),0)::numeric,
    coalesce(sum(l.disputed_rupees),0)::numeric
  from public.customer_ledger_r3631 l
  group by l.segment
  order by coalesce(sum(l.difference_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3631_difference_impact_digest() from public, anon;
grant execute on function public.founder_r3631_difference_impact_digest() to authenticated;

-- 8) High-risk queue (material_diff / unreconciled / disputed)
create or replace function public.founder_r3631_high_risk_queue()
returns table(
  customer_name text,
  account_code text,
  segment text,
  period_month date,
  recon_status text,
  confirmation_status text,
  difference_rupees numeric,
  disputed_rupees numeric,
  unmatched_receipts_count int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name, l.account_code, l.segment, l.period_month,
    l.recon_status, l.confirmation_status, l.difference_rupees, l.disputed_rupees,
    l.unmatched_receipts_count, l.notes
  from public.customer_ledger_r3631 l
  where l.recon_status in ('material_diff','unreconciled','disputed')
     or l.confirmation_status in ('disputed','no_response')
     or l.unmatched_receipts_count > 0
  order by l.difference_rupees desc, l.customer_name;
end;
$$;

revoke execute on function public.founder_r3631_high_risk_queue() from public, anon;
grant execute on function public.founder_r3631_high_risk_queue() to authenticated;
