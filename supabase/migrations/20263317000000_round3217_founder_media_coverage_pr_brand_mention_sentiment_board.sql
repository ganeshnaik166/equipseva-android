-- Round 3217: Founder Media-Coverage, PR & Brand-Mention Sentiment Board
-- PR mention log — outlet tier × mention type × reach × sentiment × key message × spokesperson × follow-up × CAPA

-- =============================================================================
-- TABLE 1: media_coverage_r3217 — individual media / PR / brand mentions
-- =============================================================================
create table if not exists public.media_coverage_r3217 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  hospital_name text not null,
  mention_ref text not null,
  outlet_name text not null,
  outlet_tier text not null check (outlet_tier in (
    'national_daily','regional_daily','trade_journal','tv_channel',
    'digital_native','social_platform','podcast_network','awards_body'
  )),
  headline text not null,
  mention_type text not null check (mention_type in (
    'news_feature','news_brief','social_post','social_thread','customer_review',
    'podcast_episode','tv_interview','award_win','award_shortlist'
  )),
  coverage_date date not null,
  published_at timestamptz,
  reach_estimate int not null,
  sentiment text not null check (sentiment in (
    'strongly_positive','positive','neutral','mixed','negative','strongly_negative'
  )),
  sentiment_score numeric(4,2),
  key_message_landed text not null check (key_message_landed in (
    'uptime_reliability','engineer_network_speed','transparent_pricing',
    'patient_safety_outcomes','make_in_india_service','hospital_cost_savings',
    'marketplace_trust','none_landed'
  )),
  spokesperson_name text,
  follow_up_opportunity text not null check (follow_up_opportunity in (
    'op_ed_pitch','case_study_feature','podcast_invite','award_submission',
    'speaker_slot','social_amplification','testimonial_request','none'
  )),
  mention_verdict text not null check (mention_verdict in (
    'amplify','monitor','respond_publicly','correct_record','escalate_crisis','archive'
  )),
  responded_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

alter table public.media_coverage_r3217 enable row level security;

create index if not exists idx_media_coverage_r3217_org on public.media_coverage_r3217(organization_id);
create index if not exists idx_media_coverage_r3217_date on public.media_coverage_r3217(coverage_date);
create index if not exists idx_media_coverage_r3217_verdict on public.media_coverage_r3217(mention_verdict);

