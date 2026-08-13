-- Round 3746: Founder Statutory Bonus / Ex-Gratia Payment Compliance Board
-- Statutory bonus (Payment of Bonus Act) and ex-gratia payment compliance per eligible
-- employee category -- eligibility, bonus % vs statutory min/max, payment timeliness,
-- allocable-surplus basis. Distinct from any general payroll-run board, any PF/ESI
-- compliance board, and any incentive/commission-payout board, which are separate schemes.

-- =============================================================================
-- TABLE 1: stat_bonus_r3746 -- per-category statutory bonus / ex-gratia facts
-- =============================================================================
create table if not exists public.stat_bonus_r3746 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_category text not null,
  location text not null,
  period_month date not null,
  eligible_employees int not null,
  bonus_pct_applied numeric,
  statutory_min_pct numeric,
  statutory_max_pct numeric,
  bonus_amount_rupees numeric(12,2),
  payment_due_date date,
  payment_made_date date,
  days_late int,
  allocable_surplus_basis boolean not null,
  bonus_class text not null check (bonus_class in (
    'minimum_statutory','allocable_surplus_based','ex_gratia_discretionary','productivity_linked','festival_bonus'
  )),
  compliance_status text not null check (compliance_status in (
    'paid_on_time','paid_late','underpaid_risk','pending','disputed'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.stat_bonus_r3746 enable row level security;

create index if not exists idx_stat_bonus_r3746_org on public.stat_bonus_r3746(organization_id);
create index if not exists idx_stat_bonus_r3746_month on public.stat_bonus_r3746(period_month);
create index if not exists idx_stat_bonus_r3746_status on public.stat_bonus_r3746(compliance_status);

-- =============================================================================
-- TABLE 2: stat_bonus_capa_actions_r3746 -- CAPA for compliance gaps
-- =============================================================================
create table if not exists public.stat_bonus_capa_actions_r3746 (
  id uuid primary key default gen_random_uuid(),
  bonus_id uuid references public.stat_bonus_r3746(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.stat_bonus_capa_actions_r3746 enable row level security;

create index if not exists idx_stat_bonus_capa_r3746_main on public.stat_bonus_capa_actions_r3746(bonus_id);
create index if not exists idx_stat_bonus_capa_r3746_status on public.stat_bonus_capa_actions_r3746(capa_status);

-- =============================================================================
-- RPCs -- 8 founder-gated rollups
-- =============================================================================

-- 1) Compliance-status distribution
create or replace function public.founder_r3746_compliance_status_rollup()
returns table(compliance_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.stat_bonus_r3746)
  select l.compliance_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.stat_bonus_r3746 l
  group by l.compliance_status
  order by count(*) desc;
end;
$$;

-- 2) Employee-category scorecard
create or replace function public.founder_r3746_employee_category_scorecard()
returns table(
  employee_category text,
  records bigint,
  eligible_employees_total bigint,
  paid_on_time bigint,
  paid_late bigint,
  underpaid_risk bigint,
  pending bigint,
  disputed bigint,
  bonus_amount_total numeric,
  avg_bonus_pct_applied numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_category,
    count(*)::bigint,
    coalesce(sum(l.eligible_employees), 0)::bigint,
    count(*) filter (where l.compliance_status = 'paid_on_time')::bigint,
    count(*) filter (where l.compliance_status = 'paid_late')::bigint,
    count(*) filter (where l.compliance_status = 'underpaid_risk')::bigint,
    count(*) filter (where l.compliance_status = 'pending')::bigint,
    count(*) filter (where l.compliance_status = 'disputed')::bigint,
    coalesce(sum(l.bonus_amount_rupees), 0)::numeric,
    round(avg(l.bonus_pct_applied), 2)
  from public.stat_bonus_r3746 l
  group by l.employee_category
  order by count(*) desc;
end;
$$;

-- 3) Bonus-class x compliance-status matrix
create or replace function public.founder_r3746_bonus_class_status_matrix()
returns table(bonus_class text, compliance_status text, records bigint, avg_bonus_amount_rupees numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.bonus_class, l.compliance_status, count(*)::bigint,
    round(avg(l.bonus_amount_rupees), 2)
  from public.stat_bonus_r3746 l
  group by l.bonus_class, l.compliance_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly payment trend
create or replace function public.founder_r3746_monthly_payment_trend()
returns table(
  period_month date,
  records bigint,
  bonus_amount_total numeric,
  avg_days_late numeric,
  paid_on_time bigint,
  paid_late bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.bonus_amount_rupees), 0)::numeric,
    round(avg(l.days_late), 1),
    count(*) filter (where l.compliance_status = 'paid_on_time')::bigint,
    count(*) filter (where l.compliance_status = 'paid_late')::bigint
  from public.stat_bonus_r3746 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3746_capa_status_board()
returns table(capa_status text, findings bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.stat_bonus_capa_actions_r3746 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3746_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.stat_bonus_capa_actions_r3746)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot), 0) * 100.0, 1)
  from public.stat_bonus_capa_actions_r3746 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Underpayment-risk digest (bonus % applied below statutory minimum)
