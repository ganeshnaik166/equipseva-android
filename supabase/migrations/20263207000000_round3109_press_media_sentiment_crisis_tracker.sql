-- Round 3109 — Founder Press & Media Coverage Sentiment + Crisis Response Tracker
-- HEAVY ★★★★: outlet × headline × reach × tone × response status × narrative correction queue.

begin;

-- =========================================================================
-- Table 1: press_media_hits_r3109
-- One row per media mention (article, broadcast, podcast, social-amplified post).
-- =========================================================================
create table if not exists public.press_media_hits_r3109 (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  outlet_name     text not null,
  outlet_tier     text not null check (outlet_tier in (
                    'tier1_national','tier2_regional','tier3_trade','tier4_blog','social_amplified'
                  )),
  headline        text not null,
  story_url       text,
  published_at    timestamptz not null,
  reporter_name   text,
  reach_estimate  integer not null check (reach_estimate >= 0),
  sentiment       text not null check (sentiment in (
                    'strongly_positive','positive','neutral','mixed','negative','strongly_negative'
                  )),
  sentiment_score numeric(4,2) not null check (sentiment_score between -1.00 and 1.00),
  topic_cluster   text not null check (topic_cluster in (
                    'product_launch','funding','clinical_outcome','price_strategy',
                    'engineer_story','customer_complaint','regulatory','founder_profile',
                    'partnership','crisis_incident','industry_trend','hiring_culture'
                  )),
  narrative_angle text not null check (narrative_angle in (
                    'on_message','off_message','factual_error','competitor_framing',
                    'leak','rumor','founder_quote_misused','positive_unsolicited'
                  )),
  spokesperson    text check (spokesperson in (
                    'founder_ceo','cto','head_of_engineering','customer_success_lead',
                    'medical_director','none','external_pr_agency'
                  )),
  response_status text not null check (response_status in (
                    'no_response_needed','statement_pending','statement_issued',
                    'correction_requested','correction_published','legal_notice_sent',
                    'rebuttal_drafted','silently_monitor'
                  )),
  syndication_count integer not null default 0 check (syndication_count >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_press_hits_r3109_published on public.press_media_hits_r3109(published_at desc);
create index if not exists idx_press_hits_r3109_sentiment on public.press_media_hits_r3109(sentiment);
create index if not exists idx_press_hits_r3109_topic on public.press_media_hits_r3109(topic_cluster);

alter table public.press_media_hits_r3109 enable row level security;

drop policy if exists press_hits_r3109_founder_all on public.press_media_hits_r3109;
create policy press_hits_r3109_founder_all on public.press_media_hits_r3109
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- =========================================================================
-- Table 2: press_crisis_response_queue_r3109
-- One row per active narrative correction / crisis-response action item.
-- =========================================================================
create table if not exists public.press_crisis_response_queue_r3109 (
  id              uuid primary key default gen_random_uuid(),
  press_hit_id    uuid not null references public.press_media_hits_r3109(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  crisis_severity text not null check (crisis_severity in (
                    'p0_existential','p1_brand_damage','p2_correction','p3_monitor','p4_log_only'
                  )),
  response_playbook text not null check (response_playbook in (
                    'founder_op_ed','press_release','social_thread','direct_outreach',
                    'legal_takedown','do_nothing_let_die','customer_email_blast',
                    'engineer_townhall','investor_memo','regulator_briefing'
                  )),
  assigned_owner  text not null check (assigned_owner in (
                    'founder_ceo','head_of_pr','legal_counsel','customer_success_lead',
                    'cto','medical_director','external_pr_agency','engineering_team_lead'
                  )),
  drafted_response text,
  approval_status text not null check (approval_status in (
                    'draft','founder_review','legal_review','approved','sent','withdrawn'
                  )),
  hours_to_first_response numeric(6,2) check (hours_to_first_response >= 0),
  outcome_status  text not null check (outcome_status in (
                    'pending','correction_secured','headline_changed','retraction_full',
                    'partial_correction','no_traction','negative_spiral','contained'
                  )),
  expected_reach_recovery integer check (expected_reach_recovery >= 0),
  due_at          timestamptz not null,
  closed_at       timestamptz,
  notes           text,
  created_at      timestamptz not null default now()
);

create index if not exists idx_crisis_r3109_severity on public.press_crisis_response_queue_r3109(crisis_severity);
create index if not exists idx_crisis_r3109_due on public.press_crisis_response_queue_r3109(due_at);
create index if not exists idx_crisis_r3109_outcome on public.press_crisis_response_queue_r3109(outcome_status);

alter table public.press_crisis_response_queue_r3109 enable row level security;

drop policy if exists crisis_r3109_founder_all on public.press_crisis_response_queue_r3109;
create policy crisis_r3109_founder_all on public.press_crisis_response_queue_r3109
  for all to authenticated
  using (public.is_founder())
  with check (public.is_founder());

-- =========================================================================
-- Seed data — first organization row, no type filter
-- =========================================================================
do $$
declare
  v_org uuid;
begin
  select id into v_org from public.organizations order by created_at asc limit 1;
  if v_org is null then
    return;
  end if;

  insert into public.press_media_hits_r3109
    (organization_id, outlet_name, outlet_tier, headline, story_url, published_at, reporter_name,
     reach_estimate, sentiment, sentiment_score, topic_cluster, narrative_angle, spokesperson,
     response_status, syndication_count)
  values
    (v_org,'Economic Times Healthworld','tier1_national',
     'equipseva tames India''s medical-equipment downtime problem with engineer marketplace',
     'https://health.economictimes.indiatimes.com/equipseva-marketplace','2026-06-12 09:00+05:30',
     'Rashmi Kaul', 480000, 'strongly_positive', 0.82, 'founder_profile','on_message','founder_ceo',
     'no_response_needed', 14),

    (v_org,'Mint','tier1_national',
     'Hospital chains adopt equipseva AMC bundles as service downtime drops 38%',
     'https://www.livemint.com/equipseva-amc','2026-06-09 07:30+05:30',
     'Devansh Iyer', 320000, 'positive', 0.55, 'clinical_outcome','on_message','medical_director',
     'no_response_needed', 9),

    (v_org,'YourStory','tier2_regional',
     'Inside equipseva: how Hyderabad-built marketplace pays field engineers ₹1 lakh+ a month',
     'https://yourstory.com/equipseva-engineers','2026-06-04 11:15+05:30',
     'Anushree Banerjee', 145000, 'strongly_positive', 0.78, 'engineer_story','on_message','head_of_engineering',
     'no_response_needed', 5),

    (v_org,'Inc42','tier2_regional',
     'equipseva raises bridge round; valuation flat amid medtech funding winter',
     'https://inc42.com/equipseva-bridge','2026-05-29 16:40+05:30',
     'Kunal Saxena', 210000, 'mixed', -0.10, 'funding','competitor_framing','founder_ceo',
     'statement_issued', 22),

    (v_org,'MoneyControl','tier1_national',
     'Class-A devices: equipseva''s narrow focus may limit TAM, say analysts',
     'https://moneycontrol.com/equipseva-tam-debate','2026-05-26 14:05+05:30',
     'Pradeep Menon', 290000, 'negative', -0.45, 'price_strategy','off_message','founder_ceo',
     'rebuttal_drafted', 11),

    (v_org,'Medical Buyer Magazine','tier3_trade',
     'Trade view: equipseva spare-part provenance bonding sets a new bar for the channel',
     'https://medicalbuyer.co.in/equipseva-bonding','2026-05-22 10:00+05:30',
     'Dr. Vimal Joshi', 38000, 'strongly_positive', 0.74, 'product_launch','on_message','cto',
     'no_response_needed', 3),

    (v_org,'Dental Tribune India','tier3_trade',
     'Dental clinic owners flag delayed compressor servicing, equipseva responds within 4 hours',
     'https://in.dental-tribune.com/equipseva-dental-sla','2026-05-18 12:20+05:30',
     'Smita Rao', 21000, 'positive', 0.42, 'customer_complaint','on_message','customer_success_lead',
     'statement_issued', 2),

    (v_org,'The Ken','tier2_regional',
     'The fragile economics of equipseva''s tiered engineer ladder',
     'https://the-ken.com/story/equipseva-engineer-ladder','2026-05-14 06:30+05:30',
     'Olina Banerji', 95000, 'negative', -0.55, 'engineer_story','factual_error','founder_ceo',
     'correction_requested', 4),

    (v_org,'X (Twitter) viral thread','social_amplified',
     'Surgeon thread: "equipseva quoted me ₹40k for a board swap that costs ₹6k on Amazon"',
     'https://x.com/drsurgblr/status/1934','2026-05-11 21:14+05:30',
     '@drsurgblr', 620000, 'strongly_negative', -0.88, 'price_strategy','founder_quote_misused','founder_ceo',
     'statement_issued', 47),

    (v_org,'Reuters Health','tier1_national',
     'India''s CDSCO names equipseva in voluntary spare-part traceability pilot',
     'https://www.reuters.com/healthcare/equipseva-cdsco','2026-05-07 18:00+05:30',
     'Krishna Das', 540000, 'positive', 0.62, 'regulatory','on_message','medical_director',
     'no_response_needed', 31),

    (v_org,'Reddit r/IndianMedicalDevices','social_amplified',
     'AMA leaked: alleged equipseva internal memo on engineer poaching by competitor',
     'https://reddit.com/r/IMD/equipseva-leak','2026-05-03 23:55+05:30',
     'u/medtechwatcher', 180000, 'mixed', -0.20, 'hiring_culture','leak','none',
     'silently_monitor', 18),

    (v_org,'Times of India Hyderabad','tier1_national',
     'equipseva engineer wins state award for restoring rural hospital ventilator in 11 hours',
     'https://timesofindia.indiatimes.com/equipseva-engineer-award','2026-04-28 08:45+05:30',
     'Sridhar Reddy', 410000, 'strongly_positive', 0.90, 'engineer_story','positive_unsolicited','head_of_engineering',
     'no_response_needed', 17),

    (v_org,'BW Healthcare World','tier3_trade',
     'Partnership: equipseva teams up with state hospital association for AMC bulk-buy',
     'https://bwhealthcareworld.com/equipseva-partnership','2026-04-21 11:00+05:30',
     'Neelam Gupta', 52000, 'positive', 0.50, 'partnership','on_message','founder_ceo',
     'no_response_needed', 6),

    (v_org,'India Today','tier1_national',
     'Question of accountability: who pays when a serviced equipment fails mid-surgery?',
     'https://www.indiatoday.in/equipseva-accountability','2026-04-18 13:30+05:30',
     'Manisha Bhalla', 380000, 'negative', -0.62, 'crisis_incident','off_message','founder_ceo',
     'legal_notice_sent', 12);

  insert into public.press_crisis_response_queue_r3109
    (press_hit_id, organization_id, crisis_severity, response_playbook, assigned_owner,
     drafted_response, approval_status, hours_to_first_response, outcome_status,
     expected_reach_recovery, due_at, closed_at, notes)
  select
    h.id, v_org, q.crisis_severity, q.response_playbook, q.assigned_owner,
    q.drafted_response, q.approval_status, q.hours_to_first_response, q.outcome_status,
    q.expected_reach_recovery, q.due_at::timestamptz, q.closed_at::timestamptz, q.notes
  from public.press_media_hits_r3109 h
  join (values
    ('Surgeon thread: "equipseva quoted me ₹40k for a board swap that costs ₹6k on Amazon"',
     'p0_existential','founder_op_ed','founder_ceo',
     'Drafting a transparency thread: BoM cost vs full-warranty service cost with CE markings.',
     'founder_review', 2.50, 'partial_correction', 350000,
     '2026-05-13 09:00+05:30', null,
     'Spike on X; founder thread + Mint op-ed combo planned.'),

    ('Question of accountability: who pays when a serviced equipment fails mid-surgery?',
     'p1_brand_damage','legal_takedown','legal_counsel',
     'Legal notice drafted citing factual inaccuracy on liability clause.',
     'sent', 6.00, 'negative_spiral', 0,
     '2026-04-20 18:00+05:30', null,
     'Outlet refused correction; escalating to PCI.'),

    ('The fragile economics of equipseva''s tiered engineer ladder',
     'p2_correction','direct_outreach','head_of_pr',
     'Outreach to editor with reconciled payout data; offered on-record interview.',
     'approved', 18.00, 'correction_secured', 70000,
     '2026-05-17 12:00+05:30', '2026-05-19 11:00+05:30',
     'Got footnote correction on tier-percentile claim.'),

    ('AMA leaked: alleged equipseva internal memo on engineer poaching by competitor',
     'p2_correction','do_nothing_let_die','external_pr_agency',
     null,
     'approved', 0.00, 'contained', 120000,
     '2026-05-05 09:00+05:30', '2026-05-08 12:00+05:30',
     'Decision: silent monitor; thread died organically in 72h.'),

    ('Class-A devices: equipseva''s narrow focus may limit TAM, say analysts',
     'p2_correction','founder_op_ed','founder_ceo',
     'Op-ed draft: why super-specialty focus beats horizontal sprawl in India medtech.',
     'draft', null, 'pending', 200000,
     '2026-05-30 18:00+05:30', null,
     'Founder writing personally; legal-light review only.'),

    ('equipseva raises bridge round; valuation flat amid medtech funding winter',
     'p3_monitor','investor_memo','founder_ceo',
     'Investor memo: bridge rationale + 18-month runway math; no public statement.',
     'approved', 4.50, 'contained', 0,
     '2026-05-31 17:00+05:30', '2026-06-02 10:30+05:30',
     'LP confidence reaffirmed; no public escalation needed.'),

    ('Dental clinic owners flag delayed compressor servicing, equipseva responds within 4 hours',
     'p4_log_only','customer_email_blast','customer_success_lead',
     'Customer success follow-up email to affected dental clinics.',
     'sent', 3.50, 'contained', 18000,
     '2026-05-20 11:00+05:30', '2026-05-21 16:00+05:30',
     'NPS recovery confirmed for 9/12 named clinics.'),

    ('Hospital chains adopt equipseva AMC bundles as service downtime drops 38%',
     'p4_log_only','press_release','head_of_pr',
     'Logged for quarterly press kit; no active response.',
     'approved', 0.00, 'contained', 0,
     '2026-06-12 09:00+05:30', '2026-06-12 09:30+05:30',
     'Positive coverage; recycled into investor deck.'),

    ('equipseva tames India''s medical-equipment downtime problem with engineer marketplace',
     'p4_log_only','social_thread','founder_ceo',
     'Founder quote-tweeted with engineer photos; amplified organically.',
     'sent', 1.00, 'contained', 0,
     '2026-06-13 10:00+05:30', '2026-06-13 12:00+05:30',
     'Followers +1.2k in 24h.'),

    ('Inside equipseva: how Hyderabad-built marketplace pays field engineers ₹1 lakh+ a month',
     'p4_log_only','engineer_townhall','engineering_team_lead',
     'Townhall recording shared; engineers proud, recruiting funnel boost expected.',
     'sent', 8.00, 'contained', 0,
     '2026-06-06 18:00+05:30', '2026-06-07 19:30+05:30',
     'Engineer applications +47% in 7 days post-story.'),

    ('India''s CDSCO names equipseva in voluntary spare-part traceability pilot',
     'p3_monitor','regulator_briefing','medical_director',
     'CDSCO follow-up briefing scheduled; reinforces compliance posture.',
     'approved', 12.00, 'contained', 0,
     '2026-05-09 15:00+05:30', '2026-05-10 11:00+05:30',
     'CDSCO program-officer happy with public framing.'),

    ('equipseva engineer wins state award for restoring rural hospital ventilator in 11 hours',
     'p4_log_only','social_thread','founder_ceo',
     'Founder posted hero-story thread; engineer interviewed on regional TV.',
     'sent', 0.50, 'contained', 0,
     '2026-04-29 10:00+05:30', '2026-04-29 22:00+05:30',
     'Engineer NPS-of-pride sky-high; retained tier-A engineer at risk of poaching.')
  ) as q(headline_match, crisis_severity, response_playbook, assigned_owner, drafted_response,
         approval_status, hours_to_first_response, outcome_status, expected_reach_recovery,
         due_at, closed_at, notes)
  on h.headline = q.headline_match;
end$$;

-- =========================================================================
-- RPC 1: rpc_press_overview_r3109
-- =========================================================================
create or replace function public.rpc_press_overview_r3109()
returns table (
  outlet_tier text,
  total_hits bigint,
  total_reach bigint,
  avg_sentiment numeric,
  negative_share numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.outlet_tier,
    count(*)::bigint,
    sum(h.reach_estimate)::bigint,
    round(avg(h.sentiment_score)::numeric, 3),
    round((sum(case when h.sentiment in ('negative','strongly_negative') then 1 else 0 end)::numeric
           / nullif(count(*),0)::numeric) * 100, 1)
  from public.press_media_hits_r3109 h
  group by h.outlet_tier
  order by total_reach desc;
end$$;

revoke execute on function public.rpc_press_overview_r3109() from public, anon;
grant execute on function public.rpc_press_overview_r3109() to authenticated;

-- =========================================================================
-- RPC 2: rpc_press_topic_rollup_r3109
-- =========================================================================
create or replace function public.rpc_press_topic_rollup_r3109()
returns table (
  topic_cluster text,
  hits bigint,
  reach bigint,
  avg_sentiment numeric,
  off_message_count bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.topic_cluster,
    count(*)::bigint,
    sum(h.reach_estimate)::bigint,
    round(avg(h.sentiment_score)::numeric, 3),
    sum(case when h.narrative_angle in ('off_message','factual_error','competitor_framing',
                                       'leak','founder_quote_misused') then 1 else 0 end)::bigint
  from public.press_media_hits_r3109 h
  group by h.topic_cluster
  order by reach desc;
end$$;

revoke execute on function public.rpc_press_topic_rollup_r3109() from public, anon;
grant execute on function public.rpc_press_topic_rollup_r3109() to authenticated;

-- =========================================================================
-- RPC 3: rpc_press_sentiment_trend_r3109 — 14-day rolling
-- =========================================================================
create or replace function public.rpc_press_sentiment_trend_r3109()
returns table (
  hit_date date,
  hits bigint,
  weighted_sentiment numeric,
  total_reach bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    (h.published_at at time zone 'Asia/Kolkata')::date,
    count(*)::bigint,
    round(
      (sum(h.sentiment_score * h.reach_estimate)::numeric
       / nullif(sum(h.reach_estimate),0)::numeric),
      3),
    sum(h.reach_estimate)::bigint
  from public.press_media_hits_r3109 h
  group by (h.published_at at time zone 'Asia/Kolkata')::date
  order by hit_date desc;
end$$;

revoke execute on function public.rpc_press_sentiment_trend_r3109() from public, anon;
grant execute on function public.rpc_press_sentiment_trend_r3109() to authenticated;

-- =========================================================================
-- RPC 4: rpc_press_spokesperson_perf_r3109
-- =========================================================================
create or replace function public.rpc_press_spokesperson_perf_r3109()
returns table (
  spokesperson text,
  hits bigint,
  avg_sentiment numeric,
  reach bigint,
  on_message_share numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    coalesce(h.spokesperson, 'unassigned'),
    count(*)::bigint,
    round(avg(h.sentiment_score)::numeric, 3),
    sum(h.reach_estimate)::bigint,
    round((sum(case when h.narrative_angle = 'on_message' then 1 else 0 end)::numeric
           / nullif(count(*),0)::numeric) * 100, 1)
  from public.press_media_hits_r3109 h
  group by h.spokesperson
  order by reach desc;
end$$;

revoke execute on function public.rpc_press_spokesperson_perf_r3109() from public, anon;
grant execute on function public.rpc_press_spokesperson_perf_r3109() to authenticated;

-- =========================================================================
-- RPC 5: rpc_press_response_status_r3109
-- =========================================================================
create or replace function public.rpc_press_response_status_r3109()
returns table (
  response_status text,
  hits bigint,
  reach bigint,
  avg_sentiment numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.response_status,
    count(*)::bigint,
    sum(h.reach_estimate)::bigint,
    round(avg(h.sentiment_score)::numeric, 3)
  from public.press_media_hits_r3109 h
  group by h.response_status
  order by hits desc;
end$$;

revoke execute on function public.rpc_press_response_status_r3109() from public, anon;
grant execute on function public.rpc_press_response_status_r3109() to authenticated;

-- =========================================================================
-- RPC 6: rpc_press_top_hits_r3109
-- =========================================================================
create or replace function public.rpc_press_top_hits_r3109()
returns table (
  outlet_name text,
  outlet_tier text,
  headline text,
  reach_estimate integer,
  sentiment text,
  sentiment_score numeric,
  response_status text,
  published_at timestamptz
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.outlet_name, h.outlet_tier, h.headline, h.reach_estimate,
    h.sentiment, h.sentiment_score, h.response_status, h.published_at
  from public.press_media_hits_r3109 h
  order by h.reach_estimate desc
  limit 25;
end$$;

revoke execute on function public.rpc_press_top_hits_r3109() from public, anon;
grant execute on function public.rpc_press_top_hits_r3109() to authenticated;

-- =========================================================================
-- RPC 7: rpc_crisis_severity_rollup_r3109
-- =========================================================================
create or replace function public.rpc_crisis_severity_rollup_r3109()
returns table (
  crisis_severity text,
  active_items bigint,
  closed_items bigint,
  avg_hours_to_first_response numeric,
  recovered_reach bigint
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.crisis_severity,
    sum(case when c.closed_at is null then 1 else 0 end)::bigint,
    sum(case when c.closed_at is not null then 1 else 0 end)::bigint,
    round(avg(c.hours_to_first_response)::numeric, 2),
    sum(coalesce(c.expected_reach_recovery,0))::bigint
  from public.press_crisis_response_queue_r3109 c
  group by c.crisis_severity
  order by c.crisis_severity asc;
end$$;

revoke execute on function public.rpc_crisis_severity_rollup_r3109() from public, anon;
grant execute on function public.rpc_crisis_severity_rollup_r3109() to authenticated;

-- =========================================================================
-- RPC 8: rpc_crisis_playbook_outcomes_r3109
-- =========================================================================
create or replace function public.rpc_crisis_playbook_outcomes_r3109()
returns table (
  response_playbook text,
  total bigint,
  positive_outcomes bigint,
  negative_outcomes bigint,
  avg_hours_to_first_response numeric
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    c.response_playbook,
    count(*)::bigint,
    sum(case when c.outcome_status in ('correction_secured','headline_changed','retraction_full',
                                      'partial_correction','contained') then 1 else 0 end)::bigint,
    sum(case when c.outcome_status in ('no_traction','negative_spiral') then 1 else 0 end)::bigint,
    round(avg(c.hours_to_first_response)::numeric, 2)
  from public.press_crisis_response_queue_r3109 c
  group by c.response_playbook
  order by total desc;
end$$;

revoke execute on function public.rpc_crisis_playbook_outcomes_r3109() from public, anon;
grant execute on function public.rpc_crisis_playbook_outcomes_r3109() to authenticated;

-- =========================================================================
-- RPC 9: rpc_crisis_open_queue_r3109
-- =========================================================================
create or replace function public.rpc_crisis_open_queue_r3109()
returns table (
  headline text,
  outlet_name text,
  crisis_severity text,
  response_playbook text,
  assigned_owner text,
  approval_status text,
  outcome_status text,
  due_at timestamptz
)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    h.headline, h.outlet_name, c.crisis_severity, c.response_playbook,
    c.assigned_owner, c.approval_status, c.outcome_status, c.due_at
  from public.press_crisis_response_queue_r3109 c
  join public.press_media_hits_r3109 h on h.id = c.press_hit_id
  where c.closed_at is null
  order by
    case c.crisis_severity
      when 'p0_existential' then 0
      when 'p1_brand_damage' then 1
      when 'p2_correction' then 2
      when 'p3_monitor' then 3
      else 4 end asc,
    c.due_at asc;
end$$;

revoke execute on function public.rpc_crisis_open_queue_r3109() from public, anon;
grant execute on function public.rpc_crisis_open_queue_r3109() to authenticated;

commit;
