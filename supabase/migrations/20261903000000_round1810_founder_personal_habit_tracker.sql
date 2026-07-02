BEGIN;

-- ============================================================================
-- Round 1810 — Founder Personal Habit Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_habit_definitions_r1810 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_name text NOT NULL,
  habit_category text NOT NULL CHECK (habit_category IN ('health','mind','work','relationship','learning')),
  target_frequency_per_week int NOT NULL DEFAULT 7 CHECK (target_frequency_per_week BETWEEN 1 AND 7),
  importance text NOT NULL CHECK (importance IN ('critical','important','nice')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_habit_logs_r1810 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id uuid NOT NULL REFERENCES public.founder_habit_definitions_r1810(id) ON DELETE CASCADE,
  log_date date NOT NULL DEFAULT current_date,
  completed boolean NOT NULL DEFAULT true,
  note text,
  logged_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(habit_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_fhd_r1810_active ON public.founder_habit_definitions_r1810(active, habit_category);
CREATE INDEX IF NOT EXISTS idx_fhl_r1810_habit_date ON public.founder_habit_logs_r1810(habit_id, log_date DESC);
CREATE INDEX IF NOT EXISTS idx_fhl_r1810_date ON public.founder_habit_logs_r1810(log_date DESC);

ALTER TABLE public.founder_habit_definitions_r1810 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_habit_logs_r1810 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fhd_r1810_founder ON public.founder_habit_definitions_r1810;
CREATE POLICY p_fhd_r1810_founder ON public.founder_habit_definitions_r1810
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_fhl_r1810_founder ON public.founder_habit_logs_r1810;
CREATE POLICY p_fhl_r1810_founder ON public.founder_habit_logs_r1810
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_habits
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_habits_r1810()
RETURNS TABLE (
  id uuid,
  habit_name text,
  habit_category text,
  target_frequency_per_week int,
  importance text,
  active boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.habit_name, h.habit_category, h.target_frequency_per_week,
         h.importance, h.active, h.created_at
  FROM public.founder_habit_definitions_r1810 h
  ORDER BY h.active DESC,
           CASE h.importance WHEN 'critical' THEN 1 WHEN 'important' THEN 2 ELSE 3 END,
           h.habit_name;
END;
$$;

-- ============================================================================
-- RPC 2: add_habit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_habit_r1810(
  p_habit_name text,
  p_habit_category text,
  p_target_frequency_per_week int,
  p_importance text
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

  INSERT INTO public.founder_habit_definitions_r1810
    (habit_name, habit_category, target_frequency_per_week, importance)
  VALUES
    (p_habit_name, p_habit_category, p_target_frequency_per_week, p_importance)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1810_add_habit',
    jsonb_build_object('habit_id', v_id, 'habit_name', p_habit_name, 'category', p_habit_category, 'importance', p_importance)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_logs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_logs_r1810(p_days int DEFAULT 30)
RETURNS TABLE (
  log_id uuid,
  habit_id uuid,
  habit_name text,
  habit_category text,
  log_date date,
  completed boolean,
  note text,
  logged_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.habit_id, h.habit_name, h.habit_category, l.log_date,
         l.completed, l.note, l.logged_at
  FROM public.founder_habit_logs_r1810 l
  JOIN public.founder_habit_definitions_r1810 h ON h.id = l.habit_id
  WHERE l.log_date >= current_date - (p_days || ' days')::interval
  ORDER BY l.log_date DESC, h.habit_name;
END;
$$;

-- ============================================================================
-- RPC 4: log_habit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_habit_r1810(
  p_habit_id uuid,
  p_log_date date,
  p_completed boolean,
  p_note text DEFAULT NULL
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

  INSERT INTO public.founder_habit_logs_r1810 (habit_id, log_date, completed, note)
  VALUES (p_habit_id, p_log_date, p_completed, p_note)
  ON CONFLICT (habit_id, log_date) DO UPDATE
    SET completed = EXCLUDED.completed,
        note = EXCLUDED.note,
        logged_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1810_log_habit',
    jsonb_build_object('habit_id', p_habit_id, 'log_date', p_log_date, 'completed', p_completed)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: streak_calc
-- ============================================================================
CREATE OR REPLACE FUNCTION public.streak_calc_r1810()
RETURNS TABLE (
  habit_id uuid,
  habit_name text,
  habit_category text,
  current_streak int,
  longest_streak int,
  last_completed date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH done AS (
    SELECT l.habit_id, l.log_date
    FROM public.founder_habit_logs_r1810 l
    WHERE l.completed = true
  ),
  grouped AS (
    SELECT d.habit_id,
           d.log_date,
           d.log_date - (ROW_NUMBER() OVER (PARTITION BY d.habit_id ORDER BY d.log_date))::int AS grp
    FROM done d
  ),
  runs AS (
    SELECT habit_id, grp, COUNT(*)::int AS run_len, MAX(log_date) AS run_end
    FROM grouped
    GROUP BY habit_id, grp
  ),
  cur AS (
    SELECT r.habit_id, r.run_len AS current_streak
    FROM runs r
    WHERE r.run_end >= current_date - INTERVAL '1 day'
  ),
  longest AS (
    SELECT habit_id, MAX(run_len) AS longest_streak FROM runs GROUP BY habit_id
  ),
  last_done AS (
    SELECT habit_id, MAX(log_date) AS last_completed FROM done GROUP BY habit_id
  )
  SELECT h.id,
         h.habit_name,
         h.habit_category,
         COALESCE(cur.current_streak, 0) AS current_streak,
         COALESCE(longest.longest_streak, 0) AS longest_streak,
         last_done.last_completed
  FROM public.founder_habit_definitions_r1810 h
  LEFT JOIN cur ON cur.habit_id = h.id
  LEFT JOIN longest ON longest.habit_id = h.id
  LEFT JOIN last_done ON last_done.habit_id = h.id
  WHERE h.active = true
  ORDER BY COALESCE(cur.current_streak, 0) DESC, h.habit_name;
END;
$$;

-- ============================================================================
-- RPC 6: weekly_compliance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.weekly_compliance_r1810(p_weeks int DEFAULT 4)
RETURNS TABLE (
  habit_id uuid,
  habit_name text,
  week_start date,
  target_frequency_per_week int,
  completed_count int,
  compliance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH weeks AS (
    SELECT date_trunc('week', current_date - (n || ' weeks')::interval)::date AS week_start
    FROM generate_series(0, GREATEST(p_weeks - 1, 0)) AS n
  ),
  pairs AS (
    SELECT h.id AS habit_id, h.habit_name, h.target_frequency_per_week, w.week_start
    FROM public.founder_habit_definitions_r1810 h
    CROSS JOIN weeks w
    WHERE h.active = true
  ),
  counts AS (
    SELECT p.habit_id, p.week_start,
           (COUNT(*) FILTER (WHERE l.completed = true
                                AND l.log_date >= p.week_start
                                AND l.log_date < p.week_start + INTERVAL '7 days'))::int AS done_ct
    FROM pairs p
    LEFT JOIN public.founder_habit_logs_r1810 l ON l.habit_id = p.habit_id
    GROUP BY p.habit_id, p.week_start
  )
  SELECT p.habit_id,
         p.habit_name,
         p.week_start,
         p.target_frequency_per_week,
         COALESCE(c.done_ct, 0) AS completed_count,
         ROUND(LEAST(100.0, (COALESCE(c.done_ct, 0)::numeric * 100.0) / NULLIF(p.target_frequency_per_week, 0)), 1) AS compliance_pct
  FROM pairs p
  LEFT JOIN counts c ON c.habit_id = p.habit_id AND c.week_start = p.week_start
  ORDER BY p.week_start DESC, p.habit_name;
END;
$$;

-- ============================================================================
-- RPC 7: habit_overview
-- ============================================================================
CREATE OR REPLACE FUNCTION public.habit_overview_r1810()
RETURNS TABLE (
  total_habits int,
  active_habits int,
  critical_habits int,
  logged_today int,
  completed_today int,
  completion_rate_today numeric,
  longest_current_streak int,
  habits_at_risk int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      (SELECT COUNT(*) FROM public.founder_habit_definitions_r1810)::int AS total_habits,
      (SELECT COUNT(*) FROM public.founder_habit_definitions_r1810 WHERE active = true)::int AS active_habits,
      (SELECT COUNT(*) FROM public.founder_habit_definitions_r1810 WHERE active = true AND importance = 'critical')::int AS critical_habits,
      (SELECT (COUNT(*) FILTER (WHERE l.log_date = current_date))::int FROM public.founder_habit_logs_r1810 l) AS logged_today,
      (SELECT (COUNT(*) FILTER (WHERE l.log_date = current_date AND l.completed = true))::int FROM public.founder_habit_logs_r1810 l) AS completed_today
  ),
  streaks AS (
    SELECT habit_id, current_streak FROM public.streak_calc_r1810()
  )
  SELECT
    b.total_habits,
    b.active_habits,
    b.critical_habits,
    b.logged_today,
    b.completed_today,
    ROUND(CASE WHEN b.active_habits > 0
               THEN (b.completed_today::numeric * 100.0) / b.active_habits
               ELSE 0 END, 1) AS completion_rate_today,
    COALESCE((SELECT MAX(current_streak) FROM streaks), 0)::int AS longest_current_streak,
    (SELECT (COUNT(*) FILTER (WHERE s.current_streak = 0))::int FROM streaks s) AS habits_at_risk
  FROM base b;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_habits_r1810() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_habits_r1810() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.add_habit_r1810(text, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_habit_r1810(text, text, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_logs_r1810(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_logs_r1810(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_habit_r1810(uuid, date, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_habit_r1810(uuid, date, boolean, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.streak_calc_r1810() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.streak_calc_r1810() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.weekly_compliance_r1810(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_compliance_r1810(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.habit_overview_r1810() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.habit_overview_r1810() TO authenticated;

COMMIT;