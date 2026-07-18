-- Round 3285: Founder Digital-Presence, Website/SEO Health & Online-Reputation Governance Board
-- Marketing board — property type × owner team × SEO rank × uptime/SSL × page-speed × reviews/reputation × lead conversion × CAPA

-- =============================================================================
-- TABLE 1: digital_presence_r3285 — per digital-property / channel health row
-- =============================================================================
create table if not exists public.digital_presence_r3285 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_name text not null,
  property_type text not null check (property_type in (
    'corporate_website','landing_page','google_business_profile','linkedin_page',
    'justdial_listing','app_store_listing','seo_keyword_cluster'
  )),
  owner_team text not null check (owner_team in (
    'marketing','founder_office','sales'
  )),
  monthly_visits int not null,
  avg_position numeric(6,2),
  uptime_pct numeric(5,2) not null,
  page_load_seconds numeric(5,2) not null,
  ssl_valid boolean not null,
  reviews_count int not null,
  avg_rating numeric(3,2),
  unanswered_reviews int not null,
  lead_conversions_month int not null,
  last_updated_date date not null,
  property_verdict text not null check (property_verdict in (
    'healthy','needs_content_refresh','seo_slipping','reputation_risk','technical_issue','neglected'
  )),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.digital_presence_r3285 enable row level security;

create index if not exists idx_digital_presence_r3285_org on public.digital_presence_r3285(org_id);
create index if not exists idx_digital_presence_r3285_date on public.digital_presence_r3285(last_updated_date);
create index if not exists idx_digital_presence_r3285_verdict on public.digital_presence_r3285(property_verdict);

-- =============================================================================
-- TABLE 2: digital_presence_capa_actions_r3285 — content/SEO/reputation/technical CAPA
-- =============================================================================
create table if not exists public.digital_presence_capa_actions_r3285 (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.digital_presence_r3285(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'content_stale','seo_ranking_slip','unanswered_reviews','ssl_or_uptime_issue',
    'slow_page_load','listing_incomplete','low_conversion'
  )),
  root_cause text not null check (root_cause in (
    'content_not_updated','competitor_outranking','no_review_response_process','cert_expired_or_server_down',
    'unoptimized_assets','missing_business_info','weak_cta_or_landing','pending_investigation'
  )),
  corrective_action text not null check (corrective_action in (
    'refresh_content_calendar','seo_keyword_optimization','assign_review_responder','renew_ssl_and_monitor',
    'optimize_page_speed','complete_listing_profile','redesign_landing_page','escalate_to_agency','none_required'
  )),
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  business_impact text not null check (business_impact in (
    'lead_pipeline_loss','brand_reputation_risk','seo_visibility_loss','none','internal_only','conversion_drop'
  )),
  target_closure_date date,
  actual_closure_date date,
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.digital_presence_capa_actions_r3285 enable row level security;

