BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_field_safety_drills_r1876 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drill_type text NOT NULL CHECK (drill_type IN ('electrical','biohazard','fire','equipment_fall','lifting')),
  drill_date date NOT NULL,
  drill_location text NOT NULL,
  attendee_user_ids uuid[] NOT NULL DEFAULT '{}',
  passed boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','conducted','cancelled')),
  conducted_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_field_safety_drill_observations_r1876 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drill_id uuid NOT NULL REFERENCES public.engineer_field_safety_drills_r1876(id) ON DELETE CASCADE,
  observation_text text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('critical','serious','observation')),
  action_required text,
  action_owner_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.engineer_field_safety_drills_r1876 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_field_safety_drill_observations_r1876 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_drills_r1876 ON public.engineer_field_safety_drills_r1876;
CREATE POLICY founder_all_drills_r1876 ON public.engineer_field_safety_drills_r1876
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_drill_obs_r1876 ON public.engineer_field_safety_drill_observations_r1876;
CREATE POLICY founder_all_drill_obs_r1876 ON public.engineer_field_safety_drill_observations_r1876
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list drills
CREATE OR REPLACE FUNCTION public.list_field_safety_drills_r1876()
RETURNS TABLE (
  id uuid,
  drill_type text,
  drill_date date,
  drill_location text,
  attendee_count int,
  passed boolean,
  status text,
  conducted_by_email text,
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
  SELECT d.id, d.drill_type, d.drill_date, d.drill_location,
         COALESCE(array_length(d.attendee_user_ids, 1), 0)::int AS attendee_count,
         d.passed, d.status, d.conducted_by_email, d.created_at
  FROM public.engineer_field_safety_drills_r1876 d
  ORDER BY d.drill_date DESC, d.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: plan drill
CREATE OR REPLACE FUNCTION public.plan_field_safety_drill_r1876(
  p_drill_type text,
  p_drill_date date,
  p_drill_location text,
  p_attendee_user_ids uuid[],
  p_conducted_by_email text
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
  INSERT INTO public.engineer_field_safety_drills_r1876
    (drill_type, drill_date, drill_location, attendee_user_ids, conducted_by_email, status)
  VALUES (p_drill_type, p_drill_date, p_drill_location,
          COALESCE(p_attendee_user_ids, '{}'::uuid[]), p_conducted_by_email, 'planned')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'plan_field_safety_drill_r1876',
          jsonb_build_object('drill_id', v_id, 'drill_type', p_drill_type, 'drill_date', p_drill_date));

  RETURN v_id;
END;
$$;

-- RPC 3: list observations
CREATE OR REPLACE FUNCTION public.list_field_safety_drill_observations_r1876(p_drill_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  drill_id uuid,
  observation_text text,
  severity text,
  action_required text,
  action_owner_email text,
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
  SELECT o.id, o.drill_id, o.observation_text, o.severity,
         o.action_required, o.action_owner_email, o.created_at
  FROM public.engineer_field_safety_drill_observations_r1876 o
  WHERE p_drill_id IS NULL OR o.drill_id = p_drill_id
  ORDER BY
    CASE o.severity WHEN 'critical' THEN 1 WHEN 'serious' THEN 2 ELSE 3 END,
    o.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: log observation
CREATE OR REPLACE FUNCTION public.log_field_safety_drill_observation_r1876(
  p_drill_id uuid,
  p_observation_text text,
  p_severity text,
  p_action_required text,
  p_action_owner_email text
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
  INSERT INTO public.engineer_field_safety_drill_observations_r1876
    (drill_id, observation_text, severity, action_required, action_owner_email)
  VALUES (p_drill_id, p_observation_text, p_severity, p_action_required, p_action_owner_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_field_safety_drill_observation_r1876',
          jsonb_build_object('observation_id', v_id, 'drill_id', p_drill_id, 'severity', p_severity));

  RETURN v_id;
END;
$$;

-- RPC 5: mark passed
CREATE OR REPLACE FUNCTION public.mark_field_safety_drill_passed_r1876(
  p_drill_id uuid,
  p_passed boolean
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
  UPDATE public.engineer_field_safety_drills_r1876
  SET passed = p_passed,
      status = 'conducted',
      updated_at = now()
  WHERE id = p_drill_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_field_safety_drill_passed_r1876',
          jsonb_build_object('drill_id', p_drill_id, 'passed', p_passed));
END;
$$;

-- RPC 6: pass rate
CREATE OR REPLACE FUNCTION public.field_safety_drill_pass_rate_r1876()
RETURNS TABLE (
  drill_type text,
  total_conducted int,
  total_passed int,
  pass_rate_pct numeric
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
  SELECT d.drill_type,
         (COUNT(*) FILTER (WHERE d.status = 'conducted'))::int AS total_conducted,
         (COUNT(*) FILTER (WHERE d.status = 'conducted' AND d.passed))::int AS total_passed,
         ROUND(
           100.0 * (COUNT(*) FILTER (WHERE d.status = 'conducted' AND d.passed))::numeric
           / NULLIF((COUNT(*) FILTER (WHERE d.status = 'conducted'))::numeric, 0),
           1
         ) AS pass_rate_pct
  FROM public.engineer_field_safety_drills_r1876 d
  GROUP BY d.drill_type
  ORDER BY d.drill_type;
END;
$$;

-- RPC 7: recent critical observations
CREATE OR REPLACE FUNCTION public.recent_critical_field_safety_observations_r1876()
RETURNS TABLE (
  id uuid,
  drill_id uuid,
  drill_type text,
  drill_location text,
  observation_text text,
  severity text,
  action_required text,
  action_owner_email text,
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
  SELECT o.id, o.drill_id, d.drill_type, d.drill_location,
         o.observation_text, o.severity, o.action_required, o.action_owner_email, o.created_at
  FROM public.engineer_field_safety_drill_observations_r1876 o
  JOIN public.engineer_field_safety_drills_r1876 d ON d.id = o.drill_id
  WHERE o.severity IN ('critical','serious')
    AND o.created_at >= now() - interval '90 days'
  ORDER BY
    CASE o.severity WHEN 'critical' THEN 1 ELSE 2 END,
    o.created_at DESC
  LIMIT 100;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_field_safety_drills_r1876() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_field_safety_drills_r1876() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.plan_field_safety_drill_r1876(text, date, text, uuid[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plan_field_safety_drill_r1876(text, date, text, uuid[], text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_field_safety_drill_observations_r1876(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_field_safety_drill_observations_r1876(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_field_safety_drill_observation_r1876(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_field_safety_drill_observation_r1876(uuid, text, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_field_safety_drill_passed_r1876(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_field_safety_drill_passed_r1876(uuid, boolean) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.field_safety_drill_pass_rate_r1876() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.field_safety_drill_pass_rate_r1876() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_critical_field_safety_observations_r1876() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_critical_field_safety_observations_r1876() TO authenticated;

COMMIT;