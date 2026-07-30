-- Round 3604: Founder Receivables Collection-Efficiency Performance Board
-- Receivables finance — customer segment × period × billed vs collected × collection-efficiency ×
-- opening/closing receivables × overdue × DSO × promises-kept × collection status × trend × CAPA

-- =============================================================================
-- TABLE 1: collection_eff_r3604 — per-segment monthly collection-efficiency lines
-- =============================================================================
create table if not exists public.collection_eff_r3604 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  collection_ref text not null,
  customer_segment text not null,
  period_month date not null,
  billed_rupees numeric(14,2) not null,
  collected_rupees numeric(14,2) not null,
  collection_efficiency_pct numeric(5,2),
  opening_receivables_rupees numeric(14,2),
  closing_receivables_rupees numeric(14,2),
  overdue_rupees numeric(14,2),
  overdue_pct numeric(5,2),
  dso_days int,
  promises_kept_pct numeric(5,2),
  collection_status text not null check (collection_status in (
    'excellent','on_target','slipping','poor','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.collection_eff_r3604 enable row level security;

create index if not exists idx_collection_eff_r3604_org on public.collection_eff_r3604(organization_id);
create index if not exists idx_collection_eff_r3604_month on public.collection_eff_r3604(period_month);
create index if not exists idx_collection_eff_r3604_status on public.collection_eff_r3604(collection_status);

-- =============================================================================
-- TABLE 2: collection_eff_capa_actions_r3604 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.collection_eff_capa_actions_r3604 (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collection_eff_r3604(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'billing_dispute','delayed_po','credit_limit_breach','payment_terms_violation',
    'promise_broken','documentation_gap','reconciliation_mismatch',
    'aged_debt_writeoff_risk','collection_follow_up_lapse'
  )),
  root_cause text not null check (root_cause in (
    'customer_cashflow_issue','invoice_dispute','incomplete_documentation','po_amendment_pending',
    'internal_billing_error','weak_follow_up','credit_policy_gap','government_payment_delay',
    'pending_investigation','service_delivery_dispute'
  )),
  corrective_action text not null check (corrective_action in (
    'escalate_to_customer_finance','issue_credit_note','restructure_payment_plan',
    'tighten_credit_terms','correct_invoice_reissue','assign_dedicated_collector',
    'legal_notice','writeoff_provision','complete_documentation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_impact_rupees numeric(14,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.collection_eff_capa_actions_r3604 enable row level security;

create index if not exists idx_collection_eff_capa_r3604_line on public.collection_eff_capa_actions_r3604(collection_id);
create index if not exists idx_collection_eff_capa_r3604_status on public.collection_eff_capa_actions_r3604(capa_status);

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

  -- 16 collection-efficiency lines
  insert into public.collection_eff_r3604 (
    organization_id, collection_ref, customer_segment, period_month,
    billed_rupees, collected_rupees, collection_efficiency_pct,
    opening_receivables_rupees, closing_receivables_rupees, overdue_rupees, overdue_pct,
    dso_days, promises_kept_pct, collection_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.seg, q.pm::date,
    q.billed, q.coll, q.ceff,
    q.oprec, q.clrec, q.ovd, q.opct,
    q.dso, q.pkept, q.cstat, q.trnd, q.nt
  from (values
    ('COL-AMC-0207','amc_services','2026-07-01',
     8500000,7990000,94.0,3200000,3710000,620000,16.7,38,88.0,'on_target','stable','AMC renewal collections holding steady across contracts'),
    ('COL-SPR-0207','spare_parts','2026-07-01',
     6200000,5890000,95.0,1800000,2110000,410000,19.4,32,91.0,'excellent','improving','Spare-parts cash-and-carry sales collecting strongly'),
    ('COL-PRJ-0207','projects','2026-07-01',
     18500000,12950000,70.0,9500000,15050000,7200000,47.8,86,62.0,'poor','worsening','Turnkey project milestones delayed, retention money stuck'),
    ('COL-DIA-0207','diagnostics','2026-07-01',
     4300000,3870000,90.0,1500000,1930000,540000,28.0,44,80.0,'on_target','stable','Diagnostics reagent AMC billing, minor documentation gaps'),
    ('COL-RNT-0207','rentals','2026-07-01',
     2600000,2470000,95.0,700000,830000,150000,18.1,29,93.0,'excellent','stable','Equipment rental monthlies received on time'),
    ('COL-GOV-0207','government_hospitals','2026-07-01',
     14200000,7810000,55.0,16800000,23190000,15600000,67.3,142,45.0,'critical','worsening','Government tenders — PFMS payment cycle extended past 120 days'),
    ('COL-PVT-0207','private_hospitals','2026-07-01',
     9800000,9310000,95.0,2900000,3390000,480000,14.2,34,90.0,'excellent','improving','Private hospital chains paying promptly'),
    ('COL-COR-0207','corporate_accounts','2026-07-01',
     5400000,4590000,85.0,2100000,2910000,980000,33.7,52,76.0,'slipping','worsening','Corporate account disputes on two invoices delaying release'),
    ('COL-AMC-0206','amc_services','2026-06-01',
     8100000,7530000,93.0,3050000,3620000,700000,19.3,40,86.0,'on_target','stable','June AMC collections near target'),
    ('COL-PRJ-0206','projects','2026-06-01',
     16800000,11760000,70.0,8200000,13240000,6400000,48.3,82,60.0,'poor','worsening','Project retention still blocked pending handover sign-off'),
    ('COL-GOV-0206','government_hospitals','2026-06-01',
     13500000,7020000,52.0,15900000,22380000,14800000,66.1,148,42.0,'critical','worsening','Govt receivables aging past 120 days, nodal officer follow-up on'),
    ('COL-DIA-0206','diagnostics','2026-06-01',
     4100000,3730000,91.0,1400000,1770000,470000,26.6,42,82.0,'on_target','improving','Diagnostics collection improving month-on-month'),
    ('COL-SPR-0205','spare_parts','2026-05-01',
     5900000,5600000,95.0,1650000,1950000,380000,19.5,33,90.0,'excellent','stable','Spare-parts collections steady'),
    ('COL-COR-0205','corporate_accounts','2026-05-01',
     5100000,4180000,82.0,1950000,2870000,1050000,36.6,55,72.0,'slipping','worsening','Corporate slippage started, credit-policy review triggered'),
    ('COL-RNT-0205','rentals','2026-05-01',
     2400000,2280000,95.0,650000,770000,140000,18.2,30,92.0,'excellent','stable','Rentals collection stable'),
    ('COL-PVT-0206','private_hospitals','2026-06-01',
     9500000,8930000,94.0,2750000,3320000,520000,15.7,36,89.0,'on_target','stable','Private hospital collections healthy')
  ) as q(ref, seg, pm, billed, coll, ceff, oprec, clrec, ovd, opct, dso, pkept, cstat, trnd, nt);

  -- CAPA seed — attach to specific lines via collection_ref
  insert into public.collection_eff_capa_actions_r3604 (
    collection_id, finding_category, root_cause, corrective_action,
    capa_status, recovery_impact_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.impact, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('COL-PRJ-0207','aged_debt_writeoff_risk','service_delivery_dispute','restructure_payment_plan','in_progress',7200000,'Ravi Menon','2026-08-15',null,'Project retention negotiation with customer finance underway'),
    ('COL-GOV-0207','payment_terms_violation','government_payment_delay','escalate_to_customer_finance','escalated',15600000,'Anita Desai','2026-08-20',null,'PFMS follow-up with hospital accounts and nodal officer'),
    ('COL-COR-0207','billing_dispute','invoice_dispute','issue_credit_note','open',980000,'Suresh Iyer','2026-08-10',null,'Two disputed invoices — credit note under approval'),
    ('COL-PRJ-0206','collection_follow_up_lapse','weak_follow_up','assign_dedicated_collector','verification_pending',6400000,'Ravi Menon','2026-07-25',null,'Dedicated collector assigned to project accounts'),
    ('COL-GOV-0206','aged_debt_writeoff_risk','government_payment_delay','legal_notice','overdue',14800000,'Anita Desai','2026-07-10',null,'Aged government debt over 120 days — legal notice drafted, past target'),
    ('COL-COR-0205','payment_terms_violation','customer_cashflow_issue','tighten_credit_terms','closed',1050000,'Suresh Iyer','2026-06-20','2026-06-18','Credit terms tightened; partial recovery achieved'),
    ('COL-DIA-0207','documentation_gap','incomplete_documentation','complete_documentation','in_progress',540000,'Priya Nair','2026-08-05',null,'Missing delivery challans blocking hospital payment'),
    ('COL-PVT-0207','reconciliation_mismatch','internal_billing_error','correct_invoice_reissue','closed',480000,'Priya Nair','2026-07-15','2026-07-12','Reconciled ledger; reissued corrected invoices')
  ) as q(ref, fc, rc, ca, cst, impact, ownr, tcd, acd, nt)
  join public.collection_eff_r3604 e
    on e.organization_id = v_org_id and e.collection_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Collection-status distribution
create or replace function public.founder_r3604_collection_status_rollup()
returns table(collection_status text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.collection_eff_r3604)
  select l.collection_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.collection_eff_r3604 l
  group by l.collection_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3604_collection_status_rollup() from public, anon;
grant execute on function public.founder_r3604_collection_status_rollup() to authenticated;

-- 2) Customer-segment scorecard
create or replace function public.founder_r3604_segment_scorecard()
returns table(
  customer_segment text,
  lines bigint,
  total_billed_rupees numeric,
  total_collected_rupees numeric,
  avg_collection_efficiency_pct numeric,
  total_overdue_rupees numeric,
  avg_dso_days numeric,
  avg_promises_kept_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment,
    count(*)::bigint,
    coalesce(sum(l.billed_rupees),0)::numeric,
    coalesce(sum(l.collected_rupees),0)::numeric,
    round(avg(l.collection_efficiency_pct), 1),
    coalesce(sum(l.overdue_rupees),0)::numeric,
    round(avg(l.dso_days), 1),
    round(avg(l.promises_kept_pct), 1)
  from public.collection_eff_r3604 l
  group by l.customer_segment
  order by coalesce(sum(l.overdue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3604_segment_scorecard() from public, anon;
grant execute on function public.founder_r3604_segment_scorecard() to authenticated;

-- 3) Segment × collection-status matrix
create or replace function public.founder_r3604_segment_status_matrix()
returns table(customer_segment text, collection_status text, lines bigint, total_billed_rupees numeric, total_overdue_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, l.collection_status, count(*)::bigint,
    coalesce(sum(l.billed_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric
  from public.collection_eff_r3604 l
  group by l.customer_segment, l.collection_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3604_segment_status_matrix() from public, anon;
grant execute on function public.founder_r3604_segment_status_matrix() to authenticated;

-- 4) Monthly collection-efficiency trend
create or replace function public.founder_r3604_monthly_efficiency_trend()
returns table(
  period_month date,
  lines bigint,
  total_billed_rupees numeric,
  total_collected_rupees numeric,
  avg_collection_efficiency_pct numeric,
  total_overdue_rupees numeric,
  avg_dso_days numeric
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
    coalesce(sum(l.billed_rupees),0)::numeric,
    coalesce(sum(l.collected_rupees),0)::numeric,
    round(avg(l.collection_efficiency_pct), 1),
    coalesce(sum(l.overdue_rupees),0)::numeric,
    round(avg(l.dso_days), 1)
  from public.collection_eff_r3604 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3604_monthly_efficiency_trend() from public, anon;
grant execute on function public.founder_r3604_monthly_efficiency_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3604_capa_status_board()
returns table(capa_status text, findings bigint, total_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.collection_eff_capa_actions_r3604 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3604_capa_status_board() from public, anon;
grant execute on function public.founder_r3604_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3604_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.collection_eff_capa_actions_r3604)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.collection_eff_capa_actions_r3604 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3604_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3604_root_cause_pareto() to authenticated;

-- 7) Overdue-impact digest (by segment)
create or replace function public.founder_r3604_overdue_impact_digest()
returns table(customer_segment text, lines bigint, total_overdue_rupees numeric, avg_overdue_pct numeric, high_risk_lines bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_segment, count(*)::bigint,
    coalesce(sum(l.overdue_rupees),0)::numeric,
    round(avg(l.overdue_pct), 1),
    count(*) filter (where l.collection_status in ('poor','critical'))::bigint
  from public.collection_eff_r3604 l
  group by l.customer_segment
  order by coalesce(sum(l.overdue_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3604_overdue_impact_digest() from public, anon;
grant execute on function public.founder_r3604_overdue_impact_digest() to authenticated;

-- 8) High-risk collection queue (poor / critical)
create or replace function public.founder_r3604_high_risk_queue()
returns table(
  customer_segment text,
  collection_ref text,
  period_month date,
  collection_status text,
  collection_efficiency_pct numeric,
  overdue_rupees numeric,
  overdue_pct numeric,
  dso_days int,
  promises_kept_pct numeric,
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
  select l.customer_segment, l.collection_ref, l.period_month, l.collection_status,
    l.collection_efficiency_pct, l.overdue_rupees, l.overdue_pct, l.dso_days,
    l.promises_kept_pct, l.trend_dir, l.notes
  from public.collection_eff_r3604 l
  where l.collection_status in ('poor','critical')
     or l.trend_dir = 'worsening'
     or l.collection_status = 'slipping'
  order by l.overdue_rupees desc, l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3604_high_risk_queue() from public, anon;
grant execute on function public.founder_r3604_high_risk_queue() to authenticated;