create or replace function public.founder_r3746_underpayment_digest()
returns table(
  employee_category text,
  records bigint,
  underpaid_risk_records bigint,
  avg_bonus_pct_applied numeric,
  avg_statutory_min_pct numeric,
  bonus_amount_total numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_category,
    count(*)::bigint,
    count(*) filter (where l.compliance_status = 'underpaid_risk')::bigint,
    round(avg(l.bonus_pct_applied), 2),
    round(avg(l.statutory_min_pct), 2),
    coalesce(sum(l.bonus_amount_rupees), 0)::numeric
  from public.stat_bonus_r3746 l
  where l.compliance_status = 'underpaid_risk'
     or l.bonus_pct_applied < l.statutory_min_pct
  group by l.employee_category
  order by count(*) desc;
end;
$$;

-- 8) High-risk payment queue (underpaid / disputed / pending, worst first)
create or replace function public.founder_r3746_high_risk_queue()
returns table(
  employee_category text,
  location text,
  period_month date,
  bonus_class text,
  compliance_status text,
  payment_due_date date,
  days_late int,
  bonus_amount_rupees numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.employee_category, l.location, l.period_month, l.bonus_class,
    l.compliance_status, l.payment_due_date, l.days_late, l.bonus_amount_rupees,
    l.notes
  from public.stat_bonus_r3746 l
  where l.compliance_status in ('underpaid_risk','disputed','pending')
  order by l.days_late desc nulls last, l.period_month desc
  limit 20;
end;
$$;

-- =============================================================================
-- Grants -- founder-gated, authenticated-only surface
-- =============================================================================
revoke all on function public.founder_r3746_compliance_status_rollup() from public, anon;
revoke all on function public.founder_r3746_employee_category_scorecard() from public, anon;
revoke all on function public.founder_r3746_bonus_class_status_matrix() from public, anon;
revoke all on function public.founder_r3746_monthly_payment_trend() from public, anon;
revoke all on function public.founder_r3746_capa_status_board() from public, anon;
revoke all on function public.founder_r3746_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3746_underpayment_digest() from public, anon;
revoke all on function public.founder_r3746_high_risk_queue() from public, anon;

grant execute on function public.founder_r3746_compliance_status_rollup() to authenticated;
grant execute on function public.founder_r3746_employee_category_scorecard() to authenticated;
grant execute on function public.founder_r3746_bonus_class_status_matrix() to authenticated;
grant execute on function public.founder_r3746_monthly_payment_trend() to authenticated;
grant execute on function public.founder_r3746_capa_status_board() to authenticated;
grant execute on function public.founder_r3746_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3746_underpayment_digest() to authenticated;
grant execute on function public.founder_r3746_high_risk_queue() to authenticated;

-- =============================================================================
-- SEED DATA -- reference first organization only
-- =============================================================================
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from public.organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  -- 16 statutory-bonus / ex-gratia rows across categories, locations, classes & months
  insert into public.stat_bonus_r3746 (
    organization_id, employee_category, location, period_month, eligible_employees,
    bonus_pct_applied, statutory_min_pct, statutory_max_pct, bonus_amount_rupees,
    payment_due_date, payment_made_date, days_late, allocable_surplus_basis,
    bonus_class, compliance_status, trend_dir, notes
  )
  select v_org_id, q.ec, q.loc, q.pm::date, q.ee,
    q.bpa, q.smn, q.smx, q.bar,
    q.pdd::date, q.pmd::date, q.dl, q.asb,
    q.bc, q.cs, q.td, q.nt
  from (values
    ('warehouse_staff','Bengaluru','2026-04-01',85,8.33,8.33,20.0,354025.00,'2026-11-30','2026-11-25',0,false,'minimum_statutory','paid_on_time','stable','Statutory minimum 8.33% applied and paid five days ahead of deadline'),
    ('field_technicians','Mumbai','2026-04-01',62,10.5,8.33,20.0,325920.00,'2026-11-30','2026-12-10',10,true,'allocable_surplus_based','paid_late','worsening','Allocable surplus computation delayed by finance close, payment slipped 10 days'),
    ('drivers','Delhi','2026-04-01',48,8.33,8.33,20.0,159834.00,'2026-11-30','2026-11-28',0,false,'minimum_statutory','paid_on_time','stable','Straightforward minimum-slab payout, no surplus computation required'),
    ('back_office_staff','Chennai','2026-04-01',34,15.0,8.33,20.0,204000.00,'2026-11-30',null,0,true,'allocable_surplus_based','pending','stable','Surplus statement awaiting board sign-off before disbursal'),
    ('supervisors','Pune','2026-04-01',22,6.0,8.33,20.0,79200.00,'2026-11-30','2026-11-30',0,false,'minimum_statutory','underpaid_risk','worsening','Applied 6% is below statutory floor of 8.33% -- correction required'),
    ('warehouse_staff','Hyderabad','2026-04-01',56,8.33,8.33,20.0,233240.00,'2026-11-30','2026-11-29',0,false,'minimum_statutory','paid_on_time','improving','Consistent on-time statutory payout for third year running'),
    ('sales_executives','Kolkata','2026-04-01',29,0.0,0.0,0.0,145000.00,'2026-10-15','2026-10-12',0,true,'ex_gratia_discretionary','paid_on_time','stable','Discretionary ex-gratia at management approval, no statutory floor applies'),
    ('field_technicians','Ahmedabad','2026-04-01',41,12.0,8.33,20.0,196800.00,'2026-11-30','2026-12-05',5,true,'allocable_surplus_based','paid_late','worsening','Regional finance sign-off delayed disbursal by five days past deadline'),
    ('production_staff','Bengaluru','2026-03-01',73,18.5,8.33,20.0,540250.00,'2026-10-31','2026-10-20',0,true,'productivity_linked','paid_on_time','improving','Strong output metrics drove near-ceiling productivity-linked payout'),
    ('drivers','Mumbai','2026-03-01',39,20.0,8.33,20.0,187200.00,'2026-10-31','2026-10-25',0,true,'allocable_surplus_based','paid_on_time','stable','Statutory maximum 20% slab paid on time per surplus availability'),
    ('back_office_staff','Delhi','2026-03-01',27,8.33,8.33,20.0,89964.00,'2026-10-31',null,0,false,'minimum_statutory','disputed','worsening','Employee union disputes eligible-employee count used in computation'),
    ('field_technicians','Chennai','2026-03-01',33,7.5,8.33,20.0,89100.00,'2026-10-31','2026-11-08',8,false,'minimum_statutory','underpaid_risk','worsening','Applied 7.5% below statutory floor and paid eight days late -- double gap'),
    ('warehouse_staff','Pune','2026-03-01',48,8.33,8.33,20.0,159936.00,'2026-10-31','2026-10-28',0,false,'minimum_statutory','paid_on_time','stable','No exceptions this cycle'),
    ('supervisors','Hyderabad','2026-05-01',18,25000.0,0.0,0.0,450000.00,'2026-11-05','2026-11-04',0,true,'festival_bonus','paid_on_time','stable','Fixed festival bonus of Rs 25,000 per eligible supervisor for Diwali'),
    ('sales_executives','Kolkata','2026-05-01',31,0.0,0.0,0.0,186000.00,'2026-11-05',null,0,true,'festival_bonus','pending','worsening','Festival bonus approval pending finance committee review'),
    ('production_staff','Ahmedabad','2026-05-01',65,16.0,8.33,20.0,416000.00,'2026-11-30','2026-11-27',0,true,'productivity_linked','paid_on_time','improving','Above-average production yield sustained a healthy payout rate')
  ) as q(ec, loc, pm, ee, bpa, smn, smx, bar, pdd, pmd, dl, asb, bc, cs, td, nt);

  -- 8 CAPA rows -- attach to bonus rows via employee_category + location + period_month
  insert into public.stat_bonus_capa_actions_r3746 (
    bonus_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('field_technicians','Mumbai','2026-04-01','Allocable surplus computation delayed by finance close cycle','Move surplus computation to a fixed pre-close checklist item two weeks before payout deadline','in_progress','Payroll Compliance Lead','2026-12-15',null,'Checklist draft prepared; finance team review scheduled next week'),
    ('supervisors','Pune','2026-04-01','Bonus percentage applied fell below the statutory minimum of 8.33 percent','Recompute and issue arrears payment to bring payout up to statutory floor','open','Payroll Compliance Lead','2026-12-05',null,'Arrears calculation in progress, approval pending from finance controller'),
    ('field_technicians','Ahmedabad','2026-04-01','Regional finance sign-off delayed disbursal past the statutory deadline','Delegate regional sign-off authority to branch finance head to remove single point of delay','closed','HR Shared Services Head','2026-12-10','2026-12-06','Delegation approved and implemented; next cycle disbursed on time'),
    ('back_office_staff','Delhi','2026-03-01','Employee union disputes the eligible-employee headcount used for the bonus computation','Conduct joint headcount reconciliation with union representative and finance','in_progress','IR & Compliance Manager','2026-12-20',null,'Joint reconciliation meeting scheduled; historical attendance records being compiled'),
    ('field_technicians','Chennai','2026-03-01','Bonus percentage below statutory floor combined with a late payment breach','Issue immediate arrears correction and escalate late-payment root cause to regional payroll head','overdue','Payroll Compliance Lead','2026-11-20',null,'SLA breached by three weeks; arrears computation stuck awaiting data from regional office'),
    ('sales_executives','Kolkata','2026-05-01','Festival bonus approval pending with finance committee beyond planned date','Pre-approve festival bonus budget annually ahead of festival season to avoid ad-hoc committee delay','open','Total Rewards Manager','2026-12-01',null,'Proposal for annual pre-approval drafted, awaiting CFO sign-off'),
    ('back_office_staff','Chennai','2026-04-01','Surplus statement awaiting board sign-off is holding up scheduled disbursal','Request expedited board circular resolution to approve surplus statement out of cycle','in_progress','Company Secretary','2026-12-12',null,'Circular resolution draft circulated to board members for signature'),
    ('drivers','Delhi','2026-04-01','No gaps identified, but category flagged for preventive documentation review','Archive computation worksheet and payout evidence for statutory audit trail','closed','Payroll Compliance Lead','2026-11-15','2026-11-10','Documentation archived; audit trail complete for the cycle')
  ) as q(ec, loc, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.stat_bonus_r3746 e
    on e.organization_id = v_org_id and e.employee_category = q.ec and e.location = q.loc and e.period_month = q.pm::date;
end;
$seed$;
