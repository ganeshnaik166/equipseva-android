BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_renewal_forecasts_r2011 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  renewal_due_date date NOT NULL,
  predicted_renewal_value_rupees bigint NOT NULL DEFAULT 0,
  actual_renewal_value_rupees bigint,
  renewal_probability_pct numeric(5,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','actualized','walked_away','superseded')),
  forecasted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcrf_r2011_hospital ON public.hospital_customer_renewal_forecasts_r2011(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hcrf_r2011_due_date ON public.hospital_customer_renewal_forecasts_r2011(renewal_due_date);
CREATE INDEX IF NOT EXISTS idx_hcrf_r2011_status ON public.hospital_customer_renewal_forecasts_r2011(status);

CREATE TABLE IF NOT EXISTS public.hospital_renewal_forecast_action_log_r2011 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_customer_renewal_forecasts_r2011(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement_call','quote_sent','won','lost','follow_up')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrfal_r2011_forecast ON public.hospital_renewal_forecast_action_log_r2011(forecast_id);
CREATE INDEX IF NOT EXISTS idx_hrfal_r2011_taken_at ON public.hospital_renewal_forecast_action_log_r2011(taken_at DESC);

ALTER TABLE public.hospital_customer_renewal_forecasts_r2011 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_renewal_forecast_action_log_r2011 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hcrf_r2011_founder_all ON public.hospital_customer_renewal_forecasts_r2011;
CREATE POLICY hcrf_r2011_founder_all ON public.hospital_customer_renewal_forecasts_r2011
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hrfal_r2011_founder_all ON public.hospital_renewal_forecast_action_log_r2011;
CREATE POLICY hrfal_r2011_founder_all ON public.hospital_renewal_forecast_action_log_r2011
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_forecasts
CREATE OR REPLACE FUNCTION public.list_hospital_renewal_forecasts_r2011()
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_name text,
  renewal_due_date date,
  predicted_renewal_value_rupees bigint,
  actual_renewal_value_rupees bigint,
  renewal_probability_pct numeric,
  status text,
  forecasted_at timestamptz
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
    SELECT f.id, f.hospital_id, p.full_name, f.renewal_due_date,
           f.predicted_renewal_value_rupees, f.actual_renewal_value_rupees,
           f.renewal_probability_pct, f.status, f.forecasted_at
      FROM public.hospital_customer_renewal_forecasts_r2011 f
      LEFT JOIN public.profiles p ON p.id = f.hospital_id
      ORDER BY f.renewal_due_date ASC NULLS LAST
      LIMIT 200;
END;
$$;

-- RPC 2: log_forecast
CREATE OR REPLACE FUNCTION public.log_hospital_renewal_forecast_r2011(
  p_hospital_id uuid,
  p_renewal_due_date date,
  p_predicted_value bigint,
  p_probability_pct numeric
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
  INSERT INTO public.hospital_customer_renewal_forecasts_r2011(
    hospital_id, renewal_due_date, predicted_renewal_value_rupees, renewal_probability_pct
  ) VALUES (p_hospital_id, p_renewal_due_date, p_predicted_value, p_probability_pct)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_hospital_renewal_forecast_r2011',
    jsonb_build_object('forecast_id', v_id, 'hospital_id', p_hospital_id, 'predicted', p_predicted_value)
  );
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_renewal_forecast_actions_r2011(p_forecast_id uuid)
RETURNS TABLE(
  id uuid,
  forecast_id uuid,
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
    SELECT a.id, a.forecast_id, a.action_type, a.taken_at, a.by_email, a.notes_md
      FROM public.hospital_renewal_forecast_action_log_r2011 a
      WHERE a.forecast_id = p_forecast_id
      ORDER BY a.taken_at DESC
      LIMIT 200;
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_renewal_forecast_action_r2011(
  p_forecast_id uuid,
  p_action_type text,
  p_notes_md text
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
  INSERT INTO public.hospital_renewal_forecast_action_log_r2011(
    forecast_id, action_type, by_email, notes_md
  ) VALUES (p_forecast_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_renewal_forecast_action_r2011',
    jsonb_build_object('action_id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type)
  );
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_renewal_forecast_status_r2011(
  p_forecast_id uuid,
  p_status text,
  p_actual_value bigint
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
  UPDATE public.hospital_customer_renewal_forecasts_r2011
     SET status = p_status,
         actual_renewal_value_rupees = COALESCE(p_actual_value, actual_renewal_value_rupees),
         updated_at = now()
   WHERE id = p_forecast_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_renewal_forecast_status_r2011',
    jsonb_build_object('forecast_id', p_forecast_id, 'status', p_status, 'actual', p_actual_value)
  );
END;
$$;

-- RPC 6: high_value_forecasts
CREATE OR REPLACE FUNCTION public.high_value_renewal_forecasts_r2011()
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_name text,
  renewal_due_date date,
  predicted_renewal_value_rupees bigint,
  renewal_probability_pct numeric,
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
    SELECT f.id, f.hospital_id, p.full_name, f.renewal_due_date,
           f.predicted_renewal_value_rupees, f.renewal_probability_pct, f.status
      FROM public.hospital_customer_renewal_forecasts_r2011 f
      LEFT JOIN public.profiles p ON p.id = f.hospital_id
      WHERE f.predicted_renewal_value_rupees >= 100000
        AND f.status = 'forecast'
      ORDER BY f.predicted_renewal_value_rupees DESC
      LIMIT 100;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_renewal_forecast_actions_r2011()
RETURNS TABLE(
  id uuid,
  forecast_id uuid,
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
    SELECT a.id, a.forecast_id, a.action_type, a.taken_at, a.by_email, a.notes_md
      FROM public.hospital_renewal_forecast_action_log_r2011 a
      ORDER BY a.taken_at DESC
      LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_hospital_renewal_forecasts_r2011() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_hospital_renewal_forecast_r2011(uuid, date, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_renewal_forecast_actions_r2011(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_renewal_forecast_action_r2011(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_renewal_forecast_status_r2011(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_value_renewal_forecasts_r2011() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_renewal_forecast_actions_r2011() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_renewal_forecasts_r2011() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hospital_renewal_forecast_r2011(uuid, date, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_renewal_forecast_actions_r2011(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_renewal_forecast_action_r2011(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_renewal_forecast_status_r2011(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_value_renewal_forecasts_r2011() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_renewal_forecast_actions_r2011() TO authenticated;

COMMIT;
