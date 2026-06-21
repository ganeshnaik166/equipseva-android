BEGIN;

-- ============================================================================
-- Round 1846 — Founder Coaching Session Log
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_coaching_sessions_r1846 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_name text NOT NULL,
  session_at timestamptz NOT NULL,
  duration_minutes int NOT NULL DEFAULT 60,
  topic text NOT NULL,
  key_insight_md text,
  action_committed_md text,
  status text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','completed','cancelled')),
  recording_url text,
  mood_rating int CHECK (mood_rating BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_coaching_action_log_r1846 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.founder_coaching_sessions_r1846(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coaching_sessions_r1846_at ON public.founder_coaching_sessions_r1846(session_at DESC);
CREATE INDEX IF NOT EXISTS idx_coaching_sessions_r1846_status ON public.founder_coaching_sessions_r1846(status);
CREATE INDEX IF NOT EXISTS idx_coaching_actions_r1846_session ON public.founder_coaching_action_log_r1846(session_id);
CREATE INDEX IF NOT EXISTS idx_coaching_actions_r1846_status ON public.founder_coaching_action_log_r1846(status);

ALTER TABLE public.founder_coaching_sessions_r1846 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_coaching_action_log_r1846 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_sessions_r1846_founder ON public.founder_coaching_sessions_r1846;
CREATE POLICY p_sessions_r1846_founder ON public.founder_coaching_sessions_r1846
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_actions_r1846_founder ON public.founder_coaching_action_log_r1846;
CREATE POLICY p_actions_r1846_founder ON public.founder_coaching_action_log_r1846
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_sessions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_coaching_sessions_r1846(int);
CREATE OR REPLACE FUNCTION public.list_coaching_sessions_r1846(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  coach_name text,
  session_at timestamptz,
  duration_minutes int,
  topic text,
  status text,
  mood_rating int,
  recording_url text
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
  SELECT s.id, s.coach_name, s.session_at, s.duration_minutes, s.topic, s.status, s.mood_rating, s.recording_url
  FROM public.founder_coaching_sessions_r1846 s
  ORDER BY s.session_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- ============================================================================
-- RPC 2: log_session
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_coaching_session_r1846(text, timestamptz, int, text, text, text, text, text, int);
CREATE OR REPLACE FUNCTION public.log_coaching_session_r1846(
  p_coach_name text,
  p_session_at timestamptz,
  p_duration_minutes int,
  p_topic text,
  p_key_insight_md text DEFAULT NULL,
  p_action_committed_md text DEFAULT NULL,
  p_status text DEFAULT 'upcoming',
  p_recording_url text DEFAULT NULL,
  p_mood_rating int DEFAULT NULL
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

  INSERT INTO public.founder_coaching_sessions_r1846(
    coach_name, session_at, duration_minutes, topic,
    key_insight_md, action_committed_md, status, recording_url, mood_rating
  ) VALUES (
    p_coach_name, p_session_at, p_duration_minutes, p_topic,
    p_key_insight_md, p_action_committed_md, COALESCE(p_status, 'upcoming'),
    p_recording_url, p_mood_rating
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_coaching_session_r1846',
    jsonb_build_object(
      'id', v_id,
      'coach_name', p_coach_name,
      'session_at', p_session_at,
      'topic', p_topic,
      'status', COALESCE(p_status, 'upcoming')
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_coaching_actions_r1846(uuid, int);
CREATE OR REPLACE FUNCTION public.list_coaching_actions_r1846(
  p_session_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  session_id uuid,
  coach_name text,
  action_text text,
  due_date date,
  status text,
  completed_at timestamptz,
  created_at timestamptz
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
  SELECT a.id, a.session_id, s.coach_name, a.action_text, a.due_date, a.status, a.completed_at, a.created_at
  FROM public.founder_coaching_action_log_r1846 a
  JOIN public.founder_coaching_sessions_r1846 s ON s.id = a.session_id
  WHERE (p_session_id IS NULL OR a.session_id = p_session_id)
  ORDER BY (a.status = 'open') DESC, a.due_date NULLS LAST, a.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_coaching_action_r1846(uuid, text, date);
CREATE OR REPLACE FUNCTION public.log_coaching_action_r1846(
  p_session_id uuid,
  p_action_text text,
  p_due_date date DEFAULT NULL
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

  INSERT INTO public.founder_coaching_action_log_r1846(session_id, action_text, due_date)
  VALUES (p_session_id, p_action_text, p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_coaching_action_r1846',
    jsonb_build_object('id', v_id, 'session_id', p_session_id, 'action_text', p_action_text, 'due_date', p_due_date)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: complete_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.complete_coaching_action_r1846(uuid, text);
CREATE OR REPLACE FUNCTION public.complete_coaching_action_r1846(
  p_action_id uuid,
  p_new_status text DEFAULT 'done'
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

  IF p_new_status NOT IN ('open','done','dropped') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.founder_coaching_action_log_r1846
  SET status = p_new_status,
      completed_at = CASE WHEN p_new_status = 'done' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'complete_coaching_action_r1846',
    jsonb_build_object('id', p_action_id, 'new_status', p_new_status)
  );
END;
$$;

-- ============================================================================
-- RPC 6: coach_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.coaching_coach_summary_r1846();
CREATE OR REPLACE FUNCTION public.coaching_coach_summary_r1846()
RETURNS TABLE (
  coach_name text,
  total_sessions int,
  completed_sessions int,
  upcoming_sessions int,
  total_minutes int,
  avg_mood numeric,
  last_session_at timestamptz
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
    s.coach_name,
    COUNT(*)::int AS total_sessions,
    (COUNT(*) FILTER (WHERE s.status = 'completed'))::int AS completed_sessions,
    (COUNT(*) FILTER (WHERE s.status = 'upcoming'))::int AS upcoming_sessions,
    COALESCE(SUM(s.duration_minutes) FILTER (WHERE s.status = 'completed'), 0)::int AS total_minutes,
    ROUND(AVG(s.mood_rating) FILTER (WHERE s.mood_rating IS NOT NULL), 2) AS avg_mood,
    MAX(s.session_at) AS last_session_at
  FROM public.founder_coaching_sessions_r1846 s
  GROUP BY s.coach_name
  ORDER BY MAX(s.session_at) DESC NULLS LAST;
END;
$$;

-- ============================================================================
-- RPC 7: recent_completed
-- ============================================================================
DROP FUNCTION IF EXISTS public.coaching_recent_completed_r1846(int);
CREATE OR REPLACE FUNCTION public.coaching_recent_completed_r1846(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  coach_name text,
  session_at timestamptz,
  topic text,
  duration_minutes int,
  mood_rating int,
  key_insight_md text,
  action_committed_md text
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
  SELECT s.id, s.coach_name, s.session_at, s.topic, s.duration_minutes, s.mood_rating, s.key_insight_md, s.action_committed_md
  FROM public.founder_coaching_sessions_r1846 s
  WHERE s.status = 'completed'
  ORDER BY s.session_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_coaching_sessions_r1846(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coaching_sessions_r1846(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_coaching_session_r1846(text, timestamptz, int, text, text, text, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_coaching_session_r1846(text, timestamptz, int, text, text, text, text, text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_coaching_actions_r1846(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coaching_actions_r1846(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_coaching_action_r1846(uuid, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_coaching_action_r1846(uuid, text, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.complete_coaching_action_r1846(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_coaching_action_r1846(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.coaching_coach_summary_r1846() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.coaching_coach_summary_r1846() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.coaching_recent_completed_r1846(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.coaching_recent_completed_r1846(int) TO authenticated;

COMMIT;