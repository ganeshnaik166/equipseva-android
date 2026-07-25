-- Round 3421: Founder 13-Week Rolling Cash-Flow & Liquidity Board
-- Treasury governance — cash_line × liquidity_status × week × forecast-vs-actual variance × min-buffer breach × collection confidence × CAPA (collection / payment-deferral / facility actions)

-- =============================================================================
-- TABLE 1: treasury_cash_flow_r3421 — per week/line direct cash-flow forecast
-- =============================================================================
create table if not exists public.treasury_cash_flow_r3421 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  counterparty_name text not null,
  week_ending date not null,
  week_number int not null,
  cash_line text not null check (cash_line in (
    'opening_balance','collections_amc','collections_spares','collections_projects',
    'payroll_outflow','vendor_payments','statutory_taxes','capex','loan_emi','closing_balance'
  )),
  forecast_amount_rupees numeric(14,2),
  actual_amount_rupees numeric(14,2),
  variance_rupees numeric(14,2),
  variance_pct numeric(6,2),
  running_balance_rupees numeric(14,2),
  min_buffer_breach boolean not null,
  collection_confidence text not null check (collection_confidence in (
    'high','medium','low','not_applicable'
  )),
  liquidity_status text not null check (liquidity_status in (
    'comfortable','adequate','tight','breach_risk','critical'
  )),
  cash_verdict text not null check (cash_verdict in (
    'on_plan','collection_action','defer_payment','arrange_facility','escalate','monitor'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.treasury_cash_flow_r3421 enable row level security;

create index if not exists idx_treasury_cash_flow_r3421_org on public.treasury_cash_flow_r3421(organization_id);
create index if not exists idx_treasury_cash_flow_r3421_week on public.treasury_cash_flow_r3421(week_ending);
create index if not exists idx_treasury_cash_flow_r3421_verdict on public.treasury_cash_flow_r3421(cash_verdict);

-- =============================================================================
-- TABLE 2: treasury_cash_flow_capa_actions_r3421 — collection / deferral / facility actions
-- =============================================================================
create table if not exists public.treasury_cash_flow_capa_actions_r3421 (
  id uuid primary key default gen_random_uuid(),
  cash_flow_id uuid not null references public.treasury_cash_flow_r3421(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'collection_shortfall','collection_delay','vendor_payment_pressure','statutory_deadline',
    'capex_overrun','loan_emi_bunching','buffer_breach','forecast_variance',
    'revenue_concentration','facility_headroom_low'
  )),
  root_cause text not null check (root_cause in (
    'customer_payment_delay','disputed_invoice','project_milestone_slip','seasonal_dip',
    'large_capex_timing','tax_outflow_bunching','vendor_credit_tightening',
    'collection_process_gap','pending_investigation','over_optimistic_forecast'
  )),
  corrective_action text not null check (corrective_action in (
    'accelerate_collections','offer_early_pay_discount','escalate_to_customer','defer_vendor_payment',
    'negotiate_vendor_terms','draw_working_capital_line','arrange_od_facility','reschedule_capex',
    'stagger_loan_emi','reforecast_week','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  facility_impact text not null check (facility_impact in (
    'covenant_breach_risk','od_utilization_high','none','internal_only','board_escalation','rating_impact'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_impact_rupees numeric(14,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.treasury_cash_flow_capa_actions_r3421 enable row level security;

create index if not exists idx_treasury_cash_flow_capa_r3421_log on public.treasury_cash_flow_capa_actions_r3421(cash_flow_id);
create index if not exists idx_treasury_cash_flow_capa_r3421_status on public.treasury_cash_flow_capa_actions_r3421(capa_status);

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

  -- 14 cash-flow line rows across a 3-week rolling window
  insert into public.treasury_cash_flow_r3421 (
    organization_id, counterparty_name, week_ending, week_number, cash_line,
    forecast_amount_rupees, actual_amount_rupees, variance_rupees, variance_pct,
    running_balance_rupees, min_buffer_breach, collection_confidence, liquidity_status,
    cash_verdict, notes
  )
  select v_org_id, q.cparty, q.wend::date, q.wnum, q.cline,
    q.fc, q.ac, q.varr, q.varp,
    q.runbal, q.buffer, q.conf, q.liq,
    q.verdict, q.nt
  from (values
    ('EquipSeva Treasury','2026-07-31',1,'opening_balance',
     8500000,8500000,0,0,8500000,false,'not_applicable','comfortable','on_plan','Week 1 opening cash position carried into 13-week board'),
    ('Apollo Chennai','2026-07-31',1,'collections_amc',
     3200000,2950000,-250000,-7.81,11450000,false,'high','comfortable','monitor','AMC collection slightly behind — one invoice at T+3'),
    ('Fortis Gurgaon','2026-07-31',1,'collections_spares',
     1450000,900000,-550000,-37.93,12350000,false,'medium','adequate','collection_action','Spares collection short — disputed GST line on PO'),
    ('EquipSeva Treasury','2026-07-31',1,'payroll_outflow',
     2600000,2600000,0,0,9750000,false,'not_applicable','adequate','on_plan','Monthly payroll run cleared on plan'),
    ('EquipSeva Treasury','2026-07-31',1,'vendor_payments',
     1800000,1800000,0,0,7950000,false,'not_applicable','adequate','monitor','Vendor payables cleared per agreed terms'),
    ('EquipSeva Treasury','2026-07-31',1,'closing_balance',
     7950000,7400000,-550000,-6.92,7400000,false,'not_applicable','adequate','monitor','Week 1 close below forecast on spares shortfall'),
    ('EquipSeva Treasury','2026-08-07',2,'opening_balance',
     7400000,7400000,0,0,7400000,false,'not_applicable','adequate','on_plan','Week 2 opening carried from week 1 actual close'),
    ('Manipal Bengaluru','2026-08-07',2,'collections_projects',
     5200000,3100000,-2100000,-40.38,10500000,false,'low','tight','collection_action','Project milestone collection slipped — client sign-off pending'),
    ('AIIMS Delhi','2026-08-07',2,'collections_amc',
     2800000,2800000,0,0,13300000,false,'high','adequate','on_plan','Government AMC tranche received on schedule'),
    ('EquipSeva Treasury','2026-08-07',2,'statutory_taxes',
     3400000,3400000,0,0,9900000,false,'not_applicable','adequate','defer_payment','GST + TDS deposit bunching — statutory deadline 20th'),
    ('EquipSeva Treasury','2026-08-07',2,'loan_emi',
     1250000,1250000,0,0,8650000,false,'not_applicable','adequate','on_plan','Term-loan EMI auto-debit on due date'),
    ('EquipSeva Treasury','2026-08-07',2,'closing_balance',
     8650000,5450000,-3200000,-37.00,5450000,true,'not_applicable','breach_risk','arrange_facility','Week 2 close breaches 6.0M min buffer on project slip'),
    ('EquipSeva Treasury','2026-08-14',3,'capex',
     4200000,4200000,0,0,1250000,true,'not_applicable','critical','escalate','Calibration-lab capex collides with low buffer — escalate to board'),
    ('KIMS Hyderabad','2026-08-14',3,'collections_projects',
     6100000,0,-6100000,-100.00,1250000,true,'low','critical','arrange_facility','Large project collection at risk — arrange OD facility to bridge')
  ) as q(cparty, wend, wnum, cline, fc, ac, varr, varp, runbal, buffer, conf, liq, verdict, nt);

  -- CAPA seed — attach to at-risk lines via (cash_line, week_ending)
  insert into public.treasury_cash_flow_capa_actions_r3421 (
    cash_flow_id, finding_category, root_cause, corrective_action,
    capa_status, facility_impact, target_closure_date, actual_closure_date,
    estimated_impact_rupees, notes
  )
  select e.id, q.fc_cat, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.impact, q.nt
  from (values
    ('collections_spares','2026-07-31','collection_shortfall','disputed_invoice','escalate_to_customer','in_progress','internal_only','2026-08-05',null,550000,'Disputed GST line — commercial team escalating to Fortis AP'),
    ('collections_projects','2026-08-07','collection_delay','project_milestone_slip','accelerate_collections','open','board_escalation','2026-08-12',null,2100000,'Milestone sign-off chase — PM to close acceptance certificate'),
    ('closing_balance','2026-08-07','buffer_breach','customer_payment_delay','draw_working_capital_line','escalated','od_utilization_high','2026-08-08',null,3200000,'Week-2 close under 6.0M buffer — WC line draw prepared'),
    ('capex','2026-08-14','capex_overrun','large_capex_timing','reschedule_capex','open','board_escalation','2026-08-13',null,4200000,'Calibration-lab capex clashes with low buffer — propose 3-week defer'),
    ('collections_projects','2026-08-14','collection_shortfall','project_milestone_slip','arrange_od_facility','escalated','covenant_breach_risk','2026-08-13',null,6100000,'KIMS project collection at risk — OD facility arrangement in progress'),
    ('statutory_taxes','2026-08-07','statutory_deadline','tax_outflow_bunching','reforecast_week','closed','internal_only','2026-08-06','2026-08-06',3400000,'GST+TDS bunching reforecast into week 2 — funded and filed'),
    ('collections_amc','2026-07-31','collection_delay','customer_payment_delay','accelerate_collections','closed','none','2026-08-02','2026-08-01',250000,'Apollo AMC invoice cleared at T+3 — closed')
  ) as q(cline, wend, fc_cat, rc, ca, cst, fi, tcd, acd, impact, nt)
  join public.treasury_cash_flow_r3421 e
    on e.organization_id = v_org_id and e.cash_line = q.cline and e.week_ending = q.wend::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Cash verdict distribution
create or replace function public.founder_r3421_cash_verdict_rollup()
returns table(cash_verdict text, lines bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.treasury_cash_flow_r3421)
  select l.cash_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.treasury_cash_flow_r3421 l
  group by l.cash_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3421_cash_verdict_rollup() from public, anon;
grant execute on function public.founder_r3421_cash_verdict_rollup() to authenticated;

-- 2) Per-week scorecard
create or replace function public.founder_r3421_week_scorecard()
returns table(
  week_ending date,
  week_number integer,
  lines bigint,
  on_plan bigint,
  needs_action bigint,
  buffer_breaches bigint,
  total_forecast_rupees numeric,
  total_actual_rupees numeric,
  min_running_balance_rupees numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.week_ending, l.week_number,
    count(*)::bigint,
    count(*) filter (where l.cash_verdict = 'on_plan')::bigint,
    count(*) filter (where l.cash_verdict in ('collection_action','defer_payment','arrange_facility','escalate'))::bigint,
    count(*) filter (where l.min_buffer_breach = true)::bigint,
    coalesce(sum(l.forecast_amount_rupees),0)::numeric,
    coalesce(sum(l.actual_amount_rupees),0)::numeric,
    min(l.running_balance_rupees)
  from public.treasury_cash_flow_r3421 l
  group by l.week_ending, l.week_number
  order by l.week_ending;
end;
$$;

revoke execute on function public.founder_r3421_week_scorecard() from public, anon;
grant execute on function public.founder_r3421_week_scorecard() to authenticated;

-- 3) Cash-line × liquidity-status matrix
create or replace function public.founder_r3421_cash_line_liquidity_matrix()
returns table(cash_line text, liquidity_status text, lines bigint, on_plan bigint, needs_action bigint, avg_variance_pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.cash_line, l.liquidity_status, count(*)::bigint,
    count(*) filter (where l.cash_verdict = 'on_plan')::bigint,
    count(*) filter (where l.cash_verdict in ('collection_action','defer_payment','arrange_facility','escalate'))::bigint,
    round(avg(l.variance_pct), 2)
  from public.treasury_cash_flow_r3421 l
  group by l.cash_line, l.liquidity_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3421_cash_line_liquidity_matrix() from public, anon;
grant execute on function public.founder_r3421_cash_line_liquidity_matrix() to authenticated;

-- 4) Weekly liquidity trend
create or replace function public.founder_r3421_weekly_liquidity_trend()
returns table(week_ending date, week_number integer, lines bigint, buffer_breaches bigint, needs_action bigint, min_running_balance_rupees numeric, total_variance_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.week_ending, l.week_number,
    count(*)::bigint,
    count(*) filter (where l.min_buffer_breach = true)::bigint,
    count(*) filter (where l.cash_verdict in ('collection_action','defer_payment','arrange_facility','escalate'))::bigint,
    min(l.running_balance_rupees),
    coalesce(sum(l.variance_rupees),0)::numeric
  from public.treasury_cash_flow_r3421 l
  group by l.week_ending, l.week_number
  order by l.week_ending;
end;
$$;

revoke execute on function public.founder_r3421_weekly_liquidity_trend() from public, anon;
grant execute on function public.founder_r3421_weekly_liquidity_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3421_capa_status_board()
returns table(capa_status text, findings bigint, avg_impact_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_impact_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.treasury_cash_flow_capa_actions_r3421 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3421_capa_status_board() from public, anon;
grant execute on function public.founder_r3421_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3421_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_impact_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.treasury_cash_flow_capa_actions_r3421)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.treasury_cash_flow_capa_actions_r3421 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3421_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3421_root_cause_pareto() to authenticated;

-- 7) Facility-impact digest
create or replace function public.founder_r3421_facility_impact_digest()
returns table(facility_impact text, findings bigint, open_findings bigint, total_impact_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.facility_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_impact_rupees),0)::numeric
  from public.treasury_cash_flow_capa_actions_r3421 c
  group by c.facility_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3421_facility_impact_digest() from public, anon;
grant execute on function public.founder_r3421_facility_impact_digest() to authenticated;

-- 8) High-risk liquidity queue (top individual concerns)
create or replace function public.founder_r3421_high_risk_queue()
returns table(
  counterparty_name text,
  week_ending date,
  week_number integer,
  cash_line text,
  forecast_amount_rupees numeric,
  actual_amount_rupees numeric,
  variance_rupees numeric,
  liquidity_status text,
  cash_verdict text,
  collection_confidence text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.counterparty_name, l.week_ending, l.week_number, l.cash_line,
    l.forecast_amount_rupees, l.actual_amount_rupees, l.variance_rupees,
    l.liquidity_status, l.cash_verdict, l.collection_confidence, l.notes
  from public.treasury_cash_flow_r3421 l
  where l.liquidity_status in ('tight','breach_risk','critical')
     or l.min_buffer_breach = true
     or l.cash_verdict in ('collection_action','defer_payment','arrange_facility','escalate')
     or l.collection_confidence = 'low'
  order by l.week_ending, l.counterparty_name;
end;
$$;

revoke execute on function public.founder_r3421_high_risk_queue() from public, anon;
grant execute on function public.founder_r3421_high_risk_queue() to authenticated;
