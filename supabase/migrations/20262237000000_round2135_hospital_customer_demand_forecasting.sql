BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_demand_forecasting_r2135 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quarter_label text NOT NULL,
  predicted_demand_jobs int NOT NULL DEFAULT 0,
  actual_demand_jobs int NOT NULL DEFAULT 0,
  forecast_error_pct numeric(8,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','actualized','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_demand_action_log_r2135 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_customer_demand_forecasting_r2135(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engineer_added','capacity_adjusted','escalated','actualized')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_demand_forecasting_r2135 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_demand_action_log_r2135 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_forecasts_r2135 ON public.hospital_customer_demand_forecasting_r2135;
CREATE POLICY founder_all_forecasts_r2135 ON public.hospital_customer_demand_forecasting_r2135
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2135 ON public.hospital_demand_action_log_r2135;
CREATE POLICY founder_all_actions_r2135 ON public.hospital_demand_action_log_r2135
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_forecasts_r2135()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  quarter_label text,
  predicted_demand_jobs int,
  actual_demand_jobs int,
  forecast_error_pct numeric,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_id, f.quarter_label, f.predicted_demand_jobs,
           f.actual_demand_jobs, f.forecast_error_pct, f.status, f.captured_at
      FROM public.hospital_customer_demand_forecasting_r2135 f
      ORDER BY f.captured_at DESC
      LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_forecast_r2135(
  p_hospital_id uuid,
  p_quarter_label text,
  p_predicted int,
  p_actual int,
  p_error_pct numeric,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_demand_forecasting_r2135(
    hospital_id, quarter_label, predicted_demand_jobs, actual_demand_jobs,
    forecast_error_pct, status
  ) VALUES (p_hospital_id, p_quarter_label, p_predicted, p_actual, p_error_pct, COALESCE(p_status,'forecast'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_forecast_r2135',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'quarter', p_quarter_label));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2135(p_forecast_id uuid)
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.forecast_id, a.action_type, a.taken_at, a.by_email, a.notes_md
      FROM public.hospital_demand_action_log_r2135 a
     WHERE a.forecast_id = p_forecast_id
     ORDER BY a.taken_at DESC
     LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2135(
  p_forecast_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_demand_action_log_r2135(forecast_id, action_type, by_email, notes_md)
  VALUES (p_forecast_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2135',
    jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2135(p_forecast_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_demand_forecasting_r2135
     SET status = p_status, updated_at = now()
   WHERE id = p_forecast_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2135',
    jsonb_build_object('id', p_forecast_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.accurate_forecasts_r2135()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  quarter_label text,
  predicted_demand_jobs int,
  actual_demand_jobs int,
  forecast_error_pct numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.hospital_id, f.quarter_label, f.predicted_demand_jobs,
           f.actual_demand_jobs, f.forecast_error_pct, f.captured_at
      FROM public.hospital_customer_demand_forecasting_r2135 f
     WHERE f.status = 'actualized' AND f.forecast_error_pct <= 10
     ORDER BY f.forecast_error_pct ASC
     LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2135()
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.forecast_id, a.action_type, a.taken_at, a.by_email, a.notes_md
      FROM public.hospital_demand_action_log_r2135 a
     ORDER BY a.taken_at DESC
     LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_forecasts_r2135() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_forecast_r2135(uuid, text, int, int, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2135(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2135(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2135(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.accurate_forecasts_r2135() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2135() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_forecasts_r2135() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_forecast_r2135(uuid, text, int, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2135(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2135(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2135(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accurate_forecasts_r2135() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2135() TO authenticated;

COMMIT;
