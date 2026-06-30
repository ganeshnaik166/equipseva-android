-- Round 3125: Founder LinkedIn Authority Tracker
-- Tracks founder personal brand: post cadence x impressions x inbound DMs x meetings x conf invites x media mentions x authority score

begin;

create table if not exists founder_linkedin_posts_r3125 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  posted_at timestamptz not null,
  post_topic text not null check (post_topic in (
    'biomed_engineer_story','hospital_uptime_case','amc_economics','dental_chair_repair',
    'ventilator_war_room','founder_journey','team_culture','industry_take','product_update',
    'customer_milestone','engineer_certification','sla_proof','market_intel','regulatory_dpdp'
  )),
  post_format text not null check (post_format in ('text_long','text_short','carousel','video_native','image_single','image_multi','poll','article','repost')),
  hashtag_cluster text not null check (hashtag_cluster in ('medtech_india','biomedical','hospital_ops','dental_clinic','medical_equipment','startup_india','founder_lessons','engineer_hiring','sla_uptime')),
  impressions int not null default 0 check (impressions >= 0),
  reactions int not null default 0 check (reactions >= 0),
  comments_count int not null default 0 check (comments_count >= 0),
  reshares int not null default 0 check (reshares >= 0),
  profile_visits int not null default 0 check (profile_visits >= 0),
  follower_delta int not null default 0,
  inbound_dms int not null default 0 check (inbound_dms >= 0),
  dm_to_meeting_count int not null default 0 check (dm_to_meeting_count >= 0),
  authority_score numeric(6,2) not null check (authority_score >= 0 and authority_score <= 100),
  created_at timestamptz not null default now()
);

create table if not exists founder_authority_signals_r3125 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  signal_at timestamptz not null,
  signal_type text not null check (signal_type in (
    'conference_invite','podcast_invite','media_mention','quote_request',
    'panel_speaker','jury_invite','book_blurb_ask','newsletter_feature',
    'inbound_partnership','inbound_investor','inbound_hire','customer_referral'
  )),
  signal_source text not null check (signal_source in (
    'linkedin_dm','linkedin_comment','email_inbound','twitter_dm','event_organizer',
    'journalist_outreach','referred_by_advisor','referred_by_customer','warm_intro'
  )),
  outlet_or_event text not null,
  reach_estimate int not null default 0 check (reach_estimate >= 0),
  meeting_booked boolean not null default false,
  meeting_outcome text check (meeting_outcome in ('pending','converted','passed','no_show','rescheduled','exploratory')),
  meeting_value_rupees bigint check (meeting_value_rupees is null or meeting_value_rupees >= 0),
  authority_score_delta numeric(5,2) not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_flp_r3125_posted on founder_linkedin_posts_r3125(posted_at desc);
create index if not exists idx_flp_r3125_topic on founder_linkedin_posts_r3125(post_topic);
create index if not exists idx_fas_r3125_signal on founder_authority_signals_r3125(signal_at desc);
create index if not exists idx_fas_r3125_type on founder_authority_signals_r3125(signal_type);

-- Seed 12+ rows
do $seed$
declare
  v_org_id uuid;
