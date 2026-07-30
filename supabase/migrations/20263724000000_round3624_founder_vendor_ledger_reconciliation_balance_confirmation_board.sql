-- Round 3624: Founder Vendor-Ledger Reconciliation / Balance-Confirmation Board
-- Vendor-ledger recon — our books vs vendor statement per vendor × category × period × difference × disputed × unmatched invoices × confirmation status × recon verdict × trend × CAPA

-- =============================================================================
-- TABLE 1: vendor_ledger_r3624 — per-vendor ledger reconciliation / balance-confirmation
-- =============================================================================
create table if not exists public.vendor_ledger_r3624 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  ledger_code text not null,
  category text not null check (category in (
    'amc_services','spare_parts','projects','diagnostics','consumables','logistics','subcontractor'
  )),
  period_month date not null,
  our_books_balance_rupees numeric(14,2) not null,
  vendor_statement_balance_rupees numeric(14,2),
  difference_rupees numeric(14,2) not null,
  disputed_rupees numeric(14,2),
  unmatched_invoices_count int not null,
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

alter table public.vendor_ledger_r3624 enable row level security;

create index if not exists idx_vendor_ledger_r3624_org on public.vendor_ledger_r3624(organization_id);
create index if not exists idx_vendor_ledger_r3624_period on public.vendor_ledger_r3624(period_month);
create index if not exists idx_vendor_ledger_r3624_recon on public.vendor_ledger_r3624(recon_status);

