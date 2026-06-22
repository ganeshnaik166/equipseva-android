BEGIN;

-- ============================================================================
-- Round 1913 — Investor Reference Checks Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_reference_checks_r1913 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid,
  referee_name text NOT NULL,
  referee_role text NOT NULL CHECK (referee_role IN ('customer','employee','partner','advisor')),
  contacted_at timestamptz,
  sentiment text CHECK (sentiment IN ('very_positive','positive','neutral','concerns','negative')),
  key_themes_md text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','declined')),
  founder_takeaway_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_reference_response_log_r1913 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  check_id uuid NOT NULL REFERENCES public.investor_reference_checks_r1913(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('note_added','follow_up_with_referee','investor_followup','founder_action_required')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  note_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irc_r1913_status ON public.investor_reference_checks_r1913(status);
CREATE INDEX IF NOT EXISTS idx_irc_r1913_sentiment ON public.investor_reference_checks_r1913(sentiment);
CREATE INDEX IF NOT EXISTS idx_irrl_r1913_check ON public.investor_reference_response_log_r1913(check_id);
CREATE INDEX IF NOT EXISTS idx_irrl_r1913_taken_at ON public.investor_reference_response_log_r1913(taken_at DESC);

ALTER TABLE public.investor_reference_checks_r1913 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_reference_response_log_r1913 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_irc_r1913 ON public.investor_reference_checks_r1913;
CREATE POLICY founder_all_irc_r1913 ON public.investor_reference_checks_r1913
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_irrl_r1913 ON public.investor_reference_response_log_r1913;
CREATE POLICY founder_all_irrl_r1913 ON public.investor_reference_response_log_r1913
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_checks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_reference_checks_r1913()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  referee_name text,
  referee_role text,
  contacted_at timestamptz,
  sentiment text,
  key_themes_md text,
  status text,
  founder_takeaway_md text,
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
  SELECT c.id, c.investor_id, c.referee_name, c.referee_role, c.contacted_at,
         c.sentiment, c.key_themes_md, c.status, c.founder_takeaway_md, c.created_at
  FROM public.investor_reference_checks_r1913 c
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_investor_reference_checks_r1913() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_reference_checks_r1913() TO authenticated;

-- ============================================================================
-- RPC 2: log_check
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_investor_reference_check_r1913(
  p_investor_id uuid,
  p_referee_name text,
  p_referee_role text,
  p_contacted_at timestamptz,
  p_sentiment text,
  p_key_themes_md text,
  p_founder_takeaway_md text
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
  INSERT INTO public.investor_reference_checks_r1913(
    investor_id, referee_name, referee_role, contacted_at,
    sentiment, key_themes_md, founder_takeaway_md
  )
  VALUES (
    p_investor_id, p_referee_name, p_referee_role, p_contacted_at,
    p_sentiment, p_key_themes_md, p_founder_takeaway_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_investor_reference_check_r1913',
    jsonb_build_object('check_id', v_id, 'referee_name', p_referee_name, 'sentiment', p_sentiment)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_investor_reference_check_r1913(uuid, text, text, timestamptz, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_reference_check_r1913(uuid, text, text, timestamptz, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_responses
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_reference_responses_r1913(p_check_id uuid)
RETURNS TABLE (
  id uuid,
  check_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  note_md text
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
  SELECT r.id, r.check_id, r.action_type, r.taken_at, r.by_email, r.note_md
  FROM public.investor_reference_response_log_r1913 r
  WHERE r.check_id = p_check_id
  ORDER BY r.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_investor_reference_responses_r1913(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_reference_responses_r1913(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_response
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_investor_reference_response_r1913(
  p_check_id uuid,
  p_action_type text,
  p_note_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt() ->> 'email');

  INSERT INTO public.investor_reference_response_log_r1913(check_id, action_type, by_email, note_md)
  VALUES (p_check_id, p_action_type, v_email, p_note_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_investor_reference_response_r1913',
    jsonb_build_object('response_id', v_id, 'check_id', p_check_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_investor_reference_response_r1913(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_reference_response_r1913(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_completed
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_investor_reference_check_completed_r1913(
  p_check_id uuid,
  p_founder_takeaway_md text
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
  UPDATE public.investor_reference_checks_r1913
  SET status = 'completed',
      founder_takeaway_md = COALESCE(p_founder_takeaway_md, founder_takeaway_md),
      updated_at = now()
  WHERE id = p_check_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'mark_investor_reference_check_completed_r1913',
    jsonb_build_object('check_id', p_check_id)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_investor_reference_check_completed_r1913(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_investor_reference_check_completed_r1913(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: top_themes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_investor_reference_themes_r1913()
RETURNS TABLE (
  sentiment text,
  check_count int,
  pending_count int,
  completed_count int
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
    COALESCE(c.sentiment, 'unspecified') AS sentiment,
    COUNT(*)::int AS check_count,
    (COUNT(*) FILTER (WHERE c.status = 'pending'))::int AS pending_count,
    (COUNT(*) FILTER (WHERE c.status = 'completed'))::int AS completed_count
  FROM public.investor_reference_checks_r1913 c
  GROUP BY COALESCE(c.sentiment, 'unspecified')
  ORDER BY check_count DESC
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_investor_reference_themes_r1913() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_investor_reference_themes_r1913() TO authenticated;

-- ============================================================================
-- RPC 7: recent_responses
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_investor_reference_responses_r1913()
RETURNS TABLE (
  id uuid,
  check_id uuid,
  referee_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  note_md text
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
  SELECT r.id, r.check_id, c.referee_name, r.action_type, r.taken_at, r.by_email, r.note_md
  FROM public.investor_reference_response_log_r1913 r
  LEFT JOIN public.investor_reference_checks_r1913 c ON c.id = r.check_id
  ORDER BY r.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_investor_reference_responses_r1913() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_investor_reference_responses_r1913() TO authenticated;

COMMIT;
