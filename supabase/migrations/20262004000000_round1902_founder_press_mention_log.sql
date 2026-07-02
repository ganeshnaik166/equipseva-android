BEGIN;

-- =========================================================================
-- Round 1902 — Founder Press Mention Log
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_press_mentions_r1902 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  publication text NOT NULL,
  mention_url text,
  mention_type text NOT NULL CHECK (mention_type IN ('news_article','podcast','interview','quoted','tv','social_post')),
  mention_date date NOT NULL,
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','critical','mixed')),
  reach_estimate int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'tracked' CHECK (status IN ('tracked','follow_up_sent','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_press_outreach_log_r1902 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mention_id uuid NOT NULL REFERENCES public.founder_press_mentions_r1902(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('thank_you_sent','follow_up_offered','exclusive_offered','decline_response')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_press_mentions_r1902 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_press_outreach_log_r1902 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_press_mentions_r1902 ON public.founder_press_mentions_r1902;
CREATE POLICY founder_only_press_mentions_r1902 ON public.founder_press_mentions_r1902
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_press_outreach_r1902 ON public.founder_press_outreach_log_r1902;
CREATE POLICY founder_only_press_outreach_r1902 ON public.founder_press_outreach_log_r1902
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

CREATE OR REPLACE FUNCTION public.list_mentions_r1902()
RETURNS TABLE (
  id uuid,
  publication text,
  mention_url text,
  mention_type text,
  mention_date date,
  sentiment text,
  reach_estimate int,
  status text,
  captured_at timestamptz
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
    SELECT m.id, m.publication, m.mention_url, m.mention_type, m.mention_date,
           m.sentiment, m.reach_estimate, m.status, m.captured_at
    FROM public.founder_press_mentions_r1902 m
    ORDER BY m.mention_date DESC, m.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_mention_r1902(
  p_publication text,
  p_mention_url text,
  p_mention_type text,
  p_mention_date date,
  p_sentiment text,
  p_reach_estimate int
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
  INSERT INTO public.founder_press_mentions_r1902(
    publication, mention_url, mention_type, mention_date, sentiment, reach_estimate
  ) VALUES (
    p_publication, p_mention_url, p_mention_type, p_mention_date, p_sentiment, COALESCE(p_reach_estimate,0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_mention_r1902',
    jsonb_build_object('id', v_id, 'publication', p_publication, 'type', p_mention_type, 'sentiment', p_sentiment)
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_outreach_r1902(p_mention_id uuid)
RETURNS TABLE (
  id uuid,
  mention_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  response_md text
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
    SELECT o.id, o.mention_id, o.action_type, o.taken_at, o.by_email, o.response_md
    FROM public.founder_press_outreach_log_r1902 o
    WHERE o.mention_id = p_mention_id
    ORDER BY o.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_outreach_r1902(
  p_mention_id uuid,
  p_action_type text,
  p_response_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_press_outreach_log_r1902(
    mention_id, action_type, by_email, response_md
  ) VALUES (
    p_mention_id, p_action_type, v_email, p_response_md
  ) RETURNING id INTO v_id;

  UPDATE public.founder_press_mentions_r1902
     SET status = 'follow_up_sent', updated_at = now()
   WHERE id = p_mention_id AND status = 'tracked';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_outreach_r1902',
    jsonb_build_object('id', v_id, 'mention_id', p_mention_id, 'action_type', p_action_type)
  );
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_archived_r1902(p_mention_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_press_mentions_r1902
     SET status = 'archived', updated_at = now()
   WHERE id = p_mention_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_archived_r1902',
    jsonb_build_object('id', p_mention_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.top_publications_r1902()
RETURNS TABLE (
  publication text,
  mentions int,
  total_reach bigint,
  positive_count int,
  critical_count int
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
    SELECT m.publication,
           (COUNT(*))::int AS mentions,
           COALESCE(SUM(m.reach_estimate),0)::bigint AS total_reach,
           (COUNT(*) FILTER (WHERE m.sentiment = 'positive'))::int AS positive_count,
           (COUNT(*) FILTER (WHERE m.sentiment = 'critical'))::int AS critical_count
    FROM public.founder_press_mentions_r1902 m
    GROUP BY m.publication
    ORDER BY mentions DESC, total_reach DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_outreach_r1902()
RETURNS TABLE (
  id uuid,
  mention_id uuid,
  publication text,
  action_type text,
  taken_at timestamptz,
  by_email text
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
    SELECT o.id, o.mention_id, m.publication, o.action_type, o.taken_at, o.by_email
    FROM public.founder_press_outreach_log_r1902 o
    JOIN public.founder_press_mentions_r1902 m ON m.id = o.mention_id
    ORDER BY o.taken_at DESC
    LIMIT 100;
END;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_mentions_r1902() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_mentions_r1902() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_mention_r1902(text, text, text, date, text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_mention_r1902(text, text, text, date, text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_outreach_r1902(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_outreach_r1902(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_outreach_r1902(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_outreach_r1902(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_archived_r1902(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_archived_r1902(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_publications_r1902() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.top_publications_r1902() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_outreach_r1902() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.recent_outreach_r1902() TO authenticated;

COMMIT;