-- =============================================================================
-- TABLE 2: vendor_ledger_capa_actions_r3624 — CAPA & follow-up actions
-- =============================================================================
create table if not exists public.vendor_ledger_capa_actions_r3624 (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references public.vendor_ledger_r3624(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'balance_mismatch','unmatched_invoice','missing_credit_note','duplicate_payment',
    'tds_mismatch','gst_itc_mismatch','advance_not_adjusted','disputed_debit_note',
    'statement_not_received','fx_rate_difference'
  )),
  root_cause text not null check (root_cause in (
    'timing_difference','invoice_not_booked','payment_not_recorded_by_vendor',
    'tds_deduction_dispute','gst_mismatch','duplicate_entry','pricing_dispute',
    'goods_in_transit','manual_posting_error','vendor_non_response'
  )),
  corrective_action text not null check (corrective_action in (
    'book_missing_invoice','request_credit_note','adjust_advance','reverse_duplicate_payment',
    'share_tds_certificate','reconcile_gst_2b','obtain_vendor_confirmation','raise_debit_note',
    'escalate_to_vendor_finance','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_ledger_capa_actions_r3624 enable row level security;

create index if not exists idx_vendor_ledger_capa_r3624_ledger on public.vendor_ledger_capa_actions_r3624(ledger_id);
create index if not exists idx_vendor_ledger_capa_r3624_status on public.vendor_ledger_capa_actions_r3624(capa_status);

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

  -- 15 vendor-ledger rows
  insert into public.vendor_ledger_r3624 (
    organization_id, vendor_name, ledger_code, category, period_month,
    our_books_balance_rupees, vendor_statement_balance_rupees, difference_rupees, disputed_rupees,
    unmatched_invoices_count, last_confirmation_date, confirmation_status, recon_status, trend_dir, notes
  )
  select v_org_id, q.vname, q.lcode, q.cat, q.pm::date,
    q.ourbal, q.vendbal, q.diff, q.disp,
    q.unm, q.lcd::date, q.cfs, q.rcs, q.trd, q.nt
  from (values
    ('Siemens Healthineers India','VLR-SIE-01','spare_parts','2026-06-30',
     4250000.00,4250000.00,0.00,0.00,0,'2026-07-05','confirmed','reconciled','stable','CT tube spares ledger fully matched with vendor SOA'),
    ('GE Healthcare India','VLR-GEH-02','amc_services','2026-06-30',
     3820000.00,3795000.00,25000.00,0.00,1,'2026-07-04','partial','minor_diff','improving','One AMC invoice timing difference; credit note awaited'),
    ('Philips India','VLR-PHI-03','projects','2026-06-30',
     9650000.00,9210000.00,440000.00,300000.00,4,'2026-06-28','disputed','material_diff','worsening','Cath-lab project retention and disputed debit notes'),
    ('Wipro GE Medical','VLR-WGE-04','spare_parts','2026-06-30',
     1560000.00,1585000.00,-25000.00,0.00,2,'2026-07-02','partial','minor_diff','stable','Two GRNs not yet booked at vendor end'),
    ('Trivitron Healthcare','VLR-TRV-05','diagnostics','2026-06-30',
     2280000.00,2280000.00,0.00,0.00,0,'2026-07-06','confirmed','reconciled','improving','Diagnostics reagent ledger tied out to statement'),
    ('Skanray Technologies','VLR-SKN-06','spare_parts','2026-05-31',
     780000.00,940000.00,-160000.00,160000.00,3,'2026-06-20','disputed','material_diff','worsening','Pricing dispute on ventilator spare parts'),
    ('BPL Medical Technologies','VLR-BPL-07','amc_services','2026-06-30',
     1120000.00,1108000.00,12000.00,0.00,1,'2026-07-03','partial','minor_diff','stable','TDS mismatch on one service invoice'),
    ('Agappe Diagnostics','VLR-AGP-08','consumables','2026-06-30',
     640000.00,640000.00,0.00,0.00,0,'2026-07-05','confirmed','reconciled','stable','Consumables statement of account matched'),
    ('Mindray India','VLR-MND-09','projects','2026-06-30',
     7420000.00,7420000.00,0.00,0.00,0,'2026-07-01','confirmed','reconciled','improving','Monitor project ledger reconciled post go-live'),
    ('Allengers Medical','VLR-ALG-10','spare_parts','2026-04-30',
     1980000.00,null,0.00,0.00,5,null,'no_response','unreconciled','worsening','No statement received for three quarters despite reminders'),
    ('Blue Star Engineering','VLR-BLS-11','projects','2026-06-30',
     5340000.00,5290000.00,50000.00,0.00,2,'2026-06-30','partial','minor_diff','improving','Cold-chain project retention timing difference'),
    ('Voltas Ltd','VLR-VLT-12','logistics','2026-06-30',
     430000.00,470000.00,-40000.00,40000.00,2,'2026-06-25','disputed','disputed','worsening','Freight debit note under dispute with vendor'),
    ('Poly Medicure','VLR-PLM-13','consumables','2026-06-30',
     890000.00,902000.00,-12000.00,0.00,1,'2026-07-04','partial','minor_diff','stable','GST 2B mismatch on a single invoice'),
    ('Erba Mannheim India','VLR-ERB-14','diagnostics','2026-03-31',
     1340000.00,1690000.00,-350000.00,200000.00,6,'2026-05-15','disputed','unreconciled','worsening','Long-pending diagnostics dispute; escalated to vendor finance'),
    ('Sushrut Surgicals','VLR-SSH-15','subcontractor','2026-06-30',
     560000.00,548000.00,12000.00,0.00,1,'2026-07-02','pending','minor_diff','stable','Subcontractor labour billing timing difference')
  ) as q(vname, lcode, cat, pm, ourbal, vendbal, diff, disp, unm, lcd, cfs, rcs, trd, nt);

  -- CAPA seed — attach to specific ledgers by ledger_code
  insert into public.vendor_ledger_capa_actions_r3624 (
    ledger_id, finding_category, root_cause, corrective_action, capa_status,
    recovery_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.cst,
    q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('VLR-PHI-03','balance_mismatch','pricing_dispute','raise_debit_note','escalated',
     300000.00,'Ananya Gupta','2026-08-10',null,'Debit note raised for disputed cath-lab retention; vendor finance escalation'),
    ('VLR-SKN-06','unmatched_invoice','pricing_dispute','escalate_to_vendor_finance','in_progress',
     160000.00,'Rahul Menon','2026-08-05',null,'Ventilator spare pricing under negotiation; three invoices unmatched'),
    ('VLR-VLT-12','disputed_debit_note','pricing_dispute','request_credit_note','open',
     40000.00,'Sneha Iyer','2026-08-15',null,'Freight debit note contested; credit note requested from Voltas'),
    ('VLR-ERB-14','statement_not_received','vendor_non_response','obtain_vendor_confirmation','escalated',
     200000.00,'Karthik Rao','2026-07-25',null,'Balance confirmation letter re-sent; diagnostics dispute open since Q1'),
    ('VLR-ALG-10','statement_not_received','vendor_non_response','escalate_to_vendor_finance','overdue',
     0.00,'Karthik Rao','2026-06-30',null,'No SOA for three quarters; overdue for founder review'),
    ('VLR-GEH-02','unmatched_invoice','timing_difference','book_missing_invoice','verification_pending',
     25000.00,'Priya Nair','2026-07-20','2026-07-18','AMC invoice booked; awaiting next statement to verify tie-out'),
    ('VLR-BPL-07','tds_mismatch','tds_deduction_dispute','share_tds_certificate','closed',
     12000.00,'Priya Nair','2026-07-15','2026-07-12','Form 16A shared; TDS deduction reconciled with vendor'),
    ('VLR-PLM-13','gst_itc_mismatch','gst_mismatch','reconcile_gst_2b','in_progress',
     12000.00,'Sneha Iyer','2026-07-28',null,'GSTR-2B vs books mismatch on one invoice; ITC follow-up in progress')
  ) as q(lcode, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.vendor_ledger_r3624 e
    on e.organization_id = v_org_id and e.ledger_code = q.lcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reconciliation-status distribution
create or replace function public.founder_r3624_recon_status_rollup()
returns table(recon_status text, vendors bigint, total_difference_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_ledger_r3624)
  select l.recon_status, count(*)::bigint,
         coalesce(sum(l.difference_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vendor_ledger_r3624 l
  group by l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3624_recon_status_rollup() from public, anon;
grant execute on function public.founder_r3624_recon_status_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3624_category_scorecard()
returns table(
  category text,
  vendors bigint,
  reconciled bigint,
  minor_diff bigint,
  material_unrec bigint,
  our_books_rupees numeric,
  vendor_statement_rupees numeric,
  difference_rupees numeric,
  avg_unmatched numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category,
    count(*)::bigint,
    count(*) filter (where l.recon_status = 'reconciled')::bigint,
    count(*) filter (where l.recon_status = 'minor_diff')::bigint,
    count(*) filter (where l.recon_status in ('material_diff','unreconciled','disputed'))::bigint,
    coalesce(sum(l.our_books_balance_rupees),0)::numeric,
    coalesce(sum(l.vendor_statement_balance_rupees),0)::numeric,
    coalesce(sum(l.difference_rupees),0)::numeric,
    round(avg(l.unmatched_invoices_count), 2)
  from public.vendor_ledger_r3624 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3624_category_scorecard() from public, anon;
grant execute on function public.founder_r3624_category_scorecard() to authenticated;

-- 3) Confirmation-status × recon-status matrix
create or replace function public.founder_r3624_confirmation_recon_matrix()
returns table(confirmation_status text, recon_status text, vendors bigint, total_difference_rupees numeric, total_disputed_rupees numeric)
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
  from public.vendor_ledger_r3624 l
  group by l.confirmation_status, l.recon_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3624_confirmation_recon_matrix() from public, anon;
grant execute on function public.founder_r3624_confirmation_recon_matrix() to authenticated;

-- 4) Monthly reconciliation trend
create or replace function public.founder_r3624_monthly_recon_trend()
returns table(period_month date, vendors bigint, reconciled bigint, material_unrec bigint, total_difference_rupees numeric, total_disputed_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, count(*)::bigint,
    count(*) filter (where l.recon_status = 'reconciled')::bigint,
    count(*) filter (where l.recon_status in ('material_diff','unreconciled','disputed'))::bigint,
    coalesce(sum(l.difference_rupees),0)::numeric,
    coalesce(sum(l.disputed_rupees),0)::numeric
  from public.vendor_ledger_r3624 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3624_monthly_recon_trend() from public, anon;
grant execute on function public.founder_r3624_monthly_recon_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3624_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.vendor_ledger_capa_actions_r3624 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3624_capa_status_board() from public, anon;
grant execute on function public.founder_r3624_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3624_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_ledger_capa_actions_r3624)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vendor_ledger_capa_actions_r3624 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3624_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3624_root_cause_pareto() to authenticated;

-- 7) Difference-impact digest (materiality bands)
create or replace function public.founder_r3624_difference_impact_digest()
returns table(impact_band text, vendors bigint, total_difference_rupees numeric, total_disputed_rupees numeric, unmatched_invoices bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.band, count(*)::bigint,
    coalesce(sum(s.difference_rupees),0)::numeric,
    coalesce(sum(s.disputed_rupees),0)::numeric,
    coalesce(sum(s.unmatched_invoices_count),0)::bigint
  from (
    select l.difference_rupees, l.disputed_rupees, l.unmatched_invoices_count,
      case
        when abs(l.difference_rupees) = 0 then 'nil'
        when abs(l.difference_rupees) < 50000 then 'under_50k'
        when abs(l.difference_rupees) < 500000 then '50k_to_5l'
        else 'above_5l'
      end as band
    from public.vendor_ledger_r3624 l
  ) s
  group by s.band
  order by coalesce(sum(abs(s.difference_rupees)),0) desc;
end;
$$;

revoke execute on function public.founder_r3624_difference_impact_digest() from public, anon;
grant execute on function public.founder_r3624_difference_impact_digest() to authenticated;

-- 8) High-risk queue (material_diff / unreconciled / disputed)
create or replace function public.founder_r3624_high_risk_queue()
returns table(
  vendor_name text,
  ledger_code text,
  category text,
  period_month date,
  our_books_balance_rupees numeric,
  vendor_statement_balance_rupees numeric,
  difference_rupees numeric,
  disputed_rupees numeric,
  confirmation_status text,
  recon_status text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.ledger_code, l.category, l.period_month,
    l.our_books_balance_rupees, l.vendor_statement_balance_rupees, l.difference_rupees,
    l.disputed_rupees, l.confirmation_status, l.recon_status, l.notes
  from public.vendor_ledger_r3624 l
  where l.recon_status in ('material_diff','unreconciled','disputed')
     or l.confirmation_status in ('disputed','no_response')
  order by case l.recon_status
             when 'unreconciled' then 0
             when 'material_diff' then 1
             when 'disputed' then 2
             else 3
           end,
           abs(l.difference_rupees) desc;
end;
$$;

revoke execute on function public.founder_r3624_high_risk_queue() from public, anon;
grant execute on function public.founder_r3624_high_risk_queue() to authenticated;
