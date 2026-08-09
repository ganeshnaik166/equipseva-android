-- Round 3696: Founder Platform API Latency / Error-Budget (SLO) Board
-- Platform reliability — service area × endpoint group × monthly latency percentiles × error rate × SLO target × error-budget remaining × burn rate × incidents × CAPA

-- =============================================================================
-- TABLE 1: api_slo_r3696 — per-endpoint-group monthly API latency / SLO entries
-- =============================================================================
create table if not exists public.api_slo_r3696 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  slo_ref text not null,
  service_area text not null,
  endpoint_group text not null,
  period_month date not null,
  requests_millions numeric(10,3),
  p50_latency_ms numeric(8,1),
  p95_latency_ms numeric(8,1),
  p99_latency_ms numeric(8,1),
  error_rate_pct numeric(6,3),
  slo_target_pct numeric(6,3),
  error_budget_remaining_pct numeric(6,1),
  budget_burn_rate numeric(6,2),
  incidents_linked int,
  service_class text not null check (service_class in (
    'auth','marketplace_rpc','payments','notifications','media_storage'
  )),
  slo_status text not null check (slo_status in (
    'within_slo','budget_healthy','budget_burning','budget_exhausted','slo_breached'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.api_slo_r3696 enable row level security;

create index if not exists idx_api_slo_r3696_org on public.api_slo_r3696(organization_id);
create index if not exists idx_api_slo_r3696_month on public.api_slo_r3696(period_month);
create index if not exists idx_api_slo_r3696_status on public.api_slo_r3696(slo_status);

-- =============================================================================
-- TABLE 2: api_slo_capa_actions_r3696 — CAPA & reliability remediation actions
-- =============================================================================
create table if not exists public.api_slo_capa_actions_r3696 (
  id uuid primary key default gen_random_uuid(),
  slo_entry_id uuid not null references public.api_slo_r3696(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'db_connection_pool_exhaustion','slow_query_regression','n_plus_one_rpc_pattern',
    'third_party_gateway_latency','cache_miss_storm','deployment_regression',
    'traffic_spike_unplanned','infra_capacity_shortfall','cold_start_overhead','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'add_db_index','optimize_query','increase_connection_pool','add_caching_layer',
    'rollback_release','scale_out_instances','tune_rate_limits','add_circuit_breaker',
    'vendor_escalation','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  error_budget_impact_pct numeric(6,1),
  owner text,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.api_slo_capa_actions_r3696 enable row level security;

create index if not exists idx_api_slo_capa_r3696_entry on public.api_slo_capa_actions_r3696(slo_entry_id);
create index if not exists idx_api_slo_capa_r3696_status on public.api_slo_capa_actions_r3696(capa_status);

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) SLO status distribution
create or replace function public.founder_r3696_slo_status_rollup()
returns table(slo_status text, entries bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.api_slo_r3696)
  select l.slo_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.api_slo_r3696 l
  group by l.slo_status
  order by count(*) desc;
end;
$$;

-- 2) Service-area reliability scorecard
create or replace function public.founder_r3696_service_area_scorecard()
returns table(
  service_area text,
  total_entries bigint,
  within_slo bigint,
  burning bigint,
  exhausted_or_breached bigint,
  avg_p95_ms numeric,
  avg_error_rate_pct numeric,
  avg_budget_remaining_pct numeric,
  incidents bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_area,
    count(*)::bigint,
    count(*) filter (where l.slo_status in ('within_slo','budget_healthy'))::bigint,
    count(*) filter (where l.slo_status = 'budget_burning')::bigint,
    count(*) filter (where l.slo_status in ('budget_exhausted','slo_breached'))::bigint,
    round(avg(l.p95_latency_ms), 1),
    round(avg(l.error_rate_pct), 3),
    round(avg(l.error_budget_remaining_pct), 1),
    coalesce(sum(l.incidents_linked),0)::bigint
  from public.api_slo_r3696 l
  group by l.service_area
  order by count(*) desc;
end;
$$;

-- 3) Service-class × SLO-status matrix
create or replace function public.founder_r3696_class_status_matrix()
returns table(service_class text, slo_status text, entries bigint, avg_p99_ms numeric, avg_burn_rate numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.service_class, l.slo_status, count(*)::bigint,
    round(avg(l.p99_latency_ms), 1),
    round(avg(l.budget_burn_rate), 2)
  from public.api_slo_r3696 l
  group by l.service_class, l.slo_status
  order by count(*) desc;
end;
$$;

-- 4) Monthly latency trend
create or replace function public.founder_r3696_monthly_latency_trend()
returns table(period_month date, entries bigint, avg_p50_ms numeric, avg_p95_ms numeric, avg_p99_ms numeric, avg_error_rate_pct numeric, breached bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.period_month,
    count(*)::bigint,
    round(avg(l.p50_latency_ms), 1),
    round(avg(l.p95_latency_ms), 1),
    round(avg(l.p99_latency_ms), 1),
    round(avg(l.error_rate_pct), 3),
    count(*) filter (where l.slo_status in ('budget_exhausted','slo_breached'))::bigint
  from public.api_slo_r3696 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

-- 5) CAPA status board
create or replace function public.founder_r3696_capa_status_board()
returns table(capa_status text, findings bigint, avg_budget_impact_pct numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.error_budget_impact_pct)::numeric, 1),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.api_slo_capa_actions_r3696 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

-- 6) Root-cause pareto
create or replace function public.founder_r3696_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_budget_impact_pct numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.api_slo_capa_actions_r3696)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.error_budget_impact_pct),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.api_slo_capa_actions_r3696 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

