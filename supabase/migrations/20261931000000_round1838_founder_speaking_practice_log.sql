BEGIN;

-- =====================================================================
-- Round 1838 — Founder Speaking Practice Log
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_speaking_practice_r1838 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL,
  event_date date NOT NULL,
  practice_session_at timestamptz NOT NULL DEFAULT now(),
  duration_minutes int NOT NULL DEFAULT 0,
  recording_url text,
  self_score int CHECK (self_score IS NULL OR (self_score BETWEEN 1 AND 10)),
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','in_progress','delivered','skipped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_speaking_practice_feedback_r1838 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.founder_speaking_practice_r1838(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('great','good','needs_work','avoid')),
  decision_note text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsp_r1838_event_date ON public.founder_speaking_practice_r1838(event_date);
CREATE INDEX IF NOT EXISTS idx_fsp_r1838_status ON public.founder_speaking_practice_r1838(status);
CREATE INDEX IF NOT EXISTS idx_fspf_r1838_session ON public.founder_speaking_practice_feedback_r1838(session_id);

ALTER TABLE public.founder_speaking_practice_r1838 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_speaking_practice_feedback_r1838 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fsp_r1838 ON public.founder_speaking_practice_r1838;
CREATE POLICY founder_all_fsp_r1838 ON public.founder_speaking_practice_r1838
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fspf_r1838 ON public.founder_speaking_practice_feedback_r1838;
CREATE POLICY founder_all_fspf_r1838 ON public.founder_speaking_practice_feedback_r1838
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_practices
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_practices_r1838();
CREATE OR REPLACE FUNCTION public.list_practices_r1838()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  practice_session_at timestamptz,
  duration_minutes int,
  recording_url text,
  self_score int,
  status text,
  feedback_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.event_name,
    p.event_date,
    p.practice_session_at,
    p.duration_minutes,
    p.recording_url,
    p.self_score,
    p.status,
    (SELECT COUNT(*) FROM public.founder_speaking_practice_feedback_r1838 f WHERE f.session_id = p.id)::int AS feedback_count
  FROM public.founder_speaking_practice_r1838 p
  ORDER BY p.event_date ASC, p.practice_session_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_practices_r1838() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_practices_r1838() TO authenticated;

-- =====================================================================
-- RPC 2: log_practice
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_practice_r1838(text, date, timestamptz, int, text, int, text);
CREATE OR REPLACE FUNCTION public.log_practice_r1838(
  p_event_name text,
  p_event_date date,
  p_practice_session_at timestamptz,
  p_duration_minutes int,
  p_recording_url text,
  p_self_score int,
  p_status text
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
  INSERT INTO public.founder_speaking_practice_r1838(
    event_name, event_date, practice_session_at, duration_minutes,
    recording_url, self_score, status
  )
  VALUES (
    p_event_name, p_event_date, COALESCE(p_practice_session_at, now()),
    COALESCE(p_duration_minutes, 0), p_recording_url, p_self_score,
    COALESCE(p_status, 'scheduled')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1838.log_practice',
    jsonb_build_object('id', v_id, 'event_name', p_event_name, 'event_date', p_event_date)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_practice_r1838(text, date, timestamptz, int, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_practice_r1838(text, date, timestamptz, int, text, int, text) TO authenticated;

-- =====================================================================
-- RPC 3: list_feedback
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_feedback_r1838(uuid);
CREATE OR REPLACE FUNCTION public.list_feedback_r1838(p_session_id uuid)
RETURNS TABLE (
  id uuid,
  session_id uuid,
  reviewer_email text,
  decision text,
  decision_note text,
  at timestamptz,
  event_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.session_id, f.reviewer_email, f.decision, f.decision_note, f.at,
    p.event_name
  FROM public.founder_speaking_practice_feedback_r1838 f
  JOIN public.founder_speaking_practice_r1838 p ON p.id = f.session_id
  WHERE (p_session_id IS NULL OR f.session_id = p_session_id)
  ORDER BY f.at DESC
  LIMIT 300;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_feedback_r1838(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_feedback_r1838(uuid) TO authenticated;

-- =====================================================================
-- RPC 4: add_feedback
-- =====================================================================
DROP FUNCTION IF EXISTS public.add_feedback_r1838(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.add_feedback_r1838(
  p_session_id uuid,
  p_reviewer_email text,
  p_decision text,
  p_decision_note text
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
  INSERT INTO public.founder_speaking_practice_feedback_r1838(
    session_id, reviewer_email, decision, decision_note
  )
  VALUES (p_session_id, p_reviewer_email, p_decision, p_decision_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1838.add_feedback',
    jsonb_build_object('feedback_id', v_id, 'session_id', p_session_id, 'decision', p_decision)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_feedback_r1838(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_feedback_r1838(uuid, text, text, text) TO authenticated;

-- =====================================================================
-- RPC 5: update_score
-- =====================================================================
DROP FUNCTION IF EXISTS public.update_score_r1838(uuid, int, text);
CREATE OR REPLACE FUNCTION public.update_score_r1838(
  p_session_id uuid,
  p_self_score int,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_speaking_practice_r1838
  SET
    self_score = COALESCE(p_self_score, self_score),
    status = COALESCE(p_status, status),
    updated_at = now()
  WHERE id = p_session_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1838.update_score',
    jsonb_build_object('session_id', p_session_id, 'self_score', p_self_score, 'status', p_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.update_score_r1838(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_score_r1838(uuid, int, text) TO authenticated;

-- =====================================================================
-- RPC 6: top_upcoming
-- =====================================================================
DROP FUNCTION IF EXISTS public.top_upcoming_r1838();
CREATE OR REPLACE FUNCTION public.top_upcoming_r1838()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  days_until int,
  practice_sessions_count int,
  latest_self_score int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.event_name,
    p.event_date,
    (p.event_date - CURRENT_DATE)::int AS days_until,
    (SELECT COUNT(*) FROM public.founder_speaking_practice_r1838 p2
       WHERE p2.event_name = p.event_name AND p2.event_date = p.event_date)::int AS practice_sessions_count,
    p.self_score AS latest_self_score,
    p.status
  FROM public.founder_speaking_practice_r1838 p
  WHERE p.event_date >= CURRENT_DATE
    AND p.status IN ('scheduled','in_progress')
  ORDER BY p.event_date ASC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_upcoming_r1838() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_upcoming_r1838() TO authenticated;

-- =====================================================================
-- RPC 7: recent_deliveries
-- =====================================================================
DROP FUNCTION IF EXISTS public.recent_deliveries_r1838();
CREATE OR REPLACE FUNCTION public.recent_deliveries_r1838()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  self_score int,
  duration_minutes int,
  positive_feedback int,
  total_feedback int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.event_name,
    p.event_date,
    p.self_score,
    p.duration_minutes,
    (COUNT(*) FILTER (WHERE f.decision IN ('great','good')))::int AS positive_feedback,
    (COUNT(f.id))::int AS total_feedback
  FROM public.founder_speaking_practice_r1838 p
  LEFT JOIN public.founder_speaking_practice_feedback_r1838 f ON f.session_id = p.id
  WHERE p.status = 'delivered'
  GROUP BY p.id, p.event_name, p.event_date, p.self_score, p.duration_minutes
  ORDER BY p.event_date DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_deliveries_r1838() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_deliveries_r1838() TO authenticated;

COMMIT;