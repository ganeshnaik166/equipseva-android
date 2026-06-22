BEGIN;

-- =========================================================================
-- Round 1899: Hospital Service Window Forecast
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_window_forecast_r1899 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_week_start date NOT NULL,
  predicted_jobs int NOT NULL DEFAULT 0,
  predicted_engineer_hours int NOT NULL DEFAULT 0,
  capacity_engineers int NOT NULL DEFAULT 0,
  capacity_utilization_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','actualized')),
  generated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_window_capacity_actions_r1899 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_service_window_forecast_r1899(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('hire_temp','shift_engineer','decline_jobs','escalate')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsw_forecast_r1899_week ON public.hospital_service_window_forecast_r1899(forecast_week_start);
CREATE INDEX IF NOT EXISTS idx_hsw_actions_r1899_forecast ON public.hospital_window_capacity_actions_r1899(forecast_id);

ALTER TABLE public.hospital_service_window_forecast_r1899 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_window_capacity_actions_r1899 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsw_forecast_r1899_founder ON public.hospital_service_window_forecast_r1899;
CREATE POLICY hsw_forecast_r1899_founder ON public.hospital_service_window_forecast_r1899
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hsw_actions_r1899_founder ON public.hospital_window_capacity_actions_r1899;
CREATE POLICY hsw_actions_r1899_founder ON public.hospital_window_capacity_actions_r1899
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_forecasts
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_forecasts_r1899()
RETURNS TABLE (
  id uuid,
  forecast_week_start date,
  predicted_jobs int,
  predicted_engineer_hours int,
  capacity_engineers int,
  capacity_utilization_pct numeric,
  status text,
  generated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.forecast_week_start, f.predicted_jobs, f.predicted_engineer_hours,
         f.capacity_engineers, f.capacity_utilization_pct, f.status, f.generated_at
    FROM public.hospital_service_window_forecast_r1899 f
   ORDER BY f.forecast_week_start ASC
   LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_forecasts_r1899() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_forecasts_r1899() TO authenticated;

-- =========================================================================
-- RPC 2: generate_forecast
-- =========================================================================
CREATE OR REPLACE FUNCTION public.generate_forecast_r1899(
  p_week_start date,
  p_predicted_jobs int,
  p_predicted_engineer_hours int,
  p_capacity_engineers int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_util numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_util := CASE WHEN p_capacity_engineers > 0
                 THEN (p_predicted_engineer_hours::numeric / (p_capacity_engineers * 40)::numeric) * 100
                 ELSE 0 END;
  INSERT INTO public.hospital_service_window_forecast_r1899(
    forecast_week_start, predicted_jobs, predicted_engineer_hours,
    capacity_engineers, capacity_utilization_pct, status
  ) VALUES (
    p_week_start, p_predicted_jobs, p_predicted_engineer_hours,
    p_capacity_engineers, v_util, 'forecast'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'generate_forecast_r1899',
          jsonb_build_object('id', v_id, 'week_start', p_week_start, 'util_pct', v_util), now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.generate_forecast_r1899(date,int,int,int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_forecast_r1899(date,int,int,int) TO authenticated;

-- =========================================================================
-- RPC 3: list_actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1899(p_forecast_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.forecast_id, a.action_type, a.taken_at, a.by_email
    FROM public.hospital_window_capacity_actions_r1899 a
   WHERE p_forecast_id IS NULL OR a.forecast_id = p_forecast_id
   ORDER BY a.taken_at DESC
   LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1899(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r1899(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: log_action
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1899(
  p_forecast_id uuid,
  p_action_type text
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_window_capacity_actions_r1899(forecast_id, action_type, by_email)
  VALUES (p_forecast_id, p_action_type, v_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), v_email, 'log_action_r1899',
          jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type), now());
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r1899(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r1899(uuid,text) TO authenticated;

-- =========================================================================
-- RPC 5: mark_actualized
-- =========================================================================
CREATE OR REPLACE FUNCTION public.mark_actualized_r1899(p_forecast_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_window_forecast_r1899
     SET status = 'actualized', updated_at = now()
   WHERE id = p_forecast_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_actualized_r1899',
          jsonb_build_object('forecast_id', p_forecast_id), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_actualized_r1899(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_actualized_r1899(uuid) TO authenticated;

-- =========================================================================
-- RPC 6: peak_demand_weeks
-- =========================================================================
CREATE OR REPLACE FUNCTION public.peak_demand_weeks_r1899()
RETURNS TABLE (
  forecast_week_start date,
  predicted_jobs int,
  capacity_utilization_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.forecast_week_start, f.predicted_jobs, f.capacity_utilization_pct
    FROM public.hospital_service_window_forecast_r1899 f
   WHERE f.status = 'forecast'
   ORDER BY f.capacity_utilization_pct DESC, f.predicted_jobs DESC
   LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.peak_demand_weeks_r1899() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.peak_demand_weeks_r1899() TO authenticated;

-- =========================================================================
-- RPC 7: recent_capacity_actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.recent_capacity_actions_r1899()
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  forecast_week_start date,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.forecast_id, f.forecast_week_start, a.action_type, a.taken_at, a.by_email
    FROM public.hospital_window_capacity_actions_r1899 a
    JOIN public.hospital_service_window_forecast_r1899 f ON f.id = a.forecast_id
   ORDER BY a.taken_at DESC
   LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_capacity_actions_r1899() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_capacity_actions_r1899() TO authenticated;

COMMIT;
