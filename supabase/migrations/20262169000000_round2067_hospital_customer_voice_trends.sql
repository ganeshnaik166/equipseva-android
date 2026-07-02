BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_voice_trends_r2067 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trend_label text NOT NULL,
  trend_category text NOT NULL CHECK (trend_category IN ('service_quality','pricing','engineer_quality','billing','feature_request','competitive')),
  signal_count int NOT NULL DEFAULT 0,
  sentiment_avg numeric(4,2),
  status text NOT NULL DEFAULT 'emerging' CHECK (status IN ('emerging','persistent','declining','resolved')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_voice_trend_action_log_r2067 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trend_id uuid NOT NULL REFERENCES public.hospital_customer_voice_trends_r2067(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('addressed','feature_request_logged','escalation','closed','superseded')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_voice_trends_r2067 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_voice_trend_action_log_r2067 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_trends_r2067 ON public.hospital_customer_voice_trends_r2067;
CREATE POLICY founder_all_trends_r2067 ON public.hospital_customer_voice_trends_r2067
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2067 ON public.hospital_voice_trend_action_log_r2067;
CREATE POLICY founder_all_actions_r2067 ON public.hospital_voice_trend_action_log_r2067
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_trends_r2067()
RETURNS SETOF public.hospital_customer_voice_trends_r2067
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_voice_trends_r2067 ORDER BY captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_trend_r2067(
  p_label text, p_category text, p_signal_count int, p_sentiment numeric, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_voice_trends_r2067(trend_label, trend_category, signal_count, sentiment_avg, status)
  VALUES (p_label, p_category, COALESCE(p_signal_count,0), p_sentiment, COALESCE(p_status,'emerging'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_trend_r2067', jsonb_build_object('id', v_id, 'label', p_label, 'category', p_category));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2067(p_trend uuid)
RETURNS SETOF public.hospital_voice_trend_action_log_r2067
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_voice_trend_action_log_r2067 WHERE trend_id = p_trend ORDER BY taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2067(
  p_trend uuid, p_action_type text, p_by_email text, p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_voice_trend_action_log_r2067(trend_id, action_type, by_email, notes_md)
  VALUES (p_trend, p_action_type, p_by_email, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2067', jsonb_build_object('id', v_id, 'trend', p_trend, 'action', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2067(p_trend uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_voice_trends_r2067 SET status = p_status, updated_at = now() WHERE id = p_trend;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2067', jsonb_build_object('trend', p_trend, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.persistent_trends_r2067()
RETURNS SETOF public.hospital_customer_voice_trends_r2067
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_voice_trends_r2067 WHERE status = 'persistent' ORDER BY signal_count DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2067()
RETURNS SETOF public.hospital_voice_trend_action_log_r2067
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_voice_trend_action_log_r2067 ORDER BY taken_at DESC LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_trends_r2067() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_trend_r2067(text, text, int, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2067(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2067(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2067(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.persistent_trends_r2067() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2067() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_trends_r2067() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_trend_r2067(text, text, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2067(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2067(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2067(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.persistent_trends_r2067() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2067() TO authenticated;

COMMIT;
