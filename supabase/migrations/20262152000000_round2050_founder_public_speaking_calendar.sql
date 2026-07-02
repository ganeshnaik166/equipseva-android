BEGIN;

-- Table: founder_public_speaking_calendar_r2050
CREATE TABLE IF NOT EXISTS public.founder_public_speaking_calendar_r2050 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL,
  event_date date NOT NULL,
  audience_size_estimate int,
  talk_topic text,
  talk_status text NOT NULL DEFAULT 'committed' CHECK (talk_status IN ('committed','preparing','delivered','cancelled','declined')),
  prep_hours int DEFAULT 0,
  captured_at timestamptz DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_public_speaking_calendar_r2050 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_speaking_calendar_r2050_all ON public.founder_public_speaking_calendar_r2050;
CREATE POLICY founder_speaking_calendar_r2050_all ON public.founder_public_speaking_calendar_r2050
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table: founder_speaking_prep_log_r2050
CREATE TABLE IF NOT EXISTS public.founder_speaking_prep_log_r2050 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.founder_public_speaking_calendar_r2050(id) ON DELETE CASCADE,
  prep_type text NOT NULL CHECK (prep_type IN ('outline_drafted','slides_done','practice_session','rehearsal','last_review')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_speaking_prep_log_r2050 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_speaking_prep_log_r2050_all ON public.founder_speaking_prep_log_r2050;
CREATE POLICY founder_speaking_prep_log_r2050_all ON public.founder_speaking_prep_log_r2050
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_speaking_cal_r2050_date ON public.founder_public_speaking_calendar_r2050(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_speaking_prep_r2050_event ON public.founder_speaking_prep_log_r2050(event_id, taken_at DESC);

-- RPC 1: list_events
CREATE OR REPLACE FUNCTION public.founder_speaking_list_events_r2050()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  audience_size_estimate int,
  talk_topic text,
  talk_status text,
  prep_hours int,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_name, e.event_date, e.audience_size_estimate, e.talk_topic, e.talk_status, e.prep_hours, e.captured_at
  FROM public.founder_public_speaking_calendar_r2050 e
  ORDER BY e.event_date DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_event
CREATE OR REPLACE FUNCTION public.founder_speaking_log_event_r2050(
  p_event_name text,
  p_event_date date,
  p_audience_size_estimate int,
  p_talk_topic text,
  p_talk_status text,
  p_prep_hours int
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
  INSERT INTO public.founder_public_speaking_calendar_r2050(
    event_name, event_date, audience_size_estimate, talk_topic, talk_status, prep_hours
  ) VALUES (
    p_event_name, p_event_date, p_audience_size_estimate, p_talk_topic, COALESCE(p_talk_status,'committed'), COALESCE(p_prep_hours,0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_speaking_log_event_r2050',
    jsonb_build_object('id', v_id, 'event_name', p_event_name, 'event_date', p_event_date));

  RETURN v_id;
END;
$$;

-- RPC 3: list_prep
CREATE OR REPLACE FUNCTION public.founder_speaking_list_prep_r2050(p_event_id uuid)
RETURNS TABLE (
  id uuid,
  event_id uuid,
  event_name text,
  prep_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.event_id, e.event_name, p.prep_type, p.taken_at, p.by_email, p.notes_md
  FROM public.founder_speaking_prep_log_r2050 p
  JOIN public.founder_public_speaking_calendar_r2050 e ON e.id = p.event_id
  WHERE (p_event_id IS NULL OR p.event_id = p_event_id)
  ORDER BY p.taken_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log_prep
CREATE OR REPLACE FUNCTION public.founder_speaking_log_prep_r2050(
  p_event_id uuid,
  p_prep_type text,
  p_notes_md text
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
  INSERT INTO public.founder_speaking_prep_log_r2050(event_id, prep_type, by_email, notes_md)
  VALUES (p_event_id, p_prep_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_speaking_log_prep_r2050',
    jsonb_build_object('id', v_id, 'event_id', p_event_id, 'prep_type', p_prep_type));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.founder_speaking_mark_status_r2050(
  p_event_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_public_speaking_calendar_r2050
  SET talk_status = p_status, updated_at = now()
  WHERE id = p_event_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_speaking_mark_status_r2050',
    jsonb_build_object('id', p_event_id, 'status', p_status));
END;
$$;

-- RPC 6: upcoming
CREATE OR REPLACE FUNCTION public.founder_speaking_upcoming_r2050()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_date date,
  audience_size_estimate int,
  talk_topic text,
  talk_status text,
  prep_hours int,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_name, e.event_date, e.audience_size_estimate, e.talk_topic, e.talk_status, e.prep_hours,
    (e.event_date - CURRENT_DATE)::int AS days_until
  FROM public.founder_public_speaking_calendar_r2050 e
  WHERE e.event_date >= CURRENT_DATE AND e.talk_status IN ('committed','preparing')
  ORDER BY e.event_date ASC
  LIMIT 50;
END;
$$;

-- RPC 7: recent_prep
CREATE OR REPLACE FUNCTION public.founder_speaking_recent_prep_r2050()
RETURNS TABLE (
  id uuid,
  event_id uuid,
  event_name text,
  prep_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.event_id, e.event_name, p.prep_type, p.taken_at, p.by_email, p.notes_md
  FROM public.founder_speaking_prep_log_r2050 p
  JOIN public.founder_public_speaking_calendar_r2050 e ON e.id = p.event_id
  ORDER BY p.taken_at DESC
  LIMIT 50;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.founder_speaking_list_events_r2050() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_list_events_r2050() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_speaking_log_event_r2050(text, date, int, text, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_log_event_r2050(text, date, int, text, text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_speaking_list_prep_r2050(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_list_prep_r2050(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_speaking_log_prep_r2050(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_log_prep_r2050(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_speaking_mark_status_r2050(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_mark_status_r2050(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_speaking_upcoming_r2050() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_upcoming_r2050() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_speaking_recent_prep_r2050() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_speaking_recent_prep_r2050() TO authenticated;

COMMIT;
