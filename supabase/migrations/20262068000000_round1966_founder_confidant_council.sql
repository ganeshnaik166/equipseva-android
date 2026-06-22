BEGIN;

-- =====================================================================
-- Round 1966 — Founder Confidant Council
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.founder_confidants_r1966 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  confidant_name text NOT NULL,
  confidant_role text NOT NULL CHECK (confidant_role IN ('personal_mentor','board_advisor','cofounder','spouse','friend','therapist','coach')),
  last_consultation_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','changed_roles','lost')),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_consultation_log_r1966 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  confidant_id uuid NOT NULL REFERENCES public.founder_confidants_r1966(id) ON DELETE CASCADE,
  topic_category text NOT NULL CHECK (topic_category IN ('business','personal','financial','relationship','health','decision_making')),
  consultation_at timestamptz NOT NULL DEFAULT now(),
  outcome_md text,
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcr1966_status ON public.founder_confidants_r1966(status);
CREATE INDEX IF NOT EXISTS idx_fcl1966_confidant ON public.founder_consultation_log_r1966(confidant_id, consultation_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcl1966_topic ON public.founder_consultation_log_r1966(topic_category);

ALTER TABLE public.founder_confidants_r1966 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_consultation_log_r1966 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fc_r1966_founder ON public.founder_confidants_r1966;
CREATE POLICY p_fc_r1966_founder ON public.founder_confidants_r1966
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_fcl_r1966_founder ON public.founder_consultation_log_r1966;
CREATE POLICY p_fcl_r1966_founder ON public.founder_consultation_log_r1966
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_confidants
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_confidants_r1966()
RETURNS TABLE (
  id uuid,
  confidant_name text,
  confidant_role text,
  last_consultation_at timestamptz,
  status text,
  consultation_count bigint
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
  SELECT c.id, c.confidant_name, c.confidant_role, c.last_consultation_at, c.status,
         (SELECT count(*) FROM public.founder_consultation_log_r1966 l WHERE l.confidant_id = c.id)
  FROM public.founder_confidants_r1966 c
  ORDER BY (c.status = 'active') DESC, c.last_consultation_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 2: log_confidant
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_confidant_r1966(
  p_name text,
  p_role text,
  p_notes_md text DEFAULT NULL
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
  INSERT INTO public.founder_confidants_r1966(confidant_name, confidant_role, notes_md)
  VALUES (p_name, p_role, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_confidant_r1966',
          jsonb_build_object('id', v_id, 'name', p_name, 'role', p_role));
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_consultations
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_consultations_r1966(p_confidant_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  confidant_id uuid,
  confidant_name text,
  topic_category text,
  consultation_at timestamptz,
  outcome_md text,
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
  SELECT l.id, l.confidant_id, c.confidant_name, l.topic_category, l.consultation_at, l.outcome_md, l.by_email
  FROM public.founder_consultation_log_r1966 l
  JOIN public.founder_confidants_r1966 c ON c.id = l.confidant_id
  WHERE p_confidant_id IS NULL OR l.confidant_id = p_confidant_id
  ORDER BY l.consultation_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 4: log_consultation
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_consultation_r1966(
  p_confidant_id uuid,
  p_topic_category text,
  p_outcome_md text DEFAULT NULL
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
  INSERT INTO public.founder_consultation_log_r1966(confidant_id, topic_category, outcome_md, by_email)
  VALUES (p_confidant_id, p_topic_category, p_outcome_md, (auth.jwt()->>'email'))
  RETURNING id INTO v_id;

  UPDATE public.founder_confidants_r1966
     SET last_consultation_at = now(), updated_at = now()
   WHERE id = p_confidant_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_consultation_r1966',
          jsonb_build_object('id', v_id, 'confidant_id', p_confidant_id, 'topic', p_topic_category));
  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: mark_status
-- =====================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r1966(
  p_confidant_id uuid,
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
  UPDATE public.founder_confidants_r1966
     SET status = p_status, updated_at = now()
   WHERE id = p_confidant_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1966',
          jsonb_build_object('confidant_id', p_confidant_id, 'status', p_status));
END;
$$;

-- =====================================================================
-- RPC 6: top_topics
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_topics_r1966()
RETURNS TABLE (
  topic_category text,
  consultation_count bigint,
  last_at timestamptz
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
  SELECT l.topic_category, count(*)::bigint, max(l.consultation_at)
  FROM public.founder_consultation_log_r1966 l
  GROUP BY l.topic_category
  ORDER BY count(*) DESC;
END;
$$;

-- =====================================================================
-- RPC 7: recent_consultations
-- =====================================================================
CREATE OR REPLACE FUNCTION public.recent_consultations_r1966()
RETURNS TABLE (
  id uuid,
  confidant_name text,
  confidant_role text,
  topic_category text,
  consultation_at timestamptz,
  outcome_md text
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
  SELECT l.id, c.confidant_name, c.confidant_role, l.topic_category, l.consultation_at, l.outcome_md
  FROM public.founder_consultation_log_r1966 l
  JOIN public.founder_confidants_r1966 c ON c.id = l.confidant_id
  WHERE l.consultation_at >= now() - interval '60 days'
  ORDER BY l.consultation_at DESC
  LIMIT 50;
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_confidants_r1966() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_confidant_r1966(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_consultations_r1966(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_consultation_r1966(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1966(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_topics_r1966() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_consultations_r1966() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_confidants_r1966() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_confidant_r1966(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_consultations_r1966(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_consultation_r1966(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1966(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_topics_r1966() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_consultations_r1966() TO authenticated;

COMMIT;
