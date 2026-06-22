BEGIN;

-- =============================================================================
-- Round 1884: Engineer Equipment Field Test Log
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_field_tests_r1884 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  manufacturer text NOT NULL,
  test_started_at timestamptz NOT NULL DEFAULT now(),
  test_duration_days int NOT NULL DEFAULT 30 CHECK (test_duration_days > 0),
  primary_use_case text NOT NULL,
  performance_score int CHECK (performance_score IS NULL OR (performance_score BETWEEN 1 AND 10)),
  would_recommend boolean,
  status text NOT NULL DEFAULT 'ongoing' CHECK (status IN ('ongoing','passed','failed','withdrawn')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eq_field_tests_r1884_engineer
  ON public.engineer_equipment_field_tests_r1884(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eq_field_tests_r1884_status
  ON public.engineer_equipment_field_tests_r1884(status);
CREATE INDEX IF NOT EXISTS idx_eq_field_tests_r1884_started
  ON public.engineer_equipment_field_tests_r1884(test_started_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_field_test_observations_r1884 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id uuid NOT NULL REFERENCES public.engineer_equipment_field_tests_r1884(id) ON DELETE CASCADE,
  observation_type text NOT NULL CHECK (observation_type IN ('positive','concern','critical','feature_gap')),
  observation_text text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_field_test_obs_r1884_test
  ON public.engineer_field_test_observations_r1884(test_id);
CREATE INDEX IF NOT EXISTS idx_field_test_obs_r1884_type
  ON public.engineer_field_test_observations_r1884(observation_type);
CREATE INDEX IF NOT EXISTS idx_field_test_obs_r1884_recorded
  ON public.engineer_field_test_observations_r1884(recorded_at DESC);

ALTER TABLE public.engineer_equipment_field_tests_r1884 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_field_test_observations_r1884 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_field_tests_r1884 ON public.engineer_equipment_field_tests_r1884;
CREATE POLICY founder_all_field_tests_r1884 ON public.engineer_equipment_field_tests_r1884
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_field_test_obs_r1884 ON public.engineer_field_test_observations_r1884;
CREATE POLICY founder_all_field_test_obs_r1884 ON public.engineer_field_test_observations_r1884
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPCs
-- =============================================================================

DROP FUNCTION IF EXISTS public.list_field_tests_r1884();
CREATE OR REPLACE FUNCTION public.list_field_tests_r1884()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  equipment_name text,
  manufacturer text,
  test_started_at timestamptz,
  test_duration_days int,
  primary_use_case text,
  performance_score int,
  would_recommend boolean,
  status text,
  observation_count int,
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
  SELECT
    t.id,
    t.engineer_user_id,
    p.email::text AS engineer_email,
    t.equipment_name,
    t.manufacturer,
    t.test_started_at,
    t.test_duration_days,
    t.primary_use_case,
    t.performance_score,
    t.would_recommend,
    t.status,
    (SELECT COUNT(*) FROM public.engineer_field_test_observations_r1884 o WHERE o.test_id = t.id)::int AS observation_count,
    t.created_at
  FROM public.engineer_equipment_field_tests_r1884 t
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  ORDER BY t.test_started_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_field_tests_r1884() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_field_tests_r1884() TO authenticated;

DROP FUNCTION IF EXISTS public.start_field_test_r1884(uuid, text, text, int, text);
CREATE OR REPLACE FUNCTION public.start_field_test_r1884(
  p_engineer_user_id uuid,
  p_equipment_name text,
  p_manufacturer text,
  p_test_duration_days int,
  p_primary_use_case text
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

  INSERT INTO public.engineer_equipment_field_tests_r1884(
    engineer_user_id, equipment_name, manufacturer, test_duration_days, primary_use_case, status
  )
  VALUES (p_engineer_user_id, p_equipment_name, p_manufacturer, p_test_duration_days, p_primary_use_case, 'ongoing')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'start_field_test_r1884',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'equipment_name', p_equipment_name)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.start_field_test_r1884(uuid, text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_field_test_r1884(uuid, text, text, int, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_field_test_observations_r1884(uuid);
CREATE OR REPLACE FUNCTION public.list_field_test_observations_r1884(p_test_id uuid)
RETURNS TABLE (
  id uuid,
  test_id uuid,
  observation_type text,
  observation_text text,
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
  SELECT o.id, o.test_id, o.observation_type, o.observation_text, o.recorded_at
  FROM public.engineer_field_test_observations_r1884 o
  WHERE o.test_id = p_test_id
  ORDER BY o.recorded_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_field_test_observations_r1884(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_field_test_observations_r1884(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_field_test_observation_r1884(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_field_test_observation_r1884(
  p_test_id uuid,
  p_observation_type text,
  p_observation_text text
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

  INSERT INTO public.engineer_field_test_observations_r1884(test_id, observation_type, observation_text)
  VALUES (p_test_id, p_observation_type, p_observation_text)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_field_test_observation_r1884',
    jsonb_build_object('id', v_id, 'test_id', p_test_id, 'observation_type', p_observation_type)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_field_test_observation_r1884(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_field_test_observation_r1884(uuid, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_field_test_passed_r1884(uuid, int, boolean);
CREATE OR REPLACE FUNCTION public.mark_field_test_passed_r1884(
  p_test_id uuid,
  p_performance_score int,
  p_would_recommend boolean
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

  UPDATE public.engineer_equipment_field_tests_r1884
  SET status = 'passed',
      performance_score = p_performance_score,
      would_recommend = p_would_recommend,
      updated_at = now()
  WHERE id = p_test_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_field_test_passed_r1884',
    jsonb_build_object('id', p_test_id, 'performance_score', p_performance_score, 'would_recommend', p_would_recommend)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_field_test_passed_r1884(uuid, int, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_field_test_passed_r1884(uuid, int, boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.top_recommended_field_tests_r1884();
CREATE OR REPLACE FUNCTION public.top_recommended_field_tests_r1884()
RETURNS TABLE (
  id uuid,
  equipment_name text,
  manufacturer text,
  performance_score int,
  would_recommend boolean,
  status text,
  engineer_email text,
  test_started_at timestamptz
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
    t.id,
    t.equipment_name,
    t.manufacturer,
    t.performance_score,
    t.would_recommend,
    t.status,
    p.email::text AS engineer_email,
    t.test_started_at
  FROM public.engineer_equipment_field_tests_r1884 t
  LEFT JOIN public.profiles p ON p.id = t.engineer_user_id
  WHERE t.status = 'passed' AND t.would_recommend = true
  ORDER BY t.performance_score DESC NULLS LAST, t.test_started_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_recommended_field_tests_r1884() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_recommended_field_tests_r1884() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_field_test_observations_r1884();
CREATE OR REPLACE FUNCTION public.recent_field_test_observations_r1884()
RETURNS TABLE (
  id uuid,
  test_id uuid,
  equipment_name text,
  observation_type text,
  observation_text text,
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
  SELECT
    o.id,
    o.test_id,
    t.equipment_name,
    o.observation_type,
    o.observation_text,
    o.recorded_at
  FROM public.engineer_field_test_observations_r1884 o
  JOIN public.engineer_equipment_field_tests_r1884 t ON t.id = o.test_id
  ORDER BY o.recorded_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_field_test_observations_r1884() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_field_test_observations_r1884() TO authenticated;

COMMIT;