begin
  select id into v_org_id from organizations order by created_at asc limit 1;
  if v_org_id is null then
    return;
  end if;

  insert into founder_linkedin_posts_r3125
    (organization_id, posted_at, post_topic, post_format, hashtag_cluster, impressions, reactions, comments_count, reshares, profile_visits, follower_delta, inbound_dms, dm_to_meeting_count, authority_score)
  values
    (v_org_id, now() - interval '28 days', 'biomed_engineer_story', 'text_long', 'biomedical', 18400, 412, 78, 41, 312, 87, 24, 6, 62.40),
    (v_org_id, now() - interval '24 days', 'ventilator_war_room', 'carousel', 'hospital_ops', 31200, 689, 142, 88, 521, 134, 38, 11, 71.80),
    (v_org_id, now() - interval '21 days', 'amc_economics', 'text_long', 'medical_equipment', 12800, 245, 52, 19, 188, 41, 14, 3, 54.20),
    (v_org_id, now() - interval '18 days', 'dental_chair_repair', 'video_native', 'dental_clinic', 27500, 521, 96, 62, 398, 102, 29, 7, 68.90),
    (v_org_id, now() - interval '14 days', 'founder_journey', 'text_long', 'founder_lessons', 41200, 892, 218, 134, 712, 198, 56, 18, 78.60),
    (v_org_id, now() - interval '11 days', 'sla_proof', 'image_multi', 'sla_uptime', 9400, 187, 34, 12, 142, 28, 9, 2, 48.50),
    (v_org_id, now() - interval '8 days',  'engineer_certification', 'carousel', 'engineer_hiring', 22100, 478, 87, 51, 341, 96, 21, 5, 65.30),
    (v_org_id, now() - interval '5 days',  'industry_take', 'article', 'medtech_india', 38600, 812, 196, 121, 624, 167, 47, 14, 75.40),
    (v_org_id, now() - interval '3 days',  'customer_milestone', 'image_single', 'medtech_india', 16700, 389, 64, 28, 261, 72, 18, 4, 58.70),
    (v_org_id, now() - interval '1 days',  'regulatory_dpdp', 'text_long', 'medical_equipment', 14200, 298, 71, 22, 198, 54, 16, 3, 56.10);

  insert into founder_authority_signals_r3125
    (organization_id, signal_at, signal_type, signal_source, outlet_or_event, reach_estimate, meeting_booked, meeting_outcome, meeting_value_rupees, authority_score_delta, notes)
  values
    (v_org_id, now() - interval '26 days', 'conference_invite',   'event_organizer',     'India MedTech Summit 2026',           4500,  true,  'converted',     0,             4.20, 'Keynote slot day 2 confirmed'),
    (v_org_id, now() - interval '22 days', 'media_mention',       'journalist_outreach', 'Economic Times Health',                85000, false, null,            null,          3.10, 'Quoted on AMC unit economics'),
    (v_org_id, now() - interval '19 days', 'podcast_invite',      'linkedin_dm',         'Indian Startup Podcast',              12000, true,  'converted',     0,             2.80, 'Recorded 60 min episode'),
    (v_org_id, now() - interval '15 days', 'inbound_investor',    'linkedin_dm',         'Blume Ventures partner ping',          0,    true,  'exploratory',   0,             5.40, 'Pre-Series A timing chat'),
    (v_org_id, now() - interval '12 days', 'inbound_partnership', 'email_inbound',       'Apollo Hospitals BMC head',            0,    true,  'converted',     2400000,       6.20, 'Tier 1 chain pilot scoped'),
    (v_org_id, now() - interval '9 days',  'quote_request',       'journalist_outreach', 'Forbes India 30U30 angle',             65000, true,  'pending',       null,          2.40, 'Background interview done'),
    (v_org_id, now() - interval '7 days',  'panel_speaker',       'event_organizer',     'NASSCOM Healthtech Roundtable',        2200, true,  'converted',     0,             3.60, 'Panel on rural service models'),
    (v_org_id, now() - interval '5 days',  'newsletter_feature',  'linkedin_comment',    'Sajith Pai operator newsletter',       18000, false, null,            null,          2.10, 'Featured as case study'),
    (v_org_id, now() - interval '4 days',  'inbound_hire',        'linkedin_dm',         'Ex-Siemens biomed senior engineer',    0,    true,  'converted',     0,             1.80, 'Joined as Bangalore lead'),
    (v_org_id, now() - interval '2 days',  'customer_referral',   'referred_by_customer','Manipal Hospitals Vizag intro',        0,    true,  'pending',       null,          1.40, 'Warm intro via Apollo BMC'),
    (v_org_id, now() - interval '1 days',  'jury_invite',         'event_organizer',     'TiE Hyderabad startup awards jury',    3500, true,  'converted',     0,             2.20, 'Healthtech vertical jury'),
    (v_org_id, now() - interval '12 hours','inbound_partnership', 'warm_intro',          'Cashfree health vertical lead',        0,    true,  'exploratory',   null,          1.90, 'Embedded finance pilot ask');
