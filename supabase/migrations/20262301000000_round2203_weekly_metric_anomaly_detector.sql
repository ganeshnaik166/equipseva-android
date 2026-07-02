BEGIN;

CREATE TABLE IF NOT EXISTS public.weekly_metric_snapshots_r2203 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key text NOT NULL,
  metric_label text NOT NULL,
  week_start date NOT NULL,
  week_end date NOT NULL,
  current_value numeric NOT NULL DEFAULT 0,
  prior_value numeric NOT NULL DEFAULT 0,
  delta_pct numeric NOT NULL DEFAULT 0,
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','warn','critical')),
  direction text NOT NULL DEFAULT 'flat' CHECK (direction IN ('up','down','flat')),
  notes text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  captured_by uuid REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.weekly_metric_anomaly_reviews_r2203 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid REFERENCES public.weekly_metric_snapshots_r2203(id) ON DELETE CASCADE,
  metric_key text NOT NULL,
  review_status text NOT NULL DEFAULT 'open' CHECK (review_status IN ('open','investigating','dismissed','confirmed','resolved')),
  root_cause text,
  action_taken text,
  reviewer_user_id uuid REFERENCES public.profiles(id),
  reviewed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.weekly_metric_snapshots_r2203 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_metric_anomaly_reviews_r2203 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.weekly_metric_snapshots_r2203;
CREATE POLICY founder_all ON public.weekly_metric_snapshots_r2203
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.weekly_metric_anomaly_reviews_r2203;
CREATE POLICY founder_all ON public.weekly_metric_anomaly_reviews_r2203
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_wmsr2203_week ON public.weekly_metric_snapshots_r2203(week_start DESC, metric_key);
CREATE INDEX IF NOT EXISTS idx_wmsr2203_sev ON public.weekly_metric_snapshots_r2203(severity, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_wmar2203_snap ON public.weekly_metric_anomaly_reviews_r2203(snapshot_id, reviewed_at DESC);

CREATE OR REPLACE FUNCTION public.list_anomalies_r2203()
RETURNS TABLE (
  id uuid,
  metric_key text,
  metric_label text,
  week_start date,
  week_end date,
  current_value numeric,
  prior_value numeric,
  delta_pct numeric,
  severity text,
  direction text,
  notes text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.metric_key, s.metric_label, s.week_start, s.week_end,
         s.current_value, s.prior_value, s.delta_pct, s.severity, s.direction,
         s.notes, s.captured_at
  FROM public.weekly_metric_snapshots_r2203 s
  ORDER BY s.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2203()
RETURNS TABLE (
  id uuid,
  metric_key text,
  review_status text,
  root_cause text,
  action_taken text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.metric_key, r.review_status, r.root_cause, r.action_taken, r.reviewed_at
  FROM public.weekly_metric_anomaly_reviews_r2203 r
  ORDER BY r.reviewed_at DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_severity_r2203()
RETURNS TABLE (
  severity text,
  total_count int,
  critical_count int,
  warn_count int,
  avg_delta numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.severity,
         COUNT(*)::int AS total_count,
         (COUNT(*) FILTER (WHERE s.severity = 'critical'))::int AS critical_count,
         (COUNT(*) FILTER (WHERE s.severity = 'warn'))::int AS warn_count,
         ROUND(AVG(s.delta_pct)::numeric, 2) AS avg_delta
  FROM public.weekly_metric_snapshots_r2203 s
  GROUP BY s.severity
  ORDER BY total_count DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_anomaly_r2203(
  p_metric_key text,
  p_metric_label text,
  p_week_start date,
  p_week_end date,
  p_current_value numeric,
  p_prior_value numeric,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_delta numeric;
  v_severity text;
  v_direction text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_prior_value = 0 THEN
    v_delta := 0;
  ELSE
    v_delta := ROUND(((p_current_value - p_prior_value) / NULLIF(p_prior_value, 0) * 100)::numeric, 2);
  END IF;
  v_direction := CASE WHEN v_delta > 1 THEN 'up' WHEN v_delta < -1 THEN 'down' ELSE 'flat' END;
  v_severity := CASE WHEN ABS(v_delta) >= 30 THEN 'critical' WHEN ABS(v_delta) >= 15 THEN 'warn' ELSE 'info' END;

  INSERT INTO public.weekly_metric_snapshots_r2203(
    metric_key, metric_label, week_start, week_end,
    current_value, prior_value, delta_pct, severity, direction, notes, captured_by
  ) VALUES (
    p_metric_key, p_metric_label, p_week_start, p_week_end,
    p_current_value, p_prior_value, v_delta, v_severity, v_direction, p_notes, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2203_log_anomaly',
          jsonb_build_object('id', v_id, 'metric_key', p_metric_key, 'delta_pct', v_delta, 'severity', v_severity));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2203(
  p_snapshot_id uuid,
  p_review_status text,
  p_root_cause text,
  p_action_taken text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_metric_key text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT metric_key INTO v_metric_key FROM public.weekly_metric_snapshots_r2203 WHERE id = p_snapshot_id;

  INSERT INTO public.weekly_metric_anomaly_reviews_r2203(
    snapshot_id, metric_key, review_status, root_cause, action_taken, reviewer_user_id
  ) VALUES (
    p_snapshot_id, COALESCE(v_metric_key, 'unknown'), COALESCE(p_review_status, 'open'),
    p_root_cause, p_action_taken, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2203_log_action',
          jsonb_build_object('id', v_id, 'snapshot_id', p_snapshot_id, 'review_status', p_review_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2203(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','investigating','dismissed','confirmed','resolved') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.weekly_metric_anomaly_reviews_r2203
  SET review_status = p_status, reviewed_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2203_mark_status',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_metric_r2203()
RETURNS TABLE (
  metric_key text,
  metric_label text,
  snapshot_count int,
  critical_count int,
  warn_count int,
  avg_abs_delta numeric,
  latest_delta numeric,
  latest_week date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.metric_key,
    MAX(s.metric_label) AS metric_label,
    COUNT(*)::int AS snapshot_count,
    (COUNT(*) FILTER (WHERE s.severity = 'critical'))::int AS critical_count,
    (COUNT(*) FILTER (WHERE s.severity = 'warn'))::int AS warn_count,
    ROUND(AVG(ABS(s.delta_pct))::numeric, 2) AS avg_abs_delta,
    (ARRAY_AGG(s.delta_pct ORDER BY s.week_start DESC))[1] AS latest_delta,
    MAX(s.week_start) AS latest_week
  FROM public.weekly_metric_snapshots_r2203 s
  GROUP BY s.metric_key
  ORDER BY critical_count DESC, warn_count DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_anomalies_r2203() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2203() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_severity_r2203() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_anomaly_r2203(text, text, date, date, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2203(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2203(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_metric_r2203() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_anomalies_r2203() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2203() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_severity_r2203() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_anomaly_r2203(text, text, date, date, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2203(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2203(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_metric_r2203() TO authenticated;

COMMIT;
