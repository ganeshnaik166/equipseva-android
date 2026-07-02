BEGIN;

-- ============================================================================
-- r1664 — Engineer Burnout Watch
-- ============================================================================

-- Table 1: engineer_burnout_signals
CREATE TABLE IF NOT EXISTS public.engineer_burnout_signals_r1664 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  jobs_in_window int NOT NULL DEFAULT 0,
  after_hours_pct numeric(5,2) NOT NULL DEFAULT 0,
  weekend_pct numeric(5,2) NOT NULL DEFAULT 0,
  leave_days int NOT NULL DEFAULT 0,
  signal_score numeric(6,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_burnout_signals_r1664_engineer
  ON public.engineer_burnout_signals_r1664(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_burnout_signals_r1664_recorded
  ON public.engineer_burnout_signals_r1664(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_burnout_signals_r1664_score
  ON public.engineer_burnout_signals_r1664(signal_score DESC);

ALTER TABLE public.engineer_burnout_signals_r1664 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS burnout_signals_r1664_founder_all ON public.engineer_burnout_signals_r1664;
CREATE POLICY burnout_signals_r1664_founder_all
  ON public.engineer_burnout_signals_r1664
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: engineer_burnout_interventions
CREATE TABLE IF NOT EXISTS public.engineer_burnout_interventions_r1664 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  signal_id uuid NOT NULL REFERENCES public.engineer_burnout_signals_r1664(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('call','leave_grant','workload_reduction','counseling','other')),
  taken_by_email text NOT NULL,
  taken_at timestamptz NOT NULL DEFAULT now(),
  note text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_burnout_interventions_r1664_signal
  ON public.engineer_burnout_interventions_r1664(signal_id);
CREATE INDEX IF NOT EXISTS idx_burnout_interventions_r1664_taken
  ON public.engineer_burnout_interventions_r1664(taken_at DESC);

ALTER TABLE public.engineer_burnout_interventions_r1664 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS burnout_interventions_r1664_founder_all ON public.engineer_burnout_interventions_r1664;
CREATE POLICY burnout_interventions_r1664_founder_all
  ON public.engineer_burnout_interventions_r1664
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: founder_compute_burnout_signals (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_compute_burnout_signals_r1664(
  p_window_days int DEFAULT 14
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
VOLATILE
AS $$
DECLARE
  v_window_start timestamptz;
  v_window_end timestamptz;
  v_count int := 0;
  v_id uuid;
  r record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_window_end := now();
  v_window_start := v_window_end - (p_window_days || ' days')::interval;

  FOR r IN
    SELECT
      e.user_id AS engineer_user_id,
      (COUNT(rj.id) FILTER (WHERE rj.completed_at IS NOT NULL))::int AS jobs_in_window,
      COALESCE(
        100.0 * (COUNT(rj.id) FILTER (
          WHERE rj.completed_at IS NOT NULL
            AND (EXTRACT(HOUR FROM rj.completed_at) < 8 OR EXTRACT(HOUR FROM rj.completed_at) >= 20)
        ))::numeric
        / NULLIF((COUNT(rj.id) FILTER (WHERE rj.completed_at IS NOT NULL))::numeric, 0),
        0
      ) AS after_hours_pct,
      COALESCE(
        100.0 * (COUNT(rj.id) FILTER (
          WHERE rj.completed_at IS NOT NULL
            AND EXTRACT(ISODOW FROM rj.completed_at) IN (6, 7)
        ))::numeric
        / NULLIF((COUNT(rj.id) FILTER (WHERE rj.completed_at IS NOT NULL))::numeric, 0),
        0
      ) AS weekend_pct
    FROM public.engineers e
    LEFT JOIN public.repair_jobs rj
      ON rj.engineer_id = e.id
     AND rj.completed_at >= v_window_start
     AND rj.completed_at < v_window_end
    GROUP BY e.user_id
  LOOP
    INSERT INTO public.engineer_burnout_signals_r1664(
      engineer_user_id,
      window_start,
      window_end,
      jobs_in_window,
      after_hours_pct,
      weekend_pct,
      leave_days,
      signal_score,
      recorded_at
    ) VALUES (
      r.engineer_user_id,
      v_window_start,
      v_window_end,
      r.jobs_in_window,
      r.after_hours_pct,
      r.weekend_pct,
      0,
      LEAST(100, GREATEST(0,
        (r.jobs_in_window * 1.5) +
        (r.after_hours_pct * 0.4) +
        (r.weekend_pct * 0.5)
      ))::numeric(6,2),
      now()
    )
    RETURNING id INTO v_id;
    v_count := v_count + 1;
  END LOOP;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1664_compute_burnout_signals',
    jsonb_build_object('rows', v_count, 'window_days', p_window_days)
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_compute_burnout_signals_r1664(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_compute_burnout_signals_r1664(int) TO authenticated;

-- ============================================================================
-- RPC 2: founder_list_burnout_signals (read)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_list_burnout_signals_r1664(
  p_limit int DEFAULT 100
)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  window_start timestamptz,
  window_end timestamptz,
  jobs_in_window int,
  after_hours_pct numeric,
  weekend_pct numeric,
  leave_days int,
  signal_score numeric,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.engineer_user_id,
    COALESCE(p.full_name, p.email, 'unknown') AS engineer_name,
    s.window_start,
    s.window_end,
    s.jobs_in_window,
    s.after_hours_pct,
    s.weekend_pct,
    s.leave_days,
    s.signal_score,
    s.recorded_at
  FROM public.engineer_burnout_signals_r1664 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY s.recorded_at DESC, s.signal_score DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_burnout_signals_r1664(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_list_burnout_signals_r1664(int) TO authenticated;

-- ============================================================================
-- RPC 3: founder_top_burnout_engineers (read)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_top_burnout_engineers_r1664(
  p_limit int DEFAULT 10
)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_name text,
  latest_signal_score numeric,
  latest_jobs int,
  latest_after_hours_pct numeric,
  latest_weekend_pct numeric,
  latest_recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.engineer_user_id)
      s.engineer_user_id,
      s.signal_score,
      s.jobs_in_window,
      s.after_hours_pct,
      s.weekend_pct,
      s.recorded_at
    FROM public.engineer_burnout_signals_r1664 s
    ORDER BY s.engineer_user_id, s.recorded_at DESC
  )
  SELECT
    l.engineer_user_id,
    COALESCE(p.full_name, p.email, 'unknown') AS engineer_name,
    l.signal_score,
    l.jobs_in_window,
    l.after_hours_pct,
    l.weekend_pct,
    l.recorded_at
  FROM latest l
  LEFT JOIN public.profiles p ON p.id = l.engineer_user_id
  ORDER BY l.signal_score DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_top_burnout_engineers_r1664(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_top_burnout_engineers_r1664(int) TO authenticated;

-- ============================================================================
-- RPC 4: founder_log_intervention (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_log_intervention_r1664(
  p_signal_id uuid,
  p_intervention_type text,
  p_note text DEFAULT NULL,
  p_outcome text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
VOLATILE
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.engineer_burnout_interventions_r1664(
    signal_id, intervention_type, taken_by_email, taken_at, note, outcome
  ) VALUES (
    p_signal_id, p_intervention_type, COALESCE(v_email, 'unknown'), now(), p_note, p_outcome
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'r1664_log_intervention',
    jsonb_build_object('id', v_id, 'signal_id', p_signal_id, 'type', p_intervention_type)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_log_intervention_r1664(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_log_intervention_r1664(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: founder_list_interventions (read)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_list_interventions_r1664(
  p_limit int DEFAULT 100
)
RETURNS TABLE(
  id uuid,
  signal_id uuid,
  engineer_name text,
  intervention_type text,
  taken_by_email text,
  taken_at timestamptz,
  note text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.signal_id,
    COALESCE(p.full_name, p.email, 'unknown') AS engineer_name,
    i.intervention_type,
    i.taken_by_email,
    i.taken_at,
    i.note,
    i.outcome
  FROM public.engineer_burnout_interventions_r1664 i
  LEFT JOIN public.engineer_burnout_signals_r1664 s ON s.id = i.signal_id
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  ORDER BY i.taken_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_interventions_r1664(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_list_interventions_r1664(int) TO authenticated;

-- ============================================================================
-- RPC 6: founder_burnout_summary (read)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_burnout_summary_r1664()
RETURNS TABLE(
  total_signals int,
  engineers_tracked int,
  high_risk_count int,
  avg_signal_score numeric,
  max_signal_score numeric,
  interventions_logged int,
  last_computed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_burnout_signals_r1664),
    (SELECT COUNT(DISTINCT engineer_user_id)::int FROM public.engineer_burnout_signals_r1664),
    (SELECT (COUNT(*) FILTER (WHERE signal_score >= 70))::int FROM public.engineer_burnout_signals_r1664),
    (SELECT COALESCE(AVG(signal_score), 0)::numeric(6,2) FROM public.engineer_burnout_signals_r1664),
    (SELECT COALESCE(MAX(signal_score), 0)::numeric(6,2) FROM public.engineer_burnout_signals_r1664),
    (SELECT COUNT(*)::int FROM public.engineer_burnout_interventions_r1664),
    (SELECT MAX(recorded_at) FROM public.engineer_burnout_signals_r1664);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_burnout_summary_r1664() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_burnout_summary_r1664() TO authenticated;

-- ============================================================================
-- RPC 7: founder_burnout_trend (read)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_burnout_trend_r1664(
  p_days int DEFAULT 30
)
RETURNS TABLE(
  bucket_date date,
  signals_recorded int,
  avg_score numeric,
  max_score numeric,
  high_risk_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (s.recorded_at AT TIME ZONE 'UTC')::date AS bucket_date,
    COUNT(*)::int AS signals_recorded,
    COALESCE(AVG(s.signal_score), 0)::numeric(6,2) AS avg_score,
    COALESCE(MAX(s.signal_score), 0)::numeric(6,2) AS max_score,
    (COUNT(*) FILTER (WHERE s.signal_score >= 70))::int AS high_risk_count
  FROM public.engineer_burnout_signals_r1664 s
  WHERE s.recorded_at >= now() - (p_days || ' days')::interval
  GROUP BY (s.recorded_at AT TIME ZONE 'UTC')::date
  ORDER BY bucket_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_burnout_trend_r1664(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_burnout_trend_r1664(int) TO authenticated;

COMMIT;