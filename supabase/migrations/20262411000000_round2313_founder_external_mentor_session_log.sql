BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_mentors_r2313 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_name text NOT NULL,
  mentor_type text NOT NULL DEFAULT 'industry_vet' CHECK (mentor_type IN ('industry_vet','fellow_founder','investor_advisor','domain_expert','operator','academic')),
  company_or_role text NOT NULL DEFAULT '',
  email text,
  intro_source text NOT NULL DEFAULT '',
  expertise_tags text NOT NULL DEFAULT '',
  relationship_status text NOT NULL DEFAULT 'active' CHECK (relationship_status IN ('active','dormant','closed')),
  first_met_on date,
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_mentor_sessions_r2313 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL REFERENCES public.founder_mentors_r2313(id) ON DELETE CASCADE,
  session_date date NOT NULL,
  session_format text NOT NULL DEFAULT 'video' CHECK (session_format IN ('video','phone','in_person','async_text')),
  duration_minutes int NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
  topic_summary text NOT NULL,
  advice_given_md text NOT NULL DEFAULT '',
  action_taken_md text NOT NULL DEFAULT '',
  action_status text NOT NULL DEFAULT 'pending' CHECK (action_status IN ('pending','in_progress','done','declined','obsolete')),
  outcome_md text NOT NULL DEFAULT '',
  usefulness_rating int CHECK (usefulness_rating BETWEEN 1 AND 5),
  follow_up_due_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_mentors_r2313 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_mentor_sessions_r2313 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_mentors_r2313 ON public.founder_mentors_r2313;
CREATE POLICY founder_all_mentors_r2313 ON public.founder_mentors_r2313
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_sessions_r2313 ON public.founder_mentor_sessions_r2313;
CREATE POLICY founder_all_sessions_r2313 ON public.founder_mentor_sessions_r2313
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_mentors
CREATE OR REPLACE FUNCTION public.list_mentors_r2313()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  mentor_type text,
  company_or_role text,
  relationship_status text,
  expertise_tags text,
  first_met_on date,
  session_count int,
  last_session_on date
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.mentor_name, m.mentor_type, m.company_or_role, m.relationship_status, m.expertise_tags, m.first_met_on,
    (SELECT (COUNT(*))::int FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id) AS session_count,
    (SELECT MAX(s.session_date) FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id) AS last_session_on
  FROM public.founder_mentors_r2313 m
  ORDER BY m.relationship_status, m.mentor_name;
END;
$$;

