BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_calendar_optimization_r1894 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date UNIQUE NOT NULL,
  total_meeting_minutes int NOT NULL DEFAULT 0 CHECK (total_meeting_minutes >= 0),
  deep_work_minutes int NOT NULL DEFAULT 0 CHECK (deep_work_minutes >= 0),
  no_fly_zone_minutes int NOT NULL DEFAULT 0 CHECK (no_fly_zone_minutes >= 0),
  batched_meeting_minutes int NOT NULL DEFAULT 0 CHECK (batched_meeting_minutes >= 0),
  optimization_score int NOT NULL DEFAULT 0 CHECK (optimization_score BETWEEN 0 AND 100),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_calendar_optimization_targets_r1894 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL REFERENCES public.founder_calendar_optimization_r1894(week_start) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (target_type IN ('deep_work_pct','batched_pct','no_fly_pct','total_meetings')),
  target_value numeric NOT NULL,
  actual_value numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(week_start, target_type)
);

ALTER TABLE public.founder_calendar_optimization_r1894 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_calendar_optimization_targets_r1894 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_r1894_weeks ON public.founder_calendar_optimization_r1894;
CREATE POLICY founder_only_r1894_weeks ON public.founder_calendar_optimization_r1894
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_r1894_targets ON public.founder_calendar_optimization_targets_r1894;
CREATE POLICY founder_only_r1894_targets ON public.founder_calendar_optimization_targets_r1894
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.r1894_list_weeks()
RETURNS TABLE(week_start date, total_meeting_minutes int, deep_work_minutes int, no_fly_zone_minutes int, batched_meeting_minutes int, optimization_score int, recorded_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.week_start, w.total_meeting_minutes, w.deep_work_minutes, w.no_fly_zone_minutes, w.batched_meeting_minutes, w.optimization_score, w.recorded_at
  FROM public.founder_calendar_optimization_r1894 w
  ORDER BY w.week_start DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1894_record_week(
  p_week_start date,
  p_total_meeting_minutes int,
  p_deep_work_minutes int,
  p_no_fly_zone_minutes int,
  p_batched_meeting_minutes int,
  p_optimization_score int
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
  INSERT INTO public.founder_calendar_optimization_r1894(week_start, total_meeting_minutes, deep_work_minutes, no_fly_zone_minutes, batched_meeting_minutes, optimization_score)
  VALUES (p_week_start, p_total_meeting_minutes, p_deep_work_minutes, p_no_fly_zone_minutes, p_batched_meeting_minutes, p_optimization_score)
  ON CONFLICT (week_start) DO UPDATE
    SET total_meeting_minutes = EXCLUDED.total_meeting_minutes,
        deep_work_minutes = EXCLUDED.deep_work_minutes,
        no_fly_zone_minutes = EXCLUDED.no_fly_zone_minutes,
        batched_meeting_minutes = EXCLUDED.batched_meeting_minutes,
        optimization_score = EXCLUDED.optimization_score,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1894_record_week', jsonb_build_object('week_start', p_week_start, 'score', p_optimization_score));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1894_list_targets()
RETURNS TABLE(week_start date, target_type text, target_value numeric, actual_value numeric, gap numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.week_start, t.target_type, t.target_value, t.actual_value, (t.actual_value - t.target_value) AS gap
  FROM public.founder_calendar_optimization_targets_r1894 t
  ORDER BY t.week_start DESC, t.target_type ASC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1894_set_target(
  p_week_start date,
  p_target_type text,
  p_target_value numeric,
  p_actual_value numeric
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
  INSERT INTO public.founder_calendar_optimization_targets_r1894(week_start, target_type, target_value, actual_value)
  VALUES (p_week_start, p_target_type, p_target_value, p_actual_value)
  ON CONFLICT (week_start, target_type) DO UPDATE
    SET target_value = EXCLUDED.target_value,
        actual_value = EXCLUDED.actual_value,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1894_set_target', jsonb_build_object('week_start', p_week_start, 'target_type', p_target_type, 'target_value', p_target_value));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1894_optimization_trend()
RETURNS TABLE(week_start date, optimization_score int, deep_work_pct numeric, no_fly_pct numeric, batched_pct numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.week_start,
         w.optimization_score,
         CASE WHEN w.total_meeting_minutes + w.deep_work_minutes > 0
              THEN ROUND((w.deep_work_minutes::numeric * 100) / NULLIF(w.total_meeting_minutes + w.deep_work_minutes, 0), 1)
              ELSE 0 END AS deep_work_pct,
         CASE WHEN w.total_meeting_minutes + w.deep_work_minutes > 0
              THEN ROUND((w.no_fly_zone_minutes::numeric * 100) / NULLIF(w.total_meeting_minutes + w.deep_work_minutes, 0), 1)
              ELSE 0 END AS no_fly_pct,
         CASE WHEN w.total_meeting_minutes > 0
              THEN ROUND((w.batched_meeting_minutes::numeric * 100) / NULLIF(w.total_meeting_minutes, 0), 1)
              ELSE 0 END AS batched_pct
  FROM public.founder_calendar_optimization_r1894 w
  ORDER BY w.week_start DESC
  LIMIT 26;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1894_top_violations()
RETURNS TABLE(week_start date, target_type text, target_value numeric, actual_value numeric, gap numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.week_start, t.target_type, t.target_value, t.actual_value, (t.actual_value - t.target_value) AS gap
  FROM public.founder_calendar_optimization_targets_r1894 t
  WHERE t.actual_value < t.target_value
  ORDER BY (t.target_value - t.actual_value) DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1894_recent_weeks()
RETURNS TABLE(week_start date, optimization_score int, total_meeting_minutes int, deep_work_minutes int, recorded_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.week_start, w.optimization_score, w.total_meeting_minutes, w.deep_work_minutes, w.recorded_at
  FROM public.founder_calendar_optimization_r1894 w
  ORDER BY w.recorded_at DESC
  LIMIT 12;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1894_list_weeks() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1894_record_week(date, int, int, int, int, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1894_list_targets() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1894_set_target(date, text, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1894_optimization_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1894_top_violations() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1894_recent_weeks() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1894_list_weeks() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1894_record_week(date, int, int, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1894_list_targets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1894_set_target(date, text, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1894_optimization_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1894_top_violations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1894_recent_weeks() TO authenticated;

COMMIT;