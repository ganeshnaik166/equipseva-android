-- Round 3677: Founder Courier / Stationery / Admin-Consumables Spend Board
-- Admin spend discipline — office × spend category × monthly spend vs budget × variance × vendor fragmentation × unapproved spend × CAPA

-- =============================================================================
-- TABLE 1: admin_spend_r3677 — per-office per-category monthly admin spend records
-- =============================================================================
create table if not exists public.admin_spend_r3677 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  office_location text not null,
  record_code text not null,
  spend_category text not null,
  category text not null check (category in (
    'courier_docs','courier_parts','stationery','pantry','housekeeping','misc_admin'
  )),
  period_month date not null,
  monthly_spend_rupees numeric(12,2) not null,
  budget_rupees numeric(12,2) not null,
  variance_pct numeric(6,2),
  transactions int not null,
  avg_ticket_rupees numeric(10,2),
  bulk_purchase_pct numeric(5,2),
  vendor_count int not null,
  unapproved_spend_rupees numeric(12,2),
  spend_status text not null check (spend_status in (
    'within_budget','on_budget','over_budget','fragmented_vendors','uncontrolled'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.admin_spend_r3677 enable row level security;

create index if not exists idx_admin_spend_r3677_org on public.admin_spend_r3677(organization_id);
create index if not exists idx_admin_spend_r3677_month on public.admin_spend_r3677(period_month);
create index if not exists idx_admin_spend_r3677_status on public.admin_spend_r3677(spend_status);

-- =============================================================================
-- TABLE 2: admin_spend_capa_actions_r3677 — CAPA & spend-control actions
-- =============================================================================
create table if not exists public.admin_spend_capa_actions_r3677 (
  id uuid primary key default gen_random_uuid(),
  spend_record_id uuid not null references public.admin_spend_r3677(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'budget_overrun','vendor_fragmentation','unapproved_purchases','ticket_size_creep',
    'bulk_discount_missed','courier_rate_leakage','pantry_wastage','stationery_hoarding'
  )),
  root_cause text not null check (root_cause in (
    'no_rate_contract','maverick_buying','po_bypass','multiple_small_vendors',
    'no_reorder_policy','festival_season_spike','branch_headcount_growth','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'negotiate_rate_contract','consolidate_vendors','enforce_po_approval','set_monthly_caps',
    'bulk_quarterly_purchase','switch_courier_partner','retrain_admin_staff','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  excess_spend_rupees numeric(12,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.admin_spend_capa_actions_r3677 enable row level security;

create index if not exists idx_admin_spend_capa_r3677_rec on public.admin_spend_capa_actions_r3677(spend_record_id);
create index if not exists idx_admin_spend_capa_r3677_status on public.admin_spend_capa_actions_r3677(capa_status);

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

  -- 16 admin spend records
  insert into public.admin_spend_r3677 (
    organization_id, office_location, record_code, spend_category, category, period_month,
    monthly_spend_rupees, budget_rupees, variance_pct, transactions, avg_ticket_rupees,
    bulk_purchase_pct, vendor_count, unapproved_spend_rupees, spend_status, trend_dir, notes
  )
  select v_org_id, q.ofc, q.rcode, q.scat, q.cat, q.pm::date,
    q.spend, q.bud, q.varp, q.txns, q.avt,
    q.blk, q.vnd, q.unap, q.sst, q.trd, q.nt
  from (values
    ('Mumbai HQ','SPN-MUM-CD-06','Document Courier','courier_docs','2026-06-01',
     48250.00,52000.00,-7.2,182,265.11,22.5,2,0.00,'within_budget','stable','Bluedart rate contract holding; doc courier under budget'),
    ('Mumbai HQ','SPN-MUM-CP-06','Spare-Parts Courier','courier_parts','2026-06-01',
     112400.00,90000.00,24.9,96,1170.83,18.0,5,14500.00,'over_budget','worsening','Urgent part shipments air-freighted without PO approval'),
    ('Mumbai HQ','SPN-MUM-ST-06','Stationery & Printing','stationery','2026-06-01',
     21800.00,24000.00,-9.2,34,641.18,64.0,1,0.00,'within_budget','improving','Quarterly bulk stationery order cut unit costs'),
    ('Chennai Branch','SPN-CHE-CD-06','Document Courier','courier_docs','2026-06-01',
     30400.00,30000.00,1.3,121,251.24,15.0,3,0.00,'on_budget','stable','DTDC and India Post mix; marginal variance'),
    ('Chennai Branch','SPN-CHE-PN-06','Pantry Supplies','pantry','2026-06-01',
     26750.00,20000.00,33.8,42,636.90,10.0,6,5200.00,'uncontrolled','worsening','Six local grocers billing separately; no reorder policy'),
    ('Chennai Branch','SPN-CHE-HK-06','Housekeeping Consumables','housekeeping','2026-06-01',
     18900.00,18000.00,5.0,12,1575.00,55.0,2,0.00,'on_budget','stable','Consolidated to two vendors after May review'),
    ('Delhi Warehouse','SPN-DEL-CP-06','Spare-Parts Courier','courier_parts','2026-06-01',
     134600.00,120000.00,12.2,143,941.26,30.0,4,8900.00,'over_budget','stable','Reverse-logistics of defective boards inflating spend'),
    ('Delhi Warehouse','SPN-DEL-HK-06','Housekeeping Consumables','housekeeping','2026-06-01',
     22300.00,25000.00,-10.8,15,1486.67,48.0,2,0.00,'within_budget','improving','Warehouse cleaning supplies on quarterly bulk cycle'),
    ('Delhi Warehouse','SPN-DEL-MA-06','Misc Admin Purchases','misc_admin','2026-06-01',
     41200.00,28000.00,47.1,27,1525.93,5.0,9,16800.00,'uncontrolled','worsening','Ad-hoc purchases across nine vendors; PO bypass rampant'),
    ('Bengaluru Service Hub','SPN-BLR-CD-06','Document Courier','courier_docs','2026-06-01',
     27300.00,28000.00,-2.5,104,262.50,20.0,2,0.00,'on_budget','stable','Service-report dispatches steady month over month'),
    ('Bengaluru Service Hub','SPN-BLR-ST-06','Stationery & Printing','stationery','2026-06-01',
     31200.00,22000.00,41.8,48,650.00,8.0,7,6400.00,'fragmented_vendors','worsening','Seven stationers used; no rate contract in place'),
    ('Hyderabad Branch','SPN-HYD-CP-06','Spare-Parts Courier','courier_parts','2026-06-01',
     68450.00,70000.00,-2.2,77,888.96,25.0,3,0.00,'on_budget','improving','Consolidated to Safexpress surface for non-urgent parts'),
    ('Hyderabad Branch','SPN-HYD-PN-06','Pantry Supplies','pantry','2026-06-01',
     14100.00,15000.00,-6.0,18,783.33,40.0,2,0.00,'within_budget','stable','Monthly bulk pantry indent working well'),
    ('Pune Office','SPN-PUN-MA-06','Misc Admin Purchases','misc_admin','2026-06-01',
     19850.00,18000.00,10.3,22,902.27,12.0,5,3100.00,'fragmented_vendors','stable','Small office; five vendors for minor admin buys'),
    ('Mumbai HQ','SPN-MUM-CD-05','Document Courier','courier_docs','2026-05-01',
     51600.00,52000.00,-0.8,190,271.58,21.0,2,0.00,'on_budget','stable','May baseline before rate-contract renewal'),
    ('Chennai Branch','SPN-CHE-PN-05','Pantry Supplies','pantry','2026-05-01',
     23400.00,20000.00,17.0,39,600.00,12.0,5,2600.00,'over_budget','worsening','Pantry spend creeping since April; flagged to admin head')
  ) as q(ofc, rcode, scat, cat, pm, spend, bud, varp, txns, avt, blk, vnd, unap, sst, trd, nt);

  -- CAPA seed — attach to specific spend records via record_code
  insert into public.admin_spend_capa_actions_r3677 (
    spend_record_id, finding_category, root_cause, corrective_action,
    capa_status, excess_spend_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.exs, q.own, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SPN-MUM-CP-06','unapproved_purchases','po_bypass','enforce_po_approval','in_progress',14500.00,'Ravi Deshmukh','2026-07-15',null,'Air-freight courier now requires ops-head PO above Rs 2000'),
    ('SPN-CHE-PN-06','vendor_fragmentation','multiple_small_vendors','consolidate_vendors','open',6750.00,'Meena Iyer','2026-07-20',null,'Shortlisting single pantry supplier with monthly indent'),
    ('SPN-DEL-MA-06','budget_overrun','maverick_buying','set_monthly_caps','escalated',13200.00,'Arjun Mehta','2026-07-10',null,'Warehouse misc spend 47 pct over; purchase-card limits being cut'),
    ('SPN-BLR-ST-06','vendor_fragmentation','no_rate_contract','negotiate_rate_contract','in_progress',9200.00,'Kavya Rao','2026-07-18',null,'Two stationers invited for annual rate-contract bids'),
    ('SPN-DEL-CP-06','courier_rate_leakage','no_rate_contract','switch_courier_partner','verification_pending',14600.00,'Arjun Mehta','2026-07-12',null,'Safexpress surface pilot for reverse logistics under review'),
    ('SPN-CHE-PN-05','ticket_size_creep','no_reorder_policy','retrain_admin_staff','closed',3400.00,'Meena Iyer','2026-06-25','2026-06-22','Admin staff retrained on indent process; May overrun closed'),
    ('SPN-PUN-MA-06','unapproved_purchases','po_bypass','enforce_po_approval','open',3100.00,'Sneha Kulkarni','2026-07-25',null,'Petty-cash misc buys to route through PO from July'),
    ('SPN-MUM-ST-06','bulk_discount_missed','no_reorder_policy','bulk_quarterly_purchase','closed',0.00,'Ravi Deshmukh','2026-06-15','2026-06-10','Quarterly bulk stationery cycle locked in; savings realised')
  ) as q(rcode, fc, rc, ca, cst, exs, own, tcd, acd, nt)
  join public.admin_spend_r3677 e
    on e.organization_id = v_org_id and e.record_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Spend status distribution
create or replace function public.founder_r3677_spend_status_rollup()
returns table(spend_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.admin_spend_r3677)
  select l.spend_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.admin_spend_r3677 l
  group by l.spend_status
  order by count(*) desc;
end;
$$;

-- 2) Office spend scorecard
create or replace function public.founder_r3677_office_scorecard()
returns table(
  office_location text,
  entries bigint,
  within_ct bigint,
  over_ct bigint,
  risk_ct bigint,
  total_spend_rupees numeric,
  total_budget_rupees numeric,
  unapproved_rupees numeric,
  within_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.office_location,
    count(*)::bigint,
    count(*) filter (where l.spend_status in ('within_budget','on_budget'))::bigint,
    count(*) filter (where l.spend_status = 'over_budget')::bigint,
    count(*) filter (where l.spend_status in ('fragmented_vendors','uncontrolled'))::bigint,
    coalesce(sum(l.monthly_spend_rupees),0)::numeric,
    coalesce(sum(l.budget_rupees),0)::numeric,
    coalesce(sum(l.unapproved_spend_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.spend_status in ('within_budget','on_budget'))::numeric / nullif(count(*),0), 1)
  from public.admin_spend_r3677 l
  group by l.office_location
  order by coalesce(sum(l.monthly_spend_rupees),0) desc;
end;
$$;

-- 3) Category × spend-status matrix
create or replace function public.founder_r3677_category_status_matrix()
returns table(category text, spend_status text, entries bigint, total_spend_rupees numeric, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.category, l.spend_status, count(*)::bigint,
    coalesce(sum(l.monthly_spend_rupees),0)::numeric,
    round(avg(l.variance_pct), 1)
  from public.admin_spend_r3677 l
  group by l.category, l.spend_status
  order by count(*) desc, l.category;
end;
$$;

-- 4) Monthly spend trend
create or replace function public.founder_r3677_monthly_spend_trend()
returns table(period_month date, entries bigint, total_spend_rupees numeric, total_budget_rupees numeric, over_budget_ct bigint, unapproved_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.monthly_spend_rupees),0)::numeric,
    coalesce(sum(l.budget_rupees),0)::numeric,
    count(*) filter (where l.spend_status in ('over_budget','uncontrolled'))::bigint,
    coalesce(sum(l.unapproved_spend_rupees),0)::numeric
  from public.admin_spend_r3677 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3677_capa_status_board()
returns table(capa_status text, findings bigint, avg_excess_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.excess_spend_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.admin_spend_capa_actions_r3677 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root cause pareto
create or replace function public.founder_r3677_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_excess_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.admin_spend_capa_actions_r3677)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.excess_spend_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.admin_spend_capa_actions_r3677 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Variance digest — spend records banded by budget variance
create or replace function public.founder_r3677_variance_digest()
returns table(variance_band text, entries bigint, total_spend_rupees numeric, total_budget_rupees numeric, unapproved_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.band, count(*)::bigint,
    coalesce(sum(s.spend),0)::numeric,
    coalesce(sum(s.bud),0)::numeric,
    coalesce(sum(s.unap),0)::numeric
  from (
    select case
      when l.variance_pct is null then 'unclassified'
      when l.variance_pct <= 0 then 'at_or_under_budget'
      when l.variance_pct <= 10 then 'overrun_0_10_pct'
      when l.variance_pct <= 25 then 'overrun_10_25_pct'
      else 'overrun_above_25_pct'
    end as band,
    l.monthly_spend_rupees as spend,
    l.budget_rupees as bud,
    l.unapproved_spend_rupees as unap
    from public.admin_spend_r3677 l
  ) s
  group by s.band
  order by count(*) desc;
end;
$$;

-- 8) High-risk spend queue (over-budget / fragmented / uncontrolled / worsening)
create or replace function public.founder_r3677_high_risk_queue()
returns table(
  office_location text,
  record_code text,
  spend_category text,
  category text,
  period_month date,
  monthly_spend_rupees numeric,
  budget_rupees numeric,
  variance_pct numeric,
  spend_status text,
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
  select l.office_location, l.record_code, l.spend_category, l.category, l.period_month,
    l.monthly_spend_rupees, l.budget_rupees, l.variance_pct, l.spend_status, l.trend_dir, l.notes
  from public.admin_spend_r3677 l
  where l.spend_status in ('over_budget','fragmented_vendors','uncontrolled')
     or l.trend_dir = 'worsening'
     or l.unapproved_spend_rupees > 0
  order by l.period_month desc, l.office_location;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3677_spend_status_rollup() from public, anon;
revoke all on function public.founder_r3677_office_scorecard() from public, anon;
revoke all on function public.founder_r3677_category_status_matrix() from public, anon;
revoke all on function public.founder_r3677_monthly_spend_trend() from public, anon;
revoke all on function public.founder_r3677_capa_status_board() from public, anon;
revoke all on function public.founder_r3677_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3677_variance_digest() from public, anon;
revoke all on function public.founder_r3677_high_risk_queue() from public, anon;

grant execute on function public.founder_r3677_spend_status_rollup() to authenticated;
grant execute on function public.founder_r3677_office_scorecard() to authenticated;
grant execute on function public.founder_r3677_category_status_matrix() to authenticated;
grant execute on function public.founder_r3677_monthly_spend_trend() to authenticated;
grant execute on function public.founder_r3677_capa_status_board() to authenticated;
grant execute on function public.founder_r3677_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3677_variance_digest() to authenticated;
grant execute on function public.founder_r3677_high_risk_queue() to authenticated;
