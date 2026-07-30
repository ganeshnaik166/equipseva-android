-- Round 3634: Founder GST Refund / Inverted-Duty / ITC Realization Board
-- GST refund claim-to-realization — refund category (export IGST, inverted duty, excess cash ledger,
-- ITC accumulation, deemed export) x refund status x claimed/sanctioned/rejected/pending amounts x
-- interest on delay x days pending x monthly trend x CAPA closure

-- =============================================================================
-- TABLE 1: gst_refund_r3634 — per-claim GST refund realization fact table
-- =============================================================================
create table if not exists public.gst_refund_r3634 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  refund_claim_ref text not null,
  refund_type text not null,
  period_month date not null,
  claim_amount_rupees numeric(14,2) not null,
  sanctioned_amount_rupees numeric(14,2) not null,
  rejected_amount_rupees numeric(14,2) not null,
  pending_amount_rupees numeric(14,2) not null,
  interest_on_delay_rupees numeric(14,2) not null,
  days_pending int not null,
  filing_date date not null,
  refund_category text not null check (refund_category in (
    'export_igst','inverted_duty','excess_cash_ledger','itc_accumulation','deemed_export'
  )),
  refund_status text not null check (refund_status in (
    'sanctioned','partially_sanctioned','under_process','deficiency_memo','rejected'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gst_refund_r3634 enable row level security;

create index if not exists idx_gst_refund_r3634_org on public.gst_refund_r3634(organization_id);
create index if not exists idx_gst_refund_r3634_period on public.gst_refund_r3634(period_month);
create index if not exists idx_gst_refund_r3634_status on public.gst_refund_r3634(refund_status);

-- =============================================================================
-- TABLE 2: gst_refund_capa_actions_r3634 — CAPA & recovery actions per claim
-- =============================================================================
create table if not exists public.gst_refund_capa_actions_r3634 (
  id uuid primary key default gen_random_uuid(),
  refund_id uuid not null references public.gst_refund_r3634(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'deficiency_memo_rfd03','invoice_mismatch_gstr1_gstr3b','shipping_bill_egm_mismatch',
    'itc_reversal_dispute','inverted_duty_formula_error','bank_account_validation_failure',
    'documentation_incomplete','officer_query_pending','portal_technical_error','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'refile_rfd01','reply_to_deficiency_memo','reconcile_gstr1_gstr3b','submit_shipping_bill_egm',
    'revalidate_bank_account','upload_supporting_docs','respond_to_officer_query',
    'escalate_to_jurisdictional_officer','file_appeal','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  impact_amount_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.gst_refund_capa_actions_r3634 enable row level security;

create index if not exists idx_gst_refund_capa_r3634_refund on public.gst_refund_capa_actions_r3634(refund_id);
create index if not exists idx_gst_refund_capa_r3634_status on public.gst_refund_capa_actions_r3634(capa_status);

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

  -- 16 refund claim rows
  insert into public.gst_refund_r3634 (
    organization_id, refund_claim_ref, refund_type, period_month,
    claim_amount_rupees, sanctioned_amount_rupees, rejected_amount_rupees, pending_amount_rupees,
    interest_on_delay_rupees, days_pending, filing_date,
    refund_category, refund_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.rtype, q.pmonth::date,
    q.claimamt, q.sancamt, q.rejamt, q.pendamt,
    q.intamt, q.dayspend, q.fdate::date,
    q.rcat, q.rstat, q.tdir, q.nt
  from (values
    ('RFD-2026-0412','Export IGST refund','2026-04-01',
     1850000,1850000,0,0,0,0,'2026-05-05','export_igst','sanctioned','improving','Export IGST fully sanctioned within 30 days'),
    ('RFD-2026-0418','Inverted duty ITC','2026-04-01',
     1240000,980000,60000,200000,0,22,'2026-05-08','inverted_duty','partially_sanctioned','stable','Inverted-duty formula reworked, part sanctioned'),
    ('RFD-2026-0425','Export IGST refund','2026-04-01',
     2100000,0,0,2100000,0,41,'2026-05-12','export_igst','under_process','stable','Awaiting officer verification of shipping bills'),
    ('RFD-2026-0430','ITC accumulation','2026-04-01',
     760000,0,0,760000,0,58,'2026-05-15','itc_accumulation','deficiency_memo','worsening','RFD-03 deficiency memo — GSTR-1 vs 3B mismatch'),
    ('RFD-2026-0505','Excess cash ledger','2026-05-01',
     340000,340000,0,0,0,0,'2026-06-02','excess_cash_ledger','sanctioned','improving','Excess balance in cash ledger refunded'),
    ('RFD-2026-0511','Inverted duty ITC','2026-05-01',
     1580000,0,1580000,0,0,66,'2026-06-04','inverted_duty','rejected','worsening','Rejected — inverted-duty formula disputed by officer'),
    ('RFD-2026-0517','Export IGST refund','2026-05-01',
     2650000,2650000,0,0,18000,47,'2026-06-08','export_igst','sanctioned','improving','Sanctioned with interest on delay beyond 60 days'),
    ('RFD-2026-0523','Deemed export refund','2026-05-01',
     910000,0,0,910000,0,39,'2026-06-11','deemed_export','under_process','stable','Deemed-export supplies to EOU — under process'),
    ('RFD-2026-0529','ITC accumulation','2026-05-01',
     1320000,900000,120000,300000,0,33,'2026-06-14','itc_accumulation','partially_sanctioned','stable','Part ITC sanctioned, balance under query'),
    ('RFD-2026-0604','Export IGST refund','2026-06-01',
     1990000,0,0,1990000,0,29,'2026-07-01','export_igst','deficiency_memo','worsening','Deficiency memo — EGM not matched with shipping bill'),
    ('RFD-2026-0610','Inverted duty ITC','2026-06-01',
     2240000,2240000,0,0,0,0,'2026-07-03','inverted_duty','sanctioned','improving','Inverted-duty refund sanctioned in full'),
    ('RFD-2026-0616','Excess cash ledger','2026-06-01',
     180000,0,0,180000,0,21,'2026-07-06','excess_cash_ledger','under_process','stable','Cash ledger refund pending bank validation'),
    ('RFD-2026-0622','ITC accumulation','2026-06-01',
     1450000,0,1450000,0,0,44,'2026-07-08','itc_accumulation','rejected','worsening','Rejected — ITC on capital goods held ineligible'),
    ('RFD-2026-0628','Deemed export refund','2026-06-01',
     670000,670000,0,0,0,0,'2026-07-10','deemed_export','sanctioned','stable','Deemed-export refund sanctioned'),
    ('RFD-2026-0705','Export IGST refund','2026-07-01',
     3100000,2480000,0,620000,0,12,'2026-07-14','export_igst','partially_sanctioned','improving','Provisional 80% sanctioned, balance under verification'),
    ('RFD-2026-0711','Inverted duty ITC','2026-07-01',
     1120000,0,0,1120000,0,9,'2026-07-16','inverted_duty','under_process','stable','New inverted-duty claim filed, ARN generated')
  ) as q(cref, rtype, pmonth, claimamt, sancamt, rejamt, pendamt, intamt, dayspend, fdate, rcat, rstat, tdir, nt);

  -- CAPA seed — attach to specific claims via refund_claim_ref
  insert into public.gst_refund_capa_actions_r3634 (
    refund_id, root_cause, corrective_action, capa_status,
    impact_amount_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('RFD-2026-0430','invoice_mismatch_gstr1_gstr3b','reconcile_gstr1_gstr3b','in_progress',760000,'Priya Nair (GST Lead)','2026-07-20',null,'Reconciling GSTR-1 vs GSTR-3B outward supplies for the period'),
    ('RFD-2026-0511','inverted_duty_formula_error','file_appeal','escalated',1580000,'Rahul Menon (Indirect Tax)','2026-07-25',null,'Rejection appealed — Rule 89(5) formula interpretation dispute'),
    ('RFD-2026-0604','shipping_bill_egm_mismatch','submit_shipping_bill_egm','open',1990000,'Anita Rao (Exports)','2026-07-22',null,'EGM/shipping bill reconciliation with ICEGATE in progress'),
    ('RFD-2026-0622','itc_reversal_dispute','file_appeal','open',1450000,'Rahul Menon (Indirect Tax)','2026-08-05',null,'Capital-goods ITC eligibility contested via appeal'),
    ('RFD-2026-0418','inverted_duty_formula_error','reply_to_deficiency_memo','verification_pending',200000,'Priya Nair (GST Lead)','2026-07-18',null,'Reworked inverted-duty computation filed, awaiting officer verification'),
    ('RFD-2026-0529','officer_query_pending','respond_to_officer_query','in_progress',300000,'Suresh Iyer (Finance)','2026-07-19',null,'Balance ITC held pending response to jurisdictional officer query'),
    ('RFD-2026-0616','bank_account_validation_failure','revalidate_bank_account','closed',180000,'Anita Rao (Exports)','2026-07-12','2026-07-09','Bank account revalidated on portal — refund credited'),
    ('RFD-2026-0425','documentation_incomplete','upload_supporting_docs','overdue',2100000,'Suresh Iyer (Finance)','2026-06-30',null,'Supporting invoices and BRC/FIRC upload overdue')
  ) as q(cref, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.gst_refund_r3634 e
    on e.organization_id = v_org_id and e.refund_claim_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Refund status distribution
create or replace function public.founder_r3634_refund_status_rollup()
returns table(refund_status text, claims bigint, total_claim_rupees numeric, total_pending_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gst_refund_r3634)
  select l.refund_status, count(*)::bigint,
         coalesce(sum(l.claim_amount_rupees),0)::numeric,
         coalesce(sum(l.pending_amount_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.gst_refund_r3634 l
  group by l.refund_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3634_refund_status_rollup() from public, anon;
grant execute on function public.founder_r3634_refund_status_rollup() to authenticated;

-- 2) Refund category scorecard
create or replace function public.founder_r3634_refund_category_scorecard()
returns table(
  refund_category text,
  claims bigint,
  claimed_rupees numeric,
  sanctioned_rupees numeric,
  rejected_rupees numeric,
  pending_rupees numeric,
  interest_rupees numeric,
  realization_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.refund_category,
    count(*)::bigint,
    coalesce(sum(l.claim_amount_rupees),0)::numeric,
    coalesce(sum(l.sanctioned_amount_rupees),0)::numeric,
    coalesce(sum(l.rejected_amount_rupees),0)::numeric,
    coalesce(sum(l.pending_amount_rupees),0)::numeric,
    coalesce(sum(l.interest_on_delay_rupees),0)::numeric,
    round(100.0 * coalesce(sum(l.sanctioned_amount_rupees),0)::numeric / nullif(sum(l.claim_amount_rupees),0), 1)
  from public.gst_refund_r3634 l
  group by l.refund_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3634_refund_category_scorecard() from public, anon;
grant execute on function public.founder_r3634_refund_category_scorecard() to authenticated;

-- 3) Refund category x refund status matrix
create or replace function public.founder_r3634_category_status_matrix()
returns table(refund_category text, refund_status text, claims bigint, claimed_rupees numeric, pending_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.refund_category, l.refund_status, count(*)::bigint,
    coalesce(sum(l.claim_amount_rupees),0)::numeric,
    coalesce(sum(l.pending_amount_rupees),0)::numeric
  from public.gst_refund_r3634 l
  group by l.refund_category, l.refund_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3634_category_status_matrix() from public, anon;
grant execute on function public.founder_r3634_category_status_matrix() to authenticated;

-- 4) Monthly refund trend
create or replace function public.founder_r3634_monthly_refund_trend()
returns table(
  period_month date,
  claims bigint,
  claimed_rupees numeric,
  sanctioned_rupees numeric,
  rejected_rupees numeric,
  pending_rupees numeric,
  interest_rupees numeric
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
    coalesce(sum(l.claim_amount_rupees),0)::numeric,
    coalesce(sum(l.sanctioned_amount_rupees),0)::numeric,
    coalesce(sum(l.rejected_amount_rupees),0)::numeric,
    coalesce(sum(l.pending_amount_rupees),0)::numeric,
    coalesce(sum(l.interest_on_delay_rupees),0)::numeric
  from public.gst_refund_r3634 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3634_monthly_refund_trend() from public, anon;
grant execute on function public.founder_r3634_monthly_refund_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3634_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.impact_amount_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.gst_refund_capa_actions_r3634 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3634_capa_status_board() from public, anon;
grant execute on function public.founder_r3634_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3634_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.gst_refund_capa_actions_r3634)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_amount_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.gst_refund_capa_actions_r3634 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3634_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3634_root_cause_pareto() to authenticated;

-- 7) Pending-refund digest (by category)
create or replace function public.founder_r3634_pending_refund_digest()
returns table(
  refund_category text,
  open_claims bigint,
  total_pending_rupees numeric,
  total_interest_rupees numeric,
  avg_days_pending numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.refund_category,
    count(*) filter (where l.pending_amount_rupees > 0)::bigint,
    coalesce(sum(l.pending_amount_rupees),0)::numeric,
    coalesce(sum(l.interest_on_delay_rupees),0)::numeric,
    round(avg(l.days_pending) filter (where l.pending_amount_rupees > 0), 1)
  from public.gst_refund_r3634 l
  group by l.refund_category
  order by coalesce(sum(l.pending_amount_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3634_pending_refund_digest() from public, anon;
grant execute on function public.founder_r3634_pending_refund_digest() to authenticated;

-- 8) High-risk queue (deficiency_memo / rejected / worsening)
create or replace function public.founder_r3634_high_risk_queue()
returns table(
  refund_claim_ref text,
  refund_category text,
  refund_status text,
  period_month date,
  claim_amount_rupees numeric,
  pending_amount_rupees numeric,
  days_pending int,
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
  select l.refund_claim_ref, l.refund_category, l.refund_status, l.period_month,
    l.claim_amount_rupees, l.pending_amount_rupees, l.days_pending, l.trend_dir, l.notes
  from public.gst_refund_r3634 l
  where l.refund_status in ('deficiency_memo','rejected')
     or l.trend_dir = 'worsening'
     or l.days_pending >= 45
  order by l.days_pending desc, l.pending_amount_rupees desc;
end;
$$;

revoke execute on function public.founder_r3634_high_risk_queue() from public, anon;
grant execute on function public.founder_r3634_high_risk_queue() to authenticated;