-- =============================================================================
-- TABLE 2: media_coverage_capa_actions_r3217 — PR CAPA & follow-up actions
-- =============================================================================
create table if not exists public.media_coverage_capa_actions_r3217 (
  id uuid primary key default gen_random_uuid(),
  coverage_id uuid not null references public.media_coverage_r3217(id) on delete cascade,
  raised_at timestamptz not null default now(),
  finding_category text not null check (finding_category in (
    'negative_press','factual_error_in_article','social_backlash','review_bomb',
    'missed_key_message','spokesperson_misquote','competitor_comparison_loss',
    'crisis_escalation','pr_process_gap','award_submission_missed'
  )),
  root_cause text not null check (root_cause in (
    'no_media_briefing_doc','spokesperson_untrained','slow_pr_response',
    'unresolved_customer_complaint','product_incident_leak','weak_outlet_relationship',
    'no_social_listening','messaging_inconsistent','pending_investigation','agency_coordination_gap'
  )),
  corrective_action text not null check (corrective_action in (
    'issue_press_statement','request_correction','media_train_spokesperson',
    'publish_rebuttal_blog','resolve_customer_complaint','brief_journalist_background',
    'set_up_social_listening','refresh_messaging_house','engage_pr_agency','none_required'
  )),
  target_closure_date date,
  actual_closure_date date,
  capa_status text not null check (capa_status in (
    'open','in_progress','verification_pending','closed','escalated','overdue'
  )),
  regulatory_impact text not null check (regulatory_impact in (
    'none','internal_only','investor_disclosure','legal_review_needed','asci_code_risk','defamation_risk'
  )),
  estimated_cost_rupees numeric(12,2),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.media_coverage_capa_actions_r3217 enable row level security;

create index if not exists idx_media_capa_r3217_coverage on public.media_coverage_capa_actions_r3217(coverage_id);
create index if not exists idx_media_capa_r3217_status on public.media_coverage_capa_actions_r3217(capa_status);

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

  -- 14 media coverage rows
  insert into public.media_coverage_r3217 (
    organization_id, hospital_name, mention_ref, outlet_name, outlet_tier, headline,
    mention_type, coverage_date, published_at, reach_estimate,
    sentiment, sentiment_score, key_message_landed, spokesperson_name,
    follow_up_opportunity, mention_verdict, responded_at, notes
  )
  select v_org_id, q.hosp, q.ref, q.outlet, q.tier, q.head,
    q.mt, q.cd::date, q.pub::timestamptz, q.reach,
    q.sen, q.ss, q.km, q.spk,
    q.fu, q.mv, q.resp::timestamptz, q.nt
  from (values
    ('Apollo Hyderabad Jubilee Hills','MC-3217-001','The Hindu','national_daily','EquipSeva cuts OT equipment downtime 40 pct at Apollo',
     'news_feature','2026-07-10','2026-07-10 08:00:00+05:30',250000,'strongly_positive',4.60,'uptime_reliability','Ganesh Kumar','case_study_feature','amplify','2026-07-10 11:30:00+05:30','Front-page metro edition; hospital COO reshared'),
    ('Apollo Hyderabad Jubilee Hills','MC-3217-002','LinkedIn','social_platform','Apollo biomedical head praises 4-hour ventilator turnaround',
     'social_post','2026-07-11','2026-07-11 09:15:00+05:30',18000,'positive',3.80,'engineer_network_speed','Dr Meena Rao','social_amplification','amplify','2026-07-11 12:00:00+05:30','Organic post by hospital-side stakeholder'),
    ('Fortis Bannerghatta Bengaluru','MC-3217-003','Economic Times Healthworld','trade_journal','Fortis pilots marketplace model for biomedical AMC',
     'news_brief','2026-07-08','2026-07-08 07:30:00+05:30',90000,'positive',3.20,'transparent_pricing','Ganesh Kumar','op_ed_pitch','amplify','2026-07-08 10:00:00+05:30','CEO quoted on AMC pricing transparency'),
    ('Fortis Bannerghatta Bengaluru','MC-3217-004','X (Twitter)','social_platform','Thread questions spare-part markups on hospital repairs',
     'social_thread','2026-07-09','2026-07-09 20:40:00+05:30',32000,'mixed',0.40,'none_landed',null,'none','respond_publicly','2026-07-10 09:00:00+05:30','Replied with public rate-card link; thread cooled'),
    ('Manipal Whitefield Bengaluru','MC-3217-005','Google Reviews','social_platform','One-star review cites delayed dialysis machine repair',
     'customer_review','2026-07-06','2026-07-06 18:05:00+05:30',4500,'negative',-2.80,'none_landed',null,'testimonial_request','respond_publicly','2026-07-07 10:20:00+05:30','Service ticket traced; owner response posted'),
    ('Manipal Whitefield Bengaluru','MC-3217-006','HealthTech India Podcast','podcast_network','Episode 84: fixing India''s broken biomedical service market',
     'podcast_episode','2026-07-05','2026-07-05 06:00:00+05:30',12000,'positive',3.50,'marketplace_trust','Ganesh Kumar','speaker_slot','amplify','2026-07-05 15:00:00+05:30','45-min founder interview; clip cut for social'),
    ('AIIMS New Delhi Ansari Nagar','MC-3217-007','Press Trust of India','national_daily','AIIMS evaluates third-party biomedical service marketplaces',
     'news_brief','2026-07-04','2026-07-04 12:00:00+05:30',140000,'neutral',0.80,'none_landed','Priya Nair','case_study_feature','monitor',null,'Syndicated across 11 outlets; watch for follow-ups'),
    ('AIIMS New Delhi Ansari Nagar','MC-3217-008','Dainik Jagran','regional_daily','Report alleges slow oxygen plant service response at AIIMS',
     'news_feature','2026-07-03','2026-07-03 07:00:00+05:30',180000,'negative',-3.40,'none_landed','Ganesh Kumar','none','correct_record','2026-07-03 16:45:00+05:30','Incident predates EquipSeva contract — correction requested'),
    ('KIMS Secunderabad','MC-3217-009','Deccan Chronicle','regional_daily','KIMS saves 28 lakh yearly via marketplace AMC bids',
     'news_feature','2026-07-02','2026-07-02 08:10:00+05:30',110000,'positive',3.00,'hospital_cost_savings','Priya Nair','case_study_feature','amplify','2026-07-02 11:00:00+05:30','CFO shared savings numbers on record'),
    ('Care Hospitals Banjara Hills','MC-3217-010','YouTube','social_platform','Viral video alleges billing dispute on emergency repair',
     'social_post','2026-07-12','2026-07-12 21:30:00+05:30',42000,'strongly_negative',-4.20,'none_landed',null,'none','escalate_crisis','2026-07-13 08:00:00+05:30','War room opened; statement drafted within 6 hours'),
    ('Yashoda Somajiguda Hyderabad','MC-3217-011','ET Now','tv_channel','Prime-time segment on make-in-India medical device servicing',
     'tv_interview','2026-07-07','2026-07-07 19:00:00+05:30',300000,'positive',4.00,'make_in_india_service','Ganesh Kumar','speaker_slot','amplify','2026-07-07 21:00:00+05:30','5-minute studio interview; clip on homepage'),
    ('St John''s Bengaluru','MC-3217-012','AHPI Awards','awards_body','Shortlisted for biomedical service excellence award',
     'award_shortlist','2026-07-01','2026-07-01 10:00:00+05:30',8000,'positive',3.60,'patient_safety_outcomes','Priya Nair','award_submission','monitor',null,'Ceremony on 2026-08-20; St John''s joint nomination'),
    ('Rainbow Children''s Hyderabad','MC-3217-013','YourStory','digital_native','How EquipSeva keeps NICU equipment alive at Rainbow',
     'news_feature','2026-06-30','2026-06-30 09:00:00+05:30',65000,'strongly_positive',4.40,'marketplace_trust','Ganesh Kumar','podcast_invite','amplify','2026-06-30 13:00:00+05:30','Founder-story feature; strong inbound from hospitals'),
    ('KIMS Secunderabad','MC-3217-014','CAHOTECH Awards','awards_body','Won best medtech service innovation award with KIMS',
     'award_win','2026-06-28','2026-06-28 19:30:00+05:30',15000,'strongly_positive',4.80,'patient_safety_outcomes','Ganesh Kumar','social_amplification','amplify','2026-06-29 09:00:00+05:30','Trophy photo pack shared with press list')
  ) as q(hosp, ref, outlet, tier, head, mt, cd, pub, reach, sen, ss, km, spk, fu, mv, resp, nt);

  -- CAPA seed — attach to specific mentions
  insert into public.media_coverage_capa_actions_r3217 (
    coverage_id, finding_category, root_cause, corrective_action,
    target_closure_date, actual_closure_date, capa_status, regulatory_impact,
    estimated_cost_rupees, notes
  )
  select e.id, q.fc, q.rc, q.ca, q.tcd::date, q.acd::date, q.cst, q.ri, q.cost, q.nt
  from (values
    ('MC-3217-004','social_backlash','messaging_inconsistent','publish_rebuttal_blog','2026-07-15',null,'in_progress','internal_only',15000.00,'Pricing-transparency explainer drafted for review'),
    ('MC-3217-005','review_bomb','unresolved_customer_complaint','resolve_customer_complaint','2026-07-12','2026-07-11','closed','none',8000.00,'Dialysis repair ticket resolved; reviewer updated to 4 stars'),
    ('MC-3217-008','factual_error_in_article','weak_outlet_relationship','request_correction','2026-07-14',null,'verification_pending','legal_review_needed',20000.00,'Correction request filed with editor; legal reviewing defamation angle'),
    ('MC-3217-010','crisis_escalation','slow_pr_response','issue_press_statement','2026-07-13',null,'escalated','investor_disclosure',75000.00,'War-room opened; statement live in 6 hours; agency retained'),
    ('MC-3217-007','missed_key_message','spokesperson_untrained','media_train_spokesperson','2026-07-20',null,'open','internal_only',40000.00,'Media training workshop booked for AIIMS account team'),
    ('MC-3217-002','pr_process_gap','no_social_listening','set_up_social_listening','2026-07-18',null,'in_progress','none',12000.00,'Positive mention found 3 days late — social listening trial started')
  ) as q(ref, fc, rc, ca, tcd, acd, cst, ri, cost, nt)
  join public.media_coverage_r3217 e
    on e.organization_id = v_org_id and e.mention_ref = q.ref;
end;
$seed$;

-- =============================================================================
-- RPCs — 8 founder-gated rollups
-- =============================================================================

-- 1) Mention verdict distribution
create or replace function public.founder_r3217_mention_verdict_rollup()
returns table(mention_verdict text, mentions bigint, total_reach bigint, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.media_coverage_r3217)
  select l.mention_verdict, count(*)::bigint,
         coalesce(sum(l.reach_estimate),0)::bigint,
         round((count(*)::numeric / nullif((select n from tot),0)) * 100.0, 1)
  from public.media_coverage_r3217 l
  group by l.mention_verdict
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3217_mention_verdict_rollup() from public, anon;
grant execute on function public.founder_r3217_mention_verdict_rollup() to authenticated;

