-- Round 3561: Founder Supplier Payment-Run / Cash-Outflow Calendar Board
-- Scheduled disbursements + liquidity timing — payment batch × supplier category × scheduled date ×
-- payable × discount capture × available cash × coverage ratio × priority × run status × CAPA

-- =============================================================================
-- TABLE 1: payment_run_calendar_r3561 — scheduled supplier payment runs / cash outflow
-- =============================================================================
create table if not exists public.payment_run_calendar_r3561 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  payment_batch text not null,
  supplier_name text not null,
  supplier_category text not null check (supplier_category in (
    'oem_spares','consumables','logistics','it_saas','statutory_dues',
    'contract_labour','utilities','capex_vendor'
  )),
  scheduled_date date not null,
  payable_rupees numeric(14,2) not null,
  discount_capture_rupees numeric(14,2),
  available_cash_rupees numeric(14,2),
  coverage_ratio numeric(6,3),
  payment_priority text not null check (payment_priority in (
    'critical','statutory','trade','discretionary','deferred'
  )),
  run_status text not null check (run_status in (
    'scheduled','released','on_hold','partial','completed','deferred'
  )),
  period_month date not null,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.payment_run_calendar_r3561 enable row level security;

create index if not exists idx_payment_run_calendar_r3561_org on public.payment_run_calendar_r3561(organization_id);
create index if not exists idx_payment_run_calendar_r3561_sched on public.payment_run_calendar_r3561(scheduled_date);
create index if not exists idx_payment_run_calendar_r3561_status on public.payment_run_calendar_r3561(run_status);

-- =============================================================================
-- TABLE 2: payment_run_calendar_capa_actions_r3561 — CAPA & liquidity remediation
-- =============================================================================
create table if not exists public.payment_run_calendar_capa_actions_r3561 (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.payment_run_calendar_r3561(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'coverage_shortfall','discount_window_missed','statutory_deadline_risk','payment_on_hold',
    'vendor_dispute','duplicate_payment_risk','cash_flow_timing_gap','po_invoice_mismatch',
    'forex_exposure','deferred_critical_run'
  )),
  root_cause text not null check (root_cause in (
    'insufficient_liquidity','collections_delay','approval_bottleneck','invoice_data_error',
    'bank_cutoff_missed','forecast_inaccuracy','vendor_terms_change','po_reconciliation_pending',
    'pending_investigation','budget_freeze'
  )),
  corrective_action text not null check (corrective_action in (
    'reprioritize_run','negotiate_extended_terms','accelerate_collections','release_partial_payment',
    'escalate_to_cfo','correct_invoice_data','draw_working_capital_line','reconcile_po',
    'capture_early_pay_discount','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  liquidity_impact text not null check (liquidity_impact in (
    'cash_crunch','discount_forfeited','penalty_risk','statutory_breach','vendor_hold_risk','none'
  )),
  impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.payment_run_calendar_capa_actions_r3561 enable row level security;

