BEGIN;

-- =====================================================================
-- Round 1775 — Hospital Operational Excellence Score
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_ops_excellence_scores_r1775 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  uptime_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_response_min int NOT NULL DEFAULT 0,
  satisfaction_score numeric(3,2) NOT NULL DEFAULT 0,
  staff_training_pct numeric(5,2) NOT NULL DEFAULT 0,
  composite_score int NOT NULL DEFAULT 0 CHECK (composite_score BETWEEN 0 AND 100),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'good' CHECK (status IN ('excellent','good','needs_improvement','critical')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hops_excl_r1775_hospital ON public.hospital_ops_excellence_scores_r1775(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hops_excl_r1775_status ON public.hospital_ops_excellence_scores_r1775(status);
CREATE INDEX IF NOT EXISTS idx_hops_excl_r1775_recorded ON public.hospital_ops_excellence_scores_r1775(recorded_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_ops_action_plans_r1775 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.hospital_ops_excellence_scores_r1775(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hops_actions_r1775_score ON public.hospital_ops_action_plans_r1775(score_id);
CREATE INDEX IF NOT EXISTS idx_hops_actions_r1775_status ON public.hospital_ops_action_plans_r1775(status);

ALTER TABLE public.hospital_ops_excellence_scores_r1775 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_ops_action_plans_r1775 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hops_excl_r1775_founder ON public.hospital_ops_excellence_scores_r1775;
CREATE POLICY hops_excl_r1775_founder ON public.hospital_ops_excellence_scores_r1775
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hops_actions_r1775_founder ON public.hospital_ops_action_plans_r1775;
CREATE POLICY hops_actions_r1775_founder ON public.hospital_ops_action_plans_r1775
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_scores
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_hops_excl_scores_r1775()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  uptime_pct numeric,
  avg_response_min int,
  satisfaction_score numeric,
  staff_training_pct numeric,
  composite_score int,
  recorded_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_user_id, p.email::text, s.uptime_pct, s.avg_response_min,
         s.satisfaction_score, s.staff_training_pct, s.composite_score, s.recorded_at, s.status
  FROM public.hospital_ops_excellence_scores_r1775 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  ORDER BY s.recorded_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================================
-- RPC 2: compute_score
-- =====================================================================
CREATE OR REPLACE FUNCTION public.compute_hops_excl_score_r1775(
  p_hospital_user_id uuid,
  p_uptime_pct numeric,
  p_avg_response_min int,
  p_satisfaction_score numeric,
  p_staff_training_pct numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_composite int;
  v_status text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_composite := LEAST(100, GREATEST(0, ROUND(
    (COALESCE(p_uptime_pct,0) * 0.30)
    + (GREATEST(0, 100 - LEAST(100, COALESCE(p_avg_response_min,0))) * 0.20)
    + (COALESCE(p_satisfaction_score,0) * 20 * 0.30)
    + (COALESCE(p_staff_training_pct,0) * 0.20)
  )::int));

  v_status := CASE
    WHEN v_composite >= 90 THEN 'excellent'
    WHEN v_composite >= 75 THEN 'good'
    WHEN v_composite >= 50 THEN 'needs_improvement'
    ELSE 'critical'
  END;

  INSERT INTO public.hospital_ops_excellence_scores_r1775(
    hospital_user_id, uptime_pct, avg_response_min, satisfaction_score,
    staff_training_pct, composite_score, status
  ) VALUES (
    p_hospital_user_id, COALESCE(p_uptime_pct,0), COALESCE(p_avg_response_min,0),
    COALESCE(p_satisfaction_score,0), COALESCE(p_staff_training_pct,0),
    v_composite, v_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'compute_hops_excl_score_r1775',
          jsonb_build_object('score_id', v_id, 'hospital_user_id', p_hospital_user_id, 'composite', v_composite));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_actions
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_hops_actions_r1775(p_score_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  score_id uuid,
  action_text text,
  owner_email text,
  due_date date,
  status text,
  completed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.score_id, a.action_text, a.owner_email, a.due_date, a.status, a.completed_at, a.created_at
  FROM public.hospital_ops_action_plans_r1775 a
  WHERE (p_score_id IS NULL OR a.score_id = p_score_id)
  ORDER BY a.created_at DESC
  LIMIT 500;
END;
$$;

-- =====================================================================
-- RPC 4: log_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_hops_action_r1775(
  p_score_id uuid,
  p_action_text text,
  p_owner_email text,
  p_due_date date
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

  INSERT INTO public.hospital_ops_action_plans_r1775(score_id, action_text, owner_email, due_date)
  VALUES (p_score_id, p_action_text, p_owner_email, p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_hops_action_r1775',
          jsonb_build_object('action_id', v_id, 'score_id', p_score_id));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 5: complete_action
-- =====================================================================
CREATE OR REPLACE FUNCTION public.complete_hops_action_r1775(p_action_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_ops_action_plans_r1775
  SET status = 'done', completed_at = now(), updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_hops_action_r1775',
          jsonb_build_object('action_id', p_action_id));
END;
$$;

-- =====================================================================
-- RPC 6: top_excellent
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_excellent_hops_r1775()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  latest_score int,
  status text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.hospital_user_id)
    s.hospital_user_id, p.email::text, s.composite_score, s.status, s.recorded_at
  FROM public.hospital_ops_excellence_scores_r1775 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.status IN ('excellent','good')
  ORDER BY s.hospital_user_id, s.recorded_at DESC
  LIMIT 50;
END;
$$;

-- =====================================================================
-- RPC 7: needing_improvement
-- =====================================================================
CREATE OR REPLACE FUNCTION public.needing_improvement_hops_r1775()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  latest_score int,
  status text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.hospital_user_id)
    s.hospital_user_id, p.email::text, s.composite_score, s.status, s.recorded_at
  FROM public.hospital_ops_excellence_scores_r1775 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_user_id
  WHERE s.status IN ('needs_improvement','critical')
  ORDER BY s.hospital_user_id, s.recorded_at DESC
  LIMIT 50;
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_hops_excl_scores_r1775() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.compute_hops_excl_score_r1775(uuid, numeric, int, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_hops_actions_r1775(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hops_action_r1775(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_hops_action_r1775(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_excellent_hops_r1775() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.needing_improvement_hops_r1775() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hops_excl_scores_r1775() TO authenticated;
GRANT EXECUTE ON FUNCTION public.compute_hops_excl_score_r1775(uuid, numeric, int, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_hops_actions_r1775(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hops_action_r1775(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_hops_action_r1775(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_excellent_hops_r1775() TO authenticated;
GRANT EXECUTE ON FUNCTION public.needing_improvement_hops_r1775() TO authenticated;

COMMIT;