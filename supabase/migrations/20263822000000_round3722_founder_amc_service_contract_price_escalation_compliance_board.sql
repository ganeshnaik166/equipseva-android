-- Round 3722: Founder AMC / Service-Contract Price-Escalation Compliance Board
-- AMC/service-contract price-escalation clauses (CPI-linked or fixed-%) — whether annual rate
-- revisions were applied correctly/on-time, customer notification, revenue leakage from missed
-- escalations. Distinct from generic contract-renewal-pipeline pages, which track renewal timing,
-- not escalation-clause execution.

-- =============================================================================
-- TABLE 1: amc_escalation_r3722 — per-contract price-escalation compliance facts
-- =============================================================================
create table if not exists public.amc_escalation_r3722 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contract_ref text not null,
  customer_name text not null,
  period_month date not null,
  contract_value_rupees numeric(12,2),
  escalation_clause_pct numeric,
  escalation_due_date date,
  escalation_applied boolean not null,
  escalation_applied_date date,
  days_late int,
  revenue_leakage_rupees numeric(12,2),
  customer_notified boolean not null,
  customer_disputed boolean not null,
  cpi_linked boolean not null,
  escalation_class text not null check (escalation_class in (
    'fixed_pct','cpi_linked','negotiated','none_applicable'
  )),
  escalation_status text not null check (escalation_status in (
    'applied_on_time','applied_late','pending','waived','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.amc_escalation_r3722 enable row level security;

create index if not exists idx_amc_escalation_r3722_org on public.amc_escalation_r3722(organization_id);
create index if not exists idx_amc_escalation_r3722_month on public.amc_escalation_r3722(period_month);
create index if not exists idx_amc_escalation_r3722_status on public.amc_escalation_r3722(escalation_status);

-- =============================================================================
-- TABLE 2: amc_escalation_capa_actions_r3722 — CAPA actions on missed/late escalations
-- =============================================================================
create table if not exists public.amc_escalation_capa_actions_r3722 (
  id uuid primary key default gen_random_uuid(),
  escalation_id uuid references public.amc_escalation_r3722(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.amc_escalation_capa_actions_r3722 enable row level security;

create index if not exists idx_amc_escalation_capa_r3722_esc on public.amc_escalation_capa_actions_r3722(escalation_id);
create index if not exists idx_amc_escalation_capa_r3722_status on public.amc_escalation_capa_actions_r3722(capa_status);

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

  -- 16 escalation-compliance rows
  insert into public.amc_escalation_r3722 (
    organization_id, contract_ref, customer_name, period_month,
    contract_value_rupees, escalation_clause_pct, escalation_due_date,
    escalation_applied, escalation_applied_date, days_late,
    revenue_leakage_rupees, customer_notified, customer_disputed, cpi_linked,
    escalation_class, escalation_status, trend_dir, notes
  )
  select v_org_id, q.cref, q.cust, q.pm::date,
    q.cval, q.eclause, q.edue::date,
    q.eapp, q.eappd::date, q.dlate,
    q.leak, q.notif, q.disp, q.cpi,
    q.cls, q.st, q.trd, q.nt
  from (values
    ('AMC-2201','Bharat Forge Ltd','2026-07-01',
     1850000.00,5.0,'2026-07-01',
     true,'2026-07-01',0,
     0.00,true,false,false,
     'fixed_pct','applied_on_time','stable','5% flat escalation applied on due date per MSA clause 4.2'),
    ('AMC-2202','Tata Steel Processing','2026-07-01',
     2400000.00,null,'2026-07-01',
     true,'2026-07-05',4,
     26301.37,true,false,true,
     'cpi_linked','applied_late','worsening','CPI index published 3 days late by MoSPI — knock-on delay'),
    ('AMC-2203','Larsen Toubro Construction','2026-06-01',
     3100000.00,4.0,'2026-06-01',
     false,null,null,
     339726.03,false,false,false,
     'fixed_pct','pending','worsening','Ops team missed escalation trigger — no notice sent to customer'),
    ('AMC-2204','Ashok Leyland Fleet','2026-06-01',
     980000.00,null,'2026-06-01',
     true,'2026-06-01',0,
     0.00,true,false,true,
     'cpi_linked','applied_on_time','stable','CPI-linked clause applied automatically via billing engine'),
    ('AMC-2205','Ultratech Cement Works','2026-05-01',
     1560000.00,6.0,'2026-05-01',
     true,'2026-06-02',32,
     136931.51,true,true,false,
     'fixed_pct','disputed','worsening','Customer disputes 6% figure citing verbal 4% commitment — legal review'),
    ('AMC-2206','Mahindra Agri Equipment','2026-07-01',
     720000.00,3.5,'2026-07-01',
     true,'2026-07-01',0,
     0.00,true,false,false,
     'fixed_pct','applied_on_time','improving','Auto-reminder workflow live since June — zero misses this quarter'),
    ('AMC-2207','JSW Energy Plant Services','2026-06-01',
     4200000.00,null,'2026-06-01',
     false,null,null,
     460273.97,false,false,true,
     'cpi_linked','pending','worsening','Large account — awaiting finance sign-off on CPI computation basis'),
    ('AMC-2208','Godrej Industrial Cranes','2026-05-01',
     640000.00,0.0,'2026-05-01',
     true,'2026-05-01',0,
     0.00,true,false,false,
     'none_applicable','waived','stable','First-year contract — escalation clause waived per signed addendum'),
    ('AMC-2209','Hindalco Materials Handling','2026-07-01',
     1320000.00,5.5,'2026-07-01',
     true,'2026-07-03',2,
     19726.03,true,false,false,
     'fixed_pct','applied_late','improving','Two-day slip vs prior quarter four-day slip — approvals faster now'),
    ('AMC-2210','Adani Ports Equipment Hire','2026-06-01',
     2850000.00,null,'2026-06-01',
     true,'2026-06-10',9,
     70273.97,true,false,true,
     'cpi_linked','applied_late','worsening','CPI data lag plus internal approval queue — compounding delay'),
    ('AMC-2211','Reliance Refinery Services','2026-05-01',
     3650000.00,4.5,'2026-05-01',
     true,'2026-05-01',0,
     0.00,true,false,false,
     'fixed_pct','applied_on_time','stable','Escalation embedded in auto-renewal invoice template'),
    ('AMC-2212','Vedanta Mining Ops','2026-07-01',
     1150000.00,5.0,'2026-07-01',
     false,null,null,
     56712.33,true,true,false,
     'fixed_pct','disputed','worsening','Customer disputes escalation applicability post-partial-scope reduction'),
    ('AMC-2213','Cipla Pharma Facilities','2026-06-01',
     890000.00,null,'2026-06-01',
     true,'2026-06-01',0,
     0.00,true,false,true,
     'cpi_linked','applied_on_time','improving','CPI feed now automated via API — zero manual steps'),
    ('AMC-2214','Dabur Manufacturing Units','2026-05-01',
     540000.00,3.0,'2026-05-01',
     true,'2026-05-20',19,
     28438.36,false,false,false,
     'fixed_pct','applied_late','worsening','Notification skipped — customer only found out via invoice'),
    ('AMC-2215','ITC Agro Warehousing','2026-07-01',
     1980000.00,null,'2026-08-01',
     false,null,null,
     0.00,true,false,true,
     'cpi_linked','pending','stable','Not yet due — CPI publication expected first week of August'),
    ('AMC-2216','Britannia Cold Chain','2026-06-01',
     760000.00,4.0,'2026-06-01',
     true,'2026-06-01',0,
     0.00,true,false,false,
     'negotiated','applied_on_time','stable','Renegotiated to 4% from original 6% at customer request, signed addendum')
  ) as q(cref, cust, pm, cval, eclause, edue, eapp, eappd, dlate, leak, notif, disp, cpi, cls, st, trd, nt);

  -- CAPA seed — attach to specific contracts via contract_ref
  insert into public.amc_escalation_capa_actions_r3722 (
    escalation_id, root_cause, corrective_action, capa_status,
    owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('AMC-2202','CPI index publication delay not buffered in workflow','Add 5-day buffer to escalation trigger calendar for CPI-linked contracts','closed','Billing Ops Lead','2026-07-20','2026-07-18','Buffer added to scheduler — verified on next CPI cycle'),
    ('AMC-2203','Escalation trigger missed by ops team — no automated reminder','Enable auto-reminder 15 days before escalation_due_date','in_progress','Contracts Manager','2026-08-20',null,'Reminder rule built — pending rollout to full contract book'),
    ('AMC-2205','Verbal commitment not captured in contract amendment','Formalize all rate discussions in written addenda before renewal','open','Key Account Manager','2026-08-25',null,'Legal drafting revised addendum — customer review pending'),
    ('AMC-2207','Large-account CPI computation basis pending finance sign-off','Escalate to CFO for computation-basis approval SLA','overdue','Finance Controller','2026-07-31',null,'Sign-off still pending — third follow-up sent this week'),
    ('AMC-2209','Approval queue causing recurring 2-4 day slippage','Delegate sub-5%-value approvals to regional finance leads','closed','Regional Finance Lead','2026-07-10','2026-07-09','Delegation matrix updated — slippage down from 4 to 2 days'),
    ('AMC-2210','CPI data lag compounded by internal approval queue','Parallelize CPI fetch and approval steps instead of sequential','in_progress','Billing Ops Lead','2026-08-18',null,'Workflow re-sequencing in UAT — targeting next escalation cycle'),
    ('AMC-2212','Escalation applied despite partial scope reduction not reflected','Cross-check active scope against escalation base before billing','open','Contracts Manager','2026-08-22',null,'Scope-reconciliation checklist drafted — awaiting sign-off'),
    ('AMC-2214','Customer notification step skipped in manual process','Make customer notification a mandatory gate before invoice release','closed','Billing Ops Lead','2026-06-15','2026-06-12','Invoice-release checklist now blocks on notification-sent flag')
  ) as q(cref, rc, ca, cst, ownr, tcd, acd, nt)
  join public.amc_escalation_r3722 e
    on e.organization_id = v_org_id and e.contract_ref = q.cref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Escalation-status distribution
create or replace function public.founder_r3722_escalation_status_rollup()
returns table(escalation_status text, contracts bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.amc_escalation_r3722)
  select l.escalation_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.amc_escalation_r3722 l
  group by l.escalation_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3722_escalation_status_rollup() from public, anon;
grant execute on function public.founder_r3722_escalation_status_rollup() to authenticated;

-- 2) Customer scorecard
create or replace function public.founder_r3722_customer_scorecard()
returns table(
  customer_name text,
  contracts bigint,
  applied_on_time bigint,
  applied_late bigint,
  pending bigint,
  disputed bigint,
  total_contract_value_rupees numeric,
  total_leakage_rupees numeric,
  avg_days_late numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.customer_name,
    count(*)::bigint,
    count(*) filter (where l.escalation_status = 'applied_on_time')::bigint,
    count(*) filter (where l.escalation_status = 'applied_late')::bigint,
    count(*) filter (where l.escalation_status = 'pending')::bigint,
    count(*) filter (where l.escalation_status = 'disputed')::bigint,
    coalesce(sum(l.contract_value_rupees),0)::numeric,
    coalesce(sum(l.revenue_leakage_rupees),0)::numeric,
    round(avg(l.days_late), 1)
  from public.amc_escalation_r3722 l
  group by l.customer_name
  order by coalesce(sum(l.revenue_leakage_rupees),0) desc;
end;
$$;

revoke all on function public.founder_r3722_customer_scorecard() from public, anon;
grant execute on function public.founder_r3722_customer_scorecard() to authenticated;

-- 3) Escalation-class x status matrix
create or replace function public.founder_r3722_escalation_class_status_matrix()
returns table(escalation_class text, escalation_status text, contracts bigint, total_leakage_rupees numeric, avg_days_late numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.escalation_class, l.escalation_status, count(*)::bigint,
    coalesce(sum(l.revenue_leakage_rupees),0)::numeric,
    round(avg(l.days_late), 1)
  from public.amc_escalation_r3722 l
  group by l.escalation_class, l.escalation_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3722_escalation_class_status_matrix() from public, anon;
grant execute on function public.founder_r3722_escalation_class_status_matrix() to authenticated;

-- 4) Monthly leakage trend
create or replace function public.founder_r3722_monthly_leakage_trend()
returns table(period_month date, contracts bigint, total_leakage_rupees numeric, applied_late bigint, disputed bigint, worsening_contracts bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.revenue_leakage_rupees),0)::numeric,
    count(*) filter (where l.escalation_status = 'applied_late')::bigint,
    count(*) filter (where l.escalation_status = 'disputed')::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.amc_escalation_r3722 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3722_monthly_leakage_trend() from public, anon;
grant execute on function public.founder_r3722_monthly_leakage_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3722_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.amc_escalation_capa_actions_r3722 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3722_capa_status_board() from public, anon;
grant execute on function public.founder_r3722_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3722_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.amc_escalation_capa_actions_r3722 where root_cause is not null)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.amc_escalation_capa_actions_r3722 c
  where c.root_cause is not null
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3722_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3722_root_cause_pareto() to authenticated;

-- 7) Revenue-leakage digest
create or replace function public.founder_r3722_revenue_leakage_digest()
returns table(
  contracts_at_risk bigint,
  total_leakage_rupees numeric,
  undisclosed_leakage_rupees numeric,
  unnotified_contracts bigint,
  disputed_contracts bigint,
  avg_days_late numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*) filter (where l.revenue_leakage_rupees > 0)::bigint,
    coalesce(sum(l.revenue_leakage_rupees),0)::numeric,
    coalesce(sum(l.revenue_leakage_rupees) filter (where l.customer_notified = false),0)::numeric,
    count(*) filter (where l.customer_notified = false)::bigint,
    count(*) filter (where l.customer_disputed = true)::bigint,
    round(avg(l.days_late) filter (where l.days_late is not null), 1)
  from public.amc_escalation_r3722 l;
end;
$$;

revoke all on function public.founder_r3722_revenue_leakage_digest() from public, anon;
grant execute on function public.founder_r3722_revenue_leakage_digest() to authenticated;

-- 8) High-risk escalation queue (pending / disputed / late / high leakage)
create or replace function public.founder_r3722_high_risk_queue()
returns table(
  contract_ref text,
  customer_name text,
  period_month date,
  escalation_class text,
  escalation_status text,
  escalation_due_date date,
  days_late int,
  revenue_leakage_rupees numeric,
  customer_notified boolean,
  customer_disputed boolean,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.contract_ref, l.customer_name, l.period_month,
    l.escalation_class, l.escalation_status, l.escalation_due_date,
    l.days_late, l.revenue_leakage_rupees, l.customer_notified, l.customer_disputed, l.notes
  from public.amc_escalation_r3722 l
  where l.escalation_status in ('pending','disputed','applied_late')
     or l.revenue_leakage_rupees > 50000
     or l.customer_notified = false
  order by l.revenue_leakage_rupees desc nulls last, l.days_late desc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3722_high_risk_queue() from public, anon;
grant execute on function public.founder_r3722_high_risk_queue() to authenticated;
