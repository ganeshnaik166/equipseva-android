-- Round 3750: Founder Trade Union / Collective-Bargaining Agreement Board
-- Trade union recognition & CBA compliance — union × site × period × CBA validity × wage-settlement
-- compliance × grievance-committee meetings × strike/lockout risk indicators × CAPA

-- =============================================================================
-- TABLE 1: trade_union_r3750 — per-union / per-site CBA compliance facts
-- =============================================================================
create table if not exists public.trade_union_r3750 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  union_name text not null,
  site_name text not null,
  period_month date not null,
  members_count int,
  cba_start_date date,
  cba_end_date date,
  days_to_cba_expiry int,
  wage_settlement_compliant boolean not null,
  grievances_raised int,
  grievances_resolved int,
  works_committee_meetings_held int,
  strike_notice_issued boolean not null,
  union_class text not null check (union_class in (
    'recognized_majority_union','minority_union','works_committee','federation_affiliated','unrecognized_pending'
  )),
  cba_status text not null check (cba_status in (
    'active_compliant','negotiation_in_progress','expired_pending_renewal','dispute_escalated','strike_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trade_union_r3750 enable row level security;

create index if not exists idx_trade_union_r3750_org on public.trade_union_r3750(organization_id);
create index if not exists idx_trade_union_r3750_month on public.trade_union_r3750(period_month);
create index if not exists idx_trade_union_r3750_status on public.trade_union_r3750(cba_status);

-- =============================================================================
-- TABLE 2: trade_union_capa_actions_r3750 — CAPA & IR-remediation actions
-- =============================================================================
create table if not exists public.trade_union_capa_actions_r3750 (
  id uuid primary key default gen_random_uuid(),
  trade_union_id uuid references public.trade_union_r3750(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.trade_union_capa_actions_r3750 enable row level security;

create index if not exists idx_trade_union_capa_r3750_union on public.trade_union_capa_actions_r3750(trade_union_id);
create index if not exists idx_trade_union_capa_r3750_status on public.trade_union_capa_actions_r3750(capa_status);

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

  -- 16 trade-union / CBA rows
  insert into public.trade_union_r3750 (
    organization_id, union_name, site_name, period_month,
    members_count, cba_start_date, cba_end_date, days_to_cba_expiry,
    wage_settlement_compliant, grievances_raised, grievances_resolved,
    works_committee_meetings_held, strike_notice_issued,
    union_class, cba_status, trend_dir, notes
  )
  select v_org_id, q.unm, q.site, q.pm::date,
    q.mem, q.cbs::date, q.cbe::date, q.dte,
    q.wsc, q.graised, q.gres,
    q.wcm, q.sni,
    q.uc, q.cst, q.trd, q.nt
  from (values
    ('Equipment Operators Union','Pune Depot','2026-07-01',
     342,'2025-04-01','2027-03-31',236,
     true,6,6,
     2,false,
     'recognized_majority_union','active_compliant','stable','Wage settlement current through FY27 — no open grievances'),
    ('Field Technicians Sangh','Chennai Yard','2026-07-01',
     198,'2024-01-01','2026-08-31',18,
     true,9,7,
     1,false,
     'recognized_majority_union','negotiation_in_progress','worsening','CBA renewal talks ongoing — only 18 days to expiry, 2 grievances open'),
    ('Warehouse Workers Federation','Bhiwandi Warehouse','2026-06-01',
     265,'2023-09-01','2026-08-31',61,
     true,4,4,
     2,false,
     'recognized_majority_union','active_compliant','stable','Committee meetings on schedule — all grievances closed'),
    ('Logistics Staff Association','Mumbai HQ','2026-07-01',
     120,'2025-10-01','2027-09-30',420,
     true,2,2,
     2,false,
     'minority_union','active_compliant','stable','Minority union recognised for supervisory cadre — cordial relations'),
    ('Transport Workers Union','Delhi NCR Yard','2026-05-01',
     410,'2022-06-01','2026-05-31',0,
     false,14,6,
     0,true,
     'recognized_majority_union','strike_risk','worsening','CBA lapsed unrenewed — strike notice served over wage arrears'),
    ('Crane Operators Guild','Kolkata Port','2026-06-01',
     87,'2024-02-01','2026-07-31',30,
     true,3,3,
     1,false,
     'minority_union','negotiation_in_progress','stable','Wage revision talks in final round ahead of July expiry'),
    ('Site Works Committee','Hyderabad Depot','2026-07-01',
     54,null,null,null,
     true,1,1,
     3,false,
     'works_committee','active_compliant','improving','No formal union — works committee handling grievances well'),
    ('Heavy Vehicle Drivers Union','Ahmedabad Yard','2026-06-01',
     176,'2023-01-01','2026-06-30',0,
     false,11,4,
     0,true,
     'recognized_majority_union','dispute_escalated','worsening','CBA expired at month end — dispute referred to labour commissioner'),
    ('Maintenance Staff Sangathan','Bengaluru Depot','2026-07-01',
     143,'2025-01-01','2027-12-31',511,
     true,5,5,
     2,false,
     'federation_affiliated','active_compliant','stable','Affiliated to state federation — settlement fully implemented'),
    ('Contract Labour Front','Nagpur Site','2026-05-01',
     92,null,null,null,
     false,8,3,
     0,false,
     'unrecognized_pending','negotiation_in_progress','worsening','Recognition application pending with labour department 90+ days'),
    ('Yard Operators Collective','Vizag Port','2026-07-01',
     134,'2025-06-01','2027-05-31',290,
     true,3,3,
     2,false,
     'recognized_majority_union','active_compliant','improving','Grievance backlog cleared after new HR-IR liaison appointed'),
    ('Equipment Operators Union','Pune Depot','2026-05-01',
     338,'2025-04-01','2027-03-31',297,
     true,7,5,
     2,false,
     'recognized_majority_union','active_compliant','stable','Two grievances rolled to next cycle — no escalation'),
    ('Federation of Transport Employees','Jaipur Depot','2026-06-01',
     221,'2024-07-01','2026-06-30',0,
     false,10,2,
     1,true,
     'federation_affiliated','strike_risk','worsening','Federation-backed strike notice issued after CBA lapse'),
    ('Field Technicians Sangh','Chennai Yard','2026-05-01',
     195,'2024-01-01','2026-08-31',110,
     true,5,5,
     1,false,
     'recognized_majority_union','active_compliant','stable','Baseline month before renewal cycle opened'),
    ('Loader Operators Union','Indore Warehouse','2026-06-01',
     76,'2023-05-01','2026-04-30',-45,
     false,9,3,
     0,true,
     'minority_union','expired_pending_renewal','worsening','CBA overdue 45 days — renewal talks stalled, notice pending withdrawal'),
    ('Security Staff Works Committee','Lucknow Depot','2026-07-01',
     41,null,null,null,
     true,0,0,
     2,false,
     'works_committee','active_compliant','improving','Small-site committee — zero grievances this quarter')
  ) as q(unm, site, pm, mem, cbs, cbe, dte, wsc, graised, gres, wcm, sni, uc, cst, trd, nt);

  -- CAPA seed — attach to specific union+site rows via join
  insert into public.trade_union_capa_actions_r3750 (
    trade_union_id, root_cause, corrective_action, capa_status,
    owner, target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('Transport Workers Union','Delhi NCR Yard','2026-05-01','CBA renewal negotiations not initiated in time','Convene tripartite settlement talks with conciliation officer','overdue',
     'IR Manager','2026-06-15',null,'Strike notice active — urgent settlement meeting overdue by 2 months'),
    ('Heavy Vehicle Drivers Union','Ahmedabad Yard','2026-06-01','Wage revision proposal delayed by management','File counter-proposal and refer dispute for conciliation','in_progress',
     'HR-IR Head','2026-08-20',null,'Labour commissioner hearing scheduled — counter-proposal under legal review'),
    ('Federation of Transport Employees','Jaipur Depot','2026-06-01','Federation escalated after unilateral wage freeze','Restore interim wage relief pending settlement signature','open',
     'Plant HR Head','2026-08-25',null,'Federation demanding interim relief before withdrawing strike notice'),
    ('Loader Operators Union','Indore Warehouse','2026-06-01','CBA renewal stalled over recognition dispute','Re-verify membership count and re-open renewal talks','in_progress',
     'IR Manager','2026-08-18',null,'Membership verification underway to resolve recognition ambiguity'),
    ('Contract Labour Front','Nagpur Site','2026-05-01','Recognition application pending beyond statutory timeline','Follow up with labour department for recognition order','open',
     'HR-IR Head','2026-09-05',null,'Escalating to regional labour office for pending recognition decision'),
    ('Field Technicians Sangh','Chennai Yard','2026-07-01','Grievance resolution backlog ahead of CBA expiry','Clear pending grievances before renewal round concludes','in_progress',
     'Site HR Manager','2026-08-30',null,'2 of 9 grievances still open — targeting closure before signing'),
    ('Crane Operators Guild','Kolkata Port','2026-06-01','Wage revision benchmarking delayed by data gaps','Complete market wage benchmarking and finalise offer','closed',
     'Compensation Lead','2026-07-20','2026-07-18','Benchmarking completed early — settlement signed ahead of schedule'),
    ('Equipment Operators Union','Pune Depot','2026-07-01','Works committee meeting cadence slipping in Q2','Reinstate monthly works-committee meeting calendar','closed',
     'Site HR Manager','2026-07-10','2026-07-05','Meeting cadence restored — two consecutive months on schedule')
  ) as q(unm, site, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.trade_union_r3750 e
    on e.organization_id = v_org_id and e.union_name = q.unm and e.site_name = q.site and e.period_month = q.pm::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) CBA-status distribution
create or replace function public.founder_r3750_cba_status_rollup()
returns table(cba_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trade_union_r3750)
  select l.cba_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.trade_union_r3750 l
  group by l.cba_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3750_cba_status_rollup() from public, anon;
grant execute on function public.founder_r3750_cba_status_rollup() to authenticated;

-- 2) Union scorecard
create or replace function public.founder_r3750_union_scorecard()
returns table(
  union_name text,
  entries bigint,
  total_members bigint,
  wage_compliant_entries bigint,
  strike_notices bigint,
  total_grievances_raised bigint,
  total_grievances_resolved bigint,
  avg_committee_meetings numeric,
  min_days_to_cba_expiry int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.union_name,
    count(*)::bigint,
    coalesce(sum(l.members_count),0)::bigint,
    count(*) filter (where l.wage_settlement_compliant = true)::bigint,
    count(*) filter (where l.strike_notice_issued = true)::bigint,
    coalesce(sum(l.grievances_raised),0)::bigint,
    coalesce(sum(l.grievances_resolved),0)::bigint,
    round(avg(l.works_committee_meetings_held), 1),
    min(l.days_to_cba_expiry)
  from public.trade_union_r3750 l
  group by l.union_name
  order by min(l.days_to_cba_expiry) asc nulls last;
end;
$$;

revoke all on function public.founder_r3750_union_scorecard() from public, anon;
grant execute on function public.founder_r3750_union_scorecard() to authenticated;

-- 3) Union-class x CBA-status matrix
create or replace function public.founder_r3750_union_class_status_matrix()
returns table(union_class text, cba_status text, entries bigint, avg_members numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.union_class, l.cba_status, count(*)::bigint,
    round(avg(l.members_count), 1)
  from public.trade_union_r3750 l
  group by l.union_class, l.cba_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3750_union_class_status_matrix() from public, anon;
grant execute on function public.founder_r3750_union_class_status_matrix() to authenticated;

-- 4) Monthly grievance trend
create or replace function public.founder_r3750_monthly_grievance_trend()
returns table(
  period_month date,
  entries bigint,
  grievances_raised bigint,
  grievances_resolved bigint,
  strike_notices bigint,
  worsening_entries bigint
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
    coalesce(sum(l.grievances_raised),0)::bigint,
    coalesce(sum(l.grievances_resolved),0)::bigint,
    count(*) filter (where l.strike_notice_issued = true)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.trade_union_r3750 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3750_monthly_grievance_trend() from public, anon;
grant execute on function public.founder_r3750_monthly_grievance_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3750_capa_status_board()
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
  from public.trade_union_capa_actions_r3750 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3750_capa_status_board() from public, anon;
grant execute on function public.founder_r3750_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3750_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.trade_union_capa_actions_r3750)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.trade_union_capa_actions_r3750 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3750_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3750_root_cause_pareto() to authenticated;

-- 7) Dispute digest — sites with active strike/lockout risk indicators
create or replace function public.founder_r3750_dispute_digest()
returns table(
  site_name text,
  unions_at_risk bigint,
  strike_notices bigint,
  wage_noncompliant bigint,
  open_grievances bigint,
  min_days_to_cba_expiry int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.site_name,
    count(*)::bigint,
    count(*) filter (where l.strike_notice_issued = true)::bigint,
    count(*) filter (where l.wage_settlement_compliant = false)::bigint,
    coalesce(sum(l.grievances_raised - l.grievances_resolved),0)::bigint,
    min(l.days_to_cba_expiry)
  from public.trade_union_r3750 l
  where l.cba_status in ('dispute_escalated','strike_risk','expired_pending_renewal')
     or l.strike_notice_issued = true
  group by l.site_name
  order by count(*) filter (where l.strike_notice_issued = true) desc, min(l.days_to_cba_expiry) asc nulls last;
end;
$$;

revoke all on function public.founder_r3750_dispute_digest() from public, anon;
grant execute on function public.founder_r3750_dispute_digest() to authenticated;

-- 8) High-risk queue — dispute/strike-risk/expired CBA row detail
create or replace function public.founder_r3750_high_risk_queue()
returns table(
  union_name text,
  site_name text,
  period_month date,
  cba_status text,
  union_class text,
  days_to_cba_expiry int,
  strike_notice_issued boolean,
  wage_settlement_compliant boolean,
  grievances_raised int,
  grievances_resolved int,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.union_name, l.site_name, l.period_month, l.cba_status, l.union_class,
    l.days_to_cba_expiry, l.strike_notice_issued, l.wage_settlement_compliant,
    l.grievances_raised, l.grievances_resolved, l.notes
  from public.trade_union_r3750 l
  where l.cba_status in ('dispute_escalated','strike_risk','expired_pending_renewal')
  order by l.strike_notice_issued desc, l.days_to_cba_expiry asc nulls last
  limit 20;
end;
$$;

revoke all on function public.founder_r3750_high_risk_queue() from public, anon;
grant execute on function public.founder_r3750_high_risk_queue() to authenticated;