end;
$seed$;

-- RPC 1: post performance rollup
create or replace function rpc_r3125_post_performance()
returns table(
  post_topic text,
  posts_count bigint,
  total_impressions bigint,
  avg_authority numeric,
  total_dms bigint,
  total_meetings bigint,
  dm_to_meeting_pct numeric
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      p.post_topic,
      count(*)::bigint,
      sum(p.impressions)::bigint,
      round(avg(p.authority_score), 2),
      sum(p.inbound_dms)::bigint,
      sum(p.dm_to_meeting_count)::bigint,
      case when sum(p.inbound_dms) = 0 then 0
           else round((sum(p.dm_to_meeting_count)::numeric / sum(p.inbound_dms)::numeric) * 100, 2)
      end
    from founder_linkedin_posts_r3125 p
    group by p.post_topic
    order by sum(p.impressions) desc;
end;
$$;

revoke execute on function rpc_r3125_post_performance() from public, anon;
grant execute on function rpc_r3125_post_performance() to authenticated;

-- RPC 2: format effectiveness
create or replace function rpc_r3125_format_effectiveness()
returns table(
  post_format text,
  posts bigint,
  avg_impressions numeric,
  avg_engagement_rate numeric,
  avg_authority numeric
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      p.post_format,
      count(*)::bigint,
      round(avg(p.impressions), 0),
      round(avg(case when p.impressions = 0 then 0
                else ((p.reactions + p.comments_count + p.reshares)::numeric / p.impressions::numeric) * 100
           end), 2),
      round(avg(p.authority_score), 2)
    from founder_linkedin_posts_r3125 p
    group by p.post_format
    order by avg(p.impressions) desc;
end;
$$;

revoke execute on function rpc_r3125_format_effectiveness() from public, anon;
grant execute on function rpc_r3125_format_effectiveness() to authenticated;

-- RPC 3: cadence weekly
create or replace function rpc_r3125_weekly_cadence()
returns table(
  week_start date,
  posts bigint,
  total_impressions bigint,
  follower_delta bigint,
  avg_authority numeric
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      date_trunc('week', p.posted_at)::date,
      count(*)::bigint,
      sum(p.impressions)::bigint,
      sum(p.follower_delta)::bigint,
      round(avg(p.authority_score), 2)
    from founder_linkedin_posts_r3125 p
    group by date_trunc('week', p.posted_at)
    order by date_trunc('week', p.posted_at) desc;
end;
$$;

revoke execute on function rpc_r3125_weekly_cadence() from public, anon;
grant execute on function rpc_r3125_weekly_cadence() to authenticated;

-- RPC 4: authority signal funnel
create or replace function rpc_r3125_signal_funnel()
returns table(
  signal_type text,
  signals bigint,
  meetings_booked bigint,
  converted bigint,
  conversion_pct numeric,
  total_value_rupees bigint
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      s.signal_type,
      count(*)::bigint,
      sum(case when s.meeting_booked then 1 else 0 end)::bigint,
      sum(case when s.meeting_outcome = 'converted' then 1 else 0 end)::bigint,
      case when count(*) = 0 then 0
           else round((sum(case when s.meeting_outcome = 'converted' then 1 else 0 end)::numeric / count(*)::numeric) * 100, 2)
      end,
      coalesce(sum(s.meeting_value_rupees), 0)::bigint
    from founder_authority_signals_r3125 s
    group by s.signal_type
    order by count(*) desc;
end;
$$;

revoke execute on function rpc_r3125_signal_funnel() from public, anon;
grant execute on function rpc_r3125_signal_funnel() to authenticated;

-- RPC 5: source attribution
create or replace function rpc_r3125_source_attribution()
returns table(
  signal_source text,
  signals bigint,
  total_reach bigint,
  authority_delta numeric,
  meetings_converted bigint
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      s.signal_source,
      count(*)::bigint,
      sum(s.reach_estimate)::bigint,
      round(sum(s.authority_score_delta), 2),
      sum(case when s.meeting_outcome = 'converted' then 1 else 0 end)::bigint
    from founder_authority_signals_r3125 s
    group by s.signal_source
    order by sum(s.authority_score_delta) desc;
end;
$$;

revoke execute on function rpc_r3125_source_attribution() from public, anon;
grant execute on function rpc_r3125_source_attribution() to authenticated;

-- RPC 6: top performing posts
create or replace function rpc_r3125_top_posts()
returns table(
  posted_at timestamptz,
  post_topic text,
  post_format text,
  impressions int,
  inbound_dms int,
  dm_to_meeting_count int,
  authority_score numeric
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select p.posted_at, p.post_topic, p.post_format, p.impressions, p.inbound_dms, p.dm_to_meeting_count, p.authority_score
    from founder_linkedin_posts_r3125 p
    order by p.authority_score desc, p.impressions desc
    limit 10;
end;
$$;

revoke execute on function rpc_r3125_top_posts() from public, anon;
grant execute on function rpc_r3125_top_posts() to authenticated;

-- RPC 7: high value inbound queue
create or replace function rpc_r3125_inbound_queue()
returns table(
  signal_at timestamptz,
  signal_type text,
  outlet_or_event text,
  signal_source text,
  meeting_outcome text,
  meeting_value_rupees bigint,
  notes text
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select s.signal_at, s.signal_type, s.outlet_or_event, s.signal_source,
           coalesce(s.meeting_outcome, 'pending'), s.meeting_value_rupees, s.notes
    from founder_authority_signals_r3125 s
    where s.signal_type in ('inbound_investor','inbound_partnership','inbound_hire','customer_referral','conference_invite')
    order by s.signal_at desc;
end;
$$;

revoke execute on function rpc_r3125_inbound_queue() from public, anon;
grant execute on function rpc_r3125_inbound_queue() to authenticated;

-- RPC 8: authority score trend (combined)
create or replace function rpc_r3125_authority_trend()
returns table(
  period_week date,
  avg_post_authority numeric,
  signal_delta_sum numeric,
  cumulative_score numeric
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    with weeks as (
      select date_trunc('week', posted_at)::date as wk, avg(authority_score) as avg_auth
      from founder_linkedin_posts_r3125
      group by date_trunc('week', posted_at)
    ),
    sig as (
      select date_trunc('week', signal_at)::date as wk, sum(authority_score_delta) as delta_sum
      from founder_authority_signals_r3125
      group by date_trunc('week', signal_at)
    ),
    merged as (
      select coalesce(w.wk, s.wk) as wk,
             coalesce(w.avg_auth, 0) as avg_auth,
             coalesce(s.delta_sum, 0) as delta_sum
      from weeks w
      full outer join sig s on s.wk = w.wk
    )
    select m.wk,
           round(m.avg_auth, 2),
           round(m.delta_sum, 2),
           round(sum(m.avg_auth + m.delta_sum) over (order by m.wk), 2)
    from merged m
    order by m.wk desc;
end;
$$;

revoke execute on function rpc_r3125_authority_trend() from public, anon;
grant execute on function rpc_r3125_authority_trend() to authenticated;

-- RPC 9: pipeline value summary
create or replace function rpc_r3125_pipeline_value()
returns table(
  bucket text,
  signals bigint,
  total_value_rupees bigint
)
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
    select
      coalesce(s.meeting_outcome, 'pending') as bucket,
      count(*)::bigint,
      coalesce(sum(s.meeting_value_rupees), 0)::bigint
    from founder_authority_signals_r3125 s
    group by coalesce(s.meeting_outcome, 'pending')
    order by coalesce(sum(s.meeting_value_rupees), 0) desc;
end;
$$;

revoke execute on function rpc_r3125_pipeline_value() from public, anon;
grant execute on function rpc_r3125_pipeline_value() to authenticated;

commit;
