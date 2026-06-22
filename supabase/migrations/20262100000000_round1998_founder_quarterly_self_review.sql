BEGIN;

-- ============================================================================
-- Round 1998: Founder Quarterly Self-Review
-- Tables: founder_quarterly_self_review_r1998, founder_self_review_action_log_r1998
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_quarterly_self_review_r1998 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  year int NOT NULL,
  what_changed_md text,
  what_to_change_md text,
  what_to_keep_md text,
  key_blocker_md text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  finalized_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_self_review_action_log_r1998 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES public.founder_quarterly_self_review_r1998(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('published','shared_with_team','escalated','personal_commitment','behavioral_change')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_self_review_r1998 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_self_review_action_log_r1998 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1998_review ON public.founder_quarterly_self_review_r1998;
CREATE POLICY founder_all_r1998_review ON public.founder_quarterly_self_review_r1998
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1998_actions ON public.founder_self_review_action_log_r1998;
CREATE POLICY founder_all_r1998_actions ON public.founder_self_review_action_log_r1998
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_reviews
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_list_reviews();
CREATE OR REPLACE FUNCTION public.r1998_list_reviews()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  year int,
  status text,
  recorded_at timestamptz,
  finalized_at timestamptz
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
  SELECT r.id, r.quarter_label, r.year, r.status, r.recorded_at, r.finalized_at
  FROM public.founder_quarterly_self_review_r1998 r
  ORDER BY r.year DESC, r.recorded_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_list_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_list_reviews() TO authenticated;

-- ============================================================================
-- RPC 2: log_review
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_log_review(text, int, text, text, text, text);
CREATE OR REPLACE FUNCTION public.r1998_log_review(
  p_quarter_label text,
  p_year int,
  p_what_changed_md text,
  p_what_to_change_md text,
  p_what_to_keep_md text,
  p_key_blocker_md text
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
  INSERT INTO public.founder_quarterly_self_review_r1998 (
    quarter_label, year, what_changed_md, what_to_change_md, what_to_keep_md, key_blocker_md
  ) VALUES (
    p_quarter_label, p_year, p_what_changed_md, p_what_to_change_md, p_what_to_keep_md, p_key_blocker_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1998_log_review',
    jsonb_build_object('review_id', v_id, 'quarter_label', p_quarter_label, 'year', p_year)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_log_review(text, int, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_log_review(text, int, text, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_list_actions(uuid);
CREATE OR REPLACE FUNCTION public.r1998_list_actions(p_review_id uuid)
RETURNS TABLE (
  id uuid,
  review_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
  SELECT a.id, a.review_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_self_review_action_log_r1998 a
  WHERE a.review_id = p_review_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_list_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_list_actions(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_log_action(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r1998_log_action(
  p_review_id uuid,
  p_action_type text,
  p_by_email text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_self_review_action_log_r1998 (review_id, action_type, by_email, notes_md)
  VALUES (p_review_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1998_log_action',
    jsonb_build_object('action_id', v_id, 'review_id', p_review_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_log_action(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_log_action(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_mark_status(uuid, text);
CREATE OR REPLACE FUNCTION public.r1998_mark_status(
  p_review_id uuid,
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
  IF p_status NOT IN ('draft','published','archived') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.founder_quarterly_self_review_r1998
  SET status = p_status,
      finalized_at = CASE WHEN p_status = 'published' THEN now() ELSE finalized_at END,
      updated_at = now()
  WHERE id = p_review_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1998_mark_status',
    jsonb_build_object('review_id', p_review_id, 'status', p_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_mark_status(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: recent_reviews
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_recent_reviews();
CREATE OR REPLACE FUNCTION public.r1998_recent_reviews()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  year int,
  status text,
  what_changed_md text,
  recorded_at timestamptz
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
  SELECT r.id, r.quarter_label, r.year, r.status, r.what_changed_md, r.recorded_at
  FROM public.founder_quarterly_self_review_r1998 r
  ORDER BY r.recorded_at DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_recent_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_recent_reviews() TO authenticated;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1998_recent_actions();
CREATE OR REPLACE FUNCTION public.r1998_recent_actions()
RETURNS TABLE (
  id uuid,
  review_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
  SELECT a.id, a.review_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_self_review_action_log_r1998 a
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1998_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1998_recent_actions() TO authenticated;

COMMIT;
