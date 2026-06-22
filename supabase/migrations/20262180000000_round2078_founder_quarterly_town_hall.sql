BEGIN;

-- =============================================================================
-- Round 2078 — Founder Quarterly Town Hall
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.founder_quarterly_town_hall_r2078 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  town_hall_date date NOT NULL,
  key_announcements_md text,
  key_questions_md text,
  key_themes_md text,
  attendee_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','held','cancelled','rescheduled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_town_hall_action_log_r2078 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  town_hall_id uuid NOT NULL REFERENCES public.founder_quarterly_town_hall_r2078(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('announced','scheduled','held','rescheduled','follow_up')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_town_hall_r2078 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_town_hall_action_log_r2078 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r2078_halls_founder ON public.founder_quarterly_town_hall_r2078;
CREATE POLICY r2078_halls_founder ON public.founder_quarterly_town_hall_r2078
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r2078_actions_founder ON public.founder_town_hall_action_log_r2078;
CREATE POLICY r2078_actions_founder ON public.founder_town_hall_action_log_r2078
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPCs
-- =============================================================================

DROP FUNCTION IF EXISTS public.r2078_list_halls();
CREATE OR REPLACE FUNCTION public.r2078_list_halls()
RETURNS TABLE(
  id uuid,
  quarter_label text,
  town_hall_date date,
  attendee_count int,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.quarter_label, h.town_hall_date, h.attendee_count, h.status, h.captured_at
    FROM public.founder_quarterly_town_hall_r2078 h
    ORDER BY h.town_hall_date DESC
    LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.r2078_log_hall(text, date, text, text, text, int, text);
CREATE OR REPLACE FUNCTION public.r2078_log_hall(
  p_quarter text,
  p_date date,
  p_announcements text,
  p_questions text,
  p_themes text,
  p_attendees int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_quarterly_town_hall_r2078(
    quarter_label, town_hall_date, key_announcements_md, key_questions_md,
    key_themes_md, attendee_count, status
  ) VALUES (
    p_quarter, p_date, p_announcements, p_questions, p_themes,
    COALESCE(p_attendees, 0), COALESCE(p_status, 'scheduled')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2078_log_hall',
          jsonb_build_object('hall_id', v_id, 'quarter', p_quarter, 'date', p_date));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.r2078_list_actions(uuid);
CREATE OR REPLACE FUNCTION public.r2078_list_actions(p_hall uuid)
RETURNS TABLE(
  id uuid,
  town_hall_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.town_hall_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_town_hall_action_log_r2078 a
    WHERE p_hall IS NULL OR a.town_hall_id = p_hall
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.r2078_log_action(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r2078_log_action(
  p_hall uuid,
  p_action text,
  p_email text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_town_hall_action_log_r2078(town_hall_id, action_type, by_email, notes_md)
  VALUES (p_hall, p_action, p_email, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2078_log_action',
          jsonb_build_object('hall_id', p_hall, 'action', p_action));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.r2078_mark_status(uuid, text);
CREATE OR REPLACE FUNCTION public.r2078_mark_status(p_hall uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_quarterly_town_hall_r2078
  SET status = p_status, updated_at = now()
  WHERE id = p_hall;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2078_mark_status',
          jsonb_build_object('hall_id', p_hall, 'status', p_status));
END;
$$;

DROP FUNCTION IF EXISTS public.r2078_upcoming();
CREATE OR REPLACE FUNCTION public.r2078_upcoming()
RETURNS TABLE(
  id uuid,
  quarter_label text,
  town_hall_date date,
  status text,
  attendee_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.quarter_label, h.town_hall_date, h.status, h.attendee_count
    FROM public.founder_quarterly_town_hall_r2078 h
    WHERE h.town_hall_date >= CURRENT_DATE
      AND h.status IN ('scheduled','rescheduled')
    ORDER BY h.town_hall_date ASC
    LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.r2078_recent_actions();
CREATE OR REPLACE FUNCTION public.r2078_recent_actions()
RETURNS TABLE(
  id uuid,
  town_hall_id uuid,
  quarter_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.town_hall_id, h.quarter_label, a.action_type, a.taken_at, a.by_email
    FROM public.founder_town_hall_action_log_r2078 a
    JOIN public.founder_quarterly_town_hall_r2078 h ON h.id = a.town_hall_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

-- =============================================================================
-- Grants
-- =============================================================================

REVOKE EXECUTE ON FUNCTION public.r2078_list_halls() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2078_log_hall(text, date, text, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2078_list_actions(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2078_log_action(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2078_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2078_upcoming() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2078_recent_actions() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2078_list_halls() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2078_log_hall(text, date, text, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2078_list_actions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2078_log_action(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2078_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2078_upcoming() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2078_recent_actions() TO authenticated;

COMMIT;
