-- Round 3616: Founder Vendor Advance-Recoverable Aging Board
-- Founder finance — vendor/supplier advance-recoverable aging + settlement recovery per vendor:
-- vendor × category × period × advance paid/adjusted/outstanding × PO-linkage × aging bucket ×
-- recovery status × trend × overdue impact × CAPA recovery actions

-- =============================================================================
-- TABLE 1: vendor_advance_r3616 — per-vendor advance-recoverable aging fact table
-- =============================================================================
create table if not exists public.vendor_advance_r3616 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  vendor_name text not null,
  advance_ref text not null,
  category text not null check (category in (
    'amc_services','spare_parts','projects','diagnostics','rentals','installation'
  )),
  period_month date not null,
  advance_paid_rupees numeric(14,2) not null,
  advance_adjusted_rupees numeric(14,2) not null,
  advance_outstanding_rupees numeric(14,2) not null,
  po_linked_pct numeric(5,2),
  expected_settlement_date date,
  overdue_rupees numeric(14,2) not null,
  aging_bucket text not null check (aging_bucket in (
    '0_30_days','31_90_days','91_180_days','over_180_days'
  )),
  recovery_status text not null check (recovery_status in (
    'current','on_track','delayed','stuck','write_off_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_advance_r3616 enable row level security;

create index if not exists idx_vendor_advance_r3616_org on public.vendor_advance_r3616(organization_id);
create index if not exists idx_vendor_advance_r3616_month on public.vendor_advance_r3616(period_month);
create index if not exists idx_vendor_advance_r3616_status on public.vendor_advance_r3616(recovery_status);

-- =============================================================================
-- TABLE 2: vendor_advance_capa_actions_r3616 — CAPA & recovery actions
-- =============================================================================
create table if not exists public.vendor_advance_capa_actions_r3616 (
  id uuid primary key default gen_random_uuid(),
  advance_id uuid not null references public.vendor_advance_r3616(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'overdue_advance','no_po_linkage','settlement_delay','vendor_dispute',
    'excess_advance','documentation_gap','write_off_candidate','early_advance_release'
  )),
  root_cause text not null check (root_cause in (
    'vendor_delay','po_not_raised','goods_not_received','pricing_dispute',
    'vendor_financial_stress','internal_approval_backlog','contract_terms_unfavourable',
    'pending_investigation','duplicate_advance','fx_or_bank_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'accelerate_delivery','link_po_retrospectively','issue_debit_note','negotiate_settlement_plan',
    'recover_via_next_invoice','escalate_to_legal','write_off_partial','withhold_future_advance',
    'none_required','adjust_against_pending_bills'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  recovery_priority text not null check (recovery_priority in (
    'critical','high','medium','low','watchlist'
  )),
  recovery_impact_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.vendor_advance_capa_actions_r3616 enable row level security;

create index if not exists idx_vendor_advance_capa_r3616_link on public.vendor_advance_capa_actions_r3616(advance_id);
create index if not exists idx_vendor_advance_capa_r3616_status on public.vendor_advance_capa_actions_r3616(capa_status);

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

  -- 16 vendor advance rows
  insert into public.vendor_advance_r3616 (
    organization_id, vendor_name, advance_ref, category, period_month,
    advance_paid_rupees, advance_adjusted_rupees, advance_outstanding_rupees, po_linked_pct,
    expected_settlement_date, overdue_rupees, aging_bucket, recovery_status, trend_dir, notes
  )
  select v_org_id, q.vname, q.aref, q.cat, q.pmonth::date,
    q.paid, q.adj, q.outstd, q.polink,
    q.esd::date, q.overdue, q.abkt, q.rstat, q.tdir, q.nt
  from (values
    ('Siemens Healthineers India','ADV-2601','spare_parts','2026-07-01',
     500000,350000,150000,100,'2026-08-15',0,'0_30_days','on_track','improving',
     'CT tube advance, PO-linked, adjusting against dispatches'),
    ('GE Healthcare India','ADV-2602','amc_services','2026-07-01',
     300000,300000,0,100,'2026-06-30',0,'0_30_days','current','stable',
     'AMC advance fully adjusted this quarter'),
    ('Philips India','ADV-2603','projects','2026-06-01',
     1200000,400000,800000,90,'2026-07-10',200000,'31_90_days','delayed','worsening',
     'Cath-lab project advance, milestone slippage'),
    ('Trivitron Healthcare','ADV-2604','diagnostics','2026-05-01',
     250000,50000,200000,40,'2026-06-20',200000,'91_180_days','stuck','worsening',
     'Reagent advance, no PO linkage, vendor delivery pending'),
    ('BPL Medical','ADV-2605','spare_parts','2026-05-15',
     180000,180000,0,100,'2026-06-01',0,'0_30_days','current','stable',
     'Monitor spares advance settled'),
    ('Wipro GE','ADV-2606','installation','2026-06-15',
     600000,200000,400000,85,'2026-07-25',0,'31_90_days','on_track','improving',
     'MRI installation advance, on schedule'),
    ('Skanray Technologies','ADV-2607','projects','2026-02-01',
     900000,100000,800000,30,'2026-04-30',700000,'over_180_days','write_off_risk','worsening',
     'Old project advance, vendor financial stress, recovery doubtful'),
    ('Allengers Medical','ADV-2608','rentals','2026-06-01',
     150000,90000,60000,70,'2026-07-15',0,'31_90_days','on_track','stable',
     'C-arm rental advance adjusting monthly'),
    ('Mindray India','ADV-2609','diagnostics','2026-04-01',
     400000,120000,280000,55,'2026-05-30',280000,'91_180_days','delayed','worsening',
     'Analyzer reagent advance, settlement delayed'),
    ('Erba Diagnostics','ADV-2610','diagnostics','2026-07-01',
     220000,220000,0,100,'2026-07-05',0,'0_30_days','current','improving',
     'Diagnostics advance cleared'),
    ('Nihon Kohden India','ADV-2611','spare_parts','2026-03-01',
     320000,40000,280000,20,'2026-05-01',250000,'over_180_days','stuck','worsening',
     'ECG spares advance stuck, goods not received'),
    ('Poly Medicure','ADV-2612','spare_parts','2026-06-20',
     90000,60000,30000,100,'2026-07-20',0,'0_30_days','on_track','stable',
     'Consumable spares advance, minor balance'),
    ('Transasia Bio-Medicals','ADV-2613','amc_services','2026-05-01',
     500000,250000,250000,75,'2026-06-25',100000,'91_180_days','delayed','stable',
     'Lab AMC advance, partial overdue'),
    ('Drager India','ADV-2614','projects','2026-06-10',
     1500000,500000,1000000,95,'2026-08-01',0,'31_90_days','on_track','improving',
     'ICU project advance milestone-linked'),
    ('Meril Diagnostics','ADV-2615','rentals','2026-01-15',
     200000,20000,180000,25,'2026-03-15',180000,'over_180_days','write_off_risk','worsening',
     'Rental advance long overdue, vendor dispute'),
    ('Agappe Diagnostics','ADV-2616','diagnostics','2026-06-05',
     160000,100000,60000,80,'2026-07-18',0,'31_90_days','on_track','stable',
     'Reagent advance adjusting on track')
  ) as q(vname, aref, cat, pmonth, paid, adj, outstd, polink, esd, overdue, abkt, rstat, tdir, nt);

  -- 8 CAPA recovery-action rows — attach via advance_ref
  insert into public.vendor_advance_capa_actions_r3616 (
    advance_id, finding_category, root_cause, corrective_action,
    capa_status, recovery_priority, recovery_impact_rupees, owner,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.rp, q.impact, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('ADV-2604','no_po_linkage','po_not_raised','link_po_retrospectively','in_progress','high',200000,'Procurement — Ravi Kumar','2026-08-05',null,'Retro PO being raised for reagent advance'),
    ('ADV-2607','write_off_candidate','vendor_financial_stress','escalate_to_legal','escalated','critical',700000,'Finance — Anjali Rao','2026-08-10',null,'Vendor insolvency risk, legal notice issued'),
    ('ADV-2603','settlement_delay','vendor_delay','negotiate_settlement_plan','open','high',200000,'Projects — Suresh Menon','2026-08-15',null,'Milestone slippage, settlement plan under negotiation'),
    ('ADV-2611','overdue_advance','goods_not_received','issue_debit_note','overdue','high',250000,'Procurement — Ravi Kumar','2026-07-20',null,'Goods not received, debit note raised past target'),
    ('ADV-2609','settlement_delay','internal_approval_backlog','adjust_against_pending_bills','verification_pending','medium',280000,'Finance — Anjali Rao','2026-08-01',null,'Adjusting against pending invoices, verification due'),
    ('ADV-2615','vendor_dispute','pricing_dispute','write_off_partial','closed','critical',180000,'Finance — Anjali Rao','2026-07-15','2026-07-12','Partial write-off approved after dispute resolution'),
    ('ADV-2613','overdue_advance','vendor_delay','recover_via_next_invoice','in_progress','medium',100000,'AMC — Deepak Nair','2026-08-08',null,'Recovering overdue portion via next AMC invoice'),
    ('ADV-2601','excess_advance','contract_terms_unfavourable','withhold_future_advance','closed','low',0,'Procurement — Ravi Kumar','2026-07-10','2026-07-08','Excess advance policy tightened, future advances capped')
  ) as q(aref, fc, rc, ca, cst, rp, impact, ownr, tcd, acd, nt)
  join public.vendor_advance_r3616 e
    on e.organization_id = v_org_id and e.advance_ref = q.aref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Recovery status distribution
create or replace function public.founder_r3616_recovery_status_rollup()
returns table(recovery_status text, advances bigint, total_outstanding_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_advance_r3616)
  select l.recovery_status, count(*)::bigint,
         coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.vendor_advance_r3616 l
  group by l.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3616_recovery_status_rollup() from public, anon;
grant execute on function public.founder_r3616_recovery_status_rollup() to authenticated;

-- 2) Category scorecard
create or replace function public.founder_r3616_category_scorecard()
returns table(
  category text,
  advances bigint,
  total_paid_rupees numeric,
  total_adjusted_rupees numeric,
  total_outstanding_rupees numeric,
  total_overdue_rupees numeric,
  stuck_or_writeoff bigint,
  avg_po_linked_pct numeric,
  current_pct numeric
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
    coalesce(sum(l.advance_paid_rupees),0)::numeric,
    coalesce(sum(l.advance_adjusted_rupees),0)::numeric,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric,
    count(*) filter (where l.recovery_status in ('stuck','write_off_risk'))::bigint,
    round(avg(l.po_linked_pct), 1),
    round(100.0 * count(*) filter (where l.recovery_status in ('current','on_track'))::numeric / nullif(count(*),0), 1)
  from public.vendor_advance_r3616 l
  group by l.category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3616_category_scorecard() from public, anon;
grant execute on function public.founder_r3616_category_scorecard() to authenticated;

-- 3) Aging bucket × recovery status matrix
create or replace function public.founder_r3616_aging_recovery_matrix()
returns table(
  aging_bucket text,
  recovery_status text,
  advances bigint,
  total_outstanding_rupees numeric,
  total_overdue_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.aging_bucket, l.recovery_status, count(*)::bigint,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric
  from public.vendor_advance_r3616 l
  group by l.aging_bucket, l.recovery_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3616_aging_recovery_matrix() from public, anon;
grant execute on function public.founder_r3616_aging_recovery_matrix() to authenticated;

-- 4) Monthly advance trend
create or replace function public.founder_r3616_monthly_advance_trend()
returns table(
  period_month date,
  advances bigint,
  total_paid_rupees numeric,
  total_adjusted_rupees numeric,
  total_outstanding_rupees numeric,
  total_overdue_rupees numeric
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
    coalesce(sum(l.advance_paid_rupees),0)::numeric,
    coalesce(sum(l.advance_adjusted_rupees),0)::numeric,
    coalesce(sum(l.advance_outstanding_rupees),0)::numeric,
    coalesce(sum(l.overdue_rupees),0)::numeric
  from public.vendor_advance_r3616 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3616_monthly_advance_trend() from public, anon;
grant execute on function public.founder_r3616_monthly_advance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3616_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
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
  from public.vendor_advance_capa_actions_r3616 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3616_capa_status_board() from public, anon;
grant execute on function public.founder_r3616_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3616_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.vendor_advance_capa_actions_r3616)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.vendor_advance_capa_actions_r3616 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3616_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3616_root_cause_pareto() to authenticated;

-- 7) Overdue-impact digest (by recovery priority)
create or replace function public.founder_r3616_overdue_impact_digest()
returns table(recovery_priority text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.recovery_priority, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_impact_rupees),0)::numeric
  from public.vendor_advance_capa_actions_r3616 c
  group by c.recovery_priority
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3616_overdue_impact_digest() from public, anon;
grant execute on function public.founder_r3616_overdue_impact_digest() to authenticated;

-- 8) High-risk recovery queue (stuck / write_off_risk and worsening exposures)
create or replace function public.founder_r3616_high_risk_queue()
returns table(
  vendor_name text,
  advance_ref text,
  category text,
  period_month date,
  aging_bucket text,
  recovery_status text,
  advance_outstanding_rupees numeric,
  overdue_rupees numeric,
  po_linked_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.vendor_name, l.advance_ref, l.category, l.period_month, l.aging_bucket,
    l.recovery_status, l.advance_outstanding_rupees, l.overdue_rupees, l.po_linked_pct, l.notes
  from public.vendor_advance_r3616 l
  where l.recovery_status in ('stuck','write_off_risk','delayed')
     or l.trend_dir = 'worsening'
     or l.aging_bucket = 'over_180_days'
     or l.overdue_rupees > 0
  order by l.overdue_rupees desc, l.advance_outstanding_rupees desc, l.period_month;
end;
$$;

revoke execute on function public.founder_r3616_high_risk_queue() from public, anon;
grant execute on function public.founder_r3616_high_risk_queue() to authenticated;
