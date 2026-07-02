BEGIN;

-- =====================================================
-- Round 1883: Hospital Service Window Optimization
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_window_optimization_r1883 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  time_window text NOT NULL CHECK (time_window IN ('morning','afternoon','evening','night')),
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  jobs_count int NOT NULL DEFAULT 0,
  avg_response_min int NOT NULL DEFAULT 0,
  peak boolean NOT NULL DEFAULT false,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsw_opt_r1883_hospital ON public.hospital_service_window_optimization_r1883(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hsw_opt_r1883_recorded ON public.hospital_service_window_optimization_r1883(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_hsw_opt_r1883_peak ON public.hospital_service_window_optimization_r1883(peak) WHERE peak = true;

CREATE TABLE IF NOT EXISTS public.hospital_service_window_routing_rules_r1883 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  window_id uuid NOT NULL REFERENCES public.hospital_service_window_optimization_r1883(id) ON DELETE CASCADE,
  routing_rule text NOT NULL CHECK (routing_rule IN ('primary_engineer','backup_engineer','escalate','parallel')),
  applied_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsw_rules_r1883_window ON public.hospital_service_window_routing_rules_r1883(window_id);
CREATE INDEX IF NOT EXISTS idx_hsw_rules_r1883_status ON public.hospital_service_window_routing_rules_r1883(status);

ALTER TABLE public.hospital_service_window_optimization_r1883 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_window_routing_rules_r1883 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsw_opt_r1883_founder_all ON public.hospital_service_window_optimization_r1883;
CREATE POLICY hsw_opt_r1883_founder_all ON public.hospital_service_window_optimization_r1883
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hsw_rules_r1883_founder_all ON public.hospital_service_window_routing_rules_r1883;
CREATE POLICY hsw_rules_r1883_founder_all ON public.hospital_service_window_routing_rules_r1883
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =====================================================
-- RPCs
-- =====================================================

-- 1. list_windows
CREATE OR REPLACE FUNCTION public.list_service_windows_r1883(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  time_window text,
  day_of_week int,
  jobs_count int,
  avg_response_min int,
  peak boolean,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_user_id,
         COALESCE(o.name, p.full_name, p.email, 'unknown')::text AS hospital_name,
         w.time_window, w.day_of_week, w.jobs_count, w.avg_response_min, w.peak, w.recorded_at
  FROM public.hospital_service_window_optimization_r1883 w
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY w.recorded_at DESC
  LIMIT p_limit;
END;
$$;

-- 2. refresh_window (write)
CREATE OR REPLACE FUNCTION public.refresh_service_window_r1883(
  p_hospital_user_id uuid,
  p_time_window text,
  p_day_of_week int,
  p_jobs_count int,
  p_avg_response_min int,
  p_peak boolean
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
  INSERT INTO public.hospital_service_window_optimization_r1883
    (hospital_user_id, time_window, day_of_week, jobs_count, avg_response_min, peak)
  VALUES
    (p_hospital_user_id, p_time_window, p_day_of_week, p_jobs_count, p_avg_response_min, p_peak)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'refresh_service_window_r1883',
    jsonb_build_object(
      'window_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'time_window', p_time_window,
      'peak', p_peak
    )
  );
  RETURN v_id;
END;
$$;

-- 3. list_rules
CREATE OR REPLACE FUNCTION public.list_service_window_rules_r1883(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  window_id uuid,
  time_window text,
  day_of_week int,
  routing_rule text,
  applied_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.window_id, w.time_window, w.day_of_week, r.routing_rule, r.applied_at, r.status
  FROM public.hospital_service_window_routing_rules_r1883 r
  JOIN public.hospital_service_window_optimization_r1883 w ON w.id = r.window_id
  ORDER BY r.applied_at DESC
  LIMIT p_limit;
END;
$$;

-- 4. set_rule (write)
CREATE OR REPLACE FUNCTION public.set_service_window_rule_r1883(
  p_window_id uuid,
  p_routing_rule text
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

  UPDATE public.hospital_service_window_routing_rules_r1883
  SET status = 'superseded', updated_at = now()
  WHERE window_id = p_window_id AND status = 'active';

  INSERT INTO public.hospital_service_window_routing_rules_r1883
    (window_id, routing_rule, status)
  VALUES (p_window_id, p_routing_rule, 'active')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'set_service_window_rule_r1883',
    jsonb_build_object('rule_id', v_id, 'window_id', p_window_id, 'routing_rule', p_routing_rule)
  );
  RETURN v_id;
END;
$$;

-- 5. peak_windows_summary
CREATE OR REPLACE FUNCTION public.peak_service_windows_summary_r1883()
RETURNS TABLE (
  time_window text,
  peak_count int,
  total_jobs int,
  avg_response_min numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.time_window,
         (COUNT(*) FILTER (WHERE w.peak = true))::int AS peak_count,
         COALESCE(SUM(w.jobs_count),0)::int AS total_jobs,
         COALESCE(AVG(w.avg_response_min),0)::numeric(10,2) AS avg_response_min
  FROM public.hospital_service_window_optimization_r1883 w
  GROUP BY w.time_window
  ORDER BY peak_count DESC;
END;
$$;

-- 6. top_demand_windows
CREATE OR REPLACE FUNCTION public.top_demand_service_windows_r1883(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  time_window text,
  day_of_week int,
  jobs_count int,
  avg_response_min int,
  peak boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_user_id,
         COALESCE(o.name, p.full_name, p.email, 'unknown')::text,
         w.time_window, w.day_of_week, w.jobs_count, w.avg_response_min, w.peak
  FROM public.hospital_service_window_optimization_r1883 w
  LEFT JOIN public.profiles p ON p.id = w.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY w.jobs_count DESC
  LIMIT p_limit;
END;
$$;

-- 7. recent_rule_changes
CREATE OR REPLACE FUNCTION public.recent_service_window_rule_changes_r1883(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  window_id uuid,
  time_window text,
  day_of_week int,
  routing_rule text,
  status text,
  applied_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.window_id, w.time_window, w.day_of_week, r.routing_rule, r.status, r.applied_at
  FROM public.hospital_service_window_routing_rules_r1883 r
  JOIN public.hospital_service_window_optimization_r1883 w ON w.id = r.window_id
  ORDER BY r.applied_at DESC
  LIMIT p_limit;
END;
$$;

-- =====================================================
-- Grants
-- =====================================================
REVOKE EXECUTE ON FUNCTION public.list_service_windows_r1883(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.refresh_service_window_r1883(uuid, text, int, int, int, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_service_window_rules_r1883(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_service_window_rule_r1883(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.peak_service_windows_summary_r1883() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_demand_service_windows_r1883(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_service_window_rule_changes_r1883(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_service_windows_r1883(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_service_window_r1883(uuid, text, int, int, int, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_service_window_rules_r1883(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_service_window_rule_r1883(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.peak_service_windows_summary_r1883() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_demand_service_windows_r1883(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_service_window_rule_changes_r1883(int) TO authenticated;

COMMIT;