-- RPC 2: list_sessions
CREATE OR REPLACE FUNCTION public.list_sessions_r2313()
RETURNS TABLE (
  id uuid,
  mentor_id uuid,
  mentor_name text,
  session_date date,
  session_format text,
  duration_minutes int,
  topic_summary text,
  action_status text,
  usefulness_rating int,
  follow_up_due_date date
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.mentor_id, m.mentor_name, s.session_date, s.session_format, s.duration_minutes, s.topic_summary, s.action_status, s.usefulness_rating, s.follow_up_due_date
  FROM public.founder_mentor_sessions_r2313 s
  JOIN public.founder_mentors_r2313 m ON m.id = s.mentor_id
  ORDER BY s.session_date DESC, s.created_at DESC;
END;
$$;

-- RPC 3: pending_follow_ups
CREATE OR REPLACE FUNCTION public.pending_follow_ups_r2313()
RETURNS TABLE (
  id uuid,
  mentor_id uuid,
  mentor_name text,
  session_date date,
  topic_summary text,
  action_status text,
  follow_up_due_date date,
  days_until_due int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.mentor_id, m.mentor_name, s.session_date, s.topic_summary, s.action_status, s.follow_up_due_date,
    (s.follow_up_due_date - CURRENT_DATE)::int AS days_until_due
  FROM public.founder_mentor_sessions_r2313 s
  JOIN public.founder_mentors_r2313 m ON m.id = s.mentor_id
  WHERE s.follow_up_due_date IS NOT NULL
    AND s.action_status IN ('pending','in_progress')
  ORDER BY s.follow_up_due_date ASC;
END;
$$;

-- RPC 4: high_rated_advice
CREATE OR REPLACE FUNCTION public.high_rated_advice_r2313()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  mentor_type text,
  session_date date,
  topic_summary text,
  usefulness_rating int,
  action_status text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, m.mentor_name, m.mentor_type, s.session_date, s.topic_summary, s.usefulness_rating, s.action_status
  FROM public.founder_mentor_sessions_r2313 s
  JOIN public.founder_mentors_r2313 m ON m.id = s.mentor_id
  WHERE s.usefulness_rating IS NOT NULL AND s.usefulness_rating >= 4
  ORDER BY s.usefulness_rating DESC, s.session_date DESC;
END;
$$;

-- RPC 5: mentor_summary
CREATE OR REPLACE FUNCTION public.mentor_summary_r2313()
RETURNS TABLE (
  mentor_id uuid,
  mentor_name text,
  mentor_type text,
  total_sessions int,
  total_minutes int,
  pending_actions int,
  done_actions int,
  avg_usefulness numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id AS mentor_id, m.mentor_name, m.mentor_type,
    (SELECT (COUNT(*))::int FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id) AS total_sessions,
    (SELECT (COALESCE(SUM(s.duration_minutes),0))::int FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id) AS total_minutes,
    (SELECT (COUNT(*))::int FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id AND s.action_status IN ('pending','in_progress')) AS pending_actions,
    (SELECT (COUNT(*))::int FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id AND s.action_status = 'done') AS done_actions,
    (SELECT ROUND(AVG(s.usefulness_rating)::numeric, 2) FROM public.founder_mentor_sessions_r2313 s WHERE s.mentor_id = m.id AND s.usefulness_rating IS NOT NULL) AS avg_usefulness
  FROM public.founder_mentors_r2313 m
  ORDER BY total_sessions DESC, m.mentor_name;
END;
$$;

-- RPC 6: type_breakdown
CREATE OR REPLACE FUNCTION public.type_breakdown_r2313()
RETURNS TABLE (
  mentor_type text,
  mentor_count int,
  session_count int,
  total_minutes int,
  avg_rating numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.mentor_type,
    (COUNT(DISTINCT m.id))::int AS mentor_count,
    (COUNT(s.id))::int AS session_count,
    (COALESCE(SUM(s.duration_minutes),0))::int AS total_minutes,
    ROUND(AVG(s.usefulness_rating)::numeric, 2) AS avg_rating
  FROM public.founder_mentors_r2313 m
  LEFT JOIN public.founder_mentor_sessions_r2313 s ON s.mentor_id = m.id
  GROUP BY m.mentor_type
  ORDER BY session_count DESC;
END;
$$;

-- RPC 7: monthly_cadence
CREATE OR REPLACE FUNCTION public.monthly_cadence_r2313()
RETURNS TABLE (
  month_start date,
  session_count int,
  unique_mentors int,
  total_minutes int,
  done_count int,
  avg_rating numeric
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', s.session_date)::date AS month_start,
    (COUNT(*))::int AS session_count,
    (COUNT(DISTINCT s.mentor_id))::int AS unique_mentors,
    (COALESCE(SUM(s.duration_minutes),0))::int AS total_minutes,
    (COUNT(*) FILTER (WHERE s.action_status = 'done'))::int AS done_count,
    ROUND(AVG(s.usefulness_rating)::numeric, 2) AS avg_rating
  FROM public.founder_mentor_sessions_r2313 s
  GROUP BY date_trunc('month', s.session_date)
  ORDER BY month_start DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_mentors_r2313() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_sessions_r2313() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pending_follow_ups_r2313() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.high_rated_advice_r2313() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mentor_summary_r2313() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.type_breakdown_r2313() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.monthly_cadence_r2313() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_mentors_r2313() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sessions_r2313() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pending_follow_ups_r2313() TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_rated_advice_r2313() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mentor_summary_r2313() TO authenticated;
GRANT EXECUTE ON FUNCTION public.type_breakdown_r2313() TO authenticated;
GRANT EXECUTE ON FUNCTION public.monthly_cadence_r2313() TO authenticated;

COMMIT;
