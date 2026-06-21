BEGIN;

-- =========================================================================
-- Round 1718 — Founder Mentor Roster
-- Track active mentors/advisors + meeting cadence + value extracted
-- =========================================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS public.founder_mentor_roster_r1718 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_name text NOT NULL,
  mentor_org text,
  expertise_areas text[] NOT NULL DEFAULT '{}',
  compensation_model text NOT NULL CHECK (compensation_model IN ('equity','cash','free')),
  monthly_compensation_rupees integer NOT NULL DEFAULT 0 CHECK (monthly_compensation_rupees >= 0),
  last_met_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','dropped')),
  value_rating integer CHECK (value_rating BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmr_r1718_status ON public.founder_mentor_roster_r1718(status);
CREATE INDEX IF NOT EXISTS idx_fmr_r1718_last_met ON public.founder_mentor_roster_r1718(last_met_at);
CREATE INDEX IF NOT EXISTS idx_fmr_r1718_value ON public.founder_mentor_roster_r1718(value_rating);

CREATE TABLE IF NOT EXISTS public.founder_mentor_meetings_r1718 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL REFERENCES public.founder_mentor_roster_r1718(id) ON DELETE CASCADE,
  meeting_date date NOT NULL,
  topic text NOT NULL,
  key_insight text,
  action_items_md text,
  took_action boolean NOT NULL DEFAULT false,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmm_r1718_mentor ON public.founder_mentor_meetings_r1718(mentor_id);
CREATE INDEX IF NOT EXISTS idx_fmm_r1718_date ON public.founder_mentor_meetings_r1718(meeting_date);
CREATE INDEX IF NOT EXISTS idx_fmm_r1718_took_action ON public.founder_mentor_meetings_r1718(took_action);

-- ---------- RLS ----------

ALTER TABLE public.founder_mentor_roster_r1718 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_mentor_meetings_r1718 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fmr_r1718_founder_all ON public.founder_mentor_roster_r1718;
CREATE POLICY fmr_r1718_founder_all
  ON public.founder_mentor_roster_r1718
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fmm_r1718_founder_all ON public.founder_mentor_meetings_r1718;
CREATE POLICY fmm_r1718_founder_all
  ON public.founder_mentor_meetings_r1718
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------- RPCs ----------

-- 1) list_mentors
CREATE OR REPLACE FUNCTION public.list_mentors_r1718()
RETURNS TABLE (
  id uuid,
  mentor_name text,
  mentor_org text,
  expertise_areas text[],
  compensation_model text,
  monthly_compensation_rupees integer,
  last_met_at timestamptz,
  status text,
  value_rating integer,
  meetings_count integer,
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
  SELECT
    m.id,
    m.mentor_name,
    m.mentor_org,
    m.expertise_areas,
    m.compensation_model,
    m.monthly_compensation_rupees,
    m.last_met_at,
    m.status,
    m.value_rating,
    (SELECT COUNT(*) FROM public.founder_mentor_meetings_r1718 mm WHERE mm.mentor_id = m.id)::int,
    m.created_at
  FROM public.founder_mentor_roster_r1718 m
  ORDER BY
    CASE WHEN m.status = 'active' THEN 0 WHEN m.status = 'paused' THEN 1 ELSE 2 END,
    m.value_rating DESC NULLS LAST,
    m.created_at DESC;
END;
$$;

-- 2) add_mentor
CREATE OR REPLACE FUNCTION public.add_mentor_r1718(
  p_mentor_name text,
  p_mentor_org text,
  p_expertise_areas text[],
  p_compensation_model text,
  p_monthly_compensation_rupees integer,
  p_value_rating integer
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

  IF p_compensation_model NOT IN ('equity','cash','free') THEN
    RAISE EXCEPTION 'invalid_compensation_model';
  END IF;

  INSERT INTO public.founder_mentor_roster_r1718(
    mentor_name, mentor_org, expertise_areas, compensation_model,
    monthly_compensation_rupees, value_rating
  )
  VALUES (
    p_mentor_name,
    p_mentor_org,
    COALESCE(p_expertise_areas, '{}'),
    p_compensation_model,
    COALESCE(p_monthly_compensation_rupees, 0),
    p_value_rating
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_mentor_r1718',
    jsonb_build_object(
      'mentor_id', v_id,
      'mentor_name', p_mentor_name,
      'compensation_model', p_compensation_model
    )
  );

  RETURN v_id;
END;
$$;

-- 3) list_meetings
CREATE OR REPLACE FUNCTION public.list_meetings_r1718(
  p_mentor_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  mentor_id uuid,
  mentor_name text,
  meeting_date date,
  topic text,
  key_insight text,
  action_items_md text,
  took_action boolean,
  outcome_md text,
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
  SELECT
    mm.id,
    mm.mentor_id,
    m.mentor_name,
    mm.meeting_date,
    mm.topic,
    mm.key_insight,
    mm.action_items_md,
    mm.took_action,
    mm.outcome_md,
    mm.created_at
  FROM public.founder_mentor_meetings_r1718 mm
  JOIN public.founder_mentor_roster_r1718 m ON m.id = mm.mentor_id
  WHERE p_mentor_id IS NULL OR mm.mentor_id = p_mentor_id
  ORDER BY mm.meeting_date DESC, mm.created_at DESC
  LIMIT 200;
END;
$$;

-- 4) log_meeting
CREATE OR REPLACE FUNCTION public.log_meeting_r1718(
  p_mentor_id uuid,
  p_meeting_date date,
  p_topic text,
  p_key_insight text,
  p_action_items_md text,
  p_took_action boolean,
  p_outcome_md text
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

  INSERT INTO public.founder_mentor_meetings_r1718(
    mentor_id, meeting_date, topic, key_insight,
    action_items_md, took_action, outcome_md
  )
  VALUES (
    p_mentor_id,
    p_meeting_date,
    p_topic,
    p_key_insight,
    p_action_items_md,
    COALESCE(p_took_action, false),
    p_outcome_md
  )
  RETURNING id INTO v_id;

  UPDATE public.founder_mentor_roster_r1718
    SET last_met_at = GREATEST(COALESCE(last_met_at, '-infinity'::timestamptz), p_meeting_date::timestamptz),
        updated_at = now()
    WHERE id = p_mentor_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_meeting_r1718',
    jsonb_build_object(
      'meeting_id', v_id,
      'mentor_id', p_mentor_id,
      'meeting_date', p_meeting_date,
      'topic', p_topic
    )
  );

  RETURN v_id;
