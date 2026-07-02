BEGIN;

-- ============================================================
-- r1815 — Hospital Win Stories Library
-- ============================================================

CREATE TABLE IF NOT EXISTS public.hospital_win_stories_r1815 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  story_title text NOT NULL,
  problem_md text,
  solution_md text,
  outcome_md text,
  quantified_impact text,
  photo_url text,
  video_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','featured','archived')),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hws_r1815_hospital_idx ON public.hospital_win_stories_r1815 (hospital_user_id);
CREATE INDEX IF NOT EXISTS hws_r1815_status_idx ON public.hospital_win_stories_r1815 (status);
CREATE INDEX IF NOT EXISTS hws_r1815_published_at_idx ON public.hospital_win_stories_r1815 (published_at DESC NULLS LAST);

CREATE TABLE IF NOT EXISTS public.hospital_win_story_uses_r1815 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES public.hospital_win_stories_r1815(id) ON DELETE CASCADE,
  use_context text NOT NULL CHECK (use_context IN ('sales_pitch','investor_deck','blog','social','email_campaign')),
  used_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  response_summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hwsu_r1815_story_idx ON public.hospital_win_story_uses_r1815 (story_id);
CREATE INDEX IF NOT EXISTS hwsu_r1815_context_idx ON public.hospital_win_story_uses_r1815 (use_context);
CREATE INDEX IF NOT EXISTS hwsu_r1815_used_at_idx ON public.hospital_win_story_uses_r1815 (used_at DESC);

ALTER TABLE public.hospital_win_stories_r1815 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_win_story_uses_r1815 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hws_r1815_founder_all ON public.hospital_win_stories_r1815;
CREATE POLICY hws_r1815_founder_all ON public.hospital_win_stories_r1815
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hwsu_r1815_founder_all ON public.hospital_win_story_uses_r1815;
CREATE POLICY hwsu_r1815_founder_all ON public.hospital_win_story_uses_r1815
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

-- 1) list_stories
DROP FUNCTION IF EXISTS public.list_stories_r1815();
CREATE OR REPLACE FUNCTION public.list_stories_r1815()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  story_title text,
  problem_md text,
  solution_md text,
  outcome_md text,
  quantified_impact text,
  photo_url text,
  video_url text,
  status text,
  published_at timestamptz,
  created_at timestamptz,
  use_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id, s.hospital_user_id, s.story_title, s.problem_md, s.solution_md,
    s.outcome_md, s.quantified_impact, s.photo_url, s.video_url, s.status,
    s.published_at, s.created_at,
    (SELECT COUNT(*) FROM public.hospital_win_story_uses_r1815 u WHERE u.story_id = s.id)::int AS use_count
  FROM public.hospital_win_stories_r1815 s
  ORDER BY s.created_at DESC;
END;
$$;

