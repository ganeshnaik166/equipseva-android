BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_health_trend_r2131 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_label text NOT NULL,
  health_index_score integer NOT NULL CHECK (health_index_score BETWEEN 0 AND 100),
  trend_direction text NOT NULL CHECK (trend_direction IN ('rising','stable','declining','sharp_drop')),
  status text NOT NULL CHECK (status IN ('thriving','healthy','at_risk','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_health_trend_action_log_r2131 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trend_id uuid NOT NULL REFERENCES public.hospital_customer_health_trend_r2131(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('escalation','win_back','closed','recovered','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_health_trend_r2131 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_health_trend_action_log_r2131 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hcht_r2131 ON public.hospital_customer_health_trend_r2131;
CREATE POLICY founder_all_hcht_r2131 ON public.hospital_customer_health_trend_r2131
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hhtal_r2131 ON public.hospital_health_trend_action_log_r2131;
CREATE POLICY founder_all_hhtal_r2131 ON public.hospital_health_trend_action_log_r2131
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_trends
CREATE OR REPLACE FUNCTION public.list_trends_r2131()
RETURNS SETOF public.hospital_customer_health_trend_r2131
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_health_trend_r2131 ORDER BY captured_at DESC;
END;
$$;

-- log_trend
CREATE OR REPLACE FUNCTION public.log_trend_r2131(
  p_hospital_id uuid,
  p_week_label text,
  p_score integer,
  p_direction text,
  p_status text
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
  INSERT INTO public.hospital_customer_health_trend_r2131(hospital_id, week_label, health_index_score, trend_direction, status)
  VALUES (p_hospital_id, p_week_label, p_score, p_direction, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_trend_r2131',
    jsonb_build_object('trend_id', v_id, 'hospital_id', p_hospital_id, 'score', p_score, 'direction', p_direction, 'status', p_status));

  RETURN v_id;
END;
$$;

-- list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2131(p_trend_id uuid)
RETURNS SETOF public.hospital_health_trend_action_log_r2131
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_health_trend_action_log_r2131
    WHERE trend_id = p_trend_id ORDER BY taken_at DESC;
END;
$$;

-- log_action
CREATE OR REPLACE FUNCTION public.log_action_r2131(
  p_trend_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.hospital_health_trend_action_log_r2131(trend_id, action_type, by_email, notes_md)
  VALUES (p_trend_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2131',
    jsonb_build_object('action_id', v_id, 'trend_id', p_trend_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2131(
  p_trend_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_health_trend_r2131
    SET status = p_status, updated_at = now()
    WHERE id = p_trend_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2131',
    jsonb_build_object('trend_id', p_trend_id, 'status', p_status));
END;
$$;

-- declining
CREATE OR REPLACE FUNCTION public.declining_r2131()
RETURNS SETOF public.hospital_customer_health_trend_r2131
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_health_trend_r2131
    WHERE trend_direction IN ('declining','sharp_drop')
    ORDER BY captured_at DESC;
END;
$$;

-- recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2131()
RETURNS SETOF public.hospital_health_trend_action_log_r2131
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_health_trend_action_log_r2131
    ORDER BY taken_at DESC LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_trends_r2131() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_trend_r2131(uuid, text, integer, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2131(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2131(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2131(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.declining_r2131() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2131() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_trends_r2131() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_trend_r2131(uuid, text, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2131(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2131(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2131(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.declining_r2131() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2131() TO authenticated;

COMMIT;
