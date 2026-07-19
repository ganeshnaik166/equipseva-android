-- Round 3373: Founder Inter-Company / Inter-Branch Transfer & Fund-Settlement Reconciliation Board
-- Inter-branch transfer log — from_branch × to_branch × transfer type × transfer value × GST compliance × goods-received × invoice-match × settlement status × reconciliation gap × aging × mismatch reason × recon verdict × CAPA

-- =============================================================================
-- TABLE 1: intercompany_transfer_recon_r3373 — per transfer / settlement record
-- =============================================================================
create table if not exists public.intercompany_transfer_recon_r3373 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  from_branch text not null check (from_branch in (
    'chennai_hub','gurgaon_hub','bengaluru_hub','hyderabad_hub','head_office'
  )),
  to_branch text not null check (to_branch in (
    'chennai_hub','gurgaon_hub','bengaluru_hub','hyderabad_hub','head_office'
  )),
  transfer_type text not null check (transfer_type in (
    'stock_transfer','spare_parts','tool_transfer','fund_transfer','expense_allocation','intercompany_invoice'
  )),
  reference_no text not null,
  transfer_date date not null,
  transfer_value_rupees numeric(14,2) not null,
  gst_stock_transfer_compliant boolean not null default true,
  goods_received_confirmed boolean not null default false,
  invoice_matched boolean not null default false,
  settlement_status text not null check (settlement_status in (
    'settled','in_transit','mismatch','pending_confirmation','disputed'
  )),
  reconciliation_gap_rupees numeric(14,2) not null default 0,
  aging_days int not null default 0,
  mismatch_reason text not null check (mismatch_reason in (
    'no_gap','goods_not_received','value_mismatch','gst_doc_missing','settlement_pending','duplicate'
  )),
  recon_verdict text not null check (recon_verdict in (
    'reconciled','confirm_receipt','resolve_mismatch','settle_now','escalate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.intercompany_transfer_recon_r3373 enable row level security;

create index if not exists idx_ic_transfer_recon_r3373_org on public.intercompany_transfer_recon_r3373(organization_id);
create index if not exists idx_ic_transfer_recon_r3373_date on public.intercompany_transfer_recon_r3373(transfer_date);
create index if not exists idx_ic_transfer_recon_r3373_verdict on public.intercompany_transfer_recon_r3373(recon_verdict);

-- =============================================================================
-- TABLE 2: intercompany_transfer_recon_capa_actions_r3373 — reconciliation / settlement actions
-- =============================================================================
create table if not exists public.intercompany_transfer_recon_capa_actions_r3373 (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.intercompany_transfer_recon_r3373(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'goods_receipt_pending','value_mismatch','gst_documentation_gap','settlement_overdue',
    'duplicate_entry','invoice_mismatch','aging_breach'
  )),
  root_cause text not null check (root_cause in (
    'grn_not_posted','price_master_mismatch','gst_invoice_missing','fund_transfer_delayed',
    'duplicate_reference','system_sync_error','manual_entry_error','pending_investigation','approval_backlog'
  )),
  corrective_action text not null check (corrective_action in (
    'post_grn','correct_price_master','issue_gst_invoice','release_fund_settlement','reverse_duplicate',
    'reconcile_ledger','escalate_to_finance_head','write_off_provision','retrain_branch_accountant','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'none','internal_only','cash_flow_delay','write_off_risk','tax_gst_exposure','audit_finding','provision_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.intercompany_transfer_recon_capa_actions_r3373 enable row level security;

create index if not exists idx_ic_transfer_capa_r3373_transfer on public.intercompany_transfer_recon_capa_actions_r3373(transfer_id);
create index if not exists idx_ic_transfer_capa_r3373_status on public.intercompany_transfer_recon_capa_actions_r3373(capa_status);

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

  -- 14 transfer / settlement rows
  insert into public.intercompany_transfer_recon_r3373 (
    organization_id, from_branch, to_branch, transfer_type, reference_no, transfer_date,
    transfer_value_rupees, gst_stock_transfer_compliant, goods_received_confirmed, invoice_matched,
    settlement_status, reconciliation_gap_rupees, aging_days, mismatch_reason, recon_verdict, notes
  )
  select v_org_id, q.fb, q.tb, q.tt, q.ref, q.td::date,
    q.tv, q.gst, q.grc, q.im,
    q.ss, q.gap, q.age::int, q.mr, q.rv, q.nt
  from (values
    ('chennai_hub','bengaluru_hub','stock_transfer','ICT-CHN-1001','2026-07-02',
     285000.00,true,true,true,'settled',0.00,3,'no_gap','reconciled','Ventilator stock to Bengaluru hub — GRN posted, invoice matched, fully reconciled'),
    ('gurgaon_hub','head_office','intercompany_invoice','ICV-GGN-2007','2026-07-01',
     540000.00,true,true,false,'mismatch',18500.00,12,'value_mismatch','resolve_mismatch','Inter-company invoice 18.5k above PO — price master mismatch flagged'),
    ('hyderabad_hub','chennai_hub','spare_parts','ICT-HYD-3012','2026-06-30',
     96000.00,true,false,true,'in_transit',0.00,6,'goods_not_received','confirm_receipt','Spare parts dispatched, GRN pending at Chennai — awaiting receipt confirmation'),
    ('head_office','gurgaon_hub','fund_transfer','FND-HO-4005','2026-06-29',
     1200000.00,true,true,true,'settled',0.00,2,'no_gap','reconciled','Working-capital fund settlement to Gurgaon — credited and cleared'),
    ('bengaluru_hub','hyderabad_hub','tool_transfer','ICT-BLR-5008','2026-06-28',
     74000.00,false,true,true,'mismatch',0.00,9,'gst_doc_missing','resolve_mismatch','Calibration tools moved without e-way GST doc — compliance gap open'),
    ('chennai_hub','head_office','expense_allocation','EXP-CHN-6003','2026-06-27',
     210000.00,true,true,false,'pending_confirmation',5200.00,8,'value_mismatch','resolve_mismatch','Shared marketing expense allocation disputed by 5.2k — under review'),
    ('gurgaon_hub','bengaluru_hub','stock_transfer','ICT-GGN-1044','2026-06-27',
     430000.00,true,true,true,'settled',0.00,4,'no_gap','reconciled','Dialysis consumables transfer — reconciled clean'),
    ('hyderabad_hub','head_office','intercompany_invoice','ICV-HYD-2019','2026-06-26',
     875000.00,true,true,false,'disputed',47000.00,21,'value_mismatch','escalate','Inter-co invoice 47k gap aging 21 days — escalated to finance head'),
    ('head_office','chennai_hub','fund_transfer','FND-HO-4011','2026-06-26',
     650000.00,true,true,true,'in_transit',0.00,3,'settlement_pending','settle_now','Fund transfer initiated, not yet credited at Chennai — settle now'),
    ('bengaluru_hub','gurgaon_hub','spare_parts','ICT-BLR-5021','2026-06-25',
     118000.00,true,false,true,'in_transit',0.00,7,'goods_not_received','confirm_receipt','Endoscopy spares in transit — GRN awaited at Gurgaon stores'),
    ('chennai_hub','hyderabad_hub','stock_transfer','ICT-CHN-1050','2026-06-24',
     320000.00,true,true,false,'mismatch',9800.00,14,'duplicate','resolve_mismatch','Duplicate reference detected — 9.8k double-booked, reversal needed'),
    ('gurgaon_hub','head_office','expense_allocation','EXP-GGN-6014','2026-06-23',
     165000.00,true,true,true,'settled',0.00,2,'no_gap','reconciled','Regional overhead allocation reconciled and closed'),
    ('hyderabad_hub','bengaluru_hub','tool_transfer','ICT-HYD-5033','2026-06-22',
     58000.00,false,true,false,'disputed',12000.00,18,'gst_doc_missing','escalate','Tool transfer without GST invoice, 12k value dispute — escalated'),
    ('head_office','hyderabad_hub','fund_transfer','FND-HO-4020','2026-06-21',
     980000.00,true,true,true,'settled',0.00,1,'no_gap','reconciled','Quarterly settlement to Hyderabad hub — cleared same day')
  ) as q(fb, tb, tt, ref, td, tv, gst, grc, im, ss, gap, age, mr, rv, nt);

  -- CAPA seed — attach to specific transfers via reference_no
  insert into public.intercompany_transfer_recon_capa_actions_r3373 (
    transfer_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('ICV-GGN-2007','value_mismatch','price_master_mismatch','correct_price_master','in_progress','audit_finding','2026-07-08',null,18500.00,'Price master correction raised — awaiting revised inter-co invoice'),
    ('ICT-HYD-3012','goods_receipt_pending','grn_not_posted','post_grn','open','cash_flow_delay','2026-07-05',null,0.00,'GRN not posted at Chennai — follow up with stores team'),
    ('ICT-BLR-5008','gst_documentation_gap','gst_invoice_missing','issue_gst_invoice','escalated','tax_gst_exposure','2026-07-04',null,8500.00,'E-way bill / GST invoice missing on tool transfer — tax exposure'),
    ('ICV-HYD-2019','value_mismatch','price_master_mismatch','escalate_to_finance_head','escalated','audit_finding','2026-07-10',null,47000.00,'47k inter-co invoice gap aging 21d — escalated to finance head'),
    ('ICT-CHN-1050','duplicate_entry','duplicate_reference','reverse_duplicate','verification_pending','provision_required','2026-07-03',null,9800.00,'Duplicate reference reversed — verify ledger at both branches'),
    ('ICT-HYD-5033','gst_documentation_gap','gst_invoice_missing','issue_gst_invoice','overdue','tax_gst_exposure','2026-06-30',null,12000.00,'GST invoice overdue on tool transfer — past target closure date'),
    ('EXP-CHN-6003','value_mismatch','manual_entry_error','reconcile_ledger','closed','internal_only','2026-07-02','2026-07-01',5200.00,'Expense allocation corrected and ledger reconciled — closed')
  ) as q(ref, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.intercompany_transfer_recon_r3373 e
    on e.organization_id = v_org_id and e.reference_no = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reconciliation verdict distribution
create or replace function public.founder_r3373_recon_verdict_rollup()
returns table(recon_verdict text, transfers bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.intercompany_transfer_recon_r3373)
  select l.recon_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.intercompany_transfer_recon_r3373 l
  group by l.recon_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3373_recon_verdict_rollup() from public, anon;
grant execute on function public.founder_r3373_recon_verdict_rollup() to authenticated;

-- 2) Branch-level reconciliation scorecard
create or replace function public.founder_r3373_branch_scorecard()
returns table(
  from_branch text,
  total_transfers bigint,
  reconciled bigint,
  mismatch bigint,
  disputed bigint,
  gst_noncompliant bigint,
  goods_pending bigint,
  total_gap_rupees numeric,
  reconciled_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.from_branch,
    count(*)::bigint,
    count(*) filter (where l.recon_verdict = 'reconciled')::bigint,
    count(*) filter (where l.settlement_status = 'mismatch')::bigint,
    count(*) filter (where l.settlement_status = 'disputed')::bigint,
    count(*) filter (where l.gst_stock_transfer_compliant = false)::bigint,
    count(*) filter (where l.goods_received_confirmed = false)::bigint,
    coalesce(sum(l.reconciliation_gap_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.recon_verdict = 'reconciled')::numeric / nullif(count(*),0), 1)
  from public.intercompany_transfer_recon_r3373 l
  group by l.from_branch
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3373_branch_scorecard() from public, anon;
grant execute on function public.founder_r3373_branch_scorecard() to authenticated;

-- 3) From-branch × to-branch flow matrix
create or replace function public.founder_r3373_branch_flow_matrix()
returns table(from_branch text, to_branch text, transfers bigint, reconciled bigint, avg_value_rupees numeric, total_gap_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.from_branch, l.to_branch, count(*)::bigint,
    count(*) filter (where l.recon_verdict = 'reconciled')::bigint,
    round(avg(l.transfer_value_rupees), 0),
    coalesce(sum(l.reconciliation_gap_rupees),0)::numeric
  from public.intercompany_transfer_recon_r3373 l
  group by l.from_branch, l.to_branch
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3373_branch_flow_matrix() from public, anon;
grant execute on function public.founder_r3373_branch_flow_matrix() to authenticated;

-- 4) Daily transfer trend
create or replace function public.founder_r3373_daily_transfer_trend()
returns table(transfer_date date, transfers bigint, reconciled bigint, mismatch bigint, total_value_rupees numeric, total_gap_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.transfer_date,
    count(*)::bigint,
    count(*) filter (where l.recon_verdict = 'reconciled')::bigint,
    count(*) filter (where l.settlement_status in ('mismatch','disputed'))::bigint,
    coalesce(sum(l.transfer_value_rupees),0)::numeric,
    coalesce(sum(l.reconciliation_gap_rupees),0)::numeric
  from public.intercompany_transfer_recon_r3373 l
  group by l.transfer_date
  order by l.transfer_date desc;
end;
$$;

revoke execute on function public.founder_r3373_daily_transfer_trend() from public, anon;
grant execute on function public.founder_r3373_daily_transfer_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3373_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.intercompany_transfer_recon_capa_actions_r3373 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3373_capa_status_board() from public, anon;
grant execute on function public.founder_r3373_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3373_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.intercompany_transfer_recon_capa_actions_r3373)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.intercompany_transfer_recon_capa_actions_r3373 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3373_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3373_root_cause_pareto() to authenticated;

-- 7) Financial-impact digest
create or replace function public.founder_r3373_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.intercompany_transfer_recon_capa_actions_r3373 c
  group by c.financial_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3373_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3373_financial_impact_digest() to authenticated;

-- 8) High-risk reconciliation queue (top individual concerns)
create or replace function public.founder_r3373_high_risk_queue()
returns table(
  from_branch text,
  to_branch text,
  transfer_type text,
  reference_no text,
  transfer_date date,
  settlement_status text,
  recon_verdict text,
  reconciliation_gap_rupees numeric,
  aging_days int,
  mismatch_reason text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.from_branch, l.to_branch, l.transfer_type, l.reference_no, l.transfer_date,
    l.settlement_status, l.recon_verdict, l.reconciliation_gap_rupees, l.aging_days,
    l.mismatch_reason, l.notes
  from public.intercompany_transfer_recon_r3373 l
  where l.recon_verdict in ('confirm_receipt','resolve_mismatch','settle_now','escalate')
     or l.settlement_status in ('mismatch','disputed','pending_confirmation')
     or l.gst_stock_transfer_compliant = false
     or l.goods_received_confirmed = false
     or l.reconciliation_gap_rupees > 0
  order by l.aging_days desc, l.reconciliation_gap_rupees desc;
end;
$$;

revoke execute on function public.founder_r3373_high_risk_queue() from public, anon;
grant execute on function public.founder_r3373_high_risk_queue() to authenticated;
