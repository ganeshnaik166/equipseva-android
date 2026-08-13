-- Round 3727: Founder Data-Center / Server Infrastructure Uptime & Capacity Board
-- Internal server/hosting infrastructure uptime, capacity headroom, and incident count per
-- service/environment/month. Distinct from any DB slow-query/index-health page, which is
-- query-level database performance, not infra-level uptime/capacity.

-- =============================================================================
-- TABLE 1: infra_uptime_r3727 — per-service/environment/month infra uptime & capacity facts
-- =============================================================================
create table if not exists public.infra_uptime_r3727 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  service_name text not null,
  environment text not null,
  period_month date not null,
  uptime_pct numeric,
  planned_downtime_minutes int,
  unplanned_downtime_minutes int,
  incidents_count int,
  cpu_utilization_avg_pct numeric,
  memory_utilization_avg_pct numeric,
  disk_utilization_pct numeric,
  capacity_headroom_pct numeric,
  autoscale_enabled boolean not null,
  service_class text not null check (service_class in (
    'api_backend','database','cache_queue','cdn_static','background_jobs'
  )),
  infra_status text not null check (infra_status in (
    'healthy','watch','capacity_risk','degraded','critical_incident'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infra_uptime_r3727 enable row level security;

create index if not exists idx_infra_uptime_r3727_org on public.infra_uptime_r3727(organization_id);
create index if not exists idx_infra_uptime_r3727_month on public.infra_uptime_r3727(period_month);
create index if not exists idx_infra_uptime_r3727_status on public.infra_uptime_r3727(infra_status);

-- =============================================================================
-- TABLE 2: infra_uptime_capa_actions_r3727 — CAPA & remediation actions for infra risks
-- =============================================================================
create table if not exists public.infra_uptime_capa_actions_r3727 (
  id uuid primary key default gen_random_uuid(),
  infra_uptime_id uuid references public.infra_uptime_r3727(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.infra_uptime_capa_actions_r3727 enable row level security;

create index if not exists idx_infra_uptime_capa_r3727_ref on public.infra_uptime_capa_actions_r3727(infra_uptime_id);
create index if not exists idx_infra_uptime_capa_r3727_status on public.infra_uptime_capa_actions_r3727(capa_status);

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

  -- 16 infra uptime/capacity rows
  insert into public.infra_uptime_r3727 (
    organization_id, service_name, environment, period_month,
    uptime_pct, planned_downtime_minutes, unplanned_downtime_minutes, incidents_count,
    cpu_utilization_avg_pct, memory_utilization_avg_pct, disk_utilization_pct, capacity_headroom_pct,
    autoscale_enabled, service_class, infra_status, trend_dir, notes, created_at
  )
  select v_org_id, q.svc, q.env, q.pm::date,
    q.upct::numeric, q.pdm::int, q.udm::int, q.inc::int,
    q.cpu::numeric, q.mem::numeric, q.disk::numeric, q.head::numeric,
    q.asc_en, q.scls, q.ist, q.trd, q.nt, now()
  from (values
    ('api-gateway','production','2026-07-01',
     99.95,15,8,1,
     58.0,62.0,41.0,39.0,
     true,'api_backend','healthy','stable','Steady load — autoscale handled peak traffic without incident'),
    ('orders-api','production','2026-07-01',
     99.80,20,35,3,
     72.0,70.0,55.0,20.0,
     true,'api_backend','watch','worsening','CPU creeping up during evening peak — headroom tightening'),
    ('primary-postgres','production','2026-07-01',
     99.99,10,2,0,
     45.0,68.0,72.0,18.0,
     false,'database','capacity_risk','worsening','Disk utilization climbing fast — storage expansion planned'),
    ('redis-cache','production','2026-07-01',
     99.90,5,12,1,
     35.0,80.0,30.0,10.0,
     false,'cache_queue','capacity_risk','worsening','Memory near ceiling — eviction rate rising, needs resize'),
    ('cdn-edge','production','2026-07-01',
     99.99,0,3,0,
     20.0,25.0,15.0,75.0,
     true,'cdn_static','healthy','stable','CDN load well within capacity — no action needed'),
    ('job-worker-fleet','production','2026-07-01',
     98.50,30,90,5,
     85.0,75.0,60.0,8.0,
     true,'background_jobs','degraded','worsening','Queue backlog growing — worker pool undersized for batch spikes'),
    ('api-gateway','staging','2026-07-01',
     99.50,0,20,2,
     40.0,45.0,35.0,55.0,
     true,'api_backend','healthy','stable','Staging stable — used for pre-prod load tests this month'),
    ('orders-api','production','2026-06-01',
     97.20,25,180,8,
     78.0,74.0,58.0,15.0,
     true,'api_backend','critical_incident','worsening','Major outage mid-month due to connection pool exhaustion'),
    ('primary-postgres','production','2026-06-01',
     99.95,10,5,1,
     42.0,64.0,68.0,22.0,
     false,'database','watch','stable','Minor replication lag incident resolved within SLA'),
    ('redis-cache','production','2026-06-01',
     99.99,5,2,0,
     30.0,72.0,28.0,20.0,
     false,'cache_queue','healthy','improving','Right-sized last month — memory pressure has eased'),
    ('cdn-edge','production','2026-06-01',
     100.00,0,0,0,
     18.0,22.0,12.0,80.0,
     true,'cdn_static','healthy','stable','No incidents — traffic well below provisioned capacity'),
    ('job-worker-fleet','production','2026-06-01',
     99.10,15,50,3,
     70.0,65.0,52.0,25.0,
     true,'background_jobs','watch','improving','Added two workers mid-month — backlog clearing faster'),
    ('billing-service','production','2026-07-01',
     99.85,10,15,2,
     50.0,55.0,40.0,42.0,
     true,'api_backend','healthy','stable','Stable performance — billing runs completing on schedule'),
    ('reporting-db-replica','production','2026-07-01',
     99.60,20,40,2,
     55.0,60.0,63.0,28.0,
     false,'database','watch','stable','Read replica lag intermittent during nightly report jobs'),
    ('notifications-queue','production','2026-07-01',
     99.40,10,60,4,
     65.0,70.0,45.0,18.0,
     true,'cache_queue','capacity_risk','worsening','Queue depth spiking during campaign sends — headroom shrinking'),
    ('search-indexer','production','2026-07-01',
     98.90,15,70,3,
     80.0,78.0,66.0,12.0,
     true,'background_jobs','degraded','worsening','Reindex jobs taking longer — CPU and memory both under pressure')
  ) as q(svc, env, pm, upct, pdm, udm, inc, cpu, mem, disk, head, asc_en, scls, ist, trd, nt);

  -- CAPA seed — attach to specific infra rows via service_name + period_month
  insert into public.infra_uptime_capa_actions_r3727 (
    infra_uptime_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('orders-api','2026-06-01','Connection pool exhaustion under peak load','Increase pool size and add circuit breaker on downstream calls','closed','Platform Eng Lead','2026-06-25','2026-06-22','Pool resized and circuit breaker deployed — no recurrence since'),
    ('job-worker-fleet','2026-07-01','Worker pool undersized for batch spikes','Scale worker fleet and add priority queue for time-sensitive jobs','in_progress','SRE Lead','2026-08-20',null,'Autoscale rules updated — priority queue rollout in progress'),
    ('primary-postgres','2026-07-01','Disk utilization trending toward capacity limit','Provision additional storage and archive cold data','open','DBA Lead','2026-08-25',null,'Storage expansion ticket raised — archival job being scripted'),
    ('redis-cache','2026-07-01','Memory ceiling reached causing high eviction rate','Resize cache instance and implement key TTL cleanup','open','Platform Eng Lead','2026-08-22',null,'Resize scheduled for next maintenance window'),
    ('notifications-queue','2026-07-01','Queue depth spikes during campaign sends','Add consumer autoscaling tied to queue depth metric','in_progress','SRE Lead','2026-08-18',null,'Autoscaling policy drafted — testing against last campaign load'),
    ('search-indexer','2026-07-01','Reindex jobs exceeding CPU/memory budget','Split reindex into incremental batches and add off-peak scheduling','open','Search Platform Owner','2026-08-28',null,'Batch splitting design in review'),
    ('reporting-db-replica','2026-07-01','Replica lag during nightly report jobs','Stagger report jobs and add read-replica capacity','overdue','DBA Lead','2026-07-31',null,'Staggering partially deployed — additional replica pending budget approval'),
    ('orders-api','2026-07-01','CPU utilization trending up during evening peak','Profile hot endpoints and add caching layer for read-heavy calls','open','Platform Eng Lead','2026-08-30',null,'Profiling underway — top three endpoints identified for caching')
  ) as q(svc, pm, rc, ca, cst, ownr, tcd, acd, nt)
  join public.infra_uptime_r3727 e
    on e.organization_id = v_org_id and e.service_name = q.svc and e.period_month = q.pm::date;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Infra-status distribution
create or replace function public.founder_r3727_infra_status_rollup()
returns table(infra_status text, service_months bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infra_uptime_r3727)
  select l.infra_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.infra_uptime_r3727 l
  group by l.infra_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3727_infra_status_rollup() from public, anon;
grant execute on function public.founder_r3727_infra_status_rollup() to authenticated;

-- 2) Service-name scorecard
create or replace function public.founder_r3727_service_name_scorecard()
returns table(
  service_name text,
  service_months bigint,
  avg_uptime_pct numeric,
  total_incidents bigint,
  avg_cpu_utilization_avg_pct numeric,
  avg_memory_utilization_avg_pct numeric,
  avg_capacity_headroom_pct numeric,
  autoscale_enabled_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_name,
    count(*)::bigint,
    round(avg(l.uptime_pct), 2),
    coalesce(sum(l.incidents_count), 0)::bigint,
    round(avg(l.cpu_utilization_avg_pct), 1),
    round(avg(l.memory_utilization_avg_pct), 1),
    round(avg(l.capacity_headroom_pct), 1),
    count(*) filter (where l.autoscale_enabled = true)::bigint
  from public.infra_uptime_r3727 l
  group by l.service_name
  order by avg(l.uptime_pct) asc;
end;
$$;

revoke all on function public.founder_r3727_service_name_scorecard() from public, anon;
grant execute on function public.founder_r3727_service_name_scorecard() to authenticated;

-- 3) Service-class × infra-status matrix
create or replace function public.founder_r3727_service_class_status_matrix()
returns table(service_class text, infra_status text, service_months bigint, avg_capacity_headroom_pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_class, l.infra_status, count(*)::bigint,
    round(avg(l.capacity_headroom_pct), 1)
  from public.infra_uptime_r3727 l
  group by l.service_class, l.infra_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3727_service_class_status_matrix() from public, anon;
grant execute on function public.founder_r3727_service_class_status_matrix() to authenticated;

-- 4) Monthly uptime trend
create or replace function public.founder_r3727_monthly_uptime_trend()
returns table(
  period_month date,
  service_months bigint,
  avg_uptime_pct numeric,
  total_incidents bigint,
  total_unplanned_downtime_minutes bigint,
  worsening_services bigint
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
    round(avg(l.uptime_pct), 2),
    coalesce(sum(l.incidents_count), 0)::bigint,
    coalesce(sum(l.unplanned_downtime_minutes), 0)::bigint,
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.infra_uptime_r3727 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3727_monthly_uptime_trend() from public, anon;
grant execute on function public.founder_r3727_monthly_uptime_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3727_capa_status_board()
returns table(capa_status text, actions bigint, overdue_flag bigint)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    count(*) filter (where c.capa_status = 'overdue')::bigint
  from public.infra_uptime_capa_actions_r3727 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3727_capa_status_board() from public, anon;
grant execute on function public.founder_r3727_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3727_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.infra_uptime_capa_actions_r3727)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.infra_uptime_capa_actions_r3727 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3727_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3727_root_cause_pareto() to authenticated;

-- 7) Capacity-risk digest (services with shrinking headroom / capacity risk)
create or replace function public.founder_r3727_capacity_risk_digest()
returns table(
  service_class text,
  capacity_risk_services bigint,
  avg_capacity_headroom_pct numeric,
  avg_cpu_utilization_avg_pct numeric,
  avg_memory_utilization_avg_pct numeric,
  avg_disk_utilization_pct numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_class,
    count(*)::bigint,
    round(avg(l.capacity_headroom_pct), 1),
    round(avg(l.cpu_utilization_avg_pct), 1),
    round(avg(l.memory_utilization_avg_pct), 1),
    round(avg(l.disk_utilization_pct), 1)
  from public.infra_uptime_r3727 l
  where l.infra_status in ('capacity_risk','degraded','critical_incident')
  group by l.service_class
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3727_capacity_risk_digest() from public, anon;
grant execute on function public.founder_r3727_capacity_risk_digest() to authenticated;

-- 8) High-risk infra queue (degraded / critical-incident, row-level detail)
create or replace function public.founder_r3727_high_risk_queue()
returns table(
  service_name text,
  environment text,
  period_month date,
  service_class text,
  infra_status text,
  uptime_pct numeric,
  incidents_count int,
  capacity_headroom_pct numeric,
  autoscale_enabled boolean,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_name, l.environment, l.period_month, l.service_class, l.infra_status,
    l.uptime_pct, l.incidents_count, l.capacity_headroom_pct, l.autoscale_enabled, l.notes
  from public.infra_uptime_r3727 l
  where l.infra_status in ('degraded','critical_incident')
  order by l.uptime_pct asc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3727_high_risk_queue() from public, anon;
grant execute on function public.founder_r3727_high_risk_queue() to authenticated;
