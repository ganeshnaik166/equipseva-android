BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_customer_pulse_weekly_r1754 (
  week_start date PRIMARY KEY,
  total_active_hospitals int NOT NULL DEFAULT 0,
  churned_this_week int NOT NULL DEFAULT 0,
  nps_score numeric(5,2),
  open_critical_tickets int NOT NULL DEFAULT 0,
  repeat_rate_pct numeric(5,2),
  health_index_score int,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_customer_pulse_alerts_r1754 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL REFERENCES public.founder_customer_pulse_weekly_r1754(week_start) ON DELETE CASCADE,
  alert_type text NOT NULL CHECK (alert_type IN ('churn_spike','nps_drop','ticket_surge','repeat_decline')),
  alert_severity text NOT NULL CHECK (alert_severity IN ('info','warning','critical')),
  alert_text text NOT NULL,
  raised_at timestamptz NOT NULL DEFAULT now(),
  acknowledged boolean NOT NULL DEFAULT false,
  acked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_customer_pulse_weekly_r1754 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_pulse_alerts_r1754 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_pulse_weekly_r1754 ON public.founder_customer_pulse_weekly_r1754;
CREATE POLICY founder_all_pulse_weekly_r1754 ON public.founder_customer_pulse_weekly_r1754
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_pulse_alerts_r1754 ON public.founder_customer_pulse_alerts_r1754;
CREATE POLICY founder_all_pulse_alerts_r1754 ON public.founder_customer_pulse_alerts_r1754
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_pulse_weekly_r1754_recorded ON public.founder_customer_pulse_weekly_r1754(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_pulse_alerts_r1754_week ON public.founder_customer_pulse_alerts_r1754(week_start);
CREATE INDEX IF NOT EXISTS idx_pulse_alerts_r1754_acked ON public.founder_customer_pulse_alerts_r1754(acknowledged);
CREATE INDEX IF NOT EXISTS idx_pulse_alerts_r1754_severity ON public.founder_customer_pulse_alerts_r1754(alert_severity);

DROP FUNCTION IF EXISTS public.list_pulse_r1754();
CREATE OR REPLACE FUNCTION public.list_pulse_r1754()
RETURNS TABLE (
  week_start date,
  total_active_hospitals int,
  churned_this_week int,
  nps_score numeric,
  open_critical_tickets int,
  repeat_rate_pct numeric,
  health_index_score int,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.week_start, p.total_active_hospitals, p.churned_this_week, p.nps_score,
         p.open_critical_tickets, p.repeat_rate_pct, p.health_index_score, p.recorded_at
  FROM public.founder_customer_pulse_weekly_r1754 p
  ORDER BY p.week_start DESC
  LIMIT 52;
END;
$$;

DROP FUNCTION IF EXISTS public.record_pulse_r1754(date, int, int, numeric, int, numeric, int);
CREATE OR REPLACE FUNCTION public.record_pulse_r1754(
  p_week_start date,
  p_total_active_hospitals int,
  p_churned_this_week int,
  p_nps_score numeric,
  p_open_critical_tickets int,
  p_repeat_rate_pct numeric,
  p_health_index_score int
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
  INSERT INTO public.founder_customer_pulse_weekly_r1754(
    week_start, total_active_hospitals, churned_this_week, nps_score,
    open_critical_tickets, repeat_rate_pct, health_index_score, recorded_at
  ) VALUES (
    p_week_start, p_total_active_hospitals, p_churned_this_week, p_nps_score,
    p_open_critical_tickets, p_repeat_rate_pct, p_health_index_score, now()
  )
  ON CONFLICT (week_start) DO UPDATE SET
    total_active_hospitals = EXCLUDED.total_active_hospitals,
    churned_this_week = EXCLUDED.churned_this_week,
    nps_score = EXCLUDED.nps_score,
    open_critical_tickets = EXCLUDED.open_critical_tickets,
    repeat_rate_pct = EXCLUDED.repeat_rate_pct,
    health_index_score = EXCLUDED.health_index_score,
    recorded_at = now(),
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_pulse_r1754',
    jsonb_build_object('week_start', p_week_start, 'health_index_score', p_health_index_score));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_alerts_r1754();
CREATE OR REPLACE FUNCTION public.list_alerts_r1754()
RETURNS TABLE (
  id uuid,
  week_start date,
  alert_type text,
  alert_severity text,
  alert_text text,
  raised_at timestamptz,
  acknowledged boolean,
  acked_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.week_start, a.alert_type, a.alert_severity, a.alert_text,
         a.raised_at, a.acknowledged, a.acked_at
  FROM public.founder_customer_pulse_alerts_r1754 a
  ORDER BY a.raised_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.raise_alert_r1754(date, text, text, text);
CREATE OR REPLACE FUNCTION public.raise_alert_r1754(
  p_week_start date,
  p_alert_type text,
  p_alert_severity text,
  p_alert_text text
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
  INSERT INTO public.founder_customer_pulse_alerts_r1754(
    week_start, alert_type, alert_severity, alert_text
  ) VALUES (p_week_start, p_alert_type, p_alert_severity, p_alert_text)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'raise_alert_r1754',
    jsonb_build_object('alert_id', v_id, 'alert_type', p_alert_type, 'severity', p_alert_severity));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.ack_alert_r1754(uuid);
CREATE OR REPLACE FUNCTION public.ack_alert_r1754(p_alert_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_customer_pulse_alerts_r1754
  SET acknowledged = true, acked_at = now(), updated_at = now()
  WHERE id = p_alert_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ack_alert_r1754',
    jsonb_build_object('alert_id', p_alert_id));
END;
$$;

DROP FUNCTION IF EXISTS public.pulse_trend_r1754();
CREATE OR REPLACE FUNCTION public.pulse_trend_r1754()
RETURNS TABLE (
  week_start date,
  health_index_score int,
  nps_score numeric,
  repeat_rate_pct numeric,
  churned_this_week int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.week_start, p.health_index_score, p.nps_score, p.repeat_rate_pct, p.churned_this_week
  FROM public.founder_customer_pulse_weekly_r1754 p
  ORDER BY p.week_start DESC
  LIMIT 12;
END;
$$;

DROP FUNCTION IF EXISTS public.critical_alerts_r1754();
CREATE OR REPLACE FUNCTION public.critical_alerts_r1754()
RETURNS TABLE (
  id uuid,
  week_start date,
  alert_type text,
  alert_text text,
  raised_at timestamptz,
  acknowledged boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.week_start, a.alert_type, a.alert_text, a.raised_at, a.acknowledged
  FROM public.founder_customer_pulse_alerts_r1754 a
  WHERE a.alert_severity = 'critical'
  ORDER BY a.raised_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pulse_r1754() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_pulse_r1754(date, int, int, numeric, int, numeric, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_alerts_r1754() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.raise_alert_r1754(date, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ack_alert_r1754(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pulse_trend_r1754() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_alerts_r1754() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pulse_r1754() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_pulse_r1754(date, int, int, numeric, int, numeric, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_alerts_r1754() TO authenticated;
GRANT EXECUTE ON FUNCTION public.raise_alert_r1754(date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ack_alert_r1754(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pulse_trend_r1754() TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_alerts_r1754() TO authenticated;

COMMIT;