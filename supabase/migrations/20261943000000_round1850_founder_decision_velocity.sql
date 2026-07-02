BEGIN;

-- =========================================================================
-- Round 1850 — Founder Decision Velocity
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_decision_velocity_r1850 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_topic text NOT NULL,
  asked_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  queue_minutes int,
  decision_quality_score int CHECK (decision_quality_score BETWEEN 1 AND 10),
  was_reversible boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','decided','parked','escalated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_decision_velocity_outliers_r1850 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.founder_decision_velocity_r1850(id) ON DELETE CASCADE,
  outlier_type text NOT NULL CHECK (outlier_type IN ('too_slow','too_fast','reversed','regretted')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fdv_r1850_status ON public.founder_decision_velocity_r1850(status);
CREATE INDEX IF NOT EXISTS idx_fdv_r1850_asked_at ON public.founder_decision_velocity_r1850(asked_at DESC);
CREATE INDEX IF NOT EXISTS idx_fdvo_r1850_decision ON public.founder_decision_velocity_outliers_r1850(decision_id);
CREATE INDEX IF NOT EXISTS idx_fdvo_r1850_recorded ON public.founder_decision_velocity_outliers_r1850(recorded_at DESC);

ALTER TABLE public.founder_decision_velocity_r1850 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_decision_velocity_outliers_r1850 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fdv_r1850_founder_all ON public.founder_decision_velocity_r1850;
CREATE POLICY fdv_r1850_founder_all ON public.founder_decision_velocity_r1850
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fdvo_r1850_founder_all ON public.founder_decision_velocity_outliers_r1850;
CREATE POLICY fdvo_r1850_founder_all ON public.founder_decision_velocity_outliers_r1850
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

CREATE OR REPLACE FUNCTION public.list_decisions_r1850()
RETURNS TABLE (
  id uuid,
  decision_topic text,
  asked_at timestamptz,
  decided_at timestamptz,
  queue_minutes int,
  decision_quality_score int,
  was_reversible boolean,
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
  SELECT d.id, d.decision_topic, d.asked_at, d.decided_at,
         d.queue_minutes, d.decision_quality_score, d.was_reversible, d.status
  FROM public.founder_decision_velocity_r1850 d
  ORDER BY d.asked_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_decision_r1850(
  p_topic text,
  p_reversible boolean DEFAULT true
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

  INSERT INTO public.founder_decision_velocity_r1850 (decision_topic, was_reversible)
  VALUES (p_topic, COALESCE(p_reversible, true))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_decision_r1850',
          jsonb_build_object('decision_id', v_id, 'topic', p_topic, 'reversible', p_reversible));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_outliers_r1850()
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  decision_topic text,
  outlier_type text,
  recorded_at timestamptz,
  founder_note text
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
  SELECT o.id, o.decision_id, d.decision_topic, o.outlier_type, o.recorded_at, o.founder_note
  FROM public.founder_decision_velocity_outliers_r1850 o
  LEFT JOIN public.founder_decision_velocity_r1850 d ON d.id = o.decision_id
  ORDER BY o.recorded_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_outlier_r1850(
  p_decision_id uuid,
  p_outlier_type text,
  p_note text DEFAULT NULL
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

  IF p_outlier_type NOT IN ('too_slow','too_fast','reversed','regretted') THEN
    RAISE EXCEPTION 'invalid outlier_type';
  END IF;

  INSERT INTO public.founder_decision_velocity_outliers_r1850 (decision_id, outlier_type, founder_note)
  VALUES (p_decision_id, p_outlier_type, p_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_outlier_r1850',
          jsonb_build_object('outlier_id', v_id, 'decision_id', p_decision_id, 'type', p_outlier_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_decision_r1850(
  p_id uuid,
  p_quality_score int,
  p_status text DEFAULT 'decided'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_asked timestamptz;
  v_queue int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('pending','decided','parked','escalated') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  IF p_quality_score IS NOT NULL AND (p_quality_score < 1 OR p_quality_score > 10) THEN
    RAISE EXCEPTION 'quality score must be 1-10';
  END IF;

  SELECT asked_at INTO v_asked
  FROM public.founder_decision_velocity_r1850
  WHERE id = p_id;

  IF v_asked IS NULL THEN
    RAISE EXCEPTION 'decision not found';
  END IF;

  v_queue := GREATEST(0, EXTRACT(EPOCH FROM (now() - v_asked))::int / 60);

  UPDATE public.founder_decision_velocity_r1850
  SET decided_at = now(),
      queue_minutes = v_queue,
      decision_quality_score = p_quality_score,
      status = p_status,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_decision_r1850',
          jsonb_build_object('decision_id', p_id, 'quality', p_quality_score, 'status', p_status, 'queue_minutes', v_queue));
END;
$$;

CREATE OR REPLACE FUNCTION public.velocity_summary_r1850()
RETURNS TABLE (
  total_decisions int,
  pending_count int,
  decided_count int,
  parked_count int,
  escalated_count int,
  avg_queue_minutes numeric,
  avg_quality_score numeric,
  reversible_share_pct numeric,
  outlier_count int
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
    (COUNT(*))::int AS total_decisions,
    (COUNT(*) FILTER (WHERE d.status = 'pending'))::int AS pending_count,
    (COUNT(*) FILTER (WHERE d.status = 'decided'))::int AS decided_count,
    (COUNT(*) FILTER (WHERE d.status = 'parked'))::int AS parked_count,
    (COUNT(*) FILTER (WHERE d.status = 'escalated'))::int AS escalated_count,
    ROUND(AVG(d.queue_minutes) FILTER (WHERE d.queue_minutes IS NOT NULL), 1) AS avg_queue_minutes,
    ROUND(AVG(d.decision_quality_score) FILTER (WHERE d.decision_quality_score IS NOT NULL), 2) AS avg_quality_score,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE d.was_reversible) / COUNT(*), 1)
    END AS reversible_share_pct,
    (SELECT COUNT(*)::int FROM public.founder_decision_velocity_outliers_r1850) AS outlier_count
  FROM public.founder_decision_velocity_r1850 d;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_outliers_r1850(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  decision_id uuid,
  decision_topic text,
  outlier_type text,
  recorded_at timestamptz,
  founder_note text
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
  SELECT o.id, o.decision_id, d.decision_topic, o.outlier_type, o.recorded_at, o.founder_note
  FROM public.founder_decision_velocity_outliers_r1850 o
  LEFT JOIN public.founder_decision_velocity_r1850 d ON d.id = o.decision_id
  ORDER BY o.recorded_at DESC
  LIMIT COALESCE(p_limit, 25);
END;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_decisions_r1850() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decision_r1850(text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outliers_r1850() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_outlier_r1850(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_decision_r1850(uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.velocity_summary_r1850() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_outliers_r1850(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_decisions_r1850() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decision_r1850(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outliers_r1850() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_outlier_r1850(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_decision_r1850(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.velocity_summary_r1850() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_outliers_r1850(int) TO authenticated;

COMMIT;