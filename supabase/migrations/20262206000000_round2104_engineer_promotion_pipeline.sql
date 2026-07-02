BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_promotion_pipeline_r2104 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_tier text NOT NULL,
  target_tier text NOT NULL,
  readiness_score int NOT NULL CHECK (readiness_score BETWEEN 0 AND 100),
  status text NOT NULL CHECK (status IN ('candidate','in_review','approved','declined','promoted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_promotion_action_log_r2104 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id uuid NOT NULL REFERENCES public.engineer_promotion_pipeline_r2104(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('nominated','reviewed','approved','declined','promoted','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_promotion_pipeline_r2104 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_promotion_action_log_r2104 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pipeline_r2104 ON public.engineer_promotion_pipeline_r2104;
CREATE POLICY founder_all_pipeline_r2104 ON public.engineer_promotion_pipeline_r2104
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2104 ON public.engineer_promotion_action_log_r2104;
CREATE POLICY founder_all_action_log_r2104 ON public.engineer_promotion_action_log_r2104
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_candidates
CREATE OR REPLACE FUNCTION public.list_candidates_r2104()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  current_tier text,
  target_tier text,
  readiness_score int,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.current_tier, p.target_tier, p.readiness_score, p.status, p.captured_at
  FROM public.engineer_promotion_pipeline_r2104 p
  ORDER BY p.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_candidate
CREATE OR REPLACE FUNCTION public.log_candidate_r2104(
  p_engineer_user_id uuid,
  p_current_tier text,
  p_target_tier text,
  p_readiness_score int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_promotion_pipeline_r2104(engineer_user_id, current_tier, target_tier, readiness_score, status)
  VALUES (p_engineer_user_id, p_current_tier, p_target_tier, p_readiness_score, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_candidate_r2104',
    jsonb_build_object('pipeline_id', v_id, 'engineer_user_id', p_engineer_user_id, 'target_tier', p_target_tier, 'readiness_score', p_readiness_score));

  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2104(p_pipeline_id uuid)
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pipeline_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_promotion_action_log_r2104 a
  WHERE a.pipeline_id = p_pipeline_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2104(
  p_pipeline_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_promotion_action_log_r2104(pipeline_id, action_type, by_email, notes_md)
  VALUES (p_pipeline_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2104',
    jsonb_build_object('action_id', v_id, 'pipeline_id', p_pipeline_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2104(p_pipeline_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_promotion_pipeline_r2104
  SET status = p_status, updated_at = now()
  WHERE id = p_pipeline_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2104',
    jsonb_build_object('pipeline_id', p_pipeline_id, 'status', p_status));
END;
$$;

-- 6. top_ready
CREATE OR REPLACE FUNCTION public.top_ready_r2104()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  current_tier text,
  target_tier text,
  readiness_score int,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_user_id, p.current_tier, p.target_tier, p.readiness_score, p.status, p.captured_at
  FROM public.engineer_promotion_pipeline_r2104 p
  WHERE p.status IN ('candidate','in_review','approved')
  ORDER BY p.readiness_score DESC, p.captured_at DESC
  LIMIT 50;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2104()
RETURNS TABLE (
  id uuid,
  pipeline_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.pipeline_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_promotion_action_log_r2104 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_candidates_r2104() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_candidate_r2104(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2104(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2104(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2104(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_ready_r2104() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2104() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_candidates_r2104() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_candidate_r2104(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2104(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2104(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2104(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_ready_r2104() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2104() TO authenticated;

COMMIT;
