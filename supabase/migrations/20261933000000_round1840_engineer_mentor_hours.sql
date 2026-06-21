BEGIN;

-- =====================================================================
-- Round 1840: Engineer Mentor Hours
-- Track senior engineers mentoring junior engineers + founder recognition
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_mentor_hours_r1840 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentee_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hours_per_month int NOT NULL DEFAULT 0,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','ended')),
  last_session_at timestamptz,
  founder_recognition text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mentor_mentee_distinct CHECK (mentor_user_id <> mentee_user_id)
);

CREATE INDEX IF NOT EXISTS idx_emh_r1840_mentor ON public.engineer_mentor_hours_r1840(mentor_user_id);
CREATE INDEX IF NOT EXISTS idx_emh_r1840_mentee ON public.engineer_mentor_hours_r1840(mentee_user_id);
CREATE INDEX IF NOT EXISTS idx_emh_r1840_status ON public.engineer_mentor_hours_r1840(status);

CREATE TABLE IF NOT EXISTS public.engineer_mentor_session_log_r1840 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_hour_id uuid NOT NULL REFERENCES public.engineer_mentor_hours_r1840(id) ON DELETE CASCADE,
  session_at timestamptz NOT NULL DEFAULT now(),
  duration_minutes int NOT NULL DEFAULT 0,
  topic text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emsl_r1840_hour ON public.engineer_mentor_session_log_r1840(mentor_hour_id);
CREATE INDEX IF NOT EXISTS idx_emsl_r1840_session_at ON public.engineer_mentor_session_log_r1840(session_at DESC);

