-- Round 3735: Founder Customer Social-Media / Public-Review Monitoring Board
-- Public-review platform monitoring — Google/social/app-store/healthcare-forum/news mentions ×
-- sentiment × response time × negative-review escalation × viral-risk flags × CAPA.
-- Distinct from any NPS/CSAT survey board, which is direct-surveyed feedback, not
-- public-review-platform monitoring.

-- =============================================================================
-- TABLE 1: review_monitor_r3735 — public-review monitoring facts
-- =============================================================================
create table if not exists public.review_monitor_r3735 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  platform_name text not null,
  region text not null,
  period_month date not null,
  reviews_received int not null,
  avg_rating numeric,
  negative_reviews int,
  responded_within_24h int,
  response_rate_pct numeric,
  escalated_to_support int,
  sentiment_score numeric,
  viral_risk_flagged boolean not null,
  platform_class text not null check (platform_class in (
    'google_reviews','social_media_mention','app_store_review','healthcare_forum','news_media'
  )),
  monitoring_status text not null check (monitoring_status in (
    'healthy_sentiment','watch','response_gap','negative_trend','crisis_risk'
  )),
  trend_dir text not null check (trend_dir in (
    'improving','stable','worsening'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.review_monitor_r3735 enable row level security;

create index if not exists idx_review_monitor_r3735_org on public.review_monitor_r3735(organization_id);
create index if not exists idx_review_monitor_r3735_month on public.review_monitor_r3735(period_month);
create index if not exists idx_review_monitor_r3735_status on public.review_monitor_r3735(monitoring_status);

-- =============================================================================
-- TABLE 2: review_monitor_capa_actions_r3735 — CAPA for review-monitoring gaps
-- =============================================================================
create table if not exists public.review_monitor_capa_actions_r3735 (
  id uuid primary key default gen_random_uuid(),
  review_monitor_id uuid references public.review_monitor_r3735(id) on delete cascade,
  root_cause text,
  corrective_action text,
  capa_status text not null check (capa_status in ('open','in_progress','closed','overdue')),
  owner text,
  target_close_date date,
  actual_close_date date,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.review_monitor_capa_actions_r3735 enable row level security;

create index if not exists idx_review_monitor_capa_r3735_ref on public.review_monitor_capa_actions_r3735(review_monitor_id);
create index if not exists idx_review_monitor_capa_r3735_status on public.review_monitor_capa_actions_r3735(capa_status);

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

  -- 16 review-monitoring rows
  insert into public.review_monitor_r3735 (
    organization_id, platform_name, region, period_month, reviews_received,
    avg_rating, negative_reviews, responded_within_24h, response_rate_pct,
    escalated_to_support, sentiment_score, viral_risk_flagged,
    platform_class, monitoring_status, trend_dir, notes
  )
  select v_org_id, q.pn, q.rg, q.pm::date, q.rr::int,
    q.ar::numeric, q.nr::int, q.rw::int, q.rp::numeric,
    q.es::int, q.ss::numeric, q.vr,
    q.pc, q.ms, q.td, q.nt
  from (values
    ('Google Business Profile','Mumbai','2026-07-01',86,4.3,6,78,90.7,2,0.72,false,'google_reviews','healthy_sentiment','improving','Positive spike after onsite service-quality drive'),
    ('Google Business Profile','Delhi NCR','2026-07-01',54,3.6,14,32,59.3,5,0.31,true,'google_reviews','crisis_risk','worsening','Viral thread on delayed AMC visit — flagged for exec review'),
    ('Facebook Page Mentions','Bengaluru','2026-07-01',41,4.0,8,29,70.7,3,0.48,false,'social_media_mention','watch','stable','Mixed mentions on rental pricing transparency'),
    ('Twitter/X Mentions','Chennai','2026-06-01',37,3.4,15,18,48.6,6,0.22,true,'social_media_mention','negative_trend','worsening','Escalating thread about breakdown response time'),
    ('Play Store Reviews','Pune','2026-07-01',63,4.1,9,52,82.5,1,0.61,false,'app_store_review','healthy_sentiment','improving','App-crash complaints dropped after v4.2 patch'),
    ('App Store (iOS) Reviews','Hyderabad','2026-06-01',29,3.2,11,14,48.3,4,0.28,false,'app_store_review','response_gap','worsening','Support-team backlog on iOS ticket replies'),
    ('MouthShut Healthcare Forum','Kolkata','2026-07-01',22,3.0,10,9,40.9,5,0.19,false,'healthcare_forum','negative_trend','worsening','Recurring complaints on radiology-equipment uptime'),
    ('Practo Forum Mentions','Ahmedabad','2026-06-01',18,4.2,2,16,88.9,0,0.69,false,'healthcare_forum','healthy_sentiment','stable','Praise for quick imaging-equipment servicing'),
    ('Economic Times Coverage','Mumbai','2026-05-01',6,3.8,1,5,83.3,0,0.55,false,'news_media','watch','stable','Neutral coverage of quarterly expansion news'),
    ('LinkedIn Company Mentions','Delhi NCR','2026-07-01',33,4.4,3,30,90.9,0,0.75,false,'social_media_mention','healthy_sentiment','improving','Strong engagement on CSR equipment-donation post'),
    ('Google Business Profile','Bengaluru','2026-06-01',71,3.9,12,49,69.0,4,0.44,false,'google_reviews','watch','stable','Steady volume, response rate slipping slightly'),
    ('Instagram Mentions','Chennai','2026-07-01',26,4.5,1,24,92.3,0,0.81,false,'social_media_mention','healthy_sentiment','improving','Reel on refurbished-equipment story went well'),
    ('Play Store Reviews','Kolkata','2026-06-01',48,2.9,22,19,39.6,9,0.18,true,'app_store_review','crisis_risk','worsening','1-star bombing after billing-glitch complaints went viral'),
    ('Google Business Profile','Pune','2026-05-01',59,4.2,5,53,89.8,1,0.68,false,'google_reviews','healthy_sentiment','stable','Consistent high rating maintained third month running'),
    ('YouTube Comment Mentions','Hyderabad','2026-06-01',15,3.5,5,7,46.7,2,0.35,false,'social_media_mention','response_gap','stable','Comment-reply SLA missed on product-demo video'),
    ('Times of India Coverage','Ahmedabad','2026-07-01',9,4.0,1,8,88.9,0,0.58,false,'news_media','healthy_sentiment','improving','Favorable feature on rural-clinic equipment outreach')
  ) as q(pn, rg, pm, rr, ar, nr, rw, rp, es, ss, vr, pc, ms, td, nt);

  -- 8 CAPA rows — attach to review-monitor rows via platform_name + region
  insert into public.review_monitor_capa_actions_r3735 (
    review_monitor_id, root_cause, corrective_action, capa_status, owner,
    target_close_date, actual_close_date, notes
  )
  select e.id, q.rc, q.ca, q.cst, q.ownr,
    q.tcd::date, q.acd::date, q.nt
  from (values
    ('Google Business Profile','Delhi NCR','AMC visit rescheduled twice without customer notice','Add auto-SMS reschedule alerts to AMC dispatch workflow','in_progress','Service Ops Lead','2026-08-22',null,'Viral thread traced to two silent reschedules in one month'),
    ('Twitter/X Mentions','Chennai','Breakdown response SLA not visible to social team','Give social-response team read access to dispatch SLA dashboard','open','Social Media Manager','2026-08-28',null,'Team was replying without response-time context'),
    ('App Store (iOS) Reviews','Hyderabad','iOS ticket queue not staffed on weekends','Add weekend on-call rotation for iOS support queue','open','Support Manager','2026-08-30',null,'Backlog builds up over weekends and slips SLA'),
    ('MouthShut Healthcare Forum','Kolkata','Radiology-equipment uptime issues not linked to forum monitoring','Route uptime alerts to marketing-CX for proactive forum replies','in_progress','CX Ops Lead','2026-08-25',null,'Currently reactive-only; no proactive outreach loop'),
    ('Play Store Reviews','Kolkata','Billing glitch went unresolved for 5 days before review storm','Set 24-hour SLA for billing-glitch escalation to engineering','overdue','Engineering Lead','2026-08-10',null,'Fix shipped but review-recovery campaign not yet started'),
    ('YouTube Comment Mentions','Hyderabad','No owner assigned for video-comment replies','Assign marketing intern rotation for daily comment triage','closed','Marketing Manager','2026-07-15','2026-07-14','Rotation live; response time down from 3 days to same-day'),
    ('Google Business Profile','Bengaluru','Response-rate slippage not caught until monthly review','Add weekly response-rate alert threshold at 75%','open','CX Ops Lead','2026-08-20',null,'Monthly-only review cadence missed the slow decline'),
    ('Facebook Page Mentions','Bengaluru','Rental pricing FAQ not linked in auto-reply templates','Update auto-reply templates with pricing-transparency FAQ link','in_progress','Social Media Manager','2026-08-18',null,'Reduces repeat pricing-confusion mentions')
  ) as q(pn, rg, rc, ca, cst, ownr, tcd, acd, nt)
  join public.review_monitor_r3735 e
    on e.organization_id = v_org_id and e.platform_name = q.pn and e.region = q.rg;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Monitoring-status distribution
create or replace function public.founder_r3735_monitoring_status_rollup()
returns table(monitoring_status text, records bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.review_monitor_r3735)
  select l.monitoring_status, count(*)::bigint,
    round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.review_monitor_r3735 l
  group by l.monitoring_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3735_monitoring_status_rollup() from public, anon;
grant execute on function public.founder_r3735_monitoring_status_rollup() to authenticated;

-- 2) Platform-name scorecard
create or replace function public.founder_r3735_platform_name_scorecard()
returns table(
  platform_name text,
  records bigint,
  total_reviews bigint,
  avg_rating numeric,
  avg_response_rate_pct numeric,
  total_escalated bigint,
  avg_sentiment_score numeric,
  viral_risk_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.platform_name,
    count(*)::bigint,
    coalesce(sum(l.reviews_received),0)::bigint,
    round(avg(l.avg_rating), 2),
    round(avg(l.response_rate_pct), 1),
    coalesce(sum(l.escalated_to_support),0)::bigint,
    round(avg(l.sentiment_score), 2),
    count(*) filter (where l.viral_risk_flagged = true)::bigint
  from public.review_monitor_r3735 l
  group by l.platform_name
  order by coalesce(sum(l.reviews_received),0) desc;
end;
$$;

revoke all on function public.founder_r3735_platform_name_scorecard() from public, anon;
grant execute on function public.founder_r3735_platform_name_scorecard() to authenticated;

-- 3) Platform-class × monitoring-status matrix
create or replace function public.founder_r3735_platform_class_status_matrix()
returns table(platform_class text, monitoring_status text, records bigint, avg_sentiment_score numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.platform_class, l.monitoring_status, count(*)::bigint,
    round(avg(l.sentiment_score), 2)
  from public.review_monitor_r3735 l
  group by l.platform_class, l.monitoring_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3735_platform_class_status_matrix() from public, anon;
grant execute on function public.founder_r3735_platform_class_status_matrix() to authenticated;

-- 4) Monthly sentiment trend
create or replace function public.founder_r3735_monthly_sentiment_trend()
returns table(
  period_month date,
  records bigint,
  total_reviews bigint,
  avg_sentiment_score numeric,
  avg_response_rate_pct numeric,
  worsening_records bigint
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
    coalesce(sum(l.reviews_received),0)::bigint,
    round(avg(l.sentiment_score), 2),
    round(avg(l.response_rate_pct), 1),
    count(*) filter (where l.trend_dir = 'worsening')::bigint
  from public.review_monitor_r3735 l
  group by l.period_month
  order by l.period_month desc;
end;
$$;

revoke all on function public.founder_r3735_monthly_sentiment_trend() from public, anon;
grant execute on function public.founder_r3735_monthly_sentiment_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3735_capa_status_board()
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
  from public.review_monitor_capa_actions_r3735 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3735_capa_status_board() from public, anon;
grant execute on function public.founder_r3735_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3735_root_cause_pareto()
returns table(root_cause text, occurrences bigint, pct numeric)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.review_monitor_capa_actions_r3735)
  select c.root_cause, count(*)::bigint,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.review_monitor_capa_actions_r3735 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3735_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3735_root_cause_pareto() to authenticated;

-- 7) Response-gap digest (response gap or negative-trend / crisis records with weak response)
create or replace function public.founder_r3735_response_gap_digest()
returns table(
  platform_class text,
  records bigint,
  responded_within_24h_total bigint,
  reviews_received_total bigint,
  avg_response_rate_pct numeric,
  escalated_total bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.platform_class,
    count(*)::bigint,
    coalesce(sum(l.responded_within_24h),0)::bigint,
    coalesce(sum(l.reviews_received),0)::bigint,
    round(avg(l.response_rate_pct), 1),
    coalesce(sum(l.escalated_to_support),0)::bigint
  from public.review_monitor_r3735 l
  where l.monitoring_status in ('response_gap','negative_trend','crisis_risk')
  group by l.platform_class
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3735_response_gap_digest() from public, anon;
grant execute on function public.founder_r3735_response_gap_digest() to authenticated;

-- 8) High-risk queue (crisis risk / negative trend, worst first)
create or replace function public.founder_r3735_high_risk_queue()
returns table(
  platform_name text,
  region text,
  platform_class text,
  period_month date,
  monitoring_status text,
  reviews_received int,
  avg_rating numeric,
  sentiment_score numeric,
  response_rate_pct numeric,
  viral_risk_flagged boolean,
  notes text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.platform_name, l.region, l.platform_class, l.period_month,
    l.monitoring_status, l.reviews_received, l.avg_rating, l.sentiment_score,
    l.response_rate_pct, l.viral_risk_flagged, l.notes
  from public.review_monitor_r3735 l
  where l.monitoring_status in ('crisis_risk','negative_trend')
  order by l.viral_risk_flagged desc, l.sentiment_score asc nulls last, l.period_month desc
  limit 20;
end;
$$;

revoke all on function public.founder_r3735_high_risk_queue() from public, anon;
grant execute on function public.founder_r3735_high_risk_queue() to authenticated;
