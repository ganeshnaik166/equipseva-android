-- Round 3629: Founder Advance-Tax / 234B-234C Interest / TDS-Credit Board
-- Founder finance — advance-tax installment tracking per entity: estimated liability × advance-tax due/paid ×
-- TDS/TCS credit × shortfall × sec 234B interest × sec 234C interest × cumulative-paid % × payment status × CAPA

-- =============================================================================
-- TABLE 1: advance_tax_r3629 — per-entity per-quarter advance-tax installment fact
-- =============================================================================
create table if not exists public.advance_tax_r3629 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  installment_ref text not null,
  entity_name text not null,
  quarter_label text not null,
  period_month date not null,
  estimated_tax_liability_rupees numeric(14,2),
  advance_tax_due_rupees numeric(14,2),
  advance_tax_paid_rupees numeric(14,2),
  tds_tcs_credit_rupees numeric(14,2),
  shortfall_rupees numeric(14,2),
  interest_234b_rupees numeric(14,2),
  interest_234c_rupees numeric(14,2),
  cumulative_paid_pct numeric(5,2),
  payment_status text not null check (payment_status in (
    'paid_on_time','short_paid','deferred','interest_accruing','defaulted'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.advance_tax_r3629 enable row level security;

create index if not exists idx_advance_tax_r3629_org on public.advance_tax_r3629(organization_id);
create index if not exists idx_advance_tax_r3629_month on public.advance_tax_r3629(period_month);
create index if not exists idx_advance_tax_r3629_status on public.advance_tax_r3629(payment_status);

-- =============================================================================
-- TABLE 2: advance_tax_capa_actions_r3629 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.advance_tax_capa_actions_r3629 (
  id uuid primary key default gen_random_uuid(),
  tax_log_id uuid not null references public.advance_tax_r3629(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'advance_tax_shortfall','interest_234b_accrual','interest_234c_accrual','tds_credit_mismatch',
    'estimation_error','cashflow_deferral','installment_missed','tds_certificate_pending'
  )),
  root_cause text not null check (root_cause in (
    'underestimated_profit','delayed_collections','tds_not_reflected_26as','cashflow_constraint',
    'advisor_delay','manual_calculation_error','client_payment_default','pending_investigation',
    'capex_timing_mismatch','gst_refund_delay'
  )),
  corrective_action text not null check (corrective_action in (
    'pay_shortfall_with_interest','revise_estimate_next_installment','reconcile_tds_26as',
    'accelerate_collections','arrange_bridge_finance','engage_tax_advisor',
    'file_lower_deduction_certificate','automate_tax_computation','escalate_to_cfo','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  interest_exposure_rupees numeric(14,2),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.advance_tax_capa_actions_r3629 enable row level security;

create index if not exists idx_advance_tax_capa_r3629_log on public.advance_tax_capa_actions_r3629(tax_log_id);
create index if not exists idx_advance_tax_capa_r3629_status on public.advance_tax_capa_actions_r3629(capa_status);

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

  -- 16 advance-tax installment rows
  insert into public.advance_tax_r3629 (
    organization_id, installment_ref, entity_name, quarter_label, period_month,
    estimated_tax_liability_rupees, advance_tax_due_rupees, advance_tax_paid_rupees, tds_tcs_credit_rupees,
    shortfall_rupees, interest_234b_rupees, interest_234c_rupees, cumulative_paid_pct,
    payment_status, trend_dir, notes
  )
  select v_org_id, q.iref, q.ent, q.ql, q.pm::date,
    q.liab, q.dueamt, q.paid, q.tds,
    q.shf, q.i234b, q.i234c, q.cumpct,
    q.pstat, q.tdir, q.nt
  from (values
    ('AT-MED-Q1','EquipSeva Medtech Pvt Ltd','Q1_FY2627','2026-06-01',4000000,600000,600000,150000,0,0,0,15.0,'paid_on_time','stable','Q1 15% installment paid on time; TDS credit reconciled'),
    ('AT-MED-Q2','EquipSeva Medtech Pvt Ltd','Q2_FY2627','2026-09-01',4200000,1290000,1290000,320000,0,0,0,45.0,'paid_on_time','improving','Q2 cumulative 45% met; estimate revised up to 42L'),
    ('AT-MED-Q3','EquipSeva Medtech Pvt Ltd','Q3_FY2627','2026-12-01',4200000,1050000,800000,350000,250000,4500,3200,68.0,'short_paid','worsening','Q3 short by 2.5L; 234C interest accruing on deferred amount'),
    ('AT-DIA-Q1','EquipSeva Diagnostics LLP','Q1_FY2627','2026-06-01',1800000,270000,270000,90000,0,0,0,15.0,'paid_on_time','stable','Diagnostics LLP Q1 paid on time'),
    ('AT-DIA-Q2','EquipSeva Diagnostics LLP','Q2_FY2627','2026-09-01',1900000,585000,400000,120000,185000,0,2800,36.0,'short_paid','worsening','Q2 collections delayed; part shortfall, 234C accruing'),
    ('AT-DIA-Q3','EquipSeva Diagnostics LLP','Q3_FY2627','2026-12-01',1900000,840000,0,130000,840000,12600,9800,36.0,'interest_accruing','worsening','Q3 installment missed entirely; heavy 234B/234C exposure'),
    ('AT-SPR-Q1','EquipSeva Spares AMC Pvt Ltd','Q1_FY2627','2026-06-01',2400000,360000,360000,200000,0,0,0,15.0,'paid_on_time','improving','Spares and AMC Q1 paid; strong AMC TDS credit'),
    ('AT-SPR-Q2','EquipSeva Spares AMC Pvt Ltd','Q2_FY2627','2026-09-01',2500000,765000,765000,260000,0,0,0,45.0,'paid_on_time','stable','Q2 cumulative 45% met on AMC book'),
    ('AT-SPR-Q3','EquipSeva Spares AMC Pvt Ltd','Q3_FY2627','2026-12-01',2500000,750000,600000,280000,150000,0,1900,71.0,'deferred','stable','Q3 partially deferred pending client AMC receipts'),
    ('AT-PRJ-Q1','EquipSeva Projects Pvt Ltd','Q1_FY2627','2026-06-01',5200000,780000,500000,100000,280000,0,3400,10.0,'short_paid','worsening','Projects Q1 short; large capex timing mismatch'),
    ('AT-PRJ-Q2','EquipSeva Projects Pvt Ltd','Q2_FY2627','2026-09-01',5400000,1650000,0,150000,1650000,24800,18600,9.0,'defaulted','worsening','Q2 defaulted; project milestone billing stuck, major interest'),
    ('AT-PRJ-Q3','EquipSeva Projects Pvt Ltd','Q3_FY2627','2026-12-01',5400000,1350000,900000,180000,450000,8200,6100,43.0,'interest_accruing','worsening','Q3 partial; cumulative behind schedule, interest accruing'),
    ('AT-FND-Q1','Founder Individual','Q1_FY2627','2026-06-01',950000,142500,142500,60000,0,0,0,15.0,'paid_on_time','stable','Founder personal advance tax Q1 on time'),
    ('AT-FND-Q2','Founder Individual','Q2_FY2627','2026-09-01',980000,298500,298500,75000,0,0,0,45.0,'paid_on_time','improving','Founder Q2 cumulative 45% met'),
    ('AT-FND-Q3','Founder Individual','Q3_FY2627','2026-12-01',980000,294000,210000,80000,84000,0,1200,66.0,'deferred','stable','Founder Q3 deferred; salary TDS covers most, small 234C'),
    ('AT-MED-Q4','EquipSeva Medtech Pvt Ltd','Q4_FY2627','2027-03-01',4200000,1060000,700000,360000,360000,15400,5200,85.0,'interest_accruing','worsening','Q4 final installment short; 234B interest building on assessed gap')
  ) as q(iref, ent, ql, pm, liab, dueamt, paid, tds, shf, i234b, i234c, cumpct, pstat, tdir, nt);

  -- CAPA seed — attach to specific installments via installment_ref
  insert into public.advance_tax_capa_actions_r3629 (
    tax_log_id, finding_category, root_cause, corrective_action,
    capa_status, interest_exposure_rupees, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.iexp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('AT-MED-Q3','interest_234c_accrual','delayed_collections','pay_shortfall_with_interest','in_progress',7700,'Rohan Mehta (CFO)','2026-12-30',null,'Pay Q3 shortfall with 234C interest; collections drive underway'),
    ('AT-DIA-Q2','tds_credit_mismatch','tds_not_reflected_26as','reconcile_tds_26as','open',2800,'Priya Nair (Accounts)','2026-10-15',null,'Vendor TDS not in 26AS; reconcile before Q3'),
    ('AT-DIA-Q3','installment_missed','cashflow_constraint','arrange_bridge_finance','escalated',22400,'Rohan Mehta (CFO)','2026-12-20',null,'Q3 missed; arrange bridge finance to clear before FY close'),
    ('AT-PRJ-Q1','advance_tax_shortfall','capex_timing_mismatch','revise_estimate_next_installment','closed',3400,'Anil Kumar (Tax)','2026-09-10','2026-09-05','Q1 shortfall trued up in Q2 estimate; closed'),
    ('AT-PRJ-Q2','installment_missed','client_payment_default','escalate_to_cfo','escalated',43400,'Rohan Mehta (CFO)','2026-11-30',null,'Q2 default from stuck milestone billing; escalated to CFO'),
    ('AT-PRJ-Q3','interest_234b_accrual','delayed_collections','accelerate_collections','in_progress',14300,'Priya Nair (Accounts)','2027-01-15',null,'Accelerate project receivables to cut 234B exposure'),
    ('AT-MED-Q4','estimation_error','underestimated_profit','engage_tax_advisor','verification_pending',20600,'Anil Kumar (Tax)','2027-03-25',null,'Profit underestimated; advisor recomputing assessed liability'),
    ('AT-FND-Q3','cashflow_deferral','cashflow_constraint','none_required','closed',1200,'Founder','2026-12-31','2026-12-28','Minor deferral; salary TDS covers, negligible 234C — closed')
  ) as q(iref, fc, rc, ca, cst, iexp, ownr, tcd, acd, nt)
  join public.advance_tax_r3629 e
    on e.organization_id = v_org_id and e.installment_ref = q.iref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Payment-status distribution
create or replace function public.founder_r3629_payment_status_rollup()
returns table(payment_status text, installments bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.advance_tax_r3629)
  select l.payment_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.advance_tax_r3629 l
  group by l.payment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3629_payment_status_rollup() from public, anon;
grant execute on function public.founder_r3629_payment_status_rollup() to authenticated;

-- 2) Entity-level advance-tax scorecard
create or replace function public.founder_r3629_entity_scorecard()
returns table(
  entity_name text,
  total_installments bigint,
  paid_on_time bigint,
  short_paid bigint,
  interest_accruing bigint,
  defaulted bigint,
  total_liability_rupees numeric,
  total_paid_rupees numeric,
  total_interest_rupees numeric,
  on_time_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.entity_name,
    count(*)::bigint,
    count(*) filter (where l.payment_status = 'paid_on_time')::bigint,
    count(*) filter (where l.payment_status = 'short_paid')::bigint,
    count(*) filter (where l.payment_status = 'interest_accruing')::bigint,
    count(*) filter (where l.payment_status = 'defaulted')::bigint,
    coalesce(sum(l.estimated_tax_liability_rupees),0)::numeric,
    coalesce(sum(l.advance_tax_paid_rupees),0)::numeric,
    coalesce(sum(l.interest_234b_rupees + l.interest_234c_rupees),0)::numeric,
    round(100.0 * count(*) filter (where l.payment_status = 'paid_on_time')::numeric / nullif(count(*),0), 1)
  from public.advance_tax_r3629 l
  group by l.entity_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3629_entity_scorecard() from public, anon;
grant execute on function public.founder_r3629_entity_scorecard() to authenticated;

-- 3) Quarter × payment-status matrix
create or replace function public.founder_r3629_quarter_status_matrix()
returns table(quarter_label text, payment_status text, installments bigint, total_shortfall_rupees numeric, total_interest_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.quarter_label, l.payment_status, count(*)::bigint,
    coalesce(sum(l.shortfall_rupees),0)::numeric,
    coalesce(sum(l.interest_234b_rupees + l.interest_234c_rupees),0)::numeric
  from public.advance_tax_r3629 l
  group by l.quarter_label, l.payment_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3629_quarter_status_matrix() from public, anon;
grant execute on function public.founder_r3629_quarter_status_matrix() to authenticated;

-- 4) Monthly advance-tax trend
create or replace function public.founder_r3629_monthly_trend()
returns table(period_month date, installments bigint, total_due_rupees numeric, total_paid_rupees numeric, total_shortfall_rupees numeric, total_interest_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.advance_tax_due_rupees),0)::numeric,
    coalesce(sum(l.advance_tax_paid_rupees),0)::numeric,
    coalesce(sum(l.shortfall_rupees),0)::numeric,
    coalesce(sum(l.interest_234b_rupees + l.interest_234c_rupees),0)::numeric
  from public.advance_tax_r3629 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke execute on function public.founder_r3629_monthly_trend() from public, anon;
grant execute on function public.founder_r3629_monthly_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3629_capa_status_board()
returns table(capa_status text, findings bigint, avg_interest_exposure_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.interest_exposure_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.advance_tax_capa_actions_r3629 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3629_capa_status_board() from public, anon;
grant execute on function public.founder_r3629_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3629_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_interest_exposure_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.advance_tax_capa_actions_r3629)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.interest_exposure_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.advance_tax_capa_actions_r3629 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3629_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3629_root_cause_pareto() to authenticated;

-- 7) Interest-exposure digest (by finding category)
create or replace function public.founder_r3629_interest_exposure_digest()
returns table(finding_category text, findings bigint, open_findings bigint, total_interest_exposure_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.finding_category, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.interest_exposure_rupees),0)::numeric
  from public.advance_tax_capa_actions_r3629 c
  group by c.finding_category
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3629_interest_exposure_digest() from public, anon;
grant execute on function public.founder_r3629_interest_exposure_digest() to authenticated;

-- 8) High-risk installment queue (interest accruing / defaulted / shortfall)
create or replace function public.founder_r3629_high_risk_queue()
returns table(
  entity_name text,
  installment_ref text,
  quarter_label text,
  period_month date,
  payment_status text,
  shortfall_rupees numeric,
  interest_234b_rupees numeric,
  interest_234c_rupees numeric,
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
  select l.entity_name, l.installment_ref, l.quarter_label, l.period_month,
    l.payment_status, l.shortfall_rupees, l.interest_234b_rupees, l.interest_234c_rupees,
    l.trend_dir, l.notes
  from public.advance_tax_r3629 l
  where l.payment_status in ('interest_accruing','defaulted','short_paid','deferred')
     or l.shortfall_rupees > 0
     or l.interest_234b_rupees > 0
     or l.interest_234c_rupees > 0
     or l.trend_dir = 'worsening'
  order by l.period_month desc, l.entity_name;
end;
$$;

revoke execute on function public.founder_r3629_high_risk_queue() from public, anon;
grant execute on function public.founder_r3629_high_risk_queue() to authenticated;
