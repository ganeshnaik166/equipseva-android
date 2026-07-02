BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_press_mentions_r2257 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_name text NOT NULL,
  outlet_type text NOT NULL CHECK (outlet_type IN ('news_article','podcast','blog','newsletter','youtube','linkedin_post','twitter_thread','industry_report','tv_segment')),
  headline text NOT NULL,
  author_name text,
  published_on date NOT NULL,
  url text,
  mention_context text NOT NULL CHECK (mention_context IN ('primary_subject','case_study','quoted_source','passing_reference','comparison_piece','listicle_inclusion','founder_interview')),
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','mixed','negative','very_negative')),
  reach_estimate_readers int NOT NULL DEFAULT 0,
  domain_authority_score int CHECK (domain_authority_score BETWEEN 0 AND 100),
  topic_tag text NOT NULL CHECK (topic_tag IN ('funding','product_launch','hospital_partnership','engineer_network','founder_story','industry_analysis','regulatory','controversy','award','customer_win')),
  key_quote text,
  factual_accuracy text NOT NULL CHECK (factual_accuracy IN ('accurate','mostly_accurate','minor_errors','significant_errors','misleading')),
  response_status text NOT NULL CHECK (response_status IN ('no_action_needed','thank_you_sent','correction_requested','amplified_socially','interview_followup','legal_review','pending_review')),
  amplification_priority text NOT NULL CHECK (amplification_priority IN ('viral_push','share_widely','team_only','no_share','suppress')),
  logged_by uuid REFERENCES public.profiles(id),
  logged_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_press_response_actions_r2257 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mention_id uuid NOT NULL REFERENCES public.founder_press_mentions_r2257(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thank_you_email','social_share','correction_email','followup_pitch','legal_notice','team_briefing','investor_share','crisis_response')),
  action_status text NOT NULL CHECK (action_status IN ('queued','in_progress','completed','blocked','cancelled')),
  assigned_to_email text,
  due_on date,
  completed_on date,
  notes text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_press_mentions_r2257 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_press_response_actions_r2257 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_press_mentions_r2257;
CREATE POLICY founder_all ON public.founder_press_mentions_r2257
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_press_response_actions_r2257;
CREATE POLICY founder_all ON public.founder_press_response_actions_r2257
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_press_mentions_r2257_published ON public.founder_press_mentions_r2257(published_on DESC);
CREATE INDEX IF NOT EXISTS idx_press_mentions_r2257_sentiment ON public.founder_press_mentions_r2257(sentiment);
CREATE INDEX IF NOT EXISTS idx_press_mentions_r2257_topic ON public.founder_press_mentions_r2257(topic_tag);
CREATE INDEX IF NOT EXISTS idx_press_actions_r2257_mention ON public.founder_press_response_actions_r2257(mention_id);
CREATE INDEX IF NOT EXISTS idx_press_actions_r2257_status ON public.founder_press_response_actions_r2257(action_status);

-- RPC 1: Overall press mention summary
CREATE OR REPLACE FUNCTION public.founder_press_summary_r2257()
RETURNS TABLE (
  total_mentions int,
  mentions_last_30d int,
  mentions_last_90d int,
  positive_share_pct numeric,
  negative_share_pct numeric,
  total_reach_estimate bigint,
  avg_domain_authority numeric,
  pending_responses int,
  corrections_requested int,
  unique_outlets int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE m.published_on >= CURRENT_DATE - INTERVAL '30 days'))::int,
    (COUNT(*) FILTER (WHERE m.published_on >= CURRENT_DATE - INTERVAL '90 days'))::int,
    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE m.sentiment IN ('positive','very_positive')) / NULLIF(COUNT(*),0), 1), 0),
    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE m.sentiment IN ('negative','very_negative')) / NULLIF(COUNT(*),0), 1), 0),
    COALESCE(SUM(m.reach_estimate_readers), 0)::bigint,
    COALESCE(ROUND(AVG(m.domain_authority_score), 1), 0),
    (COUNT(*) FILTER (WHERE m.response_status = 'pending_review'))::int,
    (COUNT(*) FILTER (WHERE m.response_status = 'correction_requested'))::int,
    (COUNT(DISTINCT m.outlet_name))::int
  FROM public.founder_press_mentions_r2257 m;
END;
$$;

