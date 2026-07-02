BEGIN;

-- Round 1948: Engineer Customer-Facing Communication Coach
-- Tables track per-engineer coaching focus areas + action log

CREATE TABLE IF NOT EXISTS public.engineer_customer_comm_coaching_r1948 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  coaching_focus text NOT NULL CHECK (coaching_focus IN ('tone','empathy','jargon_reduction','escalation_handling','closing','active_listening')),
  current_score int NOT NULL CHECK (current_score BETWEEN 1 AND 10),
  target_score int NOT NULL CHECK (target_score BETWEEN 1 AND 10),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','improving','needs_attention','excelled','paused')),
  started_at timestamptz NOT NULL DEFAULT now(),
  last_assessed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eccc_r1948_engineer ON public.engineer_customer_comm_coaching_r1948(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eccc_r1948_status ON public.engineer_customer_comm_coaching_r1948(status);

CREATE TABLE IF NOT EXISTS public.engineer_comm_coaching_log_r1948 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coaching_id uuid NOT NULL REFERENCES public.engineer_customer_comm_coaching_r1948(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('roleplay','shadow','call_review','positive_feedback','escalation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  score_change int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eccl_r1948_coaching ON public.engineer_comm_coaching_log_r1948(coaching_id);
CREATE INDEX IF NOT EXISTS idx_eccl_r1948_taken ON public.engineer_comm_coaching_log_r1948(taken_at DESC);

ALTER TABLE public.engineer_customer_comm_coaching_r1948 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_comm_coaching_log_r1948 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eccc_r1948 ON public.engineer_customer_comm_coaching_r1948;
CREATE POLICY founder_all_eccc_r1948 ON public.engineer_customer_comm_coaching_r1948
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eccl_r1948 ON public.engineer_comm_coaching_log_r1948;
CREATE POLICY founder_all_eccl_r1948 ON public.engineer_comm_coaching_log_r1948
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list coachings
CREATE OR REPLACE FUNCTION public.list_engineer_comm_coachings_r1948()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  coaching_focus text,
  current_score int,
  target_score int,
  status text,
  started_at timestamptz,
  last_assessed_at timestamptz
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
  SELECT c.id, c.engineer_user_id, p.email, c.coaching_focus, c.current_score, c.target_score,
         c.status, c.started_at, c.last_assessed_at
  FROM public.engineer_customer_comm_coaching_r1948 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY c.started_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log a coaching plan
CREATE OR REPLACE FUNCTION public.log_engineer_comm_coaching_r1948(
  p_engineer_user_id uuid,
  p_coaching_focus text,
  p_current_score int,
  p_target_score int
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
  INSERT INTO public.engineer_customer_comm_coaching_r1948(engineer_user_id, coaching_focus, current_score, target_score)
  VALUES (p_engineer_user_id, p_coaching_focus, p_current_score, p_target_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engineer_comm_coaching_r1948',
    jsonb_build_object('coaching_id', v_id, 'engineer_user_id', p_engineer_user_id, 'focus', p_coaching_focus));
  RETURN v_id;
END;
$$;

-- RPC 3: list actions
CREATE OR REPLACE FUNCTION public.list_engineer_comm_coaching_actions_r1948(p_coaching_id uuid)
RETURNS TABLE (
  id uuid,
  coaching_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  score_change int
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
  SELECT l.id, l.coaching_id, l.action_type, l.taken_at, l.by_email, l.score_change
  FROM public.engineer_comm_coaching_log_r1948 l
  WHERE l.coaching_id = p_coaching_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log an action
CREATE OR REPLACE FUNCTION public.log_engineer_comm_coaching_action_r1948(
  p_coaching_id uuid,
  p_action_type text,
  p_score_change int
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
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_comm_coaching_log_r1948(coaching_id, action_type, by_email, score_change)
  VALUES (p_coaching_id, p_action_type, v_email, p_score_change)
  RETURNING id INTO v_id;

  UPDATE public.engineer_customer_comm_coaching_r1948
  SET current_score = LEAST(10, GREATEST(1, current_score + p_score_change)),
      last_assessed_at = now(),
      updated_at = now()
  WHERE id = p_coaching_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_engineer_comm_coaching_action_r1948',
    jsonb_build_object('coaching_id', p_coaching_id, 'action', p_action_type, 'delta', p_score_change));
  RETURN v_id;
END;
$$;

-- RPC 5: mark status
CREATE OR REPLACE FUNCTION public.mark_engineer_comm_coaching_status_r1948(
  p_coaching_id uuid,
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
  UPDATE public.engineer_customer_comm_coaching_r1948
  SET status = p_status, updated_at = now()
  WHERE id = p_coaching_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_engineer_comm_coaching_status_r1948',
    jsonb_build_object('coaching_id', p_coaching_id, 'status', p_status));
END;
$$;

-- RPC 6: needs_attention engineers
CREATE OR REPLACE FUNCTION public.needs_attention_engineer_comm_coachings_r1948()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  coaching_focus text,
  current_score int,
  target_score int,
  gap int,
  last_assessed_at timestamptz
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
  SELECT c.id, c.engineer_user_id, p.email, c.coaching_focus, c.current_score, c.target_score,
         (c.target_score - c.current_score) AS gap, c.last_assessed_at
  FROM public.engineer_customer_comm_coaching_r1948 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.status = 'needs_attention' OR (c.target_score - c.current_score) >= 3
  ORDER BY (c.target_score - c.current_score) DESC
  LIMIT 100;
END;
$$;

-- RPC 7: recent actions across all coachings
CREATE OR REPLACE FUNCTION public.recent_engineer_comm_coaching_actions_r1948()
RETURNS TABLE (
  id uuid,
  coaching_id uuid,
  engineer_email text,
  coaching_focus text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  score_change int
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
  SELECT l.id, l.coaching_id, p.email, c.coaching_focus, l.action_type, l.taken_at, l.by_email, l.score_change
  FROM public.engineer_comm_coaching_log_r1948 l
  JOIN public.engineer_customer_comm_coaching_r1948 c ON c.id = l.coaching_id
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_engineer_comm_coachings_r1948() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_comm_coachings_r1948() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_engineer_comm_coaching_r1948(uuid, text, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_engineer_comm_coaching_r1948(uuid, text, int, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_engineer_comm_coaching_actions_r1948(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_comm_coaching_actions_r1948(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_engineer_comm_coaching_action_r1948(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_engineer_comm_coaching_action_r1948(uuid, text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_engineer_comm_coaching_status_r1948(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_engineer_comm_coaching_status_r1948(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.needs_attention_engineer_comm_coachings_r1948() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.needs_attention_engineer_comm_coachings_r1948() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_engineer_comm_coaching_actions_r1948() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_engineer_comm_coaching_actions_r1948() TO authenticated;

COMMIT;
