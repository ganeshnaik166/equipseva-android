-- Round 3701: Founder Database Slow-Query / Index-Health Board
-- DB internals health — slow queries × p95 latency × seq scans × unused/missing indexes × bloat × connections × lock waits × autovacuum lag × CAPA

-- =============================================================================
-- TABLE 1: db_health_r3701 — per schema-area / table-group monthly DB health snapshots
-- =============================================================================
create table if not exists public.db_health_r3701 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  snapshot_code text not null,
  schema_area text not null,
  table_group text not null,
  period_month date not null,
  slow_queries int not null,
  p95_query_ms numeric(8,1),
  seq_scans_heavy int not null,
  unused_indexes int not null,
  missing_index_candidates int not null,
  table_bloat_pct numeric(5,2),
  connections_peak int not null,
  connection_limit int not null,
  lock_waits int not null,
  autovacuum_lag_hours numeric(6,1),
  area_class text not null check (area_class in (
    'marketplace_core','payments_ledger','notifications_queue','analytics_rollups','auth_identity'
  )),
  db_status text not null check (db_status in (
    'healthy','tuning_due','index_gap','bloat_heavy','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.db_health_r3701 enable row level security;

create index if not exists idx_db_health_r3701_org on public.db_health_r3701(organization_id);
create index if not exists idx_db_health_r3701_month on public.db_health_r3701(period_month);
create index if not exists idx_db_health_r3701_status on public.db_health_r3701(db_status);

-- =============================================================================
-- TABLE 2: db_health_capa_actions_r3701 — DB tuning CAPA & remediation actions
-- =============================================================================
create table if not exists public.db_health_capa_actions_r3701 (
  id uuid primary key default gen_random_uuid(),
  db_row_id uuid not null references public.db_health_r3701(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'slow_query_regression','index_gap','table_bloat','connection_saturation',
    'lock_contention','autovacuum_lag','seq_scan_hotspot'
  )),
  root_cause text not null check (root_cause in (
    'missing_composite_index','unbounded_query_pattern','stale_statistics',
    'autovacuum_starvation','hot_update_bloat','connection_pool_misconfig',
    'orm_n_plus_one','long_running_transaction','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_composite_index','drop_unused_index','rewrite_query','tune_autovacuum',
    'run_pg_repack','resize_connection_pool','add_statement_timeout',
    'batch_backfill_rework','analyze_refresh_stats','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  est_query_ms_saved numeric(10,1),
  owner_team text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.db_health_capa_actions_r3701 enable row level security;

create index if not exists idx_db_health_capa_r3701_row on public.db_health_capa_actions_r3701(db_row_id);
create index if not exists idx_db_health_capa_r3701_status on public.db_health_capa_actions_r3701(capa_status);

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

  -- 16 DB health snapshot rows
  insert into public.db_health_r3701 (
    organization_id, snapshot_code, schema_area, table_group, period_month,
    slow_queries, p95_query_ms, seq_scans_heavy, unused_indexes, missing_index_candidates,
    table_bloat_pct, connections_peak, connection_limit, lock_waits, autovacuum_lag_hours,
    area_class, db_status, trend_dir, notes
  )
  select v_org_id, q.scode, q.sarea, q.tgrp, q.pmon::date,
    q.slowq, q.p95, q.seqs, q.unidx, q.misidx,
    q.bloat, q.connp, q.connl, q.lockw, q.avlag,
    q.aclass, q.dstat, q.tdir, q.nt
  from (values
    ('DBH-2607-MKT-01','marketplace','jobs_bids','2026-07-01',
     42,412.5,6,2,3,18.40,145,200,12,4.5,'marketplace_core','tuning_due','stable','Bid listing query p95 creeping; composite index candidate on (job_id,status)'),
    ('DBH-2607-MKT-02','marketplace','providers_equipment','2026-07-01',
     11,138.2,1,4,1,9.20,145,200,3,2.0,'marketplace_core','index_gap','improving','Four unused indexes on equipment search; drop candidates listed'),
    ('DBH-2607-PAY-01','payments','ledger_entries','2026-07-01',
     67,890.0,9,1,4,31.60,178,200,28,11.5,'payments_ledger','critical','worsening','Ledger scan p95 near 900ms; lock waits from settlement batch overlap'),
    ('DBH-2607-PAY-02','payments','payout_batches','2026-07-01',
     18,240.8,2,0,1,22.90,178,200,9,6.0,'payments_ledger','bloat_heavy','stable','Payout batch table 22.9 pct bloat from hot updates; pg_repack window needed'),
    ('DBH-2607-NTF-01','notifications','push_queue','2026-07-01',
     24,196.4,3,2,2,26.30,110,200,5,9.8,'notifications_queue','bloat_heavy','worsening','Push queue churn bloat; autovacuum lagging 9.8h behind'),
    ('DBH-2607-NTF-02','notifications','email_outbox','2026-07-01',
     7,88.1,0,1,0,12.10,110,200,1,3.2,'notifications_queue','healthy','stable','Email outbox nominal after June partition rollout'),
    ('DBH-2607-ANL-01','analytics','rollup_daily','2026-07-01',
     31,624.7,7,0,5,15.70,92,200,4,5.4,'analytics_rollups','index_gap','worsening','Five missing-index candidates on rollup joins; seq scans heavy'),
    ('DBH-2607-AUT-01','auth','users_sessions','2026-07-01',
     9,74.9,1,1,1,8.80,131,200,2,1.6,'auth_identity','healthy','improving','Session lookups healthy post index rebuild'),
    ('DBH-2607-AUT-02','auth','kyc_documents','2026-07-01',
     14,178.3,2,0,2,10.50,131,200,6,2.8,'auth_identity','tuning_due','stable','KYC doc fetch needs partial index on status where pending'),
    ('DBH-2606-MKT-01','marketplace','jobs_bids','2026-06-01',
     36,371.0,5,2,3,16.90,138,200,10,4.1,'marketplace_core','tuning_due','stable','June baseline; bid feed query already flagged'),
    ('DBH-2606-PAY-01','payments','ledger_entries','2026-06-01',
     52,702.3,8,1,3,27.40,169,200,21,8.9,'payments_ledger','critical','worsening','Ledger degradation began mid-June after backfill job'),
    ('DBH-2606-NTF-01','notifications','push_queue','2026-06-01',
     19,171.9,2,2,2,21.00,104,200,4,7.1,'notifications_queue','bloat_heavy','stable','Queue bloat steady; vacuum cost limits too conservative'),
    ('DBH-2606-ANL-01','analytics','event_stream','2026-06-01',
     44,533.6,6,3,4,14.20,92,200,7,6.7,'analytics_rollups','index_gap','worsening','Event stream BRIN candidate; three unused btrees'),
    ('DBH-2606-AUT-01','auth','users_sessions','2026-06-01',
     12,96.5,1,1,1,9.40,126,200,3,2.2,'auth_identity','healthy','stable','Auth area steady through June'),
    ('DBH-2605-MKT-01','marketplace','jobs_bids','2026-05-01',
     29,318.8,4,2,2,15.10,120,200,8,3.6,'marketplace_core','tuning_due','improving','May snapshot pre new-bid-flow load'),
    ('DBH-2605-PAY-01','payments','ledger_entries','2026-05-01',
     38,551.2,6,1,2,24.80,151,200,14,7.5,'payments_ledger','bloat_heavy','stable','May ledger snapshot; bloat before repack attempt')
  ) as q(scode, sarea, tgrp, pmon, slowq, p95, seqs, unidx, misidx, bloat, connp, connl, lockw, avlag, aclass, dstat, tdir, nt);

  -- CAPA seed — attach to specific snapshots via snapshot_code
  insert into public.db_health_capa_actions_r3701 (
    db_row_id, finding_category, root_cause, corrective_action,
    capa_status, est_query_ms_saved, owner_team,
    target_closure_date, actual_closure_date, notes
  )
  select e.id, q.fc, q.rc, q.ca,
    q.cst, q.msave, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('DBH-2607-PAY-01','slow_query_regression','long_running_transaction','add_statement_timeout','escalated',420.0,'backend','2026-07-18',null,'Settlement batch holds locks; statement_timeout plus batch split in review'),
    ('DBH-2607-PAY-02','table_bloat','hot_update_bloat','run_pg_repack','in_progress',0.0,'platform_dba','2026-07-20',null,'pg_repack window booked for Sunday 02:00 IST'),
    ('DBH-2607-NTF-01','autovacuum_lag','autovacuum_starvation','tune_autovacuum','open',60.0,'platform_dba','2026-07-22',null,'Raise autovacuum_vacuum_cost_limit for push_queue'),
    ('DBH-2607-ANL-01','index_gap','missing_composite_index','add_composite_index','verification_pending',380.5,'backend','2026-07-15',null,'Composite index built on rollup joins; verifying plan flips'),
    ('DBH-2607-MKT-01','slow_query_regression','orm_n_plus_one','rewrite_query','in_progress',210.0,'android','2026-07-19',null,'Bid feed N+1 collapsed to single RPC; release pending'),
    ('DBH-2607-MKT-02','index_gap','stale_statistics','drop_unused_index','closed',0.0,'platform_dba','2026-07-10','2026-07-08','Four unused equipment-search indexes dropped after analyze'),
    ('DBH-2606-PAY-01','lock_contention','unbounded_query_pattern','batch_backfill_rework','closed',480.0,'backend','2026-06-30','2026-06-28','Backfill rewritten to keyset batches of 5k rows'),
    ('DBH-2607-AUT-02','slow_query_regression','missing_composite_index','add_composite_index','overdue',95.0,'web','2026-07-05',null,'Partial index on kyc_documents status pending — past target date')
  ) as q(scode, fc, rc, ca, cst, msave, ownr, tcd, acd, nt)
  join public.db_health_r3701 e
    on e.organization_id = v_org_id and e.snapshot_code = q.scode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) DB status distribution
create or replace function public.founder_r3701_db_status_rollup()
returns table(db_status text, snapshots bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.db_health_r3701)
  select l.db_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.db_health_r3701 l
  group by l.db_status
  order by count(*) desc;
end;
$$;

-- 2) Schema-area scorecard
create or replace function public.founder_r3701_schema_area_scorecard()
returns table(
  schema_area text,
  snapshots bigint,
  healthy bigint,
  tuning_due bigint,
  index_gap bigint,
  critical_or_bloat bigint,
  total_slow_queries bigint,
  avg_p95_ms numeric,
  avg_bloat_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.schema_area,
    count(*)::bigint,
    count(*) filter (where l.db_status = 'healthy')::bigint,
    count(*) filter (where l.db_status = 'tuning_due')::bigint,
    count(*) filter (where l.db_status = 'index_gap')::bigint,
    count(*) filter (where l.db_status in ('critical','bloat_heavy'))::bigint,
    coalesce(sum(l.slow_queries),0)::bigint,
    round(avg(l.p95_query_ms), 1),
    round(avg(l.table_bloat_pct), 1)
  from public.db_health_r3701 l
  group by l.schema_area
  order by count(*) desc;
end;
$$;

-- 3) Area-class × DB-status matrix
create or replace function public.founder_r3701_area_class_status_matrix()
returns table(area_class text, db_status text, snapshots bigint, total_slow_queries bigint, avg_bloat_pct numeric, total_lock_waits bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.area_class, l.db_status, count(*)::bigint,
    coalesce(sum(l.slow_queries),0)::bigint,
    round(avg(l.table_bloat_pct), 1),
    coalesce(sum(l.lock_waits),0)::bigint
  from public.db_health_r3701 l
  group by l.area_class, l.db_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly slow-query trend
create or replace function public.founder_r3701_monthly_slow_query_trend()
returns table(period_month date, snapshots bigint, total_slow_queries bigint, avg_p95_ms numeric, total_lock_waits bigint, worsening_areas bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    coalesce(sum(l.slow_queries),0)::bigint,
    round(avg(l.p95_query_ms), 1),
    coalesce(sum(l.lock_waits),0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.db_health_r3701 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3701_capa_status_board()
returns table(capa_status text, findings bigint, avg_ms_saved numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.est_query_ms_saved)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.db_health_capa_actions_r3701 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3701_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_ms_saved numeric, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.db_health_capa_actions_r3701)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.est_query_ms_saved),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.db_health_capa_actions_r3701 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Index-gap digest
create or replace function public.founder_r3701_index_gap_digest()
returns table(table_group text, schema_area text, snapshots bigint, total_unused_indexes bigint, total_missing_candidates bigint, total_seq_scans_heavy bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.table_group, l.schema_area, count(*)::bigint,
    coalesce(sum(l.unused_indexes),0)::bigint,
    coalesce(sum(l.missing_index_candidates),0)::bigint,
    coalesce(sum(l.seq_scans_heavy),0)::bigint
  from public.db_health_r3701 l
  group by l.table_group, l.schema_area
  order by coalesce(sum(l.missing_index_candidates),0) desc, coalesce(sum(l.unused_indexes),0) desc;
end;
$$;

-- 8) High-risk queue (critical / bloat-heavy / worsening snapshots)
create or replace function public.founder_r3701_high_risk_queue()
returns table(
  snapshot_code text,
  schema_area text,
  table_group text,
  period_month date,
  db_status text,
  trend_dir text,
  slow_queries int,
  p95_query_ms numeric,
  table_bloat_pct numeric,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.snapshot_code, l.schema_area, l.table_group, l.period_month,
    l.db_status, l.trend_dir, l.slow_queries, l.p95_query_ms, l.table_bloat_pct, l.notes
  from public.db_health_r3701 l
  where l.db_status in ('critical','bloat_heavy')
     or l.trend_dir = 'worsening'
     or l.table_bloat_pct > 25
     or l.lock_waits >= 20
  order by l.period_month desc, l.schema_area;
end;
$$;

-- =============================================================================
-- GRANTS
-- =============================================================================
revoke all on function public.founder_r3701_db_status_rollup() from public, anon;
revoke all on function public.founder_r3701_schema_area_scorecard() from public, anon;
revoke all on function public.founder_r3701_area_class_status_matrix() from public, anon;
revoke all on function public.founder_r3701_monthly_slow_query_trend() from public, anon;
revoke all on function public.founder_r3701_capa_status_board() from public, anon;
revoke all on function public.founder_r3701_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3701_index_gap_digest() from public, anon;
revoke all on function public.founder_r3701_high_risk_queue() from public, anon;

grant execute on function public.founder_r3701_db_status_rollup() to authenticated;
grant execute on function public.founder_r3701_schema_area_scorecard() to authenticated;
grant execute on function public.founder_r3701_area_class_status_matrix() to authenticated;
grant execute on function public.founder_r3701_monthly_slow_query_trend() to authenticated;
grant execute on function public.founder_r3701_capa_status_board() to authenticated;
grant execute on function public.founder_r3701_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3701_index_gap_digest() to authenticated;
grant execute on function public.founder_r3701_high_risk_queue() to authenticated;
