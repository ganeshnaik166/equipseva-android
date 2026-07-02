BEGIN;

-- Round 1672 — Engineer Mentorship Pairings
-- Senior-junior mentorship registry + check-ins.

CREATE TABLE IF NOT EXISTS public.engineer_mentorship_pairs_r1672 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentee_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','ended')),
  ended_on date,
  ended_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mentor_ne_mentee_r1672 CHECK (mentor_user_id <> mentee_user_id)
);

CREATE INDEX IF NOT EXISTS idx_mentorship_pairs_mentor_r1672 ON public.engineer_mentorship_pairs_r1672(mentor_user_id);
CREATE INDEX IF NOT EXISTS idx_mentorship_pairs_mentee_r1672 ON public.engineer_mentorship_pairs_r1672(mentee_user_id);
CREATE INDEX IF NOT EXISTS idx_mentorship_pairs_status_r1672 ON public.engineer_mentorship_pairs_r1672(status);

CREATE TABLE IF NOT EXISTS public.engineer_mentorship_checkins_r1672 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair_id uuid NOT NULL REFERENCES public.engineer_mentorship_pairs_r1672(id) ON DELETE CASCADE,
  checkin_date date NOT NULL DEFAULT CURRENT_DATE,
  mentor_notes_md text,
  mentee_notes_md text,
  next_topic text,
  rating int CHECK (rating BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mentorship_checkins_pair_r1672 ON public.engineer_mentorship_checkins_r1672(pair_id);
CREATE INDEX IF NOT EXISTS idx_mentorship_checkins_date_r1672 ON public.engineer_mentorship_checkins_r1672(checkin_date DESC);

ALTER TABLE public.engineer_mentorship_pairs_r1672 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mentorship_checkins_r1672 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pairs_r1672 ON public.engineer_mentorship_pairs_r1672;
CREATE POLICY founder_all_pairs_r1672 ON public.engineer_mentorship_pairs_r1672
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_checkins_r1672 ON public.engineer_mentorship_checkins_r1672;
CREATE POLICY founder_all_checkins_r1672 ON public.engineer_mentorship_checkins_r1672
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_pairs
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_mentorship_pairs_r1672()
RETURNS TABLE (
  id uuid,
  mentor_user_id uuid,
  mentor_email text,
  mentee_user_id uuid,
  mentee_email text,
  started_on date,
  status text,
  ended_on date,
  ended_reason text,
  checkin_count int,
  last_checkin_on date,
  avg_rating numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.mentor_user_id,
    mp.email::text,
    p.mentee_user_id,
    mn.email::text,
    p.started_on,
    p.status,
    p.ended_on,
    p.ended_reason,
    (COUNT(c.id))::int AS checkin_count,
    MAX(c.checkin_date) AS last_checkin_on,
    ROUND(AVG(c.rating)::numeric, 2) AS avg_rating
  FROM public.engineer_mentorship_pairs_r1672 p
  LEFT JOIN public.profiles mp ON mp.id = p.mentor_user_id
  LEFT JOIN public.profiles mn ON mn.id = p.mentee_user_id
  LEFT JOIN public.engineer_mentorship_checkins_r1672 c ON c.pair_id = p.id
  GROUP BY p.id, mp.email, mn.email
  ORDER BY p.status ASC, p.started_on DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_mentorship_pairs_r1672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_mentorship_pairs_r1672() TO authenticated;

-- =========================================================================
-- RPC 2: create_pair
-- =========================================================================
CREATE OR REPLACE FUNCTION public.create_mentorship_pair_r1672(
  p_mentor_user_id uuid,
  p_mentee_user_id uuid,
  p_started_on date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_mentor_user_id = p_mentee_user_id THEN
    RAISE EXCEPTION 'mentor and mentee must differ';
  END IF;

  INSERT INTO public.engineer_mentorship_pairs_r1672(
    mentor_user_id, mentee_user_id, started_on, status
  ) VALUES (p_mentor_user_id, p_mentee_user_id, COALESCE(p_started_on, CURRENT_DATE), 'active')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1672_create_pair',
    jsonb_build_object(
      'pair_id', v_id,
      'mentor_user_id', p_mentor_user_id,
      'mentee_user_id', p_mentee_user_id,
      'started_on', COALESCE(p_started_on, CURRENT_DATE)
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_mentorship_pair_r1672(uuid, uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_mentorship_pair_r1672(uuid, uuid, date) TO authenticated;

-- =========================================================================
-- RPC 3: end_pair
-- =========================================================================
CREATE OR REPLACE FUNCTION public.end_mentorship_pair_r1672(
  p_pair_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.engineer_mentorship_pairs_r1672
  SET status = 'ended',
      ended_on = CURRENT_DATE,
      ended_reason = p_reason,
      updated_at = now()
  WHERE id = p_pair_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1672_end_pair',
    jsonb_build_object('pair_id', p_pair_id, 'reason', p_reason, 'ended_on', CURRENT_DATE)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.end_mentorship_pair_r1672(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.end_mentorship_pair_r1672(uuid, text) TO authenticated;

-- =========================================================================
-- RPC 4: list_checkins
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_mentorship_checkins_r1672(p_pair_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  pair_id uuid,
  mentor_email text,
  mentee_email text,
  checkin_date date,
  mentor_notes_md text,
  mentee_notes_md text,
  next_topic text,
  rating int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.pair_id,
    mp.email::text,
    mn.email::text,
    c.checkin_date,
    c.mentor_notes_md,
    c.mentee_notes_md,
    c.next_topic,
    c.rating,
    c.created_at
  FROM public.engineer_mentorship_checkins_r1672 c
  JOIN public.engineer_mentorship_pairs_r1672 p ON p.id = c.pair_id
  LEFT JOIN public.profiles mp ON mp.id = p.mentor_user_id
  LEFT JOIN public.profiles mn ON mn.id = p.mentee_user_id
  WHERE (p_pair_id IS NULL OR c.pair_id = p_pair_id)
  ORDER BY c.checkin_date DESC, c.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_mentorship_checkins_r1672(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_mentorship_checkins_r1672(uuid) TO authenticated;

-- =========================================================================
-- RPC 5: record_checkin
-- =========================================================================
CREATE OR REPLACE FUNCTION public.record_mentorship_checkin_r1672(
  p_pair_id uuid,
  p_mentor_notes_md text DEFAULT NULL,
  p_mentee_notes_md text DEFAULT NULL,
  p_next_topic text DEFAULT NULL,
  p_rating int DEFAULT NULL,
  p_checkin_date date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_rating IS NOT NULL AND (p_rating < 1 OR p_rating > 5) THEN
    RAISE EXCEPTION 'rating must be 1..5';
  END IF;

  INSERT INTO public.engineer_mentorship_checkins_r1672(
    pair_id, checkin_date, mentor_notes_md, mentee_notes_md, next_topic, rating
  ) VALUES (
    p_pair_id, COALESCE(p_checkin_date, CURRENT_DATE), p_mentor_notes_md, p_mentee_notes_md, p_next_topic, p_rating
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1672_record_checkin',
    jsonb_build_object(
      'checkin_id', v_id,
      'pair_id', p_pair_id,
      'rating', p_rating,
      'checkin_date', COALESCE(p_checkin_date, CURRENT_DATE)
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_mentorship_checkin_r1672(uuid, text, text, text, int, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_mentorship_checkin_r1672(uuid, text, text, text, int, date) TO authenticated;

-- =========================================================================
-- RPC 6: active_pairs_summary
-- =========================================================================
CREATE OR REPLACE FUNCTION public.active_mentorship_pairs_summary_r1672()
RETURNS TABLE (
  total_pairs int,
  active_pairs int,
  paused_pairs int,
  ended_pairs int,
  total_checkins int,
  checkins_last_30d int,
  avg_rating_overall numeric,
  pairs_no_checkin_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH last_c AS (
    SELECT p.id AS pair_id, MAX(c.checkin_date) AS last_d
    FROM public.engineer_mentorship_pairs_r1672 p
    LEFT JOIN public.engineer_mentorship_checkins_r1672 c ON c.pair_id = p.id
    WHERE p.status = 'active'
    GROUP BY p.id
  )
  SELECT
    (SELECT COUNT(*) FROM public.engineer_mentorship_pairs_r1672)::int,
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.engineer_mentorship_pairs_r1672),
    (SELECT (COUNT(*) FILTER (WHERE status = 'paused'))::int FROM public.engineer_mentorship_pairs_r1672),
    (SELECT (COUNT(*) FILTER (WHERE status = 'ended'))::int FROM public.engineer_mentorship_pairs_r1672),
    (SELECT COUNT(*) FROM public.engineer_mentorship_checkins_r1672)::int,
    (SELECT (COUNT(*) FILTER (WHERE checkin_date >= CURRENT_DATE - INTERVAL '30 days'))::int
       FROM public.engineer_mentorship_checkins_r1672),
    (SELECT ROUND(AVG(rating)::numeric, 2) FROM public.engineer_mentorship_checkins_r1672),
    (SELECT (COUNT(*) FILTER (WHERE last_d IS NULL OR last_d < CURRENT_DATE - INTERVAL '30 days'))::int
       FROM last_c);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.active_mentorship_pairs_summary_r1672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_mentorship_pairs_summary_r1672() TO authenticated;

-- =========================================================================
-- RPC 7: mentor_workload
-- =========================================================================
CREATE OR REPLACE FUNCTION public.mentor_workload_r1672()
RETURNS TABLE (
  mentor_user_id uuid,
  mentor_email text,
  active_mentees int,
  total_mentees int,
  total_checkins int,
  avg_rating numeric,
  last_checkin_on date
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.mentor_user_id,
    mp.email::text,
    (COUNT(DISTINCT p.id) FILTER (WHERE p.status = 'active'))::int AS active_mentees,
    (COUNT(DISTINCT p.id))::int AS total_mentees,
    (COUNT(c.id))::int AS total_checkins,
    ROUND(AVG(c.rating)::numeric, 2) AS avg_rating,
    MAX(c.checkin_date) AS last_checkin_on
  FROM public.engineer_mentorship_pairs_r1672 p
  LEFT JOIN public.profiles mp ON mp.id = p.mentor_user_id
  LEFT JOIN public.engineer_mentorship_checkins_r1672 c ON c.pair_id = p.id
  GROUP BY p.mentor_user_id, mp.email
  ORDER BY active_mentees DESC, total_checkins DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mentor_workload_r1672() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mentor_workload_r1672() TO authenticated;

COMMIT;