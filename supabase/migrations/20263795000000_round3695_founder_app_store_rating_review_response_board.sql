-- Round 3695: Founder App-Store Rating / Review-Response Board
-- Play-Store/App-Store reputation ops — listing × store × monthly rating × review-response discipline × review theme × reputation status × trend × CAPA

-- =============================================================================
-- TABLE 1: store_rating_r3695 — per-listing per-month rating & review-response log
-- =============================================================================
create table if not exists public.store_rating_r3695 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  review_cycle_code text not null,
  listing_name text not null,
  store_name text not null,
  period_month date not null,
  avg_rating numeric(3,2),
  ratings_count int,
  reviews_received int,
  reviews_responded int,
  response_pct numeric(5,1),
  avg_response_hours numeric(6,1),
  one_star_reviews int,
  feature_requests int,
  bug_complaints int,
  review_theme text not null check (review_theme in (
    'bugs_crashes','feature_request','ux_confusion','pricing_billing','praise'
  )),
  reputation_status text not null check (reputation_status in (
    'strong','stable','slipping','at_risk','critical'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.store_rating_r3695 enable row level security;

create index if not exists idx_store_rating_r3695_org on public.store_rating_r3695(organization_id);
create index if not exists idx_store_rating_r3695_month on public.store_rating_r3695(period_month);
create index if not exists idx_store_rating_r3695_status on public.store_rating_r3695(reputation_status);

-- =============================================================================
-- TABLE 2: store_rating_capa_actions_r3695 — CAPA & reputation-recovery actions
-- =============================================================================
create table if not exists public.store_rating_capa_actions_r3695 (
  id uuid primary key default gen_random_uuid(),
  rating_log_id uuid not null references public.store_rating_r3695(id) on delete cascade,
  raised_at timestamptz not null default now(),
  root_cause text not null check (root_cause in (
    'crash_regression','payment_gateway_failure','onboarding_confusion',
    'notification_spam','slow_support_response','pricing_page_unclear',
    'android_fragmentation','review_reply_backlog','stale_release_cadence',
    'pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'hotfix_release','fix_payment_flow','revamp_onboarding',
    'tune_notification_frequency','staff_review_response_rota','clarify_pricing_copy',
    'expand_device_test_matrix','bulk_reply_campaign','accelerate_release_train',
    'none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  rating_points_at_risk numeric(3,2),
  owner text not null,
  target_closure_date date,
  actual_closure_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.store_rating_capa_actions_r3695 enable row level security;

create index if not exists idx_store_rating_capa_r3695_log on public.store_rating_capa_actions_r3695(rating_log_id);
create index if not exists idx_store_rating_capa_r3695_status on public.store_rating_capa_actions_r3695(capa_status);

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

  -- 15 rating/review-response rows
  insert into public.store_rating_r3695 (
    organization_id, review_cycle_code, listing_name, store_name, period_month,
    avg_rating, ratings_count, reviews_received, reviews_responded, response_pct,
    avg_response_hours, one_star_reviews, feature_requests, bug_complaints,
    review_theme, reputation_status, trend_dir, notes
  )
  select v_org_id, q.rcode, q.lname, q.sname, q.pmonth::date,
    q.arating, q.rcount, q.rrecv, q.rresp, q.rpct,
    q.rhours, q.onestar, q.featreq, q.bugcmp,
    q.theme, q.rstatus, q.tdir, q.nt
  from (values
    ('CUST-GP-2026-05','EquipSeva Customer','google_play','2026-05-01',
     4.12,318,64,58,90.6,9.5,7,14,11,'feature_request','stable','stable',
     'Steady month; most reviews ask for AMC reminders and Hindi UI'),
    ('CUST-GP-2026-06','EquipSeva Customer','google_play','2026-06-01',
     3.86,352,81,61,75.3,18.2,15,12,29,'bugs_crashes','slipping','worsening',
     'v2.14.0 crash on bid screen drove a one-star wave mid-month'),
    ('CUST-GP-2026-07','EquipSeva Customer','google_play','2026-07-01',
     4.05,340,72,70,97.2,6.8,9,15,14,'bugs_crashes','stable','improving',
     'Hotfix 2.14.1 landed; response rota cleared the reply backlog'),
    ('CUST-AS-2026-05','EquipSeva Customer','apple_app_store','2026-05-01',
     4.35,96,22,20,90.9,11.0,2,6,3,'praise','strong','stable',
     'iOS cohort small but happy; praise for engineer tracking'),
    ('CUST-AS-2026-06','EquipSeva Customer','apple_app_store','2026-06-01',
     4.21,104,26,19,73.1,21.4,3,8,5,'ux_confusion','stable','worsening',
     'Checkout confusion on UPI intent flow; replies slowed during sprint'),
    ('CUST-AS-2026-07','EquipSeva Customer','apple_app_store','2026-07-01',
     4.28,111,24,24,100.0,5.2,2,7,4,'praise','strong','improving',
     'Full response coverage restored; UPI copy clarified in 2.15.0'),
    ('PROV-GP-2026-05','EquipSeva Provider','google_play','2026-05-01',
     3.72,141,38,21,55.3,30.6,9,9,16,'pricing_billing','at_risk','worsening',
     'Commission clarity complaints; replies lagging past 24h SLA'),
    ('PROV-GP-2026-06','EquipSeva Provider','google_play','2026-06-01',
     3.58,156,44,26,59.1,26.9,13,7,19,'pricing_billing','at_risk','worsening',
     'Payout-delay reviews stacking; pricing page rewrite in flight'),
    ('PROV-GP-2026-07','EquipSeva Provider','google_play','2026-07-01',
     3.81,163,41,38,92.7,10.1,8,10,12,'pricing_billing','slipping','improving',
     'Pricing copy shipped and payout fix live; rating recovering'),
    ('PROV-AS-2026-05','EquipSeva Provider','apple_app_store','2026-05-01',
     4.02,47,11,9,81.8,14.7,1,4,3,'feature_request','stable','stable',
     'Providers ask for bulk quote templates on iPad'),
    ('PROV-AS-2026-06','EquipSeva Provider','apple_app_store','2026-06-01',
     3.95,52,13,10,76.9,16.3,2,5,4,'ux_confusion','stable','stable',
     'Bid-edit flow confusion on iOS; walkthrough video planned'),
    ('PROV-AS-2026-07','EquipSeva Provider','apple_app_store','2026-07-01',
     4.08,55,12,12,100.0,7.9,1,5,2,'feature_request','stable','improving',
     'All reviews answered inside 8h; template feature queued'),
    ('ENGR-GP-2026-05','EquipSeva Engineer','google_play','2026-05-01',
     3.41,88,27,12,44.4,41.8,11,5,18,'bugs_crashes','critical','worsening',
     'Field engineers on Android 11 devices hit sync crashes; replies sparse'),
    ('ENGR-GP-2026-06','EquipSeva Engineer','google_play','2026-06-01',
     3.55,97,31,22,71.0,19.6,9,6,15,'bugs_crashes','at_risk','improving',
     'Device-matrix fix for sync crash in beta; response rota extended'),
    ('ENGR-GP-2026-07','EquipSeva Engineer','google_play','2026-07-01',
     3.78,109,29,27,93.1,9.4,5,8,9,'ux_confusion','slipping','improving',
     'Sync fix GA in 2.15.0; remaining gripes are duty-roster notifications')
  ) as q(rcode, lname, sname, pmonth, arating, rcount, rrecv, rresp, rpct,
         rhours, onestar, featreq, bugcmp, theme, rstatus, tdir, nt);

  -- CAPA seed — attach to specific review cycles via review_cycle_code
  insert into public.store_rating_capa_actions_r3695 (
    rating_log_id, root_cause, corrective_action, capa_status,
    rating_points_at_risk, owner, target_closure_date, actual_closure_date, notes
  )
  select e.id, q.rc, q.ca, q.cst,
    q.rimp, q.ownr, q.tcd::date, q.acd::date, q.nt
  from (values
    ('CUST-GP-2026-06','crash_regression','hotfix_release','closed',
     0.35,'Android Lead','2026-06-20','2026-06-18','2.14.1 hotfix shipped; crash-free sessions back to 99.6%'),
    ('CUST-GP-2026-06','review_reply_backlog','staff_review_response_rota','closed',
     0.15,'Support Ops','2026-06-25','2026-06-24','Daily 30-min reply rota staffed across support shift'),
    ('CUST-AS-2026-06','onboarding_confusion','clarify_pricing_copy','verification_pending',
     0.10,'Product Design','2026-07-15',null,'UPI intent copy reworded in 2.15.0 — watching July reviews'),
    ('PROV-GP-2026-05','pricing_page_unclear','clarify_pricing_copy','closed',
     0.30,'Growth PM','2026-06-30','2026-06-28','Commission breakdown added to provider pricing page'),
    ('PROV-GP-2026-06','payment_gateway_failure','fix_payment_flow','in_progress',
     0.40,'Payments Lead','2026-08-10',null,'Payout webhook retry fix in staging; settlement lag halved'),
    ('ENGR-GP-2026-05','android_fragmentation','expand_device_test_matrix','in_progress',
     0.55,'QA Lead','2026-08-15',null,'Android 11/12 low-RAM devices added to lab; sync crash repro automated'),
    ('ENGR-GP-2026-05','slow_support_response','bulk_reply_campaign','closed',
     0.20,'Support Ops','2026-06-10','2026-06-09','Backlog of 43 unanswered engineer reviews cleared'),
    ('ENGR-GP-2026-07','notification_spam','tune_notification_frequency','open',
     0.25,'Engineer-App PM','2026-08-20',null,'Duty-roster pings to be batched into a single morning digest')
  ) as q(rcode, rc, ca, cst, rimp, ownr, tcd, acd, nt)
  join public.store_rating_r3695 e
    on e.organization_id = v_org_id and e.review_cycle_code = q.rcode;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Reputation status distribution
create or replace function public.founder_r3695_reputation_status_rollup()
returns table(reputation_status text, cycles bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.store_rating_r3695)
  select l.reputation_status, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.store_rating_r3695 l
  group by l.reputation_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3695_reputation_status_rollup() from public, anon;
grant execute on function public.founder_r3695_reputation_status_rollup() to authenticated;

-- 2) Store-level scorecard
create or replace function public.founder_r3695_store_scorecard()
returns table(
  store_name text,
  cycles bigint,
  avg_rating numeric,
  total_ratings bigint,
  reviews_received bigint,
  reviews_responded bigint,
  avg_response_pct numeric,
  avg_response_hours numeric,
  one_star_total bigint,
  at_risk_cycles bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.store_name,
    count(*)::bigint,
    round(avg(l.avg_rating), 2),
    coalesce(sum(l.ratings_count),0)::bigint,
    coalesce(sum(l.reviews_received),0)::bigint,
    coalesce(sum(l.reviews_responded),0)::bigint,
    round(avg(l.response_pct), 1),
    round(avg(l.avg_response_hours), 1),
    coalesce(sum(l.one_star_reviews),0)::bigint,
    count(*) filter (where l.reputation_status in ('at_risk','critical'))::bigint
  from public.store_rating_r3695 l
  group by l.store_name
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3695_store_scorecard() from public, anon;
grant execute on function public.founder_r3695_store_scorecard() to authenticated;

-- 3) Review theme × reputation status matrix
create or replace function public.founder_r3695_theme_status_matrix()
returns table(review_theme text, reputation_status text, cycles bigint, avg_rating numeric, one_star_total bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.review_theme, l.reputation_status, count(*)::bigint,
    round(avg(l.avg_rating), 2),
    coalesce(sum(l.one_star_reviews),0)::bigint
  from public.store_rating_r3695 l
  group by l.review_theme, l.reputation_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3695_theme_status_matrix() from public, anon;
grant execute on function public.founder_r3695_theme_status_matrix() to authenticated;

-- 4) Monthly rating trend
create or replace function public.founder_r3695_monthly_rating_trend()
returns table(
  period_month date,
  cycles bigint,
  avg_rating numeric,
  reviews_received bigint,
  reviews_responded bigint,
  avg_response_pct numeric,
  one_star_total bigint
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
    round(avg(l.avg_rating), 2),
    coalesce(sum(l.reviews_received),0)::bigint,
    coalesce(sum(l.reviews_responded),0)::bigint,
    round(avg(l.response_pct), 1),
    coalesce(sum(l.one_star_reviews),0)::bigint
  from public.store_rating_r3695 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3695_monthly_rating_trend() from public, anon;
grant execute on function public.founder_r3695_monthly_rating_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3695_capa_status_board()
returns table(capa_status text, actions bigint, avg_rating_points_at_risk numeric, overdue_flag bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.rating_points_at_risk)::numeric, 2),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.store_rating_capa_actions_r3695 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3695_capa_status_board() from public, anon;
grant execute on function public.founder_r3695_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3695_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_rating_points_at_risk numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.store_rating_capa_actions_r3695)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.rating_points_at_risk),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.store_rating_capa_actions_r3695 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3695_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3695_root_cause_pareto() to authenticated;

-- 7) One-star digest per listing
create or replace function public.founder_r3695_one_star_digest()
returns table(
  listing_name text,
  store_name text,
  cycles bigint,
  one_star_total bigint,
  bug_complaints_total bigint,
  feature_requests_total bigint,
  avg_rating numeric,
  worst_month_rating numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.listing_name, l.store_name,
    count(*)::bigint,
    coalesce(sum(l.one_star_reviews),0)::bigint,
    coalesce(sum(l.bug_complaints),0)::bigint,
    coalesce(sum(l.feature_requests),0)::bigint,
    round(avg(l.avg_rating), 2),
    min(l.avg_rating)
  from public.store_rating_r3695 l
  group by l.listing_name, l.store_name
  order by coalesce(sum(l.one_star_reviews),0) desc;
end;
$$;

revoke all on function public.founder_r3695_one_star_digest() from public, anon;
grant execute on function public.founder_r3695_one_star_digest() to authenticated;

-- 8) High-risk queue (critical / at-risk / worsening / weak response)
create or replace function public.founder_r3695_high_risk_queue()
returns table(
  listing_name text,
  store_name text,
  period_month date,
  avg_rating numeric,
  one_star_reviews int,
  response_pct numeric,
  reputation_status text,
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
  select l.listing_name, l.store_name, l.period_month,
    l.avg_rating, l.one_star_reviews, l.response_pct,
    l.reputation_status, l.trend_dir, l.notes
  from public.store_rating_r3695 l
  where l.reputation_status in ('at_risk','critical')
     or l.trend_dir = 'worsening'
     or l.response_pct < 60.0
     or l.avg_rating < 3.6
  order by l.period_month desc, l.avg_rating asc;
end;
$$;

revoke all on function public.founder_r3695_high_risk_queue() from public, anon;
grant execute on function public.founder_r3695_high_risk_queue() to authenticated;
