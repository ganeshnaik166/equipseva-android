BEGIN;

-- ============================================================================
-- Round 1717 — Investor Press Mentions Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_press_mentions_r1717 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  publication text NOT NULL,
  article_title text NOT NULL,
  article_url text,
  published_at timestamptz NOT NULL DEFAULT now(),
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  audience_reach int NOT NULL DEFAULT 0,
  quoted_directly boolean NOT NULL DEFAULT false,
  key_quote_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_press_followups_r1717 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mention_id uuid NOT NULL REFERENCES public.investor_press_mentions_r1717(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thank_email','social_share','quote_in_deck','follow_up_pr')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_press_mentions_r1717_investor ON public.investor_press_mentions_r1717(investor_id);
CREATE INDEX IF NOT EXISTS idx_press_mentions_r1717_published ON public.investor_press_mentions_r1717(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_press_followups_r1717_mention ON public.investor_press_followups_r1717(mention_id);

ALTER TABLE public.investor_press_mentions_r1717 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_press_followups_r1717 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_press_mentions_r1717 ON public.investor_press_mentions_r1717;
CREATE POLICY founder_all_press_mentions_r1717 ON public.investor_press_mentions_r1717
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_press_followups_r1717 ON public.investor_press_followups_r1717;
CREATE POLICY founder_all_press_followups_r1717 ON public.investor_press_followups_r1717
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_mentions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_mentions_r1717();
CREATE OR REPLACE FUNCTION public.list_mentions_r1717()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  publication text,
  article_title text,
  article_url text,
  published_at timestamptz,
  sentiment text,
  audience_reach int,
  quoted_directly boolean,
  key_quote_md text,
  followup_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.investor_id,
    m.publication,
    m.article_title,
    m.article_url,
    m.published_at,
    m.sentiment,
    m.audience_reach,
    m.quoted_directly,
    m.key_quote_md,
    (SELECT COUNT(*) FROM public.investor_press_followups_r1717 f WHERE f.mention_id = m.id)::int
  FROM public.investor_press_mentions_r1717 m
  ORDER BY m.published_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_mention
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_mention_r1717(uuid, text, text, text, timestamptz, text, int, boolean, text);
CREATE OR REPLACE FUNCTION public.log_mention_r1717(
  p_investor_id uuid,
  p_publication text,
  p_article_title text,
  p_article_url text,
  p_published_at timestamptz,
  p_sentiment text,
  p_audience_reach int,
  p_quoted_directly boolean,
  p_key_quote_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_press_mentions_r1717
    (investor_id, publication, article_title, article_url, published_at, sentiment, audience_reach, quoted_directly, key_quote_md)
  VALUES
    (p_investor_id, p_publication, p_article_title, p_article_url, COALESCE(p_published_at, now()), p_sentiment, COALESCE(p_audience_reach,0), COALESCE(p_quoted_directly,false), p_key_quote_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_mention_r1717',
    jsonb_build_object('mention_id', v_id, 'investor_id', p_investor_id, 'publication', p_publication, 'sentiment', p_sentiment)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_followups
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_followups_r1717(uuid);
CREATE OR REPLACE FUNCTION public.list_followups_r1717(p_mention_id uuid)
RETURNS TABLE (
  id uuid,
  mention_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.id, f.mention_id, f.action_type, f.taken_at, f.by_email, f.note
  FROM public.investor_press_followups_r1717 f
  WHERE p_mention_id IS NULL OR f.mention_id = p_mention_id
  ORDER BY f.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: add_followup
-- ============================================================================
DROP FUNCTION IF EXISTS public.add_followup_r1717(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.add_followup_r1717(
  p_mention_id uuid,
  p_action_type text,
  p_by_email text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_press_followups_r1717 (mention_id, action_type, by_email, note)
  VALUES (p_mention_id, p_action_type, p_by_email, p_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_followup_r1717',
    jsonb_build_object('followup_id', v_id, 'mention_id', p_mention_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: sentiment_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.sentiment_summary_r1717();
CREATE OR REPLACE FUNCTION public.sentiment_summary_r1717()
RETURNS TABLE (
  sentiment text,
  mention_count int,
  total_reach bigint,
  avg_reach int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    m.sentiment,
    COUNT(*)::int,
    COALESCE(SUM(m.audience_reach),0)::bigint,
    COALESCE(AVG(m.audience_reach),0)::int
  FROM public.investor_press_mentions_r1717 m
  GROUP BY m.sentiment
  ORDER BY COUNT(*) DESC;
END;
$$;

-- ============================================================================
-- RPC 6: top_publications
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_publications_r1717();
CREATE OR REPLACE FUNCTION public.top_publications_r1717()
RETURNS TABLE (
  publication text,
  mention_count int,
  total_reach bigint,
  positive_count int,
  negative_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    m.publication,
    COUNT(*)::int,
    COALESCE(SUM(m.audience_reach),0)::bigint,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('very_positive','positive')))::int,
    (COUNT(*) FILTER (WHERE m.sentiment IN ('very_negative','negative')))::int
  FROM public.investor_press_mentions_r1717 m
  GROUP BY m.publication
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- RPC 7: recent_positive_quotes
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_positive_quotes_r1717();
CREATE OR REPLACE FUNCTION public.recent_positive_quotes_r1717()
RETURNS TABLE (
  id uuid,
  publication text,
  article_title text,
  article_url text,
  published_at timestamptz,
  sentiment text,
  key_quote_md text,
  audience_reach int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.publication,
    m.article_title,
    m.article_url,
    m.published_at,
    m.sentiment,
    m.key_quote_md,
    m.audience_reach
  FROM public.investor_press_mentions_r1717 m
  WHERE m.sentiment IN ('very_positive','positive')
    AND m.quoted_directly = true
    AND m.key_quote_md IS NOT NULL
  ORDER BY m.published_at DESC
  LIMIT 25;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_mentions_r1717() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_mentions_r1717() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_mention_r1717(uuid, text, text, text, timestamptz, text, int, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_mention_r1717(uuid, text, text, text, timestamptz, text, int, boolean, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_followups_r1717(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followups_r1717(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.add_followup_r1717(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_followup_r1717(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.sentiment_summary_r1717() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sentiment_summary_r1717() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_publications_r1717() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_publications_r1717() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_positive_quotes_r1717() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_positive_quotes_r1717() TO authenticated;

COMMIT;