BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_customer_feedback_memory_r1988 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  feedback_text_md text NOT NULL,
  feedback_category text NOT NULL CHECK (feedback_category IN ('appearance','skill','communication','punctuality','billing','follow_up')),
  sentiment text NOT NULL CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','acknowledged','addressed','disputed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecfm_r1988_engineer ON public.engineer_customer_feedback_memory_r1988(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecfm_r1988_captured ON public.engineer_customer_feedback_memory_r1988(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_ecfm_r1988_sentiment ON public.engineer_customer_feedback_memory_r1988(sentiment);

CREATE TABLE IF NOT EXISTS public.engineer_feedback_action_log_r1988 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feedback_id uuid NOT NULL REFERENCES public.engineer_customer_feedback_memory_r1988(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('acknowledged','coaching_assigned','escalated','disputed','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text NOT NULL,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efal_r1988_feedback ON public.engineer_feedback_action_log_r1988(feedback_id);
CREATE INDEX IF NOT EXISTS idx_efal_r1988_taken ON public.engineer_feedback_action_log_r1988(taken_at DESC);

ALTER TABLE public.engineer_customer_feedback_memory_r1988 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_feedback_action_log_r1988 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_ecfm_r1988_founder ON public.engineer_customer_feedback_memory_r1988;
CREATE POLICY p_ecfm_r1988_founder ON public.engineer_customer_feedback_memory_r1988
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_efal_r1988_founder ON public.engineer_feedback_action_log_r1988;
CREATE POLICY p_efal_r1988_founder ON public.engineer_feedback_action_log_r1988
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_feedback
CREATE OR REPLACE FUNCTION public.list_feedback_r1988()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  feedback_text_md text,
  feedback_category text,
  sentiment text,
  captured_at timestamptz,
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
  SELECT f.id, f.engineer_user_id, e.email, f.hospital_id, h.email,
         f.feedback_text_md, f.feedback_category, f.sentiment, f.captured_at, f.status
  FROM public.engineer_customer_feedback_memory_r1988 f
  LEFT JOIN public.profiles e ON e.id = f.engineer_user_id
  LEFT JOIN public.profiles h ON h.id = f.hospital_id
  ORDER BY f.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_feedback
CREATE OR REPLACE FUNCTION public.log_feedback_r1988(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_feedback_text_md text,
  p_feedback_category text,
  p_sentiment text
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
  INSERT INTO public.engineer_customer_feedback_memory_r1988(
    engineer_user_id, hospital_id, feedback_text_md, feedback_category, sentiment
  ) VALUES (
    p_engineer_user_id, p_hospital_id, p_feedback_text_md, p_feedback_category, p_sentiment
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_feedback_r1988',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'category', p_feedback_category, 'sentiment', p_sentiment));
  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r1988(p_feedback_id uuid)
RETURNS TABLE (
  id uuid,
  feedback_id uuid,
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
  SELECT a.id, a.feedback_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_feedback_action_log_r1988 a
  WHERE a.feedback_id = p_feedback_id
  ORDER BY a.taken_at DESC;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r1988(
  p_feedback_id uuid,
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
  INSERT INTO public.engineer_feedback_action_log_r1988(
    feedback_id, action_type, by_email, notes_md
  ) VALUES (
    p_feedback_id, p_action_type, p_by_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1988',
    jsonb_build_object('id', v_id, 'feedback_id', p_feedback_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1988(
  p_feedback_id uuid,
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
  UPDATE public.engineer_customer_feedback_memory_r1988
  SET status = p_status, updated_at = now()
  WHERE id = p_feedback_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1988',
    jsonb_build_object('id', p_feedback_id, 'status', p_status));
END;
$$;

-- 6. negative_feedback
CREATE OR REPLACE FUNCTION public.negative_feedback_r1988()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  feedback_category text,
  sentiment text,
  feedback_text_md text,
  captured_at timestamptz,
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
  SELECT f.id, f.engineer_user_id, e.email, f.feedback_category, f.sentiment, f.feedback_text_md, f.captured_at, f.status
  FROM public.engineer_customer_feedback_memory_r1988 f
  LEFT JOIN public.profiles e ON e.id = f.engineer_user_id
  WHERE f.sentiment IN ('negative','very_negative')
  ORDER BY f.captured_at DESC
  LIMIT 100;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r1988()
RETURNS TABLE (
  id uuid,
  feedback_id uuid,
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
  SELECT a.id, a.feedback_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_feedback_action_log_r1988 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_feedback_r1988() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_feedback_r1988(uuid, uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1988(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1988(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1988(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.negative_feedback_r1988() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1988() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_feedback_r1988() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_feedback_r1988(uuid, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1988(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1988(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1988(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.negative_feedback_r1988() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1988() TO authenticated;

COMMIT;
