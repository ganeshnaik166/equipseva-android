BEGIN;

-- ============================================================================
-- Round 1734 — Founder Travel Itinerary Planner
-- Plan founder travel + meeting density per trip
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_trips_r1734 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_name text NOT NULL,
  destination_city text NOT NULL,
  depart_date date NOT NULL,
  return_date date NOT NULL,
  trip_purpose text NOT NULL CHECK (trip_purpose IN ('sales','investor','conference','team','personal')),
  total_budget_rupees bigint NOT NULL DEFAULT 0,
  actual_spend_rupees bigint NOT NULL DEFAULT 0,
  roi_score int CHECK (roi_score IS NULL OR (roi_score BETWEEN 1 AND 10)),
  lessons_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_trip_meetings_r1734 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.founder_trips_r1734(id) ON DELETE CASCADE,
  meeting_label text NOT NULL,
  meeting_date date NOT NULL,
  attendee_emails text[] NOT NULL DEFAULT ARRAY[]::text[],
  meeting_type text NOT NULL CHECK (meeting_type IN ('sales','investor','customer','team','networking')),
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trips_r1734_depart ON public.founder_trips_r1734(depart_date DESC);
CREATE INDEX IF NOT EXISTS idx_trip_meetings_r1734_trip ON public.founder_trip_meetings_r1734(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_meetings_r1734_date ON public.founder_trip_meetings_r1734(meeting_date);

ALTER TABLE public.founder_trips_r1734 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_trip_meetings_r1734 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trips_r1734_founder_all ON public.founder_trips_r1734;
CREATE POLICY trips_r1734_founder_all ON public.founder_trips_r1734
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS trip_meetings_r1734_founder_all ON public.founder_trip_meetings_r1734;
CREATE POLICY trip_meetings_r1734_founder_all ON public.founder_trip_meetings_r1734
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_trips_r1734()
RETURNS TABLE (
  id uuid,
  trip_name text,
  destination_city text,
  depart_date date,
  return_date date,
  trip_purpose text,
  total_budget_rupees bigint,
  actual_spend_rupees bigint,
  roi_score int,
  meeting_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.trip_name, t.destination_city, t.depart_date, t.return_date,
         t.trip_purpose, t.total_budget_rupees, t.actual_spend_rupees, t.roi_score,
         (SELECT COUNT(*) FROM public.founder_trip_meetings_r1734 m WHERE m.trip_id = t.id)::int AS meeting_count,
         t.created_at
  FROM public.founder_trips_r1734 t
  ORDER BY t.depart_date DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.plan_trip_r1734(
  p_trip_name text,
  p_destination_city text,
  p_depart_date date,
  p_return_date date,
  p_trip_purpose text,
  p_total_budget_rupees bigint
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
  INSERT INTO public.founder_trips_r1734 (trip_name, destination_city, depart_date, return_date, trip_purpose, total_budget_rupees)
  VALUES (p_trip_name, p_destination_city, p_depart_date, p_return_date, p_trip_purpose, COALESCE(p_total_budget_rupees, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'plan_trip_r1734',
    jsonb_build_object('trip_id', v_id, 'trip_name', p_trip_name, 'destination', p_destination_city));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_meetings_r1734(p_trip_id uuid)
RETURNS TABLE (
  id uuid,
  trip_id uuid,
  meeting_label text,
  meeting_date date,
  attendee_emails text[],
  meeting_type text,
  outcome_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.trip_id, m.meeting_label, m.meeting_date, m.attendee_emails, m.meeting_type, m.outcome_md, m.created_at
  FROM public.founder_trip_meetings_r1734 m
  WHERE m.trip_id = p_trip_id
  ORDER BY m.meeting_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_meeting_r1734(
  p_trip_id uuid,
  p_meeting_label text,
  p_meeting_date date,
  p_attendee_emails text[],
  p_meeting_type text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_trip_meetings_r1734 (trip_id, meeting_label, meeting_date, attendee_emails, meeting_type, outcome_md)
  VALUES (p_trip_id, p_meeting_label, p_meeting_date, COALESCE(p_attendee_emails, ARRAY[]::text[]), p_meeting_type, p_outcome_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_meeting_r1734',
    jsonb_build_object('meeting_id', v_id, 'trip_id', p_trip_id, 'label', p_meeting_label));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_trip_r1734(
  p_trip_id uuid,
  p_actual_spend_rupees bigint,
  p_roi_score int,
  p_lessons_md text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_roi_score IS NOT NULL AND (p_roi_score < 1 OR p_roi_score > 10) THEN
    RAISE EXCEPTION 'roi_score must be between 1 and 10';
  END IF;
  UPDATE public.founder_trips_r1734
  SET actual_spend_rupees = COALESCE(p_actual_spend_rupees, actual_spend_rupees),
      roi_score = COALESCE(p_roi_score, roi_score),
      lessons_md = COALESCE(p_lessons_md, lessons_md),
      updated_at = now()
  WHERE id = p_trip_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_trip_r1734',
    jsonb_build_object('trip_id', p_trip_id, 'actual_spend', p_actual_spend_rupees, 'roi', p_roi_score));
END;
$$;

CREATE OR REPLACE FUNCTION public.trip_roi_summary_r1734()
RETURNS TABLE (
  trip_purpose text,
  trip_count int,
  total_budget_rupees bigint,
  total_actual_spend_rupees bigint,
  avg_roi_score numeric,
  total_meetings int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.trip_purpose,
         (COUNT(*))::int AS trip_count,
         COALESCE(SUM(t.total_budget_rupees), 0)::bigint AS total_budget_rupees,
         COALESCE(SUM(t.actual_spend_rupees), 0)::bigint AS total_actual_spend_rupees,
         ROUND(AVG(t.roi_score)::numeric, 2) AS avg_roi_score,
         (SELECT COUNT(*) FROM public.founder_trip_meetings_r1734 m
            JOIN public.founder_trips_r1734 t2 ON t2.id = m.trip_id
            WHERE t2.trip_purpose = t.trip_purpose)::int AS total_meetings
  FROM public.founder_trips_r1734 t
  GROUP BY t.trip_purpose
  ORDER BY total_actual_spend_rupees DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.upcoming_trips_r1734()
RETURNS TABLE (
  id uuid,
  trip_name text,
  destination_city text,
  depart_date date,
  return_date date,
  trip_purpose text,
  days_until_depart int,
  meeting_count int,
  total_budget_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.trip_name, t.destination_city, t.depart_date, t.return_date, t.trip_purpose,
         (t.depart_date - CURRENT_DATE)::int AS days_until_depart,
         (SELECT COUNT(*) FROM public.founder_trip_meetings_r1734 m WHERE m.trip_id = t.id)::int AS meeting_count,
         t.total_budget_rupees
  FROM public.founder_trips_r1734 t
  WHERE t.depart_date >= CURRENT_DATE
  ORDER BY t.depart_date ASC;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_trips_r1734() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.plan_trip_r1734(text, text, date, date, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_meetings_r1734(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_meeting_r1734(uuid, text, date, text[], text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_trip_r1734(uuid, bigint, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trip_roi_summary_r1734() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_trips_r1734() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_trips_r1734() TO authenticated;
GRANT EXECUTE ON FUNCTION public.plan_trip_r1734(text, text, date, date, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_meetings_r1734(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_meeting_r1734(uuid, text, date, text[], text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_trip_r1734(uuid, bigint, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trip_roi_summary_r1734() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_trips_r1734() TO authenticated;

COMMIT;