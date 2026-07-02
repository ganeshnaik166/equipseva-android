BEGIN;

-- ============================================================================
-- Round 1848: Engineer Late Arrival Pattern
-- Detect engineers with chronic late-arrival pattern + interventions
-- ============================================================================

-- Pattern records per engineer per month
CREATE TABLE IF NOT EXISTS public.engineer_late_arrival_patterns_r1848 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  month_start date NOT NULL,
  late_count int NOT NULL DEFAULT 0,
  total_jobs int NOT NULL DEFAULT 0,
  late_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'no_issue'
    CHECK (status IN ('no_issue','watching','intervention','improved')),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, month_start)
);

-- Interventions tied to a pattern
CREATE TABLE IF NOT EXISTS public.engineer_late_arrival_interventions_r1848 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern_id uuid NOT NULL REFERENCES public.engineer_late_arrival_patterns_r1848(id) ON DELETE CASCADE,
  intervention_type text NOT NULL
    CHECK (intervention_type IN ('verbal_warning','written_warning','coaching','route_change','role_change')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_late_patterns_r1848_engineer
  ON public.engineer_late_arrival_patterns_r1848(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_late_patterns_r1848_status
  ON public.engineer_late_arrival_patterns_r1848(status);
CREATE INDEX IF NOT EXISTS idx_late_interventions_r1848_pattern
  ON public.engineer_late_arrival_interventions_r1848(pattern_id);

ALTER TABLE public.engineer_late_arrival_patterns_r1848 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_late_arrival_interventions_r1848 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_patterns_r1848 ON public.engineer_late_arrival_patterns_r1848;
CREATE POLICY founder_all_patterns_r1848 ON public.engineer_late_arrival_patterns_r1848
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_interventions_r1848 ON public.engineer_late_arrival_interventions_r1848;
CREATE POLICY founder_all_interventions_r1848 ON public.engineer_late_arrival_interventions_r1848
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_patterns
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_late_arrival_patterns_r1848();
CREATE OR REPLACE FUNCTION public.list_late_arrival_patterns_r1848()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  month_start date,
  late_count int,
  total_jobs int,
  late_rate_pct numeric,
  status text,
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
  SELECT p.id, p.engineer_user_id, pr.email::text, p.month_start,
         p.late_count, p.total_jobs, p.late_rate_pct, p.status, p.recorded_at
  FROM public.engineer_late_arrival_patterns_r1848 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY p.month_start DESC, p.late_rate_pct DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_late_arrival_patterns_r1848() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_late_arrival_patterns_r1848() TO authenticated;

-- ============================================================================
-- RPC 2: refresh_patterns (recomputes current-month pattern rows)
-- ============================================================================
DROP FUNCTION IF EXISTS public.refresh_late_arrival_patterns_r1848();
CREATE OR REPLACE FUNCTION public.refresh_late_arrival_patterns_r1848()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_month date := date_trunc('month', now())::date;
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_late_arrival_patterns_r1848
    (engineer_user_id, month_start, late_count, total_jobs, late_rate_pct, status, recorded_at)
  SELECT
    e.user_id,
    v_month,
    0,
    (COUNT(*) FILTER (WHERE rj.completed_at >= v_month))::int,
    0,
    'no_issue',
    now()
  FROM public.engineers e
  LEFT JOIN public.repair_jobs rj ON rj.engineer_id = e.id
  GROUP BY e.user_id
  ON CONFLICT (engineer_user_id, month_start) DO UPDATE
    SET total_jobs = EXCLUDED.total_jobs,
        updated_at = now();

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'refresh_late_arrival_patterns_r1848',
          jsonb_build_object('month', v_month, 'rows', v_count));

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_late_arrival_patterns_r1848() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_late_arrival_patterns_r1848() TO authenticated;

-- ============================================================================
-- RPC 3: list_interventions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_late_arrival_interventions_r1848(uuid);
CREATE OR REPLACE FUNCTION public.list_late_arrival_interventions_r1848(p_pattern_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  pattern_id uuid,
  engineer_email text,
  intervention_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
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
  SELECT i.id, i.pattern_id, pr.email::text, i.intervention_type,
         i.taken_at, i.by_email, i.outcome
  FROM public.engineer_late_arrival_interventions_r1848 i
  LEFT JOIN public.engineer_late_arrival_patterns_r1848 p ON p.id = i.pattern_id
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE (p_pattern_id IS NULL OR i.pattern_id = p_pattern_id)
  ORDER BY i.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_late_arrival_interventions_r1848(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_late_arrival_interventions_r1848(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: log_intervention
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_late_arrival_intervention_r1848(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_late_arrival_intervention_r1848(
  p_pattern_id uuid,
  p_intervention_type text,
  p_outcome text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text := (auth.jwt()->>'email');
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_late_arrival_interventions_r1848
    (pattern_id, intervention_type, by_email, outcome)
  VALUES (p_pattern_id, p_intervention_type, v_email, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.engineer_late_arrival_patterns_r1848
    SET status = 'intervention', updated_at = now()
    WHERE id = p_pattern_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_late_arrival_intervention_r1848',
          jsonb_build_object('pattern_id', p_pattern_id, 'type', p_intervention_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_late_arrival_intervention_r1848(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_late_arrival_intervention_r1848(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_improved
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_late_arrival_improved_r1848(uuid);
CREATE OR REPLACE FUNCTION public.mark_late_arrival_improved_r1848(p_pattern_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_late_arrival_patterns_r1848
    SET status = 'improved', updated_at = now()
    WHERE id = p_pattern_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_late_arrival_improved_r1848',
          jsonb_build_object('pattern_id', p_pattern_id));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_late_arrival_improved_r1848(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_late_arrival_improved_r1848(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: top_offenders
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_late_arrival_offenders_r1848();
CREATE OR REPLACE FUNCTION public.top_late_arrival_offenders_r1848()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_late int,
  total_jobs int,
  avg_late_rate numeric,
  months_tracked int
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
  SELECT p.engineer_user_id,
         pr.email::text,
         SUM(p.late_count)::int,
         SUM(p.total_jobs)::int,
         ROUND(AVG(p.late_rate_pct), 2),
         COUNT(*)::int
  FROM public.engineer_late_arrival_patterns_r1848 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  GROUP BY p.engineer_user_id, pr.email
  ORDER BY AVG(p.late_rate_pct) DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_late_arrival_offenders_r1848() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_late_arrival_offenders_r1848() TO authenticated;

-- ============================================================================
-- RPC 7: recent_interventions
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_late_arrival_interventions_r1848();
CREATE OR REPLACE FUNCTION public.recent_late_arrival_interventions_r1848()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  intervention_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
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
  SELECT i.id, pr.email::text, i.intervention_type,
         i.taken_at, i.by_email, i.outcome
  FROM public.engineer_late_arrival_interventions_r1848 i
  LEFT JOIN public.engineer_late_arrival_patterns_r1848 p ON p.id = i.pattern_id
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY i.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_late_arrival_interventions_r1848() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_late_arrival_interventions_r1848() TO authenticated;

COMMIT;