BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_office_hours_slots_r1766 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_date date NOT NULL,
  slot_start time NOT NULL,
  slot_end time NOT NULL,
  max_attendees int NOT NULL DEFAULT 1,
  booked_attendees text[] NOT NULL DEFAULT ARRAY[]::text[],
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','full','cancelled','completed')),
  theme text NOT NULL CHECK (theme IN ('open_q_and_a','feedback','coaching','strategy')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_office_hours_attendee_feedback_r1766 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id uuid NOT NULL REFERENCES public.founder_office_hours_slots_r1766(id) ON DELETE CASCADE,
  attendee_email text NOT NULL,
  helpful_rating int NOT NULL CHECK (helpful_rating BETWEEN 1 AND 10),
  what_helped text,
  what_would_improve text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_office_hours_slots_r1766 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_office_hours_attendee_feedback_r1766 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_slots_r1766 ON public.founder_office_hours_slots_r1766;
CREATE POLICY founder_all_slots_r1766 ON public.founder_office_hours_slots_r1766
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_feedback_r1766 ON public.founder_office_hours_attendee_feedback_r1766;
CREATE POLICY founder_all_feedback_r1766 ON public.founder_office_hours_attendee_feedback_r1766
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_slots
CREATE OR REPLACE FUNCTION public.list_office_hours_slots_r1766()
RETURNS TABLE (
  id uuid,
  slot_date date,
  slot_start time,
  slot_end time,
  max_attendees int,
  booked_count int,
  status text,
  theme text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.slot_date, s.slot_start, s.slot_end, s.max_attendees,
         COALESCE(array_length(s.booked_attendees, 1), 0)::int AS booked_count,
         s.status, s.theme, s.notes
  FROM public.founder_office_hours_slots_r1766 s
  ORDER BY s.slot_date DESC, s.slot_start DESC
  LIMIT 200;
END $$;

-- 2. schedule_slot
CREATE OR REPLACE FUNCTION public.schedule_office_hours_slot_r1766(
  p_slot_date date,
  p_slot_start time,
  p_slot_end time,
  p_max_attendees int,
  p_theme text,
  p_notes text DEFAULT NULL
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
  INSERT INTO public.founder_office_hours_slots_r1766(slot_date, slot_start, slot_end, max_attendees, theme, notes)
  VALUES (p_slot_date, p_slot_start, p_slot_end, GREATEST(p_max_attendees, 1), p_theme, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'schedule_office_hours_slot_r1766',
          jsonb_build_object('slot_id', v_id, 'slot_date', p_slot_date, 'theme', p_theme));
  RETURN v_id;
END $$;

-- 3. list_feedback
CREATE OR REPLACE FUNCTION public.list_office_hours_feedback_r1766()
RETURNS TABLE (
  id uuid,
  slot_id uuid,
  slot_date date,
  theme text,
  attendee_email text,
  helpful_rating int,
  what_helped text,
  what_would_improve text,
  submitted_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.slot_id, s.slot_date, s.theme, f.attendee_email, f.helpful_rating,
         f.what_helped, f.what_would_improve, f.submitted_at
  FROM public.founder_office_hours_attendee_feedback_r1766 f
  JOIN public.founder_office_hours_slots_r1766 s ON s.id = f.slot_id
  ORDER BY f.submitted_at DESC
  LIMIT 200;
END $$;

-- 4. log_feedback
CREATE OR REPLACE FUNCTION public.log_office_hours_feedback_r1766(
  p_slot_id uuid,
  p_attendee_email text,
  p_helpful_rating int,
  p_what_helped text DEFAULT NULL,
  p_what_would_improve text DEFAULT NULL
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
  INSERT INTO public.founder_office_hours_attendee_feedback_r1766(slot_id, attendee_email, helpful_rating, what_helped, what_would_improve)
  VALUES (p_slot_id, p_attendee_email, p_helpful_rating, p_what_helped, p_what_would_improve)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_office_hours_feedback_r1766',
          jsonb_build_object('slot_id', p_slot_id, 'attendee', p_attendee_email, 'rating', p_helpful_rating));
  RETURN v_id;
END $$;

-- 5. cancel_slot
CREATE OR REPLACE FUNCTION public.cancel_office_hours_slot_r1766(p_slot_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_office_hours_slots_r1766
  SET status = 'cancelled', updated_at = now()
  WHERE id = p_slot_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cancel_office_hours_slot_r1766',
          jsonb_build_object('slot_id', p_slot_id));
END $$;

-- 6. attendee_summary
CREATE OR REPLACE FUNCTION public.office_hours_attendee_summary_r1766()
RETURNS TABLE (
  attendee_email text,
  sessions_attended int,
  avg_helpful_rating numeric,
  last_attended timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.attendee_email,
         COUNT(*)::int AS sessions_attended,
         ROUND(AVG(f.helpful_rating)::numeric, 2) AS avg_helpful_rating,
         MAX(f.submitted_at) AS last_attended
  FROM public.founder_office_hours_attendee_feedback_r1766 f
  GROUP BY f.attendee_email
  ORDER BY sessions_attended DESC, avg_helpful_rating DESC
  LIMIT 100;
END $$;

-- 7. top_themes
CREATE OR REPLACE FUNCTION public.office_hours_top_themes_r1766()
RETURNS TABLE (
  theme text,
  slots_total int,
  slots_completed int,
  feedback_count int,
  avg_rating numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.theme,
         COUNT(*)::int AS slots_total,
         (COUNT(*) FILTER (WHERE s.status = 'completed'))::int AS slots_completed,
         (SELECT COUNT(*)::int FROM public.founder_office_hours_attendee_feedback_r1766 f WHERE f.slot_id IN (SELECT s2.id FROM public.founder_office_hours_slots_r1766 s2 WHERE s2.theme = s.theme)) AS feedback_count,
         (SELECT ROUND(AVG(f.helpful_rating)::numeric, 2) FROM public.founder_office_hours_attendee_feedback_r1766 f WHERE f.slot_id IN (SELECT s2.id FROM public.founder_office_hours_slots_r1766 s2 WHERE s2.theme = s.theme)) AS avg_rating
  FROM public.founder_office_hours_slots_r1766 s
  GROUP BY s.theme
  ORDER BY slots_total DESC;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_office_hours_slots_r1766() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.schedule_office_hours_slot_r1766(date, time, time, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_office_hours_feedback_r1766() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_office_hours_feedback_r1766(uuid, text, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cancel_office_hours_slot_r1766(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.office_hours_attendee_summary_r1766() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.office_hours_top_themes_r1766() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_office_hours_slots_r1766() TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_office_hours_slot_r1766(date, time, time, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_office_hours_feedback_r1766() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_office_hours_feedback_r1766(uuid, text, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_office_hours_slot_r1766(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.office_hours_attendee_summary_r1766() TO authenticated;
GRANT EXECUTE ON FUNCTION public.office_hours_top_themes_r1766() TO authenticated;

COMMIT;