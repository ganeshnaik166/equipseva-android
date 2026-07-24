-- Round 3397: Founder Month-End Financial-Close & MIS-Reporting Timeliness Board
-- Close governance — close area × period × planned vs actual close day × reconciliation × open items × data quality × MIS delivery lag × sign-off × CAPA

-- =============================================================================
-- TABLE 1: month_end_close_r3397 — per close-area/period records
-- =============================================================================
create table if not exists public.month_end_close_r3397 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  close_area text not null check (close_area in (
    'revenue_recognition','accounts_payable','accounts_receivable','bank_reconciliation',
    'fixed_assets','payroll','inventory','gst_reconciliation','mis_pack'
  )),
  period_month text not null,
  owner text not null,
  planned_close_day int not null,
  actual_close_day int not null,
  close_status text not null check (close_status in (
    'not_started','in_progress','completed','reopened'
  )),
  on_time boolean not null,
  journal_entries_count int not null,
  reconciliation_complete boolean not null,
  open_items_count int not null,
  data_quality_issues int not null,
  mis_pack_delivered boolean not null,
  mis_delivery_lag_days numeric(5,1),
  sign_off_obtained boolean not null,
  materiality_variance_flag boolean not null,
  close_verdict text not null check (close_verdict in (
    'clean_on_time','late','rework','data_quality_gap','escalate'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.month_end_close_r3397 enable row level security;

create index if not exists idx_month_end_close_r3397_org on public.month_end_close_r3397(organization_id);
create index if not exists idx_month_end_close_r3397_verdict on public.month_end_close_r3397(close_verdict);

-- =============================================================================
-- TABLE 2: month_end_close_capa_actions_r3397 — CAPA & remediation actions
-- =============================================================================
create table if not exists public.month_end_close_capa_actions_r3397 (
  id uuid primary key default gen_random_uuid(),
  close_log_id uuid not null references public.month_end_close_r3397(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'close_delay','reconciliation_incomplete','high_open_items','data_quality_issue',
    'mis_delivery_late','sign_off_pending','materiality_variance','process_reopened'
  )),
  root_cause text not null check (root_cause in (
    'dependency_delay','manual_process','system_data_gap','resource_constraint',
    'late_source_data','approval_bottleneck','reconciliation_backlog','pending_investigation','control_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'automate_journal','fix_data_source','add_resource','tighten_cutoff',
    'clear_reconciliation_backlog','streamline_approval','strengthen_control','update_close_calendar','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  financial_impact text not null check (financial_impact in (
    'high','moderate','low','none','audit_risk','decision_delay'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.month_end_close_capa_actions_r3397 enable row level security;

create index if not exists idx_month_end_close_capa_r3397_log on public.month_end_close_capa_actions_r3397(close_log_id);
create index if not exists idx_month_end_close_capa_r3397_status on public.month_end_close_capa_actions_r3397(capa_status);

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

  insert into public.month_end_close_r3397 (
    organization_id, close_area, period_month, owner, planned_close_day, actual_close_day,
    close_status, on_time, journal_entries_count, reconciliation_complete, open_items_count,
    data_quality_issues, mis_pack_delivered, mis_delivery_lag_days, sign_off_obtained,
    materiality_variance_flag, close_verdict, notes
  )
  select v_org_id, q.area, q.period, q.owner, q.planned::int, q.actual::int,
    q.status, q.ontime, q.je::int, q.recon, q.openitems::int,
    q.dq::int, q.mispack, q.mislag, q.signoff,
    q.matvar, q.cv, q.nt
  from (values
    ('revenue_recognition','2026-06','Meera Krishnan',4,4,'completed',true,42,true,0,0,true,0.0,true,false,'clean_on_time','Revenue recognition closed on WD4 clean'),
    ('accounts_payable','2026-06','Rohit Sharma',3,3,'completed',true,68,true,2,0,true,0.0,true,false,'clean_on_time','AP closed on time, 2 minor open items carried'),
    ('accounts_receivable','2026-06','Rohit Sharma',3,5,'completed',false,55,true,8,1,true,2.0,true,false,'late','AR closed 2 days late — reconciliation backlog'),
    ('bank_reconciliation','2026-06','Priya Nair',2,2,'completed',true,30,true,0,0,true,0.0,true,false,'clean_on_time','Bank recon clean on WD2'),
    ('fixed_assets','2026-06','Meera Krishnan',5,5,'completed',true,18,true,1,0,true,0.0,true,false,'clean_on_time','Fixed assets closed on time'),
    ('payroll','2026-06','Anjali Gupta',2,2,'completed',true,24,true,0,0,true,0.0,true,false,'clean_on_time','Payroll close clean'),
    ('inventory','2026-06','Karthik Reddy',4,7,'completed',false,36,false,22,4,true,3.0,false,true,'data_quality_gap','Inventory close late with data-quality issues and materiality variance'),
    ('gst_reconciliation','2026-06','Rohit Sharma',6,9,'reopened',false,40,false,15,3,false,5.0,false,false,'rework','GST recon reopened — ITC mismatch data gap'),
    ('mis_pack','2026-06','Meera Krishnan',7,10,'completed',false,0,true,0,2,true,3.0,true,false,'late','MIS pack delivered 3 days late due to upstream AR/GST delays'),
    ('revenue_recognition','2026-05','Meera Krishnan',4,4,'completed',true,44,true,0,0,true,0.0,true,false,'clean_on_time','May revenue recognition clean'),
    ('accounts_receivable','2026-05','Rohit Sharma',3,4,'completed',false,52,true,6,0,true,1.0,true,false,'late','May AR one day late'),
    ('inventory','2026-05','Karthik Reddy',4,5,'completed',false,34,true,9,1,true,1.0,true,false,'late','May inventory slightly late — improving trend'),
    ('gst_reconciliation','2026-05','Rohit Sharma',6,6,'completed',true,38,true,3,0,true,0.0,true,false,'clean_on_time','May GST recon on time'),
    ('mis_pack','2026-05','Meera Krishnan',7,8,'completed',false,0,true,0,1,true,1.0,true,false,'late','May MIS pack one day late')
  ) as q(area, period, owner, planned, actual, status, ontime, je, recon, openitems, dq, mispack, mislag, signoff, matvar, cv, nt);

  insert into public.month_end_close_capa_actions_r3397 (
    close_log_id, finding_category, root_cause, corrective_action,
    capa_status, financial_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.fi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('gst_reconciliation','2026-06','process_reopened','system_data_gap','fix_data_source','in_progress','audit_risk','2026-08-05',null,15000.00,'GST ITC data integration fix to prevent reopen'),
    ('inventory','2026-06','data_quality_issue','manual_process','automate_journal','open','decision_delay','2026-08-10',null,25000.00,'Inventory data-quality automation to cut manual errors'),
    ('accounts_receivable','2026-06','reconciliation_incomplete','reconciliation_backlog','clear_reconciliation_backlog','verification_pending','moderate','2026-08-03',null,0.00,'AR recon backlog cleared — verify next close'),
    ('mis_pack','2026-06','mis_delivery_late','dependency_delay','update_close_calendar','open','decision_delay','2026-08-06',null,0.00,'Rework close calendar so MIS pack is buffered from AR/GST delays'),
    ('inventory','2026-06','materiality_variance','control_gap','strengthen_control','escalated','audit_risk','2026-08-01',null,0.00,'Inventory materiality variance — strengthen cut-off controls'),
    ('accounts_receivable','2026-05','close_delay','resource_constraint','add_resource','closed','low','2026-06-20','2026-06-18',0.00,'Added AR resource for month-end — May slip resolved'),
    ('gst_reconciliation','2026-06','sign_off_pending','approval_bottleneck','streamline_approval','overdue','moderate','2026-07-28',null,0.00,'GST sign-off approval streamlining past target')
  ) as q(area, period, fc, rc, ca, cst, fi, tcd, acd, cost, nt)
  join public.month_end_close_r3397 e
    on e.organization_id = v_org_id and e.close_area = q.area and e.period_month = q.period;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

create or replace function public.founder_r3397_close_verdict_rollup()
returns table(close_verdict text, records bigint, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.month_end_close_r3397)
  select l.close_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.month_end_close_r3397 l group by l.close_verdict order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3397_close_verdict_rollup() from public, anon;
grant execute on function public.founder_r3397_close_verdict_rollup() to authenticated;

create or replace function public.founder_r3397_area_scorecard()
returns table(
  close_area text, records bigint, on_time_count bigint, late_count bigint, rework_count bigint,
  avg_close_day numeric, total_open_items bigint, total_data_quality_issues bigint, on_time_pct numeric
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.close_area, count(*)::bigint,
    count(*) filter (where l.on_time = true)::bigint,
    count(*) filter (where l.close_verdict = 'late')::bigint,
    count(*) filter (where l.close_verdict in ('rework','data_quality_gap'))::bigint,
    round(avg(l.actual_close_day), 1),
    coalesce(sum(l.open_items_count),0)::bigint,
    coalesce(sum(l.data_quality_issues),0)::bigint,
    round(100.0 * count(*) filter (where l.on_time = true)::numeric / nullif(count(*),0), 1)
  from public.month_end_close_r3397 l group by l.close_area order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3397_area_scorecard() from public, anon;
grant execute on function public.founder_r3397_area_scorecard() to authenticated;

create or replace function public.founder_r3397_period_area_matrix()
returns table(period_month text, close_area text, planned_close_day int, actual_close_day int, on_time boolean, open_items_count int)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, l.close_area, l.planned_close_day, l.actual_close_day, l.on_time, l.open_items_count
  from public.month_end_close_r3397 l order by l.period_month desc, l.close_area;
end;
$$;
revoke execute on function public.founder_r3397_period_area_matrix() from public, anon;
grant execute on function public.founder_r3397_period_area_matrix() to authenticated;

create or replace function public.founder_r3397_period_timeliness_trend()
returns table(period_month text, areas bigint, on_time bigint, late bigint, avg_mis_lag_days numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month, count(*)::bigint,
    count(*) filter (where l.on_time = true)::bigint,
    count(*) filter (where l.on_time = false)::bigint,
    round(avg(l.mis_delivery_lag_days), 1)
  from public.month_end_close_r3397 l group by l.period_month order by l.period_month desc;
end;
$$;
revoke execute on function public.founder_r3397_period_timeliness_trend() from public, anon;
grant execute on function public.founder_r3397_period_timeliness_trend() to authenticated;

create or replace function public.founder_r3397_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.month_end_close_capa_actions_r3397 c group by c.capa_status order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3397_capa_status_board() from public, anon;
grant execute on function public.founder_r3397_capa_status_board() to authenticated;

create or replace function public.founder_r3397_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.month_end_close_capa_actions_r3397)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.month_end_close_capa_actions_r3397 c group by c.root_cause order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3397_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3397_root_cause_pareto() to authenticated;

create or replace function public.founder_r3397_financial_impact_digest()
returns table(financial_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.financial_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.month_end_close_capa_actions_r3397 c group by c.financial_impact order by count(*) desc;
end;
$$;
revoke execute on function public.founder_r3397_financial_impact_digest() from public, anon;
grant execute on function public.founder_r3397_financial_impact_digest() to authenticated;

create or replace function public.founder_r3397_high_risk_queue()
returns table(
  close_area text, period_month text, owner text, planned_close_day int, actual_close_day int,
  close_status text, open_items_count int, data_quality_issues int, close_verdict text, notes text
)
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.close_area, l.period_month, l.owner, l.planned_close_day, l.actual_close_day,
    l.close_status, l.open_items_count, l.data_quality_issues, l.close_verdict, l.notes
  from public.month_end_close_r3397 l
  where l.close_verdict in ('late','rework','data_quality_gap','escalate')
     or l.on_time = false
     or l.reconciliation_complete = false
     or l.sign_off_obtained = false
     or l.materiality_variance_flag = true
     or l.close_status = 'reopened'
  order by l.period_month desc, l.actual_close_day desc;
end;
$$;
revoke execute on function public.founder_r3397_high_risk_queue() from public, anon;
grant execute on function public.founder_r3397_high_risk_queue() to authenticated;