create index if not exists idx_digital_presence_capa_r3285_prop on public.digital_presence_capa_actions_r3285(property_id);
create index if not exists idx_digital_presence_capa_r3285_status on public.digital_presence_capa_actions_r3285(capa_status);

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

  -- 14 digital-property rows
  insert into public.digital_presence_r3285 (
    org_id, property_name, property_type, owner_team,
    monthly_visits, avg_position, uptime_pct, page_load_seconds, ssl_valid,
    reviews_count, avg_rating, unanswered_reviews, lead_conversions_month,
    last_updated_date, property_verdict, notes
  )
  select v_org_id, q.name, q.ptype, q.oteam,
    q.visits, q.apos, q.uptime, q.pload, q.ssl,
    q.rev, q.rating, q.unans, q.leads,
    q.lud::date, q.verdict, q.nt
  from (values
    ('EquipSeva Corporate Website','corporate_website','marketing',
     48200,8.40,99.94,2.10,true,0,null,0,142,'2026-07-10','healthy','Core site healthy — Core Web Vitals green'),
    ('Book-a-Service Landing Page','landing_page','marketing',
     15600,12.70,99.80,3.60,true,0,null,0,88,'2026-06-20','seo_slipping','Slipped from position 6 to 12 for "medical equipment service Chennai"'),
    ('EquipSeva Google Business Profile','google_business_profile','marketing',
     9800,null,100.00,1.20,true,512,4.50,34,61,'2026-07-05','reputation_risk','34 reviews unanswered over 30 days — responder needed'),
    ('EquipSeva LinkedIn Page','linkedin_page','founder_office',
     6400,null,100.00,1.00,true,0,null,0,22,'2026-07-12','healthy','Founder-led posting cadence steady'),
    ('JustDial Business Listing','justdial_listing','sales',
     4200,null,99.50,2.80,true,138,3.90,41,18,'2026-05-28','reputation_risk','41 unanswered JustDial reviews; rating drifting below 4.0'),
    ('EquipSeva Play Store Listing','app_store_listing','marketing',
     12100,null,100.00,1.50,true,1840,4.30,96,96,'2026-06-30','needs_content_refresh','Screenshots and description stale vs current app UI'),
    ('AMC Pricing Landing Page','landing_page','sales',
     8700,15.20,98.20,4.90,false,0,null,0,39,'2026-04-15','technical_issue','SSL cert expired; LCP 4.9s; conversion halved'),
    ('Biomedical Equipment AMC Keyword Cluster','seo_keyword_cluster','marketing',
     3300,18.60,100.00,3.10,true,0,null,0,12,'2026-06-10','seo_slipping','Cluster ranks page 2; competitor content outranking'),
    ('Chennai Service Hub Landing Page','landing_page','marketing',
     5400,9.80,99.90,2.40,true,0,null,0,47,'2026-07-08','healthy','Regional page performing well'),
    ('EquipSeva Apollo Partnership Microsite','corporate_website','founder_office',
     2100,22.40,97.60,5.60,true,0,null,0,8,'2026-02-12','neglected','Not updated in 5 months; content outdated post-partnership'),
    ('JustDial Bengaluru Listing','justdial_listing','sales',
     3600,null,99.40,3.00,true,74,4.10,9,14,'2026-07-01','healthy','Bengaluru listing well maintained'),
    ('EquipSeva App Store iOS Listing','app_store_listing','marketing',
     5200,null,100.00,1.40,true,620,4.00,28,28,'2026-06-05','needs_content_refresh','iOS keywords and preview video outdated'),
    ('Careers Landing Page','landing_page','founder_office',
     1900,null,99.10,3.90,true,0,null,0,3,'2026-06-28','healthy','Low traffic but stable; no SEO focus'),
    ('EquipSeva Corporate Blog','corporate_website','marketing',
     7300,14.10,96.80,6.20,false,0,null,0,19,'2026-03-20','technical_issue','Blog on separate host; SSL warning and 6.2s load; intermittent downtime')
  ) as q(name, ptype, oteam, visits, apos, uptime, pload, ssl, rev, rating, unans, leads, lud, verdict, nt);

  -- CAPA seed — attach to specific at-risk properties via property_name
  insert into public.digital_presence_capa_actions_r3285 (
    org_id, property_id, finding_category, root_cause, corrective_action,
    capa_status, business_impact, target_closure_date, actual_closure_date,
    estimated_cost_rupees, notes
  )
  select v_org_id, e.id, q.fc, q.rc, q.ca,
    q.cst, q.bi, q.tcd::date, q.acd::date,
    q.cost, q.nt
  from (values
    ('AMC Pricing Landing Page','ssl_or_uptime_issue','cert_expired_or_server_down','renew_ssl_and_monitor','escalated','conversion_drop','2026-04-20',null,8000.00,'SSL expired — cert renewal plus auto-monitor being set up'),
    ('EquipSeva Google Business Profile','unanswered_reviews','no_review_response_process','assign_review_responder','in_progress','brand_reputation_risk','2026-07-15',null,15000.00,'Assigning marketing exec to clear 34-review backlog'),
    ('JustDial Business Listing','unanswered_reviews','no_review_response_process','assign_review_responder','open','brand_reputation_risk','2026-07-20',null,12000.00,'JustDial rating below 4.0 — response SLA needed'),
    ('Book-a-Service Landing Page','seo_ranking_slip','competitor_outranking','seo_keyword_optimization','in_progress','seo_visibility_loss','2026-07-18',null,45000.00,'Content refresh plus backlinks to reclaim position 6'),
    ('Biomedical Equipment AMC Keyword Cluster','seo_ranking_slip','content_not_updated','refresh_content_calendar','open','seo_visibility_loss','2026-07-25',null,30000.00,'Publish 4 pillar articles for the cluster'),
    ('EquipSeva Apollo Partnership Microsite','content_stale','content_not_updated','refresh_content_calendar','overdue','internal_only','2026-03-01',null,20000.00,'Microsite content 5 months stale — refresh overdue'),
    ('EquipSeva Corporate Blog','ssl_or_uptime_issue','cert_expired_or_server_down','renew_ssl_and_monitor','closed','lead_pipeline_loss','2026-04-05','2026-04-02',18000.00,'Migrated blog to main host; SSL and uptime resolved')
  ) as q(pname, fc, rc, ca, cst, bi, tcd, acd, cost, nt)
  join public.digital_presence_r3285 e
    on e.org_id = v_org_id and e.property_name = q.pname;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Property verdict distribution
create or replace function public.founder_r3285_property_verdict_rollup()
returns table(property_verdict text, properties bigint, pct numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.digital_presence_r3285)
  select l.property_verdict, count(*)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.digital_presence_r3285 l
  group by l.property_verdict
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3285_property_verdict_rollup() from public, anon;
grant execute on function public.founder_r3285_property_verdict_rollup() to authenticated;

