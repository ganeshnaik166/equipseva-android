BEGIN;

-- ============================================================================
-- Round 1870: Founder Networking Event Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_networking_events_r1870 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('conference','dinner','founder_circle','investor_meetup','industry_panel')),
  event_date date NOT NULL,
  location text,
  expected_attendees int,
  founder_attended boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','attended','skipped','cancelled')),
  founder_value_score int CHECK (founder_value_score BETWEEN 1 AND 10),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_networking_event_meets_r1870 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.founder_networking_events_r1870(id) ON DELETE CASCADE,
  met_person_name text NOT NULL,
  met_person_role text,
  met_person_org text,
  met_person_email text,
  follow_up_required boolean NOT NULL DEFAULT false,
  notes text,
  met_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fne_r1870_date ON public.founder_networking_events_r1870(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_fne_r1870_status ON public.founder_networking_events_r1870(status);
CREATE INDEX IF NOT EXISTS idx_fnem_r1870_event ON public.founder_networking_event_meets_r1870(event_id);
CREATE INDEX IF NOT EXISTS idx_fnem_r1870_met_at ON public.founder_networking_event_meets_r1870(met_at DESC);

ALTER TABLE public.founder_networking_events_r1870 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_networking_event_meets_r1870 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fne_r1870_founder_all ON public.founder_networking_events_r1870;
CREATE POLICY fne_r1870_founder_all ON public.founder_networking_events_r1870
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fnem_r1870_founder_all ON public.founder_networking_event_meets_r1870;
CREATE POLICY fnem_r1870_founder_all ON public.founder_networking_event_meets_r1870
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_networking_events_r1870()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_type text,
  event_date date,
  location text,
  expected_attendees int,
  founder_attended boolean,
  status text,
  founder_value_score int,
  meet_count bigint,
  follow_up_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.event_name,
    e.event_type,
    e.event_date,
    e.location,
    e.expected_attendees,
    e.founder_attended,
    e.status,
    e.founder_value_score,
    (SELECT COUNT(*) FROM public.founder_networking_event_meets_r1870 m WHERE m.event_id = e.id) AS meet_count,
    (SELECT COUNT(*) FROM public.founder_networking_event_meets_r1870 m WHERE m.event_id = e.id AND m.follow_up_required) AS follow_up_count
  FROM public.founder_networking_events_r1870 e
  ORDER BY e.event_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_networking_events_r1870() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_networking_events_r1870() TO authenticated;

-- ============================================================================
-- RPC 2: log_event
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_networking_event_r1870(
  p_event_name text,
  p_event_type text,
  p_event_date date,
  p_location text,
  p_expected_attendees int,
  p_founder_value_score int
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_networking_events_r1870 (event_name, event_type, event_date, location, expected_attendees, founder_value_score)
  VALUES (p_event_name, p_event_type, p_event_date, p_location, p_expected_attendees, p_founder_value_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1870.log_event',
    jsonb_build_object('event_id', v_id, 'event_name', p_event_name, 'event_type', p_event_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_networking_event_r1870(text, text, date, text, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_networking_event_r1870(text, text, date, text, int, int) TO authenticated;

-- ============================================================================
-- RPC 3: list_meets
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_networking_meets_r1870()
RETURNS TABLE (
  id uuid,
  event_id uuid,
  event_name text,
  met_person_name text,
  met_person_role text,
  met_person_org text,
  met_person_email text,
  follow_up_required boolean,
  met_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.event_id,
    e.event_name,
    m.met_person_name,
    m.met_person_role,
    m.met_person_org,
    m.met_person_email,
    m.follow_up_required,
    m.met_at
  FROM public.founder_networking_event_meets_r1870 m
  JOIN public.founder_networking_events_r1870 e ON e.id = m.event_id
  ORDER BY m.met_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_networking_meets_r1870() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_networking_meets_r1870() TO authenticated;

-- ============================================================================
-- RPC 4: log_meet
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_networking_meet_r1870(
  p_event_id uuid,
  p_met_person_name text,
  p_met_person_role text,
  p_met_person_org text,
  p_met_person_email text,
  p_follow_up_required boolean
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_networking_event_meets_r1870 (event_id, met_person_name, met_person_role, met_person_org, met_person_email, follow_up_required)
  VALUES (p_event_id, p_met_person_name, p_met_person_role, p_met_person_org, p_met_person_email, COALESCE(p_follow_up_required, false))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1870.log_meet',
    jsonb_build_object('meet_id', v_id, 'event_id', p_event_id, 'person', p_met_person_name));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_networking_meet_r1870(uuid, text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_networking_meet_r1870(uuid, text, text, text, text, boolean) TO authenticated;

-- ============================================================================
-- RPC 5: mark_attended
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_networking_event_attended_r1870(
  p_event_id uuid,
  p_founder_value_score int
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_networking_events_r1870
  SET founder_attended = true,
      status = 'attended',
      founder_value_score = COALESCE(p_founder_value_score, founder_value_score),
      updated_at = now()
  WHERE id = p_event_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1870.mark_attended',
    jsonb_build_object('event_id', p_event_id, 'score', p_founder_value_score));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_networking_event_attended_r1870(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_networking_event_attended_r1870(uuid, int) TO authenticated;

-- ============================================================================
-- RPC 6: top_value_events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_networking_value_events_r1870()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_type text,
  event_date date,
  founder_value_score int,
  meet_count bigint,
  follow_up_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.event_name,
    e.event_type,
    e.event_date,
    e.founder_value_score,
    (SELECT COUNT(*) FROM public.founder_networking_event_meets_r1870 m WHERE m.event_id = e.id) AS meet_count,
    (SELECT COUNT(*) FROM public.founder_networking_event_meets_r1870 m WHERE m.event_id = e.id AND m.follow_up_required) AS follow_up_count
  FROM public.founder_networking_events_r1870 e
  WHERE e.status = 'attended' AND e.founder_value_score IS NOT NULL
  ORDER BY e.founder_value_score DESC NULLS LAST, e.event_date DESC
  LIMIT 10;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_networking_value_events_r1870() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_networking_value_events_r1870() TO authenticated;

-- ============================================================================
-- RPC 7: recent_meets
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_networking_meets_r1870()
RETURNS TABLE (
  id uuid,
  event_name text,
  met_person_name text,
  met_person_role text,
  met_person_org text,
  follow_up_required boolean,
  met_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    e.event_name,
    m.met_person_name,
    m.met_person_role,
    m.met_person_org,
    m.follow_up_required,
    m.met_at
  FROM public.founder_networking_event_meets_r1870 m
  JOIN public.founder_networking_events_r1870 e ON e.id = m.event_id
  WHERE m.met_at > now() - interval '30 days'
  ORDER BY m.met_at DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_networking_meets_r1870() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_networking_meets_r1870() TO authenticated;

COMMIT;