END;
$$;

-- 5) update_mentor_status
CREATE OR REPLACE FUNCTION public.update_mentor_status_r1718(
  p_mentor_id uuid,
  p_status text,
  p_value_rating integer
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

  IF p_status NOT IN ('active','paused','dropped') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.founder_mentor_roster_r1718
    SET status = p_status,
        value_rating = COALESCE(p_value_rating, value_rating),
        updated_at = now()
    WHERE id = p_mentor_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'update_mentor_status_r1718',
    jsonb_build_object(
      'mentor_id', p_mentor_id,
      'status', p_status,
      'value_rating', p_value_rating
    )
  );
END;
$$;

-- 6) top_value_mentors
CREATE OR REPLACE FUNCTION public.top_value_mentors_r1718(
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  id uuid,
  mentor_name text,
  mentor_org text,
  value_rating integer,
  compensation_model text,
  monthly_compensation_rupees integer,
  meetings_count integer,
  actions_taken_count integer,
  status text
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
    m.mentor_name,
    m.mentor_org,
    m.value_rating,
    m.compensation_model,
    m.monthly_compensation_rupees,
    (SELECT COUNT(*) FROM public.founder_mentor_meetings_r1718 mm WHERE mm.mentor_id = m.id)::int,
    (SELECT (COUNT(*) FILTER (WHERE mm.took_action))::int
       FROM public.founder_mentor_meetings_r1718 mm
       WHERE mm.mentor_id = m.id),
    m.status
  FROM public.founder_mentor_roster_r1718 m
  WHERE m.value_rating IS NOT NULL
  ORDER BY m.value_rating DESC NULLS LAST, m.last_met_at DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit, 10), 1);
END;
$$;

-- 7) stale_mentor_relationships
CREATE OR REPLACE FUNCTION public.stale_mentor_relationships_r1718(
  p_days_threshold integer DEFAULT 60
)
RETURNS TABLE (
  id uuid,
  mentor_name text,
  mentor_org text,
  last_met_at timestamptz,
  days_since_last_meeting integer,
  status text,
  value_rating integer,
  monthly_compensation_rupees integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_threshold integer := GREATEST(COALESCE(p_days_threshold, 60), 1);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.mentor_name,
    m.mentor_org,
    m.last_met_at,
    CASE
      WHEN m.last_met_at IS NULL THEN NULL
      ELSE EXTRACT(DAY FROM (now() - m.last_met_at))::int
    END,
    m.status,
    m.value_rating,
    m.monthly_compensation_rupees
  FROM public.founder_mentor_roster_r1718 m
  WHERE m.status = 'active'
    AND (
      m.last_met_at IS NULL
      OR m.last_met_at < (now() - (v_threshold || ' days')::interval)
    )
  ORDER BY m.last_met_at ASC NULLS FIRST;
END;
$$;

-- ---------- REVOKE + GRANT ----------

REVOKE EXECUTE ON FUNCTION public.list_mentors_r1718()                               FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_mentor_r1718(text,text,text[],text,integer,integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_meetings_r1718(uuid)                          FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_meeting_r1718(uuid,date,text,text,text,boolean,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_mentor_status_r1718(uuid,text,integer)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_value_mentors_r1718(integer)                   FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.stale_mentor_relationships_r1718(integer)          FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_mentors_r1718()                               TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_mentor_r1718(text,text,text[],text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_meetings_r1718(uuid)                          TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_meeting_r1718(uuid,date,text,text,text,boolean,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_mentor_status_r1718(uuid,text,integer)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_value_mentors_r1718(integer)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.stale_mentor_relationships_r1718(integer)          TO authenticated;

COMMIT;