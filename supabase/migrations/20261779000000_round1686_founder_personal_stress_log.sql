BEGIN;

-- ============================================================================
-- Round 1686 — Founder Personal Stress Log
-- Weekly stress + sleep + workout log with action queue
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_personal_stress_log_r1686 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  log_week date NOT NULL UNIQUE,
  stress_score int NOT NULL CHECK (stress_score BETWEEN 1 AND 10),
  sleep_avg_hours numeric(4,2) NOT NULL CHECK (sleep_avg_hours >= 0 AND sleep_avg_hours <= 24),
  workout_count int NOT NULL DEFAULT 0 CHECK (workout_count >= 0),
  journal_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpsl_r1686_week ON public.founder_personal_stress_log_r1686(log_week DESC);

CREATE TABLE IF NOT EXISTS public.founder_personal_stress_actions_r1686 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  log_id uuid NOT NULL REFERENCES public.founder_personal_stress_log_r1686(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  planned_for date NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','skipped')),
  done_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpsa_r1686_log ON public.founder_personal_stress_actions_r1686(log_id);
CREATE INDEX IF NOT EXISTS idx_fpsa_r1686_planned ON public.founder_personal_stress_actions_r1686(planned_for);

ALTER TABLE public.founder_personal_stress_log_r1686 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_personal_stress_actions_r1686 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fpsl_r1686_founder_all ON public.founder_personal_stress_log_r1686;
CREATE POLICY fpsl_r1686_founder_all ON public.founder_personal_stress_log_r1686
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fpsa_r1686_founder_all ON public.founder_personal_stress_actions_r1686;
CREATE POLICY fpsa_r1686_founder_all ON public.founder_personal_stress_actions_r1686
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_logs — list weekly logs, most recent first
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_list_logs(p_limit int DEFAULT 26)
RETURNS TABLE (
  id uuid,
  log_week date,
  stress_score int,
  sleep_avg_hours numeric,
  workout_count int,
  journal_md text,
  recorded_at timestamptz,
  action_count int,
  action_done_count int
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
  SELECT
    l.id,
    l.log_week,
    l.stress_score,
    l.sleep_avg_hours,
    l.workout_count,
    l.journal_md,
    l.recorded_at,
    (SELECT (COUNT(*))::int FROM public.founder_personal_stress_actions_r1686 a WHERE a.log_id = l.id) AS action_count,
    (SELECT (COUNT(*))::int FROM public.founder_personal_stress_actions_r1686 a WHERE a.log_id = l.id AND a.status = 'done') AS action_done_count
  FROM public.founder_personal_stress_log_r1686 l
  ORDER BY l.log_week DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 26));
END;
$$;