create index if not exists idx_payment_run_calendar_capa_r3561_run on public.payment_run_calendar_capa_actions_r3561(run_id);
create index if not exists idx_payment_run_calendar_capa_r3561_status on public.payment_run_calendar_capa_actions_r3561(capa_status);

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

  -- 16 payment-run rows
  insert into public.payment_run_calendar_r3561 (
    organization_id, payment_batch, supplier_name, supplier_category, scheduled_date,
    payable_rupees, discount_capture_rupees, available_cash_rupees, coverage_ratio,
    payment_priority, run_status, period_month, notes
  )
  select v_org_id, q.pb, q.sn, q.sc, q.sd::date,
    q.pay, q.disc, q.cash, q.cov,
    q.pri, q.rst, q.pm::date, q.nt
  from (values
    ('PB-2607-01','Siemens Healthineers India','oem_spares','2026-07-05',
     1850000,37000,2100000,1.135,'trade','completed','2026-07-01','OEM CT spares batch — 2% early-pay discount captured'),
    ('PB-2607-02','GE Healthcare India','oem_spares','2026-07-08',
     2250000,0,1900000,0.844,'critical','on_hold','2026-07-01','MRI coldhead spares held pending cash — coverage below 1.0'),
    ('PB-2607-03','3M India Consumables','consumables','2026-07-06',
     640000,12800,900000,1.406,'trade','released','2026-07-01','Sterilisation consumables — discount window met'),
    ('PB-2607-04','GST TDS Remittance','statutory_dues','2026-07-07',
     480000,0,900000,1.875,'statutory','completed','2026-07-01','Monthly GST + TDS statutory remittance cleared'),
    ('PB-2607-05','Blue Dart Express','logistics','2026-07-09',
     210000,0,850000,4.048,'trade','released','2026-07-01','Field logistics and courier settlement'),
    ('PB-2607-06','AWS India Cloud','it_saas','2026-07-10',
     320000,6400,800000,2.5,'discretionary','scheduled','2026-07-01','Cloud hosting invoice — annual commit discount available'),
    ('PB-2607-07','Randstad Contract Techs','contract_labour','2026-07-11',
     560000,0,760000,1.357,'trade','partial','2026-07-01','Contract engineer payroll — partial release pending timesheet'),
    ('PB-2607-08','EPFO Provident Fund','statutory_dues','2026-07-15',
     290000,0,500000,1.724,'statutory','deferred','2026-07-01','PF challan deferred one cycle — statutory risk flagged'),
    ('PB-2606-09','Philips Healthcare India','oem_spares','2026-06-28',
     1420000,28400,1600000,1.127,'critical','completed','2026-06-01','Cath-lab tube spares — June batch closed'),
    ('PB-2606-10','Tata Power Utilities','utilities','2026-06-26',
     175000,0,1600000,9.143,'discretionary','completed','2026-06-01','Facility electricity dues cleared'),
    ('PB-2606-11','Drager India Consumables','consumables','2026-06-27',
     380000,7600,1400000,3.684,'trade','completed','2026-06-01','Ventilator consumables — discount captured'),
    ('PB-2608-12','Trivitron Capex Vendor','capex_vendor','2026-08-04',
     3100000,0,1200000,0.387,'discretionary','deferred','2026-08-01','Capex tooling deferred — coverage far below 1.0'),
    ('PB-2608-13','Wipro GE Spares','oem_spares','2026-08-06',
     980000,19600,1300000,1.327,'trade','scheduled','2026-08-01','Ultrasound probe spares — August batch scheduled'),
    ('PB-2608-14','GST TDS Remittance','statutory_dues','2026-08-07',
     510000,0,640000,1.255,'statutory','scheduled','2026-08-01','August statutory remittance scheduled'),
    ('PB-2608-15','Delhivery Logistics','logistics','2026-08-09',
     240000,0,640000,2.667,'trade','on_hold','2026-08-01','Logistics settlement held pending PO reconciliation'),
    ('PB-2608-16','Zoho SaaS Suite','it_saas','2026-08-10',
     145000,2900,620000,4.276,'discretionary','scheduled','2026-08-01','SaaS subscription — annual discount available')
  ) as q(pb, sn, sc, sd, pay, disc, cash, cov, pri, rst, pm, nt);

  -- CAPA seed — attach to specific runs via payment_batch business key
  insert into public.payment_run_calendar_capa_actions_r3561 (
    run_id, finding_category, root_cause, corrective_action,
    capa_status, liquidity_impact, impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.liq, q.imp, q.own,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('PB-2607-02','coverage_shortfall','insufficient_liquidity','draw_working_capital_line','in_progress','cash_crunch',2250000,'Treasury Lead','2026-07-09',null,'Critical OEM run held — drawing WC line to cover coverage gap'),
    ('PB-2608-12','cash_flow_timing_gap','insufficient_liquidity','reprioritize_run','open','cash_crunch',3100000,'CFO Office','2026-08-08',null,'Capex deferred; realign disbursement to next liquidity window'),
    ('PB-2607-08','statutory_deadline_risk','approval_bottleneck','escalate_to_cfo','escalated','statutory_breach',290000,'Compliance Head','2026-07-15',null,'PF deferral risks statutory penalty — escalated to CFO'),
    ('PB-2608-15','po_invoice_mismatch','po_reconciliation_pending','reconcile_po','verification_pending','vendor_hold_risk',240000,'AP Analyst','2026-08-11',null,'Logistics invoice vs PO mismatch — reconciling before release'),
    ('PB-2607-07','payment_on_hold','invoice_data_error','correct_invoice_data','in_progress','vendor_hold_risk',560000,'AP Analyst','2026-07-13',null,'Timesheet data error — partial release pending correction'),
    ('PB-2608-16','discount_window_missed','approval_bottleneck','capture_early_pay_discount','open','discount_forfeited',2900,'Treasury Lead','2026-08-09',null,'Approve before early-pay discount window closes'),
    ('PB-2606-11','vendor_dispute','vendor_terms_change','negotiate_extended_terms','closed','none',7600,'Procurement Lead','2026-06-27','2026-06-27','Terms renegotiated — vendor dispute resolved and closed'),
    ('PB-2608-13','forex_exposure','forecast_inaccuracy','accelerate_collections','overdue','penalty_risk',980000,'Treasury Lead','2026-07-20',null,'Collections lag pushing run past target — overdue')
  ) as q(pb, fc, rc, ca, cst, liq, imp, own, tcd, acd, nt)
  join public.payment_run_calendar_r3561 e
    on e.organization_id = v_org_id and e.payment_batch = q.pb;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Run-status distribution
