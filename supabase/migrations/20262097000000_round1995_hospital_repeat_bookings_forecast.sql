BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_repeat_bookings_forecast_r1995 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  forecast_month text NOT NULL,
  predicted_repeat_count int NOT NULL DEFAULT 0,
  predicted_revenue_rupees bigint NOT NULL DEFAULT 0,
  actual_repeat_count int,
  accuracy_pct numeric(6,2),
  status text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','actualized','superseded')),
  generated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_repeat_forecast_action_log_r1995 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_repeat_bookings_forecast_r1995(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement_call','upgrade_offered','no_action','escalated','recovered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_repeat_bookings_forecast_r1995 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_repeat_forecast_action_log_r1995 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_forecast_r1995 ON public.hospital_repeat_bookings_forecast_r1995;
CREATE POLICY p_founder_forecast_r1995 ON public.hospital_repeat_bookings_forecast_r1995
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_action_log_r1995 ON public.hospital_repeat_forecast_action_log_r1995;
CREATE POLICY p_founder_action_log_r1995 ON public.hospital_repeat_forecast_action_log_r1995
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_forecasts_r1995()
RETURNS SETOF public.hospital_repeat_bookings_forecast_r1995
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repeat_bookings_forecast_r1995 ORDER BY generated_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_forecast_r1995(
  p_hospital_id uuid,
  p_forecast_month text,
  p_predicted_repeat_count int,
  p_predicted_revenue_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_repeat_bookings_forecast_r1995(hospital_id, forecast_month, predicted_repeat_count, predicted_revenue_rupees)
  VALUES (p_hospital_id, p_forecast_month, p_predicted_repeat_count, p_predicted_revenue_rupees)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_forecast_r1995', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'forecast_month', p_forecast_month));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1995(p_forecast_id uuid)
RETURNS SETOF public.hospital_repeat_forecast_action_log_r1995
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repeat_forecast_action_log_r1995 WHERE forecast_id = p_forecast_id ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1995(
  p_forecast_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_repeat_forecast_action_log_r1995(forecast_id, action_type, by_email, notes_md)
  VALUES (p_forecast_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1995', jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1995(
  p_forecast_id uuid,
  p_status text,
  p_actual_count int,
  p_accuracy_pct numeric
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_repeat_bookings_forecast_r1995
    SET status = p_status,
        actual_repeat_count = COALESCE(p_actual_count, actual_repeat_count),
        accuracy_pct = COALESCE(p_accuracy_pct, accuracy_pct),
        updated_at = now()
    WHERE id = p_forecast_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1995', jsonb_build_object('forecast_id', p_forecast_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.accurate_forecasts_r1995()
RETURNS SETOF public.hospital_repeat_bookings_forecast_r1995
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repeat_bookings_forecast_r1995
    WHERE status = 'actualized' AND accuracy_pct IS NOT NULL AND accuracy_pct >= 80
    ORDER BY accuracy_pct DESC LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1995()
RETURNS SETOF public.hospital_repeat_forecast_action_log_r1995
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_repeat_forecast_action_log_r1995 ORDER BY taken_at DESC LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_forecasts_r1995() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_forecast_r1995(uuid, text, int, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1995(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1995(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1995(uuid, text, int, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.accurate_forecasts_r1995() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1995() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_forecasts_r1995() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_forecast_r1995(uuid, text, int, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1995(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1995(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1995(uuid, text, int, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accurate_forecasts_r1995() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1995() TO authenticated;

COMMIT;