-- RPC 2: Recent mentions feed
CREATE OR REPLACE FUNCTION public.founder_press_recent_mentions_r2257()
RETURNS TABLE (
  id uuid,
  outlet_name text,
  outlet_type text,
  headline text,
  published_on date,
  sentiment text,
  topic_tag text,
  reach_estimate_readers int,
  domain_authority_score int,
  response_status text,
  amplification_priority text,
  url text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.outlet_name, m.outlet_type, m.headline, m.published_on,
         m.sentiment, m.topic_tag, m.reach_estimate_readers, m.domain_authority_score,
         m.response_status, m.amplification_priority, m.url
  FROM public.founder_press_mentions_r2257 m
  ORDER BY m.published_on DESC, m.logged_at DESC
  LIMIT 100;
END;
$$;

-- RPC 3: Sentiment breakdown by topic
CREATE OR REPLACE FUNCTION public.founder_press_sentiment_by_topic_r2257()
RETURNS TABLE (
  topic_tag text,
  total_mentions int,
  positive_count int,
  neutral_count int,
  negative_count int,
  total_reach bigint,
  avg_authority numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.topic_tag,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('positive','very_positive')))::int,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('neutral','mixed')))::int,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('negative','very_negative')))::int,
    COALESCE(SUM(m.reach_estimate_readers), 0)::bigint,
    COALESCE(ROUND(AVG(m.domain_authority_score), 1), 0)
  FROM public.founder_press_mentions_r2257 m
  GROUP BY m.topic_tag
  ORDER BY COUNT(*) DESC;
END;
$$;

-- RPC 4: Top outlets by reach
CREATE OR REPLACE FUNCTION public.founder_press_top_outlets_r2257()
RETURNS TABLE (
  outlet_name text,
  outlet_type text,
  mention_count int,
  total_reach bigint,
  avg_authority numeric,
  last_mention date,
  positive_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.outlet_name,
    MAX(m.outlet_type),
    (COUNT(*))::int,
    COALESCE(SUM(m.reach_estimate_readers), 0)::bigint,
    COALESCE(ROUND(AVG(m.domain_authority_score), 1), 0),
    MAX(m.published_on),
    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE m.sentiment IN ('positive','very_positive')) / NULLIF(COUNT(*),0), 1), 0)
  FROM public.founder_press_mentions_r2257 m
  GROUP BY m.outlet_name
  ORDER BY SUM(m.reach_estimate_readers) DESC NULLS LAST
  LIMIT 25;
END;
$$;

-- RPC 5: Pending response queue
CREATE OR REPLACE FUNCTION public.founder_press_pending_actions_r2257()
RETURNS TABLE (
  action_id uuid,
  mention_id uuid,
  outlet_name text,
  headline text,
  action_type text,
  action_status text,
  assigned_to_email text,
  due_on date,
  days_until_due int,
  sentiment text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.mention_id,
    m.outlet_name,
    m.headline,
    a.action_type,
    a.action_status,
    a.assigned_to_email,
    a.due_on,
    CASE WHEN a.due_on IS NULL THEN NULL ELSE (a.due_on - CURRENT_DATE)::int END,
    m.sentiment
  FROM public.founder_press_response_actions_r2257 a
  JOIN public.founder_press_mentions_r2257 m ON m.id = a.mention_id
  WHERE a.action_status IN ('queued','in_progress','blocked')
  ORDER BY a.due_on NULLS LAST, a.created_at ASC
  LIMIT 50;
END;
$$;

-- RPC 6: Monthly trend
CREATE OR REPLACE FUNCTION public.founder_press_monthly_trend_r2257()
RETURNS TABLE (
  month_label text,
  mention_count int,
  positive_count int,
  negative_count int,
  total_reach bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    TO_CHAR(date_trunc('month', m.published_on), 'YYYY-MM'),
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('positive','very_positive')))::int,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('negative','very_negative')))::int,
    COALESCE(SUM(m.reach_estimate_readers), 0)::bigint
  FROM public.founder_press_mentions_r2257 m
  WHERE m.published_on >= CURRENT_DATE - INTERVAL '12 months'
  GROUP BY date_trunc('month', m.published_on)
  ORDER BY date_trunc('month', m.published_on) DESC;
END;
$$;