-- 2) draft_story
DROP FUNCTION IF EXISTS public.draft_story_r1815(uuid, text, text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.draft_story_r1815(
  p_hospital_user_id uuid,
  p_story_title text,
  p_problem_md text DEFAULT NULL,
  p_solution_md text DEFAULT NULL,
  p_outcome_md text DEFAULT NULL,
  p_quantified_impact text DEFAULT NULL,
  p_photo_url text DEFAULT NULL,
  p_video_url text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_win_stories_r1815 (
    hospital_user_id, story_title, problem_md, solution_md, outcome_md,
    quantified_impact, photo_url, video_url, status
  )
  VALUES (
    p_hospital_user_id, p_story_title, p_problem_md, p_solution_md, p_outcome_md,
    p_quantified_impact, p_photo_url, p_video_url, 'draft'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'draft_story_r1815',
    jsonb_build_object('story_id', v_id, 'hospital_user_id', p_hospital_user_id, 'story_title', p_story_title)
  );
  RETURN v_id;
END;
$$;

-- 3) list_uses
DROP FUNCTION IF EXISTS public.list_uses_r1815(uuid);
CREATE OR REPLACE FUNCTION public.list_uses_r1815(p_story_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  story_id uuid,
  story_title text,
  use_context text,
  used_at timestamptz,
  by_email text,
  response_summary text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.story_id, s.story_title, u.use_context, u.used_at, u.by_email, u.response_summary
  FROM public.hospital_win_story_uses_r1815 u
  JOIN public.hospital_win_stories_r1815 s ON s.id = u.story_id
  WHERE p_story_id IS NULL OR u.story_id = p_story_id
  ORDER BY u.used_at DESC
  LIMIT 200;
END;
$$;

-- 4) log_use
DROP FUNCTION IF EXISTS public.log_use_r1815(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_use_r1815(
  p_story_id uuid,
  p_use_context text,
  p_by_email text DEFAULT NULL,
  p_response_summary text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_win_story_uses_r1815 (story_id, use_context, by_email, response_summary)
  VALUES (p_story_id, p_use_context, p_by_email, p_response_summary)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_use_r1815',
    jsonb_build_object('use_id', v_id, 'story_id', p_story_id, 'use_context', p_use_context)
  );
  RETURN v_id;
END;
$$;

-- 5) publish_story
DROP FUNCTION IF EXISTS public.publish_story_r1815(uuid);
CREATE OR REPLACE FUNCTION public.publish_story_r1815(p_story_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_win_stories_r1815
  SET status = 'published', published_at = COALESCE(published_at, now()), updated_at = now()
  WHERE id = p_story_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'publish_story_r1815',
    jsonb_build_object('story_id', p_story_id)
  );
END;
$$;

-- 6) top_used_stories
DROP FUNCTION IF EXISTS public.top_used_stories_r1815();
CREATE OR REPLACE FUNCTION public.top_used_stories_r1815()
RETURNS TABLE (
  story_id uuid,
  story_title text,
  status text,
  use_count int,
  sales_pitch_count int,
  investor_deck_count int,
  blog_count int,
  social_count int,
  email_campaign_count int,
  last_used_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id AS story_id,
    s.story_title,
    s.status,
    (COUNT(u.id))::int AS use_count,
    (COUNT(*) FILTER (WHERE u.use_context = 'sales_pitch'))::int AS sales_pitch_count,
    (COUNT(*) FILTER (WHERE u.use_context = 'investor_deck'))::int AS investor_deck_count,
    (COUNT(*) FILTER (WHERE u.use_context = 'blog'))::int AS blog_count,
    (COUNT(*) FILTER (WHERE u.use_context = 'social'))::int AS social_count,
    (COUNT(*) FILTER (WHERE u.use_context = 'email_campaign'))::int AS email_campaign_count,
    MAX(u.used_at) AS last_used_at
  FROM public.hospital_win_stories_r1815 s
  LEFT JOIN public.hospital_win_story_uses_r1815 u ON u.story_id = s.id
  GROUP BY s.id, s.story_title, s.status
  HAVING COUNT(u.id) > 0
  ORDER BY use_count DESC, last_used_at DESC NULLS LAST
  LIMIT 50;
END;
$$;

-- 7) recent_published
DROP FUNCTION IF EXISTS public.recent_published_r1815();
CREATE OR REPLACE FUNCTION public.recent_published_r1815()
RETURNS TABLE (
  id uuid,
  story_title text,
  status text,
  quantified_impact text,
  published_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.story_title, s.status, s.quantified_impact, s.published_at, s.created_at
  FROM public.hospital_win_stories_r1815 s
  WHERE s.status IN ('published','featured')
  ORDER BY s.published_at DESC NULLS LAST
  LIMIT 25;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.list_stories_r1815() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stories_r1815() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.draft_story_r1815(uuid, text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.draft_story_r1815(uuid, text, text, text, text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_uses_r1815(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_uses_r1815(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_use_r1815(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_use_r1815(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.publish_story_r1815(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.publish_story_r1815(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_used_stories_r1815() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_used_stories_r1815() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_published_r1815() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_published_r1815() TO authenticated;

COMMIT;