-- 7) Budget-burn digest (burn-rate bands)
create or replace function public.founder_r3696_budget_burn_digest()
returns table(burn_band text, entries bigint, avg_burn_rate numeric, avg_budget_remaining_pct numeric, exhausted_or_breached bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select case
      when l.budget_burn_rate >= 2.0 then 'critical_burn'
      when l.budget_burn_rate >= 1.0 then 'fast_burn'
      when l.budget_burn_rate >= 0.5 then 'moderate_burn'
      else 'slow_burn'
    end,
    count(*)::bigint,
    round(avg(l.budget_burn_rate), 2),
    round(avg(l.error_budget_remaining_pct), 1),
    count(*) filter (where l.slo_status in ('budget_exhausted','slo_breached'))::bigint
  from public.api_slo_r3696 l
  group by 1
  order by count(*) desc;
end;
$$;

-- 8) High-risk SLO queue
create or replace function public.founder_r3696_high_risk_queue()
returns table(
  service_area text,
  endpoint_group text,
  period_month date,
  p95_latency_ms numeric,
  p99_latency_ms numeric,
  error_rate_pct numeric,
  error_budget_remaining_pct numeric,
  budget_burn_rate numeric,
  slo_status text,
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
  select l.service_area, l.endpoint_group, l.period_month,
    l.p95_latency_ms, l.p99_latency_ms, l.error_rate_pct,
    l.error_budget_remaining_pct, l.budget_burn_rate,
    l.slo_status, l.trend_dir, l.notes
  from public.api_slo_r3696 l
  where l.slo_status in ('budget_exhausted','slo_breached')
     or l.budget_burn_rate >= 1.5
     or (l.slo_status = 'budget_burning' and l.trend_dir = 'worsening')
  order by l.period_month desc, l.budget_burn_rate desc;
end;
$$;

-- =============================================================================
-- Grants
-- =============================================================================
revoke all on function public.founder_r3696_slo_status_rollup() from public, anon;
revoke all on function public.founder_r3696_service_area_scorecard() from public, anon;
revoke all on function public.founder_r3696_class_status_matrix() from public, anon;
revoke all on function public.founder_r3696_monthly_latency_trend() from public, anon;
revoke all on function public.founder_r3696_capa_status_board() from public, anon;
revoke all on function public.founder_r3696_root_cause_pareto() from public, anon;
revoke all on function public.founder_r3696_budget_burn_digest() from public, anon;
revoke all on function public.founder_r3696_high_risk_queue() from public, anon;

grant execute on function public.founder_r3696_slo_status_rollup() to authenticated;
grant execute on function public.founder_r3696_service_area_scorecard() to authenticated;
grant execute on function public.founder_r3696_class_status_matrix() to authenticated;
grant execute on function public.founder_r3696_monthly_latency_trend() to authenticated;
grant execute on function public.founder_r3696_capa_status_board() to authenticated;
grant execute on function public.founder_r3696_root_cause_pareto() to authenticated;
grant execute on function public.founder_r3696_budget_burn_digest() to authenticated;
grant execute on function public.founder_r3696_high_risk_queue() to authenticated;

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

  -- 16 SLO entry rows
  insert into public.api_slo_r3696 (
    organization_id, slo_ref, service_area, endpoint_group, period_month,
    requests_millions, p50_latency_ms, p95_latency_ms, p99_latency_ms,
    error_rate_pct, slo_target_pct, error_budget_remaining_pct, budget_burn_rate,
    incidents_linked, service_class, slo_status, trend_dir, notes
  )
  select v_org_id, q.ref, q.sarea, q.egrp, q.pmon::date,
    q.reqm, q.p50v, q.p95v, q.p99v,
    q.errp, q.slot, q.ebud, q.burn,
    q.inc, q.sclass, q.sstat, q.tdir, q.nt
  from (values
    ('SLO-AUTH-LOGIN-2607','auth','login_otp_session','2026-07-01',
     4.210,88.0,240.0,410.0,0.062,99.900,74.0,0.42,0,'auth','within_slo','stable','OTP + session issuance well inside SLO all month'),
    ('SLO-AUTH-REFRESH-2607','auth','token_refresh','2026-07-01',
     9.640,41.0,120.0,205.0,0.031,99.950,81.0,0.35,0,'auth','budget_healthy','improving','Refresh path improved after connection-pool bump in 2.14.0'),
    ('SLO-MKT-SEARCH-2607','marketplace','listing_search_browse','2026-07-01',
     6.980,140.0,520.0,940.0,0.210,99.900,38.0,1.10,1,'marketplace_rpc','budget_burning','worsening','Search RPC p95 creeping up with catalog growth — index review open'),
    ('SLO-MKT-BID-2607','marketplace','bid_quote_rpcs','2026-07-01',
     1.870,110.0,360.0,650.0,0.084,99.900,66.0,0.55,0,'marketplace_rpc','budget_healthy','stable','Bid/quote RPC family nominal'),
    ('SLO-MKT-JOB-2607','marketplace','job_lifecycle_rpcs','2026-07-01',
     2.440,125.0,410.0,760.0,0.147,99.900,52.0,0.78,1,'marketplace_rpc','budget_healthy','stable','Job accept/complete RPCs steady; one brief spike on 12 Jul'),
    ('SLO-PAY-CHECKOUT-2607','payments','checkout_capture','2026-07-01',
     0.920,310.0,890.0,1650.0,0.640,99.950,0.0,2.60,3,'payments','slo_breached','worsening','Gateway latency pass-through breached SLO — vendor escalation running'),
    ('SLO-PAY-PAYOUT-2607','payments','payout_settlement','2026-07-01',
     0.310,280.0,720.0,1290.0,0.290,99.900,21.0,1.60,1,'payments','budget_burning','worsening','Settlement webhook retries burning budget fast'),
    ('SLO-PAY-REFUND-2607','payments','refund_processing','2026-07-01',
     0.084,260.0,610.0,1040.0,0.110,99.900,69.0,0.48,0,'payments','within_slo','stable','Refund path quiet month'),
    ('SLO-NOTIF-PUSH-2607','notifications','push_fcm_fanout','2026-07-01',
     12.350,65.0,190.0,340.0,0.470,99.500,8.0,1.90,2,'notifications','budget_exhausted','worsening','FCM fanout error budget exhausted after 18 Jul cache-miss storm'),
    ('SLO-NOTIF-SMSWA-2607','notifications','sms_whatsapp_dispatch','2026-07-01',
     3.720,150.0,430.0,780.0,0.180,99.500,61.0,0.62,0,'notifications','budget_healthy','stable','SMS/WA dispatch nominal; DLT throughput fine'),
    ('SLO-MEDIA-UPLOAD-2607','media','photo_kyc_upload','2026-07-01',
     1.560,420.0,1350.0,2400.0,0.350,99.500,44.0,0.95,1,'media_storage','budget_healthy','stable','Upload path heavy but within budget; large-file tail watched'),
    ('SLO-MEDIA-SERVE-2607','media','signed_url_serving','2026-07-01',
     8.910,55.0,160.0,300.0,0.052,99.900,77.0,0.38,0,'media_storage','within_slo','improving','Signed-URL serving improved with CDN cache tune'),
    ('SLO-AUTH-LOGIN-2606','auth','login_otp_session','2026-06-01',
     3.870,92.0,255.0,440.0,0.078,99.900,70.0,0.50,0,'auth','within_slo','stable','June baseline for OTP/session path'),
    ('SLO-MKT-SEARCH-2606','marketplace','listing_search_browse','2026-06-01',
     6.240,132.0,470.0,860.0,0.160,99.900,49.0,0.85,0,'marketplace_rpc','budget_healthy','worsening','June already showed search latency drift upward'),
    ('SLO-PAY-CHECKOUT-2606','payments','checkout_capture','2026-06-01',
     0.860,295.0,780.0,1420.0,0.380,99.950,18.0,1.70,2,'payments','budget_burning','worsening','Checkout burn accelerated late June — precursor to July breach'),
    ('SLO-NOTIF-PUSH-2606','notifications','push_fcm_fanout','2026-06-01',
     11.480,62.0,175.0,320.0,0.240,99.500,42.0,0.90,1,'notifications','budget_healthy','stable','June fanout healthy before July storm')
  ) as q(ref, sarea, egrp, pmon, reqm, p50v, p95v, p99v, errp, slot, ebud, burn, inc, sclass, sstat, tdir, nt);

  -- 8 CAPA rows — attach to specific SLO entries via slo_ref
  insert into public.api_slo_capa_actions_r3696 (
    slo_entry_id, root_cause, corrective_action, capa_status,
    error_budget_impact_pct, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.impct, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('SLO-PAY-CHECKOUT-2607','third_party_gateway_latency','vendor_escalation','escalated',
     100.0,'Payments Platform Lead','2026-08-14',null,'Gateway P1 open with vendor; capture path breached July SLO'),
    ('SLO-PAY-CHECKOUT-2607','db_connection_pool_exhaustion','increase_connection_pool','in_progress',
     35.0,'Payments Platform Lead','2026-08-10',null,'Pool saturation during gateway retries compounded latency'),
    ('SLO-NOTIF-PUSH-2607','cache_miss_storm','add_caching_layer','in_progress',
     92.0,'Notifications On-call','2026-08-12',null,'Device-token cache warming + jittered fanout being rolled out'),
    ('SLO-PAY-PAYOUT-2607','traffic_spike_unplanned','tune_rate_limits','verification_pending',
     54.0,'Payments Platform Lead','2026-08-08',null,'Settlement webhook retry storm rate-limited — verifying burn slowdown'),
    ('SLO-MKT-SEARCH-2607','slow_query_regression','add_db_index','open',
     41.0,'Marketplace Backend','2026-08-18',null,'Composite index on listing filters proposed; EXPLAIN review scheduled'),
    ('SLO-MKT-SEARCH-2606','n_plus_one_rpc_pattern','optimize_query','closed',
     22.0,'Marketplace Backend','2026-07-15','2026-07-11','Browse RPC batched taxonomy lookups; June drift partially recovered'),
    ('SLO-MEDIA-UPLOAD-2607','infra_capacity_shortfall','scale_out_instances','open',
     28.0,'Platform Infra','2026-08-20',null,'Upload workers near CPU ceiling at evening peak — scale-out sized'),
    ('SLO-MKT-JOB-2607','deployment_regression','rollback_release','closed',
     15.0,'Marketplace Backend','2026-07-14','2026-07-12','2.14.1 job-RPC regression rolled back within the hour on 12 Jul')
  ) as q(ref, rc, ca, cst, impct, ownr, tcd, acd, nt)
  join public.api_slo_r3696 e
    on e.organization_id = v_org_id and e.slo_ref = q.ref;
end;
$seed$;