create or replace function public.founder_r3561_run_status_rollup()
returns table(run_status text, runs bigint, total_payable_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.payment_run_calendar_r3561)
  select l.run_status, count(*)::bigint,
         coalesce(sum(l.payable_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.payment_run_calendar_r3561 l
  group by l.run_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3561_run_status_rollup() from public, anon;
grant execute on function public.founder_r3561_run_status_rollup() to authenticated;

-- 2) Supplier-category scorecard
create or replace function public.founder_r3561_supplier_category_scorecard()
returns table(
  supplier_category text,
  runs bigint,
  total_payable_rupees numeric,
  discount_captured_rupees numeric,
  completed bigint,
  on_hold bigint,
  deferred bigint,
  avg_coverage_ratio numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.supplier_category,
    count(*)::bigint,
    coalesce(sum(l.payable_rupees),0)::numeric,
    coalesce(sum(l.discount_capture_rupees),0)::numeric,
    count(*) filter (where l.run_status = 'completed')::bigint,
    count(*) filter (where l.run_status = 'on_hold')::bigint,
    count(*) filter (where l.run_status = 'deferred')::bigint,
    round(avg(l.coverage_ratio), 3)
  from public.payment_run_calendar_r3561 l
  group by l.supplier_category
  order by coalesce(sum(l.payable_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3561_supplier_category_scorecard() from public, anon;
grant execute on function public.founder_r3561_supplier_category_scorecard() to authenticated;

-- 3) Priority × run-status matrix
create or replace function public.founder_r3561_priority_status_matrix()
returns table(payment_priority text, run_status text, runs bigint, total_payable_rupees numeric, avg_coverage_ratio numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.payment_priority, l.run_status, count(*)::bigint,
    coalesce(sum(l.payable_rupees),0)::numeric,
    round(avg(l.coverage_ratio), 3)
  from public.payment_run_calendar_r3561 l
  group by l.payment_priority, l.run_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3561_priority_status_matrix() from public, anon;
grant execute on function public.founder_r3561_priority_status_matrix() to authenticated;

-- 4) Monthly outflow trend
create or replace function public.founder_r3561_monthly_outflow_trend()
returns table(period_month date, runs bigint, total_payable_rupees numeric, discount_captured_rupees numeric, completed bigint, on_hold bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.payable_rupees),0)::numeric,
    coalesce(sum(l.discount_capture_rupees),0)::numeric,
    count(*) filter (where l.run_status = 'completed')::bigint,
    count(*) filter (where l.run_status = 'on_hold')::bigint
  from public.payment_run_calendar_r3561 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3561_monthly_outflow_trend() from public, anon;
grant execute on function public.founder_r3561_monthly_outflow_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3561_capa_status_board()
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
  from public.payment_run_calendar_capa_actions_r3561 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3561_capa_status_board() from public, anon;
grant execute on function public.founder_r3561_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3561_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.payment_run_calendar_capa_actions_r3561)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.payment_run_calendar_capa_actions_r3561 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3561_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3561_root_cause_pareto() to authenticated;

-- 7) Liquidity-impact digest
create or replace function public.founder_r3561_liquidity_impact_digest()
returns table(liquidity_impact text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.liquidity_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.impact_rupees),0)::numeric
  from public.payment_run_calendar_capa_actions_r3561 c
  group by c.liquidity_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3561_liquidity_impact_digest() from public, anon;
grant execute on function public.founder_r3561_liquidity_impact_digest() to authenticated;

-- 8) High-risk payment-run queue (on-hold-critical / low-coverage / deferred-statutory)
create or replace function public.founder_r3561_high_risk_queue()
returns table(
  payment_batch text,
  supplier_name text,
  supplier_category text,
  scheduled_date date,
  payment_priority text,
  run_status text,
  payable_rupees numeric,
  coverage_ratio numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.payment_batch, l.supplier_name, l.supplier_category, l.scheduled_date,
    l.payment_priority, l.run_status, l.payable_rupees, l.coverage_ratio, l.notes
  from public.payment_run_calendar_r3561 l
  where l.run_status in ('on_hold','partial','deferred')
     or l.coverage_ratio < 1.0
     or (l.payment_priority = 'critical' and l.run_status in ('on_hold','deferred','partial'))
     or (l.payment_priority = 'statutory' and l.run_status = 'deferred')
  order by l.scheduled_date desc, l.payment_batch;
end;
$$;

revoke execute on function public.founder_r3561_high_risk_queue() from public, anon;
grant execute on function public.founder_r3561_high_risk_queue() to authenticated;
