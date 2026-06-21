BEGIN;

-- ============================================================================
-- Round 1770: Founder Press Outreach Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_press_outreach_r1770 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_name text NOT NULL,
  journalist_name text NOT NULL,
  journalist_email text NOT NULL,
  pitch_subject text NOT NULL,
  pitched_at timestamptz NOT NULL DEFAULT now(),
  response_received boolean NOT NULL DEFAULT false,
  response_summary text,
  outcome text NOT NULL DEFAULT 'no_response'
    CHECK (outcome IN ('no_response','passed','in_review','published')),
  published_at timestamptz,
  story_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_press_pitch_topics_r1770 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outreach_id uuid NOT NULL REFERENCES public.founder_press_outreach_r1770(id) ON DELETE CASCADE,
  topic text NOT NULL
    CHECK (topic IN ('funding','customer_milestone','product_launch','team_growth','industry_commentary')),
  topic_weight int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (outreach_id, topic)
);

CREATE INDEX IF NOT EXISTS idx_fpo_r1770_pitched_at ON public.founder_press_outreach_r1770(pitched_at DESC);
CREATE INDEX IF NOT EXISTS idx_fpo_r1770_outlet ON public.founder_press_outreach_r1770(outlet_name);
CREATE INDEX IF NOT EXISTS idx_fppt_r1770_outreach ON public.founder_press_pitch_topics_r1770(outreach_id);

ALTER TABLE public.founder_press_outreach_r1770 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_press_pitch_topics_r1770 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fpo_r1770_founder ON public.founder_press_outreach_r1770;
CREATE POLICY fpo_r1770_founder ON public.founder_press_outreach_r1770
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fppt_r1770_founder ON public.founder_press_pitch_topics_r1770;
CREATE POLICY fppt_r1770_founder ON public.founder_press_pitch_topics_r1770
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r1770_list_outreach()
RETURNS TABLE (
  id uuid,
  outlet_name text,
  journalist_name text,
  journalist_email text,
  pitch_subject text,
  pitched_at timestamptz,
  response_received boolean,
  response_summary text,
  outcome text,
  published_at timestamptz,
  story_url text
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
  SELECT o.id, o.outlet_name, o.journalist_name, o.journalist_email,
         o.pitch_subject, o.pitched_at, o.response_received, o.response_summary,
         o.outcome, o.published_at, o.story_url
  FROM public.founder_press_outreach_r1770 o
  ORDER BY o.pitched_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1770_log_pitch(
  p_outlet text,
  p_journalist text,
  p_email text,
  p_subject text
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
  INSERT INTO public.founder_press_outreach_r1770
    (outlet_name, journalist_name, journalist_email, pitch_subject)
  VALUES (p_outlet, p_journalist, p_email, p_subject)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1770_log_pitch',
          jsonb_build_object('id', v_id, 'outlet', p_outlet, 'journalist', p_journalist));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1770_list_topics(p_outreach_id uuid)
RETURNS TABLE (
  id uuid,
  outreach_id uuid,
  topic text,
  topic_weight int
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
  SELECT t.id, t.outreach_id, t.topic, t.topic_weight
  FROM public.founder_press_pitch_topics_r1770 t
  WHERE t.outreach_id = p_outreach_id
  ORDER BY t.topic_weight DESC, t.topic ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1770_set_topic(
  p_outreach_id uuid,
  p_topic text,
  p_weight int
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
  INSERT INTO public.founder_press_pitch_topics_r1770 (outreach_id, topic, topic_weight)
  VALUES (p_outreach_id, p_topic, COALESCE(p_weight, 1))
  ON CONFLICT (outreach_id, topic) DO UPDATE
    SET topic_weight = EXCLUDED.topic_weight,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1770_set_topic',
          jsonb_build_object('outreach_id', p_outreach_id, 'topic', p_topic, 'weight', p_weight));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1770_mark_published(
  p_outreach_id uuid,
  p_story_url text,
  p_summary text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_press_outreach_r1770
     SET outcome = 'published',
         response_received = true,
         response_summary = COALESCE(p_summary, response_summary),
         story_url = p_story_url,
         published_at = now(),
         updated_at = now()
   WHERE id = p_outreach_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1770_mark_published',
          jsonb_build_object('outreach_id', p_outreach_id, 'story_url', p_story_url));
END;
$$;

CREATE OR REPLACE FUNCTION public.r1770_response_rate_summary()
RETURNS TABLE (
  total_pitched int,
  responded int,
  passed int,
  in_review int,
  published int,
  response_rate_pct numeric
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
    COUNT(*)::int AS total_pitched,
    (COUNT(*) FILTER (WHERE response_received))::int AS responded,
    (COUNT(*) FILTER (WHERE outcome = 'passed'))::int AS passed,
    (COUNT(*) FILTER (WHERE outcome = 'in_review'))::int AS in_review,
    (COUNT(*) FILTER (WHERE outcome = 'published'))::int AS published,
    CASE WHEN COUNT(*) = 0 THEN 0::numeric
         ELSE ROUND((COUNT(*) FILTER (WHERE response_received))::numeric * 100.0 / COUNT(*)::numeric, 2)
    END AS response_rate_pct
  FROM public.founder_press_outreach_r1770;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1770_top_outlets()
RETURNS TABLE (
  outlet_name text,
  pitches int,
  published_count int,
  in_review_count int
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
    o.outlet_name,
    COUNT(*)::int AS pitches,
    (COUNT(*) FILTER (WHERE o.outcome = 'published'))::int AS published_count,
    (COUNT(*) FILTER (WHERE o.outcome = 'in_review'))::int AS in_review_count
  FROM public.founder_press_outreach_r1770 o
  GROUP BY o.outlet_name
  ORDER BY pitches DESC, published_count DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.r1770_list_outreach() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1770_log_pitch(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1770_list_topics(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1770_set_topic(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1770_mark_published(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1770_response_rate_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1770_top_outlets() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1770_list_outreach() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1770_log_pitch(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1770_list_topics(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1770_set_topic(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1770_mark_published(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1770_response_rate_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1770_top_outlets() TO authenticated;

COMMIT;