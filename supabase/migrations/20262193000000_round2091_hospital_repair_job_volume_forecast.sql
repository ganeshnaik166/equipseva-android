BEGIN;

-- ============================================================================
-- Round 2091: Hospital Repair Job Volume Forecast
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_repair_job_volume_forecast_r2091 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  forecast_period_label text NOT NULL,
  predicted_jobs int NOT NULL DEFAULT 0,
  actual_jobs int NOT NULL DEFAULT 0,
  accuracy_pct numeric(6,2),
  status text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','actualized','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrjvf_r2091_hospital ON public.hospital_repair_job_volume_forecast_r2091(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hrjvf_r2091_status ON public.hospital_repair_job_volume_forecast_r2091(status);
CREATE INDEX IF NOT EXISTS idx_hrjvf_r2091_captured ON public.hospital_repair_job_volume_forecast_r2091(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_volume_action_log_r2091 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_repair_job_volume_forecast_r2091(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engineer_pre_assigned','capacity_adjusted','escalated','actualized','superseded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hval_r2091_forecast ON public.hospital_volume_action_log_r2091(forecast_id);
CREATE INDEX IF NOT EXISTS idx_hval_r2091_taken ON public.hospital_volume_action_log_r2091(taken_at DESC);

ALTER TABLE public.hospital_repair_job_volume_forecast_r2091 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_volume_action_log_r2091 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hrjvf_r2091_founder_all ON public.hospital_repair_job_volume_forecast_r2091;
CREATE POLICY hrjvf_r2091_founder_all ON public.hospital_repair_job_volume_forecast_r2091
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hval_r2091_founder_all ON public.hospital_volume_action_log_r2091;
CREATE POLICY hval_r2091_founder_all ON public.hospital_volume_action_log_r2091
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_forecasts
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_forecasts_r2091();
CREATE OR REPLACE FUNCTION public.list_forecasts_r2091()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  forecast_period_label text,
  predicted_jobs int,
  actual_jobs int,
  accuracy_pct numeric,
  status text,
  captured_at timestamptz
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
  SELECT f.id, f.hospital_id, p.email, f.forecast_period_label, f.predicted_jobs,
         f.actual_jobs, f.accuracy_pct, f.status, f.captured_at
  FROM public.hospital_repair_job_volume_forecast_r2091 f
  LEFT JOIN public.profiles p ON p.id = f.hospital_id
  ORDER BY f.captured_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_forecast
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_forecast_r2091(uuid, text, int, int, numeric);
CREATE OR REPLACE FUNCTION public.log_forecast_r2091(
  p_hospital_id uuid,
  p_period text,
  p_predicted int,
  p_actual int,
  p_accuracy numeric
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
  INSERT INTO public.hospital_repair_job_volume_forecast_r2091
    (hospital_id, forecast_period_label, predicted_jobs, actual_jobs, accuracy_pct)
  VALUES (p_hospital_id, p_period, p_predicted, p_actual, p_accuracy)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_forecast_r2091',
          jsonb_build_object('forecast_id', v_id, 'hospital_id', p_hospital_id, 'period', p_period));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_actions_r2091();
CREATE OR REPLACE FUNCTION public.list_actions_r2091()
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  forecast_period text,
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
  SELECT a.id, a.forecast_id, f.forecast_period_label, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_volume_action_log_r2091 a
  LEFT JOIN public.hospital_repair_job_volume_forecast_r2091 f ON f.id = a.forecast_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_action_r2091(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2091(
  p_forecast_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes text
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
  INSERT INTO public.hospital_volume_action_log_r2091
    (forecast_id, action_type, by_email, notes_md)
  VALUES (p_forecast_id, p_action_type, p_by_email, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2091',
          jsonb_build_object('action_id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_status_r2091(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2091(
  p_forecast_id uuid,
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
  IF p_status NOT IN ('forecast','actualized','superseded') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.hospital_repair_job_volume_forecast_r2091
  SET status = p_status, updated_at = now()
  WHERE id = p_forecast_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2091',
          jsonb_build_object('forecast_id', p_forecast_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: accurate_forecasts
-- ============================================================================
DROP FUNCTION IF EXISTS public.accurate_forecasts_r2091();
CREATE OR REPLACE FUNCTION public.accurate_forecasts_r2091()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  forecast_period_label text,
  predicted_jobs int,
  actual_jobs int,
  accuracy_pct numeric,
  captured_at timestamptz
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
  SELECT f.id, f.hospital_id, p.email, f.forecast_period_label, f.predicted_jobs,
         f.actual_jobs, f.accuracy_pct, f.captured_at
  FROM public.hospital_repair_job_volume_forecast_r2091 f
  LEFT JOIN public.profiles p ON p.id = f.hospital_id
  WHERE f.status = 'actualized' AND f.accuracy_pct IS NOT NULL AND f.accuracy_pct >= 80
  ORDER BY f.accuracy_pct DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_actions_r2091();
CREATE OR REPLACE FUNCTION public.recent_actions_r2091()
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  forecast_period text,
  action_type text,
  taken_at timestamptz,
  by_email text
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
  SELECT a.id, a.forecast_id, f.forecast_period_label, a.action_type, a.taken_at, a.by_email
  FROM public.hospital_volume_action_log_r2091 a
  LEFT JOIN public.hospital_repair_job_volume_forecast_r2091 f ON f.id = a.forecast_id
  WHERE a.taken_at > now() - interval '30 days'
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_forecasts_r2091() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_forecasts_r2091() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_forecast_r2091(uuid, text, int, int, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_forecast_r2091(uuid, text, int, int, numeric) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2091() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2091() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_action_r2091(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2091(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2091(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2091(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.accurate_forecasts_r2091() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accurate_forecasts_r2091() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2091() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2091() TO authenticated;

COMMIT;