-- RPC 7: Accuracy issues requiring correction
CREATE OR REPLACE FUNCTION public.founder_press_accuracy_issues_r2257()
RETURNS TABLE (
  id uuid,
  outlet_name text,
  headline text,
  published_on date,
  factual_accuracy text,
  sentiment text,
  reach_estimate_readers int,
  response_status text,
  url text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.outlet_name, m.headline, m.published_on,
         m.factual_accuracy, m.sentiment, m.reach_estimate_readers,
         m.response_status, m.url
  FROM public.founder_press_mentions_r2257 m
  WHERE m.factual_accuracy IN ('minor_errors','significant_errors','misleading')
  ORDER BY
    CASE m.factual_accuracy
      WHEN 'misleading' THEN 1
      WHEN 'significant_errors' THEN 2
      WHEN 'minor_errors' THEN 3
    END,
    m.published_on DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_press_summary_r2257() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_press_recent_mentions_r2257() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_press_sentiment_by_topic_r2257() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_press_top_outlets_r2257() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_press_pending_actions_r2257() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_press_monthly_trend_r2257() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_press_accuracy_issues_r2257() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_press_summary_r2257() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_press_recent_mentions_r2257() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_press_sentiment_by_topic_r2257() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_press_top_outlets_r2257() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_press_pending_actions_r2257() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_press_monthly_trend_r2257() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_press_accuracy_issues_r2257() TO authenticated;

-- Seed
INSERT INTO public.founder_press_mentions_r2257 (outlet_name, outlet_type, headline, author_name, published_on, url, mention_context, sentiment, reach_estimate_readers, domain_authority_score, topic_tag, key_quote, factual_accuracy, response_status, amplification_priority)
VALUES
  ('YourStory', 'news_article', 'Equipseva raises seed to fix India hospital equipment uptime', 'Rohan Mehta', CURRENT_DATE - 12, 'https://yourstory.example/equipseva-seed', 'primary_subject', 'very_positive', 85000, 78, 'funding', 'A category-defining play in healthcare ops', 'accurate', 'amplified_socially', 'viral_push'),
  ('The Ken', 'news_article', 'Why hospital biomedical engineers are quitting in droves', 'Anita Rao', CURRENT_DATE - 28, 'https://theken.example/biomed-attrition', 'quoted_source', 'positive', 42000, 82, 'industry_analysis', 'Equipseva CEO called it a quiet crisis', 'mostly_accurate', 'thank_you_sent', 'share_widely'),
  ('TechCrunch India', 'news_article', 'India healthcare SaaS map 2026', 'Vivek Sharma', CURRENT_DATE - 6, 'https://tcin.example/saas-map', 'listicle_inclusion', 'positive', 110000, 85, 'industry_analysis', NULL, 'mostly_accurate', 'pending_review', 'share_widely'),
  ('Healthcare Radius', 'blog', 'Top 10 startups changing hospital operations', 'Priya Nair', CURRENT_DATE - 45, 'https://hcr.example/top10', 'listicle_inclusion', 'very_positive', 18000, 55, 'product_launch', NULL, 'accurate', 'amplified_socially', 'share_widely'),
  ('FoundersFM Podcast', 'podcast', 'Building B2B SaaS for Indian hospitals — Equipseva CEO', 'Karthik Iyer', CURRENT_DATE - 18, 'https://founders.fm/equipseva', 'founder_interview', 'very_positive', 12000, 60, 'founder_story', 'We are the operating system for hospital equipment', 'accurate', 'amplified_socially', 'viral_push'),
  ('LinkedIn Post', 'linkedin_post', 'Equipseva closed Apollo deal — congrats', 'Suresh Kumar', CURRENT_DATE - 3, 'https://linkedin.example/post1', 'passing_reference', 'positive', 4500, 50, 'customer_win', NULL, 'accurate', 'thank_you_sent', 'team_only'),
  ('Inc42', 'news_article', 'Healthtech startups facing payment cycle pressure', 'Megha Joshi', CURRENT_DATE - 35, 'https://inc42.example/payment-cycles', 'passing_reference', 'neutral', 65000, 75, 'industry_analysis', NULL, 'minor_errors', 'correction_requested', 'team_only'),
  ('Twitter Thread', 'twitter_thread', 'Why I love Equipseva as a hospital admin', 'Dr. Ramesh', CURRENT_DATE - 9, 'https://twitter.example/thread1', 'primary_subject', 'very_positive', 8500, 45, 'customer_win', 'Saved us 30% on AMC costs', 'accurate', 'amplified_socially', 'viral_push'),
  ('ETHealthWorld', 'news_article', 'CDSCO tightens equipment maintenance rules', 'Sanjay Verma', CURRENT_DATE - 22, 'https://ethw.example/cdsco-rules', 'quoted_source', 'neutral', 38000, 72, 'regulatory', 'Equipseva welcomes the new norms', 'mostly_accurate', 'thank_you_sent', 'share_widely'),
  ('Random Blog X', 'blog', 'Why startups like Equipseva will fail', 'Anonymous', CURRENT_DATE - 50, 'https://randomblog.example/fail', 'comparison_piece', 'negative', 2000, 25, 'industry_analysis', NULL, 'significant_errors', 'legal_review', 'no_share'),
  ('Medgate India', 'newsletter', 'Newsletter feature: rising biomedical startups', 'Editor Team', CURRENT_DATE - 60, 'https://medgate.example/newsletter', 'listicle_inclusion', 'positive', 22000, 58, 'product_launch', NULL, 'accurate', 'no_action_needed', 'team_only'),
  ('YouTube Channel', 'youtube', 'Hospital tech tour with Equipseva engineer', 'TechMed', CURRENT_DATE - 14, 'https://youtube.example/tour', 'primary_subject', 'positive', 15000, 65, 'engineer_network', NULL, 'accurate', 'amplified_socially', 'share_widely'),
  ('Forbes India', 'news_article', '30 Under 30 — Healthtech', 'Forbes Editorial', CURRENT_DATE - 90, 'https://forbes.example/30u30', 'primary_subject', 'very_positive', 95000, 88, 'award', NULL, 'accurate', 'amplified_socially', 'viral_push'),
  ('BiomedNet Podcast', 'podcast', 'The future of medical equipment servicing', 'Dr. Anand', CURRENT_DATE - 5, 'https://biomednet.example/podcast', 'quoted_source', 'positive', 6500, 52, 'industry_analysis', NULL, 'mostly_accurate', 'pending_review', 'share_widely'),
  ('Mint', 'news_article', 'Hospital chains adopt SaaS for ops — case study Equipseva', 'Neha Singh', CURRENT_DATE - 19, 'https://mint.example/saas-case', 'case_study', 'very_positive', 78000, 80, 'hospital_partnership', 'A 40% uptime improvement in 90 days', 'accurate', 'amplified_socially', 'viral_push');

INSERT INTO public.founder_press_response_actions_r2257 (mention_id, action_type, action_status, assigned_to_email, due_on, completed_on, notes)
SELECT m.id, 'thank_you_email', 'completed', 'pr@equipseva.com', m.published_on + 2, m.published_on + 1, 'Sent thank-you note'
FROM public.founder_press_mentions_r2257 m WHERE m.response_status = 'thank_you_sent' LIMIT 3;

INSERT INTO public.founder_press_response_actions_r2257 (mention_id, action_type, action_status, assigned_to_email, due_on, notes)
SELECT m.id, 'correction_email', 'in_progress', 'pr@equipseva.com', CURRENT_DATE + 3, 'Drafted correction request awaiting CEO review'
FROM public.founder_press_mentions_r2257 m WHERE m.response_status = 'correction_requested' LIMIT 2;

INSERT INTO public.founder_press_response_actions_r2257 (mention_id, action_type, action_status, assigned_to_email, due_on, notes)
SELECT m.id, 'legal_notice', 'queued', 'legal@equipseva.com', CURRENT_DATE + 5, 'Engage counsel on defamatory blog post'
FROM public.founder_press_mentions_r2257 m WHERE m.response_status = 'legal_review' LIMIT 1;

INSERT INTO public.founder_press_response_actions_r2257 (mention_id, action_type, action_status, assigned_to_email, due_on, notes)
SELECT m.id, 'social_share', 'queued', 'social@equipseva.com', CURRENT_DATE + 1, 'Schedule LinkedIn + Twitter amplification'
FROM public.founder_press_mentions_r2257 m WHERE m.response_status = 'pending_review' LIMIT 2;

INSERT INTO public.founder_press_response_actions_r2257 (mention_id, action_type, action_status, assigned_to_email, due_on, notes)
SELECT m.id, 'investor_share', 'queued', 'ceo@equipseva.com', CURRENT_DATE + 7, 'Include in next investor update'
FROM public.founder_press_mentions_r2257 m WHERE m.sentiment = 'very_positive' AND m.topic_tag IN ('funding','award') LIMIT 1;

COMMIT;
