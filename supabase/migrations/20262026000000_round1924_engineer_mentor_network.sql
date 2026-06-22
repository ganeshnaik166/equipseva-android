BEGIN;

-- ============================================================
-- Round 1924: Engineer Mentor Network
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_mentor_network_r1924 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mentee_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  paired_at timestamptz NOT NULL DEFAULT now(),
  focus_area text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed','ended')),
  last_check_in_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emn_r1924_mentor ON public.engineer_mentor_network_r1924(mentor_user_id);
CREATE INDEX IF NOT EXISTS idx_emn_r1924_mentee ON public.engineer_mentor_network_r1924(mentee_user_id);
CREATE INDEX IF NOT EXISTS idx_emn_r1924_status ON public.engineer_mentor_network_r1924(status);

CREATE TABLE IF NOT EXISTS public.engineer_mentor_checkin_log_r1924 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_id uuid NOT NULL REFERENCES public.engineer_mentor_network_r1924(id) ON DELETE CASCADE,
  checkin_at timestamptz NOT NULL DEFAULT now(),
  topic_md text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('on_track','needs_attention','blocker','breakthrough','escalated')),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emcl_r1924_pairing ON public.engineer_mentor_checkin_log_r1924(pairing_id);
CREATE INDEX IF NOT EXISTS idx_emcl_r1924_at ON public.engineer_mentor_checkin_log_r1924(checkin_at DESC);

ALTER TABLE public.engineer_mentor_network_r1924 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mentor_checkin_log_r1924 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_emn_r1924 ON public.engineer_mentor_network_r1924;
CREATE POLICY founder_all_emn_r1924 ON public.engineer_mentor_network_r1924
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_emcl_r1924 ON public.engineer_mentor_checkin_log_r1924;
CREATE POLICY founder_all_emcl_r1924 ON public.engineer_mentor_checkin_log_r1924
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_pairings_r1924()
RETURNS TABLE (
  id uuid,
  mentor_user_id uuid,
  mentor_email text,
  mentee_user_id uuid,
  mentee_email text,
  paired_at timestamptz,
  focus_area text,
  status text,
  last_check_in_at timestamptz,
  checkin_count bigint
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
    p.id,
    p.mentor_user_id,
    mp1.email,
    p.mentee_user_id,
    mp2.email,
    p.paired_at,
    p.focus_area,
    p.status,
    p.last_check_in_at,
    COALESCE(cl.cnt, 0)
  FROM public.engineer_mentor_network_r1924 p
  LEFT JOIN public.profiles mp1 ON mp1.id = p.mentor_user_id
  LEFT JOIN public.profiles mp2 ON mp2.id = p.mentee_user_id
  LEFT JOIN (
    SELECT pairing_id, COUNT(*)::bigint AS cnt
    FROM public.engineer_mentor_checkin_log_r1924
    GROUP BY pairing_id
  ) cl ON cl.pairing_id = p.id
  ORDER BY p.paired_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_pairing_r1924(
  p_mentor_user_id uuid,
  p_mentee_user_id uuid,
  p_focus_area text
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

  INSERT INTO public.engineer_mentor_network_r1924 (mentor_user_id, mentee_user_id, focus_area)
  VALUES (p_mentor_user_id, p_mentee_user_id, p_focus_area)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pairing_r1924',
    jsonb_build_object('id', v_id, 'mentor', p_mentor_user_id, 'mentee', p_mentee_user_id, 'focus', p_focus_area));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_checkins_r1924(p_pairing_id uuid)
RETURNS TABLE (
  id uuid,
  pairing_id uuid,
  checkin_at timestamptz,
  topic_md text,
  outcome text,
  by_email text
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
  SELECT c.id, c.pairing_id, c.checkin_at, c.topic_md, c.outcome, c.by_email
  FROM public.engineer_mentor_checkin_log_r1924 c
  WHERE c.pairing_id = p_pairing_id
  ORDER BY c.checkin_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_checkin_r1924(
  p_pairing_id uuid,
  p_topic_md text,
  p_outcome text,
  p_by_email text
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

  INSERT INTO public.engineer_mentor_checkin_log_r1924 (pairing_id, topic_md, outcome, by_email)
  VALUES (p_pairing_id, p_topic_md, p_outcome, p_by_email)
  RETURNING id INTO v_id;

  UPDATE public.engineer_mentor_network_r1924
  SET last_check_in_at = now(), updated_at = now()
  WHERE id = p_pairing_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_checkin_r1924',
    jsonb_build_object('id', v_id, 'pairing_id', p_pairing_id, 'outcome', p_outcome));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1924(
  p_pairing_id uuid,
  p_status text
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

  IF p_status NOT IN ('active','paused','completed','ended') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.engineer_mentor_network_r1924
  SET status = p_status, updated_at = now()
  WHERE id = p_pairing_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1924',
    jsonb_build_object('id', p_pairing_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.pairings_needing_checkin_r1924()
RETURNS TABLE (
  id uuid,
  mentor_email text,
  mentee_email text,
  focus_area text,
  paired_at timestamptz,
  last_check_in_at timestamptz,
  days_since_checkin numeric
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
    p.id,
    mp1.email,
    mp2.email,
    p.focus_area,
    p.paired_at,
    p.last_check_in_at,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(p.last_check_in_at, p.paired_at))) / 86400.0, 1)
  FROM public.engineer_mentor_network_r1924 p
  LEFT JOIN public.profiles mp1 ON mp1.id = p.mentor_user_id
  LEFT JOIN public.profiles mp2 ON mp2.id = p.mentee_user_id
  WHERE p.status = 'active'
    AND COALESCE(p.last_check_in_at, p.paired_at) < now() - interval '14 days'
  ORDER BY COALESCE(p.last_check_in_at, p.paired_at) ASC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_checkins_r1924()
RETURNS TABLE (
  id uuid,
  pairing_id uuid,
  mentor_email text,
  mentee_email text,
  focus_area text,
  checkin_at timestamptz,
  outcome text,
  topic_md text,
  by_email text
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
    c.id,
    c.pairing_id,
    mp1.email,
    mp2.email,
    p.focus_area,
    c.checkin_at,
    c.outcome,
    c.topic_md,
    c.by_email
  FROM public.engineer_mentor_checkin_log_r1924 c
  JOIN public.engineer_mentor_network_r1924 p ON p.id = c.pairing_id
  LEFT JOIN public.profiles mp1 ON mp1.id = p.mentor_user_id
  LEFT JOIN public.profiles mp2 ON mp2.id = p.mentee_user_id
  ORDER BY c.checkin_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================
-- REVOKE + GRANT
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.list_pairings_r1924() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pairing_r1924(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_checkins_r1924(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_checkin_r1924(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1924(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pairings_needing_checkin_r1924() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_checkins_r1924() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pairings_r1924() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pairing_r1924(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_checkins_r1924(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_checkin_r1924(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1924(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pairings_needing_checkin_r1924() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_checkins_r1924() TO authenticated;

COMMIT;