ALTER TABLE public.engineer_mentor_hours_r1840 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mentor_session_log_r1840 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS emh_r1840_founder_all ON public.engineer_mentor_hours_r1840;
CREATE POLICY emh_r1840_founder_all ON public.engineer_mentor_hours_r1840
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS emsl_r1840_founder_all ON public.engineer_mentor_session_log_r1840;
CREATE POLICY emsl_r1840_founder_all ON public.engineer_mentor_session_log_r1840
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_mentors
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_mentors_r1840()
RETURNS TABLE (
  id uuid,
  mentor_user_id uuid,
  mentee_user_id uuid,
  mentor_email text,
  mentee_email text,
  hours_per_month int,
  started_on date,
  status text,
  last_session_at timestamptz,
  founder_recognition text,
  sessions_count int
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
    h.id,
    h.mentor_user_id,
    h.mentee_user_id,
    pm.email::text AS mentor_email,
    pe.email::text AS mentee_email,
    h.hours_per_month,
    h.started_on,
    h.status,
    h.last_session_at,
    h.founder_recognition,
    (SELECT COUNT(*) FROM public.engineer_mentor_session_log_r1840 s WHERE s.mentor_hour_id = h.id)::int AS sessions_count
  FROM public.engineer_mentor_hours_r1840 h
  LEFT JOIN public.profiles pm ON pm.id = h.mentor_user_id
  LEFT JOIN public.profiles pe ON pe.id = h.mentee_user_id
  ORDER BY h.created_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 2: set_mentorship
-- =====================================================================
CREATE OR REPLACE FUNCTION public.set_mentorship_r1840(
  p_mentor_user_id uuid,
  p_mentee_user_id uuid,
  p_hours_per_month int,
  p_started_on date,
  p_founder_recognition text DEFAULT NULL
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

  INSERT INTO public.engineer_mentor_hours_r1840(
    mentor_user_id, mentee_user_id, hours_per_month, started_on, founder_recognition
  )
  VALUES (p_mentor_user_id, p_mentee_user_id, COALESCE(p_hours_per_month, 0), COALESCE(p_started_on, CURRENT_DATE), p_founder_recognition)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_mentorship_r1840',
          jsonb_build_object('id', v_id, 'mentor_user_id', p_mentor_user_id, 'mentee_user_id', p_mentee_user_id, 'hours_per_month', p_hours_per_month));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_sessions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_sessions_r1840(p_mentor_hour_id uuid)
RETURNS TABLE (
  id uuid,
  mentor_hour_id uuid,
  session_at timestamptz,
  duration_minutes int,
  topic text,
  outcome text
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
  SELECT s.id, s.mentor_hour_id, s.session_at, s.duration_minutes, s.topic, s.outcome
  FROM public.engineer_mentor_session_log_r1840 s
  WHERE s.mentor_hour_id = p_mentor_hour_id
  ORDER BY s.session_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 4: log_session
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_session_r1840(
  p_mentor_hour_id uuid,
  p_session_at timestamptz,
  p_duration_minutes int,
  p_topic text,
  p_outcome text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_session_at timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_session_at := COALESCE(p_session_at, now());

  INSERT INTO public.engineer_mentor_session_log_r1840(mentor_hour_id, session_at, duration_minutes, topic, outcome)
  VALUES (p_mentor_hour_id, v_session_at, COALESCE(p_duration_minutes, 0), p_topic, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.engineer_mentor_hours_r1840
  SET last_session_at = v_session_at, updated_at = now()
  WHERE id = p_mentor_hour_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_session_r1840',
          jsonb_build_object('id', v_id, 'mentor_hour_id', p_mentor_hour_id, 'duration_minutes', p_duration_minutes));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: update_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.update_status_r1840(
  p_id uuid,
  p_status text,
  p_founder_recognition text DEFAULT NULL
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

  IF p_status NOT IN ('active','paused','ended') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.engineer_mentor_hours_r1840
  SET status = p_status,
      founder_recognition = COALESCE(p_founder_recognition, founder_recognition),
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_status_r1840',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- =====================================================================
-- RPC 6: top_mentors
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_mentors_r1840()
RETURNS TABLE (
  mentor_user_id uuid,
  mentor_email text,
  active_mentees int,
  total_sessions int,
  total_minutes int,
  total_hours_per_month int
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
    h.mentor_user_id,
    p.email::text AS mentor_email,
    (COUNT(*) FILTER (WHERE h.status = 'active'))::int AS active_mentees,
    (SELECT COUNT(*) FROM public.engineer_mentor_session_log_r1840 s
       WHERE s.mentor_hour_id IN (SELECT id FROM public.engineer_mentor_hours_r1840 WHERE mentor_user_id = h.mentor_user_id))::int AS total_sessions,
    (SELECT COALESCE(SUM(s.duration_minutes), 0) FROM public.engineer_mentor_session_log_r1840 s
       WHERE s.mentor_hour_id IN (SELECT id FROM public.engineer_mentor_hours_r1840 WHERE mentor_user_id = h.mentor_user_id))::int AS total_minutes,
    COALESCE(SUM(h.hours_per_month), 0)::int AS total_hours_per_month
  FROM public.engineer_mentor_hours_r1840 h
  LEFT JOIN public.profiles p ON p.id = h.mentor_user_id
  GROUP BY h.mentor_user_id, p.email
  ORDER BY total_sessions DESC, active_mentees DESC
  LIMIT 50;
END;
$$;

-- =====================================================================
-- RPC 7: recent_sessions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_sessions_r1840()
RETURNS TABLE (
  id uuid,
  mentor_hour_id uuid,
  mentor_email text,
  mentee_email text,
  session_at timestamptz,
  duration_minutes int,
  topic text,
  outcome text
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
    s.id,
    s.mentor_hour_id,
    pm.email::text AS mentor_email,
    pe.email::text AS mentee_email,
    s.session_at,
    s.duration_minutes,
    s.topic,
    s.outcome
  FROM public.engineer_mentor_session_log_r1840 s
  JOIN public.engineer_mentor_hours_r1840 h ON h.id = s.mentor_hour_id
  LEFT JOIN public.profiles pm ON pm.id = h.mentor_user_id
  LEFT JOIN public.profiles pe ON pe.id = h.mentee_user_id
  ORDER BY s.session_at DESC
  LIMIT 100;
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_mentors_r1840() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_mentorship_r1840(uuid, uuid, int, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_sessions_r1840(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_session_r1840(uuid, timestamptz, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_status_r1840(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_mentors_r1840() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_sessions_r1840() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_mentors_r1840() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_mentorship_r1840(uuid, uuid, int, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sessions_r1840(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_session_r1840(uuid, timestamptz, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_status_r1840(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_mentors_r1840() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_sessions_r1840() TO authenticated;

COMMIT;