-- 2) Hospital-level PR scorecard
create or replace function public.founder_r3217_hospital_scorecard()
returns table(
  hospital_name text,
  mentions bigint,
  positive_mentions bigint,
  negative_mentions bigint,
  total_reach bigint,
  avg_sentiment_score numeric,
  amplify_count bigint,
  positive_pct numeric
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name,
    count(*)::bigint,
    count(*) filter (where l.sentiment in ('positive','strongly_positive'))::bigint,
    count(*) filter (where l.sentiment in ('negative','strongly_negative'))::bigint,
    coalesce(sum(l.reach_estimate),0)::bigint,
    round(avg(l.sentiment_score), 2),
    count(*) filter (where l.mention_verdict = 'amplify')::bigint,
    round(100.0 * count(*) filter (where l.sentiment in ('positive','strongly_positive'))::numeric / nullif(count(*),0), 1)
  from public.media_coverage_r3217 l
  group by l.hospital_name
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3217_hospital_scorecard() from public, anon;
grant execute on function public.founder_r3217_hospital_scorecard() to authenticated;

-- 3) Outlet tier × mention type matrix
create or replace function public.founder_r3217_outlet_mention_matrix()
returns table(outlet_tier text, mention_type text, mentions bigint, total_reach bigint, avg_sentiment_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.outlet_tier, l.mention_type, count(*)::bigint,
    coalesce(sum(l.reach_estimate),0)::bigint,
    round(avg(l.sentiment_score), 2)
  from public.media_coverage_r3217 l
  group by l.outlet_tier, l.mention_type
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3217_outlet_mention_matrix() from public, anon;
grant execute on function public.founder_r3217_outlet_mention_matrix() to authenticated;

-- 4) Coverage daily trend
create or replace function public.founder_r3217_coverage_daily_trend()
returns table(coverage_date date, mentions bigint, positive_mentions bigint, negative_mentions bigint, total_reach bigint, avg_sentiment_score numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.coverage_date,
    count(*)::bigint,
    count(*) filter (where l.sentiment in ('positive','strongly_positive'))::bigint,
    count(*) filter (where l.sentiment in ('negative','strongly_negative'))::bigint,
    coalesce(sum(l.reach_estimate),0)::bigint,
    round(avg(l.sentiment_score), 2)
  from public.media_coverage_r3217 l
  group by l.coverage_date
  order by l.coverage_date desc;
end;
$$;

revoke execute on function public.founder_r3217_coverage_daily_trend() from public, anon;
grant execute on function public.founder_r3217_coverage_daily_trend() to authenticated;

-- 5) CAPA status board
create or replace function public.founder_r3217_capa_status_board()
returns table(capa_status text, findings bigint, avg_cost_rupees numeric, escalated_or_overdue bigint)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.capa_status, count(*)::bigint,
    round(avg(c.estimated_cost_rupees)::numeric, 0),
    count(*) filter (where c.capa_status in ('overdue','escalated'))::bigint
  from public.media_coverage_capa_actions_r3217 c
  group by c.capa_status
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3217_capa_status_board() from public, anon;
grant execute on function public.founder_r3217_capa_status_board() to authenticated;