-- 2) Property-type scorecard
create or replace function public.founder_r3285_property_type_scorecard()
returns table(
  property_type text,
  total_properties bigint,
  healthy bigint,
  at_risk bigint,
  ssl_invalid bigint,
  total_monthly_visits bigint,
  avg_uptime_pct numeric,
  total_unanswered_reviews bigint,
  total_lead_conversions bigint,
  healthy_pct numeric
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.property_type,
    count(*)::bigint,
    count(*) filter (where l.property_verdict = 'healthy')::bigint,
    count(*) filter (where l.property_verdict in ('needs_content_refresh','seo_slipping','reputation_risk','technical_issue','neglected'))::bigint,
    count(*) filter (where l.ssl_valid = false)::bigint,
    coalesce(sum(l.monthly_visits),0)::bigint,
    round(avg(l.uptime_pct), 2),
    coalesce(sum(l.unanswered_reviews),0)::bigint,
    coalesce(sum(l.lead_conversions_month),0)::bigint,
    round(100.0 * count(*) filter (where l.property_verdict = 'healthy')::numeric / nullif(count(*),0), 1)
  from public.digital_presence_r3285 l
  group by l.property_type
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3285_property_type_scorecard() from public, anon;
grant execute on function public.founder_r3285_property_type_scorecard() to authenticated;

-- 3) Property-type × owner-team matrix
create or replace function public.founder_r3285_type_owner_matrix()
returns table(property_type text, owner_team text, properties bigint, healthy bigint, avg_monthly_visits numeric, avg_page_load_seconds numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.property_type, l.owner_team, count(*)::bigint,
    count(*) filter (where l.property_verdict = 'healthy')::bigint,
    round(avg(l.monthly_visits), 0),
    round(avg(l.page_load_seconds), 2)
  from public.digital_presence_r3285 l
  group by l.property_type, l.owner_team
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3285_type_owner_matrix() from public, anon;
grant execute on function public.founder_r3285_type_owner_matrix() to authenticated;

-- 4) Daily update / freshness trend (by last-updated date)
create or replace function public.founder_r3285_daily_update_trend()
returns table(last_updated_date date, properties bigint, healthy bigint, at_risk bigint, total_monthly_visits bigint, total_lead_conversions bigint)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.last_updated_date,
    count(*)::bigint,
    count(*) filter (where l.property_verdict = 'healthy')::bigint,
    count(*) filter (where l.property_verdict in ('needs_content_refresh','seo_slipping','reputation_risk','technical_issue','neglected'))::bigint,
    coalesce(sum(l.monthly_visits),0)::bigint,
    coalesce(sum(l.lead_conversions_month),0)::bigint
  from public.digital_presence_r3285 l
  group by l.last_updated_date
  order by l.last_updated_date desc;
end;
$$;

revoke all on function public.founder_r3285_daily_update_trend() from public, anon;
grant execute on function public.founder_r3285_daily_update_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3285_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, overdue_flag bigint)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.digital_presence_capa_actions_r3285 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3285_capa_status_board() from public, anon;
grant execute on function public.founder_r3285_capa_status_board() to authenticated;

-- 6) Root-cause pareto
create or replace function public.founder_r3285_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.digital_presence_capa_actions_r3285)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.digital_presence_capa_actions_r3285 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3285_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3285_root_cause_pareto() to authenticated;

-- 7) Business-impact / cost-risk digest
create or replace function public.founder_r3285_business_impact_digest()
returns table(business_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.business_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.digital_presence_capa_actions_r3285 c
  group by c.business_impact
  order by count(*) desc;
end;
$$;

revoke all on function public.founder_r3285_business_impact_digest() from public, anon;
grant execute on function public.founder_r3285_business_impact_digest() to authenticated;

-- 8) High-risk property queue
create or replace function public.founder_r3285_high_risk_queue()
returns table(
  property_name text,
  property_type text,
  owner_team text,
  last_updated_date date,
  property_verdict text,
  avg_position numeric,
  uptime_pct numeric,
  ssl_valid boolean,
  unanswered_reviews int,
  notes text
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.property_name, l.property_type, l.owner_team, l.last_updated_date,
    l.property_verdict, l.avg_position, l.uptime_pct, l.ssl_valid,
    l.unanswered_reviews, l.notes
  from public.digital_presence_r3285 l
  where l.property_verdict in ('needs_content_refresh','seo_slipping','reputation_risk','technical_issue','neglected')
     or l.ssl_valid = false
     or l.unanswered_reviews >= 20
     or l.uptime_pct < 99.0
     or l.page_load_seconds > 4.0
  order by l.last_updated_date asc, l.property_name;
end;
$$;

revoke all on function public.founder_r3285_high_risk_queue() from public, anon;
grant execute on function public.founder_r3285_high_risk_queue() to authenticated;
