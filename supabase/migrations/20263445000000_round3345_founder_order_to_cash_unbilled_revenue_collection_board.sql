-- Round 3345: Founder Order-to-Cash, Unbilled-Revenue & Invoice-to-Collection Governance Board
-- O2C revenue log — hospital × revenue segment × period × jobs completed × billable value × invoiced × unbilled × invoice lag × collected × outstanding × DSO × disputed × stage bottleneck × O2C verdict × CAPA

-- =============================================================================
-- TABLE 1: o2c_revenue_r3345 — per customer/segment/period O2C revenue rows
-- =============================================================================
create table if not exists public.o2c_revenue_r3345 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  revenue_segment text not null check (revenue_segment in (
    'amc_contract','breakdown_repair','spare_sales','installation','warranty_billable','consumables'
  )),
  period_month text not null,
  jobs_completed int not null,
  billable_value_rupees numeric(14,2) not null,
  invoiced_value_rupees numeric(14,2) not null,
  unbilled_value_rupees numeric(14,2) not null,
  invoice_lag_days numeric(6,1) not null,
  collected_value_rupees numeric(14,2) not null,
  outstanding_value_rupees numeric(14,2) not null,
  dso_days numeric(6,1) not null,
  disputed_value_rupees numeric(14,2) not null,
  o2c_stage_bottleneck text not null check (o2c_stage_bottleneck in (
    'none','billing_delay','approval_pending','dispute','collection_delay','credit_hold'
  )),
  o2c_verdict text not null check (o2c_verdict in (
    'healthy','unbilled_action','billing_lag','collection_lag','dispute_resolution','escalate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.o2c_revenue_r3345 enable row level security;

create index if not exists idx_o2c_revenue_r3345_org on public.o2c_revenue_r3345(organization_id);
create index if not exists idx_o2c_revenue_r3345_period on public.o2c_revenue_r3345(period_month);
create index if not exists idx_o2c_revenue_r3345_verdict on public.o2c_revenue_r3345(o2c_verdict);

-- =============================================================================
-- TABLE 2: o2c_revenue_capa_actions_r3345 — billing / collection / dispute CAPA
-- =============================================================================
create table if not exists public.o2c_revenue_capa_actions_r3345 (
  id uuid primary key default gen_random_uuid(),
  revenue_row_id uuid not null references public.o2c_revenue_r3345(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'unbilled_backlog','invoice_delay','dispute_open','collection_overdue',
    'credit_hold_breach','short_payment','revenue_leakage','write_off_risk'
  )),
  root_cause text not null check (root_cause in (
    'manual_billing_process','approval_bottleneck','missing_po','customer_dispute',
    'documentation_gap','credit_policy_gap','erp_sync_failure','pending_investigation','collections_understaffed'
  )),
  corrective_action text not null check (corrective_action in (
    'raise_invoice_now','expedite_approval','obtain_po','dispute_resolution_meeting',
    'escalate_to_cfo','adjust_credit_terms','automate_billing','assign_collections_agent',
    'write_off_provision','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  revenue_impact text not null check (revenue_impact in (
    'revenue_recognition_delay','cash_flow_impact','bad_debt_risk','none','internal_only','audit_finding'
  )),
  target_closure_date date,
  actual_closure_date date,
  recovery_value_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.o2c_revenue_capa_actions_r3345 enable row level security;

create index if not exists idx_o2c_capa_r3345_row on public.o2c_revenue_capa_actions_r3345(revenue_row_id);
create index if not exists idx_o2c_capa_r3345_status on public.o2c_revenue_capa_actions_r3345(capa_status);

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

  -- 14 O2C revenue rows
  insert into public.o2c_revenue_r3345 (
    organization_id, hospital_name, revenue_segment, period_month, jobs_completed,
    billable_value_rupees, invoiced_value_rupees, unbilled_value_rupees, invoice_lag_days,
    collected_value_rupees, outstanding_value_rupees, dso_days, disputed_value_rupees,
    o2c_stage_bottleneck, o2c_verdict, notes
  )
  select v_org_id, q.hosp, q.seg, q.pm, q.jobs,
    q.billable, q.invoiced, q.unbilled, q.lag,
    q.collected, q.outstanding, q.dso, q.disputed,
    q.bottleneck, q.verdict, q.nt
  from (values
    ('Apollo Chennai','amc_contract','2026-06',18,
     2400000.00,2400000.00,0.00,3.0,
     2400000.00,0.00,22.0,0.00,
     'none','healthy','AMC billed and collected on schedule'),
    ('Apollo Chennai','breakdown_repair','2026-06',12,
     680000.00,520000.00,160000.00,11.0,
     400000.00,120000.00,38.0,0.00,
     'billing_delay','billing_lag','1.6L unbilled repairs from month-end jobs'),
    ('Fortis Gurgaon','amc_contract','2026-06',22,
     3100000.00,3100000.00,0.00,4.0,
     1800000.00,1300000.00,61.0,0.00,
     'collection_delay','collection_lag','Collections slipping past 60-day DSO on renewal book'),
    ('Fortis Gurgaon','spare_sales','2026-05',9,
     540000.00,540000.00,0.00,2.0,
     540000.00,0.00,28.0,0.00,
     'none','healthy','Spare-part sales invoiced and cleared'),
    ('Manipal Bengaluru','breakdown_repair','2026-06',15,
     920000.00,610000.00,310000.00,14.0,
     500000.00,110000.00,41.0,0.00,
     'approval_pending','unbilled_action','3.1L awaiting customer PO before invoicing'),
    ('Manipal Bengaluru','consumables','2026-06',30,
     460000.00,460000.00,0.00,5.0,
     300000.00,160000.00,35.0,0.00,
     'none','healthy','Consumables mostly collected, small tail outstanding'),
    ('AIIMS Delhi','installation','2026-05',4,
     5200000.00,3900000.00,1300000.00,21.0,
     2000000.00,1900000.00,74.0,0.00,
     'approval_pending','unbilled_action','Govt tender milestone billing lag; 13L unbilled'),
    ('AIIMS Delhi','warranty_billable','2026-06',7,
     380000.00,0.00,380000.00,26.0,
     0.00,0.00,0.0,0.00,
     'billing_delay','billing_lag','Warranty-exceeded work not yet invoiced after 26 days'),
    ('CMC Vellore','amc_contract','2026-06',16,
     1750000.00,1750000.00,0.00,3.0,
     1750000.00,0.00,19.0,0.00,
     'none','healthy','Clean AMC order-to-cash cycle'),
    ('CMC Vellore','breakdown_repair','2026-05',11,
     720000.00,720000.00,0.00,6.0,
     300000.00,260000.00,55.0,160000.00,
     'dispute','dispute_resolution','1.6L disputed on labour-hour billing'),
    ('KIMS Hyderabad','spare_sales','2026-06',13,
     1100000.00,900000.00,200000.00,9.0,
     500000.00,400000.00,47.0,0.00,
     'credit_hold','escalate','Customer on credit hold; 4L outstanding, escalate'),
    ('KIMS Hyderabad','installation','2026-04',3,
     4100000.00,4100000.00,0.00,7.0,
     1500000.00,2600000.00,88.0,600000.00,
     'dispute','escalate','26L outstanding incl 6L dispute; 88-day DSO'),
    ('Yashoda Hyderabad','consumables','2026-06',26,
     520000.00,520000.00,0.00,4.0,
     520000.00,0.00,24.0,0.00,
     'none','healthy','Consumables billing on track'),
    ('Narayana Bengaluru','breakdown_repair','2026-06',19,
     1360000.00,980000.00,380000.00,13.0,
     700000.00,280000.00,44.0,0.00,
     'billing_delay','billing_lag','3.8L unbilled from field jobs pending closure docs')
  ) as q(hosp, seg, pm, jobs, billable, invoiced, unbilled, lag, collected, outstanding, dso, disputed, bottleneck, verdict, nt);

  -- CAPA seed — attach to specific revenue rows by hospital + segment + period
  insert into public.o2c_revenue_capa_actions_r3345 (
    revenue_row_id, finding_category, root_cause, corrective_action,
    capa_status, revenue_impact, target_closure_date, actual_closure_date,
    recovery_value_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.ri, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('Apollo Chennai','breakdown_repair','2026-06','invoice_delay','manual_billing_process','raise_invoice_now',
     'in_progress','revenue_recognition_delay','2026-07-25',null,160000.00,'Batch-invoice month-end repairs; automate next cycle'),
    ('Fortis Gurgaon','amc_contract','2026-06','collection_overdue','collections_understaffed','assign_collections_agent',
     'escalated','cash_flow_impact','2026-07-22',null,1300000.00,'13L past 60 days; dedicated collector assigned'),
    ('Manipal Bengaluru','breakdown_repair','2026-06','unbilled_backlog','missing_po','obtain_po',
     'open','revenue_recognition_delay','2026-07-28',null,310000.00,'Chasing customer PO to unlock 3.1L billing'),
    ('AIIMS Delhi','installation','2026-05','unbilled_backlog','approval_bottleneck','expedite_approval',
     'in_progress','revenue_recognition_delay','2026-07-30',null,1300000.00,'Milestone sign-off stuck with govt PMO'),
    ('AIIMS Delhi','warranty_billable','2026-06','invoice_delay','documentation_gap','raise_invoice_now',
     'open','revenue_recognition_delay','2026-07-24',null,380000.00,'Warranty-exceeded proof pending to raise invoice'),
    ('CMC Vellore','breakdown_repair','2026-05','dispute_open','customer_dispute','dispute_resolution_meeting',
     'verification_pending','audit_finding','2026-07-20','2026-07-12',160000.00,'Labour-hour dispute; joint reconciliation completed'),
    ('KIMS Hyderabad','installation','2026-04','collection_overdue','credit_policy_gap','escalate_to_cfo',
     'overdue','bad_debt_risk','2026-06-30',null,2600000.00,'88-day DSO incl 6L dispute; CFO escalation and provision review')
  ) as q(hosp, seg, pm, fc, rc, ca, cst, ri, tcd, acd, cost, nt)
  join public.o2c_revenue_r3345 e
    on e.organization_id = v_org_id and e.hospital_name = q.hosp and e.revenue_segment = q.seg and e.period_month = q.pm;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) O2C verdict distribution
create or replace function public.founder_r3345_o2c_verdict_rollup()
returns table(o2c_verdict text, entries bigint, total_billable_rupees numeric, total_outstanding_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.o2c_revenue_r3345)
  select r.o2c_verdict, count(*)::bigint,
         coalesce(sum(r.billable_value_rupees),0)::numeric,
         coalesce(sum(r.outstanding_value_rupees),0)::numeric,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.o2c_revenue_r3345 r
  group by r.o2c_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3345_o2c_verdict_rollup() from public, anon;
grant execute on function public.founder_r3345_o2c_verdict_rollup() to authenticated;

-- 2) Hospital-level O2C scorecard
create or replace function public.founder_r3345_hospital_scorecard()
returns table(
  hospital_name text,
  periods bigint,
  jobs_completed bigint,
  billable_value_rupees numeric,
  invoiced_value_rupees numeric,
  unbilled_value_rupees numeric,
  collected_value_rupees numeric,
  outstanding_value_rupees numeric,
  avg_dso_days numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.hospital_name,
    count(*)::bigint,
    coalesce(sum(r.jobs_completed),0)::bigint,
    coalesce(sum(r.billable_value_rupees),0)::numeric,
    coalesce(sum(r.invoiced_value_rupees),0)::numeric,
    coalesce(sum(r.unbilled_value_rupees),0)::numeric,
    coalesce(sum(r.collected_value_rupees),0)::numeric,
    coalesce(sum(r.outstanding_value_rupees),0)::numeric,
    round(avg(r.dso_days), 1)
  from public.o2c_revenue_r3345 r
  group by r.hospital_name
  order by coalesce(sum(r.outstanding_value_rupees),0) desc;
end;
$$;

revoke execute on function public.founder_r3345_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3345_hospital_scorecard() to authenticated;

-- 3) Revenue segment × period matrix
create or replace function public.founder_r3345_segment_period_matrix()
returns table(revenue_segment text, period_month text, entries bigint, billable_value_rupees numeric, unbilled_value_rupees numeric, outstanding_value_rupees numeric, avg_invoice_lag_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.revenue_segment, r.period_month, count(*)::bigint,
    coalesce(sum(r.billable_value_rupees),0)::numeric,
    coalesce(sum(r.unbilled_value_rupees),0)::numeric,
    coalesce(sum(r.outstanding_value_rupees),0)::numeric,
    round(avg(r.invoice_lag_days), 1)
  from public.o2c_revenue_r3345 r
  group by r.revenue_segment, r.period_month
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3345_segment_period_matrix() from public, anon;
grant execute on function public.founder_r3345_segment_period_matrix() to authenticated;

-- 4) Period trend
create or replace function public.founder_r3345_period_trend()
returns table(period_month text, entries bigint, billable_value_rupees numeric, invoiced_value_rupees numeric, collected_value_rupees numeric, unbilled_value_rupees numeric, outstanding_value_rupees numeric, avg_dso_days numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.period_month, count(*)::bigint,
    coalesce(sum(r.billable_value_rupees),0)::numeric,
    coalesce(sum(r.invoiced_value_rupees),0)::numeric,
    coalesce(sum(r.collected_value_rupees),0)::numeric,
    coalesce(sum(r.unbilled_value_rupees),0)::numeric,
    coalesce(sum(r.outstanding_value_rupees),0)::numeric,
    round(avg(r.dso_days), 1)
  from public.o2c_revenue_r3345 r
  group by r.period_month
  order by r.period_month desc;
end;
$$;

revoke execute on function public.founder_r3345_period_trend() from public, anon;
grant execute on function public.founder_r3345_period_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3345_capa_status_board()
returns table(capa_status text, findings bigint, avg_recovery_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.recovery_value_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.o2c_revenue_capa_actions_r3345 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3345_capa_status_board() from public, anon;
grant execute on function public.founder_r3345_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3345_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_recovery_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.o2c_revenue_capa_actions_r3345)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.recovery_value_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.o2c_revenue_capa_actions_r3345 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3345_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3345_root_cause_pareto() to authenticated;

-- 7) Revenue-impact (cost/risk) digest
create or replace function public.founder_r3345_revenue_impact_digest()
returns table(revenue_impact text, findings bigint, open_findings bigint, total_recovery_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.revenue_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.recovery_value_rupees),0)::numeric
  from public.o2c_revenue_capa_actions_r3345 c
  group by c.revenue_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3345_revenue_impact_digest() from public, anon;