-- 6) Root cause pareto
create or replace function public.founder_r3217_root_cause_pareto()
returns table(root_cause text, occurrences bigint, total_cost_rupees numeric, pct numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  with tot as (select count(*)::numeric as n from public.media_coverage_capa_actions_r3217)
  select c.root_cause, count(*)::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric,
    round(count(*)::numeric / nullif((select n from tot),0) * 100.0, 1)
  from public.media_coverage_capa_actions_r3217 c
  group by c.root_cause
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3217_root_cause_pareto() from public, anon;
grant execute on function public.founder_r3217_root_cause_pareto() to authenticated;

-- 7) Regulatory impact digest
create or replace function public.founder_r3217_regulatory_impact_digest()
returns table(regulatory_impact text, findings bigint, open_findings bigint, total_cost_rupees numeric)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select c.regulatory_impact, count(*)::bigint,
    count(*) filter (where c.capa_status in ('open','in_progress','overdue','escalated','verification_pending'))::bigint,
    coalesce(sum(c.estimated_cost_rupees),0)::numeric
  from public.media_coverage_capa_actions_r3217 c
  group by c.regulatory_impact
  order by count(*) desc;
end;
$$;

revoke execute on function public.founder_r3217_regulatory_impact_digest() from public, anon;
grant execute on function public.founder_r3217_regulatory_impact_digest() to authenticated;

-- 8) Priority mentions queue (needs response / correction / crisis handling)
create or replace function public.founder_r3217_priority_mentions_queue()
returns table(
  hospital_name text,
  mention_ref text,
  outlet_name text,
  coverage_date date,
  mention_type text,
  sentiment text,
  mention_verdict text,
  reach_estimate int,
  spokesperson_name text,
  notes text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select l.hospital_name, l.mention_ref, l.outlet_name, l.coverage_date,
    l.mention_type, l.sentiment, l.mention_verdict, l.reach_estimate, l.spokesperson_name, l.notes
  from public.media_coverage_r3217 l
  where l.mention_verdict in ('respond_publicly','correct_record','escalate_crisis')
     or l.sentiment in ('negative','strongly_negative')
  order by l.reach_estimate desc, l.coverage_date desc;
end;
$$;

revoke execute on function public.founder_r3217_priority_mentions_queue() from public, anon;
grant execute on function public.founder_r3217_priority_mentions_queue() to authenticated;