-- ============================================================================
-- RPC 2: record_week — upsert a weekly log
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_record_week(
  p_log_week date,
  p_stress_score int,
  p_sleep_avg_hours numeric,
  p_workout_count int,
  p_journal_md text DEFAULT NULL
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

  INSERT INTO public.founder_personal_stress_log_r1686 (log_week, stress_score, sleep_avg_hours, workout_count, journal_md, recorded_at)
  VALUES (p_log_week, p_stress_score, p_sleep_avg_hours, COALESCE(p_workout_count,0), p_journal_md, now())
  ON CONFLICT (log_week) DO UPDATE
    SET stress_score = EXCLUDED.stress_score,
        sleep_avg_hours = EXCLUDED.sleep_avg_hours,
        workout_count = EXCLUDED.workout_count,
        journal_md = EXCLUDED.journal_md,
        recorded_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1686_record_week',
          jsonb_build_object('id', v_id, 'log_week', p_log_week, 'stress_score', p_stress_score, 'sleep_avg_hours', p_sleep_avg_hours, 'workout_count', p_workout_count));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions — list actions, optionally filtered by status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_list_actions(p_status text DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  log_id uuid,
  log_week date,
  action_text text,
  planned_for date,
  status text,
  done_at timestamptz,
  created_at timestamptz
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
  SELECT
    a.id,
    a.log_id,
    l.log_week,
    a.action_text,
    a.planned_for,
    a.status,
    a.done_at,
    a.created_at
  FROM public.founder_personal_stress_actions_r1686 a
  JOIN public.founder_personal_stress_log_r1686 l ON l.id = a.log_id
  WHERE (p_status IS NULL OR a.status = p_status)
  ORDER BY a.planned_for ASC, a.created_at ASC
  LIMIT GREATEST(1, COALESCE(p_limit, 100));
END;
$$;

-- ============================================================================
-- RPC 4: add_action — append an action to a log
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_add_action(
  p_log_id uuid,
  p_action_text text,
  p_planned_for date
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

  INSERT INTO public.founder_personal_stress_actions_r1686 (log_id, action_text, planned_for, status)
  VALUES (p_log_id, p_action_text, p_planned_for, 'planned')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1686_add_action',
          jsonb_build_object('id', v_id, 'log_id', p_log_id, 'planned_for', p_planned_for));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_action_done — set status done/skipped
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_mark_action_done(
  p_action_id uuid,
  p_status text DEFAULT 'done'
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

  IF p_status NOT IN ('done','skipped','planned') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.founder_personal_stress_actions_r1686
     SET status = p_status,
         done_at = CASE WHEN p_status = 'done' THEN now() ELSE NULL END,
         updated_at = now()
   WHERE id = p_action_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1686_mark_action_done',
          jsonb_build_object('id', p_action_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: stress_trend_12w — 12-week trend
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_stress_trend_12w()
RETURNS TABLE (
  log_week date,
  stress_score int,
  sleep_avg_hours numeric,
  workout_count int
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
  SELECT l.log_week, l.stress_score, l.sleep_avg_hours, l.workout_count
    FROM public.founder_personal_stress_log_r1686 l
   WHERE l.log_week >= (CURRENT_DATE - INTERVAL '84 days')
   ORDER BY l.log_week ASC;
END;
$$;

-- ============================================================================
-- RPC 7: recent_summary — KPIs over last 4 weeks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r1686_recent_summary()
RETURNS TABLE (
  weeks_logged int,
  avg_stress_4w numeric,
  avg_sleep_4w numeric,
  total_workouts_4w int,
  open_actions int,
  overdue_actions int,
  done_actions_4w int,
  latest_week date,
  latest_stress int
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
  SELECT
    (SELECT (COUNT(*))::int FROM public.founder_personal_stress_log_r1686 WHERE log_week >= (CURRENT_DATE - INTERVAL '28 days')) AS weeks_logged,
    (SELECT ROUND(AVG(stress_score)::numeric, 2) FROM public.founder_personal_stress_log_r1686 WHERE log_week >= (CURRENT_DATE - INTERVAL '28 days')) AS avg_stress_4w,
    (SELECT ROUND(AVG(sleep_avg_hours)::numeric, 2) FROM public.founder_personal_stress_log_r1686 WHERE log_week >= (CURRENT_DATE - INTERVAL '28 days')) AS avg_sleep_4w,
    (SELECT (COALESCE(SUM(workout_count),0))::int FROM public.founder_personal_stress_log_r1686 WHERE log_week >= (CURRENT_DATE - INTERVAL '28 days')) AS total_workouts_4w,
    (SELECT (COUNT(*))::int FROM public.founder_personal_stress_actions_r1686 WHERE status = 'planned') AS open_actions,
    (SELECT (COUNT(*))::int FROM public.founder_personal_stress_actions_r1686 WHERE status = 'planned' AND planned_for < CURRENT_DATE) AS overdue_actions,
    (SELECT (COUNT(*))::int FROM public.founder_personal_stress_actions_r1686 WHERE status = 'done' AND done_at >= (now() - INTERVAL '28 days')) AS done_actions_4w,
    (SELECT log_week FROM public.founder_personal_stress_log_r1686 ORDER BY log_week DESC LIMIT 1) AS latest_week,
    (SELECT stress_score FROM public.founder_personal_stress_log_r1686 ORDER BY log_week DESC LIMIT 1) AS latest_stress;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.r1686_list_logs(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1686_record_week(date, int, numeric, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1686_list_actions(text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1686_add_action(uuid, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1686_mark_action_done(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1686_stress_trend_12w() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1686_recent_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1686_list_logs(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1686_record_week(date, int, numeric, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1686_list_actions(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1686_add_action(uuid, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1686_mark_action_done(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1686_stress_trend_12w() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1686_recent_summary() TO authenticated;

COMMIT;