grant execute on function public.founder_r3345_revenue_impact_digest() to authenticated;

-- 8) High-risk O2C queue (top unbilled / collection concerns)
create or replace function public.founder_r3345_high_risk_queue()
returns table(
  hospital_name text,
  revenue_segment text,
  period_month text,
  unbilled_value_rupees numeric,
  outstanding_value_rupees numeric,
  dso_days numeric,
  disputed_value_rupees numeric,
  o2c_stage_bottleneck text,
  o2c_verdict text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select r.hospital_name, r.revenue_segment, r.period_month,
    r.unbilled_value_rupees, r.outstanding_value_rupees, r.dso_days, r.disputed_value_rupees,
    r.o2c_stage_bottleneck, r.o2c_verdict, r.notes
  from public.o2c_revenue_r3345 r
  where r.o2c_verdict in ('unbilled_action','billing_lag','collection_lag','dispute_resolution','escalate')
     or r.o2c_stage_bottleneck in ('billing_delay','approval_pending','dispute','collection_delay','credit_hold')
  order by case r.o2c_verdict
             when 'escalate' then 0
             when 'dispute_resolution' then 1
             when 'collection_lag' then 2
             when 'unbilled_action' then 3
             when 'billing_lag' then 4
             else 5
           end,
           r.outstanding_value_rupees desc;
end;
$$;

revoke execute on function public.founder_r3345_high_risk_queue() from public, anon;
grant execute on function public.founder_r3345_high_risk_queue() to authenticated;
